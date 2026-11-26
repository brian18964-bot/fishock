"""The Japanese village's buildings and things, made our own from the user's shrine set (user
request: "素材都要經過你再製，成為我們的資產" - the originals are never committed; only what this
makes; docs/RUINED_WORLD.md). An ordinary place, nothing broken (user decision: only the city is a
ruin).

The set's pictures are tiling PBR materials its files don't carry their colours for; each part is
coloured here instead by what it is made of - a palette of ours (PALETTE: weathered cedar, black
lacquer, white plaster and paper, grey roof tiles and stone, straw, bamboo), a few things their own
(OWN: the torii's vermilion) - into a vertex colour, each face a shade of its own, darker low down
where the ground's dirt splashes; no pictures at all. Each thing one mesh, its middle over the
origin, standing on z = 0, thinned to at most its triangles (THINGS), brought to its size.

Our own besides: a clump of bamboo (CLUMP) - the set's stalks drawn up to a grove's height, leaning
their own ways, leafy at the top.

  bpyenv/bin/python tools/make_japan_assets.py -- SHRINE_SET_DIR OUT_DIR

writes OUT_DIR/jp_*.glb and jp_assets.json (each one's footprint and height, m; a lantern's lamp).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[:2]

# What each part is made of, by its material's name (the longest name that fits first).
PALETTE = {
    "wood_brown_tiles": (0.27, 0.19, 0.14), "wood_brown": (0.36, 0.25, 0.17), "wood_black": (0.07, 0.065, 0.06),
    "wood_white": (0.84, 0.81, 0.74), "brick": (0.82, 0.79, 0.72), "rock": (0.4, 0.41, 0.43),
    "window": (0.9, 0.86, 0.72), "line": (0.88, 0.85, 0.78), "ema": (0.78, 0.64, 0.44), "straw_triagle": (0.66, 0.55, 0.3),
    "straw": (0.63, 0.53, 0.28), "bamboo": (0.5, 0.56, 0.3), "metal": (0.3, 0.3, 0.32), "stone": (0.5, 0.5, 0.48),
}
# (a thing's own colours over the palette's)
VERMILION = (0.7, 0.17, 0.09)
# Each thing: its file, our name, its most triangles, its height (m; None: as made), its own colours,
# dirtied low down or not.
THINGS = [
    ("Home_1.fbx", "jp_house_1", 5000, None, {}, True),
    ("Home_2.fbx", "jp_house_2", 8000, None, {}, True),
    ("Small_Temple.fbx", "jp_shrine", 2500, 5.0, {"wood_brown": VERMILION}, True),
    ("Entrance_Wall.fbx", "jp_gate", 2200, None, {}, True),
    ("Shed.fbx", "jp_shed", 900, None, {}, True),
    ("Ema_1_Stand_large.fbx", "jp_ema_1", 1600, None, {}, True),
    ("Ema_1_stand.fbx", "jp_ema_2", 900, None, {}, True),
    ("Tori_Gate.fbx", "jp_torii", 2500, 6.0, {"wood_brown": VERMILION, "wood_white": VERMILION}, True),
    ("Lighting.fbx", "jp_toro", 600, 1.9, {}, True),
    ("Lamp_1.fbx", "jp_lamp", 500, 2.0, {}, False),
    ("Bench.fbx", "jp_bench", 200, None, {}, True),
    ("Cup.fbx", "jp_basin", 300, None, {"metal": (0.4, 0.4, 0.4)}, True),
    ("Straw_1_Basket.fbx", "jp_basket", 300, None, {}, False),
]
# The bamboo clump: how many stalks, their height (m), how far apart, how much they lean; its leaves.
CLUMP = {"stalks": 9, "high": (5.5, 8.0), "spread": 0.75, "lean": 0.12, "leaves": 14, "leaf": (0.26, 0.4, 0.14)}
# (how dark the ground's dirt at a thing's foot, and how far up, share of its height; each face's own
# shade)
DIRT = 0.72
DIRT_UP = 0.25
SHADE = 0.05
# (how rough everything is - wood, plaster, tile and stone, nothing glossy)
ROUGH = 0.88

FOOTPRINTS = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def load(path, name):
    """The file's meshes joined into one object named `name`, its middle over the origin, on z = 0."""
    clear()
    bpy.ops.import_scene.fbx(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons) > 0]
    for o in bpy.context.scene.objects:
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    centre(obj)
    return obj


def centre(obj):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    shift = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    for v in obj.data.vertices:
        v.co = v.co - shift


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def material_of(name):
    key = name.split(".")[0].lower()
    for k in sorted(PALETTE, key=len, reverse=True):
        if key.startswith(k) or k in key:
            return k
    return "rock"


def coloured(obj, own, dirt, seed):
    """Its vertex colour: each face its material's colour (or the thing's own), a shade of its own,
    darker low down."""
    me = obj.data
    mats = [material_of(m.name) if m else "rock" for m in me.materials] or ["rock"]
    face_kind = [mats[p.material_index] if p.material_index < len(mats) else "rock" for p in me.polygons]
    if not me.color_attributes.get("Col"):
        me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    col = me.color_attributes["Col"]
    h = max(float(np.array([v.co.z for v in me.vertices]).max()), 0.01)
    rng = np.random.default_rng(seed)
    for p, kind in zip(me.polygons, face_kind):
        base = own.get(kind, PALETTE[kind])
        shade = 1.0 + (rng.random() - 0.5) * 2.0 * SHADE
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            k = (DIRT + (1.0 - DIRT) * min(1.0, z / (h * DIRT_UP))) if dirt else 1.0
            c = [min(1.0, base[j] * shade * k) for j in range(3)]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
    # One plain material: the colour is the vertex colour's.
    me.materials.clear()
    m = bpy.data.materials.get("JpVertex")
    if m is None:
        m = bpy.data.materials.new("JpVertex")
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = ROUGH
    me.materials.append(m)


