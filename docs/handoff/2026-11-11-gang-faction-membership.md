# Gang faction — registration and gaze confirmed; camera-free aim built

Status updated **2026-11-12**. Workspace `vc-mod`, reVC checkout `reVC/`, branch
`vcmods`, HEAD `8d57f7c96b291bd95ec9fe5677d85233f8ca4de2`. All changes remain
uncommitted; no commits, tags, branches, worktrees or pushes were made.

The installed binary is **vcmods build 359** in `~/Games/VC/reVC.app`, installed as
executable plus re-sign only while no session ran; the other 31 bundle files kept
their hashes and the deep signature verifies. Full suite: **212 tests OK**.

## Current checkpoint — 2026-11-12 (later)

Never-wanted and downed-target gaze are play-confirmed by the user.

New report: during autonomous gang shooting, Tommy could only hit targets near
the crosshair. Cause: stock mouse-camera code (`Cam.cpp` Process_FollowPedWithMouse
and the PC_PLAYER_CONTROLS tail of Process_Behind) writes the camera heading into
the player's rotation every frame while `CanStrafeOrMouseControl()` is true, which
covers IDLE/ATTACK/FIGHT/AIM_GUN/FLEE. The torso IK then could not reach an
off-crosshair target, `GUN_POINTED_SUCCESSFULLY` stayed clear and the shot left
along the hand. Fix: `CPed::CanStrafeOrMouseControl` returns false for the player
while `VCModStreetWanderOwnsPlayer()` (the ped AI owns him), and the three
player-only camera-aim branches in `Weapon.cpp` (FireInstantHit, FireShotgun,
FireAreaEffect) carry the same gate, so shots fall back to the target/heading
paths every NPC uses. This also stops the camera turning him during NPC flee.
Normal play and STREET IDLE input breaks are unchanged. `utils/test_vc_npcaim.py`
(3 tests) covers it. Not yet play-confirmed.

## Earlier checkpoint — 2026-11-12

Never-wanted is now enforced in `Wanted.cpp`: direct levels cap at zero, queue
insertion and immediate reporting are suppressed, pending crimes are discarded,
and Update clears existing/suspended wanted before reporting. Ignore flags and
cop pursuit objectives are untouched; chase save/restore is unchanged.

Gang SetAttack now reaches the stock fallen-victim retrying-look fallback.
Combat IDLE with a living on-foot kill target stays out of player controls;
camera-behind and sprint look clearing yield to the same native combat ownership.
No gaze duration or IK changes were made. A 250ms `VCMOD gang gaze` probe logs
objective/target identity, fall/get-up state, health, look/aim/restoration/retry
flags, deadlines and head/torso pitch. These are code-level repairs, not yet
play-confirmed; GETUP objective progression still needs runtime observation.
The previously confirmed post-kill hold and scratch are unchanged.

Focused read-only review found one required test-fidelity correction, now resolved:
the gaze harness now extracts both real SetLookFlag overloads, SetLookTimer,
MoveHeadToLook, ClearLookFlag and RestoreHeadPosition. At clock 1000, the native
100ms duration produces deadline 1100, preserves that deadline on another timer
request, and expires only after it. Retry survives an unreachable IK result, not
a native timer expiry; restoration and cooldown gates are exercised. IK geometry
itself remains stubbed, so these checks do not prove the reported visual outcome.
Combat-IDLE stopping from nonzero speed and sprint-look preservation are covered.
All eight gaze tests and the final 209-test suite pass. Build 357 is installed;
no further code or install work is pending before play checks.

The source differences below describe the pre-fix investigation.

Continues `docs/handoff/2026-11-11-npc-civilian-reactions.md` and
`docs/handoff/2026-11-11-npc-probe-evidence.md`. Spec:
`docs/specs/2026-11-11-gang-faction-membership-design.md`. Plan:
`docs/plans/2026-11-11-gang-faction-membership.md`.

## Confirmed in play

- Attack drive works first try: Tommy closes and fights autonomously (ProcessObjective
  + gang-scoped Attack/Fight/PointGunAt in the player switch).
- Cop chase is **stock**, not a bug: CopAI wantedLevel==0 → CopPatrolScan
  (CopPed.cpp:527) chases any `IsGangMember()` ped on sight (Ped.cpp:1975, no IsPlayer
  exclusion on the chase branch; player only excluded from the hassle branch 1992).
  Play-tester chose full 1:1 (cops chase too).
- Ordinary gang-to-gang chat prefers the same faction. The existing player chat
  exception precedes the gang restriction in WillChat, so a civilian may initiate
  chat with gang Tommy. Do not describe this mod's eligibility as strictly
  same-gang-only. Gangs also gawk; mugging is CRIMINAL-only.

