import Foundation
import SmartSwitchKit

// Phase 0 accuracy analysis.
//
// Usage: analyze <google-10000-english.txt> [system-dict:/usr/share/dict/words]
//
// Measures, for both structural and strict parse modes:
//  1. English side — how many English words would be misread as Bopomofo when
//     typed without switching (the word + trailing space). Reported unweighted
//     and Zipf-weighted by frequency rank.
//  2. Chinese side — which attested syllables (typed as keys) collide with
//     English words, i.e. the genuinely ambiguous set.

guard CommandLine.arguments.count >= 2 else {
    print("usage: analyze <google-10000-english.txt> [dict-path]")
    exit(1)
}

let commonPath = CommandLine.arguments[1]
let dictPath = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : "/usr/share/dict/words"

func loadWords(_ path: String) -> [String] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("cannot read \(path)")
        exit(1)
    }
    return content.split(separator: "\n").map { $0.lowercased() }
        .filter { !$0.isEmpty && $0.allSatisfy { $0.isLetter } }
}

let commonWords = loadWords(commonPath)  // rank-ordered
let commonSet = Set(commonWords)
let dictWords = Set(loadWords(dictPath))

print("Loaded \(commonWords.count) common words, \(dictWords.count) dict words")
print("Strict syllable inventory: \(SyllableTable.validSyllables.count) syllables\n")

// How much of real-world English usage each rank represents (Zipf: weight ∝ 1/rank).
let zipfTotal = (1...commonWords.count).reduce(0.0) { $0 + 1.0 / Double($1) }

for mode in [ParseMode.structural, ParseMode.strict] {
    let modeName = mode == .structural ? "STRUCTURAL (文法檢查)" : "STRICT (真實音節表)"
    print("═══ \(modeName) ═══")

    // ── English side ──
    var collisions: [String] = []  // parses as Bopomofo → would be ambiguous/misread
    var weightedCollision = 0.0
    for (idx, word) in commonWords.enumerated() {
        if ZhuyinParser.parse(keys: word, appendFirstToneIfMissing: true, mode: mode) != nil {
            collisions.append(word)
            weightedCollision += 1.0 / Double(idx + 1) / zipfTotal
        }
    }
    let pct = Double(collisions.count) / Double(commonWords.count) * 100
    print("English→Bopomofo collisions (top-10k words): \(collisions.count) (\(String(format: "%.2f", pct))%)")
    print("Zipf-weighted share of English usage affected: \(String(format: "%.2f", weightedCollision * 100))%")
    print("Top-ranked colliding words: \(collisions.prefix(40).joined(separator: " "))")

    var dictCollisions = 0
    for word in dictWords
    where ZhuyinParser.parse(keys: word, appendFirstToneIfMissing: true, mode: mode) != nil {
        dictCollisions += 1
    }
    let dictPct = Double(dictCollisions) / Double(dictWords.count) * 100
    print("Full dictionary (235k) collisions: \(dictCollisions) (\(String(format: "%.2f", dictPct))%)")

    // ── Chinese side ──
    // Enumerate attested syllables, render them as key sequences, and check
    // which ones (as typed, with the tone-1 space) look like English words.
    var reverseMap: [String: Character] = [:]  // bopomofo symbol → key
    for (key, sym) in DachenLayout.map where sym.category != .tone {
        reverseMap[sym.bopomofo] = key
    }
    var ambiguousSyllables: [(keys: String, bopomofo: String)] = []
    var lettersOnlyBodies = 0
    var totalBodies = 0
    for entry in SyllableTable.validSyllables {
        let parts = entry.split(separator: "|", omittingEmptySubsequences: false)
        let body = String(parts[0]) + String(parts[1])
        let keys = String(body.map { reverseMap[String($0)]! })
        totalBodies += 1
        // Tones 2–5 end with a digit key → can never look English. Only the
        // tone-1 form (body + space) competes with an English word.
        if keys.allSatisfy({ $0.isLetter }) {
            lettersOnlyBodies += 1
            if commonSet.contains(keys) || dictWords.contains(keys) {
                ambiguousSyllables.append((keys, body))
            }
        }
    }
    print("Syllable bodies typed with letter keys only: \(lettersOnlyBodies)/\(totalBodies)")
    print("…of which collide with an English word (tone-1 form): \(ambiguousSyllables.count)")
    for (keys, bopomofo) in ambiguousSyllables.sorted(by: { $0.keys < $1.keys }) {
        let rank = commonWords.firstIndex(of: keys).map { "#\($0 + 1)" } ?? "dict-only"
        print("   \"\(keys)\" = \(bopomofo)¹  (English rank: \(rank))")
    }
    print("")
}

// ── Headline metric ──
// Policy v0: lexicon = top-3000 common words. ambiguous → English.
// English error = words (weighted) classified .chinese.
// Chinese error = tone-1 syllables whose body is in the lexicon (→ ambiguous → English).
print("═══ POLICY v0（strict 模式，詞典=top-3000，模糊時判英文）═══")
let lexicon = Set(commonWords.prefix(3000))
let classifier = Classifier(lexicon: lexicon, mode: .strict)

var englishErrWeighted = 0.0
var englishErrCount = 0
for (idx, word) in commonWords.enumerated() {
    let r = classifier.classify(token: word, followedBySpace: true)
    if r.verdict == .chinese {
        englishErrCount += 1
        englishErrWeighted += 1.0 / Double(idx + 1) / zipfTotal
    }
}
print("English side: \(englishErrCount)/\(commonWords.count) words misread as Chinese")
print("  → Zipf-weighted error: \(String(format: "%.3f", englishErrWeighted * 100))%")

var chineseErr = 0
var chineseTotal = 0
var chineseErrList: [String] = []
var reverseMap: [String: Character] = [:]
for (key, sym) in DachenLayout.map where sym.category != .tone {
    reverseMap[sym.bopomofo] = key
}
for entry in SyllableTable.validSyllables {
    let parts = entry.split(separator: "|", omittingEmptySubsequences: false)
    let body = String(parts[0]) + String(parts[1])
    let keys = String(body.map { reverseMap[String($0)]! })
    let toneKeys = [1: "", 2: "6", 3: "3", 4: "4", 5: "7"]
    for tone in 1...5 {
        chineseTotal += 1
        let typed = keys + toneKeys[tone]!
        let r = classifier.classify(token: typed, followedBySpace: tone == 1)
        if r.verdict != .chinese {
            chineseErr += 1
            if tone == 1 { chineseErrList.append("\(keys)=\(body)¹") }
        }
    }
}
print("Chinese side: \(chineseErr)/\(chineseTotal) syllable×tone forms not classified Chinese")
print("  All are tone-1 bodies colliding with a common English word:")
print("  \(chineseErrList.sorted().joined(separator: "  "))")

print("""

═══ 綜合準確率（假設中英 token 比例）═══
（中文錯誤率以「音節×聲調」均勻分佈粗估，實際依音節頻率會更低）
""")
let enAcc = 1 - englishErrWeighted
let zhAcc = 1 - Double(chineseErr) / Double(chineseTotal)
for (zh, en) in [(0.9, 0.1), (0.8, 0.2), (0.7, 0.3)] {
    let overall = zh * zhAcc + en * enAcc
    print(String(format: "中:英 = %.0f:%.0f → overall %.2f%%  (中文側 %.2f%%, 英文側 %.2f%%)",
                 zh * 100, en * 100, overall * 100, zhAcc * 100, enAcc * 100))
}
