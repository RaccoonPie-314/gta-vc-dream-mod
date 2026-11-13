# Cop NPC profile: extraction, voice, ID check, walk — verified in play, build 397

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Installed `vcmods build 397` into `~/Games/VC/reVC.app` (no live session each
time). Every item below is confirmed in play ("all fixed now", 2026-11-12).

Crew work is unchanged. No commit, tag or push was made.

Previous round: `2026-11-12-crew-ride-style-and-pickup.md`.

## Final state

The COP NPC profile is complete for a wanted-0 world: patrol scan, chase and
combat, ID check with its voice and hold, cop voice by body, chats declined for
bodies without chat lines, the pedestrian blocked reaction, and a stable stroll
gait. What stays native-only is everything that targets the player (pursuit,
arrest, crime scan, no-police zone, stingers, heli SWAT, patrol-car re-entry) —
with Tommy as the cop those would make him his own suspect.

Verified in play across builds 365-397: chase and shooting, ID check line and
the citizen's reply, the 1.2 s -> leave-timer hold, the tree escape, and the
walk no longer flickering.

### The obstacle fix, precisely (asked 2026-11-12)

Pathfinding is untouched — no nodes, path selection or seek changed. Two gates
were shut for a *player*:

- the blocked reaction is skipped unless `bIsStuck`, which only the player's own
  controls set; NPC mode never does, so he pushed into a tree until the seek
  gave up. `bVCModNpcMode` now lets him run the ped path (panic counter ->
  `WAITSTATE_STUCK` -> turn-away).
- the turn-away only rotated the body, and the stroll re-aims the heading at the
  path node every frame, undoing it. On that turn he now re-issues
  `SetWanderPath` with the opposite path direction, so he has a new node to
  walk to.

Both gates are mode-wide: GANG, CIVILIAN and COP profiles get them, normal play
does not.

## Play round 1 (build 365): accepted with two defects

The first play report: the COP profile works on the first attempt, pathing is
poor but not a problem, and two issues — the game crashed during testing, and
during a chase Tommy repeatedly "stops then continues, like refreshing the
objective". Both were traced to the same class of bug: the player override of
`CPlayerPed::ProcessControl` skips engine paths the native ped path relies on.

### Crash: nil seek target

`CPlayerPed::ProcessControl` crashed at `+0x2018`, `ldr w9, [x8,#0x40]` with
`x8 = this->0x4b0` (m_pSeekTarget) equal to nil. The `PED_SEEK_ENTITY` case
copied `m_pSeekTarget->GetPosition()` before any nil check.

The target was alive (play report: the chased crew member never despawned).
`CPed::SetAimFlag(float)` writes `m_pSeekTarget = nil` and leaves the state at
`PED_SEEK_ENTITY`; aim code reaches it through `PedFight.cpp:636/647`
(`SetAimFlag(m_fRotationCur)`) while attacking. Native `CPed::ProcessControl`
answers that exact case with `RestorePreviousState()`; the player copy had no
guard. Fixed by mirroring native: nil target → `RestorePreviousState()` and skip
the seek block.

### The mid-chase stop

Native `KillCharOnFootArmed` re-seeks only when the state is not `SEEK_*`, and
the seek completes at range/3 (~10 m). On arrival the state is restored, the
next objective tick reissues the seek — stop, then go. A native cop fills that
beat by *attacking*; the gang profile already hands `KILL_CHAR_*` combat to the
engine (`Attack()`, `Fight()`, `PointGunAt()`), but that gate read
`VCModNpcGangActive()` only, so the cop profile fell through to the
input-driven player path, which NPC mode never feeds. He stood in the aim beat
until the 1.5–3 s attack timer expired, then re-seeked.

Fix: the gate is now `npcCombatProfile = VCModNpcGangActive() ||
VCModNpcCopActive()` (and `npcCombatOwnsControl` for the idle/pause case), so a
cop chase fights with the engine's own attack code, as a native cop does. Side
effects to watch in play: he now actually fires during chases (this is what the
stop was waiting for), and cop mode owns `PED_ATTACK`/`PED_FIGHT`/`PED_AIM_GUN`
generally, so he fights back when attacked.

