"""The desert's animals, from the user's second "Des" batch - none used as it came, each made ours.

User request: "又幫你找了一些，也是一樣不要直接使用，修改後變成我們的資產" (more found for you -
again not to be used directly: changed, to become our assets). The pack stays out of the repo;
this makes ours from it, into assets/models/run3d/ (the 3D run's creatures, as
tools/build_run3d_models.py's: facing -Y here, +Z in Godot, stood at the origin, only the clips the
run uses - Idle / Walk / Run / Attack / Eat):

  hyena     the hyena (Hyenas_A4_AllMotion.Fbx, Textures_A4): brought down from 34k triangles,
            its coat regraded to a paler, sandier hide (its fur fringe cut out by its opacity
            map, folded into the picture's alpha); its idle, walk, run and first attack kept, the
            walk and the run retimed so its feet keep to the ground at the game's paces
            (RunView3D: a walk covers 0.9 x its height a second at rate 1, a run 2.6 x).

  bpyenv/bin/python tools/make_desert_animals.py -- PACK_DIR [name ...]

PACK_DIR holds the batch's archives unpacked (found by file name anywhere under it).
"""
import math
import os
import sys
import tempfile

import bpy
from mathutils import Vector
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
RUN3D = os.path.join(ROOT, "assets", "models", "run3d")
TMP = os.path.join(tempfile.gettempdir(), "desert_animals")


