# Free-camera lock-on, firing stance and the aim-raise climb (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `1641b0f`
(shipped together with the RIDE TO auto work). Workspace branch `main`, HEAD
`fb454bd`. The `vcmods` commit is local; reVC is upstream and is never pushed.
Release build `vcmods build 506` installed into `~/Games/VC/reVC.app` with no
game session running. All `utils/test_vc_*.py` harnesses pass. The user
confirmed the whole set in play, including the crew driving.

## What changed

**FREE CAMERA OVER A LOCK.** `VCModFreeAimCameraLock()` (vcmodplayer) keeps the
free mouse camera over a lock: `ProcessPlayerWeapon` skips the stock
`MODE_SYPHON` angle when the row and the mouse camera are both on. Classic
control keeps the stock lock camera. `VCModFreeAimCrosshairHidden(player)` gates
the HUD's free-cam crosshair, so the lock marker is the only reticle while a
target is held; aiming with no target still draws the crosshair, and it returns
the instant the lock drops.

**NO STRAFE + FIRING STANCE.** `VCModPlayerTurnsWithInput()` keeps the keys on
the heading while a target is locked — unless the firing stance owns the frame.
`VCModFiringStance()` is true with a lock and the trigger held (or the attack
state) in the free camera; `VCModFiringStanceTurn(this)` turns the body onto the
target at the ped stare rate (20% per call, the two-hand pose rate), called first
in `RotatePlayerToTrackTarget`. `Cam.cpp` stops aiming the ped at the lens while
the stance is on. The result is the classic lock stance: W advances on the
target, S backs, A/D strafe through the engine's left/right/back groups (the
predicate standing down is what lets `ProcessAnimGroups` pick them). Releasing
the trigger and the attack tail returns the heading to NO STRAFE.

**LOCKED SHOTS HOME.** `VCModLockShotHomes(shooterPed)` in `CWeapon::FireInstantHit`
takes the target branch even when the arm's `GUN_POINTED_SUCCESSFULLY` flag
fails; a sideways tracer from a turned body was the report that prompted it.
Non-player peds keep the stock hand-direction fallback.

**AIM RAISE CLIMB.** `CPed::PointGunAt` no longer jumps the aim clip to the hold
while a raise owns it: a cold clip runs its own raise frames up to the hold, a
clip parked in the lowered recovery hold plays that tail backwards, and the clip
is parked (speed restored) at the hold. `VCModAimRaiseHoldLanded` arms from that
park and `VCModAimPoseRaised` requires it plus the pose blend, so a clip parked
low can no longer report the raise as finished. The recovery/aim tick stands
down while a fresh raise owns the climb. Moving or ducked entries end the raise
at once (the walk carry owns the pose).

## Evidence trail

The temporary `VCMOD aimprobe` trace caught two distinct defects before it was
removed:

- The dead trigger: 11 samples all `st=22` (AIM_GUN), standing, `lock=1 raise=1
  pose=1 blend=1.00 cam=4` on the Ruger. The pose was up; only `TurnBody` was
  unfinished. The free mouse camera rewrites the ped heading every frame
  (`CCam::Process_FollowPedWithMouse`), so the sweep could never converge. The
  free-camera raise now stops on the pose alone and no-strafe owns the heading.
- The instant raise: every fresh lock stopped the raise within ~0.13 s because
  only the pose blend was gated while `PointGunAt` snapped the clip time. The
  climb above replaced that.

## Next steps

1. Nothing open on lock-on or the camera. If the stance or raise feel off in
   play, the levers are the clip's own timings — no invented constants.
2. The aim trace is gone; a future trace needs rebuilding (the probe code is in
   the `2026-11-14` chat history, not in the tree).
3. Today's other handoffs: `2026-11-14-ride-to-map-marker-auto.md` (RIDE TO
   auto, shipped in the same commit) and `2026-11-14-radio-adf-restore.md`.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. reVC is an upstream checkout: no branch, worktree,
fork or push of it. Handoffs and published artifacts name no AI.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `1641b0f`; build 506 is
> installed. Read `docs/handoff/2026-11-14-lockon-free-camera.md` first, then
> `AGENTS.md` and `docs/architecture.md`. The free-camera lock-on set is
> shipped and play-confirmed: free camera over a lock, crosshair hidden while
> locked, NO STRAFE owning the heading, the firing stance, lock-shot homing and
> the aim-raise climb (`VCModAimRaiseHoldLanded`). The temporary aim trace has
> been removed. RIDE TO auto shipped in the same commit; its handoff is
> `2026-11-14-ride-to-map-marker-auto.md`. All harnesses pass.
