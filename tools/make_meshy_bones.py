"""The altar's fish bones from the user's Meshy models (user request: the 13 fish-bone models the
user made with Meshy, from the prompts written for it, to the standard of the ASSET1 open-source
skeleton - each of the game's sixteen bones its own, and the three missing ones cut from the
others so that no two look alike).

The thirteen cover thirteen of the sixteen (scripts/bones.gd: whole / spine / skull / broken, small
to huge); the other three are cut from them - a small skull off the small whole skeleton's head, a
small broken piece out of the middle of a backbone (both ends snapped, ribs knocked off), the big
broken one the back of the huge skeleton (the head snapped off, half its ribs and some spines
gone). Then eight more broken ones (user request: two a size, the more broken the less they're
worth - scripts/bones.gd's COMPLETE): the hardly damaged ("cracked": a few ribs and spines knocked
off, a jaw or the tail's tip broken) and the pieces ("shard": a tail, a stretch of ribcage, the front
of a skull, a backbone broken in two). The glowing bones, the medium skeleton arched three ways (a
rarity each) in their colours.

Each: the model (Meshy's, geometry only) cut as above - the breaks jagged, the knocked-off ribs left
as stubs - fused into one detailed surface; brought down to a game model, unwrapped, the bone's look
baked onto it (tools/make_fish_skeleton.py's: the procedural bone colour, the detailed surface's
normals); laid flat (the ribs in the ground's plane), its head toward +x, 0.3 m long, as the bones
before it (tools/make_fish_bones.py); and its bag picture (that tool's).

  bpyenv/bin/pip install xatlas                                          (once)
  bpyenv/bin/python tools/make_meshy_bones.py MESHY_DIR [name ...]       (repo root)

MESHY_DIR holds the user's Meshy_AI_<Name>_*.fbx (not in the repo: the user's art). Writes
assets/models/items/<name>.glb and assets/sprites/items/<name>.png; then the square icons:
tools/render_square_icons.py bone_... glow_bone_....
"""
import glob
import math
import os
import random
import sys

import bpy
import bmesh  # (after bpy: it's bpy's module)
from mathutils import Vector, noise
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_fish_skeleton as fs  # noqa: E402
import make_fish_bones as fb  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MODELS = os.path.join(ROOT, "assets", "models", "items")
PICS = os.path.join(ROOT, "assets", "sprites", "items")
LENGTH = 1.9          # the models' length while they're worked on (Meshy's own)
VOXEL = 0.0025        # the detailed surface's grain at that length
LOW_VOXEL = 0.004     # the game model's, before it's brought down
TRIS = 8000           # the game model's triangles (a 0.3 m thing on the ground and in the bag)
TEX = 512             # its textures
GAME_LENGTH = 0.3

