# BECOME NPC puts the features that fight it down, and hands them back one at a time (2026-11-17)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`
(nothing committed). Release build `vcmods build 646` installed into
`~/Games/VC/reVC.app` with no game session running. All 55 `utils/test_vc_*.py`
suites pass. Unplayed.

## The report

Turning BECOME NPC on while the street features were running left the body
owned twice: STREET IDLE kept its wait and its pair chat, the crew and the
chauffeur kept their seats, and a chase kept staging or teleporting the body it
runs with. Turning the mode off restored everything at once, which is the other
half of the same collision.

## What BECOME NPC now holds

| Feature | Kind | What the mode does | What the hand-back does |
|---|---|---|---|
| `STREET IDLE` | switch | forced off, player's value saved | restored at once |
| `NPC DOOM AIM` | switch | forced off, player's value saved | restored 500 ms later |
| `CALL CREW` | command | a crew that is out is dismissed | called again 1 s later |
| `CALL DRIVER` / `SKIP RIDE` | command | a summoned chauffeur is dismissed | called again 1 s after the crew |
| chase | mission | abort (`VCModChaseAbort`) | never restored |

Left alone on purpose: `COP CROUCH+COVER`, `TRAFFIC AI`, `PED RANGE`,
`NPC ANIMATION`, `WALK MODE`, `CREW AGGRESSIVE` (it is a preference for the next
call). BECOME NPC's own dependents (`WASD MOVE`, `NPC TYPE`, `TYPE FROM BODY`,
`PED WOUNDS`, `MISSION TARGET`, `CALL GANG`, `QUICK ID CHECK`) are untouched.

`NPC DOOM AIM` is in the set because the mode fires with the body's own ped
accuracy (`m_wepAccuracy` from `VCModNpcWepAccuracy`), and the player's doom aim
would deepen that spread on the same shots.

## Where it lives

- `src/extras/vcmodnpcsuspend.cpp` (307) — the held-flag table (order is data:
  the queue walks it), the saved values, the crew/driver "was out" state, the
  resume queue, the mode-on enforcement and the public probes.
  `aVCModNpcHeld[]` is matched by pointer: a new suspended switch goes in its
  enum slot and its table row together.
- `src/extras/vcmodnpcinternal.h` (15) — `VCModNpcSuspendBegin` /
  `VCModNpcSuspendRelease`, called only from the mode's edges.
- `vcmodnpc.cpp` — the on-edge calls `VCModNpcSuspendBegin()` **before** the
  mode body touches anything, which fixes the old bug where the saved
  STREET IDLE value was read after it had already been forced off; the off-edge
  calls `VCModNpcSuspendRelease()`. `bVCModNpcSavedStreetIdle` is gone.
- `vcmodnpc.h` — `VCModNpcSuspendTick`, `VCModNpcSuspendsFlag`,
  `VCModNpcSuspendedValue`, `VCModNpcHoldsCrew`, `VCModNpcHoldsDriver`.
- `core/Game.cpp` — `VCModNpcSuspendTick();` before `VCModChaseUpdate` and
  `VCModCrewUpdate`, so the queue runs while the panel is up or the player is in
  a seat.
- `vcmodcrew.{h,cpp}` — `VCModCrewDismissNow()` (no toggle semantics) and
  `VCModCrewCall()` refuses while the mode runs.
- `vcmodride.{h,cpp}` — `VCModDriverSummoned()`, `VCModDismissDriverNow()` (the
  old toggle branch of `VCModCallDriver` refactored onto it); `VCModCallDriver`,
  `VCModSkipRide` and `VCModPassengerKey` refuse in the mode.
- `vcmodchase.{h,cpp}` — `VCModChaseAbort()`; the `VCMOD_CHASE_OFF` start also
  requires `!bVCModNpcMode`.
- `vcmodcombat.cpp` — the DOOM AIM key refuses in the mode.
- `vcmodpanel.cpp` — the old STREET IDLE ↔ BECOME NPC mutual-exclusion block is
  gone; a held switch refuses activation; `CALL CREW`/`CALL DRIVER` read
  `[HELD]  npc mode` only when that command is actually waiting, `[--]  npc mode`
  otherwise; a held switch's cell shows the player's own value.
