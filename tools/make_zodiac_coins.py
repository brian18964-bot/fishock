"""The twelve zodiac coins - the altar's rarest reward (user request) - made our own from a set the user
gave (a high-poly coin per sign, its relief in the mesh, a picture of both faces per coin). The
originals are never committed; only what this makes (user request: "素材都要經過你再製，成為我們的資產").

What's ours (user request: not so round, 1.5 times as thick, none of the little stars):
  - each coin a new, light mesh: an outline of its own, uneven as a struck old coin's (no two alike),
    its edge bevelled, 1.5 times the original's thickness;
  - the relief baked off the original's mesh into a height map, both faces, and a normal map made
    from it for the new coin;
  - the little stars and diamonds scattered round each figure found (small dark marks off the figure
    and the rim) and painted out of the picture and the relief alike;
  - the picture re-toned: an old gold, its hollows darkened and its high places worn bright from the
    relief; outside the struck face, the rim's own colour;
  - a picture for the bag (the face, cut to the coin's outline, lit by its relief) and a square one
    for the slots.

    bpyenv/bin/python tools/make_zodiac_coins.py -- Zodiac.fbx TEXTURES_DIR OUT_MODELS OUT_ICONS OUT_SQUARE [DEBUG_DIR]

writes OUT_MODELS/zodiac_NN.glb, OUT_ICONS/zodiac_NN.png, OUT_SQUARE/zodiac_NN.png (NN 01..12, Aries first).
"""
import math
import os
import sys

import bpy
import bmesh
import cv2
import numpy as np
from mathutils import Vector
from scipy.interpolate import griddata

args = sys.argv[sys.argv.index("--") + 1:]
FBX, TEX, OUT_MODELS, OUT_ICONS, OUT_SQUARE = args[:5]
DEBUG = args[5] if len(args) > 5 else ""

WORK = 1024          # the pictures worked on at this size
OUT_TEX = 512        # and kept at this
THICK = 1.5          # x the original's thickness
SEGMENTS = 96        # round its outline
RINGS = 7            # rings across each face
BEVEL = 0.035        # of the radius, the edge's bevel
RELIEF = 2.2         # how strongly the relief shows in the normal map (it's a small thing on screen)
# (a mark is a star if it's this many px at WORK and lies this far off the figure and the rim)
STAR_AREA = (10, 700)
OFF_FIGURE = 7
GOLD = np.array([0.80, 0.62, 0.30], dtype=np.float32)


def log(*a):
    print("ZODIAC", *a, flush=True)


# ---------------------------------------------------------------- reading the original

def load_coins():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=FBX)
    coins = {}
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith("z"):
            coins[int(o.name[1:3])] = o
    return coins


def sample(obj):
    """Its faces' points: front and back, each (xy about the coin's middle, z, uv)."""
    me = obj.data
    mw = obj.matrix_world
    uv = me.uv_layers.active.data
    co = np.array([(mw @ v.co)[:] for v in me.vertices], dtype=np.float64)
    nz = np.array([(mw.to_3x3() @ v.normal).normalized().z for v in me.vertices])
    vuv = np.zeros((len(me.vertices), 2))
    cnt = np.zeros(len(me.vertices))
    for loop in me.loops:
        vuv[loop.vertex_index] += uv[loop.index].uv
        cnt[loop.vertex_index] += 1
    vuv /= np.maximum(cnt, 1)[:, None]
    # (only the points its faces use - one of the meshes carries a million loose ones besides)
    used = cnt > 0
    co, nz, vuv = co[used], nz[used], vuv[used]
    # (the coin's own: where its points crowd, within its round)
    hist, xe, ye = np.histogram2d(co[:, 0], co[:, 1], bins=160)
    i, j = np.unravel_index(hist.argmax(), hist.shape)
    xy_mid = np.array([(xe[i] + xe[i + 1]) / 2, (ye[j] + ye[j + 1]) / 2])
    for _ in range(6):
        near = np.linalg.norm(co[:, :2] - xy_mid, axis=1) < 1.2
        xy_mid = (co[near, :2].min(0) + co[near, :2].max(0)) / 2
    keep = np.linalg.norm(co[:, :2] - xy_mid, axis=1) < 1.15
    keep &= np.abs(co[:, 2] - np.median(co[keep, 2])) < 0.12
    co, nz, vuv = co[keep], nz[keep], vuv[keep]
    lo, hi = co[:, :2].min(0), co[:, :2].max(0)
    mid = (lo + hi) / 2
    zmid = np.median(co[:, 2])
    front = (nz > 0.5) & (co[:, 2] > zmid)
    back = (nz < -0.5) & (co[:, 2] < zmid)
    radius = float(np.max(np.linalg.norm(co[:, :2] - mid, axis=1)))
    thick = float(co[:, 2].max() - co[:, 2].min())
    return {"xy": co[:, :2] - mid, "z": co[:, 2], "uv": vuv, "front": front, "back": back,
            "radius": radius, "thick": thick, "zmid": zmid}


