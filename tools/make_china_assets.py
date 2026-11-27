"""The Chinese village's buildings and things, made our own from the user's uploads (user request:
"開始做中國風第 11 章" and "素材都要經過你再製，成為我們的資產" - the originals are never committed; only
what this makes; docs/RUINED_WORLD.md). An ordinary place, nothing broken (user decision: only the
city is a ruin).

  - cn_hall (the temple hall, the village's landmark) and cn_pavilion (the roadside pavilion): each
    one mesh, its middle over the origin, standing on z = 0, thinned; their pictures cut down from
    4K (WHOLE px, the normal maps NRM px) and toned ours - a little less saturated, warmer,
    weathered in broad blotches;
  - cn_house (the grey stone house): the scanned house cut free of its paved yard (the yard is the
    game's ground, walked on) and made anew as one light shell, its five pictures baked onto it and
    toned ours the same way;
  - cn_tower (the two-storey pavilion with its double eaves): the upload's pictures were never packed
    with it (user: "貼圖檔我找不到，你先用現有的資料參考配色去自己上色"), so it is coloured here by what
    each part was made of (its material's lost picture's name: roof tiles, siding, floor boards, wood,
    paving) - a palette of ours (PALETTE) in a vertex colour, each face a shade of its own, darker
    low down; its bridge and ground left behind, its twelve heavy little lanterns replaced by low ones
    of ours;
  - cn_lamp_*: the garden lantern catalogue's lanterns cut apart (LANTERNS) and coloured by what
    each part is made of the same way (the catalogue's pictures are missing too);
  - cn_shop_*: the Asian street pack's blocks (the user's .mtl gives only flat colours, its pictures
    missing - its colours read and made ours: duller, a little warmer), each block with its balconies,
    frames and signs, sized to a two-storey shop house - a town's newer street;
  - cn_bamboo: a clump of the user's Bambusa vulgaris, light - its culms thinned, a share of its leafy
    sprigs kept and drawn larger, its pictures toned ours (the groves of both the Chinese and the
    Japanese villages);
  - our own besides (no upload): the red lantern post (two paper lanterns hung from a crossbar),
    the glazed water jar, the stone table with its drum stools and the stone well.

  bpyenv/bin/python tools/make_china_assets.py -- hall=Mansion.fbx pavilion=Arbor.fbx \
      textures=TEXTURES_DIR house=untitled25.blend tower=traditional_building.blend \
      lanterns=Garden_Lantern.fbx flats=asianbuildingspack.obj flats_mtl=asianbuildingspack.mtl \
      bamboo=BambusaVulgaris_07.fbx out=OUT_DIR       (the bamboo's pictures beside its .fbx)

writes OUT_DIR/cn_*.glb and cn_assets.json (each one's footprint and height, m; a lantern's lamp).
PREVIEW=1 writes every catalogue lantern and every tenement found to OUT_DIR/preview instead.
"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

ARGS = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:])
OUT = ARGS["out"]
PREVIEW = bool(os.environ.get("PREVIEW"))
ONLY = [s for s in os.environ.get("ONLY", "").split(",") if s]

# (pictures: a whole one's size, a normal map's, px; how much less saturated, how much warmer, how
# much the weathering darkens)
WHOLE = 1024
NRM = 512
HOUSE_PX = 1024
GREY = 0.12
WARM = (1.03, 1.0, 0.94)
WEATHER = 0.12
# (each thing's most triangles; its height, m - None as made)
HALL = (14000, None)
PAVILION = (6000, 5.4)
HOUSE = (int(os.environ.get("HOUSE_MOST", 9000)), 5.6)
TOWER = (9000, 7.2)
FLAT_MOST = 3000
FLAT_HIGH = (6.5, 7.5)
# (the stone house: the walls are what stands higher than this, m - the yard's paving below it; how
# far past the walls the plinth is kept, m)
HOUSE_WALL = 3.2
HOUSE_PLINTH = 0.6
HOUSE_VOXEL = 0.06
HOUSE_CAGE = 0.12
# (the two-storey pavilion: its building's box in the upload's own units - the bridge and the rock
# by it outside; its lanterns' colour)
TOWER_BOX = ((-2.6, -0.9, -0.5), (2.6, 5.5, 9.0))
LANTERN_RED = (0.62, 0.08, 0.05)
LANTERN_GOLD = (0.62, 0.45, 0.16)
# (the bamboo clump: its height, m; its culms' most triangles; how many sprig cards kept, none lower
# than BAMBOO_LOW m, each drawn this much larger; its sprig pictures' size each, px; their tone)
BAMBOO_HIGH = 7.5
BAMBOO_CULMS = 900
BAMBOO_CARDS = 300
BAMBOO_LOW = 1.4
BAMBOO_GROW = 6.5
BAMBOO_STRIP = (128, 512)
BAMBOO_SPRAY = 512
BAMBOO_STAMPS = 22
BAMBOO_TINT = (0.95, 1.0, 0.88)
import tempfile
TMPDIR = tempfile.gettempdir()

# What a self-coloured part is made of, by keywords in its material's name or its lost picture's
# (the first that fits) -> our colour.
PALETTE = [
    ("roofingtiles", (0.15, 0.155, 0.165)), ("rooftiles", (0.17, 0.17, 0.18)), ("roofing", (0.17, 0.17, 0.18)),
    ("woodsiding", (0.42, 0.1, 0.07)), ("woodfloor", (0.34, 0.23, 0.15)), ("wood060", (0.46, 0.1, 0.07)),
    ("wood036", (0.3, 0.2, 0.13)), ("bamboo", (0.52, 0.47, 0.3)), ("paving", (0.44, 0.43, 0.41)),
    ("granite", (0.47, 0.46, 0.44)), ("brick", (0.4, 0.39, 0.37)), ("stone", (0.52, 0.49, 0.43)),
    ("plaster", (0.8, 0.78, 0.72)), ("glass", (0.9, 0.8, 0.58)), ("lamp", (0.9, 0.78, 0.5)),
    ("light", (0.92, 0.8, 0.52)), ("rust", (0.34, 0.24, 0.18)), ("sand", (0.6, 0.56, 0.47)),
    ("tiles14", (0.42, 0.41, 0.4)), ("preview", (0.3, 0.22, 0.15)),
]
# (a material with no name to go by: its own flat colour, duller and warmer)
FLAT_GREY = 0.25
FLAT_WARM = (1.02, 1.0, 0.95)
DIRT = 0.72
DIRT_UP = 0.2
SHADE = 0.05
ROUGH = 0.88
THIN_STEP = 0.25

# The catalogue's lanterns kept (its groups, top row first, left to right - PREVIEW lists them):
# group -> our name, height (m).
LANTERNS = {0: ("cn_lamp_1", 2.3, 0.6), 2: ("cn_lamp_2", 2.5, 0.58), 6: ("cn_lamp_3", 1.9, 0.62),
            12: ("cn_lamp_4", 1.9, 0.6)}
# The street pack's blocks kept (by their shell's name - PREVIEW lists them) -> our name; what else of
# the pack's goes with a shell (within its box, FLAT_PAD past it, m in the pack's units), and what never
# does (its window grilles: a hundred thousand triangles each); a block's parts' own colours.
FLATS = {"Cube.015": "cn_shop_1", "Cube.092": "cn_shop_2", "Cube.117": "cn_shop_3", "Cube.008": "cn_shop_4"}
FLAT_PAD = 1.0
FLAT_SKIP = ["Profil", "Plane", "Material.008"]
FLAT_OWN = {"material.061": (0.18, 0.2, 0.22), "bare_metal": (0.38, 0.38, 0.37)}

FOOTPRINTS = {}
_pictures = {}


# ---------------------------------------------------------------- the common steps

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _pictures.clear()
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def joined(objs, name):
    """`objs` joined into one object named `name` (their transforms applied), its middle over the
    origin, on z = 0."""
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
    centre(obj)
    return obj


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and len(o.data.polygons) > 0]


def centre(obj):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    shift = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    for v in obj.data.vertices:
        v.co = v.co - shift


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def thin(obj, most, flat=True):
    """At most `most` triangles: flat faces merged first (never across two materials), then
    collapsed."""
    bpy.context.view_layer.objects.active = obj
    if flat and tris(obj) > most:
        d = obj.modifiers.new("flat", "DECIMATE")
        d.decimate_type = "DISSOLVE"
        d.angle_limit = math.radians(1.0)
        d.delimit = {"MATERIAL", "UV"}
        bpy.ops.object.modifier_apply(modifier="flat")
        t = obj.modifiers.new("tri", "TRIANGULATE")
        bpy.ops.object.modifier_apply(modifier="tri")
    # (a quarter at a time keeps a shape better than one big step; it stops where it can go no
    # further - a part can't be thinned to nothing)
    while tris(obj) > most:
        have = tris(obj)
        dec = obj.modifiers.new("thin", "DECIMATE")
        dec.ratio = max(most / have, THIN_STEP)
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")
        if tris(obj) > have * 0.95:
            break


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


def lamp_at(obj, share):
    """A lantern's lamp (m, as the game has it: x across, y up, z deep): over its middle, `share` of
    its height up."""
    h = max(v.co.z for v in obj.data.vertices)
    return [0.0, round(float(h * share), 3), 0.0]


# ---------------------------------------------------------------- pictures

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


def picture(src, size, kind, name, seed):
    """A picture of ours from the upload's (`src` a path or a loaded image): `size` px; a colour one
    toned and weathered, a normal map only smaller."""
    key = (src if isinstance(src, str) else src.name, size, kind)
    if key in _pictures:
        return _pictures[key]
    img_src = bpy.data.images.load(src) if isinstance(src, str) else src
    img_src.scale(size, size)
    px = np.empty(size * size * 4, dtype=np.float32)
    img_src.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    if kind == "colour":
        rgb = px[..., :3]
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
        rgb = (rgb * (1 - GREY) + lum[..., None] * GREY) * np.array(WARM, dtype=np.float32)
        n = noise2(size + 64, size + 64, 64, seed)[:size, :size]
        rgb = rgb * (1.0 - WEATHER * np.clip((n - 0.4) * 2.5, 0, 1))[..., None]
        px[..., :3] = np.clip(rgb, 0, 1)
    px[..., 3] = 1.0
    img = bpy.data.images.new(name, size, size)
    img.pixels.foreach_set(px.ravel())
    img.pack()
    if isinstance(src, str):
        bpy.data.images.remove(img_src)
    _pictures[key] = img
    return img


def pictured(name, colour, normal, size, seed):
    """Our material: `colour` (a path or an image) toned ours, `normal` beside it if there is one."""
    m = bpy.data.materials.new("Cn_" + name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = picture(colour, size, "colour", "cn_" + name, seed)
    nt.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = ROUGH
    if normal is not None:
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = picture(normal, NRM, "normal", "cn_" + name + "_n", 0)
        ntex.image.colorspace_settings.name = "Non-Color"
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(ntex.outputs[0], nmap.inputs["Color"])
        nt.links.new(nmap.outputs[0], bsdf.inputs["Normal"])
    return m


# ---------------------------------------------------------------- vertex colours

def lost_picture(m):
    """The name of the picture a material wore (lost or not), lower case - what it was made of."""
    names = [m.name]
    if m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                names.append(os.path.basename(n.image.filepath or n.image.name))
    return " ".join(names).lower()


def flat_colour(m):
    """A material's own flat colour (its base colour), duller and a little warmer - ours."""
    c = (0.5, 0.5, 0.5)
    if m.use_nodes and m.node_tree.nodes.get("Principled BSDF"):
        c = m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value[:3]
    else:
        c = m.diffuse_color[:3]
    lum = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    return tuple(min(1.0, (c[j] * (1 - FLAT_GREY) + lum * FLAT_GREY) * FLAT_WARM[j] * 0.92) for j in range(3))