## Fearless gang Tommy (replaces the fight-then-flee bug debug)

Play-tester request: remove ONLY defensive fear/flee from gang Tommy, keep offensive
aggression + hands-up/cower. Approved + implemented + installed (build green, suite
green). Gate = `IsPlayer() && VCModNpcGangActive()`:

1. Both `SetFlee` overloads return early for gang Tommy. SetFindPathAndFlee's
   inline path-seek bookkeeping is unchanged.
2. The entity `SetObjective` overload also refuses the three on-foot fear/flee
   objectives before they can replace fighting. This second gate is essential:
   CopPatrolScan keeps issuing a flee objective to its suspect. Blocking only the
   flee state left that objective able to cancel the kill objective.
3. `ReactToAttack` registers gang backup and sets a persistent kill objective
   with no expiry for gang Tommy, bypassing defensive flee/duck branches.

KEPT: hands-up/cower animations (ReactToPointGun unchanged — they're reaction anims,
not the threat logic; RegisterThreatWithGangPeds is separate), rival-gang hunting
(fearFlags target selection), fight-back, chat, gawk, investigate, cars/attractors,
cops/gangs still chase him. Cower is stock-off for GANG7 (no STAT_GUN_PANIC flag);
hands-up shows. Fear *ducking* left as-is (minor; iterate if it shows in play).

Status: no flee and continuous fight-back were confirmed in play. Rival hunting,
kin backup/friendly-fire immunity and some earlier civilian checks still need
separate play confirmation; do not infer those from the pose result.

## Post-kill pose — final duration verified in play

The full timeline caught gang Tommy in PED_WANDER_PATH, objective NONE,
WAITSTATE_DOUBLEBACK (8), zero velocity and idle_hbhb at full blend. The wait
kept resetting to now + 3500ms: 184408 -> 187908, 186417 -> 189917,
188427 -> 191927. This was a restarted wait, not an unfinished kill objective.

WanderPath now skips node selection while gang Tommy has DOUBLEBACK active and
restores the normal 1m walking arrival radius when no wait is active. Combat's
larger seek radius had made multiple nearby pavement nodes count as reached.

The radius correction also removed the accidental immediate post-kill trigger.
The requested behavior was restored explicitly: a genuinely completed foot or
any-means kill starts one native DOUBLEBACK wait after successful return to
wandering. Missing targets, timer expiry alone, vehicles, failed path handover,
other profiles and non-player peds do not start this post-kill wait. New kill
objectives interrupt DOUBLEBACK and fade its hands-behind-back association.

For post-kill waits only, ProcessObjective passes a random 5000–10000ms pose hold
to SetWaitState. DOUBLEBACK reserves another 2500ms for its unchanged stock
scratch window; the stock scratch subtracts 500ms. Sequence: **5–10s holding the
hands behind the back, roughly 2s for scratch/exit, then walking**. Ordinary
DOUBLEBACK calls with nil retain the original 3500ms timer.

The final hold was confirmed working on 2026-11-12. Combat interruption is
covered by the harness; no separate final-duration interruption play report was
recorded. Tests in `reVC/utils/test_vc_gangfaction.py` extract the real wander,
wait setup, wait update, objective completion and interruption code. At the final
pose confirmation the suite was 195 OK; the current full suite is 209 OK. Keep
this verified behavior intact while checking the new fixes.

## New issue: downward gaze at a fallen combat target

Report: Tommy initially looks/bends down toward an attacked ped who falls, but
his head/body orientation fades too quickly. The intended native behavior keeps
looking at the living target while it is down/getting up or still targeted.
This is distinct from the post-kill pose; do not extend that pose to solve gaze.

Verified source differences:

- Native KillCharOnFootArmed/Melee refresh target look and body turning when
  stationary/in control: `reVC/src/peds/PedAI.cpp:6618–6621,6907–6911`.
- SetPointGunAt sets retrying entity look/aim and INT32_MAX look timing:
  `reVC/src/peds/PedFight.cpp:374–391`.
- The player switch exempts gang ATTACK/FIGHT/AIM_GUN from input control, but not
  IDLE (`reVC/src/peds/PlayerPed.cpp:4304–4342`). ProcessPlayerWeapon clears a
  pointing target without target input (`3873–3875`); ClearWeaponTarget
  (`147–154`) calls ClearPointGunAt, clearing look/aim
  (`reVC/src/peds/PedFight.cpp:507–523`).
- SetAttack's PLAYER1 branch bypasses the NPC downed-victim fallback:
  `reVC/src/peds/PedFight.cpp:656–732`. Camera-behind and sprint also overwrite
  or clear look (`reVC/src/peds/PlayerPed.cpp:4456–4485`).

