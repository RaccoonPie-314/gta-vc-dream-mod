# Batch 4 — vehicle visuals from the pack (wheels, cars, steering wheel)

Date: 2026-11-08
Repo/branch/HEAD: `reVC/`, `vcmods`, `d01bb3c` plus uncommitted batches 1–4.
Installed: `~/Games/VC/reVC.app`, `vcmods build 89` (includes the rear-light fix); installed
when the previous game session exited.

Batch 4 is the owner's pick of the Vice Extended pack's vehicle visuals. Two of the four
planned items are in this build; lamp textures and the cast-light split are not started.

## What ships

1. **Loose mod files for streamed assets** — `src/fakerw/fake.cpp`
   `RwStreamOpen` now asks `CFileMgr::FindModFile` first on read. Models and texture
   dictionaries open through this path, not through `myfopen`, so before this a loose
   `mods/<name>/models/...` file never won over the game file. Reads only; writes and
   `mods/`-prefixed paths are untouched. Harness: `utils/test_vc_modfiles.py`.

2. **Pack wheels** — `~/Games/VC/mods/wheels/` (local-only, not in git):
   - `models/generic/wheels.dff` — pack model, 49 frames / 32 geometries. All ten IDE wheel
     models have `_l0`/`_l1` pairs. sha256 `84790d6d…`
   - `models/MISC.TXD` — the pack's `wheels.TXD` renamed. Stock `MISC.TXD` holds only the
     eleven wheel/tyre textures (`tyre64a`, `wheel_*64`), so replacing it wholesale is the
     pack's own scheme: its `default.dat` swaps `MISC.TXD` for `wheels.TXD`. sha256 `fe5e7f82…`
   - One asset repair: the pack's lightvan LODs reference `contour_wheels64`, which exists
     in no TXD in the pack or the stock game. Both material names were repointed to `tyres`
     (same 17-byte chunk, no size change); everything else is byte-identical to the pack.
   - `~/Games/VC/mods/mods.ini` gained `wheels`.

3. **Pack car models** — `~/Games/VC/mods/vehicles/overlay.img` + `overlay.dir`, 46 entries
   (29 DFFs, 17 TXDs) taken from the pack's `cdimages/vehicles.img`. `firetruk.dff/.txd`
   are excluded on purpose so the verified firetruck mod keeps owning them.
   `overlay.img` sha256 `1d971e59…` (14,467,072 bytes), `overlay.dir` `924e20a7…`.
   `mods.ini` gained `vehicles` after `wheels`; overlays mount in list order and later
   images win name clashes.

4. **Steering wheel** — the pack's car models carry a real `steeringwheel` node with its own
   geometry (stock VC has none). Engine support:
   - `src/vehicles/Vehicle.h`: `CAR_STEERING_WHEEL` before `NUM_CAR_NODES`.
   - `src/modelinfo/VehicleModelInfo.cpp`: `{ "steeringwheel", CAR_STEERING_WHEEL, 0 }`, so
     `SetFrameIds`/`FillFrameArray` put the per-instance frame into `m_aCarNodes`.
   - `src/vehicles/Automobile.h/.cpp`: rest matrix, last angle and validity; reset in
     `SetupModelNodes`; `VCModSteeringWheelUpdate(this)` at the end of `ProcessControl`,
     after every branch has settled `m_fSteerAngle`.
   - `src/extras/vcmodsteering.h/.cpp`: wheel geometry is a thin disc in its own XZ plane,
     so it turns about local Y; the captured rest orientation is kept and the turn is
     `POSTCONCAT` on top. Angle is `m_fSteerAngle * 4`. Calls `RwFrameUpdateObjects` so a
     parked car's wheel moves too (an unmoving entity never dirties its clump).
   - Panel row `STEERING WHEEL`, ini key `SteeringWheel`, harness
     `utils/test_vc_steering.py`. Panel now has 36 rows (passenger harness updated).

