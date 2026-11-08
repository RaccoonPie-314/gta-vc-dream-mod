# SWAT Chase Mod — Design Spec

Status: draft for review
Date: 2026-11-07
Target: reVC `miami` `a26fff4`, branch `vcmods`, distributed as `vc-mods.patch`

## 1. Summary

A native mission system for playing the police response instead of the wanted suspect. The v1 mission, **The Getaway**, launches from a pink marker at the police station, lets the player choose a ground or air approach, and runs a pursuit against an NPC criminal with a purpose. A rank ladder unlocks five tiers — patrol, SWAT, Vice, FBI and Army — each with its own uniform, vehicles, squad and finite force pools.

The same director is intended to drive a mirrored criminal mode later, where the player is the suspect and the stock wanted ladder escalates from police to helicopter to SWAT to FBI to Army.

## 2. Goals

- Play as the responder: air insertion with a climb and a rappel, ground pursuit, and an AI squad.
- Give the criminal a goal: a route with stops and a finale, not aimless fleeing.
- Scale difficulty by force size and reinforcements, never by health or damage multipliers.
- Persist rank across sessions without changing the savegame format.
- Stay patch-only: no SCM edits, no Rockstar data edits, no savegame changes.
- Leave no trace: the uniform, animation, spawned units, blips, vehicles and markers are all restored or removed on end.

## 3. Non-goals for v1

- Player gunner seat. The handheld and mounted variants are deferred.
- Player-initiated arrest/cuff. "Stopped" means down.
- Criminal mode. Designed in section 6.9, implemented after v1.
- Mission interiors. The bank interior is out of scope.
- Multiplayer.

## 4. What the engine already provides

- Wanted ladder and caps: `src/core/Wanted.cpp:52` (`AreSwatRequired`, `AreFbiRequired`, `AreArmyRequired`), `:71` (`NumOfHelisRequired`), `:311` (`UpdateWantedLevel`: max cops, law-enforcer vehicles, roadblock density). 3 = VCPD + heli, 4 = SWAT, 5 = FBI, 6 = Army.
- Police heli: `CHeli` is AI-only, locked and pilotless (`src/vehicles/Heli.cpp:124`, `:793`). It fires on a star-scaled timer (`:480`) and rappels up to four SWAT (`:721`).
- Flyable heli: any real heli spawned as `CAutomobile` uses `FlyingControl` (`src/vehicles/Automobile.cpp:1417`). The Hunter is the only heli with built-in weapons, pilot-fired (`:1465`, `:1492`).
- Ropes: `CRopes::RegisterRope`, `FindCoorsAlongRope`, eight-rope pool (`src/core/Ropes.cpp:103`, `:147`). The SWAT descent is `CCopPed::ProcessHeliSwat` (`src/peds/CopPed.cpp:811`), with `PED_ABSEIL` and `ANIM_STD_ABSEIL`.
- Ped objectives: flee on foot, flee in car, kill target, go to target, enter/leave car (`src/peds/Ped.h:195-242`). Target-agnostic car ram/block helpers (`src/control/CarAI.cpp:637`, `:646`).
- Cop factions: `eCopType` has street, FBI, SWAT, heli SWAT, Army, Miami Vice (`src/peds/CopPed.h:5`). `IsPolicePedModel` recognizes SWAT, FBI and Army (`src/modelinfo/ModelIndices.h:592`).
- Presentation: cylinder markers and arrow markers via `C3dMarkers::PlaceMarkerSet` (`src/renderer/SpecialFX.h:120`, used by script at `src/control/Script4.cpp:1520`); radar blips via `CRadar::SetCoordBlip` / `SetEntityBlip` (`src/core/Radar.h:277`).
- Character swap: `VCModApplyPedModel` streams and validates the ped, takes the model's animation group, keeps `PEDSTAT_PLAYER`, re-attaches the weapon and pins the model (`src/peds/PlayerPed.cpp:257`). The animation picker wins when NPC ANIMATION is on (`:868`).
- Passenger/car ownership: the mod already spawns, drives, routes and blips mission cars.

## 5. Experience flow (v1)

