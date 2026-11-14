# Refactor flow after the NPC-mode fix (2026-11-14)

Workspace `vc-mod`; reVC checkout `reVC/`, branch `vcmods`, HEAD `1641b0f`
("Ship free-camera lock-on and the RIDE TO map-marker destination"). The
published mirror `gta-vc-dream-mod` is at `db965f4` on `origin/main`, pushed.
Release build `vcmods build 506` is installed in `~/Games/VC/reRC.app`.

This session changed no code. The tree is clean, `vc-mods.patch` matches HEAD,
and the `TEMPORARY` aim probes are gone. The only uncommitted file after this
session is this handoff.

In play on build 506: the cop ID check and the walk-off after it are confirmed.
Chase pursuit, the cop kill pose and the toggle-off release are still open.

## Why this doc exists

The NPC-mode module split landed in `4fc7fcd`. The freeze reported afterwards
was not caused by the move: `Ped.cpp:2537`'s blocked-path gate came in with
`bb3fe88` and made an NPC-mode standstill read as a blocked path. The fix is
`VCModNpcBlockedReset` in `vcmodnpc.cpp`, plus the cop after-kill pose gate
(`build 480`/`484`). The lesson for the rest of the refactor is that moved code
has not been the failure mode; changed conditions, defaults and ini reads are.

The remaining work is ordered here from least to most impact on BECOME NPC.
The first six steps cannot change NPC state; the last two can, so they go last
and carry the harnesses.

## Measured state

| Point | Value |
| --- | --- |
| `PlayerPed.cpp` | 2,625 lines, 78 `VCMod` references |
| `PedFight.cpp` / `Ped.cpp` / `PedAI.cpp` | 30 / 32 / 18 references |
| `Wanted.cpp` | 5 `bVCModNeverWanted` gates (lines 92, 210, 241, 415, 502) |
| `AudioLogic.cpp` / `PedChat.cpp` | 1 / 1 references |
| vcmod modules | 35 `.cpp` (11,745) + 33 `.h` (1,467) |
| `vcmodpanel.h` | 44 lines |
| Harnesses | 45; 16 still import `test_vc_passenger` |
| HUD notice copies | 3 (`vcmodchase.cpp:423`, `vcmodcrew.cpp:107`, `vcmodride.cpp:83`) |
| `ReadIniIfExists` in `re3.cpp` | 111 |
| `VCMOD` stderr lines | 78; 0 `TEMPORARY` |
| `Play.bat` | absent |
| `vc-mods.patch` | matches HEAD |
| `docs/architecture.md`'s "Current debt" section is stale (2026-11-13: 2,605
lines, patch called stale). Refresh it when the cleanup passes it.

## Flow, least → most impact on NPC MODE

### 1. Shared harness support + runner

Move the shared stubs out of `test_vc_passenger.py` into
`utils/vcmod_test_support.py` and add a runner. Sixteen of 45 harnesses import
the passenger harness directly. Test-only; zero runtime. Do it first because it
is the safety net for every later step.

### 2. HUD notice dedupe

Three identical copies of the same `wchar` copy + `CHud::SetHelpMessage` in the
chase, crew and ride modules. One helper; keep the 96-character buffer so no
message truncates. Text only; no state.

### 3. Diagnostics cleanup

78 `VCMOD` `fprintf` lines remain. Gate the noisy probe-style ones behind
`VCMOD_DIAG` and keep the feature logs (`street idle:`, `sit:`, `spin kick:`,
`passengers:`, `VCMOD CHASE state`). `stderr` only; no behaviour.

### 4. Windows `Play.bat` package path

No portable package exists; `install.sh` and `package.sh` are macOS-only. This
is the portability invariant, not gameplay. Nothing on this Mac can regress.

### 5. Never-wanted helper

The five `bVCModNeverWanted` gates in `Wanted.cpp` become one helper. The clamp
is player-wanted only; the COP profile hunts NPC criminals and does not read the
player's stars. Low NPC-mode exposure.

