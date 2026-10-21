"""The old characters' pictures (user request: the old characters - the
greybox animal people: the snowy owl, the chihuahua, the brown bear, the
red deer and the sheep - kept for how well they move, their textures
brought up to the new (Meshy) ones': fur drawn hair by hair, feathers
feather by feather, eyes with an iris, a pupil and a catchlight, a nose of
pebbled leather, and the new outfit's white knit and khaki cotton).

Takes a character as tools/build_menu_character.py builds it (one mesh, a
flat colour per zone - greybox_colour) and gives the whole of it one
picture, a normal map and a roughness map:

  - laid out over one square (each zone together; the head given more of
    it, as a face needs);
  - each texel's place on the body at rest, its way out and how open it
    is (ambient occlusion) baked off the mesh;
  - then painted point by point from where it is: the coat's colours and
    markings for that animal (LOOKS), its hair as strands running the way
    the coat lies (down the body, out along the limbs, back from the nose,
    up the ears, along the tail) - a fine noise smeared along that way,
    in fine strands and in coarser locks - its feathers (the owl) or its
    curled wool (the sheep); the knit as rows of V stitches with ribbed
    cuffs, hem and neck band; the shorts a twill; the button wood;
  - its shape's shading (the occlusion) laid in, and a height for each
    texel turned into the normal map.

Its shape, skeleton and clips are as they were.

    bpyenv/bin/python tools/paint_pelt.py -- ANIMAL IN.glb OUT.glb
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
ANIMAL, SRC, OUT = args[:3]
SIZE = int(os.environ.get("PELT_SIZE", "2048"))
# the normal and roughness maps' size, the occlusion bake's
SIZE_N = SIZE // 2
SIZE_AO = SIZE // 2
# how much more of the picture the head gets, for the same area
HEAD_DENSITY = 1.8
ZONE_NAMES = ["fur", "skin", "horn", "eye", "knit", "cloth", "button", "scarf", "pad", "muzzle", "rib"]
DEBUG = os.environ.get("PELT_DEBUG")


# ---------------------------------------------------------------- colour

def srgb(*c):
    return np.array(c, dtype=float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = np.asarray(t, dtype=float)
    if t.ndim == 1:
        t = t[:, None]
    return a * (1.0 - t) + b * t


def unit(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-12)


# ---------------------------------------------------------------- noise

def _hash(ix, iy, iz, seed):
    v = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    v = (v ^ (v >> 13)) * 1274126177
    v = v ^ (v >> 16)
    return (v & 0xFFFF).astype(np.float64) / 65535.0


def vnoise(X, seed=0):
    """Value noise at X (n, 3; in cells), 0..1."""
    i = np.floor(X).astype(np.int64)
    f = X - i
    u = f * f * (3.0 - 2.0 * f)
    out = np.zeros(len(X))
    for dx in (0, 1):
        wx = u[:, 0] if dx else 1.0 - u[:, 0]
        for dy in (0, 1):
            wy = u[:, 1] if dy else 1.0 - u[:, 1]
            for dz in (0, 1):
                wz = u[:, 2] if dz else 1.0 - u[:, 2]
                out += wx * wy * wz * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(X, octaves=3, seed=0):
    out, amp, tot = np.zeros(len(X)), 1.0, 0.0
    for o in range(octaves):
        out += amp * vnoise(X * (2.0 ** o), seed + o * 17)
        tot += amp
        amp *= 0.5
    return out / tot


def worley(X, seed=0):
    """Distance to the nearest of one random point per cell (X in cells),
    the second nearest, and the nearest point's id (a random 0..1)."""
    i = np.floor(X).astype(np.int64)
    d1 = np.full(len(X), 9.0)
    d2 = np.full(len(X), 9.0)
    idv = np.zeros(len(X))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = i + np.array([dx, dy, dz])
                p = c + np.stack([_hash(c[:, 0], c[:, 1], c[:, 2], seed + k) for k in (1, 2, 3)], axis=1)
                d = np.linalg.norm(X - p, axis=1)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                idv = np.where(closer, _hash(c[:, 0], c[:, 1], c[:, 2], seed + 9), idv)
                d1 = np.where(closer, d, d1)
    return d1, d2, idv


def strands(q, d, cell, length, seed, samples=12):
    """Hair: a fine noise smeared along d (line integral convolution) -
    streaks `cell` across and about `length` long - normalised to 0..1."""
    acc = np.zeros(len(q))
    tot = 0.0
    for k in range(samples):
        t = (k + 0.5) / samples - 0.5
        w = 0.5 + 0.5 * math.cos(2.0 * math.pi * t)
        acc += w * vnoise((q + d * (t * length)) / cell, seed)
        tot += w
    acc /= tot
    m, s = acc.mean(), acc.std() + 1e-9
    return 1.0 / (1.0 + np.exp(-(acc - m) / s * 1.6))


# ---------------------------------------------------------------- scene

def select(objs, active=None):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active or objs[0]


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=SRC)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.materials)
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    # (the importer's names back as the game knows them)
    for a in bpy.data.actions:
        if a.name.endswith("_Armature"):
            a.name = a.name[:-len("_Armature")]
    for tr in arm.animation_data.nla_tracks:
        if tr.name.endswith("_Armature"):
            tr.name = tr.name[:-len("_Armature")]
        for st in tr.strips:
            if st.name.endswith("_Armature"):
                st.name = st.name[:-len("_Armature")]
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    return arm, body


def zone_of_faces(body):
    """Each face's zone (ZONE_NAMES' index) from its material's name."""
    names = []
    for m in body.data.materials:
        n = m.name.split(".")[0]
        names.append(ZONE_NAMES.index(n[4:]) if n.startswith("col_") and n[4:] in ZONE_NAMES else 0)
    mi = np.zeros(len(body.data.polygons), np.int64)
    body.data.polygons.foreach_get("material_index", mi)
    return np.array(names)[mi]


def world_co(body):
    me = body.data
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    M = np.array(body.matrix_world)
    return co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]


class Marks:
    """Where things are on the character at rest (world): its joints, eyes
    and nose, and which way it faces."""

    def __init__(self, arm, body, fz):
        mw = arm.matrix_world
        self.b = {b.name: np.array(mw @ b.head_local) for b in arm.data.bones}
        self.t = {b.name: np.array(mw @ b.tail_local) for b in arm.data.bones}
        co = world_co(body)
        me = body.data
        fv = [list(p.vertices) for p in me.polygons]

        def verts(zone, near=None):
            idx = sorted({v for f, z in zip(fv, fz) if z == zone for v in f})
            pts = co[idx] if idx else np.zeros((0, 3))
            return pts
        H = self.b["Head"]
        self.head = H
        eyes = verts(3)
        self.eyes = []
        for s in (1, -1):
            e = eyes[eyes[:, 0] * s > 0]
            self.eyes.append(e.mean(axis=0) if len(e) else H + np.array([s * 0.04, -0.1, 0.05]))
        self.eye_pts = eyes
        mid = (self.eyes[0] + self.eyes[1]) * 0.5
        # the face's way: from the head bone through between the eyes,
        # level
        f = mid - H
        f[2] = 0.0
        self.fwd = unit(f)
        nose = verts(1)
        head_pts = co[np.linalg.norm(co - H, axis=1) < 0.35]
        if len(nose):
            self.nose = nose[np.argmax(nose @ self.fwd)]
        else:
            self.nose = head_pts[np.argmax(head_pts @ self.fwd)]
        self.eye_mid = mid
        self.eye_gap = float(np.linalg.norm(self.eyes[0] - self.eyes[1]))
        self.top = float(co[np.abs(co[:, 0]) < 0.1][:, 2].max())
        self.co = co

    def __getitem__(self, k):
        return self.b[k]


