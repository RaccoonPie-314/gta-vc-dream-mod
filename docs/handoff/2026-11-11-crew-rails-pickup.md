# Crew handoff — normal ride default requested; aggressive switch pending

Historical record, superseded by `2026-11-12-crew-ride-style-and-pickup.md`.
The normal default, aggressive switch and nearer pick-up were implemented and
confirmed in play on 2026-11-12. Crew work is closed; next is cop behavior
extraction. The pending items and build receipts below describe earlier rounds.

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Latest Dock launcher receipt: installed `vcmods build 358`; checkout build
counter also 358. No `reVC` process was found during this handoff update.
Always recheck before installing; no build, install, commit or push was made
for this documentation-only update. The new ride requirements below are not
implemented. Earlier build numbers and test results are historical receipts.

## Latest direction (2026-11-12): normal driving after pick-up

Play report: after picking Tommy up, the crew rams other cars. That is not the
wanted default. The earlier request for fast driving, running reds and weaving
without contact must not be treated as the mandatory ride behaviour.

Accepted requirements for the next implementation:

- After pick-up, drive normally by default: traffic pace, obey red lights,
  brake and queue behind cars. No intentional ramming or aggressive passing.
- Provide an explicit aggressive switch, off by default. When enabled, drive
  fast, ignore red lights and try to pass blocking traffic rather than queue.
  Prefer avoidance over deliberate ploughing; collision-free aggressive
  driving is not a guarantee and must not be described as one.
- Turning the switch off during a ride restores normal driving immediately.
  Switching styles must preserve the current destination and route and must
  not snap the car back onto a lane or restart the pick-up.
- Scope this direction to the ride after pick-up. Keep the existing approach
  behaviour, mission ownership, cop flag and chat behaviour unchanged.
- The far pick-up stop remains an open, separately measured defect.

Current source: `VCModCrewApplyStyle` in `src/extras/vcmodcrew.cpp` reads the
shared `nVCModRideStyle`. FAST selects `STATUS_PHYSICS` and
`DRIVINGSTYLE_PLOUGH_THROUGH` at cruise 55 for a destination or 45 for cruising.
SAFE selects `STOP_FOR_CARS` at 25 or 20, using rails where a route exists.
The FAST branch permits ramming; the selected style during the reported ride
has not been captured, so do not claim it was verified live.

There is already a `RIDE STYLE` row in `src/extras/vcmodpanel.cpp`; inspect its
shared chauffeur use before reusing it or choosing a crew-specific switch.
Do not add two competing controls for the same crew behaviour. A stale shared
FAST setting must not silently defeat the new normal default.
`VCModCrewTickAboard` currently reapplies driving only when the destination
selection changes (`nVCModCrewAppliedZone != nVCModRideZone`), so updating a
style setting alone does not implement a live switch. Cover both toggle
transitions and route preservation with regression tests.

Implementation is pending; this update only records the report and direction.

## The request

The crew driver damages the car on the way to the pick-up. The two mechanics
asked for — ignore red lights, and weave around cars that block the lane — were
meant to stop the waiting, but the car kept reversing when blocked and hit
buildings and other objects.

## Root cause: the ask is not expressible as a stock driving style

This is the seventeenth round on the same symptom. The previous sixteen all
re-picked a driving style or wrote a controller, and the symptom moved each time
(horn → reverse → brake lights → circling → damage → walls). The reason is
structural, and it was confirmed in the engine source rather than inferred:

- **Avoidance is two halves that each lack the other.**
  `STOP_FOR_CARS` and `STOP_FOR_CARS_IGNORE_LIGHTS` avoid only through *speed*:
  `CCarCtrl::FindMaximumSpeedForThisCarInTraffic` scans cars and peds and caps the
  speed. It never steers, so it cannot pass a blocked lane. `AVOID_CARS` avoids
  only through *steering* (`FindAngleToWeaveThroughTraffic`,
  `src/control/CarCtrl.cpp`) and runs no speed scan and no light check at all.
- **Neither half sees buildings.** The traffic scan walks
  `ENTITYLIST_VEHICLES` and `ENTITYLIST_PEDS` only. Static geometry is invisible
  to it. The one thing that stops a physics car at a wall is the collision
  itself — which *is* the damage being reported.
