"""The frost flower (the user's clementisflower.fbx - a clematis, 455,000
faces, its bud drooping): thinned to about 12,000 faces, the bud turned up
(the stem's top bent smoothly so the bud stands upright), coloured by region
in vertex colours (frosted green stem and leaves, ice-white petals with a cold
blue heart), and its roots laid out over the ground round it - the cold patch
the player digs (FrostFlower). Base at the origin, HEIGHT tall.

  bpyenv/bin/python tools/make_frost_flower.py SRC.fbx    (repo root)

Writes assets/models/items/frost_flower.glb. The user's file stays out of the
repo.
"""
import math
import os
import sys

import bpy
import bmesh  # noqa: E402 (after bpy, which provides it)
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "frost_flower.glb")
HEIGHT = 0.7
KEEP = 0.016
# The stem rises straight to z ~ 3.1, then arcs over (the neck) to the bell
# hanging off its tip - the drooping bud, its mouth toward +y. The arc is cut
# away (ARC), the bell set on the stem's top and turned TURN degrees about it
# (its mouth to the sky), a short neck tube joining them.
STEM_TOP = 3.1
BELL_FROM = 3.72
ARC_X = 0.12
TURN = -92.0
ROOT_COUNT = 6
ROOT_REACH = 0.5


def tube(name, pts, r0, r1, mat, sides=6):
    """A tapering tube along `pts`."""
    bm = bmesh.new()
    rings = []
    n = len(pts)
    for i, p in enumerate(pts):
        t = i / (n - 1)
        r = r0 + (r1 - r0) * t
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = tan.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(tan).normalized()
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * r))
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            bm.faces.new([rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def main():
    src = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src)
    flower = next(o for o in bpy.data.objects if o.type == "MESH")
    bpy.context.view_layer.objects.active = flower
    mod = flower.modifiers.new("thin", "DECIMATE")
    mod.ratio = KEEP
    bpy.ops.object.modifier_apply(modifier="thin")
    bpy.ops.object.shade_smooth()
    me = flower.data
    # (the neck's arc out: every vertex on the stem's axis between its top and the bell)
    bm = bmesh.new()
    bm.from_mesh(me)
    arc = [v for v in bm.verts if abs(v.co.x) < ARC_X and STEM_TOP < v.co.z < BELL_FROM]
    bmesh.ops.delete(bm, geom=arc, context="VERTS")
    # (the bell: what's left above BELL_FROM; its closed end - furthest toward +y)
    bell = [v for v in bm.verts if v.co.z >= BELL_FROM]
    base = max(bell, key=lambda v: v.co.y).co.copy()
    pivot = Vector((0.0, 0.0, STEM_TOP))
    rot = Matrix.Rotation(math.radians(TURN), 3, "X")
    for v in bell:
        v.co = rot @ (v.co - base) + pivot
    bm.to_mesh(me)
    bm.free()
    n = len(me.vertices)
    co = np.array([v.co[:] for v in me.vertices])

    # Vertex colours by region (after the turn: the head is what's now above
    # the neck's height).
    cols = np.zeros((n, 4))
    stem = np.array([0.36, 0.58, 0.5, 1.0])
    leaf = np.array([0.5, 0.74, 0.68, 1.0])
    petal = np.array([0.86, 0.94, 1.0, 1.0])
    heart = np.array([0.35, 0.8, 1.0, 1.0])
    head_pts = co[co[:, 2] > STEM_TOP + 0.4]
    centre = np.array([float(np.median(head_pts[:, 0])), float(np.median(head_pts[:, 1])), float(np.median(head_pts[:, 2]))])
    for i in range(n):
        x, y, z = co[i]
        if z > STEM_TOP + 0.4:
            d = np.linalg.norm(np.array([x, y, z]) - centre)
            k = float(np.clip(1.0 - d / 0.9, 0.0, 1.0))
            cols[i] = petal * (1 - k) + heart * k
        elif z > 2.2 and abs(x) > 0.06:
            cols[i] = leaf
        else:
            # (frosted toward the top)
            cols[i] = stem * (1 - 0.3 * min(z / 3.0, 1.0)) + np.array([0.9, 0.97, 1.0, 1.0]) * 0.3 * min(z / 3.0, 1.0)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i in range(n):
        attr.data[i].color = cols[i]
    mat = bpy.data.materials.new("frost_flower")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs[0], b.inputs["Base Color"])
    # (no glow: a cold flower, not a lamp)
    b.inputs["Roughness"].default_value = 0.55
    flower.data.materials.clear()
    flower.data.materials.append(mat)

    # Roots over the ground, thin icy tubes spreading out and a little down.
    rmat = bpy.data.materials.new("frost_roots")
    rmat.use_nodes = True
    rb = next(x for x in rmat.node_tree.nodes if x.type == "BSDF_PRINCIPLED")
    rb.inputs["Base Color"].default_value = (0.55, 0.66, 0.7, 1.0)
    rb.inputs["Roughness"].default_value = 0.7
    rng = np.random.default_rng(4)
    scale = HEIGHT / float(co[:, 2].max())
    roots = []
    for k in range(ROOT_COUNT):
        a = 2 * math.pi * k / ROOT_COUNT + rng.uniform(-0.25, 0.25)
        reach = ROOT_REACH / scale * rng.uniform(0.7, 1.0)
        pts = []
        for s in range(9):
            t = s / 8.0
            wob = math.sin(t * 5 + k) * 0.12 * t
            ang = a + wob
            pts.append(Vector((math.cos(ang) * reach * t, math.sin(ang) * reach * t, 0.04 - 0.05 * t + 0.03 * math.sin(t * 9 + k))))
        # (thin and few, lying close to the ground)
        roots.append(tube("root_%d" % k, pts, 0.035, 0.008, rmat, 5))

    # The neck: a short stem piece from the stem's top up into the bell.
    nmat = mat
    neck = tube('neck', [Vector((0, 0, STEM_TOP - 0.15)), Vector((0, 0, STEM_TOP + 0.05)), Vector((0, 0, STEM_TOP + 0.25))], 0.03, 0.05, nmat)
    roots.append(neck)
    # Scale to HEIGHT, base on the ground at the origin.
    parts = [flower] + roots
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = flower
    for o in parts:
        for v in o.data.vertices:
            v.co = Vector((v.co.x, v.co.y, v.co.z)) * scale
    # (the stem's foot at the origin)
    foot = Vector((float(co[co[:, 2] < 0.3][:, 0].mean()), float(co[co[:, 2] < 0.3][:, 1].mean()), 0.0)) * scale
    for o in parts:
        for v in o.data.vertices:
            v.co -= foot
    top = max(v.co.z for v in flower.data.vertices)
    print("height", round(top, 3), "faces", sum(len(o.data.polygons) for o in parts))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True,
                              export_attributes=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
    os._exit(0)


if __name__ == "__main__":
    main()
