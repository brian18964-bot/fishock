"""The main screen's camp, from the user's models (user request: the camp
rebuilt with real assets - CGTrader / Fab / Quaternius packs). Each model
is made light enough for a phone - fewer triangles, its materials baked
into one small picture (and a normal picture where the detail matters) -
and saved as

  assets/models/camp/<name>.glb          the mesh (no material; metres,
                                         standing on y = 0, front toward +z)
  assets/models/camp/<name>_albedo.png   its colours, on the mesh's UVs
  assets/models/camp/<name>_normal.png   (some) its surface detail
  assets/models/camp/<name>_glow.png     (some) what glows

CampStage dresses them (CampStage.model()). Only these go in the repo:
the source packs are bought or free-to-use models whose licences don't
allow handing the original files on, so they're read from CAMP_SRC
(default: the session scratchpad), never committed.

  CAMP_SRC=/path/to/camp_src bpyenv/bin/python tools/build_camp_models.py [name ...]

CAMP_SRC holds: campfire/ (Campfire.blend + its Optimized textures),
tents/ (EXPORT_9_VIKING_TENTS_PACK), crate/box2.blend, backpack/
(Backpack.fbx + images), bookshop/ (BookShop.obj + Materials), boat/
BoatColor.blend, log/ (log.fbx + 4k textures), barrel/ (Barrel_Metal.blend +
its Textures/), lotus/Lotus+Leaf.stl, frog/ (tools/prep_frog.py's
frog_low.npz and frog_high.npz). The trees come from art_src
(Quaternius / user models already in the repo); the 渡石 is made here.
"""
import math
import os
import sys
import tempfile

import bpy
import bmesh  # noqa: E402,F401 (after bpy)
from mathutils import Matrix, Vector
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "assets", "models", "camp")
SRC = os.environ.get("CAMP_SRC", "/tmp/camp_src")
ART = os.path.join(ROOT, "art_src")
sys.path.insert(0, HERE)

Image.MAX_IMAGE_PIXELS = None


# ---------------------------------------------------------------- helpers

