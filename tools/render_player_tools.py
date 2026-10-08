"""The player using the off hand's thing (user request: the knives, the
hatchet, the machete, the pistol and the net in the off hand, swung with
a tap of the right stick - each with its own move). Motion from Kay
Lousberg's KayKit Character Animations (CC0, art_src/kaykit/), carried
onto the player's skeleton (UAL's) by tools/kaykit.py - not mirrored:
KayKit's fighter swings with the right hand, the game's off hand:

  slash  Melee_1H_Attack_Slice_Diagonal   a blade swung at a beast
  chop   Melee_1H_Attack_Chop             the hatchet or machete at a tree
  scoop  Melee_1H_Attack_Slice_Horizontal the net swept low at a critter
  shoot  Ranged_1H_Shoot                  the pistol fired

Rows = clip x 8 facings, FRAMES columns, the camera fitted to them as
tools/render_player.py fits the run sheet (x-symmetric, the feet mid-cell;
the offset in the json). The json also has, per cell, the rod on the back
and the right hand and hip (render_player.hand_cell()) - the game draws
the rod and the thing in hand from them (held_rod.gd, offhand_prop.gd).

  python tools/render_player_tools.py OUT_PREFIX [--dry]
      PLAYER=<animal> GREYBOX_DIR=<build>   (owl_character.player_files)

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

# (name, KayKit file, clip)
CLIPS = [("slash", "melee", "Melee_1H_Attack_Slice_Diagonal"),
         ("chop", "melee", "Melee_1H_Attack_Chop"),
         ("scoop", "melee", "Melee_1H_Attack_Slice_Horizontal"),
         ("shoot", "ranged", "Ranged_1H_Shoot")]
NAMES = [c[0] for c in CLIPS]


def load():
    """The rig with the player bound and the clips carried onto it (not
    mirrored), its bones renamed as render_player's are."""
    arm = kaykit.load_rig(rp.SCALE)
    meshes = owl_character.player(arm, "ual", [])
    libs = {}
    src = {}
    for name, kind, clip in CLIPS:
        if kind not in libs:
            libs[kind] = kaykit.load_source(kaykit.path(kind))
        src[name] = kaykit.bake(arm, libs[kind], clip, name="src_" + name, mirror=False, lift=0.0)
    for lib in libs.values():
        bpy.data.objects.remove(lib, do_unlink=True)
    owl_character.player_stance(arm, "ual", list(src.values()), standing=list(src.values()))
    kaykit.rename_to_mixamo(arm)
    clips = {}
    for name in NAMES:
        poses = [rp.capture(arm, src[name], f) for f in rp.frames_of(src[name], loop=False)]
        clips[name] = rp.bake(arm, name, poses)
    return arm, meshes, clips


def main():
    p = argparse.ArgumentParser()
    p.add_argument("out_prefix")
    p.add_argument("--density", type=int, default=2)
    p.add_argument("--dry", action="store_true", help="the json only, no render")
    args = p.parse_args()
    arm, meshes, clips = load()
    back_grip, back_tip = rp.back_rod_local(arm)
    yaw = rs.Yaw(0.0)
    cells = [(name, d, f) for name in NAMES for d in rp.DIRS for f in range(1, rp.FRAMES + 1)]
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
    rs.setup_scene(cy, max(w, h) / rp.DENSITY, w * d, h * d)
    scene = bpy.context.scene
    cam = scene.camera
    bpy.context.view_layer.update()

    def px(point):
        co = world_to_camera_view(scene, cam, point)
        return co.x * w, (1.0 - co.y) * h, co.z

    ox, oy, _ = px(rp.Vector((0.0, 0.0, 0.0)))
    rod = {n: [[None] * rp.FRAMES for _ in rp.DIRS] for n in NAMES}
    hand = {n: [[None] * rp.FRAMES for _ in rp.DIRS] for n in NAMES}
    belt = {n: [[None] * rp.FRAMES for _ in rp.DIRS] for n in NAMES}
    sway = {n: [[None] * rp.FRAMES for _ in rp.DIRS] for n in NAMES}

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
        i = rp.DIRS.index(dname)
        rod[name][i][f - 1] = [round(gx - ox, 2), round(gy - oy, 2), round(tx - ox, 2), round(ty - oy, 2), int(behind)]
        hand[name][i][f - 1], belt[name][i][f - 1] = rp.hand_cell(arm, px, ox, oy)
        sway[name][i][f - 1] = rp.sway_cell(arm, px, ox, oy)

    if args.dry:
        for cell in cells:
            pose_and_data(cell)
    else:
        rs.pack_sheet(meshes, cells, pose_and_data, (w * d, h * d), rp.FRAMES, args.out_prefix)
        # The normal map back to the original density (see scripts/art.gd).
        path = f"{args.out_prefix}_normal.png"
        img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
        hh, ww = img.shape[0] // d, img.shape[1] // d
        img = img.reshape(hh, d, ww, d, 4).mean(axis=(1, 3))
        n = img[..., :3] * 2.0 - 1.0
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
        img[..., :3] = n * 0.5 + 0.5
        Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    meta = {"cell": [w, h], "frames": rp.FRAMES, "clips": NAMES, "dirs": rp.DIRS,
            "offset": [0.0, round(-cy * rp.DENSITY, 2)], "rod": rod, "hand": hand, "belt": belt, "sway": sway,
            "sway_names": list(rp.sway_names(arm))}
    with open(f"{args.out_prefix}_rod.json", "w") as fh:
        json.dump(meta, fh, separators=(",", ":"))
    print(json.dumps({k: meta[k] for k in ("cell", "offset", "clips")}))


if __name__ == "__main__":
    main()
