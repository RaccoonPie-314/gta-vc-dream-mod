# NPC mode: the seat objective never completed — built, installed, awaiting play

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Installed `vcmods build 400` into `~/Games/VC/reVC.app` with no session running.
No commit, tag or push was made. Previous handoff:
`docs/handoff/2026-11-12-cop-behavior-extraction.md`.

## The report

Played build 399 and watched CIVILIAN Tommy wander. Fleeing from a fresh corpse
works (evidence below). The bug: he struggles to sit down at a seat — a cafe
chair, a bench.

## What the log showed

Scoped to the last session in `~/Games/VC/reVC.log` (started line 2325233,
build 399). `VCMOD wander:` printed 2450 transition lines; **none** had
`wait=21..24`, i.e. SIT_DOWN/SIT_DOWN_RVRS/SIT_UP/SIT_IDLE never ran. Instead,
around `obj=39` (OBJECTIVE_GOTO_SEAT_ON_FOOT) the trace ping-ponged:

```
state=6 move=2 speed=0.86 obj=39      PED_SEEK_POS toward the seat
state=6 move=1 speed=0.00 obj=39      arrived-as-far-as-Seek-counts-it
state=5 move=2 speed=0.00 obj=39      back in PED_WANDER_PATH
... repeat for minutes, never sitting
```

Where the objective came from: `CPed::UseNearbyAttractors` (Ped.cpp:1685) runs
in the civilian layer every 11 calls and always qualifies because
`SCivilianAIState::m_bAttractorUnk` is seeded with
`GetRandomNumberInRange(0,1) < 1.25f` — always true, same line as stock
`CCivilianPed`'s constructor. It registers him with the nearest seat attractor,
which sets `OBJECTIVE_GOTO_SEAT_ON_FOOT` and a seek to the seat effect pos.

## Root cause

`CPlayerPed::ProcessControl` keeps its own copy of the native state switch. In
`PED_SEEK_POS` it answered every `Seek()` arrival with
`RestorePreviousState()` (+ STILL). Native `CPed::ProcessControl`
(Ped.cpp:1845) has a dedicated branch first:

```cpp
if (Seek()) {
    if ((GOTO_AREA_ON_FOOT || ... || IsUseAttractorObjective(m_objective)) && m_pNextPathNode)
        m_pNextPathNode = nil;
    ...
    } else if (... || IsUseAttractorObjective(m_objective)) {
        SetIdle();          // stay at the attractor; ProcessObjective finishes it
    } else {
        RestorePreviousState();
    }
}
```

For an attractor objective the native ped stays put and `ProcessObjective`
re-seeks the remaining centimetres (`CPedSeatAttractor` counts seek done at
0.125 m, PedAttractor.cpp:666), turns the body onto `m_attractorHeading`, then
`SetWaitState(WAITSTATE_SIT_DOWN)`. The player copy restored the walk instead,
so the objective re-seeked, the walk re-aimed him at a path node, and the pair
looped forever — the visible "struggles to sit".

## The fix (three gates, all in `src/peds/PlayerPed.cpp`)

1. **Seek arrival** — mirror native: `IsUseAttractorObjective(m_objective)` →
   `SetIdle()`; every other objective keeps `RestorePreviousState()`, so gang
   and cop chases behave as before.
2. **Wander resume** — `VCModUpdateNpcMode` re-issued `SetWanderPath` on any
   `PED_IDLE`. That would steal him back during the native seek↔idle cadence.
   Both resume paths (the in-wander idle branch and the not-walking handover)
   now require `m_objective == OBJECTIVE_NONE`.
3. **The sit itself** — the engine's sit runs the same SIT_DOWN → SIT_IDLE →
   SIT_UP wait states as the C press but with no `bVCModSitting`, so the player
   control switch (camera aim, walk input) would have walked him off the seat.
   `VCModUpdateSitting` now adopts an engine sit (`bVCModSitEngine`): the seat
   position/heading lock and the control-code skip apply, keys do not stand him
   up while NPC mode runs (input is ignored there), and the stock 25–30 s sit
   timer is left alone — the manual C sit keeps its 10 min hold. Once the mode
   is off, keys stand him up again as before.

`VCMOD sit: engine sit adopted` / `VCMOD street idle: stood up` are the log
lines for the next play test.

## Verification

- New `utils/test_vc_sit.py` — 8 checks: adoption, stock idle timer kept, manual
  hold unchanged, keys ignored in mode, keys stand him up outside it, sequence
  clear, mid-SIT_UP adoption, manual stand on street-idle off.
- `utils/test_vc_cop_chase.py` — 7 checks (3 new): attractor arrival goes idle,
  kill seeks still restore, guard order.
- `utils/test_vc_npcmode.py` — 31 checks (2 new): a live objective owns both the
  idle ped and the orphaned walk.
- Full suite 255/255. Release build green. Installed build 400 carries
  `engine sit adopted`. **Not yet confirmed in play.**

## The flee report

One corpse event in the session: `VCMOD corpse: dist=2.9 killer=0 killerNear=0
state=5` → `PED_FLEE_ENTITY` for ~10 s at 1.8 m/s (`VCMOD react move`), then
back to wandering. That is the stock rule: a corpse under 5 m → flee; 5–10 m
with the killer far → investigate; killer near → nothing. The threat probe
reads `fear=42991616` (GUN|EXPLOSION|DEADPEDS) with `created=1`. No code change.
If the report meant "he should have investigated instead", that is a distance /
killer-proximity question, not a gate.

## Next steps

1. Play: let CIVILIAN Tommy wander past cafe chairs / benches / beach seats.
   Expect `VCMOD sit: engine sit adopted`, the sit clips, a 25–30 s stay, then
   `stood up` and the wander resuming. `wait=21..24` now appears in
   `VCMOD wander:` on the way through.
2. Watch that the seek no longer ping-pongs (no more `obj=39` alternating
   `state=6`/`state=5`), and that chat/flee/investigate still resume after.
3. Then strip the temporary diagnostics (`VCMOD wander:`, `civ layer`,
   `threat:`, `corpse:`, `react move:`, `talk:`, `voice:`, `id line:`) and
   commit the NPC topic.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Never install while
`pgrep -x reVC` returns anything. `anim/cuts.img`, `anim/cuts.dir`,
`anim/ped.ifp` are uchg. Crew ownership and chat are unchanged by request.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 400.
> Read `docs/handoff/2026-11-12-npc-seat-objective.md` first. CIVILIAN NPC mode's
> seat objective now completes in code: the player seek case mirrors native
> `SetIdle()` for attractor objectives, the wander resume yields to a live
> objective, and the engine's own sit is adopted by the sit machinery (seat lock,
> control skip, stock timer). Flee-from-corpse is confirmed stock. Play-test the
> sit on cafe chairs / benches / beach seats, check `VCMOD sit: engine sit
> adopted` and `wait=21..24` in `VCMOD wander:`, then strip the temporary probes
> and commit. Never commit/push on the play-tester's behalf. Game data, settings,
> savegames and the uchg anim files are read-only; never install over a running
> session.
