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
  RED_TEX    (optional) the colour picture of the user's red dragon (an open
             model, kept out of the repo too: "DRAGON-wings_wings, teeth,
             eye_BaseColor.jpg") - its eye is cut from it (see EYE)

  bpyenv/bin/python tools/build_dragon_sage.py SAGE_FBX OLD_GLB OUT.glb [RED_TEX]

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

_ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
SAGE, OLD, OUT = _ARGS[:3]
RED = _ARGS[3] if len(_ARGS) > 3 else None
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
    # the lower jaw: from its hinge behind the mouth's corner to the chin (see JAW)
    "jaw": (V3(0, -0.392, 0.616), V3(0, -0.512, 0.592), "Head"),
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
# A second tail (tools/build_dragon_warden.py - the black two-tailed one): its line and bones
# (tail_b01..), weighted as the first is. None here.
TAIL2_LINE = []
TAIL2_BONES = 8
# (user request, the black dragon: its two tails one size, both behind it - not one swept out to
# its side, the other hanging: the main tail shortened to the second's length - `thick` its width
# kept - and both posed as the second hangs, each swung `spread` degrees out to its own side, then
# made their rest. None: as made)
TAILS_EVEN = None
# What this build makes beyond the skeleton (another dragon's build - tools/build_dragon_warden.py -
# turns off what it hasn't measured yet): the mouth cut and parted, its eyes and teeth, the skin's
# red deepened, the skirt's chains, the skirt draped
FEATURES = {"mouth": True, "eyes": True, "deepen": True, "skirt": True, "drape": True}
# User request: its mouth opens. The lips are one skin (Meshy closed the mouth) and the head too
# coarse for an edge to run along them, so the snout is cut through (before anything else) on the
# plane along the line between them, level across (JAW_LIP: (y, z) at the snout's tip and at the
# mouth's corner - measured off the head side-on), as far back as the corner (JAW_CORNER) and parted
# there, the lower jaw on its own bone below it, fading into the throat behind (JAW_FADE: y, and
# z where the neck begins); each lip's edge closed by a dark palate / tongue going in, so the open
# mouth shows a dark maw, not the inside of the head.
JAW_LIP = ((-0.512, 0.600), (-0.42, 0.625))
JAW_CORNER = -0.415
JAW_WIDE = 0.08
# (user report: the throat went with the jaw, pulled into a sheet - the jaw is only what's ahead of
# its hinge, above the throat)
JAW_FADE = ((-0.39, -0.43), (0.545, 0.57))
# (the snout's box, as made: its half width, its bottom and top - what's cut on the lips; and how far
# back and how low the jaw's skin can be at all)
SNOUT_BOX = (0.1, 0.5, 0.72)
JAW_REACH = (-0.33, 0.45)
# (user report: still a strip between the lips, the mouth open) Bone heat had the snout ~20% on the
# neck - turning the head, the upper jaw lagged the lower (the jaw's, rigid); and a vertex just under
# the lips' plane was left the head's among the jaw's. The skull is rigid now - ahead of the neck
# (SKULL: y, from none to wholly; above the throat, z from none to wholly) all the head's, and the
# horns (above SKULL_HORNS z) - and the lower jaw is what's under the parted lips, face by face.
SKULL = ((-0.33, -0.37), (0.565, 0.585))
SKULL_HORNS = 0.74
# User request: eyes and teeth - the model has none (Meshy left only shading where they'd be) -
# after the user's red dragon (an eye with a slit pupil set into the head under its brow; a row of
# pale cone teeth along each jaw, tilted back). User reports: the eye put first on the cheek, then on
# the snout's slope - it goes in the crease under the brow each side of the snout (the user marked
# it), set into the head, a slit, green with a faint glow as the first dragon's. That crease is in
# the model, though shallow (the cheek stands ~1 cm out below it, the brow only slopes in above): the
# skin about it is made finer (EYE_FINE: within this of the eye, its edges cut this many times), the
# socket pressed into it and the brow drawn out and down over it (EYE_SOCKET: across, along, deep - m;
# the brow's lift), the eye set in the socket's bottom - green (its iris's grain the red dragon's eye's,
# the build's fourth input; plain without it), glowing faintly (an emission picture, EYE_GLOW its
# strength). Its picture, the teeth's colour and the mouth's painted into free corners of the colour
# picture (one material still).
# EYE: where the crease is (z, y as made; x its bottom, found from the side), the eye's half length (m)
# and how tall (share), how much of it stands out of the socket's bottom (share of its depth), how
# deep (share of its half length), its slant along the crease (deg, its outer corner up), which way
# it looks (the left one, blended with the skin's own way out: out, ahead, up)
EYE = {"at": (-0.471, 0.644), "r": 0.0085, "tall": 0.42, "out": 0.45, "deep": 0.6, "slant": 22.0,
       "look": (1.0, -0.35, 0.1)}
EYE_FINE = (0.024, 3)
EYE_SOCKET = {"across": 0.0075, "along": 0.0135, "deep": 0.0028, "brow": 0.0018}
EYE_GREEN = ((0.85, 1.0, 0.5), (0.3, 0.95, 0.42), (0.04, 0.32, 0.12))   # its middle, its iris, its rim
EYE_GLOW = 0.22
EYE_GLOW_TINT = (0.25, 1.0, 0.35)   # (its glow greener than its colour)
SHIP_GLOW = 1024
# User request: the skin the first dragon's deep red, not this one's pink. Measured on the two colour
# pictures (their red skin - the robe, the bone, the pale belly aside): this one's brightness 0.70
# (spread 0.12), saturation 0.45 (0.08); the first one's 0.49 (0.13), 0.59 (0.14), the same hue. The
# skin's brightness and saturation are moved onto the first one's (SKIN_TONE: (from, to, spread
# kept)), by how plainly red each texel is - the bone, the robe, the patches painted in left be.
SKIN_TONE = {"v": (0.697, 0.486, 1.0), "s": (0.454, 0.586, 1.3)}
# (another dragon's robe lightened - tools/build_dragon_warden.py: its cloth, dark and grey, this much
# brighter; none here)
ROBE_LIGHTEN = 1.0
# TEETH: along each lip from its front to its back (y), each tooth's length (m) front to back on each
# side, above and below, how thick at its root (share of its length); rooted under the lip's skin
# (TOOTH_ROOT m in from its edge, above / below the plane), tilted back (share of its length)
TEETH_Y = (-0.503, -0.428)
TEETH_UPPER = (0.010, 0.018, 0.016, 0.014, 0.013, 0.012, 0.011, 0.010)
TEETH_LOWER = (0.009, 0.015, 0.013, 0.012, 0.011, 0.010, 0.009)
TOOTH_BASE = 0.2
TOOTH_ROOT = (0.003, 0.002)
TOOTH_BACK = (0.25, 0.1)
# (the red dragon's eye in its picture: its centre, and the radius of its iris, UV)
RED_EYE = ((0.783, 0.797), 0.14)
# User request: the robe flows. Its skirt hangs on SKIRT_CHAINS chains of SKIRT_BONES bones round
# the hips (front, front-left, ... - joints measured off the robe itself, from its belt, SKIRT_TOP,
# down to near its hem), swung by DragonRig as the tail is; each skirt vertex shared between the two
# chains nearest round it and along its chain, eased in from the belt over SKIRT_EASE (m).
SKIRT_CHAINS = 8
SKIRT_BONES = 3
SKIRT_TOP = 0.04
SKIRT_EASE = 0.12
SKIRT_CENTRE = (0.0, -0.34)
# (m) thin enough to be its strands (wholly ... not at all); off the legs' bones (never nearer -
# their flesh; wholly beyond - the front panel, however thick)
SKIRT_THIN = (0.025, 0.045)
SKIRT_LEG = (0.06, 0.13)
SKIRT_CLEAR = 0.12
# User request: the skirt's four panels hang - the model (made from a drawing) has them flared out,
# the left one most, as if blown. Once weighted, each skirt vertex is turned down in its own
# upright plane about the belt toward a hang: any flare past DRAPE[0] deg kept only DRAPE[1] of -
# smoothed over the skin (DRAPE_SMOOTH passes), so a strand turns as one and keeps its thickness;
# never into the legs (DRAPE_LEG m off their bones). Its chains' joints turned alike.
DRAPE = (12.0, 0.25)
DRAPE_SMOOTH = 12
DRAPE_LEG = 0.085
# User request: the sleeves hang too. The model holds its arms straight out, its shoulders' cloth
# lying out along them; weighted to the shoulder it stayed out flat when the arm came down. Past the
# shoulder's joint (SLEEVE_EASE m along the upper arm: none .. wholly) its cloth - dark, or thin as
# its pale ragged edges are - goes with the arm.
SLEEVE_EASE = (-0.04, 0.05)
SLEEVE_NEAR = 0.2
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


