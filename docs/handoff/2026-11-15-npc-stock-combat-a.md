# Handoff: NPC-mode stock combat, slice A (melee fight and profile)

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665` (nothing committed this session)
Installed: `vcmods build 589` in `~/Games/VC/reVC.app` (the tree reported 584 before this session)
Harness: 49 harnesses green (`cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`)

## What slice A changed

Design: `docs/specs/2026-11-15-npc-stock-combat-design.md`.
Plan: `docs/plans/2026-11-15-npc-stock-combat.md`, Tasks A1–A8.

While BECOME NPC runs, the player fights as the worn ped. One predicate gates
every flipped branch:

- `VCModNpcFightsAsPed(CPed*)` in `src/extras/vcmodnpc.cpp` — player ped and
  `bVCModNpcMode` on. Mode off evaluates the stock condition exactly.
- `VCModCombatChooseMove(CPed*, int32, bool)` in `src/extras/vcmodcombat.cpp` —
  forced-move slot first (spin kick), then `ChooseAttackAI` while the predicate
  is true, `ChooseAttackPlayer` otherwise. Both call sites in `StartFightAttack`
  and `Fight` go through it; `ChooseAttackPlayer` no longer takes the slot.

`src/peds/PedFight.cpp` flips, all one-line predicate branches:

- `SetAttack`: reload continuation, melee entry (`StartFightAttack` instead of
  the `ANIM_MELEE_ATTACK_START` one-shot), partial-attack gait, the
  kill-objective obstacle, both camera aim entries, the aim-start gate (the old
  gang-only special case is gone) and the point-blank start.
- `ClearAttack`: the ducking gate.
- `StartFightAttack`: no `SetCurrentTime(0.08)`, no combo-counter reset.
- `Fight`: no katana streak, no immediate `EndFight` when the move finishes,
  0.8 anim speed, no player combo chain, ped attack voice, ped
  `SetCurrentTime(0)` on a re-chosen move, 2000 ms wait.
- `FightHitPed`: melee damage × `m_pedStats->m_attackStrength` (adrenaline still
  wins at 20×), no extra player blood spurt, no player-only knockdown clause.
- `FightStrike`: no player glass break.
- `CollideWithPed`: the NPC-mode walk-around bypass is removed; a bump is a real
  scuffle again.

`VCModNpcCombatControl` in `src/extras/vcmodcombat.cpp` now only answers
ownership: any `PED_ATTACK`/`PED_FIGHT`/`PED_AIM_GUN` in NPC mode is
AI-entered, so the manual `StartFightAttack` re-press, `SetAttackTimer` writes
and the stray `ClearAttack`/`EndFight` cleanup are gone. `PED_IDLE` keeps the
walk freeze while a live target is owned; the DIAGNOSTICS fire probe stays.
The engine's objective layer (`ProcessObjective` → `SetAttack`), `Fight` and
`FinishedAttackCB` own the cadence and the exit.

`VCModNpcBorrowIdentity` gained `copWander`: a COP-profile player borrows the
worn body's pedstat (`STAT_COP` for police bodies) and the COP threat row, with
the existing save/restore. Without it the cop chooser used `STAT_PLAYER` (kick,
3× melee) instead of `STAT_COP` (knee/punch, 1×).

## Play feedback on build 585: the chase walk/run snap

Combat works in play. One movement defect reported: while chasing, the walk clip
turned into the run clip with no blend, an instant swap between the two poses.

Cause: the player's walk/run clip weights in `CPlayerPed::SetRealMoveAnim` are
driven by `m_fMoveSpeed`. The NPC-mode reaction block (`PED_FLEE_*`,
`PED_INVESTIGATE`) and the seek block (`PED_SEEK_*`, the chase) wrote the
state's speed straight in — 1.0 walk, 1.8 run, 2.5 sprint — so a WALK→RUN flip
moved the weights (walk 1/run 0 to 0.2/0.8) in one frame. A stock player ramps
at `0.07 * CTimer::GetTimeStep()`; a stock ped crossfades the incoming clip.

First attempt was a linear ramp at the stock player's acceleration; play said
it read fast and not NPC-like. The timing to match is the ped's own: a ped
flips the move state through `CAnimManager::BlendAnimation` at delta 1.0, and
`blendAmount += blendDelta * timeStepInSeconds` makes that a weight fade of
about one second, at the body's random tempo (`VCModCharacterMoveTempo` already
gives the player that tempo). The module's wander stroll already eases at
`min(1, step * 0.035)` — a one-second time constant — so the chase/flee ease
now uses the same rate.

Fix: `VCModNpcMoveSpeed(CPlayerPed*, float target)` in `vcmodnpc.cpp` eases
`m_fMoveSpeed` toward the state's target with the stroll's ease (both
directions; a target of 0 still stops instantly, as stock does). The six
constant writes in `PlayerPed.cpp` call it. With the mode off it returns the
target unchanged, so normal play and scripted seeks are byte-identical.

Harness: `test_vc_npcmode.py` pins the shape — one eased step, monotonic, about
two thirds across at 30 frames (the second the ped fade takes), converged by
3 s, the way back eases, stop snaps, mode off is stock — plus the six-call-site
wiring check; `test_vc_cop_chase.py` compiles the seek case and gained the
mode-off stub.

## Play feedback on build 589: wandering into a wall

Asked whether a wanderer walking into a wall is normal. Mostly yes, and it is
not from slice A:

- A ped's wander steers at straight-line `PATH_PED` nodes (`CPed::WanderPath`
  → `Seek`), with no lookahead around geometry. A corner node puts him head-on
  at a wall for a moment. Stock peds do the same; the wander already takes the
  ped's `m_distanceToCountSeekDone = 1.0f` radius for the player, which is what
  stops the old wide-corner cut across buildings.
- The escape is the engine's blocked reaction: the panic counter climbs while
  he is in control, in a walk/run move state and not travelling, and at 50
  frames (~1.7 s) it sets `WAITSTATE_STUCK` and the wander re-paths. The
  NPC-mode player takes the ped rule there (`VCModNpcBlockedReset`). The panic
  needs a collision with `m_fDamageImpulse > 0` on that frame, a condition a
  stock ped shares.
- One player-only leftover sits in the same block (`Ped.cpp:2573-2581`): a ped
  answers a small building/object impact with
  `SetDirectionToWalkAroundObject(collidingEnt)`; the player branch only sets
  `bHitSomethingLastFrame = true` and breaks. So an NPC-mode player can push
  against a fence or prop longer than a ped before the panic ends it. This is
  the likely cause if the wall contact reads as persistent rather than brief.

Recommendation: watch whether it self-resolves within a second or two with the
stuck step/turn. If it repeats, flip that branch to the ped path behind a
body predicate (same one-line shape as the combat flips) and verify in play.

## Harnesses

- New `utils/test_vc_npccombat.py`: predicate truth table, chooser priority and
  the one-shot slot, plus the slice-A wiring checks (predicate counts, the old
  gang gate gone, no immediate end, strength multiplier, VFX gates).
- `test_vc_combat.py`: the chooser seam replaces the player branch.
- `test_vc_ganggaze.py`: ownership tests replace the fight-driver tests; the
  predicate stub is in the stub block; `FinishedAttackCB` still clears a stray.
- `test_vc_npcmode.py`: cop borrow/restore test, COP threat row in the stub,
  new `BorrowIdentity` signature.
- `test_vc_gangfaction.py`: the `BorrowIdentity` signature and its four calls
  (not named in the plan; the harness compiles the function).

Two plan notes for the next slice:

- `braced()` cannot cut a body whose `#ifdef`/`#else` branches both carry `{`
  (`CPed::Fight`, `CPed::ChooseAttackPlayer`): more opens than the text closes.
  `test_vc_npccombat.py` has `up_to(marker, following)` for that; the combat
  harness slices to `CPed::EndFight`.
