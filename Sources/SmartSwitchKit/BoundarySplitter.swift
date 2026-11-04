import Foundation

/// Finds where an English word ends and a Chinese syllable begins inside a
/// token that the IME has already turned English, so the user does not have
/// to press space between them ("hello" + ㄋㄧˇ typed as `hellosu3`).
///
/// Two triggers, measured offline before shipping (2026-11-04):
/// - **Tone key** (3/4/6/7, method A): the keys before the tone are split into
///   an English word plus exactly one complete syllable. Covers ~81% of typed
///   characters (everything but tone 1).
/// - **Space** (method B): the same split with the trailing syllable closed as
///   tone 1. Only applies when the whole token is not itself a known English
///   word (`protected`), because the space is also the English word delimiter.
///
/// At space the syllable's keys must include a non-digit: "win10" and "html5"
/// stay whole even though 10 = ㄅㄢ and 5 = ㄓ on the Dachen layout.
///
/// The English part must be a lexicon word with at least three letters, a
/// whitelisted two-letter word, or a user-listed word: the top-3000 list is
/// full of abbreviations ("ca", "st", "wi") that would otherwise split `cap`
/// or `win7`. When several splits qualify, the one with the highest
/// English-frequency × syllable-frequency score wins (`the` + 在 beats
/// `they` + 愛).
public struct BoundarySplitter {
    public struct Split: Equatable {
        /// Number of leading keys that stay English.
        public let englishLength: Int
        public let syllable: Syllable
    }

    /// Real two-letter words (and a few acronyms commonly typed before Chinese).
    static let twoLetterWords: Set<String> = [
        "of", "to", "in", "is", "on", "by", "it", "or", "be", "at", "as", "an", "we", "us", "if",
        "my", "do", "no", "he", "up", "so", "am", "me", "go", "oh", "ok", "hi", "tv", "pc",
    ]

    /// Lowercase word → relative frequency (Zipf: 1/rank).
    let englishWeight: [String: Double]
    let userEnglish: Set<String>
    /// Whole tokens that a space must never split.
    let protected: Set<String>
    /// `Syllable.bopomofo` → relative frequency.
    let syllableWeight: [String: Double]

    /// Weight given to user-listed words: as common as a top-10 English word,
    /// since the user declared them.
    static let userWordWeight = 1.0 / 10

    public init(
        rankedLexicon: [String], userEnglish: Set<String> = [], protected: Set<String> = [],
        syllableWeight: [String: Double]
    ) {
        var weights: [String: Double] = [:]
        for (i, w) in rankedLexicon.enumerated() where weights[w] == nil {
            weights[w] = 1.0 / Double(i + 1)
        }
        self.englishWeight = weights
        self.userEnglish = userEnglish
        self.protected = protected.union(rankedLexicon).union(userEnglish)
        self.syllableWeight = syllableWeight
    }

    /// The bundled configuration the IME uses.
    public static func bundled(userEnglish: Set<String> = []) -> BoundarySplitter {
        BoundarySplitter(
            rankedLexicon: Lexicon.top3000Ranked, userEnglish: userEnglish,
            protected: Lexicon.noSplitWords, syllableWeight: Lexicon.syllableWeights)
    }

    func englishScore(_ word: String) -> Double? {
        guard word.count >= 2, word.allSatisfy({ $0.isLetter }) else { return nil }
        let lower = word.lowercased()
        if userEnglish.contains(lower) { return Self.userWordWeight }
        guard let w = englishWeight[lower] else { return nil }
        if word.count == 2 && !Self.twoLetterWords.contains(lower) { return nil }
        return w
    }

    /// Method A: `keys` is the English token so far, `toneKey` the tone digit
    /// just typed (not yet part of `keys`).
    public func splitBeforeTone(keys: String, toneKey: Character) -> Split? {
        guard "3467".contains(toneKey) else { return nil }
        return bestSplit(keys: keys, allowDigitOnlySyllable: true) { suffix in
            ZhuyinParser.parse(keys: suffix + String(toneKey), mode: .strict)
        }
    }

    /// Method B: `keys` is the English token that space is about to close.
    public func splitAtSpace(keys: String) -> Split? {
        guard !protected.contains(keys.lowercased()) else { return nil }
        // Digits before a space are a version number far more often than a
        // syllable spelled on digit keys ("win10" is not win + 班). Before a
        // tone digit they stay allowed: 至 (54) and 大 (284) are common.
        return bestSplit(keys: keys, allowDigitOnlySyllable: false) { suffix in
            ZhuyinParser.parse(keys: suffix, appendFirstToneIfMissing: true, mode: .strict)
        }
    }

    private func bestSplit(
        keys: String, allowDigitOnlySyllable: Bool, parse: (String) -> [Syllable]?
    ) -> Split? {
        let chars = Array(keys)
        guard chars.count >= 3 else { return nil }
        var best: (score: Double, split: Split)?
        for j in 2..<chars.count {
            let suffix = chars[j...]
            guard allowDigitOnlySyllable || suffix.contains(where: { !$0.isNumber }),
                let eScore = englishScore(String(chars[0..<j])),
                let syllables = parse(String(suffix)), syllables.count == 1
            else { continue }
            let syllable = syllables[0]
            // Unknown syllables still qualify (the strict table accepted
            // them) but rank below every attested one.
            let score = eScore * (syllableWeight[syllable.bopomofo] ?? 1e-12)
            if best == nil || score > best!.score {
                best = (score, Split(englishLength: j, syllable: syllable))
            }
        }
        return best?.split
    }
}
