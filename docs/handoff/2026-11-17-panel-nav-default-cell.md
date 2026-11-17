# Panel pad nav: selector rests on the ON/OFF cell, not the pin column (2026-11-17)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
This session touched `reVC/src/extras/vcmodpanel.cpp` only, on top of the
preexisting uncommitted pile. Built green; **not installed** — a game session
was running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` matched pid 94211), so
install was skipped per the workspace rule. The Dock-pinned
`~/Games/VC/Vice City Mods.app` rebuilds and installs on its next launch, once
the game is quit.

## What changed

The pad-mode focus selector (the highlighted cell the D-pad walks) used to
land on cell 0 — the PERMA `[x]` pin column — on every fresh landing, so
after L1/R1 tab switches the owner had to press Right to reach the row's
function. Fresh landings now rest on the row's own value cell:

- new `VCModMainCell(const VCModRowDef *def)`: `1` when the row has a pin
  (`iniKey != nil`), `0` otherwise, `0` for `VCMOD_ROW_KEY` (no ON/OFF cell
  exists there; it rests on the keyboard-bind cell as before);
- used on every fresh-landing path: the `fresh` branch in `VCModNav` (covers
  tab switch, panel reopen, any reset to row -1), the find-box jump in
  `VCModFindApply`, and the header-cell `Down` return to the page;
- the draw loop's `mainTarget` now calls the same helper instead of
  duplicating the ternary;
- manual Left/Right is unchanged and is the only way onto the pin column:
  `Left` from the value cell, `Right` back. Up/Down keep the current cell.

Not done on purpose: `KEYS`-page rows keep cell 0 (keyboard bind) — the owner
dismissed the question and clarified only the pin-vs-ON/OFF columns. KEY
clear-cell (`[X]`) was never the focus cell (default was always 0).

## State and not-yet-played

Never run at the keyboard. In play, open the panel with the pad, switch tabs
with L1/R1: the focus band should sit on the `[ON]/[OFF]` value cell, `Cross`
toggles the switch, `Left` moves to the PERMA pin, `Right` returns.

## Notes for the next session

- No commit, tag or push was made. `src/extras/vcmodpanel.cpp` carries this
  session's diff inside the large preexisting uncommitted change; do not
  commit selectively.
- `docs/verification.md` has the panel play-check lines under Panel and input.

## Files not to touch

Game data under `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/` (read-only). Install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. No commit, tag or push
unless asked.

## Paste-ready prompt

> Continue `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
> Read `docs/handoff/2026-11-17-panel-nav-default-cell.md` first, then
> `AGENTS.md`. This session made the panel's pad-mode selector rest on the
> ON/OFF value cell instead of the PERMA `[x]` pin column on fresh landings
> (new `VCModMainCell()` in `src/extras/vcmodpanel.cpp`; fresh branch of
> `VCModNav`, `VCModFindApply`, header `Down`; draw uses the same helper).
> Built green, never installed (a game session was live, pid 94211) and
> never played — the Dock launcher installs it on next launch after the game
> is quit. Next: play-check the pad nav or commit when asked. Nothing is
> half-written.
