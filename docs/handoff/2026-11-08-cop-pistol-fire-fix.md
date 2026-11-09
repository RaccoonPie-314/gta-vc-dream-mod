# Two-hand colt — fire animation lookup

Date: 2026-11-08
Repo/branch/HEAD: `reVC/`, `vcmods`, `d01bb3c` + uncommitted `src/peds/PedFight.cpp`,
`src/peds/Ped.cpp`, `src/peds/PlayerPed.cpp`, `src/extras/vcmodpanel.h`,
`src/extras/vcmodpanel.cpp`
Installed: `~/Games/VC/reVC.app` carries the first two passes. The third pass
(stand-still during the shot) is built clean but not installed yet — a session
was running (pid 13353); run `scripts/install.sh` once it is closed.

Not verified in play. The build compiles clean and the harness is green; the
shooting check is the owner's.

## Symptom

With `COLT TWO-HAND` on, holding aim shows the cop pose, but firing loops the
clip without a shot (reads as a locked animation) and no bullets leave the gun.

## Root cause

`CPed::SetAttack` blended the cop clip (`ANIM_WEAPON_FIRE_3RD`) for the player via
`VCModCopFireAnim`, but the per-frame fire routine `CPed::Attack` looked the clip
up behind `m_nPedType == PEDTYPE_COP`. For the player the lookup missed, the
"no weapon anim yet" branch re-blended the clip and returned before the firing
code, so the shot block never ran.

## Change

`reVC/src/peds/PedFight.cpp`, `CPed::Attack`: the lookup now keys off the same
`VCModCopFireAnim(this, ourWeapon) == ANIM_WEAPON_FIRE_3RD` decision that chose
the clip to blend, so cops and the two-hand player take the cop timings
(11/19/14 frames) and reach `GetWeapon()->Fire`.

Second pass, after the first build played and shot but split the grip:

- `VCModCopTwoHandPose(ped, info)` is now the single predicate (row on, player,
  `WEAPONFLAG_COP3_RD`) behind both pose helpers; declared in `vcmodpanel.h`.
- `CPed::AimGun` clears `CPedIK::AIMS_WITH_ARM` while that pose is active. The arm
  IK rotated the gun hand onto the target (lock-on aim looked one-handed) and the
  support hand stayed with the clip; hip fire re-set the flag through
  `SetAimFlag(float)`, so the grip split for the whole burst. With IK off, the
  clip holds both hands and the torso does the aiming, like the other
  `CANAIM_WITHARM` weapons.
- `CPlayerPed::RotatePlayerToTrackTarget` now has its own rule for the pose.
  `colt45_cop` drives the arms *and* the thighs (in this skeleton the thighs hang
  off the spine), so the old 25°-deadband body clamp left a torso twist that
  sheared the legs and broke the grip. For the pose the whole body turns onto the
  target at `CPed::TurnBody`'s staring rate (20% of the remaining angle a frame)
  and the torso only covers the gap while the body catches up. This also keeps
  `GUN_POINTED_SUCCESSFULLY` set, so locked-on shots still go to the target.
- `VCModCopUpperBody` keeps the pose upper-body only: `colt45_cop` also keys the
  root and both legs (a cop stance plus root offsets up to ~0.14m), and as an
  overlay those replaced Tommy's walk legs and shifted the whole skeleton, which
  is the "body locked in place / legs enlarged" report. The helper nils the
  sequence pointers of Root, both thighs, calves and feet on every player copy of
  the clip (aim, attack blend and the re-blend in `Attack`), so the lower body
  keeps the movement clip and the skeleton stays anchored.
- `nVCModCopHoldFrame` stays 0: `colt45_cop` (extracted from `models/gta3.img` →
  `colt45.ifp`, 1.933s) starts and ends in the lowered stance, and that lowered
  hold is what a locked-on two-hand hold should sit at between bursts.
- Burst recovery: when the trigger is let go with a lock target, the old code
  parked the clip at the loop end and `PointGunAt` snapped it straight to the
  lowered hold. `Attack` now leaves the clip running for the pose and `PointGunAt`
  returns until the clip's lowering tail has played to its end (cut 0.05s before
  `totalLength`, because the end pose equals frame 0), then parks the hold. That
  is the same lowering the hip-fire path already plays after a burst.

