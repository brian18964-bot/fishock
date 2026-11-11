"""Reference pictures of the sixteen fish bones for an image-to-3D tool (user request: Meshy - so
they must read as solid things, not flat icons). Each a stylised fish skeleton built in 3D here - a
rounded skull with its eye sockets, jaw and gill plate, spool-shaped vertebrae, ribs on both sides
and spines on top, a fin of rays - in ivory bone, rendered three-quarter on, softly lit on white.
After the user's concept sheet (black silhouette skeletons): the same family, our own drawing.

The sixteen are the game's (scripts/bones.gd): whole / spine / skull / broken, small to huge -
each its own design (a sardine's to a big fish's).

  bpyenv/bin/python tools/make_bone_concepts.py OUT_DIR       (repo root)

Writes OUT_DIR/bone_<kind>_<size>.png (1024 square) and OUT_DIR/sheet.png.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector, Matrix

IVORY = (0.86, 0.82, 0.71, 1.0)
DARK = (0.34, 0.28, 0.22, 1.0)
RES = 1024


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, rough=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = rgb
    b.inputs["Roughness"].default_value = rough
    if "Subsurface Weight" in b.inputs:
        b.inputs["Subsurface Weight"].default_value = 0.08
    return m


def link(ob, m):
    bpy.context.collection.objects.link(ob)
    if m is not None:
        ob.data.materials.append(m)
    return ob


def tube(points, radii, m, res=6):
    """A tapered tube through `points` (Vectors), its radius at each."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = res // 2
    cu.resolution_u = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
        sp.points[i].radius = radii[i]
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    return link(bpy.data.objects.new("tube", cu), m)


