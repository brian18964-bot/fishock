"""The human world's villages' own trees, made from the user's tree pack (Trees.fbx - "Fbx.zip"; user
request: "中國風第 11 章、補強日式" - the Chinese village's willows by the water, the Japanese village's
cherry and red maples; "素材都要經過你再製，成為我們的資產": the upload itself is never committed, only
what this makes).

Each tree two surfaces, as the camp's trees have (CampModel's families): "bark" and "leaves", their
pictures <family>_bark.png and <family>_leaves.png made here too.

  - the bark: the trunk and the boughs made anew as light tubes along the pack's (rebuild_bark - its
    finest twigs go, the leaves hiding where they were), its picture the pack's bark toned ours
    (greyer, a little warmer, darker);
  - the leaves: the pack's leaves are single leaves on small cards, tens of thousands of them - too
    many for the game. A share of the cards is kept (LEAF_CARDS of them), each drawn larger
    (SPRAY_GROW), and its picture is a spray of ours: the pack's leaf (or leaves - a maple's four
    kinds, a cherry's leaf and blossom) stamped many times over at their own turns and sizes onto one
    card (droop: hanging, as a willow's strands do), so a card now carries what many did; toned ours.
    No leaf hangs lower than LOWEST m (the camp's rule: the lowest branches clear the big ghost);
  - stood on its trunk's foot at the origin, HIGH m tall.

  bpyenv/bin/python tools/make_village_trees.py -- Trees.fbx

writes assets/models/camp/<kind>.glb and the families' pictures, and prints each tree's trunk radius at
the ground, its reach and its lowest leaf (for MapTree.KINDS, CANOPY).
"""
import math
import os
import random
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CAMP = os.path.join(ROOT, "assets", "models", "camp")
SRC = sys.argv[sys.argv.index("--") + 1]
ONLY = [s for s in os.environ.get("ONLY", "").split(",") if s]

# kind: (the pack's tree, its family, height m, how many leaf cards, seed, mirrored)
TREES = {
    "willow_a": ("Weeping_Willow", "willow_tree", 10.5, 3200, 3, False),
    "willow_b": ("Weeping_Willow", "willow_tree", 9.2, 2800, 7, True),
    "cherry_a": ("Japan_Cherry", "cherry_tree", 7.6, 3000, 11, False),
    "maple_a": ("Red_Maple", "maple_tree", 9.0, 3000, 13, False),
    "gmaple_a": ("Green_Maple", "green_maple_tree", 9.0, 3000, 17, False),
    "birch_a": ("White_Birch", "birch_tree", 11.0, 2800, 19, False),
}
# Each family's leaves: which of the pack's leaf pictures go into its spray (by the pack's material),
# how many stamps a card, the stamps' size (share of the card), whether they hang; its tone (a tint
# over the pack's, how much less saturated).
SPRAYS = {
    "willow_tree": {"mats": ["Leaveswillow"], "stamps": 16, "size": (0.32, 0.5), "droop": True,
                    "tint": (0.92, 1.0, 0.86), "grey": 0.12},
    "cherry_tree": {"mats": ["LeavesCherry", "FlowersCherry"], "stamps": 18, "size": (0.22, 0.36), "droop": False,
                    "tint": (1.0, 0.96, 0.97), "grey": 0.08},
    "maple_tree": {"mats": ["Leaves1", "Leaves2", "Leaves3", "Leaves4"], "stamps": 14, "size": (0.26, 0.4), "droop": False,
                   "tint": (1.0, 0.92, 0.88), "grey": 0.1},
    "green_maple_tree": {"mats": ["Leaves5"], "stamps": 14, "size": (0.26, 0.4), "droop": False,
                         "tint": (0.94, 1.0, 0.9), "grey": 0.12},
    "birch_tree": {"mats": ["LeavesCherry"], "stamps": 16, "size": (0.22, 0.34), "droop": False,
                   "tint": (0.96, 1.0, 0.88), "grey": 0.1},
}
TWIG_SPAN = 1.6
TRUNK_ROOM = 0.9
LONG_SPAN = 3.0
# (a bough no thicker than this share of its length (+2 cm); a kind's own: how low its boughs may
# hang (m) and how slim they are drawn - a willow's hanging strands are flat ribbons in the pack, read
# far too thick as tubes)
BOUGH_GIRTH = 0.02
BOUGHS = {"willow_tree": (1.8, 0.25)}
LONG_SEGS = 5
LONG_SIDES = 6
SHORT_SEGS = 2
SHORT_SIDES = 4
THIN_STEP = 0.25
SPRAY_GROW = 2.4
SPRAY_PX = 512
BARK_PX = 512
BARK_GREY = 0.2
BARK_TINT = (0.92, 0.88, 0.84)
LOWEST = 2.6

