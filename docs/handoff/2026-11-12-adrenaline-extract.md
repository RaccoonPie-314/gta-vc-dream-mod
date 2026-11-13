# Adrenaline extraction (2026-11-12) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
`vcmods build 428` is installed in `~/Games/VC/reVC.app`. All 43 harness suites
pass. No commit, tag or push was made.

## What changed

- `src/extras/vcmodadrenaline.{cpp,h}` now own the feature: the three file
  statics, `nVCModAdrenalineMode`, `CPlayerPed::ClearAdrenaline`,
  `VCModSuspendAdrenaline`, `VCModUpdateAdrenaline`, and a new
  `VCModAdrenalineOwns(CPlayerPed *)` predicate. The moved function bodies are
  byte-identical to the previous ones (only the `static` on the update function
  is gone).
- `src/peds/PlayerPed.cpp` keeps hooks only: the destructor and
  `SetInitialState` ask `VCModAdrenalineOwns(this)` before `ClearAdrenaline()`,
  `ProcessControl` calls `VCModUpdateAdrenaline(this)`, and `SetRealMoveAnim`
  asks the predicate in its stock adrenaline block. The file is 84 lines
  shorter and no longer includes `CutsceneMgr.h`.
- `vcmodpanel.h` no longer declares the mode or the suspend hook;
  `vcmodpanel.cpp`, `src/core/re3.cpp` and `src/control/Replay.cpp` include the
  feature header. The panel row, debug-menu tweak and ini load are unchanged.
- Harnesses: `test_vc_adrenaline.py` extracts the moved functions from the
  module and compiles the real ownership predicate with them;
  `test_vc_moveanim.py` stubs `VCModAdrenalineOwns` (its cases only cover the
  stock pill); `test_vc_character.py` supplies the moved flag in its panel
  stubs.

Feature-off is unchanged: the predicate is false unless the mode owns the
player, so stock clear, pill expiry and the pill's 2x locomotion behave as
before. No row, help text, diagnostics gate or switch was touched.

## Verification

- All 43 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 428). Installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty).
- Both the build tree and the installed binary report `vcmods build 428`; the
  installed hash differs because `install.sh` re-signs the bundle.
- In game: not yet checked. The short ADRENALINE normal / slow-mo / off pass is
  the one open item.

## Uncommitted

- Modified: `src/peds/PlayerPed.cpp`, `src/extras/vcmodpanel.{cpp,h}`,
  `src/core/re3.cpp`, `src/control/Replay.cpp`, `utils/test_vc_adrenaline.py`,
  `utils/test_vc_character.py`, `utils/test_vc_moveanim.py`.
- New: `src/extras/vcmodadrenaline.{cpp,h}`.
- `vc-mods.patch` predates this refactor; regenerate it after the commit.

## Next

1. Short play check: OFF is the stock pill, NORMAL keeps the native flag
   perks without the 2x legs, SLOW-MO sets the world to 1/3 and restores the
   previous scale when switched back. Then commit only when asked.
2. Extract the next module (`vcmodsit`) the same way: one module per session,
   all 43 harnesses, a build, an install with no session running, and a play
   check.
3. `docs/architecture.md` still groups adrenaline under a future `vcmodcombat`
   in its target table; the standalone module can be folded in when that split
   happens. The other mod blocks left in `PlayerPed.cpp` are ride,
   character/model, street idle and NPC mode.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 428 is
> installed. Read `docs/handoff/2026-11-12-adrenaline-extract.md` first.
> Adrenaline now lives in `src/extras/vcmodadrenaline.{cpp,h}` and
> `PlayerPed.cpp` keeps hooks only; all 43 harnesses pass and the build is
> installed. The short in-game normal / slow-mo / off check is still open.
> Then extract the next module (`vcmodsit`) the same way: one module per
> session, all 43 harnesses, a build, an install only with no session running,
> and a play check. Never commit or push unless asked; game data and uchg anim
> files are read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before
> any install.
