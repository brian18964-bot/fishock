"""Player sprite sheet from Mixamo clips, plus where the rod goes in each cell.

User request: the carrying / casting / holding-the-rod animation. Trial
built on Mixamo (free with an Adobe account; its raw files may not be
redistributed, so they're not in art_src): the Y Bot character with the
clips Fishing Cast, Fishing Idle, Idle and Standard Run (the same files ship
with github.com/Kevin-Kwan/Unity3D-FishingRodMotion). This composes the
game's clips from them (rows = CLIPS x 8 facings, FRAMES columns), renders
the sheet through the 55deg pipeline (render_sprite.py) and writes, for
every cell, where the rod is drawn: its grip and tip on screen and whether
it's behind the body - in the left hand while fishing, across the back
otherwise. The game draws whichever rod is bought from that data
(scripts/held_rod.gd), so rod tiers don't need sheets of their own.

The clips (all baked to FRAMES poses):
  idle      Idle, ping-ponged over its first 2 s (breathing)
  run       Standard Run, made to run in place
  cast      Fishing Cast 31-140: winding back (0-3, follows the charge), the
            whip and follow-through (4-7). It's a long-rod cast - the tip
            drops low behind at the top of the backswing.
  hold      the arms-out hold after the cast (Fishing Cast 140-200, ping-pong)
  busy      Idle bent forward, rummaging
  reel      one crank of the reel (Fishing Cast's reeling-in stretch)
  fight     reel, leaning back against the fish
  hold_run  Standard Run's legs under hold's upper body

--grip (the candidate, rounds 4-6): the left hand holds the rod (rod_grip.py),
the reel is drawn with the character on top of the rod (reel.py) and, while
the rod is held out, the right hand is on its crank - turning it once round
over the reel clip; the fight is a braced pull (FIGHT_LEAN) - and the
pixels in front of the rod (front layer) cover it bent as the game bends it.

In the hand, the rod's grip follows the left hand's palm, and its angle is
set per frame (ROD_ANGLES): Mixamo's hands wave the rod about the way a
long-rod cast does (tip low behind at the top of the backswing), which
reads poorly from above, so instead it swings up over the head and back
with the charge, whips through overhead to the front on release, is held
out low while waiting (low enough to show its length from any facing) and
raised high against a running fish.

  python tools/render_player.py MIXAMO_DIR OUT_PREFIX [--density 2]

MIXAMO_DIR holds "Fishing Idle.fbx" (With Skin), "Fishing Cast.fbx",
"Y_Bot@idle.fbx" and "Y_Bot@standard_run.fbx" (60 fps). Writes
OUT_PREFIX_albedo.png (density x), OUT_PREFIX_normal.png (original density:
see scripts/art.gd) and OUT_PREFIX_rod.json, and prints the cell size and
sprite offset.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Quaternion, Vector
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import owl_character  # noqa: E402
import rod_grip  # noqa: E402
import reel  # noqa: E402

DENSITY = 27.108
PAD = 0.08
# Y Bot is 1.8 m; scaled to the old mannequin's height (UAL x1.3, 2.38).
SCALE = 1.317
FRAMES = 8
DIRS = ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
CLIPS = ["idle", "run", "cast", "hold", "busy", "reel", "fight", "hold_run"]
HAND_CLIPS = {"cast", "hold", "reel", "fight", "hold_run"}
# Rod in the hand, per frame: degrees up from pointing straight ahead
# (90 = straight up, 180 = straight back), and ROD_SIDE degrees out to
# the character's left (the hand holding it).
ROD_ANGLES = {
    "cast": [30, 70, 115, 150, 115, 70, 30, 18],
    "hold": [18, 18.5, 19, 19.5, 20, 19.5, 19, 18.5],
    "reel": [25, 26.5, 25, 23.5, 25, 26.5, 25, 23.5],
    "fight": [50 + 6 * math.sin(i / 8 * math.tau) for i in range(8)],
    "hold_run": [25 + 3 * math.sin(i / 8 * math.tau * 2) for i in range(8)],
}
# (--grip, user request round 6: the fight reads as the fish pulling.) Not
# cranking - through a run the drag gives line - but braced on the reel,
# leaning back (deg, - = back), yanked forward at frame 1 (the rod dipped
# toward the fish, the arms let out FIGHT_REACH) and hauled back up.
FIGHT_LEAN = [-12.0, -1.0, -4.0, -9.0, -13.0, -16.0, -15.0, -13.0]
FIGHT_REACH = [0.0, 0.08, 0.06, 0.03, 0.0, -0.02, -0.01, 0.0]
ROD_ANGLES_GRIP = dict(ROD_ANGLES, fight=[52, 38, 42, 48, 54, 58, 57, 54])
ROD_SIDE = 25.0
# Grip to tip, world units: the old in-hand rod's 32.8 world px.
ROD_TIP = 2.42
# Across the back (unscaled metres, facing -Y, the character's left is +X):
# from behind the right hip up past the left shoulder, drawn shorter.
BACK_GRIP = Vector((-0.14, 0.2, 0.92))
BACK_DIR = Vector((0.33, 0.06, 0.94)).normalized()
BACK_LENGTH = 1.25
UPPER_ROOT = "mixamorig:Spine"
HOLD_SETTLE = 0.75


def import_fbx(path):
    objs, acts = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o not in objs], [a for a in bpy.data.actions if a not in acts]


def fold_halves(path):
    """Moves the bottom half of a sheet's rows beside the top half."""
    img = np.asarray(Image.open(path).convert("RGBA"))
    half = img.shape[0] // 2
    Image.fromarray(np.concatenate([img[:half], img[half:]], axis=1), "RGBA").save(path)


def load(mixamo):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs, acts = import_fbx(os.path.join(mixamo, "Fishing Idle.fbx"))
    arm = next(o for o in objs if o.type == 'ARMATURE')
    meshes = [o for o in objs if o.type == 'MESH']
    src = {"fish_idle": acts[0]}
    for key, name in (("cast", "Fishing Cast.fbx"), ("idle", "Y_Bot@idle.fbx"), ("run", "Y_Bot@standard_run.fbx")):
        o2, a2 = import_fbx(os.path.join(mixamo, name))
        src[key] = a2[0]
        for o in o2:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in src.values():
        a.use_fake_user = True
    in_place(src["run"])
    arm.location *= SCALE
    arm.scale *= SCALE
    bpy.context.view_layer.update()
    return arm, meshes, src


