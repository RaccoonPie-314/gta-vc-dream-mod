# BECOME NPC with player movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While BECOME NPC runs, the movement keys own locomotion and the profile AI keeps everything else, combat included; one new row switches it and feature-off is BECOME NPC byte for byte.

**Architecture:** A new `vcmodnpcwalk` module owns the flag, the input predicate and the wait rule. `CPlayerPed::ProcessControl`'s state switch defers each AI speed write to the stock player locomotion while a key is held. Combat keeps the AI's target, aim and trigger; the stock tracking turn re-asserts the facing after the walk. Delivered in three playable slices: A free walk, B combat steering, C edge states.

**Tech Stack:** reVC C++ (C++98-compatible engine), Python 3 harnesses in `reVC/utils`, CMake via `scripts/build.sh`.

**Spec:** `docs/specs/2026-11-15-npc-player-walk-design.md`

## Global Constraints

- Feature off is stock: every new branch sits behind `VCModNpcPlayerWalks()`, and that predicate is false unless BECOME NPC and the new row are both on.
- Engine files (`src/peds/`) get hook calls and one-line branches only; feature logic lives in `src/extras/vcmodnpcwalk.{cpp,h}`.
- C++98 only: no `nullptr`, `auto`, range-for or lambdas; `nil` for null.
- Naming rule 17: `VCModNpcPlayerWalks`, `VCModNpcWalkInput`, `VCModNpcWalkMove`, `VCModNpcWalkCombat`; flags `bVCModNpcPlayerWalk`.
- The panel row keeps the harness limits: 9 fields, info ≤ 50 chars, warning ≤ 48 chars, unique name, WORLD page.
- Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty; never install over a running session.
- Run the whole suite, not only the touched harness: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f" || exit 1; done`.
- Do not commit, tag or push unless the user asks. The handoff records what is uncommitted.
- One installed build per slice; the user plays before the next slice starts.
- The installed binary must report the new build number before the slice is handed off.
- Portability: no platform `#ifdef` and no path in feature code.

## File Structure

- `src/extras/vcmodnpcwalk.h` — the row flag, the three predicates/helpers, the combat helper (slice B).
- `src/extras/vcmodnpcwalk.cpp` — flag default, predicates, wait rule, locomotion calls.
- `src/peds/PlayerPed.cpp` — include plus five hook sites: four free states (A), the combat group and the targeting lock (B).
- `src/extras/vcmodpanelregistry.cpp` — row under BECOME NPC, include, ini key.
- `src/extras/vcmodganggroup.{cpp,h}` — the ring-talk walk-away (C).
- `utils/test_vc_playerwalk.py` — the harness.

---

## Slice A — the row and the free walk

### Task A1: The module, the row and the predicates

**Files:**
- Create: `src/extras/vcmodnpcwalk.h`
- Create: `src/extras/vcmodnpcwalk.cpp`
- Modify: `src/extras/vcmodpanelregistry.cpp` (include near `vcmodnpc.h`, row after BECOME NPC at line 226, tweak in the World namespace near line 466)
- Create: `utils/test_vc_playerwalk.py`

**Interfaces:**
- Produces: `extern bool bVCModNpcPlayerWalk` (default false).
- Produces: `bool VCModNpcPlayerWalks(void)` — true only when `bVCModNpcMode && bVCModNpcPlayerWalk`.
- Produces: `bool VCModNpcWalkInput(CPad *pad)` — true for a walk axis, sprint with a direction or a jump press; false for nil or disabled controls.
- Produces: `void VCModNpcWalkMove(CPlayerPed *player, CPad *pad)` — ends a pose wait, then `PlayerControlZelda`.

- [ ] **Step 1: Write the harness**

Create `utils/test_vc_playerwalk.py`:

