# Commit and publish the follow, health and army work (2026-11-18)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `6157e4c5`.
Installed build: `vcmods build 695` in `~/Games/VC/reVC.app`, binary dated
Nov 18 05:23 — newer than every edited source, so the play test that confirmed
"everything works" ran this tree. 59 `utils/test_vc_*.py` suites green.

## What was committed

`6157e4c5 Ship follow anims and follow safety, the health key and the army side`
is one commit on top of `de225b9c`:

- `src/extras/vcmodfollow.{cpp,h}` — FOLLOW ANIMS and FOLLOW SAFE (WORLD page,
  both on), the hooks in `Ped.cpp`, `PedFight.cpp` and `Fire.cpp`, the ini reads
  in `re3.cpp`, the rows in `vcmodpanelregistry.cpp`.
- `src/extras/vcmodhealth.{cpp,h}` — the HEALTH+ARMOR key (`VCKEY_HEALTH`), its
  ini/pad names in `vcmodkeys.*`, the tick in `PlayerPed.cpp`, the KEY row.
- The army body's side in `vcmodgang.cpp`, and the same-side refusals in
  `Ped.cpp` (`ScanForThreats`) and `PedAI.cpp` (`ReactToPointGun`).
- The old mission-friend damage gate removed from `CPed::InflictDamage`; FOLLOW
  SAFE carries the player-to-follower half.
- Diagnostics probes (DIAGNOSTICS only): script-created ped, population cop,
  `SET_CHAR_AS_FRIEND` write, script block start, and a non-player hit's gates.
- Harnesses: `test_vc_follow.py`, `test_vc_health.py` new; crew, gangfaction,
  keys, passenger, adrenaline and character updated.

The previous session's follow work is now committed together with the
then-in-flight health/diagnostics work; `docs/handoff/2026-11-17-follow-anims.md`
remains the design record.

## Off-machine copy

The private repo `RaccoonPie-314/reVC-mod` is gone from GitHub, so its `backup`
remote was removed from `reVC` and `scripts/backup.sh` was deleted. The public
repo `RaccoonPie-314/gta-vc-dream-mod` (`gta-vc-dream-mod/`, branch `main`) is
the off-machine copy: README, CHANGELOG, docs, scripts and `vc-mods.patch`
(228 files, from `git diff miami..vcmods`). It was republished from `6157e4c5`
with `VC_MODS_OPERATOR=RaccoonPie-314 scripts/publish.sh gta-vc-dream-mod` and
pushed. `AGENTS.md` describes the new flow.

Gap: `~/Games/VC/mods/` (the mod's own assets, 17 MB) has no off-machine copy
now that the private repo is gone. Nothing in the public repo carries it, by
design.

## Next steps

1. Nothing pending in the tree. The next change starts from clean `vcmods`.
2. If the assets matter off-machine, copy `~/Games/VC/mods/` (read-only source)
   somewhere private; do not add it to the public repo.
3. After the next played commit: `scripts/sync.sh`, then
   `VC_MODS_OPERATOR=RaccoonPie-314 scripts/publish.sh gta-vc-dream-mod`, commit
   and push from inside that folder.

## Do not touch

Game data (`~/Games/VC`, `~/Games/VC-ai`, the reVC settings), the `uchg` anim
files, and the published patch's digest fields (`System` names the build host,
never a vendor or a model).
