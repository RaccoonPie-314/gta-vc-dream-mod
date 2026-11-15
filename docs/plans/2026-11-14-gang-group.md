# CALL GANG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One `CALL GANG` WORLD row that spawns one stock-shaped group of the player's own gang while BECOME NPC runs the GANG profile, plus a walk-up join for existing kin circles.

**Architecture:** New feature module `src/extras/vcmodganggroup.cpp/.h` owns the gate, the spawner, the tracking array, the lifecycle unlink and the circle join. The panel row is one registry entry plus a click/render case; `vcmodnpc.cpp` calls the module from the GANG branch, from the mode-off edge and once per mode frame. No engine file is edited. Members are ordinary `CPopulation::AddPed` gang peds (`RANDOM_CHAR`), linked with the stock `SetLeader`/`SetObjective`/`SetFormation` and `SetChat` calls; nothing is saved.

**Tech Stack:** reVC C++98, the project's Python harness pattern (`utils/vcmod_test_support.py`), CMake build, HUD notice helper.

**Spec:** `docs/specs/2026-11-14-gang-group-design.md`

## Global Constraints

- No git actions: no commit, tag, push or branch change. Work stays uncommitted.
- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are read-only game data.
  `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` stay `uchg`; never touch them.
- Install only while `pgrep -f "reVC.app/Contents/MacOS/reVC"` is empty.
- Feature code lives in `src/extras/vcmod<feature>.*`; engine files get no feature blocks.
  This plan touches no engine file at all.
- Portability: no `#ifdef __APPLE__`, no absolute paths, no platform APIs in mod code.
- Naming (docs/architecture.md rule 17): `VCModGangGroup<Thing>`, state prefix on the module
  name (`apVCModGangGroup`, `bVCModGangGroupFormation`), constants `VCMOD_GANG_GROUP_<DETAIL>`.
- Feature-off path is stock: with the row unpressable (mode off / other profile) nothing runs;
  the join only runs inside the GANG branch.
- Logging: feature events unconditional `fprintf(stderr, "VCMOD gang group: ...")`;
  no per-frame probes (`VCMOD_DIAG` would be needed for those, and none are added).
- Existing uncommitted work `src/extras/vcmoddrivecam.{cpp,h}` is not ours: do not edit,
  revert or commit it. It is part of the tree the build compiles.
- The verified stock references: `Population.cpp:350` (`ChooseGangOccupation` →
  `CGangs::ChooseGangPedModel`), `:1363` (size 3–6), `:1429-1436` (1/3 formation roll),
  `:1439-1507` (formation block), `:1510-1623` (circle block), `:420-488` (`AddPed` +
  stock gang weapon), `Ped.cpp:1397-1419` (walker chat roll), `:1421-1445` (`WillChat`),
  `:7856-7935` (`SetChat`/`Chat`), `:2419-2432` (alpha ramp), `PedAI.cpp:610-701`
  (`UpdateFromLeader`), `:1137-1154` (formation objective), `PedAI.cpp:591-607`
  (`ClearLeader` is the shape `Release` mirrors).

## File Structure

| File | Responsibility |
| --- | --- |
| `reVC/src/extras/vcmodganggroup.h` | public surface: cell, alive, call, update, join, release |
| `reVC/src/extras/vcmodganggroup.cpp` | gate, spawner, tracking, lifecycle, join |
| `reVC/src/extras/vcmodpanelinternal.h` | new row kind `VCMOD_ROW_GANGGROUP` |
| `reVC/src/extras/vcmodpanelregistry.cpp` | WORLD row directly after TYPE FROM BODY; debug-menu entry |
| `reVC/src/extras/vcmodpanel.cpp` | render + click case for the new kind |
| `reVC/src/extras/vcmodnpc.cpp` | mode-off release, per-frame update, GANG-branch join call |
| `README.md` | toggles table row |
| `reVC/utils/test_vc_ganggroup.py` | new harness |
| `reVC/utils/test_vc_panel_info.py` | CALL GANG row checks + row count |

---

### Task 1: Module skeleton, pure shape maths, harness

**Files:**
- Create: `reVC/src/extras/vcmodganggroup.h`
- Create: `reVC/src/extras/vcmodganggroup.cpp`
- Test: `reVC/utils/test_vc_ganggroup.py`

**Interfaces:**
- Produces: the header above; internal statics `VCModGangGroupIsFormationRoll(float)`,
  `VCModGangGroupCircleRadius(int32)`, `VCModGangGroupSlotOffset(int32, int32, float, float, float*, float*)`,
  `VCModGangGroupPartnerSlot(int32, int32)`, `VCModGangGroupIsMiddle(int32, int32)`,
  `VCModGangGroupPairTime(bool, uint32)`.
- Consumes: nothing.

- [ ] **Step 1: Write the header**

`vcmodganggroup.h`:

```cpp
#ifndef VCMODGANGGROUP_H
#define VCMODGANGGROUP_H

class CPlayerPed;
class CPad;

// CALL GANG: one press spawns one stock-shaped group of the player's own gang
// while the GANG profile runs — the stock walking formation led by the player,
// or the stock chatting circle with him on the ring. The members are ordinary
// random gang peds: the world culls them, nothing is saved, and a break or the
// mode going off hands the followers back.

// the row's value cell: "[--]" idle, "N men" while a group is out
const char *VCModGangGroupCell(void);
// live members (not dying or dead) the group still has
int32 VCModGangGroupAlive(void);
// the CALL GANG row: gate, spawn one group, or refuse with a notice
void VCModGangGroupCall(void);
// per frame while NPC mode runs: unlink the group on a break or a profile switch
void VCModGangGroupUpdate(CPlayerPed *player, CPad *pad);
// the GANG profile's walk-up: join a stock kin circle on the stock chat gates
void VCModGangTryJoinCircle(CPlayerPed *player);
// the mode hands the ped back: release every follower the group made
void VCModGangGroupRelease(CPlayerPed *player);

#endif
```

- [ ] **Step 2: Write the failing maths tests**

Create `reVC/utils/test_vc_ganggroup.py` with the shape tests. The file grows over tasks 2–3;
start with exactly this:

```python
#!/usr/bin/env python3
"""CALL GANG: the stock group shape, the gate, the tracking hand-back, the
formation link and the kin circle join, extracted from the mod source and
compiled against stubs."""
import unittest
from pathlib import Path
from vcmod_test_support import braced, run_cpp

ROOT = Path(__file__).resolve().parents[1]
GROUP = (ROOT / "src/extras/vcmodganggroup.cpp").read_text()
NPC = (ROOT / "src/extras/vcmodnpc.cpp").read_text()
POP = (ROOT / "src/peds/Population.cpp").read_text()

MATH_STUBS = r'''
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <cmath>
#define nil NULL
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
#define TWOPI (2.0f * 3.14159265358979323846f)
inline float Sqrt(float f) { return std::sqrt(f); }
inline float Cos(float f) { return std::cos(f); }
inline float Sin(float f) { return std::sin(f); }
inline float Abs(float f) { return f < 0.0f ? -f : f; }
#define Max(a, b) ((a) > (b) ? (a) : (b))
#define Min(a, b) ((a) < (b) ? (a) : (b))
#define VCMOD_GANG_GROUP_MAX 6
#define VCMOD_GANG_GROUP_JOIN_RANGE 1.8f
#define VCMOD_GANG_GROUP_JOIN_NEAR 10
#define VCMOD_GANG_GROUP_CHAT_GAP 30000
#define VCMOD_GANG_GROUP_CLUSTER_TIME 100000
enum { PED_NONE, PED_IDLE, PED_WANDER_PATH, PED_CHAT, PED_UNKNOWN };
'''

RADIUS = "static float\nVCModGangGroupCircleRadius"
SLOT = "static void\nVCModGangGroupSlotOffset"
PARTNER = "static int32\nVCModGangGroupPartnerSlot"
MIDDLE = "static bool\nVCModGangGroupIsMiddle"
PAIRTIME = "static uint32\nVCModGangGroupPairTime"
SHAPE = "static bool\nVCModGangGroupIsFormationRoll"


def math_src(*marks):
    return MATH_STUBS + "\n".join(braced(GROUP, m) for m in marks) + "\n"


class GroupShapeTests(unittest.TestCase):
    def test_circle_radius_is_the_stock_formula(self):
        run_cpp(math_src(RADIUS) + r'''
int main(void) {
    // the stock formula gives a one-metre chord between neighbours
    for (int n = 3; n <= 6; ++n) {
        float r = VCModGangGroupCircleRadius(n);
        float chord = 2.0f * r * std::sin(3.14159265f / n);
        if (std::fabs(chord - 1.0f) > 0.001f) return 10 + n;
    }
    if (std::fabs(VCModGangGroupCircleRadius(3) - 0.57735f) > 0.001f) return 1;
    if (std::fabs(VCModGangGroupCircleRadius(4) - 0.70711f) > 0.001f) return 2;
    if (std::fabs(VCModGangGroupCircleRadius(6) - 1.0f) > 0.001f) return 3;
    return 0;
}
''')

    def test_slot_zero_is_the_players_own_spot(self):
        run_cpp(math_src(RADIUS, SLOT) + r'''
int main(void) {
    for (int n = 3; n <= 6; ++n) {
        float fwd, side;
        VCModGangGroupSlotOffset(0, n, 0.0f, 0.0f, &fwd, &side);
        // slot 0 is exactly where the player stands: radius behind the ring centre
        if (std::fabs(fwd + VCModGangGroupCircleRadius(n)) > 0.001f) return 10 + n;
        if (std::fabs(side) > 0.001f) return 20 + n;
        float fwd1, side1;
        VCModGangGroupSlotOffset(1, n, 0.0f, 0.0f, &fwd1, &side1);
        float r = std::sqrt(fwd1 * fwd1 + side1 * side1);
        if (std::fabs(r - VCModGangGroupCircleRadius(n)) > 0.001f) return 30 + n;
        // slot 1 and slot 2 are neighbours on the ring: the stock one-metre chord
        float fwd2, side2;
        VCModGangGroupSlotOffset(2, n, 0.0f, 0.0f, &fwd2, &side2);
        float dx = fwd1 - fwd2, dy = side1 - side2;
        if (std::fabs(std::sqrt(dx * dx + dy * dy) - 1.0f) > 0.001f) return 40 + n;
        // the jitter stays inside the stock +/-20% ring and +/-0.2 sector
        float jf, js;
        VCModGangGroupSlotOffset(1, n, 0.19f, 0.19f, &jf, &js);
        if (std::sqrt(jf * jf + js * js) > VCModGangGroupCircleRadius(n) * 1.21f) return 50 + n;
    }
    return 0;
}
''')

    def test_pairing_and_the_middle(self):
        run_cpp(math_src(PARTNER, MIDDLE) + r'''
int main(void) {
    for (int n = 3; n <= 6; ++n) {
        // the player is slot 0 and pairs with the last placed member
        if (VCModGangGroupPartnerSlot(0, n) != n - 1) return 10 + n;
        for (int slot = 0; slot < n; ++slot)
            if (VCModGangGroupPartnerSlot(VCModGangGroupPartnerSlot(slot, n), n) != slot) return 20 + n;
        // only an odd ring has the unpaired middle
        if (VCModGangGroupIsMiddle((n - 1) / 2, n) != (n % 2 != 0)) return 30 + n;
    }
    if (!VCModGangGroupIsMiddle(2, 5)) return 1;
    if (VCModGangGroupIsMiddle(1, 4)) return 2;
    return 0;
}
''')

    def test_pair_times(self):
        run_cpp(math_src(PAIRTIME) + r'''
int main(void) {
    // the player's pair is the stock pedestrian meet, the NPC pairs the cluster timer
    if (VCModGangGroupPairTime(true, 0) != 10000) return 1;
    if (VCModGangGroupPairTime(true, 3999) != 13999) return 2;
    if (VCModGangGroupPairTime(true, 4000) != 10000) return 3;
    if (VCModGangGroupPairTime(true, 12345) != 10345) return 4;
    if (VCModGangGroupPairTime(false, 0) != 100000) return 5;
    if (VCModGangGroupPairTime(false, 3999) != 100000) return 6;
    return 0;
}
''')

    def test_shape_roll_and_stock_size(self):
        source = MATH_STUBS + r'''
struct CGeneral {
    static int minSeen, maxSeen;
    static int GetRandomNumberInRange(int a, int b) { minSeen = a; maxSeen = b; return a; }
};
int CGeneral::minSeen = 0;
int CGeneral::maxSeen = 0;
''' + braced(POP, "int32\nCPopulation::ComputeRandomisedGangSize") + braced(GROUP, SHAPE) + r'''
int main(void) {
    // the size is CPopulation's own roll: 3-6, counting the player
    int size = CPopulation::ComputeRandomisedGangSize();
    if (size != 3) return 1;
    if (CGeneral::minSeen != 3 || CGeneral::maxSeen != 6) return 2;
    // the stock split: a third becomes a formation, the rest a circle
    if (!VCModGangGroupIsFormationRoll(0.0f)) return 3;
    if (!VCModGangGroupIsFormationRoll(0.332f)) return 4;
    if (VCModGangGroupIsFormationRoll(0.333f)) return 5;
    if (VCModGangGroupIsFormationRoll(0.5f)) return 6;
    if (VCModGangGroupIsFormationRoll(1.0f)) return 7;
    return 0;
}
'''
        run_cpp(source)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the harness to verify it fails**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: FAIL/ERROR because `src/extras/vcmodganggroup.cpp` does not exist (`FileNotFoundError`).

- [ ] **Step 4: Write the module skeleton with the maths helpers**

`vcmodganggroup.cpp` (the spawner, gate, tracking and join arrive in tasks 2–4; write the
constants and helpers now, in this order — the harness markers rely on the return-type
prefixes being unique):

```cpp
#include "common.h"

#include <stdio.h>

#include "vcmodganggroup.h"
#include "vcmodgang.h"
#include "vcmodnpc.h"
#include "vcmodhud.h"

#include "Gangs.h"
#include "General.h"
#include "ModelInfo.h"
#include "Pad.h"
#include "Ped.h"
#include "PedPlacement.h"
#include "PedType.h"
#include "PlayerPed.h"
#include "Population.h"
#include "Streaming.h"
#include "Timer.h"
#include "VisibilityPlugins.h"
#include "World.h"

#define VCMOD_GANG_GROUP_MAX		6
#define VCMOD_GANG_GROUP_JOIN_RANGE	1.8f
#define VCMOD_GANG_GROUP_JOIN_NEAR	10
#define VCMOD_GANG_GROUP_CHAT_GAP	30000
#define VCMOD_GANG_GROUP_CLUSTER_TIME	100000

// the acceptance gates, one bit each so the refusal can name the first one
enum eVCModGangGroupRefusal
{
	VCMOD_GANG_GROUP_OK = 0,
	VCMOD_GANG_GROUP_NEED_GANG = 1 << 0,
	VCMOD_GANG_GROUP_IN_CAR = 1 << 1,
	VCMOD_GANG_GROUP_NOT_NOW = 1 << 2,
	VCMOD_GANG_GROUP_ALREADY = 1 << 3
};

// one near ped, reduced to the fields the circle join decides on
struct VCModGangJoinPed
{
	CPed *ped;
	int32 gang;
	bool willChat;
	int32 state;
	bool lookIsPed;
	int32 lookState;
	int32 lookGang;
	float dist;
};

static CPed *apVCModGangGroup[VCMOD_GANG_GROUP_MAX];
static bool bVCModGangGroupFormation;

// the stock split (Population.cpp:1431): a third of world groups form a walking
// column, the rest stand and chat
static bool
VCModGangGroupIsFormationRoll(float roll)
{
	return roll < 0.333f;
}

// the stock ring radius for a conversation of this many people
static float
VCModGangGroupCircleRadius(int32 members)
{
	float sector = TWOPI / members;
	return Sqrt(0.5f / (1.0f - Cos(sector)));
}

// slot 0 is the player's own spot and never moves; the rest take the stock
// sector angles with the stock per-slot jitter, in the player's own frame
static void
VCModGangGroupSlotOffset(int32 slot, int32 members, float jitterAngle, float jitterRadius,
	float *outForward, float *outSide)
{
	float radius = VCModGangGroupCircleRadius(members);
	if (slot == 0) {
		*outForward = -radius;
		*outSide = 0.0f;
		return;
	}
	float sector = TWOPI / members;
	float theta = (slot + jitterAngle) * sector;
	float r = radius * (1.0f + jitterRadius);
	*outForward = -Cos(theta) * r;
	*outSide = Sin(theta) * r;
}

// the stock pairing walks the ring from both ends
static int32
VCModGangGroupPartnerSlot(int32 slot, int32 members)
{
	return members - 1 - slot;
}

// an odd ring leaves one person unpaired; the stock middle stands locked
static bool
VCModGangGroupIsMiddle(int32 slot, int32 members)
{
	return (members & 1) != 0 && slot == (members - 1) / 2;
}

// the player's pair uses the stock pedestrian meet length, so he is not locked
// for the cluster's long timer; every NPC pair keeps the cluster timer
static uint32
VCModGangGroupPairTime(bool playerPair, uint32 roll)
{
	if (playerPair)
		return roll % 4000 + 10000;
	return VCMOD_GANG_GROUP_CLUSTER_TIME;
}
```

- [ ] **Step 5: Run the harness to verify it passes**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: `OK` (5 tests).

---

### Task 2: Tracking, gate, cell

**Files:**
- Modify: `reVC/src/extras/vcmodganggroup.cpp`
- Test: `reVC/utils/test_vc_ganggroup.py`

**Interfaces:**
- Produces: `VCModGangGroupAlive(void)`, `VCModGangGroupCell(void)`,
  `static uint32 VCModGangGroupRefusal(CPlayerPed*)`, `static void VCModGangGroupRefuse(const char*)`,
  `static void VCModGangGroupDropRefs(void)`, `static bool VCModGangGroupTracked(void)`,
  `static int32 VCModGangGroupGang(CPlayerPed*)`.

- [ ] **Step 1: Add the failing gate/tracking tests**

Append to `test_vc_ganggroup.py` (before `if __name__`):

```python
GATE_STUBS = r'''
#include <cstdio>
#include <cstdint>
#include <cstring>
#define nil NULL
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
#define VCMOD_GANG_GROUP_MAX 6
enum { VCMOD_NPC_GANG, VCMOD_NPC_CIVILIAN, VCMOD_NPC_COP };
bool bVCModNpcMode = false;
int32 nVCModNpcType = VCMOD_NPC_GANG;
// the module's own gate expression; the effective-type chain behind it is
// covered by test_vc_gangfaction.py
bool VCModNpcGangActive(void) { return bVCModNpcMode && nVCModNpcType == VCMOD_NPC_GANG; }
struct CVector { float x, y, z; };
struct CEntity { void CleanUpOldReference(CEntity**) {} void RegisterReference(CEntity**) {} };
struct CPed : CEntity {
    bool inCar, dead, inControl;
    CPed() : inCar(false), dead(false), inControl(true) {}
    bool DyingOrDead(void) { return dead; }
    bool IsPedInControl(void) { return inControl; }
};
typedef CPed CPlayerPed;
static CPed *apVCModGangGroup[VCMOD_GANG_GROUP_MAX];
'''