1. A pink cylinder marker and radar blip sit on the VCPD HQ forecourt (`405.97 -468.07 10.11`), always present in free roam.
2. Entering it opens the tier picker, limited to unlocked ranks, then a briefing.
3. Two approach markers appear: the garage for the ground start, a street marker under a hovering Maverick for the air start.
4. Ground: the player boards or drives the tier's transport (cruiser, Enforcer, Vice car, Rancher or Barracks) with the AI squad.
   Air: the player and the AI squad climb ropes into the hovering Maverick, which flies to the scene, then rappels down.
5. The leader is already fleeing the robbery. The route has three beats: car swap, accomplice pickup, marina boat.
6. Pressure rule: the leader only completes a stop when no SWAT is within about 25 m with line of sight. Otherwise he skips to the next beat.
7. Finale: the leader starts a boat. If it reaches open water, the mission fails.
8. Win: the leader is stopped before that. Reward, rank up, marker returns.

## 6. Systems

### 6.1 Mission state machine

`IDLE` (marker visible) -> `TIER_SELECT` -> `BRIEFING` -> `APPROACH` -> `BOARDING` -> `RUNNING` -> `END` -> cleanup.

- Repeatable; no state is written to the savegame.
- Cleanup runs on win, fail, death, arrest, load and manual cancel.
- If the player is not in control when cleanup runs, model restoration and despawns are queued and retried on respawn.

### 6.2 Rank, tiers and uniforms

| Rank | Squad | Player model | Ground | Air | AI squad |
|---|---|---|---|---|---|
| 1 | VCPD patrol | `MI_COP` | Police cruiser | Maverick | `COP_STREET` |
| 2 | VCPD SWAT | `MI_SWAT` | Enforcer | Maverick | `COP_SWAT`, `COP_HELI_SWAT` |
| 3 | Vice squad | `MI_VICE1` | Cheetah/Stinger | Maverick | `COP_MIAMIVICE` (modifier 0-7 picks `MI_VICE1..8`) |
| 4 | FBI | `MI_FBI` | FBI Rancher | Maverick | `COP_FBI` |
| 5 | Army | `MI_ARMY` | Barracks/Enforcer | Hunter | `COP_ARMY` |

- The uniform is applied at tier selection, while the player is on foot.
- VICE has eight outfits (`MI_VICE1..8`). Pressing its key again while VICE is already selected cycles to the next outfit, wrapping after the eighth; the notice names the variant.
- `VCModApplyPedModel` is the swap path. It already resolves the model's animation group through `VCModPedAnimGroupFor` (`src/extras/vcmodpanel.cpp:298`) and rejects unplayable groups.
- The mission saves the pre-mission model, the `bVCModPlayerNpcAnims` toggle and the pinned model request.
- While the mission runs, the NPC animation picker is forced off so the squad's own animation group applies. It is restored afterwards.
- The AI squad spawns with the faction's cop type, which supplies its model and weapons.
- Rank 5's air choice is the Hunter, whose pilot weapons are already implemented. Under an AI pilot it is transport only; the guns are pilot-fired, so they matter if the player takes the controls later.
- Rank persists in `reVC.ini` under `[VC Mods]`, for example `SwatRank=2`. It must not touch the savegame.

### 6.3 Director

One module owns the scenario:

- The leader (`CPed*` + vehicle), the route state machine, the pressure checks, the two force pools, all spawned units, blips and cleanup.
- A target abstraction pointing at the leader, so units and the heli do not have to target `FindPlayerPed()`.
- Mission-owned cars and peds are tagged so traffic, population and save logic do not adopt them.
- The stock wanted system is not used on the cop side; the player stays at zero stars and the squad is driven with explicit objectives.

### 6.4 The Getaway

- Opening: an armed robbery is already in progress or just finished; the leader is fleeing when the mission starts.
- Beat 1, the swap: the leader pulls into a parking lot and abandons his sedan for a faster parked car.
- Beat 2, the pickup: the leader stops at a motel and an accomplice joins as passenger.
- Beat 3, the marina: the leader abandons the car, runs to a boat, and starts it.
- Pressure: a stop is skipped when any SWAT is within about 25 m with line of sight. Skipped stops are not retried.
- Disabled car: the leader continues on foot. If the next beat is close, he runs; otherwise he stands and fights.
- The leader and the pickup accomplice are armed. Their exact weapons come from the tier.
- The boat takes about ten seconds to start and pull away. The player can damage the boat or kill the leader before it clears the dock.
- Win = leader down. Fail = boat reaches open water, player dies, player is arrested.
- On mission end, surviving crew flee or despawn; the mission does not require clearing them.

