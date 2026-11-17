# KEYS: CONTROLLER BINDS, CHORDS AND BIND CLEARING

Date: 2026-11-16
Repo/branch/HEAD: `reVC/`, `vcmods`, `bfc0d4d0` plus the uncommitted work below.
Installed: `~/Games/VC/reVC.app` is `vcmods build 626`. The tree is now at
`vcmods build 630` (physical-button binds, pad navigation, row-wide hover) but
was not installed: a session (pid 50900) was running at the end of the session.
Install with `scripts/install.sh` once the game is closed.

Not played yet. Compiled for macOS and Windows-neutral code; all fifty-three
`reVC/utils/test_vc_*.py` harnesses pass.

## What changed

### 1. Every hotkey slot holds a keyboard chord and a pad chord

- `aVCModKeys[]` keeps the keyboard bind, now packed `key1 | key2 << 16`
  (16-bit halves). A value written by an older build is a plain code, which
  unpacks as a single key — no conversion pass.
- New `aVCModPads[]` holds the pad bind, packed `btn1 | btn2 << 8`.
- Bindable pad buttons: Cross, Square, Triangle, Circle, L1, L2, R1, R2, the
  four D-pad directions, Start and Select (`eVCModPadButton`). The sticks have
  no just-down edge, so they are not offered. No slot ships bound to a button.
- Pad binds follow the **controller's own buttons**, not the game actions the
  stock controller setup maps them to. On the GLFW and SDL capture paths
  `CControllerConfigManager::GetPhysicalPadMask()` turns the raw gamepad state
  into a button mask, and `CapturePad` records it every frame with
  `VCModKeyPadFrameMask` (zero when no pad is attached). XInput has no
  controller setup in between, so `CPad::Update` builds the same mask from
  `PCTempJoyState` there. Consequences: a mouse click no longer binds or fires
  the pad button the stock setup synthesises it into (LMB = fire = Circle), and
  a physical press shows its own button name even after the player rearranges
  the stock controller setup. A joystick the game does not recognise as a
  gamepad has no stable button order, so it contributes no mask.
- Pure helpers in `vcmodkeys.{h,cpp}`: `VCModKeyChord/FirstOf/SecondOf`,
  `VCModPadChord/FirstOf/SecondOf`, and `VCModChordFires`, which is the one rule
  both channels and every consumer share: a slot fires when its whole chord is
  held and the last input landed this frame.

### 2. Capture binds one channel, and a held first input upgrades to a chord

- `VCModKeyArm(which, VCKEY_CHANNEL_KEYBOARD | VCKEY_CHANNEL_PAD)`;
  `VCModKeyPoll` scans only the armed channel — keyboard through the pad's
  key-state just-down accessors, pad through `NewState`/`OldState`.
- The first input commits as a single bind at once; the arm stays until that
  input is released. A second input pressed while the first is held rewrites the
  slot as a chord. Two inputs that land in the same frame also bind as a chord.
- `Esc` cancels on either channel. While armed, `VCModKeyCapturing()` suppresses
  every mod hotkey, so the press used to bind never fires, reloads or toggles.
- `VCModKeyCaptureHoldName` names the input already held, so the armed cell can
  show `L1+` while it waits for a possible second input.

### 3. The KEYS page draws three cells per row

Value area (28 cols) splits into keyboard cell (10), pad cell (14) and clear cell
(4). Clicking the keyboard cell arms a keyboard capture, the pad cell a pad
capture, and the last cell clears both binds of that row. A click on the row
label still arms the keyboard. Display: `LCTRL+A`, `L1+CROSS`,
`[KEY]`/`[PAD]` while armed, `<input>+` while held, `[--]` when empty.