ALIVE = "int32\nVCModGangGroupAlive"
CELL = "const char *\nVCModGangGroupCell"
REFUSAL = "static uint32\nVCModGangGroupRefusal"


def gate_src(*marks):
    return (GATE_STUBS + braced(GROUP, "enum eVCModGangGroupRefusal") + "\n"
            + "\n".join(braced(GROUP, m) for m in marks) + "\n")


class GateTests(unittest.TestCase):
    def test_gate_truth_table(self):
        run_cpp(gate_src(ALIVE, REFUSAL) + r'''
int main(void) {
    CPlayerPed tommy;
    bVCModNpcMode = false;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_NEED_GANG) return 1;
    bVCModNpcMode = true; nVCModNpcType = VCMOD_NPC_CIVILIAN;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_NEED_GANG) return 2;
    nVCModNpcType = VCMOD_NPC_COP;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_NEED_GANG) return 3;
    nVCModNpcType = VCMOD_NPC_GANG;
    tommy.inCar = true;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_IN_CAR) return 4;
    tommy.inCar = false; tommy.dead = true;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_NOT_NOW) return 5;
    tommy.dead = false; tommy.inControl = false;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_NOT_NOW) return 6;
    tommy.inControl = true;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_OK) return 7;
    CPed live;
    apVCModGangGroup[0] = &live;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_ALREADY) return 8;
    // corpses are not a group: the press may proceed
    live.dead = true;
    if (VCModGangGroupRefusal(&tommy) != VCMOD_GANG_GROUP_OK) return 9;
    apVCModGangGroup[0] = nil;
    return 0;
}
''')

    def test_the_row_cell_counts_live_members(self):
        run_cpp(gate_src(ALIVE, CELL) + r'''
int main(void) {
    CPed a, b;
    if (std::strcmp(VCModGangGroupCell(), "[--]") != 0) return 1;
    apVCModGangGroup[0] = &a;
    if (std::strcmp(VCModGangGroupCell(), "1 men") != 0) return 2;
    apVCModGangGroup[2] = &b;
    if (std::strcmp(VCModGangGroupCell(), "2 men") != 0) return 3;
    b.dead = true;
    if (std::strcmp(VCModGangGroupCell(), "1 men") != 0) return 4;
    return 0;
}
''')
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: FAIL — `ValueError: substring not found` for the `VCModGangGroupAlive` marker.

- [ ] **Step 3: Implement tracking, gate and cell**

Append to `vcmodganggroup.cpp`, in this order (before the helpers is fine, but the public
`Alive`/`Cell` must appear before `Refusal`):

```cpp
int32
VCModGangGroupAlive(void)
{
	int32 alive = 0;
	for (int32 i = 0; i < VCMOD_GANG_GROUP_MAX; i++)
		if (apVCModGangGroup[i] != nil && !apVCModGangGroup[i]->DyingOrDead())
			alive++;
	return alive;
}

const char *
VCModGangGroupCell(void)
{
	static char cell[16];
	int32 alive = VCModGangGroupAlive();
	if (alive == 0)
		return "[--]";
	snprintf(cell, sizeof(cell), "%d men", alive);
	return cell;
}

static bool
VCModGangGroupTracked(void)
{
	for (int32 i = 0; i < VCMOD_GANG_GROUP_MAX; i++)
		if (apVCModGangGroup[i] != nil)
			return true;
	return false;
}

// the tracking refs go: a press that finds only corpses drops them and spawns
// fresh, and the release does the same
static void
VCModGangGroupDropRefs(void)
{
	for (int32 i = 0; i < VCMOD_GANG_GROUP_MAX; i++) {
		if (apVCModGangGroup[i] == nil)
			continue;
		apVCModGangGroup[i]->CleanUpOldReference((CEntity **)&apVCModGangGroup[i]);
		apVCModGangGroup[i] = nil;
	}
	bVCModGangGroupFormation = false;
}

static uint32
VCModGangGroupRefusal(CPlayerPed *player)
{
	if (!bVCModNpcMode || !VCModNpcGangActive())
		return VCMOD_GANG_GROUP_NEED_GANG;
	if (player->bInVehicle)
		return VCMOD_GANG_GROUP_IN_CAR;
	if (player->DyingOrDead() || !player->IsPedInControl())
		return VCMOD_GANG_GROUP_NOT_NOW;
	if (VCModGangGroupAlive() > 0)
		return VCMOD_GANG_GROUP_ALREADY;
	return VCMOD_GANG_GROUP_OK;
}

static void
VCModGangGroupRefuse(const char *text)
{
	VCModHudNotice(text);
	fprintf(stderr, "VCMOD gang group: %s\n", text);
}

// GANG1..GANG9 to the CGangs shelf index; the manual GANG is GANG7 and TYPE FROM
// BODY gives the worn body's own gang
static int32
VCModGangGroupGang(CPlayerPed *player)
{
	return VCModNpcGangType(player) - PEDTYPE_GANG1;
}
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: `OK` (7 tests).

---

### Task 3: Gang derivation, formation link, join selection and action

**Files:**
- Modify: `reVC/src/extras/vcmodganggroup.cpp`
- Test: `reVC/utils/test_vc_ganggroup.py`

**Interfaces:**
- Produces: `static void VCModGangGroupSetUpFollower(CPed*, CPlayerPed*, int32)`,
  `static void VCModGangGroupLinkFormation(CPed**, int32, CPlayerPed*)`,
  `static int32 VCModGangJoinKind(const VCModGangJoinPed*, int32)`,
  `static int32 VCModGangGroupPickJoin(const VCModGangJoinPed*, int32, int32)`,
  `static void VCModGangGroupJoin(CPlayerPed*, CPed*, uint32, uint32)`,
  `static int32 VCModGangGroupGangIndex(CPlayerPed*)` — wait, name it `VCModGangGroupGang` (task 2).
- Consumes: task 1/2 helpers, `VCModNpcGangType`.

- [ ] **Step 1: Add the failing tests**

Append to `test_vc_ganggroup.py`:

```python
GANG_STUBS = r'''
#include <cstdio>
#include <cstdint>
#include <cmath>
#define nil NULL
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
enum { PEDTYPE_PLAYER1, PEDTYPE_CIVMALE, PEDTYPE_CIVFEMALE, PEDTYPE_COP,
       PEDTYPE_GANG1, PEDTYPE_GANG2, PEDTYPE_GANG3, PEDTYPE_GANG4, PEDTYPE_GANG5,
       PEDTYPE_GANG6, PEDTYPE_GANG7, PEDTYPE_GANG8, PEDTYPE_GANG9, NUM_PEDTYPES };
enum { MI_PLAYER, MI_CUBAN, MI_GANG2, MI_GANG3, MI_GANG4, MI_GANG5, MI_GANG6, MI_MALE01, MI_COUNT };
enum { MITYPE_OTHER = 0, MITYPE_PED = 3 };
struct CBaseModelInfo { int m_type; int GetModelType(void) { return m_type; } };
struct CPedModelInfo : CBaseModelInfo { int m_pedType, m_pedStatType; };
static CPedModelInfo aModels[MI_COUNT];
struct CModelInfo {
    static CBaseModelInfo *GetModelInfo(int id) { return id >= 0 && id < MI_COUNT ? (CBaseModelInfo*)&aModels[id] : nil; }
};
bool bVCModNpcAutoType = false;
struct CPed { int m_modelIndex; CPed() : m_modelIndex(MI_MALE01) {} int GetModelIndex(void) { return m_modelIndex; } };
typedef CPed CPlayerPed;
static void SetUpModels(void) {
    aModels[MI_PLAYER].m_type = MITYPE_PED; aModels[MI_PLAYER].m_pedType = PEDTYPE_PLAYER1;
    aModels[MI_CUBAN].m_type = MITYPE_PED; aModels[MI_CUBAN].m_pedType = PEDTYPE_GANG1;
    aModels[MI_GANG2].m_type = MITYPE_PED; aModels[MI_GANG2].m_pedType = PEDTYPE_GANG2;
    aModels[MI_GANG3].m_type = MITYPE_PED; aModels[MI_GANG3].m_pedType = PEDTYPE_GANG3;
    aModels[MI_GANG4].m_type = MITYPE_PED; aModels[MI_GANG4].m_pedType = PEDTYPE_GANG4;
    aModels[MI_GANG5].m_type = MITYPE_PED; aModels[MI_GANG5].m_pedType = PEDTYPE_GANG5;
    aModels[MI_GANG6].m_type = MITYPE_PED; aModels[MI_GANG6].m_pedType = PEDTYPE_GANG6;
    aModels[MI_MALE01].m_type = MITYPE_PED; aModels[MI_MALE01].m_pedType = PEDTYPE_CIVMALE;
}
'''

