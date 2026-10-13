"""The 3D run's creatures and props (scripts/run_view_3d.gd), as glTF.

User request (the 3D lakeside forest): the animals, the ghosts, the willow
and the altar were still the 2D pictures stood up facing the camera -
made 3D here, from the same sources the pictures were rendered from, so
they look as they did, now in the round:

  animals    art_src/animal, art_src/critter (Quaternius' rigs; the user's
             critters on them, tools/prep_critters.py): only the clips the
             run uses kept, renamed Idle / Walk / Run (/ Attack, Eat)
  ghost      the floating ghost (art_src/ghost/ghost.glb), still - it's
             bobbed and swayed in the game
  big_ghost  the ghoul (CG+Soul.fbx) on the rig render_big_ghost.py fits
             to it, its three UAL2 clips keyed: Float, Chase, Eat
  water_ghost the zombie (Zombie.FBX), UAL2's walk and scratch keyed onto
             its Mixamo rig: Walk, Claw
  willow     the little horned creature with its staff (WILLOW.fbx)
  altar      art_src/altar/ancient_altar.fbx
  runes      the escape point's standing stones (art_src/rune_stones)
  cage       the big ghost's iron cage (built, render_characters.py) - only
             when asked for by name: the run no longer shows it

Kept light for phones: meshes decimated to a budget (MAX_TRIS each), no
pictures (base colours; the game weathers them, RunView3D._weathered).
They all face -Y here (+Z in Godot), stood on the ground at the origin;
the game sizes them.

  bpyenv/bin/python tools/build_run3d_models.py OUT_DIR RELEASE_DIR UAL2_GLB [name ...]

RELEASE_DIR holds CG+Soul.fbx, WILLOW.fbx and Zombie.FBX (the repo's
"assets-1" release); UAL2_GLB is Quaternius' Universal Animation Library 2
(not kept in the repo).
"""
import math
import os
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402
import render_characters as rc  # noqa: E402
import render_props as rp  # noqa: E402
import render_big_ghost as rbg  # noqa: E402
import render_water_ghost as rwg  # noqa: E402
import retarget  # noqa: E402

ART = os.path.join(os.path.dirname(__file__), "..", "art_src")
MAX_TRIS = {"big_ghost": 9000, "water_ghost": 7000, "willow": 7000, "altar": 3000, "runes": 1500,
            "cage": 4000, "ghost": 3000}
ANIMAL_TRIS = 4000
# (the snake's twenty-bone chain falls apart decimated: kept whole)
WHOLE = {"snake"}

