# Gang faction: GANG profile = real Vercetti (GANG7) membership — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods` (upstream; no
branch/worktree/push here). Status: design, approved in chat, pending spec review.
Continues `docs/specs/2026-11-11-npc-mode-full-ai-design.md` and the handoff
`docs/handoff/2026-11-11-npc-civilian-reactions.md`.

## Goal

When BECOME NPC's GANG profile is on, Tommy is a real Vercetti gang (GANG7)
member, not a plain wanderer. Four behaviors, plus the confirmed cop consequence:

1. Rival gangs hunt him on sight.
2. GANG7 treat him as kin: no attack, chat, backup.
3. His own AI attacks and defends against rivals like a member.
4. He looks/voices the part: voice follows the worn body; the default Tommy body
   keeps Tommy's voice. No forced model swap.
5. (Confirmed 1:1) Cops patrol-chase him on sight, like any gang member.

The CIVILIAN and COP profiles are feature-complete and must stay unchanged.

## Why no type swap (confirmed)

`CPed::IsPlayer()` derives from `m_nPedType`; swapping the player to `PEDTYPE_GANG7`
flips `IsPlayer()` at ~337 sites across 33 files (camera, pad, wanted, missions) and
strips player protection everywhere. The player keeps `PLAYER1`. Instead the
gang-side AI decisions are patched to treat him as GANG7 while the profile is on —
the same "borrow what the AI reads, keep the type" pattern the civilian fix used for
`CharCreatedBy` and `m_fearFlags`.

## Ground truth (verified, not assumed)

Gang targeting is **not** `IsGangMember()` directly. It is
`m_fearFlags & CPedType::GetFlag(other->m_nPedType)` in `CPed::ScanForThreats`
(`Ped.cpp:848`). A gang ped hunts whoever its fear-flags name.

`data/ped.dat` (read-only install) threat table:

- Every rival gang (GANG1–6, 8, 9) lists **GANG7** in its `Threat` line. So a rival
  ped's `m_fearFlags` already contains `PED_FLAG_GANG7`; it hunts Tommy the moment
  he *reads as* GANG7 in its scan.
