# NPC mode full 1:1 AI (civilian + cop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make BECOME NPC run the complete native civilian and cop AI on the player ped, 1:1, via shared engine routines, with mutually-exclusive STREET IDLE / BECOME NPC toggles.

**Architecture:** Extract the type-specific AI layers from `CCivilianPed` and `CCopPed` into shared `CPed` methods. Native peds call the same methods (behavior unchanged); the player NPC driver calls them with mod-owned type-only state. The player keeps `PLAYER1`; only type gates that skip him get minimal named patches.

**Tech Stack:** C++ (reVC engine), Python unittest harnesses that extract C++ functions and compile against stubs (`reVC/utils/test_vc_*.py`, `braced`/`run_cpp` from `test_vc_passenger.py`).

**Spec:** `docs/specs/2026-11-11-npc-mode-full-ai-design.md`

## Global Constraints

- Game data is read-only: never delete/move/overwrite `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are uchg-locked.
- Never install over a running session: `pgrep -f "reVC.app/Contents/MacOS/reVC"` must be empty before `scripts/install.sh`.
- Git is the user's: NO commits, tags, branches, worktrees, or pushes in this plan. reVC is upstream. Tasks end at "verify", not "commit".
- Platform-neutral mod code: no `#ifdef __APPLE__` in `src/extras/` or gameplay code; assets via `mods/`.
- Published artifacts name no AI/model/tool; workspace is `vc-mod`; impersonal engineering voice.
- Native ped behavior must not change: every extraction is a verbatim move or a mechanical field-rename, proven by harness + build.
- Build: `bash scripts/build.sh`. Suite: `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'`. Install: `bash scripts/install.sh`.

## File Structure

- `reVC/src/peds/Ped.h` — add `SCivilianAIState` struct; declare the shared `CPed` methods.
- `reVC/src/peds/Ped.cpp` — host the extracted civilian methods + `ProcessCivilianState` + `CopPatrolScan`.
- `reVC/src/peds/CivilianPed.h` — replace the seven civilian fields with one `SCivilianAIState m_sCivilian`; drop the moved method declarations.
- `reVC/src/peds/CivilianPed.cpp` — ctor inits `m_sCivilian`; `ProcessControl` calls the shared routines; remove moved bodies.
- `reVC/src/peds/CopPed.cpp` — `ProcessControl` calls `CopPatrolScan(m_nHassleTimer)`; remove the moved patrol block.
- `reVC/src/peds/PlayerPed.cpp` — NPC driver dispatch, mod-owned civilian state + hassle timer, shrunk break rule, type-gate patches.
- `reVC/src/extras/vcmodpanel.h/.cpp` — COP cycle state, mutual exclusion. (`selector` color fix already done.)
- `reVC/src/core/re3.cpp` — ini clamp already derives from `NUM_VCMOD_NPC_TYPES` (verify).
- `reVC/utils/test_vc_npcmode.py` — break rule, dispatch, mutual exclusion, COP.
- `reVC/utils/test_vc_civilian_ai.py` (new) — extracted civilian routine behavior.
- `reVC/utils/test_vc_cop_patrol.py` (new) — extracted cop patrol behavior.

---

### Task 1: Civilian state struct + verbatim method moves

Move the civilian methods that use only shared `CPed` state onto `CPed`, unchanged. Define the state struct used by later tasks.

**Files:**
- Modify: `reVC/src/peds/Ped.h` (struct + declarations)
- Modify: `reVC/src/peds/Ped.cpp` (add moved bodies)
- Modify: `reVC/src/peds/CivilianPed.h` (drop moved declarations)
- Modify: `reVC/src/peds/CivilianPed.cpp` (remove moved bodies)
- Test: `reVC/utils/test_vc_civilian_ai.py`

