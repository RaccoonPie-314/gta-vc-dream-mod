#!/bin/bash
# Get the mod's source off this machine. Run it from anywhere; it finds the
# checkout itself, so it can't be pointed at the wrong repository.
#
#   scripts/backup.sh                  # push what is already committed
#   scripts/backup.sh "commit message"  # commit everything first, then push
#
# The target is the `backup` remote (RaccoonPie-314/reVC-mod, private). `origin`
# stays upstream and is never written to: it grants read access only.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$HERE/reVC"
REMOTE=backup
BRANCH=vcmods

[ -d "$REPO/.git" ] || { echo "no checkout at $REPO - run scripts/bootstrap.sh" >&2; exit 1; }
git -C "$REPO" remote get-url "$REMOTE" >/dev/null 2>&1 || {
	echo "no '$REMOTE' remote in $REPO. Add it:" >&2
	echo "  git -C '$REPO' remote add $REMOTE https://github.com/RaccoonPie-314/reVC-mod.git" >&2
	exit 1
}

if [ $# -gt 0 ]; then
	git -C "$REPO" add -A
	if git -C "$REPO" diff --cached --quiet; then
		echo "nothing to commit"
	else
		git -C "$REPO" commit -m "$1"
	fi
elif [ -n "$(git -C "$REPO" status --porcelain)" ]; then
	echo "warning: uncommitted changes stay on this machine. Pass a message to commit them:" >&2
	git -C "$REPO" status --short >&2
fi

git -C "$REPO" push "$REMOTE" "$BRANCH"
echo "backed up: $(git -C "$REPO" log --oneline -1) -> $REMOTE/$BRANCH"
