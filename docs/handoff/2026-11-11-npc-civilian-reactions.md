# NPC mode: civilian reactions unblocked (MISSION_CHAR root cause) — built, awaiting play

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c` (no
commits made; git is the play-tester's). Continues
`docs/handoff/2026-11-11-npc-mode-full-ai.md`. The clean Release build was
installed into `~/Games/VC/reVC.app` with no session running; the Dock-pinned
`~/Games/VC/Vice City Mods.app` rebuilds and installs this tree on launch.

## The bug

Played the full-AI build: CIVILIAN Tommy "just walking, no chatter, no reactions."
A temporary probe showed the scan entering with `created=2` (MISSION_CHAR) and the
node/chat probes never firing.

Root cause: the player ped is created `MISSION_CHAR` (CREATE_PLAYER in
`src/control/Script.cpp`), and that flag is the master gate the civilian AI reads:

- `CPed::ScanForInterestingStuff` returns on `CharCreatedBy == MISSION_CHAR` — no
  chat, no gawking, no interesting-node reactions.
- `CPed::ScanForThreats` skips the `PED_FLAG_DEADPEDS` branch for MISSION_CHAR — no
  corpse reaction.
- `CPed::CivilianAI`'s gun/corpse/explosion branches divert MISSION_CHAR to the
  mission duck instead of the civilian flee/fight.

The mid-walk profile switch was never the cause; the flag is MISSION_CHAR however
the profile is engaged.

## The fix

- `VCModUpdateNpcMode` (`src/peds/PlayerPed.cpp`) borrows
  `CharCreatedBy = RANDOM_CHAR` while NPC-civilian Tommy is actually wandering
  (`VCModNpcCivilianActive() && bVCModStreetWander`). A terminal break, a profile
  change, or toggle-off restores `MISSION_CHAR`. This opens every civilian gate at
  once — the 1:1 approach, no per-gate patches. Gang/cop keep the mission flag.
- Deletion safety: `CPed::CanBeDeleted` and `CanBeDeletedEvenInVehicle`
  (`src/peds/Ped.cpp`) now return false for `IsPlayer()`. The pool-full cull
  (`CPopulation::RemovePedsIfThePoolGetsFull`) is the only deletion caller that does
  not test IsPlayer at the call site, so the guard lives at the source. Every other
  caller already guarded IsPlayer.
- Two event reactions guard `IsPlayer()` directly and were lifted under
  `VCModNpcCivilianActive()` (`src/peds/PedAI.cpp`): `ReactToPointGun` (hands-up /
  cower) and `ReactToAttack` (fall through to the civilian flee/duck/fight instead
  of the player-only inform-gang path). Added the `vcmodpanel.h` include there.
- A profile switch reloads the civilian state: `nVCModNpcStateProfile` tracks the
  profile the state was initialised for; init moved into the civilian dispatch so
  GANG→CIVILIAN mid-walk re-inits without a manual off/on. This is the lightweight
  form of the play-tester's "restart on switch" idea.
- All temporary probes removed (scan entry/nodes/chat in Ped.cpp, the npc-mode
  probe in PlayerPed.cpp). Removed a duplicate `vcmodpanel.h` include in Ped.cpp.

## Files

Modified: `src/peds/Ped.cpp`, `src/peds/PedAI.cpp`, `src/peds/PlayerPed.cpp`,
`utils/test_vc_npcmode.py`.

## Verification

Release build green; full suite 176/176 (`test_vc_npcmode.py` now 23 checks,
including the flag flip per profile, off-edge restore, terminal-break drop,
profile-switch reload, and the civilian threat flags). Installed into
`~/Games/VC`. NOT yet confirmed in play.

## Round 2 — threat flags + blocked-ped stamina (after first play)

Played round 1: chatter works. Three follow-ups:

- **Corpse/gun/explosion reactions still dead.** PLAYER1 has no `Threat` line in
  `data/ped.dat`, so `m_fearFlags = CPedType::GetThreats(PLAYER1) = 0` and
  `ScanForThreats` skipped every branch even with RANDOM_CHAR. Fix:
  `VCModUpdateNpcMode` also borrows `m_fearFlags = GetThreats(PEDTYPE_CIVMALE)`
  (GUN|EXPLOSION|DEADPEDS) while civilian-wandering, restores the player's own
  (zero) otherwise and on toggle-off. `EVENT_DEAD_PED` registers on any death, so
  the event side was fine. The native dead-ped event lives ~1000 ms — reactions
  fire on a fresh kill nearby (stock window).
- **3-way chat is stock, kept.** `SetChat` does not check the partner is already
  chatting; `CPed::Chat` only checks the partner is in `PED_CHAT`, not that they
  chat with you. Native looseness; 1:1 keeps it. No change.
- **No tired/knee-grab + look-about when blocked.** `CPlayerPed::SetRealMoveAnim`
  never sets `m_nStoredMoveState` (the NPC `SetMoveAnim` does), so the blocked-ped
  `m_panicCounter` (Ped.cpp ~2436, needs WALK/RUN/SPRINT) never reached
  `WAITSTATE_STUCK`. Fix: sync `m_nStoredMoveState = m_nMoveState` in the player's
  `PED_WANDER_PATH` and `PED_SEEK_POS` control cases. Downstream already works for
  the player (`bIsStuck` physics, `m_fDistanceTravelled`, `Wait()`, and
  `SetWaitState(WAITSTATE_STUCK)` → PEDMOVE_STILL → tired/roadcross anims).

Round-2 files: `src/peds/PlayerPed.cpp`, `utils/test_vc_npcmode.py`.

## Round 3 — tired pose + reaction-state movement (after probe play)

Probe evidence: threat scan has DEADPEDS fear flag and RANDOM_CHAR (rounds 1-2 effective), but
`CheckForDeadPeds` finds an event in only ~1/176 samples — the native `EVENT_DEAD_PED` lives ~1000 ms
(stock window). The one corpse detection was at 1.8 m → flee. The react-move probe caught
`PED_FLEE_ENTITY` with `m_fMoveSpeed=0, vel=0`: he entered the reaction but did not move.

- **Tired/knee-grab when stuck:** `SetRealMoveAnim` swapped `IDLE_TIRED`→`IDLE`; the NPC `SetMoveAnim`
  guards it during `WAITSTATE_STUCK`/`WAITSTATE_FINISH_FLEE`. Wrapped the player swap in the same
  guard. Confirmed working in play.
- **Flee/investigate stood still:** the player control switch had no movement drive for reaction
  states (FLEE grouped with input-driven idle; INVESTIGATE empty default). Added a
  `PED_FLEE_POS/PED_FLEE_ENTITY/PED_INVESTIGATE` case driving `m_fMoveSpeed` from `m_nMoveState` +
  `SetRealMoveAnim` under `bVCModNpcMode`, falling through to the idle group otherwise (normal play
  unchanged). Same class as the wander freeze. Unplayed.
- **Investigate is stock-suppressed when the killer is within 10 m of the body** (<5 m → flee). To
  see it: kill a ped from >10 m so Tommy is >5 m from the body and the killer is far, or watch a death
  whose killer leaves. NPC-caused deaths usually keep the killer near.

Round-3 files: `src/peds/PlayerPed.cpp`, `utils/test_vc_moveanim.py` (stub wait-state). Probes still
present (`VCMOD threat`, `VCMOD civ layer`, `VCMOD corpse`, `VCMOD react move`) — strip before ship.

## Next steps (play-test)

1. CIVILIAN: chat with passersby, gawk, panic/flee at gunshots/explosions,
   investigate a fresh corpse, hands-up when a gun is pointed, flee/fight when
   attacked. Confirm he resumes wandering after each.
2. Switch GANG→CIVILIAN mid-walk: reactions should start without toggling off/on.
3. Toggle off: control returns and Tommy is protected as the player again.
4. Native civilians/cops unchanged; Tommy is never culled when the ped pool fills.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` —
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).