```python
#!/usr/bin/env python3
"""WASD MOVE: BECOME NPC runs the profile AI, the movement keys own locomotion.
The predicates and the wait rule are compiled against stubs; the engine wiring
is pinned from the sources."""
import pathlib
import unittest

from vcmod_test_support import braced, run_cpp

ROOT = pathlib.Path(__file__).resolve().parents[1]
WALK = ROOT / "src/extras/vcmodnpcwalk.cpp"
PANEL = (ROOT / "src/extras/vcmodpanelregistry.cpp").read_text()
PLAYER = ROOT / "src/peds/PlayerPed.cpp"

STUBS = r'''
#include <cstdio>
#include <cstdint>
#define nil NULL
typedef int32_t int32;

bool bVCModNpcMode;
bool bVCModNpcPlayerWalk;

enum ePedState { PED_IDLE, PED_ATTACK, PED_AIM_GUN, PED_FIGHT };
enum eWaitState {
    WAITSTATE_FALSE,
    WAITSTATE_USE_ATM,
    WAITSTATE_PLAYANIM_CHAT,
    WAITSTATE_SIT_DOWN,
    WAITSTATE_SIT_DOWN_RVRS,
    WAITSTATE_SIT_UP,
    WAITSTATE_SIT_IDLE,
    WAITSTATE_STUCK,
};

struct CPad {
    float leftRight, upDown;
    bool jump, disabled;
    CPad() : leftRight(0), upDown(0), jump(false), disabled(false) {}
    float GetPedWalkLeftRight(void) { return leftRight; }
    float GetPedWalkUpDown(void) { return upDown; }
    bool JumpJustDown(void) { return jump; }
    bool ArePlayerControlsDisabled(void) { return disabled; }
};
struct CPlayerPed {
    int m_nWaitState;
    int m_nPedState;
    void *m_pPointGunAt;
    int clears, zelda, fighter, rotate;
    CPlayerPed() : m_nWaitState(WAITSTATE_FALSE), m_nPedState(PED_IDLE),
                   m_pPointGunAt(nil), clears(0), zelda(0), fighter(0), rotate(0) {}
    void ClearWaitState(void) { ++clears; m_nWaitState = WAITSTATE_FALSE; }
    void PlayerControlZelda(CPad *) { ++zelda; }
    void PlayerControlFighter(CPad *) { ++fighter; }
    void RotatePlayerToTrackTarget(void) { ++rotate; }
};

static int failed = 0;
#define CHECK(c, m) do { if (!(c)) { printf("FAIL: %s\n", m); failed++; } } while (0)
'''

SIGS = (
    "bool\nVCModNpcPlayerWalks(void)",
    "bool\nVCModNpcWalkInput(CPad *pad)",
    "static void\nVCModNpcWalkEndPoseWait(CPlayerPed *player)",
    "void\nVCModNpcWalkMove(CPlayerPed *player, CPad *pad)",
)

MAIN = r'''
int main(void) {
    CPlayerPed p;
    CPad pad;
    bVCModNpcMode = false; bVCModNpcPlayerWalk = true;
    CHECK(!VCModNpcPlayerWalks(), "mode off: the row is inert");
    bVCModNpcMode = true; bVCModNpcPlayerWalk = false;
    CHECK(!VCModNpcPlayerWalks(), "row off: BECOME NPC untouched");
    bVCModNpcPlayerWalk = true;
    CHECK(VCModNpcPlayerWalks(), "both on: the keys steer");

    pad.leftRight = -1;
    CHECK(VCModNpcWalkInput(&pad), "a walk axis is input");
    pad.leftRight = 0; pad.upDown = 1;
    CHECK(VCModNpcWalkInput(&pad), "forward is input");
    pad.upDown = 0; pad.jump = true;
    CHECK(VCModNpcWalkInput(&pad), "a jump press is input");
    pad.jump = false;
    CHECK(!VCModNpcWalkInput(&pad), "a still pad is no input");
    CHECK(!VCModNpcWalkInput(nil), "nil is no input");
    pad.disabled = true; pad.upDown = 1;
    CHECK(!VCModNpcWalkInput(&pad), "disabled controls are no input");
    pad.disabled = false; pad.upDown = 0;

    p.m_nWaitState = WAITSTATE_STUCK;
    VCModNpcWalkMove(&p, &pad);
    CHECK(p.clears == 1 && p.m_nWaitState == WAITSTATE_FALSE, "a pose wait ends on the keys");
    CHECK(p.zelda == 1, "the stock walk runs");
    p.m_nWaitState = WAITSTATE_USE_ATM;
    VCModNpcWalkMove(&p, &pad);
    CHECK(p.clears == 1 && p.m_nWaitState == WAITSTATE_USE_ATM, "an ATM wait keeps its clock");
    CHECK(p.zelda == 2, "the keys still move him");

    printf(failed ? "FAILED\n" : "ok\n");
    return failed != 0;
}
'''


def fixture():
    return STUBS + "\n" + "\n".join(braced(WALK.read_text(), sig) for sig in SIGS) + MAIN


class Predicates(unittest.TestCase):
    def test_module_decisions(self):
        run_cpp(fixture())


class PanelRow(unittest.TestCase):
    ROW = ('\t{ "WASD MOVE",       VCMOD_ROW_FLAG,    &bVCModNpcPlayerWalk, "NpcPlayerWalk",  VCMOD_PAGE_WORLD, nil, -1,\n'
           '\t  "keys steer; the AI does the rest", "needs BECOME NPC on" },')

    def test_the_row_sits_under_become_npc(self):
        self.assertIn(self.ROW, PANEL)
        self.assertGreater(PANEL.index('"WASD MOVE"'), PANEL.index('"BECOME NPC"'))
        self.assertLess(PANEL.index('"WASD MOVE"'), PANEL.index('"NPC TYPE"'))
        self.assertIn("TWEAKBOOL(bVCModNpcPlayerWalk);", PANEL)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py`
