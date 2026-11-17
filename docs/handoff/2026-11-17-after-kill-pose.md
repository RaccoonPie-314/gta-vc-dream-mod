# BECOME NPC hands-behind-back pose — troubleshooting record (2026-11-17)

Workspace `vc-mod`, reVC branch `vcmods`, HEAD `bfc0d4d0` plus the uncommitted tree.
Installed `vcmods build 679`, played and confirmed: the pose fires, releases, and does not
loop. This supersedes `2026-11-17-after-kill-pose-stock.md`, which documents the rejected
1.0 m radius-clamp design (it killed the pose: 4 poses in 136 kills).

## One-minute triage

1. Which wait is it? `grep "gang pose" reVC.log | grep "player=1"` and read `wait=`:

   | wait | meaning | look |
   |---|---|---|
   | 8 | `WAITSTATE_DOUBLEBACK` — the wander's pick; 3.5 s HBHB, `XPRESS_SCRATCH` at ~1 s, a "lost" voice line | [Ped.cpp:8984](../../reVC/src/peds/Ped.cpp#L8984) |
   | 13 | `WAITSTATE_LOOK_ABOUT` — blocked against a building/object; 5 s, head turning, no scratch, re-arms while blocked | [Ped.cpp:2624](../../reVC/src/peds/Ped.cpp#L2624) |
   | 12 | `WAITSTATE_STUCK` — the blocked-ped panic chain (tired / scratch / turn180); needs a shove or impact | [Ped.cpp:2546](../../reVC/src/peds/Ped.cpp#L2546) |
   | 0 | no pose | |

   The clip alone cannot tell them apart; same `IDLE_HBHB`.

2. What radius is the walk on? `grep "VCMOD wander node" reVC.log | tail`:
   `radius=1.00` = no pose chance (node-at-a-time walk); `13`–`30` = the fight's leftover
   seek radius is live (the pose source).

3. Is the branch reached? `grep "VCMOD blocked"` (wall branch) and
   `grep "wander node: pose"` (a node wait was set, with last/next/dir). All probes are
   DIAGNOSTICS-gated.

## Where the pose actually comes from (measured, not guessed)

`ANIM_STD_IDLE_HBHB` is stock in four places: `WAITSTATE_DOUBLEBACK`, `WAITSTATE_LOOK_ABOUT`,
the 1 s `WAITSTATE_CROSS_ROAD`, and the fire/explosion gawk. There is **no** kill trigger.

The frequent one the owner watches on spawned gang peds is the DOUBLEBACK, and its source is
the fight's seek radius, not path geometry:

- `KillCharOnFootArmed` calls `SetSeek(m_pedInObjective, wepRange/3)` when approaching from
  beyond range ([PedAI.cpp:6652](../../reVC/src/peds/PedAI.cpp#L6652)) — 13 m for an M4, 30 m
  for the rifle, ctor default 1.0.
- The radius is never reset, so in the wander `Seek()` reports nodes "reached" from metres
  away, the tail re-picks every frame, and the pick lands on the double-back branches
  ([Ped.cpp:6923](../../reVC/src/peds/Ped.cpp#L6923), [Ped.cpp:6932](../../reVC/src/peds/Ped.cpp#L6932)).
- `FindNextNodeWandering` uses `*lastNode` only within √7 m and falls back to no link when
  every neighbour fails the line-of-sight test
  ([PathFind.cpp:1608](../../reVC/src/control/PathFind.cpp#L1608),
  [PathFind.cpp:1624](../../reVC/src/control/PathFind.cpp#L1624)); the LOS checks
  **buildings only** — cars are not in it.
- Kill completion only re-issues the wander ([PedAI.cpp:2060](../../reVC/src/peds/PedAI.cpp#L2060)).

Measured 2026-11-17: stock spawned peds 34 `wait=8` samples against 4 `wait=13`; the player's
pose entries were 37/48 within three lines of a kill.

## The shipped rule — do not change these pieces independently

1. **The civil/gang body takes the pedestrian blocked branch.**
   `VCModNpcPedBlockedPath` ([vcmodnpc.cpp:248](../../reVC/src/extras/vcmodnpc.cpp#L248))
   flips the three stock player gates in the building/object branch:
   walk-around ([Ped.cpp:2578](../../reVC/src/peds/Ped.cpp#L2578)),
   the stock-player bail-out ([Ped.cpp:2583](../../reVC/src/peds/Ped.cpp#L2583)),
   and the pose gate ([Ped.cpp:2624](../../reVC/src/peds/Ped.cpp#L2624)).
   The cop profile is excluded on purpose (owner: "the cop is fine").
2. **One double back per wander start.** `VCModNpcWanderStart` is called from `SetWanderPath`
   ([Ped.cpp:6760](../../reVC/src/peds/Ped.cpp#L6760)); it re-arms the pose and restores the
   saved fight radius (static module state, fine for one player). Both double-back branches
   ask `VCModNpcDoublebackAllowed`. This is what stops the in-place loop.
3. **A pose ends into a real walk.** At the end of `Wait()` ([Ped.cpp:9613](../../reVC/src/peds/Ped.cpp#L9613))
   `VCModNpcWanderPoseDone` saves a radius above 1.0 and sets 1.0, so the walk after the pose
   goes node to node; the next wander start restores the saved fight radius.
4. **The pose owns him while it is up.** `WanderPath` leaves before the seek when a node wait
   is up ([Ped.cpp:6810](../../reVC/src/peds/Ped.cpp#L6810)); without it the tail re-issues the
   wait every frame and restarts the timer (the old lock).
5. **Stock stays stock.** The stock player (mode off) and every real ped keep their paths:
   the hooks answer true for peds and false for the stock player.

## Failure signatures and where to look

- **No pose at all.** Probe radius 1.00 → the fight never left one: he engaged inside
  `wepRange` (no `SetSeek`), or the kill's `SetWanderPath` never reached the hook (the player
  guard at the top of `SetWanderPath` returns when the street wander does not own him), or
  `bVCModNpcDoublebackUsed` was never cleared (the start hook not called: check the kill
  completion took the `SetWanderPath` branch).
- **Pose repeats in place.** The allowance is not consumed, or `VCModNpcWanderPoseDone` is not
  reached (the `Wait()` tail), or the early return at [Ped.cpp:6810] is gone. Each one alone
  restores the old lock.
- **Pose never releases.** The wait is being re-issued from the tail (missing early return) or
  the timer restarts because the radius is still large while the wait is up.
- **Wall pose never fires.** One of the three gates lost the predicate, or the collider is not
  a large building/object: small objects route to the walk-around first, and **cars are
  vehicles** — they never take this branch. `VCMOD blocked:` must print if the branch is
  reached; if it never prints, the player is not colliding with a building/object at all.
- **Much more frequent near parked cars (open).** Cars are not in the node LOS test
  (`GetIsLineOfSightClear(..., true, false, ...)`, [PathFind.cpp:1624]), so this is not a LOS
  effect. Triage by the wait value first: 8 = the pick, 12 = the panic/submersion chain under
  shoves, 13 = a building/object collision. If it is 8, the candidate is physical blockage —
  he cannot reach the picked node, so the next wander start happens at the same spot with the
  same pick. If it is 12, it is cars shoving him (panic counter) — the vehicle collision
  branch, not the pose branches.
- **Pose on the cop.** `VCModNpcPedBlockedPath` excludes it; only the stock doubleback branch
  can pose a cop body, and the allowance/reset rule apply to all profiles.

## Do not

- Re-force the wait at kill completion (rejected 2026-11-17).
- Clamp the radius for the whole walk (kills the pose: 4 poses / 136 kills measured).
- Leave the pose repeating in place, or suppress a stock branch to hide a symptom.
- Bump rarity or add a gesture without a fresh ask.

## Tests that pin it (all green on this tree)

`test_vc_gangfaction` 34 (no forced pose, timer+scratch, release, stock node poses per profile,
fight radius left for the walk, one pose per start), `test_vc_cop_patrol` 10 (no player gate, the
wait hold), `test_vc_npcmode` 63 (predicate, hook wiring, finished-pose hand-back),
`test_vc_npccombat` 18, `test_vc_npcwalk` 3.

## Code map

| Where | Role |
|---|---|
| [Ped.cpp:2546](../../reVC/src/peds/Ped.cpp#L2546) | panic gate (`VCModNpcBlockedReset`) → STUCK |
| [Ped.cpp:2578](../../reVC/src/peds/Ped.cpp#L2578) / [2583](../../reVC/src/peds/Ped.cpp#L2583) | wall walk-around / stock-player bail-out |
| [Ped.cpp:2624](../../reVC/src/peds/Ped.cpp#L2624) | LOOK_ABOUT / TAXI when blocked pursuing |
| [Ped.cpp:6760](../../reVC/src/peds/Ped.cpp#L6760) | `SetWanderPath` → `VCModNpcWanderStart` |
| [Ped.cpp:6803](../../reVC/src/peds/Ped.cpp#L6803) | `WanderPath`; [:6810] the wait hold; [:6834] the node probe |
| [Ped.cpp:8984](../../reVC/src/peds/Ped.cpp#L8984) | `SetWaitState(DOUBLEBACK)` setup |
| [Ped.cpp:9214](../../reVC/src/peds/Ped.cpp#L9214) | `Wait()` DOUBLEBACK release + scratch window |
| [Ped.cpp:9613](../../reVC/src/peds/Ped.cpp#L9613) | `Wait()` end → `VCModNpcWanderPoseDone` |
| [vcmodnpc.cpp:248](../../reVC/src/extras/vcmodnpc.cpp#L248) | blocked-path predicate, pose-start rule, radius save/restore |

## Open items

- The parked-car correlation above (record the wait value from the next report first).
- The cop's kill completion still takes the pedestrian branch through `npcKillCompleted`
  (noted 2026-11-17, not asked for).
- The saved fight radius is one module-level static — a second player or a port needs it
  per-ped.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0` plus the uncommitted tree; build
> 679 is installed and plays. Read `docs/handoff/2026-11-17-after-kill-pose.md` first (the
> hands-behind-back troubleshooting record), then `AGENTS.md` and
> `docs/architecture.md`. The pose rule: stock double back from the fight's seek radius, one
> pose per wander start, the radius saved/restored, the civil/gang body takes the ped blocked
> branch, the cop excluded, no forcing. Diagnose with `VCMOD wander node` (read the radius),
> `wander node: pose`, `VCMOD blocked`, and the `wait=` value in the gang-pose dump. Open: the
> "fires often near parked cars" report — take the wait value before changing anything.
> Never commit or push unless asked; game data is read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
