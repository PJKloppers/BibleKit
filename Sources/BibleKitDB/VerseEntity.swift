import Foundation

/// A single verse row as stored in BibleKitDB, scoped to one translation.
public struct VerseEntity: Equatable, Sendable {
    /// The translation this verse belongs to (matches Translation.id).
    public let translationId: String
    /// "book:chapter:verse", e.g. "1:1:1" for Genesis 1:1.
    public let id: String
    public let text: String
    /// Sort/range key derived from `id` — stable within a translation, not globally
    /// unique across translations (that's what `translationId` is for).
    let sortKey: Int

    public init(translationId: String, id: String, text: String) {
        self.translationId = translationId
        self.id = id
        self.text = text
        self.sortKey = Self.sortKey(id: id)
    }
}

extension VerseEntity {
    public static func sortKey(id: String) -> Int {
        func pad(_ number: String) -> String {
            switch number.count {
            case 1: "00\(number)"
            case 2: "0\(number)"
            default: number
            }
        }

        let components = id.split(separator: ":")
        guard components.count == 3 else {
            fatalError("Invalid number string formed from id")
        }

        let paddedChapter = pad(String(components[1]))
        let paddedVerse = pad(String(components[2]))
        let numberString = String(components[0]) + paddedChapter + paddedVerse

        guard let key = Int(numberString) else {
            fatalError("Invalid number string formed from id")
        }
        return key
    }
}

/// One available translation in the shared database.
public struct TranslationEntity: Equatable, Sendable {
    public let id: String
    public let name: String
    public let language: String

    public init(id: String, name: String, language: String) {
        self.id = id
        self.name = name
        self.language = language
    }
}
