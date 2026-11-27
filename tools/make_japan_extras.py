"""More for the Japanese village from the user's third batch (user request: "補強日式" - "素材都要經過你再
製，成為我們的資產": the uploads are never committed, only what this makes; docs/RUINED_WORLD.md):

  - jp_toro_moss: the mossy stone lantern (Toro.fbx, its pictures in the pack's Textures/Lantern_textures),
    its picture and normal map cut down and toned ours (a little greyer, the moss less vivid);
  - jp_kasuga, jp_stupa_1, jp_stupa_2: the three scanned stone lanterns (a Kasuga lantern and two
    tiered stone towers - "Japanese Stone Lanterns.fbx" and its mossy pictures), each thinned from tens
    or hundreds of thousands of triangles (MOST), its picture toned the same way, stood to its height.

Each one mesh, its middle over the origin, standing on z = 0, into OUT_DIR, its footprint (and a
lantern's lamp) added to OUT_DIR/jp_assets.json beside the shrine set's (tools/make_japan_assets.py).

  bpyenv/bin/python tools/make_japan_extras.py -- toro=Toro.fbx toro_tex=Lantern_textures \
      lanterns="Japanese Stone Lanterns.fbx" out=assets/models/jp       (the lanterns' pictures in tex/ beside it)
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ARGS = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:])
OUT = ARGS["out"]
# our name: (the upload's object, its picture, height m, most triangles, the lamp's height share or None)
SCANS = {"jp_kasuga": ("Stone_Lantern_1", "Stone Lantern 1 UV Texture Mossy 2048x2048.jpg", 2.0, 1800, 0.62),
         "jp_stupa_1": ("Stone_Lantern_2", "Stone Lantern 2 UV Texture Mossy 2048x2048.jpg", 3.0, 2200, None),
         "jp_stupa_2": ("Stone_Lantern_3", "Stone Lantern 3 UV Texture Mossy 2048x2048.jpg", 3.2, 2400, None)}
TORO = (1.7, 1500, 0.66)
PX = 512
NRM = 256
GREY = 0.18
TINT = (1.0, 0.99, 0.95)
STEP = 0.25


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")


def stood(obj, high):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    pts = np.array([v.co[:] for v in obj.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    k = high / (hi[2] - lo[2])
    mid = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]))
    for v in obj.data.vertices:
        v.co = (v.co - mid) * k


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def thin(obj, most):
    bpy.context.view_layer.objects.active = obj
    while tris(obj) > most:
        have = tris(obj)
        d = obj.modifiers.new("thin", "DECIMATE")
        d.ratio = max(most / have, STEP)
        d.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")
        if tris(obj) > have * 0.95:
            break


def picture(path, size, colour, name):
    img = bpy.data.images.load(path)
    img.scale(size, size)
    px = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(size, size, 4)
    if colour:
        rgb = px[..., :3]
        lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        px[..., :3] = np.clip((rgb * (1 - GREY) + lum[..., None] * GREY) * np.array(TINT, np.float32), 0, 1)
    px[..., 3] = 1.0
    out = bpy.data.images.new(name, size, size)
    out.pixels.foreach_set(px.ravel())
    out.pack()
    bpy.data.images.remove(img)
    return out


def dress(obj, name, colour, normal=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.9
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = picture(colour, PX, True, name)
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    if normal:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = picture(normal, NRM, False, name + "_n")
        n.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs[0], nm.inputs["Color"])
        nt.links.new(nm.outputs[0], b.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(m)


def export(obj, name, footprints, lamp):
    pts = np.array([v.co[:] for v in obj.data.vertices])
    size = pts.max(0) - pts.min(0)
    footprints[name] = {"size": [round(float(size[0]), 3), round(float(size[1]), 3), round(float(size[2]), 3)], "tris": tris(obj)}
    if lamp is not None:
        footprints[name]["lamp"] = [0.0, round(float(size[2] * lamp), 3), 0.0]
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=82)
    print("WROTE", name, tris(obj), os.path.getsize(os.path.join(OUT, name + ".glb")))


def main():
    os.makedirs(OUT, exist_ok=True)
    jpath = os.path.join(OUT, "jp_assets.json")
    footprints = json.load(open(jpath)) if os.path.exists(jpath) else {}
    # The mossy toro.
    clear()
    bpy.ops.import_scene.fbx(filepath=ARGS["toro"])
    obj = [o for o in bpy.data.objects if o.type == "MESH"][0]
    for o in list(bpy.data.objects):
        if o is not obj:
            bpy.data.objects.remove(o)
    high, most, lamp = TORO
    stood(obj, high)
    thin(obj, most)
    tex = ARGS["toro_tex"]
    dress(obj, "jp_toro_moss", os.path.join(tex, "Lantern_BaseColor.png"), os.path.join(tex, "Lantern_Normal.png"))
    export(obj, "jp_toro_moss", footprints, lamp)
    # The scanned lanterns and towers.
    texdir = os.path.join(os.path.dirname(ARGS["lanterns"]), "tex")
    for name, (src, pic, high, most, lamp) in SCANS.items():
        clear()
        bpy.ops.import_scene.fbx(filepath=ARGS["lanterns"])
        obj = bpy.data.objects[src]
        for o in list(bpy.data.objects):
            if o is not obj:
                bpy.data.objects.remove(o)
        stood(obj, high)
        thin(obj, most)
        dress(obj, name, os.path.join(texdir, pic))
        export(obj, name, footprints, lamp)
    json.dump(footprints, open(jpath, "w"), indent=1, sort_keys=True)


main()
