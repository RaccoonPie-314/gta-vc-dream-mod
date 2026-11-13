# NPC mode session summary — seat fix, body personalities, toggle reset, melee fix (built 418)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Installed `vcmods build 418` into `~/Games/VC/reVC.app`. No commit, tag or push.
Companion docs: `2026-11-12-npc-seat-objective.md`,
`2026-11-12-npc-strong-personality.md`, `2026-11-12-npc-toggle-reset.md`.

## Confirmed in play

- BECOME NPC's toggle-off now hands the ped back completely (control returns,
  no leftover walk/seek/sit).
- Sitting at seat attractors works after the seat-objective fix.
- Flee/fear from a fresh corpse was stock all along; Tommy now investigates.

## Shipped this session

1. **Seat objective** (`2026-11-12-npc-seat-objective.md`): the player seek
   case mirrors native `SetIdle()` for attractor objectives, the wander resume
   yields to a live objective, and the engine's own sit borrows the sit
   machinery (lock, control skip, stock timer).
2. **Personality follows the worn model** (`2026-11-12-npc-strong-personality.md`):
   the civilian profile borrows the model's stock `CPedStats` while it drives
   him; Tommy's own body is a strong variant (fear 0, temper 100, no gun
   panic) that fights gunshots/attackers, investigates corpses and explosions,
   never flees, keeps the hands-up reaction. The civilian profile now owns
   engine combat for kill objectives.
3. **Toggle reset** (`2026-11-12-npc-toggle-reset.md`): the off-edge releases
   the objective, seek, chat, wait state, attractor, threat refs, path and sit
   flags, snaps to idle, and hands back STREET IDLE.

## FIXED (built 409, awaiting play): melee did not register

Report: "Tommy's hit does not register on others, and theirs does not register
on him", seen when walking into someone and swinging.

Root cause (player side, confirmed in the code): NPC mode drives the player's
combat states itself. In `PED_ATTACK` it called `CPed::Attack()`, which is the
weapon-animation driver; the player's real melee entry in normal play is the pad
handler's `StartFightAttack` (`ProcessPlayerWeapon`). With no pad, the attack
never left the start animation, so `CPed::Fight()` / `FightStrike()` — the only
place a melee hit frame reaches `FightHitPed` → `InflictDamage` — never ran. And
in `PED_FIGHT` the player never set `m_fightButtonPressure`, which `Fight()` uses
to pick the next move (the AI re-arms it through `SetAttack` every beat).

Fix (`src/peds/PlayerPed.cpp`, the npc-combat branch of the control switch):
- `PED_ATTACK`: fists / brass knuckles / `WEAPONFLAG_FIGHTMODE` now call
  `StartFightAttack(random)` — the same ped entry `SetAttack` gives an unarmed
  pedestrian; other weapons still call `Attack()`.
- `PED_FIGHT`: re-arm the next move with `StartFightAttack` when `m_attackTimer`
  has passed (the AI's own throttle), then run `Fight()`.

TEMP probe: `VCMOD fist: player|ped model N -> player|ped model N for D (hp H)`
prints on any hit where either side is the player, in NPC mode. It tells us
whether the reverse direction (peds damaging Tommy) fires at all.

Note on the reverse direction: stock gives a player victim `damage * 0.33f`
(`CPed::InflictDamage`) and `StartFightDefend` only plays a flinch on the player
while he is running, so pedestrian hits on Tommy may be landing quietly. The
probe decides whether anything else is missing.

Also checked: bumping into someone plays the stock shove / partial punch and
`StartFightDefend` with no damage — that is stock VC and unchanged.

Verification: `test_vc_ganggaze.py` 12 (PED_ATTACK takes the ped entry for every
profile; PED_FIGHT re-arms and fights; throttle honoured), full suite 270/270,
Release build green, installed build 409 with the `VCMOD fist` marker. Not yet
played.

## Play round 2 (after build 409): perpetuum punch — fixed in 411

Two reports: toggling NPC mode on left him stuck attacking since a menu click
still reached the game, and standing still he punched every passer-by.

Both traced to the melee route being too broad. Any `PED_ATTACK` took
`StartFightAttack`, and `PED_FIGHT` re-armed a move every frame with no check
that a fight was actually wanted. Bump shoves, menu clicks and leftover states
all land in those ped states, so each became a real, self-renewing fight that
picked whoever stood nearby (`ChooseAttackPlayer` has no hostility test).

Fixes:
- The ped fight entry and the re-arm now require `npcCombatOwnsControl` — a live
  `KILL_CHAR_*` objective with a living ped target. A bump shove or a stray
  attack stays the stock one-shot animation; a fight without a target is not
  re-armed and ends by itself.
- NPC mode skips `ProcessPlayerWeapon` entirely (input is ignored there), so a
  held button or a menu click cannot fire or start a player attack.
- The panel consumes the left mouse button after its click handler, so a row
  click is no longer also a game action.

Verification: ganggaze 14 (attack with a live target starts the fight; attack
without one keeps the stock animation; fight re-arms only with a live target and
honours the timer), full suite 272/272, Release build green, installed build
411. Not yet played.

Also still open from this session: confirm the `VCMOD fist:` probe shows both
directions of a real fight landing.

## Play round 3 (after build 411): stuck shove pose + panel input — fixed in 413

Report: punching or shoving left the hand stuck in the charge/holding pose, and
the panel should block game input while it is up.

The pose: a bump shove lands in `PED_ATTACK` with no kill objective. Build 411
ended that state's *driver* but still `break`-ed out of the control switch, so
the shove's last frame stayed up — the stock pose handling below (which blends
the walk/idle clip over it) never ran. A stray `PED_FIGHT` had the same class of
problem.

