// Daily Drive: a light, cheap look for just playing, not for filming.
//   1. Contrast-adaptive sharpening, after AMD's FidelityFX CAS: crisper edges without crunchy halos.
//   2. A colour look from our own LUTs (textures/CinematicShots_LUTs.png).
//   3. Vibrance, warmth, contrast and exposure, kept gentle so it stays easy on the eyes for hours.
// One pass and up to eleven texture reads, so it costs very little.
// Part of Cinematic Shots (https://github.com/0xsouldev/cinematic-shots-addon). MIT licence.
// Written for ReShade 6.8 (FX language: https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md).
// Made for SDR output; on an HDR screen the colours will be off.

namespace CinematicShots
{

uniform float Sharpening <
    ui_category = "Sharpening";
    ui_type = "slider";
    ui_label = "Sharpening";
    ui_tooltip = "Makes edges crisper. Flat areas and edges that are already sharp get less, so it doesn't look crunchy.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform int DailyLut <
    ui_category = "Colour";
    ui_type = "combo";
    ui_label = "Look";
    ui_items = "Off\0"
               "Clean daylight\0"
               "Warm evening\0"
               "Cool night\0"
               "Punchy\0"
               "Blockbuster (teal & orange)\0"
               "Golden hour\0"
               "Night chase\0"
               "Bleach bypass (gritty)\0"
               "Vintage film\0";
    ui_tooltip = "Colour looks stored as LUTs in CinematicShots_LUTs.png.\n"
                 "Clean daylight, Warm evening, Cool night and Punchy are made for everyday play.\n"
                 "The rest are the same looks as the Cinematic Look effect.";
> = 1;

uniform float DailyLutStrength <
    ui_category = "Colour";
    ui_type = "slider";
    ui_label = "Look strength";
    ui_min = 0.0; ui_max = 1.0;
> = 0.7;

uniform float Vibrance <
    ui_category = "Colour";
    ui_type = "slider";
    ui_label = "Vibrance";
    ui_tooltip = "Adds colour to dull areas more than to already bright colours, so the sky and grass pop but paint and skin don't go neon.";
    ui_min = -1.0; ui_max = 1.0;
> = 0.15;

uniform float Warmth <
    ui_category = "Colour";
    ui_type = "slider";
    ui_label = "Warmth";
    ui_tooltip = "Left for cooler (bluer), right for warmer (more orange).";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float DailyContrast <
    ui_category = "Colour";
    ui_type = "slider";
    ui_label = "Contrast";
    ui_min = 0.0; ui_max = 1.0;
> = 0.1;

uniform float DailyExposure <
    ui_category = "Colour";
    ui_type = "slider";
    ui_label = "Exposure";
    ui_tooltip = "Brightens or darkens the whole picture, in camera stops.";
    ui_min = -1.0; ui_max = 1.0;
> = 0.0;

uniform float DailyVignette <
    ui_category = "Colour";
    ui_type = "slider";
    ui_label = "Vignette";
    ui_min = 0.0; ui_max = 1.0;
> = 0.0;

// The LUT atlas: each look is a 1024x32 strip (32 tiles of 32x32; red across a tile, green down it, blue picks the
// tile), stacked one per row. tools/luts/make_luts.py makes it; the row order matches the combo above.
#define CINEMATIC_SHOTS_LUT_SIZE 32
#define CINEMATIC_SHOTS_LUT_COUNT 9

static const float3 kDailyLuma = float3(0.2126, 0.7152, 0.0722);

texture DailyBackBufferTex : COLOR;
sampler DailyBackBuffer { Texture = DailyBackBufferTex; };

texture DailyLutTex < source = "CinematicShots_LUTs.png"; >
{
    Width = CINEMATIC_SHOTS_LUT_SIZE * CINEMATIC_SHOTS_LUT_SIZE;
    Height = CINEMATIC_SHOTS_LUT_SIZE * CINEMATIC_SHOTS_LUT_COUNT;
    Format = RGBA8;
};
sampler DailyLutSampler { Texture = DailyLutTex; };

void DailyVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// One screen pixel; neighbours past the edge repeat the edge pixel instead of reading black.
float3 Pixel(int2 pixel)
{
    return tex2Dfetch(DailyBackBuffer, clamp(pixel, int2(0, 0), int2(BUFFER_WIDTH - 1, BUFFER_HEIGHT - 1))).rgb;
}

// Contrast-adaptive sharpening, following AMD FidelityFX CAS (MIT): it looks at the darkest and brightest
// neighbours, sharpens hard where there is room before clipping and gently where there isn't, and uses a
// plus-shaped filter.
float3 Sharpen(int2 pixel)
{
    float3 a = Pixel(pixel + int2(-1, -1));
    float3 b = Pixel(pixel + int2(0, -1));
    float3 c = Pixel(pixel + int2(1, -1));
    float3 d = Pixel(pixel + int2(-1, 0));
    float3 e = Pixel(pixel);
    float3 f = Pixel(pixel + int2(1, 0));
    float3 g = Pixel(pixel + int2(-1, 1));
    float3 h = Pixel(pixel + int2(0, 1));
    float3 i = Pixel(pixel + int2(1, 1));

    // Soft min and max: the plus shape counted twice, the corners once.
    float3 lowest = min(min(min(d, e), min(f, b)), h);
    lowest += min(lowest, min(min(a, c), min(g, i)));
    float3 highest = max(max(max(d, e), max(f, b)), h);
    highest += max(highest, max(max(a, c), max(g, i)));

    float3 amount = sqrt(saturate(min(lowest, 2.0 - highest) / max(highest, 0.0001)));
    float3 weight = -amount / lerp(8.0, 5.0, Sharpening);
    return saturate(((b + d + f + h) * weight + e) / (1.0 + 4.0 * weight));
}

// Trilinear read from one row of the LUT atlas. Each tile is one blue step, so two reads are blended for the
// blue between them; red and green are filtered by the sampler.
float3 ApplyLut(float3 c, int look)
{
    const float size = CINEMATIC_SHOTS_LUT_SIZE;
    c = saturate(c);
    float blue = c.b * (size - 1.0);
    float tile = floor(blue);
    float2 uv;
    uv.x = (c.r * (size - 1.0) + 0.5 + tile * size) / (size * size);
    uv.y = (c.g * (size - 1.0) + 0.5 + look * size) / (size * CINEMATIC_SHOTS_LUT_COUNT);
    float3 lower = tex2D(DailyLutSampler, uv).rgb;
    float3 upper = tex2D(DailyLutSampler, uv + float2(1.0 / size, 0.0)).rgb;
    return lerp(lower, upper, blue - tile);
}

float4 DailyPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 c = Sharpening > 0.0 ? Sharpen(int2(pos.xy)) : tex2D(DailyBackBuffer, texcoord).rgb;

