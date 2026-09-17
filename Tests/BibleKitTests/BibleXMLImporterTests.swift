import XCTest
@testable import BibleKit

final class BibleXMLImporterTests: XCTestCase {
    private func writeXML(_ xml: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testParsesVersesWithTranslationId() throws {
        let url = try writeXML("""
        <bible translation="Test">
          <book number="1">
            <chapter number="1">
              <verse number="1">In the beginning</verse>
              <verse number="2">And the earth</verse>
            </chapter>
          </book>
        </bible>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let verses = try BibleXMLImporter.parse(url: url, translationId: "test-translation")

        XCTAssertEqual(verses.count, 2)
        XCTAssertEqual(verses[0].translationId, "test-translation")
        XCTAssertEqual(verses[0].id, "1:1:1")
        XCTAssertEqual(verses[0].text, "In the beginning")
        XCTAssertEqual(verses[1].id, "1:1:2")
    }

    func testTrimsWhitespaceFromVerseText() throws {
        let url = try writeXML("""
        <bible translation="Test">
          <book number="1"><chapter number="1"><verse number="1">
            padded text
          </verse></chapter></book>
        </bible>
        """)
        defer { try? FileManager.default.removeItem(at: url) }

        let verses = try BibleXMLImporter.parse(url: url, translationId: "test-translation")

        XCTAssertEqual(verses.first?.text, "padded text")
    }
}
