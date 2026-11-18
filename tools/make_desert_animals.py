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


def smooth_weights(body, factor, repeat):
    """Each vertex's weights eased toward its neighbours' (`repeat` times, by `factor`), then summed
    to one again."""
    me = body.data
    n = len(me.vertices)
    near = [[] for _ in range(n)]
    for e in me.edges:
        a, b = e.vertices
        near[a].append(b)
        near[b].append(a)
    names = [g.name for g in body.vertex_groups]
    w = [{g.group: g.weight for g in v.groups} for v in me.vertices]
    for _ in range(repeat):
        out = []
        for i in range(n):
            if not near[i]:
                out.append(w[i])
                continue
            avg = {}
            for j in near[i]:
                for k, x in w[j].items():
                    avg[k] = avg.get(k, 0.0) + x / len(near[i])
            mix = {}
            for k in set(w[i]) | set(avg):
                mix[k] = w[i].get(k, 0.0) * (1.0 - factor) + avg.get(k, 0.0) * factor
            total = sum(mix.values())
            out.append({k: x / total for k, x in mix.items() if x / max(total, 1e-9) > 0.002} if total > 0 else w[i])
        w = out
    for g in body.vertex_groups:
        g.remove(list(range(n)))
    for i in range(n):
        for k, x in w[i].items():
            body.vertex_groups[names[k]].add([i], x, "REPLACE")


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


# The shaggy fur on a Bactrian camel's upper forelegs hangs a hand's breadth off the bone: below the
# elbow (CAMEL_FUR_Z m up) and within CAMEL_FUR_REACH of the upper leg, all of it goes with its leg -
# shared with the body it stretched into flat slabs as the leg swung (user report: "two pieces on its
# forelegs") - blended back into the body over CAMEL_FUR_BLEND above that.
CAMEL_FUR_Z = 1.28
CAMEL_FUR_BLEND = 0.12
CAMEL_FUR_REACH = 0.55
CAMEL_FUR_KNEE = 0.8


def fur_with_leg(body, rig):
    from mathutils.geometry import intersect_point_line
    groups = {g.index: g.name for g in body.vertex_groups}
    mw = body.matrix_world
    for side in ("L", "R"):
        up_name, low_name = "FrontUpperLeg." + side, "FrontLowerLeg." + side
        b = rig.data.bones[up_name]
        a, c = rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local
        g_up = body.vertex_groups[up_name]
        for v in body.data.vertices:
            p = mw @ v.co
            if (p.x > 0.0) != (side == "L") or abs(p.x) < 0.02 or p.z > CAMEL_FUR_Z + CAMEL_FUR_BLEND:
                continue
            q, t = intersect_point_line(p, a, c)
            t = min(max(t, 0.0), 1.0)
            if (p - (a + (c - a) * t)).length > CAMEL_FUR_REACH:
                continue
            low = 0.0
            others = {}
            for g in v.groups:
                name = groups[g.group]
                if name == low_name:
                    low = g.weight
                elif name != up_name:
                    others[name] = g.weight
            k = 1.0 - min(max((p.z - CAMEL_FUR_Z) / CAMEL_FUR_BLEND, 0.0), 1.0)
            if k <= 0.0:
                continue
            # (the fur hangs well above the knee: none of it goes with the lower leg - a folding knee
            # pulled its foot out to a point)
            low *= min(max((CAMEL_FUR_KNEE - p.z) / 0.12, 0.0), 1.0)
            body.vertex_groups[low_name].add([v.index], low, "REPLACE")
            keep = 1.0 - k
            for name, w in others.items():
                body.vertex_groups[name].add([v.index], w * keep, "REPLACE")
            leg_share = 1.0 - low - sum(w * keep for w in others.values())
            g_up.add([v.index], max(leg_share, 0.0), "REPLACE")


def camel_coat(a):
    """Its coat a touch paler and drier - sun on the sands."""
    h, s, v = hsv(a)
    return from_hsv(h, s * 0.88, np.clip(v * 1.07 + 0.015, 0, 1))


CAMEL_FORELEG_SWING = 0.6


