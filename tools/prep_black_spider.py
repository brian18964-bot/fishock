"""The real black spider (user request: a spider you can catch that may
bite - poison, a big slow-down - found about the map, under turned rocks
and shaken out of chopped trees, in many colourings drawn at random).
From the user's spider pack (spider.blend: one rig, one 250-frame take
holding idle 1-61, walk 62-124, attack 125-187, death 188-250 - the
Unity copy's list of clips, at this file's 30 fps - and 8 colourings,
texture_spider1..8.png, over 4 normal maps).

  bpyenv/bin/python tools/prep_black_spider.py SPIDER_DIR      (repo root)

SPIDER_DIR holds spider.blend and the texture_spider*.png. Writes
art_src/critter/black_spider.glb (the rig with two clips, Spider_Walk and
Spider_Idle, named as the Quaternius spider's so render_animals.py takes
it the same way, and as wide as that one) and
art_src/critter/black_spider_skins/skin_<n>.jpg, the colourings, small -
render_animals.py renders one picture sheet per colouring over one normal
sheet (the shape is the same in all of them). The pack stays out of the
repo.
"""
import os
import sys

import bpy
from mathutils import Vector
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "art_src", "critter")
CLIPS = {"Spider_Idle": (1, 61), "Spider_Walk": (62, 124)}
# As wide as the Quaternius spider (art_src/critter/spider.glb), so the
# same draw scale fits it.
WIDTH = 5.94
TEX = 256


def clip(src, name, start, end):
    """A new action holding src's keys from start to end, from frame 1."""
    act = bpy.data.actions.new(name)
    for fc in src.fcurves:
        keys = [k for k in fc.keyframe_points if start <= k.co.x <= end]
        if not keys:
            continue
        nf = act.fcurves.new(fc.data_path, index=fc.array_index, action_group=fc.group.name if fc.group else "")
        nf.keyframe_points.add(len(keys))
        for k, nk in zip(keys, nf.keyframe_points):
            nk.co = (k.co.x - start + 1, k.co.y)
            nk.interpolation = k.interpolation
    act.use_fake_user = True
    return act


def main():
    src_dir = sys.argv[-1]
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src_dir, "spider.blend"))
    for o in list(bpy.data.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)
    arm = bpy.data.objects["Armature"]
    mesh = bpy.data.objects["Spider"]
    bpy.context.view_layer.update()
    corners = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
    wide = max(max(c[i] for c in corners) - min(c[i] for c in corners) for i in (0, 1))
    arm.scale = arm.scale * (WIDTH / wide)
    take = arm.animation_data.action
    made = [clip(take, n, *r) for n, r in CLIPS.items()]
    # One NLA track a clip: each exports as its own animation, by name.
    arm.animation_data.action = None
    for act in made:
        track = arm.animation_data.nla_tracks.new()
        track.name = act.name
        track.strips.new(act.name, 1, act)
    bpy.data.actions.remove(take)
    # The textures, small (the sprite cell is a few dozen pixels across).
    for im in bpy.data.images:
        if im.name.startswith("texture_spider"):
            im.filepath = os.path.join(src_dir, im.name)
            im.reload()
            im.scale(TEX, TEX)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "black_spider.glb"), export_format="GLB",
                              export_animation_mode="NLA_TRACKS", export_image_format="JPEG")
    skins = os.path.join(OUT, "black_spider_skins")
    os.makedirs(skins, exist_ok=True)
    for i in range(1, 9):
        im = Image.open(os.path.join(src_dir, "texture_spider%d.png" % i)).convert("RGB")
        im.resize((TEX, TEX), Image.LANCZOS).save(os.path.join(skins, "skin_%d.jpg" % i), quality=90)
    print("black spider: clips", [a.name for a in made])


if __name__ == "__main__":
    main()
