"""The oil lamp (art_src/fuel_station/oil_lamp.fbx, the one the fuel
station sprite was rendered from) as a small glb for the menu's 3D
character to hold (CharacterViewer, hand_l): the lighter LOD, its colour
map brought down to 256 px and stored as JPEG, no normal map - it's a
hand-held thing seen small.

  bpyenv/bin/python tools/make_menu_lamp.py   (from the repo root)
"""
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
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "oil_lamp.glb"), export_format="GLB",
                          export_image_format="JPEG", export_jpeg_quality=85, export_animations=False)
