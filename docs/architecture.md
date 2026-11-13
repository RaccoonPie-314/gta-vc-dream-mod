# Mod structure and feature isolation

This is the layout rule for the mod. It exists so a feature can be added,
toggled, or removed without touching another feature's code or leaving state
behind. It is not a description of the upstream reVC engine.

If a change cannot follow a rule, the change is the thing that moves.

## The layers

| Layer | Path | May contain | Must not contain |
| --- | --- | --- | --- |
| Engine | `src/{peds,control,core,vehicles,renderer,weapons,audio,...}` | Hook calls, entity state, upstream code | Feature state, feature blocks, UI, ini parsing |
| Mod feature | `src/extras/vcmod<feature>.{cpp,h}` | One feature's flag, state, logic, predicates | Panel rendering, ini parsing, another feature's state |
| Config and UI | `vcmodpanel*`, `vcmodkeys.*`, `vcmoddiag.*` | Row registry, panel drawing, key capture, probe gate | Owning a feature's runtime state |
| Assets | `mods/<name>/`, `mods.ini` | Data, overlays, per-mod files | Code paths, hardcoded machine paths |
| Harness | `utils/test_vc_<feature>.py` | Extraction, stubs, behavior checks | Shipping code |

Dependency direction is one-way: engine → mod predicates, and UI → feature
headers. A feature never includes the panel header to read its own flag.

## The rules

### 1. Engine files are hook-only

A feature may add a predicate call or a one-line branch to an engine file. It
may not add a block of logic, a file-scope static, or a new engine method that
exists for one feature.

**Why:** engine files are the upstream patch. Every block widens the conflict
surface and gives the next feature something else to edit in the same place.

**How:** put the logic in `src/extras/`, declare a predicate in the feature
header, and call it from the engine. If the engine must remember something, add
an entity field, not a mod global.

### 2. One feature, one module

A feature is `src/extras/vcmod<feature>.cpp` plus a header. The header owns the
flag, the public predicates and the reset entry point. The cpp owns the state
and the state machine.

Do not add a feature to `PlayerPed.cpp`, `Ped.cpp`, `PedAI.cpp` or
`PedFight.cpp`. Those are engine files. If a feature needs them, they call the
feature's hook.

**Why:** one file per feature is discoverable, testable, and removable. A
feature spread across five engine files cannot be reviewed or reverted as a
unit.

### 3. The panel is a consumer

`vcmodpanel.cpp` draws and edits. It does not own feature state. New flags go
in the feature header; the panel includes that header and points a row at the
flag.

Flags that still live in `vcmodpanel.cpp` are debt. Move a flag to its feature
header when that feature is next touched; do not add new flags there.

**Why:** engine files currently include the UI header just to read a flag,
which makes the UI layer the dependency hub.

### 4. One config registry

Every persisted switch is one registry row: name, ini key, default, get/set and
page. Startup load, save, the panel and the debug menu all read that one row.
Do not add a second `ReadIniIfExists` by hand for the same key.

Validate at load: clamp indices, reject unknown enum values, and give every
flag a defined default. A written key must have a reader; a reader must have a
writer.

**Landmine:** `CarFirstPerson` is written by pinning and never read at startup,
so the pin does nothing.

### 5. Feature off means stock

The off path must be the original engine path: same defaults, same timing, no
leftover state, no extra log lines. Test with the flag off, not only on.

Ambient behaviour may default on. Commands default off. ALL ON must not sweep
commands or diagnostics. If a gate refuses an action, say why in-game and in
the log; never a silent no-op.

### 6. Take and restore

Any feature that takes over engine state must save the stock values and restore
them when it is done: toggle-off, death, dismissal, hand-back, or session end.

Keep the list explicit in the feature:

- vehicle: `AutoPilot` mission/style/cruise/speed, status, driver, seats
- ped: stats, anim group, model, objective, threat refs, wait state
- player: time scale, camera zoom, weapon state, wanted level, control owner
- resources: model requests, vehicle and ped handles

**Why:** the classic bug is a car left at `MISSION_STOP_FOREVER` or a ped left
with borrowed stats. A toggle is not finished until the off path is clean.

### 7. Per-entity state over global flags

The engine should ask about the entity: "is this car on a mod route?" or "is
this ped under civilian AI?" — not "is the crew feature active?".

Prefer an entity field set by the feature. A global flag is for player-wide
modes only.

