# Handoff — batch 2, engine-medium (2026-11-08)

## Where things are

- Workspace `vc-mod`, code in `reVC/`,
  branch `vcmods`, HEAD `d01bb3c` plus everything below uncommitted.
- Build `scripts/build.sh`; install `scripts/install.sh`; launcher `scripts/make-launcher.sh`;
  tests `python3 utils/test_vc_*.py` from `reVC/` (twelve, all passing).
- Installed app `~/Games/VC/reVC.app` is **`vcmods build 55`** — that is the wheel-loss fix.
  The tree builds **57**. The Dock launcher rebuilds and reinstalls on every launch, so the
  number rises each launch; a build number is not a change set.
- Logs `~/Games/VC/build-launch.log` and `~/Games/VC/reVC.log`.

## State

Batch 2 = the code-only items of the suggested-order group 2 in
`docs/plans/2026-11-08-vice-extended-picks.md`. Five features, each with a panel row, an ini
key under `[VC Mods]` and membership in ALL ON/OFF.

| Item | Row / ini key | Status |
|---|---|---|
| Manual reload on R | `RELOAD ON R` / `ManualReload` | verified in play |
| Cop crouches before cover | `COP CROUCH+COVER` / `CopCrouchCover` | seen in play ("worked I guess") |
| Wheel falls off on a hard impact | `WHEEL FALLS OFF` / `WheelLoss` | verified in play after the hide fix |
| Rotor blades keep cutting after the pilot bails | `BLADES AFTER BAIL` / `RotorsAfterBail` | built, **not played** |
| Shoot live projectiles | `SHOOT PROJECTILES` / `ShootProjectiles` | built, **not played** |

The last two are untested. The user called the rotor change too small to test, and said the
game has no grenade launcher or mines, so the projectile item was skipped. Before committing,
either play them or drop them (files listed below).

## Unverified constants (ours, not from the pack)

- Exit hold: 400 ms (batch 1).
- Cop crouch beat: 1000–2000 ms random.
- Wheel loss: impulse > 700, roughly a 65 km/h square hit; the drop logs the real impulse.
- Shootable projectiles: 0.6 m hit radius around the projectile; player shots only.

## What each change does

- **Reload** — the engine already has clips and a `WEAPONSTATE_RELOADING` sequence; R on foot
  starts it early. `src/extras/vcmodreload.*`, `CPed::StartReloadNow` in `PedFight.cpp`,
  tick from `PlayerInfo.cpp`. R in a vehicle stays the radio key.
- **Cop crouch** — anchored on the first engagement (`bNotAllowedToDuck` going true) in
  `KillCharOnFootArmed`: weapon crouch for a beat, cover search delayed by the same beat, then
  the stock `DuckAndCover` run to a car. `ReactToAttack` stays stock.
- **Wheel loss** — after the piece switch in `VehicleDamage`, a hard enough impulse calls
  `CAutomobile::DropWheel`: `WHEEL_STATUS_MISSING`, loose wheel object, hidden node.
- **Rotor blades** — the blade-collision block is now `CAutomobile::DoHeliBladeCollision`, called
  from the flown branch as before and from the spin-down branch behind the toggle.
- **Shoot projectiles** — `DoBulletImpact` tests the shot segment against live grenades,
  molotovs and rockets before dealing damage; detonation goes through
  `CProjectileInfo::RemoveProjectile`, which picks the boom and credits the source.

## Fixed this session

- **The F5 debug menu could flip the vanilla switches with no effect on blood.** Lifespans were
  re-applied only on a panel click; the pass now runs every frame at the top of
  `VCModPanelRender`, before either menu returns.
- **Wheel spawn but all four wheels still drew.** `SetComponentVisibility(frame, ATOMIC_FLAG_NONE)`
  matches the damage-variant atomic IDs; wheels carry none, so that call re-enabled the wheel.
  `DropWheel` now clears `rpATOMICRENDER` directly, as `BlowUpCar` does.
