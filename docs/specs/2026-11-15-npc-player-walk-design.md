# BECOME NPC with player movement — design

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `aebb665`.
Installed build `vcmods build 593`. Status: design approved 2026-11-15,
implementation pending, spec uncommitted.

## Goal

While BECOME NPC runs, everything except locomotion stays the AI's, exactly as
today. The player's movement keys own the body's translation: hold them and you
steer, release them and the AI moves him again like a stock ped. In a fight the
AI keeps aiming and firing at its target while you walk the body around it.

The feature is one row under BECOME NPC. Row off is BECOME NPC byte for byte;
BECOME NPC off is stock. It replaces the earlier auto-combat-only idea, which
is not built.

## Approved decisions

- **Walks on his own.** With no movement input he wanders, chases, flees and
  walks to seats and cars like BECOME NPC today. The AI never pauses; the keys
  only take over translation while held.
- **Steer while he shoots.** The AI owns target selection, aim, fire and the
  melee chooser. The player owns translation in every state, combat included.
- **One row under BECOME NPC**, not a separate mode.

## How BECOME NPC owns movement today

All sites in `src/peds/PlayerPed.cpp` unless noted.

| State | Who sets speed / heading today |
| --- | --- |
| `PED_IDLE` | the driver re-issues a wander; no input path |
| `PED_WANDER_PATH` | engine path following + `VCModNpcStrollGait` (`src/extras/vcmodnpc.cpp:63`), called at line 2133 |
| `PED_SEEK_POS` / `PED_SEEK_ENTITY` | `VCModNpcMoveSpeed` per move state, line 2157 (cop chase, chat approach) |
| `PED_SEEK_CAR` / `PED_SEEK_IN_BOAT` | stock speed; the stock input cancel already exists, line 2194 |
| `PED_FLEE_POS` / `PED_FLEE_ENTITY` / `PED_INVESTIGATE` | `VCModNpcMoveSpeed`, line 2074 |
| `PED_CHAT` | speed 0, line 2140 |
| `PED_ATTACK` / `PED_AIM_GUN` / `PED_FIGHT` | the engine objective layer; `VCModNpcCombatControl` (`src/extras/vcmodcombat.cpp:527`) |

Player input is otherwise dead in the mode: the pad's weapon block is skipped
(line 2126), and the AI brain runs from `VCModUpdateNpcMode` (line 1940).

## The gate

New module `src/extras/vcmodnpcwalk.{cpp,h}`:

```cpp
// "WASD MOVE" row: the player's movement keys own locomotion while BECOME NPC
// runs. Off is today's BECOME NPC.
extern bool bVCModNpcPlayerWalk;
// true when BECOME NPC runs and the row is on
bool VCModNpcPlayerWalks(void);
// true when a movement key is held this frame
bool VCModNpcWalkInput(CPad *pad);
```

Row label `WASD MOVE`, WORLD page, directly under BECOME NPC; ini key
`NpcPlayerWalk`; default off. It acts only while BECOME NPC is on and toggles
live. `TYPE FROM BODY` and the profile rows keep working untouched.

## Locomotion precedence

Each frame, in this order:

1. The AI brain runs unchanged (`VCModUpdateNpcMode`).
2. If a movement key is held, the stock player locomotion writes speed and
   heading for the frame — `PlayerControlZelda` on foot (line 1703),
   `PlayerControlFighter` in a fist fight (line 942) — and the state's own AI
   speed write is skipped for that frame.
3. With no key held, the state's AI speed write runs unchanged: stroll gait,
   seek speed, flee speed, combat positioning.

Input means a walk axis, sprint with a direction, or a jump press; the
locomotion call also carries the stock idle animations. Free states take the
heading from the input, camera-relative. Combat states keep the AI's facing; see Slice B.

Chat: walking away ends the chat, the way a stock player's walk does. Pose
waits (tired, look-around, after-kill) end on a movement key; the attractor
waits (seat, ATM, chat gesture) keep their clock and finish on their own. Car
entry keeps the stock input cancel byte for byte: a movement key restores the
previous state and objective, as it already does today.

## Combat (slice B)

- The AI keeps target selection, aim, fire, and the melee chooser; the pad's
  weapon block stays dead, so the player's trigger and aim do nothing.
