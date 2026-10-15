// Cinematic Look: one effect that does the "movie" finishing touches, in the order a film would get them.
//   1. Film glow: halation (the red-orange glow film gets round bright lights) and an anamorphic streak (the
//      horizontal blue flare of widescreen movie lenses).
//   2. A colour grade picked from a short list of well-known looks.
//   3. Lens and film texture: chromatic aberration, vignette and grain.
//   4. Optional black bars, baked into the picture, so screenshots and recordings keep them.
// Part of Cinematic Shots (https://github.com/0xsouldev/cinematic-shots-addon). MIT licence.
// Written for ReShade 6.8 (FX language: https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md).
// Made for SDR output; on an HDR screen the colours will be off.

namespace CinematicShots
{

uniform int Look <
    ui_category = "Colour grade";
    ui_type = "combo";
    ui_label = "Look";
    ui_items = "Neutral (no grade)\0Blockbuster (teal & orange)\0Golden hour\0Night chase\0Bleach bypass (gritty)\0Vintage film\0";
    ui_tooltip = "Blockbuster: cool shadows, warm highlights. Makes cars and skin pop against the background.\n"
                 "Golden hour: the warm light just before sunset.\n"
                 "Night chase: cold blue shadows and hard contrast.\n"
                 "Bleach bypass: washed-out colour and gritty contrast, like a war or heist film.\n"
                 "Vintage film: faded blacks and softer, warmer colour.";
> = 1;

uniform float LookStrength <
    ui_category = "Colour grade";
    ui_type = "slider";
    ui_label = "Look strength";
    ui_min = 0.0; ui_max = 1.0;
> = 0.8;

uniform float Exposure <
    ui_category = "Colour grade";
    ui_type = "slider";
    ui_label = "Exposure";
    ui_tooltip = "Brightens or darkens the whole picture, in camera stops.";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float Halation <
    ui_category = "Film glow";
    ui_type = "slider";
    ui_label = "Halation";
    ui_tooltip = "A soft red-orange glow round bright lights, like on real film. Lovely on headlights, street lights and sunsets.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.35;

uniform float Streak <
    ui_category = "Film glow";
    ui_type = "slider";
    ui_label = "Anamorphic streak";
    ui_tooltip = "A thin horizontal blue flare through bright lights, like a widescreen movie lens.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.25;

uniform float GlowThreshold <
    ui_category = "Film glow";
    ui_type = "slider";
    ui_label = "Glow threshold";
    ui_tooltip = "How bright something must be before it glows. Higher means only the brightest lights glow.";
    ui_min = 0.5; ui_max = 1.0;
> = 0.75;

uniform float GlowSize <
    ui_category = "Film glow";
    ui_type = "slider";
    ui_label = "Glow size";
    ui_min = 0.5; ui_max = 3.0;
> = 1.5;

uniform float Aberration <
    ui_category = "Lens";
    ui_type = "slider";
    ui_label = "Chromatic aberration";
    ui_tooltip = "Colour fringes towards the edges, like a real lens. Keep it subtle.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.15;

uniform float Vignette <
    ui_category = "Lens";
    ui_type = "slider";
    ui_label = "Vignette";
    ui_tooltip = "Darkens the corners so the eye goes to the middle of the frame.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.35;

uniform float Grain <
    ui_category = "Film grain";
    ui_type = "slider";
    ui_label = "Grain";
    ui_tooltip = "Moving film grain. Strongest in the mid-tones, like real film.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.25;

uniform int Letterbox <
    ui_category = "Letterbox";
    ui_type = "combo";
    ui_label = "Black bars";
    ui_items = "Off\0" "2.39:1 Scope (classic film)\0" "2.00:1 Univisium\0" "1.85:1 Flat\0";
    ui_tooltip = "Real black bars, baked into screenshots and recordings.\n"
                 "The Cinematic Shots add-on's guides only show on screen; use these when the bars should be in the picture.";
> = 0;

uniform int FrameCount < source = "framecount"; >;

static const float3 kLumaWeights = float3(0.2126, 0.7152, 0.0722);
static const float2 kPixel = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
static const float2 kGlowPixel = float2(4.0 * BUFFER_RCP_WIDTH, 4.0 * BUFFER_RCP_HEIGHT);

texture BackBufferTex : COLOR;
sampler BackBuffer { Texture = BackBufferTex; };

// The glow is worked out at a quarter of the screen size: it is blurry anyway, and that keeps it cheap.
texture BrightTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture BlurTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture GlowTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture StreakATex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
texture StreakBTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
sampler Bright { Texture = BrightTex; };
sampler Blur { Texture = BlurTex; };
sampler Glow { Texture = GlowTex; };
sampler StreakA { Texture = StreakATex; };
sampler StreakB { Texture = StreakBTex; };

// A full-screen triangle, as in ReShade.fxh.
void FullscreenVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Light adds up in linear space, so glows are mixed there. 2.2 is close enough to sRGB for this.
float3 ToLinear(float3 c) { return pow(max(c, 0.0), 2.2); }
float3 ToGamma(float3 c) { return pow(max(c, 0.0), 1.0 / 2.2); }

// Rolls off light above 0.8 instead of clipping it, so glowing lights keep some colour.
float3 Shoulder(float3 c)
{
    const float k = 0.8;
    float3 over = max(c - k, 0.0);
    return min(c, k) + (1.0 - k) * (1.0 - exp(-over / (1.0 - k)));
}

// Small hash without sin(), so it gives the same grain on every GPU (Dave Hoskins, "Hash without Sine").
float Hash(float2 p)
{
    float3 p3 = frac(p.xyx * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

// Keeps only the light above the threshold, with a soft knee so nothing pops in suddenly.
float4 BrightPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Four taps between pixels average a 4x4 block, so small lights do not flicker as the camera moves.
    float3 c = 0.0;
    c += tex2D(BackBuffer, texcoord + kPixel * float2(-1.0, -1.0)).rgb;
    c += tex2D(BackBuffer, texcoord + kPixel * float2(1.0, -1.0)).rgb;
    c += tex2D(BackBuffer, texcoord + kPixel * float2(-1.0, 1.0)).rgb;
    c += tex2D(BackBuffer, texcoord + kPixel * float2(1.0, 1.0)).rgb;
    float3 lin = ToLinear(c * 0.25);
    float threshold = pow(GlowThreshold, 2.2);
    float amount = saturate((dot(lin, kLumaWeights) - threshold) / max(1.0 - threshold, 0.0001));
    return float4(lin * amount * amount, 1.0);
}

// Gaussian blur, nine taps, run once across and once down.
float3 Gaussian(sampler source, float2 texcoord, float2 direction)
{
    const float weights[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
    float3 sum = tex2D(source, texcoord).rgb * weights[0];
    [unroll]
    for (int i = 1; i < 5; ++i)
    {
        float2 offset = direction * kGlowPixel * GlowSize * i;
        sum += tex2D(source, texcoord + offset).rgb * weights[i];
        sum += tex2D(source, texcoord - offset).rgb * weights[i];
    }
    return sum;
}

float4 BlurAcrossPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(Gaussian(Bright, texcoord, float2(1.0, 0.0)), 1.0);
}

float4 BlurDownPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(Gaussian(Blur, texcoord, float2(0.0, 1.0)), 1.0);
}

// A long, thin horizontal smear. Two passes with growing steps reach far without hundreds of taps.
float3 Smear(sampler source, float2 texcoord, float spacing)
{
    float3 sum = 0.0;
    float total = 0.0;
    [unroll]
    for (int i = -12; i <= 12; ++i)
    {
        float weight = exp(-abs(i) * 0.2);
        sum += tex2D(source, texcoord + float2(kGlowPixel.x * spacing * i, 0.0)).rgb * weight;
        total += weight;
    }
    return sum / total;
}

float4 StreakAPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(Smear(Bright, texcoord, 1.5 * GlowSize), 1.0);
}

