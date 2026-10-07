"""Kay Lousberg's KayKit Character Animations (CC0, art_src/kaykit/ - the
Rig_Medium clips, user request: the fishing they have - casting, waiting,
the bite, striking, reeling, the fight and landing the fish) carried over
to the player's skeleton: the Universal Animation Library's (UAL, CC0 -
art_src/player/ual1_standard.glb), the one the camp's character already
stands on, so no Mixamo file is needed any more.

KayKit's mannequin has 23 bones (no fingers, no neck, no collar bones);
each clip is carried over the way tools/retarget.py carries the ghosts'
(the trunk turned as the source's turns, the limbs pointed the way the
source's point - its rest pose isn't UAL's) and mirrored: KayKit's angler
casts with the right hand, the game's holds the rod in the left (the right
on the reel's crank).

    import kaykit
    src = kaykit.load_source(path)              # a Rig_Medium .glb
    act = kaykit.bake(arm, src, "Fishing_Cast")  # an action on `arm` (UAL)
"""
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

import retarget

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DIR = os.path.join(ROOT, "art_src", "kaykit")
# The files, by what's in them.
FILES = {"tools": "Rig_Medium_Tools.glb", "general": "Rig_Medium_General.glb",
         "move": "Rig_Medium_MovementBasic.glb", "move_adv": "Rig_Medium_MovementAdvanced.glb",
         "sim": "Rig_Medium_Simulation.glb", "melee": "Rig_Medium_CombatMelee.glb",
         "ranged": "Rig_Medium_CombatRanged.glb"}
# KayKit bone -> UAL bone (the source's own side; mirrored in bake()).
TRUNK = {"hips": "pelvis", "spine": "spine_01", "chest": "spine_03", "head": "Head"}
LIMBS = {}
for _s in ("l", "r"):
    LIMBS.update({f"upperarm.{_s}": f"upperarm_{_s}", f"lowerarm.{_s}": f"lowerarm_{_s}",
                  f"wrist.{_s}": f"hand_{_s}", f"upperleg.{_s}": f"thigh_{_s}",
                  f"lowerleg.{_s}": f"calf_{_s}", f"foot.{_s}": f"foot_{_s}", f"toes.{_s}": f"ball_{_s}"})
MAP = dict(TRUNK, **LIMBS)
FPS = 30.0


def path(kind):
    return os.path.join(DIR, FILES[kind])


def load_source(glb):
    """Imports a KayKit .glb; returns its armature (its mannequin hidden)."""
    return retarget.load_library(glb)


def _other(name):
    if name.endswith(".l"):
        return name[:-2] + ".r"
    if name.endswith(".r"):
        return name[:-2] + ".l"
    return name


def _mirror_q(q):
    """A world rotation seen in a mirror across x = 0."""
    return Quaternion((q.w, q.x, -q.y, -q.z))


def _mirror_v(v):
    return Vector((-v.x, v.y, v.z))


def action_name(src_arm, clip):
    """The source's action for `clip` ("Fishing_Cast")."""
    for a in bpy.data.actions:
        base = a.name.split("|")[-1]
        if base == clip or base.startswith(clip + "_Rig_Medium"):
            return base
    raise SystemExit(f"no KayKit clip {clip!r}")


LEGS = ("upperleg", "lowerleg")
# KayKit's mannequin stands short-legged and deep in the knees; on the
# taller animal people that reads as a crouch - the thighs and shins
# brought this share of the way to straight down (the feet kept on the
# ground, see bake()).
STRAIGHTEN = 0.55


def _feet_z(arm):
    mw = arm.matrix_world
    return min((mw @ arm.pose.bones["%s_%s" % (b, s)].head).z for b in ("foot", "ball") for s in ("l", "r"))