Pathing quality was reported as poor and expected; nothing was changed for it.

Two interactions noted in that round, neither changed:

- NEVER WANTED makes the bystander-hit consequence go away:
  `CWanted::SetWantedLevel` forces 0, the crime queue is cleared every update and
  `CPlayerPed::ProcessControl` resets a non-zero level each frame. With it on,
  the cop-mode patrol gate (`wanted == 0`) never closes, so he keeps patrolling
  after a chase.
- The crew is `PEDTYPE_GANG7` (`vcmodcrew.cpp:262`), so a cop-mode Tommy's
  patrol scan legitimately targets his own Vercetti crew. Native-consistent; the
  play report's chase target was exactly that.

## Play round 3: NPC-mode voice, chat stop, stroll run

Trace in `VCMOD wander:` (one line per state/move/wait/path/look/chat change)
showed the reported "chat attempt" was `obj=14`, which is
`OBJECTIVE_HASSLE_CHAR` — the cop ID check, not a chat. That explains the
approach, the turn and the walk-apart. The missing part was audio:

- `CPed::Say(uint16)` drops most speech while `TheCamera.m_CameraAverageSpeed`
  is above 0.9/1.25/1.65. For peds that rule mutes talk during camera pans; for
  NPC-mode Tommy the camera is his own viewpoint and moves with him, so every
  line he said while walking died there (chats, ID check). Bypassed while
  `bVCModNpcMode` is on and he is the player (`src/peds/PedChat.cpp`); stock
  peds and normal play keep the rule. `utils/test_vc_npcvoice.py` pins all four
  cases.
- A chase leaves `bIsRunning` set; `Seek()` turns that into RUN for every node
  of a plain stroll, so he jogged and the gait snapped. Cleared when a stroll
  starts (`VCModStreetStartWander`).
- `PED_CHAT` had no case in the player override, which owns `m_fMoveSpeed`, so
  a passer-by's chat left him walking away at his last speed. The case now
  zeroes speed and holds the stored move state.

Why the ID check was silent (probes `VCMOD talk:` / `VCMOD voice:`) and its
follow-up:

- Both reported lines reached the audio manager and came back as `NO_SAMPLE`
  (9942). Chat has no clips in cop/SWAT/FBI/army banks at all — those banks hand
  unknown sounds to the generic-male bank, which only covers death, grunt, fire
  and panic. A cop body cannot chatter in stock VC; a civilian body can.
- The ID line exists (`SFX_COP_VOICE_1_COP_ASK_FOR_ID_1`) but sat behind one
  global `cooldown_phrase(4)` counter shared by every cop in the world, so
  another cop's line could swallow the player's. The NPC-mode player bypasses
  the cooldown (`src/audio/AudioLogic.cpp`), stock cops keep it.
