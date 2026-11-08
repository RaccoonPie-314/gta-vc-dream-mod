# Chase Driving AI - Design Spec

Status: superseded 2026-11-07 by a stock-enhancement approach (see below)
Date: 2026-11-07
Target: reVC `miami` `a26fff4` lineage, branch `vcmods`, macOS arm64
Related: `docs/specs/2026-11-07-swat-chase-design.md`

> **Superseded:** the replacement controller lost to stock AI in the first in-game
> test, because stock already advances route nodes, keeps lanes and calibrates corner
> speed through `CCurves`. The mode now keeps stock steering and adds three nudges:
> engine pursuit against the target vehicle, reverse-out recovery, and a route rejoin
> after a solver failure. Sections describing planning and pure pursuit are historical.

## 1. Summary

Replace the driving layer for mission cars in chase mode with a real route planner,
a pursuit decision layer, a pure-pursuit controller and a recovery state machine.
It runs when a mod flag is on and only for AI-driven automobiles with a driving
mission. Everything else keeps the stock code path.

The change is a driving rework, not a new mission. It reaches the chase leader and
squad cars without editing `vcmodchase.cpp`: with the flag on, mission cars are
driven by the new brain; with it off, stock AI is untouched.

## 2. Goals

- Reach a static destination over the road network without missed turns, backtracking
  or driving into oncoming lanes.
- Pursue a moving target: close the gap, take a safe cut when one exists, and never
  follow the target's old position.
- No random lane changes and no lurch when the route is rebuilt mid-corner.
- Recover from being stuck or blocked within about 3 seconds.
- No vehicle flips on ordinary corners at cruise speed.
- Mode off: byte-for-byte stock behaviour, including story missions.

## 3. Non-goals for v1

- PIT, boxing and deliberate ramming. These are v1b.
- Bikes, boats, helis and trains.
- Ambient `MISSION_CRUISE` traffic tuning; the same brain gets it later.
- New physics, handling-data edits, SCM edits or savegame fields.
- Any edit to `vcmodchase.*` or the panel.
- A visual chase HUD. Telemetry is log plus optional route markers.

## 4. Constraints and project rules

- `reVC` is the upstream checkout. Do not fork, branch or push it.
- Work in the shared checkout. Other agents own `vcmodchase.*`, `vcmodpanel.*`,
  `Ped.cpp`, `Ped.h`, `PlayerPed.cpp`, `re3.cpp` and `PlayerInfo.cpp`.
- New logic lives in new files. Hooks only in currently clean files:
  `src/core/Game.cpp` and `src/core/CarCtrl.cpp`.
- Never stage another agent's files. Stage explicit paths only. No commit or push
  unless the user asks.
- Build from the shared working tree. Committed HEAD alone does not compile without
  the other agent's uncommitted `Ped.h` fix.
- No health, damage, accuracy or handling multipliers.

## 5. Current behaviour and root causes

The chase currently drives through the stock mission path:

- `vcmodchase.cpp:639` `VCModChaseDriveCar` joins the road system with
  `JoinCarWithRoadSystemGotoCoors`, sets `MISSION_GOTOCOORDS`, cruise speed 40 and
  `DRIVINGSTYLE_AVOID_CARS`.
- `vcmodchase.cpp:671` the squad car re-runs that every 2 seconds at the leader's
  **current** position, so the route is rebuilt against a stale point and the car
  lurches through corners.
- `CarAI.cpp:1981` the route search returns at most two nodes. `CarCtrl.cpp:1991`
  falls back to the smallest-angle neighbouring node.
- `CarCtrl.cpp:2058` lane changes are a random coin flip (`GetRandomNumber() & 0x600`,
  then `GetRandomTrueFalse()`).
- `CarCtrl.cpp:2785` the follower has corner speed multipliers but no planned route,
  and recovery is only a short `TEMPACT_REVERSE` (`CarCtrl.cpp:2328`).

That combination produces exactly the four observed failures: wrong roads, stuck or
crashing, no closing speed, and jerky lane changes.

## 6. Architecture

### Units

- `src/extras/vcmodaidrive.h` - public API, phase enum, per-car state, constants.
- `src/extras/vcmodaidrive.cpp` - flag, eligibility, registry, update tick,
  telemetry, optional route markers.
- `src/extras/vcmodaidrive_plan.cpp` - graph route planner, lane plan, moving-target
  detection, intercept point, safe-cut test.
- `src/extras/vcmodaidrive_control.cpp` - pure-pursuit steering, speed profile,
  obstacle and light checks, recovery state machine.

### Hooks

