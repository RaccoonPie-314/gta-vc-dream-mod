# NPC extraction (2026-11-12) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The refactor verified at `vcmods build 433`; the installed build is now
`vcmods build 443` because the cop ID-check / after-kill-pose fixes landed on
top (see `2026-11-12-cop-doubleback-fix.md`, the newest handoff). All 43 harness
suites pass at 443. No commit, tag or push was made.

## What changed

- `src/extras/vcmodnpc.{cpp,h}` now own BECOME NPC: `bVCModNpcMode`,
  `nVCModNpcType` and `eVCModNpcType` (moved out of the panel), the stat/gang
  borrow, the stroll easing and its reset, the GANG/CIVILIAN/COP profile
  dispatch, the mode break, the ID-check hold, the toggle-off hand-back and the
  per-frame update. The moved bodies are byte-identical; only
  `VCModNpcStrollGait` and `VCModUpdateNpcMode` lost their `static`. Public
  API: the five profile predicates, `VCModNpcStatsBorrowed()`,
  `VCModUpdateNpcMode()`, `VCModNpcStrollGait()`, `VCModNpcResetStroll()`.
- `src/peds/PlayerPed.cpp` is 460 lines shorter for this slice (3,503 now).
  It keeps the `VCModUpdateNpcMode`/`VCModNpcStrollGait` calls and asks
  `VCModNpcStatsBorrowed()` in the model reconcile; the stat-borrow statics
  are gone from the engine file.
- The `VCModNpcResetStroll` seam is gone: `vcmodstreet.cpp` includes the NPC
  header and calls the real function. `VCModRideNotice` remains the only seam.
- `vcmodpanel.{cpp,h}` no longer define or declare the NPC flags, enum or
  predicates; it includes the NPC header for the row, the debug entries and
  `VCModGangEffectiveType`. `vcmodsit.cpp`, `re3.cpp`, `Ped.cpp`, `PedAI.cpp`,
  `PedChat.cpp`, `PedFight.cpp` and `AudioLogic.cpp` include the NPC header.
- Harnesses: `test_vc_npcmode.py`, `test_vc_npcwalk.py`,
  `test_vc_gangfaction.py`, `test_vc_ganggaze.py` and `test_vc_npcstrong.py`
  read the module; the panel harnesses supply the moved flags in their stubs;
  `test_vc_diag.py` includes the module in its log sources.

The feature-off path is unchanged: with BECOME NPC off no profile code runs,
the player's stats/flags are never borrowed, and the hand-back path only fires
on the toggle edge.

## Verification

- All 43 `utils/test_vc_*.py` suites pass, before and after the install.
- `scripts/build.sh` builds cleanly. The refactor installed at build 433; the
  cop fixes then took the installed build to 443. Installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty).
- The installed binary reports `vcmods build 443`.
- In game: not yet checked (the player has not been able to test). Two open
  passes: the NPC profiles (GANG/CIVILIAN/COP), stat/personality following a
  body change, the toggle-off hand-back and the sit/street interactions; and the
  cop after-kill pose / off-path walking fix from build 443.

## Uncommitted

The adrenaline, sit and street slices from earlier this session are still
uncommitted; all four refactors are behaviour-neutral moves.

- New: `src/extras/vcmodadrenaline.{cpp,h}`, `src/extras/vcmodsit.{cpp,h}`,
  `src/extras/vcmodstreet.{cpp,h}`, `src/extras/vcmodnpc.{cpp,h}`.
- Modified: `src/peds/{PlayerPed,Ped,PedAI,PedChat,PedFight}.cpp`,
  `src/audio/AudioLogic.cpp`, `src/weapons/Weapon.cpp`,
  `src/extras/vcmodpanel.{cpp,h}`, `src/extras/vcmodsit.cpp`,
  `src/extras/vcmodstreet.cpp`, `src/core/re3.cpp`,
  `src/control/Replay.cpp`, and the harnesses `test_vc_adrenaline.py`,
  `test_vc_character.py`, `test_vc_diag.py`, `test_vc_gangfaction.py`,
  `test_vc_ganggaze.py`, `test_vc_moveanim.py`, `test_vc_npcmode.py`,
  `test_vc_npcstrong.py`, `test_vc_npcwalk.py`, `test_vc_passenger.py`,
  `test_vc_sit.py`, `test_vc_wander.py`.
- `vc-mods.patch` predates all four refactors; regenerate after the commit.

## Next

1. Play check when the player can test: the NPC profiles above and the build 443
   cop after-kill pose / off-path walking fix. Then commit the four refactors
   (and the cop fixes) only when asked and regenerate `vc-mods.patch`.
2. Extract `vcmodgang` next: the reaction/gaze/faction overrides in `Ped.cpp`,
   `PedAI.cpp`, `PedFight.cpp` and `VCModGangEffectiveType` out of the panel,
   leaving predicate calls in the engine.
3. Then `vcmodride` and `vcmodcharacter` are the remaining `PlayerPed.cpp`
   extractions; after those `PlayerPed.cpp` is engine-only. The HUD notice
   dedupe retires the `VCModRideNotice` seam.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 443 is
> installed. Read `docs/handoff/2026-11-12-npc-extract.md` and
> `docs/handoff/2026-11-12-cop-doubleback-fix.md` (newest) first. Adrenaline,
> sit, street and NPC now live in `src/extras/vcmod{adrenaline,sit,street,npc}.*`;
> `PlayerPed.cpp` keeps hooks only. The cop fixes on top: NPC-mode players get no
> wander-node poses, the only pose is the 3.5 s after-kill hold for every profile,
> and the combat seek-radius reset is profile-wide; QUICK ID CHECK (5-10 s
> cooldown) is a DEBUG switch and the ID check is confirmed fixed. All 43
> harnesses pass; the in-game NPC and cop pose/wander passes are still open (the
> player has not tested yet). Clear `~/Games/VC/reVC.log` before each test (only
> with no session running) and read only fresh, filtered, capped slices. Then
> extract `vcmodgang` the same way: one module per session, all 43 harnesses, a
> build, an install only with no session running, and a play check. Never commit
> or push unless asked; game data and uchg anim files are read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
