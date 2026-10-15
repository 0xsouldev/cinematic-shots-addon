// Photo FX: tricks photographers use on car and night shots, each its own effect you can switch on:
//   Long Exposure     ghosting or light trails, like leaving the shutter open
//   Motion Blur       a rolling shot (background streaks past) or a zoom burst, keeping your car sharp
//   Dreamy Glow       a Black Pro-Mist style diffusion filter: soft glow round highlights
//   Lens Flare        ghosts and a halo from bright lights, like light bouncing inside a lens
//   Light Leak        a warm film light leak drifting in from the edge
//   Tilt-Shift        the miniature look: a sharp band with blur above and below
// Suggested order in ReShade's list: Long Exposure, Motion Blur, Tilt-Shift, Dreamy Glow, Lens Flare, Light Leak,
// then Cinematic Look last.
// Roblox gives ReShade no depth, so the blurs work on screen position, not real distance or movement.
// Part of Cinematic Shots (https://github.com/0xsouldev/cinematic-shots-addon). MIT licence.
// Written for ReShade 6.8 (FX language: https://github.com/crosire/reshade-shaders/blob/slim/REFERENCE.md).
// Made for SDR output; on an HDR screen the colours will be off.

namespace CinematicShots
{

// ---------------------------------------------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------------------------------------------

uniform int ExposureMode <
    ui_category = "Long Exposure";
    ui_type = "combo";
    ui_label = "Mode";
    ui_items = "Light trails (keeps the brightest)\0"
               "Ghosting (blends frames)\0";
    ui_tooltip = "Light trails: headlights and tail lights leave streaks, like a night photo with the shutter open.\n"
                 "Ghosting: moving things leave see-through copies of themselves.\n"
                 "Hold the camera still for the best result.";
> = 0;

uniform float TrailLength <
    ui_category = "Long Exposure";
    ui_type = "slider";
    ui_label = "Trail length";
    ui_min = 0.0; ui_max = 1.0;
> = 0.6;

uniform float ExposureMix <
    ui_category = "Long Exposure";
    ui_type = "slider";
    ui_label = "Strength";
    ui_min = 0.0; ui_max = 1.0;
> = 1.0;

uniform int BlurMode <
    ui_category = "Motion Blur";
    ui_type = "combo";
    ui_label = "Mode";
    ui_items = "Rolling shot (sideways streaks)\0"
               "Zoom burst (streaks from the middle out)\0";
    ui_tooltip = "Rolling shot: what car photographers get shooting from another car at the same speed.\n"
                 "Zoom burst: like zooming the lens during the shot.";
> = 0;

uniform int SharpSquare <
    ui_category = "Motion Blur";
    ui_type = "combo";
    ui_label = "Keep sharp";
    ui_items = "Square 1\0Square 2\0Square 3\0Square 4\0Square 5 (middle)\0Square 6\0Square 7\0Square 8\0Square 9\0";
    ui_tooltip = "Where your car is, using the add-on's numbered squares (1 2 3 on top, 7 8 9 at the bottom).\n"
                 "There's no depth in Roblox, so the effect can't find the car itself: it keeps this spot sharp.";
> = 4;

uniform float SharpSize <
    ui_category = "Motion Blur";
    ui_type = "slider";
    ui_label = "Sharp area size";
    ui_min = 0.05; ui_max = 0.8;
> = 0.25;

uniform float BlurStrength <
    ui_category = "Motion Blur";
    ui_type = "slider";
    ui_label = "Strength";
    ui_min = 0.0; ui_max = 1.0;
> = 0.5;

uniform float MistStrength <
    ui_category = "Dreamy Glow";
    ui_type = "slider";
    ui_label = "Strength";
    ui_tooltip = "1/4 is subtle, like a Black Pro-Mist 1/4 filter; higher gets dreamier.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.3;

uniform float MistSpread <
    ui_category = "Dreamy Glow";
    ui_type = "slider";
    ui_label = "Spread";
    ui_min = 0.5; ui_max = 3.0;
> = 1.5;

uniform float MistWarmth <
    ui_category = "Dreamy Glow";
    ui_type = "slider";
    ui_label = "Glow warmth";
    ui_min = 0.0; ui_max = 1.0;
> = 0.3;

uniform float FlareStrength <
    ui_category = "Lens Flare";
    ui_type = "slider";
    ui_label = "Strength";
    ui_min = 0.0; ui_max = 1.0;
> = 0.4;

uniform float FlareThreshold <
    ui_category = "Lens Flare";
    ui_type = "slider";
    ui_label = "Threshold";
    ui_tooltip = "How bright a light must be to flare. Higher means only the sun and headlights.";
    ui_min = 0.6; ui_max = 1.0;
> = 0.85;

uniform float FlareHalo <
    ui_category = "Lens Flare";
    ui_type = "slider";
    ui_label = "Halo";
    ui_tooltip = "A faint ring round the middle of the frame.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.4;

uniform int LeakSide <
    ui_category = "Light Leak";
    ui_type = "combo";
    ui_label = "Comes from";
    ui_items = "Left\0Right\0Top left\0Top right\0";
> = 2;

uniform float LeakStrength <
    ui_category = "Light Leak";
    ui_type = "slider";
    ui_label = "Strength";
    ui_min = 0.0; ui_max = 1.0;
> = 0.4;

uniform bool LeakDrift <
    ui_category = "Light Leak";
    ui_label = "Drift slowly";
> = true;

uniform float TiltFocus <
    ui_category = "Tilt-Shift";
    ui_type = "slider";
    ui_label = "Sharp band position";
    ui_tooltip = "0 is the top of the screen, 1 the bottom.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.6;

uniform float TiltWidth <
    ui_category = "Tilt-Shift";
    ui_type = "slider";
    ui_label = "Sharp band size";
    ui_min = 0.02; ui_max = 0.5;
> = 0.12;

uniform float TiltBlur <
    ui_category = "Tilt-Shift";
    ui_type = "slider";
    ui_label = "Blur";
    ui_min = 0.0; ui_max = 1.0;
> = 0.7;

uniform float TiltSaturation <
    ui_category = "Tilt-Shift";
    ui_type = "slider";
    ui_label = "Toy colours";
    ui_tooltip = "Extra colour: miniatures look painted.";
    ui_min = 0.0; ui_max = 1.0;
> = 0.3;

uniform float PhotoFrameTime < source = "frametime"; >;
uniform float PhotoTimer < source = "timer"; >;

// ---------------------------------------------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------------------------------------------

static const float3 kPhotoLuma = float3(0.2126, 0.7152, 0.0722);
static const float kAspect = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;

texture PhotoBackBufferTex : COLOR;
sampler PhotoBackBuffer { Texture = PhotoBackBufferTex; };

void PhotoVS(in uint id : SV_VertexID, out float4 position : SV_Position, out float2 texcoord : TEXCOORD)
{
    texcoord.x = (id == 2) ? 2.0 : 0.0;
    texcoord.y = (id == 1) ? 2.0 : 0.0;
    position = float4(texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

// Light adds up in linear space; 2.2 is close enough to sRGB here.
float3 Linear(float3 c) { return pow(max(c, 0.0), 2.2); }
float3 Gamma(float3 c) { return pow(saturate(c), 1.0 / 2.2); }

// Nine-tap gaussian blur, used across then down.
float3 PhotoGaussian(sampler source, float2 texcoord, float2 step)
{
    const float weights[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };
    float3 sum = tex2D(source, texcoord).rgb * weights[0];
    [unroll]
    for (int i = 1; i < 5; ++i)
    {
        sum += tex2D(source, texcoord + step * i).rgb * weights[i];
        sum += tex2D(source, texcoord - step * i).rgb * weights[i];
    }
    return sum;
}

// ---------------------------------------------------------------------------------------------------------------
// Long Exposure: keeps a running picture of past frames. Textures keep their contents between frames, so the
// result of one frame is copied to a history texture and blended with the next.
// ---------------------------------------------------------------------------------------------------------------

texture ExposureTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
texture ExposureHistoryTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler Exposure { Texture = ExposureTex; };
sampler ExposureHistory { Texture = ExposureHistoryTex; };

float4 ExposureAccumulatePS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 current = Linear(tex2D(PhotoBackBuffer, texcoord).rgb);
    float3 history = tex2D(ExposureHistory, texcoord).rgb;
    // How much of the past survives each frame, scaled by frame time so trails are as long at 30 or 240 FPS.
    float keep = pow(lerp(0.8, 0.99, TrailLength), clamp(PhotoFrameTime, 1.0, 100.0) / 16.667);
    float3 result = ExposureMode == 0 ? max(current, history * keep) : lerp(current, history, keep);
    return float4(result, 1.0);
}

float4 ExposureStorePS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2D(Exposure, texcoord);
}

float4 ExposureShowPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 current = tex2D(PhotoBackBuffer, texcoord).rgb;
    return float4(lerp(current, Gamma(tex2D(Exposure, texcoord).rgb), ExposureMix), 1.0);
}

