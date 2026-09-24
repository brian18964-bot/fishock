"""Procedural water splash sprite sheets, rendered through the same 55deg
albedo + normal pipeline as every other sprite (tools/render_sprite.py).

There's no splash model in the asset packs, so the geometry is built here:
droplets on ballistic paths (ring out from the splash point), a central
spout, and for fish_jump a small low-poly fish leaping in an arc. One row
of frames per sheet; all sheets share the density, so in-game sizes stay
consistent.

  python tools/render_splash.py OUT_DIR

writes OUT_DIR/splash_land_55deg_*, splash_bite_55deg_*, fish_jump_right_55deg_*,
fish_jump_left_55deg_* and OUT_DIR/splash_meta.json (cell size, frames,
sprite offset = (center_x, -center_y) * 27.108 per sheet).
"""
import json
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402

DENSITY = 27.108
PAD = 0.08
WATER = (0.78, 0.9, 1.0, 1.0)
FISH = (0.5, 0.62, 0.7, 1.0)
FISH_BELLY = (0.82, 0.86, 0.88, 1.0)


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = color
    return mat


def droplet(mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    o = bpy.context.active_object
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def ballistic(count, t_land, reach, rng, r0=0.2):
    """Per-droplet (angle, radial speed, launch time, landing time)."""
    drops = []
    for i in range(count):
        a = (i + rng.uniform(-0.3, 0.3)) / count * math.tau
        tl = t_land * rng.uniform(0.75, 1.0)
        drops.append((a, reach * rng.uniform(0.6, 1.0) / tl, rng.uniform(0.0, 0.06), tl, r0))
    return drops


def place_drops(objs, drops, t, size, g):
    for o, (a, vr, t0, tl, r0) in zip(objs, drops):
        tt = t - t0
        if tt <= 0.0 or tt >= tl:
            o.scale = (0.0, 0.0, 0.0)
            continue
        vz = 0.5 * g * tl
        z = vz * tt - 0.5 * g * tt * tt
        r = r0 + vr * tt
        o.location = (math.cos(a) * r, math.sin(a) * r, z)
        s = size * (1.0 - 0.45 * tt / tl)
        # Stretched along the direction of travel.
        o.scale = (s, s, s * (1.0 + 0.9 * abs(vz - g * tt) / vz))


def splash(kind):
    rng = random.Random(7 if kind == "land" else 11)
    water = material("Water", WATER)
    if kind == "land":
        count, t_land, reach, size, frames, g = 18, 0.55, 0.95, 0.075, 8, 16.0
    else:
        count, t_land, reach, size, frames, g = 11, 0.38, 0.55, 0.06, 6, 16.0
    drops = ballistic(count, t_land, reach, rng)
    objs = [droplet(water) for _ in drops]
    spout = droplet(water) if kind == "land" else None
    cap = droplet(water) if kind == "land" else None
    total = t_land + 0.08

    def pose(i):
        t = (i + 0.5) / frames * total
        place_drops(objs, drops, t, size, g)
        if spout is not None:
            # A column that shoots up and collapses, tipped with a drop.
            k = max(0.0, math.sin(math.pi * min(t / (total * 0.7), 1.0)))
            spout.location = (0.0, 0.0, 0.45 * k)
            spout.scale = (0.1 * k + 1e-4, 0.1 * k + 1e-4, 0.5 * k + 1e-4)
            cap.location = (0.0, 0.0, 1.0 * k)
            cap.scale = (0.08 * k + 1e-4,) * 3
        bpy.context.view_layer.update()

    return frames, pose


def fish_jump(direction):
    rng = random.Random(3)
    water = material("Water", WATER)
    body_mat = material("Fish", FISH)
    belly_mat = material("FishBelly", FISH_BELLY)
    # Body: squashed sphere; belly: a lighter, smaller one underneath; tail:
    # a flattened cone. Parented to one empty that flies the arc.
    root = bpy.data.objects.new("FishRoot", None)
    bpy.context.scene.collection.objects.link(root)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0)
    body = bpy.context.active_object
    body.scale = (0.36, 0.12, 0.15)
    body.data.materials.append(body_mat)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1.0, location=(0.02, 0.0, -0.04))
    belly = bpy.context.active_object
    belly.scale = (0.3, 0.1, 0.1)
    belly.data.materials.append(belly_mat)
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.2, depth=0.26, location=(-0.44, 0.0, 0.0),
                                    rotation=(0.0, math.radians(-90.0), 0.0))
    tail = bpy.context.active_object
    tail.scale = (1.0, 0.3, 1.0)
    tail.data.materials.append(body_mat)
    for o in (body, belly, tail):
        bpy.ops.object.shade_smooth() if o is not tail else None
        o.parent = root
    frames, total, span, height = 10, 0.8, 1.6, 1.5
    entry = ballistic(9, 0.3, 0.35, rng)
    exit_ = ballistic(12, 0.35, 0.45, rng)
    entry_objs = [droplet(water) for _ in entry]
    exit_objs = [droplet(water) for _ in exit_]

    def pose(i):
        t = (i + 0.5) / frames * total
        s = t / (total * 0.8)  # fish airborne for the first 80%
        x0 = -span / 2 * direction
        if s <= 1.0:
            x = x0 + span * s * direction
            z = height * math.sin(math.pi * s) - 0.05
            slope = height * math.pi * math.cos(math.pi * s) / span
            root.location = (x, 0.0, z)
            root.rotation_euler = Euler((0.0, -math.atan(slope) * direction, 0.0 if direction > 0 else math.pi))
            root.scale = (1.0, 1.0, 1.0)
        else:
            root.scale = (0.0, 0.0, 0.0)
        # Droplets where it leaves the water, then where it lands.
        for o in entry_objs:
            o.location = (0.0, 0.0, 0.0)
        place_drops(entry_objs, entry, t, 0.05, 16.0)
        for o, d in zip(entry_objs, entry):
            if o.scale[0] > 0:
                o.location = (o.location[0] + x0, o.location[1], o.location[2])
        place_drops(exit_objs, exit_, t - total * 0.75, 0.055, 16.0)
        for o in exit_objs:
            if o.scale[0] > 0:
                o.location = (o.location[0] - x0, o.location[1], o.location[2])
        bpy.context.view_layer.update()

    return frames, pose


