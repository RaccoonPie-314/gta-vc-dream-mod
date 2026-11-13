# NATIVE-RESOLUTION FULLSCREEN ATTEMPT: REVERTED

Date: 2026-11-10
Repo/branch/HEAD: `reVC/`, `vcmods`, `8d57f7c`.
Installed: the original fullscreen build is reinstalled into `~/Games/VC`
(`scripts/build.sh` + `scripts/install.sh`, no session running).

## What was tried and why it was dropped

Goal: keep the desktop's 1470x956 display mode while playing fullscreen, so
alt-tab stops switching resolution. GLFW's own fullscreen path calls
`CGDisplaySetDisplayMode` to the game's saved 1920x1200 mode, and restores the
desktop mode whenever its fullscreen window is miniaturised (GLFW auto-iconifies
on focus loss), which is the flicker seen in and out of every alt-tab.

The attempt created an undecorated, always-on-top window covering the desktop
at the desktop mode instead, and never set a display mode. Two rounds of play
showed a collapsed frame:

1. The borderless window runs through the engine's windowed path. There,
   `CameraCreate` left the camera raster at 0x0 and `CameraSize(nil)` reused
   that size (exclusive fullscreen replaces it from the video mode), so the
   camera ended up 0x0 with a 0/0 view window.
2. Forcing the fullscreen camera rules onto that window (new
   `IsFullscreenWindow()` hook plus `CameraCreate` honouring its size) still
   produced a broken frame in play; the remaining cause was not identified.

Reverted on request. Everything the attempt touched is back at `8d57f7c`:
`src/skel/glfw/glfw.cpp`, `src/CMakeLists.txt`, `src/rw/RwHelper.cpp`,
`src/skel/crossplatform.h`, `src/skel/win/win.cpp`, `src/skel/sdl2/sdl2.cpp`.

`~/Library/Application Support/reVC` was not modified by the revert. Its
`reVC.ini` records 1470x956 from the attempt; the reverted build fits that
against the mode list, which starts at 1920x1200 on this machine, so the usual
mode is selected again. Display -> Resolution sets another one if needed.

## Do not repeat blindly

Do not route fullscreen through the windowed path again without first testing
the camera/raster sizing for a non-exclusive video mode on a real playthrough.
The display-mode change is what keeps the rest of the engine on its
fullscreen assumptions.
