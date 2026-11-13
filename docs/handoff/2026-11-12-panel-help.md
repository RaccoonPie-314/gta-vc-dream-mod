# Panel row help (2026-11-12) — verified, build 426 installed

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`
(2026-11-12). The NPC/crew/panel/diagnostics work is committed; no tag was
made and reVC was not pushed (it is upstream). `vcmods build 426` is installed
in `~/Games/VC/reVC.app`. All 43 harness suites pass, and the panel help was
play-confirmed.

## What shipped

- Every panel row in `src/extras/vcmodpanel.cpp` has a one-line `info` and an
  optional `warn`.
- Footer line 1 is `INFO  <info>` for the hovered row and stays on the last row
  the pointer used, until the page changes. Footer line 2 is `! <warn>` when
  the row has a warning, otherwise the live key hints.
- Warning rows carry a `!` badge inside the value cell.
- `utils/test_vc_panel_info.py` enforces a description on every row, the
  warning shape and the 50-column limit.
- `docs/architecture.md` section 16 makes this the default for new rows.

## Verification

- Play-confirmed: the `INFO` line and warning `!` show on the `\` VC MODS
  panel (build 426).
- All 43 harness suites pass.
- Installed with no game session running.

## Still pending

1. Regenerate `vc-mods.patch` (done: 137 files), refresh README/CHANGELOG, and
   publish the handout repo only when the owner explicitly asks. reVC has no
   push target; its only remote is upstream and is not pushed.
2. Then one refactor module per session, smallest first: `vcmodadrenaline` or
   `vcmodsit`, then `vcmodstreet`, then `vcmodnpc`/`vcmodgang`. After each:
   all 43 harnesses, a build, and a short play check; the feature-off path must
   stay stock.
3. Later: one ini registry (`CarFirstPerson` is still inert), dedupe the HUD
   notice and seat scan, split `vcmodchase`/`vcmodpanel`, move the shared test
   stubs into one module, and add the Windows `Play.bat` package path.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; installed build 426.
> Read `docs/handoff/2026-11-12-panel-help.md` first, then
> `2026-11-12-layering-audit.md` for the full audit and `docs/architecture.md`
> for where new code belongs. The panel row help is verified and the NPC/crew
> work is committed and `vc-mods.patch` is regenerated. The first step is
> refreshing README/CHANGELOG, then publishing the handout repo only if the
> owner explicitly asks. After that, extract one feature module per session,
> starting with
> `vcmodadrenaline` or `vcmodsit`, then `vcmodstreet`, then
> `vcmodnpc`/`vcmodgang`; run all 43 harnesses and a build after each, keep the
> feature-off path identical to stock, and write a handoff per session. Never
> commit or push unless asked; game data and uchg anim files are read-only;
> check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
