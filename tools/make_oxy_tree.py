"""The oxygen tree (魚氧樹 - our own, after the style of the user's
mushroomtree.fbx: a swollen trunk on root legs, branches bearing pale caps -
but ours is teal with pale rings, no eyes, and its caps are translucent
air-sacs with little bubbles under them). It grows only at the water's edge
(OxyTree) and gives off bubbles (RunView3D). Base on the ground at the origin,
HEIGHT tall.

  bpyenv/bin/python tools/make_oxy_tree.py    (repo root)

Writes assets/models/items/oxy_tree.glb.
"""
import math
import os

import bpy
import bmesh  # noqa: E402 (after bpy, which provides it)
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "oxy_tree.glb")
HEIGHT = 0.9


def material(name, color, emission=None, strength=0.0, rough=0.5, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    if emission is not None:
        b.inputs["Emission Color"].default_value = (*emission, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m


def tube(name, pts, radii, mat, sides=10):
    """A tube along `pts` with a radius at each (a lofted swelling trunk)."""
    bm = bmesh.new()
    rings = []
    n = len(pts)
    side = None
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        # (the frame carried along the tube, not worked out afresh: no twisting)
        if side is None:
            side = tan.cross(Vector((0, 1, 0)))
            if side.length < 1e-3:
                side = Vector((1, 0, 0))
        side = (side - tan * side.dot(tan)).normalized()
        up = side.cross(tan).normalized()
        rings.append([bm.verts.new(p + (side * math.cos(2 * math.pi * k / sides) + up * math.sin(2 * math.pi * k / sides)) * radii[i])
                      for k in range(sides)])
    for i in range(n - 1):
        for k in range(sides):
            bm.faces.new([rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]])
    # (closed at the tip)
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.8)
    for k in range(sides):
        bm.faces.new([rings[-1][k], rings[-1][(k + 1) % sides], tip])
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return o


def blob(name, at, radii, mat, seg=14, rings=8):
    """A flattened sphere (a cap or an air sac)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + at
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    return o


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # (no glow anywhere: it's a plant, not a lamp)
    trunk_m = material("oxy_trunk", (0.1, 0.4, 0.4), rough=0.6)
    band_m = material("oxy_band", (0.6, 0.82, 0.78), rough=0.5)
    cap_m = material("oxy_cap", (0.7, 0.9, 0.86), rough=0.3, alpha=0.7)
    sac_m = material("oxy_sac", (0.88, 0.97, 0.97), rough=0.2, alpha=0.85)
    parts = []
    # The trunk: swollen low, narrowing to a neck that leans.
    pts = [Vector(p) for p in [(0, 0, 0.0), (0, 0, 0.07), (0.01, 0, 0.17), (0.02, 0, 0.29), (0.02, 0.01, 0.4), (0.0, 0.02, 0.5),
                               (-0.02, 0.03, 0.6)]]
    radii = [0.07, 0.14, 0.165, 0.13, 0.085, 0.06, 0.05]
    parts.append(tube("trunk", pts, radii, trunk_m, 14))
    # Rings round it.
    for z, r in ((0.13, 0.168), (0.22, 0.16), (0.31, 0.13)):
        cx = 0.01 + 0.01 * (z - 0.17) / 0.12
        ring = [Vector((cx + math.cos(a) * r, math.sin(a) * r, z)) for a in [2 * math.pi * k / 16 for k in range(17)]]
        parts.append(tube("band", ring, [0.012] * 17, band_m, 5))
    # Root legs: out and a little down, tapering.
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        leg = []
        for s in range(6):
            t = s / 5.0
            leg.append(Vector((math.cos(a) * (0.11 + 0.22 * t), math.sin(a) * (0.11 + 0.22 * t), 0.09 - 0.07 * t * t + 0.05 * math.sin(t * 3))))
        parts.append(tube("leg", leg, [0.045 - 0.03 * (s / 5) for s in range(6)], trunk_m, 7))
    # Branches with a cap each, and air sacs under the cap.
    branches = [(0.0, 0.0, 0.58, 0.27, 0.16, 0.85, 0.15), (2.1, 0.0, 0.5, 0.24, -0.1, 0.72, 0.11), (4.2, 0.0, 0.46, 0.22, 0.05, 0.66, 0.09)]
    for ang, _, z0, reach, lean, zt, cap_r in branches:
        d = Vector((math.cos(ang), math.sin(ang), 0))
        start = Vector((0.0, 0.03, z0))
        pts_b = []
        for s in range(7):
            t = s / 6.0
            pts_b.append(start + d * reach * t + Vector((0, 0, (zt - z0) * math.sin(t * math.pi / 2)))
                         + Vector((-d.y, d.x, 0)) * lean * math.sin(t * math.pi))
        parts.append(tube("branch", pts_b, [0.032 - 0.016 * (s / 6) for s in range(7)], trunk_m, 7))
        top = pts_b[-1]
        parts.append(blob("cap", top + Vector((0, 0, 0.02)), (cap_r, cap_r * 0.95, cap_r * 0.42), cap_m))
        for j in range(5):
            aa = 2 * math.pi * j / 5 + ang
            r2 = cap_r * 0.5
            parts.append(blob("sac", top + Vector((math.cos(aa) * r2, math.sin(aa) * r2, -0.02 - 0.015 * (j % 3))), (0.016, 0.016, 0.02), sac_m, 8, 5))
    # Scale to HEIGHT, base on the ground.
    top_z = max((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
    k = HEIGHT / top_z
    for o in parts:
        for v in o.data.vertices:
            v.co *= k
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", sum(len(o.data.polygons) for o in parts), "faces; top", round(top_z * k, 3))
    os._exit(0)


if __name__ == "__main__":
    main()
