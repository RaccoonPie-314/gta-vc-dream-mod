# A gang-body NPC hunts a rival gang again (2026-11-16)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`
(nothing committed). Release build `vcmods build 645` installed into
`~/Games/VC/reVC.app` with no game session running. All 54
`utils/test_vc_*.py` suites pass. Unplayed.

## The report

BECOME NPC on, the gang profile, free roam wearing a Cuban body (CBb, model 84,
TYPE FROM BODY on). Haitian gang members came at the player and he fought back
once hit, but he never started a fight himself — not with fists, not with a gun.

## What the code did (probe, build 643)

The temporary probe (`vcmodnpc.cpp`, one line a second) read:

```
fear=9502208 created=1 stats=4 fearStat=20 temper=65 obj=0 threat=0 ...
| rival=85 type=8 dist=0.7..12.0 dot=+ los=1 flag=256
```

- `9502208` = `0x90FE00`: the Cuban (GANG1) threat row **with the Haitian bit
  (GANG2) missing**. The rival’s flag is `256` (GANG2), so `flag & fear` is zero
  and `ScanForThreats` never returns him: `threat=0`, `obj=0`.
- The body/profile/stat side was right: `stats=4` (STAT_GANG1), fear 20,
  temper 65, `created=1` (RANDOM_CHAR), `ctrl=1`, `state=5`, the rival 0.7–12 m
  ahead with line of sight.

## Why the row was short

The ped-type table (`CPedType`) is written into the **savegame** (`CPedType::Save`
/ `Load`). A mission clears the Cuban↔Haitian threats before the save is written
and nothing restores them (`CMissionCleanup` resets other mission globals, not
these rows). Parsing the saves:

| save | GANG1 threats | GANG2 threats |
|---|---|---|
| sf1, sf2, sf7, sf9 | `0090ff00` (stock) | `0090fe80` (stock) |
| **sf6, sf8** | `0090fe00` — no GANG2 | `0090be01` — no GANG1, GANG8; + PLAYER1 |

`sf6`/`sf8` were written right after `CUB_4`. So the save carried a permanent
Cuban–Haitian truce, and the NPC-mode player borrows the live row every frame —
faithfully, which is why he stood down while the Haitians still carried their
leftover hate-the-player bit.

## The change

1. **Stock rivalry on load** — `VCModGangRestoreStockThreats` in
   `src/extras/vcmodgang.cpp`, called at the end of `CPedType::Load` (engine keeps
   the hook call only). It adds the missing gang↔gang pairs back (ped.dat has
   every gang threatening every other), leaves every other saved change alone,
   re-applies the army alias pair the mod keeps neutral (GANG3↔GANG9), and
   re-reads every live gang ped’s row. The player re-derives every frame.
2. **Fight on sight** — `VCModGangFightRivalOnSight`, called first in
   `CPed::CivilianAI`’s rival branch: the gang-profile player takes the stock
   on-foot kill, where the stock branch would stand down unarmed against an armed
   rival, and its other answer is a flee this profile already refuses. NPC-mode
   gang player only; cops, civilians, kin, corpses, other peds and mode-off keep
   the stock branches.
3. Temporary probe still in `vcmodnpc.cpp` (`VCMOD gang scan:` once a second).
   With the repair the same line must read `fear=9502464` (`0x90FF00`) and a
   non-zero `threat` once a Haitian is in front.

## Harnesses

- `utils/test_vc_gangfaction.py` — `FightOnSightTests` (predicate truth table +
  `CivilianAI` wiring) and `StockThreatTests` (a mission-shortened save row gets
  the rivalry back, other bits kept, army pair neutral; `CPedType::Load` calls
  the repair). The CPed stub gained `bDead`/`DyingOrDead`; the CPedType stub is a
  mutable table now.
- `utils/test_vc_npcmode.py` — no-op stub for the probe.
- Full sweep: 54 suites, 0 failures. `scripts/build.sh` exit 0, build 645,
  installed and re-signed.

## In play, to check

1. Load one of the affected saves (6 or 8), BECOME NPC on, Cuban body, no weapon.
2. Walk up to a Haitian gang (HNa/HNb) in front: he should start the fight.
3. `reVC.log` (DIAGNOSTICS on) shows `VCMOD gang row: 7 …` for the repaired rows
   and `VCMOD gang scan: fear=…ff00 threat=<non-zero>`.
4. Kin (Cubans) stay spared; cops and civilians keep their stock reaction.
5. Saving and reloading keeps the rivalry (the repaired table is written back).
6. If the play holds, delete the probe, its call and the two harness stubs.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are `uchg`. Install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. No commit, tag or push unless
asked.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0`; build 645 is
> installed. Read `docs/handoff/2026-11-16-gang-rival-sight-fight.md` first, then
> `AGENTS.md`. Uncommitted: the NPC mission-target hunt, PED WOUNDS, the
> keys/panel work, the aim-after-kill fix, and this change — a loaded save’s
> mission-shortened gang threat rows are repaired to the stock rivalry
> (`VCModGangRestoreStockThreats` from `CPedType::Load`), and the gang-profile NPC
> takes the stock on-foot kill on a sighted rival (`VCModGangFightRivalOnSight`).
> A temporary `VCMOD gang scan:` probe is still in `vcmodnpc.cpp`: check
> `fear=…ff00` and a non-zero threat, then remove it with its call and the two
> harness stubs. Play, then commit and push only when asked.
