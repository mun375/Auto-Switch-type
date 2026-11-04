import Foundation

/// Bundled English word lists for the ambiguity check.
public enum Lexicon {
    /// Top-3000 most frequent English words (from the google-10000-english
    /// list, derived from the Google Web Trillion Word Corpus). This is the
    /// lexicon size Policy v0 was measured with.
    public static let top3000: Set<String> = Set(top3000Ranked)

    /// The same list in frequency order (most frequent first).
    public static let top3000Ranked: [String] = bundledLines("english-top3000")
        .map { $0.lowercased() }

    /// English words outside `top3000` that the space-split heuristic
    /// (`BoundarySplitter.splitAtSpace`) would otherwise cut into a word plus
    /// a syllable — "backup" = "back" + ㄧㄣ. Generated from google-10000 and
    /// the system word list by `swift run gen-boundary-data`.
    public static let noSplitWords: Set<String> = Set(bundledLines("english-nosplit"))

    /// `Syllable.bopomofo` → relative frequency of the syllable in typed
    /// Chinese, summed from McBopomofo's single-character unigrams. Generated
    /// by `swift run gen-boundary-data`.
    public static let syllableWeights: [String: Double] = {
        var weights: [String: Double] = [:]
        for line in bundledLines("syllable-weights") {
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let w = Double(fields[1]) else { continue }
            weights[String(fields[0])] = w
        }
        return weights
    }()

    private static func bundledLines(_ name: String) -> [String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("\(name).txt missing from bundle")
            return []
        }
        return text.split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Parses a user-maintained word list: one entry per line, `#` starts a
    /// comment, blank lines ignored. Only the first whitespace-separated field
    /// of a line counts, so `ai      # 人工智慧` works.
    ///
    /// Entries are lowercased because the classifier treats any uppercase key
    /// as an explicit English signal already.
    public static func parseUserList(_ text: String) -> Set<String> {
        var words: Set<String> = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.prefix { $0 != "#" }
            guard let field = line.split(whereSeparator: \.isWhitespace).first else { continue }
            words.insert(field.lowercased())
        }
        return words
    }
}
