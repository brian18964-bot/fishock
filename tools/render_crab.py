"""The beach crab, animated by hand. User request: a beach style with the
user's crab (Crab4.blend - a finely textured scan, no rig; trimmed to
art_src/critter/crab.glb). It's moved here, in the manner of
render_ghost_anim.py: the legs step in two alternating sets (lifting and
swinging, the tips most), the body bobs; standing, its claws wave. Same
sheet layout as the other critters (render_animals.sheet): 5 facings
rendered, the right-hand three mirrored in the game.

  python tools/render_crab.py OUT_DIR

writes OUT_DIR/crab_55deg_{albedo,normal}.png and prints its meta (merge
into animals.json / critter.gd's SPECIES).
"""
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_animals as ra  # noqa: E402

MODEL = os.path.join(os.path.dirname(__file__), "..", "art_src", "critter", "crab.glb")
WIDTH = 1.4       # world units across the legs
WALK = 8
IDLE = 8   # same as WALK: critter.gd reads one frame count per clip
LOOP_SECONDS = (0.5, 1.4)  # walk, idle
# Parts, in the model's own layout (it faces -Y, 1.36 across): the claws
# out in front, the legs out to the sides and curling back, the body.
CLAW_Y = -0.3
BODY_HALF_X = 0.33
BODY_BACK_Y = 0.32


def main():
    out = sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    meshes = rs.load_model(MODEL, 1.0)
    o = meshes[0]
    rest = np.array(o.matrix_world)
    inv = np.linalg.inv(rest)
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) @ rest[:3, :3].T + rest[:3, 3]
    # Parts, measured in the model's units before sizing.
    x, y = co[:, 0], co[:, 1]
    claw = y < CLAW_Y
    leg = ~claw & ((np.abs(x) > BODY_HALF_X) | (y > BODY_BACK_Y))
    side = np.where(x < 0, 0, 1)
    ang = np.arctan2(y, np.abs(x))
    bins = np.clip(((ang + 0.7) / 2.4 * 4).astype(int), 0, 3)
    leg_phase = ((bins % 2) + side) % 2 * math.pi
    reach = np.clip((np.hypot(x, y) - 0.32) / 0.4, 0, 1)
    claw_reach = np.clip((CLAW_Y - y) / 0.25, 0, 1)
    # Sized and stood on the ground, centred.
    s = WIDTH / np.ptp(x)
    base = co.copy()
    base[:, 0] -= (x.min() + x.max()) / 2
    base[:, 1] -= (y.min() + y.max()) / 2
    base[:, 2] -= co[:, 2].min()
    base *= s

    def put(world):
        o.data.vertices.foreach_set("co", (world @ inv[:3, :3].T + inv[:3, 3]).ravel())
        o.data.update()

    def animate(clip, i):
        p = base.copy()
        if clip == 0:
            ph = i / WALK * math.tau
            lift = np.maximum(0.0, np.sin(ph + leg_phase)) * 0.09 * s * reach
            swing = np.cos(ph + leg_phase) * 0.16 * reach
            c, sn = np.cos(swing), np.sin(swing)
            px, py = p[:, 0].copy(), p[:, 1].copy()
            p[:, 0] = np.where(leg, px * c - py * sn, px)
            p[:, 1] = np.where(leg, px * sn + py * c, py)
            p[:, 2] += np.where(leg, lift, 0.0)
            p[:, 2] += np.where(leg, 0.0, 0.012 * s * math.sin(2 * ph))
        else:
            ph = i / IDLE * math.tau
            wave = (0.5 + 0.5 * np.sin(ph + side * math.pi * 0.5)) * 0.08 * s * claw_reach
            p[:, 2] += np.where(claw, wave, 0.0)
            p[:, 0] += np.where(claw, (side * 2 - 1) * 0.02 * s * np.sin(ph) * claw_reach, 0.0)
        put(p)
        bpy.context.view_layer.update()

    yaw = rs.Yaw(0.0)
    cells = [(c, d, f) for c, n in ((0, WALK), (1, IDLE)) for d in ra.DIRS for f in range(n)]

    def pose(cell):
        c, d, f = cell
        yaw.set(rs.DIRS[d])
        animate(c, f)

    meta = ra.sheet("crab", out, meshes, cells, pose)
    meta.update({"frames": WALK, "clips": 2,
                 "fps": [round(WALK / LOOP_SECONDS[0], 2), round(IDLE / LOOP_SECONDS[1], 2)]})
    print(json.dumps({"crab": meta}))


if __name__ == "__main__":
    main()
