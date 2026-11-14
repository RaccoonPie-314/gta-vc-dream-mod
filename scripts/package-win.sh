#!/bin/bash
# Make the portable Windows folder: the game, the Windows reVC.exe and Play.bat,
# zipped for a copy-and-play unpack. Runs on macOS, Linux and Git Bash.
#
#   scripts/package-win.sh                          # personal: with game data
#   scripts/package-win.sh --public                 # no Rockstar data
#   scripts/package-win.sh --exe /path/to/reVC.exe  # a build elsewhere
#   scripts/package-win.sh --out /some/folder       # where the zip lands
#
# The Windows exe is not built on this Mac; build it on Windows with
# premake-vs2022.cmd, then point --exe at it or leave the build in reVC/bin.
set -euo pipefail
GAME="${GAME_DIR:-$HOME/Games/VC}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

exe=""
out="$HERE/dist"
public=false
while [ $# -gt 0 ]; do
	case "$1" in
	--exe) exe="$2"; shift 2 ;;
	--out) out="$2"; shift 2 ;;
	--public) public=true; shift ;;
	*) echo "unknown argument: $1" >&2; exit 2 ;;
	esac
done

if [ -z "$exe" ]; then
	for candidate in \
		"$HERE/reVC/bin/win-amd64-librw_d3d9-oal/Vanilla/reVC.exe" \
		"$HERE/reVC/bin/win-amd64-librw_gl3_glfw-oal/Vanilla/reVC.exe" \
		"$HERE/reVC/bin/win-x86-librw_d3d9-mss/Vanilla/reVC.exe"; do
		[ -f "$candidate" ] && { exe="$candidate"; break; }
	done
fi
[ -n "$exe" ] && [ -f "$exe" ] || {
	echo "no Windows reVC.exe found - build one on Windows and pass --exe" >&2
	exit 1
}
[ -f "$HERE/scripts/windows/Play.bat" ] || { echo "missing scripts/windows/Play.bat" >&2; exit 1; }

name="VC-mod-$(date +%Y%m%d)-$( $public && echo public || echo personal )-win"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/$name"

cp "$exe" "$stage/$name/reVC.exe"
cp "$HERE/scripts/windows/Play.bat" "$stage/$name/"
cp "$HERE/README.md" "$HERE/CHANGELOG.md" "$HERE/vc-mods.patch" "$stage/$name/" 2>/dev/null || true

if $public; then
	# the mod's own assets travel; the game data does not
	cp -R "$GAME/mods" "$stage/$name/mods"
else
	[ -d "$GAME/data" ] || { echo "no game data in $GAME - set GAME_DIR" >&2; exit 1; }
	for entry in "$GAME"/*; do
		base="$(basename "$entry")"
		case "$base" in
		reVC.app|*.app|*.log|gta-vc.exe|dock-prefs-*.plist) continue ;;
		esac
		cp -R "$entry" "$stage/$name/$base"
	done
fi

mkdir -p "$out"
folder="$out/$name"
rm -rf "$folder"
mv "$stage/$name" "$folder"
rmdir "$stage"

echo "folder: $folder"
if command -v zip >/dev/null 2>&1; then
	(cd "$out" && zip -qr "$name.zip" "$name")
	echo "archive: $out/$name.zip"
	echo "size: $(du -sh "$out/$name.zip" | cut -f1)"
	echo "sha256: $(shasum -a 256 "$out/$name.zip" | cut -d' ' -f1)"
else
	echo "zip is not installed; send the folder as it is"
fi
echo "on Windows: unpack, then run Play.bat in the folder"
