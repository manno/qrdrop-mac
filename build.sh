#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="QRDrop"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/Sources/QRDropApp.swift" \
  "$ROOT_DIR/Sources/ContentView.swift" \
  "$ROOT_DIR/Sources/QRCodeRenderer.swift" \
  -o "$MACOS_DIR/$APP_NAME" \
  -framework SwiftUI \
  -framework AppKit \
  -framework CoreImage \
  -framework UniformTypeIdentifiers

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "Built $APP_DIR"