# Each bone: (the Meshy model, how it's cut). Cuts: ("keep", a, b) keeps the length from a to b
# (0 the head end, 1 the tail's), its ends snapped where they're cut; ("ribs", share, seed) knocks
# off that share of the ribs, ("spines", share, seed) of the spines above; ("split", at, gap, tilt)
# breaks it in two at `at`, the back piece moved `gap` (a share of the length) and turned `tilt`
# degrees; ("bite", y, z, size, seed) knocks a jagged chunk out at (y, z) (shares of the length and
# the height; size a share of the length) - a jaw, a fin; ("arch", ...) bends it.
BONES = {
    "bone_whole_s": ("Fishbone_Fossil", []),
    "bone_whole_m": ("Fish_Skeleton", []),
    "bone_whole_l": ("Fish_Skeleton_1", []),
    "bone_whole_xl": ("Skeletal_Anglerfish", []),
    "bone_spine_s": ("Ancient_Spined_Sea_Fossil", []),
    "bone_spine_m": ("Fishbone_Fossil_1", []),
    "bone_spine_l": ("Fishbone_Fossil_2", []),
    "bone_spine_xl": ("Skeletal_Fish_Remains", []),
    "bone_skull_s": ("Fishbone_Fossil", [("keep", 0.0, 0.3)]),
    "bone_skull_m": ("Fish_Skull", []),
    "bone_skull_l": ("Ancient_Predator_Skull", []),
    "bone_skull_xl": ("Bone_Tyrant_Skull", []),
    "bone_broken_s": ("Fishbone_Fossil_1", [("keep", 0.3, 0.62), ("ribs", 0.5, 3), ("spines", 0.4, 5)]),
    "bone_broken_m": ("Ancient_Fish_Skeleton", []),
    "bone_broken_l": ("Skeletal_Anglerfish", [("keep", 0.3, 1.0), ("ribs", 0.7, 21), ("spines", 0.35, 12)]),
    "bone_broken_xl": ("Bonefin_Leviathan", []),
    # (user request: more broken ones - two a size: one hardly damaged, one in pieces)
    "bone_cracked_s": ("Fishbone_Fossil", [("keep", 0.0, 0.93), ("ribs", 0.4, 31), ("spines", 0.3, 32)]),
    "bone_cracked_m": ("Fish_Skeleton", [("bite", 0.05, 0.22, 0.09, 33), ("ribs", 0.35, 34)]),
    "bone_cracked_l": ("Fish_Skeleton_1", [("ribs", 0.45, 35), ("spines", 0.45, 36), ("keep", 0.0, 0.95)]),
    "bone_cracked_xl": ("Skeletal_Anglerfish", [("bite", 0.04, 0.18, 0.1, 37), ("ribs", 0.3, 38), ("spines", 0.3, 39)]),
    "bone_shard_s": ("Ancient_Spined_Sea_Fossil", [("keep", 0.6, 1.0)]),
    "bone_shard_m": ("Fish_Skeleton_1", [("keep", 0.3, 0.6), ("ribs", 0.5, 41), ("spines", 0.5, 42)]),
    "bone_shard_l": ("Ancient_Predator_Skull", [("keep", 0.0, 0.55), ("bite", 0.35, 0.85, 0.12, 43)]),
    "bone_shard_xl": ("Skeletal_Fish_Remains", [("keep", 0.12, 0.7), ("ribs", 0.55, 44), ("split", 0.45, 0.24, 7.0)]),
    "glow_bone_common": ("Fish_Skeleton", [("arch", 38.0)]),
    "glow_bone_rare": ("Fish_Skeleton", [("arch", -30.0)]),
    "glow_bone_epic": ("Fish_Skeleton", [("arch_s", 30.0)]),
}
CELLS = {"bone_%s_%s" % (k, s): fb.CELLS[k][i] for k in fb.CELLS for i, s in enumerate(fb.SIZES)}
# (the new broken ones, as Bones.CELLS has them: the hardly damaged as the whole, the pieces small)
for _i, _s in enumerate(fb.SIZES):
    CELLS["bone_cracked_" + _s] = fb.CELLS["whole"][_i]
    CELLS["bone_shard_" + _s] = [(1, 1), (1, 1), (2, 1), (2, 1)][_i]
for r in fb.GLOW:
    CELLS["glow_bone_" + r] = (2, 1)


def source(meshy_dir, name):
    for path in glob.glob(os.path.join(meshy_dir, "*.fbx")):
        base = os.path.basename(path)
        if "Meshy_AI_" not in base:
            continue
        stem = base.split("Meshy_AI_")[1]
        stem = stem.replace(".fbx", "")
        parts = stem.split("_2026")
        tag = parts[0] + (stem[stem.rfind("_generate") + 9:] if stem.rfind("_generate") >= 0 else "")
        if tag == name:
            return path
    raise SystemExit("no Meshy model %s in %s" % (name, meshy_dir))