### 6.5 Air insertion

- The air start uses a real flyable heli (`CAutomobile`), not the AI `CHeli`, so it has seats, a pilot and player control.
- At the station the heli hovers over a street marker. The player and two AI SWAT climb ropes into it.
- Climb: the same rope sampling and `PED_ABSEIL` state as the descent, with progress running from bottom to top and the animation clip played backwards.
- At the top, each climber is seated; the rope is released and the AI pilot flies to the scene.
- At the scene the same occupants rappel down using the existing descent math.
- The heli holds position while boarding and while dropping. It follows the leader after the drop.
- The pilot is an NPC in the driver seat and uses the stock heli autopilot: `MISSION_HELI_FLYTOCOORS` steered by `CCarCtrl::SteerAIHeliTowardsTargetCoors` (`src/vehicles/Automobile.cpp:691`, `src/control/CarCtrl.cpp:2511`). The director updates the destination each frame to the leader plus an offset, and keeps it fixed while boarding or dropping.
- This autopilot steers directly at the destination and does not pathfind, so fly at a safe altitude and use waypoints over dense blocks. It is not the `CHeli` follow/hover brain, which has no seats and cannot carry anyone.
- Reverse animation requires a small engine change: `CAnimBlendAssociation::UpdateTime` only wraps time forward today (`src/animation/AnimBlendAssociation.cpp:176`). Add a negative-time wrap so a negative speed plays the clip backwards. Fallback if that proves unstable: drive `SetCurrentTime` per frame with a decreasing value.
- Risk to verify early: whether the retail Maverick has passenger seats. The stock SWAT drop uses ropes, not seats, so the seat count has never been exercised.

### 6.6 Ground squad

- The ground start uses the tier's transport: Enforcer, FBI Rancher or Barracks/Enforcer.
- The AI squad uses the matching cop type and weapons.
- The player stays `PEDTYPE_PLAYER`, so the criminal AI targets them like any other SWAT.
- Friendly fire is closed by section 6.10; the squad is marked as mission friends.

### 6.7 Force pools and reinforcements

Two finite pools, one per side. This is the difficulty axis.

| Rank | Squad active / reserve | Crew active / reserve (excludes leader) | Notes |
|---|---|---|---|
| 1 | 2 / 0 | 0 / 0 | patrol tier, leader only, teaching mission |
| 2 | 2 / 2 | 1 / 2 | SWAT tier, the picked-up accomplice plus two reserves |
| 3 | 4 / 4 | 4 / 4 | Vice tier, crew arrives in fast cars |
| 4 | 5 / 5 | 5 / 5 | FBI tier, crew arrives in cruisers |
| 5 | 6 / 6 | 6 / 6 | Army tier, convoy and armed heli |

Rules:

- The table's crew counts exclude the leader; the squad counts exclude the player.
- Each pool has an active cap, a finite reserve and a refill delay (about 5 s for the squad, 8 s for the crew).
- A loss queues a replacement only when active < cap and reserve > 0. The reserve decrements when the replacement spawns.
- Replacements spawn at a road node 80-120 m away, outside the player's view, arrive in a vehicle, then dismount and engage.
- No health, damage or accuracy multipliers. Difficulty comes from numbers, vehicles, and the equipment that comes with the faction cop type.
- The leader and the player are never in a pool and never respawn.
- The mission ends on the leader, not on exhausting a pool. Remaining units despawn or flee.
- If the squad pool is empty, the player continues alone. There is no additional fail for losing the squad.
- HUD shows both reserve counts and announces when a pool is empty.

### 6.8 Win, fail, rewards, repeatability

- Win: leader stopped (down).
- Fail: leader escapes by boat, player dies, player is arrested.
- Reward: money and a rank increase when the tier is cleared.
- On end: result text, cleanup, marker returns. Rank persists in the ini.

### 6.9 Criminal mode (post-v1)

