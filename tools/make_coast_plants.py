"""The sandy beach's plants, made from the user's new "Des" uploads (user request: the seaside -
coconut palms, beach grass; "before use each goes through our own changes and becomes our asset").
The uploads themselves stay out of the repo; each one here is changed into ours:

  - coco_a..c: coconut palms (CampModel's "coco" family - assets/models/camp/coco_<a..c>.glb, two
    surfaces "bark" and "leaves", their pictures coco_palm_bark.png and coco_palm_leaves.png made
    here too, set in the game) from palm_FBX's palm: brought down from 20 000 faces, stood on its
    foot, each its own height and its trunk bent its own way (the beach's palms lean out toward the
    sea); its fronds regraded to a deep night green, its bark - the upload has only its relief and
    shading - drawn here, grey-brown and ringed, from them;
  - beach_palm: the squat palm of the tropical pack (its finest version), the bush you hide in on
    the beach - its fronds and trunk regraded (proto model, its pictures inside);
  - beach_grass: the tropical pack's beach grass made a clump of its cards, taller, pale and dry at
    the tips (proto model);
  - coconut: the tropical pack's coconut, a fallen one, darker and duller (proto model).

  bpyenv/bin/python tools/make_coast_plants.py -- <palm_FBX's folder> <the tropical pack's shapes folder>
"""
import math
import os
import random
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CAMP = os.path.join(ROOT, "assets", "models", "camp")
PROTO = os.path.join(ROOT, "assets", "models", "proto3d")
TMP = os.path.join(ROOT, "probe_tmp", "coast_plants")

# name: height (m), how far its top leans out (share of the height), seed
PALMS = {"coco_a": (7.6, 0.1, 3), "coco_b": (8.8, 0.22, 11), "coco_c": (6.6, 0.3, 19)}
PALM_TRIS = 7000


def picture_rgba(src, out, size, tint=(1, 1, 1), sat=1.0, val=1.0):
    from PIL import Image, ImageEnhance
    im = Image.open(src).convert("RGBA")
    if size:
        im = im.resize(size, Image.LANCZOS)
    rgb = ImageEnhance.Color(im.convert("RGB")).enhance(sat)
    a = np.asarray(rgb).astype(np.float32) / 255.0 * np.array(tint, np.float32) * val
    alpha = np.asarray(im)[..., 3:4]
    Image.fromarray(np.concatenate([(np.clip(a, 0, 1) * 255).astype(np.uint8), alpha], -1), "RGBA").save(out)
    return out


def bark_picture(ao_src, normal_src, out, size=512):
    """The palm's bark (the upload's only its shading and relief): a warm grey-brown, darker in its
    shading, lit from above by its relief, with the faint rings of old frond scars."""
    from PIL import Image
    ao = np.asarray(Image.open(ao_src).convert("L").resize((size, size), Image.LANCZOS)).astype(np.float32) / 255.0
    nm = np.asarray(Image.open(normal_src).convert("RGB").resize((size, size), Image.LANCZOS)).astype(np.float32) / 255.0
    lit = np.clip(0.55 + 0.9 * (nm[..., 1] - 0.5) + 0.3 * (nm[..., 0] - 0.5), 0, 1)
    rings = 0.92 + 0.08 * np.sin(np.linspace(0, 2 * math.pi * 6, size))[:, None]
    base = np.array([0.42, 0.36, 0.29], np.float32)
    rgb = base * (0.45 + 0.65 * ao[..., None]) * (0.7 + 0.45 * lit[..., None]) * rings[..., None]
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(out)
    return out


