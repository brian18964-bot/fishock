"""An animal person from the user's Meshy model (user request: the bear,
the two dogs, the deer, the owl and the croc made in the dragon's and the
new cat's style - added beside the old ones, which stay), rigged onto the
game's skeleton the way tools/build_cat_meshy.py rigs the cat. Built from

  ID          its entry in tools/meshy_characters.py (its measurements)
  MESHY       Meshy's textured export (.fbx, or .glb), standing in an A pose
  SKELETON    one of the game's characters (assets/models/characters/
              dog.glb): the mannequin's bones with the fingers, and all
              the clips (every character has the same)

The mesh loses what the config says to remove, is brought down to TRIS
triangles with the high one's surface baked into a normal picture for it,
sized to `height` and stood on the ground. Then, in two passes:

  1. a rough skeleton at the measured joints, bound by bone heat, turns
     the arms up and the legs straight to the game's rest (a T pose) and
     lays the tail at rest (`angles`); the mesh is kept so - its picture
     repainted if the config says (`recolour`), and its hands cut off and
     the old characters' paws grown on in their place (paws(): each its
     own arm's girth, out of the sleeve or run on from the bare wrist);
  2. the game's skeleton is moved onto it - each bone to its joint here,
     keeping its turn (so every clip plays as it does) - the fingers at
     the paws' own knuckles, the ears and the tail from pass 1
     (EarTailSway moves them) - and the mesh bound to it, the paws on
     their own parts' bones (paw_skin()).

  bpyenv/bin/python tools/build_meshy_character.py -- ID MESHY SKELETON OUT.glb [LOW.blend]

LOW.blend (optional) keeps the brought-down, baked mesh between runs.

A config's `mixamo` names a Mixamo auto-rig of the same Meshy model (the
user's upload, beside MESHY): its joints are then pass 1's and its skin
both passes', in place of the measured joints and bone heat (user report:
the black bear's fat, jumpered body never came out right under bone heat).
"""
import heapq
import math
import os
import sys
import time
from collections import defaultdict

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from meshy_characters import CHARACTERS  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ID, MESHY, SKELETON, OUT = args[:4]
LOW = args[4] if len(args) > 4 else ""
CFG = CHARACTERS[ID]
MIXAMO = os.path.join(os.path.dirname(MESHY), CFG["mixamo"]) if CFG.get("mixamo") else ""
# (a Mixamo auto-rig of the finished body itself - its T pose, paws and all,
# as tools/export_tpose.py writes it out of the game's model)
MIXAMO_FINAL = os.path.join(os.path.dirname(MESHY), CFG["mixamo_final"]) if CFG.get("mixamo_final") else ""
TRIS = 36000
NORMAL_SIZE = 2048
SHIP_COLOUR = 1536
SHIP_DETAIL = 1024
# (set from the mesh: its feet in Meshy's frame, and the size it's brought to)
FEET = 0.0
SCALE = 1.0
# Where its hips are put (m, behind the origin - as the game's characters
# stand: the origin is what collides, under the middle of them).
HIPS_BACK = 0.05
# The bones pass 1 turns to the game's rest.
TURNED = ("upperarm", "lowerarm", "hand", "thigh", "calf", "foot", "ball")
# The game's bones that take pass 1's joints.
FROM_PASS1 = ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle", "upperarm",
              "lowerarm", "hand", "thigh", "calf", "foot", "ball")


def _p(x, y, z):
    """A point in Meshy's frame, in the game's (the hips over the origin)."""
    return Vector((x, y - CFG["joints"]["pelvis"][0], z - FEET)) * SCALE + Vector((0.0, HIPS_BACK, 0.0))


def _meshy(co):
    """Game-frame points (n x 3) back in Meshy's frame."""
    out = (co - np.array([0.0, HIPS_BACK, 0.0])) / SCALE
    return out + np.array([0.0, CFG["joints"]["pelvis"][0], FEET])


def select(objs, active=None):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active or objs[0]


def coords(obj):
    me = obj.data
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    m = np.array(obj.matrix_world)
    return co @ m[:3, :3].T + m[:3, 3]


def edges(obj):
    ed = np.zeros(len(obj.data.edges) * 2, int)
    obj.data.edges.foreach_get("vertices", ed)
    return ed.reshape(-1, 2)


# ---------------------------------------------------------------- the mesh

def import_meshy():
    before = set(bpy.data.objects)
    if MESHY.endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=MESHY)
    else:
        bpy.ops.import_scene.fbx(filepath=MESHY)
    new = [o for o in set(bpy.data.objects) - before]
    hi = next(o for o in new if o.type == 'MESH')
    for o in new:
        if o is not hi and o.type != 'MESH':
            if hi.parent is o:
                mw = hi.matrix_world.copy()
                hi.parent = None
                hi.matrix_world = mw
            bpy.data.objects.remove(o, do_unlink=True)
    select([hi])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # (the stray bits off first, while they're loose pieces)
    remove_bits(hi)
    # (a .glb comes split at its picture's seams: joined up again, or bone
    # heat can't reach across them)
    select([hi])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0001)
    bpy.ops.object.mode_set(mode='OBJECT')
    hi.name = "High"
    return hi


def colours(obj):
    """Each vertex's colour off its picture."""
    me = obj.data
    nt = obj.active_material.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    node = bsdf.inputs['Base Color'].links[0].from_node
    while node.type != 'TEX_IMAGE':
        node = next(i for i in node.inputs if i.links).links[0].from_node
    img = node.image
    w, h = img.size
    px = np.array(img.pixels[:]).reshape(h, w, img.channels)[:, :, :3]
    uv = np.zeros(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    vi = np.zeros(len(me.loops), int)
    me.loops.foreach_get("vertex_index", vi)
    col = np.zeros((len(me.vertices), 3))
    col[vi] = px[np.clip((uv[:, 1] % 1 * h).astype(int), 0, h - 1), np.clip((uv[:, 0] % 1 * w).astype(int), 0, w - 1)]
    return col


def islands(obj):
    n = len(obj.data.vertices)
    parent = np.arange(n)

    def find(a):
        r = a
        while parent[r] != r:
            r = parent[r]
        while parent[a] != r:
            parent[a], a = r, parent[a]
        return r
    for a, b in edges(obj):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    return np.array([find(i) for i in range(n)])


def remove_bits(hi):
    """Loose pale pieces wholly inside a `remove` sphere, gone."""
    spots = CFG.get("remove", [])
    if not spots:
        return
    co = coords(hi)
    lum = colours(hi).mean(1)
    roots = islands(hi)
    gone = np.zeros(len(co), bool)
    for centre, r in spots:
        inside = np.linalg.norm(co - np.array(centre), axis=1) < r
        for root in np.unique(roots[inside]):
            m = roots == root
            if inside[m].all() and lum[m].mean() > 0.6:
                gone |= m
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(hi.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.where(gone)[0]], context='VERTS')
    bm.to_mesh(hi.data)
    bm.free()
    print("removed %d stray vertices" % gone.sum())


def feeds(node, socket):
    """Whether `node` leads (through any nodes between) into `socket`."""
    seen, todo = set(), [node]
    while todo:
        n = todo.pop()
        if n.name in seen:
            continue
        seen.add(n.name)
        for out in n.outputs:
            for link in out.links:
                if link.to_socket == socket:
                    return True
                todo.append(link.to_node)
    return False


def mesh():
    global FEET, SCALE
    if LOW and os.path.exists(LOW):
        with bpy.data.libraries.load(LOW) as (src, dst):
            dst.objects = [ID]
        lo = dst.objects[0]
        bpy.context.scene.collection.objects.link(lo)
        FEET, SCALE = lo["feet"], lo["scale"]
        print("mesh from", LOW)
        return centred(lo)
    hi = import_meshy()
    co = coords(hi)
    FEET = float(co[:, 2].min())
    SCALE = CFG["height"] / float(co[:, 2].max() - FEET)
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = ID
    bpy.context.scene.collection.objects.link(lo)
    tris = sum(len(p.vertices) - 2 for p in hi.data.polygons)
    m = lo.modifiers.new("Less", 'DECIMATE')
    m.ratio = min(1.0, TRIS / tris)
    m.use_collapse_triangulate = True
    select([lo])
    bpy.ops.object.modifier_apply(modifier="Less")
    mat = lo.data.materials[0].copy()
    mat.name = ID + "_Skin"
    lo.data.materials[0] = mat
    img = bpy.data.images.new(ID + "_Normal", NORMAL_SIZE, NORMAL_SIZE)
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
    bk.cage_extrusion = 0.01
    bk.max_ray_distance = 0.03
    bk.margin = 8
    select([hi, lo], active=lo)
    t = time.time()
    bpy.ops.object.bake(type='NORMAL')
    print("baked the normal picture in %.0f s" % (time.time() - t))
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    nm = next((n for n in nt.nodes if n.type == 'NORMAL_MAP'), None)
    if nm is None:
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(nm.outputs[0], bsdf.inputs['Normal'])
    for link in list(nm.inputs['Color'].links):
        nt.links.remove(link)
    nt.links.new(node.outputs['Color'], nm.inputs['Color'])
    for link in list(bsdf.inputs['Metallic'].links):
        nt.links.remove(link)
    bsdf.inputs['Metallic'].default_value = 0.0
    bpy.data.objects.remove(hi, do_unlink=True)
    for n in list(nt.nodes):
        if n.type == 'TEX_IMAGE' and n.image is not None and n.image is not img and not (
                feeds(n, bsdf.inputs['Base Color']) or feeds(n, bsdf.inputs['Roughness'])):
            nt.nodes.remove(n)
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None and n.image is not img and n.image.size[0] > 0:
            rough = feeds(n, bsdf.inputs['Roughness'])
            ship = SHIP_DETAIL if rough else SHIP_COLOUR
            n.image.scale(ship, ship)
            n.image.name = ID + ("_Roughness" if rough else "_Colour")
            n.image.pack()
    img.scale(SHIP_DETAIL, SHIP_DETAIL)
    img.pack()
    lo.location.z -= FEET
    lo.location *= SCALE
    lo.scale = (SCALE, SCALE, SCALE)
    select([lo])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo["feet"], lo["scale"] = FEET, SCALE
    print("mesh: %d triangles, %.3f the size" % (sum(len(p.vertices) - 2 for p in lo.data.polygons), SCALE))
    if LOW:
        bpy.data.libraries.write(LOW, {lo}, fake_user=True, compress=True)
    return centred(lo)


def centred(lo):
    """The mesh moved so its hips are over the origin (HIPS_BACK behind)."""
    lo.location.y += HIPS_BACK - CFG["joints"]["pelvis"][0] * SCALE
    select([lo])
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return lo


# ---------------------------------------------------------------- pass 1

def tail_line(body):
    """The tail's middle line (Meshy's frame): the mesh behind `behind` and
    below `below`, reached over its edges from the root, its centre every
    few cm of the way out."""
    t = CFG["tail"]
    co = _meshy(coords(body))
    ok = (co[:, 1] > t["behind"]) & (co[:, 2] < t["below"])
    adj = defaultdict(list)
    for a, b in edges(body):
        if ok[a] and ok[b]:
            d = float(np.linalg.norm(co[a] - co[b]))
            adj[a].append((b, d))
            adj[b].append((a, d))
    # (and across the gaps: a generated mesh comes in loose pieces - near
    # points join up)
    from scipy.spatial import cKDTree
    idx = np.where(ok)[0]
    for i, j in cKDTree(co[idx]).query_pairs(0.012):
        a, b = int(idx[i]), int(idx[j])
        d = float(np.linalg.norm(co[a] - co[b]))
        adj[a].append((b, d))
        adj[b].append((a, d))
    root = int(idx[np.argmin(np.linalg.norm(co[idx] - np.array(t["root"]), axis=1))])
    dist = {root: 0.0}
    heap = [(0.0, root)]
    while heap:
        d, v = heapq.heappop(heap)
        if d > dist.get(v, 1e9):
            continue
        for w, l in adj[v]:
            if d + l < dist.get(w, 1e9):
                dist[w] = d + l
                heapq.heappush(heap, (d + l, w))
    vs = np.array(list(dist))
    ds = np.array([dist[v] for v in vs])
    step = max(ds.max() / 24.0, 0.02)
    line = [tuple(t["root"])]
    for a in np.arange(step, ds.max(), step):
        m = (ds >= a) & (ds < a + step)
        if m.sum() >= 3:
            line.append(tuple(co[vs[m]].mean(0)))
    print("tail: %d vertices, %.2f long" % (len(vs), ds.max()))
    return [_p(*c) for c in line]


