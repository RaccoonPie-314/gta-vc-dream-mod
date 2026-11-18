# Follower anims and follow safety (2026-11-17)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `de225b9c`.
Tree builds clean; the running session (reVC PID 67923 at the end) means the
install in `~/Games/VC` is untouched — the Dock launcher builds and installs
this tree on the next start. Nothing is committed.

## What shipped

Two switches on the WORLD tab, both default on, one module.

**`src/extras/vcmodfollow.{cpp,h}`**

- `FOLLOW ANIMS` / `bVCModFollowOwnAnims` / ini `FollowAnims` — a mission char
  following Tommy keeps its own stock animation set for idle, walk, run and
  sprint. Stock hands every player-led follower `ASSOCGRP_PLAYER`
  (`CPed::SetMoveAnim`, Ped.cpp); the crew and CALL GANG exemptions already
  narrowed that, this covers script `SET_CHAR_AS_LEADER` followers (the opcode
  missions use for "follow Tommy"). The leader-paced anim speed (the follower
  matching Tommy's stride rate) is kept — only the clip set changes.
- `FOLLOW SAFE` / `bVCModFollowSafe` / ini `FollowSafe` — a mission char
  following Tommy takes no damage the player deals: bullets, fists, melee,
  explosions he caused, flamethrower burn, and the car he drives. Cops, rival
  gangs, falls, drowning and fires he did not start still hurt. Hooks:
  `CPed::InflictDamage` (one early return after the kin gate, before the havoc
  count) and `CFireManager::StartFire` (no ignition on a shielded follower).

Predicates: `VCModFollowKeepsOwnAnims`, `VCModFollowSafeFromPlayer` — both
require `CharCreatedBy == MISSION_CHAR`; the safety one also requires
`m_leader == FindPlayerPed()`. Crew and CALL GANG followers satisfy that once
linked, so they are shielded too. Switch off = the exact stock path.

Both rows sit after MISSION TARGET on the WORLD page with info/warn lines;
startup reads live in `re3.cpp` beside the other switch reads.

## Finding: friendly fire was removed by the uncommitted diagnostics work

HEAD (`996d3923`) ships a friendly-fire gate in `CPed::InflictDamage`: a
MISSION_CHAR `bIsPlayerFriend` victim takes no damage from the player or from
other mission friends (`victimFriend && attackerFriend`). The uncommitted tree
(diagnostics for the job-SWAT immortal bug, probes since build 691) deletes
that gate — `git diff src/peds/PedFight.cpp` shows the block removed — so builds
made from this working tree let Tommy hurt followers again. That removal is why
the complaint was visible in play.

`FOLLOW SAFE` deliberately restores only the player-to-follower half, for
followers only. It does not restore friend-to-friend immunity, which was the
bleed-not-die suspect in the SWAT investigation. Do not re-add that half
without re-checking the SWAT case.

## Tests

- `utils/test_vc_follow.py` (new): drives the real `CPed::SetMoveAnim` (mission
  follower keeps its set, switch off borrows Tommy's, random-char follower
  still borrows), drives both predicates (player and his car refused, cop and
  driverless car still land, non-follower and ped-leader follower not
  shielded), and asserts the rows, ini reads and all three engine call sites.
- `test_vc_crew.py`: stub for the new predicate (the crew animation test
  compiles `SetMoveAnim`).
- `test_vc_adrenaline.py`, `test_vc_character.py`: the panel housekeeping
  commit left these red at HEAD — they still cut `VCModPageHasFind` (removed)
  and missed `VCModMainCell`/`VCModFindOnPage`; extraction lists fixed and the
  two new flags stubbed.
- `test_vc_passenger.py`: row count 85 → 88 (two follow rows plus the HEALTH
  KEY row from the in-flight work).

Whole suite green.

## Uncommitted state

This session: `vcmodfollow.{cpp,h}`, `utils/test_vc_follow.py`, edits to
Ped.cpp / PedFight.cpp / Fire.cpp / re3.cpp / vcmodpanelregistry.cpp, and the
four harness files above.

Not this session (in-flight diagnostics/health work, left alone):
`vcmodhealth.{cpp,h}`, `test_vc_health.py`, the `Script*.cpp` probes,
PlayerPed.cpp, Population.cpp, vcmodkeys.*, test_vc_keys.py — and the
PedFight.cpp friend-gate removal described above.

## Next steps

1. Relaunch from the Dock launcher and check WORLD tab: FOLLOW ANIMS and
   FOLLOW SAFE, both on.
2. Play-test in a mission with a follower (e.g. Death Row / Cop Land): the
   follower should walk and run with its own gait, not Tommy's; Tommy's shots,
   punches, flamethrower, grenades and car must not scratch it; cops must still
   be able to kill it.
3. Toggle each switch off mid-session; the next walk/run change must return to
   Tommy's clips and stock damage for both.
4. Then commit (with the in-flight work separated or included by its owner).

## Do not touch

Game data (`~/Games/VC`, `~/Games/VC-ai`, reVC settings), the `uchg` anim
files, and the in-flight health/diagnostics work above. The launcher refuses to
install over a running session; wait for the game to close.
