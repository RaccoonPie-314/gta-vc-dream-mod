# NPC wander poses and off-path walking fix (2026-11-12) — build 443 installed

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
`vcmods build 443` is installed. All 43 harness suites pass. No commit, tag or
push was made.

## What changed

Build 441 gave the player one look-both-ways pose per node with a 15 s
re-issue cooldown. In play that was wrong: the pose lasted ~1 s, fired
constantly, and Tommy wandered off the pavement into buildings and cars.
Build 443 replaces the cooldown with a simpler rule:

- An NPC-mode player gets **no wander-node waits at all**. All four
  `WanderPath` branches (both doublebacks, traffic light, cross-road) are gated
  `!playerNpc`; stock peds are untouched. The player stands through these
  clips (no root motion), so any node-issued pose either locks or churns.
  `VCModNpcAllowDoubleback` / `VCModNpcNoteDoubleback` are deleted.
- The only pose left is the deliberate **after-kill pose**, now for **every
  profile**: `npcKillCompleted` in `PedAI.cpp` (player + NPC mode + on foot +
  completed KILL objective + dead target) routes cops (`MISSION_CHAR`) through
  the wander branch too, sets `PEDMOVE_STILL` and the stock
  `WAITSTATE_DOUBLEBACK` (3.5 s). While it plays, `WanderPath` returns early so
  the timer never slides; when it expires the walk resumes.
- The combat seek-radius reset (`m_distanceToCountSeekDone = 1.0f`) now applies
  to every NPC profile, not just gang. Combat leaves the radius large; the
  wander then counted pavement nodes as reached from far away, picked new nodes
  early and cut across buildings — the off-path walking.
- `QUICK ID CHECK` debug switch unchanged (`bVCModCopQuickChecks`, default off,
  5-10 s cop ID-check cooldown instead of 100 s; DEBUG row, debug menu,
  `QuickCopId` ini key, outside the ALL ON sweep). The ID check itself is
  confirmed fixed in play.
- Harnesses: `test_vc_gangfaction` pins no node poses for players, the 3.5 s
  pose for gang/civilian/cop, the mission-char restore when no kill completed,
  and the per-profile radius reset; `test_vc_cop_patrol` pins all four gated
  branches. Row count stays 57.

## Root cause (builds 435-441 diagnostics + play)

`SetWaitState` restarts its timer on every call and the player stands through
the pose, so node-issued waits re-issue forever (the original lock). The 441
cooldown stopped the lock but the cross-road wait (`WAITSTATE_CROSS_ROAD`,
1 s) and the 15 s doubleback cycle still fired constantly, and the large
combat seek radius made the wander skip nodes and walk straight through
geometry. Removing node waits for players and resetting the radius fixes both.

## Verification

- All 43 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 443); installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty).
- `~/Games/VC/reVC.log` truncated to 0 before the next test (per-test log
  hygiene: clear only with no session running, read fresh/filtered/capped).
- In game: not yet checked. Confirm: after a kill (any profile) Tommy holds
  hands-behind-back ~3.5 s then walks on; no poses while just wandering; he
  stays on the pavement after combat; cop ID check still completes (QUICK ID
  CHECK on for pacing).

## Uncommitted

The four refactor slices (adrenaline, sit, street, NPC) plus the cop fixes are
all uncommitted. `vc-mods.patch` predates them.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 443 is
> installed. Read `docs/handoff/2026-11-12-cop-doubleback-fix.md` first.
> NPC-mode players get no wander-node poses; the only pose is the 3.5 s
> after-kill hold, now for every profile (gang/civilian/cop); the combat
> seek-radius reset is profile-wide. QUICK ID CHECK (5-10 s cooldown) is on the
> DEBUG page; the ID check is confirmed fixed. All 43 harnesses pass; the
> in-game pose/wander check is open. Clear `~/Games/VC/reVC.log` before each
> test (only with no session running) and read only fresh, filtered, capped
> slices. Commit only when asked and regenerate `vc-mods.patch` then. Never
> commit or push unless asked; game data and uchg anim files are read-only;
> check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.