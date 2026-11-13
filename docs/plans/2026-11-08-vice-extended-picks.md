# Vice Extended — selected features

Status: batches 1–4 shipped; the car light textures are built in build 178 and unplayed.
Remaining: cast-light split (needs a decision), newspapers (asset + mission hook), first person,
autosave.
Date: 2026-11-08
Source: external Vice Extended 2510 pack (`~/Downloads/vice-extended-october-2025-update_1788102643_908113`).
Not vendored: its `GameFiles` are content and its `ViceEx.exe` is a Windows reVC fork with no source.

Rule for this list: keep the original game, add only fixes that make a visible effect have a
visible source, plus small behaviour polish. No overhauls, no content imports, no SCM rewrite.

## How the pack is used as evidence

The pack has no source for engine behaviour, so nothing is copied from it. Four evidence kinds:

- **`ChangesEN.txt`** — the behaviour spec. Every row below cites its line.
- **`GameFiles/ViceExtended/features.ini`** — toggles only, no values. It ships the HUD fixes
  and mirror mode at `0`; the picks turn the wanted ones on by default.
- **`GameFiles/ViceExtended/{data,models,txd}`** — tested content. Data-driven picks take their
  values from here (`particle.cfg` was checked and is identical to stock for the five particle
  types, so the longer-life change lives in code, not data). Content picks take the shipped
  files through the `mods/` overlay, never into the repo.
- **`GameFiles/ViceEx.exe`** — a 3.6 MB x64 Windows PE with no symbols. It is the oracle for
  constants that exist only in code; open it only when a value has to match exactly. The values
  that currently do not are under "Unverified constants".

## Already identified before this list

| Item | Where it lands | Cost | Pack evidence |
|---|---|---|---|
| Fire truck water cannon has a real tower and matching origins | `CAutomobile::FireTruckControl` (`src/vehicles/Automobile.cpp:3245`) | model + 2 vectors | `ChangesEN:182` |
| FBI Car / Rancher siren lights that match the fixture | siren-corona switch (`src/vehicles/Automobile.cpp:2080`) | S·C, maybe model | `ChangesEN:186` |
| Rotor blades cut after the pilot bails | blade test at `src/vehicles/Automobile.cpp:1454` | S·C | `ChangesEN:70` |
| Live projectiles can be shot down | object branch of `CWeapon::DoBulletImpact`, `CProjectileInfo::RemoveProjectile` | S·C | `ChangesEN:72` |
| Explosions blocked by walls | `CWorld::TriggerExplosionSectorList` | M·C | `ChangesEN:184` |

## Added 2026-11-08