def calm_forelegs(act, factor):
    """A camel's forelegs swing less than the alpaca's from the shoulder and elbow (the alpaca's swing
    flung the heavy fur on its forearms out): those bones' turns each frame eased toward rest."""
    from mathutils import Quaternion
    bones = ["FrontShoulder.L", "FrontShoulder.R", "FrontUpperLeg.L", "FrontUpperLeg.R"]
    for b in bones:
        path = 'pose.bones["%s"].rotation_quaternion' % b
        fcs = [fc for fc in act.fcurves if fc.data_path == path]
        if len(fcs) != 4:
            continue
        fcs.sort(key=lambda fc: fc.array_index)
        frames = sorted({round(kp.co.x, 3) for fc in fcs for kp in fc.keyframe_points})
        values = []
        for f in frames:
            q = Quaternion([fc.evaluate(f) for fc in fcs])
            values.append(Quaternion((1, 0, 0, 0)).slerp(q.normalized(), factor))
        for i, fc in enumerate(fcs):
            fc.keyframe_points.clear()
            for f, q in zip(frames, values):
                fc.keyframe_points.insert(f, q[i], options={"FAST"})
            fc.update()


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
    calm_forelegs(clips["Walk"], CAMEL_FORELEG_SWING)
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
    fur_with_leg(body, rig)
    # (no hard edges between one bone's skin and the next: the weights smoothed a little)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    smooth_weights(body, 0.5, 3)
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


# ------------------------------------------------------------------ the scorpion

SCORPION_TRIS = 2600
# Its walk, our own (the model came with only an idle): the eight legs in two sets of four - the
# first and third legs of one side with the second and fourth of the other - taking turns, each leg
# swung forward at its hip (yaw, SCORPION_SWING rad) and lifted as it goes forward (SCORPION_LIFT),
# pushed back along the ground the rest of the time; a little rise and fall, the tail swaying, the
# claws held out; SCORPION_CYCLE frames a step pair (at its own 30 fps).
SCORPION_CYCLE = 20
SCORPION_SWING = math.radians(15.0)
SCORPION_LIFT = math.radians(13.0)
SCORPION_LEGS = [("Leg0%d.%s" % (n, side), (n + (0 if side == "L" else 1)) % 2 * 0.5)
                 for n in (1, 2, 3, 4) for side in ("L", "R")]


def scorpion_shell(a):
    """Its dark brown shell and olive legs made a desert scorpion's - straw yellow, darker at the
    joints and plates' edges - its stinger left dark amber."""
    lum = a.mean(-1)
    lit = np.clip(lum / 0.42, 0, 1) ** 0.8
    dark = np.array([0.30, 0.21, 0.09], np.float32)
    pale = np.array([0.93, 0.79, 0.44], np.float32)
    out = dark + (pale - dark) * lit[..., None]
    h, s, v = hsv(a)
    sting = (s > 0.55) & ((h < 0.06) | (h > 0.9))
    out[sting] = a[sting] * 0.7
    out[lum < 0.015] = 0.0
    return out


def scorpion_walk(arm):
    """Its walk (see SCORPION_*), keyed: each moving bone's turn worked out in the world and set in
    its own frame."""
    from mathutils import Matrix, Quaternion
    act = bpy.data.actions.new("Walk")
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    up = Vector((0, 0, 1))
    ahead = Vector((0, 1, 0))  # (it faces +Y in its file)

    def local(name, world_rot):
        b = arm.data.bones[name]
        rest = b.matrix_local.to_quaternion()
        return rest.inverted() @ world_rot @ rest

    legs = []
    for name, phase in SCORPION_LEGS:
        hip = arm.data.bones[name + ".001"]
        tip = arm.data.bones[name + ".005"]
        out = (tip.tail_local - hip.head_local)
        out.z = 0.0
        out.normalize()
        fwd = 1.0 if up.cross(out).dot(ahead) > 0 else -1.0
        legs.append((name + ".001", phase, out, fwd))
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for fr in range(SCORPION_CYCLE + 1):
        t = fr / SCORPION_CYCLE
        for bone, phase, out, fwd in legs:
            th = 2.0 * math.pi * (t + phase)
            yaw = Quaternion(up, fwd * SCORPION_SWING * math.sin(th))
            lift = Quaternion(out.cross(up), SCORPION_LIFT * max(0.0, math.cos(th)))
            pb = arm.pose.bones[bone]
            pb.rotation_quaternion = local(bone, yaw @ lift)
            pb.keyframe_insert("rotation_quaternion", frame=fr)
        root = arm.pose.bones["Root"]
        root.location = Vector((0, 0, 0.03 * math.sin(4.0 * math.pi * t)))
        root.keyframe_insert("location", frame=fr)
        for k, name in enumerate(("Tail.002", "Tail.003", "Tail.004")):
            pb = arm.pose.bones[name]
            pb.rotation_quaternion = local(name, Quaternion(up, math.radians(4.0) * math.sin(2.0 * math.pi * t - k * 0.7)))
            pb.keyframe_insert("rotation_quaternion", frame=fr)
        for side, sx in (("L", -1.0), ("R", 1.0)):
            name = "Arm.%s.001" % side
            pb = arm.pose.bones[name]
            pb.rotation_quaternion = local(name, Quaternion(up, sx * math.radians(5.0) * math.sin(2.0 * math.pi * t)))
            pb.keyframe_insert("rotation_quaternion", frame=fr)
    arm.animation_data.action = None
    return act


