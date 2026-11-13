# Vice City Mods launcher

How the Dock launcher is built, what a click actually does, and what to check when it
does not work. macOS-specific; the Windows equivalent is the portable folder with
`Play.bat` (see the portability rules in `AGENTS.md`).

## The pieces

| Path | What it is |
| --- | --- |
| `~/Games/VC/Vice City Mods.app` | The Dock pin. Bundle id `local.vcmods.launcher`. |
| `…/Contents/MacOS/vcmods-launcher` | Tiny C wrapper that execs the shell script. It must be a real binary: macOS only offers the Documents permission prompt to a bundle whose main executable is native. |
| `…/Contents/Resources/launcher.sh` | Build, install, launch. The repo path is baked in at generation time. |
| `scripts/make-launcher.sh` | Regenerates the bundle. Takes an optional destination path. |
| `scripts/build.sh` | CMake configure plus Release build into `reVC/build/src/reVC.app`. |
| `scripts/install.sh` | rsync into `$GAME_DIR/reVC.app`, stamp the shipping bundle id, ad-hoc sign. |
| `~/Games/VC/reVC.app` | The game that actually runs. |
| `~/Games/VC/build-launch.log` | Every launcher run: commit, build output, install, binary sha256. |
| `~/Games/VC/reVC.log` | Game stdout/stderr, appended by the launcher. |

`~/Games/VC-ai/` is a separate test install with its own app copy; nothing here
touches it.

## What a click does

1. `pgrep -f "reVC.app/Contents/MacOS/reVC"` — refuses if a session is already running.
2. Reads one byte of `scripts/build.sh` — this is the Documents-permission probe.
3. Logs `=== <timestamp> <commit>` and runs `scripts/build.sh`, then `scripts/install.sh`,
   then prints the installed binary's sha256.
4. `cd ~/Games/VC` and `exec reVC.app/Contents/MacOS/reVC`, appending to `reVC.log`.

So the launcher always builds and installs before it starts the game. That is the point
of pinning it instead of the game: a click cannot start a stale build.

## Making it

```sh
scripts/make-launcher.sh                       # writes ~/Games/VC/Vice City Mods.app
scripts/make-launcher.sh /path/to/Other.app    # or somewhere else
```

It refuses while a session is running, writes `Info.plist`, the C wrapper and
`launcher.sh`, replaces `@REPO@` with this checkout, signs ad-hoc, and re-registers the
bundle with LaunchServices.

Then pin it:

1. Drag `Vice City Mods.app` to the Dock, right-click the tile, **Options → Keep in Dock**.
2. Check it resolves: `open -b local.vcmods.launcher` (this builds and launches).
3. Never pin `reVC.app`. It shares its identity with installed copies of the game, and a
   click can land on the build tree, which has no game data and opens the folder chooser.

If the checkout moves, regenerate the launcher: `@REPO@` is a literal path inside it.

## Checking you are running the right build

The bottom right of the screen shows one plain number:

```
vcmods build 32
```

Every build adds one, so a higher number is always a newer binary. Just quote it:
"the bug is on build 32" or "build 33 fixed it". The counter lives in
`reVC/build/vcmods-build-number`; if the build folder is wiped it restarts from the
commit count instead of from zero.

Turn the line off with `[General] DrawVersionText=0` in `reVC.ini`, or the debug menu's
**Debug → Version Text**.

To tie a number to a launcher run, the newest `===` block in `build-launch.log` records
the time, the commit, and (once the launcher has been regenerated with the current
scripts) the same `vcmods build N` line, followed by the binary's sha256.

## Troubleshooting

### Clicking the tile does nothing, or the wrong app opens

Two bundles are competing for the same identifier. List what claims it:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump |
    grep -E "path:.*reVC\.app|identifier:.*mrxenginner" | sort -u
```

The build tree is `io.github.mrxenginner.reVC.dev`; installed copies are
`io.github.mrxenginner.reVC`; the launcher is `local.vcmods.launcher`. If the dev tree
shows the shipping id, the binary predates the split — rebuild. Re-register a bundle with
`lsregister -f <path>`. Then re-pin the launcher.

### A Finder window asks you to choose the game folder

The engine could not find `data/gta_vc.dat` and `models/gta3.img` at the executable's
root. That is the build-tree app (`reVC/build/src/reVC.app`), which has no game data —
start through the launcher. If the launcher itself shows the chooser, the installed copy
is incomplete: `ls ~/Games/VC/data/gta_vc.dat ~/Games/VC/models/gta3.img`.

### "reVC is already running"

A previous session is still alive, usually after a crash left the process behind:

```sh
pgrep -fl "reVC.app/Contents/MacOS/reVC"
```

Quit it normally if possible; otherwise terminate that PID. The launcher refuses to
install over a running session on purpose.

### "macOS is blocking access to the mod source"

The launcher app was denied Documents access. Open **System Settings → Privacy &
Security → Files and Folders** (or give the app Full Disk Access), add
`Vice City Mods.app`, and click the tile again.

### "Build or install failed"

Read the tail of `build-launch.log`. Reproduce in a terminal:

```sh
scripts/build.sh && scripts/install.sh
```

A configure error is usually a missing Homebrew dependency; a build error names the
file. The launcher will not start the game when either step fails.

### The game quits immediately, or macOS shows a crash report

- Tail `~/Games/VC/reVC.log` — buffered output is lost on a crash, so an empty log is
  normal for a startup segfault.
- Crash reports: `~/Library/Logs/DiagnosticReports/reVC-*.ips`. Decode one with:

```sh
python3 - <<'PY'
import json,glob,os
p=sorted(glob.glob(os.path.expanduser("~/Library/Logs/DiagnosticReports/reVC-*.ips")),key=os.path.getmtime)[-1]
head,body=open(p).read().split("\n",1); b=json.loads(body)
print(b.get("procPath"), b.get("exception"))
t=b["threads"][b["faultingThread"]]; imgs=b["usedImages"]
for f in t["frames"][:12]:
    img=imgs[f["imageIndex"]]
    print(img.get("name"), f.get("symbol"))
PY
```

The first few frames name the subsystem. Example: `CText::Load → fread` means a text
file failed to open (a `fread` on a nil handle — `CText::Load` does not check the fd).

- Confirm the binary matches the source: version line vs `build-launch.log`.

### The installed build is older than the checkout

The launcher always rebuilds, so check the timestamp and commit of the newest `===`
block in `build-launch.log`. If it did not run, you clicked something else; if it ran and
the commit is old, the repo path baked into the launcher points at a different checkout
(regenerate it).

### Game data is never touched

`install.sh` only writes inside `$GAME/reVC.app/`. Never "clean" `~/Games/VC/data`,
`models`, `anim` or `~/Library/Application Support/reVC/` to fix a launcher problem.
