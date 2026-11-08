# Chase Driving AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace stock mission-car driving in chase mode with a planned route, a pure-pursuit controller, stuck recovery, and moving-target pursuit, behind a mode flag, without editing chase files.

**Architecture:** A new `src/extras/vcmodaidrive*` module is dispatched from `CCarCtrl::SteerAICarWithPhysics` when the flag is on. It plans over the existing car-link graph, drives with pure pursuit, and defers to stock whenever the car is ineligible, has a temp action, or the flag is off. Per-car state lives in a fixed pool keyed by versioned vehicle handles.

**Tech Stack:** reVC C++ (branch `vcmods`), CMake via `scripts/build.sh`, Python 3 harness under `utils/`, engine path graph (`ThePaths`), `CWorld` sector queries.

**Spec:** `docs/specs/2026-11-07-driving-ai-design.md`

> **Superseded (2026-11-07, after first in-game test):** the replacement controller
> drove worse than stock — it bypassed route-node advancement, lane bookkeeping and
> `CCurves` corner calibration. The mode now keeps stock steering and only nudges it
> (`VCModAIDriveEnhance`): engine pursuit (`MISSION_RAMCAR_FARAWAY` on the target car),
> reverse-out recovery (`TEMPACT_REVERSE`), and a route rejoin when the path solver
> left a goto car in a straight-drive mission. Tasks 4-6 below describe the removed
> planner/controller and are kept for history only.

## Global Constraints

- `reVC` is the upstream checkout. Do not fork, branch or push it.
- Do not edit or stage another agent's dirty files: `vcmodchase.*`, `vcmodpanel.*`,
  `Ped.cpp`, `Ped.h`, `PlayerPed.cpp`, `re3.cpp`, `PlayerInfo.cpp`, and their tests.
- New logic only in `src/extras/vcmodaidrive*.` Hooks only in
  `src/core/Game.cpp` and `src/control/CarCtrl.cpp`, both currently clean.
- If either hook file becomes dirty, stop and report; do not edit around another agent.
- Build from the shared working tree. Committed HEAD alone does not compile without
  the other agent's uncommitted `Ped.h` fix.
- No commit, tag or push. Stage nothing. Report changed files only.
- No savegame fields, handling-data edits, SCM edits, health/damage/accuracy
  multipliers, or new physics.
- Do not launch the game. Hand the in-game checklist to the user.
- Repo style: tabs, function opening brace on its own line, one responsibility per
  helper, `fprintf(stderr, "VCMOD ...")` for telemetry.

## File Structure

- `src/extras/vcmodaidrive.h` - public API, enums, per-car state, constants.
- `src/extras/vcmodaidrive.cpp` - flag, ini/debug toggle, registry, target tracking,
  telemetry, dispatch.
- `src/extras/vcmodaidrive_plan.cpp` - pure decision helpers, graph route planner,
  lane plan, intercept and safe-cut decisions.
- `src/extras/vcmodaidrive_control.cpp` - pure pursuit, speed profile, obstacle and
  light checks, recovery state machine.
- `src/core/Game.cpp` - one include and one `VCModAIDriveUpdate()` call.
- `src/control/CarCtrl.cpp` - one include and one early dispatch in
  `SteerAICarWithPhysics`.
- `utils/test_vc_aidrive.py` - brace-extracted pure functions against C++98 stubs.

---

### Task 1: Module scaffold, flag, eligibility and hooks

**Files:**
- Create: `src/extras/vcmodaidrive.h`
- Create: `src/extras/vcmodaidrive.cpp`
- Modify: `src/core/Game.cpp`
- Modify: `src/control/CarCtrl.cpp`
- Test: `utils/test_vc_aidrive.py`

**Interfaces:**
- Consumes: `eCarMission` values, `eEntityStatus`, `CVehicle::IsCar`,
  `CVehicle::pDriver`, `CVehicle::AutoPilot`.
- Produces:
  - `bool VCModAIDriveMissionDrives(uint8 mission)`
  - `eVCModAIDriveMode VCModAIDriveModeFor(uint8 mission, bool ignorePathfinding)`
  - `bool VCModAIDriveEligible(bool enabled, bool isCar, bool isPlayer, bool hasDriver, bool physics, bool missionDrives, bool tempActionIdle)`
  - `bool VCModAIDriveTakeover(CVehicle*, float*, float*, float*, bool*)`
  - `void VCModAIDriveUpdate(void)`, `void VCModAIDriveSet(bool)`,
    `bool VCModAIDriveEnabled(void)`

- [ ] **Step 1: Write the failing harness test**

Create `utils/test_vc_aidrive.py` with the mission enum mirrored from
`src/control/AutoPilot.h` in the same order:

```python
#!/usr/bin/env python3
"""Driving-AI pure logic, brace-extracted from vcmodaidrive*.cpp and run against
C++98 stubs. Mirrors the shape of test_vc_chase.py."""
import pathlib
import re
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "src/extras/vcmodaidrive.cpp"
PLAN = ROOT / "src/extras/vcmodaidrive_plan.cpp"

PRELUDE = r'''
#include <stdio.h>
#include <math.h>
typedef int int32;
typedef short int16;
typedef unsigned int uint32;
typedef unsigned char uint8;
typedef signed char int8;
#define nil NULL
#define Min(a,b) ((a)<(b)?(a):(b))
#define Max(a,b) ((a)>(b)?(a):(b))
static float Sqrt(float x) { return sqrtf(x); }
enum {
    MISSION_NONE, MISSION_CRUISE, MISSION_RAMPLAYER_FARAWAY, MISSION_RAMPLAYER_CLOSE,
    MISSION_BLOCKPLAYER_FARAWAY, MISSION_BLOCKPLAYER_CLOSE,
    MISSION_BLOCKPLAYER_HANDBRAKESTOP, MISSION_WAITFORDELETION,
    MISSION_GOTOCOORDS, MISSION_GOTOCOORDS_STRAIGHT, MISSION_EMERGENCYVEHICLE_STOP,
    MISSION_STOP_FOREVER, MISSION_GOTOCOORDS_ACCURATE,
    MISSION_GOTO_COORDS_STRAIGHT_ACCURATE, MISSION_GOTOCOORDS_ASTHECROWSWIMS,
    MISSION_RAMCAR_FARAWAY, MISSION_RAMCAR_CLOSE, MISSION_BLOCKCAR_FARAWAY,
    MISSION_BLOCKCAR_CLOSE, MISSION_BLOCKCAR_HANDBRAKESTOP, MISSION_HELI_FLYTOCOORS,
    MISSION_ATTACKPLAYER, MISSION_PLANE_FLYTOCOORS, MISSION_HELI_LAND,
    MISSION_SLOWLY_DRIVE_TOWARDS_PLAYER_1, MISSION_SLOWLY_DRIVE_TOWARDS_PLAYER_2,
    MISSION_BLOCKPLAYER_FORWARDANDBACK
};
enum eVCModAIDriveMode { VCMOD_AIDRIVE_ROAD, VCMOD_AIDRIVE_STRAIGHT, VCMOD_AIDRIVE_PURSUIT };
static int failed = 0;
#define CHECK(c, m) do { if (!(c)) { printf("FAIL: %s\n", m); failed++; } } while (0)
'''

MAIN = r'''
int main() {
    CHECK(VCModAIDriveMissionDrives(MISSION_GOTOCOORDS), "goto is driven");
    CHECK(VCModAIDriveMissionDrives(MISSION_GOTOCOORDS_STRAIGHT), "straight goto is driven");
    CHECK(VCModAIDriveMissionDrives(MISSION_RAMPLAYER_CLOSE), "ram is driven");
    CHECK(VCModAIDriveMissionDrives(MISSION_BLOCKCAR_FARAWAY), "block is driven");
    CHECK(!VCModAIDriveMissionDrives(MISSION_NONE), "none is not driven");
    CHECK(!VCModAIDriveMissionDrives(MISSION_CRUISE), "cruise stays stock in v1");
    CHECK(!VCModAIDriveMissionDrives(MISSION_STOP_FOREVER), "stop stays stock");

    CHECK(VCModAIDriveModeFor(MISSION_GOTOCOORDS, false) == VCMOD_AIDRIVE_ROAD, "road mode");
    CHECK(VCModAIDriveModeFor(MISSION_GOTOCOORDS_STRAIGHT, false) == VCMOD_AIDRIVE_STRAIGHT, "straight mode");
    CHECK(VCModAIDriveModeFor(MISSION_GOTOCOORDS, true) == VCMOD_AIDRIVE_STRAIGHT, "ignore pathfinding is straight");
    CHECK(VCModAIDriveModeFor(MISSION_RAMCAR_CLOSE, false) == VCMOD_AIDRIVE_PURSUIT, "ram is pursuit");
    CHECK(VCModAIDriveModeFor(MISSION_BLOCKPLAYER_CLOSE, false) == VCMOD_AIDRIVE_PURSUIT, "block is pursuit");

    CHECK(VCModAIDriveEligible(true, true, false, true, true, true, true), "eligible baseline");
    CHECK(!VCModAIDriveEligible(false, true, false, true, true, true, true), "flag off");
    CHECK(!VCModAIDriveEligible(true, false, false, true, true, true, true), "not a car");
    CHECK(!VCModAIDriveEligible(true, true, true, true, true, true, true), "player car");
    CHECK(!VCModAIDriveEligible(true, true, false, false, true, true, true), "no driver");
    CHECK(!VCModAIDriveEligible(true, true, false, true, false, true, true), "not physics");
    CHECK(!VCModAIDriveEligible(true, true, false, true, true, false, true), "no driving mission");
    CHECK(!VCModAIDriveEligible(true, true, false, true, true, true, false), "temp action owns the car");
    return failed ? 1 : 0;
}
'''


def cut(path, name):
    text = path.read_text()
    match = re.search(r"((?:[A-Za-z_][A-Za-z0-9_]*[\s*]+)+)" + re.escape(name) + r"\s*\([^;{]*\)\s*\{", text)
    if match is None:
        raise AssertionError(f"{name} not found in {path}")
    start = match.end() - 1
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[match.start():i + 1]
    raise AssertionError(f"unbalanced braces in {name}")


class DriveTests(unittest.TestCase):
    def test_pure_core(self):
        source = PRELUDE + "\n".join(cut(SRC, n) for n in (
            "VCModAIDriveMissionDrives",
            "VCModAIDriveModeFor",
            "VCModAIDriveEligible",
        )) + MAIN
        with tempfile.TemporaryDirectory() as tmp:
            exe = pathlib.Path(tmp) / "drive"
            build = subprocess.run(["c++", "-std=c++98", "-x", "c++", "-", "-o", str(exe)],
                                   input=source, text=True, capture_output=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertNotIn("FAIL:", run.stdout)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: FAIL with `AssertionError: VCModAIDriveMissionDrives not found`.

- [ ] **Step 3: Create the header**

`src/extras/vcmodaidrive.h`:

```cpp
#ifndef __VCMODAIDRIVE_H__
#define __VCMODAIDRIVE_H__

#include "common.h"

class CVehicle;

enum eVCModAIDrivePhase
{
	VCMOD_AIDRIVE_OFF,
	VCMOD_AIDRIVE_FOLLOW,
	VCMOD_AIDRIVE_DIRECT,
	VCMOD_AIDRIVE_PURSUE,
	VCMOD_AIDRIVE_CUT,
	VCMOD_AIDRIVE_RECOVER
};

enum eVCModAIDriveMode
{
	VCMOD_AIDRIVE_ROAD,
	VCMOD_AIDRIVE_STRAIGHT,
	VCMOD_AIDRIVE_PURSUIT
};

#define VCMOD_AIDRIVE_MAX_POINTS	32
#define VCMOD_AIDRIVE_MAX_ACTIVE	8
#define VCMOD_AIDRIVE_MAX_SEARCH	256

struct VCModAIDrivePoint
{
	CVector pos;
	int16 node;
	int16 link;
	int8 lane;
};

struct VCModAIDriveState
{
	int32 vehicleHandle;
	eVCModAIDrivePhase phase;
	eVCModAIDriveMode mode;
	VCModAIDrivePoint plan[VCMOD_AIDRIVE_MAX_POINTS];
	int32 planCount;
	int32 cursor;
	uint32 plannedAt;
	CVector planDestination;
	CVector lastDestination;
	uint32 lastDestinationAt;
	CVector targetPos;
	CVector targetVel;
	uint32 targetSeenAt;
	CVector progressPos;
	uint32 progressAt;
	uint32 recoveryUntil;
	float recoverySteer;
	int32 recoveryAttempts;
	bool gaveUp;
	int32 lane;
	uint32 telemetryAt;
};

bool VCModAIDriveEnabled(void);
void VCModAIDriveSet(bool on);
void VCModAIDriveToggle(void);
void VCModAIDriveUpdate(void);

bool VCModAIDriveTakeover(CVehicle *car, float *swerve, float *accel, float *brake, bool *handbrake);

// pure helpers, exercised by utils/test_vc_aidrive.py
bool VCModAIDriveMissionDrives(uint8 mission);
eVCModAIDriveMode VCModAIDriveModeFor(uint8 mission, bool ignorePathfinding);
bool VCModAIDriveEligible(bool enabled, bool isCar, bool isPlayer, bool hasDriver,
	bool physics, bool missionDrives, bool tempActionIdle);
bool VCModAIDriveStuck(float throttle, float speed, float progress, uint32 elapsedMs);
float VCModAIDriveCurveSpeed(float radius, float latAccel);
void VCModAIDriveInterceptPoint(float tx, float ty, float vx, float vy, float seconds,
	float *outX, float *outY);
bool VCModAIDriveShouldReplan(float destX, float destY, float planDestX, float planDestY,
	float offPlan, uint32 now, uint32 plannedAt, int32 cursor, int32 planCount,
	bool movingTarget);
int32 VCModAIDrivePickLane(int32 lanes, bool leftTurn, bool rightTurn, int32 currentLane);
float VCModAIDriveLookahead(float speed);
float VCModAIDriveClampSteer(float angle, float maxAngle);

#endif
```

- [ ] **Step 4: Create the module with the flag and pure helpers**

`src/extras/vcmodaidrive.cpp`:

```cpp
#include "common.h"

#include "vcmodaidrive.h"
#include "AutoPilot.h"
#include "ControllerConfig.h"
#include "Entity.h"
#include "Ped.h"
#include "Pools.h"
#include "Timer.h"
#include "Vehicle.h"

#include <stdio.h>
#include <string.h>

#define VCMOD_AIDRIVE_KEY	'O'
#define KEYJUSTDOWN(k)		ControlsManager.GetIsKeyboardKeyJustDown((RsKeyCodes)(k))

extern bool ReadIniIfExists(const char *cat, const char *key, bool *out);

