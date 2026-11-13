# REBINDABLE HOTKEYS + INVERTED CAR CAM

Date: 2026-11-09
Repo/branch/HEAD: `reVC/`, `vcmods`, `d6070c5` plus the uncommitted work below.
Installed: `~/Games/VC/reVC.app` is `vcmods build 176` (installed by this session;
`pgrep` checked first, no session was running).

Neither change has been played. Everything here is compiled and harness-tested.

## What changed

### 1. The mod's hotkeys are rebindable in the panel

A sixth panel tab, **KEYS**, owns the eight direct key checks the mod made for
itself. Each row shows the live binding; clicking a row arms a capture and the
next key press becomes the binding (`Esc` cancels). **RESET KEYS** restores the
shipped letters.

| Row | Slot | Default | Consumed by |
|---|---|---|---|
| PANEL KEY | `VCKEY_PANEL` | `\` | `VCModPanelRender` |
| WALK MODE KEY | `VCKEY_WALK` | `B` | `CPlayerPed::ProcessControl` |
| FIRE KEY | `VCKEY_FIRE` | `G` | `CPlayerPed::ProcessControl` |
| CALL DRIVER KEY | `VCKEY_DRIVER` | `H` | `CPlayerPed::ProcessControl` |
| SPIN KICK KEY | `VCKEY_KICK` | `K` | `CPlayerPed::ProcessControl` |
| RELOAD KEY | `VCKEY_RELOAD` | `R` | `VCModManualReloadTick` |
| CHASE SPOT KEY | `VCKEY_SPOT` | `J` | `VCModChaseUpdate` |
| CHASE CAPTURE KEY | `VCKEY_CAPTURE` | `U` | `VCModChaseUpdate` |

- New `src/extras/vcmodkeys.{h,cpp}`: the codes in `aVCModKeys`, display names,
  arm/poll/cancel, `VCModKeyResetAll`, `VCModKeySanitize`, ini save.
- `PlayerPed.cpp`, `vcmodreload.cpp`, `vcmodchase.cpp` and the panel read the
  variables instead of `#define`s. The chase tier digits 0–4 and its
  Enter/Backspace keys stay fixed; the stock game controls stay in the pause
  menu's Controller Setup page.
- Capture goes through `CPad::EditCodesForControls`, the same scan the stock
  rebinding screen uses, so arrow/numpad/function keys work as well as letters.
- While a capture is armed every mod hotkey handler returns early, so the press
  used to bind does not also fire, reload or toggle. The panel key is guarded the
  same way, and a capture is cancelled if the debug menu takes the panel's place.
- A binding is written to `[VC Mods]` (`KeyPanel`, `KeyWalk`, …) on change, not
  through PERMA: it is a setting, not a pinned switch. `re3.cpp` reads them at
  startup and `VCModKeySanitize` replaces a nonsensical stored value with the
  default.
- `RELOAD ON R` on the COMBAT page is now `MANUAL RELOAD`; the key lives on KEYS.
- The footer hint that used to hardcode `G fire B walk …` is generated from the
  live bindings.
- Duplicate bindings are allowed (both actions fire).

### 2. Driving free camera: vertical axis inverted

`src/extras/vcmoddrivecam.cpp`: pushing up used to lower the camera and look up.
It now lowers the camera and looks down over the car. The right stick follows the
same flip; `Invert Mouse Vertically` / `Invert Look` still apply on top. Yaw is
unchanged.

## Verification

- `bash scripts/build.sh`: clean (Release, `.app` linked).
- All twenty-two `reVC/utils/test_vc_*.py` harnesses pass, including the new
  `test_vc_keys.py` (slots, ini round-trip, capture guard, KEYS page, key names,
  drive-cam signs). `test_vc_adrenaline.py` and `test_vc_character.py` compile the
  panel table and gained the new enum/stubs; `test_vc_passenger.py` and
  `test_vc_reload.py` follow the renamed row and key plumbing.
- `bash scripts/install.sh` into `~/Games/VC` with no session running
  (`vcmods build 176`).

## In play, to check

1. `\` → KEYS. Click WALK MODE KEY, press a letter, close the panel, press that
   letter: walk mode flips. The binding must not fire anything during capture.
2. Esc during a capture leaves the old binding.
3. RESET KEYS brings back `\ B G H K R J U`, and the footer hint follows.
4. Rebind one key, quit and relaunch: the binding is still there (reVC.ini).
5. Rebind the PANEL row: the panel stays open while the new key is pressed, and
   closes on the next press.
6. In a car with the free camera (mouse steering off): mouse up looks down over
   the car; left/right orbit is unchanged; the camera still eases back behind the
   car after 1.5 s idle.

## Uncommitted

This session:

- `src/extras/vcmodkeys.{h,cpp}` (new), `src/extras/vcmodpanel.cpp`,
  `src/peds/PlayerPed.cpp`, `src/extras/vcmodreload.cpp`,
  `src/extras/vcmodchase.cpp`, `src/extras/vcmoddrivecam.cpp`, `src/core/re3.cpp`
- `utils/test_vc_keys.py` (new), `test_vc_adrenaline.py`, `test_vc_character.py`,
  `test_vc_passenger.py`, `test_vc_reload.py`
- `README.md`, `CHANGELOG.md` (repo root)

Already in the tree from the previous session, not touched here:

- `src/extras/vcmodfiretruck.{cpp,h}`, `src/vehicles/Automobile.cpp`,
  `utils/test_vc_firetruck.py` (firetruck cannon aim work).

After committing: `scripts/sync.sh` regenerates `vc-mods.patch`.

## Do not touch

`~/Games/VC` and `~/Games/VC-ai` game data, especially `anim/cuts.img`,
`anim/cuts.dir`, `anim/ped.ifp` (immutable). The two-hand colt stance work is
settled. The chase prototype's tier digits and Enter/Backspace are deliberately
not rebindable.