def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH']


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def select(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def apply_modifiers(objs):
    """Bakes every modifier (mirror, solidify, geometry nodes) into the mesh."""
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if not o.modifiers:
            continue
        me = bpy.data.meshes.new_from_object(o.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
        o.modifiers.clear()
        o.data = me


def realize(objs):
    """Single-user meshes with their transforms applied (instances made real)."""
    for o in objs:
        if o.data.users > 1:
            o.data = o.data.copy()
    select(objs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def decimate(objs, budget):
    """Collapses the heaviest parts until the whole is about `budget` triangles;
    small parts are left alone."""
    total = sum(tris(o) for o in objs)
    if total <= budget:
        return
    # Parts under a floor keep their shape; the rest share what's left.
    floor = max(60, budget // (len(objs) * 4))
    small = sum(tris(o) for o in objs if tris(o) <= floor)
    ratio = max(0.01, (budget - small) / max(1, total - small))
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if tris(o) <= floor:
            continue
        m = o.modifiers.new("lighter", 'DECIMATE')
        m.ratio = max(ratio, floor / tris(o))
        m.use_collapse_triangulate = True
        deps.update()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(deps), preserve_all_data_layers=True, depsgraph=deps)
        o.modifiers.clear()
        o.data = me


def unparent(objs):
    """Frees the parts from the importer's empties (an FBX's unit scale on
    a parent), keeping where they are, and drops the empties."""
    for o in objs:
        if o.parent is not None:
            w = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = w
    for o in list(bpy.data.objects):
        if o.type == 'EMPTY':
            bpy.data.objects.remove(o, do_unlink=True)


def place(objs, size=None, height=None, length=None):
    """Scales to metres (by its height, or its longest flat side) and stands
    it on the ground at the origin."""
    unparent(objs)
    lo, hi = bounds(objs)
    if height is not None:
        k = height / max(hi.z - lo.z, 1e-6)
    elif length is not None:
        k = length / max(hi.x - lo.x, hi.y - lo.y, 1e-6)
    else:
        k = size or 1.0
    c = (lo + hi) / 2
    m = Matrix.Scale(k, 4) @ Matrix.Translation((-c.x, -c.y, -lo.z))
    for o in objs:
        o.matrix_world = m @ o.matrix_world
    realize(objs)


def bounds(objs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def uv_to(material, layer):
    """Makes every image a material reads use the UV layer `layer` (so a new
    layer for the atlas doesn't move them)."""
    nt = material.node_tree
    for n in list(nt.nodes):
        if n.type == 'TEX_IMAGE' and not n.inputs['Vector'].is_linked:
            uv = nt.nodes.new('ShaderNodeUVMap')
            uv.uv_map = layer
            nt.links.new(uv.outputs['UV'], n.inputs['Vector'])
        elif n.type == 'TEX_COORD' and n.outputs['UV'].is_linked:
            uv = nt.nodes.new('ShaderNodeUVMap')
            uv.uv_map = layer
            for link in list(n.outputs['UV'].links):
                nt.links.new(uv.outputs['UV'], link.to_socket)
        elif n.type == 'NORMAL_MAP':
            n.uv_map = layer


def bake(objs, name, size, normal_from=None, glow=False, margin=6):
    """Bakes the parts' own materials into one picture laid out on a new UV
    layer ("atlas"); with `normal_from` (a high-detail copy), also the high
    copy's surface onto the low mesh. Writes <name>_albedo.png (and
    _normal.png, _glow.png)."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 4
    scene.render.bake.margin = margin
    mats = []
    for o in objs:
        me = o.data
        if len(me.uv_layers) == 0:
            me.uv_layers.new(name="UVMap")
        src = me.uv_layers[0].name
        for slot in o.material_slots:
            if slot.material is not None and slot.material not in mats:
                mats.append(slot.material)
                slot.material.use_nodes = True
        for m in [s.material for s in o.material_slots if s.material]:
            uv_to(m, src)
        atlas = me.uv_layers.new(name="atlas")
        me.uv_layers.active = atlas
        atlas.active_render = True
    # Parts with no material get a plain grey one.
    for o in objs:
        if not o.material_slots or all(s.material is None for s in o.material_slots):
            m = bpy.data.materials.new("plain")
            m.use_nodes = True
            o.data.materials.clear()
            o.data.materials.append(m)
            mats.append(m)
    select(objs)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')

    def target(kind, colour_space):
        img = bpy.data.images.new("%s_%s" % (name, kind), size * 2, size * 2, alpha=False, float_buffer=False)
        img.colorspace_settings.name = colour_space
        for m in mats:
            nt = m.node_tree
            for n in [n for n in nt.nodes if n.name == "bake_target"]:
                nt.nodes.remove(n)
            t = nt.nodes.new('ShaderNodeTexImage')
            t.name = "bake_target"
            t.image = img
            # The bake writes through the atlas layer.
            uv = nt.nodes.new('ShaderNodeUVMap')
            uv.uv_map = "atlas"
            nt.links.new(uv.outputs['UV'], t.inputs['Vector'])
            nt.nodes.active = t
        return img

    def save(img, kind, mode="RGB"):
        tmp = os.path.join(tempfile.gettempdir(), "%s_%s.png" % (name, kind))
        img.filepath_raw = tmp
        img.file_format = 'PNG'
        img.save()
        Image.open(tmp).convert(mode).resize((size, size), Image.LANCZOS).save(
            os.path.join(OUT, "%s_%s.png" % (name, kind)), optimize=True)
        os.remove(tmp)

    img = target("albedo", 'sRGB')
    select(objs)
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
    save(img, "albedo")
    if glow:
        img = target("glow", 'sRGB')
        select(objs)
        bpy.ops.object.bake(type='EMIT', use_clear=True)
        save(img, "glow")
    if normal_from is not None:
        img = target("normal", 'Non-Color')
        low = objs[0]
        select([normal_from, low], active=low)
        r = max((low.dimensions.x, low.dimensions.y, low.dimensions.z))
        bpy.ops.object.bake(type='NORMAL', use_selected_to_active=True, cage_extrusion=r * 0.02,
                            max_ray_distance=r * 0.05, use_clear=True)
        save(img, "normal")


def export(objs, name):
    """One mesh, no material, UVs = the atlas layer only."""
    for o in objs:
        me = o.data
        for layer in [l for l in me.uv_layers if l.name != "atlas"]:
            me.uv_layers.remove(layer)
        me.materials.clear()
    select(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    for p in o.data.polygons:
        p.use_smooth = True
    select([o])
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format='GLB',
                              use_selection=True, export_apply=True, export_materials='NONE',
                              export_texcoords=True, export_normals=True, export_yup=True, **NO_COLOURS)
    print("built", name, tris(o), "tris", flush=True)


def image(path, colour=True):
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = 'sRGB' if colour else 'Non-Color'
    return img


def textured(name, albedo=None, colour=(0.5, 0.5, 0.5), rough=0.8, emit=None, emit_strength=1.0):
    """A plain material: a colour, or a picture (on the default UVs)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Roughness'].default_value = rough
    if albedo is not None:
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = image(albedo)
        nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    else:
        b.inputs['Base Color'].default_value = (*colour, 1)
    if emit is not None:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = emit_strength
    return m


def retexture(objs, table, fallback=None):
    """Swaps each material for table[its name prefix] (a material)."""
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            key = next((k for k in table if m is not None and m.name.lower().startswith(k.lower())), None)
            if key is not None:
                slot.material = table[key]
            elif fallback is not None:
                slot.material = fallback


# ---------------------------------------------------------------- the models

def campfire():
    """The campfire: stones and logs (no flames - CampStage makes them)."""
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, "campfire", "Campfire.blend"))
    for o in list(bpy.data.objects):
        if o.name != "Campfire":
            bpy.data.objects.remove(o, do_unlink=True)
    objs = meshes()
    d = os.path.join(SRC, "campfire")
    m = textured("logs", os.path.join(d, "Campfire_MAT_BaseColor_00.jpg"), rough=0.85)
    # The embers: the hot colour map's red-orange, as light.
    hot = m.node_tree.nodes.new('ShaderNodeTexImage')
    hot.image = image(os.path.join(d, "Campfire_MAT_BaseColor_01.jpg"))
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    m.node_tree.links.new(hot.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = 1.0
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(m)
    place(objs, length=1.5)
    high = objs[0].copy()
    high.data = objs[0].data.copy()
    bpy.context.scene.collection.objects.link(high)
    decimate(objs, 2400)
    bake(objs, "campfire", 512, normal_from=high, glow=True)
    bpy.data.objects.remove(high, do_unlink=True)
    export(objs, "campfire")
    embers()
    fire_sprites(d)


def embers():
    """The glow picture as baked is the whole hot colour map; only where it's
    much redder than the cold one are there embers."""
    import numpy as np
    cold = np.asarray(Image.open(os.path.join(OUT, "campfire_albedo.png")).convert("RGB"), dtype=np.float32) / 255
    hot = np.asarray(Image.open(os.path.join(OUT, "campfire_glow.png")).convert("RGB"), dtype=np.float32) / 255
    heat = np.clip((hot[..., 0] - cold[..., 0] * 1.05 - (hot[..., 2] - cold[..., 2])) * 3.5, 0, 1)
    # Only the wood smoulders: the ring of stones (grey - little colour in
    # the cold map) stays cold (user request: not every stone aglow).
    sat = cold.max(-1) - cold.min(-1)
    wood = np.clip((sat / np.maximum(cold.max(-1), 0.05) - 0.22) * 6.0, 0, 1)
    heat *= wood
    out = hot * heat[..., None] * np.array([1.0, 0.75, 0.45])
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "campfire_glow.png"), optimize=True)


def fire_sprites(d):
    """Flames and smoke for the fire's particles (tools/cut_fire_sprites.py,
    run by the system Python: it needs scipy, Blender's doesn't have it)."""
    import subprocess
    subprocess.run(["python3", os.path.join(HERE, "cut_fire_sprites.py"),
                    os.path.join(d, "Campfire_fire_MAT_BaseColor_Alpha.png"), OUT], check=True)


TENT_MATS = {"Fabric": "T_fabric_BaseColor", "Fur": "T_fur_BaseColor", "Rope": "T_rope_BaseColor",
             "Wood": "T_wood_raw_BaseColor"}


def tent(i):
    """One of the nine Viking tents (low-poly); its four materials (the
    pack's paths point at the artist's drive, one at the wrong picture, and
    tents 2-6 at a fabric that isn't in the pack - tent 1's is used)."""
    fresh()
    base = os.path.join(SRC, "tents", "viking_tent_%03d" % i)
    bpy.ops.wm.obj_import(filepath=os.path.join(base, "mesh", "lowpoly_viking_tent_%03d.obj" % i))
    tex = os.path.join(SRC, "tents", "viking_tent_001", "textures")
    table = {k: textured("tent_" + k, os.path.join(tex, v + ".png"), rough=0.9) for k, v in TENT_MATS.items()}
    objs = meshes()
    retexture(objs, table)
    place(objs, height=2.5)
    decimate(objs, 6000)
    bake(objs, "tent_%d" % i, 512)
    export(objs, "tent_%d" % i)


def crate():
    """The weathered crate (box2.blend: planks laid by geometry nodes)."""
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, "crate", "box2.blend"))
    for o in list(bpy.data.objects):
        if o.type != 'MESH' or not o.visible_get():
            bpy.data.objects.remove(o, do_unlink=True)
    objs = meshes()
    apply_modifiers(objs)
    objs = [o for o in meshes() if len(o.data.polygons) > 0]
    for o in meshes():
        if o not in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    realize(objs)
    place(objs, length=1.15)
    bake(objs, "crate", 512)
    export(objs, "crate")