Expected: FAIL with `FileNotFoundError` for `vcmodnpcwalk.cpp`.

- [ ] **Step 3: Create the module**

Create `src/extras/vcmodnpcwalk.h`:

```cpp
#ifndef VCMODNPCWALK_H
#define VCMODNPCWALK_H

class CPad;
class CPlayerPed;

// "WASD MOVE": while BECOME NPC runs the movement keys own locomotion and the
// AI keeps everything else; off is BECOME NPC, byte for byte
extern bool bVCModNpcPlayerWalk;

// true when BECOME NPC runs and the row is on
bool VCModNpcPlayerWalks(void);
// true when a movement key is held this frame
bool VCModNpcWalkInput(CPad *pad);
// the keys own this frame: end a pose wait, then the stock on-foot locomotion
void VCModNpcWalkMove(CPlayerPed *player, CPad *pad);

#endif
```

Create `src/extras/vcmodnpcwalk.cpp`:

```cpp
#include "common.h"

#include "vcmodnpcwalk.h"
#include "vcmodnpc.h"

#include "Pad.h"
#include "Ped.h"
#include "PlayerPed.h"

bool bVCModNpcPlayerWalk = false;

bool
VCModNpcPlayerWalks(void)
{
	return bVCModNpcMode && bVCModNpcPlayerWalk;
}

bool
VCModNpcWalkInput(CPad *pad)
{
	if (pad == nil || pad->ArePlayerControlsDisabled())
		return false;
	return pad->GetPedWalkLeftRight() != 0.0f || pad->GetPedWalkUpDown() != 0.0f
		|| pad->JumpJustDown();
}

// a pose wait ends on a keypress the way a pedestrian's own movement ends it;
// the attractor waits keep their clock and their registration, so they finish
// on their own
static void
VCModNpcWalkEndPoseWait(CPlayerPed *player)
{
	switch (player->m_nWaitState) {
	case WAITSTATE_FALSE:
	case WAITSTATE_USE_ATM:
	case WAITSTATE_PLAYANIM_CHAT:
	case WAITSTATE_SIT_DOWN:
	case WAITSTATE_SIT_DOWN_RVRS:
	case WAITSTATE_SIT_UP:
	case WAITSTATE_SIT_IDLE:
		break;
	default:
		player->ClearWaitState();
		break;
	}
}

void
VCModNpcWalkMove(CPlayerPed *player, CPad *pad)
{
	VCModNpcWalkEndPoseWait(player);
	player->PlayerControlZelda(pad);
}
```

- [ ] **Step 4: Add the row and the ini key**

In `src/extras/vcmodpanelregistry.cpp`, add the include after `#include "vcmodnpc.h"`:

```cpp
#include "vcmodnpcwalk.h"
```

Insert the row directly after the BECOME NPC row:

```cpp
	{ "WASD MOVE",       VCMOD_ROW_FLAG,    &bVCModNpcPlayerWalk, "NpcPlayerWalk",  VCMOD_PAGE_WORLD, nil, -1,
	  "keys steer; the AI does the rest", "needs BECOME NPC on" },
```

In `namespace VCModTweaksWorld`, after `TWEAKBOOLN(bVCModNpcMode, "become npc (ignores input)");`:

```cpp
TWEAKBOOL(bVCModNpcPlayerWalk);
```

