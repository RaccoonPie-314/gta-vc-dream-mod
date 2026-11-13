# Crew confirmed in play — next: cop behavior extraction

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Latest Dock launcher receipt: installed `vcmods build 362`; checkout counter
also 362. A live reVC process was present during this handoff update (pid
32116); recheck before any install. No build, install, commit, tag or push was
made for this documentation-only update.

On 2026-11-12, the play report was: "all fixed now". The crew work is accepted
and closed; the next topic is cop behavior extraction. Do not reopen the crew
ride, pick-up, cop-defence or chat decisions without a new report or request.
No cop extraction changes were implemented in this update.

Previous round: `2026-11-11-crew-rails-pickup.md`.

## 1. The ride after pick-up: normal by default

Root cause of the ramming report: the live `reVC.ini` holds `RideStyle=1`
(FAST), and the crew read that shared chauffeur setting, so its ride was
`PLOUGH_THROUGH` at cruise 55.

- The crew no longer reads `nVCModRideStyle`. `RIDE STYLE` stays the
  chauffeur's control only, so a stale FAST value cannot defeat the default.
- New crew-only switch `CREW AGGRESSIVE` (DRIVING page, under `CREW CAR`), ini
  key `CrewAggressive`, default off, `bVCModCrewAggressive` in
  `src/extras/vcmodcrew.cpp`. Kept out of the master sweep (`aVCModSwitched`),
  like NPC DOOM AIM.
- Off (`VCModCrewApplyStyle`): `STOP_FOR_CARS`, rails where a route exists,
  cruise 18 to a zone / 15 with traffic (civilians cruise 9–18). Queues, obeys
  red lights.
- On: `STATUS_PHYSICS` + `DRIVINGSTYLE_AVOID_CARS`, cruise 40 / 35. AVOID_CARS
  steers round cars (`FindAngleToWeaveThroughTraffic`) and has no light check.
  It is blind to buildings like every stock style — contact is still possible;
  do not describe it as collision-free.
- Live toggle (`VCModCrewTickAboard`): when the applied setting differs, the
  style is re-applied in place — no `JoinCarWithRoadSystem*`, no re-seed, the
  mission, route nodes, lane, destination and phase are untouched. Rails → physics
  goes through `CCarCtrl::SwitchVehicleToRealPhysics` (crew guard keeps the
  mission). Back to normal **stays on physics**: the engine never returns a car to
  rails, and `DragCarToPoint` would place it on its lane line in one frame. The
  next ride issue (zone change, re-board) uses rails again. Skipped while the car
  is parked (`MISSION_STOP_FOREVER`) or Tommy holds the wheel.
- The approach is unchanged (rails cruise 15, runs reds via
  `VCModCrewIgnoresLights`).

## 2. The far pick-up stop