# ---------------------------------------------------------------- layout

def hidden_faces(body, fz, cen, nrm):
    """The body's faces the clothes cover (a ray out from each meets the
    knit or the cotton within a few centimetres): they need little of the
    picture."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    co = world_co(body)
    me = body.data
    cloth = {ZONE_NAMES.index(z) for z in ("knit", "rib", "cloth", "scarf")}
    polys = [list(p.vertices) for p, z in zip(me.polygons, fz) if z in cloth]
    tree = BVHTree.FromPolygons([Vector(c) for c in co], polys)
    out = np.zeros(len(fz), bool)
    for i, z in enumerate(fz):
        if z in cloth:
            continue
        hit = tree.ray_cast(Vector(cen[i] + nrm[i] * 0.0005), Vector(nrm[i]), 0.06)
        out[i] = hit[0] is not None
    return out


def unwrap(body, marks, fz):
    """One picture over all of it: the head's faces unwrapped on their own
    and given HEAD_DENSITY times the room, the body under the clothes a
    fifth of it."""
    me = body.data
    co = marks.co
    cen = np.array([co[list(p.vertices)].mean(axis=0) for p in me.polygons])
    nrm = np.zeros(len(me.polygons) * 3)
    me.polygons.foreach_get("normal", nrm)
    nrm = nrm.reshape(-1, 3) @ np.array(body.matrix_world)[:3, :3].T
    nrm = unit(nrm)
    H = marks.head
    neck = marks["neck_01"]
    head = (cen[:, 2] > neck[2] + 0.35 * (H[2] - neck[2])) & (np.abs(cen[:, 0]) < 0.30)
    hidden = hidden_faces(body, fz, cen, nrm) & ~head
    print("faces: %d head, %d under the clothes" % (head.sum(), hidden.sum()))
    select([body])
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(me)
    bm.faces.ensure_lookup_table()
    for part in (head, hidden, ~head & ~hidden):
        for f in bm.faces:
            f.select_set(bool(part[f.index]))
        bmesh.update_edit_mesh(me)
        bpy.ops.uv.smart_project(angle_limit=math.radians(64), island_margin=0.003, scale_to_bounds=False)
    for f in bm.faces:
        f.select_set(True)
    bmesh.update_edit_mesh(me)
    bpy.ops.uv.average_islands_scale()
    bm = bmesh.from_edit_mesh(me)
    bm.faces.ensure_lookup_table()
    uv = bm.loops.layers.uv.active
    for f in bm.faces:
        k = HEAD_DENSITY if head[f.index] else (0.2 if hidden[f.index] else 1.0)
        if k != 1.0:
            for lp in f.loops:
                lp[uv].uv = lp[uv].uv * k
    bmesh.update_edit_mesh(me)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.0025)
    bpy.ops.object.mode_set(mode='OBJECT')


def bake_maps(body, fz):
    """Each texel's place (world, at rest), its way out, its zone and its
    occlusion - baked off a copy of the mesh."""
    dup = body.copy()
    dup.data = body.data.copy()
    bpy.context.scene.collection.objects.link(dup)
    dup.parent = None
    dup.matrix_world = body.matrix_world
    for m in list(dup.modifiers):
        dup.modifiers.remove(m)
    # (the original out of the bake: its surface on the copy's darkened the
    # occlusion)
    body.hide_render = True
    me = dup.data
    # the zone on each face corner, for the bake to read
    attr = me.color_attributes.new("zone", 'FLOAT_COLOR', 'CORNER')
    vals = np.zeros((len(me.loops), 4))
    for p in me.polygons:
        vals[p.loop_start:p.loop_start + p.loop_total, 0] = (fz[p.index] + 0.5) / 16.0
    vals[:, 3] = 1.0
    attr.data.foreach_set("color", vals.ravel())
    mat = bpy.data.materials.new("Bake")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emit = nt.nodes.new('ShaderNodeEmission')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    at = nt.nodes.new('ShaderNodeAttribute')
    at.attribute_name = "zone"
    img_node = nt.nodes.new('ShaderNodeTexImage')
    nt.links.new(emit.outputs[0], out.inputs['Surface'])
    me.materials.clear()
    me.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.margin = 8
    maps = {}
    for what, size, src in (("Position", SIZE, geo.outputs["Position"]), ("Normal", SIZE, geo.outputs["Normal"]),
                            ("Zone", SIZE, at.outputs["Color"]), ("AO", SIZE_AO, None)):
        buf = bpy.data.images.new("Bake" + what, size, size, alpha=True, float_buffer=True)
        buf.generated_color = (0.0, 0.0, 0.0, 0.0)
        img_node.image = buf
        nt.nodes.active = img_node
        select([dup])
        if src is not None:
            nt.links.new(src, emit.inputs['Color'])
            sc.render.bake.margin_type = 'EXTEND' if what != "Zone" else 'ADJACENT_FACES'
            bpy.ops.object.bake(type='EMIT')
        else:
            sc.cycles.samples = 48
            sc.world = sc.world or bpy.data.worlds.new("w")
            sc.world.light_settings.distance = 0.12
            bpy.ops.object.bake(type='AO')
        maps[what] = np.array(buf.pixels[:], dtype=np.float32).reshape(size, size, 4)
        bpy.data.images.remove(buf)
    bpy.data.objects.remove(dup, do_unlink=True)
    bpy.data.materials.remove(mat)
    body.hide_render = False
    N = maps["Normal"][:, :, :3].astype(np.float64)
    on = np.linalg.norm(N, axis=2) > 0.5
    zone = np.clip(np.floor(maps["Zone"][:, :, 0] * 16.0), 0, len(ZONE_NAMES) - 1).astype(np.int64)
    ao = maps["AO"][:, :, 0]
    ao = np.kron(ao, np.ones((SIZE // SIZE_AO, SIZE // SIZE_AO), np.float32))
    return maps["Position"][:, :, :3].astype(np.float64), unit(N), zone, ao.astype(np.float64), on


# ---------------------------------------------------------------- fur

def coat_way(q, n, mk, look):
    """Which way the coat lies at each point (its hairs' tips' way): down
    the body and legs, out along the arms to the hands, back from the
    nose over the head and face, up the ears, out along the tail; along
    the surface."""
    d = np.zeros_like(q)
    d[:, 2] = -1.0
    sx = abs(mk["upperarm_l"][0])
    arm = smooth(sx * 0.85, sx * 1.15, np.abs(q[:, 0])) * smooth(mk["pelvis"][2], mk["clavicle_l"][2] - 0.05, q[:, 2])
    out = np.stack([np.sign(q[:, 0]), np.zeros(len(q)), np.full(len(q), -0.15)], axis=1)
    d = mix(d, out, arm)
    # the head: back from the nose (and a little down)
    H, nose = mk.head, mk.nose
    neck = mk["neck_01"]
    on_head = smooth(neck[2] + 0.2 * (H[2] - neck[2]), H[2], q[:, 2]) * (1.0 - arm)
    back = unit(q - nose + np.array([0, 0, 0.35]) * np.linalg.norm(q - nose, axis=1)[:, None] * 0.0)
    back = unit(back + np.array([0.0, 0.0, -0.25]))
    d = mix(d, back, on_head)
    # the ears: root to tip
    for s in ("l", "r"):
        for ch in ("1", "2"):
            a, b = "ear_%s%s_01" % (s, ch), "ear_%s%s_02" % (s, ch)
            if a in mk.b:
                r0 = mk[a]
                tip = mk.t[b] if b in mk.t else mk.t[a]
                ax = unit(tip - r0)
                L = np.linalg.norm(tip - r0)
                t = (q - r0) @ ax
                near = np.linalg.norm(q - r0 - t[:, None] * ax, axis=1)
                w = smooth(-0.01, 0.01, t) * smooth(L * 1.1, L * 0.9, t) * smooth(0.06, 0.03, near)
                d = mix(d, np.tile(ax, (len(q), 1)), w)
    # the tail: root to tip
    tails = sorted(k for k in mk.b if k.startswith("tail_"))
    for k in tails:
        a, b = mk[k], mk.t[k]
        ax = unit(b - a)
        L = np.linalg.norm(b - a)
        t = (q - a) @ ax
        near = np.linalg.norm(q - a - t[:, None] * ax, axis=1)
        w = smooth(-0.02, 0.0, t) * smooth(L + 0.02, L, t) * smooth(0.06, 0.035, near)
        d = mix(d, np.tile(ax, (len(q), 1)), w)
    d = d - n * np.sum(d * n, axis=1, keepdims=True)
    return unit(d)


def hair(q, n, mk, look, fine=None, coarse=None):
    """The coat's strands (0..1) and a coarser locks pattern: (fine, locks,
    their way)."""
    d = coat_way(q, n, mk, look)
    f = fine or look.get("strand", (0.0011, 0.012))
    c = coarse or look.get("lock", (0.0040, 0.030))
    s1 = strands(q, d, f[0], f[1], 3)
    s2 = strands(q, d, c[0], c[1], 7, samples=10)
    return s1, s2, d


def paint_fur(q, n, ao, mk, look, zone):
    """The coat: its colours (look["coat"](q, n, mk) - as seen), drawn as
    hair: each strand lighter at its tip, darker where the coat parts, the
    shape's shading laid in. Returns colour and height."""
    base = look["coat"](q, n, mk, zone)
    s1, s2, d = hair(q, n, mk, look)
    v = 0.6 * s1 + 0.4 * s2
    k = look.get("contrast", 0.55)
    col = base * (1.0 - k * 0.5 + k * v)[:, None]
    tip = look.get("tips")
    if tip is not None:
        col = mix(col, tip(q, n, mk, base), np.clip((s1 - 0.62) * 2.2, 0, 1) * 0.45)
    # a slow wash of light and dark, as a real coat has
    wash = fbm(q / 0.05, 2, 41)
    col *= (0.93 + 0.14 * wash)[:, None]
    col *= (0.40 + 0.60 * ao ** 0.8)[:, None]
    h = 0.55 * s1 + 0.45 * s2
    return col, h


