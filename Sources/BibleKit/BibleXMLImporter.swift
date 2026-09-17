import BibleKitDB
import Foundation

/// Streaming XML parse of a Holy-Bible-XML-Format file into database-ready verse rows.
/// Only <verse> elements carry text, so a single "inside a verse" flag is enough to
/// collect content. Runs off the main actor, since parsing is synchronous CPU work.
final class BibleXMLImporter: NSObject, XMLParserDelegate, @unchecked Sendable {
    static func parse(url: URL, translationId: String) throws -> [VerseEntity] {
        guard let parser = XMLParser(contentsOf: url) else {
            throw CocoaError(.fileReadUnknown)
        }
        let delegate = BibleXMLImporter(translationId: translationId)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? CocoaError(.fileReadCorruptFile)
        }
        return delegate.verses
    }

    private let translationId: String
    private(set) var verses: [VerseEntity] = []

    private var inVerse = false
    private var bookNumber = 0
    private var chapterNumber = 0
    private var verseNumber = 0
    private var verseText = ""

    private init(translationId: String) {
        self.translationId = translationId
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        switch elementName {
        case "book":
            bookNumber = Int(attributes["number"] ?? "") ?? 0
        case "chapter":
            chapterNumber = Int(attributes["number"] ?? "") ?? 0
        case "verse":
            verseNumber = Int(attributes["number"] ?? "") ?? 0
            verseText = ""
            inVerse = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inVerse else { return }
        verseText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        guard elementName == "verse" else { return }
        let text = verseText.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = "\(bookNumber):\(chapterNumber):\(verseNumber)"
        verses.append(VerseEntity(translationId: translationId, id: id, text: text))
        inVerse = false
    }
}
