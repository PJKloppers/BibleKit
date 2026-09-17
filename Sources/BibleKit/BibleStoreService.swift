import Foundation

/// Bridges BibleKitDB's translation-scoped verse entities to BibleKit's public `Verse` model.
protocol BibleStoreService: Sendable {
    func searchVerses(translation: TranslationID, text: String, verseIDs: [VerseID]?, limit: Int, offset: Int) async throws -> [Verse]
    func searchVersesInRange(translation: TranslationID, text: String, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse]
    func getVerses(translation: TranslationID, verseIDs: [VerseID], limit: Int, offset: Int) async throws -> [Verse]
    func getVersesInRange(translation: TranslationID, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse]
    func translations() async throws -> [Translation]
}