# ---------------------------------------------------------------- owl

def paint_feathers(q, n, ao, mk, look, zone):
    """Feathers (the snowy owl): white, lying over each other down the body
    and out along the arms, out from the eyes over the face - each its
    rounded tip over the next one's root, a shaft down its middle and
    barbs slanting off it, a soft grey under its tip; a dark bar across a
    few on the back, crown and wings."""
    from scipy.spatial import cKDTree
    F = look["feather"]
    rng = np.random.default_rng(11)
    fwd = mk.fwd

    def size_at(p):
        # small on the face and crown, larger down the body and wings
        p = np.atleast_2d(p)
        head = smooth(mk["neck_01"][2], mk.eye_mid[2] - 0.02, p[:, 2]) * (np.abs(p[:, 0]) < 0.3)
        face = smooth(0.0, 0.05, (p - mk.head) @ fwd + 0.02) * head
        return F * (1.0 - 0.30 * head - 0.25 * face)
    co = mk.co[(mk.co[:, 2] > mk["thigh_l"][2] - 0.6)]
    pts = co[rng.permutation(len(co))]
    psz = size_at(pts)
    centres, sizes = [], []
    tree = None
    for p, r in zip(pts, psz):
        if centres and len(centres) % 300 == 0:
            tree = cKDTree(np.array(centres))
        if tree is not None and tree.query(p)[0] < r:
            continue
        if centres and np.min(np.linalg.norm(np.array(centres[-300:]) - p, axis=1)) < r:
            continue
        centres.append(p)
        sizes.append(r)
    c = np.array(centres)
    csz = np.array(sizes)
    # the way they lie: the coat's way, and out from the eyes on the face
    d = coat_way(q, n, mk, look)
    e = np.array(mk.eyes)[(q[:, 0] < 0).astype(int)]
    face = smooth(0.02, -0.02, (q - mk.eye_mid) @ (-fwd) + 0.06) * smooth(-0.11, -0.06, q[:, 2] - mk.eye_mid[2]) * \
        smooth(0.11, 0.07, q[:, 2] - mk.eye_mid[2])
    rad = q - e
    rad -= np.outer(rad @ fwd, fwd)
    d = unit(mix(d, unit(rad), face))
    d = unit(d - n * np.sum(d * n, axis=1, keepdims=True))
    _, near = cKDTree(c).query(q, k=10)
    W = csz[near] * 1.0
    L = csz[near] * 1.5
    rel = q[:, None, :] - c[near]
    a = np.einsum("nki,ni->nk", rel, d)
    side = rel - a[:, :, None] * d[:, None, :]
    b = np.linalg.norm(side, axis=2)
    # (a feather's outline a little ragged - its barbs' ends)
    rag = 1.0 + 0.06 * np.sin(np.arctan2(b, a) * 9.0 + near * 1.7)
    E = np.hypot(a / L, b / W) * rag
    rank = np.einsum("nki,ni->nk", c[near], d)
    covers = E < 1.0
    top = np.argmin(np.where(covers, rank, np.inf), axis=1)
    top[~covers.any(axis=1)] = 0
    rows = np.arange(len(q))
    mine = rank[rows, top]
    above = (rank < mine[:, None] - 1e-6) & (a > 0.0)
    under = np.where(above, np.clip(1.0 - (E - 1.0) / 0.35, 0.0, 1.0), 0.0).max(axis=1)
    Et, at, bt = E[rows, top], a[rows, top], b[rows, top]
    Lt, Wt = L[rows, top], W[rows, top]
    # the shaft and the barbs off it (slanting toward the tip)
    shaft = np.clip(1.0 - bt / (Wt * 0.05), 0.0, 1.0) * smooth(-Lt * 0.9, -Lt * 0.2, at)
    barbs = 0.5 + 0.5 * np.sin((at - bt * 0.9) / (Wt * 0.075) * 2 * math.pi)
    barbs = barbs * smooth(0.04, 0.25, bt / Wt)
    which = near[rows, top]
    jitter = rng.uniform(-0.035, 0.035, len(c))[which]
    white = look["white"]
    col = np.tile(white, (len(q), 1)) * (1.0 + jitter[:, None])
    col *= (0.94 + 0.06 * barbs)[:, None]
    col = mix(col, look["shaft"], shaft * 0.30)
    # the soft grey where a feather's tip lies over the next (fainter on
    # the face, where they're downy)
    shade = under ** 1.6 * (1.0 - 0.7 * face) * 0.8
    col = mix(col, look["shade"], shade)
    # the markings: a small dark spot near the tip of one feather in FLECK
    # on its back, crown and wings (none on its face and front)
    behind = (c - mk.head) @ (-fwd)
    marks = (behind > 0.04) | (c[:, 2] > mk.top - 0.08) | (np.abs(c[:, 0]) > abs(mk["upperarm_l"][0]) * 1.2)
    marks &= rng.integers(0, look["fleck"], len(c)) == 0
    spot = np.hypot((at - 0.55 * Lt) / (0.20 * Lt), bt / (0.30 * Wt))
    bar = marks[which] & (spot < 1.0) & (face < 0.5)
    col = mix(col, look["dark"], bar * smooth(1.0, 0.6, spot))
    col *= (0.55 + 0.45 * ao ** 0.7)[:, None]
    h = np.clip(1.0 - Et, 0.0, 1.0) ** 0.5 * 0.6 + 0.2 * barbs + 0.25 * shaft
    print("feathers: %d, %d barred" % (len(c), marks.sum()))
    return col, h


