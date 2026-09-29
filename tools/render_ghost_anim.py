"""The floating ghosts, animated. User feedback: the small ghosts were stiff
- one still pose per facing (render_dirs.py), slid about and bobbed. The
model (Ghoooooost by Nikki Morin, art_src/ghost/ghost.glb) has no rig, and
isn't a body a humanoid clip would fit, so it's moved here by hand, as a
loop: its tail streams and ripples in a wave running from the head to the
tip, the body breathes, and the little clawed hands paw at the air, each a
beat apart. 8 facings now (it was 4).

  python tools/render_ghost_anim.py OUT_DIR

writes OUT_DIR/ghost_55deg_{albedo,normal}.png - rows = facings (in
render_characters.DIRS order), columns = frames - and prints the cell size
and the sprite offset.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_characters as rc  # noqa: E402

MODEL = os.path.join(os.path.dirname(__file__), "..", "art_src", "ghost", "ghost.glb")
SCALE = 1.3
FACING = 39.0
FRAMES = 8
BODY = "group473796594"
EYES = ["group108580628", "group2008820591", "group40726355", "group830039088"]
DENSITY = 2


def coords(o):
    """World-space vertices (before any turning)."""
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    m = np.array(o.matrix_world)
    return co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]


def put(o, world, rest):
    """Back into the object's own space, from world space before turning."""
    m = np.linalg.inv(np.array(rest))
    o.data.vertices.foreach_set("co", (world @ m[:3, :3].T + m[:3, 3]).ravel())
    o.data.update()


def main():
    out = sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    meshes = rs.load_model(MODEL, SCALE)
    objs = {o.name: o for o in meshes}
    body = objs[BODY]
    # Worked out in world space, before the model is turned.
    base = {o.name: coords(o) for o in meshes}
    rest = {o.name: o.matrix_world.copy() for o in meshes}
    b = base[BODY]
    head = np.concatenate([base[e] for e in EYES]).mean(0)
    far = b[np.argmax(np.linalg.norm(b - head, axis=1))]
    axis = far - head
    length = np.linalg.norm(axis)
    axis /= length
    side = np.cross(axis, [0.0, 0.0, 1.0])
    if np.linalg.norm(side) < 1e-3:
        side = np.cross(axis, [0.0, 1.0, 0.0])
    side /= np.linalg.norm(side)
    lift = np.cross(side, axis)
    s = np.clip((b - head) @ axis / length, 0.0, 1.0)
    hands = [n for n in objs if n not in EYES and n != BODY]
    hand_phase = {n: i * 0.9 for i, n in enumerate(sorted(hands))}

    def animate(i):
        ph = i / FRAMES * math.tau
        # Tail: a travelling wave, growing toward the tip.
        amp = 0.13 * length * s ** 1.5
        wave = ph - 2.6 * math.pi * s
        new = b + amp[:, None] * (np.sin(wave)[:, None] * side + 0.45 * np.cos(wave)[:, None] * lift)
        # Breathing: the head end swells a little.
        breathe = 1.0 + 0.035 * math.sin(ph) * (1.0 - s)
        new = head + (new - head) * breathe[:, None]
        put(body, new, rest[BODY])
        for n in hands:
            o = objs[n]
            c = base[n]
            q = ph + hand_phase[n]
            off = lift * 0.035 * length * math.sin(q) + axis * 0.02 * length * math.cos(q)
            put(o, c + off, rest[n])
        bpy.context.view_layer.update()

    yaw = rs.Yaw(FACING)
    cells = [(d, i) for d in rc.DIRS for i in range(FRAMES)]

    def pose(cell):
        d, i = cell
        yaw.set(rs.DIRS[d])
        animate(i)

    bs = []
    for cell in cells:
        pose(cell)
        bs.append(rs.screen_bounds(meshes))
    w, h, cx, cy = rc.fit(rc.union(bs))
    rs.setup_scene(cy, max(w, h) / rc.DENSITY, w * DENSITY, h * DENSITY, cx)
    prefix = os.path.join(out, "ghost_55deg")
    rs.pack_sheet(meshes, cells, pose, (w * DENSITY, h * DENSITY), FRAMES, prefix)
    rc.downsample_normal(f"{prefix}_normal.png")
    print(json.dumps({"ghost": {"cell": [w, h], "offset": [round(cx * rc.DENSITY, 2), round(-cy * rc.DENSITY, 2)],
                                "frames": FRAMES}}))


if __name__ == "__main__":
    main()
