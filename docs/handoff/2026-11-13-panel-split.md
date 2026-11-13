# Panel split (2026-11-13) — built, installed, play checks unchanged

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 458` (was 455). All 45 harness suites
pass at 458. No commit, tag or push was made.

## What changed

`vcmodpanel.cpp` (1,731 lines) is now three sources plus one private header:

- `src/extras/vcmodpanelregistry.cpp` (571) — the row table: the page and row
  kinds' users, the cycle getters/setters and their labels, page names, the
  row lookup helpers (`VCModPageRowCount`, `VCModPageRow`, `VCModMaxPageRows`,
  `VCModRowCount`), pin persistence, the switched list and its count, the
  master toggle, and the `#ifdef DEBUGMENU` mirror that puts every flag in the
  debug menu.
- `src/extras/vcmodpanelcatalog.cpp` (446) — the lookups that turn stored
  values into names: the ride-zone label/list, the ped category names, the ped
  name and style tables, `VCModPedDisplayName`, the worn-body label, the crew
  and driver cells, and `VCModListCount` / `VCModListLabel` / `VCModListPick`.
- `src/extras/vcmodpanel.cpp` (771) — drawing and input: fonts, cell/print
  helpers, row and tab geometry, list geometry and scrolling, the mouse cursor,
  hit testing and click dispatch, `VCModPanelShowing` and `VCModPanelRender`.
- `src/extras/vcmodpanelinternal.h` (113) — the panel's private interface: the
  `eVCModPage` / `eVCModRowKind` / `eVCModList` enums, the `VCModCycleDef` and
  `VCModRowDef` structs, the two drawing globals the catalog writes back, and
  one prototype block per source file.

`vcmodpanel.h` is unchanged by this slice (its earlier extraction diff is still
uncommitted). Every engine hook and call site is untouched: `main.cpp` calls
`VCModPanelRender`, `re3.cpp` calls `VCModPersistPinned`, `PlayerPed.cpp` calls
`VCModPanelShowing`.

### How the move was kept neutral

- Function bodies are the originals, byte-for-byte. The only edit inside a
  chunk is dropping `static` from the declaration of a symbol another file
  calls: 17 functions (three of them the non-`LOAD_INI_SETTINGS` fallbacks),
  four tables and two drawing globals.
- Two count helpers replace `ARRAY_SIZE` at the two places that hold only the
  extern array: `VCModRowCount()` (the help-line bound) and
  `VCModSwitchedCount()` (the ALL ON comparison). `sizeof` cannot be taken on
  an array of unknown bound, and the values are identical.
- State objects keep their original definition order. The two globals the
  catalog writes, `nVCModOpenList` and `nVCModListScroll`, lost `static` and
  are declared in the internal header; the rest of the drawing state stays
  file-local.
- The `DEBUGMENU` gate is preserved per file: the row table and pin
  persistence stay outside it, the debug mirror and master switch stay inside;
  the catalog is outside until the list code; the drawing is entirely inside,
  as before.
- All three sources include the original header list, so no dependency moved
  either. The internal header is included by the panel's own sources only.

### Naming rule

`docs/architecture.md` gains rule 17, "Names follow the module":

- files `vcmod<feature>.cpp/.h`, sub-concerns `vcmod<module><concern>.cpp`
  (one word), private interface `vcmod<module>internal.h`;
- harness `utils/test_vc_<feature>.py`, one per module, reading every source of
  a split module;
- functions `VCMod<Feature><Thing>`; state `b`/`n`/`f`/`a`/`p` prefix on the
  module name, `Handle` suffix for pool handles;
- enums `eVCMod<Thing>` with `VCMOD_<THING>_<VALUE>` members, tuning
  `VCMOD_<FEATURE>_<DETAIL>`, keys `VCKEY_<ACTION>`, ini keys CamelCase, panel
  rows upper case and short;
- logs `VCMOD <what happened>`, module tag when ambiguous (`VCMOD CHASE …`),
  probes behind `VCMOD_DIAG`.

Rule 15, the landmine entry, the target-layout row and the debt sizes now name
the three panel sources and the internal header.

### Harness

- 25 harnesses that read `vcmodpanel.cpp` now read the four panel files as one
  text: `vcmodpanel.cpp`, `vcmodpanelregistry.cpp`, `vcmodpanelcatalog.cpp`,
  `vcmodpanelinternal.h`, in that order. The panel-info test's table anchor
  follows the definition without `static`.
- Markers that name a symbol which lost `static` were updated in 18 of those
  files (row table, page names, page-row helpers, list count/label/pick, crew
  and driver cells, count-on, toggle-all).
- `test_vc_character.py` accepts the non-`static` category-name table and
  drops its local `static` copies of the two drawing globals (they now arrive
  from the panel text). `test_vc_adrenaline.py` reads all four sources in its
  two panel checks and extracts `VCModSwitchedCount` with the other helpers.

