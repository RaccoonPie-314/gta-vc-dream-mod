# NPC mode: personality follows the worn model; strong Tommy — built, installed, awaiting play

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Installed `vcmods build 405` into `~/Games/VC/reVC.app` with no session running.
No commit, tag or push was made. Previous handoff:
`docs/handoff/2026-11-12-npc-seat-objective.md`.

## The request

In CIVILIAN NPC mode the behavior should follow the selected body: an ordinary
model cowers/flees/fears by its own stock numbers, a tough model shrugs off
gunshots and fights. Tommy's own body must never flee or cower as a "weak"
ped: he investigates corpses and blasts instead of running, keeps the stock
hands-up reaction at a pointed gun, and gets the strong/pushy temperament.
Normal bodies stay normal. GANG keeps its Vercetti aggression, COP is unchanged.

## Why it did not follow the body

Stock peds take their personality from the model: `CPed::SetModelIndex`
applies `CPedModelInfo::m_pedStatType` (Ped.cpp:454), and `data/pedstats.dat`
holds fear, temper, lawfulness, attackStrength, defendWeakness and flags
(`STAT_GUN_PANIC` is the panic-at-guns bit). The mod erased that in two places:
`VCModApplyPedModel` forced `PEDSTAT_PLAYER` after every body change, and
`VCModReconcilePedModel` re-forced it every frame on respawn.

The visible strong-ped behaviors all come out of those numbers, not separate
code: temper against the other ped's fear decides who flinches in
`CPed::ProcessCollision` (PedFight.cpp:3864), fear 0 / temper 100 makes every
gunshot and attack branch pick the fight, and `STAT_GUN_PANIC` is the
hands-cower. The corpse flee is the exception — in `CPed::CivilianAI` a body
under 5 m flees regardless of stats (Ped.cpp, DEADPEDS branch), 5-10 m
investigates.

## What was built

1. **The civilian profile borrows the worn body's stock stat** while it drives
   him (`VCModUpdateNpcMode`), the same borrow/release the GANG profile already
   used, now shared (`bVCModNpcStatsBorrowed`, `VCModNpcRestoreStatBorrow`).
   `VCModNpcCivilianBodyStats` resolves the model's `m_pedStatType`; a model
   without a usable ped stat falls back to the player line. The body's
   `m_headingChangeRate` is applied with the borrow and restored on release.
   `VCModReconcilePedModel` leaves an active borrow alone.
2. **Tommy's own body gets a strong variant** (`VCModNpcStrongStats`): a copy
   of `PEDSTAT_PLAYER` with `m_fear = 0`, `m_temper = 100`, `STAT_GUN_PANIC`
   cleared; attack/defence/flags/name stay stock. The shared PLAYER stat object
   is never modified, so normal play and every other ped are untouched.
3. **Reaction gates for the strong variant** (`VCModNpcStrongActive`: mode on,
   civilian profile, wearing MI_PLAYER):
   - gunshot threat → `OBJECTIVE_KILL_CHAR_ON_FOOT` at the shooter instead of
     any flee/report branch;
   - fresh corpse → the stock investigate branch at any distance (the
     killer-within-10 m suppression still applies, as stock);
   - explosion → investigate, never the run-away branch;
   - attacked → the unarmed-vs-gun flee branch is skipped; he takes the fight;
   - seated threat scan → he keeps the seat instead of standing up to flee.
   Hands-up at a pointed gun is stock and deliberately kept (your call).
4. **The civilian profile now owns engine combat** for `KILL_CHAR_*`
   objectives (`npcCombatProfile` includes `VCModNpcCivilianActive`), the same
   `Attack()` / `Fight()` / `PointGunAt()` ownership gang and cop already had.
   Without it a civilian fight objective dead-ended in the aim beat — any
   stock strong body, not just Tommy, would stand there after picking a fight.

## Still stock

Other bodies keep the stat-free corpse/explosion flee, vehicle and fire flee,
sunbathe get-up, and their model's own numbers. GANG still borrows the GANG7
stat and its kin bit, COP still keeps the mission setup.

## Log tell

`VCMOD npc body: model=.. stat=.. fear=.. temper=..` prints whenever the
borrowed personality changes (mode start, body change). For Tommy's body it is
`stat=0 fear=0 temper=100`.

## Verification

- New `utils/test_vc_npcstrong.py` — 9 checks: strong variant values (fear 0,
  temper 100, panic bit cleared, stock bits/melee numbers kept, distinct from
  the shared line), body-stat resolution and fallbacks, the strong predicate,
  and source pins for the five reaction gates.
- `test_vc_npcmode.py` 32 (new: body personality borrowed then restored, with
  the heading rate; gang→civilian switch now lands on the body stat).
- `test_vc_ganggaze.py` 9: all three profiles own combat; a plain player does
  not.
- `test_vc_character.py` 6: reconcile leaves an active borrow alone.
- Full suite 265/265. Release build green. Installed build 405. **Not yet
  confirmed in play.**

## Next steps

1. Play CIVILIAN with Tommy's own body: fire a shot near him → he should turn
   and fight the shooter; leave a corpse under 5 m → investigate, not flee;
   blow a car up near him → walk over, not run; let a gun be pointed at him →
   the hands-up reaction still plays.
2. Wear another body (tough vs ordinary) and confirm the reactions match that
   model's stock numbers (`VCMOD npc body` line shows the stat).
3. Confirm a fight completes (he attacks and the target goes down) instead of
   standing in the aim beat.
4. Then strip the temporary diagnostics (`VCMOD wander:`, `civ layer`,
   `threat:`, `corpse:`, `react move:`, `talk:`, `voice:`, `id line:`,
   `npc body:`) and commit the NPC topic.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Never install while `pgrep -x reVC`
returns anything. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are uchg.
Crew ownership and chat are unchanged by request.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 405.
> Read `docs/handoff/2026-11-12-npc-strong-personality.md` first. In CIVILIAN
> NPC mode the personality now follows the worn model's stock CPedStats, and
> Tommy's own body is a strong variant (fear 0 / temper 100, no gun panic) that
> fights gunshots and attackers, investigates corpses and explosions, never
> flees, keeps the hands-up reaction. The civilian profile now owns engine
> combat for kill objectives. Play-test with Tommy's body and with another body,
> check `VCMOD npc body` in the log, then strip the temporary probes and commit.
> Never commit/push on the play-tester's behalf. Game data, settings, savegames
> and the uchg anim files are read-only; never install over a running session.
