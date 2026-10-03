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
ROD_SIDE = 25.0
# Grip to tip, world units: the old in-hand rod's 32.8 world px.
ROD_TIP = 2.42
# Across the back (unscaled metres, facing -Y, the character's left is +X):
# from behind the right hip up past the left shoulder, drawn shorter.
BACK_GRIP = Vector((-0.14, 0.2, 0.92))
BACK_DIR = Vector((0.33, 0.06, 0.94)).normalized()
BACK_LENGTH = 1.25
UPPER_ROOT = "mixamorig:Spine"


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


def build_clips(arm, src):
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
    poses["busy"] = [lean(p, 30.0 + 5.0 * math.sin(i / FRAMES * math.tau)) for i, p in enumerate(poses["idle"])]
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
GRIP_BONES = ("mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand")
# The drawn rod's width on the sheet (orig px, held_rod.gd's
# THICKNESS_SCALE included) and how far its sprite reaches behind the
# grip (the lvl1 rod's butt: 16 of its 82 px).
ROD_DRAWN_WIDTH = 3.2
ROD_BUTT = 0.2


def rod_target(name, f, side=ROD_SIDE):
    up = math.radians(ROD_ANGLES[name][f - 1])
    s = math.radians(side)
    return Vector((math.sin(s) * math.cos(up), -math.cos(s) * math.cos(up), math.sin(up)))


def _bvh(mesh):
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    return BVHTree.FromObject(ev, dg), mesh.matrix_world.copy()


def rod_through(mesh, grip, d, from_t=0.15):
    """How many of the rod's points (past the hand) are inside the
    character."""
    bvh, mw = _bvh(mesh)
    inv = mw.inverted()
    n = 0
    for t in np.linspace(from_t, 1.0, 40):
        p = inv @ (grip + d * ROD_TIP * t)
        loc, nor, _, _ = bvh.find_nearest(p)
        if loc is not None and (p - loc).dot(nor) < 0:
            n += 1
    return n


def grip_clips(arm, mesh, clips, character):
    """The hand clips re-keyed with the hand on the rod: the fingers round
    it, the arm turned toward its path. Returns the grip and, per clip and
    frame, what it took."""
    samples = [(clips[n], f, rod_target(n, f)) for n in ("hold", "reel", "fight", "hold_run")
               for f in range(1, FRAMES + 1)]
    g = rod_grip.Grip(arm, mesh, character, samples)
    report = {"fit_deg": g.fit_deg, "wrap_deg": g.wrap_deg, "thumb_angles": g.thumb_angles,
              "handle_r": g.handle_r, "clips": {}}
    fingers = list(g.pose)
    for name in HAND_CLIPS:
        # one side angle for the whole clip (frame by frame, the rod jumped
        # out where one frame needed it): the least that clears every frame
        side = ROD_SIDE
        while True:
            worst = 0
            for f in range(1, FRAMES + 1):
                rs.set_pose(clips[name], f)
                g.hold(rod_target(name, f, side))
                c, d = g.rod()
                worst = max(worst, rod_through(mesh, Vector(c), Vector(d)))
            if worst == 0 or side >= GRIP_SIDE_MAX:
                break
            side += GRIP_SIDE_STEP
        rows = []
        for f in range(1, FRAMES + 1):
            rs.set_pose(clips[name], f)
            used = g.hold(rod_target(name, f, side))
            c, d = g.rod()
            through = rod_through(mesh, Vector(c), Vector(d))
            for b in GRIP_BONES + tuple(fingers):
                arm.pose.bones[b].keyframe_insert("rotation_quaternion", frame=f)
            used.update({"side": side, "through": through})
            rows.append(used)
        report["clips"][name] = rows
    return g, report