static bool bVCModAIDrive;

bool
VCModAIDriveEnabled(void)
{
	return bVCModAIDrive;
}

void
VCModAIDriveSet(bool on)
{
	bVCModAIDrive = on;
}

bool
VCModAIDriveMissionDrives(uint8 mission)
{
	switch (mission) {
	case MISSION_GOTOCOORDS:
	case MISSION_GOTOCOORDS_STRAIGHT:
	case MISSION_GOTOCOORDS_ACCURATE:
	case MISSION_GOTO_COORDS_STRAIGHT_ACCURATE:
	case MISSION_RAMPLAYER_FARAWAY:
	case MISSION_RAMPLAYER_CLOSE:
	case MISSION_BLOCKPLAYER_FARAWAY:
	case MISSION_BLOCKPLAYER_CLOSE:
	case MISSION_BLOCKPLAYER_HANDBRAKESTOP:
	case MISSION_RAMCAR_FARAWAY:
	case MISSION_RAMCAR_CLOSE:
	case MISSION_BLOCKCAR_FARAWAY:
	case MISSION_BLOCKCAR_CLOSE:
	case MISSION_BLOCKCAR_HANDBRAKESTOP:
		return true;
	default:
		return false;
	}
}

eVCModAIDriveMode
VCModAIDriveModeFor(uint8 mission, bool ignorePathfinding)
{
	if (ignorePathfinding)
		return VCMOD_AIDRIVE_STRAIGHT;
	switch (mission) {
	case MISSION_GOTOCOORDS_STRAIGHT:
	case MISSION_GOTOCOORDS_ACCURATE:
	case MISSION_GOTO_COORDS_STRAIGHT_ACCURATE:
		return VCMOD_AIDRIVE_STRAIGHT;
	case MISSION_RAMPLAYER_FARAWAY:
	case MISSION_RAMPLAYER_CLOSE:
	case MISSION_BLOCKPLAYER_FARAWAY:
	case MISSION_BLOCKPLAYER_CLOSE:
	case MISSION_BLOCKPLAYER_HANDBRAKESTOP:
	case MISSION_RAMCAR_FARAWAY:
	case MISSION_RAMCAR_CLOSE:
	case MISSION_BLOCKCAR_FARAWAY:
	case MISSION_BLOCKCAR_CLOSE:
	case MISSION_BLOCKCAR_HANDBRAKESTOP:
		return VCMOD_AIDRIVE_PURSUIT;
	default:
		return VCMOD_AIDRIVE_ROAD;
	}
}

bool
VCModAIDriveEligible(bool enabled, bool isCar, bool isPlayer, bool hasDriver,
	bool physics, bool missionDrives, bool tempActionIdle)
{
	return enabled && isCar && !isPlayer && hasDriver && physics &&
		missionDrives && tempActionIdle;
}

void
VCModAIDriveToggle(void)
{
	bVCModAIDrive = !bVCModAIDrive;
	fprintf(stderr, "VCMOD AIDRIVE %s\n", bVCModAIDrive ? "on" : "off");
}

void
VCModAIDriveUpdate(void)
{
	static bool iniRead;
	if (!iniRead) {
		iniRead = true;
		ReadIniIfExists("VC Mods", "SmartDrive", &bVCModAIDrive);
	}
	if (KEYJUSTDOWN(VCMOD_AIDRIVE_KEY))
		VCModAIDriveToggle();
}

bool
VCModAIDriveTakeover(CVehicle *car, float *swerve, float *accel, float *brake, bool *handbrake)
{
	return false;
}
```

- [ ] **Step 5: Wire the two hooks**

In `src/core/Game.cpp`, add next to the chase include and update call:

```cpp
#include "vcmodaidrive.h"
```

and after `VCModChaseUpdate();`:

```cpp
	VCModAIDriveUpdate();
```

In `src/control/CarCtrl.cpp`, add the include after `#include "CarCtrl.h"`:

```cpp
#include "vcmodaidrive.h"
```

and at the top of `CCarCtrl::SteerAICarWithPhysics`, after the four local
declarations, before the temp-action switch:

```cpp
	if (VCModAIDriveTakeover(pVehicle, &swerve, &accel, &brake, &handbrake)) {
		pVehicle->m_fSteerAngle = swerve;
		pVehicle->bIsHandbrakeOn = handbrake;
		pVehicle->m_fGasPedal = accel;
		pVehicle->m_fBrakePedal = brake;
		return;
	}
```

- [ ] **Step 6: Run the harness**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: PASS.

- [ ] **Step 7: Build**

Run from the workspace root: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 8: Set up the separate test install**

Run once:

```bash
mkdir -p "$HOME/Games/VC-ai"
for d in anim audio data models TEXT; do
	ln -sfn "$HOME/Games/VC/$d" "$HOME/Games/VC-ai/$d"
done
GAME_DIR="$HOME/Games/VC-ai" ./scripts/install.sh
```

Report the path; do not launch.

---

### Task 2: Pure decision core and harness

**Files:**
- Modify: `src/extras/vcmodaidrive.h`
- Create: `src/extras/vcmodaidrive_plan.cpp`
- Modify: `utils/test_vc_aidrive.py`

**Interfaces:**
- Consumes: `Min`, `Max`, `Sqrt` from the repo.
- Produces the seven pure functions already declared in the header. Later tasks call
  them by these exact names and argument orders.

- [ ] **Step 1: Add the failing assertions**

Append to `MAIN` in `utils/test_vc_aidrive.py`:

```c
    CHECK(VCModAIDriveStuck(1.0f, 0.0f, 0.0f, 2500), "stuck after two seconds");
    CHECK(!VCModAIDriveStuck(1.0f, 0.0f, 0.0f, 1500), "not stuck before two seconds");
    CHECK(!VCModAIDriveStuck(0.0f, 0.0f, 0.0f, 2500), "no throttle is not stuck");
    CHECK(!VCModAIDriveStuck(1.0f, 2.0f, 0.0f, 2500), "moving is not stuck");
    CHECK(!VCModAIDriveStuck(1.0f, 0.0f, 2.0f, 2500), "progress is not stuck");

    CHECK(fabs(VCModAIDriveCurveSpeed(25.0f, 8.0f) - 14.142f) < 0.01f, "curve speed 25 m");
    CHECK(VCModAIDriveCurveSpeed(0.0f, 8.0f) == 0.0f, "zero radius stops");

    float ix, iy;
    VCModAIDriveInterceptPoint(10.0f, 10.0f, 2.0f, 0.0f, 1.5f, &ix, &iy);
    CHECK(fabs(ix - 13.0f) < 0.01f && fabs(iy - 10.0f) < 0.01f, "intercept point");

    CHECK(VCModAIDriveShouldReplan(0,0, 0,0, 0.0f, 1000, 0, 5, 5, false), "exhausted replans");
    CHECK(VCModAIDriveShouldReplan(0,0, 0,0, 0.0f, 2000, 0, 0, 5, true), "moving target replans");
    CHECK(!VCModAIDriveShouldReplan(0,0, 0,0, 0.0f, 1000, 0, 0, 5, true), "fresh moving plan holds");
    CHECK(VCModAIDriveShouldReplan(6,0, 0,0, 0.0f, 1000, 0, 0, 5, false), "moved destination replans");
    CHECK(VCModAIDriveShouldReplan(0,0, 0,0, 13.0f, 1000, 0, 0, 5, false), "off plan replans");
    CHECK(!VCModAIDriveShouldReplan(0,0, 0,0, 5.0f, 1000, 0, 0, 5, false), "on plan holds");

    CHECK(VCModAIDrivePickLane(3, true, false, 1) == 0, "left turn takes lane 0");
    CHECK(VCModAIDrivePickLane(3, false, true, 1) == 2, "right turn takes the last lane");
    CHECK(VCModAIDrivePickLane(3, false, false, 1) == 1, "straight keeps the lane");
    CHECK(VCModAIDrivePickLane(3, false, false, 9) == 2, "lane clamps high");
    CHECK(VCModAIDrivePickLane(0, false, false, 1) == 0, "no lanes clamps to zero");

    CHECK(VCModAIDriveLookahead(0.0f) == 6.0f, "lookahead floor");
    CHECK(VCModAIDriveLookahead(40.0f) == 18.0f, "lookahead ceiling");
    CHECK(fabs(VCModAIDriveLookahead(10.0f) - 11.5f) < 0.01f, "lookahead scales");

    CHECK(VCModAIDriveClampSteer(1.0f, 0.5f) == 0.5f, "steer clamps high");
    CHECK(VCModAIDriveClampSteer(-1.0f, 0.5f) == -0.5f, "steer clamps low");
    CHECK(VCModAIDriveClampSteer(0.2f, 0.5f) == 0.2f, "steer passes through");
```

