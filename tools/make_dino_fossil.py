"""The desert's dinosaur bones (user request: the desert map's dressing - "I remember there was a
dinosaur bones model; see if it's still there": the ASSET1 pack's SM_dino_midpoly, a long-necked
skeleton, 50k triangles, its 4096 px picture).

  bpyenv/bin/python tools/make_dino_fossil.py <ASSET1 fbx.fbx> <texture_pbr_20250901.png>   (repo root)

The pack itself stays out of the repo; this makes our own model from it:
  - laid on its side (the skeleton's whole profile up - ribs, legs, the curve of neck and tail -
    as a skeleton lies where it fell), half sunk in the sand (BURY of its height below the ground;
    what's well under it cut away);
  - brought down to ~TARGET triangles, SCALE of its size (about 9 m long);
  - its picture 1024 px, inside the model.
Writes assets/models/desert/dino_fossil.glb and dino_fossil.json - the ground it covers above the
sand, as circles (x, z, r in m, in the model's Godot frame: x, and z = -Blender y), for the 2D
solid (Fossil) - and its size.
"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "desert")
TMP = os.path.join(ROOT, "probe_tmp", "dino")
SCALE = 0.6
BURY = 0.22
TARGET = 11000
# (the footprint's grid, m, and how high above the sand a bone must be to be in the way)
CELL = 0.55
ABOVE = 0.12


def main():
    fbx, picture = sys.argv[-2], sys.argv[-1]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH" or "dino" not in o.name:
            bpy.data.objects.remove(o, do_unlink=True)
    d = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    d.name = "dino_fossil"
    bpy.context.view_layer.objects.active = d
    d.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # (on its side: its spine flat (it stood tipped 45 deg), then rolled over onto its flank)
    me = d.data
    me.transform(Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Rotation(math.radians(45), 4, "X"))
    me.transform(Matrix.Scale(SCALE, 4))
    pts = np.array([list(v.co) for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    height = hi[2] - lo[2]
    shift = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -(lo[2] + BURY * height)))
    me.transform(Matrix.Translation(shift))
    me.update()
    # (well under the sand: gone)
    bm = bmesh.new()
    bm.from_mesh(me)
    gone = [f for f in bm.faces if all(v.co.z < -0.12 for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(me)
    bm.free()
    tris0 = sum(len(p.vertices) - 2 for p in me.polygons)
    dec = d.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, TARGET / max(tris0, 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    # (one UV map - the picture's)
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    # (its picture, 1024 px)
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    small = os.path.join(TMP, "dino_fossil_bones.jpg")
    Image.open(picture).convert("RGB").resize((1024, 1024), Image.LANCZOS).save(small, quality=88)
    m = bpy.data.materials.new("Bones")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(small)
    img.pack()
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    me.materials.clear()
    me.materials.append(m)
    # The ground it covers above the sand: cells of CELL m with bone in them higher than ABOVE.
    cells = {}
    for v in me.vertices:
        if v.co.z > ABOVE:
            k = (int(math.floor(v.co.x / CELL)), int(math.floor(-v.co.y / CELL)))
            cells[k] = max(cells.get(k, 0.0), v.co.z)
    circles = [[round((k[0] + 0.5) * CELL, 3), round((k[1] + 0.5) * CELL, 3), round(CELL * 0.72, 3)] for k in sorted(cells)]
    pts = np.array([list(v.co) for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    info = {"circles": circles, "size": [round(hi[0] - lo[0], 2), round(hi[1] - lo[1], 2), round(hi[2], 2)],
            "reach": round(float(max(math.hypot(c[0], c[1]) + c[2] for c in circles)), 2)}
    with open(os.path.join(OUT, "dino_fossil.json"), "w") as f:
        json.dump(info, f)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dino_fossil.glb"), export_format="GLB",
                              use_selection=False, export_apply=True, export_image_format="JPEG")
    print("made dino_fossil tris %d (from %d) size %s circles %d reach %.2f" % (tris, tris0, info["size"], len(circles), info["reach"]), flush=True)
    os._exit(0)


if __name__ == "__main__":
    main()