- So "run lights + pass blocking cars + never touch anything" has no stock
  style, and no blend of two stock styles, that satisfies it.

**The one model that cannot steer into a building is rails.** `STATUS_SIMPLE`
runs `CCarCtrl::UpdateCarOnRails` → `DragCarToPoint`, which *places* the car on
its lane curve every frame instead of driving it there. No pedals, no
suspension, no steering overshoot. That is literally what civilian traffic does.
The cost: it is dragged along its own lane, so it queues rather than passes.

Put to the owner as a three-way choice — rails + ignore lights, physics + weave +
a new building-aware speed cap, or physics + ignore lights without the weave.
**Chosen for the approach: rails + ignore lights.** The car queues instead of
passing. This is not a no-damage guarantee: contacts can still convert it to
physics, as the subsequent play report below established.

## What shipped

- `VCModCrewGoto` (`src/extras/vcmodcrew.cpp`) now owns the whole driving
  decision for the run-in, because both call sites (summon and the walk-on
  retarget) go through it. A path exists → `STATUS_SIMPLE` rails at cruise 15.
  `VCModCrewApproachStyle` is deleted; it was the second place that decision
  lived.
- `VCModCrewIgnoresLights(CVehicle*)` is new and exported: true only for the crew
  car during `VCMOD_CREW_APPROACH`. `SlowCarOnRailsDownForTrafficAndLights`
  (`src/control/CarCtrl.cpp`) skips the red-light stop for it. The **bridge stop
  still applies** — that one is a physical barrier, not a signal. The ride
  (ABOARD) obeys lights as before.
- The crew car is out of the `TRAFFIC AI` layer again. That layer's cruise and
  probe logic reads `m_fGasPedal` and `m_fSteerAngle`, which a rails car never
  sets, and it converts cars to physics — the opposite of what the pick-up now
  needs. `vcmodtraffic.cpp` is back to its committed behaviour plus a comment.
  The stock rails governor owns the crew car's speed, exactly like a civilian.
- Deleted the dead weave scaffolding from the abandoned attempt: the
  `FindMaximumSpeedForThisCarOnItsPath` split (and its `CarCtrl.h` declaration,
  which restores that header to its committed state) and both `AVOID_CARS` crew
  branches. Nothing puts the crew car in `AVOID_CARS` any more.
- Kept: all three reverse exemptions in `CarAI.cpp`/`CarCtrl.cpp`, the horn
  silence, and the straight-leg traffic cap in
  `SteerAICarWithPhysicsHeadingForTarget` — that one still serves the physics
  ride, and is a no-op for FAST (`PLOUGH_THROUGH` returns cruise unchanged).

### A gap found and closed while switching

`MISSION_GOTO_COORDS_STRAIGHT_ACCURATE` on rails falls through
`PickNextNodeAccordingStrategy` to `default:` → `PickNextNodeRandomly`. A car with
no path to the destination would have **wandered at random** instead of driving
to it. `VCModCrewGoto` now keeps that one case on `STATUS_PHYSICS`, which aims at
the coordinate properly. This is the same split the ride already used
(`VCModCrewDrive`). Covered by a test.

## Verification (offline only)

- `utils/test_vc_crew.py` — **18 tests OK**, including three new/changed:
  the approach is rails with zero pedals, the light exemption is phase-gated
  (on during APPROACH, off at the kerb and aboard, off for traffic and nil), and
  a no-path run stays on physics.
- `utils/test_vc_passenger.py` — 11 OK. `utils/test_vc_driver.py` — 4 OK.
  These three are the only harnesses that read `CarCtrl`/`vcmodcrew`/`vcmodtraffic`.
- Clean build, linked, installed. Verified by symbol, not hash (install re-signs
  in place): `VCModCrewIgnoresLights` present in the installed binary;
  `ApproachStyle` and `OnItsPath` absent.

These were the initial offline results. Later play exposed the collision
conversion loop; the subsequent sections record that fix and the stop-distance
measurements. They do not prove damage-free driving.

## What to watch in play

Call the crew (`V`) from a street with traffic and watch the run-in:

1. Does the car arrive with no new damage? This is the point of the change.
2. Does it run red lights? It should, on the way in only.
3. Does it queue behind a stopped car instead of hitting it? It should wait —
   that is the accepted trade, not a bug.
