# Change log

All the work sits on branch `vcmods` in the reVC checkout, one commit ahead of the
upstream `miami` commit `a26fff4` it was written against. `vc-mods.patch` is
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

## Not verified

- ini seeding end to end: set `NpcAnims = true` in the ini, launch, and check the
  panel shows it on without touching a toggle.
- Panel row hit-testing at resolutions and window sizes other than the one used
  during development.

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