- [ ] **Step 5: Run the new harness and the panel harness**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py && python3 test_vc_panel_info.py`
Expected: both PASS.

### Task A2: The free-state hook sites

**Files:**
- Modify: `src/peds/PlayerPed.cpp` (include after `vcmodnpc.h`; flee/investigate case line 2073; wander case line 2131; chat case line 2138; seek case line 2152)
- Modify: `utils/test_vc_playerwalk.py` (add the wiring class)

**Interfaces:**
- Consumes: `VCModNpcPlayerWalks`, `VCModNpcWalkInput`, `VCModNpcWalkMove` from Task A1.
- Produces: the four gated hook sites the slice-B task extends.

- [ ] **Step 1: Add the failing wiring tests**

Append to `utils/test_vc_playerwalk.py`, before `if __name__ == "__main__":`:

```python
def block(source, start, end):
    a = source.index(start)
    return source[a:source.index(end, a)]


GATE = "VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)"


class SliceAWiring(unittest.TestCase):
    def test_free_walk_cases_take_the_keys(self):
        text = PLAYER.read_text()

        flee = block(text, "case PED_FLEE_POS:", "case PED_NONE:")
        self.assertIn(GATE, flee)
        self.assertIn("VCModNpcWalkMove(this, padUsed)", flee)
        self.assertLess(flee.index(GATE), flee.index("VCModNpcMoveSpeed(this, 1.0f)"))

        wander = block(text, "case PED_WANDER_PATH:", "case PED_CHAT:")
        self.assertIn(GATE, wander)
        self.assertLess(wander.index(GATE), wander.index("VCModNpcStrollGait(this)"))

        chat = block(text, "case PED_CHAT:", "case PED_SEEK_ENTITY:")
        self.assertIn(GATE, chat)
        self.assertLess(chat.index(GATE), chat.index("m_fMoveSpeed = 0.0f"))

        seek = block(text, "case PED_SEEK_POS:", "case PED_JUMP:")
        self.assertIn(GATE, seek)
        self.assertLess(seek.index(GATE), seek.index("switch (m_nMoveState)"))

        self.assertEqual(text.count("VCModNpcWalkMove(this, padUsed)"), 4)

    def test_combat_stays_the_ais_until_slice_b(self):
        combat = block(PLAYER.read_text(), "case PED_ANSWER_MOBILE:", "case PED_WANDER_PATH:")
        self.assertNotIn("VCModNpcWalkCombat", combat)
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py`
Expected: FAIL, `AssertionError` on the first missing gate.

- [ ] **Step 3: Add the include**

In `src/peds/PlayerPed.cpp`, after `#include "vcmodnpc.h"`:

```cpp
#include "vcmodnpcwalk.h"
```

- [ ] **Step 4: Gate the flee/investigate case**

In `src/peds/PlayerPed.cpp`, replace:

```cpp
			if (bVCModNpcMode) {
				switch (m_nMoveState) {
```

with:

```cpp
			if (bVCModNpcMode) {
				if (VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)) {
					VCModNpcWalkMove(this, padUsed);
					break;
				}
				switch (m_nMoveState) {
```

- [ ] **Step 5: Gate the wander case**

Replace:

```cpp
		case PED_WANDER_PATH:
			// the engine's wander (base WanderPath) owns the heading and the seek;
```

with:

```cpp
		case PED_WANDER_PATH:
			if (VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)) {
				VCModNpcWalkMove(this, padUsed);
				break;
			}
			// the engine's wander (base WanderPath) owns the heading and the seek;
```

- [ ] **Step 6: Gate the chat case**

Replace:

```cpp
		case PED_CHAT:
			// a passer-by opened a chat (SetChat on both). Base Chat() runs the
```

with:

```cpp
		case PED_CHAT:
			if (VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)) {
				VCModNpcWalkMove(this, padUsed);
				break;
			}
			// a passer-by opened a chat (SetChat on both). Base Chat() runs the
```

- [ ] **Step 7: Gate the seek case**

Replace:

```cpp
		case PED_SEEK_POS:
			switch (m_nMoveState) {
```

with:

```cpp
		case PED_SEEK_POS:
			if (VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)) {
				VCModNpcWalkMove(this, padUsed);
				break;
			}
			switch (m_nMoveState) {
```

- [ ] **Step 8: Sweep the harnesses that embed the edited sites**

Four harnesses compile the edited code or the panel table with their own stubs:

- `utils/test_vc_cop_chase.py` extracts `case PED_SEEK_ENTITY:` through `case PED_SNIPER_MODE:`; add `struct CPad;`, `bool VCModNpcPlayerWalks(void) { return false; }`, `bool VCModNpcWalkInput(CPad *) { return false; }`, `void VCModNpcWalkMove(SPed *, CPad *) {}` beside the `VCModNpcMoveSpeed` stub, and `CPad *padUsed = nil;` at the top of `SPed::Run()`.
- `utils/test_vc_ganggaze.py` extracts `case PED_NONE:` through `case PED_SEEK_ENTITY:`; add `struct CPlayerPed;`, the same two predicate stubs and `void VCModNpcWalkMove(CPlayerPed *, CPad *) {}` after its `struct CPad` line.
- `utils/test_vc_adrenaline.py` and `utils/test_vc_character.py` compile the panel table; add `bool bVCModNpcPlayerWalk = false;` to the fixture definitions next to `bVCModNpcMode`.
- `utils/test_vc_passenger.py` counts the table rows: 63 becomes 64.

- [ ] **Step 9: Run the harness and the suite**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py`
Expected: PASS.

Run: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f" || exit 1; done`
Expected: every harness PASS.

### Task A3: Slice A delivery

**Files:**
- Modify: `docs/architecture.md` (module table and the player-glue counts)
- Create: `docs/handoff/2026-11-15-npc-player-walk-a.md`

- [ ] **Step 1: Update the architecture doc**

Add a table row beside `vcmodnpc`:

```markdown
| BECOME NPC walk | `vcmodnpcwalk` | `CPlayerPed` |
```

Update the `PlayerPed.cpp` line/reference counts with the real numbers:

```bash
wc -l src/peds/PlayerPed.cpp src/extras/vcmodnpcwalk.cpp
grep -c "VCMod" src/peds/PlayerPed.cpp
```

- [ ] **Step 2: Build**

Run from the workspace root: `scripts/build.sh`
Expected: `built: …/reVC/build/src/reVC.app`.

- [ ] **Step 3: Install with the game closed**

Run: `pgrep -f "reVC.app/Contents/MacOS/reVC"` (must print nothing), then from the workspace root: `scripts/install.sh`
Expected: `installed: …/Games/VC/reVC.app`.

- [ ] **Step 4: Confirm the installed build number**

Run: `strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" | grep -m1 '^vcmods build '`
Expected: a number newer than the previous build (593).

- [ ] **Step 5: Write the handoff**

Create `docs/handoff/2026-11-15-npc-player-walk-a.md` with: repo/branch/HEAD, the installed build number, what is uncommitted, what slice A changed, the play steps (steer over the wander and let go; steer during a cop chase; walk away from a chat; the row off must match BECOME NPC), the files not to touch, and a paste-ready prompt that starts slice B. The prompt names the spec and this plan, slice B, the harness, the build/install commands and the game-closed rule.

Do not commit.

---

## Slice B — combat steering

### Task B1: The combat hook and the targeting-lock bypass

**Files:**
- Modify: `src/extras/vcmodnpcwalk.h` (declare the combat helper)
- Modify: `src/extras/vcmodnpcwalk.cpp` (define it)
- Modify: `src/peds/PlayerPed.cpp` (combat group at line 2095; `MovementDisabledBecauseOfTargeting` at line 1689)
- Modify: `utils/test_vc_playerwalk.py` (combat fixture and wiring)

**Interfaces:**
- Consumes: the predicates from Task A1.
- Produces: `void VCModNpcWalkCombat(CPlayerPed *player, CPad *pad)` — pose wait, `PlayerControlFighter` in `PED_FIGHT`, else `PlayerControlZelda` then `RotatePlayerToTrackTarget` when `m_pPointGunAt` is set.

- [ ] **Step 1: Add the failing tests**

In `utils/test_vc_playerwalk.py`, add `"void\nVCModNpcWalkCombat(CPlayerPed *player, CPad *pad)"` to `SIGS` after the WalkMove entry, then append to `MAIN` before `printf`:

```cpp
    p.m_nPedState = PED_FIGHT;
    VCModNpcWalkCombat(&p, &pad);
    CHECK(p.fighter == 1 && p.zelda == 2, "a fist fight takes the stock fighter step");
    CHECK(p.rotate == 0, "no gun lock, no tracking turn");
    p.m_nPedState = PED_ATTACK; p.m_pPointGunAt = &pad;
    VCModNpcWalkCombat(&p, &pad);
    CHECK(p.zelda == 3 && p.rotate == 1, "the walk runs and the aim stays on the target");
    p.m_pPointGunAt = nil;
    VCModNpcWalkCombat(&p, &pad);
    CHECK(p.zelda == 4 && p.rotate == 1, "no target, no turn");
```

