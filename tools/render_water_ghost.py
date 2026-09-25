"""The water ghost - the user's zombie (Zombie.FBX, a Mixamo-rigged model
with no animation or textures), through the 55deg pipeline: a lurching
walk, arms reaching out in front, in 8 facings.

The walk is Mixamo's Y Bot walk (same skeleton - Kevin-Kwan's
Unity3D-FishingRodMotion, as for the player) kept in place; the arms are
posed straight out ahead instead of swinging. Neither model is kept in the
repo.

  python tools/render_water_ghost.py ZOMBIE_FBX YBOT_WALK_FBX OUT_DIR

writes OUT_DIR/water_ghost_55deg_{albedo,normal}.png (rows = facings, in
render_characters.DIRS order; columns = walk frames) and prints the cell
size and sprite offset.
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

HEIGHT = 2.5      # units: a little taller than the player (2.38)
FRAMES = 6        # walk frames per facing
ARM_BONES = ["mixamorig:%s%s" % (side, b) for side in ("Left", "Right")
             for b in ("Shoulder", "Arm", "ForeArm", "Hand")]


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


def build(zombie_path, walk_path):
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

    # The walk, from Y Bot; its own objects go.
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=walk_path)
    for o in set(bpy.data.objects) - before:
        bpy.data.objects.remove(o, do_unlink=True)
    walk = max(bpy.data.actions, key=lambda a: len(a.fcurves))
    for fc in list(walk.fcurves):
        # In place (no root motion or hip travel - Y Bot's are in its own
        # scale anyway), and the arms are posed by hand.
        if fc.data_path.endswith(".location") or any(f'"{b}"' in fc.data_path for b in ARM_BONES):
            walk.fcurves.remove(fc)
    ad = arm.animation_data_create()
    ad.action = walk

    # Stood HEIGHT tall on the ground, centred (the meshes hang off the
    # armature, so it's the armature that's scaled and moved).
    bpy.context.scene.frame_set(int(walk.frame_range[0]))
    pts = np.concatenate([rc.world_points(o) for o in meshes])
    lo, hi = pts.min(0), pts.max(0)
    s = HEIGHT / (hi[2] - lo[2])
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    arm.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -lo[2])) @ arm.matrix_world
    bpy.context.view_layer.update()
    return arm, meshes, walk


def aim(arm, name, world_dir):
    """Turns pose bone `name` so it points along `world_dir`."""
    pb = arm.pose.bones[name]
    to_arm = arm.matrix_world.to_3x3().normalized().inverted()
    d = (to_arm @ world_dir).normalized()
    cur = pb.matrix.copy()
    rot = cur.col[1].xyz.normalized().rotation_difference(d).to_matrix().to_4x4()
    new = rot @ cur
    new.translation = cur.translation
    pb.matrix = new
    bpy.context.view_layer.update()


def reach(arm, sway, facing=0.0):
    """Both arms out in front (the model faces -Y before it's turned to
    `facing`), a little apart and hanging at the wrists; `sway` swings them
    a touch with the step."""
    turn = Matrix.Rotation(math.radians(facing), 3, 'Z')
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        lift = 0.08 + 0.06 * sway * sx
        aim(arm, f"mixamorig:{side}Arm", turn @ Vector((0.22 * sx, -1.0, lift)))
        aim(arm, f"mixamorig:{side}ForeArm", turn @ Vector((0.05 * sx, -1.0, lift + 0.08)))
        aim(arm, f"mixamorig:{side}Hand", turn @ Vector((0.0, -1.0, -0.45)))


def main():
    zombie, walk_path, out = sys.argv[-3], sys.argv[-2], sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    arm, meshes, walk = build(zombie, walk_path)
    start, end = walk.frame_range
    frames = [start + (end - start) * i / FRAMES for i in range(FRAMES)]
    yaw = rs.Yaw(0.0)

    def pose(cell):
        d, i = cell
        yaw.set(rs.DIRS[d])
        whole = math.floor(frames[i])
        bpy.context.scene.frame_set(int(whole), subframe=frames[i] - whole)
        bpy.context.view_layer.update()
        reach(arm, math.sin(i / FRAMES * math.tau), rs.DIRS[d])

    bs = []
    for d in rc.DIRS:
        for i in range(FRAMES):
            pose((d, i))
            bs.append(rs.screen_bounds(meshes))
    w, h, cx, cy = rc.fit(rc.union(bs))
    rs.setup_scene(cy, max(w, h) / rc.DENSITY, w * rc.HD, h * rc.HD, cx)
    prefix = os.path.join(out, "water_ghost_55deg")
    cells = [(d, i) for d in rc.DIRS for i in range(FRAMES)]
    rs.pack_sheet(meshes, cells, pose, (w * rc.HD, h * rc.HD), FRAMES, prefix)
    rc.downsample_normal(f"{prefix}_normal.png")
    meta = {"cell": [w, h], "offset": [round(cx * rc.DENSITY, 2), round(-cy * rc.DENSITY, 2)], "frames": FRAMES}
    print(json.dumps({"water_ghost": meta}))


if __name__ == "__main__":
    main()