def fit_uv(xy, uv):
    """uv = [x y 1] @ M (least squares)."""
    a = np.hstack([xy, np.ones((len(xy), 1))])
    m, *_ = np.linalg.lstsq(a, uv, rcond=None)
    return m


def to_uv(m, xy):
    return np.hstack([xy, np.ones((len(xy), 1))]) @ m


def px(uv):
    """uv -> (col, row) at WORK (v up)."""
    return np.stack([uv[:, 0] * WORK, (1.0 - uv[:, 1]) * WORK], axis=1)


def height_map(s, side, m):
    sel = s[side]
    z = s["z"][sel]
    base = np.percentile(z, 5) if side == "front" else np.percentile(z, 95)
    h = (z - base) if side == "front" else (base - z)
    p = px(s["uv"][sel])
    gx, gy = np.meshgrid(np.arange(WORK) + 0.5, np.arange(WORK) + 0.5)
    hm = griddata(p, h, (gx, gy), method="linear", fill_value=0.0).astype(np.float32)
    return hm


def face_circle(m, radius):
    """The struck face's round in the picture: its middle (px) and radius (px)."""
    c = px(to_uv(m, np.zeros((1, 2))))[0]
    e = px(to_uv(m, np.array([[radius, 0.0]])))[0]
    return c, float(np.linalg.norm(e - c))


# ---------------------------------------------------------------- the stars

def star_mask(h, circles):
    """The little stars: in the relief, small raised marks standing alone - not part of the figure
    (nor inside it: its fleece, its scales) and not the rim."""
    inside = np.zeros(h.shape, np.uint8)
    for c, r in circles:
        cv2.circle(inside, (int(c[0]), int(c[1])), int(r * 0.92), 1, -1)
    ground = cv2.morphologyEx(h, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31)))
    top = (h - ground) * inside
    thr = 0.28 * np.percentile(top[inside > 0], 99.5)
    raised = (top > thr).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(raised, connectivity=8)
    figure = np.zeros_like(raised)
    small = []
    for i in range(1, n):
        a = stats[i, cv2.CC_STAT_AREA]
        w, hh = stats[i, cv2.CC_STAT_WIDTH], stats[i, cv2.CC_STAT_HEIGHT]
        span = max(w, hh)
        ring = any(span > 1.2 * r for _, r in circles)
        if ring:
            continue
        if a > STAR_AREA[1] or span > 46:
            comp = (lab == i).astype(np.uint8)
            # (the figure filled in: what's inside its outline is part of it)
            cs, _ = cv2.findContours(comp, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            cv2.drawContours(figure, cs, -1, 1, -1)
        elif a >= STAR_AREA[0]:
            small.append(i)
    near = cv2.dilate(figure, np.ones((2 * OFF_FIGURE + 1, 2 * OFF_FIGURE + 1), np.uint8))
    mask = np.zeros_like(raised)
    for i in small:
        comp = lab == i
        if not near[comp].any():
            mask[comp] = 1
    # (each star whole and a little round it - its outline in the picture too); and the ground under
    # them (the relief without its small raised marks), to fill them with
    return cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))), ground


