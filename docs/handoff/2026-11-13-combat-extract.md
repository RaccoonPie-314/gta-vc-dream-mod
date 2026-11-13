# Combat extraction (2026-11-13) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 450` (was 448). All 45 harness suites
pass at 450. No commit, tag or push was made.

## What changed

- New `src/extras/vcmodcombat.{cpp,h}` owns the combat feature set:
  - the eight switches `bVCModAimAllWeapons`, `bVCModPlayerDoomAim`,
    `bVCModNoScopedAim`, `bVCModNeverWanted`, `bVCModCopPistol`,
    `nVCModCopHoldFrame`, `bVCModWeaponRecovery`, `bVCModAimWalk`, moved out of
    `vcmodpanel.cpp`;
  - the two-hand colt block (`VCModCopTwoHandPose`, `VCModCopFireAnim`,
    `VCModCopAimAnim`, `VCModCopSetStance`, `bVCModCopRecovering`,
    `VCModCopRecoverCut`, `VCModCopTwoHandFiring`, `VCModCopRecoveringTail`);
  - the gun recovery (`bVCModWeaponRecovering`, `VCModWeaponRecovering`,
    `VCModWeaponRecoveryWanted`, `VCModAimTailRunning`);
  - AIM RAISE (`bVCModAimRaising`, `VCModAimRaiseStart/Stop/Raising`,
    `VCModAimPoseRaised`), `VCModCopStanceAim`, `VCModAimHoldMoving`,
    `VCModAimWalkWeapon`;
  - the aim/recovery state machine pulled out of `CPed::PointGunAt` as
    `VCModCombatAimTick` (returns true when PointGunAt must return early);
  - the shot-end arming (`VCModCombatArmRecovery`), the new-burst rewind
    (`VCModCombatNewBurst`) and the leaving-aim reset (`VCModCombatClearTails`);
  - the forced fight move (`VCModCombatRequestFightMove/TakeFightMove/
    ClearFightMove`) that was `VCModForcedFightMove` in `PedFight.cpp`;
  - `VCModSpinKick`, moved out of `PlayerPed.cpp` with its notice, its street
    pose/chat hand-off and the `FIGHTMOVE_ROUNDHOUSE` request;
  - the never-wanted clamp (`VCModNeverWantedClamp`) from `PlayerPed.cpp`;
  - the NPC combat profile (`VCModNpcCombatOwnsControl`,
    `VCModNpcCombatControl`) from the `ProcessControl` switch.
- Engine files keep hook calls only:
  - `PedFight.cpp` (4,592 → 4,307 lines, 31 mod lines): `SetPointGunAt`,
    `PointGunAt`, `ClearPointGunAt`, `SetAttack`, `Attack` keep only the module
    calls; `StartFightAttack`, `ChooseAttackPlayer` and `EndFight` use the forced
    move seams.
  - `PlayerPed.cpp` (2,686 → 2,605 lines): the KICK key calls
    `VCModSpinKick(this)`, `m_pWanted->Update()` is followed by
    `VCModNeverWantedClamp(this)`, and the ownership bool is
    `VCModNpcCombatOwnsControl(this)` with
    `VCModNpcCombatControl(this, npcCombatOwnsControl)` in the case block.
  - Headers: `Weapon.cpp`, `Wanted.cpp`, `PedIK.cpp`, `Ped.cpp` and
    `vcmodchase.cpp` now include `vcmodcombat.h`; `re3.cpp` adds it beside the
    panel include. `vcmodpanel.h` drops every combat declaration.
- The panel stays a consumer: `vcmodpanel.cpp` keeps the eight rows, the
  debug-menu tweaks and `aVCModSwitched` entries, all pointing at the module's
  externs through `vcmodcombat.h`. No row was added, removed or reordered.
- New harness `utils/test_vc_combat.py`: the forced-move slot, the never-wanted
  clamp (level, queued crime, suspended level, row off), the spin-kick gates
  (fists, gun notice, run, mid-fight, dead/driving/seated) and wiring checks that
  the engine keeps no combat state.

Sizes: `PedFight.cpp` 4,307; `PlayerPed.cpp` 2,605; `vcmodpanel.cpp` 1,731;
`vcmodpanel.h` 28; `vcmodcombat.cpp` 477; `vcmodcombat.h` 101.

## Seams that stay, on purpose

- `VCModCombatAimTick` carries a three-way early return. It replaces the old
  `if (IsPlayer())` block verbatim; `return true` is the old `return`, so the
  stock parking below is skipped exactly when it used to be.
- `VCModCombatArmRecovery` returns "the tail owns the clip" instead of exposing
  the two state flags; the engine parks on the loop end only when it returns
  false, which is the old `else` branch.
- The forced-move slot crosses the seam as `int32`, so `vcmodcombat.h` does not
  pull `Ped.h` into the panel. `ChooseAttackPlayer` takes the slot before the
  check; taking an empty slot is a no-op and keeps the old one-shot semantics.