Add `"VCModAIDriveStuck"`, `"VCModAIDriveCurveSpeed"`,
`"VCModAIDriveInterceptPoint"`, `"VCModAIDriveShouldReplan"`,
`"VCModAIDrivePickLane"`, `"VCModAIDriveLookahead"`, `"VCModAIDriveClampSteer"`
to the `cut(PLAN, ...)` tuple. Change the source assembly to concatenate
`cut(SRC, ...)` for the Task 1 helpers and `cut(PLAN, ...)` for these.

- [ ] **Step 2: Run it and verify it fails**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: FAIL with `VCModAIDriveStuck not found`.

- [ ] **Step 3: Implement the pure functions**

Create `src/extras/vcmodaidrive_plan.cpp`:

```cpp
#include "common.h"

#include "vcmodaidrive.h"

bool
VCModAIDriveStuck(float throttle, float speed, float progress, uint32 elapsedMs)
{
	return throttle > 0.3f && speed < 0.6f && progress < 0.6f && elapsedMs >= 2000;
}

float
VCModAIDriveCurveSpeed(float radius, float latAccel)
{
	if (radius <= 0.0f)
		return 0.0f;
	return Sqrt(latAccel * radius);
}

void
VCModAIDriveInterceptPoint(float tx, float ty, float vx, float vy, float seconds,
	float *outX, float *outY)
{
	*outX = tx + vx * seconds;
	*outY = ty + vy * seconds;
}

bool
VCModAIDriveShouldReplan(float destX, float destY, float planDestX, float planDestY,
	float offPlan, uint32 now, uint32 plannedAt, int32 cursor, int32 planCount,
	bool movingTarget)
{
	if (cursor >= planCount)
		return true;
	if (movingTarget && now > plannedAt + 1500)
		return true;
	if (!movingTarget) {
		float dx = destX - planDestX;
		float dy = destY - planDestY;
		if (Sqrt(dx * dx + dy * dy) > 5.0f)
			return true;
	}
	return offPlan > 12.0f;
}

int32
VCModAIDrivePickLane(int32 lanes, bool leftTurn, bool rightTurn, int32 currentLane)
{
	// lane 0 is the fast/inside lane, matching the engine's m_bStayInFastLane
	if (lanes <= 0)
		return 0;
	if (leftTurn)
		return 0;
	if (rightTurn)
		return lanes - 1;
	return Min(Max(currentLane, 0), lanes - 1);
}

float
VCModAIDriveLookahead(float speed)
{
	return Min(18.0f, Max(6.0f, 6.0f + 0.55f * speed));
}

float
VCModAIDriveClampSteer(float angle, float maxAngle)
{
	return Min(maxAngle, Max(-maxAngle, angle));
}
```

- [ ] **Step 4: Run the harness**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: PASS.

- [ ] **Step 5: Build**

Run: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

---

### Task 3: Route planner, plan-only mode and telemetry

**Files:**
- Modify: `src/extras/vcmodaidrive.h`
- Create: `src/extras/vcmodaidrive_plan.h`
- Modify: `src/extras/vcmodaidrive.cpp`
- Modify: `src/extras/vcmodaidrive_plan.cpp`

**Interfaces:**
- Produces: `int32 VCModAIDrivePlanRoad(CVehicle *car, const CVector &dest, VCModAIDriveState *state)`
- Produces: `float VCModAIDriveDistanceToPlan(CVehicle *car, VCModAIDriveState *state)`
- Produces: `VCModAIDriveState *VCModAIDriveFindState(CVehicle *car)`
- Produces: `void VCModAIDriveLogPlan(CVehicle *car, VCModAIDriveState *state)`

- [ ] **Step 1: Add the planner**

Append to `src/extras/vcmodaidrive_plan.cpp`:

```cpp
#include "PathFind.h"
#include "Vehicle.h"

struct CVCModAIDriveSearch
{
	int32 node;
	int32 parent;
	int32 link;
	float g;
	float f;
	bool open;
	bool closed;
};

static float
Dist2D(const CVector &a, const CVector &b)
{
	return (a - b).Magnitude2D();
}

static int32
FindSearchNode(CVCModAIDriveSearch *nodes, int32 count, int32 node)
{
	for (int32 i = 0; i < count; i++)
		if (nodes[i].node == node)
			return i;
	return -1;
}

static int32
FindBestOpen(CVCModAIDriveSearch *nodes, int32 count)
{
	int32 best = -1;
	for (int32 i = 0; i < count; i++)
		if (nodes[i].open && (best < 0 || nodes[i].f < nodes[best].f))
			best = i;
	return best;
}

int32
VCModAIDrivePlanRoad(CVehicle *car, const CVector &dest, VCModAIDriveState *state)
{
	static CVCModAIDriveSearch nodes[VCMOD_AIDRIVE_MAX_SEARCH];
	int32 start = ThePaths.FindNodeClosestToCoors(car->GetPosition(), PATH_CAR, 25.0f);
	int32 goal = ThePaths.FindNodeClosestToCoors(dest, PATH_CAR, 40.0f);
	if (start < 0 || goal < 0)
		return 0;

	int32 count = 1;
	nodes[0].node = start;
	nodes[0].parent = -1;
	nodes[0].link = -1;
	nodes[0].g = 0.0f;
	nodes[0].f = Dist2D(ThePaths.m_pathNodes[start].GetPosition(), dest);
	nodes[0].open = true;
	nodes[0].closed = false;

	int32 goalSlot = -1;
	while ((goalSlot = FindBestOpen(nodes, count)) >= 0) {
		CVCModAIDriveSearch &cur = nodes[goalSlot];
		if (cur.node == goal)
			break;
		cur.open = false;
		cur.closed = true;
		CPathNode &n = ThePaths.m_pathNodes[cur.node];
		for (int32 i = 0; i < n.numLinks; i++) {
			int32 conn = n.firstLink + i;
			int32 next = ThePaths.ConnectedNode(conn);
			int32 link = ThePaths.m_carPathConnections[conn];
			CPathNode &nn = ThePaths.m_pathNodes[next];
			if (nn.bDisabled || nn.bWaterPath)
				continue;
			float step = Dist2D(n.GetPosition(), nn.GetPosition());
			float turn = 0.0f;
			if (cur.link >= 0) {
				CCarPathLink &a = ThePaths.m_carPathLinks[cur.link];
				CCarPathLink &b = ThePaths.m_carPathLinks[link];
				turn = 1.0f - (a.GetDirX() * b.GetDirX() + a.GetDirY() * b.GetDirY());
			}
			float g = cur.g + step + turn * 8.0f;
			int32 slot = FindSearchNode(nodes, count, next);
			if (slot < 0) {
				if (count >= VCMOD_AIDRIVE_MAX_SEARCH)
					continue;
				slot = count++;
				nodes[slot].node = next;
				nodes[slot].open = true;
				nodes[slot].closed = false;
			} else if (nodes[slot].closed || g >= nodes[slot].g) {
				continue;
			}
			nodes[slot].parent = goalSlot;
			nodes[slot].link = link;
			nodes[slot].g = g;
			nodes[slot].f = g + Dist2D(nn.GetPosition(), dest);
		}
	}
	if (goalSlot < 0 || nodes[goalSlot].node != goal)
		return 0;

	int32 chain[VCMOD_AIDRIVE_MAX_POINTS];
	int32 chainCount = 0;
	for (int32 slot = goalSlot; slot >= 0 && chainCount < VCMOD_AIDRIVE_MAX_POINTS;
	     slot = nodes[slot].parent)
		chain[chainCount++] = slot;

	state->planCount = 0;
	for (int32 i = chainCount - 1; i >= 0; i--) {
		CPathNode &pn = ThePaths.m_pathNodes[nodes[chain[i]].node];
		state->plan[state->planCount].pos = pn.GetPosition();
		state->plan[state->planCount].node = nodes[chain[i]].node;
		state->plan[state->planCount].link = nodes[chain[i]].link;
		state->plan[state->planCount].lane = 0;
		state->planCount++;
	}
	return state->planCount;
}
```

