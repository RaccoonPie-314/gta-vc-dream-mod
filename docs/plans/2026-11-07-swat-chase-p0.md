# SWAT Chase P0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the P0 shell of the SWAT chase mission: a mission state machine, a pink station marker with a radar blip pinned to VCPD HQ, five-tier selection (COP, SWAT, VICE, FBI, ARMY) that swaps the player's uniform and animation, and a clean restore to free roam.

**Architecture:** A new `extras/vcmodchase` module holds the mission state and a pure decision core. `CGame::Process` calls one update function per frame. Presentation uses the engine's own 3D marker, radar blip and help-message paths. The uniform uses the mod's existing `VCModApplyPedModel` swap, with the pre-mission model and NPC-animation toggle saved and restored.

**Tech Stack:** reVC C++ (branch `vcmods`), CMake build via `scripts/build.sh`, Python 3 brace-extraction harness under `utils/`.

**Spec:** `docs/specs/2026-11-07-swat-chase-design.md`

## Global Constraints

- Work only in `src/extras/vcmodchase.h`, `src/extras/vcmodchase.cpp`, `src/core/Game.cpp` and `utils/test_vc_chase.py`.
- Do not modify or stage `src/peds/PlayerPed.cpp`. Another agent has an uncommitted change there.
- Stage explicit paths only. Never `git add -A` or `git commit -am`.
- Do not push the reVC repository. Commits stay local on `vcmods`.
- No SCM edits, no Rockstar data edits, no savegame changes.
- No health or damage scaling; P0 adds no combat.
- Leave no trace: the model, animation group, marker, blip and mission state must be gone when the mission ends.
- Follow the repo's C++ style: tabs, function opening brace on its own line.
- P0 allows every tier regardless of rank. Rank gating and ini persistence land in P4.
- Verification is harness plus build, then an in-game handoff. Do not launch the game.

---

## File Structure

- `src/extras/vcmodchase.h` — public enums, pure API and the update entry point.
- `src/extras/vcmodchase.cpp` — pure state logic, mission state, marker, blip, input, uniform and cleanup.
- `src/core/Game.cpp` — one include and one `VCModChaseUpdate()` call in the frame loop.
- `utils/test_vc_chase.py` — brace-extracts the pure functions and runs them against C++98 stubs.

No CMake edit: the source list is `file(GLOB_RECURSE ...)` and `scripts/build.sh` reconfigures.

---

### Task 1: Module Skeleton and Pure State Core

**Files:**
- Create: `src/extras/vcmodchase.h`
- Create: `src/extras/vcmodchase.cpp`
- Modify: `src/core/Game.cpp:933-937`
- Test: `utils/test_vc_chase.py`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `enum eVCModChaseState { VCMOD_CHASE_OFF, VCMOD_CHASE_TIER_SELECT, VCMOD_CHASE_BRIEFING, VCMOD_CHASE_RUNNING }`
  - `enum eVCModChaseEvent { VCMOD_CHASE_EV_ENTER_MARKER, VCMOD_CHASE_EV_CONFIRM, VCMOD_CHASE_EV_CANCEL, VCMOD_CHASE_EV_FINISH }`
  - `enum eVCModChaseUnit { VCMOD_UNIT_NONE, VCMOD_UNIT_COP, VCMOD_UNIT_SWAT, VCMOD_UNIT_VICE, VCMOD_UNIT_FBI, VCMOD_UNIT_ARMY }`
  - `bool VCModChaseNextState(eVCModChaseState *state, eVCModChaseEvent event)`
  - `eVCModChaseUnit VCModChaseUnitForTier(int32 tier)`
  - `int16 VCModChaseUnitModel(eVCModChaseUnit unit)`
  - `int16 VCModChaseViceModel(int32 variant)`
  - `bool VCModChaseTierAllowed(int32 tier, int32 rank)`
  - `bool VCModChaseRestoreDue(bool pending, bool inControl, bool playerExists)`
  - `bool VCModChaseShouldShowMarker(eVCModChaseState state, bool spotSet)`
  - `void VCModChaseUpdate(void)`
  - `void VCModChaseReset(void)`

