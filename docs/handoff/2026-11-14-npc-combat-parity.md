# BECOME NPC: combat parity, the ID-check census and the pose questions (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `c0477aa`.
`vcmods build 530` is installed in `~/Games/VC/reVC.app`. All 45
`utils/test_vc_*.py` suites pass; the tree is clean and `vc-mods.patch` is
regenerated (167 files). No tag and no push were made.

## Reports answered this session

1. Cop ID check "not working" — a 1 Hz census showed the scan runs and the
   candidate gate is the stock-tight one: a random pedestrian in WANDER_PATH,
   no objective, no look target, within 5 m and in sight. Nearby wanderers
   usually carry a live look timer (`free=0`), so checks are rare; they do
   fire (the hassle timer went positive in play). Stock; nothing changed.
2. Civil chatter missing — the worn body decides. `WillChat` declines the
   player for Tommy's and the police bodies because their banks have no chat
   clip (`GetPlayerTalkSfx`/`GetCopTalkSfx` fall to the generic male bank,
   which has no SOUND_PED_CHAT). The recent tests wore model 0 (Tommy) and
   model 1 (MI_COP). The user chose to keep the stock rule: civilian bodies
   chat, those bodies do not.
3. Hands-behind-back rarity — stock. The clip is `idle_hbhb`, used by the
   dead-end/back-track wait, the kerb-crossing wait and the look-about. A cop
   blocked chasing the player takes the look-about (stock, and it gives up
   after two); against an NPC target the engine turns the cop instead, so a
   pose seen there is the wander dead-end right after the chase ends. The
   after-kill pose is skipped for cops (stock mission-char behaviour).

## Combat parity fixes (the session's real work)

NPC mode was taking three player-only branches that exist for a human trigger:

- **Accuracy** — `ProcessPlayerWeapon` is skipped in NPC mode, so
  `m_wepAccuracy` froze and the DOOM AIM row did nothing. `VCModUpdateNpcMode`
  now writes it every frame (95 CANAIM, 100 otherwise, 60 with the row).
- **Aim ramp** — `m_fAttackButtonCounter` only grows in NPC mode (its decay is
  in the skipped function), so the cop's spread collapsed over a hunt. The
  player ramp is off in NPC mode (`VCModPlayerAimRamp`), shots use the accuracy
  value like a ped.
- **Burst end** — `Attack()`'s player branch parks/re-aims the aim pose (the
  trigger is still down); NPC mode now takes the ped branch
  (`VCModPlayerAimPoseHold`), so the pose drops between bursts and the AI
  re-raises on its own beat. The recovery tail is gated off in NPC mode, and a
  guard releases a pointed gun once the fight is over and the ped is out of
  the combat states.

The blocked-ped predicate was verified byte-equivalent to the engine for every
non-player ped, so native cops are untouched.

## Temporary probes still in (DIAGNOSTICS)

- `VCMOD cop scan:` — near-ped census for the ID-check gate, 1 Hz, player cop
  only (`vcmodnpc.cpp`, called from `CPed::CopPatrolScan`).
- `VCMOD civ layer:` now carries the nearest ped's `will`/`dist`/`partner`
  fields for the chat candidate.

Strip both with the NPC commit that ships after play verification.

## Next

1. Play-check build 530: during a hunt the gun drops between bursts while he
   runs in and raises to fire; after the fight it returns to the carry. Doom
   Aim off = accurate, on = ped spread, switchable mid-hunt.
2. Then the refactor plan in `docs/handoff/2026-11-14-refactor-flow.md`:
   the Windows `Play.bat` package, and the config registry last.
3. Publishing the handout (`gta-vc-dream-mod`) needs its own explicit ask; this
   session only committed the local `vcmods` branch and regenerated the patch.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are `uchg`. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install. Git on reVC is the user's: no push, and no
publish of `gta-vc-dream-mod` without the explicit ask.
