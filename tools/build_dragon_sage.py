"""The big ghost's body, third make (user request): the dragon the user had
Meshy generate again ("Crimson Wyrm Sage" - one tail, a 2048 texture set;
kept out of the repo, like the other source models), rigged here for the
game with a finer skeleton than the second make had. Built from

  SAGE_FBX   Meshy's textured export (one mesh, ~270 000 triangles; colour,
             normal, roughness and metallic pictures), facing -y, feet at
             its lowest z, about 1.74 tall, arms out (a T pose), wings open
  OLD_GLB    the second make (assets/models/run3d/dragon.glb as it was before
             this one - `git show 972020b:assets/models/run3d/dragon.glb`): its six clips,
             already carried onto the characters' bone names, are carried
             again onto this one (tools/retarget.py)

  bpyenv/bin/python tools/build_dragon_sage.py SAGE_FBX OLD_GLB OUT.glb

The mesh is brought down to TRIS triangles - the wing membranes kept denser
than the rest (they bend and fill with air), left and right alike - the
high one's surface baked into its normal picture, and stood on the ground.

Its skeleton (JOINTS: measured off this mesh - the wing's spars and their
knuckles found where the skin is thickest across the membrane, the body's
joints from the auto-rig the user had made of it, the dragon's legs and its
tail by slices) keeps the characters' bone names for the body - so the game's
code for it carries over - and adds:

  - each hand's five fingers, three bones each (so it can close its fist
    on the lantern's bail),
  - each wing on fifteen: the arm in three (to the elbow, to the wrist, the
    hand) and its three fingers in four each, at their own knuckles,
  - the tail in ten, shorter toward the tip.

Its weights: Blender's (bone heat) for the body; its own for the parts
whose motion most makes it what it is -
  - the wings: each vertex between its two nearest spars (the arm and the
    three fingers), shared by how near it is to each, and along a spar
    between its bones by where it lies, blended at the knuckles - so the
    membrane stretches evenly as the fingers spread and fold;
  - the hands: each finger's skin on that finger alone (no cross-talk
    between fingers that lie close), blended at its knuckles;
  - the tail: along its line, each bone into the next.
The robe's cloth (by its colour) stays on the body's bones. Where Meshy grew
one part into another that moves apart from it - each wing's inner membrane
into the back all the way down from its shoulder, the tail's underside into
the robe and the skin between the legs - the mesh is parted along the seam
(ROOT_KEEP, TAIL_KEEP: whole only about their roots), so neither tears.
"""
import math
import os
import sys
import time

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import retarget  # noqa: E402

SAGE, OLD, OUT = sys.argv[-3:]
STAGE = os.environ.get("STAGE", "all")
TRIS = 40000
# The decimation goes easier on the membrane: its vertices weighted MEMBRANE_W (the rest 1) at
# MEMBRANE_STRENGTH - measured: it keeps ~2.3 times the membrane plain decimation would (~6000 of
# its vertices; the body ~14000).
MEMBRANE_W = 0.5
MEMBRANE_STRENGTH = 0.006
NORMAL_SIZE = 2048
SHIP_COLOUR = 2048
SHIP_NORMAL = 1536
SHIP_DETAIL = 1024
CLIPS = ("Idle", "Idle_Lamp", "Walk", "Chase", "Grab", "Eat")
LOOPING = ("Idle", "Idle_Lamp", "Walk", "Chase")
SAMPLES = 24
ARM_AIM = ("upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r")


def V3(x, y, z):
    return Vector((x, y, z))


