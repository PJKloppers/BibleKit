@testable import BibleKitDB
import XCTest
@testable import BibleKit

final class DefaultBibleStoreServiceTests: XCTestCase {
    func testGetVersesInRangeReturnsMappedVerses() async throws {
        let dataSource = try await VerseDataSource.create()
        let provider = BibleStoreProvider(repository: dataSource)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await provider.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning"),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "And the earth"),
        ])

        let service = DefaultBibleStoreService(provider: provider)
        let verses = try await service.getVersesInRange(
            translation: TranslationID("kjv"),
            startVerseID: VerseID(value: "1:1:1"),
            endVerseID: VerseID(value: "1:1:2"),
            limit: Int.max,
            offset: 0
        )

        XCTAssertEqual(verses.map(\.text), ["In the beginning", "And the earth"])
        XCTAssertEqual(verses.first?.translation, TranslationID("kjv"))
    }

    func testTranslationsListsRegisteredTranslations() async throws {
        let dataSource = try await VerseDataSource.create()
        let provider = BibleStoreProvider(repository: dataSource)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))

        let service = DefaultBibleStoreService(provider: provider)
        let translations = try await service.translations()

        XCTAssertEqual(translations, [Translation(id: TranslationID("kjv"), name: "King James Version", language: "en")])
    }
}
