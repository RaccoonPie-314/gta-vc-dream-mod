# Change log

All the work sits on branch `vcmods` in the reVC checkout, ahead of the upstream `miami` commit
`a26fff4` it was written against. `vc-mods.patch` is
generated from `git diff miami..vcmods` by `scripts/sync.sh`. Don't hand-edit the
patch; regenerate it.

## Shipped — 2026-11-06, `bd9cbc5`

"Seen" means somebody turned it on at the keyboard on this machine and the game
did the thing. "Compiles" means only that.

### Locomotion animations

Tommy can wear an NPC's animation group instead of his own. Seventeen groups are
offered through the panel or the debug menu, and the choice is live — no restart.

- Group picker with a playable check before the switch. Seen.
- Engine-side bounds check in `AnimBlendAssocGroup` and a fallback chain in
  `AnimManager`. These are what stopped `OLDMAN` taking the game down. Seen.
- No military walk set exists in `aStdAnimDescs`, so there isn't one in the list.

### Aiming

- Right-click auto-lock-on while staying on mouse-and-keyboard, all weapons via
  `AIM ALL WEAPONS`. Seen.
- Lock-on also picks drivers in cars, bikes, helis and boats. Seen.
- Lock-on as a latch instead of a hold. Seen.
- Doom aim — player accuracy dropped to the ped default of 60, deviation ramp
  bypassed, first shot included. Seen.
- Scoped weapons (sniper, M4/AK-class, RPG) auto-target instead of scoping, and
  the sniper actually fires rather than clicking. Seen.

### Input and world

- `G` fire, `B` walk toggle, for when the trackpad is doing the aiming. Seen.
- Walk cap applied in both control paths; the mouse camera runs
  `PlayerControl1stPersonRunAround`, which is why the first attempt looked dead. Seen.
- Never Wanted. Seen.

### Control surface

- Backslash panel: colour-coded rows, click to flip, the animation row opens a
  list rather than cycling, and a drawn cursor that obeys the invert-mouse
  settings. Seen.
- Panel stands down while the debug menu is open, so the cheat pages stay
  readable. Seen.
- Startup defaults from `[VC Mods]` in `reVC.ini`. **Compiles, not verified** —
  the scripted keystrokes never reached the game window.

## Shipped — 2026-11-07, `6d5f67d`

### Adrenaline

- `ADRENALINE` reproduces the native pill without picking it up: the flag-driven
  perks, sprint without spending stamina, and the melee damage multipliers. Seen.
- `ADRENALINE MODE` splits the world slowdown out. `SLOW-MO` is the native
  behaviour; `NORMAL` keeps everything else and leaves the world at full speed
  with the legs at their normal rate, because the pill's own 2x is compensation
  for the slowdown. Seen.
- The mod's ownership of the time scale is released on death, arrest, entering a
  vehicle and a replay snapshot, so a disabled toggle cannot leave the game at 1/3.
  Harness.

### Characters

- `PED CATEGORY` then `CHARACTER` dropdowns, read out of the loaded model table,
  Tommy first. The worn model brings its own animation group through the
  playability guard, and the swap runs in the update pass rather than the render.
  Seen for cops, gangs and civilians.
- Tommy keeps `PEDSTAT_PLAYER` across the swap and across respawn, which goes
  through `Undress`/`Dress` and re-takes stats from the worn model. Harness.
- **Crash fix:** the mission shelf used to request the `special01`..`special21`
  placeholder slots directly. No file answers to those names, the slot reported
  itself loaded with a nil clump, and `CPed::SetModelIndex` died in
  `RpAnimBlendClumpInit`. The shelf now resolves each slot through the game's own
  cutscene table, offers only bodies the archive holds, and refuses anything with
  no clump before the ped is touched. Harness; the crash itself was a real fault
  report.

### Control surface

- Two-hand colt left out of ALL ON/OFF and defaults off, so the paused feature
  cannot come on while everything else is switched on. Harness.

### Passenger riding

