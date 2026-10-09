"""The player's moves in a run (user request: the user's Mixamo clips -
MOVES_DIR, Y Bot, 30 fps, kept out of the repo like the other Mixamo
files - played when the player does things), onto the player's skeleton
(UAL's) by tools/kaykit.py, the hips kept over the feet (the game moves the
character):

  drink     Drinking          a potion drunk
  look      Looking           a hand to the brow, looking far (binoculars)
  eye       Magic.Heal        its second half (user request): an eye item used
  pick      Picking.Up        a thing picked up off the ground
  lift      Lifting           a rock turned over
  throw     Throw.Object      the 誘惑 fish thrown
  cheer     Victory           a rare catch: both arms up
  fist      Fist.Pump         a catch
  sad       Disappointed      the fish lost
  scared    Scared            a ghost's fright: down into a crouch and up
  dizzy     Dizzy.Idle        the spider's venom (a loop)
  pray      Praying           the offering at the altar (a loop)
  kneel     Kneeling.Down     down on a knee at the 渡石 (held at its end)
  sad_idle  Sad.Idle          worn out, standing (a loop)
  sad_walk  Sad.Walk          worn out, walking (a loop)
  walk      Walking           walking (a loop - user request: slowed down
                              by the stick it walked, not a slowed-down
                              run; the Locomotion Pack's)

FRAMES frames a clip, five facings - down, down-left, left, up-left, up;
the game draws the other three mirrored (memory on phones: this is a third
sheet beside the run's and the off hand's). Rows = clip x facing, and the
rows folded into side-by-side sections so no column is over MAX_H px
(phone GPUs); the camera fitted as tools/render_player.py fits the run
sheet (x-symmetric, the feet mid-cell; the offset in the json). The json
also has, per cell, the rod on the back and the right hand and hip
(render_player.hand_cell()).

  MOVES_DIR=<dir> PLAYER=<animal> GREYBOX_DIR=<build> \\
      bpyenv/bin/python tools/render_player_moves.py OUT_PREFIX [--dry]

writes OUT_PREFIX_albedo.png (2x density), OUT_PREFIX_normal.png and
OUT_PREFIX_rod.json.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_player as rp  # noqa: E402
import owl_character  # noqa: E402
import kaykit  # noqa: E402

# (name, file, source frames, how it's played: "once", "loop" or "pingpong"
# - down and back up - and whether it's a standing one (owl_character's
# stance: the feet kept under the hips))
CLIPS = [("drink", "Drinking.fbx", (62, 172), "once", True),
         ("look", "Looking.fbx", (12, 138), "once", True),
         ("eye", "Magic.Heal.fbx", (41, 81), "once", True),
         ("pick", "Picking.Up.fbx", (20, 170), "once", False),
         ("lift", "Lifting.fbx", (20, 100), "once", False),
         ("throw", "Throw.Object.fbx", (52, 100), "once", False),
         ("cheer", "Victory.fbx", (8, 110), "once", True),
         ("fist", "Fist.Pump.fbx", (14, 60), "once", True),
         ("sad", "Disappointed.fbx", (12, 96), "once", True),
         ("scared", "Scared.fbx", (205, 255), "pingpong", False),
         ("dizzy", "Dizzy.Idle.fbx", None, "loop", True),
         ("pray", "Praying.fbx", None, "loop", True),
         ("kneel", "Kneeling.Down.fbx", (15, 70), "once", False),
         ("sad_idle", "Sad.Idle.fbx", None, "loop", True),
         ("sad_walk", "Sad.Walk.fbx", None, "loop", False),
         ("walk", "Walking.fbx", None, "loop", False)]
NAMES = [c[0] for c in CLIPS]
DIRS = ["down", "down_left", "left", "up_left", "up"]
MAX_H = 8192


def load():
    """The rig with the player bound and the clips carried onto it, its
    bones renamed as render_player's are."""
    arm = kaykit.load_rig(rp.SCALE)
    meshes = owl_character.player(arm, "ual", [])
    src = {}
    for name, fbx, span, _mode, _standing in CLIPS:
        lib = kaykit.load_mixamo(os.path.join(os.environ["MOVES_DIR"], fbx), "mx_" + name)
        act = bpy.data.actions["mx_" + name]
        s, e = span or act.frame_range
        # (about two keys a frame drawn, at most)
        step = max(1, int((e - s) / (rp.FRAMES * 3)))
        src[name] = kaykit.bake(arm, lib, "mx_" + name, name="src_" + name, lift=0.0, rig="mixamo",
                                span=(s, e), step=step)
        bpy.data.objects.remove(lib, do_unlink=True)
    owl_character.player_stance(arm, "ual", list(src.values()),
                                standing=[src[c[0]] for c in CLIPS if c[4]])
    kaykit.rename_to_mixamo(arm)
    clips = {}
    for name, _fbx, _span, mode, _standing in CLIPS:
        if mode == "pingpong":
            s, e = src[name].frame_range
            at = [s + (e - s) * t for t in (0.0, 0.3, 0.6, 1.0, 1.0, 0.6, 0.3, 0.0)]
        else:
            at = rp.frames_of(src[name], loop=mode == "loop")
        poses = [rp.capture(arm, src[name], f) for f in at]
        clips[name] = rp.bake(arm, name, poses)
    return arm, meshes, clips


