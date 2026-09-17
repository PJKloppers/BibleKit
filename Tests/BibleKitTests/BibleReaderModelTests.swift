import XCTest
@testable import BibleKit

@MainActor
final class BibleReaderModelTests: XCTestCase {
    func testLoadSucceedsWithBundledDatabase() {
        let model = BibleReaderModel()
        model.load()
        XCTAssertEqual(model.state, .loaded)
    }

    func testDisplayNameUsesAfrikaans() {
        let model = BibleReaderModel()
        let exodus = BookCollection.mapping[.Exodus]!
        XCTAssertEqual(model.displayName(for: exodus), "Eksodus")
    }

    func testVersesReturnsGenesisChapterOne() async throws {
        let model = BibleReaderModel()
        model.load()
        let verses = try await model.verses(chapter: ChapterReference(bookName: .Genesis, index: 1))
        XCTAssertEqual(verses.count, 31)
    }
}
