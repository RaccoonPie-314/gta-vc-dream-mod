# Handoff — Vice Extended: vehicle lights, spawner, stock police (2026-11-09)

## Where things are

- Workspace `vc-mod`, code in `reVC/`, branch `vcmods`, HEAD `d6070c5` plus the uncommitted
  tree below.
- Installed `~/Games/VC/reVC.app` is **`vcmods build 195`**.
- Build `scripts/build.sh`; install `scripts/install.sh`; tests `python3 utils/test_vc_*.py`
  from `reVC/` (twenty-five, all passing).

## Confirmed in play

- Reload on a key, wheel falls off, steering wheel turns.
- Police cruiser: stock model back, bar lights on its roof blocks, owner called it correct.
- Car light cubes: faded out up close; owner confirmed fixed.
- FBI Car, FBI Rancher and Vice Cheetah: all three light correctly (Cheetah explicitly "looks
  good"; the set was confirmed at build 194).
- The vehicle spawner reached the Vice Cheetah for that test.

## Still unobserved

The owner will verify these himself, one at a time: rotor blades after bail, shootable
projectiles, explosion cover, pack wheels, the lamp-face light textures, and the red tail in
reverse. They are **pending**, not confirmed.

## What is left from the picks list

`docs/plans/2026-11-08-vice-extended-picks.md` is the list; everything code-only is in.

1. **Cast-light split** (`ChangesEN:128`) needs a definition. Our tree already casts front
   light as `headlight` and rear light as `shad_exp` (the explosion sprite). Both stock and
   pack `particle.txd` carry the same names (`headlight`, `shad_exp`, `lamp_shad_64`); the
   pack added no taillight texture. The only spare candidate is `lamp_shad_64` (the lamp-post
   pool), which would replace the rear explosion sprite. Owner's call.
2. **Unique newspapers** (`ChangesEN:18`): the pack ships `txd/newspapers.txd`, 22 mission
   textures. Needs a mission-completed hook and a texture swap; Rockstar-derived, so local-only
   under `~/Games/VC/mods/` like the wheels.
3. **First person** (`ChangesEN:152`, L): `CCam::Process_1stPerson` exists; needs weapon/clump
   visibility, aim handoff and collision, against the existing aim and camera mods.
4. **Autosave after missions** (`ChangesEN:91`, M): needs the mission hook plus a policy (when,
   which slot, overwrite?).

## What changed this session

The pack's car and bike models carry a lit lamp texture beside the unlit one: their TXDs hold
`lights` + `lightson` (police also `servicelights` + `servicelightson`), while the DFFs
reference only the unlit one. Stock reVC draws the unlit face, so the lamps never glow.

- New `src/extras/vcmodlighttex.{h,cpp}`.
  - `VCModLightTextCollect` runs for every material while
    `CVehicleModelInfo::FindEditableMaterialList` rebuilds the editable lists; it records the
    materials whose texture is `lights` or `servicelights` together with the unlit texture.
  - `VCModLightTextRender` runs at the top of `CAutomobile::Render` and `CBike::Render`,
    right after `SetVehicleColour`, and points each recorded material at `lightson`
    (`servicelightson` for the police bar) when that vehicle's lights are on, otherwise back
    at the unlit texture.
  - `CVehicleModelInfo` gained `m_numLightMaterials`, `m_lightMaterials`, `m_lightOffTex`,
    `m_lightOnTex`, `m_lightPair` and a `m_lightTexTried` mask (`NUM_LIGHT_MATERIALS = 32`,
    reset in the constructor, `DeleteRwObject` and `FindEditableMaterialList`).
- Panel row `LIGHT TEXTURES` on DRIVING between `STEERING WHEEL` and `WHEEL FALLS OFF`, in
  ALL ON/OFF; ini key `[VC Mods] LightTextures`, default on; debug-menu entry
  `lit car lamp textures`; `utils/test_vc_lighttex.py`.
- **Car light cubes** — play reported a cube of light at the back of the car. That is stock:
  `CBrightLights::Render` draws every front/rear car lamp as a translucent 8-vertex 3D box
  (`CubeIndices`), holding at alpha 31 closer than 15 m. The box now fades from 31 at 15 m to
  0 at 8 m (`CARLIGHTS_BOX_OFF_DIST`), so at driving/parking distance only the lamp face and
  its corona draw the light. Far behaviour (15–30 m) is unchanged. Front and rear share the
  code, so both fade. Traffic lights and sirens keep their own alpha paths.
  Harness `utils/test_vc_carlights.py`.
- **FBI / Cheetah siren uses the stock bar code, seated per model** — the owner compared
  against the cruiser and asked for the bar effect, not a custom lamp:
  - FBI Rancher: one lamp in the cabin at the pack's seat, `pos1 = pos2 = (0.71, 1.1, 0.6)`.
    A four-corona bar on the cab roof was tried first; play reported it missing on the roof
    (the seat did not sit over visible geometry), so the Rancher joined the other two.
  - FBI Car: `pos1 = pos2 = (0.54, 0.74, 0.36)`.
  - Cheetah: `pos1 = pos2 = (0.4, 0.6, 0.3)`; play marked this one correct.
  They run the stock loop, so the timing, colours (red/blue), fade and the `CPointLights`
  road glow are the cruiser's own; only the seat differs. Toggle off: the FBI Car is dark
  and the Rancher / Cheetah keep their stock stub. The earlier custom single lamp (0.8 size,
  `255,80,80` / `0,80,255`, no point light) is gone — it read as a dot next to the bar.
- Owner note at build 195: the glow reads a little static because the four coronas are stacked,
  so there is no travel like a real bar. A ±5–10 cm spread was offered to bring the sweep back;
  owner declined for now.
- **Vehicle spawner** — play could not find the Vice Cheetah to test it. The DEBUG page gained
  `SPAWN VEHICLE`, which opens a list of every car model in the install, sorted by IDE name,
  wheel-scrolled 16 rows at a time. Picking one queues it; `VCModSpawnTick()` in
  `CGame::Process` streams the model and spawns it 4.5 m ahead of the player, unlocked and
  on the road. New module `src/extras/vcmodspawn.{h,cpp}`; harness
  `utils/test_vc_spawn.py`.
- **Police bar narrowed to its roof blocks** — the stock bar blocks sit within ±0.31 and top
  out at z 0.95, while upstream sweeps the coronas at ±0.7. The four-corona line now runs
  `(±0.3, -0.55, 0.97)` to match the block spacing.
- **Stock police model restored** — play wanted the roof light bumpers back. The pack's
  POLICE replacement lacked them, so `~/Games/VC/mods/stockpolice/overlay.img` (+ `.dir`,
  2 entries: POLICE.DFF 86 sectors, POLICE.TXD 39) carries the stock files extracted from
  `models/gta3.img`, and `mods.ini` lists `stockpolice` **after** `vehicles` so it wins the
  mount-order clash. Local-only, like the other pack assets. Backup of the old manifest:
  `/tmp/mods.ini.bak`.
- **Tail lamps stay red in reverse** — the stock code washes the tail coronas white while
  reversing, which play reads as the red being overwritten. The white path is gone; the tail
  keeps red (brake boost included). `CAR_POS_REVERSINGLIGHTS` had no other reader, so the
  marker and its model assoc were removed. Pack models that carry reversing lamps show white
  on those lamps through the light-texture swap.
- The lit texture is looked up lazily on first use through the model's TXD slot
  (`CTxdStore::GetSlot(GetTxdSlot())->texDict`), because the dictionary is not guaranteed to
  be loaded when the material list is built. A model without the lit texture (every stock
  car) is marked tried and falls back to the unlit face.

Assumption to check in play: the pack switches the texture and expects the lit art to read as
glowing on its own. If the lamps look bright but still shaded (dim at night), the next step is
an emissive draw, not another texture.

## To check in play

1. Drive a replaced car at night with the lights on: the lamp faces should show the lit art;
   switch the lights off and they should go back to plain glass.
2. Park a car with the lights on next to a same-model car with them off. The shared-material
   trap is the thing to watch: each car must show its own state at the same time.
3. Police car with the siren on but headlights off: the roof bar should light.
4. `LIGHT TEXTURES` off in the panel (and ALL OFF): lamps back to the unlit face on the next
   frame.
5. Stock cars must look unchanged.
6. Car light cubes: stand behind a parked car with its lights on. There must be no translucent
   box around the lamps; at 15 m and farther the glow should look as before. If a glowing
   block is still there, check whether it is the lamp face itself: toggle `LIGHT TEXTURES`
   off — a block that disappears is the lit lamp texture, not the bright-light box.
7. FBI Rancher, FBI Car and Vice Cheetah: four coronas stacked in one lamp inside the
   cabin — same red/blue sweep and road glow as the cruiser, just one seat instead of a bar.
   All three were confirmed at build 194/195; toggle off returns the stock stub
   (Cheetah/Rancher) and a dark FBI Car.
8. Reverse in any car: the tail lamps stay red, no white wash. Pack models with their own
   reversing lamps should show white on those lamps instead. **Not re-reported since the
   change.**
9. Police: the bar lights sit on the roof blocks; stock police model back with its roof
   bumpers. Confirmed correct at build 187.
10. Spawner: DEBUG tab → `SPAWN VEHICLE` → wheel to `Vice Cheetah` → click. The car appears
    4.5 m ahead, unlocked. Used successfully for the Cheetah test.

## Where the FBI Car actually comes from

At wanted level 5 the chase car is always the **FBI Rancher** —
`CCarCtrl::ChoosePoliceCarModel` returns `MI_FBIRANCH` and never `MI_FBICAR`
(`src/control/CarCtrl.cpp:876`). The FBI Car only appears in **roadblocks** at that tier
(`src/control/RoadBlocks.cpp:214`) or when a mission scripts it. That is why it is never seen
in ordinary play; use the spawner to reach it.

## The pack's source is public

`github.com/x87/gta-extended` (miami branch) is the framework the pack's exe was built from
(its PDB paths say `D:\Modding\GTA\VC\gta-extended\src\...`). It carries the pack's vehicle
work under `IMPROVED_TECH_PART` and `IMPROVED_VEHICLES` in `src/vehicles/Automobile.cpp`:
per-lamp textures keyed on the `taillight_l/r`, `reversinglight_l/r`, `brakelight_l/r` nodes;
the `#ifndef IMPROVED_VEHICLES` removal of the bright-light cubes; and the split light shadow
with separate reversing tint. Anything else on the picks list that needs the pack's mechanic
should be read there before inventing positions.

## Uncommitted

Ours this session:

- `src/extras/vcmodlighttex.{h,cpp}` (new)
- `src/modelinfo/VehicleModelInfo.{h,cpp}`, `src/vehicles/Automobile.cpp`,
  `src/vehicles/Bike.cpp`, `src/core/re3.cpp`, `src/core/Game.cpp`,
  `src/extras/vcmodpanel.cpp`, `src/renderer/SpecialFX.cpp`
- `src/extras/vcmodspawn.{h,cpp}` (new)
- `utils/test_vc_lighttex.py`, `utils/test_vc_carlights.py`, `utils/test_vc_spawn.py` (new),
  `test_vc_passenger.py` (row count 47), `test_vc_adrenaline.py`, `test_vc_character.py`
  (flag and spawner stubs), `test_vc_fbilights.py` and `test_vc_rearlights.py` (rewritten for
  the pack mechanic and the red tail)

Already in the tree from the previous session, not touched here: the rebindable-keys work
(`vcmodkeys.*`, panel, `PlayerPed.cpp`, `vcmodreload.cpp`, `vcmodchase.cpp`,
`vcmoddrivecam.cpp`, tests, README/CHANGELOG) and the firetruck cannon aim changes. The user
commits.

## Traps paid for

- A `CPointLights` light on an interior lamp tints the whole car body its colour. A coloured
  corona alone is the brightness knob; do not add a point light to a lamp that sits inside
  the cabin.
- A spawner pick must not stream or allocate from the panel: the panel is drawn inside the
  frame render. Queue the model and run it from `CGame::Process`.

- `CTxdStore::isTxdLoaded` is declared in `src/rw/TxdStore.h` but never defined; using it
  links and then fails at the final link step. Use `GetSlot(slot)->texDict` with a nil check.
- `scripts/build.sh` pipes the build through `grep`; a link error scrolls past unless the
  script's exit status is checked. The first build this session failed on that symbol and
  printed only the "Linking …" line at the tail.
- `scripts/install.sh` rsyncs the build bundle with `--delete`. Installing after a failed link
  (the build bundle had no executable) briefly left `~/Games/VC/reVC.app` without its binary.
  Check `reVC/build/src/reVC.app/Contents/MacOS/reVC` exists before installing; the rebuild
  and install restored the app at build 179.
- The materials belong to the clone-shared geometry, not to each car, so a texture set once at
  model load would light every car of that model. The switch has to ride the render call, the
  same reason `SetVehicleColour` mutates shared materials there.
- Lamp material capacity: parsed from the pack's DFFs, the busiest model is the police car at
  21 lamp materials (12 `lights` + 9 `servicelights`), so `NUM_LIGHT_MATERIALS = 32` has room;
  a bigger model would silently lose its extra lamps.
- The pack's models are re-centred in x (sometimes z) against stock, so comparing raw DFF
  bounds between the two misleads. The POLICE body matches stock; the Cheetah does not.

## Next, in order

1. The owner commits the tree (stage explicit paths; never push the reVC repo for him).
2. He verifies the pending items one at a time: rotor blades, rockets, explosion cover, pack
   wheels, lamp textures, red tail in reverse.
3. Then pick the next feature: cast-light split decision, newspapers, first person or autosave.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Check `git status` and the newest handoff before touching `src/core/re3.cpp`,
  `src/extras/vcmodpanel.*`, `src/peds/PlayerPed.cpp`.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is
  read-only. Pack assets live only under `~/Games/VC/mods/`, never in git or a public package.
- The user tests in game; do not call an unplayed change fixed, and do not install while
  `pgrep -x reVC` is non-empty.