# ------------------------------------------------------------ the joints
# In Meshy's own frame (facing -y, its left +x; z as the mesh has it - the
# ground is LIFT below 0). (name: head, tail, parent) - the left side's;
# the right's mirrored.
TRUNK = {
    "pelvis": (V3(0, -0.37, -0.03), V3(0, -0.356, 0.075), "root"),
    "spine_01": (V3(0, -0.356, 0.075), V3(0, -0.334, 0.193), "pelvis"),
    "spine_02": (V3(0, -0.334, 0.193), V3(0, -0.309, 0.327), "spine_01"),
    "spine_03": (V3(0, -0.309, 0.327), V3(0, -0.28, 0.479), "spine_02"),
    "neck_01": (V3(0, -0.28, 0.479), V3(0, -0.263, 0.59), "spine_03"),
    "Head": (V3(0, -0.263, 0.59), V3(0, -0.30, 0.80), "neck_01"),
}
SIDE = {
    "clavicle": (V3(0.107, -0.28, 0.443), V3(0.261, -0.28, 0.37), "spine_03"),
    "upperarm": (V3(0.261, -0.28, 0.37), V3(0.443, -0.269, 0.36), "clavicle"),
    "lowerarm": (V3(0.443, -0.269, 0.36), V3(0.699, -0.319, 0.36), "upperarm"),
    "hand": (V3(0.699, -0.319, 0.36), V3(0.79, -0.311, 0.376), "lowerarm"),
    "thigh": (V3(0.164, -0.366, -0.082), V3(0.188, -0.395, -0.30), "pelvis"),
    "calf": (V3(0.188, -0.395, -0.30), V3(0.222, -0.16, -0.63), "thigh"),
    "foot": (V3(0.222, -0.16, -0.63), V3(0.268, -0.37, -0.815), "calf"),
    "ball": (V3(0.268, -0.37, -0.815), V3(0.29, -0.47, -0.85), "foot"),
    # the wing: the arm to the elbow, to the wrist (its hook), the hand
    "wing": (V3(0.12, -0.19, 0.51), V3(0.283, -0.088, 0.538), "spine_03"),
    "wing_02": (V3(0.283, -0.088, 0.538), V3(0.315, -0.096, 0.827), "wing"),
    "wing_03": (V3(0.315, -0.096, 0.827), V3(0.35, -0.068, 0.795), "wing_02"),
}
# The fingers, joint to joint (each finger's bones parented down the chain).
HAND = {
    "thumb": [V3(0.723, -0.349, 0.322), V3(0.743, -0.373, 0.292), V3(0.786, -0.399, 0.254), V3(0.834, -0.435, 0.227)],
    "index": [V3(0.783, -0.366, 0.365), V3(0.832, -0.377, 0.359), V3(0.878, -0.388, 0.349), V3(0.909, -0.392, 0.323)],
    "middle": [V3(0.799, -0.328, 0.375), V3(0.849, -0.33, 0.39), V3(0.893, -0.331, 0.38), V3(0.925, -0.328, 0.353)],
    "ring": [V3(0.801, -0.291, 0.38), V3(0.843, -0.28, 0.403), V3(0.884, -0.265, 0.403), V3(0.915, -0.252, 0.386)],
    "pinky": [V3(0.78, -0.259, 0.386), V3(0.834, -0.242, 0.369), V3(0.877, -0.228, 0.344), V3(0.899, -0.218, 0.304)],
}
# The wing's fingers: from the hand, knuckle to knuckle, to the tip (where
# the skin across the membrane is thickest - their spars).
WING = {
    "f1": [V3(0.352, -0.066, 0.819), V3(0.588, 0.133, 0.735), V3(0.836, 0.339, 0.561), V3(0.915, 0.374, 0.423),
           V3(0.952, 0.386, 0.30)],
    "f2": [V3(0.352, -0.066, 0.771), V3(0.593, 0.034, 0.517), V3(0.713, 0.062, 0.345), V3(0.851, 0.112, 0.099),
           V3(0.89, 0.142, -0.025)],
    "f3": [V3(0.345, -0.071, 0.775), V3(0.383, -0.046, 0.615), V3(0.517, -0.021, 0.255), V3(0.551, -0.023, 0.083),
           V3(0.550, -0.046, -0.025)],
}
# The tail's line (x = 0): from the back of its hips down and back to its tip.
TAIL_LINE = [V3(0, -0.24, 0.0), V3(0, -0.12, -0.035), V3(0, 0.0, -0.11), V3(0, 0.1, -0.19), V3(0, 0.2, -0.25),
             V3(0, 0.3, -0.288), V3(0, 0.4, -0.322), V3(0, 0.5, -0.331), V3(0, 0.578, -0.335)]
TAIL_BONES = 10
# (Meshy's z) nothing of the wings lower than this - their fingertips end at -0.025
WING_LOW = -0.07
# (m) the membrane eases off the body's flesh between these distances from it
ATTACH = (0.012, 0.16)
# (m) no further from its spars than this is the membrane (the middle of its widest panel ~0.17)
MEMBRANE_REACH = 0.22
# (Meshy's y: +y behind it) skin further back than this is behind its back - the wings' and the
# trunk's, never the arms' (held out in front of the wings, ~0.2 ahead): the inner membrane behind
# the back is about as near a forearm as a spar, and that mustn't decide whose it is
BACK_Y = -0.17
# The membrane shared among its spars by how near it is to each (each's share 1/d^SPAR_POWER) - smooth
# everywhere, as the nearest two alone aren't where the second nearest changes; and soft enough that
# spreading the wing far wider than it was made (DragonRig.SPREAD_*) opens each panel evenly, as a
# fan - sharper, all of it stretched in a thin band midway between two fingers. The wing's flesh
# against the body's eased over WING_SOFT (m) of which is nearer
SPAR_POWER = 2.0
WING_SOFT = 0.08
# (m from the wing's root, its shoulder) Meshy grew each wing's inner membrane into the back the
# whole way down from its shoulder, a seam standing up behind it as the wing does - which, the
# wing laid out flat to fly, would stretch half a metre: it stays grown into the back only about its
# root (wholly within the first, eased off by the second), the rest of that seam parted
ROOT_KEEP = (0.12, 0.2)
TAIL_TAPER = 0.92   # each tail bone this much of the one before
# (m from the tail's root) what Meshy grew onto the tail's underside - the robe, the skin between
# the legs - is parted from it further out than this: the tail swings free of it (crouched, that
# goes with the legs)
TAIL_KEEP = 0.1


def select(objs, active=None):
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active or objs[0]


def log(*a):
    print(*a, flush=True)


# ------------------------------------------------------------ the mesh

