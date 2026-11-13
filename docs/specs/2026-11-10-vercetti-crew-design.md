# Vercetti crew: call, ride, entourage

Status: design, awaiting review.

## 1. Goal

A summonable Vercetti crew: three gang members in a four-door car, driven either by
one of them or by Tommy, who follow Tommy on foot and fight with him. It is the
chauffeur feature with a crew instead of one driver, and a stock gang instead of a
single follower.

The feature must feel like the game's own gang setup, not a scripted minigame:
summon, ride, get out, walk, fight, and walk away when dismissed.

## 2. What the engine already provides

Verified in this tree, not assumed:

- There is no cheat for this. `CPad::AddToPCCheatString` (`src/core/Pad.cpp:1297`)
  carries every cheat this build knows, and none recruits a gang. The nearest is
  `HOPINGIRL` (`src/core/Pad.cpp:144`), which puts one nearby ped in the car.
  Recruit-anyone is a San Andreas cheat. Nothing can be switched on.
- A complete entourage AI exists: `CPed::SetLeader` (`src/peds/Ped.cpp:9164`) plus
  `CPed::UpdateFromLeader` (`src/peds/PedAI.cpp:598`). A follower walks to the
  leader while the leader is on foot, boards the leader's car when the leader is
  driving and a passenger seat is free (`:652`), leaves when the leader leaves,
  attacks the leader's look target while the leader attacks (`:664`), waits when
  the leader is more than 30 m away (`:612`), and flees when the leader dies
  (`:631`).
- Street gangs are built with the same fields: `CPopulation::PlaceGangMembersInFormation`
  (`src/peds/Population.cpp:1439`) spawns a leader, gives him a wander path and
  `bIsLeader`, and gives the rest `SetLeader` plus
  `OBJECTIVE_FOLLOW_CHAR_IN_FORMATION` (`:1470`, `:1495`).
- The Vercetti gang is `PEDTYPE_GANG7`, models `PGA`/`PGB`
  (`src/peds/Gangs.cpp:30`). The engine hardcodes that they never register Tommy as
  a threat (`src/peds/PedAI.cpp:5445`), gives followers the player's anim group
  (`src/peds/Ped.cpp:654`) and the player's radio station on `PGA`/`PGB`
  (`src/peds/Ped.cpp:9379`).
- The gang spawner already arms gang peds from `CGangInfo`
  (`src/peds/Population.cpp:420` and the GANG1..9 case), so a GANG7 ped made by
  `CPopulation::AddPed` is a real Vercetti member, not a civilian wearing the model.
- The car is our choice: the game never assigned the Vercetti gang one
  (`SetGangVehicleModel(GANG_PLAYER, -1)`, `src/peds/Gangs.cpp:38`). The Cubans get
  the Hermes, Haitians the Voodoo, Streetwangs the Gang Burrito, Bikers the Angel.
- Seats come from doors: `GetMaximumNumberOfPassengersFromNumberOfDoors`
  (`src/modelinfo/VehicleModelInfo.cpp:1177`) returns `doors - 1`, so a four-door car
  has three passenger seats. Three crew plus Tommy is exactly four seats.

The feature is assembly plus a trigger; the AI is stock. The work is the car
choreography, the handovers, and the cleanup.

## 3. Decisions

| Question | Decision |
|---|---|
| Crew | 3 `PEDTYPE_GANG7` men, `PGA`/`PGB`, M4 each, `MISSION_CHAR` while serving |
| Car | Admiral default; a `CREW CAR` row lists every 4-door car this install loads |
| Call | `CREW` key, default `V`, plus a `CALL CREW` panel action |
| I drive | the stock enter control (F by default) on the crew car: the driver yields the seat |
| I ride | `PASSENGER` key, default `P`, global on every car, driver or not |
| F on other cars | stock behaviour, carjack included |
| Dismissed crew | leadership handed to one member; they stay a gang, the world may reclaim them at distance |
| Tommy dies | same handover at the moment of death; they do not flee |
| `PASSENGER MODE` row | retired; the `PASSENGER` key replaces it |

## 4. Behaviour

### 4.1 Call

`CREW` key or the `CALL CREW` row.

- Not in control (`!IsPedInControl()`) or an active crew already being boarded:
  the key does nothing beyond the existing state.
- A crew is active: the press dismisses it (section 4.6).
- Tommy is in any vehicle: notice `crew: get out first`, nothing else. This is the
  chauffeur's rule.
- Otherwise summon.

Summon requests and loads, in this order: the chosen car model, `MI_M4`,
`MI_PGA`, `MI_PGB`. A model that does not load aborts with a notice naming it.