def backpack():
    """The canvas backpack (MonicaRG): 14 parts, 7 materials."""
    fresh()
    d = os.path.join(SRC, "backpack")
    bpy.ops.import_scene.fbx(filepath=os.path.join(d, "Backpack.fbx"))
    objs = meshes()
    # Its materials' pictures, by name (the FBX's packed images are kept, but
    # point them at the files where they're missing).
    for m in {s.material for o in objs for s in o.material_slots if s.material}:
        colour = os.path.join(d, m.name + "_Base_Color.png")
        if os.path.exists(colour):
            slot_m = textured(m.name + "_baked", colour, rough=0.85)
            for o in objs:
                for s in o.material_slots:
                    if s.material == m:
                        s.material = slot_m
    flat = {"Mat_zipper": (0.25, 0.24, 0.22), "Mat_plastic": (0.12, 0.11, 0.1)}
    for o in objs:
        for s in o.material_slots:
            if s.material is not None and s.material.name in flat:
                s.material = textured(s.material.name + "_flat", colour=flat[s.material.name], rough=0.6)
    place(objs, height=0.55)
    decimate(objs, 6000)
    bake(objs, "backpack", 512)
    export(objs, "backpack")


BOOKSHOP_COLOURS = {
    # Linear colours (Blender's): dark and saturated, a night market.
    "Bread": (0.42, 0.2, 0.07), "Knob": (0.35, 0.24, 0.07), "Glass": (0.25, 0.38, 0.4),
    "metal": (0.12, 0.12, 0.13), "bookOutside": (0.16, 0.035, 0.025), "PotionGlow1": (0.08, 0.55, 0.18),
    "PotionGlow2": (0.12, 0.2, 0.85), "PotionGlow3": (0.75, 0.08, 0.3), "PotionGlow4": (0.85, 0.5, 0.06),
    "Pot": (0.12, 0.07, 0.05), "Mixture": (0.08, 0.35, 0.12), "glow": (1.0, 0.6, 0.2), "Carpet": (0.18, 0.025, 0.02),
    "None": (0.16, 0.09, 0.05),
}


def _checked_cloth():
    """The canopy as the pack shows it (no picture came with it): a dark
    green check, the weave faintly in it."""
    m = bpy.data.materials.new("cloth")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Roughness'].default_value = 0.95
    uv = nt.nodes.new('ShaderNodeTexCoord')
    check = nt.nodes.new('ShaderNodeTexChecker')
    check.inputs['Scale'].default_value = 6.0
    check.inputs['Color1'].default_value = (0.016, 0.05, 0.032, 1)
    check.inputs['Color2'].default_value = (0.005, 0.018, 0.012, 1)
    nt.links.new(uv.outputs['UV'], check.inputs['Vector'])
    weave = nt.nodes.new('ShaderNodeTexNoise')
    weave.inputs['Scale'].default_value = 140.0
    nt.links.new(uv.outputs['UV'], weave.inputs['Vector'])
    mul = nt.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 0.35
    nt.links.new(check.outputs['Color'], mul.inputs[6])
    nt.links.new(weave.outputs['Color'], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs['Base Color'])
    return m


# The canopy's front hangs down over the counter: cut away below this
# height (m, the stall 3.3 high) in front of this line (its front is -y),
# so the shelves inside show (user request).
CANOPY_HEM = 2.2
CANOPY_FRONT = -0.45


