import Foundation
import XCTest
@testable import BibleKit

final class BibleProviderImportTests: XCTestCase {
    private func writeFixtureXML() throws -> URL {
        let xml = """
        <bible translation="Test">
          <book number="1"><chapter number="1"><verse number="1">Test verse</verse></chapter></book>
        </bible>
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".xml")
        try xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testImportXMLMakesVersesAvailableViaChapter() async throws {
        let dbURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let xmlURL = try writeFixtureXML()
        defer { try? FileManager.default.removeItem(at: xmlURL) }

        let provider = try await BibleProvider.createEmpty(url: dbURL)
        try await provider.importXML(url: xmlURL, translationID: TranslationID("test"), displayName: "Test Translation", language: "en")

        let verses = try await provider.chapter(translation: TranslationID("test"), chapter: ChapterReference(bookName: .Genesis, index: 1))
        XCTAssertEqual(verses.map(\.text), ["Test verse"])
    }

    func testImportXMLThrowsOnDuplicateTranslationID() async throws {
        let dbURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        let xmlURL = try writeFixtureXML()
        defer { try? FileManager.default.removeItem(at: xmlURL) }

        let provider = try await BibleProvider.createEmpty(url: dbURL)
        try await provider.importXML(url: xmlURL, translationID: TranslationID("test"), displayName: "Test Translation", language: "en")

        do {
            try await provider.importXML(url: xmlURL, translationID: TranslationID("test"), displayName: "Duplicate", language: "en")
            XCTFail("Expected duplicate translation import to throw")
        } catch {
            // expected — unique Translation.id constraint
        }
    }
}
