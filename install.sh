#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LongShot"
SOURCE_APP="$ROOT_DIR/build/$APP_NAME.app"
DEST_APP="/Applications/$APP_NAME.app"

if [[ ! -d "$SOURCE_APP" ]]; then
  "$ROOT_DIR/build.sh"
fi

pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$DEST_APP"
ditto "$SOURCE_APP" "$DEST_APP"
xattr -cr "$DEST_APP"
touch "$DEST_APP/Contents/Info.plist" "$DEST_APP/Contents/Resources/AppIcon.icns"
touch "$DEST_APP"
codesign --verify --deep --strict --verbose=2 "$DEST_APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -u "$DEST_APP" >/dev/null 2>&1 || true
  "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
fi

qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
osascript -e "tell application \"Finder\" to update POSIX file \"$DEST_APP\"" >/dev/null 2>&1 || true

echo "Installed $DEST_APP"
echo "Open it with: open '$DEST_APP'"