## Session end state (2026-11-11)

BECOME NPC CIVILIAN/COP is feature-complete: full native AI 1:1, chat/gawk, corpse/gun/explosion
reactions, the stuck tired/look-about cycle, sitting, bump reaction. Confirmed in play: chatter,
sitting, bump, tired pose. Built/installed but **unplayed**: the reaction-state movement fix
(flee/investigate now translate). Probes still in `Ped.cpp`/`PlayerPed.cpp` (`VCMOD threat`,
`VCMOD civ layer`, `VCMOD corpse`, `VCMOD react move`) — strip after a final play confirm.
Probe evidence saved to `docs/handoff/2026-11-11-npc-probe-evidence.md`. Build green, suite 176/176.

## Next feature — gang faction membership (the GANG profile)

Make Tommy a real Vercetti (GANG7) member when the GANG profile is on — attacking/defending and
the full social loop. Confirmed scope (four behaviors):

1. Rival gangs hunt him on sight.
2. GANG7 treat him as kin: no attack, chat, backup.
3. His own AI fights rivals like a member (attack + defend).
4. Look + voice the part. Voice follows the worn body; in his default Tommy body use Tommy's own
   voice, not a gang voice.

Approach decision (confirmed): keep `PLAYER1` — a ped-type swap flips `IsPlayer()` at ~337 call
sites and strips player protection everywhere. Instead patch the gang-side AI decisions to treat
him as GANG7 while the profile is on. Key hinges located:

- `CPed::CanBeDamagedByThisGangMember` (`PedAI.cpp:6964`) — `m_gangFlags & (1 << (who->m_nPedType
  - PEDTYPE_GANG1))`; only gates gang-shot damage, not target selection.
- Hardcoded GANG7+IsPlayer protections: `PedAI.cpp:2156` (ReactToPointGun), `2237` (ReactToAttack),
  `5446` (attack decision).
- `CPed::InformMyGangOfAttack` (`PedAI.cpp:5972`) — gang backup call.
- Gang target-selection is scattered across `IsGangMember()` checks; needs investigation.

First step: investigate where gangs pick enemies / decide to attack the player and how
`m_gangFlags` is set, brainstorm the approach, write a plan, then implement incrementally with
harnesses and in-game iteration.

## Paste-ready prompt (gang faction)

> Starting the gang-faction feature in `vc-mod` (reVC/, branch vcmods, HEAD 8d57f7c, all
> uncommitted; git is mine — never commit/push). BECOME NPC's CIVILIAN/COP profiles are done
> (full native AI 1:1); the GANG profile is currently a plain wander. Make Tommy a real Vercetti
> (GANG7) member when GANG is on: rival gangs hunt him on sight, GANG7 treat him as kin (no
> attack, chat, backup), his own AI attacks and defends against rivals like a member, and he
> looks/voices the part (voice follows the worn body; default Tommy body keeps Tommy's voice).
> Confirmed approach: keep PLAYER1 (no type swap — it flips IsPlayer at ~337 sites) and patch the
> gang-side AI to treat him as GANG7 while the profile is on. Hinges: CanBeDamagedByThisGangMember
> (PedAI.cpp:6964, m_gangFlags), the GANG7+IsPlayer guards at PedAI.cpp:2156/2237/5446,
> InformMyGangOfAttack (5972), and the scattered IsGangMember() target-selection. Read
> docs/handoff/2026-11-11-npc-civilian-reactions.md and docs/handoff/2026-11-11-npc-probe-evidence.md
> first. Start by investigating gang target-selection and m_gangFlags, brainstorm the approach,
> write a plan, then implement incrementally with harnesses + in-game iteration. Leftover: the
> civilian reaction-movement fix is unplayed and four VCMOD probes are still in Ped.cpp/
> PlayerPed.cpp — strip them after a final confirm. Do not touch ~/Games/VC data or the uchg anim
> files (anim/cuts.img, cuts.dir, ped.ifp).