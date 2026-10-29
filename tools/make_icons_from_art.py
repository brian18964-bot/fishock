"""The talents' and abilities' icons, from the user's flat-colour sheet
(Fishing_Talent_Icons.zip: 15 PNGs, a glyph on a dark tile), put into our own
medallion: the tile's dark ground keyed out, the glyph scaled (never past the
circle - every opaque pixel within GLYPH_R of the centre), set on a dark ground
tinted to its colour, under the gold rim of the older icons. The 狠角色 and the cat stay
ours (art_src/icons/tough.svg, rasterised first - see below).

  godot --headless --path . -s tools/raster_svg.gd -- art_src/icons/tough.svg /tmp/tough.png 256
  godot --headless --path . -s tools/raster_svg.gd -- art_src/icons/cat.svg /tmp/cat.png 256
  python3 tools/make_icons_from_art.py ART_DIR /tmp/tough.png /tmp/cat.png      (repo root; ART_DIR holds the PNGs)

Writes assets/ui/talents/<id>.png and assets/ui/abilities/<kind>.png (256 px).
The user's own files stay out of the repo.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = 512          # drawn at this size, saved at SAVE
SAVE = 256
BG_KEY = np.array([28.0, 37.0, 42.0])
GLYPH_R = 0.80     # share of the inner circle the glyph may reach

# id: (where, ground centre, ground edge) - the ground tinted to the glyph
ICONS = {
    "reflex": ("talents", "#5a2a30", "#14070a"), "weights": ("talents", "#2a3c5a", "#070c18"),
    "leak": ("talents", "#1e4a56", "#04141a"), "grit": ("talents", "#5a3a1c", "#150c04"),
    "lucky": ("talents", "#1d4a2c", "#04120a"), "veteran": ("talents", "#2a3a50", "#070c14"),
    "mood": ("talents", "#5a2a30", "#14070a"),
    "owl": ("abilities", "#1d3352", "#060b16"),
    "dog": ("abilities", "#4a3a1e", "#140f06"), "bear": ("abilities", "#6a2a1a", "#1c0806"),
    "deer": ("abilities", "#1e4a26", "#061408"), "sheep": ("abilities", "#5a5232", "#18160a"),
    "croc": ("abilities", "#14455a", "#04121a"),
}


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)


def key_out(img):
    """The glyph with the tile's ground made clear (RGBA float 0..1): the ground
    is whatever near the tile's colour touches the edge - so a dark thing inside a
    glyph (a nose, a pupil) stays."""
    from scipy import ndimage
    a = np.asarray(img.convert("RGB"), dtype=np.float32)
    h, w = a.shape[:2]
    m = 12                      # (the tile's own rounded border: inset)
    a = a[m:h - m, m:w - m]
    d = np.sqrt(((a - BG_KEY) ** 2).sum(axis=2))
    near = d < 30.0
    labels, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    ground = np.isin(labels, list(edge))
    # (a soft edge: the ground mask grown a pixel and blurred)
    g = Image.fromarray((ground * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    alpha = 1.0 - np.asarray(g, dtype=np.float32) / 255.0
    # (specks of ground colour left inside the margin: dropped)
    return np.dstack([a / 255.0, alpha])


def fit(rgba, size, radius):
    """Scale the glyph so every opaque pixel lies within `radius` of the centre
    of its bounding box; returns an RGBA image of `size` with it centred."""
    al = rgba[..., 3]
    ys, xs = np.nonzero(al > 0.5)
    cx, cy = (xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0
    far = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
    k = radius / far
    img = Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")
    w, h = img.size
    img = img.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(img, (round(size / 2 - cx * k), round(size / 2 - cy * k)))
    return out


def medallion(glyph, c1, c0):
    S = OUT
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    cx = S / 2.0
    r = np.sqrt((xx - cx) ** 2 + (yy - cx) ** 2) / (S / 2.0)
    # ground: radial, brighter up-left of the middle
    gx, gy = cx, S * 0.40
    t = np.clip(np.sqrt((xx - gx) ** 2 + (yy - gy) ** 2) / (S * 0.62), 0, 1)[..., None]
    ground = hexc(c1) * (1 - t) + hexc(c0) * t
    img = np.zeros((S, S, 4), dtype=np.float32)
    img[..., :3] = ground
    # rim: gold gradient top to bottom, 60..54 of 64
    rim_t = (yy / S)[..., None]
    gold = np.where(rim_t < 0.5, hexc("#f6dc8a") * (1 - rim_t * 2) + hexc("#b8862e") * rim_t * 2,
                    hexc("#b8862e") * (1 - (rim_t - 0.5) * 2) + hexc("#6e4a14") * (rim_t - 0.5) * 2)
    inner = r < 54.0 / 64.0
    outer = r < 60.0 / 64.0
    img[..., :3] = np.where(inner[..., None], img[..., :3], gold)
    img[..., 3] = outer.astype(np.float32) * 255.0
    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    # a thin dark line inside the rim
    d = ImageDraw.Draw(base)
    d.ellipse([cx - 54 / 64 * cx, cx - 54 / 64 * cx, cx + 54 / 64 * cx, cx + 54 / 64 * cx], outline=(0, 0, 0, 115), width=4)
    # the glyph, clipped to the inner circle
    g = glyph.copy()
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([cx - 54 / 64 * cx, cx - 54 / 64 * cx, cx + 54 / 64 * cx, cx + 54 / 64 * cx], fill=255)
    ga = np.asarray(g.split()[3], dtype=np.float32) * (np.asarray(mask, dtype=np.float32) / 255.0)
    g.putalpha(Image.fromarray(ga.astype(np.uint8)))
    base.alpha_composite(g)
    return base.resize((SAVE, SAVE), Image.LANCZOS)


def main():
    art, tough, cat = sys.argv[1], sys.argv[2], sys.argv[3]
    for key, (where, c1, c0) in ICONS.items():
        rgba = key_out(Image.open(os.path.join(art, key + ".png")))
        glyph = fit(rgba, OUT, GLYPH_R * 54.0 / 64.0 * OUT / 2.0)
        medallion(glyph, c1, c0).save(os.path.join(ROOT, "assets", "ui", where, key + ".png"))
    # (ours, kept: the cat, and the 狠角色 - both rasterised from their SVGs)
    Image.open(cat).convert("RGBA").resize((SAVE, SAVE), Image.LANCZOS).save(os.path.join(ROOT, "assets", "ui", "abilities", "cat.png"))
    Image.open(tough).convert("RGBA").resize((SAVE, SAVE), Image.LANCZOS).save(os.path.join(ROOT, "assets", "ui", "talents", "tough.png"))
    print("wrote", len(ICONS) + 1)


if __name__ == "__main__":
    main()
