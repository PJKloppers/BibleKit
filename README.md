# BibleKit

A Swift package with everything needed to read and search a Bible translation in a SwiftUI app:
a GRDB/SQLite-backed database layer, an async provider API, and a ready-to-use reading screen.

Built to be shared between [BibleReader](https://github.com/PJKloppers/BibleReader) (a standalone
reading app) and [Delta](https://github.com/PJKloppers/Delta), so the parsing and UI code lives in
one place instead of being duplicated across apps.

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

## Data source

BibleKit bundles a pre-built `bible.db` (package resource, via `Bundle.module`) covering two
translations out of the box: `"afrikaans-2020"` (default) and `"english-kjv"`. Both were generated
from `Sources/BibleKit/Resources/Holy-Bible-XML-Format`, a git submodule of the
[Holy-Bible-XML-Format fork](https://github.com/PJKloppers/Holy-Bible-XML-Format), via
`scripts/generate-bundled-db.sh`. The submodule stays in the repo as the import source for that
script and for any consuming app that wants to `importXML` further translations at runtime.

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/PJKloppers/BibleKit.git
```

Or, if already cloned:

```bash
git submodule update --init --recursive
```

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

Import another Holy-Bible-XML-Format file at runtime with
`provider.importXML(url:translationID:displayName:language:)`.

## Credits

BibleKit's database layer and provider API are adapted from
[VerseWell/BibleKit-swift](https://github.com/VerseWell/BibleKit-swift)
(Apache License 2.0), extended here to support multiple translations in one
shared database and to import additional translations on-device.