- [ ] **Step 1: Write the failing harness**

Create `utils/test_vc_chase.py`:

```python
#!/usr/bin/env python3
"""Pure chase-mission logic, brace-extracted from vcmodchase.cpp and run
against C++98 stubs. Mirrors the shape of test_vc_driver.py."""
import pathlib
import re
import subprocess
import tempfile
import unittest

SRC = pathlib.Path(__file__).resolve().parents[1] / "src/extras/vcmodchase.cpp"

PRELUDE = r'''
#include <stdio.h>
typedef int int32;
typedef short int16;
enum eVCModChaseState { VCMOD_CHASE_OFF, VCMOD_CHASE_TIER_SELECT, VCMOD_CHASE_BRIEFING, VCMOD_CHASE_RUNNING };
enum eVCModChaseEvent { VCMOD_CHASE_EV_ENTER_MARKER, VCMOD_CHASE_EV_CONFIRM, VCMOD_CHASE_EV_CANCEL, VCMOD_CHASE_EV_FINISH };
enum eVCModChaseUnit { VCMOD_UNIT_NONE, VCMOD_UNIT_COP, VCMOD_UNIT_SWAT, VCMOD_UNIT_VICE, VCMOD_UNIT_FBI, VCMOD_UNIT_ARMY };
static int failed = 0;
#define CHECK(c, m) do { if (!(c)) { printf("FAIL: %s\n", m); failed++; } } while (0)
'''

MAIN = r'''
int main() {
    eVCModChaseState s;

    s = VCMOD_CHASE_OFF;
    CHECK(VCModChaseNextState(&s, VCMOD_CHASE_EV_ENTER_MARKER) && s == VCMOD_CHASE_TIER_SELECT,
          "marker enters tier select");
    s = VCMOD_CHASE_TIER_SELECT;
    CHECK(!VCModChaseNextState(&s, VCMOD_CHASE_EV_ENTER_MARKER) && s == VCMOD_CHASE_TIER_SELECT,
          "marker is ignored while selecting");
    s = VCMOD_CHASE_TIER_SELECT;
    CHECK(VCModChaseNextState(&s, VCMOD_CHASE_EV_CANCEL) && s == VCMOD_CHASE_OFF,
          "cancel leaves tier select");
    s = VCMOD_CHASE_TIER_SELECT;
    CHECK(VCModChaseNextState(&s, VCMOD_CHASE_EV_CONFIRM) && s == VCMOD_CHASE_BRIEFING,
          "confirm opens the briefing");
    s = VCMOD_CHASE_BRIEFING;
    CHECK(VCModChaseNextState(&s, VCMOD_CHASE_EV_CONFIRM) && s == VCMOD_CHASE_RUNNING,
          "confirm starts the run");
    s = VCMOD_CHASE_RUNNING;
    CHECK(VCModChaseNextState(&s, VCMOD_CHASE_EV_FINISH) && s == VCMOD_CHASE_OFF,
          "finish returns to off");
    s = VCMOD_CHASE_RUNNING;
    CHECK(VCModChaseNextState(&s, VCMOD_CHASE_EV_CANCEL) && s == VCMOD_CHASE_OFF,
          "cancel ends the run");
    s = VCMOD_CHASE_OFF;
    CHECK(!VCModChaseNextState(&s, VCMOD_CHASE_EV_FINISH) && s == VCMOD_CHASE_OFF,
          "finish is ignored when off");

    CHECK(VCModChaseUnitForTier(1) == VCMOD_UNIT_COP, "tier 1 is COP");
    CHECK(VCModChaseUnitForTier(2) == VCMOD_UNIT_SWAT, "tier 2 is SWAT");
    CHECK(VCModChaseUnitForTier(3) == VCMOD_UNIT_VICE, "tier 3 is VICE");
    CHECK(VCModChaseUnitForTier(4) == VCMOD_UNIT_FBI, "tier 4 is FBI");
    CHECK(VCModChaseUnitForTier(5) == VCMOD_UNIT_ARMY, "tier 5 is ARMY");
    CHECK(VCModChaseUnitForTier(0) == VCMOD_UNIT_NONE, "tier 0 is none");
    CHECK(VCModChaseUnitForTier(6) == VCMOD_UNIT_NONE, "tier 6 is none");

    CHECK(VCModChaseTierAllowed(1, 1), "rank 1 allows tier 1");
    CHECK(VCModChaseTierAllowed(2, 2), "rank 2 allows tier 2");
    CHECK(VCModChaseTierAllowed(3, 3), "rank 3 allows tier 3");
    CHECK(!VCModChaseTierAllowed(4, 3), "rank 3 denies tier 4");
    CHECK(VCModChaseTierAllowed(5, 5), "rank 5 allows tier 5");
    CHECK(!VCModChaseTierAllowed(0, 5), "tier 0 is never allowed");
    CHECK(!VCModChaseTierAllowed(6, 5), "tier 6 is never allowed");

    CHECK(VCModChaseRestoreDue(true, true, true), "restore when pending and in control");
    CHECK(!VCModChaseRestoreDue(true, false, true), "no restore out of control");
    CHECK(!VCModChaseRestoreDue(true, true, false), "no restore without a player");
    CHECK(!VCModChaseRestoreDue(false, true, true), "no restore when not pending");

    CHECK(VCModChaseShouldShowMarker(VCMOD_CHASE_OFF, true), "marker shows when off");
    CHECK(!VCModChaseShouldShowMarker(VCMOD_CHASE_OFF, false), "no marker without a spot");
    CHECK(!VCModChaseShouldShowMarker(VCMOD_CHASE_TIER_SELECT, true), "no marker while selecting");

    return failed ? 1 : 0;
}
'''


def cut(name):
    text = SRC.read_text()
    match = re.search(r"([A-Za-z_][A-Za-z0-9_]*\s+)" + re.escape(name) + r"\s*\([^;{]*\)\s*\{", text)
    if match is None:
        raise AssertionError(f"{name} not found in {SRC}")
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


def source():
    return PRELUDE + "\n".join(cut(n) for n in (
        "VCModChaseNextState",
        "VCModChaseUnitForTier",
        "VCModChaseTierAllowed",
        "VCModChaseRestoreDue",
        "VCModChaseShouldShowMarker",
    )) + MAIN


class ChaseTests(unittest.TestCase):
    def test_pure_core(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = pathlib.Path(tmp) / "chase"
            build = subprocess.run(
                ["c++", "-std=c++98", "-x", "c++", "-", "-o", str(exe)],
                input=source(), text=True, capture_output=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(exe)], text=True, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertNotIn("FAIL:", run.stdout)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the harness and verify it fails**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: FAIL, `vcmodchase.cpp` does not exist yet.

- [ ] **Step 3: Create the header**

Create `src/extras/vcmodchase.h`:

```cpp
#ifndef __VCMODCHASE_H__
#define __VCMODCHASE_H__

