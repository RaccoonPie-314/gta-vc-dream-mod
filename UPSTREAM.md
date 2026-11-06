# Where this came from

Built against [https://github.com/mrxenginner/reVC](https://github.com/mrxenginner/reVC), branch `miami`, commit `a26fff4`.
Mod commits on top of it:

    6d5f67d Add adrenaline, character selection and passenger riding mods
    bd9cbc5 Add player-animation, aiming and control-surface mods

reVC is MIT with a proof-of-usage condition (see LICENSE.md). That condition
also covers systems that read this repository, so the use is recorded in
upstream's PROOF_OF_USAGE.md.

Usage record for the build of this folder:

    System:   macOS arm64
    Operator: RaccoonPie-314
    Date:     2026-11-06T21:05:29Z
    Target:   https://github.com/mrxenginner/reVC
    Hash:     3c882ff518accf1efeaafcd1f7b5bcceae3c8f14da64ef35a405e5de43b8e9a8

## Rebuilding

```
scripts/bootstrap.sh [dest]   # clone upstream, detach to a26fff4, apply vc-mods.patch
scripts/build.sh              # cmake, Release
scripts/install.sh            # drop the bundle into the game folder, re-sign
```

Game data is not here and can't be: it's Rockstar's. Bring your own licensed copy.