- `src/core/Game.cpp` - one `VCModAIDriveUpdate()` call next to the chase tick.
- `src/core/CarCtrl.cpp` - at the top of `SteerAICarWithPhysics`, if the mode is on
  and the car is eligible, compute our controls, write them, and return. Otherwise
  fall through to the stock function.

`CAutomobile::ProcessControl` calls `CCarAI::UpdateCarAI` before
`CCarCtrl::SteerAICarWithPhysics` (`Automobile.cpp:491-492`), so mission state is
current when the new controller runs. Our hook only replaces control; it does not
own mission transitions.

### Eligibility (v1)

- `pVehicle->IsCar()`.
- Status `STATUS_PHYSICS` (chase cars use it). `STATUS_SIMPLE` cars keep on-rails
  stock behaviour.
- Not the player's vehicle, and has a driver ped.
- `AutoPilot.m_nCarMission` is one of `MISSION_GOTOCOORDS`,
  `MISSION_GOTOCOORDS_STRAIGHT`, `MISSION_GOTOCOORDS_ACCURATE`,
  `MISSION_GOTO_COORDS_STRAIGHT_ACCURATE`, `MISSION_RAMCAR_*`,
  `MISSION_BLOCKCAR_*`, `MISSION_RAMPLAYER_*`, `MISSION_BLOCKPLAYER_*`.
- `m_nTempAction == TEMPACT_NONE`. A live temp action defers to stock for its
  duration, so scripted handbrake stops and waits keep working.
- If `AutoPilot.m_bIgnorePathfinding` is set, the car uses direct mode and the graph
  is not consulted.
- Mode flag on.

### Registry

A fixed pool of 8 active cars, keyed by vehicle pool index and re-resolved every
frame. Dead or recycled vehicles are dropped. No fields are added to `CVehicle` or
`CAutoPilot`, so no layout or savegame change.

Per-car state: phase, plan queue (up to 32 points), plan timestamp, destination at
plan time, target last position and smoothed velocity, stuck timer, lanes, failure
count, telemetry clock.

## 7. Planner

### Graph

Use the link graph, never `prevIndex`/`nextIndex`:

- Node neighbours: `ThePaths.ConnectedNode(firstLink + i)` for `i < numLinks`.
- Link geometry, lanes and directions: `CCarPathLink`.
- Skip disabled nodes, water nodes for cars, and links narrower than the vehicle.
- Respect one-way direction; `CCarPathLink` lane counts define available lanes.

### Route search

A* over links with a bounded open set (256 nodes) and a 32-point output queue. Cost:

- link length;
- turn angle penalty;
- lane-change penalty;
- traffic-light penalty for styles that stop;
- a small penalty for leaving the current road too early.

Start from `AutoPilot.m_nCurrentPathNodeInfo` when valid, otherwise the nearest car
link. Goal is the destination's nearest link, or the exact point when it is already
on the network. Chase beats are path-node positions, so the leader is on-network.

### Re-planning

- Static destination: plan once. Re-plan if the destination moved more than 5 m from
  the plan-time destination, the car is off-plan by more than 12 m, the route is
  exhausted, or recovery failed.
- Moving destination: re-plan every 1.5 s to a **predicted** point, never the
  current position.
- Plan work is staggered across cars; only one car plans per frame.

### Moving target detection

Without chase-file changes, detect a moving destination by comparing
`AutoPilot.m_vecDestinationCoors` across frames. If it moves more than ~2 m in
0.5 s, treat it as a target and smooth the implied velocity. `m_pTargetCar` is used
when the mission sets it.

### Intercept and safe cuts

- If there is line of sight to the target and the gap is above 15 m, compute an
  intercept point at `targetPos + targetVelocity * 1.5 s`.
- Prefer the road route. Take a **cut** only when all hold:
  - the straight segment is under 40 m;
  - `CWorld::ProcessLineOfSight` at car height hits no building or object;
  - sampled points are not over water (`CWaterLevel::GetWaterLevel(..., true)`);
  - the endpoint lies on a road link and re-enters the graph cleanly.
- Otherwise stay in FOLLOW.

### Fallback

If no route exists, switch to a smooth straight-line mode toward the destination,
log once, and keep re-planning. Never drive to the world origin.

## 8. Controller

- Pure pursuit: target is the point at lookahead `L = clamp(6 + 0.55 * speed, 6, 18)`
  metres along the plan, offset into the chosen lane.
- Steering is clamped by a speed-dependent maximum so the car cannot flip. No
  handbrake is used above the recovery speed threshold.
- Lane is chosen on link entry from `numLeftLanes`/`numRightLanes`: keep right,
  take the turn lane before a junction, overtake only with clearance ahead and
  behind. No per-frame random changes.
