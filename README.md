# Cinematic Shots

A ReShade add-on (`.addon64`) for lining up and capturing cinematic shots in Roblox through [Unishade](https://github.com/OMouta/Unishade).

It loads into Unishade's own process, alongside ReShade. Unishade captures the Roblox window with Windows Graphics Capture and runs ReShade on its own window, so nothing here is injected into or reads from the Roblox client.

## Features

**Framing guides.** Letterbox bars and rule-of-thirds lines drawn over the picture to help line up shots. Press **Ctrl+F6** to show or hide them while driving. In the **Cinematic** section of ReShade's Add-ons tab you can pick the aspect ratio (2.39:1, 2.00:1, 1.85:1, 16:9, 4:3 or 9:16 vertical), turn the bars or lines on and off, number the nine squares 1 to 9 (left to right, top to bottom) so you can talk about where things sit, and set how dark the bars are. Settings are saved in `ReShade.ini` under `[CINEMATIC_SHOTS]`.

The guides are for framing only: Unishade's screenshots leave them out. A recording that captures Unishade's window, such as OBS window capture, will include them, so hide them with Ctrl+F6 before recording. To share a frame with the grid on it, use Windows' Snipping Tool (Win+Shift+S).

**Coached shot list.** Six classic car shots (low tracking, chase cam, front three-quarter, low-angle hero, detail close-up and wide establishing), each with how-to tips that use the numbered squares. Pick one and its one-line hint shows at the bottom of the screen with the guides, so you can line it up while driving. Tick shots off as you get them; progress is saved. Press **Ctrl+F5** to move on to the next shot.

**Shot presets.** Link a ReShade preset to any shot: load the look you want, pick the shot and click **Link the current preset to this shot**. Picking that shot later, in the panel or with Ctrl+F5, switches to its preset. ReShade saves the preset you leave and reloads effects, so expect a short pause. Unishade follows the switch in its own menu. Turn **Switch to the shot's preset when I pick it** off to keep one look for every shot.

**Cinematic Look effect.** `CinematicLook.fx` is our own ReShade effect that does a film's finishing touches in one go:

- **Film glow:** halation (the red-orange glow real film gets round bright lights) and an anamorphic streak (the thin blue horizontal flare of widescreen movie lenses). Great on headlights, street lights and sunsets.
- **Colour grade:** pick a look: Blockbuster (teal & orange), Golden hour, Night chase, Bleach bypass or Vintage film, plus a strength slider and exposure.
- **Lens and film:** subtle chromatic aberration, a vignette, and moving film grain that sits in the mid-tones like real film.
- **Black bars (optional):** real 2.39:1, 2.00:1 or 1.85:1 bars, baked into screenshots and recordings, unlike the add-on's framing guides.

Unlike the guides, everything this effect does ends up in your screenshots and recordings.

**Daily Drive effect.** `DailyDrive.fx` is the light, cheap one for just playing: one pass with contrast-adaptive sharpening (after AMD's FidelityFX CAS), a colour look, vibrance, warmth, contrast and exposure. Its looks come from our own LUTs.

**LUTs.** Nine colour looks stored as LUTs in `textures/`: four for everyday play (Clean daylight, Warm evening, Cool night, Punchy) and the five Cinematic Look grades. `CinematicShots_LUTs.png` holds them all for Daily Drive; each one is also a standard 1024x32 strip (`CinematicShots_<Name>.png`) that ReShade's own `LUT.fx` can use by setting `fLUT_TextureName` to its file name. `tools/luts/make_luts.py` makes them, so a look can be tweaked there and rebuilt.

Ctrl+F6 and Ctrl+F5 were picked because Unishade doesn't use them (its keys are Home, F7, Ctrl+F8, Ctrl+F9, Ctrl+F10 and Ctrl+PageUp/PageDown). The keys are read in every app while Unishade runs, so pressing them elsewhere works too.

## Requirements

- Windows, x64
- Unishade installed with its Setup, which installs ReShade **with full add-on support** (`ReShade_Setup_<version>_Addon.exe`). The standard ReShade build refuses add-ons.
- To build: Visual Studio 2022 with **Desktop development with C++**, and CMake 3.20 or newer

## Build

```powershell
cmake -S . -B build -A x64
cmake --build build --config Release
```

The add-on is at `build\Release\CinematicShots.addon64`. CMake downloads the ReShade and Dear ImGui headers it needs and checks their SHA-256.

GitHub Actions also builds it on every push; download `CinematicShots.addon64` from the run's **Artifacts**.

## Install

1. Close Unishade.
2. Copy `CinematicShots.addon64` into Unishade's folder, next to `Unishade.exe` and `dxgi.dll`. Unless you picked another folder in Setup, that's `%LOCALAPPDATA%\Programs\Unishade`.
3. Start Unishade, open its menu, then open ReShade's menu from there. Unishade blocks ReShade's own menu key, so its menu is the way in.
4. The **Add-ons** tab should list **Cinematic Shots**, with a **Cinematic** section further down holding its settings.

If it doesn't show up, check `ReShade.log` in the same folder for the line `Searching for add-ons` and any error after it.

To remove it, delete the file.

### Install the effects

1. Download **CinematicShots-effects** from the same Actions run and unzip it. It has a `Shaders` and a `Textures` folder.
2. Copy both into `reshade-shaders` inside Unishade's folder (`%LOCALAPPDATA%\Programs\Unishade\reshade-shaders`), merging with the folders already there. Unishade's Setup keeps effects you add there when it updates; uninstalling only removes them if you tick the option to delete your settings.
3. In ReShade's **Home** tab, tick **Daily Drive (Cinematic Shots)** for everyday play, or **Cinematic Look (Cinematic Shots)** for filming. Drag Cinematic Look to the bottom of the list, so the grain and bars go over every other effect.
4. Save each into its own preset, and link the filming one to a shot in the shot list if you like.

`tools/fxcheck` builds ReShade 6.8.0's own effect compiler on Linux; CI uses it to check every effect in `shaders/` compiles, and runs the generated code through glslang and spirv-val. CI also checks the LUT images match `tools/luts/make_luts.py`.

## Versions

ReShade checks the add-on API version and the Dear ImGui version an add-on was built with, and refuses an add-on when either doesn't match.

| What | Pinned to | Where |
| --- | --- | --- |
| ReShade headers | `v6.8.0` (`RESHADE_API_VERSION` 20) | `CMakeLists.txt` |
| Dear ImGui header | `v1.92.5-docking` (`IMGUI_VERSION_NUM` 19250) | `CMakeLists.txt` |

These match what Unishade builds against. When ReShade updates its ImGui version, update both pins together with their hashes.

## License

[MIT](LICENSE)
