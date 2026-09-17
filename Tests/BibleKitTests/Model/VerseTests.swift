import XCTest
@testable import BibleKit

final class VerseTests: XCTestCase {
    func testSelectedVerseRangeSingleVerse() {
        let verse = Verse(id: VerseID(value: "1:1:1"), translation: TranslationID("kjv"), text: "In the beginning")
        let ranges = Verse.selectedVerseRange(verses: [verse])
        XCTAssertEqual(ranges.count, 1)
    }

    func testShareVersesTextSingleVerse() {
        let verse = Verse(id: VerseID(value: "1:1:1"), translation: TranslationID("kjv"), text: "In the beginning")
        XCTAssertEqual(Verse.shareVersesText(verses: [verse]), ["In the beginning"])
    }

    func testCreateShareTextIncludesBookAndChapter() {
        let verse = Verse(id: VerseID(value: "1:1:1"), translation: TranslationID("kjv"), text: "In the beginning")
        XCTAssertTrue(Verse.createShareText(verses: [verse]).hasPrefix("Genesis 1:1"))
    }

    func testShareVersesTextAddsChapterPrefixWhenCrossingChapters() {
        let verses = [
            Verse(id: VerseID(value: "1:1:31"), translation: TranslationID("kjv"), text: "Last verse of chapter 1"),
            Verse(id: VerseID(value: "1:2:1"), translation: TranslationID("kjv"), text: "First verse of chapter 2"),
        ]
        XCTAssertEqual(
            Verse.shareVersesText(verses: verses),
            ["[31] Last verse of chapter 1", "[2:1] First verse of chapter 2"]
        )
    }
}
