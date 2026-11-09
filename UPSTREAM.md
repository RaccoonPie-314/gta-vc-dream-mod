# Where this came from

Built against [https://github.com/mrxenginner/reVC](https://github.com/mrxenginner/reVC), branch `miami`, commit `a26fff4`.
Mod commits on top of it:

    d6070c5 Add gun recovery tails and free movement while locked on
    57f4568 Ship the vanilla fixes, world fixes, tabbed panel and two-hand stance
    d01bb3c Add traffic AI, path probe and interior mods
    d812138 Mount asset mods from a portable mods folder
    287138f Name the crime and its dispatch line per tier
    d61bfd3 Give the player's ride its own seat rule for later backup cars
    133e2cc Ride the vice tier as a pair regardless of the car's seat data
    3f589c6 Scale the squad response to the crew size and the tier
    23596aa Ride the squad in the tier transport instead of following on foot
    bbda9b9 Stop the squad's cop AI from arresting the player during the mission
    ac52179 Lay the chase route out by distance so the leader never starts at the station
    92a5fab Walk chase lanes forward only and unlock the mission cars
    62b324c Keep the chase route off boat lanes so the leader does not drown at spawn
    3aa21eb Track the chase leader by handle so the engine's death cleanup cannot double free
    ea842db Clean up mission objects without freeing live references
    f1cd5ce Add the marina boat escape and the U capture key
    35ef2a8 Log the player's position with K for authoring the marina
    996d392 Add never-wanted, friendly fire, and the ground squad
    18175ce Add the leader's car swap and the accomplice pickup
    bf21966 Give the leader a 200 m head start with a 10 second delay
    207f1f3 Drive the leader along a two-stop route with the pressure rule
    bfa3895 Spawn the chase leader with a blip and a leash fail
    69cdda4 Cycle the eight VICE uniforms with repeated 3 presses
    adf04c0 Teleport to the station forecourt with J
    8ce2799 Add COP and VICE tiers and pin the chase station to VCPD HQ
    558259c Add chase cleanup and marker return
    dd4e421 Add chase tier selection and uniform swap
    a14aad0 Add chase station marker and blip
    e83756e Add chase mission state machine skeleton
    ca60b70 Add street idle, chauffeur, ride style and passenger fixes
    6d5f67d Add adrenaline, character selection and passenger riding mods
    bd9cbc5 Add player-animation, aiming and control-surface mods

reVC is MIT with a proof-of-usage condition (see LICENSE.md). That condition
also covers systems that read this repository, so the use is recorded in
upstream's PROOF_OF_USAGE.md.

Usage record for the build of this folder:

    System:   macOS arm64
    Operator: RaccoonPie-314
    Date:     2026-11-09T04:20:53Z
    Target:   https://github.com/mrxenginner/reVC
    Hash:     28fee285234081856d34ecfd217557bfa68661c6b62f749d60e0cbb657fc42f7

## Rebuilding

```
scripts/bootstrap.sh [dest]   # clone upstream, detach to a26fff4, apply vc-mods.patch
scripts/build.sh              # cmake, Release
scripts/install.sh            # drop the bundle into the game folder, re-sign
```

Game data is not here and can't be: it's Rockstar's. Bring your own licensed copy.
