# Layering audit (2026-11-12) — current tree, no code changed

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`
(2026-11-09). `vcmods build 419` is installed in `~/Games/VC/reVC.app`; the
installed binary is newer than every source file, so it matches this tree. No
commit, tag or push was made.

The tree is three days ahead of HEAD: 32 modified files, four untracked source
files (`src/extras/vcmodcrew.*`, `src/extras/vcmodfirstperson.*`) and 19
untracked harnesses. `vc-mods.patch` is from 2026-11-09 11:20 (96 files) and
predates HEAD, the crew, first-person and NPC work.

## Verdict

The feature set is covered by harnesses and the playable build is current, but
the layering regressed: the NPC, cop, wanted and sit work landed in engine
files, not in `src/extras/vcmod*`.

## Numbers

- 21 `vcmod*` modules, 8,082 lines. Chase 3,610; panel 1,883; crew 1,011.
- `src/peds/PlayerPed.cpp` is 5,181 lines; 2,184 (42%) are in `VCMod*`
  functions.
- Engine-side mod lines against upstream: Ped.cpp +810, PedFight +416,
  PedAI +101, Wanted +21, AudioLogic +19, PedChat +19. 25 engine files
  reference the mod.
- 14 engine files include `vcmodpanel.h`; the header is 185 lines and owns
  flags and predicates for combat, character, ride, seat and four NPC
  profiles.
- 55 panel rows across 6 pages. 36 row ini keys, 52 reads in `re3.cpp`.
  `CarFirstPerson` is still the one row that pinning writes and nothing reads.
- 97 `fprintf(stderr, "VCMOD...")` calls. Explicit temporary probes remain at
  `PlayerPed.cpp:1869`, `PlayerPed.cpp:1902` and `PedFight.cpp:2546`.
- `~/Games/VC/reVC.log` is 143 MB; the last 20,000 lines contain 19,859 VCMOD
  diagnostics, 18,535 of them the wander probe.
- 41 harnesses; 15 import `test_vc_passenger` as their stub library; there is
  no runner.
- `Play.bat` is still absent; `install.sh` and `package.sh` are macOS-only.

## What improved

- Crew and first-person are proper modules with their own headers and flags.
- The civilian AI state and routines (`SCivilianAIState`, `CivilianAI`,
  `ProcessCivilianState`, `CopPatrolScan`) moved into `CPed`, so the NPC
  profiles run stock code instead of look-alikes.
- New harnesses exist and pass (9 files, 53 tests, run during this audit).
- The panel row table is still the single UI and config index; the new crew and
  first-person rows joined it.

## Next steps

1. Strip or gate the temporary diagnostics. The wander/flicker probe is the
   flood; keep the feature logs listed in
   `2026-11-12-npc-mode-roundup.md`.
2. Commit the NPC topic plus the earlier uncommitted work, run
   `scripts/sync.sh`, and refresh README and CHANGELOG (last dated changelog
   entry is 2026-11-09; README has no BECOME NPC, NPC TYPE, cop patrol or
   NEVER WANTED section).
3. Extract the NPC domain from engine files: `vcmodnpc` (profiles, stat
   borrow, ID check), `vcmodstreet` (idle, chat, wander), `vcmodsit` (seat scan
   and sit) and a `vcmodgang` hook module for the reaction overrides. Target:
   `PlayerPed.cpp` returns to engine-only.
4. One config registry drives ini load, save, panel and debug menu; fix the
   inert `CarFirstPerson` pin and add a consistency harness.
5. Dedupe the HUD notice (three copies) and the seat scan; move the shared
   test stubs into `utils/vcmod_test_support.py` and add a runner.
6. Split `vcmodchase.cpp` (3,610) and `vcmodpanel.cpp` (1,883) when next
   touched; add the Windows `Play.bat` package path.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg and cannot be rebuilt. Check
`pgrep -f "reVC.app/Contents/MacOS/reVC"` immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 419.
> Read `docs/handoff/2026-11-12-layering-audit.md` first. The game is current
> and the new harnesses pass, but the tree is uncommitted and `vc-mods.patch`
> is stale (2026-11-09). Start by stripping the temporary `VCMOD` probes, then
> commit and regenerate the patch. After that, contain the NPC domain:
> extract `vcmodnpc`, `vcmodstreet`, `vcmodsit` and `vcmodgang` from
> `PlayerPed.cpp`, `PedAI.cpp`, `Ped.cpp` and `PedFight.cpp`, leaving hook
> calls only. Then unify the ini registry and fix the inert `CarFirstPerson`
> pin. Never commit or push unless asked; game data and uchg anim files are
> read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any
> install.
