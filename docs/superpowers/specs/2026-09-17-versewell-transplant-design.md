# Transplanting VerseWell/BibleKit-swift into BibleKit

Date: 2026-09-17

## Motivation

BibleKit currently ships a minimal, in-memory XML parser (`BibleModels.swift`,
`BibleParser.swift`) that loads one bundled translation fully into memory on
load. It has no search, no reference-range queries, and no way to add more
translations without rewriting the parser.

[VerseWell/BibleKit-swift](https://github.com/VerseWell/BibleKit-swift)
(Apache 2.0) is a mature, GRDB/SQLite-backed Bible library with full-text
search (FTS5), async reference-based fetching, and a well-factored
`VerseID`/`Book`/`Reference` model. It has no bundled UI and expects the
consuming app to supply its own `bible.db`.

This spec adopts VerseWell's architecture as BibleKit's new foundation,
extends its schema to support multiple translations in one shared database
(VerseWell's schema assumes a single translation per db file), adds a
runtime XML-import capability so a consuming app can add translations on
the device, and rebuilds BibleKit's existing SwiftUI reading screen on top
of it.

Code carried over from VerseWell is adapted, not copied verbatim where the
schema changes require it (see "Database schema" below); attribution is
handled via an Apache 2.0 `LICENSE` file and a README credit.

## Decisions already made (from brainstorming)

- **No GitHub-side fork.** Code is pulled from a local clone of
  `VerseWell/BibleKit-swift` and adapted in place; no public fork is created.
- **Full replace**, not dual data paths. `BibleModels.swift` and
  `BibleParser.swift` are deleted; `Verse`/`VerseID`/`Book`/`BibleProvider`
  become the only data layer.
- **Two targets**, matching upstream: `BibleKitDB` (GRDB persistence) and
  `BibleKit` (public API, XML import, and the SwiftUI reader).
- **One shared database, multiple translations** — not one `.db` file per
  translation. This is the one point where the schema meaningfully diverges
  from upstream (detailed below).
- **UI is rewritten**, not left broken: `BibleReaderView`/`BibleReaderModel`
  move onto the new async `BibleProvider`, defaulting to one bundled
  translation. A translation-switcher UI is an explicit non-goal for this
  pass.
- **Apache 2.0 LICENSE** added to this repo, with a README credit to
  VerseWell/BibleKit-swift.

## Non-goals (this pass)

- A translation-switcher UI in `BibleReaderView` (data layer supports it;
  screen does not expose it yet).
- Cross-translation search/comparison UI.
- iOS/macOS-side UI for importing a new XML translation on-device (the
  `BibleProvider.importXML` API is added; no settings screen calls it yet).
- Deleting or restructuring the `Holy-Bible-XML-Format` submodule — it
  remains the source data for imports.

## Package layout

```
Package.swift                          # adds BibleKitDB target + GRDB dependency
Sources/
  BibleKit/
    BibleProvider.swift                # search/fetch/import async API
    BibleXMLImporter.swift             # adapted from today's BibleParser
    BibleReaderModel.swift             # rewritten for async BibleProvider
    BibleReaderView.swift              # rewritten for async BibleProvider
    Model/
      Book.swift
      BookName.swift                   # canonical English names + abbreviations
      ChapterReference.swift
      Reference.swift
      SelectedVerseRange.swift
      Translation.swift                # NEW — id/name/language
      Verse.swift                      # gains `translation: TranslationID`
      VerseID.swift
      VerseReference.swift
    Data/
      BookCollection.swift             # unchanged (translation-agnostic structure)
      BookDisplayNames.swift           # NEW — per-translation display names for BookName
    Resources/
      Holy-Bible-XML-Format/           # submodule, unchanged (import source)
      bible.db                         # NEW — pre-built shared db, package resource
  BibleKitDB/
    BibleStoreProvider.swift
    VerseDataSource.swift              # schema + SQL adapted for translationId
    VerseEntity.swift                  # gains translationId
    VerseRepository.swift
Tests/
  BibleKitTests/                       # adapted from upstream's suite
  BibleKitDBTests/                     # adapted from upstream's suite
scripts/
  generate-bundled-db.sh               # NEW — (re)builds Resources/bible.db from XML
```

`BibleModels.swift`, `BibleParser.swift`, and their tests are deleted.

`Package.swift` gains `GRDB.swift` (`from: "7.0.0"`) as a plain dependency
(unlike `swift-docc-plugin`, GRDB is needed on iOS too, so no `#if !os(iOS)`
guard), and a `BibleKitDB` library product/target plus its test target,
alongside the existing `BibleKit` target and platform minimums
(iOS 17 / macOS 14 / visionOS 1 — already higher than upstream's iOS 13 /
macOS 10.15 floor, so no platform changes needed).

## Database schema (BibleKitDB)

Upstream's schema has no translation concept — `Verse.id` *is* the
deterministic sort key derived from `book:chapter:verse`, which only works
because one db file holds exactly one translation. Supporting multiple
translations in one db requires:

```sql
CREATE TABLE Translation (
    id       TEXT PRIMARY KEY,   -- stable slug, e.g. "afrikaans-2020"
    name     TEXT NOT NULL,      -- display name, e.g. "Afrikaans 2020"
    language TEXT NOT NULL       -- BCP-47-ish tag, e.g. "af"
);

CREATE TABLE Verse (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    translationId TEXT NOT NULL REFERENCES Translation(id),
    number        TEXT NOT NULL,      -- "book:chapter:verse", e.g. "1:1:1"
    sortKey       INTEGER NOT NULL,   -- VerseEntity.sortKey(id:) — for ORDER BY / BETWEEN
    text          TEXT NOT NULL,
    searchText    TEXT NOT NULL
);
CREATE UNIQUE INDEX Verse_translation_number ON Verse(translationId, number);
CREATE INDEX Verse_translation_sortKey ON Verse(translationId, sortKey);

CREATE VIRTUAL TABLE VerseFts USING fts5(
    searchText,
    content='Verse',
    content_rowid='id',
    tokenize='porter unicode61'
);
-- synchronized with Verse via GRDB's t.synchronize(withTable:), as upstream does
```

Key differences from upstream's `VerseDataSource`:

- `Verse.id` is now a plain autoincrement surrogate key (FTS5's
  `content_rowid`), not a derived value — it can no longer double as the
  sort/range key once two translations can share the same `book:chapter:verse`.
- `sortKey` (upstream's `VerseEntity.key`, unchanged computation) takes over
  range queries (`BETWEEN`), always paired with a `translationId` filter.
- Every repository/query method gains a `translationId: String` parameter:
  `searchVerses`, `searchVersesInRange`, `searchVersesByIds`,
  `getVersesByIds`, `getVersesInRange`, `insertVerses` (verses being
  inserted already carry their `translationId`).
- `insertVerses` becomes append-only across translations — it must not
  assume an empty table, since a second `importXML` call adds rows without
  touching existing translations. Duplicate `(translationId, number)` should
  throw rather than silently overwrite, using GRDB's uniqueness violation.
- `VerseDataSource.create` additionally creates the `Translation` table and
  gains a `registerTranslation(id:name:language:) async throws` method used
  by the import path before inserting verses.

`VerseEntity` (public within `BibleKitDB`) gains a `translationId: String`
field alongside `id`/`text`/`key`.

## Public API (BibleKit)

**`Translation`** (new):
```swift
public struct TranslationID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct Translation: Identifiable, Sendable {
    public let id: TranslationID
    public let name: String
    public let language: String
}
```

**`Verse`** — same shape as upstream plus one field:
```swift
public struct Verse: Equatable, Hashable, Sendable {
    public let id: VerseID              // translation-agnostic position
    public let translation: TranslationID
    public let text: String
    let sortKey: Int
}
```
`Verse.selectedVerseRange`/`shareVersesText`/`createShareText` keep
upstream's "single book" assertion and additionally assert a single
`translation` across the input list — mixing translations in one share/range
call is a caller error, same class of precondition upstream already enforces
for books.

**`BibleProvider`** — every fetch/search method gains a
`translation: TranslationID` parameter; two additions:
```swift
public func translations() async throws -> [Translation]

@discardableResult
public func importXML(
    url: URL,
    translationID: TranslationID,
    displayName: String,
    language: String
) async throws -> Translation
```
`importXML` parses the given Holy-Bible-XML-Format file with
`BibleXMLImporter` (adapted from today's `BibleParser` — same streaming
`XMLParserDelegate` approach, but producing `VerseEntity` rows tagged with
`translationID` instead of an in-memory `BibleBook` tree) and inserts them
via `BibleStoreProvider`/`VerseDataSource`. This is the "drop in another XML
file to expand the db later, on the phone" capability.

`BibleXMLImporter` is also what the bundled-data build script uses (see
below), so the parsing logic has exactly one implementation.

`BookCollection`/`Book`/`BookName`/`Reference`/`ChapterReference`/
`VerseReference` are carried over unchanged — book/chapter/verse structure
is translation-independent.

**`BookDisplayNames`** (new, small, in `BibleKit/Data/`): a
`[TranslationID: [BookName: String]]`-shaped static lookup used by the UI
to show localized book names (e.g. "Genesis" vs "Génesis" vs our existing
Afrikaans list) — replaces today's single hardcoded `bibleBookNames` array.
Only the two bundled translations get entries initially; this is a
recognized extension point, not a general localization system.

## Bundled data

`scripts/generate-bundled-db.sh` creates an empty db via
`VerseDataSource.create`, then calls the same `BibleXMLImporter` +
`importXML` path (through a tiny throwaway Swift snippet run via
`swift run` or a `swift package plugin`-free script) to import:

- `Afrikaans2020Bible.xml` → `translationId: "afrikaans-2020"` (default)
- `EnglishKJBible.xml` → `translationId: "english-kjv"` (proves multi-translation)

both already present in the `Holy-Bible-XML-Format` submodule — no need to
reach into the sibling `Delta` checkout. The resulting `bible.db` is copied
to `Sources/BibleKit/Resources/bible.db` and committed as a package
resource via `Bundle.module`, replacing the single bundled XML resource
(the submodule itself stays, as the import source for this script and for
`importXML` callers).

`BibleReaderModel` opens the bundled db via `BibleProvider.create(url:
Bundle.module.url(forResource: "bible", withExtension: "db")!)` and defaults
to `translation: TranslationID(rawValue: "afrikaans-2020")`.

## UI rewrite

`BibleReaderModel` changes from "parse everything into memory up front" to:
load state now wraps a `BibleProvider` + the fixed `BookCollection.allBooks`
list (no async needed for the book list itself, since structure is
static); chapter text is fetched on demand via
`provider.chapter(chapter:translation:)` when the user navigates into a
chapter, instead of being available synchronously from an in-memory tree.

`BibleReaderView` keeps its three-level book → chapter → verses navigation
structure; the chapter-detail view becomes async (`.task` per chapter
selection) and shows a `ProgressView` while that chapter loads. Book/chapter
listing text uses `BookDisplayNames` for the current translation instead of
the old Afrikaans-only `bibleBookNames`.

## Licensing

Add `LICENSE` (Apache 2.0, matching upstream) at the repo root. Add a
"Credits" section to `README.md` crediting VerseWell/BibleKit-swift as the
origin of the database/provider architecture, with a link.

## Testing

Upstream's `Tests/BibleKitTests` and `Tests/BibleKitDBTests` are adapted
(not copied verbatim) to thread `translationId`/`translation` through every
call site, plus new cases for: multiple translations coexisting in one db,
`importXML` rejecting a duplicate `(translationId, number)`, and
`translations()` listing what's loaded. `BibleReaderModel`/`BibleReaderView`
get the same load-state coverage the current XML-based version has today,
adapted to the async chapter-fetch flow.

## Risks / open follow-ups

- FTS5 content-table sync assumes `Verse.id` is a stable rowid; GRDB's
  `t.synchronize(withTable:)` handles this automatically as long as we keep
  `id INTEGER PRIMARY KEY` — confirmed compatible with the autoincrement
  surrogate key design above.
- `bible.db` bundled resource size: upstream's example db (single
  translation) is ~18MB; two translations will roughly double that. Worth
  confirming this is acceptable for a package resource before committing it.
- `BookDisplayNames` is a minimal stopgap, not a localization system — flag
  this explicitly in code comments so it isn't mistaken for one.
