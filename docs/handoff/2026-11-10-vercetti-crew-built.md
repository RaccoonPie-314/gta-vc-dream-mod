# Handoff — Vercetti crew built (2026-11-10)

## Where things are

- Workspace `vc-mod`, code in `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
- Built and installed into `~/Games/VC/reVC.app` at 16:52 on 2026-11-10, after the
  three play reports below. No session was running during any install, and the
  game has not been launched since.
- The design and the task list are unchanged:
  `docs/specs/2026-11-10-vercetti-crew-design.md`,
  `docs/plans/2026-11-10-vercetti-crew.md`. All seven tasks are implemented.

## What was built

- `src/extras/vcmodcrew.{h,cpp}` — the four-door shelf, the summon, the phase
  machine (`APPROACH → PICKUP → SWAP → ABOARD → ESCORT`, plus `DISMISS_WAIT`), the
  F handover, the seat fill, the ride mission, the handover to a street gang, the
  death hook and the telemetry (`VCMOD CREW` lines on stderr).
- `VCKEY_CREW` (`V`) and `VCKEY_PASSENGER` (`P`), ini `KeyCrew` / `KeyPassenger`;
  `CrewCar` picks the car. `PASSENGER MODE`, its row and its ini read are gone.
- `P` boards the nearest car within 10 m as a passenger, driver or not; `F` is
  stock everywhere except the summoned limo and the crew car. The passenger key's
  ride watchdog is only armed for a driven car; an empty one is not frozen.
- DRIVING page: `CALL CREW` and `CREW CAR` above `CALL DRIVER`; the table is 52
  rows. KEYS page: `CALL CREW KEY`, `PASSENGER KEY`.
- README: new "Vercetti crew" section, the passenger riding rewrite, the key list
  (eleven keys), the two new toggle rows.
- `utils/test_vc_crew.py` — the crew harness (shelf, summon, failures, handover,
  abort, fill, escort re-press, dismissal, death, panel rows).

## Verification

Every `utils/test_vc_*.py` passes, and `scripts/build.sh` links the app. Nothing
has been played: the harnesses prove the state table, not the feel.

## First play report and its fix

Played once on the 15:25 build. `V` spawned the car and the three men, but the men
stood beside the car doing nothing and the car never drove.

Root cause, in engine code rather than the mod: the men were linked to Tommy at
spawn. `CPed::UpdateFromLeader` is not only the `IsPedInControl()` block — there is
an `else if (bInVehicle)` branch (`src/peds/PedAI.cpp:733`) that orders
`OBJECTIVE_LEAVE_CAR` for a seated follower whose leader is on foot. Tommy was on
foot on the kerb, so every man was ordered out 250 ms after spawning; once outside,
the 30 m leader leash (`PedAI.cpp:612`) made them idle where they stood, and the
driver's exit left nothing at the wheel.

Fix: `VCModCrewAddMan` no longer calls `SetLeader`. Each man is linked in the aboard
pass (`VCModCrewTickAboard`) when he is seated with Tommy, plus the ex-driver in
`VCModCrewTickSwap` when he takes the rear seat. The harness asserts the spawn
state (`m_leader == nil`) and that a seated man is linked again. The design's §4.1
and §5.2 said "in-vehicle crew are immune" and "links can be set at spawn"; both
were wrong and are corrected in the spec.

## Deviations from the plan (worth knowing)

- The plan's crew harness could not compile as written: `CREW_STUBS` needs its own
  `events` vector, `CModelInfo` has to be declared before `CVehicleModelInfo` uses
  it, `ride_enums()` has to come before `CREW_STUBS` because the stubs initialise
  `nVCModRideStyle`, and the crew phase enum is read from `vcmodcrew.h` so it
  cannot drift. All fixed in `test_vc_crew.py`.
- The plan's fill test asserted `car->pDriver == pedPool[0]` after the fill, which
  the stub cannot model (no door-walk AI). It now asserts the driver objective, then
  warps the men in to check the leader link comes back.
- The plan's dismiss/death tests expected `PICKUP → ESCORT` on foot. Pick-up only
  leaves on boarding, so both route through a one-frame `ABOARD` first.
- `F` in `ESCORT` would have been swallowed by `VCModCrewEntry` (returned `true`,
  did nothing), so a parked crew car with a man at the wheel could never be taken
  again. It now runs the same handover and remembers the phase it started from
  (`nVCModCrewSwapFrom`), so an abort returns to the escort rather than pick-up.
- The passenger key's "release the ride I was holding" moved out of the driver
  block, so a press on the crew car or an empty car still hands back a car held
  from an earlier press.
- The street-car arrival notice renamed `passenger mode: arrived` →
  `passenger: arrived`, and the two pressed notices lost the same stale word.
- `utils/test_vc_driver.py` asserted the retired rule (F on a street car boards);
  that block now presses `VCModPassengerKey()` from beside the car.
- `test_vc_character.py` / `test_vc_adrenaline.py` gained crew symbol stubs (and
  the adrenaline render list extracts `VCModCrewCell`), because the shared panel
  code now calls into the crew module.

## Second and third play reports

Round two produced two fixes. Round three showed the first of them was a wrong
guess and named the real cause of the driving trouble:

1. **The car rammed walls and fences on its way, and sometimes stopped driving.**
   Two separate faults, both ours. First, the approach destination was Tommy's exact
   position, and `CCarAI` switches a `MISSION_GOTOCOORDS` car to a **straight line**
   inside `FindSwitchDistanceClose` (20 m) of that point (`CarAI.cpp:175`). With
   Tommy on a pavement, lawn or behind a fence, the last 20 m was a straight drive
   through whatever stood between; on arrival the mission went to `MISSION_NONE`
   and the car sat. The pick-up is now a **car path node** near Tommy (15 m, then
   60 m, then his feet) so the final straight run stays on the road, and the car is
   stopped by our own 15 m pick-up ring first. Second, the ride mission was issued
   while the driver seat was still empty, so a car with Tommy aboard could start
   moving before the fill's driver was seated, and the engine's entry code could
   overwrite the mission when he did sit. `VCModCrewTickAboard` now issues the
   drive only when a crew man is actually at the wheel.
2. **The first attempt at the "reversing/honking at a light" report was wrong.**
   A guard that refreshed `CarHasReasonToStop` and cancelled `TEMPACT_REVERSE`
   whenever a red light was near was based on a misread: it read the car's path
   links without validating them and could hold a car that was not at a light,
   which is why round three saw *more* stuck cars. It is gone.
3. **The horn.** The crew car leaned on the horn like an NPC in a jam, which is
   stock engine behaviour (`CAutomobile::PlayHornIfNecessary`). `VCModCrewQuietHorn`
   keeps `m_nCarHornTimer` alive while a crew man drives, so the crew car does not
   honk at all. Nothing else changed about the AI.
4. **Riding as a passenger, then a crew man took the wheel, and everyone was
   ordered out, Tommy included.** (Round two; still fixed.)
   `CPed::PedSetInCarCB` ejects every passenger that lacks `bStayInCarOnJack` when a
   ped enters as driver (`Ped.cpp:4373`). The crew men carry the flag; Tommy did
   not. `VCModCrewKeepPlayerSeated` sets the flag on Tommy while he is in the crew
   car (the aboard pass, before the fill can order a driver) and gives it back when
   he leaves or the crew is torn down, remembering whether the mod set it so a
   script's own value is not cleared.

The crew telemetry line prints `mission`, `style` and `temp`, so a car that
misbehaves again can be diagnosed from `reVC.log`.

## Fourth play report: the permanent horn and the reversing pickup

Two faults, and the horn was ours while the reversing was stock:

1. **The horn never stopped.** `VCModCrewQuietHorn` held `m_nCarHornTimer` at 20
   every frame. That does stop `PlayCarHorn` from firing a new beep, but the audio
   layer plays the horn sample whenever the timer is above zero and the pattern bit
   is set (`AudioLogic.cpp:2779`, `HornPattern[pattern][44 - timer]`; bit 24 is set
   in all eight patterns), so the car sat mid-honk forever. It also told every ped
   in range the car was honking (`Ped.cpp:6844`), so they kept evading it. The
   function is gone. `CAutomobile::PlayCarHorn` now returns early for the crew car
   (`VCModCrewOwnsCar`), which covers both callers, `PlayHornIfNecessary` and the
   car AI's unstick. The player's own horn sets the timer directly and is untouched.
2. **It reversed at the pickup.** The crew car is a `MISSION_VEHICLE`, and
   `CCarAI::UpdateCarAI` gives mission vehicles the reverse unstick regardless of
   driving style (`CarAI.cpp:395`): two seconds stationary becomes 1500 ms of
   reverse. Behind a queue or a red light that reads as rocking back and forth and
   ramming, and it is the aggressive part of the pickup. The mission-vehicle clause
   now skips the crew car, so it follows its style like a civilian car would:
   `STOP_FOR_CARS` at 25 under SAFE waits in a queue and does not reverse; FAST still
   gets the reverse, as any fast car does.

Not the traffic mod: `VCModTrafficUpdate` returns early for `MISSION_VEHICLE`
(`vcmodtraffic.cpp:198`), so the ported real-traffic AI never touched the crew car.

## Fifth and sixth play reports: the pick-up, the stop distance, the brake lights

1. **Leaving the car and boarding again left it parked.** The ride was issued only
   when the applied zone differed from the panel's RIDE TO. After the car arrived
   and parked, the zone was still the same, so `VCModCrewTickAboard` never issued
   the ride again. The ABOARD → ESCORT step now clears `nVCModCrewAppliedZone`, so
   any later boarding issues the same zone afresh (cruise included).
2. **The pick-up now cuts traffic, i.e. `AVOID_CARS`** at cruise 25
   (`VCModCrewApproachStyle`). The first attempt, `STOP_FOR_CARS_IGNORE_LIGHTS`,
   ran the lights but still queued behind cars, which is not what was asked. Phase
   two also gave the straight final leg a speed cap because it has no traffic scan
   of its own; `AVOID_CARS` makes that cap moot and steers around the car instead,
   in both the path-follow and the straight-leg steer. The crew car is now exempt
   from the reverse unstick in every style, so a wedged weave cannot turn back into
   the old back-and-forth.
3. **The pick-up stops beside Tommy, not at the node.** The ring was 15 m measured
   to the road node, and the node itself can be 15 m from him, so the car could
   park 30 m away. It now stops at 10 m from the player's own position
   (`VCMOD_CREW_PICKUP_NEAR`), while the route still aims at a road node.
4. **The "always braking" was the AI's speed trim.** The AI holds its target speed
   with the brake pedal, and any pedal above zero lights the rear lamps
   (`Automobile.cpp:2453`), so a crew car looks permanently braked while ordinary
   traffic is mostly `STATUS_SIMPLE` and has no pedals at all. Light trims
   (< 0.15) are now dropped for the crew car when nothing is flagged as blocking
   it; braking for a car or a ped is kept. The AVOID pick-up removes the rest of
   the trim, because that style does not chase a traffic-capped target.
5. **Telemetry now prints the pedals.** The `VCMOD CREW state` line carries
   `gas`, `brake` and `slowed cars/peds` after `temp`; if braking still looks wrong,
   one line from `reVC.log` says whether it is a real block or a trim.
6. **Heavy braking in a normal drive is stock.** SAFE is `STOP_FOR_CARS` at 20: it
   brakes for cars ahead and stops 8 m short of a red light
   (`CTrafficLights::ShouldCarStopForLight`). Stock traffic is the same style at
   12–16 (`CarCtrl.cpp`), so this is not a crew-only behaviour; FAST is the panel's
   other choice.

## Seventh play report: the crew car now drives on rails

Three physics builds in a row failed on the same point: a physics AI car has to
work its speed through the pedals, and pedestrian traffic does not. The crew car
is now `STATUS_SIMPLE` while the AI drives it, the same mode every civilian car
uses (`CCarCtrl::UpdateCarOnRails`), and physics only for the deliberate FAST
ride and the no-path fallback.

- **Why the traffic looks calm.** On rails the car is dragged along its lane by
  `CCarCtrl::UpdateCarOnRails`, and `SlowCarOnRailsDownForTrafficAndLights` only
  moves a speed target (`AutoPilot::ModifySpeed`). There is no throttle or brake
  pedal at all, so there are no brake lights and no governor braking. That
  answers "why do NPCs not brake": they have no pedals.
- **Seeding the curve.** The rails position is a function of time, so
  `VCModCrewRailsSeed` rebuilds the curve timing around the car's real place on
  the link pair after every join or re-route. Without it the first frame drags
  the car back to the start of the link.
- **The pick-up still runs the lights.** The rails slow-down stops at lights for
  every car; `VCModCrewIgnoresLights` exempts the crew car during APPROACH, so
  the run in cuts reds while still lowering its speed for whatever is in front.
  It cannot pass a blocked lane on rails — that is the stock limit, and it is
  why the weave (AVOID_CARS, a physics style) was worse: it circled and, with the
  crew exemption from the reverse unstick, ended up stopped.
- **The stop ring now also accepts the node.** With the ring at 10 m around
  Tommy, a route ending at a node 15 m from him never tripped it: the mission
  completed and the car sat in APPROACH. Arriving within 8 m of the pick-up node
  now counts too.
- **Unchanged:** the ride obeys lights and lights up nothing; FAST is still the
  physics plough; the horn guard, the reverse exemption and the brake-trim trim
  only matter on the physics paths now.

## Eighth play report: the pick-up weaves again

The rare NPC that runs a light, does not queue and goes around other cars is the
stock `AVOID_CARS` car: the engine escalates a car to that style after it has sat
wedged for 15 s (`SlowCarDownForOtherCar`), and that style is not in the light-stop
list, so it cuts reds and steers through gaps. The seventh report's claim that the
mode did not exist was wrong.

The pick-up is back on it: `STATUS_PHYSICS`, `AVOID_CARS`, cruise 20 (down from
25, which is what clipped cars while weaving). The two things that broke the first
attempt are both fixed now: the stop ring accepts the pick-up node (arriving at
the node used to end the mission silently, which is the "stopped moving"), and the
crew car is no longer exempt from the reverse unstick, so a wedged weave backs out
the way a stock car does. Removing that exemption is what made the first AVOID
build sit forever.

The ride is unchanged: rails for SAFE, physics plough for FAST. The red-light
exemption in the rails slow-down went away with it, because the pick-up is no
longer on rails.

## Ninth play report: the car always arrives damaged

The damage is the style split, not a bug. In this engine the two traffic styles
each do half the job:

- `STOP_FOR_CARS` and `STOP_FOR_CARS_IGNORE_LIGHTS` avoid cars through **speed**:
  `FindMaximumSpeedForThisCarInTraffic` scans a 14 m box, predicts rect collisions
  with moving cars and peds and caps the speed to the leading car's pace. The
  IGNORE variant only removes the 8 m red-light stop. Neither steers.
- `AVOID_CARS` avoids cars through **steering**: `FindAngleToWeaveThroughTraffic`
  picks an angle. It runs no speed scan at all — that is why a stock weaving car
  clips things and why the crew car arrived beaten up.

The crew car in `AVOID_CARS` now also runs the engine's scan: the scan was split
out as `CCarCtrl::FindMaximumSpeedForThisCarOnItsPath` (the old style check moved
into `FindMaximumSpeedForThisCarInTraffic`), and the crew car uses it in both the
path steer and the straight-leg aim. So it weaves, but slows when the gap it is
aiming at is closing, and it also brakes for peds. Every other car's behaviour is
unchanged.

## Tenth play report: reversing into walls, and the remaining contact

1. **The reversing was the stock unstick, twice.** The 2 s-stationary → 1500 ms
   reverse branch backs up without looking
   (`SteerAICarWithPhysics_OnlyMission` has no rear scan), and I had restored it
   for the crew car in the eighth round. It is off again. The second one was
   hidden: every 30 s, a car with `randomSeed & 7 == 0` cruising is escalated to
   physics, AVOID and a 400 ms reverse — that one also hit the crew car on the
   rails ride. Both branches now skip the crew car. It waits instead, which is the
   correct behaviour for a car stopped by traffic.
2. **The pick-up cruise is down to 15**, the pace the traffic layer pins every
   civilian car to. Relative closing speeds are what caused most of the contact;
   at the same pace the weave has room and the 14 m scan lands on time.
3. **The car starts pointing along the route's first link**, not at Tommy. Facing
   him could mean facing against the legal lane, and a run that begins nose-to-nose
   with traffic swipes the first car it meets (`VCModCrewFaceRoute`).
4. **What is left is the stock weave itself.** `FindAngleToWeaveThroughTraffic`
   picks an angle with no clearance model, and its collision scan projects along
   the car's own heading while the car is moving sideways. At 15 with the scan the
   risk is much smaller, but a guaranteed no-contact pass needs a custom steering
   layer, not another style flag.

## Eleventh: the run-in has its own controller

The stock styles each do half the job, so the pick-up run now has a real one:
`VCModCrewPassControl` in `vcmodcrew.cpp`, called from `CAutomobile::Update`
right after the stock AI steering (that call still advances the route).

- Follows the route's own curve (`CCurves::CalcCurvePoint`) with a lateral offset.
- Scans 16 m around a point 12 m ahead for cars and peds. When something slower
  occupies the lane within 22 m, it tests the corridors 3 m left and right for
  2.2 m of clearance and takes a free one, holding it for up to 2.5 s.
- Eases across at 0.08 m a frame instead of swerving, so it never snaps into the
  lane beside it.
- Keeps a stopping gap to whatever is in the corridor it will sweep and drives a
  speed target from it; the pedals have a deadband, so there are no brake lights
  while cruising.
- Never reverses: boxed in, it brakes and waits. The stock mission-vehicle reverse
  and the 30 s cruise reverse are both still skipped for the crew car.
- If the controller stands down (mission not a goto, route finished), the stock
  style is `STOP_FOR_CARS` at 15, i.e. it waits rather than weaves.

`utils/test_vc_crew.py` now runs the controller against stubbed links and world:
pass side chosen and eased into, an occupied side refused, and a boxed-in car
braking instead of reversing. 15 crew checks.

Also found in the live `reVC.ini`: `RideStyle=1`, the panel's "fast &
aggressive", which sends every RIDE TO through `PLOUGH_THROUGH` at 45–55. That is
likely a large part of the damage, and it is a setting; SAFE is the rails ride.

## Twelfth: the circling, and which install is which

- `~/Games/VC-ai` is a **Nov 8 build with no crew code at all**: its binary is dated
  Nov 8 10:26, it has no `VCMOD CREW` strings, and it has no `mods/` directory. The
  mod-pack tree is `~/Games/VC` (it owns `mods/`), and its app is today's build.
  Everything crew-related only ever existed there.
- The circling came from the first pass controller: its aim point was computed from
  the route's curve clock, which runs on its own timer. When the clock led the car,
  the aim landed behind it, and a car aiming at a point behind itself drives a
  circle. The aim is now the lane line, projected forward from the car's own place
  on it, and the link's direction flag is aligned to the car's heading first.
- Also in this build: the engine's own steer limits (full lock at speed spins the
  car), a sideways guard that hands the wheel back while the car is turned across
  the lane, a side-clearance probe that counts buildings and objects, not just
  traffic, and a hard bailout — ten seconds without closing the distance to the
  pick-up and the stock AI takes over for the rest of the run, with an on-screen
  "letting the driver find his own way".

## Thirteenth: contact, and the stop distance

- **The lateral margins were narrower than a car.** The corridor used 1.4 m either
  side, while two cars are about 2.2 m from mirror to mirror; a car just outside
  the corridor was never slowed for. `VCMOD_CREW_HALF` is 2.2 and is used by the
  blocked test, the side checks and the speed corridor.
- **The scan only looked forward.** An overtaking car in the lane the car was
  moving into was invisible, so the pass could sideswipe it. The scan now reaches
  10 m behind, and the side checks refuse a corridor with anything from 8 m behind
  onward.
- **The speed target now takes the engine's own prediction as a ceiling**
  (`CCarCtrl::FindMaximumSpeedForThisCarOnItsPath`, the moving-rect scan), which
  catches crossing traffic and peds that a lane corridor cannot.
- **Stop rings:** 6 m from the player (was 10) and 5 m from the pick-up node (was
  8). The distance is measured from the car's centre, so 10 m was about 7.7 m from
  the bumper; 6 m is about 3.7 m.

## Fourteenth: the traffic AI drives the pick-up

The crew car is a `MISSION_VEHICLE` (deliberately: mission cars are not culled and
carry a route), and `VCModTrafficUpdate` skips mission vehicles, so the TRAFFIC AI
had never touched it. It now does, for the approach only:

- `vcmodtraffic.cpp` lets a mission vehicle through when `VCModCrewOwnsCar` and the
  phase is `APPROACH`;
- the physics switch is skipped for the crew car because
  `CCarCtrl::SwitchVehicleToRealPhysics` replaces the mission with `MISSION_CRUISE`
  and would throw the route away.

The custom pass controller is gone: its call in `CAutomobile::Update`, its helpers
and state, its header entry and its harness test. The car now gets exactly what a
civilian car gets — cruise 15, the three-ray front probe, the ground-stuck fix, and
the jam rule that switches to `AVOID_CARS` for 4 s after 3 s stuck. Consequences:
it obeys red lights and queues like traffic, and it can weave briefly out of a jam.
The stop rings stay at 6 m from the player and 5 m from the pick-up node.

Also still true: the blind reverse branches skip the crew car, the horn stays quiet,
the ride is rails for SAFE and physics plough for FAST, and the live ini still has
`RideStyle=1` (fast & aggressive) — worth setting to SAFE before judging the ride.

## Fifteenth: the crew car is out of every weave escalation

Two places switch a stuck car to `AVOID_CARS` — the traffic layer after 3 s
(`vcmodtraffic.cpp`) and the engine's own 15 s rule in
`SlowCarDownForOtherCar` (`CarCtrl.cpp`). `AVOID_CARS` runs no obstacle scan at
all (`FindMaximumSpeedForThisCarInTraffic` returns the cruise immediately), so it
is a blind weave; on the crew car that read as "aggressive mode, ramming cars".
The layer's restore only runs while the car is within 120 m of the camera, so a car
that drifted out of that window stayed in the weave for good. Both flips now skip
the crew car, which stays `STOP_FOR_CARS` at 15: it obeys lights, brakes for what
is in front, and never weaves. Ignoring lights is not itself what hits cars — the
blind weave is.

## Sixteenth: the gang keep their own animations

Play report: the crew moved like Tommy. The engine's follower rule in
`CPed::SetMoveAnim` (`src/peds/Ped.cpp`) hands any ped whose leader is the player
`ASSOCGRP_PLAYER` for idle/walk/run/sprint. The crew take Tommy as leader in the
aboard pass, so they borrowed his set. `default.ide` gives `PGA`/`PGB` the `gang1`
group, which is what they should keep. Added `VCModCrewOwnsPed` (`vcmodcrew.{h,cpp}`,
mirrors `VCModCrewOwnsCar`) and exempted the three men from that one override, so
they walk and idle in `gang1` while any other player follower still borrows Tommy's
set. The leader link itself is untouched — escort/follow behaviour is unchanged.
Harness: `test_vc_crew.py` gained a membership test and a compile test that drives
the real `SetMoveAnim` down the walk branch (crew → `gang1`, other follower →
`ASSOCGRP_PLAYER`, leaderless → own group). All 27 suites green; built and installed.

## Uncommitted

This session (all of it works, none of it staged):

- New: `reVC/src/extras/vcmodcrew.h`, `reVC/src/extras/vcmodcrew.cpp`,
  `reVC/utils/test_vc_crew.py`.
- Modified: `reVC/src/core/Game.cpp`, `src/core/PlayerInfo.cpp`, `src/core/re3.cpp`,
  `src/extras/vcmodkeys.{h,cpp}`, `src/extras/vcmodpanel.{h,cpp}`,
  `src/peds/Ped.cpp`, `src/peds/PlayerPed.cpp`, `src/vehicles/Automobile.cpp`,
  `src/control/CarAI.cpp`, `src/control/CarCtrl.cpp`, `README.md`,
  `utils/test_vc_adrenaline.py`, `test_vc_character.py`, `test_vc_driver.py`,
  `test_vc_keys.py`, `test_vc_passenger.py`.
- Docs: this file. `docs/specs/2026-11-10-vercetti-crew-design.md` and
  `docs/plans/2026-11-10-vercetti-crew.md` were already uncommitted before this
  session.

Not this session's — the cockpit/first-person work already in the tree; leave it
alone: `src/core/Cam.cpp`, `src/core/Game.cpp` (its own hunks), `src/renderer/Renderer.cpp`,
`src/extras/vcmodfirstperson.{cpp,h}`, `utils/test_vc_firstperson.py`.

## Play checks (the owner's)

1. `V` away from cars in a clear street: the car arrives with a driver, stops,
   `V` again dismisses.
2. `F` on the stopped crew car: the driver steps out, Tommy takes the wheel, the
   ex-driver takes a rear seat; no carjack, no wanted star.
3. `P` on the crew car: Tommy rides; with a crew man at the wheel, `RIDE TO` is
   followed and the arrival parks the car.
4. Empty the driver's seat (or call while a man is out) then `P`: one man takes the
   wheel and the rest board.
5. Get out: the men follow on foot, fight with him, take free seats in other cars.
6. `V` on foot: they stop being followers and walk off as a gang; `V` again calls a
   fresh crew.
7. Die with the crew out: the men go on as a gang and do not flee. Do not test this
   on a save you mind losing.
8. Panel: `CALL CREW`, `CREW CAR` (list on the four-door shelf), `PASSENGER MODE`
   gone from DRIVING; KEYS shows `CALL CREW KEY` `V` and `PASSENGER KEY` `P`.
9. `reVC.ini` keeps `KeyCrew`, `KeyPassenger`, `CrewCar`; `PassengerMode` is no
   longer read.
10. With the crew out on foot, the men walk and idle in their own gang style, not
    Tommy's; they still follow him.

Known limit, unchanged by this work: the save writer does not store the leader
link, so a save taken with the crew out reloads the men leaderless.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` — game
  data is read-only.
- The cockpit/first-person files listed above.
- `gta-vc-dream-mod/` (generated by `scripts/publish.sh`).
- No commits, tags or pushes; the owner handles git after playing.
