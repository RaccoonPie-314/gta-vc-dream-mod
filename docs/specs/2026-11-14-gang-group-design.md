# BECOME NPC: gang group spawn and chatter (CALL GANG) — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `ff1f984`.
Status: design approved in chat 2026-11-14; pending spec review. Continues
`docs/specs/2026-11-14-body-type-banking-design.md` and
`docs/specs/2026-11-11-gang-faction-membership-design.md`.

## Goal

While BECOME NPC runs the GANG profile, one panel button (`CALL GANG`) spawns
one stock-shaped group of the player's own gang that he is part of: the stock
walking formation (he leads it) or the stock chatting circle (he takes a ring
slot). Walking up to an existing kin circle can pull him into its conversation.
Nothing spawns when the mode engages, and existing world groups keep their stock
spawn and chatter.

## Decisions (approved in chat, 2026-11-14)

- One panel row, one press = one group. No auto-spawn on engage, no hotkey.
- The player is part of the group: leader of the formation, one ring slot in
  the circle.
- The stock split (1/3 formation, 2/3 circle) and the stock 3–6 size roll.
- The player's circle pair uses the stock pedestrian-meet length (10–14 s); the
  NPC pairs keep the stock cluster's 100 s.
- One active group at a time; a press while it is out refuses with a notice.
- Existing kin circles are joinable by walking up, using the stock chat radius,
  roll and cooldown. Rival circles stay hostile-only.
- World groups, rival reactions and stock chatter stay as they are; no code
  changes there.

## Current behaviour (verified in the tree)

### The GANG profile is a solo wanderer

- `VCModGangEffectiveType` reports the player as his worn gang while the GANG
  profile runs (`vcmodgang.cpp:22`), and `VCModNpcGangType` derives that gang
  from the body or the manual GANG7 (`vcmodnpc.cpp:166`).
- `VCModNpcBorrowIdentity` borrows the gang's fear flags, stat and kin mask;
  `m_gangFlags` clears only his own gang's bit (`vcmodnpc.cpp:362`, `:393`).
- The gang profile runs the shared civilian layer, `ProcessObjective` and the
  attractor layer on the player (`vcmodnpc.cpp:665-680`).
- `VCModNpcReleasePed` clears chats, objectives, waits and paths on toggle-off
  and break (`vcmodnpc.cpp:443`).

### Kin chat already works for walkers

- `WillChat` returns true on equal effective gang before any body/bank check
  (`Ped.cpp:1432`); the player's body bank gate only applies to non-kin
  (`Ped.cpp:1441-1449`).
- The stock chat roll runs for the player because the gang branch calls
  `ProcessCivilianState` (`Ped.cpp:1397-1419`): both peds walking, within
  1.8 m, in sight, `WillChat` true, 50% roll and `m_chatTimer` gate, then
  `SetChat` both ways for 10–14 s (`Ped.cpp:1407-1409`).
- `Chat()` runs the stock pair cycle: face the partner, say `SOUND_PED_CHAT`
  with the `idle_chat` gesture, end on the partner-state change or the timer
  (`Ped.cpp:7872`, `:7888`, `:7931`). `ClearChat` restores the previous state
  (`Ped.cpp:7938`).
- Gang voice banks carry chat clips; the player's own `MI_PLAYER` bank does not
  (`AudioLogic.cpp:5448-5449`, `:7795`; voice-bank reference).
- The NPC layer already re-adopts the player after a chat ends: `ClearChat`
  restores `PED_WANDER_PATH` and the layer re-issues the wander on `PED_IDLE`
  (`vcmodnpc.cpp:715-727`).

### Stock group spawn (population)

- `CPopulation::PlaceGangMembers` rolls 1/3 formation, 2/3 circle
  (`Population.cpp:1429-1436`) with 3–6 members (`:1363`), spawned 40–50 m from
  the player in gang zones (`:615-646`), out of view.
