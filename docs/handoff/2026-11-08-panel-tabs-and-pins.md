# Backslash panel — tabs and per-row pins

Date: 2026-11-08
Repo/branch/HEAD: `reVC/`, `vcmods`, `d01bb3c` plus the uncommitted mod tree (63 files).
Installed: `~/Games/VC/reVC.app`, `vcmods build 104`; installed with no session running.

Not verified in play yet. The build compiles clean and is installed; the checks below are the
owner's.

## What ships

1. **Five tabs** — `src/extras/vcmodpanel.cpp`. The flat 36-row column becomes one page per
   category, with the tab strip under the title:

   | Tab | Rows |
   |---|---|
   | COMBAT | freeaim+lockon, aim all weapons, NPC doom aim, no scope camera, colt two-hand, lockon vehicles, never wanted, lockon latch, adrenaline, adrenaline mode, reload on R |
   | PLAYER | walk mode, no strafe, NPC animation, anim set, ped category, character |
   | DRIVING | passenger mode, call driver, ride to, ride style, skip ride, keep wheel angle, steering wheel, wheel falls off, blades after bail, firetruck cannon |
   | WORLD | street idle, traffic AI, vanilla fixes, hud cleanup, exit hold off, longer blood/sand, cop crouch+cover, shoot projectiles, explosion cover, FBI light bars |
   | DEBUG | path node, path lane (read-only) |

   Click a tab to switch; the last tab is kept for the session and the panel opens on it.
   Switching closes any open list. The panel reserves the tallest page so the warnings and the
   hint line do not move between tabs. No new key bindings: digits and TAB would reach the game
   behind a panel that does not pause.

2. **Master switch** moved from the first row into the right end of the title bar
   (`[ALL ON]` / `[MIXED]` / `[ALL OFF]`). It still flips the same 25 switches and still leaves
   WALK MODE and NO STRAFE alone.

3. **Pin cell** — the first three columns of every row read `[ ]` or `[*]`. Left-click the cell
   to pin or unpin; left-click the rest of the row to flip or open its list. Rows with nothing
   to remember (call driver, skip ride, the two path read-outs, ped category) get a blank cell.

4. **What pinned means** — a row is pinned exactly when its key exists in `[VC Mods]` of
   `reVC.ini`. Pinning writes the current value at once; every later change to that row
   rewrites it. Unpinning deletes the key; the session keeps the value, the next launch falls
   back to the code default. `src/core/re3.cpp` gained four thin wrappers (`IniHasKey`,
   `IniStoreKey`, `IniRemoveKey`, `IniFlush`) and a `VCModPersistPinned()` call in
   `SaveINISettings`, so a Ctrl-M change to a pinned row is written on quit instead of being
   overwritten by the value the file held at startup.

   Pinnable value rows: ANIM SET (`AnimChoice`), CHARACTER (`PedModel`), RIDE TO (`RideZone`),
   RIDE STYLE (`RideStyle`). CHARACTER persists the worn body, not the pending model — the
   pending index is cleared to `-1` once the swap runs.

5. **Startup read fixed** — `TrafficAI` was never read from the ini, so that row could not have
   survived a restart even if pinned. Added next to the other `[VC Mods]` reads. A key check
   confirms all 34 pinnable keys are read at startup; the only extra read is `CopHoldFrame`,
   which belongs to the debug menu.

6. **Debug menu mirrors the tabs** — the one `SETTWEAKPATH("VC Mods")` became
   `VC Mods|Combat`, `|Player`, `|Driving`, `|World`, each in its own namespace (the macro names
   a static, so it cannot be called twice in one scope). The all on/off command stays on the
   root `VC Mods` page. No DEBUG submenu: the path read-outs are panel-only.

## Files

- `reVC/src/extras/vcmodpanel.cpp` — row table with page + ini key, tab strip, pin cell,
  persistence, split tweak paths, master in the title.
- `reVC/src/extras/vcmodpanel.h` — `VCModPersistPinned()` declaration.
- `reVC/src/core/re3.cpp` — wrappers, `TrafficAI` read, quit-time persist.
- `reVC/src/core/main.h` — wrapper declarations.

No assets, no new ini section, no platform calls in mod code.

## Checks to run in play

1. `\` opens on COMBAT; every tab shows its rows; a tab switch closes an open list.
2. Each list opens beside its row, scrolls with the wheel, and picks.
3. `[ALL ON/OFF]` in the title flips across pages; walk mode and no strafe stay put.
4. Pin a switch, flip it, quit, relaunch — it comes back in the flipped state.
5. Unpin it, quit, relaunch — it falls back to the code default.
6. Pin CHARACTER, quit, relaunch — the same body is worn.
7. Ctrl-M shows `VC Mods` with Combat / Player / Driving / World submenus.

## Next steps

- Play the seven checks above; fix anything that reads wrong (cell widths, tab hit areas).
- Add a CHANGELOG entry once seen.
- Nothing is committed; the reVC tree carries the whole mod batch uncommitted.

## Do not touch

`~/Games/VC` and `~/Games/VC-ai` game data, especially `anim/cuts.img`, `anim/cuts.dir`,
`anim/ped.ifp` (immutable, cannot be rebuilt).
