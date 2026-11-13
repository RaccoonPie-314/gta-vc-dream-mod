# Vercetti crew Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A summoned Vercetti crew of three M4-armed gang members in a four-door car, driven by them or by Tommy, who follow and fight on foot and live on as a street gang when released.

**Architecture:** One new `extras/vcmodcrew` unit owns the car, the three men and a phase machine. It uses only stock objectives (`SetLeader`/`UpdateFromLeader`, `ENTER_CAR_AS_PASSENGER`, `LEAVE_CAR`) and the chauffeur's spawn/approach/handback patterns. Two mod keys drive it: `CREW` calls or dismisses, `PASSENGER` boards any car as a passenger. The `PASSENGER MODE` row is retired.

**Tech Stack:** C++98 in the reVC tree (CMake on macOS, premake on Windows), Python 3 unittest harnesses that extract production functions and compile them against stubs.

**Spec:** `docs/specs/2026-11-10-vercetti-crew-design.md`

## Global Constraints

- Never commit, tag, push or create branches: the owner handles git after play-testing.
- English only in code, UI, docs and filenames. Published artifacts name no AI, model or tool.
- `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` are read-only. Never delete, move or overwrite game data.
- Never install while a session runs: `pgrep -f "reVC.app/Contents/MacOS/reVC"` must print nothing.
- Mod code stays platform-neutral: everything new lives in `src/extras/`, no platform `#ifdef`, no absolute paths.
- Only stock engine objectives are used; no new AI.
- C++98 style as the tree: tabs, Allman braces, `nil` not `NULL`, `int32`/`uint32`/`int16`.
- Harnesses run as `python3 utils/test_vc_*.py` from `reVC/`.
- Build with `scripts/build.sh`; install with `scripts/install.sh` into `~/Games/VC`.

## File Map

Create:

- `reVC/src/extras/vcmodcrew.h` — the crew API and phases.
- `reVC/src/extras/vcmodcrew.cpp` — car shelf, summon, phases, boarding, handover, telemetry.
- `reVC/utils/test_vc_crew.py` — crew harness.

Modify:

- `reVC/src/extras/vcmodkeys.h` / `.cpp` — two key slots.
- `reVC/src/extras/vcmodpanel.h` / `.cpp` — remove `bVCModPassengerMode`; add `VCModPassengerKey`, `CALL CREW`, `CREW CAR`, KEYS rows.
- `reVC/src/peds/PlayerPed.cpp` — nearest car, passenger key, owned-car entry, key polls.
- `reVC/src/core/Game.cpp:942` — `VCModCrewUpdate()`.
- `reVC/src/peds/Ped.cpp:7055` — player-death hook.
- `reVC/src/core/re3.cpp` — ini keys; remove `PassengerMode`; `CrewCar`.
- `reVC/utils/test_vc_passenger.py`, `test_vc_keys.py`, `test_vc_character.py`, `test_vc_adrenaline.py` — key slots, row count/order, mode removal.
- `README.md` — driving section, key table.

---

### Task 1: The PASSENGER key replaces PASSENGER MODE

**Files:**
- Modify: `reVC/src/extras/vcmodkeys.h`, `reVC/src/extras/vcmodkeys.cpp`
- Modify: `reVC/src/extras/vcmodpanel.h`, `reVC/src/extras/vcmodpanel.cpp`
- Modify: `reVC/src/peds/PlayerPed.cpp`
- Modify: `reVC/src/core/re3.cpp`
- Modify: `reVC/utils/test_vc_passenger.py`, `test_vc_keys.py`, `test_vc_character.py`, `test_vc_adrenaline.py`
- Modify: `README.md`

**Interfaces:**
- Produces: `bool VCModPassengerKey(void)` in `vcmodpanel.h`; boards the nearest car as a passenger, driver optional.
- Produces: `static CVehicle *VCModNearestCar(CPlayerPed *player)` and `static bool VCModPassengerSeats(CVehicle *veh)` in `PlayerPed.cpp`.
- Changes: `VCModPassengerEntry(CVehicle*)` owns only the summoned limo; every other car returns false. The crew car branch lands in Task 3.

- [ ] **Step 1: Add the two key slots**

`vcmodkeys.h`, append to `eVCModKey` before `NUM_VCKEYS`:

```cpp
	VCKEY_CREW,		// calls or dismisses the Vercetti crew
	VCKEY_PASSENGER,	// boards the nearest car as a passenger
	NUM_VCKEYS
```

`vcmodkeys.cpp`, extend the three arrays in the same order:

```cpp
int32 aVCModKeys[NUM_VCKEYS] = {
	'\\', 'B', 'G', 'H', 'K', 'R', 'J', 'U', 'C', 'V', 'P'
};

static const int32 aVCModKeyDefaults[NUM_VCKEYS] = {
	'\\', 'B', 'G', 'H', 'K', 'R', 'J', 'U', 'C', 'V', 'P'
};

static const char *aVCModKeyLabels[NUM_VCKEYS] = {
	"PANEL KEY", "WALK MODE", "FIRE", "CALL DRIVER",
	"SPIN KICK", "RELOAD", "CHASE SPOT", "CHASE CAPTURE", "1ST PERSON",
	"CALL CREW", "PASSENGER"
};

static const char *aVCModKeyIniNames[NUM_VCKEYS] = {
	"KeyPanel", "KeyWalk", "KeyFire", "KeyDriver",
	"KeyKick", "KeyReload", "KeySpot", "KeyCapture", "KeyFirstPerson",
	"KeyCrew", "KeyPassenger"
};
```

- [ ] **Step 2: Remove `bVCModPassengerMode`**

`vcmodpanel.h`: delete `extern bool bVCModPassengerMode;`.
`vcmodpanel.cpp`: delete the definition (line 70), the row
`{ "PASSENGER MODE", VCMOD_ROW_FLAG, &bVCModPassengerMode, "PassengerMode", VCMOD_PAGE_DRIVING },`
(line 518) and `TWEAKBOOL(bVCModPassengerMode);` (line 705).
`re3.cpp`: delete the `PassengerMode` read (line 689) and add:

```cpp
	ReadIniIfExists("VC Mods", "KeyCrew", &aVCModKeys[VCKEY_CREW]);
	ReadIniIfExists("VC Mods", "KeyPassenger", &aVCModKeys[VCKEY_PASSENGER]);
```

- [ ] **Step 3: Write the failing passenger-key tests**

In `utils/test_vc_passenger.py`: delete `bVCModPassengerMode` from `RIDE_GLOBALS` and `reset()`, add `STATUS_WRECKED` to the status enum, add `bool EnteringCar(void) { return false; }` to `CPlayerPed`, and add a pooled nearest-car view:

```cpp
    int32 GetSize(void) { return 4; }
    CVehicle *GetSlot(int32 i) { return i >= 0 && i < 4 ? poolSlots[i] : nil; }
```

Extend `ride_functions`'s signature map:

```python
        "nearest": "static CVehicle *\nVCModNearestCar(CPlayerPed *player)",
        "seats": "static bool\nVCModPassengerSeats(CVehicle *veh)",
        "passkey": "bool\nVCModPassengerKey(void)",
```

Add tests; `standdown` needs `handback`, so include it:

```python
KEY_NAMES = ("notice", "vehicle", "release", "handback", "standdown",
             "seatfree", "nearest", "seats", "passkey")

    def test_key_boards_a_driven_car(self):
        run_cpp(ride_source(*KEY_NAMES) + r'''
int main() {
    CVehicle veh;
    reset(veh);
    veh.pDriver = &driverPed;
    playerPed.pos = CVector(2.0f, 0.0f, 0.0f);
    check(VCModPassengerKey(), "the key owns the press");
    check(playerPed.m_objective == OBJECTIVE_ENTER_CAR_AS_PASSENGER, "Tommy rides");
    check(veh.AutoPilot.m_nCarMission == MISSION_STOP_FOREVER, "the driven car is held");
    check(nVCModRidePhase == VCMOD_RIDE_BOARDING, "the ride watchdog arms");
}
''')

    def test_key_boards_an_empty_car(self):
        run_cpp(ride_source(*KEY_NAMES) + r'''
int main() {
    CVehicle veh;
    reset(veh);
    veh.pDriver = nil;
    playerPed.pos = CVector(2.0f, 0.0f, 0.0f);
    check(VCModPassengerKey(), "the key owns the press");
    check(playerPed.m_objective == OBJECTIVE_ENTER_CAR_AS_PASSENGER,
          "a passenger seat with nobody driving is allowed");
    check(veh.AutoPilot.m_nCarMission != MISSION_STOP_FOREVER, "an empty car is not frozen");
    check(nVCModRidePhase == VCMOD_RIDE_NONE, "no ride watchdog");
}
''')

    def test_key_refusals(self):
        run_cpp(ride_source(*KEY_NAMES) + r'''
int main() {
    CVehicle veh;
    reset(veh);
    playerPed.pos = CVector(50.0f, 0.0f, 0.0f);
    check(!VCModPassengerKey(), "no car nearby takes nothing");
    check(saw("notice:passenger: no car nearby"), "and says why");

    reset(veh);
    veh.pDriver = &driverPed;
    for (int i = 0; i < veh.m_nNumMaxPassengers; ++i) veh.pPassengers[i] = &driverPed;
    playerPed.pos = CVector(2.0f, 0.0f, 0.0f);
    check(!VCModPassengerKey(), "a full car is refused");
    check(saw("notice:passenger: every seat taken"), "and says why");
}
''')

    def test_f_on_a_street_car_is_stock(self):
        run_cpp(ride_source("notice", "vehicle", "release", "handback", "standdown",
                            "seatfree", "entry") + r'''
int main() {
    CVehicle veh;
    reset(veh);
    veh.pDriver = &driverPed;
    bVCModRideSummoned = false;
    check(!VCModPassengerEntry(&veh), "a street car press goes back to the game");
    check(playerPed.m_objective == OBJECTIVE_NONE, "and nothing is ordered");
}
''')
```

Remove the old mode off/on cases from `test_entry_decision_table`; keep the summoned-limo cases. Update the row count from 49 to **50** (mode row removed, two KEYS rows added) and start the row-order regex at `CALL DRIVER`.

- [ ] **Step 4: Run to fail**

```bash
cd reVC && python3 utils/test_vc_passenger.py
```

- [ ] **Step 5: Implement the key in `PlayerPed.cpp`**

After `VCModPassengerSeatFree`:

```cpp
#define VCMOD_PASSENGER_REACH	10.0f

static CVehicle *
VCModNearestCar(CPlayerPed *player)
{
	CVehicle *best = nil;
	float bestDist = VCMOD_PASSENGER_REACH;
	int32 n = CPools::GetVehiclePool()->GetSize();
	for (int32 i = 0; i < n; i++) {
		CVehicle *veh = CPools::GetVehiclePool()->GetSlot(i);
		if (veh == nil || veh->GetStatus() == STATUS_WRECKED)
			continue;
		if (veh->IsPlane() || veh->IsHeli() || veh->IsTrain())
			continue;
		float d = (veh->GetPosition() - player->GetPosition()).Magnitude2D();
		if (d < bestDist) {
			bestDist = d;
			best = veh;
		}
	}
	return best;
}

static bool
VCModPassengerSeats(CVehicle *veh)
{
	if (veh->IsPlane() || veh->IsHeli() || veh->IsTrain()) {
		VCModRideNotice("passenger: no seat in this");
		return false;
	}
	if (!VCModPassengerSeatFree(veh)) {
		VCModRideNotice("passenger: every seat taken");
		return false;
	}
	return true;
}

bool
VCModPassengerKey(void)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil || !player->IsPedInControl() || player->bInVehicle || player->EnteringCar())
		return false;

	CVehicle *veh = VCModNearestCar(player);
	if (veh == nil) {
		VCModRideNotice("passenger: no car nearby");
		return false;
	}
	if (!VCModPassengerSeats(veh))
		return false;

	if (veh->GetStatus() == STATUS_SIMPLE) {
		veh->SetStatus(STATUS_PHYSICS);
		CCarCtrl::SwitchVehicleToRealPhysics(veh);
	}

	bool summoned = bVCModRideSummoned && veh == VCModRideVehicle();

	if (veh->pDriver != nil) {
		if (nVCModRidePhase != VCMOD_RIDE_NONE && !summoned)
			VCModRideStandDown();
		bVCModRideTrafficSaved = !summoned;
		if (!summoned) {
			nVCModRideTrafficCruise = veh->AutoPilot.m_nCruiseSpeed;
			nVCModRideTrafficStyle = veh->AutoPilot.m_nDrivingStyle;
			fVCModRideTrafficMaxSpeed = veh->AutoPilot.m_fMaxTrafficSpeed;
		}
		veh->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
		veh->AutoPilot.m_nCruiseSpeed = 0;
		nVCModRideHandle = CPools::GetVehiclePool()->GetIndex(veh);
		nVCModRidePhase = VCMOD_RIDE_BOARDING;
		nVCModRideBoardAt = CTimer::GetTimeInMilliseconds();
		nVCModRideAppliedStyle = -1;
		bVCModRideSummoned = summoned;
	}

	player->SetObjective(OBJECTIVE_ENTER_CAR_AS_PASSENGER, veh);
	return true;
}
```

- [ ] **Step 6: Make the F entry the limo's only**

Replace the top of `VCModPassengerEntry`:

```cpp
bool
VCModPassengerEntry(CVehicle *vehicle)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil || !player->IsPedInControl() || player->bInVehicle || vehicle == nil)
		return false;

	// every car is the game's press unless it is the limo we called; the crew car
	// branch is added in Task 3
	bool summoned = bVCModRideSummoned && vehicle == VCModRideVehicle();
	if (!summoned)
		return false;

	// the rest of the old body follows, with "summoned" already known
```

Delete the old `if (!bVCModPassengerMode && !summoned) return false;` and the
`bool summoned = bVCModRideSummoned && vehicle == VCModRideVehicle();` that followed it.

- [ ] **Step 7: Poll the key**

In `CPlayerPed::ProcessControl`, inside the on-foot block (the one handling `VCKEY_KICK`):

```cpp
		if (KEYJUSTDOWN(aVCModKeys[VCKEY_PASSENGER]))
			VCModPassengerKey();
```

- [ ] **Step 8: KEYS page rows and declaration**

`vcmodpanel.h`: add `void VCModPassengerKey(void);`.
`vcmodpanel.cpp` KEYS page table, after `1ST PERSON KEY`:

```cpp
	{ "CALL CREW KEY",   VCMOD_ROW_KEY,     nil,                   nil,              VCMOD_PAGE_KEYS, nil, VCKEY_CREW },
	{ "PASSENGER KEY",   VCMOD_ROW_KEY,     nil,                   nil,              VCMOD_PAGE_KEYS, nil, VCKEY_PASSENGER },
```

- [ ] **Step 9: Other suites**

`test_vc_keys.py`: assert the eleven defaults, the two ini names, and `len(VCKEY_[A-Z]+,) == 11`.
`test_vc_character.py` and `test_vc_adrenaline.py`: stub eleven key slots and delete the `"PASSENGER MODE"` row assertion.

- [ ] **Step 10: README**

Replace the `PASSENGER MODE` paragraphs (around 331, 364, 372, 398) with: `P` boards the nearest car as a passenger, driver or not; `F` is stock everywhere except the summoned limo. Add `KeyCrew`/`KeyPassenger` to the key list at line 196.

- [ ] **Step 11: Run**

```bash
cd reVC && python3 utils/test_vc_passenger.py && python3 utils/test_vc_keys.py && python3 utils/test_vc_character.py && python3 utils/test_vc_adrenaline.py
```

---

### Task 2: Crew module, car shelf and summon

**Files:**
- Create: `reVC/src/extras/vcmodcrew.h`, `reVC/src/extras/vcmodcrew.cpp`
- Create: `reVC/utils/test_vc_crew.py`
- Modify: `reVC/src/core/Game.cpp:942`, `reVC/src/peds/PlayerPed.cpp`, `reVC/src/core/re3.cpp`

**Interfaces:**
- Produces: `void VCModCrewCall(void)`, `void VCModCrewUpdate(void)`, `int32 VCModCrewPhase(void)`, `CVehicle *VCModCrewVehicle(void)`, `bool VCModCrewOwnsCar(CVehicle*)`, `bool VCModCrewEntry(CVehicle*)`, `void VCModCrewPlayerDied(void)`, `int32 VCModCrewCarCount(void)`, `bool VCModCrewCarAt(int32, int16*, const char**)`, `void VCModCrewCarValidate(void)`, `extern int32 nVCModCrewCar`.
- `VCModCrewEntry` returns true for the crew car in this task; Task 3 adds the swap.

- [ ] **Step 1: Create `vcmodcrew.h`**

```cpp
#ifndef VCMODCREW_H
#define VCMODCREW_H

#include "Vector.h"

class CVehicle;

enum eVCModCrewPhase
{
	VCMOD_CREW_NONE,
	VCMOD_CREW_APPROACH,
	VCMOD_CREW_PICKUP,
	VCMOD_CREW_SWAP,
	VCMOD_CREW_ABOARD,
	VCMOD_CREW_ESCORT,
	VCMOD_CREW_DISMISS_WAIT
};

extern int32 nVCModCrewCar;

int32 VCModCrewCarCount(void);
bool VCModCrewCarAt(int32 entry, int16 *outModel, const char **outName);
void VCModCrewCarValidate(void);

int32 VCModCrewPhase(void);
CVehicle *VCModCrewVehicle(void);
bool VCModCrewOwnsCar(CVehicle *vehicle);
bool VCModCrewEntry(CVehicle *vehicle);
void VCModCrewCall(void);
void VCModCrewUpdate(void);
void VCModCrewPlayerDied(void);

#endif
```

- [ ] **Step 2: Create the harness**

`utils/test_vc_crew.py`:

```python
#!/usr/bin/env python3
"""Vercetti crew: the car shelf, the summon, the swap, the handover."""
import unittest
from pathlib import Path

from test_vc_passenger import ENGINE_STUBS, braced, ride_enums, run_cpp

ROOT = Path(__file__).resolve().parents[1]
CREW = (ROOT / "src/extras/vcmodcrew.cpp").read_text()
PANEL = (ROOT / "src/extras/vcmodpanel.cpp").read_text()
```

`CREW_STUBS` (order is the dependency order):

