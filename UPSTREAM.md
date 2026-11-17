# Where this came from

Built against [https://github.com/mrxenginner/reVC](https://github.com/mrxenginner/reVC), branch `miami`, commit `a26fff4`.
Mod commits on top of it:

    de225b9c Ship the NPC spawner, the BECOME NPC suspend table and panel housekeeping
    bfc0d4d0 Add autodrive, the speed limit and per-feature key slots
    46e9f0ff Ship NPC stock combat, the BECOME NPC walk, ped range and bigger pools
    aebb665e Ship CALL GANG, infinite ammo, saves and the army gang
    3f62c78d Ship the drive camera's stock deadzone hold
    ff1f9847 Ship body-type banking for BECOME NPC
    c0477aa5 Ship NPC combat parity, the wander fixes and the module slices
    1641b0fb Ship free-camera lock-on and the RIDE TO map-marker destination
    4fc7fcd9 Ship the NPC-mode module split and the standstill fix
    bb3fe88b Ship NPC mode, the Vercetti crew, panel help and diagnostics
    8d57f7c9 Ship lit car lamp textures, the vehicle spawner and fitted sirens - LIGHT TEXTURES: a replaced model's lamp material swaps to its lit texture   while that car's lights are on, back to the unlit face when they are off;   DRIVING row, default on - Car light cubes fade from 15 m to 8 m, so no translucent box hugs a parked car - FBI Car, FBI Rancher and Vice Cheetah run the stock four-corona siren seated   per model; the police bar narrows to its roof blocks - Tail lamps stay red in reverse; the white reversing marker is gone - SPAWN VEHICLE on DEBUG lists every car model and queues a spawn ahead - Rebindable mod keys with a KEYS page; direct key reads skip while capturing - Firetruck cannon fires from the muzzle and the barrel turns with the aim - Harnesses: test_vc_lighttex, test_vc_carlights, test_vc_spawn, test_vc_keys
    d6070c52 Add gun recovery tails and free movement while locked on
    57f4568f Ship the vanilla fixes, world fixes, tabbed panel and two-hand stance
    d01bb3c2 Add traffic AI, path probe and interior mods
    d812138b Mount asset mods from a portable mods folder
    287138f9 Name the crime and its dispatch line per tier
    d61bfd36 Give the player's ride its own seat rule for later backup cars
    133e2cca Ride the vice tier as a pair regardless of the car's seat data
    3f589c60 Scale the squad response to the crew size and the tier
    23596aa8 Ride the squad in the tier transport instead of following on foot
    bbda9b99 Stop the squad's cop AI from arresting the player during the mission
    ac521791 Lay the chase route out by distance so the leader never starts at the station
    92a5fab1 Walk chase lanes forward only and unlock the mission cars
    62b324c0 Keep the chase route off boat lanes so the leader does not drown at spawn
    3aa21eb5 Track the chase leader by handle so the engine's death cleanup cannot double free
    ea842db1 Clean up mission objects without freeing live references
    f1cd5ced Add the marina boat escape and the U capture key
    35ef2a8f Log the player's position with K for authoring the marina
    996d3923 Add never-wanted, friendly fire, and the ground squad
    18175ce2 Add the leader's car swap and the accomplice pickup
    bf219668 Give the leader a 200 m head start with a 10 second delay
    207f1f3f Drive the leader along a two-stop route with the pressure rule
    bfa3895b Spawn the chase leader with a blip and a leash fail
    69cdda45 Cycle the eight VICE uniforms with repeated 3 presses
    adf04c0c Teleport to the station forecourt with J
    8ce27997 Add COP and VICE tiers and pin the chase station to VCPD HQ
    558259cc Add chase cleanup and marker return
    dd4e4218 Add chase tier selection and uniform swap
    a14aad04 Add chase station marker and blip
    e83756e5 Add chase mission state machine skeleton
    ca60b70b Add street idle, chauffeur, ride style and passenger fixes
    6d5f67da Add adrenaline, character selection and passenger riding mods
    bd9cbc5e Add player-animation, aiming and control-surface mods

reVC is MIT with a proof-of-usage condition (see LICENSE.md). That condition
also covers systems that read this repository, so the use is recorded in
upstream's PROOF_OF_USAGE.md.

Usage record for the build of this folder:

    System:   macOS arm64
    Operator: RaccoonPie-314
    Date:     2026-11-17T09:51:49Z
    Target:   https://github.com/mrxenginner/reVC
    Hash:     a868920020aa18f7f6827a35f7ec07ba8179a1fe609d5cf959ae19dfb0d2691d

## Rebuilding

```
scripts/bootstrap.sh [dest]   # clone upstream, detach to a26fff4, apply vc-mods.patch
scripts/build.sh              # cmake, Release
scripts/install.sh            # drop the bundle into the game folder, re-sign
```

Game data is not here and can't be: it's Rockstar's. Bring your own licensed copy.
