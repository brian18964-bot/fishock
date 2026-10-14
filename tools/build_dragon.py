"""The big ghost's new body (user request): a dragon-headed wanderer, on the
characters' own skeleton so it moves - and can take hold of the traveller -
the way they do. Built from

  UAL1 / UAL2   Quaternius' Universal Animation Library mannequin (CC0, kept
                out of the repo): its skeleton and body, and the clips
  DRAGON_DIR    the user's red dragon (Red Dragon.fbx, from the release
                Asset1; kept out of the repo): its head, wings and tail

the shape after the user's reference (a demon base mesh - stood upright, a
long tail, wings), dressed after the old big ghost but plainer: a dark,
ragged robe from the chest to the shins. The head, the wings and the tail
are cut from the dragon, turned to face the way the mannequin does, scaled
to it and set on: the head on the neck (moving with the head bone), each
wing on a bone of its own at the shoulder blades (so they can be flexed),
the tail on a chain of five bones from the hips (so it can sway). The green
lantern goes in its hand in the game (RunView3D), as the old one's did.

  bpyenv/bin/python tools/build_dragon.py UAL1_GLB UAL2_GLB DRAGON_DIR OUT.glb

Clips (the game's names): Idle (Idle_Lantern_Loop), Walk (Zombie_Walk_Fwd_
Loop), Chase (Jog_Fwd_Loop), Grab (Zombie_Scratch), Eat (Consume).
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

UAL1, UAL2, DRAGON_DIR, OUT = sys.argv[-4:]
CLIPS = {"Idle": "Idle_Lantern_Loop", "Walk": "Zombie_Walk_Fwd_Loop", "Chase": "Jog_Fwd_Loop",
         "Grab": "Zombie_Scratch", "Eat": "Consume"}
# The dragon to the mannequin (the dragon's head ~0.17 long - 0.37 here, a
# big head as the reference has).
SCALE = 2.2
# The dragon's parts, in its own frame (z up, its head toward -x): what's
# the head, the wings, the tail.
HEAD_X = -0.335
WING_Y = 0.10
WING_Z = 0.24
TAIL_X = 0.06
# Its front feet (the clawed ones) for the mannequin's: x from .. to, under
# this high.
FOOT_X = (-0.30, -0.16)
FOOT_Z = 0.065
# The wings smaller than the rest of it (the body's a man's, not a
# dragon's), and how much bulkier than the mannequin the body is (m).
WING_SCALE = 0.72
BULK = 0.018
TAIL_BONES = 5
SCALES = (0.20, 0.045, 0.04)
CLOTH = (0.075, 0.068, 0.065)
CLOTH_HEM = (0.11, 0.095, 0.085)
TEXTURE = 1024


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH']


def select(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def colour(name, rgb, rough=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*rgb, 1.0)
    b.inputs['Roughness'].default_value = rough
    return m


# ---------------------------------------------------------------- the mannequin

def mannequin():
    """UAL1's armature and body; the clips wanted from both libraries."""
    fresh()
    bpy.ops.import_scene.gltf(filepath=UAL1)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = next(o for o in meshes() if o.name.startswith("Mannequin"))
    for o in meshes():
        if o is not body:
            bpy.data.objects.remove(o, do_unlink=True)
    have = {a.name.replace("_Armature", ""): a for a in bpy.data.actions}
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=UAL2)
    for o in set(bpy.data.objects) - before:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in bpy.data.actions:
        name = a.name.replace("_Armature", "")
        if name.endswith(".001"):
            name = name[:-4]
        have.setdefault(name, a)
    keep = {}
    for game, ual in CLIPS.items():
        if ual not in have:
            raise SystemExit("no clip " + ual)
        keep[game] = have[ual]
        have[ual].use_fake_user = True
    for a in list(bpy.data.actions):
        if a not in keep.values():
            bpy.data.actions.remove(a)
    return arm, body, keep


def bone_head(arm, name):
    return arm.matrix_world @ arm.data.bones[name].head_local


