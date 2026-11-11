"""Our own fish skeleton, made to stand beside the open-source one the user found (the ASSET1
release's SM_fish_midpoly - a predator's skeleton, stylised-realistic) and be compared with it
(user request: with that model as the example, make one of our own).

Our own design, not its mesh: a big-headed predator - a heavy skull, a deep eye socket ringed in
bone (a thin wall inside it with a window through), the gill plates behind it with holes worn
through, toothed jaws a little open; a backbone of hourglass vertebrae arching to the tail; spines
above it swept back (the first ones tall, curling back at the tip, a few forked), flared into webs
where they meet the bone, short spines between the first few; ribs round the belly; spines under the
tail; a forked tail of rays fused into two lobes; the pectoral and pelvic fins likewise. Each part
swept along its curve (blades and bone plates thinned to sharp rims, ribs round), then all of it
fused into one fine-grained surface (a voxel remesh), so the joints blend as a sculpt's do; that
detailed surface brought down to about the reference's size for the model itself, unwrapped, and
the bone's look baked onto it as textures (user request: sharper skull plates, the colour a texture):
its colour from a procedural material - ivory and tan, stained, darker in the crevices - and the
detailed surface's normals, so the rims stay sharp in the light.

  bpyenv/bin/pip install xatlas                               (once: the unwrapper)
  bpyenv/bin/python tools/make_fish_skeleton.py OUT_DIR       (repo root)

Writes OUT_DIR/own_fish.glb (the model with its textures), own_fish.blend, own_fish_color.png and
own_fish_normal.png, and renders OUT_DIR/own_<side|q34|top|front>.png with the light and the
cameras of the reference's renders (the same directions, scaled to the fish's length). Built with
its head toward +x and turned to lie as the reference does (head toward -y).
"""
import math
import os
import sys

import bpy
import bmesh  # (after bpy: it's bpy's module)
from mathutils import Vector

N_VERT = 15          # vertebrae
VOXEL = 0.0018       # the detailed surface's grain (m; the fish ~2.15 m long, as the reference)
LOW_VOXEL = 0.0028   # the model's own grain, before it's brought down: coarse enough to close the
                     # millimetre gaps (bone lying on bone) that a decimation would cross
TARGET_TRIS = 90000  # the model's own triangles (the reference: 93k)
TEX = 2048           # its textures' size (the reference's: 2048)


class Builder:
    """Swept shapes gathered into one mesh."""

    def __init__(self):
        self.verts = []
        self.faces = []

    def sweep(self, pts, rn, rb=None, segs=10, cap=True, edge=0.0):
        """A tube along `pts` (Vectors), its cross-section an ellipse: `rn` across within the
        fish's own plane (front-back for a spine, up-down for a jaw), `rb` side to side (round if
        not given). `rn`/`rb` one radius a point. Capped (unless `cap` false) with rounded ends.
        `edge` sharpens the rims across `rn`: 0 an ellipse's round rim, 1 a lens's (the thickness
        thinning straight to an edge) - a bone plate's or a blade's."""
        rb = rb or rn
        n = len(pts)
        side = Vector((0, 1, 0))
        rings = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            nrm = side.cross(t)
            if nrm.length < 1e-4:
                nrm = Vector((1, 0, 0)).cross(t)
            nrm.normalize()
            rings.append((p, t, nrm, t.cross(nrm).normalized(), rn[i], rb[i]))
        if cap:
            def dome(ring, sign, order):
                p, t, nrm, bin_, a, b_ = ring
                depth = max(a, b_) * 0.6
                return [(p + t * sign * depth * math.sqrt(1 - s_ * s_), t, nrm, bin_, a * s_, b_ * s_) for s_ in order]
            rings = dome(rings[0], -1, (0.25, 0.55, 0.8, 0.95)) + rings + dome(rings[-1], 1, (0.95, 0.8, 0.55, 0.25))
        base = len(self.verts)
        for p, t, nrm, bin_, a, b_ in rings:
            for k in range(segs):
                ang = 2 * math.pi * k / segs
                sn = math.sin(ang)
                self.verts.append(p + nrm * math.cos(ang) * a + bin_ * math.copysign(abs(sn) ** (1.0 + edge), sn) * b_)
        m = len(rings)
        for i in range(m - 1):
            for k in range(segs):
                a = base + i * segs + k
                b_ = base + i * segs + (k + 1) % segs
                self.faces.append((a, b_, b_ + segs, a + segs))
        if cap:
            self.faces.append(tuple(base + k for k in range(segs))[::-1])
            self.faces.append(tuple(base + (m - 1) * segs + k for k in range(segs)))

    def mesh(self, name):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        me.validate()
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        return ob


def V(x, y, z):
    return Vector((x, y, z))