# ---------------------------------------------------------------- our coin

def outline(seed):
    """Its outline: radius by angle - uneven, as a struck old coin's."""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, math.tau, 4)
    amp = rng.uniform(0.6, 1.0, 4) * np.array([0.035, 0.022, 0.014, 0.008])
    th = np.linspace(0, math.tau, SEGMENTS, endpoint=False)
    k = 1.0 + amp[0] * np.sin(2 * th + ph[0]) + amp[1] * np.sin(3 * th + ph[1]) + amp[2] * np.sin(5 * th + ph[2]) \
        + amp[3] * np.sin(9 * th + ph[3])
    # (a flat bit, where the strike ran off the blank)
    cut = rng.uniform(0, math.tau)
    k -= 0.03 * np.clip(np.cos(th - cut) - 0.85, 0, None) / 0.15
    return th, np.clip(k, 0.93, 1.05)


def build_mesh(name, s, mf, mb, seed):
    th, k = outline(seed)
    R = s["radius"] * 0.985
    half = s["thick"] * THICK / 2.0
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rings = {}
    for side, zs, m in (("f", 1.0, mf), ("b", -1.0, mb)):
        centre = bm.verts.new((0.0, 0.0, zs * half))
        rows = []
        for j in range(1, RINGS + 1):
            t = j / RINGS
            row = []
            for i in range(SEGMENTS):
                rr = R * k[i] * (t if j < RINGS else 1.0 - BEVEL)
                z = zs * half if j < RINGS else zs * half * 0.82
                row.append(bm.verts.new((rr * math.cos(th[i]), rr * math.sin(th[i]), z)))
            rows.append(row)
        edge = [bm.verts.new((R * k[i] * math.cos(th[i]), R * k[i] * math.sin(th[i]), zs * half * 0.55)) for i in range(SEGMENTS)]
        rings[side] = (centre, rows, edge, m)
    bm.verts.ensure_lookup_table()

    def uv_of(v, m):
        u = to_uv(m, np.array([[v.co.x, v.co.y]]))[0]
        return (float(u[0]), float(u[1]))

    def face(vs, m, flip):
        vs = list(reversed(vs)) if flip else vs
        f = bm.faces.new(vs)
        for loop in f.loops:
            loop[uvl].uv = uv_of(loop.vert, m)
        return f

    for side, (centre, rows, edge, m) in rings.items():
        flip = side == "b"
        for i in range(SEGMENTS):
            n = (i + 1) % SEGMENTS
            face([centre, rows[0][i], rows[0][n]], m, flip)
            for j in range(RINGS - 1):
                face([rows[j][i], rows[j + 1][i], rows[j + 1][n], rows[j][n]], m, flip)
            face([rows[-1][i], edge[i], edge[n], rows[-1][n]], m, flip)
    # The rim between the two faces' edges (the front's rim colour along it).
    ef, eb = rings["f"][2], rings["b"][2]
    for i in range(SEGMENTS):
        n = (i + 1) % SEGMENTS
        f = bm.faces.new([ef[i], eb[i], eb[n], ef[n]])
        for loop in f.loops:
            p = loop.vert.co
            d = Vector((p.x, p.y)).normalized() * R * 0.96
            u = to_uv(mf, np.array([[d.x, d.y]]))[0]
            loop[uvl].uv = (float(u[0]), float(u[1]))
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    # (a metre across, standing on its face)
    s_k = 1.0 / (2 * R * 1.05)
    obj.scale = (s_k, s_k, s_k)
    return obj, th, k


# ---------------------------------------------------------------- pictures