def colour_of(m, own):
    """What a part is made of -> its colour: the thing's own (`own`, keyword -> colour) first, then
    the palette's, then the material's own flat colour made ours."""
    if m is None:
        return (0.45, 0.44, 0.42)
    if m.name.startswith("own"):
        return tuple(m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value[:3])
    words = lost_picture(m)
    for k, c in list(own.items()) + PALETTE:
        if k in words:
            return c
    return flat_colour(m)


def coloured(obj, own, dirt, seed):
    """Its vertex colour: each face its part's colour, a shade of its own, darker low down; one plain
    material."""
    me = obj.data
    cols = [colour_of(m, own) for m in me.materials] or [(0.45, 0.44, 0.42)]
    # (any colours the upload's parts carried go: ours is the only one, the one exported)
    while len(me.color_attributes):
        me.color_attributes.remove(me.color_attributes[0])
    col = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = 0
    h = max(float(np.array([v.co.z for v in me.vertices]).max()), 0.01)
    rng = np.random.default_rng(seed)
    for p in me.polygons:
        base = cols[p.material_index] if p.material_index < len(cols) else cols[0]
        shade = 1.0 + (rng.random() - 0.5) * 2.0 * SHADE
        for li in p.loop_indices:
            z = me.vertices[me.loops[li].vertex_index].co.z
            k = (DIRT + (1.0 - DIRT) * min(1.0, z / (h * DIRT_UP))) if dirt else 1.0
            c = [min(1.0, base[j] * shade * k) for j in range(3)]
            col.data[li].color = (c[0], c[1], c[2], 1.0)
    me.materials.clear()
    m = bpy.data.materials.get("CnVertex")
    if m is None:
        m = bpy.data.materials.new("CnVertex")
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = ROUGH
    me.materials.append(m)


