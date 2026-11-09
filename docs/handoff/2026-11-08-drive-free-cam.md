# Drive free camera

2026-11-08. Branch `main`, repo `vc-mod`. Built release green and installed into
`~/Games/VC/reVC.app` (no session was running). **Unplayed** — nothing here has been
watched in game.

## What it does

In a vehicle the third-person camera can be turned around the car:

- Mouse (or right stick) swings the view around the car and up/down. The angle is
  held **relative to the car**, so it follows while you drive and steer.
- After **1.5 s** with no camera input it eases back to directly behind the car over
  0.6 s. Any input during the ease cancels it and carries on from the current angle.
- The stock look keys still win: holding look-left (Q), look-right (E) or look-behind
  (middle mouse) drops the orbit and runs the original look code; on release the
  camera settles behind the car as it always has.
- Untouched: first person, top-down, cinematic, fixed/garage/stairs cameras, scripted
  and Obbe cameras, and the `Display -> Free Cam` option (when it is on, that camera
  is used and this one never engages).
- Always on while driving — no ini key, no panel row (owner's choice).

## How it works

The stock car camera (`Process_Cam_On_A_String`) is a cam on a string: `Source` trails
in world space and only swings back when the car is more than 160 degrees off
(`RotCamIfInFrontCar`). There is no mouse input in it at all, so the orbit owns the yaw
while it is engaged and hands the camera back from "directly behind", a state the
string camera takes over without a jump.

New `src/extras/vcmoddrivecam.{h,cpp}` — input, 1.5 s clock, yaw/pitch offsets, ease.
Hooks in `src/core/Cam.cpp`:

1. `CCam::Process` — `VCModDriveCamTick(CamTargetEntity, Mode)` once per frame. Reads the
   mouse (`m_bUseMouse3rdPerson` and `m_bDisableMouseSteering`, the same rule the SA car
   cam uses) and the pad, and resets on a target/mode change, a camera transition, a
   replay, disabled controls or a held look key.
2. `Process_Cam_On_A_String` — `VCModDriveCamOrbit` places `Source` at the orbit angle
   before the distance clamp, then `Beta` is recomputed from the new position.
3. `WorkOutCamHeight` — the stock camera height plus the orbit pitch, clamped to
   -20..88 degrees so it never goes under the road or flips over the car.
4. `RotCamIfInFrontCar` — returns early while engaged, otherwise it would drag the angle
   back behind the car.
5. `Process_BehindBoat` — the same yaw/pitch offsets on the boat camera (identical
   position convention, `Source = target - R*(cos, sin)`).

Rates: mouse uses the on-foot camera's 2.5/4.0 and `m_fMouseAccelHorzntl/Vertical`;
stick is 2.2 rad/s yaw, 1.3 rad/s pitch at full deflection.

## Unverified in play

- The 1.5 s idle (owner asked for shorter than the original 3 s) is unplayed.
- Everything above. Signs, sensitivity, the return timing and the feel of the pinned
  angle have not been watched. The mouse-right / view-right sign was derived from
  `Process_FollowPedWithMouse`, not observed in a car.
- Boats: same helper on `Process_BehindBoat`, never driven.
- Live `reVC.ini` has `FreeCam=0`, `DisableMouseSteering=1`, `Method=0` (standard
  controls) and `InvertMouseVertically=1`, so the mouse path is the active one here.
  With mouse steering turned on the mouse is not read for the camera (by design).
- Orbiting into a wall: `AvoidTheGeometry` pushes the camera each frame but the orbit
  re-seats it every frame, so it may jitter in tight spots instead of settling.

## Tree repair (not this feature)

`src/vehicles/Automobile.cpp` was left mid-edit at 16:43 (after the 16:42 build) with a
duplicated tail-light block referencing `tailIntensity` out of scope and
`CAR_POS_REVERSINGLIGHT_L/_R`, which do not exist. That is the per-side reversing-lamp
attempt the batch-4 handoff says not to make; it could not compile. Removed the
duplicate (38 lines) so the file is back to the version that built at 16:42: red tail
coronas when the model carries `CAR_POS_REVERSINGLIGHTS`, stock white glow otherwise.
The broken file is kept at `/tmp/Automobile.cpp.broken-1710` if that work needs picking
up again.

## Uncommitted

New `src/extras/vcmoddrivecam.{h,cpp}`, `src/core/Cam.cpp` (5 hooks), plus the
`Automobile.cpp` repair on top of batches 1-4. Nothing touches game data.

## Next

1. Drive a car: turn the view with the mouse, let go for 1.5 s, watch the ease back; turn
   while holding an angle; tap Q/E/look-behind; cycle the zoom; enter and exit a car.
2. Judge sensitivity and the 1.5 s / 0.6 s timings; both are single `#define`s at the top
   of `vcmoddrivecam.cpp`.
3. Boat check if one is handy, then add the feature to `CHANGELOG.md` with the batch
   that ships.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Do not install while a session runs (`pgrep -x reVC` must be empty; the broad
  `pgrep -f` matches the grep itself in a concurrent shell).
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC`
  is read-only.
