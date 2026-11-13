# NPC mode: standstill freeze after ID check and in an armed chase (2026-11-13)

Workspace `vc-mod`, reVC `reVC/`, branch `vcmods`, HEAD `bb3fe88`. Installed
build `480` (was 479); all 45 `utils/test_vc_*.py` suites pass (41 tests in the
NPC harness). No commit, tag or push.

## Report

Play test on 479: after a cop ID check, NPC-Tommy stands until a wait animation
plays; in an armed criminal chase he stands and fires without closing on the
target. Both were described as new after the file-split refactor.

## Root cause

The working-tree splits did not introduce it: `Ped.cpp:2537` (the blocked-path
gate) and the wait handling came in with the committed NPC-mode drop `bb3fe88`.

The gate put an NPC-mode player on the blocked-ped reaction branch
unconditionally:

```cpp
(!IsPlayer() || (!bIsStuck && !bVCModNpcMode))
```

`bIsStuck` is only ever set by player controls, and the `!bVCModNpcMode` factor
made the whole collision test false for the mode. So the panic counter climbed
on every standstill with a stale WALK/RUN move state (its reset needs a
move-state/`m_fDistanceTravelled` change, `Ped.cpp:2519`), reached 50 in about a
second and called `SetWaitState(WAITSTATE_STUCK)` (`Ped.cpp:2548`). The tired /
scratch / turn-180 chain then owns the body until its timer ends.

Log evidence (build 479, `~/Games/VC/reVC.log`, pre-fix):

- `id check done dist=1.0` -> `id hold set (3000 ms)` -> one second later
  `state=1 wait=12` (STUCK) through the hold, then `state=5 wait=12 speed=0.00`
  while the pedestrian walks away (dist 0.9 -> 7.3).
- Chase dispatch at 17.5 m -> `state=16 wait=12`; further dispatches at 16.6 m
  freeze too, and the target runs to 41.6 m while `state=7 move=1 wait=12`.
- `VCMOD npc kill: state=16 wait=12 pose=1` completes the objective from that
  frozen pose.

## Fix

`VCModNpcBlockedReset(bool isPlayer, bool impact, bool stuck)` in
`src/extras/vcmodnpc.cpp` (declared in `vcmodnpc.h`), called from the gate:

- ped: reset unless a real impact (`!impact`);
- stock player: reset unless impact or the controls' stuck flag
  (`!impact && !stuck`, unchanged);
- NPC-mode player: the ped rule (`!impact`) - no pad, so a standstill is never
  a block; a real collision still starts the stock panic.

`Ped.cpp` keeps only the hook call. This also restores the intended collision
reaction for a tree or car without the old false positive.

## Verification

- New harness `test_an_npc_mode_standstill_is_not_a_blocked_path` covers the
  full matrix (ped, stock player, NPC-mode player, impact, stuck).
- All 45 suites pass; `scripts/build.sh` builds cleanly (build 480); installed
  with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. The installed binary
  reports `vcmods build 480`.
- In game: not yet played.

## Change: the cop keeps no after-kill pose (build 484)

The hands-behind-back + scratch pose is the pedestrian `WAITSTATE_DOUBLEBACK`
(3500 ms, trimmed to 3000 ms when the handler blends `XPRESS_SCRATCH` at 1 s;
stock upstream `Ped.cpp:8208` / `8435`). The cop is a mission char in stock and
goes straight back to patrol, so the completion in `PedAI.cpp` now gates the
pose on `npcKillCompleted && !VCModNpcCopActive()`: civilians and gangs keep
it, the cop skips it and resumes the wander from the same `SetWanderPath` call.
The stuck fix is untouched (separate gate in `Ped.cpp`).

Harness `test_pedestrian_profiles_hold_the_stock_pose_after_a_kill` now expects
the pose for GANG/CIVILIAN and no pose for COP. Build 484 installed with no
session; unplayed.

## Follow-up: "hunting stops after 2-3 times" (build 481 log)

Not a latch. After the last player hunt (`VCMOD cop: state=... obj=8` at
`reVC.log:54617`) the cop diag kept reporting `obj=0, ctrl=1, wanted=0,
state=5` for the rest of the mode-on time (~2.4 min over three short sessions),
so `CopPatrolScan` kept running; he also kept chatting/ID-checking pedestrians
from the same near-ped list. The last "2-3 hunts" were three engages on the
same criminal inside 20 s; that chase ended with the target out of range at
51.5 m and the objective cleared normally (`pose=0`), then he patrolled.

The scan (`Ped.cpp:2018`) only accepts a random-spawned `PEDTYPE_CRIMINAL` or
gang ped that is in control and not already fleeing from another cop, and it
only looks at the 10 nearest peds inside ~30 m (`Ped.h:642`). In the same
window other cops made four chase dispatches elsewhere, and the peds near
Tommy were civilians. So: no eligible target nearby, not a stuck mode.

Optional scope change if more hunting is wanted: let the NPC-mode player take
over a criminal that is already fleeing from another cop (drop
`anotherCopChasesHim` for him). **Declined 2026-11-13: the skip is the stock
rule (upstream `CCopPed::CopAI`, `CopPed.cpp:527-541`), so it stays. Do not
re-propose.** Two cops on one criminal still happens when both scan before the
criminal's `PED_FLEE_ENTITY` land, when the flee is from a non-cop, after the
6 s flee-till-safe ends, or from attack reactions (which bypass the scan).

## Next

1. Play-test build 484: kill a criminal on foot as the cop and confirm he goes
   straight back to the patrol (no hands-behind-back/scratch); re-check that the
   ID-check walk-off and the chase pursuit from build 480 still hold.
2. If he still holds his ground while the criminal is in view, that is the stock
   armed objective firing from the weapon's full range (seek only starts beyond
   it). The removed build-472 close-in divisor was not stock; re-adding it is a
   separate scope decision, one parameter hook, not a state write.
3. The remaining profile passes and one chase run from the 1:1 audit stand.

## Files not to touch

Game data is read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before
any install. Do not re-introduce `bIsStuck` gating for the NPC-mode player.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 484 is
> installed. Read `docs/handoff/2026-11-13-npc-wait-freeze.md` first, then
> `docs/handoff/2026-11-13-npc-1to1-audit.md`, `docs/architecture.md` and
> `AGENTS.md`. Fixed: the blocked-path standstill freeze (`VCModNpcBlockedReset`)
> and the cop's after-kill pose (civilians/gangs keep it, the cop skips it).
> Play-test a cop kill, an ID-check walk-off and a chase pursuit on 484. If the
> armed cop still holds range with the target in view, the close-in divisor is a
> separate scope decision. Run all `utils/test_vc_*.py` suites,
> `scripts/build.sh`, install only with no session, and confirm the installed
> build number. Never commit or push unless asked; game data is read-only.