- [ ] **Step 2: Add the registry and plan-only dispatch**

Create `src/extras/vcmodaidrive_plan.h`:

```cpp
#ifndef __VCMODAIDRIVEPLAN_H__
#define __VCMODAIDRIVEPLAN_H__

#include "vcmodaidrive.h"

class CVehicle;

VCModAIDriveState *VCModAIDriveFindState(CVehicle *car);
void VCModAIDriveLogPlan(CVehicle *car, VCModAIDriveState *state);
int32 VCModAIDrivePlanRoad(CVehicle *car, const CVector &dest, VCModAIDriveState *state);
float VCModAIDriveDistanceToPlan(CVehicle *car, VCModAIDriveState *state);
bool VCModAIDriveCanCut(CVehicle *car, const CVector &point);

#endif
```

In `src/extras/vcmodaidrive.cpp`, replace the empty `VCModAIDriveTakeover` and
extend `VCModAIDriveUpdate`:

```cpp
#include "vcmodaidrive_plan.h"

static VCModAIDriveState aVCModAIDriveState[VCMOD_AIDRIVE_MAX_ACTIVE];
static bool bVCModAIDrivePlanOnly = true;
static bool bVCModAIDriveInit;

float
VCModAIDriveDistanceToPlan(CVehicle *car, VCModAIDriveState *state)
{
	if (state->planCount == 1)
		return (car->GetPosition() - state->plan[0].pos).Magnitude2D();
	if (state->planCount < 2)
		return 9999.0f;
	float best = 9999.0f;
	CVector2D p = car->GetPosition();
	for (int32 i = 0; i < state->planCount - 1; i++) {
		CVector2D a = state->plan[i].pos;
		CVector2D b = state->plan[i + 1].pos;
		CVector2D ab = b - a;
		float len = ab.Magnitude();
		float t = len > 0.01f ?
			Min(1.0f, Max(0.0f, DotProduct2D(p - a, ab) / (len * len))) : 0.0f;
		CVector2D closest = a + ab * t;
		best = Min(best, (p - closest).Magnitude());
	}
	return best;
}

VCModAIDriveState *
VCModAIDriveFindState(CVehicle *car)
{
	if (!bVCModAIDriveInit) {
		bVCModAIDriveInit = true;
		for (int32 i = 0; i < VCMOD_AIDRIVE_MAX_ACTIVE; i++)
			aVCModAIDriveState[i].vehicleHandle = -1;
	}
	int32 handle = CPools::GetVehiclePool()->GetIndex(car);
	for (int32 i = 0; i < VCMOD_AIDRIVE_MAX_ACTIVE; i++)
		if (aVCModAIDriveState[i].vehicleHandle == handle)
			return &aVCModAIDriveState[i];
	for (int32 i = 0; i < VCMOD_AIDRIVE_MAX_ACTIVE; i++) {
		if (aVCModAIDriveState[i].vehicleHandle < 0) {
			VCModAIDriveState *state = &aVCModAIDriveState[i];
			memset(state, 0, sizeof(*state));
			state->vehicleHandle = handle;
			state->phase = VCMOD_AIDRIVE_FOLLOW;
			state->mode = VCMOD_AIDRIVE_ROAD;
			state->lane = 0;
			return state;
		}
	}
	return nil;
}

static void
VCModAIDriveLogPlan(CVehicle *car, VCModAIDriveState *state)
{
	uint32 now = CTimer::GetTimeInMilliseconds();
	if (now < state->telemetryAt + 1000)
		return;
	state->telemetryAt = now;
	fprintf(stderr, "VCMOD AIDRIVE car=%d phase=%d mode=%d pts=%d dest=%.1f,%.1f\n",
		car->GetModelIndex(), state->phase, state->mode, state->planCount,
		state->planDestination.x, state->planDestination.y);
	for (int32 i = 0; i < Min(8, state->planCount); i++)
		fprintf(stderr, "VCMOD AIDRIVE pt%d=%.1f,%.1f node=%d\n", i,
			state->plan[i].pos.x, state->plan[i].pos.y, state->plan[i].node);
	if (state->planCount > 8)
		fprintf(stderr, "VCMOD AIDRIVE end=%.1f,%.1f\n",
			state->plan[state->planCount - 1].pos.x,
			state->plan[state->planCount - 1].pos.y);
}

static void
VCModAIDriveHousekeep(void)
{
	for (int32 i = 0; i < VCMOD_AIDRIVE_MAX_ACTIVE; i++) {
		VCModAIDriveState *state = &aVCModAIDriveState[i];
		if (state->vehicleHandle < 0)
			continue;
		if (CPools::GetVehiclePool()->GetAt(state->vehicleHandle) == nil)
			state->vehicleHandle = -1;
	}
}

bool
VCModAIDriveTakeover(CVehicle *car, float *swerve, float *accel, float *brake, bool *handbrake)
{
	if (!VCModAIDriveEligible(bVCModAIDrive, car->IsCar(),
		car->pDriver != nil && car->pDriver->IsPlayer(), car->pDriver != nil,
		car->GetStatus() == STATUS_PHYSICS,
		VCModAIDriveMissionDrives(car->AutoPilot.m_nCarMission),
		car->AutoPilot.m_nTempAction == TEMPACT_NONE))
		return false;

	VCModAIDriveState *state = VCModAIDriveFindState(car);
	if (state == nil)
		return false;

	state->mode = VCModAIDriveModeFor(car->AutoPilot.m_nCarMission,
		car->AutoPilot.m_bIgnorePathfinding);
	if (!state->gaveUp && state->phase != VCMOD_AIDRIVE_RECOVER &&
	    state->phase != VCMOD_AIDRIVE_CUT)
		state->phase = state->mode == VCMOD_AIDRIVE_PURSUIT ?
			VCMOD_AIDRIVE_PURSUE :
			state->mode == VCMOD_AIDRIVE_STRAIGHT ? VCMOD_AIDRIVE_DIRECT : VCMOD_AIDRIVE_FOLLOW;

	uint32 now = CTimer::GetTimeInMilliseconds();
	bool needsPlan = state->planCount == 0 ||
		VCModAIDriveShouldReplan(car->AutoPilot.m_vecDestinationCoors.x,
			car->AutoPilot.m_vecDestinationCoors.y,
			state->planDestination.x, state->planDestination.y,
			VCModAIDriveDistanceToPlan(car, state), now, state->plannedAt,
			state->cursor, state->planCount, false);
	if (needsPlan) {
		state->planDestination = car->AutoPilot.m_vecDestinationCoors;
		state->planCount = state->mode == VCMOD_AIDRIVE_STRAIGHT ? 0 :
			VCModAIDrivePlanRoad(car, state->planDestination, state);
		if (state->planCount == 0 && state->mode != VCMOD_AIDRIVE_STRAIGHT) {
			state->plan[0].pos = state->planDestination;
			state->plan[0].node = -1;
			state->plan[0].link = -1;
			state->plan[0].lane = 0;
			state->planCount = 1;
		}
		state->cursor = 0;
		state->plannedAt = now;
		state->gaveUp = false;
	}
	if (state->planCount == 1 && state->plannedAt != 0 && now < state->plannedAt + 1000)
		needsPlan = false;
	VCModAIDriveLogPlan(car, state);

	if (bVCModAIDrivePlanOnly)
		return false;
	return false;
}
```

