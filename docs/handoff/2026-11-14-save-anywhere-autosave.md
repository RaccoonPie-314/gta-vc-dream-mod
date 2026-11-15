# Save anywhere and post-mission autosave (2026-11-14)

Workspace `vc-mod`, reVC checkout `reVC/`, branch `vcmods`, HEAD `3f62c78`.
Installed build `~/Games/VC/reVC.app` (installed this session). Nothing
committed; this work sits on top of the existing uncommitted session changes.

## What was built

Both features are always on — no panel row, no ini key.

- **Pause menu `SAVE GAME` row** (`MENUACTION_PAUSE_SAVE`), inserted after
  Resume. Opens the stock slot picker. Refused with a HUD notice and a log
  line during a mission (`bAlreadyRunningAMissionScript` or the script's own
  `OnAMissionFlag`), during a cutscene, while wasted/busted, and outside
  `GS_PLAYING_GAME`. Manual saves keep the stock pre-save pass, so game time
  still advances 6 in-game hours like a safehouse save.
- **Autosave after a passed mission.** `COMMAND_REGISTER_MISSION_PASSED` (and
  the oddjob variant) record the script; that script's mission-flag
  `TERMINATE_THIS_SCRIPT` arms the save, which fires on the next
  `CGame::Process` tick if the moment is saveable. Failed missions, side
  threads and mismatched scripts cannot arm it. The autosave skips
  `DoGameSpecificStuffBeforeSave` so the mission flow never jumps the clock.
- **Slot 8 is the autosave slot.** It is gone from the manual save list
  (1-7 remain + Cancel), still shown in Load and Delete, and labelled
  `AutoSave` (header name written as `AutoSave`, empty row reads `AutoSave`).
  The first passed mission overwrites whatever `GTAVCsf8.b` holds.

Saving while driving works: the autosave/pause save sets the pool force flag
(the same path the mobile quicksave uses), so the player's car is written
into the save and restored on load. The ped/vehicle link is not part of the
save format, so a save taken in a car loads on foot beside the preserved car.

## Files

- New: `src/extras/vcmodsave.{h,cpp}`, `utils/test_vc_save.py`.
- Engine hooks (predicate/branch only): `src/core/Frontend.{h,cpp}`,
  `src/core/MenuScreensCustom.cpp`, `src/core/Game.cpp`,
  `src/core/Pools.cpp`, `src/save/GenericGameStorage.cpp`,
  `src/save/PCSave.cpp`, `src/control/Script.cpp`, `Script3.cpp`,
  `Script8.cpp`.
- `VCModSaveTick` runs with the other feature ticks in `CGame::Process`.

## Verified

- Full build, no new warnings.
- `utils/test_vc_save.py`: trigger matching, all gates, timeout drop,
  failure no-retry, label/override scoping, plus wiring checks. Whole
  `utils/test_vc_*.py` suite green.
- Not yet seen in play. The harness proves the decisions, not the feature.

## Play test

1. Pause on foot, `SAVE GAME`, slot 1, confirm, resume; load slot 1.
2. Same while driving: the car should come back with you (you on foot beside
   it); note whether the spawn looks acceptable.
3. Pause during a mission: the row refuses, and the reason shows in the help
   line after closing the menu.
4. Pass a mission: `GAME AUTOSAVED` help line, then Load shows `AutoSave` in
   slot 8 with the current date. Load it; state should be the post-mission
   world.
5. Save at a safehouse save zone: unchanged stock flow, 1-7 only.

## Next

1. Play test above; adjust the in-car load behaviour if the on-foot spawn
   looks wrong (the alternative is refusing save while seated).
2. If the oddjob passes autosave too eagerly, drop the `Script8.cpp` hook.
3. Commit and sync when the play test passes.
