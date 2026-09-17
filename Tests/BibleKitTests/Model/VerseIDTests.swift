import XCTest
@testable import BibleKit

final class VerseIDTests: XCTestCase {
    func testComponents() {
        XCTAssertEqual(VerseID(value: "1:2:3").components(), [1, 2, 3])
    }

    func testBookChapterVerse() {
        XCTAssertEqual(VerseID(value: "1:1:1").bookChapterVerse(), "Genesis 1:1")
    }

    func testBookNameFromID() {
        XCTAssertEqual(VerseID(value: "40:1:1").bookName(), .Matthew)
    }

    func testStartAndEnd() {
        XCTAssertEqual(VerseID.start.value, "1:1:1")
        XCTAssertEqual(VerseID.end.value, "66:22:21")
    }
}
