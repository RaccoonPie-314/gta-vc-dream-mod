# BECOME NPC: body-derived type and gang identity (body-type banking) — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`. Status: design
approved in chat 2026-11-14; pending spec review. Continues
`docs/specs/2026-11-11-npc-mode-full-ai-design.md` and
`docs/specs/2026-11-11-gang-faction-membership-design.md`.

## Goal

BECOME NPC's identity follows the worn body, the way the voice already does. A
new `TYPE FROM BODY` switch makes the worn model's stock ped type choose the NPC
profile and, for gang bodies, the gang number. With the switch off the mode is
exactly today's manual GANG/CIVILIAN/COP behaviour, and GANG is GANG7.

## Current behaviour

- `nVCModNpcType` is the manual profile (GANG, CIVILIAN, COP), stored as
  `[VC Mods] NpcType` in `reVC.ini` and read at `re3.cpp:700`.
- GANG is hardcoded to Vercetti `GANG7`: `VCModGangEffectiveType`
  (`vcmodgang.cpp:19`), `m_fearFlags`/`m_pedStats` GANG7 and the GANG7 gang-bit
  clear in the borrow block (`vcmodnpc.cpp:460-496`).
- Voice already follows the model: the bank is selected by model index
  (`AudioLogic.cpp:5354`).
- The character swap already carries the model's anim group and, for the
  civilian personality, the model's stock stat (`vcmodnpc.cpp:279`).
- The mapping data is already in the model table: `CPedModelInfo::m_pedType`
  and `m_pedStatType` (`PedModelInfo.h:36`).

## Ground truth (verified in the install's data)

`default.ide`:

- player model 0: `PLAYER1`, `STAT_PLAYER` (line 42).
- `swat`, `fbi`, `army`: `COP`, `STAT_COP` (lines 44-46).
- `medic`: `EMERGENCY`, `STAT_MEDIC` (47); `fireman`: `FIREMAN`,
  `STAT_FIREMAN` (48).
- gang models: `CBa/CBb GANG1 STAT_GANG1` (126-127), `HNa/HNb GANG2`,
  `SGa/SGb GANG3`, `CLa/CLb GANG4`, `GDa/GDb GANG5`, `BKa/BKb GANG6`,
  `PGa/PGb GANG7` (138-139).
- `special01..21`: `CIVMALE`, `STAT_STD_MISSION` (154+).
- no GANG8/GANG9 models ship; the ped type enum keeps the range.
- `PEDSTAT_GANG1..GANG7` exist; there is no GANG8/GANG9 stat.

## Mapping (TYPE FROM BODY on)

| worn model's stock type | profile | gang type |
| --- | --- | --- |
| `MI_PLAYER` | GANG | GANG7 |
| GANG1..GANG9 | GANG | the model's own type |
| COP (`cop`, `swat`, `fbi`, `army`) | COP | none |
| everything else (`CIVMALE`, `CIVFEMALE`, `CRIMINAL`, `PROSTITUTE`, `EMERGENCY`, `FIREMAN`, `SPECIAL`) | CIVILIAN | none |

The mapping follows the stock ped type, not the panel shelf. A medic or fireman
body is browsed on the COPS shelf but its stock type is `EMERGENCY`/`FIREMAN`,
so it auto-selects CIVILIAN. Military bodies select COP because their stock type
is COP. Mission/cutscene slots are `CIVMALE`/`STAT_STD_MISSION`, so they
auto-select CIVILIAN; the cutscene clump's own stats are not used because the
player wears the special slot's model info.

## The toggle

- New flag `bVCModNpcAutoType`, ini key `NpcAutoType`, default on.
- On: the profile and gang type derive from the player's current model every
  time they are read. The stored `nVCModNpcType` is never rewritten; it remains
  the manual fallback.
- Off: exactly today's behaviour. Manual profile on any skin; GANG means GANG7.
- Panel: new `TYPE FROM BODY` row on WORLD, next to NPC TYPE. Info: "worn body
  picks profile and gang". Warn: "NPC TYPE is overridden while on".
- NPC TYPE row: the getter returns the effective profile while auto is on, so
  the label follows the body. Cycling the row while auto is on turns auto off
  and applies the chosen value, so the row is never a dead click.
