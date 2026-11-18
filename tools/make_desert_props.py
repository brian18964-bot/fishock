"""The desert's props made from the user's pack (user request: the "Des" release's models - "look
whether any can be used; before use each goes through our own changes and becomes our asset").
The pack itself stays out of the repo; each one here is changed into ours:

  - mammoth_fossil: the mammoth skeleton fallen on its side, sun-bleached (user request: the bones
    lie in the sand, not standing);
  - elephant_bones, crocodile_bones, wildcat_bones: from the user's second "Des" batch (the
    skeletons pack: an elephant, a crocodile, a big cat), each fallen where it died - brought
    down to a few thousand triangles from a third of a million, sized as the animal is (the
    elephant ~6 m with its tusks, the cat a lion's ~2.4 m), their five pictures each baked into
    one of ours: regraded to sun-bleached bone, sand-stained low down and mottled;
  - skull: the antlered deer skull, small, resting tipped in the sand, bleached;
  - saguaro, cholla: the two cacti, brought down to a few thousand triangles, dusted with sand
    (the cholla's spines left off - too fine to see), the saguaro half again as tall;
  - desert_rhazya: the desert shrub (Rhazya stricta) at a twentieth of its triangles - the dry
    bush of the dunes (RunView3D sways it);
  - desert_rock_a..c: the cliff rock made three - rounded, a long slab, a tall stack - its surface
    roughened, its picture warmed to the dunes' sandstone;
  - cracked_mud: the cracked-ground texture recoloured to the dunes' clay, softened (the dry
    hollows' crust).
Each a .glb (its picture inside, 1024 px) - the bones, the cacti and the skull with a .json of
the ground they stand on (circles x, z, r in m, the model's Godot frame), for Fossil; the bones'
circles with a fourth, the height (m) the bones reach in that spot - how deep the sand must be to
hide them (Fossil buries each a different depth each game). The dinosaur's (make_dino_fossil.py)
is given its heights here too, from its model.

  bpyenv/bin/python tools/make_desert_props.py -- <the pack's folder> [<the second batch's folder>] [only=a,b]
    (repo root; the second batch: Crocodile.fbx, Elephant.fbx, WildCat.fbx and, in the first pack's
    Blender_Pack folder, their pictures)
"""
import json
import math
import os
import random
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector, noise

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DESERT = os.path.join(ROOT, "assets", "models", "desert")
PROTO = os.path.join(ROOT, "assets", "models", "proto3d")
GROUND = os.path.join(ROOT, "assets", "sprites", "ground")
TMP = os.path.join(ROOT, "probe_tmp", "desert_props")


def fresh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in obs:
        o.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(obs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    for x in list(bpy.context.scene.objects):
        if x != o:
            bpy.data.objects.remove(x, do_unlink=True)
    return o


def picture(src, name, tint=(1, 1, 1), lift=0.0, sat=1.0, size=1024):
    """Our version of a picture: smaller, its colour moved (tint, a lift toward white, saturation)."""
    from PIL import Image, ImageEnhance
    Image.MAX_IMAGE_PIXELS = None
    im = Image.open(src).convert("RGB").resize((size, size), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(sat)
    a = np.asarray(im).astype(np.float32) / 255.0
    a = a * np.array(tint, np.float32)
    a = a + (1.0 - a) * lift
    out = os.path.join(TMP, name + ".jpg")
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(out, quality=88)
    return out


def dress(o, pics):
    """Each material's base colour its picture (pics: {material name prefix: picture}, "*" else)."""
    for slot in o.material_slots:
        m = slot.material
        if m is None:
            continue
        pic = next((p for k, p in pics.items() if k != "*" and m.name.startswith(k)), pics.get("*"))
        if pic is None:
            continue
        m.use_nodes = True
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])
        t = nt.nodes.new("ShaderNodeTexImage")
        img = bpy.data.images.load(pic)
        img.pack()
        t.image = img
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.9


