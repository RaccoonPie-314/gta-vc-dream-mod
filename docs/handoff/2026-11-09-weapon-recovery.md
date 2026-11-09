# One recovery tail for every firearm

Date: 2026-11-09
Repo/branch/HEAD: `reVC/`, `vcmods`, `57f4568` + this session's changes (uncommitted)
Installed: `~/Games/VC/reVC.app` is `vcmods build 155`; the tree builds **161**.
This session did not install and did not start a session. The Dock launcher rebuilds
and installs 161 on its next start.

Not verified in play. The shooting check is the owner's.

## The question, answered

The two-hand colt's "recovery" is not a special clip: `colt45_cop` is 1.933 s long,
`weapon.dat` only loops frames 11–18, and the remainder returns the arms to the
lowered carry. Every firearm clip has the same shape, so the tail exists for all of
them. Measured from the IFPs in `models/gta3.img`, cross-checked against the known
`colt45_cop` numbers (aim hands 0.13 m apart, lowered 0.60 m):

| Weapon(s) | Clip | Length | Loop end | Tail |
|---|---|---|---|---|
| Colt45, Tec9, Silenced Ingram | `colt45_fire` | 0.900 s | 0.600 s | 0.30 s |
| Python | `python_fire` | 2.033 s | 1.033 s | 1.00 s |
| Shotgun | `shotgun_fire` | 1.533 s | 1.133 s | 0.40 s |
| Spas-12 / Stubby | `buddy_fire` | 2.000 s | 0.667 / 1.667 s | 1.33 / 0.33 s |
| Uzi / MP5 | `UZI_fire` | 0.767 s | 0.467 s | 0.30 s |
| M4 / Ruger | `RIFLE_fire` | 0.767 s | 0.567 s | 0.20 s |
| M60 | `M60_fire` | 0.767 s | 0.533 s | 0.23 s |
| Flamethrower / Minigun | `FLAME_fire` | 1.200 s | 0.433 s | 0.77 s |

The arm path is real, not an idle repeat: `colt45_fire`'s right hand sits ~+0.49 m
above the pelvis at the aim frame and ends ~0.56 m below it (arms at his side);
`python_fire` opens at the two-hand aim and ends with the hands ~0.59 m apart and
down at hip height.

Why the player never saw it while aiming: `CPed::Attack` parks the clip on the loop
end whenever the burst ends and the player still holds aim. NPCs skip that branch
and run the clip to its end, which is why their arms drop after a burst.

## Change

One panel row, **GUN RECOVERY** (`bVCModWeaponRecovery`, ini `WeaponRecovery`),
default on, part of ALL ON/OFF.

- `reVC/src/extras/vcmodpanel.{h,cpp}`, `src/core/re3.cpp`: the switch, the row
  (COMBAT page, after COLT TWO-HAND), the debug-menu entry, the ini read, and the
  ALL ON/OFF list.
- `reVC/src/peds/PedFight.cpp`:
  - `VCModWeaponRecoveryWanted()` — player, row on, not ducking, not the two-hand
    pose, and the clip's `totalLength` past `loopEnd + VCModCopRecoverCut`.
  - `bVCModWeaponRecovering`: the burst-end branch leaves the clip running;
    `PointGunAt` then returns before its aim-frame seek while the clip is past the
    loop end, so the tail plays out and **stays on its lowered end pose** — that
    lowered end is the hold, the same way `colt45_cop`'s carry is the two-hand
    hold. The clip ends with `ASSOC_FADEOUTWHENDONE`, so the hold cancels that
    fade (`ASSOC_DELETEFADEDOUT`, `SetBlend(1, 0)`); otherwise the arm would fade
    into the idle pose and the aim clip would be re-added on top. A first lock-on
    still parks on the aim frame (gun up and pointing), because the flag is only
    armed by a finished burst.
  - A new burst outranks the lowered hold: `Attack` clears the state and rewinds
    the clip to `animLoopStart` (with full blend) so the gun comes up and the shot
    fires instead of being swallowed by the parked tail.
  - `ClearPointGunAt` clears both recovery states when the aim is dropped, so the
    arm fades out from the lowered pose.
- `reVC/src/peds/Ped.cpp`, `CPed::AimGun`: the arm IK stands down while recovering,
  the same way it already does for the two-hand hold — otherwise
  `PointGunInDirectionUsingArm` re-aims the arm the clip is lowering (only Colt45,
  Tec9 and Silenced Ingram set `CANAIM_WITHARM`, but the guard is unconditional).

The two-hand colt is untouched: it is decided before the new branch in `Attack`,
`SetPointGunAt` and `PointGunAt`, and the new predicate returns false for that pose.
Hip fire is untouched too — it already plays the whole clip; the switch only
changes the aim-held burst.

## Verification

- `bash scripts/build.sh`: clean (Release, `.app` linked).
- `python3 reVC/utils/test_vc_weapon_recovery.py`: 7 tests — the predicate truth
  table compiled with stubs (row, player, ducking, two-hand pose, tail length,
  nils) plus the wiring checks (burst-end branch, the abort rewind, the fade before
  the park, ClearPointGunAt, AimGun, panel row and ini key).
- All twenty harnesses pass (`for t in utils/test_vc_*.py`).
  `test_vc_passenger.py`'s row-count fixture was 34 and is now 35 for the new row.

## In play, to check

1. Lock on before firing: the gun should be up and pointing at the target.
2. Fire a burst, release fire but keep aiming: the arm should drop with the clip's
   tail and **stay down** on the lock-on, not rise back to the aim pose.
3. Fire again from that lowered hold: the gun comes up and the shot fires at once —
   no dead trigger.
4. Same with the Uzi, rifle, shotgun and python — the python's tail is a full
   second, so he stands lowered for about that long after a burst. If that is too
   long, the row is the answer, not a per-clip table.
5. With COLT TWO-HAND on, the two-hand colt must behave exactly as before.
6. Turn GUN RECOVERY off: every weapon parks on the loop end like stock.

## Pre-existing uncommitted work, not touched

`src/core/re3.cpp`, `src/extras/vcmodpanel.{h,cpp}`, `src/peds/PlayerPed.cpp` and
four harnesses already carried the ADRENALINE single-row rework before this session
(three-state row, `AdrenalineSlowMo` fold-in). It is still uncommitted and still
passes; this session only added lines beside it.

## Do not touch

`~/Games/VC` and `~/Games/VC-ai` game data, especially `anim/cuts.img`,
`anim/cuts.dir`, `anim/ped.ifp` (immutable). The two-hand colt stance work is
settled — do not revisit it.
