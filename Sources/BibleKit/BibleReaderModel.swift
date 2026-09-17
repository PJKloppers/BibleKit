import Foundation
import Observation

/// Opens the bundled translation via BibleProvider, then serves chapters on demand
/// instead of holding the whole Bible in memory.
@Observable
@MainActor
public final class BibleReaderModel {
    public enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private static let translationDefaultsKey = "BibleReaderModel.selectedTranslation"
    private static let defaultTranslation = TranslationID("afrikaans-2020")

    public private(set) var state: LoadState = .idle
    public private(set) var availableTranslations: [Translation] = []

    public private(set) var translation: TranslationID {
        didSet {
            UserDefaults.standard.set(translation.rawValue, forKey: Self.translationDefaultsKey)
        }
    }

    private var provider: BibleProvider?

    public init() {
        if let saved = UserDefaults.standard.string(forKey: Self.translationDefaultsKey) {
            translation = TranslationID(saved)
        } else {
            translation = Self.defaultTranslation
        }
    }

    public func load() {
        guard state != .loaded else { return }
        state = .loading
        guard let url = Bundle.module.url(forResource: "bible", withExtension: "db") else {
            state = .failed("Bundled Bible database not found.")
            return
        }
        let provider = BibleProvider.create(url: url)
        self.provider = provider
        state = .loaded
        Task {
            availableTranslations = (try? await provider.translations()) ?? []
        }
    }

    public func selectTranslation(_ id: TranslationID) {
        guard id != translation else { return }
        translation = id
    }

    public func displayName(for book: Book) -> String {
        BookDisplayNames.name(for: book.bookName, translation: translation)
    }

    public func verses(chapter: ChapterReference) async throws -> [Verse] {
        guard let provider else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try await provider.chapter(translation: translation, chapter: chapter)
    }
}
