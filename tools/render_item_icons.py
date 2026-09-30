"""Pictures for the things kept in the warehouse and the bag (Items): the
five rods (their models, laid flat, side on), the flashlight and the
battery (built here), and the oil lamp (its model). Same look as the fish
(render_fish.stage: side on, soft light, transparent), each sized to its
cells in the bag grid - a rod is three cells long, the flashlight two.

  bpyenv/bin/python tools/render_item_icons.py      (from the repo root)
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_fish as rf  # noqa: E402

ROOT = rf.ROOT
OUT = os.path.join(ROOT, "assets", "sprites", "items")
CELL = 64


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metal=0.0, rough=0.5, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 2.0
    return m


def cyl(name, r, depth, loc, m, verts=32, rot=(0, math.radians(90), 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def shoot(name, objs, cells):
    rf.SIZE = (CELL * cells[0] * 2, CELL * cells[1] * 2)
    rf.stage(objs)
    scene = bpy.context.scene
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("wrote", name)


def rod(tier):
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "fishing_rod_lvl%d.glb" % tier))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    # Lying along X, butt left, tip right, tilted up a touch so the reel shows.
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in bpy.data.objects:
        if o.parent is None and o is not root:
            o.parent = root
    root.rotation_euler = (0, math.radians(90), math.radians(-8))
    # Thickened: a real rod is a hair at this size.
    root.scale = (2.6, 2.6, 1.0)
    bpy.context.view_layer.update()
    shoot("rod_%d" % (tier - 1), objs, (3, 1))


def flashlight():
    fresh()
    body = mat("body", (0.08, 0.08, 0.09), metal=0.6, rough=0.35)
    chrome = mat("chrome", (0.75, 0.75, 0.78), metal=1.0, rough=0.2)
    lens = mat("lens", (1.0, 0.95, 0.7), emit=(1.0, 0.9, 0.6))
    grip = mat("grip", (0.2, 0.2, 0.22), rough=0.8)
    objs = [
        cyl("body", 0.11, 0.9, (0, 0, 0), body),
        cyl("head", 0.17, 0.3, (0.58, 0, 0), chrome),
        cyl("lens", 0.155, 0.02, (0.735, 0, 0), lens),
        cyl("tail", 0.12, 0.08, (-0.47, 0, 0), chrome),
    ]
    for i in range(5):
        objs.append(cyl("ring%d" % i, 0.118, 0.04, (-0.3 + i * 0.08, 0, 0), grip))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.15, 0, 0.11))
    btn = bpy.context.object
    btn.scale = (0.1, 0.06, 0.03)
    btn.data.materials.append(mat("btn", (0.8, 0.2, 0.15), rough=0.4))
    objs.append(btn)
    # Turned a little toward the camera so the lens shows.
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    root.rotation_euler = (0, 0, math.radians(-28))
    bpy.context.view_layer.update()
    shoot("flashlight", objs, (2, 1))


def battery():
    fresh()
    shell = mat("shell", (0.12, 0.3, 0.55), metal=0.3, rough=0.35)
    band = mat("band", (0.85, 0.65, 0.2), metal=0.8, rough=0.3)
    tip = mat("tip", (0.75, 0.75, 0.78), metal=1.0, rough=0.2)
    up = (0, 0, 0)
    objs = [
        cyl("shell", 0.2, 0.8, (0, 0, 0), shell, rot=up),
        cyl("band", 0.203, 0.22, (0, 0, 0.26), band, rot=up),
        cyl("tip", 0.07, 0.06, (0, 0, 0.43), tip, rot=up),
        cyl("base", 0.19, 0.02, (0, 0, -0.405), tip, rot=up),
    ]
    shoot("battery", objs, (1, 1))


def lamp():
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "oil_lamp.glb"))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    lens = mat("glow", (1.0, 0.8, 0.4), emit=(1.0, 0.7, 0.3))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=(0, 0, 0.14))
    flame = bpy.context.object
    flame.data.materials.append(lens)
    shoot("oil_lamp", objs + [flame], (1, 1))


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    if only:
        for name in only:
            globals()[name]()
        return
    for tier in range(1, 6):
        rod(tier)
    flashlight()
    battery()
    lamp()


if __name__ == "__main__":
    main()