| Item | Version | What it touches | Cost | Assets | Pack evidence |
|---|---|---|---|---|---|
| First-person view | 1.5 | `CCam::Process_1stPerson` exists; needs weapon/clump visibility, aim handoff, collision | L·C | none | `ChangesEN:152`; code |
| Weapon reload on a key | 2.5 | clip state (`m_nAmmoInClip` already used by the HUD), reload input, ammo HUD | M·C | none | `ChangesEN:115`; code |
| Autosave after missions | 2.5/3.0 | mission-completion detection + save write; stock `main.scm` has no hook | M·C | none | `ChangesEN:91`, moved to script `:60` |
| Cops crouch, then move to cover | 2.6 | `CPed`/`CPedAI`; `m_duckAndCoverTimer` already exists | M·C | none | `ChangesEN:69`; code |
| Longer blood/footprint particle life | 1.0 | particle lifetime (`particle.cfg` / `CParticle`) | S·D | none | `ChangesEN:185`; code — pack `particle.cfg` matches stock |
| Rotating steering wheel | 2.5 | needs a steering-wheel node per model, then rotate with `m_fSteerAngle` | S/M·C | model nodes | `ChangesEN:94`; code + edited models |
| Car light textures enabled | 2.5 | emissive lamp textures on vehicle models + light state | M·C | lamp textures | `ChangesEN:97`; content + code |
| Headlight/taillight ground textures separated | 2.5 | the cast-light shadow path, one texture split into two | S·C | texture | `ChangesEN:128`; content + code |
| Engine fire/smoke from the grille; bike beside it | 2.5 | grille/engine position already exists (`src/vehicles/Automobile.cpp:1536`); bike offset is new | S·C | none | `ChangesEN:99`; reVC already does it |
| Open doors can slam | 2.5 | `CAutomobile::ProcessOpenDoor` + door close anim and sound | S·C | none | `ChangesEN:127`; reVC already does it |
| Wheel falls off on hard impact | 2.0 | detachable wheel node and physics | M·C | none | `ChangesEN:142`; code |
| Front wheels keep steer angle after exit | 2.0 | stop the steer reset on exit | S·C | none | `ChangesEN:141`; code |
| Engine and lights off while holding exit | 2.5 | exit-hold input + vehicle state | S·C | none | `ChangesEN:119`; code |
| Improved wheels / new wheel models | 2.5 | `models/generic/wheels.dff/txd`, wheel IDs | S·A | wheels | `ChangesEN:117`; content |
| Hide wanted stars when there is no search | ini | HUD | S·C | none | `ChangesEN:106`; `features.ini` toggle (ships 0) |
| Remove zeros in money | ini | HUD | S·C | none | `ChangesEN:107`; `features.ini` toggle (ships 0) |
| Unique newspapers after missions | 2506 | `newspapers.txd` swap on mission completion | M·C | newspaper TXD | `ChangesEN:18`; content |
| Mirror mode by default | 2506 | debug-menu toggle only; dropped 2026-11-08 | — | none | `ChangesEN:20`; `features.ini` `MirrorModeByDefault=0`; `ViceEx.exe` string "Toggle mirror mode" sits in the debug menu between "Toggle Comedy Controls" and "Current area" |

Duplicate in the request: "Remove zeros in money" was listed twice; it appears once above.

## Unverified constants

These numbers are ours, chosen from the changelog's behaviour, not read from the pack. If exact
parity ever matters, the target is the code in `ViceEx.exe` that touches
`CParticleSystemManager::m_aParticles[…]m_nLifeSpan` after the config load, and the exit-hold
timer in the vehicle entry path:

| Value | Ours | Pack says | Extract from the exe |
|---|---|---|---|
| blood/dust lifespan | ×2, applied after the config load | `ChangesEN:185`; its `particle.cfg` is identical to stock | the multiplier written after `Initialise()` |
| exit hold before engine off | 400 ms | `ChangesEN:119` only | the hold duration before `bEngineOn = false` |
| mirror mode | not built, item dropped | toggle only, ships `0`, no gameplay definition | nothing to read; decision taken 2026-11-08: no code |

Alternatively, run the pack on Windows and compare the two builds side by side.

## Blockers and decisions

- **Asset override path.** reVC has no modloader, and `~/Games/VC` data is read-only by project
  rule. Wheels, lamp textures, cast-light texture and newspapers need a shipped override
  (own IMG mount, packed copies in the bundle, or texture replacement at load) before those rows
  are implementable.
- **Steering wheel node.** VC models are not guaranteed to have a wheel node; the pack's models
  were edited for it. Check per model before counting this as a code-only fix.
- **Autosave policy.** Decide when it fires, which slot it writes, and whether it overwrites.
  That is a savegame behaviour change even though the format is untouched.
- **First person** overlaps the existing aim and camera mods; scope it against `Process_1stPerson`
  and the weapon render pass before estimating.

## Suggested order

1. HUD and small behaviour: wanted stars, money zeros, front wheel steer, exit hold, door slam,
   particle life, bike smoke, mirror default.
2. Engine-medium: reload, cops cover, wheel loss, cast-light split, newspapers.
3. Asset-dependent: steering wheel, light textures, wheels, newspapers.
4. Large: first person, autosave.

Build and install checks follow `AGENTS.md`: the change ships only when the Dock launcher builds
and installs it into `~/Games/VC`, and never while a session is running.