Add to `VCModAIDriveUpdate`:

```cpp
	VCModAIDriveHousekeep();
```

Also declare `VCModAIDriveFindState` and `VCModAIDriveLogPlan` in
`src/extras/vcmodaidrive_plan.h` (create it; it includes `vcmodaidrive.h`).

- [ ] **Step 3: Build and run the harness**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: PASS.

Run: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 4: Plan-only in-game check (user runs)**

Install:

```bash
GAME_DIR="$HOME/Games/VC-ai" ./scripts/install.sh
```

Hand the user this checklist:

1. Launch the test install:

```bash
cd "$HOME/Games/VC-ai" && ./reVC.app/Contents/MacOS/reVC 2>> reVC.log
```

Press `K`; the log says `VCMOD AIDRIVE on`.
2. Start the chase. The leader still drives stock.
3. In `~/Games/VC-ai/reVC.log` (or the terminal), every active mission car logs a
   plan with 3 or more points, and consecutive point coordinates follow a road.
4. If a plan has `pts=0`, note the destination; it is a planner gap.

---

### Task 4: Controller and static takeover (v1a)

**Files:**
- Create: `src/extras/vcmodaidrive_control.cpp`
- Modify: `src/extras/vcmodaidrive.cpp`
- Modify: `src/extras/vcmodaidrive.h`

**Interfaces:**
- Produces: `bool VCModAIDriveControl(CVehicle *car, VCModAIDriveState *state, float *swerve, float *accel, float *brake, bool *handbrake)`
- Add that declaration to `src/extras/vcmodaidrive.h`; `vcmodaidrive.cpp` calls it.
- `VCModAIDriveTakeover` returns true when a plan exists and the mode is not plan-only.

- [ ] **Step 1: Create the controller**

`src/extras/vcmodaidrive_control.cpp`:

```cpp
#include "common.h"

#include "vcmodaidrive.h"
#include "CarCtrl.h"
#include "General.h"
#include "PathFind.h"
#include "TrafficLights.h"
#include "Vehicle.h"
#include "World.h"

static float
ObstacleLimit(CVehicle *car, float cruise)
{
	int16 count;
	CEntity *entities[8];
	CVector forward = car->GetForward();
	float limit = cruise;
	CWorld::FindObjectsInRange(car->GetPosition(), 25.0f, true, &count, 8, entities,
		false, true, false, false, false);
	for (int32 i = 0; i < count; i++) {
		if (entities[i] == car || !entities[i]->IsVehicle())
			continue;
		CVector delta = entities[i]->GetPosition() - car->GetPosition();
		float ahead = DotProduct2D(delta, forward);
		if (ahead <= 0.0f || ahead > 20.0f)
			continue;
		float side = ABS(delta.x * forward.y - delta.y * forward.x);
		if (side > 3.5f)
			continue;
		limit = Min(limit, Sqrt(Max(0.0f, 2.0f * 8.0f * (ahead - 5.0f))));
	}
	return limit;
}

static CVector
PlanTarget(CVehicle *car, VCModAIDriveState *state, float lookahead)
{
	if (state->planCount == 0)
		return car->GetPosition();
	int32 last = state->planCount - 1;
	int32 i = Max(state->cursor, 0);
	while (i < last && (state->plan[i].pos - car->GetPosition()).Magnitude2D() < lookahead)
		i++;
	state->cursor = i;
	int32 link = state->plan[i].link;
	if (link >= 0) {
		CCarPathLink &l = ThePaths.m_carPathLinks[link];
		int32 lanes = l.numLeftLanes + l.numRightLanes;
		bool left = false, right = false;
		if (i + 1 < state->planCount) {
			int32 nextLink = state->plan[i + 1].link;
			if (nextLink >= 0) {
				CCarPathLink &n = ThePaths.m_carPathLinks[nextLink];
				float cross = l.GetDirX() * n.GetDirY() - l.GetDirY() * n.GetDirX();
				left = cross > 0.2f;
				right = cross < -0.2f;
			}
		}
		state->lane = VCModAIDrivePickLane(lanes, left, right, state->lane);
	}
	CVector target = state->plan[i].pos;
	if (link >= 0) {
		CCarPathLink &l = ThePaths.m_carPathLinks[link];
		CVector2D dir(l.GetDirX(), l.GetDirY());
		CVector2D side(dir.y, -dir.x);
		float offset = (state->lane + l.OneWayLaneOffset()) * LANE_WIDTH;
		target.x += side.x * offset;
		target.y += side.y * offset;
	}
	return target;
}

static bool
DriveTo(CVehicle *car, const CVector &target, float cruise, VCModAIDriveState *state,
	float *swerve, float *accel, float *brake, bool *handbrake)
{
	CVector2D forward = car->GetForward();
	forward.Normalise();
	float heading = CGeneral::GetATanOfXY(forward.x, forward.y);
	float want = CGeneral::GetATanOfXY(target.x - car->GetPosition().x,
		target.y - car->GetPosition().y);
	float steer = VCModAIDriveClampSteer(CGeneral::LimitRadianAngle(want - heading),
		CCarCtrl::FindMaxSteerAngle(car));

	float speedLimit = cruise;
	if (state->cursor + 1 < state->planCount) {
		CVector a = state->plan[state->cursor].pos;
		CVector b = state->plan[state->cursor + 1].pos;
		CVector2D ab(b.x - a.x, b.y - a.y);
		float len = ab.Magnitude();
		float turn = ABS(CGeneral::LimitRadianAngle(
			CGeneral::GetATanOfXY(ab.x, ab.y) - heading));
		float radius = turn > 0.05f ? len / turn : 1000.0f;
		speedLimit = Min(speedLimit, VCModAIDriveCurveSpeed(radius, 8.0f));
	}
	speedLimit = Min(speedLimit, ObstacleLimit(car, speedLimit));
	if (car->AutoPilot.m_nDrivingStyle == DRIVINGSTYLE_STOP_FOR_CARS &&
	    CTrafficLights::ShouldCarStopForLight(car, false))
		speedLimit = 0.0f;

	float speed = car->GetMoveSpeed().Magnitude() * GAME_SPEED_TO_CARAI_SPEED;
	float diff = speedLimit - speed;
	*swerve = steer;
	*handbrake = false;
	*accel = diff > 0.0f ? Min(1.0f, diff * (speed < 2.0f ? 0.25f : 0.125f)) : 0.0f;
	*brake = diff < 0.0f ? Min(0.5f, -diff * 0.05f) : 0.0f;
	if (speedLimit < 0.05f && diff < 0.03f) {
		*accel = 0.0f;
		*brake = 1.0f;
	}
	return true;
}

bool
VCModAIDriveControl(CVehicle *car, VCModAIDriveState *state, float *swerve,
	float *accel, float *brake, bool *handbrake)
{
	if (state->mode == VCMOD_AIDRIVE_STRAIGHT)
		return DriveTo(car, car->AutoPilot.m_vecDestinationCoors,
			car->AutoPilot.GetCruiseSpeed(), state, swerve, accel, brake, handbrake);
	if (state->planCount == 0 || state->cursor >= state->planCount)
		return false;
	float lookahead = VCModAIDriveLookahead(
		car->GetMoveSpeed().Magnitude() * GAME_SPEED_TO_CARAI_SPEED);
	CVector target = PlanTarget(car, state, lookahead);
	return DriveTo(car, target, car->AutoPilot.GetCruiseSpeed(), state,
		swerve, accel, brake, handbrake);
}
```

