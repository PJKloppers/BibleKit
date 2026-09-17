import XCTest
@testable import BibleKit

final class TranslationTests: XCTestCase {
    func testTranslationIDRawValueRoundTrips() {
        let id = TranslationID(rawValue: "afrikaans-2020")
        XCTAssertEqual(id.rawValue, "afrikaans-2020")
    }

    func testTranslationIDConvenienceInitMatchesRawValueInit() {
        XCTAssertEqual(TranslationID("kjv"), TranslationID(rawValue: "kjv"))
    }

    func testTranslationIDIsUsableAsADictionaryKey() {
        let names: [TranslationID: String] = [TranslationID("kjv"): "King James Version"]
        XCTAssertEqual(names[TranslationID("kjv")], "King James Version")
    }

    func testTranslationEquality() {
        let a = Translation(id: TranslationID("kjv"), name: "King James Version", language: "en")
        let b = Translation(id: TranslationID("kjv"), name: "King James Version", language: "en")
        XCTAssertEqual(a, b)
    }
}
