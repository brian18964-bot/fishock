"""The English village's houses, chapel and tower, made our own from the user's medieval set and
small stone tower (user request: "素材都要經過你再製，成為我們的資產" - the originals are never
committed; only what this makes; docs/RUINED_WORLD.md). An ordinary place, nothing broken (user
decision: only the city is a ruin).

  - the four timber-framed houses and the chapel with its spire: each one mesh, its middle over the
    origin, standing on z = 0, thinned to at most MOST triangles (the chapel CHAPEL_MOST); their
    pictures cut down from 4K (a tiling one to TILE px, a whole one to WHOLE px; the normal maps to
    NRM), toned ours - a little less saturated, warmer, weathered in broad blotches - the set's tiling
    (its readme: stone x4, roof x7...) written into the parts' UVs, so one picture repeats as it
    should;
  - the small stone tower: its own picture missing, so dressed in the set's second stone, made ours
    the same way, wrapped round it.

  bpyenv/bin/python tools/make_england_assets.py -- MEDIEVAL_SET_DIR TOWER.fbx OUT_DIR

writes OUT_DIR/eng_house_{1..4}.glb, eng_chapel.glb, eng_tower.glb and eng_assets.json (each one's
footprint and height, m).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SET, TOWER, OUT = args[:3]
TEX = os.path.join(SET, "textures")

# (pictures: a tiling one's size, a whole one's, a normal map's, px; how much less saturated, how
# much warmer, how much the weathering darkens)
TILE = 512
WHOLE = 768
NRM = 256
GREY = 0.15
WARM = (1.03, 1.0, 0.93)
WEATHER = 0.14
# (the set's tiling - its readme)
TILING = {"stone_1": 4.0, "stone_2": 3.0, "stone_3": 3.0, "wood_2": 5.0, "wood_3": 4.0, "wood_4": 5.0,
          "roof_1": 7.0, "roof_2": 7.5, "roof_3": 7.5}
NORMALS = {"plaster_1": "plaster_1-2", "plaster_2": "plaster_1-2", "roof_1": "roof_1-2-3", "roof_2": "roof_1-2-3",
           "roof_3": "roof_1-2-3", "wood_2": "wood_2-3-4", "wood_3": "wood_2-3-4", "wood_4": "wood_2-3-4"}
# (how many triangles each keeps at most)
MOST = 7000
CHAPEL_MOST = 10000
THINGS = [("th_1.fbx", "eng_house_1"), ("th_2.fbx", "eng_house_2"), ("th_3.fbx", "eng_house_3"),
          ("th_4.fbx", "eng_house_4"), ("th_5.fbx", "eng_chapel")]
# (the tower: its height, m - as made, 5.9 - and how many times the stone repeats round it)
TOWER_HIGH = 6.0
TOWER_TILING = 2.0

FOOTPRINTS = {}
_pictures = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _pictures.clear()
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def noise2(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((h // cell + 2, w // cell + 2)).astype(np.float32)
    ys = np.linspace(0, g.shape[0] - 1.001, h)
    xs = np.linspace(0, g.shape[1] - 1.001, w)
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    ty = (ys - y0)[:, None]
    tx = (xs - x0)[None, :]
    ty = ty * ty * (3 - 2 * ty)
    tx = tx * tx * (3 - 2 * tx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def picture(path, size, kind, name, seed):
    """A picture of ours from the set's: `size` px; a colour one toned and weathered, a normal map
    only smaller."""
    key = (path, size, kind)
    if key in _pictures:
        return _pictures[key]
    src = bpy.data.images.load(path)
    src.scale(size, size)
    px = np.empty(size * size * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    if kind == "colour":
        rgb = px[..., :3]
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
        rgb = (rgb * (1 - GREY) + lum[..., None] * GREY) * np.array(WARM, dtype=np.float32)
        # (weathered in broad blotches - the blotches wrapping, so a tiling picture still tiles)
        n = noise2(size + 64, size + 64, 64, seed)[:size, :size]
        n = (n + np.roll(n, size // 2, 0) + np.roll(n, size // 2, 1)) / 3.0
        rgb = rgb * (1.0 - WEATHER * np.clip((n - 0.4) * 2.5, 0, 1))[..., None]
        px[..., :3] = np.clip(rgb, 0, 1)
    px[..., 3] = 1.0
    img = bpy.data.images.new(name, size, size)
    img.pixels.foreach_set(px.ravel())
    img.pack()
    bpy.data.images.remove(src)
    _pictures[key] = img
    return img


def material(base, seed):
    """Our material for one of the set's (`base`: "stone_1", "plaster_2"...)."""
    m = bpy.data.materials.new("Eng_" + base)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    size = TILE if base in TILING else WHOLE
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = picture(os.path.join(TEX, base + "_base_color.png"), size, "colour", "eng_" + base, seed)
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    nrm_file = os.path.join(TEX, NORMALS.get(base, base) + "_normal.png")
    if os.path.exists(nrm_file):
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = picture(nrm_file, NRM, "normal", "eng_" + NORMALS.get(base, base) + "_n", 0)
        ntex.image.colorspace_settings.name = "Non-Color"
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ntex.outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
    return m


