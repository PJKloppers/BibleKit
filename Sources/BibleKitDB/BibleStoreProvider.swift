import Foundation
import GRDB

/// Public entry point to the shared, multi-translation Bible database.
public final class BibleStoreProvider: Sendable {
    private let repository: VerseRepository

    public init(repository: VerseRepository) {
        self.repository = repository
    }

    /// Opens an existing database file. The file must already contain the BibleKitDB
    /// schema (see `createEmpty(url:)`) — this does not create tables.
    public static func create(url: URL) -> BibleStoreProvider {
        BibleStoreProvider(repository: VerseDataSource(url: url))
    }

    /// Creates a new database file at `url` with the BibleKitDB schema, ready for
    /// `registerTranslation`/`insertVerses`.
    public static func createEmpty(url: URL) async throws -> BibleStoreProvider {
        let dataSource = try await VerseDataSource.create(dbQueue: DatabaseQueue(path: url.path))
        return BibleStoreProvider(repository: dataSource)
    }

    public func searchVerses(translationId: String, text: String, verseIDs: [String]? = nil, limit: Int, offset: Int) async throws -> [VerseEntity] {
        if let verseIDs {
            try await repository.searchVersesByIds(translationId: translationId, text: text, verseIDs: verseIDs, limit: limit, offset: offset)
        } else {
            try await repository.searchVerses(translationId: translationId, text: text, limit: limit, offset: offset)
        }
    }

    public func searchVersesInRange(translationId: String, text: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await repository.searchVersesInRange(translationId: translationId, text: text, startVerse: startVerse, endVerse: endVerse, limit: limit, offset: offset)
    }

    public func getVerses(translationId: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await repository.getVersesByIds(translationId: translationId, verseIDs: verseIDs, limit: limit, offset: offset)
    }

    public func getVersesInRange(translationId: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await repository.getVersesInRange(translationId: translationId, startVerse: startVerse, endVerse: endVerse, limit: limit, offset: offset)
    }

    public func insertVerses(_ verses: [VerseEntity]) async throws {
        try await repository.insertVerses(verses)
    }

    public func registerTranslation(_ translation: TranslationEntity) async throws {
        try await repository.registerTranslation(translation)
    }

    public func translations() async throws -> [TranslationEntity] {
        try await repository.translations()
    }
}