_made_pictures = set()


def clear_and_load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    import io_scene_fbx.import_fbx as fi
    fi.blen_read_light = lambda tmpl, obj, settings: bpy.data.lights.new(name="Light", type="POINT")
    bpy.ops.import_scene.fbx(filepath=SRC)
    bpy.context.view_layer.update()


def pixels(img):
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def base_picture(m):
    """The picture feeding a material's base colour."""
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
            return n.image
    return None


def save_rgba(arr, path):
    from PIL import Image
    Image.fromarray((np.clip(arr[::-1], 0, 1) * 255).astype(np.uint8), "RGBA").save(path, optimize=True)


def spray_picture(family, leaves):
    """Our spray: the family's leaf pictures (`leaves`: arrays, the pack's, each with its alpha)
    stamped over and over onto one card - each its own size and turn (hanging ones mostly downward),
    the later ones over the earlier; toned ours."""
    from PIL import Image
    spec = SPRAYS[family]
    rng = random.Random(len(family) * 31)
    card = Image.new("RGBA", (SPRAY_PX, SPRAY_PX), (0, 0, 0, 0))
    srcs = [Image.fromarray((np.clip(a[::-1], 0, 1) * 255).astype(np.uint8), "RGBA") for a in leaves]
    for k in range(spec["stamps"]):
        src = srcs[k % len(srcs)]
        s = int(SPRAY_PX * rng.uniform(*spec["size"]))
        leaf = src.resize((s, s), Image.LANCZOS)
        turn = rng.gauss(180.0, 22.0) if spec["droop"] else rng.uniform(0.0, 360.0)
        leaf = leaf.rotate(turn, resample=Image.BICUBIC, expand=True)
        x = int(rng.uniform(0.05, 0.95) * SPRAY_PX - leaf.size[0] / 2)
        y = int(rng.uniform(0.05, 0.95) * SPRAY_PX - leaf.size[1] / 2)
        card.alpha_composite(leaf, (max(-leaf.size[0] // 2, x), max(-leaf.size[1] // 2, y)))
    a = np.asarray(card).astype(np.float32) / 255.0
    rgb = a[..., :3]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    rgb = (rgb * (1 - spec["grey"]) + lum[..., None] * spec["grey"]) * np.array(spec["tint"], np.float32)
    # (the colour bled out under the clear parts, so the cut edge never shows a dark fringe)
    keep = a[..., 3] > 0.05
    mean = rgb[keep].mean(0) if keep.any() else np.array([0.2, 0.3, 0.1])
    rgb = np.where(keep[..., None], rgb, mean)
    out = np.concatenate([np.clip(rgb, 0, 1), a[..., 3:4]], -1)
    from PIL import Image as I
    I.fromarray((out * 255).astype(np.uint8), "RGBA").save(os.path.join(CAMP, family + "_leaves.png"), optimize=True)


def bark_picture(family, img):
    img.scale(BARK_PX, BARK_PX)
    a = pixels(img)
    rgb = a[..., :3]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    rgb = (rgb * (1 - BARK_GREY) + lum[..., None] * BARK_GREY) * np.array(BARK_TINT, np.float32)
    if family == "birch_tree":
        rgb = rgb * 1.05
    a = np.concatenate([np.clip(rgb, 0, 1), np.ones_like(a[..., :1])], -1)
    save_rgba(a, os.path.join(CAMP, family + "_bark.png"))


def thin(obj, most):
    bpy.context.view_layer.objects.active = obj
    while sum(len(p.vertices) - 2 for p in obj.data.polygons) > most:
        have = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        d = obj.modifiers.new("thin", "DECIMATE")
        d.ratio = max(most / have, THIN_STEP)
        d.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="thin")
        # (it stops where it can go no further - a twig can't be thinned to nothing)
        if sum(len(p.vertices) - 2 for p in obj.data.polygons) > have * 0.95:
            break


def tree(kind):
    src, family, high, cards, seed, mirrored = TREES[kind]
    print("tree", kind, flush=True)
    clear_and_load()
    print("  loaded", flush=True)
    root = bpy.data.objects[src]
    origin = root.matrix_world.translation.copy()
    parts = [root] + [o for o in bpy.data.objects if o.parent is root and o.type == "MESH"]
    spec = SPRAYS[family]
    # (the family's pictures, once: the spray from the pack's leaves, the bark toned)
    if family not in _made_pictures:
        leaves = []
        for o in parts[1:]:
            for m in o.data.materials:
                if m and any(m.name.startswith(k) for k in spec["mats"]):
                    img = base_picture(m)
                    if img is not None and all(img.name != l[0] for l in leaves):
                        leaves.append((img.name, pixels(img).copy()))
        spray_picture(family, [l[1] for l in leaves])
        bark_picture(family, base_picture(root.data.materials[0]))
        _made_pictures.add(family)
    for o in list(bpy.context.scene.objects):
        if o not in parts:
            bpy.data.objects.remove(o)
    for o in parts:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # The bark alone, thinned; the leaves' cards (one object), a share of them kept.
    bark = root
    leaf_objs = [o for o in parts[1:] if spec["mats"] and any(m and any(m.name.startswith(k) for k in spec["mats"]) for m in o.data.materials)]
    for o in parts[1:]:
        if o not in leaf_objs:
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in leaf_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = leaf_objs[0]
    if len(leaf_objs) > 1:
        bpy.ops.object.join()
    leaf = bpy.context.view_layer.objects.active
    # (the trunk's foot: the pack's tree's own origin - its place, on the ground; scaled to its height)
    pts = np.array([v.co[:] for v in bark.data.vertices])
    mid = Vector((origin.x, origin.y, 0.0))
    top = max(pts[:, 2].max(), max(v.co.z for v in leaf.data.vertices))
    k = high / top
    for o in (bark, leaf):
        for v in o.data.vertices:
            v.co = (v.co - mid) * k
            if mirrored:
                v.co.x = -v.co.x
        if mirrored:
            o.data.flip_normals()
    rebuild_bark(bark, family)
    print("  bark", sum(len(p.vertices) - 2 for p in bark.data.polygons), flush=True)
    keep_cards(leaf, cards, seed, BOUGHS.get(family, (LOWEST, 1.0))[0])
    print("  leaves", len(leaf.data.polygons), flush=True)
    # One object, two surfaces named as CampModel knows them.
    mb = bpy.data.materials.new("bark")
    ml = bpy.data.materials.new("leaves")
    bark.data.materials.clear()
    bark.data.materials.append(mb)
    leaf.data.materials.clear()
    leaf.data.materials.append(ml)
    # (one UV layer each, the same name, so they join into one)
    for o, keep in ((bark, bark.data.uv_layers.active.name), (leaf, leaf.data.uv_layers.active.name)):
        for uv in list(o.data.uv_layers):
            if uv.name != keep:
                o.data.uv_layers.remove(uv)
        o.data.uv_layers[0].name = "UVMap"
    bpy.ops.object.select_all(action="DESELECT")
    bark.select_set(True)
    leaf.select_set(True)
    bpy.context.view_layer.objects.active = bark
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = kind
    measure(kind, obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(CAMP, kind + ".glb"), export_format="GLB", use_selection=True,
                              export_apply=True, export_image_format="NONE")


def rebuild_bark(bark, family):
    """The trunk and the boughs made anew, light: the pack's are thousands of loose little tubes,
    which thinned only flatten into ribbons. Each piece spanning TWIG_SPAN m or more becomes a tube
    of ours along it - its middle and its girth read slice by slice along its length (a long one
    LONG_SIDES-sided in LONG_SEGS slices, a short one SHORT_SIDES in SHORT_SEGS) - the bark's picture
    wrapped round it; the twigs (the shorter pieces) go, the leaves hiding where they were, and so
    does whatever hangs lower than LOWEST further than TRUNK_ROOM m out from the trunk (a willow's
    strands)."""
    me = bark.data
    lowest, slim = BOUGHS.get(family, (LOWEST, 1.0))
    pts_all = np.array([v.co[:] for v in me.vertices])
    parent = np.arange(len(me.vertices))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for e in me.edges:
        a, b = find(e.vertices[0]), find(e.vertices[1])
        if a != b:
            parent[a] = b
    roots = np.array([find(i) for i in range(len(me.vertices))])
    order = np.argsort(roots)
    cuts = np.flatnonzero(np.diff(roots[order])) + 1
    groups = np.split(order, cuts)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    made = 0
    for idx in groups:
        pts = pts_all[idx]
        span = float(np.linalg.norm(pts.max(0) - pts.min(0)))
        if span < TWIG_SPAN:
            continue
        low = pts[:, 2].min()
        if pts[:, 2].max() < lowest and float(np.hypot(pts[:, 0], pts[:, 1]).min()) > TRUNK_ROOM:
            continue
        # (the trunk: the piece standing on the ground at the tree's foot - its girth as it is; the
        # rest each as slim as the tree's kind has them, never thicker than its length allows)
        trunk = low < 0.3 and float(np.hypot(*pts[np.argmin(pts[:, 2])][:2])) < TRUNK_ROOM
        c = pts.mean(0)
        w, vecs = np.linalg.eigh(np.cov((pts - c).T))
        axis = vecs[:, -1]
        if axis[2] < 0.0:
            axis = -axis
        t = (pts - c) @ axis
        t0, t1 = t.min(), t.max()
        longer = span >= LONG_SPAN
        segs = LONG_SEGS if longer else SHORT_SEGS
        sides = LONG_SIDES if longer else SHORT_SIDES
        rings = []
        for k in range(segs + 1):
            at = t0 + (t1 - t0) * k / segs
            near = np.abs(t - at) <= (t1 - t0) / (2.0 * segs) + 1e-4
            sl = pts[near] if near.sum() >= 3 else pts[np.argsort(np.abs(t - at))[:6]]
            mid = sl.mean(0)
            off = sl - mid
            off = off - np.outer(off @ axis, axis)
            r = float(np.median(np.linalg.norm(off, axis=1))) if len(off) else 0.02
            if not trunk:
                r = min(r * slim, BOUGH_GIRTH * span + 0.02)
            rings.append((mid, max(r, 0.015)))
        # (the frame round the tube's axis)
        ref = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = np.cross(axis, ref)
        u /= np.linalg.norm(u)
        v2 = np.cross(axis, u)
        verts = []
        for mid, r in rings:
            verts.append([bm.verts.new(tuple(mid + (u * math.cos(a) + v2 * math.sin(a)) * r))
                          for a in [j / sides * math.tau for j in range(sides)]])
        girth = max(sum(r for _m, r in rings) / len(rings) * math.tau, 0.05)
        along = 0.0
        for k in range(segs):
            step = float(np.linalg.norm(rings[k + 1][0] - rings[k][0]))
            for j in range(sides):
                f = bm.faces.new((verts[k][j], verts[k][(j + 1) % sides], verts[k + 1][(j + 1) % sides], verts[k + 1][j]))
                for l, (a, b) in zip(f.loops, [(j, along), (j + 1, along), (j + 1, along + step), (j, along + step)]):
                    l[uv].uv = (a / sides, b / girth)
            along += step
        made += 1
    me2 = bpy.data.meshes.new("bark_new")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    bm.to_mesh(me2)
    bm.free()
    old = bark.data
    bark.data = me2
    bpy.data.meshes.remove(old)
    print("  boughs", made, flush=True)


def keep_cards(leaf, cards, seed, lowest):
    """`cards` of the leaf cards kept (none below LOWEST), each grown SPRAY_GROW about its middle,
    its picture the whole spray (its UVs spread over the card)."""
    bm = bmesh.new()
    bm.from_mesh(leaf.data)
    bm.faces.ensure_lookup_table()
    uv = bm.loops.layers.uv.active
    # (a card: the faces joined to one another - a leaf's quad, or a pair of triangles)
    seen = set()
    islands = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack = [f]
        group = []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        islands.append(group)
    rng = random.Random(seed)
    mids = []
    for g in islands:
        vs = {v for f in g for v in f.verts}
        c = sum((v.co for v in vs), Vector()) / len(vs)
        mids.append(c)
    ok = [i for i, c in enumerate(mids) if c.z >= lowest]
    rng.shuffle(ok)
    keep = set(ok[:cards])
    gone = []
    for i, g in enumerate(islands):
        if i not in keep:
            gone.extend(g)
            continue
        vs = {v for f in g for v in f.verts}
        c = mids[i]
        grow = SPRAY_GROW * rng.uniform(0.85, 1.15)
        for v in vs:
            v.co = c + (v.co - c) * grow
        # (the spray over the whole card, its top up: the card's corners laid out across it by where
        # they are - along the card level and up it - whatever the pack's own UVs were)
        n = sum((f.normal for f in g), Vector())
        n = n.normalized() if n.length > 1e-6 else Vector((0.0, 1.0, 0.0))
        across = n.cross(Vector((0.0, 0.0, 1.0)))
        across = across.normalized() if across.length > 1e-3 else Vector((1.0, 0.0, 0.0))
        up = across.cross(n).normalized()
        if up.z < 0.0:
            up = -up
        xs = [(v.co - c).dot(across) for v in vs]
        ys = [(v.co - c).dot(up) for v in vs]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        for f in g:
            for l in f.loops:
                d = l.vert.co - c
                l[uv].uv = Vector(((d.dot(across) - x0) / max(x1 - x0, 1e-6), (d.dot(up) - y0) / max(y1 - y0, 1e-6)))
    bmesh.ops.delete(bm, geom=list({f for f in gone}), context="FACES")
    bm.to_mesh(leaf.data)
    bm.free()


def measure(kind, o):
    me = o.data
    leafy = set()
    for p in me.polygons:
        if me.materials[p.material_index].name.startswith("leaves"):
            leafy.update(p.vertices)
    reach, foot_r, lo_leaf = 0.0, 0.0, 1e9
    rs = []
    for v in me.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if v.index in leafy:
            lo_leaf = min(lo_leaf, v.co.z)
            rs.append(r)
        elif v.co.z < 0.3:
            foot_r = max(foot_r, r)
    reach = float(np.percentile(rs, 92)) if rs else 0.0
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("made %s tris %d foot_r %.2f reach %.2f lowest_leaf %.2f high %.2f" % (
        kind, tris, foot_r, reach, lo_leaf, max(v.co.z for v in me.vertices)), flush=True)


for kind in TREES:
    if ONLY and kind not in ONLY:
        continue
    tree(kind)