```python
CREW_STUBS = r'''
struct CVector2D {
    float x, y;
    CVector2D() : x(0), y(0) {}
    CVector2D(float a, float b) : x(a), y(b) {}
    void Normalise(void) { float m = (float)std::sqrt(x*x + y*y); if (m > 0) { x /= m; y /= m; } }
};
struct CVector : CVector2D {
    float z;
    CVector() : CVector2D(), z(0) {}
    CVector(float a, float b, float c) : CVector2D(a, b), z(c) {}
    CVector operator-(const CVector &o) const { return CVector(x-o.x, y-o.y, z-o.z); }
    CVector operator+(const CVector &o) const { return CVector(x+o.x, y+o.y, z+o.z); }
    CVector operator*(float s) const { return CVector(x*s, y*s, z*s); }
    float Magnitude(void) const { return (float)std::sqrt(x*x+y*y+z*z); }
    float Magnitude2D(void) const { return (float)std::sqrt(x*x+y*y); }
};

enum { STATUS_SIMPLE, STATUS_PHYSICS, STATUS_WRECKED, STATUS_ABANDONED };
enum { MISSION_NONE, MISSION_CRUISE, MISSION_GOTOCOORDS, MISSION_STOP_FOREVER };
enum { TEMPACT_NONE };
enum { DRIVINGSTYLE_STOP_FOR_CARS, DRIVINGSTYLE_PLOUGH_THROUGH };
enum { RANDOM_VEHICLE, MISSION_VEHICLE, PARKED_VEHICLE };
enum { RANDOM_CHAR, MISSION_CHAR, UNK_CHAR };
enum { PEDTYPE_GANG7 = 7, PEDTYPE_CIVMALE };
enum { WEAPONTYPE_M4 = 26 };
enum { GANG_PLAYER = 6 };
enum { MI_ADMIRAL = 10, MI_SENTINEL = 11, MI_INFERNUS = 12, MI_SEATS2 = 13,
       MI_M4 = 26, MI_PGA = 30, MI_PGB = 31 };
enum { OBJECTIVE_NONE, OBJECTIVE_ENTER_CAR_AS_DRIVER, OBJECTIVE_ENTER_CAR_AS_PASSENGER,
       OBJECTIVE_LEAVE_CAR, OBJECTIVE_WAIT_ON_FOOT, OBJECTIVE_FOLLOW_CHAR_IN_FORMATION,
       OBJECTIVE_KILL_CHAR_ON_FOOT, OBJECTIVE_KILL_CHAR_ANY_MEANS,
       OBJECTIVE_FLEE_ON_FOOT_TILL_SAFE };
enum { PATH_CAR };
enum { BLIP_CAR, BLIP_DISPLAY_BOTH };
enum { MITYPE_VEHICLE = 1, MITYPE_PED = 2 };
enum { VEHICLE_TYPE_CAR, VEHICLE_TYPE_BIKE };
typedef int32 eObjective;
enum eFormation { FORMATION_UNDEFINED, FORMATION_REAR, FORMATION_REAR_LEFT,
                  FORMATION_REAR_RIGHT, FORMATION_FRONT_LEFT, FORMATION_FRONT_RIGHT };
#define MODELINFOSIZE 16

struct CAutoPilot {
    int32 m_nCarMission, m_nTempAction, m_nDrivingStyle, m_nCruiseSpeed;
    float m_fMaxTrafficSpeed;
    CAutoPilot() : m_nCarMission(MISSION_NONE), m_nTempAction(TEMPACT_NONE),
                   m_nDrivingStyle(DRIVINGSTYLE_STOP_FOR_CARS), m_nCruiseSpeed(0),
                   m_fMaxTrafficSpeed(0) {}
};
struct CEntity {
    CVector pos, fwd, right, up;
    CEntity() : fwd(0,1,0), right(1,0,0), up(0,0,1) {}
    virtual ~CEntity() {}
    CVector GetPosition(void) { return pos; }
    void SetPosition(const CVector &p) { pos = p; }
    CVector &GetForward(void) { return fwd; }
    CVector &GetRight(void) { return right; }
    CVector &GetUp(void) { return up; }
    float GetDistanceFromCentreOfMassToBaseOfModel(void) { return 1.0f; }
    int32 GetModelIndex(void) { return MI_ADMIRAL; }
};
struct CVehicle;

struct CPed : CEntity {
    int32 m_nPedType; int32 CharCreatedBy; bool bIsPlayerFriend, bStayInCarOnJack;
    bool bInVehicle; bool bIsLeader; int32 m_objective; CEntity *m_pedInObjective;
    CEntity *m_leader; int32 model; int32 weapon; int32 ammo; int32 formation;
    CPed() : m_nPedType(PEDTYPE_GANG7), CharCreatedBy(RANDOM_CHAR),
             bIsPlayerFriend(false), bStayInCarOnJack(false), bInVehicle(false),
             bIsLeader(false), m_objective(OBJECTIVE_NONE), m_pedInObjective(nil),
             m_leader(nil), model(MI_PGA), weapon(0), ammo(0), formation(0) {}
    void SetObjective(int32 o, CEntity *target = nil) {
        events.push_back("objective:" + to_string(o));
        m_objective = o; m_pedInObjective = target;
    }
    void SetObjectiveTimer(uint32) {}
    void SetLeader(CEntity *l) { events.push_back("leader"); m_leader = l; }
    void ClearLeader(void) { events.push_back("clearleader"); m_leader = nil; }
    void GiveDelayedWeapon(int32 w, uint32 a) { weapon = w; ammo = (int32)a; }
    void SetCurrentWeapon(int32) {}
    void SetWanderPath(int32) { events.push_back("wander"); }
    void SetFormation(eFormation f) { formation = (int32)f; }
    bool Dead(void) { return false; }
    bool IsPedInControl(void) { return !bInVehicle; }
    void WarpPedIntoCar(CVehicle *car);
};

struct CVehicle : CEntity {
    int32 handle, status, VehicleCreatedBy, m_nNumMaxPassengers, m_nNumPassengers;
    CPed *pDriver, *pPassengers[8];
    CAutoPilot AutoPilot;
    CVehicle() : handle(5), status(STATUS_PHYSICS), VehicleCreatedBy(MISSION_VEHICLE),
                 m_nNumMaxPassengers(3), m_nNumPassengers(0), pDriver(nil) {
        for (int i = 0; i < 8; ++i) pPassengers[i] = nil;
    }
    int32 GetStatus(void) { return status; }
    void SetStatus(int32 s) { status = s; }
    bool IsPlane(void) { return false; }
    bool IsHeli(void) { return false; }
    bool IsTrain(void) { return false; }
    bool IsBike(void) { return false; }
};

void CPed::WarpPedIntoCar(CVehicle *car) {
    bInVehicle = true;
    if (m_objective == OBJECTIVE_ENTER_CAR_AS_DRIVER) {
        car->pDriver = this;
        events.push_back("warp:driver");
    } else {
        for (int i = 0; i < car->m_nNumMaxPassengers; ++i)
            if (car->pPassengers[i] == nil) {
                car->pPassengers[i] = this;
                car->m_nNumPassengers++;
                break;
            }
        events.push_back("warp:passenger");
    }
}

struct CPlayerPed : CPed {
    CVehicle *m_pMyVehicle;
    CPlayerPed() : m_pMyVehicle(nil) {}
    bool IsPedInControl(void) { return true; }
    bool InVehicle(void) { return bInVehicle && m_pMyVehicle; }
    bool EnteringCar(void) { return false; }
};
CPlayerPed playerPed;
CPlayerPed *FindPlayerPed(void) { return &playerPed; }

std::vector<CPed*> pedPool;
struct CPedPool {
    int32 GetIndex(CPed *p) {
        for (size_t i = 0; i < pedPool.size(); ++i) if (pedPool[i] == p) return (int32)i;
        return -1;
    }
    CPed *GetAt(int32 h) { return h >= 0 && (size_t)h < pedPool.size() ? pedPool[h] : nil; }
};
CPedPool pedPoolStore;
struct CVehiclePool {
    CVehicle *slots[4];
    CVehiclePool() { for (int i = 0; i < 4; ++i) slots[i] = nil; }
    int32 GetIndex(CVehicle *v) { return v->handle; }
    CVehicle *GetAt(int32 h) {
        for (int i = 0; i < 4; ++i)
            if (slots[i] && slots[i]->handle == h) return slots[i];
        return nil;
    }
    int32 GetSize(void) { return 4; }
    CVehicle *GetSlot(int32 i) { return i >= 0 && i < 4 ? slots[i] : nil; }
    void add(CVehicle *v) { for (int i = 0; i < 4; ++i) if (!slots[i]) { slots[i] = v; return; } }
};
CVehiclePool vehiclePool;
struct CPools {
    static CVehiclePool *GetVehiclePool(void) { return &vehiclePool; }
    static CPedPool *GetPedPool(void) { return &pedPoolStore; }
};

struct CAutomobile : CVehicle {
    CAutomobile(int32 id, uint8) { handle = 5; VehicleCreatedBy = MISSION_VEHICLE;
        (void)id; vehiclePool.add(this); }
    void PlaceOnRoadProperly(void) { events.push_back("onroad"); }
};

struct CCarCtrl {
    static int32 NumRandomCars, NumParkedCars, NumMissionCars;
    static void JoinCarWithRoadSystem(CVehicle*) {}
    static bool JoinCarWithRoadSystemGotoCoors(CVehicle*, CVector, bool) {
        events.push_back("goto"); return false;
    }
    static void SwitchVehicleToRealPhysics(CVehicle*) {}
};
int32 CCarCtrl::NumRandomCars = 0;
int32 CCarCtrl::NumParkedCars = 0;
int32 CCarCtrl::NumMissionCars = 0;

int32 missingModel = -1;
struct CStreaming {
    static void RequestModel(int32 m, int32) { events.push_back("request:" + to_string(m)); }
    static void LoadAllRequestedModels(bool) { events.push_back("loadall"); }
    static bool HasModelLoaded(int32 m) { return m != missingModel; }
};
struct CRadar {
    static int32 SetEntityBlip(int32, int32 h, uint32, int32) {
        events.push_back("blip:" + to_string(h)); return 1;
    }
    static void ClearBlipForEntity(int32, int32 h) { events.push_back("unblip:" + to_string(h)); }
};
struct CWorld {
    static void Add(CEntity*) { events.push_back("world:add"); }
    static void Remove(CEntity*) { events.push_back("world:remove"); }
    static void RemoveReferencesToDeletedObject(CEntity*) { events.push_back("deref"); }
    static float FindGroundZForCoord(float, float) { return 10.0f; }
};
struct CTheScripts {
    static void ClearSpaceForMissionEntity(const CVector&, CEntity*) { events.push_back("clearspace"); }
};
struct CHud {
    static void SetHelpMessage(wchar *msg, bool) {
        std::string t; for (int i = 0; i < 63 && msg[i]; ++i) t += (char)msg[i];
        events.push_back("notice:" + t);
    }
};
uint32 nowMs = 10000;
struct CTimer { static uint32 GetTimeInMilliseconds(void) { return nowMs; } };
struct CPathNode { CVector pos; CVector GetPosition(void) { return pos; } };
bool noRoad = false;
struct CPathFind {
    CPathNode m_pathNodes[4];
    int32 FindNodeClosestToCoors(CVector, uint8, float dist, bool = false, bool = false,
                                 bool = false, bool = false) {
        events.push_back("node:" + to_string((int)dist));
        if (noRoad) return -1;
        return dist > 100000.0f ? 2 : 1;
    }
};
CPathFind ThePaths;
struct CGeneral {
    static uint32 GetRandomNumber(void) { return 3; }
    static int32 GetRandomNumberInRange(int32 lo, int32) { return lo; }
};
struct CWeaponInfo {
    int32 m_nWeaponSlot;
    static CWeaponInfo *GetWeaponInfo(int32) { static CWeaponInfo w; w.m_nWeaponSlot = 5; return &w; }
};
struct CGangs { static int32 ChooseGangPedModel(int16) { return MI_PGA; } };
struct CPopulation {
    static CPed *AddPed(int32 type, int32 model, CVector pos) {
        CPed *p = new CPed();
        p->m_nPedType = type; p->model = model; p->pos = pos;
        pedPool.push_back(p);
        events.push_back("addped:" + to_string(model));
        return p;
    }
};
struct CModelInfo;
struct CBaseModelInfo {
    int32 type; const char *name; int32 doors;
    int32 GetModelType(void) { return type; }
    const char *GetModelName(void) { return name; }
};
struct CVehicleModelInfo : CBaseModelInfo {
    int32 m_vehicleType;
    static int32 GetMaximumNumberOfPassengersFromNumberOfDoors(int32 id) {
        CVehicleModelInfo *m = (CVehicleModelInfo*)CModelInfo::GetModelInfo(id);
        return m && m->doors > 0 ? m->doors - 1 : 1;
    }
};
struct CModelInfo { static CBaseModelInfo *GetModelInfo(int32); };
CVehicleModelInfo gModels[MODELINFOSIZE];
int32 gModelCount = 0;
CBaseModelInfo *CModelInfo::GetModelInfo(int32 id) {
    return id >= 0 && id < gModelCount ? &gModels[id] : nil;
}
int32 nVCModRideZone = -1;
int32 nVCModRideStyle = VCMOD_RIDE_SAFE;
static bool VCModRideZoneAt(int32 entry, int32 *out, const char **name, CVector *pos) {
    if (entry < 0 || entry > 3) return false;
    if (entry == 0) { if (out) *out = -1; if (name) *name = "traffic"; return true; }
    if (out) *out = entry;
    if (name) *name = "zone";
    if (pos) *pos = CVector(100.0f * entry, 200.0f * entry, 0.0f);
    return true;
}
'''
```

