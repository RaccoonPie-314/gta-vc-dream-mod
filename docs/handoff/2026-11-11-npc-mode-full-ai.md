# NPC mode: literal 1:1 civilian + cop AI — built and installed, awaiting play

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c` (no
commits made; git is the play-tester's). The Dock-pinned `~/Games/VC/Vice City
Mods.app` rebuilds and installs this tree on launch; the clean build was also
installed directly into `~/Games/VC/reVC.app` with no session running.

Spec: `docs/specs/2026-11-11-npc-mode-full-ai-design.md`.
Plan: `docs/plans/2026-11-11-npc-mode-full-ai.md`.

## What this is

BECOME NPC now runs the complete native pedestrian AI on Tommy, 1:1, by extracting
the engine's own routines rather than approximating them. "1:1" here means the
literal, full behavior set — chat, gawking, panic/flee, corpse/gunshot/explosion
reactions, attractors, and the crime/objective layer — not a chosen subset.

Three profiles via NPC TYPE (now GANG / CIVILIAN / COP):

- GANG — the plain shared wander (a gang ped on foot is a plain CPed). Unchanged.
- CIVILIAN — the full CCivilianPed layer: state switch (wander/scan, seek, phone,
  mug, solicit), CivilianAI threat reactions, attractors, vacant-car theft.
- COP — the foot patrol: chase fleeing criminal/gang NPCs, hassle wanderers. No
  self-arrest (the arrest/pursuit logic is separate and not extracted).

## How it stays 1:1

The type-specific AI moved off CCivilianPed/CCopPed onto shared CPed methods; the
native ped classes call the exact same methods, so their behavior is unchanged.

- `CPed::CivilianAI`, `IsAttractedTo`, `FindNearbyAttractorsSectorList` — verbatim
  moves (use only shared CPed state).
- `CPed::UseNearbyAttractors`, `EnterVacantNearbyCars`, `IsOnStealWishList` — take
  a `SCivilianAIState&` holding the seven civilian-only fields. CCivilianPed groups
  its fields into one such struct (same size/order); Tommy uses a mod-owned one.
- `CPed::ProcessCivilianState` — the ProcessControl state switch, verbatim.
- `CPed::CopPatrolScan(uint32& hassleTimer)` — the patrol scan, bool return for the
  chase early-exit; CCopPed passes m_nHassleTimer, Tommy a mod-owned timer.

Tommy keeps PLAYER1 (no type swap — that flips 337 IsPlayer sites). Named,
minimal divergences:

- The hooker compare in ProcessCivilianState casts `this` to CCivilianPed*; the
  prostitute type guard precedes it, so only a prostitute reaches it.
- The gawk gate (LookForSexyPeds) allows Tommy when NPC-civilian
  (`VCModNpcCivilianActive()`), the way WillChat already did.
- NPC-Tommy's civilian state sets the criminal car-theft flag true so the full
  crime layer fires on him.
- The prostitute-in-car block stays in the shared switch; its own type guard makes
  it unreachable for Tommy.

## Driver and toggles

- `VCModUpdateNpcMode` dispatches the profile's native layer in CCivilianPed's
  order. The hard break shrunk to terminal events only (death, car, arrest,
  controls taken); reaction states (flee, investigate, chat, mug, hassle, chase)
  ride through and the wander resumes when the engine returns him to idle/wander.
- STREET IDLE and BECOME NPC are mutually exclusive: the panel toggle clears the
  other, and NPC mode clears STREET IDLE while on (handles ini/debug entry without
  a frame-ordering race). NPC mode is standalone.
- The NPC TYPE cycle's GANG label rendered greyed because the renderer treated
  index 0 as "off"; `VCModCycleDef` gained a `selector` flag (NPC TYPE sets it) so
  every state renders colored. On/off cycles are unchanged.

## Files

Modified: `src/peds/Ped.h`, `Ped.cpp`, `CivilianPed.h`, `CivilianPed.cpp`,
`CopPed.cpp`, `PlayerPed.cpp`, `src/extras/vcmodpanel.h`, `vcmodpanel.cpp`.
New harnesses: `utils/test_vc_civilian_ai.py`, `utils/test_vc_cop_patrol.py`;
`utils/test_vc_npcmode.py` rewritten for the new driver.

## Verification

Release build green; full suite 169/169; installed into `~/Games/VC` with no
session running. The extraction moves are verbatim or mechanical field-renames,
proven by the build (native code compiles unchanged in CPed context) plus the
behavior harnesses. Not yet played.

Plan deviations, both deliberate: Task 3 used the build as the identity proof for
the verbatim state-switch move (a full-switch stub harness would mostly test
stubs); Task 7 enforces exclusion at the toggle and has NPC mode clear STREET IDLE
(not the reverse at the engage point, which would race the frame order).

## Next steps (play-test)

1. CIVILIAN: chat with passersby, gawk, panic/flee at gunshots/explosions,
   investigate a fresh corpse, use attractors, the crime layer. Confirm he resumes
   wandering after reactions and after chat.
2. COP: chase a fleeing criminal/gang, hassle a wanderer; confirm he never arrests
   himself.
3. Native civilians and cops behave exactly as before (the extraction must not
   have changed them).
4. Toggles: turning one on turns the other off; GANG label is colored like the
   others.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` —
  read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).

## Parked

Faction membership (rivals hunt him, Vercetti kin, gang hostility, look+voice) is
still out of scope — this borrows the civilian/cop reaction routines, it does not
make the world treat him as a gang member.

## Paste-ready prompt

> Continuing the reVC NPC-mode work in `vc-mod` (reVC/, branch vcmods, HEAD
> 8d57f7c, all uncommitted). BECOME NPC now runs the full native civilian + cop AI
> 1:1 via shared CPed routines; STREET IDLE / BECOME NPC are mutually exclusive;
> NPC TYPE is GANG/CIVILIAN/COP. Build green, suite 169/169, installed into
> ~/Games/VC. Read docs/handoff/2026-11-11-npc-mode-full-ai.md first. Next:
> play-test the civilian reactions (chat/gawk/panic/corpse/crime), cop patrol,
> native peds unchanged, and the toggle exclusion. Do not touch ~/Games/VC data or
> the uchg anim files; git is mine.