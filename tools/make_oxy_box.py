"""The oxygenated fish box (打氧魚箱; the user's LiveBaitBucket_v5.fbx - a
cooler box with a battery aerator on its side) made the game's own: its
parts kept (body, mounts, carry handle, pump, air line, air stone), the
textures cut to 1024 and written as JPEG, base on the ground at the origin,
the front (the latch) toward +z. Mounts the shop's preview, the bag's
icons and the hip in a run.

  bpyenv/bin/python tools/make_oxy_box.py SRC.fbx    (repo root)

Writes assets/models/items/oxy_box.glb. The user's files stay out of the repo.
"""
import os
import sys

import bpy
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "oxy_box.glb")
MAX_TEX = 1024


def main():
    src = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.parent = None
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    print("bounds", [round(x, 3) for x in lo], [round(x, 3) for x in hi])
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in meshes:
        for v in o.data.vertices:
            v.co -= shift
    for img in bpy.data.images:
        if img.size[0] > MAX_TEX:
            img.scale(MAX_TEX, MAX_TEX)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=85, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", sum(len(o.data.polygons) for o in meshes), "faces")
    os._exit(0)


if __name__ == "__main__":
    main()