def bez(p0, p1, p2, steps=8):
    return [p0 * (1 - t) ** 2 + p1 * 2 * t * (1 - t) + p2 * t * t for t in [i / (steps - 1) for i in range(steps)]]


def chain(pts, steps=12):
    """A smooth curve through `pts` (Catmull-Rom), `steps` points a span."""
    out = []
    ext = [pts[0] * 2 - pts[1]] + list(pts) + [pts[-1] * 2 - pts[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(steps):
            t = s / steps
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1].copy())
    return out


def profile(n, values):
    """`values` (a few) stretched over `n` points."""
    out = []
    for i in range(n):
        f = i / (n - 1) * (len(values) - 1)
        j = min(int(f), len(values) - 2)
        out.append(values[j] + (values[j + 1] - values[j]) * (f - j))
    return out


def ellipsoid(loc, size, segs=48):
    """An ellipsoid whose vertices are in world space (its origin at the world's)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, location=loc)
    ob = bpy.context.active_object
    ob.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def lens(ob, cy, half, power=1.8):
    """A thin ellipsoid (thin along y, centred at y `cy`, `half` thick each side) made a lens: its
    rim thinned to an edge instead of rounded."""
    for v in ob.data.vertices:
        f = (v.co.y - cy) / half
        v.co.y = cy + math.copysign(abs(f) ** power, f) * half
    return ob


def cut(target, cutter):
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)


# ---------------------------------------------------------------- the body (head toward +x)

def spine_at(u):
    """The backbone's centre, u 0 at the back of the skull .. 1 at the tail's root: arching a
    little behind the head, falling to the tail."""
    x = 0.54 - 1.28 * u
    w = (1 - u) ** 3, 3 * u * (1 - u) ** 2, 3 * u * u * (1 - u), u ** 3
    z = 0.50 * w[0] + 0.6 * w[1] + 0.5 * w[2] + 0.385 * w[3]
    return V(x, 0, z)


def spine_r(u):
    return 0.05 * (1.0 - 0.56 * u)


def neural(b, i, c, r, u):
    """The spine above vertebra `i`: swept back, curling at the tip, its root flared into a web."""
    tall = (0.5 if i else 0.4) * (1.0 - u) ** 0.95 + 0.07
    lean = math.radians(14 + 50 * u)
    curl = 0.22 * tall * max(0.0, 1.0 - 1.6 * u)
    base = c + V(0, 0, r * 0.2)
    mid = c + V(-math.sin(lean * 0.6) * tall * 0.55, 0, math.cos(lean * 0.6) * tall * 0.6)
    tip = c + V(-math.sin(lean) * tall - curl, 0, math.cos(lean) * tall)
    pts = bez(base, mid, tip, 12)
    web = 1.8 - 0.5 * u
    b.sweep(pts, profile(12, [r * web, r * 0.9, r * 0.5, r * 0.36, r * 0.28, r * 0.2, r * 0.04]),
        profile(12, [r * 0.62, r * 0.42, r * 0.3, r * 0.22, r * 0.17, r * 0.12, r * 0.03]), segs=14, edge=0.8)
    if i in (1, 3, 5):
        # (forked at the tip: a prong off its back, near the top)
        at = pts[9]
        d = (pts[11] - pts[8]).normalized()
        back = V(d.z, 0, -d.x) if d.z > 0 else V(-1, 0, 0)
        if back.x > 0:
            back = -back
        prong = bez(at, at + d * tall * 0.06 + back * tall * 0.04, at + d * tall * 0.1 + back * tall * 0.16, 6)
        b.sweep(prong, profile(6, [r * 0.24, r * 0.16, r * 0.03]), profile(6, [r * 0.14, r * 0.1, r * 0.03]), segs=8)
    if i < 4:
        # (a short spine behind it, between it and the next)
        c2 = spine_at(u + 0.5 / N_VERT)
        s0 = c2 + V(0, 0, r * 0.3)
        sh = 0.11 + 0.03 * (4 - i) / 4
        b.sweep(bez(s0, s0 + V(-0.02, 0, sh * 0.6), s0 + V(-0.07, 0, sh), 7),
            profile(7, [r * 1.3, r * 0.5, r * 0.25, r * 0.04]), profile(7, [r * 0.45, r * 0.28, r * 0.15, r * 0.03]), segs=12, edge=0.8)


def rib(b, i, c, r):
    """A pair of ribs off vertebra `i`, round the belly, leaning back."""
    ln = 0.25 + 0.17 * math.sin(math.pi * i / 10.0)
    for side in (-1, 1):
        s0 = c + V(0.005, side * r * 0.72, -r * 0.42)
        p1 = s0 + V(-0.035, side * 0.075, -ln * 0.42)
        p2 = s0 + V(-0.12 - 0.006 * i, side * 0.03, -ln)
        pts = bez(s0, p1, p2, 12)
        b.sweep(pts, profile(12, [r * 0.75, r * 0.42, r * 0.33, r * 0.27, r * 0.18, r * 0.04]),
            profile(12, [r * 0.5, r * 0.34, r * 0.28, r * 0.22, r * 0.15, r * 0.035]), segs=12, edge=0.3)


def haemal(b, c, r, u):
    """A spine under the tail, swept back, webbed at the root."""
    low = 0.32 * (1.0 - u) + 0.07
    lean = math.radians(36 + 30 * u)
    base = c - V(0, 0, r * 0.2)
    mid = c + V(-math.sin(lean * 0.6) * low * 0.5, 0, -math.cos(lean * 0.6) * low * 0.6)
    tip = c + V(-math.sin(lean) * low, 0, -math.cos(lean) * low)
    pts = bez(base, mid, tip, 9)
    b.sweep(pts, profile(9, [r * 1.4, r * 0.7, r * 0.38, r * 0.24, r * 0.04]), profile(9, [r * 0.6, r * 0.36, r * 0.24, r * 0.16, r * 0.03]), segs=14, edge=0.8)


def body(b):
    # the column: one sweep, each vertebra an hourglass - flared rims at its ends, a notch between
    steps = N_VERT * 14
    pts, rn, rb = [], [], []
    for k in range(steps + 1):
        u = k / steps
        f = (u * N_VERT) % 1.0
        rim = abs(math.cos(math.pi * f)) ** 3
        notch = math.exp(-((min(f, 1 - f)) / 0.035) ** 2)
        r = spine_r(u) * (0.8 + 0.3 * rim) * (1.0 - 0.22 * notch)
        pts.append(spine_at(u))
        rn.append(r)
        rb.append(r * 0.94)
    # (and on into the skull's back)
    pts.insert(0, spine_at(0) + V(0.06, 0, -0.01))
    rn.insert(0, spine_r(0) * 0.9)
    rb.insert(0, spine_r(0) * 0.9)
    b.sweep(pts, rn, rb, segs=16)
    for i in range(N_VERT):
        u = (i + 0.5) / N_VERT
        c = spine_at(u)
        r = spine_r(u)
        neural(b, i, c, r, u)
        if 1 <= i <= 9:
            rib(b, i, c, r)
        elif i >= 10:
            haemal(b, c, r, u)


def blade(b, root, d, n, reach, width, thick, rays=3, sag=0.0, steps=14):
    """A fin's lobe: a thin blade from `root` along `d` (unit, within the fish's plane or near it),
    `n` across it; broadest a third of the way, pointed; `rays` ridges along it, standing proud of
    the blade, converging toward the tip."""
    tip = root + d * reach
    mid = root + d * reach * 0.5 + n * sag
    pts = bez(root, mid, tip, steps)
    b.sweep(pts, profile(steps, [width * 0.55, width, width * 0.8, width * 0.45, 0.003]), profile(steps, [thick, thick * 0.85, thick * 0.7, thick * 0.55, 0.0015]), segs=14, edge=1.0)
    for k in range(rays):
        off = (k / (rays - 1) - 0.5) * 2.0 if rays > 1 else 0.0
        a = root + n * off * width * 0.35
        c = tip + n * off * width * 0.08
        m = (a + c) * 0.5 + n * (sag + off * width * 0.25)
        b.sweep(bez(a, m, c, steps), profile(steps, [0.009, 0.007, 0.005, 0.0015]), profile(steps, [thick * 1.5, thick * 1.35, thick * 1.1, 0.0015]), segs=8)


def tail(b):
    end = spine_at(1.0)
    r = spine_r(1.0)
    # (the hypural plate: a short fan the lobes grow from)
    plate = bez(end + V(0.02, 0, 0), end + V(-0.05, 0, 0.005), end + V(-0.09, 0, 0.01), 6)
    b.sweep(plate, profile(6, [r * 1.0, r * 1.9, r * 2.5]), profile(6, [r * 0.85, r * 0.6, r * 0.4]), segs=14)
    root = end + V(-0.07, 0, 0.01)
    # (two lobes - the upper the longer - and a short rounded piece in the fork)
    for deg, reach, width, sag in ((23, 0.37, 0.05, -0.012), (-21, 0.31, 0.045, 0.012), (0, 0.12, 0.05, 0.0)):
        a = math.radians(deg)
        d = V(-math.cos(a), 0, math.sin(a))
        n = V(math.sin(a), 0, math.cos(a))
        blade(b, root + n * (0.025 if deg > 0 else -0.025 if deg < 0 else 0.0), d, n, reach, width, 0.0065, rays=3 if deg else 2, sag=sag)


def fins(b):
    # the pectoral fins: a knob low behind the gills, a ribbed blade back along the belly
    for side in (-1, 1):
        k0 = V(0.45, side * 0.125, 0.115)
        b.sweep(bez(k0 + V(0.03, -side * 0.01, 0.012), k0, k0 + V(-0.03, side * 0.004, -0.004), 6), profile(6, [0.018, 0.026, 0.02]), segs=12)
        d = V(-0.96, side * 0.12, -0.25).normalized()
        n = V(-0.25, 0, 0.96).normalized()
        blade(b, k0 + V(-0.02, side * 0.005, 0), d, n, 0.27, 0.04, 0.006, rays=4, sag=0.01)
    # the pelvic fins: small, under the belly
    for side in (-1, 1):
        p0 = V(0.24, side * 0.05, 0.1)
        b.sweep(bez(p0 + V(0.03, 0, 0.02), p0, p0 + V(-0.02, 0, -0.005), 5), profile(5, [0.012, 0.018, 0.013]), segs=10)
        # (the pelvic bone: forward to the foot of the cleithrum, which it hangs from)
        b.sweep(bez(p0, p0 + V(0.12, side * 0.01, -0.03), V(0.5, side * 0.07, 0.075), 8), profile(8, [0.012, 0.009, 0.011]), segs=10)
        d = V(-0.9, side * 0.15, -0.4).normalized()
        n = V(-0.4, 0, 0.9).normalized()
        blade(b, p0, d, n, 0.16, 0.028, 0.005, rays=3, sag=0.006)


# ---------------------------------------------------------------- the head

def head(b):
    """The skull's bars, rims and teeth into `b`; its cranium and gill plates as their own objects
    (cut through with booleans). Returns those objects."""
    parts = []
    # (the cranium: heavy behind, tapering and sloping down to the snout, flat beneath)
    cranium = ellipsoid((0.7, 0, 0.44), (0.25, 0.15, 0.17), segs=64)
    for v in cranium.data.vertices:
        t = max(0.0, (v.co.x - 0.7) / 0.25)
        back = max(0.0, (0.7 - v.co.x) / 0.25)
        k = 1.0 - 0.5 * t ** 1.3
        v.co.y *= k * (1.0 + 0.1 * back)
        dz = (v.co.z - 0.44) * k
        if dz > 0:
            dz *= 1.0 + 0.25 * back
        else:
            dz = -0.12 * math.tanh(-dz / 0.12)
        v.co.z = 0.44 + dz - 0.11 * t ** 1.4
    cranium.data.update()
    bpy.context.view_layer.update()

    def skin(x, z0, dy, dz):
        """Where the cranium's surface is, out from (x, 0, z0) along (0, dy, dz): (point, normal),
        or None."""
        ok, loc, nrm, _ = cranium.ray_cast(V(x, 0, z0), V(0, dy, dz).normalized())
        return (loc, nrm) if ok else None

    def axis_z(x):
        t = max(0.0, (x - 0.7) / 0.25)
        return 0.43 - 0.11 * t ** 1.4

    eye = V(0.765, 0, 0.405)
    for side in (-1, 1):
        # (the socket's rim, on the skull's face: thick below and behind - the bones under the eye -
        # thinner above)
        ring, rn, rb = [], [], []
        for k in range(37):
            a = 2 * math.pi * k / 36
            x, z = eye.x + math.cos(a) * 0.097, eye.z + math.sin(a) * 0.092
            hit = skin(x, z, side, 0)
            y = hit[0].y - side * 0.004 if hit else side * 0.1
            heavy = 0.5 + 0.5 * math.sin(-a - math.pi * 0.25)
            ring.append(V(x, y, z))
            rn.append(0.015 + 0.02 * heavy)
            rb.append(0.012 + 0.008 * heavy)
        b.sweep(ring, rn, rb, segs=14, cap=False, edge=0.6)
        # (ridges along the crown, front to back - the frontals' edges)
        for deg, thick in ((80, 0.011), (54, 0.014)):
            th = math.radians(deg)
            pts = []
            for k in range(16):
                x = 0.93 - 0.4 * k / 15
                hit = skin(x, axis_z(x), side * math.cos(th), math.sin(th))
                if hit:
                    pts.append(hit[0] + hit[1] * thick * 0.3)
            if len(pts) > 3:
                rr = profile(len(pts), [thick * 0.5, thick, thick * 1.1, thick * 0.9])
                b.sweep(pts, [x * 1.3 for x in rr], [x * 0.7 for x in rr], segs=14, edge=0.8)
    # (the crest: a blade standing on the crown, rising behind into the first spine)
    tops = []
    for k in range(14):
        x = 0.88 - 0.34 * k / 13
        hit = skin(x, axis_z(x), 0, 1)
        if hit:
            tops.append(hit[0])
    h = profile(len(tops), [0.006, 0.018, 0.032, 0.05])
    crest = [p + V(0, 0, hh * 0.6) for p, hh in zip(tops, h)]
    b.sweep(crest, h, profile(len(tops), [0.006, 0.009, 0.012, 0.015]), segs=14, edge=1.0)
    # (the eye socket, deep and big - right through; a thin wall put back inside it)
    cut(cranium, ellipsoid((eye.x, 0, eye.z), (0.088, 0.5, 0.083), segs=40))
    # (smaller windows: one above-behind the socket, one before it)
    cut(cranium, ellipsoid((0.62, 0, 0.5), (0.028, 0.5, 0.022), segs=24))
    cut(cranium, ellipsoid((0.885, 0, 0.385), (0.024, 0.5, 0.02), segs=24))
    parts.append(cranium)
    septum = lens(ellipsoid((0.76, 0, 0.4), (0.085, 0.012, 0.08), segs=48), 0.0, 0.012)
    cut(septum, ellipsoid((0.75, 0, 0.385), (0.03, 0.2, 0.034), segs=24))
    parts.append(septum)
    for side in (-1, 1):
        # (the preopercle: a crescent behind the eye, down to the jaw's hinge and forward)
        pre = chain([V(0.66, side * 0.125, 0.53), V(0.625, side * 0.135, 0.4), V(0.6, side * 0.138, 0.26),
                     V(0.61, side * 0.13, 0.17), V(0.67, side * 0.12, 0.135)], 6)
        b.sweep(pre, profile(len(pre), [0.014, 0.03, 0.034, 0.03, 0.016]), profile(len(pre), [0.01, 0.013, 0.014, 0.012, 0.009]), segs=14, edge=1.0)
        # (the quadrate: the hinge's post up to the skull)
        b.sweep(bez(V(0.6, side * 0.115, 0.15), V(0.62, side * 0.12, 0.24), V(0.66, side * 0.115, 0.33), 7), profile(7, [0.024, 0.018, 0.022]), profile(7, [0.018, 0.013, 0.016]), segs=12, edge=0.4)
        # (the cleithrum: the crescent the gills close on, down to the throat)
        cle = chain([V(0.475, side * 0.12, 0.5), V(0.455, side * 0.135, 0.38), V(0.45, side * 0.135, 0.24), V(0.475, side * 0.11, 0.12), V(0.52, side * 0.07, 0.07)], 6)
        b.sweep(cle, profile(len(cle), [0.014, 0.034, 0.04, 0.032, 0.014]), profile(len(cle), [0.008, 0.009, 0.01, 0.009, 0.007]), segs=14, edge=1.0)
        # (the gill plate: bowed out well clear of the skull's side - a surface lying within a few
        # mm of another crosses it to and fro, each crossing a crease the crevices' darkening finds -
        # its inner face sunk into the skull, all but the rim; two holes worn through it)
        plate = lens(ellipsoid((0.525, side * 0.145, 0.36), (0.075, 0.012, 0.16), segs=64), side * 0.145, 0.012)
        for v in plate.data.vertices:
            q = max(0.0, 1.0 - ((v.co.z - 0.36) / 0.16) ** 2 - ((v.co.x - 0.525) / 0.075) ** 2)
            if (v.co.y - side * 0.145) * side < 0:
                v.co.y -= side * 0.035 * q ** 0.3
            v.co.y += side * 0.04 * q
        for c, s in (((0.53, side * 0.16, 0.45), (0.022, 0.1, 0.027)), ((0.51, side * 0.16, 0.3), (0.026, 0.1, 0.021))):
            cut(plate, ellipsoid(c, s, segs=24))
        parts.append(plate)
        # (the subopercle beneath it)
        parts.append(lens(ellipsoid((0.54, side * 0.135, 0.18), (0.06, 0.011, 0.035), segs=48), side * 0.135, 0.011))
    # (the snout's bar, from the brow down to the jaws' tip)
    b.sweep(bez(V(0.9, 0, 0.42), V(0.99, 0, 0.37), V(1.03, 0, 0.29), 8), profile(8, [0.032, 0.024, 0.02]), profile(8, [0.028, 0.02, 0.018]), segs=12)
    for side in (-1, 1):
        # (the cheek: a plate from the snout under the eye, joining the upper jaw to the skull)
        cheek = chain([V(1.03, side * 0.03, 0.3), V(0.94, side * 0.085, 0.31), V(0.83, side * 0.12, 0.295)], 6)
        b.sweep(cheek, profile(len(cheek), [0.016, 0.034, 0.036, 0.024]), profile(len(cheek), [0.008, 0.009, 0.009, 0.008]), segs=14, edge=1.0)
    # (the jaws: the upper along the mouth's edge, the lower hinged a little open - an underbite -
    # teeth along both, the front ones fangs)
    hinge = V(0.6, 0, 0.15)
    chin = V(1.075, 0, 0.065)
    for side in (-1, 1):
        prem = chain([V(1.05, side * 0.012, 0.25), V(0.96, side * 0.06, 0.235), V(0.84, side * 0.095, 0.22)], 6)
        b.sweep(prem, profile(len(prem), [0.016, 0.02, 0.018]), profile(len(prem), [0.012, 0.014, 0.012]), segs=12, edge=0.5)
        maxi = chain([V(0.92, side * 0.08, 0.27), V(0.8, side * 0.105, 0.23), V(0.67, side * 0.115, 0.19)], 6)
        b.sweep(maxi, profile(len(maxi), [0.012, 0.026, 0.034, 0.022]), profile(len(maxi), [0.009, 0.011, 0.012, 0.01]), segs=14, edge=1.0)
        low = chain([V(hinge.x, side * 0.115, hinge.z), V(0.78, side * 0.095, 0.12), V(0.95, side * 0.055, 0.085), V(chin.x, side * 0.01, chin.z)], 6)
        b.sweep(low, profile(len(low), [0.046, 0.042, 0.032, 0.02]), profile(len(low), [0.018, 0.016, 0.013, 0.011]), segs=14, edge=0.7)
        b.sweep(bez(V(hinge.x - 0.02, side * 0.115, hinge.z), V(hinge.x, side * 0.12, hinge.z + 0.005), V(hinge.x + 0.025, side * 0.115, hinge.z + 0.01), 5),
            [0.03, 0.036, 0.038, 0.034, 0.024], segs=12)
        for j in range(8):
            f = j / 7
            fang = 1.0 + 0.9 * max(0.0, 1.0 - f * 3.5)
            pu = prem[min(len(prem) - 1, int(f * (len(prem) - 1) + 0.5))]
            ln = (0.024 + 0.012 * math.sin(f * math.pi)) * fang
            r0 = pu + V(0, -side * 0.004, -0.01)
            b.sweep(bez(r0, r0 + V(0.003, 0, -ln * 0.6), r0 + V(-0.008, -side * 0.004, -ln), 6), profile(6, [0.0075 * fang ** 0.5, 0.005, 0.0012]), segs=8)
        for j in range(10):
            f = j / 9
            fang = 1.0 + 1.1 * max(0.0, 1.0 - f * 3.0)
            pl = low[min(len(low) - 1, int((0.3 + 0.7 * (1 - f)) * (len(low) - 1)))]
            ln = (0.028 + 0.014 * math.sin(f * math.pi)) * fang
            r0 = pl + V(0, -side * 0.004, 0.012)
            b.sweep(bez(r0, r0 + V(0.004, 0, ln * 0.6), r0 + V(-0.01, -side * 0.005, ln), 6), profile(6, [0.008 * fang ** 0.5, 0.0055, 0.0012]), segs=8)
    return parts


# ---------------------------------------------------------------- material, light, cameras

def bone_material():
    m = bpy.data.materials.new("bone")
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    coord = nodes.new("ShaderNodeTexCoord")

    def mul(a, b_):
        n = nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = "MULTIPLY"
        n.inputs["Factor"].default_value = 1.0
        links.new(a, n.inputs[6])
        links.new(b_, n.inputs[7])
        return n.outputs[2]

    def noise_ramp(scale, detail, lo, hi):
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = scale
        nz.inputs["Detail"].default_value = detail
        links.new(coord.outputs["Object"], nz.inputs["Vector"])
        rp = nodes.new("ShaderNodeValToRGB")
        for el, (pos, col) in zip(rp.color_ramp.elements, (lo, hi)):
            el.position = pos
            el.color = col + (1,)
        links.new(nz.outputs["Fac"], rp.inputs["Fac"])
        return rp.outputs["Color"]

    # (ivory to tan, broad; brown stains, patchy; dirt in the crevices - how shut in a point is)
    base = noise_ramp(3.0, 6.0, (0.4, (0.52, 0.36, 0.19)), (0.6, (0.85, 0.73, 0.52)))
    stain = noise_ramp(7.0, 10.0, (0.5, (1.0, 1.0, 1.0)), (0.7, (0.7, 0.54, 0.36)))
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.22
    # (shut in by its own bone only - not by the lighter model lying on it while it's baked)
    ao.only_local = True
    aor = nodes.new("ShaderNodeValToRGB")
    aor.color_ramp.elements[0].color = (0.16, 0.1, 0.05, 1)
    aor.color_ramp.elements[1].position = 0.95
    links.new(ao.outputs["AO"], aor.inputs["Fac"])
    geo = nodes.new("ShaderNodeNewGeometry")
    edge = nodes.new("ShaderNodeValToRGB")
    edge.color_ramp.elements[0].position = 0.42
    edge.color_ramp.elements[0].color = (0.7, 0.62, 0.5, 1)
    edge.color_ramp.elements[1].position = 0.56
    links.new(geo.outputs["Pointiness"], edge.inputs["Fac"])
    links.new(mul(mul(mul(base, stain), aor.outputs["Color"]), edge.outputs["Color"]), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.58
    bsdf.inputs["Subsurface Weight"].default_value = 0.05
    bsdf.inputs["Subsurface Scale"].default_value = 0.012
    bsdf.inputs["Subsurface Radius"].default_value = (1.0, 0.55, 0.3)
    # (a fine porous grain)
    fine = nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 45.0
    fine.inputs["Detail"].default_value = 4.0
    links.new(coord.outputs["Object"], fine.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.035
    links.new(fine.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def stage_and_render(ob, out, prefix):
    """The reference's renders' light and cameras: one sun, a grey world, orthographic views along
    the same directions, scaled to the fish's length."""
    sc = bpy.context.scene
    L = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    L.data.energy = 3.0
    L.rotation_euler = (math.radians(40), math.radians(15), math.radians(20))
    sc.collection.objects.link(L)
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.52, 1)
    sc.world = w
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = False
    sc.view_settings.view_transform = "Standard"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    bpy.context.view_layer.update()
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    print("own lo", tuple(round(x, 3) for x in lo), "hi", tuple(round(x, 3) for x in hi), flush=True)
    mid = (lo + hi) / 2
    span = (hi - lo).length
    length = hi.y - lo.y
    height = hi.z - lo.z
    for name, d, scale, res in (("side", (1, 0, 0), 1.05 * length, (1400, 760)), ("q34", (0.75, -0.45, 0.48), 1.0 * length, (1400, 900)),
                                ("top", (0, 0, 1), 1.05 * length, (1400, 600)), ("front", (0, -1, 0.1), 1.2 * height, (900, 900))):
        d = Vector(d).normalized()
        cam.location = mid + d * span * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.ortho_scale = scale
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.filepath = os.path.join(out, "%s_%s.png" % (prefix, name))
        bpy.ops.render.render(write_still=True)
        print("made", sc.render.filepath, flush=True)