- The ALL ON/OFF sweep does not include the new flag; it is a mode setting, like
  WALK MODE. The debug menu gets a `type follows body` switch.
- A body change or a toggle change mid-mode reuses the existing profile-switch
  path: `nVCModNpcStateProfile` compares the effective type and re-inits the
  civilian state. A gang-to-gang body change does not re-init; the stat borrow
  re-resolves through the existing `player->m_pedStats != borrowedStats` check.

## Derivation helpers (`vcmodnpc`)

- `int32 VCModNpcEffectiveType(void)`: when the mode is on and auto is on, ask
  `FindPlayerPed()` for the body profile; otherwise return `nVCModNpcType`. A
  nil player or a non-ped model info falls back to `nVCModNpcType`, so a data
  error can never crash or silently change the profile.
- `int32 VCModNpcBodyProfile(CPlayerPed *player)`: the mapping table above.
  `MI_PLAYER` is GANG; GANG1..9 is GANG; COP is COP; everything else is
  CIVILIAN.
- `int32 VCModNpcGangType(CPlayerPed *player)`: `MI_PLAYER` is GANG7; a gang
  model is its own type; any other model is GANG7. The fallback is only
  reachable with auto off and a manual GANG profile, which is today's behaviour.
- `CPedStats *VCModNpcBodyStats(CPlayerPed *player)`: the model's stock
  `m_pedStatType`, with the existing bounds and nil fallback. The civilian path
  keeps its strong-Tommy special case; the GANG path uses GANG7 for `MI_PLAYER`
  and this helper for every other body.
- `VCModNpcCivilianActive`, `VCModNpcGangActive` and `VCModNpcCopActive` use
  `VCModNpcEffectiveType()` instead of `nVCModNpcType`. `VCModNpcStrongActive`,
  `VCModNpcCopScanDiag`, the engage log and the profile-switch comparison use
  the same effective value.

## Identity plumbing

- `VCModGangEffectiveType(player)`: when the ped is the player and GANG is
  active, return `VCModNpcGangType(player)`; otherwise return the ped's own type.
  Non-player peds are unchanged.
- Borrow in `VCModUpdateNpcMode`:
  - `m_fearFlags = CPedType::GetThreats(gangType)` for the GANG wander.
  - `m_pedStats` is GANG7 for `MI_PLAYER`, the body's stock stat for other GANG
    bodies.
  - `m_gangFlags` clears the gang-type bit (GANG1..9), restored from
    `nVCModNpcSavedGangFlags` on off, break and profile switch.
  - The saved-stat pointer and restore machinery are unchanged.
- `IsGangMember` stays profile-based: true for the player while GANG is active.
  With auto on, GANG is only gang/Tommy bodies; with auto off, any skin can act
  as gang as requested.
- The GANG profile's fearless fight-back and refuse-flee overrides stay
  profile-wide (the existing named divergence). This feature changes identity,
  stats and threats, not the reaction policy.
- COP and CIVILIAN profile bodies and stats are unchanged. COP keeps the
  mission setup; CIVILIAN keeps the body-stat borrow and the strong-Tommy
  variant, which is reachable with auto off.

## Non-goals

- No new hand-kept body-to-gang table. The model table is the bank; a future
  override table (for example a mission body mapped to a gang) is a separate
  feature.
- No voice change; voice already follows the model.
- No new AI layer for medics or firemen. CPR is the only remaining stock NPC
  action and is not this feature.
- No cop arrest or pursuit work; those are player-mechanic paths, not stock NPC
  behaviour.
- No forced body, gang weapon or model swap.

## Edge cases

- Tommy's model is `PLAYER1`/`STAT_PLAYER`; the GANG profile special-cases it to
  GANG7 so the default experience does not change.
- Mission/cutscene special slots resolve to `CIVMALE`/`STAT_STD_MISSION`, so
  auto selects CIVILIAN.
- No GANG8/GANG9 models ship. The helper accepts the range, and the body's
  `m_pedStatType` supplies the stat if a data edit ever adds one.
