import SwiftUI

/// A simple, self-contained Bible reading screen: book list -> chapter list -> chapter text.
/// Loads the translation bundled with BibleKit; drop this view into any SwiftUI app.
public struct BibleReaderView: View {
    @State private var model = BibleReaderModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .idle, .loading:
                    ProgressView("Reading the Bible…")
                case .failed(let message):
                    ContentUnavailableView("Can't read the Bible", systemImage: "exclamationmark.triangle", description: Text(message))
                case .loaded:
                    bookList
                }
            }
            .navigationTitle("Bible")
            .navigationDestination(for: BookName.self) { bookName in
                chapterList(for: bookName)
            }
            .navigationDestination(for: ChapterReference.self) { chapter in
                ChapterDetailView(model: model, chapter: chapter)
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    translationMenu
                }
            }
        }
        .task { model.load() }
    }

    @ViewBuilder
    private var translationMenu: some View {
        if model.availableTranslations.count > 1 {
            Menu {
                Picker("Translation", selection: Binding(
                    get: { model.translation },
                    set: { model.selectTranslation($0) }
                )) {
                    ForEach(model.availableTranslations) { translation in
                        Text(translation.name).tag(translation.id)
                    }
                }
            } label: {
                Label("Translation", systemImage: "globe")
            }
        }
    }

    private var oldTestamentBooks: [Book] { BookCollection.oldTestamentBooks }
    private var newTestamentBooks: [Book] { BookCollection.newTestamentBooks }

    private var bookList: some View {
        List {
            Section {
                ForEach(oldTestamentBooks, id: \.bookName) { book in
                    NavigationLink(value: book.bookName) { bookRow(book) }
                }
            } header: {
                testamentHeader("Old Testament", count: oldTestamentBooks.count)
            }
            Section {
                ForEach(newTestamentBooks, id: \.bookName) { book in
                    NavigationLink(value: book.bookName) { bookRow(book) }
                }
            } header: {
                testamentHeader("New Testament", count: newTestamentBooks.count)
            }
        }
    }

    private func testamentHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count) books")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    private func bookRow(_ book: Book) -> some View {
        HStack {
            Text(model.displayName(for: book))
            Spacer()
            Text("\(book.totalChapters) chapters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chapterList(for bookName: BookName) -> some View {
        let book = BookCollection.mapping[bookName]!
        return List {
            ForEach(1...book.totalChapters, id: \.self) { chapterIndex in
                let chapter = ChapterReference(bookName: bookName, index: chapterIndex)
                NavigationLink(value: chapter) {
                    HStack {
                        Text("Chapter \(chapterIndex)")
                        Spacer()
                        Text("\(book.totalVerses(chapter: chapterIndex)) verses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(model.displayName(for: book))
    }
}

/// Fetches and displays one chapter's verses on demand.
private struct ChapterDetailView: View {
    let model: BibleReaderModel
    let chapter: ChapterReference

    @State private var verses: [Verse] = []
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            if let loadError {
                ContentUnavailableView("Can't load this chapter", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if verses.isEmpty {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.displayName(for: BookCollection.mapping[chapter.bookName]!))
                        .font(.system(.largeTitle, design: .serif))
                        .bold()
                    Text("Chapter \(chapter.index)")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary)

                    Divider()

                    ForEach(verses, id: \.id) { verse in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(verse.id.chapterVerseNumbers().last ?? 0)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            Text(verse.text)
                                .font(.system(.body, design: .serif))
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle("\(model.displayName(for: BookCollection.mapping[chapter.bookName]!)) \(chapter.index)")
        .task(id: ReloadKey(chapter: chapter, translation: model.translation)) { await loadVerses() }
    }

    private struct ReloadKey: Equatable {
        let chapter: ChapterReference
        let translation: TranslationID
    }

    private func loadVerses() async {
        loadError = nil
        do {
            verses = try await model.verses(chapter: chapter)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    BibleReaderView()
}
