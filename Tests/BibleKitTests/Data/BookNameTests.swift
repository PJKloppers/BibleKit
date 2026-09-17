import XCTest
@testable import BibleKit

final class BookNameTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(BookName.allCases.count, 66)
    }

    func testShortNameForGenesis() {
        XCTAssertEqual(BookName.Genesis.shortName, "Gen")
    }

    func testValueForMultiWordName() {
        XCTAssertEqual(BookName.Samuel1.value, "1 Samuel")
    }

    func testIsHashable() {
        let names: Set<BookName> = [.Genesis, .Genesis, .Exodus]
        XCTAssertEqual(names.count, 2)
    }
}