def bake(arm, src_arm, clip, name=None, mirror=True, lift=1.0, step=1.0, straighten=STRAIGHTEN):
    """`clip` carried onto `arm` (UAL, the character bound) and keyed, one
    key a source frame (every `step` frames), from frame 1: returns the
    action. lift scales the hips' sway and drift; the legs are straightened
    (`straighten`, see STRAIGHTEN) and the hips set so the lower foot stays
    on the ground where it stands at rest."""
    act_name = action_name(src_arm, clip)
    src_act = next(a for a in bpy.data.actions if a.name.split("|")[-1] == act_name)
    s, e = src_act.frame_range
    n = max(int(round((e - s) / step)) + 1, 2)
    bones = list(MAP)
    c = retarget.Clip(src_arm, act_name, bones, n, loop=False, ref="rest")
    # The hips' motion scaled from KayKit's mannequin to the character.
    src_hips = (src_arm.matrix_world @ src_arm.data.bones["hips"].head_local).z
    tgt_hips = (arm.matrix_world @ arm.data.bones["pelvis"].head_local).z
    k = tgt_hips / max(src_hips, 1e-6) * lift
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    # Posed with no action on (it would be evaluated over the pose), the
    # poses keyed after.
    ad.action = None
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    ground = _feet_z(arm)
    down = Vector((0.0, 0.0, -1.0))
    poses = []
    for i in range(n):
        deltas, dirs, off = c.delta(i), c.dirs(i), c.offset(i)
        if mirror:
            deltas = {_other(b): _mirror_q(q) for b, q in deltas.items()}
            dirs = {_other(b): _mirror_v(v) for b, v in dirs.items()}
            off = _mirror_v(off)
        aim = {b: v for b, v in dirs.items() if b in LIMBS}
        for b in aim:
            if b.split(".")[0] in LEGS:
                aim[b] = aim[b].normalized().lerp(down, straighten).normalized()
        off = Vector((off.x * k, off.y * k, 0.0))
        retarget.apply(arm, deltas, MAP, 1.0, aim=aim, offset=off)
        off.z = ground - _feet_z(arm)
        retarget.apply(arm, deltas, MAP, 1.0, aim=aim, offset=off)
        poses.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones})
    act = bpy.data.actions.new(name or clip)
    act.use_fake_user = True
    ad.action = act
    for i, pose in enumerate(poses):
        for pb in arm.pose.bones:
            pb.location, pb.rotation_quaternion = pose[pb.name]
            pb.keyframe_insert("location", frame=i + 1)
            pb.keyframe_insert("rotation_quaternion", frame=i + 1)
    ad.action = None
    return act


# ---------------------------------------------------------------- the rig
# The player's skeleton (UAL's mannequin, its meshes dropped) and its bones
# under the names the sheet tools were written against (render_player.py,
# rod_grip.py: Mixamo's, from when they posed Mixamo's Y Bot) - kept, so
# the grip, the reel and the stance search read as before.
UAL_GLB = os.path.join(ROOT, "art_src", "player", "ual1_standard.glb")
TO_MIXAMO = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
             "neck_01": "Neck", "Head": "Head"}
for _s, _side in (("l", "Left"), ("r", "Right")):
    TO_MIXAMO.update({f"clavicle_{_s}": f"{_side}Shoulder", f"upperarm_{_s}": f"{_side}Arm",
                      f"lowerarm_{_s}": f"{_side}ForeArm", f"hand_{_s}": f"{_side}Hand",
                      f"thigh_{_s}": f"{_side}UpLeg", f"calf_{_s}": f"{_side}Leg", f"foot_{_s}": f"{_side}Foot",
                      f"ball_{_s}": f"{_side}ToeBase", f"ball_leaf_{_s}": f"{_side}Toe_End"})
    for _f in ("thumb", "index", "middle", "ring", "pinky"):
        for _i in (1, 2, 3):
            TO_MIXAMO[f"{_f}_0{_i}_{_s}"] = f"{_side}Hand{_f.capitalize()}{_i}"
        TO_MIXAMO[f"{_f}_04_leaf_{_s}"] = f"{_side}Hand{_f.capitalize()}4"
TO_MIXAMO = {k: "mixamorig:" + v for k, v in TO_MIXAMO.items()}


def load_rig(scale=1.0):
    """A fresh scene with UAL's skeleton in it (no meshes, no clips),
    scaled; returns the armature."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=UAL_GLB)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    arm.scale *= scale
    bpy.context.view_layer.update()
    return arm


def rename_to_mixamo(arm):
    """UAL's bone names to TO_MIXAMO's - the skin's groups follow, and the
    actions' channels are moved over."""
    for b in arm.data.bones:
        if b.name in TO_MIXAMO:
            b.name = TO_MIXAMO[b.name]
    for o in bpy.data.objects:
        if o.type == "MESH":
            for g in o.vertex_groups:
                if g.name in TO_MIXAMO:
                    g.name = TO_MIXAMO[g.name]
    for act in bpy.data.actions:
        for fc in act.fcurves:
            path = fc.data_path
            if path.startswith('pose.bones["'):
                name = path.split('"')[1]
                if name in TO_MIXAMO:
                    fc.data_path = path.replace('"%s"' % name, '"%s"' % TO_MIXAMO[name], 1)
        for g in act.groups:
            if g.name in TO_MIXAMO:
                g.name = TO_MIXAMO[g.name]