**Why:** two features can then share the engine without fighting over one
entity, and the engine stays feature-agnostic.

### 8. No feature-to-feature calls

Do not reach into another feature's statics. If two features must interact, the
interaction belongs to one owner or to a shared helper.

One canonical helper per job: one HUD notice, one seat scan, one vehicle
hand-back. A near-duplicate is a bug waiting to drift.

### 9. One owner per input

One hotkey per action, one `VCKEY_*` slot. Handlers check
`VCModKeyCapturing()`, and the key is added to the labels, the ini names and
the panel KEYS row.

Do not let two features read the same key or pad button in the same frame
without an explicit owner.

### 10. Update order is explicit

New per-frame work goes where the existing order lives, and the comment says
why the order matters:

- global systems: `CGame::Process`
- player systems: `CPlayerPed::ProcessControl`
- per-entity traffic: `CAutomobile::ProcessControl` / `CBike::ProcessControl`

Do not hide a tick in an unrelated engine method.

**Why:** street idle, NPC mode and the ride all write the player's state; the
order is the difference between a clean hand-off and a fight.

### 11. Validate at the boundary

Model indices, pool handles, zone indices, enum values and ini values are
clamped before use. Use a pool handle or index across frames, never a raw
entity pointer. Timers use wrap-safe subtraction (`now - since > threshold`),
not `now > since + threshold`. Release model requests when the feature is done.

### 12. Assets are data

Mods live under `mods/<name>/`, listed in `mods.ini`. Later lines win, so the
order is data. Overlays are built with `scripts/mk-overlay.py`; do not hand-edit
`.dir`/`.img`. No machine paths, drive letters or bundle paths in mod code.
Public packages carry no Rockstar data.

### 13. Logging

Feature events ("street idle", "sit", "spin kick", "passengers"), errors and
one-shot state changes stay unconditional. Temporary probes go through
`VCMOD_DIAG` (the DIAGNOSTICS switch, off by default). No raw `fprintf` in a
per-frame path.

**Why:** the wander probe alone wrote 18,535 lines and helped grow the log to
143 MB in 25 minutes.

### 14. Tests, build and delivery

One harness per feature, `utils/test_vc_<feature>.py`, following the existing
pattern: extract the real function, compile it against small stubs, exercise
the decision path.

- Run the whole suite before shipping, not only the touched harness.
- Prefer behaviour and relationship checks over literal line checks. The
  registry rule is tested as "every row key has a loader", not as five copied
  strings.
- A new symbol used by an extracted function must be added to the shared stubs.
- CMake globs recursively. The Windows/premake path does **not**: a new
  `src/extras/...` subdirectory needs a `premake5.lua` line.
- No `#ifdef __APPLE__` in mod code. Platform code belongs in `src/skel/`,
  `src/core/FileMgr.*` and `src/core/CdStream_*`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Session ends with a handoff under `docs/handoff/`.

### 15. Size is a signal

A module near 1,000 lines is a split signal. Split by sub-concern, not by type:
chase → state machine / squad / air; panel → registry / catalogs / drawing.

Chase code grows in the sub-concern that owns it: the run and its state machine
in `vcmodchase.cpp`, the ground team in `vcmodchasesquad.cpp`, the air
insertion in `vcmodchaseair.cpp`. Panel code grows the same way: the row table,
pins and master switch in `vcmodpanelregistry.cpp`, the zone, ped and crew
lookups in `vcmodpanelcatalog.cpp`, the fonts, input and render in
`vcmodpanel.cpp`. Add to the sub-concern that owns the work, not to whichever
file is open.

### 16. Rows explain themselves

Every panel row carries a one-line `info` in plain language and an optional
`warn`. The footer shows the info for the row under the pointer; a row with a
warning gets a `!` badge and a `! ` line. Keep the text within the panel width
(50 columns), and say what the switch changes and what can surprise the player.

No row is added without these fields. `utils/test_vc_panel_info.py` enforces
the shape and the length.

**Why:** a row name is not a description. `NEVER WANTED`, `BECOME NPC` and
`SKIP RIDE` change the game in ways their names do not say, and a new player
should not have to read the source to find out.

**How:** add `info` and, when the row can surprise, `warn` to the row entry.
The hovered row's text and the `!` badge are drawn automatically; do not add a
second help table.

### 17. Names follow the module

A name says which module owns it, what kind of thing it is, and which part of
the module it lives in. One scheme; no spelling that only works if you know the
history.