- [ ] **Step 2: Take over in `Takeover`**

Change the last block of `VCModAIDriveTakeover` from the plan-only return to:

```cpp
	if (bVCModAIDrivePlanOnly)
		return false;
	return VCModAIDriveControl(car, state, swerve, accel, brake, handbrake);
```

Set `bVCModAIDrivePlanOnly = false;` for the build, but keep the variable so Task 3
can be re-enabled.

- [ ] **Step 3: Build and test**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: PASS.

Run: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 4: Static-route in-game check (user runs)**

Install to `~/Games/VC-ai` and hand over:

1. Toggle on; start the chase. The leader drives its three beats without missing a
   junction or driving on the pavement.
2. It does not change lanes randomly; it does not flip at corners.
3. If it stops, log the `VCMOD AIDRIVE` line and the surrounding `reVC.log` tail.
4. Toggle off; the car returns to stock behaviour immediately.

---

### Task 5: Stuck recovery

**Files:**
- Modify: `src/extras/vcmodaidrive_control.cpp`
- Modify: `src/extras/vcmodaidrive.cpp`

- [ ] **Step 1: Add the recovery branch**

In `VCModAIDriveTakeover`, before the plan check, make the give-up sticky until the
destination changes:

```cpp
	if (state->gaveUp) {
		if ((car->AutoPilot.m_vecDestinationCoors - state->planDestination).Magnitude2D() > 5.0f) {
			state->gaveUp = false;
			state->recoveryAttempts = 0;
			state->planCount = 0;
			state->cursor = 0;
		} else {
			return VCModAIDriveControl(car, state, swerve, accel, brake, handbrake);
		}
	}
```

At the top of `VCModAIDriveControl`:

```cpp
	uint32 now = CTimer::GetTimeInMilliseconds();
	if (state->phase == VCMOD_AIDRIVE_RECOVER) {
		if (now < state->recoveryUntil) {
			*swerve = state->recoverySteer;
			*accel = -0.5f;
			*brake = 0.0f;
			*handbrake = false;
			return true;
		}
		state->phase = VCMOD_AIDRIVE_FOLLOW;
		state->planCount = 0;
		state->cursor = 0;
	}
```

Add the give-up exit and a `CheckStuck` helper, and call the helper before mode
dispatch so direct and planned driving both recover:

```cpp
static void
CheckStuck(CVehicle *car, VCModAIDriveState *state, uint32 now)
{
	CVector pos = car->GetPosition();
	if (state->progressAt == 0) {
		state->progressAt = now;
		state->progressPos = pos;
	}
	float moved = (pos - state->progressPos).Magnitude2D();
	if (moved > 0.6f) {
		state->progressAt = now;
		state->progressPos = pos;
		moved = 0.0f;
	}
	if (state->phase == VCMOD_AIDRIVE_RECOVER)
		return;
	if (VCModAIDriveStuck(car->m_fGasPedal,
		car->GetMoveSpeed().Magnitude() * GAME_SPEED_TO_CARAI_SPEED,
		moved, now - state->progressAt)) {
		state->recoveryAttempts++;
		state->phase = VCMOD_AIDRIVE_RECOVER;
		state->recoveryUntil = now + 1500;
		state->recoverySteer = car->m_fSteerAngle >= 0.0f ? -0.5f : 0.5f;
		state->progressAt = now;
		state->progressPos = pos;
		fprintf(stderr, "VCMOD AIDRIVE recover attempt=%d\n", state->recoveryAttempts);
	}
	if (state->recoveryAttempts >= 3 && !state->gaveUp) {
		state->gaveUp = true;
		state->phase = VCMOD_AIDRIVE_OFF;
		fprintf(stderr, "VCMOD AIDRIVE stuck, leaving it to the mission\n");
	}
}
```

Then in `VCModAIDriveControl`, immediately after the recovery branch:

```cpp
	if (state->phase == VCMOD_AIDRIVE_OFF) {
		*swerve = 0.0f;
		*accel = 0.0f;
		*brake = 1.0f;
		*handbrake = true;
		return true;
	}
	CheckStuck(car, state, now);
```

- [ ] **Step 2: Build**

Run: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 3: Recovery in-game check (user runs)**

1. Wedge the chase car into traffic or a wall.
2. It reverses within about 2 s, re-plans, and resumes.
3. A second failure logs `recover attempt=2`; a third logs
   `stuck, leaving it to the mission`.

---

### Task 6: Moving-target pursuit and safe cuts (v1b)

**Files:**
- Modify: `src/extras/vcmodaidrive.cpp`
- Modify: `src/extras/vcmodaidrive_plan.cpp`
- Modify: `src/extras/vcmodaidrive_control.cpp`

- [ ] **Step 1: Track the target**

Add to the top of `vcmodaidrive.cpp`:

```cpp
#include "ColPoint.h"
#include "World.h"
```

In `VCModAIDriveUpdate`, before the housekeeping call, add:

```cpp
static void
VCModAIDriveTrackTargets(void)
{
	for (int32 i = 0; i < VCMOD_AIDRIVE_MAX_ACTIVE; i++) {
		VCModAIDriveState *state = &aVCModAIDriveState[i];
		if (state->vehicleHandle < 0)
			continue;
		CVehicle *car = CPools::GetVehiclePool()->GetAt(state->vehicleHandle);
		if (car == nil)
			continue;
		uint32 now = CTimer::GetTimeInMilliseconds();
		CVector dest = car->AutoPilot.m_vecDestinationCoors;
		if (state->lastDestinationAt != 0) {
			float dt = (now - state->lastDestinationAt) / 1000.0f;
			if (dt > 0.01f) {
				CVector delta = dest - state->lastDestination;
				float step = delta.Magnitude2D();
				if (step > 2.0f && step / dt < 60.0f) {
					state->targetPos = dest;
					state->targetVel = delta * (1.0f / dt);
					state->targetSeenAt = now;
				}
			}
		}
		state->lastDestination = dest;
		state->lastDestinationAt = now;
	}
}
```