- `PASSENGER MODE` redirects the enter-vehicle key: an NPC takes the wheel, Tommy
  takes a passenger seat, with animated entry on cars, bikes (pillion) and boats.
  Planes, helis and trains are refused with a reason. Harness.
- Empty cars are crewed through `SetUpDriver()` with the parked-car counters moved
  the way the game moves them; script and mission cars are left alone; a press that
  cannot be honoured falls back to the stock driver entry instead of doing nothing.
  Harness.
- `RIDE TO` sends the driver cruising with traffic or routing to a named map zone
  and parking on arrival. The car waits with `MISSION_STOP_FOREVER` until Tommy is
  seated. Harness.

## Uncommitted — 2026-11-07

### Passenger riding

- **Fix:** passenger mode no longer puts a driver into an unoccupied vehicle. Any
  driverless car, boat or the player's own parked car is left exactly as it was,
  and the enter press falls back to the stock entry, so Tommy gets in as the
  driver. Only a vehicle that already has someone driving can be ridden along in.
  Harness.
- **Fix:** a street car held for boarding could stay at `MISSION_STOP_FOREVER`
  with its driver frozen if the boarding was abandoned — walking away, a door that
  never opened, a press on a different car, or getting into another car. The hold
  now ends after 30 m of separation, 15 s without boarding, another car, or a new
  enter press, and the entry objective is cleared so Tommy stops chasing the car
  that drove off. Harness.
- **Fix:** arriving at a destination ended the ride and left the parked car
  stopped for the session. Arrival now parks with the ride still open; getting out
  is what ends it, and the ordinary release puts the car back on the road. **SKIP
  RIDE** from a passenger seat works the same way. A chauffeur dismissed from the
  back seat is released when Tommy gets out instead of staying stopped. Harness.

## Shipped — 2026-11-07, `ca60b70`

### Locomotion animations

- The skater pair (`wfysk`, `wmysk`) now keeps the ide's `skate` group when worn,
  and `SKATER (ROLLERBLADES)` is offered in the **ANIM SET** list. The group has
  walk, run, sprint and idle but no startwalk; the playability guard now accepts
  it.
