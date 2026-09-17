import Foundation

/// Identifies a translation stored in the shared BibleKit database — a stable slug
/// like "afrikaans-2020", not a display name.
public struct TranslationID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// One translation available in the shared database.
public struct Translation: Identifiable, Equatable, Sendable {
    public let id: TranslationID
    public let name: String
    public let language: String

    public init(id: TranslationID, name: String, language: String) {
        self.id = id
        self.name = name
        self.language = language
    }
}