- The player is the criminal and the stock wanted ladder is the difficulty.
- 3 stars brings the police heli, 4 SWAT, 5 FBI, 6 Army, with the existing caps, roadblocks and weapon behavior.
- The mission is an escape: commit the score, then reach a boat or hideout while surviving the tier.
- Rank unlocks higher star floors. The same star vocabulary is shown in both modes: on the cop side it names the threat tier, on the criminal side the literal wanted level.

### 6.10 Friendly fire

- Mission squad peds are spawned with `CharCreatedBy = MISSION_CHAR` and `bIsPlayerFriend = true`. The leader and crew are explicitly set to `false`.
- The flag defaults to true on every ped (`src/peds/Ped.cpp:286`), so a missed assignment would make the crew bulletproof.
- `CPed::InflictDamage` (`src/peds/PedFight.cpp:2678`) gets a team check before any effect: if the victim is the player or a mission friend, and the attacker is the player, the player's vehicle, or a mission friend, return false. The attacker can be a vehicle, so resolve its driver.
- This filters stray squad bullets into the player and player bullets into the squad, and no damage event is raised, so nobody retaliates.
- The existing flag already keeps friends out of the player's aim priority (`src/peds/PlayerPed.cpp:1390`) and out of gang threat propagation (`src/peds/PedAI.cpp:5442`); the damage filter closes the manual-fire case.
- The player's vehicle is a separate path (`CVehicle::InflictDamage`, `src/vehicles/Vehicle.cpp:1126`). Add the same check if squad fire into the player's heli proves possible.
- Test both directions and the ram case: player shoots a squad mate, squad fire crosses the player, a squad car clips the player. Crew damage must still apply normally.

### 6.11 Crimes and purpose

The chase machinery is the same every run; what changes is what the crew did and what they are carrying. A crime is data: a name, a dispatch line, a base threat, a stop pattern, and an optional loot modifier.

- Crime tableau: the crime is staged where the player can see it. At the first stop the crew walks into the shop, the alarm sounds, and they come back out with bags; when the mission opens in view, the same tableau plays at spawn. Stock props, stock alarm samples and existing walk animations, no new art.
- Dispatch line: the briefing and the start notice name the crime and its rating ("bank job, threat rating 4, FBI responding"). The crime's base threat feeds the same response rule as the tier, so the number of cops follows what the crew did as well as the unit the player picked.
- Stop patterns are permutations of the existing stop types: swap, pickup, drop, short stop, and the boat finale. A drop is a stop with no pickup, where the crew leaves something in a parked car or stash and drives on. A short stop is a collection that resolves in a couple of seconds, so pressure can skip it.
- Ordering constraint: a pickup placed before a swap leaves the accomplice in the abandoned car until passengers are transferred, so the first slice keeps swap, pickup, boat.
- Loot is a modifier, not a new system: cash or a crate slows the leader and keeps him out of two-seaters until the handoff, which is why a bank job does not play like a car theft.
- A rival faction is a third car that also wants the leader (gang peds with a chase objective). The player can shadow it, let it soften him up, or get caught between.

| Scenario | Where | The crime | Stops | Twist |
|---|---|---|---|---|
| Store till | 24/7, Washington Beach | clerk hit the alarm, crew out with duffels | swap, pickup, boat | the collection is short, so pressure skips it |
| Jewelry grab | Downtown | smashed window, bags handed on | swap, pickup, boat | the handoff car leaves with the loot |
| Protection round | Vice Point shops | envelope collections | short stops, boat | each stop is brief; the round is the variety |
| Weapons deal | Prawn Island | deal goes loud | pickup, swap, boat | the crate takes a seat |
| Armored truck | Viceport | Securicar hit | swap, drop, boat | the loot slows him until the drop |
| Bank job | El Banco Corrupto Grande | shotguns, alarm, cash bags | swap, pickup, boat | the crew rides with him; losing the crew drops the response a tier |
| Drug plane | Escobar International | cargo off a landed smuggler plane | swap, drop, boat | the drop is timed; miss it and the plane leaves with the shipment |
| Boat transfer | Viceport docks | product from warehouse to speedboat | pickup, boat | two boats, pick the right one |
| Studio smuggling | InterGlobal Films | cargo in film cans | swap, pickup, boat | the prop truck blocks the alley |

