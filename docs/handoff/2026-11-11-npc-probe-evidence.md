# NPC-civilian probe evidence — 2026-11-11

Captured from `~/Games/VC/reVC.log` (cumulative, ~122 MB; the live log keeps growing, so this
excerpt is the durable record). Probes were gated to `IsPlayer()` and throttled to once/second.
Build at capture: the round-3 build (tired-pose guard + reaction-state movement fix), installed
into `~/Games/VC`. Companion: `docs/handoff/2026-11-11-npc-civilian-reactions.md`.

## Probe counts (latest play session)

| Probe | Count | Meaning |
| --- | --- | --- |
| `VCMOD civ layer` | 283 | civilian AI dispatch ran (NPC-civilian wandering) |
| `VCMOD threat` | 278 | `ScanForThreats` reached the dead-ped branch |
| `VCMOD corpse` | 1 | `CivilianAI` processed a DEADPEDS reaction once |
| `VCMOD react move` | 1 | player entered a flee/investigate state once |

## Raw lines

```
VCMOD civ layer: state=5 fear=42991616 created=1 obj=0 ctrl=1 threat=0 near=10
VCMOD threat: fear=42991616 created=1 dead=0 dist=-1.0 near=10   (all 278 samples dead=0)
VCMOD corpse: dist=1.8 killer=0 killerNear=0 state=20
VCMOD react move: state=9 moveSpd=0.00 moveState=1 vel=0.00 wait=0
```

## Decoding

- `state=5` = `PED_WANDER_PATH`; `state=9` = `PED_FLEE_ENTITY`; `state=20` = `PED_CHAT`;
  `PED_INVESTIGATE` = 30. `moveState=1` = `PEDMOVE_STILL`.
- `fear=42991616` = `0x2900000` = `PED_FLAG_GUN (1<<20) | PED_FLAG_EXPLOSION (1<<23) |
  PED_FLAG_DEADPEDS (1<<25)` — exactly the civilian `Threat GUN EXPLOSION DEADPEDS` from
  `data/ped.dat`. Confirms the `m_fearFlags` borrow is effective at runtime.
- `created=1` = `RANDOM_CHAR` — confirms the `CharCreatedBy` borrow is effective.

## Conclusions

1. **Round-1/2 flags confirmed live.** Fear flags and `RANDOM_CHAR` are correct while
   civilian-wandering; the civilian layer runs (283 dispatch samples).
2. **Corpse detection is a brief stock window.** `dead=0` in all 278 threat samples: the native
   `EVENT_DEAD_PED` lives only ~1000 ms (`Ped.cpp` `RegisterEvent(..., 1000)`), so a once/second
   probe rarely coincides with it. Natives share this window. The single corpse detection was at
   1.8 m → the flee branch (<5 m), not investigate.
3. **Reaction movement bug (fixed round 3, unplayed).** `react move` caught `PED_FLEE_ENTITY`
   with `moveSpd=0, vel=0` — the player entered flee but did not translate, because the player
   control switch had no movement drive for flee/investigate. Fixed by driving `m_fMoveSpeed`
   from `m_nMoveState` + `SetRealMoveAnim` for those states under `bVCModNpcMode`.
4. **Investigate is stock-suppressed when the killer lingers.** `CivilianAI`'s DEADPEDS branch
   skips investigation if the killer is within 10 m of the body (`Ped.cpp:1543`); <5 m → flee.
   NPC-caused deaths keep the killer near the body, so investigate rarely fires naturally. To
   observe it: kill a ped from >10 m (Tommy >5 m from the body, killer far), or watch a death
   whose killer walks off.

## Still pending

- Reaction-state movement fix is built/installed but **not confirmed in play**.
- Probes (`VCMOD threat`, `VCMOD civ layer`, `VCMOD corpse`, `VCMOD react move`) are still in
  `Ped.cpp` / `PlayerPed.cpp` — strip before shipping.