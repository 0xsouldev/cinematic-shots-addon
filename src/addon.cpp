// Cinematic Shots: a ReShade add-on loaded by ReShade inside Unishade's process. It never touches the Roblox client.

// reshade.hpp only declares ReShade's ImGui functions when imgui.h comes first, and reshade_overlay.hpp checks that
// ImTextureID is 64-bit.
#define ImTextureID ImU64
#include <imgui.h>
#include <reshade.hpp>

// Shown in ReShade's add-on list.
extern "C" __declspec(dllexport) const char* NAME = "Cinematic Shots";
extern "C" __declspec(dllexport) const char* DESCRIPTION = "Cinematic tools for capturing shots through Unishade.";

namespace
{
void DrawCinematicTab(reshade::api::effect_runtime*)
{
    ImGui::TextUnformatted("Cinematic Shots is loaded.");
    ImGui::TextDisabled("Version 0.1.0");
}
} // namespace

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    switch (reason)
    {
    case DLL_PROCESS_ATTACH:
        // Fails when ReShade is missing, has no full add-on support, or exports a different ImGui version.
        if (!reshade::register_addon(module))
            return FALSE;
        reshade::register_overlay("Cinematic", DrawCinematicTab);
        break;
    case DLL_PROCESS_DETACH:
        reshade::unregister_addon(module);
        break;
    }
    return TRUE;
}