def thickness(obj):
    """Per vertex: how far through the skin it is to the other side (m) -
    the membrane a few mm, the spars and the body far more."""
    me = obj.data
    mw = obj.matrix_world
    co = [mw @ v.co for v in me.vertices]
    bvh = BVHTree.FromPolygons([tuple(p) for p in co], [tuple(p.vertices) for p in me.polygons])
    n3 = mw.to_3x3().inverted().transposed()
    th = np.zeros(len(me.vertices))
    for v in me.vertices:
        n = (n3 @ v.normal).normalized()
        hit = bvh.ray_cast(co[v.index] - n * 1e-4, -n, 0.12)
        th[v.index] = hit[3] if hit[0] is not None else 0.12
    return th


def mesh():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=SAGE)
    hi = next(o for o in set(bpy.data.objects) - before if o.type == 'MESH')
    hi.name = "High"
    # Its pictures from the files beside the FBX (its own embedded ones can't be packed)
    folder = os.path.dirname(os.path.abspath(SAGE))
    stem = os.path.splitext(os.path.basename(SAGE))[0]
    for n in hi.data.materials[0].node_tree.nodes:
        if n.type != 'TEX_IMAGE' or n.image is None:
            continue
        kind = ("_roughness" if "roughness" in n.image.name else "_metallic" if "metallic" in n.image.name
                else "" if n.image.colorspace_settings.name == 'sRGB' else "_normal")
        path = os.path.join(folder, stem + kind + ".png")
        if os.path.exists(path):
            img = bpy.data.images.load(path)
            img.colorspace_settings.name = 'sRGB' if kind == "" else 'Non-Color'
            n.image = img
    select([hi])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    zs = np.array([v.co.z for v in hi.data.vertices])
    lift = -float(zs.min())
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = "DragonGhost"
    bpy.context.scene.collection.objects.link(lo)
    # The membranes kept denser: a group of the wings' thin skin.
    th = thickness(lo)
    keep = lo.vertex_groups.new(name="Membrane")
    idx = [v.index for v in lo.data.vertices
           if (th[v.index] < 0.016 and abs(v.co.x) > 0.24 and v.co.z > -0.12 and v.co.y > -0.22)
           # (and the hands: their fingers close on the lantern's bail)
           or (abs(v.co.x) > 0.68 and v.co.y < -0.15 and 0.15 < v.co.z < 0.5)]
    keep.add([v.index for v in lo.data.vertices], 1.0, 'REPLACE')
    keep.add(idx, MEMBRANE_W, 'REPLACE')
    log("membrane and hand vertices kept denser: %d" % len(idx))
    tris = sum(len(p.vertices) - 2 for p in hi.data.polygons)
    m = lo.modifiers.new("Less", 'DECIMATE')
    m.ratio = TRIS / tris
    m.use_collapse_triangulate = True
    m.use_symmetry = True
    m.symmetry_axis = 'X'
    m.vertex_group = "Membrane"
    m.vertex_group_factor = MEMBRANE_STRENGTH
    select([lo])
    bpy.ops.object.modifier_apply(modifier="Less")
    lo.vertex_groups.remove(lo.vertex_groups["Membrane"])
    # Its own material, the baked normal in it.
    mat = lo.data.materials[0].copy()
    mat.name = "DragonGhost_Skin"
    lo.data.materials[0] = mat
    img = bpy.data.images.new("DragonGhost_Normal", NORMAL_SIZE, NORMAL_SIZE)
    img.colorspace_settings.name = 'Non-Color'
    nt = mat.node_tree
    node = nt.nodes.new('ShaderNodeTexImage')
    node.image = img
    for n in nt.nodes:
        n.select = False
    node.select = True
    nt.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.012
    bk.max_ray_distance = 0.03
    bk.margin = 8
    select([hi, lo], active=lo)
    t = time.time()
    bpy.ops.object.bake(type='NORMAL')
    log("baked the normal picture in %.0f s" % (time.time() - t))
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    nm = next(n for n in nt.nodes if n.type == 'NORMAL_MAP')
    for link in list(nm.inputs['Color'].links):
        nt.links.remove(link)
    nt.links.new(node.outputs['Color'], nm.inputs['Color'])
    # (no metal in it: Meshy's metallic picture is all but black)
    for link in list(bsdf.inputs['Metallic'].links):
        nt.links.remove(link)
    bsdf.inputs['Metallic'].default_value = 0.0
    bpy.data.objects.remove(hi, do_unlink=True)
    for n in list(nt.nodes):
        if n.type != 'TEX_IMAGE' or n.image is None or n.image is img:
            continue
        name = n.image.name
        if "metallic" in name:
            nt.nodes.remove(n)
        elif "roughness" in name:
            n.image.scale(SHIP_DETAIL, SHIP_DETAIL)
            n.image.name = "DragonGhost_Roughness"
        elif n.image.colorspace_settings.name == 'sRGB':
            if n.image.size[0] != SHIP_COLOUR:
                n.image.scale(SHIP_COLOUR, SHIP_COLOUR)
            n.image.name = "DragonGhost_Colour"
        else:
            nt.nodes.remove(n)     # Meshy's own normal picture: baked into ours
    img.scale(SHIP_NORMAL, SHIP_NORMAL)
    # (each picture its own file by its name - the export names them so)
    folder = os.path.dirname(os.path.abspath(OUT))
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            n.image.filepath_raw = os.path.join(folder, n.image.name + ".png")
            n.image.file_format = 'PNG'
            n.image.save()
    # Stood on the ground.
    lo.location.z += lift
    select([lo])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    log("mesh: %d triangles, %d vertices; lifted %.3f" % (sum(len(p.vertices) - 2 for p in lo.data.polygons),
                                                          len(lo.data.vertices), lift))
    return lo, lift


