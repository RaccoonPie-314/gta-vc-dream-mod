# NPC-mode stock combat Implementation Plan

Work through the tasks in order; every step is a checkbox. Each slice ends with
a build, an install and a play check before the next slice starts.

**Goal:** While BECOME NPC runs, make the player ped fight, shoot and take damage exactly as a ped of the worn body, with one predicate (`VCModNpcFightsAsPed`) gating every player-only combat branch.

**Architecture:** Add the predicate in `vcmodnpc` and one chooser seam in `vcmodcombat`; flip the player branches in `PedFight.cpp` and `PedAI.cpp` to the ped path when the predicate is true. The COP profile starts borrowing the worn body's pedstat and threat row. Delivered in three playable slices: A melee + profile, B guns, C receiving.

**Tech Stack:** reVC C++ (C++98-compatible engine), Python 3 harnesses in `reVC/utils`, CMake via `scripts/build.sh`.

**Spec:** `docs/specs/2026-11-15-npc-stock-combat-design.md`

## Global Constraints

- Feature off is stock, byte for byte: every flip is a predicate branch; no new runtime flag is added.
- Engine files (`src/peds/`, `src/core/`) get hook calls and one-line branches only; feature logic lives in `src/extras/vcmod*.{cpp,h}`.
- Naming follows rule 17: `VCModNpcFightsAsPed`, `VCModCombatChooseMove`, `VCModNpcWepAccuracy`; state prefixes `b`/`n`/`f`/`a`.
- `CPlayerPed::ProcessControl` order is untouched: adrenaline → reconcile → apply-default → ride → sit → street → npc → keys/latch → never-wanted.
- Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty; never install over a running session.
- Run the whole suite, not only the touched harness: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`.
- Do not commit, tag or push unless the user asks. The handoff records what is uncommitted.
- One installed build per slice; the user plays before the next slice starts.
- The installed binary must report the new build number before the slice is handed off.

---

## Slice A — melee fight and profile

### Task A1: The predicate

**Files:**
- Modify: `src/extras/vcmodnpc.h` (after `VCModNpcCombatActive`)
- Modify: `src/extras/vcmodnpc.cpp` (after `VCModNpcCombatActive`, currently line 221)
- Create: `utils/test_vc_npccombat.py`

**Interfaces:**
- Produces: `bool VCModNpcFightsAsPed(CPed *ped)` — true only for the player ped while `bVCModNpcMode` is on.

- [ ] **Step 1: Create the harness with the failing predicate test**

Create `utils/test_vc_npccombat.py`:

```python
#!/usr/bin/env python3
"""NPC-mode combat takes the worn ped's path: predicate, move chooser, stock
accuracy, cop pistol clip. Decision functions are compiled against stubs; the
engine side is pinned by wiring checks."""
import pathlib
import unittest

from vcmod_test_support import braced, run_cpp

ROOT = pathlib.Path(__file__).resolve().parents[1]
NPC = (ROOT / "src/extras/vcmodnpc.cpp").read_text()
COMBAT = (ROOT / "src/extras/vcmodcombat.cpp").read_text()
PEDFIGHT = (ROOT / "src/peds/PedFight.cpp").read_text()
PEDAI = (ROOT / "src/peds/PedAI.cpp").read_text()
COPPED = (ROOT / "src/peds/CopPed.cpp").read_text()

STUBS = r'''
#include <cstdio>
#include <cstdint>
#define nil NULL
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
typedef int8_t int8; typedef uint8_t uint8; typedef int16_t int16;
typedef uint16_t uint16; typedef int32_t int32; typedef uint32_t uint32;

enum { MI_COP = 1, MI_SWAT, MI_FBI, MI_ARMY, MI_VICE1, MI_VICE2, MI_VICE3,
       MI_VICE4, MI_VICE5, MI_VICE6, MI_VICE7, MI_VICE8, MI_MALE01 };
enum { VCMOD_NPC_GANG, VCMOD_NPC_CIVILIAN, VCMOD_NPC_COP };
enum { WEAPONFLAG_COP3_RD = 1 << 18 };
enum { FIGHTMOVE_NULL = 0, FIGHTMOVE_ROUNDHOUSE = 9 };

bool bVCModNpcMode;
bool bVCModCopPistol;
int32 nVCModNpcType;
bool bVCModNpcAutoType;
int32 nVCModNpcTypeStub;

struct CWeaponInfo {
    int flags;
    CWeaponInfo() : flags(0) {}
    bool IsFlagSet(int f) { return (flags & f) != 0; }
};
struct CPed {
    bool player;
    int16 model;
    int aiCalls, playerCalls;
    bool IsPlayer() { return player; }
    int16 GetModelIndex() { return model; }
    int32 ChooseAttackAI(uint8, bool) { ++aiCalls; return 1; }
    int32 ChooseAttackPlayer(uint8, bool) { ++playerCalls; return 2; }
};
struct CPlayerPed : CPed {};
int32 VCModNpcEffectiveType(void) { return nVCModNpcTypeStub; }
bool VCModNpcCopActive(void) { return bVCModNpcMode && VCModNpcEffectiveType() == VCMOD_NPC_COP; }
static int32 nVCModForcedFightMove = FIGHTMOVE_NULL;

static int failed = 0;
#define CHECK(c, m) do { if (!(c)) { printf("FAIL: %s\n", m); failed++; } } while (0)
'''

MAIN = r'''
int main() {
    CPlayerPed p; p.player = true; p.model = MI_MALE01;
    bVCModNpcMode = false;
    CHECK(!VCModNpcFightsAsPed(&p), "mode off keeps the player");
    bVCModNpcMode = true;
    CHECK(VCModNpcFightsAsPed(&p), "mode on fights as the ped");
    CPed q; q.player = false;
    CHECK(!VCModNpcFightsAsPed(&q), "a native ped is not the player");
    CHECK(!VCModNpcFightsAsPed(nil), "nil is not the player");
    return failed != 0;
}
'''


def source(functions):
    return STUBS + "\n".join(braced(NPC + "\n" + COMBAT, f) for f in functions) + MAIN


class PredicateTests(unittest.TestCase):
    def test_fights_as_ped(self):
        run_cpp(source(["bool\nVCModNpcFightsAsPed(CPed *ped)"]))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL — `VCModNpcFightsAsPed` not found / assertion.

- [ ] **Step 3: Implement the predicate**

In `src/extras/vcmodnpc.h` after `VCModNpcCombatActive`:

```cpp
// true when this ped is the player and NPC mode owns his combat: every engine
// branch that exists for a human trigger takes the ped path on this answer
bool VCModNpcFightsAsPed(CPed *ped);
```

In `src/extras/vcmodnpc.cpp` after `VCModNpcCombatActive`:

```cpp
bool
VCModNpcFightsAsPed(CPed *ped)
{
	return ped != nil && ped->IsPlayer() && bVCModNpcMode;
}
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS (1 test).

---

### Task A2: The move chooser seam

**Files:**
- Modify: `src/extras/vcmodcombat.h` (after `VCModCombatClearFightMove`)
- Modify: `src/extras/vcmodcombat.cpp` (after `VCModCombatClearFightMove`, currently line 448)
- Modify: `src/peds/PedFight.cpp` (`StartFightAttack` 1195, `Fight` 1631, `ChooseAttackPlayer` 1804-1807)
- Modify: `utils/test_vc_npccombat.py`, `utils/test_vc_combat.py`

**Interfaces:**
- Consumes: `VCModNpcFightsAsPed`, `VCModCombatTakeFightMove`.
- Produces: `int32 VCModCombatChooseMove(CPed *ped, int32 buttonPressure, bool fightWithWeapon)`.

- [ ] **Step 1: Extend the harness with the failing chooser cases**

In `test_vc_npccombat.py`, replace `MAIN` with the predicate + chooser cases:

```python
MAIN = r'''
int main() {
    CPlayerPed p; p.player = true; p.model = MI_MALE01;
    bVCModNpcMode = false;
    CHECK(!VCModNpcFightsAsPed(&p), "mode off keeps the player");
    bVCModNpcMode = true;
    CHECK(VCModNpcFightsAsPed(&p), "mode on fights as the ped");
    CPed q; q.player = false;
    CHECK(!VCModNpcFightsAsPed(&q), "a native ped is not the player");
    CHECK(!VCModNpcFightsAsPed(nil), "nil is not the player");

    nVCModForcedFightMove = FIGHTMOVE_NULL;
    p.aiCalls = p.playerCalls = 0;
    bVCModNpcMode = false;
    CHECK(VCModCombatChooseMove(&p, 200, false) == 2 && p.playerCalls == 1 && p.aiCalls == 0,
          "mode off asks the player chooser");
    bVCModNpcMode = true;
    CHECK(VCModCombatChooseMove(&p, 200, false) == 1 && p.aiCalls == 1,
          "mode on asks the ped chooser");
    VCModCombatRequestFightMove(FIGHTMOVE_ROUNDHOUSE);
    CHECK(VCModCombatChooseMove(&p, 200, false) == FIGHTMOVE_ROUNDHOUSE, "the forced move outranks the chooser");
    CHECK(VCModCombatTakeFightMove() == FIGHTMOVE_NULL, "choosing consumed it");
    return failed != 0;
}
'''
```

and the test:

```python
class ChooserTests(unittest.TestCase):
    def test_chooser_priority(self):
        run_cpp(source([
            "bool\nVCModNpcFightsAsPed(CPed *ped)",
            "void\nVCModCombatRequestFightMove(int32 move)",
            "int32\nVCModCombatTakeFightMove(void)",
            "void\nVCModCombatClearFightMove(void)",
            "int32\nVCModCombatChooseMove(CPed *ped, int32 buttonPressure, bool fightWithWeapon)",
        ]))
```

The signature strings must match the real definitions (`RequestFightMove` and `ClearFightMove` return `void`).

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL — `VCModCombatChooseMove` not found.

- [ ] **Step 3: Implement the seam**

In `src/extras/vcmodcombat.h`:

```cpp
// the fight move chooser: the forced-move slot first (the spin kick command),
// then the ped chooser while NPC mode owns the body, the player chooser
// otherwise. Taking the slot here (not inside ChooseAttackPlayer) keeps the
// one-shot request working for both choosers.
int32 VCModCombatChooseMove(CPed *ped, int32 buttonPressure, bool fightWithWeapon);
```

In `src/extras/vcmodcombat.cpp` after `VCModCombatClearFightMove`:

```cpp
int32
VCModCombatChooseMove(CPed *ped, int32 buttonPressure, bool fightWithWeapon)
{
	int32 forcedMove = VCModCombatTakeFightMove();
	if (forcedMove != FIGHTMOVE_NULL)
		return forcedMove;
	if (VCModNpcFightsAsPed(ped))
		return ped->ChooseAttackAI((uint8)buttonPressure, fightWithWeapon);
	return ped->ChooseAttackPlayer((uint8)buttonPressure, fightWithWeapon);
}
```

In `src/peds/PedFight.cpp`:

- `StartFightAttack` line 1195:
```cpp
	m_curFightMove = VCModCombatChooseMove(this, buttonPressure, fightWithWeapon);
```
- `Fight` line 1631:
```cpp
		m_curFightMove = VCModCombatChooseMove(this, m_fightButtonPressure, fightWithWeapon);
```
- `ChooseAttackPlayer` 1804-1807: delete the forced-move take:
```cpp
	// the request is one-shot: taking it is what empties the slot
	int32 forcedMove = VCModCombatTakeFightMove();
	if (forcedMove != FIGHTMOVE_NULL)
		return (PedFightMoves)forcedMove;
```

- [ ] **Step 4: Update `test_vc_combat.py`'s engine wiring check**

Add `from vcmod_test_support import braced` next to the existing imports, then add to `CombatModuleTests`:

```python
    def test_the_chooser_seam_replaces_the_player_branch(self):
        fight = PEDFIGHT.read_text()
        self.assertEqual(fight.count("VCModCombatChooseMove(this,"), 2)
        self.assertNotIn("IsPlayer() ? ChooseAttackPlayer(", fight)
        player = braced(fight, "CPed::ChooseAttackPlayer(uint8 buttonPressure, bool fightWithWeapon)")
        self.assertNotIn("VCModCombatTakeFightMove", player)
```

- [ ] **Step 5: Run both harnesses**

Run: `cd reVC/utils && python3 test_vc_npccombat.py && python3 test_vc_combat.py`
Expected: PASS.

---

### Task A3: Melee entry and SetAttack gates

**Files:**
- Modify: `src/peds/PedFight.cpp` (`SetAttack` 316-436, `ClearAttack` 504)
- Modify: `utils/test_vc_npccombat.py`

**Interfaces:**
- Consumes: `VCModNpcFightsAsPed`.

- [ ] **Step 1: Add the failing wiring test**

In `test_vc_npccombat.py`:

```python
class SliceAWiring(unittest.TestCase):
    def test_setattack_takes_the_ped_melee_path(self):
        setattack = braced(PEDFIGHT, "CPed::SetAttack(CEntity *victim)")
        self.assertGreaterEqual(setattack.count("VCModNpcFightsAsPed(this)"), 7)
        self.assertNotIn("IsPlayer() && !VCModNpcGangActive()", setattack)

    def test_clearattack_takes_the_ped_duck_gate(self):
        clearattack = braced(PEDFIGHT, "CPed::ClearAttack(void)")
        self.assertIn("VCModNpcFightsAsPed(this)", clearattack)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL — predicate count 0 / old gang gate present.

- [ ] **Step 3: Flip the branches**

In `CPed::SetAttack`:

1. Reload continuation:
```cpp
		if (!IsPlayer() || VCModNpcFightsAsPed(this) || m_nPedState != PED_ATTACK || ((CPlayerPed*)this)->m_bHaveTargetSelected)
```
2. Melee entry:
```cpp
		if ((IsPlayer() && !VCModNpcFightsAsPed(this)) ||
			(m_nPedState != PED_FIGHT && m_nMoveState != PEDMOVE_NONE && m_nMoveState != PEDMOVE_STILL
				&& !(m_pedStats->m_flags & STAT_SHOPPING_BAGS) && curWeapon->IsFlagSet(WEAPONFLAG_PARTIALATTACK))) {
```
3. Partial attack while moving:
```cpp
	if (curWeapon->IsFlagSet(WEAPONFLAG_PARTIALATTACK) &&
		(IsPlayer() && !VCModNpcFightsAsPed(this) && ((CPlayerPed*)this)->m_fMoveSpeed >= 1.0f ||
		m_nMoveState == PEDMOVE_WALK || m_nMoveState == PEDMOVE_RUN)) {
```
4. Obstacle during a kill objective:
```cpp
				if (!IsPlayer() || VCModNpcFightsAsPed(this)) {
```
5. Aim from the camera rotation (inner check):
```cpp
			if (this == FindPlayerPed() && !VCModNpcFightsAsPed(this) && TheCamera.Cams[0].Using3rdPersonMouseCam()) {
```
and the `FIX_BUGS` flamethrower branch:
```cpp
	else if (curWeapon->m_AnimToPlay == ASSOCGRP_FLAMETHROWER && TheCamera.Cams[0].Using3rdPersonMouseCam() && this == FindPlayerPed() && !VCModNpcFightsAsPed(this))
```
6. Aim-start gate:
```cpp
	if ((IsPlayer() && !VCModNpcFightsAsPed(this)) || (!victimPed || victimPed->IsPedInControl())) {
```
7. Point-blank start:
```cpp
			if (pointBlankStatus == POINT_BLANK_FOR_WANTED_PED || !victimPed && (IsPlayer() && !VCModNpcFightsAsPed(this) || !m_carInObjective))
```

In `CPed::ClearAttack`:

```cpp
	if (m_nPedState != PED_ATTACK || (bIsDucking && (!IsPlayer() || VCModNpcFightsAsPed(this))) || m_nWaitState == WAITSTATE_PLAYANIM_DUCK)
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

- [ ] **Step 5: Stub the predicate in the harnesses that compile SetAttack**

`test_vc_cop_pistol.py` compiles `CPed::SetAttack` and `test_vc_ganggaze.py`
compiles its tail. Add to each harness's stub block, after `CPed` is defined:

```cpp
bool bVCModNpcMode = false;
bool VCModNpcFightsAsPed(CPed *ped) { return ped->IsPlayer() && bVCModNpcMode; }
```

`test_vc_ganggaze.py` already declares `bVCModNpcMode = true` for its mode tests,
so add only the predicate there.

Run: `cd reVC/utils && python3 test_vc_cop_pistol.py && python3 test_vc_ganggaze.py`
Expected: PASS.

---

### Task A4: StartFightAttack and Fight take the ped state

**Files:**
- Modify: `src/peds/PedFight.cpp` (`StartFightAttack` 1229/1241, `Fight` 1528-1711)
- Modify: `utils/test_vc_npccombat.py`

- [ ] **Step 1: Add the failing wiring test**

```python
    def test_fight_keeps_the_ped_state_in_npc_mode(self):
        fight = braced(PEDFIGHT, "CPed::Fight(void)")
        self.assertGreaterEqual(fight.count("VCModNpcFightsAsPed(this)"), 9)
        self.assertNotIn("if (!bIsAttacking && IsPlayer()) {", fight)

    def test_startfightattack_skips_the_player_timing(self):
        start = braced(PEDFIGHT, "CPed::StartFightAttack(uint8 buttonPressure, PedFightMoves forceMove)")
        self.assertIn("if (IsPlayer() && !VCModNpcFightsAsPed(this))", start)
        self.assertIn("VCModCombatChooseMove(this,", start)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Flip the branches**

In `CPed::StartFightAttack`:

```cpp
		if (IsPlayer() && !VCModNpcFightsAsPed(this))
			animAssoc->SetCurrentTime(0.08f);
```
and
```cpp
	if (IsPlayer() && !VCModNpcFightsAsPed(this))
		nPlayerInComboMove = 0;
```

In `CPed::Fight`:

1. Katana streak:
```cpp
	if (IsPlayer() && !VCModNpcFightsAsPed(this) && currentAssoc && weapon == WEAPONTYPE_KATANA) {
```
2. Immediate end:
```cpp
	if (!bIsAttacking && IsPlayer() && !VCModNpcFightsAsPed(this)) {
```
3. Melee start sound:
```cpp
				if (animTime > curMove.startFireTime && animTime - currentAssoc->timeStep < curMove.startFireTime &&
					(IsPlayer() && !VCModNpcFightsAsPed(this) || weapon != WEAPONTYPE_UNARMED)) {
```
4. Anim speed:
```cpp
				if (IsPlayer() && !VCModNpcFightsAsPed(this))
					currentAssoc->speed = 1.0f;
				else
					currentAssoc->speed = 0.8f;
```
5. Combo chain:
```cpp
				if (IsPlayer() && !VCModNpcFightsAsPed(this) && !nPlayerInComboMove && !fightWithWeapon) {
```
6. Attack voice:
```cpp
			if (!IsPlayer() || VCModNpcFightsAsPed(this))
				Say(SOUND_PED_ATTACK);
```
7. Re-chosen move start:
```cpp
				if (!IsPlayer() || VCModNpcFightsAsPed(this))
					animAssoc->SetCurrentTime(0.0f);
			}
			if (IsPlayer() && !VCModNpcFightsAsPed(this))
				animAssoc->SetCurrentTime(0.08f);
```
8. Wait timer:
```cpp
			if (IsPlayer() && !VCModNpcFightsAsPed(this))
				m_nWaitTimer = CTimer::GetTimeInMilliseconds() + 500;
			else
				m_nWaitTimer = CTimer::GetTimeInMilliseconds() + 2000;
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

---

### Task A5: Outgoing melee damage

**Files:**
- Modify: `src/peds/PedFight.cpp` (`FightStrike` 2174, `FightHitPed` 2270/2345/2368)
- Modify: `utils/test_vc_npccombat.py`

- [ ] **Step 1: Add the failing wiring test**

```python
    def test_melee_damage_uses_the_ped_strength(self):
        hit = braced(PEDFIGHT, "CPed::FightHitPed(CPed *victim, CVector &touchPoint, CVector &dir, int16 piece)")
        self.assertIn("VCModNpcFightsAsPed(this)", hit)
        self.assertIn("m_pedStats->m_attackStrength", hit)
        self.assertNotIn("if (IsPlayer()) {\n\t\tif (((CPlayerPed*)this)->m_bAdrenalineActive)", hit)

    def test_player_only_melee_vfx_is_off_in_npc_mode(self):
        hit = braced(PEDFIGHT, "CPed::FightHitPed(CPed *victim, CVector &touchPoint, CVector &dir, int16 piece)")
        self.assertIn("IsPlayer() && !VCModNpcFightsAsPed(this)", hit)
        strike = braced(PEDFIGHT, "CPed::FightStrike(CVector &touchedNodePos, bool fightWithWeapon)")
        self.assertIn("VCModNpcFightsAsPed(this)", strike)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Flip the damage path**

