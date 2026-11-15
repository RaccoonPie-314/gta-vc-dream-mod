# Handoff: BECOME NPC with player movement, slice A (free walk)

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665` (nothing committed this session)
Installed: `vcmods build 598` in `~/Games/VC/reVC.app` (previous 593)
Harness: all green, including the new `utils/test_vc_playerwalk.py`

Slice A ships the row and the free walk. With BECOME NPC and `WASD MOVE` both
on, the movement keys own locomotion in wander, seek (cop chase, chat
approach), flee/investigate and chat; the AI keeps its state machine and
resumes movement on release. Combat stays fully AI-owned in this slice: the
keys do nothing in a fight until slice B.

## What changed

- New module `src/extras/vcmodnpcwalk.{cpp,h}` (53 lines): the flag, the input
  predicate, the pose-wait rule, `VCModNpcWalkMove`.
- `src/extras/vcmodpanelregistry.cpp`: row `WASD MOVE` under BECOME NPC, ini
  key `NpcPlayerWalk`, World tweak.
- `src/peds/PlayerPed.cpp`: include plus four gated hook sites (flee/investigate,
  wander, chat, seek). The gate is `VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)`.
- Harness sweep the plan did not list: `test_vc_cop_chase`, `test_vc_ganggaze`,
  `test_vc_adrenaline`, `test_vc_character` gained the new predicate stubs, and
  `test_vc_passenger`'s row count went 63 to 64.
- `docs/architecture.md`: module table row and refreshed counts.

Uncommitted in the checkout also: the previous session's NPC-combat slices and
their harnesses. Do not revert or split them; they are the base this builds on.

## Play steps

1. Panel, WORLD page: BECOME NPC on, WASD MOVE on.
2. Let him wander, then steer with the keys; release and let him walk again
   (he may stand a beat before the next path).
3. Trigger a reaction seek (cop chase on a cop body, or a chat approach) and
   steer during it.
4. Walk away from a chat; it should end.
5. Turn WASD MOVE off: BECOME NPC must ignore the keys again, exactly as 593.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Next

Play slice A. If it reads right, slice B per the plan: the combat hook, the
targeting-lock bypass and `VCModNpcWalkCombat` with the stock tracking turn.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 598` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-player-walk-design.md`,
> `docs/plans/2026-11-15-npc-player-walk.md`, `docs/architecture.md` and
> `AGENTS.md` first.
>
> Slice A is installed and awaiting play. Implement slice B (Tasks B1–B2):
> `VCModNpcWalkCombat`, the gated combat branch in `CPlayerPed::ProcessControl`,
> and the `MovementDisabledBecauseOfTargeting` bypass, so the keys steer a fight
> while the AI keeps the target, the aim, the trigger and the melee chooser.
> Keep the facing on the AI's target with `RotatePlayerToTrackTarget` after the
> walk. Work test-first in `utils/test_vc_playerwalk.py`; sweep any harness that
> compiles the edited sites.
>
> Run all `utils/test_vc_*.py`, `scripts/build.sh`, then `scripts/install.sh`
> only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, and confirm
> `strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" | grep -m1
> '^vcmods build '` before handing off for play. Do not commit, tag or push
> unless asked; game data and the `uchg` anim files stay untouched.
