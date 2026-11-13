# Character extraction (2026-11-13) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 447` (was 445). All 43 harness suites
pass at 447. No commit, tag or push was made.

## Workflow — back to handoffs

Extractions run directly in the session that does them: read the newest handoff,
one module per session, move the code, run the whole suite, build, install, hand
off for the player's live test. The separate orchestration protocol and its
document have been removed.

The durable rules are `docs/architecture.md` (code shape) and `AGENTS.md`
(workspace invariants); the stricter one wins. The post-extraction ordering map
is recorded in this handoff, under **Ordering** below.

## What changed

- `src/extras/vcmodcharacter.{cpp,h}` now own the character feature: the ped
  roster (which shelf a ped type sits on, what is on that shelf), the anim-set
  picker and its group table, the model swap and its streaming bookkeeping, and
  the player's locomotion tempo. Twenty symbols moved verbatim out of
  `PlayerPed.cpp` and `vcmodpanel.cpp`; two were added, both required by the move:
  `VCModAnimSetName` (the panel's name accessor) and `VCModCharacterMoveTempo`
  (the tempo hook below).
- The character flags and types moved out of the panel: `bVCModPlayerNpcAnims`,
  `nVCModAnimChoice`, `nVCModPedModel` and `eVCModPedCategory` now live in
  `vcmodcharacter.{cpp,h}`. `vcmodpanel.{cpp,h}` no longer define or declare them.
  The anim-set tables (`aVCModAnimGroupNames`, `aVCModAnimGroups`,
  `aVCModMoveAnims`) and `VCModGroupPlayable` moved with them.
- Three functions lost `static` because the engine calls them:
  `VCModApplyPedModelDefault`, `VCModReconcilePedModel`, `VCModPlayerAnimGroup`.
  `VCModRollPlayerPace` and `VCModApplyPedModel` were already exported.
- The tempo/seed block at the end of `CPlayerPed::SetRealMoveAnim` is now one
  engine call, `VCModCharacterMoveTempo(this, curWalkAssoc, curRunAssoc,
  curSprintAssoc)`, at the exact position the inline block held. Its predicate
  (`!m_bAdrenalineActive && (bVCModPlayerNpcAnims || GetModelIndex() != MI_PLAYER)`)
  stayed inside the hook, so the engine line is a call, not a branch. The
  diagnostic one-shot `nVCModLoggedSeed` is now a module static instead of a
  static inside an engine function.
- `PlayerPed.cpp` keeps the hook calls only: `VCModReconcilePedModel(this)` and
  `VCModApplyPedModelDefault()` in `ProcessControl`, and
  `VCModPlayerAnimGroup(this, strafing, &want)` in `ProcessAnimGroups`.
- The panel stays a consumer. It keeps its own shelf-selection state
  (`nVCModPedCategory`) and display labels (`aVCModPedCategoryNames`), and reaches
  the moved tables through `NUM_VCMOD_ANIM_SETS` (17, a compile-time constant so
  the debug-menu clamp bound is unchanged) and `VCModAnimSetName`. It keeps no
  copy of either table. No row was added, removed or reordered.
- `re3.cpp` keeps the `NpcAnims`, `AnimChoice` and `PedModel` ini reads at their
  original positions; `vcmodchase.cpp` keeps its save/force/restore of
  `bVCModPlayerNpcAnims` and its `VCModApplyPedModel` calls. Both changes are
  include-only.
- No reset entry was added. `VCModReconcilePedModel` is already the hand-back for
  the held streaming request and is already wired at `ProcessControl`; a new
  `VCModCharacterReset()` would have no call site and would be dead code.

Sizes: `PlayerPed.cpp` 2,896 → 2,726 lines; `vcmodpanel.cpp` 1,883 → 1,766;
`vcmodpanel.h` 110 → 83. The god header shrank and does not include the feature
header — consumers include `vcmodcharacter.h` directly.

## Seams that stay, on purpose

- `VCModPassengerReleaseAim` and the lock-on latch `bVCModLockOnHeld` stay in
  `PlayerPed.cpp`; they retire with the walk-mode / lock-on extraction.
- `VCModSpinKick` stays in `PlayerPed.cpp`. It is a melee command on the fight
  path (`StartFightAttack` / `FIGHTMOVE_ROUNDHOUSE`), so it moves with the combat
  extraction, not this one.
- `VCModRideNotice` keeps its name until the HUD notice is deduped into one helper.

`PlayerPed.cpp` is **not** engine-only yet: the walk-mode, no-strafe, lock-on,
aim, never-wanted and NPC-profile blocks still live there and belong to the next
two extractions.

## Ordering

The body-ownership chain is unchanged and was verified line by line after the
move: adrenaline 1929 → reconcile 1930 → apply-default 1931 → ride 1932 → sit
1986 → street 1987 → npc 1988. `VCModPlayerAnimGroup` is still called from
`ProcessAnimGroups` with the same arguments (now 1372). The tempo hook lands
after the four engine sprint-speed writes (658/672/676/678) and owns the fifth
and last, so the fixed-camera sprint exception still wins. Both anim tables are
17 entries and the debug-menu `VCMOD_ROW(0..16)` labels still line up with them.

### Post-extraction line map

This replaces the ordering registry that used to live in the removed
orchestrator doc. Verified against the tree at build 447; re-check before relying
on it, since any edit above a site shifts it.

**Startup — `re3.cpp` `LoadINISettings()` (564).** VC Mods flag reads 667–723 in
listed order (`NpcAnims` 667, `AnimChoice` 668, `PedModel` 695) → key reads
725–735 → `VCModKeySanitize()` 736 → clamps. Clamps follow their reads:
`Adrenaline` 679, `NpcType` 699, `RideStyle` 738. The legacy `AdrenalineSlowMo`
migration sits at 684–689. Save: `SaveINISettings()` (751) →
`VCModPersistPinned()` 841.

**`CGame::Process` — `Game.cpp`, after `CWorld::Process` (940).**
`VCModChaseUpdate` 943 → `VCModCrewUpdate` 944 → `VCModSpawnTick` 945 →
`VCModCarFirstPersonTick` 946.

**`CPlayerPed::ProcessControl` — `PlayerPed.cpp` 1927–2431.**

| Line | Call | Why the position matters |
| --- | --- | --- |
| 1929 | `VCModUpdateAdrenaline` | time scale before anything reads it |
| 1930 | `VCModReconcilePedModel` | model request cleanup before a new body |
| 1931 | `VCModApplyPedModelDefault` | pending ini body applied before ride/anim |
| 1932 | `VCModUpdateRide` | ride owns the body before sit/street/npc |
| 1976 | `VCModPanelShowing` gate | panel up → no player input |
| 1986 | `VCModUpdateSitting` | body-ownership priority: sit |
| 1987 | `VCModUpdateStreetIdle` | then street |
| 1988 | `VCModUpdateNpcMode` | then npc |
| 1992–2007 | keys: Driver, Crew, Fire/Walk/Kick/Passenger | after the mode updates, capture-checked |
| 2011–2015 | lock-on latch | |
| 2020 | never-wanted clamp | |
| 2094 | wander objective gate | |
| 2113 | `VCModSitting` gate | |
| 2120 | npc combat profile (gang/cop/civilian) | |
| 2241 | `VCModNpcStrollGait` | |
| 2389–2390 | `VCModStreetKeepChat` | after the frame's control code |
| 2392 | gang objective follow | |

**Animation path (outside `ProcessControl`).** `ProcessAnimGroups` (1358) calls
`VCModPlayerAnimGroup(this, strafing, &want)` at 1372. `SetRealMoveAnim` (390)
calls `VCModCharacterMoveTempo` at 681, after the four engine sprint-speed writes
(658/672/676/678); the hook owns the fifth and last.

**`CAutomobile` — `Automobile.cpp`.** `ProcessControl` (274):
`VCModTrafficUpdate` 281 (first) → crew brake gate 507 → keep-wheel-angle
539/578 → rotor blades 1431. `PreRender`: fire-truck cannon 1773, FBI lights
2118/2140. `Render`: light textures 3044. `ProcessControlInputs`: steering wheel
3308. `FireTruckControl`/`TankControl`: cannon 3324/3337/3374. `VehicleDamage`:
wheel loss 4350. `PlayCarHorn`: crew 5182. **`CBike`**: traffic 221, light
textures 1745.

## Verification

- All 43 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 447); installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, checked immediately
  before install). The installed binary reports `vcmods build 447`.
