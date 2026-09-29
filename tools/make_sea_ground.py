"""The beaches' gravel and sand, from the user's ocean-water pack (the
"Asset2" release, OCEAN+WATER.rar, MAPS/): Pebbles02_4K (ambientCG, CC0)
and aerial_beach_02_4k (Poly Haven, CC0).

User request: look to that pack for the gravel, the rocks and the sand
too - in our style, not its photographic one. So the photos are brought
to the ground textures' size (1024 albedo, 512 normal - make_ground.py's
tile) and painted down: fine detail smoothed away, the colours pulled
into our palette (pale grey and cream stones, warm sand; the pebbles'
dead leaves greyed out), the light and dark eased. The normal maps come
along (the pebbles' is DirectX-style: its green flipped to ours, Y up;
the sand's made from its displacement). soften_ground.py runs on them
afterwards like on the rest.

  python tools/make_sea_ground.py MAPS_DIR
  python tools/soften_ground.py
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

Image.MAX_IMAGE_PIXELS = None
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "ground")
ALBEDO = 1024
NORMAL = 512
LUMA = np.array([0.299, 0.587, 0.114], np.float32)


def load(path, size, mode="RGB"):
    return np.asarray(Image.open(path).convert(mode).resize((size, size), Image.LANCZOS)).astype(np.float32) / 255.0


def save(arr, name):
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, name),
                                                                                   optimize=True)
    print("wrote", name)


def paint_down(rgb, radius):
    """Photo detail smoothed away, edges kept (a median, then a light blur)."""
    img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
    img = img.filter(ImageFilter.MedianFilter(radius)).filter(ImageFilter.GaussianBlur(0.6))
    return np.asarray(img).astype(np.float32) / 255.0


def normal_from_height(h, strength):
    gy, gx = np.gradient(h)
    n = np.stack([-gx * strength, gy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def pebbles(maps):
    rgb = load(os.path.join(maps, "Pebbles02_4K_BaseColor.png"), ALBEDO)
    grey = rgb @ LUMA
    # Dead leaves and rust out: everything toward a pale warm grey.
    sat = rgb - grey[..., None]
    rgb = grey[..., None] + sat * 0.35
    # Ease the contrast, lift toward the pack's sunlit beach stones.
    rgb = 0.2 + (rgb - rgb.mean()) * 0.8 + rgb.mean() * 0.95
    rgb = rgb * np.array([1.04, 1.0, 0.93])
    rgb = paint_down(rgb, 5)
    n = load(os.path.join(maps, "Pebbles02_4K_Normal.png"), NORMAL)
    n[..., 1] = 1.0 - n[..., 1]  # DirectX to ours (Y up)
    save(rgb, "sea_pebbles_albedo.png")
    save(n, "sea_pebbles_normal.png")


def sand(maps):
    rgb = load(os.path.join(maps, "aerial_beach_02_diff_4k.jpg"), ALBEDO)
    grey = rgb @ LUMA
    # Its wind ripples and prints kept as light and shade, the colour ours:
    # the pale warm sand of beach_sand.
    rel = grey / max(grey.mean(), 1e-4)
    # (Softly: the photo's footprints fade to faint dents.)
    rel = 1.0 + (rel - 1.0) * 0.4
    base = np.array([0.74, 0.66, 0.5])
    rgb = paint_down(base[None, None, :] * rel[..., None], 7)
    h = load(os.path.join(maps, "aerial_beach_02_disp_4k.png"), NORMAL, "L")
    h = np.asarray(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))) / 255.0
    save(rgb, "sea_sand_albedo.png")
    save(normal_from_height(h, 10.0), "sea_sand_normal.png")


def main():
    maps = sys.argv[1]
    pebbles(maps)
    sand(maps)


if __name__ == "__main__":
    main()