`CPed::FightHitPed`:

```cpp
	if (IsPlayer() && ((CPlayerPed*)this)->m_bAdrenalineActive) {
		// the pill is a deliberate power-up and outranks the body's strength
		damageMult = 20;
	} else if (!IsPlayer() || VCModNpcFightsAsPed(this)) {
		if (!fightingWithWeapon)
			damageMult *= m_pedStats->m_attackStrength;
	}
```

Extra blood particles:
```cpp
		if (IsPlayer() && !VCModNpcFightsAsPed(this)) {
			CParticle::AddParticle(PARTICLE_BLOOD_SPURT, bloodPos, dir, nil, 0.0f, 0, 0, 0, 0);
			CParticle::AddParticle(PARTICLE_BLOOD_SPURT, bloodPos, dir, nil, 0.0f, 0, 0, 0, 0);
		}
```

Knockdown rule:
```cpp
					|| weaponType != WEAPONTYPE_UNARMED && weaponType != WEAPONTYPE_BRASSKNUCKLE && IsPlayer() && !VCModNpcFightsAsPed(this)
```

`CPed::FightStrike`:
```cpp
	if (this == FindPlayerPed() && !VCModNpcFightsAsPed(this) && fightWithWeapon && GetWeapon()->m_eWeaponType != WEAPONTYPE_UNARMED)
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

---

### Task A6: The engine owns the fight state; bump shoves return

**Files:**
- Modify: `src/extras/vcmodcombat.cpp` (`VCModNpcCombatControl` 501-570)
- Modify: `src/peds/PedFight.cpp` (`CollideWithPed` 3631)
- Modify: `utils/test_vc_ganggaze.py`

- [ ] **Step 1: Update the ganggaze tests to the new ownership**

In `utils/test_vc_ganggaze.py`, in the profile loop test, replace the `fightStarts` expectation with:

```python
        for (int profile = VCMOD_NPC_GANG; profile <= VCMOD_NPC_COP; ++profile) {
            bVCModNpcMode = true;
            nVCModNpcType = profile;
            tommy.m_nPedState = PED_ATTACK;
            tommy.m_objective = OBJECTIVE_KILL_CHAR_ON_FOOT;
            tommy.m_pedInObjective = &target;
            tommy.m_attackTimer = 0;
            int starts = tommy.fightStarts;
            tommy.Control();
            CHECK(tommy.fightStarts == starts);   // the module never presses the fight button
        }
        CHECK(playerControls == 0);               // the state is owned; the input path stays out
```

Replace `test_melee_attack_takes_the_ped_path_in_npc_mode` with:

```python
    def test_the_module_keeps_no_fight_driver(self):
        control = braced(COMBAT, "VCModNpcCombatControl(CPlayerPed *player, bool npcCombatOwnsControl)")
        for call in ("StartFightAttack", "SetAttackTimer", "ClearAttack", "EndFight"):
            self.assertNotIn(call, control)
```

Replace `test_melee_attack_state_starts_the_fight` with:

```python
    def test_an_attack_state_is_owned_not_pressed(self):
        self.check(r'''
    nVCModNpcType = VCMOD_NPC_CIVILIAN;
    tommy.m_nPedState = PED_ATTACK;
    tommy.m_attackTimer = 0;
    tommy.m_objective = OBJECTIVE_KILL_CHAR_ON_FOOT;
    tommy.m_pedInObjective = &target;
    int before = attacks, starts = tommy.fightStarts;
    tommy.Control();
    CHECK(tommy.fightStarts == starts);   // the objective layer calls SetAttack
    CHECK(attacks == before);             // the module never runs the engine driver
    CHECK(playerControls == 0);           // owned: the input path is out
''')
```

Replace `test_attack_state_without_a_target_keeps_the_stock_animation` with:

```python
    def test_a_stray_attack_is_left_to_the_engine_endings(self):
        # melee bump shoves now enter PED_FIGHT through the ped chooser; a gun
        # PED_ATTACK ends in FinishedAttackCB -> ClearAttack. The module owning
        # the state is what keeps the stock ending in charge.
        self.check(r'''
    nVCModNpcType = VCMOD_NPC_CIVILIAN;
    target.m_nPedState = PED_GETUP;
    tommy.m_nPedState = PED_ATTACK;
    tommy.m_attackTimer = 0;
    tommy.m_pedInObjective = &target;
    tommy.m_objective = OBJECTIVE_NONE;
    int starts = tommy.fightStarts;
    tommy.Control();
    CHECK(tommy.attacksCleared == 0);   // the module does not cut it
    CHECK(tommy.fightsEnded == 0);
    CHECK(tommy.fightStarts == starts);
    CHECK(playerControls == 0);         // owned; FinishedAttackCB clears on the animation end
''')
```

Add:

```python
    def test_finished_attack_still_ends_a_stray(self):
        cb = braced(FIGHT, "CPed::FinishedAttackCB(CAnimBlendAssociation *attackAssoc, void *arg)")
        self.assertIn("ped->ClearAttack();", cb)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_ganggaze.py`
Expected: FAIL — the module still compiles the old driver into the test source and `test_the_module_keeps_no_fight_driver` fails.

- [ ] **Step 3: Simplify `VCModNpcCombatControl`**

Replace the body with:

```cpp
bool
VCModNpcCombatControl(CPlayerPed *player, bool npcCombatOwnsControl)
{
	bool npcCombatProfile = VCModNpcGangActive() || VCModNpcCopActive() || VCModNpcCivilianActive();
	if (npcCombatProfile && (player->m_nPedState == PED_ATTACK || player->m_nPedState == PED_FIGHT
		|| player->m_nPedState == PED_AIM_GUN || (player->m_nPedState == PED_IDLE && npcCombatOwnsControl))) {
		// every combat state in NPC mode is entered by the engine's AI: the
		// player's input attack is skipped and the objective layer calls
		// SetAttack itself. A manual re-press or a stray cleanup here would
		// fight that cadence, and clearing a stray would cut a bump scuffle
		// short; the engine's own FinishedAttackCB/Fight endings own the exit.
		if (player->m_nPedState == PED_ATTACK) {
			// temporary probe (DIAGNOSTICS): a gunfight that never puts a round
			// in the air names the weapon's own state
			static uint32 nFireDiag = 0;
			uint32 now = CTimer::GetTimeInMilliseconds();
			if (now >= nFireDiag) {
				nFireDiag = now + 1000;
				CWeapon *wep = player->GetWeapon();
				VCMOD_DIAG("VCMOD combat: state=%d wep=%d clip=%d total=%d wstate=%d attacking=%d shoot=%d gun=%d look=%d obj=%d\n",
					player->m_nPedState, wep->m_eWeaponType, wep->m_nAmmoInClip,
					wep->m_nAmmoTotal, wep->m_eWeaponState, (int)player->bIsAttacking,
					(int32)(player->m_shootTimer - now), player->m_pPointGunAt != nil,
					player->m_pLookTarget != nil, player->m_objective);
			}
		} else if (player->m_nPedState == PED_IDLE) {
			player->m_fMoveSpeed = 0.0f;
			player->m_nStoredMoveState = player->m_nMoveState;
			player->SetRealMoveAnim();
		}
		return true;
	}
	return false;
}
```

- [ ] **Step 4: Remove the NPC bump bypass**

In `CPed::CollideWithPed`, delete the line:

```cpp
								// NPC mode has no attack input to end a bump shove,
								// so the 250-450 ms retry becomes a shove loop; he
								// walks around instead, as the polite branch does
								|| (IsPlayer() && VCModNpcCombatActive())
