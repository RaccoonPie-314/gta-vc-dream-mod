# Review, commit and publish the accumulated tree

Date: 2026-11-09
Repo/branch/HEAD: `reVC/`, `vcmods`, `57f4568` (parent `d01bb3c`)
Installed: `~/Games/VC/reVC.app` is `vcmods build 152`; the tree builds **153**.
This session did not install. No session was running, and the Dock launcher rebuilds
and installs 153 on its next start.

## What happened

The whole uncommitted tree — batches 1–4 of the Vice Extended picks, the two-hand
colt rework, no-strafe, street idle's kerbside look and the tabbed panel — was
reviewed, built, tested and committed as one change set, then synced and published.

## Review findings, and what was done

| Finding | Action |
|---|---|
| Four harnesses asserted the old flat panel: `VCModListAnchorRow`, fixed row indices, a two-cell row, ordering inside one table | Rewritten for pages, the title-bar master, the three-cell row and the click-time list anchor |
| `README.md` still described the single-page panel and claimed settings are never written back | Panel, config precedence and toggles table updated; the write-back caveat for an absent key is spelled out |
| `README.md` called the two-hand colt "Paused: … the arm still tracks the old target" | Replaced with what it does now |
| `CHANGELOG.md` had shipped nothing since 2026-11-07 | New `Shipped — 2026-11-09` section, marking each item Seen / Harness / Built, and the Not verified list extended |

No product-code defect was found that changed behaviour. The build is clean at
`-Wall`/`-Wextra` for every touched file, and all nineteen harnesses pass.

## Verification

```
scripts/build.sh                               # green, no warnings in the mod files
cd reVC && for t in utils/test_vc_*.py; do python3 "$t"; done    # 19/19
```

Installed copy untouched; no session was started.

## Published

`scripts/sync.sh` regenerated `vc-mods.patch` from `miami..vcmods`, and
`scripts/publish.sh` refreshed the public folder. `gta-vc-dream-mod` carries the new
patch, README, CHANGELOG, `docs/` and the two script changes (`install.sh` restores
the production bundle id after the rsync; `make-launcher.sh` logs the build line).

## Next

1. Launch from the Dock and check the panel at the new build: tabs, the PERMAnent
   pin cell, and a pin surviving a restart. None of that has been seen in play.
2. Play the unplayed items listed under Not verified in `CHANGELOG.md` — drive cam,
   pack cars, explosion cover, FBI bars, firetruck cannon, no-strafe, kerbside look.
3. `COLT TWO-HAND` is off by default on purpose. When testing it, the lowered hold
   fades out while walking; that is the intended split, not a missing clip.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` — game data
  and saves; `anim/cuts.img`, `cuts.dir` and `ped.ifp` are `uchg`-locked.
- `reVC/utils/test_vc_*.py` extract production code by marker. Renaming a panel
  helper or changing a row's shape breaks a harness first — update the harness in the
  same change.