- Speed target is the minimum of:
  - mission cruise speed;
  - curve limit `v = sqrt(a_lat * R)` from the angle between links;
  - link width and speed-limit contribution;
  - obstacle limit from a forward corridor time-to-collision;
  - a red light when the driving style stops for lights;
  - arrival braking against `m_nSwitchDistance`.
- Braking uses stopping distance, not bumper proximity.
- Traffic awareness reuses the engine's sector lists and weave helpers
  (`SlowCarDownForCars*`, `WeaveThroughCars*`, `FindAngleToWeaveThroughTraffic`).
  No new collision physics and no handling edits.

## 9. Recovery

- Detect: commanded throttle above 0.3, forward speed below 0.6 m/s, and less than
  0.6 m of progress over 2 s, or repeated blocked collisions.
- Phase `RECOVER`: reverse for 1.2-1.8 s with opposite steer, then re-plan.
  Recovery writes throttle, brake and steer directly; it does not set
  `m_nTempAction`, so the stock temp-action path stays untouched.
- Repeat once: three-point turn using the widest nearby links.
- Third failure: stop, log `stuck`, and leave abandonment to the mission.
- Guard the reverse segment with line-of-sight checks; never reverse into water.
- An upside-down car is logged, not teleported, in v1. The mission owns recovery.

## 10. Mission mapping

- `MISSION_GOTOCOORDS` -> FOLLOW along the road graph to the destination.
- `MISSION_GOTOCOORDS_STRAIGHT`, `MISSION_GOTO_COORDS_STRAIGHT_ACCURATE` and
  `MISSION_GOTOCOORDS_ACCURATE` -> direct mode, smooth steering to the point.
- `MISSION_RAM*` and `MISSION_BLOCK*` -> PURSUE: target from `m_pTargetCar` when
  set, otherwise the moving destination.
- `MISSION_CRUISE`, `MISSION_NONE`, `MISSION_STOP_FOREVER` -> stock path in v1.
- Arrival brakes inside `m_nSwitchDistance`; stock `UpdateCarAI` still performs the
  mission transition.
- The module never writes mission fields.

## 11. Debug and telemetry

- Ini key `SmartDrive`, default 0, read lazily from the module.
- A debug key toggles it in play. The panel row is added only after the chase panel
  work lands.
- 1 Hz telemetry: `VCMOD AIDRIVE car=<model> phase=<follow|pursue|cut|recover> pts=<n>
  gap=<m> speed=<x> reason=<...>`.
- Optional debug route markers for the nearest active car, behind the same debug flag.
- The flag is a hard kill switch: off means the stock function is used, with no
  residual state.

## 12. Testing

### Harness

`utils/test_vc_aidrive.py`, following the existing `utils/test_vc_*.py` pattern, for
the pure decisions:

- intercept point from target position and velocity;
- curve speed from angle and radius;
- lane choice from lane counts and junction side;
- stuck predicate from throttle, speed and progress;
- route queue trimming and replan triggers.

### In-game acceptance

- Cross-map static route: no missed turn, no backtrack, no wrong-way lane.
- Squad pursuit: gap closes over 20-30 s on open road; no random lane flips; no
  lurch when the route updates.
- Stuck case: car recovers or logs failure within 3 s; no wall grinding.
- Cruise-speed corners: no flips.
- Mode off: stock behaviour and a story mission run unchanged.
- Performance: under about 1 ms per frame for 8 active cars, measured from the
  telemetry build.

## 13. Risks

- **Physics stability.** Aggressive steering flips cars. Clamp by speed and test at
  cruise before adding pursuit aggression.
- **Mission interference.** Temp actions and mission transitions stay stock; the
  module only writes controls.
- **Dangling vehicles.** Registry uses pool handles and re-resolves; never keep a raw
  pointer across frames.
- **Path data traps.** `prevIndex`/`nextIndex` are unusable; water nodes are car
  nodes; use link data and `bWaterPath`.
- **Shared files.** Only two clean hooks. If either becomes dirty, stop and
  renegotiate rather than editing around the other agent.
- **Arrival semantics.** Braking must hand control back before the mission switches
  to straight/stop, or the car will overshoot.

## 14. Rollout

- v1a: flag, registry, planner and controller for static destinations.
- v1b: moving-target pursuit, intercept and safe cuts.
- v1c: recovery, telemetry, harness and tuning.
- v1d (separate spec): PIT, boxing, ramming and off-road aggression.

## 15. Open questions

None for v1. Ram/block behaviour is deliberately deferred to v1d.
