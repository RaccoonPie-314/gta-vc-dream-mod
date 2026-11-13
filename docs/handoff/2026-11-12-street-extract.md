# Street extraction (2026-11-12) — built, installed, play check open

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
`vcmods build 431` is installed in `~/Games/VC/reVC.app`. All 43 harness suites
pass. No commit, tag or push was made.

## What changed

- `src/extras/vcmodstreet.{cpp,h}` now own STREET IDLE: the waiting pose and
  gesture cycle, the head scratch, the kerbside road-cross look and its probe,
  the pair chat (voices, gestures, breaks), the wander escalation, and the
  `bVCModStreetIdle` flag (defined in the module, `extern` in its header). The
  moved bodies are byte-identical; only the functions other files call lost
  their `static`. Public API: the chat/wander predicates, `VCModStreetEndChat`,
  `VCModStreetAbortChat`, `VCModStreetEndWander`, `VCModStreetStartWander`,
  `VCModStreetFadePose`, `VCModStreetKeepChat`, `VCModStreetUpdateIdle`, and the
  shared `VCMOD_CHATBREAK_*` bit enum.
- `src/peds/PlayerPed.cpp` is 1,284 lines shorter for this slice (3,963 now).
  It keeps hooks: the `VCModStreetUpdateIdle` call before the control code,
  `VCModStreetKeepChat` after it, `VCModStreetWanderOwnsPlayer()` in the NPC
  gates and `PlayerControl`, `VCModStreetClearWander()` in the NPC hand-back,
  and `VCModStreetChatActive()` before the spin kick ends a chat.
- NPC mode still reads/writes the moved `bVCModStreetIdle` flag through the
  street header, and `VCModNpcModeBreak` uses the shared chat-break bits.
- One temporary seam remains: `VCModNpcResetStroll()` is declared in
  `vcmodstreet.cpp` and defined in `PlayerPed.cpp`, because the NPC stroll
  easing still lives there. `VCModRideNotice` remains the second seam.
- `vcmodsit` now includes `vcmodstreet.h` for the idle-pose fade and the
  STREET IDLE gate; its local fade prototype is gone. `Ped.cpp`, `Weapon.cpp`,
  `vcmodpanel.cpp` and `re3.cpp` include the street header.
- Harnesses: `test_vc_wander.py` and `test_vc_npcmode.py` read the module;
  `test_vc_ganggaze.py` follows the `VCModStreetChatActive()` marker;
  `test_vc_adrenaline.py`/`test_vc_character.py` supply the moved flag in their
  panel stubs; `test_vc_diag.py` includes the module in its log sources.

The feature-off path is unchanged: with STREET IDLE off there is no waiting
pose, chat or wander, and the C press is the sit module's own gate.

## Verification

- All 43 `utils/test_vc_*.py` suites pass, before and after the install.
- `scripts/build.sh` builds cleanly (build 431). Installed with no game session
  running (`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty).
- Both the build tree and the installed binary report `vcmods build 431`.
- In game: not yet checked. The street pass is the open item: the waiting pose
  and scratch on a pavement stop, the kerb look at a crossing, the pair chat
  with a civilian, the wander escalation, STREET IDLE off returning stock, and
  the NPC mode hand-back standing him up and returning control.

## Uncommitted

The adrenaline and sit slices from earlier this session are still uncommitted
too; all three refactors are behaviour-neutral moves.

- New: `src/extras/vcmodadrenaline.{cpp,h}`, `src/extras/vcmodsit.{cpp,h}`,
  `src/extras/vcmodstreet.{cpp,h}`.
- Modified: `src/peds/PlayerPed.cpp`, `src/peds/Ped.cpp`,
  `src/weapons/Weapon.cpp`, `src/extras/vcmodpanel.{cpp,h}`,
  `src/core/re3.cpp`, `src/control/Replay.cpp`, and the harnesses
  `test_vc_adrenaline.py`, `test_vc_character.py`, `test_vc_diag.py`,
  `test_vc_ganggaze.py`, `test_vc_moveanim.py`, `test_vc_npcmode.py`,
  `test_vc_passenger.py`, `test_vc_sit.py`, `test_vc_wander.py`.
- `vc-mods.patch` predates all three refactors; regenerate after the commit.

## Next

1. Play check the street states above. Then commit the three refactors only when
   asked and regenerate `vc-mods.patch`.
2. Extract `vcmodnpc`/`vcmodgang` next: that removes the `VCModNpcResetStroll`
   seam, moves the NPC flag reads out of `vcmodsit` and `vcmodstreet`, and takes
   the civilian/gang/cop profile code out of `Ped.cpp`, `PedAI.cpp` and
   `PedChat.cpp`.
3. After that, the HUD notice dedupe can retire the `VCModRideNotice` seam.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 431 is
> installed. Read `docs/handoff/2026-11-12-street-extract.md` first. Adrenaline,
> sit and street now live in `src/extras/vcmodadrenaline.*`,
> `src/extras/vcmodsit.*` and `src/extras/vcmodstreet.*`; `PlayerPed.cpp` keeps
> hooks only. All 43 harnesses pass; the in-game adrenaline, sit and street
> passes are still open. Then extract `vcmodnpc`/`vcmodgang` the same way: one
> module per session, all 43 harnesses, a build, an install only with no session
> running, and a play check. Never commit or push unless asked; game data and
> uchg anim files are read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.