Third pass, after the upper-body strip played clean but let the player walk
through the shot:

- Player movement is root motion: the walk/run clips carry `ASSOC_HAS_TRANSLATION`
  and their Root translation is extracted into `m_vecAnimMoveDelta`
  (`FrameUpdate.cpp`), weighted by `1 - totalBlendAmount` of the partials covering
  Root. The old full-body cop clip covered Root, so it zeroed that extraction and
  pinned the player for the whole shot. The upper-body strip gave the root motion
  back — hence walking while firing.
- `VCModCopTwoHandFiring(ped, info)` (PedFight.cpp, declared in `vcmodpanel.h`):
  pose active and (`PED_ATTACK` or the recovery flag). While it is true the
  movement input is zeroed, so `m_fMoveSpeed` stays 0, `SetRealMoveAnim` fades to
  idle and the root motion dies — immobile like before, with normal idle legs
  instead of the clip's baked stance.
- Applied on both movement paths: `MovementDisabledBecauseOfTargeting` (used by
  `PlayerControlZelda`) returns true for it, and `PlayerControl1stPersonRunAround`
  (the mouse third-person path, which never calls that gate) zeroes
  leftRight/upDown/padMove/padMoveInGameUnit itself. The parked lowered hold
  (aim, not firing, recovery done) still allows walking.

New `reVC/utils/test_vc_cop_pistol.py`:
- compiles the pose predicate, the two pose-selection helpers and the firing
  predicate with stubs and checks player/cop × flag-on/flag-off × colt/other gun
  × attack/hold/recovery states;
- asserts `Attack` looks up `ANIM_WEAPON_FIRE_3RD` for the two-hand player before
  the primary clip, `SetAttack` keeps blending through the helper, `AimGun` drops
  the arm IK for the pose, `RotatePlayerToTrackTarget` turns the body at the stare
  rate for the pose, the pose strips the root/leg sequences at every attach site,
  the burst sets/clears the recovery flag and waits for the clip tail, the hold
  stays the lowered frame 0, and both movement paths stand the player still while
  the fire clip plays.

## Verification

- `scripts/build.sh` clean; `scripts/install.sh` into `~/Games/VC` (no session).
- `utils/test_vc_cop_pistol.py` (7 tests), `test_vc_reload.py`: pass.
- Pre-existing failures, untouched by this change (panel-tabs refactor changed the
  row table and some markers): `test_vc_adrenaline.py`, `test_vc_character.py`,
  `test_vc_moveanim.py`, `test_vc_passenger.py`, `test_vc_qol.py`.
- Seen in play: shots fire and hit the lock target, the grip holds, the burst
  lowers with the recovery, the stare-rate body turn tracks a running target and
  the legs/skeleton stay normal with the upper-body strip. Remaining report that
  this pass addresses: the player could walk while the shooting animation played.
- In play, to check: lock on and fire a burst — WASD should not move Tommy until
  the clip (and its lowering tail) finishes; the parked lowered hold should still
  allow walking; check both classic and mouse third-person movement; hip fire
  should also stand still during the shot.

## Next steps

1. Install (see above) and play the check above, aiming and hip fire.
2. If it holds: update the `bVCModCopPistol` row note in `README.md` (still says
   paused / arm tracks old target) and add a CHANGELOG entry.
3. If the body still reads wrong, the pose now only drives the upper body; the
   next suspects are the torso aim (`Spine1`, which carries both arms and the
   head) and the stare-rate body turn. The clip lives in `models/gta3.img` →
   `colt45.ifp` (read-only, 1.933s); the hold parks frame 0 and the fire loop is
   the upstream cop timing 11/19/14 frames. Get a screenshot of the bad region
   before changing anything else.

## Do not touch

`~/Games/VC` and `~/Games/VC-ai` game data, especially `anim/cuts.img`,
`anim/cuts.dir`, `anim/ped.ifp` (immutable).
