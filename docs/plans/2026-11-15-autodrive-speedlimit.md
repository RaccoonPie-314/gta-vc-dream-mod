# Auto drive and speed limit — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A player car/bike drives itself with two stock NPC styles (safe, aggressive) and a separate row caps manual driving at the civilian traffic pace (15).

**Architecture:** The player car keeps `STATUS_PLAYER`. A new `vcmodautodrive` module saves the car's AutoPilot, routes it, and each frame calls the engine's own `CCarCtrl::SteerAICarWithPhysics` after the stock `ProcessControlInputs`, so pedals, steering, lights and car/ped avoidance are stock NPC code. The speed limit is the same pace applied as a pedal governor.

**Tech Stack:** C++98 in the reVC tree (CMake on macOS, premake on Windows), Python 3 unittest harnesses that extract production functions and compile them against stubs.

**Spec:** `docs/specs/2026-11-15-autodrive-speedlimit-design.md`

> **Revision after the first play (2026-11-15):** the second style is the
> engine's `DRIVINGSTYLE_AVOID_CARS` (runs reds, weaves around traffic) and
> the speed limit holds the cap with throttle only, applying no brake trim, so
> the tail lamps stay off; auto drive drops its own sub-0.15 cruise trim the
> same way. The code blocks below carry the revised values.

## Global Constraints

- Do not commit, tag or push unless explicitly asked. This plan has no commit steps.
- Feature off = stock path; the off path adds no log lines and no per-frame work beyond one predicate call.
- One feature, one module: `src/extras/vcmodautodrive.{cpp,h}`; engine files get one-line hooks only.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is read-only; the `uchg` anim files stay untouched.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- No `#ifdef __APPLE__` and no machine paths in mod code.
- Panel rows need `info` (and `warn` when surprising), within the panel width.
- The pace is 15, from `VCModTrafficPace()`; no second copy of the value.

---

### Task 1: Export the traffic pace

**Files:**
- Modify: `reVC/src/extras/vcmodtraffic.h`
- Modify: `reVC/src/extras/vcmodtraffic.cpp`

**Interfaces:**
- Produces: `int32 VCModTrafficPace(void)` — the cruise the traffic layer gives civilian cars (15).

- [ ] **Step 1: Declare the accessor in the header**

```cpp
// the cruise the traffic layer gives civilian cars; auto drive and the speed
// limit keep the same pace, so the value has one home
int32 VCModTrafficPace(void);
```

- [ ] **Step 2: Define it next to `VCModTrafficHornAllowed`**

```cpp
int32
VCModTrafficPace(void)
{
	return (int32)RTF_CRUISE;
}
```

- [ ] **Step 3: Verify the value is the applied one**

Run: `grep -n "RTF_CRUISE" reVC/src/extras/vcmodtraffic.cpp`
Expected: the define is 15.0f and line 217 assigns it to `m_nCruiseSpeed`.

---

### Task 2: The auto drive module

**Files:**
- Create: `reVC/src/extras/vcmodautodrive.h`
- Create: `reVC/src/extras/vcmodautodrive.cpp`

**Interfaces:**
- Consumes: `VCModTrafficPace()`, `VCModHudNotice()`, `CCarCtrl::SteerAICarWithPhysics`, `CCarCtrl::JoinCarWithRoadSystem`, `CCarCtrl::JoinCarWithRoadSystemGotoCoors`, `CCarCtrl::GAME_SPEED_TO_CARAI_SPEED`, `CRadar::TargetMarkerId/Pos`, `CPools::GetVehiclePool`, `CPad`.
- Produces: `nVCModAutoDriveMode`, `bVCModSpeedLimit`, `VCModAutoDriveModeGet`, `VCModAutoDriveSetMode(int32)`, `VCModAutoDriveKey`, `VCModAutoDriveControl(CVehicle*)`, `VCModAutoDriveTick(CPlayerPed*)`, `VCModAutoDriveReset`.

- [ ] **Step 1: Write the header**

