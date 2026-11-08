# Ped AI Overhaul - Priority Plan

Status: planning, no code yet
Base: shared `reVC` checkout on `vcmods` @ `287138f`
Target: reVC `miami` `a26fff4` lineage, macOS arm64

## Goal

A standalone, switchable mode in which drivers and peds behave competently: planned
routes, sane lane discipline, stuck recovery, contact memory, cover, and a small
amount of squad coordination. Default off. When off, stock AI and story missions run
exactly as before.

This is not a global AI patch. One director owns the mode; the stock code path is
untouched while the mode is off.

## Isolation from the chase work

`reVC` is the upstream checkout, not our repository. Per the project rule, do not
fork, branch or push it. Isolation from the other agent is by file choice and staging
discipline, not by a git branch.

Another agent has uncommitted edits in the shared checkout:
`vcmodchase.*`, `vcmodpanel.*`, `Ped.cpp`, `Ped.h`, `PlayerPed.cpp`, `re3.cpp` and
`PlayerInfo.cpp`.

Baseline note: committed `vcmods` HEAD does not build by itself.
`PedFight.cpp:1091` defines `StartFightAttack(uint8, PedFightMoves)` but
`Ped.h:772` still declares the one-argument form; the other agent's uncommitted
`Ped.h` edit fixes it. Build from the shared working tree, never from a clean HEAD,
and never copy or stage their files.

Rules for this work:

- New logic lives in new files under `src/extras/vcmodai.*`. Do not edit
  `vcmodchase.*` or the panel until the chase work is committed.
- Hook only files that are currently clean: `src/core/Game.cpp` (one update call) and
  `src/core/CarCtrl.cpp` (mode dispatch in `SteerAICarWithPhysics`). Defer
  `Ped.cpp`/`PlayerPed.cpp` hooks until the other agent lands.
- Read the mode flag from the ini lazily inside the director, so `re3.cpp` does not
  need editing. Wire the panel row after the chase panel commit.
- Stage explicit paths only. Never `git add -A` or `git commit -am`. Never stage the
  other agent's dirty files. No commit or push unless the user asks.
- Test from a second game folder (`~/Games/VC-ai`, data symlinked) so an AI build
  never overwrites the live chase build.

## Mode shape

Recommended: **sandbox world mode**, not a mission entry.

- The director runs whenever the mode flag is on; nearby traffic and peds use the
  upgraded brain. No entry marker, no scenario code, no dependency on the chase.
- A debug-spawned test squad provides the combat harness later. This stays in our
  own file and can be removed or kept behind the debug flag.
- Reasoning: it matches "standalone mode", it isolates us from the other agent's
  files, and it gives the simplest repeatable test: turn it on, drive around, provoke
  peds.

## Priority ladder

| Milestone | Scope | Why now | Sessions |
|---|---|---|---|
| M0 Baseline and test harness | Build from the shared tree, second test install, ini flag, debug key | Two agents must not overwrite each other | 1 |
| M1 Driving brain | Full route queue, lane plan, speed/brake profile, stuck recovery, instrumentation | Most visible "stupid" and self-contained; reusable by every later mode | 5-9 |
| M2 Contacts and pursuit driving | Contact memory shared by cars, PIT/block with damage-aware speed, yielding | Makes the driving look deliberate rather than scripted | 2-4 |
| M3 Squad combat slice | Sight/sound contacts, cover selection, peek/shoot cadence, one flank role | First "they are not stupid" combat moment | 4-7 |
| M4 Coordination and civilians | Roles, contact sharing, panic propagation, carjack-to-flee | Turns individual brains into a world | 3-6 |
| M5 Sandbox polish | Whole-world LOD, difficulty knobs, panel row, docs, package | Ship shape, after behaviour is proven | 2-4 |

V1 (M0-M3) is the "clearly not stupid" target: roughly 12-20 focused sessions.
M4-M5 add breadth; full faction combat depth remains the long tail.

