# Body-Type Banking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give BECOME NPC a `TYPE FROM BODY` switch: while it is on, the worn model's stock ped type picks the NPC profile and, for gang bodies, the gang number; with it off the mode is exactly today's manual GANG/CIVILIAN/COP behaviour with GANG7.

**Architecture:** Derive, never store. `VCModNpcEffectiveType()` reads the player's model info each time the profile is needed (`MI_PLAYER`/GANG1..9 → GANG, `COP` → COP, everything else → CIVILIAN), and `VCModNpcGangType()` reads the body's own gang. The borrow block becomes one named helper (`VCModNpcBorrowIdentity`) that feeds those values into `m_fearFlags`, `m_pedStats` and `m_gangFlags`; the engine gate `VCModGangEffectiveType` returns the body gang for an active GANG player. The manual `nVCModNpcType` is never rewritten and remains the fallback.

**Tech Stack:** C++98 (reVC engine), CMake Release build, Python unittest harnesses that extract real C++ functions and compile them against stubs (`reVC/utils/test_vc_*.py`).

**Spec:** `docs/specs/2026-11-14-body-type-banking-design.md`

## Global Constraints

- Git is the play-tester's: **no commit, tag, or push** in any task. Verification is harness + build, never `git commit`. A task's last step is "run the harness", not the skill's usual commit.
- Game data is read-only: never write `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/`. Never touch `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).
- Install into `~/Games/VC` only when no session is running: `pgrep -f "reVC.app/Contents/MacOS/reVC"` must be empty. Never launch the game.
- Published artifacts name no AI/model/tool; the workspace is written as `vc-mod`. English only.
- Stock behaviour is 1:1. CIVILIAN/COP profiles, native peds, and the auto-off path must stay identical to today.
- Mod code stays platform-neutral (no `#ifdef __APPLE__` in `src/extras/`).
- Harness command: `cd reVC/utils && python3 -m unittest <module> -v`. Full suite: `for f in test_vc_*.py; do python3 "$f" || exit 1; done` from `reVC/utils/`.
- Build: `scripts/build.sh` from the workspace root. Install: `scripts/install.sh`.
- Verification bar: harnesses green and the build installed are necessary; the auto on/off matrix is settled by the play-tester's game session.

## File Structure

- `reVC/src/extras/vcmodnpc.h` / `.cpp` — the auto flag, the derivation helpers, the effective-type predicates, `VCModNpcBorrowIdentity`, the profile dispatch and the engage log.
- `reVC/src/extras/vcmodgang.cpp` — `VCModGangEffectiveType` returns the body gang for the player.
- `reVC/src/extras/vcmodpanelregistry.cpp` — the `TYPE FROM BODY` row, the NPC TYPE getter/setter, the debug tweak, the ALL ON comment.
- `reVC/src/core/re3.cpp` — the `NpcAutoType` ini read.
- `reVC/utils/test_vc_npcmode.py` — real model/stat tables, mapping matrix, auto on/off, cycle getter/setter, body-change re-init, identity borrow.
- `reVC/utils/test_vc_gangfaction.py` — identity borrow + effective body gang.
- `reVC/utils/test_vc_panel_info.py` — the new row's shape.
- `reVC/utils/test_vc_npcstrong.py`, `test_vc_ganggaze.py`, `test_vc_character.py`, `test_vc_adrenaline.py` — stub updates for the new symbols.
- `README.md` — the toggles table row.
- `docs/handoff/2026-11-14-body-type-banking.md` — session handoff with the play matrix.

Line anchors are from HEAD `c0477aa`; locate by function signature, not absolute line.

---

### Task 1: Mapping helpers, effective predicates, dispatch

**Files:**
- Modify: `reVC/src/extras/vcmodnpc.h:9-34` (flag + helper declarations)
- Modify: `reVC/src/extras/vcmodnpc.cpp:28-30` (flag), `:136-165` (predicates), `:173-227` (diag), `:278-292` (body stats), `:428` (engage log), `:498-502` (profile switch), `:569-622` (dispatch)
- Test: `reVC/utils/test_vc_npcmode.py` (stub rework + mapping tests)
- Test: `reVC/utils/test_vc_npcstrong.py`, `test_vc_ganggaze.py`, `test_vc_character.py`, `test_vc_adrenaline.py` (stub symbols)

**Interfaces:**
- Produces: `bool bVCModNpcAutoType` (default `true`).
- Produces: `int32 VCModNpcEffectiveType(void)` → the body profile while `bVCModNpcMode && bVCModNpcAutoType`, else `nVCModNpcType`.
- Produces: `int32 VCModNpcGangType(CPlayerPed *player)` → the body's gang type, `PEDTYPE_GANG7` when auto is off, the player/model is nil, or the body is not a gang body.
- Produces: `static int32 VCModNpcBodyProfile(CPlayerPed *player)` (file-local) → `VCMOD_NPC_GANG` for `PLAYER1` and `GANG1..GANG9`, `VCMOD_NPC_COP` for `COP`, `VCMOD_NPC_CIVILIAN` otherwise; manual profile when the player/model is invalid.
- Produces: `static CPedStats *VCModNpcBodyStats(CPlayerPed *player)` (file-local) → the model's stock stat, `PEDSTAT_PLAYER` on a data gap.
- Consumes: `FindPlayerPed`, `CModelInfo::GetModelInfo`, `CPedModelInfo::m_pedType/m_pedStatType`, `PEDTYPE_*`, `NUM_PEDSTATS`, `MITYPE_PED`.

- [ ] **Step 1: Rework the `test_vc_npcmode.py` stubs**

Replace the model enum at line 48 with:

```c
enum { MI_PLAYER, MI_COP, MI_SWAT, MI_FBI, MI_ARMY, MI_MALE01,
       MI_CUBAN, MI_HAITIAN, MI_SHARK, MI_DIAZ, MI_GANG5, MI_BIKER, MI_VERCETTI,
       MI_MEDIC, MI_FIREMAN, MI_SPECIAL01, MI_NOT_PED, MI_COUNT };
```

Replace the ped type enum at line 70 and the flag/stat enums at lines 71-73 with:

```c
enum { PEDTYPE_PLAYER1, PEDTYPE_PLAYER2, PEDTYPE_PLAYER3, PEDTYPE_PLAYER4,
       PEDTYPE_CIVMALE, PEDTYPE_CIVFEMALE, PEDTYPE_COP,
       PEDTYPE_GANG1, PEDTYPE_GANG2, PEDTYPE_GANG3, PEDTYPE_GANG4, PEDTYPE_GANG5,
       PEDTYPE_GANG6, PEDTYPE_GANG7, PEDTYPE_GANG8, PEDTYPE_GANG9,
       PEDTYPE_EMERGENCY, PEDTYPE_FIREMAN, PEDTYPE_CRIMINAL, PEDTYPE_UNUSED1,
       PEDTYPE_PROSTITUTE, PEDTYPE_SPECIAL, PEDTYPE_UNUSED2, NUM_PEDTYPES };
enum { PED_FLAG_GUN = 1, PED_FLAG_EXPLOSION = 2, PED_FLAG_DEADPEDS = 4,
       PED_FLAG_GANG1 = 8, PED_FLAG_GANG7 = 16, PED_FLAG_GANG8 = 32,
       PED_FLAG_GANG2 = 64, PED_FLAG_GANG3 = 128, PED_FLAG_GANG4 = 256,
       PED_FLAG_GANG5 = 512, PED_FLAG_GANG6 = 1024, PED_FLAG_GANG9 = 2048 };
enum { STAT_GUN_PANIC = 0x80 };
enum { PEDSTAT_PLAYER = 0, PEDSTAT_COP = 1, PEDSTAT_MEDIC = 2, PEDSTAT_FIREMAN = 3,
       PEDSTAT_GANG1 = 4, PEDSTAT_GANG2 = 5, PEDSTAT_GANG3 = 6, PEDSTAT_GANG4 = 7,
       PEDSTAT_GANG5 = 8, PEDSTAT_GANG6 = 9, PEDSTAT_GANG7 = 10,
       PEDSTAT_STD_MISSION = 38, NUM_PEDSTATS = 40 };
```