def mat(name, picture, cut=False, pack=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(picture)
    if pack:
        img.pack()
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if cut:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
    bsdf.inputs["Roughness"].default_value = 0.95
    return m


def only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def join_meshes(keep=None):
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH" and (keep is None or keep(o))]
    for o in list(bpy.context.scene.objects):
        if o not in obs:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in obs:
        o.parent = None
    only(obs)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(obs) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def stand(o, height):
    """Its foot's middle at the origin, scaled to `height`."""
    me = o.data
    pts = np.array([list(v.co) for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    foot = pts[pts[:, 2] < lo[2] + 0.04 * (hi[2] - lo[2])]
    cx, cy = foot[:, 0].mean(), foot[:, 1].mean()
    me.transform(Matrix.Translation(Vector((-cx, -cy, -lo[2]))))
    k = height / (hi[2] - lo[2])
    me.transform(Matrix.Scale(k, 4))
    me.update()


def measure(name, o, leaf_mat):
    lo_leaf, reach, foot_r = 1e9, 0.0, 0.0
    me = o.data
    leafy = set()
    for p in me.polygons:
        if me.materials[p.material_index] is not None and me.materials[p.material_index].name.startswith(leaf_mat):
            leafy.update(p.vertices)
    for v in me.vertices:
        r = math.hypot(v.co.x, v.co.y)
        reach = max(reach, r)
        if v.index in leafy:
            lo_leaf = min(lo_leaf, v.co.z)
        elif v.co.z < 0.15:
            foot_r = max(foot_r, r)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("made %s tris %d foot_r %.2f reach %.2f lowest_leaf %.2f" % (name, tris, foot_r, reach, lo_leaf), flush=True)


def export(path, o, images):
    only([o])
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="AUTO" if images else "NONE")


def palm(name, height, lean, seed, src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src)
    o = join_meshes()
    # (its two surfaces as CampModel knows them: the trunk "bark", the fronds "leaves")
    for slot in o.material_slots:
        if slot.material is None:
            continue
        slot.material.name = "bark" if slot.material.name.endswith("001") else "leaves"
    stand(o, 1.0)
    d = o.modifiers.new("d", "DECIMATE")
    now = sum(len(p.vertices) - 2 for p in o.data.polygons)
    d.ratio = min(1.0, PALM_TRIS / now)
    d.use_collapse_triangulate = True
    only([o])
    bpy.ops.object.modifier_apply(modifier="d")
    # (each its own: its height, its trunk bent out its own way - more toward the top - and turned)
    rng = random.Random(seed)
    az = rng.uniform(0, math.tau)
    out = Vector((math.cos(az), math.sin(az), 0.0))
    for v in o.data.vertices:
        t = max(v.co.z, 0.0)
        v.co += out * lean * (t ** 1.8)
    o.data.update()
    stand(o, height)
    measure(name, o, "leaves")
    export(os.path.join(CAMP, name + ".glb"), o, False)


def proto(name, src, keep, height, pics, cut_mats, spin=0.0):
    """A proto model from the tropical pack: `keep` picks its finest version's objects; its pictures
    ours (pics: material name -> picture); `height` m tall."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.collada_import(filepath=src)
    o = join_meshes(keep)
    for slot in o.material_slots:
        m = slot.material
        if m is None or m.name not in pics:
            continue
        slot.material = mat(m.name, pics[m.name], m.name in cut_mats, pack=True)
    if spin:
        o.data.transform(Matrix.Rotation(spin, 4, "X"))
    stand(o, height)
    measure(name, o, "~")
    export(os.path.join(PROTO, name + ".glb"), o, True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    palm_dir, shapes = args[0], args[1]
    only_names = None
    for a in args[2:]:
        if a.startswith("only="):
            only_names = set(a[5:].split(","))
    os.makedirs(TMP, exist_ok=True)

    def want(n):
        return only_names is None or n in only_names

    if any(want(n) for n in PALMS):
        picture_rgba(os.path.join(palm_dir, "textures", "palm_leaf.png"), os.path.join(CAMP, "coco_palm_leaves.png"), (512, 968),
                     (0.82, 0.95, 0.78), 0.8, 0.8)
        bark_picture(os.path.join(palm_dir, "textures", "Bark_Tex_AO.png"), os.path.join(palm_dir, "textures", "Bark_Tex_N.png"),
                     os.path.join(CAMP, "coco_palm_bark.png"))
        for n, (h, lean, seed) in PALMS.items():
            if want(n):
                palm(n, h, lean, seed, os.path.join(palm_dir, "source", "palma.fbx"))
    if want("beach_palm"):
        base = os.path.join(shapes, "trees", "BeachPalm")
        fronds = picture_rgba(os.path.join(base, "KingsPalm2.dds"), os.path.join(TMP, "beach_palm_fronds.png"), None,
                              (0.85, 0.95, 0.8), 0.8, 0.82)
        trunk = picture_rgba(os.path.join(base, "PalmTrunkMap.dds"), os.path.join(TMP, "beach_palm_trunk.png"), None,
                             (1.0, 0.95, 0.88), 0.7, 0.85)
        proto("beach_palm", os.path.join(base, "BeachPalm01.DAE"), lambda o: o.name.startswith("BeachPalm256"), 1.9,
              {"KingsPalm01": fronds, "SquatPalm": trunk}, {"KingsPalm01"})
    if want("beach_grass"):
        base = os.path.join(shapes, "groundCover", "BeachGrass_01")
        blades = picture_rgba(os.path.join(base, "3td_BeachGrass_01.png"), os.path.join(TMP, "beach_grass_blades.png"), None,
                              (0.95, 0.95, 0.8), 0.7, 0.85)
        proto("beach_grass", os.path.join(base, "BeachGrass01.DAE"), None, 0.6, {"BeachGrass01": blades}, {"BeachGrass01"})
    if want("coconut"):
        base = os.path.join(shapes, "props", "coconut_brown")
        shell = picture_rgba(os.path.join(base, "3td_coconut_shell.jpg"), os.path.join(TMP, "coconut_shell.png"), (256, 256),
                             (0.9, 0.85, 0.8), 0.8, 0.8)
        proto("coconut", os.path.join(base, "CoconutBrown.DAE"), lambda o: o.name == "Object", 0.26, {"CoconutBrown": shell}, set())


main()
