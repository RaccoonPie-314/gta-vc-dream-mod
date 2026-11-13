# NPC mode gunfire — stock burst explained, double-shot fixed (build 438)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
Installed `vcmods build 438` into `~/Games/VC/reVC.app`. No commit, tag or push.

## The report

Shooting in NPC MODE with the GANG or COP profile fires "2-5 bullets at a
time"; the expectation was one bullet per shot.

## Answer: the 2-5 round burst is stock, the doubling was not

Two separate things were in the report.

**Stock burst.** A gun-carrying pedestrian AI fires in bursts. The attack
objective sets `SetShootTimer(600-1500ms)` (`PedAI.cpp:6718`) and every
fire-animation crossing inside that window is a round; the Colt45 clip loops
about every 0.3 s, so one burst is 2-5 rounds, then a 100-500 ms
`SetAttackTimer` pause before the next burst. Every cop and gang member in the
retail game fires that way; NPC MODE runs their native AI, so the burst count
stays 1:1 after this fix.

**Non-stock double fire.** `CPlayerPed::ProcessControl` calls
`CPed::ProcessControl()` first (`PlayerPed.cpp:2743`), and that base function
runs the ped state switch — including `Attack()` for `PED_ATTACK`
(`Ped.cpp:3356`), `Fight()` for `PED_FIGHT`, and `PointGunAt()` for
`PED_AIM_GUN`. Stock player fire works exactly there: `ProcessPlayerWeapon`
calls `SetAttack` and the base `Attack()` fires the round. The NPC-combat
branch of the player's own switch called `Attack()`, `Fight()` and
`PointGunAt()` a second time in the same frame.

`CPed::Attack` fires whenever the clip's `currentTime` crosses
`m_fAnimFrameFire` this frame (`weaponAnimTime - timeStep <= fire <=
weaponAnimTime`). Called twice with the same clip time, both passes cross and
both call `CWeapon::Fire` — instant-hit weapons have no internal rate gate
(`addFireRateAsDelay=false`, `m_nTimer` set to now), and `WEAPONSTATE_FIRING`
is an allowed state, so the second round left the gun in the same frame. Every
shot consumed two rounds and drew two hits; melee swings were duplicated the
same way through the second `Fight()`.

## Fix

`src/peds/PlayerPed.cpp`, npc-combat branch of the control switch:

- `PED_ATTACK`: the gun case no longer calls `Attack()`; the base layer already
  ran it this frame. The melee branch (`StartFightAttack` + `SetAttackTimer`)
  is unchanged — that is the pad-less ped entry and the only way a fist reaches
  `FightStrike`.
- `PED_FIGHT`: the per-beat `StartFightAttack` re-arm is unchanged; the
  duplicate `Fight()` call is gone.
- `PED_AIM_GUN`: the duplicate `ReactToPointGun` + `PointGunAt` pair is gone;
  the base layer's aim block runs it once.
- The stray-attack `ClearAttack`, stray-fight `EndFight`, combat-idle speed stop
  and the `break` that keeps the pad path out are unchanged.

Harness: `utils/test_vc_ganggaze.py` drops the expectation that the switch
itself calls `Fight()`, and adds
`test_npc_combat_leaves_the_engine_drivers_to_the_base_layer`, which pins that
the base call exists and the switch carries no bare `Attack()`, `Fight()`,
`PointGunAt()` or `ReactToPointGun()` call.

## Verification

- Release build clean; `VCMOD_BUILD_NUMBER` 438; installed into `~/Games/VC`
  with no session running.
- All 43 `utils/test_vc_*.py` harnesses pass (`test_vc_ganggaze.py` 15 tests).
- Not played yet. Expected in game: the same 2-5 round bursts, now one round
  per shot / one hit per swing, and ammo dropping one per report.

## Next

1. Play-test a gang or cop NPC-mode fight and watch the muzzle count against
   the ammo counter (one per report).
2. If melee now feels one beat slower, that is the base-layer call taking over
   the same frame the re-arm happens; the strike itself is unchanged.
3. Do not re-add any of those four calls to the switch — the base
   `CPed::ProcessControl` owns them for every ped, the player included.
