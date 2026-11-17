# Handoff: off-machine backup for the mod

Date: 2026-11-16
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d`
Backup: `RaccoonPie-314/reVC-mod` (private), branches `vcmods`, `assets`, `workspace`
Installed: unchanged, `vcmods build 609` in `~/Games/VC/reVC.app`

## Why this exists

`reVC` was cloned read-only from upstream: `mrxenginner/reVC` grants this account
`pull: true, push: false`, and no fork of it exists. So the 43 commits on `vcmods`
had never left this disk — the only off-machine copy of the mod was
`vc-mods.patch`, and that patch stopped at `46e9f0f`.

What the patch did not carry:

- Autodrive and the speed limit (`src/extras/vcmodautodrive.*`, which owns both)
- The per-feature key slots: 12 slots committed against 26 in the working tree,
  plus `VCModKeyJustDown` and its call sites in `PlayerPed.cpp`
- The key wrappers for WHEEL FALLS OFF, CREW AGGRESSIVE, NEVER WANTED and NPC
  DOOM AIM (the rows themselves are in the patch, the hotkeys were not)
- `~/Games/VC/mods/` — 17 MB of the mod's own assets, in no repo at all
- `scripts/windows/Play.bat`, `AGENTS.md`, and the Nov 15–16 handoffs

## What was pushed

`RaccoonPie-314/reVC-mod`, private, three branches:

| Branch | Content | Head |
|---|---|---|
| `vcmods` | reVC at the pin plus all `vcmods` work, incl. autodrive | `bfc0d4d` |
| `assets` | `mods/` and `mods.ini` copied from the game folder (9 files) | `f2b1b35` |
| `workspace` | `AGENTS.md`, `README.md`, `CHANGELOG.md`, `docs/`, `scripts/` | `3a51ee0` |

Autodrive is committed untested: the commit says "Add", not "Ship", and the
patch stays at `46e9f0f` until it has been played.

Pushing from the shallow clone failed with `remote: fatal: did not receive
expected object`; `git fetch --unshallow origin` fixed it (5201 commits, 80 MB
`.git`) and the push then carried the whole history.

## The rule from here

Commit on `vcmods` as before, then push:

```
git -C reVC push backup vcmods
```

`backup` is the remote name. `origin` remains upstream and stays untouched. Re-derive
the patch and refresh the published repo with `scripts/sync.sh` once the new work
has been played, not before.

## Still not backed up

- A built binary: the installed `reVC.app` (20 MB) would make a restore a copy
  instead of a build. It embeds 13 MB of Rockstar files, so it can only go to the
  private repo's releases, never the public one.
- Saves and config in `~/Library/Application Support/reVC`.
- The warmed `vendor/librw` submodule is a pointer; a restore re-clones it.