def load(path):
    """The model, alone, its long side along y (head toward -y, as Meshy's are), LENGTH long."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    fs.only(meshes[0], *meshes[1:])
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in list(bpy.context.scene.objects):
        if o != ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.data.materials.clear()
    normalise(ob)
    return ob


def bounds(ob):
    co = [v.co for v in ob.data.vertices]
    lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    return lo, hi


def normalise(ob):
    """Centred on x, its head end at y 0, its foot at z 0, LENGTH long."""
    lo, hi = bounds(ob)
    k = LENGTH / (hi.y - lo.y)
    cx = (lo.x + hi.x) / 2
    for v in ob.data.vertices:
        v.co = Vector(((v.co.x - cx) * k, (v.co.y - lo.y) * k, (v.co.z - lo.z) * k))
    ob.data.update()


def solid(verts_top, nx, nz, far):
    """A closed slab: `verts_top` (an nx-by-nz grid, row-major), its back a copy moved by `far`."""
    bm = bmesh.new()
    top = [bm.verts.new(v) for v in verts_top]
    bot = [bm.verts.new(v + far) for v in verts_top]
    idx = lambda i, j: i * nz + j
    for i in range(nx - 1):
        for j in range(nz - 1):
            a, b, c, d = idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)
            bm.faces.new((top[a], top[b], top[c], top[d]))
            bm.faces.new((bot[d], bot[c], bot[b], bot[a]))
    ring = [idx(i, 0) for i in range(nx)] + [idx(nx - 1, j) for j in range(1, nz)] + \
        [idx(i, nz - 1) for i in range(nx - 2, -1, -1)] + [idx(0, j) for j in range(nz - 2, 0, -1)]
    for a, b in zip(ring, ring[1:] + ring[:1]):
        bm.faces.new((top[a], bot[a], bot[b], top[b]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("cutter")
    bm.to_mesh(me)
    bm.free()
    cut = bpy.data.objects.new("cutter", me)
    bpy.context.collection.objects.link(cut)
    return cut


def subtract(ob, cutter):
    mod = ob.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.use_hole_tolerant = True
    mod.object = cutter
    fs.only(ob)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)


def snap_end(ob, y, keep_front, seed):
    """Cut across at `y`, keeping the head's side (`keep_front`) or the tail's: the break jagged."""
    lo, hi = bounds(ob)
    nx, nz = 48, 48
    pts = []
    for i in range(nx):
        for j in range(nz):
            x = lo.x - 0.2 + (hi.x - lo.x + 0.4) * i / (nx - 1)
            z = lo.z - 0.2 + (hi.z - lo.z + 0.4) * j / (nz - 1)
            p = Vector((x * 9.0, z * 9.0, seed * 3.1))
            d = 0.035 * noise.fractal(p, 0.6, 2.2, 4) + 0.012 * noise.noise(p * 4.0)
            pts.append(Vector((x, y + d, z)))
    far = Vector((0, 3.0 if keep_front else -3.0, 0))
    subtract(ob, solid(pts, nx, nz, far))


def spine_line(ob, y0, y1, n=48):
    """Where the backbone runs between y0 and y1: for each of `n` stations, the height at which
    the bone is thickest across (x) at the middle - the vertebrae, not the thin ribs or spines."""
    bvh = BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    lo, hi = bounds(ob)
    out = []
    for k in range(n):
        y = y0 + (y1 - y0) * (k + 0.5) / n
        best, best_z = 0.0, None
        for m in range(140):
            z = lo.z + (hi.z - lo.z) * (m + 0.5) / 140
            # (the chord through x 0 along x: in at the first hit, out at the next)
            start, inside, chord = Vector((lo.x - 0.1, y, z)), False, 0.0
            enter = None
            for _ in range(12):
                loc, nrm, _i, _d = bvh.ray_cast(start, Vector((1, 0, 0)), 10.0)
                if loc is None:
                    break
                if not inside:
                    enter = loc.x
                else:
                    if enter <= 0.0 <= loc.x:
                        chord = loc.x - enter
                        break
                inside = not inside
                start = loc + Vector((1e-4, 0, 0))
            if chord > best:
                best, best_z = chord, z
        out.append((y, best_z, best))
    # (gaps filled from the neighbours, then smoothed)
    zs = [z for _y, z, _c in out]
    known = [i for i, z in enumerate(zs) if z is not None]
    for i in range(len(zs)):
        if zs[i] is None:
            j = min(known, key=lambda q: abs(q - i))
            zs[i] = zs[j]
    sm = [sorted(zs[max(0, i - 2):i + 3])[len(zs[max(0, i - 2):i + 3]) // 2] for i in range(len(zs))]
    return [(out[i][0], sm[i], out[i][2]) for i in range(len(zs))]


def box(x0, x1, y0, y1, z0, z1):
    bpy.ops.mesh.primitive_cube_add(location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    b = bpy.context.active_object
    b.scale = ((x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return b


def knock(ob, share, seed, below):
    """Knock off about `share` of the ribs (`below`) or of the spines above: in short stretches along
    the backbone, everything beyond a little way from it gone - the ribs left as snapped stubs."""
    rng = random.Random(seed)
    lo, hi = bounds(ob)
    # (not into the tail's fin)
    line = spine_line(ob, lo.y + 0.03, lo.y + 0.8 * (hi.y - lo.y))
    thick = sorted(c for _y, _z, c in line)[len(line) // 2]
    step = (line[1][0] - line[0][0])
    boxes = []
    k = 0
    while k < len(line):
        run = rng.randint(2, 4)
        seg = line[k:k + run]
        if rng.random() < share and seg:
            # (one box a stretch, a hair short of the next: boxes that touch confuse the cut)
            y0, y1 = seg[0][0] - step / 2 + 0.004, seg[-1][0] + step / 2 - 0.004
            gap = thick * rng.uniform(1.0, 2.6)
            if below:
                boxes.append(box(lo.x - 0.5, hi.x + 0.5, y0, y1, lo.z - 0.5, min(z for _y, z, _c in seg) - gap))
            else:
                boxes.append(box(lo.x - 0.5, hi.x + 0.5, y0, y1, max(z for _y, z, _c in seg) + gap + thick, hi.z + 0.5))
        k += run
    if not boxes:
        return
    fs.only(boxes[0], *boxes[1:])
    bpy.ops.object.join()
    subtract(ob, bpy.context.view_layer.objects.active)


def split(ob, at, gap, tilt, seed):
    """Broken in two at `at` (a share of the length from the head end): a thin jagged slice taken
    out across, then the back piece moved `gap` (a share of the length) further back, turned `tilt`
    degrees in its own plane and dropped a little - two pieces lying apart."""
    lo, hi = bounds(ob)
    y = lo.y + (hi.y - lo.y) * at
    nx, nz = 48, 48
    pts = []
    for i in range(nx):
        for j in range(nz):
            x = lo.x - 0.2 + (hi.x - lo.x + 0.4) * i / (nx - 1)
            z = lo.z - 0.2 + (hi.z - lo.z + 0.4) * j / (nz - 1)
            p = Vector((x * 9.0, z * 9.0, seed * 2.3))
            pts.append(Vector((x, y + 0.03 * noise.fractal(p, 0.6, 2.2, 4), z)))
    subtract(ob, solid(pts, nx, nz, Vector((0, 0.012, 0))))
    pivot = Vector((0, y, (lo.z + hi.z) / 2))
    a = math.radians(tilt)
    shift = Vector((0, gap * (hi.y - lo.y), -0.02 * (hi.z - lo.z)))
    # (each loose piece moved whole, by which side of the break its middle lies: the break is
    # jagged, so a piece behind it can reach forward past the line - moved point by point it would
    # be torn, its faces stretched across the gap)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen = set()
    for v0 in bm.verts:
        if v0 in seen:
            continue
        piece, stack = [v0], [v0]
        seen.add(v0)
        while stack:
            u = stack.pop()
            for e in u.link_edges:
                w = e.other_vert(u)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
                    piece.append(w)
        if sum(v.co.y for v in piece) / len(piece) > y:
            for v in piece:
                d = v.co - pivot
                v.co = pivot + Vector((d.x, d.y * math.cos(a) - d.z * math.sin(a), d.y * math.sin(a) + d.z * math.cos(a))) + shift
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def bite(ob, fy, fz, size, seed):
    """A jagged chunk knocked out at (fy, fz) - shares of the length and the height - `size` a share
    of the length across, right through side to side (a jaw broken off, a fin, a corner of skull)."""
    lo, hi = bounds(ob)
    c = Vector((0.0, lo.y + (hi.y - lo.y) * fy, lo.z + (hi.z - lo.z) * fz))
    r = size * (hi.y - lo.y)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=1.0, location=(0, 0, 0))
    cut = bpy.context.active_object
    for v in cut.data.vertices:
        n = v.co.normalized()
        k = 1.0 + 0.35 * noise.fractal(n * 3.0 + Vector((seed, 0, 0)), 0.6, 2.2, 3)
        v.co = Vector((n.x * (hi.x - lo.x + 0.4), n.y * r * k, n.z * r * k)) + c
    cut.data.update()
    subtract(ob, cut)


def arch(ob, curve):
    """Bent in its own plane (y-z) along its length: `curve(t)` the turn (radians a unit length) at
    t (0 the head end .. 1 the tail's) - the backbone a smooth bow, each point carried with it."""
    lo, hi = bounds(ob)
    zc = (lo.z + hi.z) / 2
    n = 400
    pts, ang = [Vector((0.0, lo.y, zc))], 0.0
    angs = [0.0]
    ds = (hi.y - lo.y) / n
    for i in range(n):
        ang += curve((i + 0.5) / n) * ds
        pts.append(pts[-1] + Vector((0.0, math.cos(ang), math.sin(ang))) * ds)
        angs.append(ang)
    for v in ob.data.vertices:
        f = min(n, max(0.0, (v.co.y - lo.y) / ds))
        i = min(n - 1, int(f))
        t = f - i
        c = pts[i].lerp(pts[i + 1], t)
        a = angs[i] + (angs[i + 1] - angs[i]) * t
        h = v.co.z - zc
        v.co = Vector((v.co.x, c.y - math.sin(a) * h, c.z + math.cos(a) * h))
    ob.data.update()
    normalise(ob)


def keep_main(ob, share=0.04):
    """After cutting: the bits a cut left hanging free (a rib's lower end, its top cut away) gone -
    every piece under `share` of the biggest's volume."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen, pieces = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        piece, stack = [f], [f]
        seen.add(f)
        while stack:
            a = stack.pop()
            for e in a.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g)
                        stack.append(g)
                        piece.append(g)
        pieces.append((sum(g.calc_center_median().dot(g.normal) * g.calc_area() for g in piece) / 3.0, piece))
    big = max(v for v, _p in pieces)
    drop = [f for v, p in pieces if v < share * big for f in p]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def shells_out(ob, smallest=200):
    """Only what's bone kept: the closed pockets a fine voxel grain seals inside it (each its own
    shell, turned inward) gone, and loose crumbs. Unlike make_fish_skeleton.outer_only, more than
    one piece may stay (a skeleton broken in two)."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    seen, drop = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        piece, stack = [f], [f]
        seen.add(f)
        while stack:
            a = stack.pop()
            for e in a.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g)
                        stack.append(g)
                        piece.append(g)
        vol = sum(g.calc_center_median().dot(g.normal) * g.calc_area() for g in piece) / 3.0
        if vol <= 0.0 or len(piece) < smallest:
            drop += piece
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def lay_flat(ob):
    """As the game's bones lie: head toward +x, its back toward +y (up in the bag's picture, which
    looks down), its side on the ground (z 0), GAME_LENGTH long, centred."""
    lo, hi = bounds(ob)
    k = GAME_LENGTH / (hi.y - lo.y)
    cy, cz = (lo.y + hi.y) / 2, (lo.z + hi.z) / 2
    for v in ob.data.vertices:
        x, y, z = v.co
        v.co = Vector((-(y - cy) * k, (z - cz) * k, -x * k))
    ob.data.update()
    lo, hi = bounds(ob)
    for v in ob.data.vertices:
        v.co.z -= lo.z
    ob.data.update()


