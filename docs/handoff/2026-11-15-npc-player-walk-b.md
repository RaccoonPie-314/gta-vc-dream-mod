# Handoff: BECOME NPC with player movement, slice B (combat steering)

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665` (nothing committed this session)
Installed: `vcmods build 600` in `~/Games/VC/reVC.app` (slice A was 598)
Harness: all green, including the extended `utils/test_vc_playerwalk.py`

Slice B makes the keys work during a fight. The AI still picks the target,
aims, fires, reloads and chooses melee moves; the player's movement translates
the body, and the stock tracking turn puts the facing back on the AI's target
after the walk. Release the keys and the AI's own locomotion resumes.

## What changed

- `src/extras/vcmodnpcwalk.{cpp,h}`: `VCModNpcWalkCombat` — pose wait,
  `PlayerControlFighter` in a fist fight, else `PlayerControlZelda` then
  `RotatePlayerToTrackTarget` when the AI points a gun.
- `src/peds/PlayerPed.cpp`:
  - the combat group (`PED_ATTACK`, `PED_FIGHT`, `PED_AIM_GUN`, combat-owned
    `PED_IDLE`) takes the key branch before `VCModNpcCombatControl`;
  - `MovementDisabledBecauseOfTargeting` returns false under the new predicate,
    so the AI's own aim no longer plants the player's keys;
  - slices A's four free-state hooks are unchanged.
- Harness: `test_vc_playerwalk` gained the combat fixture and wiring tests and
  dropped the slice-A "combat stays the AI's" assertion; `test_vc_ganggaze`
  gained the `VCModNpcWalkCombat` stub.

Uncommitted in the checkout also: the previous session's NPC-combat slices.
Do not revert or split them.

## Play steps

1. BECOME NPC + WASD MOVE on, then start a fight (cop profile with a wanted
   level, or walk into a gang).
2. Keep a movement key held during the gunfight: he should keep aiming and
   firing at his target while you walk him around it. Watch that the gun stays
   on the target and that the legs do not slide oddly.
3. Release the keys mid-fight: he repositions as a stock ped.
4. A fist fight: the AI throws the moves, the keys move him between them.
5. Turn WASD MOVE off: the fight is fully AI-owned again, keys dead.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Next

Play slice B, especially the aim staying on target while strafing and the
fist-fight feel. Then slice C: the ring-talk walk-away and the edge inventory.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 600` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-player-walk-design.md`,
> `docs/plans/2026-11-15-npc-player-walk.md` and `AGENTS.md` first.
>
> Slices A and B are installed. Implement slice C (Tasks C1–C2): the CALL GANG
> ring-talk walk-away (`VCModGangGroupWalkAway`, the `why` parameter on
> `VCModGangGroupStopChat`, the call from `VCModNpcWalkMove`, the gang-group
> harness call site), the stock-edge inventory tests, then the build, install
> and session handoff. Sweep any harness that compiles the edited functions.
>
> Run all `utils/test_vc_*.py`, `scripts/build.sh`, then `scripts/install.sh`
> only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, and confirm the
> installed build number before handing off. Do not commit, tag or push unless
> asked; game data and the `uchg` anim files stay untouched.
