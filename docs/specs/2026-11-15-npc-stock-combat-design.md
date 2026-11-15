# NPC mode: the player fights as the worn NPC — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`.
Installed build `vcmods build 582`. Status: design approved 2026-11-15,
implementation pending. 48 harnesses green at the time of writing.

## Goal

While BECOME NPC runs, the player ped's combat is the stock NPC's combat. The
same fight entry, move chooser, fight state and timing, damage numbers, gun
accuracy and hit reactions as a pedestrian of the worn body. Feature off is
stock, byte for byte.

"Tommy still uses his own combat profile, moves, animation and state" is the
report this answers: the previous session fixed the accuracy write, the aim
ramp and the burst end, but the fight code still takes the player branches that
exist for a human trigger.

## Approved decisions

- **Full ped combat.** Outgoing and receiving sides: how he attacks and how he
  is hit, reacts and dies.
- **Body decides animation.** A worn NPC body already uses its model's anim
  group (`vcmodcharacter`); Tommy's own body keeps `ASSOCGRP_PLAYER`. No anim
  group override is added.
- **Delivery in three playable slices**, one installed build each:
  A melee fight + profile, B guns, C receiving side. Each slice is independently
  revertible because every flip sits behind one predicate.

## Evidence: what is still the player's today

All sites in `src/peds/PedFight.cpp` unless noted.

| Behaviour | Player branch | Ped branch |
| --- | --- | --- |
| Melee entry | `SetAttack` takes `PED_ATTACK` + `ANIM_MELEE_ATTACK_START` | `StartFightAttack` → `PED_FIGHT` |
| Move choice | `ChooseAttackPlayer` (combos, angle footwork) | `ChooseAttackAI` (pedstat flags: punch-only, knee, kick, roundhouse, bags) |
| Fight state | `Fight` ends the fight as soon as a move finishes; 500 ms wait | stays in `PED_FIGHT`; 2000 ms wait |
| Fight timing | anim `SetCurrentTime(0.08)`, speed 1.0, combo chain | from 0, speed 0.8, no combo |
| Melee damage | `m_attackStrength` skipped (adrenaline only) | damage × `m_pedStats->m_attackStrength` |
| Gun aim gate | player may aim with no live/controlled victim | waits for a controlled victim |
| Gun perks | fast reload, sprint breakout, weapon streak | none |
| Accuracy | 95 aimable / 100 other / 60 DOOM AIM | 60, cops 60/68/76/84 |
| Empty gun | player keeps an empty gun | switches to another gun |
| Pistol clip | cop pose only behind the COLT TWO-HAND row | cop body gets `colt45_cop` |
| Damage taken | `damage × 0.33`, no limb loss, no bleed | `damage × m_pedStats->m_defendWeakness`, ped limb/bleed rules |
| Hit reaction | running player plays HITBYGUN one-shot | fight/fall reaction |
| Reacting to attack | inform gang + look | fight/flee per stat |
| Bump shove | NPC mode walks around (`CollideWithPed`) | shoves back |

## The predicate

New in `src/extras/vcmodnpc.{cpp,h}`:

```cpp
// true when this ped is the player and NPC mode owns his combat: every engine
// branch that exists for a human trigger takes the ped path on this answer
bool VCModNpcFightsAsPed(CPed *ped)
{
	return ped != nil && ped->IsPlayer() && bVCModNpcMode;
}
```

