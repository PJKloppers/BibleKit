#!/bin/sh
set -e
cd "$(dirname "$0")/.."

XML_DIR="Sources/BibleKit/Resources/Holy-Bible-XML-Format"
OUTPUT_DB="Sources/BibleKit/Resources/bible.db"

echo "Generating bundled database from $XML_DIR..."
swift run GenerateBundledDB "$XML_DIR" "$OUTPUT_DB"

echo "✅ Wrote $OUTPUT_DB"