Replace `struct CPedType` (lines 77-83) with a gang-aware threat table:

```c
struct CPedType {
    static uint32 GetThreats(int type) {
        static const uint32 gangBits[] = { PED_FLAG_GANG1, PED_FLAG_GANG2, PED_FLAG_GANG3,
            PED_FLAG_GANG4, PED_FLAG_GANG5, PED_FLAG_GANG6, PED_FLAG_GANG7,
            PED_FLAG_GANG8, PED_FLAG_GANG9 };
        if (type >= PEDTYPE_GANG1 && type <= PEDTYPE_GANG9) {
            uint32 mask = PED_FLAG_GUN | PED_FLAG_EXPLOSION;
            for (int g = 0; g < 9; g++)
                if (g != type - PEDTYPE_GANG1) mask |= gangBits[g];
            return mask;
        }
        return PED_FLAG_GUN | PED_FLAG_EXPLOSION | PED_FLAG_DEADPEDS;
    }
};
```

Replace the `CPedStats` block (lines 84-86) with a full table plus a `g_bodyStat` alias:

```c
struct CPedStats { int m_type; int8_t m_fear, m_temper; int16_t m_flags; float m_headingChangeRate;
                   static CPedStats *ms_apPedStats[NUM_PEDSTATS]; };
static CPedStats aStats[NUM_PEDSTATS];
CPedStats *CPedStats::ms_apPedStats[NUM_PEDSTATS];
static CPedStats &g_bodyStat = aStats[PEDSTAT_STD_MISSION];
```

Insert the model-info stubs before `struct CGeneral` (line 94):

```c
enum { MITYPE_OTHER = 0, MITYPE_PED = 3 };
struct CBaseModelInfo {
    int m_type;
    int GetModelType(void) { return m_type; }
    CBaseModelInfo(void) : m_type(MITYPE_PED) {}
};
struct CPedModelInfo : CBaseModelInfo {
    int m_pedType, m_pedStatType;
    CPedModelInfo(void) : m_pedType(PEDTYPE_CIVMALE), m_pedStatType(PEDSTAT_STD_MISSION) {}
};
static CPedModelInfo aModels[MI_COUNT];
struct CModelInfo {
    static CBaseModelInfo *GetModelInfo(int id) {
        return id >= 0 && id < MI_COUNT ? (CBaseModelInfo *)&aModels[id] : nil;
    }
};
```

After the `CPlayerPed` struct (line 220), add:

```c
static CPlayerPed *g_player;
static CPlayerPed *FindPlayerPed(void) { return g_player; }
```

Delete the old stubs `static CPedStats g_bodyStat;` and
`static CPedStats *VCModNpcCivilianBodyStats(CPlayerPed *) { return &g_bodyStat; }`
(lines 260-261); the real helpers are extracted instead.

In `setup()`, replace the stat lines (lines 309-311) with:

```python
    bVCModNpcAutoType = false;
    for (int i = 0; i < NUM_PEDSTATS; i++) {
        CPedStats::ms_apPedStats[i] = &aStats[i];
        aStats[i].m_type = i; aStats[i].m_fear = 50; aStats[i].m_temper = 50;
        aStats[i].m_flags = 0; aStats[i].m_headingChangeRate = 5.0f;
    }
    aStats[PEDSTAT_PLAYER].m_headingChangeRate = 15.0f;
    aStats[PEDSTAT_GANG7].m_headingChangeRate = 7.5f;
    for (int i = PEDSTAT_GANG1; i <= PEDSTAT_GANG7; i++) aStats[i].m_headingChangeRate = 7.0f;
    g_bodyStat.m_type = 99; g_bodyStat.m_headingChangeRate = 6.0f;
    aModels[MI_PLAYER].m_type = MITYPE_PED;  aModels[MI_PLAYER].m_pedType = PEDTYPE_PLAYER1;  aModels[MI_PLAYER].m_pedStatType = PEDSTAT_PLAYER;
    aModels[MI_COP].m_type = MITYPE_PED;     aModels[MI_COP].m_pedType = PEDTYPE_COP;          aModels[MI_COP].m_pedStatType = PEDSTAT_COP;
    aModels[MI_SWAT].m_type = MITYPE_PED;    aModels[MI_SWAT].m_pedType = PEDTYPE_COP;         aModels[MI_SWAT].m_pedStatType = PEDSTAT_COP;
    aModels[MI_FBI].m_type = MITYPE_PED;     aModels[MI_FBI].m_pedType = PEDTYPE_COP;          aModels[MI_FBI].m_pedStatType = PEDSTAT_COP;
    aModels[MI_ARMY].m_type = MITYPE_PED;    aModels[MI_ARMY].m_pedType = PEDTYPE_COP;         aModels[MI_ARMY].m_pedStatType = PEDSTAT_COP;
    aModels[MI_MALE01].m_type = MITYPE_PED;  aModels[MI_MALE01].m_pedType = PEDTYPE_CIVMALE;   aModels[MI_MALE01].m_pedStatType = PEDSTAT_STD_MISSION;
    aModels[MI_CUBAN].m_type = MITYPE_PED;   aModels[MI_CUBAN].m_pedType = PEDTYPE_GANG1;      aModels[MI_CUBAN].m_pedStatType = PEDSTAT_GANG1;
    aModels[MI_HAITIAN].m_type = MITYPE_PED; aModels[MI_HAITIAN].m_pedType = PEDTYPE_GANG2;    aModels[MI_HAITIAN].m_pedStatType = PEDSTAT_GANG2;
    aModels[MI_SHARK].m_type = MITYPE_PED;   aModels[MI_SHARK].m_pedType = PEDTYPE_GANG3;      aModels[MI_SHARK].m_pedStatType = PEDSTAT_GANG3;
    aModels[MI_DIAZ].m_type = MITYPE_PED;    aModels[MI_DIAZ].m_pedType = PEDTYPE_GANG4;       aModels[MI_DIAZ].m_pedStatType = PEDSTAT_GANG4;
    aModels[MI_GANG5].m_type = MITYPE_PED;   aModels[MI_GANG5].m_pedType = PEDTYPE_GANG5;      aModels[MI_GANG5].m_pedStatType = PEDSTAT_GANG5;
    aModels[MI_BIKER].m_type = MITYPE_PED;   aModels[MI_BIKER].m_pedType = PEDTYPE_GANG6;      aModels[MI_BIKER].m_pedStatType = PEDSTAT_GANG6;
    aModels[MI_VERCETTI].m_type = MITYPE_PED; aModels[MI_VERCETTI].m_pedType = PEDTYPE_GANG7;  aModels[MI_VERCETTI].m_pedStatType = PEDSTAT_GANG7;
    aModels[MI_MEDIC].m_type = MITYPE_PED;   aModels[MI_MEDIC].m_pedType = PEDTYPE_EMERGENCY;  aModels[MI_MEDIC].m_pedStatType = PEDSTAT_MEDIC;
    aModels[MI_FIREMAN].m_type = MITYPE_PED; aModels[MI_FIREMAN].m_pedType = PEDTYPE_FIREMAN;  aModels[MI_FIREMAN].m_pedStatType = PEDSTAT_FIREMAN;
    aModels[MI_SPECIAL01].m_type = MITYPE_PED; aModels[MI_SPECIAL01].m_pedType = PEDTYPE_CIVMALE; aModels[MI_SPECIAL01].m_pedStatType = PEDSTAT_STD_MISSION;
    aModels[MI_NOT_PED].m_type = MITYPE_OTHER;
```

