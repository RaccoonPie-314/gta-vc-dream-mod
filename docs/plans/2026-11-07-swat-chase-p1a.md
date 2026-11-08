# SWAT Chase P1a: Ground Pursuit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the mission playable on the ground: the leader spawns in a sedan, flees along a road route, stops to swap cars, then stops to pick up an accomplice, and the run ends in a win (leader down) or a fail (leader escapes), leaving no trace.

**Architecture:** Extend `src/extras/vcmodchase.cpp` with a scenario section that spawns and owns the leader, drives him with the engine's road autopilot, and advances a small beat machine every frame. The head start and both beats are laid out by walking the car lane from the station 200 m, so the route is always on road and starts well away from the player; the leader waits 10 s before pulling out. Spawning follows the proven pattern in `PlayerPed.cpp:654` (`RequestModel`, `new CAutomobile(..., RANDOM_VEHICLE)`, `SetUpDriver`, then `VehicleCreatedBy = MISSION_VEHICLE`). Route points resolve to car path nodes so the car always drives on roads. Pure decisions are brace-extracted into `utils/test_vc_chase.py`.

**Tech Stack:** reVC C++ (branch `vcmods`), CMake via `scripts/build.sh`, Python 3 harness under `utils/`.

**Spec:** `docs/specs/2026-11-07-swat-chase-design.md` (sections 6.4, 6.6, 8, 9)

**Scope:** P1a is the chase and the two stops. P1b adds the AI squad, the Enforcer, the friendly-fire filter, and the marina boat finale. P1a's fail is a distance leash, which the boat replaces.

## Global Constraints

- Work only in `src/extras/vcmodchase.h`, `src/extras/vcmodchase.cpp` and `utils/test_vc_chase.py`.
- Do not modify or stage other agents' dirty files: `src/core/re3.cpp`, `src/extras/vcmodpanel.*`, `src/peds/Ped.cpp`, `src/peds/PlayerPed.cpp`, `utils/test_vc_driver.py`, `utils/test_vc_passenger.py`.
- Stage explicit paths only. Never `git add -A` or `git commit -am`.
- Do not push the reVC repository; commits stay local on `vcmods`.
- No SCM, Rockstar data or savegame edits.
- No health, damage or accuracy multipliers.
- Leave no trace: every mission ped, vehicle and blip is deleted on end, including on fail and on reset.
- Follow the repo style: tabs, function opening brace on its own line, one responsibility per helper.
- Verification is harness plus build, then an in-game handoff. Do not launch the game.

---

## File Structure

- `src/extras/vcmodchase.h` — add the pure API for the leash and pressure rules.
- `src/extras/vcmodchase.cpp` — add includes, scenario state, spawn/cleanup, the beat machine, and the win/fail checks.
- `utils/test_vc_chase.py` — extract and test the new pure functions.

---

### Task 1: Leader, Blip, Win by Death, Fail by Leash

**Files:**
- Modify: `src/extras/vcmodchase.h`
- Modify: `src/extras/vcmodchase.cpp`
- Test: `utils/test_vc_chase.py`

**Interfaces:**
- Consumes: `VCMOD_CHASE_RUNNING`, `VCModChaseEnd`, `VCModChaseNotice`, `FindPlayerCoors`, `FindPlayerPed`.
- Produces:
  - `bool VCModChaseHasEscaped(float dist, uint32 awaySince, uint32 now)`
  - `static bool VCModChaseSpawnLeader(CVector at)`
  - `static void VCModChaseClearScenario(void)`
  - module state `pVCModChaseLeader`, `pVCModChaseLeaderCar`, `nVCModChaseLeaderBlip`, `nVCModChaseAwaySince`

- [ ] **Step 1: Add the failing harness case**

In `utils/test_vc_chase.py`, add `VCModChaseHasEscaped` to the extraction list:

```python
        "VCModChaseTierAllowed",
        "VCModChaseHasEscaped",
```

and these checks before `return failed ? 1 : 0;` in `MAIN`:

```c
    CHECK(!VCModChaseHasEscaped(100.0f, 0, 5000), "no escape inside the leash");
    CHECK(!VCModChaseHasEscaped(300.0f, 1000, 2000), "no escape before the timer");
    CHECK(VCModChaseHasEscaped(300.0f, 1000, 5000), "escape after the timer");
    CHECK(!VCModChaseHasEscaped(300.0f, 0, 9999), "no escape without a start time");
```

- [ ] **Step 2: Run the harness and verify it fails**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: FAIL with `VCModChaseHasEscaped not found in .../vcmodchase.cpp`.

- [ ] **Step 3: Declare the pure function**

In `src/extras/vcmodchase.h`, after `VCModChaseTierAllowed`:

```cpp
bool VCModChaseHasEscaped(float dist, uint32 awaySince, uint32 now);
```

- [ ] **Step 4: Add the scenario state and spawn/cleanup**

In `src/extras/vcmodchase.cpp`, extend the includes:

```cpp
#include "Automobile.h"
#include "CarCtrl.h"
#include "PathFind.h"
#include "Pools.h"
#include "Population.h"
#include "Script.h"
#include "Streaming.h"
```

After the tier state, add:

```cpp
#define VCMOD_CHASE_LEADER_MODEL	MI_MALE01
#define VCMOD_CHASE_LEADER_CAR		MI_SENTINEL
#define VCMOD_CHASE_LEASH			220.0f
#define VCMOD_CHASE_LEASH_TIME		3000

static CPed *pVCModChaseLeader;
static CVehicle *pVCModChaseLeaderCar;
static int32 nVCModChaseLeaderBlip = -1;
static uint32 nVCModChaseAwaySince;
```

Add the pure function after `VCModChaseTierAllowed`:

```cpp
bool
VCModChaseHasEscaped(float dist, uint32 awaySince, uint32 now)
{
	return dist > VCMOD_CHASE_LEASH && awaySince != 0 && now - awaySince > VCMOD_CHASE_LEASH_TIME;
}
```

Add the spawn and cleanup helpers before `VCModChaseUpdate`:

```cpp
static bool
VCModChaseSpawnLeader(CVector at)
{
	CStreaming::RequestModel(VCMOD_CHASE_LEADER_MODEL, 0);
	CStreaming::RequestModel(VCMOD_CHASE_LEADER_CAR, 0);
	CStreaming::LoadAllRequestedModels(false);
	if (!CStreaming::HasModelLoaded(VCMOD_CHASE_LEADER_MODEL) ||
	    !CStreaming::HasModelLoaded(VCMOD_CHASE_LEADER_CAR)) {
		VCModChaseNotice("chase: the leader cannot be loaded");
		return false;
	}

	int32 node = ThePaths.FindNodeClosestToCoors(at, PATH_CAR, 80.0f, true, true);
	CVector pos = node >= 0 ? ThePaths.m_pathNodes[node].GetPosition() : at;

	CAutomobile *car = new CAutomobile(VCMOD_CHASE_LEADER_CAR, RANDOM_VEHICLE);
	if (car == nil) {
		VCModChaseNotice("chase: no room for the leader's car");
		return false;
	}
	pos.z += car->GetDistanceFromCentreOfMassToBaseOfModel();
	CTheScripts::ClearSpaceForMissionEntity(pos, car);
	car->SetPosition(pos);
	car->PlaceOnRoadProperly();
	car->SetStatus(STATUS_PHYSICS);
	car->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
	car->AutoPilot.m_nCruiseSpeed = 0;

	if (car->SetUpDriver() == nil) {
		CWorld::Add(car);
		VCModChaseNotice("chase: nobody to drive the leader's car");
		VCModChaseClearScenario();
		return false;
	}
	car->VehicleCreatedBy = MISSION_VEHICLE;
	CCarCtrl::NumRandomCars--;
	CCarCtrl::NumMissionCars++;
	CWorld::Add(car);

	pVCModChaseLeader = car->pDriver;
	pVCModChaseLeaderCar = car;
	pVCModChaseLeader->CharCreatedBy = MISSION_CHAR;
	pVCModChaseLeader->bIsPlayerFriend = false;
	nVCModChaseLeaderBlip = CRadar::SetEntityBlip(BLIP_CHAR,
		CPools::GetPedPool()->GetIndex(pVCModChaseLeader), 0, BLIP_DISPLAY_BOTH);
	nVCModChaseAwaySince = 0;
	return true;
}

static void
VCModChaseClearScenario(void)
{
	if (nVCModChaseLeaderBlip >= 0) {
		CRadar::ClearBlip(nVCModChaseLeaderBlip);
		nVCModChaseLeaderBlip = -1;
	}
	if (pVCModChaseLeaderCar != nil) {
		CWorld::Remove(pVCModChaseLeaderCar);
		delete pVCModChaseLeaderCar;
		pVCModChaseLeaderCar = nil;
	}
	pVCModChaseLeader = nil;
	nVCModChaseAwaySince = 0;
}
```

