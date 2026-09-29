"""Seasonal versions of the detailed sprites, made from the sprites
themselves (no re-render: same size, same camera, so every offset,
footprint and fade rect carries over).

User request: a detailed snowfield and a detailed autumn wood, now that
only the detailed map styles are played.

  snow    snow lies on the faces that look up at the sky: the normal map
          says which (camera space, X right, Y up the screen, Z toward the
          viewer; the world's up is (0, cos 55, sin 55) there), broken into
          drifts by soft noise. Pines, dead and bare trees, rocks, bushes.
  autumn  green leaves turned orange, gold or red (a hue shift of the green
          and yellow-green pixels; bark and flowers untouched). Oaks, leafy
          trees, bushes.

Writes <name>_<season>_55deg_albedo.png beside each source albedo (the
normal map is shared - scripts/derived_art.gd points at the source's).

  python tools/derive_variants.py [--only snow|autumn]
"""
import glob
import math
import os
import sys
import zlib

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")
SEASONS = {
    "snow": ["pine", "dead_tree", "bare_tree", "rock", "bush"],
    "autumn": ["oak_tree", "leafy_tree", "bush"],
}
UP = np.array([0.0, math.cos(math.radians(55.0)), math.sin(math.radians(55.0))])
SNOW = np.array([0.86, 0.9, 0.96])
# Not given a season: the pale yellow-green pines turn all white under
# snow, and snow on flowers looks wrong.
SKIP = {"snow": {"pine_6", "pine_7", "pine_8", "pine_9", "pine_10", "bush_flowers", "plant_big_2"}}
# Autumn hues (degrees), dealt out by sprite so a wood gets a mix.
AUTUMN_HUES = [26.0, 40.0, 10.0, 32.0, 18.0]


def sources(directory):
    for path in sorted(glob.glob(os.path.join(SPRITES, directory, "*_55deg_albedo.png"))):
        name = os.path.basename(path)[:-len("_55deg_albedo.png")]
        if name.endswith("_snow") or name.endswith("_autumn"):
            continue
        yield name, path, path.replace("_albedo.png", "_normal.png")


def soft_noise(seed, size, feature):
    rng = np.random.default_rng(seed)
    img = Image.fromarray((rng.random((size[1], size[0])) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(feature))
    a = np.asarray(img, np.float32)
    return (a - a.min()) / max(a.max() - a.min(), 1e-6)


def snow(name, albedo, normal):
    img = np.asarray(Image.open(albedo).convert("RGBA"), np.float32) / 255.0
    h, w = img.shape[:2]
    nrm = Image.open(normal).convert("RGB").resize((w, h), Image.BILINEAR)
    n = np.asarray(nrm, np.float32) / 255.0 * 2.0 - 1.0
    up = n @ UP
    cover = np.clip((up - 0.72) / 0.18, 0.0, 1.0)
    # Drifts, a few world px across (albedo is 4 texels per world px).
    drift = soft_noise(zlib.crc32(name.encode()), (w, h), 7.0)
    cover *= np.clip((drift - 0.3) / 0.25, 0.0, 1.0)
    rgb = img[..., :3]
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    # The snow keeps a little of the shading underneath.
    solid = img[..., 3] > 0.5
    ref = np.percentile(lum[solid], 90) if solid.any() else 1.0
    shade = 0.8 + 0.3 * np.clip(lum / max(ref, 1e-3), 0.0, 1.0)
    snowy = SNOW[None, None, :] * shade[..., None]
    rgb = rgb * (1.0 - cover[..., None]) + snowy * cover[..., None]
    # The rest a touch colder and paler, as under a winter sky.
    grey = (rgb @ np.array([0.299, 0.587, 0.114]))[..., None]
    rgb = rgb * 0.85 + grey * 0.15
    img[..., :3] = rgb
    return img


def autumn(name, albedo, _normal, hue):
    img = np.asarray(Image.open(albedo).convert("RGBA"), np.float32) / 255.0
    rgb = img[..., :3]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hdeg = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    # Greens and yellow-greens with some colour to them are leaves.
    leaf = np.clip((sat - 0.12) / 0.1, 0, 1) * np.clip(1.0 - np.abs(hdeg - 105.0) / 60.0, 0, 1) ** 0.5
    new_h = (hue + (hdeg - 105.0) * 0.12) / 360.0 % 1.0
    new_s = np.clip(sat * 1.15, 0, 1)
    new_v = np.clip(mx * 1.08, 0, 1)
    # HSV -> RGB, vectorised.
    i = np.floor(new_h * 6).astype(int) % 6
    f = new_h * 6 - np.floor(new_h * 6)
    p, q, t = new_v * (1 - new_s), new_v * (1 - f * new_s), new_v * (1 - (1 - f) * new_s)
    choices = [(new_v, t, p), (q, new_v, p), (p, new_v, t), (p, q, new_v), (t, p, new_v), (new_v, p, q)]
    out = np.zeros_like(rgb)
    for k, (cr, cg, cb) in enumerate(choices):
        m = i == k
        out[..., 0] = np.where(m, cr, out[..., 0])
        out[..., 1] = np.where(m, cg, out[..., 1])
        out[..., 2] = np.where(m, cb, out[..., 2])
    img[..., :3] = rgb * (1 - leaf[..., None]) + out * leaf[..., None]
    return img


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    for season, dirs in SEASONS.items():
        if only and season != only:
            continue
        k = 0
        for directory in dirs:
            for name, albedo, normal in sources(directory):
                if name in SKIP.get(season, ()):
                    continue
                if season == "snow":
                    img = snow(name, albedo, normal)
                else:
                    img = autumn(name, albedo, normal, AUTUMN_HUES[k % len(AUTUMN_HUES)])
                    k += 1
                out = albedo.replace("_55deg_albedo.png", "_%s_55deg_albedo.png" % season)
                Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(out, optimize=True)
                print(season, os.path.relpath(out, SPRITES))


if __name__ == "__main__":
    main()
