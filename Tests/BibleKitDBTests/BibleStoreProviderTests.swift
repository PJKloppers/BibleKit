import Foundation
import XCTest
@testable import BibleKitDB

final class BibleStoreProviderTests: XCTestCase {
    func testCreateEmptyThenRoundTripsAVerse() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try await BibleStoreProvider.createEmpty(url: url)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await provider.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning")])

        let verses = try await provider.getVersesInRange(translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)

        XCTAssertEqual(verses.first?.text, "In the beginning")
    }

    func testCreateOpensAnExistingDatabaseFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try await BibleStoreProvider.createEmpty(url: url)
        try await writer.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await writer.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning")])

        let reader = BibleStoreProvider.create(url: url)
        let verses = try await reader.getVersesInRange(translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)

        XCTAssertEqual(verses.first?.text, "In the beginning")
    }

    func testSearchVersesWithoutIdsSearchesEverything() async throws {
        let dataSource = try await VerseDataSource.create()
        let provider = BibleStoreProvider(repository: dataSource)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await provider.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "findme")])

        let results = try await provider.searchVerses(translationId: "kjv", text: "findme", limit: Int.max, offset: 0)

        XCTAssertEqual(results.count, 1)
    }
}
