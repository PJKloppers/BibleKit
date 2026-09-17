# VerseWell/BibleKit-swift Transplant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace BibleKit's in-memory XML parser with a GRDB/SQLite-backed, multi-translation architecture adapted from VerseWell/BibleKit-swift, and rebuild the SwiftUI reader on top of it.

**Architecture:** Two targets — `BibleKitDB` (GRDB persistence, translation-scoped schema) and `BibleKit` (public models, `BibleProvider` async API, XML import, SwiftUI reader). One shared SQLite database holds every translation, distinguished by a `translationId` column, so the schema diverges from upstream's one-db-per-translation design.

**Tech Stack:** Swift 5.9+, GRDB.swift 7.x, XCTest, XMLParser, SwiftUI/Observation.

**Spec:** [docs/superpowers/specs/2026-09-17-versewell-transplant-design.md](../specs/2026-09-17-versewell-transplant-design.md)

## Global Constraints

- Swift tools version stays 5.9; platforms stay iOS 17 / macOS 14 / visionOS 1 (unchanged from current `Package.swift`).
- GRDB.swift dependency pinned `from: "7.0.0"`.
- No GitHub-side fork — code is adapted from a local shallow clone of `VerseWell/BibleKit-swift`, cloned into `.build/upstream-reference/` (gitignored, ephemeral).
- Full replacement: `BibleModels.swift` and `BibleParser.swift` are deleted once their replacements land (Task 17).
- One shared database for all translations — never one `.db` file per translation.
- Apache 2.0 `LICENSE` and a README credit to VerseWell/BibleKit-swift are required (Task 1).
- Bundled translations are `"afrikaans-2020"` (default) and `"english-kjv"` — both already present in the `Holy-Bible-XML-Format` submodule.
- Non-goals: a translation-switcher UI, cross-translation search UI, and an in-app XML-import settings screen are explicitly out of scope for this plan.

---

### Task 1: LICENSE and README credit

**Files:**
- Create: `LICENSE`
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing code-facing; establishes the Apache 2.0 attribution the rest of the plan depends on legally.

- [ ] **Step 1: Clone the upstream reference (idempotent, reused by later tasks)**

```bash
mkdir -p .build/upstream-reference
[ -d .build/upstream-reference/BibleKit-swift ] || \
  git clone --depth 1 https://github.com/VerseWell/BibleKit-swift.git .build/upstream-reference/BibleKit-swift
```

- [ ] **Step 2: Copy the LICENSE file verbatim**

```bash
cp .build/upstream-reference/BibleKit-swift/LICENSE LICENSE
```

- [ ] **Step 3: Add a Credits section to README.md**

Add this section at the end of `README.md`:

```markdown
## Credits

BibleKit's database layer and provider API are adapted from
[VerseWell/BibleKit-swift](https://github.com/VerseWell/BibleKit-swift)
(Apache License 2.0), extended here to support multiple translations in one
shared database and to import additional translations on-device.
```

- [ ] **Step 4: Verify**

```bash
head -3 LICENSE   # expect "Apache License" / "Version 2.0"
grep -c "Credits" README.md   # expect 1
```

- [ ] **Step 5: Commit**

```bash
git add LICENSE README.md
git commit -m "Add Apache 2.0 LICENSE and credit VerseWell/BibleKit-swift"
```

---

### Task 2: BibleKitDB scaffold — VerseEntity, TranslationEntity

**Files:**
- Modify: `Package.swift`
- Create: `Sources/BibleKitDB/VerseEntity.swift`
- Test: `Tests/BibleKitDBTests/VerseEntityTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `VerseEntity` (translationId/id/text/sortKey), `VerseEntity.sortKey(id:) -> Int`, `TranslationEntity` (id/name/language) — both used by every later BibleKitDB and BibleKit task.

- [ ] **Step 1: Update Package.swift**

Replace the whole file with:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BibleKit",
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "BibleKit", targets: ["BibleKit"]),
        .library(name: "BibleKitDB", targets: ["BibleKitDB"]),
    ],
    dependencies: {
        var dependencies: [Package.Dependency] = [
            .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        ]
        #if !os(iOS)
        dependencies.append(
            .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
        )
        #endif
        return dependencies
    }(),
    targets: [
        .target(
            name: "BibleKit",
            dependencies: ["BibleKitDB"],
            resources: [.copy("Resources/Holy-Bible-XML-Format/Afrikaans2020Bible.xml")]
        ),
        .target(
            name: "BibleKitDB",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "BibleKitDBTests",
            dependencies: ["BibleKitDB"]
        ),
    ]
)
```

- [ ] **Step 2: Write the failing test**

Create `Tests/BibleKitDBTests/VerseEntityTests.swift`:

```swift
import XCTest
@testable import BibleKitDB

final class VerseEntityTests: XCTestCase {
    func testSortKeyPadsChapterAndVerse() {
        XCTAssertEqual(VerseEntity.sortKey(id: "1:1:1"), 1_001_001)
    }

    func testSortKeyForLastVerseOfBible() {
        XCTAssertEqual(VerseEntity.sortKey(id: "66:22:21"), 66_022_021)
    }

    func testSortKeyOrdersVersesWithinABook() {
        XCTAssertLessThan(VerseEntity.sortKey(id: "1:1:31"), VerseEntity.sortKey(id: "1:2:1"))
    }

    func testInitStoresTranslationId() {
        let verse = VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning")
        XCTAssertEqual(verse.translationId, "kjv")
        XCTAssertEqual(verse.text, "In the beginning")
    }

    func testTranslationEntityEquality() {
        let a = TranslationEntity(id: "kjv", name: "King James Version", language: "en")
        let b = TranslationEntity(id: "kjv", name: "King James Version", language: "en")
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
swift test --filter VerseEntityTests
```
Expected: FAIL (build error — `VerseEntity` doesn't exist yet).

- [ ] **Step 4: Implement**

Create `Sources/BibleKitDB/VerseEntity.swift`:

```swift
import Foundation

/// A single verse row as stored in BibleKitDB, scoped to one translation.
public struct VerseEntity: Equatable, Sendable {
    /// The translation this verse belongs to (matches Translation.id).
    public let translationId: String
    /// "book:chapter:verse", e.g. "1:1:1" for Genesis 1:1.
    public let id: String
    public let text: String
    /// Sort/range key derived from `id` — stable within a translation, not globally
    /// unique across translations (that's what `translationId` is for).
    let sortKey: Int

    public init(translationId: String, id: String, text: String) {
        self.translationId = translationId
        self.id = id
        self.text = text
        self.sortKey = Self.sortKey(id: id)
    }
}

extension VerseEntity {
    public static func sortKey(id: String) -> Int {
        func pad(_ number: String) -> String {
            switch number.count {
            case 1: "00\(number)"
            case 2: "0\(number)"
            default: number
            }
        }

        let components = id.split(separator: ":")
        guard components.count == 3 else {
            fatalError("Invalid number string formed from id")
        }

        let paddedChapter = pad(String(components[1]))
        let paddedVerse = pad(String(components[2]))
        let numberString = String(components[0]) + paddedChapter + paddedVerse

        guard let key = Int(numberString) else {
            fatalError("Invalid number string formed from id")
        }
        return key
    }
}

/// One available translation in the shared database.
public struct TranslationEntity: Equatable, Sendable {
    public let id: String
    public let name: String
    public let language: String

    public init(id: String, name: String, language: String) {
        self.id = id
        self.name = name
        self.language = language
    }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
swift test --filter VerseEntityTests
```
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Package.resolved Sources/BibleKitDB Tests/BibleKitDBTests
git commit -m "Add BibleKitDB target with VerseEntity and TranslationEntity"
```

---

### Task 3: VerseRepository protocol and VerseDataSource

**Files:**
- Create: `Sources/BibleKitDB/VerseRepository.swift`
- Create: `Sources/BibleKitDB/VerseDataSource.swift`
- Test: `Tests/BibleKitDBTests/VerseDataSourceTests.swift`

**Interfaces:**
- Consumes: `VerseEntity`, `TranslationEntity` (Task 2).
- Produces: `VerseRepository` protocol; `VerseDataSource` (conforms to it) with `init(databaseWriter:)`, `convenience init(url:)`, `static create(dbQueue:) async throws -> VerseDataSource`. Used by Task 4's `BibleStoreProvider`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitDBTests/VerseDataSourceTests.swift`:

```swift
import GRDB
import XCTest
@testable import BibleKitDB

final class VerseDataSourceTests: XCTestCase {
    private func makeDataSource() async throws -> VerseDataSource {
        try await VerseDataSource.create()
    }

    func testInsertAndFetchVersesInRangeScopedByTranslation() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning"),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "And the earth"),
        ])

        let verses = try await dataSource.getVersesInRange(
            translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:2", limit: Int.max, offset: 0
        )

        XCTAssertEqual(verses.map(\.text), ["In the beginning", "And the earth"])
    }

    func testTwoTranslationsCanShareTheSameVerseNumber() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.registerTranslation(TranslationEntity(id: "afrikaans-2020", name: "Afrikaans 2020", language: "af"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning"),
            VerseEntity(translationId: "afrikaans-2020", id: "1:1:1", text: "In die begin"),
        ])

        let kjv = try await dataSource.getVersesInRange(translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)
        let afr = try await dataSource.getVersesInRange(translationId: "afrikaans-2020", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)

        XCTAssertEqual(kjv.first?.text, "In the beginning")
        XCTAssertEqual(afr.first?.text, "In die begin")
    }

    func testInsertingDuplicateVerseNumberForSameTranslationThrows() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "First")])

        do {
            try await dataSource.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "Duplicate")])
            XCTFail("Expected duplicate insert to throw")
        } catch {
            // expected — unique index on (translationId, number)
        }
    }

    func testSearchVersesPrioritizesExactPhraseMatch() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "God created the heaven"),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "the heaven and God"),
        ])

        let results = try await dataSource.searchVerses(translationId: "kjv", text: "God created", limit: Int.max, offset: 0)

        XCTAssertEqual(results.first?.id, "1:1:1")
    }

    func testSearchVersesDoesNotLeakAcrossTranslations() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await dataSource.registerTranslation(TranslationEntity(id: "other", name: "Other", language: "en"))
        try await dataSource.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "unique-word-kjv"),
            VerseEntity(translationId: "other", id: "1:1:1", text: "unique-word-kjv"),
        ])

        let results = try await dataSource.searchVerses(translationId: "kjv", text: "unique-word-kjv", limit: Int.max, offset: 0)

        XCTAssertEqual(results.count, 1)
    }

    func testTranslationsListsRegisteredTranslations() async throws {
        let dataSource = try await makeDataSource()
        try await dataSource.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))

        let translations = try await dataSource.translations()

        XCTAssertEqual(translations, [TranslationEntity(id: "kjv", name: "King James Version", language: "en")])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter VerseDataSourceTests
```
Expected: FAIL (build error — `VerseDataSource` doesn't exist yet).

- [ ] **Step 3: Implement the protocol**

Create `Sources/BibleKitDB/VerseRepository.swift`:

```swift
import Foundation

/// The repository for accessing verse rows in the shared, multi-translation database.
public protocol VerseRepository: Sendable {
    func searchVerses(translationId: String, text: String, limit: Int, offset: Int) async throws -> [VerseEntity]
    func searchVersesInRange(translationId: String, text: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity]
    func searchVersesByIds(translationId: String, text: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity]
    func getVersesByIds(translationId: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity]
    func getVersesInRange(translationId: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity]
    func insertVerses(_ verses: [VerseEntity]) async throws
    func registerTranslation(_ translation: TranslationEntity) async throws
    func translations() async throws -> [TranslationEntity]
}
```

- [ ] **Step 4: Implement VerseDataSource**

Create `Sources/BibleKitDB/VerseDataSource.swift`:

```swift
import Foundation
import GRDB

/// A GRDB/SQLite-backed VerseRepository. Verses from every translation live in one
/// database, scoped by `translationId` — see
/// docs/superpowers/specs/2026-09-17-versewell-transplant-design.md for why this
/// differs from VerseWell/BibleKit-swift's one-db-per-translation schema.
final class VerseDataSource: VerseRepository, Sendable {
    struct Verse: Codable, FetchableRecord, PersistableRecord {
        static let databaseTableName = "Verse"

        var translationId: String
        var number: String
        var sortKey: Int
        var text: String
        var searchText: String
    }

    private let databaseWriter: DatabaseWriter

    init(databaseWriter: DatabaseWriter) {
        self.databaseWriter = databaseWriter
    }

    convenience init(url: URL) {
        self.init(databaseWriter: try! DatabaseQueue(path: url.path))
    }

    static func create(dbQueue: DatabaseQueue = try! DatabaseQueue()) async throws -> VerseDataSource {
        try await dbQueue.write { db in
            try db.create(table: "Translation") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("language", .text).notNull()
            }

            try db.create(table: "Verse") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("translationId", .text).notNull().references("Translation", column: "id")
                t.column("number", .text).notNull()
                t.column("sortKey", .integer).notNull()
                t.column("text", .text).notNull()
                t.column("searchText", .text).notNull()
            }
            try db.create(index: "Verse_translation_number", on: "Verse", columns: ["translationId", "number"], unique: true)
            try db.create(index: "Verse_translation_sortKey", on: "Verse", columns: ["translationId", "sortKey"])

            try db.create(virtualTable: "VerseFts", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.content = "Verse"
                t.column("searchText")
                t.synchronize(withTable: "Verse")
            }
        }
        return VerseDataSource(databaseWriter: dbQueue)
    }

    func registerTranslation(_ translation: TranslationEntity) async throws {
        try await databaseWriter.write { db in
            try db.execute(
                sql: "INSERT INTO Translation (id, name, language) VALUES (?, ?, ?)",
                arguments: [translation.id, translation.name, translation.language]
            )
        }
    }

    func translations() async throws -> [TranslationEntity] {
        try await databaseWriter.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, language FROM Translation ORDER BY id")
                .map { TranslationEntity(id: $0["id"], name: $0["name"], language: $0["language"]) }
        }
    }

    func searchVerses(translationId: String, text: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await databaseWriter.read { db in
            let phraseSearchTerm = "\"\(text)\""
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM (
                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 0 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(phraseSearchTerm)) AS exact_matches
                    ON Verse.id = exact_matches.rowid
                WHERE Verse.translationId = \(translationId)

                UNION

                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 1 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(text)) AS word_matches
                    ON Verse.id = word_matches.rowid
                WHERE Verse.translationId = \(translationId)
                AND Verse.id NOT IN (
                    SELECT Verse.id FROM Verse
                    JOIN VerseFts ON Verse.id = VerseFts.rowid
                    WHERE VerseFts.searchText MATCH \(phraseSearchTerm) AND Verse.translationId = \(translationId)
                )
            )
            ORDER BY priority, sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func searchVersesInRange(
        translationId: String,
        text: String,
        startVerse: String,
        endVerse: String,
        limit: Int,
        offset: Int
    ) async throws -> [VerseEntity] {
        let start = VerseEntity.sortKey(id: startVerse)
        let end = VerseEntity.sortKey(id: endVerse)
        return try await databaseWriter.read { db in
            let phraseSearchTerm = "\"\(text)\""
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM (
                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 0 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(phraseSearchTerm)) AS exact_matches
                    ON Verse.id = exact_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.sortKey BETWEEN \(start) AND \(end)

                UNION

                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 1 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(text)) AS word_matches
                    ON Verse.id = word_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.sortKey BETWEEN \(start) AND \(end)
                AND Verse.id NOT IN (
                    SELECT Verse.id FROM Verse
                    JOIN VerseFts ON Verse.id = VerseFts.rowid
                    WHERE VerseFts.searchText MATCH \(phraseSearchTerm) AND Verse.translationId = \(translationId)
                )
            )
            ORDER BY priority, sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func searchVersesByIds(
        translationId: String,
        text: String,
        verseIDs: [String],
        limit: Int,
        offset: Int
    ) async throws -> [VerseEntity] {
        try await databaseWriter.read { db in
            let phraseSearchTerm = "\"\(text)\""
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM (
                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 0 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(phraseSearchTerm)) AS exact_matches
                    ON Verse.id = exact_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.number IN \(verseIDs)

                UNION

                SELECT Verse.id, Verse.translationId, Verse.number, Verse.sortKey, Verse.text, Verse.searchText, 1 AS priority
                FROM Verse
                JOIN (SELECT rowid FROM VerseFts WHERE searchText MATCH \(text)) AS word_matches
                    ON Verse.id = word_matches.rowid
                WHERE Verse.translationId = \(translationId) AND Verse.number IN \(verseIDs)
                AND Verse.id NOT IN (
                    SELECT Verse.id FROM Verse
                    JOIN VerseFts ON Verse.id = VerseFts.rowid
                    WHERE VerseFts.searchText MATCH \(phraseSearchTerm) AND Verse.translationId = \(translationId)
                )
            )
            ORDER BY priority, sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func getVersesByIds(translationId: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await databaseWriter.read { db in
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM Verse
            WHERE translationId = \(translationId) AND number IN \(verseIDs)
            ORDER BY sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func getVersesInRange(translationId: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        let start = VerseEntity.sortKey(id: startVerse)
        let end = VerseEntity.sortKey(id: endVerse)
        return try await databaseWriter.read { db in
            let request: SQLRequest<Verse> = """
            SELECT translationId, number, sortKey, text, searchText FROM Verse
            WHERE translationId = \(translationId) AND sortKey BETWEEN \(start) AND \(end)
            ORDER BY sortKey
            LIMIT \(limit) OFFSET \(offset)
            """
            return try request.fetchAll(db).map {
                VerseEntity(translationId: $0.translationId, id: $0.number, text: $0.text)
            }
        }
    }

    func insertVerses(_ verses: [VerseEntity]) async throws {
        try await databaseWriter.write { db in
            for verse in verses {
                try Verse(
                    translationId: verse.translationId,
                    number: verse.id,
                    sortKey: verse.sortKey,
                    text: verse.text,
                    searchText: verse.text
                ).insert(db)
            }
        }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
swift test --filter VerseDataSourceTests
```
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/BibleKitDB Tests/BibleKitDBTests
git commit -m "Add VerseRepository protocol and GRDB-backed VerseDataSource"
```

---

### Task 4: BibleStoreProvider

**Files:**
- Create: `Sources/BibleKitDB/BibleStoreProvider.swift`
- Test: `Tests/BibleKitDBTests/BibleStoreProviderTests.swift`

**Interfaces:**
- Consumes: `VerseRepository`, `VerseDataSource`, `VerseEntity`, `TranslationEntity` (Tasks 2–3).
- Produces: `BibleStoreProvider` with `create(url:) -> BibleStoreProvider`, `createEmpty(url:) async throws -> BibleStoreProvider`, and passthrough query/insert/translation methods. Used by Task 10's `DefaultBibleStoreService` and Task 14's bundled-db generator.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitDBTests/BibleStoreProviderTests.swift`:

```swift
import Foundation
import XCTest
@testable import BibleKitDB

final class BibleStoreProviderTests: XCTestCase {
    func testCreateEmptyThenRoundTripsAVerse() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = try await BibleStoreProvider.createEmpty(url: url)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await provider.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning")])

        let verses = try await provider.getVersesInRange(translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)

        XCTAssertEqual(verses.first?.text, "In the beginning")
    }

    func testCreateOpensAnExistingDatabaseFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = try await BibleStoreProvider.createEmpty(url: url)
        try await writer.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await writer.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning")])

        let reader = BibleStoreProvider.create(url: url)
        let verses = try await reader.getVersesInRange(translationId: "kjv", startVerse: "1:1:1", endVerse: "1:1:1", limit: Int.max, offset: 0)

        XCTAssertEqual(verses.first?.text, "In the beginning")
    }

    func testSearchVersesWithoutIdsSearchesEverything() async throws {
        let dataSource = try await VerseDataSource.create()
        let provider = BibleStoreProvider(repository: dataSource)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await provider.insertVerses([VerseEntity(translationId: "kjv", id: "1:1:1", text: "findme")])

        let results = try await provider.searchVerses(translationId: "kjv", text: "findme", limit: Int.max, offset: 0)

        XCTAssertEqual(results.count, 1)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter BibleStoreProviderTests
```
Expected: FAIL (build error — `BibleStoreProvider` doesn't exist yet).

- [ ] **Step 3: Implement**

Create `Sources/BibleKitDB/BibleStoreProvider.swift`:

```swift
import Foundation
import GRDB

/// Public entry point to the shared, multi-translation Bible database.
public final class BibleStoreProvider: Sendable {
    private let repository: VerseRepository

    public init(repository: VerseRepository) {
        self.repository = repository
    }

    /// Opens an existing database file. The file must already contain the BibleKitDB
    /// schema (see `createEmpty(url:)`) — this does not create tables.
    public static func create(url: URL) -> BibleStoreProvider {
        BibleStoreProvider(repository: VerseDataSource(url: url))
    }

    /// Creates a new database file at `url` with the BibleKitDB schema, ready for
    /// `registerTranslation`/`insertVerses`.
    public static func createEmpty(url: URL) async throws -> BibleStoreProvider {
        let dataSource = try await VerseDataSource.create(dbQueue: DatabaseQueue(path: url.path))
        return BibleStoreProvider(repository: dataSource)
    }

    public func searchVerses(translationId: String, text: String, verseIDs: [String]? = nil, limit: Int, offset: Int) async throws -> [VerseEntity] {
        if let verseIDs {
            try await repository.searchVersesByIds(translationId: translationId, text: text, verseIDs: verseIDs, limit: limit, offset: offset)
        } else {
            try await repository.searchVerses(translationId: translationId, text: text, limit: limit, offset: offset)
        }
    }

    public func searchVersesInRange(translationId: String, text: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await repository.searchVersesInRange(translationId: translationId, text: text, startVerse: startVerse, endVerse: endVerse, limit: limit, offset: offset)
    }

    public func getVerses(translationId: String, verseIDs: [String], limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await repository.getVersesByIds(translationId: translationId, verseIDs: verseIDs, limit: limit, offset: offset)
    }

    public func getVersesInRange(translationId: String, startVerse: String, endVerse: String, limit: Int, offset: Int) async throws -> [VerseEntity] {
        try await repository.getVersesInRange(translationId: translationId, startVerse: startVerse, endVerse: endVerse, limit: limit, offset: offset)
    }

    public func insertVerses(_ verses: [VerseEntity]) async throws {
        try await repository.insertVerses(verses)
    }

    public func registerTranslation(_ translation: TranslationEntity) async throws {
        try await repository.registerTranslation(translation)
    }

    public func translations() async throws -> [TranslationEntity] {
        try await repository.translations()
    }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
swift test --filter BibleStoreProviderTests
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKitDB/BibleStoreProvider.swift Tests/BibleKitDBTests/BibleStoreProviderTests.swift
git commit -m "Add BibleStoreProvider with create/createEmpty entry points"
```

---

### Task 5: BibleKitTests scaffold — TranslationID, Translation

**Files:**
- Modify: `Package.swift`
- Create: `Sources/BibleKit/Model/Translation.swift`
- Test: `Tests/BibleKitTests/Model/TranslationTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `TranslationID` (RawRepresentable String wrapper), `Translation` (id/name/language). Used throughout the rest of the `BibleKit` target.

- [ ] **Step 1: Add the BibleKitTests target to Package.swift**

In the `targets:` array, after the `BibleKitDBTests` test target, add:

```swift
        .testTarget(
            name: "BibleKitTests",
            dependencies: ["BibleKit"]
        ),
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/BibleKitTests/Model/TranslationTests.swift`:

```swift
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
```

- [ ] **Step 3: Run to verify it fails**

```bash
swift test --filter TranslationTests
```
Expected: FAIL (build error — `TranslationID`/`Translation` don't exist yet).

- [ ] **Step 4: Implement**

Create `Sources/BibleKit/Model/Translation.swift`:

```swift
import Foundation

/// Identifies a translation stored in the shared BibleKit database — a stable slug
/// like "afrikaans-2020", not a display name.
public struct TranslationID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// One translation available in the shared database.
public struct Translation: Identifiable, Equatable, Sendable {
    public let id: TranslationID
    public let name: String
    public let language: String

    public init(id: TranslationID, name: String, language: String) {
        self.id = id
        self.name = name
        self.language = language
    }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
swift test --filter TranslationTests
```
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/BibleKit/Model/Translation.swift Tests/BibleKitTests
git commit -m "Add BibleKitTests target with TranslationID and Translation"
```

---

### Task 6: Core reference models — BookName, Book, BookCollection, VerseID

**Files:**
- Create: `Sources/BibleKit/Data/BookName.swift` (copied from upstream)
- Create: `Sources/BibleKit/Data/BookCollection.swift` (copied from upstream)
- Create: `Sources/BibleKit/Model/Book.swift` (copied from upstream)
- Create: `Sources/BibleKit/Model/VerseID.swift` (copied from upstream)
- Create: `Sources/BibleKit/BookName+Hashable.swift`
- Test: `Tests/BibleKitTests/Data/BookNameTests.swift`
- Test: `Tests/BibleKitTests/Data/BookCollectionTests.swift`
- Test: `Tests/BibleKitTests/Model/BookTests.swift`
- Test: `Tests/BibleKitTests/Model/VerseIDTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `BookName` (66-case enum, `.value`, `.shortName`, now `Hashable`), `Book` (bookName/totalChapters/verses, `startVerseID`/`endVerseID`/`totalVerses(chapter:)`/`allVerseIDs()`), `BookCollection` (`.allBooks`, `.oldTestamentBooks`, `.newTestamentBooks`, `.mapping`), `VerseID` (value/components()/bookName()/bookChapterVerse()/.start/.end). Used throughout the rest of `BibleKit`.

- [ ] **Step 1: Ensure the upstream reference is cloned and copy the files**

```bash
mkdir -p .build/upstream-reference
[ -d .build/upstream-reference/BibleKit-swift ] || \
  git clone --depth 1 https://github.com/VerseWell/BibleKit-swift.git .build/upstream-reference/BibleKit-swift

mkdir -p Sources/BibleKit/Data Sources/BibleKit/Model Tests/BibleKitTests/Data Tests/BibleKitTests/Model

cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Data/BookName.swift Sources/BibleKit/Data/BookName.swift
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Data/BookCollection.swift Sources/BibleKit/Data/BookCollection.swift
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Model/Book.swift Sources/BibleKit/Model/Book.swift
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Model/VerseID.swift Sources/BibleKit/Model/VerseID.swift
```

These four files are translation-agnostic (book/chapter/verse structure, not text), so they're copied unmodified.

- [ ] **Step 2: Add Hashable conformance for navigation (SwiftUI needs this later)**

Create `Sources/BibleKit/BookName+Hashable.swift`:

```swift
import Foundation

extension BookName: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
```

- [ ] **Step 3: Write the tests**

Create `Tests/BibleKitTests/Data/BookNameTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class BookNameTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(BookName.allCases.count, 66)
    }

    func testShortNameForGenesis() {
        XCTAssertEqual(BookName.Genesis.shortName, "Gen")
    }

    func testValueForMultiWordName() {
        XCTAssertEqual(BookName.Samuel1.value, "1 Samuel")
    }

    func testIsHashable() {
        let names: Set<BookName> = [.Genesis, .Genesis, .Exodus]
        XCTAssertEqual(names.count, 2)
    }
}
```

Create `Tests/BibleKitTests/Data/BookCollectionTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class BookCollectionTests: XCTestCase {
    func testAllBooksCount() {
        XCTAssertEqual(BookCollection.allBooks.count, 66)
    }

    func testOldAndNewTestamentCounts() {
        XCTAssertEqual(BookCollection.oldTestamentBooks.count, 39)
        XCTAssertEqual(BookCollection.newTestamentBooks.count, 27)
    }

    func testMappingCoversEveryBook() {
        for bookName in BookName.allCases {
            XCTAssertNotNil(BookCollection.mapping[bookName])
        }
    }
}
```

Create `Tests/BibleKitTests/Model/BookTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class BookTests: XCTestCase {
    func testGenesisStructure() {
        let genesis = BookCollection.mapping[.Genesis]!
        XCTAssertEqual(genesis.totalChapters, 50)
        XCTAssertEqual(genesis.totalVerses(chapter: 1), 31)
        XCTAssertEqual(genesis.startVerseID.value, "1:1:1")
    }

    func testAllVerseIDsCountMatchesVerseCounts() {
        let ruth = BookCollection.mapping[.Ruth]!
        XCTAssertEqual(ruth.allVerseIDs().count, 22 + 23 + 18 + 22)
    }
}
```

Create `Tests/BibleKitTests/Model/VerseIDTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class VerseIDTests: XCTestCase {
    func testComponents() {
        XCTAssertEqual(VerseID(value: "1:2:3").components(), [1, 2, 3])
    }

    func testBookChapterVerse() {
        XCTAssertEqual(VerseID(value: "1:1:1").bookChapterVerse(), "Genesis 1:1")
    }

    func testBookNameFromID() {
        XCTAssertEqual(VerseID(value: "40:1:1").bookName(), .Matthew)
    }

    func testStartAndEnd() {
        XCTAssertEqual(VerseID.start.value, "1:1:1")
        XCTAssertEqual(VerseID.end.value, "66:22:21")
    }
}
```

- [ ] **Step 4: Run to verify everything passes**

```bash
swift test --filter "BookNameTests|BookCollectionTests|BookTests|VerseIDTests"
```
Expected: PASS (13 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/Data Sources/BibleKit/Model Sources/BibleKit/BookName+Hashable.swift Tests/BibleKitTests
git commit -m "Add BookName, Book, BookCollection, and VerseID from upstream"
```

---

### Task 7: Reference range models — ChapterReference, VerseReference, Reference, SelectedVerseRange

**Files:**
- Create: `Sources/BibleKit/Model/ChapterReference.swift` (copied from upstream)
- Create: `Sources/BibleKit/Model/VerseReference.swift` (copied from upstream)
- Create: `Sources/BibleKit/Model/Reference.swift` (copied from upstream)
- Create: `Sources/BibleKit/Model/SelectedVerseRange.swift` (copied from upstream)
- Create: `Sources/BibleKit/ChapterReference+Hashable.swift`
- Test: `Tests/BibleKitTests/Model/ChapterReferenceTests.swift`
- Test: `Tests/BibleKitTests/Model/VerseReferenceTests.swift`
- Test: `Tests/BibleKitTests/Model/ReferenceTests.swift`

**Interfaces:**
- Consumes: `BookName`, `Book`, `BookCollection`, `VerseID` (Task 6).
- Produces: `ChapterReference` (bookName/index, `startVerseID`/`endVerseID`/`allVerseIDs()`, now `Hashable`), `VerseReference` (chapter/index, `Comparable`, `.fromVerseID(_:)`), `Reference` (from/to, `.fixup()`, `.verseIDs()`, `.createWithBook(...)`), `SelectedVerseRange` (used by Task 8's `Verse.selectedVerseRange`). `BibleProvider.chapter(...)` (Task 11) consumes `ChapterReference`.

- [ ] **Step 1: Copy the files**

```bash
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Model/ChapterReference.swift Sources/BibleKit/Model/ChapterReference.swift
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Model/VerseReference.swift Sources/BibleKit/Model/VerseReference.swift
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Model/Reference.swift Sources/BibleKit/Model/Reference.swift
cp .build/upstream-reference/BibleKit-swift/Sources/BibleKit/Model/SelectedVerseRange.swift Sources/BibleKit/Model/SelectedVerseRange.swift
```

- [ ] **Step 2: Add Hashable conformance for navigation**

Create `Sources/BibleKit/ChapterReference+Hashable.swift`:

```swift
import Foundation

extension ChapterReference: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bookName)
        hasher.combine(index)
    }
}
```

- [ ] **Step 3: Write the tests**

Create `Tests/BibleKitTests/Model/ChapterReferenceTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class ChapterReferenceTests: XCTestCase {
    func testStartAndEndVerseID() {
        let chapter = ChapterReference(bookName: .Genesis, index: 1)
        XCTAssertEqual(chapter.startVerseID.value, "1:1:1")
        XCTAssertEqual(chapter.endVerseID.value, "1:1:31")
    }

    func testAllVerseIDsCount() {
        let chapter = ChapterReference(bookName: .Ruth, index: 1)
        XCTAssertEqual(chapter.allVerseIDs().count, 22)
    }

    func testIsHashable() {
        let chapters: Set<ChapterReference> = [
            ChapterReference(bookName: .Genesis, index: 1),
            ChapterReference(bookName: .Genesis, index: 1),
            ChapterReference(bookName: .Genesis, index: 2),
        ]
        XCTAssertEqual(chapters.count, 2)
    }
}
```

Create `Tests/BibleKitTests/Model/VerseReferenceTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class VerseReferenceTests: XCTestCase {
    func testFromVerseIDValid() {
        let ref = VerseReference.fromVerseID("1:1:1")
        XCTAssertEqual(ref?.chapter.bookName, .Genesis)
    }

    func testFromVerseIDInvalidBookReturnsNil() {
        XCTAssertNil(VerseReference.fromVerseID("67:1:1"))
    }

    func testComparable() {
        let a = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 1), index: 1)
        let b = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 1), index: 2)
        XCTAssertLessThan(a, b)
    }
}
```

Create `Tests/BibleKitTests/Model/ReferenceTests.swift`:

```swift
import XCTest
@testable import BibleKit

final class ReferenceTests: XCTestCase {
    func testVerseIDsWithinSingleChapter() {
        // Ruth is book 8 (Genesis=1 ... Judges=7, Ruth=8).
        let reference = Reference.createWithBook(bookName: .Ruth, fromChapter: 1, toChapter: 1, fromVerse: 1, toVerse: 3)
        XCTAssertEqual(reference.verseIDs().map(\.value), ["8:1:1", "8:1:2", "8:1:3"])
    }

    func testFixupSwapsOutOfOrderReferences() {
        let from = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 2), index: 1)
        let to = VerseReference(chapter: ChapterReference(bookName: .Genesis, index: 1), index: 1)
        let fixed = Reference(from: from, to: to).fixup()
        XCTAssertEqual(fixed.from, to)
        XCTAssertEqual(fixed.to, from)
    }
}
```

- [ ] **Step 4: Run to verify everything passes**

```bash
swift test --filter "ChapterReferenceTests|VerseReferenceTests|ReferenceTests"
```
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/Model/ChapterReference.swift Sources/BibleKit/Model/VerseReference.swift \
        Sources/BibleKit/Model/Reference.swift Sources/BibleKit/Model/SelectedVerseRange.swift \
        Sources/BibleKit/ChapterReference+Hashable.swift Tests/BibleKitTests/Model
git commit -m "Add ChapterReference, VerseReference, Reference, SelectedVerseRange from upstream"
```

---

### Task 8: Verse model

**Files:**
- Create: `Sources/BibleKit/Model/Verse.swift`
- Test: `Tests/BibleKitTests/Model/VerseTests.swift`

**Interfaces:**
- Consumes: `VerseID`, `TranslationID`, `BookCollection`, `SelectedVerseRange` (Tasks 5–7); `VerseEntity.sortKey(id:)` from `BibleKitDB` (Task 2).
- Produces: `Verse` (id/translation/text), `Verse.selectedVerseRange(verses:)`, `Verse.shareVersesText(verses:)`, `Verse.createShareText(verses:)`. Used by Task 10's `DefaultBibleStoreService` and Task 11's `BibleProvider`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/Model/VerseTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter VerseTests
```
Expected: FAIL (build error — `Verse` doesn't exist yet).

- [ ] **Step 3: Implement**

Create `Sources/BibleKit/Model/Verse.swift`:

```swift
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
```

- [ ] **Step 4: Run to verify it passes**

```bash
swift test --filter VerseTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/Model/Verse.swift Tests/BibleKitTests/Model/VerseTests.swift
git commit -m "Add translation-aware Verse model"
```

---


### Task 9: BibleXMLImporter

**Files:**
- Create: `Sources/BibleKit/BibleXMLImporter.swift`
- Test: `Tests/BibleKitTests/BibleXMLImporterTests.swift`

**Interfaces:**
- Consumes: `VerseEntity` from `BibleKitDB` (Task 2).
- Produces: `BibleXMLImporter.parse(url:translationId:) throws -> [VerseEntity]`. Used by Task 12's `importXML` and Task 14's bundled-db generator.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/BibleXMLImporterTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter BibleXMLImporterTests
```
Expected: FAIL (build error — `BibleXMLImporter` doesn't exist yet).

- [ ] **Step 3: Implement**

Create `Sources/BibleKit/BibleXMLImporter.swift`:

```swift
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
```

- [ ] **Step 4: Run to verify it passes**

```bash
swift test --filter BibleXMLImporterTests
```
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/BibleXMLImporter.swift Tests/BibleKitTests/BibleXMLImporterTests.swift
git commit -m "Add BibleXMLImporter for Holy-Bible-XML-Format files"
```

---

### Task 10: BibleStoreService and DefaultBibleStoreService

**Files:**
- Create: `Sources/BibleKit/BibleStoreService.swift`
- Create: `Sources/BibleKit/DefaultBibleStoreService.swift`
- Test: `Tests/BibleKitTests/DefaultBibleStoreServiceTests.swift`

**Interfaces:**
- Consumes: `Verse`, `VerseID`, `Translation`, `TranslationID` (Tasks 5–8); `BibleStoreProvider`, `VerseEntity`, `TranslationEntity` from `BibleKitDB` (Tasks 2–4).
- Produces: `BibleStoreService` protocol (search/get/translations, no import yet); `DefaultBibleStoreService` (conforms to it, wraps `BibleStoreProvider`, converts `VerseEntity` → `Verse`). Used by Task 11's `BibleProvider`. `importXML` is added to both in Task 12.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/DefaultBibleStoreServiceTests.swift`:

```swift
import BibleKitDB
import XCTest
@testable import BibleKit

final class DefaultBibleStoreServiceTests: XCTestCase {
    func testGetVersesInRangeReturnsMappedVerses() async throws {
        let dataSource = try await VerseDataSource.create()
        let provider = BibleStoreProvider(repository: dataSource)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await provider.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning"),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "And the earth"),
        ])

        let service = DefaultBibleStoreService(provider: provider)
        let verses = try await service.getVersesInRange(
            translation: TranslationID("kjv"),
            startVerseID: VerseID(value: "1:1:1"),
            endVerseID: VerseID(value: "1:1:2"),
            limit: Int.max,
            offset: 0
        )

        XCTAssertEqual(verses.map(\.text), ["In the beginning", "And the earth"])
        XCTAssertEqual(verses.first?.translation, TranslationID("kjv"))
    }

    func testTranslationsListsRegisteredTranslations() async throws {
        let dataSource = try await VerseDataSource.create()
        let provider = BibleStoreProvider(repository: dataSource)
        try await provider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))

        let service = DefaultBibleStoreService(provider: provider)
        let translations = try await service.translations()

        XCTAssertEqual(translations, [Translation(id: TranslationID("kjv"), name: "King James Version", language: "en")])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter DefaultBibleStoreServiceTests
```
Expected: FAIL (build error — `DefaultBibleStoreService` doesn't exist yet).

- [ ] **Step 3: Implement the protocol**

Create `Sources/BibleKit/BibleStoreService.swift`:

```swift
import Foundation

/// Bridges BibleKitDB's translation-scoped verse entities to BibleKit's public `Verse` model.
protocol BibleStoreService: Sendable {
    func searchVerses(translation: TranslationID, text: String, verseIDs: [VerseID]?, limit: Int, offset: Int) async throws -> [Verse]
    func searchVersesInRange(translation: TranslationID, text: String, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse]
    func getVerses(translation: TranslationID, verseIDs: [VerseID], limit: Int, offset: Int) async throws -> [Verse]
    func getVersesInRange(translation: TranslationID, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse]
    func translations() async throws -> [Translation]
}
```

- [ ] **Step 4: Implement the adapter**

Create `Sources/BibleKit/DefaultBibleStoreService.swift`:

```swift
import BibleKitDB
import Foundation

final class DefaultBibleStoreService: BibleStoreService, Sendable {
    let provider: BibleStoreProvider

    init(provider: BibleStoreProvider) {
        self.provider = provider
    }

    func searchVerses(translation: TranslationID, text: String, verseIDs: [VerseID]?, limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.searchVerses(
            translationId: translation.rawValue,
            text: text,
            verseIDs: verseIDs?.map(\.value),
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func searchVersesInRange(translation: TranslationID, text: String, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.searchVersesInRange(
            translationId: translation.rawValue,
            text: text,
            startVerse: startVerseID.value,
            endVerse: endVerseID.value,
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func getVerses(translation: TranslationID, verseIDs: [VerseID], limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.getVerses(
            translationId: translation.rawValue,
            verseIDs: verseIDs.map(\.value),
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func getVersesInRange(translation: TranslationID, startVerseID: VerseID, endVerseID: VerseID, limit: Int, offset: Int) async throws -> [Verse] {
        let results = try await provider.getVersesInRange(
            translationId: translation.rawValue,
            startVerse: startVerseID.value,
            endVerse: endVerseID.value,
            limit: limit,
            offset: offset
        )
        return results.map { Verse(id: VerseID(value: $0.id), translation: translation, text: $0.text) }
    }

    func translations() async throws -> [Translation] {
        let entities = try await provider.translations()
        return entities.map { Translation(id: TranslationID($0.id), name: $0.name, language: $0.language) }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
swift test --filter DefaultBibleStoreServiceTests
```
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/BibleKit/BibleStoreService.swift Sources/BibleKit/DefaultBibleStoreService.swift \
        Tests/BibleKitTests/DefaultBibleStoreServiceTests.swift
git commit -m "Add BibleStoreService and DefaultBibleStoreService"
```

---

### Task 11: BibleProvider public API

**Files:**
- Create: `Sources/BibleKit/BibleProvider.swift`
- Test: `Tests/BibleKitTests/BibleProviderTests.swift`

**Interfaces:**
- Consumes: `BibleStoreService`, `DefaultBibleStoreService` (Task 10); `Verse`, `VerseID`, `Translation`, `TranslationID`, `Reference`, `ChapterReference`, `Book` (Tasks 5–8); `BibleStoreProvider` from `BibleKitDB` (Task 4).
- Produces: `BibleProvider` with `create(url:)`, `createEmpty(url:) async throws`, `search(translation:query:...)` (two overloads), `chapter(translation:chapter:...)`, `book(translation:book:...)`, `verses(translation:ids:...)`, `translations()`. Used by Task 12 (`importXML`), Task 14 (bundled-db generator), and Task 15 (`BibleReaderModel`).

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/BibleProviderTests.swift`:

```swift
import BibleKitDB
import XCTest
@testable import BibleKit

final class BibleProviderTests: XCTestCase {
    private func makeProvider() async throws -> BibleProvider {
        let dataSource = try await VerseDataSource.create()
        let storeProvider = BibleStoreProvider(repository: dataSource)
        try await storeProvider.registerTranslation(TranslationEntity(id: "kjv", name: "King James Version", language: "en"))
        try await storeProvider.insertVerses([
            VerseEntity(translationId: "kjv", id: "1:1:1", text: "In the beginning God created the heaven and the earth."),
            VerseEntity(translationId: "kjv", id: "1:1:2", text: "And the earth was without form, and void."),
        ])
        return BibleProvider(store: DefaultBibleStoreService(provider: storeProvider))
    }

    func testChapterReturnsAllVersesInOrder() async throws {
        let provider = try await makeProvider()
        let verses = try await provider.chapter(translation: TranslationID("kjv"), chapter: ChapterReference(bookName: .Genesis, index: 1))
        XCTAssertEqual(verses.map(\.id.value), ["1:1:1", "1:1:2"])
    }

    func testSearchFindsMatchingVerse() async throws {
        let provider = try await makeProvider()
        let results = try await provider.search(translation: TranslationID("kjv"), query: "void")
        XCTAssertEqual(results.map(\.id.value), ["1:1:2"])
    }

    func testSearchWithBlankQueryReturnsEmpty() async throws {
        let provider = try await makeProvider()
        let results = try await provider.search(translation: TranslationID("kjv"), query: "   ")
        XCTAssertTrue(results.isEmpty)
    }

    func testTranslationsListsRegistered() async throws {
        let provider = try await makeProvider()
        let translations = try await provider.translations()
        XCTAssertEqual(translations.map(\.id), [TranslationID("kjv")])
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter BibleProviderTests
```
Expected: FAIL (build error — `BibleProvider` doesn't exist yet).

- [ ] **Step 3: Implement**

Create `Sources/BibleKit/BibleProvider.swift`:

```swift
import BibleKitDB
import Foundation

/// Main entry point for reading and searching Bible content across every translation
/// loaded into the shared database.
public final class BibleProvider: Sendable {
    private let store: BibleStoreService

    init(store: BibleStoreService) {
        self.store = store
    }

    /// Opens an existing database file (must already contain the BibleKitDB schema).
    public static func create(url: URL) -> BibleProvider {
        let provider = BibleStoreProvider.create(url: url)
        return BibleProvider(store: DefaultBibleStoreService(provider: provider))
    }

    /// Creates a new, empty database file at `url`, ready for `importXML`.
    public static func createEmpty(url: URL) async throws -> BibleProvider {
        let provider = try await BibleStoreProvider.createEmpty(url: url)
        return BibleProvider(store: DefaultBibleStoreService(provider: provider))
    }

    public func search(
        translation: TranslationID,
        query: String,
        verseIDs: [VerseID]? = nil,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return try await store.searchVerses(translation: translation, text: query, verseIDs: verseIDs, limit: limit, offset: offset)
    }

    public func search(
        translation: TranslationID,
        query: String,
        reference: Reference,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        let fixedReference = reference.fixup()
        return try await store.searchVersesInRange(
            translation: translation,
            text: query,
            startVerseID: fixedReference.from.verseID(),
            endVerseID: fixedReference.to.verseID(),
            limit: limit,
            offset: offset
        )
    }

    public func chapter(
        translation: TranslationID,
        chapter: ChapterReference,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        try await store.getVersesInRange(
            translation: translation,
            startVerseID: chapter.startVerseID,
            endVerseID: chapter.endVerseID,
            limit: limit,
            offset: offset
        )
    }

    public func book(
        translation: TranslationID,
        book: Book,
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        try await store.getVersesInRange(
            translation: translation,
            startVerseID: book.startVerseID,
            endVerseID: book.endVerseID,
            limit: limit,
            offset: offset
        )
    }

    public func verses(
        translation: TranslationID,
        ids: [VerseID],
        limit: Int = Int.max,
        offset: Int = Int.min
    ) async throws -> [Verse] {
        try await store.getVerses(translation: translation, verseIDs: ids, limit: limit, offset: offset)
    }

    public func translations() async throws -> [Translation] {
        try await store.translations()
    }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
swift test --filter BibleProviderTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/BibleProvider.swift Tests/BibleKitTests/BibleProviderTests.swift
git commit -m "Add BibleProvider public API"
```

---

### Task 12: importXML wiring

**Files:**
- Modify: `Sources/BibleKit/BibleStoreService.swift`
- Modify: `Sources/BibleKit/DefaultBibleStoreService.swift`
- Modify: `Sources/BibleKit/BibleProvider.swift`
- Test: `Tests/BibleKitTests/BibleProviderImportTests.swift`

**Interfaces:**
- Consumes: `BibleXMLImporter` (Task 9), everything from Tasks 10–11.
- Produces: `BibleProvider.importXML(url:translationID:displayName:language:) async throws -> Translation` — the "drop in another XML file to expand the db" capability from the spec. Used by Task 14's bundled-db generator.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/BibleProviderImportTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter BibleProviderImportTests
```
Expected: FAIL (build error — `importXML` doesn't exist yet).

- [ ] **Step 3: Add importXML to the protocol**

In `Sources/BibleKit/BibleStoreService.swift`, add to the protocol:

```swift
    func importXML(url: URL, translationID: TranslationID, displayName: String, language: String) async throws -> Translation
```

- [ ] **Step 4: Implement it in DefaultBibleStoreService**

In `Sources/BibleKit/DefaultBibleStoreService.swift`, add:

```swift
    func importXML(url: URL, translationID: TranslationID, displayName: String, language: String) async throws -> Translation {
        let verses = try BibleXMLImporter.parse(url: url, translationId: translationID.rawValue)
        try await provider.registerTranslation(TranslationEntity(id: translationID.rawValue, name: displayName, language: language))
        try await provider.insertVerses(verses)
        return Translation(id: translationID, name: displayName, language: language)
    }
```

- [ ] **Step 5: Expose it on BibleProvider**

In `Sources/BibleKit/BibleProvider.swift`, add:

```swift
    @discardableResult
    public func importXML(url: URL, translationID: TranslationID, displayName: String, language: String) async throws -> Translation {
        try await store.importXML(url: url, translationID: translationID, displayName: displayName, language: language)
    }
```

- [ ] **Step 6: Run to verify it passes**

```bash
swift test --filter BibleProviderImportTests
```
Expected: PASS (2 tests).

- [ ] **Step 7: Run the full BibleKit and BibleKitDB test suites**

```bash
swift test
```
Expected: PASS (all tests from Tasks 2–12).

- [ ] **Step 8: Commit**

```bash
git add Sources/BibleKit/BibleStoreService.swift Sources/BibleKit/DefaultBibleStoreService.swift \
        Sources/BibleKit/BibleProvider.swift Tests/BibleKitTests/BibleProviderImportTests.swift
git commit -m "Add importXML for on-device translation import"
```

---

### Task 13: BookDisplayNames

**Files:**
- Create: `Sources/BibleKit/Data/BookDisplayNames.swift`
- Test: `Tests/BibleKitTests/Data/BookDisplayNamesTests.swift`

**Interfaces:**
- Consumes: `BookName`, `TranslationID` (Tasks 5–6).
- Produces: `BookDisplayNames.name(for:translation:) -> String`. Used by Task 15's `BibleReaderModel`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/Data/BookDisplayNamesTests.swift`:

```swift
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
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter BookDisplayNamesTests
```
Expected: FAIL (build error — `BookDisplayNames` doesn't exist yet).

- [ ] **Step 3: Implement**

Create `Sources/BibleKit/Data/BookDisplayNames.swift`:

```swift
import Foundation

/// Per-translation display names for each canonical BookName.
///
/// This is a small stopgap for the two bundled translations, not a general
/// localization system — if BibleKit ever supports arbitrary imported
/// translations needing their own display names, this should be revisited.
public enum BookDisplayNames {
    public static func name(for book: BookName, translation: TranslationID) -> String {
        translationNames[translation]?[book] ?? book.value
    }

    private static let translationNames: [TranslationID: [BookName: String]] = [
        TranslationID("afrikaans-2020"): afrikaans,
        TranslationID("english-kjv"): english,
    ]

    private static let english: [BookName: String] = Dictionary(
        uniqueKeysWithValues: BookName.allCases.map { ($0, $0.value) }
    )

    private static let afrikaans: [BookName: String] = [
        .Genesis: "Genesis", .Exodus: "Eksodus", .Leviticus: "Levitikus", .Numbers: "Numeri",
        .Deuteronomy: "Deuteronomium", .Joshua: "Josua", .Judges: "Rigters", .Ruth: "Rut",
        .Samuel1: "1 Samuel", .Samuel2: "2 Samuel", .Kings1: "1 Konings", .Kings2: "2 Konings",
        .Chronicles1: "1 Kronieke", .Chronicles2: "2 Kronieke", .Ezra: "Esra", .Nehemiah: "Nehemia",
        .Esther: "Ester", .Job: "Job", .Psalms: "Psalms", .Proverbs: "Spreuke",
        .Ecclesiastes: "Prediker", .SongOfSolomon: "Hooglied", .Isaiah: "Jesaja", .Jeremiah: "Jeremia",
        .Lamentations: "Klaagliedere", .Ezekiel: "Esegiël", .Daniel: "Daniël", .Hosea: "Hosea",
        .Joel: "Joël", .Amos: "Amos", .Obadiah: "Obadja", .Jonah: "Jona",
        .Micah: "Miga", .Nahum: "Nahum", .Habakkuk: "Habakuk", .Zephaniah: "Sefanja",
        .Haggai: "Haggai", .Zechariah: "Sagaria", .Malachi: "Maleagi",
        .Matthew: "Matteus", .Mark: "Markus", .Luke: "Lukas", .John: "Johannes",
        .Acts: "Handelinge", .Romans: "Romeine", .Corinthians1: "1 Korintiërs", .Corinthians2: "2 Korintiërs",
        .Galatians: "Galasiërs", .Ephesians: "Efesiërs", .Philippians: "Filippense", .Colossians: "Kolossense",
        .Thessalonians1: "1 Tessalonisense", .Thessalonians2: "2 Tessalonisense", .Timothy1: "1 Timoteus", .Timothy2: "2 Timoteus",
        .Titus: "Titus", .Philemon: "Filemon", .Hebrews: "Hebreërs", .James: "Jakobus",
        .Peter1: "1 Petrus", .Peter2: "2 Petrus", .John1: "1 Johannes", .John2: "2 Johannes",
        .John3: "3 Johannes", .Jude: "Judas", .Revelation: "Openbaring",
    ]
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
swift test --filter BookDisplayNamesTests
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/Data/BookDisplayNames.swift Tests/BibleKitTests/Data/BookDisplayNamesTests.swift
git commit -m "Add per-translation book display names"
```

---

### Task 14: Bundled database generation

**Files:**
- Modify: `Package.swift`
- Create: `Sources/GenerateBundledDB/GenerateBundledDB.swift`
- Create: `scripts/generate-bundled-db.sh`

**Interfaces:**
- Consumes: `BibleProvider.createEmpty(url:)`, `BibleProvider.importXML(...)` (Tasks 11–12); `Sources/BibleKit/Resources/Holy-Bible-XML-Format/Afrikaans2020Bible.xml` and `EnglishKJBible.xml` (already in the submodule).
- Produces: `Sources/BibleKit/Resources/bible.db`, the package resource `BibleReaderModel` opens in Task 15.

- [ ] **Step 1: Add the generator executable target and switch the bundled resource**

In `Package.swift`, change the `BibleKit` target's `resources:` from the XML copy to the generated db, and add the new executable target:

```swift
        .target(
            name: "BibleKit",
            dependencies: ["BibleKitDB"],
            resources: [.copy("Resources/bible.db")]
        ),
```

Add to the `targets:` array (any position after `BibleKit`):

```swift
        .executableTarget(
            name: "GenerateBundledDB",
            dependencies: ["BibleKit"]
        ),
```

- [ ] **Step 2: Write the generator**

Create `Sources/GenerateBundledDB/GenerateBundledDB.swift`:

```swift
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
```

- [ ] **Step 3: Write the shell wrapper**

Create `scripts/generate-bundled-db.sh`:

```bash
#!/bin/sh
set -e
cd "$(dirname "$0")/.."

XML_DIR="Sources/BibleKit/Resources/Holy-Bible-XML-Format"
OUTPUT_DB="Sources/BibleKit/Resources/bible.db"

echo "Generating bundled database from $XML_DIR..."
swift run GenerateBundledDB "$XML_DIR" "$OUTPUT_DB"

echo "✅ Wrote $OUTPUT_DB"
```

```bash
chmod +x scripts/generate-bundled-db.sh
```

- [ ] **Step 4: Make sure the XML submodule is checked out, then run it**

```bash
git submodule update --init --recursive
./scripts/generate-bundled-db.sh
```
Expected: prints "Imported Afrikaans 2020", "Imported English KJV", "✅ Wrote Sources/BibleKit/Resources/bible.db".

- [ ] **Step 5: Verify the generated database**

```bash
ls -lh Sources/BibleKit/Resources/bible.db
sqlite3 Sources/BibleKit/Resources/bible.db "SELECT id, name, language FROM Translation;"
sqlite3 Sources/BibleKit/Resources/bible.db "SELECT translationId, COUNT(*) FROM Verse GROUP BY translationId;"
```
Expected: two translation rows (`afrikaans-2020`, `english-kjv`), each with 31,102 verses (the standard Protestant canon verse count — both translations cover the same 66 books). Note the file size — the spec flags this as a risk (upstream's single-translation example db is ~18MB, so two translations may roughly double that); if it's unexpectedly large, investigate before committing.

- [ ] **Step 6: Confirm the whole package still builds and tests pass with the new resource**

```bash
swift build
swift test
```
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources/GenerateBundledDB scripts/generate-bundled-db.sh Sources/BibleKit/Resources/bible.db
git commit -m "Generate and bundle a shared multi-translation database"
```

---

### Task 15: BibleReaderModel rewrite

**Files:**
- Modify: `Sources/BibleKit/BibleReaderModel.swift`
- Test: `Tests/BibleKitTests/BibleReaderModelTests.swift`

**Interfaces:**
- Consumes: `BibleProvider`, `BookDisplayNames`, `BookCollection`, `Book`, `ChapterReference`, `Verse`, `TranslationID` (Tasks 6, 11, 13).
- Produces: `BibleReaderModel` with `state`, `translation`, `load()`, `displayName(for:)`, `verses(chapter:) async throws -> [Verse]`. Used by Task 16's `BibleReaderView`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/BibleKitTests/BibleReaderModelTests.swift`:

```swift
import XCTest
@testable import BibleKit

@MainActor
final class BibleReaderModelTests: XCTestCase {
    func testLoadSucceedsWithBundledDatabase() {
        let model = BibleReaderModel()
        model.load()
        XCTAssertEqual(model.state, .loaded)
    }

    func testDisplayNameUsesAfrikaans() {
        let model = BibleReaderModel()
        let exodus = BookCollection.mapping[.Exodus]!
        XCTAssertEqual(model.displayName(for: exodus), "Eksodus")
    }

    func testVersesReturnsGenesisChapterOne() async throws {
        let model = BibleReaderModel()
        model.load()
        let verses = try await model.verses(chapter: ChapterReference(bookName: .Genesis, index: 1))
        XCTAssertEqual(verses.count, 31)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
swift test --filter BibleReaderModelTests
```
Expected: FAIL (old `BibleReaderModel` API doesn't match — no `load()`/`state` compatible with a bundled `.db`, or a build error referencing removed XML-parser types).

- [ ] **Step 3: Implement**

Replace the contents of `Sources/BibleKit/BibleReaderModel.swift` with:

```swift
import Foundation
import Observation

/// Opens the bundled translation via BibleProvider, then serves chapters on demand
/// instead of holding the whole Bible in memory.
@Observable
@MainActor
public final class BibleReaderModel {
    public enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    public private(set) var state: LoadState = .idle
    public let translation = TranslationID("afrikaans-2020")

    private var provider: BibleProvider?

    public init() {}

    public func load() {
        guard state != .loaded else { return }
        state = .loading
        guard let url = Bundle.module.url(forResource: "bible", withExtension: "db") else {
            state = .failed("Bundled Bible database not found.")
            return
        }
        provider = BibleProvider.create(url: url)
        state = .loaded
    }

    public func displayName(for book: Book) -> String {
        BookDisplayNames.name(for: book.bookName, translation: translation)
    }

    public func verses(chapter: ChapterReference) async throws -> [Verse] {
        guard let provider else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try await provider.chapter(translation: translation, chapter: chapter)
    }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
swift test --filter BibleReaderModelTests
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/BibleKit/BibleReaderModel.swift Tests/BibleKitTests/BibleReaderModelTests.swift
git commit -m "Rewrite BibleReaderModel on top of BibleProvider"
```

---

### Task 16: BibleReaderView rewrite

**Files:**
- Modify: `Sources/BibleKit/BibleReaderView.swift`

**Interfaces:**
- Consumes: `BibleReaderModel` (Task 15), `BookCollection`, `Book`, `BookName`, `ChapterReference`, `Verse` (Tasks 6–8, 15).
- Produces: `BibleReaderView` — the public, drop-in reading screen. No new public API beyond what already exists; SwiftUI views aren't unit-testable without UI test infrastructure this package doesn't have, so this task's verification is a successful build plus the `BibleReaderModel` coverage from Task 15 (which already exercises the exact `verses(chapter:)` call this view drives).

- [ ] **Step 1: Implement**

Replace the contents of `Sources/BibleKit/BibleReaderView.swift` with:

```swift
import SwiftUI

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
            .navigationDestination(for: BookName.self) { bookName in
                chapterList(for: bookName)
            }
            .navigationDestination(for: ChapterReference.self) { chapter in
                ChapterDetailView(model: model, chapter: chapter)
            }
        }
        .task { model.load() }
    }

    private var oldTestamentBooks: [Book] { BookCollection.oldTestamentBooks }
    private var newTestamentBooks: [Book] { BookCollection.newTestamentBooks }

    private var bookList: some View {
        List {
            Section {
                ForEach(oldTestamentBooks, id: \.bookName) { book in
                    NavigationLink(value: book.bookName) { bookRow(book) }
                }
            } header: {
                testamentHeader("Old Testament", count: oldTestamentBooks.count)
            }
            Section {
                ForEach(newTestamentBooks, id: \.bookName) { book in
                    NavigationLink(value: book.bookName) { bookRow(book) }
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

    private func bookRow(_ book: Book) -> some View {
        HStack {
            Text(model.displayName(for: book))
            Spacer()
            Text("\(book.totalChapters) chapters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chapterList(for bookName: BookName) -> some View {
        let book = BookCollection.mapping[bookName]!
        return List {
            ForEach(1...book.totalChapters, id: \.self) { chapterIndex in
                let chapter = ChapterReference(bookName: bookName, index: chapterIndex)
                NavigationLink(value: chapter) {
                    HStack {
                        Text("Chapter \(chapterIndex)")
                        Spacer()
                        Text("\(book.totalVerses(chapter: chapterIndex)) verses")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(model.displayName(for: book))
    }
}

/// Fetches and displays one chapter's verses on demand.
private struct ChapterDetailView: View {
    let model: BibleReaderModel
    let chapter: ChapterReference

    @State private var verses: [Verse] = []
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            if let loadError {
                ContentUnavailableView("Can't load this chapter", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if verses.isEmpty {
                ProgressView()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.displayName(for: BookCollection.mapping[chapter.bookName]!))
                        .font(.system(.largeTitle, design: .serif))
                        .bold()
                    Text("Chapter \(chapter.index)")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(.secondary)

                    Divider()

                    ForEach(verses, id: \.id) { verse in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(verse.id.chapterVerseNumbers().last ?? 0)")
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
        .navigationTitle("\(model.displayName(for: BookCollection.mapping[chapter.bookName]!)) \(chapter.index)")
        .task(id: chapter) { await loadVerses() }
    }

    private func loadVerses() async {
        loadError = nil
        do {
            verses = try await model.verses(chapter: chapter)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview {
    BibleReaderView()
}
```

- [ ] **Step 2: Verify it builds**

```bash
swift build
```
Expected: builds cleanly. This package has no UI test target and no host app to run a simulator against — if you have Xcode available, open the package and check `BibleReaderView`'s `#Preview` (book list → tap a book → tap a chapter → verses load) as a manual sanity check; otherwise, the build succeeding plus `BibleReaderModelTests` (Task 15, which already exercises the exact `verses(chapter:)` call this view drives) is the coverage this task has.

- [ ] **Step 3: Commit**

```bash
git add Sources/BibleKit/BibleReaderView.swift
git commit -m "Rewrite BibleReaderView on top of the async BibleProvider"
```

---

### Task 17: Remove the old XML parser, update README, regenerate docs

**Files:**
- Delete: `Sources/BibleKit/BibleModels.swift`
- Delete: `Sources/BibleKit/BibleParser.swift`
- Modify: `README.md`
- Modify: `scripts/update-docs.sh`

**Interfaces:**
- Consumes: everything from Tasks 1–16.
- Produces: a fully working package with no references to the old in-memory XML API.

- [ ] **Step 1: Confirm nothing still references the old files**

```bash
grep -rl "BibleModels\|BibleBook\|BibleChapter\|BibleTestament\|bibleBookNames\|BibleParser\b" Sources Tests || echo "clean"
```
Expected: "clean" (Tasks 15–16 already stopped using these types; `BibleXMLImporter`, added in Task 9, is unrelated to `BibleParser`).

- [ ] **Step 2: Delete the old files**

```bash
rm Sources/BibleKit/BibleModels.swift Sources/BibleKit/BibleParser.swift
```

- [ ] **Step 3: Run the full test suite**

```bash
swift build
swift test
```
Expected: PASS — every test from Tasks 2–16 still passes with the old files gone.

- [ ] **Step 4: Rewrite README.md's "What's inside" and "Usage" sections**

Replace the `## What's inside` and `## Usage` sections (keep `## Data source`, `## Credits`, and everything else) with:

```markdown
## What's inside

- `BibleKitDB` — GRDB/SQLite persistence for a shared, multi-translation database
- `Model/` — `Verse`, `VerseID`, `Book`, `BookName`, `Translation`, `Reference`,
  `ChapterReference`, `VerseReference`, `SelectedVerseRange`
- `BibleProvider` — async search, chapter/book/verse fetch, and `importXML` for
  adding translations on-device
- `BibleXMLImporter` — parses a
  [Holy-Bible-XML-Format](https://github.com/PJKloppers/Holy-Bible-XML-Format) file
  into database rows
- `BibleReaderModel` / `BibleReaderView` — an `@Observable` load-state view model and a
  ready-to-use book → chapter → verses reading screen

## Usage

Add BibleKit as a Swift package dependency, then drop in the reading screen:

```swift
import BibleKit

struct ContentView: View {
    var body: some View {
        BibleReaderView()
    }
}
```

Or use `BibleProvider` directly:

```swift
import BibleKit

let provider = BibleProvider.create(url: Bundle.module.url(forResource: "bible", withExtension: "db")!)
let results = try await provider.search(translation: TranslationID("afrikaans-2020"), query: "liefde")
```

BibleKit ships with two bundled translations — `"afrikaans-2020"` (default) and
`"english-kjv"`. Import another Holy-Bible-XML-Format file at runtime with
`provider.importXML(url:translationID:displayName:language:)`.
```

- [ ] **Step 5: Update the DocC generation script for the second target**

In `scripts/update-docs.sh`, change the `swift package ... generate-documentation` invocation to document both targets:

```bash
swift package --disable-sandbox generate-documentation \
    --warnings-as-errors \
    --symbol-graph-minimum-access-level package \
    --enable-experimental-combined-documentation \
    --target BibleKit \
    --target BibleKitDB \
    --output-path ./docs \
    --transform-for-static-hosting
```

- [ ] **Step 6: Regenerate the docs site**

```bash
./scripts/update-docs.sh
```
Expected: succeeds, `docs/documentation/` now includes both `biblekit/` and `biblekitdb/`; `docs/index.html` and `docs/CNAME` are untouched (per the backup/restore already built into this script).

- [ ] **Step 7: Final full verification**

```bash
swift build
swift test
```
Expected: PASS, zero references to the deleted files.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Remove the old XML-parser data layer; update README and docs for the new architecture"
```

---

## Self-Review

**Spec coverage:**
- No GitHub fork → Task 1 clones locally only. ✓
- Full replace of the XML data layer → Task 17 deletes `BibleModels.swift`/`BibleParser.swift`. ✓
- Two targets (`BibleKitDB`, `BibleKit`) → Task 2. ✓
- Shared multi-translation schema (`Translation` table, `translationId`-scoped `Verse`, autoincrement surrogate key, `sortKey` for range queries) → Task 3. ✓
- `Verse` gains `translation`; `BibleProvider` methods gain `translation` parameter → Tasks 8, 10, 11. ✓
- `translations()` and `importXML(...)` → Tasks 11–12. ✓
- Bundled data from `Afrikaans2020Bible.xml` + `EnglishKJBible.xml` → Task 14. ✓
- `BibleReaderView`/`BibleReaderModel` rewrite, defaulting to one translation, no translation-switcher UI → Tasks 15–16 (explicit non-goal noted in Global Constraints). ✓
- Apache 2.0 LICENSE + README credit → Task 1. ✓
- Testing threaded through every changed call site → every task from 2–16 has its own test step. ✓
- Risk: bundled db size → flagged as a checkpoint in Task 14, Step 5. ✓
- Risk: `BookDisplayNames` is a stopgap, not localization → documented in its doc comment (Task 13). ✓

**Placeholder scan:** no TBD/TODO; every step has runnable code or an exact shell command.

**Type consistency:** `TranslationID`/`Translation` (Task 5) are used identically in Tasks 8, 10–16. `VerseEntity`/`TranslationEntity` (Task 2) field names (`translationId`, `id`, `text`, `sortKey` / `id`, `name`, `language`) are used identically across Tasks 3, 4, 9, 10, 12, 14. `BibleProvider` method signatures introduced in Task 11 (`search`, `chapter`, `book`, `verses`, `translations`) and extended in Task 12 (`importXML`) are called with matching argument labels in Tasks 14–15.
