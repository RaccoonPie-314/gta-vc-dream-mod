# NPC mode: literal 1:1 pedestrian AI (civilian + cop) — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods` (upstream; no
branch/worktree/push here). Status: design, pending review.

## Goal

BECOME NPC turns the player ped into a literal pedestrian: the complete native
behavior set, not a chosen subset. "1:1" means every behavior the native ped
runs — chat, gawking, panic/flee, corpse/gunshot/explosion reactions, attractors,
the crime/objective layer — reproduced by running the engine's own routine, not
an approximation. The mode is standalone: it does not depend on STREET IDLE, and
the two toggles are mutually exclusive. It may reuse other mod mechanics (head
scratch, chatter) but owns its full AI layer.

Three profiles via NPC TYPE:

- GANG — the plain shared wander (a gang ped on foot is a plain `CPed`; no extra
  layer). Unchanged from today.
- CIVILIAN — the full `CCivilianPed` behavior set.
- COP — the foot-patrol layer (chase + hassle), minus arresting himself.

## Why extraction, not a type swap

`CPed::IsPlayer()` derives from `m_nPedType`; swapping the player to
`PEDTYPE_CIV*`/`PEDTYPE_COP` flips 337 `IsPlayer()` sites across 33 files (camera,
pad, wanted, missions). The player keeps `PLAYER1`. The native AI layers are
extracted into shared `CPed` routines that both the native ped class and the
player NPC driver call — one source of truth, which is what makes it 1:1. This is
the same extraction pattern documented for the cop profile in the street-idle
handoff.

## The extraction pattern

Native ped-type-specific AI lives in `CCivilianPed::ProcessControl` /
`CCopPed::ProcessControl`, which the player never runs. Extract the type-specific
layer into shared `CPed` methods. Type-only state is passed in, never moved onto
`CPed` (keeps every ped object's layout stable; `CCopPed` has an active
`VALIDATE_SIZE`).

- Civilian state: a small `SCivilianAIState` struct holding the seven
  `CCivilianPed`-only fields (`m_bLookForVacantCars`,
  `m_nLookForVacantCarsCounter`, `m_bStealCarEvenIfThereIsSomeoneInIt`,
  `m_bJustStoleACar`, `m_nStealWishList[16]`, `m_bAttractorUnk`,
  `m_nAttractorCycleState`). `CCivilianPed` groups its fields into one such struct
  (same size, same order); the player NPC driver owns a mod-side instance,
  initialized when the mode engages. Initialization keeps the native RNG call
  order so population behavior is unchanged.
- Cop state: the patrol scan uses only `m_nHassleTimer` (a `uint32`). The shared
  method takes a `uint32&`; `CCopPed` passes its member, the player passes a
  mod-owned timer.

### Civilian layer

Methods moved to `CPed`:

- `CivilianAI()` — the threat/event reaction (gunshot, dead ped, explosion →
  flee, investigate, report crime, duck). Uses only shared `CPed` state, so it
  moves verbatim, no struct parameter.
- `UseNearbyAttractors()`, `EnterVacantNearbyCars()` and helpers
  `FindNearbyAttractorsSectorList`, `IsAttractedTo`, `IsOnStealWishList` — take
  `SCivilianAIState&`.

The civilian `ProcessControl` state switch is extracted into a shared routine the
player calls (not hand-reproduced, to keep one source of truth): wander →
`ScanForInterestingStuff` (already wired), seek, phone → make-call, `Mug`,
`Solicit`. `Mug`, `Solicit`, `RunToReportCrime`,
`ScanForDelayedResponseThreats`, `CheckThreatValidity` are already shared `CPed`
methods. `CCivilianPed::ProcessControl` calls the same shared routines, so native
civilians are byte-for-byte unchanged.

Named omission: the prostitute-in-car `PED_DRIVING` block. It applies only to a
prostitute ped in a car with the player; the player ped on foot cannot enter it.

### Cop layer

