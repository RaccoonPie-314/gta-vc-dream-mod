# Player extraction (2026-11-13) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 448` (was 447). All 44 harness suites
pass at 448. No commit, tag or push was made.

## What changed

- `src/extras/vcmodplayer.{cpp,h}` now own walk mode, no-strafe and lock-on:
  - the five switches `bVCModWalkMode`, `bVCModNoStrafe`, `bVCModLockOnVehicles`,
    `bVCModLockOnLatch`, `bVCModMouseAimLockOn`, moved out of `vcmodpanel.cpp`;
  - `VCModPlayerTurnsWithInput` and its comment, moved verbatim out of
    `vcmodpanel.cpp`;
  - the aim-latch state `bVCModLockOnHeld` and the release call, moved out of
    `PlayerPed.cpp` as `VCModPlayerReleaseAim` (the old
    `VCModPassengerReleaseAim` name is gone);
  - the walk-speed cap (`VCModWalkModeCap`), the walk key toggle
    (`VCModPlayerToggleWalkMode`), the latch tick (`VCModLockOnLatchTick`), the
    mouse lock-on getter (`VCModMouseLockOn`) and the two vehicle lock-on scans
    (`VCModLockOnVehiclesNext`, `VCModLockOnVehiclesFirst`).
- Engine files keep hook calls only:
  - `PlayerPed.cpp` calls `VCModWalkModeOn()` in the start-fade condition,
    `VCModWalkModeCap(this)` at both control paths, `VCModPlayerToggleWalkMode()`
    on the walk key, `VCModLockOnLatchTick(this, padUsed)` in the on-foot key
    block, `VCModLockOnVehiclesNext/First` in the two lock-on searches, and
    `VCModMouseLockOn()` at the three free-aim checks.
  - `Cam.cpp` and `Ped.cpp` keep `VCModPlayerTurnsWithInput()`; their changes
    are include-only.
- `vcmodride.cpp` includes `vcmodplayer.h` and calls `VCModPlayerReleaseAim()`.
  The forward declaration of the old seam is gone, and the board comment that
  named the seam now reads as the destination catalog only.
- `re3.cpp` keeps the `WalkMode`, `NoStrafe`, `LockOnVehicles`, `LockOnLatch` and
  `MouseAimLockOn` ini reads at their original positions; the change is
  include-only.
- The panel stays a consumer. Its five rows and debug-menu entries still point at
  the same variables through the module header, and no row was added, removed or
  reordered. `aVCModSwitched` still leaves out WALK MODE and NO STRAFE.
- New harness `utils/test_vc_player.py`: walk cap off/on, the toggle and
  predicate, the latch (arm, re-arm, lost target, boarding release, row off),
  the mouse lock-on getter, the no-strafe heading rules, plus wiring checks that
  the engine keeps hooks and the panel keeps no copies.

Sizes: `PlayerPed.cpp` 2,726 → 2,686 lines; `vcmodpanel.cpp` 1,766 → 1,745;
`vcmodpanel.h` 83 → 71. `vcmodplayer.cpp` is 114 lines.

## Seams that stay, on purpose

- `VCModSpinKick` stays in `PlayerPed.cpp`. It is a melee command on the fight
  path, so it moves with `vcmodcombat`.
- The aim/recovery block and its predicates (`VCModAimWalkWeapon`,
  `VCModAimHoldMoving`, `VCModAimTailRunning`, `VCModAimRaise*`) stay in
  `PedFight.cpp`; `bVCModAimWalk` and `bVCModNoScopedAim` stay in the panel until
  that extraction.
- The never-wanted clamp and the NPC combat profile block still live in
  `PlayerPed.cpp`; they are not player-locomotion concerns.

`PlayerPed.cpp` is **not** engine-only yet: the aim/recovery path, never-wanted
and the NPC-profile block belong to `vcmodcombat`.

## Ordering

The body-ownership chain is unchanged and was verified line by line after the
move. `VCModCharacterMoveTempo` still lands after the four engine sprint-speed
writes and owns the fifth and last, so the fixed-camera sprint exception still
wins. Both anim tables are still 17 entries and the debug-menu `VCMOD_ROW(0..16)`
labels still line up with them.

### Post-extraction line map

Re-check before relying on it; any edit above a site shifts it.

