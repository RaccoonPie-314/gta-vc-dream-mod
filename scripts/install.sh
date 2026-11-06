#!/bin/bash
# Install the build into the game folder and re-sign it.
set -euo pipefail
GAME="${GAME_DIR:-$HOME/Games/VC}"
SRC="$(cd "$(dirname "$0")/../reVC/build/src/reVC.app" && pwd)"

[ -d "$GAME/data" ] || { echo "no game data in $GAME - set GAME_DIR" >&2; exit 1; }

rsync -a --delete "$SRC/" "$GAME/reVC.app/"
codesign --force --deep --sign - "$GAME/reVC.app" > /dev/null 2>&1
echo "installed: $GAME/reVC.app"
echo "launch with: open \"$GAME/Vice City Mods.app\""
