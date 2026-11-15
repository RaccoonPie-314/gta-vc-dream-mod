# Handoff: NPC-mode stock combat, slice C (receiving side)

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665` (nothing committed this session)
Installed: `vcmods build 593` in `~/Games/VC/reVC.app` (slice B shipped 591)
Harness: 49 harnesses green (`cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`)

Slice C completes the three-slice feature: while BECOME NPC runs, the player
fights, shoots and takes damage as the worn ped. All three slices are
uncommitted and installed.

## What slice C changed

Design: `docs/specs/2026-11-15-npc-stock-combat-design.md`, slice C.
Plan: `docs/plans/2026-11-15-npc-stock-combat.md`, Tasks C1–C4.

Every flip is a one-line branch behind the slice-A predicate
`VCModNpcFightsAsPed(...)`, so mode off is the stock path byte for byte.

### Damage taken (C1)

`src/peds/PedFight.cpp`, `CPed::InflictDamage`:

- `healthImpact` uses `damage * m_pedStats->m_defendWeakness` instead of the
  player's `damage * 0.33f`.
- The bleed counter (knife, screwdriver, cleaver..chainsaw) is the ped's.
- Gunshot limb removal is the ped's (`dontRemoveLimb` only for a normal-play
  player or `bNoCriticalHits`); `RemoveBodyPart` now runs for the worn body.
- Explosion dismemberment (`CGame::nastyGame`, lethal impact) runs for the
  worn body.
- The player-only GANG7 damage immunity and the player's `m_bFireproof`
  exemption are skipped, so gang members and fire hurt him as they hurt a ped.
- Kept as player's: the `m_bCanBeDamaged` arrest/safe gate and
  `AnnoyPlayerPed(false)` camera feedback. Kill credit, havoc, media attention,
  the health/armour loss timestamps and drowning stats are untouched (world
  identity stays the player's).

### Hit reactions (C2)

`CPed::StartFightDefend`:

- No running-player HITBYGUN one-shot: the worn body takes the ped reaction
  (fight-move set or fall per hit level and direction).
- The low-hit knockdown coin flips take the ped rule, so a back hit at
  `HITLEVEL_LOW` always falls him (the stock player only falls by a random
  chance under 30 HP).
- No 1.2 anim speed on the fight move (the ped speed is whatever the clip is).
- The player-with-gun reaction branch is off, so he reaches the stock
  `SetPedState(PED_FIGHT)` fight-idle entry.

`CPed::FightHitPed` (victim side):

- No `PED_GETUP` immunity for the worn body: a melee hit during get-up lands.
- The ped hit-step value (`unk2 = 101`, `ANIM_HIT_BIGSTEP`) reaches him when the
  attacker holds a non-unarmed weapon outside fight mode.

### Reacting to an attack (C3)

`src/peds/PedAI.cpp`, `CPed::ReactToAttack`: the early player branch now reads
`IsPlayer() && !VCModNpcFightsAsPed(this) && attacker->IsPed()`. Every NPC
profile takes the ped reaction; the delta is the COP profile, which previously
took the player path (inform the gang, look at the attacker) and now fights or
flees per the borrowed cop stat. Civilian and gang profiles already fell
through: the ped path routes gang mode through `VCModGangFightBack` and strong
Tommy through `VCModNpcStrongActive`. The kin gate stays ahead of the reaction.

`CPed::ReactToPointGun` is unchanged, as designed: a cop returns (stock cops do
not hands-up), civ/gang take the ped path.

### Harness

`utils/test_vc_npccombat.py` gains `SliceCWiring` (4 tests): the damage-rule
flips with each line pinned, the hit-reaction flips and the predicate count,
the victim-side get-up/hit-step lines, and `ReactToAttack`'s new condition with
the kin gate still first. The four harnesses that read these functions
(`test_vc_copcover`, `test_vc_gangfaction`, `test_vc_ganggroup`,
`test_vc_npcstrong`) only read text; their assertions still hold and none
needed a stub.

`docs/architecture.md` debt: the `PedFight.cpp` / `PedAI.cpp` mod-line counts
and the `vcmodcombat` / `vcmodnpc` sizes are now measured (79 / 20 lines,
559 / 809 lines). No module crossed the 1,000-line split signal.

## The feature as a whole

- **Slice A (build 589):** melee entry, `ChooseAttackAI` chooser, ped fight
  state (2000 ms beat, 0.8 speed, no Tommy combos), melee damage × body attack
  strength, no player VFX, real bump scuffles, COP profile stat/threat borrow.
  Plus the 589 movement fix: `VCModNpcMoveSpeed` eases chase/flee walk↔run at
  the ped fade rate instead of snapping.
- **Slice B (build 591):** stock gun accuracy (60; police bodies their
  `CCopPed` value), ped reload/empty-gun/projectile gates, no fast reload or
  sprint breakout, AIM WALK/aim tick stand down, body-driven cop pistol clip,
  stock aim park frame.
- **Slice C (build 593):** the receiving side above.

## What to play (the user's turn)

1. **Civilian body, taking a beating:** start a fist fight and lose a few hits.
   Expect the body's defence (civilian `defendWeakness` ≈ 1.0–1.4, roughly
   three times the player's 0.33, so hits hurt), the ped reaction animations
   instead of the running HITBYGUN one-shot, and a melee hit during get-up
   landing. A knife or screwdriver hit bleeds.
2. **Gang body:** the same, plus the attack reaction routes through the gang
   flee/fight split; kin never wound kin.
3. **Cop body:** throw a punch at a pedestrian and let him swing back. The cop
   body takes the ped reaction now — fight or flee per the cop stat — instead
   of the player inform-gang/look. Defence is 1.0.
4. **Bullets and explosions:** a lethal shot can take a limb (ped rules), and a
   lethal explosion in a nasty-game session can dismember him. Both are the
   stock ped outcomes.
5. **Player-only rows stop covering him:** FIREPROOF no longer protects the
   worn body from molotov/flamethrower, and GANG7 pedestrians can damage him.
6. **Feature off must stay stock:** 0.33 damage, no limb loss, get-up immunity,
   the HITBYGUN one-shot while running, GANG7 and fireproof exemptions, the
   inform-gang attack reaction.
7. **Slices A and B still stand:** the fight set/stance, the 589 chase ease,
   gun accuracy/reload/empty-gun switch, and the cop colt clip.

## Still open from build 589

The wander's wall contact: stock brief panic → stuck → re-path versus the
player-only small-obstacle branch in `src/peds/Ped.cpp:2573`. No play verdict
yet; flip it only if the contact reads as persistent. If flipped, it takes the
same one-line predicate shape and earns a wiring check in
`test_vc_npccombat.py` or `test_vc_wander.py`.

## Uncommitted (slices A + B + C together)

`reVC/`: `src/extras/vcmodnpc.{cpp,h}`, `src/extras/vcmodcombat.{cpp,h}`,
`src/peds/PedFight.cpp`, `src/peds/PedAI.cpp`, `src/peds/PlayerPed.cpp`
(slice A's move-speed ease), `utils/test_vc_npcmode.py`,
`utils/test_vc_combat.py`, `utils/test_vc_ganggaze.py`,
`utils/test_vc_gangfaction.py`, `utils/test_vc_cop_chase.py`,
`utils/test_vc_cop_pistol.py`, `utils/test_vc_aimwalk.py`,
`utils/test_vc_windup.py`, new `utils/test_vc_npccombat.py`.
Outside `reVC/`: this handoff and the `docs/architecture.md` debt update.

## Close-out (after play)

When play signs off the feature:

1. Commit the three slices to `vcmods` (one commit is fine; the message names
   the feature and every area it touched).
2. Regenerate `vc-mods.patch` — it is stale relative to the tree (architecture
   debt).
3. The Windows package (`Play.bat` portable folder) is still not built; slice
   A–C code is platform-neutral and the design asks for that equivalent.
4. Publish to `./gta-vc-dream-mod` main only when asked; `scripts/publish.sh`
   owns the provenance record, which names the build host and no other party.
5. If any play report contradicts a slice, the fix is a predicate branch at the
   named site; the harness fails until the flip is restored.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Engine files keep hook calls only; no new `#ifdef` feature gates.
