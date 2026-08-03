/// Parses a raw key sequence (as typed on the Dachen layout) into Bopomofo
/// syllables, or nil when the sequence cannot be a Bopomofo composition.
///
/// A syllable is: [initial]? [medial]? [final]? tone — symbols must appear in
/// that order, at least one phonetic symbol before the tone, and a new syllable
/// can only start after the previous one's tone key.
public struct Syllable: Equatable {
    public var initialC: String?
    public var medial: String?
    public var final: String?
    public var tone: Int

    public var rime: String { (medial ?? "") + (final ?? "") }

    public var bopomofo: String {
        let toneMarks = [1: "", 2: "ˊ", 3: "ˇ", 4: "ˋ", 5: "˙"]
        return (initialC ?? "") + rime + (toneMarks[tone] ?? "")
    }
}

public enum ParseMode {
    /// Only checks symbol ordering (initial → medial → final → tone).
    case structural
    /// Additionally requires each syllable to exist in `SyllableTable`.
    case strict
}

public enum ZhuyinParser {
    /// Parses `keys` into complete syllables.
    ///
    /// - Parameter appendFirstToneIfMissing: when true, a trailing syllable
    ///   without a tone key is closed with tone 1. This models the fact that
    ///   the space bar is both the first-tone key and the English word
    ///   delimiter — call with `true` when the token was followed by a space.
    public static func parse(
        keys: String,
        appendFirstToneIfMissing: Bool = false,
        mode: ParseMode = .strict
    ) -> [Syllable]? {
        var syllables: [Syllable] = []
        var current = Syllable(tone: 0)
        var hasSymbol = false
        var stage = 0  // 0=start, 1=initial, 2=medial, 3=final

        func close(tone: Int) -> Bool {
            guard hasSymbol else { return false }
            current.tone = tone
            if mode == .strict,
                !SyllableTable.isValid(initial: current.initialC ?? "", rime: current.rime)
            {
                return false
            }
            syllables.append(current)
            current = Syllable(tone: 0)
            hasSymbol = false
            stage = 0
            return true
        }

        for ch in keys {
            guard let sym = DachenLayout.map[ch] else { return nil }
            switch sym.category {
            case .initialConsonant:
                guard stage < 1 else { return nil }
                current.initialC = sym.bopomofo
                stage = 1
                hasSymbol = true
            case .medial:
                guard stage < 2 else { return nil }
                current.medial = sym.bopomofo
                stage = 2
                hasSymbol = true
            case .final:
                guard stage < 3 else { return nil }
                current.final = sym.bopomofo
                stage = 3
                hasSymbol = true
            case .tone:
                guard close(tone: sym.tone!) else { return nil }
            }
        }

        if hasSymbol {
            guard appendFirstToneIfMissing, close(tone: 1) else { return nil }
        }
        return syllables.isEmpty ? nil : syllables
    }
}