- The interaction ended too early: the hassle completion sets
  `m_leaveCarTimer = now + 3000` on both peds and switches them to
  `OBJECTIVE_WANDER`; the mod's idle→stroll re-adopt fired in the same frame, so
  he turned and walked off before the line played. The command now holds the
  stroll 1.2 s after a completion (`VCMOD_NPC_IDCHECK_HOLD`), facing the ped the
  objective left in his look target. `utils/test_vc_npcmode.py` pins the hold.
  The hold alone was not enough: the completion also switches him to
  `OBJECTIVE_WANDER`, whose path starts by itself, and the completion can land
  in either `ProcessObjective` call (the base one in `CPed::ProcessControl` or
  the cop branch's). `VCModNpcIdCheckHold` now runs after both and clears the
  objective in the same frame the completion happens. The hold now ends on the
  completion's own leave timer (3 s, both peds), not a fixed 1.2 s, so the pair
  parts together as stock does.
- The citizen's answer never played: it is not the NPC-mode player, so the same
  camera gate dropped it while Tommy was still running. The two lines of that
  exchange (`SOUND_PED_INNOCENT`, `SOUND_PED_COP_ASK_FOR_ID`) are exempt while
  the mode is on; stock behaviour outside it is unchanged.
- Chat *audio* in a cop body is genuinely absent: the log shows sound 157
  (chat) resolving `NO_SAMPLE` (9942) every time, while 134 (ID) resolves 8548
  and 139 (cop bark) 3107 and do play. The chat interaction itself still
  happens (facing, gesture); only the voice clip does not exist for those
  bodies. Silent chat gestures are not stock: stock chats only pair two
  pedestrian peds, whose banks both carry chat clips, so gesture and voice
  always coincide. A cop body gesturing silently only happens when a civilian
  starts a chat with the cop-bodied player. Per the body-bank rule the engine
  now declines that chat: `CPed::WillChat` answers false for the police bodies
  and MI_PLAYER (1:1 with a stock cop, who cannot be chatted with).
- Obstacles: a pedestrian's blocked reaction is gated for players on `bIsStuck`,
  which only the player's own controls set, so NPC-mode Tommy stood at sidewalk
  trees until the seek gave up. The gate now lets the NPC-mode player run the
  ped path (panic counter → `WAITSTATE_STUCK`). The 180° escape also needed the
  stroll re-aimed: the player's heading is re-aimed at his path node every frame,
  which undid the raw turn and left him pushing into the tree. On that turn the
  NPC-mode player re-issues `SetWanderPath` with the opposite path direction.
  Both gates are `bVCModNpcMode`, so GANG/CIVILIAN/COP all get them; normal
  play is untouched.
- The walk flicker: `Seek()` re-decides his move state every frame, so it flips
  WALK/RUN/STILL and the per-frame table assignment snapped the speed and
  restarted the clip. `VCModNpcStrollGait` eases the speed toward the target and
  derives the gait from the eased value, so a one-frame STILL no longer breaks
  the walk (`utils/test_vc_npcwalk.py`).
- The ID-check approach is stock: `PedAI` sets `PEDMOVE_RUN` beyond 5 m and walk
  inside it.

Not explained yet: the remaining walk flicker. The trace still shows move state
and speed changing on consecutive frames while wandering (`WALK/RUN/STILL`,
speed `0.00/1.00/1.80`); native peds read the same state but ease their speed.
If it is still visible after this build, the fix is to ease the player's speed
between states instead of assigning the table value each frame.

## 1. The COP NPC profile was a no-op (build 365)

`CPed::CopPatrolScan` gated the scanner on `CharCreatedBy == RANDOM_CHAR`
(`src/peds/Ped.cpp:1993`), and the COP profile deliberately leaves Tommy
`MISSION_CHAR` (`src/peds/PlayerPed.cpp:1632`). Every call returned false. Even
a successful scan would have gone nowhere: the cop branch never called
`ProcessObjective`, so no chase or ID-check objective was ever serviced. The
npcmode harness stubbed `CopPatrolScan`, which is why it kept passing.

## 2. Agreed target rules

Reported before extraction, then confirmed:

- Share only the patrol scan (chase criminals and gang members, ID-check
  passers-by). Pursuit slots, arrest, `ScanForCrimes`, no-police stop-and-shoot,
  the `field_624` stuck counter, patrol-car re-entry, stinger and heli SWAT all
  target the player, so they stay native-only: with Tommy as the cop they would
  make him his own suspect or delete him (`FlagToDestroyWhenNextProcessed`).
- Native wanted gate: Tommy patrols only while his own wanted level is 0.
- Targeting line: only while he wears a police body (COP/SWAT/FBI/ARMY), since
  only those voice banks carry the clip. Tommy's own body and the Miami Vice
  bodies fall back to generic male and stay silent.

## 3. What changed

- `src/peds/Ped.cpp` — `CopPatrolScan`'s gate now reads
  `CharCreatedBy == RANDOM_CHAR || (IsPlayer() && VCModNpcCopActive())`. Random
  cops and their call site are untouched; Tommy stays `MISSION_CHAR`, so
  civilian, mugger and chat scans still skip him.
- `src/extras/vcmodpanel.h` — `VCModNpcCopActive(void)` declared next to the
  civilian/gang gates.
- `src/peds/PlayerPed.cpp` — the gate itself, and a cop branch that follows
  `CCopPed`'s order: `ProcessObjective()` always, then
  `CopPatrolScan(nVCModNpcHassleTimer)` when in control, not in `PED_AIM_GUN`
  and at wanted level 0, then the targeting line for a police body while a gun
  is pointed.

## Verification (offline, build 369)

- `utils/test_vc_cop_chase.py` (new) — 4 OK. Drives the real `PED_SEEK_ENTITY`
  case: the guard sits before the dereference, a vanished target clears the seek
  instead of reading nil, a live target copies the position and runs at 1.8 m/s
  with the stored move state, and arrival restores the state to STILL.
- `utils/test_vc_ganggaze.py` — 8 OK. The profile test now pins that gang *and*
  cop hand `PED_ATTACK` to `Attack()`, while the civilian profile and a plain
  player keep the input path. The gate slice follows
  `npcCombatProfile`/`npcCombatOwnsControl`.
- Round 1 harnesses still green: `test_vc_cop_patrol.py` 6 OK,
  `test_vc_npcmode.py` 28 OK.
- Every `utils/test_vc_*.py` harness OK (36 files). `test_vc_passenger.py` had
  failed once in an earlier full-sweep run on a missing
  `VCModPassengerReleaseAim` declaration and has since passed repeatedly; cause
  not established, watch for it.
- Clean build; installed binary carries `vcmods build 369`.

## Not verified

Play of build 369. What to look for: the chase no longer stops at the aim beat
(he fires instead), no crash during a long chase with criminals despawning, and
that his shooting during cop mode is acceptable.

## Uncommitted

The cop topic touched: `src/peds/PlayerPed.cpp` (profile gate, combat
ownership, seek guard, chat stop, ID-check hold, stroll gait, voice resets),
`src/peds/Ped.cpp` (patrol scan gate, chat decline by body, blocked-reaction
gate, stuck escape re-route), `src/peds/PedChat.cpp` (speech gate, voice
probes), `src/audio/AudioLogic.cpp` (ID-line cooldown, voice probe),
`src/extras/vcmodpanel.h` (profile gate), and the new/updated harnesses:
`utils/test_vc_cop_patrol.py`, `test_vc_npcmode.py`, `test_vc_npcvoice.py`,
`test_vc_npcwalk.py`, `test_vc_cop_chase.py`, `test_vc_ganggaze.py`,
`test_vc_wander.py`, plus stub updates in the harnesses those extract from.

The wider tree still carries the street-idle, lock-on, passenger, gang and
crew work from earlier handoffs. Nothing in the cop topic was committed.

Temporary diagnostics still in the build (all stderr, cheap, worth removing
with the commit that closes this topic): `VCMOD wander:`, `VCMOD talk:`,
`VCMOD voice:`, `VCMOD id line:`.

## Next steps

1. Remove the four temporary diagnostics above when this topic is committed.
2. Fight-back while wearing a cop body is still unevaluated: he keeps PLAYER1
   fear flags, so his threat reactions differ from a native cop's.
3. Cop-mode shooting during chases is accepted as of build 366-397; NEVER
   WANTED (COMBAT page) removes the bystander-heat consequence if it is not.
4. Still open, unrelated: the traffic stop-light deadlock (`reVC-traffic-mods`
   memory) and the crew's rails approach for its own car.

## Paste-ready prompt

Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 397.
Read `docs/handoff/2026-11-12-cop-behavior-extraction.md` first. The cop NPC
profile topic is finished and verified in play: patrol, chase/combat, ID check
(voice, reply, hold), body-bank voice rules, blocked-reaction and stroll gait.
Start the next session by removing the four temporary `VCMOD wander/talk/voice/
id line` diagnostics, then pick up the open items (cop fight-back parity, or a
new topic). Check the live session before any install; game data, settings,
savegames and the immutable animation files are read-only.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Never install while
`pgrep -f "reVC.app/Contents/MacOS/reVC"` returns anything. Crew ownership and
chat are unchanged by request; keep them so.