- Harness changes: `test_vc_character.py` reads the state and tables from
  `vcmodcharacter.{cpp,h}` and checks that the engine keeps the hooks but not the
  feature state, and that the panel keeps no copy of the tables.
  `test_vc_moveanim.py` and `test_vc_adrenaline.py` now extract
  `VCModCharacterMoveTempo` alongside `SetRealMoveAnim` — the tempo assertions
  still exercise the real code, and `nVCModLoggedSeed` is pulled explicitly
  because it sits outside the hook body. `test_vc_adrenaline.py` also needed its
  `eVCModPedCategory` source and its globals-harvest regex re-pointed, not just
  the table assertion. `test_vc_diag.py` gained `vcmodcharacter.cpp` in its log
  sources (the `VCMOD move:` probe moved).
- In game: not yet checked. Open passes: the character pass (wear another body
  from each shelf, the anim-set picker, the pace/tempo change, back to Tommy),
  plus the still-open ride pass, the build 444 gang pass and the build 443
  NPC/cop passes.

The feature-off path is unchanged: with `NpcAnims` off and Tommy worn, the tempo
hook returns without touching any clip speed, `VCModPlayerAnimGroup` falls
through to the stock per-weapon logic, and the roster and picker are inert.

## Uncommitted

Seven refactor slices (adrenaline, sit, street, NPC, gang, ride, character) plus
the cop fixes are all uncommitted; every refactor is a behaviour-neutral move.
`vc-mods.patch` predates them.

