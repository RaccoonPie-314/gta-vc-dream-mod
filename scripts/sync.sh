#!/bin/bash
# Regenerate vc-mods.patch from the vcmods branch. Never hand-edit the patch.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE/reVC"

branch=$(git branch --show-current)
if [ "$branch" != "vcmods" ]; then
	echo "on '$branch', expected 'vcmods'. Nothing written." >&2
	exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
	echo "working tree is dirty - commit to vcmods first, then re-run." >&2
	exit 1
fi

git diff miami..vcmods > "$HERE/vc-mods.patch"
echo "patch: $(grep -c '^+++' "$HERE/vc-mods.patch") files, $(git diff --shortstat miami..vcmods)"
