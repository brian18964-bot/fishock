"""The beginner owl person (tools/build_finch_bird_head.py) as the player's
character in the game (user request: put it in the game to see it).

Two steps:

  bake  - the built owl (its .blend: the finch in the beginner's clothes
          with the owl's head, feathered arms and legs) made game-ready:
          the arms straightened level (the T-pose both of the game's
          skeletons have), each part cut down and its whole look - the
          owl's own texture, the projected feathers, the knit and its
          normal maps - baked onto one shared picture and one normal map.
          Writes art_src/player/owl_character.glb (the parts, no rig) and
          art_src/player/owl_character.json (where its joints are).

    bpyenv/bin/python tools/owl_character.py bake FINCH_OWL.blend
    bpyenv/bin/python tools/owl_character.py bake DOG.blend --name dog   (build_animal_person.py's)

  bind  - for the tools that render or export the character: the owl put
          on a skeleton that already carries the game's clips - Mixamo's
          (the run's sprites: render_player.py, render_player_struggle.py)
          or Quaternius' UAL (the camp's 3D character:
          build_menu_character.py). The skeleton's joints are moved to the
          owl's (each bone keeps its own axes, so every clip plays on it as
          it did), the owl is sized to it by the hips, and its parts get
          their weights (bone heat, each part only from the bones it
          belongs to; the head and the ruff by hand).

    import owl_character
    meshes = owl_character.bind(armature, "mixamo")      # or "ual"
"""
import json
import math
import os
import sys

import bpy
import bmesh  # noqa: E402 (after bpy, which provides it)
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# The finch's hips' height: the other animal people (build_animal_person.py)
# are sized against it (their legs may be shorter), times their own size.
REF_HIPS = 0.603


def paths(name="owl"):
    """A character's game file and its joints (art_src/player)."""
    base = os.path.join(ROOT, "art_src", "player", "%s_character" % name)
    return base + ".glb", base + ".json"

# The built owl's parts, by what they're called in the game file.
# (the animal people's head and collar are "animal_head", "animal_ruff")
PARTS = {"bird_head": "owl_head", "bird_ruff": "owl_ruff", "finch_jumper": "owl_jumper",
         "finch_trousers": "owl_trousers", "finch_hand": "owl_hands", "finch_feet": "owl_feet",
         "finch_button_trousers_1": "owl_button"}
# Triangles each part is cut down to (from its smoothed shape), about.
TRIS = {"owl_head": 2400, "owl_ruff": 6400, "owl_jumper": 7000, "owl_trousers": 4000,
        "owl_hands": 5000, "owl_feet": 5000, "owl_button": 120}
# The shared picture; the face gets more of it (HEAD_SHARE times the
# texels a part of its size would).
ATLAS = 2048
NORMALS = 1024
HEAD_SHARE = 2.2
# The arms straightened (after the bake) over this much either side of the shoulder and
# elbow (finch units).
SHOULDER_BLEND = 0.035
ELBOW_BLEND = 0.02


# ---------------------------------------------------------------- bake

def _bone(arm, name, end="head"):
    b = arm.data.bones[name]
    return arm.matrix_world @ (b.head_local if end == "head" else b.tail_local)


def _turn(p, about, t):
    """p turned by t about `about`, in the x-z plane."""
    dx, dz = p.x - about.x, p.z - about.z
    c, s = math.cos(t), math.sin(t)
    return Vector((about.x + dx * c - dz * s, p.y, about.z + dx * s + dz * c))


def _smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


class Straighten:
    """The arms raised level at the shoulder, then the forearm at the
    elbow - the finch's arms hang a little; both game skeletons are
    T-posed (and keep their bones' own axes on the owl)."""

    def __init__(self, arm):
        self.sh = _bone(arm, "DEF_arm_L")
        el = _bone(arm, "DEF_forearm_L")
        wr = _bone(arm, "DEF_hand_L")
        self.t1 = -math.atan2(el.z - self.sh.z, el.x - self.sh.x)
        self.el = _turn(el, self.sh, self.t1)
        wr1 = _turn(wr, self.sh, self.t1)
        self.t2 = -math.atan2(wr1.z - self.el.z, wr1.x - self.el.x)

    def __call__(self, p):
        side = 1.0 if p.x >= 0 else -1.0
        q = Vector((p.x * side, p.y, p.z))
        # (only the arms: a wide body's sides - the bear's - lower down
        # are left as they are)
        w1 = _smooth(self.sh.x - SHOULDER_BLEND, self.sh.x + SHOULDER_BLEND, q.x) * \
            _smooth(self.sh.z - 0.2, self.sh.z - 0.15, q.z)
        q = _turn(q, self.sh, self.t1 * w1)
        w2 = _smooth(self.el.x - ELBOW_BLEND, self.el.x + ELBOW_BLEND, q.x)
        q = _turn(q, self.el, self.t2 * w2)
        return Vector((q.x * side, q.y, q.z))


# The legs drawn in (user request: the legs needn't stand so far apart):
# from the crotch down (fully by LEGS_IN[1], none above LEGS_IN[0]) each
# leg moved NARROW in toward the middle, the baggy trouser legs made
# TROUSERS_SLIM narrower about TROUSERS_MID so they don't meet.
LEGS_IN = (0.60, 0.48)
NARROW = 0.029
TROUSERS_MID = 0.11
TROUSERS_SLIM = 0.8


def narrow(p, trousers=False, girth=1.0, drop=0.0):
    """(`drop`: how much lower this body's hips are than the finch's - an
    animal person with shorter legs)"""
    t = _smooth(LEGS_IN[0] - drop, LEGS_IN[1] - drop, p.z)
    if t <= 0.0:
        return Vector(p)
    side = 1.0 if p.x >= 0 else -1.0
    x = abs(p.x)
    if trousers:
        mid = TROUSERS_MID * girth
        want = (mid - NARROW) + (x - mid) * TROUSERS_SLIM
    else:
        want = x - NARROW
    return Vector((side * (x + (want - x) * t), p.y, p.z))


