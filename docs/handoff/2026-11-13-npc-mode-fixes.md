# NPC mode fixes (2026-11-13) — built, installed, play check pending

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `bb3fe88`.
The installed build is now `vcmods build 464` (was 458; 460 and 462 were the
earlier rounds of these fixes). All 45 harness suites pass at 464. No commit,
tag or push was made.

## Reported

1. Police hunting a criminal did not trigger on the first COP engage; toggling
   NPC MODE off and on made it work.
2. Walking into a blocked path no longer played the tired pose (hands on knees).
3. Switching NPC MODE off did not completely stop the AI.
4. The post-kill hands-behind-back pose lasted about a second instead of the
   stock 3.5 s.
5. After the first round the tired pose and the ID check worked, but the first
   engage still behaved differently from a re-engage: the user's workaround was
   still to toggle NPC MODE off and on.

## Root causes and fixes

All three live in `src/extras/vcmodnpc.cpp`.

### 1 + 4. The stroll wrote over the engine's wait poses

`CPlayerPed::ProcessControl` runs `VCModNpcStrollGait` for every
`PED_WANDER_PATH` frame. While a wait state owned the body — `WAITSTATE_STUCK`
(the blocked-ped tired pose), `WAITSTATE_DOUBLEBACK` (the after-kill
hands-behind-back), the look-arounds — the stroll still wrote
`m_fMoveSpeed`, `m_nMoveState`, `m_nStoredMoveState` and called
`SetRealMoveAnim()`. Its walk clip blended over the pose about a second in, so
the 5 s tired pose and the 3.5 s post-kill pose were cut short.

Fix (`vcmodnpc.cpp:58`): the stroll stands down while
`m_nWaitState != WAITSTATE_FALSE` — zeroes its eased speed and the ped's move
speed and returns, letting `CPed::Wait()` own the pose. When the wait ends the
stroll resumes on the next frame.

### 1. A street chat had no owner during NPC mode

STREET IDLE is ambient and on by default. If a passer-by opened a chat before
BECOME NPC was switched on, the street layer stood down (`VCModUpdateStreetIdle`
returns early on `bVCModNpcMode`) but nothing ended the chat.
`VCModStreetKeepChat` re-asserted `PED_CHAT` for both peds every frame, and the
command's "not walking yet" branch only starts a wander from `PED_IDLE` /
`PED_WANDER_PATH`. The cop branch — and therefore `CopPatrolScan` — is only
reached once the wander is owned, so hunting never started until a toggle-off
cleared the chat.

Fix (`vcmodnpc.cpp:329`): while the mode is on, an active street chat is
aborted through `VCModStreetAbortChat(player, "npc mode")`. `ClearChat` restores
the previous state, so the wander starts the same frame and the patrol runs.

### 3. The release skipped a ped owned by a jump/fall/getup

`VCModNpcReleasePed` returned early for every state at or above
`PED_STATES_NO_AI`. That guard is right for death and arrest, but a jump, fall,
getup or stagger is transient: the objective, wait state and path were left
behind, and the engine resumed them on the frame control returned — the AI
still running after the switch was off.

Fix (`vcmodnpc.cpp:267`): the guard is now death, in-vehicle or `PED_ARRESTED`;
the objective/wait/chat/threat/path clears run in every other state, and only
the `ClearAll()`/`SetIdle()` hand-back waits for a state below
`PED_STATES_NO_AI`.

### 5. The first engage inherited normal-play residue

An engage was not the same body a re-engage starts from: a normal-play
objective, threat/event reference, attractor, an unattached path, a wait state,
or an aim/fight state rode into the profile. The patrol then reacted to it (or
waited behind it), which is why a toggle-off/on — whose release wipes all of
it — made the mode behave.

Fix (`vcmodnpc.cpp:353`): on the engage edge, `VCModNpcBodyDirty`
(`vcmodnpc.cpp:253`) names those leftovers, the stat borrow is restored, and
the same `VCModNpcReleasePed` the toggle-off runs takes the body before the
profile starts. Two deliberate exceptions: a wander the street layer already
owns is not residue (the command inherits it), and a seat pose keeps the body
until the player stands, as before. The release also resets the hassle timer
and the stroll speed now, so nothing of the previous engagement survives
(`vcmodnpc.cpp:281`).

### 6. QUICK ID CHECK could not shorten a cooldown already running

The debug switch only chose the timer for the *next* check. If a check had just
set the stock 100 s cooldown, turning the switch on did nothing until that
timer expired, so the ID check could not be retested without waiting it out.

Fix (`vcmodnpc.cpp:521`): the cop branch clamps a running cooldown to five
seconds when `bVCModCopQuickChecks` is on, so the switch takes effect at once.

### Diagnostic

`vcmodnpc.cpp:558` — with DIAGNOSTICS on, the "not walking yet" branch now logs
one line a second naming the state that owns the ped (`state`, `obj`, `ctrl`,
`sit`, `car`, `dead`). If a first engage ever stalls again, that line says why.

## Harness