The car spawns on a car path node behind Tommy, 80 m out, the chauffeur's
`VCModRideSpawnLimo` geometry (`src/peds/PlayerPed.cpp:668`), with its fallbacks:
the nearest node to Tommy within 60 m, then within 200 m. No node: `crew: no road
to come from`.

Three men are made with `CPopulation::AddPed(PEDTYPE_GANG7, model, pos)`, the model
picked with `CGangs::ChooseGangPedModel(GANG_PLAYER)`. Each gets:

- `CharCreatedBy = MISSION_CHAR`, `bIsPlayerFriend = true`,
  `bStayInCarOnJack = true`
- `GiveDelayedWeapon(WEAPONTYPE_M4, 25001)` and the M4 weapon slot, after the
  `CGangs` delayed weapon the spawner gave them
- no leader link yet; the link is attached when he is seated with Tommy (§5.2)

The men are seated with `CPed::WarpPedIntoCar` (`src/peds/Ped.cpp:9392`): the first
with `OBJECTIVE_ENTER_CAR_AS_DRIVER`, the next two with
`OBJECTIVE_ENTER_CAR_AS_PASSENGER`. The warp reads the objective, so the order
matters: a passenger objective on the first man leaves the driver seat empty.

The car is `MISSION_VEHICLE`, counted in `CCarCtrl::NumMissionCars`, put through
`CTheScripts::ClearSpaceForMissionEntity`, placed on the road, physics status, and
bliped with `BLIP_CAR` for the approach.

### 4.2 Approach and pick-up

The driver is a normal AI ped on `MISSION_GOTOCOORDS` to Tommy's position, using
the shared `RIDE STYLE` (`VCMOD_RIDE_SAFE` / `VCMOD_RIDE_FAST`, the chauffeur's
`VCModRideApplyStyle`).

- If Tommy moves more than 20 m, the target is refreshed, at most once every 3 s.
- Within 15 m the car stops (`MISSION_STOP_FOREVER`, cruise 0) and the phase becomes
  pick-up. Notice: `your crew is here`.
