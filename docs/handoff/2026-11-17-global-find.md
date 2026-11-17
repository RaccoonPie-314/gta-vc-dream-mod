# Global find box

The panel's type-to-find box existed only on a tab longer than the window
(KEYS, 28 rows; every other tab has 20 or fewer). It now draws, clicks and is
pad-reachable on every tab, and the search spans all of them: a query that
matches a row on another tab switches the panel to that tab and highlights
the row.

## What changed

- `reVC/src/extras/vcmodpanel.cpp`
  - `VCModPageHasFind()` is gone, with every gate that used it (draw, click,
    hover, pad header cells, typing start).
  - `VCModFindApply()` searches the open tab first, then the other tabs in
    strip order. A hit elsewhere switches `nVCModPage`, scrolls the window to
    the row and sets the pad focus to it, so the find band shows in both
    mouse and pad mode. No match keeps the query; the footer says so.
  - `VCModFindBegin()` closes any open list, because typing is ignored while
    a list is open and a click on FIND with a shelf open otherwise looked
    dead.
  - Pad: the header row always has two cells (sweep, find); Left/Right walk
    them.
- `reVC/src/extras/vcmodpanelinternal.h`,
  `reVC/src/extras/vcmodpanelregistry.cpp`: comments only — the search is no
  longer described as the KEYS page's own.
- `reVC/utils/test_vc_panelhouse.py`: `test_find_box_is_on_every_tab`
  replaces the old KEYS-only assertion and checks the cross-tab search
  (open tab first, page switch, no row-count check in the typing poll).

Behaviour kept from the previous box: a printable letter arms the search,
Backspace deletes, Esc clears and leaves typing, Enter keeps the query and
the highlight, a tab click or L1/R1 clears the query. The box still jumps and
bands; it never filters the row list. The KEYS page keeps its wheel scroll.

## Verification

- Panel harness: 8 tests OK.
- `scripts/build.sh`: clean Release build into `reVC/build/src/reVC.app`.
- Not installed by hand; the Dock launcher builds and installs from this
  checkout, so the next launch carries the change. In-game state: unplayed.

## Suggested play check

- On COMBAT, click FIND and type `wheel`: the panel switches to DRIVING and
  bands WHEEL FALLS OFF.
- Type `cop` from any tab: first match in strip order; Backspace widens the
  query; Esc clears and the tab stays where the jump left it.
- Pad: Up from the first row, Right onto FIND, Cross, type — the found row is
  banded and the pad focus sits on it.

## Files not to touch

Game data: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/` (read-only; `anim/cuts.img`,
`anim/cuts.dir`, `anim/ped.ifp` carry `uchg`). Install only while
`pgrep -f "reVC.app/Contents/MacOS/reVC"` is empty. No commit, tag or push
unless asked.
