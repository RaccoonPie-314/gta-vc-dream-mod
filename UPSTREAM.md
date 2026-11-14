# Where this came from

Built against [https://github.com/mrxenginner/reVC](https://github.com/mrxenginner/reVC), branch `miami`, commit `a26fff4`.
Mod commits on top of it:

    3f62c78 Ship the drive camera's stock deadzone hold
    ff1f984 Ship body-type banking for BECOME NPC
    c0477aa Ship NPC combat parity, the wander fixes and the module slices
    1641b0f Ship free-camera lock-on and the RIDE TO map-marker destination
    4fc7fcd Ship the NPC-mode module split and the standstill fix
    bb3fe88 Ship NPC mode, the Vercetti crew, panel help and diagnostics
    8d57f7c Ship lit car lamp textures, the vehicle spawner and fitted sirens - LIGHT TEXTURES: a replaced model's lamp material swaps to its lit texture   while that car's lights are on, back to the unlit face when they are off;   DRIVING row, default on - Car light cubes fade from 15 m to 8 m, so no translucent box hugs a parked car - FBI Car, FBI Rancher and Vice Cheetah run the stock four-corona siren seated   per model; the police bar narrows to its roof blocks - Tail lamps stay red in reverse; the white reversing marker is gone - SPAWN VEHICLE on DEBUG lists every car model and queues a spawn ahead - Rebindable mod keys with a KEYS page; direct key reads skip while capturing - Firetruck cannon fires from the muzzle and the barrel turns with the aim - Harnesses: test_vc_lighttex, test_vc_carlights, test_vc_spawn, test_vc_keys
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
    Date:     2026-11-14T12:59:10Z
    Target:   https://github.com/mrxenginner/reVC
    Hash:     bd7a28ac9bbafa6cc8accdeaaa2ad0766f24bbd0a2f458f3e01df0c63c0a080b

## Rebuilding

```
scripts/bootstrap.sh [dest]   # clone upstream, detach to a26fff4, apply vc-mods.patch
scripts/build.sh              # cmake, Release
scripts/install.sh            # drop the bundle into the game folder, re-sign
```

Game data is not here and can't be: it's Rockstar's. Bring your own licensed copy.
