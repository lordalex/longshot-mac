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
ditto "$SOURCE_APP" "$DEST_APP"
xattr -cr "$DEST_APP"
codesign --verify --deep --strict --verbose=2 "$DEST_APP"

echo "Installed $DEST_APP"
echo "Open it with: open '$DEST_APP'"
