"""The dragons' moves (user request): the user's Mixamo clips (MOVES_DIR - 30 fps, no skin; kept out
of the repo, as Mixamo's raw files may not be passed on) carried onto a dragon's skeleton by
tools/build_dragon_sage.py (the red one) and tools/build_dragon_warden.py (the black one).

Each is carried as tools/retarget.py carries a clip (from the source's rest - Mixamo's T pose - the
arms pointed the way the source's point), its legs' and trunk's motion scaled (DAMP: a man's stride
on a dragon's legs), and taken off the ground: the way the clip travels and turns - its hips' path,
smoothed over a step or two, and their heading - comes out of it (the dragon is moved and turned
by the game, BigGhost), what's left in it the hips' bob and sway, its body's own twist. What came
out is kept for the game (scripts/dragon_moves.gd, written from each build's OUT.moves.json by
tools/dragon_moves_gd.py): per clip its length, how far it goes forward and aside and how far it
turns over it (sampled), so the game can match its steps to the ground and turn the body with the
clip's own feet. A right turn can be the left one mirrored.

  MOVES: {game name: {"file": stem, "loop": bool, "kind": "walk"/"run"/"turn"/"act", "mirror": bool}}
"""
import json
import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

import retarget

# (Mixamo's names for ours - as tools/kaykit.py's TO_MIXAMO; the fingers left out: the dragon's
# hands are its own - the lantern's fist, DragonRig)
OURS = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
        "neck_01": "Neck", "Head": "Head"}
for _s, _side in (("l", "Left"), ("r", "Right")):
    OURS.update({f"clavicle_{_s}": f"{_side}Shoulder", f"upperarm_{_s}": f"{_side}Arm",
                 f"lowerarm_{_s}": f"{_side}ForeArm", f"hand_{_s}": f"{_side}Hand",
                 f"thigh_{_s}": f"{_side}UpLeg", f"calf_{_s}": f"{_side}Leg", f"foot_{_s}": f"{_side}Foot",
                 f"ball_{_s}": f"{_side}ToeBase"})
FROM_MIXAMO = {"mixamorig:" + v: k for k, v in OURS.items()}
ARM_AIM = ("upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r")
LEGS = ("thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r")
# How much of each kind's motion is kept (the rest 1): a man's stride on a dragon's legs (the knee
# already forward) kicks them out level; a run's pitch and a slash's twist, with the wings on its
# back, read as flailing
DAMP = {"walk": dict.fromkeys(LEGS, 0.75),
        "turn": dict.fromkeys(LEGS, 0.75),
        "run": {"pelvis": 0.7, **dict.fromkeys(LEGS, 0.6)},
        "act": {"pelvis": 0.45, "spine_01": 0.5, "spine_02": 0.5, "spine_03": 0.6, **dict.fromkeys(LEGS, 0.75)}}
RATE = 15.0          # samples a second (the clips are 30 fps)
SMOOTH = 0.6         # s: the path and the heading smoothed over this (a step or two) - what's left stays in the clip


def moving(poses, eps=1e-4):
    """The bones posed at all in `poses` ([{bone: (location, rotation)}, ...]) - away from their rest
    in any of them. (User request: the files kept small - a clip keys only these; the rest of the
    skeleton - the wings, the tail, the fingers, the skirt, set by DragonRig - stays at rest.)"""
    out = set()
    for pose in poses:
        for b, (loc, rot) in pose.items():
            if b in out:
                continue
            if loc.length > eps or rot.rotation_difference(Quaternion()).angle > eps:
                out.add(b)
    return out


def bake(arm, frames, poses):
    """Keys `poses` at `frames` on `arm`'s action - only the bones that move (moving)."""
    keep = moving(poses)
    for f, pose in zip(frames, poses):
        for pb in arm.pose.bones:
            if pb.name not in keep:
                continue
            pb.location, pb.rotation_quaternion = pose[pb.name]
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    return keep