def fold(path, sections):
    """The rows cut into `sections` runs, set side by side."""
    img = np.asarray(Image.open(path).convert("RGBA"))
    rows = img.shape[0] // sections
    Image.fromarray(np.concatenate([img[i * rows:(i + 1) * rows] for i in range(sections)], axis=1),
                    "RGBA").save(path)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("out_prefix")
    p.add_argument("--density", type=int, default=2)
    p.add_argument("--dry", action="store_true", help="the json only, no render")
    args = p.parse_args()
    arm, meshes, clips = load()
    back_grip, back_tip = rp.back_rod_local(arm)
    # (PlayerVisual.WALK_PACE: the walk's own pace at the run's frame rate)
    print("walk pace %.1f px/s at 10.9 frames/s" % rp.run_pace(arm, clips["walk"]), flush=True)
    yaw = rs.Yaw(0.0)
    cells = [(name, d, f) for name in NAMES for d in DIRS for f in range(1, rp.FRAMES + 1)]
    mw = arm.matrix_world

    def pose(cell):
        name, d, f = cell
        yaw.set(rs.DIRS[d])
        rs.set_pose(clips[name], f)

    x0 = y0 = 1e9
    x1 = y1 = -1e9
    for cell in cells:
        pose(cell)
        b = rs.screen_bounds(meshes)
        x0, x1 = min(x0, b["min_x"]), max(x1, b["max_x"])
        y0, y1 = min(y0, b["min_y"]), max(y1, b["max_y"])
    hx = max(-x0, x1) + rp.PAD
    y0, y1 = y0 - rp.PAD, y1 + rp.PAD
    w = math.ceil(2 * hx * rp.DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * rp.DENSITY / 8) * 8
    cy = (y0 + y1) / 2
    d = args.density
    rows = len(NAMES) * len(DIRS)
    # As few sections as keep a column under MAX_H, the rows split evenly
    # (padded with empty rows to a whole number per section).
    sections = math.ceil(rows * h * d / MAX_H)
    per = math.ceil(rows / sections)
    rs.setup_scene(cy, max(w, h) / rp.DENSITY, w * d, h * d)
    scene = bpy.context.scene
    cam = scene.camera
    bpy.context.view_layer.update()

    def px(point):
        co = world_to_camera_view(scene, cam, point)
        return co.x * w, (1.0 - co.y) * h, co.z

    ox, oy, _ = px(rp.Vector((0.0, 0.0, 0.0)))
    rod = {n: [[None] * rp.FRAMES for _ in DIRS] for n in NAMES}
    hand = {n: [[None] * rp.FRAMES for _ in DIRS] for n in NAMES}
    belt = {n: [[None] * rp.FRAMES for _ in DIRS] for n in NAMES}

    def pose_and_data(cell):
        pose(cell)
        name, dname, f = cell
        bones = arm.pose.bones
        m = mw @ bones["mixamorig:Spine2"].matrix
        grip, tip = m @ back_grip, m @ back_tip
        gx, gy, _ = px(grip)
        tx, ty, _ = px(tip)
        chest_at = mw @ bones["mixamorig:Spine2"].head
        behind = ((grip + tip) * 0.5).y > chest_at.y + 0.05
        i = DIRS.index(dname)
        rod[name][i][f - 1] = [round(gx - ox, 2), round(gy - oy, 2), round(tx - ox, 2), round(ty - oy, 2), int(behind)]
        hand[name][i][f - 1], belt[name][i][f - 1] = rp.hand_cell(arm, px, ox, oy)

    if args.dry:
        for cell in cells:
            pose_and_data(cell)
    else:
        # (blank cells to fill the last section)
        pad = [None] * ((sections * per - rows) * rp.FRAMES)

        def pose_or_blank(cell):
            if cell is None:
                for o in meshes:
                    o.hide_render = True
                return
            for o in meshes:
                o.hide_render = False
            pose_and_data(cell)

        rs.pack_sheet(meshes, cells + pad, pose_or_blank, (w * d, h * d), rp.FRAMES, args.out_prefix)
        for o in meshes:
            o.hide_render = False
        # The normal map back to the original density (see scripts/art.gd).
        path = f"{args.out_prefix}_normal.png"
        img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
        hh, ww = img.shape[0] // d, img.shape[1] // d
        img = img.reshape(hh, d, ww, d, 4).mean(axis=(1, 3))
        n = img[..., :3] * 2.0 - 1.0
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
        img[..., :3] = n * 0.5 + 0.5
        Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
        for mode in ("albedo", "normal"):
            fold(f"{args.out_prefix}_{mode}.png", sections)
    meta = {"cell": [w, h], "frames": rp.FRAMES, "clips": NAMES, "dirs": DIRS, "sections": sections,
            "rows_per_section": per, "modes": {c[0]: c[3] for c in CLIPS},
            "offset": [0.0, round(-cy * rp.DENSITY, 2)], "rod": rod, "hand": hand, "belt": belt}
    with open(f"{args.out_prefix}_rod.json", "w") as fh:
        json.dump(meta, fh, separators=(",", ":"))
    print(json.dumps({k: meta[k] for k in ("cell", "offset", "sections", "rows_per_section")}))


if __name__ == "__main__":
    main()
