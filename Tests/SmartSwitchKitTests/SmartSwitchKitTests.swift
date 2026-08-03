import XCTest

@testable import SmartSwitchKit

final class ZhuyinParserTests: XCTestCase {
    func testValidSingleSyllableWithToneKey() {
        // vul3 = ㄒㄧㄠˇ (小)
        let syl = ZhuyinParser.parse(keys: "vul3")
        XCTAssertEqual(syl?.count, 1)
        XCTAssertEqual(syl?.first?.bopomofo, "ㄒㄧㄠˇ")
    }

    func testFirstToneClosedBySpace() {
        // rup + space = ㄐㄧㄣ (今)
        let syl = ZhuyinParser.parse(keys: "rup", appendFirstToneIfMissing: true)
        XCTAssertEqual(syl?.first?.bopomofo, "ㄐㄧㄣ")
    }

    func testTrailingSyllableWithoutToneFails() {
        XCTAssertNil(ZhuyinParser.parse(keys: "rup", appendFirstToneIfMissing: false))
    }

    func testMultiSyllable() {
        // 5j4vul3 = ㄓㄨˋ + ㄒㄧㄠˇ
        let syl = ZhuyinParser.parse(keys: "5j4vul3")
        XCTAssertEqual(syl?.map(\.bopomofo), ["ㄓㄨˋ", "ㄒㄧㄠˇ"])
    }

    func testEnglishWordDoesNotParse() {
        // hello → ㄘㄍㄠㄠㄟ: two finals in a row, no tone → invalid
        XCTAssertNil(ZhuyinParser.parse(keys: "hello", appendFirstToneIfMissing: true))
        XCTAssertNil(ZhuyinParser.parse(keys: "the", appendFirstToneIfMissing: true))
        XCTAssertNil(ZhuyinParser.parse(keys: "abc", appendFirstToneIfMissing: true))
    }

    func testStrictRejectsUnattestedSyllable() {
        // hi = ㄘㄛ: structurally fine, but ㄘㄛ is not a Mandarin syllable
        XCTAssertNotNil(
            ZhuyinParser.parse(keys: "hi", appendFirstToneIfMissing: true, mode: .structural))
        XCTAssertNil(ZhuyinParser.parse(keys: "hi", appendFirstToneIfMissing: true, mode: .strict))
    }

    func testEmptyRimeSyllables() {
        // 5 + tone = ㄓ (zhi); plain ㄅ alone is not a syllable
        XCTAssertNotNil(ZhuyinParser.parse(keys: "5", appendFirstToneIfMissing: true))
        XCTAssertNil(ZhuyinParser.parse(keys: "1", appendFirstToneIfMissing: true))
    }

    func testToneWithoutSymbolFails() {
        XCTAssertNil(ZhuyinParser.parse(keys: "3vul3"))
    }
}

final class ClassifierTests: XCTestCase {
    let classifier = Classifier(lexicon: ["so", "the", "hello", "mac", "i"])

    func testChineseToken() {
        XCTAssertEqual(
            classifier.classify(token: "vul3", followedBySpace: false).verdict, .chinese)
        XCTAssertEqual(classifier.classify(token: "rup", followedBySpace: true).verdict, .chinese)
    }

    func testEnglishToken() {
        XCTAssertEqual(classifier.classify(token: "hello", followedBySpace: true).verdict, .english)
        XCTAssertEqual(classifier.classify(token: "the", followedBySpace: true).verdict, .english)
    }

    func testUppercaseForcesEnglish() {
        XCTAssertEqual(classifier.classify(token: "Mac", followedBySpace: true).verdict, .english)
    }

    func testAmbiguousToken() {
        // "so " = ㄋㄟ¹ and the English word "so"
        XCTAssertEqual(classifier.classify(token: "so", followedBySpace: true).verdict, .ambiguous)
    }

    func testEnglishWordNotInLexiconButUnparseableIsEnglish() {
        XCTAssertEqual(
            classifier.classify(token: "xyzzy", followedBySpace: true).verdict, .english)
    }
}

final class SyllableTableTests: XCTestCase {
    func testInventorySize() {
        // Standard Mandarin has ~410–420 attested syllables (incl. rare ones);
        // flag loudly if the hand-encoded chart drifts far from that.
        let n = SyllableTable.validSyllables.count
        XCTAssertGreaterThan(n, 380, "inventory suspiciously small: \(n)")
        XCTAssertLessThan(n, 450, "inventory suspiciously large: \(n)")
    }

    func testKnownSyllables() {
        XCTAssertTrue(SyllableTable.isValid(initial: "ㄒ", rime: "ㄧㄠ"))
        XCTAssertTrue(SyllableTable.isValid(initial: "ㄓ", rime: ""))
        XCTAssertTrue(SyllableTable.isValid(initial: "", rime: "ㄦ"))
        XCTAssertFalse(SyllableTable.isValid(initial: "ㄘ", rime: "ㄛ"))
        XCTAssertFalse(SyllableTable.isValid(initial: "ㄐ", rime: "ㄚ"))
        XCTAssertFalse(SyllableTable.isValid(initial: "ㄅ", rime: ""))
    }
}
