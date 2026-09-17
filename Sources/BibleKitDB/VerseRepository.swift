import Foundation

/// The repository for accessing verse rows in the shared, multi-translation database.
public protocol VerseRepository: Sendable {
    func searchVerses(translationId: String, text: String, limit: Int, offset: Int) async throws -> [VerseEntity]
    func searchVersesInRange(translationId: String, text: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity]
    func searchVersesByIds(translationId: String, text: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity]
    func getVersesByIds(translationId: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity]
    func getVersesInRange(translationId: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity]
    func insertVerses(_ verses: [VerseEntity]) async throws
    func registerTranslation(_ translation: TranslationEntity) async throws
    func translations() async throws -> [TranslationEntity]
}