- Starting to walk fades into the movement clip under the idle instead of cutting
  to full weight, the way `CPed::SetMoveAnim` does for NPCs: with `WALK MODE` on
  for any group, and on any group without a startwalk slot of its own (all the NPC
  groups are four clips; the player used to borrow Tommy's `walk_start`). That cut
  is what snapped the arms out on the first frame. A sprint start keeps the start
  clip's step, and stopping mid-fade blends the idle back. Harness.
- The player gets the native `SOUND_SKATING` when the worn group is skate. The
  group stands in for the skater ped stat the mod does not take; the surface
  slow-down and trip chance in that branch stay NPC-only. Harness.
- Toggling `WALK MODE` across the walk/run boundary no longer cuts the animation:
  `SetRealMoveAnim` crossfades the incoming clip instead of swapping the blend
  weights in one frame, matching how `CPed::SetMoveAnim` blends an NPC's move-state
  change. Harness.

### Characters

- The `CHARACTER` list shows readable names instead of the ide's model names:
  cops and emergency services, gangs, story bodies, and the civilian codes decoded
  from their letters (`hfyst` becomes `Hispanic girl, street`). An unknown or
  modded model keeps its own name. Harness.

### Personal driver

- `CALL DRIVER` / `H` spawns a Stretch on the nearest car node behind Tommy with a
  chauffeur, a radar blip and mission ownership, drives it to him, re-targets every
  3 s while he walks, stops 15 m out, and gives up past 120 m. Harness.
- Boarding is the normal enter key and works with `PASSENGER MODE` off, because
  that flag governs street cars. A street car boarded while a chauffeur waits hands
  him back to traffic. Harness.
- Dismissal from the kerb or from the back seat, with the traffic counts and the
  blip moved the way `ClearShortCut` moves them. Harness.

### Street idle

- `STREET IDLE` is one switch for the whole scene, the waiting pose and the pair
  chat together: they were two flags for a difference the player cannot act on. It
  still starts on (flavour, not a cheat), the ini's `StreetIdle` key turns it off,
  and when a gate refuses, one line per distinct refusal reaches the log
  (`VCMOD street idle held: 0x…` with state, weapon, surface and speed), so a
  silent feature names its blocker instead of only failing to start.
- The waiting pose is exactly one `idle_hbhb` cycle. Still on foot, unarmed and off
  the tarmac for four seconds, Tommy blends into the clip at 2.0 and fades out where
  the cycle has already carried the arms back to the pose it started from. The old
  3–5 s hold faded the pose at a random point, often just after the clip had looped
  back into raising the arms, which is the snap the ped wait states never show. The
  stock bored fidget (stretch, watch, scratch) keeps its slot and the pose steps
  aside while it plays. Half the time the pose is followed by the head scratch: the
  ped's DOUBLEBACK wait goes from the hands-behind-back pose into `XPRESSscratch`,
  so Tommy plays its own cycle and fades it where it ends.
- `C` on a chair or bench sits Tommy instead of crouching. The seat is the map's
  own `ATTRACTOR_SEAT` 2dfx, and the sit runs the same `SEAT_down`/`SEAT_idle`/
  `SEAT_up` sequence the ped wait states run, landing on the effect position at
  ground level and facing the seat's use direction. The seat owns him while the
  clips play: the on-foot mouse camera normally aims the ped at the lens every
  frame, so a seated ped is taken out of that path and pinned to the anchor he sat
  down on, letting the camera orbit on its own instead of swinging him off the
  bench. The scan covers the dummy
  entity list as well as buildings and objects, because map props (park benches
  included) are placed as dummies and the ped attractor scan never looks there. A
  seat is taken only while a living ped's attractor points at that effect and that
  instance's position, read from the peds rather than the manager's slot count:
  that count is per effect, so a ped on any other bench of the same model reads as
  every instance being full, and it can outlive a sitter killed on the bench. A
  body left on the seat no longer blocks the press (`VCMOD sit: dead sitter
  ignored`), and a living holder is named in the log (`VCMOD sit: seat held by
  ped …`). The press is refused while armed, crouched, in a car, in the air or in
  water — each refusal names itself in the log (`VCMOD sit: …`), because C is also
  the crouch key. Any walk key, jump or a second `C` stands him up; without a free
  seat in reach the press stays the stock crouch. It is part of the same `STREET
  IDLE` switch, and switching the mod off while seated stands him up rather than
  leaving the controls locked.
- The chat no longer ends when another pedestrian bumps in. The break tests are the
  player's own: a walk press, fire, aim, jump, crouch, a car, a death, lost
  controls, or being knocked down. A shove changes the move speed and the touched
  surface for a frame or two and is ignored; either side dropping out of `PED_CHAT`
  for a frame is put back with the clock unchanged, and the reason reaches the log
  (`chat ended (…)`). Cops, gangs and mission actors are still not candidates, and
  the ped still has to pass `WillChat`'s own surface and road checks.
- The pair faces each other for the whole conversation. `Chat()` only turns the
  body while the look flag is up and `SetChat` gives that a three second timer, so
  the look is re-armed after the control and camera code each frame. The chat also
  opens with the partner's own `SOUND_PED_CHAT` straight into their voice: the
  engine's `Say()` waits a beat and can be swallowed while the camera moves, and
  the ped's bank is the only side of the pair that has chat lines at all.
- The chat gestures on its own turns. A line measures ~1.6 s in the voice bank, so
  the speaker plays `idle_chat` from the clip's own first pose for 1.8 s and the
  hands rest until the next turn; the listener stands in its stance. `Chat()`'s own
  cycle re-blended the clip at a random 0–3 s offset and faded it out a second or
  two later, which restarted the arms mid-pose every couple of seconds of a
  face-to-face conversation. The hands follow the turn even when the body has no
  chat bank and the partner's voice answers.
- The chat ends on a rest beat, not a timer cut. A ped's chat runs out inside
  `Chat()` and that frame clears the clip at 8.0 and walks the pair apart; the
  player has no path to walk back onto, so the cut was the whole ending. The pair
  now finishes its last line's gesture, lets the hands come down at the gesture's
  4.0, holds the facing for 0.6 s and parts, and a line that would run past the
  clock moves the clock instead of being cut. The engine's per-ped chat timer is
  out of the loop for the pair so it cannot clear the conversation a second early,
  and the 30 s gap it would have set is set when the pair parts.
- Street idle no longer asks for fists: the waiting pose, the pair chat and `C` on
  a bench all work with a weapon selected. The spin kick still wants fists, being a
  melee attack rather than part of the scene. The on-screen "step off the road"
  reminder is gone; the tarmac refusal still reaches the gate log.
  **Compiles, not verified** — a weapon's own stance stays under the partial pose
  and chat clips, which is the part to look at in game.
- Seen in game: the waiting pose, the scratch follow-up, the pair chat and sitting
  on a bench. The seat camera lock still needs a retest. Harness green.

### Melee

- `K` throws the peds' spinning roundhouse: `FIGHT_ROUNDHOUSE`, the move the AI
  uses at arm's length, chosen by name instead of letting the fight code roll a
  punch. It runs through `StartFightAttack`, so the clip, spin, strike window, foot
  hit height and damage come from the fight table. From a standstill it starts a
  fight; mid-fight the request waits for the next attack slot. Unarmed only —
  anything in the hands names itself in the log and on the help line — and the
  sitting pose and a chat are dropped when the kick starts. Compiles; not yet seen
  at the keyboard.

### Ride style

- `RIDE STYLE` — safe / fast — shared by the chauffeur and ordinary passenger
  rides, and live mid-ride. Safe is `STOP_FOR_CARS`, the only style that reaches the
  red-light check; fast is `PLOUGH_THROUGH` with real physics and a higher cruise.
  Harness.
- `SKIP RIDE` is a button, not a style: one-shot travel to the chosen zone behind a
  camera jump cut, on foot or from a passenger seat, and it refuses when `RIDE TO`
  is still on traffic. A car Tommy is riding in parks on arrival. The enter key
  never travels, so boarding can no longer turn into a jump. Harness.
- A street car held for boarding is released to traffic when the ride ends and
  nobody is aboard, so its driver no longer sits at `MISSION_STOP_FOREVER` with the
  wheels stopped after Tommy gets out. The release puts the car's own cruise speed,
  driving style and `m_fMaxTrafficSpeed` back instead of the ride's pace, so an
  ordinary driver blends into the traffic again rather than weaving away at ride
  speed. Harness.
- **Fix:** a released street car kept the ride's `DRIVINGSTYLE_AVOID_CARS` and cruise
  20, where generated traffic runs `STOP_FOR_CARS` at 9–14. The driver appeared to
  panic and bolt once Tommy got out; he now drives at the pace the car had before
  the press. Harness.
- **Fix:** a `STATUS_SIMPLE` car is promoted to real physics before the ride
  re-routes it. Driver entry does that when the player sits down; passenger entry
  never did, so `UpdateCarOnRails` kept writing the car's position and dragged it a
  few metres onto the path lane — the ride appeared to teleport on boarding and on
  exit. Harness.

### Tests

- Five Python drivers under `reVC/utils/` brace-extract the production functions
  and compile them as C++98 against stubs. The repo has no test target, so this is
  the shape they take; nothing in the shipped build comes from them.

## Shipped — 2026-11-09

The Vice Extended review, the panel rebuild and the two-hand colt rework. "Seen"
means somebody turned it on at the keyboard on this machine; everything else says
what it actually got.

### Vanilla fixes

- `VANILLA FIXES` master with `HUD CLEANUP`, `KEEP WHEEL ANGLE`, `EXIT HOLD OFF` and
  `LONGER BLOOD/SAND`: money without zero padding, no empty wanted slots, the front
  wheels keep their angle when the car is abandoned, a held exit key cuts the engine
  instead of getting out, and blood and foot dust live twice as long. Seen, including
  the revert with the master off.
- `RELOAD ON R` starts the engine's own reload on demand instead of after the clip
  empties. Seen.
- `WHEEL FALLS OFF`: an impact above 700 impulse marks the nearest wheel missing,
  hides its node and throws a loose wheel object; a simple car is promoted to real
  physics first. Seen.
- `COP CROUCH+COVER`: a wanted cop shot at by an armed player drops into a firing
  crouch for a beat before the stock run to cover. Seen.
- `BLADES AFTER BAIL` and `SHOOT PROJECTILES`: blade collision keeps running while a
  heli spins down with nobody aboard, and a shot through a live grenade, molotov or
  rocket sets it off. Built, unplayed; both kept deliberately.

### World and vehicles

- `EXPLOSION COVER`: a building between a blast and an entity stops that entity's
  damage and its chain detonation. Built, unplayed.
- `FBI LIGHT BARS`: the FBI Car and FBI Rancher get the cruiser bar on the roof, sized
  from the model's own bounding box. Built, unplayed.
- `FIRETRUCK CANNON`: the water jet starts at the tower mount for the AI driver too,
  and the arrow keys aim it on a keyboard, where the stock accessors always read
  zero. Built, unplayed after the mount was raised once.
- `STEERING WHEEL`: pack car models carry a real `steeringwheel` node; it turns at
  four times the road-wheel angle about its own rest orientation, and recaptures that
  orientation when the clump is set up. Shipped with the pack cars, unplayed.
- A loose `mods/` file now also wins for streamed models and texture dictionaries,
  which open through `RwStreamOpen` rather than `myfopen`. Harness.
- A model with its own `reversinglights` dummy keeps its red tail corona in reverse
  instead of washing it white. Harness.

### Driving camera

- In a car or boat the mouse and right stick swing the third-person camera around
  the vehicle, holding the angle relative to the car, and it eases back behind after
  1.5 s with no camera input. Unplayed.

### Two-hand colt

- The shot keeps the cop clip's stance: the lowered hold stays upper-body only, the
  fire clip restores its own legs from the group template, and the body turns on the
  target instead of the IK twisting the spine. Settled in play.
- The lowering tail plays out after a burst instead of snapping the gun down. Seen.

### No strafe

- `NO STRAFE` gives the direction keys the body's heading, the way a ped walks, and
  hands it back to the mouse camera while aiming or firing. Harness.

### Panel

- Five tabs — COMBAT, PLAYER, DRIVING, WORLD, DEBUG — a `PERMA` pin column, and the
  master switch moved from the first row into the title bar. A pinned row is written
  back to `[VC Mods]` at once and on every later change; unpinned rows stay presets.
  Not verified in play.
- A row with modes cycles on click instead of taking a second row. `ADRENALINE` steps
  `OFF` → `NORMAL` → `SLOW-MO` and `VANILLA FIXES` steps `OFF` → `ON` for its four
  items, which keep their flags, ini keys and Ctrl-M entries but lose their own rows.
  Adrenaline is one `int32` (`Adrenaline = 0/1/2`) shared by the panel, the Ctrl-M
  page and the ini; an old ini's `AdrenalineSlowMo` key is folded in once, then
  dropped so a pinned normal-speed value cannot come back as slow-mo.
- `TRAFFIC AI` is read from the ini at startup, which it never was, so that row could
  not have survived a restart.

### Street idle

- The kerbside look: a waiting ped whose pavement node carries the crossing flag
  looks both ways with `roadcross` instead of playing the waiting idle, and the same
  beat follows the exhausted pose and a stopped run. The probe logs its misses once
  per 30 s so a silent rule can name itself. Compiles, unverified.

### Tests

- Nineteen drivers under `reVC/utils/`, all passing. The five that brace-extract panel
  code were updated for the tabbed panel: page-relative row indices, the title-bar
  master, the pin cell as its own click target, and the list anchor coming from the
  row that opened it.

## Shipped — 2026-11-09, `d6070c5`

### Weapon recovery and moving with a lock

- `GUN RECOVERY`: every firearm clip has the same shape — a loop window
  `weapon.dat` parks on, then a tail that returns the arms to the lowered pose.
  NPCs always played it and the player cut it. A burst now hands the player the
  same tail, and the lowered pose it ends on is the hold until the next shot.
  Seen.
- `AIM WALK`: a locked-on target rooted the player for every gun without
  `CANAIM_WITHARM` in `weapon.dat` — only Colt45, Tec9 and Silenced Ingram could
  walk, because only they aim with the arm IK. With the row on, any gun walks:
  the parked aim pose fades out while he moves and comes back when he stops, and
  the facing follows the direction keys instead of the target. The shot still
  plants him, and so does the recovery tail, so the lowering always lands before
  the walk starts. Seen — the first pass let movement cut the tail and dropped
  the gun at once, which play rejected.
- The lock survives the walk: a torso that cannot reach the target no longer
  drops it while the gun is down.
- `reVC/utils/test_vc_aimwalk.py` covers the two predicates and the wiring;
  twenty-one drivers now pass.

## Shipped — 2026-11-09, `8d57f7c`

### Vehicle lights

- `LIGHT TEXTURES` on the DRIVING page: a replaced model's lamp material switches
  to its lit texture while that car's lights are on, and back to the unlit face
  when they are off. The materials belong to the clone-shared geometry, so the
  switch rides the render call the way `SetVehicleColour` does, and two cars of
  one model can show different states at once.
- Car light cubes — the translucent 8-vertex box `CBrightLights` draws on every
  lamp — fade from 15 m to 8 m, so only the lamp face and its corona carry the
  light at parking distance. Far behaviour is unchanged.
- The FBI Car, FBI Rancher and Vice Cheetah run the stock four-corona siren seated
  per model inside the cabin, so timing, colours and the road glow are the
  cruiser's own. The police bar's coronas narrow to its roof blocks.
- Tail lamps stay red while reversing; the white wash over the coronas is gone,
  and the white belongs to the reversing lamps on pack models that carry them.
- The stock police model is back, from `mods/stockpolice/overlay.img`.

### Vehicle spawner

- `SPAWN VEHICLE` on the DEBUG page lists every car model in the install, sorted
  by IDE name, and queues the pick; `CGame::Process` streams and spawns it 4.5 m
  ahead of the player, unlocked. The panel never streams from the frame render.

### Input

- The mod's own hotkeys are rebindable on a new **KEYS** panel page. The eight
  direct key checks — fire, walk mode, call driver, spin kick, reload, chase spot,
  chase capture and the panel key — now read `aVCModKeys` in
  `src/extras/vcmodkeys.cpp` instead of compiled-in literals. Clicking a row arms a
  capture; the next key press becomes the binding (Esc cancels) and writes
  `KeyPanel` / `KeyWalk` / … into `[VC Mods]` at once. **RESET KEYS** restores the
  shipped letters. While a capture is armed, every mod hotkey handler stands down,
  so the key used to bind does not also fire, reload or toggle. Duplicate bindings
  are allowed; the chase tier digits and its Enter/Backspace keys stay fixed, and
  the game's own controls remain on the pause menu's Controller Setup page.
- The driving free camera's vertical axis is inverted: pushing up now lowers the
  camera and looks down over the car instead of looking up. Yaw keeps the stock
  direction, and the stock invert settings still flip either axis on top.

### Firetruck

- The water cannon fires from the model's muzzle, mirrored with the aim, and the
  barrel node turns with it — a parked truck schedules its own frame update, or
  the turn waits for the vehicle to move.

### Tests

- New `test_vc_lighttex.py`, `test_vc_carlights.py`, `test_vc_spawn.py` and
  `test_vc_keys.py`; `test_vc_fbilights.py` and `test_vc_rearlights.py` rewritten
  for the pack mechanic and the red tail. Twenty-five drivers pass.

## Dropped — 2026-11-09

- Per-lamp light cast. The pack splits the head and tail pair into one ground pool
  per lamp; built and installed, then rejected in play: the pools read as choppy
  against the terrain and the split is back out, so cars cast the stock single
  quad at each end again. Nothing of it remains in the tree. The pack's tail pool
  going grey in reverse was never taken either.

## Uncommitted — 2026-11-09

- `1ST PERSON` on the DRIVING page: a first-person driving view. Key `C`, rebindable
  as `1ST PERSON KEY` on the KEYS page, and the row itself; the stock change-camera
  key cycles away from it as it always has. No on-foot first person.
- The camera is above the **bonnet**, not at the driver's seat. Vice City car bodies
  are single-sided shells with no cabin: from the seat, play reported the car
  entirely absent from the frame, which is what the shell does from inside. The mod
  reads the car's own `bonnet_dummy` (already in every car's node table) and puts the
  eye 0.22 m above it and 0.20 m behind it, so the nose frames the bottom of the view.
  Bikes and boats keep the stock seat camera.