def _dense(co, th):
    """Whether a vertex (as made) is kept denser by the decimation: the wings' thin skin, the hands."""
    return (th < 0.016 and abs(co.x) > 0.24 and co.z > -0.12 and co.y > -0.22) \
        or (abs(co.x) > 0.68 and co.y < -0.15 and 0.15 < co.z < 0.5)   # (their fingers close on the bail)


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
    idx = [v.index for v in lo.data.vertices if _dense(v.co, th[v.index])]
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

def _tail_joints(line=None, bones=None):
    """A tail's line (TAIL_LINE) resampled into its bones (TAIL_BONES), each TAIL_TAPER of the one before."""
    line = TAIL_LINE if line is None else line
    TAIL_BONES_ = TAIL_BONES if bones is None else bones
    pts = [p.copy() for p in line]
    seg = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(seg)
    share = [TAIL_TAPER ** i for i in range(TAIL_BONES_)]
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


def _lip_z(y):
    """The lip line's height (z, as made) at `y` (see JAW_LIP)."""
    (y0, z0), (y1, z1) = JAW_LIP
    return z0 + (np.asarray(y) - y0) * (z1 - z0) / (y1 - y0)


def cut_mouth(body, lift):
    """The snout cut through on the lips' plane (see JAW_LIP): an edge along each lip."""
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    mw = body.matrix_world
    inv = mw.inverted()

    def snout(f):
        for v in f.verts:
            q = mw @ v.co
            if not (q.y < JAW_CORNER + 0.005 and abs(q.x) < SNOUT_BOX[0] and SNOUT_BOX[1] + lift < q.z < SNOUT_BOX[2] + lift):
                return False
        return True
    faces = [f for f in bm.faces if snout(f)]
    geom = faces + list({e for f in faces for e in f.edges}) + list({v for f in faces for v in f.verts})
    (y0, z0), (y1, z1) = JAW_LIP
    along = Vector((0.0, y1 - y0, z1 - z0)).normalized()
    no = Vector((1.0, 0.0, 0.0)).cross(along).normalized()
    if no.z < 0:
        no = -no
    before = len(bm.verts)
    bmesh.ops.bisect_plane(bm, geom=geom, dist=0.0005, plane_co=inv @ Vector((0.0, y0, z0 + lift)),
                           plane_no=(inv.to_3x3() @ no).normalized())
    log("mouth: the snout cut on its lips (%d faces, %d new vertices)" % (len(faces), len(bm.verts) - before))
    bm.to_mesh(me)
    bm.free()
    me.update()


def _skirt_angle(P):
    """Each point's angle round the hips (deg: 0 ahead, +90 its left)."""
    return np.degrees(np.arctan2(P[:, 0] - SKIRT_CENTRE[0], -(P[:, 1] - SKIRT_CENTRE[1])))


def _skirt_region(body, lift, spec, thick):
    """Per vertex 0..1: how much of it is the robe's skirt - below its belt, thin (its hanging
    strands, a cm or two) or well away from the legs (its front panel), never the legs' own flesh;
    eased in from the belt, and smoothed over the skin so it fades, not steps, into the body."""
    me = body.data
    P = np.array([tuple(body.matrix_world @ v.co) for v in me.vertices])
    zm = P[:, 2] - lift
    dl = np.full(len(P), 9.0)
    df = np.full(len(P), 9.0)
    for part in ("thigh", "calf", "foot", "ball"):
        for side in ("l", "r"):
            h, t, _ = spec["%s_%s" % (part, side)]
            d, _ = _seg_dist(P, np.array(h), np.array(t))
            dl = np.minimum(dl, d)
            if part in ("foot", "ball"):
                df = np.minimum(df, d)
    thin = np.clip((SKIRT_THIN[1] - thick) / (SKIRT_THIN[1] - SKIRT_THIN[0]), 0, 1)
    far = np.clip((dl - SKIRT_LEG[1]) / 0.04, 0, 1) * (zm > -0.65)
    r = np.maximum(thin, far) * (zm < SKIRT_TOP)
    ed = np.zeros(len(me.edges) * 2, int)
    me.edges.foreach_get("vertices", ed)
    ed = ed.reshape(-1, 2)
    deg = np.bincount(ed.ravel(), minlength=len(P)).astype(float)
    for _ in range(4):
        acc = np.zeros(len(P))
        np.add.at(acc, ed[:, 0], r[ed[:, 1]])
        np.add.at(acc, ed[:, 1], r[ed[:, 0]])
        r = 0.5 * r + 0.5 * acc / np.maximum(deg, 1)
    r *= np.clip((SKIRT_TOP - zm) / SKIRT_EASE, 0, 1)
    r *= np.clip((dl - SKIRT_LEG[0]) / 0.05, 0, 1)
    # (nor the feet's claws - thin too, past their bones' ends)
    r *= np.clip((df - 0.10) / 0.04, 0, 1)
    return r


