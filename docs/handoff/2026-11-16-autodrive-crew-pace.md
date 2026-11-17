# Handoff: AUTO DRIVE aggressive pace, crew weave slowdown and reverse

Date: 2026-11-16
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `46e9f0f` (nothing committed this session)
Built: `vcmods build 613`, installed in `~/Games/VC/reVC.app` (no session was
running). Harness: all 52 `utils/test_vc_*.py` green.

## The reports

1. AUTO DRIVE `[AGGRESSIVE]` runs reds and weaves but is slow: cruise was
   `VCModTrafficPace()` (15) in every mode.
2. The crew's aggressive ride never reverses when wedged.
3. The crew's aggressive ride never slows for heavy traffic — it drives into
   whatever it cannot pass.

## What changed

- **Auto drive pace** (`src/extras/vcmodautodrive.cpp`): a new
  `VCModAutoDrivePace()` picks 15 for SAFE and the crew's fast pace for
  AGGRESSIVE — 40 on a marker route (`VCMOD_AUTODRIVE_RUSH`), 35 cruising
  (`VCMOD_AUTODRIVE_RUSH_CRUISE`), the same numbers the crew ride uses. The
  weave style and the light exemption are unchanged: `AVOID_CARS` already runs
  reds and steers around cars.
- **Traffic scan for both aggressive rides**:
  - `src/control/CarCtrl.{h,cpp}`: the moving-rect scan is split out as
    `CCarCtrl::FindMaximumSpeedForThisCarOnItsPath`; the stock
    `FindMaximumSpeedForThisCarInTraffic` keeps its style early-return and now
    calls it, so every other car behaves exactly as before.
  - `SteerAICarWithPhysicsFollowPath` gives the crew car the scan while it is
    in `AVOID_CARS`; the straight-leg crew cap in
    `SteerAICarWithPhysicsHeadingForTarget` now uses the same scan (it used to
    call the function that no-ops for that style). Heavy traffic is braked for
    instead of rammed.
  - `VCModAutoDriveControl` does the same for the auto-drive car each frame
    while AGGRESSIVE: base pace set first, then the scan caps it, so a clear
    frame restores 40/35 instead of the cap sticking.
- **Crew reverse unstick** (`src/control/CarAI.cpp`): the crew car is no longer
  excluded from the stock mission-vehicle reverse unstick. That branch only
  fires after 2 s of continuous contact (`m_nLastTimeCollided`), so a car
  merely queued behind traffic still waits; a genuinely wedged one backs out
  for the stock 1500 ms. The blind 30 s cruise nudge still skips the crew car.

## Tradeoff to know

The restored reverse is stock-blind: `SteerAICarWithPhysics_OnlyMission` has no
rear scan, so a wedged crew car can back into the car behind it. That was the
original reason for the exclusion. The traffic scan above means the car now
stops behind queues instead of ramming them, so the unstick should mostly fire
on walls and corners — watch this in play.

## Play steps

1. Launch through the Dock app, confirm `vcmods build 613`.
2. AUTO DRIVE `[AGGRESSIVE]` with a marker: it should pull away at 40 and hold
   it on clear straights, weave around cars, run red lights, brake when a car
   ahead closes the gap, and still brake to a stop at the marker and turn off.
   Without a marker it cruises at 35.
3. AUTO DRIVE `[SAFE]`: unchanged, traffic pace 15, stops at lights and queues.
4. CREW AGGRESSIVE on, RIDE TO somewhere: the ride is fast and weaves, but now
   slows and brakes when boxed in instead of driving into the queue.
5. Wedge the crew car (corner, kerb, wall) in aggressive: it should back out
   after a moment instead of sitting forever. Watch whether it reverses into
   anything behind it.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Uncommitted in the checkout

This session: `src/control/CarCtrl.{h,cpp}`, `src/control/CarAI.cpp`,
`utils/test_vc_crew.py`, plus the already-untracked
`src/extras/vcmodautodrive.{cpp,h}` and `utils/test_vc_autodrive.py` from the
2026-11-15 session. Everything else uncommitted predates this session.

## Next

1. Play the steps above; the reverse and the weave slowdown are the two things
   that need eyes.
2. If the aggressive crew car still arrives damaged, the next lever is the
   weave angle, not the scan: `FindAngleToWeaveThroughTraffic` has no clearance
   model.
3. If the blind reverse proves to hit cars behind, the stock answer is a rear
   probe before `TEMPACT_REVERSE` for the crew car only — a real divergence,
   decide it in play first.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `46e9f0f`.
> `vcmods build 613` is installed in `~/Games/VC/reVC.app`: AUTO DRIVE
> aggressive now runs the crew's fast pace (40 on a route, 35 cruising) with
> the engine traffic scan, and the crew aggressive ride gets the scan plus the
> stock reverse unstick. Read `AGENTS.md` and
> `docs/handoff/2026-11-16-autodrive-crew-pace.md` first.
>
> Play the checklist in that handoff: aggressive auto drive pace, weave, reds
> and marker arrival; safe mode unchanged; crew aggressive slowing in heavy
> traffic; the wedged crew car reversing (watch for reversing into cars).
> Run all `reVC/utils/test_vc_*.py` and `scripts/build.sh` before handing off.
> Do not commit, tag or push unless asked; game data and the `uchg` anim files
> stay untouched.