def in_place(action):
    """Takes the forward root motion out of a locomotion clip."""
    s, e = action.frame_range
    for fc in action.fcurves:
        if fc.data_path == 'pose.bones["mixamorig:Hips"].location' and fc.array_index == 2:
            drift = fc.evaluate(e) - fc.evaluate(s)
            for k in fc.keyframe_points:
                d = drift * (k.co.x - s) / (e - s)
                k.co.y -= d
                k.handle_left.y -= d
                k.handle_right.y -= d
            fc.update()


def capture(arm, action, frame):
    rs.set_pose(action, frame)
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones}


def bake(arm, name, poses):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = act
    for k, pose in enumerate(poses):
        for pb in arm.pose.bones:
            pb.location, pb.rotation_quaternion = pose[pb.name]
            pb.keyframe_insert("location", frame=k + 1)
            pb.keyframe_insert("rotation_quaternion", frame=k + 1)
    return act


def turned(arm, pose, bone, axis_world, deg):
    """pose with `bone` turned `deg` more about a world axis (rest frame)."""
    rest = (arm.matrix_world @ arm.pose.bones[bone].bone.matrix_local).to_3x3().normalized()
    axis = (rest.inverted() @ axis_world).normalized()
    out = dict(pose)
    loc, rot = pose[bone]
    out[bone] = (loc, Quaternion(axis, math.radians(deg)) @ rot)
    return out


def pingpong(a, b):
    return [a + (b - a) * t for t in (0, 0.25, 0.5, 0.75, 1, 0.75, 0.5, 0.25)]


def crank_cycle(arm, cast):
    """One turn of the reel: the stretch of the reeling-in whose right arm
    comes back to where it started."""
    keys = ["mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand"]
    poses = {f: capture(arm, cast, f) for f in range(390, 505)}

    def dist(a, b):
        return sum((poses[a][k][1] - poses[b][k][1]).magnitude for k in keys)
    return min(((dist(a, a + n), a, n) for a in range(400, 480) for n in range(18, 26)))[1:]


def build_clips(arm, src, two_hands=False):
    """The clips, baked. two_hands (--grip, user request round 6): the
    fight is FIGHT_LEAN's braced pull on the reel's first pose (both hands
    then go on the reel, grip_clips)."""
    upper = {b.name for b in arm.pose.bones[UPPER_ROOT].children_recursive} | {UPPER_ROOT}
    idle_frames = pingpong(1, 121)
    run_s, run_e = src["run"].frame_range
    run_frames = [run_s + i * (run_e - run_s) / FRAMES for i in range(FRAMES)]
    a, n = crank_cycle(arm, src["cast"])
    reel_frames = [a + i * n / FRAMES for i in range(FRAMES)]
    print(f"reel cycle {a}+{n}", flush=True)
    # Lean back: the character faces -Y, its left is +X.
    side = Vector((1.0, 0.0, 0.0))

    def lean(pose, deg):
        for bone, share in (("mixamorig:Spine", 0.3), ("mixamorig:Spine1", 0.35), ("mixamorig:Spine2", 0.35)):
            pose = turned(arm, pose, bone, side, deg * share)
        return pose

    poses = {
        "idle": [capture(arm, src["idle"], f) for f in idle_frames],
        "run": [capture(arm, src["run"], f) for f in run_frames],
        "cast": [capture(arm, src["cast"], f) for f in (31, 49, 67, 85, 100, 110, 122, 140)],
        "hold": [capture(arm, src["cast"], f) for f in pingpong(140, 200)],
        "reel": [capture(arm, src["cast"], f) for f in reel_frames],
    }
    # User request (round 5: switching between waiting, reeling and the
    # fight is checked): the hold is the cast's follow-through, stepped
    # forward and sinking, its rod hand 6-11 px off the reel's, and the
    # game cuts straight from one to the other - the hold (hips and all)
    # HOLD_SETTLE of the way to the reel's first pose, the whip's last two
    # frames a third and two thirds of that, so it ends where the hold
    # starts.

    def toward(pose, target, w):
        return {b: (pose[b][0].lerp(target[b][0], w), pose[b][1].slerp(target[b][1], w)) for b in pose}

    poses["hold"] = [toward(p, poses["reel"][0], HOLD_SETTLE) for p in poses["hold"]]
    for i, k in ((6, 1 / 3), (7, 2 / 3)):
        poses["cast"][i] = toward(poses["cast"][i], poses["reel"][0], HOLD_SETTLE * k)
    poses["busy"] = [lean(p, 30.0 + 5.0 * math.sin(i / FRAMES * math.tau)) for i, p in enumerate(poses["idle"])]
    if two_hands:
        poses["fight"] = [lean(poses["reel"][0], deg) for deg in FIGHT_LEAN]
    else:
        poses["fight"] = [lean(p, -14.0 - 3.0 * math.sin(i / FRAMES * math.tau)) for i, p in enumerate(poses["reel"])]
    hold_top = poses["hold"][2]
    poses["hold_run"] = [{b: (hold_top[b] if b in upper else p[b]) for b in p} for p in poses["run"]]
    return {name: bake(arm, name, poses[name]) for name in CLIPS}


def check_lean(arm, clips):
    """busy must bend forward (head toward -Y), fight lean back."""
    head = arm.pose.bones["mixamorig:Head"]
    ys = {}
    for name in ("idle", "busy", "fight", "reel"):
        rs.set_pose(clips[name], 1)
        ys[name] = (arm.matrix_world @ head.head).y
    assert ys["busy"] < ys["idle"] and ys["fight"] > ys["reel"], ys


def back_rod_local(arm):
    """The back rod's ends in Spine2's space, placed on the rest pose."""
    arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    m = (arm.matrix_world @ arm.pose.bones["mixamorig:Spine2"].matrix).inverted()
    grip = BACK_GRIP * SCALE
    tip = grip + BACK_DIR * BACK_LENGTH * SCALE
    arm.data.pose_position = 'POSE'
    bpy.context.view_layer.update()
    return m @ grip, m @ tip


# ---------------------------------------------------------------- the hand on the rod (candidate)
# User request (round 4): the hand holds the rod - the rod fixed in the
# hand (rod_grip.py), the arm turned toward the path wanted - in a
# candidate sheet beside the game's (--grip). The rod's path: ROD_ANGLES'
# angle up, ROD_SIDE out to the left - a clip's whole path further out
# (GRIP_SIDE_STEP at a time, up to GRIP_SIDE_MAX) while the rod would
# pass through the character in any of its frames.
GRIP_SIDE_STEP = 8.0
GRIP_SIDE_MAX = 65.0
SHARED_SIDE = ("hold", "reel", "fight")
GRIP_BONES = ("mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand")
# The rods as the game draws them (scripts/held_rod.gd): each tier's
# sprite, its canvas centre from the grip (OFFSET, orig px), the tier's
# grip moved along it to the reel seat (GRIP_SHIFT, the candidate's), the
# sprite's grip-to-tip length the rod data's length stands for (TIP_X)
# and its thickness on screen (SPRITE_SCALE x THICKNESS_SCALE). The
# pixels in front of the rod are found over all five tiers' outlines -
# reel and butt included - so the one front layer serves whichever rod.
# (ROD_SPRITE_DIR: another set of the five, e.g. the candidate's - its
# rods without their reels, round 6: the reel is drawn with the character)
ROD_SPRITES = [os.path.join(os.environ.get("ROD_SPRITE_DIR") or os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "rod"),
    "rod_lvl%d_55deg_albedo.png" % t) for t in range(1, 6)]
