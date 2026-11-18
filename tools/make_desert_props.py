"""The desert's props made from the user's pack (user request: the "Des" release's models - "look
whether any can be used; before use each goes through our own changes and becomes our asset").
The pack itself stays out of the repo; each one here is changed into ours:

  - mammoth_fossil: the mammoth skeleton sunk to its knees in the sand, listing, sun-bleached;
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
the ground they stand on (circles x, z, r in m, the model's Godot frame), for Fossil.

  bpyenv/bin/python tools/make_desert_props.py <the pack's folder, unpacked>   (repo root)
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


def footprint(o, cell, above, below=1e9):
    """The ground it covers: cells of `cell` m with some of it between `above` and `below` m up."""
    cells = set()
    for v in o.data.vertices:
        if above < v.co.z < below:
            cells.add((int(math.floor(v.co.x / cell)), int(math.floor(-v.co.y / cell))))
    circles = [[round((k[0] + 0.5) * cell, 3), round((k[1] + 0.5) * cell, 3), round(cell * 0.72, 3)] for k in sorted(cells)]
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


def mammoth(pack):
    o = fresh(os.path.join(pack, "fbx.1/fbx.1.fbx"))
    decimate(o, 9000)
    # (sunk to its knees, listing to one side, its head dipping)
    turn = Matrix.Rotation(math.radians(11), 4, "Y") @ Matrix.Rotation(math.radians(-7), 4, "X")
    settle(o, turn, 1.0, 0.3)
    dress(o, {"*": picture(os.path.join(pack, "textures.to1/x/textures/_gh0a76ve0mrj.png"), "mammoth_bones", (1.06, 1.0, 0.9), 0.12, 0.8)})
    export(o, os.path.join(DESERT, "mammoth_fossil.glb"), footprint(o, 0.5, 0.15))


def skull(pack):
    o = fresh(os.path.join(pack, "Deer_Skull_High_Poly/Deer_Skull_High_Poly.fbx"))
    decimate(o, 2600)
    pts = np.array([list(v.co) for v in o.data.vertices])
    length = float(max(pts.max(0) - pts.min(0)))
    turn = Matrix.Rotation(math.radians(18), 4, "Y") @ Matrix.Rotation(math.radians(-12), 4, "X")
    settle(o, turn, 0.62 / length, 0.12)
    dress(o, {"*": picture(os.path.join(pack, "Deer_Skull_PBR_Textures/x/Deer Skull PBR Textures/Lowpoly full deer head_initialShadingGroup_BaseColor.1001.png"),
                          "skull_bone", (1.05, 1.0, 0.9), 0.15, 0.7)})
    export(o, os.path.join(DESERT, "skull.glb"), footprint(o, 0.25, 0.05, 0.4))


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
    from PIL import Image, ImageFilter
    col = Image.open(os.path.join(pack, "2K/x/2K/CrackedGroundCOL_2K.png")).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    a = np.asarray(col).astype(np.float32) / 255.0
    # (recoloured: its light the dunes' pale clay, its cracks a dark dry brown)
    lum = a.mean(-1, keepdims=True)
    lum = (lum - lum.min()) / max(float(lum.max() - lum.min()), 1e-6)
    clay = np.array([0.64, 0.52, 0.37], np.float32)
    crack = np.array([0.3, 0.23, 0.16], np.float32)
    out = crack + (clay - crack) * np.clip(lum * 1.15, 0, 1)
    blurred = np.asarray(Image.fromarray((out * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
    out = out * 0.6 + blurred * 0.4
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(os.path.join(GROUND, "cracked_mud_albedo.png"), optimize=True)
    nrm = Image.open(os.path.join(pack, "2K/x/2K/CrackedGroundNRM_2K.png")).convert("RGB").resize((512, 512), Image.LANCZOS)
    nrm.save(os.path.join(GROUND, "cracked_mud_normal.png"), optimize=True)
    print("made cracked_mud", flush=True)


def main():
    pack = sys.argv[-1]
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(DESERT, exist_ok=True)
    for make in (mammoth, skull, saguaro, cholla, rhazya, rocks, cracked):
        make(pack)
    os._exit(0)


if __name__ == "__main__":
    main()