- **Files.** A feature is `src/extras/vcmod<feature>.cpp` and `.h`. When a
  module outgrows one file (rule 15), each sub-concern is
  `vcmod<module><concern>.cpp` — one word, no separator: `vcmodchasesquad.cpp`,
  `vcmodpanelregistry.cpp`. The private interface shared by those sources is
  `vcmod<module>internal.h`. The public header stays `vcmod<module>.h`; an
  `internal.h` is included by the module's own sources only.
- **Harness.** One per feature, `utils/test_vc_<feature>.py`, named after the
  module. A harness that covers a split module reads every source of it.
- **Functions.** `VCMod<Feature><Thing>` — `VCModChaseTickLeader`,
  `VCModRideZoneAt`, `VCModPanelRender`. A predicate answers one yes/no
  question.
- **State.** The type prefix on the module name: `b` bool, `n` int32, `f`
  float, `a` array or table, `p` pointer, `Handle` suffix for a pool handle —
  `bVCModStreetIdle`, `nVCModRideZone`, `aVCModRows`, `nVCModChaseLeaderHandle`.
  File-local static state keeps the same name; there is no short form for it.
- **Types and constants.** `eVCMod<Thing>` for an enum, members
  `VCMOD_<THING>_<VALUE>`; tuning values `VCMOD_<FEATURE>_<DETAIL>`; hotkeys
  `VCKEY_<ACTION>`; ini keys CamelCase (`MouseAimLockOn`); panel rows upper case
  and short (`FREEAIM+LOCKON`).
- **Logs.** `VCMOD <what happened>` on stderr, with the module tag when the
  message would otherwise be ambiguous (`VCMOD CHASE cleanup ped`). A log line
  records an event, not progress; probes go behind `VCMOD_DIAG`.

**Why:** the engine hooks and the harnesses find a feature by its prefix. A
second spelling (`Chase_squad`, `vcmod-chase-air`, `SquadTick`) turns every
grep and every removal into a search with false negatives, and leaves a stale
symbol nobody dares delete.

**How:** when adding a symbol, copy the nearest existing one in the same module
and change the noun. When splitting a file, keep the module prefix and add the
concern as a suffix, so the old name still finds the new home.

## Where a feature goes (target layout)

Some of these modules do not exist yet; they are the extraction target, not a
claim that the code is already there.

| Feature kind | Module | Engine hooks |
| --- | --- | --- |
| Panel, keys, probes | `vcmodpanel` + `vcmodpanelregistry` + `vcmodpanelcatalog`, `vcmodkeys`, `vcmoddiag` | `main.cpp`, `re3.cpp` |
| Character, anim set | `vcmodcharacter` | `CPlayerPed`, `CPed` |
| Combat, aim, reload, adrenaline | `vcmodcombat` | `PedFight`, `CPlayerPed`, `Weapon` |
| Walk mode, no strafe, lock-on | `vcmodplayer` | `CPlayerPed`, `Cam` |
| Ride, chauffeur, passenger, seats | `vcmodride` | `CPlayerPed`, `PlayerInfo` |
| Crew | `vcmodcrew` | `Game`, `CarAI`, `CarCtrl`, `Automobile` |
| Street idle, chat, wander | `vcmodstreet` | `CPlayerPed`, `PedChat` |
| Sit and seat attractors | `vcmodsit` | `CPlayerPed`, `Ped` |
| NPC profiles, gang, cop | `vcmodnpc`, `vcmodgang` | `PedAI`, `Ped`, `PedChat`, `AudioLogic` |
| Chase mission | `vcmodchase` + `vcmodchasesquad` + `vcmodchaseair` | `Game`, `Wanted` |
| Traffic | `vcmodtraffic` | `Automobile`, `Bike`, `CarCtrl`, `CarAI` |
| Vehicle bits | one module per bit | `Automobile`, `VehicleModelInfo` |
| Vanilla fixes, QoL | `vcmodqol` | `Frontend`, `Hud`, `Particle` |

## Landmines

- `src/peds/PlayerPed.cpp` — player-control glue. The feature state lives in the
  `vcmod*` modules; only hook calls belong here. Do not add blocks.
