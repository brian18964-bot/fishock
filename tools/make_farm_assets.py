"""The countryside's farms, made our own from the user's low-poly farm set (user request: "素材都要
經過你再製，成為我們的資產" - the original is never committed; only what this makes;
docs/RUINED_WORLD.md section 6). The countryside is an ordinary place, not a ruin (user decision),
so nothing here is broken - only toned to sit with the rest of the game:

  - the set's one palette picture (bright gradient swatches) redrawn as ours: every swatch less
    saturated and a little darker, warmed (the whites to cream, the blue roofs to slate), with a fine
    grain so no two faces sharing a swatch shade quite alike;
  - its farmhouses, barns, a water tower or two, a lookout, an open shelter and a row of silos: each
    one mesh, its middle over the origin, standing on z = 0, its flat faces merged and then thinned
    to BUILDING_TRIS triangles at most, darkened low down where the ground's dirt splashes (a vertex
    colour the game's material multiplies by);
  - the yard's things: a lantern post (brought to LANTERN_HIGH m - its lamp's place kept for the
    game's light), two wells, log piles, a barrel, a hay wagon, a wheelbarrow, a trough, a milk can;
    fruit trees for an orchard; pumpkins and leafy rows for a vegetable field.

  bpyenv/bin/python tools/make_farm_assets.py -- FARM.fbx FARM_PALETTE.jpg OUT_DIR

writes OUT_DIR/farm_*.glb and farm_assets.json (each one's footprint and height, m; the lantern's
lamp). ONLY=buildings|yard makes just those.
"""
import colorsys
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
FARM, PALETTE, OUT = args[:3]
ONLY = os.environ.get("ONLY", "")

# (the palette: its size, px; how much less saturated, how much darker; the blues' extra greying,
# the warmth; the grain)
PAL = 512
GREY = 0.22
BLUE_GREY = 0.45
DARK = 0.9
WARM = (1.03, 1.0, 0.9)
GRAIN = 0.05
# (how many triangles each keeps at most: a building, a yard thing, a tree, a crop)
BUILDING_TRIS = 4500
YARD_TRIS = 1500
TREE_TRIS = 2200
CROP_TRIS = 300
# (how dark the ground's dirt at a thing's foot, and how far up it reaches, share of its height)
DIRT = 0.72
DIRT_UP = 0.3
# (the lantern post: its height, m - the set's is 1.9, shorter than a traveller with a hat)
LANTERN_HIGH = 3.0

# The set's things: (its object, our name).
BUILDINGS = [
    ("house_07", "farm_house_1"), ("house_10", "farm_house_2"), ("house_13", "farm_house_3"),
    ("house_16", "farm_house_4"), ("house_06", "farm_house_5"), ("house_09", "farm_house_6"),
    ("farmbuilding_03", "farm_barn_1"), ("farmbuilding_07", "farm_barn_2"), ("farmbuilding_08", "farm_barn_3"),
    ("farmbuilding_06", "farm_barn_4"),
    ("farmstractures_26", "farm_tower_1"), ("farmstractures_22", "farm_tower_2"),
    ("farmstractures_04", "farm_lookout"), ("farmstractures_02", "farm_shelter"), ("farmstractures_19", "farm_silos"),
]
YARD = [
    ("streetlight_a001", "farm_lantern"), ("props_92", "farm_well_1"), ("props_91", "farm_well_2"),
    ("props_90", "farm_logs_1"), ("props_85", "farm_logs_2"), ("barrel_a001", "farm_barrel"),
    ("car_07", "farm_wagon"), ("car_09", "farm_barrow"), ("littlefoodholder_a001", "farm_trough"),
    ("milktank_a002", "farm_milk"),
]
TREES = [("tree_06", "farm_fruit_1"), ("tree_02", "farm_fruit_2"), ("tree_08", "farm_fruit_3")]
CROPS = [("green_06", "farm_pumpkin"), ("green_03", "farm_greens")]

FOOTPRINTS = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # (Blender 5's FBX importer trips over some files' lights: a plain light instead)
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def descendants(o):
    out = [o]
    for c in o.children:
        out += descendants(c)
    return out


