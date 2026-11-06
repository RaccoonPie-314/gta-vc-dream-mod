# Change log

All the work sits on branch `vcmods` in the reVC checkout, a couple of commits
ahead of the upstream `miami` commit `a26fff4` it was written against. `vc-mods.patch` is
generated from `git diff miami..vcmods` by `scripts/sync.sh`. Don't hand-edit the
patch; regenerate it.

## Shipped — 2026-11-06, `bd9cbc5`

"Seen" means somebody turned it on at the keyboard on this machine and the game
did the thing. "Compiles" means only that.

### Locomotion animations

Tommy can wear an NPC's animation group instead of his own. Sixteen groups are
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

### Tests

- Three Python drivers under `reVC/utils/` brace-extract the production functions
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