- The plan's stub sweep for `test_vc_cop_pistol`, `test_vc_weapon_recovery`,
  `test_vc_aimwalk` and `test_vc_windup` belongs to slice B: in this tree those
  harnesses do not compile the functions slice A flips, so no stub was needed.

## What to play (the user's turn)

1. BECOME NPC as a civilian body, then start a fist fight (bump a pedestrian or
   hit one). Expected: the body's own move set (punch; kick/roundhouse only
   where the stat allows), 0.8 anim speed, no Tommy combo chain, no one-shot
   swing, the fight holds its stance on the 2000 ms ped beat, and damage scales
   with the body's attack strength.
2. A cop body next: knee/punch only, 1× melee (the `STAT_COP` borrow), and the
   slower cop heading rate (7.5 vs 15) during the patrol.
3. Bumps can now start a real scuffle instead of walking around; watch for a
   shove loop while an objective runs.
4. Build 589's movement fix: a chase (and a flee) should cross from the walk
   clip to the run clip over a ped-like second instead of snapping.

Feature off must stay stock: normal play keeps the 500 ms wait, 1.0 speed,
combos, the one-shot swing, the 0.08 seek, player VFX and the spin kick.

## Uncommitted

`reVC/`: `src/extras/vcmodnpc.{cpp,h}`, `src/extras/vcmodcombat.{cpp,h}`,
`src/peds/PedFight.cpp`, `utils/test_vc_npcmode.py`, `utils/test_vc_combat.py`,
`utils/test_vc_ganggaze.py`, `utils/test_vc_gangfaction.py`,
`utils/test_vc_cop_chase.py`, new `utils/test_vc_npccombat.py`.
This handoff is the only change outside `reVC/`.

## Next steps

1. Play slice A as above; fix what play names before slice B starts. Open
   question from build 589: whether the wander's wall contact is the stock
   brief one (panic → stuck → re-path) or the player-only small-obstacle branch
   above; flip it only if play says it is persistent.
2. Slice B (guns): `VCModNpcWepAccuracy`, the `Attack`/`SetAttack` gun gates,
   no fast reload/streak/sprint breakout, the aim-feature stand-down
   (`VCModAimWalkWeapon`, `VCModCombatAimTick`, `PointGunAt` raise), and the
   body-driven cop pistol clip.
3. Slice C (receiving side): `InflictDamage` rules, `StartFightDefend`,
   `ReactToAttack`.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Engine files keep hook calls only; no new `#ifdef` feature gates.
- No commit, tag or push unless asked.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 589` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-stock-combat-design.md`,
> `docs/plans/2026-11-15-npc-stock-combat.md` and
> `docs/handoff/2026-11-15-npc-stock-combat-a.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Slice A (melee fight and profile) is
> uncommitted and installed; implement slice B (Task B1–B4, guns: stock
> accuracy, gun gates and perks, aim stand-down, body-driven cop pistol clip),
> test-first with `utils/test_vc_npccombat.py` and the named harness stubs.
> Feature off is stock; engine files keep hook calls only. Run all
> `utils/test_vc_*.py` (49), `scripts/build.sh`, then `scripts/install.sh` only
> with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, and confirm the installed
> `vcmods build` number before handing off. Open from build 589: whether the
> wander's wall contact is the stock brief panic/stuck/re-path or the
> player-only small-obstacle branch in `Ped.cpp:2573`; flip it only if play says
> it is persistent. In-game play is the user's turn. Write the handoff with a
> paste-ready prompt for slice C. Do not commit, tag or push unless asked; game
> data and the `uchg` anim files stay untouched.
