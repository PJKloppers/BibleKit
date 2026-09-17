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

    public private(set) var state: LoadState = .idle
    public let translation = TranslationID("afrikaans-2020")

    private var provider: BibleProvider?

    public init() {}

    public func load() {
        guard state != .loaded else { return }
        state = .loading
        guard let url = Bundle.module.url(forResource: "bible", withExtension: "db") else {
            state = .failed("Bundled Bible database not found.")
            return
        }
        provider = BibleProvider.create(url: url)
        state = .loaded
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
