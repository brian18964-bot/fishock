"""The altar's rewards (user request): fish bones - whole skeletons, skulls, spines and broken
pieces in four sizes - and the glowing bone, its own kind, in the fish's three rarities' colours.
Built here from tubes and squashed spheres: a row of vertebrae along +x, the neural spines and
ribs curving off them, the skull at the front (its jaw and eye socket), the tail's fan of rays.
Lying flat (the ribs in the ground's plane), 0.3 m long.

Superseded for the models and pictures in the game by tools/make_meshy_bones.py (the user's Meshy
skeletons), which uses this one's picture() and halo(); running this again would put the old
procedural bones back.

  bpyenv/bin/python tools/make_fish_bones.py       (repo root)

Writes assets/models/items/bone_<kind>_<size>.glb (kind whole / spine / skull / broken, size
s / m / l / xl) and glow_bone_<rarity>.glb (common / rare / epic), and their pictures for the
bag, sized to their cells (Bones.CELLS), assets/sprites/items/<the same>.png. The square icons:
tools/render_square_icons.py.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MODELS = os.path.join(ROOT, "assets", "models", "items")
PICS = os.path.join(ROOT, "assets", "sprites", "items")
SIZES = ["s", "m", "l", "xl"]
# Vertebrae by size (a bigger fish, more of them, and thicker for its length).
VERTS = {"s": 10, "m": 13, "l": 16, "xl": 19}
# The cells each takes in the bag (Bones.CELLS - kept the same there).
CELLS = {
    "whole": [(1, 1), (2, 1), (3, 1), (3, 2)],
    "spine": [(1, 1), (2, 1), (3, 1), (3, 1)],
    "skull": [(1, 1), (1, 1), (2, 1), (2, 2)],
    "broken": [(1, 1), (1, 1), (2, 1), (2, 1)],
}
GLOW = {"common": (0.85, 0.92, 1.0), "rare": (0.35, 0.62, 1.0), "epic": (0.78, 0.45, 1.0)}
BONE = (0.86, 0.81, 0.68)
PX = 128


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, emit=None, strength=3.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.72
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    return m


def tube(points, radius, m, taper=0.4):
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
        # (thinning to the tip)
        sp.points[i].radius = 1.0 - (1.0 - taper) * i / max(len(points) - 1, 1)
    ob = bpy.data.objects.new("tube", cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m)
    return ob


def blob(loc, scale, m, rot=(0.0, 0.0, 0.0), segs=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = scale
    ob.data.materials.append(m)
    return ob


def arc(x0, y0, length, bend, up, steps=6):
    """A rib or spine off the backbone at (x0, y0): out along y (`up` 1 above, -1 below), swept
    back along -x by `bend` - points along it."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        pts.append((x0 - bend * t * t, y0 + up * length * t, 0.0))
    return pts


def spine(m, n, x_from, x_to, rng, ribs=True, broken=0.0, thick=1.0):
    """The backbone from x_from to x_to: n vertebrae, a spine above and a rib below each (the
    ribs only along the front two thirds - the belly); `broken` the share of ribs snapped short or
    gone."""
    parts = []
    step = (x_to - x_from) / max(n - 1, 1)
    r = 0.022 * thick
    for i in range(n):
        x = x_from + step * i
        t = i / max(n - 1, 1)
        # (the body's depth along it: deepest a third of the way back)
        depth = math.sin(math.pi * (0.15 + 0.85 * t)) ** 0.8
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=r * (1.0 - 0.35 * t), depth=step * 0.72,
                                            location=(x, 0.0, 0.0), rotation=(0.0, math.pi / 2, 0.0))
        v = bpy.context.active_object
        v.data.materials.append(m)
        parts.append(v)
        if not ribs:
            continue
        up_len = 0.13 * depth * (0.7 + 0.3 * rng.random())
        down_len = 0.16 * depth * (0.8 + 0.2 * rng.random()) if t < 0.66 else 0.09 * depth
        for up, length in ((1, up_len), (-1, down_len)):
            if broken > 0.0 and rng.random() < broken:
                if rng.random() < 0.5:
                    continue
                length *= rng.uniform(0.25, 0.6)
            parts.append(tube(arc(x, 0.0, length, step * 1.6, up), 0.008 * thick, m))
    return parts


