// Cinematic Shots: a ReShade add-on loaded by ReShade inside Unishade's process. It never touches the Roblox client.

// reshade.hpp only declares ReShade's ImGui functions when imgui.h comes first, and reshade_overlay.hpp checks that
// ImTextureID is 64-bit.
#define ImTextureID ImU64
#include <imgui.h>
#include <reshade.hpp>

#include <iterator>

// Shown in ReShade's add-on list.
extern "C" __declspec(dllexport) const char* NAME = "Cinematic Shots";
extern "C" __declspec(dllexport) const char* DESCRIPTION = "Cinematic tools for capturing shots through Unishade.";

namespace
{
constexpr const char* kSection = "CINEMATIC_SHOTS";

struct AspectRatio
{
    const char* name;
    float ratio;
};

constexpr AspectRatio kRatios[] = {
    { "2.39:1 Scope (classic film)", 2.39f },
    { "2.00:1 Univisium", 2.0f },
    { "1.85:1 Flat", 1.85f },
    { "16:9 Widescreen", 16.0f / 9.0f },
    { "4:3 Classic TV", 4.0f / 3.0f },
    { "9:16 Vertical (Shorts, TikTok)", 9.0f / 16.0f },
};

struct Settings
{
    bool guides = true;
    bool letterbox = true;
    bool thirds = true;
    bool numbers = false;
    int ratio = 0;
    int barOpacity = 100; // percent
};

Settings settings;
bool loaded = false;
bool hotkeyWasDown = false;

void Load()
{
    reshade::get_config_value(nullptr, kSection, "Guides", settings.guides);
    reshade::get_config_value(nullptr, kSection, "Letterbox", settings.letterbox);
    reshade::get_config_value(nullptr, kSection, "Thirds", settings.thirds);
    reshade::get_config_value(nullptr, kSection, "Numbers", settings.numbers);
    reshade::get_config_value(nullptr, kSection, "AspectRatio", settings.ratio);
    reshade::get_config_value(nullptr, kSection, "BarOpacity", settings.barOpacity);
    if (settings.ratio < 0 || settings.ratio >= static_cast<int>(std::size(kRatios)))
        settings.ratio = 0;
    if (settings.barOpacity < 0 || settings.barOpacity > 100)
        settings.barOpacity = 100;
    loaded = true;
}

void Save()
{
    reshade::set_config_value(nullptr, kSection, "Guides", settings.guides);
    reshade::set_config_value(nullptr, kSection, "Letterbox", settings.letterbox);
    reshade::set_config_value(nullptr, kSection, "Thirds", settings.thirds);
    reshade::set_config_value(nullptr, kSection, "Numbers", settings.numbers);
    reshade::set_config_value(nullptr, kSection, "AspectRatio", settings.ratio);
    reshade::set_config_value(nullptr, kSection, "BarOpacity", settings.barOpacity);
}

// Ctrl+F6 shows or hides the guides. Unishade's own keys are Home, F7, Ctrl+F8, Ctrl+F9, Ctrl+F10 and Ctrl+PageUp/Down.
// The game window has focus while playing, not Unishade's, so the key state is read directly instead of from ReShade.
void PollHotkey()
{
    const bool down = (GetAsyncKeyState(VK_CONTROL) & 0x8000) && (GetAsyncKeyState(VK_F6) & 0x8000);
    if (down && !hotkeyWasDown)
    {
        settings.guides = !settings.guides;
        Save();
    }
    hotkeyWasDown = down;
}

// Runs every frame after the effects. The background draw list sits under every ImGui window, so menus stay readable.
// Unishade takes its screenshots before this is drawn, so the guides never end up in them.
void DrawGuides(reshade::api::effect_runtime*)
{
    if (!loaded)
        Load();
    PollHotkey();
    if (!settings.guides || (!settings.letterbox && !settings.thirds))
        return;

    const ImVec2 screen = ImGui::GetIO().DisplaySize;
    if (screen.x <= 0.0f || screen.y <= 0.0f)
        return;
    ImDrawList* draw = ImGui::GetBackgroundDrawList();

    // The framed area: the largest rectangle of the chosen ratio that fits, centred.
    const float ratio = kRatios[settings.ratio].ratio;
    ImVec2 min(0.0f, 0.0f), max = screen;
    if (screen.x / screen.y > ratio)
    {
        const float bar = (screen.x - screen.y * ratio) / 2.0f;
        min.x = bar;
        max.x = screen.x - bar;
    }
    else
    {
        const float bar = (screen.y - screen.x / ratio) / 2.0f;
        min.y = bar;
        max.y = screen.y - bar;
    }

    if (settings.letterbox)
    {
        const ImU32 black = IM_COL32(0, 0, 0, settings.barOpacity * 255 / 100);
        if (min.y > 0.0f)
        {
            draw->AddRectFilled(ImVec2(0.0f, 0.0f), ImVec2(screen.x, min.y), black);
            draw->AddRectFilled(ImVec2(0.0f, max.y), screen, black);
        }
        if (min.x > 0.0f)
        {
            draw->AddRectFilled(ImVec2(0.0f, 0.0f), ImVec2(min.x, screen.y), black);
            draw->AddRectFilled(ImVec2(max.x, 0.0f), screen, black);
        }
    }

    if (settings.thirds)
    {
        const ImU32 line = IM_COL32(255, 255, 255, 110);
        const float width = max.x - min.x, height = max.y - min.y;
        for (int i = 1; i <= 2; ++i)
        {
            const float x = min.x + width * i / 3.0f;
            const float y = min.y + height * i / 3.0f;
            draw->AddLine(ImVec2(x, min.y), ImVec2(x, max.y), line, 1.0f);
            draw->AddLine(ImVec2(min.x, y), ImVec2(max.x, y), line, 1.0f);
        }

        // Squares numbered 1 to 9 like a phone keypad: left to right, top to bottom.
        if (settings.numbers)
        {
            for (int row = 0; row < 3; ++row)
                for (int col = 0; col < 3; ++col)
                {
                    const char label[2] = { static_cast<char>('1' + row * 3 + col), '\0' };
                    const ImVec2 pos(min.x + width * col / 3.0f + 8.0f, min.y + height * row / 3.0f + 6.0f);
                    draw->AddText(ImVec2(pos.x + 1.0f, pos.y + 1.0f), IM_COL32(0, 0, 0, 160), label);
                    draw->AddText(pos, IM_COL32(255, 255, 255, 200), label);
                }
        }
    }
}

void DrawCinematicTab(reshade::api::effect_runtime*)
{
    if (!loaded)
        Load();
    bool changed = false;

    changed |= ImGui::Checkbox("Show guides (Ctrl+F6)", &settings.guides);
    ImGui::BeginDisabled(!settings.guides);
    changed |= ImGui::Checkbox("Letterbox bars", &settings.letterbox);
    ImGui::SameLine();
    changed |= ImGui::Checkbox("Rule-of-thirds lines", &settings.thirds);
    ImGui::SameLine();
    ImGui::BeginDisabled(!settings.thirds);
    changed |= ImGui::Checkbox("Number the squares", &settings.numbers);
    ImGui::EndDisabled();

    if (ImGui::BeginCombo("Aspect ratio", kRatios[settings.ratio].name))
    {
        for (int i = 0; i < static_cast<int>(std::size(kRatios)); ++i)
            if (ImGui::Selectable(kRatios[i].name, i == settings.ratio))
            {
                settings.ratio = i;
                changed = true;
            }
        ImGui::EndCombo();
    }
    changed |= ImGui::SliderInt("Bar opacity", &settings.barOpacity, 0, 100, "%d%%");
    ImGui::EndDisabled();

    ImGui::Spacing();
    ImGui::TextDisabled("Tip: put the car on a line or where two lines cross, with space ahead of it.");
    ImGui::TextDisabled("Guides are for framing only and are not in Unishade's screenshots.");

    if (changed)
        Save();
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
        reshade::register_event<reshade::addon_event::reshade_overlay>(DrawGuides);
        reshade::register_overlay("Cinematic", DrawCinematicTab);
        break;
    case DLL_PROCESS_DETACH:
        reshade::unregister_addon(module);
        break;
    }
    return TRUE;
}
