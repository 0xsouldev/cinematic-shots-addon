"""Makes the Cinematic Shots colour LUTs.

A LUT (look-up table) stores a colour grade as a picture: for every input colour it holds the graded colour, so any
grade, however complicated, costs one texture read in the game. ReShade's LUT format is a 1024x32 strip of 32 tiles:
inside a tile red goes left to right and green top to bottom; blue picks the tile. That is the layout of lut.png in
ReShade's standard effects and what LUT.fx reads.

Writes to shaders/../textures/:
  CinematicShots_LUTs.png       every look stacked, one 32-pixel row each, for DailyDrive.fx
  CinematicShots_<Name>.png     each look on its own, for ReShade's LUT.fx or any effect that reads that format

Usage: python3 tools/luts/make_luts.py [--check]   (needs numpy and Pillow)
--check writes nothing and fails if the PNGs in textures/ don't match the looks below (CI runs this).
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 32
LUMA = np.array([0.2126, 0.7152, 0.0722])

# Each look is the same set of controls CinematicLook.fx grades with, so a LUT and the effect agree:
# shadows/highlights: multipliers that tint dark and bright parts ("split toning")
# saturation: 1 keeps colour, below 1 drains it; vibrance: boosts dull colours more than strong ones
# contrast: amount of S-curve; fade: lifts black towards grey; bleach: bleach-bypass overlay amount
# The order matters: DailyDrive.fx's combo box lists them in this order.
LOOKS = [
    ("CleanDaylight", "Clean daylight", dict(shadows=(0.98, 1.0, 1.02), highlights=(1.03, 1.0, 0.97), vibrance=0.25, contrast=0.15)),
    ("WarmEvening", "Warm evening", dict(shadows=(1.0, 0.98, 0.95), highlights=(1.08, 1.01, 0.88), vibrance=0.2, contrast=0.15, fade=0.015)),
    ("CoolNight", "Cool night", dict(shadows=(0.9, 0.98, 1.12), highlights=(0.98, 1.0, 1.04), saturation=0.92, contrast=0.25)),
    ("Punchy", "Punchy", dict(vibrance=0.45, saturation=1.05, contrast=0.35)),
    ("Blockbuster", "Blockbuster (teal & orange)", dict(shadows=(0.86, 1.0, 1.10), highlights=(1.10, 1.0, 0.86), saturation=1.1, contrast=0.35)),
    ("GoldenHour", "Golden hour", dict(shadows=(1.02, 0.98, 0.92), highlights=(1.14, 1.02, 0.80), saturation=1.12, contrast=0.2, fade=0.03)),
    ("NightChase", "Night chase", dict(shadows=(0.82, 0.96, 1.18), highlights=(0.95, 1.0, 1.08), saturation=0.85, contrast=0.45)),
    ("BleachBypass", "Bleach bypass (gritty)", dict(highlights=(1.02, 1.0, 0.98), saturation=0.55, contrast=0.3, bleach=0.6)),
    ("VintageFilm", "Vintage film", dict(shadows=(0.96, 1.02, 1.0), highlights=(1.08, 1.02, 0.88), saturation=0.8, contrast=-0.15, fade=0.06)),
]


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def grade(c, shadows=(1, 1, 1), highlights=(1, 1, 1), saturation=1.0, vibrance=0.0, contrast=0.0, fade=0.0, bleach=0.0):
    """The same steps, in the same order, as Grade() in CinematicLook.fx, plus vibrance."""
    luma = (c @ LUMA)[..., None]
    tint = np.array(shadows) + (np.array(highlights) - np.array(shadows)) * smoothstep(0.05, 0.85, luma)
    g = c * tint
    g *= luma / np.maximum(g @ LUMA, 0.0001)[..., None]

    overlay = np.where(luma < 0.5, 2.0 * luma * g, 1.0 - 2.0 * (1.0 - luma) * (1.0 - g))
    g = g + (overlay - g) * bleach

    gl = (g @ LUMA)[..., None]
    g = gl + (g - gl) * saturation
    if vibrance:
        # How colourful a pixel already is, 0 for grey. Dull colours get most of the boost.
        chroma = (g.max(axis=-1) - g.min(axis=-1))[..., None]
        g = gl + (g - gl) * (1.0 + vibrance * (1.0 - np.clip(chroma, 0.0, 1.0)))

    g = np.clip(g, 0.0, 1.0)
    g = g + (g * g * (3.0 - 2.0 * g) - g) * contrast
    g = g * (1.0 - fade) + fade
    return np.clip(g, 0.0, 1.0)


def identity():
    """The 32x1024 strip that maps every colour to itself, as float RGB in 0..1."""
    steps = np.arange(SIZE) / (SIZE - 1)
    b, g, r = np.meshgrid(steps, steps, steps, indexing="ij")  # [tile][row][column]
    strip = np.stack([r, g, b], axis=-1)  # 32 tiles of 32x32
    return strip.transpose(1, 0, 2, 3).reshape(SIZE, SIZE * SIZE, 3)


def to_png(strip):
    return Image.fromarray(np.round(strip * 255.0).astype(np.uint8), "RGB")


def main():
    check = "--check" in sys.argv[1:]
    out = Path(__file__).resolve().parents[2] / "textures"
    base = identity()
    images = {}
    for file_name, _, settings in LOOKS:
        images[f"CinematicShots_{file_name}.png"] = to_png(grade(base, **settings))
    images["CinematicShots_LUTs.png"] = to_png(np.concatenate([np.asarray(i) / 255.0 for i in images.values()], axis=0))

    if check:
        # Pixels, not bytes, are compared: PNG compression differs between Pillow versions.
        stale = [name for name, image in images.items()
                 if not (out / name).exists() or not np.array_equal(np.asarray(Image.open(out / name).convert("RGB")), np.asarray(image))]
        if stale:
            sys.exit("Out of date, run python3 tools/luts/make_luts.py: " + ", ".join(stale))
        print(f"{len(images)} LUT images match")
        return

    out.mkdir(exist_ok=True)
    for name, image in images.items():
        image.save(out / name, optimize=True)
    print(f"{len(LOOKS)} looks written to {out}")


if __name__ == "__main__":
    main()