def skirt_joints(body, lift, spec, thick):
    """{name: (head, tail, parent)} for the skirt's chains, measured off the robe."""
    P = np.array([tuple(body.matrix_world @ v.co) for v in body.data.vertices])
    P[:, 2] -= lift
    reg = _skirt_region(body, lift, spec, thick)
    tb = ["tail_%02d" % (i + 1) for i in range(TAIL_BONES)]
    tpts = [np.array(spec[tb[0]][0])] + [np.array(spec[b][1]) for b in tb]
    Pw = P.copy()
    Pw[:, 2] += lift
    dt_, _, _ = _chain(Pw, tpts)
    r_all = np.hypot(P[:, 0] - SKIRT_CENTRE[0], P[:, 1] - SKIRT_CENTRE[1])
    ang_all = _skirt_angle(P)
    # (its strands - not the folded wings' tips hanging beside them, nor the tail)
    strand = (reg > 0.5) & (dt_ > 0.14) & (r_all < 0.5)
    belt = np.abs(P[:, 2] - SKIRT_TOP) < 0.03
    out = {}
    up = Vector((0, 0, lift))
    for k in range(SKIRT_CHAINS):
        a = 360.0 * k / SKIRT_CHAINS
        d = (ang_all - a + 180.0) % 360.0 - 180.0
        inside = np.abs(d) < 0.6 * 360.0 / SKIRT_CHAINS
        S, r = P[inside & strand], r_all[inside & strand]
        bottom = float(np.clip(np.percentile(S[:, 2], 6), -0.62, -0.25))
        # (its radius straight from the belt - the waist's own - to the hem: the strands' own
        # scatter doesn't kink it)
        top_r = float(np.median(r_all[inside & belt & (r_all < 0.4)]))
        low = S[:, 2] < bottom + 0.12
        low_r = float(np.median(r[low] if low.sum() > 3 else r))
        rr = math.radians(a)
        out_dir = np.array([math.sin(rr), -math.cos(rr), 0.0])
        pts = []
        last = 0.0
        for i in range(SKIRT_BONES + 1):
            f = i / SKIRT_BONES
            z = SKIRT_TOP + (bottom - SKIRT_TOP) * f
            # (never in again below where it's been pushed out: it hangs, flaring)
            rad = max((top_r + (low_r - top_r) * f) * 0.92, last)
            # (and clear of the legs as they stand - they swing into it, not start inside it)
            while rad < 0.6:
                q = np.array([SKIRT_CENTRE[0], SKIRT_CENTRE[1], z + lift]) + out_dir * rad
                if min(float(_seg_dist(q[None], np.array(spec[nm][0]), np.array(spec[nm][1]))[0][0])
                       for nm in ("thigh_l", "thigh_r", "calf_l", "calf_r")) >= SKIRT_CLEAR:
                    break
                rad += 0.01
            last = rad
            pts.append(Vector((SKIRT_CENTRE[0] + rad * math.sin(rr), SKIRT_CENTRE[1] - rad * math.cos(rr), z)) + up)
        for i in range(SKIRT_BONES):
            name = "skirt_%d_%02d" % (k, i + 1)
            out[name] = (pts[i], pts[i + 1], "pelvis" if i == 0 else "skirt_%d_%02d" % (k, i))
    return out


