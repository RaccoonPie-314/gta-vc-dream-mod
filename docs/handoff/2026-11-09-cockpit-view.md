# Handoff — cockpit (first-person) driving view (2026-11-09)

## Where things are

- Workspace `vc-mod`, code in `reVC/`, branch `vcmods`.
- HEAD `8d57f7c`; uncommitted: the new module, the camera hook, the key slot, the
  panel rows and the harnesses listed at the bottom.
- Installed `~/Games/VC/reVC.app` is **`vcmods build 204`**; the bonnet camera is built
  in `reVC/build/` and installs on the next launch from the dock.
- Build `scripts/build.sh`; install `scripts/install.sh`; tests `python3 utils/test_vc_*.py`
  from `reVC/` (twenty-six, all passing).

## What shipped

A cockpit view for driving. The user asked for the vehicle view only, no on-foot first person.

The camera is **stock**: `CAM_ZOOM_1STPRS` → `CCam::MODE_1STPERSON` → `CCam::Process_1stPerson`'s
vehicle branch already exists in this tree and puts the view at `ped_frontseat` with x forced to 0
(between the seats), +0.08 y, +0.62 z, FOV 60, Front/Up taken from the vehicle matrix (so no
look-around), a bike lean matrix, +0.5 z for boats, and a neck-height camera on a driven bike.

**The first attempt was wrong and is gone.** It forced `ReqMode = MODE_1STPERSON` from
`CCamera::CamControl` behind a mod flag. Play reported no view at all. The rewrite below needs no
camera write: the mod only moves the ring stop that the stock code already reacts to.

- **The view is above the bonnet, not at the seat.** The seat camera was tried in play first and
  the car was absent from the frame — Vice City car bodies are single-sided shells, so from inside
  there is nothing to see and the view reads as a floating camera. `CCam::Process_1stPerson`'s
  vehicle branch now, when `VCModCarFirstPersonOn()`, takes the car's own `bonnet_dummy` world
  position (`m_aCarNodes[CAR_BONNET]`, `GetComponentWorldPosition`) and puts the eye at
  `bonnet + Up*0.22 - Front*0.20`. Bikes and boats keep the stock seat camera; a car without a
  bonnet node falls back to it.
- New `src/extras/vcmodfirstperson.{h,cpp}`: `On()` reads `TheCamera.CarZoomIndicator ==
  CAM_ZOOM_1STPRS`, `Set()` writes `CAM_ZOOM_1STPRS` or `CAM_ZOOM_2`, `Toggle()` flips it and logs
  `vcm: cockpit view on|off`, and `Tick()` reads the mod key. Called from `CGame::Process` after
  `VCModSpawnTick()`, before `TheCamera.Process()`.
- `src/core/Camera.cpp` is **untouched** by this feature: the stock branch
  (`CarZoomIndicator == CAM_ZOOM_1STPRS && !m_bPlayerIsInGarage` → `ReqMode = MODE_1STPERSON`)
  builds the mode, and the stock change-camera key cycles out of it.
- Key `VCKEY_FIRSTPERSON`, default `C`, label `1ST PERSON`, ini `KeyFirstPerson`; panel row
  `1ST PERSON` (DRIVING, cycle, ini `CarFirstPerson`) and `1ST PERSON KEY` (KEYS); debug tweak
  `1st person car camera` calls the same toggle. The row reads the ring, so pressing the stock
  camera key updates it instead of leaving a stale wish.
- Ring arithmetic, for the record: the stops are `CAM_ZOOM_1STPRS`(0), 1, 2, 3, TOPDOWN(4),
  CINEMATIC(5); the cycle starts at 2, so the stock change-camera key reaches the stop on its
  **second** press. That is why `V` alone looked like it did nothing.
- Harness `utils/test_vc_firstperson.py`; `test_vc_passenger.py` row count 49 and
  `test_vc_keys.py` nine slots updated, plus the two panel-extraction drivers
  (`test_vc_adrenaline.py`, `test_vc_character.py`) which stub the key enum and now the cycle.

## To check in play

1. Get in a car, press `C`: the eye sits just over the bonnet and the car's nose fills the bottom
   of the view, looking where the car points. Press `C` again or the stock change-camera key to
   come back out. The same switch is the `1ST PERSON` row on DRIVING.
2. Is 0.22 m above the bonnet the right height, and 0.20 m back the right distance? Too high and
   the bonnet leaves the frame; too low and the panel fills it. Both are one constant each in
   `Process_1stPerson`.
3. Drive: the camera must follow the car with no lag or swim, and the near clip must not slice
   the bonnet on the replaced models.
3. The driver's own head and hands: the camera sits between the seats, so the head should be off
   to one side. If it fills the frame edge, the next step is hiding the player ped's head while
   the view is on, not moving the camera.
4. A bike and a boat: both are wired. On a bike the stock wheelie cam can take over, which is
   stock behaviour.
5. Exit the car: the on-foot camera must come straight back, and the toggle must stay set for the
   next car.
6. Reverse into a garage and take a wide-screen scripted moment: the chase camera must stay.

## Known limits, by design

- No look-around: the stock vehicle first-person branch locks the view to the car's own axes.
  Adding mouse look means reworking that branch the way the ped branch does it — a separate job.
- No aim handoff or weapon hiding; drive-by in this view is whatever the stock code draws.
- No on-foot first person (out of scope per the request).

## Traps paid for

- `CAM_ZOOM_1STPRS` is a ring stop, not an on/off switch, and it is the **second** press of the
  stock change-camera key from the default zoom. Pressing the key once looks like nothing changed;
  that is what the first report was.
- Forcing `ReqMode` from the mod did not produce the view and is not coming back; if the toggle
  ever stops working, check `TheCamera.CarZoomIndicator` in the log line the toggle writes before
  touching `CamControl`.
- `CarZoomValue` must be 0 in this mode; the stock 1STPRS branch sets it and the `else if` chain
  below would overwrite it with a zoom distance. Writing the ring stop is what gets that right;
  writing `ReqMode` alone leaves `CarZoomValue` at a chase distance.
- `MODE_1STPERSON` enters by jump cut, so there is no smoothing to fight on the way in.
- Automobile.cpp already skips the player's own headlight coronas when
  `Mode == MODE_1STPERSON && this == FindPlayerVehicle()`, so the cockpit view does not stare into
  its own lamps — do not "fix" that branch.
- Camera.cpp's motion blur keys off `MODE_1STPERSON && FindPlayerVehicle() && GetUp().z < 0.2f`
  (upside down), which now applies to the cockpit view as well; that is stock and correct.
- Two harnesses brace-extract the panel and stub the world around it
  (`test_vc_adrenaline.py`, `test_vc_character.py`): any new row, switch or key slot needs a stub
  there too or they fail to compile.

## Next, in order

1. The owner commits this work (explicit paths; never push).
2. He plays it; the pending queue from the previous handoff is unchanged: rotor blades, rockets,
   explosion cover, pack wheels, lamp textures, red tail in reverse.
3. Then the pick list is down to newspapers and autosave.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is
  read-only. Pack assets live only under `~/Games/VC/mods/`, never in git or a public package.
- The user tests in game; do not call an unplayed change fixed.