technique PhotoLongExposure <
    ui_label = "Long Exposure (Cinematic Shots)";
    ui_tooltip = "Light trails or ghosting, like leaving the shutter open. Best with the camera held still.";
>
{
    pass Accumulate { VertexShader = PhotoVS; PixelShader = ExposureAccumulatePS; RenderTarget = ExposureTex; }
    pass Store { VertexShader = PhotoVS; PixelShader = ExposureStorePS; RenderTarget = ExposureHistoryTex; }
    pass Show { VertexShader = PhotoVS; PixelShader = ExposureShowPS; }
}

// ---------------------------------------------------------------------------------------------------------------
// Motion Blur: averages the picture along a line. The further from the sharp spot, the longer the line.
// ---------------------------------------------------------------------------------------------------------------

float4 MotionBlurPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    // Centre of the chosen square; squares go 1 2 3 / 4 5 6 / 7 8 9 like the add-on's grid.
    float2 centre = float2(SharpSquare % 3 + 0.5, SharpSquare / 3 + 0.5) / 3.0;
    float2 offset = texcoord - centre;
    float fromSharp = length(offset * float2(kAspect, 1.0));
    float amount = smoothstep(SharpSize, SharpSize + 0.35, fromSharp) * BlurStrength;

    // Rolling shot: a sideways line centred on the pixel. Zoom burst: a line pointing at the sharp spot.
    float2 streak = BlurMode == 0 ? float2(0.08 * amount, 0.0) : -offset * 0.3 * amount;
    float2 start = BlurMode == 0 ? texcoord - streak * 0.5 : texcoord;

    float3 sum = 0.0;
    [unroll]
    for (int i = 0; i < 24; ++i)
        sum += Linear(tex2Dlod(PhotoBackBuffer, float4(start + streak * (i / 23.0), 0.0, 0.0)).rgb);
    return float4(Gamma(sum / 24.0), 1.0);
}

