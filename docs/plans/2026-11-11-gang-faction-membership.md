# Gang Faction Membership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make BECOME NPC's GANG profile turn Tommy into a real Vercetti (GANG7) member — rivals hunt him, GANG7 are kin (spare/chat/backup), his own AI fights rivals, cops chase him, voice follows the worn body.

**Architecture:** Keep `PLAYER1` (no type swap). While GANG-wandering, borrow the gang fields the AI reads (`m_fearFlags`, `m_pedStats`, `m_gangFlags`, `CharCreatedBy`) and restore them on break/off/switch. Make `IsGangMember()` player-aware and substitute an effective gang type (`VCModGangEffectiveType`) at the shared bit/type reads so other peds' AI treat Tommy as GANG7. Dispatch the same `CCivilianPed` AI layer the CIVILIAN profile runs.

**Tech Stack:** C++98 (reVC engine), CMake Release build, Python unittest harnesses that extract real C++ functions and compile against stubs (`reVC/utils/test_vc_*.py`).

**Spec:** `docs/specs/2026-11-11-gang-faction-membership-design.md`

## Global Constraints

- Git is the play-tester's: **no commit, tag, or push** in any task. The skill's "commit" step is replaced by build + harness verify.
- Game data is read-only: never write `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`. Never touch `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).
- Install into `~/Games/VC` only when no session is running: `pgrep -f "reVC.app/Contents/MacOS/reVC"` must be empty.
- Published artifacts name no AI/model/tool; write the workspace as `vc-mod`. English only.
- Keep CIVILIAN and COP profiles and native gang peds' own behavior unchanged.
- Mod/gameplay code stays platform-neutral (no `#ifdef __APPLE__` in `src/extras/`).
- Build: `scripts/build.sh`. Install: `scripts/install.sh`. Harness: run from `reVC/utils/` so cross-imports resolve (`cd reVC/utils && python3 -m unittest <module> -v`); full suite `python3 -m unittest discover -p 'test_vc_*.py'`.
- Verification bar: a behavior is "done" only when confirmed in play by the play-tester; harness green is necessary, not sufficient. Do not append launch/relaunch instructions to the play-tester.

## File Structure

- `reVC/src/extras/vcmodpanel.h` / `.cpp` — declare/define `VCModGangEffectiveType(CPed*)` (the effective-type helper). `vcmodpanel.cpp` already includes `Ped.h`/`PedType.h`.
- `reVC/src/peds/PlayerPed.cpp` — `VCModNpcGangActive()` gate; gang field borrows + restore + GANG AI dispatch in `VCModUpdateNpcMode`.
- `reVC/src/peds/Ped.cpp` — `IsGangMember()` player-aware; effective-type in `ScanForThreats`, `CanBeFriends`, `CivilianAI` corpse branch.
- `reVC/src/peds/PedAI.cpp` — effective-type in `CanBeDamagedByThisGangMember`, `RegisterThreatWithGangPeds`; lift `ReactToAttack`/`ReactToPointGun` player guards under the gang gate.
- `reVC/src/weapons/Weapon.cpp` — effective-type in the melee (526) and bullet (1400) friendly-fire checks.
- `reVC/utils/test_vc_gangfaction.py` — NEW: truth-table harness for the helpers + damage gate.
- `reVC/utils/test_vc_npcmode.py` — extend stubs; rewrite the three old plain-wander GANG tests; add gang borrow/restore/dispatch tests.

Line numbers are anchors from HEAD `8d57f7c`; locate by function/signature, not by absolute line, since earlier tasks shift them.

---

### Task 1: Gang identity helpers + player-aware IsGangMember

**Files:**
- Modify: `reVC/src/extras/vcmodpanel.h` (declare near `VCModNpcCivilianActive`, line ~81)
- Modify: `reVC/src/extras/vcmodpanel.cpp` (define helper)
- Modify: `reVC/src/peds/PlayerPed.cpp:1553` (add `VCModNpcGangActive` after `VCModNpcCivilianActive`)
- Modify: `reVC/src/peds/Ped.cpp:8325` (`IsGangMember`)
- Test: `reVC/utils/test_vc_gangfaction.py` (create)

**Interfaces:**
- Produces: `bool VCModNpcGangActive(void)` → `bVCModNpcMode && nVCModNpcType == VCMOD_NPC_GANG`.
- Produces: `int32 VCModGangEffectiveType(CPed *ped)` → `PEDTYPE_GANG7` if `ped->IsPlayer() && VCModNpcGangActive()`, else `ped->m_nPedType`.
- Produces: `CPed::IsGangMember()` now true for the gang-profile player.
- Consumes: `bVCModNpcMode`, `nVCModNpcType`, `VCMOD_NPC_GANG` (vcmodpanel.h); `PEDTYPE_GANG7` (PedType.h).

