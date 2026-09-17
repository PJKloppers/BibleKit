@testable import BibleKitDB
import XCTest
@testable import BibleKit

final class BibleProviderTests: XCTestCase {
    private func makeProvider() async throws -> BibleProvider {
        let dataSource = try await VerseDataSource.create()
        let storeProvider = BibleStoreProvider(repository: dataSource)
        try await storeProvider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await storeProvider.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning God created the heaven and the earth."),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "And the earth was without form, and void."),
        ])
        return BibleProvider(store: DefaultBibleStoreService(provider: storeProvider))
    }

    func testChapterReturnsAllVersesInOrder() async throws {
        let provider = try await makeProvider()
        let verses = try await provider.chapter(translation: TranslationID("kjv"), chapter: ChapterReference(bookName: .Genesis, index: 1))
        XCTAssertEqual(verses.map(\.id.value), ["1:1:1", "1:1:2"])
    }

    func testSearchFindsMatchingVerse() async throws {
        let provider = try await makeProvider()
        let results = try await provider.search(translation: TranslationID("kjv"), query: "void")
        XCTAssertEqual(results.map(\.id.value), ["1:1:2"])
    }

    func testSearchWithBlankQueryReturnsEmpty() async throws {
        let provider = try await makeProvider()
        let results = try await provider.search(translation: TranslationID("kjv"), query: "   ")
        XCTAssertTrue(results.isEmpty)
    }

    func testTranslationsListsRegistered() async throws {
        let provider = try await makeProvider()
        let translations = try await provider.translations()
        XCTAssertEqual(translations.map(\.id), [TranslationID("kjv")])
    }
}