def ellipsoid(loc, size, m, rot=(0, 0, 0), segs=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = size
    ob.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return ob


def cut(target, cutter):
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    cutter.hide_render = True
    cutter.hide_viewport = True


# ---------------------------------------------------------------- the parts

def skull(m, dark, x, length, height, snout=0.4, jaw=12.0, teeth=0, crack=False, gill=False, rng=None):
    """A fish's head, its back at `x`, facing +x: the cranium (tapering to the snout, its eye
    socket cut through), the lower jaw hinged open `jaw` degrees, teeth along both, the gill plate's
    rim behind. Returns the front tip's x."""
    rng = rng or random.Random(1)
    width = height * 0.62
    cx = x + length * 0.5
    head = ellipsoid((cx, 0, height * 0.08), (length * 0.5, width * 0.5, height * 0.5), m)
    # (a fish's head, not a ball: the brow sloping down to the snout, the front narrowed, the
    # cheeks flat, the crown a little ridged)
    bpy.context.view_layer.update()
    for v in head.data.vertices:
        t = (v.co.x + 1.0) * 0.5
        k = 1.0 - (0.25 + snout * 0.6) * max(0.0, t - 0.3) / 0.7
        v.co.y *= k * (0.85 + 0.15 * (1.0 - abs(v.co.z)))
        top = max(0.0, v.co.z)
        v.co.z = v.co.z * (0.55 + 0.45 * k) - (0.15 + snout * 0.25) * max(0.0, t - 0.45) * (1.0 + top)
        if v.co.z > 0.8 and abs(v.co.y) < 0.3:
            v.co.z += 0.08 * (1.0 - t)
    # (its eye: a socket right through, a ring of bone round it)
    eye_x = x + length * (0.62 + 0.08 * snout)
    eye_z = height * 0.22
    eye_r = height * 0.16
    hole = ellipsoid((eye_x, 0, eye_z), (eye_r, width, eye_r), m, segs=24)
    cut(head, hole)
    for side in (-1, 1):
        # (the socket's rim, raised a little on each cheek)
        bpy.ops.mesh.primitive_torus_add(major_radius=eye_r * 1.05, minor_radius=eye_r * 0.13,
            location=(eye_x, side * width * 0.3, eye_z), rotation=(math.pi / 2, 0, 0))
        ring = bpy.context.active_object
        ring.data.materials.append(m)
        bpy.ops.object.shade_smooth()
    # (ridges on the bone, snapped onto the skull's face: the gill plate's rim behind the cheek, a
    # brow over the eye)
    bpy.context.view_layer.update()
    inv = head.matrix_world.inverted()

    def on_skin(p, out=0.0):
        ok, loc, nrm, _ = head.closest_point_on_mesh(inv @ p)
        w = head.matrix_world @ loc
        return w + (head.matrix_world.to_3x3() @ nrm).normalized() * out if ok else p

    for side in (-1, 1):
        gill_pts = []
        for i in range(9):
            ang = math.radians(-70 + 140 * i / 8)
            gill_pts.append(on_skin(Vector((x + length * (0.3 - 0.06 * math.cos(ang)), side * width,
                height * 0.05 + math.sin(ang) * height * 0.42)), height * 0.01))
        tube(gill_pts, [height * 0.02] + [height * 0.034] * 7 + [height * 0.02], m)
        brow = [on_skin(Vector((eye_x + eye_r * math.cos(a), side * width, eye_z + eye_r * 1.25 * math.sin(a) + eye_r * 0.2)), height * 0.01)
            for a in [math.radians(d) for d in (200, 160, 120, 90, 60, 30)]]
        tube(brow, [height * 0.02, height * 0.03, height * 0.035, height * 0.035, height * 0.03, height * 0.02], m)
    # (the mouth: a wedge cut from the front's foot)
    bpy.ops.mesh.primitive_cube_add(location=(x + length * 1.02, 0, -height * 0.12),
        rotation=(0, math.radians(-14), 0))
    wedge = bpy.context.active_object
    wedge.scale = (length * 0.42, width, height * 0.09)
    cut(head, wedge)
    # (the lower jaw: a long tapering bone hinged under the cheek)
    hinge = Vector((x + length * 0.38, 0, -height * 0.22))
    a = math.radians(jaw)
    tip = hinge + Vector((math.cos(a), 0, -math.sin(a))) * length * 0.72
    for side in (-1, 1):
        tube([hinge + Vector((0, side * width * 0.28, 0)), hinge.lerp(tip, 0.5) + Vector((0, side * width * 0.24, -height * 0.02)),
            tip + Vector((0, side * width * 0.05, 0))], [height * 0.11, height * 0.08, height * 0.04], m)
    ellipsoid(tip, (height * 0.07, width * 0.14, height * 0.06), m)
    # (teeth: small cones along the upper edge and the jaw)
    for i in range(teeth):
        f = (i + 0.5) / teeth
        for side in (-1, 1):
            up = Vector((x + length * (0.62 + 0.36 * f), side * width * 0.2 * (1.1 - f), -height * 0.12 - 0.04 * height))
            low = hinge.lerp(tip, 0.35 + 0.6 * f) + Vector((0, side * width * 0.16 * (1.1 - f), height * 0.05))
            for at, d in ((up, -1), (low, 1)):
                bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=height * 0.035, depth=height * 0.12,
                    location=at + Vector((0, 0, d * height * 0.05)), rotation=(0 if d > 0 else math.pi, 0, 0))
                bpy.context.active_object.data.materials.append(m)
    if gill:
        # (the gill plate's rim: a crescent of bone behind the cheek, both sides)
        for side in (-1, 1):
            pts = []
            for i in range(7):
                t = i / 6
                ang = math.radians(-75 + 150 * t)
                pts.append(Vector((x + length * 0.2 + math.cos(ang) * length * 0.12, side * width * 0.42,
                    height * 0.05 + math.sin(ang) * height * 0.42)))
            tube(pts, [height * 0.035] * 3 + [height * 0.05] + [height * 0.035] * 3, m)
    if crack:
        # (a crack across the crown, dark in its depth)
        pts = [Vector((x + length * (0.3 + 0.08 * i), (rng.random() - 0.5) * width * 0.25, height * (0.56 - 0.05 * abs(i - 2))))
            for i in range(6)]
        tube(pts, [height * 0.022] * 6, dark)
    return x + length