- `src/extras/vcmodpanel.h` — god header. Do not add unrelated declarations.
- `src/extras/vcmodpanel.cpp` (771) — fonts, input and render. The row table,
  pins and master switch live in `vcmodpanelregistry.cpp` (571), the zone, ped
  and crew lookups in `vcmodpanelcatalog.cpp` (446), and the shared types,
  state and cross-file prototypes in `vcmodpanelinternal.h` (113). Grow each
  in its own file. The chase module is split the same way: `vcmodchase.cpp`
  1,552 (state machine), `vcmodchasesquad.cpp` 948, `vcmodchaseair.cpp` 1,019,
  with the shared interface in `vcmodchaseinternal.h` (432).
- `src/peds/PedAI.cpp` gang overrides — engine-level and gated. Keep every
  change behind the predicate and every probe behind `VCMOD_DIAG`.
- `src/core/Wanted.cpp` — the never-wanted gates. One helper, no scattered
  copies.
- `src/audio/AudioLogic.cpp` — voice follows the model. Gate anything that
  changes stock behaviour.
- `src/extras/{ini.h,debugmenu.*,custompipes*,postfx*,shaders/}` — upstream or
  vendor code. Do not mix mod features into it.
- `premake5.lua` — non-recursive per directory. New subfolder, new line.
- `src/core/config.h` — no new `#ifdef` feature gates. Runtime flags only.
- `scripts/sync.sh` — requires a clean tree on `vcmods`; `vc-mods.patch` is
  generated, never hand-edited.
- `mods/mods.ini` — later lines win. Reordering is a behaviour change.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` — uchg; game data is
  read-only. Never truncate `reVC.log` as a cleanup; it lives under
  `~/Games/VC/`.

## New feature checklist

1. Name the feature and its module. Decide the flag, default and whether it is
   ambient or a command.
2. Write the module: state, logic, public predicates, `VCMod<Feature>Reset()`.
3. Add the engine hook(s): predicate or one-line branch only.
4. Add the registry row with a plain-language `info` (and a `warn` when the
   switch can surprise), the ini read and the debug-menu entry.
5. Add a key only if needed: `VCKEY_*`, capture check, labels, ini name, row.
6. Write the harness; run the whole suite.
7. Build; install only with no game session; confirm the off path is stock.
8. Write the handoff. Commit only if asked.

## Review gate

Before calling a feature done, answer all of these:

- With the flag off, is the behaviour identical to stock?
- Toggling mid-session leaves no residue: objectives, seats, stats, time
  scale, camera, vehicles, model requests?
- Does it restore everything it borrowed on death, dismissal and hand-back?
- Is any state global where it should be per-entity?
- Does every flag have a default, a clamp, a reader and a writer?
- Does the row explain what the switch does and warn about side effects?
- Does every key check capture and have one owner?
- Does the log stay quiet with DIAGNOSTICS off?
- Does the Windows path still build: no platform ifdefs in mod code, premake
  updated for a new directory?

## Current debt (shrink when touched)

As of 2026-11-13:

- `PlayerPed.cpp` 2,605 lines, 74 mod references — every feature module is
  extracted; what remains is hook calls and gated branches, plus the aim-control
  block in `ProcessPlayerWeapon`, which reads `vcmodcombat` predicates.
- `PedFight.cpp` 31 mod lines — hook calls only. `vcmodcombat` owns the
  aim/recovery state, the two-hand hold, the forced fight move, the spin kick,
  the never-wanted clamp and the NPC combat profile block
  (`src/extras/vcmodcombat.cpp`, 477 lines).
- `vcmodpanel.cpp` 771, `vcmodpanelregistry.cpp` 571,
  `vcmodpanelcatalog.cpp` 446 — the panel is split by concern (drawing /
  registry / catalogs); the row table is the only part that grows a line per
  switch. The chase module is split the same way: the state machine in
  `vcmodchase.cpp`, the ground team in `vcmodchasesquad.cpp`, the air insertion
  in `vcmodchaseair.cpp`, and the shared state in `vcmodchaseinternal.h`.
- `vcmodpanel.h` 28 lines — only the ped category, the ride-zone helper, persist
  and the render entry remain.
- HUD notice ×3, seat scan ×2 — one helper each.
- 16 harnesses import `test_vc_passenger` — shared support module is pending.
- `vc-mods.patch` is stale relative to the tree; commit and regenerate before
  handing the mod out.
- Windows `Play.bat` package path is not built yet.

## Relationship to AGENTS.md

`AGENTS.md` holds the workspace invariants: game data is read-only, a change
ships through the launcher, published artifacts name no AI, portability is an
invariant, and every session ends with a handoff. This document holds the code
shape rules. When they disagree, the stricter one wins.