**Interfaces:**
- Produces: `struct SCivilianAIState { bool m_bLookForVacantCars; uint32 m_nLookForVacantCarsCounter; bool m_bStealCarEvenIfThereIsSomeoneInIt; bool m_bJustStoleACar; uint32 m_nStealWishList[16]; bool m_bAttractorUnk; int32 m_nAttractorCycleState; };`
- Produces: `void CPed::CivilianAI(void)`, `bool CPed::IsAttractedTo(int8 type)`, `void CPed::FindNearbyAttractorsSectorList(CPtrList&, float&, C2dEffect*&, CEntity*&)` — bodies identical to the `CCivilianPed` originals.

- [ ] **Step 1: Add the struct + declarations to Ped.h**

Add before `class CPed` (after the includes/enums it depends on):

```cpp
struct SCivilianAIState {
	bool m_bLookForVacantCars;
	uint32 m_nLookForVacantCarsCounter;
	bool m_bStealCarEvenIfThereIsSomeoneInIt;
	bool m_bJustStoleACar;
	uint32 m_nStealWishList[16];
	bool m_bAttractorUnk;
	int32 m_nAttractorCycleState;
};
```

In `class CPed` public section add:

```cpp
void CivilianAI(void);
bool IsAttractedTo(int8 type);
void FindNearbyAttractorsSectorList(CPtrList&, float&, C2dEffect*&, CEntity*&);
```

- [ ] **Step 2: Move the three bodies verbatim into Ped.cpp**

