import Foundation
import GRDB

/// A GRDB/SQLite-backed VerseRepository. Verses from every translation live in one
/// database, scoped by `translationId` — see
/// docs/superpowers/specs/2026-09-17-versewell-transplant-design.md for why this
/// differs from VerseWell/BibleKit-swift's one-db-per-translation schema.
final class VerseDataSource: VerseRepository, Sendable {
    struct Verse: Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "Verse"

        var translationId: String
        var number: String
        var sortKey: Int
        var text: String
        var searchText: String
    }

    private let databaseWriter: DatabaseWriter

    init(databaseWriter: DatabaseWriter) {
        self.databaseWriter = databaseWriter
    }

    convenience init(url: URL) {
        self.init(databaseWriter: try! DatabaseQueue(path: url.path))
    }

    static func create(dbQueue: DatabaseQueue = try! DatabaseQueue()) async throws -> VerseDataSource {
        try await dbQueue.write { db in
            try db.create(table: "Translation") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("language", .text).notNull()
            }

            try db.create(table: "Verse") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("translationId", .text).notNull().references("Translation", column: "id")
                t.column("number", .text).notNull()
                t.column("sortKey", .integer).notNull()
                t.column("text", .text).notNull()
                t.column("searchText", .text).notNull()
            }
            try db.create(index: "Verse_translation_number", on: "Verse", columns: ["translationId", "number"], unique: true)
            try db.create(index: "Verse_translation_sortKey", on: "Verse", columns: ["translationId", "sortKey"])

            try db.create(virtualTable: "VerseFts", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.content = "Verse"
                t.column("searchText")
                t.synchronize(withTable: "Verse")
            }
        }
        return VerseDataSource(databaseWriter: dbQueue)
    }

    func registerTranslation(_ translation: TranslationEntity) async throws {
        try await databaseWriter.write { db in
            try db.execute(
                sql: "INSERT INTO Translation (id, name, language) VALUES (?, ?, ?)",
                arguments: [translation.id, translation.name, translation.language]
            )
        }
    }

    func translations() async throws -> [TranslationEntity] {
        try await databaseWriter.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, language FROM Translation ORDER BY id")
                .map { TranslationEntity(id: $0["id"], name: $0["name"], language: $0["language"]) }
        }
    }

    func searchVerses(translationId: String, text: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await databaseWriter.read { db in
            let phraseSearchTerm = "\"\(text)\""
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM (
                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 0 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(phraseSearchTerm)) AS exact_matches
                    ON Verse.id = exact_matches.rowid
                WHERE Verse.translationId = \(translationId)

                UNION

                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 1 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(text)) AS word_matches
                    ON Verse.id = word_matches.rowid
                WHERE Verse.translationId = \(translationId)
                AND Verse.id NOT IN (
                    SELECT Verse.id FROM Verse
                    JOIN VerseFts ON Verse.id = VerseFts.rowid
                    WHERE VerseFts.searchText MATCH \(phraseSearchTerm) AND Verse.translationId = \(translationId)
                )
            )
            ORDER BY priority, sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func searchVersesInRange(
        translationId: String,
        text: String,
        startVerse: String,
        endVerse: String,
        limit: Int,
        offset: Int
    ) async throws -> [VerseEntity] {
        let start = VerseEntity.sortKey(id: startVerse)
        let end = VerseEntity.sortKey(id: endVerse)
        return try await databaseWriter.read { db in
            let phraseSearchTerm = "\"\(text)\""
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM (
                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 0 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(phraseSearchTerm)) AS exact_matches
                    ON Verse.id = exact_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.sortKey BETWEEN \(start) AND \(end)

                UNION

                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 1 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(text)) AS word_matches
                    ON Verse.id = word_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.sortKey BETWEEN \(start) AND \(end)
                AND Verse.id NOT IN (
                    SELECT Verse.id FROM Verse
                    JOIN VerseFts ON Verse.id = VerseFts.rowid
                    WHERE VerseFts.searchText MATCH \(phraseSearchTerm) AND Verse.translationId = \(translationId)
                )
            )
            ORDER BY priority, sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func searchVersesByIds(
        translationId: String,
        text: String,
        verseIDs: [String],
        limit: Int,
        offset: Int
    ) async throws -> [VerseEntity] {
        try await databaseWriter.read { db in
            let phraseSearchTerm = "\"\(text)\""
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM (
                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 0 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(phraseSearchTerm)) AS exact_matches
                    ON Verse.id = exact_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.number IN \(verseIDs)

                UNION

                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 1 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(text)) AS word_matches
                    ON Verse.id = word_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.number IN \(verseIDs)
                AND Verse.id NOT IN (
                    SELECT Verse.id FROM Verse
                    JOIN VerseFts ON Verse.id = VerseFts.rowid
                    WHERE VerseFts.searchText MATCH \(phraseSearchTerm) AND Verse.translationId = \(translationId)
                )
            )
            ORDER BY priority, sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func getVersesByIds(translationId: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await databaseWriter.read { db in
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM Verse
            WHERE translationId = \(translationId) AND number IN \(verseIDs)
            ORDER BY sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func getVersesInRange(translationId: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        let start = VerseEntity.sortKey(id: startVerse)
        let end = VerseEntity.sortKey(id: endVerse)
        return try await databaseWriter.read { db in
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM Verse
            WHERE translationId = \(translationId) AND sortKey BETWEEN \(start) AND \(end)
            ORDER BY sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func insertVerses(_ verses: [VerseEntity]) async throws {
        try await databaseWriter.write { db in
            for verse in verses {
                try Verse(
                    translationId: verse.translationId,
                    number: verse.id,
                    sortKey: verse.sortKey,
                    text: verse.text,
                    searchText: verse.text
                ).insert(db)
            }
        }
    }
}
