# Handoff: NPC-mode stock combat, slice B (guns)

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665` (nothing committed this session)
Installed: `vcmods build 591` in `~/Games/VC/reVC.app` (slice A shipped 589)
Harness: 49 harnesses green (`cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`)

## What slice B changed

Design: `docs/specs/2026-11-15-npc-stock-combat-design.md`, slice B.
Plan: `docs/plans/2026-11-15-npc-stock-combat.md`, Tasks B1–B4.

### Stock accuracy (B1)

`VCModNpcWepAccuracy(CPlayerPed*)` in `src/extras/vcmodnpc.cpp`: 60 for every
civilian, gang and non-police body; the police bodies' own `CCopPed`
constructor values while the COP profile runs (`MI_COP` 60, `MI_SWAT` 68,
`MI_FBI` 76, `MI_ARMY` 84, `MI_VICE1..8` 76, other bodies 60). The table is
`aVCModNpcCopAccuracy`. `VCModUpdateNpcMode` writes it every frame in place of
`VCModPlayerWepAccuracy`, so DOOM AIM no longer affects NPC mode; it stays a
player row.

### Gun gates and player perks (B2)

`src/peds/PedFight.cpp`, all behind `VCModNpcFightsAsPed(this)`:

- `Attack`: the reload clears the attack (`bIsAttacking = false` via
  `ClearAttack`); the player melee-start flag is off; a projectile throws
  without `m_bHaveTargetSelected`; an empty gun calls `SelectGunIfArmed`; no
  bat/katana weapon streak and no pad sprint breakout.
- `StartReloadNow`: no `m_bFastReload` in NPC mode, so the full reload time and
  the reload animation are the ped's.

### Aim stand-down and the cop clip (B3)

`src/extras/vcmodcombat.cpp`:

- `VCModCopTwoHandPose`: the worn body decides. In NPC mode a police body keeps
  the stock cop clip regardless of the COLT TWO-HAND row; a non-police body
  keeps its own weapon clip even with the row on. Normal play keeps the row.
- `VCModCopSetStance`: no-op for the NPC-mode cop (the pinning exists for
  Tommy's skeleton; the cop skeleton is the clip's authoring target).
- `VCModAimWalkWeapon` and `VCModCombatAimTick` stand down in NPC mode; the
  engine's stock ped aim parking runs instead.
- `CPed::PointGunAt`: the raise gate excludes the NPC-mode player, and the
  NPC-mode cop parks at the stock `m_fAnimLoopStart` instead of the player's
  `nVCModCopHoldFrame`.

### Harness notes

- `test_vc_npccombat.py`: accuracy table cases, the CopPed source guard, the
  body-driven cop pose matrix, the gun wiring count and the aim stand-down
  wiring.
- `test_vc_npcmode.py`: `m_wepAccuracy` on the stub, the accuracy write test.
- `test_vc_cop_pistol.py`: NPC cop-pose cases and the predicate stubs (both in
  `PRELUDE` and in the stance test's inline source).
- `test_vc_aimwalk.py`: predicate stub. `test_vc_windup.py`: the raise
  assertion follows the new condition.
- No stub was needed in `test_vc_weapon_recovery.py` (same finding as slice A:
  it reads `Attack`'s text but does not compile it). The plan's `test_vc_combat`
  cop-pose step was applied to `test_vc_cop_pistol.py`, which is where those
  decisions are actually compiled.

## What to play (the user's turn)

1. Civilian body, gunfight: accuracy sprays like a pedestrian (~60) instead of
   the player's 95/100; reload takes the full weapon.dat time and plays the
   reload clip; an empty gun switches to the next gun instead of holding an
   empty one; sprinting no longer breaks out of the fire animation; no
   bat/katana motion streak. DOOM AIM should do nothing while BECOME NPC runs.
2. Cop body with the colt: the two-hand cop clip plays with COLT TWO-HAND off,
   the legs are not pinned (no Tommy stance), and the aim parks on weapon.dat's
   frame. A pistol/uzi cop body picks its accuracy from the table above.
3. Non-police body with the colt and the row on: still one-hand, the body's own
   clip.
4. Feature off must stay stock: 95/100 accuracy, DOOM AIM, fast reload, weapon
   streak, sprint breakout, row-driven cop pose and AIM WALK.

## Still open from build 589

The wander's wall contact: stock brief panic/stuck/re-path versus the
player-only small-obstacle branch in `Ped.cpp:2573`. No play verdict yet; flip
it only if the contact reads as persistent.

## Uncommitted (slice A + B together)

`reVC/`: `src/extras/vcmodnpc.{cpp,h}`, `src/extras/vcmodcombat.{cpp,h}`,
`src/peds/PedFight.cpp`, `src/peds/PlayerPed.cpp` (slice A's move-speed ease),
`utils/test_vc_npcmode.py`, `utils/test_vc_combat.py`,
`utils/test_vc_ganggaze.py`, `utils/test_vc_gangfaction.py`,
`utils/test_vc_cop_chase.py`, `utils/test_vc_cop_pistol.py`,
`utils/test_vc_aimwalk.py`, `utils/test_vc_windup.py`, new
`utils/test_vc_npccombat.py`. This handoff is the only change outside `reVC/`.

## Next steps

1. Play slice B as above; fix what play names before slice C starts.
2. Slice C (receiving side), Tasks C1–C4: `InflictDamage` ped damage rules
   (defend weakness, bleed, limbs, no GANG7 immunity or fireproof exemption),
   `StartFightDefend` hit reactions, `FightHitPed` victim-side get-up/hit-step
   rules, `ReactToAttack` ped path. `ReactToPointGun` stays unchanged.
3. The open wander wall-contact question above.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Engine files keep hook calls only; no new `#ifdef` feature gates.
- No commit, tag or push unless asked.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 591` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-stock-combat-design.md`,
> `docs/plans/2026-11-15-npc-stock-combat.md`,
> `docs/handoff/2026-11-15-npc-stock-combat-a.md` and
> `docs/handoff/2026-11-15-npc-stock-combat-b.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Slices A and B are uncommitted and
> installed; implement slice C (Tasks C1–C4, receiving side: `InflictDamage`
> ped damage rules, `StartFightDefend` hit reactions, `FightHitPed` victim-side
> get-up and hit-step rules, `ReactToAttack` ped path; `ReactToPointGun` stays
> unchanged), test-first with `utils/test_vc_npccombat.py`. Feature off is
> stock; engine files keep hook calls only. Run all `utils/test_vc_*.py` (49),
> `scripts/build.sh`, then `scripts/install.sh` only with
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, and confirm the installed
> `vcmods build` number before handing off. Open from build 589: whether the
> wander's wall contact is the stock brief panic/stuck/re-path or the
> player-only small-obstacle branch in `Ped.cpp:2573`; flip it only if play says
> it is persistent. In-game play is the user's turn. Write the handoff with a
> paste-ready prompt for the final close-out. Do not commit, tag or push unless
> asked; game data and the `uchg` anim files stay untouched.
