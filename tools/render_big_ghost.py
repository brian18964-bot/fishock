"""The big ghost, animated. User feedback: the big ghost was stiff - one
still pose per facing, slid about and bobbed. The user's ghoul (CG+Soul.fbx,
see render_characters.py) came as a sculpt with no skeleton, so one is
built here to fit its pose (spine, neck, head, both arms - the lantern held
out in its right hand, the chain hanging from its left), each vertex bound
to the bones nearest it for their thickness, and moved by clips from
Quaternius' Universal Animation Library 2 (CC0, supplied by the user; not
kept in the repo), laid over its own pose (tools/retarget.py, ref = the
clip's average pose):

  float  Zombie_Idle_Loop       wandering, searching, asleep - swaying, head lolling
  chase  Zombie_Walk_Fwd_Loop   charging, hunting, carrying - leaning in, lurching
  eat    Consume                gnawing a thrown fish - the chain hand to its mouth

The smoke it rises out of churns (a displacement whose noise moves round a
circle, so the loop closes), the lantern and chain go with its hands.

  python tools/render_big_ghost.py RELEASE_DIR UAL2_GLB OUT_DIR [--preview]

writes OUT_DIR/big_ghost_55deg_{albedo,normal}.png - cells in rows of COLS,
in order clip x facing (render_characters.DIRS) x frame - and prints the
cell size, sprite offset and the lantern's position per cell (world px from
the origin at sprite scale 0.5).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_characters as rc  # noqa: E402
import retarget  # noqa: E402

COLS = 16
# name -> (frames, UAL2 clip, arm strength (left, right), lean deg)
CLIPS = {
    "float": (8, "Zombie_Idle_Loop", (0.8, 0.5), 0.0),
    "chase": (8, "Zombie_Walk_Fwd_Loop", (0.9, 0.5), 8.0),
    "eat": (6, "Consume", (1.0, 0.15), 12.0),
}

# The skeleton, fitted to the sculpt (FBX scene coordinates; it faces -Y).
# name: (head, tail, parent, radius) - radius: how thick the body is round
# the bone, so a vertex goes to the bone it's nearest *for its thickness*
# (the torso's flank isn't taken by the arm hanging beside it).
BONES = {
    "pelvis": ((2.05, -0.08, 1.15), (2.04, -0.12, 1.6), None, 0.22),
    "spine_01": ((2.04, -0.12, 1.6), (2.05, -0.25, 1.95), "pelvis", 0.22),
    "spine_02": ((2.05, -0.25, 1.95), (2.05, -0.2, 2.3), "spine_01", 0.22),
    "spine_03": ((2.05, -0.2, 2.3), (2.05, -0.25, 2.55), "spine_02", 0.22),
    "neck_01": ((2.05, -0.25, 2.55), (2.066, -0.38, 2.72), "spine_03", 0.08),
    "Head": ((2.066, -0.38, 2.72), (2.067, -0.45, 3.1), "neck_01", 0.15),
    "clavicle_r": ((2.0, -0.25, 2.47), (1.75, -0.32, 2.47), "spine_03", 0.08),
    "upperarm_r": ((1.75, -0.32, 2.47), (1.55, -0.88, 2.55), "clavicle_r", 0.06),
    "lowerarm_r": ((1.55, -0.88, 2.55), (1.63, -1.36, 2.52), "upperarm_r", 0.05),
    "hand_r": ((1.63, -1.36, 2.52), (1.64, -1.5, 2.47), "lowerarm_r", 0.05),
    "clavicle_l": ((2.1, -0.2, 2.47), (2.36, -0.15, 2.45), "spine_03", 0.08),
    "upperarm_l": ((2.36, -0.15, 2.45), (2.5, 0.03, 1.85), "clavicle_l", 0.06),
    "lowerarm_l": ((2.5, 0.03, 1.85), (2.57, -0.3, 1.4), "upperarm_l", 0.05),
    "hand_l": ((2.57, -0.3, 1.4), (2.57, -0.4, 1.22), "lowerarm_l", 0.05),
}
HOOD_BONES = ["spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r"]
RIGID = {"Lamp": "hand_r", "Sphere": "Head", "Torus.019": "hand_l", "BezierCurve": "hand_l"}
SKIN = "PM3D_Genesis{20}8{2E}1{20}Male6"
SMOKE = "Sphere.002"
SOFT = 0.35   # blend width, in thicknesses


def segment_distance(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def apply_decimate(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def local_points(o):
    """Vertices in the FBX scene's coordinates (the root's local space)."""
    co = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", co)
    m = np.array(o.matrix_basis)
    return co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]


def bind(o, arm, names):
    pts = local_points(o)
    heads = {n: np.array(BONES[n][0]) for n in names}
    tails = {n: np.array(BONES[n][1]) for n in names}
    d = np.stack([segment_distance(pts, heads[n], tails[n]) / BONES[n][3] for n in names], axis=1)
    w = np.exp(-(d - d.min(axis=1, keepdims=True)) / SOFT)
    w[w < 0.02] = 0.0
    w /= w.sum(axis=1, keepdims=True)
    for j, n in enumerate(names):
        vg = o.vertex_groups.new(name=n)
        col = w[:, j]
        for level in np.unique(np.round(col[col > 0] * 50) / 50):
            idx = np.nonzero(np.abs(np.round(col * 50) / 50 - level) < 1e-6)[0]
            vg.add(idx.tolist(), float(level), 'REPLACE')
    mod = o.modifiers.new("rig", 'ARMATURE')
    mod.object = arm


def bind_rigid(o, arm, bone):
    vg = o.vertex_groups.new(name=bone)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    mod = o.modifiers.new("rig", 'ARMATURE')
    mod.object = arm


def build_rig(meshes):
    root = meshes[0].parent
    data = bpy.data.armatures.new("ghoul")
    arm = bpy.data.objects.new("ghoul", data)
    bpy.context.scene.collection.objects.link(arm)
    arm.parent = root
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for name, (head, tail, parent, _r) in BONES.items():
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = head, tail
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    by_name = {o.name: o for o in meshes}
    skin = by_name[SKIN]
    apply_decimate(skin)
    bind(skin, arm, list(BONES))
    hood = by_name["hood 2"]
    apply_decimate(hood)
    bind(hood, arm, HOOD_BONES)
    for name, bone in RIGID.items():
        apply_decimate(by_name[name])
        bind_rigid(by_name[name], arm, bone)
    return arm


def churn(smoke):
    """The smoke's displacement; returns set(phase 0..1)."""
    tex = bpy.data.textures.new("churn", 'CLOUDS')
    tex.noise_scale = 0.35
    tex.noise_depth = 2
    probe = bpy.data.objects.new("churn_probe", None)
    bpy.context.scene.collection.objects.link(probe)
    probe.parent = smoke.parent
    mod = smoke.modifiers.new("churn", 'DISPLACE')
    mod.texture = tex
    mod.texture_coords = 'OBJECT'
    mod.texture_coords_object = probe
    mod.strength = 0.16
    mod.mid_level = 0.5

    def set_phase(p):
        a = p * math.tau
        probe.location = (0.35 * math.cos(a), 0.35 * math.sin(a), 0.2 * math.sin(a))
    return set_phase


