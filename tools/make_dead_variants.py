"""Variants of the camp's two dead trees (user request: from the existing dead trees, two or three
more like them; some with our autumn leaves - the colours of tools/make_autumn_trees.py's).

Each starts from dead_a or dead_b (assets/models/camp, built by tools/build_camp_models.py) and is
bent, leant, twisted and stretched - the same family, not the same tree - and some get small cards
of turned leaves at their twigs' ends. Two surfaces as every camp tree: "bark" (the dead trees'
picture, dead_tree_bark.png) and "leaves" (CampModel shares the autumn trees' picture for them).

  bpyenv/bin/python tools/make_dead_variants.py       (repo root)

Writes assets/models/camp/dead_c.glb, dead_d.glb, dead_e.glb.
"""
import math
import os
import random

import bpy
from mathutils import Vector, Matrix

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CAMP = os.path.join(ROOT, "assets", "models", "camp")
# name: (from, seed, height, lean (deg), bend (deg), twist (deg), squash xy, leaf share, leaves per tip)
VARIANTS = {
    "dead_c": ("dead_a", 4, 10.4, 10.0, 34.0, 80.0, 0.85, 0.0, 0),
    "dead_d": ("dead_b", 9, 9.0, -5.0, -12.0, -50.0, 1.12, 0.55, 3),
    "dead_e": ("dead_a", 15, 8.6, 4.0, -22.0, 70.0, 1.05, 0.3, 2),
}


def material(name, picture, leaves=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(picture)
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if leaves:
        m.node_tree.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
    return m


def deform(ob, kind, angle, axis="Z"):
    mod = ob.modifiers.new(kind, "SIMPLE_DEFORM")
    mod.deform_method = kind
    mod.angle = math.radians(angle)
    mod.deform_axis = axis
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=mod.name)


def twig_tips(ob, rng, want):
    """Points out at the branches' ends: the vertices furthest from the trunk in their direction,
    high up, kept apart."""
    vs = [v.co.copy() for v in ob.data.vertices]
    top = max(v.z for v in vs)
    cands = [v for v in vs if v.z > top * 0.42 and math.hypot(v.x, v.y) > 0.9]
    cands.sort(key=lambda v: -(math.hypot(v.x, v.y) + 0.35 * v.z))
    tips = []
    for v in cands:
        if all((v - t).length > 1.1 for t in tips):
            tips.append(v)
        if len(tips) >= want:
            break
    rng.shuffle(tips)
    return tips


def leaf_cards(ob, tips, per, rng, leaves):
    verts, faces, uvs = [], [], []
    for p in tips:
        for _ in range(per):
            c = p + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.25, 0.45)))
            s = rng.uniform(0.45, 0.75)
            rot = Matrix.Rotation(rng.uniform(0, math.tau), 3, "Z") @ Matrix.Rotation(rng.uniform(-0.9, 0.9), 3, "X")
            base = len(verts)
            verts += [c + rot @ Vector(v) * s for v in ((-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1))]
            faces.append((base, base + 1, base + 2, base + 3))
            uvs += [(0, 0), (1, 0), (1, 1), (0, 1)]
    if not faces:
        return None
    me = bpy.data.meshes.new("leaves")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for i, loop in enumerate(me.loops):
        uv.data[i].uv = uvs[loop.vertex_index]
    card = bpy.data.objects.new("leaves", me)
    bpy.context.collection.objects.link(card)
    me.materials.append(leaves)
    return card


def make(name, spec):
    src, seed, height, lean, bend, twist, squash, share, per = spec
    rng = random.Random(seed)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(CAMP, src + ".glb"))
    ob = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    # (its own transform baked in, the foot at the origin)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bark = material("bark", os.path.join(CAMP, "dead_tree_bark.png"))
    leaves = material("leaves", os.path.join(CAMP, "autumn_tree_leaves.png"), True)
    ob.data.materials.clear()
    ob.data.materials.append(bark)
    # (the glTF's up is Y in Blender's import? - made Z-up already by the importer)
    zs = [v.co.z for v in ob.data.vertices]
    lo = min(zs)
    for v in ob.data.vertices:
        v.co.z -= lo
    # Stretched or stouter, twisted round its trunk, bent, leant.
    for v in ob.data.vertices:
        v.co.x *= squash
        v.co.y *= squash
    deform(ob, "TWIST", twist)
    # (the bend about the trunk's base: a curve up the trunk, the crown carried over)
    ob.location = (0, 0, 0)
    deform(ob, "BEND", bend, "Y")
    k = height / (max(v.co.z for v in ob.data.vertices) - min(v.co.z for v in ob.data.vertices))
    lo = min(v.co.z for v in ob.data.vertices)
    tilt = Matrix.Rotation(math.radians(lean), 3, "X")
    for v in ob.data.vertices:
        p = Vector((v.co.x * k, v.co.y * k, (v.co.z - lo) * k))
        v.co = tilt @ p
    # (the foot back on the ground, the trunk's base over the origin)
    lo = min(v.co.z for v in ob.data.vertices)
    foot = [v.co for v in ob.data.vertices if v.co.z < lo + 0.4]
    cx = sum(p.x for p in foot) / len(foot)
    cy = sum(p.y for p in foot) / len(foot)
    for v in ob.data.vertices:
        v.co = Vector((v.co.x - cx, v.co.y - cy, v.co.z - lo))
    if share > 0.0:
        tips = twig_tips(ob, rng, 40)
        tips = tips[:max(1, int(round(len(tips) * share)))]
        card = leaf_cards(ob, tips, per, rng, leaves)
        if card is not None:
            for o in bpy.context.scene.objects:
                o.select_set(o in (ob, card))
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.join()
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o)
    ob.name = name
    out = os.path.join(CAMP, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_apply=True,
                              export_image_format="NONE")  # (the pictures are CampModel's, set in the game)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("made", name, "from", src, "tris", tris, flush=True)


def main():
    for name, spec in VARIANTS.items():
        make(name, spec)
    os._exit(0)


if __name__ == "__main__":
    main()