Add a wiring test to `SliceAWiring`, replacing the slice-A `test_combat_stays_the_ais_until_slice_b` (it pinned the now-superseded state):

```python
    def test_the_fight_steers_and_the_aim_stays(self):
        combat = block(PLAYER.read_text(), "case PED_ANSWER_MOBILE:", "case PED_WANDER_PATH:")
        self.assertIn(GATE, combat)
        self.assertIn("VCModNpcWalkCombat(this, padUsed)", combat)
        self.assertLess(combat.index(GATE), combat.index("VCModNpcCombatControl(this, npcCombatOwnsControl)"))
        self.assertIn("m_nPedState == PED_IDLE && npcCombatOwnsControl", combat)

    def test_the_ai_aim_never_plants_the_keys(self):
        gate = braced(PLAYER.read_text(), "CPlayerPed::MovementDisabledBecauseOfTargeting")
        self.assertIn("if (VCModNpcPlayerWalks())\n\t\treturn false;", gate)
        self.assertLess(gate.index("VCModNpcPlayerWalks"), gate.index("VCModCopTwoHandFiring(this, info)"))
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py`
Expected: FAIL, `ValueError` for the missing `VCModNpcWalkCombat` marker and the wiring assertions.

- [ ] **Step 3: Add the combat helper**

In `src/extras/vcmodnpcwalk.h`, before `#endif`:

```cpp
// the same for a combat frame: the AI keeps the target and the trigger, the
// keys only translate and the tracking turn keeps the facing on the target
void VCModNpcWalkCombat(CPlayerPed *player, CPad *pad);
```

In `src/extras/vcmodnpcwalk.cpp`, after `VCModNpcWalkMove`:

```cpp
void
VCModNpcWalkCombat(CPlayerPed *player, CPad *pad)
{
	VCModNpcWalkEndPoseWait(player);
	// a fist fight moves off the attack steps, not a free walk
	if (player->m_nPedState == PED_FIGHT) {
		player->PlayerControlFighter(pad);
		return;
	}
	player->PlayerControlZelda(pad);
	// the AI owns the target: put the facing back on it after the walk, the
	// same call the player's own lock-on makes
	if (player->m_pPointGunAt)
		player->RotatePlayerToTrackTarget();
}
```

- [ ] **Step 4: Gate the combat group**

In `src/peds/PlayerPed.cpp`, replace:

```cpp
		case PED_ANSWER_MOBILE:
			// Combat IDLE is an NPC attack pause, not a handover to player input.
			if (VCModNpcCombatControl(this, npcCombatOwnsControl))
```

with:

```cpp
		case PED_ANSWER_MOBILE:
			// the keys steer a fight too: the AI keeps the target and the
			// trigger, only the translation is the player's
			if (VCModNpcPlayerWalks() && VCModNpcWalkInput(padUsed)
				&& (m_nPedState == PED_ATTACK || m_nPedState == PED_FIGHT
					|| m_nPedState == PED_AIM_GUN
					|| (m_nPedState == PED_IDLE && npcCombatOwnsControl))) {
				VCModNpcWalkCombat(this, padUsed);
				break;
			}
			// Combat IDLE is an NPC attack pause, not a handover to player input.
			if (VCModNpcCombatControl(this, npcCombatOwnsControl))
```

- [ ] **Step 5: Bypass the targeting movement lock**

In `CPlayerPed::MovementDisabledBecauseOfTargeting`, replace:

```cpp
	CWeaponInfo *info = CWeaponInfo::GetWeaponInfo(GetWeapon()->m_eWeaponType);
	if (VCModCopTwoHandFiring(this, info))
```

with:

```cpp
	CWeaponInfo *info = CWeaponInfo::GetWeaponInfo(GetWeapon()->m_eWeaponType);
	// WASD MOVE: the AI owns the trigger and the target, so its aim must not
	// plant the player's own keys
	if (VCModNpcPlayerWalks())
		return false;
	if (VCModCopTwoHandFiring(this, info))
```

- [ ] **Step 6: Run the harness and the suite**

`utils/test_vc_ganggaze.py` extracts `case PED_NONE:` through
`case PED_SEEK_ENTITY:`, so add `void VCModNpcWalkCombat(CPlayerPed *, CPad) {}`
beside its other walk stubs first.

Run: `cd reVC/utils && python3 test_vc_playerwalk.py && python3 test_vc_aimwalk.py && python3 test_vc_cop_pistol.py`
Expected: PASS.

