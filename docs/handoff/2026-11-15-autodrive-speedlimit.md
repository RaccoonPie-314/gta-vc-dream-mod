# Handoff: AUTO DRIVE (two stock NPC styles) and SPEED LIMIT

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `46e9f0f` (nothing committed this session)
Built: `vcmods build 611` in `reVC/build/src/reVC.app` (harnessed and installed
by hand). The Dock launch rebuilt the same tree and installed `vcmods build 612`
in `~/Games/VC/reVC.app`; that is the build now in play.
Harness: all `utils/test_vc_*.py` green, including the new
`utils/test_vc_autodrive.py` (9 tests).

## What this is

- **AUTO DRIVE** — from the driver seat, the player's car or bike drives itself
  with one of the engine's own NPC styles. A pause-map marker routes it; no
  marker cruises the road graph. Any driving input or the key hands the wheel
  back. Arrival brakes to a stop and turns the mode off.
- **SPEED LIMIT** — caps manual driving at the traffic pace (15) with the
  throttle alone; no brake trim, so the tail lamps stay off at the cap. A real
  overshoot still brakes.

## The pieces

- `src/extras/vcmodautodrive.{cpp,h}`: mode enum, session state (vehicle pool
  handle), saved AutoPilot fields, `VCModAutoDriveControl`,
  `VCModAutoDriveTick`, `VCModAutoDriveKey`, `VCModAutoDriveReset`.
- `vcmodtraffic.{h,cpp}`: `VCModTrafficPace()` — the one home for 15.
- Hooks: `Automobile.cpp` and `Bike.cpp` after `ProcessControlInputs(0)`;
  `PlayerPed.cpp` next to `VCModUpdateRide` (tick) and CALL DRIVER (key);
  `GenericGameStorage.cpp` resets the session on save load.
- `vcmodkeys`: `VCKEY_AUTODRIVE`, default `O`, label `AUTO DRIVE`, ini
  `KeyAutoDrive`.
- Panel DRIVING page: `AUTO DRIVE` cycle (`[OFF]`, `[SAFE]`, `[AGGRESSIVE]`)
  and `SPEED LIMIT` flag (`SpeedLimit`, default off); KEYS page `AUTO DRIVE KEY`.
- The ALL ON sweep leaves SPEED LIMIT alone on purpose.

## Styles (stock engine behaviour)

- `[SAFE]` = `DRIVINGSTYLE_STOP_FOR_CARS`: stops for cars and peds and at red
  lights.
- `[AGGRESSIVE]` = `DRIVINGSTYLE_AVOID_CARS`: runs red lights and weaves around
  other cars instead of waiting behind them; both still stop for lifting
  bridges.
- Both at cruise 15, `VCModTrafficPace()`. The cruise AI's sub-0.15 brake trim
  is dropped unless it is slowing for traffic, so the tail lamps stay off while
  the car just holds its pace.

## Play steps

1. Launch through the Dock app and confirm `vcmods build 612`.
2. Drive. Press `O` (or set the DRIVING page AUTO DRIVE row to `[SAFE]`):
   - with a map marker the car routes there, then brakes to a stop and the
     row returns to `[OFF]`;
   - without a marker it cruises like traffic.
3. Cycle the row to `[AGGRESSIVE]`: it should run reds and steer around the
   cars ahead instead of queueing behind them.
4. Take the wheel with the gas, brake, steering or handbrake; the press should
   apply on that frame and the log should say `VCMOD auto drive off: take the
   wheel`. Holding the gas while engaging does not cancel until it is released
   and pressed again.
5. SPEED LIMIT on, floor it on a straight: forward speed should settle at the
   traffic pace with no brake lamps; steering and reverse stay normal. A big
   overshoot (downhill) still brakes.
6. Exit the car, get busted, or wreck it: no stuck mission and no frozen car.

## What to watch in play

- Lane keeping, junction turns and the aggressive weave (the path strategy and
  the weave are the engine's own).
- The 3 m arrival brake: the car may roll a few metres past the marker; that is
  the stock mission-car arrival distance.
- The speed cap feel: at 15 the throttle is cut and the car settles with no
  brake lamps; only a real overshoot brakes. The pace is deliberately the
  traffic pace, not a fast cruise.
- A held input when engaging is latched, not cancelled; the next press after
  release takes the wheel.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Uncommitted in the checkout

- New: `src/extras/vcmodautodrive.{cpp,h}`,
  `utils/test_vc_autodrive.py`,
  `docs/specs/2026-11-15-autodrive-speedlimit-design.md`,
  `docs/plans/2026-11-15-autodrive-speedlimit.md`.
- Modified: `vcmodtraffic.{cpp,h}`, `vcmodkeys.{cpp,h}`,
  `vcmodpanelregistry.cpp`, `re3.cpp`, `PlayerPed.cpp`, `Automobile.cpp`,
  `Bike.cpp`, `GenericGameStorage.cpp`, and the harnesses that compile the
  panel row table or count key slots (`test_vc_passenger`, `test_vc_keys`,
  `test_vc_ammo`, `test_vc_adrenaline`, `test_vc_character`).

## Next

1. Play the steps above against build 612.
2. If the arrival brake overshoots too far, tune `VCMOD_AUTODRIVE_ARRIVE_NEAR`
   in `vcmodautodrive.cpp` (currently the stock 3 m).
3. The speed cap now holds by cutting throttle; a brake appears only on a real
   overshoot (a 0.15 pedal). The trim rule is in `VCModAutoDriveGovern`.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `46e9f0f`.
> The AUTO DRIVE + SPEED LIMIT work is installed as `vcmods build 612` in
> `~/Games/VC/reVC.app`. Read `AGENTS.md`,
> `docs/specs/2026-11-15-autodrive-speedlimit-design.md` and
> `docs/plans/2026-11-15-autodrive-speedlimit.md` first.
>
> Play the checklist in `docs/handoff/2026-11-15-autodrive-speedlimit.md`:
> marker route and arrival, SAFE stopping at reds and behind traffic,
> AGGRESSIVE running reds and weaving around cars, the take-the-wheel press and
> the held-gas latch, the speed cap with no brake lamps, and exit/death/wreck
> restore. Run all `reVC/utils/test_vc_*.py` and `scripts/build.sh` before
> handing off. Do not commit, tag or push unless asked; game data and the
> `uchg` anim files stay untouched.
