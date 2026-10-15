"""The big ghost's body, second make (user request): the dragon-headed
wanderer the user had generated in Meshy ("Crimson Wyrm Warden" - a
sculpted, textured mesh: kept out of the repo, like the other source
models) - rigged here for the game. Built from

  MESHY_FBX     Meshy's textured export (one mesh, ~250 000 triangles, a
                2048 colour, normal and roughness picture), its feet toward
                -z, facing -y, about 1.8 tall
  UAL1 / UAL2   Quaternius' Universal Animation Library (CC0, kept out of
                the repo): the clips

The mesh is brought down to TRIS triangles, the high one's surface baked
into a normal picture for it (so the scales, the muscles and the cloth's
folds stay), and stood on the ground. A skeleton is fitted to it: the
characters' own bone names (pelvis, spine_01.., upperarm_l..) at the joints
measured off this mesh (JOINTS - it stands in an A pose, its legs a
dragon's, the knee forward, the hock back), and its own: each wing on five
bones (the arm in two, three fingers spreading the membrane), the tail on
seven. Its weights are Blender's (bone heat), the wings and the tail kept
to their own bones. The clips - the same five the first make had - are
carried onto it as tools/retarget.py carries the ghosts': the trunk and
the legs turned as the source's turn, from their own rest; the arms
pointed the way the source's point (UAL's rest is a T pose).

  bpyenv/bin/python tools/build_dragon_meshy.py MESHY_FBX UAL1 UAL2 OUT.glb

The game folds and beats the wings and lifts the tail itself
(scripts/dragon_rig.gd).
"""
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import retarget  # noqa: E402

MESHY, UAL1, UAL2, OUT = sys.argv[-4:]
TRIS = 30000
NORMAL_SIZE = 2048
# The pictures shipped (px): the colour a little under Meshy's 2048 (its
# own JPEG, passed through, was 3.5 MB), the normal (baked at NORMAL_SIZE)
# and the roughness smaller - the web build's size.
SHIP_COLOUR = 1536
SHIP_DETAIL = 1024
# (user request: the lantern down at its side, the arms easy, as it goes
# about - held up, Idle_Lamp, only when someone's near; an upright walk)
CLIPS = {"Idle": "Idle_Loop", "Idle_Lamp": "Idle_Lantern_Loop", "Walk": "Walk_Loop", "Chase": "Jog_Fwd_Loop",
         "Grab": "Zombie_Scratch", "Eat": "Consume"}
LOOPING = ("Idle", "Idle_Lamp", "Walk", "Chase")
# How much of a clip's trunk motion is kept (the rest at 1): the scratch
# turns the whole body side-on - with the wings out it reads as flailing -
# a man's walk and jog on a dragon's legs (the knee already forward) kick
# them out level.
TRUNK_BONES = ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head")
DAMP = {"Grab": {"pelvis": 0.4, "spine_01": 0.4, "spine_02": 0.4, "spine_03": 0.5},
        "Walk": {"thigh_l": 0.75, "thigh_r": 0.75, "calf_l": 0.75, "calf_r": 0.75,
                 "foot_l": 0.75, "foot_r": 0.75, "ball_l": 0.75, "ball_r": 0.75},
        "Chase": {"pelvis": 0.7, "thigh_l": 0.6, "thigh_r": 0.6, "calf_l": 0.6, "calf_r": 0.6,
                  "foot_l": 0.6, "foot_r": 0.6, "ball_l": 0.6, "ball_r": 0.6}}
SAMPLES = 24
# The joints, in Meshy's own frame (the mesh's middle at the origin, feet
# at z -0.896, facing -y; its right side is -x): measured off slices of
# the mesh. (name, head, tail, parent)
LIFT = 0.896


def _p(x, y, z):
    return Vector((x, y, z + LIFT))


def _sides(name, head, tail, parent):
    """Both sides of a limb: `name` and `parent` with {s} for the side
    (the left's x as given, the right's mirrored)."""
    out = []
    for s, k in (("l", 1.0), ("r", -1.0)):
        out.append((name.format(s=s), Vector((head.x * k, head.y, head.z)), Vector((tail.x * k, tail.y, tail.z)),
                    parent.format(s=s)))
    return out