def painted(obj, colour):
    """A whole new part one colour (a material that names it, for coloured())."""
    m = bpy.data.materials.new("own")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1.0)
    obj.data.materials.clear()
    obj.data.materials.append(m)
    return obj


# ---------------------------------------------------------------- the pictured ones

def hall():
    clear()
    bpy.ops.import_scene.fbx(filepath=ARGS["hall"])
    obj = joined(meshes(), "cn_hall")
    thin(obj, HALL[0], flat=False)
    sized(obj, HALL[1])
    tex = os.path.join(ARGS["textures"], "Mansion_textures")
    for i, m in enumerate(obj.data.materials):
        base = m.name.split(".")[0]
        nrm = os.path.join(tex, "mansion_%s_NormalOpenGL.png" % base)
        obj.data.materials[i] = pictured("hall_" + base.lower(), os.path.join(tex, "mansion_%s_BaseColor.png" % base),
                                         nrm if os.path.exists(nrm) else None, WHOLE, 10 + i)
    footprint(obj, "cn_hall")
    export(obj, os.path.join(OUT, "cn_hall.glb"), True)


def pavilion():
    clear()
    bpy.ops.import_scene.fbx(filepath=ARGS["pavilion"])
    obj = joined(meshes(), "cn_pavilion")
    thin(obj, PAVILION[0], flat=False)
    sized(obj, PAVILION[1])
    tex = os.path.join(ARGS["textures"], "Arbor_textures")
    for i, m in enumerate(obj.data.materials):
        base = m.name.split(".")[0]
        nrm = os.path.join(tex, "%s_Normal.png" % base)
        obj.data.materials[i] = pictured("pavilion_" + base.lower(), os.path.join(tex, "%s_BaseColor.png" % base),
                                         nrm if os.path.exists(nrm) else None, WHOLE, 20 + i)
    footprint(obj, "cn_pavilion")
    export(obj, os.path.join(OUT, "cn_pavilion.glb"), True)