5. **Rear lights on the pack cars** — first play report: the reverse lamp went red for
   a moment and was then washed out by the white glow. Stock VC only has tail-lamp
   markers and recolours that single pair of coronas white in reverse; the pack models
   carry their own reversing lamps, so that recolour reads as "red overwritten by white".
   - `src/modelinfo/VehicleModelInfo.{h,cpp}`: `CAR_POS_REVERSINGLIGHTS` from the
     `reversinglights` marker node (the plural dummy, which owns no geometry — do not use
     `reversinglight_l/_r`: those frames carry the lamp atomics and
     `PreprocessHierarchy` destroys the frames it reads positions from).
   - `src/vehicles/Automobile.cpp`: when that marker exists the tail coronas stay red in
     reverse (brake boost respected, alarm-off handled); models without it keep the
     original white tail glow byte-for-byte. Harness: `utils/test_vc_rearlights.py`.

## Unverified in play

- Steering wheel direction and 4× ratio, and whether the wheel pivot looks right on all
  twelve cars that carry the node (banshee, infernus, police, sabre, sabretur, taxi,
  admiral, ambulan, baggage, cheetah, idaho, patriot, vicechee, plus firetruk). Axis was
  derived from the geometry (disc normal = local Y) and the sign from `m_fSteerAngle > 0`
  meaning a right turn; nothing has been watched in game.
- Wheels: all thirteen texture names the patched model uses resolve from the new
  `MISC.TXD`. Not yet seen on a moving car; watch for wheel scale/offset differences and
  for the lightvan contour material.
- Cars: the pack TXDs cover their models, with these known holes (pack's own defects):
  `licenseplates` on sabre/sabretur, `policemiami868bit128` and `policemiami86body128` on
  taxi (its TXD has the `taximiami…` pair instead), `servicelights.png` on firetruk. Those
  patches render untextured; nothing in the stock game or the pack supplies them.
- Rear lights: the split is built from the marker name only; the two tail coronas sit at
  the model's `taillights` marker (middle lens row), not on the per-side lamp meshes. If
  the owner wants the glow to sit on the top lamp row or a white reversing glow, that needs
  per-side positions plus a guard so `PreprocessHierarchy` does not destroy lamp frames.
  The play session that reported the bug predates this fix (game still running at 16:42).

## Uncommitted

Batches 1–4 are one tree. Ours this batch: `src/fakerw/fake.cpp`,
`src/modelinfo/VehicleModelInfo.cpp`, `src/vehicles/{Automobile.cpp,Automobile.h,Vehicle.h}`,
`src/core/re3.cpp`, `src/extras/vcmodpanel.cpp`, new `src/extras/vcmodsteering.{h,cpp}`,
new `utils/test_vc_{modfiles,steering,rearlights}.py`, and harness touch-ups in
`utils/test_vc_{adrenaline,character,passenger}.py`. Not ours: `src/peds/PlayerPed.cpp`
and the `vcmoddriveby.*` wiring. Nothing here touches the game data.

## Next, in order

1. Play this build: drive a few of the replaced cars at night, turn the wheel while parked
   and while rolling, and look at a lightvan, a sabre and a taxi. Steering direction, the
   4× ratio and the missing-texture patches are the things to judge.
2. Then the remaining batch-4 items need a definition before code: "lamp textures" (swap
   `lights` to `lightson` material faces at night?) and "cast-light split" (corona vs
   cast light). The pack ships `lights`/`lightson`/`servicelights` textures in the car
   TXDs already, so this is engine work, not assets.
3. Commit batches 1–4 once the owner has played them.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Check `git status` and the newest handoff before touching `src/core/re3.cpp`,
  `src/extras/vcmodpanel.*`, `src/peds/PlayerPed.cpp`; each was owned by another agent.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is
  read-only. Pack assets live only under `~/Games/VC/mods/` and never in git or a public
  package.
- The user tests in game; do not call an unplayed change fixed, and do not install while
  `pgrep -x reVC` is non-empty. Do not use the broad
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` from another shell: it matches the grep
  command itself in a concurrent session.
