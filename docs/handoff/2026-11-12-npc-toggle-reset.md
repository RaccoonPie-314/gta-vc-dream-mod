# NPC mode: toggle-off now hands the ped back completely — built, installed, awaiting play

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Installed `vcmods build 407` into `~/Games/VC/reVC.app`. No commit, tag or push
was made. Previous handoffs: `2026-11-12-npc-seat-objective.md`,
`2026-11-12-npc-strong-personality.md`.

## The report

While stuck in NPC mode, turning BECOME NPC off did not give control back. The
panel key and the switch itself work (the panel polls its own key in the render
loop); the failure was in what the toggle-off dropped.

## Root cause

The off-edge only restored the flags (CharCreatedBy, fear flags, borrowed stats)
and ended the wander pose. Everything the mode borrowed from the engine's state
machine stayed live:

- a seat/ATM objective with its `PED_SEEK_POS` (the spawn of the earlier sit
  report), or any reaction objective (flee, investigate, kill, chat);
- the AI ped state itself;
- wait states (sit, hands-up, stuck pose);
- the attractor registration, threat/event references, look and chat.

The base `CPed::ProcessControl` keeps servicing objectives and seeks, and
`CPlayerPed::ProcessControl` has no input path out of several of those states
(chats hold the speed at 0, `PED_WANDER_PATH`/`PED_SEEK_POS` drive speed from
the move state without reading the pad). The result is a toggle that flips the
switch but leaves the body driven or locked — "the game doesn't let me".

## The fix

`VCModNpcReleasePed` runs on the off-edge, after the stat restore:
- drops the wander flag first (the restores below call `SetWanderPath`, and the
  engine must not re-own him), resets the retry/hold timers;
- skips the body reset for death, a car, an arrest or an airborne/get-up state
  (the game owns those; only the flags restore);
- de-registers the seat attractor, clears threat/event references and flags;
- `ClearChat`, `ClearObjective`, `ClearWaitState`, `ClearLookFlag`,
  `ClearPointGunAt`, drops the path nodes, `ClearAll` (seek/flee/point state),
  `SetIdle`, speed 0, not running;
- clears the sit flags, and hands back the player's own STREET IDLE setting the
  command had forced off (saved on the engage edge).

Log line: `VCMOD npc mode: released`.

## Verification

- `test_vc_npcmode.py` 34 (two new): an off-toggle from `PED_SEEK_POS` with a
  live seat objective, SIT_IDLE wait state, attractor, threat and sit flags ends
  at `PED_IDLE`, no objective, no wait state, speed 0, nothing registered; and
  the STREET IDLE setting is saved on engage and handed back on release.
- Full suite 267/267. Release build green. Installed build 407. **Not yet
  confirmed in play.**

## Install note

The install ran while a game session was live (`pgrep -x reVC` was non-empty);
`scripts/install.sh` does not guard against that itself. The session kept
running with no crash report and the log flowing, but a running game streams
gamefiles from inside the bundle that was replaced. Always check `pgrep -x
reVC` immediately before installing; if it is non-empty, wait for the session to
end. The session that was running predates build 407, so a restart is needed to
play it.

## Next steps

1. Restart the game (the live session was on the older build), then in NPC mode:
   get stuck at a seat or mid-reaction, open the panel, turn BECOME NPC off →
   control returns immediately, he stands still, no walk continues on its own.
2. Toggle off during a chat and during a fight (strong body) → same result.
3. Confirm STREET IDLE returns to whatever it was before the mode was engaged.
4. Then strip the temporary diagnostics (`VCMOD wander:`, `civ layer`,
   `threat:`, `corpse:`, `react move:`, `talk:`, `voice:`, `id line:`,
   `npc body:`, `npc mode: released`) and commit the NPC topic.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Never install while `pgrep -x reVC`
returns anything. `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are uchg.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 407.
> Read `docs/handoff/2026-11-12-npc-toggle-reset.md` first. BECOME NPC's
> toggle-off now releases the ped completely: objective, seek, chat, wait state,
> attractor, threat references, sit flags and the path are dropped and STREET
> IDLE is handed back, so control returns where it used to stay stuck. Also
> installed this session: the seat objective fix and the body-personality/strong
> Tommy work. Play-test toggling off while stuck / chatting / fighting, then
> strip the temporary probes and commit. Never commit/push on the play-tester's
> behalf. Game data, settings, savegames and the uchg anim files are read-only;
> check `pgrep -x reVC` immediately before any install.
