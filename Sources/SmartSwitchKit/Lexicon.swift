import Foundation

/// Bundled English word lists for the ambiguity check.
public enum Lexicon {
    /// Top-3000 most frequent English words (from the google-10000-english
    /// list, derived from the Google Web Trillion Word Corpus). This is the
    /// lexicon size Policy v0 was measured with.
    public static let top3000: Set<String> = {
        guard
            let url = Bundle.module.url(
                forResource: "english-top3000", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("english-top3000.txt missing from bundle")
            return []
        }
        return Set(
            text.split(separator: "\n").map { $0.lowercased() }.filter { !$0.isEmpty })
    }()

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