GANGTYPE = "int32\nVCModNpcGangType"
GANGINDEX = "static int32\nVCModGangGroupGang(CPlayerPed *player)"


def gang_src():
    return (GANG_STUBS + braced(NPC, GANGTYPE) + "\n" + braced(GROUP, GANGINDEX) + "\n")


class GangDerivationTests(unittest.TestCase):
    def test_the_manual_gang_is_gang7_any_skin(self):
        run_cpp(gang_src() + r'''
int main(void) {
    SetUpModels();
    CPlayerPed tommy; tommy.m_modelIndex = MI_CUBAN;
    bVCModNpcAutoType = false;
    if (VCModGangGroupGang(&tommy) != 6) return 1;   // GANG_PLAYER shelf index
    return 0;
}
''')

    def test_the_worn_body_picks_its_own_gang(self):
        run_cpp(gang_src() + r'''
int main(void) {
    SetUpModels();
    CPlayerPed tommy;
    bVCModNpcAutoType = true;
    int models[6] = { MI_CUBAN, MI_GANG2, MI_GANG3, MI_GANG4, MI_GANG5, MI_GANG6 };
    for (int i = 0; i < 6; ++i) {
        tommy.m_modelIndex = models[i];
        if (VCModGangGroupGang(&tommy) != i) return 10 + i;
    }
    tommy.m_modelIndex = MI_PLAYER;
    if (VCModGangGroupGang(&tommy) != 6) return 20;   // Tommy walks as Vercetti
    tommy.m_modelIndex = MI_MALE01;
    if (VCModGangGroupGang(&tommy) != 6) return 21;   // every other body too
    return 0;
}
''')
```

Formation-link test stubs:

```python
FOLLOW_STUBS = r'''
#include <cstdio>
#include <cstdint>
#define nil NULL
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
enum { OBJECTIVE_NONE, OBJECTIVE_FOLLOW_CHAR_IN_FORMATION };
enum eFormation { FORMATION_UNDEFINED, FORMATION_REAR, FORMATION_REAR_LEFT, FORMATION_REAR_RIGHT,
                  FORMATION_FRONT_LEFT, FORMATION_FRONT_RIGHT, FORMATION_LEFT, FORMATION_RIGHT, FORMATION_FRONT };
struct CEntity {};
struct CPed : CEntity {
    CEntity *leader;
    int objective;
    int formation;
    bool bIsLeader;
    CPed() : leader(nil), objective(OBJECTIVE_NONE), formation(FORMATION_UNDEFINED), bIsLeader(false) {}
    void SetLeader(CEntity *who) {
        leader = who;
        // the engine's own side effect (Ped.cpp:9867)
        if (who)
            ((CPed*)who)->bIsLeader = true;
    }
    void SetObjective(int obj, CEntity*) { objective = obj; }
    void SetFormation(eFormation type) { formation = type; }
};
typedef CPed CPlayerPed;
'''

SETUP_FOLLOWER = "static void\nVCModGangGroupSetUpFollower"
LINK_FORMATION = "static void\nVCModGangGroupLinkFormation"


def follower_src():
    return (FOLLOW_STUBS + braced(GROUP, SETUP_FOLLOWER) + "\n" + braced(GROUP, LINK_FORMATION) + "\n")


class FormationLinkTests(unittest.TestCase):
    def test_each_follower_gets_the_stock_slot(self):
        run_cpp(follower_src() + r'''
int main(void) {
    CPlayerPed tommy;
    CPed a, b;
    VCModGangGroupSetUpFollower(&a, &tommy, 1);
    VCModGangGroupSetUpFollower(&b, &tommy, 2);
    if (a.objective != OBJECTIVE_FOLLOW_CHAR_IN_FORMATION) return 1;
    if (b.objective != OBJECTIVE_FOLLOW_CHAR_IN_FORMATION) return 2;
    if (a.formation != FORMATION_REAR) return 3;
    if (b.formation != FORMATION_REAR_LEFT) return 4;
    return 0;
}
''')

    def test_the_player_is_linked_but_left_not_a_leader(self):
        run_cpp(follower_src() + r'''
int main(void) {
    CPlayerPed tommy;
    CPed members[2];
    CPed *list[2] = { &members[0], &members[1] };
    VCModGangGroupLinkFormation(list, 2, &tommy);
    if (members[0].leader != &tommy || members[1].leader != &tommy) return 1;
    // SetLeader marked him; the group is led by his wander, so the flag is residue
    if (tommy.bIsLeader) return 2;
    return 0;
}
''')
```

Join-selection stubs (pure):

```python
JOIN_STUBS = r'''
#include <cstdio>
#include <cstdint>
#define nil NULL
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
enum { PED_NONE, PED_IDLE, PED_WANDER_PATH, PED_CHAT, PED_UNKNOWN };
enum { PEDTYPE_GANG1 = 1, PEDTYPE_CIVMALE = 4 };
struct CPed {};
'''

JOIN_STRUCT = "struct VCModGangJoinPed"
JOIN_KIND = "static int32\nVCModGangJoinKind"
JOIN_PICK = "static int32\nVCModGangGroupPickJoin"


def join_src():
    return (JOIN_STUBS + braced(GROUP, JOIN_STRUCT) + "\n"
            + braced(GROUP, JOIN_KIND) + "\n" + braced(GROUP, JOIN_PICK) + "\n")


class JoinSelectionTests(unittest.TestCase):
    def test_the_middle_beats_a_nearer_pair(self):
        run_cpp(join_src() + r'''
static VCModGangJoinPed Pair(float dist) {
    VCModGangJoinPed p;
    p.ped = nil; p.gang = PEDTYPE_GANG1; p.willChat = true; p.state = PED_CHAT;
    p.lookIsPed = true; p.lookState = PED_CHAT; p.lookGang = PEDTYPE_GANG1; p.dist = dist;
    return p;
}
static VCModGangJoinPed Middle(float dist) {
    VCModGangJoinPed p;
    p.ped = nil; p.gang = PEDTYPE_GANG1; p.willChat = true; p.state = PED_UNKNOWN;
    p.lookIsPed = false; p.lookState = PED_NONE; p.lookGang = -1; p.dist = dist;
    return p;
}
int main(void) {
    VCModGangJoinPed peds[3];
    peds[0] = Pair(0.5f);
    peds[1] = Middle(1.7f);
    peds[2] = Pair(0.9f);
    if (VCModGangJoinKind(&peds[0], PEDTYPE_GANG1) != 1) return 1;
    if (VCModGangJoinKind(&peds[1], PEDTYPE_GANG1) != 2) return 2;
    if (VCModGangGroupPickJoin(peds, 3, PEDTYPE_GANG1) != 1) return 3;  // middle first
    if (VCModGangGroupPickJoin(peds, 2, PEDTYPE_GANG1) != 0) return 4;  // nearest pair
    if (VCModGangGroupPickJoin(peds, 1, PEDTYPE_GANG1) != 0) return 5;
    return 0;
}
''')

    def test_rivals_and_civilians_never_match(self):
        run_cpp(join_src() + r'''
static VCModGangJoinPed Pair(int gang) {
    VCModGangJoinPed p;
    p.ped = nil; p.gang = gang; p.willChat = true; p.state = PED_CHAT;
    p.lookIsPed = true; p.lookState = PED_CHAT; p.lookGang = gang; p.dist = 0.5f;
    return p;
}
static VCModGangJoinPed Middle(int gang) {
    VCModGangJoinPed p;
    p.ped = nil; p.gang = gang; p.willChat = true; p.state = PED_UNKNOWN;
    p.lookIsPed = false; p.lookState = PED_NONE; p.lookGang = -1; p.dist = 0.5f;
    return p;
}
int main(void) {
    VCModGangJoinPed rival = Pair(2);          // another gang
    VCModGangJoinPed civilian = Pair(PEDTYPE_CIVMALE);
    VCModGangJoinPed rivalMiddle = Middle(2);
    if (VCModGangJoinKind(&rival, PEDTYPE_GANG1) != 0) return 1;
    if (VCModGangJoinKind(&civilian, PEDTYPE_GANG1) != 0) return 2;
    if (VCModGangJoinKind(&rivalMiddle, PEDTYPE_GANG1) != 0) return 3;
    // a kin ped that refuses the chat (surface or crossing) never matches
    VCModGangJoinPed mute = Pair(PEDTYPE_GANG1);
    mute.willChat = false;
    if (VCModGangJoinKind(&mute, PEDTYPE_GANG1) != 0) return 4;
    // a pair whose partner is not in the chat is no pair
    VCModGangJoinPed broken = Pair(PEDTYPE_GANG1);
    broken.lookState = PED_WANDER_PATH;
    if (VCModGangJoinKind(&broken, PEDTYPE_GANG1) != 0) return 5;
    // a middle that is looking at a ped is not the unpaired middle
    VCModGangJoinPed watching = Middle(PEDTYPE_GANG1);
    watching.lookIsPed = true;
    if (VCModGangJoinKind(&watching, PEDTYPE_GANG1) != 0) return 6;
    return 0;
}
''')
```

Join-action stubs:

```python
JOIN_ACTION_STUBS = r'''
#include <cstdio>
#include <cstdint>
#define nil NULL
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
enum { PED_NONE, PED_IDLE, PED_CHAT, PED_UNKNOWN };
#define VCMOD_GANG_GROUP_CHAT_GAP 30000
struct CEntity {
    bool isPed;
    CEntity() : isPed(true) {}
    bool IsPed(void) { return isPed; }
};
struct CPed : CEntity {
    int m_nPedState;
    CEntity *m_pLookTarget;
    uint32 m_chatTimer;
    CPed *chatWith;
    uint32 chatTime;
    int cleared;
    CPed() : m_nPedState(PED_NONE), m_pLookTarget(nil), m_chatTimer(0),
             chatWith(nil), chatTime(0), cleared(0) {}
    void SetChat(CPed *other, uint32 time) { chatWith = other; chatTime = time; m_nPedState = PED_CHAT; }
    void ClearChat(void) { cleared++; m_nPedState = PED_IDLE; m_pLookTarget = nil; }
};
typedef CPed CPlayerPed;
'''

