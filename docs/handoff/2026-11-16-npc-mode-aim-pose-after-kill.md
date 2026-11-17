# A BECOME NPC kill no longer leaves the gun up (2026-11-16)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
Release build `vcmods build 637` installed into `~/Games/VC/reVC.app` with no
game session running. All `utils/test_vc_*.py` harnesses pass. Unplayed.

## The report

BECOME NPC on, the AI driving Tommy: he raises the gun at a target, the target
dies, and the body stays in the raised-gun pose instead of lowering it.

## What the code did

The mode's pose guard in `VCModUpdateNpcMode` released the aim only once the ped
had left `PED_ATTACK`/`PED_AIM_GUN`/`PED_FIGHT`. A completed kill never leaves
those states on the player ped:

- `CPed::ProcessObjective`'s kill completion skips `RestorePreviousState()` when
  the kill belongs to the player in NPC mode (it hands a real ped to the engine's
  wander instead so the stock look-both-ways pose can play).
- That wander hand-off is `SetWanderPath`, which refuses the player
  (`IsPlayer() && !VCModStreetWanderOwnsPlayer()`). STREET IDLE off means nothing
  owns the wander, so the hand-off returns false and the ped gets no new state
  at all.
- The attack's own endings park the aim (`ClearAttack` re-seats the aim clip on
  the still-set `m_pLookTarget`, and `SetPointGunAt` leaves `m_pPointGunAt` on
  the ped being aimed at), so the state stays `PED_AIM_GUN` with the clip parked
  on the hold — aimed at the corpse.

Nothing then releases it: the guard skipped the combat states, the AI layer has
no objective to end, and the cop profile's patrol scan is skipped while
`PED_AIM_GUN`.

## The change

`vcmodnpc`: the guard is now `VCModNpcAimPoseDone`, which keeps the old rule and
adds one: the pose also ends when the ped being aimed at is down
(`DyingOrDead`), whatever the ped state. A live kill order still owns the pose —
its completion restores the objective — and a live target, a vehicle target or a
cleared point-gun target leaves the pose alone, so a hunt in progress, an ID
check or a chase keeps its aim.

## Harnesses

- `utils/test_vc_npcaim.py`: new `test_the_aim_pose_ends_when_its_target_does`
  compiles the predicate and drives it over live and downed targets, both states, a
  live kill order, a vehicle target and a ped that is not pointing.
- `utils/test_vc_npcmode.py`: the mode stub gained `CEntity`, `IsPed` and the
  real predicate in its extracted translation unit.

## In play, to check

1. BECOME NPC on with STREET IDLE off (the reported setup), pick a fight as a
   cop/gang body: kill the target and watch the gun come down on the kill frame
   instead of staying raised.
2. A fight that continues (a second hostile still alive) must keep the aim and
   re-raise on the next beat.
3. The ID check and the patrol must still aim at a live civilian.
4. Normal play (BECOME NPC off) is untouched: the guard only runs in the mode.

## Follow-up worth a session

`CPlayerPed::m_bFreeAimActive` is a player-only flag that NPC mode does not
clear on engage (`VCModNpcBodyDirty` does not test it), and it is one of the ways
into `PED_AIM_GUN` during an AI attack (`PedFight`'s free-aim attack ending calls
`SetPointGunAt(nil)`). This change releases the leftover pose regardless of how
it was entered; the flag itself may still steer an AI burst's ending.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. reVC is an upstream checkout: no branch,
worktree, fork or push of it. Handoffs and published artifacts name no AI.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0`; build 637 is
> installed. Read `docs/handoff/2026-11-16-npc-mode-aim-pose-after-kill.md`
> first, then `AGENTS.md` and `docs/architecture.md`. Uncommitted in this tree:
> the NPC mission-target hunt, the ped-wounds row, the keys/panel work, and this
> session's change — in BECOME NPC, a kill no longer leaves the player ped
> parked in the aim pose; `VCModNpcAimPoseDone` releases the pose when the ped
> being aimed at is down. In play, check a kill with STREET IDLE off, a fight
> that continues, and the cop ID check. Open lead: `m_bFreeAimActive` survives
> the engage into NPC mode.