- `utils/test_vc_npcmode.py` — four new tests:
  - a wait state keeps the stroll off the body (speed, stored state and clip
    calls), and the stroll resumes when the pose ends;
  - toggling off during `PED_FALL` clears the objective, wait and path without
    forcing an idle onto the fall;
  - engaging with a street chat active aborts it;
  - a first engage wipes a normal-play objective, wait state, threat, attractor
    and unattached path before the profile runs;
  - QUICK ID CHECK shortens a 100 s cooldown already running.
  - The three seat/ATM/ID-check tests now engage first and set their objective
    on the next frame, which is the order those states actually occur in.
- `utils/test_vc_npcwalk.py` — its stroll stub gained `m_nWaitState` and
  `WAITSTATE_FALSE`, since the extracted function now reads the wait state.

## Verification

- All 45 `utils/test_vc_*.py` suites pass (39 tests in the NPC harness).
- `scripts/build.sh` builds cleanly (build 464); installed with
  `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty. The installed binary reports
  `vcmods build 464`.
- In game: build 462 was played and everything worked; the only open items were
  the stock post-kill clip length and the quick-check cooldown. Build 464
  (cooldown clamp) is unplayed.

## Not changed

- The update order, the animation-path hooks and the no-strafe gates are
  untouched.
- Toggling NPC MODE off still hands back the player's own STREET IDLE setting,
  as designed; with that switch on, street-idle behaviour resumes after the
  idle timer. That is a setting, not a leftover.
- The post-kill pose is stock. `WAITSTATE_DOUBLEBACK` sets a 3.5 s timer; at
  about one second in the engine blends `idle_hbhb` into the scratch-and-exit
  tail and shortens the timer by 500 ms, so the hands-behind-back clip itself
  is visible for roughly one second and the whole wait runs about three. The
  5–6 s seen on build 460 was a different pose (the blocked-ped look-about is
  5 s of the same clip) or the stand before walking. The stock timer is kept;
  holding the clip for the full 3.5 s would be a deliberate deviation.

## Uncommitted

Same eleven refactor slices plus the cop fixes as the previous handoff, now
with this NPC-mode fix in `src/extras/vcmodnpc.cpp` (new file) and two harness
files.

## Next

1. Play check build 464: with QUICK ID CHECK on, an ID check should be
   reachable within 5–10 s even if the 100 s cooldown was running (`VCMOD cop:
   id check model=…`). Decide whether the stock post-kill clip length is
   acceptable; holding the hands-behind-back for the full timer is a change.
2. Re-confirm the build-462 items without toggling: first engage in a clean
   save, after a street chat, while aiming, and after a fight; toggle off
   mid-jump. With DIAGNOSTICS on, a stalled engage logs `VCMOD npc wait: …`.
2. The still open panel, combat, character, ride, gang, NPC/cop and player
   passes, plus one chase run.
3. `ProcessPlayerWeapon` aim-control extraction; the single never-wanted helper
   in `Wanted.cpp`.
4. Commit only when asked.

## Files not to touch

Game data is read-only: `~/Games/VC/`, `~/Games/VC-ai/`,
`~/Library/Application Support/reVC/`. `anim/cuts.img`, `anim/cuts.dir` and
`anim/ped.ifp` are uchg. Check `pgrep -f "reVC.app/Contents/MacOS/reVC"`
immediately before any install.

## Paste-ready prompt

> Continue `vc-mod/reVC`, branch `vcmods`, HEAD `bb3fe88`; build 464 is installed.
> Read `docs/handoff/2026-11-13-npc-mode-fixes.md` first, then
> `docs/handoff/2026-11-13-panel-split.md`, `docs/architecture.md` and
> `AGENTS.md`. Eleven behaviour-neutral slices plus the cop fixes are
> uncommitted; the NPC-mode fixes (build 462 played, build 464 unplayed) and the
> panel, combat, character, ride, gang, NPC/cop and player play checks are still
> open.
>
> Work directly in this session: one module per session, done in place. Next is
> the `ProcessPlayerWeapon` aim-control extraction, then the single
> never-wanted helper in `Wanted.cpp`.
>
> Keep every move behaviour-neutral and verbatim for refactors; feature fixes
> stay in the feature module. Engine files keep hook calls only. Preserve the
> update order in `CPlayerPed::ProcessControl` — adrenaline 1870 → reconcile
> 1871 → apply-default 1872 → ride 1873 → sit 1927 → street 1928 → npc 1929 →
> keys/latch 1941–1950 → never-wanted 1953 — the animation-path hooks
> (`VCModPlayerAnimGroup` 1316, `VCModCharacterMoveTempo` 645, last of the five
> sprint-speed writes), and the no-strafe gates at `PlayerPed.cpp` 1313/1327,
> `Cam.cpp` 1537, `Ped.cpp` 2115. Name every new file and symbol by rule 17.
>
> Per feature: run all `utils/test_vc_*.py` suites, `scripts/build.sh`, then
> `scripts/install.sh` only with `pgrep -f "reVC.app/Contents/MacOS/reVC"` empty,
> and confirm the installed binary reports the new build number BEFORE handing
> off for the player's live test — never hand off an uncompiled tree. In-game
> verify on and off is the player's turn. Clear `~/Games/VC/reVC.log` before each
> test, and read only fresh, filtered, capped slices. Update the debt sizes in
> `docs/architecture.md`, write the handoff and a paste-ready prompt at the end.
> Never commit or push unless asked; game data and uchg anim files are read-only.