- Formation: a spawned leader wanders and each member gets `SetLeader`,
  `SetFormation`, `OBJECTIVE_FOLLOW_CHAR_IN_FORMATION` and a formation position
  (`Population.cpp:1439-1507`).
- Circle: members stand on a ring, face its centre, are paired
  `j <-> pedIdx-1-j` with `SetChat(..., 100000)` (`Population.cpp:1596-1599`);
  an odd middle member gets `PED_UNKNOWN` facing slot 0 (`:1602-1610`); slot 0
  takes `bIsLeader` and the rest are linked to it (`:1611-1614`).
- Spawn fields: `CPopulation::AddPed` creates a `CCivilianPed` with the gang's
  stock weapon (`Population.cpp:420`, `:464-483`); `CharCreatedBy` stays
  `RANDOM_CHAR`; the clump starts at alpha 0 and ramps +16 per frame in
  `CPed::ProcessControl` (`Ped.cpp:2419-2433`).
- The population cull iterates the whole ped pool and removes eligible random
  peds by distance (`Population.cpp:1080-1160`); the counts move in the ped
  constructor/destructor (`Ped.cpp:377`, `:413`).
- Model choice: `CGangs::ChooseGangPedModel` over the two models set in
  `CGangs::Initialise` (`Gangs.cpp:23-40`, `:74`). GANG7 is `PGA`/`PGB`.

### What walking up to existing groups does today

- Kin walkers open the stock chat as above; a kin circle ignores the player,
  because its members are in `PED_CHAT` and the stock roll only considers
  `PED_WANDER_PATH` peds. Bumping a member can end that pair (the partner-state
  check at `Ped.cpp:7888`).
- A kin formation follows its own leader and does not chat.
- Rival flags register through the effective type in `ScanForThreats`
  (`Ped.cpp:869-878`), so rival circles break their chat and attack.
- Attacking kin: bullets require different effective gangs (`Weapon.cpp:1405`);
  melee keeps the stock 1/32 random pass (`Weapon.cpp:529`). Kin do not rally
  against the player (GANG7 guard at `PedAI.cpp:5478-5481`; the player's raw
  `PLAYER1` flag in the rally loop). The player cannot be hurt by kin
  (`PedAI.cpp:6999-7002` with the borrowed mask).
- Being attacked rallies kin: `ReactToAttack` calls
  `RegisterThreatWithGangPeds` (`PedAI.cpp:2203`).

## Design

### Panel row

- New row kind `VCMOD_ROW_GANGGROUP` in `vcmodpanelinternal.h`.
- Row `CALL GANG` on the WORLD page, directly after `TYPE FROM BODY`.
- Value cell: `[--]` when idle, `N men` while a group is active; row style off
  while idle, on while active.
- Click dispatches to `VCModGangGroupCall()` (`vcmodpanel.cpp`, beside the
  `CALL CREW` case). No ini key and no hotkey row.
- `README.md` toggles table gains the row.

### Gate and notices

- Requires `bVCModNpcMode && VCModNpcGangActive()`, the player on foot, alive
  and in control.
- Every refusal is a HUD notice plus one log line, never a silent no-op:
  - `gang: become a gang first` (mode off, or CIVILIAN/COP profile)
  - `gang: get out first` (in a vehicle)
  - `gang: the models cannot be loaded`
  - `gang: no room here` (fewer than two members could be placed)
  - `gang: already here` (a group from this row is still active)
  - success: `your gang is here`
- Log lines use the plain `fprintf(stderr, "VCMOD gang group: ...")` style the
  street layer uses, so they are in `reVC.log` without DIAGNOSTICS.

### Gang and models

- Gang type: `VCModNpcGangType(player)` — manual GANG gives GANG7; TYPE FROM
  BODY gives the worn body's gang.
- Gang index: `type - PEDTYPE_GANG1`; models from
  `CGangs::ChooseGangPedModel`.
- Request both gang models, `LoadAllRequestedModels(false)`, then require both
  `HasModelLoaded`; the streaming pattern follows the crew
  (`vcmodcrew.cpp:352-366`).