ROD_OFFSET = (31.99, -1.63)
ROD_GRIP_SHIFT = [0.0, 0.0, 11.8, 7.5, 7.9]
ROD_TIP_END = [56.0, 56.0, 75.0, 75.5, 79.5]
# (round 6) the candidate game bends the rod while a fish is on (held_rod.gd
# BEND_*): the front layer covers it bent toward the fish, up to its most
# (BEND_FISH + BEND_TENSION + BEND_RUN + BEND_YANK, at most BEND_MAX) - the
# bends the mask is made over, rad at the tip
FRONT_BENDS = (0.45, 0.9, 1.3)
BEND_DOWN = 0.5
# where the fish is, for which side the rod bends to: straight ahead, this
# far (world units; a cast lands 4-8 away)
FISH_AHEAD = 5.0
ROD_TIP_X = 82.0
ROD_THICK = 0.5 * 1.6
FOOT_GROW = 3
_ROD_TEXELS = []


def rod_texels():
    """Each tier's opaque texels, in its node's local px (grip at 0)."""
    if not _ROD_TEXELS:
        for t, path in enumerate(ROD_SPRITES):
            a = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
            H, W = a.shape
            ys, xs = np.nonzero(a > 0)
            u = xs + 0.5 - W / 2.0
            v = ys + 0.5 - H / 2.0
            ox = (ROD_OFFSET[0] - ROD_GRIP_SHIFT[t]) * 2.0
            oy = ROD_OFFSET[1] * 2.0
            _ROD_TEXELS.append(np.stack([u + ox, v + oy], axis=1))
    return _ROD_TEXELS


def bent(along, bend, length, steps=32, gather=2.0):
    """held_rod.gd's bent rod (round 6): `along` px from the grip (screen,
    as on the straight rod) to the point on the bent centre line and its
    normal, in the rod's frame (x along it, y across) - the tip turned
    `bend` rad off its line, the turn gathering toward the tip as
    (distance / length) ^ gather; the butt behind the grip straight, past
    the visible tip (length px) on along its last direction."""
    a = np.asarray(along, float)
    length = max(length, 1e-3)
    step = length / steps
    k = np.arange(1, steps + 1)
    mids = bend * ((k - 0.5) / steps) ** gather
    pts = np.vstack([[0.0, 0.0], np.cumsum(np.c_[np.cos(mids), np.sin(mids)] * step, axis=0)])
    angs = bend * (np.arange(steps + 1) / steps) ** gather
    t = np.clip(a / length * steps, 0.0, steps)
    i = np.minimum(t.astype(int), steps - 1)
    f = t - i
    point = pts[i] * (1 - f)[:, None] + pts[i + 1] * f[:, None]
    ang = angs[i] * (1 - f) + angs[i + 1] * f
    past = a > length
    point[past] = pts[-1] + np.c_[np.cos(angs[-1]), np.sin(angs[-1])] * (a[past] - length)[:, None]
    behind = a <= 0
    point[behind] = np.c_[a[behind], np.zeros(behind.sum())]
    ang[behind] = 0.0
    return point, np.c_[-np.sin(ang), np.cos(ang)]


def rod_footprint(grip_px, tip_px, size, grow=None, bend=0.0, along_map=False):
    """Where any tier's rod covers this cell's picture (render px): each
    texel placed as held_rod.gd places it (its faint edge too), then
    `grow` px more (FOOT_GROW) - the front layer redraws the body's own
    pixels (scripts/body_front.gd), so reaching past the rod costs nothing
    inside the body, and short of it the rod's edge showed as a thin line
    (user request, round 5: no notches where the layer meets the rod).
    bend: the rod bent as held_rod.gd bends it (rad at the tip, + toward
    the rod's +y). along_map: also each pixel's place along the rod (0 at
    the grip, 1 at the tip; NaN off it)."""
    from scipy.ndimage import binary_dilation, distance_transform_edt
    W, H = size
    g = np.asarray(grip_px, float)
    al = np.asarray(tip_px, float) - g
    L = float(np.hypot(*al))
    mask = np.zeros((H, W), bool)
    tmap = np.full((H, W), np.nan)
    if L < 1e-6:
        return (mask, tmap) if along_map else mask
    cth, sth = al / L
    # local px -> render px: scale x by L / (2 TIP_X) (the sprite's 2x
    # texels to the rod data's length), y as held_rod.gd's scale.y to orig
    # px, then the density
    for t, tex in enumerate(rod_texels()):
        x = tex[:, 0] * (L / (ROD_TIP_X * 2.0))
        y = tex[:, 1] * ROD_THICK / 2.0 * RENDER_D[0]  # held_rod: / Art.DENSITY to orig px
        if bend:
            tip_len = (ROD_TIP_END[t] - ROD_GRIP_SHIFT[t]) / ROD_TIP_X * L
            c, n = bent(x, bend, tip_len)
            lx, ly = c[:, 0] + n[:, 0] * y, c[:, 1] + n[:, 1] * y
        else:
            lx, ly = x, y
        px = g[0] + lx * cth - ly * sth
        py = g[1] + lx * sth + ly * cth
        i = np.round(px).astype(int)
        j = np.round(py).astype(int)
        ok = (i >= 0) & (i < W) & (j >= 0) & (j < H)
        mask[j[ok], i[ok]] = True
        tmap[j[ok], i[ok]] = x[ok] / L
    grown = binary_dilation(mask, iterations=FOOT_GROW if grow is None else grow)
    if not along_map:
        return grown
    _, (ji, ii) = distance_transform_edt(~mask, return_indices=True)
    return grown, np.where(grown, tmap[ji, ii], np.nan)


RENDER_D = [2]


def rod_target(name, f, side=ROD_SIDE, angles=None):
    up = math.radians((angles or ROD_ANGLES)[name][f - 1])
    s = math.radians(side)
    return Vector((math.sin(s) * math.cos(up), -math.cos(s) * math.cos(up), math.sin(up)))


def _bvh(mesh):
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    return BVHTree.FromObject(ev, dg), mesh.matrix_world.copy()