### Verification

- Mechanical, not by eye: every non-blank line of the original file is
  present exactly once across the four files, except the `static` qualifier
  dropped on 23 declarations, the dropped
  `static void VCModToggleAll(void);` forward declaration (the internal header
  declares it), and the two `ARRAY_SIZE` call sites replaced by the count
  helpers.
- All 45 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 458); installed with
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty immediately before the
  install. The installed binary reports `vcmods build 458` and is ad-hoc
  signed.
- In game: not checked. The panel is worth one pass when the player is at the
  machine — every tab, the hovered help line, one pin, each list, one key
  rebind and the master switch — because this slice rebuilt the UI's file
  boundaries even though the code is the same.

## Not changed

- The update order and every line in the post-extraction map: adrenaline 1870 →
  reconcile 1871 → apply-default 1872 → ride 1873 → sit 1927 → street 1928 →
  npc 1929 → keys/latch 1941–1950 → never-wanted 1953; the animation-path hooks
  at `PlayerPed.cpp` 1316 and 645; the no-strafe gates at 1313/1327,
  `Cam.cpp` 1537, `Ped.cpp` 2115.
- The feature-off path: this slice moves code, it does not gate anything anew.
- Play checks: the open list is the same as the last handoff.

## Uncommitted

Eleven behaviour-neutral refactor slices (adrenaline, sit, street, NPC, gang,
ride, character, player, combat, chase, panel) plus the cop fixes and the
naming rule. `vc-mods.patch` predates them.

- New this slice: `src/extras/vcmodpanelregistry.cpp`,
  `src/extras/vcmodpanelcatalog.cpp`, `src/extras/vcmodpanelinternal.h`.
- Rewritten this slice: `src/extras/vcmodpanel.cpp` (drawing remainder).
- Modified this slice: 25 `utils/test_vc_*.py` harnesses and
  `docs/architecture.md` (rule 17, rule 15 wording, landmine, target layout,
  debt sizes).

## Next

1. Play checks when the player can test: the panel pass first (it is the
   newest boundary), then the still open combat, character, ride, gang,
   NPC/cop and player passes, plus one chase run. One feature per session,
   flag on and off.
2. The `ProcessPlayerWeapon` aim-control extraction (doom-aim accuracy, scope
   skip, AIM RAISE trigger gate) so the engine file keeps hook calls only.
3. The single never-wanted helper in `Wanted.cpp` for the five
   `bVCModNeverWanted` gates.
4. Commit the eleven refactors (and the cop fixes) only when asked, then
   regenerate `vc-mods.patch`.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 458 is installed.
> Read `docs/handoff/2026-11-13-panel-split.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Eleven behaviour-neutral slices
> (adrenaline, sit, street, NPC, gang, ride, character, player, combat, chase,
> panel) are uncommitted; the panel, combat, character, ride, gang, NPC/cop and
> player play checks are still open.
> The panel is now four files: `vcmodpanel.cpp` (drawing, 771),
> `vcmodpanelregistry.cpp` (rows and pins, 571), `vcmodpanelcatalog.cpp`
> (lookups, 446) and `vcmodpanelinternal.h` (shared types and prototypes, 113).
> `vcmodpanel.h` and every engine hook are unchanged; all 45 harnesses pass.
>
> Work directly in this session: one module per session, done in place. Next is
> the `ProcessPlayerWeapon` aim-control extraction, then the single
> never-wanted helper in `Wanted.cpp`.
>
> Keep every move behaviour-neutral and verbatim: same statements, order,
> comments and log strings; feature-off byte-identical to stock; no existing hook
> signature changed; engine files keep hook calls only. Preserve the update order
> in `CPlayerPed::ProcessControl` — adrenaline 1870 → reconcile 1871 →
> apply-default 1872 → ride 1873 → sit 1927 → street 1928 → npc 1929 → keys/latch
> 1941–1950 → never-wanted 1953 — the animation-path hooks
> (`VCModPlayerAnimGroup` 1316, `VCModCharacterMoveTempo` 645, last of the five
> sprint-speed writes), and the no-strafe gates at `PlayerPed.cpp` 1313/1327,
> `Cam.cpp` 1537, `Ped.cpp` 2115. Name every new file and symbol by rule 17.
>
> Per feature: run all `utils/test_vc_*.py` suites, `scripts/build.sh`, then
> `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty,
> and confirm the installed binary reports the new build number BEFORE handing
> off for the player's live test — never hand off an uncompiled tree. In-game
> verify on and off is the player's turn. Clear `~/Games/VC/reVC.log` before each
> test, and read only fresh, filtered, capped slices. Update the debt sizes in
> `docs/architecture.md`, write the handoff and a paste-ready prompt at the end.
> Never commit or push unless asked; game data and uchg anim files are read-only.
