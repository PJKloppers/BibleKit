import BibleKitDB
import Foundation

/// A single verse, scoped to one translation. `id` alone doesn't identify verse text —
/// the same VerseID exists once per translation.
public struct Verse: Equatable, Hashable, Sendable {
    public let id: VerseID
    public let translation: TranslationID
    public let text: String
    let sortKey: Int

    public init(id: VerseID, translation: TranslationID, text: String) {
        self.id = id
        self.translation = translation
        self.text = text
        self.sortKey = VerseEntity.sortKey(id: id.value)
    }
}

extension Verse {
    /// Groups a list of verses (single translation, single book) into continuous ranges.
    public static func selectedVerseRange(verses: [Verse]) -> [SelectedVerseRange] {
        guard !verses.isEmpty else {
            fatalError("Verses should not be empty.")
        }

        let allTranslations = Set(verses.map(\.translation))
        guard allTranslations.count == 1 else {
            fatalError("Multiple translations not supported.")
        }

        let sortedVerses = verses.sorted { $0.sortKey < $1.sortKey }
        let allBooks = Set(sortedVerses.map { $0.id.components().first! }).sorted()

        guard allBooks.count == 1 else {
            fatalError("Multiple books not supported.")
        }

        let bookName = sortedVerses.first!.id.bookName()

        let selectedVerses: [SelectedVerseRange] = {
            if sortedVerses.count == 1 {
                let components = sortedVerses.first!.id.components()
                return [
                    SelectedVerseRange(
                        startBook: components.first!,
                        endBook: components.first!,
                        startChapter: components.dropFirst().first!,
                        endChapter: components.dropFirst().first!,
                        startVerse: components.last!,
                        endVerse: components.last!
                    ),
                ]
            } else {
                var selectedVerses = [SelectedVerseRange]()

                let allVerseIDs = BookCollection.mapping[bookName]!
                    .allVerseIDs()
                    .drop {
                        VerseEntity.sortKey(id: $0.value) <
                            VerseEntity.sortKey(id: sortedVerses.first!.id.value)
                    }

                var selectedVerseIDs: [Verse] = sortedVerses.reversed()

                var calculatingRange = false
                var startChapter: Int = selectedVerseIDs.last!.id.components().dropFirst().first!
                var endChapter: Int = selectedVerseIDs.last!.id.components().dropFirst().first!
                var startIdx: Int = selectedVerseIDs.last!.id.components().last!
                var endIdx: Int = selectedVerseIDs.last!.id.components().last!

                func addBreak() {
                    selectedVerses.append(
                        SelectedVerseRange(
                            startBook: sortedVerses.first!.id.components().first!,
                            endBook: sortedVerses.first!.id.components().first!,
                            startChapter: startChapter,
                            endChapter: endChapter,
                            startVerse: startIdx,
                            endVerse: endIdx
                        )
                    )
                }

                for verseId in allVerseIDs {
                    if verseId.value == selectedVerseIDs.last?.id.value {
                        if !calculatingRange {
                            startChapter = verseId.components().dropFirst().first!
                            startIdx = verseId.components().last!
                        }
                        calculatingRange = true
                        endChapter = verseId.components().dropFirst().first!
                        endIdx = verseId.components().last!
                        selectedVerseIDs = Array(selectedVerseIDs.dropLast(1))
                    } else if selectedVerseIDs.isEmpty {
                        break
                    } else {
                        if calculatingRange { addBreak() }
                        calculatingRange = false
                    }
                }

                addBreak()
                return selectedVerses
            }
        }()

        return selectedVerses
    }

    /// Formats verses for sharing, with chapter numbers added when crossing a chapter
    /// boundary. Single translation, single book only.
    public static func shareVersesText(verses: [Verse]) -> [String] {
        guard !verses.isEmpty else {
            fatalError("Verses should not be empty.")
        }

        let allTranslations = Set(verses.map(\.translation))
        guard allTranslations.count == 1 else {
            fatalError("Multiple translations not supported.")
        }

        let sortedVerses = verses.sorted { $0.sortKey < $1.sortKey }
        let allBooks = Set(sortedVerses.map { $0.id.components().first! }).sorted()

        guard allBooks.count == 1 else {
            fatalError("Multiple books not supported.")
        }

        let bookName = sortedVerses.first!.id.bookName()
        let startBook = BookCollection.mapping[bookName]!

        var addChapterPrefix = false
        var versesText = [String]()

        var startChapter: Int = sortedVerses.first!.id.components().dropFirst().first!

        if sortedVerses.count == 1 {
            versesText.append(sortedVerses.first!.text)
        } else {
            for verse in sortedVerses {
                let currentChapter = verse.id.components().dropFirst().first!

                var prefix = ""

                if addChapterPrefix || startChapter != currentChapter {
                    prefix = "\(verse.id.components().dropFirst().first!):"
                }

                versesText.append("[\(prefix)\(verse.id.components().last!)] \(verse.text)")

                if startBook.totalVerses(chapter: currentChapter) == verse.id.components().last! {
                    if startBook.totalChapters == currentChapter {
                        // Nothing left to select in this book.
                    } else {
                        addChapterPrefix = true
                    }
                } else {
                    addChapterPrefix = false
                }

                startChapter = currentChapter
            }
        }

        return versesText
    }

    /// A complete share string, e.g. "Genesis 1:1-3 - [1] In the beginning… [2] …".
    public static func createShareText(verses: [Verse]) -> String {
        let title = SelectedVerseRange.shareTitle(range: selectedVerseRange(verses: verses))
        let verseText = shareVersesText(verses: verses).joined(separator: " ")
        return "\(title) - \(verseText)"
    }
}