def house():
    """The scanned stone house, cut free of its yard (only what lies within the walls' box - the
    faces standing higher than HOUSE_WALL - HOUSE_PLINTH past it, is kept). The scan is eighteen
    thousand loose pieces (each tile, each brick its own) - it can't be thinned as it is: it is made
    anew instead, one closed shell from it (voxels HOUSE_VOXEL m), thinned to its triangles, and its
    five pictures baked onto that one (HOUSE_PX), toned ours."""
    clear()
    with bpy.data.libraries.load(ARGS["house"], link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == "ok"]
    o = dst.objects[0]
    bpy.context.scene.collection.objects.link(o)
    o.parent = None
    obj = joined([o], "cn_house_scan")
    pts = np.array([v.co[:] for v in obj.data.vertices])
    tall = pts[pts[:, 2] > HOUSE_WALL]
    lo = tall[:, :2].min(0) - HOUSE_PLINTH
    hi = tall[:, :2].max(0) + HOUSE_PLINTH
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    gone = [f for f in bm.faces if not all(lo[0] <= v.co.x <= hi[0] and lo[1] <= v.co.y <= hi[1] for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    centre(obj)
    sized(obj, HOUSE[1])
    # (the new shell)
    low = obj.copy()
    low.data = obj.data.copy()
    low.name = "cn_house"
    bpy.context.scene.collection.objects.link(low)
    bpy.context.view_layer.objects.active = low
    vox = low.modifiers.new("vox", "REMESH")
    vox.mode = "VOXEL"
    vox.voxel_size = HOUSE_VOXEL
    bpy.ops.object.modifier_apply(modifier="vox")
    thin(low, HOUSE[0], flat=False)
    low.data.materials.clear()
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = bpy.data.images.new("cn_house_baked", HOUSE_PX, HOUSE_PX)
    m = bpy.data.materials.new("bake")
    m.use_nodes = True
    node = m.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = baked
    m.node_tree.nodes.active = node
    low.data.materials.append(m)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True,
                        cage_extrusion=HOUSE_CAGE, max_ray_distance=HOUSE_CAGE * 3.0, margin=6)
    bpy.data.objects.remove(obj)
    low.data.materials[0] = pictured("house", baked, None, HOUSE_PX, 30)
    footprint(low, "cn_house")
    export(low, os.path.join(OUT, "cn_house.glb"), True)


# ---------------------------------------------------------------- the self-coloured ones

def low_lantern(at, r, h, name):
    """One of our low paper lanterns: an eight-sided barrel, red, its caps gold."""
    bm = bmesh.new()
    rings = [(0.0, r * 0.55), (h * 0.12, r * 0.9), (h * 0.5, r), (h * 0.88, r * 0.9), (h, r * 0.55)]
    vs = []
    for z, rr in rings:
        vs.append([bm.verts.new((at[0] + math.cos(a) * rr, at[1] + math.sin(a) * rr, at[2] + z))
                   for a in [k / 8 * math.tau for k in range(8)]])
    for a, b in zip(vs, vs[1:]):
        for k in range(8):
            bm.faces.new((a[k], a[(k + 1) % 8], b[(k + 1) % 8], b[k]))
    bm.faces.new(list(reversed(vs[0])))
    bm.faces.new(vs[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return painted(o, LANTERN_RED)


def tower():
    """The two-storey pavilion: its building alone (TOWER_BOX), its lanterns ours."""
    clear()
    with bpy.data.libraries.load(ARGS["tower"], link=False) as (src, dst):
        dst.objects = list(src.objects)
    keep = []
    lamps = []
    for o in dst.objects:
        if o is None or o.type != "MESH" or len(o.data.polygons) == 0:
            continue
        bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.update()
    for o in meshes():
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        mid = (lo + hi) / 2
        inside = all(TOWER_BOX[0][j] <= mid[j] <= TOWER_BOX[1][j] for j in range(3))
        if o.name.startswith("lantern_full"):
            lamps.append((mid, hi.z - lo.z))
        elif inside and o.name != "Cube.041" and max(hi - lo) < 12.0:
            keep.append(o)
    for i, (mid, h) in enumerate(lamps):
        keep.append(low_lantern((mid.x, mid.y, mid.z - h * 0.5), h * 0.36, h, "lamp%d" % i))
    obj = joined(keep, "cn_tower")
    sized(obj, TOWER[1])
    thin(obj, TOWER[0])
    coloured(obj, {}, True, 41)
    footprint(obj, "cn_tower")
    export(obj, os.path.join(OUT, "cn_tower.glb"), False)


def catalogue_groups():
    """The garden lantern catalogue's lanterns: its parts grouped where they overlap (it stands in
    the x-z plane), the frame and its grid left out; top row first, left to right."""
    clear()
    bpy.ops.import_scene.fbx(filepath=ARGS["lanterns"])
    bpy.context.view_layer.update()

    def box(o):
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        return lo, hi

    items = []
    for o in meshes():
        lo, hi = box(o)
        s = hi - lo
        if max(s) >= 6.0 or (min(s) < 0.02 and max(s) > 1.5):
            continue
        items.append((o, lo, hi))
    groups = []
    for o, lo, hi in items:
        groups.append({"objs": [o], "lo": lo, "hi": hi})
    changed = True
    while changed:
        changed = False
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                a, b = groups[i], groups[j]
                if (a["lo"].x <= b["hi"].x + 0.05 and a["hi"].x >= b["lo"].x - 0.05
                        and a["lo"].z <= b["hi"].z + 0.05 and a["hi"].z >= b["lo"].z - 0.05):
                    a["objs"] += b["objs"]
                    a["lo"] = Vector(map(min, a["lo"], b["lo"]))
                    a["hi"] = Vector(map(max, a["hi"], b["hi"]))
                    groups.pop(j)
                    changed = True
                    break
            if changed:
                break
    groups.sort(key=lambda g: (-round(g["hi"].z, 0), g["lo"].x))
    return groups


def lanterns():
    groups = catalogue_groups()
    wanted = range(len(groups)) if PREVIEW else LANTERNS.keys()
    for gi in wanted:
        clear()
        groups = catalogue_groups()
        g = groups[gi]
        name, high, share = LANTERNS.get(gi, ("cn_lamp_g%d" % gi, None, 0.6))
        obj = joined(g["objs"], name)
        sized(obj, high)
        thin(obj, 1500)
        coloured(obj, {}, True, 60 + gi)
        footprint(obj, name, {"lamp": lamp_at(obj, share)})
        export(obj, os.path.join(OUT, name + ".glb"), False)


def mtl_colours(path):
    """The .mtl's flat colours (Kd) by material name."""
    out = {}
    name = None
    for line in open(path, encoding="utf-8", errors="replace"):
        w = line.split()
        if not w:
            continue
        if w[0] == "newmtl":
            name = " ".join(w[1:])
        elif w[0] == "Kd" and name:
            out[name] = tuple(float(x) for x in w[1:4])
    return out


def flats():
    """The street pack's tenement blocks: each building's shell with whatever else stands within its
    box (balconies, frames, signs - none of the pack's heavy window grilles, FLAT_SKIP), coloured
    from the .mtl's flat colours made ours, sized to FLAT_HIGH."""
    kd = mtl_colours(ARGS["flats_mtl"])
    rng = np.random.default_rng(81)
    shells = FLATS if not PREVIEW else None
    clear()
    bpy.ops.wm.obj_import(filepath=ARGS["flats"])
    bpy.context.view_layer.update()
    names = [o.name for o in meshes() if any(m and (m.name.startswith("Building") or m.name.startswith("blueBuilding"))
                                             for m in o.data.materials)]
    for k, shell_name in enumerate(names):
        ours = shells.get(shell_name) if shells is not None else "cn_flat_" + shell_name.replace(".", "_")
        if ours is None:
            continue
        clear()
        bpy.ops.wm.obj_import(filepath=ARGS["flats"])
        bpy.context.view_layer.update()
        for m in bpy.data.materials:
            if m.name in kd and m.use_nodes:
                m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*kd[m.name], 1.0)
        shell = bpy.data.objects[shell_name]
        lo, hi = bounds(shell)
        pad = Vector((FLAT_PAD, FLAT_PAD, FLAT_PAD))
        part = [shell]
        for o in meshes():
            if o is shell or any(m and any(m.name.startswith(x) for x in FLAT_SKIP) for m in o.data.materials):
                continue
            olo, ohi = bounds(o)
            mid = (olo + ohi) / 2
            if all(lo[j] - pad[j] <= mid[j] <= hi[j] + pad[j] for j in range(3)) and max(ohi - olo) < max(hi - lo) * 1.2:
                part.append(o)
        obj = joined(part, ours)
        sized(obj, float(rng.uniform(*FLAT_HIGH)))
        thin(obj, FLAT_MOST)
        coloured(obj, FLAT_OWN, True, 80 + k)
        footprint(obj, ours)
        export(obj, os.path.join(OUT, ours + ".glb"), False)


def bounds(o):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w))
        hi = Vector(map(max, hi, w))
    return lo, hi