    // Exposure and warmth work on light, so they are applied in linear space.
    float3 lin = pow(max(c, 0.0), 2.2) * exp2(DailyExposure);
    lin *= float3(1.0 + 0.1 * Warmth, 1.0, 1.0 - 0.1 * Warmth);
    c = saturate(pow(max(lin, 0.0), 1.0 / 2.2));

    if (DailyLut > 0)
        c = lerp(c, ApplyLut(c, DailyLut - 1), DailyLutStrength);

    // Vibrance: dull colours (low chroma) get the biggest boost.
    float luma = dot(c, kDailyLuma);
    float chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
    c = luma + (c - luma) * (1.0 + Vibrance * (1.0 - chroma));
    c = saturate(c);

    c = lerp(c, c * c * (3.0 - 2.0 * c), DailyContrast);

    float aspect = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
    float2 fromCentre = (texcoord - 0.5) * float2(aspect, 1.0);
    c *= 1.0 - DailyVignette * 0.8 * smoothstep(0.35, 1.0, length(fromCentre) / length(float2(aspect, 1.0) * 0.5));

    return float4(saturate(c), 1.0);
}

technique DailyDrive <
    ui_label = "Daily Drive (Cinematic Shots)";
    ui_tooltip = "A light, cheap look for everyday play: sharpening, a colour look, vibrance and warmth.\n"
                 "Needs CinematicShots_LUTs.png in reshade-shaders\\Textures.";
>
{
    pass { VertexShader = DailyVS; PixelShader = DailyPS; }
}

}
