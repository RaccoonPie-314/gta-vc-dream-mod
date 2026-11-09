# Handoff — batch 1 verified in play (2026-11-08)

## Where things are

- Workspace `vc-mod`, code in `reVC/`,
  branch `vcmods`, HEAD `d01bb3c` plus the uncommitted work below.
- Build `scripts/build.sh`; install `scripts/install.sh`; launcher `scripts/make-launcher.sh`;
  tests `python3 utils/test_vc_*.py` from `reVC/` (seven, all passing).
- Installed app `~/Games/VC/reVC.app`, **`vcmods build 43`**
  (`strings ~/Games/VC/reVC.app/Contents/MacOS/reVC | grep '^vcmods build '`).
- The Dock launcher rebuilds and reinstalls on every launch, so the build number goes up
  each time the game is started. A build number is not a change set.
- Logs `~/Games/VC/build-launch.log` and `~/Games/VC/reVC.log`.

## State

Batch 1 is done and seen in play. The five behaviours, the `VANILLA FIXES` panel row and the
bottom-right build line all work in the shipping build. `VANILLA FIXES` defaults on; each item
has its own ini key under `[VC Mods]` (`VanillaFixes`, `HudCleanup`, `KeepWheelAngle`,
`ExitHoldOff`, `LongerFx`).

What play confirmed (builds 42/43), with the log to back it:

- Money without leading zeros, empty wanted stars hidden (`$0`, `$1234`, no star outlines).
- Wheels keep their angle after getting out.
- Exit hold: engine and lights die ~410 ms into the hold; a tap leaves them on.
  `vcm: exit hold 408ms: engine off (model 150)` in `reVC.log`.
- Blood and sand live twice as long: `vcm: fx lifespan x2: blood 4000, blooddrop 4000, dust 2000`.
- Item 6 (door slam, bike fire) closed without code: both behaviours are already in reVC.
- Item 7 (mirror mode) dropped: the pack only ships a debug-menu toggle, off by default.

Not yet exercised: turning `VANILLA FIXES` off and watching all five revert. The wiring is
there (the other four read their flags per frame; the particle pass now runs every frame from
`VCModPanelRender`, so a flip in either the panel or the F5 debug menu applies on the next
frame), so this is a confirmation, not a fix.

## Uncommitted in `reVC/` (the user commits; never push)

- **Batch 1** — `src/extras/vcmodqol.{h,cpp}`, wiring in `Hud.cpp`, `Automobile.cpp`,
  `PlayerInfo.cpp`, `Particle.cpp`, `re3.cpp`, `vcmodpanel.cpp`.
- **Startup crash fix** — `src/core/FileMgr.cpp`, `bundledPath` lifetime in `myfopen`.
- **Bundle identity** — `res/macos/Info.plist` builds as `…reVC.dev`; `scripts/install.sh`
  stamps the shipping id and supports `BUNDLE_ID` (mirrored into `gta-vc-dream-mod/`).
- **Version line** — build counter in `src/CMakeLists.txt`, drawn from `src/core/main.cpp`;
  `scripts/make-launcher.sh` logs the number after install (both copies).
- **Tests** — `utils/test_vc_qol.py`; flag stubs in `test_vc_adrenaline.py` and
  `test_vc_character.py`; `test_vc_passenger.py` row count 26.
- **Not ours** — `src/peds/PlayerPed.cpp` is another agent's kerbside road-cross look.
  Do not edit or stage it.

## Fixed this session

- **The F5 debug menu could flip the vanilla switches without effect on blood.** Those entries
  write the bools directly, but lifespans were only re-applied on a panel click, so
  `longer blood/sand` looked dead there. The pass now runs every frame at the top of
  `VCModPanelRender`, before either menu returns; the two click-site calls are gone.
- **Wheels did nothing in build 41.** The guard was on the abandoned branch only, but the
  player's own get-out goes through `CPed::SetExitCar`, which sets `STATUS_PLAYER_DISABLED`
  (`src/peds/PedAI.cpp:4524`), and that branch zeroed the angle first. Both branches respect
  the flag now; `STATUS_WRECKED` still straightens.
- **Exit hold did nothing in build 41.** The tick required the ped to still be seated when the
  400 ms expired, but the exit starts on the press, so the window is only the get-out
  animation. It now arms on the press while driving, remembers the car, and cuts while the key
  is still held whether or not the ped is out. It validates the pointer against the vehicle
  pool and skips a car an AI driver took.
- **Particles were never broken**; the build-41 report was perception. Three `vcm:` lines now
  print the captured raw values, the applied pair and each mode change.

## Next, in order

1. Toggle `VANILLA FIXES` off in the panel and confirm all five revert (money padded, star
   outlines back, wheels straighten, engine stays on, blood back to stock).
2. Commit. This is one coherent change set; the `FileMgr.cpp` lifetime fix reads better in its
   own commit message if the user prefers to split it.
3. Only then start batch 2 from `docs/plans/2026-11-08-vice-extended-picks.md`.

## Traps paid for

- The player's get-out status is `STATUS_PLAYER_DISABLED`, not `STATUS_ABANDONED`; checking
  only the abandoned branch silently does nothing.
- Exit begins on the first frame the exit key is down, so anything gated on being seated for a
  few hundred milliseconds can never fire.
- Getting out of a car also clears `bInVehicle` and `m_pMyVehicle`; a pointer captured at the
  press must be validated against `CPools::GetVehiclePool()` before use.
- Do not install while `pgrep -f "reVC.app/Contents/MacOS/reVC"` is non-empty.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Check `git status` and the newest handoff before touching `src/core/re3.cpp`,
  `src/extras/vcmodpanel.*`, `src/peds/PlayerPed.cpp`; each was owned by another agent.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC`
  is read-only.
- The user plays and tests themselves; do not claim an in-game fix without their run.
