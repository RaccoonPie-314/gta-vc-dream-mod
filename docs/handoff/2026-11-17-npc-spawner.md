# NPC spawner with a bindable key (2026-11-17)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
Tree build 671; the install running in `~/Games/VC` is the 15:22 build (667,
spawner without the army entry and plain names) — replaced the earlier
blocked install note: the game was relaunched from the Dock launcher while this
session was still building, and a session was running again at the end
(reVC PID 61564), so 671 is built but not installed. Nothing is committed.

## What shipped

**`src/extras/vcmodnpcspawn.{cpp,h}`** — a spawner modelled on the DEBUG-page
vehicle spawner, but driven by a key:

- the model list is every `MITYPE_PED` model in this install, sorted by IDE
  name; the pick persists as `SpawnPed` (default `MI_MALE01`);
- the key only queues (`VCModNpcSpawnKey`); `VCModNpcSpawnTick` runs from
  `CGame::Process` beside `VCModSpawnTick` and does the streaming and the
  spawn, never from a render;
- the body lands two metres ahead on ground, facing the player, through
  `CPopulation::AddPed` with the model's own IDE ped type — civilians walk,
  gangs take their stock weapons, cops are matched to `eCopType`
  (`cop`/`swat`/`fbi`/`army`/`vice*`), and mission/player bodies fall back to
  a `PEDTYPE_CIVMALE` container because `AddPed` has no branch for those
  types and reads the model slot as a cop type for `PEDTYPE_COP`;
- cap: 8 live spawned peds, tracked by `RegisterReference`; a freed slot
  returns on its own when the game deletes the ped. Spawned peds are ordinary
  ambient peds — not saved, never removed by the mod, nothing to restore.

**Army gang entry.** No stock model carries GANG9, so the list holds one
synthetic entry (`VCMOD_NPCSPAWN_ARMY_GANG`, the same sentinel value the
character shelf stores) inserted directly after the `army` model. It spawns
`CPopulation::AddPed(PEDTYPE_GANG9, MI_ARMY, pos)` and arms the ped with the
M4, exactly as the call-gang group arms its army men; `SpawnPed` can hold the
sentinel across sessions. The debug-menu integer still clamps to `MI_LAST_PED`,
so the panel remains the way to pick it.

**Plain selector names.** Gang bodies answer with the gang's plain name —
`Cuban gang`, `Haitian gang`, `Shark gang`, `Diaz gang`, `Security`, `Bikers`,
`Vercetti gang`, and the army entry `Army gang` — instead of the roster labels
(`Cuban gangster 1`). Civilian and cop models keep their readable names. This
is the spawner selector only; the PLAYER-page CHARACTER shelf still shows the
per-model roster names.

**Key.** New `VCKEY_SPAWNNPC` slot (keyboard and pad channels, ships unbound),
`KeySpawnNpc`/`PadSpawnNpc`, loaded in `re3.cpp` beside the crew-aggressive
slot; handler in `PlayerPed.cpp` beside the other unbound gameplay keys.

**Panel.** DEBUG page `SPAWN NPC` row opens the ped list and names the picked
body in its cell; picking only sets the key's model (the key stays the only
spawn path). KEYS page `SPAWN NPC KEY` row. The row is pinned through
`SpawnPed`, and the debug menu carries the same integer.

**Refusals** (notice plus a log line, never a silent no-op): in a vehicle,
model not a ped, cap reached, model did not load, no ground ahead.

## Testing

- New `utils/test_vc_npcspawn.py`: list filter and sort, deferred key,
  container mapping, cop-type mapping, cap 7/8 boundary, panel and key wiring;
  the decision functions compile against stubs.
- Harness updates that the new row/slot forced: `test_vc_keys` (new slot pair),
  `test_vc_adrenaline` and `test_vc_character` (spawner stubs for the shared
  catalog code), `test_vc_panelhouse` (DEBUG rows 6 → 7), `test_vc_passenger`
  (row total 83 → 85).
- Whole `utils/test_vc_*.py` suite green (60 harnesses); `scripts/build.sh`
  clean; build 671 in the tree.

## Not verified

Nothing ran in play yet. Install and the checklist below are the next
session's first moves.

## Next steps

1. With no session running: `scripts/install.sh` (or start the Dock-pinned
   app, whose launcher rebuilds and installs), then launch.
2. KEYS page: bind `SPAWN NPC KEY` (e.g. `K`); DEBUG page: open `SPAWN NPC`
   and pick a civilian model.
3. Press the key on foot: one ped appears two steps ahead facing Tommy and
   walks off like any ambient ped. Ninth press shows
   `npc spawner: 8 spawned peds already alive`. Pressing it in a car shows
   `npc spawner: leave the vehicle first`. Pick a gang model (walks armed with
   the gang's stock weapon) and a cop model (arrives as that officer type).
4. Re-check the vehicle spawner and the KEYS page capture/pad navigation on
   the same build; the row table moved.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` —
  read-only, including `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp`.
- Do not install while `pgrep -f "reVC.app/Contents/MacOS/reVC"` is non-empty.
