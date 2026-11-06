#!/bin/bash
# Assemble the folder that can go public: patch, docs, scripts. Nothing else.
# Builds into a temp stage, scans it, then syncs it onto OUT (keeping OUT/.git),
# so re-running after a commit refreshes an existing repo instead of refusing.
# It never inits a repo, adds a remote, or pushes.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$HOME/Desktop/vc-mod-public}"
UPSTREAM_URL="https://github.com/mrxenginner/reVC"
BRANCH="miami"
PIN=a26fff4
MOD="$(git -C "$HERE/reVC" log --format='    %h %s' "$PIN..vcmods")"

for f in README.md CHANGELOG.md vc-mods.patch; do
	[ -f "$HERE/$f" ] || { echo "missing $HERE/$f, run scripts/sync.sh" >&2; exit 1; }
done
if [ -e "$OUT" ] && [ ! -f "$OUT/UPSTREAM.md" ]; then
	echo "$OUT exists and isn't a folder this script made - refusing to touch it" >&2
	exit 1
fi

# The license condition digests SystemName:OperatorName:ISODate:RepoURL. Don't
# invent an operator; leave the field unfilled and say so in the file.
stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if [ -n "${VC_MODS_OPERATOR:-}" ]; then
	hash=$(printf '%s' "Qoder agent:${VC_MODS_OPERATOR}:${stamp}:${UPSTREAM_URL}" | shasum -a 256 | cut -d' ' -f1)
else
	hash='(unset - rerun with VC_MODS_OPERATOR="name" set)'
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/repo/scripts"
cp "$HERE/README.md" "$HERE/CHANGELOG.md" "$HERE/vc-mods.patch" "$stage/repo/"
cp "$HERE"/scripts/*.sh "$stage/repo/scripts/"
cp "$HERE/reVC/LICENSE.md" "$stage/repo/"

cat > "$stage/repo/UPSTREAM.md" <<EOF
# Where this came from

Built against [$UPSTREAM_URL]($UPSTREAM_URL), branch \`$BRANCH\`, commit \`$PIN\`.
Mod commits on top of it:

$MOD

reVC is MIT with a proof-of-usage condition (see LICENSE.md). That condition
applies to automated systems that read this repository too, so any tool that
ingests it records a row in upstream's PROOF_OF_USAGE.md.

Usage record for the build of this folder:

    System:   Qoder agent
    Operator: ${VC_MODS_OPERATOR:-(not supplied at build time)}
    Date:     $stamp
    Target:   $UPSTREAM_URL
    Hash:     $hash

## Rebuilding

\`\`\`
scripts/bootstrap.sh [dest]   # clone upstream, detach to $PIN, apply vc-mods.patch
scripts/build.sh              # cmake, Release
scripts/install.sh            # drop the bundle into the game folder, re-sign
\`\`\`

Game data is not here and can't be: it's Rockstar's. Bring your own licensed copy.
EOF

cat > "$stage/repo/.gitignore" <<'EOF'
reVC/
build/
*.zip
.DS_Store
EOF

leaks=$(find "$stage/repo" \( -type d \( -name data -o -name models -o -name gamefiles \) \
	-o -type f \( -iname '*.set' -o -iname '*.dat' -o -iname '*.ide' -o -iname '*.ied' \
	-o -iname 'gta-vc.exe' -o -iname 'mss32.dll' -o -iname 'revc.ini' -o -iname 'revc.log' \
	-o -iname 'savegame*' \) \) -print 2>/dev/null || true)
if [ -n "$leaks" ]; then
	echo "refusing to publish, found local or Rockstar content:" >&2
	printf '%s\n' "$leaks" | sed 's/^/  /' >&2
	exit 1
fi

mkdir -p "$OUT"
rsync -a --delete --exclude '.git' "$stage/repo/" "$OUT/"
echo "wrote: $OUT ($(du -sh "$OUT" | cut -f1))"
find "$OUT" -type f -not -path "$OUT/.git/*" | sed "s|^$OUT/||" | sort
echo
if [ -d "$OUT/.git" ]; then
	echo "refreshed an existing repo - commit and push from inside it."
else
	echo "to publish, from inside that folder:"
	echo "  git init -b main && git add -A && git commit -m 'patch set against reVC $PIN'"
	echo "  git remote add origin <your repo url> && git push -u origin main"
fi
