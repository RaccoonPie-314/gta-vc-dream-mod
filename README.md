# GTA VC: Dream Mod

Some features i always wanted in the game, now made it into mods. All of it compiled into the game
itself, every one of them a live toggle.

`vc-mods.patch` against reVC `miami` commit `a26fff4`.
Built and run on macOS arm64 (Apple clang 21, CMake + vendored librw GL3/GLFW)
against licensed game data. Everything described as seen was turned on at the
keyboard; the rest says what it got, in `CHANGELOG.md`. Still unverified: the ini
seeding at startup, panel hit-testing at other window sizes, and the items the
changelog lists as built but unplayed.

## Apply

```
scripts/bootstrap.sh [dest]     # clone, detach a26fff4, apply the patch
```

or by hand:

```
git clone -b miami --recurse-submodules https://github.com/mrxenginner/reVC.git
cd reVC && git apply ../vc-mods.patch
```

## Scripts

`vcmods` in the reVC checkout is the branch that carries the work; upstream
`miami` stays untouched at `a26fff4`. New features get committed there, then
`sync.sh` re-derives the patch from the branch diff, so the patch is a build
product rather than something you hand-maintain.

```
scripts/sync.sh        # vc-mods.patch := git diff miami..vcmods   (run after every commit)
scripts/build.sh       # cmake Release
scripts/install.sh     # bundle -> game folder, re-sign
scripts/package.sh     # zip the game folder for a flash drive; --public drops Rockstar data
scripts/package-win.sh # portable Windows folder: reVC.exe, Play.bat, game data, mods
scripts/publish.sh     # small folder fit to hand out: patch, docs, scripts, nothing else
scripts/bootstrap.sh   # rebuild the whole thing from a clean machine
```

`package.sh` and `publish.sh` are for two different audiences: the first is your
own stick copy and keeps the game data, the second is what goes anywhere public
and refuses to run if it finds any.

`package-win.sh` is the second machine's path. It stages a portable folder —
`reVC.exe`, the game folder, `mods/` and `scripts/windows/Play.bat` — and zips it.
`Play.bat` starts the game with `cd /d "%~dp0"`, so the folder runs from wherever
it is unpacked: no drive letter, no install path. `--public` leaves the Rockstar
data out. The exe has to be built on Windows (`premake-vs2022.cmd`); pass `--exe`
when it is not under `reVC/bin`. That build has no CMake build counter, so the
version line shows `vcmods <sha8>` rather than a build number.

The loop while features are still being added: edit in `reVC/`, commit to
`vcmods`, `sync.sh`, `build.sh`, `install.sh`, play. Half-way states live in
commits on that branch, never in the patch. When something's finished, update
`CHANGELOG.md` and run `package.sh` for the stick.

To push that to GitHub, in order:

```
scripts/sync.sh                                              # branch -> patch
VC_MODS_OPERATOR=me scripts/publish.sh ./gta-vc-dream-mod    # patch -> handout folder
cd gta-vc-dream-mod && git commit -am '...' && git push      # folder -> github.com/RaccoonPie-314/gta-vc-dream-mod
```

`publish.sh` refreshes that folder in place and leaves its `.git` alone, so the
same directory is both the build product and the working clone.

One hazard worth five seconds: run `git rev-parse --show-toplevel` from this
folder. If the answer is anything other than `reVC`, a stray repo encloses your
home directory, and `git add -A` from here sweeps it. Do git inside `reVC/` (the
mod branch) or inside a folder `publish.sh` just created.

## Build on macOS arm64

```
brew install cmake openal-soft mpg123 glfw
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j8
```

Produces `build/src/reVC.app`. Two routes that do *not* work, so don't spend
time on them: the repo's `conanfile.py` is Conan 1.x API and Homebrew ships
Conan 2.34, and Homebrew's premake 5.0.0 aborts on `premake5.lua:376`
(`flags` nil). Plain CMake with the vendored librw submodule is the path.

Toggles are debug-menu entries, so the build needs `DEBUGMENU` — enabled for
non-`MASTER` builds at `src/core/config.h:274`. If you build with `MASTER`
defined the tweak block compiles out and the mods stay off.