- [ ] **Step 1: Write the failing harness** — create `reVC/utils/test_vc_gangfaction.py`:

```python
#!/usr/bin/env python3
"""Gang faction identity: IsGangMember / VCModGangEffectiveType / VCModNpcGangActive
and the gang damage gate, extracted from the engine and compiled against stubs."""
import unittest
from pathlib import Path
from test_vc_passenger import braced, run_cpp

ROOT = Path(__file__).resolve().parents[1]
PED = (ROOT / "src/peds/Ped.cpp").read_text()
PANEL = (ROOT / "src/extras/vcmodpanel.cpp").read_text()
PLAYER = (ROOT / "src/peds/PlayerPed.cpp").read_text()
PEDAI = (ROOT / "src/peds/PedAI.cpp").read_text()

STUBS = r'''
#include <cstdio>
#include <cstdint>
#define nil NULL
typedef int8_t int8;
typedef uint8_t uint8;
typedef int32_t int32;
typedef uint32_t uint32;
enum { PEDTYPE_PLAYER1, PEDTYPE_GANG1, PEDTYPE_GANG7 = 7, PEDTYPE_GANG8 };
enum { VCMOD_NPC_GANG, VCMOD_NPC_CIVILIAN, VCMOD_NPC_COP };
bool bVCModNpcMode = false;
int32 nVCModNpcType = VCMOD_NPC_GANG;
struct CPed {
    int m_nPedType;
    uint8 m_gangFlags;
    bool m_isPlayer;
    CPed() : m_nPedType(PEDTYPE_GANG7), m_gangFlags(0xFF), m_isPlayer(false) {}
    bool IsPlayer(void) const { return m_isPlayer; }
    bool IsGangMember(void) const;
};
'''

GATE = "bool\nVCModNpcGangActive(void)"
EFF = "int32\nVCModGangEffectiveType(CPed *ped)"
ISGANG = "bool\nCPed::IsGangMember(void) const"
DMG = "bool\nCPed::CanBeDamagedByThisGangMember(CPed* who)"

def src(*funcs):
    return STUBS + "\n".join(funcs) + "\n"

class IdentityTests(unittest.TestCase):
    def test_gang_active_gate(self):
        run_cpp(src(braced(PLAYER, GATE)) + r'''
int main(void) {
    bVCModNpcMode = true; nVCModNpcType = VCMOD_NPC_GANG;
    if (!VCModNpcGangActive()) return 1;
    nVCModNpcType = VCMOD_NPC_CIVILIAN;
    if (VCModNpcGangActive()) return 2;
    bVCModNpcMode = false; nVCModNpcType = VCMOD_NPC_GANG;
    if (VCModNpcGangActive()) return 3;
    return 0;
}
''')

    def test_is_gang_member_player_aware(self):
        run_cpp(src(braced(PLAYER, GATE), braced(PED, ISGANG)) + r'''
int main(void) {
    CPed gang; gang.m_nPedType = PEDTYPE_GANG7;
    if (!gang.IsGangMember()) return 1;          // real gang ped
    CPed tommy; tommy.m_isPlayer = true; tommy.m_nPedType = PEDTYPE_PLAYER1;
    bVCModNpcMode = false;
    if (tommy.IsGangMember()) return 2;          // normal player: not a gang member
    bVCModNpcMode = true; nVCModNpcType = VCMOD_NPC_GANG;
    if (!tommy.IsGangMember()) return 3;         // gang-profile player: GANG7 kin
    nVCModNpcType = VCMOD_NPC_CIVILIAN;
    if (tommy.IsGangMember()) return 4;          // civilian profile: not gang
    return 0;
}
''')

    def test_effective_type(self):
        run_cpp(src(braced(PLAYER, GATE), braced(PANEL, EFF)) + r'''
int main(void) {
    CPed tommy; tommy.m_isPlayer = true; tommy.m_nPedType = PEDTYPE_PLAYER1;
    bVCModNpcMode = true; nVCModNpcType = VCMOD_NPC_GANG;
    if (VCModGangEffectiveType(&tommy) != PEDTYPE_GANG7) return 1;
    bVCModNpcMode = false;
    if (VCModGangEffectiveType(&tommy) != PEDTYPE_PLAYER1) return 2;
    CPed rival; rival.m_nPedType = PEDTYPE_GANG8;
    if (VCModGangEffectiveType(&rival) != PEDTYPE_GANG8) return 3;  // non-player unchanged
    return 0;
}
''')

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction -v`
Expected: FAIL — `VCModNpcGangActive` / `VCModGangEffectiveType` not found in source (braced raises ValueError).