def lean(deg):
    """Tips forward (toward -Y, the way the sculpt faces)."""
    return Quaternion(Vector((1.0, 0.0, 0.0)), math.radians(deg))


def main():
    preview = "--preview" in sys.argv
    release, glb, out = [a for a in sys.argv[1:] if a != "--preview"][-3:]
    os.makedirs(out, exist_ok=True)
    meshes, lamp = rc.build_ghost(os.path.join(release, "CG+Soul.fbx"))
    arm = build_rig(meshes)
    set_phase = churn(bpy.data.objects[SMOKE])

    src = retarget.load_library(glb)
    mapping = {b: b for b in BONES}
    clips = {}
    for name, (frames, clip, (ls, rs_), deg) in CLIPS.items():
        c = retarget.Clip(src, clip, list(BONES), frames, loop=True, ref="mean")
        strength = {b: (ls if b.endswith("_l") else rs_ if b.endswith("_r") else 1.0) for b in BONES}
        clips[name] = (c, strength, {"spine_01": lean(deg * 0.6), "spine_02": lean(deg * 0.4)} if deg else None)
    src.hide_render = True

    dirs = rc.DIRS if not preview else os.environ.get("PREVIEW_DIRS", "down left up_left").split()
    cells = [(name, d, i) for name in CLIPS for d in dirs for i in range(CLIPS[name][0])]
    yaw = rs.Yaw(0.0)

    def pose(cell):
        name, d, i = cell
        c, strength, extra = clips[name]
        retarget.apply(arm, c.delta(i), mapping, strength, extra)
        set_phase(i / CLIPS[name][0])
        yaw.set(rs.DIRS[d])

    bs = []
    for cell in cells:
        pose(cell)
        bs.append(rs.screen_bounds(meshes))
    w, h, cx, cy = rc.fit(rc.union(bs))
    rs.setup_scene(cy, max(w, h) / rc.DENSITY, w * rc.HD, h * rc.HD, cx)
    lamps = []
    for cell in cells:
        pose(cell)
        p = Vector(rc.world_points(lamp).mean(0))
        lamps.append([round(p.dot(rs.RIGHT) * rc.DENSITY * 0.5, 2), round(-p.dot(rs.UP) * rc.DENSITY * 0.5, 2)])
    prefix = os.path.join(out, "big_ghost_55deg")
    if preview:
        bpy.context.scene.cycles.samples = 8
    rs.pack_sheet(meshes, cells, pose, (w * rc.HD, h * rc.HD), COLS, prefix)
    rc.downsample_normal(f"{prefix}_normal.png")
    meta = {"cell": [w, h], "offset": [round(cx * rc.DENSITY, 2), round(-cy * rc.DENSITY, 2)],
            "clips": {n: CLIPS[n][0] for n in CLIPS}, "cols": COLS, "lamp": lamps}
    json.dump(meta, open(os.path.join(out, "big_ghost_meta.json"), "w"))
    print(json.dumps({k: v for k, v in meta.items() if k != "lamp"}))


if __name__ == "__main__":
    main()