- First slice: store till, jewelry grab, protection round, bank job and drug plane, one per tier, which covers the dispatch and tableau before stop patterns change.

## 7. Technical design

- New module: `src/extras/vcmodchase.cpp` and `.h` for the mission state machine, director, scenario, force pools and HUD. Small hooks in `PlayerPed.cpp` for the uniform, climb control and seats; small hooks in the animation code for reverse time.
- Reuse: `CPopulation::AddPed` with cop types for the squad; gang ped types for the crew; `SetUpDriver` and `CCarAI::AddPoliceCarOccupants` for vehicles; `C3dMarkers` and `CRadar` for presentation; the mod's existing character swap and ini plumbing.
- Mission data: tier table, route waypoints, spawn nodes and the station, garage and pad coordinates. Author coordinates with a debug teleport key rather than guessing.
- Streaming: request every tier model during the briefing so the swap and spawns do not hitch.
- Population budget: `NUMPEDS = 140`, `NUMVEHICLES = 110` (`src/core/config.h:39`). Tier 5's active caps plus traffic fit, provided mission-owned vehicles are despawned promptly.
- Tests: brace-extract drivers for the mission state machine, pressure rule, force-pool reserve accounting and rank restore. In-game verification for the climb, rappel, seats, uniform restore and markers. Follow the repo's existing harness style; shipped code stays C++.

## 8. Risks and unknowns

- Maverick passenger seat count in the retail handling data.
- Negative-time animation playback and how it looks on the abseil clip.
- AI squad spacing and stuck cars under director control.
- The stock heli autopilot steers directly and does not pathfind; buildings, wires and altitude need authored waypoints.
- `bIsPlayerFriend` defaults to true, so a missed assignment makes the crew immune or a mission ped hostile.
- The friendly-fire filter must resolve vehicle attackers, or the ram case leaks.
- Boat AI reliability at the marina, and the boat's start delay feeling fair.
- Friendly fire from mission-owned cops.
- Uniform restore after death or arrest, including the pinned model request.
- Marker coordinates and a station location with a usable garage and enough street clearance for a hovering heli.
- Traffic and population pressure at tier 5.

## 9. Phases and acceptance

**P0, skeleton.**
Mission state machine, station marker and blip, tier picker, uniform apply/restore, cleanup.
Accept: marker appears; the tier pick changes the model and animation; the mission ends cleanly; free roam is left untouched.

**P1, ground mission.**
Leader spawn, route, pressure, swap, marina boat, win/fail; patrol and SWAT transport; AI squad; blips; ranks 1-2.
Accept: a full ground run can be won or lost from the marker and cleaned up, with friendly fire inert in both directions.

**P1a, crimes and variety.**
Crime table with a name, dispatch line and base threat per tier; start notice names the crime and its rating; staged tableau at the first stop.
Accept: one crime per tier with distinct dispatch text and ratings; the tableau is visible at the first stop; the response size follows the crime as well as the pick; no new art.

**P2, air insertion.**
Flyable Maverick with AI pilot, climb up, flight, rappel down, AI SWAT, reverse animation.
Accept: both approaches reach the same mission, the NPC pilot holds and follows via the stock autopilot, and the ropes and seats behave.

**P3, force pools and high tiers.**
Finite reinforcements for both sides, HUD counters, Vice/FBI/Army tiers, fast cars/Rancher/Barracks/Hunter, ranks 3-5.
Accept: losses trigger replacements until each reserve is empty; the pools are visibly finite; the high-tier vehicles and uniforms work.

**P4, polish.**
Reward, rank persistence, callouts, balance, cleanup edge cases, harness tests.
Accept: rank survives a restart; no trace after any ending; no crashes in the mission paths.

**P5, post-v1.**
Criminal mode with the stock star ladder; gunner seat; arrest interaction.

## 10. Open questions

- Exact tier values: active caps, reserves, delays and spawn distances.
- Whether the squad pool should be automatic or callable by radio; v1 assumes automatic.
- Whether rank 5's air start should always be the Hunter or a choice between Maverick and Hunter.
- HUD style for the two reserve counts.
- Marina location and whether the boat AI needs authored approach points.
- Whether the arrest verb is worth building after v1, since "stopped" already ends the mission.