def strip_head(body, arm):
    """The mannequin's own head and feet off (the dragon's go on), the rest
    of it bulked out a little."""
    gi = body.vertex_groups["Head"].index
    feet = {body.vertex_groups[n].index for n in ("foot_l", "foot_r", "ball_l", "ball_r") if n in body.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(body.data)
    dl = bm.verts.layers.deform.active
    neck = bone_head(arm, "Head").z
    ankle = bone_head(arm, "foot_l").z
    gone = [v for v in bm.verts if (v[dl].get(gi, 0.0) > 0.5 and (body.matrix_world @ v.co).z > neck - 0.02)
            or (sum(v[dl].get(g, 0.0) for g in feet) > 0.5 and (body.matrix_world @ v.co).z < ankle + 0.03)]
    bmesh.ops.delete(bm, geom=gone, context='VERTS')
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * BULK
    bm.to_mesh(body.data)
    bm.free()


def dress(body, arm):
    """Its body scaled, the trunk clothed (a second material on the faces
    the trunk bones carry)."""
    scales = colour("Dragon_Scales", SCALES, 0.6)
    cloth = colour("Dragon_Cloth", CLOTH)
    body.data.materials.clear()
    body.data.materials.append(scales)
    body.data.materials.append(cloth)
    trunk = {body.vertex_groups[n].index for n in ("pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l",
             "clavicle_r", "thigh_l", "thigh_r") if n in body.vertex_groups}
    me = body.data
    weight = {}
    for v in me.vertices:
        weight[v.index] = sum(g.weight for g in v.groups if g.group in trunk)
    knee = bone_head(arm, "calf_l").z
    for p in me.polygons:
        w = sum(weight[i] for i in p.vertices) / len(p.vertices)
        z = sum((body.matrix_world @ me.vertices[i].co).z for i in p.vertices) / len(p.vertices)
        p.material_index = 1 if (w > 0.6 and z > knee + 0.05) else 0


def robe(body, arm):
    """A ragged robe from the waist to the shins, round the hips and legs
    (a tube, its hem cut ragged), weighted from the body nearest it."""
    me = body.data
    pts = np.array([(body.matrix_world @ v.co)[:] for v in me.vertices])
    top = bone_head(arm, "pelvis").z + 0.12
    bottom = bone_head(arm, "calf_l").z - 0.18
    cx, cy = float(np.mean(pts[:, 0])), float(np.mean(pts[:, 1]))
    rows, cols = 9, 28
    rng = np.random.default_rng(4)
    hem = 1.0 - rng.random(cols) ** 2 * 0.35
    bm = bmesh.new()
    grid = []
    for r in range(rows):
        t = r / (rows - 1)
        row = []
        for c in range(cols):
            a = c / cols * math.tau
            d = np.array([math.cos(a), math.sin(a)])
            z = top - (top - bottom) * t * (hem[c] if r == rows - 1 else 1.0)
            band = pts[np.abs(pts[:, 2] - z) < 0.08]
            reach = 0.18
            if len(band):
                rel = band[:, :2] - [cx, cy]
                along = rel @ d
                across = np.abs(rel @ [-d[1], d[0]])
                near = along[across < 0.09]
                if len(near):
                    reach = max(reach, float(near.max()))
            reach += 0.035 + 0.06 * t
            row.append(bm.verts.new((cx + d[0] * reach, cy + d[1] * reach, z)))
        grid.append(row)
    for r in range(rows - 1):
        for c in range(cols):
            bm.faces.new((grid[r][c], grid[r][(c + 1) % cols], grid[r + 1][(c + 1) % cols], grid[r + 1][c]))
    me2 = bpy.data.meshes.new("Robe")
    bm.to_mesh(me2)
    bm.free()
    o = bpy.data.objects.new("Robe", me2)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(colour("Dragon_Robe", CLOTH_HEM))
    sol = o.modifiers.new("Solid", 'SOLIDIFY')
    sol.thickness = 0.012
    select([o])
    bpy.ops.object.modifier_apply(modifier="Solid")
    # Its weights from the body nearest it.
    for g in body.vertex_groups:
        o.vertex_groups.new(name=g.name)
    dt = o.modifiers.new("Weights", 'DATA_TRANSFER')
    dt.object = body
    dt.use_vert_data = True
    dt.data_types_verts = {'VGROUP_WEIGHTS'}
    dt.vert_mapping = 'POLYINTERP_NEAREST'
    dt.layers_vgroup_select_src = 'ALL'
    dt.layers_vgroup_select_dst = 'NAME'
    select([o])
    bpy.ops.object.modifier_apply(modifier="Weights")
    return o


# ---------------------------------------------------------------- the dragon

def dragon_parts():
    """The red dragon cut into its head, its two wings and its tail - each
    its own object, still in the dragon's frame."""
    src = os.path.join(DRAGON_DIR, "untitled.fbx")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=src)
    new = [o for o in set(bpy.data.objects) - before]
    dr = next(o for o in new if o.type == 'MESH')
    for o in new:
        if o is not dr:
            bpy.data.objects.remove(o, do_unlink=True)
    select([dr])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    dr.parent = None
    # (its pictures, where they are here)
    for i, m in enumerate(dr.data.materials):
        img = bpy.data.images.load(os.path.join(DRAGON_DIR, "texture_%d.png" % i))
        img.scale(TEXTURE, TEXTURE)
        for n in m.node_tree.nodes:
            if n.type == 'TEX_IMAGE':
                n.image = img
    tests = {
        "head": lambda p: p.x < HEAD_X and p.z > 0.15,
        # (its left is its -y: it faces -x)
        "wing_l": lambda p: p.y < -WING_Y and p.z > WING_Z,
        "wing_r": lambda p: p.y > WING_Y and p.z > WING_Z,
        "foot_l": lambda p: FOOT_X[0] < p.x < FOOT_X[1] and p.z < FOOT_Z and p.y < 0,
        "foot_r": lambda p: FOOT_X[0] < p.x < FOOT_X[1] and p.z < FOOT_Z and p.y > 0,
        "tail": lambda p: p.x > TAIL_X and p.z < 0.2 and abs(p.y) < 0.1,
    }
    parts = {}
    for name, keep in tests.items():
        o = dr.copy()
        o.data = dr.data.copy()
        o.name = "Dragon_" + name
        bpy.context.scene.collection.objects.link(o)
        bm = bmesh.new()
        bm.from_mesh(o.data)
        inside = {v for v in bm.verts if keep(v.co)}
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if not all(v in inside for v in f.verts)], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        bm.to_mesh(o.data)
        bm.free()
        parts[name] = o
    bpy.data.objects.remove(dr, do_unlink=True)
    return parts


