"""The player in the big ghost's grip (user request, Camp v2: no more being
carried off stiff to a cage - caught, the player struggles for a few
seconds, and staggers free if they get loose). Motion from Quaternius'
Universal Animation Library (CC0, not kept in the repo), carried
over to the player's Mixamo skeleton by tools/retarget.py - the player's
character on it (owl_character.player; --ybot: Mixamo's Y Bot, the old
stand-in):

  struggle  Push_Loop   shoving at the ghost's hold
  knock     Hit_Chest   struck free, staggering back a step

Framed exactly as the player's own sheet (tools/render_player.py: 56x72
cells, the feet at the same place), so PlayerVisual swaps sheets without
moving the character. Rows = clip x 8 facings, FRAMES columns.

  python tools/render_player_struggle.py MIXAMO_DIR UAL1_GLB OUT_PREFIX [--ybot]

writes OUT_PREFIX_albedo.png (2x density) and OUT_PREFIX_normal.png.
"""
import os
import sys

import bpy
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_player as rp  # noqa: E402
import owl_character  # noqa: E402
import retarget  # noqa: E402
from render_water_ghost import MIXAMO, AIMED  # noqa: E402

# (name, source clip, loops, the part of it used, how much of the body's
# lean and the hips' rise and fall is kept, whether the legs follow). The
# push keeps its arms - shoving at the ghost - over a body barely leaning
# and legs planted (full strength it lunges almost flat); knocked free,
# the chest takes the blow and the player staggers back a step.
CLIPS = [("struggle", "Push_Loop", True, (0.0, 1.0), 0.35, False),
         ("knock", "Hit_Chest", False, (0.0, 1.0), 1.0, True)]
TRUNK = ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head")
LEGS = ("thigh", "calf", "foot", "ball")
# The player sheet's cell and camera (render_player.py's output).
CELL = (56, 72)
CENTER_Y = 15.38 / rp.DENSITY
HD = 2


def main():
    ybot = "--ybot" in sys.argv
    mixamo, ual1, out = [a for a in sys.argv if a != "--ybot"][-3:]
    arm, meshes, _ = rp.load(mixamo)
    if not ybot:
        meshes = owl_character.player(arm, "mixamo", [])
    for a in [a for a in bpy.data.actions]:
        a.use_fake_user = False
    lib1 = retarget.load_library(ual1)
    libs = {"Push_Loop": lib1, "Hit_Chest": lib1}
    bones = list(MIXAMO)
    clips = [retarget.Clip(libs[src], src, bones, rp.FRAMES, loop=loop, ref="rest", span=span)
             for _, src, loop, span, _, _ in CLIPS]
    hips = arm.matrix_world @ arm.data.bones[MIXAMO["pelvis"]].head_local
    lift = hips.z / clips[0].rest_head.z
    yaw = rs.Yaw(0.0)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for t in ad.nla_tracks:
        t.mute = True

    def pose(cell):
        c, d, i = cell
        clip = clips[c]
        k, legs = CLIPS[c][4], CLIPS[c][5]
        yaw.set(0.0)
        # The hips rise and fall, but stay over the feet (the sprite's
        # origin): any travel is the game's to do.
        off = clip.offset(i) * lift
        off.x = off.y = 0.0
        planted = [b for b in bones if b.split("_")[0] in LEGS] if not legs else []
        strength = {b: (k if b in TRUNK else (0.0 if b in planted else 1.0)) for b in bones}
        aim = {b: v for b, v in clip.dirs(i).items() if b in AIMED and b not in planted}
        retarget.apply(arm, clip.delta(i), MIXAMO, strength, aim=aim, offset=off * (k if legs else 0.0))
        yaw.set(rs.DIRS[d])

    w, h = CELL
    rs.setup_scene(CENTER_Y, max(w, h) / rp.DENSITY, w * HD, h * HD)
    cells = [(c, d, i) for c in range(len(CLIPS)) for d in rp.DIRS for i in range(rp.FRAMES)]
    rs.pack_sheet(meshes, cells, pose, (w * HD, h * HD), rp.FRAMES, out)
    # The normal map back to the original density (see scripts/art.gd).
    path = f"{out}_normal.png"
    img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    hh, ww = img.shape[0] // HD, img.shape[1] // HD
    img = img.reshape(hh, HD, ww, HD, 4).mean(axis=(1, 3))
    n = img[..., :3] * 2.0 - 1.0
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    img[..., :3] = n * 0.5 + 0.5
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    print("wrote", out, [c[0] for c in CLIPS])


if __name__ == "__main__":
    main()