_PARITY_RAYS = (Vector((0.0, 0.0, 1.0)), Vector((1.0, 0.3, 0.2)).normalized(), Vector((-0.4, 1.0, 0.1)).normalized())


def _inside(bvh, p):
    """Inside the character: rays out from p cross its surface an odd
    number of times, two of three ways (the nearest face's facing alone
    said "inside" for points a metre off - user request, round 5: the rod
    pushed out for hits that weren't there - thin ears and overlapping
    shells turn their backs on far points)."""
    odd = 0
    for ray in _PARITY_RAYS:
        n, q = 0, p.copy()
        while n < 64:
            hit, _, _, _ = bvh.ray_cast(q, ray)
            if hit is None:
                break
            n += 1
            q = hit + ray * 1e-4
        odd += n % 2
    return odd >= 2


def rod_through(mesh, grip, d, from_t=0.15):
    """How many of the rod's points (past the hand) are inside the
    character."""
    bvh, mw = _bvh(mesh)
    inv = mw.inverted()
    n = 0
    for t in np.linspace(from_t, 1.0, 40):
        p = inv @ (grip + d * ROD_TIP * t)
        loc, nor, _, _ = bvh.find_nearest(p)
        if loc is not None and (p - loc).dot(nor) < 0 and _inside(bvh, p):
            n += 1
    return n


# ---------------------------------------------------------------- both hands on the reel (candidate)
# User request (round 6): reeling in and the fight cranked at the air - the
# right hand turned a small circle 24-31 cm (in a 1.2 m animal person) off
# the rod, with no reel there. In the clips with the rod held out
# (STANCE_CLIPS) both hands are on it now: the left round its handle, the
# right on the reel's crank knob (reel.py, drawn with the character) -
# turning it once round over the reel clip's 8 frames (CRANK_STEP each,
# from THETA0: the knob back and down, nearest the body), still in the
# others (the fight gives line through the drag). The animals' arms are
# short and their bellies round: to bring both hands together on the reel
# in front of the body the torso turns (the right shoulder forward), may
# lean, and the shoulders come forward - how far, and where the rod hand
# goes (in the chest's frame, so a lean carries the hands), searched per
# character (Hands.search): the arms neither straight nor cramped, the
# hands, knob and reel clear of the body.
STANCE_CLIPS = ("hold", "reel", "fight", "hold_run")
THETA0 = 225.0
CRANK_STEP = 45.0
KNOB_TUNE = {"axis": 0.0, "palm_at": -0.1, "handle_r": reel.KNOB_R}
STANCE_TWIST = (10.0, 20.0, 30.0)
STANCE_LEAN = (0.0, 8.0)
STANCE_PROT = (15.0, 25.0)
# the arms' reach the search aims at (shoulder to grip, x their length) and
# never passes
REACH_AIM = 0.8
REACH_MAX = 0.93
# how much of the run's forward pitch the running hold takes back
UPRIGHT = 0.85
# the elbows tried round each arm's line (deg): the least bent wrist kept
ELBOW_SWINGS = (-45.0, -22.5, 0.0, 22.5, 45.0)
SPINE = (("mixamorig:Spine", 0.3), ("mixamorig:Spine1", 0.35), ("mixamorig:Spine2", 0.35))
STANCE_BONES = tuple(b for b, _ in SPINE) + ("mixamorig:LeftShoulder", "mixamorig:RightShoulder",
                                              "mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand")
TORSO_GROUPS = ("mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
                "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg")
# The search's grid and the fight's FIGHT_REACH are in world units for a
# character of the greybox animals' size (their char_k); others scale.
GRID_K = 2.18


def theta(name, f):
    """The crank's angle in this frame (deg; 0 = the knob toward the tip,
    90 = up): a whole turn over the reel clip, still elsewhere."""
    return (THETA0 + (f - 1) * CRANK_STEP) % 360.0 if name == "reel" else THETA0


def stance(arm, twist, lean, prot):
    """The torso turned `twist` deg (the right shoulder forward), leaned
    `lean` forward, the shoulders brought `prot` deg forward."""
    head = lambda b: rod_grip.head(arm, b)  # noqa: E731
    for b, share in SPINE:
        rod_grip.turn_bone(arm, b, rod_grip._rot([0, 0, 1], twist * share), head(b))
    for b, share in SPINE:
        # (a turn about +X tips the head toward -Y: forward)
        rod_grip.turn_bone(arm, b, rod_grip._rot([1, 0, 0], lean * share), head(b))
    rod_grip.turn_bone(arm, "mixamorig:RightShoulder", rod_grip._rot([0, 0, 1], prot), head("mixamorig:RightShoulder"))
    rod_grip.turn_bone(arm, "mixamorig:LeftShoulder", rod_grip._rot([0, 0, 1], -prot), head("mixamorig:LeftShoulder"))


def chest(arm):
    return np.array(arm.matrix_world @ arm.pose.bones["mixamorig:Spine2"].matrix)


def pitch(arm):
    """How far the chest leans forward (deg; the character faces -Y)."""
    up = chest(arm)[:3, 1]
    return math.degrees(math.atan2(-up[1], up[2]))


def yaw(arm):
    """Which way the shoulders face (deg about Z, from the right shoulder
    to the left)."""
    v = np.array(rod_grip.head(arm, "mixamorig:LeftArm")) - np.array(rod_grip.head(arm, "mixamorig:RightArm"))
    return math.degrees(math.atan2(v[1], v[0]))


class Torso:
    """The torso's surface as it's posed (its own vertices: not the arms in
    front of it), for clearances: signed distance by the nearest vertex
    and its normal (- inside)."""

    def __init__(self, mesh):
        from scipy.spatial import cKDTree
        idx = {mesh.vertex_groups[n].index for n in TORSO_GROUPS if n in mesh.vertex_groups}
        keep = np.array([v.index for v in mesh.data.vertices if v.groups and max(v.groups, key=lambda x: x.weight).group in idx])
        dg = bpy.context.evaluated_depsgraph_get()
        ev = mesh.evaluated_get(dg)
        n = len(ev.data.vertices)
        co, no = np.empty(n * 3), np.empty(n * 3)
        ev.data.vertices.foreach_get("co", co)
        ev.data.vertices.foreach_get("normal", no)
        m = np.array(mesh.matrix_world)
        self.co = co.reshape(-1, 3)[keep] @ m[:3, :3].T + m[:3, 3]
        no = no.reshape(-1, 3)[keep] @ m[:3, :3].T
        self.no = no / np.linalg.norm(no, axis=1, keepdims=True)
        self.tree = cKDTree(self.co)

    def sd(self, pts):
        pts = np.asarray(pts, float)
        shape = pts.shape[:-1]
        pts = pts.reshape(-1, 3)
        dist, i = self.tree.query(pts)
        along = np.einsum("ij,ij->i", pts - self.co[i], self.no[i])
        return np.where(along < 0, along, dist).reshape(shape)


