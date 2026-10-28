"""The shovel (鏟子; the user's Shovel.zip, a 3ds Max model of 719 faces):
its albedo cut to 1024 and written as JPEG, steel and wood by constants,
laid along +x with the blade at +x, its middle at the origin, SIZE m long.
It's the off hand's thing (Profile.SHOVEL_*), used to dig (Player.dig).

  bpyenv/bin/python tools/make_shovel.py DIR_WITH_Shovel.obj_AND_ShovelAlbedo.png    (repo root)

Writes assets/models/items/shovel.glb. The user's files stay out of the repo.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "shovel.glb")
SIZE = 1.0
MAX_TEX = 1024


def main():
    src = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=os.path.join(src, "Shovel.obj"))
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = np.array([v.co[:] for v in body.data.vertices])
    # (whichever way the file lies: the longest side onto x, the next onto y,
    # the thinnest onto z - turned, never mirrored)
    order = list(np.argsort(-np.ptp(co, axis=0)))
    perm = np.zeros((3, 3))
    for new_axis, old_axis in enumerate(order):
        perm[new_axis, old_axis] = 1.0
    if np.linalg.det(perm) < 0:
        perm[2] *= -1.0
    m = Matrix(perm.tolist())
    for v in body.data.vertices:
        v.co = m @ v.co
    co = np.array([v.co[:] for v in body.data.vertices])
    # the blade end: the wider (across the length) one, onto +x
    lo_end = co[co[:, 0] < co[:, 0].min() + 0.2 * np.ptp(co[:, 0])]
    hi_end = co[co[:, 0] > co[:, 0].max() - 0.2 * np.ptp(co[:, 0])]
    wide = lambda p: np.ptp(p[:, 1]) * np.ptp(p[:, 2])
    if wide(lo_end) > wide(hi_end):
        for v in body.data.vertices:
            v.co = Vector((-v.co.x, -v.co.y, v.co.z))
        co = np.array([v.co[:] for v in body.data.vertices])
    k = SIZE / np.ptp(co[:, 0])
    mid = Vector(((co[:, 0].max() + co[:, 0].min()) / 2, (co[:, 1].max() + co[:, 1].min()) / 2,
                  (co[:, 2].max() + co[:, 2].min()) / 2))
    for v in body.data.vertices:
        v.co = (v.co - mid) * k
    bpy.ops.object.shade_smooth()
    alb = bpy.data.images.load(os.path.join(src, "ShovelAlbedo.png"))
    alb.scale(MAX_TEX, MAX_TEX)
    mat = bpy.data.materials.new("shovel")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = alb
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.6
    b.inputs["Metallic"].default_value = 0.35
    body.data.materials.clear()
    body.data.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=85, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", len(body.data.polygons), "faces")
    os._exit(0)


if __name__ == "__main__":
    main()