```cpp
#ifndef VCMODAUTODRIVE_H
#define VCMODAUTODRIVE_H

class CPlayerPed;
class CVehicle;

// AUTO DRIVE drives the player's own car with the engine's NPC styles; SPEED
// LIMIT is the same traffic pace applied to the player's manual driving.
enum eVCModAutoDriveMode
{
	VCMOD_AUTODRIVE_OFF,
	VCMOD_AUTODRIVE_SAFE,		// DRIVINGSTYLE_STOP_FOR_CARS
	VCMOD_AUTODRIVE_AGGRESSIVE,	// DRIVINGSTYLE_AVOID_CARS: runs reds, weaves
	NUM_VCMOD_AUTODRIVE_MODES
};

extern int32 nVCModAutoDriveMode;
extern bool bVCModSpeedLimit;

int32 VCModAutoDriveModeGet(void);
void VCModAutoDriveSetMode(int32 mode);
void VCModAutoDriveKey(void);
void VCModAutoDriveControl(CVehicle *vehicle);
void VCModAutoDriveTick(CPlayerPed *player);
void VCModAutoDriveReset(void);

#endif
```

- [ ] **Step 2: Write the module implementation**

```cpp
#include "common.h"

#include <stdio.h>

#include "vcmodautodrive.h"
#include "vcmodhud.h"
#include "vcmodtraffic.h"

#include "CarCtrl.h"
#include "General.h"
#include "Pad.h"
#include "Ped.h"
#include "PlayerPed.h"
#include "Pools.h"
#include "Radar.h"
#include "Vehicle.h"

int32 nVCModAutoDriveMode = VCMOD_AUTODRIVE_OFF;
bool bVCModSpeedLimit = false;

// the style the key comes back to; a session choice, not a saved setting
static int32 nVCModAutoDriveLastMode = VCMOD_AUTODRIVE_SAFE;
// the borrowed car is a pool handle: a recycled slot must end the session, not
// become the next car that gets driven
static int32 nVCModAutoDriveHandle = -1;
static int32 nVCModAutoDriveAppliedMode = -1;
static bool bVCModAutoDriveHasDestination;
static bool bVCModAutoDriveArriving;
static bool bVCModAutoDriveLatched;
static CVector vecVCModAutoDriveDestination;
// the stock AutoPilot the session replaced
static uint8 nVCModAutoDriveSavedMission;
static uint8 nVCModAutoDriveSavedStyle;
static uint8 nVCModAutoDriveSavedCruise;
static float fVCModAutoDriveSavedMaxSpeed;
static uint8 nVCModAutoDriveSavedTempAction;
static int16 nVCModAutoDriveSavedPathCount;
static CVector vecVCModAutoDriveSavedDestination;

// the stock mission-car arrival distance (CCarAI::UpdateCarAI GOTOCOORDS_STRAIGHT)
#define VCMOD_AUTODRIVE_ARRIVE_NEAR	3.0f
// how far a placed marker has to move before the route follows it
#define VCMOD_AUTODRIVE_RETARGET_NEAR	25.0f
#define VCMOD_AUTODRIVE_STOPPED		0.05f

static CVehicle *VCModAutoDriveVehicle(void);

static CVehicle *
VCModAutoDriveVehicle(void)
{
	if (nVCModAutoDriveHandle < 0)
		return nil;
	return CPools::GetVehiclePool()->GetAt(nVCModAutoDriveHandle);
}

static bool
VCModAutoDriveIsOurCar(CVehicle *veh)
{
	return veh != nil && nVCModAutoDriveHandle >= 0 &&
		CPools::GetVehiclePool()->GetIndex(veh) == nVCModAutoDriveHandle;
}

// the reasons a mode cannot be turned on, in the panel's own words
static const char *
VCModAutoDriveRefusal(CPlayerPed *player)
{
	if (player == nil || !player->InVehicle() || player->m_pMyVehicle == nil)
		return "auto drive: get in the driver seat";
	CVehicle *veh = player->m_pMyVehicle;
	if (veh->pDriver != player)
		return "auto drive: not from the passenger seat";
	if (!veh->IsCar() && !veh->IsBike())
		return "auto drive: not in this";
	return nil;
}

static void
VCModAutoDriveSave(CVehicle *veh)
{
	nVCModAutoDriveSavedMission = veh->AutoPilot.m_nCarMission;
	nVCModAutoDriveSavedStyle = veh->AutoPilot.m_nDrivingStyle;
	nVCModAutoDriveSavedCruise = veh->AutoPilot.m_nCruiseSpeed;
	fVCModAutoDriveSavedMaxSpeed = veh->AutoPilot.m_fMaxTrafficSpeed;
	nVCModAutoDriveSavedTempAction = veh->AutoPilot.m_nTempAction;
	nVCModAutoDriveSavedPathCount = veh->AutoPilot.m_nPathFindNodesCount;
	vecVCModAutoDriveSavedDestination = veh->AutoPilot.m_vecDestinationCoors;
}

static void
VCModAutoDriveRestore(CVehicle *veh)
{
	if (veh == nil)
		return;
	veh->AutoPilot.m_nCarMission = nVCModAutoDriveSavedMission;
	veh->AutoPilot.m_nDrivingStyle = nVCModAutoDriveSavedStyle;
	veh->AutoPilot.m_nCruiseSpeed = nVCModAutoDriveSavedCruise;
	veh->AutoPilot.m_fMaxTrafficSpeed = fVCModAutoDriveSavedMaxSpeed;
	veh->AutoPilot.m_nTempAction = nVCModAutoDriveSavedTempAction;
	veh->AutoPilot.m_nPathFindNodesCount = nVCModAutoDriveSavedPathCount;
	veh->AutoPilot.m_vecDestinationCoors = vecVCModAutoDriveSavedDestination;
}

static void
VCModAutoDriveApplyPace(CVehicle *veh)
{
	int32 pace = VCModTrafficPace();
	veh->AutoPilot.m_nDrivingStyle = nVCModAutoDriveMode == VCMOD_AUTODRIVE_AGGRESSIVE ?
		DRIVINGSTYLE_AVOID_CARS : DRIVINGSTYLE_STOP_FOR_CARS;
	veh->AutoPilot.m_nCruiseSpeed = (uint8)pace;
	veh->AutoPilot.m_fMaxTrafficSpeed = (float)pace;
	veh->AutoPilot.m_nTempAction = TEMPACT_NONE;
	nVCModAutoDriveAppliedMode = nVCModAutoDriveMode;
}

static void
VCModAutoDriveRoute(CVehicle *veh)
{
	if (CRadar::TargetMarkerId != -1) {
		CVector dest = CRadar::TargetMarkerPos;
		bool straight = CCarCtrl::JoinCarWithRoadSystemGotoCoors(veh, dest, false);
		veh->AutoPilot.m_nCarMission = straight ? MISSION_GOTOCOORDS_STRAIGHT : MISSION_GOTOCOORDS;
		vecVCModAutoDriveDestination = dest;
		bVCModAutoDriveHasDestination = true;
	} else {
		CCarCtrl::JoinCarWithRoadSystem(veh);
		veh->AutoPilot.m_nCarMission = MISSION_CRUISE;
		bVCModAutoDriveHasDestination = false;
	}
	bVCModAutoDriveArriving = false;
	VCModAutoDriveApplyPace(veh);
}

static bool
VCModAutoDrivePadHeld(void)
{
	CPad *pad = CPad::GetPad(0);
	if (pad == nil)
		return false;
	return pad->GetAccelerate() > 0 || pad->GetBrake() > 0 ||
		pad->GetSteeringLeftRight() != 0 || pad->GetHandBrake() > 0;
}

// a control held when the car takes over is how the player got there, not a
// request for the wheel back; the next press after everything is released is
static bool
VCModAutoDriveTookWheel(void)
{
	bool held = VCModAutoDrivePadHeld();
	if (bVCModAutoDriveLatched) {
		if (!held)
			bVCModAutoDriveLatched = false;
		return false;
	}
	return held;
}

static void
VCModAutoDriveGovern(CVehicle *veh)
{
	float pace = (float)VCModTrafficPace();
	float forward = DotProduct(veh->GetMoveSpeed(), veh->GetForward()) * GAME_SPEED_TO_CARAI_SPEED;
	if (forward <= pace)
		return;
	// hold the cap with the throttle alone, the quiet way traffic does: a brake
	// trim under 0.15 only brightens the tail lamps, so only a real overshoot
	// brakes (the same rule the crew car uses for its cruise pedal)
	veh->m_fGasPedal = 0.0f;
	float brake = Min(0.5f, (forward - pace) * 0.05f);
	if (brake >= 0.15f && veh->m_fBrakePedal < brake)
		veh->m_fBrakePedal = brake;
}

static void
VCModAutoDriveBegin(CVehicle *veh)
{
	nVCModAutoDriveHandle = CPools::GetVehiclePool()->GetIndex(veh);
	VCModAutoDriveSave(veh);
	VCModAutoDriveRoute(veh);
	bVCModAutoDriveLatched = VCModAutoDrivePadHeld();
	fprintf(stderr, "VCMOD auto drive on: %s\n",
		nVCModAutoDriveMode == VCMOD_AUTODRIVE_AGGRESSIVE ? "aggressive" : "safe");
}

static void
VCModAutoDriveEnd(const char *reason, const char *notice)
{
	CVehicle *veh = VCModAutoDriveVehicle();
	VCModAutoDriveRestore(veh);
	if (notice != nil)
		VCModHudNotice(notice);
	fprintf(stderr, "VCMOD auto drive off: %s\n", reason);
	nVCModAutoDriveHandle = -1;
	nVCModAutoDriveAppliedMode = -1;
	bVCModAutoDriveHasDestination = false;
	bVCModAutoDriveArriving = false;
	bVCModAutoDriveLatched = false;
	nVCModAutoDriveMode = VCMOD_AUTODRIVE_OFF;
}

int32
VCModAutoDriveModeGet(void)
{
	return nVCModAutoDriveMode;
}

void
VCModAutoDriveSetMode(int32 mode)
{
	if (mode < 0 || mode >= NUM_VCMOD_AUTODRIVE_MODES)
		mode = VCMOD_AUTODRIVE_OFF;
	if (mode == nVCModAutoDriveMode)
		return;
	if (mode != VCMOD_AUTODRIVE_OFF) {
		const char *refusal = VCModAutoDriveRefusal(FindPlayerPed());
		if (refusal != nil) {
			VCModHudNotice(refusal);
			return;
		}
		nVCModAutoDriveLastMode = mode;
		nVCModAutoDriveMode = mode;
		VCModHudNotice(mode == VCMOD_AUTODRIVE_AGGRESSIVE ?
			"auto drive: aggressive" : "auto drive: safe");
		return;
	}
	nVCModAutoDriveMode = VCMOD_AUTODRIVE_OFF;
}

void
VCModAutoDriveKey(void)
{
	if (nVCModAutoDriveMode != VCMOD_AUTODRIVE_OFF) {
		VCModAutoDriveEnd("key", "auto drive off");
		return;
	}
	VCModAutoDriveSetMode(nVCModAutoDriveLastMode);
}

void
VCModAutoDriveControl(CVehicle *veh)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil || veh == nil || veh->pDriver != player)
		return;

	bool ours = VCModAutoDriveIsOurCar(veh);

	if (nVCModAutoDriveMode == VCMOD_AUTODRIVE_OFF) {
		if (ours)
			VCModAutoDriveEnd("mode off", nil);
		if (bVCModSpeedLimit)
			VCModAutoDriveGovern(veh);
		return;
	}

	// the mode is only ever turned on from the driver seat; a session found in
	// another car is the tick's business
	if (!player->InVehicle() || player->m_pMyVehicle != veh)
		return;

	if (!ours)
		VCModAutoDriveBegin(veh);
	else if (nVCModAutoDriveMode != nVCModAutoDriveAppliedMode)
		VCModAutoDriveApplyPace(veh);

	if (VCModAutoDriveTookWheel()) {
		VCModAutoDriveEnd("take the wheel", "auto drive off");
		return;
	}

	// a marker placed, moved or removed mid-drive re-routes, the same live rule
	// the RIDE destination follows
	if (bVCModAutoDriveHasDestination
			? (CRadar::TargetMarkerId == -1 ||
			   (CRadar::TargetMarkerPos - vecVCModAutoDriveDestination).Magnitude2D() > VCMOD_AUTODRIVE_RETARGET_NEAR)
			: (CRadar::TargetMarkerId != -1))
		VCModAutoDriveRoute(veh);

	if (bVCModAutoDriveHasDestination) {
		float distance = (veh->GetPosition() - vecVCModAutoDriveDestination).Magnitude2D();
		if (!bVCModAutoDriveArriving && distance < VCMOD_AUTODRIVE_ARRIVE_NEAR) {
			bVCModAutoDriveArriving = true;
			veh->AutoPilot.m_nCarMission = MISSION_STOP_FOREVER;
			veh->AutoPilot.m_nTempAction = TEMPACT_NONE;
		}
		if (bVCModAutoDriveArriving && veh->GetMoveSpeed().Magnitude() < VCMOD_AUTODRIVE_STOPPED) {
			VCModAutoDriveEnd("arrived", "auto drive: arrived");
			return;
		}
	}

	CCarCtrl::SteerAICarWithPhysics(veh);
	// the AI holds its cruise with the brake pedal, and any pedal above zero
	// brightens the tail lamps; a trim under 0.15 is only that, so it is
	// dropped unless the AI is really slowing for traffic
	if (veh->m_fBrakePedal < 0.15f &&
			!veh->AutoPilot.m_bSlowedDownBecauseOfCars && !veh->AutoPilot.m_bSlowedDownBecauseOfPeds)
		veh->m_fBrakePedal = 0.0f;
}

void
VCModAutoDriveTick(CPlayerPed *player)
{
	if (nVCModAutoDriveHandle < 0) {
		if (nVCModAutoDriveMode != VCMOD_AUTODRIVE_OFF)
			nVCModAutoDriveMode = VCMOD_AUTODRIVE_OFF;
		return;
	}

	if (nVCModAutoDriveMode == VCMOD_AUTODRIVE_OFF) {
		VCModAutoDriveEnd("mode off", nil);
		return;
	}

	CVehicle *veh = VCModAutoDriveVehicle();
	bool aboard = player != nil && veh != nil && player->InVehicle() &&
		player->m_pMyVehicle == veh && veh->pDriver == player;
	bool wrecked = veh == nil || veh->GetStatus() == STATUS_WRECKED;
	bool taken = player != nil && (player->GetPedState() == PED_ARRESTED ||
		player->GetPedState() == PED_DRAG_FROM_CAR);

	if (!aboard)
		VCModAutoDriveEnd("left the car", nil);
	else if (wrecked)
		VCModAutoDriveEnd("wrecked", nil);
	else if (taken)
		VCModAutoDriveEnd("arrested", nil);
}

void
VCModAutoDriveReset(void)
{
	if (nVCModAutoDriveHandle >= 0)
		VCModAutoDriveEnd("reset", nil);
	nVCModAutoDriveMode = VCMOD_AUTODRIVE_OFF;
	nVCModAutoDriveLastMode = VCMOD_AUTODRIVE_SAFE;
}
```