`CPed::CharCreatedBy` is a public member; `bIsPlayerFriend` is a bitfield in `CPed` (`src/peds/Ped.h:473`). The vehicle is deleted before the ped, and the ped is owned by the vehicle's driver slot; deleting the vehicle does not delete the driver, so delete the ped first:

```cpp
	if (pVCModChaseLeader != nil) {
		CPopulation::RemovePed(pVCModChaseLeader);
		pVCModChaseLeader = nil;
	}
	if (pVCModChaseLeaderCar != nil) {
		CWorld::Remove(pVCModChaseLeaderCar);
		delete pVCModChaseLeaderCar;
		pVCModChaseLeaderCar = nil;
	}
```

Use that order in the helper.

- [ ] **Step 5: Spawn on RUNNING and check win/fail**

In `VCModChaseUpdate`, inside the `case VCMOD_CHASE_RUNNING:` block, before the BACKSPACE check:

```cpp
		if (pVCModChaseLeaderCar == nil && !VCModChaseSpawnLeader(vecVCModChaseStation))
			break;
		if (pVCModChaseLeader->DyingOrDead()) {
			VCModChaseNotice("chase: the leader is down");
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_FINISH);
			VCModChaseClearScenario();
			VCModChaseEnd();
			break;
		}
		float dist = (pVCModChaseLeader->GetPosition() - player->GetPosition()).Magnitude2D();
		uint32 now = CTimer::GetTimeInMilliseconds();
		if (dist > VCMOD_CHASE_LEASH && nVCModChaseAwaySince == 0)
			nVCModChaseAwaySince = now;
		else if (dist <= VCMOD_CHASE_LEASH)
			nVCModChaseAwaySince = 0;
		if (VCModChaseHasEscaped(dist, nVCModChaseAwaySince, now)) {
			VCModChaseNotice("chase: the leader got away");
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_FINISH);
			VCModChaseClearScenario();
			VCModChaseEnd();
			break;
		}
```

Also call `VCModChaseClearScenario()` in `VCModChaseReset` and in `VCModChaseEnd`.

- [ ] **Step 6: Run the harness and verify it passes**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: PASS.

- [ ] **Step 7: Build**

Run: `scripts/build.sh`
Expected: Release build completes with no errors.

- [ ] **Step 8: Commit**

```bash
cd reVC
git add src/extras/vcmodchase.h src/extras/vcmodchase.cpp utils/test_vc_chase.py
git commit -m "Spawn the chase leader with a blip and a leash fail"
```

---

### Task 2: Route Legs, Stops and the Pressure Rule

**Files:**
- Modify: `src/extras/vcmodchase.h`
- Modify: `src/extras/vcmodchase.cpp`
- Test: `utils/test_vc_chase.py`

**Interfaces:**
- Consumes: `pVCModChaseLeaderCar`, `VCModChaseSpawnLeader`.
- Produces:
  - `bool VCModChaseLeaderPressured(float dist, bool lineOfSight)`
  - `static void VCModChaseDriveTo(CVector dest)`
  - `static void VCModChaseStopHere(void)`
  - `static CVector VCModChaseBeatCoors(int32 beat)`
  - `nVCModChaseBeat`, `nVCModChaseStopUntil`, `bVCModChaseAtStop`

- [ ] **Step 1: Add the failing harness case**

Add `VCModChaseLeaderPressured` to the extraction list and these checks:

```c
    CHECK(VCModChaseLeaderPressured(10.0f, true), "pressure inside 25 m with sight");
    CHECK(!VCModChaseLeaderPressured(10.0f, false), "no pressure without sight");
    CHECK(!VCModChaseLeaderPressured(40.0f, true), "no pressure beyond 25 m");
```

- [ ] **Step 2: Run the harness and verify it fails**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: FAIL with `VCModChaseLeaderPressured not found`.

- [ ] **Step 3: Declare and implement the pure rule**

Header, after `VCModChaseHasEscaped`:

```cpp
bool VCModChaseLeaderPressured(float dist, bool lineOfSight);
```

Source:

```cpp
bool
VCModChaseLeaderPressured(float dist, bool lineOfSight)
{
	return dist < 25.0f && lineOfSight;
}
```

- [ ] **Step 4: Add the beat data and leg helpers**

Constants and state next to the scenario state:

```cpp
#define VCMOD_CHASE_BEAT_NEAR	7.0f
#define VCMOD_CHASE_STOP_TIME	5000

static const CVector vecVCModChaseBeatAnchor[2] = {
	CVector(398.57f, -560.00f, 11.75f),
	CVector(398.57f, -650.00f, 11.75f),
};
static CVector vecVCModChaseBeat[2];
static int32 nVCModChaseBeat;
static uint32 nVCModChaseStopUntil;
static bool bVCModChaseAtStop;
```

Helpers:

```cpp
static CVector
VCModChaseBeatCoors(int32 beat)
{
	return vecVCModChaseBeat[beat];
}

static void
VCModChaseDriveTo(CVector dest)
{
	CCarCtrl::JoinCarWithRoadSystemGotoCoors(pVCModChaseLeaderCar, dest, false);
	pVCModChaseLeaderCar->AutoPilot.m_nCarMission = MISSION_GOTOCOORDS;
	pVCModChaseLeaderCar->AutoPilot.m_nCruiseSpeed = 40;
	pVCModChaseLeaderCar->AutoPilot.m_nTempAction = TEMPACT_NONE;
	pVCModChaseLeaderCar->SetStatus(STATUS_PHYSICS);
}

static void
VCModChaseStopHere(void)
{
	pVCModChaseLeaderCar->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
	pVCModChaseLeaderCar->AutoPilot.m_nCruiseSpeed = 0;
	pVCModChaseLeaderCar->AutoPilot.m_nTempAction = TEMPACT_NONE;
}
```

In `VCModChaseSpawnLeader`, after the leader is set, resolve both anchors to car nodes and start the first leg:

```cpp
	for (int32 i = 0; i < 2; i++) {
		int32 n = ThePaths.FindNodeClosestToCoors(vecVCModChaseBeatAnchor[i], PATH_CAR, 80.0f, true, true);
		vecVCModChaseBeat[i] = n >= 0 ? ThePaths.m_pathNodes[n].GetPosition() : vecVCModChaseBeatAnchor[i];
	}
	nVCModChaseBeat = 0;
	nVCModChaseStopUntil = 0;
	bVCModChaseAtStop = false;
	VCModChaseDriveTo(VCModChaseBeatCoors(0));
```

- [ ] **Step 5: Advance the beats in the RUNNING block**

After the leash check and before the BACKSPACE check:

```cpp
		if (bVCModChaseAtStop) {
			if (CTimer::GetTimeInMilliseconds() > nVCModChaseStopUntil) {
				bVCModChaseAtStop = false;
				nVCModChaseBeat++;
				if (nVCModChaseBeat < 2) {
					VCModChaseDriveTo(VCModChaseBeatCoors(nVCModChaseBeat));
				} else {
					VCModChaseNotice("chase: the leader got away");
					VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_FINISH);
					VCModChaseClearScenario();
					VCModChaseEnd();
					break;
				}
			}
		} else if ((pVCModChaseLeaderCar->GetPosition() - VCModChaseBeatCoors(nVCModChaseBeat)).Magnitude2D() < VCMOD_CHASE_BEAT_NEAR) {
			bool sight = CWorld::GetIsLineOfSightClear(pVCModChaseLeader->GetPosition(),
				player->GetPosition(), true, false, false, false, false, false, false);
			if (VCModChaseLeaderPressured((pVCModChaseLeader->GetPosition() - player->GetPosition()).Magnitude2D(), sight)) {
				VCModChaseNotice("chase: the leader skipped his stop");
				nVCModChaseBeat++;
				if (nVCModChaseBeat < 2)
					VCModChaseDriveTo(VCModChaseBeatCoors(nVCModChaseBeat));
			} else {
				VCModChaseStopHere();
				bVCModChaseAtStop = true;
				nVCModChaseStopUntil = CTimer::GetTimeInMilliseconds() + VCMOD_CHASE_STOP_TIME;
			}
		}
```

