# Change log

All the work sits on branch `vcmods` in the reVC checkout, three commits
ahead of the upstream `miami` commit `a26fff4` it was written against. `vc-mods.patch` is
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

- `IDLE GESTURES` gives Tommy the peds' own waiting pose: still on foot, unarmed and
  off the tarmac for four seconds, he blends `idle_hbhb` for 3–5 s, then idles again.
  The stock bored fidget (stretch, watch, scratch) keeps its slot, and the waiting
  pose steps aside while it plays. Compiles; not yet seen at the keyboard.
- `CHATTER` starts the peds' pair chat with a wandering civilian within 1.8 m who can
  see him: both sides enter `PED_CHAT`, the `idle_chat`/scratch loop runs, and any
  movement, weapon, aim or jump ends it on the frame it is pressed. Cops, gangs and
  mission actors are not candidates, and the ped still has to pass `WillChat`'s own
  surface and road checks. Compiles; not yet seen at the keyboard.
- Both start on, because they are flavour rather than cheats; the ini's `StreetIdle`
  and `Chatter` keys turn them off. When a gate refuses, one line per distinct
  refusal reaches the log (`VCMOD street idle held: 0x…` with state, weapon,
  surface and speed), so a silent feature names its blocker instead of only
  failing to start.

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

## Not verified

- ini seeding end to end: set `NpcAnims = true` in the ini, launch, and check the
  panel shows it on without touching a toggle.
- Panel row hit-testing at resolutions and window sizes other than the one used
  during development.
- Passenger riding end to end, including whether a bike pillion seat behaves with
  an NPC rider, and what a boat driver does when we crewed it ourselves.
- The story characters on the mission shelf: the resolution path is tested, but
  nobody has worn them in play yet.
- Zone routing: the destination is a zone centre, so a district whose centre lands
  off-road depends on the game's own pathfinding snapping it to a road node.
- The chauffeur end to end: spawn, the drive over, boarding, dismissal, and whether
  the Stretch's rear door reads correctly.
- `SKIP RIDE` travel in play: scene streaming and the landing height at the road node.
- Changing `RIDE STYLE` mid-approach and mid-ride from the panel.

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