- [ ] **Step 3: Compile-check after the hooks (Task 3)**

Run: `scripts/build.sh`
Expected: the new module compiles with no warnings from its own file.

---

### Task 3: Engine hooks

**Files:**
- Modify: `reVC/src/vehicles/Automobile.cpp` (include block; `STATUS_PLAYER` branch)
- Modify: `reVC/src/vehicles/Bike.cpp` (include block; `STATUS_PLAYER` branch)
- Modify: `reVC/src/peds/PlayerPed.cpp` (tick next to `VCModUpdateRide`, key next to CALL DRIVER)
- Modify: `reVC/src/save/GenericGameStorage.cpp` (reset after `VCModSaveReset()`)

**Interfaces:**
- Consumes: `VCModAutoDriveControl`, `VCModAutoDriveTick`, `VCModAutoDriveKey`, `VCModAutoDriveReset`.

- [ ] **Step 1: Automobile hook**

Add `#include "vcmodautodrive.h"` to the mod include block, then one line after the stock input read:

```cpp
			if(playerRemote || pDriver->m_nPedType == PEDTYPE_PLAYER1)
				ProcessControlInputs(0);
			VCModAutoDriveControl(this);
```

- [ ] **Step 2: Bike hook**

Add the include, then one line after `ProcessControlInputs(0);` in the `STATUS_PLAYER` case:

```cpp
			ProcessControlInputs(0);
			VCModAutoDriveControl(this);
```

- [ ] **Step 3: Player tick and key**

Add `#include "vcmodautodrive.h"`, then:

```cpp
	VCModUpdateRide(this);
	VCModAutoDriveTick(this);
```

and next to the CALL DRIVER block:

```cpp
	// O by default: the car drives itself from the driver seat, and any driving
	// input hands the wheel back
	if (padUsed && !padUsed->ArePlayerControlsDisabled() && !VCModKeyCapturing() &&
	    KEYJUSTDOWN(aVCModKeys[VCKEY_AUTODRIVE]))
		VCModAutoDriveKey();
```

- [ ] **Step 4: Save-load reset**

```cpp
	VCModSaveReset();
	VCModAutoDriveReset();
```

- [ ] **Step 5: Build**

Run: `scripts/build.sh`
Expected: success.

---

### Task 4: Key slot and ini reads

**Files:**
- Modify: `reVC/src/extras/vcmodkeys.h`
- Modify: `reVC/src/extras/vcmodkeys.cpp`
- Modify: `reVC/src/core/re3.cpp`

**Interfaces:**
- Produces: `VCKEY_AUTODRIVE`, default `'O'`, ini names `KeyAutoDrive` and `SpeedLimit`.

