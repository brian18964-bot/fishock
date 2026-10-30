"""The salt (鹽巴's picture, made here): a small wooden dish heaped with coarse white
salt, a few grains spilled beside it. Base on the ground at the origin, 0.2 m wide.

  bpyenv/bin/python tools/make_salt.py     (repo root)

Writes assets/models/items/salt.glb.
"""
import math
import os
import random

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "salt.glb")


def mat(name, rgb, rough=0.6):
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
    random.seed(4)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    wood = mat("salt_wood", (0.42, 0.26, 0.12), 0.8)
    white = mat("salt_white", (0.96, 0.96, 0.98), 0.35)
    # the dish
    dish = add("primitive_cone_add", "dish", wood, vertices=32, radius1=0.5, radius2=0.72, depth=0.3, location=(0, 0, 0.15))
    # the heap
    heap = add("primitive_uv_sphere_add", "heap", white, radius=0.62, location=(0, 0, 0.32), segments=32, ring_count=16)
    heap.scale = (1.0, 1.0, 0.55)
    # grains: little cubes over the heap and beside the dish
    for i in range(70):
        a = random.random() * math.tau
        r = (random.random() ** 0.5) * 0.5
        z = 0.32 + 0.34 * (1 - (r / 0.62) ** 2) * 0.9
        c = add("primitive_cube_add", "g%d" % i, white, size=random.uniform(0.05, 0.09),
                location=(math.cos(a) * r, math.sin(a) * r, z + 0.02))
        c.rotation_euler = (random.random(), random.random(), random.random())
    for i in range(10):
        a = random.uniform(-0.6, 0.6) + 0.4
        r = random.uniform(0.82, 1.1)
        add("primitive_cube_add", "s%d" % i, white, size=random.uniform(0.04, 0.07), location=(math.cos(a) * r, math.sin(a) * r, 0.04))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    xs = [v.co.x for v in ob.data.vertices]
    k = 0.2 / (max(xs) - min(xs))
    for v in ob.data.vertices:
        v.co = Vector((v.co.x * k, v.co.y * k, v.co.z * k))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
    os._exit(0)


if __name__ == "__main__":
    main()