- A non-ped model or nil model info falls back to the stored manual profile.
- A body change while the mode is active follows the existing character-swap
  path; the effective type changes on the next read, and the profile-switch
  re-init runs if the profile changed.
- Turning auto off while wearing a gang body reverts to the stored manual
  profile and GANG7 inside GANG; turning it on re-derives. The stat/gang-flag
  restore path is unchanged.
- Pinning: NPC TYPE pins the manual value (the getter shows the effective value
  at pin time); TYPE FROM BODY pins the switch. With auto on, the pinned manual
  profile is inert until auto is off.
- The engage log names the effective profile and gang type. The break log keeps
  its existing reason text. Probe-style lines stay behind `VCMOD_DIAG`;
  feature events stay unconditional.

## Files

- `reVC/src/extras/vcmodnpc.h/.cpp`: flag, mapping helpers, effective-type
  predicates, gang condition, borrow.
- `reVC/src/extras/vcmodgang.cpp`: effective type uses the derived gang.
- `reVC/src/extras/vcmodpanelregistry.cpp`: the new row, the NPC TYPE
  getter/setter change, the debug tweak, the ALL ON comment.
- `reVC/src/core/re3.cpp`: `NpcAutoType` read next to `NpcType`.
- `reVC/utils/test_vc_npcmode.py`, `test_vc_gangfaction.py`,
  `test_vc_panel_info.py`: the mapping matrix, auto on/off, borrow/restore,
  panel setter and row shape.
- `README.md`: the toggles table row.
- `docs/`: this spec, the implementation plan, the session handoff.

## Testing

Harnesses:

- `test_vc_npcmode`: mapping matrix (`MI_PLAYER`, each gang type, COP,
  EMERGENCY, FIREMAN, CIVMALE/CIVFEMALE/CRIMINAL/PROSTITUTE/SPECIAL), auto
  on/off, getter/setter (cycling disables auto), profile-switch re-init on a
  body change.
- `test_vc_gangfaction`: effective type is the body gang; fear flags are
  `GetThreats(body gang)`; stats are the body stock stat (GANG7 for
  `MI_PLAYER`); the gang bit is cleared for the body gang; restore on off, break
  and switch; a non-gang body with auto off keeps GANG7.
- `test_vc_panel_info`: the new row's name, info and warn fit the 50-column
  rule.
- All 45 `utils/test_vc_*.py` suites must pass; the auto-off path is the
  regression baseline.

In game, one pass:

- Auto on: Tommy is GANG7 as today; a Cuban body is GANG1 (Cubans spare/chat,
  rival gangs hunt, cops chase); a military body is COP foot patrol; a civilian
  body is CIVILIAN with its body personality; a medic body is CIVILIAN.
- Auto off: a military body with manual GANG is today's GANG7 behaviour; any
  body with manual COP or CIVILIAN is unchanged.
- Cycling NPC TYPE while auto is on turns auto off and applies the chosen
  profile.
- Toggle the mode off, die, enter a car, get arrested, change the body
  mid-mode: stats, fear flags and gang flags restore; no residue; the next
  engage re-derives.
- Voice still follows the body.

Delivery: run all suites, `scripts/build.sh`, install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, confirm the installed build
number, then play.

## Risks

- A borrow/stats mismatch is the main risk: a GANG1 body with GANG7 stats or the
  reverse. The harness pins the exact mapping.
- The profile-switch path is second: a body change that changes the profile must
  re-init the civilian state, or the old profile's state leaks into the new one.
- The panel setter is a deliberate two-effect action; a test pins it.
- `IsGangMember` is profile-based. With auto off, a cop-looking body in GANG is
  treated as a gang member on purpose (the requested flexibility).
- The GANG profile's fearless overrides remain profile-wide. If the body's stock
  fear should govern instead, that is a separate, explicit change.

## Portability and publication

Gameplay code stays platform-neutral; no new assets, no Rockstar data. Published
artifacts name no AI or tool; the workspace is `vc-mod`. No commit unless asked.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only.
- `anim/cuts.img`, `anim/cuts.dir` and `anim/ped.ifp` are `uchg`.
- Git on reVC is the play-tester's: no commit, tag or push unless asked.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