Open the mod panel with `\` in game. The debug menu page **VC Mods** (Ctrl-M) is
still there and drives the same variables.

## The panel

`src/extras/vcmodpanel.cpp` is the mod's whole control surface: the toggle
variables, the animation-group tables, the debug-menu rows and the on-screen panel
all live there, so `PlayerPed.cpp` keeps only the behaviour hooks.

- Colour comes from charsets, the same mechanism the debug menu uses to highlight a
  selected row — `RtCharsetCreate(&fg, &bg)` with an opaque background, and every
  cell padded to a fixed column width so the glyph backgrounds tile into one
  continuous panel instead of text floating over the game.
- Green `[ON]`, grey `[--]`, cyan for the anim set name, amber for a warning,
  lavender for the key hints, magenta title bar.
- A row flips on mouse click. **ANIM SET** has no boolean: clicking it opens a list
  of all seventeen groups beside the panel, marked `+` when closed and `-` when open.
  Picking a name sets it (marked `>` in green) and turns the swap on; clicking the
  row again, or anywhere outside both panels, closes the list. It opens beside the
  panel rather than pushing rows down so the panel keeps one shape.
- A row with modes cycles instead of flipping: **ADRENALINE** steps
  `OFF` → `NORMAL` → `SLOW-MO` → `OFF` on each click, and **VANILLA FIXES** steps
  `OFF` → `ON`. One row per feature is the rule now — a switch and its mode used to
  be two rows, which is two clicks and two states to reconcile.
- Six tabs — **COMBAT**, **PLAYER**, **DRIVING**, **WORLD**, **KEYS**, **DEBUG** —
  split the rows so the panel stays one screen high; DEBUG holds the two read-only
  path probes. KEYS holds the mod's own hotkeys: click a row and the next key press
  becomes the binding (Esc cancels), and **RESET KEYS** restores the shipped letters.
  Clicking a tab switches page and closes any open list, and the last tab is
  kept for the session. The master switch sits at the right end of the title bar as
  `[ALL ON]` / `[MIXED]` / `[ALL OFF]`, and still leaves WALK MODE and NO STRAFE
  alone.
- `PERMA` column: the first three columns of a row are a pin cell, `[ ]` or `[x]`.
  Clicking it pins the row, which writes the current value into `[VC Mods]` at once
  and rewrites it on every later change; clicking it again deletes the key. The rest
  of the row flips the switch or opens its list. Rows with nothing to remember
  (call driver, skip ride, the path read-outs, ped category) leave the cell blank.
- The cursor is geometry, not a glyph — a charset `+` at 8px was unreadable. Two
  filled `RwIm2DRenderPrimitive` triangles (dark edge under a white one, ~20px),
  drawn *after* `RtCharsetBufferFlush()` so it sits on top of the panel instead of
  under it. It follows the game's own `MousePointerStateHelper` invert settings;
  ignoring them made it move against the hand pointing it.
- Two warnings, shown only when the combination is actually broken: scope
  suppression without *aim all weapons* (the sniper has no `CANAIM` bit), and
  lock-on off while the mouse camera is up (the two-finger hold then does nothing).
- Drawn from `VCModPanelRender()`, called right after `DebugMenuRender()` in
  `main.cpp`. It does not pause the game, but it does consume mouse deltas into its
  own cursor while open, so the camera will not turn until you close it.
- It stands down while the Ctrl-M menu is open (`DebugMenuIsActive()`, one accessor
  added to `debugmenu.cpp`) — the menu's page column occupies the same corner, and
  with both drawn the panel covered Cheats and everything else.

## Config file

The switches take their **startup defaults** from `reVC.ini`
(`~/Library/Application Support/reVC/reVC.ini`, or next to the exe on Windows),
read in `LoadINISettings()` with the engine's own `ReadIniIfExists`:

```ini
[VC Mods]
NpcAnims = 0
AnimChoice = 0
MouseAimLockOn = 0
AimAllWeapons = 0
PlayerDoomAim = 0
NoScopedAim = 0
WalkMode = 0
LockOnVehicles = 0
NeverWanted = 0
LockOnLatch = 0
Adrenaline = 0
PedModel = -1
RideZone = -1
RideStyle = 0
NoStrafe = 0
CopPistol = 0
WeaponRecovery = 1
ManualReload = 1
CopCrouchCover = 1
WheelLoss = 1
RotorsAfterBail = 1
ShootProjectiles = 1
ExplosionCover = 1
FbiLights = 1
FireTruckCannon = 1
SteeringWheel = 1
TrafficAI = 1
VanillaFixes = 1
HudCleanup = 1
KeepWheelAngle = 1
ExitHoldOff = 1
LongerFx = 1
```

`1`/`0`, and `AnimChoice` is the index into `aVCModAnimGroups` (0 = man, 8 = woman,
15 = panicchunky). `PedModel` is a model index, `-1` meaning Tommy. `RideZone` is
an index into the ride destination list, `-1` meaning cruise with traffic.
`RideStyle` is `0` safe or `1` fast and aggressive; an old ini that still says `2`
for the removed skip style is clamped to safe. Section and key names are case sensitive — `MINI_CASE_SENSITIVE`
is on in this build. A plain key is a preset: **the ini seeds it, the panel owns it
from then on**, and flipping an unpinned row in play does not write back. A pinned
row works the other way — pinning writes it at once and every later change to it is
written too, so the file remembers what you left the row at. An absent key means
"not pinned", which matters for the switches that default on: deleting their key
turns them on again at the next launch, it does not turn them off.

Hotkey bindings use the same section but their own rule: a binding is a setting,
not a pinned row, so it is written the moment it changes on the KEYS page. The
keys are `KeyPanel`, `KeyWalk`, `KeyFire`, `KeyDriver`, `KeyKick`, `KeyReload`,
`KeySpot`, `KeyCapture`, `KeyFirstPerson`, `KeyCrew` and `KeyPassenger`; the value
is the key code (printable keys are ASCII,
the rest are the engine's `RsKeyCodes`). An absent or nonsense value falls back to
the shipped default, so deleting one resets that hotkey.

## Toggles

| Toggle | Default | Effect |
|---|---|---|
| `bVCModPlayerNpcAnims` | off | Tommy plays the chosen NPC animation group for locomotion in every weapon state |
| `nVCModAnimChoice` | 0 | Which group, as an index into `aVCModAnimGroups` |
| `anim: <name>` rows | — | One row per group; activating a row selects it **and** turns the mod on |
| `bVCModMouseAimLockOn` | off | Auto-lock stays reachable while mouse-aim is on |
| `bVCModAimAllWeapons` | off | Bypasses the `WEAPONFLAG_CANAIM` requirement, so `weapon.dat` needs no editing |
| `bVCModPlayerDoomAim` | off | Tommy aims like a ped: `m_wepAccuracy` drops to the ped default 60 and the shot goes through the ped deviation branch instead of the player's ramped one |
| `bVCModNoScopedAim` | off | Sniper / M4 / RPG aim with lock-on instead of taking the 1st-person scope camera |
| `bVCModWalkMode` | off | Caps movement to walk speed (0.9) and the walk anim; the WALK MODE key (KEYS page, `B` by default) flips it in play |
| `bVCModLockOnVehicles` | off | Lock-on also considers driven vehicles — cars, bikes, boats, helis |
| `bVCModLockOnLatch` | off | Aim button latches: one two-finger press locks on and stays, the next releases |
| `bVCModNeverWanted` | off | Wanted level is forced back to 0 every frame |
| `nVCModAdrenalineMode` (key `Adrenaline`) | 0 | One row cycling `OFF` → `NORMAL` → `SLOW-MO`: reproduces the native adrenaline pill without picking it up. `NORMAL` keeps every effect and leaves the world at full speed with the legs at their normal rate; `SLOW-MO` adds the native `SetTimeScale(1/3)`. An old ini's `AdrenalineSlowMo` key is folded into the mode once and then dropped |
| `nVCModPedModel` | -1 | Character to wear, as a model index; `-1` is Tommy |
| `bVCModCopPistol` | off | Two-handed colt hold using the cop's own fire, aim and stance clips. Left out of ALL ON/OFF so it cannot come on during other testing |
| `bVCModWeaponRecovery` | on | After a burst while still aiming, the fire clip plays out its authored tail — the same lowering an NPC runs — and the lowered pose becomes the hold until the next shot. Every firearm clip has one; the two-hand colt keeps its own path |
| `bVCModAimWalk` | on | A locked-on target no longer roots the player. Any gun walks — the parked aim pose fades out while he moves and comes back when he stops — while the shot and its recovery tail still plant him, so the lowering lands before the walk starts |
| `nVCModRideZone` | -1 | Where the NPC driver goes: `-1` cruises with traffic, otherwise a map zone from the destination list |
| `nVCModRideStyle` | 0 | How he drives there: `0` safe — stops for traffic and for red lights; `1` fast and aggressive — ploughs through both |
| `SKIP RIDE` row | — | One-shot travel to the **RIDE TO** destination, on foot or from a passenger seat. Never bound to the enter key |
| `CALL DRIVER` row | — | Calls the chauffeur, or dismisses one already coming. The CALL DRIVER key (`H`) does the same |
| `CALL CREW` row | — | Calls the three-man crew, or dismisses one already out. The CALL CREW key (`V`) does the same |
| `CREW CAR` row (key `CrewCar`) | Admiral | The four-door car the crew arrives in; the list is every four-door car this install loads |
| `bVCModNoStrafe` | off | The direction keys choose the body's heading — `A`/`D` turn instead of side-stepping. Aiming or firing hands the heading back to the camera |
| `bVCModNpcAutoType` (row `TYPE FROM BODY`) | on | BECOME NPC derives the profile from the worn body's stock ped type: Tommy and gang bodies run GANG as the body's own gang, police bodies COP, every other body CIVILIAN. NPC TYPE shows the derived profile while it runs; cycling NPC TYPE turns this off and applies the chosen value |
| `bVCModManualReload` | on | The RELOAD key (`R` by default) starts the reload on foot instead of waiting for the clip to empty. `R` is also the car radio key, so the tick does nothing while driving |
| `bVCModVanillaFixes` (row `VANILLA FIXES`) | on | One row for the four fixes below. It reads `[ON]` only when all four are on, and switching it on restores the whole set |
| `bVCModHudCleanup` | on | Money shows as `$42` instead of `$00000042`, and empty wanted stars are not drawn. Ini and Ctrl-M only — the row is the master above |
| `bVCModKeepWheelAngle` | on | The front wheels keep their last steering angle when the car is abandoned instead of snapping straight. Ini and Ctrl-M only |
| `bVCModExitHoldOff` | on | Holding the exit key while driving cuts the engine instead of getting out. Ini and Ctrl-M only |
| `bVCModLongerFx` | on | Blood and foot-dust particles live twice as long. Ini and Ctrl-M only |
| `bVCModCopCrouchCover` | on | A wanted cop who takes fire drops into a firing crouch for a beat before running to cover |
| `bVCModWheelLoss` | on | A very hard impact tears the nearest wheel off and throws it as a loose object |
| `bVCModRotorBlades` | on | A heli's rotor keeps cutting while it spins down after the pilot bails |
| `bVCModShootableProjectiles` | on | A shot that passes through a live grenade, molotov or rocket sets it off |
| `bVCModExplosionCover` | on | A building between a blast and a target stops both the damage and any chain detonation behind it |
| `bVCModFBILights` | on | The FBI Car and FBI Rancher get the cruiser light bar on the roof |
| `bVCModFireTruckCannon` | on | The water jet starts at the tower mount whether the player or the AI drives, and the arrow keys aim it |
| `bVCModSteeringWheel` | on | The pack car models' steering wheel node turns with the front wheels |
| `bVCModTrafficAI` | on | The traffic layer: right-lane driving, horn on a blocked road, and the path fixes from `mods/` |

## Mod hotkeys

Eleven keys are checked by the mod itself rather than by the controller binding
table, because `gta_vc.set` rewrites that table on load. All eleven are rebindable
on the panel's **KEYS** page; the shipped defaults are:

- `G` = fire. A trackpad cannot hold the two-finger aim button and press the left
  mouse button at the same time. Left Ctrl still fires too, and `Insert` (numpad 0)
  is the other stock default — absent on a laptop.
- `B` = toggle walk mode.
- `H` = call the chauffeur, or dismiss him. Checked outside the on-foot block, so
  it also works from the back seat, where the player state is `PED_DRIVING`.
- `K` = the spinning roundhouse.
- `R` = manual reload, on foot only.
- `J` / `U` = the chase prototype's spot teleport and coordinate log.
- `C` = the cockpit view on and off.
- `V` = call the crew, or dismiss it. Like `H` it is checked outside the on-foot
  block, so it also works from a seat.
- `P` = board the nearest car as a passenger, driver or not.
- `\` = open the panel.

Clicking a KEYS row arms it and the next key press becomes the binding in the same
moment; `Esc` cancels, and **RESET KEYS** restores all eleven. A binding is saved to
`[VC Mods]` in `reVC.ini` immediately. While a capture is armed the mod's own
hotkey handlers stand down, so the key used to bind does not also fire, reload or
toggle. Binding a key that another action already uses is allowed — both actions
fire. The chase prototype's tier digits 0–4 and its Enter/Backspace keys stay
fixed, and the game's own controls stay on the pause menu's Controller Setup page.

Walk mode is capped in **both** on-foot control paths: `PlayerControlZelda` (the
camera-relative one) and `PlayerControl1stPersonRunAround`, which is what actually
runs whenever `Using3rdPersonMouseCam()` is true. The cap can cross the walk/run
boundary in one frame, so `SetRealMoveAnim` now crossfades the incoming clip at
that boundary instead of swapping the blend weights directly, the way
`CPed::SetMoveAnim` blends an NPC's move-state change. Starting from a standstill
with the cap on fades into the walk clip the same way instead of cutting into it.

The scope toggle has three parts: the mode request and the sniper-family early
return in `ProcessPlayerWeapon`, the "you have to zoom first" click in
`ProcessControl`, and `CWeapon::Fire` — `FireSniper()` returns false outside a
1st-person camera mode, so with the toggle on the player's sniper goes through
`FireInstantHit()` like every other weapon and NPC does, otherwise it clicks and
never fires. The RPG only needed the click suppressed; `FireProjectile` was never
scope-gated.

Mouse buttons as the engine actually maps them (`InitDefaultControlConfigMouse`
uses `RsKeyCodes`, so the numbers are 1 = LMB, 2 = MMB, 3 = RMB):

| Gesture | Action |
|---|---|
| one finger / click | fire |
| two fingers, held | lock-on target — this is `PED_LOCK_TARGET`, not look-behind |
| middle button | look behind |
| two-finger scroll | cycle weapon |

With `bVCModNoScopedAim` on, those weapons fall through to the same lock-on path as
the rest. The sniper has no `WEAPONFLAG_CANAIM` in `weapon.dat`, so it also needs
`bVCModAimAllWeapons`.

The debug menu has no dropdown widget, so the picker is a list of rows — one per
group — rather than a value that cycles. `nVCModAnimChoice` is kept as a plain
number so the current selection is readable.

While strafing (PC mouse-control mode) the override stands down and the stock
`playerback/left/right` groups are used, because no NPC group contains side-step
clips — forcing one makes A and D play a forward walk.

## Characters

Two rows pick who Tommy wears: **PED CATEGORY** (cops / gangs / civilians /
mission) then **CHARACTER**, Tommy always first so there is a way back. The list
is read out of the model table the game loaded rather than a hand-kept list, so
nothing goes stale when the ide changes. It shows what each body is rather than
the ide's name — `Cuban gangster 1`, `Hispanic girl, street`, `Candy Suxxx` — and
falls back to the raw model name for anything it does not recognise.

The worn model brings its own animation group, gated by the same playability
check the animation picker uses, and the swap happens in the update pass, never
inside the render. Tommy keeps his own ped stats through it, because respawn goes
through `Undress`/`Dress`, which re-takes stats from whatever model is worn.

The **mission** shelf is a special case: `default.ide` declares slots
`MI_SPECIAL01..21` as `special01`..`special21` with a generic texture dictionary,
and no file answers to those names. Selecting one used to stream an empty model
and hand a nil clump to `CPed::SetModelIndex`, which crashed. The shelf now
resolves each slot through the game's own cutscene table (`igcandy`, `igdiaz`,
the `csplay` variants) and only offers a slot whose file is actually in the
archive. Anything that still cannot be resolved is refused before the ped is
touched.

## Passenger riding

The passenger key (`P`) puts Tommy in the passenger seat of the nearest car within
10 m — driven or empty; nobody has to be at the wheel. Planes, helis and trains are
passed over, and so is a wrecked car, with a message when that leaves nothing to
board. A full car is refused the same way. The enter-vehicle key is untouched: on
an ordinary car it is the game's own driver entry and carjack, and only the limo
you called takes it as a passenger press.

A driven car is held with `MISSION_STOP_FOREVER` until Tommy is actually seated,
the same trick the shortcut taxi uses, so it cannot drive off without him; an empty
one is left to the game's own update, since nobody is there to drive off. That hold
is never left behind: walking more than 30 m from the car, fifteen seconds without
getting in, getting into another car, or pressing the passenger key beside a
different car all hand the held car back to traffic at once, and the entry
objective is cleared so Tommy does not chase a car that drove off. A car the
traffic system is still simulating on rails (`STATUS_SIMPLE`) is promoted to real
physics before its route is touched: entering as the driver does that when the
player sits down, but entering as a passenger never does, and the on-rails update
writes the car's position directly — it would drag the car sideways onto the path
lane the moment the ride re-routes. **RIDE TO**
then chooses what the driver does, and it starts on `auto`: the pause-map marker
while one is placed, traffic otherwise. A named district from the game's zone
table routes there; the marker can also be picked by hand. Either way the ride
parks on arrival, and a destination changed mid-ride — another zone, or a marker
placed, cleared or moved more than 25 m — re-routes the car. Arriving keeps the
ride open with Tommy still in the car — the driver waits where he stopped, and
getting out is what ends the ride. The street car is then handed back to traffic
with the cruise speed, driving style and `m_fMaxTrafficSpeed` it had before the
press, so its
driver carries on like the traffic around him — generated traffic runs
`STOP_FOR_CARS` at 9–14, and handing it back on the ride's faster `AVOID_CARS`
setting made the driver look like he was bolting. A summoned limo, which never had
a traffic pace of its own, is released at ordinary traffic speed. The ride state is
tracked by vehicle handle, so a car that is blown up or recycled mid-ride is
dropped rather than followed.

## Personal driver

**CALL DRIVER** (or `H`) sends a black Stretch with a chauffeur to wherever Tommy
is standing. It spawns on the nearest car path node behind him — far enough that
the approach is a drive — gets a radar blip, and is made mission-owned so traffic
cannot reclaim it while it waits. It stops within 15 m; if Tommy walks more than
20 m from the pick-up point it is re-targeted every 3 seconds, and walking more
than 120 m away while it waits calls it off, the shortcut taxi's own rule.

Boarding is the ordinary enter key: the limo you called owns its own enter press,
which the game's driver entry never sees. Once Tommy is in the back seat the limo
drives to **RIDE TO** with the
selected **RIDE STYLE** — under the default `auto` that is the map marker, or
ordinary traffic when none is placed. Arriving parks him there until Tommy gets
out; getting out hands the limo back to traffic rather than deleting it, with the
counters and the blip moved the way `ClearShortCut` moves them. A marker off the
road graph, which has no route, ends in the engine's own straight-line drive at
it. Calling again dismisses him —
from the kerb he drives off at once, and from the back seat he waits for Tommy to
get out before going back to ordinary traffic.

**RIDE STYLE** applies to ordinary passenger rides too, and it can be changed
mid-ride:

| Style | Engine settings | What it does |
|---|---|---|
| Safe | `DRIVINGSTYLE_STOP_FOR_CARS`, cruise 20 (25 to a destination) | Slows for cars and peds and stops at red lights |
| Fast | `DRIVINGSTYLE_PLOUGH_THROUGH`, `STATUS_PHYSICS`, cruise 45 (55 to a destination) | No traffic scan, no light stop, no weaving. Bridge stops still apply |

Only the two `STOP_FOR_CARS` styles reach `CTrafficLights::ShouldCarStopForLight`
in `CCarCtrl::SteerAICarWithPhysics`, which is what makes "safe" mean traffic law
rather than merely a slower cruise.

**SKIP RIDE** is a button, not a style. It travels once to the **RIDE TO**
destination: nearest car path node to the zone centre, `LoadScene`/`LoadSceneCollision`,
ground Z plus the entity's base offset, `FindPlayerEntity()->Teleport`, camera jump
cut. It works on foot or from a passenger seat, and a car Tommy is riding in parks
on arrival instead of driving on. It needs a destination, so on `auto` with no map
marker placed, or with **RIDE TO** set to traffic, it says so and does nothing.
The passenger key never travels: pressing
it next to a car always boards and rides.

## Vercetti crew

**CALL CREW** (or `V`) sends three Vercetti gang members — `PGA`/`PGB`, an M4 each —
in a four-door car. The car spawns on a road node behind Tommy the way the
chauffeur's limo does, drives to him with the same **RIDE STYLE**, and stops within
15 m. The men are the game's own gang peds, made by `CPopulation::AddPed` with
`PEDTYPE_GANG7`, so they carry the gang's voice and reactions; each is also given
the M4 and `MISSION_CHAR`. They are linked to Tommy only once seated with him, so
the stock follower rule cannot order them out of the approaching car.

The car comes with a driver, and each man is a stock follower (`CPed::SetLeader` +
`UpdateFromLeader`), so on foot they walk with Tommy, wait at their 30 m leash,
take free passenger seats, and attack whoever he attacks. There is no new AI and no
car gunner.

| Press | Car | Result |
|---|---|---|
| enter key (F) | crew car, driver seated | the driver gets out and Tommy takes the wheel; the ex-driver takes a rear seat |
| enter key (F) | crew car, empty | stock driver entry |
| `P` | any car | passenger seat, driver or not |
| enter key (F) | any other car | stock, carjack included |

`F` on the crew car never carjacks: the press is intercepted, the driver is ordered
out, and Tommy's driver objective is issued only once the seat is clear. If the seat
never clears in 6 s, or Tommy walks more than 10 m away, the driver takes the wheel
back and the car stays at the pick-up. With Tommy driving nobody steers; with a crew
man driving the car follows **RIDE TO**, which on the default `auto` is the map
marker while one is placed and ordinary traffic otherwise.

Getting out ends the ride and leaves an escort: the men get out with him. **CALL
CREW** again dismisses them. They are not despawned — one living man becomes the
leader of the rest and the group is left as an ordinary street gang (mission
ownership dropped, `RANDOM_CHAR`), which the world may reclaim only once it is far
away and off screen. **CREW CAR** picks the car from every four-door this install
loads; the Admiral is the default.

If Tommy dies, the same handover runs at the moment of death, so the crew never
runs the stock dead-leader flee; a kill already in progress is kept.

## Why the group swap crashed, and the actual fix

Two groups crashed in play (`oldman`, `jogger`) while `man` worked. Root cause, in
the engine rather than in the mod:

- `CAnimBlendAssocGroup::CreateAssociations` allocates `assocList` with
  `numAssocs`, the group's own clip count, and assigns ids `firstAnimId + i`.
- NPC walk groups are tiny: `man` has 173 clips, `oldman`/`jogger`/`gang1` have 4.
- `GetAnimation(uint32 id)` was `return &assocList[id - firstAnimId]` with **no
  bounds check**, so asking a 4-clip group for `ANIM_STD_STARTWALK` returned a
  pointer past the end of the array. `CopyAnimation`'s `if (anim == nil)` could
  therefore never fire, because an array address is never nil.
- `CPlayerPed::SetRealMoveAnim()` requests ids well beyond the five locomotion
  slots (`RUNSTOP1`, `RUNSTOP2`, `IDLE_TIRED`, `FIGHT_IDLE`), so the player's move
  code hit that out-of-range read every frame. The engine had already papered over
  it in places by hard-coding `ASSOCGRP_STD` for `IDLE_TIRED`.
- Fault signature matched: `KERN_INVALID_ADDRESS at 0x85` inside the association
  copy constructor, i.e. a garbage `hierarchy` read, not a nil one.

Fix, two parts, both correctness changes in the engine:

1. `GetAnimation(uint32)` now range-checks against `numAssociations` and returns nil.
2. `CAnimManager::CreateAnimAssociation` falls back — player group, then the full
   `std` group — when the current group cannot supply the id, so an NPC walk keeps
   its own clips and borrows Tommy's only for transitions it does not define.

`VCModGroupPlayable()` stays as a third layer: it refuses to install a group whose
existing associations are unusable and logs the clip name.

Behaviour change to be aware of: the fallback is engine-wide, so any ped asking for
a clip its group lacks now gets the player/std clip instead of reading past the
array. That is strictly better than undefined behaviour, but it is not scoped to
the player, and it is the one change here that could in principle alter an NPC.

**Not yet verified in play** — reproducing this needed a spawned Tommy, which
needs someone at the keyboard. Try `oldman` and `jogger` again.




All five flip live. No restart, no reload, because each is read at decision time:

- **Anim group** — fed into `ProcessAnimGroups` as a different `groupToSet`, which
  falls through the engine's own `if (m_animGroup != groupToSet) { ... ReApplyMoveAnims(); }`
  path. That path already exists to handle weapon-group swaps every frame, so
  toggling re-blends walk/run/sprint/idle on the next frame instead of needing a
  re-init. Turning it off restores `ProcessAnimGroups`' original behaviour.
- **Lock-on** — `bVCModMouseAimLockOn` off re-arms the original
  `ClearWeaponTarget()` bail, so a stale lock drops by itself.
- **Doom aim** — read per shot in `CWeapon::FireInstantHit`.

Defaults are all off so an unmodified game behaves normally until you switch something on.

## Which groups are offered

Only groups built from `aStdAnimDescs`, because those carry the locomotion slots
the player path reaches directly (`ANIM_STD_WALK`, `RUN`, `RUNFAST`, `IDLE`): man,
gang1, gang2, shuffle, oldman, fatman, oldfatman, jogger, woman, shopping,
busywoman, sexywoman, fatwoman, oldwoman, jogwoman, panicchunky, skater.

Only the player groups carry a `STARTWALK` slot; every NPC group is four clips
(walk, run, sprint, idle), so the player used to borrow Tommy's start clip and cut
straight into it. With `WALK MODE` on, and on any group without a start clip of its
own, the player now skips the start clip and fades into the movement clip under the
idle, the way `CPed::SetMoveAnim` does for the NPCs; cutting to full weight snapped
the arms out in a single frame, and stopping mid-fade blends the idle back. A
sprint start keeps the start clip's step. The skater group is the extreme case: it
has no start clip anywhere in `skate.ifp`, so it always fades; `ReApplyMoveAnims`
also skips a slot the group does not have. The native `SOUND_SKATING` is driven off
the group too,
because the mod keeps `PEDSTAT_PLAYER` across a model swap; the skater surface
slow-down and trip chance in that branch stay NPC-only. Weapon groups
(`shotgun`, `m60`, `uzi`) have no locomotion slots at all and are not offered.

Verified against licensed stock data: `cop`, `swat`, `fbi`, `army` and `vice1-3`
all use group `man`, so there is no distinct police walk in Vice City — `man` is
what cops actually play, shared with most male civilians. Walk clips differ per
group and are resolvable (`walk_civi`, `walk_gang1`, `walk_player`), so a swap is
visible.

## Also fixed upstream

`CTweakSwitch`'s constructor in `src/extras/debugmenu.h` omitted `m_pFunc` from its
initialiser list, leaving it unassigned before being handed to `DebugMenuAddVar`.
One line. The picker rows no longer use `CTweakSwitch`, so this fix is not
load-bearing for the mod — it is a real latent bug in the engine's own weather
switch, kept because it is correct.

The patch also adds a null guard in `ReApplyMoveAnims`, which previously
dereferenced `GetAnimAssociation(group, slot)->hierarchy` unconditionally. That is a
pre-existing engine crash, not one this mod introduced; with it a group missing a
slot degrades to "not re-blended" instead of faulting.

## Launching, and why the Dock pin kept failing

CMake copies the gamefiles into the bundle (`Contents/Resources/gamefiles/`) and the
engine searches that, so a Dock or Finder launch of `reVC.app` does find `data/` —
earlier notes here blaming the cwd were wrong, and `Contents/MacOS/reVC` is a Mach-O,
not a wrapper script.

The pin failed for a different reason. It pointed at the **build tree**
(`.../reVC/build/src/reVC.app`), which every rebuild deletes and rewrites, and the
installed copy carries the same bundle id `io.github.mrxenginner.reVC`, so
LaunchServices had two claims on one identifier and the click resolved to nothing.
`open` on either bundle worked all along, which is what ruled the engine out.

Fix applied on 2026-11-06: the Dock's stale tile was replaced in
`com.apple.dock`/`persistent-apps` (index 12) with `~/Games/VC/Vice City Mods.app`,
id `local.vcmods.launcher`, and the Dock was restarted. Verify a tile with
`open -b local.vcmods.launcher`.

- `Vice City Mods.app` — a bash `launcher` that cds into `~/Games/VC` and execs
  `reVC.app/Contents/MacOS/reVC`, appending console output to `~/Games/VC/reVC.log`.
  Builds never touch it, so it is the thing to pin.
- Before the edit, the live prefs were exported to
  `~/Games/VC/dock-prefs-before-vcmod.plist`; restore with
  `defaults import com.apple.dock ~/Games/VC/dock-prefs-before-vcmod.plist && killall Dock`.
  Edit them through `defaults export`/`import`, never by writing the plist file —
  `cfprefsd` holds a cache and will overwrite a direct edit.

## Unverified risks, in the order I'd test them

1. **Mouse-aim and lock-on fight over rotation.** While locked,
   `RotatePlayerToTrackTarget()` and mouse-aim both write player rotation every
   frame. This patch lets both run; it does not arbitrate them. Expect either one
   winning outright or visible jitter. This is the item most likely to need a real fix.
2. **`bVCModAimAllWeapons` on melee.** `WEAPONFLAG_CANAIM` is absent from fists
   and bats deliberately. Forcing the aim state onto them may look wrong, and
   `PedFight.cpp:402`/`:428` dereference `GetAnimAssociation(...)->hierarchy->name`
   with the same missing-null guard I removed from `ReApplyMoveAnims`. Test guns first.
3. **Doom-aim and lock-on disagree.** Doom-aim retargets to the closest visible
   entity in a 22.5° cone. With both on, a nearby ped can hijack a shot you locked
   onto someone further away. By design, but it will read as a bug the first time.
4. **Sprinting still blocks aiming** — `m_nMoveState != PEDMOVE_SPRINT` at
   `PlayerPed.cpp:1445` is untouched. Deliberate: relaxing it means entering the
   aim state on transition anims the engine may not have.

## Data-edit alternative

`DEFAULT.DAT` (group token on the `player` line) and `weapon.dat` (`0x40` in the
hex flags column) remain the no-code routes for the anim group and CANAIM.
Neither hot-reloads — both are parsed once at load — and the `DEFAULT.DAT` route
gets overwritten by `ProcessAnimGroups` while armed, which is why the code route
above is the one worth using.
