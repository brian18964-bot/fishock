"""One weathered colour for every leafless tree.

User feedback: a map's dead trees came in colours that jumped about - the
dead trees dark blue-grey, half the bare trees a warm orange-brown, the
other half grey-brown. Every leafless shape stays in use; they're all
brought to the grey-brown of bare trees 6-10 (WOOD): each sprite keeps its
own light and shade (its luminance, relative to its mean) and takes that
colour. Rewrites the albedos in place; running it again changes nothing.
Re-derive the snow versions afterwards:

  python tools/weather_dead_trees.py
  python tools/derive_variants.py --only snow
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")
WOOD = np.array([84.0, 76.0, 72.0]) / 255.0  # bare trees 6-10, mean over the opaque pixels
TREES = ["dead_tree/dead_tree_%d" % i for i in range(1, 6)] + ["bare_tree/bare_tree_%d" % i for i in range(1, 6)]
LUMA = np.array([0.2126, 0.7152, 0.0722])


def weather(path):
    img = np.asarray(Image.open(path).convert("RGBA"), np.float32) / 255.0
    rgb, alpha = img[..., :3], img[..., 3]
    luma = rgb @ LUMA
    solid = alpha > 0.5
    rel = luma / max(luma[solid].mean(), 1e-4)
    out = img.copy()
    out[..., :3] = np.clip(WOOD[None, None, :] * rel[..., None], 0.0, 1.0)
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path, optimize=True)


def main():
    for name in TREES:
        path = os.path.join(SPRITES, name + "_55deg_albedo.png")
        weather(path)
        print("weathered", os.path.relpath(path, SPRITES))


if __name__ == "__main__":
    main()