def _joints(arm, fix, head, girth=1.0, drop=0.0):
    """Where the owl's joints are (its left side; the right mirrors it),
    arms straightened."""
    def at(name, end="head"):
        return list(fix(_bone(arm, name, end)))

    def finger(n):
        return [at(f"DEF_{n}_L.001"), at(f"DEF_{n}_L.002"), at(f"DEF_{n}_L.003"), at(f"DEF_{n}_L.003", "tail")]
    top = max((head.matrix_world @ v.co).z for v in head.data.vertices)
    knee = (Vector(at("DEF_knee_L")) + Vector(at("DEF_knee_L", "tail"))) / 2
    return {
        "trunk": [at("DEF_spine.004"), at("DEF_spine.003"), at("DEF_spine.002"), at("DEF_spine.001"),
                  at("DEF_head")],
        "head_top": [0.0, at("DEF_head")[1], top],
        "clavicle": at("DEF_shoulder_L"), "shoulder": at("DEF_arm_L"), "elbow": at("DEF_forearm_L"),
        "wrist": at("DEF_hand_L"),
        "thumb": [at("DEF_palm_L.004"), at("DEF_thumb_L.001"), at("DEF_thumb_L.002"), at("DEF_thumb_L.002", "tail")],
        "index": finger("index"), "middle": finger("middle"), "ring": finger("ring"), "pinky": finger("pinky"),
        "thigh": list(narrow(Vector(at("DEF_thigh_L")), girth=girth, drop=drop)), "knee": list(narrow(knee, girth=girth, drop=drop)),
        "ankle": list(narrow(Vector(at("DEF_calf_L", "tail")), girth=girth, drop=drop)),
        "ball": list(narrow(Vector(at("DEF_toe_2_L.002")), girth=girth, drop=drop)),
        "toe": list(narrow(Vector(at("DEF_toe_2_L.003", "tail")), girth=girth, drop=drop)),
    }


def _fill_misses(im):
    w, h = im.size
    px = np.empty(w * h * 4, np.float32)
    im.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    miss = px[:, :3].sum(1) <= 0.0
    if miss.any() and not miss.all():
        px[miss, :3] = px[~miss, :3].mean(0)
        im.pixels.foreach_set(px.ravel())


def _emission_of_colour(m):
    nt = m.node_tree
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
    b = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if out is None or b is None:
        return
    emit = nt.nodes.new("ShaderNodeEmission")
    sock = b.inputs["Base Color"]
    if sock.is_linked:
        nt.links.new(sock.links[0].from_socket, emit.inputs["Color"])
    else:
        emit.inputs["Color"].default_value = sock.default_value
    nt.links.new(emit.outputs[0], out.inputs["Surface"])


def _area(o):
    return sum(p.area for p in o.data.polygons)


def _atlas(parts, gap=0.006):
    """Each part's own unwrap (filling a square) set into the one picture:
    squares as big as the part's surface (the face's HEAD_SHARE times),
    laid in rows, as large as they all fit."""
    want = {n: math.sqrt(_area(o) * (HEAD_SHARE if n == "owl_head" else 1.0)) for n, o in parts.items()}
    order = sorted(want, key=want.get, reverse=True)

    def lay(k):
        at, x, y, row = {}, 0.0, 0.0, 0.0
        for n in order:
            side = want[n] * k
            if x + side > 1.0 + 1e-9:
                x, y, row = 0.0, y + row + gap, 0.0
            at[n] = (x, y, side)
            x += side + gap
            row = max(row, side)
        return at if y + row <= 1.0 + 1e-9 else None
    lo, hi = 0.0, 10.0 / max(want.values())
    for _ in range(40):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if lay(mid) else (lo, mid)
    for n, (x, y, side) in lay(lo).items():
        uv = parts[n].data.uv_layers["atlas"].data
        co = np.array([d.uv[:] for d in uv])
        base = co.min(0)
        span = float((co.max(0) - base).max())
        co = (co - base) / span * side + (x, y)
        uv.foreach_set("uv", co.ravel())