def scorpion(pack):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=find(pack, "Transvaal_Scorpion_FreeDownload.blend"), load_ui=False)
    bpy.context.preferences.filepaths.use_scripts_auto_execute = False
    arm = bpy.data.objects["Transvaal_Scorpion-rig"]
    body = bpy.data.objects["Transvaal_Scorpion"]
    # (only the animal: not the file's camera, lights, ground, nor its maker's name in letters)
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    for md in list(body.modifiers):
        if md.type == "SUBSURF":
            body.modifiers.remove(md)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    stray = arm.data.edit_bones.get("Bone")
    if stray is not None:
        arm.data.edit_bones.remove(stray)
    bpy.ops.object.mode_set(mode="OBJECT")
    if body.vertex_groups.get("Bone") is not None:
        body.vertex_groups.remove(body.vertex_groups["Bone"])
    body.data.materials.clear()
    bring_down(body, SCORPION_TRIS)
    idle = [a for a in bpy.data.actions if a.name == "Scorpion-idle"][0]
    for a in list(bpy.data.actions):
        if a != idle:
            bpy.data.actions.remove(a)
    idle.name = "Idle"
    idle.use_fake_user = True
    if arm.animation_data is not None:
        arm.animation_data.action = None
    walk = scorpion_walk(arm)
    run = walk.copy()
    run.name = "Run"
    run.use_fake_user = True
    for a in (idle, walk, run):
        a.id_root = "OBJECT"
    # (its feet: the tips of its legs)
    tips = [(name + ".005", arm.data.bones[name + ".005"].tail_local.copy()) for name, _ in SCORPION_LEGS]
    long = max((body.matrix_world @ v.co).y for v in body.data.vertices) - min((body.matrix_world @ v.co).y for v in body.data.vertices)
    # (a small thing scuttling fast for its size: its feet kept to the ground only so far - past
    # these its legs would flicker faster than the eye, so they slide a little instead)
    for act, pace, least in ((walk, 0.9, 0.55), (run, 2.6, 0.4)):
        v = ground_speed(arm, act, tips, 0.04)
        k = max(v / (pace * long), least) if v > 0 else 1.0
        retime(act, k)
        print("scorpion %s: %.2f u/s at its own time, %.2f wanted - x%.2f" % (act.name, v, pace * long, k), flush=True)
    # (turned to face -Y, as the game's animals do)
    arm.rotation_euler.z = math.pi
    os.makedirs(TMP, exist_ok=True)
    from PIL import Image
    src = Image.open(find(pack, "Transvaal_Scorpion-Diff.png")).convert("RGB")
    # (the maker's name and address written in its picture's empty corner: painted out)
    w, h = src.size
    src.paste((0, 0, 0), (0, int(h * 0.91), int(w * 0.32), h))
    clean = os.path.join(TMP, "scorpion_src.png")
    src.save(clean)
    shell = picture(clean, os.path.join(TMP, "scorpion_shell.jpg"), 512, scorpion_shell)
    nrm = picture(find(pack, "Transvaal_Scorpion-Norm2.png"), os.path.join(TMP, "scorpion_normal.jpg"), 512)
    textured(body, "scorpion_shell", shell, nrm)
    export("scorpion")


# ------------------------------------------------------------------ the vulture