JOIN = "static void\nVCModGangGroupJoin"


def join_action_src():
    return JOIN_ACTION_STUBS + braced(GROUP, JOIN) + "\n"


class JoinActionTests(unittest.TestCase):
    def test_taking_a_pair_member_ends_the_old_pair(self):
        run_cpp(join_action_src() + r'''
int main(void) {
    CPlayerPed tommy;
    CPed member, partner;
    member.m_nPedState = PED_CHAT;
    member.m_pLookTarget = &partner;
    partner.m_nPedState = PED_CHAT;
    VCModGangGroupJoin(&tommy, &member, 12000, 5000);
    if (partner.cleared != 1) return 1;
    if (partner.m_chatTimer != 5000 + 30000) return 2;
    if (member.chatWith != &tommy || member.chatTime != 12000) return 3;
    if (tommy.chatWith != &member || tommy.chatTime != 12000) return 4;
    return 0;
}
''')

    def test_the_middle_joins_without_displacing_anyone(self):
        run_cpp(join_action_src() + r'''
int main(void) {
    CPlayerPed tommy;
    CPed middle;
    middle.m_nPedState = PED_UNKNOWN;
    VCModGangGroupJoin(&tommy, &middle, 10000, 5000);
    if (middle.cleared != 0) return 1;
    if (middle.chatWith != &tommy) return 2;
    if (tommy.chatWith != &middle) return 3;
    if (middle.chatTime != 10000 || tommy.chatTime != 10000) return 4;
    return 0;
}
''')
```

Also append the source-shape checks:

```python
class SourceShapeTests(unittest.TestCase):
    def test_the_player_is_never_moved(self):
        self.assertNotIn("player->SetPosition", GROUP)
        self.assertNotIn("FindPlayerPed()->SetPosition", GROUP)

    def test_the_spawn_is_the_stock_one(self):
        self.assertIn("CPopulation::ComputeRandomisedGangSize()", GROUP)
        self.assertIn("CPopulation::AddPed(", GROUP)
        self.assertIn("CPopulation::RemovePed(", GROUP)
        self.assertIn("CVisibilityPlugins::SetClumpAlpha(", GROUP)
        self.assertIn("CGangs::ChooseGangPedModel(", GROUP)
        # ordinary random gang peds: no mission ownership and no hotkey
        self.assertNotIn("MISSION_CHAR", GROUP)
        self.assertNotIn("bIsPlayerFriend", GROUP)

    def test_the_refusals_are_not_silent(self):
        for text in ("gang: become a gang first", "gang: get out first",
                     "gang: the models cannot be loaded", "gang: no room here",
                     "gang: already here", "gang: not now", "your gang is here"):
            self.assertIn('"' + text + '"', GROUP)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: FAIL — the new markers are not in the module yet.

- [ ] **Step 3: Implement the tested functions**

Append to `vcmodganggroup.cpp`:

```cpp
// one formation member's stock setup, with the player in the leader slot
static void
VCModGangGroupSetUpFollower(CPed *member, CPlayerPed *player, int32 slot)
{
	member->SetObjective(OBJECTIVE_FOLLOW_CHAR_IN_FORMATION, player);
	member->SetFormation((eFormation)slot);
}

// the stock link, made after every member is placed. SetLeader marks the player
// bIsLeader; that flag is the spawner's residue for a ped leader, the group here
// is led by his wander, and nothing reads it — clear it so no engine path sees
// the player as a formation leader
static void
VCModGangGroupLinkFormation(CPed **members, int32 count, CPlayerPed *player)
{
	for (int32 i = 0; i < count; i++)
		members[i]->SetLeader(player);
	player->bIsLeader = false;
}

// 0 not a candidate, 1 a member of a kin pair, 2 the stock unpaired middle
static int32
VCModGangJoinKind(const VCModGangJoinPed *ped, int32 playerGang)
{
	if (ped->gang != playerGang || !ped->willChat)
		return 0;
	if (ped->state == PED_UNKNOWN)
		return ped->lookIsPed ? 0 : 2;
	if (ped->state != PED_CHAT)
		return 0;
	if (!ped->lookIsPed || ped->lookState != PED_CHAT || ped->lookGang != playerGang)
		return 0;
	return 1;
}

// the middle first, otherwise the nearest pair member
static int32
VCModGangGroupPickJoin(const VCModGangJoinPed *peds, int32 count, int32 playerGang)
{
	int32 middle = -1;
	int32 pair = -1;
	for (int32 i = 0; i < count; i++) {
		int32 kind = VCModGangJoinKind(&peds[i], playerGang);
		if (kind == 2 && (middle < 0 || peds[i].dist < peds[middle].dist))
			middle = i;
		else if (kind == 1 && (pair < 0 || peds[i].dist < peds[pair].dist))
			pair = i;
	}
	return middle >= 0 ? middle : pair;
}

// taking a pair member ends that pair on the stock end-of-chat gap; the rest of
// the circle keeps chatting
static void
VCModGangGroupJoin(CPlayerPed *player, CPed *target, uint32 time, uint32 now)
{
	if (target->m_nPedState == PED_CHAT && target->m_pLookTarget != nil
		&& target->m_pLookTarget->IsPed() && target->m_pLookTarget != player) {
		CPed *old = (CPed *)target->m_pLookTarget;
		old->ClearChat();
		old->m_chatTimer = now + VCMOD_GANG_GROUP_CHAT_GAP;
	}
	player->SetChat(target, time);
	target->SetChat(player, time);
}
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: `OK` (16 tests).

---

### Task 4: Spawner, pairing, call path, lifecycle and join scan

**Files:**
- Modify: `reVC/src/extras/vcmodganggroup.cpp`
- Test: `reVC/utils/test_vc_ganggroup.py`

**Interfaces:**
- Produces: `static int32 VCModGangGroupPlaceFormation(CPlayerPed*, int32, int32, CPed**)`,
  `static int32 VCModGangGroupPlaceCircle(CPlayerPed*, int32, int32, CPed**)`,
  `static void VCModGangGroupPairCircle(CPlayerPed*, CPed**, int32)`,
  `static void VCModGangGroupTrack(CPed**, int32, bool)`,
  `void VCModGangGroupCall(void)`, `void VCModGangGroupRelease(CPlayerPed*)`,
  `void VCModGangGroupUpdate(CPlayerPed*, CPad*)`, `void VCModGangTryJoinCircle(CPlayerPed*)`.
- Consumes: everything above.

- [ ] **Step 1: Add the failing pairing test**

Append to `test_vc_ganggroup.py`:

```python
PAIR_STUBS = r'''
#include <cstdio>
#include <cstdint>
#include <cmath>
#define nil NULL
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
typedef int8_t int8;
typedef uint8_t uint8;
typedef int16_t int16;
typedef int32_t int32;
typedef uint32_t uint32;
enum { PED_NONE, PED_IDLE, PED_CHAT, PED_UNKNOWN };
#define VCMOD_GANG_GROUP_CLUSTER_TIME 100000
#define VCMOD_GANG_GROUP_MAX 6
static uint32 g_roll = 12345;
static float g_angle = 0.5f;
struct CVector { float x, y, z; CVector() : x(0.0f), y(0.0f), z(0.0f) {} };
struct CGeneral {
    static int GetRandomNumber(void) { return g_roll; }
    static float GetRadianAngleBetweenPoints(float, float, float, float) { return g_angle; }
};
struct CPed;
struct CEntity {};
struct CPed : CEntity {
    int m_nPedState;
    float m_fRotationDest, m_fRotationCur;
    int headingSet;
    float heading;
    CPed *chatWith;
    uint32 chatTime;
    CPed() : m_nPedState(PED_NONE), m_fRotationDest(0.0f), m_fRotationCur(0.0f),
             headingSet(0), heading(0.0f), chatWith(nil), chatTime(0) {}
    CVector GetPosition(void) { return CVector(); }
    void SetChat(CPed *other, uint32 time) { chatWith = other; chatTime = time; m_nPedState = PED_CHAT; }
    void SetHeading(float angle) { headingSet++; heading = angle; }
    void SetPedState(int state) { m_nPedState = state; }
};
typedef CPed CPlayerPed;
'''