def _lift_canopy(objs, cloth):
    """Cuts the canopy's front back to a hem at CANOPY_HEM."""
    for o in objs:
        slots = [i for i, s in enumerate(o.material_slots) if s.material == cloth]
        if not slots:
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        mw = o.matrix_world
        cut = [f for f in bm.faces if f.material_index in slots
               and (mw @ f.calc_center_median()).z < CANOPY_HEM and (mw @ f.calc_center_median()).y < CANOPY_FRONT]
        bmesh.ops.delete(bm, geom=cut, context='FACES')
        bm.to_mesh(o.data)
        bm.free()
        print("canopy:", o.name, "cut", len(cut), "faces", flush=True)


def bookshop():
    """The market stall (BookShop.obj): no .mtl came with it - its wood and
    pages from Materials, the rest coloured by material name. The cloth
    canopy (400k triangles of cloth sim) is brought right down."""
    fresh()
    d = os.path.join(SRC, "bookshop")
    bpy.ops.wm.obj_import(filepath=os.path.join(d, "BookShop.obj"))
    objs = meshes()
    table = {
        "woodTexture": textured("planks", os.path.join(d, "weathered_brown_planks_diff_4k.jpg"), rough=0.9),
        "DarkWoodTexture": textured("dark_wood", os.path.join(d, "Wood059_2K_Color.jpg"), rough=0.8),
        "woodPoleTexture": textured("pole_wood", os.path.join(d, "Wood059_2K_Color.jpg"), rough=0.8),
        "bookPages": textured("pages", os.path.join(d, "pagesTexture.png"), rough=0.9),
    }
    for k, c in BOOKSHOP_COLOURS.items():
        glows = k.startswith("PotionGlow") or k == "glow"
        table[k] = textured("c_" + k, colour=c, rough=0.5 if glows else 0.85,
                            emit=c if glows else None, emit_strength=2.0)
    table["FabricTiled"] = _checked_cloth()
    retexture(objs, table, fallback=table["None"])
    # The dark wood darker.
    dark = table["DarkWoodTexture"].node_tree
    b = next(n for n in dark.nodes if n.type == 'BSDF_PRINCIPLED')
    mul = dark.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    dark.links.new(b.inputs['Base Color'].links[0].from_socket, mul.inputs[6])
    mul.inputs[7].default_value = (0.62, 0.56, 0.52, 1)
    dark.links.new(mul.outputs[2], b.inputs['Base Color'])
    place(objs, height=3.3)
    _lift_canopy(objs, table["FabricTiled"])
    decimate(objs, 14000)
    bake(objs, "bookshop", 1024, glow=True)
    export(objs, "bookshop")


# The mast stands far above the hull (the hull's top about 1.4 m): above
# MAST_FROM it's drawn down to MAST_KEEP of its height (user request: 40%
# shorter).
MAST_FROM = 1.6
MAST_KEEP = 0.567


def _shorten_mast(objs):
    for o in objs:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            if p.z > MAST_FROM:
                p.z = MAST_FROM + (p.z - MAST_FROM) * MAST_KEEP
                v.co = o.matrix_world.inverted() @ p


def boat():
    """The covered boat (BoatColor.blend), without its sea."""
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, "boat", "BoatColor.blend"))
    for o in list(bpy.data.objects):
        if o.type != 'MESH' or o.name == "Plane":
            bpy.data.objects.remove(o, do_unlink=True)
    objs = meshes()
    apply_modifiers(objs)
    realize(objs)
    place(objs, length=5.2)
    _shorten_mast(objs)
    decimate(objs, 5000)
    bake(objs, "boat", 512)
    export(objs, "boat")


def log():
    """A scanned log (213k triangles) brought down, its bark baked on.
    Source: "Free 4k Wood Log Scan" on CGTrader, Royalty Free License (no
    AI) - user confirmed."""
    fresh()
    d = os.path.join(SRC, "log")
    bpy.ops.import_scene.fbx(filepath=os.path.join(d, "log.fbx"))
    objs = meshes()
    m = textured("bark", os.path.join(d, "log_4K_basecolor.png"), rough=0.9)
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(m)
    place(objs, length=1.7)
    high = objs[0].copy()
    high.data = objs[0].data.copy()
    bpy.context.scene.collection.objects.link(high)
    decimate(objs, 2500)
    bake(objs, "log", 512, normal_from=high)
    bpy.data.objects.remove(high, do_unlink=True)
    export(objs, "log")


def _barrel(colour):
    """The metal barrel (ASSET2's Barrel_Metal.blend, its paint picked from
    the four it comes in), standing 0.92 m. Its own UVs and pictures are
    kept - only made small: the colour with its ambient occlusion laid on,
    and its normal picture."""
    fresh()
    d = os.path.join(SRC, "barrel")
    bpy.ops.wm.open_mainfile(filepath=os.path.join(d, "Barrel_Metal.blend"))
    for o in list(bpy.data.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)
    objs = meshes()
    realize(objs)
    place(objs, height=0.92)
    return objs


def _barrel_pictures(name, colour, normal=True):
    """(The trough shares the drum's normal picture: CampModel.SHARED.)"""
    import numpy as np
    d = os.path.join(SRC, "barrel", "Textures", "Common")
    base = Image.open(os.path.join(d, "Base_Color", "Barrel_Metal_%s_Base_color.png" % colour)).convert("RGB")
    ao = Image.open(os.path.join(d, "Barrel_Metal_Mixed_AO.png")).convert("L")
    size = (512, 512)
    c = np.asarray(base.resize(size, Image.LANCZOS)).astype(np.float32)
    a = np.asarray(ao.resize(size, Image.LANCZOS)).astype(np.float32)[..., None] / 255.0
    Image.fromarray(np.clip(c * a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + "_albedo.png"), optimize=True)
    if normal:
        Image.open(os.path.join(d, "Barrel_Metal_Normal_OpenGL.png")).convert("RGB").resize(size, Image.LANCZOS).save(
            os.path.join(OUT, name + "_normal.png"), optimize=True)