def joined(root, name):
    """`root`'s meshes joined into one object named `name`, in the world as they stood, its middle
    over the origin, standing on z = 0."""
    meshes = [o for o in descendants(root) if o.type == "MESH" and len(o.data.polygons) > 0]
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
    pts = np.array([v.co[:] for v in obj.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    shift = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    for v in obj.data.vertices:
        v.co = v.co - shift
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def thin(obj, most):
    """Its flat faces merged first (a low-poly model's walls and roofs lose nothing), then, if it's
    still over `most` triangles, collapsed down to it."""
    bpy.context.view_layer.objects.active = obj
    if tris(obj) > most:
        flat = obj.modifiers.new("flat", "DECIMATE")
        flat.decimate_type = "DISSOLVE"
        flat.angle_limit = math.radians(1.0)
        flat.delimit = {"UV"}
        bpy.ops.object.modifier_apply(modifier="flat")
        tri = obj.modifiers.new("tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier="tri")
    have = tris(obj)
    if have > most:
        dec = obj.modifiers.new("thin", "DECIMATE")
        dec.ratio = most / have
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")


def footprint(obj, key, extra=None):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    size = pts.max(0) - pts.min(0)
    # (x across, y deep, z up - as Blender has them; the game's x and z)
    FOOTPRINTS[key] = {"size": [round(float(size[0]), 3), round(float(size[1]), 3), round(float(size[2]), 3)],
                       "tris": tris(obj)}
    if extra:
        FOOTPRINTS[key].update(extra)


def palette():
    """The set's palette redrawn as ours (see the top)."""
    src = bpy.data.images.load(PALETTE)
    if src.size[0] != PAL:
        src.scale(PAL, PAL)
    px = np.empty(PAL * PAL * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(PAL, PAL, 4)
    rgb = px[..., :3].reshape(-1, 3)
    out = np.empty_like(rgb)
    for i, c in enumerate(rgb):
        h, s, v = colorsys.rgb_to_hsv(*c)
        # (the blues and cyans greyed further - slate roofs, not bright paint)
        blue = max(0.0, 1.0 - abs(h - 0.6) / 0.12)
        s *= 1.0 - GREY - BLUE_GREY * blue
        v *= DARK
        out[i] = colorsys.hsv_to_rgb(h, s, v)
    out = out.reshape(PAL, PAL, 3) * np.array(WARM, dtype=np.float32)
    rng = np.random.default_rng(31)
    grain = 1.0 + (rng.random((PAL // 4, PAL // 4)).repeat(4, 0).repeat(4, 1) - 0.5) * 2.0 * GRAIN
    px[..., :3] = np.clip(out * grain[..., None], 0, 1)
    px[..., 3] = 1.0
    img = bpy.data.images.new("farm_palette", PAL, PAL)
    img.pixels.foreach_set(px.ravel())
    img.pack()
    bpy.data.images.remove(src)
    return img


def material(img):
    m = bpy.data.materials.new("FarmPalette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    return m


def dirtied(obj, seed, dirt=True):
    """Its vertex colour: darker low down (the ground's dirt splashed up), each thing a shade of its
    own."""
    me = obj.data
    if not me.color_attributes.get("Col"):
        me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    col = me.color_attributes["Col"]
    h = max(float(np.array([v.co.z for v in me.vertices]).max()), 0.01)
    rng = np.random.default_rng(seed)
    own = 1.0 + (rng.random() - 0.5) * 0.08
    for poly in me.polygons:
        for li in poly.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            k = (DIRT + (1.0 - DIRT) * min(1.0, z / (h * DIRT_UP))) if dirt else 1.0
            k = min(1.0, k * own)
            col.data[li].color = (k, k, k, 1.0)


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=88,
                              export_vertex_color="ACTIVE")
    print("WROTE", path, os.path.getsize(path), tris(obj))


def lamp_of(obj):
    """The lantern post's lamp (m, as the game has it: x across, y up, z deep): the middle of the
    post's top part that hangs out furthest from its foot."""
    pts = np.array([v.co[:] for v in obj.data.vertices])
    h = pts[:, 2].max()
    top = pts[pts[:, 2] > h * 0.55]
    foot = pts[pts[:, 2] < h * 0.2][:, :2].mean(0)
    far = np.linalg.norm(top[:, :2] - foot, axis=1)
    lamp = top[far > far.max() * 0.7]
    c = lamp.mean(0)
    # (Blender's z up; glTF's y up and its z Blender's -y)
    return [round(float(c[0]), 3), round(float(lamp[:, 2].min()), 3), round(float(-c[1]), 3)]


def make(group, most, dirt=True):
    clear()
    bpy.ops.import_scene.fbx(filepath=FARM)
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o)
    mat = material(palette())
    by_name = {o.name: o for o in bpy.context.scene.objects}
    for k, (src, ours) in enumerate(group):
        obj = joined(by_name[src], ours)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        extra = None
        if ours == "farm_lantern":
            s = LANTERN_HIGH / max(v.co.z for v in obj.data.vertices)
            for v in obj.data.vertices:
                v.co = v.co * s
            extra = {"lamp": lamp_of(obj)}
        thin(obj, most)
        dirtied(obj, 100 + k, dirt)
        footprint(obj, ours, extra)
        export(obj, os.path.join(OUT, ours + ".glb"))


os.makedirs(OUT, exist_ok=True)
info_path = os.path.join(OUT, "farm_assets.json")
if os.path.exists(info_path):
    FOOTPRINTS.update(json.load(open(info_path)))
if ONLY in ("", "buildings"):
    make(BUILDINGS, BUILDING_TRIS)
if ONLY in ("", "yard"):
    make(YARD, YARD_TRIS)
    make(TREES, TREE_TRIS)
    make(CROPS, CROP_TRIS, False)
json.dump(FOOTPRINTS, open(info_path, "w"), indent=1, sort_keys=True)
print("FOOTPRINTS", json.dumps(FOOTPRINTS))
