# Two-hand colt — shot keeps the cop stance

Date: 2026-11-09
Repo/branch/HEAD: `reVC/`, `vcmods`, `d01bb3c` + the existing uncommitted work, this
session changed `src/peds/PedFight.cpp` and `utils/test_vc_cop_pistol.py`
Installed: not installed by this session. The build tree at
`reVC/build/src/reVC.app` is current; the Dock launcher rebuilds and installs it on
the next start (a session was never checked for, so `scripts/install.sh` was not run).

Not verified in play. The shooting check is the owner's.

## Symptom

With `COLT TWO-HAND` on, the shot played with Tommy's legs held in idle. The cop
fires the same clip with a planted two-hand stance; the player had none of it.

## Root cause

`VCModCopUpperBody` masked `Root`, both thighs, calves and feet on *every* player
copy of `colt45_cop`, and it was called at every attach site — `SetPointGunAt`,
`SetAttack` and both re-blends in `Attack`. The mask exists so the lowered hold can
be walked; applying it to the shot threw away the clip's stance legs, leaving the
movement clip's idle legs under a firing upper body.

It also ran for NPC cops: `SetAttack` called the helper for any ped, so an
attacking cop had its own clip's legs stripped at the aim entry.

## Change

`VCModCopSetStance(ped, assoc, firing)` replaces `VCModCopUpperBody`, in
`reVC/src/peds/PedFight.cpp`:

- player + `ANIM_WEAPON_FIRE_3RD` only, so NPC clips are untouched;
- `firing == false` masks `Root`, both thighs, calves and feet — the lowered hold
  stays upper-body only and the player can still walk with it;
- `firing == true` restores those tracks from the group's unmodified clip
  template (`CAnimManager::GetAnimAssociation(group, anim)`), then re-seeks the
  association to its current time: masked nodes do not advance, so a restored
  track would otherwise sample a stale frame;
- guards on a nil template or an association outside the group table.

Call sites:

- `CPed::SetPointGunAt` — masks, unless the lowering tail is still running.
- `CPed::PointGunAt` — masks once the recovery has landed (after the existing
  `clipEnd - VCModCopRecoverCut` wait).
- `CPed::SetAttack` and `CPed::Attack` (blend and re-blend) — full stance while
  the shot plays. Player movement is still pinned by `VCModCopTwoHandFiring`.

`reVC/utils/test_vc_cop_pistol.py`: the upper-body-only test is replaced by
`test_firing_does_not_strip_the_cop_stance` and
`test_lowered_hold_releases_stance_after_recovery`, plus
`test_stance_tracks_restore_at_current_shot_time`, which compiles the helper with
stubs and checks masking, restoration, the re-seek count, NPC isolation, that the
template is never mutated, and nil-template/nil-frame tolerance.

## Verification

- `bash scripts/build.sh`: clean (Release, `.app` linked).
- `python3 reVC/utils/test_vc_cop_pistol.py`: 9 tests pass.
- Rest of `reVC/utils/test_vc_*.py`: not re-run this session. Five harnesses
  (`adrenaline`, `character`, `moveanim`, `passenger`, `qol`) were already failing
  before this change (panel row-table refactor); the others passed on the same
  uncommitted tree.

## Second pass — the two regression reports

After the first pass was played, two reports came back:

1. Locked on a *running* target with the trigger held, the legs distorted again.
2. After the recovery, moving while still locked on left the upper body stiff.

Both are the same mechanism the clip exposes on the player: `colt45_cop` keys
the pelvis, spine and spine1, and the thighs hang off `Spine`. `CPedIK` aims by
twisting `m_pFrames[PED_MID]` (`PointGunInDirection`'s POSTCONCAT block, and
`RotateTorso`). With the legs restored, that twist drags the baked stance around
the hip — the distortion during a chase. During the lowered hold the clip owned
the torso, so walking never moved it under the clip's static spine — the stiffness.

Changes:

- `VCModCopStanceAim(CPed*)` (`PedFight.cpp`, declared in `vcmodpanel.h`): player
  with the pose active (hold or shot), weapon resolved inside.
- `reVC/src/peds/PedIK.cpp`: `RotateTorso` returns early for that pose, and
  `PointGunInDirection` skips its POSTCONCAT spine twist. `MoveLimb` still runs,
  so `GUN_POINTED_SUCCESSFULLY` and `bCanPointGunAtTarget` are unchanged and the
  body turn in `RotatePlayerToTrackTarget` is what aims the pose.
