# Handoff: pool sizes and world reach

Date: 2026-11-15
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `aebb665`
Installed: `~/Games/VC/reVC.app` (pool build, UUID `64B7E7E9…`); the world-reach
build is built and tested but not installed — a session was live at close, so
the Dock launcher ships it on the next launch
Harness: 50 harnesses green (`cd reVC/utils && for f in test_vc_*.py; do python3 "$f"; done`)

## The crash

Crash report of 2026-11-15 12:44:21, process launched 11:36 (the session that
played build 582/583):

```
CPhysical::Add() + 852
CWorld::Add(CEntity*)
CPopulation::AddPed(...)
CPopulation::AddToPopulation(...)
CGame::Process()
```

`EXC_BAD_ACCESS` at address 0, write, main thread. An ambient pedestrian spawn.

### What actually happened

`CPhysical::Add` at `0x1001566cc` in the binary; the faulting pc is `+0x354`:
`stp x20, x23, [x0]` immediately after `bl CEntryInfoNode::operator new`.
In the crash state `x0 == 0`, `x24 == &ms_aSectors[60][56]`, `x20 ==
&…m_lists[PEDS_OVERLAP]`, and the sector-loop counters sit on the last cell: a
normal 1-2 cell ped insert, not a runaway bounds loop.

`CEntryInfoNode::operator new` (`src/core/Lists.cpp:18`) returns null when
`CPool<CEntryInfoNode>::New()` wraps its scan and finds no free slot. Its guard
is `assert(node)`, which on macOS goes through `re3_assert`
(`src/core/re3.cpp:1354`) into `printf` plus libc `assert(false)` — a no-op
under the Release build's `NDEBUG`. So exhaustion returned null silently and
the next store wrote to address 0.

Peds, vehicles, objects **and dummies** each hold one entry-info node per 50 m
sector cell they touch (`CPhysical::Add`, `CDummy::Add`); the stock 3200 pool
saturated after 68 minutes of play in dense areas. The crash session's log ends
abruptly at line 622276 of `reVC.log`, consistent with the 12:44 report.

## The change

`src/core/config.h`, pool capacities only — no behaviour change, no savegame
impact (entry infos and ptr nodes are never serialized; ped/vehicle/object
loads store slot indices, and existing saves stay valid):

| Pool | Stock | Now |
| --- | --- | --- |
| `NUMPTRNODES` | 50000 | 160000 |
| `NUMENTRYINFOS` | 3200 | 40000 |
| `NUMPEDS` | 140 | 256 |
| `NUMVEHICLES` | 110 | 200 |
| `NUMBUILDINGS` | 7000 | 12000 |
| `NUMTREADABLES` | 1 | 8 |
| `NUMOBJECTS` | 460 | 1200 |
| `NUMDUMMIES` | 2340 | 6000 |
| `NUMAUDIOSCRIPTOBJECTS` | 192 | 400 |
| `NUMCOLMODELS` | 4400 | 6000 |

Entry infos now exceed the worst case the entity pools can hold (entities × 4
sector cells), and ptr nodes cover those plus buildings. Total pool memory is
about 10 MB, up from about 4 MB.

Not touched: population caps (`MaxNumberOfPedsInUse`, 25 / 40 interior),
traffic, and the Display settings Draw Distance slider (`m_PrefsLOD`,
0.925–1.8). Pool size removes the ceiling; it does not raise density or view
range.

## World reach

`src/extras/vcmodrange.{cpp,h}`, two WORLD-page rows, both default on:

- **PED RANGE** — scales the ped distance cull by 1.25 in
  `CPopulation::ManagePopulation`: stock 51 m hard radius (66 m special) becomes
  63.75 m (82.5 m); gang members keep their −30 m offset, so ~94 m. The
  offscreen fast-despawn is already disabled (`EXTENDED_OFFSCREEN_DESPAWN_RANGE`
  is on), so this is the only distance cull.