def _export_uv(objs, name):
    """export(), keeping the model's own UVs as the atlas."""
    for o in objs:
        o.data.uv_layers[0].name = "atlas"
    export(objs, name)


def drum():
    """The standing oil drum, in its red paint."""
    objs = _barrel("Red")
    _barrel_pictures("drum", "Red")
    _export_uv(objs, "drum")


def drum_trough():
    """The fish tank: the barrel on its side, its top half cut away (walls
    given a thickness, so the cut edge reads), in its yellow paint -
    CampStage fills it with water."""
    objs = _barrel("Yellow")
    o = objs[0]
    # Lying along x, its middle at the axis height.
    o.matrix_world = Matrix.Translation((0, 0, 0.32)) @ Matrix.Rotation(math.radians(90), 4, 'Y') @ \
        Matrix.Translation((0, 0, -0.46))
    realize(objs)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    lo, hi = bounds(objs)
    cut = lo.z + (hi.z - lo.z) * 0.62
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, cut),
                           plane_no=(0, 0, 1), clear_outer=True)
    bm.to_mesh(o.data)
    bm.free()
    sol = o.modifiers.new("wall", 'SOLIDIFY')
    sol.thickness = 0.012
    sol.offset = -1.0
    sol.use_even_offset = True
    apply_modifiers([o])
    place([o], size=1.0)
    _barrel_pictures("drum_trough", "Yellow", normal=False)
    _export_uv([o], "drum_trough")


def _rune_mask(path, w=512, h=1024):
    """The 渡石's runes: a column of them down its face (white on black),
    cut with a chisel's straight strokes, and a ring above them."""
    from PIL import ImageDraw
    import random
    rng = random.Random(7)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    # (strokes in a 0..1 box: Elder Futhark-like - staves and twigs)
    glyphs = [
        [((0.3, 0), (0.3, 1)), ((0.3, 0.15), (0.75, 0.35)), ((0.3, 0.45), (0.75, 0.65))],
        [((0.5, 0), (0.5, 1)), ((0.5, 0.3), (0.15, 0.05)), ((0.5, 0.3), (0.85, 0.05))],
        [((0.3, 0), (0.3, 1)), ((0.3, 0), (0.75, 0.25)), ((0.75, 0.25), (0.3, 0.5))],
        [((0.2, 0), (0.2, 1)), ((0.8, 0), (0.8, 1)), ((0.2, 0.25), (0.8, 0.6))],
        [((0.5, 0), (0.15, 0.5)), ((0.15, 0.5), (0.5, 1)), ((0.5, 0), (0.85, 0.5)), ((0.85, 0.5), (0.5, 1))],
        [((0.5, 0), (0.5, 1)), ((0.15, 0.35), (0.85, 0.65)), ((0.85, 0.35), (0.15, 0.65))],
        [((0.3, 0), (0.3, 1)), ((0.3, 0.2), (0.75, 0.45)), ((0.75, 0.45), (0.3, 0.7))],
    ]
    stroke = int(w * 0.035)
    # A ring near the top (the way through).
    cx, cy, r = w * 0.5, h * 0.16, w * 0.17
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=255, width=stroke)
    d.ellipse((cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35), outline=255, width=stroke)
    top, step, size = h * 0.29, h * 0.095, w * 0.2
    for i in range(7):
        g = glyphs[(i * 3 + 1) % len(glyphs)]
        ox = w * 0.5 - size * 0.5 + rng.uniform(-w * 0.02, w * 0.02)
        oy = top + i * step
        for (a, b) in g:
            d.line((ox + a[0] * size, oy + a[1] * size * 0.8, ox + b[0] * size, oy + b[1] * size * 0.8),
                   fill=255, width=stroke)
    # (Blender reads a picture from its bottom row up)
    img.transpose(Image.FLIP_TOP_BOTTOM).save(path)


def _front_uv(o, name="front"):
    """A UV layer laid flat on the stone's face: across x, up z (0..1 over
    the face)."""
    me = o.data
    lay = me.uv_layers.new(name=name)
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        lay.data[loop.index].uv = ((co.x - x0) / (x1 - x0), (co.z - z0) / (z1 - z0))