- `VCModCopSetStance` now masks `Root`, `Pelvis`, `Spine`, `Spine1` and the six
  leg bones for the held pose — the hold is arms only, so the movement clip walks
  and bobs the body under the grip. The shot still restores all of them.

Tests: 11 in `test_vc_cop_pistol.py`, including a compiled mask/restore test over
11 bones, the PedIK wiring, and the hold's bone list. `bash scripts/build.sh`
links clean.

## Third pass — the trigger-hold distortion

Repro from play: lock on, fire once, then hold the trigger — the legs distort.

Root cause: `CPed::SetPointGunAt` does **not** return early in `PED_ATTACK`, and
lock-on re-acquisition calls it (`FindWeaponLockOnTarget` /
`FindNextWeaponLockOnTarget` → `SetPointGunAt`) while the trigger is held.
That call passed `bVCModCopRecovering` (false mid-burst) as the hold state, so
the helper masked the stance **in the middle of the burst**. Nothing re-restored
it until the next re-blend, so the rest of the burst ran the idle spine, pelvis
and legs under the clip's arms — and once the second pass widened the mask to
`Spine`/`Spine1`, that read as worse.

Fix: `VCModCopSetStance` now resolves the weapon and ORs the caller's hold
request with `VCModCopTwoHandFiring`, so a shot always outranks a hold request,
whichever call site fires mid-burst.

## Fourth pass — the mask now follows the clip, not the callers

Repro from play, sharper: lock on, fire once, and **hold fire during the
recovery animation** — the legs distort.

The guard from the third pass keyed on the ped state (`PED_ATTACK` or the
recovery flag). That leaves a window the repro lands in: the tail-end branch in
`PointGunAt` clears `bVCModCopRecovering` and calls the helper with "hold"
while the trigger is held and the ped is not yet back in `PED_ATTACK` (the
attack timer gates `SetAttack`). The mask then lands on a clip that is about to
shoot again, and because masked nodes stop advancing, the spine and legs sit on
an older frame than the arms for the rest of the burst — a distorted stance.

Fix: `VCModCopSetStance` treats the clip itself as the state. A masked node
stops advancing, so masking is only correct for the **parked** clip (the hold);
while the association is `IsRunning()` or recovering it is a shot, a tail, or a
shot starting mid-tail, and it is never masked. The explicit `firing` request and
`VCModCopTwoHandFiring` are kept as extra guards. `PointGunAt` calls the helper
before it parks, so the hold is masked from the following frame.

`bVCModCopRecovering` moved above the helper. Test: the compiled stance test now
drives `ASSOC_RUNNING` explicitly — running + hold request must not mask, parked +
hold request must mask, and a parked mask followed by a shot must restore and
re-seek. 11 tests pass; the build links clean.

It was still reported after that, so the fifth pass took the one track that is
authored purely for the cop model out of the shot: `Root` now stays masked even
while the clip plays. The legs keep the clip's rotations (the stance) but the
clip's body offsets — up to ~0.10 m forward and ~0.14 m down at 0.5 s — no
longer drag the skeleton off the entity while the feet are planted by the leg
tracks. Test expectation updated accordingly (every track restores except Root).

**This is the last inference.** If the legs still read wrong, the remaining
possibility is that the clip's leg tracks themselves do not fit the player
skeleton (thigh translations are authored near the cop's bind pose), and this
cannot be settled from the source — a screenshot of a distorted frame is needed.
The fallback that is guaranteed free of lower-body artifacts is the pre-session
behaviour: arms-only during the shot as well (plain idle/walk legs, no stance).

## Sixth pass — the screenshot settled it

A play frame showed the legs **displaced** out of the hips (a very wide straddle
with straight legs), not merely posed. That is the clip's per-bone translation
channel (KRT0) authored on the cop skeleton being written onto the player's
skeleton. `Root` was already masked in the fifth pass; the pelvis and leg bones
were still applying their translations.

Fix: while the stance plays, the helper sets `AnimBlendFrameData::IGNORE_TRANSLATION`
on `Pelvis`, both thighs, calves and feet — the engine then keeps the animation's
rotations and leaves the bone positions at the player's bind pose (`FrameUpdate`
skips the position write). The flag is cleared when the clip goes back to the
held state. The compiled stance test now asserts the flag is set for those bones
during a shot, never on the arms or `Root`, and cleared on the hold.

