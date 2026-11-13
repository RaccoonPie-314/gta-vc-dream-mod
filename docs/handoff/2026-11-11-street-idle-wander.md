# Street-idle wander: Tommy becomes a pedestrian when left idle — built, awaiting play

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods` (upstream remote; no
branch/worktree/push here). HEAD `8d57f7c`. The Dock-pinned `~/Games/VC/Vice City
Mods.app` rebuilds and installs this tree on launch; the clean build was also
installed directly into `~/Games/VC/reVC.app` with no session running.

## The request

When the player stands idle long enough, hand him the NPCs' own wander — 1:1
walking and animation, "basically becoming an NPC". Follow-up: make sure it is
the Vercetti gang's engine, not a civilian approximation.

## What the engine actually does (the gang question)

- Pathing is one shared engine for every ped type. Cops, civilians and gangs all
  walk through `CPed::SetWanderPath → WanderPath` on the same `PATH_PED` nodes.
  The Vercetti crew is the proof: it spawns `PEDTYPE_GANG7` and calls
  `leader->SetWanderPath(...)` (`src/extras/vcmodcrew.cpp`).
- The layers on top differ: civilians (`CCivilianPed`) run `ScanForInterestingStuff`
  (gawk/flee/report crime); cops (`CCopPed`) add pursuit/arrest; gangs are plain
  `CPed` with type-checks (hostility matrix, `GANG7` hardcoded friendly to Tommy).
- So there is no private gang pathing to adopt. The wander Tommy gets IS the
  crew's walk, and like a gang ped he does not run the civilian panic layer
  (that is `CCivilianPed`-only code).
- He cannot literally take `PEDTYPE_GANG7`: `CPed::IsPlayer()` is derived from the
  ped type (`src/peds/Ped.cpp`), so a type swap would make the camera, pad, wanted
  and every mission script lose the player. He keeps `PLAYER1` and shares the
  gang's walk code — exactly what the crew does.

## Design shipped

An escalation of the existing street-idle switch (`bVCModStreetIdle`), no new
panel row. The stillness clock already runs pose (4 s) → chat (2.5 s, resets the
clock on end). A third, longer threshold hands him to the engine:

- `VCMOD_STREET_WANDER_WAIT` = 30000 ms of uninterrupted stillness, alone (the
  chat owns him first when a partner is near). `VCModStreetStartWander` sets a
  mod flag and calls the engine's `SetWanderPath`.
- The only engine change: `SetWanderPath`'s player guard is lifted for that
  deliberate call — `if (IsPlayer() && !VCModStreetWanderOwnsPlayer()) return false;`
  (`src/peds/Ped.cpp`). The predicate is exported from `PlayerPed.cpp` via
  `vcmodpanel.h`, next to `VCModStreetChatOwnsPed`. NPC/crew behaviour is untouched.
- `WanderPath` is self-sustaining (picks the next node on arrival, waits at
  crossings), so the engine walks him indefinitely with the stock clips. When a
  dead-end node drops him to `PED_IDLE`, the wander branch re-issues the same
  call, like the population AI does for civilians. No path at all (interior,
  off-path ground) → `SetWanderPath` falls back to idle and the flag clears, so
  he keeps posing.
- Input suppression mirrors the seat: `objective==NONE → PEDMOVE_STILL` is gated
  off during wander, and `CPlayerPed::ProcessControl` sits the frame out before
  the control switch (which has no wander case). Any input — walk, jump, weapon,
  target, duck — ends the wander the same frame (`VCModStreetWanderBreak`, reusing
  the chat break bits) and control resumes. Controls-disabled (mission/cutscene),
  death, into a car, or a knock-down state also end it.
- Entry reuses `VCModStreetBlockReason` (on foot, unarmed-fire, off tarmac, not
  aiming/ducking/in water/in air, controls live). Wander while wanted is allowed
  as street idle already is; an arrest ends it via the state break.

## Files

- `src/peds/Ped.cpp` — the `SetWanderPath` guard.
- `src/peds/PlayerPed.cpp` — wander statics/threshold, `VCModStreetWanderOwnsPlayer`,
  `VCModStreetWanderBreak/EndWander/StartWander`, the wander branch and start
  check in `VCModUpdateStreetIdle`, the two input-suppression points.
- `src/extras/vcmodpanel.h` — predicate declaration.
- `utils/test_vc_wander.py` — new driver (7 checks) extracting the four helpers.

## Verification

Release build green (`scripts/build.sh`). Full harness suite 143/143
(`python3 -m unittest discover -s utils -p 'test_vc_*.py'`), including the new
wander driver. Installed into `~/Games/VC`; the installed binary carries the
`VCMOD street idle: wander started/ended` log lines. Not yet played — in-game
confirmation is the user's.

To watch in play: stand still on a pavement ~30 s (no nearby chat partner) and
he should walk off on the ped paths; any key returns control instantly. The
stderr log names each start/end and its reason.

## Levers if the feel is off in play

- Threshold: `VCMOD_STREET_WANDER_WAIT` (a `#define`, not ini-tunable).
- Camera follow during wander is expected to just track him (the camera reads
  his position), but it is unverified — first thing to eyeball.