TRUNK = [
    ("root", _p(0, 0, -0.896), _p(0, 0.1, -0.896), None),
    ("pelvis", _p(0, -0.19, 0.0), _p(0, -0.19, 0.12), "root"),
    ("spine_01", _p(0, -0.19, 0.12), _p(0, -0.19, 0.24), "pelvis"),
    ("spine_02", _p(0, -0.19, 0.24), _p(0, -0.2, 0.34), "spine_01"),
    ("spine_03", _p(0, -0.2, 0.34), _p(0, -0.18, 0.47), "spine_02"),
    ("neck_01", _p(0, -0.18, 0.47), _p(0, -0.17, 0.57), "spine_03"),
    ("Head", _p(0, -0.17, 0.57), _p(0, -0.2, 0.78), "neck_01"),
]
LIMBS = []
for _spec in (
        ("clavicle_{s}", _p(0.04, -0.17, 0.43), _p(0.24, -0.2, 0.41), "spine_03"),
        ("upperarm_{s}", _p(0.24, -0.2, 0.41), _p(0.37, -0.15, 0.14), "clavicle_{s}"),
        ("lowerarm_{s}", _p(0.37, -0.15, 0.14), _p(0.5, -0.28, -0.07), "upperarm_{s}"),
        ("hand_{s}", _p(0.5, -0.28, -0.07), _p(0.53, -0.32, -0.2), "lowerarm_{s}"),
        ("thigh_{s}", _p(0.11, -0.2, -0.02), _p(0.19, -0.27, -0.33), "pelvis"),
        ("calf_{s}", _p(0.19, -0.27, -0.33), _p(0.235, -0.07, -0.63), "thigh_{s}"),
        ("foot_{s}", _p(0.235, -0.07, -0.63), _p(0.28, -0.3, -0.86), "calf_{s}"),
        ("ball_{s}", _p(0.28, -0.3, -0.86), _p(0.29, -0.43, -0.88), "foot_{s}"),
        # (the wing: the arm up to the hooked wrist, in two; three fingers
        # from the wrist out to the membrane's points)
        ("wing_{s}", _p(0.12, -0.04, 0.45), _p(0.22, -0.06, 0.68), "spine_03"),
        ("wing_{s}_02", _p(0.22, -0.06, 0.68), _p(0.31, -0.07, 0.86), "wing_{s}"),
        ("wing_{s}_f1", _p(0.31, -0.07, 0.86), _p(0.95, -0.2, 0.3), "wing_{s}_02"),
        ("wing_{s}_f2", _p(0.31, -0.07, 0.86), _p(0.86, -0.16, 0.02), "wing_{s}_02"),
        ("wing_{s}_f3", _p(0.31, -0.07, 0.86), _p(0.55, -0.11, 0.0), "wing_{s}_02")):
    LIMBS += _sides(*_spec)
TAIL_POINTS = [_p(0, -0.02, 0.05), _p(-0.13, 0.17, 0.0), _p(-0.3, 0.22, -0.15), _p(-0.39, 0.17, -0.31),
               _p(-0.47, 0.09, -0.45), _p(-0.6, 0.0, -0.55), _p(-0.78, -0.09, -0.65), _p(-0.96, -0.17, -0.79)]
# The tail as it hangs (user request: off the ground, clear of the legs -
# Meshy's swept forward round the left leg): each bone's angle down from
# level (deg), straight back, the tip just lifting.
TAIL_DROP = (50, 45, 35, 25, 15, 5, -5)
# How far from the tail's bones its skin reaches (m, Meshy's scale).
TAIL_REACH = 0.11
ARM_AIM = ("upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r")


def select(objs, active=None):
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active or objs[0]


# ---------------------------------------------------------------- the mesh

