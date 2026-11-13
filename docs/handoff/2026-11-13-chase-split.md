# Chase split (2026-11-13) — built, installed, play checks unchanged

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 455` (was 450). All 45 harness suites
pass at 455. No commit, tag or push was made.

## What changed

`vcmodchase.cpp` (3,611 lines) is now three sources plus one private header,
split by sub-concern:

- `src/extras/vcmodchase.cpp` (1,552) — the state machine: the tier and crime
  tables and every pure predicate, the take/restore of scenario state
  (uniform, density, cop mute), the route and driving primitives, the leader
  and his tableau/swap/alarm/boat beats, and `VCModChaseTickLeader` /
  `SpawnLeader` / `End` / `Update` / `Reset`.
- `src/extras/vcmodchasesquad.cpp` (948) — the ground force: squad and crew
  handles and accessors, the transport, station boarding, the force pools and
  their replacement cars, the accomplice, the dismount and the endgame stand.
- `src/extras/vcmodchaseair.cpp` (1,019) — the air insertion: heli spawn and
  flight, the ropes, the approach and rally, the gun run, the wreck and the
  drop. The three pure air predicates (`RopeProgress`, `AirWrecked`,
  `AirSquad`) live here.
- `src/extras/vcmodchaseinternal.h` (432) — the module's private interface: the
  tuning defines and the three file-local enums, every state object as an
  `extern` declaration carrying its original note, and one prototype block per
  source file.

`vcmodchase.h` is unchanged: same public entries, same public enums. Every
engine hook and call site is untouched; this slice moves no call.

### How the move was kept neutral

- Function bodies are the originals, byte-for-byte. The only edit inside a
  chunk is dropping `static` from its return-type line.
- State objects are defined in `vcmodchase.cpp` in their original order, so
  the order they are initialised in does not change. Each lost its `static`;
  the four `static const` vectors became `extern const` (a const object at
  namespace scope keeps internal linkage without it).
- The two intra-file forward declarations — the block at the top of the old
  file and the single `VCModChaseCriminalTarget` line at the force-pools
  banner — are gone; the internal header declares every module symbol
  non-static instead.
- The three source files include the same header list as before, so no
  dependency moved either.

Verification of the move was mechanical, not by eye: all 115 function bodies are
present exactly once and byte-identical to the original; all 103 state-object
declarations are present; the only original lines not found verbatim are the
two dropped forward prototypes, which the header replaces non-static.

### Build and harness

- CMake globs the directory, and premake's `addSrcFiles("src/extras")` already
  covers `src/extras/*.cpp`, so neither build file needed a change. No new
  directory, so the Windows premake path is unaffected.
- `utils/test_vc_chase.py` now searches the three sources for the functions it
  extracts by name; nothing else in it changed.
- `utils/test_vc_character.py`, `test_vc_combat.py` and `test_vc_keys.py` read
  `vcmodchase.cpp` for the chase take/restore lines, the combat include and the
  removed key macros; all three still find them where they are.

## Not changed

- The update order and every line in the post-extraction map: adrenaline 1870 →
  reconcile 1871 → apply-default 1872 → ride 1873 → sit 1927 → street 1928 →
  npc 1929 → keys/latch 1941–1950 → never-wanted 1953; the animation-path hooks
  at `PlayerPed.cpp` 1316 and 645; the no-strafe gates at 1313/1327,
  `Cam.cpp` 1537, `Ped.cpp` 2115.
- The feature-off path: this slice moves code, it does not gate anything anew.
- Play checks: the open list is the same as the last handoff.

## Verification

- All 45 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 455); installed with
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty immediately before the
  install. The installed binary reports `vcmods build 455` and is ad-hoc
  signed.
- In game: not checked. The chase mission itself is worth a run when the player
  is at the machine — the ground route end to end and one air insertion — since
  this slice rebuilt the module's boundaries even though the code is the same.

## Uncommitted

Ten refactor slices (adrenaline, sit, street, NPC, gang, ride, character,
player, combat, chase) plus the cop fixes are all uncommitted; every refactor is
a behaviour-neutral move. `vc-mods.patch` predates them.

- New this slice: `src/extras/vcmodchasesquad.cpp`,
  `src/extras/vcmodchaseair.cpp`, `src/extras/vcmodchaseinternal.h`.
- Modified this slice: `src/extras/vcmodchase.cpp` (the state machine
  remainder), `utils/test_vc_chase.py` (reads three sources), and
  `docs/architecture.md` (rule 15 wording, the landmine entry, the target
  layout, the debt sizes).

## Next

1. Play checks when the player can test: the combat pass, then the still open
   character, ride, gang, NPC/cop and player passes, plus one chase run. One
   feature per session, flag on and off.
2. Split `vcmodpanel.cpp` (1,731) by sub-concern: registry / catalogs / drawing.
   Its rows point at the feature headers, so the split is a move like this one.
3. Known debt still kept out: the `ProcessPlayerWeapon` aim-control branches
   (doom-aim accuracy, scope skip, AIM RAISE trigger gate) and the five
   `bVCModNeverWanted` gates in `Wanted.cpp` (one helper still owed).
4. Commit the ten refactors (and the cop fixes) only when asked, then
   regenerate `vc-mods.patch`.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 455 is installed.
> Read `docs/handoff/2026-11-13-chase-split.md` first, then
> `docs/architecture.md` and `AGENTS.md`. Ten behaviour-neutral slices
> (adrenaline, sit, street, NPC, gang, ride, character, player, combat, chase)
> are uncommitted; the character, ride, gang, NPC/cop, player and combat play
> checks are still open.
> The chase module is now four files: `vcmodchase.cpp` (state machine, 1,552),
> `vcmodchasesquad.cpp` (ground team, 948), `vcmodchaseair.cpp` (air insertion,
> 1,019) and `vcmodchaseinternal.h` (defines, enums, state as extern, one
> prototype block per source). `vcmodchase.h` and every engine hook are
> unchanged; all 45 harnesses pass.
>
> Work directly in this session: one module per session, done in place. Next is
> the `vcmodpanel.cpp` split (registry / catalogs / drawing), then the
> `ProcessPlayerWeapon` aim-control extraction and the single never-wanted
> helper in `Wanted.cpp` if they are wanted first.
>
> Keep every move behaviour-neutral and verbatim: same statements, order,
> comments and log strings; feature-off byte-identical to stock; no existing hook
> signature changed; engine files keep hook calls only. Preserve the update order
> in `CPlayerPed::ProcessControl` — adrenaline 1870 → reconcile 1871 →
> apply-default 1872 → ride 1873 → sit 1927 → street 1928 → npc 1929 → keys/latch
> 1941–1950 → never-wanted 1953 — the animation-path hooks
> (`VCModPlayerAnimGroup` 1316, `VCModCharacterMoveTempo` 645, last of the five
> sprint-speed writes), and the no-strafe gates at `PlayerPed.cpp` 1313/1327,
> `Cam.cpp` 1537, `Ped.cpp` 2115.
>
> Per feature: run all `utils/test_vc_*.py` suites, `scripts/build.sh`, then
> `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty,
> and confirm the installed binary reports the new build number BEFORE handing
> off for the player's live test — never hand off an uncompiled tree. In-game
> verify on and off is the player's turn. Clear `~/Games/VC/reVC.log` before each
> test, and read only fresh, filtered, capped slices. Update the debt sizes in
> `docs/architecture.md`, write the handoff and a paste-ready prompt at the end.
> Never commit or push unless asked; game data and uchg anim files are read-only.
