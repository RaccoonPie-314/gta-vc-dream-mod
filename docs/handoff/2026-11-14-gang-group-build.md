# Handoff: CALL GANG — implementation, build 547

Date: 2026-11-14
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `ff1f984` (unchanged; nothing committed)
Installed: `vcmods build 561` in `~/Games/VC/reVC.app` (game stopped for every install)
Docs: the spec `docs/specs/2026-11-14-gang-group-design.md` (status updated), the plan
`docs/plans/2026-11-14-gang-group.md`, this handoff
Harness: `utils/test_vc_ganggroup.py` (21 tests), full suite green

## Session result

The approved CALL GANG feature is implemented, built, tested and installed. Nothing is
committed. The feature has not been played yet; the in-game matrix below is the next step.

What exists now:

- `src/extras/vcmodganggroup.cpp/.h` — the whole feature in one module:
  - gate truth table (`become a gang first`, `get out first`, `not now`, `already here`);
  - the stock shape/size roll (1/3 formation, 2/3 circle, 3–6 counting the player);
  - formation placement (`SetObjective FOLLOW`, `SetFormation`, ground/LOS/1 m checks,
    `SetPosition`, face-the-leader rotation, clump alpha 0, then `SetLeader(player)` and
    `player->bIsLeader = false`);
  - circle placement (ring radius from the stock formula, centre = player + forward·R,
    player fixed at slot 0, stock sector/jitter slots, ground/clear/LOS per slot, stock
    outward-facing rotation);
  - stock pairing `j ↔ n-1-j`, the player's pair at the pedestrian-meet 10–14 s, NPC
    pairs at `100000`, odd-ring middle `SetHeading` toward the player + `PED_UNKNOWN`;
  - tracking array (6 refs, `RegisterReference`), corpse pruning on press, `N men` cell;
  - release on mode off / break / profile switch (followers: `SetLeader(nil)`,
    `ClearObjective()`, `SetWanderPath(random)`; circle members left to the stock chat);
  - the walk-up join: stock 50% roll + 200 ms back-off + `m_chatTimer`, candidate scan
    (kin, `WillChat`, 1.8 m, both ways in sight), middle first then nearest pair member,
    displaced partner `ClearChat()` + 30 s gap.
- Panel: `VCMOD_ROW_GANGGROUP`, WORLD row `CALL GANG` directly after `TYPE FROM BODY`,
  click dispatch next to `CALL CREW`, value `[--]`/`N men`, debug-menu entry `call gang`.
  No ini key, no hotkey.
- `vcmodnpc.cpp`: release on the mode-off edge, `VCModGangGroupUpdate(player, pad)` once
  per mode frame (before the profile branch), `VCModGangTryJoinCircle(player)` in the GANG
  branch right after `ProcessCivilianState`.
- `README.md` toggles table row.
- Harness coverage: shape maths, gate table, gang derivation, formation setup + leader
  flag, join kind/pick/action, circle pairing + middle, source-shape checks (no player
  position write, stock calls, no mission ownership, notice strings), NPC hook placement.
- `utils/test_vc_npcmode.py` gained counted stubs for the three new hook symbols (a new
  symbol used by an extracted function must be in the stubs).
- `utils/test_vc_panel_info.py` gained the CALL GANG row test; the row floor moved 56 → 61.

Deviations from the spec, recorded:

- Added the notice `gang: not now` for the dead / not-in-control refusal the spec gates on
  but does not name. The design's "never a silent no-op" rule requires a notice.
- The formation members face the leader (spec); stock leaves their spawn orientation.
  The circle's rotation is the stock one (face the ring centre), which the spec calls
  "toward the centre".
- `Release` clears `player->bIsLeader` only when the released group was our formation, so
  another feature's leader role is never clobbered by an empty or circle release.

## Concurrent session in the same tree

While this session ran, another session was editing the same checkout (uncommitted):

- `INFINITE AMMO` row + `AMMO KEY` + `src/extras/vcmodammo.*`, `Weapon.cpp`,
  `vcmodkeys.*`, `PlayerPed.cpp`, `Frontend.*`, `MenuScreensCustom.cpp`, `re3.cpp`,
  `utils/test_vc_ammo.py`, `utils/test_vc_keys.py`;
- `src/extras/vcmodsave.*`, `Script.cpp`, `Script3.cpp`, `Script8.cpp`, `Game.cpp`,
  `Pools.cpp`, `save/GenericGameStorage.cpp`, `save/PCSave.cpp`;
