# Auto drive and speed limit — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`.
Status: implemented 2026-11-15 (vcmods build 611, installed); awaiting the
in-game check.

## Goal

Two driving features that share one pace and one stock NPC behaviour:

1. **AUTO DRIVE** — while the player is the driver of a car or bike, the car
   drives itself with one of two stock NPC driving styles. A pause-map marker
   routes it; without a marker it cruises the road graph. Any driving input or
   the key hands the wheel back.
2. **SPEED LIMIT** — while the player drives manually, forward speed is capped
   at the same pace the traffic layer gives civilian NPC cars (cruise 15).

The two styles are the engine's own:
`DRIVINGSTYLE_STOP_FOR_CARS` (stops for cars, peds and red lights) and
`DRIVINGSTYLE_AVOID_CARS` (runs red lights and weaves around traffic, the
stock style cops and stuck cars use). Both still stop for lifting bridges,
which is the stock rule for every style.

## Approved decisions

- Auto drive is for the player's own car from the driver seat, not for NPC
  traffic.
- The aggressive style runs red lights and weaves around other cars instead of
  waiting behind them: the stock `DRIVINGSTYLE_AVOID_CARS`. It is not the RIDE
  FAST plough-through style, which does not steer around anything.
- The safe pace is the traffic pace: cruise 15, the same value the traffic
  layer gives civilian cars (`RTF_CRUISE` in `vcmodtraffic.cpp`).