Watch for: legs under the hips at normal width, knees bending with the clip,
feet planted; the pose should read as a stance, not a straddle.

Open question from play: whether the previous build (Root masked only) hid the
stance entirely or still showed the straddle — the two reports conflict, and it
decides whether the Root track also has to come back.

## Seventh pass — the missing raise

With the legs fixed, play reported no wind-up: the gun appeared already aimed
when the trigger went down.

Cause: `CPed::Attack`'s loop branch is entered when the clip is **stopped**
(`!weaponAnimAssoc->IsRunning()`), which is exactly the parked hold, so the
first shot fell into it and sought `animLoopStart` (frame 11 — the aim pose).
The clip's raise (frames 0→11, lowered to aimed) was skipped every time.

Rejected in play: the owner wants the cop's fire animation **1:1**, and that
animation *begins* in the stance (loop window 11→19, shot at 14). Starting the
clip at frame 0 made the burst open on the lowered carry instead, which is what
read as "no stance". The raise branch was removed again: the burst seeks to
`animLoopStart` (frame 11, the stance) exactly as a cop's does, and the lowered
hold stays as the between-burst pose.

12 tests pass; the release build links clean. `test_shot_uses_the_cop_timeline`
pins the 11/19/14 frames and the seek.

## Eighth pass — ground grip (Root restored)

Play: the player model floats/glides during the burst, while a cop firing the
same clip spreads his legs and grips the floor.

That grip is the clip's **Root drop** (about 0.14 m at 0.5 s): it lowers the hips
so the widened stance's feet carry weight. Masking `Root` (fifth pass) kept the
hips at idle height, so the same leg rotations hovered. `Root` is restored for
the shot again; only the limb translations stay pinned (`IGNORE_TRANSLATION` on
pelvis, thighs, calves, feet), which is what fixed the displacement.

If the feet still hover, the next step is to unpin the thigh translations too,
which would make the shot byte-for-byte the cop's clip — at the risk of the
straddle returning.

Confirmed fixed in play after that pass (stance, grip, wind-up). **Do not revisit
the stance work.**

## Ninth pass — locked-on movement

Play: locked on without firing, moving made Tommy run with his hands down and
stiff.

Cause: the held pose is arms-only, so the cop clip kept the arms pinned in the
carry while the movement clip drove the legs and torso — no arm swing at all.

Fix: in `PointGunAt`, the held pose fades out (`blendDelta = -8`) while the ped
is walking/running (`PEDMOVE_WALK`, `PEDMOVE_RUN`, or `m_fMoveSpeed > 0.1`), and
fades back in when he stops; firing re-blends it through `SetAttack` as before.
Locomotion owns the body while moving, the two-hand carry owns it while still.

Play: while locked on, WASD lost its direction — every input drove Tommy
forward.

Cause: the no-strafe rule moves the ped along its facing, and
`RotatePlayerToTrackTarget` pins the facing to the target every frame for this
pose. So A/D/W/S all became "forward".

Fix: that aim turn now stands down while the ped is moving
(`PEDMOVE_WALK`, `PEDMOVE_RUN`, or `m_fMoveSpeed > 0.1`), so the no-strafe input
heading wins on the move and the aim turn resumes when he stands still. Firing
already freezes movement, so the stance turn is unaffected.

13 tests pass; the release build links clean.

## In play, to check

1. Lock on and fire: legs should plant into the cop stance with the shot, no idle
   legs, no walk-through, and the gun should still hit the lock target.
2. Release: the burst lowers with its tail; then the lowered hold should allow
   walking with normal legs.
3. Hip fire (no lock target) with the colt: stance on the shot, normal legs after.
4. A cop aiming and firing should look exactly as before (their clip is no longer
   stripped by `SetAttack`).

If the body visibly shifts when the stance enters, the suspect is the clip's root
translation (up to ~0.14 m around 0.5 s) now being applied for the shot; the next
step would be pinning `Root` to the hold's offset instead of the clip's.

## Do not touch

`~/Games/VC` and `~/Games/VC-ai` game data, especially `anim/cuts.img`,
`anim/cuts.dir`, `anim/ped.ifp` (immutable).