# ------------------------------------------------------------ the skeleton

def _tail_joints():
    """TAIL_LINE resampled into TAIL_BONES bones, each TAIL_TAPER of the one before."""
    pts = [p.copy() for p in TAIL_LINE]
    seg = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(seg)
    share = [TAIL_TAPER ** i for i in range(TAIL_BONES)]
    k = total / sum(share)
    out = [pts[0]]
    run = 0.0
    for s in share[:-1]:
        run += s * k
        acc = 0.0
        for i, L in enumerate(seg):
            if acc + L >= run:
                out.append(pts[i].lerp(pts[i + 1], (run - acc) / L))
                break
            acc += L
    out.append(pts[-1])
    return out


def joints(lift):
    """{name: (head, tail, parent)}, stood on the ground."""
    up = Vector((0, 0, lift))
    out = {"root": (V3(0, -0.30, 0.0), V3(0, -0.20, 0.0), None)}
    for n, (h, t, p) in TRUNK.items():
        out[n] = (h + up, t + up, p)
    for s, k in (("l", 1.0), ("r", -1.0)):
        def m(v):
            return Vector((v.x * k, v.y, v.z)) + up
        for n, (h, t, p) in SIDE.items():
            name = n.replace("wing", "wing_" + s, 1) if n.startswith("wing") else n + "_" + s
            if n.startswith("wing"):
                parent = p if p == "spine_03" else p.replace("wing", "wing_" + s, 1)
            else:
                parent = p if p in TRUNK or p == "root" else p + "_" + s
            out[name] = (m(h), m(t), parent)
        for f, pts in HAND.items():
            for i in range(3):
                out["%s_%02d_%s" % (f, i + 1, s)] = (m(pts[i]), m(pts[i + 1]),
                                                    "hand_" + s if i == 0 else "%s_%02d_%s" % (f, i, s))
        for f, pts in WING.items():
            for i in range(4):
                name = "wing_%s_%s" % (s, f) + ("" if i == 0 else "_%02d" % (i + 1))
                parent = "wing_%s_03" % s if i == 0 else "wing_%s_%s" % (s, f) + ("" if i == 1 else "_%02d" % i)
                out[name] = (m(pts[i]), m(pts[i + 1]), parent)
    tj = _tail_joints()
    for i in range(TAIL_BONES):
        out["tail_%02d" % (i + 1)] = (tj[i] + up, tj[i + 1] + up, "pelvis" if i == 0 else "tail_%02d" % i)
    return out


