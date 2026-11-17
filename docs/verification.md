# Built, not yet seen in play

As of 2026-11-17, build 646. Everything here is harness-green, compiled into the
installed build and never confirmed at the keyboard. Each line names the handoff
that carries the play steps, so an item can be closed without reading the source.

This is the one live list. When a play pass confirms an item, delete its line;
when a feature ships unplayed, add it here instead of a second "not verified"
section elsewhere.

## BECOME NPC and NPC behaviour

- [ ] `MISSION TARGET` on mid-mission: Tommy takes the nearest mission enemy and
  hunts him on foot, a target in a car is attacked on foot instead, the stock
  after-kill wait pose plays, then the next enemy; the pin survives a restart.
  `docs/handoff/2026-11-16-npc-mission-target.md`
- [ ] `PED WOUNDS` off: pistol rounds take about a third of health and limbs stay
  on; on: ped damage and limbs come off; the mode off is stock either way.
  `docs/handoff/2026-11-16-npc-ped-wounds-toggle.md`
- [ ] Aim pose after a kill: the gun comes down on the kill frame, a second
  hostile keeps the aim, and the ID check and patrol still aim at a civilian.
  `docs/handoff/2026-11-16-npc-mode-aim-pose-after-kill.md`
- [ ] Suspend set: `STREET IDLE` and `NPC DOOM AIM` read held and refuse a toggle,
  the crew and chauffeur are sent home and a chase stops; turning the mode off
  hands them back (switch, then 0.5 s, then a summon after 1 s); a quick double
  toggle keeps the values; a pinned switch still reads on.
  `docs/handoff/2026-11-17-become-npc-suspend.md`
- [ ] Gang rivalry repair: on the affected saves a Cuban body with no weapon is
  attacked by Haitians on sight, kin stay spared, cops and civilians keep their
  stock reaction, and the repaired table survives save and reload.
  `docs/handoff/2026-11-16-gang-rival-sight-fight.md`

## Driving and vehicles

- [ ] `AUTO DRIVE` `[SAFE]`: routes to the map marker, brakes to a stop and turns
  itself off; without a marker it cruises like traffic; taking the wheel cancels
  on that frame.
  `docs/handoff/2026-11-15-autodrive-speedlimit.md`
- [ ] `AUTO DRIVE` `[AGGRESSIVE]`: pulls away at 40, weaves around traffic, runs
  reds, brakes when a car ahead closes the gap, and still stops at the marker.
  `docs/handoff/2026-11-16-autodrive-crew-pace.md`
- [ ] `CREW AGGRESSIVE` with `RIDE TO`: fast and weaving but brakes when boxed in,
  and a wedged crew car backs out after a moment instead of sitting forever.
  `docs/handoff/2026-11-16-autodrive-crew-pace.md`
- [ ] `SPEED LIMIT` feel: the cap cuts the throttle at traffic pace with no brake
  lamps, and only a real overshoot brakes.
  `docs/handoff/2026-11-15-autodrive-speedlimit.md`
- [ ] Cockpit view on replaced models: the camera clears the dash and roof, the
  driver's head stays out of the frame edge, bikes and boats read right, and the
  camera-key exit feels right.
- [ ] Pack car models and wheels, the steering wheel node and the lamp textures on
  a car that is actually driven.
- [ ] `EXPLOSION COVER`, `FBI LIGHT BARS` and `FIRETRUCK CANNON` in play.
- [ ] Driving orbit camera: the inverted vertical axis and the boat hold.
- [ ] Passenger riding end to end, including a bike pillion seat with an NPC rider.
- [ ] Chauffeur end to end: spawn, the drive over, boarding, dismissal, and whether
  the Stretch's rear door reads correctly.
- [ ] `SKIP RIDE`: scene streaming and the landing height at the road node.
- [ ] Changing `RIDE STYLE` mid-approach and mid-ride from the panel.
- [ ] `RIDE TO` a zone whose centre lands off-road: the path snaps it to a road node.

## Panel and input

- [ ] KEYS page: arming a row, a keyboard chord, a pad chord, `[X]` clearing a row,
  `Esc` cancel, `RESET KEYS`, and a rebind surviving a restart.
  `docs/handoff/2026-11-16-keys-pads-combos.md`
- [ ] Panel on the controller: the D-pad walks rows and a row's targets, L1/R1
  switch tabs, Cross acts, Circle backs out of a list and then the panel, and the
  highlight follows the last device used.
- [ ] Panel hit-testing at resolutions and window sizes other than the one used
  during development, including the tab strip and the pin cell.
- [ ] Panel housekeeping, per tab: `[TAB ON]` at the right end of the header row
  switches the tab's sweepable rows together from the mouse and from the pad
  (one step above the first row lands on the header cells, Left/Right walks
  them); KEYS and DEBUG show `[TAB --]` and a press says so. `TAB MIX` reads
  when only some are on. Pins and a held BECOME NPC switch keep their values.
  `RESET STATE` (DEBUG page, after SPAWN VEHICLE): crew out, chauffeur out,
  gang group out, a chase up and AUTO DRIVE on — all put down in one press and
  each through its own dismissal; an empty press says nothing was running;
  switches and BECOME NPC keep their values. `FIND` on the KEYS page: type
  letters, the page scrolls to and lights the match, Backspace deletes, Esc
  clears and leaves, Enter leaves the query standing; typed letters never
  fire, walk or drive; nothing stays typed after a tab switch or a
  close mid-type.
  `docs/handoff/2026-11-17-panel-housekeeping.md`
- [ ] ini seeding end to end: set a switch in the ini, launch, and the panel shows
  it on without touching a toggle; a pinned row survives a restart.

## Combat and player

- [ ] Lock-on walk shot: plant, raise, burst, tail; a tap fires one shot once the
  gun is up; a lock while standing is unchanged; walking with a lock and no fire
  stays in the carry.
  `docs/handoff/2026-11-16-lockon-walk-shot-windup.md`
- [ ] The `K` spin kick: the dropped-in roundhouse reads right on Tommy and lands
  on a ped at arm's length.
- [ ] `NO STRAFE` and the kerbside look.
- [ ] The story characters on the mission shelf: wear one in play.

## World

- [ ] The seat camera lock on a bench.
- [ ] Sitting on the Miami apartment bench after an NPC was killed on it, and after
  a corpse was left there.
- [ ] Cutscene subtitle gaps: play until a subtitle shows `… missing`, then read
  the last `text key missing:` line in `~/Games/VC/reVC.log`.
  `docs/handoff/2026-11-16-cutscene-subtitles.md`