- [ ] **Step 1: Add the key slot**

In `eVCModKey`, before `NUM_VCKEYS`:

```cpp
	VCKEY_AUTODRIVE,	// the car drives itself on and off
```

- [ ] **Step 2: Add the key tables**

Extend all four arrays at the same position:

```cpp
	'P',	// passenger
	'O',	// auto drive

	'\\', 'B', 'G', 'H', 'K', 'R', 'J', 'U', 'C', 'V', 'P', 'O',

	"PANEL KEY", "WALK MODE", "FIRE", "CALL DRIVER",
	"SPIN KICK", "RELOAD", "CHASE SPOT", "CHASE CAPTURE", "1ST PERSON",
	"CALL CREW", "PASSENGER", "AMMO", "AUTO DRIVE"

	"KeyPanel", "KeyWalk", "KeyFire", "KeyDriver",
	"KeyKick", "KeyReload", "KeySpot", "KeyCapture", "KeyFirstPerson",
	"KeyCrew", "KeyPassenger", "KeyAmmo", "KeyAutoDrive"
```

- [ ] **Step 3: Read both ini keys**

Next to the other `ReadIniIfExists` lines in `re3.cpp`:

```cpp
	ReadIniIfExists("VC Mods", "SpeedLimit", &bVCModSpeedLimit);
	ReadIniIfExists("VC Mods", "KeyAutoDrive", &aVCModKeys[VCKEY_AUTODRIVE]);
```