- GANG7's `Threat` line is `GUN GANG1 GANG2 GANG3 GANG4 GANG5 GANG6 GANG8 GANG9
  EXPLOSION` — exactly the other eight gangs, never itself. So
  `GetThreats(PEDTYPE_GANG7)` is the rival hate list; borrowing it makes Tommy's own
  scan hunt rivals and spare kin.
- `PLAYER1` has no `Threat` line → `GetThreats(PLAYER1) == 0` (why Tommy normally
  fears nothing).

Gang peds are created `CCivilianPed` (`Population.cpp:474`) and run
`CCivilianPed::ProcessControl` → `ProcessCivilianState()` + `CivilianAI()` +
(RANDOM_CHAR) `EnterVacantNearbyCars()` + `UseNearbyAttractors()`. The gang-specific
behavior lives in branches inside those shared routines. So the GANG AI layer is the
same dispatch the CIVILIAN profile already runs; only the borrowed fields differ.

Stock same-gang friendly-fire immunity comes from **type-equality checks**, not
`m_gangFlags` (gang peds carry `m_gangFlags == ~0`): melee `Weapon.cpp:526`
(`victim->m_nPedType != shooter->m_nPedType`) and bullet `Weapon.cpp:1400`. The
`m_gangFlags` gate (`CanBeDamagedByThisGangMember`, `Weapon.cpp:1103`) is a second
layer used by script gang wars.

## Mechanism — part 1: borrowed gang fields

While GANG-wandering (`VCModNpcGangActive() && bVCModStreetWander`), borrow in
`VCModUpdateNpcMode` (`PlayerPed.cpp:1575`), restored on terminal break, toggle-off,
and profile switch — the existing civilian restore machinery:

- `m_fearFlags = CPedType::GetThreats(PEDTYPE_GANG7)` — hunts rivals, spares kin.
- `m_pedStats = CPedStats::ms_apPedStats[PEDSTAT_GANG7]` — gang fear/temper/attack
  strength for his own decisions, and others read gang stats when targeting him.
  Save the pre-borrow pointer and restore it exactly (the player's stat is set only
  at construction, `Ped.cpp:481`; the selector does not change it).
- `m_gangFlags` with the GANG7 bit cleared
  (`~(1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1))`) — kin shots pass the
  `CanBeDamagedByThisGangMember` gate. Restore to the player's default `~0`.
- `CharCreatedBy = RANDOM_CHAR` — opens the gang AI gates (corpse threat branch
  `Ped.cpp:890` requires `!= MISSION_CHAR`; chat/interesting-stuff scans). Mirrors
  the civilian borrow. `CanBeDeleted`/`CanBeDeletedEvenInVehicle` already return
  false for `IsPlayer()`, so RANDOM_CHAR does not expose him to culling.

## Mechanism — part 2: effective gang identity

`m_nPedType` stays PLAYER1, so the shared gang reads use an effective identity:

- `CPed::IsGangMember()` (`Ped.cpp:8325`) becomes player-aware:
  `(m_nPedType in GANG1..GANG9) || (IsPlayer() && VCModNpcGangActive())`. This lights
  up every boolean gang gate at once — including cop patrol-chase (`CopPatrolScan`,
  `Ped.cpp:1974`), the chosen 1:1 consequence.
- New helper `VCModGangEffectiveType(CPed*)` (declared `vcmodpanel.h`, defined
  `vcmodpanel.cpp`, which already includes `Ped.h`/`PedType.h`): returns
  `PEDTYPE_GANG7` for the gang-profile player, else `ped->m_nPedType`. Substituted at
  the bit/index and type-equality reads below.
- New gate `VCModNpcGangActive()` (mirror `VCModNpcCivilianActive()`,
  `PlayerPed.cpp:1553`): `bVCModNpcMode && nVCModNpcType == VCMOD_NPC_GANG`.

### Patch set

| Site | Change |
| --- | --- |
| `ScanForThreats` GetFlag reads — `Ped.cpp:868`, `873` (shooter), `915` (near ped), `985` (driver) | `GetFlag(VCModGangEffectiveType(...))` → rivals see GANG7 (hunt), GANG7 see kin (spare) |
| `CanBeFriends` — `Ped.cpp:1427`, `1438` | effective type in the same-type / gang comparisons → kin chat eligibility |
| `CivilianAI` corpse same-type — `Ped.cpp:1559` | effective type → kin corpse behavior |
| `CanBeDamagedByThisGangMember` — `PedAI.cpp:6966` | bit index from `VCModGangEffectiveType(who)` |
| Melee friendly-fire — `Weapon.cpp:526` | effective type equality → Tommy and kin do not melee each other |
| Bullet friendly-fire — `Weapon.cpp:1400` | effective type equality → no kin bullet damage either direction |
| `RegisterThreatWithGangPeds` — `PedAI.cpp:5464`, `5487` | effective type for `this` → Tommy's threat call rallies nearby GANG7 (backup) |
| `ReactToAttack` player guard — `PedAI.cpp:2230` | also lift under `VCModNpcGangActive()` → gang fight/backup path, not the player-only `InformMyGangOfAttack` branch |
| `ReactToPointGun` player guard — `PedAI.cpp:2149` | also lift under `VCModNpcGangActive()` → gang gun reaction (`RegisterThreatWithGangPeds` via `IsGangMember`) |
| Stock GANG7+IsPlayer guards — `PedAI.cpp:2156`, `2237`, `5446` | **unchanged** — already spare the player; keep |

`IsGangMember()` going player-aware also covers the `IsGangMember()` boolean clauses
at `Weapon.cpp:528`/`1401`, `Ped.cpp:862` (scan gun path), `PedAI.cpp:2177`/`2277`
(register threat), `PedFight.cpp:4218` (carjack threat) without separate edits.

## AI layer dispatch

Add a GANG branch in `VCModUpdateNpcMode`'s wander block, mirroring CIVILIAN:
`ProcessCivilianState()`; if `IsPedInControl()` then `CivilianAI()`; then
`EnterVacantNearbyCars(sVCModNpcCivilian)` + `UseNearbyAttractors(sVCModNpcCivilian)`.
Reuse `VCModNpcInitCivilianState()` for the shared `SCivilianAIState` (gang peds run
the same `CCivilianPed` path). The profile-switch reload (`nVCModNpcStateProfile`)
already re-inits on GANG↔CIVILIAN.

## Restore safety (hard requirement)

A stuck borrow corrupts normal play. The off-edge, terminal break (death, car,
arrest, controls taken), and profile switch must restore `CharCreatedBy`,
`m_fearFlags`, `m_pedStats`, and `m_gangFlags` to the player's own values. The
civilian path already restores the first two; extend it for the two gang-only
borrows. `m_pedStats` restores from the saved pointer, not a recomputed constant.

## Behavior → mechanism map

1. Rival hunt: rival `m_fearFlags` already contains GANG7 (data) + Tommy presents
   GANG7 in their scan (effective-type GetFlag reads).
2. Kin spare: GANG7 `m_fearFlags` excludes GANG7 + effective-type scan + the three
   stock guards. Kin chat: `CanBeFriends` effective type. Backup:
   `RegisterThreatWithGangPeds` effective type rallies nearby GANG7.
3. Own attack/defend: borrowed `GetThreats(GANG7)` + `CivilianAI` layer hunts rivals;
   `ReactToAttack` fall-through fights back; friendly-fire gates spare kin.
4. Look/voice: no model swap; the worn-body voice routing is untouched (verify only).
5. Cop chase: `IsGangMember()` player-aware → `CopPatrolScan` targets him.

## Verification

Harness — extend `utils/test_vc_npcmode.py`:
- gang flag borrows per profile (fearFlags == GetThreats(GANG7), pedStats ==
  PEDSTAT_GANG7, GANG7 bit cleared, RANDOM_CHAR) and restore on off/break/switch;
- `IsGangMember()` and `VCModGangEffectiveType` truth table (gang-profile player vs
  normal player vs real GANG7 vs rival);
- friendly-fire gates (kin melee/bullet skipped, rival allowed);
- CIVILIAN/COP profiles unchanged.

In-game iteration checkpoints (build + install into `~/Games/VC` only when no
session is running):
1. Own attack/defend first (highest risk): gang Tommy acquires a rival, closes, and
   fights — see Risks.
2. Rival gangs hunt him on sight; GANG7 spare him.
3. Kin chat + backup (a rival attacks Tommy → nearby GANG7 join).
4. Cop patrol-chase.
5. Voice: default Tommy body keeps Tommy's voice; a worn gang body keeps that
   body's voice.
6. Toggle off / terminal break: control returns, Tommy protected as the player,
   all borrows restored.

## Risks / iteration checkpoints

- **Attack movement gap (most likely).** The player control switch had no movement
  drive for reaction states until the civilian round-3 fix added flee/investigate.
  Gang Tommy's `OBJECTIVE_KILL_CHAR_ON_FOOT` → seek/attack movement may likewise
  stand still. Expect to drive seek/attack movement under `bVCModNpcMode` the same
  way. Verify this first.
- **Restore airtightness.** A stuck `m_pedStats`/`RANDOM_CHAR`/`m_gangFlags` breaks
  normal play; test the off/break/switch edges explicitly.
- **Cop heat is intended** (confirmed 1:1), not a regression.
- **Kin chat initiation** reuses the civilian chat path; eligibility is fixed by
  `CanBeFriends`, but confirm a gang partner actually starts/answers a chat in play.

## Out of scope

- No forced gang model or weapon (Tommy keeps the worn body and carried weapon).
- No rebuild of the worn-body voice routing (behavior 4 is verify-only).
- No change to CIVILIAN/COP profiles or to native gang peds' own behavior.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` — read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).
- Git is the play-tester's: no commit, tag, or push.

## Leftover from the civilian session (separate, do not fold in silently)

- The civilian reaction-movement fix (flee/investigate translate) is built/installed
  but unplayed.
- Four VCMOD probes still in `Ped.cpp`/`PlayerPed.cpp` (`VCMOD threat`, `VCMOD civ
  layer`, `VCMOD corpse`, `VCMOD react move`) — strip after a final play confirm.