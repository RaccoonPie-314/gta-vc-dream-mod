# Where this came from

Built against [https://github.com/mrxenginner/reVC](https://github.com/mrxenginner/reVC), branch `miami`, commit `a26fff4`.
One mod commit on top: `bd9cbc5 Add player-animation, aiming and control-surface mods`.

reVC is MIT with a proof-of-usage condition (see LICENSE.md). That condition
also covers systems that read this repository, so the use is recorded in
upstream's PROOF_OF_USAGE.md.

Usage record for the build of this folder:

    System:   macOS arm64
    Operator: RaccoonPie-314
    Date:     2026-11-06T11:00:27Z
    Target:   https://github.com/mrxenginner/reVC
    Hash:     6e838f2a3aaef2ac723adf84ebbf54053471ed37b9cd301115f050743e451cde

## Rebuilding

```
scripts/bootstrap.sh [dest]   # clone upstream, detach to a26fff4, apply vc-mods.patch
scripts/build.sh              # cmake, Release
scripts/install.sh            # drop the bundle into the game folder, re-sign
```

Game data is not here and can't be: it's Rockstar's. Bring your own licensed copy.