def spine_path(x_from, x_to, bend, wave=0.0):
    """The backbone's line, head end at x_to: `bend` lifts (or drops) the tail end."""
    def at(t):
        # t 0 at the tail, 1 at the head
        x = x_from + (x_to - x_from) * t
        z = bend * (1.0 - t) ** 2 + wave * math.sin(t * math.pi * 2.0) * 0.5
        return Vector((x, 0, z))
    return at


def backbone(m, dark, path, n, depth, thick, rng, ribs=True, spines=True, missing=0.0, snapped=0.0,
             rib_curve=0.3, double=False, gaps=()):
    """`n` vertebrae along `path` (t 0 tail .. 1 head), each a spool; ribs down both sides (their
    length the body's depth there - deepest a third back from the head, tapering to the tail),
    spines up; `missing` of the ribs gone, `snapped` of them broken short. Returns the tail point."""
    for i in range(n):
        if i in gaps:
            continue
        t = i / max(n - 1, 1)
        p = path(t)
        q = path(min(1.0, t + 0.5 / n))
        tan = (q - p).normalized() if (q - p).length > 1e-6 else Vector((1, 0, 0))
        r = thick * (0.65 + 0.45 * t)
        seg = (path(min(1.0, t + 1.0 / max(n - 1, 1))) - p).length * 0.52
        # (the spool: a waisted drum, its rims a little wider)
        tube([p - tan * seg, p - tan * seg * 0.5, p, p + tan * seg * 0.5, p + tan * seg],
            [r * 1.12, r * 0.86, r * 0.78, r * 0.86, r * 1.12], m, res=8)
        if t > 0.94:
            continue
        shape = math.sin(min(1.0, t * 1.25) * math.pi * 0.5) ** 0.8
        long = depth * (0.25 + 0.75 * shape)
        up = Vector((0, 0, 1))
        back = Vector((-1, 0, 0))
        if spines:
            # (the spine above: long, curving back)
            tip = p + up * long * 0.78 + back * long * 0.42
            mid = p + up * long * 0.45 + back * long * 0.12
            tube([p + up * r, mid, tip], [r * 0.5, r * 0.34, r * 0.07], m)
        if not ribs or t < 0.12:
            continue
        for side in (-1, 1):
            if rng.random() < missing:
                continue
            k = 1.0 if rng.random() >= snapped else rng.uniform(0.3, 0.6)
            pts, rad = [], []
            for s in range(5):
                f = s / 4 * k
                # (curving out from the body, then down and back)
                pts.append(p + Vector((-long * (0.18 + rib_curve * 0.25) * f * f,
                    side * (r * 1.2 + long * 0.32 * math.sin(f * math.pi * 0.8)),
                    -r - long * f)))
                rad.append(r * (0.55 - 0.42 * f))
            tube(pts, rad, m)
            if k < 1.0:
                # (the break's end: a dark splinter)
                ellipsoid(pts[-1], (r * 0.18, r * 0.18, r * 0.24), dark, segs=10)
            if double and t > 0.3:
                pts2 = [pp + Vector((-long * 0.08, side * long * 0.05, long * 0.06)) for pp in pts]
                tube(pts2, [rr * 0.7 for rr in rad], m)
    return path(0.0)