# ---------------------------------------------------------------- sheep

def paint_wool(q, n, ao, mk, look, zone):
    """Fleece (the sheep): soft round locks, each a tight curl of crimped
    fibres, white, the gaps between them in shade."""
    cell = look["wool"]
    d1, d2, idv = worley(q / cell, 21)
    lump = np.clip(1.0 - d1 / 0.9, 0.0, 1.0)
    edge = smooth(0.0, 0.35, d2 - d1)
    # each lock's fibres curling round its middle
    i = np.floor(q / cell).astype(np.int64)
    # (the way round: the surface's normal crossed with the way to the
    # lock's middle, approximated by the noise's gradient)
    eps = cell * 0.25
    g = np.stack([worley((q + np.eye(3)[k] * eps) / cell, 21)[0] - d1 for k in range(3)], axis=1)
    curl = unit(np.cross(n, unit(g) + 1e-6))
    fib = strands(q, curl, cell * 0.10, cell * 0.8, 5, samples=10)
    base = look["coat"](q, n, mk, zone)
    col = base * (0.80 + 0.22 * fib)[:, None]
    col = mix(look["wool_shade"], col, (0.35 + 0.65 * edge * (0.4 + 0.6 * lump)))
    col *= (0.95 + 0.08 * (idv - 0.5))[:, None]
    col *= (0.62 + 0.38 * ao ** 0.8)[:, None]
    h = 0.7 * lump * edge + 0.3 * fib
    return col, h


# ---------------------------------------------------------------- face

def paint_eyes(q, n, ao, mk, look):
    """The eyes: an iris (its rim darker, fine fibres out from the pupil),
    the pupil (round, or a sheep's bar), a catchlight up and to the side,
    the white barely showing (as an animal's), glossy."""
    col = np.zeros((len(q), 3))
    iris_c = look["iris"]
    for k, s in enumerate((1, -1)):
        sel = (q[:, 0] * s) > 0
        pts = mk.eye_pts[mk.eye_pts[:, 0] * s > 0]
        ball = pts.mean(axis=0)
        r = np.linalg.norm(pts - ball, axis=1).mean()
        qq, aa = q[sel], ao[sel]
        v = unit(qq - ball)
        # where it looks: ahead and out to its side (as the head was made)
        look_d = unit(mk.fwd + np.array([s * look.get("eye_side", 0.3), 0.0, 0.0]))
        ang = np.arccos(np.clip(v @ look_d, -1, 1))
        shown = np.percentile(ang[aa > 0.6], 90) if (aa > 0.6).sum() > 10 else 0.9
        iris = float(np.clip(shown, 0.6, 1.15)) * look.get("iris_share", 0.86)
        up = np.array([0.0, 0.0, 1.0]) - look_d * look_d[2]
        up = unit(up)
        right = np.cross(look_d, up)
        x = np.arcsin(np.clip(v @ right, -1, 1)) / iris
        y = np.arcsin(np.clip(v @ up, -1, 1)) / iris
        rr = np.hypot(x, y)
        th = np.arctan2(y, x)
        fib = vnoise(np.stack([np.cos(th) * 6, np.sin(th) * 6, rr * 3], axis=1) * 3.0, 77)
        c = mix(iris_c[1], iris_c[0], smooth(0.25, 0.95, rr))
        c *= (0.80 + 0.35 * fib)[:, None]
        c = mix(c, iris_c[2], smooth(0.80, 1.0, rr))
        if look.get("pupil_bar"):
            pupil = (np.abs(x) < look["pupil"] * 1.25) & (np.abs(y) < look["pupil"] * 0.38)
        else:
            pupil = rr < look["pupil"]
        c[pupil] = srgb(0.02, 0.02, 0.02)
        white = rr > 1.0
        c[white] = mix(look.get("sclera", srgb(0.80, 0.74, 0.66)), srgb(0.25, 0.20, 0.18), smooth(1.0, 1.3, rr[white]))
        # the catchlight
        hl = np.hypot(x + s * 0.32, y - 0.38)
        c = mix(c, srgb(1.0, 1.0, 0.98), smooth(0.17, 0.11, hl))
        col[sel] = c
    return col


def paint_leather(q, n, ao, mk, look, base, cell=0.0011):
    """Nose leather and pads: pebbled - small domes, darker cracks."""
    d1, d2, idv = worley(q / cell, 31)
    crack = smooth(0.0, 0.18, d2 - d1)
    col = base * (0.55 + 0.45 * crack)[:, None] * (0.92 + 0.16 * idv)[:, None]
    col *= (0.55 + 0.45 * ao)[:, None]
    return col, 0.6 * crack + 0.2 * idv


def lid_rims(q, col, mk, look):
    """A dark rim of bare lid round each eye, where the fur meets it."""
    rim = look.get("rim", 0.0022)
    for s in (1, -1):
        pts = mk.eye_pts[mk.eye_pts[:, 0] * s > 0]
        if not len(pts):
            continue
        ball = pts.mean(axis=0)
        r = np.linalg.norm(pts - ball, axis=1).mean()
        dd = np.linalg.norm(q - ball, axis=1) - r
        col = mix(col, look.get("lid", srgb(0.06, 0.05, 0.05)), smooth(rim, rim * 0.4, dd))
    return col


def nostrils(q, col, mk, look):
    """Two dark nostrils low on the front of the nose."""
    nose = mk.nose
    w = look.get("nostril", 0.0085)
    for s in (1, -1):
        c = nose + np.array([s * w, 0.0, -w * 0.45])
        rel = q - c
        rel[:, 0] *= 0.8
        rel[:, 2] *= 1.6
        dd = np.linalg.norm(rel, axis=1)
        col = mix(col, srgb(0.015, 0.012, 0.012), smooth(w * 0.55, w * 0.35, dd))
    return col


# ---------------------------------------------------------------- clothes

def knit_cells(u, v, colw=0.0050, rowh=0.0044):
    """Stockinette: rows of V stitches - (height 0..1, stitch id)."""
    cu = u / colw
    cv = v / rowh
    a = cu - np.floor(cu) - 0.5
    best = np.zeros(len(u))
    for dv in (0.0, 1.0, -1.0):
        b = cv - np.floor(cv) + dv
        for s in (-1, 1):
            # a leg: an ellipse tilted to make the V (its bottom at the
            # column's middle)
            ax = np.array([s * 0.42, 1.0])
            ax /= np.linalg.norm(ax)
            pu, pv = a - s * 0.22, b - 0.55
            al = pu * ax[0] + pv * ax[1]
            ac = -pu * ax[1] + pv * ax[0]
            e = 1.0 - (al / 0.62) ** 2 - (ac / 0.24) ** 2
            best = np.maximum(best, np.sqrt(np.clip(e, 0.0, 1.0)))
    sid = np.floor(cu) * 7.13 + np.floor(cv) * 3.71
    return best, np.sin(sid) * 0.5 + 0.5


def rib_cells(u, v, colw=0.0042):
    """1x1 rib: raised knit columns of stitches between sunk purl ones."""
    cu = u / colw
    col = np.floor(cu)
    a = cu - col - 0.5
    knit = (col % 2) == 0
    st, _ = knit_cells(u, v, colw, 0.0040)
    prof = np.cos(a * math.pi) ** 2
    h = np.where(knit, 0.55 + 0.45 * st * prof, 0.15 + 0.15 * np.cos(v / 0.002 * math.pi) ** 2)
    return h