- No commit, tag or push unless asked.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`,
> installed `vcmods build 593` in `~/Games/VC/reVC.app`. Read
> `docs/specs/2026-11-15-npc-stock-combat-design.md`,
> `docs/plans/2026-11-15-npc-stock-combat.md` and the handoffs
> `docs/handoff/2026-11-15-npc-stock-combat-{a,b,c}.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Slices A, B and C are uncommitted and
> installed; slice C (receiving side: `InflictDamage` ped damage rules,
> `StartFightDefend` hit reactions, `FightHitPed` victim-side get-up/hit-step
> rules, `ReactToAttack` ped path) is the final slice. Close-out: take the play
> verdicts for all three slices, and only act on what play names. Open from
> build 589: whether the wander's wall contact is the stock brief
> panic/stuck/re-path or the player-only small-obstacle branch in
> `src/peds/Ped.cpp:2573` — flip it only if play says it is persistent. When
> play signs off and only when asked: commit `vcmods`, regenerate
> `vc-mods.patch`, build the Windows portable folder, and publish per
> `scripts/publish.sh`. Keep the harness green (`cd reVC/utils && for f in
> test_vc_*.py; do python3 "$f"; done`, 49), install only with
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, and confirm the installed
> `vcmods build` number. In-game play is the user's turn. Do not commit, tag or
> push unless asked; game data and the `uchg` anim files stay untouched.
