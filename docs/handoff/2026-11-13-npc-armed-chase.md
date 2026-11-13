# NPC mode: armed chase and post-ID walk (2026-11-13) — built, installed

Workspace `vc-mod`, reVC `reVC/`, branch `vcmods`, HEAD `bb3fe88`. Installed
build `472`; all 45 harnesses pass (41 tests in the NPC harness). No commit,
tag or push.

## Log evidence from the build-468 play test

- 55 `VCMOD cop: chase model=…` lines: hunting does trigger, including after an
  engage. The armed cop then stands and fires from the weapon's full range, so
  he never visibly closes on the target.
- `wait=12` is `WAITSTATE_STUCK`: after an ID check the cop stood in the
  engine's blocked-ped chain, which plays ROADCROSS/TIRED/SCRATCH/TURN180 one
  after another — the "random animations".
- The logged cooldown line read `hassle=81758 quick=0`: QUICK ID CHECK was off
  during that run, so the 100 s timer was the stock one, not a broken clamp.

## Fix 1: the armed cop closes the distance (build 472)

The build-466 attempt wrote `SetSeek` into the ped state every frame and was
reverted in 468. This time the change is one engine hook and no state writes:
`VCModNpcCopWeaponRange` (`vcmodnpc.cpp:253`) returns the stock weapon range
over three when the ped is the player in COP mode with a live kill objective,
and `CPed::KillCharOnFootArmed` uses it for its local `wepRange`
(`PedAI.cpp:6521`). That divisor is the engine's own `wepRangeAdjusted`, so the
standoff scales with the weapon instead of a constant: M4/Ruger 30 m, M60 25 m,
Uzi/MP5 15 m, Shotgun 13.3 m, Colt/Python 10 m, Sniper 33.3 m. The engine's
seek/attack alternation walks him in to that range and fires; every other ped
and stock cop keeps the original value.

## Fix 2: the walk after an ID check goes away from the pedestrian (build 470)

`VCModStreetStartWander` (`vcmodstreet.cpp:512`) now uses the ped's
`m_nPathDir` instead of a random direction when the engine's leave timer is
still recent (the ID check sets both peds' `m_leaveCarTimer` and an
away-from-the-target heading). A random walk could start straight into the
pedestrian he had just questioned, which ended in the blocked-ped pose chain.

## Verification

- All 45 `utils/test_vc_*.py` suites pass; new tests cover the cop range gating
  (8 m for the NPC cop kill, unchanged otherwise) and the away-heading walk
  after an ID check.
- `scripts/build.sh` builds cleanly (build 472); installed with
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. The installed binary reports
  `vcmods build 472`.
- In game: not checked.

## Next

1. Hunt armed: the cop should walk in to the weapon's stock close range (M4
   ~30 m, pistol ~10 m, Uzi ~15 m), then fire, and chase again when the target
   runs.
2. Question a pedestrian, then watch him part and walk away without the
   TIRED/SCRATCH/TURN180 chain.
3. QUICK ID CHECK with the switch actually on: the cop diag should read
   `quick=1`, and a new ID check should be reachable within 5–10 s.
4. The panel, combat, character, ride, gang, NPC/cop and player passes and one
   chase run remain; then the `ProcessPlayerWeapon` extraction and the
   never-wanted helper. Commit only when asked.

## Files not to touch

Game data is read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before
any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 470 is installed.
> Read `docs/handoff/2026-11-13-npc-armed-chase.md` first, then
> `docs/handoff/2026-11-13-npc-mode-fixes.md`, `docs/architecture.md` and
> `AGENTS.md`. The armed cop range hook and the post-ID away-walk are built but
> unplayed. Run all `utils/test_vc_*.py` suites, `scripts/build.sh`, install
> only with no session, and confirm the installed build number before handing
> off. Never commit or push unless asked; game data is read-only.