class Hands:
    """Both hands on the reel (see STANCE_CLIPS)."""

    def __init__(self, arm, mesh, clips, g, character):
        self.arm, self.mesh, self.clips, self.g = arm, mesh, clips, g
        self.k = k = g._char_k(mesh)
        self.gR = rod_grip.Grip(arm, mesh, character, (), side="Right", tune=KNOB_TUNE)
        gR = self.gR
        seat = g.span[1] + reel.GAP * k
        knob_len = (gR.span[1] - gR.span[0]) * 0.8
        self.reel = reel.Reel(k, g.handle_r, seat, knob_len, knob_r=gR.handle_r)
        self.wrap = gR.handle_r + 2.0 * float(np.mean([gR.radius[x] for x in gR.fingers]))
        self.half = (gR.span[1] - gR.span[0]) * 0.5
        self.st = None
        self.ref_pitch = None

    def bones(self):
        return STANCE_BONES + tuple(self.g.pose) + tuple(self.gR.pose)

    def search(self, angles):
        """The stance (twist, lean, shoulders forward) and the rod hand's
        place in the chest's frame that suit this character - over the
        hold, the reel (the crank's whole turn) and the fight's yank and
        haul: both arms near REACH_AIM of their length (never past
        REACH_MAX), the hand on the knob, the reel and the rod hand clear
        of the torso, the rod hand nearest a natural height, the least
        turning and leaning."""
        arm, g, gR, rl, k = self.arm, self.g, self.gR, self.reel, self.k
        H = lambda b: np.array(rod_grip.head(arm, b))  # noqa: E731
        rs.set_pose(self.clips["reel"], 1)
        la = np.linalg.norm(H("mixamorig:LeftForeArm") - H("mixamorig:LeftArm")) + \
            np.linalg.norm(H("mixamorig:LeftHand") - H("mixamorig:LeftForeArm")) + np.linalg.norm(g.c_local)
        ra = np.linalg.norm(H("mixamorig:RightForeArm") - H("mixamorig:RightArm")) + \
            np.linalg.norm(H("mixamorig:RightHand") - H("mixamorig:RightForeArm")) + np.linalg.norm(gR.c_local)
        refs = [("hold", 1), ("reel", 1), ("fight", 2), ("fight", 6)]
        xs = np.arange(-0.05, 0.151, 0.05) * k / GRID_K
        ys = np.arange(0.10, 0.851, 0.025) * k / GRID_K
        zs = np.arange(-0.05, 0.851, 0.05) * k / GRID_K
        X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
        grid = np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1)
        best = None
        for tw in STANCE_TWIST:
            for le in STANCE_LEAN:
                for pr in STANCE_PROT:
                    posed = []
                    for name, f in refs:
                        rs.set_pose(self.clips[name], f)
                        stance(arm, tw, le, pr)
                        if name == "reel":
                            # the grid: in the reel's facing frame from the
                            # hips, then in the chest's
                            hips = H("mixamorig:Hips")
                            p = hips + grid * np.array([1.0, -1.0, 1.0])
                            local = (np.linalg.inv(chest(arm)) @ np.c_[p, np.ones(len(p))].T).T[:, :3]
                            shoulder_z = (H("mixamorig:RightArm")[2] + H("mixamorig:LeftArm")[2]) / 2 - hips[2]
                        posed.append((name, f, chest(arm), np.array(rod_target(name, f, ROD_SIDE, angles)),
                                      H("mixamorig:RightArm"), H("mixamorig:LeftArm"), Torso(self.mesh)))
                    score = 0.5 * np.abs(grid[:, 2] - 0.6 * shoulder_z) + 0.002 * (tw + le + pr)
                    ok = np.ones(len(grid), bool)
                    for name, f, M, d, rsh, lsh, torso in posed:
                        c = (M @ np.c_[local, np.ones(len(local))].T).T[:, :3]
                        if name == "fight":
                            c = c + np.array([0.0, -1.0, 0.0]) * FIGHT_REACH[f - 1] * k / GRID_K
                        ths = [theta("reel", i) for i in range(1, FRAMES + 1)] if name == "reel" else [THETA0]
                        offs = np.array([rl.knob(np.zeros(3), d, t)[0] for t in ths])
                        _, u, up, sv = reel.frame(np.zeros(3), d)
                        knobs = c[:, None, :] + offs[None]
                        kr = np.linalg.norm(knobs - rsh, axis=2) / ra
                        lr = np.linalg.norm(c - lsh, axis=1) / la
                        span = np.linspace(-self.half, self.half, 5)
                        dk = torso.sd(knobs[:, :, None, :] + sv * span[:, None]).min(axis=(1, 2))
                        dr = torso.sd(c + u * rl.seat + up * rl.lift)
                        dg = torso.sd(c)
                        ok &= (kr.max(axis=1) <= REACH_MAX) & (lr <= REACH_MAX) & (dk >= self.wrap) & \
                            (dr >= reel.BODY_R * k * 1.15) & (dg >= g.handle_r * 3.0)
                        score += (kr.mean(axis=1) - REACH_AIM) ** 2 + (lr - REACH_AIM) ** 2
                    score[~ok] = np.inf
                    i = int(np.argmin(score))
                    if np.isfinite(score[i]) and (best is None or score[i] < best["score"]):
                        best = {"score": round(float(score[i]), 4), "twist": tw, "lean": le, "prot": pr,
                                "grip": [round(float(v), 3) for v in grid[i]], "local": local[i].tolist()}
        if best is None:
            raise SystemExit("no stance brings both hands to the reel for this character")
        self.st = best
        return best

    def pose(self, name, f, target):
        """This frame with both hands on the reel (the clip's frame set
        already): the stance, the rod hand at its place (the fight's yank
        letting it out), the rod along `target`, the right hand on the knob.
        Returns what it took."""
        arm, g, gR, st = self.arm, self.g, self.gR, self.st
        stance(arm, st["twist"], st["lean"], st["prot"])
        if name == "hold_run":
            # the run's legs pitch the hold's upper body forward: it runs
            # upright as it holds (so the hands stay where they hold)
            if self.ref_pitch is None:
                rs.set_pose(self.clips["hold"], 3)
                stance(arm, st["twist"], st["lean"], st["prot"])
                self.ref_pitch, self.ref_yaw = pitch(arm), yaw(arm)
                rs.set_pose(self.clips[name], f)
                stance(arm, st["twist"], st["lean"], st["prot"])
            over = pitch(arm) - self.ref_pitch
            for b, share in SPINE:
                rod_grip.turn_bone(arm, b, rod_grip._rot([1, 0, 0], -over * UPRIGHT * share), rod_grip.head(arm, b))
            # and the rod swings as the shoulders turn with the stride (the
            # hands keep their hold on it and the reel)
            target = np.array(rod_grip._rot([0, 0, 1], yaw(arm) - self.ref_yaw) @ np.array(target, float))
        c = chest(arm) @ np.append(st["local"], 1.0)
        c = c[:3]
        if name == "fight":
            c = c + np.array([0.0, -1.0, 0.0]) * FIGHT_REACH[f - 1] * self.k / GRID_K
        g.fingers_on()
        g.reach(c, target, swings=ELBOW_SWINGS)
        c2, d = g.rod()
        kc, sv = self.reel.knob(c2, d, theta(name, f))
        gR.fingers_on()
        gR.reach(kc, sv, either=True, swings=ELBOW_SWINGS)
        kc2, _ = gR.rod()
        rsh = np.array(rod_grip.head(arm, "mixamorig:RightArm"))
        return {"grip_err": round(float(np.linalg.norm(np.array(c2) - c)), 4),
                "knob_err": round(float(np.linalg.norm(np.array(kc2) - kc)), 4),
                "wrist_l": round(g.wrist_bend(), 1), "wrist_r": round(gR.wrist_bend(), 1),
                "theta": theta(name, f), "knob_reach": round(float(np.linalg.norm(kc - rsh)), 3)}