- `VCModCopRecoveringTail` exists so `SetPointGunAt` can pass the old
  `bVCModCopRecovering` value without the engine reading module state.
- The `ProcessPlayerWeapon` aim-control branches (doom-aim accuracy, scope
  skip, AIM RAISE trigger gate) stay in `PlayerPed.cpp`; they are gated reads of
  combat predicates, not combat state.

Ordering: unchanged. The body-ownership chain, the five sprint-speed writes and
both 17-entry anim tables are untouched by this slice.

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

**`CPlayerPed::ProcessControl` — `PlayerPed.cpp` 1868–2300.**

| Line | Call | Why the position matters |
| --- | --- | --- |
| 1870 | `VCModUpdateAdrenaline` | time scale before anything reads it |
| 1871 | `VCModReconcilePedModel` | model request cleanup before a new body |
| 1872 | `VCModApplyPedModelDefault` | pending ini body applied before ride/anim |
| 1873 | `VCModUpdateRide` | ride owns the body before sit/street/npc |
| 1917 | `VCModPanelShowing` gate | panel up → no player input |
| 1927 | `VCModUpdateSitting` | body-ownership priority: sit |
| 1928 | `VCModUpdateStreetIdle` | then street |
| 1929 | `VCModUpdateNpcMode` | then npc |
| 1941–1948 | keys: Fire, Walk, Kick, Passenger | after the mode updates, capture-checked |
| 1945 | `VCModSpinKick` | combat module hook on the KICK key |
| 1950 | `VCModLockOnLatchTick` | inside the same on-foot block, after the keys |
| 1953 | `VCModNeverWantedClamp` | right after `m_pWanted->Update()` |
| 2026 | wander objective gate | |
| 2045 | `VCModSitting` gate | |
| 2052 | `VCModNpcCombatOwnsControl` | combat module owns the ownership decision |
| 2088 | `VCModNpcCombatControl` | in the combat case block |
| 2120 | `VCModNpcStrollGait` | |
| 2269–2270 | `VCModStreetKeepChat` | after the frame's control code |
| 2271 | gang objective follow | |

**Animation path (outside `ProcessControl`).** `ProcessAnimGroups` (1302) calls
`VCModPlayerAnimGroup(this, strafing, &want)` at 1316 and keeps the two
`!VCModPlayerTurnsWithInput()` gates at 1313 and 1327. `SetRealMoveAnim` calls
`VCModWalkModeOn()` in the start-fade condition at 453 and
`VCModCharacterMoveTempo` at 645, after the four engine sprint-speed writes.

**Lock-on scans.** `FindNextWeaponLockOnTarget` calls `VCModLockOnVehiclesNext`
at 1237; `FindWeaponLockOnTarget` calls `VCModLockOnVehiclesFirst` at 1289.
`ProcessPlayerWeapon` reads `VCModMouseLockOn()` at 1598, 1600 and 1653.
`PlayerControl1stPersonRunAround` caps at 1016; `PlayerControlZelda` caps at 1761.

**Camera and velocity.** `Cam.cpp` 1537 and `Ped.cpp` 2115 read
`VCModPlayerTurnsWithInput()`.

**`PedFight.cpp` combat hooks.** `SetPointGunAt` 185/199; `PointGunAt` 213/225
(tick) and 242 (raise the weapon when standing); `ClearPointGunAt` 256/262;
`SetAttack` 439/442/452; `Attack` 745 (fire clip), 842–844 (stance on a new
clip), 877 (new burst), 1081 (arm recovery), 1092 (free-cam arm recovery);
`StartFightAttack` 1127/1165/1167; `ChooseAttackPlayer` 1776; `EndFight` 2023.

**`CAutomobile` — `Automobile.cpp`.** `ProcessControl` (274):
`VCModTrafficUpdate` 281 (first) → crew brake gate 507 → keep-wheel-angle
539/578 → rotor blades 1431. `PreRender`: fire-truck cannon 1773, FBI lights
2118/2140. `Render`: light textures 3044. `ProcessControlInputs`: steering wheel
3308. `FireTruckControl`/`TankControl`: cannon 3324/3337/3374. `VehicleDamage`:
wheel loss 4350. `PlayCarHorn`: crew 5182. **`CBike`**: traffic 221, light
textures 1745.

## Verification

- All 45 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 450); installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, checked immediately
  before install). The installed binary reports `vcmods build 450` and is
  ad-hoc signed.
- Harness changes: `test_vc_aimwalk.py`, `test_vc_cop_pistol.py`,
  `test_vc_weapon_recovery.py` and `test_vc_windup.py` read the moved
  definitions from `vcmodcombat.cpp` and keep their wiring checks on the engine
  call sites; `test_vc_ganggaze.py` compiles `VCModNpcCombatOwnsControl` and
  `VCModNpcCombatControl` from the module in place of the old inline block (and
  stubs `VCModCombatClearTails` for `ClearPointGunAt`); `test_vc_diag.py` scans
  the module for the spin-kick log; `test_vc_adrenaline.py` and
  `test_vc_character.py` add the combat flag definitions to their compiled panel;
  `test_vc_combat.py` is new.
