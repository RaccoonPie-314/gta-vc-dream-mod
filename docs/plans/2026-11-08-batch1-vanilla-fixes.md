# Batch 1 — vanilla fixes implementation plan

Status: five behaviours seen working in play (builds 42/43); item 6 closed as already present;
item 7 dropped; the "master off" revert is the only checklist row not yet exercised
Date: 2026-11-08
Base: reVC `vcmods` @ `d01bb3c`, uncommitted working tree; seven harnesses pass
Scope: the eight unblocked picks in `2026-11-08-vice-extended-picks.md`
Out of scope: Windows build, assets, SCM, Rockstar data edits, first person, autosave

## Goal

Add the small "the original should have done this" behaviours without touching content:
cleaner HUD, wheels that stay where you left them, engine and lights off when you hold
exit, and longer blood and sand particles. One visible switch, four ini keys, no assets.

## What the pack actually offers here

Two of the eight are already in reVC, one has no defined meaning:

- **Open doors can slam** — `CAutomobile::OpenDoor` already plays
  `SOUND_CAR_DOOR_CLOSE_BONNET + door` when a door reaches closed
  (`src/vehicles/Automobile.cpp:4601-4609`). The pack's line likely describes this same
  sound. Verify in-game; expect no change.
- **Bike fire/smoke beside it** — `CBike` already emits `PARTICLE_CARFLAME`,
  `ENGINE_SMOKE2` and `CARFLAME_SMOKE` at `CAR_POS_BACKSEAT` minus 0.3 z
  (`src/vehicles/Bike.cpp:1105-1136`). Verify; expect no change.
- **Mirror mode by default** — the pack only exposes a debug-menu entry
  ("Toggle mirror mode"); no gameplay meaning established. Deferred until defined.

So Batch 1 is five changes plus two verification tasks.

## Values and provenance

The pack has no source, so these are reimplemented here. What each one rests on:

| Behaviour | Pack evidence | Our value / implementation | Parity |
|---|---|---|---|
| Money without leading zeros | `ChangesEN:107`, `features.ini` `RemoveMoneyZerosInTheHud` | `"$%d"` | exact (format is unambiguous) |
| Empty stars hidden | `ChangesEN:106`, `features.ini` `WantedStarsHideOnScreenWhenThereIsNoSearch` | hide the dim row only when level and pending are both 0 | exact (rule is binary) |
| Wheel angle kept | `ChangesEN:141` | skip the `m_fSteerAngle = 0` reset | exact (one branch) |
| Engine/lights on exit hold | `ChangesEN:119` | 400 ms after a fresh press, driver only | **ours**, untested against the pack |
| Longer blood/sand | `ChangesEN:185` | ×2 after the config load | **ours**: the pack's `particle.cfg` matches stock, so its factor is in `ViceEx.exe` |

The two "ours" values are listed again under "Unverified constants" in
`2026-11-08-vice-extended-picks.md`. Extract them from `ViceEx.exe` only if the feel is wrong in
play; otherwise tune by playing.

## Control surface

One new panel row, `VANILLA FIXES`, default on. It gates all four behaviours. Fine control
stays in the ini so a rebuild is not needed:

```ini
[VC Mods]
VanillaFixes = 1
HudCleanup = 1
KeepWheelAngle = 1
ExitHoldOff = 1
LongerFx = 1
```

Append the row after `PATH LANE` (`src/extras/vcmodpanel.cpp:506`) so no existing row index
moves. The panel does not scroll (`VCModRowY` at `src/extras/vcmodpanel.cpp:594`); one extra
row adds 14 logical pixels and keeps the 720p layout intact.

## New module

`src/extras/vcmodqol.h` / `.cpp`:

- Flags: `bVCModVanillaFixes`, `bVCModHudCleanup`, `bVCModKeepWheelAngle`,
  `bVCModExitHoldOff`, `bVCModLongerFx`.
- Pure helpers for the harness:
  - `void VCModFormatMoney(char *out, size_t size, int32 money)`
  - `bool VCModWantedSlotVisible(int32 level, int32 minLevel, int32 slot)`
  - `bool VCModExitHoldElapsed(uint32 now, uint32 since, uint32 threshold)`