def tail(m, at, size, rng, fork=0.5, lift=0.0, rays=6, droop=0.0):
    """A forked fin of rays fanning from `at` (the last vertebra) back along -x - its two lobes
    pointed, the notch between them `fork` deep - with its membrane between the rays (thin, a
    little thicker at the root); the whole fin tipped up by `lift`, down by `droop`."""
    base = Vector(at)
    tilt = (lift - droop) * 0.45
    tips = []
    n = rays * 2 + 1
    for i in range(n):
        u = -1.0 + 2.0 * i / (n - 1)
        ang = u * math.radians(55) + tilt
        reach = size * (1.0 - fork * 0.7 * (1.0 - abs(u)) ** 1.3)
        tip = base + Vector((-math.cos(ang) * reach, 0, math.sin(ang) * reach))
        tips.append(tip)
        mid = base.lerp(tip, 0.5) + Vector((0, 0, u * size * 0.04))
        tube([base, mid, tip], [size * 0.05, size * 0.035, size * 0.012], m)
    verts, faces = [base + Vector((0, -size * 0.03, 0)), base + Vector((0, size * 0.03, 0))], []
    for tip in tips:
        verts.append(tip + Vector((0, -size * 0.008, 0)))
        verts.append(tip + Vector((0, size * 0.008, 0)))
    for i in range(len(tips) - 1):
        a, b = 2 + i * 2, 2 + (i + 1) * 2
        faces.append((0, a, b))
        faces.append((1, b + 1, a + 1))
        faces.append((a, a + 1, b + 1, b))
    me = bpy.data.meshes.new("fin")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    ob = link(bpy.data.objects.new("fin", me), m)
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = size * 0.015
    return ob


def small_fin(m, at, size, up=True, rays=4):
    for i in range(rays):
        f = i / max(rays - 1, 1)
        ang = math.radians(100 + 50 * f)
        d = Vector((math.cos(ang), 0, math.sin(ang) * (1 if up else -1)))
        tube([at, at + d * size * (0.55 + 0.45 * (1 - f))], [size * 0.06, size * 0.012], m)


# ---------------------------------------------------------------- the sixteen

