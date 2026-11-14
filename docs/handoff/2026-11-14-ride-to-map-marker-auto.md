# RIDE TO follows the pause-map marker (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `4fc7fcd`.
Workspace branch `main`, HEAD `fb454bd`. Nothing committed, tagged or pushed for
this change. Release build installed into `~/Games/VC/reVC.app` at 10:17 with no
game session running.

## What changed

**RIDE TO** now starts on `auto`. While a pause-map marker is placed, the
chauffeur and a Vercetti crew driver use it as the destination; with no marker
they cruise with traffic. Neither flow needs the panel opened to pick a
destination.

- `src/extras/vcmodpanel.h`
  - `VCMOD_RIDE_ZONE_AUTO` (`-1`), the only new stored value.
  - `VCModRideZoneValue(position)` — list position → stored value. The list is one
    longer than before and only its first slot is new, so position `n` stores
    `n - 1` and every `RideZone` an older build saved still selects the same
    place. Old `-1` (traffic) now reads as auto: the same drive while no marker
    is placed.
  - `VCModRideZoneEntry(stored)` — resolves auto, once, to cruise (`0`) or the
    marker's own entry, so the panel and both drivers agree.
  - `VCModRideZoneMoved(applied)` — true when auto is following and the marker
    sits more than 25 m (`VCMOD_RIDE_RETARGET_NEAR`) from the point applied, so a
    shaky placement does not re-route every frame.
  - `VCModRideZoneRowText()` — the row reads `auto: map marker` or
    `auto: traffic`.
- `src/extras/vcmodpanelcatalog.cpp`
  - `VCModRideZoneCount()` +2 (auto row plus the existing marker row).
  - `VCModRideZoneAt()` resolves auto through `VCModRideZoneEntry()`.
  - Ride list label renders `auto (marker / cruise)` as a name, not as the point
    it currently resolves to, so the row does not move under the pointer when a
    marker is placed.
  - `VCModListPick()` stores `VCModRideZoneValue(entry)`.
- `src/extras/vcmodpanel.cpp`
  - RIDE TO row uses `VCModRideZoneRowText()`.
  - SKIP RIDE row: `[JUMP]  to RIDE TO` when there is a destination,
    `[--]  place a map marker` when auto has none, otherwise `[--]  pick
    RIDE TO`.
- `src/extras/vcmodride.cpp` / `.h`
  - `nVCModRideZone` initialises to `VCMOD_RIDE_ZONE_AUTO`; the header comment
    describes the setting rather than the old `-1` meaning.
  - Both drivers read RIDE TO live: `nVCModRideAppliedZone` (ride) and
    `nVCModCrewAppliedZone` (crew) hold the resolved entry, so another zone, or a
    marker placed, cleared or dragged, re-routes a ride already under way.
  - The chauffeur now ends in `MISSION_GOTOCOORDS_STRAIGHT` when
    `JoinCarWithRoadSystemGotoCoors` finds no route (a marker off the road
    graph) instead of holding a mission with no path. The crew already had this
    pattern.
  - SKIP RIDE message on auto without a marker:
    `skip the ride: place a map marker first`.
- `src/extras/vcmodcrew.cpp` — crew drive and tick use the resolved entry and
  `VCModRideZoneMoved()`; the aggressive-style switch still re-applies only while
  the destination has not changed.

Docs: `README.md` (ride, personal driver, SKIP RIDE, crew sections),
`CHANGELOG.md` (`## Uncommitted — 2026-11-14`),
`docs/specs/2026-11-10-vercetti-crew-design.md` §4.4.

`src/core/re3.cpp` still reads `RideZone` from the ini unchanged; auto needs no
new key.

## Harnesses

`utils/test_vc_passenger.py` (catalog: count, value mapping, auto resolution,
moved threshold, row text), `test_vc_driver.py`
(`test_the_destination_follows_the_map_marker`, skip-message expectation),
`test_vc_crew.py` (`test_auto_destination_follows_the_marker`),
`test_vc_character.py` (shifted list positions), and the existing
`test_vc_adrenaline.py` flag stubs all pass. The full suite is
`python3 utils/test_vc_*.py` from `reVC/`; all 45 drivers passed before install.

## Installed build

`~/Games/VC/reVC.app/Contents/MacOS/reVC`, built by `scripts/build.sh` and
installed by `scripts/install.sh` from `reVC/` (Release). The installed binary
contains `auto: %s`, `map marker`, `[--]  place a map marker` and
`skip the ride: place a map marker first`. No game session was running during the
install.

## Not done

- Never played: nothing here is "seen" yet. Worth checking by hand —
  1. place a marker, call the crew or the chauffeur without opening the panel;
  2. clear the marker mid-ride (should fall back to cruise);
  3. drag the marker more than 25 m mid-ride (should re-route);
  4. place a marker off the road graph (straight-line fallback, no stuck car);
  5. load a save with an old `RideZone` value and confirm it still selects the
     same place.
- Nothing committed. `scripts/sync.sh` regenerates `vc-mods.patch` and refuses to
  run on a dirty tree; do not hand-edit the patch.

## Files not to touch

The reVC tree carries uncommitted work from earlier sessions that this change
does not own:

- `src/extras/vcmodcombat.cpp`, `vcmodcombat.h`, `vcmodplayer.cpp`,
  `vcmodplayer.h`, `src/peds/PlayerPed.cpp`, `src/renderer/Hud.cpp`,
  `src/weapons/Weapon.cpp`
- `utils/test_vc_player.py`, `utils/test_vc_windup.py`

Leave them alone when staging or committing this change; the ride files are
`vcmodride.*`, `vcmodcrew.cpp`, `vcmodpanel.*`, `vcmodpanelcatalog.cpp` and the
passenger/driver/crew/character harnesses.
