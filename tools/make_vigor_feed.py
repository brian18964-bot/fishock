"""The vitality feed (活力飼料's picture, made here - no model came with it): a
small cloth sack tied at the neck with cord, a few green-gold pellets spilled
at its foot. Base on the ground at the origin, 0.3 m tall.

  bpyenv/bin/python tools/make_vigor_feed.py     (repo root)

Writes assets/models/items/vigor_feed.glb.
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "vigor_feed.glb")


def mat(name, rgb, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    return m


def add(kind, name, material, **kw):
    getattr(bpy.ops.mesh, kind)(**kw)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cloth = mat("feed_cloth", (0.55, 0.4, 0.22), 0.9)
    cord = mat("feed_cord", (0.25, 0.14, 0.07), 0.8)
    pellet = mat("feed_pellet", (0.42, 0.62, 0.16), 0.5)
    # the sack: a fat egg, its top gathered in
    body = add("primitive_uv_sphere_add", "body", cloth, radius=0.5, location=(0, 0, 0.5), segments=32, ring_count=16)
    body.scale = (1.0, 0.85, 0.95)
    for v in body.data.vertices:
        if v.co.z > 0.2:
            k = 1.0 - 0.75 * ((v.co.z - 0.2) / 0.3) ** 1.5
            v.co.x *= max(k, 0.18)
            v.co.y *= max(k, 0.18)
    # the gathered mouth and the tie
    add("primitive_cone_add", "frill", cloth, radius1=0.16, radius2=0.28, depth=0.3, location=(0, 0, 1.0), vertices=24)
    add("primitive_torus_add", "tie", cord, major_radius=0.17, minor_radius=0.035, location=(0, 0, 0.88), major_segments=24, minor_segments=8)
    # pellets at its foot
    for i, (x, y) in enumerate([(0.55, -0.4), (0.7, -0.15), (0.45, -0.62), (0.78, -0.45), (0.6, -0.8)]):
        add("primitive_uv_sphere_add", "pellet%d" % i, pellet, radius=0.08, location=(x, y, 0.08), segments=12, ring_count=8)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    top = max(v.co.z for v in ob.data.vertices)
    k = 0.3 / top
    cx = sum(v.co.x for v in ob.data.vertices) / len(ob.data.vertices)
    cy = sum(v.co.y for v in ob.data.vertices) / len(ob.data.vertices)
    for v in ob.data.vertices:
        v.co = Vector(((v.co.x - cx) * k, (v.co.y - cy) * k, v.co.z * k))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
    os._exit(0)


if __name__ == "__main__":
    main()