def skeleton(spec):
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.scene.collection.objects.link(arm)
    select([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = data.edit_bones
    done = set()

    def make(name):
        if name in done:
            return
        h, t, parent = spec[name]
        if parent:
            make(parent)
        b = eb.new(name)
        b.head, b.tail = h, t
        # (rolled so each bone's x points the same way across the body)
        b.align_roll(Vector((0.0, -1.0, 0.0)) if abs((t - h).normalized().y) < 0.9 else Vector((0.0, 0.0, 1.0)))
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        done.add(name)
    for name in spec:
        make(name)
    bpy.ops.object.mode_set(mode='OBJECT')
    log("skeleton: %d bones" % len(data.bones))
    return arm



# ------------------------------------------------------------ the weights

def _seg_dist(P, a, b):
    """Distances from points P (n,3) to segment a-b, and how far along (0..1)."""
    ab = b - a
    L2 = max(float(ab @ ab), 1e-12)
    t = np.clip(((P - a) @ ab) / L2, 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1), t


def _chain(P, pts):
    """Distance from P to a polyline of joints, the segment nearest and how far along it."""
    best = np.full(len(P), 9.0)
    seg = np.zeros(len(P), int)
    tt = np.zeros(len(P))
    for i in range(len(pts) - 1):
        d, t = _seg_dist(P, pts[i], pts[i + 1])
        m = d < best
        best[m], seg[m], tt[m] = d[m], i, t[m]
    return best, seg, tt


def _along(bones, seg, t, blend):
    """Weights (n, len(bones)) along a chain: each point on its segment's bone, eased into the next
    (or the one before) within `blend` of the joint between them (a share of the bone's length) -
    half and half at the joint itself."""
    n = len(seg)
    W = np.zeros((n, len(bones)))
    rows = np.arange(n)
    W[rows, seg] = 1.0

    def ease(x):
        x = np.clip(x, 0.0, 1.0)
        return 0.5 * x * x * (3 - 2 * x)
    up = ease((t - (1 - blend)) / blend) * (seg + 1 < len(bones))
    down = ease((blend - t) / blend) * (seg > 0)
    W[rows, seg] -= up + down
    nxt = np.minimum(seg + 1, len(bones) - 1)
    prv = np.maximum(seg - 1, 0)
    np.add.at(W, (rows, nxt), up)
    np.add.at(W, (rows, prv), down)
    return W


def _cloth(body):
    """Per vertex: whether it's the robe's cloth (dark, grey: its colour picture)."""
    me = body.data
    img = next(n.image for n in me.materials[0].node_tree.nodes
               if n.type == 'TEX_IMAGE' and n.image and n.image.name == "DragonGhost_Colour")
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uv = me.uv_layers.active.data
    acc = np.zeros((len(me.vertices), 3))
    cnt = np.zeros(len(me.vertices))
    for l in me.loops:
        u, v = uv[l.index].uv
        acc[l.vertex_index] += px[int(np.clip(v * h, 0, h - 1)), int(np.clip(u * w, 0, w - 1)), :3]
        cnt[l.vertex_index] += 1
    c = acc / np.maximum(cnt, 1)[:, None]
    mx, mn = c.max(1), c.min(1)
    return (mx < 0.5) & ((mx - mn) < 0.2 * mx + 0.035)


def weights(body, arm, spec):
    """Bone heat for the body; its own for the wings, the hands and the tail (see the top)."""
    own = ("wing_", "tail_", "thumb_", "index_", "middle_", "ring_", "pinky_")
    for b in arm.data.bones:
        b.use_deform = not b.name.startswith(own) and b.name != "root"
    select([body, arm], active=arm)
    t0 = time.time()
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    log("bone heat in %.0f s; %d vertices with no bone" % (time.time() - t0,
                                                           sum(1 for v in body.data.vertices if not v.groups)))
    for b in arm.data.bones:
        b.use_deform = b.name != "root"
    me = body.data
    n = len(me.vertices)
    names = [b.name for b in arm.data.bones if b.name != "root"]
    col = {nm: i for i, nm in enumerate(names)}
    W = np.zeros((n, len(names)))
    gi = {g.index: g.name for g in body.vertex_groups}
    for v in me.vertices:
        for g in v.groups:
            nm = gi[g.group]
            if nm in col:
                W[v.index, col[nm]] += g.weight
    s = W.sum(1)
    W[s > 0] /= s[s > 0][:, None]
    P = np.array([tuple(body.matrix_world @ v.co) for v in me.vertices])
    cloth = _cloth(body)
    thick = thickness(body)
    lift = float(body["lift"])
    H = {k: (np.array(v[0]), np.array(v[1])) for k, v in spec.items()}
    # the body as capsules (bone, radius): how near a point is to the body's own flesh
    body_r = {"pelvis": 0.15, "spine_01": 0.15, "spine_02": 0.15, "spine_03": 0.14, "neck_01": 0.08, "Head": 0.1,
              "clavicle": 0.06, "upperarm": 0.06, "lowerarm": 0.05, "hand": 0.04, "thigh": 0.08, "calf": 0.06,
              "foot": 0.04, "ball": 0.03}
    behind = P[:, 1] > BACK_Y
    near_body = np.full(n, 9.0)
    for nm in names:
        base = nm[:-2] if nm[-2:] in ("_l", "_r") else nm
        if base in body_r:
            d, _ = _seg_dist(P, *H[nm])
            if base in ("upperarm", "lowerarm", "hand"):
                d = np.where(behind, 9.0, d)
            near_body = np.minimum(near_body, d - body_r[base])

    trunk_cols = [col[b] for b in ("pelvis", "spine_01", "spine_02", "spine_03")]
    trunk_skin = W[:, trunk_cols].sum(1) > 0.6
    # (the back: the trunk's and the shoulders' - where the robe's hood lies over it too)
    back_skin = W[:, trunk_cols + [col["clavicle_l"], col["clavicle_r"]]].sum(1) > 0.6

    def put(region, sub, bones):
        """region (n,) 0..1: how much of each vertex's weight is `sub` (n, len(bones)) on `bones`."""
        nonlocal W
        if not np.any(region > 0):
            return
        W *= (1 - region)[:, None]
        for j, b in enumerate(bones):
            W[:, col[b]] += region * sub[:, j]

    for side in ("l", "r"):
        sx = 1.0 if side == "l" else -1.0
        # ---- the wing
        spars = {"arm": ["wing_%s" % side, "wing_%s_02" % side, "wing_%s_03" % side]}
        for f in ("f1", "f2", "f3"):
            spars[f] = ["wing_%s_%s" % (side, f)] + ["wing_%s_%s_%02d" % (side, f, i) for i in (2, 3, 4)]
        dist, along = {}, {}
        for k, bones in spars.items():
            pts = [H[bones[0]][0]] + [H[b][1] for b in bones]
            d, sg, t = _chain(P, pts)
            dist[k] = d
            along[k] = _along(bones, sg, t, 0.18)
        keys = list(spars)
        D = np.stack([dist[k] for k in keys], 1)
        d_wing = D.min(1)
        # the wing's skin: its membrane (thin, out on its side) wholly; its flesh where it's nearer the
        # wing's bones than the body's; never the robe (its cloth, or below the wing's lowest point -
        # the robe's long strands hang out beside the hips, nearest a wing's fingertips)
        above = P[:, 2] > WING_LOW + lift
        # (the arm held out in front of the wing: how near its flesh)
        near_arm = np.full(n, 9.0)
        for part in ("clavicle", "upperarm", "lowerarm", "hand"):
            d, _ = _seg_dist(P, *H["%s_%s" % (part, side)])
            near_arm = np.minimum(near_arm, d - body_r[part])
        thin = (thick < 0.02) & (P[:, 0] * sx > 0.05) & (d_wing < MEMBRANE_REACH) & ((d_wing < near_arm) | behind)
        region = np.clip((near_body - d_wing) / WING_SOFT + 0.5, 0, 1)
        # (the robe's cloth by its colour - but nearer the wing's bones than the body, a dark claw)
        robe = cloth & (d_wing > 0.05) & (d_wing > near_body)
        # the membrane: off the body's flesh as far as it is from it (the nearest thick skin not
        # a spar's), eased over ATTACH - and where it's held there, the body's weights are that
        # flesh's own, so the seam along the flank stays whole
        # (the trunk's: the membrane grows from the back and the flank, never the arm held out
        # in front of it - and behind, from under the robe's hood: the hood's edge it's grown into)
        flesh = (d_wing > 0.05) & (((thick > 0.035) & ~cloth & trunk_skin) | (cloth & behind & back_skin))
        fidx = np.nonzero(flesh)[0]
        from mathutils.kdtree import KDTree
        kd = KDTree(len(fidx))
        for j, i in enumerate(fidx):
            kd.insert(P[i], j)
        kd.balance()
        near_f = np.full(n, 9.0)
        near_i = np.zeros(n, int)
        for i in np.nonzero(thin & above & ~robe)[0]:
            _, j, dist = kd.find(P[i])
            near_f[i], near_i[i] = dist, fidx[j]
        d_root = np.linalg.norm(P - H["wing_%s" % side][0], axis=1)
        rooted = 1.0 - np.clip((d_root - ROOT_KEEP[0]) / (ROOT_KEEP[1] - ROOT_KEEP[0]), 0, 1)
        held = thin & above & ~robe & (rooted > 0)
        ease = np.clip((near_f - ATTACH[0]) / (ATTACH[1] - ATTACH[0]), 0, 1)
        ease = 1.0 - (1.0 - ease * ease * (3 - 2 * ease)) * rooted
        region = np.where(held, ease, region)
        W[held] = W[near_i[held]]
        # (behind its back, away from its root, the membrane is the wing's wholly - parted from the back)
        region = np.where(thin & behind & above & ~robe & (rooted <= 0), 1.0, region)
        region = region * (P[:, 0] * sx > 0.05) * (~robe) * above
        allb = [b for k in keys for b in spars[k]]
        sub = np.zeros((n, len(allb)))
        off = {}
        o = 0
        for k in keys:
            off[k] = o
            o += len(spars[k])
        near = np.maximum(D, 0.004) ** -SPAR_POWER
        share = near / near.sum(1, keepdims=True)
        for j, kk in enumerate(keys):
            sub[:, off[kk]:off[kk] + len(spars[kk])] = share[:, j:j + 1] * along[kk]
        put(region, sub, allb)
        log("wing %s: %d vertices (%d wholly)" % (side, int((region > 0).sum()), int((region > 0.99).sum())))
        # ---- the hand
        fingers = {f: ["%s_%02d_%s" % (f, i, side) for i in (1, 2, 3)] for f in HAND}
        hand = "hand_" + side
        wrist, knuck = H[hand][0], H[hand][1]
        fwd = (knuck - wrist) / np.linalg.norm(knuck - wrist)
        past = (P - wrist) @ fwd
        dh, _ = _seg_dist(P, wrist, knuck)
        fd, fa = {"palm": dh}, {"palm": np.ones((n, 1))}
        for f, bones in fingers.items():
            pts = [H[bones[0]][0]] + [H[b][1] for b in bones]
            d, sg, t = _chain(P, pts)
            fd[f], fa[f] = d, _along(bones, sg, t, 0.25)
        fk = list(fd)
        FD = np.stack([fd[k] for k in fk], 1)
        fo = np.argsort(FD, 1)
        near_hand = FD.min(1) < 0.06
        hreg = np.clip((past + 0.01) / 0.03, 0, 1) * near_hand * (P[:, 0] * sx > 0.5)
        hb = [hand] + [b for f in fingers for b in fingers[f]]
        hoff = {"palm": 0}
        o = 1
        for f in fingers:
            hoff[f] = o
            o += 3
        sub = np.zeros((n, len(hb)))
        a_i, b_i = fo[:, 0], fo[:, 1]
        da = FD[np.arange(n), a_i]
        db = FD[np.arange(n), b_i]
        wa = db ** 4 / np.maximum(da ** 4 + db ** 4, 1e-16)
        for i in np.nonzero(hreg > 0)[0]:
            for kk, w in ((fk[a_i[i]], wa[i]), (fk[b_i[i]], 1 - wa[i])):
                width = fa[kk].shape[1]
                sub[i, hoff[kk]:hoff[kk] + width] += w * fa[kk][i]
        put(hreg, sub, hb)
        log("hand %s: %d vertices" % (side, int((hreg > 0).sum())))
    # ---- the tail
    tb = ["tail_%02d" % (i + 1) for i in range(TAIL_BONES)]
    pts = [H[tb[0]][0]] + [H[b][1] for b in tb]
    dt_, sg, t = _chain(P, pts)
    # how far along it from its root (m)
    lens = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
    cum = np.concatenate([[0], np.cumsum(lens)])
    s_along = cum[sg] + t * np.array(lens)[sg]
    near_legs = np.full(n, 9.0)
    for nm in ("thigh_l", "thigh_r", "calf_l", "calf_r"):
        d, _ = _seg_dist(P, *H[nm])
        near_legs = np.minimum(near_legs, d - 0.07)
    radius = np.interp(s_along, [0, 0.3, 0.6, 1.0], [0.12, 0.09, 0.06, 0.04])
    # (its spikes are pale bone: not cloth, near its line)
    robe = cloth & (dt_ > radius)
    # (eased into the body - the legs', its hips' - over a few cm, so the root bends, not tears)
    treg = np.clip((s_along - 0.05) / 0.1, 0, 1) * np.clip((radius * 1.6 - dt_) / 0.04 + 0.5, 0, 1) \
        * np.clip((near_legs - dt_) / 0.05 + 0.5, 0, 1) * (~robe)
    put(treg, _along(tb, sg, t, 0.4), tb)
    log("tail: %d vertices (%d wholly)" % (int((treg > 0).sum()), int((treg > 0.99).sum())))
    # Where Meshy grew the membrane onto the body - onto the arm held out in front of it, into the
    # back below the wing's root (ROOT_KEEP) - the two are parted, not a face lost: each face is the
    # wing's or the body's by its vertices' shares, and the edges between a wing face and a body
    # face are split, so each side keeps its own copy of those vertices (the wing's on the wing's
    # bones alone, the body's on its own) - at rest they lie where they were; moving, the membrane's
    # edge comes away clean instead of dragging the body after it. About its root it stays whole -
    # the wing grows from its shoulder. So too the tail from the robe over it (TAIL_KEEP).
    wing_cols = [col[b] for b in names if b.startswith("wing")]
    tail_cols = [col[b] for b in names if b.startswith("tail")]
    wing_share = W[:, wing_cols].sum(1)
    tail_share = W[:, tail_cols].sum(1)
    roots = [H["wing_l"][0], H["wing_r"][0]]
    tail_root = H["tail_01"][0]
    bm = bmesh.new()
    bm.from_mesh(me)
    orig = bm.verts.layers.int.new("orig")
    for v in bm.verts:
        v[orig] = v.index
    kind = {}
    for f in bm.faces:
        vs = [v.index for v in f.verts]
        kind[f] = "w" if np.mean(wing_share[vs]) > 0.5 else "t" if np.mean(tail_share[vs]) > 0.5 \
            else "r" if np.mean(cloth[vs]) > 0.5 else "b"

    def mid(e):
        m = (np.array(e.verts[0].co) + np.array(e.verts[1].co)) * 0.5
        return np.array(body.matrix_world @ Vector(m))

    def parted(e):
        if len(e.link_faces) != 2:
            return False
        ks = {kind[e.link_faces[0]], kind[e.link_faces[1]]}
        if "w" in ks and len(ks) == 2:
            return min(np.linalg.norm(mid(e) - r) for r in roots) >= ROOT_KEEP[0]
        if "t" in ks and len(ks) == 2:
            return np.linalg.norm(mid(e) - tail_root) >= TAIL_KEEP
        return False
    seam = [e for e in bm.edges if parted(e)]
    bmesh.ops.split_edges(bm, edges=seam)
    bm.verts.ensure_lookup_table()
    rows = np.array([v[orig] for v in bm.verts])
    side_of = []
    for v in bm.verts:
        ks = {kind.get(f, "") for f in v.link_faces}
        # (the body's side: anything not the wing's - for the tail's seam, the tail's or the robe's)
        side_of.append("w" if ks == {"w"} else "b" if ks and "w" not in ks and "t" not in ks
                       else "t" if ks == {"t"} else "")
    bm.verts.layers.int.remove(orig)
    bm.to_mesh(me)
    bm.free()
    me.update()
    W = W[rows]
    split = len(rows) - n
    n = len(rows)
    # (each copy on its own side's bones - and away from the roots, any vertex all of whose faces
    # are one side's: what it had of them - or, had it none, its neighbours' on that side)
    Pn = np.array([tuple(body.matrix_world @ v.co) for v in me.vertices])
    far = np.min([np.linalg.norm(Pn - r, axis=1) for r in roots], 0) > ROOT_KEEP[1]
    sided = np.array([k in ("w", "b") for k in side_of])
    doubled = np.nonzero((np.bincount(rows)[rows] > 1) | (far & sided))[0]
    nbr = {int(i): [] for i in doubled}
    for e in me.edges:
        a, b = e.vertices
        if a in nbr:
            nbr[a].append(b)
        if b in nbr:
            nbr[b].append(a)
    before = W.copy()
    at_tail = (np.bincount(rows)[rows] > 1) & (np.linalg.norm(Pn - tail_root, axis=1) >= TAIL_KEEP)
    every = np.arange(len(names))
    for i in doubled:
        if side_of[i] == "w":
            keep = np.isin(every, wing_cols)
        elif side_of[i] == "t" and at_tail[i]:
            keep = np.isin(every, tail_cols)
        elif side_of[i] == "b":
            keep = ~np.isin(every, wing_cols + (tail_cols if at_tail[i] else []))
        else:
            continue
        if before[i, keep].sum() < 0.05:
            own = [j for j in nbr[int(i)] if before[j, keep].sum() > 0.5]
            if not own:
                continue
            W[i] = before[own].mean(0)
        W[i, ~keep] = 0.0
        if W[i].sum() < 1e-6:
            W[i] = before[i]
    s_ = W.sum(1)
    W[s_ > 0] /= s_[s_ > 0][:, None]
    log("membrane parted from the body: %d edges split, %d vertices doubled" % (len(seam), split))
    # at most four bones each, adding up to one
    order = np.argsort(-W, 1)[:, :4]
    top = np.take_along_axis(W, order, 1)
    top = np.where(top < 0.01, 0.0, top)
    top /= np.maximum(top.sum(1, keepdims=True), 1e-9)
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    groups = {nm: body.vertex_groups.new(name=nm) for nm in names}
    for i in range(n):
        for j in range(4):
            if top[i, j] > 0:
                groups[names[order[i, j]]].add([i], float(top[i, j]), 'REPLACE')
    log("weights written: %d with none" % int((top.sum(1) == 0).sum()))


# ------------------------------------------------------------ the clips

def carry(arm, src):
    """The second make's clips carried onto `arm`: {name: action}."""
    out = {}
    mapping = [b.name for b in arm.data.bones
               if b.name in src.data.bones and not b.name.startswith(("wing", "tail")) and b.name != "root"]
    for game in CLIPS:
        loop = game in LOOPING
        clip = retarget.Clip(src, game, mapping, SAMPLES if loop else SAMPLES + 1, loop=loop, ref="rest")
        src_hips = (src.matrix_world @ src.data.bones["pelvis"].head_local).z
        k = arm.data.bones["pelvis"].head_local.z / max(src_hips, 1e-6)
        ad = arm.animation_data or arm.animation_data_create()
        ad.action = None
        for pb in arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.matrix_basis.identity()
        poses = []
        n = len(clip.times)
        for i in range(n):
            aim = {b: d for b, d in clip.dirs(i).items() if b in ARM_AIM}
            retarget.apply(arm, clip.delta(i), {b: b for b in mapping}, 1.0, aim=aim, offset=clip.offset(i) * k)
            poses.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in arm.pose.bones})
        act = bpy.data.actions.new(game)
        act.use_fake_user = True
        ad.action = act
        span = (clip.times[-1] - clip.times[0]) * (n / max(n - 1, 1) if loop else 1.0)
        step = span / n if loop else span / max(n - 1, 1)
        frames = [1 + i * step for i in range(n)] + ([1 + n * step] if loop else [])
        if loop:
            poses.append(poses[0])
        for f, pose in zip(frames, poses):
            for pb in arm.pose.bones:
                pb.location, pb.rotation_quaternion = pose[pb.name]
                pb.keyframe_insert("location", frame=f)
                pb.keyframe_insert("rotation_quaternion", frame=f)
        ad.action = None
        out[game] = act
        log("clip %s: %d keys over %.0f frames" % (game, len(frames), frames[-1] - 1))
    return out