- The frame-out skips `ProcessAnimGroups`; if a weapon anim group makes the walk
  clip look wrong, that is the place to look. He enters unarmed-fire, so this is
  unlikely.

## Uncommitted in reVC/

This session: the four files above. Alongside prior sessions' work (crew
`vcmodcrew.*`, first-person `vcmodfirstperson.*`, windup, traffic/CarAI/CarCtrl,
Cam/Game/PlayerInfo/re3 hooks, key table, panel, and the matching harnesses).
The user handles git after manual testing.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` —
  read-only (AGENTS.md).
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).

## Next steps

1. Play-test the wander: escalation timing, the walk looking 1:1 with the crew,
   camera follow, and instant wake on input.
2. If he wanders into trouble (traffic, water) the break reasons should catch it;
   report any case where he keeps walking when he should stop.
3. Nothing else open on this feature; it sits uncommitted with the crew work.

## Manual "BECOME NPC" toggle + NPC TYPE profile — built, awaiting play

Follow-up request: a mod-menu toggle that turns Tommy into an NPC on command and
ignores player input until switched off (the idle escalation wakes on any input;
this must not), plus a switcher for which behavior he falls into. User cannot
play-test yet — built offline. Scope settled in chat: ship GANG + CIVILIAN first;
COP deferred (it needs an engine refactor, see below).

Shipped:

- Panel WORLD page, beside STREET IDLE: `BECOME NPC` (flag `bVCModNpcMode`, default
  off, ini `NpcMode`) and `NPC TYPE` (cycle `nVCModNpcType`, GANG ↔ CIVILIAN,
  default GANG, ini `NpcType`). Both kept out of the `aVCModSwitched` ALL-ON sweep
  (commands, not settings). Debug-menu tweaks added in `VCModTweaksWorld`.
- `VCModUpdateNpcMode(player, pad)` in `PlayerPed.cpp`, called beside
  `VCModUpdateStreetIdle` in `CPlayerPed::ProcessControl`. On → immediate handover
  to the same engine wander (`VCModStreetStartWander`), independent of the idle
  timer and the STREET IDLE switch. Reuses `bVCModStreetWander`, the
  `SetWanderPath` guard predicate and the two input-suppression points — no new
  engine seam.
- Input is ignored: `VCModNpcModeBreak` is hard-state-only (dead / in car /
  knock-down-or-arrest state / controls disabled). Walk/jump/weapon/duck never
  break it. A hard break suspends the walk; the command stays on and resumes once
  he is idle again. A 500 ms retry gap (`VCMOD_NPC_RETRY_GAP`) avoids per-frame
  node searches on pathless ground. Toggle off (edge-detected via
  `bVCModNpcModeWasOn`) ends the wander and returns control the same frame.
- Profiles: GANG = the plain shared wander (exactly a gang ped's walk). CIVILIAN =
  the wander plus the engine's `CPed::ScanForInterestingStuff` each frame while he
  walks (`Ped.cpp:1311`) — gawk, react to events, chat with passersby, 1:1. A
  reaction/chat that takes him out of the walk suspends the command's wander and
  it resumes when idle. The scan is a `CPed` method gated on in-control / objective
  none / not-mission; Tommy is `RANDOM_CHAR`, so it runs on him.
- `VCModUpdateStreetIdle` returns early while `bVCModNpcMode` is on, so the idle
  poses/chat/escalation never fight the manual mode. The command waits while he is
  sitting (`bVCModSitting`). The panel opens from `VCModPanelRender` (render loop,
  own key poll), so the menu stays reachable while he is an NPC.

Files: `vcmodpanel.h/.cpp` (flag, cycle, rows, tweaks), `core/re3.cpp` (ini load +
clamp), `peds/PlayerPed.cpp` (driver, break, statics, call site, stand-down). New
harness `utils/test_vc_npcmode.py` (12 checks). Panel-row trap handled: passenger
row count 52 → 54; the NPC-type cycle's four extraction markers added to the
character and adrenaline drivers (their `bool/int32` globals auto-extract by
regex, so no manual flag stub needed).

Verification: Release build green; full suite 155/155; installed into `~/Games/VC`
with no session running; the binary carries the `BECOME NPC` / `NPC TYPE` rows.
The freeze fix is played ("he walks"); the post-chat resume fix is not yet played
— walk feel, camera follow, the civilian reactions and the suspend/resume are the
user's to confirm.

## COP profile — deferred follow-up (not built)

The user correctly noted cops chase thief NPCs, not just the player. Verified:
`CCopPed::ProcessControl`'s idle-patrol block (`CopPed.cpp:527-569`) chases fleeing
criminal/gang NPCs (`OBJECTIVE_KILL_CHAR_ON_FOOT`, `bBeingChasedByPolice`) and
hassles wanderers (`OBJECTIVE_HASSLE_CHAR`) — none of it targets the player. The
player-arrest logic is separate (`CopAI`, wanted-driven). So a cop profile is
achievable: patrol + chase + hassle, minus arresting himself.

The cost (why it is deferred): that block lives in `CCopPed::ProcessControl`, which
Tommy does not run, and the hassle half uses `m_nHassleTimer`, a `CCopPed`-only
member (`CopPed.h:32`). The 1:1 plan (no copy that drifts): extract the patrol scan
into a shared `CPed` method that `CCopPed` also calls, preserving the original
early-exit via a bool return (`if (CopPatrolScan(&m_nHassleTimer)) return;`), plus a
mod-owned hassle timer for Tommy. The chase half uses only shared `CPed` state.
This touches stock cop AI, so it needs a harness proving the extracted block is
behavior-identical. Add `VCMOD_NPC_COP` as the third cycle state when built.

## Two BECOME NPC bugs — fixed in code, awaiting play

### 1. Freeze on toggle-on (fixed, played: "he walks")

Root cause: the player ped does not move like an NPC. An NPC translates via
`m_nMoveState` + `SetMoveAnim`; the player via `m_fMoveSpeed` +
`CPlayerPed::SetRealMoveAnim`, driven by the control switch in `PlayerPed.cpp`.
The first cut sat the whole frame out before that switch while wandering
(`if (bVCModStreetWander) return;`), so the engine set `PED_WANDER_PATH` and a
seek target but nothing set the player's speed or walk clip — he stood frozen
with `animDelta=0`. Confirmed with a temporary per-second probe (since removed).

Fix: removed the early-return and added a `PED_WANDER_PATH` case to the player
control switch (mirroring `PED_SEEK_POS`): set `m_fMoveSpeed` from `m_nMoveState`
and call `SetRealMoveAnim()`. The base `CPed::ProcessControl` still runs
`WanderPath()` for heading/seek. User confirmed he now walks.

### 2. Stands still after a civilian chat (fixed, not yet played)

User play-test: he walks and reacts, chats with a ped, then stands still after
the chat instead of resuming the wander.

Root cause: the civilian scan's `SetChat` stores `PED_WANDER_PATH` as the previous
state. The driver treats `PED_CHAT` as a hard state break and clears
`bVCModStreetWander`. When the engine chat ends, `ClearChat → RestorePreviousState`
(`Ped.cpp:822`) puts him back in `PED_WANDER_PATH` and calls `SetWanderPath` — which
bails on the player guard because the wander flag is already down. He is left
orphaned in `PED_WANDER_PATH` with the flag off, and the resume branch only fired
on `PED_IDLE`, so it never re-adopted him.

Fix: the not-walking resume branch in `VCModUpdateNpcMode` now accepts
`PED_WANDER_PATH` as well as `PED_IDLE`, so it re-issues `VCModStreetStartWander`
(flag up → `SetWanderPath` finds a fresh node) and re-adopts the orphaned walk.
New regression check `test_resumes_after_chat_restores_wander_state`.

## Faction membership — parked scope (user wants it, after the bug)

User confirmed all four behaviors: rivals hunt him, Vercetti treat him as kin, he
fights like a member, and look+voice. Voice tweak: voice follows the worn body; if
he is in his default Tommy body, use Tommy's own voice (not a gang voice). Approach
agreed in principle: keep `PLAYER1`, patch the gang-side AI decisions to treat him
as `GANG7` while the profile is on (NOT a ped-type swap — that flips 337 `IsPlayer()`
sites across 33 files). Hostility hinge is `CanBeDamagedByThisGangMember`
(`PedAI.cpp:6963`, `m_gangFlags` bitmask, only gates gang-shot damage in Weapon.cpp);
gang target-selection is scattered, so this is several patches + harnesses, and it
needs in-game iteration. Do not start until the post-chat resume fix is confirmed
in play.