# ---------------------------------------------------------------- our own

def lathe(profile, sides, name, colour):
    """A turned shape: `profile` [(radius, z)...] round the z axis, `sides` sides, capped."""
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


def box(size, at, name, colour):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=at)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    return painted(o, colour)


RED_POST = {"high": 2.6, "arm": 0.9, "lantern": (0.24, 0.5), "wood": (0.24, 0.15, 0.1)}
JAR = (0.36, 0.3, 0.22)
STONE = (0.5, 0.49, 0.46)
WELL_STONE = (0.46, 0.45, 0.43)


def red_post():
    """Our red lantern post: a dark wooden post, a crossbar, two red paper lanterns hung from it -
    its lamp between them."""
    clear()
    p = RED_POST
    parts = [box((0.16, 0.16, p["high"]), (0, 0, p["high"] / 2), "post", p["wood"]),
             box((p["arm"] * 2, 0.1, 0.1), (0, 0, p["high"] - 0.15), "arm", p["wood"]),
             lathe([(0.16, 0.0), (0.2, 0.08), (0.2, 0.14), (0.0, 0.16)], 8, "foot", STONE)]
    r, h = p["lantern"]
    for side in (-1.0, 1.0):
        x = side * (p["arm"] - 0.15)
        parts.append(low_lantern((x, 0.0, p["high"] - 0.3 - h), r, h, "lantern"))
        parts.append(box((0.02, 0.02, 0.15), (x, 0, p["high"] - 0.22), "cord", (0.1, 0.08, 0.06)))
        tassel = lathe([(0.0, 0.0), (0.05, 0.12), (0.02, 0.2)], 6, "tassel", LANTERN_GOLD)
        tassel.location = (x, 0.0, p["high"] - 0.3 - h - 0.2)
        parts.append(tassel)
    obj = joined(parts, "cn_red_lantern")
    coloured(obj, {}, False, 70)
    footprint(obj, "cn_red_lantern", {"lamp": [0.0, round(p["high"] - 0.3 - h * 0.5, 3), 0.0]})
    export(obj, os.path.join(OUT, "cn_red_lantern.glb"), False)