Run: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f" || exit 1; done`
Expected: every harness PASS.

### Task B2: Slice B delivery

**Files:**
- Modify: `docs/architecture.md` (counts)
- Create: `docs/handoff/2026-11-15-npc-player-walk-b.md`

- [ ] **Step 1: Update the architecture doc counts**

Run: `wc -l src/peds/PlayerPed.cpp src/extras/vcmodnpcwalk.cpp` and `grep -c "VCMod" src/peds/PlayerPed.cpp`; write the numbers into the player-glue paragraph.

- [ ] **Step 2: Build, install, verify**

Run from the workspace root: `scripts/build.sh`, then `pgrep -f "reVC.app/Contents/MacOS/reVC"` (must print nothing), then `scripts/install.sh`, then the `strings` build-number check. Expected: a number newer than slice A's.

- [ ] **Step 3: Write the handoff**

Create `docs/handoff/2026-11-15-npc-player-walk-b.md` with the slice-A handoff fields plus the slice-B play steps: a gunfight as a gang body and a cop body with the keys held while he fires; a fist fight; the row off must match BECOME NPC. Paste-ready prompt starts slice C.

Do not commit.

---

## Slice C — edge states

### Task C1: The ring talk walk-away and the inventory

**Files:**
- Modify: `src/extras/vcmodganggroup.h` (declare `VCModGangGroupWalkAway`)
- Modify: `src/extras/vcmodganggroup.cpp` (the reason parameter and the new entry point)
- Modify: `src/extras/vcmodnpcwalk.cpp` (call it on a chat walk)
- Modify: `utils/test_vc_playerwalk.py` (stubs, fixture assertions and inventory tests)
- Modify: `utils/test_vc_ganggroup.py` (the compiled `StopChat` call takes the reason)

**Interfaces:**
- Consumes: `VCModGangGroupPlayerTalking(CPlayerPed *)` (existing).
- Produces: `void VCModGangGroupWalkAway(CPlayerPed *player)` — breaks the ring talk with the `walked away` reason; a no-op when the player is not talking.

- [ ] **Step 1: Add the failing tests**

In `utils/test_vc_playerwalk.py`, add `PED_CHAT` to the stub state enum and add the gang stubs before `static int failed`:

```cpp
enum ePedState { PED_IDLE, PED_ATTACK, PED_AIM_GUN, PED_FIGHT, PED_CHAT };
```

```cpp
int gangTalking, gangWalkAway;
bool VCModGangGroupPlayerTalking(CPlayerPed *) { return gangTalking != 0; }
void VCModGangGroupWalkAway(CPlayerPed *) { ++gangWalkAway; }
```

Append to `MAIN` before `printf`:

```cpp
    p.m_nPedState = PED_CHAT;
    gangTalking = 1; gangWalkAway = 0;
    VCModNpcWalkMove(&p, &pad);
    CHECK(gangWalkAway == 1, "a walk away from the ring ends its talk");
    gangTalking = 0;
    VCModNpcWalkMove(&p, &pad);
    CHECK(gangWalkAway == 1, "no ring, no break");
```

Append a new test class before `if __name__ == "__main__":`:

```python
class SliceCInventory(unittest.TestCase):
    def test_the_ring_talk_breaks_on_a_walk(self):
        walk = WALK.read_text()
        self.assertIn("VCModGangGroupWalkAway(player)", walk)
        gangs = (ROOT / "src/extras/vcmodganggroup.cpp").read_text()
        self.assertIn('"walked away"', gangs)
        header = (ROOT / "src/extras/vcmodganggroup.h").read_text()
        self.assertIn("void VCModGangGroupWalkAway(CPlayerPed *player);", header)

    def test_the_stock_edges_stay_stock(self):
        text = PLAYER.read_text()
        # a seat owns the pose before any input path
        self.assertLess(text.index("if (VCModSitting())\n\t\treturn;"), text.index("switch (m_nPedState)"))
        # car entry cancels on a keypress exactly as it always has
        car = block(text, "case PED_SEEK_CAR:", "case PED_JUMP:")
        self.assertIn("RestorePreviousObjective();", car)
        self.assertIn("GetLeftStickXJustDown()", car)
        # a jump runs the player's own control, no gate needed
        jump = block(text, "case PED_JUMP:", "case PED_FALL:")
        self.assertIn("PlayerControlZelda(padUsed)", jump)
        # a plain idle already walks under the player's own control
        combat = block(text, "case PED_ANSWER_MOBILE:", "case PED_WANDER_PATH:")
        self.assertIn("PlayerControlZelda(padUsed)", combat)
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py`
Expected: FAIL, undeclared `VCModGangGroupWalkAway` in the fixture and the missing `walked away` string.

