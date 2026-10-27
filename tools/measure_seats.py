"""Where each character sits (user report: sat on a log, some sank into it -
each its own height): its body's lowest point under its hips, sat
(Sitting_Idle, its middle), the hips' own height and how far behind its
feet' spot they go (m, in its own frame: up, and back from where it stood).
Written into assets/sprites/player/<id>/fit.json as "seat": [height, hips,
back] for the camp
(CampLife: the log's top under the hips, the character raised or lowered
onto it).

  bpyenv/bin/python tools/measure_seats.py -- id [id ...]    (repo root)
"""
import json
import os
import sys

import bpy
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# How far round the hips (m, across and along) the seat's looked for.
AROUND = 0.12


def measure(cid):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets", "models", "characters", cid + ".glb"))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    act = next(a for a in bpy.data.actions if a.name.split("|")[-1].startswith("Sitting_Idle"))
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = act
    bpy.context.scene.frame_set(int(sum(act.frame_range) / 2))
    bpy.context.view_layer.update()
    hips = arm.matrix_world @ arm.pose.bones["pelvis"].head
    dg = bpy.context.evaluated_depsgraph_get()
    low = 9.0
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        tails = {g.index for g in o.vertex_groups if g.name.startswith(("tail", "hand", "lowerarm", "index", "middle",
                                                                          "ring", "pinky", "thumb"))}
        mesh = o.evaluated_get(dg).to_mesh()
        m = np.array(o.matrix_world)
        co = np.array([v.co for v in mesh.vertices])
        co = co @ m[:3, :3].T + m[:3, 3]
        skip = np.array([sum(g.weight for g in v.groups if g.group in tails) > 0.3 for v in o.data.vertices])
        near = (np.abs(co[:, 0] - hips.x) < AROUND) & (np.abs(co[:, 1] - hips.y) < AROUND) & ~skip
        if near.any():
            low = min(low, float(co[near, 2].min()))
        o.evaluated_get(dg).to_mesh_clear()
    # (the glTF's +z ahead is Blender's -y: behind is +y)
    return round(low, 3), round(float(hips.z), 3), round(float(hips.y), 3)


def main():
    ids = sys.argv[sys.argv.index("--") + 1:]
    for cid in ids:
        seat, hips, back = measure(cid)
        path = os.path.join(ROOT, "assets", "sprites", "player", cid, "fit.json")
        fit = json.load(open(path))
        fit["seat"] = [seat, hips, back]
        json.dump(fit, open(path, "w"), separators=(",", ":"))
        print("%s: seat %.3f m up, hips %.3f up and %.3f m back" % (cid, seat, hips, back))
    os._exit(0)


if __name__ == "__main__":
    main()