Copy the full bodies of `CCivilianPed::CivilianAI` (CivilianPed.cpp:50-224), `CCivilianPed::IsAttractedTo` (520-531), and `CCivilianPed::FindNearbyAttractorsSectorList` into `Ped.cpp`, renaming only the qualifier `CCivilianPed::` → `CPed::`. Do not change any statement. Add any includes `Ped.cpp` lacks for these bodies (e.g. `Weather.h`, `PedAttractor.h`, `Phones.h`, `Wanted.h` — check against CivilianPed.cpp's include list). Delete the three bodies from CivilianPed.cpp and their declarations from CivilianPed.h.

- [ ] **Step 3: Write the behavior harness**

Create `reVC/utils/test_vc_civilian_ai.py` following the `test_vc_npcmode.py` pattern (import `braced, run_cpp`). Extract `CPed::IsAttractedTo` (marker `"bool\nCPed::IsAttractedTo(int8 type)"`) against a stub `CWeather::Rain`. Concrete cases:

```python
def test_attracted_to_seat_and_atm(self):
    # ATTRACTOR_SEAT and ATTRACTOR_ATM return true regardless of weather
    ...
def test_shelter_only_in_rain(self):
    # ATTRACTOR_SHELTER returns CWeather::Rain >= 0.2f
    ...
def test_icecream_not_attracted(self):
    # ATTRACTOR_ICECREAM returns false
    ...
```

Use the real `ATTRACTOR_*` enum values from `src/peds/PedAttractor.h` (read them; do not guess).

- [ ] **Step 4: Run harness + build**

Run: `cd reVC/utils && python3 -m unittest test_vc_civilian_ai -v` → PASS.
Run: `bash scripts/build.sh` → green (proves the moved bodies compile in `CPed` context and `CCivilianPed` still links).

- [ ] **Step 5: Verify native unchanged**

Confirm `CCivilianPed::ProcessControl` still calls `CivilianAI()` (now inherited). The build linking + the harness are the identity proof for the verbatim move. No commit (git is the user's).

---

### Task 2: Struct-taking civilian methods + field consolidation

Move the three methods that use civilian-only fields, parameterized by `SCivilianAIState&`. Consolidate `CCivilianPed`'s seven fields into one struct member (same size/order).

**Files:**
- Modify: `reVC/src/peds/Ped.h`, `reVC/src/peds/Ped.cpp`
- Modify: `reVC/src/peds/CivilianPed.h`, `reVC/src/peds/CivilianPed.cpp`
- Test: `reVC/utils/test_vc_civilian_ai.py`

**Interfaces:**
- Consumes: `SCivilianAIState` (Task 1).
- Produces: `void CPed::UseNearbyAttractors(SCivilianAIState& state)`, `void CPed::EnterVacantNearbyCars(SCivilianAIState& state)`, `bool CPed::IsOnStealWishList(SCivilianAIState& state, int32 model)`.
- Produces: `CCivilianPed` member `SCivilianAIState m_sCivilian;` replacing the seven fields.

- [ ] **Step 1: Write the failing harness for IsOnStealWishList**

Add to `test_vc_civilian_ai.py`: extract `CPed::IsOnStealWishList` (marker `"bool\nCPed::IsOnStealWishList(SCivilianAIState& state, int32 model)"`) with the real `SCivilianAIState` struct extracted from Ped.h. Test: a state whose `m_nStealWishList[3] == 123` returns true for model 123, false for 999. Run → FAIL (method not on CPed yet).

- [ ] **Step 2: Move the three bodies with the field rename**

Copy `UseNearbyAttractors` (478-518), `EnterVacantNearbyCars` (533-599), `IsOnStealWishList` (601-610) into Ped.cpp as `CPed::` methods taking `SCivilianAIState& state`. Rename ONLY these member references to `state.`: `m_bAttractorUnk`, `m_nAttractorCycleState`, `m_bLookForVacantCars`, `m_bJustStoleACar`, `m_nLookForVacantCarsCounter`, `m_bStealCarEvenIfThereIsSomeoneInIt`, `m_nStealWishList`. Every other member (`bInVehicle`, `bHasAlreadyStoleACar`, `m_carInObjective`, `m_pMyVehicle`, `m_objective`, etc.) stays `this->`. `IsOnStealWishList(veh->GetModelIndex())` call inside `EnterVacantNearbyCars` becomes `IsOnStealWishList(state, veh->GetModelIndex())`. Add declarations to Ped.h; remove bodies + declarations from CivilianPed.

- [ ] **Step 3: Consolidate CCivilianPed fields**

In CivilianPed.h replace the seven field declarations with `SCivilianAIState m_sCivilian;` (keep it in the same position so layout/order is preserved). In the ctor (CivilianPed.cpp:21-47) prefix each initialized field with `m_sCivilian.` (e.g. `m_sCivilian.m_bLookForVacantCars = false;`, the wishlist loop writes `m_sCivilian.m_nStealWishList[i]`). Keep the RNG call order identical. In `ProcessControl`, the calls `EnterVacantNearbyCars()` / `UseNearbyAttractors()` become `EnterVacantNearbyCars(m_sCivilian)` / `UseNearbyAttractors(m_sCivilian)`.

- [ ] **Step 4: Run harness + build**

Run: `python3 -m unittest test_vc_civilian_ai -v` → PASS. Run: `bash scripts/build.sh` → green. If `VALIDATE_SIZE(CCivilianPed, 0x53C)` is uncommented it must still pass (struct preserves size).

- [ ] **Step 5: Verify**

Native civilian car-theft/attractor behavior is the same code with renamed field access. No commit.

---

### Task 3: Extract the civilian state switch

Move the `ProcessControl` state switch into a shared `CPed::ProcessCivilianState` so the player runs the identical switch.

**Files:**
- Modify: `reVC/src/peds/Ped.h`, `reVC/src/peds/Ped.cpp`, `reVC/src/peds/CivilianPed.cpp`
- Test: `reVC/utils/test_vc_civilian_ai.py`

**Interfaces:**
- Produces: `void CPed::ProcessCivilianState(void)` — the switch currently at CivilianPed.cpp:241-403 (wander→`ScanForInterestingStuff`, seek, phone→make-call, `Mug`, `Solicit`, `PED_UNKNOWN`, prostitute `PED_DRIVING`). The prostitute block stays; its own `if (m_nPedType != PEDTYPE_PROSTITUTE) break;` guard makes it unreachable for the player.

- [ ] **Step 1: Write the failing harness**

Add a test extracting `CPed::ProcessCivilianState` (marker `"void\nCPed::ProcessCivilianState(void)"`) with a stub ped: set `m_nPedState = PED_WANDER_PATH`, `IsVisible()` true, assert it calls `ScanForInterestingStuff()` (stub records the call). Run → FAIL.

- [ ] **Step 2: Move the switch**

Copy the `switch (m_nPedState) { ... }` block (CivilianPed.cpp:241-403) verbatim into `CPed::ProcessCivilianState`. It references only `CPed` members and globals (`CWorld::Players`, `gPhoneInfo`), so no parameter is needed. Replace the block in `CCivilianPed::ProcessControl` with `ProcessCivilianState();`. Keep the surrounding `CPed::ProcessControl()` call, the `bWasPostponed`/`DyingOrDead` guards, `GetWeapon()->Update`, the trailing `if (IsPedInControl()) CivilianAI();` and the `RANDOM_CHAR` attractor/car calls exactly where they are.

- [ ] **Step 3: Run harness + build**

Run: `python3 -m unittest test_vc_civilian_ai -v` → PASS. Run: `bash scripts/build.sh` → green.

- [ ] **Step 4: Verify**

`CCivilianPed::ProcessControl` now reads: base call → guards → `ProcessCivilianState()` → `CivilianAI()` → attractors/cars. Same order as before. No commit.

---

### Task 4: Extract the cop foot-patrol scan

Move the patrol scan into a shared `CPed` method taking a hassle-timer reference, preserving the chase early-exit via a bool return.

**Files:**
- Modify: `reVC/src/peds/Ped.h`, `reVC/src/peds/Ped.cpp`, `reVC/src/peds/CopPed.cpp`
- Test: `reVC/utils/test_vc_cop_patrol.py`

**Interfaces:**
- Produces: `bool CPed::CopPatrolScan(uint32& hassleTimer)` — returns true when it sets a chase objective (the original `return;` at CopPed.cpp:545), false otherwise. Contains the gate `m_objective != OBJECTIVE_KILL_CHAR_ON_FOOT && m_objective != OBJECTIVE_HASSLE_CHAR && CharCreatedBy == RANDOM_CHAR` and the near-ped loop (527-569), with `m_nHassleTimer` renamed to `hassleTimer`.

- [ ] **Step 1: Write the failing harness**

Create `test_vc_cop_patrol.py`. Extract `CPed::CopPatrolScan` (marker `"bool\nCPed::CopPatrolScan(uint32& hassleTimer)"`). Stub a ped with one near ped that is a fleeing criminal (`m_nPedType == PEDTYPE_CRIMINAL`, `m_nPedState == PED_FLEE_ENTITY`, `m_fleeFrom` a cop). Assert: returns true, sets `OBJECTIVE_KILL_CHAR_ON_FOOT` on self, `OBJECTIVE_FLEE_CHAR_ON_FOOT_TILL_SAFE` + `bBeingChasedByPolice` on the target. Second test: a wandering non-cop non-player near ped within 5m with clear line of sight → sets `OBJECTIVE_HASSLE_CHAR`, writes `hassleTimer = now + 100000`, returns false. Run → FAIL.

- [ ] **Step 2: Move the block**

Copy the gate + loop (CopPed.cpp:527-569) into `CPed::CopPatrolScan(uint32& hassleTimer)`. Rename `m_nHassleTimer` → `hassleTimer`. Replace the chase `return;` with `return true;`; end the method with `return false;`. In `CCopPed::ProcessControl`, replace the block with `if (CopPatrolScan(m_nHassleTimer)) return;` at the same nesting point (inside the on-foot `else`, inside `IsPedInControl()`). Add the declaration to Ped.h.

- [ ] **Step 3: Run harness + build**

Run: `python3 -m unittest test_vc_cop_patrol -v` → PASS. Run: `bash scripts/build.sh` → green. `VALIDATE_SIZE(CCopPed, 0x62C)` must still pass (no layout change).

- [ ] **Step 4: Verify**

The arrest/pursuit logic (`CopAI`, `SetArrestPlayer`, `ScanForCrimes`) is untouched. No commit.

---

### Task 5: Player driver — civilian profile + shrunk break rule

Wire the civilian profile to the shared routines with mod-owned state; shrink the hard break to terminal events; patch the type gates that skip `PLAYER1`.

**Files:**
- Modify: `reVC/src/peds/PlayerPed.cpp`
- Modify: `reVC/src/peds/Ped.cpp` (`LookForSexyPeds` gate)
- Test: `reVC/utils/test_vc_npcmode.py`

**Interfaces:**
- Consumes: `CPed::ProcessCivilianState`, `CivilianAI`, `UseNearbyAttractors(SCivilianAIState&)`, `EnterVacantNearbyCars(SCivilianAIState&)`, `CopPatrolScan(uint32&)` (Tasks 1-4).
- Produces: mod statics `static SCivilianAIState sVCModNpcCivilian; static uint32 nVCModNpcHassleTimer; static bool bVCModNpcStateInit;` and `VCModNpcInitCivilianState()`; rewritten `VCModNpcModeBreak` (terminal-only) and `VCModUpdateNpcMode` (profile dispatch).

- [ ] **Step 1: Write failing harness for the shrunk break rule**

In `test_vc_npcmode.py` add: with mode on and wandering, set `p.m_nPedState = PED_FLEE_ENTITY` (a reaction state) → `VCModUpdateNpcMode` keeps `bVCModStreetWander` true (no break). Set `PED_ARRESTED` → breaks. Update the stub enum to include `PED_FLEE_ENTITY`, `PED_INVESTIGATE`. Run → FAIL (current code breaks on FLEE).

- [ ] **Step 2: Shrink VCModNpcModeBreak**

Replace the generic state break with terminal-only:

```cpp
static int32
VCModNpcModeBreak(CPlayerPed *player, CPad *pad)
{
	int32 reason = 0;
	if (player->DyingOrDead()) reason |= VCMOD_CHATBREAK_DEAD;
	if (player->bInVehicle) reason |= VCMOD_CHATBREAK_IN_CAR;
	if (pad->ArePlayerControlsDisabled()) reason |= VCMOD_CHATBREAK_CONTROLS;
	if (player->m_nPedState == PED_ARRESTED) reason |= VCMOD_CHATBREAK_STATE;
	return reason;
}
```

- [ ] **Step 3: Add mod state + initializer**

Add the statics near the other NPC statics. `VCModNpcInitCivilianState()` mirrors the `CCivilianPed` ctor's field init (same RNG order): zero the struct, `m_bLookForVacantCars = true` (named divergence: lets NPC-Tommy use the criminal car-theft layer), randomize `m_nStealWishList` exactly as the ctor does, `m_bAttractorUnk = (CGeneral::GetRandomNumberInRange(0.0f,1.0f) < 1.25f)`, `m_nAttractorCycleState = 0`. Set `bVCModNpcStateInit = true`.

- [ ] **Step 4: Rewrite VCModUpdateNpcMode dispatch**

Keep the on->off edge and the not-wandering handover (resume on `PED_IDLE`/`PED_WANDER_PATH`, init civilian state on first successful start). While wandering and not terminal-broken: if `state == PED_IDLE` re-issue `SetWanderPath`; then dispatch:

```cpp
if (nVCModNpcType == VCMOD_NPC_CIVILIAN) {
	player->ProcessCivilianState();
	if (player->IsPedInControl()) player->CivilianAI();
	player->EnterVacantNearbyCars(sVCModNpcCivilian);
	player->UseNearbyAttractors(sVCModNpcCivilian);
} else if (nVCModNpcType == VCMOD_NPC_COP) {
	player->CopPatrolScan(nVCModNpcHassleTimer);
}
```

(This mirrors `CCivilianPed::ProcessControl`'s post-base order. The COP branch is exercised in Task 6.) Remove the old civilian-only `ScanForInterestingStuff` call — `ProcessCivilianState` now owns it.

- [ ] **Step 5: Patch the gawk type gate**

In `CPed::LookForSexyPeds` (Ped.cpp:7867), the FIX_BUGS gate skips non-civilian types. Add a named allowance so NPC-civilian Tommy gawks: extend the gate condition with `&& !(IsPlayer() && VCModNpcCivilianActive())`, where `VCModNpcCivilianActive()` is a small exported predicate (declared in vcmodpanel.h, defined in PlayerPed.cpp) returning `bVCModNpcMode && nVCModNpcType == VCMOD_NPC_CIVILIAN`. Keep the divergence minimal and commented.

- [ ] **Step 6: Run harness + build**

Update `test_vc_npcmode.py` stubs for the new calls (`ProcessCivilianState`, `CivilianAI`, etc. as recording stubs) and the new break rule. Run: `python3 -m unittest test_vc_npcmode test_vc_civilian_ai -v` → PASS. Run: `bash scripts/build.sh` → green.

- [ ] **Step 7: Verify**

Full suite still green. No commit.

---

### Task 6: Player driver — cop profile + COP cycle state

Add the COP profile selection and confirm the cop dispatch from Task 5.

**Files:**
- Modify: `reVC/src/extras/vcmodpanel.h` (enum), `reVC/src/extras/vcmodpanel.cpp` (labels)
- Modify: `reVC/src/core/re3.cpp` (verify clamp)
- Test: `reVC/utils/test_vc_npcmode.py`, `reVC/utils/test_vc_character.py`, `reVC/utils/test_vc_adrenaline.py`, `reVC/utils/test_vc_passenger.py`

**Interfaces:**
- Consumes: `CPed::CopPatrolScan` (Task 4), COP dispatch (Task 5).
- Produces: `enum eVCModNpcType { VCMOD_NPC_GANG, VCMOD_NPC_CIVILIAN, VCMOD_NPC_COP, NUM_VCMOD_NPC_TYPES };`, labels `{"GANG","CIVILIAN","COP"}`.

- [ ] **Step 1: Write failing harness for COP dispatch**

In `test_vc_npcmode.py`: mode on, `nVCModNpcType = VCMOD_NPC_COP`, wandering → `VCModUpdateNpcMode` calls `CopPatrolScan` (recording stub) and not the civilian routines. Run → FAIL (enum has no COP yet).

- [ ] **Step 2: Extend enum + labels**

In vcmodpanel.h add `VCMOD_NPC_COP` before `NUM_VCMOD_NPC_TYPES`. In vcmodpanel.cpp set `aVCModNpcTypeLabels[] = { "GANG", "CIVILIAN", "COP" }`. The cycle count (`ARRAY_SIZE`), tweak range (`NUM-1`) and ini clamp (`NUM`) extend automatically — verify re3.cpp clamp uses `NUM_VCMOD_NPC_TYPES`.

- [ ] **Step 3: Update panel harnesses**

The character/adrenaline drivers extract the NPC-type cycle markers; the labels array now has 3 entries. Update any asserted label/count. Passenger row-count assertion is unchanged (no new row). Run them.

- [ ] **Step 4: Run harness + build**

Run: `python3 -m unittest test_vc_npcmode test_vc_character test_vc_adrenaline test_vc_passenger -v` → PASS. Run: `bash scripts/build.sh` → green.

- [ ] **Step 5: Verify**

COP selectable; cop-Tommy chases criminals/gangs and hassles wanderers, never arrests himself. No commit.

---

### Task 7: Mutual exclusion of the toggles

Turning BECOME NPC on clears STREET IDLE and vice versa.

**Files:**
- Modify: `reVC/src/extras/vcmodpanel.cpp` (flag-toggle path)
- Modify: `reVC/src/peds/PlayerPed.cpp` (street-idle path / NPC engage)
- Test: `reVC/utils/test_vc_npcmode.py`

**Interfaces:**
- Consumes: `bVCModNpcMode`, `bVCModStreetIdle`.
- Produces: exclusion enforced when either flag changes.

- [ ] **Step 1: Write failing harness**

Add a test: set `bVCModStreetIdle = true`, then turn `bVCModNpcMode` on via the panel toggle handler → `bVCModStreetIdle == false`. And the reverse. Run → FAIL.

- [ ] **Step 2: Enforce at the toggle points**

In the panel flag-toggle path (where `VCMOD_ROW_FLAG` flips `*def->state`), after flipping: if the flipped row is `NpcMode` and it is now true, clear `bVCModStreetIdle`; if it is `StreetIdle` and now true, clear `bVCModNpcMode`. Identify rows by `def->iniKey` ("NpcMode"/"StreetIdle"). Also clear `bVCModStreetIdle` when `VCModUpdateNpcMode` engages the wander, and clear `bVCModNpcMode` when street-idle starts its wander, so the exclusion holds regardless of entry path.

- [ ] **Step 3: Run harness + build**

Run: `python3 -m unittest test_vc_npcmode -v` → PASS. Run: `bash scripts/build.sh` → green.

- [ ] **Step 4: Verify**

The two modes never run together; `VCModUpdateStreetIdle`'s existing `if (bVCModNpcMode) return;` still guards the idle layer. No commit.

---

### Task 8: Full verification, install, handoff

**Files:**
- Modify: `docs/handoff/2026-11-11-street-idle-wander.md` (or a new handoff)

- [ ] **Step 1: Full suite**

Run: `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'` → all OK. Fix any regression.

- [ ] **Step 2: Release build**

Run: `bash scripts/build.sh` → green.

- [ ] **Step 3: Install (only if no session)**

Run: `pgrep -f "reVC.app/Contents/MacOS/reVC"` → must be empty. Then `bash scripts/install.sh`. If a session is running, stop and ask the user to quit; never install over it.

- [ ] **Step 4: Handoff**

Write the handoff doc (repo/branch/HEAD, installed build, what is uncommitted, next steps, files not to touch) and a paste-ready prompt. In-game confirmation of civilian reactions (chat/gawk/panic/corpse), cop patrol, and native civilians/cops unchanged is the play-tester's. Do not claim fixed without play. No commit.

---

## Self-Review

**Spec coverage:** civilian extraction (Tasks 1-3), cop extraction (Task 4), player dispatch + shrunk break + type gates (Task 5), COP cycle (Task 6), mutual exclusion + standalone (Task 7), selector color fix (done pre-plan), testing/build/install/handoff (Task 8). Faction membership, cop arrest/vehicle, prostitute block remain out of scope (prostitute block stays shared but self-guards). All spec sections map to a task.

**Placeholder scan:** no TBD/TODO; moved bodies are referenced by exact source method + line range with a precise rename rule (the bodies exist in source; the instruction is to copy them verbatim). Test code given for the key behaviors.

**Type consistency:** `SCivilianAIState` field names match CivilianPed.h verbatim; method signatures (`UseNearbyAttractors(SCivilianAIState&)`, `EnterVacantNearbyCars(SCivilianAIState&)`, `IsOnStealWishList(SCivilianAIState&, int32)`, `CopPatrolScan(uint32&)`, `ProcessCivilianState(void)`, `CivilianAI(void)`) are used identically across Tasks 1-6. `VCMOD_NPC_COP` added before `NUM_VCMOD_NPC_TYPES` everywhere.