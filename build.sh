#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LongShot"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
find "$ROOT_DIR/Resources" -maxdepth 1 \( -name '*.icns' -o -name '*.png' \) -exec cp {} "$RESOURCES_DIR/" \;

xcrun swiftc \
  -swift-version 5 \
  -target arm64-apple-macos13.0 \
  "$ROOT_DIR"/Sources/LongShot/*.swift \
  -o "$MACOS_DIR/$APP_NAME" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework ScreenCaptureKit \
  -framework UniformTypeIdentifiers

chmod +x "$MACOS_DIR/$APP_NAME"

SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development/ { print $2; exit }')"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
  echo "Signed with $SIGN_IDENTITY"
else
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
  echo "Signed ad-hoc"
fi

echo "Built $APP_DIR"