```

- [ ] **Step 5: Run the harness**

Run: `cd reVC/utils && python3 test_vc_ganggaze.py`
Expected: PASS.

---

### Task A7: The COP profile borrows its body

**Files:**
- Modify: `src/extras/vcmodnpc.cpp` (`VCModNpcBorrowIdentity` 371-409, call site 562-564)
- Modify: `utils/test_vc_npcmode.py`

- [ ] **Step 1: Update the harness extraction and add the failing test**

In `utils/test_vc_npcmode.py`, change the SIGS entry:

```python
    "static void\nVCModNpcBorrowIdentity(CPlayerPed *player, bool civilianWander, bool gangWander, bool copWander)",
```

Add a COP threat row to the `CPedType::GetThreats` stub before the final return:

```cpp
        if (type == PEDTYPE_COP)
            return PED_FLAG_GUN | PED_FLAG_EXPLOSION | PED_FLAG_DEADPEDS;
```

Add the test:

```python
    def test_cop_wander_borrows_the_body_personality(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_COP", state="PED_WANDER_PATH") + r'''
    bVCModStreetWander = true;
    p.m_modelIndex = MI_COP;
    CPedStats *own = p.m_pedStats;
    uint32 ownThreats = p.m_fearFlags;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_COP]) return 1;  // the cop body's stat
    if (p.m_fearFlags != CPedType::GetThreats(PEDTYPE_COP)) return 2;     // the cop threat row
    if (p.m_headingRate != 5.0f) return 3;                                // the body's turn rate
    bVCModNpcMode = false; bVCModNpcModeWasOn = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != own) return 4;
    if (p.m_fearFlags != ownThreats) return 5;
    if (p.m_headingRate != 15.0f) return 6;
    return 0;
}
''')
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npcmode.py`
Expected: FAIL — compile error on the new signature / assertion.

- [ ] **Step 3: Add the cop borrow**

Change the signature:

```cpp
static void
VCModNpcBorrowIdentity(CPlayerPed *player, bool civilianWander, bool gangWander, bool copWander)
```

Fear row:

```cpp
	player->m_fearFlags = CPedType::GetThreats(civilianWander ? PEDTYPE_CIVMALE
		: gangWander ? gangType : copWander ? PEDTYPE_COP : player->m_nPedType);
```

Borrowed stats:

```cpp
	else if (civilianWander)
		borrowedStats = VCModNpcCivilianBodyStats(player);
	else if (copWander)
		borrowedStats = VCModNpcBodyStats(player);
```

Call site:

```cpp
	bool bCivilianWander = VCModNpcCivilianActive() && VCModStreetWanderOwnsPlayer();
	bool bGangWander = VCModNpcGangActive() && VCModStreetWanderOwnsPlayer();
	bool bCopWander = VCModNpcCopActive() && VCModStreetWanderOwnsPlayer();
	VCModNpcBorrowIdentity(player, bCivilianWander, bGangWander, bCopWander);
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npcmode.py`
Expected: PASS. If other tests fail on the signature, update their `npc_source()` extraction only; their behaviour is unchanged.

---

### Task A8: Slice A verification, install and handoff

- [ ] **Step 1: Run the whole suite**

Run: `cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`
Expected: 49 harnesses, all pass.

- [ ] **Step 2: Build**

Run: `cd vc-mod && scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`.

- [ ] **Step 3: Confirm the game is closed, then install**

Run: `pgrep -f "reVC.app/Contents/MacOS/reVC"` (must be empty), then `cd vc-mod && scripts/install.sh`.
Confirm the installed build number:

```bash
strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" | grep -m1 '^vcmods build '
```

Expected: the new build number.

- [ ] **Step 4: Hand off for play**

Write the handoff to `docs/handoff/` named with the session's date and the
suffix `-npc-stock-combat-a` (for example `2026-11-16-npc-stock-combat-a.md`):
branch/HEAD, installed build, uncommitted files, what A changed, what to play
(fist fight as a civilian body, then a cop body), and the next slice. Do not
commit unless asked.

---

## Slice B — guns

### Task B1: Stock accuracy

**Files:**
- Modify: `src/extras/vcmodnpc.h` (declare `VCModNpcWepAccuracy`)
- Modify: `src/extras/vcmodnpc.cpp` (add the table + function; replace the accuracy write at line 543)
- Modify: `utils/test_vc_npccombat.py`, `utils/test_vc_npcmode.py`

**Interfaces:**
- Produces: `uint8 VCModNpcWepAccuracy(CPlayerPed *player)`.

- [ ] **Step 1: Add the failing accuracy cases**

In `test_vc_npccombat.py`'s `MAIN`, add after the chooser cases:

```python
    // accuracy: everyone 60, police bodies their CCopPed value
    nVCModNpcTypeStub = VCMOD_NPC_CIVILIAN; p.model = MI_COP;
    CHECK(VCModNpcWepAccuracy(&p) == 60, "a civilian body is 60");
    nVCModNpcTypeStub = VCMOD_NPC_COP;
    p.model = MI_COP;   CHECK(VCModNpcWepAccuracy(&p) == 60, "street cop 60");
    p.model = MI_SWAT;  CHECK(VCModNpcWepAccuracy(&p) == 68, "swat 68");
    p.model = MI_FBI;   CHECK(VCModNpcWepAccuracy(&p) == 76, "fbi 76");
    p.model = MI_ARMY;  CHECK(VCModNpcWepAccuracy(&p) == 84, "army 84");
    p.model = MI_VICE4; CHECK(VCModNpcWepAccuracy(&p) == 76, "vice 76");
    p.model = MI_MALE01; CHECK(VCModNpcWepAccuracy(&p) == 60, "a non-cop body in the cop profile is 60");
```

The extracted function needs the real static table, which `braced` cannot cut
(its first brace is the `struct`). Add a table slicer to the harness and teach
`source()` to include it:

```python
def cop_accuracy_table():
    start = NPC.index("static const struct { int16 model; uint8 accuracy; } aVCModNpcCopAccuracy[]")
    end = NPC.index("};", start) + 2
    return NPC[start:end]


def source(functions):
    table = cop_accuracy_table() + "\n" if any("VCModNpcWepAccuracy" in f for f in functions) else ""
    return STUBS + table + "\n".join(braced(NPC + "\n" + COMBAT, f) for f in functions) + MAIN
```

Add a test method:

```python
class AccuracyTests(unittest.TestCase):
    def test_stock_accuracy_table(self):
        run_cpp(source([
            "bool\nVCModNpcFightsAsPed(CPed *ped)",
            "void\nVCModCombatRequestFightMove(int32 move)",
            "int32\nVCModCombatTakeFightMove(void)",
            "void\nVCModCombatClearFightMove(void)",
            "int32\nVCModCombatChooseMove(CPed *ped, int32 buttonPressure, bool fightWithWeapon)",
            "uint8\nVCModNpcWepAccuracy(CPlayerPed *player)",
        ]))
```

In `test_vc_npcmode.py`, add `m_wepAccuracy` to the stub `CPlayerPed`, stub the new function, and add:

```python
    def test_npc_mode_writes_the_body_accuracy(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(state="PED_WANDER_PATH") + r'''
    p.m_wepAccuracy = 95;             // normal play's aimable value
    p.m_modelIndex = MI_MALE01;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_wepAccuracy != 60) return 1;   // the ped's stock accuracy
    return 0;
}
''')
```

with the stub:

```cpp
uint8 VCModNpcWepAccuracy(CPlayerPed *) { return 60; }
```

- [ ] **Step 2: Run both harnesses to verify they fail**

Run: `cd reVC/utils && python3 test_vc_npccombat.py; python3 test_vc_npcmode.py`
Expected: FAIL.

- [ ] **Step 3: Implement the accuracy**

`vcmodnpc.h`:

```cpp
// the stock accuracy of the worn body's ped: 60 for every pedestrian and gang
// ped, the police bodies' own CCopPed values while the COP profile runs
uint8 VCModNpcWepAccuracy(CPlayerPed *player);
```

`vcmodnpc.cpp`:

```cpp
// CCopPed's constructor gives each cop type its value; the table is that
// mapping by model, so a cpl body reads the same as the stock cop
static const struct { int16 model; uint8 accuracy; } aVCModNpcCopAccuracy[] = {
	{ MI_COP, 60 }, { MI_SWAT, 68 }, { MI_FBI, 76 }, { MI_ARMY, 84 },
	{ MI_VICE1, 76 }, { MI_VICE2, 76 }, { MI_VICE3, 76 }, { MI_VICE4, 76 },
	{ MI_VICE5, 76 }, { MI_VICE6, 76 }, { MI_VICE7, 76 }, { MI_VICE8, 76 },
};

uint8
VCModNpcWepAccuracy(CPlayerPed *player)
{
	if (VCModNpcEffectiveType() != VCMOD_NPC_COP)
		return 60;
	for (int i = 0; i < ARRAY_SIZE(aVCModNpcCopAccuracy); i++)
		if (player->GetModelIndex() == aVCModNpcCopAccuracy[i].model)
			return aVCModNpcCopAccuracy[i].accuracy;
	return 60;
}
```

Replace the write in `VCModUpdateNpcMode`:

```cpp
	// the body's stock accuracy, not the player's 95/100: the AI fires these
	// shots, so it fires them with the ped's spread. DOOM AIM stays a player row
	player->m_wepAccuracy = VCModNpcWepAccuracy(player);
```

Add a source guard to `test_vc_npccombat.py`:

```python
    def test_accuracy_table_matches_cop_constructor(self):
        for value in ("m_wepAccuracy = 60;", "m_wepAccuracy = 68;",
                      "m_wepAccuracy = 76;", "m_wepAccuracy = 84;"):
            self.assertIn(value, COPPED)
```

- [ ] **Step 4: Run both harnesses**

Run: `cd reVC/utils && python3 test_vc_npccombat.py && python3 test_vc_npcmode.py`
Expected: PASS.

---

### Task B2: Gun gates and player perks

**Files:**
- Modify: `src/peds/PedFight.cpp` (`Attack` 795/818/860/952/1032/1045, `StartReloadNow` 673)
- Modify: `utils/test_vc_npccombat.py`

- [ ] **Step 1: Add the failing wiring test**

```python
    def test_gun_attack_takes_the_ped_path_in_npc_mode(self):
        attack = braced(PEDFIGHT, "CPed::Attack(void)")
        self.assertIn("VCModNpcFightsAsPed(this)", attack)
        self.assertGreaterEqual(attack.count("VCModNpcFightsAsPed(this)"), 5)
        self.assertIn("SelectGunIfArmed", attack)
        reload = braced(PEDFIGHT, "CPed::StartReloadNow(void)")
        self.assertIn("VCModNpcFightsAsPed(this)", reload)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Flip the gun branches**

In `CPed::Attack`:

1. Reload clear:
```cpp
		if (!IsPlayer() || VCModNpcFightsAsPed(this) || ((CPlayerPed*)this)->m_bHaveTargetSelected)
```
2. Melee start flag:
```cpp
					if (IsPlayer() && !VCModNpcFightsAsPed(this))
						meleeAttackStarted = true;
```
3. Projectile start:
```cpp
				if (ourWeapon->m_eWeaponFire != WEAPON_FIRE_PROJECTILE || !IsPlayer() || VCModNpcFightsAsPed(this) || ((CPlayerPed*)this)->m_bHaveTargetSelected) {
```
4. Empty gun:
```cpp
			if (GetWeapon()->m_nAmmoTotal == 0 && ourWeapon->m_eWeaponFire != WEAPON_FIRE_MELEE && (FindPlayerPed() != this || VCModNpcFightsAsPed(this))) {
```
5. Weapon streak:
```cpp
	if (IsPlayer() && !VCModNpcFightsAsPed(this)) {
```
6. Sprint breakout:
```cpp
	if (IsPlayer() && !VCModNpcFightsAsPed(this)) {
```

In `CPed::StartReloadNow`:

```cpp
	bool fast = IsPlayer() && !VCModNpcFightsAsPed(this) && CWorld::Players[CWorld::PlayerInFocus].m_bFastReload;
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

- [ ] **Step 5: Stub the predicate in the harness that compiles Attack**

`test_vc_weapon_recovery.py` compiles `CPed::Attack`. Add to its stub block:

```cpp
bool bVCModNpcMode = false;
bool VCModNpcFightsAsPed(CPed *ped) { return ped->IsPlayer() && bVCModNpcMode; }
```

Run: `cd reVC/utils && python3 test_vc_weapon_recovery.py`
Expected: PASS.

---

### Task B3: Aim handling and the cop pistol clip

**Files:**
- Modify: `src/extras/vcmodcombat.cpp` (`VCModCopTwoHandPose` 41-45, `VCModCopSetStance` 67, `VCModAimWalkWeapon` 264, `VCModCombatAimTick` 321)
- Modify: `src/peds/PedFight.cpp` (`PointGunAt` 214-229)
- Modify: `utils/test_vc_npccombat.py`, `utils/test_vc_combat.py`

- [ ] **Step 1: Add the failing cases**

In `test_vc_npccombat.py`'s `MAIN`, add:

```python
    // the cop pistol clip is the body's, not the row's
    CWeaponInfo cop; cop.flags = WEAPONFLAG_COP3_RD;
    bVCModCopPistol = false;
    bVCModNpcMode = true; nVCModNpcTypeStub = VCMOD_NPC_COP;
    CHECK(VCModCopTwoHandPose(&p, &cop), "an npc cop body keeps the cop clip with the row off");
    nVCModNpcTypeStub = VCMOD_NPC_CIVILIAN;
    CHECK(!VCModCopTwoHandPose(&p, &cop), "a civilian body ignores the row in npc mode");
    bVCModNpcMode = false;
    CHECK(!VCModCopTwoHandPose(&p, &cop), "normal play keeps the row off");
    bVCModCopPistol = true;
    CHECK(VCModCopTwoHandPose(&p, &cop), "normal play keeps the row on");
```

and the extraction list gains `"bool\nVCModCopTwoHandPose(CPed *ped, CWeaponInfo *info)"`.

Wiring:

```python
    def test_aim_features_stand_down_in_npc_mode(self):
        walk = COMBAT[COMBAT.index("VCModAimWalkWeapon(CPed *ped, CWeaponInfo *info)"):]
        walk = walk[:walk.index("\n}")]
        self.assertIn("VCModNpcFightsAsPed(ped)", walk)
        tick = braced(COMBAT, "VCModCombatAimTick(CPed *ped, CWeaponInfo *weaponInfo, CAnimBlendAssociation *weaponAssoc)")
        self.assertIn("VCModNpcFightsAsPed(ped)", tick)
        point = braced(PEDFIGHT, "CPed::PointGunAt(void)")
        self.assertIn("VCModNpcFightsAsPed(this)", point)
        self.assertIn("!VCModNpcCopActive()", point)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Implement the aim rules**

`VCModCopTwoHandPose`:

```cpp
bool
VCModCopTwoHandPose(CPed *ped, CWeaponInfo *info)
{
	if (!ped->IsPlayer() || !info->IsFlagSet(WEAPONFLAG_COP3_RD))
		return false;
	if (VCModNpcFightsAsPed(ped))
		// the worn body decides: a police body keeps the stock cop clip the
		// COLT TWO-HAND row exists to restore, every other body keeps its own
		return VCModNpcCopActive();
	return bVCModCopPistol;
}
```

`VCModCopSetStance`, after the nil guard:

```cpp
	if (VCModNpcFightsAsPed(ped) && VCModNpcCopActive())
		// the cop skeleton is what the clip was authored on; the pinning is
		// for Tommy's skeleton, not the body the clip belongs to
		return;
```

`VCModAimWalkWeapon`:

```cpp
	return bVCModAimWalk && ped->IsPlayer() && !VCModNpcFightsAsPed(ped) && !ped->bIsDucking
		&& !VCModCopTwoHandPose(ped, info)
		&& !info->IsFlagSet(WEAPONFLAG_CANAIM_WITHARM);
```

`VCModCombatAimTick`, at the top:

```cpp
	if (VCModNpcFightsAsPed(ped))
		// the stock ped aim handling: the player's cop-pose hold, AIM WALK and
		// recovery tails are player features, so the engine parks the clip
		return false;
```

`CPed::PointGunAt`:

```cpp
	bool raising = IsPlayer() && !VCModNpcFightsAsPed(this) && VCModAimRaising();
```
and
```cpp
	float animLoopStart = aimAnim == ANIM_WEAPON_FIRE_3RD && !VCModNpcCopActive() ? nVCModCopHoldFrame / 30.0f : weaponInfo->m_fAnimLoopStart;
```

- [ ] **Step 4: Update `test_vc_combat.py`'s cop pose tests**

The existing cop-pose test asserts the row gates the pose for the player. Add the NPC cases (or update it) to include: `VCModCopTwoHandPose` returns true for a police body in NPC mode with the row off, and false for a civilian body. Keep the normal-play row case.

- [ ] **Step 5: Stub the aim predicates in the compiling harnesses**

Add to the stub block of `test_vc_cop_pistol.py`, `test_vc_aimwalk.py` and
`test_vc_weapon_recovery.py`:

```cpp
bool bVCModNpcMode = false;
bool VCModNpcFightsAsPed(CPed *ped) { return ped->IsPlayer() && bVCModNpcMode; }
bool VCModNpcCopActive(void) { return false; }
```

In `test_vc_windup.py`, the `PointGunAt` assertion at line ~101 pins the old
raise condition. Update it to:

```python
        self.assertIn("bool raising = IsPlayer() && !VCModNpcFightsAsPed(this) && VCModAimRaising();", point)
```

and add the same `bVCModNpcMode` + predicate stub if that harness ever compiles
the function; today it only reads the text, so the stub is optional there.

- [ ] **Step 6: Run the harnesses**

Run: `cd reVC/utils && python3 test_vc_npccombat.py && python3 test_vc_combat.py && python3 test_vc_cop_pistol.py && python3 test_vc_aimwalk.py && python3 test_vc_weapon_recovery.py && python3 test_vc_windup.py`
Expected: PASS.

---

### Task B4: Slice B verification, install and handoff

- [ ] **Step 1: Whole suite** — `cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done` (49 pass).
- [ ] **Step 2: Build** — `cd vc-mod && scripts/build.sh`.
- [ ] **Step 3: Install** — `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, `scripts/install.sh`, then `strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" | grep -m1 '^vcmods build '` shows the new number.
- [ ] **Step 4: Hand off** — `docs/handoff/` named with the session date and `-npc-stock-combat-b`; what to play: a gunfight as a civilian body (accuracy, reload, empty-gun switch) and as a cop body (colt clip, no Tommy stance pinning). No commit unless asked.

---

## Slice C — receiving side

### Task C1: Damage taken

**Files:**
- Modify: `src/peds/PedFight.cpp` (`InflictDamage` 2822-2856, 3006, 3086)
- Modify: `utils/test_vc_npccombat.py`

- [ ] **Step 1: Add the failing wiring test**

```python
    def test_damage_taken_uses_the_ped_rules(self):
        dmg = braced(PEDFIGHT, "CPed::InflictDamage(CEntity *damagedBy, eWeaponType method, float damage, ePedPieceTypes pedPiece, uint8 direction)")
        self.assertIn("healthImpact = damage * m_pedStats->m_defendWeakness;", dmg)
        self.assertNotIn("if (IsPlayer())\n\t\thealthImpact = damage * 0.33f;", dmg)
        self.assertIn("VCModNpcFightsAsPed(this)", dmg)
        self.assertIn("dontRemoveLimb = true", dmg)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Flip the damage rules**

`CPed::InflictDamage`:

1. GANG7 immunity:
```cpp
		if (!VCModNpcFightsAsPed(this)
			&& damagedBy && damagedBy->IsPed() && ((CPed*)damagedBy)->m_nPedType == PEDTYPE_GANG7)
			return false;
```
2. Fireproof exemption:
```cpp
		if ((method == WEAPONTYPE_FLAMETHROWER || method == WEAPONTYPE_MOLOTOV) && CWorld::Players[CWorld::PlayerInFocus].m_bFireproof
			&& !VCModNpcFightsAsPed(this))
			return false;
```
3. Health impact:
```cpp
	if (IsPlayer() && !VCModNpcFightsAsPed(this))
		healthImpact = damage * 0.33f;
	else
		healthImpact = damage * m_pedStats->m_defendWeakness;
```
4. Bleed:
```cpp
	if ((!IsPlayer() || VCModNpcFightsAsPed(this)) &&
		(method == WEAPONTYPE_SCREWDRIVER || method == WEAPONTYPE_KNIFE || (method >= WEAPONTYPE_CLEAVER && method <= WEAPONTYPE_CHAINSAW)))
		m_bleedCounter = 200;
```
5. Limb removal:
```cpp
				if ((IsPlayer() && !VCModNpcFightsAsPed(this)) || bNoCriticalHits)
					dontRemoveLimb = true;
```
6. Explosion dismemberment:
```cpp
				if (CGame::nastyGame && (!IsPlayer() || VCModNpcFightsAsPed(this)) && !bInVehicle &&
					1.0f + healthImpact > m_fArmour + m_fHealth) {
```

Keep `m_bCanBeDamaged` and `AnnoyPlayerPed(false)`.

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

---

### Task C2: Hit reactions and victim-side melee rules

**Files:**
- Modify: `src/peds/PedFight.cpp` (`StartFightDefend` 1283-1429, `FightHitPed` 2254/2310)
- Modify: `utils/test_vc_npccombat.py`

- [ ] **Step 1: Add the failing wiring test**

```python
    def test_hit_reactions_take_the_ped_path(self):
        defend = braced(PEDFIGHT, "CPed::StartFightDefend(uint8 direction, uint8 hitLevel, uint8 unk)")
        self.assertIn("IsPlayer() && !VCModNpcFightsAsPed(this)", defend)
        hit = braced(PEDFIGHT, "CPed::FightHitPed(CPed *victim, CVector &touchPoint, CVector &dir, int16 piece)")
        self.assertIn("VCModNpcFightsAsPed(victim)", hit)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Flip the reaction branches**

`CPed::StartFightDefend`:

1. Running-player branch:
```cpp
		if ((IsPlayer() && !VCModNpcFightsAsPed(this) && m_nPedState != PED_FIGHT && ((CPlayerPed*)this)->m_fMoveSpeed > 1.0f)
			|| (!IsPlayer() && m_objective == OBJECTIVE_FLEE_CHAR_ON_FOOT_TILL_SAFE)) {
```
2. Low-hit knockdowns:
```cpp
					if (direction == 2 && ((!IsPlayer() || VCModNpcFightsAsPed(this)) || ((CGeneral::GetRandomNumber() & 1) && m_fHealth < 30.0f))) {
```
```cpp
					} else if (direction != 2 && (!IsPlayer() || VCModNpcFightsAsPed(this)) && (CGeneral::GetRandomNumber() & 1) && m_fHealth < 30.0f) {
```
3. Fight-move speed:
```cpp
				if (IsPlayer() && !VCModNpcFightsAsPed(this))
					moveAssoc->speed = 1.2f;
```
4. Player-with-gun reaction:
```cpp
				} else if (IsPlayer() && !VCModNpcFightsAsPed(this) && GetWeapon()->m_eWeaponType != WEAPONTYPE_UNARMED && GetWeapon()->m_eWeaponType != WEAPONTYPE_BRASSKNUCKLE &&
```

`CPed::FightHitPed`:

1. Get-up immunity:
```cpp
	if (victim->IsPlayer() && !VCModNpcFightsAsPed(victim) && victim->m_nPedState == PED_GETUP)
		return;
```
2. Hit-step value:
```cpp
	if (GetWeapon()->m_eWeaponType != WEAPONTYPE_UNARMED && GetWeapon()->m_eWeaponType != WEAPONTYPE_BRASSKNUCKLE &&
		(!victim->IsPlayer() || VCModNpcFightsAsPed(victim)) && !fightingWithWeapon)
		unk2 = 101;
```

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

---

### Task C3: Reacting to an attack as a ped

**Files:**
- Modify: `src/peds/PedAI.cpp` (`ReactToAttack` 2264)
- Modify: `utils/test_vc_npccombat.py`

- [ ] **Step 1: Add the failing wiring test**

```python
    def test_react_to_attack_takes_the_ped_path_for_every_profile(self):
        react = braced(PEDAI, "CPed::ReactToAttack(CEntity *attacker)")
        self.assertIn("VCModNpcFightsAsPed(this)", react)
        self.assertNotIn("!VCModNpcCivilianActive() && !VCModNpcGangActive()", react)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: FAIL.

- [ ] **Step 3: Flip it**

```cpp
	if (IsPlayer() && !VCModNpcFightsAsPed(this) && attacker->IsPed()) {
```

Leave `ReactToPointGun` untouched: its current player gate is already profile-correct (cop returns, civ/gang take the ped path).

- [ ] **Step 4: Run the harness**

Run: `cd reVC/utils && python3 test_vc_npccombat.py`
Expected: PASS.

---

### Task C4: Slice C verification, install and final handoff

- [ ] **Step 1: Whole suite** — `cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done` (49 pass).
- [ ] **Step 2: Build** — `cd vc-mod && scripts/build.sh`.
- [ ] **Step 3: Install** — `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, `scripts/install.sh`, then `strings "$HOME/Games/VC/reVC.app/Contents/MacOS/reVC" | grep -m1 '^vcmods build '` shows the new number.
- [ ] **Step 4: Hand off** — `docs/handoff/` named with the session date and `-npc-stock-combat-c`: the complete feature, what to play (taking fists, bullets, falls and explosions as a civilian/gang/cop body; death/limb rules; the cop reaction to an attack), and any open play item. Update `docs/architecture.md` debt sizes if a module crossed 1,000 lines. Commit only if asked.

---

## Self-Review Notes

- Spec coverage: melee entry (A3), chooser (A2), fight state (A4), strength/VFX (A5), ownership/bump (A6), profile (A7), accuracy (B1), gun gates/perks (B2), aim/cop clip (B3), damage taken (C1), hit reactions (C2), attack reaction (C3). ReactToPointGun is explicitly no-change (C3).
- Placeholder scan: no TBDs; every code step carries the literal code.
- Type consistency: `VCModCombatChooseMove` returns `int32` at both call sites into `m_curFightMove`; `VCModNpcWepAccuracy` returns `uint8` into `m_wepAccuracy`; the harness extraction strings match the real signatures.
- Line numbers are as of HEAD `aebb665`; locate by function name if an earlier task shifts them.
