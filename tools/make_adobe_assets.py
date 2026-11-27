"""The adobe village's houses and things (user request: the tribal theme dropped, "換成土屋主題" - an
adobe village made from the user's Egyptian houses pack; "素材都要經過你再製，成為我們的資產": the
originals are never committed, only what this makes; docs/RUINED_WORLD.md).

  - adb_house_1..9: the pack's nine mud-brick houses (its low-poly version), each one mesh, its middle
    over the origin, standing on z = 0, thinned to at most MOST triangles; its three tiling pictures
    (the plaster, the raw wood, the rope) cut down (TILE px, normal maps NRM) and toned ours - each
    house earthen (MUD) or lime-washed (LIME), weathered in broad blotches;
  - our own besides (no upload): the tall clay water jar, the domed bread oven, the shade of palm
    fronds on its posts, the well of mud brick with its timber frame, a cluster of pots.

  bpyenv/bin/python tools/make_adobe_assets.py -- PACK_DIR OUT_DIR

PACK_DIR holds egyptian_houses_00N/mesh/lowpoly_egyptian_house_00N.fbx and the shared pictures in
egyptian_houses_001/textures; writes OUT_DIR/adb_*.glb and adb_assets.json (footprints, m).
"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
PACK, OUT = args[:2]
TEX = os.path.join(PACK, "egyptian_houses_001", "textures")
ONLY = [s for s in os.environ.get("ONLY", "").split(",") if s]

TILE = 512
NRM = 256
MOST = 6000
GREY = 0.1
WEATHER = 0.16
# (the plaster's two tones over the pack's pale one: an earthen mud, a lime wash; the wood greyer)
MUD = (0.86, 0.7, 0.52)
LIME = (1.04, 1.0, 0.92)
WOOD = (0.82, 0.76, 0.68)
# (which houses are lime-washed - the rest earthen)
LIMED = {2, 3, 6, 8}
PICTURES = {"Stone": ("T_stone_wall_bc.png", "T_stone_wall_n.png"), "Wood": ("T_wood_raw_bc.png", "T_wood_raw_n_strong.png"),
            "Rope": ("T_rope_BaseColor.png", "T_rope_NormalMap.png")}
# Our own things' colours (vertex colours) and sizes.
CLAY = (0.55, 0.36, 0.22)
MUDBRICK = (0.5, 0.38, 0.26)
TIMBER = (0.3, 0.22, 0.15)
FROND = (0.42, 0.38, 0.2)
DIRT = 0.72
DIRT_UP = 0.25
SHADE = 0.06

FOOTPRINTS = {}
_pictures = {}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _pictures.clear()
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def joined(objs, name):
    bpy.context.view_layer.update()
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA") or (o.type == "MESH" and o not in objs):
            bpy.data.objects.remove(o)
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(objs) > 1:
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
    """At most `most` triangles: flat faces merged first (never across a material or a seam), then
    collapsed a quarter at a time, stopping where it can go no further."""
    bpy.context.view_layer.objects.active = obj
    if tris(obj) > most:
        d = obj.modifiers.new("flat", "DECIMATE")
        d.decimate_type = "DISSOLVE"
        d.angle_limit = math.radians(1.0)
        d.delimit = {"MATERIAL", "UV"}
        bpy.ops.object.modifier_apply(modifier="flat")
        t = obj.modifiers.new("tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier="tri")
    while tris(obj) > most:
        have = tris(obj)
        d = obj.modifiers.new("thin", "DECIMATE")
        d.ratio = max(most / have, 0.25)
        d.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")
        if tris(obj) > have * 0.95:
            break


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


def picture(path, size, tint, name, seed, normal=False):
    """Ours from the pack's tiling picture: `size` px square; a colour one toned by `tint` and
    weathered in blotches that wrap (it still tiles), a normal map only smaller."""
    key = (path, size, tint, normal)
    if key in _pictures:
        return _pictures[key]
    src = bpy.data.images.load(path)
    src.scale(size, size)
    px = np.empty(size * size * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    if not normal:
        rgb = px[..., :3]
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        rgb = (rgb * (1 - GREY) + lum[..., None] * GREY) * np.array(tint, np.float32)
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


def material(base, tint, tag, seed):
    m = bpy.data.materials.new("Adb_%s_%s" % (base, tag))
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.92
    colour, normal = PICTURES[base]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = picture(os.path.join(TEX, colour), TILE, tint, "adb_%s_%s" % (base.lower(), tag), seed)
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    ntex = nt.nodes.new("ShaderNodeTexImage")
    ntex.image = picture(os.path.join(TEX, normal), NRM, (1, 1, 1), "adb_%s_n" % base.lower(), 0, True)
    ntex.image.colorspace_settings.name = "Non-Color"
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(ntex.outputs[0], nmap.inputs["Color"])
    nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
    return m


def footprint(obj, key):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    size = pts.max(0) - pts.min(0)
    FOOTPRINTS[key] = {"size": [round(float(size[0]), 3), round(float(size[1]), 3), round(float(size[2]), 3)],
                       "tris": tris(obj)}


def export(obj, path, textured):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if textured:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_texcoords=True, export_normals=True,
                                  export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=80)
    else:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_texcoords=False, export_normals=True,
                                  export_materials="EXPORT", export_vertex_color="ACTIVE")
    print("WROTE", path, os.path.getsize(path), tris(obj))


def house(i):
    clear()
    bpy.ops.import_scene.fbx(filepath=os.path.join(PACK, "egyptian_houses_%03d" % i, "mesh", "lowpoly_egyptian_house_%03d.fbx" % i))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons) > 0]
    name = "adb_house_%d" % i
    obj = joined(meshes, name)
    thin(obj, MOST)
    limed = i in LIMED
    for k, m in enumerate(obj.data.materials):
        base = m.name.split(".")[0] if m else "Stone"
        base = base if base in PICTURES else "Stone"
        tint = (LIME if limed else MUD) if base == "Stone" else WOOD
        obj.data.materials[k] = material(base, tint, "lime" if limed and base == "Stone" else "mud", 10 + k)
    footprint(obj, name)
    export(obj, os.path.join(OUT, name + ".glb"), True)


# ---------------------------------------------------------------- our own

def painted(obj, colour):
    m = bpy.data.materials.new("own")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1.0)
    obj.data.materials.clear()
    obj.data.materials.append(m)
    return obj


def lathe(profile, sides, name, colour):
    bm = bmesh.new()
    rings = [[bm.verts.new((math.cos(k / sides * math.tau) * r, math.sin(k / sides * math.tau) * r, z))
              for k in range(sides)] for r, z in profile]
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if profile[0][0] > 0.0:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0.0:
        bm.faces.new(rings[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return painted(o, colour)


def box(size, at, name, colour, turn=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler = (0.0, 0.0, turn)
    return painted(o, colour)


def coloured(obj, dirt, seed):
    """Each face its part's colour (its material's), a shade of its own, darker low down."""
    me = obj.data
    cols = [tuple(m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value[:3]) for m in me.materials]
    while len(me.color_attributes):
        me.color_attributes.remove(me.color_attributes[0])
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = col
    h = max(float(np.array([v.co.z for v in me.vertices]).max()), 0.01)
    rng = np.random.default_rng(seed)
    for p in me.polygons:
        base = cols[p.material_index]
        shade = 1.0 + (rng.random() - 0.5) * 2.0 * SHADE
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            k = (DIRT + (1.0 - DIRT) * min(1.0, z / (h * DIRT_UP))) if dirt else 1.0
            c = [min(1.0, base[j] * shade * k) for j in range(3)]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
    me.materials.clear()
    m = bpy.data.materials.new("AdbVertex")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    me.materials.append(m)


def own(name, parts, dirt=True):
    obj = joined(parts, name)
    coloured(obj, dirt, len(name))
    footprint(obj, name)
    export(obj, os.path.join(OUT, name + ".glb"), False)


def jar():
    """The tall clay water jar (zir): narrow foot, full belly, short neck, a rolled lip."""
    clear()
    own("adb_jar", [lathe([(0.12, 0.0), (0.3, 0.25), (0.36, 0.55), (0.3, 0.85), (0.16, 1.0), (0.18, 1.06), (0.15, 1.08),
                           (0.12, 1.02), (0.0, 1.0)], 14, "jar", CLAY)])


def oven():
    """The domed bread oven of mud (tannour): a squat dome with its mouth, on a low plinth."""
    clear()
    dome = lathe([(0.75, 0.0), (0.75, 0.15), (0.72, 0.35), (0.6, 0.7), (0.4, 0.95), (0.15, 1.08), (0.0, 1.1)], 16, "dome", MUDBRICK)
    mouth = box((0.4, 0.2, 0.36), (0.0, -0.66, 0.36), "mouth", (0.12, 0.09, 0.07))
    plinth = box((1.7, 1.7, 0.12), (0.0, 0.0, 0.06), "plinth", MUDBRICK)
    own("adb_oven", [dome, mouth, plinth])


def shade():
    """The shade: four timber posts, beams across, a mat of palm fronds laid over them."""
    clear()
    parts = []
    for x in (-1.2, 1.2):
        for y in (-0.9, 0.9):
            parts.append(box((0.1, 0.1, 2.3), (x, y, 1.15), "post", TIMBER))
    for y in (-0.9, 0.9):
        parts.append(box((2.7, 0.1, 0.1), (0.0, y, 2.3), "beam", TIMBER))
    for k in range(9):
        x = -1.2 + k * 0.3
        parts.append(box((0.08, 2.1, 0.06), (x, 0.0, 2.38), "rafter", TIMBER))
    for k in range(7):
        y = -0.9 + k * 0.3
        parts.append(box((2.8, 0.34, 0.05), (0.0, y, 2.45 + 0.02 * (k % 2)), "frond", FROND, turn=0.04 * (k - 3)))
    own("adb_shade", parts, dirt=False)


def well():
    """The well: a ring of mud brick, a timber frame over it, its beam and its pulley."""
    clear()
    ring = lathe([(0.75, 0.0), (0.78, 0.7), (0.66, 0.75), (0.55, 0.7), (0.55, 0.1), (0.0, 0.1)], 14, "ring", MUDBRICK)
    parts = [ring, box((0.12, 0.12, 2.0), (-0.72, 0, 1.0), "post", TIMBER), box((0.12, 0.12, 2.0), (0.72, 0, 1.0), "post", TIMBER),
             box((1.6, 0.12, 0.12), (0, 0, 1.95), "beam", TIMBER)]
    pulley = lathe([(0.0, -0.05), (0.14, -0.05), (0.14, 0.05), (0.0, 0.05)], 10, "pulley", TIMBER)
    pulley.rotation_euler = (math.pi / 2, 0.0, 0.0)
    pulley.location = (0.0, 0.0, 1.78)
    parts.append(pulley)
    own("adb_well", parts)


def pots():
    """A cluster of clay pots of three sizes, one lying on its side."""
    clear()
    parts = []
    for (x, y, s, lying) in ((0.0, 0.0, 1.0, False), (0.42, 0.18, 0.75, False), (-0.35, 0.3, 0.6, False), (0.2, -0.45, 0.65, True)):
        p = lathe([(0.1 * s, 0.0), (0.24 * s, 0.18 * s), (0.26 * s, 0.32 * s), (0.14 * s, 0.5 * s), (0.15 * s, 0.55 * s),
                   (0.0, 0.53 * s)], 12, "pot", CLAY)
        p.location = (x, y, 0.24 * s if lying else 0.0)
        if lying:
            p.rotation_euler = (math.pi / 2, 0.0, 0.6)
        parts.append(p)
    own("adb_pots", parts)


STEPS = [("house_%d" % i, (lambda i=i: house(i))) for i in range(1, 10)] + \
    [("jar", jar), ("oven", oven), ("shade", shade), ("well", well), ("pots", pots)]

os.makedirs(OUT, exist_ok=True)
old = os.path.join(OUT, "adb_assets.json")
if os.path.exists(old) and ONLY:
    FOOTPRINTS.update(json.load(open(old)))
for key, step in STEPS:
    if ONLY and key not in ONLY:
        continue
    step()
json.dump(FOOTPRINTS, open(os.path.join(OUT, "adb_assets.json"), "w"), indent=1, sort_keys=True)
print("FOOTPRINTS", json.dumps(FOOTPRINTS))
