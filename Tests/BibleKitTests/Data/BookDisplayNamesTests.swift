import XCTest
@testable import BibleKit

final class BookDisplayNamesTests: XCTestCase {
    func testAfrikaansNameForGenesis() {
        XCTAssertEqual(BookDisplayNames.name(for: .Genesis, translation: TranslationID("afrikaans-2020")), "Genesis")
    }

    func testAfrikaansNameForExodusDiffersFromEnglish() {
        XCTAssertEqual(BookDisplayNames.name(for: .Exodus, translation: TranslationID("afrikaans-2020")), "Eksodus")
    }

    func testEnglishNameFallsBackToBookNameValue() {
        XCTAssertEqual(BookDisplayNames.name(for: .Exodus, translation: TranslationID("english-kjv")), "Exodus")
    }

    func testUnknownTranslationFallsBackToBookNameValue() {
        XCTAssertEqual(BookDisplayNames.name(for: .Genesis, translation: TranslationID("unknown")), "Genesis")
    }
}
