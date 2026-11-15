# Handoff: NPC-mode stock combat — design and plan (2026-11-15)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`.
Installed build `vcmods build 582`. No code changed this session; no build, no
install, no commit, no push.

## What this session produced

- `docs/specs/2026-11-15-npc-stock-combat-design.md` — the approved design.
- `docs/plans/2026-11-15-npc-stock-combat.md` — the task-by-task plan.
- This handoff. The three files are uncommitted.

The feature: while BECOME NPC runs, the player ped fights, shoots and takes
damage exactly as a ped of the worn body. One predicate, `VCModNpcFightsAsPed`,
gates every player-only combat branch; feature off is stock. Delivered in three
playable slices:

- **A — melee + profile:** ped fight entry/chooser/state/timing, melee strength,
  the COP profile borrowing its body's stat and threat row, the engine owning
  the fight state, bump scuffles back.
- **B — guns:** stock accuracy by body, ped reload/burst/empty-gun rules, no
  fast reload/streak/sprint breakout/AIM WALK, the cop pistol clip driven by the
  body instead of the row.
- **C — receiving side:** ped damage multiplier, limb/bleed/dismemberment rules,
  ped hit reactions, `ReactToAttack` as a ped. `ReactToPointGun` is already
  correct and does not change.

## Approved constraints

- Full ped combat (outgoing and receiving).
- Body decides animation: Tommy's own body keeps `ASSOCGRP_PLAYER`; NPC bodies
  keep their model's group.
- Named consequences: Tommy's body becomes the `STAT_PLAYER` strong ped (3×
  melee, 0.4 defence); NPC bodies get much squishier (~1.0 defence); the cop
  profile's heading/personality numbers change to the stock cop's; bumps can
  start fist fights again; gun accuracy drops to the body's value.

## Next session

Execute slice A only: Tasks A1–A8 in the plan, test-first. Then run all
harnesses (49 after the new one), build, install only with the game closed,
confirm the installed build number, and hand off for play. Slice B starts only
after the user has played A.

Harness stub sweep is part of the plan: the harnesses that compile a flipped
engine function (`test_vc_cop_pistol`, `test_vc_weapon_recovery`,
`test_vc_aimwalk`, `test_vc_windup`, `test_vc_ganggaze`) need the predicate and
cop-profile stubs, and the windup raise assertion changes.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 582` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-stock-combat-design.md` and
> `docs/plans/2026-11-15-npc-stock-combat.md` first, then `docs/architecture.md`
> and `AGENTS.md`.
>
> Implement slice A (Tasks A1–A8) of the plan: while BECOME NPC runs the player
> fights as the worn ped. Add `VCModNpcFightsAsPed` and
> `VCModCombatChooseMove`, flip the melee fight entry/chooser/state and the
> outgoing melee damage, let the engine own the combat state (no manual
> `StartFightAttack`/`SetAttackTimer`, no stray cleanup, the bump walk-around
> bypass goes), and make the COP profile borrow the worn body's stat and threat
> row. Work test-first with `utils/test_vc_npccombat.py`; update the harnesses
> named in the task stub sweep. Feature off is stock; engine files keep hook
> calls only.
>
> Run all `utils/test_vc_*.py` (49 after the new harness), `scripts/build.sh`,
> then `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"`
> empty, and confirm `strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" |
> grep -m1 '^vcmods build '` shows the new number BEFORE handing off. In-game
> play is the user's turn: a fist fight as a civilian body, then as a cop body.
> Write the handoff with a paste-ready prompt for slice B. Do not commit, tag or
> push unless asked; game data and the `uchg` anim files stay untouched.