def _rock_material(name, runes=None):
    """Weathered grey stone, darker in its cracks, moss where it faces up;
    `runes` (a mask picture on the "front" UVs): cut into the face and
    glowing."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    N, L = nt.nodes, nt.links
    b = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Roughness'].default_value = 0.92
    tc = N.new('ShaderNodeTexCoord')
    big = N.new('ShaderNodeTexNoise')
    big.inputs['Scale'].default_value = 2.2
    big.inputs['Detail'].default_value = 10.0
    L.new(tc.outputs['Object'], big.inputs['Vector'])
    ramp = N.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[0].color = (0.17, 0.175, 0.18, 1)
    ramp.color_ramp.elements[1].color = (0.34, 0.34, 0.33, 1)
    L.new(big.outputs['Fac'], ramp.inputs['Fac'])
    # fine grain and pale lichen flecks
    grain = N.new('ShaderNodeTexNoise')
    grain.inputs['Scale'].default_value = 40.0
    grain.inputs['Detail'].default_value = 4.0
    L.new(tc.outputs['Object'], grain.inputs['Vector'])
    gmix = N.new('ShaderNodeMix')
    gmix.data_type = 'RGBA'
    gmix.blend_type = 'MULTIPLY'
    gmix.inputs['Factor'].default_value = 0.25
    L.new(ramp.outputs['Color'], gmix.inputs['A'])
    L.new(grain.outputs['Color'], gmix.inputs['B'])
    # dark in the cracks
    ao = N.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = 0.08
    aomix = N.new('ShaderNodeMix')
    aomix.data_type = 'RGBA'
    aomix.blend_type = 'MULTIPLY'
    aomix.inputs['Factor'].default_value = 0.85
    L.new(gmix.outputs['Result'], aomix.inputs['A'])
    L.new(ao.outputs['AO'], aomix.inputs['B'])
    # moss on what faces up
    geo = N.new('ShaderNodeNewGeometry')
    sep = N.new('ShaderNodeSeparateXYZ')
    L.new(geo.outputs['Normal'], sep.inputs['Vector'])
    up = N.new('ShaderNodeMapRange')
    up.inputs['From Min'].default_value = 0.35
    up.inputs['From Max'].default_value = 0.8
    L.new(sep.outputs['Z'], up.inputs['Value'])
    mn = N.new('ShaderNodeTexNoise')
    mn.inputs['Scale'].default_value = 9.0
    mn.inputs['Detail'].default_value = 6.0
    L.new(tc.outputs['Object'], mn.inputs['Vector'])
    mr = N.new('ShaderNodeMapRange')
    mr.inputs['From Min'].default_value = 0.45
    mr.inputs['From Max'].default_value = 0.6
    L.new(mn.outputs['Fac'], mr.inputs['Value'])
    moss = N.new('ShaderNodeMath')
    moss.operation = 'MULTIPLY'
    L.new(up.outputs['Result'], moss.inputs[0])
    L.new(mr.outputs['Result'], moss.inputs[1])
    mmix = N.new('ShaderNodeMix')
    mmix.data_type = 'RGBA'
    mmix.inputs['B'].default_value = (0.08, 0.12, 0.045, 1)
    L.new(moss.outputs['Value'], mmix.inputs['Factor'])
    L.new(aomix.outputs['Result'], mmix.inputs['A'])
    colour = mmix.outputs['Result']
    if runes is not None:
        uv = N.new('ShaderNodeUVMap')
        uv.uv_map = "front"
        t = N.new('ShaderNodeTexImage')
        t.image = image(runes, colour=False)
        L.new(uv.outputs['UV'], t.inputs['Vector'])
        # only on the face (its normal toward -y, Blender's front)
        face = N.new('ShaderNodeMapRange')
        face.inputs['From Min'].default_value = -0.45
        face.inputs['From Max'].default_value = -0.75
        L.new(sep.outputs['Y'], face.inputs['Value'])
        cut = N.new('ShaderNodeMath')
        cut.operation = 'MULTIPLY'
        L.new(t.outputs['Color'], cut.inputs[0])
        L.new(face.outputs['Result'], cut.inputs[1])
        dark = N.new('ShaderNodeMix')
        dark.data_type = 'RGBA'
        dark.inputs['B'].default_value = (0.10, 0.16, 0.19, 1)
        L.new(cut.outputs['Value'], dark.inputs['Factor'])
        L.new(colour, dark.inputs['A'])
        colour = dark.outputs['Result']
        L.new(cut.outputs['Value'], b.inputs['Emission Strength'])
        b.inputs['Emission Color'].default_value = (1, 1, 1, 1)
    L.new(colour, b.inputs['Base Color'])
    return m


def ferry_stone():
    """The 渡石 (user request: moved up to the camp, drawn in close when
    it's tapped - more detail than the far-off pair of slabs it was): one
    tall weathered standing stone, a little tapered and leaning, chipped,
    its face cut with a ring and a column of runes that glow, moss on its
    shoulders, a few stones sunk round its foot. Made here (no source
    pack): a detailed one sculpted by noise, baked onto a light one."""
    import random
    fresh()
    rng = random.Random(3)
    mask = os.path.join(tempfile.gettempdir(), "ferry_runes.png")
    _rune_mask(mask)
    # The stone: a block, rounded, tapered, then weathered.
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    st = bpy.context.active_object
    st.name = "stone"
    st.scale = (0.62, 0.36, 1.8)
    bpy.ops.object.transform_apply(scale=True)
    st.location.z = 0.9
    bpy.ops.object.transform_apply(location=True)
    bev = st.modifiers.new("round", 'BEVEL')
    bev.width = 0.09
    bev.segments = 4
    apply_modifiers([st])
    sub = st.modifiers.new("fine", 'SUBSURF')
    sub.subdivision_type = 'SIMPLE'
    sub.levels = sub.render_levels = 5
    apply_modifiers([st])
    taper = st.modifiers.new("taper", 'SIMPLE_DEFORM')
    taper.deform_method = 'TAPER'
    taper.factor = -0.32
    taper.deform_axis = 'Z'
    apply_modifiers([st])
    for scale, strength, kind in ((0.55, 0.07, 'CLOUDS'), (0.22, 0.03, 'VORONOI'), (0.06, 0.008, 'CLOUDS')):
        tex = bpy.data.textures.new("n%s" % scale, kind)
        tex.noise_scale = scale
        if kind == 'VORONOI':
            tex.distance_metric = 'DISTANCE'
        dm = st.modifiers.new("d%s" % scale, 'DISPLACE')
        dm.texture = tex
        dm.strength = strength
        dm.mid_level = 0.5
        dm.texture_coords = 'GLOBAL'
        apply_modifiers([st])
    # The face's runes cut in.
    _front_uv(st)
    front = st.vertex_groups.new(name="front")
    st.data.update()
    ids = [v.index for v in st.data.vertices if v.normal.y < -0.55]
    front.add(ids, 1.0, 'REPLACE')
    rt = bpy.data.textures.new("runes", 'IMAGE')
    rt.image = image(mask, colour=False)
    rt.extension = 'CLIP'
    cut = st.modifiers.new("runes", 'DISPLACE')
    cut.texture = rt
    cut.texture_coords = 'UV'
    cut.uv_layer = "front"
    cut.vertex_group = "front"
    cut.mid_level = 0.0
    cut.strength = -0.018
    apply_modifiers([st])
    # Leaning a touch, turned a little.
    st.rotation_euler = (math.radians(3.0), math.radians(-2.5), math.radians(4.0))
    bpy.ops.object.transform_apply(rotation=True)
    st.data.materials.append(_rock_material("ferry", runes=mask))
    # Stones round its foot, half sunk.
    plain = _rock_material("foot")
    parts = [st]
    for i in range(7):
        a = i / 7.0 * math.tau + rng.uniform(-0.25, 0.25)
        r = rng.uniform(0.42, 0.62)
        size = rng.uniform(0.09, 0.2)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=size,
                                              location=(math.cos(a) * r, math.sin(a) * r * 0.85, size * 0.15))
        o = bpy.context.active_object
        o.scale = (1.0, rng.uniform(0.7, 1.0), rng.uniform(0.5, 0.75))
        bpy.ops.object.transform_apply(scale=True)
        tex = bpy.data.textures.new("f%d" % i, 'CLOUDS')
        tex.noise_scale = 0.12
        dm = o.modifiers.new("d", 'DISPLACE')
        dm.texture = tex
        dm.strength = size * 0.35
        dm.texture_coords = 'GLOBAL'
        apply_modifiers([o])
        _front_uv(o)
        o.data.materials.append(plain)
        parts.append(o)
    # Into the ground a little, all of it on y = 0 after.
    for o in parts:
        for v in o.data.vertices:
            v.co.z -= 0.03
    high = []
    for o in parts:
        h = o.copy()
        h.data = o.data.copy()
        bpy.context.scene.collection.objects.link(h)
        high.append(h)
    select(high)
    bpy.ops.object.join()
    hi = bpy.context.view_layer.objects.active
    decimate([parts[0]], 2600)
    decimate(parts[1:], 700)
    # (one mesh, so the surface detail is baked onto all of it)
    select(parts, active=parts[0])
    bpy.ops.object.join()
    low = bpy.context.view_layer.objects.active
    bake([low], "ferry_stone", 1024, normal_from=hi, glow=True)
    bpy.data.objects.remove(hi, do_unlink=True)
    export([low], "ferry_stone")


def _npz_mesh(path, name):
    """A mesh from tools/prep_frog.py's arrays (ZBrush is y-up), its colour
    per face in a colour layer read by a plain material."""
    import numpy as np
    d = np.load(path)
    V, F, C = d["V"], d["F"], d["C"]
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(V))
    me.vertices.foreach_set("co", np.stack([V[:, 0], -V[:, 2], V[:, 1]], 1).ravel())
    me.loops.add(F.size)
    me.loops.foreach_set("vertex_index", F.ravel())
    me.polygons.add(len(F))
    me.polygons.foreach_set("loop_start", np.arange(0, F.size, 3))
    me.polygons.foreach_set("loop_total", np.full(len(F), 3))
    lin = np.where(C <= 0.04045, C / 12.92, ((C + 0.055) / 1.055) ** 2.4)
    col = me.color_attributes.new("paint", 'FLOAT_COLOR', 'CORNER')
    col.data.foreach_set("color", np.concatenate([np.repeat(lin, 3, 0), np.ones((F.size, 1))], 1)
                         .astype(np.float32).ravel())
    me.validate()
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    m = bpy.data.materials.new(name + "_paint")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    a = nt.nodes.new('ShaderNodeVertexColor')
    a.layer_name = "paint"
    nt.links.new(a.outputs['Color'], b.inputs['Base Color'])
    me.materials.append(m)
    return o


def frog_merchant():
    """The merchant: the frog wanderer (ASSET2's ZBrush sculpt), cut down and
    coloured part by part by tools/prep_frog.py. Its parts are plain
    colours, so they stay as the mesh's vertex colours (no picture: an
    unwrap of a sculpt this size is all crumbs). Rigged and animated by
    tools/rig_frog.py (Idle, Walk, Talk). Facing +z (the sculpt's front)."""
    import numpy as np
    import rig_frog
    fresh()
    path = os.path.join(SRC, "frog", "frog_low.npz")
    o = _npz_mesh(path, "frog_merchant")
    d = np.load(path)
    V, F, C = d["V"], d["F"], d["C"]
    # The sculpt -> metres, standing on the ground (as _npz_mesh lays it, then
    # place()).
    k = 1.25 / float(V[:, 1].max() - V[:, 1].min())
    lo_y = float(V[:, 1].min())
    cx = float(V[:, 0].max() + V[:, 0].min()) / 2
    cz = float(V[:, 2].max() + V[:, 2].min()) / 2

    def to_blender(p):
        return Vector(((p[0] - cx) * k, -(p[2] - cz) * k, (p[1] - lo_y) * k))

    place([o], height=1.25)
    o.data.materials.clear()
    for p in o.data.polygons:
        p.use_smooth = True
    # Each vertex's colour (its faces all share one).
    Cv = np.zeros((len(V), 3), np.float32)
    for j in range(3):
        Cv[F[:, j]] = C
    if len(o.data.vertices) != len(V):
        raise SystemExit("frog mesh changed size (%d vs %d)" % (len(o.data.vertices), len(V)))
    arm = rig_frog.armature(to_blender)
    rig_frog.skin(o, arm, V, Cv)
    rig_frog.animate(arm)
    select([arm, o], active=arm)
    colours = {"export_vertex_color": "ACTIVE"} if "export_vertex_color" in \
        bpy.ops.export_scene.gltf.get_rna_type().properties.keys() else {"export_colors": True}
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "frog_merchant.glb"), export_format='GLB',
                              use_selection=True, export_materials='NONE', export_texcoords=False,
                              export_normals=True, export_yup=True, export_animation_mode="NLA_TRACKS",
                              export_def_bones=False, **colours)
    print("built frog_merchant", tris(o), "tris, rigged", flush=True)


