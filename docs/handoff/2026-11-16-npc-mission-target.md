# Handoff: MISSION TARGET, the BECOME NPC hunt

Date: 2026-11-16
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0` (nothing committed this
session)
Built and installed: `vcmods build 616` in `~/Games/VC/reVC.app` (no session was
running). Harness: all 53 `utils/test_vc_*.py` green.

## The report

BECOME NPC makes Tommy walk the street, but he only reacts to what the engine
threw at him: a cop chase objective, a gang group order, an ATM seat. The mission
the player is actually playing asks for a specific enemy, and nothing in the
mode pointed him at it. The request was not to change how the AI fights; it was
to add one switch that makes the AI-driven Tommy hunt the mission's enemy.

## What changed

- New module `src/extras/vcmodnpctarget.{h,cpp}` (sub-feature of BECOME NPC, like
  the WASD walk): flag `bVCModNpcMissionTarget`, default **off**, ini key
  `NpcMissionTarget`. `VCModNpcMissionTargetPed`, `VCModNpcMissionTargetEligible`,
  `VCModNpcMissionTargetTick`, `VCModNpcMissionTargetReset`.
- The enemy rule: `CharCreatedBy == MISSION_CHAR`, not `bIsPlayerFriend`, not the
  player, not a follower (`m_leader == player`), not `bNeverEverTargetThisPed`, alive.
- The tick runs inside the mode driver after `VCModGangGroupUpdate` and before the
  wander layer, so a free idle frame becomes the kill order and the wander's own
  "an objective owns the ped" check then leaves him to the hunt.
- Acquisition only from a free ped (no objective, no pose wait, no attractor, no
  car, `PED_IDLE`/`PED_WANDER_PATH`, in control); nearest eligible by 2D distance
  via a ped-pool scan retried every 1000 ms.
- The order is the stock `OBJECTIVE_KILL_CHAR_ON_FOOT` (not `ANY_MEANS`): the
  on-foot kill also attacks a target in his car, where any-means would make the
  ped grab a car and fight the leave-car order.
- Holds the target while it lives; re-issues the order only when nothing else
  owns it; clears when the mission ends or the target stops qualifying. A dead
  held target: the handle is dropped and the engine's kill completion / after-kill
  pose is left to run untouched.

## Files

- `src/extras/vcmodnpctarget.{h,cpp}` — new module: flag, eligibility, tick, reset.
- `src/extras/vcmodnpc.{h,cpp}` — tick wired in, reset on engage / toggle-off / break.
- `src/extras/vcmodpanelregistry.cpp` — WORLD row `MISSION TARGET` (info + warn) and
  debug entry.
- `src/core/re3.cpp` — `NpcMissionTarget` ini reader.
- `utils/test_vc_npctarget.py` — new, 12 checks (eligibility truth table, off/mode/
  free/scan-gap gates, nearest pick, hold, re-issue, mission end, friend flip, reset,
  wiring).
- `utils/test_vc_npccombat.py` — slice wiring check for the new switch.
- `utils/test_vc_npcmode.py` — tick/reset stubs for the driver.
- `utils/test_vc_adrenaline.py`, `utils/test_vc_character.py` — stub flag list.
- `utils/test_vc_passenger.py` — row count 81 -> 82.

`src/text/Text.cpp` was already modified in the tree before this session (missing-key
debug line); it is untouched here and still uncommitted.

## Play steps

1. Launch through the Dock app, confirm `vcmods build 616`.
2. BECOME NPC on with `MISSION TARGET` off (default): stock behaviour, no order.
3. Turn `MISSION TARGET` on mid-mission: Tommy should take the nearest mission
   enemy and hunt him on foot; a target in a car is attacked on foot rather than
   Tommy seeking a car of his own.
4. Kill the target; confirm the stock after-kill wait pose plays and the mode
   resumes hunting the next mission enemy.
5. Pin the row, restart, confirm the choice was remembered.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`,
> installed `vcmods build 616` in `~/Games/VC/reVC.app`. Read
> `docs/handoff/2026-11-16-npc-mission-target.md` first, then
> `docs/specs/2026-11-15-npc-stock-combat-design.md` and `AGENTS.md`.
>
> BECOME NPC now has a `MISSION TARGET` switch (WORLD page, default off): with
> BECOME NPC on and a mission running, the AI hunts the mission's own enemy via
> the stock `OBJECTIVE_KILL_CHAR_ON_FOOT`. The uncommitted tree also has the
> earlier `src/text/Text.cpp` missing-key debug line, not part of this change.
>
> Next: play the two states (mission running, switch off vs on; a target in a
> car; a kill then the next mission enemy), check the pin survives a restart, then
> commit and push with `scripts/backup.sh` only when asked. Run all
> `utils/test_vc_*.py` and `scripts/build.sh`; install only with
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. Game data and the `uchg` anim
> files stay untouched.
