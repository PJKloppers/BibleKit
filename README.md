# BibleKit

A small Swift package with everything needed to read a Bible translation in a SwiftUI app: the
data models, an XML parser, an observable view model, and a ready-to-use reading screen.

Built to be shared between [BibleReader](https://github.com/PJKloppers/BibleReader) (a standalone
reading app) and [Delta](https://github.com/PJKloppers/Delta), so the parsing and UI code lives in
one place instead of being duplicated across apps.

## What's inside

- `BibleModels.swift` — `BibleBook`, `BibleChapter`, `BibleVerse`, `BibleTestament`
- `BibleParser.swift` — a streaming `XMLParser`-based parser for the
  [Holy-Bible-XML-Format](https://github.com/PJKloppers/Holy-Bible-XML-Format) dataset
- `BibleReaderModel.swift` — an `@Observable` view model that loads a translation off the main actor
- `BibleReaderView.swift` — a `NavigationStack`-based book → chapter → verses reading screen

## Data source

The Bible text lives in `Sources/BibleKit/Resources/Holy-Bible-XML-Format`, a git submodule of the
[Holy-Bible-XML-Format fork](https://github.com/PJKloppers/Holy-Bible-XML-Format). BibleKit bundles
one translation (Afrikaans 2020) as a package resource via `Bundle.module`, so consuming apps get a
working Bible out of the box with no extra setup.

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

Or use the pieces directly — `BibleParser.parseBundled()` returns the parsed translation and
books, and `BibleReaderModel` wraps that in an observable load state for your own UI.

## Credits

BibleKit's database layer and provider API are adapted from
[VerseWell/BibleKit-swift](https://github.com/VerseWell/BibleKit-swift)
(Apache License 2.0), extended here to support multiple translations in one
shared database and to import additional translations on-device.
