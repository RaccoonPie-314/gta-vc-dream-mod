#!/bin/bash
# Make the copy-and-play archive. Default keeps the game data so the stick is
# self-contained and stays personal. --public strips it, for anything that leaves
# your hands: CMake copies 13 MB of Rockstar's files into the bundle at build time.
set -euo pipefail
GAME="${GAME_DIR:-$HOME/Games/VC}"
SETTINGS="$HOME/Library/Application Support/reVC"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$HOME/Desktop}"

public=false
[ "${1:-}" = "--public" ] && { public=true; OUT="${2:-$HOME/Desktop}"; }

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$GAME" "$stage/VC"
mkdir -p "$stage/VC/reVC-settings"
ditto "$SETTINGS" "$stage/VC/reVC-settings" 2>/dev/null || true
cp "$HERE/vc-mods.patch" "$HERE/README.md" "$HERE/CHANGELOG.md" "$stage/VC/" 2>/dev/null || true

if $public; then
	rm -rf "$stage/VC/reVC.app/Contents/Resources/gamefiles"
	rm -f "$stage/VC/gta-vc.exe" "$stage/VC/Mss32.dll"
	rm -rf "$stage/VC/reVC-settings"
	find "$stage/VC" -maxdepth 1 -type d -name data -o -maxdepth 1 -type d -name models | xargs rm -rf
else
	rm -f "$stage/VC/gta-vc.exe"			# the i386 port never runs on arm64 anyway
fi

name="VC-mod-$(date +%Y%m%d)-$("$public" && echo public || echo personal).zip"
ditto -c -k --keepParent "$stage/VC" "$OUT/$name"
echo "archive: $OUT/$name"
echo "size: $(du -sh "$OUT/$name" | cut -f1)"
echo "sha256: $(shasum -a 256 "$OUT/$name" | cut -d' ' -f1)"