### 6. Crew split, only if touched

`vcmodcrew.cpp` is 1,012 lines. Split by concern only when the next change
lands there. Crew is a separate feature module; NPC mode never runs it.

### 7. `ProcessPlayerWeapon` aim-control extraction

Doom-aim accuracy, the scope skip and the AIM RAISE trigger gate still live in
`PlayerPed.cpp` (now 78 references after the lock-on work). NPC mode skips this
function at `PlayerPed.cpp:2120` (`padUsed && !bVCModNpcMode`), so a pure move
cannot freeze him. The exposure is `vcmodcombat`, which also owns
`VCModNpcCombatControl` / `VCModNpcCombatOwnsControl`; those stay untouched.
Move verbatim, one commit, no condition edits.

### 8. One config registry (last)

Make one registry drive ini load, save, panel and debug menu. This is the step
that can silently disable BECOME NPC: `bVCModNpcMode` is read at
`re3.cpp:699`, `nVCModNpcType` is clamped at `701`, and `bVCModCopQuickChecks`
is read at `709`. A dropped read leaves the flag at its default `false` with no
build error. Preserve the ini key strings, defaults and clamps exactly.

## Guardrails

- A commit is either a pure move or a behaviour change, never both. The split
  and the standstill fix shared a commit, which is why "did the refactor do
  it?" took a log dig.
- After steps 7 and 8, run all 45 suites plus the blocked-gate matrix
  (`test_an_npc_mode_standstill_is_not_a_blocked_path`) and the toggle-off
  release check. In-game pass only for those two: ID check (re-check as a
  regression), chase, kill pose, toggle off.
- Preserve the ini key strings, defaults and clamps exactly.
- Do not touch `VCModNpcBlockedReset` or re-introduce `bIsStuck` gating for the
  NPC-mode player.

## Verification

Nothing to build or install for this doc. When a step lands: all
`utils/test_vc_*.py` suites, `scripts/build.sh`, install only with
`pgrep -f "reVC.app/Contents/MacOS/reVC"` empty, confirm the installed build
number, then `scripts/sync.sh` and `scripts/publish.sh` if a release is wanted.

In game (2026-11-14): cop ID check and the walk-off after it confirmed on
build 506. Chase pursuit, the cop kill pose and the toggle-off release remain
open.

## Next

1. Steps 1–3 in one pass: shared test support + runner, HUD notice dedupe,
   diagnostics gating. None can touch NPC mode.
2. In game on build 506: the cop ID check and the walk-off after it are
   confirmed. Chase pursuit, the cop kill pose and the toggle-off release are
   still open; check those when convenient.
3. Then the packaging step, and leave the aim extraction and the config
   registry for their own sessions, in that order.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are `uchg`. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install. Git on reVC is the user's: no commit, tag or
push unless asked.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `1641b0f`; build 506 installed;
> tree clean and pushed to the mirror (`gta-vc-dream-mod` `db965f4`). Read
> `docs/handoff/2026-11-14-refactor-flow.md` first, then `docs/architecture.md`
> and `AGENTS.md`. Work the remaining refactor least-to-most NPC-mode impact:
> (1) move the shared harness stubs into `utils/vcmod_test_support.py` and add a
> runner, (2) dedupe the three HUD notice helpers, (3) gate the noisy VCMOD
> diagnostics behind `VCMOD_DIAG` while keeping the feature logs. Then the
> Windows `Play.bat` path, the never-wanted helper, and only then the
> `ProcessPlayerWeapon` aim extraction and the single config registry — those
> two are the only steps that can affect BECOME NPC, so each gets its own
> commit, all 45 suites, and an in-game pass (ID check confirmed on build 506;
> chase, kill pose and toggle off still open). Preserve `NpcMode` / `NpcType` /
> `QuickCopId` keys and the `nVCModNpcType` clamp. Never commit or push unless
> asked; game data and the uchg anim files are read-only; check
> `pgrep -f "reVC.app/Contents/MacOS/reVC"` before any install.