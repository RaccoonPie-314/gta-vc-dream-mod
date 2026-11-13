#!/bin/bash
# Build, install and start the game in this terminal, with output visible.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GAME="${GAME_DIR:-$HOME/Games/VC}"

# A non-login shells starts with a minimal PATH; Homebrew tools live outside it.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if pgrep -f "reVC.app/Contents/MacOS/reVC" >/dev/null; then
	echo "reVC is already running - quit it first" >&2
	exit 1
fi

echo "=== $(date '+%Y-%m-%d %H:%M:%S') $(git -C "$HERE/reVC" log --oneline -1)"

"$HERE/scripts/build.sh" || { echo "build failed - not installing" >&2; exit 1; }
GAME_DIR="$GAME" "$HERE/scripts/install.sh" || { echo "install failed - not starting" >&2; exit 1; }

strings "$GAME/reVC.app/Contents/MacOS/reVC" | grep -m1 '^vcmods build ' || true

cd "$GAME" || exit 1
exec "$GAME/reVC.app/Contents/MacOS/reVC"