- `utils/test_vc_adrenaline.py`, `test_vc_character.py`, `test_vc_passenger.py` touched;
- the earlier uncommitted drivecam work is gone from the tree (not this session's doing).

**The installed build therefore also contains that uncommitted work.** It compiled and
the full harness suite passed at build time, but it is not this feature's play surface.
If a clean CALL GANG-only build is wanted, the tree has to be separated first.

## Verification run

- `cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done` — all green at the time
  of the build (48 harnesses).
- `scripts/build.sh` — `vcmods build 547`, then `vcmods build 549` after the follow-up
  animation fix (the same day's counter had advanced from other build runs).
- `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty before each `scripts/install.sh`.
- No git actions. No file under `~/Games/VC/`, `~/Games/VC-ai/` or
  `~/Library/Application Support/reVC/` was read-modified-written; no `uchg` file touched.
  The game was never launched by this session.

## Follow-up (same day): formation members played Tommy's animations

Play test 1 (build 547) spawned a formation (`formation out, n=4 placed=3` in `reVC.log`)
and the members walked and idled in Tommy's player animation set.

Cause: `CPed::SetMoveAnim` hands any follower whose leader is the player
`ASSOCGRP_PLAYER`, and only the crew was exempt (`!VCModCrewOwnsPed(this)`). CALL GANG's
formation sets `SetLeader(player)`, so the members fell into the borrow; the circle writes
no leader link and was not affected.

Fix (build 549):

- `VCModGangGroupOwnsPed(CPed*)` in the module: true for any tracked member.
- `CPed::SetMoveAnim`'s condition extended to
  `!VCModCrewOwnsPed(this) && !VCModGangGroupOwnsPed(this)`, so the members keep their
  model's stock gang set (the IDE gives `pga`/`pgb` `gang1`).
- `VCModGangGroupPairCircle` now logs `circle chats, the player paired for X.Xs` once per
  circle press: the direct evidence that the player entered the chatter.
- Harness: 23 ganggroup tests (owns-ped, the engine condition), crew harness gained a
  CALL GANG follower case plus the new stub; full suite green; build 549 installed.

How the player enters the chatter (the play question from this round): the mode wandering
does not have to be interrupted by walking into the ring. The press itself calls the stock
`SetChat(player, member, 10–14 s)` both ways, which is `PED_CHAT`: he stops wandering, turns
to the ring partner, plays the stock chat cycle (silent turns on `MI_PLAYER`), and when the
timer ends `ClearChat` restores the wander. The walk-up join does the same when he walks
into an existing kin circle.

## Follow-up 2: no circle ever spawned

Play test 2's log had five `formation out` and zero `circle out`, plus three quick
`no room here` presses. The roll was fine; the three refusals were circle attempts failing
placement. Cause: the circle's stock obstacle scan runs over peds and vehicles, and the
player — who holds slot 0 of the ring — sits one metre from the slots beside him, so those
slots were always blocked. Stock ignores the peds it has just created; the player is one of
the ring's own people but was not in the ignore list. With `n = 3` and `n = 4` that leaves
fewer than two places, so the press refused.

Fix (build 551):

- `VCModGangGroupRingObstacle(CEntity*, CPlayerPed*, CPed**, int32)`: the ring's own people
  (the player at slot 0 and the already-placed members) never block a slot. `PlaceCircle`
  uses it; `n = 3` and `n = 4` rings now place.
- The success notice names the shape, because only the circle chats:
  `your gang falls in behind you` (formation) / `your gang is talking` (circle).
  The spec's notice list is updated.
- Harness: 24 ganggroup tests (the ring-obstacle rule), full suite green, build 551
  installed.

Play check: press until the notice says `your gang is talking` (2/3 roll). He turns to his
ring partner and the group chats for 10–14 s; `reVC.log` confirms with
`VCMOD gang group: circle chats, the player paired for X.Xs`. A formation press never chats
by design — it walks with him.

## Follow-up 3: the circle scattered when the chatter ended

Play test 3: the chatter worked, but when it ended every member walked off in his own
direction. Cause: `CPed::RestorePreviousState` (Ped.cpp:817-821) hands a leaderless random
ped a random wander path when the chat ends. The spec deliberately wrote no leader link
into the circle, so nothing kept the men together.

Fix (build 553): deferred adoption, no link while the ring talks.

- `VCModGangGroupAdoptCircle`, called from the per-frame `VCModGangGroupUpdate` for a
  circle: a member whose chat has ended (`PED_IDLE`/`PED_WANDER_PATH`, in control) gets the
  stock follower setup (`SetObjective FOLLOW_CHAR_IN_FORMATION` + `SetFormation` slot +
  `SetLeader(player)`); the locked middle (`PED_UNKNOWN`) is adopted once no tracked member
  is still in `PED_CHAT`; a member in a reaction state waits for it to settle.
- A link bitmask (`nVCModGangGroupLinked`) records which members hold the player link, so
  `Release` unlinks exactly those (a man still chatting keeps the stock chat, as before) and
  clears `player->bIsLeader` only when our own links existed.
- The talk is untouched: the still-chatting pairs are not followers, so `UpdateFromLeader`
  cannot interrupt them.
- Harness: 25 ganggroup tests (adoption timing, the middle, reaction wait, no double link);
  full suite green; build 553 installed.

Expected in play: the player's partner joins him after the 10–14 s pair, the rest join as
their pairs finish (up to 100 s), and the middle joins when the ring goes quiet — after
that the whole circle trails him like the formation.

## Follow-up 4: the ring's talk is open-ended, the row breaks it

Play test 4: chatter and the follow-up after it work. The next decision from the
play-tester: the spawned ring's conversation should not time out at all; a menu input
ends it (NPC mode ignores the pad, so the menu row is the input), and all pairs in the
ring hold, not only the player's.

Fix (build 557):

- `VCModGangGroupPairCircle` starts every pair on the cluster's `100000` (the stock
  pedestrian meet no longer applies to the spawned ring).
- `VCModGangGroupHoldChat`, called every mode frame for a circle: every member in
  `PED_CHAT` gets `m_chatTimer = now + 2000`, and the player's clock is pushed out too
  only while his look target is a tracked member. `Chat()`'s own voice/gesture cycle keeps
  running; nothing about the talk is reimplemented.
- The CALL GANG row's second press while the ring talks runs `VCModGangGroupStopChat`:
  every open member pair and the player's pair `ClearChat` on the stock 30 s gap, notice
  `your gang moves on`, then the men adopt on the same press (the panel is open, so the
  mode update is not running) and follow as the player resumes his wander.
- The cell reads `N men talking` while the ring is open, so the row's second function is
  visible; the row info now says `call your gang; press again to stop the talk`.
- The walk-up join into a world circle keeps the stock pedestrian meet (10–14 s): only
  the spawned ring is held.
- Harness: 26 ganggroup tests (hold, menu break, the talking cell); full suite green;
  build 557 installed.

Note: while the panel is open the NPC mode update is skipped, so the hold does not run;
the nominal 100 s covers a normal panel visit. Close the panel to watch the ring and the
hold resumes.

Play check: press until `your gang is talking`, leave him in the ring — the talk never
ends on its own. Press CALL GANG again: the whole ring stops, the notice says
`your gang moves on`, he walks and the men fall in behind him.

## In-game matrix (next)

1. Cuban body, Little Havana, BECOME NPC on (TYPE FROM BODY on):
   - `CALL GANG` circle press: he stands in the ring, faces a partner, the group speaks,
     his turns are gestures (no chat bank), the chat ends in 10–14 s and he walks on; the
     NPC pairs keep talking.
   - `CALL GANG` formation press: the group trails his wander, waits at the 30 m leash,
     the group keeps the stock gang weapons/voices.
   - Repeated presses: `gang: already here` notice, no second group.
   - Walk up to a stock kin circle: the 50% roll pulls him into a pair (or takes the
     middle); the displaced member's old partner stops with the 30 s gap; the rest of the
     circle keeps chatting; after his chat, the 30 s cooldown blocks the next join.
   - Mode off mid-group: the followers walk off as random pedestrians, the circle pair
     ends, the row shows `[--]`.
   - Get in a car mid-group (script/mission): followers released, notice path not shown.
2. Rival body (e.g. Haitian in Cuban turf): a rival circle stays hostile-only, no join.
3. Tommy body: the group speaks, his turns are silent gestures; formation trails.
4. World groups still spawn and chat in gang zones.
5. Panel: row reads `[--]` idle, `N men` with a group out; pin cell stays blank.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Git on reVC: no commit, tag or push unless asked.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- The concurrent session's files listed above: not this feature's to edit or revert.

## Follow-up 5: the ring's talk still ended on its own

Play test 5: the talk still ended after a few seconds. The log showed the chat animation
alive for 6 s and hit reactions (HIT_L/HIT_R) in the same window, so the end was not the
chat timer.

Two causes, both the civilian layer pulling him out of `PED_CHAT`:

- `EnterVacantNearbyCars`: the mode's shared civilian state has `m_bLookForVacantCars`
  true (borrowed for the crime layer), and the call runs every frame in the GANG branch.
  A wish-listed parked car within 10 m hands him `OBJECTIVE_ENTER_CAR_AS_DRIVER` mid-talk;
  `ProcessObjective` then changes his state and the pair ends.
- An objective already in hand when the row was pressed (a seat, a car) does the same on
  its next objective tick.

Fix (build 559):

- `VCModGangGroupPlayerTalking(player)` — in `PED_CHAT` with a tracked partner.
- The GANG branch skips `EnterVacantNearbyCars` / `UseNearbyAttractors` while that is true;
  the rest of the civilian layer (threat reactions) still runs, so a fight can still end
  the talk (stock).
- The circle press clears an objective the player was already carrying before pairing.
- If the talk ever ends without the menu, the update logs one line —
  `the talk ended by itself (player state=N)` plus each member's `state=alive=` — so the
  next play test names the reason instead of guessing.
- Harness: 27 ganggroup tests (the engine gate), full suite green, build 559 installed.

## Follow-up 6: the talk still expired, plus pairing and split

Play test 6's log: the talk ended with the player in `PED_IDLE` and all members in
`PED_WANDER_PATH` — a calm, simultaneous clear, not a fight. Cause: the hold lived in
`VCModGangGroupUpdate`, which runs from the player's mode update; the panel blocks that
update, so with the panel open the pair clocks ran to their 100 s nominal and every pair
cleared together.

Fix (build 561):

- `VCModGangGroupTick` in `CGame::Process` (beside `VCModCrewUpdate`) holds the open pairs'
  clocks every global frame, so the panel can no longer starve them. The per-frame mode
  update keeps the break/release and the adoption.
- Per-person end logging: `member N left the talk (state=X)` and
  `the player left the talk (state=X)`, one line each, so any future end names the leaver
  and the state.
- Ring pairing is now a cross: slot j pairs with the one across (`VCModGangGroupPartnerSlot`),
  so a four-man ring reads A-C and B-D; an odd ring keeps the stock middle. The stock
  both-ends pairing is replaced for this spawned scene.
- The button favours the conversation: formation on a roll < 0.2 (20%), circle 80%. The
  success log now prints the roll (`... out, n=4 placed=3 (roll 0.93)`), so the split is
  visible. Stock world groups keep their own 1/3.
- Harness: 28 ganggroup tests (cross maths, the 0.2 split, the global-tick hook), full
  suite green, build 561 installed.

Answered in chat: the overlapping chat gestures are stock behaviour — each ped's `Chat()`
re-blends `idle_chat` at a random offset and says a line every couple of seconds with no
turn-taking. The street-idle layer replaces that cycle for the player's street chats; the
ring still uses stock `Chat()`. Turn-taking for the ring is a separate change if wanted.

## Next steps

1. Play the matrix above; the first two things to judge are circle framing at the press
   moment (the ring is 0.6–1.0 m in radius) and whether the player's stock chat cycle
   reads correctly on a non-Tommy body.
2. If the circle press refuses with `gang: no room here` in open street, check the slot
   obstacle scan (the player is not passed as an allowed obstacle) in `vcmodganggroup.cpp`.
3. Commit only when asked; the tree also holds the concurrent session's work, so a commit
   needs the user's scope decision first.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `ff1f984`, installed
> `vcmods build 561` in `~/Games/VC/reVC.app`. Read
> `docs/handoff/2026-11-14-gang-group-build.md` and
> `docs/specs/2026-11-14-gang-group-design.md`. CALL GANG is implemented in
> `src/extras/vcmodganggroup.cpp` (row on WORLD after TYPE FROM BODY, formation/circle
> spawner, tracking, release, kin-circle join); 549 exempted the members from the
> player-animation borrow, 551 fixed circle placement (the player no longer blocks his own
> ring slots) and names the shape in the notice, 553 makes each circle member fall in
> behind the player when his chat ends, 557 holds the spawned ring's talk open until the
> CALL GANG row is pressed again, 559 stops the civilian car-theft layer from pulling him
> out of that talk.
 Play the in-game matrix in the handoff and
> report what the circle framing, the player's chat turns and the walk-up join look like.
> Note: the tree also carries another session's uncommitted ammo/save work; do not revert
> or commit it. No git actions; game data and the `uchg` anim files stay untouched.