technique PhotoMotionBlur <
    ui_label = "Motion Blur (Cinematic Shots)";
    ui_tooltip = "A rolling shot or zoom burst that keeps one square of the frame sharp. Put your car there.";
>
{
    pass { VertexShader = PhotoVS; PixelShader = MotionBlurPS; }
}

// ---------------------------------------------------------------------------------------------------------------
// Dreamy Glow: a Black Pro-Mist filter scatters a little of the bright light, so highlights bloom and the picture
// softens without going blurry. Here: a soft highlight pass, blurred at quarter size, added back on.
// ---------------------------------------------------------------------------------------------------------------

texture MistATex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture MistBTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture MistCTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
sampler MistA { Texture = MistATex; };
sampler MistB { Texture = MistBTex; };
sampler MistC { Texture = MistCTex; };

float4 MistPrefilterPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 px = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
    float3 c = 0.0;
    c += Linear(tex2D(PhotoBackBuffer, texcoord + px * float2(-1.0, -1.0)).rgb);
    c += Linear(tex2D(PhotoBackBuffer, texcoord + px * float2(1.0, -1.0)).rgb);
    c += Linear(tex2D(PhotoBackBuffer, texcoord + px * float2(-1.0, 1.0)).rgb);
    c += Linear(tex2D(PhotoBackBuffer, texcoord + px * float2(1.0, 1.0)).rgb);
    c *= 0.25;
    // Mostly the bright parts glow, but softly: no hard threshold, unlike a bloom.
    return float4(c * smoothstep(0.05, 0.6, dot(c, kPhotoLuma)), 1.0);
}

float4 MistAcrossPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(PhotoGaussian(MistA, texcoord, float2(4.0 * BUFFER_RCP_WIDTH * MistSpread, 0.0)), 1.0);
}

float4 MistDownPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return float4(PhotoGaussian(MistB, texcoord, float2(0.0, 4.0 * BUFFER_RCP_HEIGHT * MistSpread)), 1.0);
}