def knit_coords(q, mk):
    """Where on the knit: (round, along) - round the trunk and down it on
    the body, round the arm and along it on the sleeves (the two meeting
    in a seam at the shoulder)."""
    sx = abs(mk["upperarm_l"][0]) * 1.06
    sleeve = np.abs(q[:, 0]) > sx
    # body: round the trunk
    sp = mk["spine_02"]
    th = np.arctan2(q[:, 0], -(q[:, 1] - sp[1]) * np.sign(-mk.fwd[1] if abs(mk.fwd[1]) > 0.5 else 1.0))
    u_b = th * 0.16
    v_b = -q[:, 2]
    # sleeves: round the arm and out along it
    sh = mk["upperarm_l"]
    th2 = np.arctan2(q[:, 2] - sh[2], q[:, 1] - sh[1])
    u_s = th2 * 0.05
    v_s = np.abs(q[:, 0])
    u = np.where(sleeve, u_s, u_b)
    v = np.where(sleeve, v_s, v_b)
    seam = smooth(0.003, 0.0, np.abs(np.abs(q[:, 0]) - sx))
    return u, v, sleeve, seam


def paint_knit(q, n, ao, mk, look, rib):
    u, v, sleeve, seam = knit_coords(q, mk)
    st, sid = knit_cells(u, v)
    h = st.copy()
    if rib.any():
        # the rib's columns run across the band: along the arm on the
        # cuffs, up and down on the hem, out from the neck round the
        # collar
        neck = mk["neck_01"]
        phi = np.arctan2(q[:, 0], -(q[:, 1] - neck[1]) * (-mk.fwd[1] if abs(mk.fwd[1]) > 0.5 else 1.0))
        r_neck = np.linalg.norm((q - neck)[:, :2], axis=1)
        collar = rib & (q[:, 2] > mk["spine_03"][2] - 0.02) & (np.abs(q[:, 0]) < abs(mk["upperarm_l"][0]))
        ru = np.where(collar, phi * 0.08, u)
        rv = np.where(collar, r_neck + (neck[2] - q[:, 2]) * 0.5, v)
        h[rib] = rib_cells(ru[rib], rv[rib])
    col = np.where(rib[:, None], COMMON["rib"][None, :], COMMON["knit"][None, :])
    col *= (0.62 + 0.42 * h + 0.05 * (sid - 0.5))[:, None]
    col *= (1.0 - 0.18 * seam)[:, None]
    col *= (0.42 + 0.58 * ao ** 0.9)[:, None]
    return col, h


def paint_cloth(q, n, ao, mk, base, pitch=0.0016, contrast=0.12, seams=True):
    """Cotton twill: fine diagonal ribs (two plane waves across the
    surface, whichever lies better), a little mottling, the shading."""
    a1 = unit(np.array([1.0, 0.35, 1.0]))
    a2 = unit(np.array([0.35, 1.0, -1.0]))
    w1 = 1.0 - np.abs(n @ a1)
    w2 = 1.0 - np.abs(n @ a2)
    t1 = 0.5 + 0.5 * np.sin(q @ a1 / pitch * 2 * math.pi)
    t2 = 0.5 + 0.5 * np.sin(q @ a2 / pitch * 2 * math.pi)
    tw = (t1 * w1 + t2 * w2) / (w1 + w2 + 1e-9)
    mott = fbm(q / 0.012, 3, 55)
    col = base * (1.0 - contrast + contrast * 2 * tw * 0.5 + 0.08 * (mott - 0.5))[:, None]
    h = tw * 0.4 + mott * 0.2
    if seams:
        line, stitch = shorts_seams(q, n, mk)
        col *= (1.0 - 0.28 * line - 0.10 * stitch)[:, None]
        h = h - 0.6 * line + 0.25 * stitch
    col *= (0.40 + 0.60 * ao ** 0.9)[:, None]
    return col, h


def shorts_seams(q, n, mk):
    """The shorts' making: the waistband (stitched along both edges), a
    slanting pocket opening each side in front, two patch pockets behind,
    the side seams down the outside of the legs; as (seam lines, rows of
    stitches beside them) 0..1."""
    top = q[:, 2].max()
    hip = abs(mk["thigh_l"][0])
    yc = mk["pelvis"][1]
    ax = np.abs(q[:, 0])
    front = (q[:, 1] - yc) * np.sign(mk.fwd[1]) > 0
    k = hip / 0.18
    w = 0.0012
    lines = []
    stitches = []

    def stitched(dist, off=0.004 * k):
        # a seam on dist = 0, a row of stitches a few mm beside it
        lines.append(smooth(w, w * 0.3, np.abs(dist)))
        dash = 0.5 + 0.5 * np.sin((q[:, 0] + q[:, 1] + q[:, 2]) / 0.0016 * math.pi)
        stitches.append(smooth(w * 0.7, 0.0, np.abs(np.abs(dist) - off)) * smooth(0.3, 0.6, dash))
    band = 0.034 * k
    stitched(q[:, 2] - (top - band))
    stitches.append(smooth(w * 0.7, 0.0, np.abs(q[:, 2] - (top - 0.004 * k))) *
                    smooth(0.3, 0.6, 0.5 + 0.5 * np.sin((q[:, 0] + q[:, 1]) / 0.0016 * math.pi)))
    # front pockets: a curve from the waistband out and down to the side
    x0, x1 = hip * 0.45, hip * 1.25
    t = np.clip((ax - x0) / (x1 - x0), 0.0, 1.0)
    zc = top - band - (t ** 1.6) * 0.075 * k
    on = front & (ax > x0 - 0.003) & (ax < x1) & (q[:, 2] < top - band + 0.002)
    stitched(np.where(on, q[:, 2] - zc, 1.0))
    # back pockets
    bx0, bx1 = hip * 0.20, hip * 0.85
    bz0, bz1 = top - band - 0.105 * k, top - band - 0.025 * k
    inside = (~front) & (ax > bx0) & (ax < bx1) & (q[:, 2] > bz0) & (q[:, 2] < bz1)
    edge = np.minimum.reduce([ax - bx0, bx1 - ax, q[:, 2] - bz0, bz1 - q[:, 2]])
    stitched(np.where(inside, edge, np.where((~front) & (ax > bx0 - 0.002) & (ax < bx1 + 0.002) &
                                             (q[:, 2] > bz0 - 0.002) & (q[:, 2] < bz1 + 0.002), 0.0, 1.0)))
    # side seams
    stitched(np.where(ax > hip * 0.8, (q[:, 1] - yc), 1.0))
    return np.clip(np.maximum.reduce(lines), 0, 1), np.clip(np.maximum.reduce(stitches), 0, 1)


def paint_wood(q, n, ao, mk, base):
    """The buttons: wood, its rings round its middle, varnished."""
    r = np.linalg.norm((q - q.mean(axis=0))[:, [0, 2]], axis=1)
    g = fbm(q / 0.004, 2, 61)
    rings = 0.5 + 0.5 * np.sin((r + 0.002 * g) / 0.0012 * 2 * math.pi)
    col = base * (0.80 + 0.25 * rings)[:, None]
    col *= (0.45 + 0.55 * ao)[:, None]
    return col, rings * 0.3


# ---------------------------------------------------------------- looks

