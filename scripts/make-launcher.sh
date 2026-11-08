#!/bin/bash
# Generate the Dock launcher app that builds, installs and starts the game.
# A native main executable is required: macOS only offers the Documents
# permission prompt to an app bundle whose main executable is a binary.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$HOME/Games/VC/Vice City Mods.app}"

pgrep -f "reVC.app/Contents/MacOS/reVC" >/dev/null && {
	echo "reVC is running - quit it first" >&2
	exit 1
}
[ -w "$(dirname "$APP")" ] || { echo "cannot write to $(dirname "$APP")" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>vcmods-launcher</string>
	<key>CFBundleIdentifier</key><string>local.vcmods.launcher</string>
	<key>CFBundleName</key><string>Vice City Mods</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSDocumentsFolderUsageDescription</key>
	<string>Read the mod source under ~/Documents to build the game before launching.</string>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/launcher.c" <<'C'
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int
main(void)
{
	char exe[PATH_MAX];
	uint32_t size = sizeof(exe);
	char script[PATH_MAX];
	char *slash;

	if (_NSGetExecutablePath(exe, &size) != 0)
		return 1;
	slash = strrchr(exe, '/');
	if (slash == NULL)
		return 1;
	*slash = '\0';
	snprintf(script, sizeof(script), "%s/../Resources/launcher.sh", exe);
	char *argv[] = { "/bin/bash", script, NULL };
	execv("/bin/bash", argv);
	perror("execv");
	return 1;
}
C

cat > "$APP/Contents/Resources/launcher.sh" <<'SCRIPT'
#!/bin/bash
# Build, install into this folder, then launch. Quit the game before using it.
DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
REPO="${VCMODS_REPO:-@REPO@}"
LOG="$DIR/build-launch.log"

# A Dock launch starts with a minimal PATH; Homebrew tools live outside it.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

notify() {
	osascript -e "display notification \"$1\" with title \"Vice City Mods\"" >/dev/null 2>&1
}

if pgrep -f "reVC.app/Contents/MacOS/reVC" >/dev/null; then
	notify "reVC is already running. Quit it, then launch again."
	exit 1
fi

# The first read may prompt for Documents access. If it was refused, say so
# instead of building stale code or starting an old binary.
if [ -f "$REPO/scripts/build.sh" ] && ! head -c 1 "$REPO/scripts/build.sh" >/dev/null 2>&1; then
	notify "macOS is blocking access to the mod source. Allow Vice City Mods in Privacy settings."
	open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
	exit 1
fi

if [ -x "$REPO/scripts/build.sh" ]; then
	{
		echo "=== $(date '+%Y-%m-%d %H:%M:%S') $(git -C "$REPO/reVC" log --oneline -1)"
		"$REPO/scripts/build.sh" &&
		"$REPO/scripts/install.sh" &&
		shasum -a 256 "$DIR/reVC.app/Contents/MacOS/reVC"
	} >> "$LOG" 2>&1
	if [ $? -ne 0 ]; then
		notify "Build or install failed, game not started. See build-launch.log."
		exit 1
	fi
else
	notify "No build scripts at $REPO. Launching the installed build."
fi

cd "$DIR" || exit 1
exec "$DIR/reVC.app/Contents/MacOS/reVC" >> "$DIR/reVC.log" 2>&1
SCRIPT

sed -i '' "s|@REPO@|$HERE|" "$APP/Contents/Resources/launcher.sh"
chmod +x "$APP/Contents/Resources/launcher.sh"
cc -O2 -o "$APP/Contents/MacOS/vcmods-launcher" "$APP/Contents/MacOS/launcher.c"
rm "$APP/Contents/MacOS/launcher.c"

codesign --force --sign - "$APP" >/dev/null
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
[ -x "$lsregister" ] && "$lsregister" -f "$APP" >/dev/null

echo "wrote: $APP"
codesign -dv "$APP" 2>&1 | grep -E "Identifier|Format"