- [ ] **Step 3: Add the gate** in `PlayerPed.cpp` immediately after `VCModNpcCivilianActive` (line ~1556):

```cpp
// exported for the gang type gates that would otherwise skip PLAYER1
bool
VCModNpcGangActive(void)
{
	return bVCModNpcMode && nVCModNpcType == VCMOD_NPC_GANG;
}
```

Declare in `vcmodpanel.h` next to `VCModNpcCivilianActive` (line ~81):

```cpp
bool VCModNpcGangActive(void);
// the gang profile reads Tommy as GANG7: his effective type for the gang bit/type
// decisions, while m_nPedType stays PLAYER1
int32 VCModGangEffectiveType(CPed *ped);
```

- [ ] **Step 4: Define the helper** in `vcmodpanel.cpp` (near the other VCMod free functions; `Ped.h`/`PedType.h` are already included):

```cpp
int32
VCModGangEffectiveType(CPed *ped)
{
	if (ped->IsPlayer() && VCModNpcGangActive())
		return PEDTYPE_GANG7;
	return ped->m_nPedType;
}
```

- [ ] **Step 5: Make IsGangMember player-aware** in `Ped.cpp:8325` (vcmodpanel.h is already included — `VCModNpcCivilianActive` is used at line 8466):

```cpp
bool
CPed::IsGangMember(void) const
{
	return (m_nPedType >= PEDTYPE_GANG1 && m_nPedType <= PEDTYPE_GANG9)
		|| (IsPlayer() && VCModNpcGangActive());
}
```

- [ ] **Step 6: Run the harness to verify it passes**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction -v`
Expected: PASS (3 tests).

- [ ] **Step 7: Build + full suite (no git)**

Run: `scripts/build.sh` then `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'`
Expected: build green; suite green (the new file adds 3; existing tests unaffected — `IsGangMember` returns false for the normal player, so native behavior is unchanged).

---

### Task 2: Gang field borrows + restore + GANG AI dispatch

**Files:**
- Modify: `reVC/src/peds/PlayerPed.cpp` — `VCModUpdateNpcMode` (1575) and the NPC statics block
- Test: `reVC/utils/test_vc_npcmode.py` (extend stubs; rewrite 3 GANG tests; add borrow/restore/dispatch tests)

**Interfaces:**
- Consumes: `VCModNpcGangActive()` (Task 1); `CPedType::GetThreats`, `CPedStats::ms_apPedStats`, `PEDSTAT_GANG7`, `PEDTYPE_GANG7`, `PEDTYPE_GANG1`.
- Produces: while GANG-wandering, player has `m_fearFlags == GetThreats(GANG7)`, `m_pedStats == ms_apPedStats[PEDSTAT_GANG7]`, GANG7 bit of `m_gangFlags` cleared, `CharCreatedBy == RANDOM_CHAR`; all restored on off/break/switch. GANG profile runs `ProcessCivilianState` + `CivilianAI` + cars + attractors.

- [ ] **Step 1: Extend the harness stubs** in `test_vc_npcmode.py`. Replace the type/flag enums and `CPedType` stub (lines ~52-61) with:

```python
enum { PEDTYPE_PLAYER1, PEDTYPE_CIVMALE, PEDTYPE_GANG1, PEDTYPE_GANG7 = 7 };
enum { PED_FLAG_GUN = 1, PED_FLAG_EXPLOSION = 2, PED_FLAG_DEADPEDS = 4,
       PED_FLAG_GANG1 = 8, PED_FLAG_GANG7 = 16, PED_FLAG_GANG8 = 32 };
enum { PEDSTAT_PLAYER, PEDSTAT_GANG7 };
#define VCMOD_NPC_RETRY_GAP 500

struct CPedType {
    static uint32 GetThreats(int type) {
        if (type == PEDTYPE_CIVMALE) return PED_FLAG_GUN | PED_FLAG_EXPLOSION | PED_FLAG_DEADPEDS;
        if (type == PEDTYPE_GANG7) return PED_FLAG_GUN | PED_FLAG_GANG1 | PED_FLAG_GANG8 | PED_FLAG_EXPLOSION;
        return 0;
    }
};
struct CPedStats { int m_type; static CPedStats *ms_apPedStats[2]; };
static CPedStats g_playerStat, g_gangStat;
CPedStats *CPedStats::ms_apPedStats[2] = { &g_playerStat, &g_gangStat };
```

Add fields to the stub `CPlayerPed` (after `m_fearFlags`): `CPedStats *m_pedStats; uint8 m_gangFlags;` and initialize in its constructor: `m_pedStats(CPedStats::ms_apPedStats[PEDSTAT_PLAYER]), m_gangFlags(0xFF)`. Add `bool IsPlayer(void) { return true; }`. Add the gang statics to the STUBS static block (after `nVCModNpcStateProfile`):

