/// The standard Dachen (大千/標準) Bopomofo keyboard layout.
///
/// Every printable key that carries a Bopomofo symbol is mapped here. Note that
/// all 26 latin letters carry a symbol, which is why English words typed without
/// switching modes still land on Bopomofo keys — the classifier's job is to tell
/// which interpretation the user meant.
public enum SymbolCategory: Equatable {
    case initialConsonant  // 聲母 ㄅㄆㄇ…
    case medial            // 介音 ㄧㄨㄩ
    case final             // 韻母 ㄚㄛㄜ…
    case tone              // 聲調（空白=1, 6=ˊ, 3=ˇ, 4=ˋ, 7=˙）
}

public struct KeySymbol: Equatable {
    public let bopomofo: String
    public let category: SymbolCategory
    /// Tone number 1–5, only for tone keys.
    public let tone: Int?

    init(_ bopomofo: String, _ category: SymbolCategory, tone: Int? = nil) {
        self.bopomofo = bopomofo
        self.category = category
        self.tone = tone
    }
}

public enum DachenLayout {
    public static let map: [Character: KeySymbol] = [
        // 聲母
        "1": KeySymbol("ㄅ", .initialConsonant),
        "q": KeySymbol("ㄆ", .initialConsonant),
        "a": KeySymbol("ㄇ", .initialConsonant),
        "z": KeySymbol("ㄈ", .initialConsonant),
        "2": KeySymbol("ㄉ", .initialConsonant),
        "w": KeySymbol("ㄊ", .initialConsonant),
        "s": KeySymbol("ㄋ", .initialConsonant),
        "x": KeySymbol("ㄌ", .initialConsonant),
        "e": KeySymbol("ㄍ", .initialConsonant),
        "d": KeySymbol("ㄎ", .initialConsonant),
        "c": KeySymbol("ㄏ", .initialConsonant),
        "r": KeySymbol("ㄐ", .initialConsonant),
        "f": KeySymbol("ㄑ", .initialConsonant),
        "v": KeySymbol("ㄒ", .initialConsonant),
        "5": KeySymbol("ㄓ", .initialConsonant),
        "t": KeySymbol("ㄔ", .initialConsonant),
        "g": KeySymbol("ㄕ", .initialConsonant),
        "b": KeySymbol("ㄖ", .initialConsonant),
        "y": KeySymbol("ㄗ", .initialConsonant),
        "h": KeySymbol("ㄘ", .initialConsonant),
        "n": KeySymbol("ㄙ", .initialConsonant),
        // 介音
        "u": KeySymbol("ㄧ", .medial),
        "j": KeySymbol("ㄨ", .medial),
        "m": KeySymbol("ㄩ", .medial),
        // 韻母
        "8": KeySymbol("ㄚ", .final),
        "i": KeySymbol("ㄛ", .final),
        "k": KeySymbol("ㄜ", .final),
        ",": KeySymbol("ㄝ", .final),
        "9": KeySymbol("ㄞ", .final),
        "o": KeySymbol("ㄟ", .final),
        "l": KeySymbol("ㄠ", .final),
        ".": KeySymbol("ㄡ", .final),
        "0": KeySymbol("ㄢ", .final),
        "p": KeySymbol("ㄣ", .final),
        ";": KeySymbol("ㄤ", .final),
        "/": KeySymbol("ㄥ", .final),
        "-": KeySymbol("ㄦ", .final),
        // 聲調
        " ": KeySymbol("", .tone, tone: 1),
        "6": KeySymbol("ˊ", .tone, tone: 2),
        "3": KeySymbol("ˇ", .tone, tone: 3),
        "4": KeySymbol("ˋ", .tone, tone: 4),
        "7": KeySymbol("˙", .tone, tone: 5),
    ]
}
