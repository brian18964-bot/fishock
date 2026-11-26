"""The ruined city's buildings, cars and street things, made our own from the user's packs (user
request: "素材都要經過你再製，成為我們的資產" - the originals are never committed; only what this
makes; docs/RUINED_WORLD.md section 6):

  - its low buildings (Housing_Pack_1: a strip of shops, a long house, two houses with porches and
    arcades): each one mesh, its middle over the origin, standing on z = 0; its pictures cut down to
    TEX px and turned abandoned - greyed, darkened, grimy in blotches - its lit windows put out (the
    emissive maps dropped); its normal maps kept, smaller;
  - the skyline's towers (Buildings-FBX: eight high-rises with baked pictures): each thinned out to
    TOWER_TRIS triangles, its picture the same way abandoned and smaller;
  - the street's things from the farm pack (LowPoly_Farm_02): its jeeps and pickups, an oil drum,
    crates and park benches - their shared palette greyed and darkened, each car dirtied low down
    and rusted in patches (a vertex colour the game's material multiplies by), each car brought to
    CAR_LENGTH m long.

  bpyenv/bin/python tools/make_city_assets.py -- HOUSING.fbx HOUSING_TEX_DIR TOWERS_DIR \\
      TOWER_TEX_DIR FARM.fbx FARM_PALETTE.jpg OUT_DIR

writes OUT_DIR/city_house_{1..4}.glb, city_tower_{1..5}.glb, city_car_{1..4}.glb, city_drum.glb,
city_crate.glb, city_bench_{1,2}.glb and city_assets.json (each one's footprint and height, m).
ONLY=houses|towers|street makes just those.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
HOUSING, HOUSING_TEX, TOWERS, TOWER_TEX, FARM, FARM_TEX, OUT = args[:7]
ONLY = os.environ.get("ONLY", "")

# (pictures: their size, px; the normal maps'; how much greyer and darker, how blotchy the grime)
TEX = 1024
NRM = 512
GREY = 0.3
DARK = 0.78
GRIME = 0.28
# (the towers: how many triangles each keeps; the three whose facades won't thin out that far - too
# heavy for the web build - left out)
TOWER_TRIS = 8000
TOWER_SKIP = {"Building-Big-Wide-01", "Building-Big-Wide-02", "Building-Medium-01"}
# (the cars: how many triangles each keeps)
CAR_TRIS = 3500
# (the cars: their length, m; how dark low down; how much rust)
CAR_LENGTH = 4.4
RUST = (0.42, 0.22, 0.1)
# The housing pack's materials and their pictures.
HOUSE_MATS = {
    "Housing_2_Concrete": "Housing_2", "Housing_2_Metal": "Housing_2_Metal_Wall",
    "Housing_2_RedRoof": "Housing_2_Red_Roof", "Housing_2_Trimsheet": "Housing_2_Trim_Sheet",
    "Housing_3": "Housing_3", "Housing_4": "Housing_4",
}
# The farm pack's things for the street: (its object, our name).
STREET = [("car_03", "city_car_1"), ("car_04", "city_car_2"), ("car_05", "city_car_3"), ("car_06", "city_car_4"),
          ("barrel_a001", "city_drum"), ("cratebox_a004", "city_crate"), ("bench_a001", "city_bench_1"),
          ("bench_d001", "city_bench_2")]

FOOTPRINTS = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # (Blender 5's FBX importer trips over some files' lights: a plain light instead)
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def import_fbx(path):
    bpy.ops.import_scene.fbx(filepath=path)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            # (keep the empties that hold meshes; drop lights and cameras)
            if o.type in ("LIGHT", "CAMERA"):
                bpy.data.objects.remove(o)


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


def footprint(obj, key):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    size = pts.max(0) - pts.min(0)
    # (x across, y deep, z up - as Blender has them; the game's x and z)
    FOOTPRINTS[key] = {"size": [round(float(size[0]), 3), round(float(size[1]), 3), round(float(size[2]), 3)],
                       "tris": sum(len(p.vertices) - 2 for p in obj.data.polygons)}


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
    """A picture of ours from `path`: `size` px; a colour one ("colour") greyed, darkened and grimy,
    a normal map ("normal") only smaller."""
    src = bpy.data.images.load(path)
    if src.size[0] != size:
        src.scale(size, size)
    px = np.empty(size * size * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    if kind == "colour":
        rgb = px[..., :3]
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
        rgb = rgb * (1 - GREY) + lum[..., None] * GREY
        grime = 1.0 - GRIME * np.clip((noise2(size, size, 48, seed) - 0.35) * 2.2, 0, 1)
        fine = 0.92 + 0.08 * noise2(size, size, 6, seed + 1)
        rgb = rgb * DARK * (grime * fine)[..., None]
        px[..., :3] = np.clip(rgb, 0, 1)
    px[..., 3] = 1.0
    img = bpy.data.images.new(name, size, size)
    img.pixels.foreach_set(px.ravel())
    img.pack()
    bpy.data.images.remove(src)
    return img


def textured(name, colour, normal=None, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = colour
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    if normal is not None:
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = normal
        ntex.image.colorspace_settings.name = "Non-Color"
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ntex.outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
    return m


def export(obj, path, colours=False):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
              export_texcoords=True, export_normals=True, export_materials="EXPORT", export_image_format="JPEG",
              export_jpeg_quality=82)
    if colours:
        kw["export_vertex_color"] = "ACTIVE"
    bpy.ops.export_scene.gltf(**kw)
    print("WROTE", path, os.path.getsize(path))


def thin(obj, tris):
    have = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if have > tris:
        bpy.context.view_layer.objects.active = obj
        dec = obj.modifiers.new("thin", "DECIMATE")
        dec.ratio = tris / have
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")


# ---------------------------------------------------------------- the low buildings

def houses():
    clear()
    import_fbx(HOUSING)
    roots = sorted([o for o in bpy.context.scene.objects if o.parent is None and o.name.startswith("Housing_Pack")],
                   key=lambda o: o.name)
    mats = {}
    for k, mat_name in enumerate(HOUSE_MATS):
        base = HOUSE_MATS[mat_name]
        colour = picture(os.path.join(HOUSING_TEX, base + "_albd.tga"), TEX, "colour", "city_" + base.lower(), 20 + k)
        normal = picture(os.path.join(HOUSING_TEX, base + "_nrml.tga"), NRM, "normal", "city_" + base.lower() + "_n", 0)
        mats[mat_name] = textured("City" + base, colour, normal, 0.88 if "Metal" not in base else 0.6)
    names = []
    for i, root in enumerate(roots):
        obj = joined(root, "CityHouse%d" % (i + 1))
        for slot in obj.material_slots:
            key = slot.material.name.split(".")[0] if slot.material else ""
            if key in mats:
                slot.material = mats[key]
        footprint(obj, "city_house_%d" % (i + 1))
        names.append(obj)
    for i, obj in enumerate(names):
        export(obj, os.path.join(OUT, "city_house_%d.glb" % (i + 1)))


# ---------------------------------------------------------------- the skyline

def towers():
    files = sorted(f for f in os.listdir(TOWERS) if f.lower().endswith(".fbx") and os.path.splitext(f)[0] not in TOWER_SKIP)
    for i, f in enumerate(files):
        clear()
        import_fbx(os.path.join(TOWERS, f))
        roots = [o for o in bpy.context.scene.objects if o.parent is None]
        obj = joined(roots[0], "CityTower%d" % (i + 1))
        thin(obj, TOWER_TRIS)
        stem = os.path.splitext(f)[0]
        colour = picture(os.path.join(TOWER_TEX, stem + "_Bake1_PBR_Diffuse.png"), TEX, "colour", "city_tower_%d" % (i + 1), 40 + i)
        normal = picture(os.path.join(TOWER_TEX, stem + "_Bake1_PBR_Normal.png"), NRM, "normal", "city_tower_%d_n" % (i + 1), 0)
        obj.data.materials.clear()
        obj.data.materials.append(textured("CityTower%d" % (i + 1), colour, normal, 0.9))
        footprint(obj, "city_tower_%d" % (i + 1))
        export(obj, os.path.join(OUT, "city_tower_%d.glb" % (i + 1)))


# ---------------------------------------------------------------- the street's things

def street():
    clear()
    import_fbx(FARM)
    palette = picture(FARM_TEX, 512, "colour", "city_palette", 7)
    mat = textured("CityPalette", palette, None, 0.8)
    rng = np.random.default_rng(5)
    by_name = {o.name: o for o in bpy.context.scene.objects}
    for src, ours in STREET:
        root = by_name[src]
        obj = joined(root, ours)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        pts = np.array([v.co[:] for v in obj.data.vertices])
        size = pts.max(0) - pts.min(0)
        if ours.startswith("city_car"):
            # (its long way along x; CAR_LENGTH long)
            if size[1] > size[0]:
                for v in obj.data.vertices:
                    v.co = Vector((v.co.y, -v.co.x, v.co.z))
                size = np.array([size[1], size[0], size[2]])
            k = CAR_LENGTH / size[0]
            for v in obj.data.vertices:
                v.co = v.co * k
            thin(obj, CAR_TRIS)
        # The dirt: darker low down; on a car, rust in patches (a vertex colour).
        me = obj.data
        if not me.color_attributes.get("Col"):
            me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        col = me.color_attributes["Col"]
        h = max(float(np.array([v.co.z for v in me.vertices]).max()), 0.01)
        seed = rng.random() * 100
        for poly in me.polygons:
            for li in poly.loop_indices:
                p = me.vertices[me.loops[li].vertex_index].co
                low = 0.62 + 0.38 * min(1.0, p.z / (h * 0.45))
                c = [low, low, low]
                if ours.startswith("city_car"):
                    r = 0.5 + 0.5 * math.sin(p.x * 2.1 + seed) * math.sin(p.y * 2.7 + seed * 0.7) * math.sin(p.z * 3.1 + seed * 1.3)
                    rust = max(0.0, (r - 0.55) * 2.6)
                    c = [c[j] * (1 - rust) + RUST[j] * rust * 1.6 for j in range(3)]
                col.data[li].color = (min(c[0], 1.0), min(c[1], 1.0), min(c[2], 1.0), 1.0)
        footprint(obj, ours)
        export(obj, os.path.join(OUT, ours + ".glb"), colours=True)


os.makedirs(OUT, exist_ok=True)
info_path = os.path.join(OUT, "city_assets.json")
if os.path.exists(info_path):
    FOOTPRINTS.update(json.load(open(info_path)))
if ONLY in ("", "houses"):
    houses()
if ONLY in ("", "towers"):
    towers()
if ONLY in ("", "street"):
    street()
json.dump(FOOTPRINTS, open(info_path, "w"), indent=1, sort_keys=True)
print("FOOTPRINTS", json.dumps(FOOTPRINTS))