- [ ] **Step 6: Harness, build and commit**

Run: `cd reVC && python3 utils/test_vc_chase.py -v` -> PASS.
Run: `scripts/build.sh` -> no errors.

```bash
git add src/extras/vcmodchase.h src/extras/vcmodchase.cpp utils/test_vc_chase.py
git commit -m "Drive the leader along a two-stop route with the pressure rule"
```

---

### Task 3: The Car Swap at the First Stop

**Files:**
- Modify: `src/extras/vcmodchase.cpp`

**Interfaces:**
- Consumes: `bVCModChaseAtStop`, `nVCModChaseBeat`, `nVCModChaseStopUntil`.
- Produces: `static bool VCModChaseStartSwap(void)`, `pVCModChaseSwapCar`, `bVCModChaseSwapping`.

- [ ] **Step 1: Add the swap state and spawner**

```cpp
#define VCMOD_CHASE_SWAP_CAR	MI_CHEETAH

static CVehicle *pVCModChaseSwapCar;
static bool bVCModChaseSwapping;
```

```cpp
static bool
VCModChaseStartSwap(void)
{
	CStreaming::RequestModel(VCMOD_CHASE_SWAP_CAR, 0);
	CStreaming::LoadAllRequestedModels(false);
	if (!CStreaming::HasModelLoaded(VCMOD_CHASE_SWAP_CAR))
		return false;

	CVector here = pVCModChaseLeaderCar->GetPosition();
	CAutomobile *car = new CAutomobile(VCMOD_CHASE_SWAP_CAR, RANDOM_VEHICLE);
	if (car == nil)
		return false;
	here.x += 6.0f;
	here.z += car->GetDistanceFromCentreOfMassToBaseOfModel();
	CTheScripts::ClearSpaceForMissionEntity(here, car);
	car->SetPosition(here);
	car->PlaceOnRoadProperly();
	car->SetStatus(STATUS_PHYSICS);
	car->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
	car->AutoPilot.m_nCruiseSpeed = 0;
	car->VehicleCreatedBy = MISSION_VEHICLE;
	CCarCtrl::NumRandomCars--;
	CCarCtrl::NumMissionCars++;
	CWorld::Add(car);

	pVCModChaseSwapCar = car;
	pVCModChaseLeader->SetObjective(OBJECTIVE_ENTER_CAR_AS_DRIVER, car);
	bVCModChaseSwapping = true;
	return true;
}
```

- [ ] **Step 2: Run the swap when the first stop begins**

When the stop is first entered and `nVCModChaseBeat == 0`, call `VCModChaseStartSwap()` once (guard with `bVCModChaseSwapping || pVCModChaseSwapCar != nil`).

- [ ] **Step 3: Finish the swap**

While `bVCModChaseSwapping`, if `pVCModChaseLeader->m_pMyVehicle == pVCModChaseSwapCar || (pVCModChaseLeader->GetPosition() - pVCModChaseSwapCar->GetPosition()).Magnitude2D() < 2.0f`:

```cpp
		if (pVCModChaseLeader->m_pMyVehicle != pVCModChaseSwapCar) {
			pVCModChaseLeader->SetObjective(OBJECTIVE_ENTER_CAR_AS_DRIVER, pVCModChaseSwapCar);
			pVCModChaseLeader->WarpPedIntoCar(pVCModChaseSwapCar);
		}
		pVCModChaseLeaderCar->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
		pVCModChaseLeaderCar = pVCModChaseSwapCar;
		pVCModChaseSwapCar = nil;
		bVCModChaseSwapping = false;
		nVCModChaseStopUntil = CTimer::GetTimeInMilliseconds() + 1000;
```