- The view is reached through the vehicle camera ring: `CAM_ZOOM_1STPRS` is already a
  stop on it and the stock code turns that stop into `MODE_1STPERSON`. The key and the
  row move the ring and nothing else, so no camera mode is written from the mod; an
  earlier pass that forced `ReqMode` from `CamControl` produced no view at all. The
  stock key reaches the same stop on its second press from the default zoom.
  Compiled and harness-tested; not played.
- `reVC/utils/test_vc_firstperson.py` covers the ring stop, the bonnet placement,
  the absence of any camera-mode write from the mod, the key read and the row. `test_vc_passenger.py`
  (row count 49) and `test_vc_keys.py` (nine slots) follow. Twenty-six drivers pass.

## Not verified

- ini seeding end to end: set `NpcAnims = true` in the ini, launch, and check the
  panel shows it on without touching a toggle. The pinned-row writer has not been
  exercised across a restart either.
- Panel row hit-testing at resolutions and window sizes other than the one used
  during development, and the tab strip and pin cell at any size.
- The driving orbit camera, the pack car models and wheels, the steering wheel node,
  explosion cover, the FBI bars and the firetruck cannon: built, installed, unplayed.
  The camera's inverted vertical axis from 2026-11-09 is unplayed too.
- The cockpit view: whether the front-seat camera clears the dash and roof of
  every replaced model, whether the driver's own head intrudes at the frame edge,
  how bikes and boats read in it, and whether the camera-key exit feels right.