At the end of `setup()` (after `CPlayerPed p; CPad pad;`) add:

```python
    p.m_modelIndex = MI_MALE01;
    g_player = &p;
```

Add `#include <cstring>` at the top of `STUBS` (StrongStats uses `memcpy`).

- [ ] **Step 2: Extend the extraction list**

In `test_vc_npcmode.py`, replace `SIGS` with this order (dependencies first):

```python
SIGS = [
    "static int32\nVCModNpcBodyProfile(CPlayerPed *player)",
    "int32\nVCModNpcEffectiveType(void)",
    "int32\nVCModNpcGangType(CPlayerPed *player)",
    "static CPedStats *\nVCModNpcStrongStats(void)",
    "static CPedStats *\nVCModNpcBodyStats(CPlayerPed *player)",
    "static CPedStats *\nVCModNpcCivilianBodyStats(CPlayerPed *player)",
    "static void\nVCModNpcRestoreStatBorrow(CPlayerPed *player)",
    "bool\nVCModStreetWanderOwnsPlayer(void)",
    "bool\nVCModNpcCivilianActive(void)",
    "bool\nVCModNpcGangActive(void)",
    "bool\nVCModNpcCopActive(void)",
    "static void\nVCModNpcIdCheckHold(CPlayerPed *player, uint32 now)",
    "void\nVCModStreetEndWander(CPlayerPed *player, const char *why)",
    "void\nVCModStreetStartWander(CPlayerPed *player)",
    "static int32\nVCModNpcModeBreak(CPlayerPed *player, CPad *pad)",
    "static bool\nVCModNpcBodyDirty(CPlayerPed *player)",
    "static void\nVCModNpcReleasePed(CPlayerPed *player)",
    "void\nVCModUpdateNpcMode(CPlayerPed *player, CPad *pad)",
]
```

- [ ] **Step 3: Add the mapping tests**

Append a new class before `if __name__ == "__main__":`:

```python
class AutoTypeTests(unittest.TestCase):
    def test_profile_follows_the_stock_ped_type(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup() + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_PLAYER;
    if (VCModNpcEffectiveType() != VCMOD_NPC_GANG) return 1;
    p.m_modelIndex = MI_COP;     if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 2;
    p.m_modelIndex = MI_SWAT;    if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 3;
    p.m_modelIndex = MI_FBI;     if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 4;
    p.m_modelIndex = MI_ARMY;    if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 5;
    int gangs[] = { MI_CUBAN, MI_HAITIAN, MI_SHARK, MI_DIAZ, MI_GANG5, MI_BIKER, MI_VERCETTI };
    for (int i = 0; i < 7; i++) {
        p.m_modelIndex = gangs[i];
        if (VCModNpcEffectiveType() != VCMOD_NPC_GANG) return 10 + i;
    }
    p.m_modelIndex = MI_MEDIC;      if (VCModNpcEffectiveType() != VCMOD_NPC_CIVILIAN) return 20;
    p.m_modelIndex = MI_FIREMAN;    if (VCModNpcEffectiveType() != VCMOD_NPC_CIVILIAN) return 21;
    p.m_modelIndex = MI_SPECIAL01;  if (VCModNpcEffectiveType() != VCMOD_NPC_CIVILIAN) return 22;
    int others[] = { PEDTYPE_CIVFEMALE, PEDTYPE_CRIMINAL, PEDTYPE_PROSTITUTE, PEDTYPE_SPECIAL };
    for (int i = 0; i < 4; i++) {
        aModels[MI_MALE01].m_pedType = others[i];
        p.m_modelIndex = MI_MALE01;
        if (VCModNpcEffectiveType() != VCMOD_NPC_CIVILIAN) return 30 + i;
    }
    return 0;
}
''')

    def test_gang_type_follows_the_body(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup() + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_PLAYER;
    if (VCModNpcGangType(&p) != PEDTYPE_GANG7) return 1;
    p.m_modelIndex = MI_CUBAN;    if (VCModNpcGangType(&p) != PEDTYPE_GANG1) return 2;
    p.m_modelIndex = MI_HAITIAN;  if (VCModNpcGangType(&p) != PEDTYPE_GANG2) return 3;
    p.m_modelIndex = MI_SHARK;    if (VCModNpcGangType(&p) != PEDTYPE_GANG3) return 4;
    p.m_modelIndex = MI_DIAZ;     if (VCModNpcGangType(&p) != PEDTYPE_GANG4) return 5;
    p.m_modelIndex = MI_GANG5;    if (VCModNpcGangType(&p) != PEDTYPE_GANG5) return 6;
    p.m_modelIndex = MI_BIKER;    if (VCModNpcGangType(&p) != PEDTYPE_GANG6) return 7;
    p.m_modelIndex = MI_VERCETTI; if (VCModNpcGangType(&p) != PEDTYPE_GANG7) return 8;
    p.m_modelIndex = MI_MALE01;   if (VCModNpcGangType(&p) != PEDTYPE_GANG7) return 9;
    bVCModNpcAutoType = false;
    p.m_modelIndex = MI_CUBAN;    if (VCModNpcGangType(&p) != PEDTYPE_GANG7) return 10;
    return 0;
}
''')

    def test_auto_off_keeps_the_manual_profile(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup() + r'''
    p.m_modelIndex = MI_CUBAN;
    nVCModNpcType = VCMOD_NPC_GANG;
    if (VCModNpcEffectiveType() != VCMOD_NPC_GANG) return 1;
    if (VCModNpcGangType(&p) != PEDTYPE_GANG7) return 2;
    nVCModNpcType = VCMOD_NPC_COP;
    if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 3;
    if (!VCModNpcCopActive()) return 4;
    if (VCModNpcGangActive() || VCModNpcCivilianActive()) return 5;
    return 0;
}
''')

    def test_non_ped_body_falls_back_to_manual(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup() + r'''
    bVCModNpcAutoType = true;
    nVCModNpcType = VCMOD_NPC_COP;
    p.m_modelIndex = MI_NOT_PED;
    if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 1;
    if (VCModNpcGangType(&p) != PEDTYPE_GANG7) return 2;
    g_player = nil;
    if (VCModNpcEffectiveType() != VCMOD_NPC_COP) return 3;
    return 0;
}
''')

    def test_the_body_picks_the_branch(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    bVCModStreetWander = true;
    p.m_modelIndex = MI_CUBAN;
    VCModUpdateNpcMode(&p, &pad);
    if (!''' + has("civilianState") + r''') return 1;
    if (''' + has("patrol") + r''') return 2;
    events.clear();
    p.m_modelIndex = MI_SWAT;
    VCModUpdateNpcMode(&p, &pad);
    if (!''' + has("patrol") + r''') return 3;
    if (''' + has("civilianState") + r''') return 4;
    return 0;
}
''')

    def test_a_body_change_reloads_the_profile_state(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    bVCModStreetWander = true;
    p.m_modelIndex = MI_CUBAN;
    VCModUpdateNpcMode(&p, &pad);
    if (!''' + has("initCivilian") + r''') return 1;
    events.clear();
    p.m_modelIndex = MI_MALE01;                 // gang -> civilian: reload
    VCModUpdateNpcMode(&p, &pad);
    if (!''' + has("initCivilian") + r''') return 2;
    events.clear();
    p.m_modelIndex = MI_HAITIAN;                // civilian -> gang: reload
    VCModUpdateNpcMode(&p, &pad);
    if (!''' + has("initCivilian") + r''') return 3;
    events.clear();
    p.m_modelIndex = MI_VERCETTI;               // gang -> gang: same profile, no reload
    VCModUpdateNpcMode(&p, &pad);
    if (''' + has("initCivilian") + r''') return 4;
    return 0;
}
''')
```