def decimate(o, tris):
    now = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if now > tris:
        m = o.modifiers.new("d", "DECIMATE")
        m.ratio = tris / now
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="d")
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def settle(o, turn, scale, bury, centre=True):
    """`turn` (a Matrix) and `scale` applied; its middle over the origin, `bury` of its height under
    the ground (z 0); what's well under cut away."""
    me = o.data
    me.transform(Matrix.Scale(scale, 4) @ turn)
    pts = np.array([list(v.co) for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    h = hi[2] - lo[2]
    shift = Vector((-(lo[0] + hi[0]) / 2 if centre else 0.0, -(lo[1] + hi[1]) / 2 if centre else 0.0, -(lo[2] + bury * h)))
    me.transform(Matrix.Translation(shift))
    bm = bmesh.new()
    bm.from_mesh(me)
    gone = [f for f in bm.faces if all(v.co.z < -0.08 * max(h, 0.5) for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])


def footprint(o, cell, above, below=1e9, tops=False):
    """The ground it covers: cells of `cell` m with some of it between `above` and `below` m up (with
    `tops`, each with how high it reaches there)."""
    cells = {}
    for v in o.data.vertices:
        if above < v.co.z < below:
            k = (int(math.floor(v.co.x / cell)), int(math.floor(-v.co.y / cell)))
            cells[k] = max(cells.get(k, 0.0), v.co.z)
    circles = [[round((k[0] + 0.5) * cell, 3), round((k[1] + 0.5) * cell, 3), round(cell * 0.72, 3)] + ([round(cells[k], 2)] if tops else [])
               for k in sorted(cells)]
    pts = np.array([list(v.co) for v in o.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    reach = max([math.hypot(c[0], c[1]) + c[2] for c in circles] or [0.3])
    return {"circles": circles, "size": [round(float(hi[0] - lo[0]), 2), round(float(hi[1] - lo[1]), 2), round(float(hi[2]), 2)],
            "reach": round(float(reach), 2)}


def export(o, path, info=None):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="JPEG")
    if info is not None:
        with open(path.replace(".glb", ".json"), "w") as f:
            json.dump(info, f)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("made %s tris %d %s" % (os.path.basename(path), tris, ("reach %.2f circles %d size %s" % (info["reach"], len(info["circles"]), info["size"])) if info else ""), flush=True)


def mammoth(pack, _batch=None):
    o = fresh(os.path.join(pack, "fbx.1/fbx.1.fbx"))
    decimate(o, 9000)
    # (fallen on its side - rolled over its length, the spine a little up off the sand - its head
    # dipping)
    turn = Matrix.Rotation(math.radians(-4), 4, "X") @ Matrix.Rotation(math.radians(96), 4, "Y")
    settle(o, turn, 1.0, 0.04)
    dress(o, {"*": picture(os.path.join(pack, "textures.to1/x/textures/_gh0a76ve0mrj.png"), "mammoth_bones", (1.06, 1.0, 0.9), 0.12, 0.8)})
    export(o, os.path.join(DESERT, "mammoth_fossil.glb"), footprint(o, 0.5, 0.12, tops=True))


# The second batch's skeletons: sun-bleached bone, and the sand's stain on what lies low.
BONE = (0.77, 0.7, 0.58)
SAND_STAIN = (0.71, 0.56, 0.38)
STAIN_H = 0.45


def bone_picture(src, name, size=1024):
    """A part's picture made ours: its colour moved to sun-bleached bone (BONE), its light and dark
    kept and drawn out a little."""
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    a = np.asarray(Image.open(src).convert("RGB").resize((size, size), Image.LANCZOS)).astype(np.float32) / 255.0
    lum = a.mean(-1, keepdims=True)
    out = np.array(BONE, np.float32) * (1.0 + 1.8 * (lum - 0.62))
    path = os.path.join(TMP, name + ".png")
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(path)
    return path


def one_picture(o, parts, name, size=1024):
    """`o`'s materials - each its part's picture (parts: {material name, less any ".001": picture})
    - baked into one picture of ours on a fresh unwrap, sand-stained up to STAIN_H m from the
    ground and mottled; one material."""
    from PIL import Image
    me = o.data
    me.uv_layers[0].name = "src"
    me.uv_layers.active = me.uv_layers.new(name="UVMap")
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new("bake_" + name, size, size)
    for slot in o.material_slots:
        m = slot.material
        m.use_nodes = True
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        uv = nt.nodes.new("ShaderNodeUVMap")
        uv.uv_map = "src"
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(parts[m.name.split(".")[0]])
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        # (the stain: strong at the sand, gone by STAIN_H; a mottle of weathering all over)
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], sep.inputs["Vector"])
        low = nt.nodes.new("ShaderNodeMapRange")
        low.inputs["From Min"].default_value = 0.0
        low.inputs["From Max"].default_value = STAIN_H
        low.inputs["To Min"].default_value = 0.6
        low.inputs["To Max"].default_value = 0.0
        nt.links.new(sep.outputs["Z"], low.inputs["Value"])
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 1.7
        nz.inputs["Detail"].default_value = 4.0
        nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
        mot = nt.nodes.new("ShaderNodeMapRange")
        mot.inputs["From Min"].default_value = 0.48
        mot.inputs["From Max"].default_value = 0.72
        mot.inputs["To Min"].default_value = 0.0
        mot.inputs["To Max"].default_value = 0.35
        nt.links.new(nz.outputs["Fac"], mot.inputs["Value"])
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        add.use_clamp = True
        nt.links.new(low.outputs["Result"], add.inputs[0])
        nt.links.new(mot.outputs["Result"], add.inputs[1])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(add.outputs["Value"], mix.inputs["Factor"])
        nt.links.new(tex.outputs["Color"], mix.inputs[6])
        mix.inputs[7].default_value = SAND_STAIN + (1.0,)
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        target = nt.nodes.new("ShaderNodeTexImage")
        target.image = img
        nt.nodes.active = target
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE", margin=6)
    raw = os.path.join(TMP, name + "_bake.png")
    img.filepath_raw = raw
    img.file_format = "PNG"
    img.save()
    pic = os.path.join(TMP, name + ".jpg")
    Image.open(raw).convert("RGB").save(pic, quality=88, optimize=True)
    me.uv_layers.remove(me.uv_layers["src"])
    me.materials.clear()
    m = bpy.data.materials.new(name)
    me.materials.append(m)
    dress(o, {"*": pic})


def skeleton(path, length, turn, tris):
    """One of the second batch's skeletons: joined, `length` m long (its longest side), turned."""
    o = fresh(path)
    pts = np.array([list(v.co) for v in o.data.vertices])
    size = float(max(pts.max(0)[:2] - pts.min(0)[:2]))
    decimate(o, tris)
    settle(o, turn, length / size, 0.03)
    return o


def batch_skeleton(pack, batch, animal, length, turn, tris, cell):
    o = skeleton(os.path.join(batch, animal + ".fbx"), length, turn, tris)
    src = os.path.join(pack, "Blender_Pack/x/Blender_Pack", animal)
    parts = {}
    for slot in o.material_slots:
        part = slot.material.name.split(".")[0]
        parts[part] = bone_picture(os.path.join(src, part + "_BaseColor.png"), animal.lower() + "_" + part.lower(), 512)
    one_picture(o, parts, animal.lower() + "_bones")
    export(o, os.path.join(DESERT, animal.lower() + "_bones.glb"), footprint(o, cell, 0.12, tops=True))


def elephant(pack, batch):
    # (already fallen on its side in the pack; tipped a touch further over)
    batch_skeleton(pack, batch, "Elephant", 6.2, Matrix.Rotation(math.radians(-6), 4, "Y"), 9000, 0.5)


def crocodile(pack, batch):
    # (on its belly as it lay; rolled a little, its head turned)
    batch_skeleton(pack, batch, "Crocodile", 3.9, Matrix.Rotation(math.radians(9), 4, "Y"), 6000, 0.4)


def wildcat(pack, batch):
    # (a lion's size - the pack's is half again bigger - curled on its side)
    batch_skeleton(pack, batch, "WildCat", 2.4, Matrix.Rotation(math.radians(5), 4, "Y"), 5000, 0.3)


def dino_heights(_pack, _batch=None):
    """The dinosaur's circles (make_dino_fossil.py's) given their heights, from its model."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(DESERT, "dino_fossil.glb"))
    pts = np.concatenate([np.array([list(o.matrix_world @ v.co) for v in o.data.vertices])
                          for o in bpy.context.scene.objects if o.type == "MESH"])
    path = os.path.join(DESERT, "dino_fossil.json")
    info = json.load(open(path))
    for c in info["circles"]:
        half = c[2] / 0.72 / 2.0
        near = pts[(np.abs(pts[:, 0] - c[0]) <= half) & (np.abs(-pts[:, 1] - c[1]) <= half)]
        c[3:] = [round(float(near[:, 2].max()) if len(near) else 0.3, 2)]
    with open(path, "w") as f:
        json.dump(info, f)
    print("dino heights: %d circles, highest %.2f" % (len(info["circles"]), max(c[3] for c in info["circles"])), flush=True)


def skull(pack):
    o = fresh(os.path.join(pack, "Deer_Skull_High_Poly/Deer_Skull_High_Poly.fbx"))
    decimate(o, 2600)
    pts = np.array([list(v.co) for v in o.data.vertices])
    length = float(max(pts.max(0) - pts.min(0)))
    turn = Matrix.Rotation(math.radians(18), 4, "Y") @ Matrix.Rotation(math.radians(-12), 4, "X")
    settle(o, turn, 0.62 / length, 0.12)
    dress(o, {"*": picture(os.path.join(pack, "Deer_Skull_PBR_Textures/x/Deer Skull PBR Textures/Lowpoly full deer head_initialShadingGroup_BaseColor.1001.png"),
                          "skull_bone", (1.05, 1.0, 0.9), 0.15, 0.7)})
    export(o, os.path.join(DESERT, "skull.glb"), footprint(o, 0.25, 0.05, 0.4, tops=True))


def saguaro(pack):
    o = fresh(os.path.join(pack, "Cactus/x/F/Cactus.fbx"))
    decimate(o, 1800)
    settle(o, Matrix.Identity(4), 2.0, 0.02)
    dress(o, {"*": picture(os.path.join(pack, "Cactus/x/T/ueopfjiga_4K_Albedo.jpg"), "saguaro_skin", (1.0, 0.97, 0.86), 0.04, 0.82)})
    # (in the way: its trunk at the ground)
    export(o, os.path.join(DESERT, "saguaro.glb"), footprint(o, 0.3, 0.0, 0.7))


def cholla(pack):
    o = fresh(os.path.join(pack, "untitled/x/untitled.fbx"))
    # (its spines off - too fine to see from the game's camera)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    spine = [i for i, m in enumerate(o.data.materials) if m and m.name.startswith("Spine")]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in spine], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    decimate(o, 3200)
    settle(o, Matrix.Identity(4), 1.25, 0.02)
    fbm = os.path.join(pack, "untitled/x/untitled.fbm")
    dress(o, {"Stems": picture(os.path.join(fbm, "USC PipeCactus Diffuse.jpg"), "cholla_stems", (1.0, 0.97, 0.86), 0.04, 0.85, 512),
              "Petal": picture(os.path.join(fbm, "USC ChoaUpontia Petal Diffuse.jpg"), "cholla_petals", (1.0, 0.95, 0.85), 0.0, 0.9, 256)})
    export(o, os.path.join(DESERT, "cholla.glb"), footprint(o, 0.3, 0.0, 0.5))


def rhazya(pack):
    o = fresh(os.path.join(pack, "5/x/Rhazya stricta.fbx"))
    decimate(o, 3000)
    settle(o, Matrix.Identity(4), 1.0, 0.0)
    # (gone a little drier and dustier in our desert)
    dress(o, {"*": picture(os.path.join(pack, "5/x/T/xdjmfeqqx_4K_Albedo.jpg"), "rhazya_leaves", (1.04, 1.0, 0.86), 0.03, 0.75)})
    export(o, os.path.join(PROTO, "desert_rhazya.glb"))


def rocks(pack):
    pic = picture(os.path.join(pack, "Cliff_Rock_One_Texture4K/x/Cliff_Rock_One_Texture4K/Cliff_Rock_One_BaseColor.png"),
                  "desert_rock", (1.1, 0.98, 0.8), 0.05, 0.85)
    shapes = {"desert_rock_a": ((1.0, 1.0, 0.8), 3), "desert_rock_b": ((1.6, 0.9, 0.45), 11), "desert_rock_c": ((0.8, 0.8, 1.35), 23)}
    for name, (stretch, seed) in shapes.items():
        o = fresh(os.path.join(pack, "Cliffside_Rock_FBX/Cliffside_Rock_FBX.fbx"))
        # (made ours: subdivided, roughened by noise of its own seed, stretched to its shape)
        bpy.context.view_layer.objects.active = o
        sub = o.modifiers.new("s", "SUBSURF")
        sub.levels = 1
        sub.subdivision_type = "SIMPLE"
        bpy.ops.object.modifier_apply(modifier="s")
        rng = random.Random(seed)
        off = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
        pts = np.array([list(v.co) for v in o.data.vertices])
        c = Vector(pts.mean(0).tolist())
        size = float(max(pts.max(0) - pts.min(0)))
        for v in o.data.vertices:
            d = (v.co - c)
            n = noise.noise((v.co / size) * 2.6 + off) * 0.09 + noise.noise((v.co / size) * 7.0 + off) * 0.03
            v.co = c + d * (1.0 + n)
        o.data.transform(Matrix.Diagonal((stretch[0], stretch[1], stretch[2], 1.0)))
        settle(o, Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z"), 1.0, 0.08)
        dress(o, {"*": pic})
        export(o, os.path.join(PROTO, name + ".glb"))


def cracked(pack):
    """The cracked ground, made ours: its colour map is soft (the cracks only smudges), so the
    pattern comes from its second displacement map - clean crack lines round plates - drawn in
    the dunes' clay: pale plates whose rims curl up a touch paler, dark dry cracks; its colour
    map kept only as a faint mottle; the normal map worked out from the same heights so the
    light falls into the same cracks."""
    from PIL import Image, ImageFilter
    src = os.path.join(pack, "2K/x/2K/")

    def grey(name, size):
        im = Image.open(src + name).convert("L").resize((size, size), Image.LANCZOS)
        return np.asarray(im).astype(np.float32) / 255.0

    def blur(a, r):
        # (wrapped round, so the tile still meets itself)
        m = int(r * 3) + 2
        im = Image.fromarray((np.clip(np.pad(a, m, mode="wrap"), 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))
        return (np.asarray(im).astype(np.float32) / 255.0)[m:-m, m:-m]

    def smooth(e0, e1, x):
        t = np.clip((x - e0) / (e1 - e0), 0, 1)
        return t * t * (3 - 2 * t)

    h = grey("CrackedGroundDISPVar2_2K.png", 1024)
    tone = grey("CrackedGroundCOL_2K.png", 1024)
    tone = np.clip((tone - tone.mean()) / max(float(tone.std()), 1e-6), -2, 2)
    crack = 1.0 - smooth(0.2, 0.7, h)
    # (a plate's rim: near a crack, but not in it - curled up, catching more light)
    rim = np.clip(blur(crack, 5.0) * 2.2, 0, 1) * (1.0 - crack)
    clay = np.array([0.66, 0.54, 0.39], np.float32)
    dark = np.array([0.25, 0.19, 0.13], np.float32)
    plate = clay * (1.0 + 0.035 * tone[..., None]) * (1.0 + 0.1 * rim[..., None])
    out = plate * (1.0 - crack[..., None]) + dark * crack[..., None]
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(os.path.join(GROUND, "cracked_mud_albedo.png"), optimize=True)
    # the normal map (OpenGL's: green up) from the heights - the plates' rims lifted as well
    hn = grey("CrackedGroundDISPVar2_2K.png", 512)
    lift = blur(1.0 - smooth(0.2, 0.7, hn), 3.0) * (smooth(0.2, 0.7, hn))
    height = blur(hn * 0.8 + lift * 0.5, 0.8)
    wrapped = np.pad(height, 1, mode="wrap")
    dy, dx = (g[1:-1, 1:-1] for g in np.gradient(wrapped))
    s = 6.0
    nrm = np.stack([-dx * s, dy * s, np.ones_like(height)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8)).save(os.path.join(GROUND, "cracked_mud_normal.png"), optimize=True)
    print("made cracked_mud", flush=True)


MAKERS = {"mammoth": mammoth, "skull": skull, "saguaro": saguaro, "cholla": cholla, "rhazya": rhazya, "rocks": rocks,
          "cracked": cracked, "elephant": elephant, "crocodile": crocodile, "wildcat": wildcat, "dino_heights": dino_heights}
# (what needs the second batch's folder)
SECOND = ("elephant", "crocodile", "wildcat")


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[-1:]
    only = next((a[5:].split(",") for a in args if a.startswith("only=")), None)
    args = [a for a in args if not a.startswith("only=")]
    pack = args[0]
    batch = args[1] if len(args) > 1 else None
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(DESERT, exist_ok=True)
    for name, make in MAKERS.items():
        if only is not None and name not in only:
            continue
        if name in SECOND and batch is None:
            print("(no second batch's folder: %s skipped)" % name, flush=True)
            continue
        if name in SECOND:
            make(pack, batch)
        else:
            make(pack)
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    main()