def joined(name):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons) > 0]
    for o in list(bpy.context.scene.objects):
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
    pts = np.array([v.co[:] for v in obj.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    shift = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    for v in obj.data.vertices:
        v.co = v.co - shift
    return obj


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def thin(obj, most):
    have = tris(obj)
    if have > most:
        bpy.context.view_layer.objects.active = obj
        dec = obj.modifiers.new("thin", "DECIMATE")
        dec.ratio = most / have
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")


def tiled(obj):
    """The set's tiling written into the UVs of the parts that tile (and our materials put on)."""
    me = obj.data
    uv = me.uv_layers.active
    bases = [m.name.split(".")[0] if m else "" for m in me.materials]
    for p in me.polygons:
        k = TILING.get(bases[p.material_index], 1.0) if p.material_index < len(bases) else 1.0
        if k != 1.0:
            for li in p.loop_indices:
                uv.data[li].uv = uv.data[li].uv * k
    for i, base in enumerate(bases):
        if base:
            me.materials[i] = material(base, 50 + i)


def footprint(obj, key):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    size = pts.max(0) - pts.min(0)
    FOOTPRINTS[key] = {"size": [round(float(size[0]), 3), round(float(size[1]), 3), round(float(size[2]), 3)],
                       "tris": tris(obj)}


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=80)
    print("WROTE", path, os.path.getsize(path), tris(obj))


os.makedirs(OUT, exist_ok=True)
for src, ours in THINGS:
    clear()
    bpy.ops.import_scene.fbx(filepath=os.path.join(SET, src))
    obj = joined(ours)
    thin(obj, CHAPEL_MOST if ours == "eng_chapel" else MOST)
    tiled(obj)
    footprint(obj, ours)
    export(obj, os.path.join(OUT, ours + ".glb"))

# The small tower: wrapped in the set's second stone.
clear()
bpy.ops.import_scene.fbx(filepath=TOWER)
obj = joined("eng_tower")
k = TOWER_HIGH / max(v.co.z for v in obj.data.vertices)
for v in obj.data.vertices:
    v.co = v.co * k
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.cube_project(cube_size=TOWER_HIGH / TOWER_TILING)
bpy.ops.object.mode_set(mode="OBJECT")
obj.data.materials.clear()
obj.data.materials.append(material("stone_2", 70))
footprint(obj, "eng_tower")
export(obj, os.path.join(OUT, "eng_tower.glb"))
json.dump(FOOTPRINTS, open(os.path.join(OUT, "eng_assets.json"), "w"), indent=1, sort_keys=True)
print("FOOTPRINTS", json.dumps(FOOTPRINTS))
