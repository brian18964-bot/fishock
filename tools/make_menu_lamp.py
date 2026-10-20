"""The oil lamp (art_src/fuel_station/oil_lamp.fbx, the one the fuel
station sprite was rendered from) as a small glb for the menu's 3D
character to hold (CharacterViewer, hand_l): the lighter LOD, its colour
map brought down to 256 px and stored as JPEG, no normal map - it's a
hand-held thing seen small.

It's given a bail (user request: the opening's lighting put the big Meshy
hands into the lamp - it had only a fat knob on top to hold): a thin wire
arc from lugs on the cap up over the top, BAIL_TOP above the base, the
fist closed round its middle (CharacterRig.LAMP_BAIL), across the lamp's
x - clear of the knob under it whatever size the hand.

  bpyenv/bin/python tools/make_menu_lamp.py   (from the repo root)
"""
import math
import os

import bpy

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "art_src", "fuel_station", "oil_lamp.fbx"))
for o in list(bpy.data.objects):
    if o.name != "OilLamp_LOD_1":
        bpy.data.objects.remove(o)
lamp = bpy.data.objects["OilLamp_LOD_1"]
lamp.location = (0, 0, 0)
lamp.data.materials.clear()
m = bpy.data.materials.new("OilLamp")
m.use_nodes = True
bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
img = bpy.data.images.load(os.path.join(ROOT, "art_src", "fuel_station", "tex", "Oil_Lamp_Color.PNG"))
img.scale(256, 256)
tex = m.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.5
bsdf.inputs["Metallic"].default_value = 0.3
lamp.data.materials.append(m)
# The bail: from the cap's lugs (BAIL_FOOT up, BAIL_HALF out on +-x) up to
# BAIL_TOP, squarer than a half circle so its top runs level a fist's width.
BAIL_FOOT = 0.24
BAIL_HALF = 0.072
BAIL_TOP = 0.38
WIRE = 0.0045
pts = []
for i in range(25):
    t = math.pi * i / 24
    c, s_ = math.cos(t), math.sin(t)
    pts.append((BAIL_HALF * math.copysign(abs(c) ** 0.75, c), 0.0,
                BAIL_FOOT + (BAIL_TOP - BAIL_FOOT) * abs(s_) ** 0.6))
cu = bpy.data.curves.new("Bail", "CURVE")
cu.dimensions = "3D"
cu.bevel_depth = WIRE
cu.bevel_resolution = 1
sp = cu.splines.new("POLY")
sp.points.add(len(pts) - 1)
for p, xyz in zip(sp.points, pts):
    p.co = (*xyz, 1.0)
bail = bpy.data.objects.new("Bail", cu)
bpy.context.scene.collection.objects.link(bail)
iron = bpy.data.materials.new("Bail")
iron.use_nodes = True
b2 = next(n for n in iron.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
b2.inputs["Base Color"].default_value = (0.06, 0.055, 0.05, 1.0)
b2.inputs["Roughness"].default_value = 0.45
b2.inputs["Metallic"].default_value = 0.8
cu.materials.append(iron)
# (lugs: small rings at its feet)
for side in (-1, 1):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.009, minor_radius=0.003, major_segments=10, minor_segments=4, location=(side * BAIL_HALF, 0, BAIL_FOOT),
                                     rotation=(0, math.radians(90), 0))
    bpy.context.object.data.materials.append(iron)
bpy.ops.object.select_all(action="DESELECT")
bail.select_set(True)
bpy.context.view_layer.objects.active = bail
bpy.ops.object.convert(target="MESH")
for o in bpy.data.objects:
    o.select_set(o.type == "MESH" and o.name != lamp.name)
bpy.context.view_layer.objects.active = bail
bpy.ops.object.join()
# (its origin on the lugs' line, so it folds down about its x - the game
# lays it over on a lamp stood down, CharacterRig.fold_bail())
bpy.context.scene.cursor.location = (0.0, 0.0, BAIL_FOOT)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "oil_lamp.glb"), export_format="GLB",
                          export_image_format="JPEG", export_jpeg_quality=85, export_animations=False)
