# NPC mode session roundup (2026-11-12) — build 418 installed

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `8d57f7c`.
Installed `vcmods build 418` into `~/Games/VC/reVC.app` with no session running.
No commit, tag or push was made. This doc supersedes the round-by-round notes in
`2026-11-12-npc-seat-objective.md`, `2026-11-12-npc-strong-personality.md`,
`2026-11-12-npc-toggle-reset.md` and `2026-11-12-npc-melee-open.md` for the
"where are we now" question.

## What shipped this session

1. **Sitting at seat attractors.** The player seek case mirrors native
   `SetIdle()` for attractor objectives, the wander resume yields to a live
   objective, and the engine's own sit uses the sit machinery (seat lock,
   control skip, stock 25-30 s timer).
2. **Personality follows the worn model.** The civilian profile borrows the
   model's stock `CPedStats` while it drives him; Tommy's own body is a strong
   variant (fear 0, temper 100, no gun panic) that fights gunshots and
   attackers, investigates corpses and blasts, never flees, keeps the hands-up
   reaction. GANG/COP unchanged.
3. **Toggle-off releases the ped completely.** Objective, seek, chat, wait
   state, attractor, threat refs, path and sit flags are dropped, speed zeroed,
   STREET IDLE handed back. (Play-confirmed: "ok fixed now".)
4. **Melee route.** Fists go through the ped fight entry (`StartFightAttack`)
   and re-arm on the AI's 300-900 ms `SetAttackTimer` beat; a fight only starts
   with a live kill objective; a bump shove walks around instead of attacking;
   a stray attack/fight ends and hands back the pose. NPC mode skips the player
   weapon handler, so input cannot start attacks.
5. **Panel.** While open it blocks all player input (early return in
   `CPlayerPed::ProcessControl`), and one physical click toggles a row once.
   (Play-confirmed: "menu fixed".)

## Verified in play vs pending

Play-confirmed: the toggle reset, the panel input block and single-click
toggling, and the earlier flee/corpse stock behaviour.

Built but **not** re-checked in play after the last rounds: sitting,
body-personality reactions after the combat changes, and the melee chain
(build 418: shove loop gone, attack cadence, pose restore). Treat these as
wired-but-unconfirmed.

## If a hit still feels missing (stock facts, not bugs)

- A player victim takes `damage * 0.33f` in `CPed::InflictDamage`.
- `StartFightDefend` gives the player a flinch only while he is running.
- Bumping without a fight is cosmetic in stock; the 2 s strong-bump flinch
  (other ped cowers) is intentional and kept.

The `VCMOD fist:` probe prints `player|ped model N -> player|ped model N for D
(hp H)` on any hit where either side is the player, in NPC mode.

## Next steps

1. Play a short pass when convenient: sit at a chair, walk through a crowd,
   force one fist fight, toggle off. Expect: sit + stock timer, no shove loop,
   punches at a human pace, control back on toggle-off.
2. Strip the temporary diagnostics before the commit:
   `VCMOD wander:`, `civ layer`, `threat:`, `corpse:`, `react move:`,
   `talk:`, `voice:`, `id line:`, `npc body:`, `npc mode: released`,
   `fist:`, and the older `gang gaze`, `gang pose`, `gang react`, `gang obj`,
   `move:`. Keep the feature logs: `street idle: …`, `sit: …`, `spin kick: …`,
   `passengers: …`.
3. Commit the NPC topic (the tree also carries the earlier street-idle, crew,
   cop, traffic and light-texture work, all uncommitted).

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. Check `pgrep -x reVC` immediately before
any install (an install over a live session happened once this session; the
session survived). `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are uchg.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `8d57f7c`; installed build 418.
> Read `docs/handoff/2026-11-12-npc-mode-roundup.md` first. This session fixed
> seat sitting, body-personality/strong Tommy, the toggle-off reset, the melee
> route (ped fight entry, AI-paced re-arm, no bump-shove loop, pose restored)
> and the panel (input blocked while open, one click toggles once). Play a short
> pass (sit, crowd walk, one fist fight, toggle off), then strip the temporary
> `VCMOD` probes listed in the doc and commit the NPC topic; the tree also
> carries earlier uncommitted street-idle/crew/cop/traffic work. Never
> commit/push for me; game data and uchg anim files are read-only; check
> `pgrep -x reVC` before any install.