```python
static CPedStats *pVCModNpcSavedStats = nil;
static uint8 nVCModNpcSavedGangFlags = 0;
static bool bVCModNpcGangBorrowed = false;
```

Reset them in `setup()`: `pVCModNpcSavedStats = nil; nVCModNpcSavedGangFlags = 0; bVCModNpcGangBorrowed = false; g_playerStat.m_type = PEDSTAT_PLAYER; g_gangStat.m_type = PEDSTAT_GANG7;`. Add `VCModNpcGangActive` to SIGS (`"bool\nVCModNpcGangActive(void)"`) and add the restore helper signature if extracted (Step 3 defines it static; add `"static void\nVCModNpcRestoreGangBorrow(CPlayerPed *player)"` to SIGS).

- [ ] **Step 2: Rewrite the three obsolete GANG tests** to the new behavior:

`test_gang_keeps_empty_threat_flags` → `test_gang_wander_reads_gang_threats`:

```python
    def test_gang_wander_reads_gang_threats(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (!(p.m_fearFlags & PED_FLAG_GANG1)) return 1;   // hunts rivals
    if (!(p.m_fearFlags & PED_FLAG_GANG8)) return 2;
    if (p.m_fearFlags & PED_FLAG_GANG7) return 3;      // never his own gang
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG7]) return 4;
    if (p.m_gangFlags & (1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1))) return 5;  // kin bit cleared
    return 0;
}
''')
```

`test_gang_and_cop_keep_mission_char` → `test_gang_random_char_cop_mission_char`:

```python
    def test_gang_random_char_cop_mission_char(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.CharCreatedBy != RANDOM_CHAR) return 1;      // gang AI gates open
    nVCModNpcType = VCMOD_NPC_COP;
    VCModUpdateNpcMode(&p, &pad);
    if (p.CharCreatedBy != MISSION_CHAR) return 2;     // cop unchanged
    return 0;
}
''')
```

`test_gang_is_plain_wander` → `test_gang_runs_native_layer`:

```python
    def test_gang_runs_native_layer(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (!''' + has("civilianState") + r''') return 1;
    if (!''' + has("civilianAI") + r''') return 2;
    if (!''' + has("vacantCars") + r''') return 3;
    if (!''' + has("attractors") + r''') return 4;
    if (''' + has("patrol") + r''') return 5;
    if (!bVCModStreetWander) return 6;
    return 0;
}
''')
```

- [ ] **Step 3: Add restore-on-off and restore-on-switch tests**:

```python
    def test_toggle_off_restores_gang_borrows(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModStreetWander = true;
    bVCModNpcModeWasOn = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG7]) return 1;
    bVCModNpcMode = false;
    VCModUpdateNpcMode(&p, &pad);
    if (p.CharCreatedBy != MISSION_CHAR) return 2;
    if (p.m_fearFlags != 0) return 3;
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_PLAYER]) return 4;
    if (p.m_gangFlags != 0xFF) return 5;
    return 0;
}
''')

    def test_gang_to_civilian_switch_restores_gang_stats(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG7]) return 1;
    nVCModNpcType = VCMOD_NPC_CIVILIAN;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_PLAYER]) return 2;
    if (p.m_gangFlags != 0xFF) return 3;
    if (!(p.m_fearFlags & PED_FLAG_DEADPEDS)) return 4;   // civilian flags now
    return 0;
}
''')
```

- [ ] **Step 4: Run the harness to verify the new/rewritten tests fail**

Run: `cd reVC/utils && python3 -m unittest test_vc_npcmode -v`
Expected: FAIL on the gang tests (current code keeps MISSION_CHAR / fearFlags 0 / no layer).

- [ ] **Step 5: Implement the borrows + restore** in `PlayerPed.cpp`. Add the statics near the other NPC statics:

```cpp
static CPedStats *pVCModNpcSavedStats = nil;
static uint8 nVCModNpcSavedGangFlags = 0;
static bool bVCModNpcGangBorrowed = false;

static void
VCModNpcRestoreGangBorrow(CPlayerPed *player)
{
	if (bVCModNpcGangBorrowed) {
		player->m_pedStats = pVCModNpcSavedStats;
		player->m_gangFlags = nVCModNpcSavedGangFlags;
		bVCModNpcGangBorrowed = false;
	}
}
```

In the off-edge block (`if (!bVCModNpcMode)`, ~1582), after the existing `m_fearFlags` restore, add `VCModNpcRestoreGangBorrow(player);`.

Replace the borrow lines (1603-1605) with:

```cpp
	bool bCivilianWander = VCModNpcCivilianActive() && bVCModStreetWander;
	bool bGangWander = VCModNpcGangActive() && bVCModStreetWander;
	player->CharCreatedBy = (bCivilianWander || bGangWander) ? RANDOM_CHAR : MISSION_CHAR;
	player->m_fearFlags = CPedType::GetThreats(bCivilianWander ? PEDTYPE_CIVMALE
		: bGangWander ? PEDTYPE_GANG7 : player->m_nPedType);
	if (bGangWander) {
		if (!bVCModNpcGangBorrowed) {
			pVCModNpcSavedStats = player->m_pedStats;
			nVCModNpcSavedGangFlags = player->m_gangFlags;
			bVCModNpcGangBorrowed = true;
		}
		player->m_pedStats = CPedStats::ms_apPedStats[PEDSTAT_GANG7];
		player->m_gangFlags = (uint8)~(1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1));
	} else {
		VCModNpcRestoreGangBorrow(player);
	}
```

- [ ] **Step 6: Add the GANG AI dispatch branch** in the wander block, after the CIVILIAN branch (~1659), before the COP branch:

```cpp
		} else if (nVCModNpcType == VCMOD_NPC_GANG) {
			if (!bVCModNpcStateInit) {
				VCModNpcInitCivilianState();
				bVCModNpcStateInit = true;
			}
			player->ProcessCivilianState();
			if (player->IsPedInControl())
				player->CivilianAI();
			player->EnterVacantNearbyCars(sVCModNpcCivilian);
			player->UseNearbyAttractors(sVCModNpcCivilian);
```

- [ ] **Step 7: Run the harness to verify it passes**

Run: `cd reVC/utils && python3 -m unittest test_vc_npcmode -v`
Expected: PASS (all civilian/cop tests still green; gang tests now green).

- [ ] **Step 8: Build + full suite (no git)**

Run: `scripts/build.sh` then `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'`
Expected: build green; suite green.

---

### Task 3: Effective type in target selection, chat, corpse

**Files:**
- Modify: `reVC/src/peds/Ped.cpp` — `ScanForThreats` (868/873/915/985), `CanBeFriends` (1427/1438), `CivilianAI` corpse (1559)
- Test: `reVC/utils/test_vc_gangfaction.py` (add a targeting-predicate test); in-game checkpoint is the integration gate.

**Interfaces:**
- Consumes: `VCModGangEffectiveType(CPed*)` (Task 1), `CPedType::GetFlag`.
- Produces: a rival gang ped's scan flags Tommy as `PED_FLAG_GANG7` (a threat); a GANG7 ped's scan does not; `CanBeFriends` allows Tommy↔GANG7.

- [ ] **Step 1: Add the failing predicate test** to `test_vc_gangfaction.py`. Extend STUBS with `PED_FLAG_GANG1 = 1<<7, PED_FLAG_GANG7 = 1<<13` and a `CPedType::GetFlag`/`GetThreats` stub mirroring ped.dat (GANG7 threats = all rivals, rivals include GANG7). Add:

```python
    def test_rival_sees_tommy_as_gang7_kin_does_not(self):
        run_cpp(src(braced(PLAYER, GATE), braced(PANEL, EFF)) + r'''
int main(void) {
    CPed tommy; tommy.m_isPlayer = true; tommy.m_nPedType = PEDTYPE_PLAYER1;
    bVCModNpcMode = true; nVCModNpcType = VCMOD_NPC_GANG;
    uint32 tommyFlag = CPedType::GetFlag(VCModGangEffectiveType(&tommy));
    if (tommyFlag != PED_FLAG_GANG7) return 1;
    uint32 rivalFears = CPedType::GetThreats(PEDTYPE_GANG1);   // includes GANG7
    if (!(rivalFears & tommyFlag)) return 2;                   // rival hunts him
    uint32 kinFears = CPedType::GetThreats(PEDTYPE_GANG7);     // excludes GANG7
    if (kinFears & tommyFlag) return 3;                        // kin spare him
    return 0;
}
''')
```

