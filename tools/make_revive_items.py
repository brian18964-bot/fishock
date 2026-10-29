"""The revive needle (復活針: the user's syringe, 3d-model.fbx) and the affix
dropper (洗點滴瓶: the user's BottleOne dropper bottle) - each part given a
plain colour of our own (the files carry none), all in one mesh per thing,
upright with its base on the ground at the origin.

  bpyenv/bin/python tools/make_revive_items.py -- SYRINGE.fbx BOTTLE.fbx   (repo root)

Writes assets/models/items/revive_needle.glb and affix_dropper.glb. The
user's files stay out of the repo.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items")
HEIGHT = 0.32


def mat(name, rgb, rough=0.4, metal=0.0, alpha=1.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Alpha"].default_value = alpha
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = 0.6
    if alpha < 1.0:
        m.blend_method = "BLEND"
    return m


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o.type == "MESH"]


def paint(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)


def finish(meshes, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    # (out from under the file's empties, their transforms kept)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    co = np.array([v.co[:] for v in ob.data.vertices])
    # the tall axis up (z)
    ext = np.ptp(co, axis=0)
    ax = int(np.argmax(ext))
    if ax != 2:
        for v in ob.data.vertices:
            c = list(v.co)
            c[2], c[ax] = c[ax], c[2]
            v.co = Vector(c)
        co = np.array([v.co[:] for v in ob.data.vertices])
    k = HEIGHT / np.ptp(co[:, 2])
    mid = Vector(((co[:, 0].max() + co[:, 0].min()) / 2, (co[:, 1].max() + co[:, 1].min()) / 2, co[:, 2].min()))
    for v in ob.data.vertices:
        v.co = (v.co - mid) * k
    bpy.ops.object.shade_smooth()
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True)
    print("wrote", path, os.path.getsize(path) // 1024, "KB")


def main():
    syringe, bottle = sys.argv[sys.argv.index("--") + 1:][:2]
    meshes = load(syringe)
    steel = mat("needle_steel", (0.72, 0.74, 0.78), 0.25, 0.9)
    glass = mat("needle_glass", (0.3, 0.95, 0.5), 0.1, 0.0, 0.75, emit=(0.15, 0.8, 0.3))
    serum = mat("needle_serum", (0.35, 1.0, 0.55), 0.2, 0.0, 1.0, emit=(0.2, 0.9, 0.4))
    rubber = mat("needle_rubber", (0.55, 0.1, 0.12), 0.7)
    plastic = mat("needle_plastic", (0.9, 0.9, 0.92), 0.5)
    # (by size: the long barrel is the biggest; see the preview)
    for o in meshes:
        d = o.dimensions
        n = o.name
        paint(o, {"Group_001": steel, "Group_002": steel, "Group_003": glass,
                  "Group_004": rubber, "Group_006": plastic}.get(n, steel))
    finish(meshes, "revive_needle")

    meshes = load(bottle)
    amber = mat("dropper_glass", (0.95, 0.62, 0.18), 0.12, 0.0, 0.55)
    cap = mat("dropper_cap", (0.12, 0.1, 0.1), 0.5)
    teat = mat("dropper_teat", (0.6, 0.12, 0.5), 0.6)
    paper = mat("dropper_label", (0.93, 0.9, 0.8), 0.9)
    liquid = mat("dropper_liquid", (0.45, 0.8, 1.0), 0.15, 0.0, 1.0, emit=(0.2, 0.5, 0.9))
    pick = {"Karet": teat, "Label": paper, "Pipet": liquid, "Pipet_atas": teat, "Sweep_1": amber, "Tutup": cap}
    for o in meshes:
        paint(o, pick.get(o.name, amber))
    finish(meshes, "affix_dropper")
    os._exit(0)


if __name__ == "__main__":
    main()