- If Tommy wanders more than 120 m from the stopped car, the crew is stood down and
  the car removed (the chauffeur's abandon rule).
- If Tommy gets into another car, the crew is stood down.

### 4.3 Boarding

The car arrives with a driver, as asked. The two rear men stay in the car.

| Press | Car state | Result |
|---|---|---|
| stock enter (F) | crew car, driver seated | the driver gets out, Tommy takes the wheel, the driver takes the free seat |
| stock enter (F) | crew car, empty | stock driver entry |
| `PASSENGER` (P) | any car, free seat | Tommy boards as a passenger, driver or not |
| `PASSENGER` (P) | crew car, empty | Tommy boards passenger; one crew man takes the wheel, the rest board |
| stock enter (F) | any other driven car | stock carjack |
| stock enter (F) | any other empty car | stock driver entry |
| stock enter (F) | summoned chauffeur limo | passenger, as today |

**F never carjacks the crew.** Every enter press on the crew car is intercepted
before the stock driver entry. While the driver is seated the press is consumed and
the player's driver objective is issued only after `car->pDriver == nil`; there is
no room in the sequence for the carjack state.

The swap is a small phase:

1. `F` in pick-up: the driver is ordered `OBJECTIVE_LEAVE_CAR` and his leader link is
   cleared for the duration, so he does not walk off toward Tommy. Notice: `the
   driver is getting out`.
2. The phase waits for `car->pDriver == nil` and the ex-driver not `bInVehicle`
   (`m_pMyVehicle` is set while a ped is still walking to a door, the chase lesson).
3. When clear, Tommy is issued `OBJECTIVE_ENTER_CAR_AS_DRIVER`; the ex-driver is
   given `OBJECTIVE_WAIT_ON_FOOT` with a timer.
4. Abort on 6 s without a clear seat, or if Tommy moves more than 10 m away: the
   ex-driver is ordered back into the driver seat and the phase returns to pick-up,
   with a notice. No carjack is ever started.
5. When Tommy is aboard, the ex-driver is re-linked to him and ordered
   `OBJECTIVE_ENTER_CAR_AS_PASSENGER`; there is exactly one free seat.

`bStayInCarOnJack` on all three is what keeps the two rear men from being ejected by
`PedSetInCarCB` (`src/peds/Ped.cpp:4382`) when Tommy takes the wheel.

### 4.4 Riding

- Tommy driving: no AI touches the wheel. The three men ride; the stock leader AI
  is idle while they are in vehicle states (see 5.2).
- A crew man driving: the car follows the `RIDE TO` zone exactly like the chauffeur
  (same destination list and style rows), or cruises when no zone is set. Changing
  `RIDE TO` re-routes. Arriving at the destination stops the car and keeps the ride
  open; getting out ends it. The mission is issued when Tommy boards as a passenger
  (the car is held stopped during pick-up), including after the empty-car fill.
- Tommy leaves the car: every crew man leaves with him (stock leader rule) and the
  phase becomes escort. The car stays parked where it was left.

### 4.5 On foot

Nothing custom. The three are leader-followers of Tommy, so they walk to him, wait at
30 m, leave and board cars as he does, attack whoever he attacks, and react to
threats the stock way. There is no car gunner and no driving-by: the crew fights on
foot only.

If Tommy enters another car, the men take free passenger seats and the ones who do
not fit follow on foot. If he drives off, they wait at their 30 m leash.

### 4.6 Dismiss

`CREW` again, or the panel row. The crew is handed to the street:

- A random living member becomes the leader: `ClearLeader` on all three, then the
  chosen man gets `SetObjective(OBJECTIVE_NONE)` and a wander path, and the others
  get `SetLeader(newLeader)`, `OBJECTIVE_FOLLOW_CHAR_IN_FORMATION` and a formation
  slot, the fields `PlaceGangMembersInFormation` uses for a street gang.
- A kill objective they are already on is kept; only a flee is replaced by the group
  order. `bIsPlayerFriend` and `bStayInCarOnJack` are cleared.
- `CharCreatedBy` becomes `RANDOM_CHAR`. They do not disappear on dismissal: they
  stay a led gang near Tommy. The flag only lets the world reclaim the group once it
  is far away and off-screen, exactly like any other street gang (`CanBeDeleted`,
  `src/peds/Ped.cpp:4529`). The mod never removes a living dismissed man itself: no
  timer, no distance check of ours. While the group is near Tommy it stays, whatever
  the pool thinks; only the engine's own far-and-off-screen reclaim can take it.
- Dead members are removed from the pool; a mission ped is never reclaimed by the
  world, so the corpse would otherwise be permanent. That is the only removal the
  mod does.

If Tommy is in the crew car at dismissal, the car is stopped, the three are ordered
out, and the handover happens once they are clear. The car is then deleted if nobody
is in it, or handed back to traffic if Tommy is (`VehicleCreatedBy = RANDOM_VEHICLE`,
the counters corrected, the blip cleared, never a delete with the player inside).

### 4.7 Tommy dies

`CPed::SetDie` (`src/peds/Ped.cpp:7055`) calls a mod hook once for the player, before
the crew's next objective pass. The handover of 4.6 runs there:

- No crew man gets the dead-leader flee, because the leader link is gone before
  `UpdateFromLeader` can see a dead leader.
- Kill objectives in progress are kept; they keep shooting who they were shooting.
- If Tommy dies in the crew car, the car is stopped and the three are ordered out
  first, then handed over.
- The car follows the dismissal rule: delete if empty, hand back if the player's body
  is inside.

Without this hook the stock behaviour is `SetLeader(nil)` plus
`FLEE_ON_FOOT_TILL_SAFE` (`src/peds/PedAI.cpp:631`); stock followers run when their
leader dies.

### 4.8 Failure states

- Car destroyed while parked or approaching: the living crew are handed over as in
  4.6, the phase ends, the blip is cleared.
- Driver killed during the approach: the living passengers are handed over; the car
  is left as it is.
- All three dead: the phase ends; the car is cleaned up.
- Seat taken between the press and the objective, door never opens, objective stolen
  by another system: the existing boarding watchdog pattern applies (15 s), then
  stand down or abort, with a notice.
- Pool slot recycled (the car or a man is gone): the stored index is validated by
  looking the ped up and checking it is a living GANG7; a miss drops the member
  rather than acting on a stranger.

## 5. State machine and invariants

### 5.1 Phases

`NONE -> APPROACH -> PICKUP -> SWAP -> ABOARD -> ESCORT`, plus `DISMISS_WAIT` for a
dismissal while Tommy is in the car.

| From | Event | To |
|---|---|---|
| NONE | call | APPROACH |
| APPROACH | car within 15 m | PICKUP |
| APPROACH | player enters another car / 120 m / car gone | NONE |
| PICKUP | stock enter | SWAP |
| PICKUP | `PASSENGER` | ABOARD (passenger) |
| SWAP | seat clear | ABOARD (driver) |
| SWAP | 6 s / player walked away | PICKUP |
| ABOARD | player leaves the car | ESCORT |
| ESCORT | player boards the crew car again | ABOARD |
| any | dismiss | NONE (or DISMISS_WAIT) |
| any | player death | NONE |

### 5.2 Leader links

The leader link is what makes the crew follow, board and fight, and it is cheap, but
`UpdateFromLeader` has two rules that matter. Its on-foot leave/board logic is
inside `if (IsPedInControl())`, and `IsPedInControl` is false for `PED_DRIVING` and
`PED_PASSENGER` (`src/peds/Ped.cpp:3893`), so an in-car man is immune to that half.

The other half is `else if (bInVehicle)` (`src/peds/PedAI.cpp:733`): a follower
seated in a car whose leader is on foot is ordered `OBJECTIVE_LEAVE_CAR` 250 ms
later, and once he is outside, a leader more than 30 m away makes him stand and
wait. A man in a vehicle is therefore **not** immune while the leader is on foot.

That fixes when the link may be attached: not at spawn, because the car comes from
80 m away while Tommy stands on the kerb. Each man is linked when he is seated with
Tommy in the crew car (the aboard pass), the ex-driver when he takes the rear seat
after the F swap, and the links stay through the ride and the escort.

The real conflict is the opposite case: a man on foot, Tommy riding as a **passenger**
of the crew car (not driving). `UpdateFromLeader` then keeps ordering
`OBJECTIVE_GOTO_CHAR_ON_FOOT` at the car and would stomp a boarding order. So while
the player is a passenger of the crew car and the men are walking to it, their leader
links are cleared and the boarding objectives are ours; each man is re-linked when he
is seated. In every other configuration the links stay.

### 5.3 Other invariants

- `aboard` means `player->bInVehicle && player->m_pMyVehicle == car`. The car pointer
  alone is set while Tommy is still walking to a door.
- The car is mission-owned from spawn to dismissal/death; only then does its class
  change. It is never deleted while the player is inside.
- The blip exists only between spawn and pick-up.
- A car model is only accepted for `CREW CAR` if it is a car with
  `GetMaximumNumberOfPassengersFromNumberOfDoors >= 3`. A saved value that fails this
  on load falls back to the Admiral.
- The three crew handles and the car handle are pool indices, checked every use.
- No engine AI is added: every order is an existing objective.

## 6. Files and touch points

New:

- `reVC/src/extras/vcmodcrew.h`, `vcmodcrew.cpp` — summon, phases, boarding, handover,
  telemetry. Sources are globbed by `src/CMakeLists.txt` and by
  `addSrcFiles("src/extras")` in `premake5.lua`, so both builds pick the file up.
- `reVC/utils/test_vc_crew.py` — the state tests.

Changed:

- `src/core/Game.cpp` — `VCModCrewUpdate()` beside the chase/spawn ticks (`:942`).
- `src/peds/PlayerPed.cpp` — the enter hook (`VCModPassengerEntry`, `:522`) becomes the
  crew/summoned-limo entry; the `PASSENGER` key poll in `ProcessControl` (`:3729`);
  the passenger-ride helper accepts the no-driver case.
- `src/core/PlayerInfo.cpp:392` — call site name.
- `src/peds/Ped.cpp:7055` — the player-death hook in `SetDie`.
- `src/extras/vcmodpanel.cpp/.h` — rows, `CREW CAR` list, remove `PASSENGER MODE`.
- `src/extras/vcmodkeys.cpp/.h` — two keys.
- `src/core/re3.cpp` — ini reads: `CrewCar`, `KeyCrew`, `KeyPassenger`; remove
  `PassengerMode`.
- `utils/test_vc_passenger.py` — mode tests become key tests; row assertions.
- `utils/test_vc_character.py:911`, `utils/test_vc_keys.py` — row and key counts.
- `README.md` — driving section, key list, passenger key replaces the mode.

## 7. Panel, keys, ini, notices

DRIVING page gains, above `CALL DRIVER`:

- `CALL CREW` — summons, or dismisses an active crew (the `CALL DRIVER` action row's
  pattern).
- `CREW CAR` — a scrollable list of every 4-door car this install loads, current
  model named in the cell, persisted as `CrewCar`.

KEYS page gains:

- `CALL CREW KEY` — `VCKEY_CREW`, default `V`, ini `KeyCrew`.
- `PASSENGER KEY` — `VCKEY_PASSENGER`, default `P`, ini `KeyPassenger`.

Notices, phrased like the existing ones: `your crew is on the way`, `your crew is
here`, `the driver is getting out`, `crew dismissed`, `crew: get out first`,
`crew: no road to come from`, `crew: the M4 cannot be loaded`, `crew: the <car model>
cannot be loaded`, `crew: nobody to drive this`, `crew: every seat taken`,
`passenger: no seat in this`, `passenger: that car is wrecked`, `passenger: no car
nearby`.

## 8. Retiring PASSENGER MODE

The key makes the row redundant, and the row's job (turn F into a passenger press)
is the behaviour being removed. The change is:

- `bVCModPassengerMode` and its row, ini read and test assertions come out.
- The summoned limo still owns its enter press and still boards as a passenger; that
  is the personal-driver feature and is unchanged.
- The passenger ride code keeps the held-car handback, because `PASSENGER` on a
  driven street car still stops the car for boarding and still gives it back if the
  boarding is abandoned.

The `PASSENGER` key is global, and driver-less is allowed: no seat means a notice,
but there is no "someone must be driving" check. A passenger seat, a rideable
vehicle (not plane, heli or train, not wrecked), and Tommy on foot are the only
requirements.

## 9. Telemetry

`VCMOD CREW` lines on stderr, the chase's pattern:

- one line per transition (`summon car %p model %s crew %d`, `swap start/abort/done`,
  `board done seat %d`, `dismiss`, `handover leader %d`, `player died`, `cleanup car
  %p`)
- a once-per-second state line (`phase`, car pointer, seat, driver
  `player|crew|none`, living crew, speed, position).

The harness asserts on these; the handoff can quote them.

## 10. Tests

`utils/test_vc_crew.py` in the house style (extract the module's functions, compile
against stubs, assert events), covering:

1. `CREW` refusal while in a vehicle; summon model requests; no-model, no-road and
   no-room failures; car model, mission ownership, blip, seat count.
2. The F swap: driver `LEAVE_CAR`, no carjack objective, player driver objective only
   after the seat clears, abort on timeout/walk-away, re-seat on abort.
3. The `PASSENGER` key: nearest-car choice, free-seat refusal, wreck/plane/train
   refusal, no-driver boarding, the crew-car fill (one man to the wheel, rest to
   seats).
4. Leader links: set at spawn; cleared only for the passenger-riding boarding case;
   restored when seated.
5. Escort: leaving the car orders `LEAVE_CAR`; re-boarding orders passenger seats.
6. Dismissal: new leader, formation on the other two, `RANDOM_CHAR`, living men left
   in the world (no despawn of ours, near or far), dead members removed, car
   delete/handback rule.
7. Death: handover, no flee, kill objective kept, car rule.
8. Panel/keys/ini: `CALL CREW` and `CREW CAR` present, `PASSENGER MODE` absent, 11
   key slots with `V`/`P` defaults, the new ini names, saved car validation.

Updated suites: passenger (mode removed, key behaviour added), character (row
assertion), keys (slots and defaults).

Build: `scripts/build.sh` on this machine, then `scripts/install.sh` into
`~/Games/VC` only with no session running. Play verification is the user's; the
harness proves the state table, not the feel.

## 11. Risks and limits

- The crew carries M4s. A fight escalates, cops respond, and the wanted level is
  normal. That is the requested loadout, not a bug.
- Dismissed gangs stay until the world reclaims them at distance; they never despawn
  in front of Tommy. A player who keeps them nearby keeps them, and repeated recalls
  in one spot can gather several crews.
- The save writer stores ped position, class, health, armour and weapons, not the
  leader link (`src/peds/Ped.cpp:9648`). A save taken after a handover reloads the
  men as leaderless gang peds standing where they were; they will not regroup. Save
  support is not part of this change.
- Interiors are separate worlds; the crew waits outside, as stock followers do.
- A driver killed mid-approach leaves a parked car and two passengers; handing them
  over is the graceful outcome, not a replacement driver.

## 12. Out of scope

- Car gunner or drive-by passengers.
- Recruiting street gang peds; only the three summoned men.
- Formation spacing changes to the stock follow.
- Interiors, save/restore, respawns, multiple concurrent crews.
- Any cheat string.

## 13. Delivery

The change ships when the Dock-launched build runs it: `scripts/build.sh`,
`scripts/install.sh` into `~/Games/VC`, no session running. Windows stays supported:
the module is platform-neutral, the keys are ASCII, the assets are the mod's own.
`README.md` documents the new keys and the retired row. The session ends with a
handoff in `docs/handoff/` and a paste-ready prompt.
