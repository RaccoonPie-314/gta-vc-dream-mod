# Radio station archives restored (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `4fc7fcd`.
Workspace branch `main`, HEAD `fb454bd`. No code changed, no commit, no build:
this was game data only.

## Symptom

Every vehicle radio station played silence. Ambient MP3s and SFX were fine.

## Cause

`~/Games/VC/audio/` had no station archives. The streamer in
`reVC/src/audio/sampman.h` (`StreamedNameTable`) expects nine `.ADF` files:
`WILD`, `FLASH`, `KCHAT`, `FEVER`, `VROCK`, `VCPR`, `ESPANT`, `EMOTION`,
`WAVE`. The install had 1,120 `.wav` SFX, 90 ambience/stinger `.mp3` files,
`sfx.RAW`, `sfx.SDT` and `sound.cache`, but zero `.adf`.

`~/Games/VC/reVC.log` held 74,825 failed opens across those stations, the
first at line 5921 for `KCHAT.ADF` (the station `Radio=2` in `reVC.ini`).

`audio/sfx.RAW` is not a radio source: its 9,941 PCM sample descriptors in
`sfx.SDT` cover the file exactly (`max(offset+size) == file size`), so it
holds only sound effects.

## Restore

The nine files were copied from the Steam install's Cider prefix:

`~/Library/Application Support/Steam/steamapps/common/grand theft auto - vice city/Grand Theft Auto - Vice City.app/Contents/Resources/transgaming/c_drive/Program Files/Rockstar Games/Grand Theft Auto Vice City/audio/`

into `~/Games/VC/audio/`, with `cp -np` so nothing existing was replaced.
Each copy's sha256 matches its source. `KCHAT.adf` was XOR-decoded with
`0x22` and parsed as a valid 16 kHz stereo MP3.

Total added: about 556 MB. Disk had 15 GiB free.

## Not changed

- `audio/sound.cache` was left alone. `sampman_oal.cpp` recomputes every
  stream length at startup even when the cache loads, so the stale zero
  entries do not need removing.
- `~/Games/VC-ai/audio/` still has no `.ADF` files. Copy the same nine there
  if the test install needs radio.
- The user-track station stays empty: `mp3/` contains only `MP3Report.txt`
  (`TOTAL SUPPORTED MP3s: 0`).
- No other game data was deleted, moved, renamed, truncated or overwritten.

## Next

1. Launch from the Dock and tune through the stations; the log should no
   longer print `couldn't find dir/file "...ADF"`.
2. If radio is wanted in `~/Games/VC-ai`, copy the same nine files there.
3. Optionally add user MP3s to `~/Games/VC/mp3/` for the MP3 station.

Do not touch `anim/cuts.img`, `anim/cuts.dir`, `anim/ped.ifp` or any other
game data.