float4 MistCompositePS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 lin = Linear(tex2D(PhotoBackBuffer, texcoord).rgb);
    float3 glow = tex2D(MistC, texcoord).rgb * lerp(1.0, float3(1.1, 0.95, 0.8), MistWarmth);
    // The filter also lifts the blacks a touch and takes the edge off contrast.
    lin = lin * (1.0 - 0.15 * MistStrength) + glow * MistStrength * 1.5 + 0.004 * MistStrength;
    return float4(Gamma(lin), 1.0);
}

technique PhotoDreamyGlow <
    ui_label = "Dreamy Glow (Cinematic Shots)";
    ui_tooltip = "A soft glow round highlights, like a Black Pro-Mist filter on the lens.";
>
{
    pass Prefilter { VertexShader = PhotoVS; PixelShader = MistPrefilterPS; RenderTarget = MistATex; }
    pass Across { VertexShader = PhotoVS; PixelShader = MistAcrossPS; RenderTarget = MistBTex; }
    pass Down { VertexShader = PhotoVS; PixelShader = MistDownPS; RenderTarget = MistCTex; }
    pass Composite { VertexShader = PhotoVS; PixelShader = MistCompositePS; }
}

// ---------------------------------------------------------------------------------------------------------------
// Lens Flare: in a real lens, light bounces between the glass elements and lands as "ghosts" on a line through the
// middle of the frame, opposite the light. This mirrors bright spots through the centre, several times at different
// distances, with colour fringes and a halo ring ("pseudo lens flare", after John Chapman's write-up).
// ---------------------------------------------------------------------------------------------------------------

texture FlareBrightTex { Width = BUFFER_WIDTH / 4; Height = BUFFER_HEIGHT / 4; Format = RGBA16F; };
texture FlareGhostTex { Width = BUFFER_WIDTH / 8; Height = BUFFER_HEIGHT / 8; Format = RGBA16F; };
sampler FlareBright { Texture = FlareBrightTex; };
sampler FlareGhost { Texture = FlareGhostTex; };

float4 FlareBrightPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 lin = Linear(tex2D(PhotoBackBuffer, texcoord).rgb);
    float threshold = pow(FlareThreshold, 2.2);
    float amount = saturate((dot(lin, kPhotoLuma) - threshold) / max(1.0 - threshold, 0.0001));
    return float4(lin * amount, 1.0);
}

// Reads the bright pass with red and blue slightly apart along the flare line, like a real lens's colour fringes.
float3 FlareSample(float2 texcoord, float2 direction)
{
    float2 fringe = direction * 0.012;
    return float3(tex2D(FlareBright, texcoord + fringe).r, tex2D(FlareBright, texcoord).g, tex2D(FlareBright, texcoord - fringe).b);
}

float4 FlareGhostPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float2 flipped = 1.0 - texcoord;
    float2 toCentre = (0.5 - flipped) * 0.35;
    float2 direction = normalize(toCentre + 0.0001);
    float3 result = 0.0;

    [unroll]
    for (int i = 0; i < 5; ++i)
    {
        float2 at = frac(flipped + toCentre * i);
        // Ghosts fade towards the edge of the frame, like real ones.
        float weight = pow(1.0 - saturate(length(0.5 - at) / 0.7071), 6.0);
        result += FlareSample(at, direction) * weight;
    }

    // Halo: a ring at a fixed distance from the centre, faded at the frame edge.
    float2 haloAt = flipped + direction * 0.45;
    float haloWeight = pow(1.0 - saturate(length(0.5 - frac(haloAt)) / 0.7071), 8.0);
    result += FlareSample(haloAt, direction) * haloWeight * FlareHalo * 2.0;

    // A gentle rainbow tint, stronger towards the edge of the frame.
    float edge = saturate(length(texcoord - 0.5) * 2.0);
    float3 tint = lerp(float3(1.0, 1.0, 1.0), float3(0.8, 0.9, 1.25), edge);
    return float4(result * tint, 1.0);
}

float4 FlareCompositePS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 lin = Linear(tex2D(PhotoBackBuffer, texcoord).rgb);
    // Four reads around the pixel soften the low-resolution ghosts.
    float2 px = float2(8.0 * BUFFER_RCP_WIDTH, 8.0 * BUFFER_RCP_HEIGHT) * 0.5;
    float3 flare = tex2D(FlareGhost, texcoord + px * float2(-1.0, -1.0)).rgb + tex2D(FlareGhost, texcoord + px * float2(1.0, -1.0)).rgb
                 + tex2D(FlareGhost, texcoord + px * float2(-1.0, 1.0)).rgb + tex2D(FlareGhost, texcoord + px * float2(1.0, 1.0)).rgb;
    lin += flare * 0.25 * FlareStrength * 3.0;
    return float4(Gamma(lin), 1.0);
}

