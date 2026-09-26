"""Render the user's nature packs into game sprites, and write the catalog
the game reads them from (scripts/nature_catalog.gd).

User request: many map styles, so the picture isn't monotonous, from the
packs the user supplied (art_src/packs/):
  lowpoly_tree_collection_01.fbx  200 trees; their colour came from a
      palette texture (color_1024x1024.jpg) that didn't come with them. Each
      face's UVs sit on one spot of that palette: bark swatches up top
      (v > 52/64), four leaf swatches along the middle, shaded top to
      bottom. The palette is rebuilt here (make_palette) with whatever leaf
      and bark colour a style wants - the same shapes serve the autumn,
      meadow, snow and ink-painting looks.
  low_poly_set.fbx  flat-coloured: conifers (two snowy), palms, sago
      palms, baobabs, banana plants, monstera, three huge banyan-like trees,
      round meadow trees, bushes on rocks, coloured rocks and mossy stones.
  rocks_stylized.fbx, assorted_rocks.fbx  rocks whose textures didn't come
      with them: painted stone colours with grime and ambient occlusion
      (render_props.paint).

Each model goes through the same 55deg pipeline as every other sprite
(render_sprite.py): moved so its ground footprint sits on the origin,
scaled to a target height (or width, for rocks) in world units, one tight
camera per model (bounds + PAD, sides rounded up to multiples of 8), the
normal map at the original density and the albedo at Art.DENSITY x.

  python tools/render_packs.py [--only NAME_PREFIX] [--catalog-only]

Writes assets/sprites/<dir>/<name>_55deg_{albedo,normal}.png, the render
records to art_src/packs/manifest.json, and scripts/nature_catalog.gd.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
from render_props import paint  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
PACKS = os.path.join(ROOT, "art_src", "packs")
SPRITES = os.path.join(ROOT, "assets", "sprites")
MANIFEST = os.path.join(PACKS, "manifest.json")
CATALOG = os.path.join(ROOT, "scripts", "nature_catalog.gd")

DENSITY = 27.108          # texture px per world unit (original density)
NODE_PX = DENSITY * 0.5   # node-local px per unit (sprites drawn at 0.5)
PAD = 0.12
HD = 2
SIN55 = math.sin(math.radians(55.0))

COLLECTION = "lowpoly_tree_collection_01.fbx"
LOWPOLY = "low_poly_set.fbx"
STYLIZED = "rocks_stylized.fbx"
ASSORTED = "assorted_rocks.fbx"

# Leaf / bark colours (linear RGB) for the rebuilt palette.
LEAF = {
    "orange": (0.62, 0.20, 0.04), "red": (0.48, 0.07, 0.04), "gold": (0.62, 0.40, 0.06),
    "rust": (0.40, 0.13, 0.04),
    "fresh": (0.16, 0.36, 0.08), "deep": (0.06, 0.22, 0.07), "lime": (0.26, 0.42, 0.08),
    "ink": (0.07, 0.20, 0.13), "pine_dark": (0.05, 0.17, 0.10),
}
BARK = {"brown": (0.20, 0.10, 0.05), "grey": (0.16, 0.13, 0.11), "dark": (0.09, 0.07, 0.06)}
SNOW = (0.80, 0.86, 0.95)

# Painted rock colours: (base, grime).
STONE = {
    "slate": ((0.20, 0.21, 0.24), (0.08, 0.08, 0.09)),
    "granite": ((0.30, 0.29, 0.27), (0.12, 0.11, 0.10)),
    "sandstone": ((0.45, 0.30, 0.17), (0.20, 0.12, 0.07)),
    "moss": ((0.22, 0.24, 0.19), (0.08, 0.14, 0.05)),
}


def m(name, src, objects, directory, kind, family, height=None, width=None, **opts):
    return dict(name=name, src=src, objects=objects, dir=directory, kind=kind, family=family,
                height=height, width=width, **opts)


def collection_tree(idx, name, family, directory, height, leaf, bark="brown", snow=False):
    return m(name, COLLECTION, ["%02d" % idx], directory, "tree", family, height=height,
             palette=(leaf, bark), snow=snow)


MODELS = []
# Autumn broadleaf: the collection's broadleaf shapes, in orange, red, gold
# and rust.
for i, (idx, leaf) in enumerate([(49, "orange"), (51, "red"), (53, "gold"), (55, "orange"), (57, "rust"),
                                 (61, "red"), (64, "gold"), (67, "orange"), (69, "red"), (122, "gold"),
                                 (131, "orange"), (142, "rust")]):
    MODELS.append(collection_tree(idx, "autumn_%d" % (i + 1), "autumn", "autumn_tree",
                                  8.5, leaf))
# Meadow: round and lollipop trees in fresh greens.
for i, (idx, leaf, h) in enumerate([(11, "fresh", 8.0), (16, "lime", 8.0), (81, "deep", 6.5), (97, "fresh", 6.5),
                                    (100, "lime", 7.0), (104, "fresh", 8.0), (107, "deep", 9.0), (110, "lime", 7.0)]):
    MODELS.append(collection_tree(idx, "meadow_%d" % (i + 1), "meadow", "meadow_tree", h, leaf))
# Ink-painting stone forest: windswept umbrella and bonsai shapes, dark.
for i, (idx, h) in enumerate([(52, 8.5), (54, 9.5), (58, 10.0), (59, 10.0), (60, 8.0), (62, 8.5), (64, 9.0)]):
    MODELS.append(collection_tree(idx, "bonsai_%d" % (i + 1), "bonsai", "bonsai_tree", h, "ink", "grey"))
# Snow: the collection's pines and bare trees dusted with snow.
for i, idx in enumerate([151, 153, 155, 165, 161, 163, 166, 21, 23, 31]):
    MODELS.append(collection_tree(idx, "snow_pine_%d" % (i + 1), "snow_pine", "snow_tree", 10.0,
                                  "pine_dark", "dark", snow=True))
for i, idx in enumerate([173, 175, 177, 183, 185, 187, 190]):
    MODELS.append(collection_tree(idx, "snow_bare_%d" % (i + 1), "snow_bare", "snow_tree", 9.5,
                                  "pine_dark", "grey", snow=True))

# low_poly_set: conifers (conifer5 .005 and conifer7 are the snowy ones).
for i, obj in enumerate(["conifer1_Cylinder.002", "conifer1_Cylinder.003", "conifer2_Cylinder.001",
                         "conifer3_Cylinder.001", "conifer4_Cylinder.001", "conifer5_Cylinder.004",
                         "conifer5_Cylinder.006", "conifer6_Cylinder.001"]):
    MODELS.append(m("conifer_%d" % (i + 1), LOWPOLY, [obj], "conifer", "tree", "conifer", height=11.0))
for i, obj in enumerate(["conifer5_Cylinder.005", "conifer7_Cylinder.002"]):
    MODELS.append(m("snow_conifer_%d" % (i + 1), LOWPOLY, [obj], "snow_tree", "tree", "snow_pine", height=11.0))
for i, obj in enumerate(["palm_1", "palm_2", "palm_3", "palm_4", "palm_5", "palm_6"]):
    MODELS.append(m("palm2_%d" % (i + 1), LOWPOLY, [obj], "jungle_tree", "tree", "palm2", height=11.0))
for i, obj in enumerate(["palm_7", "palm_8"]):
    MODELS.append(m("sago_%d" % (i + 1), LOWPOLY, [obj], "jungle_tree", "tree", "sago", height=7.0))
for i, (obj, h) in enumerate([("tree_4", 12.0), ("tree_5", 10.5), ("tree_6", 8.5)]):
    MODELS.append(m("baobab_%d" % (i + 1), LOWPOLY, [obj], "jungle_tree", "tree", "baobab", height=h))
for i, (obj, h) in enumerate([("baban_1", 8.0), ("banan_2", 7.0), ("banan_3", 5.0)]):
    MODELS.append(m("banana_%d" % (i + 1), LOWPOLY, [obj], "jungle_tree", "tree", "banana", height=h))
for i, (obj, h) in enumerate([("tree_1", 15.0), ("tree_2", 15.0), ("tree_3", 16.0)]):
    MODELS.append(m("banyan_%d" % (i + 1), LOWPOLY, [obj], "jungle_tree", "tree", "banyan", height=h,
                    max_width=12.0))
ROUND_TREES = [
    ["tree1_Icosphere.01%d" % k for k in range(1, 8)],
    ["tree2_Icosphere.004", "tree2_Icosphere.005"],
    ["tree3_Icosphere.003", "tree3_Icosphere.005"],
    ["tree4_Icosphere.002", "tree4_Icosphere.003"],
    ["tree5_Cube.0%s" % k for k in ("10", "11", "12", "14", "15", "16", "17")],
    ["tree6_Icosphere.005", "tree6_Icosphere.006", "tree6_Icosphere.007"],
    ["Cube.001", "tree3_Icosphere.006", "tree5_Cube.018", "tree5_Cube.019"],
]
for i, objs in enumerate(ROUND_TREES):
    MODELS.append(m("round_%d" % (i + 1), LOWPOLY, objs, "meadow_tree", "tree", "round", height=8.5))
# Bushes: foliage balls on a rock, and the tropical plants.
BUSHES = [
    ["Plane.017", "tree3_Icosphere.007"], ["Plane.010", "tree6_Icosphere.008"],
    ["Plane.011", "tree1_Icosphere.018"], ["Plane.012", "tree2_Icosphere.006"],
    ["Plane.015", "tree1_Icosphere.020"], ["Plane.016", "tree1_Icosphere.021"],
]
for i, objs in enumerate(BUSHES):
    MODELS.append(m("rock_bush_%d" % (i + 1), LOWPOLY, objs, "bush2", "bush", "rock_bush", width=3.6))
for i, (obj, w) in enumerate([("Plane.103", 4.2), ("Plane.109", 3.8), ("Plane.111", 3.2)]):
    MODELS.append(m("monstera_%d" % (i + 1), LOWPOLY, [obj], "bush2", "bush", "monstera", width=w))

# Rocks. low_poly_set: six shapes in four colours; grey and red kept.
for i, (obj, w) in enumerate([("Rock Type1 04 mesh.001", 2.4), ("Rock Type2 01 mesh.001", 4.2),
                              ("Rock Type3 03 mesh.001", 3.4), ("Rock Type4 04 mesh.001", 3.4),
                              ("Rock Type5 03 mesh.001", 4.2), ("Rock Type6 02 mesh.001", 4.2)]):
    MODELS.append(m("grey_rock_%d" % (i + 1), LOWPOLY, [obj], "rock2", "rock", "grey", width=w,
                    recolor=(0.17, 0.17, 0.18)))
for i, (obj, w) in enumerate([("Rock Type1 02 mesh.001", 4.4), ("Rock Type2 02 mesh.001", 4.2),
                              ("Rock Type3 04 mesh.001", 3.2), ("Rock Type5 04 mesh.001", 2.6)]):
    MODELS.append(m("red_rock_%d" % (i + 1), LOWPOLY, [obj], "rock2", "rock", "red", width=w))
for i, (obj, w) in enumerate([("stone_with_moss_2.001", 4.4), ("stone_with_moss_3.001", 4.6),
                              ("stone_with_moss_7.001", 3.8), ("stone_with_moss_1.001", 3.0)]):
    MODELS.append(m("moss_stone_%d" % (i + 1), LOWPOLY, [obj], "rock2", "rock", "mossy", width=w))
for i, (obj, w) in enumerate([("stone_2.001", 4.4), ("stone_3.001", 4.6), ("stone_7.001", 3.8)]):
    MODELS.append(m("stone_%d" % (i + 1), LOWPOLY, [obj], "rock2", "rock", "stone", width=w))
# rocks_stylized: tall slabs and boulders (its parts, by size).
STYLIZED_PARTS = None  # filled in from the file (largest first)
for i in range(6):
    MODELS.append(m("pillar_%d" % (i + 1), STYLIZED, ["#%d" % i], "rock2", "rock", "pillar",
                    height=None, width=None, fit=6.2 if i < 3 else 4.0, paint="slate"))
# assorted_rocks: smooth boulders in sandstone and granite.
for i, (obj, look, w) in enumerate([("AR01", "sandstone", 4.2), ("AR05", "sandstone", 3.4), ("AR07", "granite", 4.0),
                                    ("AR08", "granite", 4.2), ("AR16", "sandstone", 4.8), ("AR20", "granite", 3.0),
                                    ("AR25", "sandstone", 3.8), ("AR31", "granite", 3.6)]):
    MODELS.append(m("boulder2_%d" % (i + 1), ASSORTED, [obj], "rock2", "rock",
                    "sand" if look == "sandstone" else "granite", width=w, paint=look))


def make_palette(leaf, bark):
    """The collection's palette, rebuilt: bark swatches for v >= 52/64 (lighter
    up the swatch), leaf swatches below (all one hue, lighter up the swatch)."""
    key = "pal_%s_%s" % (leaf, bark)
    if key in bpy.data.images:
        return bpy.data.images[key]
    n = 256
    g = (np.arange(n) + 0.5) / n * 64.0
    u, v = np.meshgrid(g, g)
    img = np.ones((n, n, 4), dtype=np.float32)
    bark_mask = v >= 52
    bark_shade = 0.7 + 0.5 * np.clip((v - 56) / 6, 0, 1) + 0.08 * np.clip((u - 16) / 4, 0, 1)
    leaf_shade = 0.62 + 0.62 * np.clip((v - 43) / 7, 0, 1)
    for c in range(3):
        img[..., c] = np.where(bark_mask, BARK[bark][c] * bark_shade, LEAF[leaf][c] * leaf_shade)
    im = bpy.data.images.new(key, n, n)
    im.colorspace_settings.name = 'Linear Rec.709'
    im.pixels.foreach_set(np.clip(img, 0, 1).ravel())
    return im


def snow_over(mat):
    """Snow on the upward faces: Base Color mixed toward SNOW by the world
    normal's up component."""
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    base = bsdf.inputs['Base Color']
    if base.is_linked:
        src = base.links[0].from_socket
    else:
        rgb = nt.nodes.new('ShaderNodeRGB')
        rgb.outputs[0].default_value = base.default_value
        src = rgb.outputs[0]
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Normal'], sep.inputs[0])
    rng = nt.nodes.new('ShaderNodeMapRange')
    rng.inputs['From Min'].default_value = 0.35
    rng.inputs['From Max'].default_value = 0.7
    nt.links.new(sep.outputs['Z'], rng.inputs['Value'])
    # Broken up by noise, so it lies in patches on the tiers and branches
    # rather than coating every upward face.
    coord = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 4.0
    noise.inputs['Detail'].default_value = 2.0
    nt.links.new(coord.outputs['Generated'], noise.inputs['Vector'])
    patch = nt.nodes.new('ShaderNodeMapRange')
    patch.inputs['From Min'].default_value = 0.42
    patch.inputs['From Max'].default_value = 0.58
    nt.links.new(noise.outputs['Fac'], patch.inputs['Value'])
    both = nt.nodes.new('ShaderNodeMath')
    both.operation = 'MULTIPLY'
    nt.links.new(rng.outputs['Result'], both.inputs[0])
    nt.links.new(patch.outputs['Result'], both.inputs[1])
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.inputs[7].default_value = (*SNOW, 1.0)
    nt.links.new(src, mix.inputs[6])
    nt.links.new(both.outputs['Value'], mix.inputs['Factor'])
    nt.links.new(mix.outputs[2], base)


