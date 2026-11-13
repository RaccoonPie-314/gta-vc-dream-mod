# Passenger key P — silent failure traced, latched-aim cancel fixed

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Build green; **not installed** — a session was live (pid 42192) during this round.
The Dock-pinned `Vice City Mods.app` rebuilds and installs this tree on its next
launch, so no separate install is needed. Nothing committed, tagged or pushed.

Previous round: `2026-11-12-crew-ride-style-and-pickup.md`.

## The report

Pressing `P` beside the crew car did nothing. "Passenger Mode" could not be found
in the menu. Both had to be answered separately.

## There is no Passenger Mode any more, by design

The toggle was replaced on 2026-11-10 by a one-shot key that boards the nearest
car as a passenger. The menu still exposes it, but as a binding, not a mode:
`PASSENGER KEY` on the **KEYS** page (`src/extras/vcmodpanel.cpp:589`), default
`P`, ini key `KeyPassenger` (`src/extras/re3.cpp:727`). No `PASSENGER MODE` row
exists in the panel. Looking on the DRIVING page will not find it.

The configured key was not the fault: `KeyPassenger` has no override, so it is
the compiled default `P`.

## A real silent-cancel path, found and fixed

`VCModPassengerKey` (`src/peds/PlayerPed.cpp:571`) sets
`OBJECTIVE_ENTER_CAR_AS_PASSENGER`. The engine then walks Tommy to the door in
`PED_SEEK_CAR`, and that state cancels the whole objective on the first frame the
target input is down (`src/peds/PlayerPed.cpp:4424-4431`).

The mod's lock-on latch re-asserts `RightShoulder1` every frame while
`bVCModLockOnHeld` is set (`src/peds/PlayerPed.cpp:4181-4186`). So a latch left
on by an earlier fight silently kills every boarding attempt: the press is
accepted, the objective is set, and the entry is dropped before it starts with no
notice.

This is a genuine reachable failure. **It is not proven to be the one reported** —
the owner was not sure whether a lock-on was active. Treat it as one confirmed
bug removed, not as the diagnosis.

**Fix.** Accepted boarding now clears the latch through
`VCModPassengerReleaseAim()` (`src/peds/PlayerPed.cpp:563`, declared in
`vcmodpanel.h`), called immediately before the objective is set. A refused press
does not touch it — the player is still aiming for their own reasons.

## Diagnostics added

Every press now leaves one line, so a silent no-op becomes identifiable:

```
VCMOD passengers: press control=%d inCar=%d entering=%d
```

`control=0` means Tommy was not in control (mid-animation, knocked down, an
objective owning him). `inCar=1` means he was already aboard. `entering=1` means
an entry was already in progress. `~/Games/VC/reVC.log`, Dock launch only.

## Verification

- `utils/test_vc_passenger.py` — **12 OK**, including the new
  `test_boarding_lets_go_of_a_latched_lock_on`, which was red before the fix and
  also pins that a refused press keeps the latch.
- Every `utils/test_vc_*.py` harness — **ALL OK** (the change touches
  `PlayerPed.cpp` and `vcmodpanel.h`, which many harnesses read).
- Clean build; the built binary carries `VCModPassengerReleaseAim` and the new
  diagnostic literal.
- Harness note: `ride_functions` now pulls `releaseaim` automatically whenever
  `passkey` is extracted, because the key calls it.

## Next steps

1. Play: press `P` beside the crew car and beside an ordinary car. If it fails
   again, read the `VCMOD passengers: press` line — that names which gate
   refused.
2. If `entering=1` or `control=0`, the next investigation is why Tommy was in
   that state, not the key. If the line shows `control=1 inCar=0 entering=0` and
   boarding still does not happen, the remaining candidates are the passenger
   door search (`GetNearestPassengerDoor`) and `CanPedEnterCar`'s motion test —
   both now documented in this thread.
3. The crew work and the cop flag are accepted; leave them intact.

## Uncommitted

`src/peds/PlayerPed.cpp`, `src/extras/vcmodpanel.h`, `utils/test_vc_passenger.py`
from this round, plus the crew files and the wider tree from earlier handoffs.

## Files not to touch

`~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
read-only. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` carry the macOS
immutable flag. Never install while `pgrep -x reVC` returns anything.