- `void VCModApplyParticleLifetimes(void)`, called from `CParticle::ReloadConfig`
  (`src/renderer/Particle.cpp:248`) after `mod_ParticleSystemManager.Initialise()`.

Wire the flags through `TWEAKBOOLN` in the panel, `aVCModSwitched`, the ini reads in
`src/core/re3.cpp` `LoadINISettings`, and the panel row table.

## Tasks

### 1. HUD money without leading zeros

- File: `src/renderer/Hud.cpp:423`.
- Change: `sprintf(sTemp, "$%08d", ...)` → `VCModFormatMoney(sTemp, sizeof(sTemp), ...)`
  when `bVCModVanillaFixes && bVCModHudCleanup`, otherwise keep the stock format.
- Test: harness formats `0 → "$0"`, `42 → "$42"`, `1234567 → "$1234567"`, negative input
  unchanged in magnitude.
- In-game: new game shows `$0`; picking up cash shows `$1234`, not `$00001234`.

### 2. Hide empty wanted stars

- File: `src/renderer/Hud.cpp:659` (the `GetWantedLevel() <= i` branch).
- Change: skip that branch when the helper says the slot is not visible. Keep the bright
  and search-flash branches untouched, so the six-slot row still appears during a chase.
- Helper: `level == 0 && minLevel == 0` → hide every slot.
- Test: harness covers level 0/min 0, level 0/min 3 (flash), level 3 slots 0-5.
- In-game: no star outlines at 0 wanted; one star shows one bright star and no dim slots;
  escaping still flashes the pending search stars.

### 3. Front wheels keep their angle

- Files: `src/vehicles/Automobile.cpp` — `STATUS_ABANDONED` (`m_fSteerAngle = 0`) and
  `STATUS_PLAYER_DISABLED`.
- Change: leave `m_fSteerAngle` alone when the flag is on, in both branches.
- Build 41 proved the abandoned-only guard did nothing: the player's own get-out goes through
  `CPed::SetExitCar`, which sets `STATUS_PLAYER_DISABLED` (`src/peds/PedAI.cpp:4524`), and that
  branch zeroed the angle before the car ever reached `STATUS_ABANDONED`. `WRECKED` still resets.
- Bikes already keep it: `CBike`'s `STATUS_ABANDONED` branch does not reset the angle
  (`src/vehicles/Bike.cpp:351-379`).
- Test: none; this is a one-line branch.
- In-game: park with the wheels turned, exit, the wheels stay turned; re-enter and drive.

### 4. Engine and lights off while exit is held

- File: `src/core/PlayerInfo.cpp:310` (enter/exit handling), `src/vehicles/Vehicle.h:206`
  (`bEngineOn`).
- Change: while the player is in a vehicle and `GetExitVehicle()` is held, count elapsed
  milliseconds; past ~400 ms set `m_pMyVehicle->bEngineOn = false`. Reset the timestamp
  when the key is released or the player is no longer in a vehicle. Lights follow because
  the render block requires `bEngineOn && bLightsOn` (`src/vehicles/Automobile.cpp:2262`).
- The first version required the ped to still be seated when the 400 ms expired. The exit
  starts on the press, so that window is only the get-out animation; if it ends early the
  tick is disarmed on foot and never fires. The tick now arms on the press while driving,
  remembers that car, and cuts while the key is still held whether or not the ped is out.
  It only touches a car the player was driving, and skips it if an AI driver took it.
- Do not set `bLightsOn` directly: `CAutomobile::ProcessControl` recomputes it each frame
  from time/weather (`src/vehicles/Automobile.cpp:2243`).
- Test: harness covers the pure elapsed-time helper (below/at/over threshold, wrap).
- In-game: drive at night, hold exit ~0.5 s; engine sound and headlights stop before the
  door opens. A tap still leaves them on until the normal exit.

### 5. Longer blood and sand particles

- Files: `src/renderer/Particle.cpp:248` (`ReloadConfig`), `src/renderer/ParticleMgr.h:128`
  (`m_aParticles` is public), `src/renderer/ParticleMgr.cpp:197` (config reader).
