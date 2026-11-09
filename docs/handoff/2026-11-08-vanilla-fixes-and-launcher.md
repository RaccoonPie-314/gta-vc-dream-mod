# Handoff — vanilla fixes batch 1, launcher and build number (2026-11-08)

## Where things are

- Workspace `vc-mod`, code in `reVC/`,
  branch `vcmods`, HEAD `d01bb3c` plus the uncommitted work below.
- Build `scripts/build.sh`; install `scripts/install.sh`; launcher `scripts/make-launcher.sh`;
  tests `python3 utils/test_vc_*.py` from `reVC/`.
- Installed app `~/Games/VC/reVC.app`, currently **`vcmods build 36`**:
  `strings ~/Games/VC/reVC.app/Contents/MacOS/reVC | grep '^vcmods build '`.
- Logs `~/Games/VC/build-launch.log` and `~/Games/VC/reVC.log`; crash reports
  `~/Library/Logs/DiagnosticReports/reVC-*.ips`.
- Plans and docs: `docs/plans/2026-11-08-batch1-vanilla-fixes.md`, `docs/launcher.md`.
- User settings `~/Library/Application Support/reVC/reVC.ini` (`DrawVersionText=1` now).

## State

Shipped and seen in game (build 36): the batch-1 behaviours, the `VANILLA FIXES` panel row,
the bottom-right `vcmods build 36` line. All seven harnesses pass.

Uncommitted in `reVC/` (the user commits; never push):

- **Batch 1** — `src/extras/vcmodqol.{h,cpp}` (flags, money/stars helpers, exit-hold tick,
  particle lifespan pass), wiring in `Hud.cpp`, `Automobile.cpp`, `PlayerInfo.cpp`,
  `Particle.cpp`, `re3.cpp`, `vcmodpanel.cpp`.
- **Startup crash fix** — `src/core/FileMgr.cpp`, `bundledPath` lifetime in `myfopen`.
  Critical: without it the game segfaults in `CText::Load` on many builds.
- **Bundle identity** — `res/macos/Info.plist` builds as `…reVC.dev`; `scripts/install.sh`
  stamps the shipping id and now supports `BUNDLE_ID`. Same edit mirrored into
  `gta-vc-dream-mod/scripts/install.sh`.
- **Version line** — build counter in `src/CMakeLists.txt`, drawn from `src/core/main.cpp`;
  `scripts/make-launcher.sh` (both copies) logs the number after install.
- **Tests** — new `utils/test_vc_qol.py`; flag stubs in `test_vc_adrenaline.py` and
  `test_vc_character.py`; `test_vc_passenger.py` row count 26.
- **Not ours** — `src/peds/PlayerPed.cpp` is another agent's kerbside road-cross look,
  already compiled into build 36. Do not edit or stage it.
- **Provenance** — `docs/plans/2026-11-08-vice-extended-picks.md` now carries the pack evidence
  per row (changelog line, `features.ini` toggle, content or code) and an "Unverified
  constants" table: particle ×2 and exit hold 400 ms are ours, not read from `ViceEx.exe`.

Launcher: the Dock pin `~/Games/VC/Vice City Mods.app` (`local.vcmods.launcher`) was
regenerated with the build-number log line. It builds, installs, then execs the installed
app. Guide in `docs/launcher.md`.

## Next, in order

1. Play build 36 and work the plan's checklist: money `$0`/`$1234`, no empty stars, wheel
   angle survives exit, exit hold stops engine and lights, blood and sand last ~2x, and
   `VANILLA FIXES` off reverts all five.
2. Batch-1 item 6 (in game): door slam and bike fire are expected to already work in reVC;
   confirm and close or fix the path that bypasses them.
3. Batch-1 item 7: mirror mode has no defined meaning. Ask before building (flipped
   viewport / rear-view mirror / the pack's debug toggle).
4. Commit once the user is satisfied. Everything above is one coherent change set, but the
   FileMgr fix is worth its own commit message if they prefer it separate.

## Traps paid for this session

- `myfopen` in `FileMgr.cpp` must keep `bundledPath` alive until `fcaseopen`; the mods
  commit had scoped it to the `else` block. Symptom is intermittent: `CText::Load` passes a
  nil fd to `fread` and segfaults at startup (it does not check the open).
- `CFont::SetJustifyOff()` also clears `rightJustify`; call `SetRightJustifyOn()` after it.
- Three bundles shared `io.github.mrxenginner.reVC`; a click could resolve to the build
  tree, which has no game data and opens the folder chooser. The dev tree is `.dev` now.
- The build number lives in `reVC/build/vcmods-build-number`, incremented at configure; a
  wiped build tree reseeds from `git rev-list --count HEAD`. Configure can increment twice
  in one build, so numbers may skip — they only ever go up.
- Never install while `pgrep -f "reVC.app/Contents/MacOS/reVC"` is non-empty.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Do not edit other agents' files: `src/core/re3.cpp`, `src/extras/vcmodpanel.*`,
  `src/peds/PlayerPed.cpp` were each owned by someone else at some point; check
  `git status` and the newest handoff before touching them.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC`
  is read-only.
- The user plays and tests themselves; do not claim an in-game fix without their run.