- Movement is translated while the AI fires. The targeting movement lock
  (`MovementDisabledBecauseOfTargeting`, line 1689) exists for a human trigger
  and must not zero the player's keys here.
- In `PED_ATTACK` and `PED_AIM_GUN` the AI owns the facing, re-asserted after
  the locomotion with the stock player's tracking turn
  (`RotatePlayerToTrackTarget`, the call the player's own lock-on uses), and
  movement is camera-relative, capped to the aim-walk speed while the gun is up
  and free once the AI leaves the aim.
- In `PED_FIGHT` the AI picks and throws the moves; movement uses the stock
  fighter step rule, including the step-off after a punch.
- Releasing the keys returns movement to the AI: it closes distance, holds or
  retreats per the ped combat state.

## Hand-back and breaks

Same breaks as BECOME NPC today (`VCModNpcModeBreak`): death, a car, arrest,
controls disabled. The row toggling live only changes who translates: off
mid-fight returns movement to the AI, on mid-fight hands it to the keys at
once. Turning BECOME NPC off returns stock play.

## Worn skin

Unchanged. `TYPE FROM BODY` picks the profile and gang; the worn body's stat,
accuracy (`src/extras/vcmodnpc.cpp:585`) and anim group are borrowed while the
mode runs and restored on exit. This feature adds no stat or accuracy rule.

## Slices

Each slice is its own playable build; with the row off a slice is the previous
build's behavior.

### Slice A — the row and free-walk

- Flag, row, ini key, module; the gate and the input predicate.
- Movement override in wander, seek pos/entity (cop chase, chat approach),
  flee/investigate, idle, chat end and wait end.
- Combat stays fully AI-owned: the keys are dead in `PED_ATTACK`,
  `PED_AIM_GUN` and `PED_FIGHT`, as today.
- New harness `reVC/utils/test_vc_playerwalk.py`.
- Play: steer over his wander and let go; steer during a cop chase; walk away
  from a chat.

### Slice B — combat steering

- Facing rule in the aim states, the targeting-lock bypass, the aim-walk
  speed cap, and the fist-fight step rule.
- Play: a gunfight as a gang and a cop body, steering while he fires; a fist
  fight.

### Slice C — edge states

- ID check hold, the gang group talk and leader walk, attractors and seats,
  seek-car, and an inventory of every remaining speed write in the NPC path.
- Play: a full pass across all three profiles.

## Testing

- The harness pins the gate, each new branch behind `VCModNpcPlayerWalks`, and
  the stock-when-off line: no write happens with the mode or the row off.
- Full harness set, `scripts/build.sh`, then `scripts/install.sh` only with the
  game closed; confirm the installed build number.
- Harnesses read source; play decides. A slice is verified in game before the
  next one starts.

## Files

- New: `src/extras/vcmodnpcwalk.{cpp,h}`, `reVC/utils/test_vc_playerwalk.py`.
- Hooks, one line each: `src/peds/PlayerPed.cpp` (the state switch sites
  above), `src/extras/vcmodnpc.cpp` (driver deference),
  `src/extras/vcmodpanelregistry.cpp` (row and ini key).
- No engine file gains feature logic; other platforms see the same code.

## Out of scope

- Vehicles: a car breaks the mode as today; no driving or drive-by control.
- The player's trigger and aim input during an AI fight: the AI owns them.
- A standalone auto-combat switch: replaced by this design, not built.

## Risks

- `PlayerControlZelda` writes the heading (`m_fRotationDest`). In combat the
  aim must win the facing; Slice A avoids the conflict by leaving combat fully
  AI-owned until Slice B owns the rule.
- The AI re-decides move states every frame. The override must be a per-frame
  deferral, never a state flip, or releasing the keys would leave an AI state
  driving a player-set speed.
- The idle re-wander keeps its 500 ms retry gap, so after release he may stand
  a moment before the AI walks. That is stock NPC-mode timing and is kept.

## Acceptance

- Row off: BECOME NPC matches the installed build; BECOME NPC off: stock.
- Row on: movement keys always move the body, releasing always returns the
  AI's movement, combat keeps firing while steering, all three profiles work
  through `TYPE FROM BODY`, and the mode's breaks are unchanged.