def normal_from(h, m):
    world_per_px = 1.0 / (WORK * np.linalg.norm(m[:2, 0]))
    gx = cv2.Sobel(h, cv2.CV_32F, 1, 0, ksize=3) / 8.0 / world_per_px
    gy = -cv2.Sobel(h, cv2.CV_32F, 0, 1, ksize=3) / 8.0 / world_per_px
    n = np.dstack([-gx * RELIEF, -gy * RELIEF, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def retone(rgb, h, circles):
    f = rgb.astype(np.float32) / 255.0
    lum = f @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    hs = cv2.GaussianBlur(h, (0, 0), 1.2)
    lo, hi = np.percentile(hs, 3), np.percentile(hs, 97)
    hn = np.clip((hs - lo) / max(hi - lo, 1e-6), 0, 1)
    gold = (lum / max(np.percentile(lum, 95), 1e-3))[..., None] * GOLD
    out = gold * (0.72 + 0.4 * hn[..., None])
    # (outside the struck face: the rim's colour, so an outline wider than the face shows the rim)
    yy, xx = np.mgrid[0:WORK, 0:WORK]
    face = np.zeros((WORK, WORK), bool)
    for c, r in circles:
        face |= (xx - c[0]) ** 2 + (yy - c[1]) ** 2 < (r * 0.985) ** 2
    rim = np.median(out[face].reshape(-1, 3), axis=0) * 0.85
    out[~face] = rim
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)


def save_tex(img, path):
    small = cv2.resize(img, (OUT_TEX, OUT_TEX), interpolation=cv2.INTER_AREA)
    cv2.imwrite(path, cv2.cvtColor(small, cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 88])


def icon(albedo, normal, c, r, th, k, size):
    """The front face cut to the coin's outline, lit by its relief, on nothing."""
    crop = 1.08
    x0, y0 = c[0] - r * crop, c[1] - r * crop
    span = 2 * r * crop
    M = np.float32([[size / span, 0, -x0 * size / span], [0, size / span, -y0 * size / span]])
    a = cv2.warpAffine(albedo, M, (size, size), flags=cv2.INTER_AREA).astype(np.float32) / 255.0
    n = cv2.warpAffine(normal, M, (size, size), flags=cv2.INTER_AREA).astype(np.float32) / 255.0 * 2 - 1
    light = np.array([-0.45, 0.55, 0.7]); light /= np.linalg.norm(light)
    shade = np.clip(n @ light, 0, 1)[..., None]
    col = a * (0.55 + 0.6 * shade)
    pts = [(size / 2 + math.cos(t) * kk * size / 2 / crop * 0.985, size / 2 - math.sin(t) * kk * size / 2 / crop * 0.985) for t, kk in zip(th, k)]
    mask = np.zeros((size, size), np.uint8)
    cv2.fillPoly(mask, [np.int32(pts)], 255)
    mask = cv2.GaussianBlur(mask, (3, 3), 0)
    # (a dark edge round it)
    edge = cv2.morphologyEx(mask, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8))
    col = col * (1 - 0.6 * (edge[..., None] / 255.0))
    out = np.dstack([np.clip(col, 0, 1) * 255, mask]).astype(np.uint8)
    return out


def square(ic, size):
    """On the slots' dark painted ground."""
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.sqrt((xx - size / 2) ** 2 + (yy - size / 2) ** 2) / (size / 2)
    ground = (np.array([0.16, 0.13, 0.1]) * (1.15 - 0.55 * d)[..., None]).clip(0, 1)
    small = cv2.resize(ic, (int(size * 0.84), int(size * 0.84)), interpolation=cv2.INTER_AREA).astype(np.float32) / 255.0
    o = (size - small.shape[0]) // 2
    out = ground.copy()
    al = small[..., 3:4]
    out[o:o + small.shape[0], o:o + small.shape[1]] = small[..., :3] * al + out[o:o + small.shape[0], o:o + small.shape[1]] * (1 - al)
    return (np.dstack([out, np.ones((size, size))]) * 255).astype(np.uint8)