- Change: after the particle config loads, multiply `m_nLifeSpan` by 2 for
  `PARTICLE_BLOOD`, `PARTICLE_BLOOD_SMALL`, `PARTICLE_BLOOD_SPURT`, `PARTICLE_BLOODDROP`
  and `PARTICLE_PEDFOOT_DUST`. The config is re-read on every `Initialise`, so the
  multiplier must not compound; if it can be called twice without a reload, guard it.
- Test: harness checks the multiplier is applied once and only to those five types.
- In-game: shoot a ped; blood lasts visibly longer. Walk on sand; the dust trail lasts
  about twice as long.
- Not reproduced in build 41: the hook runs after the config load, the enum order matches the
  cfg row order, and blood is already `2000` ms (so ×2 should be obvious). Three `vcm:` log
  lines now print the captured raw values, the applied pair, and each mode change, so the next
  run says whether the config loaded and what the engine actually stores.

### 6. Verify the two existing behaviours

- Closed 2026-11-08, no code. Both paths are in the shipping build: door close sound at
  `CAutomobile::ProcessOpenDoor` (`src/vehicles/Automobile.cpp:4609`), bike flame/smoke at
  `CBike::ProcessControl` (`src/vehicles/Bike.cpp:1105`). The pack's two lines describe what
  reVC already does, so there is nothing to add; the exit thunk the player hears is that sound.
- Door slam: exit a car and listen for `SOUND_CAR_DOOR_CLOSE_FRONT_*`
  (`src/vehicles/Automobile.cpp:4609`). If it is already audible, close the item with a
  note; if not, find which close path bypasses `OpenDoor`.
- Bike fire: set a bike below 250 health and watch the flame/smoke near
  `CAR_POS_BACKSEAT` (`src/vehicles/Bike.cpp:1105-1136`). If it already reads as "beside
  the bike", close the item; otherwise adjust the offset only.

### 7. Mirror mode

- Dropped 2026-11-08. The pack's only surface is a debug-menu entry ("Toggle mirror mode",
  visible in `ViceEx.exe` next to "Toggle Comedy Controls") exposed as
  `features.ini` `MirrorModeByDefault = 0`. That is a developer switch shipped off, not a
  gameplay behaviour, and this fork has no mirror code to turn on. No code, and the row stays
  closed in `2026-11-08-vice-extended-picks.md`.

## Wiring and tests

- `src/extras/vcmodpanel.cpp`: one row, five flags in `aVCModSwitched`, `TWEAKBOOLN` lines.
- `src/core/re3.cpp`: five `ReadIniIfExists("VC Mods", ...)` calls.
- New `utils/test_vc_qol.py`: brace-extract the pure helpers, plus static checks that the
  row exists, the flags are listed, and the ini keys are read.
- Update the panel row-count assertions: `utils/test_vc_passenger.py` expects 25 rows;
  add one (26). Re-run all six harnesses.
- Build: `scripts/build.sh`. Install only with no session running.

## Verification checklist

1. All six harnesses pass; Release build links.
2. Money and wanted HUD match the two checks above.
3. Wheel angle survives exit.
4. Exit hold stops engine and lights; tap does not.
5. Blood and sand particles last ~2x.
6. Door and bike items either confirmed as already present or adjusted with evidence.
7. Toggle `VANILLA FIXES` off and confirm every one of the five reverts to stock behaviour.

## Rollback

Each behaviour is behind its own flag; the master row turns them all off at runtime. Code
rollback is one hunk per item plus the module and row, with no data or savegame changes.

## Risks

- Hidden empty stars change the HUD silhouette; the search-flash branch must keep drawing
  while a wanted level is pending.
- Scripts and missions set `bEngineOn`; the hold must only act on the player's current
  vehicle while the exit key is held, never on AI or mission-owned cars.
- Particle multipliers can compound if the config is not reloaded; guard with a static and
  a fresh-load check.
- Keeping the steer angle leaves an abandoned car's front wheels angled to physics. It is
  the requested behaviour; note it if push tests look odd.