float4 StreakBPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(Smear(StreakA, texcoord, 6.0 * GlowSize), 1.0);
}

// The settings behind each look. Shadows and highlights are tinted separately ("split toning"), which is how
// colourists build most of these looks.
void LookSettings(int look, out float3 shadows, out float3 highlights, out float saturation, out float contrast,
                  out float fade, out float bleach)
{
    shadows = 1.0; highlights = 1.0; saturation = 1.0; contrast = 0.0; fade = 0.0; bleach = 0.0;
    if (look == 1) // Blockbuster: teal shadows, orange highlights.
    {
        shadows = float3(0.86, 1.0, 1.10); highlights = float3(1.10, 1.0, 0.86);
        saturation = 1.1; contrast = 0.35;
    }
    else if (look == 2) // Golden hour: warm all over, softly lifted blacks.
    {
        shadows = float3(1.02, 0.98, 0.92); highlights = float3(1.14, 1.02, 0.80);
        saturation = 1.12; contrast = 0.2; fade = 0.03;
    }
    else if (look == 3) // Night chase: cold shadows, hard contrast, less colour.
    {
        shadows = float3(0.82, 0.96, 1.18); highlights = float3(0.95, 1.0, 1.08);
        saturation = 0.85; contrast = 0.45;
    }
    else if (look == 4) // Bleach bypass: silver left in the film, so colour drops and contrast climbs.
    {
        highlights = float3(1.02, 1.0, 0.98);
        saturation = 0.55; contrast = 0.3; bleach = 0.6;
    }
    else if (look == 5) // Vintage film: faded blacks, green-tinged shadows, warm highlights.
    {
        shadows = float3(0.96, 1.02, 1.0); highlights = float3(1.08, 1.02, 0.88);
        saturation = 0.8; contrast = -0.15; fade = 0.06;
    }
}