def build(name, maker, out_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    frames, pose = maker()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    x0 = y0 = 1e9
    x1 = y1 = -1e9
    for i in range(frames):
        pose(i)
        live = [o for o in meshes if o.matrix_world.to_scale().length > 1e-3]
        if not live:
            continue
        b = rs.screen_bounds(live)
        x0, x1 = min(x0, b["min_x"]), max(x1, b["max_x"])
        y0, y1 = min(y0, b["min_y"]), max(y1, b["max_y"])
    hx = max(-x0, x1) + PAD  # symmetric, so the anchor sits mid-cell
    y0, y1 = y0 - PAD, y1 + PAD
    w = math.ceil(2 * hx * DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * DENSITY / 8) * 8
    cy = (y0 + y1) / 2
    rs.setup_scene(cy, max(w, h) / DENSITY, w, h)
    rs.pack_sheet(meshes, list(range(frames)), pose, (w, h), frames, os.path.join(out_dir, f"{name}_55deg"))
    return {"cell": [w, h], "frames": frames, "offset": [0.0, round(-cy * DENSITY, 2)]}


def main():
    out_dir = sys.argv[-1]
    os.makedirs(out_dir, exist_ok=True)
    meta = {
        "splash_land": build("splash_land", lambda: splash("land"), out_dir),
        "splash_bite": build("splash_bite", lambda: splash("bite"), out_dir),
        "fish_jump_right": build("fish_jump_right", lambda: fish_jump(1), out_dir),
        "fish_jump_left": build("fish_jump_left", lambda: fish_jump(-1), out_dir),
    }
    with open(os.path.join(out_dir, "splash_meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
