import SwiftUI

/// A pushed chapter: the book and chapter the reader is showing.
private struct BibleChapterRef: Hashable {
    let book: Int
    let chapter: Int
}

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
            .navigationDestination(for: Int.self) { bookID in
                chapterList(for: bookID)
            }
            .navigationDestination(for: BibleChapterRef.self) { ref in
                chapterView(ref)
            }
        }
        .task { model.load() }
    }

    private var oldTestamentBooks: [BibleBook] {
        model.books.filter { $0.testament == .old }
    }

    private var newTestamentBooks: [BibleBook] {
        model.books.filter { $0.testament == .new }
    }

    private var bookList: some View {
        List {
            Section {
                ForEach(oldTestamentBooks) { book in
                    NavigationLink(value: book.id) { bookRow(book) }
                }
            } header: {
                testamentHeader("Old Testament", count: oldTestamentBooks.count)
            }
            Section {
                ForEach(newTestamentBooks) { book in
                    NavigationLink(value: book.id) { bookRow(book) }
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

    private func bookRow(_ book: BibleBook) -> some View {
        HStack {
            Text(book.name)
            Spacer()
            Text("\(book.chapters.count) chapters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chapterList(for bookID: Int) -> some View {
        List {
            if let book = model.books.first(where: { $0.id == bookID }) {
                ForEach(book.chapters) { chapter in
                    NavigationLink(value: BibleChapterRef(book: book.id, chapter: chapter.id)) {
                        HStack {
                            Text("Chapter \(chapter.id)")
                            Spacer()
                            Text("\(chapter.verses.count) verses")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.books.first { $0.id == bookID }?.name ?? "")
    }

    private func chapterView(_ ref: BibleChapterRef) -> some View {
        ScrollView {
            if let book = model.books.first(where: { $0.id == ref.book }),
               let chapter = book.chapters.first(where: { $0.id == ref.chapter }) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(book.name)
                        .font(.system(.largeTitle, design: .serif))
                        .bold()
                    Text("Chapter \(chapter.id)")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary)

                    Divider()

                    ForEach(chapter.verses) { verse in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(verse.id)")
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
        .navigationTitle("\(model.books.first { $0.id == ref.book }?.name ?? "") \(ref.chapter)")
    }
}

#Preview {
    BibleReaderView()
}
