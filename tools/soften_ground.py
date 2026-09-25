"""Bakes the ground shader's detail softening into the ground albedo images.

shaders/ground.gdshader used to sample every ground texture twice - full
detail and a blurred mip (LOD 2.5) - and mix them 55/45 to calm the tile
pattern under the close camera. That's the same for every pixel, so it's
done here once instead: each albedo becomes 0.55 x itself + 0.45 x its
LOD-2.5 blur (box-downsampled 2^2.5 times, wrapped bilinear back up, as the
GPU's mip would). Performance on phones (user report: the phone ran hot).

Marks each image it softens (a PNG text chunk) and skips marked ones, so
running it again changes nothing.

  python tools/soften_ground.py [assets/sprites/ground]
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, PngImagePlugin

DETAIL = 0.55
LOD = 2.5
MARK = "fishock-softened"


def blurred(img):
    """The texture as its mip at LOD, back at full size (wrapping)."""
    h, w = img.shape[:2]
    small = max(1, int(round(w / 2 ** LOD)))
    sm = np.asarray(Image.fromarray(img).resize((small, small), Image.BOX)).astype(np.float32)
    # Bilinear back up on the torus: pad by one texel each side, wrapped.
    pad = np.concatenate([sm[-1:], sm, sm[:1]], 0)
    pad = np.concatenate([pad[:, -1:], pad, pad[:, :1]], 1)
    ys = (np.arange(h) + 0.5) * small / h - 0.5 + 1.0
    xs = (np.arange(w) + 0.5) * small / w - 0.5 + 1.0
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None, None]
    fx = (xs - x0)[None, :, None]
    a = pad[y0][:, x0]
    b = pad[y0][:, x0 + 1]
    c = pad[y0 + 1][:, x0]
    d = pad[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "assets/sprites/ground"
    for path in sorted(glob.glob(os.path.join(folder, "*_albedo.png"))):
        im = Image.open(path)
        if im.info.get(MARK):
            print("already softened", path)
            continue
        mode = im.mode
        arr = np.asarray(im.convert("RGBA")).astype(np.float32)
        out = arr * DETAIL + blurred(arr.astype(np.uint8)) * (1.0 - DETAIL)
        out[..., 3] = arr[..., 3]
        info = PngImagePlugin.PngInfo()
        info.add_text(MARK, str(DETAIL))
        Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA").convert(mode).save(path, pnginfo=info)
        print("softened", path)


if __name__ == "__main__":
    main()
