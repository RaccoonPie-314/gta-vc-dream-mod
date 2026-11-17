# A shot from the lock-on walk gets its wind-up back (2026-11-16)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`.
Release build `vcmods build 620` installed into `~/Games/VC/reVC.app` with no
game session running. All `utils/test_vc_*.py` harnesses pass. Unplayed.

## The report

Moving, locking on, then pressing fire without stopping: the shot started
instantly — no raise, no blend, no tail.

## What the code did

- `CPlayerPed::FindWeaponLockOnTarget` armed the aim-raise on every fresh lock.
  The raise block in `ProcessPlayerWeapon` then threw it away on a moving entry
  ("the walk entry has no wind-up"), because AIM WALK fades the aim clip out and
  the pose can never land while he walks.
- With the raise dead, the trigger was open and `SetAttack` blended the aim clip
  back in over 8/s from the pose the walk left it parked on: the aim hold. So the
  clip time was already at the firing frames — the shot came from a pre-raised
  pose that was not even visible yet.

## The change

A lock taken up mid-walk no longer starts the raise: the gun stays in the carry
and the trigger arms the climb when he actually fires.

- `vcmodcombat`: `VCModAimRaiseFromCarry(ped)` arms the same raise when the aim
  clip is below full weight (parked on the aim hold with the walk's fade on it).
  It rewinds the clip to 0 and blends it in at the stock rate, so the clip's own
  raise frames play; a clip sitting in a tail is left for `PointGunAt` to play
  backwards. A clip whose length does not reach the hold keeps the stock entry
  instead of a dead trigger.
- The climb it arms is "carried": `VCModAimRaiseCarried` plants the player
  (`MovementDisabledBecauseOfTargeting`) and neither the AIM WALK fade nor the
  moving branch of the raise block can cancel it.
- The press that armed the climb stays owed: `VCModAimRaiseTakeShot` fires it
  once the climb lands even if the trigger was a tap, and the owed shot is
  dropped with the lock (`VCModCombatClearTails`).
- `ProcessPlayerWeapon`: the arm call sits before the trigger gate; the owed shot
  is read at the end of the function, after the lock validity handling.

No invented timings: the climb is the clip's own raise frames, the blend is the
stock 8 rate, and the trigger opens on the same pose test a standing lock uses.

## Harnesses

- `utils/test_vc_windup.py`: three new tests (the carry entry arms before the
  gate, the cold rewind and blend, the tap's owed shot, the standstill-only lock
  raise); `test_the_trigger_waits_for_the_raise` no longer asserts a single
  `SetAttack` site or a gate-free weapon function.
- `utils/test_vc_aimwalk.py` unchanged and passing.

## In play, to check

1. Hold a rifle/Uzi/M60, walk, lock on, keep walking and press fire: he plants,
   the gun climbs from the carry, then the burst starts — raise, fire, tail.
2. Tap fire while walking at a lock: one shot once the gun is up, then the tail.
3. Lock while standing: unchanged (the climb starts on the lock).
4. Walk with a lock and no fire: the gun stays in the carry, as before.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. reVC is an upstream checkout: no branch,
worktree, fork or push of it. Handoffs and published artifacts name no AI.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0`; build 620 is
> installed. Read `docs/handoff/2026-11-16-lockon-walk-shot-windup.md` first,
> then `AGENTS.md` and `docs/architecture.md`. The uncommitted tree also holds
> the NPC mission-target work (`src/extras/vcmodnpctarget.*`). This session's
> change: a shot pressed while walking at a lock now plants the player and plays
> the aim-raise climb (`VCModAimRaiseFromCarry`) before firing, instead of
> firing from a pre-raised pose; taps are buffered until the climb lands. If the
> entry feels wrong in play, the levers are the clip's own raise frames and the
> stock 8 blend rate — no invented timers.