(Define the stub `GetThreats(PEDTYPE_GANG1)` to include `PED_FLAG_GANG7` and `GetThreats(PEDTYPE_GANG7)` to exclude it, matching `data/ped.dat`.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction.IdentityTests.test_rival_sees_tommy_as_gang7_kin_does_not -v`
Expected: FAIL until the stub data + helper exist (Task 1 helper already present; this pins the data semantics).

- [ ] **Step 3: Substitute effective type in ScanForThreats** (`Ped.cpp`). At the shooter reads (868 and 873):

```cpp
			if (CPedType::GetFlag(VCModGangEffectiveType(shooter)) & fearFlags || m_nPedType == PEDTYPE_GANG5) {
				...
				return CPedType::GetFlag(VCModGangEffectiveType(shooter));
```

At the near-ped read (915):

```cpp
				flagsOfNearPed = CPedType::GetFlag(VCModGangEffectiveType(m_nearPeds[i]));
```

At the driver read (985):

```cpp
				flagsOfNearPed = CPedType::GetFlag(VCModGangEffectiveType(driver));
```

- [ ] **Step 4: Substitute effective type in CanBeFriends** (`Ped.cpp:1427` and `1438`):

```cpp
	if (VCModGangEffectiveType(this) == VCModGangEffectiveType(stranger))
		return true;
	...
	if ((IsGangMember() || stranger->IsGangMember())
		&& VCModGangEffectiveType(this) != VCModGangEffectiveType(stranger))
		return false;
```

- [ ] **Step 5: Substitute effective type in the CivilianAI corpse same-type check** (`Ped.cpp:1559`):

```cpp
		} else if (((CPed*)m_pEventEntity)->bIsDrowning
			|| IsGangMember() && VCModGangEffectiveType(this) == VCModGangEffectiveType((CPed*)m_pEventEntity)) {
```

- [ ] **Step 6: Run the harness + build**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction -v` then `scripts/build.sh`
Expected: harness PASS; build green.

- [ ] **Step 7: In-game checkpoint (integration gate)** — build/install only if `pgrep -f "reVC.app/Contents/MacOS/reVC"` is empty (`scripts/install.sh`). Play-tester confirms: GANG profile on, walk into rival gang turf → rivals attack on sight; walk among GANG7 → no attack. If a rival ignores Tommy, add a temporary once/second `IsPlayer()`-gated probe in `ScanForThreats` logging `GetFlag(VCModGangEffectiveType(nearPed))` and the scanner's `fearFlags`, read `~/Games/VC/reVC.log`, fix, strip the probe. Record result in the handoff.

---

### Task 4: Friendly-fire + damage gates

**Files:**
- Modify: `reVC/src/peds/PedAI.cpp:6966` (`CanBeDamagedByThisGangMember`)
- Modify: `reVC/src/weapons/Weapon.cpp:526` (melee), `1400` (bullet)
- Test: `reVC/utils/test_vc_gangfaction.py` (damage-gate truth table)

**Interfaces:**
- Consumes: `VCModGangEffectiveType`, player-aware `IsGangMember`, the cleared GANG7 `m_gangFlags` bit (Task 2).
- Produces: Tommy and GANG7 do not damage each other (melee + bullet); rivals still damage Tommy and vice versa.

- [ ] **Step 1: Add the failing damage-gate test** to `test_vc_gangfaction.py` (extract `CanBeDamagedByThisGangMember`; stub `CPed` already has `m_gangFlags`):

```python
class DamageGateTests(unittest.TestCase):
    def test_kin_bit_blocks_gang7_shooter(self):
        run_cpp(src(braced(PLAYER, GATE), braced(PANEL, EFF), braced(PEDAI, DMG)) + r'''
int main(void) {
    bVCModNpcMode = true; nVCModNpcType = VCMOD_NPC_GANG;
    CPed tommy; tommy.m_isPlayer = true; tommy.m_nPedType = PEDTYPE_PLAYER1;
    tommy.m_gangFlags = (uint8)~(1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1));  // borrowed
    CPed kin; kin.m_nPedType = PEDTYPE_GANG7;
    if (tommy.CanBeDamagedByThisGangMember(&kin)) return 1;   // GANG7 cannot hurt Tommy
    CPed rival; rival.m_nPedType = PEDTYPE_GANG8;
    if (!tommy.CanBeDamagedByThisGangMember(&rival)) return 2; // rival can
    return 0;
}
''')
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction.DamageGateTests -v`
Expected: FAIL (current bit index uses `who->m_nPedType`; for a GANG7 shooter it is already correct, but the test pins the effective-type path for a gang-profile Tommy shooter added next).

- [ ] **Step 3: Effective shooter type in the damage gate** (`PedAI.cpp:6966`):

```cpp
bool
CPed::CanBeDamagedByThisGangMember(CPed* who)
{
	return m_gangFlags & (1 << (VCModGangEffectiveType(who) - PEDTYPE_GANG1));
}
```

- [ ] **Step 4: Effective type in the melee friendly-fire check** (`Weapon.cpp:526`). Replace `victimPed->m_nPedType != shooterPed->m_nPedType` with `VCModGangEffectiveType(victimPed) != VCModGangEffectiveType(shooterPed)` (keep the rest of the condition unchanged). Add `#include "vcmodpanel.h"` to Weapon.cpp if not present.

- [ ] **Step 5: Effective type in the bullet friendly-fire check** (`Weapon.cpp:1400`). Replace `((CPed*)shooter)->m_nPedType != ((CPed*)victim)->m_nPedType` with `VCModGangEffectiveType((CPed*)shooter) != VCModGangEffectiveType((CPed*)victim)` (keep the `PEDTYPE_PLAYER2` and `!IsGangMember()` clauses unchanged).

- [ ] **Step 6: Run harness + build + full suite**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction -v` then `scripts/build.sh` then `python3 -m unittest discover -p 'test_vc_*.py'`
Expected: PASS; build green; suite green.

- [ ] **Step 7: In-game checkpoint** — play-tester confirms: GANG7 bullets/melee do not hurt Tommy; Tommy cannot hurt GANG7; rival gangs still damage him and he damages them. Record in handoff.

---

### Task 5: Fight/defend reactions + gang backup

**Files:**
- Modify: `reVC/src/peds/PedAI.cpp` — `ReactToPointGun` guard (2149), `ReactToAttack` guard (2230), `RegisterThreatWithGangPeds` (5464/5487)
- Test: in-game checkpoint (these are heavy state-machine functions; verify in play, probe if needed).

**Interfaces:**
- Consumes: `VCModNpcGangActive`, player-aware `IsGangMember`, `VCModGangEffectiveType`.
- Produces: gang-profile Tommy fights back when attacked (not the player-only inform path), reacts to pointed guns like a gang member, and his threat call rallies nearby GANG7.

- [ ] **Step 1: Lift the ReactToPointGun player guard** (`PedAI.cpp:2149`) — add the gang gate:

```cpp
	if ((IsPlayer() && !VCModNpcCivilianActive() && !VCModNpcGangActive()) || !IsPedInControl() || (CharCreatedBy == MISSION_CHAR && !bCrouchWhenScared))
		return;
```

- [ ] **Step 2: Lift the ReactToAttack player guard** (`PedAI.cpp:2230`) — add the gang gate so gang Tommy falls through to the fight/backup path:

```cpp
	if (IsPlayer() && !VCModNpcCivilianActive() && !VCModNpcGangActive() && attacker->IsPed()) {
		InformMyGangOfAttack(attacker);
		SetLookFlag(attacker, true);
		SetLookTimer(700);
		return;
	}
```

- [ ] **Step 3: Effective type for `this` in RegisterThreatWithGangPeds** so Tommy's call matches nearby GANG7. At `PedAI.cpp:5464`:

```cpp
						if (nearPed->CharCreatedBy == RANDOM_CHAR && nearPed != this
							&& VCModGangEffectiveType(nearPed) == VCModGangEffectiveType(this))
							nearPed->m_fearFlags |= CPedType::GetFlag(attackerPed->m_nPedType);
```

At `PedAI.cpp:5487` (the driver same-type check), replace `nearVehDriver->m_nPedType == m_nPedType` with `VCModGangEffectiveType(nearVehDriver) == VCModGangEffectiveType(this)`.

- [ ] **Step 4: Build + full suite**

Run: `scripts/build.sh` then `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'`
Expected: build green; suite green (no harness covers these heavy functions directly; the build + existing suite guard against regressions).

- [ ] **Step 5: In-game checkpoint** — play-tester confirms: a rival attacks Tommy → he fights back (not stands still); nearby GANG7 join the fight against the rival (backup); a pointed gun triggers a gang reaction. If Tommy does not fight back, probe `ReactToAttack` entry (once/second, `IsPlayer()`-gated) logging `m_nPedState`, `m_objective`, and whether the gang branch ran; read `~/Games/VC/reVC.log`, fix, strip. Record in handoff.

---

### Task 6: Attack/seek movement + final in-game pass + voice + probe strip

**Files:**
- Modify: `reVC/src/peds/PlayerPed.cpp` — the player control switch / `SetRealMoveAnim` movement drive (the round-3 reaction-state case) to also drive gang attack/seek movement under `bVCModNpcMode`.
- Modify: `reVC/src/peds/Ped.cpp` / `PlayerPed.cpp` — strip the four civilian VCMOD probes after final confirm.
- Test: `reVC/utils/test_vc_moveanim.py` (extend if the movement drive is extractable); in-game is the gate.

**Interfaces:**
- Consumes: `bVCModNpcMode`, the gang objective states (`OBJECTIVE_KILL_CHAR_ON_FOOT` → `PED_SEEK_POS`/`PED_ATTACK`/`PED_FIGHT`).
- Produces: gang Tommy translates toward his target and fights (no stand-still); voice unchanged.

- [ ] **Step 1: Diagnose the movement gap in play.** With Tasks 1-5 installed, play-tester engages GANG and provokes a rival fight. Observe whether Tommy closes on the target or stands still. If he stands still, add a temporary once/second probe in the player control switch logging `m_nPedState`, `m_objective`, `m_fMoveSpeed`, `m_nMoveState` for the attack/seek states. Read `~/Games/VC/reVC.log`.

- [ ] **Step 2: Drive attack/seek movement** mirroring the round-3 flee/investigate fix. In the player control switch case that handles reaction states under `bVCModNpcMode`, add `PED_SEEK_POS` (and the attack approach) driving `m_fMoveSpeed` from `m_nMoveState` + `SetRealMoveAnim`, falling through to the idle group when `bVCModNpcMode` is off (normal play unchanged). Use the exact pattern already present for `PED_FLEE_POS`/`PED_FLEE_ENTITY`/`PED_INVESTIGATE`; do not invent a new movement scheme. If `m_nStoredMoveState` is needed for the seek/attack states, sync it as the wander/seek cases already do.

- [ ] **Step 3: Build + harness + install + in-game confirm**

Run: `scripts/build.sh`, `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'`, install only if no session running. Play-tester confirms gang Tommy closes, fights, defends, and resumes wandering after. Iterate Step 2 until movement is natural (NPC parity bar).

- [ ] **Step 4: Voice verify (behavior 4, no code change expected).** Play-tester confirms: default Tommy body keeps Tommy's voice during gang chatter/grunts; a worn gang body keeps that body's voice. If a gang body is mute, inspect the worn-body comment routing (`cAudioManager::GetPedCommentSfx`) — the gang profile must not gate it; fix only if the profile disturbed it.

- [ ] **Step 5: Full in-game pass of all behaviors.** Play-tester confirms the spec's six checkpoints: own attack/defend, rival hunt, kin spare/chat/backup, cop chase, voice, toggle-off/break restore. Confirm CIVILIAN and COP profiles still behave as before.

- [ ] **Step 6: Strip the four civilian probes** (only after the play-tester confirms the civilian reaction-movement fix and the gang feature). Remove `VCMOD threat`, `VCMOD civ layer`, `VCMOD corpse`, `VCMOD react move` from `Ped.cpp`/`PlayerPed.cpp`, plus any temporary gang probes added in Tasks 3/5/6. Remove now-unused diagnostic statics.

- [ ] **Step 7: Final build + full suite + install (no session)**

Run: `scripts/build.sh`, `cd reVC/utils && python3 -m unittest discover -p 'test_vc_*.py'`, `scripts/install.sh` (pgrep empty). Expected: build green; suite green; clean build installed.

- [ ] **Step 8: Handoff.** Write `docs/handoff/2026-11-11-gang-faction-membership.md` (repo/branch/HEAD, installed build, what is uncommitted, verified vs pending behaviors, next steps, files not to touch) and post a paste-ready prompt. No git actions.

---

## Self-Review

**Spec coverage:**
- Behavior 1 (rival hunt): Task 3 (scan effective-type) + Task 2 (Tommy reads GANG7). ✓
- Behavior 2 (kin spare/chat/backup): Task 3 (scan spare + CanBeFriends chat), Task 4 (no friendly fire), Task 5 (backup). ✓
- Behavior 3 (own attack/defend): Task 2 (fearFlags + AI layer), Task 5 (fight back), Task 6 (movement). ✓
- Behavior 4 (look/voice): Task 6 Step 4 (verify-only). ✓
- Behavior 5 (cop chase): Task 1 (IsGangMember player-aware → CopPatrolScan). ✓
- Borrowed fields + restore: Task 2. ✓
- Effective-type patch set (scan/chat/corpse/damage/weapon/backup/guards): Tasks 3-5. ✓
- Stock GANG7+IsPlayer guards unchanged: no task touches 2156/2237/5446. ✓
- Harness + in-game verification: every task. ✓
- Civilian leftover (probe strip, unplayed movement fix): Task 6 Steps 5-6. ✓

**Placeholder scan:** No TBD/TODO; each code step shows the actual change. Task 6 Step 2 references the existing round-3 pattern rather than inventing code — the exact case is located in play (Step 1) because the movement gap is empirical; the pattern to copy is named and already in the file.

**Type consistency:** `VCModNpcGangActive(void)`, `VCModGangEffectiveType(CPed*)`, `VCModNpcRestoreGangBorrow(CPlayerPed*)`, statics `pVCModNpcSavedStats`/`nVCModNpcSavedGangFlags`/`bVCModNpcGangBorrowed` are spelled identically across tasks and harness. `PEDSTAT_GANG7`, `PEDTYPE_GANG7`, `PEDTYPE_GANG1` match PedType.h.

**Known risk carried into execution:** Task 6's movement drive is the most likely "built but stands still" gap (same class as the civilian freeze); it is diagnosed in play before coding, per the project's in-game verification bar.