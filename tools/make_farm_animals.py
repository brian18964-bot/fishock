"""The villages' animals, made from the user's uploads (user request: "綿羊、烏鴉、雞的動畫" - the
sheep, the crow and the chickens; and the calf the user sent for the cows - "素材都要經過你再製，成為
我們的資產": the uploads are never committed, only what this makes).

None of them came with a single clip - the sheep and the crow have their rigs (no moves), the chickens
and the calf not even that. Every move here is ours, keyed bone by bone (each turn about an axis of
the world - across the body, up, along it - whatever way the upload's bones lie), loops the game
plays by how fast the animal goes (RunView3D: Idle; Walk at 0.9 x its height a second at rate 1;
Run at 2.6 x):

  sheep    the ram (its 71-bone rig): Idle - it stands, looks about, puts its head down and grazes;
           Walk - a four-beat walk; Run - a trot. Its picture toned ours (the wool creamier).
  crow     the crow (its Bip rig, wings spread): its wings folded to its sides; Idle - it looks about
           and pecks at the ground; Walk - it hops; Run - it flies off low, flapping. Its picture
           the plain crow's (not the three-eyed raven's), toned ours.
  chicken  the hen, and rooster the cock (one upload, three birds - no rig): a rig of ours (body,
           neck, head, tail, legs, wings), skinned by the bones' reach; Idle - it looks about and
           pecks; Walk - the head bobbing as it steps; Run - running, wings half out.
  calf     the calf (no rig): a four-legged rig of ours fitted to it (legs found where they meet
           the ground), skinned the same way; Idle (grazing), Walk, Run as the sheep's.

Each stood facing -Y (the game's +Z) on z = 0, sized (HIGH m tall), brought down to its triangles,
into assets/models/run3d/<name>.glb.

  bpyenv/bin/python tools/make_farm_animals.py -- ram=ram.Fbx crow=CROW.blend chickens=Chickens.fbx \
      calf=calf.fbx calf_tex=texture_0.png
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RUN3D = os.path.join(ROOT, "assets", "models", "run3d")
ARGS = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:])
ONLY = [s for s in os.environ.get("ONLY", "").split(",") if s]
OUT = os.environ.get("OUT", RUN3D)

FPS = 24
# Each animal: its height (m), its most triangles, its picture's size (px).
HIGH = {"sheep": 0.95, "crow": 0.42, "chicken": 0.42, "rooster": 0.55, "calf": 1.15}
TRIS = {"sheep": 5000, "crow": 3000, "chicken": 2500, "rooster": 2500, "calf": 5000}
PICTURE = 512
# (the game's paces: a walk covers WALK_PACE x its height a second at rate 1, a run RUN_PACE x)
WALK_PACE = 0.9
RUN_PACE = 2.6
X = Vector((1.0, 0.0, 0.0))
Y = Vector((0.0, 1.0, 0.0))
Z = Vector((0.0, 0.0, 1.0))


# ------------------------------------------------------------------ the common steps

def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")
    bpy.context.scene.render.fps = FPS


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def bring_down(o, most):
    """Down to about `most` triangles - ahead of its armature, so its weights carry over - a pass at a
    time (a pass stops short at seams)."""
    bpy.context.view_layer.objects.active = o
    for _ in range(4):
        n = tris([o])
        if n <= most * 1.08:
            return
        mod = o.modifiers.new("budget", "DECIMATE")
        mod.ratio = most / n
        while o.modifiers.find("budget") > 0:
            bpy.ops.object.modifier_move_up(modifier="budget")
        bpy.ops.object.modifier_apply(modifier="budget")


def stand(arm, body, high):
    """The armature and its skin brought to `high` m tall, its feet on z = 0, its middle over the
    origin, every transform applied (the rig's bones and the skin's points in metres)."""
    bpy.context.view_layer.update()
    pts = np.array([(body.matrix_world @ v.co)[:] for v in body.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    k = high / (hi[2] - lo[2])
    shift = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    top = arm if arm is not None else body
    top.matrix_world = Matrix.Translation(shift * k) @ Matrix.Scale(k, 4) @ top.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for o in (arm, body):
        if o is not None:
            o.select_set(True)
    bpy.context.view_layer.objects.active = top
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def toned(img, out, grade):
    """Our picture from the upload's (`img` a Blender image): `grade` (an rgb array -> rgb array)
    over it, PICTURE px, saved to `out`."""
    from PIL import Image
    img.scale(PICTURE, PICTURE)
    px = np.empty(PICTURE * PICTURE * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    a = px.reshape(PICTURE, PICTURE, 4)[::-1]
    rgb = grade(a[..., :3])
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(out, quality=88)
    return out


def dress(o, name, picture):
    """One material of ours on `o`: its picture."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(picture)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(m)