- [ ] **Step 4: Run the harness to verify it fails**

Run: `cd reVC/utils && python3 -m unittest test_vc_npcmode -v`
Expected: FAIL — `braced` raises `ValueError: substring not found` for `VCModNpcBodyProfile` (the helpers do not exist yet).

- [ ] **Step 5: Implement the flag and helpers**

In `vcmodnpc.h`, after `extern int32 nVCModNpcType;` add:

```c
// the worn body picks the profile and gang while this is on; off is the manual
// NPC TYPE value, exactly as before
extern bool bVCModNpcAutoType;
```

After the three active predicates add:

```c
// the profile in force: the worn body's while BECOME NPC and TYPE FROM BODY are
// both on, the manual NPC TYPE otherwise
int32 VCModNpcEffectiveType(void);
// the gang the worn body belongs to; MI_PLAYER and every non-gang body are GANG7
int32 VCModNpcGangType(CPlayerPed *player);
```

In `vcmodnpc.cpp`, add the flag next to the others:

```c
bool bVCModNpcMode = false;
int32 nVCModNpcType = 0;
bool bVCModNpcAutoType = true;
bool bVCModCopQuickChecks = false;
```

Insert the helpers immediately before `VCModNpcStrongStats` (line 258):

```c
// the profile the worn model's stock ped type picks: players and gang bodies
// walk as gang, police bodies patrol, every other body is a civilian. A nil
// player or a non-ped model keeps the manual profile
static int32
VCModNpcBodyProfile(CPlayerPed *player)
{
	if (player == nil)
		return nVCModNpcType;
	CBaseModelInfo *mi = CModelInfo::GetModelInfo(player->GetModelIndex());
	if (mi == nil || mi->GetModelType() != MITYPE_PED)
		return nVCModNpcType;
	int32 type = ((CPedModelInfo *)mi)->m_pedType;
	if (type == PEDTYPE_PLAYER1 || (type >= PEDTYPE_GANG1 && type <= PEDTYPE_GANG9))
		return VCMOD_NPC_GANG;
	if (type == PEDTYPE_COP)
		return VCMOD_NPC_COP;
	return VCMOD_NPC_CIVILIAN;
}

int32
VCModNpcEffectiveType(void)
{
	if (!bVCModNpcMode || !bVCModNpcAutoType)
		return nVCModNpcType;
	return VCModNpcBodyProfile(FindPlayerPed());
}

// the worn body's gang; a manual GANG keeps Vercetti GANG7 on any skin, and
// MI_PLAYER and every non-gang body keep it too
int32
VCModNpcGangType(CPlayerPed *player)
{
	if (!bVCModNpcAutoType || player == nil)
		return PEDTYPE_GANG7;
	CBaseModelInfo *mi = CModelInfo::GetModelInfo(player->GetModelIndex());
	if (mi == nil || mi->GetModelType() != MITYPE_PED)
		return PEDTYPE_GANG7;
	int32 type = ((CPedModelInfo *)mi)->m_pedType;
	if (type >= PEDTYPE_GANG1 && type <= PEDTYPE_GANG9)
		return type;
	return PEDTYPE_GANG7;
}
```

Replace the three active predicates and the strong check:

```c
bool
VCModNpcCivilianActive(void)
{
	return bVCModNpcMode && VCModNpcEffectiveType() == VCMOD_NPC_CIVILIAN;
}

bool
VCModNpcGangActive(void)
{
	return bVCModNpcMode && VCModNpcEffectiveType() == VCMOD_NPC_GANG;
}

bool
VCModNpcCopActive(void)
{
	return bVCModNpcMode && VCModNpcEffectiveType() == VCMOD_NPC_COP;
}

bool
VCModNpcStrongActive(void)
{
	if (!bVCModNpcMode || VCModNpcEffectiveType() != VCMOD_NPC_CIVILIAN)
		return false;
	CPlayerPed *player = FindPlayerPed();
	return player != nil && player->GetModelIndex() == MI_PLAYER;
}
```

In `VCModNpcCopScanDiag`, change the gate:

```c
	if (!bVCModNpcMode || VCModNpcEffectiveType() != VCMOD_NPC_COP || !cop->IsPlayer())
		return;
```

Replace `VCModNpcCivilianBodyStats` with the body-stat helper pair:

```c
// the worn body's stock stat; a data gap borrows the PLAYER numbers rather than
// an out-of-bounds table entry
static CPedStats *
VCModNpcBodyStats(CPlayerPed *player)
{
	CBaseModelInfo *mi = CModelInfo::GetModelInfo(player->GetModelIndex());
	if (mi == nil || mi->GetModelType() != MITYPE_PED)
		return CPedStats::ms_apPedStats[PEDSTAT_PLAYER];
	int32 stat = ((CPedModelInfo *)mi)->m_pedStatType;
	if (stat < 0 || stat >= NUM_PEDSTATS)
		return CPedStats::ms_apPedStats[PEDSTAT_PLAYER];
	return CPedStats::ms_apPedStats[stat];
}

static CPedStats *
VCModNpcCivilianBodyStats(CPlayerPed *player)
{
	if (player->GetModelIndex() == MI_PLAYER)
		return VCModNpcStrongStats();
	return VCModNpcBodyStats(player);
}
```

Change the engage log:

```c
			VCMOD_DIAG("VCMOD npc mode: engaged type=%d gang=%d\n",
				VCModNpcEffectiveType(), VCModNpcGangType(player));
```

Change the profile-switch comparison:

```c
	// switching profile reloads the civilian state, the way a fresh engage would
	int32 profile = VCModNpcEffectiveType();
	if (profile != nVCModNpcStateProfile) {
		nVCModNpcStateProfile = profile;
		bVCModNpcStateInit = false;
	}
```

Change the three dispatch branches (`if (nVCModNpcType == ...)`) to compare `profile`:

```c
		if (profile == VCMOD_NPC_CIVILIAN) {
```

```c
		} else if (profile == VCMOD_NPC_GANG) {
```

```c
		} else if (profile == VCMOD_NPC_COP) {
```

- [ ] **Step 6: Update the dependent harness stubs**

In `test_vc_npcstrong.py`: add to `STATICS` (after `nVCModNpcType;`):

```c
int32 VCModNpcEffectiveType(void) { return nVCModNpcType; }
```

and add to `SIGS` before `VCModNpcCivilianBodyStats`:

```python
    "static CPedStats *\nVCModNpcBodyStats(CPlayerPed *player)",
```

In `test_vc_ganggaze.py`: after `int nVCModNpcType = VCMOD_NPC_GANG;` add:

```c
int32 VCModNpcEffectiveType(void) { return nVCModNpcType; }
```

In `test_vc_character.py` and `test_vc_adrenaline.py`: replace the shared definitions line

