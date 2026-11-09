# Handoff — car gunner experiment removed (2026-11-08)

## Where things are

- Workspace `vc-mod`, code in `reVC/`,
  branch `vcmods`, HEAD `d01bb3c` plus the batch 1–4 work uncommitted.
- Build `scripts/build.sh`; install `scripts/install.sh`; launcher `scripts/make-launcher.sh`;
  tests `python3 utils/test_vc_*.py` from `reVC/` (fifteen, all passing).
- The tree builds **88**. The installed app was on build 86 and still carries the gunner
  experiment; the next launch of `Vice City Mods.app` delivers 88 and removes it.

## What was removed

The whole passenger-gunner experiment of this session, not just the broken part:

- `src/extras/vcmoddriveby.{h,cpp}` — deleted (the standing pose, the `G` toggle, the gang
  passenger gunner).
- `src/extras/vcmodgunner.{h,cpp}` — deleted earlier in the session.
- `src/core/Game.cpp` — `VCModGunnerUpdate()` call and include.
- `src/vehicles/Automobile.cpp` — `VCModPassengerDriveByTick(this)` and include.
- `src/peds/Ped.cpp` — the `SetPedPositionInCar` root lift / heading override and include.
- `src/weapons/Weapon.{h,cpp}` — `FireFromCar` / `FireInstantHitFromCar` back to three
  parameters; attribution, events and the 3× drive-by damage back to `FindPlayerPed()`.
- `src/extras/vcmodpanel.{h,cpp}` — `STANDS & SHOOTS` row, `bVCModStandAndShoot`, TWEAKBOOL,
  ALL ON/OFF membership (row count back to 35, `test_vc_passenger.py` updated).
- `src/core/re3.cpp` — `StandAndShoot` ini read.

`git status` should now show none of the above. Nothing in the shipped build depends on it.

## What the experiment learned (worth keeping if it is ever retried)

- The mission "The Chase" gunner is not a drive-by: the script attaches the ped with
  `ATTACH_CHAR_TO_CAR` (`CPed::AttachPedToEntity`, `Script6.cpp:1200`, `Ped.cpp:9472`), which
  sets him standing at the seat and lets the normal on-foot gun code fire.
- VC's `ped.ifp` has **no stand-up-in-car clip** — only `Driveby_L/R` (+ `_LO`), the bike
  drive-bys, `CAR_sit`, and the van door anims. Any "standing through the roof" pose has to
  come from moving the ped's root, not from an animation.
- Detaching a player from the passenger seat and re-seating him (`RemovePassenger` /
  `AddPassenger` + `PED_DRIVING`) is what left the car stopped when the toggle was switched off;
  do not leave the vehicle bookkeeping changed across a toggle.
- The `Phnom Penh '86` gunner setup (`PED_SNIPER_MODE` + `CCam::MODE_HELICANNON_1STPERSON`) is
  a zoomed first-person weapon camera — wrong for a "normal camera" gunner.

## Not touched

- Game data under `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`.
- The batch 1–4 changes and the packs.
