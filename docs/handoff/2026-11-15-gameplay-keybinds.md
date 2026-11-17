# Handoff: assignable keys for every gameplay mod

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `46e9f0f` (uncommitted work on top)
Installed: `vcmods build 609` in `~/Games/VC/reVC.app`
Harness: all green (52 files), including the rewritten `utils/test_vc_keys.py`

Every gameplay feature now has its own rebindable key slot on the panel's KEYS
page, and every slot ships unbound except `PANEL KEY` (`\`). Mechanic fixes and
cosmetic switches deliberately have no key: they stay panel-only.

## What has a key now

Gameplay actions and toggles, all default `NONE`:

- BECOME NPC, STREET IDLE, NEVER WANTED, ADRENALINE (cycles off/normal/slow-mo)
- CALL GANG, SKIP RIDE
- the existing set, now also default `NONE`: WALK MODE, FIRE, CALL DRIVER,
  SPIN KICK, RELOAD, CHASE SPOT, CHASE CAPTURE, 1ST PERSON, CALL CREW,
  PASSENGER, AMMO, AUTO DRIVE
- aim toggles: FREEAIM+LOCKON, NPC DOOM AIM, LOCKON LATCH, LOCKON VEHICLES
- driving toggles: SPEED LIMIT, WHEEL FALLS OFF, CREW AGGRESSIVE

No key by design (fixes / mechanics / cosmetics): AIM ALL WEAPONS, NO SCOPE
CAMERA, COLT TWO-HAND, GUN RECOVERY, AIM WALK, MANUAL RELOAD's own switch,
WASD MOVE, NPC TYPE, TYPE FROM BODY, TRAFFIC AI, VANILLA FIXES, COP CROUCH,
SHOOT PROJECTILES, EXPLOSION COVER, FBI LIGHTS, PED/RENDER RANGE, STEERING
WHEEL, LIGHT TEXTURES, BLADES AFTER BAIL, FIRETRUCK CANNON, and the DEBUG rows.

## How it works

- `src/extras/vcmodkeys.{h,cpp}`: 26 slots (`VCKEY_*`). Defaults and the reset
  default are all 0 except `VCKEY_PANEL` = `'\\'`. `VCModKeyJustDown(pad, slot)`
  is the one gate: false for an unbound slot, a nil/disabled pad, or an armed
  capture.
- `src/core/re3.cpp`: `KeyNpcMode`, `KeyStreetIdle`, `KeyNeverWanted`,
  `KeyAdrenaline`, `KeyGang`, `KeySkipRide`, `KeyFreeAim`, `KeyDoomAim`,
  `KeyLockOnLatch`, `KeyLockOnVehicles`, `KeySpeedLimit`, `KeyWheelLoss`,
  `KeyCrewAggressive` load before `VCModKeySanitize()`.
- Handlers live in the owning module (toggle + HUD notice + `VCMOD` log line):
  `vcmodnpc` (BECOME NPC, at the top of `VCModUpdateNpcMode`, including the
  street-idle hand-off), `vcmodstreet` (STREET IDLE, refuses with
  "street idle: npc mode is on" while the NPC command owns the body),
  `vcmodadrenaline` (`VCModAdrenalineCycle`), `vcmodcombat` (NEVER WANTED,
  NPC DOOM AIM), `vcmodplayer` (FREEAIM, LOCKON LATCH, LOCKON VEHICLES),
  `vcmodautodrive` (SPEED LIMIT), `vcmodwheel` (WHEEL FALLS OFF), `vcmodcrew`
  (CREW AGGRESSIVE). CALL GANG and SKIP RIDE reuse the existing
  `VCModGangGroupCall` / `VCModSkipRide` gates, so their refusals still speak.
- `src/peds/PlayerPed.cpp`: one guarded line per remaining slot, beside the
  existing H/V/O block.

## Panel KEYS page

- 27 rows: the gameplay actions first, then the existing tool keys, then the
  aim/driving toggles, then RESET KEYS at the bottom.
- The page is longer than the screen, so pages now scroll: `VCMOD_PAGE_ROWS` is
  20, the mouse wheel moves `nVCModPageScroll`, `^`/`v` marks show where scroll
  is left, and click/hover/list anchors use the visible row. Any future page
  over 20 rows scrolls the same way; the panel keeps one height.

## The one manual step

`reVC.ini` in the game folder already holds the old letters (`KeyWalk=66`,
`KeyFire=71`, ...). Those are valid bindings, so the empty defaults do not
apply to them until they are cleared once. On the KEYS page press **RESET
KEYS**: it now writes `NONE` to every gameplay slot and keeps `PANEL KEY` at
`\`. The ini is settings, not ours to edit from here.

## Verification done

- `./scripts/build.sh` clean; installed with `./scripts/install.sh` into
  `~/Games/VC/reVC.app` (no session was running).
- All 52 `utils/test_vc_*.py` pass. `test_vc_keys.py` pins: panel is the only
  shipped default, every ini key has a loader, every KEYS row has its slot,
  the helper refuses unbound/captured presses, and pages scroll.
- `test_vc_panel_info.py`: 80 rows, unique names, info/warning lengths.

## Not verified

Nothing here has been played. Assign a few keys in game, toggle each feature
from the key and confirm the HUD notice, then check that an unassigned press
does nothing and that RESET KEYS clears everything except `\`.

## Next steps

1. Play pass on the KEYS page: assign, rebind, reset, page scroll.
2. Check a toggle in each group: BECOME NPC (world), ADRENALINE (combat),
   LOCKON LATCH (aim), SPEED LIMIT (driving), CALL GANG refusal text.
3. Decide whether the remaining ambient/cosmetic switches need keys too; the
  slots are a one-line enum + row each if so.

## Files not to touch

- `anim/` game data (uchg). Never install with a session running.
- The uncommitted AUTO DRIVE/traffic/save work in the same tree is an earlier
  session's; do not revert or split it.
- `vc-mods.patch` is generated; nothing here is committed or pushed.