PAIRTIME = "static uint32\nVCModGangGroupPairTime"
PAIR_CIRCLE = "static void\nVCModGangGroupPairCircle"


def pair_src():
    return (PAIR_STUBS + braced(GROUP, PAIRTIME) + "\n" + braced(GROUP, PAIR_CIRCLE) + "\n")


class CirclePairTests(unittest.TestCase):
    def test_player_pairs_with_the_last_slot_and_npcs_pair_from_both_ends(self):
        run_cpp(pair_src() + r'''
int main(void) {
    CPlayerPed tommy;
    CPed members[3];                      // a four-person ring, the player included
    CPed *list[3] = { &members[0], &members[1], &members[2] };
    VCModGangGroupPairCircle(&tommy, list, 3);
    if (tommy.chatWith != &members[2] || members[2].chatWith != &tommy) return 1;
    if (tommy.chatTime != 10345 || members[2].chatTime != 10345) return 2;
    if (members[0].chatWith != &members[1] || members[1].chatWith != &members[0]) return 3;
    if (members[0].chatTime != VCMOD_GANG_GROUP_CLUSTER_TIME) return 4;
    return 0;
}
''')

    def test_an_odd_ring_leaves_the_middle_facing_the_player(self):
        run_cpp(pair_src() + r'''
int main(void) {
    CPlayerPed tommy;
    CPed members[4];                      // a five-person ring
    CPed *list[4] = { &members[0], &members[1], &members[2], &members[3] };
    VCModGangGroupPairCircle(&tommy, list, 4);
    if (tommy.chatWith != &members[3]) return 1;
    if (members[0].chatWith != &members[2]) return 2;
    if (members[1].chatWith != nil) return 3;          // the middle stays unpaired
    if (members[1].m_nPedState != PED_UNKNOWN) return 4;
    if (members[1].headingSet != 1 || members[1].heading != 0.5f) return 5;
    return 0;
}
''')
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: FAIL — `VCModGangGroupPairCircle` marker missing.

- [ ] **Step 3: Implement the spawner and the call lifecycle**

Append to `vcmodganggroup.cpp` (order matters for the harness markers: `VCModGangGroupTrack`
after `DropRefs`, `Release`/`Update` before `TryJoinCircle`, `Call` last):