def tint(img_path, rgb, out_path):
    """A glowing bone's colour: the bone's, washed with its rarity's."""
    from PIL import Image
    im = Image.open(img_path).convert("RGB")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            v = 0.2 + 0.7 * lum
            px[x, y] = tuple(int(min(255, 255 * v * (0.3 + 0.7 * c))) for c in rgb)
    im.save(out_path)


def seed(name):
    return sum(map(ord, name)) % 97


def make(name, meshy_dir, work):
    model, cuts = BONES[name]
    ob = load(source(meshy_dir, model))
    # (fused into one closed surface first: Meshy's own isn't watertight, and cuts through it come
    # out as rubbish)
    fs.apply(ob, "REMESH", mode="VOXEL", voxel_size=VOXEL, adaptivity=0.0)
    shells_out(ob)
    for c in cuts:
        if c[0] == "keep":
            _k, a, b = c
            if a > 0.0:
                snap_end(ob, LENGTH * a, False, seed(name))
            if b < 1.0:
                snap_end(ob, LENGTH * b, True, seed(name) + 7)
            normalise(ob)
        elif c[0] == "ribs":
            knock(ob, c[1], c[2], below=True)
        elif c[0] == "spines":
            knock(ob, c[1], c[2], below=False)
        elif c[0] == "split":
            split(ob, c[1], c[2], c[3], seed(name) + 3)
        elif c[0] == "bite":
            bite(ob, c[1], c[2], c[3], c[4])
        elif c[0] == "arch":
            deg = c[1]
            arch(ob, lambda t: math.radians(deg) / LENGTH)
        elif c[0] == "arch_s":
            deg = c[1]
            arch(ob, lambda t: math.radians(deg) / LENGTH * 2.2 * math.sin(2 * math.pi * t))
    if any(c[0] in ("keep", "ribs", "spines", "split", "bite") for c in cuts):
        keep_main(ob)
    normalise(ob)
    # (the detailed surface: fused, the pockets out)
    high = ob
    high.name = name + "_detail"
    fs.apply(high, "SMOOTH", factor=0.3, iterations=1)
    shells_out(high)
    # (the game model)
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.collection.objects.link(low)
    fs.apply(low, "REMESH", mode="VOXEL", voxel_size=LOW_VOXEL, adaptivity=0.0)
    fs.apply(low, "SMOOTH", factor=0.4, iterations=1)
    shells_out(low)
    fs.apply(low, "DECIMATE", ratio=min(1.0, TRIS / max(1, len(low.data.polygons) * 2)))
    shells_out(low, smallest=40)
    fs.unwrap(low, TEX)
    fs.only(low)
    bpy.ops.object.shade_smooth()
    color, normal = fs.bake_textures(high, low, work, prefix=name, tex=TEX, cage=0.015, reach=0.045)
    bpy.data.objects.remove(high)
    glow = name[len("glow_bone_"):] if name.startswith("glow_bone_") else None
    if glow:
        tinted = os.path.join(work, name + "_tinted.png")
        tint(color.filepath_raw, fb.GLOW[glow], tinted)
        color = bpy.data.images.load(tinted)
    mat = fs.textured_material(color, normal)
    mat.name = name
    if glow:
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Emission Color"].default_value = (*fb.GLOW[glow], 1.0)
        # (lit from within, but not so it washes out the bone's own shading)
        bsdf.inputs["Emission Strength"].default_value = 0.3
    low.data.materials.clear()
    low.data.materials.append(mat)
    lay_flat(low)
    fs.only(low)
    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    bpy.ops.export_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"), export_format="GLB", use_selection=True,
                              export_image_format="JPEG", export_jpeg_quality=90, export_tangents=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, name + ".blend"))
    fb.picture(low, CELLS[name], os.path.join(PICS, name + ".png"), glow)
    print("made %s from %s: %d tris" % (name, model, tris), flush=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    meshy_dir, names = args[0], args[1:] or list(BONES)
    work = os.path.normpath(meshy_dir) + "_work"
    os.makedirs(work, exist_ok=True)
    for name in names:
        make(name, meshy_dir, work)
    os._exit(0)


if __name__ == "__main__":
    main()
