# Cutscene subtitles and the "<KEY> missing" text (2026-11-16)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
Installed build `~/Games/VC/reVC.app` (binary dated Nov 16 07:49, this session).
Uncommitted: `src/text/Text.cpp` (one diagnostic line).

## The report

During a cutscene the game drew something like `CUBE1 X missing`. The question
was whether subtitle handling is broken.

## How the path actually works

Cutscene subtitles are not drawn by `CCutsceneMgr`. The mission script prints
them:

- `PRINT_NOW` (`0x00BC`) + an 8-byte GXT key, e.g. `CUB1_A` … `CUB1_X`.
- `CTheScripts::GetTextByKeyFromScript` (`src/control/Script.h:519`) hands the
  raw script bytes to `CText::Get` — no copy, no added terminator.
- `CText::Get` (`src/text/Text.cpp:120`) searches the global `MAIN` table
  first, then the one loaded mission table, and only if `bHasMissionTextOffsets`
  and `bIsMissionTextLoaded`.
- On a miss, `CKeyArray::Search` builds `"%s missing"` into `WideErrorString`
  and that is the text on screen. Only a `MASTER` build blanks it.

The mission table is loaded by `LOAD_MISSION_TEXT` (`0x054C`) →
`CText::LoadMissionText`, which unloads the previous table first.

## What was ruled out

- `data/main.scm` is byte-identical to the Steam install
  (md5 `f0e8d648fd9e5ca18effe62b2a08789e`).
- `TEXT/american.gxt` in `~/Games/VC` is the file the game opens. The mod's
  per-mod probes (`mods/<name>/AMERICAN.GXT`) all miss and fall through to it;
  the bundle copy under `Contents/Resources/gamefiles/TEXT/` is only a
  fallback and is not the one read.
- Opcode numbering matches the SCM exactly once the `ScriptCommands.h` enum is
  counted with `#ifdef`/`#else` branches collapsed: `PRINT_NOW = 0xBC`,
  `SCRIPT_NAME = 0x3A4`, `LOAD_MISSION_TEXT = 0x54C`. (Counting both branches of
  a conditional produces a spurious +1 after `0xBC` and misattributes every
  later opcode.)
- In the `CUBAN1` script the order is `SCRIPT_NAME CUBAN1` →
  `LOAD_MISSION_TEXT CUBAN1` (`0xD3056`) → `PRINT_NOW CUB1_A…X`
  (`0xD365E`…), so the table is loaded before the cutscene prints.
- `CUB1_X` is in `CUBAN1`, and reVC's own `BinarySearch` (12-byte entries,
  `strcmp` on `char key[8]`) finds it in 6 steps. Max key length in the GXT is
  7, so no key is unreachable through a missing terminator.
- `src/text/` is unchanged against upstream; no file under `src/extras/` touches
  `TheText`, `CMessages` or `ScriptSpace`.
- `CText::Load`/`Unload` run only from `InitialiseLanguage`, which is called
  from `psInitialize` at startup (and on a language change) — nothing reloads
  text mid-game on macOS.
- The mod's save gate cannot produce a mid-mission save:
  `bAlreadyRunningAMissionScript || IsPlayerOnAMission()` and
  `CCutsceneMgr::IsRunning()` both refuse. A mid-mission save would be the one
  state that shows this symptom, because the loaded mission table name is never
  stored in the save (`GetNameOfLoadedMissionText` has no callers) and so is
  never restored on load.

## Genuine stock data gaps

Six keys the stock script prints that exist in no GXT table — in the game dir
copy, the bundle copy and the repo copy alike:

| Key | Print | Missing from |
|---|---|---|
| `ICC1_8B` | `PRINT_NOW` | `ICECRE1` (ice cream) |
| `ICC1_8C` | `PRINT_NOW` | `ICECRE1` |
| `PIZ1_0` | `PRINT_HELP` | pizza-boy |
| `SIREN_3` | `PRINT_HELP` | side mission |
| `GUN_H2` | `PRINT_HELP_FOREVER` | only `GUN_H1` exists |
| `CPYTH02` | `PRINT_WITH_NUMBER_BIG_Q` | only `CPYTH01` exists |

These are Rockstar data gaps, not mod regressions; stock VC draws the same
`<KEY> missing` line. None of them is a `CUB*` key.

## What changed

`CText::Get` now records every failed lookup to `reVC.log`:

```
[DBG]: text key missing: <key> (mission table <table>, loaded <0|1>)
```

Diagnostic only — the on-screen behaviour is untouched, the key is printed with
`%.8s` so a non-terminated script key cannot overrun, and `debug()` is a
permanent log path in both Debug and Release. Nothing else was edited.

## Verified

- Full build, no new warnings (`scripts/build.sh`).
- Installed into `~/Games/VC` with no session running (`scripts/install.sh`);
  the format string is present in the installed binary.
- Static checks above were run read-only against the live install and the GXT.

## Not verified

- Not reproduced in play. No session has run since the diagnostic shipped, so
  there is no log line naming a real failing key yet.

## Next

1. Play until a subtitle shows `… missing`, then read the last
   `text key missing:` line in `~/Games/VC/reVC.log`. `loaded 0` means the
   mission table was not loaded at print time; `loaded 1` with a table name
   that does not own the key means the wrong table was current.
2. If it reports one of the six gaps above, decide whether to fill it with a
   `mods/` GXT override — that is a deliberate divergence from stock data, so
   it needs a decision on wording first.
3. Commit `src/text/Text.cpp` with the rest of the session's work when the
   behaviour is confirmed.

## Files not to touch

`~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`, and in
particular `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (immutable, cannot
be rebuilt).
