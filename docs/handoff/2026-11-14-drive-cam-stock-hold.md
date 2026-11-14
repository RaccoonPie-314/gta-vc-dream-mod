# Drive free camera: stock deadzone on the hold (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `ff1f984` plus
the uncommitted change below. Release build green and installed into
`~/Games/VC/reVC.app` with no game session running. Third shape today; the
first two were played and rejected.

## What changed

While camera input is moving, the drive orbit is unchanged: yaw/pitch seat the
camera relative to the car. The 1.5 s idle hold went through three shapes:

1. Handed the view to the stock string camera on the first input-free frame.
   Played: unusable — `RotCamIfInFrontCar` measures the absolute
   view-to-heading offset, so any released view more than 20° off was dragged
   behind at once.
2. Froze the view in the world and handed it to stock once the car's own turn
   passed the deadzone. Played: the handoff swung the camera behind, i.e. it
   centred instantly and lost the held angle.
3. Shipped shape: the view **freezes in the world** (the beta the orbit last
   placed, `sHeldBeta`) and is re-seated at that fixed angle around the car. A
   car turn under the stock deadzone rotates the car beneath the view. Once
   the car's own turn since release passes the deadzone — and the car is moving
   forward, the same gate `RotCamIfInFrontCar` uses — the view **re-couples to
   the car at the held angle** (`sYaw = sHeldBeta - heading`, so no jump) and
   follows its direction again. Nothing is centred; the 1.5 s idle and 0.6 s
   recenter to directly behind are unchanged.

No invented behaviour: `VCMOD_DRIVECAM_FOLLOW_TURN` is the engine's own
`PI - DEGTORAD(160.0f)` deadzone, and the 0.02 forward-speed gate is copied
from `RotCamIfInFrontCar`. The deadzone is measured on the car's turn, not on
the released offset.

## How it works

`src/extras/vcmoddrivecam.cpp` only; `vcmoddrivecam.h` comment updated. Hooks
in `src/core/Cam.cpp` unchanged.

- `sSession` — orbit session in progress. `sEngaged` — the orbit owns the
  camera. `sHolding` — view frozen in the world. `sFollowed` — the deadzone was
  passed, the view follows the car again.
- First idle frame: `sHolding = true`, `sRefHeading` = current heading (the
  same `GetATanOfXY` CCam::Process uses). `sHeldBeta` is recorded by
  `VCModDriveCamOrbit` on every seated frame.
- Hold frames: `VCModDriveCamOrbit` seats at `beta = sHeldBeta`; `Busy` stays
  true, so the stock drag never runs during a session.
- Gate: `|wrap(heading - sRefHeading)| > 20°` and forward speed > 0.02 →
  re-couple (`sHolding = false`, `sFollowed = true`); the view keeps tracking
  the car 1:1 from the held angle.
- Idle mark: `sYaw = wrap(sHeldBeta - heading)` and the 0.6 s ease runs from
  it (pitch included).
- Input during the hold re-anchors from the seated position, keeps the held
  pitch, and re-arms the deadzone for the next idle.

## Verification

- Release build green (`scripts/build.sh`); installed with no session running.
- Shapes 1 and 2 were played and rejected (instant drag on release; instant
  centring at the deadzone). This shape is the correction and is unplayed.
- To judge: aim sideways, release, drive straight — view must hold. Turn under
  ~20° — the car rotates under the view. Turn past it — the view follows the
  car, keeping the angle (no centring). After 1.5 s idle the 0.6 s recenter
  still runs.

## Next steps

1. Play test the three phases above; the levers stay
   `VCMOD_DRIVECAM_IDLE_MS` / `VCMOD_DRIVECAM_RETURN_MS`.
2. Boats unverified: the boat camera buffers `Beta` on its own while the hold
   runs; the handoff back at the idle mark can be a snap rather than a swing.

## Uncommitted

`reVC/src/extras/vcmoddrivecam.cpp`, `reVC/src/extras/vcmoddrivecam.h`.

## Rules

- Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
  `~/Library/Application Support/reVC/`. Never install while a session runs.
- Never push reVC; handoffs name no AI; workspace is `vc-mod`.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `ff1f984` + uncommitted
> `vcmoddrivecam.{cpp,h}`. Read
> `docs/handoff/2026-11-14-drive-cam-stock-hold.md` first, then `AGENTS.md`.
> The drive free camera freezes the view in the world during the 1.5 s hold,
> re-couples to the car at the held angle once the car's own turn passes the
> stock deadzone (20° off, moving forward), and recenters behind after the
> 1.5 s + 0.6 s as before. Build green, installed, third shape unplayed. Next:
> the play test; keep stock behaviour 1:1 and add no constants.