def drape_skirt(body, arm, lift):
    """The skirt turned down to hang (see DRAPE): its skin, and its chains' joints."""
    me = body.data
    n = len(me.vertices)
    skirt_groups = {g.index for g in body.vertex_groups if g.name.startswith("skirt_")}
    share = np.zeros(n)
    for v in me.vertices:
        for g in v.groups:
            if g.group in skirt_groups:
                share[v.index] += g.weight
    mw = body.matrix_world
    P = np.array([tuple(mw @ v.co) for v in me.vertices])
    cx, cy = SKIRT_CENTRE
    # (the belt's own radius round the hips, every 10 deg, smoothed round)
    def polar(Q):
        r = np.hypot(Q[:, 0] - cx, Q[:, 1] - cy)
        return r, _skirt_angle(Q)
    r, ang = polar(P)
    belt = (np.abs(P[:, 2] - lift - SKIRT_TOP) < 0.03) & (r < 0.4)
    bins = np.full(36, np.nan)
    for k in range(36):
        d = np.abs((ang - (k * 10.0 - 175.0) + 180.0) % 360.0 - 180.0) < 5.0
        if (d & belt).sum() >= 3:
            bins[k] = np.median(r[d & belt])
    good = ~np.isnan(bins)
    idx = np.arange(36)
    bins = np.interp(idx, idx[good], bins[good], period=36)
    bins = (np.roll(bins, 1) + 2.0 * bins + np.roll(bins, -1)) / 4.0
    centres = idx * 10.0 - 175.0

    def belt_r(a):
        return np.interp(a, centres, bins, period=360.0)
    t0 = math.radians(DRAPE[0])

    def hang(phi):
        return np.where(phi > t0, t0 + (phi - t0) * DRAPE[1], phi)

    def turned(Q, base, dphi):
        r_, a_ = polar(Q)
        dr = r_ - base
        dz = lift + SKIRT_TOP - Q[:, 2]
        L = np.hypot(dr, dz)
        phi = np.arctan2(dr, dz) + dphi
        nr = base + L * np.sin(phi)
        ux = (Q[:, 0] - cx) / np.maximum(r_, 1e-6)
        uy = (Q[:, 1] - cy) / np.maximum(r_, 1e-6)
        out = Q.copy()
        out[:, 0] = cx + ux * nr
        out[:, 1] = cy + uy * nr
        out[:, 2] = lift + SKIRT_TOP - L * np.cos(phi)
        return out
    base = belt_r(ang)
    dz = lift + SKIRT_TOP - P[:, 2]
    phi = np.arctan2(r - base, dz)
    delta = (hang(phi) - phi) * share * (dz > 0)
    ed = np.zeros(len(me.edges) * 2, int)
    me.edges.foreach_get("vertices", ed)
    ed = ed.reshape(-1, 2)
    on = share > 0.0
    keep = on[ed[:, 0]] & on[ed[:, 1]]
    ed = ed[keep]
    deg = np.bincount(ed.ravel(), minlength=n).astype(float)
    for _ in range(DRAPE_SMOOTH):
        acc = np.zeros(n)
        np.add.at(acc, ed[:, 0], delta[ed[:, 1]])
        np.add.at(acc, ed[:, 1], delta[ed[:, 0]])
        delta = np.where(on, np.where(deg > 0, 0.5 * delta + 0.5 * acc / np.maximum(deg, 1), delta), 0.0)
    Q = turned(P, base, delta)
    # (never into the legs as they stand)
    legs = []
    for side in ("l", "r"):
        for a_, b_ in (("thigh", "calf"), ("calf", "foot")):
            ha = np.array(arm.data.bones["%s_%s" % (a_, side)].head_local)
            hb = np.array(arm.data.bones["%s_%s" % (b_, side)].head_local)
            legs.append((ha, hb))
    moved = 0
    for i in np.nonzero(on & (np.abs(delta) > 1e-4))[0]:
        for a_, b_ in legs:
            d, _ = _seg_dist(Q[i:i + 1], a_, b_)
            if d[0] < DRAPE_LEG:
                ab = b_ - a_
                tq = np.clip(((Q[i] - a_) @ ab) / (ab @ ab), 0, 1)
                off = Q[i] - (a_ + tq * ab)
                Q[i] = a_ + tq * ab + off / max(np.linalg.norm(off), 1e-6) * DRAPE_LEG
        moved += 1
    inv = mw.inverted()
    for i in np.nonzero(on)[0]:
        me.vertices[i].co = inv @ Vector(tuple(Q[i]))
    me.update()
    log("skirt draped: %d vertices turned (flare %.0f deg most -> %.0f)" % (
        moved, math.degrees(float(phi[on & (dz > 0)].max())) if on.any() else 0.0,
        math.degrees(float(hang(phi[on & (dz > 0)]).max())) if on.any() else 0.0))
    # its chains' joints, turned alike
    select([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.data.edit_bones
    joints_ = {}
    for b in eb:
        if b.name.startswith("skirt_"):
            joints_[b.name] = (np.array(b.head), np.array(b.tail))
    for name, (h, t) in joints_.items():
        J = np.array([h, t])
        rj, aj = polar(J)
        bj = belt_r(aj) * 0.92
        phij = np.arctan2(rj - bj, lift + SKIRT_TOP - J[:, 2])
        dj = np.where(lift + SKIRT_TOP - J[:, 2] > 1e-4, hang(phij) - phij, 0.0)
        Jn = turned(J, bj, dj)
        eb[name].head = Vector(tuple(Jn[0]))
        eb[name].tail = Vector(tuple(Jn[1]))
    bpy.ops.object.mode_set(mode='OBJECT')


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
    if TAIL2_LINE:
        tj = _tail_joints(TAIL2_LINE, TAIL2_BONES)
        for i in range(TAIL2_BONES):
            out["tail_b%02d" % (i + 1)] = (tj[i] + up, tj[i + 1] + up, "pelvis" if i == 0 else "tail_b%02d" % i)
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



def even_tails(body, arm):
    """The two tails posed alike behind it (TAILS_EVEN), the body skinned to them, that pose its rest."""
    from mathutils import Matrix
    spread = math.radians(TAILS_EVEN["spread"])
    thick = TAILS_EVEN["thick"]

    def turned(line, ang):
        R = Matrix.Rotation(ang, 3, 'Z')
        return [line[0] + R @ (p - line[0]) for p in line]
    # (its right is -x: the main tail, swept out to its right as made, stays on its right)
    chains = (("tail_%02d", TAIL_BONES, turned(TAIL2_LINE, spread)),
              ("tail_b%02d", TAIL2_BONES, turned(TAIL2_LINE, -spread)))
    # (a tail's skin past its root its own: bone heat gave the main tail's, wound round the leg, a
    # share of the leg's - left behind as the tail swung, it tore out in a flap)
    me = body.data
    groups = {g.index: g.name for g in body.vertex_groups}
    for fmt, n, line in chains:
        own = {fmt % (i + 1) for i in range(n)}
        root = arm.data.bones[fmt % 1].head_local
        for v in me.vertices:
            tw = sum(g.weight for g in v.groups if groups[g.group] in own)
            if tw < 0.5 or (body.matrix_world @ v.co - root).length < TAILS_EVEN["root"]:
                continue
            for g in list(v.groups):
                if groups[g.group] not in own:
                    body.vertex_groups[g.group].remove([v.index])
            for g in v.groups:
                g.weight /= tw
    select([arm], active=arm)
    bpy.ops.object.mode_set(mode='POSE')
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    for fmt, n, line in chains:
        names = [fmt % (i + 1) for i in range(n)]
        bones = [arm.data.bones[b] for b in names]
        js = _tail_joints(line, n)
        root = bones[0].head_local.copy()
        js = [root + (j - js[0]) for j in js]
        was = sum((b.tail_local - b.head_local).length for b in bones)
        for i, b in enumerate(bones):
            pb = arm.pose.bones[b.name]
            rest = b.matrix_local
            d0 = (b.tail_local - b.head_local)
            d1 = js[i + 1] - js[i]
            q = d0.normalized().rotation_difference(d1.normalized())
            rot = q.to_matrix() @ rest.to_3x3().normalized()
            scale = Matrix.Diagonal((thick, d1.length / d0.length, thick))
            pb.matrix = Matrix.Translation(js[i]) @ (rot @ scale).to_4x4()
            bpy.context.view_layer.update()
        log("tail %s: %.2f m -> %.2f m, swung %+.0f deg, behind it" % (
            fmt % 1, was, sum((js[i + 1] - js[i]).length for i in range(n)), math.degrees(spread if fmt == "tail_%02d" else -spread)))
    bpy.ops.object.mode_set(mode='OBJECT')
    # the body skinned to that pose; the pose made the skeleton's rest
    mod = next(m for m in body.modifiers if m.type == 'ARMATURE')
    name = mod.name
    select([body], active=body)
    bpy.ops.object.modifier_apply(modifier=name)
    m = body.modifiers.new(name, 'ARMATURE')
    m.object = arm
    while body.modifiers[0] != m:
        bpy.ops.object.modifier_move_up(modifier=name)
    select([arm], active=arm)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')


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


def _picture(body, name):
    return next(n.image for n in body.data.materials[0].node_tree.nodes
                if n.type == 'TEX_IMAGE' and n.image and n.image.name == name)


# (texels a side of each painted patch - the eye's picture, the teeth's colour root to tip, the
# palate's and the tongue's - in the colour picture, SHIP_COLOUR a side)
ROOMS = {"eye": 80, "teeth": 32, "palate": 32, "tongue": 32}
ROOM = {}


def paint_rooms(body):
    """The eye's picture, the teeth's and the mouth's colours painted where no face of the skin has its
    UV (each patch a few texels clear of any): ROOM[name] = its (u0, v0, u1, v1). Their normal flat,
    their roughness their own."""
    me = body.data
    uv = np.empty(len(me.loops) * 2, np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    k = 4                                           # texels a cell
    g = SHIP_COLOUR // k
    used = np.zeros((g, g), bool)
    for p in me.polygons:
        q = uv[p.loop_start:p.loop_start + p.loop_total] * g
        lo = np.clip(np.floor(q.min(0)).astype(int), 0, g - 1)
        hi = np.clip(np.floor(q.max(0)).astype(int), 0, g - 1)
        cy, cx = np.mgrid[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
        pt = np.stack([cx.ravel() + 0.5, cy.ravel() + 0.5], 1)
        hit = np.zeros(len(pt), bool)
        for t in range(1, len(q) - 1):              # (each triangle of its fan, a cell's width wider)
            a, b, c = q[0], q[t], q[t + 1]
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-12:
                continue
            l1 = ((b[1] - c[1]) * (pt[:, 0] - c[0]) + (c[0] - b[0]) * (pt[:, 1] - c[1])) / den
            l2 = ((c[1] - a[1]) * (pt[:, 0] - c[0]) + (a[0] - c[0]) * (pt[:, 1] - c[1])) / den
            slack = 1.5 / max(np.abs(np.array([a - b, b - c, c - a])).max(), 1.0)
            hit |= (l1 > -slack) & (l2 > -slack) & (1 - l1 - l2 > -slack)
        used[cy.ravel()[hit], cx.ravel()[hit]] = True
        used[lo[1], lo[0]] = True
    # (a cell clear round every face's)
    grown = used.copy()
    grown[1:] |= used[:-1]; grown[:-1] |= used[1:]
    grown[:, 1:] |= grown[:, :-1].copy(); grown[:, :-1] |= grown[:, 1:].copy()
    used = grown
    for name, size in ROOMS.items():
        c = size // k + 2                           # its cells, with one clear round it
        sat = np.pad(used.astype(int).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
        free = (sat[c:, c:] - sat[:-c, c:] - sat[c:, :-c] + sat[:-c, :-c]) == 0
        ys, xs = np.nonzero(free)
        if not len(ys):
            raise RuntimeError("no room in the colour picture for the " + name)
        # (of the free places, the one nearest the picture's middle - any would do; so each build alike)
        i = int(np.argmin((ys + c / 2 - g / 2) ** 2 + (xs + c / 2 - g / 2) ** 2))
        y0, x0 = ys[i] + 1, xs[i] + 1
        used[y0 - 1:y0 + c - 1, x0 - 1:x0 + c - 1] = True
        ROOM[name] = (x0 * k / SHIP_COLOUR, y0 * k / SHIP_COLOUR, (x0 * k + size) / SHIP_COLOUR,
                      (y0 * k + size) / SHIP_COLOUR)
    # the colours
    eye = _eye_picture(ROOMS["eye"])
    t = np.linspace(0.0, 1.0, ROOMS["teeth"])[:, None, None]
    root, tip = _tooth_colour()
    teeth = np.broadcast_to(root * (1 - t) + tip * t, (ROOMS["teeth"], ROOMS["teeth"], 3))
    pal = np.broadcast_to(np.array([0.24, 0.05, 0.06]), (32, 32, 3))
    ton = np.broadcast_to(np.array([0.40, 0.11, 0.12]), (32, 32, 3))
    looks = {"eye": (eye, (0.5, 0.5, 1.0), 0.3), "teeth": (teeth, (0.5, 0.5, 1.0), 0.45),
             "palate": (pal, (0.5, 0.5, 1.0), 0.6), "tongue": (ton, (0.5, 0.5, 1.0), 0.5)}
    for pic, which in (("DragonGhost_Colour", 0), ("DragonGhost_Normal", 1), ("DragonGhost_Roughness", 2)):
        img = _picture(body, pic)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)
        for name, (u0, v0, u1, v1) in ROOM.items():
            a, b, c_, d = int(round(u0 * w)), int(round(v0 * h)), int(round(u1 * w)), int(round(v1 * h))
            val = looks[name][which]
            if which == 0:
                # (resampled to this picture's texels)
                src = np.asarray(val, np.float32)
                ys = (np.arange(d - b) * src.shape[0] // max(d - b, 1)).clip(0, src.shape[0] - 1)
                xs = (np.arange(c_ - a) * src.shape[1] // max(c_ - a, 1)).clip(0, src.shape[1] - 1)
                px[b:d, a:c_, :3] = src[ys][:, xs]
            else:
                px[b:d, a:c_, :3] = val
            px[b:d, a:c_, 3] = 1.0
        img.pixels.foreach_set(px.ravel())
        img.update()
    # (its glow: black but for the eye - the BSDF's emission, EYE_GLOW strong)
    glow = bpy.data.images.new("DragonGhost_Glow", SHIP_GLOW, SHIP_GLOW)
    px = np.zeros((SHIP_GLOW, SHIP_GLOW, 4), np.float32)
    px[:, :, 3] = 1.0
    u0, v0, u1, v1 = ROOM["eye"]
    a, b, c_, d = (int(round(q * SHIP_GLOW)) for q in (u0, v0, u1, v1))
    ys = (np.arange(d - b) * eye.shape[0] // max(d - b, 1)).clip(0, eye.shape[0] - 1)
    xs = (np.arange(c_ - a) * eye.shape[1] // max(c_ - a, 1)).clip(0, eye.shape[1] - 1)
    px[b:d, a:c_, :3] = eye[ys][:, xs] * np.array(EYE_GLOW_TINT)
    glow.pixels.foreach_set(px.ravel())
    glow.update()
    glow.pack()
    nt = body.data.materials[0].node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    node = nt.nodes.new('ShaderNodeTexImage')
    node.image = glow
    socket = bsdf.inputs.get("Emission Color") or bsdf.inputs["Emission"]
    nt.links.new(node.outputs['Color'], socket)
    bsdf.inputs["Emission Strength"].default_value = EYE_GLOW
    log("painted the eye, the teeth, the mouth: %s" % {k_: tuple(round(x, 3) for x in v) for k_, v in ROOM.items()})


def _eye_picture(size):
    """(size, size, 3) the eye (see EYE_GREEN): green, lightest in its middle (no pupil - user request), its rim
    darkened into the socket - its iris's grain the red dragon's eye's (RED, RED_EYE), if given. Rows
    from the bottom (as Blender's pictures are)."""
    yy, xx = np.mgrid[0:size, 0:size]
    x = (xx + 0.5) / size * 2 - 1
    y = (yy + 0.5) / size * 2 - 1
    r = np.sqrt(x * x + y * y)
    grain = np.ones((size, size))
    if RED and os.path.exists(RED):
        img = bpy.data.images.load(RED)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)[:, :, :3]
        (cu, cv), rad = RED_EYE
        k = max(1, int(2 * rad * w) // size)
        n = size * k
        x0 = int(cu * w) - n // 2
        y0 = int(cv * h) - n // 2
        lum = px[y0:y0 + n, x0:x0 + n].mean(2).reshape(size, k, size, k).mean((1, 3))
        grain = np.clip(0.55 + 0.9 * (lum - lum.mean()) / max(lum.std() * 3, 1e-6) + 0.45, 0.6, 1.3)
        bpy.data.images.remove(img)
        log("the eye's grain from", os.path.basename(RED))
    mid, iris, rim = (np.array(c) for c in EYE_GREEN)
    s1 = np.clip(r / 0.55, 0, 1)[..., None]
    s2 = np.clip((r - 0.55) / 0.4, 0, 1)[..., None]
    pic = (mid * (1 - s1) + iris * s1) * (1 - s2) + rim * s2
    pic = np.clip(pic * grain[..., None], 0, 1)
    edge = np.clip((r - 0.82) / 0.18, 0, 1)
    return pic * (1 - 0.8 * edge * edge * (3 - 2 * edge))[..., None]


def _tooth_colour():
    """The teeth's colour at the root and at the tip (the red dragon's teeth's, else bone)."""
    base = np.array([0.86, 0.80, 0.66])
    if RED and os.path.exists(RED):
        img = bpy.data.images.load(RED)
        w, h = img.size
        px = np.empty(w * h * 4, np.float32)
        img.pixels.foreach_get(px)
        px = px.reshape(h, w, 4)[:, :, :3]
        base = px[int(0.6 * h):int(0.9 * h), int(0.08 * w):int(0.42 * w)].reshape(-1, 3).mean(0)
        bpy.data.images.remove(img)
    return base * np.array([0.72, 0.66, 0.55]), np.minimum(base * 1.12, 1.0)


def deepen_skin(body):
    """The skin's red the first dragon's (see SKIN_TONE): each texel's brightness and saturation moved,
    its hue kept, by how plainly red it is (not the robe, the bone, the painted patches)."""
    img = _picture(body, "DragonGhost_Colour")
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    c = px[:, :, :3]
    hi, lo = c.max(2), c.min(2)
    sat = np.where(hi > 1e-4, (hi - lo) / np.maximum(hi, 1e-4), 0.0)
    span = np.maximum(hi - lo, 1e-4)
    # (red: its red the most, its hue near red - green over blue not by much either way)
    hue = (c[:, :, 1] - c[:, :, 2]) / span
    red = (c[:, :, 0] >= hi - 1e-6) & (hue > -0.5) & (hue < 0.7)
    share = red * np.clip((sat - 0.18) / 0.12, 0, 1) * np.clip((hi - 0.06) / 0.06, 0, 1)
    for u0, v0, u1, v1 in ROOM.values():
        share[int(v0 * h) - 2:int(v1 * h) + 2, int(u0 * w) - 2:int(u1 * w) + 2] = 0.0
    (va, vb, vk), (sa, sb, sk) = SKIN_TONE["v"], SKIN_TONE["s"]
    v2 = np.clip(vb + (hi - va) * vk, 0.0, 1.0)
    s2 = np.clip(sb + (sat - sa) * sk, 0.0, 1.0)
    f = (c - lo[..., None]) / span[..., None]                # each channel's place between the two
    deep = v2[..., None] * (1.0 - s2[..., None] * (1.0 - f))
    robe = (sat < 0.22) & (hi < 0.45) & (share <= 0.0)
    for u0, v0, u1, v1 in ROOM.values():
        robe[int(v0 * h) - 2:int(v1 * h) + 2, int(u0 * w) - 2:int(u1 * w) + 2] = False
    px[:, :, :3] = c + share[..., None] * (deep - c)
    if ROBE_LIGHTEN != 1.0:
        px[:, :, :3] = np.where(robe[..., None], np.clip(c * ROBE_LIGHTEN, 0.0, 1.0), px[:, :, :3])
    img.pixels.foreach_set(px.ravel())
    img.update()
    log("skin deepened: %.0f%% of the picture" % (100 * float((share > 0.5).mean())))


def eyes_and_teeth(body, lift):
    """The eyes (on the head) and the teeth (the upper on the head, the lower on the jaw as its skin
    is): see EYE, TEETH_*. Built into the skin, UV on the painted patches (ROOM)."""
    me = body.data
    bm = bmesh.new()
    bm.from_mesh(me)
    mw = body.matrix_world
    inv = mw.inverted()
    bm.transform(mw)
    bvh = BVHTree.FromBMesh(bm)
    dl = bm.verts.layers.deform.verify()
    uvl = bm.loops.layers.uv.active
    head = body.vertex_groups["Head"].index
    jaw = body.vertex_groups["jaw"].index
    made = {"eye": 0, "tooth": 0}

    def weigh(v, f_jaw):
        if f_jaw > 0:
            v[dl][jaw] = f_jaw
        if f_jaw < 1:
            v[dl][head] = 1.0 - f_jaw

    def face(vs, uvs, out_from):
        try:
            f = bm.faces.new(vs)
        except ValueError:
            return
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - out_from) < 0:
            f.normal_flip()
        for l in f.loops:
            l[uvl].uv = uvs[vs.index(l.vert)]
        f.smooth = True
        return f

    def room_uv(name, a, b):
        u0, v0, u1, v1 = ROOM[name]
        return Vector((u0 + (u1 - u0) * (0.5 + 0.5 * a), v0 + (v1 - v0) * (0.5 + 0.5 * b)))
    # ---- the eyes: each one's socket first - the skin about it made finer, pressed in, its brow drawn
    # out and down over it - then the eye in its bottom
    (ey, ez), r = EYE["at"], EYE["r"]
    sock = EYE_SOCKET
    frames = []
    for sx in (1.0, -1.0):
        hit, nrm, _, _ = bvh.ray_cast(Vector((0.3 * sx, ey, ez + lift)), Vector((-sx, 0.0, 0.0)), 0.4)
        if hit is None:
            raise RuntimeError("no skin where the eye goes")
        look = Vector((EYE["look"][0] * sx, EYE["look"][1], EYE["look"][2])).normalized()
        d = (look + nrm).normalized()
        back = (Vector((0, 1, 0)) - d * d.y).normalized()
        up = d.cross(back) if sx > 0 else back.cross(d)
        if up.z < 0:
            up = -up
        t = math.radians(EYE["slant"])
        e1 = back * math.cos(t) + up * math.sin(t)            # along it, to its outer corner
        e2 = up * math.cos(t) - back * math.sin(t)            # across it: the slit along this
        frames.append((sx, hit.copy(), d, e1, e2))
    for sx, c, d, e1, e2 in frames:
        near = [f for f in bm.faces if (f.calc_center_median() - c).length < EYE_FINE[0]]
        bmesh.ops.subdivide_edges(bm, edges=list({e for f in near for e in f.edges}), cuts=EYE_FINE[1],
                                  use_grid_fill=True)
    moved = 0
    for sx, c, d, e1, e2 in frames:
        for v in bm.verts:
            q = v.co - c
            if q.length > 0.03 or v.co.x * sx < 0.005 or abs(q.dot(d)) > 0.012:
                continue
            s_, t_ = q.dot(e1), q.dot(e2)
            r2 = (s_ / sock["along"]) ** 2 + (t_ / sock["across"]) ** 2
            dent = sock["deep"] * max(0.0, 1.0 - r2) ** 2
            brow = sock["brow"] * math.exp(-((t_ - 0.85 * sock["across"]) / (0.45 * sock["across"])) ** 2) \
                * max(0.0, 1.0 - (s_ / (1.15 * sock["along"])) ** 2) ** 2
            if dent > 1e-5 or brow > 1e-5:
                v.co += d * (brow - dent) - e2 * (0.6 * brow)
                moved += 1
    bm.normal_update()
    bvh = BVHTree.FromBMesh(bm)
    log("eye sockets: %d vertices of the skin moved" % moved)
    for sx, c, d, e1, e2 in frames:
        a, b = r, r * EYE["tall"]
        depth = r * EYE["deep"]
        centre = c - d * sock["deep"] + d * (depth * EYE["out"]) - d * depth
        rings, segs = 7, 16
        verts = []
        tip = bm.verts.new(centre + d * depth)
        weigh(tip, 0.0)
        for i in range(1, rings + 1):
            th = math.radians(105.0) * i / rings
            ring = []
            for j in range(segs):
                ph = 2 * math.pi * j / segs
                v = bm.verts.new(centre + math.sin(th) * (a * math.cos(ph) * e1 + b * math.sin(ph) * e2)
                                 + d * depth * math.cos(th))
                weigh(v, 0.0)
                ring.append(v)
            verts.append(ring)

        def euv(v):
            q = v.co - centre
            return room_uv("eye", 0.96 * q.dot(e1) / a, 0.96 * q.dot(e2) / b)
        for j in range(segs):
            p0, p1 = verts[0][j], verts[0][(j + 1) % segs]
            face([tip, p0, p1], [euv(tip), euv(p0), euv(p1)], centre)
            for i in range(rings - 1):
                p0, p1 = verts[i][j], verts[i][(j + 1) % segs]
                p2, p3 = verts[i + 1][(j + 1) % segs], verts[i + 1][j]
                face([p0, p3, p2, p1], [euv(p0), euv(p3), euv(p2), euv(p1)], centre)
        made["eye"] += 1
        log("eye %s: at %s, looking %s" % ("left" if sx > 0 else "right", tuple(round(x, 3) for x in c),
                                             tuple(round(x, 2) for x in d)))
    # ---- the teeth
    (y0, z0), (y1, z1) = JAW_LIP
    back = Vector((0.0, y1 - y0, z1 - z0)).normalized()
    up = Vector((1.0, 0.0, 0.0)).cross(back).normalized()
    if up.z < 0:
        up = -up
    for upper, lengths in ((True, TEETH_UPPER), (False, TEETH_LOWER)):
        for sx in (1.0, -1.0):
            for i, L in enumerate(lengths):
                y = TEETH_Y[0] + (TEETH_Y[1] - TEETH_Y[0]) * (i + 0.5) / len(lengths)
                z = float(_lip_z(y)) + lift + (0.0015 if upper else -0.0015)
                hit = bvh.ray_cast(Vector((0.2 * sx, y, z)), Vector((-sx, 0.0, 0.0)), 0.3)[0]
                if hit is None:
                    continue
                inward = Vector((-sx, 0.0, 0.0))
                root = Vector((hit.x, y, z)) + inward * (TOOTH_ROOT[0] + L * TOOTH_BASE) \
                    + up * (TOOTH_ROOT[1] if upper else -TOOTH_ROOT[1])
                axis = ((-up if upper else up) + back * (TOOTH_BACK[0] if upper else TOOTH_BACK[1])
                        + inward * 0.08).normalized()
                s1 = back.cross(axis).normalized()
                s2 = axis.cross(s1)
                rb = L * TOOTH_BASE
                f_jaw = 0.0 if upper else float(np.clip((JAW_FADE[0][0] - y) / (JAW_FADE[0][0] - JAW_FADE[0][1]),
                                                        0, 1))
                rings = []
                for t, rr, bend in ((0.0, rb, 0.0), (0.5, rb * 0.72, 0.05)):
                    ring = []
                    for j in range(6):
                        ph = 2 * math.pi * j / 6
                        v = bm.verts.new(root + axis * (L * t) + back * (L * bend)
                                         + rr * (math.cos(ph) * s1 + math.sin(ph) * s2))
                        weigh(v, f_jaw)
                        ring.append(v)
                    rings.append(ring)
                tipv = bm.verts.new(root + axis * L + back * (L * 0.14))
                weigh(tipv, f_jaw)
                mid = root + axis * (L * 0.5)
                tu = lambda t_: room_uv("teeth", 0.0, 2.0 * t_ - 1.0)
                for j in range(6):
                    a, b = rings[0][j], rings[0][(j + 1) % 6]
                    c, e = rings[1][(j + 1) % 6], rings[1][j]
                    face([a, b, c, e], [tu(0.05), tu(0.05), tu(0.5), tu(0.5)], mid)
                    face([e, c, tipv], [tu(0.5), tu(0.5), tu(0.98)], mid)
                face(list(rings[0]), [tu(0.02)] * 6, mid)
                made["tooth"] += 1
    bm.transform(inv)
    bm.to_mesh(me)
    bm.free()
    me.update()
    log("eyes: %d, teeth: %d" % (made["eye"], made["tooth"]))


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


def weights(body, arm, spec, thick):
    """Bone heat for the body; its own for the wings, the hands and the tail (see the top)."""
    own = ("wing_", "tail_", "thumb_", "index_", "middle_", "ring_", "pinky_", "jaw", "skirt_")
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
    # ---- the sleeves (see SLEEVE_EASE)
    owned_now = W[:, [col[b] for b in names if b.startswith(("wing", "hand", "thumb", "index", "middle",
                                                              "ring", "pinky"))]].sum(1)
    for side, sx in (("l", 1.0), ("r", -1.0)):
        sh, el = H["upperarm_" + side]
        ax = (el - sh) / np.linalg.norm(el - sh)
        along = (P - sh) @ ax
        rad = np.linalg.norm((P - sh) - np.outer(along, ax), axis=1)
        # (its cloth: dark, or thin - its pale ragged edges)
        sleeve = (cloth | (thick < SKIRT_THIN[1])) & (rad < SLEEVE_NEAR) & (P[:, 0] * sx > 0.12) \
            & (P[:, 2] - lift > 0.2)
        ease = np.clip((along - SLEEVE_EASE[0]) / (SLEEVE_EASE[1] - SLEEVE_EASE[0]), 0, 1)
        sreg_ = sleeve * ease * np.clip(1.0 - 2.0 * owned_now, 0, 1)
        put(sreg_, np.ones((n, 1)), ["upperarm_" + side])
        log("sleeve %s: %d vertices (%d wholly)" % (side, int((sreg_ > 0).sum()), int((sreg_ > 0.99).sum())))
    # ---- the tail (and a second, if it has one)
    near_legs = np.full(n, 9.0)
    for nm in ("thigh_l", "thigh_r", "calf_l", "calf_r"):
        d, _ = _seg_dist(P, *H[nm])
        near_legs = np.minimum(near_legs, d - 0.07)

    def weigh_tail(tb):
        pts = [H[tb[0]][0]] + [H[b][1] for b in tb]
        dt_, sg, t = _chain(P, pts)
        # how far along it from its root (m)
        lens = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
        cum = np.concatenate([[0], np.cumsum(lens)])
        s_along = cum[sg] + t * np.array(lens)[sg]
        radius = np.interp(s_along, [0, 0.3, 0.6, 1.0], [0.12, 0.09, 0.06, 0.04])
        # (its spikes are pale bone: not cloth, near its line)
        robe = cloth & (dt_ > radius)
        # (eased into the body - the legs', its hips' - over a few cm, so the root bends, not tears)
        treg = np.clip((s_along - 0.05) / 0.1, 0, 1) * np.clip((radius * 1.6 - dt_) / 0.04 + 0.5, 0, 1) \
            * np.clip((near_legs - dt_) / 0.05 + 0.5, 0, 1) * (~robe)
        put(treg, _along(tb, sg, t, 0.4), tb)
        log("%s: %d vertices (%d wholly)" % (tb[0][:-2], int((treg > 0).sum()), int((treg > 0.99).sum())))
    for tb in [["tail_%02d" % (i + 1) for i in range(TAIL_BONES)]] \
            + ([["tail_b%02d" % (i + 1) for i in range(TAIL2_BONES)]] if TAIL2_LINE else []):
        weigh_tail(tb)
    # ---- the skull, rigid (see SKULL): ahead of the neck, and its horns, all the head's
    zm = P[:, 2] - lift
    skull = np.maximum(np.clip((SKULL[0][0] - P[:, 1]) / (SKULL[0][0] - SKULL[0][1]), 0, 1)
                       * np.clip((zm - SKULL[1][0]) / (SKULL[1][1] - SKULL[1][0]), 0, 1),
                       ((zm > SKULL_HORNS) & (W[:, col["Head"]] > 0.5)).astype(float)) \
        * (np.abs(P[:, 0]) < 0.12) * (~cloth) * float(FEATURES["mouth"])
    put(skull, np.ones((n, 1)), ["Head"])
    log("skull: %d vertices the head's alone" % int((skull > 0.99).sum()))
    # ---- the jaw (see JAW_LIP)
    lip = _lip_z(P[:, 1])
    # (the head's own width - not the hood round it)
    jreg = ((zm < lip - 0.0006) &(P[:, 1] < JAW_REACH[0]) & (zm > JAW_REACH[1]) & (~cloth | (P[:, 1] < JAW_CORNER))).astype(float) \
        * np.clip((JAW_WIDE - np.abs(P[:, 0])) / 0.015, 0, 1) \
        * np.clip((JAW_FADE[0][0] - P[:, 1]) / (JAW_FADE[0][0] - JAW_FADE[0][1]), 0, 1) \
        * np.clip((zm - JAW_FADE[1][0]) / (JAW_FADE[1][1] - JAW_FADE[1][0]), 0, 1) * float(FEATURES["mouth"])
    put(jreg, np.ones((n, 1)), ["jaw"])
    log("jaw: %d vertices (%d wholly)" % (int((jreg > 0).sum()), int((jreg > 0.99).sum())))
    # ---- the skirt (see SKIRT_CHAINS)
    if FEATURES["skirt"]:
        sang = _skirt_angle(P)
        # (not what's already the wings', the tail's, the hands')
        owned = W[:, [col[b] for b in names if b.startswith(("wing", "tail", "hand", "thumb", "index", "middle",
                                                              "ring", "pinky"))]].sum(1)
        sreg = _skirt_region(body, lift, spec, thick) * np.clip(1.0 - 2.0 * owned, 0, 1)
        sb, ssub = [], []
        step = 360.0 / SKIRT_CHAINS
        for k in range(SKIRT_CHAINS):
            bones = ["skirt_%d_%02d" % (k, i + 1) for i in range(SKIRT_BONES)]
            pts = [H[bones[0]][0]] + [H[b][1] for b in bones]
            _, sg, t = _chain(P, pts)
            d = np.abs((sang - step * k + 180.0) % 360.0 - 180.0)
            share = np.clip(1.0 - d / step, 0, 1)
            sb += bones
            ssub.append(share[:, None] * _along(bones, sg, t, 0.35))
        ssub = np.concatenate(ssub, 1)
        tot = ssub.sum(1, keepdims=True)
        ssub = np.where(tot > 0, ssub / np.maximum(tot, 1e-9), 0.0)
        put(sreg * (tot[:, 0] > 0), ssub, sb)
        log("skirt: %d vertices (%d wholly)" % (int((sreg > 0).sum()), int((sreg > 0.99).sum())))
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
    jaw_share = W[:, col["jaw"]]
    kind = {}
    for f in bm.faces:
        vs = [v.index for v in f.verts]
        # (the lower jaw's: below the lips' plane, ahead of the corner - however its vertices on the
        # cut were shared)
        c = np.array(body.matrix_world @ f.calc_center_median())
        jaws = FEATURES["mouth"] and (np.mean(jaw_share[vs]) > 0.5) or FEATURES["mouth"] and (c[1] < JAW_CORNER and c[2] - lift < _lip_z(c[1])
                                                 and abs(c[0]) < JAW_WIDE and c[2] - lift > SNOUT_BOX[1])
        kind[f] = "w" if np.mean(wing_share[vs]) > 0.5 else "t" if np.mean(tail_share[vs]) > 0.5 \
            else "j" if jaws else "r" if np.mean(cloth[vs]) > 0.5 else "b"

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
        if "j" in ks and len(ks) == 2:
            q = mid(e)
            return q[1] < JAW_CORNER and abs(q[2] - lift - _lip_z(q[1])) < 0.002
        return False
    seam = [e for e in bm.edges if parted(e)]
    bmesh.ops.split_edges(bm, edges=seam)
    # (the mouth's lips, parted: each edge closed in by a dark fan - palate above, tongue below)
    bm.verts.ensure_lookup_table()
    uvl = bm.loops.layers.uv.active
    mouth = {side: Vector(((ROOM[k][0] + ROOM[k][2]) / 2, (ROOM[k][1] + ROOM[k][3]) / 2))
             for side, k in (("upper", "palate"), ("lower", "tongue"))} if FEATURES["mouth"] else {}
    caps = 0
    for side in ("upper", "lower") if FEATURES["mouth"] else ():
        edges = []
        for e in bm.edges:
            if not e.is_boundary or not e.link_faces:
                continue
            q = mid(e)
            if q[1] > JAW_CORNER + 0.005 or abs(q[2] - lift - _lip_z(q[1])) > 0.002:
                continue
            if (kind.get(e.link_faces[0]) == "j") == (side == "lower"):
                edges.append(e)
        if not edges:
            continue
        vs = {v for e in edges for v in e.verts}
        c = sum((v.co for v in vs), Vector()) / len(vs)
        inward = body.matrix_world.inverted().to_3x3() @ Vector((0.0, 0.02, 0.01 if side == "upper" else -0.008))
        centre = bm.verts.new(c + inward)
        centre[orig] = -1 if side == "upper" else -2
        for e in edges:
            a, b = e.verts
            f_ = e.link_faces[0]
            # (wound against the lip's own face, so it faces into the mouth)
            loop = next(l for l in f_.loops if l.edge == e)
            first, second = (b, a) if loop.vert == a else (a, b)
            try:
                nf = bm.faces.new((first, second, centre))
            except ValueError:
                continue
            for l in nf.loops:
                l[uvl].uv = mouth[side]
            nf.material_index = f_.material_index
            kind[nf] = "j" if side == "lower" else "b"
            caps += 1
    bm.verts.ensure_lookup_table()
    rows = np.array([v[orig] for v in bm.verts])
    side_of = []
    jaw_side = []
    for v in bm.verts:
        ks = {kind.get(f, "") for f in v.link_faces}
        jaw_side.append("j" if ks == {"j"} else "h" if ks and "j" not in ks else "")
        # (the body's side: anything not the wing's - for the tail's seam, the tail's or the robe's)
        side_of.append("w" if ks == {"w"} else "b" if ks and "w" not in ks and "t" not in ks
                       else "t" if ks == {"t"} else "")
    bm.verts.layers.int.remove(orig)
    bm.to_mesh(me)
    bm.free()
    me.update()
    upper_w = np.zeros(W.shape[1]); upper_w[col["Head"]] = 1.0
    lower_w = np.zeros(W.shape[1]); lower_w[col["jaw"]] = 1.0
    rows = np.where(rows == -1, n, np.where(rows == -2, n + 1, rows))
    W = np.concatenate([W, upper_w[None], lower_w[None]], 0)[rows]
    split = len(rows) - n
    n = len(rows)
    log("mouth: %d faces closing its lips" % caps)
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
    # (the lips' copies: the lower one the jaw's - as its fade has it - the upper one the head's; and
    # so every vertex of the snout all of whose faces are under the parted lips, or over them)
    lipd = np.abs(Pn[:, 2] - lift - _lip_z(Pn[:, 1]))
    at_lip = (np.bincount(rows)[rows] > 1) & (Pn[:, 1] < JAW_CORNER + 0.005) & (lipd < 0.002)
    snout = (Pn[:, 1] < JAW_CORNER + 0.005) & (np.abs(Pn[:, 0]) < JAW_WIDE) & (Pn[:, 2] - lift > SNOUT_BOX[1]) \
        & FEATURES["mouth"]
    at_lip &= FEATURES["mouth"]
    jc, hc = col["jaw"], col["Head"]
    for i in np.nonzero(at_lip | snout)[0]:
        if jaw_side[i] == "j":
            f = float(np.clip((JAW_FADE[0][0] - Pn[i, 1]) / (JAW_FADE[0][0] - JAW_FADE[0][1]), 0, 1)
                      * np.clip((Pn[i, 2] - lift - JAW_FADE[1][0]) / (JAW_FADE[1][1] - JAW_FADE[1][0]), 0, 1))
            W[i] = 0.0
            W[i, jc], W[i, hc] = f, 1.0 - f
        elif jaw_side[i] == "h":
            W[i, jc] = 0.0
            if W[i].sum() < 1e-6:
                W[i, hc] = 1.0
    s_ = W.sum(1)
    W[s_ > 0] /= s_[s_ > 0][:, None]
    log("lips parted: %d vertices" % int(at_lip.sum()))
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
    if FEATURES["mouth"]:
        cut_mouth(body, lift)
    if FEATURES["mouth"] or FEATURES["eyes"]:
        paint_rooms(body)
    spec = joints(lift)
    thick = thickness(body)
    if FEATURES["skirt"]:
        spec.update(skirt_joints(body, lift, spec, thick))
    arm = skeleton(spec)
    weights(body, arm, spec, thick)
    if TAILS_EVEN and TAIL2_LINE:
        even_tails(body, arm)
    if FEATURES["skirt"] and FEATURES["drape"]:
        drape_skirt(body, arm, lift)
    if FEATURES["deepen"]:
        deepen_skin(body)
    if FEATURES["eyes"]:
        eyes_and_teeth(body, lift)
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
