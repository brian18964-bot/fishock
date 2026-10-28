"""The oxygen tree (魚氧樹 - our own). A water plant of the shallows: a squat
teal bulb ringed in pale bands, held up on thick buttress roots that arch out
of it and spread over the ground, forking and meandering (the way the frost
flower's do, but heavy), and from its top a few curving stems each carrying a
bunch of translucent air-bladders like grapes, with ribbon leaves among them.
No glow. It grows only at the water's edge (OxyTree) and gives off bubbles
(RunView3D). Base on the ground at the origin, HEIGHT tall.

  bpyenv/bin/python tools/make_oxy_tree.py    (repo root)

Writes assets/models/items/oxy_tree.glb.
"""
import math
import os

import numpy as np

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


def ribbon(name, pts, widths, mat):
    """A flat strip along `pts` (a leaf), two-sided."""
    bm = bmesh.new()
    n = len(pts)
    left = []
    right = []
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = tan.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        left.append(bm.verts.new(p + side * widths[i]))
        right.append(bm.verts.new(p - side * widths[i]))
    for i in range(n - 1):
        bm.faces.new([left[i], left[i + 1], right[i + 1], right[i]])
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


def grow_roots(rng, mat, count, reach):
    """Thick buttress roots: out of the bulb's foot, up and over, then down to
    lie on the ground, meandering and forking into thinner ones (the same
    growing as the frost flower's roots, but heavy and short)."""
    out = []
    gaps = rng.uniform(0.6, 1.5, count)
    angs = np.cumsum(gaps / gaps.sum() * 2 * math.pi) + rng.uniform(0, 6.28)
    counter = [0]

    def thread(p0, ang, length, r0, arch, depth):
        steps = max(int(length / 0.035), 6)
        curve = rng.uniform(-0.45, 0.45) if depth == 0 else rng.uniform(-0.8, 0.8)
        pts = [Vector(p0)]
        radii = [r0]
        x, y = p0[0], p0[1]
        for s in range(1, steps + 1):
            t = s / steps
            ang += curve * 0.4 + rng.normal(0, 0.2)
            x += math.cos(ang) * length / steps
            y += math.sin(ang) * length / steps
            # an arch over (the buttress), settling on the ground
            z = r0 * 0.6 * (1 - t) + 0.012 + arch * math.sin(min(t * 1.5, 1.0) * math.pi * 0.5) * (1 - t) ** 1.5
            pts.append(Vector((x, y, z)))
            radii.append(max(r0 * (1 - t * 0.85), 0.004))
        counter[0] += 1
        out.append(tube("root_%d" % counter[0], pts, radii, mat, 6 if r0 > 0.015 else 4))
        if depth >= 2:
            return
        for _ in range(int(rng.integers(1, 3)) if depth == 0 else int(rng.integers(0, 2))):
            t = rng.uniform(0.35, 0.75)
            idx = int(t * steps)
            fa = math.atan2(pts[idx + 1].y - pts[idx].y, pts[idx + 1].x - pts[idx].x) + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0)
            thread(pts[idx], fa, length * rng.uniform(0.35, 0.55) * (1 - t * 0.4), radii[idx] * 0.7, 0.0, depth + 1)

    for a in angs:
        r0 = rng.uniform(0.032, 0.046)
        thread((math.cos(a) * 0.09, math.sin(a) * 0.09, 0.07), float(a), rng.uniform(reach * 0.55, reach), r0, rng.uniform(0.03, 0.08), 0)
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = np.random.default_rng(21)
    # (no glow anywhere: it's a plant, not a lamp)
    trunk_m = material("oxy_trunk", (0.1, 0.4, 0.4), rough=0.6)
    root_m = material("oxy_root", (0.12, 0.3, 0.27), rough=0.75)
    band_m = material("oxy_band", (0.6, 0.82, 0.78), rough=0.5)
    leaf_m = material("oxy_leaf", (0.16, 0.5, 0.42), rough=0.55)
    leaf_m.use_backface_culling = False
    sac_m = material("oxy_sac", (0.88, 0.97, 0.97), rough=0.2, alpha=0.85)
    parts = []
    # The bulb: squat and swollen, a little off true.
    pts = [Vector(p) for p in [(0, 0, 0.02), (0, 0, 0.07), (0.005, 0, 0.14), (0.01, 0.005, 0.22), (0.01, 0.01, 0.29), (0.0, 0.015, 0.34)]]
    radii = [0.08, 0.15, 0.17, 0.14, 0.08, 0.045]
    parts.append(tube("bulb", pts, radii, trunk_m, 16))
    for z, r in ((0.11, 0.168), (0.19, 0.162)):
        ring = [Vector((0.006 + math.cos(a) * r, math.sin(a) * r, z)) for a in [2 * math.pi * k / 18 for k in range(19)]]
        parts.append(tube("band", ring, [0.011] * 19, band_m, 5))
    # The roots.
    parts += grow_roots(rng, root_m, 6, 0.55)
    # Stems up from the top, each with a bunch of air-bladders (grapes).
    stems = [(0.3, 0.55, 0.12, 0.8), (2.0, 0.42, 0.10, 0.7), (3.6, 0.5, 0.14, 0.78), (5.0, 0.36, 0.08, 0.6)]
    for ang, rise, reach, top in stems:
        d = Vector((math.cos(ang), math.sin(ang), 0))
        start = Vector((0.0, 0.015, 0.33))
        pts_s = []
        for s_ in range(8):
            t = s_ / 7.0
            pts_s.append(start + d * reach * math.sin(t * math.pi * 0.8) + Vector((0, 0, (top - 0.33) * t)) + Vector((-d.y, d.x, 0)) * 0.04 * math.sin(t * 5))
        parts.append(tube("stem", pts_s, [0.026 - 0.016 * (s_ / 7) for s_ in range(8)], trunk_m, 7))
        tip = pts_s[-1]
        # the bunch: a bigger bladder at the tip, smaller ones about it
        parts.append(blob("bladder", tip + Vector((0, 0, 0.03)), (0.045, 0.045, 0.055), sac_m, 12, 7))
        for j in range(6):
            aa = 2 * math.pi * j / 6 + ang
            rr = 0.05 + 0.012 * (j % 2)
            parts.append(blob("bladder", tip + Vector((math.cos(aa) * rr, math.sin(aa) * rr, -0.01 - 0.028 * (j % 3))),
                              (0.028, 0.028, 0.034), sac_m, 10, 6))
    # Ribbon leaves from the bulb's top, arching out and drooping.
    for ang, length, lift in ((1.2, 0.5, 0.2), (2.9, 0.44, 0.16), (4.4, 0.52, 0.22), (5.7, 0.4, 0.14)):
        d = Vector((math.cos(ang), math.sin(ang), 0))
        pts_l = []
        wid = []
        for s_ in range(9):
            t = s_ / 8.0
            pts_l.append(Vector((0, 0.01, 0.3)) + d * length * t + Vector((0, 0, lift * math.sin(t * math.pi * 0.9) - 0.25 * t * t)))
            wid.append(0.045 * math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.7 + 0.004)
        parts.append(ribbon("leaf", pts_l, wid, leaf_m))
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