def jar():
    """Our glazed water jar (水缸): wide-bellied, a rolled lip, dark brown glaze."""
    clear()
    o = lathe([(0.32, 0.0), (0.46, 0.18), (0.55, 0.45), (0.52, 0.68), (0.45, 0.8), (0.48, 0.84), (0.44, 0.86),
               (0.4, 0.8), (0.0, 0.78)], 16, "jar", JAR)
    obj = joined([o], "cn_jar")
    coloured(obj, {}, True, 71)
    footprint(obj, "cn_jar")
    export(obj, os.path.join(OUT, "cn_jar.glb"), False)


def table():
    """Our stone table and its four drum stools."""
    clear()
    parts = [lathe([(0.28, 0.0), (0.2, 0.1), (0.16, 0.55), (0.5, 0.62), (0.52, 0.72), (0.0, 0.74)], 12, "table", STONE)]
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        s = lathe([(0.17, 0.0), (0.22, 0.2), (0.17, 0.42), (0.0, 0.43)], 10, "stool", STONE)
        s.location = (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.0)
        parts.append(s)
    obj = joined(parts, "cn_table")
    coloured(obj, {}, True, 72)
    footprint(obj, "cn_table")
    export(obj, os.path.join(OUT, "cn_table.glb"), False)


def well():
    """Our stone well: a ring of stone, a wooden frame over it with its windlass."""
    clear()
    ring = lathe([(0.7, 0.0), (0.72, 0.62), (0.62, 0.66), (0.5, 0.62), (0.5, 0.1), (0.0, 0.1)], 14, "ring", WELL_STONE)
    wood = (0.27, 0.18, 0.12)
    parts = [ring, box((0.12, 0.12, 1.9), (-0.68, 0, 0.95), "postl", wood), box((0.12, 0.12, 1.9), (0.68, 0, 0.95), "postr", wood),
             box((1.5, 0.1, 0.1), (0, 0, 1.85), "beam", wood)]
    drum = lathe([(0.12, -0.5), (0.12, 0.5)], 8, "drum", wood)
    drum.rotation_euler = (0.0, math.pi / 2, 0.0)
    drum.location = (0.0, 0.0, 1.45)
    parts.append(drum)
    obj = joined(parts, "cn_well")
    coloured(obj, {}, True, 73)
    footprint(obj, "cn_well")
    export(obj, os.path.join(OUT, "cn_well.glb"), False)


