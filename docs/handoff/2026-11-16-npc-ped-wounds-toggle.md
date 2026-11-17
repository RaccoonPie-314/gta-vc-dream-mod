# Handoff: PED WOUNDS switch for BECOME NPC

Date: 2026-11-16
Repo: `vc-mod/reVC`, branch `vcmods`, HEAD `bfc0d4d0` (nothing committed this
session)
Built and installed: `vcmods build 615` in `~/Games/VC/reVC.app`
Harness: all 52 `utils/test_vc_*.py` green

## The report

BECOME NPC's receiving side uses the worn body's damage multiplier, which is
almost 1:1: a Colt45 round is 250 against 100 HP, so any hit kills, and a lethal
shot takes limbs off. The request was not to remove that, but to put it behind
a switch.

## What changed

`PED WOUNDS` (`bVCModNpcPedWounds`, ini `NpcPedWounds`, default **on**) on the
WORLD page, right after CALL GANG. It is a modifier of BECOME NPC, so it only
acts while the mode runs. On is the shipped behaviour; off keeps the player's
own taking-damage rules while the AI still walks and fights him.

The switch gates the six receiving-side flips of stock-combat slice C in
`CPed::InflictDamage`:

- damage taken: `damage × 0.33` (player) instead of `× m_defendWeakness`
  (worn body);
- the knife/cleaver/chainsaw bleed counter;
- gunshot limb removal (`dontRemoveLimb` back on, so no limb comes off);
- explosion dismemberment (`CGame::nastyGame` branch);
- the player's GANG7 damage immunity and the `m_bFireproof` exemption come back.

On, nothing differs from build 614. Off, a Colt45 round is 82.5 rather than
250 and no limb is removed; hit reactions, the ped hit-step, fight animations
and the outgoing combat side are untouched. `VCModNpcPedWoundsActive()` is the
one predicate (`bVCModNpcMode && bVCModNpcPedWounds`), called from the engine
only.

## Files

- `src/extras/vcmodnpc.{h,cpp}` — flag, default, predicate.
- `src/peds/PedFight.cpp` — six predicate calls, one per line.
- `src/extras/vcmodpanelregistry.cpp` — WORLD row and debug-menu entry.
- `src/core/re3.cpp` — `NpcPedWounds` ini reader.
- `utils/test_vc_npccombat.py` — SliceCWiring repinned and a new
  `test_ped_wounds_switch_restores_the_player_rules`.
- `utils/test_vc_adrenaline.py`, `utils/test_vc_character.py` — panel stubs
  define the new flag.
- `utils/test_vc_passenger.py` — row count 80 → 81.

`src/text/Text.cpp` was already modified in the tree before this session
(missing-key debug line); it is untouched here and still uncommitted.

## Play steps

1. Launch through the Dock app, confirm `vcmods build 615`.
2. Turn BECOME NPC on with PED WOUNDS on (default): a pistol round should kill
   and may take a limb off, as before.
3. Turn PED WOUNDS off: pistol rounds take about a third of health, limbs stay
   on, and gang/fire protection is back. Turn BECOME NPC off: the player is
   stock again either way.
4. Pin the PED WOUNDS row, restart, and confirm the choice was remembered.

## Files not to touch

- `~/Games/VC/`, `~/Games/VC-ai/`, `~/Library/Application Support/reVC/` are
  read-only.
- `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` are `uchg`.
- Install only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty.
- Do not commit, tag or push without an explicit ask.

## Paste-ready prompt

> Continue vc-mod, reVC checkout `reVC/`, branch `vcmods`, HEAD `bfc0d4d0`,
> installed `vcmods build 615` in `~/Games/VC/reVC.app`. Read
> `docs/handoff/2026-11-16-npc-ped-wounds-toggle.md` first, then
> `docs/specs/2026-11-15-npc-stock-combat-design.md` and `AGENTS.md`.
>
> BECOME NPC now has a PED WOUNDS switch (WORLD page, default on): on keeps the
> worn body's 1:1 damage, bleed, limb removal and explosion dismemberment; off
> restores the player's 0.33 multiplier, keeps limbs on and restores the GANG7
> and fireproof protections. The uncommitted tree also has the earlier
> `src/text/Text.cpp` missing-key debug line, not part of this change.
>
> Next: play the two states (pistol hit with PED WOUNDS on and off; a shotgun
> death; a car explosion; a gang attacker), check the pin survives a restart,
> then commit and push with `scripts/backup.sh` only when asked. Run all
> `utils/test_vc_*.py` and `scripts/build.sh`; install only with
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. Game data and the `uchg`
> anim files stay untouched.