Call it from `VCModAIDriveUpdate`. In `VCModAIDriveTakeover`, insert the smoothed
target block immediately after `uint32 now = CTimer::GetTimeInMilliseconds();` and
before the plan check:

```cpp
	bool movingTarget = state->targetSeenAt != 0 &&
		now < state->targetSeenAt + 3000 &&
		state->targetVel.Magnitude2D() > 1.0f;
	if (movingTarget && state->mode != VCMOD_AIDRIVE_STRAIGHT) {
		float age = (now - state->targetSeenAt) / 1000.0f;
		CVector targetNow = state->targetPos + state->targetVel * age;
		float ix, iy;
		VCModAIDriveInterceptPoint(targetNow.x, targetNow.y,
			state->targetVel.x, state->targetVel.y, 1.5f, &ix, &iy);
		state->planDestination = CVector(ix, iy, targetNow.z);
		state->mode = VCMOD_AIDRIVE_PURSUIT;
	}
```

Then plan to `state->planDestination`. In the `needsPlan` block, guard the
destination assignment so the predicted point is not overwritten:

```cpp
	if (needsPlan) {
		if (!movingTarget)
			state->planDestination = car->AutoPilot.m_vecDestinationCoors;
		/* existing plan call, no-route fallback, cursor and timestamp */
	}
```

Use `movingTarget` as the `ShouldReplan` flag. When the phase is `CUT`, skip the
planner and drive the cut directly:

```cpp
	if (state->phase == VCMOD_AIDRIVE_CUT) {
		state->planCount = 0;
		needsPlan = false;
	}
```

- [ ] **Step 2: Add the safe cut**

In `vcmodaidrive_plan.cpp`:

```cpp
#include "ColPoint.h"
#include "WaterLevel.h"
#include "World.h"

bool
VCModAIDriveCanCut(CVehicle *car, const CVector &point)
{
	if ((point - car->GetPosition()).Magnitude2D() > 40.0f)
		return false;
	CColPoint col;
	CEntity *hit = nil;
	if (CWorld::ProcessLineOfSight(car->GetPosition(), point, col, hit,
		true, false, false, false, false, false))
		return false;
	float level;
	CVector mid = (car->GetPosition() + point) * 0.5f;
	if (CWaterLevel::GetWaterLevel(mid, &level, true) ||
	    CWaterLevel::GetWaterLevel(point, &level, true))
		return false;
	return ThePaths.FindNodeClosestToCoors(point, PATH_CAR, 20.0f) >= 0;
}
```

Declare it in `vcmodaidrive_plan.h`. In `Takeover`, when pursuing and the target is
visible, choose `CUT`:

```cpp
	if (state->mode == VCMOD_AIDRIVE_PURSUIT && movingTarget) {
		float age = (now - state->targetSeenAt) / 1000.0f;
		CVector targetNow = state->targetPos + state->targetVel * age;
		CVector target = targetNow + state->targetVel * 1.5f;
		CColPoint sightCol;
		CEntity *sightHit = nil;
		if (!CWorld::ProcessLineOfSight(car->GetPosition(), targetNow,
			sightCol, sightHit, true, false, false, false, false, false) &&
		    VCModAIDriveCanCut(car, target)) {
			state->phase = VCMOD_AIDRIVE_CUT;
			state->planDestination = target;
		}
	}
```

In `VCModAIDriveControl`, add the cut branch after the direct-mode branch:

```cpp
	if (state->phase == VCMOD_AIDRIVE_CUT) {
		if ((state->planDestination - car->GetPosition()).Magnitude2D() < 8.0f) {
			state->phase = VCMOD_AIDRIVE_FOLLOW;
			state->planCount = 0;
			state->cursor = 0;
		} else {
			return DriveTo(car, state->planDestination,
				car->AutoPilot.GetCruiseSpeed(), state,
				swerve, accel, brake, handbrake);
		}
	}
```

- [ ] **Step 3: Build and test**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: PASS.

Run: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 4: Pursuit in-game check (user runs)**

1. Start the chase; the squad car closes the gap on open road instead of following
   the leader's old spot.
2. It takes a cut only when there is clear ground; it does not cross water or
   buildings.
3. No lane flips and no lurch when the chase re-targets.

---

### Task 7: Acceptance, performance and documentation

**Files:**
- Modify: `src/extras/vcmodaidrive.cpp` (telemetry final pass)
- Modify: `README.md`, `CHANGELOG.md` (only after the user confirms the behaviour)
- Test: `utils/test_vc_aidrive.py`

- [ ] **Step 1: Add the frame-budget telemetry**

Add counters in `vcmodaidrive.cpp`:

```cpp
static uint32 nVCModAIDriveCostCycles;
static uint32 nVCModAIDriveCostAt;
static int32 nVCModAIDriveCars;
```

Wrap the body of `VCModAIDriveTakeover` after the eligibility check:

```cpp
	uint32 costStart = CTimer::GetCurrentTimeInCycles();
	...existing body...
	nVCModAIDriveCostCycles += CTimer::GetCurrentTimeInCycles() - costStart;
	nVCModAIDriveCars++;
```

In `VCModAIDriveUpdate`, once per second:

```cpp
	uint32 now = CTimer::GetTimeInMilliseconds();
	if (now > nVCModAIDriveCostAt + 1000) {
		float ms = (float)nVCModAIDriveCostCycles /
			Max(1.0f, CTimer::GetCyclesPerMillisecond());
		fprintf(stderr, "VCMOD AIDRIVE active=%d cost=%.2fms\n",
			nVCModAIDriveCars, ms);
		nVCModAIDriveCostCycles = 0;
		nVCModAIDriveCars = 0;
		nVCModAIDriveCostAt = now;
	}
```

Target under 1 ms for 8 active cars. If it is over, stagger re-planning across
frames before changing anything else.

- [ ] **Step 2: Run the full harness and build**

Run: `python3 utils/test_vc_aidrive.py -v`
Expected: PASS.

Run: `./scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 3: Hand over the acceptance checklist**

1. Cross-map static route: no missed turn, no backtrack, no wrong-way lane.
2. Squad pursuit: gap closes over 20-30 s; no random lane flips; no lurch on re-target.
3. Stuck case: recover or log failure within 3 s; no wall grinding.
4. Cruise-speed corners: no flips.
5. Mode off: chase and a story mission behave exactly like stock.
6. Performance line under 1 ms with 8 active cars.

- [ ] **Step 4: Document after the user confirms**

Add the `SmartDrive` key and the `K` toggle to the config/panel section of
`README.md`, and a `CHANGELOG.md` entry. Do not commit; report the files.

---

## Self-Review

- **Spec coverage:** every spec section maps to a task: module/flag/eligibility
  (1), pure decisions (2), planner and lane plan (3), controller and lights/obstacles
  (4), recovery (5), pursuit/intercept/safe cut (6), telemetry/performance/docs (7).
- **No placeholders:** all functions and signatures used by later tasks are defined
  in earlier tasks.
- **Type consistency:** `VCModAIDriveState`, `VCModAIDrivePoint`,
  `VCModAIDrivePlanRoad`, `VCModAIDriveControl`, `VCModAIDriveFindState` and
  `VCModAIDriveCanCut` keep the same names and argument orders across tasks.