#include "common.h"

enum eVCModChaseState
{
	VCMOD_CHASE_OFF,
	VCMOD_CHASE_TIER_SELECT,
	VCMOD_CHASE_BRIEFING,
	VCMOD_CHASE_RUNNING
};

enum eVCModChaseEvent
{
	VCMOD_CHASE_EV_ENTER_MARKER,
	VCMOD_CHASE_EV_CONFIRM,
	VCMOD_CHASE_EV_CANCEL,
	VCMOD_CHASE_EV_FINISH
};

enum eVCModChaseUnit
{
	VCMOD_UNIT_NONE,
	VCMOD_UNIT_COP,
	VCMOD_UNIT_SWAT,
	VCMOD_UNIT_VICE,
	VCMOD_UNIT_FBI,
	VCMOD_UNIT_ARMY
};

bool VCModChaseNextState(eVCModChaseState *state, eVCModChaseEvent event);
eVCModChaseUnit VCModChaseUnitForTier(int32 tier);
int16 VCModChaseUnitModel(eVCModChaseUnit unit);
bool VCModChaseTierAllowed(int32 tier, int32 rank);
bool VCModChaseRestoreDue(bool pending, bool inControl, bool playerExists);
bool VCModChaseShouldShowMarker(eVCModChaseState state, bool spotSet);
void VCModChaseUpdate(void);
void VCModChaseReset(void);