def design(name, m, dark):
    rng = random.Random(name)
    kind, size = name.split("_")[1], name.split("_")[2]
    if kind == "whole":
        spec = {
            "s": dict(L=4.0, H=0.8, sn=0.55, jaw=6, teeth=0, n=13, depth=0.45, thick=0.08, bend=0.05, fork=0.8, tail=0.6, lift=0.0),
            "m": dict(L=4.6, H=1.2, sn=0.3, jaw=14, teeth=0, n=12, depth=0.8, thick=0.11, bend=0.85, fork=0.6, tail=0.8, lift=0.55),
            "l": dict(L=4.8, H=1.5, sn=0.15, jaw=20, teeth=4, n=11, depth=0.95, thick=0.12, bend=-0.6, fork=0.5, tail=0.85, lift=-0.5),
            "xl": dict(L=5.6, H=1.45, sn=0.35, jaw=16, teeth=6, n=17, depth=0.95, thick=0.13, bend=0.25, fork=0.85, tail=0.95, lift=0.0, double=True),
        }[size]
        head_len = spec["H"] * 1.45
        x_head = spec["L"] * 0.5 - head_len
        skull(m, dark, x_head, head_len, spec["H"], spec["sn"], spec["jaw"], spec["teeth"], rng=rng)
        path = spine_path(-spec["L"] * 0.5, x_head + head_len * 0.12, spec["bend"])
        end = backbone(m, dark, path, spec["n"], spec["depth"], spec["thick"], rng, double=spec.get("double", False))
        tail(m, end, spec["tail"], rng, spec["fork"], lift=max(0, spec["lift"]), droop=max(0, -spec["lift"]))
    elif kind == "spine":
        spec = {
            "s": dict(L=2.6, n=9, depth=0.5, thick=0.1, bend=0.1, tail=0.55, fork=0.7, lift=0.0),
            "m": dict(L=3.6, n=12, depth=0.7, thick=0.11, bend=0.35, tail=0.7, fork=0.6, lift=0.3),
            "l": dict(L=4.2, n=14, depth=0.85, thick=0.12, bend=0.9, tail=0.8, fork=0.5, lift=0.6),
            "xl": dict(L=5.2, n=19, depth=1.0, thick=0.14, bend=-0.3, tail=0.95, fork=0.85, lift=-0.2, double=True),
        }[size]
        path = spine_path(-spec["L"] * 0.5, spec["L"] * 0.5, spec["bend"])
        end = backbone(m, dark, path, spec["n"], spec["depth"], spec["thick"], rng, double=spec.get("double", False))
        tail(m, end, spec["tail"], rng, spec["fork"], lift=max(0, spec["lift"]), droop=max(0, -spec["lift"]))
        # (where the head was: the first vertebra's face, a little ragged)
        ellipsoid(path(1.0) + Vector((0.05, 0, 0)), (0.06, spec["thick"] * 1.5, spec["thick"] * 1.5), dark, segs=12)
    elif kind == "skull":
        spec = {
            "s": dict(L=1.0, H=0.85, sn=0.2, jaw=8, teeth=0),
            "m": dict(L=1.5, H=0.95, sn=0.7, jaw=10, teeth=0),
            "l": dict(L=1.4, H=1.2, sn=0.25, jaw=26, teeth=5),
            "xl": dict(L=1.7, H=1.45, sn=0.1, jaw=22, teeth=7),
        }[size]
        x0 = -spec["L"] * 0.5
        skull(m, dark, x0, spec["L"], spec["H"], spec["sn"], spec["jaw"], spec["teeth"], crack=(size == "xl"), rng=rng)
        # (the neck's stub: two vertebrae behind)
        path = spine_path(x0 - spec["H"] * 0.3, x0 + spec["L"] * 0.15, 0.0)
        backbone(m, dark, path, 3, spec["H"] * 0.4, spec["H"] * 0.09, rng, ribs=False)
    else:  # broken
        if size == "s":
            # (a head and three vertebrae, two ribs snapped)
            skull(m, dark, 0.2, 1.1, 0.8, 0.4, 10, 0, rng=rng)
            path = spine_path(-1.1, 0.32, 0.05)
            backbone(m, dark, path, 5, 0.55, 0.08, rng, snapped=0.7, missing=0.3)
            ellipsoid(path(0.0), (0.05, 0.1, 0.1), dark, segs=10)
        elif size == "m":
            # (the front half: head and half the spine, snapped off behind)
            skull(m, dark, 0.6, 1.2, 1.0, 0.3, 16, 0, rng=rng)
            path = spine_path(-1.8, 0.75, 0.15)
            backbone(m, dark, path, 9, 0.8, 0.09, rng, snapped=0.35, missing=0.2)
            ellipsoid(path(0.0) + Vector((-0.05, 0, 0)), (0.07, 0.13, 0.13), dark, segs=12)
        elif size == "l":
            # (the back half: spine and tail, no head, ribs half gone)
            path = spine_path(-2.0, 1.4, 0.7)
            end = backbone(m, dark, path, 11, 0.85, 0.1, rng, missing=0.35, snapped=0.35)
            tail(m, end, 0.8, rng, 0.6, lift=0.5)
            ellipsoid(path(1.0) + Vector((0.06, 0, 0)), (0.08, 0.15, 0.15), dark, segs=12)
        else:
            # (a big skeleton in pieces: a cracked skull, the spine broken in two, ribs missing)
            skull(m, dark, 1.5, 1.5, 1.2, 0.25, 30, 5, crack=True, rng=rng)
            path = spine_path(-2.6, 1.68, 0.4)
            end = backbone(m, dark, path, 16, 0.95, 0.11, rng, missing=0.3, snapped=0.3, gaps=(7, 8))
            tail(m, end, 0.9, rng, 0.75, lift=0.3, rays=5)
            gap = path(7.5 / 15)
            ellipsoid(gap + Vector((0.1, 0, 0)), (0.08, 0.14, 0.14), dark, segs=12)
            ellipsoid(gap + Vector((-0.1, 0, 0)), (0.08, 0.14, 0.14), dark, segs=12)


# ---------------------------------------------------------------- the picture