4. No brake lights, no horn, no reversing.
5. Boarding and the ride should be unchanged.

Per-second telemetry is already in the build: `VCMOD CREW state phase … mission …
style … temp … gas … brake … slowed …` in `~/Games/VC/reVC.log`. It only lands
there when launched **via the Dock icon**; a terminal launch sends it to the tty.
The initial log had no crew lines. Later builds captured the approach and
stop-distance evidence recorded below.

## Uncommitted

Everything below is uncommitted; no commit, tag or push was made.

- Modified: `src/control/CarAI.cpp`, `src/control/CarCtrl.cpp`,
  `src/extras/vcmodtraffic.cpp` (comment only).
- Untracked: `src/extras/vcmodcrew.cpp`, `src/extras/vcmodcrew.h`,
  `utils/test_vc_crew.py`.
- `src/control/CarCtrl.h` is back to its committed state.
- The wider tree still carries the unrelated street-idle / lock-on / passenger
  work listed in `2026-11-11-street-idle-wander.md`.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` carry the macOS immutable flag. Never install over a running
session (`pgrep -x reVC` must be empty).

## First play on rails: the reverse loop, root-caused and fixed (build 309)

Report: the car kept "respawning with reverse stuff", looping, and stopped far
away. The telemetry added in build 293 captured it — 95 `VCMOD CREW state` lines,
the first crew evidence ever recorded.

Decoded against `eCarMission` (`src/control/AutoPilot.h`): mission 8 =
`GOTOCOORDS`, 9 = `GOTOCOORDS_STRAIGHT`, 11 = `STOP_FOREVER`, 13 =
`GOTO_COORDS_STRAIGHT_ACCURATE`, 1 = `CRUISE`.

The log shows the car **flipping between mission 8 (rails, gas 0, brake 0) and
mission 1 (physics, gas up to 100) every few seconds while oscillating inside a
13 m band** (x 193–206, y ≈ −1306), never arriving. Two earlier runs did arrive
(8 → 9 → 11), so the failure is intermittent and contact-driven.

**Root cause.** `CPhysical::ProcessControl` (`src/entities/Physical.cpp:2115`)
converts any `STATUS_SIMPLE` car that collides into `STATUS_PHYSICS` and calls
`CCarCtrl::SwitchVehicleToRealPhysics`, which **unconditionally overwrites
`m_nCarMission` with `MISSION_CRUISE`** (`src/control/CarCtrl.cpp:3071`). So the
first time the rails crew car touches anything it loses its run to the pick-up
and becomes a random cruising car. The mod's 3 s retarget
(`VCMOD_CREW_RETARGET_WAIT`) then re-issues the route, it touches something again,
and the cycle repeats — that is the reversing/oscillation loop.

This is the documented `SwitchVehicleToRealPhysics` trap. The earlier guard only
covered the traffic layer's call; the engine's own collision path was unguarded.
It also corrects a claim in the first round: rails cannot *steer* into a building,
but a collision still converts it to physics, so "no contact consequences" was
too strong.

**Fix.** One guard at the single choke point every caller goes through:
`SwitchVehicleToRealPhysics` no longer rewrote the mission for the crew car. The
conversion to physics still happens (stock collision response, damage and all),
but the goto route survives, so the car drives the rest of the way and arrives —
the 8 → 9 → 11 shape the two successful runs already showed.

Regression test extracts the **real** `SwitchVehicleToRealPhysics` from
`CarCtrl.cpp` into the crew harness (the stub was replaced by a declaration, and
`CAutoPilot` gained `m_nAntiReverseTimer`): a crew car keeps `GOTOCOORDS`, a
non-crew car still falls back to `CRUISE`. It failed before the guard, passes now.

### The stop distance: now MEASURED, defect confirmed, not yet fixed

The stop is an OR (`VCModCrewTickApproach`): within `VCMOD_CREW_PICKUP_NEAR` = 6 m
of Tommy **or** within `VCMOD_CREW_PICKUP_NODE_NEAR` = 5 m of the pick-up node.
The node is chosen by `VCModCrewPickupPoint` within 15 m, falling back to 60 m.

Build 340's log carries 630 telemetry lines with the new `dT` (car→Tommy) and
`dN` (car→node) fields. At every stop (`phase 2`, `mission 11`):

| dT (m) | dN (m) | verdict |
|---|---|---|
| 2.1 – 4.1 | 2.9 – 4.0 | close enough — the 6 m term fired |
| 8.5, 10.8, 11.1, 12.7 | 2.9 – 4.0 | **too far — the node term fired** |
| 22.6, 27.3, 27.4 | 3.9 – 4.0 | **far too far — the node term fired** |

Every bad stop has `dN < 5` while `dT` is 8.5–27.4 m. So the node term is
stopping the car beside a road node that is nowhere near Tommy, exactly as
suspected. This is now evidence, not inference.

Not fixed yet — it was measured after the owner asked for the handoff, and the
next change is theirs to call. The options, in order of preference:

1. Gate the node fallback so it only counts when the car is also within some
   radius of Tommy, and keep driving otherwise. Needs a termination answer for
   the case where the route genuinely ends far from him.
2. Choose a closer destination: `VCModCrewPickupPoint` returns the node centre;
   a point on the road nearest Tommy would shorten the walk.
3. Shrink `VCMOD_CREW_PICKUP_NODE_NEAR` from 5 m. Cheapest, but it only removes
   5 m of slack — it does not fix a node 27 m away.

## Verification (build 309)

- `utils/test_vc_crew.py` — **19 tests OK** (18 plus the collision regression).
- `utils/test_vc_passenger.py` — 11 OK. `utils/test_vc_driver.py` — 4 OK.
- Clean build, linked, installed with no session running. Verified by the new
  telemetry literal `tommy %.1f %.1f target` in the installed binary.

### The accepted trade

Rails cannot pass a blocked lane, so the pick-up queues like any civilian. That
was chosen over the weave. If waiting ever proves unacceptable, the only
remaining option that passes traffic is the physics + weave + building-aware
speed cap — new code that re-opens the contact risk, and a fresh decision rather
than a style tweak.

## The crew now sees police (build 332)

Report: the crew attacks peds that hurt Tommy but ignores cops. Root cause is
data, not code — `data/ped.dat` gives GANG7
`Threat GUN GANG1 GANG2 GANG3 GANG4 GANG5 GANG6 GANG8 GANG9 EXPLOSION`, with no
`COP`. Every branch of `CPed::ScanForThreats` is gated on
`flagsOfNearPed & fearFlags` (`src/peds/Ped.cpp:917`), including the gun branch
(`:868`), so a cop is invisible to a crew man — even a cop firing.

The engine's gang-alert cannot fill the gap: `RegisterThreatWithGangPeds`
(`src/peds/PedAI.cpp:5475`) only propagates when the attacker is the player or a
gang member, and only writes flags into `RANDOM_CHAR` peds (`:5479`); the crew
are `MISSION_CHAR`.

**Shipped.** `VCModCrewAddMan` sets `m_fearFlags |= PED_FLAG_COP` on each of the
three men; `VCModCrewHandover` clears it again, so a dismissed gang keeps the
stock list. `CharCreatedBy` stays `MISSION_CHAR` — that decision was examined and
kept: `CanBeDeleted()` (`src/peds/Ped.cpp:5123`) is what stops the world culling
them, and they spawn 80 m out, so stock peds would be deleted before arriving.

The path this opens: an idle crew man led by Tommy runs `ScanForThreats`
(`src/peds/PedAI.cpp:680`), a cop now passes the flag test and becomes
`m_threatEntity` (`src/peds/Ped.cpp:1003`), and the same block calls `SetAttack`.

**Limits, stated plainly:**

- The scan only runs while the man is `PED_IDLE` and Tommy is his leader. Men
  walking to keep up are in seek/follow, not idle, so they do not scan.
- Seated men never run it: `IsPedInControl()` is false for `PED_DRIVING` /
  `PED_PASSENGER`, so the whole `UpdateFromLeader` block is skipped. Defence is
  on foot only.
- The near-ped scan's "attacking me" test only fires for a cop attacking that
  particular man, but its fallback picks the closest feared ped regardless. So
  the crew engages nearby police **on sight**, not only police shooting Tommy.
  This trade-off was put to the owner and accepted. Every crime they commit
  lands on Tommy's wanted record.

Two tests added, both red before the change: a serving man carries `PED_FLAG_COP`
alongside his stock gang threats, and dismissal removes it. The harness `CPed`
gained `m_fearFlags`, seeded with a cop-free baseline so the test proves the flag
is added rather than merely present.

**Correction to an earlier claim in this thread:** gang peds are `CCivilianPed`,
not plain `CPed` — `CPopulation::AddPed` creates that class for GANG1-9
(`src/peds/Population.cpp:474`). They do have the civilian layer; what stops them
using it is the `MISSION_CHAR` bail at the top of `ScanForInterestingStuff`
(`src/peds/Ped.cpp:1331`).

### Not built: Tommy chatting with the crew

Asked and answered, no code. In GANG NPC mode Tommy runs the civilian layer
(`src/peds/PlayerPed.cpp:1705`) and `WillChat` already accepts a same-gang pair
via `VCModGangEffectiveType` (`src/peds/Ped.cpp:1427`), so the pairing is legal.
It never happens because the engine's chat loop requires **both** peds in
`PED_WANDER_PATH` within 1.8 m (`src/peds/Ped.cpp:1396`), and a serving crew man
is never wandering: led by Tommy he is in seek/follow, and idle he goes to
`PED_IDLE` because `MISSION_CHAR` skips `SetWanderPath` (`:811`). The crew also
never initiate (`ScanForInterestingStuff` bails), and the mod's own street-chat
picker excludes them twice — `RANDOM_CHAR` only
(`src/peds/PlayerPed.cpp:1367`) and civilians only (`:1374`).

If wanted later: extend the mod's street-chat picker to accept the three crew
peds when GANG mode is on, reusing its existing turn machinery. Stock gangs
mostly chat by spawn-time pairing anyway (`src/peds/Population.cpp:1598`, `:1790`).

## Verification (build 340)

Offline:

- `utils/test_vc_crew.py` — **21 tests OK**.
- `utils/test_vc_passenger.py` — 11 OK. `utils/test_vc_driver.py` — 4 OK.
- Clean build, `vcmodcrew.cpp.o` recompiled, installed; the Dock launcher then
  rebuilt and reinstalled the same tree as build 340.

**In play — the reverse loop is gone.** Across 630 telemetry lines the mission
distribution is: `0` NONE ×369, `11` STOP_FOREVER ×198, `8` GOTOCOORDS ×36,
`1` CRUISE ×21, `9` GOTOCOORDS_STRAIGHT ×4, `13` GOTO_COORDS_STRAIGHT_ACCURATE ×2.
**All 21 CRUISE lines are `phase 4` (ABOARD)** — the ride's own legitimate
`MISSION_CRUISE` from `VCModCrewDrive`. There is **no CRUISE during APPROACH at
all**, where before the fix the car flipped 8 ↔ 1 every few seconds. The approach
now runs 8 → 9/13 → 11 and arrives. The route-preservation guard is confirmed by
play, not just by the harness.

**In play — the stop distance is wrong**, measured above. The newer report also
identifies unwanted post-pick-up ramming; the normal default and optional
aggressive ride switch are pending, as specified at the top.

**Not yet verified — the cop defence.** The telemetry prints no combat state, so
the log cannot show whether the men engaged police. It needs an eyeball check:
stand with the crew on foot, let a cop open fire, and see whether they shoot back.
Remember the three limits (on foot, idle, on sight).

## Next steps

1. **Implement normal post-pick-up driving as the default**, with the optional
   aggressive switch described at the top. Test normal arrival/ride, both live
   toggle directions, destination preservation and player wheel handover. Do
   not bring back mandatory FAST/plough driving or promise contact-free weave.
2. **Fix the far pick-up stop as a separate slice** from the measured numbers.
   Gating the node fallback or choosing a nearer road point needs a route-end
   answer; shrinking 5 m alone cannot fix a node 27 m from Tommy.
3. **Verify in play** after offline harnesses and build pass. Cop defence remains
   unverified; if ignored, capture the men's combat states before diagnosing.
   Recheck that no session is running before any install. Do not launch the
   game as part of this handoff update.

Deferred: Tommy/crew chat was declined (keep them as they are); do not build it
as part of the ride change. The separate traffic stop-light deadlock remains
undiagnosed.