- The KEYS page in play: arming a row, binding, Esc cancel, RESET KEYS, and whether
  a rebind survives a restart. Harness only.
- `NO STRAFE` and the kerbside look in play; both have harnesses only.
- Passenger riding end to end, including whether a bike pillion seat behaves with
  an NPC rider.
- The story characters on the mission shelf: the resolution path is tested, but
  nobody has worn them in play yet.
- Zone routing: the destination is a zone centre, so a district whose centre lands
  off-road depends on the game's own pathfinding snapping it to a road node.
- The chauffeur end to end: spawn, the drive over, boarding, dismissal, and whether
  the Stretch's rear door reads correctly.
- `SKIP RIDE` travel in play: scene streaming and the landing height at the road node.
- Changing `RIDE STYLE` mid-approach and mid-ride from the panel.
- The `K` spin kick: whether the dropped-in `FIGHT_ROUNDHOUSE` reads right on
  Tommy and whether a ped at arm's length takes the hit.
- The seat camera lock on a bench.
- Sitting on the Miami apartment bench after an NPC was killed on it, and after a
  corpse was left there.

## Ideas not started

Nothing is committed to these. They're here so the list survives a context loss.

- Split the mod into a ccode/loader plugin so the game exe stays upstream and the
  mod drops in. Would need the call sites re-expressed as hooks.
- Windows build of the same patch. The patch is portable C++; the panel and
  charset drawing should follow, but the ini path and `FindGameRoot` behave
  differently there.
- Weapon-set switching via the cheat page froze the game once. Fixed as a side
  effect of the anim-group work; worth re-testing before assuming it's gone.
- A fifth animation slot or two, if the groups turn out not to cover something
  (carrying-heavy-weapon one-hand is the known gap).
