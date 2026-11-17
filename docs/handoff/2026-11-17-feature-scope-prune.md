# Feature scope pruned, one abandoned plan deleted, verification debts written down (2026-11-17)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`, 61 files
uncommitted (all predating this session). Installed build 646. This session changed
documentation only: no code, no build, no install, no commit, no push.

## What this session did

A survey of the NPC and QOL surface against the panel registry, the plans, the
specs, the handoffs and the CHANGELOG. The owner then pruned the candidate list.

**Declined, recorded in `CHANGELOG.md` under `## Declined — 2026-11-17`:**

- Ped spawner and NPC inspector on the DEBUG page.
- BECOME NPC in a vehicle (ped driving, ride-along, passenger seats in the mode).
- COP profile arrest and pursuit driving: the profile is player behaviour, so it
  stays a foot patrol.
- The ped driving brain (route queue, lane discipline, stuck recovery, pursuit).
- Prostitute-in-car block and a gang weapons loadout.
- Time of day, weather and traffic-density controls.
- Weapon-set / loadout switching.
- On-foot first person; the cockpit view is the only first-person camera.
- Chase leftovers: the boat finale, on-foot continuation after a wreck, the gunner
  seat. The run stays as it is.

**Kept as ideas, in `CHANGELOG.md` under `## Ideas not started`:**

- `CALL GANG` dismiss/cleanup.
- `MISSION TARGET` following its target into a car.
- Newspapers after missions (blocked on an asset override path).
- Panel housekeeping: per-tab ALL ON, reset-every-feature-state, KEYS-page search.

## The deleted plan

`docs/plans/2026-11-07-ped-ai-overhaul.md` was the ped driving brain plan
(`Status: planning, no code yet`). Checked before deleting: no `vcmodai.*` source,
no harness, no ini key, no premake or CMake entry, no trace in `vc-mods.patch`, no
commit in any reVC branch, no stash. It was paper only, so deleting it cannot
affect a feature. Deleted from `docs/plans/` and from the `gta-vc-dream-mod`
handout as well. The handout deletion is **uncommitted**; the next handout commit
and push removes the file from `HEAD`. Old commits still contain it, which the
owner accepted — no history rewrite.

## The verification list

`docs/verification.md` (new): 29 unchecked lines in five groups — BECOME NPC and
NPC behaviour, driving and vehicles, panel and input, combat and player, world.
Each line says what to confirm in play and names the handoff that carries the play
steps. It is now the one live list: `CHANGELOG.md`'s `## Not verified` section is a
pointer to it, and `docs/plans/2026-11-08-vice-extended-picks.md`'s status line was
corrected (autosave shipped, first person declined, newspapers the only live pick).

## Files touched

- `CHANGELOG.md` — the Declined section, the Not verified pointer, four kept ideas,
  and the stale weapon-set bullet removed.
- `docs/verification.md` — new.
- `docs/plans/2026-11-08-vice-extended-picks.md` — status line.
- `docs/plans/2026-11-07-ped-ai-overhaul.md` — deleted.
- `gta-vc-dream-mod/docs/plans/2026-11-07-ped-ai-overhaul.md` — deleted, pending commit.

## Next

1. Commit the docs when asked (`vc-mod` is not a repo; the handout is). The handout
   shows one pending deletion.
2. Pick up one of the four kept ideas, or play a line off `docs/verification.md`
   and delete it once confirmed.
3. Keep new unverified work going into `docs/verification.md`, not into a second
   "not verified" list.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are `uchg`. Install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. No commit, tag or push unless
asked.

## Paste-ready prompt

> Continue `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`, build
> 646 installed; all 61 uncommitted files predate this. Read
> `docs/handoff/2026-11-17-feature-scope-prune.md` first, then `AGENTS.md` and
> `docs/architecture.md`. The NPC/QOL candidate list was pruned: the declined set
> and the four kept ideas are in `CHANGELOG.md`, the ped driving brain plan is
> deleted, and `docs/verification.md` is the single play-check list. Nothing is
> half-written. Next: either build one of the four kept ideas (`CALL GANG` dismiss,
> `MISSION TARGET` into a car, panel housekeeping, newspapers) or play a
> verification line. Commit and push only when asked.