- In game: not yet checked. Open passes: the character pass, the ride pass, the
  build 444 gang pass, the build 443 NPC/cop passes, the build 448 player pass,
  and this combat pass (two-hand colt hold and tail, gun recovery on/off,
  AIM WALK on/off, AIM RAISE entry, free-aim lock-on, never-wanted on/off, spin
  kick with fists and with a gun, NPC combat profiles).

The feature-off path is unchanged: every hook checks its switch first, and the
moved blocks are verbatim apart from `this` → parameter and the early-return
result.

## Uncommitted

Nine refactor slices (adrenaline, sit, street, NPC, gang, ride, character,
player, combat) plus the cop fixes are all uncommitted; every refactor is a
behaviour-neutral move. `vc-mods.patch` predates them.

- New: `src/extras/vcmod{adrenaline,sit,street,npc,gang,ride,character,player,combat}.{cpp,h}`,
  `utils/test_vc_{player,combat}.py`.
- This slice modified: `src/peds/PedFight.cpp`, `src/peds/PlayerPed.cpp`,
  `src/peds/Ped.cpp`, `src/peds/PedIK.cpp`, `src/core/re3.cpp`,
  `src/core/Wanted.cpp`, `src/weapons/Weapon.cpp`,
  `src/extras/vcmodchase.cpp`, `src/extras/vcmodpanel.{cpp,h}`, and
  `utils/test_vc_{combat,aimwalk,cop_pistol,weapon_recovery,windup,ganggaze,diag,adrenaline,character}.py`.
- Docs updated: `docs/architecture.md` (debt sizes, PlayerPed landmine).

## Next

1. Play check when the player can test: this combat pass, then the still open
   character, ride, gang, NPC/cop and player passes. One feature per session,
   flag on and off. Then commit the nine refactors (and the cop fixes) only when
   asked and regenerate `vc-mods.patch`.
2. Split `vcmodchase.cpp` (3,611) by sub-concern: state machine / squad / air.
3. Split `vcmodpanel.cpp` (1,731) by sub-concern: registry / catalogs / drawing.
4. Known debt kept out of this slice: the `ProcessPlayerWeapon` aim-control
   branches and the five `bVCModNeverWanted` gates in `Wanted.cpp` (one helper
   still owed).

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install. `~/Games/VC/reVC.log` is empty (`0` bytes) at the
end of this session, so the next test starts from a fresh log.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 450 is installed.
> Read `docs/handoff/2026-11-13-combat-extract.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Nine behaviour-neutral slices
> (adrenaline, sit, street, NPC, gang, ride, character, player, combat) are
> uncommitted; the character, ride, gang, NPC/cop, player and combat play checks
> are still open.
> `vcmodcombat` owns the combat switches, the two-hand colt, gun recovery,
> AIM RAISE, the aim/recovery tick in `CPed::PointGunAt`, the forced fight move,
> `VCModSpinKick`, the never-wanted clamp and the NPC combat profile; the panel
> keeps only rows pointing at those switches and `PedFight.cpp` keeps hook calls
> only. All 45 harnesses pass.
>
> Work directly in this session: one module per session, done in place. Next are
> the `vcmodchase.cpp` split (state machine / squad / air) and the
> `vcmodpanel.cpp` split (registry / catalogs / drawing), then the
> `ProcessPlayerWeapon` aim-control extraction and the single never-wanted helper
> in `Wanted.cpp` if they are wanted first.
>
> Keep every move behaviour-neutral and verbatim: same statements, order,
> comments and log strings; feature-off byte-identical to stock; no existing hook
> signature changed; engine files keep hook calls only. Preserve the update order
> in `CPlayerPed::ProcessControl` — adrenaline 1870 → reconcile 1871 →
> apply-default 1872 → ride 1873 → sit 1927 → street 1928 → npc 1929 → keys/latch
> 1941–1950 → never-wanted 1953 — the animation-path hooks
> (`VCModPlayerAnimGroup` 1316, `VCModCharacterMoveTempo` 645, last of the five
> sprint-speed writes), and the no-strafe gates at `PlayerPed.cpp` 1313/1327,
> `Cam.cpp` 1537, `Ped.cpp` 2115.
>
> Per feature: run all `utils/test_vc_*.py` suites, `scripts/build.sh`, then
> `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty,
> and confirm the installed binary reports the new build number BEFORE handing
> off for the player's live test — never hand off an uncompiled tree. In-game
> verify on and off is the player's turn. Clear `~/Games/VC/reVC.log` before each
> test, and read only fresh, filtered, capped slices. Update the debt sizes in
> `docs/architecture.md`, write the handoff and a paste-ready prompt at the end.
> Never commit or push unless asked; game data and uchg anim files are read-only.