def _swap(name):
    if name.endswith("_l"):
        return name[:-2] + "_r"
    if name.endswith("_r"):
        return name[:-2] + "_l"
    return name


def _mirror_q(q):
    # (reflected through the body's middle - x to -x)
    return Quaternion((q.w, q.x, -q.y, -q.z))


def load(path, name):
    """A Mixamo .fbx's armature, its bones under our names, its clip called `name`."""
    before_o, before_a = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=path)
    new = set(bpy.data.objects) - before_o
    arm = next(o for o in new if o.type == 'ARMATURE')
    act = next(a for a in bpy.data.actions if a not in before_a)
    act.name = name
    for b in arm.data.bones:
        if b.name in FROM_MIXAMO:
            b.name = FROM_MIXAMO[b.name]
    for fc in act.fcurves:
        p = fc.data_path
        if p.startswith('pose.bones["'):
            n = p.split('"')[1]
            if n in FROM_MIXAMO:
                fc.data_path = p.replace('"%s"' % n, '"%s"' % FROM_MIXAMO[n], 1)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    return arm, act


def _smooth(vals, w, loop):
    n = len(vals)
    if loop or w < 1:
        return list(vals)
    out = []
    for i in range(n):
        a, b = max(0, i - w), min(n - 1, i + w)
        acc = vals[a] * 0.0
        for v in vals[a:b + 1]:
            acc = acc + v
        out.append(acc / (b - a + 1))
    return out