VULTURE_TRIS = 5000
# The condor of the bird figures (a still figure, wings spread), stood at the origin facing -Y: a rig
# of our own - its body, head, tail, each wing three bones (to the elbow, the wrist, the tip) - its
# weights by where along the wing each part is; two clips: soaring (wings held, the hands and the tail
# trimming the air, VULTURE_SOAR frames) and beating (VULTURE_FLAP frames: the arm sweeping down and
# up, the hand a beat behind it).
VULTURE_SOAR = 90
VULTURE_FLAP = 24
VULTURE_WING = [("Arm", 0.10, 0.45), ("Forearm", 0.45, 0.85), ("Hand", 0.85, 1.38)]


def vulture_plumage(a):
    """The condor's black made a desert vulture's dusty umber, its pale wing bars buff - its bare head
    left as it is."""
    h, s, v = hsv(a)
    head = (s > 0.35) & ((h < 0.08) | (h > 0.9)) & (v > 0.3)
    umber = np.array([0.33, 0.24, 0.16], np.float32)
    buff = np.array([0.82, 0.72, 0.56], np.float32)
    lit = np.clip(v / 0.75, 0, 1)
    out = umber * (0.55 + 0.9 * lit[..., None]) * (1.0 - lit[..., None] ** 3) + buff * (lit[..., None] ** 3)
    out[head] = a[head]
    return out