```python
        definitions += "\nint32 nVCModAdrenalineMode;\nbool bVCModStreetIdle = true;\nbool bVCModNpcMode = false;\nint32 nVCModNpcType = 0;\nbool bVCModCopQuickChecks = false;\nint32 nVCModRideZone;\nint32 nVCModRideStyle;"
```

with

```python
        definitions += "\nint32 nVCModAdrenalineMode;\nbool bVCModStreetIdle = true;\nbool bVCModNpcMode = false;\nbool bVCModNpcAutoType = false;\nint32 nVCModNpcType = 0;\nbool bVCModCopQuickChecks = false;\nint32 nVCModRideZone;\nint32 nVCModRideStyle;\nint32 VCModNpcEffectiveType(void) { return nVCModNpcType; }"
```

- [ ] **Step 7: Run the harnesses**

Run: `cd reVC/utils && python3 -m unittest test_vc_npcmode test_vc_npcstrong test_vc_ganggaze test_vc_character test_vc_adrenaline -v`
Expected: PASS (all mapping tests plus the untouched regression tests).

---

### Task 2: Identity borrow and the gang effective type

**Files:**
- Modify: `reVC/src/extras/vcmodnpc.cpp:455-496` (borrow block → `VCModNpcBorrowIdentity`), `:461-464` (call site)
- Modify: `reVC/src/extras/vcmodgang.cpp:16-24` (`VCModGangEffectiveType`)
- Test: `reVC/utils/test_vc_npcmode.py` (borrow tests)
- Test: `reVC/utils/test_vc_gangfaction.py` (stub rework + borrow/identity tests)

**Interfaces:**
- Consumes: `VCModNpcGangType`, `VCModNpcBodyStats`, `VCModNpcCivilianBodyStats`, `VCModNpcRestoreStatBorrow` (Task 1).
- Produces: `static void VCModNpcBorrowIdentity(CPlayerPed *player, bool civilianWander, bool gangWander)` — sets `CharCreatedBy`, `m_fearFlags`, `m_pedStats`, `m_headingRate` and `m_gangFlags`; restores through `VCModNpcRestoreStatBorrow` when neither profile borrows.
- Rule: the body stat is borrowed only while TYPE FROM BODY is on. Off is the manual profile, and manual GANG keeps the GANG7 stat and mask on any skin exactly as build 533 did (the spec's auto-off baseline wins over the helper's shorthand).
- Produces: `VCModGangEffectiveType(CPed *ped)` returns `VCModNpcGangType((CPlayerPed *)ped)` for an active GANG player.

- [ ] **Step 1: Add the failing borrow tests to `test_vc_npcmode.py`**

Add `"static void\nVCModNpcBorrowIdentity(CPlayerPed *player, bool civilianWander, bool gangWander)",` to `SIGS` after `VCModNpcRestoreStatBorrow`, then append:

```python
class BodyBorrowTests(unittest.TestCase):
    def test_a_gang_body_borrows_its_own_identity(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_CUBAN;
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.CharCreatedBy != RANDOM_CHAR) return 1;
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG1]) return 2;
    if (p.m_headingRate != 7.0f) return 3;
    if (p.m_fearFlags != CPedType::GetThreats(PEDTYPE_GANG1)) return 4;
    if (p.m_gangFlags != (uint8)~(1 << (PEDTYPE_GANG1 - PEDTYPE_GANG1))) return 5;
    if (p.m_fearFlags & PED_FLAG_GANG1) return 6;
    if (!(p.m_fearFlags & PED_FLAG_GANG7)) return 7;
    return 0;
}
''')

    def test_tommys_body_keeps_gang7(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_PLAYER;
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG7]) return 1;
    if (p.m_fearFlags != CPedType::GetThreats(PEDTYPE_GANG7)) return 2;
    if (p.m_gangFlags != (uint8)~(1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1))) return 3;
    return 0;
}
''')

    def test_auto_off_keeps_gang7_on_any_skin(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    p.m_modelIndex = MI_CUBAN;
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG7]) return 1;
    if (p.m_fearFlags != CPedType::GetThreats(PEDTYPE_GANG7)) return 2;
    if (p.m_gangFlags != (uint8)~(1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1))) return 3;
    return 0;
}
''')

    def test_a_gang_to_gang_body_change_reresolves_the_stat(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_CUBAN;
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG1]) return 1;
    events.clear();
    p.m_modelIndex = MI_HAITIAN;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG2]) return 2;
    if (p.m_gangFlags != (uint8)~(1 << (PEDTYPE_GANG2 - PEDTYPE_GANG1))) return 3;
    if (p.m_fearFlags != CPedType::GetThreats(PEDTYPE_GANG2)) return 4;
    if (p.CharCreatedBy != RANDOM_CHAR) return 5;
    if (''' + has("initCivilian") + r''') return 6;
    return 0;
}
''')

    def test_a_gang_body_restores_on_toggle_off(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_CUBAN;
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    CPedStats *own = CPedStats::ms_apPedStats[PEDSTAT_PLAYER];
    if (p.m_pedStats == own) return 1;
    bVCModNpcMode = false; bVCModNpcModeWasOn = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.m_pedStats != own) return 2;
    if (p.m_gangFlags != 0xFF) return 3;
    if (p.m_headingRate != 15.0f) return 4;
    return 0;
}
''')

    def test_a_medic_body_is_a_civilian_with_its_own_stat(self):
        run_cpp(npc_source() + r'''
int main(void) {
''' + setup(profile="VCMOD_NPC_GANG", state="PED_WANDER_PATH") + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_MEDIC;
    bVCModStreetWander = true;
    VCModUpdateNpcMode(&p, &pad);
    if (p.CharCreatedBy != RANDOM_CHAR) return 1;
    if (p.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_MEDIC]) return 2;
    if (p.m_fearFlags != CPedType::GetThreats(PEDTYPE_CIVMALE)) return 3;
    if (p.m_gangFlags != 0xFF) return 4;
    return 0;
}
''')
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd reVC/utils && python3 -m unittest test_vc_npcmode -v`
Expected: FAIL — `braced` raises `ValueError` for `VCModNpcBorrowIdentity`.

- [ ] **Step 3: Implement `VCModNpcBorrowIdentity`**

In `vcmodnpc.cpp`, add the helper after `VCModNpcCivilianBodyStats` (it calls `VCModNpcRestoreStatBorrow`, which is defined later; move `VCModNpcRestoreStatBorrow` above the helper):

