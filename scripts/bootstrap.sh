#!/bin/bash
# Rebuild the mod from scratch: clone upstream at the pinned commit, apply the patch.
# This is the file to read when porting to another OS - the patch is the whole mod.
set -euo pipefail
UPSTREAM="https://github.com/mrxenginner/reVC"
BRANCH="miami"
PIN="a26fff4"			# the commit vc-mods.patch was written against
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$HERE/reVC}"

[ -d "$DEST/.git" ] && { echo "$DEST already is a checkout, refusing to touch it" >&2; exit 1; }

git clone --branch "$BRANCH" "$UPSTREAM" "$DEST"
cd "$DEST"
# Only librw is needed on this build: ogg/opus/opusfile stay empty here and
# CMake takes audio from Homebrew instead. A --recursive init pulls all four and
# changes nothing.
git submodule update --init vendor/librw
git checkout --detach "$PIN"
git submodule update --init vendor/librw
git checkout -b vcmods
git apply "$HERE/vc-mods.patch"
echo "applied onto $PIN. If this failed, upstream moved: re-derive the patch against a newer pin."
