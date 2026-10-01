"""A skeleton for the frog merchant (user request: his arms and legs moved
as he walked - the sculpt comes with none). Bones set at the sculpt's
joints (measured on it, tools/prep_frog.py's coordinates: y up, front +z),
weights worked out from where each part is and what it is (its painted
colour: legs and feet, arms and wraps, the head and hood, the rest the
body), and three clips keyed here:

  Idle   breathing, the arms hanging easy, a tilt of the head
  Walk   a waddle: legs swinging, knees lifting, arms swinging against
         them, the hips rolling and bobbing (one stride a second)
  Talk   a hand raised as he talks, the head nodding

Used by tools/build_camp_models.py (frog_merchant), in Blender.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

import prep_frog as pf

FPS = 24
# Joints (sculpt units). x + is the frog's left.
HIPS = (0.0, -2.6, -0.1)
CHEST = (0.0, -1.0, -0.1)
NECK = (0.0, -0.75, -0.1)
CROWN = (0.0, 1.0, 0.0)
LEG = [(0.56, -2.75, -0.1), (0.6, -3.62, -0.05), (0.66, -4.35, 0.0), (0.74, -4.55, 0.6)]
ARM = [(1.05, -1.05, 0.0), (1.4, -1.75, 0.15), (1.5, -2.35, 0.25), (1.55, -2.85, 0.3)]
KNEE_Y, ANKLE_Y = LEG[1][1], LEG[2][1]
ELBOW_Y, WRIST_Y = ARM[1][1], ARM[2][1]


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def _is(col, ref):
    return np.all(np.abs(col - np.array(ref)) < 0.01, axis=-1)


def weights(V, Cv):
    """Per vertex, a weight per bone (dict bone -> array). V in sculpt
    units, Cv the vertex's colour (prep_frog's palette)."""
    x, y = V[:, 0], V[:, 1]
    n = len(V)
    w = {}
    side = {"L": x > 0, "R": x <= 0}
    sword = _is(Cv, pf.HILT) | _is(Cv, pf.GUARD) | _is(Cv, pf.SCABBARD) | ((np.abs(x) > 1.2) & (y > -1.0))
    legs = (_is(Cv, pf.PANTS) & (y < -2.45)) | (_is(Cv, pf.SKIN) & (y < -3.2))
    arms = ~sword & ~legs & (np.abs(x) > 1.0) & (y < -0.95) & (y > -3.0) & (
        _is(Cv, pf.SKIN) | _is(Cv, pf.WRAP) | _is(Cv, pf.LEATHER))
    head = ~sword & ~arms & (_is(Cv, pf.SKIN) | _is(Cv, pf.EYE) | _is(Cv, pf.PUPIL) | _is(Cv, pf.HOOD))
    # The body: hips low, chest up; the head from the neck.
    up = _smooth(-2.5, -1.9, y)
    w["hips"] = (1 - up)
    w["spine"] = up.copy()
    h = np.where(head, _smooth(-0.95, -0.55, y), 0.0)
    w["head"] = h
    w["hips"] *= (1 - h)
    w["spine"] *= (1 - h)
    # The legs: the pants blend into the hips at the top; thigh, shin,
    # foot down the leg.
    leg = np.where(legs, _smooth(-2.5, -2.85, y), 0.0)
    shin = _smooth(KNEE_Y + 0.12, KNEE_Y - 0.12, y)
    foot = _smooth(ANKLE_Y + 0.08, ANKLE_Y - 0.08, y)
    for s in "LR":
        on = np.where(side[s], leg, 0.0)
        w["thigh_" + s] = on * (1 - shin)
        w["shin_" + s] = on * shin * (1 - foot)
        w["foot_" + s] = on * foot
    for k in ("hips", "spine"):
        w[k] = w[k] * (1 - leg)
    # The arms: upper arm, forearm, hand.
    arm = np.where(arms, _smooth(-1.0, -1.25, y), 0.0)
    low = _smooth(ELBOW_Y + 0.12, ELBOW_Y - 0.12, y)
    hand = _smooth(WRIST_Y + 0.1, WRIST_Y - 0.1, y)
    for s in "LR":
        on = np.where(side[s], arm, 0.0)
        w["upperarm_" + s] = on * (1 - low)
        w["lowerarm_" + s] = on * low * (1 - hand)
        w["hand_" + s] = on * hand
    for k in ("hips", "spine", "head"):
        w[k] = w[k] * (1 - arm)
    total = sum(w.values())
    w["spine"] += np.where(total < 1e-6, 1.0, 0.0)
    return w


def armature(to_blender):
    """The bones (Blender, metres) - `to_blender` maps a sculpt point."""
    data = bpy.data.armatures.new("frog_rig")
    arm = bpy.data.objects.new("frog_rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')

    def bone(name, a, b, parent=None):
        e = data.edit_bones.new(name)
        e.head = to_blender(a)
        e.tail = to_blender(b)
        e.roll = 0.0
        if parent is not None:
            e.parent = data.edit_bones[parent]
            e.use_connect = False
        return e

    bone("hips", HIPS, (HIPS[0], HIPS[1] + 0.6, HIPS[2]))
    bone("spine", (HIPS[0], HIPS[1] + 0.6, HIPS[2]), CHEST, "hips")
    bone("head", NECK, CROWN, "spine")
    for s, k in (("L", 1), ("R", -1)):
        m = [(p[0] * k, p[1], p[2]) for p in LEG]
        bone("thigh_" + s, m[0], m[1], "hips")
        bone("shin_" + s, m[1], m[2], "thigh_" + s)
        bone("foot_" + s, m[2], m[3], "shin_" + s)
        a = [(p[0] * k, p[1], p[2]) for p in ARM]
        bone("upperarm_" + s, a[0], a[1], "spine")
        bone("lowerarm_" + s, a[1], a[2], "upperarm_" + s)
        bone("hand_" + s, a[2], a[3], "lowerarm_" + s)
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def skin(mesh_obj, arm, V, Cv):
    w = weights(V, Cv)
    for name, ws in w.items():
        g = mesh_obj.vertex_groups.new(name=name)
        for i in np.nonzero(ws > 0.001)[0]:
            g.add([int(i)], float(ws[i]), 'REPLACE')
    mod = mesh_obj.modifiers.new("rig", 'ARMATURE')
    mod.object = arm
    mesh_obj.parent = arm


# ---------------------------------------------------------------- the clips

def _swing(arm, name, axis, degrees):
    """Turns a bone about the frog's own axis ('x' side to side - + swings a
    hanging limb back, nods a head down; 'y' its up; 'z' its front - +
    swings a hanging limb toward its left), in degrees, as a pose."""
    pb = arm.pose.bones[name]
    world = {"x": Vector((1, 0, 0)), "y": Vector((0, 0, 1)), "z": Vector((0, -1, 0))}[axis]
    rest = pb.bone.matrix_local.to_3x3()
    local = (rest.inverted() @ world).normalized()
    return local, math.radians(degrees)


def _key(arm, frame, pose):
    """pose: bone -> list of (axis, degrees), plus "_lift" (hips up, m)."""
    for pb in arm.pose.bones:
        q = Matrix.Identity(3).to_quaternion()
        for axis, deg in pose.get(pb.name, []):
            local, ang = _swing(arm, pb.name, axis, deg)
            q = Quaternion(local, ang) @ q
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        if pb.name == "hips":
            pb.location = (0.0, pose.get("_lift", 0.0), 0.0)
            pb.keyframe_insert("location", frame=frame)


def _clip(arm, name, frames, pose_at):
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in range(frames + 1):
        _key(arm, f, pose_at(f / frames * math.tau))
    act.use_fake_user = True
    arm.animation_data.action = None
    return act


def _idle(t):
    return {
        "spine": [("x", 2.0 * math.sin(t))],
        "head": [("z", 3.0 * math.sin(t * 0.5)), ("x", -1.5 * math.sin(t))],
        "upperarm_L": [("x", 3.0 * math.sin(t + 0.6)), ("z", 4.0)],
        "upperarm_R": [("x", 3.0 * math.sin(t + 1.4)), ("z", -4.0)],
        "lowerarm_L": [("x", -6.0)], "lowerarm_R": [("x", -6.0)],
    }


def _walk(t):
    s = math.sin(t)
    lift_l = max(0.0, math.sin(t + math.pi / 2))
    lift_r = max(0.0, math.sin(t - math.pi / 2))
    return {
        "_lift": 0.012 * abs(math.cos(t)),
        "hips": [("z", 6.0 * s), ("y", 4.0 * s)],
        "spine": [("z", -4.0 * s), ("y", -5.0 * s), ("x", 3.0)],
        "head": [("z", -2.0 * s)],
        "thigh_L": [("x", -24.0 * s - 10.0 * lift_l)],
        "thigh_R": [("x", 24.0 * s - 10.0 * lift_r)],
        "shin_L": [("x", 30.0 * lift_l)],
        "shin_R": [("x", 30.0 * lift_r)],
        "foot_L": [("x", -10.0 * lift_l)],
        "foot_R": [("x", -10.0 * lift_r)],
        "upperarm_L": [("x", 18.0 * s), ("z", 6.0)],
        "upperarm_R": [("x", -18.0 * s), ("z", -6.0)],
        "lowerarm_L": [("x", -12.0 - 8.0 * max(0.0, -s))],
        "lowerarm_R": [("x", -12.0 - 8.0 * max(0.0, s))],
    }


def _talk(t):
    raise_ = 0.5 - 0.5 * math.cos(t)
    return {
        "spine": [("x", 1.5 * math.sin(t))],
        "head": [("x", 7.0 * max(0.0, math.sin(2 * t))), ("z", 4.0 * math.sin(t))],
        "upperarm_R": [("x", -38.0 * raise_), ("z", -10.0 * raise_)],
        "lowerarm_R": [("x", -55.0 * raise_ - 8.0 * math.sin(3 * t) * raise_)],
        "hand_R": [("z", 15.0 * math.sin(3 * t) * raise_)],
        "upperarm_L": [("x", 3.0 * math.sin(t)), ("z", 4.0)],
        "lowerarm_L": [("x", -8.0)],
    }


def animate(arm):
    """The three clips, each on its own NLA track (exported one per track)."""
    clips = [_clip(arm, "Idle", 48, _idle), _clip(arm, "Walk", 24, _walk), _clip(arm, "Talk", 48, _talk)]
    ad = arm.animation_data
    for act in clips:
        track = ad.nla_tracks.new()
        track.name = act.name
        strip = track.strips.new(act.name, 0, act)
        strip.name = act.name
        track.mute = True
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