The foot-patrol scan (`CopPed.cpp:527-569`) extracts into a shared `CPed` method
taking the hassle-timer reference and returning `bool` to preserve the chase
early-exit (`CCopPed` does `if (CopPatrolScan(m_nHassleTimer)) return;`). It
chases fleeing criminal/gang NPCs (`OBJECTIVE_KILL_CHAR_ON_FOOT`, sets the target
fleeing + `bBeingChasedByPolice`) and hassles wanderers
(`OBJECTIVE_HASSLE_CHAR`). The hassle branch already skips `IsPlayer()`, so
cop-Tommy never hassles himself. The arrest/pursuit logic (`CopAI`,
`SetArrestPlayer`, `ScanForCrimes`) is separate and not extracted — cop-Tommy
chases and hassles but does not arrest himself. The cop vehicle-entering and
disabled-cop blocks stay in `CCopPed` (not foot patrol).

## Type gates — minimal and named

The player keeps `PLAYER1`. A few civilian behaviors gate on ped type and
currently skip him (the gawk check `LookForSexyPeds` wants a civilian
male/female/criminal/gang; car theft wants the criminal flag). Patch only those
gates, guarded by NPC+civilian mode, the same way `WillChat` was already patched
to accept the player. His real type stays `PLAYER1` for camera, wanted and
missions. Each patch is a named, minimal divergence.

## Player NPC driver

`VCModUpdateNpcMode` dispatches on `nVCModNpcType` while the mode is on:

- GANG — shared wander only (as today).
- CIVILIAN — wander + the civilian state switch + `CivilianAI` + attractors +
  vacant-car layer, via the shared routines and the mod-side civilian state.
- COP — wander + the shared foot-patrol scan with the mod-owned hassle timer.

### Break rule shrinks

Today the mode suspends on any non-wander/idle state, which would eject the
player the instant he panics and flees. For 1:1, civilian/cop reaction states
(flee, investigate, chat, mug, hassle, chase) are part of being an NPC, not
breaks. The hard break shrinks to terminal events only: death, into a car,
controls taken, arrest. The mode rides through reaction states and resumes the
wander when the engine returns him to idle/wander (the post-chat resume already
re-adopts `PED_WANDER_PATH`).

## Toggles, panel, standalone

- Mutual exclusion: switching BECOME NPC on clears STREET IDLE; switching STREET
  IDLE on clears BECOME NPC. Enforced when either toggle changes state (the panel
  flag-toggle path and the street-idle path), so the two never run together.
- NPC TYPE cycle gains COP: enum `{GANG, CIVILIAN, COP, NUM}`, labels
  `{"GANG","CIVILIAN","COP"}`. The ini clamp, tweak range and cycle count derive
  from `NUM`/`ARRAY_SIZE`, so they extend automatically.
- Cycle color fix (done): the renderer treated index 0 as the greyed "off" state,
  which greyed GANG. `VCModCycleDef` gains a `selector` flag (default false keeps
  the on/off cycles unchanged); NPC TYPE sets it true so every state renders
  colored.

## Testing

- Behavior-identical harness: run each extracted routine against the same inputs
  as the original `CCivilianPed`/`CCopPed` code and assert identical state
  transitions (the extraction must not change native behavior).
- Extend `test_vc_npcmode`: the shrunk break rule (reaction states do not break;
  terminal events do), profile dispatch, mutual exclusion, COP cycle state.
- Panel harnesses updated for the `selector` field and the third cycle state.
- Full suite + Release build + install into `~/Games/VC` with no session running;
  in-game confirmation is the play-tester's.

## Portability and publication

Gameplay/AI code stays platform-neutral (no `#ifdef __APPLE__` in mod code);
assets via `mods/`. Published artifacts name no AI/model/tool; the workspace is
`vc-mod`. No Rockstar data shipped.

## Out of scope

- Faction membership (rivals hunt him, Vercetti treat him as kin, gang hostility
  matrix, look+voice) — still parked; this design only borrows the civilian/cop
  reaction routines, it does not make the world treat him as a gang member.
- The cop arrest/pursuit/vehicle layer and the prostitute-in-car block.
- COP heli/SWAT/roadblock behavior (`ProcessHeliSwat`, stingers) — street patrol
  only.