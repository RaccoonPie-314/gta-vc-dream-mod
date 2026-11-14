# BECOME NPC: the wander restart twitch and stock node poses restored (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `1641b0f`.
`vcmods build 514` is installed in `~/Games/VC/reVC.app`. All 45
`utils/test_vc_*.py` suites pass. The tree is uncommitted (see below); no commit,
tag or push was made.

## Reports

1. Play test on the previous working-tree build: with `BECOME NPC` on, Tommy
   twitched in place and kept changing his mind about where to walk.
2. The wandering pedestrian hands-behind-back pose had been suppressed for every
   type by the earlier stuck-pose work. The user asked for it back and set the
   project rule: all native stock behaviour is 1:1; the only fix is the
   hands-behind-back pose that locked after a kill.

## Twitch — root cause and fix

The previous session's uncommitted edit forced the civilian wander every frame:
while `bCivilianWander` was true, `VCModUpdateNpcMode` set `bVCModStreetWander`,
called `VCModNpcResetStroll()` and `VCModStreetStartWander(player)` every frame.
`VCModStreetStartWander` picks a fresh random path direction and calls
`SetWanderPath`; `VCModNpcResetStroll` zeroes the stroll speed. Every frame the
heading target changed and the speed was erased, so he jittered in place. The log
proves it: 8,801 back-to-back `VCMOD street idle: wander started` lines in
`~/Games/VC/reVC.log`. The engage path at the bottom of the same function already
starts the wander once, and the owned-wander block re-issues it on `PED_IDLE`.

Fix: the per-frame block is removed, and `bVCModStreetWander` is `static` again in
`vcmodstreet.cpp` (header export removed).

## Stock node poses restored

`Ped.cpp`, `CPed::WanderPath`: the four stock node-wait branches are stock again —
no `playerNpc` gate anywhere. Every NPC-mode profile takes the dead-end
hands-behind-back, the back-track pose, the traffic-light wait and the cross-road
wait exactly as a native pedestrian does.

The only divergence left in the wander is the DOUBLEBACK hold: while that wait
state is up, `WanderPath` returns early for the NPC-mode player. A player stands
through the pose while a ped's walk clip would blend over it, and the wander's
node bookkeeping would otherwise restart the timer; holding lets the stock pose
run its length and release. That is the after-kill stuck-pose fix, and it is now
the project's only sanctioned divergence in stock behaviour. The stock ped seek
radius reset (`m_distanceToCountSeekDone = 1.0f`) stays: combat leaves it large
and the wander then skips nodes and walks through geometry.

Rule recorded in `AGENTS.md` ("Stock behaviour is 1:1").

## Verification

- All 45 suites pass. `test_vc_gangfaction` now pins every stock node pose for
  the player in all three profiles, the DOUBLEBACK hold, and the post-kill pose
  resuming into a real walk; `test_vc_cop_patrol` pins that no branch carries a
  player gate and pins the hold and radius.
- `scripts/build.sh` builds cleanly (build 514), installed with
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- In game: not yet played. Check:
  - Enable BECOME NPC: one direction at a time, no twitch. The log shows one
    `wander started` per engage/resume, not a stream.
  - Wander node poses: dead end -> hands behind back ~3 s (scratch near the end)
    then walk back; back-track turns and kerb/traffic-light waits as stock.
    Poses repeat at the same spot only as often as a native ped would.
  - A pose must always release and the walk resume; a pose that never ends at the
    same spot is the lock bug — fix the hold, never suppress the pose.
  - After a kill: civilians/gangs hold the pose then walk; the cop skips it
    (stock mission-char behaviour).

## Uncommitted (all of it)

This working tree also carries the previous session's refactor slices, which the
514 build includes and the suite covers: shared test support
(`utils/vcmod_test_support.py`), HUD notice dedupe (`src/extras/vcmodhud.*`),
diagnostics gating behind `VCMOD_DIAG`, the never-wanted helper in `Wanted.cpp`,
and the `ProcessPlayerWeapon` aim extraction into `vcmodcombat`.
`vc-mods.patch` predates all of it. `AGENTS.md` has the new rule.

## Next

1. Play-test build 514 with the checks above.
2. The refactor plan in `docs/handoff/2026-11-14-refactor-flow.md` still stands:
   packaging (Windows `Play.bat`), then the config registry last.
3. Commit only when asked; regenerate `vc-mods.patch` then.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are `uchg`. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install. Git on reVC is the user's: no commit, tag or
push unless asked.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `1641b0f` plus an uncommitted
> working tree; build 514 installed. Read
> `docs/handoff/2026-11-14-npc-wander-twitch.md` first, then `AGENTS.md` (new
> rule: stock behaviour is 1:1, the only divergence is the hands-behind-back
> hold) and `docs/handoff/2026-11-14-refactor-flow.md`. The BECOME NPC twitch
> (per-frame wander restart) is removed and every stock WanderPath node pose is
> back for all profiles. All 45 suites pass. Play-check build 514: steady
> walking, stock node poses that always release, the after-kill pose (cop skips
> it), chatter and the cop ID check. Then continue the refactor plan (Windows
> package, config registry last). Never commit or push unless asked; game data
> and the uchg anim files are read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