def grip_clips(arm, mesh, clips, character):
    """The hand clips re-keyed with the hand on the rod: the fingers round
    it, the arm turned toward its path - and, in STANCE_CLIPS, the other
    hand on the reel's crank. Returns the grip, the hands and, per clip and
    frame, what it took."""
    angles = ROD_ANGLES_GRIP
    samples = [(clips[n], f, rod_target(n, f, ROD_SIDE, angles)) for n in ("hold", "reel", "fight", "hold_run")
               for f in range(1, FRAMES + 1)]
    g = rod_grip.Grip(arm, mesh, character, samples)
    hands = Hands(arm, mesh, clips, g, character)
    st = hands.search(angles)
    print("stance", json.dumps(st), flush=True)
    report = {"fit_deg": g.fit_deg, "wrap_deg": g.wrap_deg, "thumb_angles": g.thumb_angles,
              "handle_r": g.handle_r, "clips": {},
              "stance": {k: st[k] for k in ("twist", "lean", "prot", "grip", "score")},
              "reel": {"crank_r": hands.reel.crank_r, "seat": hands.reel.seat, "knob_x": hands.reel.knob_x,
                       "theta0": THETA0, "crank_step": CRANK_STEP,
                       "knob_thumb_angles": hands.gR.thumb_angles, "knob_wrap_deg": hands.gR.wrap_deg}}
    fingers = list(g.pose)

    def pose_frame(name, f, side):
        rs.set_pose(clips[name], f)
        target = rod_target(name, f, side, angles)
        if name in STANCE_CLIPS:
            return hands.pose(name, f, target)
        return g.hold(target)

    def clear_side(names):
        # the least side angle that clears every frame of these clips
        side = ROD_SIDE
        while True:
            worst = 0
            for name in names:
                for f in range(1, FRAMES + 1):
                    pose_frame(name, f, side)
                    c, d = g.rod()
                    worst = max(worst, rod_through(mesh, Vector(c), Vector(d)))
            if worst == 0 or side >= GRIP_SIDE_MAX:
                return side
            side += GRIP_SIDE_STEP
    # one side angle per clip (frame by frame, the rod jumped out where one
    # frame needed it), and one for waiting, reeling and the fight together
    # (user request, round 5: the game cuts between them - the rod kept
    # its line across the cut)
    sides = {name: clear_side([name]) for name in ("cast", "hold_run")}
    shared = clear_side(SHARED_SIDE)
    sides.update({name: shared for name in SHARED_SIDE})
    for name in ("hold", "reel", "fight", "hold_run", "cast"):
        side = sides[name]
        rows = []
        for f in range(1, FRAMES + 1):
            used = pose_frame(name, f, side)
            c, d = g.rod()
            through = rod_through(mesh, Vector(c), Vector(d))
            keys = GRIP_BONES + tuple(fingers) + (hands.bones() if name in STANCE_CLIPS else ())
            for b in keys:
                arm.pose.bones[b].keyframe_insert("rotation_quaternion", frame=f)
            used.update({"side": side, "through": through})
            rows.append(used)
        report["clips"][name] = rows
    # (user request, round 5: the cast ends where the hold starts) the
    # whip's last two frames a third and two thirds of the way to the
    # hold's first - its other hand coming to the knob
    rs.set_pose(clips["hold"], 1)
    held = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones}
    for f, w in ((7, 1 / 3), (8, 2 / 3)):
        rs.set_pose(clips["cast"], f)
        for pb in arm.pose.bones:
            loc, rot = held[pb.name]
            pb.location = pb.location.lerp(loc, w)
            pb.rotation_quaternion = pb.rotation_quaternion.slerp(rot, w)
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
        bpy.context.view_layer.update()
        c, d = g.rod()
        report["clips"]["cast"][f - 1]["through"] = rod_through(mesh, Vector(c), Vector(d))
        report["clips"]["cast"][f - 1]["to_hold"] = round(w, 3)
    return g, hands, report