**Startup — `re3.cpp` `LoadINISettings()` (564).** VC Mods flag reads 667–723 in
listed order (`NpcAnims` 667, `AnimChoice` 668, `MouseAimLockOn` 669, `WalkMode`
673, `NoStrafe` 674, `LockOnVehicles` 675, `LockOnLatch` 677, `PedModel` 695) →
key reads 725–735 → `VCModKeySanitize()` 736 → clamps. Clamps follow their reads:
`Adrenaline` 679, `NpcType` 699, `RideStyle` 738. The legacy `AdrenalineSlowMo`
migration sits at 684–689. Save: `SaveINISettings()` (751) →
`VCModPersistPinned()` 841.

**`CGame::Process` — `Game.cpp`, after `CWorld::Process` (940).**
`VCModChaseUpdate` 943 → `VCModCrewUpdate` 944 → `VCModSpawnTick` 945 →
`VCModCarFirstPersonTick` 946.

**`CPlayerPed::ProcessControl` — `PlayerPed.cpp` 1894–2389.**

| Line | Call | Why the position matters |
| --- | --- | --- |
| 1896 | `VCModUpdateAdrenaline` | time scale before anything reads it |
| 1897 | `VCModReconcilePedModel` | model request cleanup before a new body |
| 1898 | `VCModApplyPedModelDefault` | pending ini body applied before ride/anim |
| 1899 | `VCModUpdateRide` | ride owns the body before sit/street/npc |
| 1943 | `VCModPanelShowing` gate | panel up → no player input |
| 1953 | `VCModUpdateSitting` | body-ownership priority: sit |
| 1954 | `VCModUpdateStreetIdle` | then street |
| 1955 | `VCModUpdateNpcMode` | then npc |
| 1967–1974 | keys: Fire, Walk, Kick, Passenger | after the mode updates, capture-checked |
| 1976 | `VCModLockOnLatchTick` | inside the same on-foot block, after the keys |
| 1980 | never-wanted clamp | |
| 2054 | wander objective gate | |
| 2073 | `VCModSitting` gate | |
| 2080 | npc combat profile (gang/cop/civilian) | |
| 2201 | `VCModNpcStrollGait` | |
| 2350–2351 | `VCModStreetKeepChat` | after the frame's control code |
| 2352 | gang objective follow | |

**Animation path (outside `ProcessControl`).** `ProcessAnimGroups` (1328) calls
`VCModPlayerAnimGroup(this, strafing, &want)` at 1342 and keeps the two
`!VCModPlayerTurnsWithInput()` gates at 1339 and 1353. `SetRealMoveAnim` (380)
calls `VCModWalkModeOn()` in the start-fade condition at 479 and
`VCModCharacterMoveTempo` at 671, after the four engine sprint-speed writes.

**Lock-on scans.** `FindNextWeaponLockOnTarget` calls `VCModLockOnVehiclesNext`
at 1263; `FindWeaponLockOnTarget` calls `VCModLockOnVehiclesFirst` at 1315.
`ProcessPlayerWeapon` reads `VCModMouseLockOn()` at 1624, 1626 and 1679.
`PlayerControl1stPersonRunAround` caps at 1042; `PlayerControlZelda` caps at
1787.

**Camera and velocity.** `Cam.cpp` 1537 and `Ped.cpp` 2115 read
`VCModPlayerTurnsWithInput()`.

**`CAutomobile` — `Automobile.cpp`.** `ProcessControl` (274):
`VCModTrafficUpdate` 281 (first) → crew brake gate 507 → keep-wheel-angle
539/578 → rotor blades 1431. `PreRender`: fire-truck cannon 1773, FBI lights
2118/2140. `Render`: light textures 3044. `ProcessControlInputs`: steering wheel
3308. `FireTruckControl`/`TankControl`: cannon 3324/3337/3374. `VehicleDamage`:
wheel loss 4350. `PlayCarHorn`: crew 5182. **`CBike`**: traffic 221, light
textures 1745.

## Verification

- All 44 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 448); installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, checked immediately
  before install). The installed binary reports `vcmods build 448`.
- Harness changes: `test_vc_moveanim.py` extracts the real `VCModWalkModeOn` from
  the module and checks NO STRAFE's flag lives in the module, not the panel;
  `test_vc_passenger.py` extracts `VCModPlayerReleaseAim` from the module and
  asserts the engine keeps the latch tick but no latch state;
  `test_vc_character.py` and `test_vc_adrenaline.py` add the player-module flags
  to their compiled panels; `test_vc_player.py` is new.
