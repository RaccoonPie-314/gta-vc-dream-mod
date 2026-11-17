# Panel housekeeping: per-tab ALL ON, RESET STATE, KEYS-page search (2026-11-17)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`,
65 files uncommitted (all predating this session except the new
`vcmodreset.{cpp,h}` and `test_vc_panelhouse.py`). Installed build 657. This
session built, harness-tested and installed the one kept idea the owner picked
from the 2026-11-17 scope-prune survey.

## What shipped

**Per-tab ALL ON.** A `[TAB ON]` cell at the right end of the header row, on
every page. It is the master's set restricted to the `VCMOD_ROW_FLAG` rows the
page shows:

- read states mirror the title-bar master: `[TAB ON]`, `[TAB OFF]`, `[TAB MIX]`;
- `KEYS` and `DEBUG` have no sweepable switch, so the cell renders `[TAB --]`
  and a press reports `no switches on this tab` instead of doing nothing;
- challenge rows (NPC DOOM AIM), cycle rows (ADRENALINE, VANILLA FIXES),
  commands, diagnostics and rows without a switch never move, per tab exactly
  as for the master; the four VANILLA FIXES flags have no rows and are not
  swept (the VANILLA FIXES row is a cycle and does not move either);
- a switch BECOME NPC holds keeps the player's own value, both for the read
  and the flip, same as the master;
- pad-reachable: one step above the first row lands on the header cells;
  Left/Right walks them (sweep then find box), Cross acts, Down returns to the
  page; clickable with the mouse like everything else on the header row;
- the footer line explains the focused header cell.

**`RESET STATE`**, DEBUG page after SPAWN VEHICLE. Puts down everything the mod
is running in the world, each through that feature's own entry point:

| order | thing | out when | drop |
|-------|-------|----------|------|
| 1 | crew | `VCModCrewPhase()` != `NONE`/`DISMISS_WAIT` | `VCModCrewDismissNow()` |
| 2 | chauffeur | `VCModDriverSummoned()` | `VCModDismissDriverNow()` |
| 3 | gang group | `VCModGangGroupAlive() > 0` | `VCModGangGroupRelease(player)` |
| 4 | chase | `VCModChaseRunning()` | `VCModChaseStop("chase: stopped by reset")` |
| 5 | AUTO DRIVE | `VCModAutoDriveModeGet() != OFF` | `VCModAutoDriveSetMode(VCMOD_AUTODRIVE_OFF)` |
| 6 | cockpit view | `VCModCarFirstPersonOn()` | `VCModCarFirstPersonSet(false)` |

The row only queues (`VCModResetRequest`); `VCModResetTick` runs the table from
`CGame::Process`, the same deferred rule SPAWN VEHICLE follows — the panel never
does world work inside the render pass. Switches, pins and BECOME NPC are
untouched on purpose: ending the mode would re-summon the crew and the driver
a second later through `VCModNpcSuspendRelease`. A press with nothing up says
`state reset: nothing was running`; otherwise `state reset: everything put down`
and a log line.

**KEYS page search.** A `FIND` box at the right end of the header row, drawn
only on the KEYS page (the one page longer than the window, 27 rows against
`VCMOD_PAGE_ROWS` 20). Type letters and the page scrolls to and lights the
first row whose name holds the query, case folded; the found row draws banded
and the footer names it. Backspace deletes, Esc clears and leaves, Enter
leaves the query standing. No match: the footer reports `no row has that
name`, once per query state (no HUD notice per keystroke).

While the box holds the keyboard, the panel sets a player-control bit of its
own (bit 9, `VCMOD_CONTROL_TYPING` = 512, above the stock bits) and
`VCModKeyJustDown`/`VCModKeyDown`/`VCModKeyPressed` stand down
(`VCModKeyTypingSet`), so typed letters never walk, fire, drive or leak into a
hotkey. `VCModKeyPanelPressed` is the panel key's own just-down past those
gates: the panel still opens/closes from the find box, while an armed key
capture still owns the next press. The bit is re-asserted by the panel every
rendered frame and released when typing ends; it is its own bit, so no engine
assignment can strand controls. Query is cleared on tab switch and on close.

Pad navigation also got a header step (Up above the first row) and a fresh Down
now lands on the first visible row instead of skipping it.

## Files touched

- `reVC/src/extras/vcmodpanel.cpp` — header row cells (draw + click), find-box
  state and poll, tab sweep activation, pad nav header step, footer overrides.