- The speed limit caps manual driving only; auto drive uses its own cruise.
- Default key: `O` (free in both the stock defaults and the mod's own keys);
  rebindable on the KEYS page.

## Current behaviour (verified in the tree)

- A player-driven car runs `CAutomobile::ProcessControl` case `STATUS_PLAYER`
  and reads the pad through `ProcessControlInputs(0)`
  (`src/vehicles/Automobile.cpp:413-418`); bikes do the same in
  `CBike::ProcessControl` (`src/vehicles/Bike.cpp:245-248`).
- AI driving is `CCarCtrl::SteerAICarWithPhysics` (`src/control/CarCtrl.cpp:2314`):
  it chooses a mission branch, then writes `m_fSteerAngle`,
  `bIsHandbrakeOn`, `m_fGasPedal` and `m_fBrakePedal` directly
  (`CarCtrl.cpp:2402-2406`). It is public and already used by the engine for
  `STATUS_SIMPLE` and `STATUS_PHYSICS` cars.
- `SteerAICarWithPhysics_OnlyMission` covers `MISSION_CRUISE`,
  `MISSION_GOTOCOORDS`, `MISSION_GOTOCOORDS_STRAIGHT` and
  `MISSION_STOP_FOREVER` (`CarCtrl.cpp:2415`). Path following, lane keeping,
  light stopping and the traffic scan all live behind those missions
  (`SteerAICarWithPhysicsFollowPath`, `CarCtrl.cpp:2789`).
- The light stop applies only to `DRIVINGSTYLE_STOP_FOR_CARS` and
  `DRIVINGSTYLE_SLOW_DOWN_FOR_CARS` (`CarCtrl.cpp:2878-2884`); AVOID_CARS skips
  it. AVOID_CARS also steers through `FindAngleToWeaveThroughTraffic`
  (`CarCtrl.cpp:2849`), and `FindMaximumSpeedForThisCarInTraffic` returns its
  full cruise for that style (`CarCtrl.cpp:1115-1117`), so it neither stops nor
  waits behind other cars.
- Brake lamps are the tail coronas; any positive `m_fBrakePedal` brightens them
  (`Automobile.cpp:2461`), and the cruise AI holds its speed with a brake trim.
  The crew module already drops a trim under `0.15` when the AI is not slowing
  for a car or ped (`Automobile.cpp:506-511`).
- Cruise speed maps to world speed with
  `GAME_SPEED_TO_CARAI_SPEED 60.0f` (`src/control/CarCtrl.h:9`).
- The traffic layer sets every civilian car to cruise 15
  (`RTF_CRUISE`, `src/extras/vcmodtraffic.cpp:20`, applied at `:217`).
- RIDE already drives a borrowed street car from an NPC driver through
  `JoinCarWithRoadSystem` / `JoinCarWithRoadSystemGotoCoors` plus
  `MISSION_CRUISE` / `MISSION_GOTOCOORDS` (`src/extras/vcmodride.cpp:340-362`),
  and saves/restores the car's own pace (`vcmodride.cpp:81-101`).
- The player's exit-at-speed rule branches on `GetStatus() != STATUS_PLAYER`
  (`src/core/PlayerInfo.cpp:337`), so the car must keep `STATUS_PLAYER` while
  the mod drives it.

## Approach

The car keeps `STATUS_PLAYER`. After the stock `ProcessControlInputs`, the new
module calls `CCarCtrl::SteerAICarWithPhysics(car)`, which overwrites the
pedals, steering and handbrake with the stock NPC output for the current
mission. This reuses the NPC driving code exactly and leaves every
player-car rule (damage, audio, exit, mission checks) untouched.

The rejected alternative was flipping the car to `STATUS_PHYSICS` and letting
the engine run `CCarAI::UpdateCarAI`; it would change the exit-at-speed path,
damage and audio branches, and the player car's identity for scripts.

`CCarAI::UpdateCarAI` is not called: its mission bookkeeping is replaced by
two explicit edges in the module (arrive → `MISSION_STOP_FOREVER`, cancel →
restore). Everything the driving itself needs is inside
`SteerAICarWithPhysics`.

## Module

New `src/extras/vcmodautodrive.{cpp,h}`.

State and public surface:

```c
enum eVCModAutoDriveMode {
    VCMOD_AUTODRIVE_OFF,
    VCMOD_AUTODRIVE_SAFE,
    VCMOD_AUTODRIVE_AGGRESSIVE,
    NUM_VCMOD_AUTODRIVE_MODES
};

extern int32 nVCModAutoDriveMode;   // eVCModAutoDriveMode; OFF unless driving
extern bool bVCModSpeedLimit;

int32 VCModAutoDriveModeGet(void);
void VCModAutoDriveSetMode(int32 mode);  // refuses any ON when not the driver
void VCModAutoDriveKey(void);            // toggles OFF <-> last style
void VCModAutoDriveControl(CVehicle *vehicle);  // per frame, player cars only
void VCModAutoDriveTick(CPlayerPed *player);    // ends a session the player left
void VCModAutoDriveReset(void);
```

Session state is a vehicle pool handle, the applied mode, the destination and
the saved AutoPilot fields (mission, style, cruise, max traffic speed, temp
action, path node count, destination). Reused fields come back on every end
path: key off, any driving input, arrival, exit, death, wreck, save load.

`VCModAutoDriveSetMode` validates the seat and vehicle type and shows the
refusal: on foot, passenger seat, or a boat/plane/heli/train. Turning the mode
on remembers the style for the next key press (module static, not persisted).

## Auto drive behaviour

- **Engage.** Mode non-OFF while the player drives a car or bike. The module
  saves the car's AutoPilot fields and routes it.
- **Destination.** If `CRadar::TargetMarkerId != -1`, route to
  `CRadar::TargetMarkerPos` with `JoinCarWithRoadSystemGotoCoors`; the engine's
  straight-line mission is the fallback, the same rule RIDE uses. Without a
  marker, `JoinCarWithRoadSystem` plus `MISSION_CRUISE`.
- **Style and pace.** `DRIVINGSTYLE_STOP_FOR_CARS` for SAFE,
  `DRIVINGSTYLE_AVOID_CARS` for AGGRESSIVE; cruise and max traffic speed set to
  `VCModTrafficPace()` (15).
- **No cruise trim lamps.** After the AI call, a brake pedal under `0.15` is
  dropped unless `m_bSlowedDownBecauseOfCars` or `...Peds` is set, the same
  rule the crew car uses; the tail lamps stay off while the car just holds its
  pace.
- **Live changes.** A style change re-applies style and pace without
  discarding the route. A marker placed, moved more than 25 m or removed
  re-routes, the same live rule the RIDE destination uses.
- **Arrival.** Within 3 m of the destination (the stock mission-car arrival
  distance in `CarAI.cpp:186`), the mission becomes `MISSION_STOP_FOREVER`;
  when the car has stopped, the mode turns off with `auto drive: arrived`.
- **Take the wheel.** Accelerator, brake, steering or handbrake cancels and
  the player's input applies that frame. A driving input already held when the
  car takes over is latched: the wheel returns on the next press after all
  driving controls are released, so engaging with the gas held does not
  instantly cancel.
- **End without a notice.** Exit, arrested, wrecked or a stale handle ends the
  session and restores the AutoPilot fields silently.
- **Key.** `VCKEY_AUTODRIVE` (default `O`): OFF → last style, ON → OFF with
  `auto drive off`.

## Speed limit behaviour

- Row on: for any car or bike the player drives manually (auto drive off),
  forward speed is compared to the pace through
  `DotProduct(moveSpeed, forward) * GAME_SPEED_TO_CARAI_SPEED`.
- Above the pace: gas is cut to 0 and the car coasts down, the quiet way
  traffic holds its cruise. A brake is applied only when the overshoot is real
  (the proportional `Min(0.5f, (speed - pace) * 0.05f)` reaches `0.15`, the
  threshold below which the tail-lamp coronas would brighten for a trim); a
  stronger player brake is never lowered. At or below: nothing is touched.
- Reverse is not capped. Steering and handbrake stay the player's. While auto
  drive runs, the governor is skipped (auto drive's cruise is the same pace).
- Row off is the stock path, with no read of the pad or the car's speed.

## Panel, keys, ini

- DRIVING page, one cycle row `AUTO DRIVE` with `[OFF]` / `[SAFE]` /
  `[AGGRESSIVE]`, no ini key: a command that is never armed at startup.
- DRIVING page, flag row `SPEED LIMIT`, ini key `SpeedLimit`, default off,
  read in `re3.cpp`.
- KEYS page, `AUTO DRIVE KEY` row; `vcmodkeys` gains `VCKEY_AUTODRIVE` with
  default `O`, label `AUTO DRIVE` and ini name `KeyAutoDrive`.
- The master ALL ON sweep does not include `SPEED LIMIT`: silently capping
  the player's speed with an ambient sweep is a surprise (same reasoning as
  CREW AGGRESSIVE).
- `VCModTrafficPace()` is exported from `vcmodtraffic.{h,cpp}`: the one home
  for 15, so the limit cannot drift from the NPC pace.

## Hooks

One line each:

- `src/vehicles/Automobile.cpp` — after `ProcessControlInputs(0)` in the
  `STATUS_PLAYER` branch: `VCModAutoDriveControl(this);`.
- `src/vehicles/Bike.cpp` — same place.
- `src/peds/PlayerPed.cpp` — `VCModAutoDriveTick(this);` next to
  `VCModUpdateRide(this)`; the key handler next to the CALL DRIVER block.
- `src/save/GenericGameStorage.cpp` — `VCModAutoDriveReset();` after
  `VCModSaveReset();` so a loaded save never inherits a stale handle.

## Notices and log

- `auto drive: safe` / `auto drive: aggressive` on engage or style change;
  `auto drive off` on take-back or key; `auto drive: arrived`.
- Refusals: `auto drive: get in the driver seat`, `auto drive: not from the
  passenger seat`, `auto drive: not in this`.
- One unconditional log line on session start and on every end reason; no
  per-frame logging.

## Tests

`utils/test_vc_autodrive.py`, following the driver/passenger harness pattern:

- style maps to the two stock driving styles (`STOP_FOR_CARS`, `AVOID_CARS`)
  and the traffic pace;
- auto drive drops a sub-`0.15` cruise brake trim unless slowing for traffic;
- speed limit cuts gas above the pace, adds no trim brake (no tail lamps), and
  brakes only on a real overshoot; a stronger player brake is kept;
- marker → destination mission, no marker → cruise; marker moved/removed
  re-routes; style change keeps the route;
- take-the-wheel cancels on a new press, latches a held input;
- arrival holds the brake until stopped then turns off;
- exit/death/wreck ends and restores the saved AutoPilot fields;
- speed limit cuts gas and brakes above the pace, leaves pedals alone at or
  below it, ignores reverse, skips while auto drive runs, off path is stock;
- mode setter refusals (on foot, passenger, wrong vehicle type);
- registry: rows, labels, info/warn lengths, key slot and ini read present.

Full suite `utils/test_vc_*.py`, then the build and install.

## Out of scope

- Boats, planes, helicopters, trains, RC vehicles.
- Driving NPC cars with these styles (traffic keeps its own layer).
- Changing the RIDE FAST style or the traffic layer's cruise.
- Path-node speed-limit multipliers; the pace is the traffic pace.