def bake_character(src, character="owl"):
    bpy.ops.wm.open_mainfile(filepath=src)
    glb, joints_path = paths(character)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.data.pose_position = "REST"
    sc = bpy.context.scene
    girth = float(sc.get("animal_girth", 1.0))
    for a, b in (("animal_head", "bird_head"), ("animal_ruff", "bird_ruff")):
        if a in bpy.data.objects:
            bpy.data.objects[a].name = b
    head = bpy.data.objects["bird_head"]
    bpy.context.view_layer.update()
    fix = Straighten(arm)
    drop = REF_HIPS - _bone(arm, "DEF_spine.004").z if "animal_size" in sc else 0.0
    joints = _joints(arm, fix, head, girth, drop)
    if "animal_size" in sc:
        joints["size"] = float(sc["animal_size"])
        joints["ref_hips"] = REF_HIPS

    tris = dict(TRIS)
    if "animal_size" in sc:
        # (a sculpted animal's head needs more to keep its face)
        tris["owl_head"] = 6000
    parts = {}
    for src_name, name in PARTS.items():
        o = bpy.data.objects[src_name]
        for md in list(o.modifiers):
            if md.type in ("PARTICLE_SYSTEM", "ARMATURE"):
                o.modifiers.remove(md)
            elif md.type == "SUBSURF":
                md.levels = 2
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        me.transform(o.matrix_world)
        part = bpy.data.objects.new(name, me)
        sc.collection.objects.link(part)
        # The picture's own map, to bake onto; the part's maps still
        # what its materials read.
        render = next(l for l in me.uv_layers if l.active_render)
        atlas = me.uv_layers.new(name="atlas")
        me.uv_layers.active = atlas
        render.active_render = True
        parts[name] = part
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o not in parts.values()]:
        bpy.data.objects.remove(o, do_unlink=True)

    # One picture for all: unwrapped together, the face given more room.
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts["owl_head"]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    _atlas(parts)

    # Baked from each part's own materials, as built (their projected
    # feathers placed as they were drawn).
    colour = bpy.data.images.new("owl_character_color", ATLAS, ATLAS)
    normal = bpy.data.images.new("owl_character_normal", ATLAS, ATLAS)
    normal.colorspace_settings.name = "Non-Color"
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 4
    bk = sc.render.bake
    bk.use_selected_to_active = False
    bk.margin = 6
    mats = {s.material for o in parts.values() for s in o.material_slots if s.material and s.material.use_nodes}
    targets = []
    for m in mats:
        slot = m.node_tree.nodes.new("ShaderNodeTexImage")
        m.node_tree.nodes.active = slot
        targets.append(slot)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts["owl_head"]
    for what, im in (("NORMAL", normal), ("EMIT", colour)):
        if what == "EMIT":
            for m in mats:
                _emission_of_colour(m)
        for t in targets:
            t.image = im
        bpy.ops.object.bake(type=what, use_clear=True, normal_space="TANGENT")
    _fill_misses(colour)
    normal.scale(NORMALS, NORMALS)

    # The game's material: the two pictures.
    mat = bpy.data.materials.new("owl_character")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.85
    col = nt.nodes.new("ShaderNodeTexImage")
    col.image = colour
    nt.links.new(col.outputs[0], b.inputs["Base Color"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = normal
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    for im in (colour, normal):
        im.pack()
    for name, o in parts.items():
        me = o.data
        for layer_name in [l.name for l in me.uv_layers if l.name != "atlas"]:
            me.uv_layers.remove(me.uv_layers[layer_name])
        me.uv_layers["atlas"].name = "UVMap"
        me.materials.clear()
        me.materials.append(mat)
        # Cut down to about TRIS (the picture's map kept), then the arms
        # straightened (the pictures go with them).
        have = sum(len(p.vertices) - 2 for p in me.polygons)
        if have > tris[name]:
            dec = o.modifiers.new("dec", "DECIMATE")
            dec.ratio = tris[name] / have
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier="dec")
        for v in o.data.vertices:
            v.co = fix(v.co)
            if name in ("owl_trousers", "owl_feet"):
                v.co = narrow(v.co, trousers=name == "owl_trousers", girth=girth, drop=drop)
        o.data.update()
        o.data.shade_smooth()
    lows = parts

    bpy.ops.object.select_all(action="DESELECT")
    for o in lows.values():
        o.select_set(True)
    os.makedirs(os.path.dirname(glb), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True,
                              export_image_format="JPEG", export_jpeg_quality=88, export_vertex_color="NONE")
    with open(joints_path, "w") as fh:
        json.dump({k: v if not isinstance(v, list) else
                   [[round(c, 5) for c in p] for p in v] if isinstance(v[0], list) else [round(c, 5) for c in v]
                   for k, v in joints.items()}, fh, indent=1)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in lows.values()}
    print("wrote", glb, os.path.getsize(glb) // 1024, "KB;", tris, sum(tris.values()), "triangles")


# ---------------------------------------------------------------- bind

FINGERS = ("thumb", "index", "middle", "ring", "pinky")
# Each skeleton's names: its trunk, hips to head; a limb bone of side s
# ("l"/"r"); a finger's i-th bone (1-4, the 4th its tip); the head's top.
RIGS = {
    "mixamo": {
        "trunk": ["mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2", "mixamorig:Neck",
                  "mixamorig:Head"],
        "limbs": {"clavicle": "Shoulder", "shoulder": "Arm", "elbow": "ForeArm", "wrist": "Hand",
                  "thigh": "UpLeg", "knee": "Leg", "ankle": "Foot", "ball": "ToeBase", "toe": "Toe_End"},
        "limb": lambda s, n: "mixamorig:%s%s" % ("Left" if s == "l" else "Right", n),
        "finger": lambda s, f, i: "mixamorig:%sHand%s%d" % ("Left" if s == "l" else "Right", f.capitalize(), i),
        "head_top": "mixamorig:HeadTop_End",
    },
    "ual": {
        "trunk": ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"],
        "limbs": {"clavicle": "clavicle", "shoulder": "upperarm", "elbow": "lowerarm", "wrist": "hand",
                  "thigh": "thigh", "knee": "calf", "ankle": "foot", "ball": "ball", "toe": "ball_leaf"},
        "limb": lambda s, n: "%s_%s" % (n, s),
        "finger": lambda s, f, i: "%s_0%d_%s" % (f, i, s) if i < 4 else "%s_04_leaf_%s" % (f, s),
        "head_top": None,
    },
}
# Which bones each part is weighted from (by the joints they belong to).
PART_JOINTS = {
    "owl_jumper": {"trunk": True, "limbs": ("clavicle", "shoulder", "elbow")},
    "owl_trousers": {"hips": True, "limbs": ("thigh", "knee")},
    "owl_button": {"hips": True},
    "owl_hands": {"limbs": ("elbow", "wrist"), "fingers": True},
    "owl_feet": {"limbs": ("thigh", "knee", "ankle", "ball")},
}
# The ruff: on the knit it goes with the chest, up to the neck's edge
# with the neck, under the head with the head (heights above the
# jumper's neckline, owl units).
RUFF_CHEST = (-0.002, 0.012)
RUFF_HEAD = (0.02, 0.04)


def _scale(hips_z, joints):
    """World units a character unit, on a skeleton with its hips this high:
    the owl's hips at the skeleton's; another animal person sized against
    the finch's hips, times its own size."""
    return hips_z / joints.get("ref_hips", joints["trunk"][0][2]) * joints.get("size", 1.0)


def _targets(arm, rig, joints):
    """Each mapped bone's new head (world), the scale and offset the owl
    is put on the skeleton with."""
    mw = arm.matrix_world
    bones = arm.data.bones
    trunk = rig["trunk"]
    hips = mw @ bones[trunk[0]].head_local
    head = mw @ bones[trunk[-1]].head_local
    owl_trunk = [Vector(p) for p in joints["trunk"]]
    k = _scale(hips.z, joints)
    off = Vector((0.0, hips.y - owl_trunk[0].y * k, 0.0))

    def place(p):
        return Vector(p) * k + off

    def mirror(p, s):
        return Vector((p[0] if s == "l" else -p[0], p[1], p[2]))
    out = {}
    # The trunk: each bone as far up the owl's as it is up the skeleton's.
    zs = [p.z for p in owl_trunk]
    for name in trunk:
        f = ((mw @ bones[name].head_local).z - hips.z) / (head.z - hips.z)
        z = zs[0] + f * (zs[-1] - zs[0])
        x = float(np.interp(z, zs, [p.x for p in owl_trunk]))
        y = float(np.interp(z, zs, [p.y for p in owl_trunk]))
        out[name] = place((x, y, z))
    if rig["head_top"]:
        out[rig["head_top"]] = place(joints["head_top"])
    for s in ("l", "r"):
        for joint, n in rig["limbs"].items():
            out[rig["limb"](s, n)] = place(mirror(joints[joint], s))
        for f in FINGERS:
            for i in range(4):
                out[rig["finger"](s, f, i + 1)] = place(mirror(joints[f][i], s))
    return {n: p for n, p in out.items() if n in bones}, k, off


def _chain_next(arm, name, targets):
    """The bone that carries this one's chain on (the child nearest its
    tail) - for the segment it's weighted along."""
    b = arm.data.bones[name]
    kids = [c for c in b.children if c.name in targets]
    if not kids:
        return None
    return min(kids, key=lambda c: (c.head_local - b.tail_local).length).name


def _refit(arm, targets):
    """The skeleton's rest pose moved onto the owl: each mapped bone's head
    where the owl's joint is, its axes and roll as they were (so a clip
    turns it as it turned the original); the rest follow their nearest
    moved parent."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    mw = arm.matrix_world
    inv = mw.inverted()
    eb = arm.data.edit_bones
    old = {b.name: (mw @ b.head, mw @ b.tail) for b in eb}
    for b in eb:
        b.use_connect = False
    heads = dict(targets)
    for b in eb:
        if b.name in heads:
            continue
        a = b.parent
        while a is not None and a.name not in targets:
            a = a.parent
        if a is not None:
            heads[b.name] = targets[a.name] + (old[b.name][0] - old[a.name][0])
    for b in eb:
        if b.name not in heads:
            continue
        h0, t0 = old[b.name]
        nxt = next((c.name for c in b.children if c.name in heads and (old[c.name][0] - t0).length < 1e-4), None)
        ratio = 1.0
        if nxt is not None and (old[nxt][0] - h0).length > 1e-6:
            ratio = (heads[nxt] - heads[b.name]).length / (old[nxt][0] - h0).length
        d = t0 - h0
        b.head = inv @ heads[b.name]
        b.tail = inv @ (heads[b.name] + d * max(ratio, 0.05))
    bpy.ops.object.mode_set(mode="OBJECT")
    return heads


def _weigh_heat(part, arm, names, heads, tails):
    """Bone-heat weights for `part` from just the bones `names`, laid
    along the owl's own limbs (a stand-in skeleton, used only for this)."""
    data = bpy.data.armatures.new("weigh")
    rig = bpy.data.objects.new("weigh", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for n in names:
        b = data.edit_bones.new(n)
        b.head = heads[n]
        b.tail = tails[n]
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    part.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Anything the heat didn't reach: from its nearest bones.
    segs = [(n, heads[n], tails[n]) for n in names]
    for v in part.data.vertices:
        if sum(g.weight for g in v.groups) > 1e-3:
            continue
        near = sorted((_seg_dist(v.co, a, b), n) for n, a, b in segs)[:2]
        w = [1.0 / max(d, 1e-4) ** 4 for d, _ in near]
        for (d, n), wi in zip(near, w):
            part.vertex_groups[n].add([v.index], wi / sum(w), "REPLACE")
    for md in [m for m in part.modifiers if m.type == "ARMATURE"]:
        part.modifiers.remove(md)
    part.parent = None
    bpy.data.objects.remove(rig, do_unlink=True)


def _seg_dist(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-12 else min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)
    return (p - (a + ab * t)).length


def _neckline(jumper):
    bm = bmesh.new()
    bm.from_mesh(jumper.data)
    pts = np.array([v.co[:] for e in bm.edges if e.is_boundary for v in e.verts])
    bm.free()
    top = pts[:, 2].max()
    pts = pts[pts[:, 2] > top - (top - pts[:, 2].min()) * 0.25]
    pts = pts[np.abs(pts[:, 0]) < np.abs(pts[:, 0]).max() * 0.5]
    cx, cy = 0.0, (pts[:, 1].min() + pts[:, 1].max()) / 2
    ang = np.arctan2(pts[:, 0] - cx, -(pts[:, 1] - cy))
    order = np.argsort(ang)
    return (lambda a: float(np.interp(a, ang[order], pts[order, 2], period=2 * math.pi))), cx, cy


# A clip's feet no further out from the hips than this (owl units; user
# request: the legs needn't stand so far apart - the stand-in skeletons'
# clips stand wide).
STANCE = 0.012
# ...and, standing (not walking), no further ahead or behind it than this.
STRIDE = 0.035


def close_stance(arm, rig_name, actions, standing=(), character="owl", files=None):
    """Each of `actions` (on `arm`) gone through frame by frame: where a
    foot is further out than STANCE from its hip - or, in the `standing`
    ones, further ahead or behind than STRIDE - the thigh turned (about
    the hip) to bring it there and the foot turned back the same so it
    stays flat (a bent knee takes a few goes); keyed over the clip."""
    rig = RIGS[rig_name]
    with open((files or paths(character))[1]) as fh:
        joints = json.load(fh)
    hips_z = (arm.matrix_world @ arm.data.bones[rig["trunk"][0]].head_local).z
    limit = STANCE * _scale(hips_z, joints)
    stride = STRIDE * _scale(hips_z, joints)
    ad = arm.animation_data or arm.animation_data_create()
    keep = ad.action
    mutes = [(t, t.mute) for t in ad.nla_tracks]
    for t in ad.nla_tracks:
        t.mute = True
    scene = bpy.context.scene
    for act in actions:
        ad.action = act
        s0, s1 = (int(round(f)) for f in act.frame_range)
        for f in range(s0, s1 + 1):
            scene.frame_set(f)
            for side, sign in (("l", 1.0), ("r", -1.0), ("l", 1.0), ("r", -1.0), ("l", 1.0), ("r", -1.0)):
                thigh = arm.pose.bones[rig["limb"](side, rig["limbs"]["thigh"])]
                foot = arm.pose.bones[rig["limb"](side, rig["limbs"]["ankle"])]
                mw = arm.matrix_world
                hip = mw @ thigh.head
                ank = mw @ foot.head
                drop = hip.z - ank.z
                if drop < 1e-3:
                    continue
                turn = Matrix.Identity(4)
                out = (ank.x - hip.x) * sign - limit
                if out > 0.0:
                    turn = Matrix.Rotation(math.atan2(out, drop) * sign, 4, "Y") @ turn
                ahead = abs(ank.y - hip.y) - stride
                if act in standing and ahead > 0.0:
                    turn = Matrix.Rotation(-math.copysign(math.atan2(ahead, drop), ank.y - hip.y), 4, "X") @ turn
                if turn == Matrix.Identity(4):
                    continue
                turn = Matrix.Translation(hip) @ turn @ Matrix.Translation(-hip)
                foot_world = mw @ foot.matrix
                thigh.matrix = mw.inverted() @ turn @ mw @ thigh.matrix
                bpy.context.view_layer.update()
                # The foot as it was turned (flat), where the leg now puts it.
                now = mw @ foot.matrix
                fixed = foot_world.copy()
                fixed.translation = now.translation
                foot.matrix = mw.inverted() @ fixed
                bpy.context.view_layer.update()
                for pb in (thigh, foot):
                    pb.keyframe_insert("rotation_quaternion", frame=f)
    ad.action = keep
    for t, m in mutes:
        t.mute = m


def _pick(rig, targets, spec):
    """The bones a part is weighted from (PART_JOINTS' spec)."""
    names = []
    if spec.get("trunk"):
        names += rig["trunk"][:-1]
    if spec.get("hips"):
        names.append(rig["trunk"][0])
    for s in ("l", "r"):
        for j in spec.get("limbs", ()):
            names.append(rig["limb"](s, rig["limbs"][j]))
        if spec.get("fingers"):
            names += [rig["finger"](s, f, i) for f in FINGERS for i in (1, 2, 3)]
    return [n for n in names if n in targets]


def _bind_greybox(arm, rig, joints, parts, heads, tails, targets, k, off):
    """A greybox character (tools/greybox_animals.py): its one body (head
    to toes and tail) weighted from the whole skeleton - rigid with the
    head above its neck, the tail along tail bones added for it (with the
    hips if it has none) - its eyes and nose
    with the head, and its clothes moving as the body under them does."""
    head_bone = rig["trunk"][-1]
    pelvis = rig["trunk"][0]
    fingers = joints.get("fingers", list(FINGERS))
    names = list(rig["trunk"])
    for s in ("l", "r"):
        for j in ("clavicle", "shoulder", "elbow", "wrist", "thigh", "knee", "ankle", "ball"):
            names.append(rig["limb"](s, rig["limbs"][j]))
        names += [rig["finger"](s, f, i) for f in fingers for i in (1, 2, 3)]
    names = [n for n in names if n in targets]
    body = parts["owl_body"]
    _weigh_heat(body, arm, names, heads, tails)

    def unit(co):
        return (co - off) / k
    z0, z1 = joints["head_rigid"]
    reach = joints["head_reach"]
    hg = body.vertex_groups.get(head_bone) or body.vertex_groups.new(name=head_bone)
    pg = body.vertex_groups.get(pelvis) or body.vertex_groups.new(name=pelvis)
    box = joints.get("tail_box")
    chain = _tail_bones(arm, pelvis, joints, k, off) if joints.get("tail") else []
    tg = [body.vertex_groups.get(n) or body.vertex_groups.new(name=n) for n in chain]
    pts = [Vector(p) for p in joints.get("tail", ())]
    for v in body.data.vertices:
        p = unit(v.co)
        w = _smooth(z0, z1, p.z) if abs(p.x) < reach else 0.0
        if w > 0.0:
            for g in v.groups:
                g.weight *= 1.0 - w
            hg.add([v.index], w, "ADD")
        if box and all(box[0][i] - 0.005 <= p[i] <= box[1][i] + 0.005 for i in range(3)):
            t = _smooth(joints["tail_root_y"], joints["tail_root_y"] + 0.03, p.y)
            if t > 0.0 and chain:
                # along the tail's own bones, by its place along the tail
                d, i, f = min((_seg_dist(p, pts[j], pts[j + 1]), j, _seg_t(p, pts[j], pts[j + 1]))
                              for j in range(len(pts) - 1))
                if d > TAIL_REACH:
                    t = 0.0
                # each bone's share peaks at its middle, shared at its ends
                at = i + f
                ws = {j: max(0.0, 1.0 - abs(at - j - 0.5)) for j in range(len(chain))}
                tot = sum(ws.values())
                ws = {j: w / tot for j, w in ws.items()}
                if t > 0.0:
                    for g in v.groups:
                        g.weight *= 1.0 - t
                    for j, w in ws.items():
                        if w * t > 1e-4:
                            tg[j].add([v.index], w * t, "ADD")
            elif t > 0.0:
                for g in v.groups:
                    g.weight *= 1.0 - t
                pg.add([v.index], t, "ADD")
    _weigh_ears(body, arm, head_bone, joints, k, off, unit)
    if "owl_face" in parts:
        fc = parts["owl_face"]
        fc.vertex_groups.new(name=head_bone).add(range(len(fc.data.vertices)), 1.0, "REPLACE")
    # The clothes move as the body under them does: each point takes the
    # weights of the nearest point of the body (so they stay over it).
    tune = os.environ.get("GB_GARMENT_WEIGHTS", "1") != "0"
    if tune and "owl_trousers" in parts:
        # the shorts first: smoothed, and the body under them given the
        # same weights, so the two move as one (see _shorts_and_body)
        _copy_weights(body, parts["owl_trousers"])
        _shorts_and_body(body, parts["owl_trousers"], rig, unit, k)
    for name in ("owl_jumper", "owl_trousers", "owl_button", "owl_ruff"):
        if name in parts and not (tune and name == "owl_trousers"):
            _copy_weights(body, parts[name])
    if tune:
        _garment_weights(parts, rig, joints, unit)
    return body


def _weights(ob):
    """Each vertex's weights by group name."""
    names = {g.index: g.name for g in ob.vertex_groups}
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in ob.data.vertices]


def _set_weights(ob, ws):
    groups = {g.name: g for g in ob.vertex_groups}
    for g in ob.vertex_groups:
        g.remove(range(len(ob.data.vertices)))
    for i, w in enumerate(ws):
        tot = sum(w.values())
        for n, x in w.items():
            if x > 1e-4 and tot > 0.0:
                groups[n].add([i], x / tot, "REPLACE")


def _move(w, src, dst, share=1.0):
    """`share` of the weight of bones `src` handed to `dst` (one bone, or
    the vertex's own weights among `dst` bones, by their shares)."""
    moved = 0.0
    for n in src:
        if n in w:
            m = w[n] * share
            w[n] -= m
            moved += m
    if moved <= 0.0:
        return
    if isinstance(dst, str):
        w[dst] = w.get(dst, 0.0) + moved
        return
    have = {n: w[n] for n in dst if w.get(n, 0.0) > 0.0}
    if not have:
        have = {dst[0]: 1.0}
    tot = sum(have.values())
    for n, x in have.items():
        w[n] = w.get(n, 0.0) + moved * x / tot


def _smooth_weights(ob, repeat, factor=0.5):
    """Every group's weights eased toward their neighbours' mean, `repeat`
    times; then each vertex's summed to one."""
    me = ob.data
    n = len(me.vertices)
    ev = np.zeros(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", ev)
    ev = ev.reshape(-1, 2)
    a = np.concatenate([ev[:, 0], ev[:, 1]])
    b = np.concatenate([ev[:, 1], ev[:, 0]])
    deg = np.bincount(a, minlength=n).astype(float)
    names = [g.name for g in ob.vertex_groups]
    W = np.zeros((n, len(names)))
    for i, w in enumerate(_weights(ob)):
        for k, x in w.items():
            W[i, names.index(k)] = x
    for _ in range(repeat):
        acc = np.zeros_like(W)
        np.add.at(acc, a, W[b])
        mean = acc / np.maximum(deg, 1.0)[:, None]
        W = np.where(deg[:, None] > 0, W * (1.0 - factor) + mean * factor, W)
    _set_weights(ob, [{names[j]: W[i, j] for j in np.nonzero(W[i] > 1e-4)[0]} for i in range(n)])


def _garment_weights(parts, rig, joints, unit):
    """The clothes' weights, copied from the body, then set to move as
    cloth does (user request: the jumper lifted whole in the run, the
    waist left uncovered, the cuffs collapsed, the shorts stretched):
    the jumper's body, away from the armpit,
    goes with the spine, not the arms; its turned-back cuffs move with
    the upper arm alone, as do the shorts' with the thigh; the shorts
    ride on the hips and thighs, nothing higher; and the weights are
    smoothed so a bend spreads over the cloth instead of creasing it.
    (The jumper's hem keeps the thighs' share it copied: let go of them,
    the shorts' fronts rose through it as a leg came up - measured in the
    run, 43 mm deep.)"""
    lr = ("l", "r")
    limb = lambda s, j: rig["limb"](s, rig["limbs"][j])  # noqa: E731
    trunk = list(rig["trunk"])
    pelvis = trunk[0]
    spine = trunk[1:-2]
    legs = [limb(s, j) for s in lr for j in ("thigh", "knee", "ankle", "ball")]
    fingers = [rig["finger"](s, f, i) for s in lr for f in FINGERS for i in (1, 2, 3)]
    sh = Vector(joints["shoulder"])
    el = Vector(joints["elbow"])
    ax = (el - sh).normalized()
    reach = (el - sh).length
    if "owl_jumper" in parts:
        ob = parts["owl_jumper"]
        co = [unit(v.co) for v in ob.data.vertices]
        hem = min(p.z for p in co)
        ws = _weights(ob)
        for p, w in zip(co, ws):
            side = "l" if p.x >= 0.0 else "r"
            arm = [limb(side, "shoulder"), limb(side, "elbow"), limb(side, "wrist")] + \
                [n for n in fingers if n.endswith("_" + side) or ("Left" if side == "l" else "Right") in n]
            q = Vector((abs(p.x), p.y, p.z))
            t = (q - sh).dot(ax) / reach
            if t < 0.0 and os.environ.get("GB_JUMPER_ARMFADE", "0") != "0":
                # the body of it: the arms' pull fades out below the armpit
                d = (q - sh).length
                keep = 1.0 - _smooth(0.06, 0.14, d)
                _move(w, arm, spine + [pelvis], 1.0 - keep)
            elif t > 0.45:
                # the sleeve's end and cuff: with the upper arm only
                _move(w, arm[1:], arm[0])
            if p.z < hem + 0.06:
                _move(w, [limb(side, "clavicle")], spine + [pelvis], _smooth(hem + 0.06, hem, p.z))
        _set_weights(ob, ws)
        _smooth_weights(ob, int(os.environ.get("GB_SMOOTH_JUMPER", "0")))


def _shorts_and_body(body, shorts, rig, unit, k):
    """The shorts' weights smoothed (user request: the shorts stretched in
    big patches - a bend spread over the cloth stretches it less), their
    turned-up hems with the thighs alone; then the body under them given
    the same weights, fading back to its own toward the hems and the
    waistband, so the body moves with the cloth over it instead of out
    through it (smoothing the shorts alone, the hips and crotch came
    through). The tail's root keeps its own."""
    limb = lambda s, j: rig["limb"](s, rig["limbs"][j])  # noqa: E731
    co = [unit(v.co) for v in shorts.data.vertices]
    low = min(p.z for p in co)
    top = max(p.z for p in co)
    ws = _weights(shorts)
    for p, w in zip(co, ws):
        side = "l" if p.x >= 0.0 else "r"
        if p.z < low + 0.045:
            _move(w, [limb(side, "knee"), limb(side, "ankle")], limb(side, "thigh"))
    _set_weights(shorts, ws)
    _smooth_weights(shorts, int(os.environ.get("GB_SMOOTH_SHORTS", "4")))
    ws = _weights(shorts)
    me = shorts.data
    tree = BVHTree.FromPolygons([v.co for v in me.vertices], [list(p.vertices) for p in me.polygons])
    polys = [list(p.vertices) for p in me.polygons]
    bw = _weights(body)
    for i, v in enumerate(body.data.vertices):
        p = unit(v.co)
        if p.z < low - 0.005 or p.z > top or any(n.startswith("tail_") for n in bw[i]):
            continue
        loc, nrm, fi, dist = tree.find_nearest(v.co)
        if loc is None or dist / k > 0.03 or ((v.co - loc).dot(nrm) > 0.0 and dist / k > 0.002):
            continue
        b = _smooth(low, low + 0.03, p.z) * _smooth(top, top - 0.02, p.z)
        if b <= 0.0:
            continue
        mix = {}
        for j in polys[fi]:
            for n, x in ws[j].items():
                mix[n] = mix.get(n, 0.0) + x / len(polys[fi])
        w = {n: x * (1.0 - b) for n, x in bw[i].items()}
        for n, x in mix.items():
            w[n] = w.get(n, 0.0) + x * b
        bw[i] = w
    _set_weights(body, bw)


# A body point further than this from the tail's line (character units)
# isn't the tail's, whatever box it is in.
TAIL_REACH = 0.05


# How far along an ear (a share of its length) it eases free of the head.
EAR_EASE = 0.25


def _seg_t(p, a, b):
    ab = b - a
    return 0.0 if ab.length_squared < 1e-12 else min(max((p - a).dot(ab) / ab.length_squared, 0.0), 1.0)


def _tail_bones(arm, pelvis, joints, k, off):
    """A chain of bones down the tail (joints["tail"]: its points, root
    to tip, character units) from the hips - for swinging it; the clips
    don't key them, so they ride with the hips until something does."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    inv = arm.matrix_world.inverted()
    eb = arm.data.edit_bones
    parent = eb[pelvis]
    names = []
    pts = joints["tail"]
    for i in range(len(pts) - 1):
        b = eb.new("tail_%02d" % (i + 1))
        b.head = inv @ (Vector(pts[i]) * k + off)
        b.tail = inv @ (Vector(pts[i + 1]) * k + off)
        b.parent = parent
        b.use_connect = i > 0
        parent = b
        names.append(b.name)
    bpy.ops.object.mode_set(mode="OBJECT")
    return names


def _weigh_ears(body, arm, head_bone, joints, k, off, unit):
    """User request: the ears (the owl's tufts) twitch - each a short
    chain of bones from the head (joints["ears"]: its points root to tip,
    `reach` round them, free of the head `from` this share of its length
    on), the ear's points weighted along it, eased in from the head."""
    ears = joints.get("ears") or []
    if not ears:
        return
    chains = []
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    inv = arm.matrix_world.inverted()
    eb = arm.data.edit_bones
    per_side = {}
    for ear in ears:
        pts = ear["points"]
        side = "l" if pts[-1][0] > 0 else "r"
        per_side[side] = per_side.get(side, 0) + 1
        parent = eb[head_bone]
        names = []
        for i in range(len(pts) - 1):
            b = eb.new("ear_%s%d_%02d" % (side, per_side[side], i + 1))
            b.head = inv @ (Vector(pts[i]) * k + off)
            b.tail = inv @ (Vector(pts[i + 1]) * k + off)
            b.parent = parent
            b.use_connect = i > 0
            parent = b
            names.append(b.name)
        chains.append(names)
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = [[body.vertex_groups.get(n) or body.vertex_groups.new(name=n) for n in names] for names in chains]
    for ear, gs in zip(ears, groups):
        pts = [Vector(p) for p in ear["points"]]
        lengths = [(pts[j + 1] - pts[j]).length for j in range(len(pts) - 1)]
        total = sum(lengths)
        reach = ear["reach"]
        start = ear["from"]
        for v in body.data.vertices:
            p = unit(v.co)
            d, i, f = min((_seg_dist(p, pts[j], pts[j + 1]), j, _seg_t(p, pts[j], pts[j + 1]))
                          for j in range(len(pts) - 1))
            if d > reach:
                continue
            along = (sum(lengths[:i]) + lengths[i] * f) / total
            w = _smooth(start, start + EAR_EASE, along) * (1.0 - _smooth(reach * 0.75, reach, d))
            if w <= 1e-4:
                continue
            for g in v.groups:
                g.weight *= 1.0 - w
            # each bone's share peaks at its middle, shared at its ends
            at = i + f
            ws = {j: max(0.0, 1.0 - abs(at - j - 0.5)) for j in range(len(gs))}
            tot = sum(ws.values())
            for j, wj in ws.items():
                if wj > 0.0:
                    gs[j].add([v.index], w * wj / tot, "ADD")


def _copy_weights(src, dst):
    """dst's vertex groups from src's, at the nearest point of src's
    surface (interpolated across its face)."""
    for vg in src.vertex_groups:
        if dst.vertex_groups.get(vg.name) is None:
            dst.vertex_groups.new(name=vg.name)
    md = dst.modifiers.new("weights", "DATA_TRANSFER")
    md.object = src
    md.use_vert_data = True
    md.data_types_verts = {"VGROUP_WEIGHTS"}
    md.vert_mapping = "POLYINTERP_NEAREST"
    md.layers_vgroup_select_src = "ALL"
    md.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = dst
    dst.select_set(True)
    bpy.ops.object.modifier_apply(modifier=md.name)


def bind(arm, rig_name, character="owl", files=None):
    """The owl (or another animal person, `character`) on `arm` (Mixamo's
    or UAL's skeleton, T-posed): returns its one mesh, skinned to it; the
    skeleton's own meshes are taken off. `files` (a .glb and its .json)
    instead of the character's own - a greybox (greybox_animals.py)."""
    rig = RIGS[rig_name]
    glb, joints_path = files or paths(character)
    with open(joints_path) as fh:
        joints = json.load(fh)
    for o in [o for o in bpy.data.objects if o.type == "MESH" and (o.parent is arm or o.find_armature() is arm)]:
        bpy.data.objects.remove(o, do_unlink=True)
    before = set(bpy.data.objects)
    # Whole again (the file splits them where the picture's map does) -
    # weighted in pieces they'd tear apart at those seams.
    bpy.ops.import_scene.gltf(filepath=glb, merge_vertices=True)
    parts = {o.name.split(".")[0]: o for o in set(bpy.data.objects) - before if o.type == "MESH"}
    bpy.context.view_layer.update()
    targets, k, off = _targets(arm, rig, joints)
    for o in parts.values():
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        o.data.transform(Matrix.Translation(off) @ Matrix.Scale(k, 4))
        o.data.update()
    heads = _refit(arm, targets)
    # The segments the parts are weighted along: each bone to the next
    # joint of its chain (the head to its top; tips a little on).
    tails = {}
    for n in targets:
        nxt = _chain_next(arm, n, targets)
        if nxt is not None:
            tails[n] = heads[nxt]
        else:
            b = arm.data.bones[n]
            d = (arm.matrix_world @ b.tail_local) - (arm.matrix_world @ b.head_local)
            tails[n] = heads[n] + d
    head_bone = rig["trunk"][-1]
    if rig["head_top"] is None:
        tails[head_bone] = Vector(joints["head_top"]) * k + off

    if "owl_body" in parts:
        hd = _bind_greybox(arm, rig, joints, parts, heads, tails, targets, k, off)
        out = _join(parts, hd, arm)
        out[0]["char_k"] = k  # (world units a character unit: rod_grip.py)
        return out
    for name, spec in PART_JOINTS.items():
        _weigh_heat(parts[name], arm, _pick(rig, targets, spec), heads, tails)
    # The head: all the head's.
    hd = parts["owl_head"]
    hd.vertex_groups.new(name=head_bone).add(range(len(hd.data.vertices)), 1.0, "REPLACE")
    # The ruff: by how far above the jumper's neckline.
    height, cx, cy = _neckline(parts["owl_jumper"])
    ruff = parts["owl_ruff"]
    chest, neck = rig["trunk"][3], rig["trunk"][4]
    groups = {n: ruff.vertex_groups.new(name=n) for n in (chest, neck, head_bone)}
    for v in ruff.data.vertices:
        p = v.co
        h = (p.z - height(math.atan2(p.x - cx, -(p.y - cy)))) / k
        wc = 1.0 - _smooth(RUFF_CHEST[0], RUFF_CHEST[1], h)
        wh = _smooth(RUFF_HEAD[0], RUFF_HEAD[1], h)
        wn = max(1.0 - wc - wh, 0.0)
        for n, w in ((chest, wc), (neck, wn), (head_bone, wh)):
            if w > 1e-4:
                groups[n].add([v.index], w, "REPLACE")
    return _join(parts, hd, arm)


def player_files():
    """The player's character (PLAYER, the owl by default) and its files:
    a greybox's whenever GREYBOX_DIR is given - the owl's too; without it,
    PLAYER=owl is the baked owl person (files None)."""
    name = os.environ.get("PLAYER", "owl")
    gb = os.environ.get("GREYBOX_DIR")
    files = None
    if gb or name != "owl":
        files = (os.path.join(gb, name + "_greybox.glb"), os.path.join(gb, name + "_greybox.json"))
    return name, files


def player_stance(arm, rig_name, actions, standing=()):
    """close_stance() for the player's character (player_files())."""
    name, files = player_files()
    close_stance(arm, rig_name, actions, standing=standing, character=name, files=files)


def player(arm, rig_name, actions, standing=()):
    """The player's character on `arm`, for the tools that make the game's
    pictures of it (render_player.py, render_player_struggle.py,
    build_menu_character.py): the baked owl person, or - PLAYER=<animal>
    (user request: the black cat in the game) - a greybox animal person
    from GREYBOX_DIR (greybox_animals.py's build: <animal>_greybox.glb and
    .json, kept out of the repo like its other builds; with GREYBOX_DIR set
    the owl is its greybox too) in its trial colours
    (greybox_colour.py). Bound, its feet drawn in over `actions`; returns
    its meshes."""
    name, files = player_files()
    meshes = bind(arm, rig_name, name, files=files)
    if actions:
        close_stance(arm, rig_name, actions, standing=standing, character=name, files=files)
    if files:
        import greybox_colour
        greybox_colour.recolour(meshes, name)
    return meshes


def _join(parts, hd, arm):
    """The parts as one mesh, skinned to the skeleton."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = hd
    bpy.ops.object.join()
    hd.name = "owl"
    hd.data.name = "owl"
    hd.data.validate()
    bpy.ops.object.select_all(action="DESELECT")
    hd.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)
    md = hd.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    return [hd]


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args and args[0] == "bake":
        bake_character(os.path.abspath(args[1]), args[3] if len(args) > 3 and args[2] == "--name" else "owl")