def material(name, albedo_path, normal_path):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Metallic"].default_value = 0.85
    bsdf.inputs["Roughness"].default_value = 0.42
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = bpy.data.images.load(albedo_path)
    nt.links.new(ta.outputs[0], bsdf.inputs["Base Color"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = bpy.data.images.load(normal_path)
    tn.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return m


def main():
    for d in (OUT_MODELS, OUT_ICONS, OUT_SQUARE):
        os.makedirs(d, exist_ok=True)
    tmp = os.path.join(DEBUG or "/tmp", "zodiac_tmp")
    os.makedirs(tmp, exist_ok=True)
    coins = load_coins()
    log("coins", sorted(coins))
    only = [int(x) for x in os.environ.get("ONLY", "").split(",") if x]
    for n in sorted(coins):
        if only and n not in only:
            continue
        obj = coins[n]
        s = sample(obj)
        mf = fit_uv(s["xy"][s["front"]], s["uv"][s["front"]])
        mb = fit_uv(s["xy"][s["back"]], s["uv"][s["back"]])
        circles = [face_circle(mf, s["radius"]), face_circle(mb, s["radius"])]
        rgb = cv2.cvtColor(cv2.imread(os.path.join(TEX, "z%03d_BaseColor.png" % n)), cv2.COLOR_BGR2RGB)
        rgb = cv2.resize(rgb, (WORK, WORK), interpolation=cv2.INTER_AREA)
        h = height_map(s, "front", mf) + height_map(s, "back", mb)
        mask, ground = star_mask(h, circles)
        # (painted out: the picture filled from round each star, then smoothed there; the relief laid
        # down to its ground there - both eased in at the edges)
        # (the picture's marks are wider than the relief's - their dark outlines - so more of it goes)
        cmask = cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)))
        csoft = cv2.GaussianBlur(cmask.astype(np.float32), (0, 0), 3.0)[..., None]
        filled = cv2.inpaint(rgb, cmask, 15, cv2.INPAINT_TELEA)
        filled = cv2.medianBlur(filled, 21)
        rgb_clean = (rgb * (1 - csoft) + filled * csoft).astype(np.uint8)
        soft = cv2.GaussianBlur(cv2.dilate(mask, np.ones((5, 5), np.uint8)).astype(np.float32), (0, 0), 2.5)
        hg = cv2.GaussianBlur(ground, (0, 0), 3.0)
        h_clean = (h * (1 - soft) + hg * soft).astype(np.float32)
        albedo = retone(rgb_clean, h_clean, circles)
        normal = normal_from(h_clean, mf)
        key = "zodiac_%02d" % n
        ap, np_ = os.path.join(tmp, key + "_colour.jpg"), os.path.join(tmp, key + "_normal.jpg")
        save_tex(albedo, ap)
        save_tex(normal, np_)
        if DEBUG:
            dbg = np.hstack([rgb, np.dstack([mask * 255] * 3).astype(np.uint8), albedo, normal])
            cv2.imwrite(os.path.join(DEBUG, key + "_debug.jpg"), cv2.cvtColor(cv2.resize(dbg, (2048, 512)), cv2.COLOR_RGB2BGR))
        coin, th, k = build_mesh(key, s, mf, mb, seed=100 + n)
        coin.data.materials.append(material(key, ap, np_))
        bpy.ops.object.select_all(action="DESELECT")
        coin.select_set(True)
        bpy.context.view_layer.objects.active = coin
        out = os.path.join(OUT_MODELS, key + ".glb")
        bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                                  export_image_format="JPEG", export_materials="EXPORT")
        c, r = circles[0]
        ic = icon(albedo, normal, c, r, th, k, 256)
        cv2.imwrite(os.path.join(OUT_ICONS, key + ".png"), cv2.cvtColor(cv2.resize(ic, (128, 128), interpolation=cv2.INTER_AREA), cv2.COLOR_RGBA2BGRA))
        sq = square(ic, 128)
        cv2.imwrite(os.path.join(OUT_SQUARE, key + ".png"), cv2.cvtColor(sq, cv2.COLOR_RGBA2BGRA))
        bpy.data.objects.remove(coin)
        log("made", key, "stars painted out (px):", int(mask.sum()), "glb", os.path.getsize(out))


main()