- [ ] **Step 4: Build**

Run: `scripts/build.sh`
Expected: success.

---

### Task 5: Panel rows

**Files:**
- Modify: `reVC/src/extras/vcmodpanelregistry.cpp`

**Interfaces:**
- Consumes: `VCModAutoDriveModeGet`, `VCModAutoDriveSetMode`, `bVCModSpeedLimit`, `VCKEY_AUTODRIVE`.

- [ ] **Step 1: Add the include and the cycle definition**

```cpp
#include "vcmodautodrive.h"
```

```cpp
static const char *aVCModAutoDriveLabels[] = {
	"[OFF]", "[SAFE]", "[AGGRESSIVE]"
};

static const VCModCycleDef aVCModAutoDriveCycle = {
	VCModAutoDriveModeGet, VCModAutoDriveSetMode,
	ARRAY_SIZE(aVCModAutoDriveLabels), aVCModAutoDriveLabels
};
```

- [ ] **Step 2: Add the DRIVING page rows**

After the RIDE rows:

```cpp
	{ "AUTO DRIVE",      VCMOD_ROW_CYCLE,   nil,                   nil,              VCMOD_PAGE_DRIVING, &aVCModAutoDriveCycle, -1,
	  "the car drives itself; driving keys take over", "runs reds and weaves through traffic" },
	{ "SPEED LIMIT",     VCMOD_ROW_FLAG,    &bVCModSpeedLimit,     "SpeedLimit",     VCMOD_PAGE_DRIVING, nil, -1,
	  "caps your driving at the pace of traffic", "acceleration stops above the cap" },
```

- [ ] **Step 3: Add the KEYS page row**

```cpp
	{ "AUTO DRIVE KEY",  VCMOD_ROW_KEY,     nil,                   nil,              VCMOD_PAGE_KEYS, nil, VCKEY_AUTODRIVE,
	  "the car drives itself on and off", nil },
```

- [ ] **Step 4: Keep the master sweep honest**

Do not add `bVCModSpeedLimit` to `aVCModSwitched`; extend the comment above it:

```cpp
// SPEED LIMIT is out too: an ambient sweep that silently caps the player's
// speed reads as a broken car.
```

- [ ] **Step 5: Build and run the panel shape test**

Run: `scripts/build.sh && cd utils && python3 test_vc_panel_info.py`
Expected: success; the new rows' info/warn lengths pass.

---

### Task 6: Harness

**Files:**
- Create: `reVC/utils/test_vc_autodrive.py`