`ride_enums()` supplies `VCMOD_RIDE_SAFE/FAST`; do not redefine them here.

Extraction, all functions in one fixed list (the module's prototypes make the order free):

```python
SIGS = {
    "notice": "static void\nVCModCrewNotice(const char *text)",
    "carcount": "int32\nVCModCrewCarCount(void)",
    "carat": "bool\nVCModCrewCarAt(int32 entry, int16 *outModel, const char **outName)",
    "carbuild": "static void\nVCModCrewCarBuild(void)",
    "carvalidate": "void\nVCModCrewCarValidate(void)",
    "phase": "int32\nVCModCrewPhase(void)",
    "vehicle": "CVehicle *\nVCModCrewVehicle(void)",
    "ped": "static CPed *\nVCModCrewPed(int32 slot)",
    "ownscar": "bool\nVCModCrewOwnsCar(CVehicle *vehicle)",
    "style": "static void\nVCModCrewApplyStyle(CVehicle *car, bool goingSomewhere)",
    "addman": "static CPed *\nVCModCrewAddMan(CVehicle *car, int32 model, bool driver)",
    "removemen": "static void\nVCModCrewRemoveMen(void)",
    "removecar": "static void\nVCModCrewRemoveCar(void)",
    "reset": "static void\nVCModCrewReset(void)",
    "standdown": "static void\nVCModCrewStandDown(void)",
    "summon": "static bool\nVCModCrewSummon(CPlayerPed *player)",
    "call": "void\nVCModCrewCall(void)",
    "approach": "static void\nVCModCrewTickApproach(CPlayerPed *player, CVehicle *car)",
    "entry": "bool\nVCModCrewEntry(CVehicle *vehicle)",
    "telemetry": "static void\nVCModCrewTelemetry(CPlayerPed *player, CVehicle *car)",
    "update": "void\nVCModCrewUpdate(void)",
}


def crew_statics():
    start = CREW.index("#define VCMOD_CREW_SIZE")
    end = CREW.index("static void\nVCModCrewNotice")
    return CREW[start:end]


def crew_source():
    return (ENGINE_STUBS + CREW_STUBS + ride_enums() + crew_statics() +
            "\n".join(braced(CREW, SIGS[n]) for n in SIGS) + HELPERS)
```

Helpers:

```python
HELPERS = r'''
static int checks;
void check(bool ok, const char *name) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", name); std::exit(1); }
    ++checks;
}
bool saw(const char *event) {
    for (size_t i = 0; i < events.size(); ++i) if (events[i] == event) return true;
    return false;
}
void shelf(int32 id, const char *name, int32 doors) {
    gModels[id].type = MITYPE_VEHICLE;
    gModels[id].m_vehicleType = VEHICLE_TYPE_CAR;
    gModels[id].name = name;
    gModels[id].doors = doors;
    if (id + 1 > gModelCount) gModelCount = id + 1;
}
void clearPeds(void) {
    for (size_t i = 0; i < pedPool.size(); ++i) delete pedPool[i];
    pedPool.clear();
}
void reset(void) {
    events.clear();
    clearPeds();
    vehiclePool = CVehiclePool();
    ThePaths.m_pathNodes[1].pos = CVector(-80.0f, 0.0f, 0.0f);
    ThePaths.m_pathNodes[2].pos = CVector(150.0f, 250.0f, 0.0f);
    playerPed = CPlayerPed();
    playerPed.pos = CVector(0.0f, 0.0f, 0.0f);
    for (int i = 0; i < MODELINFOSIZE; ++i) {
        gModels[i].type = MITYPE_PED; gModels[i].name = "none";
        gModels[i].m_vehicleType = VEHICLE_TYPE_BIKE; gModels[i].doors = 0;
    }
    shelf(MI_ADMIRAL, "admiral", 4);
    shelf(MI_SENTINEL, "sentinel", 4);
    shelf(MI_INFERNUS, "infernus", 2);
    shelf(MI_SEATS2, "seats2", 2);
    nVCModCrewCar = MI_ADMIRAL;
    nVCModCrewCarCount = -1;
    nVCModCrewHandle = -1;
    for (int i = 0; i < VCMOD_CREW_SIZE; ++i) nVCModCrewPedHandle[i] = -1;
    nVCModCrewPhase = VCMOD_CREW_NONE;
    nVCModCrewRetargetAt = 0;
    nVCModCrewSwapAt = 0;
    bVCModCrewPlayerObjective = false;
    nowMs = 10000;
    missingModel = -1;
    noRoad = false;
    CCarCtrl::NumRandomCars = 0;
    CCarCtrl::NumParkedCars = 0;
    CCarCtrl::NumMissionCars = 0;
}
void carAtPickup(void) {
    CVehicle *car = VCModCrewVehicle();
    if (car) car->pos = playerPed.pos;
    nowMs += 100;
    VCModCrewUpdate();
}
'''
```

Tests:

```python
class CrewShelfTests(unittest.TestCase):
    def test_shelf_keeps_four_door_cars_only(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    check(VCModCrewCarCount() == 2, "only the two four-doors survive");
    int16 model; const char *name;
    check(VCModCrewCarAt(0, &model, &name) && model == MI_ADMIRAL, "admiral first");
    check(VCModCrewCarAt(1, &model, &name) && model == MI_SENTINEL, "then sentinel");
    nVCModCrewCar = MI_INFERNUS;
    VCModCrewCarValidate();
    check(nVCModCrewCar == MI_ADMIRAL, "an invalid saved car falls back");
}
''')


class SummonTests(unittest.TestCase):
    def test_summon_puts_three_armed_men_in_the_car(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    VCModCrewCall();
    CVehicle *car = VCModCrewVehicle();
    check(car != nil, "the car exists");
    check(car->VehicleCreatedBy == MISSION_VEHICLE, "and is mission-owned");
    check(pedPool.size() == 3, "three men are made");
    check(pedPool[0]->bInVehicle && car->pDriver == pedPool[0], "the first drives");
    check(pedPool[1]->m_objective == OBJECTIVE_ENTER_CAR_AS_PASSENGER, "the others ride");
    check(pedPool[0]->weapon == WEAPONTYPE_M4, "each carries the M4");
    check(pedPool[0]->CharCreatedBy == MISSION_CHAR, "they are mission chars");
    check(pedPool[0]->bStayInCarOnJack, "they stay on a jack");
    check(pedPool[0]->m_leader == (CEntity*)&playerPed, "and follow Tommy");
    check(nVCModCrewPhase == VCMOD_CREW_APPROACH, "the car is on its way");
    check(saw("notice:your crew is on the way"), "and says so");
}
''')

    def test_summon_failures(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    missingModel = MI_M4;
    VCModCrewCall();
    check(VCModCrewVehicle() == nil, "no M4, no crew");
    check(saw("notice:crew: the M4 cannot be loaded"), "and says why");

    reset();
    noRoad = true;
    VCModCrewCall();
    check(VCModCrewVehicle() == nil, "no road, no crew");
    check(saw("notice:crew: no road to come from"), "and says why");

    reset();
    playerPed.bInVehicle = true;
    VCModCrewCall();
    check(saw("notice:crew: get out first"), "a car seat refuses the call");
}
''')
```

- [ ] **Step 3: Run to fail**

```bash
cd reVC && python3 utils/test_vc_crew.py
```

- [ ] **Step 4: Implement `vcmodcrew.cpp`**

Includes:

```cpp
#include "common.h"

#include "vcmodcrew.h"
#include "vcmodpanel.h"

#include "Automobile.h"
#include "CarCtrl.h"
#include "Gangs.h"
#include "General.h"
#include "Hud.h"
#include "ModelInfo.h"
#include "PathFind.h"
#include "Ped.h"
#include "PedType.h"
#include "PlayerPed.h"
#include "Population.h"
#include "Radar.h"
#include "Script.h"
#include "Streaming.h"
#include "Vehicle.h"
#include "WeaponInfo.h"
#include "World.h"
```

Statics and prototypes (the prototypes let the functions appear in any order):

```cpp
#define VCMOD_CREW_SIZE		3
#define VCMOD_CREW_CAR_MAX	64
#define VCMOD_CREW_SPAWN_BACK	80.0f
#define VCMOD_CREW_PICKUP_NEAR	15.0f
#define VCMOD_CREW_RETARGET_NEAR	20.0f
#define VCMOD_CREW_RETARGET_WAIT	3000
#define VCMOD_CREW_ABANDON_FAR	120.0f
#define VCMOD_CREW_SWAP_FAR	10.0f
#define VCMOD_CREW_SWAP_TIMEOUT	6000
#define VCMOD_CREW_ARRIVE_NEAR	20.0f
#define VCMOD_CREW_M4_AMMO	25001

int32 nVCModCrewCar = MI_ADMIRAL;

static int16 aVCModCrewCars[VCMOD_CREW_CAR_MAX];
static int32 nVCModCrewCarCount = -1;
static int32 nVCModCrewHandle = -1;
static int32 nVCModCrewPedHandle[VCMOD_CREW_SIZE] = { -1, -1, -1 };
static int32 nVCModCrewPhase = VCMOD_CREW_NONE;
static CVector vecVCModCrewPickup;
static uint32 nVCModCrewRetargetAt;
static uint32 nVCModCrewSwapAt;
static bool bVCModCrewPlayerObjective;

static void VCModCrewNotice(const char *text);
static void VCModCrewCarBuild(void);
static CPed *VCModCrewPed(int32 slot);
static void VCModCrewApplyStyle(CVehicle *car, bool goingSomewhere);
static CPed *VCModCrewAddMan(CVehicle *car, int32 model, bool driver);
static void VCModCrewRemoveMen(void);
static void VCModCrewRemoveCar(void);
static void VCModCrewReset(void);
static void VCModCrewStandDown(void);
static bool VCModCrewSummon(CPlayerPed *player);
static void VCModCrewTickApproach(CPlayerPed *player, CVehicle *car);
static void VCModCrewTelemetry(CPlayerPed *player, CVehicle *car);
```

Notice and shelf:

```cpp
static void
VCModCrewNotice(const char *text)
{
	static wchar notice[64];
	int32 i;
	for (i = 0; i < (int32) ARRAY_SIZE(notice) - 1 && text[i] != '\0'; i++)
		notice[i] = (wchar) text[i];
	notice[i] = 0;
	CHud::SetHelpMessage(notice, false);
}

static void
VCModCrewCarBuild(void)
{
	nVCModCrewCarCount = 0;
	for (int32 i = 0; i < MODELINFOSIZE && nVCModCrewCarCount < VCMOD_CREW_CAR_MAX; i++) {
		CBaseModelInfo *info = CModelInfo::GetModelInfo(i);
		if (info == nil || info->GetModelType() != MITYPE_VEHICLE)
			continue;
		if (((CVehicleModelInfo*)info)->m_vehicleType != VEHICLE_TYPE_CAR)
			continue;
		if (CVehicleModelInfo::GetMaximumNumberOfPassengersFromNumberOfDoors(i) < 3)
			continue;
		int32 j = nVCModCrewCarCount;
		while (j > 0 && strcmp(((CBaseModelInfo*)CModelInfo::GetModelInfo(aVCModCrewCars[j-1]))->GetModelName(),
		                      info->GetModelName()) > 0) {
			aVCModCrewCars[j] = aVCModCrewCars[j-1];
			j--;
		}
		aVCModCrewCars[j] = i;
		nVCModCrewCarCount++;
	}
}

int32
VCModCrewCarCount(void)
{
	if (nVCModCrewCarCount < 0)
		VCModCrewCarBuild();
	return nVCModCrewCarCount;
}

bool
VCModCrewCarAt(int32 entry, int16 *outModel, const char **outName)
{
	if (entry < 0 || entry >= VCModCrewCarCount())
		return false;
	int32 model = aVCModCrewCars[entry];
	if (outModel) *outModel = model;
	if (outName) *outName = ((CBaseModelInfo*)CModelInfo::GetModelInfo(model))->GetModelName();
	return true;
}

void
VCModCrewCarValidate(void)
{
	for (int32 i = 0; i < VCModCrewCarCount(); i++)
		if (aVCModCrewCars[i] == nVCModCrewCar)
			return;
	nVCModCrewCar = MI_ADMIRAL;
}
```

Accessors and style:

```cpp
int32
VCModCrewPhase(void) { return nVCModCrewPhase; }

CVehicle *
VCModCrewVehicle(void)
{
	if (nVCModCrewHandle < 0)
		return nil;
	return CPools::GetVehiclePool()->GetAt(nVCModCrewHandle);
}

static CPed *
VCModCrewPed(int32 slot)
{
	if (slot < 0 || slot >= VCMOD_CREW_SIZE)
		return nil;
	int32 handle = nVCModCrewPedHandle[slot];
	if (handle < 0)
		return nil;
	CPed *ped = CPools::GetPedPool()->GetAt(handle);
	if (ped == nil || ped->m_nPedType != PEDTYPE_GANG7) {
		nVCModCrewPedHandle[slot] = -1;
		return nil;
	}
	return ped;
}

bool
VCModCrewOwnsCar(CVehicle *vehicle)
{
	return vehicle != nil && vehicle == VCModCrewVehicle();
}

static void
VCModCrewApplyStyle(CVehicle *car, bool goingSomewhere)
{
	car->SetStatus(STATUS_PHYSICS);
	if (nVCModRideStyle == VCMOD_RIDE_FAST) {
		car->AutoPilot.m_nDrivingStyle = DRIVINGSTYLE_PLOUGH_THROUGH;
		car->AutoPilot.m_nCruiseSpeed = goingSomewhere ? 55 : 45;
	} else {
		car->AutoPilot.m_nDrivingStyle = DRIVINGSTYLE_STOP_FOR_CARS;
		car->AutoPilot.m_nCruiseSpeed = goingSomewhere ? 25 : 20;
	}
}
```

Man and removal:

```cpp
static CPed *
VCModCrewAddMan(CVehicle *car, int32 model, bool driver)
{
	CPed *ped = CPopulation::AddPed(PEDTYPE_GANG7, model, car->GetPosition());
	if (ped == nil)
		return nil;
	ped->CharCreatedBy = MISSION_CHAR;
	ped->bIsPlayerFriend = true;
	ped->bStayInCarOnJack = true;
	ped->GiveDelayedWeapon(WEAPONTYPE_M4, VCMOD_CREW_M4_AMMO);
	ped->SetCurrentWeapon(CWeaponInfo::GetWeaponInfo(WEAPONTYPE_M4)->m_nWeaponSlot);
	ped->SetObjective(driver ? OBJECTIVE_ENTER_CAR_AS_DRIVER : OBJECTIVE_ENTER_CAR_AS_PASSENGER, car);
	ped->WarpPedIntoCar(car);
	ped->SetLeader(FindPlayerPed());
	return ped;
}

static void
VCModCrewRemoveMen(void)
{
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		CPed *ped = VCModCrewPed(i);
		nVCModCrewPedHandle[i] = -1;
		if (ped == nil)
			continue;
		CWorld::Remove(ped);
		CWorld::RemoveReferencesToDeletedObject(ped);
		delete ped;
	}
}

static void
VCModCrewRemoveCar(void)
{
	int32 handle = nVCModCrewHandle;
	CVehicle *car = VCModCrewVehicle();
	nVCModCrewHandle = -1;
	if (car == nil)
		return;
	CRadar::ClearBlipForEntity(BLIP_CAR, handle);
	CPlayerPed *player = FindPlayerPed();
	if (player != nil && player->InVehicle() && player->m_pMyVehicle == car) {
		if (car->VehicleCreatedBy == MISSION_VEHICLE) {
			car->VehicleCreatedBy = RANDOM_VEHICLE;
			CCarCtrl::NumMissionCars--;
			CCarCtrl::NumRandomCars++;
		}
		return;
	}
	CWorld::Remove(car);
	CWorld::RemoveReferencesToDeletedObject(car);
	delete car;
}

static void
VCModCrewReset(void)
{
	nVCModCrewHandle = -1;
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++)
		nVCModCrewPedHandle[i] = -1;
	nVCModCrewPhase = VCMOD_CREW_NONE;
	vecVCModCrewPickup = CVector(0.0f, 0.0f, 0.0f);
	nVCModCrewRetargetAt = 0;
	nVCModCrewSwapAt = 0;
	bVCModCrewPlayerObjective = false;
}

static void
VCModCrewStandDown(void)
{
	VCModCrewRemoveMen();
	VCModCrewRemoveCar();
	VCModCrewReset();
}
```

Summon (the handle is set before the men so the failure path can remove the car):

```cpp
static bool
VCModCrewSummon(CPlayerPed *player)
{
	VCModCrewCarValidate();
	CStreaming::RequestModel(nVCModCrewCar, 0);
	CStreaming::RequestModel(MI_M4, 0);
	CStreaming::RequestModel(MI_PGA, 0);
	CStreaming::RequestModel(MI_PGB, 0);
	CStreaming::LoadAllRequestedModels(false);
	if (!CStreaming::HasModelLoaded(nVCModCrewCar)) {
		VCModCrewNotice("crew: the car cannot be loaded");
		return false;
	}
	if (!CStreaming::HasModelLoaded(MI_M4)) {
		VCModCrewNotice("crew: the M4 cannot be loaded");
		return false;
	}
	if (!CStreaming::HasModelLoaded(MI_PGA) || !CStreaming::HasModelLoaded(MI_PGB)) {
		VCModCrewNotice("crew: the crew cannot be loaded");
		return false;
	}

	CVector here = player->GetPosition();
	CVector from = here - player->GetForward() * VCMOD_CREW_SPAWN_BACK;
	int32 node = ThePaths.FindNodeClosestToCoors(from, PATH_CAR, 60.0f, true, true);
	if (node < 0)
		node = ThePaths.FindNodeClosestToCoors(here, PATH_CAR, 200.0f, true, true);
	if (node < 0) {
		VCModCrewNotice("crew: no road to come from");
		return false;
	}

	CAutomobile *car = new CAutomobile(nVCModCrewCar, RANDOM_VEHICLE);
	if (car == nil) {
		VCModCrewNotice("crew: no room for the car");
		return false;
	}

	CVector pos = ThePaths.m_pathNodes[node].GetPosition();
	car->SetPosition(pos);
	CVector2D dir = here - pos;
	dir.Normalise();
	car->GetForward() = CVector(dir.x, dir.y, 0.0f);
	car->GetRight() = CVector(dir.y, -dir.x, 0.0f);
	car->GetUp() = CVector(0.0f, 0.0f, 1.0f);
	pos.z += car->GetDistanceFromCentreOfMassToBaseOfModel();
	car->SetPosition(pos);
	car->PlaceOnRoadProperly();
	car->SetStatus(STATUS_PHYSICS);
	car->VehicleCreatedBy = MISSION_VEHICLE;
	CCarCtrl::NumRandomCars--;
	CCarCtrl::NumMissionCars++;
	CTheScripts::ClearSpaceForMissionEntity(pos, car);
	CWorld::Add(car);
	nVCModCrewHandle = CPools::GetVehiclePool()->GetIndex(car);

	int32 made = 0;
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		int32 model = CGangs::ChooseGangPedModel(GANG_PLAYER);
		CPed *ped = VCModCrewAddMan(car, model, i == 0);
		if (ped == nil)
			break;
		nVCModCrewPedHandle[i] = CPools::GetPedPool()->GetIndex(ped);
		made++;
	}
	if (made < VCMOD_CREW_SIZE) {
		VCModCrewStandDown();
		VCModCrewNotice("crew: the men could not be made");
		return false;
	}

	CRadar::SetEntityBlip(BLIP_CAR, nVCModCrewHandle, 0, BLIP_DISPLAY_BOTH);
	nVCModCrewPhase = VCMOD_CREW_APPROACH;
	vecVCModCrewPickup = here;
	nVCModCrewRetargetAt = 0;
	CCarCtrl::JoinCarWithRoadSystemGotoCoors(car, here, false);
	car->AutoPilot.m_nCarMission = MISSION_GOTOCOORDS;
	car->AutoPilot.m_nTempAction = TEMPACT_NONE;
	VCModCrewApplyStyle(car, true);
	VCModCrewNotice("your crew is on the way");
	return true;
}
```

Approach, call, entry, telemetry and update:

```cpp
static void
VCModCrewTickApproach(CPlayerPed *player, CVehicle *car)
{
	if (player->InVehicle()) {
		VCModCrewStandDown();
		return;
	}
	CVector here = player->GetPosition();
	if ((here - vecVCModCrewPickup).Magnitude2D() > VCMOD_CREW_RETARGET_NEAR &&
			CTimer::GetTimeInMilliseconds() >= nVCModCrewRetargetAt) {
		vecVCModCrewPickup = here;
		nVCModCrewRetargetAt = CTimer::GetTimeInMilliseconds() + VCMOD_CREW_RETARGET_WAIT;
		CCarCtrl::JoinCarWithRoadSystemGotoCoors(car, here, false);
		car->AutoPilot.m_nCarMission = MISSION_GOTOCOORDS;
	}
	if ((car->GetPosition() - vecVCModCrewPickup).Magnitude2D() < VCMOD_CREW_PICKUP_NEAR) {
		car->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
		car->AutoPilot.m_nCruiseSpeed = 0;
		CRadar::ClearBlipForEntity(BLIP_CAR, nVCModCrewHandle);
		nVCModCrewPhase = VCMOD_CREW_PICKUP;
		VCModCrewNotice("your crew is here");
	}
}

void
VCModCrewCall(void)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil || !player->IsPedInControl())
		return;
	if (nVCModCrewPhase != VCMOD_CREW_NONE) {
		VCModCrewNotice("crew: already out");
		return;
	}
	if (player->bInVehicle) {
		VCModCrewNotice("crew: get out first");
		return;
	}
	VCModCrewSummon(player);
}

bool
VCModCrewEntry(CVehicle *vehicle)
{
	if (!VCModCrewOwnsCar(vehicle))
		return false;
	// Task 3 owns the boarding rules; for now the press is ours, never a carjack
	return true;
}

static void
VCModCrewTelemetry(CPlayerPed *player, CVehicle *car)
{
	static uint32 next;
	uint32 now = CTimer::GetTimeInMilliseconds();
	if (now < next)
		return;
	next = now + 1000;
	fprintf(stderr, "VCMOD CREW state phase %d car %p seat %d driver %d speed %.1f pos %.1f %.1f %.1f\n",
		(int) nVCModCrewPhase, (void*) car,
		player->InVehicle() && player->m_pMyVehicle == car,
		car->pDriver == player ? 1 : car->pDriver != nil,
		car->AutoPilot.m_nCruiseSpeed,
		car->GetPosition().x, car->GetPosition().y, car->GetPosition().z);
}

void
VCModCrewUpdate(void)
{
	CPlayerPed *player = FindPlayerPed();
	if (nVCModCrewPhase == VCMOD_CREW_NONE)
		return;
	CVehicle *car = VCModCrewVehicle();
	if (player == nil || car == nil) {
		VCModCrewStandDown();
		return;
	}
	switch (nVCModCrewPhase) {
	case VCMOD_CREW_APPROACH:	VCModCrewTickApproach(player, car); break;
	default:			break;
	}
	VCModCrewTelemetry(player, car);
}
```

- [ ] **Step 5: Wire the tick, the key and the ini**

`Game.cpp` after `VCModChaseUpdate();`: `VCModCrewUpdate();`, with `#include "vcmodcrew.h"`.

`PlayerPed.cpp`, next to the `VCKEY_DRIVER` poll (outside the on-foot block):

```cpp
	if (padUsed && !padUsed->ArePlayerControlsDisabled() && !VCModKeyCapturing() &&
	    KEYJUSTDOWN(aVCModKeys[VCKEY_CREW]))
		VCModCrewCall();
```

`re3.cpp`: `ReadIniIfExists("VC Mods", "CrewCar", &nVCModCrewCar);`. The validate runs in `VCModCrewSummon`.

- [ ] **Step 6: Run and build**

```bash
cd reVC && python3 utils/test_vc_crew.py
cd .. && scripts/build.sh
```

---

### Task 3: Pick-up, the F wheel handover, no carjack

**Files:**
- Modify: `reVC/src/extras/vcmodcrew.cpp`
- Modify: `reVC/src/peds/PlayerPed.cpp`
- Modify: `reVC/utils/test_vc_crew.py`, `test_vc_passenger.py`

**Interfaces:**
- Produces: `static void VCModCrewTickPickup(CPlayerPed*, CVehicle*)`, `static void VCModCrewTickSwap(CPlayerPed*, CVehicle*)`.
- `VCModPassengerEntry` calls `VCModCrewEntry`; `VCModPassengerKey` skips the hold for the crew car.

- [ ] **Step 1: Add the signatures to the harness**

Append to `SIGS`:

```python
    "pickup": "static void\nVCModCrewTickPickup(CPlayerPed *player, CVehicle *car)",
    "swap": "static void\nVCModCrewTickSwap(CPlayerPed *player, CVehicle *car)",
```

- [ ] **Step 2: Add the tests**

```python
class BoardingTests(unittest.TestCase):
    def test_f_takes_the_wheel_without_a_carjack(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    VCModCrewCall();
    carAtPickup();
    check(nVCModCrewPhase == VCMOD_CREW_PICKUP, "the car stops inside the ring");
    CPed *driver = pedPool[0];

    check(VCModCrewEntry(VCModCrewVehicle()), "the press on our car is ours");
    check(driver->m_objective == OBJECTIVE_LEAVE_CAR, "the driver is told to get out");
    check(playerPed.m_objective == OBJECTIVE_NONE, "Tommy is not sent at a taken seat");

    driver->bInVehicle = false;
    VCModCrewVehicle()->pDriver = nil;
    nowMs += 1000;
    VCModCrewUpdate();
    check(playerPed.m_objective == OBJECTIVE_ENTER_CAR_AS_DRIVER,
          "the seat is handed over once it is clear");

    playerPed.bInVehicle = true;
    playerPed.m_pMyVehicle = VCModCrewVehicle();
    VCModCrewUpdate();
    check(driver->m_objective == OBJECTIVE_ENTER_CAR_AS_PASSENGER,
          "the ex-driver takes the free seat");
    check(nVCModCrewPhase == VCMOD_CREW_ABOARD, "and the crew is aboard");
}
''')

    def test_swap_aborts_when_tommy_walks_away(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    VCModCrewCall();
    carAtPickup();
    CPed *driver = pedPool[0];
    VCModCrewEntry(VCModCrewVehicle());
    playerPed.pos = CVector(40.0f, 0.0f, 0.0f);
    nowMs += 1000;
    VCModCrewUpdate();
    check(nVCModCrewPhase == VCMOD_CREW_PICKUP, "walking away aborts the handover");
    check(driver->m_objective == OBJECTIVE_NONE,
          "the driver stays at the wheel, with no leave objective left");
}
''')
```

- [ ] **Step 3: Implement**

```cpp
static void
VCModCrewTickPickup(CPlayerPed *player, CVehicle *car)
{
	CVector here = player->GetPosition();
	if ((here - car->GetPosition()).Magnitude2D() > VCMOD_CREW_ABANDON_FAR) {
		VCModCrewNotice("crew left: too far away");
		VCModCrewStandDown();
		return;
	}
	if (player->InVehicle()) {
		if (player->m_pMyVehicle != car) {
			VCModCrewStandDown();
			return;
		}
		nVCModCrewPhase = VCMOD_CREW_ABOARD;
	}
}

bool
VCModCrewEntry(CVehicle *vehicle)
{
	if (!VCModCrewOwnsCar(vehicle))
		return false;
	// every press on the crew car belongs to us; none of them may become a carjack
	if (nVCModCrewPhase == VCMOD_CREW_APPROACH) {
		VCModCrewNotice("crew: wait for the car to stop");
		return true;
	}
	if (nVCModCrewPhase != VCMOD_CREW_PICKUP)
		return true;

	CPlayerPed *player = FindPlayerPed();
	if (player == nil || player->bInVehicle)
		return true;
	if (vehicle->pDriver == nil)
		return false;	// empty crew car: the stock driver entry is right

	CPed *driver = vehicle->pDriver;
	if (driver->m_nPedType != PEDTYPE_GANG7)
		return false;

	driver->ClearLeader();
	driver->SetObjective(OBJECTIVE_LEAVE_CAR, vehicle);
	nVCModCrewSwapAt = CTimer::GetTimeInMilliseconds();
	bVCModCrewPlayerObjective = false;
	nVCModCrewPhase = VCMOD_CREW_SWAP;
	VCModCrewNotice("the driver is getting out");
	return true;
}

static void
VCModCrewTickSwap(CPlayerPed *player, CVehicle *car)
{
	CPed *driver = car->pDriver != nil ? car->pDriver : VCModCrewPed(0);
	if (!bVCModCrewPlayerObjective && car->pDriver == nil &&
			(driver == nil || !driver->bInVehicle)) {
		if (driver != nil) {
			driver->SetObjective(OBJECTIVE_WAIT_ON_FOOT);
			driver->SetObjectiveTimer(0);
		}
		player->SetObjective(OBJECTIVE_ENTER_CAR_AS_DRIVER, car);
		bVCModCrewPlayerObjective = true;
	}
	if (player->InVehicle() && player->m_pMyVehicle == car) {
		nVCModCrewPhase = VCMOD_CREW_ABOARD;
		if (driver != nil) {
			driver->SetLeader(player);
			driver->SetObjective(OBJECTIVE_ENTER_CAR_AS_PASSENGER, car);
		}
		return;
	}
	if (CTimer::GetTimeInMilliseconds() - nVCModCrewSwapAt > VCMOD_CREW_SWAP_TIMEOUT ||
			(player->GetPosition() - car->GetPosition()).Magnitude2D() > VCMOD_CREW_SWAP_FAR) {
		if (driver != nil && driver->bInVehicle && car->pDriver == driver)
			driver->SetObjective(OBJECTIVE_NONE);
		else if (driver != nil)
			driver->SetObjective(OBJECTIVE_ENTER_CAR_AS_DRIVER, car);
		bVCModCrewPlayerObjective = false;
		nVCModCrewPhase = VCMOD_CREW_PICKUP;
		VCModCrewNotice("crew: the driver is back at the wheel");
	}
}
```

Add the two prototypes to the statics block and the two cases to the update switch.

- [ ] **Step 4: Wire the entry and the key**

`PlayerPed.cpp`: include `vcmodcrew.h`; in `VCModPassengerEntry`, before the limo check:

```cpp
	if (VCModCrewEntry(vehicle))
		return true;
```

In `VCModPassengerKey`, add the crew exclusion:

```cpp
	bool crewCar = VCModCrewOwnsCar(veh);
	bool summoned = bVCModRideSummoned && veh == VCModRideVehicle();

	if (veh->pDriver != nil && !crewCar) {
```

The body of that `if` is unchanged from Task 1.

- [ ] **Step 5: Passenger harness stubs**

`test_vc_passenger.py`: add

```cpp
bool VCModCrewOwnsCar(CVehicle*) { return false; }
bool VCModCrewEntry(CVehicle*) { return false; }
```

so the extracted `entry`/`passkey` link. Add `crewcar`-agnostic tests only.

- [ ] **Step 6: Run**

```bash
cd reVC && python3 utils/test_vc_crew.py && python3 utils/test_vc_passenger.py
```

---

### Task 4: Aboard, fill, ride mission, escort

**Files:**
- Modify: `reVC/src/extras/vcmodcrew.cpp`
- Modify: `reVC/utils/test_vc_crew.py`

**Interfaces:**
- Produces: `static void VCModCrewTickAboard`, `VCModCrewTickEscort`, `VCModCrewFill`, `VCModCrewDrive`, `static bool VCModCrewSeatFree`.

- [ ] **Step 1: Extend the harness**

Statics additions (in `vcmodcrew.cpp`, so the harness picks them up):

```cpp
static int32 nVCModCrewAppliedZone = -2;
static CVector vecVCModCrewDestination;
static bool bVCModCrewHasDestination;
static uint32 nVCModCrewDismissAt;
```

Add to `SIGS`:

```python
    "seatfree": "static bool\nVCModCrewSeatFree(CVehicle *car)",
    "fill": "static void\nVCModCrewFill(CPlayerPed *player, CVehicle *car)",
    "drive": "static void\nVCModCrewDrive(CVehicle *car)",
    "aboard": "static void\nVCModCrewTickAboard(CPlayerPed *player, CVehicle *car)",
    "escort": "static void\nVCModCrewTickEscort(CPlayerPed *player, CVehicle *car)",
```

Extend `reset()` with `nVCModCrewAppliedZone = -2; bVCModCrewHasDestination = false; nVCModCrewDismissAt = 0;`.

- [ ] **Step 2: Add the test**

```python
    def test_passenger_ride_fills_the_driver_and_the_seats(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    VCModCrewCall();
    carAtPickup();
    CVehicle *car = VCModCrewVehicle();
    car->pDriver = nil;
    car->m_nNumPassengers = 0;
    for (int i = 0; i < car->m_nNumMaxPassengers; ++i) car->pPassengers[i] = nil;
    for (int i = 0; i < 3; ++i) { pedPool[i]->bInVehicle = false; pedPool[i]->m_objective = OBJECTIVE_NONE; }
    playerPed.bInVehicle = true;
    playerPed.m_pMyVehicle = car;
    VCModCrewUpdate();	// PICKUP -> ABOARD
    VCModCrewUpdate();	// fill
    check(car->pDriver == pedPool[0], "one man takes the wheel");
    check(pedPool[1]->m_objective == OBJECTIVE_ENTER_CAR_AS_PASSENGER,
          "the second man boards passenger");
    check(pedPool[0]->m_leader == nil, "the boarding men are unlinked while walking");
}
''')
```

- [ ] **Step 3: Implement**

```cpp
static bool
VCModCrewSeatFree(CVehicle *car)
{
	for (int32 i = 0; i < car->m_nNumMaxPassengers; i++)
		if (car->pPassengers[i] == nil)
			return true;
	return false;
}

static void
VCModCrewFill(CPlayerPed *player, CVehicle *car)
{
	bool driverNeeded = car->pDriver == nil;
	bool playerDriving = player->InVehicle() && player->m_pMyVehicle == car &&
		car->pDriver == player;
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		CPed *ped = VCModCrewPed(i);
		if (ped == nil || ped->bInVehicle)
			continue;
		// riding as a passenger: UpdateFromLeader would keep calling the men to
		// the car, so the link is lifted until each man is seated
		if (!playerDriving && ped->m_leader != nil)
			ped->ClearLeader();
		if (ped->m_objective == OBJECTIVE_ENTER_CAR_AS_PASSENGER ||
				ped->m_objective == OBJECTIVE_ENTER_CAR_AS_DRIVER)
			continue;
		if (driverNeeded) {
			ped->SetObjective(OBJECTIVE_ENTER_CAR_AS_DRIVER, car);
			driverNeeded = false;
		} else if (VCModCrewSeatFree(car)) {
			ped->SetObjective(OBJECTIVE_ENTER_CAR_AS_PASSENGER, car);
		}
	}
}

static void
VCModCrewDrive(CVehicle *car)
{
	int32 zoneIndex;
	CVector dest;
	if (VCModRideZoneAt(nVCModRideZone, &zoneIndex, nil, &dest) && zoneIndex >= 0) {
		CCarCtrl::JoinCarWithRoadSystemGotoCoors(car, dest, false);
		car->AutoPilot.m_nCarMission = MISSION_GOTOCOORDS;
		vecVCModCrewDestination = dest;
		bVCModCrewHasDestination = true;
		VCModCrewApplyStyle(car, true);
	} else {
		CCarCtrl::JoinCarWithRoadSystem(car);
		car->AutoPilot.m_nCarMission = MISSION_CRUISE;
		bVCModCrewHasDestination = false;
		VCModCrewApplyStyle(car, false);
	}
	car->AutoPilot.m_nTempAction = TEMPACT_NONE;
	nVCModCrewAppliedZone = nVCModRideZone;
}

static void
VCModCrewTickAboard(CPlayerPed *player, CVehicle *car)
{
	if (!player->InVehicle() || player->m_pMyVehicle != car) {
		nVCModCrewPhase = VCMOD_CREW_ESCORT;
		return;
	}
	VCModCrewFill(player, car);
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		CPed *ped = VCModCrewPed(i);
		if (ped != nil && ped->bInVehicle && ped->m_leader == nil)
			ped->SetLeader(player);
	}
	if (car->pDriver != player) {
		if (nVCModCrewAppliedZone != nVCModRideZone)
			VCModCrewDrive(car);
		if (bVCModCrewHasDestination &&
				(car->GetPosition() - vecVCModCrewDestination).Magnitude2D() < VCMOD_CREW_ARRIVE_NEAR) {
			car->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
			car->AutoPilot.m_nCruiseSpeed = 0;
			car->AutoPilot.m_nTempAction = TEMPACT_NONE;
			bVCModCrewHasDestination = false;
			VCModCrewNotice("your crew has arrived");
		}
	}
}

static void
VCModCrewTickEscort(CPlayerPed *player, CVehicle *car)
{
	if (player->InVehicle() && player->m_pMyVehicle == car)
		nVCModCrewPhase = VCMOD_CREW_ABOARD;
}
```

Add the prototypes and the switch cases (`ABOARD`, `ESCORT`).

- [ ] **Step 4: Run**

```bash
cd reVC && python3 utils/test_vc_crew.py
```

---

### Task 5: Dismissal, handover, death and cleanup

**Files:**
- Modify: `reVC/src/extras/vcmodcrew.cpp`
- Modify: `reVC/src/peds/Ped.cpp:7055`
- Modify: `reVC/utils/test_vc_crew.py`

**Interfaces:**
- Produces: `void VCModCrewPlayerDied(void)`, `static void VCModCrewHandover(void)`, `static void VCModCrewDismiss(void)`, `static void VCModCrewTickDismissWait(CPlayerPed*, CVehicle*)`, `static void VCModCrewRemoveDead(void)`.

- [ ] **Step 1: Extend the harness**

Add to `SIGS`:

```python
    "dismiss": "static void\nVCModCrewDismiss(void)",
    "handover": "static void\nVCModCrewHandover(void)",
    "dismisswait": "static void\nVCModCrewTickDismissWait(CPlayerPed *player, CVehicle *car)",
    "died": "void\nVCModCrewPlayerDied(void)",
    "removedead": "static void\nVCModCrewRemoveDead(void)",
```

- [ ] **Step 2: Add the tests**

```python
    def test_dismiss_hands_the_gang_member_to_member(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    VCModCrewCall();
    carAtPickup();
    for (int i = 0; i < 3; ++i) pedPool[i]->bInVehicle = false;
    VCModCrewVehicle()->pDriver = nil;
    VCModCrewVehicle()->m_nNumPassengers = 0;
    for (int i = 0; i < VCModCrewVehicle()->m_nNumMaxPassengers; ++i)
        VCModCrewVehicle()->pPassengers[i] = nil;
    VCModCrewVehicle()->pos = CVector(2.0f, 0.0f, 0.0f);
    playerPed.bInVehicle = false;
    VCModCrewUpdate();
    check(nVCModCrewPhase == VCMOD_CREW_ESCORT, "on foot");

    VCModCrewCall();	// dismiss
    check(saw("clearleader"), "Tommy's links are cut");
    check(pedPool[0]->CharCreatedBy == RANDOM_CHAR, "the world may take them");
    check(pedPool.size() == 3, "nobody is despawned on dismissal");
    check(nVCModCrewPhase == VCMOD_CREW_NONE, "the crew state is over");
}
''')

    def test_death_hands_over_and_does_not_flee(self):
        run_cpp(crew_source() + r'''
int main() {
    reset();
    VCModCrewCall();
    carAtPickup();
    for (int i = 0; i < 3; ++i) pedPool[i]->bInVehicle = false;
    VCModCrewVehicle()->pDriver = nil;
    VCModCrewVehicle()->m_nNumPassengers = 0;
    for (int i = 0; i < VCModCrewVehicle()->m_nNumMaxPassengers; ++i)
        VCModCrewVehicle()->pPassengers[i] = nil;
    VCModCrewVehicle()->pos = CVector(2.0f, 0.0f, 0.0f);
    playerPed.bInVehicle = false;
    VCModCrewUpdate();
    VCModCrewPlayerDied();
    check(nVCModCrewPhase == VCMOD_CREW_NONE, "the crew is handed to the street");
    check(pedPool[0]->CharCreatedBy == RANDOM_CHAR, "and the world may take them");
    check(pedPool[0]->m_objective != OBJECTIVE_FLEE_ON_FOOT_TILL_SAFE,
          "the dead-leader flee never lands");
    check(pedPool.size() == 3, "nobody is despawned on death");
}
''')
```

- [ ] **Step 3: Implement**

```cpp
static void
VCModCrewHandover(void)
{
	CPed *living[VCMOD_CREW_SIZE];
	int32 n = 0;
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		CPed *ped = VCModCrewPed(i);
		if (ped != nil && !ped->Dead())
			living[n++] = ped;
	}
	if (n == 0)
		return;

	CPed *leader = living[CGeneral::GetRandomNumberInRange(0, n)];
	for (int32 i = 0; i < n; i++) {
		CPed *ped = living[i];
		// a fight already running survives the handover; only a flee is replaced
		eObjective keep = (eObjective) ped->m_objective;
		CEntity *target = ped->m_pedInObjective;
		ped->ClearLeader();
		ped->bIsPlayerFriend = false;
		ped->bStayInCarOnJack = false;
		ped->CharCreatedBy = RANDOM_CHAR;
		if (keep == OBJECTIVE_KILL_CHAR_ON_FOOT || keep == OBJECTIVE_KILL_CHAR_ANY_MEANS)
			ped->SetObjective(keep, target);
	}
	for (int32 i = 0; i < n; i++) {
		CPed *ped = living[i];
		if (ped == leader)
			continue;
		ped->SetLeader(leader);
		if (ped->m_objective != OBJECTIVE_KILL_CHAR_ON_FOOT &&
				ped->m_objective != OBJECTIVE_KILL_CHAR_ANY_MEANS) {
			ped->SetObjective(OBJECTIVE_FOLLOW_CHAR_IN_FORMATION, leader);
			ped->SetFormation((eFormation) i);
		}
	}
	if (leader->m_objective != OBJECTIVE_KILL_CHAR_ON_FOOT &&
			leader->m_objective != OBJECTIVE_KILL_CHAR_ANY_MEANS) {
		leader->SetObjective(OBJECTIVE_NONE);
		leader->SetWanderPath(CGeneral::GetRandomNumber() & 7);
	}
	leader->bIsLeader = true;
}

static void
VCModCrewRemoveDead(void)
{
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		int32 handle = nVCModCrewPedHandle[i];
		if (handle < 0)
			continue;
		CPed *ped = CPools::GetPedPool()->GetAt(handle);
		if (ped == nil || !ped->Dead())
			continue;
		nVCModCrewPedHandle[i] = -1;
		CWorld::Remove(ped);
		CWorld::RemoveReferencesToDeletedObject(ped);
		delete ped;
	}
}

static void
VCModCrewDismiss(void)
{
	CPlayerPed *player = FindPlayerPed();
	CVehicle *car = VCModCrewVehicle();
	bool aboard = player != nil && car != nil && player->InVehicle() && player->m_pMyVehicle == car;
	if (aboard) {
		car->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
		car->AutoPilot.m_nCruiseSpeed = 0;
		car->AutoPilot.m_nTempAction = TEMPACT_NONE;
		for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
			CPed *ped = VCModCrewPed(i);
			if (ped != nil && ped->bInVehicle)
				ped->SetObjective(OBJECTIVE_LEAVE_CAR, car);
		}
		nVCModCrewDismissAt = CTimer::GetTimeInMilliseconds();
		nVCModCrewPhase = VCMOD_CREW_DISMISS_WAIT;
		VCModCrewNotice("crew dismissed");
		return;
	}
	VCModCrewHandover();
	VCModCrewRemoveDead();
	VCModCrewRemoveCar();
	VCModCrewReset();
	VCModCrewNotice("crew dismissed");
}

static void
VCModCrewTickDismissWait(CPlayerPed *player, CVehicle *car)
{
	bool anyAboard = false;
	for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
		CPed *ped = VCModCrewPed(i);
		if (ped != nil && ped->bInVehicle)
			anyAboard = true;
	}
	if (!anyAboard || CTimer::GetTimeInMilliseconds() - nVCModCrewDismissAt > 10000) {
		VCModCrewHandover();
		VCModCrewRemoveDead();
		VCModCrewRemoveCar();
		VCModCrewReset();
	}
}

void
VCModCrewPlayerDied(void)
{
	if (nVCModCrewPhase == VCMOD_CREW_NONE)
		return;
	CVehicle *car = VCModCrewVehicle();
	CPlayerPed *player = FindPlayerPed();
	if (car != nil && player != nil && player->InVehicle() && player->m_pMyVehicle == car) {
		car->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
		car->AutoPilot.m_nCruiseSpeed = 0;
		for (int32 i = 0; i < VCMOD_CREW_SIZE; i++) {
			CPed *ped = VCModCrewPed(i);
			if (ped != nil && ped->bInVehicle)
				ped->SetObjective(OBJECTIVE_LEAVE_CAR, car);
		}
		nVCModCrewDismissAt = CTimer::GetTimeInMilliseconds();
		nVCModCrewPhase = VCMOD_CREW_DISMISS_WAIT;
		return;
	}
	VCModCrewHandover();
	VCModCrewRemoveDead();
	VCModCrewRemoveCar();
	VCModCrewReset();
}
```

Change `VCModCrewCall`'s active branch to:

```cpp
		VCModCrewDismiss();
		return;
```

Add the prototypes and the `DISMISS_WAIT` switch case. `Ped.cpp`: include `vcmodcrew.h`; in `CPed::SetDie`, after `if (DyingOrDead()) return;`:

```cpp
	if (player == this)
		VCModCrewPlayerDied();
```

- [ ] **Step 4: Run and build**

```bash
cd reVC && python3 utils/test_vc_crew.py && python3 utils/test_vc_passenger.py
cd .. && scripts/build.sh
```

---

### Task 6: Panel rows, CREW CAR list, README

**Files:**
- Modify: `reVC/src/extras/vcmodpanel.cpp`
- Modify: `README.md`
- Modify: `reVC/utils/test_vc_crew.py`, `test_vc_passenger.py`

**Interfaces:**
- Consumes: `VCModCrewCall`, `VCModCrewCarCount/At`, `VCModCrewPhase`.
- Produces: `VCMOD_ROW_CALLCREW`, `VCMOD_ROW_CREWCAR`, `VCMOD_LIST_CREWCAR`.

- [ ] **Step 1: Add the panel test**

```python
    def test_panel_has_the_crew_rows_and_no_passenger_mode(self):
        rows = braced(PANEL, "static const VCModRowDef aVCModRows[]")
        self.assertIn('{ "CALL CREW",', rows)
        self.assertIn('{ "CREW CAR",', rows)
        self.assertNotIn('"PASSENGER MODE"', rows)
        self.assertIn("VCModCrewCall", PANEL)
        self.assertIn("VCModCrewCarAt", PANEL)
```

- [ ] **Step 2: Add the row kinds and rows**

Enum: `VCMOD_ROW_CALLCREW`, `VCMOD_ROW_CREWCAR`. List: `VCMOD_LIST_CREWCAR`.
Above `CALL DRIVER`:

```cpp
	{ "CALL CREW",       VCMOD_ROW_CALLCREW, nil,                   nil,              VCMOD_PAGE_DRIVING },
	{ "CREW CAR",        VCMOD_ROW_CREWCAR, nil,                    "CrewCar",        VCMOD_PAGE_DRIVING },
```

- [ ] **Step 3: Wire the list, the action and the cells**

`VCModRowList`: `case VCMOD_ROW_CREWCAR: return VCMOD_LIST_CREWCAR;`.
`VCModListCount`: `case VCMOD_LIST_CREWCAR: return VCModCrewCarCount();`.

```cpp
	case VCMOD_LIST_CREWCAR: {
		int16 model;
		const char *name;
		if (!VCModCrewCarAt(entry, &model, &name))
			return "unknown";
		*selected = model == nVCModCrewCar;
		return name;
	}
```

`VCModListPick`:

```cpp
	case VCMOD_LIST_CREWCAR: {
		int16 model;
		if (VCModCrewCarAt(entry, &model, nil))
			nVCModCrewCar = model;
		break;
	}
```

`VCModRowValue`: `case VCMOD_ROW_CREWCAR: return nVCModCrewCar;`.

```cpp
		case VCMOD_ROW_CREWCAR: {
			style = VCFONT_SET;
			value = "car";
			for (int32 i = 0; i < VCModCrewCarCount(); i++) {
				int16 model;
				const char *name;
				if (VCModCrewCarAt(i, &model, &name) && model == nVCModCrewCar) {
					value = name;
					break;
				}
			}
			break;
		}
		case VCMOD_ROW_CALLCREW:
			style = VCModCrewPhase() == VCMOD_CREW_NONE ? VCFONT_OFF : VCFONT_ON;
			value = VCModCrewCell();
			break;
```

```cpp
static const char *
VCModCrewCell(void)
{
	switch (VCModCrewPhase()) {
	case VCMOD_CREW_APPROACH:	return "[EN ROUTE]  V dismiss";
	case VCMOD_CREW_PICKUP:		return "[WAITING]   V dismiss";
	case VCMOD_CREW_SWAP:		return "[HANDOVER]";
	case VCMOD_CREW_ABOARD:		return "[ABOARD]    V dismiss";
	case VCMOD_CREW_ESCORT:		return "[ON FOOT]   V dismiss";
	case VCMOD_CREW_DISMISS_WAIT:	return "[LEAVING]";
	}
	return "[CALL]      V";
}
```

Action: `case VCMOD_ROW_CALLCREW: VCModCrewCall(); break;`.
Debug menu, `VCModTweaksDriving`: `TWEAKFUNCN(VCModCrewCall, "call crew");`.
Include `vcmodcrew.h`.

- [ ] **Step 4: Row count**

The table is **52** rows (49 − 1 mode + 2 KEYS + 2 crew). Update `test_vc_passenger.py:1013` and the row-order regex (`CALL CREW`, `CREW CAR`, `CALL DRIVER`).

- [ ] **Step 5: README**

Add `CALL CREW` (`V`), `CREW CAR`, the entourage behaviour and the two keys. State that `P` is global and `F` is stock except on the crew car and the summoned limo.

- [ ] **Step 6: Run**

```bash
cd reVC && python3 utils/test_vc_crew.py && python3 utils/test_vc_passenger.py && python3 utils/test_vc_keys.py
```

---

### Task 7: Full verification, build, install, handoff

- [ ] **Step 1: Every harness**

```bash
cd reVC && for t in utils/test_vc_*.py; do python3 "$t" || exit 1; done
```

- [ ] **Step 2: Build**

```bash
cd .. && scripts/build.sh
```

- [ ] **Step 3: Install with no session**

```bash
pgrep -f "reVC.app/Contents/MacOS/reVC" || scripts/install.sh
```

- [ ] **Step 4: Handoff**

`docs/handoff/2026-11-10-vercetti-crew.md`: repo/branch/HEAD, installed build, uncommitted files, the play checks (call, F swap, P ride, dismiss, death), files not to touch. Play verification is the owner's; do not claim it.

---

## Self-Review

- Spec coverage: shelf/summon (2), approach/pick-up (3), F swap (3), global key and mode retirement (1), fill/ride/escort (4), handover/dismiss/death (5), panel/ini/README (6), telemetry (2), build/install/handoff (7).
- Names: `VCModCrewEntry`, `VCModCrewOwnsCar`, `VCModCrewCarAt`, `VCModPassengerKey`, `VCMOD_CREW_*` used consistently.
- Harness: `ENGINE_STUBS` supplies the typedefs; `CREW_STUBS` defines types in dependency order (`CEntity`, `CPed`, `CVehicle`, `CPlayerPed : CPed`); `CModelInfo` is forward-declared before `CVehicleModelInfo` uses it; `crew_statics()` starts at the defines so the car shelf's arrays are present.
- Row count: 49 − 1 + 2 + 2 = 52.
- No commit steps, by the owner's git rule.
