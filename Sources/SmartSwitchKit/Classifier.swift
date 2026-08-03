import Foundation

/// Classifies one token (the keys typed between word delimiters) as Chinese
/// (Bopomofo composition) or English.
///
/// Design notes:
/// - Any uppercase letter is an explicit English signal (the user pressed
///   Shift), mirroring how ASUS Smart Input lets Shift force English.
/// - A token counts as a Bopomofo composition only if it parses into complete
///   syllables (every syllable closed by a tone key; a trailing space closes
///   the last syllable with tone 1).
/// - A token that parses as Bopomofo *and* is an English word in the lexicon is
///   genuinely ambiguous; resolution policy is measured separately.
public struct Classifier {
    public enum Verdict: Equatable {
        case chinese
        case english
        /// Parses as Bopomofo and is also an English word in the lexicon.
        case ambiguous
    }

    public struct Result: Equatable {
        public let verdict: Verdict
        public let syllables: [Syllable]?
    }

    /// English words used for the ambiguity check (lowercase).
    public let lexicon: Set<String>
    public let mode: ParseMode

    public init(lexicon: Set<String>, mode: ParseMode = .strict) {
        self.lexicon = lexicon
        self.mode = mode
    }

    public func classify(token: String, followedBySpace: Bool) -> Result {
        guard !token.isEmpty else { return Result(verdict: .english, syllables: nil) }

        // Shift = explicit English.
        if token.contains(where: { $0.isUppercase }) {
            return Result(verdict: .english, syllables: nil)
        }

        let parsed = ZhuyinParser.parse(
            keys: token,
            appendFirstToneIfMissing: followedBySpace,
            mode: mode
        )

        guard let syllables = parsed else {
            // Not a possible Bopomofo composition → English. (Tokens with
            // Bopomofo-only keys that fail to parse are usually mistyped
            // Bopomofo; typo handling is a Phase 2 concern.)
            return Result(verdict: .english, syllables: nil)
        }

        let lettersOnly = token.allSatisfy { $0.isLetter }
        if lettersOnly, lexicon.contains(token.lowercased()) {
            return Result(verdict: .ambiguous, syllables: syllables)
        }
        return Result(verdict: .chinese, syllables: syllables)
    }
}
