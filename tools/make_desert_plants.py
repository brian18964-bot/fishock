"""The desert map's own plants (user request: the desert - an oasis in the dunes, like the picture:
date palms thick along the pool, green round it, dry scrub out on the sand - "plants: make them
yourself").

  bpyenv/bin/python tools/make_desert_plants.py       (repo root)

Date palms (CampModel's "palm" family - assets/models/camp/palm_<a..d>.glb, two surfaces "bark" and
"leaves", their pictures palm_bark.png and palm_leaves.png made here too, set in the game):
  - a trunk that leans and bends a little, flared at the foot, covered in the old leaf bases;
  - a crown of pinnate fronds in three tiers - the youngest standing up, the oldest arching out and
    down - each frond a strip along its curving rib, folded up into a V (the leaflets' way), its
    picture the leaflets on both sides of the rib;
  - a skirt of dead, brown fronds hanging under the crown, and bunches of dates.
  palm_d: two trunks from one foot.
The proto plants (assets/models/proto3d, their pictures inside - RunView3D sways them):
  - palm_young: a young palm, its fronds straight from the sand (the bush you can hide in);
  - desert_grass: a tuft of tall straw-coloured grass.
Prints each one's size (trunk radius at the foot, crown reach, lowest frond) for MapTree.
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CAMP = os.path.join(ROOT, "assets", "models", "camp")
PROTO = os.path.join(ROOT, "assets", "models", "proto3d")
TMP = os.path.join(ROOT, "probe_tmp", "desert_plants")

# The leaves picture: two fronds side by side (green u 0..0.5, dry 0.5..1), each its rib up the
# middle; the bottom DATE_V of it the dates' colour (solid).
LEAF_W, LEAF_H = 1024, 1024
DATE_V = 0.0625
# (name, seed, height m, lean, fronds a tier (top, middle, low), dead fronds, date bunches)
PALMS = [
    ("palm_a", 3, 8.6, 0.07, (7, 10, 10), 8, 4),
    ("palm_b", 8, 7.0, 0.22, (6, 9, 9), 6, 3),
    ("palm_c", 13, 10.2, 0.11, (7, 11, 11), 10, 4),
]


# --- pictures ------------------------------------------------------------------

def bark_picture(path):
    """The trunk's old leaf bases: staggered rows of rounded scales, each lighter at its lower lip
    (it overhangs the one below), dark fibre in the gaps; grey-brown, weathered. Tiles both ways
    (u: half the trunk round, v: 1.2 m of it)."""
    from PIL import Image, ImageDraw, ImageFilter
    rng = random.Random(7)
    w, h = 256, 512
    im = Image.new("RGB", (w, h), (52, 40, 30))
    d = ImageDraw.Draw(im)
    # (fibre between the scales)
    for _ in range(900):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ln = rng.uniform(6, 18)
        a = math.radians(rng.uniform(60, 120))
        c = rng.randint(30, 70)
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=(c + 18, c + 8, c), width=1)
    cols, row_h = 6, 34
    cw = w / cols
    for r in range(-1, h // row_h + 2):
        off = (cw * 0.5) if r % 2 else 0.0
        for c in range(-1, cols + 1):
            cx = c * cw + off + rng.uniform(-3, 3)
            top = r * row_h + rng.uniform(-3, 3)
            bw = cw * rng.uniform(0.44, 0.52)
            bh = row_h * rng.uniform(1.15, 1.35)
            base = rng.uniform(0.85, 1.12)
            tone = (int(118 * base), int(98 * base), int(76 * base))
            # (a scale: a V at its top, rounded at its lower lip; shaded light toward the lip)
            for k in range(8):
                f = k / 7.0
                sh = 0.72 + 0.4 * f
                col = tuple(min(255, int(v * sh)) for v in tone)
                yy = top + bh * (0.15 + 0.8 * f)
                half = bw * (0.35 + 0.65 * math.sin(math.pi * min(1.0, 0.2 + f * 0.85)))
                pts = [(cx - half, yy - bh * 0.18), (cx, yy - bh * 0.32), (cx + half, yy - bh * 0.18),
                       (cx + half * 0.8, yy + bh * 0.08), (cx, yy + bh * 0.16), (cx - half * 0.8, yy + bh * 0.08)]
                for ox in (-w, 0, w):
                    for oy in (-h, 0, h):
                        d.polygon([(px + ox, py + oy) for px, py in pts], fill=col)
            # (a dark crack under the lip)
            for ox in (-w, 0, w):
                for oy in (-h, 0, h):
                    d.arc([cx - bw * 0.7 + ox, top + bh * 0.6 + oy, cx + bw * 0.7 + ox, top + bh * 1.05 + oy], 20, 160,
                          fill=(34, 26, 20), width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(path)


def _frond(d, x0, y0, fw, fh, rng, dry):
    """One frond drawn up the picture: the rib from the base (y0 + fh) to the tip (y0), leaflets
    off both sides pointing up and out, longest at the middle, spines near the base."""
    import PIL.ImageDraw  # noqa: F401
    cx = x0 + fw / 2
    greens = [(66, 98, 50), (78, 112, 56), (58, 86, 44), (90, 120, 62), (72, 104, 60)]
    drys = [(138, 104, 62), (120, 90, 54), (152, 120, 74), (104, 78, 46)]
    pal = drys if dry else greens
    rib_dark = (70, 74, 44) if not dry else (96, 72, 42)
    n = 92
    for i in range(n):
        t = i / (n - 1)  # 0 base .. 1 tip
        if t < 0.12:
            # (spines on the stalk)
            if i % 2 == 0:
                for side in (-1, 1):
                    y = y0 + fh * (1 - t)
                    d.line([(cx, y), (cx + side * fw * 0.06, y - fh * 0.015)], fill=pal[0] + (255,), width=2)
            continue
        y = y0 + fh * (1 - t)
        span = math.sin(math.pi * min(1.0, (t - 0.1) / 0.9)) ** 0.5
        for side in (-1, 1):
            if dry and rng.random() < 0.15:
                continue  # (a leaflet broken off)
            ln = fw * 0.48 * span * rng.uniform(0.88, 1.04)
            a = math.radians(rng.uniform(30, 40))
            dx, dy = side * math.sin(a), -math.cos(a)
            px, py = -dy, dx
            tip = (cx + dx * ln, y + dy * ln)
            wid = 16.0 * (0.55 + 0.45 * span) * rng.uniform(0.85, 1.15)
            col = pal[rng.randrange(len(pal))]
            # (a lance: widest a third of the way out, pointed)
            mid = (cx + dx * ln * 0.35, y + dy * ln * 0.35)
            pts = [(cx, y), (mid[0] + px * wid / 2, mid[1] + py * wid / 2), tip, (mid[0] - px * wid / 2, mid[1] - py * wid / 2)]
            d.polygon(pts, fill=col + (255,))
            # (its midrib, and its tip gone yellow-brown in the sun)
            d.line([(cx, y), tip], fill=tuple(max(0, v - 26) for v in col) + (255,), width=2)
            if not dry and rng.random() < 0.3:
                d.line([((cx + tip[0] * 3) / 4, (y + tip[1] * 3) / 4), tip], fill=(146, 132, 80, 255), width=3)
    # (the rib over them, thicker at the base)
    for k in range(24):
        t0, t1 = k / 24, (k + 1) / 24
        d.line([(cx, y0 + fh * (1 - t0)), (cx, y0 + fh * (1 - t1))], fill=rib_dark + (255,), width=max(2, int(9 * (1 - t0) + 2)))


def leaves_picture(path):
    from PIL import Image, ImageDraw
    rng = random.Random(11)
    im = Image.new("RGBA", (LEAF_W, LEAF_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top_h = int(LEAF_H * (1 - DATE_V))
    _frond(d, 0, 4, LEAF_W // 2, top_h - 8, rng, False)
    _frond(d, LEAF_W // 2, 4, LEAF_W // 2, top_h - 8, rng, True)
    # (the dates' strip: amber to brown, speckled)
    for x in range(LEAF_W):
        for y in range(top_h, LEAF_H):
            k = rng.uniform(0.85, 1.1)
            im.putpixel((x, y), (int(132 * k), int(66 * k), int(26 * k), 255))
    im.save(path)


def grass_picture(path):
    """Tall dry grass blades, straw and pale gold, a little green left at their feet."""
    from PIL import Image, ImageDraw
    rng = random.Random(31)
    w, h = 256, 512
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(90):
        x = w / 2 + rng.uniform(-60, 60)
        lean = rng.uniform(-0.5, 0.5)
        ln = rng.uniform(250, 500)
        col = [(196, 172, 112), (176, 150, 96), (210, 190, 132), (150, 140, 90)][rng.randrange(4)]
        pts = []
        for k in range(10):
            t = k / 9
            pts.append((x + lean * ln * t * t, h - 2 - ln * t))
        for k in range(9):
            wdt = max(1, int(4 * (1 - k / 9)))
            c = col if k > 1 else (110, 120, 70)
            d.line([pts[k], pts[k + 1]], fill=c + (255,), width=wdt)
    im.save(path)


# --- meshes --------------------------------------------------------------------

class Build:
    """Vertices, faces and UVs gathered for one mesh."""

    def __init__(self):
        self.v, self.f, self.uv = [], [], []

    def quad(self, a, b, c, d, ua, ub, uc, ud):
        i = len(self.v)
        self.v += [a, b, c, d]
        self.uv += [ua, ub, uc, ud]
        self.f.append((i, i + 1, i + 2, i + 3))

    def obj(self, name, material):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li, vi in zip(poly.loop_indices, poly.vertices):
                uvl.data[li].uv = self.uv[vi]
        me.materials.append(material)
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        return ob


def frond(b, base, az, el, length, width, droop, dry, rng, segs=8, fold=0.42):
    """One frond from `base`, out at azimuth `az` and elevation `el` (rad), `length` m, curving down
    by `droop` (m a metre squared); a V-folded strip `width` m across at its widest."""
    d0 = Vector((math.cos(el) * math.cos(az), math.cos(el) * math.sin(az), math.sin(el)))
    side = Vector((-math.sin(az), math.cos(az), 0.0))
    u0 = 0.5 if dry else 0.0
    rows = []
    twist = rng.uniform(-0.25, 0.25)
    for i in range(segs + 1):
        t = i / segs
        s = t * length
        p = base + d0 * s + Vector((0, 0, -droop * s * s))
        tan = (d0 + Vector((0, 0, -2 * droop * s))).normalized()
        up = tan.cross(side).normalized()
        if up.z < 0:
            up = -up
        w = width * 0.5 * (math.sin(math.pi * min(1.0, max(0.0, (t - 0.08) / 0.92))) ** 0.55 if t > 0.08 else 0.04)
        f = fold + twist * t
        sd = side * math.cos(f) + up * math.sin(f)
        sd2 = -side * math.cos(f) + up * math.sin(f)
        v = DATE_V + (1 - DATE_V) * (0.004 + 0.99 * t)
        rows.append((p + sd2 * w, p, p + sd * w, v))
    for i in range(segs):
        l0, c0, r0, v0 = rows[i]
        l1, c1, r1, v1 = rows[i + 1]
        b.quad(l0, c0, c1, l1, (u0, v0), (u0 + 0.25, v0), (u0 + 0.25, v1), (u0, v1))
        b.quad(c0, r0, r1, c1, (u0 + 0.25, v0), (u0 + 0.5, v0), (u0 + 0.5, v1), (u0 + 0.25, v1))


def trunk(b, foot, height, lean, rng, r0=0.27, segs=10, rings=16):
    """A palm trunk from `foot`: leaning `lean` (top offset share of its height) toward a random
    way, a slight S, flared at the foot, a bulge at the head. Returns (head point, its up)."""
    az = rng.uniform(0, math.tau)
    way = Vector((math.cos(az), math.sin(az), 0.0))
    wob = rng.uniform(-0.04, 0.04)
    wob_way = Vector((-way.y, way.x, 0.0))

    def at(t):
        return foot + way * (lean * height * t ** 1.6) + wob_way * (wob * height * math.sin(math.pi * t)) + Vector((0, 0, height * t))

    def radius(t):
        s = t * height
        flare = 1.0 + 0.75 * math.exp(-s / 0.35)
        head = 1.0 + 0.32 * math.exp(-((t - 1.0) / 0.035) ** 2)
        return r0 * flare * head * (1.0 - 0.12 * t) * (1.0 + 0.04 * math.sin(s * 3.1))

    ring_pts = []
    for k in range(rings + 1):
        t = k / rings
        c = at(t)
        tan = (at(min(1.0, t + 0.01)) - at(max(0.0, t - 0.01))).normalized()
        x = tan.cross(Vector((0, 1, 0))).normalized()
        y = tan.cross(x).normalized()
        r = radius(t)
        ring = []
        for j in range(segs + 1):
            a = j / segs * math.tau
            ring.append(c + (x * math.cos(a) + y * math.sin(a)) * r)
        ring_pts.append((ring, t * height / 1.2))
    for k in range(rings):
        ra, va = ring_pts[k]
        rb, vb = ring_pts[k + 1]
        for j in range(segs):
            u0, u1 = j / segs * 2.0, (j + 1) / segs * 2.0
            b.quad(ra[j], ra[j + 1], rb[j + 1], rb[j], (u0, va), (u1, va), (u1, vb), (u0, vb))
    head = at(1.0)
    up = (at(1.0) - at(0.97)).normalized()
    return head, up


def crown(leaf, head, tiers, dead, bunches, rng, scale=1.0):
    """A palm's crown at `head`: fronds in three tiers (standing, out, arching down), a skirt of
    dead ones under them, bunches of dates."""
    top, mid, low = tiers
    for n, el, ln, droop, wd in ((top, (0.95, 1.3), (2.6, 3.2), 0.05, 1.1),
                                 (mid, (0.35, 0.75), (3.4, 4.1), 0.1, 1.35),
                                 (low, (-0.1, 0.25), (3.4, 4.0), 0.15, 1.3)):
        a0 = rng.uniform(0, math.tau)
        for i in range(n):
            az = a0 + i / n * math.tau + rng.uniform(-0.2, 0.2)
            base = head + Vector((math.cos(az), math.sin(az), 0)) * 0.18 * scale + Vector((0, 0, rng.uniform(-0.25, 0.05)))
            frond(leaf, base, az, rng.uniform(*el), rng.uniform(*ln) * scale, wd * scale, droop / scale, False, rng)
    for i in range(dead):
        az = rng.uniform(0, math.tau)
        base = head + Vector((math.cos(az), math.sin(az), 0)) * 0.22 * scale + Vector((0, 0, -0.35))
        frond(leaf, base, az, rng.uniform(-1.45, -1.2), rng.uniform(2.2, 2.8) * scale, 0.95 * scale, 0.02, True, rng, segs=5, fold=0.2)
    date_uv = (0.25, DATE_V * 0.5)
    for i in range(bunches):
        az = rng.uniform(0, math.tau)
        stem = head + Vector((math.cos(az), math.sin(az), 0)) * 0.3 * scale + Vector((0, 0, -0.25))
        for k in range(9):
            c = stem + Vector((math.cos(az) * 0.15, math.sin(az) * 0.15, -0.35)) * scale \
                + Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), rng.uniform(-0.22, 0.1))) * scale
            r = 0.05 * scale
            # (a date: a little diamond of six faces - four round, two caps)
            pts = [c + Vector((r, 0, 0)), c + Vector((0, r, 0)), c + Vector((-r, 0, 0)), c + Vector((0, -r, 0))]
            topp, bot = c + Vector((0, 0, r * 1.3)), c + Vector((0, 0, -r * 1.3))
            for j in range(4):
                a, bb = pts[j], pts[(j + 1) % 4]
                leaf.quad(a, bb, topp, topp, date_uv, date_uv, date_uv, date_uv)
                leaf.quad(bb, a, bot, bot, date_uv, date_uv, date_uv, date_uv)


def mat(name, picture, leaves=False, pack=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(picture)
    if pack:
        img.pack()
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if leaves:
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        m.blend_method = "CLIP"
    bsdf.inputs["Roughness"].default_value = 0.95
    return m


def measure(name, obs):
    lo_leaf = 1e9
    reach = 0.0
    foot_r = 0.0
    for ob in obs:
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            reach = max(reach, math.hypot(p.x, p.y))
            if ob.name.startswith("leaves"):
                lo_leaf = min(lo_leaf, p.z)
            elif p.z < 0.05:
                foot_r = max(foot_r, math.hypot(p.x, p.y))
    tris = sum(len(p.vertices) - 2 for ob in obs for p in ob.data.polygons)
    print("made %s tris %d foot_r %.2f reach %.2f lowest_leaf %.2f" % (name, tris, foot_r, reach, lo_leaf), flush=True)


def export(path, images):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_image_format="AUTO" if images else "NONE")


def make_palm(name, seed, height, lean, tiers, dead, bunches, double=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(seed)
    bark_m = mat("bark", os.path.join(CAMP, "palm_bark.png"))
    leaf_m = mat("leaves", os.path.join(CAMP, "palm_leaves.png"), True)
    wood, leaf = Build(), Build()
    feet = [(Vector((0, 0, -0.25)), height, lean, tiers, dead, bunches, 1.0)]
    if double:
        feet = [(Vector((0.18, 0, -0.25)), height, lean, tiers, dead, bunches, 1.0),
                (Vector((-0.2, 0.1, -0.25)), height * 0.7, lean * 1.6, tuple(max(4, t - 2) for t in tiers), dead // 2, 2, 0.85)]
    for foot, h, ln, ti, de, bu, sc in feet:
        head, _up = trunk(wood, foot, h, ln, rng, r0=0.27 * sc)
        crown(leaf, head, ti, de, bu, rng, sc)
    obs = [wood.obj("bark_" + name, bark_m), leaf.obj("leaves_" + name, leaf_m)]
    measure(name, obs)
    # (one mesh, its two surfaces - CampModel takes a model's first mesh)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    obs[0].name = name
    export(os.path.join(CAMP, name + ".glb"), False)


def make_young_palm():
    """A young palm (the bush you hide in): its fronds from the sand, ~1.6 m high, ~2.6 across."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(41)
    leaf_m = mat("Fronds", os.path.join(TMP, "palm_young_fronds.png"), True, pack=True)
    leaf = Build()
    for n, el, ln, droop in ((5, (1.05, 1.35), (1.3, 1.6), 0.08), (8, (0.5, 0.85), (1.5, 1.8), 0.2), (8, (0.15, 0.4), (1.4, 1.7), 0.3)):
        a0 = rng.uniform(0, math.tau)
        for i in range(n):
            az = a0 + i / n * math.tau + rng.uniform(-0.25, 0.25)
            frond(leaf, Vector((math.cos(az) * 0.08, math.sin(az) * 0.08, 0.0)), az, rng.uniform(*el), rng.uniform(*ln),
                  0.75, droop, rng.random() < 0.12, rng, segs=6)
    obs = [leaf.obj("palm_young", leaf_m)]
    measure("palm_young", obs)
    export(os.path.join(PROTO, "palm_young.glb"), True)