- New: `src/extras/vcmod{adrenaline,sit,street,npc,gang,ride,character}.{cpp,h}`.
- This slice modified: `src/peds/PlayerPed.cpp`, `src/core/re3.cpp`,
  `src/extras/vcmodpanel.{cpp,h}`, `src/extras/vcmodchase.cpp`,
  `utils/test_vc_{character,moveanim,adrenaline,diag}.py`.
- Docs updated: `docs/architecture.md` (debt sizes). The orchestration document
  and its handoff were removed when the workflow went back to handoffs; the
  ordering map they carried is now in this document.

## Next

1. Play check when the player can test: the character pass above, then the still
   open ride, gang and NPC/cop passes. One feature per session, flag on and off.
   Then commit the seven refactors (and the cop fixes) only when asked and
   regenerate `vc-mods.patch`.
2. Extract `vcmodplayer` next — walk mode, no-strafe, lock-on
   (`PlayerPed.cpp` + `Cam.cpp`). It retires the `VCModPassengerReleaseAim` seam.
3. Then `vcmodcombat` — `PedFight.cpp`, the aim/recovery block, `VCModSpinKick`,
   and the gang pose/gaze/threat probes.
4. Then the splits: `vcmodchase.cpp` and `vcmodpanel.cpp`.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install. `~/Games/VC/reVC.log` was already empty at the
end of this session, so the next test starts from a fresh log.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 447 is installed.
> Read `docs/handoff/2026-11-13-character-extract.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Seven behaviour-neutral slices
> (adrenaline, sit, street, NPC, gang, ride, character) are uncommitted; the
> character, ride, gang and NPC/cop play checks are still open. `vcmodcharacter`
> owns the roster, anim-set picker, model swap and the locomotion tempo; the
> panel keeps only its shelf selection and labels and reaches the tables through
> `NUM_VCMOD_ANIM_SETS` and `VCModAnimSetName`. `VCModSpinKick` stays in
> `PlayerPed.cpp` for the combat slice and `VCModPassengerReleaseAim` stays for
> the player slice; `PlayerPed.cpp` is not engine-only yet. All 43 harnesses pass.
>
> Work directly in this session: one module per session, done in place. Next is
> `vcmodplayer` (walk mode, no-strafe, lock-on in `PlayerPed.cpp` + `Cam.cpp`; it
> retires the `VCModPassengerReleaseAim` seam and the `bVCModLockOnHeld` latch),
> then `vcmodcombat` (`PedFight.cpp`, the aim/recovery block, `VCModSpinKick`,
> and the gang pose/gaze/threat probes).
>
> Keep every move behaviour-neutral and verbatim: same statements, order,
> comments and log strings; feature-off byte-identical to stock; no existing hook
> signature changed; engine files keep hook calls only. Preserve the update order
> in `CPlayerPed::ProcessControl` — adrenaline 1929 → reconcile 1930 →
> apply-default 1931 → ride 1932 → sit 1986 → street 1987 → npc 1988 — and the
> two animation-path hooks (`VCModPlayerAnimGroup` at 1372,
> `VCModCharacterMoveTempo` at 681, last of the five sprint-speed writes).
>
> Per feature: run all 43 `utils/test_vc_*.py` suites, `scripts/build.sh`, then
> `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty,
> and confirm the installed binary reports the new build number BEFORE handing
> off for the player's live test — never hand off an uncompiled tree. In-game
> verify on and off is the player's turn. Clear `~/Games/VC/reVC.log` before each
> test, and read only fresh, filtered, capped slices. Update the debt sizes in
> `docs/architecture.md`, write the handoff and a paste-ready prompt at the end.
> Never commit or push unless asked; game data and uchg anim files are read-only.