- `reVC/src/extras/vcmodpanelinternal.h` — `VCMOD_ROW_STATERESET`, sweep and
  `VCModRowNameMatches` declarations.
- `reVC/src/extras/vcmodpanelregistry.cpp` — the row, `VCModPageSweepsRow`
  (`#ifdef DEBUGMENU`), `VCModPageSweepCount/On/Sweep`, `VCModRowNameMatches`.
- `reVC/src/extras/vcmodreset.{cpp,h}` — new module, the table and the queue.
- `reVC/src/extras/vcmodchase.{cpp,h}` — `VCModChaseRunning` / `VCModChaseStop`
  (abort now delegates to `VCModChaseStop`).
- `reVC/src/extras/vcmodkeys.{cpp,h}` — typing gate (`VCModKeyTyping(Set)`),
  `VCModKeyPanelPressed`.
- `reVC/src/core/Game.cpp` — `VCModResetTick();` in the update-pass hook block.
- Harnesses: new `test_vc_panelhouse.py`; `test_vc_keys.py`
  (`VCModKeyPanelPressed` assertion), `test_vc_adrenaline.py` and
  `test_vc_character.py` (header-cell extracts and stubs), `test_vc_passenger.py`
  (row count 83). The whole suite is green.
- `docs/verification.md` — the play-check line under Panel and input.
- `CHANGELOG.md` — the 2026-11-17 uncommitted entry; panel housekeeping removed
  from Ideas not started.

## State and not-yet-played

Built, harness-green, installed (657). **Never confirmed at the keyboard.**
Watch in play, per `docs/verification.md`:

1. `[TAB ON]` on an empty tab (`KEYS`, `DEBUG`) refuses with a notice; elsewhere
   it flips the tab's rows and the cell flips `ON/OFF/MIX`; a held BECOME NPC
   switch reads on and refuses; pins keep their values.
2. `RESET STATE` with the crew out, a chase up and AUTO DRIVE on: one press puts
   all of it down, each through its own dismissal; empty press says so; switches
   and BECOME NPC do not move.
3. `FIND` on KEYS: type `loss`, the page jumps to WHEEL LOSS KEY; typed letters
   do not fire, walk, drive or bind; Backspace/Esc/Enter; the query clears on a
   tab switch and on close; the panel key still closes the panel mid-type.
4. Pad: one step above the first row lands on the header cells; Left/Right walks
   them; Cross activates; Down returns to the page.

## Notes for the next session

- The build number file is `reVC/build/vcmods-build-number`; it increments on
  every configure, so it drifts ahead of the app you installed. The installed
  number is visible bottom-right in game (`vcmods build 657`).
- `VCMOD_CONTROL_TYPING` is bit 9 of `DisablePlayerControls` (512). The panel
  re-asserts it every rendered frame while typing, so an engine assignment
  cannot leave it behind, but if a future control-bit ever claims bit 9, the
  find box breaks visibly — that is the symptom to check first.
- The find box deliberately does not filter the row list; a query jumps and
  lights. No match is announced in the footer, one per query state.
- `VCModPageHasFind` is `VCModPageRowCount(page) > VCMOD_PAGE_ROWS`, so adding
  an 21st row to any other page gives it a find box automatically. If that ever
  happens by accident, the KEYS page assertion in `test_vc_panelhouse.py` will
  still pass — check the page first.

## Files not to touch

Game data: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/` (read-only; `anim/cuts.img`, `anim/cuts.dir`,
`anim/ped.ifp` are `uchg`). Install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty — it was empty for every install
today. No commit, tag or push unless asked.

## Paste-ready prompt

> Continue `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`, build
> 657 installed; all 65 uncommitted files predate this except `vcmodreset.{cpp,h}`
> and `utils/test_vc_panelhouse.py` (this session's work). Read
> `docs/handoff/2026-11-17-panel-housekeeping.md` first, then `AGENTS.md` and
> `docs/architecture.md`. Panel housekeeping shipped: per-tab `[TAB ON]` in the
> header row (master's set restricted to the page's flag rows, `[TAB --]` on
> KEYS/DEBUG), `RESET STATE` on the DEBUG page (crew, chauffeur, gang, chase,
> AUTO DRIVE, cockpit view; queued, switches and BECOME NPC untouched), and a
> type-to-find `FIND` box on the KEYS page (own `PLAYERCONTROL` bit 512, hotkeys
> stand down while typing, panel key still answers). Harness suite green. This is
> built and installed, never played; the play checks are in `docs/verification.md`
> under Panel and input. Next: play the three play-check items or commit when
> asked. Nothing is half-written.
