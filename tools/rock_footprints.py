"""Rocks' solid footprints from their pictures (user request: no walking
into the rocks - their bases had been an ellipse fitted to a box around
each rock's measured base, so a long rock lying across the view, a flat
slab, let the player step onto its ends).

For every rock picture the obstacles use (scripts/obstacle.gd VARIANTS,
scripts/nature_catalog.gd ROCKS, and their snowed and autumn versions,
scripts/derived_art.gd), within the box its base was measured to from the
model (its footprint: a long rock's ends, a slab's, reach its corners), the
base is the silhouette there, column by column: from its top (or the box's
back edge, for a tall rock) to its bottom - the front edge of the base.
Columns past the box's sides (a roof, a leaning top) are left out. Their
convex hull, in the node's px at size 1, is written to
assets/sprites/rock_footprints.json (albedo path -> [[x, y], ...]), which
obstacle.gd makes the rock's collision from.

  python3 tools/rock_footprints.py
"""
import json
import os
import re

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "rock_footprints.json")
# scripts/art.gd DENSITY; obstacle.gd SPRITE_SCALE
DENSITY = 2.0
SPRITE_SCALE = 0.5
SEASONS = ["snow", "autumn"]
ALPHA = 128
# Columns sampled across the silhouette (each side).
STEPS = 14
ENTRY = re.compile(r'"albedo":\s*"(res://[^"]+)".*?"offset":\s*Vector2\(\s*([-\d.]+),\s*([-\d.]+)\)'
                   r'.*?"footprint":\s*Rect2\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\)', re.S)
# A column belongs to the base this far past the box's sides (px).
SIDE_SLACK = 3.0


def entries(path, const):
    text = open(os.path.join(ROOT, path)).read()
    start = text.index("const %s := [" % const)
    end = text.index("\n]", start)
    for m in ENTRY.finditer(text[start:end]):
        yield m.group(1), (float(m.group(2)), float(m.group(3))), tuple(float(v) for v in m.group(4, 5, 6, 7))


def local(path):
    return os.path.join(ROOT, path.replace("res://", ""))


def hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def footprint(png, offset, box):
    a = np.asarray(Image.open(png).convert("RGBA"))[..., 3] >= ALPHA
    h, w = a.shape
    cols = np.where(a.any(axis=0))[0]
    if len(cols) == 0:
        return None
    x0, x1 = cols[0], cols[-1]
    k = SPRITE_SCALE / DENSITY
    bx, by, bw, bh = box

    def node(px, py):
        return ((px - w / 2.0) + offset[0] * DENSITY) * k, ((py - h / 2.0) + offset[1] * DENSITY) * k
    pts = []
    for i in range(4 * STEPS + 1):
        x = int(round(x0 + (x1 - x0) * i / (4 * STEPS)))
        ys = np.where(a[:, x])[0]
        if len(ys) == 0:
            continue
        nx, south = node(x + 0.5, ys[-1] + 1.0)
        _, top = node(x + 0.5, ys[0])
        if nx < bx - SIDE_SLACK or nx > bx + bw + SIDE_SLACK or south < by:
            continue
        north = max(top, by)
        south = min(south, by + bh + SIDE_SLACK)
        pts.append((round(nx, 1), round(south, 1)))
        pts.append((round(nx, 1), round(min(north, south), 1)))
    if len(pts) < 6:
        return None
    return [list(p) for p in hull(pts)]


def main():
    found = {}
    for path, const in (("scripts/obstacle.gd", "VARIANTS"), ("scripts/nature_catalog.gd", "ROCKS")):
        for albedo, offset, box in entries(path, const):
            for p in [albedo] + [albedo.replace("_55deg_albedo.png", "_%s_55deg_albedo.png" % s) for s in SEASONS]:
                if os.path.exists(local(p)):
                    fp = footprint(local(p), offset, box)
                    if fp:
                        found[p] = fp
    with open(OUT, "w") as fh:
        json.dump(found, fh, separators=(",", ":"), sort_keys=True)
    print("wrote", OUT, len(found), "rocks")


if __name__ == "__main__":
    main()
