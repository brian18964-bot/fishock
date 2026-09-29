"""The water ghost - the user's zombie (Zombie.FBX, a Mixamo-rigged model
with no animation or textures), through the 55deg pipeline, in 8 facings.

User feedback: it moved stiffly (a borrowed walk with the arms posed out
by hand). Its motion now comes from Quaternius' Universal Animation
Library 2 (CC0, supplied by the user; not kept in the repo), carried over
to the Mixamo skeleton by tools/retarget.py:

  walk   Zombie_Walk_Fwd_Loop   rising, lurching out of the water, wading back
  claw   Zombie_Scratch         clinging to the player, clawing at them

  python tools/render_water_ghost.py ZOMBIE_FBX UAL2_GLB OUT_DIR

writes OUT_DIR/water_ghost_55deg_{albedo,normal}.png (rows = clip x facing,
in render_characters.DIRS order; COLS columns = frames, the claw row
using the first CLAW of them) and prints the cell size and sprite offset.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_characters as rc  # noqa: E402
import retarget  # noqa: E402

HEIGHT = 2.5      # units: a little taller than the player (2.38)
WALK = 10         # frames per facing
CLAW = 8
COLS = WALK
MIXAMO = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
          "neck_01": "Neck", "Head": "Head"}
for _s, _side in (("l", "Left"), ("r", "Right")):
    MIXAMO.update({f"clavicle_{_s}": f"{_side}Shoulder", f"upperarm_{_s}": f"{_side}Arm",
                   f"lowerarm_{_s}": f"{_side}ForeArm", f"hand_{_s}": f"{_side}Hand",
                   f"thigh_{_s}": f"{_side}UpLeg", f"calf_{_s}": f"{_side}Leg",
                   f"foot_{_s}": f"{_side}Foot", f"ball_{_s}": f"{_side}ToeBase"})
MIXAMO = {k: "mixamorig:" + v for k, v in MIXAMO.items()}
# Limbs are pointed the way the source's point: the zombie was modelled
# arms down, the library's mannequin in a T-pose.
AIMED = [b for b in MIXAMO if b.split("_")[0] in ("upperarm", "lowerarm", "hand", "thigh", "calf", "foot", "ball")]


def noise_paint(name, base, dark, scale=9.0, amount=0.6):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    coord = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 6.0
    nt.links.new(coord.outputs['Generated'], noise.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeMapRange')
    ramp.inputs['From Min'].default_value = 0.4
    ramp.inputs['From Max'].default_value = 0.75
    ramp.inputs['To Max'].default_value = amount
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Value'])
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.inputs[6].default_value = (*base, 1.0)
    mix.inputs[7].default_value = (*dark, 1.0)
    nt.links.new(ramp.outputs['Result'], mix.inputs['Factor'])
    nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
    return mat


def build(zombie_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=zombie_path)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in [o for o in bpy.data.objects if o.type == 'EMPTY']:
        bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    # No textures came with it: drowned skin, dark rags.
    skin = noise_paint("skin", (0.3, 0.4, 0.36), (0.12, 0.17, 0.15))
    rags = noise_paint("rags", (0.13, 0.15, 0.14), (0.05, 0.06, 0.05), scale=14.0)
    for o in meshes:
        o.data.materials.clear()
        o.data.materials.append(skin if len(o.data.vertices) > 2000 else rags)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)

    # Stood HEIGHT tall on the ground, centred (the meshes hang off the
    # armature, so it's the armature that's scaled and moved).
    pts = np.concatenate([rc.world_points(o) for o in meshes])
    lo, hi = pts.min(0), pts.max(0)
    s = HEIGHT / (hi[2] - lo[2])
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    arm.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -lo[2])) @ arm.matrix_world
    bpy.context.view_layer.update()
    return arm, meshes


def main():
    zombie, glb, out = sys.argv[-3], sys.argv[-2], sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    arm, meshes = build(zombie)
    src = retarget.load_library(glb)
    bones = list(MIXAMO)
    clips = [retarget.Clip(src, "Zombie_Walk_Fwd_Loop", bones, WALK, loop=True, ref="rest"),
             retarget.Clip(src, "Zombie_Scratch", bones, CLAW, loop=True, ref="rest")]
    # The hips' bob, in the zombie's size.
    hips = arm.matrix_world @ arm.data.bones[MIXAMO["pelvis"]].head_local
    lift = hips.z / clips[0].rest_head.z
    yaw = rs.Yaw(0.0)

    def pose(cell):
        c, d, i = cell
        clip = clips[c]
        yaw.set(0.0)
        retarget.apply(arm, clip.delta(i), MIXAMO, 1.0, aim={b: v for b, v in clip.dirs(i).items() if b in AIMED},
                       offset=clip.offset(i) * lift)
        yaw.set(rs.DIRS[d])

    cells = [(c, d, i) for c, n in enumerate((WALK, CLAW)) for d in rc.DIRS for i in range(n)]
    bs = []
    for cell in cells:
        pose(cell)
        bs.append(rs.screen_bounds(meshes))
    w, h, cx, cy = rc.fit(rc.union(bs))
    rs.setup_scene(cy, max(w, h) / rc.DENSITY, w * rc.HD, h * rc.HD, cx)
    prefix = os.path.join(out, "water_ghost_55deg")
    # The claw rows are shorter: padded to COLS with blank cells.
    grid = []
    for c, n in enumerate((WALK, CLAW)):
        for d in rc.DIRS:
            grid += [(c, d, i) for i in range(n)] + [None] * (COLS - n)

    def pose_or_hide(cell):
        for o in meshes:
            o.hide_render = cell is None
        if cell is not None:
            pose(cell)
    rs.pack_sheet(meshes, grid, pose_or_hide, (w * rc.HD, h * rc.HD), COLS, prefix)
    rc.downsample_normal(f"{prefix}_normal.png")
    meta = {"cell": [w, h], "offset": [round(cx * rc.DENSITY, 2), round(-cy * rc.DENSITY, 2)],
            "walk": WALK, "claw": CLAW, "cols": COLS}
    print(json.dumps({"water_ghost": meta}))


if __name__ == "__main__":
    main()