def mesh():
    """Meshy's mesh brought down to TRIS, the high one's surface baked into
    a normal picture, stood on the ground: the low one."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=MESHY)
    hi = next(o for o in set(bpy.data.objects) - before if o.type == 'MESH')
    hi.name = "High"
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = "DragonGhost"
    bpy.context.scene.collection.objects.link(lo)
    tris = sum(len(p.vertices) - 2 for p in hi.data.polygons)
    m = lo.modifiers.new("Less", 'DECIMATE')
    m.ratio = TRIS / tris
    m.use_collapse_triangulate = True
    select([lo])
    bpy.ops.object.modifier_apply(modifier="Less")
    # Its own material, the baked normal in it.
    mat = lo.data.materials[0].copy()
    mat.name = "DragonGhost_Skin"
    lo.data.materials[0] = mat
    img = bpy.data.images.new("DragonGhost_Normal", NORMAL_SIZE, NORMAL_SIZE)
    img.colorspace_settings.name = 'Non-Color'
    nt = mat.node_tree
    node = nt.nodes.new('ShaderNodeTexImage')
    node.image = img
    for n in nt.nodes:
        n.select = False
    node.select = True
    nt.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.015
    bk.max_ray_distance = 0.04
    bk.margin = 8
    select([hi, lo], active=lo)
    t = time.time()
    bpy.ops.object.bake(type='NORMAL')
    print("baked the normal picture in %.0f s" % (time.time() - t))
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    nm = next((n for n in nt.nodes if n.type == 'NORMAL_MAP'), None)
    if nm is None:
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(nm.outputs[0], bsdf.inputs['Normal'])
    for link in list(nm.inputs['Color'].links):
        nt.links.remove(link)
    nt.links.new(node.outputs['Color'], nm.inputs['Color'])
    # (no metal in it: Meshy's metallic picture is all but black)
    for link in list(bsdf.inputs['Metallic'].links):
        nt.links.remove(link)
    bsdf.inputs['Metallic'].default_value = 0.0
    bpy.data.objects.remove(hi, do_unlink=True)
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None and n.image is not img and n.image.size[0] > 0:
            ship = SHIP_DETAIL if "roughness" in n.image.name else SHIP_COLOUR
            n.image.scale(ship, ship)
            n.image.name = "DragonGhost_Roughness" if "roughness" in n.image.name else "DragonGhost_Colour"
    img.scale(SHIP_DETAIL, SHIP_DETAIL)
    for n in list(nt.nodes):
        if n.type == 'TEX_IMAGE' and n.image is not None and "metallic" in n.image.name:
            nt.nodes.remove(n)
    # Stood on the ground.
    lo.location.z += LIFT
    select([lo])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print("mesh: %d triangles" % sum(len(p.vertices) - 2 for p in lo.data.polygons))
    return lo


# ---------------------------------------------------------------- the skeleton

def skeleton():
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    select([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = data.edit_bones
    specs = TRUNK + LIMBS
    pts = TAIL_POINTS
    for i in range(len(pts) - 1):
        specs.append(("tail_%02d" % (i + 1), pts[i], pts[i + 1], "pelvis" if i == 0 else "tail_%02d" % i))
    for name, h, t, parent in specs:
        b = eb.new(name)
        b.head, b.tail = h, t
        # (rolled so each bone's x points the same way across the body)
        b.align_roll(Vector((0.0, -1.0, 0.0)) if abs((t - h).normalized().y) < 0.9 else Vector((0.0, 0.0, 1.0)))
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    print("skeleton: %d bones" % len(data.bones))
    return arm


def bind(body, arm):
    """Bone heat; the wings and the tail kept to their own bones, the body
    off them."""
    select([body, arm], active=arm)
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    empty = sum(1 for v in body.data.vertices if not v.groups)
    print("bound: %d vertices with no bone" % empty)
    tail_only(body, arm)
    hang_tail(body, arm)
    # At most four bones, adding up to one.
    select([body])
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)


def tail_only(body, arm):
    """The tail's skin on the tail's bones alone (user report: two tails -
    Meshy's swept round the left leg, so bone heat gave some of it to the
    leg, and that part stayed by the leg when the tail was laid back): what
    lies nearer the tail's line than any other bone, within TAIL_REACH of
    it, keeps only its tail (and, at the root, pelvis) weights."""
    segs = []
    for b in arm.data.bones:
        segs.append((b.name, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local))

    def seg_dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (a + ab * t - p).length, t

    groups = {g.name: g for g in body.vertex_groups}
    index = {g.index: g.name for g in body.vertex_groups}
    moved = 0
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        best_tail, tail_bone, other = 9.0, None, 9.0
        for name, a, b in segs:
            d, _t = seg_dist(p, a, b)
            if name.startswith("tail"):
                if d < best_tail:
                    best_tail, tail_bone = d, name
            elif not name.startswith(("wing", "root")):
                other = min(other, d)
        if tail_bone is None or best_tail > TAIL_REACH or best_tail >= other:
            continue
        keep = {}
        for g in v.groups:
            name = index[g.group]
            if name.startswith("tail") or (name == "pelvis" and tail_bone == "tail_01"):
                keep[name] = g.weight
        if not keep:
            keep = {tail_bone: 1.0}
        for g in list(v.groups):
            if index[g.group] not in keep:
                groups[index[g.group]].remove([v.index])
        for name, w in keep.items():
            groups[name].add([v.index], w, 'REPLACE')
        moved += 1
    print("tail skin kept to the tail: %d vertices" % moved)


def hang_tail(body, arm):
    """The tail laid back (TAIL_DROP) and made the rest pose - the mesh
    moved with it."""
    select([arm])
    bpy.ops.object.mode_set(mode='POSE')
    for i, drop in enumerate(TAIL_DROP):
        pb = arm.pose.bones["tail_%02d" % (i + 1)]
        bpy.context.view_layer.update()
        now = (arm.matrix_world @ pb.matrix).to_3x3() @ Vector((0.0, 1.0, 0.0))
        a = math.radians(drop)
        want = Vector((0.0, math.cos(a), -math.sin(a)))
        turn = now.normalized().rotation_difference(want)
        world = arm.matrix_world.to_3x3()
        m = pb.matrix.copy()
        r = (world.inverted() @ turn.to_matrix() @ world).to_4x4()
        head = m.translation.copy()
        m.translation = Vector()
        m = r @ m
        m.translation = head
        pb.matrix = m
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode='OBJECT')
    mod = next(m for m in body.modifiers if m.type == 'ARMATURE')
    select([body])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    select([arm])
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    mod = body.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    tip = arm.matrix_world @ arm.data.bones["tail_07"].tail_local
    print("tail laid back: tip at y %.2f, %.2f above the ground" % (tip.y, tip.z))


# ---------------------------------------------------------------- the clips

def libraries():
    srcs = []
    for path in (UAL1, UAL2):
        src = retarget.load_library(path)
        srcs.append(src)
    return srcs


def carry(arm, srcs):
    """CLIPS carried onto `arm`: {game name: action}."""
    out = {}
    mapping = {b.name: b.name for b in arm.data.bones
               if not b.name.startswith(("wing", "tail")) and b.name != "root"}
    for game, ual in CLIPS.items():
        # (UAL1 and UAL2 share the mannequin's skeleton: either one plays
        # any of their clips)
        src = srcs[0]
        bones = [b for b in mapping if b in src.data.bones]
        loop = game in LOOPING
        clip = retarget.Clip(src, ual, bones, SAMPLES if loop else SAMPLES + 1, loop=loop, ref="rest")
        # The hips' bob and sway scaled from the source's height to this one's.
        src_hips = (src.matrix_world @ src.data.bones["pelvis"].head_local).z
        k = arm.data.bones["pelvis"].head_local.z / max(src_hips, 1e-6)
        ad = arm.animation_data or arm.animation_data_create()
        ad.action = None
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis.identity()
        poses = []
        n = len(clip.times)
        for i in range(n):
            aim = {b: d for b, d in clip.dirs(i).items() if b in ARM_AIM}
            off = clip.offset(i) * k
            strength = {b: DAMP.get(game, {}).get(b, 1.0) for b in bones}
            retarget.apply(arm, clip.delta(i), {b: b for b in bones}, strength, aim=aim, offset=off)
            poses.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones})
        act = bpy.data.actions.new(game)
        act.use_fake_user = True
        ad.action = act
        span = (clip.times[-1] - clip.times[0]) * (n / max(n - 1, 1) if loop else 1.0)
        step = span / n if loop else span / max(n - 1, 1)
        frames = [1 + i * step for i in range(n)] + ([1 + n * step] if loop else [])
        if loop:
            poses.append(poses[0])
        for f, pose in zip(frames, poses):
            for pb in arm.pose.bones:
                pb.location, pb.rotation_quaternion = pose[pb.name]
                pb.keyframe_insert("location", frame=f)
                pb.keyframe_insert("rotation_quaternion", frame=f)
        ad.action = None
        out[game] = act
        print("clip %s from %s: %d keys over %.0f frames" % (game, ual, len(frames), frames[-1] - 1))
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    srcs = libraries()
    for s in srcs:
        for o in s.children:
            o.hide_render = True
    body = mesh()
    arm = skeleton()
    bind(body, arm)
    clips = carry(arm, srcs)
    for s in srcs:
        for o in [s] + list(s.children):
            bpy.data.objects.remove(o, do_unlink=True)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for game, a in clips.items():
        tr = ad.nla_tracks.new()
        tr.name = game
        st = tr.strips.new(game, int(a.frame_range[0]), a)
        st.name = game
        tr.mute = True
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    select([arm, body], active=arm)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
                              export_anim_single_armature=True, export_def_bones=False,
                              export_image_format='JPEG', export_jpeg_quality=85)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