def vulture(pack):
    from mathutils import Quaternion
    fresh()
    bpy.ops.import_scene.fbx(filepath=find(pack, "bird+collection.fbx"))
    body = [o for o in bpy.data.objects if o.name.startswith("condor")][0]
    for o in list(bpy.data.objects):
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # (centred on its body, turned to face -Y: the figure faced +Y)
    vs = [v.co for v in body.data.vertices]
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    low = min(v.z for v in vs if abs(v.x - cx) < 0.12)
    for v in body.data.vertices:
        v.co = Vector((-(v.co.x - cx), -(v.co.y - cy), v.co.z - low - 0.12))
    body.data.update()
    bring_down(body, VULTURE_TRIS)
    span = max(abs(v.co.x) for v in body.data.vertices)
    # the rig
    arm_data = bpy.data.armatures.new("VultureRig")
    arm = bpy.data.objects.new("VultureRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    root = eb.new("Body")
    root.head, root.tail = Vector((0, 0.15, 0.1)), Vector((0, -0.2, 0.1))
    head = eb.new("Head")
    head.head, head.tail, head.parent = Vector((0, -0.2, 0.12)), Vector((0, -0.42, 0.1)), root
    tail = eb.new("Tail")
    tail.head, tail.tail, tail.parent = Vector((0, 0.15, 0.08)), Vector((0, 0.42, 0.06)), root

    def wing_z(f):
        # (the wings' dihedral: the figure's own, from its vertices near that far out)
        near = [v.co for v in body.data.vertices if abs(abs(v.co.x) - f * span) < 0.04 and abs(v.co.y) < 0.35]
        return sum(c.z for c in near) / len(near) if near else 0.1

    for side, sx in (("L", 1.0), ("R", -1.0)):
        parent = root
        for name, a, b in VULTURE_WING:
            bone = eb.new("%s.%s" % (name, side))
            fa, fb = a / VULTURE_WING[-1][2], b / VULTURE_WING[-1][2]
            bone.head = Vector((sx * fa * span, 0.0, wing_z(fa)))
            bone.tail = Vector((sx * fb * span, 0.0, wing_z(min(fb, 0.97))))
            bone.parent = parent
            bone.roll = 0.0
            parent = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    # (weights by where each part is: along a wing by how far out, blended over the joints; the body
    # the middle, the head forward, the tail behind)
    groups = {b.name: body.vertex_groups.new(name=b.name) for b in arm_data.bones}
    joints = [0.0] + [b / VULTURE_WING[-1][2] for _n, _a, b in VULTURE_WING]
    for v in body.data.vertices:
        x, y = v.co.x, v.co.y
        f = abs(x) / span
        side = "L" if x > 0 else "R"
        w = {}
        if f < 0.1:
            k = 1.0 - min(f / 0.1, 1.0)
            core = "Head" if y < -0.2 else ("Tail" if y > 0.17 else "Body")
            w[core] = k
            w["Arm." + side] = 1.0 - k
        else:
            for i, (name, a, b) in enumerate(VULTURE_WING):
                lo_f, hi_f = joints[i] if i else 0.1, joints[i + 1]
                if lo_f <= f <= hi_f or (i == len(VULTURE_WING) - 1 and f > hi_f):
                    t = (f - lo_f) / max(hi_f - lo_f, 1e-6)
                    w["%s.%s" % (name, side)] = 1.0
                    # (blended into the next bone over the last fifth, and from the one before over the first)
                    if t > 0.8 and i + 1 < len(VULTURE_WING):
                        k = (t - 0.8) / 0.4
                        w["%s.%s" % (name, side)] = 1.0 - k
                        w["%s.%s" % (VULTURE_WING[i + 1][0], side)] = k
                    elif t < 0.2 and i > 0:
                        k = (0.2 - t) / 0.4
                        w["%s.%s" % (name, side)] = 1.0 - k
                        w["%s.%s" % (VULTURE_WING[i - 1][0], side)] = k
                    break
        for name, wt in w.items():
            if wt > 0.0:
                groups[name].add([v.index], wt, "REPLACE")
    attach(body, arm)
    # the clips
    arm.animation_data_create()
    fwd = Vector((0, -1, 0))
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"

    def local(name, rot):
        rest = arm.data.bones[name].matrix_local.to_quaternion()
        return rest.inverted() @ rot @ rest

    def key_clip(clip, frames, pose):
        act = bpy.data.actions.new(clip)
        act.use_fake_user = True
        act.id_root = "OBJECT"
        arm.animation_data.action = act
        for fr in range(frames + 1):
            t = (fr % frames) / frames
            for name, rot in pose(t).items():
                pb = arm.pose.bones[name]
                pb.rotation_quaternion = local(name, rot)
                pb.keyframe_insert("rotation_quaternion", frame=fr)
        arm.animation_data.action = None

    def soar(t):
        th = 2.0 * math.pi * t
        out = {"Tail": Quaternion(Vector((0, 0, 1)), math.radians(5.0) * math.sin(th)),
               "Head": Quaternion(Vector((0, 0, 1)), math.radians(8.0) * math.sin(th + 1.0))}
        for side, sx in (("L", 1.0), ("R", -1.0)):
            # (rolled about the body's line: + raises the left wing, lowers the right - so sx)
            out["Arm." + side] = Quaternion(fwd, sx * math.radians(3.0) * math.sin(th))
            out["Forearm." + side] = Quaternion(fwd, sx * math.radians(2.0) * math.sin(th - 0.6))
            out["Hand." + side] = Quaternion(fwd, sx * math.radians(5.0) * math.sin(th - 1.2))
        return out

    def flap(t):
        th = 2.0 * math.pi * t
        out = {"Tail": Quaternion(Vector((1, 0, 0)), math.radians(6.0) * math.sin(th + 0.5)),
               "Head": Quaternion(Vector((1, 0, 0)), math.radians(4.0) * math.sin(th + 2.0))}
        for side, sx in (("L", 1.0), ("R", -1.0)):
            # (deeper down than up - the downstroke does the work)
            out["Arm." + side] = Quaternion(fwd, sx * math.radians(22.0) * (math.sin(th) - 0.25))
            out["Forearm." + side] = Quaternion(fwd, sx * math.radians(9.0) * (math.sin(th - 0.7) - 0.2))
            out["Hand." + side] = Quaternion(fwd, sx * math.radians(12.0) * (math.sin(th - 1.3) - 0.2))
        return out

    key_clip("Soar", VULTURE_SOAR, soar)
    key_clip("Flap", VULTURE_FLAP, flap)
    os.makedirs(TMP, exist_ok=True)
    tex = None
    for n in [m_ for m_ in bpy.data.images if m_.name.startswith("condor")]:
        tex = n
        break
    src = find(pack, "condor.tif")
    feathers = picture(src, os.path.join(TMP, "vulture_plumage.jpg"), 512, vulture_plumage)
    textured(body, "vulture_plumage", feathers)
    export("vulture")


MAKERS = {"hyena": hyena, "camel": camel, "iguana": iguana, "scorpion": scorpion, "vulture": vulture}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    pack = args[0]
    for name in (args[1:] or list(MAKERS)):
        MAKERS[name](pack)
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    main()