def front_mask(meshes, cam, size, grip, tip, d, fish=None):
    """Where on this cell's picture (size, `d` x density) the character
    (meshes: its body, and the reel drawn with it) is in front of the
    drawn rod: the rod's footprint (its drawn width, from
    a little behind the grip to the tip), each pixel's ray against the
    character, nearer than the rod's axis there. fish (round 6: the game
    bends the rod while one is on): where it is (world) - the footprint
    then takes in the rod bent toward it by each of FRONT_BENDS too, each
    pixel against the rod's axis where that pixel lies along it. Returns
    that and the part of it within a pixel of the rod itself (see
    front_atlas)."""
    scene = bpy.context.scene
    W, H = size
    RENDER_D[0] = d

    def screen(p):
        x, y, _ = [v * k for v, k in zip(world_to_camera_view(scene, cam, p), (W, H, 1))]
        return np.array([x, H - y])
    a, b = screen(grip), screen(tip)
    foot, tmap = rod_footprint(a, b, (W, H), along_map=True)
    near = rod_footprint(a, b, (W, H), grow=1)
    if fish is not None:
        # (the side held_rod.gd bend_toward() bends it to: the line's pull,
        # leaning BEND_DOWN down the screen)
        ab = b - a
        q = screen(fish) - a
        q = q / (np.linalg.norm(q) or 1.0) + np.array([0.0, BEND_DOWN])
        side = 1.0 if ab[0] * q[1] - ab[1] * q[0] >= 0 else -1.0
        for bend in FRONT_BENDS:
            f2, t2 = rod_footprint(a, b, (W, H), bend=side * bend, along_map=True)
            tmap = np.where(np.isnan(tmap) & f2, t2, tmap)
            foot |= f2
            near |= rod_footprint(a, b, (W, H), grow=1, bend=side * bend)
    mask = np.zeros((H, W), bool)
    if not foot.any():
        return mask, mask
    mw_c = cam.matrix_world
    fwd = (mw_c.to_3x3() @ Vector((0, 0, -1))).normalized()
    right = (mw_c.to_3x3() @ Vector((1, 0, 0))).normalized()
    up = (mw_c.to_3x3() @ Vector((0, 1, 0))).normalized()
    sw = cam.data.ortho_scale if W >= H else cam.data.ortho_scale * W / H
    sh = sw * H / W
    hitters = []
    for o in meshes:
        bvh, mw = _bvh(o)
        inv = mw.inverted()
        hitters.append((bvh, mw, inv, (inv.to_3x3() @ fwd).normalized()))
    g3, t3 = Vector(grip), Vector(tip)
    for py, px in zip(*np.nonzero(foot)):
        q = np.array([px + 0.5, py + 0.5])
        # (where along the rod this pixel is - the straight rod's line runs
        # on past the grip, for the butt)
        t = float(tmap[py, px])
        o = mw_c.translation + right * ((q[0] / W - 0.5) * sw) + up * ((0.5 - q[1] / H) * sh)
        depth = None
        for bvh, mw, inv, dir_l in hitters:
            hit, _, _, _ = bvh.ray_cast(inv @ o, dir_l)
            if hit is not None:
                dd = ((mw @ hit) - o).dot(fwd)
                depth = dd if depth is None else min(depth, dd)
        if depth is None:
            continue
        on_rod = g3 + (t3 - g3) * t
        if depth < (on_rod - o).dot(fwd):
            mask[py, px] = True
    return mask, mask & near


