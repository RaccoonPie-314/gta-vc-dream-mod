# Vice Extended — selected features

Status: selected for consideration, no code yet
Date: 2026-11-08
Source: external Vice Extended 2510 pack (`~/Downloads/vice-extended-october-2025-update_1788102643_908113`).
Not vendored: its `GameFiles` are content and its `ViceEx.exe` is a Windows reVC fork with no source.

Rule for this list: keep the original game, add only fixes that make a visible effect have a
visible source, plus small behaviour polish. No overhauls, no content imports, no SCM rewrite.

## Already identified before this list

| Item | Where it lands | Cost |
|---|---|---|
| Fire truck water cannon has a real tower and matching origins | `CAutomobile::FireTruckControl` (`src/vehicles/Automobile.cpp:3245`) | model + 2 vectors |
| FBI Car / Rancher siren lights that match the fixture | siren-corona switch (`src/vehicles/Automobile.cpp:2080`) | S·C, maybe model |
| Rotor blades cut after the pilot bails | blade test at `src/vehicles/Automobile.cpp:1454` | S·C |
| Live projectiles can be shot down | object branch of `CWeapon::DoBulletImpact`, `CProjectileInfo::RemoveProjectile` | S·C |
| Explosions blocked by walls | `CWorld::TriggerExplosionSectorList` | M·C |

## Added 2026-11-08

| Item | Version | What it touches | Cost | Assets |
|---|---|---|---|---|
| First-person view | 1.5 | `CCam::Process_1stPerson` exists; needs weapon/clump visibility, aim handoff, collision | L·C | none |
| Weapon reload on a key | 2.5 | clip state (`m_nAmmoInClip` already used by the HUD), reload input, ammo HUD | M·C | none |
| Autosave after missions | 2.5/3.0 | mission-completion detection + save write; stock `main.scm` has no hook | M·C | none |
| Cops crouch, then move to cover | 2.6 | `CPed`/`CPedAI`; `m_duckAndCoverTimer` already exists | M·C | none |
| Longer blood/footprint particle life | 1.0 | particle lifetime (`particle.cfg` / `CParticle`) | S·D | none |
| Rotating steering wheel | 2.5 | needs a steering-wheel node per model, then rotate with `m_fSteerAngle` | S/M·C | model nodes |
| Car light textures enabled | 2.5 | emissive lamp textures on vehicle models + light state | M·C | lamp textures |
| Headlight/taillight ground textures separated | 2.5 | the cast-light shadow path, one texture split into two | S·C | texture |
| Engine fire/smoke from the grille; bike beside it | 2.5 | grille/engine position already exists (`src/vehicles/Automobile.cpp:1536`); bike offset is new | S·C | none |
| Open doors can slam | 2.5 | `CAutomobile::ProcessOpenDoor` + door close anim and sound | S·C | none |
| Wheel falls off on hard impact | 2.0 | detachable wheel node and physics | M·C | none |
| Front wheels keep steer angle after exit | 2.0 | stop the steer reset on exit | S·C | none |
| Engine and lights off while holding exit | 2.5 | exit-hold input + vehicle state | S·C | none |
| Improved wheels / new wheel models | 2.5 | `models/generic/wheels.dff/txd`, wheel IDs | S·A | wheels |
| Hide wanted stars when there is no search | ini | HUD | S·C | none |
| Remove zeros in money | ini | HUD | S·C | none |
| Unique newspapers after missions | 2506 | `newspapers.txd` swap on mission completion | M·C | newspaper TXD |
| Mirror mode by default | 2506 | renderer world matrix | S·C | none |

Duplicate in the request: "Remove zeros in money" was listed twice; it appears once above.

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
