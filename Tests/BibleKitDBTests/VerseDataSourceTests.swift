import GRDB
import XCTest
@testable import BibleKitDB

final class VerseDataSourceTests: XCTestCase {
    private func makeDataSource() async throws -> VerseDataSource {
        try await VerseDataSource.create()
    }

    func testInsertAndFetchVersesInRangeScopedByTranslation() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning"),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "And the earth"),
        ])

        let verses = try await dataSource.getVersesInRange(
            translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:2", limit: Int.max, offset: 0
        )

        XCTAssertEqual(verses.map(\.text), ["In the beginning", "And the earth"])
    }

    func testTwoTranslationsCanShareTheSameVerseNumber() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.registerTranslation(TranslationEntity(id: "afrikaans-2020", name: "Afrikaans 2020", language: "af"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning"),
            VerseEntity(translationId: "afrikaans-2020", id: "1:1:1", text: "In die begin"),
        ])

        let kjv = try await dataSource.getVersesInRange(translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)
        let afr = try await dataSource.getVersesInRange(translationId: "afrikaans-2020", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)

        XCTAssertEqual(kjv.first?.text, "In the beginning")
        XCTAssertEqual(afr.first?.text, "In die begin")
    }

    func testInsertingDuplicateVerseNumberForSameTranslationThrows() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "First")])

        do {
            try await dataSource.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "Duplicate")])
            XCTFail("Expected duplicate insert to throw")
        } catch {
            // expected — unique index on (translationId, number)
        }
    }

    func testSearchVersesPrioritizesExactPhraseMatch() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "God created the heaven"),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "the heaven and God"),
        ])

        let results = try await dataSource.searchVerses(translationId: "kjv", text: "God created", limit: Int.max, offset: 0)

        XCTAssertEqual(results.first?.id, "1:1:1")
    }

    func testSearchVersesDoesNotLeakAcrossTranslations() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.registerTranslation(TranslationEntity(id: "other", name: "Other", language: "en"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "onlyinbothtranslations"),
            VerseEntity(translationId: "other", id: "1:1:1", text: "onlyinbothtranslations"),
        ])

        let results = try await dataSource.searchVerses(translationId: "kjv", text: "onlyinbothtranslations", limit: Int.max, offset: 0)

        XCTAssertEqual(results.count, 1)
    }

    func testTranslationsListsRegisteredTranslations() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))

        let translations = try await dataSource.translations()

        XCTAssertEqual(translations, [TranslationEntity(id: "kjv", name: "King James Version", language: "en")])
    }
}
