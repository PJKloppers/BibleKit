import BibleKit
import Foundation

@main
struct GenerateBundledDB {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            print("Usage: GenerateBundledDB <xml-directory> <output-db-path>")
            exit(1)
        }
        let xmlDirectory = URL(fileURLWithPath: arguments[1])
        let outputPath = URL(fileURLWithPath: arguments[2])

        if FileManager.default.fileExists(atPath: outputPath.path) {
            try FileManager.default.removeItem(at: outputPath)
        }

        let provider = try await BibleProvider.createEmpty(url: outputPath)

        try await provider.importXML(
            url: xmlDirectory.appendingPathComponent("Afrikaans2020Bible.xml"),
            translationID: TranslationID("afrikaans-2020"),
            displayName: "Afrikaans 2020",
            language: "af"
        )
        print("Imported Afrikaans 2020")

        try await provider.importXML(
            url: xmlDirectory.appendingPathComponent("EnglishKJBible.xml"),
            translationID: TranslationID("english-kjv"),
            displayName: "King James Version",
            language: "en"
        )
        print("Imported English KJV")

        print("Wrote \(outputPath.path)")
    }
}