- [ ] **Step 3: Add the walk-away entry point**

In `src/extras/vcmodganggroup.h`, after `VCModGangGroupPlayerTalking`:

```cpp
// a WASD MOVE walk away from the ring: the same break the row's second press
// makes, with its own reason in the log
void VCModGangGroupWalkAway(CPlayerPed *player);
```

In `src/extras/vcmodganggroup.cpp`, change the static's signature and log:

```cpp
static void
VCModGangGroupStopChat(CPlayerPed *player, uint32 now, const char *why)
```

and the final log line to:

```cpp
	fprintf(stderr, "VCMOD gang group: the talk breaks (%s)\n", why);
```

Update the menu call site:

```cpp
		VCModGangGroupStopChat(player, CTimer::GetTimeInMilliseconds(), "menu");
```

Add after the static:

```cpp
void
VCModGangGroupWalkAway(CPlayerPed *player)
{
	if (!VCModGangGroupPlayerTalking(player))
		return;
	VCModGangGroupStopChat(player, CTimer::GetTimeInMilliseconds(), "walked away");
}
```

In `utils/test_vc_ganggroup.py`, the compiled fixture calls the static directly; pass the reason:

```cpp
    VCModGangGroupStopChat(&tommy, 5000, "menu");
```

- [ ] **Step 4: Call it from the module**

In `src/extras/vcmodnpcwalk.cpp`, add `#include "vcmodganggroup.h"` after `#include "vcmodnpc.h"`, and change `VCModNpcWalkMove` to:

```cpp
void
VCModNpcWalkMove(CPlayerPed *player, CPad *pad)
{
	// walking out of the ring's talk ends it; the stock menu press is unchanged
	if (player->m_nPedState == PED_CHAT && VCModGangGroupPlayerTalking(player))
		VCModGangGroupWalkAway(player);
	VCModNpcWalkEndPoseWait(player);
	player->PlayerControlZelda(pad);
}
```

- [ ] **Step 5: Run the harness and the suite**

Run: `cd reVC/utils && python3 test_vc_playerwalk.py && python3 test_vc_ganggroup.py`
Expected: PASS.

Run: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f" || exit 1; done`
Expected: every harness PASS.

### Task C2: Slice C delivery and the session handoff

**Files:**
- Modify: `docs/architecture.md` (counts)
- Create: `docs/handoff/2026-11-15-npc-player-walk.md`

- [ ] **Step 1: Update the architecture doc counts**

Run: `wc -l src/peds/PlayerPed.cpp src/extras/vcmodnpcwalk.cpp src/extras/vcmodganggroup.cpp` and `grep -c "VCMod" src/peds/PlayerPed.cpp`; write the numbers into the player-glue paragraph.

- [ ] **Step 2: Build, install, verify**

Run from the workspace root: `scripts/build.sh`, then `pgrep -f "reVC.app/Contents/MacOS/reVC"` (must print nothing), then `scripts/install.sh`, then the `strings` build-number check. Expected: a number newer than slice B's.

- [ ] **Step 3: Write the session handoff**

Create `docs/handoff/2026-11-15-npc-player-walk.md` with: repo/branch/HEAD, the installed build number, what is uncommitted (the whole feature plus the spec and this plan), a full play pass (all three profiles via TYPE FROM BODY, the four free states, combat steering, ring talk, car break, row off matching BECOME NPC), open questions from play, and a paste-ready prompt for the next session.

Do not commit.

---

## Self-Review

- Spec coverage: the gate (A1), free-walk states and wait rule (A2), combat steering and targeting lock (B1), ring talk walk-away and stock edge inventory (C1), delivery and play per slice (A3/B2/C2). Worn-skin behaviour is untouched by design and needs no task; the mode's breaks are pinned by the C1 inventory test.
- Placeholder scan: no TBD/TODO; every step carries its code or command.
- Type consistency: `bVCModNpcPlayerWalk`, `VCModNpcPlayerWalks`, `VCModNpcWalkInput`, `VCModNpcWalkMove`, `VCModNpcWalkCombat`, `VCModGangGroupWalkAway` are used with the same signatures in every task and in the harness stubs.
