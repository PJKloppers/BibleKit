import XCTest
@testable import BibleKit

final class BookCollectionTests: XCTestCase {
    func testAllBooksCount() {
        XCTAssertEqual(BookCollection.allBooks.count, 66)
    }

    func testOldAndNewTestamentCounts() {
        XCTAssertEqual(BookCollection.oldTestamentBooks.count, 39)
        XCTAssertEqual(BookCollection.newTestamentBooks.count, 27)
    }

    func testMappingCoversEveryBook() {
        for bookName in BookName.allCases {
            XCTAssertNotNil(BookCollection.mapping[bookName])
        }
    }
}
