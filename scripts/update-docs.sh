#!/bin/sh

set -e

# Regenerates the DocC API reference into ./docs. `generate-documentation
# --output-path` takes full ownership of that directory (it clears it first),
# so the hand-written landing page (docs/index.html) and the GitHub Pages
# CNAME are backed up beforehand and restored afterward.

cd "$(dirname "$0")/.."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Backing up landing page and CNAME..."
cp docs/index.html "$TMP_DIR/index.html"
cp docs/CNAME "$TMP_DIR/CNAME"

echo "Generating documentation for BibleKit and BibleKitDB..."
swift package --disable-sandbox generate-documentation \
    --warnings-as-errors \
    --symbol-graph-minimum-access-level package \
    --enable-experimental-combined-documentation \
    --target BibleKit \
    --target BibleKitDB \
    --output-path ./docs \
    --transform-for-static-hosting

echo "Restoring landing page and CNAME..."
cp "$TMP_DIR/index.html" docs/index.html
cp "$TMP_DIR/CNAME" docs/CNAME

echo "✅ Documentation generated in ./docs/documentation (landing page and CNAME left untouched)"
