# RIDE TO: the pause-map marker is now a destination

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Built and installed into `~/Games/VC` with no session running; in-game line
`vcmods build 370`. Nothing committed, tagged or pushed. Not yet played.

Previous round: `2026-11-12-passenger-key.md`.

## What was asked

`RIDE TO` only offered "traffic (cruise)" and whole map zones, so a rider could
not send the crew to a point they chose. The game already has a pause-map
waypoint, and the owner expected it to work. It did not: nothing read it.

## What shipped

The marker is the **last** entry in `RIDE TO`, after cruise and every map zone.
It resolves to `CRadar::TargetMarkerPos` and is valid only while
`CRadar::TargetMarkerId != -1`.

Entry indices for cruise and the zones are unchanged, so a saved `RideZone`
value still means the same thing. What did change is that `nVCModRideZone` now
stores the **list entry** rather than a derived zone index. For zones the two
numbers were always identical, so only cruise moved, from `-1` to `0` — both
read as cruise everywhere (`VCModRideZoneAt(0)` returns zoneIndex `-1`, and a
stored `-1` is out of range and also falls back to cruise). An old ini holding
`-1` therefore still loads as cruise.

Three consequences worth knowing:

- **An unplaced marker is not a drive to the origin.** `VCModRideZoneAt` fills
  the name first, then returns false when no marker is placed, so every caller's
  existing `zoneIndex >= 0` test falls back to cruising. The menu names the row
  `map marker` and the `RIDE TO` value reads `traffic (cruise)` — visible, not a
  silent no-op.
- **A free point may need a straight last leg.** The marker is not on the road
  graph, and the crew drive already handles that: a route when
  `JoinCarWithRoadSystemGotoCoors` finds one, otherwise
  `MISSION_GOTO_COORDS_STRAIGHT_ACCURATE`.
- **The destination is resolved when the ride is issued**, not every frame. Place
  the marker, then pick `RIDE TO`, then call the crew. Placing it afterwards does
  not re-route the current ride.

## Files

`src/extras/vcmodpanel.cpp` — `VCModRideZoneCount` (+1), the marker branch in
`VCModRideZoneAt`, the list render and select handler now work in entries, the
`TWEAKINT32` bound widened to `NUMMAPZONES`, and `Radar.h` added to the includes.

`utils/test_vc_passenger.py` — new `test_the_map_marker_is_a_destination`
(unplaced refuses but still names itself; placed resolves to the point and its
own entry; past the marker refused). `test_destination_list` updated for the
longer list. `test_vc_character.py` updated: picking cruise now stores entry 0.

## Verification

- `utils/test_vc_passenger.py` — **13 OK**.
- Every `utils/test_vc_*.py` harness — **ALL OK**.
- Clean build and install; the installed binary carries the `map marker` string.

Note on method: the marker test was written before the implementation, but the
implementation was written before the test was first run, so it never showed a
red. It does discriminate — the old count returned 2 for two zones where the test
asserts 3, and the old lookup treated entry 2 as a missing zone and returned
false where the test expects the marker point.

## Next steps

1. Play: place a pause-map marker, set `RIDE TO` to `map marker`, board, and
   check the crew drives to it — including a marker off the road, which should
   end in a straight last leg.
2. Check the unplaced case reads `traffic (cruise)` and the car cruises rather
   than heading for the map origin.
3. Confirm a saved `RideZone` from an older build still selects the same place.

## Uncommitted

`src/extras/vcmodpanel.cpp`, `utils/test_vc_passenger.py`,
`utils/test_vc_character.py` from this round, plus the passenger-key, crew, gang
and NPC-mode work from earlier handoffs.

## Files not to touch

`~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` carry the macOS
immutable flag. Never install while `pgrep -x reVC` returns anything.
