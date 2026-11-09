# Handoff — batch 3, explosion cover and FBI bars (2026-11-08)

## Where things are

- Workspace `vc-mod`, code in `reVC/`,
  branch `vcmods`, HEAD `d01bb3c` plus everything below uncommitted.
- Build `scripts/build.sh`; install `scripts/install.sh`; launcher `scripts/make-launcher.sh`;
  tests `python3 utils/test_vc_*.py` from `reVC/` (fourteen, all passing).
- Installed app `~/Games/VC/reVC.app` is still **`vcmods build 55`**. The tree builds **60**.
  The Dock launcher rebuilds and installs on every launch, so the first launch after this
  session delivers 60; a build number is not a change set.
- Logs `~/Games/VC/build-launch.log` and `~/Games/VC/reVC.log`.

## State

Batch 3 = the first three items of the picks doc's group 3. Two were code-only and are built;
the third is blocked on an asset. Both built items carry a panel row, an ini key under
`[VC Mods]` and membership in ALL ON/OFF.

| Item | Row / ini key | Status |
|---|---|---|
| Explosions are stopped by walls | `EXPLOSION COVER` / `ExplosionCover` | built, **not played** |
| FBI Car / Rancher roof light bars | `FBI LIGHT BARS` / `FbiLights` | built, **not played** |
| Fire truck water-cannon tower | `FIRETRUCK CANNON` / `FireTruckCannon` | model installed, code built, **not played** |

## What each change does

- **Explosion cover** — `CWorld::TriggerExplosionSectorList` now calls
  `VCModExplosionReaches(position, pEntity)` at the top of the radius branch and skips the
  entity when a building stands between. The test runs *before* `BlowUpExplosiveThings`, so a
  barrel or a car behind the wall does not chain. Only buildings count: a vehicle, ped or prop
  in the way does not shield a blast, which matches `ChangesEN:184` ("Wall protects against
  explosion").
- **FBI bars** — `MI_FBICAR` and `MI_FBIRANCH` joined the cruiser group in the siren switch, so
  they run the same four-corona animated bar as the police cars. The bar's two endpoints come
  from the model's own col box (`GetColModel()`, `boundingBox.max.x*0.75f` capped at 0.85,
  `boundingBox.max.z`), not from guessed vectors. With the toggle off the stock paths stand:
  the Rancher keeps its single stub corona at (0.4, 0.6, 0.3) and the FBI Car stays dark.

## The fire truck tower: where the model is

The tower is a model edit, and the pack ships it in an overlay archive, not as a loose
file: `GameFiles/modloader/ViceExtended/cdimages/vehicles.{img,dir}` in
`~/Downloads/vice-extended-october-2025-update_1788102643_908113.zip`. That IMG is
headerless with a separate 32-byte-record `.dir` (offset and size in 2048-byte sectors),
which is exactly the pair `CStreaming::LoadCdDirectory` expects — it derives `X.DIR` from
every mounted `X.img`.

What went into `~/Games/VC/mods/`:

- `mods/mods.ini` — one line, `firetruck`.
- `mods/firetruck/overlay.img` — 471 040 bytes, `firetruk.dff` (134 sectors) then
  `firetruk.txd` (96 sectors), taken verbatim from sectors 646 and 7199 of the pack's
  archive. sha256 `cc65b569…`.
- `mods/firetruck/overlay.dir` — two entries, offsets 0 and 134.

Verified offline: both chunks are RW 3.6, declare 272 596 and 196 536 bytes and fit their
sector allocations; the five texture names the DFF references
(`firetruk86body8bit128a/b`, `firetruk86body8bit64`, `firetruk86speca`, `firetruk8bit128`)
are all present in the shipped TXD. The model is 76 frames against stock's 48, keeps the
`chassis_dummy` / wheel / door dummy names the engine looks up, and its `vehicles.ide`
line is stock, so nothing else has to ship with it.