Fixes:
- Non-owned `PED_ATTACK` now ends via `ClearAttack()` and **falls through** to
  the stock handling, which restores the pose.
- Non-owned `PED_FIGHT` ends via `EndFight(ENDFIGHT_FAST)` and falls through
  too; owned attack/fight still breaks out as before.
- Panel: `VCModPanelShowing()` + an early return in `CPlayerPed::ProcessControl`
  after the base control — while the menu is up no pad input reaches the game
  (movement, weapons, mod hotkeys), so a row click cannot fire or attack behind
  it. The panel also consumes its left click.

Verification: ganggaze 14 (shove ends with the stock pose pass; a stray fight
ends and falls through; owned fight still re-arms), full suite 272/272, Release
build green, installed build 413. Not yet played.

## Play round 4 (after build 413): one click toggled twice — fixed in 416

Report: clicking a panel row read ON and then OFF by itself; several clicks were
needed for a switch to stick.

Cause was the round-2 click swallow: clearing `NewMouseControllerState.LMB`
after handling the click kept `OldMouseControllerState` from ever seeing the
press, so a held button reported a fresh press on every frame and the row
toggled at frame rate. The swallow is no longer needed — the panel-open input
block (round 3) keeps clicks out of the game — so it was removed and the plain
`Old`/`New` edge restored: exactly one toggle per physical press.

Verification: `test_vc_adrenaline.py` 3 and `test_vc_character.py` 6 (both drive
`VCModClick` against Old/New mouse states, including a held button), full suite
272/272, Release build green, installed build 416. Not yet played.

## Play round 5 (after build 416): shove/attack spam — fixed in 418

Report: menu is fixed; the shoving and attacking kept spamming, mixed with normal
combat.

Two causes:
- The collision shove (`CPed::ProcessCollision` → `SetAttack(collideWith)`,
  retried every 250-450 ms) kept starting shove attacks while walking through
  peds, and during a fight it hijacked the state into a shove. NPC mode has no
  attack input to end those, so they accumulated. In NPC mode the player now
  takes the polite branch (walks around, says the stock line) instead of
  shoving. The 2 s bump flinch (strong ped → other ped cowers) is untouched.
- The fight re-arm requested a move every frame: it never set `m_attackTimer`,
  which is the AI's own throttle (`SetAttack` → `SetAttackTimer`). It now sets
  the same 300-900 ms beat after each request.

Verification: ganggaze 14 (the beat is set and holds the next request),
full suite 272/272, Release build green, installed build 418. Not yet played.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Check `pgrep -x reVC` immediately before
any install (an install over a live session happened this session; the session
survived). `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are uchg.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 418.
> Read `docs/handoff/2026-11-12-npc-melee-open.md` first. Session fixes: seat
> objective, body-personality/strong Tommy, full toggle reset, melee route (a
> fight only starts with a live kill target and runs on the AI's 300-900 ms
> beat; bump shoves walk around instead of attacking), panel blocks player input
> while open, one click toggles once. Play-test walking through a crowd (no shove
> loop), a real fight in both directions (`VCMOD fist:` probe), and panel
> clicks; then strip the temporary probes and commit. Never commit/push for me;
> game data and uchg anim files are read-only; check `pgrep -x reVC` before any
> install.
