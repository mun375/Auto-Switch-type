/// Inventory of attested Standard Mandarin syllables, encoded as
/// initial → allowed rimes (medial + final), in Bopomofo.
///
/// Used by the strict parse mode to reject key sequences that are structurally
/// shaped like a syllable but do not exist in Mandarin (e.g. ㄘㄛ).
///
/// Calibrated (2026-08-03) against McBopomofo's dictionary data
/// (`Source/Data/BPMFBase.txt` + `BPMFMappings.txt`, 429 toneless syllables):
/// every syllable attested there is accepted, with one deliberate exception —
/// the 14 bare-initial entries (ㄅ, ㄆ, ㄇ, … as standalone dictionary items)
/// are the Bopomofo *symbols themselves*, not Mandarin syllables. Accepting
/// them would make most single English letters parse as Chinese, so the
/// classifier rejects them; symbol input stays available via candidate
/// selection in the IME. See `scripts/` in the repo for the comparison tool.
public enum SyllableTable {
    /// Pinyin-flavored rime names → Bopomofo strings. "v" stands for ü (ㄩ).
    /// "ye" (ㄧㄜ) and "iai" (ㄧㄞ) are rare rimes with no standard pinyin
    /// spelling.
    static let rimes: [String: String] = [
        "a": "ㄚ", "o": "ㄛ", "e": "ㄜ", "eh": "ㄝ", "ai": "ㄞ", "ei": "ㄟ",
        "ao": "ㄠ", "ou": "ㄡ", "an": "ㄢ", "en": "ㄣ", "ang": "ㄤ", "eng": "ㄥ", "er": "ㄦ",
        "i": "ㄧ", "ia": "ㄧㄚ", "io": "ㄧㄛ", "ie": "ㄧㄝ", "iao": "ㄧㄠ", "iu": "ㄧㄡ",
        "ian": "ㄧㄢ", "in": "ㄧㄣ", "iang": "ㄧㄤ", "ing": "ㄧㄥ", "ye": "ㄧㄜ", "iai": "ㄧㄞ",
        "u": "ㄨ", "ua": "ㄨㄚ", "uo": "ㄨㄛ", "uai": "ㄨㄞ", "ui": "ㄨㄟ",
        "uan": "ㄨㄢ", "un": "ㄨㄣ", "uang": "ㄨㄤ", "ong": "ㄨㄥ",
        "v": "ㄩ", "ve": "ㄩㄝ", "van": "ㄩㄢ", "vn": "ㄩㄣ", "iong": "ㄩㄥ",
    ]

    /// Initial (empty string = zero initial) → space-separated rime names.
    /// "-" denotes the empty rime (ㄓㄔㄕㄖㄗㄘㄙ standing alone, i.e. zhi/chi/…).
    static let chart: [String: String] = [
        "": "a o e eh ai ei ao ou an en ang eng er i ia io ie iao iu ian in iang ing ye iai u ua uo uai ui uan un uang ong v ve van vn iong",
        "ㄅ": "a o ai ei ao an en ang eng i ie iao ian in iang ing u",
        "ㄆ": "a o ai ei ao ou an en ang eng i ia ie iao ian in ing u",
        "ㄇ": "a o e ai ei ao ou an en ang eng i ie iao iu ian in ing u",
        "ㄈ": "a o ei ou an en ang eng iao u",
        "ㄉ": "a e ai ei ao ou an ang eng i ia ie iao iu ian ing u uo ui uan un ong",
        "ㄊ": "a e ai ao ou an ang eng i ie iao ian ing u uo ui uan un ong",
        "ㄋ": "a e ai ei ao ou an en ang eng i ie iao iu ian in iang ing u uo uan un ong v ve",
        "ㄌ": "a e ai ei ao ou an ang eng i ia ie iao iu ian in iang ing u uo uan un ong v ve van",
        "ㄍ": "a e ai ei ao ou an en ang eng u ua uo uai ui uan un uang ong",
        "ㄎ": "a e ai ao ou an en ang eng u ua uo uai ui uan un uang ong",
        "ㄏ": "a e ai ei ao ou an en ang eng u ua uo uai ui uan un uang ong",
        "ㄐ": "i ia ie iao iu ian in iang ing v ve van vn iong",
        "ㄑ": "i ia ie iao iu ian in iang ing v ve van vn iong",
        "ㄒ": "i ia ie iao iu ian in iang ing v ve van vn iong",
        "ㄓ": "- a e ai ei ao ou an en ang eng u ua uo uai ui uan un uang ong",
        "ㄔ": "- a e ai ao ou an en ang eng u ua uo uai ui uan un uang ong",
        "ㄕ": "- a e ai ei ao ou an en ang eng u ua uo uai ui uan un uang",
        "ㄖ": "- e ao ou an en ang eng u uo ui uan un ong",
        "ㄗ": "- a e ai ei ao ou an en ang eng u uo ui uan un ong",
        "ㄘ": "- a e ai ao ou an en ang eng u uo ui uan un ong",
        "ㄙ": "- a e ai ei ao ou an en ang eng u uo ui uan un ong",
    ]

    /// Syllables attested only in rare/literary readings or CJK-extension
    /// characters (e.g. ㄙㄟ 㩙, ㄅㄧㄤ 𰻞, ㄈㄧㄠ 覅). They are valid for
    /// parsing, but a classifier should heavily down-weight the Chinese
    /// interpretation when one of these competes with a common English word
    /// (ㄙㄟ's key sequence is literally "no").
    public static let rareSyllables: Set<String> = [
        "|ㄧㄜ", "|ㄧㄞ", "ㄅ|ㄧㄤ", "ㄆ|ㄧㄚ", "ㄈ|ㄧㄠ",
        "ㄋ|ㄨㄣ", "ㄌ|ㄩㄢ", "ㄔ|ㄨㄚ", "ㄙ|ㄟ",
    ]

    /// Set of "initial|rime" (both in Bopomofo) for O(1) validity lookup.
    public static let validSyllables: Set<String> = {
        var set = Set<String>()
        for (initial, rimeNames) in chart {
            for name in rimeNames.split(separator: " ") {
                if name == "-" {
                    set.insert("\(initial)|")
                } else if let rime = rimes[String(name)] {
                    set.insert("\(initial)|\(rime)")
                } else {
                    fatalError("Unknown rime name: \(name)")
                }
            }
        }
        return set
    }()

    public static func isValid(initial: String, rime: String) -> Bool {
        validSyllables.contains("\(initial)|\(rime)")
    }
}
