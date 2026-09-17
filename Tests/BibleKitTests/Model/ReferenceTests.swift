import XCTest
@testable import BibleKit

final class ReferenceTests: XCTestCase {
    func testVerseIDsWithinSingleChapter() {
        // Ruth is book 8 (Genesis=1 ... Judges=7, Ruth=8).
        let reference = Reference.createWithBook(bookName: .Ruth, fromChapter: 1, toChapter: 1, fromVerse: 1, toVerse: 3)
        XCTAssertEqual(reference.verseIDs().map(\.value), ["8:1:1", "8:1:2", "8:1:3"])
    }

    func testFixupSwapsOutOfOrderReferences() {
        let from = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 2), index: 1)
        let to = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 1), index: 1)
        let fixed = Reference(from: from, to: to).fixup()
        XCTAssertEqual(fixed.from, to)
        XCTAssertEqual(fixed.to, from)
    }
}
