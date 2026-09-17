import XCTest
@testable import BibleKit

final class VerseReferenceTests: XCTestCase {
    func testFromVerseIDValid() {
        let ref = VerseReference.fromVerseID("1:1:1")
        XCTAssertEqual(ref?.chapter.bookName, .Genesis)
    }

    func testFromVerseIDInvalidBookReturnsNil() {
        XCTAssertNil(VerseReference.fromVerseID("67:1:1"))
    }

    func testComparable() {
        let a = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 1), index: 1)
        let b = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 1), index: 2)
        XCTAssertLessThan(a, b)
    }
}