#endif
```

- [ ] **Step 4: Create the pure core and an empty update**

Create `src/extras/vcmodchase.cpp`:

```cpp
#include "common.h"

#include "vcmodchase.h"
#include "vcmodpanel.h"
#include "ModelIndices.h"
#include "PlayerPed.h"
#include "Pad.h"
#include "ControllerConfig.h"
#include "Hud.h"
#include "World.h"
#include "SpecialFX.h"
#include "Radar.h"
#include "Timer.h"

#include <stdio.h>

bool
VCModChaseNextState(eVCModChaseState *state, eVCModChaseEvent event)
{
	eVCModChaseState old = *state;

	switch (old) {
	case VCMOD_CHASE_OFF:
		if (event == VCMOD_CHASE_EV_ENTER_MARKER)
			*state = VCMOD_CHASE_TIER_SELECT;
		break;
	case VCMOD_CHASE_TIER_SELECT:
		if (event == VCMOD_CHASE_EV_CONFIRM)
			*state = VCMOD_CHASE_BRIEFING;
		else if (event == VCMOD_CHASE_EV_CANCEL)
			*state = VCMOD_CHASE_OFF;
		break;
	case VCMOD_CHASE_BRIEFING:
		if (event == VCMOD_CHASE_EV_CONFIRM)
			*state = VCMOD_CHASE_RUNNING;
		else if (event == VCMOD_CHASE_EV_CANCEL)
			*state = VCMOD_CHASE_OFF;
		break;
	case VCMOD_CHASE_RUNNING:
		if (event == VCMOD_CHASE_EV_FINISH || event == VCMOD_CHASE_EV_CANCEL)
			*state = VCMOD_CHASE_OFF;
		break;
	}
	return *state != old;
}

eVCModChaseUnit
VCModChaseUnitForTier(int32 tier)
{
	switch (tier) {
	case 1: return VCMOD_UNIT_COP;
	case 2: return VCMOD_UNIT_SWAT;
	case 3: return VCMOD_UNIT_VICE;
	case 4: return VCMOD_UNIT_FBI;
	case 5: return VCMOD_UNIT_ARMY;
	default: return VCMOD_UNIT_NONE;
	}
}

int16
VCModChaseUnitModel(eVCModChaseUnit unit)
{
	switch (unit) {
	case VCMOD_UNIT_COP: return MI_COP;
	case VCMOD_UNIT_SWAT: return MI_SWAT;
	case VCMOD_UNIT_VICE: return MI_VICE1;
	case VCMOD_UNIT_FBI: return MI_FBI;
	case VCMOD_UNIT_ARMY: return MI_ARMY;
	default: return -1;
	}
}

bool
VCModChaseTierAllowed(int32 tier, int32 rank)
{
	return tier >= 1 && tier <= 5 && tier <= rank;
}

bool
VCModChaseRestoreDue(bool pending, bool inControl, bool playerExists)
{
	return pending && inControl && playerExists;
}

bool
VCModChaseShouldShowMarker(eVCModChaseState state, bool spotSet)
{
	return spotSet && state == VCMOD_CHASE_OFF;
}

static eVCModChaseState nVCModChaseState;

void
VCModChaseUpdate(void)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil)
		return;
}

