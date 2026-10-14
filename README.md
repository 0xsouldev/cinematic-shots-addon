# Cinematic Shots

A ReShade add-on (`.addon64`) for lining up and capturing cinematic shots in Roblox through [Unishade](https://github.com/OMouta/Unishade).

It loads into Unishade's own process, alongside ReShade. Unishade captures the Roblox window with Windows Graphics Capture and runs ReShade on its own window, so nothing here is injected into or reads from the Roblox client.

Right now it only proves the add-on loads: it adds a **Cinematic** tab to ReShade's menu.

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
4. The **Add-ons** tab should list **Cinematic Shots**, and a **Cinematic** tab should appear.

If it doesn't show up, check `ReShade.log` in the same folder for the line `Searching for add-ons` and any error after it.

To remove it, delete the file.

## Versions

ReShade checks the add-on API version and the Dear ImGui version an add-on was built with, and refuses an add-on when either doesn't match.

| What | Pinned to | Where |
| --- | --- | --- |
| ReShade headers | `v6.8.0` (`RESHADE_API_VERSION` 20) | `CMakeLists.txt` |
| Dear ImGui header | `v1.92.5-docking` (`IMGUI_VERSION_NUM` 19250) | `CMakeLists.txt` |

These match what Unishade builds against. When ReShade updates its ImGui version, update both pins together with their hashes.

## License

[MIT](LICENSE)