- **RENDER RANGE** — multiplies `TheCamera.LODDistMultiplier` by 1.25 in
  `CCamera::UpdateCamera`, after the stock Draw Distance slider is applied and
  after `GenerationDistMultiplier` is latched, so ped/vehicle spawn distances
  stay stock and cutscenes keep their 1.0. Draw base is the user's slider
  (currently 1.8 max) → effective 2.25; the world cull radius
  `LOD_DISTANCE` 540 → 675 m, still far below the timecycle far clip (2000)
  and the helicopter altitude scaling still applies.

Off-path is exact: both predicates return 1.0 and every stock constant stays in
the engine. Startup keys `PedRange` / `RenderRange` are read in `re3.cpp`, rows
are pinned/persisted like the rest, and both are in the ALL ON sweep.

Sized for the machine in use: MacBook Air (Mac16,12), M4 10-core (4P+6E,
8-core GPU), 16 GB, 2560×1664. A 25% LOD/streaming bump and a 25% ped cull
bump are light for that GPU and add no new data.

## Verification

- Full Release build and `scripts/install.sh` with no session running.
- All ten capacities read back from the installed binary's `CPools::Initialise`
  (e.g. `0x27100` = 160000 flags for ptr nodes, `0x9c40` = 40000 entry infos,
  `0x100` = 256 peds, `0xc8` = 200 vehicles, `0x2ee0` = 12000 buildings,
  `0x4b0` = 1200 objects, `0x1770` = 6000 dummies and 6000 col models,
  `0x190` = 400 audio script objects, 8 treadables).
- 50 harnesses green, including new `utils/test_vc_range.py` (flags, off-path
  unity, stock constants kept in the engine, hook order in `CCamera`, panel
  rows, startup keys). `test_vc_adrenaline.py`, `test_vc_character.py` gained
  the range definitions in their generated translation units;
  `test_vc_passenger.py` row count 61 → 63.
- `VCModPedRangeScale` / `VCModRenderDistScale` verified in the built binary as
  1.25/1.0 selects.
- In-game confirmation is the user's turn: long session, dense areas, gang
  fights.

## Uncommitted

`reVC/src/core/config.h` (pool sizes), `reVC/src/extras/vcmodrange.{cpp,h}`,
hooks in `src/peds/Population.cpp`, `src/core/Camera.cpp`, `src/core/re3.cpp`
and `src/extras/vcmodpanelregistry.cpp`, `utils/test_vc_range.py` plus the
three touched harnesses — and the pre-existing NPC-stock-combat slice A+B tree
(`src/extras/vcmodnpc.*`, `src/extras/vcmodcombat.*`, `src/peds/PedFight.cpp`,
`src/peds/PlayerPed.cpp`, `src/peds/PedAI.cpp`, the touched
`utils/test_vc_*.py` and `utils/test_vc_npccombat.py`).

## If it recurs

Same signature would mean a pool still saturated, which the new headroom makes
unlikely. Next step then is telemetry, not another bump: print
`CPools::GetEntryInfoNodePool()->GetNoOfUsedSpaces()` and the entity pools'
used counts at a slow cadence and find what keeps holding slots.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only; `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`.
> `~/Games/VC/reVC.app` runs the pool build; a world-reach build (PED RANGE /
> RENDER RANGE, both 1.25, WORLD page) is built and harness-green but was not
> installed because a session was live — the Dock launcher ships it next
> launch. Read `docs/handoff/2026-11-15-entryinfo-pool-crash.md` and
> `docs/handoff/2026-11-15-npc-stock-combat-b.md`. Play a long session in
> dense areas: peds should stay to ~64 m (~94 m for gangs), models hold ~25%
> further. If the entry-info crash recurs, add pool telemetry before touching
> sizes. Uncommitted: all pool and range work plus NPC-stock-combat slices
> A+B. No git actions unless asked; game data and the `uchg` anim files stay
> untouched.