void
VCModChaseReset(void)
{
	nVCModChaseState = VCMOD_CHASE_OFF;
}
```

- [ ] **Step 5: Hook the update into the frame loop**

In `src/core/Game.cpp`, add the include near the other local includes:

```cpp
#include "vcmodchase.h"
```

Then, inside `void CGame::Process(void)`, in the `if (!CTimer::GetIsPaused())` block, after `CWorld::Process()`:

```cpp
		PUSH_MEMID(MEMID_WORLD);
		CWorld::Process();
		POP_MEMID();

		VCModChaseUpdate();

		gAccidentManager.Update();
```

- [ ] **Step 6: Run the harness and verify it passes**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: PASS.

- [ ] **Step 7: Build**

Run: `scripts/build.sh`
Expected: Release build completes with no errors.

- [ ] **Step 8: Commit only these files**

```bash
cd reVC
git add src/extras/vcmodchase.h src/extras/vcmodchase.cpp src/core/Game.cpp utils/test_vc_chase.py
git commit -m "Add chase mission state machine skeleton"
```

Do not stage `src/peds/PlayerPed.cpp`.

---

### Task 2: Station Spot, Pink Marker and Blip

**Files:**
- Modify: `src/extras/vcmodchase.cpp`
- Test: `utils/test_vc_chase.py` (still green), in-game acceptance

**Interfaces:**
- Consumes: `VCModChaseShouldShowMarker`, `VCModChaseNextState`, `VCModChaseUpdate`.
- Produces: the module-local `vecVCModChaseStation`, `bVCModChaseSpotSet`, `nVCModChaseBlip`.

- [ ] **Step 1: Add the module state and constants**

At the top of `src/extras/vcmodchase.cpp`, after the includes:

```cpp
#define VCMOD_CHASE_SPOTKEY		'J'
#define VCMOD_CHASE_MARKER_ID	0x56434348
#define VCMOD_CHASE_ENTER_NEAR	2.0f

// VCPD HQ forecourt
static const CVector vecVCModChaseStationHome = CVector(405.97f, -468.07f, 10.11f);
// Debug spawn in front of the station, J teleports here
static const CVector vecVCModChaseTeleport = CVector(398.57f, -470.29f, 11.75f);
static CVector vecVCModChaseStation = vecVCModChaseStationHome;
static bool bVCModChaseSpotSet = true;
static int32 nVCModChaseBlip = -1;
```

The marker is always present in free roam from the first frame, so no capture step is needed to see it.

- [ ] **Step 2: Add the debug teleport, marker and proximity code**

Extend `VCModChaseUpdate` after the `player == nil` guard:

```cpp
	if (KEYJUSTDOWN(VCMOD_CHASE_SPOTKEY)) {
		if (player->m_pMyVehicle != nil) {
			VCModChaseNotice("chase: leave the vehicle to teleport");
		} else {
			player->Teleport(vecVCModChaseTeleport);
			VCModChaseNotice("chase: teleported to VCPD HQ");
			fprintf(stderr, "VCMOD CHASE teleport %.2f %.2f %.2f\n",
				vecVCModChaseTeleport.x, vecVCModChaseTeleport.y, vecVCModChaseTeleport.z);
		}
	}

	if (VCModChaseShouldShowMarker(nVCModChaseState, bVCModChaseSpotSet)) {
		C3dMarkers::PlaceMarkerSet(VCMOD_CHASE_MARKER_ID, MARKERTYPE_CYLINDER, vecVCModChaseStation,
			2.0f, 255, 105, 180, 180, 1024, 0.25f, 0);
		if (nVCModChaseBlip < 0)
			nVCModChaseBlip = CRadar::SetCoordBlip(BLIP_COORD, vecVCModChaseStation, 0, BLIP_DISPLAY_BOTH);
	} else if (nVCModChaseBlip >= 0) {
		CRadar::ClearBlip(nVCModChaseBlip);
		nVCModChaseBlip = -1;
	}

	if (nVCModChaseState == VCMOD_CHASE_OFF && bVCModChaseSpotSet &&
	    (FindPlayerCoors() - vecVCModChaseStation).Magnitude() < VCMOD_CHASE_ENTER_NEAR) {
		VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_ENTER_MARKER);
	}