def shade_over(mat, ao_distance):
    """Flat-coloured low-poly art reads as cut-out cards next to the other
    sprites, whose textures carry their own light and dark: bake in ambient
    occlusion and a soft light from above into the albedo."""
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    base = bsdf.inputs['Base Color']
    if base.is_linked:
        src = base.links[0].from_socket
    else:
        rgb = nt.nodes.new('ShaderNodeRGB')
        rgb.outputs[0].default_value = base.default_value
        src = rgb.outputs[0]
    ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = ao_distance
    ao.samples = 16
    ao_lift = nt.nodes.new('ShaderNodeMapRange')
    ao_lift.inputs['To Min'].default_value = 0.55
    nt.links.new(ao.outputs['AO'], ao_lift.inputs['Value'])
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    top = nt.nodes.new('ShaderNodeVectorMath')
    top.operation = 'DOT_PRODUCT'
    top.inputs[1].default_value = (0.35, -0.25, 0.9)
    nt.links.new(geo.outputs['Normal'], top.inputs[0])
    top_lift = nt.nodes.new('ShaderNodeMapRange')
    top_lift.inputs['From Min'].default_value = -0.4
    top_lift.inputs['To Min'].default_value = 0.72
    top_lift.inputs['To Max'].default_value = 1.1
    nt.links.new(top.outputs['Value'], top_lift.inputs['Value'])
    light = nt.nodes.new('ShaderNodeMath')
    light.operation = 'MULTIPLY'
    nt.links.new(ao_lift.outputs['Result'], light.inputs[0])
    nt.links.new(top_lift.outputs['Result'], light.inputs[1])
    mul = nt.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    nt.links.new(src, mul.inputs[6])
    nt.links.new(light.outputs['Value'], mul.inputs[7])
    nt.links.new(mul.outputs[2], base)


