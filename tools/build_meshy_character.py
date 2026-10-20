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
     lays the tail at rest (`angles`); the mesh is kept so;
  2. the game's skeleton is moved onto it - each bone to its joint here,
     keeping its turn (so every clip plays as it does) - the fingers at
     the knuckles found on the posed hands, the ears and the tail from
     pass 1 (EarTailSway moves them) - and the mesh bound to it.

  bpyenv/bin/python tools/build_meshy_character.py -- ID MESHY SKELETON OUT.glb [LOW.blend]

LOW.blend (optional) keeps the brought-down, baked mesh between runs.
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
DIGITS = ("index", "middle", "ring", "pinky")


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


def rough_skeleton(body):
    j = CFG["joints"]

    def mid(name):
        y, z = j[name]
        return _p(0.0, y, z)

    def side(name, k):
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


# User requests: the Meshy hands came big - into the lamp they held (a
# person's reaches about 0.11 of the height past the wrist; these 0.13 to
# 0.17) - and their long fingers splayed like claws; the old characters'
# small round paws read well. A hand reaching further than HAND_MAX of the
# height is brought down to it (about the wrist, no smaller than HAND_FLOOR
# of itself) - the old ones' size.
HAND_MAX = 0.06
HAND_FLOOR = 0.3
# (the spread between the fingers kept, past the knuckles)
FINGERS_TOGETHER = 0.7


def shrink_hands(body, rough):
    """The hands (on the posed, T mesh) brought down to HAND_MAX of the
    height: each point past the wrist drawn in toward it, eased in over the
    cuff so the sleeve's not cut."""
    me = body.data
    co = coords(body)
    height = co[:, 2].max() - co[:, 2].min()
    for s in ("l", "r"):
        hb = rough.data.bones["hand_" + s]
        wrist = np.array(rough.matrix_world @ hb.head_local)
        u = np.array((rough.matrix_world @ hb.tail_local) - (rough.matrix_world @ hb.head_local))
        u /= np.linalg.norm(u)
        rel = co - wrist
        t = rel @ u
        side = np.linalg.norm(rel - np.outer(t, u), axis=1)
        # (all of it past the wrist - a spread finger's tip left out was
        # stretched out to where it was, a web)
        hand = (t > -0.01) & (side < 0.3) & (np.sign(co[:, 0]) == np.sign(wrist[0]))
        reach = t[hand].max()
        k = max(HAND_FLOOR, min(1.0, HAND_MAX * height / reach))
        print("hand_%s: %.3f past the wrist (%.3f of the height) -> x%.2f" % (s, reach, reach / height, k))
        if k >= 0.999:
            continue
        f = np.clip((t + 0.01) / 0.04, 0.0, 1.0)
        f = f * f * (3 - 2 * f)
        scale = 1.0 - (1.0 - k) * f
        co[hand] = wrist + rel[hand] * scale[hand, None]
        # (and the fingers drawn together across the hand, past the
        # knuckles - a paw, not a fan)
        v = np.array((0.0, -1.0, 0.0))
        v = v - u * v.dot(u)
        v /= np.linalg.norm(v)
        rel = co - wrist
        t = rel @ u
        a = rel @ v
        kt = 0.5 * reach * k
        mid = np.median(a[hand & (np.abs(t - kt) < 0.01)]) if (hand & (np.abs(t - kt) < 0.01)).any() else 0.0
        g = np.clip((t - kt + 0.01) / 0.03, 0.0, 1.0)
        g = g * g * (3 - 2 * g)
        pull = (1.0 - FINGERS_TOGETHER) * g * (a - mid)
        co[hand] -= np.outer(pull[hand], v)
    me.vertices.foreach_set("co", (co @ np.linalg.inv(np.array(body.matrix_world)[:3, :3]).T
                                   - np.array(body.matrix_world)[:3, 3] @ np.linalg.inv(np.array(body.matrix_world)[:3, :3]).T).ravel())
    me.update()