- **PANEL KEY** has no clear cell: it is the only way back into the panel. RESET
  KEYS still restores its `\` and clears everything else.
- Hovering a row's `[X]` highlights the whole row (label, both bind cells and
  the cell itself, in the warning colour) so the row about to lose its binds is
  unmistakable.
- `VCModCell` now truncates over-long text at the cell edge instead of bleeding
  into the next cell (a long chord is the first value that could overflow).
- `VCModKeyName(0)` now reads `NONE`; unbound slots used to print `KEY 0` in the
  footer hint. The footer now names packed keyboard binds.

### 4. Storage

- `[VC Mods]` gains `PadPanel`, `PadWalk`, … beside the existing `KeyPanel`,
  `KeyWalk`, … (26 each). Both are written on change and on RESET, never through
  PERMA.
- `VCModKeySanitize` validates each packed half: an invalid first key falls back
  to the slot default, an invalid or duplicate second input is dropped, and a
  second pad button without a first is dropped.

### 5. Consumers

- `CPlayerPed::ProcessControl`: DRIVER/AUTODRIVE/CREW/WALK/KICK/PASSENGER use
  `VCModKeyJustDown(padUsed, …)`; the FIRE slot uses the new
  `VCModKeyDown(padUsed, …)` because it holds the control down.
- `VCModKeyPressed` is the ungated just-down (no disabled-controls check), used
  by the panel toggle (so the panel still opens while the player is locked) and
  by the chase spot/capture hotkeys, matching their old behaviour.
- Manual reload uses `VCModKeyJustDown(CPad::GetPad(0), VCKEY_RELOAD)`, infinite
  ammo `VCModKeyJustDown(pad, VCKEY_AMMO)`, first person
  `VCModKeyPressed(CPad::GetPad(0), VCKEY_FIRSTPERSON)`.

### 6. The panel navigates with the controller

- Input is the same physical mask, so the mouse never moves the focus and the
  pad never picks a row by accident. The last device used owns the highlight:
  moving or clicking with the mouse takes it back; any pad nav press takes it.
- **D-pad up/down** moves between rows (the page window follows the focus);
  **D-pad left/right** moves between a row's targets — `pin → row` where the
  row has a pin, `KEY → PAD → [X]` on a KEYS row; **L1/R1** switch tabs;
  **Cross** activates the focused target (toggle, cycle, call, open a list, arm
  a key or pad capture, clear, pin); **Circle** closes an open list first, the
  panel second.
- **Lists** (characters, ride zones, crew car, spawn): up/down walks the
  entries, the window scrolls with the selection, Cross picks, Circle closes.
- The focused row draws the warning band; the focused target cell draws in the
  title colour so it is clear what Cross will hit. Hovering any row with the
  mouse draws the same band now, not just the `[X]` cell.
- Navigation stands down while a capture is armed (those presses are the
  binding; Esc cancels) and while the stock pause menu is up.

## Known, by design

- A pad bind fires alongside that button's stock action: binding Cross to a
  feature still means Cross does whatever it did in stock. Buttons are observed,
  not taken over.
- Duplicate binds across rows stay allowed (both actions fire), as before.
- Binding PANEL KEY to Start works but Start also opens the stock pause menu, so
  the panel comes back under the menu; that is the stock action doing its job.
- Keyboard chords need both keys held on the same frame; a modifier-style order
  (hold first, tap second) is the intended way.

## Verification

- `bash scripts/build.sh`: clean, `reVC.app` linked.
- All 53 harnesses pass, including the rewritten `test_vc_keys.py`: slot
  defaults, packed ini round-trip, per-channel capture, Esc-before-save, clear,
  panel key lockout, cell widths summing to the value area, bind names, chord
  fire truth table, sanitize of legacy/garbage values, plus the existing key-name
  and drive-camera checks. `test_vc_adrenaline.py` and `test_vc_character.py`
  compile the panel table and gained stubs for the new key API;
  `test_vc_ammo.py`, `test_vc_firstperson.py`, `test_vc_passenger.py` and
  `test_vc_reload.py` follow the helpers.
- `bash scripts/install.sh` into `~/Games/VC` with no session running
  (`vcmods build 626`).

## In play, to check

1. `\` → KEYS. Every row but PANEL KEY ends in `[X]`, and an unbound row reads
   `[--] [--] [X]`.
2. Click the left cell, press `B`; the cell shows `B`. Release, close the panel,
   press `B`: WALK MODE flips.
3. Click the left cell, hold `LCTRL`, tap `A`; the cell shows `LCTRL+A`. In play,
   hold `LCTRL` and tap `A` flips the feature; `A` alone does nothing.
4. With a controller connected: click the middle cell, press L1 (or hold L1 and
   tap Cross) — the cell shows `L1` / `L1+CROSS`. The same presses work in play.
   The click itself must not bind anything, and the button shown must be the
   one pressed even if the stock controller setup maps it to another action.
5. Hover `[X]`: the whole row highlights before you click. Click it: both cells
   read `[--]`, and the button stops firing the feature. The button's stock
   action is untouched.
6. PANEL KEY row has no `[X]`; rebind it to a pad button and open/close the panel
   from the pad.
7. `Esc` during any capture leaves the old bind.
8. Quit and relaunch: keyboard and pad binds are still there (`Key*`, `Pad*` in
   `reVC.ini`). RESET KEYS restores `\` and clears every other key and button.
9. Chord firing: holding the first input alone must not fire; the chord fires on
   the frame the second input lands and not again while both are held.
10. Controller navigation: D-pad walks rows, left/right walks a row's targets
    (the pin cell and `[X]` included), L1/R1 switch tabs, Cross acts, Circle
    backs out and then closes. Opening a list with Cross, walking it and picking
    must work without touching the mouse; moving the mouse takes the highlight
    back.
11. Hovering anywhere on a row lights the whole row, tabs and list entries
    included.

## Uncommitted

This session:

- `src/extras/vcmodkeys.{h,cpp}`, `src/extras/vcmodpanel.cpp`,
  `src/extras/vcmodpanelregistry.cpp` (RESET KEYS wording), `src/core/re3.cpp`,
  `src/core/Pad.cpp`, `src/core/ControllerConfig.{h,cpp}` (the physical pad
  mask), `src/skel/glfw/glfw.cpp`, `src/skel/sdl2/sdl2.cpp` (the mask hooks),
  `src/peds/PlayerPed.cpp`, `src/extras/vcmodreload.cpp`,
  `src/extras/vcmodammo.cpp`, `src/extras/vcmodfirstperson.cpp`,
  `src/extras/vcmodchase.cpp`
- `utils/test_vc_keys.py` (rewritten), `test_vc_adrenaline.py`,
  `test_vc_character.py`, `test_vc_ammo.py`, `test_vc_firstperson.py`,
  `test_vc_passenger.py`, `test_vc_reload.py`
- `README.md`, `CHANGELOG.md` (repo root)

Already in the tree from earlier sessions, not touched here: `vcmodcombat.*`,
`vcmodnpc.*`, `vcmodnpctarget.*`, `PedFight.cpp`, `Text.cpp`, and the
`test_vc_npcmode/combat/windup.py` edits (the NPC mission-target and ped-wound
work).

After committing: `scripts/sync.sh` regenerates `vc-mods.patch`.

## Do not touch

`~/Games/VC` and `~/Games/VC-ai` game data, especially `anim/cuts.img`,
`anim/cuts.dir`, `anim/ped.ifp` (immutable). The two-hand colt stance work is
settled. The chase prototype's tier digits and Enter/Backspace stay deliberately
not rebindable, and `Esc` stays the capture cancel on both channels.
