"""The autumn map's own trees (user request: the autumn wood - bare, dead trees, a few with their
last leaves). Grown here: a trunk that leans and bends, its branches forking three times over,
thinning as they go (tubes off curves); on some, small cards of turned leaves at the twigs' ends.
Two surfaces, as the camp's trees have: "bark" and "leaves" (CampModel's "autumn" family -
autumn_tree_bark.png, autumn_tree_leaves.png, made here too). About 9-11 m tall, like the pines.

  bpyenv/bin/python tools/make_autumn_trees.py       (repo root)

Writes assets/models/camp/autumn_<a..d>.glb and the two pictures.
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Vector, Matrix

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CAMP = os.path.join(ROOT, "assets", "models", "camp")
# (name, seed, height, lean, spread (deg), forks, leaf share of the twigs, leaves per twig)
TREES = [
    ("autumn_a", 3, 9.5, 0.05, 32, 3, 0.0, 0),
    ("autumn_b", 8, 8.4, 0.18, 48, 3, 0.0, 0),
    ("autumn_c", 13, 9.0, 0.08, 40, 3, 0.35, 3),
    ("autumn_d", 21, 10.0, 0.04, 36, 3, 0.75, 5),
]


def leaf_picture(path):
    """Turned leaves, scattered on nothing: rust, red, gold and brown, each a pointed oval with its
    vein."""
    from PIL import Image, ImageDraw
    rng = random.Random(5)
    size = 512
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    palette = [(196, 92, 28), (170, 44, 22), (214, 150, 40), (128, 70, 30), (186, 120, 34), (150, 36, 30)]
    for _ in range(90):
        cx, cy = rng.uniform(40, size - 40), rng.uniform(40, size - 40)
        if (cx - size / 2) ** 2 + (cy - size / 2) ** 2 > (size * 0.47) ** 2:
            continue
        length, width = rng.uniform(34, 58), rng.uniform(14, 24)
        a = rng.uniform(0, math.tau)
        col = palette[rng.randrange(len(palette))]
        shade = rng.uniform(0.8, 1.1)
        col = tuple(min(255, int(c * shade)) for c in col)
        pts = []
        for i in range(24):
            t = i / 23 * math.pi * 2
            x = math.cos(t) * length / 2
            y = math.sin(t) * width / 2 * (1 - 0.5 * max(0.0, math.cos(t)) ** 2)
            pts.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
        d = ImageDraw.Draw(im)
        d.polygon(pts, fill=col + (255,))
        vein = tuple(max(0, c - 50) for c in col) + (255,)
        d.line([(cx - math.cos(a) * length / 2, cy - math.sin(a) * length / 2), (cx + math.cos(a) * length / 2, cy + math.sin(a) * length / 2)], fill=vein, width=2)
    im.save(path)


def bark_picture(path):
    """The dead trees' bark, a little warmer and drier."""
    from PIL import Image, ImageEnhance
    im = Image.open(os.path.join(CAMP, "dead_tree_bark.png")).convert("RGB")
    r, g, b = im.split()
    im = Image.merge("RGB", (r.point(lambda v: min(255, int(v * 1.08))), g, b.point(lambda v: int(v * 0.9))))
    ImageEnhance.Brightness(im).enhance(0.95).save(path)


