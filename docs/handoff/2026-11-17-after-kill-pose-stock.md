# After-kill pose: stock only, no force (2026-11-17) — build 661 installed

> Superseded by `2026-11-17-after-kill-pose.md`. The seek-radius clamp described here was
> removed: the pose's frequent source is the fight's leftover radius, and the shipped rule is
> one double back per wander start with the radius saved and restored. Read the newer file.

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
64 files uncommitted. `vcmods build 661` is built and installed into
`~/Games/VC/reVC.app` (no session was running); the installed binary reports
`vcmods build 661`. 56/56 `utils/test_vc_*.py` suites pass.

## The decision

The owner does not want the after-kill hands-behind-back pose forced. The force
is gone; the stock behaviour is live: the pose comes only from the wander's own
node waits, exactly as it does for a pedestrian.

## What ships

**`src/peds/PedAI.cpp`** — kill completion takes the stock branch again: a
completed kill only re-issues the wander. No `PEDMOVE_STILL`, no
`SetWaitState(WAITSTATE_DOUBLEBACK)` on the kill. Civilians, gangs and the cop
are all on the same path now; a cop still gets `RestorePreviousState` for the
mission-char case, unchanged.

```cpp
} else {
    // stock: a completed kill only re-issues the wander, so the
    // look-both-ways pose falls where the new path dead-ends or
    // turns back, never on the kill itself
    SetWanderPath(CGeneral::GetRandomNumber() & 7);
}
```

**`src/peds/Ped.cpp`** — the player-only early return in `WanderPath` is gone.
While a wait is up the NPC-mode player holds the ped seek radius
(`m_distanceToCountSeekDone = 1.0f`), so `Seek()` reports the walk-back node out
of reach, the stock node bookkeeping runs anyway, and the wait's own timer can
expire and hand the body back — the `WAITSTATE_DOUBLEBACK` case in `Wait()`
releases `PEDMOVE_WALK` at the deadline. Combat's large seek radius used to
remain in place, made every frame report the node reached, and re-issued the
wait so the timer never ended (the freeze the early return was avoiding).

Net effect: the four node waits (both doublebacks, traffic light, cross-road)
play for the NPC-mode player like for a pedestrian, enter from the path data,
and release from the stock timer. No pose is ever triggered by the kill itself.

## What the owner sees in play

- A kill never poses. He finishes, wanders on and resumes walking.
- The pose appears only when his path dead-ends or turns back to the previous
  node — the same rule the pedestrians around him use. Expect it rarely: four
  genuine dead-end poses across the whole logged play history (out of hundreds
  of peds' worth of paths). One body cannot show it as often as a crowd.
- A cop kill never poses.
- The wander dead-end also blends `XPRESS_SCRATCH` in the last seconds before
  it releases, as stock; that behaviour is untouched.

## Harness

- `test_vc_gangfaction.py`: the two post-kill pose tests now expect no pose
  after a kill. New test `test_the_pose_releases_even_with_the_combat_seek_radius`
  pins the release: with a 40.0 m combat leftover radius, four `WanderPath`
  ticks during the wait must call `Seek()` (the stock routine runs), must not
  re-issue the wait or restart its timer, and `Wait()` past the deadline must
  clear the state and set `PEDMOVE_WALK`.
- `test_vc_cop_patrol.py`: `WanderGuardTests` now requires the radius hold and
  no early return before the node logic, and no player gate on any node wait.
- `test_after_kill_pose_holds_then_wander_resumes` expects `Seek()` to be asked
  each frame during the wait, with the timer untouched.
- All 56 suites pass.

## Honest limits

This does not make the pose appear often. Nothing can, short of forcing it on
the kill (rejected) or adding a deliberate street-idle-style gesture in NPC
mode (not done, not asked for). If the owner wants more of it, the options are:
a rare gesture after kills or standstills in NPC mode, both mod additions, or
the STREET IDLE waiting pose behaving as in normal play.

## Not committed; do not

- Do not reintroduce any force in `ProcessObjective`'s kill completion.
- Do not gate the node-wait branches on the player.
- Game data is read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
  before any install; handoff at `docs/handoff/`.
