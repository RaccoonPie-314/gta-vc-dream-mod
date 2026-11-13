# Gang extraction (2026-11-12) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 444` (was 443). All 43 harness suites
pass at 444. No commit, tag or push was made.

## What changed

- `src/extras/vcmodgang.{cpp,h}` now own the gang-profile faction identity and
  reaction overrides. `VCModGangEffectiveType` moved out of the panel verbatim
  (gang-profile Tommy reads as `PEDTYPE_GANG7`, every other ped reports his own
  type). The reaction blocks moved out of `PedAI.cpp` as hook calls:
  - `VCModGangRefuseFleeObjective` — the fearless flee-objective refusal in
    `SetObjective` (the comment stays at the hook).
  - `VCModGangNoteObjective` — the throttled objective probe (its static counter
    is function-local, as it was in the engine).
  - `VCModGangInterruptKillPose` — the after-kill pose interruption on a fresh
    kill objective in `SetObjective`.
  - `VCModGangNoteReact` — the throttled reaction probe at the top of
    `ReactToAttack` (function-local static).
  - `VCModGangFightBack` — the fearless fight-back (register threat, kill
    objective, no expiry); returns true so the engine returns.
  - `VCModGangReactDiag` — the three stock-branch reaction probes, now one
    helper taking the decision string.
- `src/peds/PedAI.cpp` keeps the hook calls and the stock decision branches
  (including the strong-civilian exception line). `src/peds/Ped.cpp` and
  `src/weapons/Weapon.cpp` keep their `VCModGangEffectiveType` predicate calls
  and now include `vcmodgang.h`. `PedFight.cpp` is unchanged (its only gang
  reference is the `VCModNpcGangActive` predicate, already in `vcmodnpc.h`).
- `vcmodpanel.{cpp,h}` no longer define or declare `VCModGangEffectiveType`.
- The moved bodies are behaviour-identical; the probes keep their exact strings
  and throttle gaps. The standalone `VCMOD gang pose:` (ProcessCivilianState),
  `VCMOD gang gaze:` (PlayerPed ProcessControl) and `VCMOD threat:`
  (ScanForThreats) probes stay with their engine functions — they are NPC-combat
  / gang-ped instrumentation for a later extraction, not gang reaction logic.
- Harnesses: `test_vc_gangfaction.py` reads `vcmodgang.cpp` for the effective
  type and the three `SetObjective` helpers (a new `obj_source()`);
  `test_vc_diag.py` adds `vcmodgang.cpp` to its log sources. Row count stays 57.

The feature-off path is unchanged: with NPC mode off every gang hook is a no-op
or returns false, `VCModGangEffectiveType` returns the ped's own type, and the
stock flee/fight branches run exactly as before.

## Verification

- All 43 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 444); installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, checked immediately
  before install). The installed binary reports `vcmods build 444`.
- In game: not yet checked (the player has not been able to test). Open passes:
  the build 443 NPC profiles and cop after-kill pose / off-path walking fix, plus
  the gang reaction (fight-back instead of flee, flee-objective refusal, GANG7
  kin spare him / rivals hunt him, the after-kill pose interruption).

## Uncommitted

The five refactor slices (adrenaline, sit, street, NPC, gang) plus the cop fixes
are all uncommitted; every refactor is a behaviour-neutral move.
`vc-mods.patch` predates them.

- New: `src/extras/vcmod{adrenaline,sit,street,npc,gang}.{cpp,h}`.
- This slice modified: `src/peds/{Ped,PedAI}.cpp`, `src/weapons/Weapon.cpp`,
  `src/extras/vcmodpanel.{cpp,h}`, `utils/test_vc_gangfaction.py`,
  `utils/test_vc_diag.py`.

## Next

1. Play check when the player can test: the gang reaction and faction passes
   above, plus the still-open build 443 NPC/cop passes. Then commit the five
   refactors (and the cop fixes) only when asked and regenerate `vc-mods.patch`.
2. Extract `vcmodride` and `vcmodcharacter` next — the remaining `PlayerPed.cpp`
   extractions; after those `PlayerPed.cpp` is engine-only. The HUD notice dedupe
   retires the `VCModRideNotice` seam. The gang pose/gaze/threat probes move with
   the NPC-combat extraction.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 444 is
> installed. Read `docs/handoff/2026-11-12-gang-extract.md` first. Adrenaline,
> sit, street, NPC and gang now live in `src/extras/vcmod{adrenaline,sit,street,
> npc,gang}.*`; the engine keeps hook and predicate calls only. `vcmodgang` owns
> `VCModGangEffectiveType` (out of the panel) and the `SetObjective`/
> `ReactToAttack` reaction overrides (flee refusal, fight-back, pose interrupt,
> probes). The gang pose/gaze/threat probes stay in the engine for the NPC-combat
> extraction. All 43 harnesses pass; the in-game gang reaction/faction pass and
> the build 443 NPC/cop passes are still open (the player has not tested). Clear
> `~/Games/VC/reVC.log` before each test (only with no session running) and read
> only fresh, filtered, capped slices. Then extract `vcmodride` the same way: one
> module per session, all 43 harnesses, a build, an install only with no session
> running, and a play check. Never commit or push unless asked; game data and uchg
> anim files are read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before
> any install.