def find(pack, name):
    for base, _dirs, files in os.walk(pack):
        for f in files:
            if f.lower() == name.lower():
                return os.path.join(base, f)
    raise FileNotFoundError(name)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.use_scripts_auto_execute = False


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def tris(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in objs:
        m = o.evaluated_get(dg).to_mesh()
        m.calc_loop_triangles()
        n += len(m.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    return n


def decimate(o, ratio):
    """Collapsed to `ratio` of its triangles - applied ahead of its armature, so the weights carry
    over."""
    mod = o.modifiers.new("budget", "DECIMATE")
    mod.ratio = ratio
    bpy.context.view_layer.objects.active = o
    while o.modifiers.find("budget") > 0:
        bpy.ops.object.modifier_move_up(modifier="budget")
    bpy.ops.object.modifier_apply(modifier="budget")


def bring_down(o, budget, passes=4):
    """Down to about `budget` triangles - pass after pass (a pass stops short at seams and edges)."""
    for _ in range(passes):
        n = tris([o])
        if n <= budget * 1.08:
            break
        decimate(o, budget / n)


def skin_by_proxy(body, arm, voxel):
    """Skinned to `arm` by the bones' reach - worked out on a sealed copy of it (a voxel remesh: the
    reach can't be found over an open, many-pieced skin), then handed over to it, each vertex its
    nearest point's weights."""
    proxy = body.copy()
    proxy.data = body.data.copy()
    bpy.context.collection.objects.link(proxy)
    for md in list(proxy.modifiers):
        proxy.modifiers.remove(md)
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


def attach(body, arm):
    """`body`, its weights by bone name already on it, skinned to `arm` (whatever rig they were
    worked out on)."""
    for md in list(body.modifiers):
        if md.type == "ARMATURE":
            body.modifiers.remove(md)
    mw = body.matrix_world.copy()
    body.parent = arm
    body.matrix_world = mw
    md = body.modifiers.new("rig", "ARMATURE")
    md.object = arm


def weight_rig(arm, reach):
    """A copy of `arm` for working the skin's weights out on: its bones the same, each reaching on
    to `reach[name]` (a point, m) - the alpaca's own are mere points, which would leave the skin
    near any of them to it (the belly to the legs)."""
    rig = arm.copy()
    rig.data = arm.data.copy()
    bpy.context.collection.objects.link(rig)
    rig.animation_data_clear()
    inv = rig.matrix_world.inverted()
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        if eb.name in reach:
            eb.tail = inv @ Vector(reach[eb.name])
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def own_side(body, prefixes):
    """Each leg's weights kept to its own side of the body (x > 0 the left): a leg standing close
    to its fellow mustn't drag the other's hoof along - a weight on the far side's bone moved to
    its own side's."""
    groups = {g.index: g.name for g in body.vertex_groups}
    for v in body.data.vertices:
        if abs(v.co.x) < 0.02:
            continue
        wrong = ".R" if v.co.x > 0.0 else ".L"
        right = ".L" if v.co.x > 0.0 else ".R"
        moves = [(groups[g.group], g.weight) for g in v.groups
                 if groups[g.group].startswith(prefixes) and groups[g.group].endswith(wrong)]
        for name, w in moves:
            body.vertex_groups[name].remove([v.index])
            mate = body.vertex_groups.get(name[:-2] + right)
            if mate is not None:
                mate.add([v.index], w, "ADD")


def keep_near(body, rig, legs, radius, spine):
    """A leg's bones bend only the skin about the leg (within `radius` m of its bones): the belly
    and the chest past it go with the spine (the nearest of `spine`), not with the leg."""
    from mathutils.geometry import intersect_point_line

    def seg(name):
        b = rig.data.bones[name]
        return rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local

    def dist(p, a, b):
        q, t = intersect_point_line(p, a, b)
        t = min(max(t, 0.0), 1.0)
        return (p - (a + (b - a) * t)).length

    segs = {b.name: seg(b.name) for b in rig.data.bones}
    groups = {g.index: g.name for g in body.vertex_groups}
    mw = body.matrix_world
    for v in body.data.vertices:
        p = mw @ v.co
        cut = 0.0
        gone = []
        for g in list(v.groups):
            name = groups[g.group]
            if name.startswith(legs) and name in segs and dist(p, *segs[name]) > radius:
                cut += g.weight
                gone.append(name)
                body.vertex_groups[name].remove([v.index])
        if cut > 0.0:
            # (to the nearest of the rest: the spine for the belly, its own lower leg for a hoof)
            rest = [n for n in segs if n not in gone and body.vertex_groups.get(n) is not None
                    and rig.data.bones[n].use_deform and (n in spine or n.startswith(legs))]
            near = min(rest, key=lambda n: dist(p, *segs[n]))
            body.vertex_groups[near].add([v.index], cut, "ADD")


def bake_down(hi, lo, out_color, out_normal, size, normal_size, grade=None):
    """`lo` given our own picture: unwrapped afresh, and the colour (and the surface's relief, as a
    normal map) of `hi` - the full model, its own picture on it - baked onto it."""
    from PIL import Image
    bpy.context.view_layer.objects.active = lo
    bpy.ops.object.select_all(action="DESELECT")
    lo.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = True
    sc.render.bake.cage_extrusion = 0.03
    sc.render.bake.max_ray_distance = 0.08
    m = bpy.data.materials.new("bake")
    m.use_nodes = True
    lo.data.materials.clear()
    lo.data.materials.append(m)
    node = m.node_tree.nodes.new("ShaderNodeTexImage")
    m.node_tree.nodes.active = node
    results = []
    for kind, path, px in (("DIFFUSE", out_color, size), ("NORMAL", out_normal, normal_size)):
        img = bpy.data.images.new("bake_" + kind, px, px)
        if kind == "NORMAL":
            img.colorspace_settings.name = "Non-Color"
        node.image = img
        bpy.ops.object.select_all(action="DESELECT")
        hi.select_set(True)
        lo.select_set(True)
        bpy.context.view_layer.objects.active = lo
        if kind == "DIFFUSE":
            sc.render.bake.use_pass_direct = False
            sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
            bpy.ops.object.bake(type="DIFFUSE", margin=6)
        else:
            bpy.ops.object.bake(type="NORMAL", margin=6, normal_space="TANGENT")
        raw = os.path.join(TMP, "bake_%s.png" % kind)
        img.filepath_raw = raw
        img.file_format = "PNG"
        img.save()
        im = Image.open(raw).convert("RGB")
        if kind == "DIFFUSE" and grade is not None:
            a = grade(np.asarray(im).astype(np.float32) / 255.0)
            im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
        im.save(path, quality=88, optimize=True)
        results.append(path)
    lo.data.materials.clear()
    return results


def keep_actions(names):
    """Only these actions (source name -> game clip), renamed; nothing left playing, so each is
    exported as a clip of its own."""
    keep = {}
    for a in bpy.data.actions:
        for src, game in names.items():
            # (one each: a glTF may hold an action twice, under its object's name and its own)
            if a.name.endswith(src) and game not in keep.values():
                keep[a] = game
    for a in list(bpy.data.actions):
        if a not in keep:
            bpy.data.actions.remove(a)
    for a, game in keep.items():
        a.name = game
        a.use_fake_user = True
        # (an action never yet played on an object has no kind - the exporter would pass it by)
        a.id_root = "OBJECT"
    for o in bpy.data.objects:
        if o.animation_data is not None:
            o.animation_data.action = None
            for t in list(o.animation_data.nla_tracks):
                o.animation_data.nla_tracks.remove(t)
    return {game: a for a, game in keep.items()}


def retime(act, k):
    """The action played `k` times as long (its keys and their handles moved)."""
    start = act.frame_range[0]
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            for attr in ("co", "handle_left", "handle_right"):
                v = getattr(kp, attr)
                v.x = start + (v.x - start) * k
        fc.update()


def ground_speed(arm, act, feet, down=0.02):
    """How fast (m/s, world) the ground goes by under its feet in this in-place clip: the way each
    foot slides back while it's down (within `down` m of its lowest), over all its frames down."""
    sc = bpy.context.scene
    arm.animation_data_create()
    arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    track = {i: [] for i in range(len(feet))}
    for fr in range(f0, f1 + 1):
        sc.frame_set(fr)
        for i, f in enumerate(feet):
            if isinstance(f, str):
                at = arm.pose.bones[f].head
            else:
                # (a point carried by a bone: given where it is at rest, in the rig's space)
                pb = arm.pose.bones[f[0]]
                at = pb.matrix @ (pb.bone.matrix_local.inverted() @ f[1])
            track[i].append((arm.matrix_world @ at).copy())
    arm.animation_data.action = None
    fps = sc.render.fps / sc.render.fps_base
    way = 0.0
    frames = 0
    for f, ps in track.items():
        low = min(p.z for p in ps)
        for a, b in zip(ps, ps[1:]):
            # (a foot down both frames, sliding back - not the jump from one end of the clip to the other)
            if a.z < low + down and b.z < low + down and abs(b.y - a.y) < 0.25 * (1.0 + down * 10.0):
                way += abs(b.y - a.y)
                frames += 1
    return way / frames * fps if frames else 0.0


def height(objs):
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    return max(zs) - min(zs)


def picture(src, out, size, grade=None, alpha=None, quality=88):
    """A source picture made ours: graded (grade(rgb array 0..1) -> rgb), brought to `size`,
    and - with `alpha` (a picture, white kept) - its alpha set (PNG), else a JPG."""
    from PIL import Image
    im = Image.open(src).convert("RGB").resize((size, size), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    if grade is not None:
        a = grade(a)
    rgb = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    if alpha is not None:
        al = Image.open(alpha).convert("L").resize((size, size), Image.LANCZOS)
        rgb.putalpha(al)
        rgb.save(out, optimize=True)
    else:
        rgb.save(out, quality=quality, optimize=True)
    return out


def hsv(a):
    mx = a.max(-1)
    mn = a.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = d > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6.0
    h[gg] = (b - r)[gg] / d[gg] + 2.0
    h[bb] = (r - g)[bb] / d[bb] + 4.0
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return h, s, mx


def from_hsv(h, s, v):
    i = np.floor(h * 6.0) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p = v * (1 - s)
    q = v * (1 - s * f)
    t = v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,), np.float32)
    for k, (x, y, z) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        sel = i == k
        out[..., 0][sel] = x[sel]
        out[..., 1][sel] = y[sel]
        out[..., 2][sel] = z[sel]
    return out


def textured(o, name, color, normal=None, cut=False):
    """One material of our own on `o`: its picture (and its normal map), cut out by its alpha."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(color)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if cut:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
    if normal is not None:
        nt_img = nt.nodes.new("ShaderNodeTexImage")
        nt_img.image = bpy.data.images.load(normal)
        nt_img.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nt_img.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    o.data.materials.clear()
    o.data.materials.append(m)


def export(name):
    path = os.path.join(RUN3D, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_apply=False, export_yup=True,
                              export_lights=False, export_cameras=False, export_image_format="AUTO")
    print("built", name, tris(meshes()), "tris", os.path.getsize(path) // 1024, "KB", flush=True)


# ------------------------------------------------------------------ the hyena

HYENA_TRIS = 6000
HYENA_CLIPS = {"_Idle": "Idle", "_Walk": "Walk", "_Run": "Run", "_Atk": "Attack"}
HYENA_FEET = ["bip01_l_toe0", "bip01_r_toe0", "bip01_l_finger0", "bip01_r_finger0"]


def hyena_coat(a):
    """The hide paler and sandier - a desert hyena's - its spots kept, its mouth's reds left."""
    h, s, v = hsv(a)
    fur = (h > 0.03) & (h < 0.16)
    h2 = np.where(fur, h + (0.095 - h) * 0.45, h)
    s2 = np.where(fur, s * 0.72, s)
    v2 = np.where(fur, np.clip(v * 1.18 + 0.03, 0, 1), v)
    return from_hsv(h2, s2, v2)


def hyena(pack):
    fresh()
    bpy.ops.import_scene.fbx(filepath=find(pack, "Hyenas_A4_AllMotion.Fbx"))
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    body = [o for o in meshes() if o.parent == arm][0]
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    clips = keep_actions(HYENA_CLIPS)
    decimate(body, HYENA_TRIS / tris([body]))
    # (its feet kept to the ground: each gait's clip retimed to the game's pace for it)
    tall = height([body])
    for clip, pace in (("Walk", 0.9), ("Run", 2.6)):
        v = ground_speed(arm, clips[clip], HYENA_FEET)
        k = v / (pace * tall) if v > 0 else 1.0
        retime(clips[clip], k)
        print("hyena %s: %.2f m/s at its own time, %.2f wanted - x%.2f" % (clip, v, pace * tall, k), flush=True)
    os.makedirs(TMP, exist_ok=True)
    coat = picture(find(pack, "Hyenas_A4.png"), os.path.join(TMP, "hyena_coat.png"), 1024, hyena_coat,
                   alpha=find(pack, "Hyenas_A_Opacity1.png"))
    nrm = picture(find(pack, "Hyenas_A4_Normal.png"), os.path.join(TMP, "hyena_normal.jpg"), 512)
    textured(body, "hyena_coat", coat, nrm, cut=True)
    export("hyena")


# ------------------------------------------------------------------ the camel

ALPACA = os.path.join(ROOT, "art_src", "animal", "alpaca.glb")
CAMEL_TRIS = 8000
CAMEL_VOXEL = 0.011
CAMEL_CLIPS = {"Idle_AnimalArmature": "Idle", "Walk_AnimalArmature": "Walk", "Gallop_AnimalArmature": "Run",
}
# The alpaca's rig (Quaternius', art_src/animal) on the camel: its size first (CAMEL_RIG_SCALE of
# the alpaca's), then each bone moved - its way and roll kept, so the alpaca's clips turn it as they
# turned the alpaca - to the camel's own joint (m, the camel stood facing -Y, its feet at z 0, read
# off a measured side view): the hoof, knee and elbow of the forelegs; the hip, stifle and hock
# behind; the spine under the humps; the neck down from the withers to its dip and up to the
# skull; the tail.
CAMEL_RIG_SCALE = 0.62
CAMEL_JOINTS = {
    "Body": (0.0, 0.35, 0.95),
    "Back": (0.0, 1.15, 1.85), "Torso": (0.0, 0.65, 1.78), "Torso2": (0.0, 0.1, 1.74), "Torso3": (0.0, -0.4, 1.76),
    "Neck1": (0.0, -0.55, 1.86), "Neck2": (0.0, -0.83, 1.70), "Neck3": (0.0, -0.93, 2.05), "Head": (0.0, -1.0, 2.33),
    "Ear1.L": (0.1, -0.97, 2.55), "Ear2.L": (0.13, -0.96, 2.6), "Ear3.L": (0.15, -0.95, 2.64), "Ear4.L": (0.17, -0.94, 2.68),
    "FrontShoulder.L": (0.13, -0.3, 1.72), "FrontUpperLeg.L": (0.17, -0.22, 1.35), "FrontLowerLeg.L": (0.17, -0.16, 0.6),
    "IKFrontLeg.L": (0.16, -0.2, 0.25), "FF.L": (0.16, -0.21, 0.08),
    "BackShoulder.L": (0.17, 1.0, 1.82), "BackLeg.L": (0.24, 1.02, 1.74), "BackUpperLeg.L": (0.27, 0.95, 1.25),
    "BackLowerLeg.L": (0.28, 1.2, 0.63), "IKBackLeg.L": (0.28, 0.98, 0.25), "FFB.L": (0.28, 0.94, 0.08),
    "Tail1": (0.0, 1.3, 1.8), "Tail2": (0.0, 1.42, 1.55), "Tail3": (0.0, 1.46, 1.25),
}
# (what doesn't bend the skin: the alpaca's IK handles and its hooves' bones - the hooves ride on the
# lower legs, so a longer leg than the alpaca's carries them without stretching)
CAMEL_NO_DEFORM = ("IK", "PoleTarget", "FF", "Hoof", "Body")
# Where each bone reaches to, for the skin's weights (a joint's name, or a point): joint to joint
CAMEL_REACH = {
    "Back": "Torso", "Torso": "Torso2", "Torso2": "Torso3", "Torso3": "Neck1",
    "Neck1": "Neck2", "Neck2": "Neck3", "Neck3": "Head", "Head": (0.0, -1.45, 2.3),
    "Ear1.L": "Ear2.L", "Ear2.L": "Ear3.L", "Ear3.L": "Ear4.L", "Ear4.L": (0.2, -0.93, 2.74),
    "FrontShoulder.L": "FrontUpperLeg.L", "FrontUpperLeg.L": "FrontLowerLeg.L", "FrontLowerLeg.L": "FF.L",
    "BackShoulder.L": "BackLeg.L", "BackLeg.L": "BackUpperLeg.L", "BackUpperLeg.L": "BackLowerLeg.L",
    "BackLowerLeg.L": "FFB.L",
    "Tail1": "Tail2", "Tail2": "Tail3", "Tail3": (0.0, 1.47, 1.0),
}
CAMEL_HOOVES = [("HoofFront", "FrontLowerLeg", (0.16, -0.21, 0.04)), ("HoofBack", "BackLowerLeg", (0.28, 0.94, 0.04))]


def camel_coat(a):
    """Its coat a touch paler and drier - sun on the sands."""
    h, s, v = hsv(a)
    return from_hsv(h, s * 0.88, np.clip(v * 1.07 + 0.015, 0, 1))


def camel_pace(arm, act):
    """A camel paces: each side's legs together. The alpaca's walk is a four-beat one, its front legs a
    beat apart from its back ones - each front leg's keys shifted (round its loop) to its own side's
    back leg's beat: when each hoof is furthest forward."""
    sc = bpy.context.scene
    arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    span = f1 - f0
    def most_forward(bone):
        best, at = None, f0
        for fr in range(f0, f1):
            sc.frame_set(fr)
            y = (arm.matrix_world @ arm.pose.bones[bone].head).y
            if best is None or y < best:
                best, at = y, fr
        return at
    for side in ("L", "R"):
        shift = (most_forward("FFB." + side) - most_forward("FF." + side)) % span
        bones = ["FrontShoulder." + side, "FrontUpperLeg." + side, "FrontLowerLeg." + side, "IKFrontLeg." + side,
                 "FF." + side]
        for fc in act.fcurves:
            if not any('"%s"' % b in fc.data_path for b in bones):
                continue
            vals = [fc.evaluate(f0 + ((fr - f0 - shift) % span)) for fr in range(f0, f1 + 1)]
            fc.keyframe_points.clear()
            for i, v in enumerate(vals):
                fc.keyframe_points.insert(f0 + i, v, options={"FAST"})
            fc.update()
        print("camel pace: %s fore legs %d frames on" % (side, shift), flush=True)
    arm.animation_data.action = None


def camel(pack):
    fresh()
    # (the camel: fifteen pieces of one model, near 1.5 million triangles - joined, brought down)
    bpy.ops.import_scene.fbx(filepath=find(pack, "Camel.fbx"))
    parts = meshes()
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "Camel"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # (its own picture is cut into countless islands, whose edges a decimation can't cross: a copy
    # brought down without it, unwrapped afresh, the full model's colour and relief baked onto it)
    hi = body
    body = hi.copy()
    body.data = hi.data.copy()
    body.name = "Camel"
    bpy.context.collection.objects.link(body)
    while body.data.uv_layers:
        body.data.uv_layers.remove(body.data.uv_layers[0])
    # (its skin is open and torn in thousands of places, which stops a decimation short: sealed by a
    # fine voxel remesh first)
    rm = body.modifiers.new("seal", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = CAMEL_VOXEL
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.object.modifier_apply(modifier="seal")
    bring_down(body, CAMEL_TRIS)
    bpy.ops.object.shade_smooth()
    os.makedirs(TMP, exist_ok=True)
    coat, nrm = bake_down(hi, body, os.path.join(TMP, "camel_coat.jpg"), os.path.join(TMP, "camel_normal.jpg"),
                          1024, 1024, camel_coat)
    bpy.data.objects.remove(hi, do_unlink=True)
    textured(body, "camel_coat", coat, nrm)
    # the alpaca's rig and clips
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ALPACA)
    new = [o for o in bpy.data.objects if o not in before]
    arm = [o for o in new if o.type == "ARMATURE"][0]
    for o in new:
        if o != arm:
            bpy.data.objects.remove(o, do_unlink=True)
    clips = keep_actions(CAMEL_CLIPS)
    arm.scale = arm.scale * CAMEL_RIG_SCALE
    bpy.context.view_layer.update()
    inv = arm.matrix_world.inverted()
    joints = dict(CAMEL_JOINTS)
    for name, p in list(joints.items()):
        if name.endswith(".L"):
            joints[name[:-2] + ".R"] = (-p[0], p[1], p[2])
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        eb.use_connect = False
    for eb in arm.data.edit_bones:
        if eb.name not in joints:
            continue
        way = eb.tail - eb.head
        roll = eb.roll
        eb.head = inv @ Vector(joints[eb.name])
        eb.tail = eb.head + way
        eb.roll = roll
    # (a bone at each hoof, riding its lower leg - where the game's prints in the sand go)
    for hoof, leg, at in CAMEL_HOOVES:
        for side, sx in (("L", 1.0), ("R", -1.0)):
            eb = arm.data.edit_bones.new(hoof + "." + side)
            eb.head = inv @ Vector((at[0] * sx, at[1], at[2]))
            eb.tail = eb.head + (inv @ Vector((0, 0, 0.1)) - inv @ Vector((0, 0, 0)))
            eb.parent = arm.data.edit_bones[leg + "." + side]
    bpy.ops.object.mode_set(mode="OBJECT")
    for b in arm.data.bones:
        b.use_deform = not b.name.startswith(CAMEL_NO_DEFORM)
    camel_pace(arm, clips["Walk"])
    # (skinned to it by the bones' reach - its deforming bones only, worked out on bones that reach
    # from joint to joint, each leg its own side's)
    reach = {name: joints[to] if isinstance(to, str) else to for name, to in CAMEL_REACH.items()}
    for name, to in list(reach.items()):
        if name.endswith(".L"):
            reach[name[:-2] + ".R"] = (-to[0], to[1], to[2])
    rig = weight_rig(arm, reach)
    skin_by_proxy(body, rig, 0.012)
    own_side(body, ("Front", "Back", "Ear"))
    keep_near(body, rig, ("Front", "BackLeg", "BackUpper", "BackLower"), 0.24,
              ["Back", "Torso", "Torso2", "Torso3", "Neck1"])
    attach(body, arm)
    bpy.data.objects.remove(rig, do_unlink=True)
    tall = height([body])
    # (its hooves, where they ride on its lower legs)
    hooves = [(leg, inv @ Vector(joints[hoof])) for leg, hoof in (("FrontLowerLeg.L", "FF.L"), ("FrontLowerLeg.R", "FF.R"),
                                                               ("BackLowerLeg.L", "FFB.L"), ("BackLowerLeg.R", "FFB.R"))]
    for clip, pace, down in (("Walk", 0.9, 0.02), ("Run", 2.6, 0.08)):
        v = ground_speed(arm, clips[clip], hooves, down)
        k = v / (pace * tall) if v > 0 else 1.0
        retime(clips[clip], k)
        print("camel %s: %.2f m/s at its own time, %.2f wanted - x%.2f" % (clip, v, pace * tall, k), flush=True)
    export("camel")


# ------------------------------------------------------------------ the iguana

IGUANA_RANGES = {"Walk": (10, 40), "Idle": (170, 200)}
IGUANA_FEET = ["Foot_L", "Foot_R", "Hand_L", "Hand_R"]


def iguana_hide(a):
    """The green iguana made a desert one: its greens turned to a pale sandy grey-tan, its dark bands
    a warm brown, its belly paler - the red of its mouth left."""
    h, s, v = hsv(a)
    green = (h > 0.14) & (h < 0.5)
    band = green & (v < 0.42)
    h2 = np.where(green, np.where(band, 0.065, 0.095), h)
    s2 = np.where(green, np.where(band, s * 0.62, s * 0.46), s)
    v2 = np.where(green, np.where(band, v * 0.9, np.clip(v * 0.92 + 0.03, 0, 1)), v)
    return from_hsv(h2, s2, v2)


def bake_range(arm, src, name, f0, f1):
    """Frames f0..f1 of `src` - legs worked by IK - baked into an action of plain bone keys,
    starting at 0."""
    arm.animation_data.action = src
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, step=1, only_selected=False, visual_keying=True,
                     clear_constraints=False, use_current_action=False, bake_types={"POSE"})
    bpy.ops.object.mode_set(mode="OBJECT")
    act = arm.animation_data.action
    act.name = name
    act.use_fake_user = True
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            for attr in ("co", "handle_left", "handle_right"):
                getattr(kp, attr).x -= f0
        fc.update()
    arm.animation_data.action = src
    return act