def even(pts, n):
    run = [0.0]
    for a, b in zip(pts, pts[1:]):
        run.append(run[-1] + (b - a).length)
    out = []
    for i in range(n + 1):
        s = run[-1] * i / n
        k = max(j for j in range(len(run)) if run[j] <= s + 1e-9)
        if k >= len(pts) - 1:
            out.append(pts[-1])
            continue
        f = (s - run[k]) / max(run[k + 1] - run[k], 1e-9)
        out.append(pts[k].lerp(pts[k + 1], f))
    return out


# Mixamo's bones (less their "mixamorig:") as the game's, the sides as
# "Left"/"Right" -> "_l"/"_r"; the fingers the hand's.
MIX_TRUNK = {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01",
             "Head": "Head", "HeadTop_End": "Head"}
MIX_SIDE = {"Shoulder": "clavicle", "Arm": "upperarm", "ForeArm": "lowerarm", "Hand": "hand", "UpLeg": "thigh",
            "Leg": "calf", "Foot": "foot", "ToeBase": "ball", "Toe_End": "ball"}
# (pass 1's joints from Mixamo's bones' heads)
MIX_JOINTS = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
              "neck_01": "Neck", "Head": "Head", "head_end": "HeadTop_End", "clavicle": "Shoulder",
              "upperarm": "Arm", "lowerarm": "ForeArm", "hand": "Hand", "hand_end": "HandMiddle4",
              "thigh": "UpLeg", "calf": "Leg", "foot": "Foot", "ball": "ToeBase", "toe": "Toe_End"}
MIX = None


def _mix_name(n):
    n = n.split(":")[-1]
    if n in MIX_TRUNK:
        return MIX_TRUNK[n]
    for side, s in (("Left", "_l"), ("Right", "_r")):
        if n.startswith(side):
            rest = n[len(side):]
            if rest.startswith("Hand"):
                return "hand" + s
            if rest in MIX_SIDE:
                return MIX_SIDE[rest] + s
    return None


def load_mixamo(path=None, final=False):
    """The Mixamo rig at rest, in the game's frame: its points, their skin
    (on the game's bones' names) and its joints. `final`: a rig of the
    finished body, already in the game's frame."""
    global MIX
    path = path or MIXAMO
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = list(set(bpy.data.objects) - before)
    arm = next(o for o in new if o.type == 'ARMATURE')
    me = next(o for o in new if o.type == 'MESH')
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    M = np.array(me.matrix_world)
    co = np.array([v.co for v in me.data.vertices]) @ M[:3, :3].T + M[:3, 3]

    def game(p):
        p = np.asarray(p, float)
        if final:
            return p
        return (p - np.array([0.0, CFG["joints"]["pelvis"][0], FEET])) * SCALE + np.array([0.0, HIPS_BACK, 0.0])
    names = sorted({_mix_name(g.name) for g in me.vertex_groups} - {None})
    col = {n: i for i, n in enumerate(names)}
    gmap = {g.index: _mix_name(g.name) for g in me.vertex_groups}
    W = np.zeros((len(co), len(names)))
    for v in me.data.vertices:
        for g in v.groups:
            n = gmap[g.group]
            if n:
                W[v.index, col[n]] += g.weight
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    joints = {b.name.split(":")[-1]: game(arm.matrix_world @ b.head_local) for b in arm.data.bones}
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    MIX = dict(co=game(co), W=W, names=names, joints=joints, final=final)
    print("mixamo: %d points, %d bones' skin, from %s" % (len(co), len(names), os.path.basename(path)))


# The game's bones moved onto a final Mixamo rig's joints (their turn kept, so
# every clip plays as it does): its skin was made for them. The hands, their
# fingers, the head, the ears and the tail stay pass 1's - the paws are the
# old characters', grown on; Mixamo's head joint sat off the head's skin (the
# black-faced sheep's head tore).
MIX_MOVE = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck",
            "clavicle": "Shoulder", "upperarm": "Arm", "lowerarm": "ForeArm", "thigh": "UpLeg",
            "calf": "Leg", "foot": "Foot", "ball": "ToeBase"}


def mix_refit(game):
    inv = np.array(game.matrix_world.inverted())
    J = MIX["joints"]

    def at(name):
        side = name[-2:] if name[-2:] in ("_l", "_r") else ""
        part = name[:-2] if side else name
        key = MIX_MOVE.get(part)
        if key is None:
            return None
        key = ({"_l": "Left", "_r": "Right"}.get(side, "")) + key
        if key not in J:
            return None
        p = np.asarray(J[key])
        return Vector(tuple(p @ inv[:3, :3].T + inv[:3, 3]))
    select([game])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = game.data.edit_bones
    heads = {b.name: at(b.name) for b in eb}
    moved = 0
    for b in eb:
        h = heads[b.name]
        if h is None:
            continue
        # (its length to its child's new head, where there's one)
        kids = [heads[c.name] for c in b.children if heads.get(c.name) is not None]
        if b.name.startswith("lowerarm"):
            t = b.tail
        elif kids:
            t = min(kids, key=lambda k: (k - h).length)
        else:
            t = h + (b.tail - b.head)
        roll = b.roll
        way = (b.tail - b.head).normalized()
        b.head = h
        b.tail = h + way * max((t - h).length, 0.01)
        b.roll = roll
        moved += 1
    bpy.ops.object.mode_set(mode='OBJECT')
    print("mixamo joints: %d of the game's bones moved onto them" % moved)


def slim(body):
    """The trunk drawn in (CFG `slim`: (across, front, back) - how much less),
    between the hips' joints and the shoulders - the arms, legs and head as
    they are (user request: the black bear thinner). The Mixamo rig's points
    drawn in alike, so its skin still lies on them."""
    k = CFG.get("slim")
    if not k or not MIX:
        return
    from scipy.spatial import cKDTree
    J = MIX["joints"]
    hip, sh, y0 = J["LeftUpLeg"][2], J["LeftArm"][2], J["Spine1"][1]
    names = MIX["names"]
    trunk = MIX["W"][:, [i for i, n in enumerate(names) if n.startswith(("pelvis", "spine"))]].sum(axis=1)
    arms = MIX["W"][:, [i for i, n in enumerate(names) if n.startswith(("clavicle", "upperarm", "lowerarm", "hand"))]].sum(axis=1)

    def drawn(co, t, a):
        f = _ease(hip - 0.03, hip + 0.13, co[:, 2]) * (1.0 - _ease(sh - 0.19, sh, co[:, 2])) * np.clip(t - a, 0.0, 1.0)
        out = co.copy()
        out[:, 0] *= 1.0 - k[0] * f
        dy = co[:, 1] - y0
        out[:, 1] = y0 + dy * np.where(dy < 0, 1.0 - k[1] * f, 1.0 - k[2] * f)
        return out
    co = coords(body)
    _, j = cKDTree(MIX["co"]).query(co)
    new = drawn(co, trunk[j], arms[j])
    inv = np.array(body.matrix_world.inverted())
    body.data.vertices.foreach_set("co", (new @ inv[:3, :3].T + inv[:3, 3]).ravel())
    body.data.update()
    MIX["co"] = drawn(MIX["co"], trunk, arms)
    print("slim: the trunk drawn in by %s" % (k,))


def mix_skin(body, arm):
    """The Mixamo rig's skin on the body (each point its nearest few of the
    rig's, by distance) - bound to `arm` without bone heat."""
    from scipy.spatial import cKDTree
    for m in list(body.modifiers):
        if m.type == 'ARMATURE':
            body.modifiers.remove(m)
    body.vertex_groups.clear()
    select([body, arm], active=arm)
    bpy.ops.object.parent_set(type='ARMATURE_NAME')
    co = coords(body)
    d, j = cKDTree(MIX["co"]).query(co, k=4)
    w = 1.0 / np.maximum(d, 1e-5)
    W = (MIX["W"][j] * w[:, :, None]).sum(axis=1) / w.sum(axis=1)[:, None]
    groups = {g.name: g for g in body.vertex_groups}
    for c, n in enumerate(MIX["names"]):
        if n not in groups:
            groups[n] = body.vertex_groups.new(name=n)
        idx = np.nonzero(W[:, c] > 1e-3)[0]
        for i in idx.tolist():
            groups[n].add([i], float(W[i, c]), 'REPLACE')
    print("mixamo skin: %d points, farthest from the rig's %.3f" % (len(co), float(d[:, 0].max())))