```cpp
static void
VCModGangGroupTrack(CPed **members, int32 count, bool formation)
{
	VCModGangGroupDropRefs();
	for (int32 i = 0; i < count && i < VCMOD_GANG_GROUP_MAX; i++) {
		apVCModGangGroup[i] = members[i];
		members[i]->RegisterReference((CEntity **)&apVCModGangGroup[i]);
	}
	bVCModGangGroupFormation = formation;
}

// the stock member block (Population.cpp:1461-1495) with the player in the
// leader slot: the player keeps his own wander and the followers trail it
static int32
VCModGangGroupPlaceFormation(CPlayerPed *player, int32 gang, int32 size, CPed **members)
{
	CVector base = player->GetPosition();
	int32 placed = 0;
	for (int32 slot = 1; slot < size && placed < VCMOD_GANG_GROUP_MAX; slot++) {
		int32 model = CGangs::ChooseGangPedModel(gang);
		CPed *member = CPopulation::AddPed((ePedType)(PEDTYPE_GANG1 + gang), model, base);
		if (member == nil)
			continue;
		if (CGangs::GetWillAttackPlayerWithCops((ePedType)(PEDTYPE_GANG1 + gang)))
			member->bCanAttackPlayerWithCops = true;
		VCModGangGroupSetUpFollower(member, player, slot);
		CVector pos = member->GetFormationPosition();
		bool foundGround;
		float groundZ = CWorld::FindGroundZFor3DCoord(pos.x, pos.y, 1.0f + pos.z, &foundGround) + 1.0f;
		pos.z = Max(pos.z, groundZ);
		if (!foundGround
			|| Abs(pos.z - player->GetPosition().z) > 1.0f
			|| !CWorld::GetIsLineOfSightClear(pos, player->GetPosition(),
				true, false, false, false, false, false, false)) {
			CPopulation::RemovePed(member);
			continue;
		}
		member->SetPosition(pos);
		float angle = CGeneral::GetRadianAngleBetweenPoints(
			player->GetPosition().x, player->GetPosition().y, pos.x, pos.y);
		member->m_fRotationDest = angle;
		member->m_fRotationCur = angle;
		CVisibilityPlugins::SetClumpAlpha(member->GetClump(), 0);
		members[placed++] = member;
	}
	return placed;
}

// the stock circle block (Population.cpp:1510-1623) with slot 0 being the player
// at his own position: the centre sits radius ahead of him, members take the
// stock sector and jitter, and a slot that cannot be placed is skipped
static int32
VCModGangGroupPlaceCircle(CPlayerPed *player, int32 gang, int32 size, CPed **members)
{
	float radius = VCModGangGroupCircleRadius(size);
	CVector here = player->GetPosition();
	CVector fwd = player->GetForward();
	fwd.z = 0.0f;
	if (fwd.Magnitude2D() < 0.01f) {
		fwd.x = 0.0f;
		fwd.y = 1.0f;
	} else
		fwd.Normalise2D();
	CVector right(fwd.y, -fwd.x, 0.0f);
	CVector centre = here + fwd * radius;

	int32 placed = 0;
	for (int32 slot = 1; slot < size && placed < VCMOD_GANG_GROUP_MAX; slot++) {
		float offsetFwd, offsetSide;
		VCModGangGroupSlotOffset(slot, size,
			CGeneral::GetRandomNumberInRange(-0.2f, 0.2f),
			CGeneral::GetRandomNumberInRange(-0.2f, 0.2f),
			&offsetFwd, &offsetSide);
		CVector pos = centre + fwd * offsetFwd + right * offsetSide;

		bool foundGround;
		float groundZ = CWorld::FindGroundZFor3DCoord(pos.x, pos.y, centre.z + 1.0f, &foundGround) + 1.0f;
		pos.z = here.z > groundZ ? here.z : groundZ;
		if (!foundGround || Abs(pos.z - here.z) >= 1.0f)
			continue;

		int32 model = CGangs::ChooseGangPedModel(gang);
		CEntity *obstacles[VCMOD_GANG_GROUP_MAX] = { nil, nil, nil, nil, nil, nil };
		CPedPlacement::IsPositionClearForPed(pos,
			CModelInfo::GetColModel(model)->boundingSphere.radius,
			ARRAY_SIZE(obstacles), obstacles);
		bool blocked = false;
		for (int32 m = 0; m < ARRAY_SIZE(obstacles); m++) {
			if (obstacles[m] == nil)
				continue;
			bool ours = false;
			for (int32 n = 0; n < placed; n++)
				if (obstacles[m] == members[n])
					ours = true;
			if (!ours) {
				blocked = true;
				break;
			}
		}
		if (blocked)
			continue;
		if (!CWorld::GetIsLineOfSightClear(pos, here, true, false, false, false, false, false, false))
			continue;

		CPed *member = CPopulation::AddPed((ePedType)(PEDTYPE_GANG1 + gang), model, pos);
		if (member == nil)
			continue;
		if (CGangs::GetWillAttackPlayerWithCops((ePedType)(PEDTYPE_GANG1 + gang)))
			member->bCanAttackPlayerWithCops = true;
		float angle = CGeneral::GetRadianAngleBetweenPoints(centre.x, centre.y, pos.x, pos.y);
		member->m_fRotationDest = angle;
		member->m_fRotationCur = angle;
		CVisibilityPlugins::SetClumpAlpha(member->GetClump(), 0);
		members[placed++] = member;
	}
	return placed;
}

// the stock pairing over the whole ring, the player included: his pair uses the
// pedestrian meet length, the NPC pairs the cluster timer, and an odd ring
// leaves the locked middle facing him
static void
VCModGangGroupPairCircle(CPlayerPed *player, CPed **members, int32 count)
{
	int32 n = count + 1;
	uint32 roll = CGeneral::GetRandomNumber();
	for (int32 j = 0; j < n / 2; j++) {
		CPed *a = j == 0 ? (CPed *)player : members[j - 1];
		CPed *b = members[n - 2 - j];
		uint32 time = VCModGangGroupPairTime(j == 0, roll);
		a->SetChat(b, time);
		b->SetChat(a, time);
	}
	if ((n & 1) != 0) {
		int32 middleSlot = (n - 1) / 2;
		if (middleSlot >= 1) {
			CPed *middle = members[middleSlot - 1];
			float angle = CGeneral::GetRadianAngleBetweenPoints(
				player->GetPosition().x, player->GetPosition().y,
				middle->GetPosition().x, middle->GetPosition().y);
			middle->SetHeading(angle);
			middle->SetPedState(PED_UNKNOWN);
		}
	}
}

void
VCModGangGroupCall(void)
{
	CPlayerPed *player = FindPlayerPed();
	if (player == nil)
		return;

	uint32 refusal = VCModGangGroupRefusal(player);
	if (refusal == VCMOD_GANG_GROUP_NEED_GANG) {
		VCModGangGroupRefuse("gang: become a gang first");
		return;
	}
	if (refusal == VCMOD_GANG_GROUP_IN_CAR) {
		VCModGangGroupRefuse("gang: get out first");
		return;
	}
	if (refusal == VCMOD_GANG_GROUP_NOT_NOW) {
		VCModGangGroupRefuse("gang: not now");
		return;
	}
	if (refusal == VCMOD_GANG_GROUP_ALREADY) {
		VCModGangGroupRefuse("gang: already here");
		return;
	}
	// tracked corpses are not a group: drop those references and spawn fresh
	VCModGangGroupDropRefs();

	int32 gang = VCModGangGroupGang(player);
	int32 model1 = CGangs::GetGangPedModel1(gang);
	int32 model2 = CGangs::GetGangPedModel2(gang);
	CStreaming::RequestModel(model1, 0);
	CStreaming::RequestModel(model2, 0);
	CStreaming::LoadAllRequestedModels(false);
	if (!CStreaming::HasModelLoaded(model1) || !CStreaming::HasModelLoaded(model2)) {
		VCModGangGroupRefuse("gang: the models cannot be loaded");
		return;
	}

	int32 size = CPopulation::ComputeRandomisedGangSize();
	if (size < 3)
		size = 3;
	if (size > VCMOD_GANG_GROUP_MAX)
		size = VCMOD_GANG_GROUP_MAX;
	bool formation = VCModGangGroupIsFormationRoll(CGeneral::GetRandomNumberInRange(0.0f, 1.0f));

	CPed *members[VCMOD_GANG_GROUP_MAX];
	int32 placed = formation
		? VCModGangGroupPlaceFormation(player, gang, size, members)
		: VCModGangGroupPlaceCircle(player, gang, size, members);
	if (placed < 2) {
		for (int32 i = 0; i < placed; i++)
			CPopulation::RemovePed(members[i]);
		VCModGangGroupRefuse("gang: no room here");
		return;
	}

	VCModGangGroupTrack(members, placed, formation);
	if (formation)
		VCModGangGroupLinkFormation(members, placed, player);
	else
		VCModGangGroupPairCircle(player, members, placed);
	VCModHudNotice("your gang is here");
	fprintf(stderr, "VCMOD gang group: %s out, n=%d placed=%d\n",
		formation ? "formation" : "circle", size, placed);
}

void
VCModGangGroupRelease(CPlayerPed *player)
{
	for (int32 i = 0; i < VCMOD_GANG_GROUP_MAX; i++) {
		CPed *member = apVCModGangGroup[i];
		if (member == nil)
			continue;
		if (bVCModGangGroupFormation && !member->DyingOrDead()) {
			// the hand-back the spec names: drop the link and the follow
			// objective, then walk on as a random pedestrian
			member->SetLeader(nil);
			member->ClearObjective();
			if (member->IsPedInControl())
				member->SetWanderPath(CGeneral::GetRandomNumber() & 7);
		}
		member->CleanUpOldReference((CEntity **)&apVCModGangGroup[i]);
		apVCModGangGroup[i] = nil;
	}
	bVCModGangGroupFormation = false;
	if (player != nil)
		player->bIsLeader = false;
}

void
VCModGangGroupUpdate(CPlayerPed *player, CPad *pad)
{
	bool broken = !bVCModNpcMode || !VCModNpcGangActive()
		|| player->DyingOrDead() || player->bInVehicle
		|| player->m_nPedState == PED_ARRESTED
		|| (pad != nil && pad->ArePlayerControlsDisabled());
	if (broken && VCModGangGroupTracked())
		VCModGangGroupRelease(player);
}

void
VCModGangTryJoinCircle(CPlayerPed *player)
{
	if (player->m_nPedState != PED_WANDER_PATH || player->m_objective != OBJECTIVE_NONE)
		return;

	uint32 now = CTimer::GetTimeInMilliseconds();
	// the stock walker roll (Ped.cpp:1397-1419): half the frames skip, the rest
	// check, and a miss parks the next look 200 ms out
	if (CGeneral::GetRandomNumberInRange(0.0f, 1.0f) >= 0.5f) {
		player->m_chatTimer = now + 200;
		return;
	}
	if (now <= player->m_chatTimer)
		return;

	int32 playerGang = VCModGangEffectiveType(player);
	VCModGangJoinPed peds[VCMOD_GANG_GROUP_JOIN_NEAR];
	int32 count = 0;
	for (int32 i = 0; i < player->m_numNearPeds && count < VCMOD_GANG_GROUP_JOIN_NEAR; i++) {
		CPed *ped = player->m_nearPeds[i];
		if (ped == nil || ped == player)
			continue;
		float dist = (ped->GetPosition() - player->GetPosition()).Magnitude();
		if (dist >= VCMOD_GANG_GROUP_JOIN_RANGE)
			continue;
		if (!player->CanSeeEntity(ped) || !ped->CanSeeEntity(player))
			continue;
		VCModGangJoinPed *c = &peds[count++];
		c->ped = ped;
		c->gang = VCModGangEffectiveType(ped);
		c->willChat = ped->WillChat(player);
		c->state = ped->m_nPedState;
		c->lookIsPed = ped->m_pLookTarget != nil && ped->m_pLookTarget->IsPed();
		c->lookState = c->lookIsPed ? ((CPed *)ped->m_pLookTarget)->m_nPedState : PED_NONE;
		c->lookGang = c->lookIsPed ? VCModGangEffectiveType((CPed *)ped->m_pLookTarget) : -1;
		c->dist = dist;
	}

	int32 pick = VCModGangGroupPickJoin(peds, count, playerGang);
	if (pick < 0)
		return;

	uint32 time = VCModGangGroupPairTime(true, CGeneral::GetRandomNumber());
	VCModGangGroupJoin(player, peds[pick].ped, time, now);
	fprintf(stderr, "VCMOD gang group: joined a kin circle (%s)\n",
		VCModGangJoinKind(&peds[pick], playerGang) == 2 ? "middle" : "pair");
}
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: `OK` (18 tests).

---

### Task 5: Panel row, click and README

**Files:**
- Modify: `reVC/src/extras/vcmodpanelinternal.h`
- Modify: `reVC/src/extras/vcmodpanelregistry.cpp`
- Modify: `reVC/src/extras/vcmodpanel.cpp`
- Modify: `reVC/README.md` — no: `README.md` at the workspace root
- Test: `reVC/utils/test_vc_panel_info.py`

**Interfaces:**
- Consumes: `VCModGangGroupAlive`, `VCModGangGroupCell`, `VCModGangGroupCall`.
- Produces: row kind `VCMOD_ROW_GANGGROUP`.

- [ ] **Step 1: Add the failing panel tests**

Append to `test_vc_panel_info.py`:

```python
    def test_call_gang_row(self):
        rows = table_rows()
        names = [fields[0].strip('"') for fields in rows]
        self.assertIn("CALL GANG", names)
        index = names.index("CALL GANG")
        self.assertEqual(names[index - 1], "TYPE FROM BODY")
        row = rows[index]
        self.assertEqual(len(row), 9)
        self.assertEqual(row[1], "VCMOD_ROW_GANGGROUP")
        self.assertEqual(row[2], "nil")             # no stored state
        self.assertEqual(row[3], "nil")             # no ini key
        self.assertEqual(row[4], "VCMOD_PAGE_WORLD")
        self.assertEqual(row[5], "nil")
        self.assertNotEqual(row[7], "nil")          # info
        self.assertNotEqual(row[8], "nil")          # warning
```

Bump the row-count floor in `test_every_row_has_a_description` from 56 to the count after the
row is added (60 at the time of writing; set it to the number the harness reports).

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 test_vc_panel_info.py`
Expected: FAIL — `CALL GANG` not in the row table.

- [ ] **Step 3: Add the row kind, row, click and render**

`vcmodpanelinternal.h`, in `eVCModRowKind` after `VCMOD_ROW_CALLCREW`:

```cpp
	VCMOD_ROW_GANGGROUP,	// calls one stock group of the player's gang
```

`vcmodpanelregistry.cpp`, in `aVCModRows` directly after the `TYPE FROM BODY` entry:

```cpp
	{ "CALL GANG",       VCMOD_ROW_GANGGROUP, nil,                 nil,              VCMOD_PAGE_WORLD, nil, -1,
	  "one stock group of your own gang", "needs BECOME NPC on the GANG profile" },
```

Add the include next to the other feature headers:

```cpp
#include "vcmodganggroup.h"
```

Add the debug-menu entry in `namespace VCModTweaksWorld` after the NPC rows:

```cpp
TWEAKFUNCN(VCModGangGroupCall, "call gang");
```

`vcmodpanel.cpp`: add `#include "vcmodganggroup.h"`, then in `VCModClick`'s switch:

```cpp
		case VCMOD_ROW_GANGGROUP:
			VCModGangGroupCall();
			break;
```

and in `VCModPanelRender`'s switch:

```cpp
		case VCMOD_ROW_GANGGROUP:
			style = VCModGangGroupAlive() > 0 ? VCFONT_ON : VCFONT_OFF;
			value = VCModGangGroupCell();
			break;
```

- [ ] **Step 4: Add the README row**

In the **Toggles** table after the `CALL CREW`/`CREW CAR` block:

```
| `CALL GANG` row | — | One press sends one stock-shaped group of the player's own gang while BECOME NPC runs the GANG profile: the stock walking formation with Tommy at its head, or the stock chatting circle with him on the ring. A press while one is still out says so |
```