def iguana(pack):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=find(pack, "Iguana.blend"), load_ui=False)
    bpy.context.preferences.filepaths.use_scripts_auto_execute = False
    arm = bpy.data.objects["IguanaArmature"]
    body = bpy.data.objects["IguanaLowPoly"]
    src = arm.animation_data.action
    clips = {name: bake_range(arm, src, name, *rng) for name, rng in IGUANA_RANGES.items()}
    # (and a run: its walk, quicker - feet kept to the ground at the game's pace for a run)
    run = clips["Walk"].copy()
    run.name = "Run"
    run.use_fake_user = True
    clips["Run"] = run
    for pb in arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    arm.animation_data.action = None
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a not in clips.values():
            bpy.data.actions.remove(a)
    for a in clips.values():
        a.id_root = "OBJECT"
    # (its walk goes forward by itself - its root carried along, its feet planted: made to walk on the
    # spot, as the game's animals do, the root's way forward taken out; how fast it went is the
    # ground's pace under its feet)
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    pace_of = {}
    for name in ("Walk", "Run"):
        act = clips[name]
        f0, f1 = act.frame_range
        for fc in act.fcurves:
            if fc.data_path == 'pose.bones["Root"].location' and fc.array_index == 2:
                way = fc.evaluate(f1) - fc.evaluate(f0)
                for kp in fc.keyframe_points:
                    for attr in ("co", "handle_left", "handle_right"):
                        pt = getattr(kp, attr)
                        pt.y -= way * (pt.x - f0) / (f1 - f0)
                fc.update()
                pace_of[name] = abs(way) / ((f1 - f0) / fps)
    # (its length is what the game sizes it by)
    long = max((body.matrix_world @ v.co).y for v in body.data.vertices) - min((body.matrix_world @ v.co).y for v in body.data.vertices)
    for clip, pace in (("Walk", 0.9), ("Run", 2.6)):
        v = pace_of.get(clip, 0.0)
        k = v / (pace * long) if v > 0 else 1.0
        retime(clips[clip], k)
        print("iguana %s: %.2f u/s at its own time, %.2f wanted - x%.2f" % (clip, v, pace * long, k), flush=True)
    os.makedirs(TMP, exist_ok=True)
    hide = picture(find(pack, "Iguana.png"), os.path.join(TMP, "iguana_hide.jpg"), 1024, iguana_hide)
    nrm = picture(find(pack, "IguanaLowPolyN.png"), os.path.join(TMP, "iguana_normal.jpg"), 512)
    textured(body, "iguana_hide", hide, nrm)
    export("iguana")


MAKERS = {"hyena": hyena, "camel": camel, "iguana": iguana}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    pack = args[0]
    for name in (args[1:] or list(MAKERS)):
        MAKERS[name](pack)
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    main()