The old sedan stays where it is and is deleted with the scenario on end; record it in `pVCModChaseAbandonedCar` so cleanup deletes both. Add that field to `VCModChaseClearScenario`.

- [ ] **Step 4: Cleanup**

Add `pVCModChaseAbandonedCar` deletion in `VCModChaseClearScenario`, before the leader car:

```cpp
	if (pVCModChaseAbandonedCar != nil) {
		CWorld::Remove(pVCModChaseAbandonedCar);
		delete pVCModChaseAbandonedCar;
		pVCModChaseAbandonedCar = nil;
	}
```

- [ ] **Step 5: Build and commit**

Run: `scripts/build.sh` -> no errors.
Commit: `Add the leader's car swap at the first stop`.

---

### Task 4: The Accomplice Pickup at the Second Stop

**Files:**
- Modify: `src/extras/vcmodchase.cpp`

**Interfaces:**
- Consumes: the second stop, `pVCModChaseLeaderCar`.
- Produces: `static bool VCModChaseSpawnAccomplice(void)`, `pVCModChaseAccomplice`.

- [ ] **Step 1: Spawn the accomplice when the second stop begins**

```cpp
#define VCMOD_CHASE_ACCOMPLICE_MODEL	MI_MALE02

static CPed *pVCModChaseAccomplice;
```

```cpp
static bool
VCModChaseSpawnAccomplice(void)
{
	CStreaming::RequestModel(VCMOD_CHASE_ACCOMPLICE_MODEL, 0);
	CStreaming::LoadAllRequestedModels(false);
	if (!CStreaming::HasModelLoaded(VCMOD_CHASE_ACCOMPLICE_MODEL))
		return false;

	CVector here = pVCModChaseLeaderCar->GetPosition();
	here.x += 4.0f;
	CPed *ped = CPopulation::AddPed(PEDTYPE_CIVMALE, VCMOD_CHASE_ACCOMPLICE_MODEL, here);
	if (ped == nil)
		return false;
	ped->CharCreatedBy = MISSION_CHAR;
	ped->bIsPlayerFriend = false;
	ped->SetObjective(OBJECTIVE_ENTER_CAR_AS_PASSENGER, pVCModChaseLeaderCar);
	pVCModChaseAccomplice = ped;
	return true;
}
```

- [ ] **Step 2: Seat him when the leader's stop starts to end**

When the second stop timer fires, before driving on:

```cpp
		if (pVCModChaseAccomplice != nil && pVCModChaseAccomplice->m_pMyVehicle != pVCModChaseLeaderCar) {
			pVCModChaseAccomplice->SetObjective(OBJECTIVE_ENTER_CAR_AS_PASSENGER, pVCModChaseLeaderCar);
			pVCModChaseAccomplice->WarpPedIntoCar(pVCModChaseLeaderCar);
		}
```

- [ ] **Step 3: Cleanup**

Delete the accomplice with `CPopulation::RemovePed` in `VCModChaseClearScenario` before the cars.

- [ ] **Step 4: Final acceptance run**

Run: harness, then `scripts/build.sh`, then install only if reVC is not running and hand off for a launch. Acceptance: from the station marker, pick a tier, confirm twice, the leader spawns and drives; he stops twice; the chase reads correctly; killing him wins; letting him pull away long enough fails; after either, the uniform restores, the marker returns, and no mission ped, car or blip remains.

- [ ] **Step 5: Commit**

Commit: `Add the accomplice pickup and finish the ground chase`.

---

## Self-Review

- Spec coverage for P1a: leader spawn (Task 1), route and pressure (Task 2), swap (Task 3), pickup (Task 4), win/fail and cleanup (Tasks 1-4). The boat finale, squad, Enforcer and friendly fire are P1b, called out in Scope.
- Every code path deletes what it spawns; the abandoned sedan is tracked so a swap does not leak it.
- `SetUpDriver` runs before `VehicleCreatedBy = MISSION_VEHICLE`, matching `PlayerPed.cpp:696-705`.
- The harness only extracts functions with no engine types.
- Coordinates are anchors resolved to car path nodes at spawn; if the road is not where the anchor expects, the notice fires and the beat stays on the anchor, which the in-game pass will correct.