def skull(m, x, size, socket=True):
    """The skull at x: a long cranium narrowing to a pointed snout, the thin lower jaw under it,
    the gill cover's plate behind, the eye socket a hollow in it."""
    parts = []
    k = size
    cranium = blob((x, 0.012 * k, 0.0), (0.085 * k, 0.04 * k, 0.026 * k), m, rot=(0.0, 0.0, -0.08))
    parts.append(cranium)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.024 * k, radius2=0.004 * k, depth=0.07 * k,
                                    location=(x + 0.1 * k, 0.004 * k, 0.0), rotation=(0.0, math.pi / 2, 0.0))
    snout = bpy.context.active_object
    snout.scale = (0.7, 1.0, 1.0)
    snout.data.materials.append(m)
    parts.append(snout)
    parts.append(blob((x + 0.05 * k, -0.03 * k, 0.0), (0.08 * k, 0.011 * k, 0.014 * k), m, rot=(0.0, 0.0, 0.1)))
    # (the gill cover: a flat plate behind the eye, its rim a ridge)
    bpy.ops.mesh.primitive_cylinder_add(vertices=18, radius=0.042 * k, depth=0.01 * k, location=(x - 0.05 * k, 0.0, 0.004 * k))
    plate = bpy.context.active_object
    plate.scale = (0.8, 1.0, 1.0)
    plate.data.materials.append(m)
    parts.append(plate)
    parts.append(tube([(x - 0.07 * k, 0.045 * k, 0.0), (x - 0.088 * k, 0.0, 0.0), (x - 0.07 * k, -0.042 * k, 0.0)], 0.006 * k, m, 1.0))
    if socket:
        hole = blob((x + 0.03 * k, 0.02 * k, 0.026 * k), (0.015 * k, 0.015 * k, 0.026 * k), m)
        mod = cranium.modifiers.new("socket", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = hole
        bpy.context.view_layer.objects.active = cranium
        bpy.ops.object.modifier_apply(modifier="socket")
        bpy.data.objects.remove(hole)
    return parts


def tail(m, x, size, rng):
    parts = []
    for i in range(7):
        a = math.radians(-34 + 68 * i / 6)
        length = 0.1 * size * (1.0 - 0.25 * abs(i - 3) / 3)
        parts.append(tube([(x, 0.0, 0.0), (x - length * math.cos(a), length * math.sin(a), 0.0)], 0.006 * size, m))
    return parts


def build(kind, size, m, seed):
    rng = random.Random(seed)
    n = VERTS[size]
    k = {"s": 0.9, "m": 1.0, "l": 1.1, "xl": 1.25}[size]
    parts = []
    if kind == "whole":
        parts += skull(m, 0.36, k)
        parts += spine(m, n, 0.25, -0.3, rng, thick=k)
        parts += tail(m, -0.32, k, rng)
    elif kind == "spine":
        parts += spine(m, n, 0.25, -0.3, rng, thick=k)
    elif kind == "skull":
        parts += skull(m, 0.0, k * 1.6)
        parts += spine(m, 3, -0.11 * k, -0.2 * k, rng, ribs=False, thick=k * 1.4)
    elif kind == "broken":
        # (the front half of a backbone, ribs snapped and gone, a piece of the jaw by it)
        keep = max(4, int(n * 0.55))
        parts += spine(m, keep, 0.12, -0.2, rng, broken=0.55, thick=k)
        parts.append(blob((0.2, -0.05, 0.0), (0.045 * k, 0.014 * k, 0.018 * k), m, rot=(0.0, 0.0, 0.5)))
    return parts


def finish(parts, path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in list(bpy.context.scene.objects):
        if ob.type == "CURVE":
            bpy.context.view_layer.objects.active = ob
            ob.select_set(True)
            bpy.ops.object.convert(target="MESH")
            ob.select_set(False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for p in ob.data.polygons:
        p.use_smooth = True
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    s = 0.3 / span
    cx, cy = (max(xs) + min(xs)) / 2.0, (max(ys) + min(ys)) / 2.0
    for v in ob.data.vertices:
        v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - min(zs)) * s))
    ob.name = os.path.splitext(os.path.basename(path))[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True)
    return ob


def picture(ob, cells, path, glow=None):
    """Looked down on, in the cells' shape, on nothing (transparent), lit warm from the upper left;
    a glowing one with its light round it."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = cells[0] * PX
    scene.render.resolution_y = cells[1] * PX
    scene.view_settings.view_transform = "Standard"
    xs = [(ob.matrix_world @ v.co).x for v in ob.data.vertices]
    ys = [(ob.matrix_world @ v.co).y for v in ob.data.vertices]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    # (turned to lie along the cells' long side; a square box: corner to corner is the picture's own)
    if cells[1] > cells[0]:
        ob.rotation_euler = (0.0, 0.0, math.pi / 2)
        w, h = h, w
    aspect = cells[0] / cells[1]
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(w, h * aspect) * 1.12
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0.0, 0.0, 1.0)
    scene.camera = cam
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun_ob = bpy.data.objects.new("sun", sun)
    scene.collection.objects.link(sun_ob)
    sun_ob.rotation_euler = (math.radians(35), math.radians(-25), math.radians(20))
    fill = bpy.data.lights.new("fill", "SUN")
    fill.energy = 0.9
    fill.color = (0.7, 0.8, 1.0)
    fill_ob = bpy.data.objects.new("fill", fill)
    scene.collection.objects.link(fill_ob)
    fill_ob.rotation_euler = (math.radians(-40), math.radians(30), 0.0)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if glow is not None:
        halo(path, GLOW[glow])


def halo(path, rgb):
    """A glowing one's light round it: its shape blurred out in its colour, under it."""
    from PIL import Image, ImageFilter
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A")
    soft = a.filter(ImageFilter.GaussianBlur(radius=max(im.size) * 0.04)).point(lambda v: min(255, int(v * 2.2)))
    glow_im = Image.new("RGBA", im.size, tuple(int(c * 255) for c in rgb) + (0,))
    glow_im.putalpha(soft)
    out = Image.alpha_composite(glow_im, im)
    out.save(path)


def make(name, kind, size, cells, glow=None):
    fresh()
    m = mat("bone", GLOW[glow] if glow else BONE, GLOW[glow] if glow else None, 0.7)
    parts = build(kind, size, m, sum(map(ord, name)))
    ob = finish(parts, os.path.join(MODELS, name + ".glb"))
    picture(ob, cells, os.path.join(PICS, name + ".png"), glow)
    print("made", name, flush=True)


def main():
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for kind in CELLS:
        for i, size in enumerate(SIZES):
            name = "bone_%s_%s" % (kind, size)
            if not only or name in only:
                make(name, kind, size, CELLS[kind][i])
    for rarity in GLOW:
        name = "glow_bone_" + rarity
        if not only or name in only:
            make(name, "whole", "m", (2, 1), rarity)
    os._exit(0)


if __name__ == "__main__":
    main()