def carry(arm, moves_dir, moves, log):
    """MOVES carried onto `arm`: ({game name: action}, {game name: what came out of it})."""
    actions, meta = {}, {}
    want = [b.name for b in arm.data.bones if b.name in OURS]
    for game, spec in moves.items():
        src, act = load(os.path.join(moves_dir, spec["file"] + ".fbx"), "mx_" + game)
        bones = [b for b in want if b in src.data.bones]
        loop = bool(spec.get("loop", False))
        f0, f1 = act.frame_range
        length = (f1 - f0) / 30.0
        n = max(4, int(round(length * RATE))) + (0 if loop else 1)
        clip = retarget.Clip(src, "mx_" + game, bones, n, loop=loop, ref="rest")
        if spec.get("mirror"):
            clip.rots = [{b: _mirror_q(r[_swap(b)]) for b in bones} for r in clip.rots]
            clip.ref = {b: _mirror_q(clip.ref[_swap(b)]) for b in bones}
            clip.heads = [Vector((-h.x, h.y, h.z)) for h in clip.heads]
            clip.rest_head = Vector((-clip.rest_head.x, clip.rest_head.y, clip.rest_head.z))
        # its heading (about the vertical, from facing -y; left turns positive) and its hips' path
        fwd0 = Vector((0.0, -1.0, 0.0))
        yaw = []
        for r in clip.rots:
            f = (r["pelvis"] @ clip.ref["pelvis"].inverted()) @ fwd0
            yaw.append(math.atan2(f.x, -f.y))
        for i in range(1, n):
            while yaw[i] - yaw[i - 1] > math.pi:
                yaw[i] -= 2 * math.pi
            while yaw[i] - yaw[i - 1] < -math.pi:
                yaw[i] += 2 * math.pi
        flat = [Vector((h.x, h.y, 0.0)) for h in clip.heads]
        if loop:
            # (a loop's: straight on, at the pace it covers a loop in)
            trip = (flat[-1] - flat[0]) * (n / max(n - 1, 1))
            spin = (yaw[-1] - yaw[0]) * (n / max(n - 1, 1))
            path = [flat[0] + trip * (i / n) for i in range(n)]
            head = [yaw[0] + spin * (i / n) for i in range(n)]
        else:
            w = int(round(SMOOTH * RATE * 0.5))
            path = _smooth(flat, w, False)
            head = _smooth(yaw, w, False)
            # (from where it stands at the start, to where it ends)
            path[0], path[-1] = flat[0], flat[-1]
            head[0], head[-1] = yaw[0], yaw[-1]
        # taken off: each sample turned back by its heading (from where it faces at its start too -
        # some start turned away), its hips over their path
        for i in range(n):
            R = Quaternion(Vector((0.0, 0.0, 1.0)), -head[i])
            clip.rots[i] = {b: R @ q for b, q in clip.rots[i].items()}
            local = clip.heads[i] - path[i]
            clip.heads[i] = Vector((path[0].x, path[0].y, 0.0)) + R @ local
        src_hips = clip.rest_head.z
        k = arm.data.bones["pelvis"].head_local.z / max(src_hips, 1e-6)
        R0 = Matrix.Rotation(head[0], 3, 'Z').inverted()
        rel = [R0 @ (p - path[0]) for p in path]
        # (its legs' swing scaled by DAMP: its feet cover that share of the way its hips go)
        meta[game] = {"length": round(length, 3), "loop": loop, "kind": spec["kind"], "rate": RATE,
                      "stride": DAMP[spec["kind"]].get("thigh_l", 1.0),
                      "fwd": [round(-p.y * k, 4) for p in rel], "side": [round(p.x * k, 4) for p in rel],
                      "turn": [round(math.degrees(h - head[0]), 2) for h in head]}
        if loop:
            meta[game]["trip"] = round(-(R0 @ trip).y * k, 4)
        # posed and keyed, as build_dragon_sage.carry
        ad = arm.animation_data or arm.animation_data_create()
        ad.action = None
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis.identity()
        damp = DAMP[spec["kind"]]
        strength = {b: damp.get(b, 1.0) for b in bones}
        poses = []
        feet = []
        toes = []
        for i in range(n):
            aim = {b: d for b, d in clip.dirs(i).items() if b in ARM_AIM}
            retarget.apply(arm, clip.delta(i), {b: b for b in bones}, strength, aim=aim, offset=clip.offset(i) * k)
            poses.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones})
            # (which foot's ahead, and by how much: its left's lead over its right, forward being -y)
            feet.append(round(-(arm.pose.bones["foot_l"].head.y - arm.pose.bones["foot_r"].head.y), 4))
            toes.append((arm.pose.bones["ball_l"].head.copy(), arm.pose.bones["ball_r"].head.copy()))
        meta[game]["feet"] = feet
        # How fast its planted foot goes back under it (its toes, the lower of the two, staying the
        # lower): the pace it walks at, played as it is - its feet on the ground at that speed
        per = (n if loop else max(n - 1, 1)) / max(length, 1e-3)
        back = []
        for i in range(n if loop else n - 1):
            j = (i + 1) % n
            for side in (0, 1):
                a, b = toes[i][side], toes[j][side]
                oa, ob = toes[i][1 - side], toes[j][1 - side]
                if a.z <= oa.z and b.z <= ob.z:
                    back.append(math.hypot(b.y - a.y, b.x - a.x) * per)
        back.sort()
        meta[game]["planted"] = round(back[len(back) // 2], 4) if back else 0.0
        out = bpy.data.actions.new(game)
        out.use_fake_user = True
        ad.action = out
        step = (length * 30.0) / (n if loop else max(n - 1, 1))
        frames = [1 + i * step for i in range(n)] + ([1 + n * step] if loop else [])
        if loop:
            poses.append(poses[0])
        bake(arm, frames, poses)
        ad.action = None
        actions[game] = out
        m = meta[game]
        log("move %s (%s%s): %.2f s, %.2f m on, %.2f m aside, turns %+.0f deg" % (
            game, spec["file"], ", mirrored" if spec.get("mirror") else "", length,
            m.get("trip", m["fwd"][-1]), m["side"][-1], m["turn"][-1] if not loop else 0.0))
        for o in [src] + list(src.children):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.actions.remove(act)
    return actions, meta


def write(meta, out):
    with open(out, "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
