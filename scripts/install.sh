#!/bin/bash
# Install the build into the game folder and re-sign it.
set -euo pipefail
GAME="${GAME_DIR:-$HOME/Games/VC}"
SRC="$(cd "$(dirname "$0")/../reVC/build/src/reVC.app" && pwd)"

[ -d "$GAME/data" ] || { echo "no game data in $GAME - set GAME_DIR" >&2; exit 1; }

rsync -a --delete "$SRC/" "$GAME/reVC.app/"
# The build tree keeps the .dev identity so a Finder or Spotlight click on "reVC"
# resolves to an installed copy, never the half-built one without game data.
/usr/bin/plutil -replace CFBundleIdentifier -string "${BUNDLE_ID:-io.github.mrxenginner.reVC}" \
	"$GAME/reVC.app/Contents/Info.plist"
codesign --force --deep --sign - "$GAME/reVC.app" > /dev/null 2>&1
echo "installed: $GAME/reVC.app"
echo "launch with: open \"$GAME/Vice City Mods.app\""
