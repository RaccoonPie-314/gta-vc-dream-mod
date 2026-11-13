# Ride extraction (2026-11-12) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 445` (was 444). All 43 harness suites
pass at 445. No commit, tag or push was made.

## What changed

- `src/extras/vcmodride.{cpp,h}` now own the passenger ride and the chauffeur:
  the ride state machine (approach, pickup, boarding, driving), the summoned
  limo, the passenger key and enter-press takeover, the skip-the-ride travel,
  and the traffic hand-back. The bodies moved out of `PlayerPed.cpp` verbatim;
  `VCModUpdateRide` is the only one that lost `static` (the engine calls it).
- The ride flags and types moved out of the panel: `nVCModRideZone`,
  `nVCModRideStyle`, `eVCModRideStyle` and `eVCModRidePhase` now live in
  `vcmodride.{cpp,h}`. `vcmodpanel.{cpp,h}` no longer define or declare them.
- `PlayerPed.cpp` keeps the hook calls only: `VCModUpdateRide(this)` in
  `ProcessControl`, the `VCKEY_DRIVER` and `VCKEY_PASSENGER` presses, and the
  spin kick's `VCModRideNotice` line. `PlayerInfo.cpp` keeps its
  `VCModPassengerEntry` predicate call. Both now include `vcmodride.h`.
- Two seams stay where they were, on purpose:
  - `VCModPassengerReleaseAim` stays in `PlayerPed.cpp` next to the lock-on
    latch `bVCModLockOnHeld` it writes; `vcmodride.cpp` forward-declares it. It
    retires with the lock-on / player extraction, not this one.
  - `VCModRideNotice` keeps its name and moves with the ride; the sit module
    and the spin kick still call it until the HUD notice is deduped into one
    helper. `vcmodsit.cpp` now includes `vcmodride.h` instead of forward-
    declaring it.
- The destination catalog (`VCModRideZoneCount`, `VCModRideZoneAt`,
  `VCModZoneLabel`) stays in `vcmodpanel.cpp` — it is panel data shared with the
  crew. `vcmodride.cpp` forward-declares `VCModRideZoneAt`; `vcmodcrew.cpp`
  includes `vcmodride.h` for the zone flag and keeps `vcmodpanel.h` for the
  catalog.
- `re3.cpp` keeps the `RideZone`/`RideStyle` ini reads and the style clamp; it
  now includes `vcmodride.h`.
- Harnesses: `test_vc_passenger.py` reads the state machine from `vcmodride.cpp`
  and the enums from `vcmodride.h` (the aim-latch seam still from
  `PlayerPed.cpp`); its wiring test checks the new home and that the engine
  keeps the hooks but not the ride state. `test_vc_adrenaline.py` and
  `test_vc_character.py` read the ride enums from `vcmodride.h` and supply the
  two flag definitions the panel no longer carries. `test_vc_diag.py` adds
  `vcmodride.cpp` to its log sources (the `VCMOD passengers:` line moved).
  `test_vc_driver.py` docstring only. Row count stays 57.

The feature-off path is unchanged: with no ride armed every hook is a no-op,
`VCModPassengerEntry` returns false for every car but a summoned limo, and the
stock enter press and traffic update run exactly as before.

## Verification

- All 43 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` builds cleanly (build 445); installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, checked immediately
  before install). The installed binary reports `vcmods build 445`.
- In game: not yet checked (the player has not been able to test). Open passes:
  the ride itself (passenger key onto a driven / empty car, the chauffeur call,
  pickup, boarding, the drive and arrival, dismissal from the back seat, skip
  travel), plus the still-open build 444 gang reaction/faction pass and the
  build 443 NPC/cop passes.

## Uncommitted

The six refactor slices (adrenaline, sit, street, NPC, gang, ride) plus the cop
fixes are all uncommitted; every refactor is a behaviour-neutral move.
`vc-mods.patch` predates them.

- New: `src/extras/vcmod{adrenaline,sit,street,npc,gang,ride}.{cpp,h}`.
- This slice modified: `src/peds/PlayerPed.cpp`, `src/core/{re3,PlayerInfo}.cpp`,
  `src/extras/vcmodpanel.{cpp,h}`, `src/extras/vcmod{crew,sit}.cpp`,
  `utils/test_vc_{passenger,driver,adrenaline,character,diag}.py`.
- `PlayerPed.cpp` is now 2,896 lines; the ride block (~612 lines) moved out.

## Next

1. Play check when the player can test: the ride pass above, plus the still-open
   gang and NPC/cop passes. Then commit the six refactors (and the cop fixes)
   only when asked and regenerate `vc-mods.patch`.
2. Extract `vcmodcharacter` next — the last `PlayerPed.cpp` extraction; after it
   `PlayerPed.cpp` is engine-only. The HUD notice dedupe retires the
   `VCModRideNotice` seam; the lock-on / player extraction retires
   `VCModPassengerReleaseAim`. The gang pose/gaze/threat probes move with the
   NPC-combat extraction.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 445 is
> installed. Read `docs/handoff/2026-11-12-ride-extract.md` first. Adrenaline,
> sit, street, NPC, gang and ride now live in `src/extras/vcmod{adrenaline,sit,
> street,npc,gang,ride}.*`; the engine keeps hook and predicate calls only.
> `vcmodride` owns the ride flags and enums (out of the panel) and the whole
> ride/chauffeur state machine; the zone catalog stays in the panel.
> `VCModPassengerReleaseAim` stays in `PlayerPed.cpp` as the lock-on latch seam
> and `VCModRideNotice` keeps its name until the HUD dedupe. All 43 harnesses
> pass; the in-game ride pass, the build 444 gang pass and the build 443 NPC/cop
> passes are still open (the player has not tested). Clear `~/Games/VC/reVC.log`
> before each test (only with no session running) and read only fresh, filtered,
> capped slices. Then extract `vcmodcharacter` the same way: one module per
> session, all 43 harnesses, a build, an install only with no session running,
> and a play check. Never commit or push unless asked; game data and uchg anim
> files are read-only; check `pgrep -f "reVC.app/Contents/MacOS/reVC"` before
> any install.