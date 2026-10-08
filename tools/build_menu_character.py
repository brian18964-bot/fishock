"""The camp's character, assets/models/characters/<PLAYER>.glb (user
request: the animals in the game - the four, then the deer and the sheep -
the camp's fire changing who's travelling - CharacterArt): Quaternius'
Universal Animation Library mannequin (CC0 - the libraries kept out of
the repo, like the other source models) with the clips the menus play.
UAL1 and UAL2 share the mannequin's skeleton, so their clips go onto it
as they are: breathing and waving (the equipment page, a tap), and the
camp's life (user request, Camp v2: the character rests at the camp on
its own - walks about, sits by the fire, mends things... - less and less
of it as the spirit runs low; see CampLife). Carrying, chopping and
harvesting are left out (user request: the hands didn't close on what
they held), and dancing (user request).

User request: the user's Mixamo clips (MOVES_DIR - Y Bot, 30 fps, kept out
of the repo) for more of the camp's life - lying down to sleep, sitting on
the ground, tea on the log, stretching, looking about, waving to the
merchant, cheering, low - carried onto the mannequin's skeleton by
tools/kaykit.py (the hips kept over the feet, the feet on the ground), by
the names in MIXAMO ("_Loop" ones loop, as UAL's do).

The one wearing them is the player's character (owl_character.player, put
on the mannequin's skeleton: the beginner owl person, or PLAYER=<animal>
GREYBOX_DIR=<build> a greybox one); MANNEQUIN=1 keeps the mannequin instead.

  UAL1=<UAL1_Standard.glb> UAL2=<UAL2_Standard.glb> MOVES_DIR=<dir> \\
      bpyenv/bin/python tools/build_menu_character.py      (repo root)
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import owl_character  # noqa: E402
import kaykit  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# (OUT=<path>: elsewhere - a try-out of another character)
OUT = os.environ.get("OUT") or os.path.join(ROOT, "assets", "models", "characters",
                                           os.environ.get("PLAYER", "owl") + ".glb")

# The clips kept, by library.
UAL1 = [
    "Idle_Loop", "Idle_Talking_Loop", "Interact", "Walk_Loop",
    "Sitting_Enter", "Sitting_Idle_Loop", "Sitting_Exit", "Sitting_Talking_Loop",
    "Crouch_Idle_Loop", "Idle_Torch_Loop", "Fixing_Kneeling", "PickUp_Table",
]
UAL2 = [
    "Idle_FoldArms_Loop", "Idle_Rail_Loop", "Chest_Open", "Consume", "Yes", "Idle_No_Loop", "LayToIdle",
]

# The Mixamo clips: the name it's played by, the file, the source frames
# (None: all), and whether it's a standing one (the stance's stride check).
MIXAMO = [
    ("Lie_Down", "Lying.Down.fbx", None, False),
    ("Lying_Loop", "Laying.fbx", None, False),
    ("Sleep_B_Loop", "Male.Laying.Pose.1.fbx", None, False),
    ("Ground_Sit_Loop", "Sitting.Idle.fbx", (1, 160), False),
    ("Ground_Stand", "Standing.Up.fbx", (1, 70), False),
    ("Seat_Rest_Loop", "Sitting.fbx", None, False),
    ("Seat_Clap_Loop", "Clapping.1.fbx", None, False),
    ("Seat_Drink", "Sitting.Drinking.fbx", (130, 400), False),
    ("Drink", "Drinking.fbx", (62, 172), True),
    ("Stretch_Neck", "Neck.Stretching.fbx", None, True),
    ("Stretch_Arms", "Front.Raises.fbx", None, True),
    ("Look_Around", "Look.Around.fbx", None, True),
    ("Peek", "Crouch.Look.Around.Corner.fbx", None, False),
    ("Wave_Big", "Waving.fbx", None, True),
    ("Wave", "Waving.1.fbx", None, True),
    ("Beckon", "Beckoning.fbx", None, True),
    ("Clap_Loop", "Clapping.fbx", None, True),
    ("Fist_Pump", "Fist.Pump.fbx", (1, 75), True),
    ("Victory", "Victory.fbx", None, True),
    ("Disappointed", "Disappointed.fbx", None, True),
    ("Sad_Loop", "Sad.Idle.fbx", None, True),
    ("Sad_B_Loop", "Sad.Idle.1.fbx", None, True),
]
# Every second source frame kept (the keys spread back out, so it plays at
# the same pace): the model's size.
MIXAMO_STEP = 2
# Lying and sat on the ground, it's the body's lowest point that goes on
# the ground, not a foot (a knee up, the feet off it) - ground_on_body().
GROUNDED = ("Lie_Down", "Lying_Loop", "Sleep_B_Loop", "Ground_Sit_Loop", "Ground_Stand",
            # (user report, checked on the camp: crouching, kneeling and the
            # beckon's crouch put the feet or a knee in the ground)
            "Beckon", "Peek", "Crouch_Idle_Loop", "Fixing_Kneeling",
            # (and lying to getting up, the standing about and the walk -
            # the bear's walk 7 cm in, the rest's toes 2-3 cm)
            "LayToIdle", "Walk_Loop", "Idle_Loop", "Idle_FoldArms_Loop", "Idle_No_Loop",
            "Idle_Talking_Loop", "Idle_Torch_Loop", "Sad_Loop")
# User report (the bear sank into the log): the camp's logs (CampStage.SEATS)
# have their top this high under the hips of one sat on them, m (measured
# in the camp) - and the clips sat on one, whole and getting on and off.
# sit_on_logs() puts each character's seat on it, its feet on the ground.
SEAT_TOP = 0.442
SEAT_REACH = 0.12
SAT = ("Sitting_Idle_Loop", "Sitting_Talking_Loop")
SITTING_DOWN = ("Sitting_Enter", "Sitting_Exit")
# Sat on a log: Mixamo's seats are lower than the camp's logs (into the
# wood by up to 14 cm), so the hips and legs are UAL's Sitting_Idle's (made
# for the logs) and the body above them keeps the Mixamo clip's turn -
# seat_on_log().
ON_LOG = ("Seat_Rest_Loop", "Seat_Clap_Loop", "Seat_Drink")
LOG_CLIP = "Sitting_Idle_Loop"
LEGS = ("root", "pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r")


def mixamo_clips(arm):
    """MIXAMO carried onto `arm` (the mannequin): {name: action}; none
    without MOVES_DIR."""
    folder = os.environ.get("MOVES_DIR", "")
    out = {}
    if folder == "":
        return out
    for name, fbx, span, _standing in MIXAMO:
        lib = kaykit.load_mixamo(os.path.join(folder, fbx), "mx_" + name)
        act = bpy.data.actions["mx_" + name]
        s, e = span or act.frame_range
        step = MIXAMO_STEP if e - s >= 8 else 1
        baked = kaykit.bake(arm, lib, "mx_" + name, name=name, lift=0.0, rig="mixamo", span=(s, e), step=step)
        if step > 1:
            for fc in baked.fcurves:
                for kp in fc.keyframe_points:
                    kp.co.x = 1.0 + (kp.co.x - 1.0) * step
                    kp.handle_left.x = 1.0 + (kp.handle_left.x - 1.0) * step
                    kp.handle_right.x = 1.0 + (kp.handle_right.x - 1.0) * step
        for o in [lib] + list(lib.children):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.actions.remove(act)
        out[name] = baked
    return out


def _not_tail(body):
    """{mesh name: indices of its vertices that aren't the tail's}."""
    keep = {}
    for o in body:
        if o.type != "MESH":
            continue
        tails = {g.index for g in o.vertex_groups if g.name.startswith("tail")}
        keep[o.name] = {v.index for v in o.data.vertices
                        if sum(g.weight for g in v.groups if g.group in tails) <= 0.3}
    return keep


def _lows(body, keep, around):
    """As posed now (world): the lowest point of the body within SEAT_REACH
    (across) of `around` - the seat - and the lowest point of a foot."""
    dg = bpy.context.evaluated_depsgraph_get()
    seat = foot = 9.0
    for o in body:
        if o.type != "MESH":
            continue
        feet = {g.index for g in o.vertex_groups if g.name.startswith(("foot", "ball"))}
        mesh = o.evaluated_get(dg).to_mesh()
        for v in o.data.vertices:
            if v.index not in keep[o.name]:
                continue
            p = o.matrix_world @ mesh.vertices[v.index].co
            if (p.x - around.x) ** 2 + (p.y - around.y) ** 2 < SEAT_REACH ** 2:
                seat = min(seat, p.z)
            if any(g.group in feet and g.weight > 0.5 for g in v.groups):
                foot = min(foot, p.z)
        o.evaluated_get(dg).to_mesh_clear()
    return seat, foot


def _leg_ik(arm, side, target, knee_was, foot_was):
    """The leg bent (two bones, the knee the way it was) to put the ankle
    at `target` (world) - as near as it reaches - the foot turned as
    `foot_was` (its world matrix) was."""
    mw = arm.matrix_world
    inv = mw.inverted()
    bones = arm.pose.bones
    thigh, calf, foot = bones["thigh_" + side], bones["calf_" + side], bones["foot_" + side]
    hip = mw @ thigh.head
    knee_now = mw @ calf.head
    a = (knee_now - hip).length
    b = ((mw @ foot.head) - knee_now).length
    d = target - hip
    reach = min(max(d.length, abs(a - b) + 1e-4), a + b - 1e-4)
    way = d.normalized()
    pole = knee_was - hip
    pole = pole - way * pole.dot(way)
    pole = pole.normalized() if pole.length > 1e-5 else (knee_now - hip - way * (knee_now - hip).dot(way)).normalized()
    cos_a = max(-1.0, min(1.0, (a * a + reach * reach - b * b) / (2 * a * reach)))
    knee = hip + way * (a * cos_a) + pole * (a * math.sqrt(max(0.0, 1.0 - cos_a * cos_a)))

    def turn(pb, about, frm, to):
        q = frm.rotation_difference(to)
        world = Matrix.Translation(about) @ q.to_matrix().to_4x4() @ Matrix.Translation(-about) @ (mw @ pb.matrix)
        pb.matrix = inv @ world
        bpy.context.view_layer.update()

    turn(thigh, hip, (mw @ calf.head) - hip, knee - hip)
    knee_now = mw @ calf.head
    turn(calf, knee_now, (mw @ foot.head) - knee_now, hip + way * reach - knee_now)
    at = (mw @ foot.matrix).translation
    world = foot_was.copy()
    world.translation = at
    foot.matrix = inv @ world
    bpy.context.view_layer.update()


def sit_on_logs(arm, body, acts):
    """SAT and SITTING_DOWN keyed again for this character: the hips raised
    so the seat is on the log's top (SEAT_TOP) - as far as it's sat down,
    the getting on and off - and each leg bent to keep its foot where it
    was, on the ground (the short-legged's left hanging)."""
    ad = arm.animation_data or arm.animation_data_create()
    bones = arm.pose.bones
    hips = bones["pelvis"]
    mw = arm.matrix_world
    scene = bpy.context.scene
    keep = _not_tail(body)

    def first(act):
        ad.action = act
        scene.frame_set(int(act.frame_range[0]))
        return mw @ hips.head

    stand = first(acts["Idle_Loop"]).z
    sat_at = first(acts["Sitting_Idle_Loop"])
    seat, foot = _lows(body, keep, sat_at)
    lift = SEAT_TOP - seat
    # (the soles brought up to the ground, sat, if the clip had them in it)
    sole = max(0.0, -foot)
    print("seat: lift %.3f, soles %.3f" % (lift, sole))
    for name in SAT + SITTING_DOWN:
        if name not in acts:
            continue
        act = acts[name]
        ad.action = act
        for pb in [hips] + [bones[b + s] for b in ("thigh_", "calf_", "foot_") for s in "lr"]:
            pb.rotation_mode = "QUATERNION"
        frames = sorted({int(round(kp.co.x)) for fc in act.fcurves for kp in fc.keyframe_points})
        for f in frames:
            scene.frame_set(f)
            down = max(0.0, min(1.0, (stand - (mw @ hips.head).z) / max(stand - sat_at.z, 1e-4)))
            feet = {s: (mw @ bones["foot_" + s].matrix).copy() for s in "lr"}
            knees = {s: mw @ bones["calf_" + s].head for s in "lr"}
            world = mw @ hips.matrix
            world.translation.z += lift * down
            hips.location = arm.convert_space(pose_bone=hips, matrix=world, from_space="WORLD", to_space="LOCAL").translation
            bpy.context.view_layer.update()
            for s in "lr":
                target = feet[s].translation + Vector((0.0, 0.0, sole * down))
                _leg_ik(arm, s, target, knees[s], feet[s])
            hips.keyframe_insert("location", frame=f)
            for s in "lr":
                for b in ("thigh_", "calf_", "foot_"):
                    bones[b + s].keyframe_insert("rotation_quaternion", frame=f)
    ad.action = None


def ground_on_body(arm, body, act):
    """`act` keyed again with the hips raised or lowered, frame by frame,
    so the body's lowest point (the character bound, its meshes as posed)
    just touches the ground - never lower than a foot would put it."""
    ad = arm.animation_data
    ad.action = act
    hips = arm.pose.bones["pelvis"]
    scene = bpy.context.scene
    s0, s1 = (int(round(f)) for f in act.frame_range)
    frames = sorted({int(round(kp.co.x)) for fc in act.fcurves for kp in fc.keyframe_points})
    # (not the tail: hanging down it'd hold the feet up off the ground)
    meshes = [o for o in body if o.type == "MESH"]
    skip = {}
    for o in meshes:
        tails = {g.index for g in o.vertex_groups if g.name.startswith("tail")}
        skip[o.name] = {v.index for v in o.data.vertices
                        if sum(g.weight for g in v.groups if g.group in tails) > 0.3}
    lifts = {}
    for f in frames:
        scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        low = 0.0
        for o in meshes:
            mesh = o.evaluated_get(dg).to_mesh()
            out = skip[o.name]
            zs = [(o.matrix_world @ v.co).z for v in mesh.vertices if v.index not in out]
            if zs:
                low = min(low, min(zs)) if low != 0.0 else min(zs)
        lifts[f] = -low
    for f in frames:
        scene.frame_set(f)
        world = arm.matrix_world @ hips.matrix
        world.translation.z += lifts[f]
        hips.location = arm.convert_space(pose_bone=hips, matrix=world, from_space="WORLD", to_space="LOCAL").translation
        hips.keyframe_insert("location", frame=f)
    for o in body:
        if o.type == "MESH":
            o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    ad.action = None


def seat_on_log(arm, act, seat):
    """`act` keyed again with the hips and legs as `seat` has them (its
    first frame) and spine_01 turned so the body above keeps the way it
    faced in `act`."""
    ad = arm.animation_data or arm.animation_data_create()
    bones = arm.pose.bones
    scene = bpy.context.scene
    frames = sorted({int(round(kp.co.x)) for fc in act.fcurves for kp in fc.keyframe_points})
    ad.action = act
    turn = {}
    for f in frames:
        scene.frame_set(f)
        turn[f] = bones["spine_01"].matrix.to_quaternion()
    ad.action = seat
    scene.frame_set(int(seat.frame_range[0]))
    legs = {b: bones[b].matrix_basis.copy() for b in LEGS if b in bones}
    ad.action = act
    for f in frames:
        scene.frame_set(f)
        for b, m in legs.items():
            bones[b].matrix_basis = m
            bones[b].keyframe_insert("location", frame=f)
            bones[b].keyframe_insert("rotation_quaternion", frame=f)
        bpy.context.view_layer.update()
        sp = bones["spine_01"]
        at = sp.matrix.to_translation()
        sp.matrix = _placed(turn[f], at)
        sp.keyframe_insert("rotation_quaternion", frame=f)
        sp.keyframe_insert("location", frame=f)
    ad.action = None


def _placed(q, at):
    """A matrix turned `q`, at `at`."""
    m = q.to_matrix().to_4x4()
    m.translation = at
    return m


def clip_name(action, armature):
    # The glTF importer names them "<clip>" or "<clip>_<armature>".
    name = action.name.split("|")[-1]
    return name[:-len(armature) - 1] if name.endswith("_" + armature) else name


def load(path):
    """Imports a library; returns its armature, its other objects, and its
    actions by clip name."""
    before_obj = set(bpy.data.objects)
    before_act = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    new = set(bpy.data.objects) - before_obj
    arm = next(o for o in new if o.type == "ARMATURE")
    acts = {clip_name(a, arm.name): a for a in set(bpy.data.actions) - before_act}
    return arm, [o for o in new if o is not arm], acts


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # (Mixamo's 30 a second, keyed a frame each; UAL's come in to match)
    bpy.context.scene.render.fps = int(kaykit.FPS)
    arm, body, acts1 = load(os.environ["UAL1"])
    arm2, body2, acts2 = load(os.environ["UAL2"])
    keep = {}
    for names, acts in ((UAL1, acts1), (UAL2, acts2)):
        for n in names:
            if n not in acts:
                raise SystemExit("no clip %r" % n)
            keep[n] = acts[n]
    # The second library's mannequin goes; its clips stay.
    for o in [arm2] + body2:
        bpy.data.objects.remove(o, do_unlink=True)
    mixamo = mixamo_clips(arm)
    keep.update(mixamo)
    standing = [a for n, a in keep.items() if n.startswith("Idle")]
    standing += [mixamo[m[0]] for m in MIXAMO if m[3] and m[0] in mixamo]
    if os.environ.get("MANNEQUIN") != "1":
        for o in body:
            bpy.data.objects.remove(o, do_unlink=True)
        body = owl_character.player(arm, "ual", list(keep.values()), standing=standing)
    for name in GROUNDED:
        if name in keep:
            ground_on_body(arm, body, keep[name])
    sit_on_logs(arm, body, keep)
    for name in ON_LOG:
        if name in mixamo:
            seat_on_log(arm, mixamo[name], keep[LOG_CLIP])
    for a in list(bpy.data.actions):
        if a not in keep.values():
            bpy.data.actions.remove(a)
    # Each clip on its own NLA track (exported one animation per track).
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    for n, a in keep.items():
        a.use_fake_user = True
        track = ad.nla_tracks.new()
        track.name = n
        strip = track.strips.new(n, int(a.frame_range[0]), a)
        strip.name = n
        track.mute = True
    bpy.ops.object.select_all(action="DESELECT")
    for o in [arm] + body:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
                              export_anim_single_armature=True, export_def_bones=False,
                              export_vertex_color="NONE")
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB,", len(keep), "clips")


if __name__ == "__main__":
    main()
