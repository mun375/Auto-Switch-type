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

final class ZhuyinParserPrefixTests: XCTestCase {
    func testEmptyIsPrefix() {
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: ""), .prefix(completed: []))
    }

    func testOpenSyllableStaysPrefix() {
        // ㄒ → ㄒㄧ → ㄒㄧㄠ: attested completions exist at every step
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "v"), .prefix(completed: []))
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "vu"), .prefix(completed: []))
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "vul"), .prefix(completed: []))
    }

    func testCompleteSyllable() {
        guard case .complete(let syls) = ZhuyinParser.parsePrefix(keys: "vul3") else {
            return XCTFail("expected .complete")
        }
        XCTAssertEqual(syls.map(\.bopomofo), ["ㄒㄧㄠˇ"])
    }

    func testCompleteThenOpenSyllable() {
        // ㄓㄨˋ closed, ㄒㄧ still open
        guard case .prefix(let completed) = ZhuyinParser.parsePrefix(keys: "5j4vu") else {
            return XCTFail("expected .prefix")
        }
        XCTAssertEqual(completed.map(\.bopomofo), ["ㄓㄨˋ"])
    }

    func testMultiSyllableComplete() {
        guard case .complete(let syls) = ZhuyinParser.parsePrefix(keys: "5j4vul3") else {
            return XCTFail("expected .complete")
        }
        XCTAssertEqual(syls.map(\.bopomofo), ["ㄓㄨˋ", "ㄒㄧㄠˇ"])
    }

    func testStrictRejectsBeforeToneOnUnattestedFinal() {
        // hi = ㄘㄛ: no ㄘㄛ syllable, dead on the second key without a tone
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "hi"), .impossible)
        // structural mode only checks ordering, so it stays a prefix
        XCTAssertEqual(
            ZhuyinParser.parsePrefix(keys: "hi", mode: .structural), .prefix(completed: []))
    }

    func testStrictRejectsBeforeToneOnUnattestedMedial() {
        // hu = ㄘㄧ: no ㄘㄧ* syllable exists, dead at the medial already
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "hu"), .impossible)
        // r8 = ㄐㄚ: ㄐ takes no bare ㄚ rime
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "r8"), .impossible)
    }

    func testOrderingViolationIsImpossible() {
        // he = ㄘㄍ: two initials in a row
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "he"), .impossible)
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "hello"), .impossible)
    }

    func testToneWithoutSymbolIsImpossible() {
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "3"), .impossible)
    }

    func testNonLayoutKeyIsImpossible() {
        XCTAssertEqual(ZhuyinParser.parsePrefix(keys: "v["), .impossible)
    }

    func testPrefixAgreesWithFullParse() {
        // complete ⇔ parse succeeds without the trailing-space rescue
        for keys in ["vul3", "5j4vul3", "rup", "hello", "hi", "so"] {
            let full = ZhuyinParser.parse(keys: keys, appendFirstToneIfMissing: false)
            if case .complete(let syls) = ZhuyinParser.parsePrefix(keys: keys) {
                XCTAssertEqual(full, syls, "mismatch for \(keys)")
            } else {
                XCTAssertNil(full, "parsePrefix not .complete but parse succeeded for \(keys)")
            }
        }
    }

    func testRareSyllableParsesButIsFlagged() {
        // no = ㄙㄟ (only 㩙), uk = ㄧㄜ (rare rime)
        guard case .prefix = ZhuyinParser.parsePrefix(keys: "no") else {
            return XCTFail("ㄙㄟ is attested, should stay a prefix")
        }
        let syls = ZhuyinParser.parse(keys: "no", appendFirstToneIfMissing: true)
        XCTAssertEqual(syls?.first?.isRare, true)
        let ye = ZhuyinParser.parse(keys: "uk", appendFirstToneIfMissing: true)
        XCTAssertEqual(ye?.first?.isRare, true)
        let xiao = ZhuyinParser.parse(keys: "vul3")
        XCTAssertEqual(xiao?.first?.isRare, false)
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

    func testRareSyllableLosesToEnglishWord() {
        // "no " parses as ㄙㄟ (rare, only 㩙) but is the common word "no":
        // English wins, yet the Chinese reading is kept as the alternate.
        let rare = Classifier(lexicon: ["no", "uk"])
        let no = rare.classify(token: "no", followedBySpace: true)
        XCTAssertEqual(no.verdict, .english)
        XCTAssertEqual(no.syllables?.first?.bopomofo, "ㄙㄟ")
        XCTAssertEqual(rare.classify(token: "uk", followedBySpace: true).verdict, .english)
    }

    func testRareSyllableWithExplicitToneStaysChinese() {
        // "no4" = ㄙㄟˋ typed with an explicit tone key: not an English-shaped
        // token at all, the rare reading is honored.
        let rare = Classifier(lexicon: ["no"])
        XCTAssertEqual(rare.classify(token: "no4", followedBySpace: false).verdict, .chinese)
    }
}

final class ClassifierPrefixTests: XCTestCase {
    let classifier = Classifier(lexicon: ["so", "no", "uk", "hello", "the"])

    func testOpenBopomofoIsUndecided() {
        XCTAssertEqual(classifier.classifyPrefix(keys: "v"), .undecidedPrefix)
        XCTAssertEqual(classifier.classifyPrefix(keys: "vul"), .undecidedPrefix)
        XCTAssertEqual(classifier.classifyPrefix(keys: "so"), .undecidedPrefix)
        XCTAssertEqual(classifier.classifyPrefix(keys: ""), .undecidedPrefix)
    }

    func testImpossiblePrefixIsEnglish() {
        // conversion trigger fires mid-word, long before the space
        XCTAssertEqual(classifier.classifyPrefix(keys: "he"), .english)
        XCTAssertEqual(classifier.classifyPrefix(keys: "hel"), .english)
    }

    func testUppercaseIsEnglish() {
        XCTAssertEqual(classifier.classifyPrefix(keys: "N"), .english)
        XCTAssertEqual(classifier.classifyPrefix(keys: "aN"), .english)
    }

    func testCompleteCompositionIsChinese() {
        guard case .chinese(let syls) = classifier.classifyPrefix(keys: "vul3") else {
            return XCTFail("expected .chinese")
        }
        XCTAssertEqual(syls.map(\.bopomofo), ["ㄒㄧㄠˇ"])
    }

    func testSpaceResolvesAmbiguity() {
        guard case .ambiguous(let syls) = classifier.classifyPrefix(keys: "so", followedBySpace: true)
        else {
            return XCTFail("expected .ambiguous")
        }
        XCTAssertEqual(syls.map(\.bopomofo), ["ㄋㄟ"])
    }

    func testSpaceAppliesRareDownWeight() {
        XCTAssertEqual(classifier.classifyPrefix(keys: "no", followedBySpace: true), .english)
        XCTAssertEqual(classifier.classifyPrefix(keys: "uk", followedBySpace: true), .english)
    }

    func testSpaceOnPlainChinese() {
        guard case .chinese(let syls) = classifier.classifyPrefix(keys: "rup", followedBySpace: true)
        else {
            return XCTFail("expected .chinese")
        }
        XCTAssertEqual(syls.map(\.bopomofo), ["ㄐㄧㄣ"])
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