- `vcmodpanelregistry.cpp` — `VCModRowValue`, `VCModCountOn` and
  `VCModToggleAll` read the saved value of a held switch, so a pin survives the
  mode intact and the master sweep does not clobber it.
- `docs/architecture.md` — new target-layout row.

## Timing and edges

- A switch comes back on the release frame; the next switch 500 ms later.
- A summon waits 1000 ms after release (and after the crew) so the mode's own
  exit — body reset, ped release — has finished before a car arrives.
- A summon is held, not failed, until the player is on his feet: `IsPedInControl`,
  not in a vehicle, not dying or dead. A call that is made and does not take is
  retried twice, then dropped with a notice (`crew: could not come back`).
- A switch the player already had off is dropped on release: no restore, no
  delay, and the panel can toggle it again immediately.
- A crew in `VCMOD_CREW_DISMISS_WAIT` is already on its way out, so it is not
  counted as "was out" and is not called back.
- Re-entering the mode while the queue is pending cancels the timer and keeps
  the pending settings: the saved value is the player's, not the forced-off one.
- The mode-on enforcement in the tick only claims the switches after
  `VCModNpcSuspendBegin` has run, so the snapshot can never read a value the
  enforcement already forced off.

## Harnesses

- New `utils/test_vc_npcsuspend.py` (11): ordered restore with the gap, a switch
  that was off stays off, re-entry keeps a waiting setting, the mode forces a
  mid-run flip back off, crew+driver dismissal and the queue order, the summon
  gate, a crew already leaving, give-up after three failed calls, an empty queue,
  and the wiring (`Game.cpp` tick, mode edge owns begin/release, no stale field).
- `test_vc_npcmode.py` — the mode now only hands over: begin/release counters
  replace the saved-street-idle assertions.
- `test_vc_passenger.py` / `test_vc_driver.py` — the ride stubs gained
  `summoned`/`dismissnow` and `bVCModNpcMode`.
- `test_vc_crew.py` — `dismissnow` signature and the mode global.
- `test_vc_adrenaline.py` / `test_vc_character.py` — panel stubs for the three
  probes.
- Full sweep: 55 suites, 0 failures. `scripts/build.sh` exit 0,
  `scripts/install.sh` into `~/Games/VC`, ad-hoc re-signed.

## In play, to check

1. STREET IDLE on, NPC DOOM AIM on, a crew out and the chauffeur waiting, then
   turn BECOME NPC on: both switches read held and refuse a toggle, the crew and
   the car are sent home, a chase in progress stops with a notice.
2. Turn it off: `street idle back on`, half a second later
   `npc doom aim back on`, then the crew is called, then the driver. Nothing
   arrives while Tommy is in a seat or dead.
3. Turn it on and off twice quickly: the settings must survive the re-entry, not
   come back as off.
4. Pin STREET IDLE on, run the mode, and confirm the pin still reads on.
5. Leave it off and check the off-path is stock: no notices, no queue.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are `uchg`. Install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. No commit, tag or push unless
asked.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0`; build 646 is
> installed. Read `docs/handoff/2026-11-17-become-npc-suspend.md` first, then
> `AGENTS.md` and `docs/architecture.md`. Uncommitted in this tree: the NPC
> mission-target hunt, PED WOUNDS, the keys/panel work, the aim-after-kill fix,
> the gang rivalry repair, and this session's change — BECOME NPC now holds
> STREET IDLE and NPC DOOM AIM, dismisses the crew, the chauffeur and a chase on
> its on-edge, and hands the switches and the two calls back one at a time
> (500 ms between switches, 1 s before a summon) from `vcmodnpcsuspend.cpp` via
> `VCModNpcSuspendTick` in `CGame::Process`. Turn the mode on and off over a
> running street setup to check the hand-back order and that the pins keep the
> player's value. Play, then commit and push only when asked.