def fingers(body, rough):
    """The left hand's digits on the posed (T) mesh: each one's four joints,
    knuckle first. The hand along its bone; the fingers are the four bands
    across it past the knuckles (front to back: index to pinky), the thumb
    the front of the palm."""
    hb = rough.data.bones["hand_l"]
    wrist = rough.matrix_world @ hb.head_local
    u = ((rough.matrix_world @ hb.tail_local) - wrist).normalized()
    v = Vector((0.0, -1.0, 0.0))
    v = (v - u * v.dot(u)).normalized()       # the hand's front
    w = u.cross(v)
    co = coords(body)
    rel = co - np.array(wrist)
    t = rel @ np.array(u)
    a = rel @ np.array(v)
    b = rel @ np.array(w)
    reach = (rough.matrix_world @ hb.tail_local - wrist).length
    m = (t > -0.005) & (t < reach * 1.5) & (np.hypot(a, b) < reach * 0.9) & (co[:, 0] > wrist.x - 0.01)
    t, a, b, pts = t[m], a[m], b[m], co[m]
    tip_t = t.max()
    kt = 0.52 * tip_t
    sl = np.abs(t - (kt + 0.35 * (tip_t - kt))) < 0.008
    vals = np.sort(-a[sl])        # back to front -> front first after the sign
    bands = []
    if len(vals) > 8:
        gaps = np.diff(vals)
        cut = np.sort(np.argsort(gaps)[-3:])
        if gaps[cut].min() > 0.004:
            edges_ = [vals[0] - 1e-3] + [(vals[c] + vals[c + 1]) / 2 for c in cut] + [vals[-1] + 1e-3]
            bands = [(edges_[i], edges_[i + 1]) for i in range(4)]
    if not bands:
        fa = -a[t > kt]
        lo, hi = np.percentile(fa, 3), np.percentile(fa, 97)
        bands = [(lo + (hi - lo) * i / 4, lo + (hi - lo) * (i + 1) / 4) for i in range(4)]
    out = {}
    for name, (lo, hi) in zip(DIGITS, bands):
        inb = (-a >= lo) & (-a <= hi) & (t > kt - 0.01)
        if inb.sum() < 4:
            inb = (-a >= lo) & (-a <= hi)
        tt = t[inb]
        k = int(np.argmax(tt))
        tip = Vector(pts[inb][k])
        near = np.abs(tt - kt) < 0.012
        knuckle = Vector(pts[inb][near].mean(0)) if near.sum() else wrist + u * kt
        out[name] = [knuckle.lerp(tip, f) for f in (0.0, 0.36, 0.7, 1.0)]
    # the thumb: from the palm's front edge near the wrist out to its tip
    front = -a < np.percentile(-a, 20)
    palm = front & (t < kt)
    if palm.sum() >= 4:
        base = Vector(pts[palm & (t < 0.45 * kt)].mean(0)) if (palm & (t < 0.45 * kt)).sum() else wrist + u * 0.2 * kt
        far = np.linalg.norm(pts[palm] - np.array(base), axis=1)
        tip = Vector(pts[palm][int(np.argmax(far))])
    else:
        base, tip = wrist + u * 0.2 * kt - v * 0.02, wrist + u * 0.6 * kt - v * 0.05
    out["thumb"] = [base.lerp(tip, f) for f in (0.0, 0.36, 0.7, 1.0)]
    for name, pts_ in out.items():
        print("finger %s: knuckle %s tip %s" % (name, tuple(round(c, 3) for c in pts_[0]),
                                                tuple(round(c, 3) for c in pts_[-1])))
    return {k: [tuple(p) for p in vals_] for k, vals_ in out.items()}


def mitten(body):
    """The four fingers bending as one, a mitten (the thumb its own): each
    one's skin on the middle finger's bones - the clips spread them apart,
    long claws fanned out."""
    groups = {g.name: g for g in body.vertex_groups}
    index = {g.index: g.name for g in body.vertex_groups}
    moved = 0
    for v in body.data.vertices:
        add = {}
        for g in list(v.groups):
            name = index[g.group]
            if name.startswith(("index_", "ring_", "pinky_")):
                to = "middle_" + name.split("_", 1)[1]
                add[to] = add.get(to, 0.0) + g.weight
                groups[name].remove([v.index])
        for to, w in add.items():
            if to not in groups:
                groups[to] = body.vertex_groups.new(name=to)
            have = next((g.weight for g in v.groups if index.get(g.group) == to), 0.0)
            groups[to].add([v.index], have + w, 'REPLACE')
        moved += bool(add)
    print("mitten: %d vertices on the middle finger's bones" % moved)


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
    for digit, pts in digits.items():
        for s, k in (("l", 1.0), ("r", -1.0)):
            ps = [inv @ Vector((p[0] * k, p[1], p[2])) for p in pts]
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
    rough = rough_skeleton(body)
    heat(body, rough)
    tail_only(body, rough)
    pose_rest(body, rough, game)
    shrink_hands(body, rough)
    digits = fingers(body, rough)
    refit(game, rough, digits)
    bpy.data.objects.remove(rough, do_unlink=True)
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    body.parent = None
    heat(body, game)
    tail_only(body, game)
    mitten(body)
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