def _near_seg(q, a, b):
    ab = b - a
    t = np.clip(((q - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(q - (a + t[:, None] * ab), axis=1), t


def face_masks(q, n, mk):
    """Useful places on the head: (muzzle - the snout ahead of the eyes,
    chin and throat - under the jaw, ahead of the neck, eye ring, inner
    ear, crown)."""
    fwd = mk.fwd
    H = mk.head
    ahead = (q - mk.eye_mid) @ fwd
    snout_len = max(float((mk.nose - mk.eye_mid) @ fwd), 0.02)
    muzzle = smooth(-0.1 * snout_len, 0.35 * snout_len, ahead) * smooth(0.04, 0.0, q[:, 2] - mk.eye_mid[2] + 0.0)
    under = smooth(0.0, -0.4, n[:, 2])
    neck = mk["neck_01"]
    throat = smooth(H[2] + 0.02, neck[2], q[:, 2]) * 0 + smooth(-0.3, 0.3, -((q - H) @ (-fwd))) * \
        smooth(0.2, -0.5, n[:, 2] + (n @ (-fwd)) * 0.0) * (q[:, 2] > neck[2] - 0.02) * (q[:, 2] < mk.eye_mid[2] - 0.01)
    throat = np.clip(throat * smooth(-0.6, 0.1, -(n @ fwd)), 0, 1)
    ring = np.zeros(len(q))
    for e in mk.eyes:
        dd = np.linalg.norm(q - e, axis=1)
        ring = np.maximum(ring, smooth(mk.eye_gap * 0.36, mk.eye_gap * 0.24, dd))
    inner = np.zeros(len(q))
    for s in ("l", "r"):
        a = "ear_%s1_01" % s
        if a in mk.b:
            b = "ear_%s1_02" % s
            tip = mk.t[b] if b in mk.t else mk.t[a]
            dd, t = _near_seg(q, mk[a], tip)
            facing = smooth(-0.1, 0.5, n @ fwd)
            inner = np.maximum(inner, smooth(0.05, 0.03, dd) * smooth(0.05, 0.25, t) * facing)
    crown = smooth(mk.eye_mid[2], mk.top, q[:, 2])
    # (all of it on the head only - ahead of the eyes and below them is
    # the knees' fronts too)
    on_head = smooth(neck[2] - 0.01, neck[2] + 0.03, q[:, 2]) * (np.abs(q[:, 0]) < 0.3)
    muzzle *= on_head
    ring *= on_head
    crown *= on_head
    ahead = np.where(on_head > 0.5, ahead, -1.0)
    return dict(muzzle=muzzle, under=under, throat=throat, ring=ring, inner_ear=inner, crown=crown, ahead=ahead)


def limb_masks(q, mk):
    """(hands, feet, lower legs, lower arms): 0..1."""
    hand = np.zeros(len(q))
    foot = np.zeros(len(q))
    for s in ("l", "r"):
        dd, _ = _near_seg(q, mk["hand_" + s], mk.t["middle_03_" + s] if "middle_03_" + s in mk.t else mk.t["hand_" + s])
        hand = np.maximum(hand, smooth(0.06, 0.03, dd))
        foot = np.maximum(foot, smooth(mk["calf_" + s][2] * 0.0 + mk["foot_" + s][2] + 0.04, mk["foot_" + s][2], q[:, 2]))
    calf = smooth(mk["calf_l"][2] + 0.02, mk["calf_l"][2] - 0.08, q[:, 2])
    fore = smooth(abs(mk["lowerarm_l"][0]) * 0.95, abs(mk["hand_l"][0]), np.abs(q[:, 0])) * \
        (q[:, 2] > mk["pelvis"][2])
    return dict(hand=hand, foot=foot, calf=calf, fore=fore)


def coat_dog(q, n, mk, zone):
    """A fawn chihuahua: warm fawn, a touch darker and redder down its
    back, nape and the backs of its ears; cream under its chin, down its
    throat, inside its legs and on its paws; the ears' insides pale pink,
    thinly haired; the muzzle a little darker toward the nose."""
    fawn = srgb(0.80, 0.58, 0.36)
    dark = srgb(0.66, 0.43, 0.25)
    cream = srgb(0.96, 0.89, 0.76)
    pink = srgb(0.92, 0.72, 0.66)
    fm = face_masks(q, n, mk)
    lm = limb_masks(q, mk)
    back = smooth(-0.2, 0.6, (n @ (-mk.fwd)) * 1.0 + n[:, 2] * 0.3)
    col = mix(np.tile(fawn, (len(q), 1)), dark, back * 0.55)
    col = mix(col, dark * 0.92, fm["crown"] * 0.25)
    col = mix(col, cream, np.clip(fm["throat"] * 1.2, 0, 1))
    col = mix(col, cream, fm["muzzle"] * fm["under"] * 0.9)
    col = mix(col, cream, lm["hand"] * 0.65 + lm["foot"] * 0.75)
    inner_leg = smooth(0.3, -0.2, np.abs(n[:, 0]) * np.sign(q[:, 0]) * np.sign(n[:, 0])) * lm["calf"]
    col = mix(col, cream, inner_leg * 0.5)
    tipn = smooth(0.5, 1.0, fm["ahead"] / max(float((mk.nose - mk.eye_mid) @ mk.fwd), 0.02))
    col = mix(col, srgb(0.42, 0.28, 0.19), tipn * 0.55)
    col = mix(col, pink, fm["inner_ear"])
    return col


def coat_bear(q, n, mk, zone):
    """A brown bear: dark brown, its legs and paws near black-brown, the
    hump and shoulders grizzled (the hairs' tips pale), the muzzle a
    lighter tan, the ears' rims light."""
    brown = srgb(0.36, 0.22, 0.12)
    legs = srgb(0.17, 0.10, 0.06)
    tan = srgb(0.56, 0.42, 0.28)
    fm = face_masks(q, n, mk)
    lm = limb_masks(q, mk)
    col = np.tile(brown, (len(q), 1))
    col = mix(col, legs, np.clip(lm["calf"] + lm["hand"] + lm["foot"] + lm["fore"] * 0.6, 0, 1))
    col = mix(col, tan, fm["muzzle"] * 0.85)
    col = mix(col, srgb(0.24, 0.15, 0.09), fm["ring"] * 0.5)
    col = mix(col, srgb(0.22, 0.14, 0.09), fm["inner_ear"] * 0.8)
    return col


def tips_bear(q, n, mk, base):
    hump = smooth(mk["spine_03"][2] - 0.05, mk.head[2], q[:, 2]) * smooth(-0.2, 0.5, n @ (-mk.fwd) + n[:, 2])
    return mix(base, srgb(0.72, 0.58, 0.40), hump)


def coat_deer(q, n, mk, zone):
    """A red deer stag: red-brown, its head and neck greyer brown, a dark
    mane down the throat, the lower legs grey-brown; a pale band round the
    muzzle behind the dark nose, a white chin, pale rings round the eyes,
    pale inside the ears; the tail cream under, dark on top."""
    red = srgb(0.56, 0.33, 0.18)
    grey = srgb(0.46, 0.36, 0.27)
    mane = srgb(0.30, 0.22, 0.16)
    pale = srgb(0.86, 0.80, 0.70)
    fm = face_masks(q, n, mk)
    lm = limb_masks(q, mk)
    neck = mk["neck_01"]
    up = smooth(mk["spine_03"][2] - 0.04, neck[2] + 0.02, q[:, 2]) * (np.abs(q[:, 0]) < abs(mk["clavicle_l"][0]) + 0.1)
    col = mix(np.tile(red, (len(q), 1)), grey, up)
    col = mix(col, mane, fm["throat"] * (1.0 - smooth(mk.eye_mid[2] - 0.08, mk.eye_mid[2] - 0.03, q[:, 2])))
    col = mix(col, grey * 0.8, np.clip(lm["calf"] + lm["foot"], 0, 1) * 0.8)
    snout = max(float((mk.nose - mk.eye_mid) @ mk.fwd), 0.02)
    band = smooth(0.55, 0.70, fm["ahead"] / snout) * smooth(0.95, 0.82, fm["ahead"] / snout)
    col = mix(col, pale, band * 0.85)
    col = mix(col, srgb(0.16, 0.12, 0.10), smooth(0.86, 0.96, fm["ahead"] / snout))
    col = mix(col, pale * 1.05, fm["muzzle"] * fm["under"])
    col = mix(col, pale, fm["ring"] * 0.6)
    col = mix(col, pale, fm["inner_ear"])
    return col


def coat_sheep(q, n, mk, zone):
    """A white sheep, all over: the fleece white, its face and lower legs
    short white hair, a little pink round the nose and eyes and inside the
    ears."""
    white = srgb(0.95, 0.94, 0.90)
    fm = face_masks(q, n, mk)
    col = np.tile(white, (len(q), 1))
    col = mix(col, srgb(0.90, 0.80, 0.78), fm["inner_ear"] * 0.8)
    snout = max(float((mk.nose - mk.eye_mid) @ mk.fwd), 0.02)
    col = mix(col, srgb(0.86, 0.74, 0.72), smooth(0.85, 1.0, fm["ahead"] / snout) * 0.7)
    col = mix(col, srgb(0.88, 0.80, 0.78), fm["ring"] * 0.35)
    return col


def coat_owl(q, n, mk, zone):
    return np.tile(srgb(0.96, 0.96, 0.94), (len(q), 1))


def sheep_wool_mask(q, n, mk, zone):
    """Where the sheep is fleece (not short hair): its crown and the back
    of its head, its neck and the ruff, its legs down to the shins."""
    fm = face_masks(q, n, mk)
    face = smooth(-0.04, 0.02, fm["ahead"] + 0.0) * smooth(0.06, 0.0, q[:, 2] - mk.eye_mid[2] - 0.03)
    head = (q[:, 2] > mk["neck_01"][2]) & (np.abs(q[:, 0]) < 0.3)
    legs = smooth(mk["foot_l"][2] + 0.14, mk["foot_l"][2] + 0.22, q[:, 2]) * (q[:, 2] < mk["pelvis"][2])
    arms = np.abs(q[:, 0]) > abs(mk["hand_l"][0]) - 0.02
    w = np.where(head, 1.0 - face, 1.0)
    w = np.where(q[:, 2] < mk["pelvis"][2], legs, w)
    w = np.where(arms, 0.0, w)
    return np.clip(w, 0, 1)


def horn_dog(q, n, mk):
    return np.tile(srgb(0.16, 0.14, 0.13), (len(q), 1))


def horn_bear(q, n, mk):
    # claws: dark at the root, horn-coloured at the tips
    return np.tile(srgb(0.55, 0.50, 0.42), (len(q), 1))


def horn_deer(q, n, mk):
    """Antlers: bone with brown in the grooves, pale at the tips; the
    hooves dark."""
    g = fbm(q * np.array([1 / 0.003, 1 / 0.003, 1 / 0.03]), 3, 91)
    col = mix(srgb(0.46, 0.36, 0.25), srgb(0.80, 0.74, 0.62), smooth(0.35, 0.75, g))
    tips = smooth(mk.top - 0.12, mk.top, q[:, 2])
    col = mix(col, srgb(0.92, 0.88, 0.80), tips)
    hoof = q[:, 2] < mk["calf_l"][2] * 0.5
    col[hoof] = srgb(0.13, 0.11, 0.10)
    return col


def horn_sheep(q, n, mk):
    """Horns: tan, ridged with growth rings (darker in the grooves); the
    hooves dark."""
    g = fbm(q / 0.004, 2, 93)
    col = mix(srgb(0.55, 0.45, 0.31), srgb(0.78, 0.69, 0.52), g)
    hoof = q[:, 2] < mk["calf_l"][2] * 0.5
    col[hoof] = srgb(0.15, 0.13, 0.12)
    return col


def horn_owl(q, n, mk):
    return np.tile(srgb(0.09, 0.08, 0.08), (len(q), 1))


# (as seen - sRGB) iris: (rim, middle, limbal ring)
LOOKS = {
    "dog": dict(coat=coat_dog, kind="fur", strand=(0.0010, 0.011), lock=(0.0032, 0.020), contrast=0.60,
                iris=(srgb(0.16, 0.09, 0.05), srgb(0.30, 0.17, 0.08), srgb(0.05, 0.03, 0.02)), pupil=0.48,
                iris_share=0.92, eye_side=0.34, nose=srgb(0.07, 0.06, 0.06), pad=srgb(0.20, 0.15, 0.14), horn=horn_dog,
                scarf=srgb(0.56, 0.10, 0.08), nostril=0.0070),
    "bear": dict(coat=coat_bear, tips=tips_bear, kind="fur", strand=(0.0013, 0.022), lock=(0.0055, 0.050),
                 contrast=0.60, iris=(srgb(0.14, 0.08, 0.05), srgb(0.26, 0.15, 0.08), srgb(0.04, 0.03, 0.02)),
                 pupil=0.42, iris_share=0.95, eye_side=0.20, nose=srgb(0.06, 0.05, 0.05), pad=srgb(0.10, 0.08, 0.08),
                 horn=horn_bear, nostril=0.011),
    "deer": dict(coat=coat_deer, kind="fur", strand=(0.0010, 0.010), lock=(0.0035, 0.022), contrast=0.45,
                 iris=(srgb(0.10, 0.06, 0.04), srgb(0.20, 0.12, 0.07), srgb(0.03, 0.02, 0.02)), pupil=0.55,
                 iris_share=0.97, eye_side=0.75, nose=srgb(0.08, 0.07, 0.07), pad=srgb(0.12, 0.10, 0.09), horn=horn_deer,
                 nostril=0.0085),
    "sheep": dict(coat=coat_sheep, kind="wool", wool=0.0075, wool_shade=srgb(0.80, 0.77, 0.70),
                  strand=(0.0009, 0.006), lock=(0.0030, 0.012), contrast=0.30,
                  iris=(srgb(0.55, 0.38, 0.10), srgb(0.78, 0.60, 0.22), srgb(0.20, 0.14, 0.05)), pupil=0.30,
                  pupil_bar=True, iris_share=0.92, eye_side=0.80, nose=srgb(0.55, 0.42, 0.42), pad=srgb(0.16, 0.14, 0.13),
                  horn=horn_sheep, nostril=0.0065),
    "owl": dict(coat=coat_owl, kind="feathers", feather=0.019, white=srgb(0.97, 0.97, 0.95),
                shade=srgb(0.72, 0.75, 0.80), shaft=srgb(0.82, 0.82, 0.82), dark=srgb(0.24, 0.21, 0.19), fleck=5,
                iris=(srgb(0.86, 0.72, 0.26), srgb(0.93, 0.83, 0.42), srgb(0.32, 0.25, 0.10)), pupil=0.48,
                iris_share=0.92, eye_side=0.1, nose=srgb(0.30, 0.26, 0.20), pad=srgb(0.40, 0.38, 0.37), horn=horn_owl),
}
# (user request: the beginner's outfit iron grey and charcoal with navy - the
# jumper iron grey, its collar, cuffs and hem charcoal, the shorts navy)
COMMON = dict(knit=srgb(0.43, 0.44, 0.46), rib=srgb(0.21, 0.22, 0.24), cloth=srgb(0.15, 0.20, 0.33),
              button=srgb(0.50, 0.32, 0.17))
# roughness by zone
ROUGH = {"fur": 0.88, "skin": 0.38, "horn": 0.45, "eye": 0.06, "knit": 0.95, "cloth": 0.86, "button": 0.42,
         "scarf": 0.80, "pad": 0.70, "muzzle": 0.88, "rib": 0.95}
# the normal map's strength by zone (m of height per unit)
BUMP = {"fur": 0.0007, "muzzle": 0.0006, "skin": 0.0005, "pad": 0.0005, "horn": 0.0004, "knit": 0.0012,
        "rib": 0.0014, "cloth": 0.0004, "button": 0.0003, "scarf": 0.0003, "eye": 0.0}


def paint(P, N, Z, AO, on, mk, look):
    """The picture, the height and the roughness, texel by texel."""
    col = np.zeros((SIZE, SIZE, 3))
    hgt = np.zeros((SIZE, SIZE))
    rough = np.full((SIZE, SIZE), 0.8)
    for zi, zn in enumerate(ZONE_NAMES):
        sel = on & (Z == zi)
        if not sel.any():
            continue
        q, n, ao = P[sel], N[sel], AO[sel]
        if zn in ("fur", "muzzle"):
            if look["kind"] == "feathers":
                c, h = paint_feathers(q, n, ao, mk, look, zi)
            elif look["kind"] == "wool":
                c1, h1 = paint_fur(q, n, ao, mk, look, zi)
                c2, h2 = paint_wool(q, n, ao, mk, look, zi)
                w = sheep_wool_mask(q, n, mk, zi)
                c, h = mix(c1, c2, w), h1 * (1 - w) + h2 * w
            else:
                c, h = paint_fur(q, n, ao, mk, look, zi)
            c = lid_rims(q, c, mk, look)
        elif zn == "eye":
            c, h = paint_eyes(q, n, ao, mk, look), np.zeros(len(q))
        elif zn == "skin":
            c, h = paint_leather(q, n, ao, mk, look, look["nose"])
            c = nostrils(q, c, mk, look)
        elif zn == "pad":
            c, h = paint_leather(q, n, ao, mk, look, look["pad"], cell=0.0016)
        elif zn == "horn":
            base = look["horn"](q, n, mk)
            g = fbm(q / 0.0015, 2, 97)
            c, h = base * (0.85 + 0.25 * g)[:, None] * (0.55 + 0.45 * ao)[:, None], g * 0.3
        elif zn in ("knit", "rib"):
            c, h = paint_knit(q, n, ao, mk, look, np.full(len(q), zn == "rib"))
        elif zn == "cloth":
            c, h = paint_cloth(q, n, ao, mk, COMMON["cloth"])
        elif zn == "scarf":
            c, h = paint_cloth(q, n, ao, mk, look.get("scarf", srgb(0.56, 0.10, 0.08)), 0.0012, 0.10, False)
        elif zn == "button":
            c, h = paint_wood(q, n, ao, mk, COMMON["button"])
        else:
            c, h = np.tile(srgb(0.5, 0.5, 0.5), (len(q), 1)), np.zeros(len(q))
        col[sel] = np.clip(c, 0.0, 1.0)
        hgt[sel] = h * BUMP.get(zn, 0.0005)
        r = ROUGH.get(zn, 0.8)
        rough[sel] = np.clip(r + (0.08 * (h - 0.5) if zn not in ("eye",) else 0.0), 0.03, 1.0)
        print("painted", zn, sel.sum())
    # (the eyes' shared edges with the lids: the knit and fur bleed no
    # further than their own texels - the bake's margins carry them out)
    return col, hgt, rough


def normal_map(P, hgt, on):
    """The heights' slopes, across the picture, as a tangent-space normal
    map (the picture's u along its tangent, v its bitangent)."""
    gx = np.zeros_like(hgt)
    gy = np.zeros_like(hgt)
    dpx = np.linalg.norm(np.diff(P, axis=1), axis=2)
    dpy = np.linalg.norm(np.diff(P, axis=0), axis=2)
    med = np.median(dpx[on[:, 1:] & on[:, :-1]])
    okx = (dpx < med * 4) & on[:, 1:] & on[:, :-1]
    oky = (dpy < med * 4) & on[1:, :] & on[:-1, :]
    sx = np.where(okx, np.diff(hgt, axis=1) / np.maximum(dpx, 1e-6), 0.0)
    sy = np.where(oky, np.diff(hgt, axis=0) / np.maximum(dpy, 1e-6), 0.0)
    gx[:, :-1] += sx
    gx[:, 1:] += sx
    gx[:, 1:-1] *= 0.5
    gy[:-1, :] += sy
    gy[1:, :] += sy
    gy[1:-1, :] *= 0.5
    nm = np.stack([-gx, -gy, np.ones_like(gx)], axis=2)
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    k = SIZE // SIZE_N
    nm = nm.reshape(SIZE_N, k, SIZE_N, k, 3).mean(axis=(1, 3))
    nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    return nm * 0.5 + 0.5


def bleed(img, on, steps=6):
    """Each picture carried a few texels past its islands' edges (so the
    lower mip levels and the filtering don't pull in black)."""
    out = img.copy()
    have = on.copy()
    for _ in range(steps):
        acc = np.zeros_like(out)
        cnt = np.zeros(have.shape)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            sh = np.roll(np.roll(out * have[..., None] if out.ndim == 3 else out * have, dy, 0), dx, 1)
            acc += sh
            cnt += np.roll(np.roll(have, dy, 0), dx, 1)
        new = (~have) & (cnt > 0)
        if out.ndim == 3:
            out[new] = acc[new] / cnt[new][:, None]
        else:
            out[new] = acc[new] / cnt[new]
        have |= new
    return out


def image(name, arr, non_color=False):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'
    px = np.ones((h, w, 4), np.float32)
    px[:, :, :3] = arr if arr.ndim == 3 else arr[..., None]
    img.pixels.foreach_set(px.ravel())
    img.pack()
    return img


def dress(body, col, nm, rough):
    """One material over all of it: the picture, its normal map, its
    roughness (in the green, as glTF has it)."""
    mat = bpy.data.materials.new(ANIMAL + "_Pelt")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = image(ANIMAL + "_Colour", col)
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    tn = nt.nodes.new('ShaderNodeTexImage')
    tn.image = image(ANIMAL + "_Normal", nm, True)
    nmap = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(tn.outputs['Color'], nmap.inputs['Color'])
    nt.links.new(nmap.outputs['Normal'], b.inputs['Normal'])
    tr = nt.nodes.new('ShaderNodeTexImage')
    mr = np.stack([np.zeros_like(rough), rough, np.zeros_like(rough)], axis=2)
    tr.image = image(ANIMAL + "_Roughness", mr, True)
    sep = nt.nodes.new('ShaderNodeSeparateColor')
    nt.links.new(tr.outputs['Color'], sep.inputs['Color'])
    nt.links.new(sep.outputs['Green'], b.inputs['Roughness'])
    nt.links.new(sep.outputs['Blue'], b.inputs['Metallic'])
    me = body.data
    me.materials.clear()
    me.materials.append(mat)
    me.polygons.foreach_set("material_index", [0] * len(me.polygons))


def main():
    import time
    t0 = time.time()
    arm, body = load()
    fz = zone_of_faces(body)
    mk = Marks(arm, body, fz)
    print("faces", len(fz), "forward", mk.fwd.round(2), "nose", mk.nose.round(3))
    unwrap(body, mk, fz)
    P, N, Z, AO, on = bake_maps(body, fz)
    print("baked %.0fs, %d texels on" % (time.time() - t0, on.sum()))
    look = LOOKS[ANIMAL]
    col, hgt, rough = paint(P, N, Z, AO, on, mk, look)
    print("painted %.0fs" % (time.time() - t0))
    nm = normal_map(P, hgt, on)
    col = bleed(col, on)
    k = SIZE // SIZE_N
    rough_s = rough.reshape(SIZE_N, k, SIZE_N, k).mean(axis=(1, 3))
    if DEBUG:
        from PIL import Image
        Image.fromarray((np.clip(col[::-1], 0, 1) * 255).astype(np.uint8)).save(DEBUG + "_col.png")
        Image.fromarray((np.clip(nm[::-1], 0, 1) * 255).astype(np.uint8)).save(DEBUG + "_nm.png")
    dress(body, col, nm, rough_s)
    select([arm, body], active=arm)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_optimize_animation_size=True, export_anim_single_armature=True,
                              export_def_bones=False, export_image_format='JPEG', export_jpeg_quality=88)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB %.0fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
    sys.stdout.flush()
    os._exit(0)