def bamboo():
    """Our bamboo clump (for the Chinese and the Japanese villages' groves) from the user's Bambusa
    vulgaris: its culms thinned (BAMBOO_CULMS triangles), its leafy sprigs' cards a share kept
    (BAMBOO_CARDS, none lower than BAMBOO_LOW m) and drawn larger, its twigs left out (the sprigs hide
    where they were); its three sprig pictures (colour and cut-out joined) side by side in one, and
    its culm picture, toned ours; BAMBOO_HIGH m tall."""
    from PIL import Image
    clear()
    bpy.ops.import_scene.fbx(filepath=ARGS["bamboo"])
    bpy.context.view_layer.update()
    tex = os.path.dirname(ARGS["bamboo"])
    culm = [o for o in meshes() if o.name.startswith("Bark")]
    sprigs = sorted([o for o in meshes() if o.name.startswith("Leaf")], key=lambda o: o.name)
    for o in meshes():
        if o not in culm and o not in sprigs:
            bpy.data.objects.remove(o)
    # (a spray of ours for every card: the three sprig pictures (colour and cut-out joined) stamped
    # over and over onto one card, hanging their own ways - a card now carries what many did)
    import random as _random
    leaves = []
    for o in sprigs:
        n = o.name.split("_")[0][-2:]
        col = Image.open(os.path.join(tex, "AS01_Leaf%sFront_dif_su.png" % n)).convert("RGB").resize(BAMBOO_STRIP)
        alp = Image.open(os.path.join(tex, "AS01_Leaf%s_alp_su.png" % n)).convert("L").resize(BAMBOO_STRIP)
        im = Image.merge("RGBA", (*col.split(), alp))
        leaves.append(im.crop(im.getbbox() or (0, 0, *BAMBOO_STRIP)))
    rnd = _random.Random(93)
    sheet = Image.new("RGBA", (BAMBOO_SPRAY, BAMBOO_SPRAY), (0, 0, 0, 0))
    for k in range(BAMBOO_STAMPS):
        src = leaves[k % len(leaves)]
        h = int(BAMBOO_SPRAY * rnd.uniform(0.35, 0.6))
        w = max(4, int(src.size[0] * h / max(src.size[1], 1)))
        leaf = src.resize((w, h)).rotate(rnd.gauss(180.0, 40.0), resample=Image.BICUBIC, expand=True)
        sheet.alpha_composite(leaf, (int(rnd.uniform(0.05, 0.95) * BAMBOO_SPRAY - leaf.size[0] / 2) % BAMBOO_SPRAY // 1,
                                     max(0, int(rnd.uniform(0.0, 0.8) * BAMBOO_SPRAY - leaf.size[1] / 4))))
    a = np.asarray(sheet).astype(np.float32) / 255.0
    rgb = a[..., :3]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    rgb = (rgb * (1 - GREY) + lum[..., None] * GREY) * np.array(BAMBOO_TINT, np.float32)
    keep = a[..., 3] > 0.1
    rgb = np.where(keep[..., None], rgb, rgb[keep].mean(0))
    path = os.path.join(TMPDIR, "cn_bamboo_leaves.png")
    Image.fromarray((np.concatenate([np.clip(rgb, 0, 1), a[..., 3:4]], -1) * 255).astype(np.uint8)).save(path)
    for o in culm + sprigs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in culm + sprigs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = culm[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(sprigs) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in sprigs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = sprigs[0]
        bpy.ops.object.join()
    leaf = bpy.context.view_layer.objects.active
    stalks = culm[0]
    pts = np.array([v.co[:] for v in stalks.data.vertices])
    foot = Vector((float(pts[:, 0].mean()), float(pts[:, 1].mean()), float(pts[:, 2].min())))
    k = BAMBOO_HIGH / (max(float(pts[:, 2].max()), max(v.co.z for v in leaf.data.vertices)) - foot.z)
    for o in (stalks, leaf):
        for v in o.data.vertices:
            v.co = (v.co - foot) * k
    thin(stalks, BAMBOO_CULMS, flat=False)
    # (the sprigs' cards: a share kept, each grown about its middle)
    bm = bmesh.new()
    bm.from_mesh(leaf.data)
    bm.faces.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    seen = set()
    cards = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, group = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        cards.append(group)
    rng = np.random.default_rng(91)
    mids = [sum((v.co for v in {v for f in g for v in f.verts}), Vector()) / len({v for f in g for v in f.verts}) for g in cards]
    ok = [i for i, c in enumerate(mids) if c.z >= BAMBOO_LOW]
    rng.shuffle(ok)
    keep_set = set(ok[:BAMBOO_CARDS])
    gone = []
    for i, g in enumerate(cards):
        if i not in keep_set:
            gone.extend(g)
            continue
        vs = {v for f in g for v in f.verts}
        for v in vs:
            v.co = mids[i] + (v.co - mids[i]) * BAMBOO_GROW
        # (the spray over the whole card, its top up)
        nrm = sum((f.normal for f in g), Vector())
        nrm = nrm.normalized() if nrm.length > 1e-6 else Vector((0.0, 1.0, 0.0))
        across = nrm.cross(Vector((0.0, 0.0, 1.0)))
        across = across.normalized() if across.length > 1e-3 else Vector((1.0, 0.0, 0.0))
        up = across.cross(nrm).normalized()
        if up.z < 0.0:
            up = -up
        xs = [(v.co - mids[i]).dot(across) for v in vs]
        ys = [(v.co - mids[i]).dot(up) for v in vs]
        for f in g:
            for l in f.loops:
                d = l.vert.co - mids[i]
                l[uvl].uv = ((d.dot(across) - min(xs)) / max(max(xs) - min(xs), 1e-6),
                             (d.dot(up) - min(ys)) / max(max(ys) - min(ys), 1e-6))
    bmesh.ops.delete(bm, geom=list(set(gone)), context="FACES")
    bm.to_mesh(leaf.data)
    bm.free()
    ml = bpy.data.materials.new("Cn_bamboo_leaves")
    ml.use_nodes = True
    b = ml.node_tree.nodes["Principled BSDF"]
    t = ml.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(path)
    t.image.pack()
    ml.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
    ml.node_tree.links.new(t.outputs[1], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = ROUGH
    leaf.data.materials.clear()
    leaf.data.materials.append(ml)
    stalks.data.materials.clear()
    stalks.data.materials.append(pictured("bamboo_culm", os.path.join(tex, "AS01_Bark01_dif_su.png"), None, 256, 92))
    for o in (stalks, leaf):
        keep_uv = o.data.uv_layers.active.name
        for uvl in list(o.data.uv_layers):
            if uvl.name != keep_uv:
                o.data.uv_layers.remove(uvl)
        o.data.uv_layers[0].name = "UVMap"
    bpy.ops.object.select_all(action="DESELECT")
    stalks.select_set(True)
    leaf.select_set(True)
    bpy.context.view_layer.objects.active = stalks
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "cn_bamboo"
    footprint(obj, "cn_bamboo")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "cn_bamboo.glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="AUTO")
    print("WROTE cn_bamboo", tris(obj))


STEPS = [("hall", hall), ("pavilion", pavilion), ("house", house), ("tower", tower), ("lanterns", lanterns),
         ("flats", flats), ("red_post", red_post), ("jar", jar), ("table", table), ("well", well), ("bamboo", bamboo)]

if PREVIEW:
    OUT = os.path.join(OUT, "preview")
os.makedirs(OUT, exist_ok=True)
old = os.path.join(OUT, "cn_assets.json")
if os.path.exists(old) and ONLY:
    FOOTPRINTS.update(json.load(open(old)))
for key, step in STEPS:
    if ONLY and key not in ONLY:
        continue
    step()
json.dump(FOOTPRINTS, open(os.path.join(OUT, "cn_assets.json"), "w"), indent=1, sort_keys=True)
print("FOOTPRINTS", json.dumps(FOOTPRINTS))
