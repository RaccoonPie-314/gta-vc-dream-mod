# Handoff — per-lamp light cast, tried and dropped (2026-11-09)

## Where things are

- Workspace `vc-mod`, code in `reVC/`, branch `vcmods`.
- HEAD `8d57f7c`. The working tree is **clean** — the per-lamp cast was reverted and
  `src/vehicles/Automobile.cpp` matches the commit exactly.
- Installed `~/Games/VC/reVC.app` was **`vcmods build 196`** when the attempt was abandoned;
  the tree now casts the stock quad again, so rebuild and install before the next play test.
- Tests `python3 utils/test_vc_*.py` from `reVC/` (twenty-five, all passing).

## What was tried

`ChangesEN:128` ("the texture of the light cast on the surface from the headlights and taillights
is separated") is about cast **geometry**, not art: the pack's `IMPROVED_VEHICLES` block in
gta-extended's `Automobile.cpp` splits the head pair and the tail pair into one ground pool per
lamp. Ported as-is, then with the offsets re-anchored to each lamp (the pack's `tailLightPos.y + 2`
counts the lamp dummy's own y twice, which walks a long car's pools a metre behind the bumper).

## Why it was dropped

Two play reports, then the call:

1. The pools sat off the bumper — the offset fault above.
2. With the offsets fixed they still read as **choppy** against the terrain, because each small
   additive quad is cut up by the ground collision triangles it is cast across. Stock's single
   wide quad hides that in its size and softness.

The owner asked for stock lighting back, so the split is out entirely: the per-lamp calls, the
extra shadow ids, the harness and the change-log entry are gone. **Do not re-propose it.** If the
pack's look is ever wanted again, the terrain chopping is the thing to solve first, not the
offsets.

## What still stands from the session

- `8d57f7c` is untouched: lamp textures, the car-light cube fade, the model-seated FBI/Cheetah
  sirens, the narrowed police bar, the red tail in reverse, the vehicle spawner, rebindable keys,
  the inverted drive-camera axis and the firetruck cannon aim.
- The standing verification queue is unchanged: rotor blades, rockets, explosion cover, pack
  wheels, lamp textures, red tail in reverse.

## Traps still worth keeping

- A stored shadow's `z` is not where it is drawn: `CastShadowSectorList` uses `pPosn->z` only to
  pick the surfaces within `fZDistance` below it. A visible sideways shift is real world XY.
- `CShadows::StoreCarLightShadow` takes `(frontX, frontY, sideX, sideY, r, g, b, maxViewAngle)`;
  each corner of the quad is the position plus and minus both vectors, so a `1.0` step is a 2 m
  square.
- Light cast on terrain is chopped by the collision triangles. Anything smaller than the stock
  quads makes that obvious.
- `scripts/build.sh` pipes through `grep`; check the binary exists before installing, and never
  install while `pgrep -x reVC` is non-empty.

## Next, in order

1. Rebuild and install so the installed app matches the reverted tree.
2. The owner verifies the standing queue one item at a time.
3. Then pick the next feature: newspapers, first person or autosave.

## Rules

- Stage explicit paths, never `-A`; never push the reVC repo; never commit for the user.
- Game data under `~/Games/VC`, `~/Games/VC-ai` and `~/Library/Application Support/reVC` is
  read-only. Pack assets live only under `~/Games/VC/mods/`, never in git or a public package.
- The user tests in game; do not call an unplayed change fixed.