```

- [ ] **Step 3: Add the key macro**

Near the includes, after the constants:

```cpp
#define KEYJUSTDOWN(k)	ControlsManager.GetIsKeyboardKeyJustDown((RsKeyCodes)(k))
```

- [ ] **Step 4: Harness**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: PASS.

- [ ] **Step 5: Build**

Run: `scripts/build.sh`
Expected: Release build completes with no errors.

- [ ] **Step 6: In-game check, no launch**

Install with `scripts/install.sh` only if reVC is not running, then hand off for a launch. On the VCPD HQ forecourt:
Expected: a pink cylinder marker and a radar blip are present without any key press.
Walk into it: the marker disappears and the value is no longer `OFF`.
Pressing `J` teleports the player to the debug spawn in front of the station and logs it.

- [ ] **Step 7: Commit**

```bash
cd reVC
git add src/extras/vcmodchase.cpp
git commit -m "Add chase station marker and blip"
```

---

### Task 3: Tier Selection and Uniform Swap

**Files:**
- Modify: `src/extras/vcmodchase.cpp`
- Test: `utils/test_vc_chase.py` (still green), in-game acceptance

**Interfaces:**
- Consumes: `VCModChaseUnitForTier`, `VCModChaseUnitModel`, `VCModChaseTierAllowed`, `VCModChaseRestoreDue`, `VCModApplyPedModel(int16)`, `bVCModPlayerNpcAnims`.
- Produces: module-local `nVCModChaseTier`, `nVCModChaseRank`, `nVCModChasePreModel`, `bVCModChasePreNpcAnims`, `bVCModChaseUniformWanted`, `bVCModChaseRestorePending`.

- [ ] **Step 1: Add the uniform state**

After the marker state in `src/extras/vcmodchase.cpp`:

```cpp
static int32 nVCModChaseTier;
static int32 nVCModChaseRank = 5;	// P0: every tier; P4 reads the ini
static bool bVCModChaseUniformWanted;
static bool bVCModChaseRestorePending;
static int16 nVCModChasePreModel = -1;
static bool bVCModChasePreNpcAnims;
static uint32 nVCModChaseCooldownUntil;
```

- [ ] **Step 2: Add the notice and uniform helpers**

Before `VCModChaseUpdate`:

```cpp
static void
VCModChaseNotice(const char *text)
{
	static wchar notice[96];
	int32 i;
	for (i = 0; i < (int32) ARRAY_SIZE(notice) - 1 && text[i] != '\0'; i++)
		notice[i] = (wchar) text[i];
	notice[i] = 0;
	CHud::SetHelpMessage(notice, false);
}

static const char *
VCModChaseUnitName(eVCModChaseUnit unit)
{
	switch (unit) {
	case VCMOD_UNIT_COP: return "COP";
	case VCMOD_UNIT_SWAT: return "SWAT";
	case VCMOD_UNIT_VICE: return "VICE";
	case VCMOD_UNIT_FBI: return "FBI";
	case VCMOD_UNIT_ARMY: return "ARMY";
	default: return "none";
	}
}

static void
VCModChaseApplyUniform(void)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil || !player->IsPedInControl())
		return;

	if (nVCModChasePreModel < 0) {
		nVCModChasePreModel = player->GetModelIndex();
		bVCModChasePreNpcAnims = bVCModPlayerNpcAnims;
	}
	bVCModPlayerNpcAnims = false;

	int16 model = VCModChaseUnitModel(VCModChaseUnitForTier(nVCModChaseTier));
	if (model >= 0 && VCModApplyPedModel(model))
		bVCModChaseUniformWanted = false;
}

static void
VCModChaseRestoreUniform(void)
{
	if (nVCModChasePreModel >= 0)
		bVCModChaseRestorePending = true;
}