def drop_crumbs(ob, smallest=100):
    """Loose bits (fewer than `smallest` vertices) - what a decimation leaves - gone."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen, crumbs = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        piece, stack = [v], [v]
        seen.add(v)
        while stack:
            a = stack.pop()
            for e in a.link_edges:
                o = e.other_vert(a)
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
                    piece.append(o)
        if len(piece) < smallest:
            crumbs += piece
    bmesh.ops.delete(bm, geom=crumbs, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def unwrap(ob, tex=TEX):
    """`ob` triangulated and unwrapped by xatlas (Godot's own lightmap unwrapper): charts that never
    overlap, packed tight. (Blender's projection unwrap, tried first, folded a holed plate's chart
    over the bone behind its hole - the one's texels painted over the other - and its thousands of
    crumbs of islands left most of the texture empty.) Needs `pip install xatlas` in the bpy env."""
    import numpy as np
    import xatlas
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    me = ob.data
    verts = np.array([v.co[:] for v in me.vertices], dtype=np.float32)
    faces = np.array([p.vertices[:] for p in me.polygons], dtype=np.uint32)
    atlas = xatlas.Atlas()
    atlas.add_mesh(verts, faces)
    pack = xatlas.PackOptions()
    pack.resolution = tex
    pack.padding = 4
    pack.bilinear = True
    pack.rotate_charts = True
    atlas.generate(xatlas.ChartOptions(), pack)
    _vmap, idx, uvs = atlas[0]
    layer = me.uv_layers.new(name="UVMap")
    me.uv_layers.active = layer
    loop_uv = np.zeros((len(me.loops), 2), dtype=np.float32)
    for i, p in enumerate(me.polygons):
        for k, li in enumerate(p.loop_indices):
            loop_uv[li] = uvs[idx[i][k]]
    layer.data.foreach_set("uv", loop_uv.ravel())
    print("unwrapped: %d charts, %.0f%% of the texture used" % (atlas.chart_count, 100 * float(atlas.utilization)), flush=True)


def outer_only(ob):
    """Only the outer surface kept: the fine grain seals narrow gaps (a gill plate lying close on the
    skull) into pockets inside the bone, each its own closed shell - unseen, but a bake reading the
    surface would find their dark walls. Returns how many pieces went."""
    only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(ob.data)
    for v in bm.verts:
        v.select = False
    max(bm.verts, key=lambda v: v.co.z).select = True
    bm.select_flush(True)
    bpy.ops.mesh.select_linked()
    bpy.ops.mesh.select_all(action="INVERT")
    gone = sum(1 for v in bm.verts if v.select)
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    return gone


def only(ob, *others):
    """`ob` the active object, it and `others` alone selected."""
    for o in bpy.context.scene.objects:
        o.select_set(o == ob or o in others)
    bpy.context.view_layer.objects.active = ob


def apply(ob, kind, **props):
    only(ob)
    mod = ob.modifiers.new(kind.lower(), kind)
    for k, v in props.items():
        setattr(mod, k, v)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def bake_textures(high, low, out, prefix="own_fish", tex=TEX, cage=0.006, reach=0.02):
    """The bone's look baked into two textures on `low`'s UVs, both read off the detailed surface
    (`high`): its colour (the procedural material's - stains, dirt in the crevices, worked out on the
    detailed surface, whose crevices are the true ones) and its normals, so the sharp rims and
    creases still catch the light on the lighter model. Saved as OUT/own_fish_color.png and
    OUT/own_fish_normal.png."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    bk = sc.render.bake
    bk.margin = 8
    bk.margin_type = "EXTEND"
    bk.use_selected_to_active = True
    bk.cage_extrusion = cage
    bk.max_ray_distance = reach
    mat = bone_material()
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Subsurface Weight"].default_value = 0.0
    high.data.materials.clear()
    high.data.materials.append(mat)
    # (the model only receives: out of every ray, so it shadows nothing on the surface it's read from)
    for flag in ("visible_camera", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter", "visible_shadow"):
        setattr(low, flag, False)
    target = bpy.data.materials.new("bake_target")
    target.use_nodes = True
    low.data.materials.clear()
    low.data.materials.append(target)
    images = {}
    for name, colour in (("color", "sRGB"), ("normal", "Non-Color")):
        img = bpy.data.images.new("%s_%s" % (prefix, name), tex, tex, alpha=False, float_buffer=False)
        img.colorspace_settings.name = colour
        node = target.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = img
        images[name] = (img, node)

    def bake(name, kind):
        img, node = images[name]
        for n in target.node_tree.nodes:
            n.select = n == node
        target.node_tree.nodes.active = node
        only(low, high)
        bpy.ops.object.bake(type=kind)
        img.filepath_raw = os.path.join(out, img.name + ".png")
        img.file_format = "PNG"
        img.save()
        print("baked", img.filepath_raw, flush=True)
        return img

    bk.use_pass_direct = False
    bk.use_pass_indirect = False
    bk.use_pass_color = True
    color = bake("color", "DIFFUSE")
    bk.normal_space = "TANGENT"
    normal = bake("normal", "NORMAL")
    for flag in ("visible_camera", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter", "visible_shadow"):
        setattr(low, flag, True)
    return color, normal


def textured_material(color, normal):
    """The model's material as a game would have it: the two textures, nothing worked out live."""
    m = bpy.data.materials.new("own_fish")
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tc = nodes.new("ShaderNodeTexImage")
    tc.image = color
    links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    tn = nodes.new("ShaderNodeTexImage")
    tn.image = normal
    nm = nodes.new("ShaderNodeNormalMap")
    links.new(tn.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def main():
    out = sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = Builder()
    body(b)
    tail(b)
    fins(b)
    solids = head(b)
    swept = b.mesh("swept")
    only(swept, *solids)
    bpy.ops.object.join()
    high = bpy.context.view_layer.objects.active
    high.name = "own_fish_detail"
    raw = sum(len(p.vertices) - 2 for p in high.data.polygons)
    # (turned as the reference lies: its head toward -y, its back up)
    high.rotation_euler = (0, 0, math.radians(-90))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    # (the detailed surface: all of it fused into one, fine-grained, barely smoothed - the joints
    # blended as a sculpt's are, the plates' rims kept sharp)
    apply(high, "REMESH", mode="VOXEL", voxel_size=VOXEL, adaptivity=0.0)
    apply(high, "SMOOTH", factor=0.3, iterations=1)
    print("inner pockets: %d vertices dropped" % outer_only(high), flush=True)
    bpy.ops.object.shade_smooth()
    fused = len(high.data.polygons)
    # (the model itself: the detailed surface brought down, unwrapped)
    low = high.copy()
    low.data = high.data.copy()
    low.name = "own_fish"
    bpy.context.collection.objects.link(low)
    apply(low, "REMESH", mode="VOXEL", voxel_size=LOW_VOXEL, adaptivity=0.0)
    apply(low, "SMOOTH", factor=0.4, iterations=1)
    outer_only(low)
    apply(low, "DECIMATE", ratio=min(1.0, TARGET_TRIS / max(1, len(low.data.polygons) * 2)))
    drop_crumbs(low)
    unwrap(low)
    only(low)
    bpy.ops.object.shade_smooth()
    tris = sum(len(p.vertices) - 2 for p in low.data.polygons)
    print("made own_fish: parts %d tris, detailed %d faces, model %d tris" % (raw, fused, tris), flush=True)
    color, normal = bake_textures(high, low, out)
    bpy.data.objects.remove(high)
    low.data.materials.clear()
    low.data.materials.append(textured_material(color, normal))
    only(low)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "own_fish.glb"), export_format="GLB", use_selection=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "own_fish.blend"))
    stage_and_render(low, out, "own")
    os._exit(0)


if __name__ == "__main__":
    main()