def mat(name, picture, leaves=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(picture)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if leaves:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
    bsdf.inputs["Roughness"].default_value = 0.95
    return m


def tube(points, radii, m):
    cu = bpy.data.curves.new("branch", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 0
    cu.resolution_u = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
        sp.points[i].radius = radii[i]
    ob = bpy.data.objects.new("branch", cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m)
    return ob


def grow(rng, start, direction, length, radius, depth, spec, bark, tips):
    """A branch from `start` along `direction`, bending a little as it goes; at its end (and along
    it) the next forks; its tip kept for leaves."""
    steps = 4
    pts, radii = [start], [radius]
    d = direction.normalized()
    p = start.copy()
    for i in range(steps):
        wobble = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.5))) * 0.18
        d = (d + wobble).normalized()
        p = p + d * (length / steps)
        pts.append(p.copy())
        radii.append(radius * (1.0 - 0.62 * (i + 1) / steps))
    tube(pts, radii, bark)
    if depth <= 0:
        tips.append((p.copy(), d.copy()))
        return
    n = 2 if depth < spec["forks"] else 3
    for k in range(n):
        at = rng.uniform(0.55, 1.0)
        idx = min(steps, max(1, int(round(at * steps))))
        base = pts[idx]
        spin = math.radians(rng.uniform(0, 360) + k * 360 / n)
        tilt = math.radians(spec["spread"] * rng.uniform(0.7, 1.3))
        side = Vector((math.cos(spin), math.sin(spin), 0.0))
        nd = (d * math.cos(tilt) + side * math.sin(tilt)).normalized()
        nd.z = max(nd.z, 0.12)
        grow(rng, base, nd, length * rng.uniform(0.55, 0.7), radii[idx] * 0.62, depth - 1, spec, bark, tips)


def leaf_cards(rng, tips, share, per, leaves):
    verts, faces, uvs = [], [], []
    for p, d in tips:
        if rng.random() > share:
            continue
        for _ in range(per):
            c = p + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.4)))
            s = rng.uniform(0.45, 0.8)
            rot = Matrix.Rotation(rng.uniform(0, math.tau), 3, "Z") @ Matrix.Rotation(rng.uniform(-0.9, 0.9), 3, "X")
            corners = [rot @ Vector(v) * s for v in ((-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1))]
            base = len(verts)
            verts += [c + v for v in corners]
            faces.append((base, base + 1, base + 2, base + 3))
            uvs += [(0, 0), (1, 0), (1, 1), (0, 1)]
    if not faces:
        return None
    me = bpy.data.meshes.new("leaves")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for i, loop in enumerate(me.loops):
        uv.data[i].uv = uvs[loop.vertex_index]
    ob = bpy.data.objects.new("leaves", me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(leaves)
    return ob


def make(spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(spec["seed"])
    bark = mat("bark", os.path.join(CAMP, "autumn_tree_bark.png"))
    leaves = mat("leaves", os.path.join(CAMP, "autumn_tree_leaves.png"), True)
    tips = []
    lean = Vector((spec["lean"], spec["lean"] * 0.4, 1.0)).normalized()
    trunk_len = spec["height"] * 0.42
    grow(rng, Vector((0, 0, -0.3)), lean, trunk_len, 0.34, spec["forks"], spec, bark, tips)
    branches = [o for o in bpy.context.scene.objects if o.type == "CURVE"]
    for o in branches:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    wood = bpy.context.view_layer.objects.active
    wood.name = spec["name"]
    # (the bark's picture wrapped round it)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")
    card = leaf_cards(rng, tips, spec["share"], spec["per"], leaves)
    if card is not None:
        bpy.ops.object.select_all(action="DESELECT")
        card.select_set(True)
        wood.select_set(True)
        bpy.context.view_layer.objects.active = wood
        bpy.ops.object.join()
    # (scaled to its height, its foot at the origin)
    zs = [v.co.z for v in wood.data.vertices]
    k = spec["height"] / (max(zs) - min(zs))
    for v in wood.data.vertices:
        v.co = Vector((v.co.x * k, v.co.y * k, (v.co.z - min(zs)) * k))
    out = os.path.join(CAMP, spec["name"] + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=False, export_apply=True,
                              export_image_format="NONE")  # (the pictures are CampModel's, set in the game)
    tris = sum(len(p.vertices) - 2 for p in wood.data.polygons)
    print("made", spec["name"], "tris", tris, flush=True)


def main():
    leaf_picture(os.path.join(CAMP, "autumn_tree_leaves.png"))
    bark_picture(os.path.join(CAMP, "autumn_tree_bark.png"))
    for name, seed, height, lean, spread, forks, share, per in TREES:
        make({"name": name, "seed": seed, "height": height, "lean": lean, "spread": spread, "forks": forks, "share": share, "per": per})
    os._exit(0)


if __name__ == "__main__":
    main()
