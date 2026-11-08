# Cutscene Voice Guide

Status: living rule
Date: 2026-11-07
Applies to: any spoken line added for an existing GTA VC character in a mod cutscene
Tool: `scripts/voicebank.py`

The rule: **look up first, reuse before generating, and generate only in the
character's own voice and register.** Never write a line and synthesize it as an
afterthought; the check comes before the script entry is finalized.

## 1. Order of checks

Do these in order. Stop at the first one that answers the line.

1. **Stock line already says it.** The bank holds 9,416 existing clips. Check the
   set's `categories` in the manifest for a bark that fits (`ARREST`,
   `COP_ASK_FOR_ID`, `CHAT`, `JEER`, `FIGHT`). A stock bark is native audio, so it
   beats anything generated. If two clips cover the beat, use stock.
2. **Voice profile exists.** Run `lookup` for the speaking ped's model:
   `python3 scripts/voicebank.py lookup MI_SWAT`.
   It prints the routed set(s), the delivery categories, the reference picks, and
   whether generated lines already exist for that set.
3. **Same line was generated before.** Generated audio carries a sidecar and an
   index entry keyed by `sha1(set + text)`. Search `generated/index.json` before
   asking for a take. A changed style or seed is a new take, not a duplicate.
4. **Generate.** Only after 1–3 miss. If the generator is not wired up yet, mark
   the line `PENDING-VOICE` in the mission script rather than shipping a
   placeholder.

If `lookup` reports no set for the model, the model has no dedicated actor and is
routed to a fallback (`ARMY`/`FIREMAN` → `GENERIC`, `MALE01` → `DEFAULT`). Use the
routed set. Never synthesize a new persona by borrowing an unrelated demographic's
voice.

## 2. Pick the right voice

- One character, one set, pinned. The engine chooses cop variants per entity
  (`AudioLogic.cpp:5774`, `% 5`), SWAT (`:5814`, `% 3`) and FBI (`% 3`). A cutscene
  must pick one variant per character and use it for every line. Do not spread a
  character's lines across variants.
- Two characters sharing a model (two SWATs, two cops) need different variants, and
  the variant assignment must be stable across scenes so they are recognizable.
- Ped model codes are demographic + role shorthand: `BMYBB` (black male young beach
  bum), `WMYST` (white male young street), `HFOST` (hispanic female old street).
  Treat the code as a hint and confirm by listening to the reference clips.
- `PLAYER` and `POLICE` are not NPC voices: `PLAYER` is Tommy, `POLICE` is radio
  chatter. Neither belongs in an NPC cutscene.

## 3. Match personality, not just timbre

The bank's categories are the characters' full emotional range. A clone can only
reproduce registers the actor actually recorded, so the line has to live inside
that range.

| Archetype | Available registers | Write them as |
|---|---|---|
| Cop, SWAT, FBI | orders, tension, fight (`ARREST`, `COP_TARGETING`, `GUNAIMEDAT*`, `DODGE`) | clipped, procedural, imperative |
| Medic | fight, at-victim, get-out (`FIGHT`, `AT_VICTIM`, `GET_OUT_VAN_CHAT`) | urgent, reassuring |
| Civilians | neutral, taunt, panic (`CHAT`, `FIGHT`, `EYEING`, `JEER`, `SHOCKED`, `DODGE`) | colloquial, short, present tense |
| Radio (non-character) | dispatch fragments | never spoken by a character |

Rules that follow:

- Do not write reflective, wistful or deadpan humour for SWAT. Fourteen shouted
  orders is the actor's entire SWAT performance; the clone will fight you.
- A taunt from a civilian is well supported (`JEER`, `FIGHT`, `EYEING`). A calm,
  reasoned cop speech is not; use `COP_ASK_FOR_ID` / `SAVED` lines instead or
  rewrite the beat.
- Pick the reference bucket that matches intent: `neutral`/`order`, `angry`/`taunt`,
  `panic`/`tense`, `fight`. Never mix buckets inside one take unless the line
  genuinely changes emotion mid-sentence.
- VC dialogue is terse. One thought per line, no long subordinate clauses, no
  exposition. Cut the line before stretching the clone.
- Split anything over ~10 seconds into separate lines with separate takes.

## 4. Format contract (the "1:1" rule)

Generated audio must be indistinguishable from the bank in format and level:

- Native rate per set (`manifest.voices[id].rate`, 12,000 Hz for ped and law),
  mono, 16-bit PCM.
- Level-matched to that set's median `rms_dbfs` (per-clip values are in the
  manifest), within ±1 dB.
- No denoise, EQ, compression, reverb, room tone, or modern loudness
  normalization. The 12 kHz ceiling is the character; leave it alone.
- Trim leading and trailing silence to the same floor as the bank clips.
- Never upsample the source for training reference and forget to bring the output
  back down.

## 5. Files and record keeping

```
voice-library/
  manifest.json                 voice sets, routing, references, level targets
  voices/<SET>/*.wav            byte-exact bank clips
  generated/<SET>/<slug>-<hash8>.wav
  generated/<SET>/<slug>-<hash8>.json
  generated/index.json          sha1(set + text) -> take
```

Sidecar fields: `text`, `style`, `refs`, `seed`, `model`, `created`, `rms_target`,
`source_set`. A take is reproducible only if those are recorded.

## 6. QC before the line ships

1. Level: new clip within ±1 dB of the set's median, no clipping.
2. Bandwidth: no energy above the set's ceiling; compare against two stock clips.
3. Blind A/B: put the new line between two stock lines from the same character.
   If it is the one that stands out, it is wrong.
4. In-game: play it through the cutscene audio path at the same gain as the stock
   lines around it.
5. Pronunciation: names, place names and slang need a listen; VC actors clip
   consonants and the clone may swallow them.

## 7. Storage and legal

Generated lines are derived from copyrighted recordings. They stay in
`~/Games/VC/voice-library` (or another local folder), never in the repo, the patch,
or a published folder. `vc-mods.patch` carries code only.

## 8. Open items

- Reference transcripts: every clone model needs the text of its reference clips.
  Not built yet; the library currently ships audio and heuristic picks only.
- `genline`: the generator that reads this manifest, enforces section 4, and writes
  the sidecar and index entry. Not built yet.
- Audio path for cutscenes: new lines are played through the OAL channel wrapper
  (`reVC/src/audio/oal/channel.cpp`, mono16) or appended to the bank if they must
  be script-addressable. Decide per scene; bank edits are patch-external.
