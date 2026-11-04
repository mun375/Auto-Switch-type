import Foundation
import SmartSwitchKit

// Measures the shipped BoundarySplitter (automatic English→Chinese boundary).
//
// Usage (from the repo root): swift run -c release measure-boundary
//
// Chinese side: every lexicon word E followed by every syllable S, weighted by
// E's Zipf frequency × S's frequency — how often the split lands on E.
// English side: words outside every protected list, plus hand-picked
// alphanumeric and brand tokens — how often a split wrongly fires.
// Simulated key sequences, not real typing.

let repo = FileManager.default.currentDirectoryPath
let splitter = BoundarySplitter.bundled()
let classifier = Classifier(lexicon: Lexicon.top3000)

func pct(_ x: Double) -> String { String(format: "%.2f%%", x * 100) }

/// Index at which the token turns English (IME hook A), nil if never.
func englishFrom(_ keys: String) -> Int? {
    let k = Array(keys)
    for i in 1...k.count where classifier.classifyPrefix(keys: String(k[0..<i])) == .english {
        return i
    }
    return nil
}

var keyForSymbol: [Character: Character] = [:]
for (key, symbol) in DachenLayout.map where symbol.category != .tone {
    keyForSymbol[Character(symbol.bopomofo)] = key
}
let toneKeys: [Character: Character] = ["ˊ": "6", "ˇ": "3", "ˋ": "4", "˙": "7"]
func keys(for bopomofo: String) -> (String, Character) {
    var out = ""
    var tone: Character = " "
    for ch in bopomofo {
        if let t = toneKeys[ch] { tone = t } else if let k = keyForSymbol[ch] { out.append(k) }
    }
    return (out, tone)
}

let syllables = Lexicon.syllableWeights.map { (keys(for: $0.key), $0.key, $0.value) }
let toned = syllables.filter { $0.0.1 != " " }
let tone1 = syllables.filter { $0.0.1 == " " }
let tonedTotal = toned.reduce(0) { $0 + $1.2 }
let tone1Total = tone1.reduce(0) { $0 + $1.2 }
print("Characters with a tone digit (method A coverage): \(pct(tonedTotal / (tonedTotal + tone1Total)))")

let words = Lexicon.top3000Ranked.enumerated().filter { $0.element.count >= 2 && $0.element.allSatisfy(\.isLetter) }
let wordTotal = words.reduce(0.0) { $0 + 1.0 / Double($1.offset + 1) }

for (name, set, total, isSpace) in [("A (tone key)", toned, tonedTotal, false), ("B (space)", tone1, tone1Total, true)] {
    var correct = 0.0, wrong = 0.0, none = 0.0
    for (rank, e) in words {
        let we = 1.0 / Double(rank + 1) / wordTotal
        for ((sk, tone), _, ws) in set {
            let w = we * ws / total
            let buf = e + sk
            guard englishFrom(buf) != nil else { none += w; continue }
            let split = isSpace ? splitter.splitAtSpace(keys: buf) : splitter.splitBeforeTone(keys: buf, toneKey: tone)
            if let split { if split.englishLength == e.count { correct += w } else { wrong += w } } else { none += w }
        }
    }
    print("\(name) Chinese side: correct \(pct(correct)), wrong split \(pct(wrong)), no split \(pct(none))")
}

let googleWords = (try! String(contentsOfFile: "\(repo)/data/google-10000-english.txt", encoding: .utf8))
    .split(separator: "\n").map { $0.lowercased() }.filter { $0.allSatisfy(\.isLetter) && !$0.isEmpty }
let zipf = (1...googleWords.count).reduce(0.0) { $0 + 1.0 / Double($1) }
var spaceWrong = 0.0
for (i, w) in googleWords.enumerated() where englishFrom(w) != nil && splitter.splitAtSpace(keys: w) != nil {
    spaceWrong += 1.0 / Double(i + 1) / zipf
}
print("B English side (google 10k, Zipf-weighted): wrongly split \(pct(spaceWrong)) of English usage")

let samples = """
mp3 mp4 h264 win7 win10 win11 ipv4 ipv6 iphone16 ps4 ps5 covid19 4k b2b utf8 html5 css3 es6 python3 gpt4 gpt5
i7 i9 m4 x86 arm64 2fa web3 4g 5g usb3 ddr4 ddr5 sha256 md5 base64 ios18 rtx4090 office365 n95 top10 day3 step6 mark4
github gmail youtube netflix iphone chatgpt claude vercel supabase nextjs ecpay openai costco startup signup taipei
""".split(whereSeparator: \.isWhitespace).map(String.init)
var broken: [String] = []
for tok in samples {
    guard let ei = englishFrom(tok) else { continue }
    let k = Array(tok)
    var buf = String(k[0..<ei])
    var hit = false
    for c in k[ei...] {
        if "3467".contains(c), let s = splitter.splitBeforeTone(keys: buf, toneKey: c) {
            broken.append("\(tok)→\(buf.prefix(s.englishLength))|\(s.syllable.bopomofo)")
            hit = true
            break
        }
        buf.append(c)
    }
    if !hit, let s = splitter.splitAtSpace(keys: buf) {
        broken.append("\(tok)␣→\(buf.prefix(s.englishLength))|\(s.syllable.bopomofo)")
    }
}
print("Sample tokens wrongly split: \(broken.count)/\(samples.count): \(broken.joined(separator: " "))")