Implemented in terms of the existing `VCModNpcCombatActive()` (which stays the
no-arg mode predicate used by the combat module's aim features).

Engine files keep hook calls only: each site becomes a predicate call or a
one-line branch. Every flip reads `VCModNpcFightsAsPed(ped)` so the mode-off
path evaluates exactly as today.

## Helper seams (vcmodcombat)

```cpp
// the fight move chooser: the forced-move slot first (the spin kick command),
// then the ped chooser while NPC mode owns the body, the player chooser
// otherwise. Moving the take here from ChooseAttackPlayer keeps the one-shot
// slot working for both choosers.
int32 VCModCombatChooseMove(CPed *ped, uint8 buttonPressure, bool fightWithWeapon);
```

`ChooseAttackPlayer` loses its own slot take; both call sites in
`StartFightAttack` and `Fight` go through the helper. The spin kick keeps
working in normal play and in NPC mode.

## Slice A — melee fight and profile

### Fight path

- `CPed::SetAttack`:
  - reload gate takes the ped path (`bIsAttacking = false`);
  - melee entry: `IsPlayer() && !VCModNpcFightsAsPed(this)` takes the
    `PED_ATTACK` one-shot branch; otherwise `StartFightAttack(random)`;
  - partial-attack gait check takes the ped move-state path;
  - obstacle during a kill objective (`bObstacleShowedUpDuringKillObjective`)
    runs for the ped path;
  - point-blank start-fight gate takes the ped condition;
  - the aim-start gate drops the player exemption, so an NPC-mode player waits
    for `victimPed->IsPedInControl()` like a ped (this replaces the earlier
    gang-only special case).
- `CPed::ClearAttack`: the ducking gate takes the ped path.
- `CPed::StartFightAttack`: chooser through `VCModCombatChooseMove`; no
  `SetCurrentTime(0.08)` and no combo-counter reset for the ped path.
- `CPed::Fight`: no immediate `EndFight` after a move; 2000 ms wait; ped anim
  speed; no player combo chain; ped attack sound; no katana streak; ped
  `SetCurrentTime(0)` on a re-chosen move.
- `CPed::FightHitPed`: melee damage × `m_pedStats->m_attackStrength` when not
  the normal-play player; the `unk2` hit-step value takes the ped rule for a
  victim that is the NPC-mode player; no extra player blood particles; the
  player knockdown rule is off.
- `CPed::FightStrike`: no player glass break.
- `CPed::CollideWithPed`: the NPC-mode "walk around instead of shoving" bypass
  goes. The ped fight path now owns the shove; a bump starts a real scuffle.
- `VCModNpcCombatControl` simplifies to the ownership answer: any
  `PED_ATTACK`/`PED_FIGHT`/`PED_AIM_GUN` in NPC mode is AI-entered, so the
  manual `StartFightAttack` re-press, the `SetAttackTimer` writes and the stray
  `ClearAttack`/`EndFight` cleanup go. `PED_IDLE` keeps the walk freeze while a
  live target is owned. `VCModNpcCombatOwnsControl` stays as the "live target"
  answer for that freeze and the camera gates.

### Profile

- `VCModNpcBorrowIdentity` gains a cop case: a COP-profile player borrows the
  worn body's pedstat (`STAT_COP` for police bodies) and the COP threat flags,
  exactly as CIVILIAN/GANG already borrow theirs. Without it the cop chooser
  uses `STAT_PLAYER` (can kick, 3× melee) instead of `STAT_COP` (knee only,
  1×). The existing save/restore covers the new borrow.

## Slice B — guns

- New `VCModNpcWepAccuracy(CPlayerPed*)` in `vcmodnpc.cpp`, written every frame
  from `VCModUpdateNpcMode` in place of `VCModPlayerWepAccuracy`:
  - non-COP profile → 60 (the `CPed` constructor's value; every pedestrian and
    gang ped is 60);
  - COP profile → the stock cop value by body: `MI_COP` 60, `MI_SWAT` 68,
    `MI_FBI` 76, `MI_ARMY` 84, `MI_VICE1..8` 76, other police bodies 60.
  - DOOM AIM therefore no longer affects NPC mode; it stays a player row.
- `CPed::Attack` / `SetAttack` gun gates take the ped path:
  - reload keeps `bIsAttacking = false` and clears the attack;
  - a projectile throws without `m_bHaveTargetSelected`;
  - an empty gun calls `SelectGunIfArmed`;
  - no screen-level weapon streak and no pad sprint breakout;
  - the player melee-start clause is off.
- `CPed::StartReloadNow`: no `m_bFastReload` in NPC mode.
- `VCModAimWalkWeapon` excludes NPC mode; `VCModCombatAimTick` returns false
  for the NPC-mode player so the engine's stock aim parking runs; the
  `PointGunAt` raise gate excludes NPC mode.
- Cop pistol clip, body-driven:
  - `VCModCopTwoHandPose` in NPC mode returns true only when the active profile
    is COP (police body), regardless of the COLT TWO-HAND row; non-police
    bodies keep their own weapon clips;
  - `VCModCopSetStance` no-ops for the NPC-mode cop (the cop skeleton already
    matches the clip; the pinning exists for Tommy's skeleton);
  - `PointGunAt` uses the stock `m_fAnimLoopStart` for the NPC-mode cop instead
    of the player's handy hold frame.

## Slice C — receiving side

- `CPed::InflictDamage`:
  - `healthImpact = damage * m_pedStats->m_defendWeakness` instead of ×0.33;
  - the bleed counter, limb removal, `dontRemoveLimb` exemption and explosion
    dismemberment take the ped rules;
  - the player-only GANG7 immunity and the `m_bFireproof` exemption are skipped;
  - `m_bCanBeDamaged` stays (it is false only during arrest/safe mode, which
    already breaks the mode) and `AnnoyPlayerPed` stays (camera feedback).
- `CPed::StartFightDefend`: the running-player HITBYGUN branch, the player
  knockdown exemptions and the 1.2 anim speed take the ped path.
- `CPed::FightHitPed`: the player get-up immunity does not apply to the
  NPC-mode player as victim.
- `CPed::ReactToAttack`: every NPC profile takes the ped reaction (the current
  early branch is player + not civilian/gang, so the cop still takes it). The
  ped path already routes gang mode through `VCModGangFightBack` and strong
  Tommy through `VCModNpcStrongActive`.
- `CPed::ReactToPointGun` is already profile-correct and does not change: a cop
  returns (a stock cop does not hands-up) and civ/gang take the ped path.

## What stays the player's, by design

- Human feedback, not NPC behaviour: screen shake on chainsaw contact,
  `AnnoyPlayerPed` camera feedback, HUD and notice text.
- World identity: `m_nPedType` remains `PLAYER1`; wanted level, havoc, media
  attention, rampage counters and kill credit still see the player.
- Attacker-side AI special-casing of the player as a victim (cop arrest and
  pursuit, `FindMeleeAttackPoint`, no-police-zone rules, vehicle drag). Enemies
  still treat him as the player. This is a named boundary, not an oversight: it
  is what keeps missions, wanted and arrest away from the fight change.
- The adrenaline pill's 20× melee multiplier survives in NPC mode (deliberate
  player power-up, checked before the stat multiplier).
- The spin kick command keeps working (forced-move slot).

## Named consequences

- **Tommy's body becomes the data's strong ped.** The CIVILIAN strong variant
  is a copy of `STAT_PLAYER`: attack 3.0, defence 0.4, flags knee+kick. With
  the ped path the attack multiplier now applies, so melee is 3× and incoming
  damage ×0.4 instead of the player's ×0.33. This is the worn body deciding,
  per the approved rule. One number flips it later if play disagrees.
- **NPC-mode bodies get much squishier.** Civilian/gang `defendWeakness` is
  around 1.0–1.4 versus the player's 0.33; a cop body is 1.0. Stock.
- **Cop profile changes turn rate and personality numbers.** Borrowing
  `STAT_COP` brings heading rate 7.5 (was 15), fear 10, temper 30, lawfulness
  100. These are the stock cop's. The ID-check turn and patrol feel may need a
  play check.
- **Bump scuffles return.** Removing the walk-around bypass means a bump can
  start a fist fight, as it does for a stock ped. If the shove loops in play,
  the bypass is a one-line revert.
- **Gun accuracy drops.** A civilian/gang body goes from 95 to 60 accuracy in
  NPC mode; cops use their stock values.

## Testing

- New harness `utils/test_vc_npccombat.py`: compiles the extracted decision
  functions and asserts the matrix — predicate truth table, chooser priority and
  one-shot slot, accuracy table, cop pose rule, and the engine wiring checks
  (the old `IsPlayer()` conditions are gone, the predicate calls are present).
- Extend `utils/test_vc_npcmode.py`: the `VCModNpcBorrowIdentity` signature
  gains the cop flag (the existing extraction list must be updated or the
  harness will not compile), the cop borrow/restore, and the accuracy write.
- Extend `utils/test_vc_combat.py`: `VCModCombatChooseMove`, the cop pose
  rule, and the chooser wiring.
- Extend `utils/test_vc_ganggaze.py`: the simplified combat ownership (no
  manual `StartFightAttack`/`SetAttackTimer`, no stray cleanup, the state is
  owned) and the unchanged `FinishedAttackCB` ending.
- Harness stub sweep: the harnesses that compile a flipped engine function
  (`test_vc_cop_pistol`, `test_vc_weapon_recovery`, `test_vc_aimwalk`,
  `test_vc_windup`, `test_vc_ganggaze`) gain the predicate and cop-profile
  stubs, and the windup assertion follows the new raise condition.
- Full suite: 49 harnesses, `cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`.
- Build with `scripts/build.sh`, install with `scripts/install.sh` only when
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` is empty, confirm the installed
  build number.
- Play check per slice: A fist fight against a pedestrian as a civilian body
  (moves, stance, no Tommy combos, no one-shot swing, damage strength), then a
  cop body (knee/punch only); B gunfight accuracy and reload; C taking hits.

## Risks and rollback

- The largest risk is the cop stat borrow (personality/heading). It is isolated
  in `VCModNpcBorrowIdentity` and reverted by dropping the cop branch.
- `VCModNpcCombatControl` simplification is the second risk (a combat state that
  never ends). The engine's own `Fight`/`ClearAttack`/`ProcessObjective` end
  states; if play shows a stuck state, the cleanup returns behind the same
  predicate.
- Every flip is a one-line predicate branch; reverting a slice means restoring
  the player condition at its sites, with the harness failing until it is
  restored.
- Game data stays read-only; no `anim/` file is touched; no `#ifdef` in mod
  code; portability holds.

## Files

- Modify: `src/extras/vcmodnpc.{cpp,h}`, `src/extras/vcmodcombat.{cpp,h}`,
  `src/peds/PedFight.cpp`, `src/peds/PedAI.cpp` (ReactToAttack), `src/peds/CopPed.cpp`
  not needed (values are read, not changed).
- Create: `utils/test_vc_npccombat.py`.
- Extend: `utils/test_vc_npcmode.py`, `utils/test_vc_combat.py`.
- Docs: `docs/architecture.md` debt sizes if a module crosses the split signal;
  handoff per slice.