technique PhotoLensFlare <
    ui_label = "Lens Flare (Cinematic Shots)";
    ui_tooltip = "Ghosts and a halo from bright lights, like light bouncing around inside a camera lens.";
>
{
    pass Bright { VertexShader = PhotoVS; PixelShader = FlareBrightPS; RenderTarget = FlareBrightTex; }
    pass Ghosts { VertexShader = PhotoVS; PixelShader = FlareGhostPS; RenderTarget = FlareGhostTex; }
    pass Composite { VertexShader = PhotoVS; PixelShader = FlareCompositePS; }
}

// ---------------------------------------------------------------------------------------------------------------
// Light Leak: on film cameras, light sneaking past a worn seal fogs the edge of the film warm orange and red.
// ---------------------------------------------------------------------------------------------------------------

float4 LightLeakPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 c = tex2D(PhotoBackBuffer, texcoord).rgb;
    float2 anchor = LeakSide == 0 ? float2(-0.1, 0.5) : LeakSide == 1 ? float2(1.1, 0.5) : LeakSide == 2 ? float2(-0.05, -0.05) : float2(1.05, -0.05);
    // Slow drift: the leak wanders a little, about once every twenty seconds.
    float t = LeakDrift ? PhotoTimer * 0.0003 : 0.0;
    anchor += float2(sin(t), cos(t * 1.3)) * 0.08;

    float2 offset = (texcoord - anchor) * float2(kAspect, 1.0);
    float glow = exp(-dot(offset, offset) * 3.5);
    float3 colour = lerp(float3(1.0, 0.25, 0.1), float3(1.0, 0.7, 0.3), saturate(glow * 1.5));
    float3 leak = colour * glow * LeakStrength;
    // Screen blend: brightens like extra light on the film, never past white.
    return float4(1.0 - (1.0 - c) * (1.0 - leak), 1.0);
}

technique PhotoLightLeak <
    ui_label = "Light Leak (Cinematic Shots)";
    ui_tooltip = "A warm film light leak drifting in from the edge.";
>
{
    pass { VertexShader = PhotoVS; PixelShader = LightLeakPS; }
}

// ---------------------------------------------------------------------------------------------------------------
// Tilt-Shift: a tilted lens puts only a thin band in focus, which our eyes read as a tiny model. The picture is
// copied with mipmaps (smaller and smaller blurred copies), and each pixel reads a blurrier copy the further it is
// from the band.
// ---------------------------------------------------------------------------------------------------------------

texture TiltTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; MipLevels = 6; };
sampler Tilt { Texture = TiltTex; };

float4 TiltCopyPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2D(PhotoBackBuffer, texcoord);
}

float4 TiltShiftPS(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float away = abs(texcoord.y - TiltFocus);
    float lod = smoothstep(TiltWidth * 0.5, TiltWidth * 0.5 + 0.25, away) * TiltBlur * 5.0;

    // Four reads spread by the blur size smooth out the blocky small mipmaps.
    float2 spread = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * exp2(lod) * 0.5;
    float3 c = 0.0;
    c += tex2Dlod(Tilt, float4(texcoord + spread * float2(-1.0, -1.0), 0.0, lod)).rgb;
    c += tex2Dlod(Tilt, float4(texcoord + spread * float2(1.0, -1.0), 0.0, lod)).rgb;
    c += tex2Dlod(Tilt, float4(texcoord + spread * float2(-1.0, 1.0), 0.0, lod)).rgb;
    c += tex2Dlod(Tilt, float4(texcoord + spread * float2(1.0, 1.0), 0.0, lod)).rgb;
    c *= 0.25;

    float luma = dot(c, kPhotoLuma);
    c = saturate(luma + (c - luma) * (1.0 + TiltSaturation));
    return float4(c, 1.0);
}

technique PhotoTiltShift <
    ui_label = "Tilt-Shift (Cinematic Shots)";
    ui_tooltip = "The miniature look: one sharp band, blur above and below. Works best looking down on a scene.";
>
{
    pass Copy { VertexShader = PhotoVS; PixelShader = TiltCopyPS; RenderTarget = TiltTex; }
    pass Blur { VertexShader = PhotoVS; PixelShader = TiltShiftPS; }
}

}