## M1 - Driving brain (first build)

### What is wrong today

- Route planning is a 2-node lookahead (`CarAI.cpp:1981`), with a smallest-angle
  fallback. Cars miss turns and backtrack.
- Lane changes are a random coin flip (`CarCtrl.cpp:2058`). This is the visible lane
  drift and oncoming-lane behaviour.
- Stuck recovery is a ~0.8 s reverse with no re-plan.
- No anticipation: speed is not derived from the upcoming curve, junction or traffic.

### What replaces it

One new driver brain, dispatched from the top of `CCarCtrl::SteerAICarWithPhysics`
while the mode is on:

1. **Route queue.** Plan from the car's current link to the destination over
   `ThePaths.m_carPathLinks`, using lane counts and directions. Re-plan on deviation,
   not every frame. Keep a bounded queue and fall back to stock if no route exists.
2. **Lane plan.** Choose a lane from `numLeftLanes`/`numRightLanes`, the next link's
   alignment, and an oncoming-traffic check. No lane change when it would cross an
   occupied oncoming lane.
3. **Speed profile.** Target speed from link geometry (curve angle, width, traffic
   lights) and stopping distance to the next obstacle. Brake early, not at the
   bumper.
4. **Steering.** Pure-pursuit on a lookahead point on the current lane, with a
   stability clamp so cars do not flip. Tune in the AI layer, never in handling data.
5. **Recovery.** Detect low speed + blocked ahead for ~2 s, reverse for a bounded
   time, then re-plan; if still blocked, leave the car or despawn per mission rules.

### Files

- New: `src/extras/vcmodai.h`, `src/extras/vcmodai.cpp` (mode state, ini, LOD,
  instrumentation, dispatch).
- New: `src/extras/vcmodai_drive.cpp` (route, lane, speed, steering, recovery).
- Edit: `src/core/Game.cpp` (call `VCModAIUpdate()` next to the chase tick).
- Edit: `src/core/CarCtrl.cpp` (early dispatch in `SteerAICarWithPhysics`).
- New: `utils/test_vcmodai.py` for the pure decisions (lane choice, speed target,
  stuck predicate, route queue).

### LOD and budget

- Steering runs every frame for cars in the active radius.
- Re-planning is staggered: each car plans on its own schedule, not all at once.
- Contact/LOS scans are range-limited and staggered.
- Target: AI update under ~1.5 ms average with ~40 active cars near the player,
  measured from an instrumentation line, not guessed.

### Acceptance criteria

- A cross-map destination is reached without reversing except during recovery, and
  without entering an oncoming lane.
- No lane change within ~15 m of occupied oncoming traffic.
- Stuck car is detected within ~2 s and moving again or abandoned within ~3 s.
- No car flips on ordinary turns at cruise speed.
- Mode off: stock behaviour and story missions unchanged, verified by a mission run.

## Open decision

The wrapper is the only open choice. The recommended reading is the sandbox world
mode above. The alternative - a scenario/mission entry like the chase - is cheaper
per behaviour but couples us to the chase's actor and spawn code. If the sandbox is
chosen, M1 and M3 do not depend on any chase file.

## Risks

- **Physics stability.** Aggressive steering flips cars. Clamp and test at cruise
  speed before adding pursuit aggression.
- **Performance.** Route planning and LOS are the expensive parts. Stagger and cache;
  do not scan every ped every frame.
- **Story missions.** `main.scm` drives the same objectives and car missions. The
  mode gate is mandatory, and the off path must remain byte-for-byte the stock path.
- **Shared files.** The chase agent's uncommitted work is the merge risk. Keep our diff
  in new files and two thin hooks until their work lands.
- **Engine traps.** Driving peds are destroyed on death (`CPed::SetDie`), path
  `prevIndex`/`nextIndex` are unusable, police cars spawn locked, `CopAI` is
  wanted-only. Use pool handles and link data.
