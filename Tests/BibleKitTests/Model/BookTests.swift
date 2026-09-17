import XCTest
@testable import BibleKit

final class BookTests: XCTestCase {
    func testGenesisStructure() {
        let genesis = BookCollection.mapping[.Genesis]!
        XCTAssertEqual(genesis.totalChapters, 50)
        XCTAssertEqual(genesis.totalVerses(chapter: 1), 31)
        XCTAssertEqual(genesis.startVerseID.value, "1:1:1")
    }

    func testAllVerseIDsCountMatchesVerseCounts() {
        let ruth = BookCollection.mapping[.Ruth]!
        XCTAssertEqual(ruth.allVerseIDs().count, 22 + 23 + 18 + 22)
    }
}
