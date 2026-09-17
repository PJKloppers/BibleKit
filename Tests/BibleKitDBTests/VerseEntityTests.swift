import XCTest
@testable import BibleKitDB

final class VerseEntityTests: XCTestCase {
    func testSortKeyPadsChapterAndVerse() {
        XCTAssertEqual(VerseEntity.sortKey(id: "1:1:1"), 1_001_001)
    }

    func testSortKeyForLastVerseOfBible() {
        XCTAssertEqual(VerseEntity.sortKey(id: "66:22:21"), 66_022_021)
    }

    func testSortKeyOrdersVersesWithinABook() {
        XCTAssertLessThan(VerseEntity.sortKey(id: "1:1:31"), VerseEntity.sortKey(id: "1:2:1"))
    }

    func testInitStoresTranslationId() {
        let verse = VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning")
        XCTAssertEqual(verse.translationId, "kjv")
        XCTAssertEqual(verse.text, "In the beginning")
    }

    func testTranslationEntityEquality() {
        let a = TranslationEntity(id: "kjv", name: "King James Version", language: "en")
        let b = TranslationEntity(id: "kjv", name: "King James Version", language: "en")
        XCTAssertEqual(a, b)
    }
}