def front_atlas(out_prefix, masks, cells, cell, d, cols):
    """The character's pixels in front of the rod, cut from the sheets
    (albedo at d x, normal at 1x) and packed: OUT_PREFIX_front_{albedo,
    normal}.png; returns each cell's [x, y, w, h, ox, oy] (atlas and
    in-cell place, in the albedo's px) or None."""
    alb = np.asarray(Image.open(f"{out_prefix}_albedo.png").convert("RGBA"))
    nor = np.asarray(Image.open(f"{out_prefix}_normal.png").convert("RGBA"))
    w, h = cell[0] * d, cell[1] * d
    pieces = []
    for i, c in enumerate(cells):
        m, near = masks.get(c, (None, None))
        if m is None or not m.any():
            pieces.append(None)
            continue
        ys, xs = np.nonzero(m)
        x0, y0 = xs.min() // d * d, ys.min() // d * d
        x1, y1 = (xs.max() // d + 1) * d, (ys.max() // d + 1) * d
        row, col = divmod(i, cols)
        X, Y = col * w, row * h
        a = alb[Y + y0:Y + y1, X + x0:X + x1].copy()
        # past the rod itself only where the body is opaque: drawn twice, a
        # half-clear outline pixel came out darker (user request, round 5:
        # no blocks of the character's colour where the layer ends)
        m = m.copy()
        m[y0:y1, x0:x1] &= (a[..., 3] >= 250) | near[y0:y1, x0:x1]
        a[..., 3] = (a[..., 3] * m[y0:y1, x0:x1]).astype(np.uint8)
        n = nor[(Y + y0) // d:(Y + y1) // d, (X + x0) // d:(X + x1) // d].copy()
        mn = m[y0:y1, x0:x1].reshape((y1 - y0) // d, d, (x1 - x0) // d, d).any(axis=(1, 3))
        n[..., 3] = (n[..., 3] * mn).astype(np.uint8)
        pieces.append((a, n, x0, y0))
    # shelf packing, rows 1024 px wide
    W = 1024
    x = y = rowh = 0
    place = []
    for p in pieces:
        if p is None:
            place.append(None)
            continue
        ph, pw = p[0].shape[:2]
        if x + pw > W:
            x, y, rowh = 0, y + rowh, 0
        place.append((x, y))
        x += pw + d
        rowh = max(rowh, ph + d)
    Hh = int(math.ceil((y + rowh) / 8.0) * 8) or 8
    A = np.zeros((Hh, W, 4), np.uint8)
    N = np.zeros((Hh // d, W // d, 4), np.uint8)
    out = []
    for p, pl in zip(pieces, place):
        if p is None:
            out.append(None)
            continue
        a, n, ox, oy = p
        X, Y = pl
        A[Y:Y + a.shape[0], X:X + a.shape[1]] = a
        N[Y // d:Y // d + n.shape[0], X // d:X // d + n.shape[1]] = n
        out.append([X, Y, a.shape[1], a.shape[0], int(ox), int(oy)])
    Image.fromarray(A, "RGBA").save(f"{out_prefix}_front_albedo.png")
    Image.fromarray(N, "RGBA").save(f"{out_prefix}_front_normal.png")
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("mixamo")
    p.add_argument("out_prefix")
    p.add_argument("--density", type=int, default=2)
    p.add_argument("--dry", action="store_true", help="rod data and cell size only, no render")
    p.add_argument("--grip", action="store_true",
                   help="candidate: the hand holding the rod (rod_grip.py), and the pixels in front of the rod")
    p.add_argument("--character", choices=("owl", "ybot"), default="owl",
                   help="who's drawn: the player's character (owl_character.player: the owl person,"
                   " or PLAYER=<animal> a greybox one) or Mixamo's Y Bot")
    args = p.parse_args()

    arm, meshes, src = load(args.mixamo)
    if args.character == "owl":
        meshes = owl_character.player(arm, "mixamo", list(src.values()), standing=[src["idle"]])
    clips = build_clips(arm, src, two_hands=args.grip)
    check_lean(arm, clips)
    hand_grip = grip_report = hands = None
    if args.grip:
        hand_grip, hands, grip_report = grip_clips(arm, meshes[0], clips, os.environ.get("PLAYER", "owl"))
        meshes = meshes + hands.reel.objects()
    back_grip, back_tip = back_rod_local(arm)
    yaw = rs.Yaw(0.0)
    cells = [(name, d, f) for name in CLIPS for d in DIRS for f in range(1, FRAMES + 1)]
    mw = arm.matrix_world

    def rod_ends(name, f):
        """This cell's rod (grip, tip) - and, with the reel, the side it
        stands out to (None: up)."""
        bones = arm.pose.bones
        if name in HAND_CLIPS and hand_grip is not None:
            c, dd = hand_grip.rod()
            grip = Vector(c)
            return grip, grip + Vector(dd) * ROD_TIP, None
        m = mw @ bones["mixamorig:Spine2"].matrix
        grip, tip = m @ back_grip, m @ back_tip
        # (on the back: away from it)
        return grip, tip, np.array((grip - m.translation)[:])

    def pose(cell):
        name, d, f = cell
        yaw.set(rs.DIRS[d])
        rs.set_pose(clips[name], f)
        if hands is not None:
            grip, tip, out = rod_ends(name, f)
            hands.reel.place(np.array(grip[:]), np.array((tip - grip).normalized()[:]), theta(name, f), out)
            bpy.context.view_layer.update()

    # Camera fitted to every cell, x-symmetric so the feet sit mid-cell.
    x0 = y0 = 1e9
    x1 = y1 = -1e9
    for cell in cells[::2]:
        pose(cell)
        b = rs.screen_bounds(meshes)
        x0, x1 = min(x0, b["min_x"]), max(x1, b["max_x"])
        y0, y1 = min(y0, b["min_y"]), max(y1, b["max_y"])
    hx = max(-x0, x1) + PAD
    y0, y1 = y0 - PAD, y1 + PAD
    w = math.ceil(2 * hx * DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * DENSITY / 8) * 8
    cy = (y0 + y1) / 2
    d = args.density
    rs.setup_scene(cy, max(w, h) / DENSITY, w * d, h * d)
    scene = bpy.context.scene
    cam = scene.camera
    bpy.context.view_layer.update()  # the camera's matrix, before projecting

    def px(point):
        co = world_to_camera_view(scene, cam, point)
        return co.x * w, (1.0 - co.y) * h, co.z

    ox, oy, _ = px(Vector((0.0, 0.0, 0.0)))
    rod = {name: [[None] * FRAMES for _ in DIRS] for name in CLIPS}
    crank = {name: [[None] * FRAMES for _ in DIRS] for name in STANCE_CLIPS}
    masks = {}

    def pose_and_rod(cell):
        pose(cell)
        name, dname, f = cell
        bones = arm.pose.bones
        chest_at = mw @ bones["mixamorig:Spine2"].head
        if name in HAND_CLIPS and hand_grip is not None:
            grip, tip, _ = rod_ends(name, f)
            if name in STANCE_CLIPS:
                kc, _ = hands.reel.knob(np.array(grip[:]), np.array((tip - grip).normalized()[:]), theta(name, f))
                kx, ky, _ = px(Vector(kc))
                crank[name][DIRS.index(dname)][f - 1] = [round(kx - ox, 2), round(ky - oy, 2)]
        elif name in HAND_CLIPS:
            hand = bones["mixamorig:LeftHand"]
            grip = (mw @ hand.head + mw @ bones["mixamorig:LeftHandMiddle1"].head) * 0.5
            up = math.radians(ROD_ANGLES[name][f - 1])
            side = math.radians(ROD_SIDE)
            # Facing -Y, the character's left is +X; then turned to its facing.
            local = Vector((math.sin(side) * math.cos(up), -math.cos(side) * math.cos(up), math.sin(up)))
            tip = grip + Matrix.Rotation(math.radians(rs.DIRS[dname]), 3, 'Z') @ local * ROD_TIP
        else:
            m = mw @ bones["mixamorig:Spine2"].matrix
            grip, tip = m @ back_grip, m @ back_tip
        gx, gy, _ = px(grip)
        tx, ty, _ = px(tip)
        # Behind the body = farther back than the chest, seen level (the
        # camera's depth would count anything held high as in front).
        behind = ((grip + tip) * 0.5).y > chest_at.y + 0.05
        rod[name][DIRS.index(dname)][f - 1] = [round(gx - ox, 2), round(gy - oy, 2), round(tx - ox, 2), round(ty - oy, 2), int(behind)]
        if hand_grip is not None and not args.dry:
            fish = None
            if name in STANCE_CLIPS:
                # straight ahead of its facing, on the ground
                fish = Matrix.Rotation(math.radians(rs.DIRS[dname]), 3, "Z") @ Vector((0.0, -FISH_AHEAD, 0.0))
            masks[cell] = front_mask(meshes, cam, (w * d, h * d), grip, tip, d, fish)

    if args.dry:
        for cell in cells:
            pose_and_rod(cell)
    else:
        rs.pack_sheet(meshes, cells, pose_and_rod, (w * d, h * d), FRAMES, args.out_prefix)

    # Normal map back to the original density (see scripts/art.gd).
    if d > 1 and not args.dry:
        path = f"{args.out_prefix}_normal.png"
        img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
        hh, ww = img.shape[0] // d, img.shape[1] // d
        img = img.reshape(hh, d, ww, d, 4).mean(axis=(1, 3))
        n = img[..., :3] * 2.0 - 1.0
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
        img[..., :3] = n * 0.5 + 0.5
        Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)

    front = None
    if hand_grip is not None and not args.dry:
        front = front_atlas(args.out_prefix, masks, cells, (w, h), d, FRAMES)

    # Performance on phones: 64 rows of cells made the sheet over 8192 px
    # tall, past what many phone GPUs take; the second half of the rows sits
    # beside the first instead (scripts/player_visual.gd, SHEET_HALVES).
    if not args.dry:
        for mode in ("albedo", "normal"):
            fold_halves(f"{args.out_prefix}_{mode}.png")

    meta = {"cell": [w, h], "frames": FRAMES, "clips": CLIPS, "dirs": DIRS,
            "offset": [0.0, round(-cy * DENSITY, 2)], "rod_length": round(ROD_TIP * DENSITY, 2),
            "rod": rod}
    if hand_grip is not None:
        meta["grip"] = "hand"
        meta["grip_report"] = grip_report
        # where the crank hand's knob is, per cell (the clips with both
        # hands on the reel), for checking its turn and the cuts
        meta["crank"] = crank
    if front is not None:
        meta["front"] = {name: [[front[cells.index((name, dn, f))] for f in range(1, FRAMES + 1)] for dn in DIRS]
                         for name in CLIPS}
    with open(f"{args.out_prefix}_rod.json", "w") as fh:
        json.dump(meta, fh, separators=(",", ":"))
    print(json.dumps({k: meta[k] for k in ("cell", "offset", "clips")}))


if __name__ == "__main__":
    main()