- **Blades did nothing after the pilot bailed.** The spin-down branch (`engine off, rotor
  decaying`) never reached the blade-collision block, which sat inside the flown branch.

## Traps paid for

- Wheel atomics have no `ATOMIC_FLAG_OK`/`ATOMIC_FLAG_DAM` id: `SetComponentVisibility` cannot
  hide them, and a comment mentioning the function breaks the wheel test's negative assertion.
- A non-player heli takes the spin-down branch, not the flown one: anything heli-related added
  only to the flown branch dies on bail-out.
- `ReactToAttack` fires on later hits, often while the cop is already running to cover; the
  "first" moment for a cop entering cover mode is `bNotAllowedToDuck` flipping true.
- `m_nAmmoInClip` already models clips and the HUD already prints them; do not add a parallel
  ammo system. The HUD order is `reserve-clip` (`Hud.cpp:478`) and is stock.
- The ammo HUD prints `TotalAmmo - AmmoInClip` because `m_nAmmoTotal` includes the loaded rounds.
- Older harnesses inline the panel arrays: adding a row means bumping the count in
  `test_vc_passenger.py` and adding the flag stub in `test_vc_adrenaline.py` /
  `test_vc_character.py`.

## Uncommitted in `reVC/` (the user commits; never push)

- **Batch 1** — `src/extras/vcmodqol.{h,cpp}`, wiring in `Hud.cpp`, `Automobile.cpp`,
  `PlayerInfo.cpp`, `Particle.cpp`, `re3.cpp`, `vcmodpanel.cpp`; `utils/test_vc_qol.py`.
- **Startup crash fix** — `src/core/FileMgr.cpp`, `bundledPath` lifetime in `myfopen`.
- **Bundle identity** — `res/macos/Info.plist` builds as `…reVC.dev`; `scripts/install.sh`
  stamps the shipping id and supports `BUNDLE_ID` (mirrored into `gta-vc-dream-mod/`).
- **Version line** — build counter in `src/CMakeLists.txt`, drawn from `src/core/main.cpp`;
  `scripts/make-launcher.sh` logs the number after install (both copies).
- **Batch 2** — new modules `src/extras/vcmod{reload,copcover,wheel,rotor,shootable}.{h,cpp}`;
  edits to `src/peds/Ped.h`, `src/peds/PedAI.cpp`, `src/peds/PedFight.cpp`,
  `src/vehicles/Automobile.{h,cpp}`, `src/weapons/Weapon.cpp`, `src/core/re3.cpp`,
  `src/extras/vcmodpanel.cpp`; tests `utils/test_vc_{reload,copcover,wheel,rotor,shootable}.py`.
- **Not ours** — `src/peds/PlayerPed.cpp` is another agent's kerbside road-cross look.
  Do not edit or stage it.
- To drop shootable projectiles only, remove `src/extras/vcmodshootable.{h,cpp}`,
  `utils/test_vc_shootable.py`, its row and `&bVCModShootableProjectiles` in `vcmodpanel.cpp`,
  its include and ini read in `re3.cpp`, the include and the seven-line block at the top of
  `CWeapon::DoBulletImpact`, and the `bVCModShootableProjectiles` stubs in the two older
  harnesses. Row count then goes back to 30.

## Next, in order

1. Play or drop the two unplayed items (rotor blades, shootable projectiles).
2. Commit. This is one coherent tree; the `FileMgr.cpp` lifetime fix reads better in its own
   commit if the user prefers to split it.
3. Batch 3 from the picks doc: explosion line-of-sight, FBI siren lights, fire-truck cannon.
   Cast-light split, newspapers, steering wheel and lamp textures stay blocked on shipped
   assets; first person and autosave are the large items.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Check `git status` and the newest handoff before touching `src/core/re3.cpp`,
  `src/extras/vcmodpanel.*`, `src/peds/PlayerPed.cpp`; each was owned by another agent.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is
  read-only.
- The user tests in game; do not call an unplayed change fixed, and do not install while
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` is non-empty.