def front_mask(mesh, cam, size, grip, tip, d):
    """Where on this cell's picture (size, `d` x density) the character is
    in front of the drawn rod: the rod's footprint (its drawn width, from
    a little behind the grip to the tip), each pixel's ray against the
    character, nearer than the rod's axis there."""
    scene = bpy.context.scene
    W, H = size
    gx, gy, _ = [v * k for v, k in zip(world_to_camera_view(scene, cam, grip), (W, H, 1))]
    tx, ty, _ = [v * k for v, k in zip(world_to_camera_view(scene, cam, tip), (W, H, 1))]
    gy, ty = H - gy, H - ty
    a = np.array([gx, gy]) + (np.array([gx, gy]) - np.array([tx, ty])) * ROD_BUTT
    b = np.array([tx, ty])
    half = ROD_DRAWN_WIDTH * d * 0.5 + 1.0
    x0, x1 = int(max(0, min(a[0], b[0]) - half)), int(min(W - 1, max(a[0], b[0]) + half))
    y0, y1 = int(max(0, min(a[1], b[1]) - half)), int(min(H - 1, max(a[1], b[1]) + half))
    mask = np.zeros((H, W), bool)
    if x1 <= x0 or y1 <= y0:
        return mask
    mw_c = cam.matrix_world
    fwd = (mw_c.to_3x3() @ Vector((0, 0, -1))).normalized()
    right = (mw_c.to_3x3() @ Vector((1, 0, 0))).normalized()
    up = (mw_c.to_3x3() @ Vector((0, 1, 0))).normalized()
    sw = cam.data.ortho_scale if W >= H else cam.data.ortho_scale * W / H
    sh = sw * H / W
    bvh, mw = _bvh(mesh)
    inv = mw.inverted()
    inv3 = inv.to_3x3()
    ab = b - a
    L2 = float(ab @ ab) or 1.0
    g3, t3 = Vector(grip), Vector(tip)
    butt3 = g3 + (g3 - t3) * ROD_BUTT
    dir_l = (inv3 @ fwd).normalized()
    for py in range(y0, y1 + 1):
        for px in range(x0, x1 + 1):
            q = np.array([px + 0.5, py + 0.5])
            t = float(np.clip(((q - a) @ ab) / L2, 0.0, 1.0))
            if np.linalg.norm(q - (a + ab * t)) > half:
                continue
            o = mw_c.translation + right * ((q[0] / W - 0.5) * sw) + up * ((0.5 - q[1] / H) * sh)
            hit, _, _, _ = bvh.ray_cast(inv @ o, dir_l)
            if hit is None:
                continue
            depth = ((mw @ hit) - o).dot(fwd)
            on_rod = butt3 + (t3 - butt3) * t
            if depth < (on_rod - o).dot(fwd):
                mask[py, px] = True
    return mask


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
        m = masks.get(c)
        if m is None or not m.any():
            pieces.append(None)
            continue
        ys, xs = np.nonzero(m)
        x0, y0 = xs.min() // d * d, ys.min() // d * d
        x1, y1 = (xs.max() // d + 1) * d, (ys.max() // d + 1) * d
        row, col = divmod(i, cols)
        X, Y = col * w, row * h
        a = alb[Y + y0:Y + y1, X + x0:X + x1].copy()
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
    clips = build_clips(arm, src)
    check_lean(arm, clips)
    hand_grip = grip_report = None
    if args.grip:
        hand_grip, grip_report = grip_clips(arm, meshes[0], clips, os.environ.get("PLAYER", "owl"))
    back_grip, back_tip = back_rod_local(arm)
    yaw = rs.Yaw(0.0)
    cells = [(name, d, f) for name in CLIPS for d in DIRS for f in range(1, FRAMES + 1)]

    def pose(cell):
        name, d, f = cell
        yaw.set(rs.DIRS[d])
        rs.set_pose(clips[name], f)

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
    masks = {}
    mw = arm.matrix_world

    def pose_and_rod(cell):
        pose(cell)
        name, dname, f = cell
        bones = arm.pose.bones
        chest = mw @ bones["mixamorig:Spine2"].head
        if name in HAND_CLIPS and hand_grip is not None:
            c, dd = hand_grip.rod()
            grip = Vector(c)
            tip = grip + Vector(dd) * ROD_TIP
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
        behind = ((grip + tip) * 0.5).y > chest.y + 0.05
        rod[name][DIRS.index(dname)][f - 1] = [round(gx - ox, 2), round(gy - oy, 2), round(tx - ox, 2), round(ty - oy, 2), int(behind)]
        if hand_grip is not None and not args.dry:
            masks[cell] = front_mask(meshes[0], cam, (w * d, h * d), grip, tip, d)

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
    if front is not None:
        meta["front"] = {name: [[front[cells.index((name, dn, f))] for f in range(1, FRAMES + 1)] for dn in DIRS]
                         for name in CLIPS}
    with open(f"{args.out_prefix}_rod.json", "w") as fh:
        json.dump(meta, fh, separators=(",", ":"))
    print(json.dumps({k: meta[k] for k in ("cell", "offset", "clips")}))


if __name__ == "__main__":
    main()