```c
static void
VCModNpcRestoreStatBorrow(CPlayerPed *player)
{
	if (bVCModNpcStatsBorrowed) {
		player->m_pedStats = pVCModNpcSavedStats;
		player->m_gangFlags = nVCModNpcSavedGangFlags;
		player->m_headingRate = player->m_pedStats->m_headingChangeRate;
		bVCModNpcStatsBorrowed = false;
	}
}

// the profile's identity: civilian bodies read as random pedestrians and borrow
// their own stat, gang bodies read as the worn gang and borrow its stat plus the
// kin mask, cops keep the mission setup. A manual profile keeps GANG7 for any
// skin. The originals restore on break/off/switch
static void
VCModNpcBorrowIdentity(CPlayerPed *player, bool civilianWander, bool gangWander)
{
	int32 gangType = VCModNpcGangType(player);
	player->CharCreatedBy = (civilianWander || gangWander) ? RANDOM_CHAR : MISSION_CHAR;
	player->m_fearFlags = CPedType::GetThreats(civilianWander ? PEDTYPE_CIVMALE
		: gangWander ? gangType : player->m_nPedType);

	CPedStats *borrowedStats = nil;
	if (gangWander)
		// auto on reaches a gang body only through its own type; auto off is the
		// manual GANG, which keeps the Vercetti stat on any skin as it always did
		borrowedStats = bVCModNpcAutoType && player->GetModelIndex() != MI_PLAYER
			? VCModNpcBodyStats(player) : CPedStats::ms_apPedStats[PEDSTAT_GANG7];
	else if (civilianWander)
		borrowedStats = VCModNpcCivilianBodyStats(player);

	if (borrowedStats) {
		if (!bVCModNpcStatsBorrowed) {
			pVCModNpcSavedStats = player->m_pedStats;
			nVCModNpcSavedGangFlags = player->m_gangFlags;
			bVCModNpcStatsBorrowed = true;
		}
		// the body's own turn rate, stock; a mid-mode body change re-applies it,
		// and wait states still own it afterwards
		if (player->m_pedStats != borrowedStats) {
			player->m_headingRate = borrowedStats->m_headingChangeRate;
			VCMOD_DIAG("VCMOD npc body: model=%d stat=%d fear=%d temper=%d\n",
				player->GetModelIndex(), (int)borrowedStats->m_type,
				(int)borrowedStats->m_fear, (int)borrowedStats->m_temper);
		}
		player->m_pedStats = borrowedStats;
		player->m_gangFlags = gangWander
			? (uint8)~(1 << (gangType - PEDTYPE_GANG1))
			: nVCModNpcSavedGangFlags;
	} else {
		VCModNpcRestoreStatBorrow(player);
	}
}
```

Delete the old `VCModNpcRestoreStatBorrow` definition at its former place (one definition only).

- [ ] **Step 4: Replace the inline borrow block in `VCModUpdateNpcMode`**

Replace everything from the `bool bCivilianWander = ...` line through the end of the `} else { VCModNpcRestoreStatBorrow(player); }` block with:

```c
	bool bCivilianWander = VCModNpcCivilianActive() && VCModStreetWanderOwnsPlayer();
	bool bGangWander = VCModNpcGangActive() && VCModStreetWanderOwnsPlayer();
	VCModNpcBorrowIdentity(player, bCivilianWander, bGangWander);

	int32 profile = VCModNpcEffectiveType();
	// switching profile reloads the civilian state, the way a fresh engage would
	if (profile != nVCModNpcStateProfile) {
		nVCModNpcStateProfile = profile;
		bVCModNpcStateInit = false;
	}
```

- [ ] **Step 5: Implement the gang effective type**

In `vcmodgang.cpp`, add `#include "PlayerPed.h"` after `#include "vcmodnpc.h"`, and replace the helper:

```c
// the gang profile reads the worn body's gang for the gang bit/type decisions
// while his real type stays PLAYER1; with TYPE FROM BODY off the worn body is
// GANG7, which is the manual GANG behaviour. Every other ped reports his own
// type unchanged
int32
VCModGangEffectiveType(CPed *ped)
{
	if (ped->IsPlayer() && VCModNpcGangActive())
		return VCModNpcGangType((CPlayerPed *)ped);
	return ped->m_nPedType;
}
```

- [ ] **Step 6: Run the npcmode harness**

Run: `cd reVC/utils && python3 -m unittest test_vc_npcmode -v`
Expected: PASS.

- [ ] **Step 7: Add the failing identity/borrow tests to `test_vc_gangfaction.py`**

Extend the primary `STUBS` in `test_vc_gangfaction.py`:

1. Replace the ped type enum with the real-order enum from Task 1 Step 1.
2. Replace `CPedType` with the gang-aware `GetThreats` from Task 1 Step 1.
3. Add, before `struct CPed`:

```c
#include <cstring>
enum { STAT_GUN_PANIC = 0x80 };
enum { PEDSTAT_PLAYER = 0, PEDSTAT_COP = 1, PEDSTAT_MEDIC = 2, PEDSTAT_FIREMAN = 3,
       PEDSTAT_GANG1 = 4, PEDSTAT_GANG2 = 5, PEDSTAT_GANG3 = 6, PEDSTAT_GANG4 = 7,
       PEDSTAT_GANG5 = 8, PEDSTAT_GANG6 = 9, PEDSTAT_GANG7 = 10,
       PEDSTAT_STD_MISSION = 38, NUM_PEDSTATS = 40 };
struct CPedStats { int m_type; int8_t m_fear, m_temper; int16_t m_flags; float m_headingChangeRate;
                   static CPedStats *ms_apPedStats[NUM_PEDSTATS]; };
static CPedStats aStats[NUM_PEDSTATS];
CPedStats *CPedStats::ms_apPedStats[NUM_PEDSTATS];
enum { MI_PLAYER, MI_SWAT, MI_CUBAN, MI_MALE01, MI_NOT_PED, MI_COUNT };
enum { MITYPE_OTHER = 0, MITYPE_PED = 3 };
struct CBaseModelInfo { int m_type; int GetModelType(void) { return m_type; } };
struct CPedModelInfo : CBaseModelInfo { int m_pedType, m_pedStatType; };
static CPedModelInfo aModels[MI_COUNT];
struct CModelInfo {
    static CBaseModelInfo *GetModelInfo(int id) {
        return id >= 0 && id < MI_COUNT ? (CBaseModelInfo *)&aModels[id] : nil;
    }
};
bool bVCModNpcAutoType = false;
```

4. Extend `CPed` with:

```c
    int m_modelIndex;
    CPedStats *m_pedStats;
    float m_headingRate;
    uint32 m_fearFlags;
    int CharCreatedBy;
    int GetModelIndex(void) { return m_modelIndex; }
```

and initialise them in the constructor body/initialiser list: `m_modelIndex(MI_MALE01)`, `m_pedStats(CPedStats::ms_apPedStats[PEDSTAT_PLAYER])`, `m_headingRate(0.0f)`, `m_fearFlags(0)`, `CharCreatedBy(MISSION_CHAR)`.

5. After the `CPed` struct add:

```c
typedef CPed CPlayerPed;
static CPlayerPed *g_player;
static CPlayerPed *FindPlayerPed(void) { return g_player; }
static CPedStats *pVCModNpcSavedStats = nil;
static uint8 nVCModNpcSavedGangFlags = 0;
static bool bVCModNpcStatsBorrowed = false;
static void ResetPedStats(void) {
    for (int i = 0; i < NUM_PEDSTATS; i++) {
        CPedStats::ms_apPedStats[i] = &aStats[i];
        aStats[i].m_type = i; aStats[i].m_fear = 50; aStats[i].m_temper = 50;
        aStats[i].m_flags = 0; aStats[i].m_headingChangeRate = 5.0f;
    }
    aStats[PEDSTAT_PLAYER].m_headingChangeRate = 15.0f;
    aStats[PEDSTAT_GANG7].m_headingChangeRate = 7.5f;
    for (int i = PEDSTAT_GANG1; i <= PEDSTAT_GANG7; i++) aStats[i].m_headingChangeRate = 7.0f;
    aModels[MI_PLAYER].m_type = MITYPE_PED; aModels[MI_PLAYER].m_pedType = PEDTYPE_PLAYER1; aModels[MI_PLAYER].m_pedStatType = PEDSTAT_PLAYER;
    aModels[MI_SWAT].m_type = MITYPE_PED; aModels[MI_SWAT].m_pedType = PEDTYPE_COP; aModels[MI_SWAT].m_pedStatType = PEDSTAT_COP;
    aModels[MI_CUBAN].m_type = MITYPE_PED; aModels[MI_CUBAN].m_pedType = PEDTYPE_GANG1; aModels[MI_CUBAN].m_pedStatType = PEDSTAT_GANG1;
    aModels[MI_MALE01].m_type = MITYPE_PED; aModels[MI_MALE01].m_pedType = PEDTYPE_CIVMALE; aModels[MI_MALE01].m_pedStatType = PEDSTAT_STD_MISSION;
    aModels[MI_NOT_PED].m_type = MITYPE_OTHER;
}
```

