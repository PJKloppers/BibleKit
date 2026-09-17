import XCTest
@testable import BibleKit

@MainActor
final class BibleReaderModelTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "BibleReaderModel.selectedTranslation")
        super.tearDown()
    }

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

    func testAvailableTranslationsPopulateAfterLoad() async throws {
        let model = BibleReaderModel()
        model.load()

        var translations: [BibleKit.Translation] = []
        for _ in 0..<50 {
            translations = model.availableTranslations
            if !translations.isEmpty { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(Set(translations.map { $0.id }), [TranslationID("afrikaans-2020"), TranslationID("english-kjv")])
    }

    func testSelectTranslationUpdatesTranslation() {
        let model = BibleReaderModel()
        model.selectTranslation(TranslationID("english-kjv"))
        XCTAssertEqual(model.translation, TranslationID("english-kjv"))
    }

    func testSelectTranslationPersistsAcrossInstances() {
        let model = BibleReaderModel()
        model.selectTranslation(TranslationID("english-kjv"))

        let reloaded = BibleReaderModel()
        XCTAssertEqual(reloaded.translation, TranslationID("english-kjv"))
    }

    func testDisplayNameReflectsSelectedTranslation() {
        let model = BibleReaderModel()
        model.selectTranslation(TranslationID("english-kjv"))
        let exodus = BookCollection.mapping[.Exodus]!
        XCTAssertEqual(model.displayName(for: exodus), "Exodus")
    }
}
