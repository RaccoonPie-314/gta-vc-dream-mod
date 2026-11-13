# Diagnostics gated (2026-11-12) — build 422 installed

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`
(2026-11-09; the tree carries all later work uncommitted). `vcmods build 422`
was built and installed into `~/Games/VC/reVC.app` with no session running. No
commit, tag or push was made.

## What changed

- New `src/extras/vcmoddiag.h` / `vcmoddiag.cpp`: `bVCModDiagnostics`
  (default false) and the `VCMOD_DIAG(...)` macro.
- Switch surface: the panel's DEBUG page has a DIAGNOSTICS row, the debug menu
  has `VC Mods|Debug`, and the ini key `Diagnostics` under `[VC Mods]` is read
  at startup. The row is excluded from ALL ON.
- Gated probes, message text unchanged so old log greps still work:
  `wander`, `civ layer`, `react move`, `talk`, `voice`, `id line`, `gang obj`,
  `gang react`, `threat`, `corpse`, `gang pose`, `gang gaze`, `fist`,
  `npc body`, `npc mode`, `move`.
- Left unconditional: `street idle`, `sit`, `spin kick`, `passengers`, error
  lines, panel/key action lines, and the chase/crew state logs.
- `utils/test_vc_diag.py` locks the split in. Six harness stub blocks gained
  the symbol and macro; the panel row count assertion went from 55 to 56.

## Project rule added

`docs/architecture.md` now holds the code-shape rule: layer map, feature
isolation, config registry, take/restore, landmines and the new-feature
checklist. `AGENTS.md` points to it under "Feature code has one home".

## Panel help text (same session)

Every row now carries a one-line description and an optional warning. The
footer shows the description for the row under the pointer; a row with a
warning gets a `!` badge and a `! ` line. The rule is
`docs/architecture.md` section 16, and `utils/test_vc_panel_info.py` enforces a
description on every row plus the 50-column limit.

## Verification

- All 43 harness suites pass.
- Build 420 built and installed; `pgrep` was empty before the install.
- Not played. The next pass should confirm `reVC.log` stays quiet during street
  idle. The old 143 MB log was left untouched.

## Still true from the layering audit

- The tree is uncommitted and `vc-mods.patch` is still 2026-11-09, missing the
  crew, first-person and NPC work.
- Next: commit and regenerate the patch, refresh README/CHANGELOG, then extract
  the NPC domain (`vcmodnpc`, `vcmodstreet`, `vcmodsit`, `vcmodgang`) from
  `PlayerPed.cpp`, `PedAI.cpp`, `Ped.cpp` and `PedFight.cpp`; unify the ini
  registry; dedupe the HUD notice and seat scan.
- Full findings: `docs/handoff/2026-11-12-layering-audit.md`.

## Turning probes on

Panel DEBUG page → DIAGNOSTICS, or `Diagnostics=1` under `[VC Mods]` in
`reVC.ini`. They print the same `VCMOD ...` lines as before.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg and cannot be rebuilt. Check
`pgrep -f "reVC.app/Contents/MacOS/reVC"` immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 422.
> Read `docs/handoff/2026-11-12-diagnostics-gated.md` first, then
> `2026-11-12-layering-audit.md` for the full audit, and follow
> `docs/architecture.md` for where new code belongs. Panel rows now require a
> plain-language `info` and an optional `warn`; the hovered row shows them in
> the footer. The temporary `VCMOD` probes are now behind the DIAGNOSTICS
> switch (panel DEBUG row and `Diagnostics` ini key), and all 43 harnesses
> pass. Next: commit the uncommitted crew/first-person/NPC/street work, run
> `scripts/sync.sh`, refresh README/CHANGELOG, then extract the NPC domain
> (`vcmodnpc`, `vcmodstreet`, `vcmodsit`, `vcmodgang`) out of `PlayerPed.cpp`,
> `PedAI.cpp`, `Ped.cpp` and `PedFight.cpp`, leaving hook calls only. Then
> unify the ini registry and fix the inert `CarFirstPerson` pin. Never commit
> or push unless asked; game data and uchg anim files are read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