def _leaf_picture(path, size=256):
    """A lotus leaf seen from above, on UVs laid flat across it (u, v = x, y
    from -0.5 to 0.5): green, paler at the heart, veins running out."""
    import numpy as np
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size - 0.5
    r = np.hypot(x, y) * 2.0
    a = np.arctan2(y, x)
    veins = np.clip(1.0 - np.abs(np.sin(a * 11.0)) * 18.0 * np.clip(r, 0.05, 1) , 0, 1) * np.clip(r * 3.0, 0, 1)
    rng = np.random.default_rng(5)
    noise = rng.normal(0, 1, (size // 8, size // 8))
    noise = np.asarray(Image.fromarray(((noise + 3) / 6 * 255).clip(0, 255).astype(np.uint8)).resize(
        (size, size), Image.BICUBIC)).astype(np.float32) / 255 - 0.5
    green = np.array([0.17, 0.36, 0.11])
    heart = np.array([0.30, 0.46, 0.16])
    rim = np.array([0.22, 0.34, 0.10])
    col = green + (heart - green) * np.clip(1 - r * 1.6, 0, 1)[..., None] + (rim - green) * np.clip(r * 2 - 1.2, 0, 1)[..., None]
    col = col * (1 + noise[..., None] * 0.25) + veins[..., None] * np.array([0.09, 0.1, 0.04])
    Image.fromarray((np.clip(col * 1.5, 0, 1) * 255).astype(np.uint8)).save(path, optimize=True)


def lotus_leaf():
    """A lotus leaf floating (ASSET2's Lotus+Leaf.stl: a sculpt, 3M
    triangles, no colour), brought right down; its colour painted here on
    UVs laid flat from above. 1 m across, its middle at the origin (the
    water line), front +z (no front)."""
    fresh()
    bpy.ops.wm.stl_import(filepath=os.path.join(SRC, "lotus", "Lotus+Leaf.stl"))
    objs = meshes()
    realize(objs)
    o = objs[0]
    m = o.modifiers.new("lighter", 'DECIMATE')
    m.ratio = 1400 / len(o.data.polygons)
    apply_modifiers(objs)
    place(objs, length=1.0)
    me = o.data
    uv = me.uv_layers.new(name="atlas")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.x + 0.5, co.y + 0.5)
    _leaf_picture(os.path.join(OUT, "lotus_leaf_albedo.png"))
    export(objs, "lotus_leaf")


TREES = {
    "pine_a": ("pine", "pine_1.glb", 1300, 9.0),
    "pine_b": ("pine", "pine_3.glb", 1600, 11.0),
    "pine_c": ("pine", "pine_4.glb", 1500, 10.0),
    "dead_a": ("dead_tree", "dead_tree_1.glb", 1600, 9.5),
    "dead_b": ("dead_tree", "dead_tree_3.glb", 1600, 8.5),
    "twisted_a": ("twisted_tree", "twisted_tree_2.glb", 2200, 9.0),
}


def tree(name):
    """A tree (Quaternius, CC0) kept with its own bark and leaf pictures
    (leaves need their transparency): only brought down and resaved small.
    Its two surfaces, bark and leaves, stay apart in the mesh."""
    folder, file, budget, height = TREES[name]
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ART, folder, file))
    objs = meshes()
    realize(objs)
    place(objs, height=height)
    decimate(objs, budget)
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image is not None:
                    kind = "leaves" if "leaf" in n.image.name.lower() or "leaves" in n.image.name.lower() else "bark"
                    stem = os.path.splitext(n.image.name)[0].lower()
                    if stem.endswith("_normal"):
                        continue
                    dst = os.path.join(OUT, "%s_%s.png" % (folder, kind))
                    if not os.path.exists(dst):
                        tmp = os.path.join(tempfile.gettempdir(), "tree_tex.png")
                        n.image.filepath_raw = tmp
                        n.image.file_format = 'PNG'
                        n.image.save()
                        Image.open(tmp).convert("RGBA").resize((512, 512), Image.LANCZOS).save(dst, optimize=True)
            m.name = "leaves" if any("leaf" in (n.image.name.lower() if n.type == 'TEX_IMAGE' and n.image else "")
                                     or "leaves" in (n.image.name.lower() if n.type == 'TEX_IMAGE' and n.image else "")
                                     for n in m.node_tree.nodes) else "bark"
    select(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format='GLB',
                              use_selection=True, export_apply=True, export_materials='EXPORT',
                              export_image_format='NONE', export_texcoords=True, export_normals=True,
                              export_yup=True, **NO_COLOURS)
    print("built", name, tris(o), "tris", flush=True)


# Vertex colours aren't used (the pictures carry the colour).
NO_COLOURS = {"export_vertex_color": "NONE"} if "export_vertex_color" in \
    bpy.ops.export_scene.gltf.get_rna_type().properties.keys() else {"export_colors": False}


BUILDERS = {
    "campfire": campfire, "crate": crate, "backpack": backpack, "bookshop": bookshop, "boat": boat,
    "log": log, "drum": drum, "drum_trough": drum_trough, "ferry_stone": ferry_stone,
    "frog_merchant": frog_merchant, "lotus_leaf": lotus_leaf,
}
for _i in range(1, 10):
    BUILDERS["tent_%d" % _i] = (lambda i: lambda: tent(i))(_i)
for _t in TREES:
    BUILDERS[_t] = (lambda t: lambda: tree(t))(_t)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or list(BUILDERS):
        BUILDERS[name]()


if __name__ == "__main__":
    main()
