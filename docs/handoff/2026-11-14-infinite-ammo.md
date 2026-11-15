# Infinite ammo toggle

## What shipped

An `INFINITE AMMO` switch on the panel's COMBAT page. It reuses the reward the
engine already gives a 100% save: the clip still empties and reloads, but the
player's total ammo stops dropping. The switch grants that behaviour below
100%. With it off the engine path is stock, so a finished save keeps the reward
even with the row off — the row reports the mod switch, not the effective state.

The detonator keeps spending charges and the 25000-ammo cap stays, exactly as
they do at 100% completion. Toggling changes nothing else: no HUD edits, no
anim, no state to restore.

A rebindable hotkey was added as `AMMO KEY` on the KEYS page. It ships
**unbound** (`NONE`); click the row, press a key, Esc cancels. RESET KEYS puts
it back to unbound. The tick sits next to the driver/crew keys, so it answers
on foot and behind the wheel. The switch is not part of the ALL ON sweep.

## Where it lives

- `src/extras/vcmodammo.{h,cpp}` — flag, `VCModInfiniteAmmoActive()`,
  `VCModInfiniteAmmoKeyTick()`.
- `src/weapons/Weapon.cpp` — two one-line gate changes
  (`CWeapon::Fire`, `CWeapon::FireFromCar`); `!VCModInfiniteAmmoActive()`
  replaces the progress test. Both stock exceptions are left in place.
- `src/peds/PlayerPed.cpp` — one call next to the H/V keys.
- `src/extras/vcmodpanelregistry.cpp` — COMBAT row, KEYS row, debug-menu entry.
- `src/extras/vcmodkeys.{h,cpp}` — 12th slot (index 11), default 0,
  `VCModKeyName(0)` now reads `NONE`.
- `src/core/re3.cpp` — `InfiniteAmmo` and `KeyAmmo` ini reads.
- `utils/test_vc_ammo.py` — predicate truth table plus wiring checks.

## Verification

- Full harness suite: 48 files, all green. `test_vc_keys.py` now expects twelve
  slots; `test_vc_passenger.py` row count corrected from 58 to 61.
- `test_vc_adrenaline.py` and `test_vc_character.py` were already red before
  this work: their stub panels lacked the gang-group symbols from the
  uncommitted CALL GANG work. Stubs for `VCModGangGroupCell/Alive/Call` and the
  new ammo symbols were added; the gang feature itself was not touched.
- Built with `scripts/build.sh`; symbols
  `VCModInfiniteAmmoActive`, `VCModInfiniteAmmoKeyTick`, `_bVCModInfiniteAmmo`
  present in the installed binary.
- Installed into `~/Games/VC/reVC.app` with no session running.
- Not yet played. In-game checks to run: switch on below 100% and fire several
  clips (`m_nAmmoTotal` holds, clip cycles, HUD total stops dropping); detonator
  still spends charges; drive-by uzi does not drain; toggle from a car; bind
  `AMMO KEY` from the KEYS page and press it; row stays OFF on a 100% save
  while ammo is still infinite (stock).

## Uncommitted at handoff

This session: the files listed above. Also in the tree from earlier work, not
touched here: CALL GANG (`vcmodganggroup.*`, panel and registry rows) and the
drive-camera hold. Nothing was committed.

## Not to touch

- Game data (`~/Games/VC`, `~/Games/VC-ai`, `~/Library/Application
  Support/reVC/`), including the `uchg` anim files.
- Never install while a session runs.
- `src/weapons/Weapon.cpp` gate lines: the detonator and 25000 exceptions are
  deliberate.
