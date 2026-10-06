"""Checks the front layer (BodyFront) in the in-game captures (user
request, round 5: no notches, no blocks of the character's colour, no
rod wrongly covered). Per cell, three captures of the same frame:
  clean   rod + front layer, as the game draws it
  nofront rod, no front layer
  norod   body alone
  rod     where nofront differs from norod: the rod's pixels on screen
  front   where clean differs from nofront: what the front layer changed
  good    front pixels where clean matches the body alone (the body put
          back over the rod)
  bad     front pixels where clean matches neither - a block of colour or
          a cut that doesn't line up with the body
  stray   front pixels off the rod (the layer drawn where no rod is)
Tolerance TOL per channel. A sprite's edge is filtered (its outer pixel
half the colour under it), so the pixels within EDGE px of the front
layer's outline (bad) or of the rod's (stray) are counted apart as
"edge": what's left (bad_core, stray_core) is a real error.

    python3 tools/rod_front_check.py SHOTS_DIR OUT.json [WORST_DIR]  (shots: tools/preview_shots.gd)
"""
import glob
import json
import os
import re
import sys

import numpy as np
from PIL import Image

TOL = 24
EDGE = 2


def load(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(int)


def main():
    src, out = sys.argv[1:3]
    worst_dir = sys.argv[3] if len(sys.argv) > 3 else None
    rows = []
    for p in sorted(glob.glob(os.path.join(src, "*_clean.png"))):
        key = os.path.basename(p)[:-len("_clean.png")]
        n, b = p.replace("_clean", "_nofront"), p.replace("_clean", "_norod")
        if not (os.path.exists(n) and os.path.exists(b)):
            continue
        C, N, B = load(p), load(n), load(b)
        diff = lambda x, y: (np.abs(x - y) > TOL).any(axis=2)
        rod = diff(N, B)
        front = diff(C, N)
        good = front & ~diff(C, B)
        bad = front & diff(C, B)
        stray = front & ~rod
        from scipy.ndimage import binary_dilation, binary_erosion
        core = binary_erosion(front, iterations=EDGE)
        near_rod = binary_dilation(rod, iterations=EDGE)
        bad_core = bad & core
        stray_core = stray & ~near_rod
        m = re.match(r"t(\d)_(\w+?)_d(\d)_f(\d)", key)
        rows.append({"cell": key, "tier": int(m.group(1)), "clip": m.group(2), "dir": int(m.group(3)),
                     "frame": int(m.group(4)), "rod": int(rod.sum()), "front": int(front.sum()),
                     "good": int(good.sum()), "bad": int(bad.sum()), "stray": int(stray.sum()),
                     "bad_core": int(bad_core.sum()), "stray_core": int(stray_core.sum())})
        if worst_dir:
            rows[-1]["_masks"] = (bad_core, stray_core)
    worst = sorted(rows, key=lambda r: -(r["bad_core"] + r["stray_core"]))[:6]
    if worst_dir:
        os.makedirs(worst_dir, exist_ok=True)
        for r in worst:
            C = load(os.path.join(src, r["cell"] + "_clean.png")).astype(np.uint8)
            bad, stray = r["_masks"]
            mark = C.copy()
            mark[bad] = (255, 0, 255)
            mark[stray] = (0, 200, 255)
            Image.fromarray(np.concatenate([C, mark], axis=1)).save(os.path.join(worst_dir, r["cell"] + ".png"))
    for r in rows:
        r.pop("_masks", None)
    summ = {"cells": len(rows), "with_front": sum(1 for r in rows if r["front"]),
            "front_px": sum(r["front"] for r in rows), "good_px": sum(r["good"] for r in rows),
            "bad_px": sum(r["bad"] for r in rows), "stray_px": sum(r["stray"] for r in rows),
            "bad_core_px": sum(r["bad_core"] for r in rows), "stray_core_px": sum(r["stray_core"] for r in rows),
            "cells_bad_core_over_4px": sum(1 for r in rows if r["bad_core"] > 4),
            "cells_stray_core_over_4px": sum(1 for r in rows if r["stray_core"] > 4), "edge_px": EDGE,
            "worst": [{k: v for k, v in r.items()} for r in worst], "tolerance": TOL}
    json.dump({"summary": summ, "cells": rows}, open(out, "w"), indent=1)
    print("OCCL", json.dumps({k: v for k, v in summ.items() if k != "worst"}))
    for r in worst:
        print("  worst", r["cell"], "rod", r["rod"], "front", r["front"], "bad", r["bad"], r["bad_core"],
              "stray", r["stray"], r["stray_core"])


if __name__ == "__main__":
    main()