def export(name):
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_apply=False, export_yup=True,
                              export_lights=False, export_cameras=False, export_image_format="JPEG",
                              export_jpeg_quality=85)
    print("built", name, tris(meshes()), "tris", os.path.getsize(path) // 1024, "KB", flush=True)


# ------------------------------------------------------------------ keying the moves

class Keys:
    """Moves keyed on `arm`'s bones as turns about axes of the world (and shifts along them), so a
    move reads the same whatever way the upload's bones were laid."""

    def __init__(self, arm):
        self.arm = arm
        self.inv = arm.matrix_world.to_3x3().normalized().inverted()

    def turn(self, bone, axis, angle):
        b = self.arm.data.bones[bone]
        local = b.matrix_local.to_3x3().inverted() @ (self.inv @ axis)
        return Quaternion(local.normalized(), angle)

    def shift(self, bone, by):
        b = self.arm.data.bones[bone]
        return b.matrix_local.to_3x3().inverted() @ (self.inv @ by) / max(self.arm.matrix_world.to_scale()[0], 1e-6)

    def action(self, name, seconds, pose):
        """A clip `seconds` long: `pose(t)` (t 0..1 through it) -> {bone: ([(axis, angle)...], shift)};
        keyed every other frame, the last as the first (it loops)."""
        arm = self.arm
        act = bpy.data.actions.new(name)
        arm.animation_data_create()
        arm.animation_data.action = act
        frames = max(2, int(round(seconds * FPS)))
        used = set()
        for f in range(0, frames + 1, 2):
            t = (f % frames) / frames
            p = pose(t)
            for pb in arm.pose.bones:
                pb.rotation_mode = "QUATERNION"
                pb.rotation_quaternion = Quaternion()
                pb.location = Vector()
            for bone, (turns, by) in p.items():
                if bone not in arm.pose.bones:
                    continue
                q = Quaternion()
                for axis, angle in turns:
                    q = self.turn(bone, axis, angle) @ q
                pb = arm.pose.bones[bone]
                pb.rotation_quaternion = q
                if by is not None:
                    pb.location = self.shift(bone, by)
                used.add(bone)
            for bone in used:
                pb = arm.pose.bones[bone]
                pb.keyframe_insert("rotation_quaternion", frame=f + 1)
                pb.keyframe_insert("location", frame=f + 1)
        act.use_fake_user = True
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, act)
        arm.animation_data.action = None
        return act


def wave(t, shift=0.0):
    return math.sin((t + shift) * math.tau)


def swing(t, shift, stance):
    """A leg's swing through a stride (t, its own phase `shift`): forward through the swing (the share
    1 - `stance`), back through the stance on the ground - -1 (back) .. 1 (forward); and how high its
    lower leg folds (0 on the ground)."""
    u = (t + shift) % 1.0
    if u < stance:
        return 1.0 - 2.0 * u / stance, 0.0
    w = (u - stance) / (1.0 - stance)
    return -1.0 + 2.0 * (0.5 - 0.5 * math.cos(w * math.pi)), math.sin(w * math.pi)


def merge(*poses):
    out = {}
    for p in poses:
        for bone, (turns, by) in p.items():
            have = out.get(bone, ([], None))
            out[bone] = (have[0] + turns, by if by is not None else have[1])
    return out


