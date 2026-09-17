import Foundation

/// Event-driven parse of the Bible XML. Only <verse> elements carry text, so a single
/// "inside a verse" flag is enough to collect the chapter content. Runs off the main actor,
/// since parsing is synchronous CPU work.
public final class BibleParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    public static func parse(url: URL) throws -> (translation: String, books: [BibleBook]) {
        guard let parser = XMLParser(contentsOf: url) else {
            throw CocoaError(.fileReadUnknown)
        }
        let delegate = BibleParser()
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return (delegate.translation, delegate.books)
    }

    /// Parses the translation bundled with BibleKit (Afrikaans 2020).
    public static func parseBundled() throws -> (translation: String, books: [BibleBook]) {
        guard let url = Bundle.module.url(forResource: "Afrikaans2020Bible", withExtension: "xml") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try parse(url: url)
    }

    private(set) var translation = ""
    private(set) var books: [BibleBook] = []

    private var inVerse = false
    private var bookNumber = 0
    private var chapterNumber = 0
    private var verseNumber = 0
    private var verseText = ""
    private var bookChapters: [BibleChapter] = []
    private var chapterVerses: [BibleVerse] = []

    public func parser(_ parser: XMLParser, didStartElement elementName: String,
                        namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "bible":
            translation = attributes["translation"] ?? ""
        case "book":
            bookNumber = Int(attributes["number"] ?? "") ?? 0
            bookChapters = []
        case "chapter":
            chapterNumber = Int(attributes["number"] ?? "") ?? 0
            chapterVerses = []
        case "verse":
            verseNumber = Int(attributes["number"] ?? "") ?? 0
            verseText = ""
            inVerse = true
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inVerse else { return }
        verseText += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String,
                        namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "verse":
            let text = verseText.trimmingCharacters(in: .whitespacesAndNewlines)
            chapterVerses.append(BibleVerse(id: verseNumber, text: text))
            inVerse = false
        case "chapter":
            bookChapters.append(BibleChapter(id: chapterNumber, verses: chapterVerses))
        case "book":
            let testament: BibleTestament = bookNumber <= 39 ? .old : .new
            books.append(BibleBook(id: bookNumber, name: Self.bookName(for: bookNumber),
                                    testament: testament, chapters: bookChapters))
        default:
            break
        }
    }

    public static func bookName(for number: Int) -> String {
        guard (1...bibleBookNames.count).contains(number) else { return "Book \(number)" }
        return bibleBookNames[number - 1]
    }
}
