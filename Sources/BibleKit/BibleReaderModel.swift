import Foundation
import Observation

/// Parses the bundled translation off the main actor, then publishes the result back on it.
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
    public private(set) var translation = ""
    public private(set) var books: [BibleBook] = []

    private var loadTask: Task<Void, Never>?

    public init() {}

    public func load() {
        guard state != .loaded, loadTask == nil else { return }
        state = .loading
        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let parsed = try BibleParser.parseBundled()
                await self?.finishLoad(.success(parsed))
            } catch {
                await self?.finishLoad(.failure(error))
            }
        }
    }

    private func finishLoad(_ result: Result<(translation: String, books: [BibleBook]), Error>) {
        loadTask = nil
        switch result {
        case .success(let parsed):
            translation = parsed.translation
            books = parsed.books
            state = .loaded
        case .failure(let error):
            state = .failed(error.localizedDescription)
        }
    }
}
