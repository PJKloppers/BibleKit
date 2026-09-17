import BibleKitDB
import Foundation

final class DefaultBibleStoreService: BibleStoreService, Sendable {
    let provider: BibleStoreProvider

    init(provider: BibleStoreProvider) {
        self.provider = provider
    }

    func searchVerses(translation: TranslationID, text: String, verseIDs: [VerseID]?, limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.searchVerses(
            translationId: translation.rawValue,
            text: text,
            verseIDs: verseIDs?.map(\.value),
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func searchVersesInRange(translation: TranslationID, text: String, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.searchVersesInRange(
            translationId: translation.rawValue,
            text: text,
            startVerse: startVerseID.value,
            endVerse: endVerseID.value,
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func getVerses(translation: TranslationID, verseIDs: [VerseID], limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.getVerses(
            translationId: translation.rawValue,
            verseIDs: verseIDs.map(\.value),
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func getVersesInRange(translation: TranslationID, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.getVersesInRange(
            translationId: translation.rawValue,
            startVerse: startVerseID.value,
            endVerse: endVerseID.value,
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func translations() async throws -> [Translation] {
        let entities = try await provider.translations()
        return entities.map { Translation(id: TranslationID($0.id), name: $0.name, language: $0.language) }
    }

    func importXML(url: URL, translationID: TranslationID, displayName: String, language: String) async throws -> Translation {
        let verses = try BibleXMLImporter.parse(url: url, translationId: translationID.rawValue)
        try await provider.registerTranslation(TranslationEntity(id: translationID.rawValue, name: displayName, language: language))
        try await provider.insertVerses(verses)
        return Translation(id: translationID, name: displayName, language: language)
    }
}