6. Replace the `GATE`/`EFF` constants and `src()` with the dependency bundle:

```python
PROF = "static int32\nVCModNpcBodyProfile(CPlayerPed *player)"
EFFECTIVE = "int32\nVCModNpcEffectiveType(void)"
GANGTYPE = "int32\nVCModNpcGangType(CPlayerPed *player)"
STRONG = "static CPedStats *\nVCModNpcStrongStats(void)"
BODYSTATS = "static CPedStats *\nVCModNpcBodyStats(CPlayerPed *player)"
CIVSTATS = "static CPedStats *\nVCModNpcCivilianBodyStats(CPlayerPed *player)"
RESTORE = "static void\nVCModNpcRestoreStatBorrow(CPlayerPed *player)"
BORROW = "static void\nVCModNpcBorrowIdentity(CPlayerPed *player, bool civilianWander, bool gangWander)"
GATE = "bool\nVCModNpcGangActive(void)"
EFF = "int32\nVCModGangEffectiveType(CPed *ped)"
ISGANG = "bool\nCPed::IsGangMember(void) const"
DMG = "bool\nCPed::CanBeDamagedByThisGangMember(CPed* who)"
REFUSE = "bool\nVCModGangRefuseFleeObjective(CPed *ped, int32 newObj)"
NOTE_OBJ = "void\nVCModGangNoteObjective(CPed *ped, int32 newObj)"
INTERRUPT = "void\nVCModGangInterruptKillPose(CPed *ped, int32 newObj)"

DEPS = [PROF, EFFECTIVE, GANGTYPE, STRONG, BODYSTATS, CIVSTATS, RESTORE, BORROW, GATE]

def src(*funcs):
    return STUBS + "\n".join(braced(NPC, s) for s in DEPS) + "\n" + "\n".join(funcs) + "\n"
```

Update every existing `src(braced(NPC, GATE), ...)` call to drop the `braced(NPC, GATE)` argument (the dependency bundle now includes it).

7. In `OBJ_STUBS` and `WANDER_STUBS`, add a stub next to `nVCModNpcType`:

```c
int32 VCModNpcEffectiveType(void) { return nVCModNpcType; }
```

