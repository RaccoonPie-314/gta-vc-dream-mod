# Handoff: CALL GANG — stock gang group spawn and chatter (design only)

Date: 2026-11-14
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `ff1f984` (tree clean)
Installed: `vcmods build 537` in `~/Games/VC/reVC.app`; no session running
Docs: this handoff, the spec `docs/specs/2026-11-14-gang-group-design.md`
Code: nothing written, built or installed this session

## Session result

The feature was designed and approved in chat; the spec is written and awaiting
review. No engine or extras file was touched.

The feature: while BECOME NPC runs the GANG profile, a `CALL GANG` row on the
WORLD page spawns one stock-shaped group of the player's own gang that he is
part of — the stock walking formation (he leads) or the stock chatting circle
(he takes a ring slot). Walking up to an existing kin circle can pull him into
its conversation. Nothing spawns on engage; world groups keep stock behaviour.

Decisions settled with the play-tester:

- One row, one press = one group; no auto-spawn, no hotkey, no dismiss.
- Player leads the formation; in the circle he occupies one ring slot without
  being moved.
- Stock 1/3 formation / 2/3 circle split and 3–6 size roll.
- Player's circle pair uses the stock meet length (10–14 s); NPC pairs keep
  the cluster's 100 s.
- One active group at a time; a press while one lives is refused with a notice.
- Existing kin circles are joinable by walking up (stock radius, roll and
  cooldown); rival circles stay hostile-only.
- World groups, rival reactions and stock chatter stay as they are.

## Why the shape

The stock population already spawns exactly these two group shapes and already
runs the circle chatter (`CPopulation::PlaceGangMembers*`, the `SetChat(...,
100000)` pairing, the stock `CPed::Chat` cycle). The profile is solo today, and
stock groups spawn 40–50 m away out of view, so the scene the button makes is
the stock scene with the player written into the group instead of a new one.
The kin chat path already exists for walkers (`WillChat` effective type); the
missing half is the circle join.

## Spec pointers (verified in the tree)

- `vcmodgang.cpp:22` effective gang; `vcmodnpc.cpp:166`, `:188`, `:362`, `:393`,
  `:665-680`, `:715-727`, `:443` profile, borrow, gang branch, release.
- `Ped.cpp:1397-1419` stock chat roll; `:1421-1449` `WillChat`; `:7856`
  `SetChat`; `:7872-7936` `Chat` cycle and timers; `:7938` `ClearChat`;
  `:2419-2433` clump fade-in; `:377`, `:413` ped counts.
- `Population.cpp:420-483` `AddPed` and gang weapons; `:1363` size; `:1429-1436`
  shape roll; `:1439-1507` formation; `:1510-1623` circle, pairing and middle;
  `:1080-1160` cull.
- `Gangs.cpp:23-40`, `:74` gang models; `AudioLogic.cpp:5448-5449`, `:7795`
  gang voices; `Weapon.cpp:529`, `:1405` friendly fire; `PedAI.cpp:2203`,
  `:5478-5481`, `:6999-7002` rally, GANG7 guard, damage mask.
- Panel: `vcmodpanelinternal.h`, `vcmodpanelregistry.cpp` (WORLD rows after
  `TYPE FROM BODY`), `vcmodpanel.cpp` (dispatch beside `CALL CREW`);
  streaming pattern in `vcmodcrew.cpp:352-366`.

## Next steps

1. Review the spec. On approval, write the implementation plan under
   `docs/plans/2026-11-14-gang-group.md` (panel row and gate; spawner and
   tracking; lifecycle unlink; kin-circle join; harness; README), or implement
   directly from the spec if the tasks are small enough.
2. Build in `reVC/`, run the full `utils/test_vc_*.py` suite, install only with
   `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
3. In-game pass: Cuban body in Little Havana for the circle, the formation and
   the walk-up join; a rival body for hostile-only; a Tommy body for silent
   turns; repeated presses; mode off mid-group. World groups stay stock.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only; free disk space from build output, never game data.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Git on reVC: no commit, tag or push unless asked.
- Install only with no session running.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `ff1f984`,
> tree clean, `vcmods build 537` installed in `~/Games/VC/reVC.app`. Read
> `docs/handoff/2026-11-14-gang-group.md` and
> `docs/specs/2026-11-14-gang-group-design.md`. The approved feature: a
> `CALL GANG` WORLD row that spawns one stock-shaped group of the player's
> gang (walking formation led by the player, or chatting circle with him in a
> ring slot), plus a walk-up join for existing kin circles. Nothing is built.
> Write the implementation plan and execute it: panel row and gate, spawner
> and active-group tracking, lifecycle unlink, kin-circle join, harness. Build,
> run all `utils/test_vc_*.py`, install only with the game stopped, then hand
> off for the in-game matrix. No git actions; game data and the `uchg` anim
> files stay untouched.