- [ ] **Step 5: Run the panel harness**

Run: `cd reVC/utils && python3 test_vc_panel_info.py`
Expected: `OK`.

---

### Task 6: NPC mode hooks (release, update, join)

**Files:**
- Modify: `reVC/src/extras/vcmodnpc.cpp`
- Test: `reVC/utils/test_vc_ganggroup.py`

- [ ] **Step 1: Add the failing hook tests**

Append to `test_vc_ganggroup.py`:

```python
class NpcHookTests(unittest.TestCase):
    def test_the_mode_owns_the_group(self):
        self.assertIn('#include "vcmodganggroup.h"', NPC)
        self.assertIn("VCModGangGroupUpdate(player, pad);", NPC)
        self.assertIn("VCModGangGroupRelease(player);", NPC)

    def test_the_gang_branch_tries_the_circle_join(self):
        start = NPC.index("} else if (profile == VCMOD_NPC_GANG) {")
        branch = NPC[start:NPC.index("} else if (profile == VCMOD_NPC_COP) {", start)]
        self.assertIn("VCModGangTryJoinCircle(player);", branch)
        self.assertLess(branch.index("ProcessCivilianState"),
                        branch.index("VCModGangTryJoinCircle"))
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: FAIL.

- [ ] **Step 3: Add the three calls**

`vcmodnpc.cpp`:

Include:

```cpp
#include "vcmodganggroup.h"
```

Mode-off edge, inside `if (bVCModNpcModeWasOn)`, after `VCModNpcReleasePed(player);`:

```cpp
			VCModGangGroupRelease(player);
```

Mode-on path, right after `VCModNpcBorrowIdentity(player, bCivilianWander, bGangWander);`:

```cpp
	// CALL GANG's group belongs to the mode: another profile, a car, death or
	// an arrest hands its followers back before this frame's AI runs
	VCModGangGroupUpdate(player, pad);
```

GANG branch, directly after `player->ProcessCivilianState();`:

```cpp
			// a stock kin circle never looks at a walker; the mod lets him walk
			// into its conversation on the same gates the walker chat uses
			VCModGangTryJoinCircle(player);
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_ganggroup.py`
Expected: `OK` (20 tests).

---

### Task 7: Full suite and build

- [ ] **Step 1: Run every harness**

Run: `cd reVC/utils && for f in test_vc_*.py; do echo "== $f"; python3 "$f" >/dev/null 2>&1 || { python3 "$f"; exit 1; }; done; echo ALL PASS`
Expected: `ALL PASS`.

- [ ] **Step 2: Build**

Run: `scripts/build.sh`
Expected: `built: <repo>/reVC/build/src/reVC.app` with no errors. The build also compiles the
pre-existing uncommitted `vcmoddrivecam` work; if that fails, report it and do not edit it.

---

### Task 8: Install (game stopped)

- [ ] **Step 1: Verify no session is running**

Run: `pgrep -f "reVC.app/Contents/MacOS/reVC" || echo stopped`
Expected: `stopped` (no PIDs). If PIDs print, stop and ask — never install over a live session.

- [ ] **Step 2: Install**

Run: `scripts/install.sh`
Expected: `installed: /Users/<user>/Games/VC/reVC.app`.

- [ ] **Step 3: Confirm the build number**

Run: `strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" | grep -m1 '^vcmods build '`
Expected: the next counter value (538 at the time of writing).

---

### Task 9: Handoff

- [ ] **Step 1: Write `docs/handoff/2026-11-14-gang-group-build.md`**

Include: repo/branch/HEAD (unchanged `ff1f984`), the installed build number, what is
uncommitted (the new module, panel hooks, NPC hooks, harness, README, plan, spec status and
the pre-existing `vcmoddrivecam` work), the harness/build/install results, the in-game matrix
from the spec, and the do-not-touch list.

- [ ] **Step 2: Update the spec status line**

`docs/specs/2026-11-14-gang-group-design.md` header: `Status: implemented in build <N>;
awaiting the in-game matrix.`

- [ ] **Step 3: Post the paste-ready prompt in chat**

Per AGENTS.md: repo/branch/HEAD, installed build, uncommitted list, next two or three steps,
files not to touch.

---

## Self-Review

**Spec coverage**
- Panel row + gate + notices: Task 2 (gate/cell), Task 5 (row/click/render/README).
- Stock shape and size, circle slots/pairing/middle, formation fields, player not moved:
  Tasks 1, 3, 4 (+ `SourceShapeTests`).
- Active-group tracking, corpse pruning, one group at a time: Task 2 (`Alive`, `Refusal`) and
  Task 4 (`DropRefs` in `Call`).
- Lifecycle unlink on mode off / break / profile switch: Task 4 (`Release`, `Update`), Task 6
  (hooks).
- Kin-circle join (stock roll, 200 ms, timer, middle-first, displaced partner, rival filter):
  Tasks 3 and 4.
- Harness + full suite + build + install: Tasks 1–8.
- Handoff: Task 9.

**Deviations recorded**
- `gang: not now` is added for the dead / not-in-control refusal the spec gates on but does
  not name; the design's "never a silent no-op" rule demands a notice.
- The circle's initial heading is the stock outward-from-centre rotation (the stock call
  orients the member to face the ring centre); the formation sets the spec's
  face-the-leader rotation, which stock leaves at the spawn orientation.
- Debug-menu entry `call gang` added for the new feature checklist; no hotkey, no ini key.

## Execution notes (2026-11-14)

- All nine tasks executed. `test_vc_ganggroup.py` ends at 21 tests; `test_vc_panel_info.py`
  at 5; the full 48-harness suite was green before the build.
- The panel row floor moved 56 → 61 (the 60 existing rows plus CALL GANG; a concurrent
  session's two new rows make the live count 63, so the floor stays valid either way).
- `utils/test_vc_npcmode.py` needed counted stubs for `VCModGangGroupUpdate`,
  `VCModGangGroupRelease` and `VCModTryJoinCircle` — a new symbol used by an extracted
  function must be added to the stubs (docs/architecture.md rule 14). Evented stubs broke
  the retry-gap test, so they are counters.
- `VCModGangGroupRelease` clears `player->bIsLeader` only for a released formation group, so
  an empty or circle release cannot clobber another feature's leader role.
- Build: `vcmods build 547`, installed into `~/Games/VC/reVC.app` with no session running.
- The checkout also carried another session's uncommitted ammo/save/keys work during this
  session; the installed build includes it. That work is not this feature's surface.

## Follow-up (2026-11-14)

Play test 1 spawned a formation and its members walked in Tommy's player animation set.
`CPed::SetMoveAnim` gives any player-led follower `ASSOCGRP_PLAYER` unless exempted, and
only the crew was. Added `VCModGangGroupOwnsPed(CPed*)` and extended the engine condition
with it, so the formation keeps the model's stock gang set. The circle never had a leader
link and was unaffected. `PairCircle` also logs the player's pair length once per press, so
a play test can confirm the chatter from the log. Harness: 23 ganggroup tests plus a CALL
GANG case in the crew animation test (and its stub). Build 549 installed.

Follow-up 2 (play test 2, five formations and three failed circle presses): the circle's
stock obstacle scan counted the player — slot 0 of the ring — as a blocker for the slots
beside him, so three- and four-person rings could never place. Added
`VCModGangGroupRingObstacle` (the player and the placed members never block a slot) and
shape-named success notices (`your gang falls in behind you` / `your gang is talking`).
Harness: 24 ganggroup tests. Build 551 installed.

Follow-up 3 (play test 3, the circle scattered after the chatter): the stock chat restore
gives a leaderless random ped a random wander path. Added deferred adoption — no leader
link while the ring talks; each man joins the player's formation as his chat ends, the
middle when the ring is quiet — plus a link bitmask so `Release` unlinks exactly those.
Harness: 25 ganggroup tests. Build 553 installed.

Follow-up 4 (play decision: the spawned ring's talk is open-ended, ended by a menu input):
all pairs start on the cluster timer and the per-frame update pushes every open pair's
clock 2 s out (the player's included while his partner is tracked); the CALL GANG row's
second press ends the whole ring on the stock 30 s gap, adopts the men on the same press
and the cell reads `N men talking`. The walk-up join into a world circle keeps the stock
10–14 s meet. Harness: 26 ganggroup tests. Build 557 installed.

Follow-up 5 (the talk still ended on its own): the civilian car-theft layer (borrowed
`m_bLookForVacantCars`) could hand the player an enter-car objective mid-talk, and an
objective already in hand at press time did the same. `VCModGangGroupPlayerTalking` now
gates the car/attractor calls in the GANG branch, the press clears a carried objective,
and a talk that ends without the menu logs the player's and members' states once.
Harness: 27 ganggroup tests. Build 559 installed.

Follow-up 6 (the talk expired with the panel open; cross pairing; circle-favouring split):
the hold moved from the mode update to `CGame::Process` (`VCModGangGroupTick`), because the
panel blocks the mode update and the 100 s nominal clocks ran out together; per-person
"left the talk (state)" lines added; the ring now pairs across (A-C, B-D) and the button's
formation roll dropped to 0.2, with the roll value in the log. Harness: 28 tests. Build 561
installed.
