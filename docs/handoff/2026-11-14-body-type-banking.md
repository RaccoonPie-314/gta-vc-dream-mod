# Handoff: body-type banking (TYPE FROM BODY)

Date: 2026-11-14
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `c0477aa`
Installed: build 534 in `~/Games/VC/reVC.app` (no session was running at install)
Commits: none. Everything below is uncommitted by design.

## What changed

BECOME NPC now has a `TYPE FROM BODY` switch (`NpcAutoType`, default on) on the
WORLD page. While it is on, the worn model's stock ped type picks the profile
and, for gang bodies, the gang number:

- `MI_PLAYER` and `GANG1..GANG9` bodies → GANG as the body's own gang
  (`MI_PLAYER` stays GANG7)
- `COP` bodies (`cop`, `swat`, `fbi`, `army`) → COP
- everything else (`CIVMALE`, `CIVFEMALE`, `CRIMINAL`, `PROSTITUTE`,
  `EMERGENCY`, `FIREMAN`, `SPECIAL`) → CIVILIAN with the body's stock stat

With the switch off the mode is exactly build 533: the manual NPC TYPE on any
skin, and GANG means GANG7 (stat, threats and kin mask included). Cycling NPC
TYPE while auto is on turns auto off and applies the chosen profile; the row's
label follows the body while the mode runs.

The identity borrow moved into one helper, `VCModNpcBorrowIdentity`. It reads
`VCModNpcGangType` for the fear flags and kin mask and borrows GANG7 for
`MI_PLAYER` or the body's stock stat for other gang bodies. `VCModGangEffectiveType`
now returns the derived gang, so rivals hunt a Cuban NPC-Tommy and Cubans spare
him.

## Files touched (reVC, uncommitted)

- `src/extras/vcmodnpc.h`, `src/extras/vcmodnpc.cpp` — flag, helpers, predicates,
  borrow, dispatch, engage log
- `src/extras/vcmodgang.cpp` — effective gang type for the player
- `src/extras/vcmodpanelregistry.cpp` — row, NPC TYPE getter/setter, debug tweak
- `src/core/re3.cpp` — `NpcAutoType` ini read
- `utils/test_vc_npcmode.py`, `test_vc_gangfaction.py`, `test_vc_panel_info.py`,
  `test_vc_npcstrong.py`, `test_vc_ganggaze.py`, `test_vc_character.py`,
  `test_vc_adrenaline.py`, `test_vc_passenger.py` — stubs, tests, row count
- `README.md` — toggles row

Docs outside reVC: this handoff, the plan
(`docs/plans/2026-11-14-body-type-banking.md`), the spec
(`docs/specs/2026-11-14-body-type-banking-design.md`).

## Verification done

- All 45 `utils/test_vc_*.py` suites pass.
- `scripts/build.sh` clean; build counter 534; installed and re-signed.
- No play test yet. The in-game matrix below is the open item.

## Play matrix

Auto on (TYPE FROM BODY row ON):

- Tommy: GANG7 as before. Vercetti spare/chat, rivals hunt, cops chase.
- A Cuban body: GANG1. Cubans spare/chat, rival gangs hunt, cops chase.
- A military body (army/swat/fbi/cop): COP foot patrol, no gang identity.
- A civilian body: CIVILIAN with that body's personality; a medic body is
  CIVILIAN with the medic stat.

Auto off:

- A military body with NPC TYPE GANG: build 533 GANG7 behaviour.
- Any body with NPC TYPE COP or CIVILIAN: unchanged from build 533.

Panel:

- Cycling NPC TYPE while auto is on turns TYPE FROM BODY off and applies the
  chosen profile.
- The NPC TYPE label follows the body while auto is on and NPC mode runs.

Lifecycle: toggle the mode off, die, enter a car, get arrested, change the body
mid-mode. Stats, fear flags and gang flags restore with no residue; the next
engage re-derives. Voice still follows the body.

## Next steps

1. Play the matrix above; note any body where the profile, gang or stat is
   wrong (the body model and the expected gang are enough to trace it).
2. If a gang body's kin behaves wrong in chat or damage, check
   `VCModGangEffectiveType`'s callers and the borrowed `m_gangFlags` mask
   (GANG1 clears bit 0, GANG7 bit 6).
3. Commit only when asked; then `scripts/sync.sh` regenerates `vc-mods.patch`.

## Do not touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Git on reVC is the play-tester's: no commit, tag or push unless asked.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