def rough_skeleton(body):
    j = CFG["joints"]

    def mid(name):
        if MIX:
            return Vector(tuple(MIX["joints"][MIX_JOINTS[name]]))
        y, z = j[name]
        return _p(0.0, y, z)

    def side(name, k):
        # (the wrist where it was measured: the hand's cut off there and its
        # paw grown on - at Mixamo's, a cm further in, a scrap of the old
        # hand's black fur was left outside the cuff)
        if MIX and name not in ("hand", "hand_end"):
            return Vector(tuple(MIX["joints"][("Left" if k > 0 else "Right") + MIX_JOINTS[name]]))
        x, y, z = j[name]
        return _p(x * k, y, z)
    trunk = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "head_end"]
    specs = []
    for a, b in zip(trunk, trunk[1:]):
        specs.append((a, mid(a), mid(b), None if a == "pelvis" else trunk[trunk.index(a) - 1]))
    limbs = [("clavicle", "upperarm", "spine_03"), ("upperarm", "lowerarm", "clavicle"),
             ("lowerarm", "hand", "upperarm"), ("hand", "hand_end", "lowerarm"),
             ("thigh", "calf", "pelvis"), ("calf", "foot", "thigh"), ("foot", "ball", "calf"), ("ball", "toe", "foot")]
    for s, k in (("l", 1.0), ("r", -1.0)):
        for a, b, parent in limbs:
            par = parent if parent in trunk else parent + "_" + s
            specs.append((a + "_" + s, side(a, k), side(b, k), par))
        for e, chain in enumerate(CFG.get("ears", [])):
            pts = [_p(x * k, y, z) for x, y, z in chain]
            for i in range(len(pts) - 1):
                name = "ear_%s%d_%02d" % (s, e + 1, i + 1)
                specs.append((name, pts[i], pts[i + 1], "Head" if i == 0 else "ear_%s%d_%02d" % (s, e + 1, i)))
    if CFG.get("tail"):
        pts = even(tail_line(body), CFG["tail"]["bones"])
        for i in range(CFG["tail"]["bones"]):
            specs.append(("tail_%02d" % (i + 1), pts[i], pts[i + 1], "pelvis" if i == 0 else "tail_%02d" % i))
    data = bpy.data.armatures.new("Rough")
    arm = bpy.data.objects.new("Rough", data)
    bpy.context.scene.collection.objects.link(arm)
    select([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = data.edit_bones
    for name, h, t, parent in specs:
        b = eb.new(name)
        b.head, b.tail = h, t
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def _centre_legs(body, rough):
    """The rough skeleton's knees and ankles put on each leg's own middle
    (user report: in game the right calf was set off from the thigh at the
    knee, the left not - the joints are read off one side and mirrored, and
    a generated body isn't: the collie's right shin stood 5 cm outside its
    bones). Each cut across its leg at the joint, the joint moved to the
    middle of what's within LEG_FIND of it."""
    co = coords(body)
    select([rough])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rough.data.edit_bones
    M = rough.matrix_world
    inv = M.inverted()
    for s in ("l", "r"):
        for joint, bone in (("knee", "calf_" + s), ("ankle", "foot_" + s)):
            b = eb[bone]
            at = np.array(M @ b.head)
            par = b.parent
            u = np.array(M.to_3x3() @ (par.tail - par.head))
            u /= np.linalg.norm(u)
            rel = co - at
            x = rel @ u
            m = (np.abs(x) < 0.012) & (np.sign(co[:, 0]) == np.sign(at[0]))
            c = at.copy()
            for _ in range(4):
                near = m & (np.linalg.norm(co - c - np.outer((co - c) @ u, u), axis=1) < LEG_FIND)
                if near.sum() < 8:
                    break
                side_ = co[near] - at
                side_ -= np.outer(side_ @ u, u)
                c = at + (np.percentile(side_, 95, axis=0) + np.percentile(side_, 5, axis=0)) / 2.0
            d = Vector(tuple(c - at))
            if d.length < 1e-4:
                continue
            d = inv.to_3x3() @ d
            # (the ankle alone: the ball and toes stay on the foot's own)
            b.head = b.head + d
            par.tail = b.head
            print("%s_%s: moved %.3f onto the leg's middle" % (joint, s, float(np.linalg.norm(c - at))))
    bpy.ops.object.mode_set(mode='OBJECT')


def heat(body, arm):
    """Bone heat; what it leaves out on its nearest bone."""
    for m in list(body.modifiers):
        if m.type == 'ARMATURE':
            body.modifiers.remove(m)
    body.vertex_groups.clear()
    select([body, arm], active=arm)
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    segs = [(b.name, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local)
            for b in arm.data.bones if b.use_deform]
    groups = {g.name: g for g in body.vertex_groups}
    loose = 0
    for v in body.data.vertices:
        if v.groups:
            continue
        p = body.matrix_world @ v.co
        best, name = 9.0, None
        for n, a, b in segs:
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
            d = (a + ab * t - p).length
            if d < best:
                best, name = d, n
        if name not in groups:
            groups[name] = body.vertex_groups.new(name=name)
        groups[name].add([v.index], 1.0, 'REPLACE')
        loose += 1
    print("bound: %d loose vertices on their nearest bone" % loose)


def _ease(a, b, x):
    t = np.clip((np.asarray(x, float) - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# The skin laid as the old characters' is (owl_character._bind_greybox) where
# bone heat on a generated mesh - its shells lying over each other, the
# sweater over the body - went wrong (user report: the snouts tore as the
# ears swayed and the head turned; the shoulders pulled the sides up into
# wings as the arms rose; the croc's legs stuck together):
#   the head rigid above the neck, the snout and jaw with it (heat gave
#   the face to the ears, the neck);
#   each ear on its own bones only round its own line, from EAR_FROM of
#   its length on, EAR_REACH of that length round it;
#   the arms' share of the torso no more than an easing over SHOULDER_EASE
#   (m, across the shoulder's joint), the rest the clavicle's; round the
#   shoulders each point's skin its neighbours' within SMOOTH_R (the
#   sweater and the body under it moving as one);
#   a leg's skin below the crotch on that leg's bones alone.
EAR_FROM = 0.25
EAR_REACH = 0.33
SHOULDER_EASE = (-0.12, 0.09)
# (the arm's share eased out between these times its own girth from its line)
ARM_REACH = (1.15, 1.6)
# (and the clavicle's share of the torso by the shoulder - the old dog's
# 0.65 to 0.8 - taken from the spine's)
CLAVICLE_SHARE = 0.7
SMOOTH_R = 0.035
SMOOTH_TIMES = 4
# The trunk laid along the spine from this far over the hips' joints (eased
# in up to the second; m)
TRUNK_FROM = (0.02, 0.10)
# ... and the weights smoothed this far round the neck's root (m)
NECK_SMOOTH = 0.22
# ... and round the knees and the hips' joints
KNEE_SMOOTH = 0.12
# (the knee's thigh-to-calf split eased over this either side of the joint,
# within KNEE_SPLIT of it)
KNEE_BLEND = 0.05
# (a leg's middle at a joint: what's within this of the joint across it)
LEG_FIND = 0.11
KNEE_SPLIT = 0.16


def tidy_skin(body, arm):
    from scipy.spatial import cKDTree
    co = coords(body)
    me = body.data
    for b in arm.data.bones:
        if b.use_deform and body.vertex_groups.get(b.name) is None and (
                b.name.startswith(("ear_", "clavicle", "thigh", "calf", "foot", "ball", "spine")) or
            b.name in ("Head", "pelvis")):
            body.vertex_groups.new(name=b.name)
    groups = {g.name: g for g in body.vertex_groups}
    names = list(groups)
    col = {n: i for i, n in enumerate(names)}

    def need(n):
        assert n in col, n
    W = np.zeros((len(co), len(names)))
    gi = {g.index: col[g.name] for g in body.vertex_groups}
    for v in me.vertices:
        for g in v.groups:
            W[v.index, gi[g.group]] = g.weight

    def bone(n, end="head"):
        b = arm.data.bones[n]
        return np.array(arm.matrix_world @ (b.head_local if end == "head" else b.tail_local))
    # (the ears' heat back on the head; laid again below)
    need("Head")
    ears = sorted(n for n in names if n.startswith("ear_"))
    for n in ears:
        W[:, col["Head"]] += W[:, col[n]]
        W[:, col[n]] = 0.0
    # The head: rigid from the neck's middle up, and anything ahead of the
    # neck above its root (the snout, the jaw).
    H, N = bone("Head"), bone("neck_01")
    L = H[2] - N[2]
    z0, z1 = N[2] + 0.3 * L, N[2] + 0.8 * L
    shoulder = abs(bone("upperarm_l")[0])
    flat = np.hypot(co[:, 0] - N[0], co[:, 1] - N[1])
    hw = _ease(z0, z1, co[:, 2]) * (flat < 0.7 * shoulder)
    ahead = (co[:, 2] > z0) & (co[:, 1] < N[1] - 0.06) & (np.abs(co[:, 0]) < 0.7 * shoulder)
    hw = np.maximum(hw, ahead * _ease(z0, 0.5 * (z0 + z1), co[:, 2]))
    hw = np.where((co[:, 2] >= z1) & (np.linalg.norm(co - H, axis=1) < 0.5), 1.0, hw)
    W *= (1.0 - hw)[:, None]
    W[:, col["Head"]] += hw
    print("head: %d points rigid with it, %d eased" % ((hw > 0.999).sum(), ((hw > 0.0) & (hw <= 0.999)).sum()))
    # The ears, each round its own line.
    chains = {}
    for n in ears:
        chains.setdefault(n[:-3], []).append(n)
    for key, bones in chains.items():
        bones.sort()
        pts = [bone(bones[0])] + [bone(b, "tail") for b in bones]
        lens = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(bones))]
        total = sum(lens)
        reach = min(EAR_REACH * total, 0.07)
        best_d = np.full(len(co), 9.0)
        best_at = np.zeros(len(co))
        for i in range(len(bones)):
            a, b = pts[i], pts[i + 1]
            ab = b - a
            t = np.clip((co - a) @ ab / max(ab @ ab, 1e-9), 0.0, 1.0)
            d = np.linalg.norm(co - (a + t[:, None] * ab), axis=1)
            better = d < best_d
            best_d[better] = d[better]
            best_at[better] = i + t[better]
        along = np.array([sum(lens[:int(min(a_, len(bones) - 1e-6))]) + lens[int(min(a_, len(bones) - 1e-6))]
                          * (a_ - int(min(a_, len(bones) - 1e-6))) for a_ in best_at]) / total
        w = _ease(EAR_FROM, EAR_FROM + 0.2, along) * (1.0 - _ease(0.75 * reach, reach, best_d))
        w *= best_d < reach
        for b in bones:
            need(b)
        idx = np.nonzero(w > 1e-4)[0]
        W[idx] *= (1.0 - w[idx])[:, None]
        for j, b in enumerate(bones):
            share = np.clip(1.0 - np.abs(best_at[idx] - j - 0.5), 0.0, 1.0)
            tot = sum(np.clip(1.0 - np.abs(best_at[idx] - k - 0.5), 0.0, 1.0) for k in range(len(bones)))
            W[idx, col[b]] += w[idx] * share / np.maximum(tot, 1e-6)
        print("ear %s: %d points on it" % (key, len(idx)))
    # The trunk: by height up the spine (user report: the black bear's belly
    # dented and tore - heat gave its whole round front to the pelvis and
    # thighs, the spine's bones running down its back far from it, so the
    # chest went with the spine and the belly with the hips). Above the
    # hips' joints the thighs' share and the trunk bones' (pelvis, spine)
    # are laid again along the spine by height, the old characters' way;
    # the arms' and neck's left as they are.
    trunk = [n for n in ("pelvis", "spine_01", "spine_02", "spine_03") if n in col]
    tz = np.array([bone(n)[2] for n in trunk])
    legs_ = [col[n] for n in names if n.startswith(("thigh_", "calf_"))]
    tcols = [col[n] for n in trunk]
    hip_z = bone("thigh_l")[2]
    # (a Mixamo skin's trunk kept as it is)
    up = _ease(hip_z + TRUNK_FROM[0], hip_z + TRUNK_FROM[1], co[:, 2]) * (1.0 - hw) * (0.0 if MIX else 1.0)
    moved = W[:, legs_].sum(axis=1) * up
    W[:, legs_] *= (1.0 - up)[:, None]
    # (and the tail's well up the back, heat's: user report, the black
    # bear's back taking a quarter of its little tail's sway)
    tails = [col[n] for n in names if n.startswith("tail")]
    if tails and "tail_01" in arm.data.bones:
        tz0 = bone("tail_01")[2]
        off = _ease(tz0 + 0.08, tz0 + 0.14, co[:, 2]) * (1.0 - hw)
        moved += W[:, tails].sum(axis=1) * off
        W[:, tails] *= (1.0 - off)[:, None]
    share = W[:, tcols].sum(axis=1) + moved
    zc = np.clip(co[:, 2], tz[0], tz[-1])
    tent = np.zeros((len(co), len(trunk)))
    for j in range(len(trunk)):
        lo = tz[j - 1] if j > 0 else tz[j] - 1.0
        hi = tz[j + 1] if j + 1 < len(trunk) else tz[j] + 1.0
        tent[:, j] = np.where(zc <= tz[j], (zc - lo) / max(tz[j] - lo, 1e-6), (hi - zc) / max(hi - tz[j], 1e-6))
    tent = np.clip(tent, 0.0, 1.0)
    tent /= np.maximum(tent.sum(axis=1, keepdims=True), 1e-9)
    # (by height where it's the trunk's; below the hips' joints - the legs'
    # tops, the seat - as heat had it)
    keep = 1.0 - _ease(hip_z + TRUNK_FROM[0], hip_z + TRUNK_FROM[1], co[:, 2])
    if MIX:
        keep[:] = 1.0
    W[:, tcols] = W[:, tcols] * keep[:, None] + (share * (1.0 - keep))[:, None] * tent
    print("trunk: %d points laid along the spine" % (up > 0.5).sum())
    # The shoulders: the arm's share of the torso eased in across the joint.
    def arm_girth(s):
        # (round the top of the upper arm, where no torso is)
        S = bone("upperarm_" + s)
        u = bone("upperarm_" + s, "tail") - S
        L = np.linalg.norm(u)
        u /= L
        t = (co - S) @ u
        on_line = S + np.clip(t, 0.0, L)[:, None] * u
        a = W[:, [col[n] for n in names if n.endswith("_" + s) and n.startswith(("upperarm", "lowerarm"))]].sum(axis=1)
        mid = (a > 0.95) & (t > 0.3 * L) & (t < 0.7 * L) & (on_line[:, 2] <= co[:, 2])
        return np.percentile(np.linalg.norm(co - on_line, axis=1)[mid], 75) if mid.sum() > 20 else 0.06
    # (the two arms the same girth - the larger, a generated body's two
    # sides weighted unlike)
    girth = max(arm_girth("l"), arm_girth("r"))
    for s, sign in (("l", 1.0), ("r", -1.0)):
        S = bone("upperarm_" + s)
        u = bone("upperarm_" + s, "tail") - S
        u /= np.linalg.norm(u)
        t = (co - S) @ u
        arm_cols = [col[n] for n in names if n.endswith("_" + s) and not n.startswith(
            ("clavicle", "thigh", "calf", "foot", "ball", "ear"))]
        need("clavicle_" + s)
        a = W[:, arm_cols].sum(axis=1)
        # (a Mixamo skin's shoulders kept)
        allowed = np.ones(len(co)) if MIX else _ease(SHOULDER_EASE[0], SHOULDER_EASE[1], t)
        # (and none of it on the torso well away from the arm's own line,
        # however far from the shoulder - user report, the black bear's
        # belly crumpled with its arms down: heat had given its front, a
        # third of a metre below and in from the shoulder, wholly to the
        # upper arm)
        E = bone("upperarm_" + s, "tail")
        L = np.linalg.norm(E - S)
        # (below the arm only - the belly under it)
        on_line = S + np.clip(t, 0.0, L)[:, None] * u
        down = np.clip(on_line[:, 2] - co[:, 2], 0.0, None)
        radial = np.maximum(1.0 - _ease(ARM_REACH[0] * girth, ARM_REACH[1] * girth, down), _ease(0.5 * L, 0.8 * L, t))
        allowed = allowed * radial
        over = a > allowed + 1e-6
        k = np.where(over, allowed / np.maximum(a, 1e-9), 1.0)
        moved = (a * (1.0 - k))
        W[:, arm_cols] *= k[:, None]
        # (what's taken: round the joint to the clavicle, further down the
        # side to the trunk, by height as the rest of it)
        cw = 1.0 - _ease(0.12, 0.22, np.linalg.norm(co - S, axis=1))
        W[:, col["clavicle_" + s]] += moved * cw
        W[:, tcols] += (moved * (1.0 - cw))[:, None] * tent
        print("shoulder_%s: arm's girth %.3f, %d points off it" % (s, girth, (over & (radial < 0.5)).sum()))
        if MIX:
            continue
        spine = [col[n] for n in ("spine_03", "spine_02") if n in col]
        # (faded out toward the edge of the shoulder's reach, not cut there:
        # on the black bear's broad chest the cut ran across its front)
        fade = (np.sign(co[:, 0]) == sign) * (1.0 - _ease(0.18, 0.3, np.linalg.norm(co - S, axis=1)))
        want = CLAVICLE_SHARE * _ease(-0.24, -0.12, t) * (1.0 - _ease(-0.02, 0.06, t)) * fade
        have = W[:, col["clavicle_" + s]]
        sp = W[:, spine].sum(axis=1)
        take = np.clip(want - have, 0.0, None)
        take = np.minimum(take, sp)
        ratio = np.where(sp > 1e-9, 1.0 - take / np.maximum(sp, 1e-9), 1.0)
        W[:, spine] *= ratio[:, None]
        W[:, col["clavicle_" + s]] += take
        print("shoulder_%s: %d points of the torso taken off the arm" % (s, over.sum()))
    if MIX:
        # (a Mixamo skin: its arms off the body under them, the rest as is)
        _write_skin(body, W, col, groups)
        return
    # ... and smoothed there, by where the points are, not how they're joined.
    zone = np.zeros(len(co), bool)
    for s in ("l", "r"):
        zone |= np.linalg.norm(co - bone("upperarm_" + s), axis=1) < 0.18
    # (and round the neck's root down into the V of the collar: user report,
    # the black bear's chest tore there - the collar and the fur inside it
    # lie over each other, and heat weighted them apart)
    zone |= (np.linalg.norm(co - bone("neck_01"), axis=1) < NECK_SMOOTH) & (hw < 0.5)
    # (and round the knees and hips: user report, the legs came apart
    # behind the knee as it bent - the fur's layers there weighted apart)
    for s in ("l", "r"):
        side = np.sign(co[:, 0]) == (1.0 if s == "l" else -1.0)
        for b, r in (("calf_" + s, KNEE_SMOOTH), ("thigh_" + s, KNEE_SMOOTH)):
            zone |= side & (np.linalg.norm(co - bone(b), axis=1) < r)
    # (and over the whole trunk, the shirt's front and the fur under it
    # lying over each other there too)
    zone |= (co[:, 2] > hip_z + TRUNK_FROM[0]) & (co[:, 2] < bone("neck_01")[2]) & \
        (np.abs(co[:, 0]) < abs(bone("upperarm_l")[0])) & (hw < 0.5)
    idx = np.nonzero(zone)[0]
    tree = cKDTree(co)
    nbrs = tree.query_ball_point(co[idx], SMOOTH_R)
    keep_head = hw[idx] > 0.5
    for _ in range(SMOOTH_TIMES):
        W[idx] = np.array([W[nb].mean(axis=0) for nb in nbrs])
    W[idx[keep_head]] = 0.0
    W[idx[keep_head], col["Head"]] = 1.0
    # The legs: below the crotch, each on its own.
    crotch = bone("thigh_l")[2] - 0.02
    for s, sign, o in (("l", 1.0, "r"), ("r", -1.0, "l")):
        m = (co[:, 2] < crotch) & (np.sign(co[:, 0]) == sign)
        for part in ("thigh", "calf", "foot", "ball"):
            if part + "_" + o in col:
                need(part + "_" + s)
                W[m, col[part + "_" + s]] += W[m, col[part + "_" + o]]
                W[m, col[part + "_" + o]] = 0.0
    # The knees: the thigh's and calf's shares split again across the joint
    # by how far along the leg each point is, eased over KNEE_BLEND either
    # side (user report: behind the knee the legs pinched and stepped as it
    # bent - heat had split them unevenly round it, front and back).
    for s, sign in (("l", 1.0), ("r", -1.0)):
        th, ca = col["thigh_" + s], col["calf_" + s]
        K = bone("calf_" + s)
        a = K - bone("thigh_" + s)
        b = bone("foot_" + s) - K
        d = a / np.linalg.norm(a) + b / np.linalg.norm(b)
        d /= np.linalg.norm(d)
        t = (co - K) @ d
        m = (np.sign(co[:, 0]) == sign) & (co[:, 2] < crotch) & (np.linalg.norm(co - K, axis=1) < KNEE_SPLIT)
        both = W[:, th] + W[:, ca]
        m &= both > 0.5 * W.sum(axis=1)
        f = _ease(-KNEE_BLEND, KNEE_BLEND, t)
        W[m, ca] = both[m] * f[m]
        W[m, th] = both[m] * (1.0 - f[m])
        print("knee_%s: %d points split across it" % (s, m.sum()))
    _write_skin(body, W, col, groups)


def _write_skin(body, W, col, groups):
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
    for g in body.vertex_groups:
        g.remove(range(len(W)))
    for n, c in col.items():
        idx = np.nonzero(W[:, c] > 1e-4)[0]
        for i in idx.tolist():
            groups[n].add([i], float(W[i, c]), 'REPLACE')


def part_legs(body, rough):
    """Legs the generation made as one (the croc's, touching from the
    crotch to the feet - walking, the skin between them stretched like a
    web): below the crotch each leg's inner side drawn in toward its own
    line (CFG part_legs of the way it was, eased in from the crotch), the
    faces still joining the two taken off and the holes they leave closed,
    the closing coloured as the skin round it."""
    import bmesh
    squeeze = CFG.get("part_legs")
    if not squeeze:
        return
    me = body.data
    M = np.array(body.matrix_world)
    inv = np.linalg.inv(M)

    def joint(n):
        return np.array(rough.matrix_world @ rough.data.bones[n].head_local)
    crotch = joint("thigh_l")[2]
    axes = {s: [joint("thigh_" + s), joint("calf_" + s), joint("foot_" + s)] for s in ("l", "r")}

    def axis_x(s, z):
        pts = axes[s]
        zs = [p[2] for p in pts][::-1]
        xs = [p[0] for p in pts][::-1]
        return np.interp(z, zs, xs)
    co = coords(body)
    below = co[:, 2] < crotch
    f = 1.0 - (1.0 - squeeze) * _ease(crotch, crotch - 0.08, co[:, 2])
    moved = 0
    for s, sign in (("l", 1.0), ("r", -1.0)):
        m = below & (np.sign(co[:, 0]) == sign)
        ax = axis_x(s, co[m, 2])
        inner = (co[m, 0] - ax) * sign < 0.0
        nx = np.where(inner, ax + (co[m, 0] - ax) * f[m], co[m, 0])
        moved += int(inner.sum())
        co[np.nonzero(m)[0], 0] = nx
    local = co @ inv[:3, :3].T + inv[:3, 3]
    me.vertices.foreach_set("co", local.ravel())
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    web = [fc for fc in bm.faces
           if all(co[v.index, 2] < crotch - 0.03 for v in fc.verts)
           and min(co[v.index, 0] for v in fc.verts) < 0.0 < max(co[v.index, 0] for v in fc.verts)]
    bmesh.ops.delete(bm, geom=web, context='FACES_ONLY')
    edges = [e for e in bm.edges if e.is_boundary and all(co[v.index, 2] < crotch for v in e.verts)]
    filled = bmesh.ops.holes_fill(bm, edges=edges, sides=0)["faces"]
    tri = bmesh.ops.triangulate(bm, faces=filled)["faces"] if filled else []
    uvl = bm.loops.layers.uv.active
    for fc in tri:
        for loop in fc.loops:
            others = [l for l in loop.vert.link_loops if l.face not in tri]
            if others:
                loop[uvl].uv = others[0][uvl].uv.copy()
    bm.to_mesh(me)
    bm.free()
    me.update()
    print("legs parted: %d points drawn in, %d faces between them off, %d holes closed" % (moved, len(web), len(filled)))


def own_legs(body, arm):
    """Below the crotch each point on its own side's leg bones only (user
    report, the black bear's remake: its legs nearly touch inside, and bone
    heat gave bits of each leg's inner side to the other leg - shards of
    skin tore across between them as they parted)."""
    crotch = (arm.matrix_world @ arm.data.bones["thigh_l"].head_local).z - 0.02
    co = coords(body)
    groups = {g.name: g for g in body.vertex_groups}
    names = {g.index: g.name for g in body.vertex_groups}
    moves = []
    for v in body.data.vertices:
        if co[v.index][2] >= crotch:
            continue
        own, other = ("_l", "_r") if co[v.index][0] > 0.0 else ("_r", "_l")
        w = {names[g.group]: g.weight for g in v.groups}
        for n, x in w.items():
            if n.endswith(other) and n[:-2] in ("thigh", "calf", "foot", "ball"):
                moves.append((v.index, n, n[:-2] + own, x + w.get(n[:-2] + own, 0.0)))
    for i, n, to, x in moves:
        groups[n].remove([i])
        if to not in groups:
            groups[to] = body.vertex_groups.new(name=to)
        groups[to].add([i], x, 'REPLACE')
    moved = len(moves)
    print("legs: %d of the other leg's weights moved to the point's own" % moved)


def tail_only(body, arm):
    """The tail's skin on the tail's bones alone."""
    if not CFG.get("tail"):
        return
    reach = CFG["tail"]["reach"]
    segs = [(b.name, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones
            if b.use_deform]

    def seg_dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (a + ab * t - p).length
    groups = {g.name: g for g in body.vertex_groups}
    index = {g.index: g.name for g in body.vertex_groups}
    moved = 0
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        best_tail, tail_bone, other = 9.0, None, 9.0
        for name, a, b in segs:
            d = seg_dist(p, a, b)
            if name.startswith("tail"):
                if d < best_tail:
                    best_tail, tail_bone = d, name
            else:
                other = min(other, d)
        if tail_bone is None or best_tail > reach or best_tail >= other:
            continue
        keep = {}
        for g in v.groups:
            name = index[g.group]
            if name.startswith("tail") or (name == "pelvis" and tail_bone == "tail_01"):
                keep[name] = g.weight
        if not keep:
            keep = {tail_bone: 1.0}
        for g in list(v.groups):
            if index[g.group] not in keep:
                groups[index[g.group]].remove([v.index])
        for name, w in keep.items():
            if name not in groups:
                groups[name] = body.vertex_groups.new(name=name)
            groups[name].add([v.index], w, 'REPLACE')
        moved += 1
    print("tail skin kept to the tail: %d vertices" % moved)


def turn_to(arm, pb, want):
    bpy.context.view_layer.update()
    now = (arm.matrix_world @ pb.matrix).to_3x3() @ Vector((0.0, 1.0, 0.0))
    turn = now.normalized().rotation_difference(want.normalized())
    world = arm.matrix_world.to_3x3()
    m = pb.matrix.copy()
    r = (world.inverted() @ turn.to_matrix() @ world).to_4x4()
    head = m.translation.copy()
    m.translation = Vector()
    m = r @ m
    m.translation = head
    pb.matrix = m


def pose_rest(body, rough, game):
    select([rough])
    bpy.ops.object.mode_set(mode='POSE')
    order = [b.name for b in rough.data.bones]
    order.sort(key=lambda n: len(rough.data.bones[n].parent_recursive))
    angles = (CFG.get("tail") or {}).get("angles")
    for name in order:
        part = name.rsplit("_", 1)[0]
        pb = rough.pose.bones[name]
        if part in TURNED:
            gb = game.data.bones[name]
            want = game.matrix_world.to_3x3() @ (gb.tail_local - gb.head_local)
            if part == "hand":
                tip = game.data.bones["middle_04_leaf_" + name[-1]].head_local
                want = game.matrix_world.to_3x3() @ (tip - gb.head_local)
            turn_to(rough, pb, want)
        elif name.startswith("tail_") and angles:
            a = math.radians(angles[int(name[5:]) - 1])
            turn_to(rough, pb, Vector((0.0, math.cos(a), -math.sin(a))))
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode='OBJECT')
    mod = next(m for m in body.modifiers if m.type == 'ARMATURE')
    select([body])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    select([rough])
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if CFG.get("tail"):
        low = min((rough.matrix_world @ b.tail_local).z for b in rough.data.bones if b.name.startswith("tail"))
        print("posed: the tail's lowest %.2f above the ground" % low)


# User requests: the new ones told apart from their old namesakes - the red
# deer a sika (lighter, white spots), the sheep a black-faced one, the bear
# a Formosan black bear (a white V on its chest). Their pictures repainted
# where on the body each texel is (texels(): baked off the posed mesh), each
# by its own rule (RECOLOUR) - before the paws are grown, so a paw takes the
# new colour at its wrist.

def texels(body):
    """The colour picture, and where on the body (the game's frame) and
    which way out each of its texels is - baked; `on` the texels painted on
    the body at all."""
    me = body.data
    mat = me.materials[0]
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    node = bsdf.inputs['Base Color'].links[0].from_node
    while node.type != 'TEX_IMAGE':
        node = next(i for i in node.inputs if i.links).links[0].from_node
    img = node.image
    w, h = img.size
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
    was = out.inputs['Surface'].links[0].from_socket
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    emit = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(emit.outputs[0], out.inputs['Surface'])
    target = nt.nodes.new('ShaderNodeTexImage')
    maps = {}
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.margin = 2
    for what in ("Position", "Normal"):
        buf = bpy.data.images.new("Bake" + what, w, h, alpha=True, float_buffer=True)
        buf.generated_color = (0.0, 0.0, 0.0, 0.0)
        target.image = buf
        for n in nt.nodes:
            n.select = False
        target.select = True
        nt.nodes.active = target
        nt.links.new(geo.outputs[what], emit.inputs['Color'])
        select([body])
        bpy.ops.object.bake(type='EMIT')
        px = np.array(buf.pixels[:]).reshape(h, w, 4)
        maps[what] = px
        bpy.data.images.remove(buf)
    nt.links.new(was, out.inputs['Surface'])
    for n in (geo, emit, target):
        nt.nodes.remove(n)
    colour = np.array(img.pixels[:]).reshape(h, w, img.channels)
    on = maps["Position"][:, :, 3] > 0.5
    return img, colour, maps["Position"][:, :, :3], maps["Normal"][:, :, :3], on


def _lum(c):
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def _bone(rough, name):
    b = rough.data.bones[name]
    return np.array(rough.matrix_world @ b.head_local), np.array(rough.matrix_world @ b.tail_local)


def _to_segment(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def _black_bear(P, N, C, rough):
    """Formosan black bear: the fur black (its own shading kept), the muzzle
    left tan, a cream V on the chest under the chin."""
    lum = _lum(C)
    fur = (lum < 0.40) & (C[:, 0] > C[:, 2])
    k = np.clip(lum[fur] / max(float(np.median(lum[fur])), 1e-3), 0.5, 1.8)
    C[fur] = np.array([0.065, 0.058, 0.056])[None, :] * k[:, None]
    # the V: on the chest's fur facing ahead, from its lowest point at the
    # middle up and out to each side
    chest = _bone(rough, "spine_03")[0][2]
    front = fur & (N[:, 1] < -0.45) & (np.abs(P[:, 0]) < 0.16) & (P[:, 2] > chest - 0.05)
    # (the fur shows in a V down into the jumper's neck: the bear's own V
    # inside it, its point a little above the jumper's)
    z0 = float(np.percentile(P[front, 2], 3)) + 0.035
    rise = 0.09
    up = P[:, 2] - z0
    arm = np.abs(np.abs(P[:, 0]) - up * (0.085 / rise) - 0.006)
    band = 0.018 + 0.008 * (1.0 - np.clip(up / rise, 0.0, 1.0))
    v = front & (up > -0.01) & (up < rise) & (arm < band)
    soft = np.clip((band - arm) / 0.006, 0.0, 1.0)[v]
    C[v] = C[v] * (1.0 - soft[:, None]) + np.array([0.92, 0.89, 0.80])[None, :] * soft[:, None]
    print("black bear: %d texels of fur, %d of the V (from %.2f up %.2f)" % (fur.sum(), v.sum(), z0, rise))


def _sika(P, N, C, rough):
    """Sika deer: the red-brown fur lighter and yellower, white spots where
    it shows - down the neck and the outsides of the legs."""
    rgb = C
    fur = (rgb[:, 0] > rgb[:, 1] * 1.32) & (rgb[:, 0] > 0.22) & (_lum(rgb) < 0.62)
    mean = rgb[fur].mean(0)
    target = np.array([0.76, 0.53, 0.31])
    C[fur] = np.clip(rgb[fur] * (target / mean), 0.0, 1.0)
    neck = _bone(rough, "neck_01")
    head = _bone(rough, "Head")
    near_neck = _to_segment(P, neck[0] - np.array([0, 0, 0.04]), head[0]) < 0.11
    legs = np.zeros(len(P), bool)
    for s in ("l", "r"):
        for seg in ("thigh", "calf"):
            a, b = _bone(rough, "%s_%s" % (seg, s))
            out = (P[:, 0] - a[0]) * np.sign(a[0])
            legs |= (_to_segment(P, a, b) < 0.09) & (out > -0.005) & (P[:, 2] > 0.18)
    from scipy.spatial import cKDTree
    # (user report: pale grey-green smudges high on the inside of the thighs
    # - the Meshy picture's, not red enough to be taken for fur: below the
    # shorts' hem each leg's texels that aren't fur, down to the hooves,
    # take the nearest fur's colour)
    tube = np.zeros(len(P), bool)
    for s in ("l", "r"):
        for seg in ("thigh", "calf"):
            a, b = _bone(rough, "%s_%s" % (seg, s))
            tube |= _to_segment(P, a, b) < 0.10
    hip = _bone(rough, "thigh_l")[0][2]
    hoof = _bone(rough, "foot_l")[0][2] + 0.05
    # (the hem: down from the hip, the last 1 cm band of the legs still
    # mostly cloth)
    hem = hip
    for z in np.arange(hip, hoof, -0.01):
        band = tube & (P[:, 2] < z) & (P[:, 2] >= z - 0.01)
        if band.sum() < 20 or (~fur[band]).mean() < 0.7:
            break
        hem = z - 0.01
    leg = tube & (P[:, 2] < hem - 0.01) & (P[:, 2] > hoof)
    # (by hue: the smudges yellow-green against the fur's red-brown, some
    # of them red enough to have passed for fur)
    gr = C[:, 1] / np.maximum(C[:, 0], 0.02)
    ref = np.median(gr[leg & fur]) if (leg & fur).any() else 0.7
    odd = leg & ((~fur & (_lum(rgb) < 0.85)) | (gr > ref + 0.08))
    print("sika: leg g/r median %.2f, percentiles %s" % (ref, np.round(np.percentile(gr[leg], [50, 90, 97, 99]), 2)))
    # (each from the nearest of the leg's typical fur - the fur at the
    # smudges' edges yellowed too)
    lum = _lum(C)
    src = leg & fur & ~odd & (np.abs(gr - ref) < 0.04)
    if src.sum() > 100:
        lo, hi = np.percentile(lum[src], [25, 85])
        src &= (lum > lo) & (lum < hi)
    if odd.any() and src.any():
        _, j = cKDTree(P[src]).query(P[odd])
        C[odd] = C[src][j]
        fur = fur | odd
    print("sika: hem at %.2f, %d off-colour leg texels made fur" % (hem, odd.sum()))
    where = fur & ((near_neck & (N[:, 1] > -0.4)) | legs)
    rng = np.random.default_rng(7)
    idx = np.where(where)[0]
    rng.shuffle(idx)
    spots = []
    for i in idx[:20000]:
        if spots and np.min(np.linalg.norm(np.array(spots) - P[i], axis=1)) < 0.034:
            continue
        spots.append(P[i])
        if len(spots) > 260:
            break
    if spots:
        d, j = cKDTree(np.array(spots)).query(P[where])
        r = 0.0085 + 0.003 * rng.random(len(spots))[j]
        soft = np.clip((r - d) / 0.003, 0.0, 1.0)
        C[where] = C[where] * (1.0 - soft[:, None]) + np.array([0.97, 0.94, 0.86])[None, :] * soft[:, None]
    print("sika: %d texels of fur lightened, %d spots" % (fur.sum(), len(spots)))


def _black_face(P, N, C, rough):
    """Black-faced sheep: its face below the wool, its ears, its legs below
    the knee and its hands black - the wool and the jumper white."""
    mf = _meshy(P)
    f = CFG["face"]
    y, z = mf[:, 1], mf[:, 2]
    # (the face: up to the brow in front, the cheeks up to the wool's edge,
    # back to the ears; down to the chin - not the wool round the neck)
    face = (y < f["back"]) & (z < np.where(y < f["snout"], f["brow"], f["cap"])) \
        & (z > np.where(y < f["snout"] - 0.02, f["chin"], f["collar"]))
    ears = np.zeros(len(P), bool)
    for chain in CFG.get("ears", []):
        for k in (1.0, -1.0):
            pts = [np.array(_p(x * k, y, z)) for x, y, z in chain]
            for a, b in zip(pts, pts[1:]):
                ears |= _to_segment(P, a, b) < 0.05
    legs = np.zeros(len(P), bool)
    hands = np.zeros(len(P), bool)
    for s in ("l", "r"):
        kn = _bone(rough, "calf_" + s)[0]
        legs |= (P[:, 2] < kn[2]) & (np.sign(P[:, 0]) == np.sign(kn[0])) & (np.abs(P[:, 0]) < 0.4)
        w, t = _bone(rough, "hand_" + s)
        u = (t - w) / np.linalg.norm(t - w)
        hands |= ((P - w) @ u > 0.005) & (np.linalg.norm(P - w, axis=1) < 0.35)
    black = face | ears | legs | hands
    lum = _lum(C)
    k = np.clip(lum[black] / max(float(np.median(lum[black])), 1e-3), 0.55, 1.6)
    C[black] = np.array([0.075, 0.07, 0.07])[None, :] * k[:, None]
    print("black face: %d texels of face, %d ears, %d legs, %d hands" % (face.sum(), ears.sum(), legs.sum(),
                                                                         hands.sum()))


RECOLOUR = {"black_bear": _black_bear, "sika": _sika, "black_face": _black_face}


def recolour(body, rough):
    how = CFG.get("recolour")
    if how is None:
        return
    img, colour, pos, nrm, on = texels(body)
    flat = colour[:, :, :3][on].copy()
    RECOLOUR[how](pos[on], nrm[on], flat, rough)
    colour[:, :, :3][on] = flat
    img.pixels.foreach_set(colour.astype(np.float32).ravel())
    img.update()
    img.pack()


# User requests: the Meshy hands came big, then were shrunk too far - not
# meeting the arm, their palms badly made, long fingers fanned out like
# claws. All of them made the old characters' way instead
# (tools/greybox_animals.py's hands): a thick palm, short round fingers and a
# thumb, pads under them (claws on some) - each sized to its own wrist and
# grown out of it, the arm cut CUT short of the wrist and run on into it.
# The old dog's paw (the greybox's units) and the wrist it's on: a new one is
# it at its own wrist's size, as wide and as thick as that wrist is.
PAW = dict(wrist=0.029, palm=(0.056, 0.068, 0.036), fingers=(0.018, 0.015, 0.012), finger_r=0.0138,
           thumb=(0.016, 0.013), thumb_r=0.0125, curl=(8, 14, 18), spread=10, claw=(0.013, 0.0045))
CUT = 0.012
# (the paw's own wrist runs this far back in under the arm, a little inside
# it - SNUG of its girth - its edge where the arm's is brought onto it)
UNDER = 0.03
SNUG = 0.88
PAD = (0.16, 0.12, 0.11)
CLAW = (0.13, 0.11, 0.10)
# (how many faces a paw comes to)
PAW_FACES = 3200
# (a paw out of a sleeve to the wrist starts this far past its cuff, its
# wrist FILL of the cuff's girth - filling it, the arm run on into the paw
# as the old characters' are (user request: smaller than the sleeve, the
# paws didn't go with the arms); and none more than F_MAX times the old
# dog's - the old bear's and cat's 1.3 to 1.4, a big bear's sleeve more)
COVERED = 0.012
# (a sleeve ending less than HEM short of the wrist: the paw out of that)
HEM = 0.07
FILL = 0.9
F_MAX = 1.9
# (a bare arm's cut edge brought onto the paw just outside it - on it, the
# two surfaces fought, the seam ragged)
SEAM_OUT = 1.015


def _paw_shapes(f, wide, thick, n, claw):
    """The old characters' paw (greybox_animals.Animal.hand, a paw's) off a
    wrist at the origin, along +x, its back +z, its thumb toward -y - `f`
    times the old dog's, `wide` and `thick` times more across and through:
    its shapes, pads, claws and the digits' joints."""
    import sdf_mesh as S

    def V(*a):
        return np.array(a, dtype=float)

    def unit(v):
        return v / np.linalg.norm(v)
    H = PAW
    pl, pw, pt = H["palm"][0] * f, H["palm"][1] * f * wide, H["palm"][2] * f * thick
    fr = H["finger_r"] * f * min(wide, thick) ** 0.5
    W = V(0, 0, 0)
    shapes, pads, claws = [], [], []
    shapes.append(S.ellipsoid(W + V(pl * 0.50, 0.0, -pt * 0.04), (pl * 0.60, pw * 0.50, pt * 0.50)))
    shapes.append(S.ellipsoid(W + V(pl * 0.14, 0.0, -pt * 0.08), (pl * 0.32, pw * 0.42, pt * 0.46)))
    # (each part's bone: the skin goes with the part it's on)
    parts = [("hand", shapes[0]), ("hand", shapes[1])]
    joints = {}
    span = pw * 0.5 - fr * 1.02
    for i, nm in enumerate(["index", "middle", "ring", "pinky"][:n]):
        a = (i / (n - 1)) * 2.0 - 1.0
        d = S.rot((0, 0, 1), a * H["spread"]) @ V(1, 0, 0)
        reach = 1.0 - abs(a) * 0.18
        p = W + V(pl * 0.86, a * span, -pt * 0.04)
        pts = [p.copy()]
        for L, c in zip(H["fingers"], H["curl"]):
            d = S.rot(unit(np.cross(V(0, 0, 1), d)), c) @ d
            p = p + d * L * f * reach
            pts.append(p.copy())
        joints[nm] = pts
        rs = [fr * 1.05, fr * 1.0, fr * 0.97, fr * 0.95]
        segs = [S.round_cone(pts[j], pts[j + 1], rs[j], rs[j + 1]) for j in range(3)]
        parts += [("%s_%02d" % (nm, j + 1), seg) for j, seg in enumerate(segs)]
        shapes.append(S.smooth(segs, 0.004 * f))
        pads.append(S.sphere(pts[3] + d * fr * 0.15 + V(0, 0, -fr * 0.42), fr * 0.72))
        pads.append(S.sphere(pts[0] + V(fr * 0.2, 0, -pt * 0.36), fr * 0.82))
        if claw:
            L, r = H["claw"][0] * f, H["claw"][1] * f
            down = unit(S.rot(unit(np.cross(V(0, 0, 1), d)), 38) @ d)
            base = pts[3] - d * fr * 0.20 + V(0, 0, fr * 0.78)
            mid = base + d * L * 0.62 + V(0, 0, r * 0.3)
            claws.append(S.smooth([S.round_cone(base, mid, r, r * 0.72),
                                   S.round_cone(mid, mid + down * L * 0.55, r * 0.72, r * 0.15)], 0.002 * f))
    if n == 3:
        joints["pinky"] = [q + V(-0.006, 0.004, 0) * f for q in joints["ring"]]
    T = W + V(pl * 0.32, -pw * 0.40, -pt * 0.16)
    d = unit(V(0.55, -0.72, -0.42))
    pts = [T.copy()]
    p = T.copy()
    for L in (H["thumb"][0] * 0.6,) + tuple(H["thumb"]):
        p = p + d * L * f
        pts.append(p.copy())
        d = unit(d + V(0.20, 0.06, -0.04))
    joints["thumb"] = pts
    tr = H["thumb_r"] * f * min(wide, thick) ** 0.5
    trs = [tr * 1.12, tr * 1.06, tr * 1.0, tr * 0.95]
    segs = [S.round_cone(pts[j], pts[j + 1], trs[j], trs[j + 1]) for j in range(3)]
    parts += [("thumb_%02d" % (j + 1), seg) for j, seg in enumerate(segs)]
    shapes.append(S.smooth(segs, 0.005 * f))
    pads.append(S.sphere(pts[3] + V(0, 0, -tr * 0.45), tr * 0.7))
    if claw:
        L, r = H["claw"][0] * f, H["claw"][1] * f
        base = pts[3] - d * tr * 0.3 + V(0, 0, tr * 0.55)
        claws.append(S.round_cone(base, base + unit(d + V(0, 0, -0.55)) * L * 0.85, r, r * 0.15))
    pads.append(S.ellipsoid(W + V(pl * 0.52, 0.0, -pt * 0.40), (pl * 0.30, pw * 0.32, pt * 0.18)))
    return shapes, pads, claws, joints, parts


def _fewer(verts, faces, zone, target, longest=None):
    """A paw's mesh brought down to about `target` faces (its zones kept),
    with no doubled or degenerate bits left - bone heat fails on those; and
    `longest` (length, from x, to x): no edge across that stretch longer
    than that (bringing it down drew a round wrist out into slivers its
    whole length - its bend all across one face)."""
    me = bpy.data.meshes.new("Paw")
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.validate()
    me.polygons.foreach_set("material_index", zone.astype(int)[:len(me.polygons)])
    ob = bpy.data.objects.new("Paw", me)
    bpy.context.scene.collection.objects.link(ob)
    select([ob])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0002)
    bpy.ops.mesh.dissolve_degenerate(threshold=0.0002)
    bpy.ops.object.mode_set(mode='OBJECT')
    m = ob.modifiers.new("Less", 'DECIMATE')
    m.ratio = min(1.0, target / max(len(me.polygons), 1))
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier="Less")
    if longest is not None:
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(me)
        most, x0, x1 = longest
        for _ in range(8):
            long = [e for e in bm.edges if e.calc_length() > most
                    and min(e.verts[0].co.x, e.verts[1].co.x) < x1 and max(e.verts[0].co.x, e.verts[1].co.x) > x0]
            if not long:
                break
            bmesh.ops.subdivide_edges(bm, edges=long, cuts=1, use_grid_fill=False)
            bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(me)
        bm.free()
    v = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", v)
    f = np.array([list(p.vertices) for p in me.polygons], dtype=int)
    z = np.zeros(len(me.polygons), dtype=int)
    me.polygons.foreach_get("material_index", z)
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.meshes.remove(me)
    return v.reshape(-1, 3), f, z


# The paws' skin by their parts (paws(), as they're built; paw_skin() puts
# it on after bone heat - which gave a paw's palm to its short fingers: shut
# round the lamp the paw tore).
PAW_SKIN = []
# And where each wrist is (paws(): its side, middle, way along the hand,
# where the arm's cut, out of a sleeve or not, how far into the paw the
# wrist bends): the arm's end round it bends with the paw the same way
# (WRIST_BLEND back from the cut on a bare wrist; out of a sleeve the cuff
# stays with the forearm, the paw turning out of it - the paw's own wrist
# in under the cuff with it: a bigger paw's, bent, stuck out through it).
PAW_WRISTS = []
WRIST_BLEND = 0.03


def _wrist_share(x, w):
    """How much of the hand's turn a point `x` along the wrist `w` takes
    (0 the forearm's, 1 the hand's), eased."""
    lo = 0.0 if w["covered"] else -w["cut"] - WRIST_BLEND
    t = np.clip((np.asarray(x) - lo) / (w["end"] - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def paw_skin(body):
    """The paws' skin on their own bones, over what bone heat gave them -
    and the arm's end at each wrist bending as the paw's wrist does."""
    groups = {g.name: g for g in body.vertex_groups}
    idx = [i for i, _ in PAW_SKIN]
    for g in body.vertex_groups:
        g.remove(idx)
    for i, wts in PAW_SKIN:
        for name, w in wts.items():
            if name not in groups:
                groups[name] = body.vertex_groups.new(name=name)
            groups[name].add([i], w, 'REPLACE')
    print("paws: %d vertices on their own bones" % len(idx))
    co = coords(body)
    paw = np.zeros(len(co), bool)
    paw[idx] = True
    me = body.data
    for w in PAW_WRISTS:
        rel = co - w["W"]
        x = rel @ w["u"]
        r = np.linalg.norm(rel - np.outer(x, w["u"]), axis=1)
        x0 = -w["cut"] - 2.0 * WRIST_BLEND
        m = np.where(~paw & (np.sign(co[:, 0]) == np.sign(w["W"][0])) & (x > x0) & (x < 0.01) & (r < 0.15))[0]
        hand, fore = "hand_" + w["s"], "lowerarm_" + w["s"]
        for name in (hand, fore):
            if name not in groups:
                groups[name] = body.vertex_groups.new(name=name)
        h = _wrist_share(x[m], w)
        # (eased in from bone heat's over the first WRIST_BLEND)
        a = np.clip((x[m] - x0) / WRIST_BLEND, 0.0, 1.0)
        for k, i in enumerate(m.tolist()):
            had = {body.vertex_groups[g.group].name: g.weight for g in me.vertices[i].groups}
            total = sum(had.values()) or 1.0
            want = {n: v / total * (1.0 - a[k]) for n, v in had.items()}
            want[hand] = want.get(hand, 0.0) + h[k] * a[k]
            want[fore] = want.get(fore, 0.0) + (1.0 - h[k]) * a[k]
            for g in list(me.vertices[i].groups):
                body.vertex_groups[g.group].remove([i])
            for n, v in want.items():
                if v > 1e-4:
                    if n not in groups:
                        groups[n] = body.vertex_groups.new(name=n)
                    groups[n].add([i], v, 'REPLACE')
        mine = np.array([i for i, _ in PAW_SKIN if np.sign(co[i, 0]) == np.sign(w["W"][0])])
        print("wrist_%s: %d of the arm's end bending with the paw (its paw from %.3f along)"
              % (w["s"], len(m), float(np.percentile(x[mine], 1)) if len(mine) else 0.0))


def _centre_arms(body, rough):
    """The rough skeleton's elbows and wrists put on their arms' middle
    lines (their joints were read off the A pose by eye: dog2's wrist sat
    9 cm behind its arm) - the forearm, and the paw, turn about them."""
    co = coords(body)
    select([rough])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rough.data.edit_bones
    inv = rough.matrix_world.inverted()
    for s in ("l", "r"):
        lo, hand = eb["lowerarm_" + s], eb["hand_" + s]
        for joint, along in (("elbow", lo.tail - lo.head), ("wrist", hand.tail - hand.head)):
            at = rough.matrix_world @ (lo.head if joint == "elbow" else hand.head)
            u = np.array(rough.matrix_world.to_3x3() @ along)
            u /= np.linalg.norm(u)
            rel = co - np.array(at)
            x = rel @ u
            side_ = rel - np.outer(x, u)
            m = (np.sign(co[:, 0]) == np.sign(at.x)) & (np.abs(x) < 0.02) & (np.linalg.norm(side_, axis=1) < 0.2)
            if m.sum() < 8:
                continue
            mid = (np.percentile(side_[m], 95, axis=0) + np.percentile(side_[m], 5, axis=0)) / 2.0
            mid -= u * (mid @ u)
            new = inv @ Vector(tuple(np.array(at) + mid))
            if joint == "elbow":
                lo.head = new
                eb["upperarm_" + s].tail = new
            else:
                # (the hand moved whole - its way kept)
                hand.tail = hand.tail + (new - hand.head)
                lo.tail = new
                hand.head = new
            print("%s_%s: moved %.3f onto the arm's middle" % (joint, s, float(np.linalg.norm(mid))))
    bpy.ops.object.mode_set(mode='OBJECT')


def _move_wrist(rough, s, W):
    """The rough skeleton's wrist (s) at W (world): where the paw grows."""
    select([rough])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rough.data.edit_bones
    p = rough.matrix_world.inverted() @ Vector(tuple(W))
    eb["lowerarm_" + s].tail = p
    eb["hand_" + s].tail = eb["hand_" + s].tail + (p - eb["hand_" + s].head)
    eb["hand_" + s].head = p
    bpy.ops.object.mode_set(mode='OBJECT')


def paws(body, rough):
    """The hands (on the posed, T mesh) cut off CUT short of the wrist and
    the old characters' paws grown on in their place, each from the arm's
    own girth there - the arm's cut edge brought onto the paw's wrist, the
    paw coloured as the wrist is (its faces take the picture there, the
    same way round), its pads and claws their own colours. Its digits'
    joints for the skeleton, per side."""
    import bmesh
    import sdf_mesh as S
    cfg = CFG.get("paw", {})
    me = body.data
    _centre_arms(body, rough)
    co = coords(body)
    col = colours(body)
    luv = np.zeros(len(me.loops) * 2)
    me.uv_layers[0].data.foreach_get("uv", luv)
    luv = luv.reshape(-1, 2)
    fcen = np.array([co[list(p.vertices)].mean(0) for p in me.polygons])
    floops = [list(p.loop_indices) for p in me.polygons]
    built = {}
    for s in ("l", "r"):
        hb = rough.data.bones["hand_" + s]
        W = np.array(rough.matrix_world @ hb.head_local)
        u = np.array((rough.matrix_world @ hb.tail_local) - (rough.matrix_world @ hb.head_local))
        u /= np.linalg.norm(u)
        Y = np.array((0.0, 1.0, 0.0)) - u * u[1]
        Y /= np.linalg.norm(Y)
        Z = np.cross(u, Y)
        if Z[2] < 0.0:
            Z = -Z

        def local(p, W=W, u=u, Y=Y, Z=Z):
            q = p - W
            return q @ u, q @ Y, q @ Z
        side = np.sign(co[:, 0]) == np.sign(W[0])
        x, y, z = local(co)
        near = side & (np.hypot(y, z) < 0.2)
        # (the wrist past the sleeve, if it has one - the sleeve's colour up
        # the forearm, not the hand's: no more of it in the slices across
        # the arm than a few flecks - a sleeve to the wrist isn't cut into)
        hand_c = col[near & (x > 0.08) & (x < 0.14)].mean(0)
        sleeve_c = col[near & (x > -0.16) & (x < -0.10)].mean(0)
        xw, cut, covered = 0.0, CUT, False
        end = cfg.get("sleeve")
        if end is None and np.linalg.norm(sleeve_c - hand_c) > 0.3:
            end = -1.0
            for a in np.arange(-0.10, 0.07, 0.01):
                m = near & (x >= a) & (x < a + 0.01)
                if m.sum() >= 3 and (np.linalg.norm(col[m] - sleeve_c, axis=1) < 0.2).mean() > 0.15:
                    end = a + 0.01
        if end is not None:
            covered = end > -HEM
            if end > -0.03:
                # (a sleeve down to the wrist - its cuff wider than any wrist:
                # cut at its end, the paw coming out of it, its own wrist in
                # under the cuff)
                xw, cut = min(end, 0.06) + COVERED, COVERED
            elif covered:
                # (a sleeve a little short of it - the dogs': cut at its hem
                # all the same, the paw's forearm coming out of it, its
                # wrist where it was - the bare bit of arm between, the cut
                # across it, showed as a seam)
                cut = -end
            else:
                xw = min(max(0.0, end + CUT + 0.005), 0.05)
        W = W + u * xw
        x, y, z = local(co, W)
        band = side & (x > -cut - 0.035) & (x < -cut) & (np.hypot(y, z) < 0.2)
        # (the wrist's own middle, and its girth across the hand and up)
        cy = (np.percentile(y[band], 95) + np.percentile(y[band], 5)) / 2.0
        cz = (np.percentile(z[band], 95) + np.percentile(z[band], 5)) / 2.0
        W = W + Y * cy + Z * cz
        x, y, z = local(co, W)
        ry = float(np.percentile(np.abs(y[band]), 92))
        rz = float(np.percentile(np.abs(z[band]), 92))
        cap = F_MAX * PAW["wrist"]
        if covered:
            ry, rz = ry * FILL, rz * FILL
            asp = min(max(ry / rz, 0.8), 1.25)
            ry, rz = (ry * rz * asp) ** 0.5, (ry * rz / asp) ** 0.5
        r = (ry * rz) ** 0.5
        f = min(r, cap) / PAW["wrist"]
        shapes, pads, claws, joints, parts = _paw_shapes(f, ry / r * cfg.get("wide", 1.0), rz / r, cfg.get("fingers", 3),
                                                  cfg.get("claw", False))
        wrist = S.squash(S.round_cone((-cut - UNDER, 0, 0), (PAW["palm"][0] * f * 0.3, 0, 0), r, r),
                         (0, 0, 0), (1.0, ry / r * SNUG, rz / r * SNUG))
        hand = S.smooth([S.smooth(shapes, 0.010 * f), wrist], 0.012 * f)
        node = hand
        voxel = r / 13.0
        verts, faces = S.polygonise(node, voxel)
        verts, faces = S.drop_crumbs(verts, faces)
        # (what of it is in under the arm, past the arm's edge, off - before
        # it's brought down: after, its wrist's long faces reached past it)
        start = -cut - (UNDER if covered else 0.004)
        faces = faces[(verts[faces][:, :, 0] > start).all(1)]
        # (brought down first, the pads marked after - cut along their
        # outlines, not moved about by the bringing down)
        bend = PAW["palm"][0] * f * 0.3
        verts, faces, _ = _fewer(verts, faces, np.zeros(len(faces), int), PAW_FACES,
                                 longest=(bend / 2.0, -bend, 2.0 * bend))
        verts, faces, zone = S.split_labels(verts, faces, [(1, S.union(pads))], voxel)
        if claws:
            # (the claws on their own, finer - a paw's grid lost them - set
            # into the fingertips they stand out of)
            cv, cf = S.polygonise(S.union(claws), voxel / 3.0)
            cv, cf, cz = _fewer(cv, cf, np.full(len(cf), 2), 60 * len(claws))
            faces = np.concatenate([faces, cf + len(verts)])
            zone = np.concatenate([zone, cz])
            verts = np.concatenate([verts, cv])
        zone_v = np.zeros(len(verts), int)
        zone_v[faces[zone == 2].ravel()] = 2
        keep = (verts[faces][:, :, 0] > start - 1e-6).all(1)
        faces, zone = faces[keep], zone[keep]
        used = np.unique(faces)
        remap = -np.ones(len(verts), int)
        remap[used] = np.arange(len(used))
        verts, faces, zone_v = verts[used], remap[faces], zone_v[used]
        # (its picture: a bare wrist's just short of the cut - the paw the
        # arm's own fur, run on - and out of a sleeve, the hand's that was
        # (fur, not sleeve); the face there nearest the middling colour, the
        # paw spread over that bit of the picture: one fur, as the old paws
        # were one colour)
        fx, fy, fz = local(fcen, W)
        lo_x, hi_x = (-cut, -cut + 0.04) if covered else (-cut - 0.035, -cut - 0.004)
        bf = np.where((np.sign(fcen[:, 0]) == np.sign(W[0])) & (fx > lo_x) & (fx < hi_x)
                      & (np.hypot(fy, fz) < 0.2))[0]
        # (its back, as the arm shows it from above and outside)
        bf = bf[fz[bf] > 0.0] if (fz[bf] > 0.0).sum() >= 3 else bf
        fcol = np.array([col[list(me.polygons[k].vertices)].mean(0) for k in bf])
        src = bf[int(np.argmin(np.linalg.norm(fcol - np.median(fcol, axis=0), axis=1)))]
        # (each vertex's bones: the parts it's nearest, blended over a
        # finger's width at a joint; the wrist half the forearm's; a claw
        # its fingertip's)
        wrist = dict(s=s, W=W, u=u, cut=cut, covered=covered, end=bend)
        PAW_WRISTS.append(wrist)
        dist = np.stack([node_(verts) for _, node_ in parts], axis=1)
        names = [nm for nm, _ in parts]
        near = dist.min(1, keepdims=True)
        blend = 0.35 * PAW["finger_r"] * f
        w = np.clip(1.0 - (dist - near) / blend, 0.0, 1.0) ** 2
        weights = []
        for i in range(len(verts)):
            d = {}
            for j in np.nonzero(w[i] > 0.01)[0]:
                d[names[j]] = d.get(names[j], 0.0) + float(w[i, j])
            tip = max(d, key=d.get)
            if zone_v[i] == 2 and tip != "hand":
                d = {tip[:-2] + "03": 1.0}
            if "hand" in d:
                h = float(_wrist_share(verts[i, 0], wrist))
                if h < 1.0:
                    d["lowerarm"] = d.get("lowerarm", 0.0) + d["hand"] * (1.0 - h)
                    d["hand"] *= h
                    if d["hand"] <= 0.0:
                        del d["hand"]
            t = sum(d.values())
            weights.append({k + "_" + s: v / t for k, v in d.items()})
        built[s] = dict(W=W, u=u, Y=Y, Z=Z, node=node, faces=faces, zone=zone, src=luv[floops[src]], cut=cut,
                        weights=weights,
                        covered=covered,
                        local=verts, world=W + verts[:, :1] * u + verts[:, 1:2] * Y + verts[:, 2:3] * Z,
                        joints={k: [tuple(W + q[0] * u + q[1] * Y + q[2] * Z) for q in v] for k, v in joints.items()})
        _move_wrist(rough, s, W)
        print("paw_%s: wrist %.3f by %.3f (x%.2f the old dog's%s) %.3f on%s, %d faces (%d pad, %d claw)"
              % (s, ry, rz, f, ", held down" if r > cap else "", xw, ", out of its sleeve" if covered else "",
                 len(faces), (zone == 1).sum(), (zone == 2).sum()))
    # The arms cut, their edges brought onto the paws' wrists; the paws in.
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    for s, b in built.items():
        W, u, Y, Z, node = b["W"], b["u"], b["Y"], b["Z"], b["node"]

        def arm(v, W=W, u=u, Y=Y, Z=Z):
            q = np.array(v.co) - W
            return (np.sign(v.co.x) == np.sign(W[0]) and q @ u > -b["cut"] - 0.03
                    and math.hypot(q @ Y, q @ Z) < 0.25)
        # (cut across on a plane - a clean edge, not the coarse mesh's
        # jagged one - the hand past it gone)
        faces = [f for f in bm.faces if all(arm(v) for v in f.verts)]
        geom = list({e for f in faces for e in f.edges}) + faces + list({v for f in faces for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(tuple(W - u * b["cut"])), plane_no=Vector(tuple(u)),
                               clear_outer=True)
        # (and whatever of the hand was out of reach of that - a finger far
        # off the arm's line)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if np.sign(v.co.x) == np.sign(W[0])
                                   and (np.array(v.co) - W) @ u > -b["cut"] + 0.001
                                   and np.linalg.norm(np.array(v.co) - W) < 0.45], context='VERTS')
        bm.verts.ensure_lookup_table()
        moved = 0
        for v in bm.verts:
            # (a sleeve's cuff stays as it is, the paw out of it)
            if b["covered"] or not v.is_boundary or not arm(v):
                continue
            q = np.array(v.co) - W
            px, py, pz = q @ u, q @ Y, q @ Z
            rad = math.hypot(py, pz)
            if px < -CUT - 0.004 or rad < 1e-6:
                continue
            dy, dz = py / rad, pz / rad
            lo, hi = 0.0, rad * 2.0
            for _ in range(30):
                m = (lo + hi) / 2.0
                if node(np.array([[px, dy * m, dz * m]]))[0] < 0.0:
                    lo = m
                else:
                    hi = m
            v.co = Vector(tuple(W + px * u + (dy * Y + dz * Z) * lo * SEAM_OUT))
            moved += 1
        new = [bm.verts.new(tuple(q)) for q in b["world"]]
        b["new"] = new
        # (the paw's fur, its pads, its claws: their materials, put on below)
        base = len(me.materials)
        slot = {0: base + 2, 1: base, 2: base + 1}
        A, B, C = b["src"][0], b["src"][1], b["src"][-1]
        lv = b["local"]
        reach = max(float(lv[:, 0].max()) + b["cut"], 1e-3)
        for tri, zone in zip(b["faces"], b["zone"]):
            try:
                face = bm.faces.new([new[i] for i in tri])
            except ValueError:
                continue
            face.material_index = slot[int(zone)]
            face.smooth = True
            for loop, i in zip(face.loops, tri):
                a = 0.5 + 0.5 * math.cos(math.atan2(lv[i, 2], lv[i, 1]))
                t = min(max((lv[i, 0] + b["cut"]) / reach, 0.0), 1.0)
                loop[uvl].uv = tuple(A + (B - A) * (0.2 + 0.5 * a) + (C - A) * (0.25 * t))
        print("paw_%s: the arm's edge brought onto it at %d points" % (s, moved))
    bm.verts.index_update()
    for b in built.values():
        b["index"] = [v.index if v.is_valid else -1 for v in b["new"]]
        del b["new"]
    bm.to_mesh(me)
    bm.free()
    me.update()
    global PAW_SKIN
    PAW_SKIN = [(i, wts) for b in built.values() for i, wts in zip(b["index"], b["weights"]) if i >= 0]
    # (its pads and claws: their own colours)
    # (named as the game keeps a character's own colours - CharacterRig._dress)
    for name, colour in (("pad", cfg.get("pad", PAD)), ("claw", cfg.get("claw_colour", CLAW))):
        m = bpy.data.materials.new("col_" + name)
        m.use_nodes = True
        bsdf = next(nd for nd in m.node_tree.nodes if nd.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = (*[c ** 2.2 for c in colour], 1.0)
        bsdf.inputs['Roughness'].default_value = 0.75 if name == "pad" else 0.45
        me.materials.append(m)
    # (its fur: the body's picture without its bumps - spread over the paw
    # from one bit of the arm, that bit's bumps tilted the whole paw dark)
    fur = me.materials[0].copy()
    fur.name = ID + "_Paw"
    nt = fur.node_tree
    bsdf = next(nd for nd in nt.nodes if nd.type == 'BSDF_PRINCIPLED')
    for link in list(nt.links):
        if link.to_socket == bsdf.inputs['Normal']:
            nt.links.remove(link)
    me.materials.append(fur)
    return {s: b["joints"] for s, b in built.items()}


# ---------------------------------------------------------------- pass 2

def game_skeleton():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SKELETON)
    new = set(bpy.data.objects) - before
    arm = next(o for o in new if o.type == 'ARMATURE')
    for o in new:
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in bpy.data.actions:
        if a.name.endswith("_Armature"):
            a.name = a.name[:-len("_Armature")]
        # (the ears and the tail are this one's own, and the clips don't
        # move them - EarTailSway does)
        for fc in list(a.fcurves):
            if '["ear_' in fc.data_path or '["tail_' in fc.data_path:
                a.fcurves.remove(fc)
    for tr in arm.animation_data.nla_tracks:
        if tr.name.endswith("_Armature"):
            tr.name = tr.name[:-len("_Armature")]
        for st in tr.strips:
            if st.name.endswith("_Armature"):
                st.name = st.name[:-len("_Armature")]
    arm.name = "Armature"
    arm.data.name = "Armature"
    return arm


def refit(game, rough, digits):
    inv = game.matrix_world.inverted()
    joints = {}
    for b in rough.data.bones:
        joints[b.name] = (inv @ (rough.matrix_world @ b.head_local), inv @ (rough.matrix_world @ b.tail_local))
    fing = {}
    for s in ("l", "r"):
        for digit, pts in digits[s].items():
            ps = [inv @ Vector(p) for p in pts]
            for i in range(3):
                fing["%s_%02d_%s" % (digit, i + 1, s)] = (ps[i], ps[i + 1])
            fing["%s_04_leaf_%s" % (digit, s)] = (ps[3], ps[3] + (ps[3] - ps[2]) * 0.5)
    select([game])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = game.data.edit_bones
    for b in list(eb):
        if b.name.startswith(("ear_", "tail_")):
            eb.remove(b)
    for b in eb:
        part = b.name.rsplit("_", 1)[0] if b.name[-2:] in ("_l", "_r") else b.name
        if part in FROM_PASS1 and b.name in joints:
            h, t = joints[b.name]
            if part == "hand":
                t = fing["middle_01" + b.name[-2:]][0]
        elif b.name in fing:
            h, t = fing[b.name]
        elif b.name.startswith("ball_leaf"):
            h = joints["ball" + b.name[-2:]][1]
            t = h + (b.tail - b.head)
        else:
            continue
        roll = b.roll
        way = (b.tail - b.head).normalized()
        b.head = h
        b.tail = h + way * max((t - h).length, 0.01)
        b.roll = roll
    for name, (h, t) in joints.items():
        if name.startswith(("ear_", "tail_")):
            b = eb.new(name)
            b.head, b.tail = h, t
            b.parent = eb[rough.data.bones[name].parent.name]
    for b in eb:
        b.use_deform = not (b.name == "root" or "leaf" in b.name)
    bpy.ops.object.mode_set(mode='OBJECT')
    print("skeleton: %d bones" % len(game.data.bones))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    game = game_skeleton()
    body = mesh()
    if MIXAMO:
        load_mixamo()
        slim(body)
    rough = rough_skeleton(body)
    if MIX:
        mix_skin(body, rough)
    else:
        _centre_legs(body, rough)
        heat(body, rough)
        own_legs(body, rough)
    tail_only(body, rough)
    pose_rest(body, rough, game)
    part_legs(body, rough)
    recolour(body, rough)
    digits = paws(body, rough)
    refit(game, rough, digits)
    bpy.data.objects.remove(rough, do_unlink=True)
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    body.parent = None
    if MIXAMO_FINAL:
        # (pass 1 was bone heat's; pass 2 the finished body's own Mixamo rig)
        load_mixamo(MIXAMO_FINAL, final=True)
        mix_refit(game)
        # (the tail, the ears, the head and the hands kept as pass 1 had them: Mixamo
        # gave the tail to the hips and legs - bits of it flew off with a
        # stride - and the paws are the old characters')
        kept = {}
        names = {g.index: g.name for g in body.vertex_groups}
        for v in body.data.vertices:
            had = {names[g.group]: g.weight for g in v.groups if g.weight > 1e-4}
            if sum(w for n, w in had.items() if n.startswith(("tail_", "ear_", "hand_"))) > 0.01 or \
                    had.get("Head", 0.0) > 0.5:
                kept[v.index] = had
        mix_skin(body, game)
        groups = {g.name: g for g in body.vertex_groups}
        for i, had in kept.items():
            for g in body.vertex_groups:
                g.remove([i])
            for n, w in had.items():
                if n not in groups:
                    groups[n] = body.vertex_groups.new(name=n)
                groups[n].add([i], w, 'REPLACE')
        print("mixamo: %d points kept as pass 1 had them (tail, ears, head, hands)" % len(kept))
    elif MIX or CFG.get("pass1_skin"):
        # (the skin pass 1 had - the same bones' names - kept; but the hand's
        # the forearm's: the hands are cut off and the old characters' paws
        # grown on, the arm's end bending with its paw as paw_skin() has it
        # - Mixamo's hand reached up into the cuff)
        for s in ("l", "r"):
            h, lo = body.vertex_groups.get("hand_" + s), body.vertex_groups.get("lowerarm_" + s)
            if h is None or lo is None:
                continue
            for v in body.data.vertices:
                w = next((g.weight for g in v.groups if g.group == h.index), 0.0)
                if w > 0.0:
                    had = next((g.weight for g in v.groups if g.group == lo.index), 0.0)
                    lo.add([v.index], had + w, 'REPLACE')
                    h.remove([v.index])
        select([body, game], active=game)
        bpy.ops.object.parent_set(type='ARMATURE_NAME')
    else:
        heat(body, game)
    tidy_skin(body, game)
    own_legs(body, game)
    tail_only(body, game)
    paw_skin(body)
    select([body])
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    game.animation_data.action = None
    for pb in game.pose.bones:
        pb.matrix_basis.identity()
    body.name = ID
    select([game, body], active=game)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_optimize_animation_size=True, export_anim_single_armature=True,
                              export_def_bones=False, export_image_format='JPEG', export_jpeg_quality=85)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