def anchor(o, keep):
    pts = [v.co.copy() for v in o.data.vertices if keep(v.co)]
    if not pts:
        pts = [v.co.copy() for v in o.data.vertices]
    return sum(pts, Vector()) / len(pts)


def place(o, at, to, turn=0.0, tilt=0.0, size=1.0):
    """Part `o` turned to face as the mannequin does (its -x to -y), scaled,
    its point `at` (its own frame) put on `to`; turned `turn` about z and
    tipped `tilt` about x first."""
    m = (Matrix.Translation(to) @ Matrix.Rotation(turn, 4, 'Z') @ Matrix.Rotation(tilt, 4, 'X')
         @ Matrix.Rotation(math.pi / 2, 4, 'Z') @ Matrix.Scale(SCALE * size, 4) @ Matrix.Translation(-at))
    o.data.transform(m)
    o.data.update()


def add_bones(arm, specs):
    """Bones added to the armature: name -> (head, tail, parent)."""
    select([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    inv = arm.matrix_world.inverted()
    for name, (h, t, parent) in specs.items():
        b = eb.new(name)
        b.head = inv @ h
        b.tail = inv @ t
        b.parent = eb[parent]
    bpy.ops.object.mode_set(mode='OBJECT')


def rigid(o, bone):
    o.vertex_groups.clear()
    g = o.vertex_groups.new(name=bone)
    g.add([v.index for v in o.data.vertices], 1.0, 'REPLACE')


def tail_rig(arm, tail):
    """The tail's chain: TAIL_BONES bones along its middle, from its root
    at the hips; each vertex shared between the two bones nearest it."""
    pts = np.array([v.co[:] for v in tail.data.vertices])
    ys = pts[:, 1]
    y0, y1 = float(ys.min()), float(ys.max())
    joints = []
    for k in range(TAIL_BONES + 1):
        y = y0 + (y1 - y0) * k / TAIL_BONES
        near = pts[np.abs(ys - y) < (y1 - y0) / TAIL_BONES * 0.6]
        joints.append(Vector(near.mean(0)) if len(near) else Vector((0, y, pts[:, 2].mean())))
    specs = {}
    for k in range(TAIL_BONES):
        specs["tail_%02d" % (k + 1)] = (joints[k], joints[k + 1], "pelvis" if k == 0 else "tail_%02d" % k)
    add_bones(arm, specs)
    tail.vertex_groups.clear()
    groups = [tail.vertex_groups.new(name="tail_%02d" % (k + 1)) for k in range(TAIL_BONES)]
    seg = (y1 - y0) / TAIL_BONES
    for v in tail.data.vertices:
        f = (v.co.y - y0) / seg - 0.5
        k = int(math.floor(f))
        w = f - k
        for kk, ww in ((k, 1.0 - w), (k + 1, w)):
            kk = min(max(kk, 0), TAIL_BONES - 1)
            groups[kk].add([v.index], ww, 'ADD')


def decimate(o, faces):
    if len(o.data.polygons) <= faces:
        return
    d = o.modifiers.new("Less", 'DECIMATE')
    d.ratio = faces / len(o.data.polygons)
    select([o])
    bpy.ops.object.modifier_apply(modifier="Less")


def main():
    arm, body, clips = mannequin()
    # (in its rest pose, the clips off it)
    if arm.animation_data:
        arm.animation_data.action = None
    strip_head(body, arm)
    dress(body, arm)
    gown = robe(body, arm)
    parts = dragon_parts()
    head_at = bone_head(arm, "Head")
    chest = bone_head(arm, "spine_03")
    hips = bone_head(arm, "pelvis")
    # The head on the neck, its cut end where the mannequin's head was.
    h = parts["head"]
    place(h, anchor(h, lambda p: p.x > HEAD_X - 0.02), head_at + Vector((0, -0.03, 0.02)), size=1.2)
    decimate(h, 4500)
    rigid(h, "Head")
    # The wings from the shoulder blades, swept up and back.
    wing_bones = {}
    for side, sign in (("wing_l", 1), ("wing_r", -1)):
        w = parts[side]
        root = anchor(w, lambda p: abs(p.y) < WING_Y + 0.03)
        to = chest + Vector((sign * 0.1, 0.14, 0.02))
        place(w, root, to, turn=sign * -0.35, tilt=0.25, size=WING_SCALE)
        decimate(w, 1600)
        rigid(w, side)
        wing_bones[side] = (to, to + Vector((sign * 0.3, 0.12, 0.2)), "spine_03")
    # The clawed feet for the mannequin's.
    for side in ("foot_l", "foot_r"):
        f = parts[side]
        top = anchor(f, lambda p: p.z > FOOT_Z - 0.02)
        place(f, top, bone_head(arm, side) + Vector((0, -0.02, 0.0)))
        decimate(f, 900)
        rigid(f, side)
    add_bones(arm, wing_bones)
    # The tail from the small of the back, trailing.
    t = parts["tail"]
    place(t, anchor(t, lambda p: p.x < TAIL_X + 0.03), hips + Vector((0, 0.12, -0.04)), tilt=0.15)
    decimate(t, 1500)
    tail_rig(arm, t)
    # All of it on the skeleton, one skinned body.
    every = [body, gown, h, parts["wing_l"], parts["wing_r"], t, parts["foot_l"], parts["foot_r"]]
    for o in every:
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        o.parent = arm
        o.matrix_parent_inverse = arm.matrix_world.inverted()
        mod = o.modifiers.new("Armature", 'ARMATURE')
        mod.object = arm
    # The clips, each on its own track.
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for game, a in clips.items():
        a.name = game
        tr = ad.nla_tracks.new()
        tr.name = game
        st = tr.strips.new(game, int(a.frame_range[0]), a)
        st.name = game
        tr.mute = True
    select([arm] + every, active=arm)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
                              export_anim_single_armature=True, export_def_bones=False,
                              export_image_format='JPEG', export_jpeg_quality=80)
    tris = sum(len(o.data.polygons) for o in every)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB,", tris, "faces")


if __name__ == "__main__":
    main()