float3 Grade(float3 c)
{
    float3 shadows, highlights;
    float saturation, contrast, fade, bleach;
    LookSettings(Look, shadows, highlights, saturation, contrast, fade, bleach);

    float luma = dot(c, kLumaWeights);
    float3 graded = c * lerp(shadows, highlights, smoothstep(0.05, 0.85, luma));
    // Tinting should change colour, not brightness.
    graded *= luma / max(dot(graded, kLumaWeights), 0.0001);

    // Bleach bypass lays a black-and-white copy over the colour one ("overlay" blend).
    float3 overlay = lerp(2.0 * luma * graded, 1.0 - 2.0 * (1.0 - luma) * (1.0 - graded), step(0.5, luma));
    graded = lerp(graded, overlay, bleach);

    graded = lerp(dot(graded, kLumaWeights), graded, saturation);
    graded = saturate(graded);
    graded = lerp(graded, graded * graded * (3.0 - 2.0 * graded), contrast); // gentle S-curve
    graded = graded * (1.0 - fade) + fade;
    return lerp(c, graded, LookStrength);
}

// Width over height of the picture inside the bars, or 0 for no bars.
float LetterboxRatio()
{
    if (Letterbox == 1) return 2.39;
    if (Letterbox == 2) return 2.0;
    if (Letterbox == 3) return 1.85;
    return 0.0;
}

float4 FinalPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Chromatic aberration: red and blue land slightly apart, more so towards the edges.
    float2 fromCentre = texcoord - 0.5;
    float2 fringe = fromCentre * Aberration * 0.008;
    float3 c;
    c.r = tex2D(BackBuffer, texcoord - fringe).r;
    c.g = tex2D(BackBuffer, texcoord).g;
    c.b = tex2D(BackBuffer, texcoord + fringe).b;

    float3 lin = ToLinear(c) * exp2(Exposure);
    float3 glow = tex2D(Glow, texcoord).rgb;
    float3 streak = tex2D(StreakB, texcoord).rgb;
    lin += glow * Halation * 0.35;                                                      // soft bloom
    lin += dot(glow, kLumaWeights) * float3(1.0, 0.32, 0.12) * Halation * 1.5;          // red-orange halation
    lin += dot(streak, kLumaWeights) * float3(0.35, 0.6, 1.0) * Streak * 2.5;           // blue anamorphic streak
    c = ToGamma(Shoulder(lin));

    c = Grade(c);

    // Vignette, measured on a circle rather than an oval, so it looks the same on any screen shape.
    float aspect = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
    float radius = length(fromCentre * float2(aspect, 1.0)) / length(float2(aspect, 1.0) * 0.5);
    c *= 1.0 - Vignette * smoothstep(0.35, 1.0, radius) * 0.8;

    // Grain: new every frame, strongest in the mid-tones and faint in deep shadow and bright sky.
    float frame = FrameCount % 1024;
    float noise = Hash(pos.xy + frame * float2(17.0, 59.0)) + Hash(pos.xy + frame * float2(43.0, 11.0)) - 1.0;
    float luma = dot(c, kLumaWeights);
    c += noise * Grain * 0.12 * (0.3 + 2.8 * luma * (1.0 - luma));

    // Black bars last, so nothing glows or grains on top of them.
    float ratio = LetterboxRatio();
    if (ratio > 0.0)
    {
        float2 inside = aspect > ratio ? float2(ratio / aspect, 1.0) : float2(1.0, aspect / ratio);
        float2 edge = (1.0 - inside) * 0.5;
        if (any(texcoord < edge) || any(texcoord > 1.0 - edge))
            c = 0.0;
    }
    return float4(saturate(c), 1.0);
}

technique CinematicLook <
    ui_label = "Cinematic Look (Cinematic Shots)";
    ui_tooltip = "Film glow, a colour grade, lens touches, grain and optional black bars in one effect.\n"
                 "Put it at the bottom of the effect list so the bars and grain go over everything else.";
>
{
    pass Bright { VertexShader = FullscreenVS; PixelShader = BrightPS; RenderTarget = BrightTex; }
    pass BlurAcross { VertexShader = FullscreenVS; PixelShader = BlurAcrossPS; RenderTarget = BlurTex; }
    pass BlurDown { VertexShader = FullscreenVS; PixelShader = BlurDownPS; RenderTarget = GlowTex; }
    pass StreakA { VertexShader = FullscreenVS; PixelShader = StreakAPS; RenderTarget = StreakATex; }
    pass StreakB { VertexShader = FullscreenVS; PixelShader = StreakBPS; RenderTarget = StreakBTex; }
    pass Final { VertexShader = FullscreenVS; PixelShader = FinalPS; }
}

}