def stage(yaw):
    """Everything turned three-quarter on, the camera fitted round it, soft light, white about."""
    obs = [o for o in bpy.context.scene.objects if o.type in ("MESH", "CURVE") and not o.hide_render]
    pivot = bpy.data.objects.new("pivot", None)
    bpy.context.collection.objects.link(pivot)
    for o in bpy.context.scene.objects:
        if o != pivot and o.parent is None:
            o.parent = pivot
    pivot.rotation_euler = (math.radians(4), 0, math.radians(yaw))
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in obs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    mid = (lo + hi) * 0.5
    span = max(hi.x - lo.x, hi.z - lo.z, (hi.y - lo.y) * 0.6)
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.lens = 60
    fov = 2 * math.atan(18 / 60)
    dist = span * 0.5 / math.tan(fov / 2) * 1.08
    view = Vector((0.0, -1.0, 0.45)).normalized()
    cam.location = mid + view * dist
    cam.rotation_euler = (-view).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    fit(cam, view, fov)
    for name, rot, energy, kind, size in (("key", (48, 10, -42), 2.4, "SUN", 0), ("fill", (65, 0, 145), 0.45, "SUN", 0),
            ("rim", (118, 0, 15), 1.3, "SUN", 0)):
        L = bpy.data.objects.new(name, bpy.data.lights.new(name, kind))
        L.data.energy = energy
        L.data.angle = math.radians(18)
        L.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(L)
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.22
    sc.world = w
    sc.render.film_transparent = True
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 96
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        sc.cycles.use_denoising = False
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    sc.view_settings.view_transform = "Standard"


def fit(cam, view, fov, fill=0.84):
    """The camera moved and drawn in so the skeleton - every point of it as it renders - sits in
    the middle of the picture, filling `fill` of it."""
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in bpy.context.scene.objects:
        if o.type not in ("MESH", "CURVE") or o.hide_render:
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        step = max(1, len(me.vertices) // 400)
        pts += [mw @ me.vertices[i].co for i in range(0, len(me.vertices), step)]
        ev.to_mesh_clear()
    half = math.tan(fov / 2)
    for _ in range(4):
        bpy.context.view_layer.update()
        inv = cam.matrix_world.inverted()
        xs, ys, zs = [], [], []
        for p in pts:
            c = inv @ p
            d = max(-c.z, 1e-3)
            xs.append(c.x / d / half)
            ys.append(c.y / d / half)
            zs.append(d)
        cx = (max(xs) + min(xs)) * 0.5
        cy = (max(ys) + min(ys)) * 0.5
        span = max(max(xs) - min(xs), max(ys) - min(ys)) * 0.5
        depth = sum(zs) / len(zs)
        right = cam.matrix_world.to_3x3() @ Vector((1, 0, 0))
        up = cam.matrix_world.to_3x3() @ Vector((0, 1, 0))
        cam.location += right * cx * depth * half + up * cy * depth * half
        cam.location -= view * depth * (1.0 - span / fill)


def render(name, out):
    fresh()
    m = material("bone", IVORY)
    dark = material("dark", DARK, 0.8)
    design(name, m, dark)
    stage(yaw={"whole": 32, "spine": 32, "skull": 24, "broken": 30}[name.split("_")[1]])
    path = os.path.join(out, name + ".png")
    raw = path + ".raw.png"
    bpy.context.scene.render.filepath = raw
    bpy.ops.render.render(write_still=True)
    # (on plain white - what the image-to-3D tools read best)
    from PIL import Image
    im = Image.open(raw).convert("RGBA")
    white = Image.new("RGBA", im.size, (255, 255, 255, 255))
    Image.alpha_composite(white, im).convert("RGB").save(path)
    os.remove(raw)
    print("made", path, flush=True)


def main():
    out = sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    only = os.environ.get("ONLY", "")
    names = ["bone_%s_%s" % (k, s) for k in ("whole", "spine", "skull", "broken") for s in ("s", "m", "l", "xl")]
    for n in names:
        if only and n not in only.split(","):
            continue
        render(n, out)
    os._exit(0)


if __name__ == "__main__":
    main()