(`int32` is already typedef'd in both; `WANDER_STUBS` has `int32 nVCModNpcType`.)

8. Append the tests:

```python
class BodyIdentityTests(unittest.TestCase):
    def test_effective_type_is_the_body_gang(self):
        run_cpp(src(braced(GANG, EFF)) + r'''
int main(void) {
    ResetPedStats();
    CPlayerPed tommy; tommy.m_isPlayer = true; tommy.m_nPedType = PEDTYPE_PLAYER1;
    tommy.m_modelIndex = MI_CUBAN;
    g_player = &tommy;
    bVCModNpcMode = true; bVCModNpcAutoType = true; nVCModNpcType = VCMOD_NPC_GANG;
    if (VCModGangEffectiveType(&tommy) != PEDTYPE_GANG1) return 1;
    tommy.m_modelIndex = MI_SWAT;
    if (VCModGangEffectiveType(&tommy) != PEDTYPE_PLAYER1) return 2;
    tommy.m_modelIndex = MI_CUBAN;
    bVCModNpcAutoType = false;
    if (VCModGangEffectiveType(&tommy) != PEDTYPE_GANG7) return 3;
    return 0;
}
''')

    def test_a_gang_body_borrows_its_own_identity(self):
        run_cpp(src() + r'''
int main(void) {
    ResetPedStats();
    CPed tommy; tommy.m_isPlayer = true; tommy.m_modelIndex = MI_CUBAN;
    bVCModNpcMode = true; bVCModNpcAutoType = true;
    VCModNpcBorrowIdentity(&tommy, false, true);
    if (tommy.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG1]) return 1;
    if (tommy.m_headingRate != 7.0f) return 2;
    if (tommy.m_fearFlags != CPedType::GetThreats(PEDTYPE_GANG1)) return 3;
    if (tommy.m_gangFlags != (uint8)~(1 << (PEDTYPE_GANG1 - PEDTYPE_GANG1))) return 4;
    if (tommy.CharCreatedBy != RANDOM_CHAR) return 5;
    return 0;
}
''')

    def test_the_manual_gang_keeps_gang7_on_any_skin(self):
        run_cpp(src() + r'''
int main(void) {
    ResetPedStats();
    CPed tommy; tommy.m_isPlayer = true; tommy.m_modelIndex = MI_CUBAN;
    bVCModNpcMode = true; bVCModNpcAutoType = false;
    VCModNpcBorrowIdentity(&tommy, false, true);
    if (tommy.m_pedStats != CPedStats::ms_apPedStats[PEDSTAT_GANG7]) return 1;
    if (tommy.m_fearFlags != CPedType::GetThreats(PEDTYPE_GANG7)) return 2;
    if (tommy.m_gangFlags != (uint8)~(1 << (PEDTYPE_GANG7 - PEDTYPE_GANG1))) return 3;
    return 0;
}
''')

    def test_the_borrow_restores_on_hand_back(self):
        run_cpp(src() + r'''
int main(void) {
    ResetPedStats();
    CPed tommy; tommy.m_isPlayer = true; tommy.m_modelIndex = MI_CUBAN;
    CPedStats *own = tommy.m_pedStats;
    uint8 ownFlags = tommy.m_gangFlags;
    bVCModNpcMode = true; bVCModNpcAutoType = true;
    VCModNpcBorrowIdentity(&tommy, false, true);
    if (tommy.m_pedStats == own) return 1;
    VCModNpcBorrowIdentity(&tommy, false, false);
    if (tommy.m_pedStats != own) return 2;
    if (tommy.m_gangFlags != ownFlags) return 3;
    if (tommy.m_headingRate != 15.0f) return 4;
    if (tommy.CharCreatedBy != MISSION_CHAR) return 5;
    return 0;
}
''')
```

- [ ] **Step 8: Run the gangfaction harness to verify it fails, then implement, then pass**

Run: `cd reVC/utils && python3 -m unittest test_vc_gangfaction -v`
Expected first: FAIL — the `BORROW` marker is missing (Task 2 Step 3 not yet written). With Steps 3 and 5 already applied above, this run is the green check.

Run again after the implementation edits if the first run was red.
Expected: PASS.

---

### Task 3: Panel row, NPC TYPE cycle, ini, debug menu, README

**Files:**
- Modify: `reVC/src/extras/vcmodpanelregistry.cpp:127-146` (getter/setter), `:220-223` (row), `:445-459` (debug tweak), `:467-473` (ALL ON comment)
- Modify: `reVC/src/core/re3.cpp:700-702` (ini read)
- Modify: `README.md:220` (toggles table)
- Test: `reVC/utils/test_vc_panel_info.py`, `reVC/utils/test_vc_npcmode.py`

**Interfaces:**
- Consumes: `bVCModNpcAutoType`, `VCModNpcEffectiveType` (Tasks 1-2).
- Produces: row `TYPE FROM BODY`, ini key `NpcAutoType`, debug switch `type follows body`.

- [ ] **Step 1: Add the failing panel tests**

In `test_vc_panel_info.py`, append:

```python
    def test_type_from_body_row(self):
        rows = table_rows()
        names = [fields[0].strip('"') for fields in rows]
        self.assertIn("TYPE FROM BODY", names)
        index = names.index("TYPE FROM BODY")
        self.assertEqual(names[index - 1], "NPC TYPE")
        row = rows[index]
        self.assertEqual(row[3], '"NpcAutoType"')
        self.assertEqual(row[4], "VCMOD_PAGE_WORLD")
        self.assertEqual(row[7], '"worn body picks profile and gang"')
        self.assertEqual(row[8], '"NPC TYPE is overridden while on"')
```

In `test_vc_npcmode.py`, add `PANEL = (ROOT / "src/extras/vcmodpanelregistry.cpp").read_text()` under the other file loads, and append a test:

```python
    def test_the_type_row_hands_control_back(self):
        run_cpp(npc_source() + "\n".join(braced(PANEL, s) for s in (
            "static int32\nVCModNpcTypeGet(void)",
            "static void\nVCModNpcTypeSet(int32 value)")) + r'''
int main(void) {
''' + setup() + r'''
    bVCModNpcAutoType = true;
    p.m_modelIndex = MI_CUBAN;
    if (VCModNpcTypeGet() != VCMOD_NPC_GANG) return 1;
    VCModNpcTypeSet(VCMOD_NPC_COP);
    if (bVCModNpcAutoType) return 2;
    if (nVCModNpcType != VCMOD_NPC_COP) return 3;
    if (VCModNpcTypeGet() != VCMOD_NPC_COP) return 4;
    return 0;
}
''')
```

- [ ] **Step 2: Run to verify failure**

Run: `cd reVC/utils && python3 -m unittest test_vc_panel_info test_vc_npcmode -v`
Expected: FAIL — `TYPE FROM BODY` missing from the table; the npcmode test fails at `VCModNpcTypeGet() != VCMOD_NPC_GANG` (the current getter returns the manual 0, and the setter does not clear auto).

- [ ] **Step 3: Implement the panel getter/setter and row**

Replace the NPC type getter/setter block:

```c
// the reaction profile NPC Tommy walks with; while TYPE FROM BODY is on the
// label follows the worn model, and a click takes manual control back
static int32
VCModNpcTypeGet(void)
{
	return VCModNpcEffectiveType();
}

static void
VCModNpcTypeSet(int32 value)
{
	bVCModNpcAutoType = false;
	nVCModNpcType = value;
}
```

Add the row after `NPC TYPE`:

```c
	{ "TYPE FROM BODY",  VCMOD_ROW_FLAG,    &bVCModNpcAutoType,    "NpcAutoType",    VCMOD_PAGE_WORLD, nil, -1,
	  "worn body picks profile and gang", "NPC TYPE is overridden while on" },
```

- [ ] **Step 4: Add the debug tweak and the ALL ON comment**

In `VCModTweaksWorld`, after `TWEAKINT32N(nVCModNpcType, ...)` add:

```c
TWEAKBOOLN(bVCModNpcAutoType, "type follows body");
```

Replace the ALL ON comment's first sentence with:

```c
// WALK MODE, NO STRAFE and TYPE FROM BODY are left out on purpose: they say how
// Tommy moves or how his body reads, not which mods are running, and losing them
// every time the combat switches get flipped together is the annoying version of
// a convenience button. ADRENALINE is out because it is a mode row now, and the
// master has no meaning to give it. NPC DOOM AIM is a challenge row: it scatters
// locked shots like an NPC's, so a master sweep that quietly turns it on reads
// as broken lock-on. CREW AGGRESSIVE is out for the same reason: a sweep would
// turn the crew's ride reckless.
```

Do **not** add `bVCModNpcAutoType` to `aVCModSwitched[]`.

- [ ] **Step 5: Add the ini read**

In `re3.cpp`, after the `nVCModNpcType` clamp:

```c
	ReadIniIfExists("VC Mods", "NpcAutoType", &bVCModNpcAutoType);
```

- [ ] **Step 6: Add the README row**

In the Toggles table, after the `bVCModNoStrafe` row:

```markdown
| `bVCModNpcAutoType` (row `TYPE FROM BODY`) | on | BECOME NPC derives the profile from the worn body's stock ped type: Tommy and gang bodies run GANG as the body's own gang, police bodies COP, every other body CIVILIAN. NPC TYPE shows the derived profile while it runs; cycling NPC TYPE turns this off and applies the chosen value |
```

- [ ] **Step 7: Run the harnesses**

Run: `cd reVC/utils && python3 -m unittest test_vc_panel_info test_vc_npcmode test_vc_character test_vc_adrenaline -v`
Expected: PASS.

---

### Task 4: Full suite and build

**Files:** none modified.

- [ ] **Step 1: Run every harness**

Run from `reVC/utils`:

```bash
for f in test_vc_*.py; do python3 "$f" || { echo "FAILED $f"; exit 1; }; done
```

Expected: all 45 suites pass (no `FAILED` line, exit 0).

- [ ] **Step 2: Build**

Run from the workspace root: `scripts/build.sh`
Expected: `built: .../reVC/build/src/reVC.app`, and `cat reVC/build/vcmods-build-number` shows `534`.

---

### Task 5: Install and hand off the play matrix

**Files:**
- Create: `docs/handoff/2026-11-14-body-type-banking.md`

- [ ] **Step 1: Confirm no game session is running**

Run: `pgrep -f "reVC.app/Contents/MacOS/reVC"`
Expected: no output. If a session is running, stop here and report it; do not kill it.

- [ ] **Step 2: Install**

Run: `scripts/install.sh`
Expected: `installed: ~/Games/VC/reVC.app`.

- [ ] **Step 3: Confirm the installed build number**

Run: `strings ~/Games/VC/reVC.app/Contents/MacOS/reVC | grep "vcmods build"`
Expected: `vcmods build 534`. Do not launch the game.

- [ ] **Step 4: Write the handoff**

Create `docs/handoff/2026-11-14-body-type-banking.md` with: repo/branch/HEAD, installed build number, what is uncommitted, the files not to touch, and this play matrix:

```markdown
## Play matrix

Auto on (TYPE FROM BODY row ON):
- Tommy: GANG7 as today; Vercetti spare/chat, rivals hunt, cops chase.
- A Cuban body: GANG1. Cubans spare/chat, rival gangs hunt, cops chase.
- A military body (army/swat/fbi/cop): COP foot patrol, no gang identity.
- A civilian body: CIVILIAN with that body's personality; a medic body is
  CIVILIAN with the medic stat.

Auto off:
- A military body with NPC TYPE GANG: today's GANG7 behaviour.
- Any body with NPC TYPE COP or CIVILIAN: unchanged from build 533.

Panel:
- Cycling NPC TYPE while auto is on turns TYPE FROM BODY off and applies the
  chosen profile.
- The NPC TYPE label follows the body while auto is on and NPC mode runs.

Lifecycle: toggle the mode off, die, enter a car, get arrested, change the body
mid-mode. Stats, fear flags and gang flags restore with no residue; the next
engage re-derives. Voice still follows the body.
```

- [ ] **Step 5: Hand the play matrix to the play-tester**

Post the paste-ready handoff prompt in chat (repo/branch/HEAD, installed build,
uncommitted files, next steps, files not to touch). Do not launch the game and
do not append launch instructions.