def main():
    cache = OUT + ".mesh.blend"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if os.path.exists(cache) and STAGE != "mesh":
        with bpy.data.libraries.load(cache) as (src, dst):
            dst.objects = [n for n in src.objects]
        for o in dst.objects:
            if o is not None:
                bpy.context.scene.collection.objects.link(o)
        body = bpy.data.objects["DragonGhost"]
        lift = float(body["lift"])
        log("mesh from the cache: %d triangles" % len(body.data.polygons))
    else:
        body, lift = mesh()
        body["lift"] = lift
        for img in bpy.data.images:
            if img.size[0] > 0 and img.name.startswith("DragonGhost"):
                img.pack()
        bpy.ops.wm.save_as_mainfile(filepath=cache)
        if STAGE == "mesh":
            return
    spec = joints(lift)
    arm = skeleton(spec)
    weights(body, arm, spec)
    if STAGE == "weights":
        bpy.ops.wm.save_as_mainfile(filepath=OUT + ".weights.blend")
        return
    src = retarget.load_library(OLD)
    for o in src.children:
        o.hide_render = True
    clips = carry(arm, src)
    for o in [src] + list(src.children):
        bpy.data.objects.remove(o, do_unlink=True)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    for game, a in clips.items():
        tr = ad.nla_tracks.new()
        tr.name = game
        st = tr.strips.new(game, int(a.frame_range[0]), a)
        st.name = game
        tr.mute = True
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    select([arm, body], active=arm)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
                              export_anim_single_armature=True, export_def_bones=False,
                              export_image_format='JPEG', export_jpeg_quality=88)
    log("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__" and STAGE == "skeleton":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=SAGE)
    hi = next(o for o in bpy.data.objects if o.type == 'MESH')
    lift = -min((hi.matrix_world @ v.co).z for v in hi.data.vertices)
    hi.location.z += lift
    arm = skeleton(joints(lift))
    bpy.ops.wm.save_as_mainfile(filepath=OUT)
    raise SystemExit(0)


if __name__ == "__main__" and STAGE != "skeleton":
    main()
    os._exit(0)     # (bpy can fall over tearing itself down)