**Not in git.** A modified Rockstar model is not the mod's own asset, and
`AGENTS.md` says public packages carry no Rockstar data. It lives only in
`~/Games/VC/mods/`. Two things follow: a second machine needs the payload copied by hand
(or the pack installed on its own), and `scripts/package.sh --public` would currently
ship `mods/` because it only strips `data/` and `models/` — strip it there before the next
public archive.

The code half is `src/extras/vcmodfiretruck.{h,cpp}`: `VCModFireTruckCannonPos()` returns
`(0, 1.05, 2.0)`, the tower mount measured off the model with the jet lifted clear of the
pedestal top (1.88), and both `FireTruckControl` branches use it. With the toggle off each
site keeps its stock vector, `(0, 1.5, 1.9)` for the player and `(0, 0, 2.2)` for the AI
driver — that split, not the model, is what made the jet move when the driver changed.

The same toggle adds arrow-key aiming. The stock path reads
`CPad::GetCarGunLeftRight/UpDown`, which only ever return the right stick or D-pad; a
keyboard fills neither, so the cannon was unaimable without a gamepad and `m_fCarGunLR`
never left zero. While the fire button is held, the arrow keys now feed the same rates as
the stick, so they aim — with the caveat that the arrows still steer the truck too.

How the mount was measured, if it ever needs redoing: parse the clump, read the frame list
(56-byte records: 9 rotation floats, 3 position floats, parent index, flags) and each
geometry's vertices (the morph-target block starts at a 4-float bounding sphere followed by
`hasPositions=1, hasNormals=1`), then take the body mesh's vertices above z 1.6. Stock stops
at a flat roof of z 1.66; the pack adds an 18 cm pedestal over `y 0.97..1.14` topping out
at z 1.88.

## Unverified constants (ours, not from the pack)

- Explosion cover: ray is lifted 0.5 m at both ends so a blast sitting on the ground does not
  block itself on the terrain, and starts 0.5 m along the ray so a blast that went off against
  a wall is not read as being inside it. Blasts closer than 1 m always count.
- FBI bar: lateral half-width `max.x * 0.75`, capped at 0.85 m; height is the col box top;
  lengthwise centre is the model origin. If a bar sits high or short in play, that is which
  number to move.
- Firetruck cannon: z 2.0 is the pedestal top (1.88) plus 12 cm of clearance. Play reported
  the jet starting below the nozzle at 1.9, so the clearance is ours, not measured; it is the
  number to move if the jet now floats above the mouth.
- Arrow aim rate: arrows count as a 128-of-255 axis, so half a stick's speed.

## Traps paid for

- `MI_FBIRANCH` already had a siren case — one blue corona, low on the body, drawn only when
  the car points away from the camera. It shares that case with `MI_VICECHEE`. A second
  `case MI_FBIRANCH:` in the same switch does not compile, so the feature had to merge the two
  groups rather than append a case; the stock stub now lives inside the merged branch behind
  `!bVCModFBILights`.
- The blast position of a rocket or grenade fired into a wall is inside that wall's col model.
  Without the step-out, every victim reads as covered and explosions stop doing damage.
- Terrain is collision too: a ray along the ground can be blocked by the ground, so the cover
  test is taken at 0.5 m up.
- Adding a row means bumping the count in `utils/test_vc_passenger.py` (now 35) and adding the
  new flag stubs to `utils/test_vc_adrenaline.py` and `utils/test_vc_character.py`, which
  compile an extracted copy of the panel arrays.
- The pack's archive has no `VER2` header: it is a bare IMG with a separate `.dir` of
  32-byte records. An `overlay.img` without its `overlay.dir` mounts as an empty archive and
  silently does nothing, because `LoadCdDirectory` builds the `.DIR` name from the image name.
- A keyboard never fills `DPad` or `RightStick`, and the pad runs in mode 0, so every
  `GetCarGun*` accessor returns 0 on this machine. Any vehicle turret that only reads those
  is unusable here; `CPad::GetUp/Down/Left/Right` read the arrow keys directly.
- To prove an overlay really took, grep `reVC.log` for two things: `mods: mounting …overlay.img`
  and `<name>.dff appears more than once in MODELS\GTA3.DIR`. The second line is the stock
  entry being rejected, i.e. the overlay won.