Telemetry in the current log (3 stops; earlier builds' lines are gone): Tommy
was 9.1, 12.2 and 23.5 m from the chosen node. In the stationary case Tommy
never moved and the node was 13.8 m from him; at one summon the nearest node was
24.8 m away. Nodes sit 20–40 m apart along a road that passes much closer.

- `VCModCrewPickupPoint` now projects Tommy onto each enabled link of the
  nearest node and returns the nearest point on the road; a node with no links
  returns the node as before. The point is on the link's centre line, the same
  line the old node target sat on.
- Retarget compares pick-up points, not Tommy's distance to one: every 3 s the
  point for where he stands is recomputed and the car re-routed only if it moved
  more than 10 m (was: Tommy > 20 m from the point). A man standing off the road
  no longer re-routes the car to the same point repeatedly.
- The stop ring is unchanged in size (6 m to Tommy, 5 m to the point); the
  constant is renamed `VCMOD_CREW_PICKUP_POINT_NEAR`. When Tommy stands far off
  any road the car stops at the road point — as close as it can come.

## Verification (offline)

- `utils/test_vc_crew.py` — 27 OK, six new: normal default with a stale FAST
  RideStyle, aggressive from the start, both toggle directions preserving route /
  lane / position / curve timing / phase, Tommy at the wheel untouched, panel+ini
  wiring, road-point projection (beside, clamped, nearer link, closed road, no
  links), and point-based retarget.
- Every `utils/test_vc_*.py` harness OK. `test_vc_passenger.py` row count and
  DRIVING order updated; `test_vc_adrenaline.py` and `test_vc_character.py` gained
  the flag stub.
- Clean build; installed binary carries `CrewAggressive` / `CREW AGGRESSIVE`.

## Play acceptance (2026-11-12)

The crew fixes are confirmed by the "all fixed now" report. The accepted work
is normal post-pick-up driving, the optional aggressive switch, the nearer
road-point pick-up and the preceding crew fixes. The report is the acceptance
receipt; it does not establish a universal no-collision guarantee in aggressive
mode. The offline results above are the earlier implementation receipt, not a
new test run in this handoff update.

The normal default, live toggle transitions and road-point pick-up are no
longer waiting for approval or another play round. Keep the implementation.

## Uncommitted

Crew files from earlier rounds plus this round: `src/extras/vcmodcrew.{cpp,h}`,
`src/extras/vcmodpanel.cpp`, `src/core/re3.cpp`, `utils/test_vc_crew.py`,
`utils/test_vc_{passenger,adrenaline,character}.py`. The wider tree still carries
the street-idle / lock-on / passenger / gang work from earlier handoffs.

## Next topic: cop behavior extraction

The next session moves to native cop behavior extraction for NPC mode, not
more crew changes. Start from current source: the older NPC handoff
`2026-11-11-npc-mode-full-ai.md` called the cop profile "full" but explicitly
excluded arrest/pursuit. Its claim that gangs are plain CPed is also stale;
`CPopulation::AddPed` constructs CCivilianPed for gang types.

Verified current entry points:

- `src/peds/Ped.cpp:1991` — `CPed::CopPatrolScan(uint32& hassleTimer)`, already
  shared. It selects nearby criminal/gang targets and hassles wandering peds.
- `src/peds/CopPed.cpp:527` — native cops call that same patrol scan.
- `src/peds/PlayerPed.cpp:1713` — the COP profile dispatches only
  `player->CopPatrolScan(nVCModNpcHassleTimer)` in its profile-specific branch.
  That is not a full extraction of CCopPed behavior.
- `src/peds/CopPed.cpp:309` — `CCopPed::CopAI`, still native. It reads
  `FindPlayerPed()->m_pWanted` and targets the player or their vehicle. Calling
  it unchanged on Tommy would make the player their own suspect.
- `src/peds/CopPed.cpp:549` — `CCopPed::ProcessControl`, the native orchestration
  to compare against the NPC-mode driver.
- `src/peds/CopPed.h` — cop-owned state and methods: pursuit, arrest, crime scan,
  heli SWAT, stinger and the cop subtype. Inventory their dependencies before
  deciding what can be shared or needs separate state.
- `utils/test_vc_cop_patrol.py` — existing real-function patrol harness;
  `utils/test_vc_npcmode.py` covers the mode driver. Extend current harnesses,
  do not mistake patrol coverage for coverage of the complete cop state machine.

Next steps:

1. Inventory native cop routines, state, targets and caller order; compare with
   the existing COP profile. Report what is already shared, what remains native
   and what is target-specific before proposing an extraction boundary.
2. Confirm the intended cop behavior set and target rules. No specific new
   arrest, wanted, vehicle, SWAT or stinger behavior was selected in this
   handoff request. Preserve PLAYER1 and normal player systems; do not solve
   self-targeting by swapping Tommy's ped type or casting CPlayerPed to CCopPed.
3. Extract the agreed native path in testable slices, with native cops and
   NPC-mode Tommy using the same routine where appropriate. Run regression
   harnesses and build, then verify in play. Keep crew and gang behavior intact.

The unrelated traffic stop-light deadlock is still undiagnosed and is not the
next task.

## Paste-ready prompt

Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 362.
Read `docs/handoff/2026-11-12-crew-ride-style-and-pickup.md` first. The crew fixes
are confirmed in play and closed; next is cop behavior extraction for NPC mode.
Start with native CopAI/ProcessControl/state inventory versus the current shared
CopPatrolScan, then agree target rules before extracting. All source changes
remain uncommitted, including crew, gang and NPC-mode work. A game session was
live at handoff; recheck before installing. Game data/settings/savegames are
read-only, and the immutable animation files must not be touched.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Never install while
`pgrep -f "reVC.app/Contents/MacOS/reVC"` returns anything. Crew ownership and
chat are unchanged by request; keep them so.