# name: (file, {game clip: source clip})
ANIMALS = {
    "rat": ("critter/rat.glb", {"Idle": "Rat_Idle", "Walk": "Rat_Run"}),
    "frog": ("critter/frog.glb", {"Idle": "Frog_Idle", "Walk": "Frog_Jump"}),
    "snake": ("critter/snake.glb", {"Idle": "Snake_Idle", "Walk": "Snake_Walk"}),
    "spider": ("critter/spider.glb", {"Idle": "Spider_Idle", "Walk": "Spider_Walk"}),
    "black_spider": ("critter/black_spider.glb", {"Idle": "Spider_Idle", "Walk": "Spider_Walk"}),
    "wasp": ("critter/wasp.glb", {"Idle": "Wasp_Flying"}),
    "grasshopper": ("critter/grasshopper.glb", {"Idle": "Grasshopper_Idle", "Walk": "Grasshopper_Hop"}),
    "deer": ("animal/deer.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "stag": ("animal/stag.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "fox": ("animal/fox.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": "Attack"}),
    "wolf": ("animal/wolf.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": "Attack"}),
    "husky": ("animal/husky.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": "Attack"}),
    "shiba": ("animal/shiba.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Attack": "Attack"}),
    "horse": ("animal/horse.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "white_horse": ("animal/white_horse.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "cow": ("animal/cow.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "bull": ("animal/bull.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "donkey": ("animal/donkey.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
    "alpaca": ("animal/alpaca.glb", {"Idle": "Idle", "Walk": "Walk", "Run": "Gallop", "Eat": "Eating"}),
}
# The ghouls' clips: frames a loop (sampled from the source's), as in the
# pictures but finer.
BIG_GHOST = {"Float": "float", "Chase": "chase", "Eat": "eat"}
LOOP_FRAMES = 24


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH']


def tris(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in objs:
        m = o.evaluated_get(dg).to_mesh()
        m.calc_loop_triangles()
        n += len(m.loop_triangles)
    return n


def decimate(objs, budget):
    """Down to about `budget` triangles in all (each mesh its share)."""
    total = tris(objs)
    if total <= budget:
        return
    ratio = budget / total
    for o in objs:
        mod = o.modifiers.new("budget", 'DECIMATE')
        mod.ratio = ratio
        # (applied before an armature modifier, so the weights carry over)
        while o.modifiers.find("budget") > 0:
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_move_up(modifier="budget")
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="budget")


def plain_materials(objs):
    """Procedural paint can't go into glTF: each material's base colour
    (the paint's own, else its first colour input) set plainly."""
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if m is None or not m.use_nodes:
                continue
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is None:
                continue
            base = bsdf.inputs['Base Color']
            colour = None
            if base.links:
                src = base.links[0].from_node
                if src.type == 'MIX':
                    colour = src.inputs[6].default_value[:]
                elif src.type == 'TEX_IMAGE' and src.image is not None and src.image.has_data:
                    continue  # (a real picture: kept)
            for link in list(base.links):
                nt.links.remove(link)
            if colour is not None:
                base.default_value = colour


def export(name, out, animated):
    path = os.path.join(out, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_animations=animated,
                              export_animation_mode='ACTIONS', export_apply=False, export_yup=True,
                              export_lights=False, export_cameras=False)
    print("built", name, tris(meshes()), "tris", os.path.getsize(path) // 1024, "KB", flush=True)


def animal(name, out):
    fresh()
    path, clips = ANIMALS[name]
    bpy.ops.import_scene.gltf(filepath=os.path.join(ART, path))
    keep = {}
    for game, src in clips.items():
        a = rs.find_action(src)
        keep.setdefault(a, game)
    for a in list(bpy.data.actions):
        if a not in keep:
            bpy.data.actions.remove(a)
    for a, game in keep.items():
        a.name = game
        a.use_fake_user = True
    for o in bpy.data.objects:
        if o.animation_data is not None:
            o.animation_data.action = None
            for t in list(o.animation_data.nla_tracks):
                o.animation_data.nla_tracks.remove(t)
    if name not in WHOLE:
        decimate(meshes(), ANIMAL_TRIS)
    export(name, out, True)


def drop_others(arm):
    """The animation library's mannequin (and anything on it) goes; only
    `arm` and its meshes are exported."""
    names = set()
    for o in bpy.data.objects:
        if o.type == 'ARMATURE' and o != arm:
            names.add(o.name)
            names.update(c.name for c in o.children_recursive)
    for n in names:
        o = bpy.data.objects.get(n)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)


def key_pose(arm, frame):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def keyed_clip(arm, name, frames, pose):
    """An action `name` of `frames` poses (pose(i) sets the i-th), looping
    (its first pose again at the end)."""
    if arm.animation_data is None:
        arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for i in range(frames + 1):
        pose(i % frames)
        key_pose(arm, i)
    arm.animation_data.action = None


def big_ghost(out, release, ual2):
    ms, _lamp = rc.build_ghost(os.path.join(release, "CG+Soul.fbx"))
    arm = rbg.build_rig(ms)
    src = retarget.load_library(ual2)
    mapping = {b: b for b in rbg.BONES}
    for game, key in BIG_GHOST.items():
        _frames, clip, (ls, rs_), deg = rbg.CLIPS[key]
        c = retarget.Clip(src, clip, list(rbg.BONES), LOOP_FRAMES, loop=True, ref="mean")
        strength = {b: (ls if b.endswith("_l") else rs_ if b.endswith("_r") else 1.0) for b in rbg.BONES}
        extra = {"spine_01": rbg.lean(deg * 0.6), "spine_02": rbg.lean(deg * 0.4)} if deg else None
        keyed_clip(arm, game, LOOP_FRAMES, lambda i: retarget.apply(arm, c.delta(i), mapping, strength, extra))
    drop_others(arm)
    for a in list(bpy.data.actions):
        if a.name not in BIG_GHOST:
            bpy.data.actions.remove(a)
    # (the smoke it rises out of: churned in the game)
    plain_materials(meshes())
    decimate(meshes(), MAX_TRIS["big_ghost"])
    export("big_ghost", out, True)


def water_ghost(out, release, ual2):
    arm, ms = rwg.build(os.path.join(release, "Zombie.FBX"))
    src = retarget.load_library(ual2)
    bones = list(rwg.MIXAMO)
    hips = arm.matrix_world @ arm.data.bones[rwg.MIXAMO["pelvis"]].head_local
    for game, clip in (("Walk", "Zombie_Walk_Fwd_Loop"), ("Claw", "Zombie_Scratch")):
        c = retarget.Clip(src, clip, bones, LOOP_FRAMES, loop=True, ref="rest")
        lift = hips.z / c.rest_head.z

        def pose(i, c=c, lift=lift):
            retarget.apply(arm, c.delta(i), rwg.MIXAMO, 1.0, aim={b: v for b, v in c.dirs(i).items() if b in rwg.AIMED},
                           offset=c.offset(i) * lift)
        keyed_clip(arm, game, LOOP_FRAMES, pose)
    drop_others(arm)
    for a in list(bpy.data.actions):
        if a.name not in ("Walk", "Claw"):
            bpy.data.actions.remove(a)
    plain_materials(meshes())
    decimate(meshes(), MAX_TRIS["water_ghost"])
    export("water_ghost", out, True)


def static(name, out, release):
    if name == "ghost":
        fresh()
        bpy.ops.import_scene.gltf(filepath=os.path.join(ART, "ghost", "ghost.glb"))
    elif name == "willow":
        rc.build_willow(os.path.join(release, "WILLOW.fbx"))
    elif name == "altar":
        rp.build_altar()
    elif name == "runes":
        rp.build_runes(os.path.join(tempfile.gettempdir(), "runes_mask.png"))
    elif name == "cage":
        fresh()
        back, front = rc.ellipse_cage()
    plain_materials(meshes())
    decimate(meshes(), MAX_TRIS[name])
    export(name, out, False)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out, release, ual2 = args[:3]
    names = args[3:] or (list(ANIMALS) + ["ghost", "big_ghost", "water_ghost", "willow", "altar", "runes"])
    os.makedirs(out, exist_ok=True)
    for name in names:
        if name in ANIMALS:
            animal(name, out)
        elif name == "big_ghost":
            big_ghost(out, release, ual2)
        elif name == "water_ghost":
            water_ghost(out, release, ual2)
        else:
            static(name, out, release)


if __name__ == "__main__":
    main()