# ------------------------------------------------------------------ four legs

def quadruped_moves(keys, rig, high):
    """Idle (looking about, then head down grazing), Walk (four beats) and Run (a trot) for a
    four-legged rig: `rig` names its bones - spine (list), neck (list), head, tail (list), and each leg
    "fl", "fr", "hl", "hr" as (upper, lower, foot)."""
    leg = high * 0.55

    def legs(t, amp, fold, stance, order):
        p = {}
        for name, shift in order.items():
            up, low, foot = rig[name]
            s, f = swing(t, shift, stance)
            hind = name[0] == "h"
            # (a front leg's knee folds back, a hind leg's hock forward)
            p[up] = ([(X, -s * amp)], None)
            p[low] = ([(X, (f * fold) * (-1.0 if hind else 1.0))], None)
            p[foot] = ([(X, (f * fold * 0.6) * (1.0 if hind else -1.0))], None)
        return p

    def head_pose(nod, look, graze):
        p = {}
        n = len(rig["neck"])
        for b in rig["neck"]:
            p[b] = ([(X, graze * 1.0 / n + nod), (Z, look / n)], None)
        p[rig["head"]] = ([(X, graze * 0.35 + nod * 0.5)], None)
        return p

    def tail_pose(t, amount):
        return {b: ([(Z, wave(t, 0.1 * i) * amount)], None) for i, b in enumerate(rig["tail"])}

    def idle(t):
        # (it looks one way and the other, then lowers its head to the grass and crops it a while)
        graze = 0.0
        if 0.45 < t < 0.95:
            graze = math.sin(min((t - 0.45) / 0.1, 1.0, (0.95 - t) / 0.1) * math.pi / 2)
        look = 0.35 * math.sin(t * math.tau * 2) * (1.0 - graze)
        chew = 0.04 * math.sin(t * math.tau * 14) * graze
        breathe = {rig["spine"][0]: ([(X, 0.012 * wave(t * 3))], None)}
        return merge(head_pose(chew, look, graze * 0.95), tail_pose(t * 2, 0.15), breathe)

    walk_time = 0.8
    run_time = 0.5
    # (the stride's reach: the feet keep to the ground at the game's pace)
    walk_amp = math.asin(min(0.9, WALK_PACE * high * walk_time * 0.65 / (2.0 * leg)))
    run_amp = math.asin(min(0.9, RUN_PACE * high * run_time * 0.4 / (2.0 * leg)))

    def walk(t):
        bob = 0.012 * high * wave(t * 2)
        p = legs(t, walk_amp, 0.7, 0.65, {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75})
        p[rig["spine"][0]] = ([(Z, 0.03 * wave(t))], Vector((0.0, 0.0, bob)))
        return merge(p, head_pose(0.05 * wave(t * 2), 0.0, 0.1), tail_pose(t, 0.1))

    def run(t):
        bob = 0.03 * high * abs(wave(t))
        p = legs(t, run_amp, 1.1, 0.4, {"hl": 0.0, "fr": 0.0, "hr": 0.5, "fl": 0.5})
        p[rig["spine"][0]] = ([(X, 0.04 * wave(t * 2))], Vector((0.0, 0.0, bob)))
        return merge(p, head_pose(0.08 * wave(t * 2, 0.25), 0.0, -0.1), tail_pose(t, 0.25))

    keys.action("Idle", 6.0, idle)
    keys.action("Walk", walk_time, walk)
    keys.action("Run", run_time, run)


# ------------------------------------------------------------------ rigs of ours