### Spawn shape

One roll per press, stock values:

- `GetRandomNumberInRange(0.f, 1.f) < 0.333f` -> formation, else circle
  (`Population.cpp:1431`).
- Member count `ComputeRandomisedGangSize()` (3–6, `Population.cpp:1363`),
  counting the player.

### Circle

- `n` = member count; radius `sqrt(0.5f / (1.0f - cos(TWOPI / n)))`, the stock
  formula.
- Centre = the player's position plus his forward times the radius, ground
  corrected. The player is slot 0 at his current position; he is not moved.
- Members fill slots 1..n-1 on the stock angle-and-jitter pattern (the stock
  loop's per-slot `angleMult` and `randomR` jitter), each ground checked and
  clear for a ped; a failed slot is skipped. Require at least two members.
- Each member: `CPopulation::AddPed(gangType, model, pos)`, rotation toward the
  centre, clump alpha 0. No leader link is written: `PED_CHAT` never uses it and
  a player `bIsLeader` would be residue. (The stock code sets those fields; for
  this spawned scene they change nothing.)
- Pairing as stock: slot `j <-> n-1-j`, `SetChat` both ways
  (`Population.cpp:1598-1599`). The player is slot 0 and pairs with slot n-1:
  - the player's pair: the stock pedestrian-meet length,
    `GetRandomNumber() % 4000 + 10000` (`Ped.cpp:1407`), so he is not locked
    for the cluster's 100 s;
  - every NPC pair: `100000` as stock.
- Odd `n`: slot `(n-1)/2` is the stock middle — heading toward the player,
  `PED_UNKNOWN`, no look target (`Population.cpp:1602-1610`).
- Voice stays stock: a gang body speaks; `MI_PLAYER`'s turns are silent
  gestures because his bank has no chat clip.

### Formation

- The player is the leader; `n-1` members (2–5).
- Each member: `AddPed` at the player's position, `SetLeader(player)` (which
  sets the player's `bIsLeader`; clear it back immediately), `SetObjective(
  OBJECTIVE_FOLLOW_CHAR_IN_FORMATION, player)`, `SetFormation((eFormation)i)`
  for i = 1..n-1, ground and line-of-sight check on the formation position,
  then `SetPosition`; rotation toward the leader; clump alpha 0. This mirrors
  the stock member block (`Population.cpp:1461-1495`) with the player in the
  leader slot.
- The player keeps his own wander; the followers trail it through
  `UpdateFromLeader` inside `ProcessObjective` (`PedAI.cpp:790-796`).
- Require at least two members; on failure remove what was made and refuse.

### Active-group tracking

- Up to six member pointers in a static array, each registered with
  `RegisterReference` so deletion nils it.
- The group is active while any tracked member is alive (not dying or dead); a
  press while active refuses. A press that finds only corpses tracked releases
  those references (`CleanUpOldReference`), clears the array and proceeds. No
  dismiss, no mod removal: the members are ordinary `RANDOM_CHAR` peds and the
  population culls them by distance.
- The row value is the number of live tracked members; the row is pressable
  exactly when that count is zero.

### Lifecycle and residue

- On NPC mode off and on every break (car, death, arrest, controls taken) the
  feature unlinks what it made: for each tracked formation member still valid,
  `SetLeader(nil)`, clear the follow objective, and `SetWanderPath(random 0..7)`
  if in control; circle members are left to the stock chat (their pair ends on
  the stock partner/timer rules). The tracking array is cleared.
- The player's `bIsLeader` is false after every press and every unlink.
- No save data changes: the members are random peds, not saved.

### Join an existing kin circle

- Runs in the GANG branch of `VCModUpdateNpcMode` (`vcmodnpc.cpp:665-680`), so
  the feature stays in mod files; no engine edit.
- While the player is walking (`PED_WANDER_PATH`, no objective) and the stock
  chat gates allow it, the same 50% per-frame roll, 200 ms back-off and
  `m_chatTimer` gate as the stock loop apply (`Ped.cpp:1397-1419`).
- Candidate: a kin ped near the player (1.8 m, in sight) that is either
  - the stock unpaired middle of a kin circle: `PED_UNKNOWN`, no ped look
    target, or
  - a member of a kin pair: `PED_CHAT`, whose look target is a ped in
    `PED_CHAT` of the same effective gang.
  Preferred order: the unpaired middle first, otherwise the nearest pair
  member. `WillChat`'s surface and road gates apply
  (`Ped.cpp:1421-1432`).
- Join: `SetChat` both ways with the stock meet length (10–14 s). When a pair
  member is taken, its old partner gets `ClearChat` and the stock chat-end gap
  (`m_chatTimer = now + 30000`, `Ped.cpp:7931-7936`); the rest of the circle
  keeps chatting.
- The player starts from a normal walking state; `SetChat` stops him and faces
  him like the stock chat. His turns follow the body's bank rule.
- Rival circles never match (different effective gang) and stay hostile-only.
  Civilian and mall groups never match (different effective type).
- After the chat ends, the stock 30 s cooldown on the player governs the next
  join.

## What stays stock

- World group spawn, shapes, sizes, chatter and cull.
- Rival hostility, cop pursuit, friendly-fire and threat gates.
- Kin walker chats and the stock 10–14 s pair cycle.
- All effects on non-player peds.

## Edge cases

- Facing a wall, a crowded pavement or a slope: slots fail, the partial group is
  removed, `gang: no room here`.
- Model streaming unavailable (interior, memory pressure): refuse, row stays
  pressable.
- Body changed mid-mode with a group out: the group stays the old gang; a new
  press refuses until it is gone. A later press uses the new gang.
- Player with `MI_PLAYER`: the circle includes him and the group chats; his
  turns are silent. The formation works the same.
- Mode off / death mid-circle: the player's pair ends through the release
  `ClearChat`; the NPC pairs continue stock.
- The join does not run while the player is in a chat, an objective, a vehicle,
  a mission/controls lock, or inside the post-chat cooldown.

## Testing

- New `utils/test_vc_ganggroup.py` following the brace-extract pattern
  (`utils/vcmod_test_support.py`):
  - gate truth table (mode off, CIVILIAN, COP, in car, dying);
  - gang derivation (manual GANG7, worn GANG1..GANG6);
  - size and shape roll bounds;
  - circle slot/pairing maths, the player's slot, the middle rule, the pair
    times;
  - formation member fields and the cleared `bIsLeader`;
  - join candidate selection (middle first, pair second, displaced partner
    cooldown, rival/civilian rejected);
  - no player position write.
- Update `test_vc_panel_info.py` row counts for the new WORLD row.
- Full suite, `scripts/build.sh`, install only with the game stopped
  (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty).
- In-game matrix:
  - Cuban body in Little Havana: circle press (he joins the conversation and
    the group speaks), formation press (the group trails his wander), walk-up
    join at a stock kin circle, repeated presses refused, mode off mid-group
    releases the followers.
  - Rival body: a rival circle stays hostile-only; no join.
  - Tommy body: circle and group speak, his turns silent; formation trails.
  - World groups still spawn and chat in gang zones.

## Out of scope

- Automatic spawn when the mode engages.
- Any change to rival, cop or civilian groups.
- Stock gang weapons or a gang loadout for the player.
- A dismiss/cleanup action for the group.
- A hotkey row or ini key for the button.

## Open play checks (assumptions)

- The player's stock pair cycle animates correctly in a circle pair (the street
  layer plays `ANIM_STD_CHAT` on him, `vcmodstreet.cpp:342-353`).
- Formation followers track the player's NPC wander without fighting the
  stroll speed (the crew's followers use the same objective with an NPC
  leader).
- A kin circle's chat breaks and re-forms around the join without a pose snap.
