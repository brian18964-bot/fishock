"""The live-fish clasp (活魚扣, made here from the user's wire-loop stringer picture): a
long loop of stainless wire - round at the far end, drawn in to a twisted neck - and, at
the neck, a small sprung clasp (a barrel and a hooked pin) to hang a fish by. Lies flat
on the ground at the origin, 0.3 m long.

  bpyenv/bin/python tools/make_fish_clasp.py     (repo root)

Writes assets/models/items/fish_clasp.glb.
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "fish_clasp.glb")


def mat(name, rgb, rough=0.35, metal=0.9):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def wire(name, points, radius, material, cyclic=False):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    cu.resolution_u = 14
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, c in zip(sp.points, points):
        p.co = (c[0], c[1], c[2], 1.0)
    sp.use_cyclic_u = cyclic
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(material)
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    steel = mat("clasp_steel", (0.78, 0.8, 0.84))
    brass = mat("clasp_brass", (0.8, 0.58, 0.22), 0.4, 0.85)
    # The loop: a teardrop, round at the far end (x = 1), drawn in to the neck at x = 0.
    pts = []
    n = 40
    for i in range(n + 1):
        t = math.pi * (0.5 - i / n * 1.0)          # the round end, from the top round to the bottom
        pts.append((0.62 + 0.38 * math.cos(t) * 0.9 + 0.0, 0.34 * math.sin(t), 0.0))
    top = [(0.62, 0.34, 0.0)]
    # the two sides run in to the neck
    upper = [(0.62 - 0.62 * k / 10.0, 0.34 - 0.30 * (k / 10.0) ** 1.2, 0.0) for k in range(11)]
    lower = [(0.62 - 0.62 * k / 10.0, -0.34 + 0.30 * (k / 10.0) ** 1.2, 0.0) for k in range(11)]
    loop = list(reversed(upper)) + pts[1:-1] + lower
    wire("loop", loop, 0.012, steel)
    # the neck: the two wire ends twisted round each other
    twist_a, twist_b = [], []
    for k in range(24):
        x = 0.02 - 0.16 * k / 23.0
        a = k * 0.9
        twist_a.append((x, 0.016 * math.sin(a), 0.016 * math.cos(a)))
        twist_b.append((x, -0.016 * math.sin(a), -0.016 * math.cos(a)))
    wire("twist_a", twist_a, 0.01, steel)
    wire("twist_b", twist_b, 0.01, steel)
    # the clasp at the neck: a ring, a barrel, a hooked pin
    bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.011, location=(-0.24, 0.0, 0.0),
                                     rotation=(math.pi / 2, 0.0, 0.0), major_segments=28, minor_segments=8)
    ring = bpy.context.active_object
    ring.name = "ring"
    ring.data.materials.append(steel)
    bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=0.02, depth=0.15, location=(-0.17, 0.0, 0.0), rotation=(0.0, math.pi / 2, 0.0))
    barrel = bpy.context.active_object
    barrel.name = "barrel"
    barrel.data.materials.append(brass)
    # the pin: a straight shank out of the barrel, bent round into a hook
    hook = [(-0.09, 0.0, 0.0), (-0.02, 0.0, 0.0)]
    for k in range(1, 12):
        a = math.pi * k / 11.0
        hook.append((-0.02 + 0.05 * math.sin(a), 0.0, -0.05 * (1 - math.cos(a)) * 0.9))
    hook.append((-0.04, 0.0, -0.095))
    wire("pin", hook, 0.009, steel)
    bpy.ops.object.select_all(action="SELECT")
    # curves to meshes, then join
    for ob in list(bpy.context.selected_objects):
        if ob.type == "CURVE":
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.convert(target="MESH")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for p in ob.data.polygons:
        p.use_smooth = True
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    k = 0.3 / (max(xs) - min(xs))
    cx = (max(xs) + min(xs)) / 2.0
    cy = (max(ys) + min(ys)) / 2.0
    zs = [v.co.z for v in ob.data.vertices]
    for v in ob.data.vertices:
        v.co = Vector(((v.co.x - cx) * k, (v.co.y - cy) * k, (v.co.z - min(zs)) * k))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
    os._exit(0)


if __name__ == "__main__":
    main()
