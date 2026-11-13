# Lock-on: doom aim sweep fix and aim-walk plant-frame fix — verified

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods` (upstream remote; no
branch/worktree/push here). HEAD `8d57f7c`. The Dock-pinned `~/Games/VC/Vice City
Mods.app` rebuilds and installs this tree on launch.

## Verified in play (user confirmed 2026-11-10)

Lock-on holds through move-and-shoot on the Kruger; shots home. Both fixes below
are uncommitted in `reVC/` alongside the crew/first-person work.

## Done this session

- Reported symptom: lock-on reticle showed but every locked shot missed, all
  weapons. Root cause: `PlayerDoomAim=1` in the live
  `~/Library/Application Support/reVC/reVC.ini` (read-only to agents). Doom aim
  forces `m_wepAccuracy = 60` (PlayerPed.cpp, ProcessPlayerWeapon) and
  `FireInstantHit` then applies the NPC spread branch: ±8 m at weapon max range
  (Weapon.cpp ~938). Colt range 30 m → ~±15°, misses a torso at 10 m.
- The flag was on because the panel ALL ON master sweep included it. Fix shipped:
  `&bVCModPlayerDoomAim` removed from `aVCModSwitched` in
  `src/extras/vcmodpanel.cpp` (~793), exclusion comment extended. The row and its
  ini key stay; only the master sweep no longer touches it.
- The user flipped NPC DOOM AIM off in-game themselves; shots home again.
- Verified: Release build green (`scripts/build.sh`), all 27 `utils/test_vc_*.py`
  harnesses pass. Change is uncommitted in `reVC/` alongside the crew/first-person
  work below.

## Plant-frame unlock (fixed, verified)

User repro: Kruger (body-aim rifle) — lock on, move, shoot → lock breaks.
Cause: in ProcessPlayerWeapon the retention clause
`!bCanPointGunAtTarget && !CANAIM_WITHARM && !aimWalkMoving` dropped the lock
on the shot's plant frame — the attack zeroes input (speed 0, STILL) the same
frame, the movement exemption switches off, and the torso has not re-converged
(RotatePlayerToTrackTarget runs after the check). Angle-dependent, read as
random; pistols are exempt by their CANAIM_WITHARM flag. Latent since AIM WALK
shipped (d6070c5); masked while doom aim sprayed every shot.

Fix: the exemption is the weapon, not the moment —
`bool aimWalk = VCModAimWalkWeapon(this, weaponInfo)` in the clause. The body
clamps onto the target whenever it plants, so a catching-up torso never drops
an aim-walk lock. Range break unchanged; row off keeps stock behavior.
test_vc_aimwalk's lock-survival test rewritten (red→green); all 27 harnesses
pass; Release build green. Diagnostic probes added for the trace were removed
after verification; the clean build ships on the next Dock launch (a session
was running at the final install check).

Side finding: the user's "free cam" was CONTROL_STANDARD (ini [Controller]
Method=0; classic=1), applied as m_bUseMouse3rdPerson. They were told to flip
it back via Options → Controller Setup → Control Method; settings files are
read-only to agents. Whether it flipped via restore-defaults is unconfirmed.

Ruled out so far:

- Street idle: `VCModStreetBlockReason` blocks on aiming, input, move speed —
  cannot start a pose/chat while locked.
- `DoesTargetHaveToBeBroken`: range check only, deterministic.
- FREE_CAM paths: live ini has `FreeCam=0`.
- Uncommitted per-frame additions (crew update, first-person tick, passenger
  entry) do not obviously touch the on-foot lock; crew only acts when called.

Lock-clear paths to keep tracing:

- `ProcessPlayerWeapon` outer gate (PlayerPed.cpp ~3489): `GetTarget()` (latch
  re-arms `NewState.RightShoulder1` each frame at ~3833), `m_nSelectedWepSlot ==
  m_currentWeapon`, `m_nMoveState != PEDMOVE_SPRINT`,
  `!TheCamera.Using1stPersonWeaponMode()`; any flicker → `ClearWeaponTarget`.
- Inner break (~3514): `!bCanPointGunAtTarget && !CANAIM_WITHARM && !aimWalkMoving`.
- `SetObjective` (PedAI.cpp 241/380/417) and `SetIdle` (Ped.cpp ~5123) both call
  `ClearPointGunAt`; find who sets either on the player mid-strafe.
- `ProcessPlayerWeapon` only runs for ped states NONE/IDLE/FLEE/ATTACK/FIGHT/
  AIM_GUN/ANSWER_MOBILE (PlayerPed.cpp ~3934); a state flicker skips it.
- Next read: `PlayerControlZelda` (PlayerPed.cpp ~3572) and `bVCModNoStrafe`
  (live ini `NoStrafe=1`) — strafe handling is the prime suspect.

## Uncommitted in reVC/ (not this session's work except the panel edit)

Crew feature (`src/extras/vcmodcrew.*`, hooks in Ped.cpp SetDie, Game.cpp,
PlayerInfo.cpp, re3.cpp, panel), passenger key rework + `VCModPassengerKey`
(PlayerPed.cpp), cockpit car camera (`vcmodfirstperson.*`, Cam.cpp bonnet cam),
key table additions, harness updates. New harnesses: test_vc_crew,
test_vc_firstperson.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` —
  read-only (AGENTS.md). The ini flip above was the user's own in-game action.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).

## Aim raise on lock-on (built, awaiting in-play verification)

Request: a fresh lock must raise the gun with the ped's own wind-up before the
hold, 1:1 with NPCs, and no shot may leave the gun until it is up.

Design shipped: the raise is the ped entry verbatim — on a fresh lock
(FindWeaponLockOnTarget only; target switching with [ ] does not re-wind) a
player-only state (`VCModAimRaise*` in PedFight.cpp) stands down the instant
body clamp and runs `SetLookFlag` + `CPed::TurnBody()` while planted — the same
stare-rate sweep (20% of the gap per call, done at 0.05 rad) the ped objective
uses. The aim pose keeps blending at the stock 8.0. The trigger is swallowed
in ProcessPlayerWeapon until `TurnBody()` reports done and `VCModAimPoseRaised`
(aim assoc blendAmount >= 1) passes; while walking the walk owns the heading,
so the raise there is the pose blend alone. Release clears the state via
ClearPointGunAt. No timing constant exists anywhere — the speed is the ped's
own by construction. NPCs, free aim and the ducked entry are untouched.
Harness: utils/test_vc_windup.py (8 checks); full suite 28/28; Release build.

If the feel is off in play, the levers are: run TurnBody while walking too
(fights the walk heading), or gate fire on TurnBody even while walking — both
are design changes, not constants. The clean build was installed with the game
closed, so it is live in ~/Games/VC now.

## Next steps

1. Nothing open on lock-on. The two fixes sit uncommitted with the crew work;
   the user handles git after manual testing.
2. Control method: the user was told to flip Options → Controller Setup →
   Control Method back to Classic (ini Method=0 is Standard/mouse camera).
   Confirm it stuck if camera behavior comes up again.