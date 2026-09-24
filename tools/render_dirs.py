"""Static (unanimated) model -> one sprite sheet row, one cell per facing,
through the same 55deg albedo + normal pipeline (tools/render_sprite.py).

For props or creatures with no animation clips that still need to face the
way they move (the ghost). The camera is fitted to the union of every
facing's bounds, x-symmetric so the model origin sits mid-cell.

  python tools/render_dirs.py MODEL OUT_PREFIX [--scale S] [--facing DEG]
      [--dirs down left right up] [--recenter] [--drop NAME]

prints the cell size and the sprite offset ((0, -center_y) * 27.108).

Rendered so far:
  ghost/ghost  art_src/ghost/ghost.glb x1.3 --facing 39  (dirs down left right up)
"""
import argparse
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402

DENSITY = 27.108
PAD = 0.08


def main():
    p = argparse.ArgumentParser()
    p.add_argument("model")
    p.add_argument("out_prefix")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--facing", type=float, default=0.0, help="yaw (deg) that turns the model to face the camera")
    p.add_argument("--dirs", nargs="+", default=["down", "left", "right", "up"], choices=list(rs.DIRS))
    p.add_argument("--recenter", action="store_true")
    p.add_argument("--drop", action="append", default=[])
    args = p.parse_args()

    meshes = rs.load_model(args.model, args.scale, args.recenter, 0.25, None, args.drop)
    yaw = rs.Yaw(args.facing)
    x0 = y0 = 1e9
    x1 = y1 = -1e9
    for d in args.dirs:
        yaw.set(rs.DIRS[d])
        b = rs.screen_bounds(meshes)
        x0, x1 = min(x0, b["min_x"]), max(x1, b["max_x"])
        y0, y1 = min(y0, b["min_y"]), max(y1, b["max_y"])
    hx = max(-x0, x1) + PAD
    y0, y1 = y0 - PAD, y1 + PAD
    w = math.ceil(2 * hx * DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * DENSITY / 8) * 8
    cy = (y0 + y1) / 2
    rs.setup_scene(cy, max(w, h) / DENSITY, w, h)
    rs.pack_sheet(meshes, list(args.dirs), lambda d: yaw.set(rs.DIRS[d]), (w, h), len(args.dirs), args.out_prefix)
    print(json.dumps({"cell": [w, h], "dirs": args.dirs, "offset": [0.0, round(-cy * DENSITY, 2)]}))


if __name__ == "__main__":
    main()
