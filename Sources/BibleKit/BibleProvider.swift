import BibleKitDB
import Foundation

/// Main entry point for reading and searching Bible content across every translation
/// loaded into the shared database.
public final class BibleProvider: Sendable {
    private let store: BibleStoreService

    init(store: BibleStoreService) {
        self.store = store
    }

    /// Opens an existing database file (must already contain the BibleKitDB schema).
    public static func create(url: URL) -> BibleProvider {
        let provider = BibleStoreProvider.create(url: url)
        return BibleProvider(store: DefaultBibleStoreService(provider: provider))
    }

    /// Creates a new, empty database file at `url`, ready for `importXML`.
    public static func createEmpty(url: URL) async throws -> BibleProvider {
        let provider = try await BibleStoreProvider.createEmpty(url: url)
        return BibleProvider(store: DefaultBibleStoreService(provider: provider))
    }

    public func search(
        translation: TranslationID,
        query: String,
        verseIDs: [VerseID]? = nil,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return try await store.searchVerses(translation: translation, text: query, verseIDs: verseIDs, limit: limit, offset: offset)
    }

    public func search(
        translation: TranslationID,
        query: String,
        reference: Reference,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        let fixedReference = reference.fixup()
        return try await store.searchVersesInRange(
            translation: translation,
            text: query,
            startVerseID: fixedReference.from.verseID(),
            endVerseID: fixedReference.to.verseID(),
            limit: limit,
            offset: offset
        )
    }

    public func chapter(
        translation: TranslationID,
        chapter: ChapterReference,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        try await store.getVersesInRange(
            translation: translation,
            startVerseID: chapter.startVerseID,
            endVerseID: chapter.endVerseID,
            limit: limit,
            offset: offset
        )
    }

    public func book(
        translation: TranslationID,
        book: Book,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        try await store.getVersesInRange(
            translation: translation,
            startVerseID: book.startVerseID,
            endVerseID: book.endVerseID,
            limit: limit,
            offset: offset
        )
    }

    public func verses(
        translation: TranslationID,
        ids: [VerseID],
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        try await store.getVerses(translation: translation, verseIDs: ids, limit: limit, offset: offset)
    }

    public func translations() async throws -> [Translation] {
        try await store.translations()
    }
}
