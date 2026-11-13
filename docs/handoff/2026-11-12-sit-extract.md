# Sit extraction (2026-11-12) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
`vcmods build 429` is installed in `~/Games/VC/reVC.app`. All 43 harness suites
pass. No commit, tag or push was made.

## What changed

- `src/extras/vcmodsit.{cpp,h}` now own seat handling: the seat statics and
  tuning constants, the seat-user scan, `VCModStreetFindSeat`, the sit
  down/up/refused helpers, the engine-sit adoption and the hold/stand state
  machine. The moved bodies are byte-identical to the previous ones (only the
  `static` on `VCModUpdateSitting` is gone). Public API: `VCModSitting()`,
  `VCModUpdateSitting(CPlayerPed *, CPad *)`, `VCModSitReset()`.
- `src/peds/PlayerPed.cpp` is 457 lines shorter for this slice. Its four direct
  `bVCModSitting` reads (NPC wander gate, street idle yield, spin kick,
  `PlayerControl`) call `VCModSitting()`; `VCModNpcReleasePed` calls
  `VCModSitReset()`; the `ProcessControl` call site is unchanged.
- Two seams stay in `PlayerPed.cpp` until their owners move out:
  `VCModStreetFadePose` (street idle pose) and `VCModRideNotice` (shared HUD
  line) are no longer `static` and are declared in `vcmodsit.cpp`. The sit
  module still reads `bVCModStreetIdle` and `bVCModNpcMode` from
  `vcmodpanel.h` for its start gate and stand rules.
- Harnesses: `test_vc_sit.py` reads the module and compiles its real statics;
  `test_vc_npcmode.py` stubs `VCModSitting()`/`VCModSitReset()` in its extracted
  release path; `test_vc_passenger.py` follows the non-static notice marker;
  `test_vc_diag.py` includes `vcmodsit.cpp` in its unconditional-log sources.

The feature-off path is unchanged: with STREET IDLE off a C press is the stock
crouch, and with NPC mode off no engine sit is adopted.

## Verification

- All 43 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 429). Installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty).
- Both the build tree and the installed binary report `vcmods build 429`.
- The moved sit block matches the previous source except the dropped `static`.
- In game: not yet checked. The sit pass is the one open item: C on a bench
  (hold, then a key stands him up), a wandering NPC-mode civilian taking a seat
  by itself, a toggle-off standing him up, and the two refusal notices.

## Uncommitted

The adrenaline slice from earlier this session is still uncommitted too.

- New: `src/extras/vcmodadrenaline.{cpp,h}`, `src/extras/vcmodsit.{cpp,h}`.
- Modified: `src/peds/PlayerPed.cpp`, `src/extras/vcmodpanel.{cpp,h}`,
  `src/core/re3.cpp`, `src/control/Replay.cpp`, `utils/test_vc_adrenaline.py`,
  `utils/test_vc_character.py`, `utils/test_vc_moveanim.py`,
  `utils/test_vc_sit.py`, `utils/test_vc_npcmode.py`,
  `utils/test_vc_passenger.py`, `utils/test_vc_diag.py`.
- `vc-mods.patch` predates both refactors; regenerate it after the commit.

## Next

1. Play check the sit states above. Then commit both refactors only when asked
   and regenerate `vc-mods.patch`.
2. Extract `vcmodstreet` next: it takes `VCModStreetFadePose` and the idle/chat/
   wander code, which removes one seam and lets `vcmodsit` read an exported
   street predicate instead of the panel flag. Then `vcmodnpc`/`vcmodgang`,
   which also removes the NPC-flag reads from the sit module.
3. After those, the HUD notice dedupe can retire the `VCModRideNotice` seam.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 429 is
> installed. Read `docs/handoff/2026-11-12-sit-extract.md` first. Adrenaline and
> sit now live in `src/extras/vcmodadrenaline.*` and `src/extras/vcmodsit.*`;
> `PlayerPed.cpp` keeps hooks only. All 43 harnesses pass; the in-game sit and
> adrenaline passes are still open. Then extract `vcmodstreet` the same way:
> one module per session, all 43 harnesses, a build, an install only with no
> session running, and a play check. Never commit or push unless asked; game
> data and uchg anim files are read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