def build_rig(name, spec):
    """An armature of ours: `spec` [(bone, head, tail, parent)...] (m, the animal stood facing -Y)."""
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, head, tail, parent in spec:
        eb = data.edit_bones.new(bone)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        if parent:
            eb.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin_by_proxy(body, arm, voxel):
    """Skinned to `arm` by the bones' reach - worked out on a sealed copy of it (a voxel remesh: the
    reach can't be found over an open, many-pieced skin), then handed over, each point its nearest's
    weights."""
    proxy = body.copy()
    proxy.data = body.data.copy()
    bpy.context.scene.collection.objects.link(proxy)
    rm = proxy.modifiers.new("seal", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    bpy.context.view_layer.objects.active = proxy
    bpy.ops.object.modifier_apply(modifier="seal")
    bpy.ops.object.select_all(action="DESELECT")
    proxy.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    dt = body.modifiers.new("weights", "DATA_TRANSFER")
    dt.object = proxy
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.datalayout_transfer(modifier="weights")
    while body.modifiers.find("weights") > 0:
        bpy.ops.object.modifier_move_up(modifier="weights")
    bpy.ops.object.modifier_apply(modifier="weights")
    bpy.data.objects.remove(proxy, do_unlink=True)


def own_side(body, legs):
    """A leg's weights kept to its own side (x > 0 the left): a leg standing close to its fellow
    mustn't drag the other's foot along."""
    groups = {g.index: g.name for g in body.vertex_groups}
    for v in body.data.vertices:
        if abs(v.co.x) < 1e-4:
            continue
        wrong = "_R" if v.co.x > 0.0 else "_L"
        right = "_L" if v.co.x > 0.0 else "_R"
        moves = [(groups[g.group], g.weight) for g in v.groups
                 if any(groups[g.group].startswith(l) for l in legs) and groups[g.group].endswith(wrong)]
        for name, w in moves:
            body.vertex_groups[name].remove([v.index])
            mate = body.vertex_groups.get(name[:-2] + right)
            if mate is not None:
                mate.add([v.index], w, "ADD")


def points(body):
    return np.array([v.co[:] for v in body.data.vertices])


# ------------------------------------------------------------------ the sheep

SHEEP_RIG = {"spine": ["spine_001", "spine_003", "spine_005"], "neck": ["neck_001", "neck_002", "neck_003", "neck_004"],
             "head": "head", "tail": ["tail_001", "tail_002", "tail_003"],
             "fl": ("upper_arm_L", "forearm_L", "forefoot_L"), "fr": ("upper_arm_R", "forearm_R", "forefoot_R"),
             "hl": ("thigh_L", "lower_leg_L", "hind_foot_L"), "hr": ("thigh_R", "lower_leg_R", "hind_foot_R")}


def sheep_wool(rgb):
    """The fleece creamier and softer, the face and legs left dark."""
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    rgb = rgb * 0.85 + lum[..., None] * 0.15
    return rgb * np.array([1.04, 1.0, 0.9], np.float32) * 0.96


def sheep():
    fresh()
    bpy.ops.import_scene.fbx(filepath=ARGS["ram"])
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    body = [o for o in meshes() if o.parent == arm][0]
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    arm.animation_data_clear()
    img = next(n.image for m in body.data.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    pic = toned(img, os.path.join(bpy.app.tempdir or "/tmp", "sheep_wool.jpg"), sheep_wool)
    stand(arm, body, HIGH["sheep"])
    bring_down(body, TRIS["sheep"])
    dress(body, "sheep_wool", pic)
    quadruped_moves(Keys(arm), SHEEP_RIG, HIGH["sheep"])
    export("sheep")


# ------------------------------------------------------------------ the crow

CROW_WINGS = {"L": ["Bip001--L-Wing01", "Bip001--L-Wing02", "Bip001--L-Wing03"],
              "R": ["Bip001--R-Wing01", "Bip001--R-Wing02", "Bip001--R-Wing03"]}
# (its wings laid back along its sides: each joint's turn about the up axis (+ swings the left wing
# back), and how far each droops - the whole wing swung back from the shoulder, barely bent: folded
# joint by joint the upload's long feathers splay out)
CROW_FOLD = [(1.3, 0.85), (-0.25, 0.1), (0.2, 0.0)]


def crow_coat(rgb):
    """The crow's plumage darker - a crow's black, its sheen a little bluish - ours."""
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    rgb = rgb * 0.7 + lum[..., None] * 0.3
    return rgb * np.array([0.5, 0.52, 0.58], np.float32)


def crow_moves(keys):
    def wings(fold, flap=0.0, lift=0.0):
        """Folded (1) to spread (0); flapping by `flap` (rad, + up)."""
        p = {}
        for side, sign in (("L", 1.0), ("R", -1.0)):
            for i, b in enumerate(CROW_WINGS[side]):
                turn, droop = CROW_FOLD[i]
                # (lowered first - about the axis along the body, while the wing still points out - then
                # swung back about the up axis)
                turns = [(Y, sign * droop * fold), (Z, sign * turn * fold)]
                if i == 0:
                    turns.append((Y, -sign * (flap + lift)))
                elif i == 1:
                    turns.append((Y, -sign * flap * 0.5))
                p[b] = (turns, None)
        return p

    def body(peck=0.0, look=0.0, bob=0.0, tail=0.0):
        return {"Bip001-neck": ([(X, peck * 0.6), (Z, look * 0.5)], None),
                "Bip001-head": ([(X, peck * 0.5), (Z, look * 0.5)], None),
                "Bip001-chest": ([(X, peck * 0.35)], None),
                "Bip001-Tail": ([(X, -tail)], None),
                "Bip001": ([], Vector((0.0, 0.0, bob)))}

    def legs(a, b, fold_a=0.0, fold_b=0.0):
        return {"Bip001-L-Thigh": ([(X, -a)], None), "Bip001-R-Thigh": ([(X, -b)], None),
                "Bip001-L-Calf": ([(X, fold_a)], None), "Bip001-R-Calf": ([(X, fold_b)], None)}

    def idle(t):
        # (it looks about, then pecks at the ground twice)
        look = 0.6 * math.sin(t * math.tau * 2) if t < 0.5 else 0.0
        peck = 0.0
        if t >= 0.55:
            u = (t - 0.55) / 0.45
            peck = 1.1 * max(0.0, math.sin(u * math.tau * 2)) ** 0.6
        return merge(wings(1.0), body(peck, look, 0.0, 0.1 * peck), legs(0.0, 0.0))

    def hop(t):
        # (both feet together: crouch, spring, land - two hops a clip)
        u = (t * 2.0) % 1.0
        up = max(0.0, math.sin(u * math.pi)) * HIGH["crow"] * 0.18
        tuck = max(0.0, math.sin(u * math.pi)) * 0.5
        return merge(wings(0.95), body(0.15 * math.cos(u * math.tau), 0.0, up, 0.15), legs(0.2 - tuck, 0.2 - tuck, tuck, tuck))

    def fly(t):
        # (off the ground, its legs tucked, flapping)
        flap = 0.75 * math.sin(t * math.tau * 2)
        return merge(wings(0.0, flap, 0.1), body(-0.2, 0.0, HIGH["crow"] * 1.6 + 0.05 * math.sin(t * math.tau * 2 + 1.0), -0.1),
                     legs(-0.9, -0.9, 0.8, 0.8))

    keys.action("Idle", 4.0, idle)
    keys.action("Walk", 0.7, hop)
    keys.action("Run", 0.5, fly)


def crow():
    fresh()
    path = ARGS["crow"]
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in ("SKM_Crow", "SKM_Crow.001")]
    for o in dst.objects:
        bpy.context.scene.collection.objects.link(o)
    arm = bpy.data.objects["SKM_Crow"]
    body = bpy.data.objects["SKM_Crow.001"]
    arm.animation_data_clear()
    # (the plain crow's picture - not the three-eyed raven's - beside the upload)
    img = bpy.data.images.load(os.path.join(os.path.dirname(path), "T_Crow_D.dds"))
    pic = toned(img, os.path.join(bpy.app.tempdir or "/tmp", "crow_coat.jpg"), crow_coat)
    stand(arm, body, 1.0)
    # (its height as it stands, wings folded - the spread wings' tips set aside)
    bpy.context.view_layer.update()
    k = HIGH["crow"] / max(v.co.z for v in body.data.vertices)
    arm.matrix_world = Matrix.Scale(k, 4) @ arm.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bring_down(body, TRIS["crow"])
    dress(body, "crow_coat", pic)
    crow_moves(Keys(arm))
    export("crow")


# ------------------------------------------------------------------ the chickens

# Which of the upload's three birds (its materials: mat_0 the white hen, mat_1 the cock, mat_2 the brown
# hen, mat_3 the chick) each of ours is.
CHICKENS = {"chicken": "mat_2", "rooster": "mat_1"}


def bird_rig(body, name):
    """Our bird's rig, from where its parts are: its legs where it meets the ground (left and right),
    its head the top of its front, its tail the top of its back."""
    pts = points(body)
    lo, hi = pts.min(0), pts.max(0)
    h = hi[2]
    length = hi[1] - lo[1]
    low = pts[pts[:, 2] < 0.15 * h]
    left = low[low[:, 0] > 0.0]
    right = low[low[:, 0] <= 0.0]
    lx = float(left[:, 0].mean()) if len(left) else 0.03 * h
    rx = float(right[:, 0].mean()) if len(right) else -0.03 * h
    fy = float(low[:, 1].mean()) if len(low) else 0.0
    front = pts[pts[:, 1] < lo[1] + 0.35 * length]
    head = front[front[:, 2] > front[:, 2].max() - 0.18 * h].mean(0)
    back = pts[pts[:, 1] > hi[1] - 0.3 * length]
    tail = back[back[:, 2] > back[:, 2].max() - 0.15 * h].mean(0)
    hip = (0.0, fy + 0.05 * length, 0.45 * h)
    chest = (0.0, fy - 0.15 * length, 0.5 * h)
    neck = (0.0, head[1] + 0.12 * length, 0.62 * h)
    w = max(lx - rx, 0.08 * h)
    spec = [("root", (0, fy, 0), (0, fy, 0.2 * h), None),
            ("body", hip, chest, "root"),
            ("neck", chest, neck, "body"),
            ("head", neck, tuple(head), "neck"),
            ("tail", (0.0, hip[1] + 0.08 * length, 0.5 * h), tuple(tail), "body")]
    for side, x in (("L", lx), ("R", rx)):
        spec += [("thigh_" + side, (x * 0.8, fy + 0.03 * length, 0.42 * h), (x, fy, 0.22 * h), "body"),
                 ("shin_" + side, (x, fy, 0.22 * h), (x, fy, 0.05 * h), "thigh_" + side),
                 ("foot_" + side, (x, fy, 0.05 * h), (x, fy - 0.12 * length, 0.0), "shin_" + side),
                 ("wing_" + side, (x * 1.6 if x * 1.6 else 0.3 * w, chest[1], 0.6 * h),
                  (x * 1.7, hip[1] + 0.2 * length, 0.55 * h), "body")]
    return build_rig(name + "_rig", spec)


def bird_moves(keys, high, run_wings=0.6):
    def legs(a, b, fold_a, fold_b):
        return {"thigh_L": ([(X, -a)], None), "thigh_R": ([(X, -b)], None),
                "shin_L": ([(X, fold_a)], None), "shin_R": ([(X, fold_b)], None),
                "foot_L": ([(X, -fold_a * 0.8)], None), "foot_R": ([(X, -fold_b * 0.8)], None)}

    def upper(peck=0.0, look=0.0, thrust=0.0, lean=0.0, bob=0.0, tail=0.0, wings=0.0, flap=0.0):
        return {"root": ([], Vector((0.0, 0.0, bob))),
                "body": ([(X, lean + peck * 0.45)], None),
                "neck": ([(X, peck * 0.7 + thrust), (Z, look * 0.6)], None),
                "head": ([(X, peck * 0.3 - thrust), (Z, look * 0.4)], None),
                "tail": ([(X, -tail)], None),
                "wing_L": ([(Y, -(wings + flap)), (Z, -wings * 0.4)], None),
                "wing_R": ([(Y, wings + flap), (Z, wings * 0.4)], None)}

    def idle(t):
        # (it looks about, then pecks at the ground twice, its tail flicking)
        look = 0.7 * math.sin(t * math.tau * 2) if t < 0.5 else 0.0
        peck = 0.0
        if t >= 0.5:
            peck = 1.0 * max(0.0, math.sin((t - 0.5) / 0.5 * math.tau * 2)) ** 0.5
        return merge(upper(peck, look, 0.0, 0.0, 0.0, 0.15 * math.sin(t * math.tau * 3)), legs(0.0, 0.0, 0.0, 0.0))

    step = 0.6
    reach = math.asin(min(0.8, WALK_PACE * high * step * 0.5 / (2.0 * 0.4 * high)))

    def walk(t):
        a, fa = swing(t, 0.0, 0.5)
        b, fb = swing(t, 0.5, 0.5)
        # (the head held still, then thrust on - twice a stride)
        thrust = 0.25 * (((t * 2.0) % 1.0) - 0.5)
        return merge(upper(0.0, 0.0, thrust, 0.08, 0.02 * high * abs(wave(t)), 0.05), legs(a * reach, b * reach, fa * 0.9, fb * 0.9))

    def run(t):
        a, fa = swing(t, 0.0, 0.45)
        b, fb = swing(t, 0.5, 0.45)
        return merge(upper(0.0, 0.0, 0.0, 0.35, 0.05 * high * abs(wave(t)), -0.1, run_wings, 0.5 * wave(t * 2)),
                     legs(a * reach * 1.4, b * reach * 1.4, fa * 1.2, fb * 1.2))

    keys.action("Idle", 4.0, idle)
    keys.action("Walk", step, walk)
    keys.action("Run", 0.36, run)


def chicken_coat(rgb):
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    return (rgb * 0.88 + lum[..., None] * 0.12) * np.array([1.02, 1.0, 0.94], np.float32)


def chickens(which):
    fresh()
    bpy.ops.import_scene.fbx(filepath=ARGS["chickens"])
    src = meshes()[0]
    mat = CHICKENS[which]
    # (only this bird: the upload's others cut away)
    keep = src.data.materials.find(mat)
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != keep], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(src.data)
    bm.free()
    img = next(n.image for n in src.data.materials[keep].node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    pic = toned(img, os.path.join(bpy.app.tempdir or "/tmp", which + "_coat.jpg"), chicken_coat)
    src.name = which
    stand(None, src, HIGH[which])
    bring_down(src, TRIS[which])
    dress(src, which + "_coat", pic)
    arm = bird_rig(src, which)
    skin_by_proxy(src, arm, HIGH[which] * 0.03)
    own_side(src, ["thigh", "shin", "foot", "wing"])
    bird_moves(Keys(arm), HIGH[which])
    export(which)


# ------------------------------------------------------------------ the calf

def calf_rig(body):
    """Our four-legged rig on the calf: its legs where they meet the ground (front and back, left and
    right), its spine along its back, its neck up to its head (the top of its front), its tail."""
    pts = points(body)
    lo, hi = pts.min(0), pts.max(0)
    h = hi[2]
    length = hi[1] - lo[1]
    low = pts[pts[:, 2] < 0.1 * h]
    mid_y = (lo[1] + hi[1]) / 2
    feet = {}
    for name, fy, sx in (("fl", -1, 1), ("fr", -1, -1), ("hl", 1, 1), ("hr", 1, -1)):
        q = low[((low[:, 1] - mid_y) * fy > 0) & (low[:, 0] * sx > 0)]
        feet[name] = q.mean(0) if len(q) else np.array([sx * 0.1 * h, mid_y + fy * 0.3 * length, 0.0])
    front = pts[pts[:, 1] < lo[1] + 0.25 * length]
    head = front[front[:, 2] > front[:, 2].max() - 0.15 * h].mean(0)
    snout = front[front[:, 1] < front[:, 1].min() + 0.05 * length].mean(0)
    back_y = (feet["hl"][1] + feet["hr"][1]) / 2
    fore_y = (feet["fl"][1] + feet["fr"][1]) / 2
    top = 0.68 * h
    spec = [("root", (0, mid_y, 0), (0, mid_y, 0.3 * h), None),
            ("spine_1", (0, back_y, top), (0, mid_y, top), "root"),
            ("spine_2", (0, mid_y, top), (0, fore_y, top * 1.02), "spine_1"),
            ("neck_1", (0, fore_y, top * 1.02), (0, (fore_y + head[1]) / 2, (top + head[2]) / 2), "spine_2"),
            ("neck_2", (0, (fore_y + head[1]) / 2, (top + head[2]) / 2), tuple(head), "neck_1"),
            ("head", tuple(head), tuple(snout), "neck_2"),
            ("tail_1", (0, back_y + 0.04 * length, top), (0, hi[1], top * 0.75), "spine_1"),
            ("tail_2", (0, hi[1], top * 0.75), (0, hi[1] + 0.02 * length, top * 0.35), "tail_1")]
    for name, side in (("fl", "L"), ("fr", "R"), ("hl", "L"), ("hr", "R")):
        x, y = float(feet[name][0]), float(feet[name][1])
        part = "fore" if name[0] == "f" else "hind"
        parent = "spine_2" if name[0] == "f" else "spine_1"
        spec += [("%s_up_%s" % (part, side), (x, y, 0.62 * h), (x, y, 0.33 * h), parent),
                 ("%s_low_%s" % (part, side), (x, y, 0.33 * h), (x, y, 0.1 * h), "%s_up_%s" % (part, side)),
                 ("%s_foot_%s" % (part, side), (x, y, 0.1 * h), (x, y - 0.03 * length, 0.0), "%s_low_%s" % (part, side))]
    return build_rig("calf_rig", spec)


CALF_RIG = {"spine": ["spine_1", "spine_2"], "neck": ["neck_1", "neck_2"], "head": "head", "tail": ["tail_1", "tail_2"],
            "fl": ("fore_up_L", "fore_low_L", "fore_foot_L"), "fr": ("fore_up_R", "fore_low_R", "fore_foot_R"),
            "hl": ("hind_up_L", "hind_low_L", "hind_foot_L"), "hr": ("hind_up_R", "hind_low_R", "hind_foot_R")}


def calf_coat(rgb):
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    return (rgb * 0.9 + lum[..., None] * 0.1) * np.array([1.0, 0.98, 0.93], np.float32)


def calf():
    fresh()
    bpy.ops.import_scene.fbx(filepath=ARGS["calf"])
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    body = meshes()[0]
    bpy.context.view_layer.update()
    # (it came lying along x: turned to face -Y - its head the end with the top of it)
    pts = np.array([(body.matrix_world @ v.co)[:] for v in body.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    head_x = 1.0 if pts[pts[:, 2] > hi[2] - 0.05 * (hi[2] - lo[2])][:, 0].mean() > (lo[0] + hi[0]) / 2 else -1.0
    body.matrix_world = Matrix.Rotation(-math.pi / 2 * head_x, 4, "Z") @ body.matrix_world
    img = bpy.data.images.load(ARGS["calf_tex"])
    pic = toned(img, os.path.join(bpy.app.tempdir or "/tmp", "calf_coat.jpg"), calf_coat)
    stand(None, body, HIGH["calf"])
    bring_down(body, TRIS["calf"])
    dress(body, "calf_coat", pic)
    arm = calf_rig(body)
    skin_by_proxy(body, arm, HIGH["calf"] * 0.025)
    own_side(body, ["fore_", "hind_"])
    quadruped_moves(Keys(arm), CALF_RIG, HIGH["calf"])
    export("calf")


STEPS = [("sheep", sheep), ("crow", crow), ("chicken", lambda: chickens("chicken")),
         ("rooster", lambda: chickens("rooster")), ("calf", calf)]
for key, step in STEPS:
    if ONLY and key not in ONLY:
        continue
    step()