- Overlays win by mount order, not by a name search in the loader: images are walked from the
  last index down and the first entry seen for a name sets its position, so the stock entry
  only loses if the overlay is mounted after it (it is).
- Another agent is in this tree at the same time: `src/extras/vcmoddriveby.*`, touching
  `re3.cpp`, `vcmodpanel.*`, `Weapon.*`, `PedAI.cpp`, `PlayerPed.cpp` and
  `utils/test_vc_adrenaline.py`. It added the `PASSENGER DRIVEBY` panel row, which is why the
  row count is 35 and not 34. Re-read those files before editing; the count is shared.

## Uncommitted in `reVC/` (the user commits; never push)

- **Batch 1** — `src/extras/vcmodqol.{h,cpp}`, wiring in `Hud.cpp`, `Automobile.cpp`,
  `PlayerInfo.cpp`, `Particle.cpp`, `re3.cpp`, `vcmodpanel.cpp`; `utils/test_vc_qol.py`.
- **Startup crash fix** — `src/core/FileMgr.cpp`, `bundledPath` lifetime in `myfopen`.
- **Bundle identity** — `res/macos/Info.plist` builds as `…reVC.dev`; `scripts/install.sh`
  stamps the shipping id and supports `BUNDLE_ID` (mirrored into `gta-vc-dream-mod/`).
- **Version line** — build counter in `src/CMakeLists.txt`, drawn from `src/core/main.cpp`;
  `scripts/make-launcher.sh` logs the number after install (both copies).
- **Batch 2** — new modules `src/extras/vcmod{reload,copcover,wheel,rotor,shootable}.{h,cpp}`;
  edits to `src/peds/Ped.h`, `src/peds/PedAI.cpp`, `src/peds/PedFight.cpp`,
  `src/vehicles/Automobile.{h,cpp}`, `src/weapons/Weapon.cpp`, `src/core/re3.cpp`,
  `src/extras/vcmodpanel.cpp`; tests `utils/test_vc_{reload,copcover,wheel,rotor,shootable}.py`.
  Reload, cop crouch and wheel loss are verified in play; rotor blades and shootable
  projectiles are built but unplayed, and the owner chose to keep them rather than test them.
- **Batch 3** — new modules `src/extras/vcmodexplosion.{h,cpp}`, `src/extras/vcmodfbilights.{h,cpp}`
  and `src/extras/vcmodfiretruck.{h,cpp}`; edits to `src/core/World.cpp`,
  `src/vehicles/Automobile.cpp`, `src/core/re3.cpp`, `src/extras/vcmodpanel.cpp`;
  tests `utils/test_vc_{explosion,fbilights,firetruck}.py`, plus the three harness touch-ups
  above. The fire truck asset itself is not in git; see its section.
- **Not ours** — `src/peds/PlayerPed.cpp` is another agent's kerbside road-cross look, and
  the `vcmoddriveby.*` module plus its wiring is a third agent's work in flight.
  Do not edit or stage either.

## Next, in order

1. Play the batch-3 items. Explosions: fire a rocket into one side of a building and
   confirm nothing on the far side moves; a barrel behind the wall must not chain. FBI bars:
   get a wanted level high enough for the FBI Car / Rancher and look at the roof; ALL OFF
   must return the stock Rancher stub and a dark FBI Car. Fire truck: the roof should carry
   the raised mount and the jet should start there whether you or the AI drives.
2. Commit batches 2 and 3. This is one coherent tree; the `FileMgr.cpp` lifetime fix reads
   better in its own commit if the user prefers to split it.
3. Remaining picks are the large ones (first person, autosave) and the asset-dependent ones
   (steering wheel, lamp textures, cast-light split, newspapers).

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Check `git status` and the newest handoff before touching `src/core/re3.cpp`,
  `src/extras/vcmodpanel.*`, `src/peds/PlayerPed.cpp`; each was owned by another agent.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is
  read-only.
- The user tests in game; do not call an unplayed change fixed, and do not install while
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` is non-empty.