These are demonstrated ownership differences, not proof of which branch caused
this specific short bend. Trace target identity, fall/get-up state, look/aim
flags, retry flag and restoration timing before choosing the fix. Preserve
native head/torso IK and release conditions, not a timed fake gaze.

Base CPed already runs objectives, aim/head IK and combat before the gang update
repeats objectives/combat. Existing comments saying the base never runs
objectives are misleading. Do not remove calls without regression coverage of
the currently working fighting and handover behavior.

## New issue: never-wanted briefly gains and clears stars

Report: aiming at or killing cops in NPC mode produces stars briefly, then
never-wanted clears them; this loops. Source confirms the ordering:

- `reVC/src/peds/PlayerPed.cpp:4173–4176` updates wanted, then conditionally clears
  nonzero level/chaos. It does not prevent crime registration.
- Cop ReactToPointGun directly raises level 2 for the player:
  `reVC/src/peds/PedAI.cpp:2219–2225`.
- Direct setters and queued/immediate crime entry points have no never-wanted
  guard (`reVC/src/core/Wanted.cpp:89–130,176–189`). Shooting/melee events still
  identify Tommy as the player, irrespective of effective GANG7 identity.
- Queued crimes can survive while level/chaos remain zero and report later;
  inspect AddCrimeToQ, ReportCrimeNow and UpdateCrimesQ.

Fix wanted-state registration rather than hiding stars or clearing them more
frequently. Preserve behavior when never-wanted is off. Do not enable
ignored-by-cops/everyone or disable native gang patrol pursuit; that removes the
separately requested gang behavior. Check chase-owned save/restore handling in
`reVC/src/extras/vcmodchase.cpp` before changing global enforcement.

## Next work

1. Play-check gang shooting with the crosshair pointed away from the target: he
   should turn and hit on his own. Also check normal play aiming/strafing is
   unchanged and NPC flee runs its own way regardless of the camera.
2. Confirm the post-kill hold remains unchanged, then strip temporary probes
   (including `VCMOD gang gaze`); rebuild/test and install only while stopped.

## Probes currently in the build (strip after fix + final confirm)

- `VCMOD gang pose`: per-ped timeline including wandering, actual velocity, wait
  deadlines, target health/death and all animation names/weights/flags. Earlier
  filters excluding wandering missed the freeze. IDLE_CAM and IDLE_HBHB both
  map to idle_hbhb.

- `VCMOD gang react` + branch tags (PedAI.cpp ReactToAttack).
- `VCMOD gang obj` (PedAI.cpp SetObjective).
- Four civilian probes: `VCMOD threat`, `VCMOD civ layer`, `VCMOD corpse`,
  `VCMOD react move` (Ped.cpp/PlayerPed.cpp).

## Not implemented (deliberate / structural)

- Gang weapon (stock gang peds carry a CGangs firearm; Tommy keeps his loadout).
- Group/formation/leader + circle idle cluster (PED_UNKNOWN) — solo player, N/A.
- Rival hunt both ways: wired but untestable until story progress spawns rival gangs.
- Kin chat / backup / friendly-fire immunity: wired, need play confirm.
- Civilian reaction-movement fix still unplayed.

## Mechanism recap (keep PLAYER1, no type swap)

VCModNpcGangActive + VCModGangEffectiveType (GANG7 for gang-profile player);
IsGangMember player-aware; borrows m_fearFlags=GetThreats(GANG7), m_pedStats=PEDSTAT_GANG7
(saved pointer), m_gangFlags GANG7-bit cleared, RANDOM_CHAR; airtight restore via
VCModNpcRestoreGangBorrow. Effective-type in ScanForThreats/WillChat/corpse/
CanBeDamagedByThisGangMember/Weapon melee+bullet/RegisterThreatWithGangPeds. ReactToAttack
+ ReactToPointGun player guards lifted under gang gate. GANG runs the CCivilianPed layer
+ ProcessObjective + engine attack handlers.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` data — read-only.
  `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` (uchg).
- Git: no commit/tag/push. reVC upstream: no branch/worktree/fork. Install only when
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` is empty.

## Paste-ready prompt

> Continue vc-mod, reVC/ branch vcmods, HEAD 8d57f7c, all uncommitted. Installed
> build 359; suite 212 OK. Read the updated gang handoff. Never-wanted and gaze are
> play-confirmed. Camera-free NPC aim (CanStrafeOrMouseControl + Weapon.cpp gates)
> is installed, not play-confirmed. Next: confirm it in play, then strip the
> temporary probes. Preserve the verified 5–10s post-kill hold. No git actions,
> game-data/uchg or save/settings edits; no install over a running session.