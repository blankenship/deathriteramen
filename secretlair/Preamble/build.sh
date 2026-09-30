#!/bin/bash
# Builds Preamble.app next to this script.
set -euo pipefail
cd "$(dirname "$0")"

APP="Preamble.app"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -parse-as-library \
  -target "${ARCH}-apple-macos13.0" \
  Sources/Preamble.swift \
  -o "$APP/Contents/MacOS/Preamble"

codesign --force --sign - "$APP"

echo "Built $PWD/$APP"