def make_cards(name, picture, count, size, spread, tilt, seed, image_name):
    """A plant of crossed upright cards (`count`, `size` (w, h) m) round its foot."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(seed)
    m = mat(image_name, picture, True, pack=True)
    b = Build()
    for i in range(count):
        a = i / count * math.pi + rng.uniform(-0.2, 0.2)
        w, h = size[0] * rng.uniform(0.8, 1.1), size[1] * rng.uniform(0.8, 1.1)
        c = Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread), 0))
        dx = Vector((math.cos(a), math.sin(a), 0)) * w / 2
        lean = Vector((math.cos(a + 1.57), math.sin(a + 1.57), 0)) * h * rng.uniform(-tilt, tilt)
        up = Vector((0, 0, h)) + lean
        b.quad(c - dx, c + dx, c + dx + up, c - dx + up, (0, 0), (1, 0), (1, 1), (0, 1))
    obs = [b.obj(name, m)]
    measure(name, obs)
    export(os.path.join(PROTO, name + ".glb"), True)


def main():
    os.makedirs(TMP, exist_ok=True)
    bark_picture(os.path.join(CAMP, "palm_bark.png"))
    leaves_picture(os.path.join(CAMP, "palm_leaves.png"))
    # (the young palm's own copy of the fronds - a proto model carries its picture inside)
    import shutil
    shutil.copy(os.path.join(CAMP, "palm_leaves.png"), os.path.join(TMP, "palm_young_fronds.png"))
    grass_picture(os.path.join(TMP, "desert_grass_blades.png"))
    for name, seed, height, lean, tiers, dead, bunches in PALMS:
        make_palm(name, seed, height, lean, tiers, dead, bunches)
    make_palm("palm_d", 29, 8.2, 0.16, (6, 9, 9), 6, 3, double=True)
    make_young_palm()
    make_cards("desert_grass", os.path.join(TMP, "desert_grass_blades.png"), 4, (0.55, 0.85), 0.06, 0.15, 61, "Blades")
    os._exit(0)


if __name__ == "__main__":
    main()
