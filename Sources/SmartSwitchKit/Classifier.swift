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
    /// User-maintained words that win outright (lowercase). Unlike `lexicon`,
    /// a hit here is not merely ambiguous: the user has declared that this key
    /// sequence means the English word, so the verdict is `.english` even when
    /// the keys form a perfectly good syllable ("ai" is ㄇㄛ = 摸). The Bopomofo
    /// reading is still returned as the alternate interpretation for ↑.
    public let userEnglish: Set<String>
    public let mode: ParseMode

    public init(
        lexicon: Set<String>, userEnglish: Set<String> = [], mode: ParseMode = .strict
    ) {
        self.lexicon = lexicon
        self.userEnglish = userEnglish
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

        let lowercased = token.lowercased()
        if userEnglish.contains(lowercased) {
            return Result(verdict: .english, syllables: syllables)
        }

        let lettersOnly = token.allSatisfy { $0.isLetter }
        if lettersOnly, lexicon.contains(lowercased) {
            // A rare/literary syllable loses to a common English word: "no" is
            // ㄙㄟ only for 㩙, so the English reading wins outright. Syllables
            // are still returned so the UI can offer the Chinese reading as
            // the alternate interpretation.
            if syllables.contains(where: \.isRare) {
                return Result(verdict: .english, syllables: syllables)
            }
            return Result(verdict: .ambiguous, syllables: syllables)
        }
        return Result(verdict: .chinese, syllables: syllables)
    }

    /// Per-keystroke verdict for the IME's smart mixed mode.
    public enum PrefixVerdict: Equatable {
        /// Could still become a Bopomofo composition — keep feeding keys.
        case undecidedPrefix
        case chinese([Syllable])
        case english
        /// Complete Bopomofo composition that is also an English lexicon word.
        case ambiguous([Syllable])
    }

    /// Incremental classification of the raw keys typed so far in one token.
    ///
    /// Call with `followedBySpace: false` on every printable key; `.english`
    /// means no continuation can be Bopomofo (the conversion trigger for the
    /// IME's hook A). Call with `followedBySpace: true` when the space key
    /// arrives (hook C) for the final chinese/english/ambiguous decision.
    public func classifyPrefix(keys: String, followedBySpace: Bool = false) -> PrefixVerdict {
        guard !keys.isEmpty else { return .undecidedPrefix }

        if keys.contains(where: { $0.isUppercase }) {
            return .english
        }

        if followedBySpace {
            let result = classify(token: keys, followedBySpace: true)
            switch result.verdict {
            case .chinese: return .chinese(result.syllables ?? [])
            case .ambiguous: return .ambiguous(result.syllables ?? [])
            case .english: return .english
            }
        }

        switch ZhuyinParser.parsePrefix(keys: keys, mode: mode) {
        case .impossible:
            return .english
        case .prefix:
            return .undecidedPrefix
        case .complete(let syllables):
            // A tone key (space aside) is a digit, so a complete composition
            // can never be an English lexicon word — no ambiguity mid-token.
            return .chinese(syllables)
        }
    }
}
