import XCTest
@testable import BibleKit

final class ChapterReferenceTests: XCTestCase {
    func testStartAndEndVerseID() {
        let chapter = ChapterReference(bookName: .Genesis, index: 1)
        XCTAssertEqual(chapter.startVerseID.value, "1:1:1")
        XCTAssertEqual(chapter.endVerseID.value, "1:1:31")
    }

    func testAllVerseIDsCount() {
        let chapter = ChapterReference(bookName: .Ruth, index: 1)
        XCTAssertEqual(chapter.allVerseIDs().count, 22)
    }

    func testIsHashable() {
        let chapters: Set<ChapterReference> = [
            ChapterReference(bookName: .Genesis, index: 1),
            ChapterReference(bookName: .Genesis, index: 1),
            ChapterReference(bookName: .Genesis, index: 2),
        ]
        XCTAssertEqual(chapters.count, 2)
    }
}