**Interfaces:**
- Consumes: extracted functions from `vcmodautodrive.cpp`; stubs for the engine surface listed in Task 2.

- [ ] **Step 1: Write the extraction and stubs**

Model on `test_vc_passenger.py`: `ENGINE_STUBS` from `vcmod_test_support`, plus

- `AUTODRIVE_ENUMS` (mode enum),
- `AUTODRIVE_STUBS`: `CVector`, `CVehicle` (AutoPilot, `GetMoveSpeed`, `GetForward`, `GetPosition`, `GetStatus`, `SetStatus`, `IsCar`, `IsBike`, `pDriver`, `m_fGasPedal`, `m_fBrakePedal`), `CPlayerPed` (`InVehicle`, `m_pMyVehicle`, `GetPedState`), `CPools` (one-car pool with `GetIndex`/`GetAt`), `CPad` with settable `accelerate/brake/steer/handbrake`, `CRadar` (`TargetMarkerId`, `TargetMarkerPos`), `CCarCtrl` recording `join`, `goto`, `steer` and setting `AutoPilot`, `VCModTrafficPace()` returning 15, `VCModHudNotice` recording notices, `GAME_SPEED_TO_CARAI_SPEED 60.0f`, `DotProduct`, `Min`, `FindPlayerPed`.
- `autodrive_statics()`: the block from `static int32 nVCModAutoDriveLastMode` to the first function.
- `autodrive_functions(*names)`: marker map in caller order: `vehicle`, `isourcar`, `refusal`, `save`, `restore`, `applypace`, `route`, `padheld`, `tookwheel`, `govern`, `begin`, `end`, `modeget`, `setmode`, `key`, `control`, `tick`, `reset`.

- [ ] **Step 2: Write the checks**

One `unittest.TestCase` per concern, with concrete assertions:

- `test_styles_and_pace`: mode SAFE → `DRIVINGSTYLE_STOP_FOR_CARS` and cruise 15; mode AGGRESSIVE → `DRIVINGSTYLE_AVOID_CARS` and cruise 15.
- `test_route_follows_marker`: no marker → `join` recorded and `MISSION_CRUISE`; marker → `goto` recorded, destination matches, `MISSION_GOTOCOORDS` (or STRAIGHT on a failed route); marker moved 30 m → re-route; marker removed → cruise.
- `test_take_the_wheel`: a new pad press ends with `auto drive off` and mode OFF; a held input at begin is latched and does not end until released and pressed again.
- `test_arrival`: within 3 m → `MISSION_STOP_FOREVER`; zero speed → mode OFF and `auto drive: arrived`.
- `test_end_restores`: saved mission/style/cruise/max speed/temp action/path count/destination come back on key off, exit and wreck.
- `test_speed_limit`: at 15 untouched; at 16 gas 0 and no brake trim; at 20 gas 0 and brake 0.25; reverse untouched; auto drive active → untouched; off → untouched. Plus the auto drive cruise-trim drop.
- `test_mode_setter`: on foot, passenger and boat refusals show the right notices and leave the mode OFF.
- `test_registry`: `AUTO DRIVE` and `SPEED LIMIT` rows exist with info/warn; the key slot and both ini reads are present.

- [ ] **Step 3: Run the harness**

Run: `cd reVC/utils && python3 test_vc_autodrive.py`
Expected: all tests pass.

---

### Task 7: Full suite, build, install, handoff

- [ ] **Step 1: Run the whole harness suite**

Run: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f" || exit 1; done`
Expected: every harness passes.

- [ ] **Step 2: Build**

Run: `scripts/build.sh`
Expected: success.

- [ ] **Step 3: Install only when no session is running**

Run: `pgrep -f "reVC.app/Contents/MacOS/reVC"`
Expected: no output. Then `scripts/install.sh` and confirm the build number.

- [ ] **Step 4: Play checklist for the handoff**

1. Drive, press `O`: with a marker the car drives there and parks; without one it cruises.
2. Cycle the panel row to `ignore red lights`: the car runs reds but still stops for traffic.
3. Take the wheel with the gas: the car hands back the same frame.
4. Turn SPEED LIMIT on and floor it: forward speed settles at traffic pace.
5. Exit/re-enter, die, wreck: no stuck mission, no frozen car.

- [ ] **Step 5: Write the handoff**

`docs/handoff/2026-11-15-autodrive-speedlimit.md` plus the paste-ready prompt.
