"""The bag of frozen soil (冷凍土's picture - the user's Bag02, a photogrammetry
sack): its 4,000-triangle LOD only, half the size (0.35 m), a little
squatter and fuller (a bag of soil, not an empty sack), its canvas turned from
beige to a cold slate blue with a pale frost on it, the texture cut to
1024 JPEG. Base on the ground at the origin.

  bpyenv/bin/python tools/make_soil_bag.py DIR_WITH_Bag02.fbx_AND_Textures    (repo root)

Writes assets/models/items/frozen_soil.glb. The user's files stay out of the repo.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "frozen_soil.glb")
HEIGHT = 0.35
FULLER = 1.18
SQUAT = 0.9
MAX_TEX = 1024


def recolour(img):
    """Beige canvas -> slate blue, a pale frost over it (more toward the bottom
    third of the picture's grain, so it isn't an even wash)."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    lum = rgb @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    # (the canvas's own light and dark kept: the weave and the stains)
    tone = np.clip((lum - 0.05) / 0.7, 0.0, 1.0)
    dark = np.array([0.11, 0.17, 0.25], dtype=np.float32)
    light = np.array([0.55, 0.68, 0.8], dtype=np.float32)
    out = dark + (light - dark) * tone[..., None]
    yy, xx = np.mgrid[0:h, 0:w]
    rng = np.random.default_rng(3)
    grain = rng.random((h // 8 + 1, w // 8 + 1)).repeat(8, 0).repeat(8, 1)[:h, :w]
    frost = np.clip((grain - 0.55) * 3.0, 0.0, 1.0) * 0.45
    out = out + (np.array([0.9, 0.96, 1.0], dtype=np.float32) - out) * frost[..., None]
    px[..., :3] = out
    img.pixels[:] = px.reshape(-1)


def main():
    src = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "Bag02.fbx"))
    keep = next(o for o in bpy.data.objects if o.name == "Bag02_Low")
    for o in list(bpy.data.objects):
        if o is not keep:
            bpy.data.objects.remove(o, do_unlink=True)
    keep.parent = None
    bpy.context.view_layer.objects.active = keep
    bpy.ops.object.select_all(action="DESELECT")
    keep.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = np.array([v.co[:] for v in keep.data.vertices])
    # (whichever axis is the tall one: put it on z)
    k = HEIGHT / np.ptp(co[:, 2])
    mid = Vector(((co[:, 0].max() + co[:, 0].min()) / 2, (co[:, 1].max() + co[:, 1].min()) / 2, co[:, 2].min()))
    for v in keep.data.vertices:
        p = (v.co - mid) * k
        v.co = Vector((p.x * FULLER, p.y * FULLER, p.z * SQUAT))
    bpy.ops.object.shade_smooth()
    img = bpy.data.images.load(os.path.join(src, "Textures", "UE4", "Bag02_Bag02_BaseColor.png"))
    img.scale(MAX_TEX, MAX_TEX)
    recolour(img)
    mat = bpy.data.materials.new("frozen_soil")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    keep.data.materials.clear()
    keep.data.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=85, export_apply=True)
    top = max(v.co.z for v in keep.data.vertices)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", len(keep.data.polygons), "faces; height", round(top, 3))
    os._exit(0)


if __name__ == "__main__":
    main()