- In game: not yet checked. Open passes: the character pass, the ride pass, the
  build 444 gang pass, the build 443 NPC/cop passes, and this player pass (walk
  mode on/off at both control paths and the fade, no strafe, lock-on latch on and
  off, free-aim lock-on, lock-on vehicles, boarding a car with a latched aim).

The feature-off path is unchanged: every new hook checks its switch first (walk
cap, latch, mouse lock-on, vehicle scans), the toggle only writes the switch, and
the no-strafe predicate returns false with its flag off.

## Uncommitted

Eight refactor slices (adrenaline, sit, street, NPC, gang, ride, character,
player) plus the cop fixes are all uncommitted; every refactor is a
behaviour-neutral move. `vc-mods.patch` predates them.

- New: `src/extras/vcmod{adrenaline,sit,street,npc,gang,ride,character,player}.{cpp,h}`,
  `utils/test_vc_player.py`.
- This slice modified: `src/peds/PlayerPed.cpp`, `src/peds/Ped.cpp`,
  `src/core/Cam.cpp`, `src/core/re3.cpp`, `src/extras/vcmodpanel.{cpp,h}`,
  `src/extras/vcmodride.cpp`, `utils/test_vc_{player,moveanim,passenger,character,adrenaline}.py`.
- Docs updated: `docs/architecture.md` (debt sizes).

## Next

1. Play check when the player can test: this player pass first, then the still
   open character, ride, gang and NPC/cop passes. One feature per session, flag
   on and off. Then commit the eight refactors (and the cop fixes) only when
   asked and regenerate `vc-mods.patch`.
2. Extract `vcmodcombat` — `PedFight.cpp` (aim/recovery block and its predicates,
   `bVCModAimWalk`, `bVCModNoScopedAim`, `VCModSpinKick`) plus the never-wanted
   clamp and the NPC combat profile block from `PlayerPed.cpp`.
3. Then the splits: `vcmodchase.cpp` and `vcmodpanel.cpp`.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install. `~/Games/VC/reVC.log` is empty (`0` bytes) at the
end of this session, so the next test starts from a fresh log.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 448 is installed.
> Read `docs/handoff/2026-11-13-player-extract.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Eight behaviour-neutral slices
> (adrenaline, sit, street, NPC, gang, ride, character, player) are uncommitted;
> the character, ride, gang, NPC/cop and player play checks are still open.
> `vcmodplayer` owns walk mode, no-strafe and lock-on: the five switches, the
> turn-with-input predicate, the aim latch (`VCModPlayerReleaseAim`, which
> replaces the old `VCModPassengerReleaseAim` seam), the walk cap and the two
> vehicle lock-on scans; the panel keeps only rows pointing at those switches.
> `VCModSpinKick`, the aim/recovery block in `PedFight.cpp`, never-wanted and the
> NPC combat profile still live in their engine files for the combat slice; all
> four harnesses that touch the player flags pass, 44 in total.
>
> Work directly in this session: one module per session, done in place. Next is
> `vcmodcombat` (`PedFight.cpp`, the aim/recovery block and its predicates,
> `bVCModAimWalk`, `bVCModNoScopedAim`, `VCModSpinKick`, the never-wanted clamp
> and the NPC combat profile block), then the `vcmodchase.cpp` and
> `vcmodpanel.cpp` splits.
>
> Keep every move behaviour-neutral and verbatim: same statements, order,
> comments and log strings; feature-off byte-identical to stock; no existing hook
> signature changed; engine files keep hook calls only. Preserve the update order
> in `CPlayerPed::ProcessControl` — adrenaline 1896 → reconcile 1897 →
> apply-default 1898 → ride 1899 → sit 1953 → street 1954 → npc 1955 → keys/latch
> 1967–1976 — the two animation-path hooks (`VCModPlayerAnimGroup` at 1342,
> `VCModCharacterMoveTempo` at 671, last of the five sprint-speed writes), and
> the no-strafe gates at `PlayerPed.cpp` 1339/1353, `Cam.cpp` 1537, `Ped.cpp`
> 2115.
>
> Per feature: run all 44 `utils/test_vc_*.py` suites, `scripts/build.sh`, then
> `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty,
> and confirm the installed binary reports the new build number BEFORE handing
> off for the player's live test — never hand off an uncompiled tree. In-game
> verify on and off is the player's turn. Clear `~/Games/VC/reVC.log` before each
> test, and read only fresh, filtered, capped slices. Update the debt sizes in
> `docs/architecture.md`, write the handoff and a paste-ready prompt at the end.
> Never commit or push unless asked; game data and uchg anim files are read-only.
