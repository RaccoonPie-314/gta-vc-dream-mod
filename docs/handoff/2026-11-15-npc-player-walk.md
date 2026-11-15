# Handoff: BECOME NPC with player movement, slices B and C

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `46e9f0f` (committed; not pushed — the remote is upstream)
Installed: `vcmods build 601` in `~/Games/VC/reVC.app`
Release: `46e9f0f` published as `d8004f7` on `gta-vc-dream-mod` main, pushed
Harness: all green, including `utils/test_vc_playerwalk.py`

The feature is complete and installed: BECOME NPC with the `WASD MOVE` row on
gives the movement keys to the player and everything else to the profile AI,
combat included. Slice A was played and confirmed (598); slices B and C are in
601 and await play.

## What each slice is

- **A — walking (played).** Keys own locomotion in wander, seek (cop chase,
  chat approach), flee/investigate and chat; release returns movement to the AI.
  Pose waits end on a key; seat/ATM waits finish on their own.
- **B — combat steering.** Keys keep working in `PED_ATTACK`, `PED_AIM_GUN`,
  `PED_FIGHT` and combat-owned `PED_IDLE`. The AI keeps the target, the aim,
  the trigger and the melee chooser; the stock tracking turn re-faces the
  target after the walk; the targeting movement lock no longer plants the keys.
- **C — edges.** Walking out of the CALL GANG ring talk ends it
  (`VCModGangGroupWalkAway`, log reason "walked away"), and the harness pins
  that seats, ATMs, car entry, jump and idle stay stock.

## What changed since the last handoff

- `src/extras/vcmodnpcwalk.{cpp,h}` (73 lines): `VCModNpcWalkCombat` added; the
  walk-away call in `VCModNpcWalkMove`.
- `src/peds/PlayerPed.cpp`: the combat branch and the
  `MovementDisabledBecauseOfTargeting` bypass (2,648 lines, 96 mod references).
- `src/extras/vcmodganggroup.{cpp,h}`: `VCModGangGroupWalkAway`, and the
  `why` parameter on the static `VCModGangGroupStopChat`.
- Harness: `test_vc_playerwalk` combat fixture, ring-talk checks and the edge
  inventory; `test_vc_ganggaze` gained the combat stub; `test_vc_ganggroup`'s
  compiled `StopChat` call takes the reason.
- `docs/architecture.md` counts.

Uncommitted in the checkout also: the previous session's NPC-combat slices.
Do not revert or split them.

## Play steps

1. Panel, WORLD page: BECOME NPC on, WASD MOVE on.
2. Fight test (B): start a gunfight and hold a movement key — he should keep
   aiming and firing at his target while you walk him around it; release and he
   repositions. Watch the gun staying on target and the leg clips.
3. Fist fight (B): the AI throws the moves, the keys move him.
4. Ring talk (C): CALL GANG on the GANG profile, start the talk, then walk —
   the ring should break and the log should say `walked away`.
5. Row off: BECOME NPC ignores the keys and fights entirely on its own again.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Open questions for play

- Does the aim stay visually on target while strafing with every gun, or only
  the arm-aim pistols?
- Does a fist fight read right with the AI choosing moves while the player walks
  between them?

## Committed

`46e9f0f` on `vcmods` carries the whole set: the NPC stock combat slices, the
BECOME NPC walk, the range rows and the pool sizes, with the harnesses. The
release folder was regenerated (`scripts/sync.sh`, `scripts/publish.sh`) and
pushed to the `gta-vc-dream-mod` origin as `d8004f7`.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `46e9f0f`,
> installed `vcmods build 601` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-player-walk-design.md`,
> `docs/plans/2026-11-15-npc-player-walk.md`,
> `docs/handoff/2026-11-15-npc-player-walk.md` and `AGENTS.md` first.
>
> The BECOME NPC walk feature (WASD MOVE) is committed and published; slices B
> and C await play: combat steering with the AI keeping aim/trigger, and the
> CALL GANG ring walk-away. Fix only what play reports; keep feature-off
> stock. Run all `utils/test_vc_*.py`, `scripts/build.sh`, install only with
> the game closed, confirm the build number, then hand off. Do not commit,
> tag or push unless asked; game data and the `uchg` anim files stay untouched.
