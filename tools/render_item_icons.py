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


def model_pic(name, cells, turn, thick=1.0):
    """A picture from a model the shop sells (tools/prep_shop_models.py
    builds them along +x): laid side on, turned by `turn` (degrees about
    x, y, z)."""
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "items", name + ".glb"))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in bpy.data.objects:
        if o.parent is None and o is not root:
            o.parent = root
    root.rotation_euler = tuple(math.radians(a) for a in turn)
    root.scale = (1.0, thick, thick)
    bpy.context.view_layer.update()
    shoot(name, objs, cells)


def flashlight():
    # User request: the user's flashlight model (tools/prep_shop_models.py).
    model_pic("flashlight", (2, 1), (0, 0, -28))


# User request: the weapons (Profile.WEAPONS), as long as their bag cells.
def knife():
    model_pic("knife", (2, 1), (0, 0, -8))


def machete():
    model_pic("machete", (3, 1), (0, 0, -6))


def hatchet():
    model_pic("hatchet", (2, 1), (-90, 0, -90))


def glock():
    model_pic("glock", (2, 1), (0, 0, -12))


def battery():
    # User request: the user's battery model (tools/prep_shop_models.py).
    model_pic("battery", (1, 1), (0, 0, 25))


def lamp():
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "oil_lamp.glb"))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    lens = mat("glow", (1.0, 0.8, 0.4), emit=(1.0, 0.7, 0.3))
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.035, location=(0, 0, 0.14))
    flame = bpy.context.object
    flame.data.materials.append(lens)
    shoot("oil_lamp", objs + [flame], (1, 1))


def blob(name, loc, scale, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=loc, rotation=rot, segments=24, ring_count=12)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def stick(name, a, b, r, m):
    from mathutils import Vector
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + b) / 2, vertices=8)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    o.data.materials.append(m)
    return o


def cricket():
    """A live-bait cricket: brown body, head, long hind legs, feelers."""
    fresh()
    shell = mat("shell", (0.28, 0.17, 0.08), rough=0.35)
    dark = mat("dark", (0.12, 0.08, 0.05), rough=0.5)
    objs = [
        blob("body", (0, 0, 0.1), (0.42, 0.16, 0.14), shell),
        blob("thorax", (0.36, 0, 0.12), (0.14, 0.14, 0.13), shell),
        blob("head", (0.52, 0, 0.13), (0.1, 0.1, 0.1), dark),
    ]
    for s in (-1, 1):
        objs.append(stick("thigh%d" % s, (0.05, 0.1 * s, 0.14), (-0.3, 0.14 * s, 0.34), 0.035, shell))
        objs.append(stick("shin%d" % s, (-0.3, 0.14 * s, 0.34), (-0.55, 0.16 * s, 0.0), 0.02, dark))
        objs.append(stick("fore%d" % s, (0.35, 0.1 * s, 0.08), (0.45, 0.2 * s, -0.04), 0.015, dark))
        objs.append(stick("feeler%d" % s, (0.58, 0.04 * s, 0.18), (1.05, 0.25 * s, 0.4), 0.008, dark))
    shoot("cricket", objs, (1, 1))