static void
VCModChaseEnd(void)
{
	nVCModChaseTier = 0;
	bVCModChaseUniformWanted = false;
	VCModChaseRestoreUniform();
	nVCModChaseCooldownUntil = CTimer::GetTimeInMilliseconds() + 2000;
}
```

- [ ] **Step 3: Add the restore retry**

At the start of `VCModChaseUpdate`, after the `player == nil` guard:

```cpp
	if (bVCModChaseRestorePending &&
	    VCModChaseRestoreDue(true, player->IsPedInControl(), true)) {
		bVCModPlayerNpcAnims = bVCModChasePreNpcAnims;
		if (VCModApplyPedModel(nVCModChasePreModel)) {
			nVCModChasePreModel = -1;
			bVCModChaseRestorePending = false;
		}
	}
```

- [ ] **Step 4: Add the state input**

Replace the standalone proximity block added in Task 2 with this switch. The full state block after the marker code:

```cpp
	switch (nVCModChaseState) {
	case VCMOD_CHASE_OFF:
		if (!bVCModChaseRestorePending &&
		    CTimer::GetTimeInMilliseconds() > nVCModChaseCooldownUntil &&
		    bVCModChaseSpotSet &&
		    (FindPlayerCoors() - vecVCModChaseStation).Magnitude() < VCMOD_CHASE_ENTER_NEAR) {
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_ENTER_MARKER);
			VCModChaseNotice("chase: 1 COP, 2 SWAT, 3 VICE, 4 FBI, 5 ARMY. ENTER to confirm");
		}
		break;
	case VCMOD_CHASE_TIER_SELECT:
		for (int32 tier = 1; tier <= 5; tier++) {
			if (KEYJUSTDOWN('0' + tier) && VCModChaseTierAllowed(tier, nVCModChaseRank)) {
				char text[96];
				nVCModChaseTier = tier;
				bVCModChaseUniformWanted = true;
				snprintf(text, sizeof(text), "chase: %s selected. ENTER to confirm",
					VCModChaseUnitName(VCModChaseUnitForTier(tier)));
				VCModChaseNotice(text);
			}
		}
		if (bVCModChaseUniformWanted)
			VCModChaseApplyUniform();
		if (KEYJUSTDOWN(rsENTER)) {
			if (nVCModChaseTier == 0) {
				VCModChaseNotice("chase: pick a tier first");
			} else {
				VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_CONFIRM);
				VCModChaseNotice("chase: ENTER to start, BACKSPACE to cancel");
			}
		} else if (KEYJUSTDOWN(rsBACKSP)) {
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_CANCEL);
			VCModChaseEnd();
			VCModChaseNotice("chase: cancelled");
		}
		break;
	case VCMOD_CHASE_BRIEFING:
		if (KEYJUSTDOWN(rsENTER)) {
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_CONFIRM);
			VCModChaseNotice("chase: P0 run active. BACKSPACE to end");
		} else if (KEYJUSTDOWN(rsBACKSP)) {
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_CANCEL);
			VCModChaseEnd();
			VCModChaseNotice("chase: cancelled");
		}
		break;
	case VCMOD_CHASE_RUNNING:
		if (KEYJUSTDOWN(rsBACKSP)) {
			VCModChaseNextState(&nVCModChaseState, VCMOD_CHASE_EV_FINISH);
			VCModChaseEnd();
			VCModChaseNotice("chase: ended");
		}
		break;
	}