def thin(obj, most):
    bpy.context.view_layer.objects.active = obj
    if tris(obj) > most:
        flat = obj.modifiers.new("flat", "DECIMATE")
        flat.decimate_type = "DISSOLVE"
        flat.angle_limit = math.radians(1.0)
        flat.delimit = {"MATERIAL"}
        bpy.ops.object.modifier_apply(modifier="flat")
        tri = obj.modifiers.new("tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier="tri")
    have = tris(obj)
    if have > most:
        dec = obj.modifiers.new("thin", "DECIMATE")
        dec.ratio = most / have
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")


def sized(obj, high):
    if high is None:
        return
    k = high / max(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co = v.co * k


def footprint(obj, key, extra=None):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    size = pts.max(0) - pts.min(0)
    FOOTPRINTS[key] = {"size": [round(float(size[0]), 3), round(float(size[1]), 3), round(float(size[2]), 3)],
                       "tris": tris(obj)}
    if extra:
        FOOTPRINTS[key].update(extra)


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=False, export_normals=True,
                              export_materials="EXPORT", export_vertex_color="ACTIVE")
    print("WROTE", path, os.path.getsize(path), tris(obj))


def bamboo_clump():
    """Our own clump of bamboo: the set's stalk, drawn up to a grove's height, CLUMP's stalks of it
    leaning their own ways, a crown of leafy blobs up their top half."""
    stalk = load(os.path.join(SRC, "Bamboo_1.fbx"), "jp_bamboo")
    coloured(stalk, {}, False, 3)
    rng = np.random.default_rng(17)
    parts = []
    for i in range(CLUMP["stalks"]):
        o = stalk.copy()
        o.data = stalk.data.copy()
        bpy.context.scene.collection.objects.link(o)
        high = rng.uniform(*CLUMP["high"])
        a = rng.random() * math.tau
        r = math.sqrt(rng.random()) * CLUMP["spread"]
        o.scale = (1.6, 1.6, high)
        o.rotation_euler = (rng.normal(0, CLUMP["lean"]), rng.normal(0, CLUMP["lean"]), rng.random() * math.tau)
        o.location = (math.cos(a) * r, math.sin(a) * r, 0.0)
        parts.append(o)
    bpy.data.objects.remove(stalk)
    leaf = bpy.data.materials.get("JpVertex")
    for i in range(CLUMP["leaves"]):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
        b = bpy.context.active_object
        s = rng.uniform(0.6, 1.1)
        b.scale = (s * rng.uniform(1.0, 1.6), s * rng.uniform(1.0, 1.6), s * 0.55)
        a = rng.random() * math.tau
        r = rng.uniform(0.2, CLUMP["spread"] + 0.6)
        b.location = (math.cos(a) * r, math.sin(a) * r, rng.uniform(CLUMP["high"][0] * 0.5, CLUMP["high"][1] * 0.95))
        b.rotation_euler = (rng.normal(0, 0.3), rng.normal(0, 0.3), rng.random() * math.tau)
        me = b.data
        me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for p in me.polygons:
            shade = 1.0 + (rng.random() - 0.5) * 0.3
            for li in p.loop_indices:
                c = [min(1.0, CLUMP["leaf"][j] * shade) for j in range(3)]
                me.color_attributes["Col"].data[li].color = (c[0], c[1], c[2], 1.0)
        me.materials.append(leaf)
        parts.append(b)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "jp_bamboo"
    centre(obj)
    footprint(obj, "jp_bamboo")
    export(obj, os.path.join(OUT, "jp_bamboo.glb"))


def lamp_at(obj, share):
    """A lantern's lamp (m, as the game has it: x across, y up, z deep): over its middle, `share` of
    its height up - where its light box is."""
    pts = np.array([v.co[:] for v in obj.data.vertices])
    h = pts[:, 2].max()
    return [0.0, round(float(h * share), 3), 0.0]


os.makedirs(OUT, exist_ok=True)
for k, (src, ours, most, high, own, dirt) in enumerate(THINGS):
    obj = load(os.path.join(SRC, src), ours)
    sized(obj, high)
    # (thinned while its parts still know what they're made of - flat faces of two kinds never merged)
    thin(obj, most)
    coloured(obj, own, dirt, 40 + k)
    extra = None
    if ours == "jp_toro":
        extra = {"lamp": lamp_at(obj, 0.62)}
    elif ours == "jp_lamp":
        extra = {"lamp": lamp_at(obj, 0.8)}
    footprint(obj, ours, extra)
    export(obj, os.path.join(OUT, ours + ".glb"))
bamboo_clump()
json.dump(FOOTPRINTS, open(os.path.join(OUT, "jp_assets.json"), "w"), indent=1, sort_keys=True)
print("FOOTPRINTS", json.dumps(FOOTPRINTS))