def shrimp():
    """A live-bait shrimp: a curled, tapering, segmented body (a bevelled
    curve), a tail fan, little legs and long feelers."""
    import math as m
    fresh()
    body = mat("body", (0.9, 0.5, 0.38), rough=0.28)
    dark = mat("dark", (0.1, 0.05, 0.05), rough=0.4)
    cu = bpy.data.curves.new("shrimp", 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = 0.11
    cu.bevel_resolution = 6
    sp = cu.splines.new('NURBS')
    n = 9
    sp.points.add(n - 1)
    for i in range(n):
        a_ = m.radians(200 - i * 30)
        x, z = m.cos(a_) * 0.32, m.sin(a_) * 0.32
        sp.points[i].co = (x, 0, z, 1)
        sp.points[i].radius = 1.15 - i * 0.1
    sp.use_endpoint_u = True
    sp.order_u = 3
    o = bpy.data.objects.new("body", cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(body)
    objs = [o]
    # Segment lines: thin dark rings along the back.
    for i in range(1, 7):
        a_ = m.radians(200 - i * 30 - 15)
        objs.append(blob("ring%d" % i, (m.cos(a_) * 0.33, 0, m.sin(a_) * 0.33), (0.012, 0.1, 0.012), dark))
    head = blob("head", (-0.34, 0, -0.08), (0.16, 0.11, 0.12), body)
    objs.append(head)
    objs.append(blob("eye", (-0.44, 0.07, -0.03), (0.028, 0.028, 0.028), dark))
    tail = blob("fan", (0.3, 0, -0.3), (0.13, 0.03, 0.08), body, rot=(0, m.radians(40), 0))
    objs.append(tail)
    for k in range(5):
        a_ = m.radians(170 - k * 22)
        base = (m.cos(a_) * 0.24, 0.04, m.sin(a_) * 0.24)
        objs.append(stick("leg%d" % k, base, (base[0] * 0.55, 0.06, base[2] * 0.55 - 0.06), 0.01, body))
    for sgn in (-1, 1):
        objs.append(stick("feeler%d" % sgn, (-0.46, 0.03 * sgn, -0.1), (-1.05, 0.12 * sgn, 0.25), 0.006, dark))
    shoot("shrimp", objs, (1, 1))


def tea():
    """The merchant's hot tea (Camp v2): a chipped enamel tin mug, dark
    amber tea in it, a loop of handle."""
    import bmesh
    fresh()
    enamel = mat("enamel", (0.24, 0.26, 0.25), rough=0.3)
    rim = mat("rim", (0.08, 0.14, 0.26), rough=0.35)
    chip = mat("chip", (0.06, 0.06, 0.07), metal=0.6, rough=0.5)
    brew = mat("tea", (0.2, 0.07, 0.015), rough=0.05)
    up = (0, 0, 0)
    # The cup: a cylinder hollowed out (its top face dropped, walls made
    # thick).
    bpy.ops.mesh.primitive_cylinder_add(radius=0.3, depth=0.5, location=(0, 0, 0.25), vertices=32)
    cup = bpy.context.object
    cup.name = "cup"
    bm = bmesh.new()
    bm.from_mesh(cup.data)
    top = [f for f in bm.faces if f.normal.z > 0.9]
    bmesh.ops.delete(bm, geom=top, context="FACES_ONLY")
    bm.to_mesh(cup.data)
    bm.free()
    sol = cup.modifiers.new("wall", "SOLIDIFY")
    sol.thickness = 0.025
    cup.data.materials.append(enamel)
    bpy.ops.object.shade_smooth()
    objs = [cup,
            cyl("tea", 0.278, 0.02, (0, 0, 0.43), brew, rot=up),
            ]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.018, location=(0, 0, 0.5))
    lip = bpy.context.object
    lip.name = "rim"
    lip.data.materials.append(rim)
    bpy.ops.object.shade_smooth()
    objs.append(lip)
    # Chips in the enamel.
    for k, (a, z, r) in enumerate([(0.6, 0.32, 0.035), (2.2, 0.12, 0.05), (4.0, 0.4, 0.03), (5.1, 0.2, 0.04)]):
        objs.append(blob("chip%d" % k, (math.cos(a) * 0.3, math.sin(a) * 0.3, z), (r * 1.4, r * 1.4, r * 0.9), chip,
                         rot=(0, 0, a)))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.028, location=(0.32, 0, 0.27),
                                     rotation=(math.radians(90), 0, 0))
    handle = bpy.context.object
    handle.name = "handle"
    handle.data.materials.append(enamel)
    bpy.ops.object.shade_smooth()
    objs.append(handle)
    shoot("tea", objs, (1, 1))


def round7():
    """User request (round 7): pictures (for things dropped on the ground
    and dragged out of the bag) of the live baits made from the user's
    models and the things to use in a run."""
    for name, turn in (("worm", (0, 0, -15)), ("grasshopper", (0, 0, -20)), ("minnow", (0, 0, -10)), ("shrimp", (0, 0, -20)),
                       ("potion_vigor", (0, 0, 0)), ("potion_ward", (0, 0, 0)), ("eyeball", (0, 0, -105)), ("binoculars", (0, 0, 20))):
        model_pic(name, (1, 1), turn)


def round8():
    """Round 8: pictures of the two new eyes, the eyeball again (its nerve
    gone) and the net."""
    for name, turn in (("eyeball", (0, 0, -105)), ("eye_altar", (0, 0, -105)), ("eye_ghost", (0, 0, -105))):
        model_pic(name, (1, 1), turn)
    model_pic("net", (2, 1), (0, 0, -20))


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
    for weapon in (knife, machete, hatchet, glock):
        weapon()


if __name__ == "__main__":
    main()