def import_pack(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(PACKS, src))
    for o in bpy.context.scene.objects:
        o.animation_data_clear()
    for mat in bpy.data.materials:
        if mat.use_nodes:
            bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is not None:
                for link in list(bsdf.inputs['Alpha'].links):
                    mat.node_tree.links.remove(link)
                bsdf.inputs['Alpha'].default_value = 1.0
        mat.blend_method = 'OPAQUE'
    bpy.context.view_layer.update()


def keep_only(names):
    """Keep these meshes (world transforms kept), delete everything else."""
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == 'MESH']
    if names[0].startswith("#"):
        # Parts of a set picked by size rank (largest first).
        def size(o):
            return max(o.dimensions)
        ranked = sorted(meshes, key=size, reverse=True)
        keep = [ranked[int(n[1:])] for n in names]
    else:
        keep = [bpy.data.objects[n] for n in names]
    for o in keep:
        w = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = w
    for o in list(scene.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    return keep


def world_points(meshes):
    return [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]


def normalize(meshes, spec):
    """Footprint centre to the origin, ground to z = 0, scaled to the target."""
    pts = world_points(meshes)
    z0 = min(p.z for p in pts)
    z1 = max(p.z for p in pts)
    base = [p for p in pts if p.z < z0 + 0.12 * (z1 - z0)]
    cx = (min(p.x for p in base) + max(p.x for p in base)) / 2
    cy = (min(p.y for p in base) + max(p.y for p in base)) / 2
    for o in meshes:
        o.location -= Vector((cx, cy, z0))
    bpy.context.view_layer.update()
    pts = world_points(meshes)
    h = max(p.z for p in pts)
    w = max(max(p.x for p in pts) - min(p.x for p in pts), max(p.y for p in pts) - min(p.y for p in pts))
    if spec.get("fit"):
        s = spec["fit"] / max(h, w)
    elif spec.get("height"):
        s = spec["height"] / h
        if spec["kind"] == "tree":
            # Wide canopies kept to about the old trees' spread.
            s = min(s, spec.get("max_width", 7.0) / w)
    else:
        s = spec["width"] / w
    for o in meshes:
        o.location *= s
        o.scale *= s
    bpy.context.view_layer.update()


def dress(meshes, spec):
    if spec.get("palette"):
        leaf, bark = spec["palette"]
        pal = make_palette(leaf, bark)
        for mat in {s.material for o in meshes for s in o.material_slots if s.material}:
            for n in mat.node_tree.nodes:
                if n.type == 'TEX_IMAGE':
                    n.image = pal
                    n.interpolation = 'Closest'
    if spec.get("paint"):
        base, grime = STONE[spec["paint"]]
        mat = paint("stone_" + spec["paint"], base, grime, scale=3.0, amount=0.6)
        for o in meshes:
            o.data.materials.clear()
            o.data.materials.append(mat)
    if spec.get("recolor"):
        for mat in {s.material for o in meshes for s in o.material_slots if s.material}:
            bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
            bsdf.inputs['Base Color'].default_value = (*spec["recolor"], 1.0)
    if spec.get("snow"):
        for mat in {s.material for o in meshes for s in o.material_slots if s.material}:
            snow_over(mat)
    if not spec.get("paint"):
        pts = world_points(meshes)
        size = max(max(p.z for p in pts), 1.0)
        for mat in {s.material for o in meshes for s in o.material_slots if s.material}:
            shade_over(mat, 0.12 * size)


def render_model(spec):
    import_pack(spec["src"])
    meshes = keep_only(spec["objects"])
    normalize(meshes, spec)
    dress(meshes, spec)
    b = rs.screen_bounds(meshes)
    w = math.ceil((b["max_x"] - b["min_x"] + 2 * PAD) * DENSITY / 8) * 8
    h = math.ceil((b["max_y"] - b["min_y"] + 2 * PAD) * DENSITY / 8) * 8
    cx = (b["min_x"] + b["max_x"]) / 2
    cy = (b["min_y"] + b["max_y"]) / 2
    rs.setup_scene(cy, max(w, h) / DENSITY, w, h, cx)
    out_dir = os.path.join(SPRITES, spec["dir"])
    os.makedirs(out_dir, exist_ok=True)
    prefix = os.path.join(out_dir, spec["name"] + "_55deg")
    rs.rewire_materials(meshes, "normal")
    rs.render_pass(prefix + "_normal.png", "normal")
    scene = bpy.context.scene
    scene.render.resolution_x = w * HD
    scene.render.resolution_y = h * HD
    rs.rewire_materials(meshes, "albedo")
    rs.render_pass(prefix + "_albedo.png", "albedo")
    grade = spec.get("grade", (0.78, 0.82) if spec["src"] == LOWPOLY else None)
    if grade:
        _grade(prefix + "_albedo.png", *grade)
    record = {k: spec[k] for k in ("name", "dir", "kind", "family")}
    record["offset"] = [round(cx * DENSITY, 2), round(-cy * DENSITY, 2)]
    record["bounds"] = {k: round(v, 4) for k, v in b.items()}
    if spec["kind"] == "rock":
        pts = world_points(meshes)
        top = max(p.z for p in pts)
        base = [p for p in pts if p.z < 0.25 * top]
        record["footprint"] = [min(p.x for p in base), max(p.x for p in base),
                               min(p.y for p in base), max(p.y for p in base)]
    return record


def _grade(path, sat, val):
    """The flat-coloured pack is brighter and more saturated than the rest
    of the art: pulled toward grey and darkened, alpha kept."""
    from PIL import Image
    im = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    rgb = im[..., :3]
    grey = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    rgb = (grey[..., None] + (rgb - grey[..., None]) * sat) * val
    im[..., :3] = np.clip(rgb, 0, 1)
    Image.fromarray((im * 255 + 0.5).astype(np.uint8)).save(path)


def rect(x, y, w, h):
    return "Rect2(%.1f, %.1f, %.1f, %.1f)" % (x, y, w, h)


def write_catalog(records):
    by_kind = {"tree": [], "rock": [], "bush": []}
    for r in records:
        by_kind[r["kind"]].append(r)
    lines = [
        "class_name NatureCatalog",
        "",
        "## Generated by tools/render_packs.py from the user's nature packs",
        "## (art_src/packs/) - re-run the tool rather than editing this.",
        "## Textures are paths, loaded when a prop picks that variant, so a map",
        "## only holds the ones it uses.",
        "##",
        "## offset: the sprite's center from the node, in original-density texture",
        "## px (Art.place scales it). fade_rect / hide_rect / footprint: node-local",
        "## px at sprite scale 0.5.",
        "",
    ]

    def paths(r):
        base = "res://assets/sprites/%s/%s_55deg" % (r["dir"], r["name"])
        return '"albedo": "%s_albedo.png", "normal": "%s_normal.png"' % (base, base)

    def off(r):
        return "Vector2(%.2f, %.2f)" % tuple(r["offset"])

    lines.append("const TREES := [")
    for r in by_kind["tree"]:
        b = r["bounds"]
        fade = rect(b["min_x"] * NODE_PX, -b["max_y"] * NODE_PX, (b["max_x"] - b["min_x"]) * NODE_PX,
                    max(b["max_y"] * NODE_PX - 10.0, 12.0))
        lines.append('\t{"name": "%s", %s,\n\t "family": "%s", "offset": %s, "fade_rect": %s},'
                     % (r["name"], paths(r), r["family"], off(r), fade))
    lines.append("]")
    lines.append("")
    lines.append("const ROCKS := [")
    for r in by_kind["rock"]:
        x0, x1, y0, y1 = r["footprint"]
        fp = rect(x0 * NODE_PX, -y1 * NODE_PX * SIN55, (x1 - x0) * NODE_PX, (y1 - y0) * NODE_PX * SIN55)
        lines.append('\t{"name": "%s", %s,\n\t "family": "%s", "offset": %s, "footprint": %s},'
                     % (r["name"], paths(r), r["family"], off(r), fp))
    lines.append("]")
    lines.append("")
    lines.append("const BUSHES := [")
    for r in by_kind["bush"]:
        b = r["bounds"]
        hide = rect(b["min_x"] * NODE_PX, -b["max_y"] * NODE_PX, (b["max_x"] - b["min_x"]) * NODE_PX,
                    (b["max_y"] - max(b["min_y"], -0.4)) * NODE_PX)
        lines.append('\t{"name": "%s", %s,\n\t "family": "%s", "offset": %s, "hide_rect": %s},'
                     % (r["name"], paths(r), r["family"], off(r), hide))
    lines.append("]")
    lines.append("")
    lines.append("")
    lines.append("## The entries of `table` in these families (all when empty).")
    lines.append("static func of_families(table: Array, families: Array) -> Array:")
    lines.append("\tif families.is_empty():")
    lines.append("\t\treturn table")
    lines.append("\treturn table.filter(func(v): return v.family in families)")
    with open(CATALOG, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--catalog-only", action="store_true")
    args = parser.parse_args(argv)
    records = {}
    if os.path.exists(MANIFEST):
        records = {r["name"]: r for r in json.load(open(MANIFEST))}
    if not args.catalog_only:
        for spec in MODELS:
            if args.only and not spec["name"].startswith(args.only):
                continue
            records[spec["name"]] = render_model(spec)
            print("rendered", spec["name"], flush=True)
            with open(MANIFEST, "w") as f:
                json.dump(list(records.values()), f, indent=1)
    order = [s["name"] for s in MODELS]
    write_catalog([records[n] for n in order if n in records])
    print("catalog:", len(records), "entries")


if __name__ == "__main__":
    main()