```

- [ ] **Step 5: Harness**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: PASS.

- [ ] **Step 6: Build**

Run: `scripts/build.sh`
Expected: Release build completes with no errors.

- [ ] **Step 7: In-game handoff**

At the VCPD HQ marker, walk in, press `1`/`3`/`5`:
Expected: the player model becomes COP/VICE/ARMY, the model's own animation group applies, and the notice names the unit. Press `ENTER` twice, then `BACKSPACE`:
Expected: the state returns to free roam and the original model and animation return.

- [ ] **Step 8: Commit**

```bash
cd reVC
git add src/extras/vcmodchase.cpp
git commit -m "Add chase tier selection and uniform swap"
```

---

### Task 4: End Cleanup and Marker Return

**Files:**
- Modify: `src/extras/vcmodchase.cpp`
- Test: `utils/test_vc_chase.py` (still green), in-game acceptance

**Interfaces:**
- Consumes: everything above.
- Produces: a clean `OFF` state with no mission-owned marker, blip, model or animation.

- [ ] **Step 1: Make the marker and blip follow the state**

The marker block already calls `VCModChaseShouldShowMarker` and clears the blip when false. Confirm that on `END` the blip is cleared and the marker stops being placed, so it disappears at the next render.

- [ ] **Step 2: Reset the module on a new game or load**

Replace the Task 1 stub's `VCModChaseReset` body with:

```cpp
void
VCModChaseReset(void)
{
	nVCModChaseState = VCMOD_CHASE_OFF;
	nVCModChaseTier = 0;
	vecVCModChaseStation = vecVCModChaseStationHome;
	bVCModChaseSpotSet = true;
	bVCModChaseUniformWanted = false;
	bVCModChaseRestorePending = false;
	nVCModChasePreModel = -1;
	if (nVCModChaseBlip >= 0) {
		CRadar::ClearBlip(nVCModChaseBlip);
		nVCModChaseBlip = -1;
	}
	nVCModChaseCooldownUntil = 0;
}
```

`VCModChaseReset` is exposed for P1's load hook. P0 does not call it from a save path.

- [ ] **Step 3: Harness**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: PASS.

- [ ] **Step 4: Build**

Run: `scripts/build.sh`
Expected: Release build completes with no errors.

- [ ] **Step 5: In-game acceptance**

- Enter the forecourt: the marker and blip are already present.
- Walk in: marker goes away, tier help appears.
- Pick `1`: model is COP, animation is COP's.
- Pick `2`: model is SWAT, animation is SWAT's.
- Pick `3`: model is VICE; press `3` again to cycle `MI_VICE1..8` and wrap.
- Pick `4`: model is FBI, animation is FBI's.
- Pick `5`: model is Army, animation is Army's.
- `ENTER`, `ENTER`, `BACKSPACE`: original model and animation return.
- Marker and blip come back after the two-second cooldown.
- No crash, no game data touched, no save loaded or written.

- [ ] **Step 6: Commit**

```bash
cd reVC
git add src/extras/vcmodchase.cpp
git commit -m "Add chase cleanup and marker return"
```

---

### Task 5: Full Build, Harness and Handoff

**Files:** none new.

- [ ] **Step 1: Run the harness**

Run: `cd reVC && python3 utils/test_vc_chase.py -v`
Expected: PASS.

- [ ] **Step 2: Build**

Run: `scripts/build.sh`
Expected: Release build completes.

- [ ] **Step 3: Check the working tree**

Run: `cd reVC && git status --short`
Expected: the only paths from this work are the four P0 files. `src/peds/PlayerPed.cpp` may still be modified by the other agent; it must not be staged.

- [ ] **Step 4: Hand off for launch**

Do not launch the game. Report the build result and ask the user to launch and perform the Task 4 acceptance steps.

- [ ] **Step 5: Report**

Report harness output, build result, and the exact in-game steps. Do not claim in-game success without the user's report; the repo's rule is that a mod fix is verified in-game.

---

## Self-Review

- Spec coverage for P0: mission state machine (Task 1), station marker and blip (Task 2), tier pick and uniform (Task 3), cleanup and no-trace (Task 4), harness and in-game handoff (Task 5). Rank gating and ini persistence are deliberately P4, per the spec.
- The marker is placed every frame because the engine clears `m_bIsUsed` after each render, so stopping the call removes it.
- The station is a pinned coordinate from the spec, not a captured one; `J` stays as a debug override, and `VCModChaseReset` restores the pinned spot so the marker always returns.
- `bIsPlayerFriend` is not touched in P0; it belongs to P1 combat and section 6.10 of the spec.
- `PlayerPed.cpp` is never edited or staged.
- Function names and types above match the interface block and the harness extraction list.
