"""Flames and smoke for the camp fire's particles: the campfire pack's
flame atlas cut into a 2x2 sheet of its biggest flames and a 2x2 sheet of
its biggest smoke wisps (told apart by colour), on transparent, 256 px a
cell, bottoms aligned.

  python3 tools/cut_fire_sprites.py ATLAS.png OUT_DIR   (build_camp_models runs it)

Writes OUT_DIR/fire_flames.png and fire_smoke.png.
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def main(atlas, out):
    sheet = Image.open(atlas).convert("RGBA")
    a = np.asarray(sheet)
    alpha = a[..., 3] > 24
    lab, _ = ndimage.label(ndimage.binary_dilation(alpha, iterations=6))
    pieces = []
    for sl in ndimage.find_objects(lab):
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if h * w < 40 * 40:
            continue
        rgb = a[sl][..., :3][alpha[sl]]
        warm = float(np.mean(rgb[:, 0]) - np.mean(rgb[:, 2]))
        pieces.append((h * w, warm, sl))
    flames = sorted([p for p in pieces if p[1] > 40], key=lambda p: -p[0])[:4]
    smoke = sorted([p for p in pieces if p[1] <= 40], key=lambda p: -p[0])[:4]
    for kind, picked in (("flames", flames), ("smoke", smoke)):
        sheet_out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        for k, (_, _, sl) in enumerate(picked):
            cell = sheet.crop((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
            cell.thumbnail((240, 240), Image.LANCZOS)
            x = (k % 2) * 256 + (256 - cell.width) // 2
            y = (k // 2) * 256 + (256 - cell.height)
            sheet_out.alpha_composite(cell, (x, y))
        sheet_out.save(os.path.join(out, "fire_%s.png" % kind), optimize=True)
        print("built fire_%s from %d pieces" % (kind, len(picked)), flush=True)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
