"""Every fish species (FishData.FISH) as a picture, from a fish built here.

User request: the fish need a look of their own. Until the user's photos
come (tools/fish_from_photo.py takes over a species once it has one),
each is modelled from its body type - a loft of elliptical sections along
its length (the body's height, width and belly along it), fins cut from
outlines (forked, crescent, rounded or lobed tails; dorsal, anal and
pectoral fins), eyes, and the type's own features (a catfish's barbels,
a billfish's sword, a hammerhead's head, a sturgeon's plates...) - painted
from its colours and pattern (back to belly, spots, bars, stripes,
speckles, scales, koi blotches, bones), lit and rendered side-on, a little
from above, onto a transparent 256x128 picture.

  python tools/render_fish.py [id ...]

reads the species from scripts/fish_data.gd, writes
assets/sprites/fish/<id>.png.
"""
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "fish")
SIZE = (256, 128)
RINGS = 48
SEGMENTS = 20

# Body types: height and width (share of the length) at their widest, where
# along it (0 tail .. 1 snout), how blunt the head (0 pointed .. 1 blunt),
# the tail stalk's thickness (share of the height), how much it hangs
# below the midline (a belly), the tail fin, the fins, extras.
BODIES = {
    "carp": dict(h=0.32, w=0.16, peak=0.55, blunt=0.55, stalk=0.34, belly=0.05, tail="fork", dorsal=(0.35, 0.72, 0.14), anal=(0.2, 0.3, 0.1), pect=0.12, extras=["barbels_small"]),
    "trout": dict(h=0.22, w=0.12, peak=0.52, blunt=0.35, stalk=0.38, belly=0.02, tail="notch", dorsal=(0.45, 0.62, 0.12), anal=(0.2, 0.32, 0.08), pect=0.1, extras=["adipose"]),
    "bass": dict(h=0.3, w=0.14, peak=0.5, blunt=0.45, stalk=0.34, belly=0.02, tail="notch", dorsal=(0.3, 0.72, 0.14), anal=(0.18, 0.34, 0.1), pect=0.1, extras=["spiny", "big_mouth"]),
    "catfish": dict(h=0.2, w=0.2, peak=0.72, blunt=0.9, stalk=0.45, belly=0.03, tail="notch", dorsal=(0.62, 0.72, 0.12), anal=(0.12, 0.5, 0.07), pect=0.1, extras=["barbels", "flat_head"]),
    "eel": dict(h=0.08, w=0.07, peak=0.6, blunt=0.5, stalk=0.8, belly=0.0, tail="point", dorsal=(0.02, 0.62, 0.035), anal=(0.02, 0.5, 0.03), pect=0.04, extras=[]),
    "tilapia": dict(h=0.38, w=0.13, peak=0.55, blunt=0.6, stalk=0.34, belly=0.03, tail="round", dorsal=(0.22, 0.76, 0.14), anal=(0.18, 0.36, 0.12), pect=0.12, extras=["spiny"]),
    "goby": dict(h=0.17, w=0.15, peak=0.72, blunt=0.85, stalk=0.5, belly=0.02, tail="round", dorsal=(0.3, 0.66, 0.12), anal=(0.25, 0.45, 0.07), pect=0.14, extras=["big_eyes"]),
    "pike": dict(h=0.16, w=0.1, peak=0.5, blunt=0.1, stalk=0.5, belly=0.01, tail="fork", dorsal=(0.18, 0.32, 0.12), anal=(0.16, 0.3, 0.1), pect=0.08, extras=["duck_snout"]),
    "angel": dict(h=0.5, w=0.08, peak=0.55, blunt=0.6, stalk=0.3, belly=0.0, tail="fan", dorsal=(0.3, 0.7, 0.3), anal=(0.3, 0.7, 0.3), pect=0.08, extras=["streamers"]),
    "arowana": dict(h=0.2, w=0.09, peak=0.45, blunt=0.3, stalk=0.5, belly=0.0, tail="round", dorsal=(0.1, 0.35, 0.12), anal=(0.08, 0.45, 0.12), pect=0.1, extras=["upturned", "barbels_chin"]),
    "sturgeon": dict(h=0.15, w=0.14, peak=0.55, blunt=0.05, stalk=0.35, belly=0.02, tail="shark", dorsal=(0.22, 0.3, 0.1), anal=(0.18, 0.26, 0.07), pect=0.12, extras=["plates", "long_snout"]),
    "gar": dict(h=0.12, w=0.1, peak=0.5, blunt=0.05, stalk=0.55, belly=0.0, tail="round", dorsal=(0.12, 0.22, 0.1), anal=(0.12, 0.22, 0.09), pect=0.07, extras=["beak"]),
    "coelacanth": dict(h=0.3, w=0.15, peak=0.55, blunt=0.6, stalk=0.5, belly=0.02, tail="tri", dorsal=(0.55, 0.66, 0.16), anal=(0.25, 0.32, 0.12), pect=0.16, extras=["lobes"]),
    "betta": dict(h=0.24, w=0.1, peak=0.6, blunt=0.55, stalk=0.5, belly=0.0, tail="flowing", dorsal=(0.18, 0.5, 0.3), anal=(0.08, 0.55, 0.35), pect=0.08, extras=[]),
    "mackerel": dict(h=0.2, w=0.12, peak=0.55, blunt=0.3, stalk=0.2, belly=0.01, tail="fork", dorsal=(0.55, 0.68, 0.1), anal=(0.25, 0.35, 0.06), pect=0.08, extras=["finlets"]),
    "tuna": dict(h=0.28, w=0.2, peak=0.52, blunt=0.3, stalk=0.14, belly=0.02, tail="crescent", dorsal=(0.52, 0.66, 0.14), anal=(0.3, 0.4, 0.1), pect=0.14, extras=["finlets"]),
    "bream": dict(h=0.42, w=0.13, peak=0.58, blunt=0.75, stalk=0.3, belly=0.02, tail="fork", dorsal=(0.25, 0.72, 0.14), anal=(0.2, 0.38, 0.1), pect=0.13, extras=["spiny"]),
    "grouper": dict(h=0.3, w=0.18, peak=0.5, blunt=0.5, stalk=0.4, belly=0.03, tail="round", dorsal=(0.25, 0.72, 0.12), anal=(0.2, 0.34, 0.1), pect=0.13, extras=["spiny", "big_mouth"]),
    "ribbon": dict(h=0.08, w=0.03, peak=0.8, blunt=0.2, stalk=0.02, belly=0.0, tail="none", dorsal=(0.05, 0.88, 0.035), anal=(0.0, 0.0, 0.0), pect=0.05, extras=["fangs"]),
    "ribbon_short": dict(h=0.1, w=0.07, peak=0.55, blunt=0.1, stalk=0.25, belly=0.0, tail="fork", dorsal=(0.22, 0.3, 0.06), anal=(0.2, 0.28, 0.05), pect=0.06, extras=["beak_short", "finlets"]),
    "flat": dict(h=0.5, w=0.07, peak=0.5, blunt=0.7, stalk=0.3, belly=0.0, tail="round", dorsal=(0.08, 0.92, 0.07), anal=(0.08, 0.8, 0.07), pect=0.06, extras=["flat"]),
    "puffer": dict(h=0.5, w=0.45, peak=0.55, blunt=0.9, stalk=0.3, belly=0.08, tail="round", dorsal=(0.22, 0.28, 0.1), anal=(0.2, 0.26, 0.1), pect=0.12, extras=["spines"]),
    "billfish": dict(h=0.2, w=0.13, peak=0.6, blunt=0.3, stalk=0.12, belly=0.01, tail="crescent", dorsal=(0.45, 0.78, 0.2), anal=(0.25, 0.35, 0.09), pect=0.14, extras=["bill"]),
    "sunfish": dict(h=0.7, w=0.2, peak=0.5, blunt=0.9, stalk=0.8, belly=0.0, tail="clavus", dorsal=(0.12, 0.26, 0.3), anal=(0.12, 0.26, 0.3), pect=0.1, extras=[]),
    "shark": dict(h=0.2, w=0.16, peak=0.6, blunt=0.3, stalk=0.2, belly=0.02, tail="shark", dorsal=(0.5, 0.64, 0.2), anal=(0.25, 0.3, 0.06), pect=0.2, extras=["hammer", "gills"]),
    "mahi": dict(h=0.3, w=0.1, peak=0.78, blunt=0.95, stalk=0.2, belly=0.0, tail="fork", dorsal=(0.12, 0.95, 0.12), anal=(0.12, 0.5, 0.08), pect=0.1, extras=[]),
    "trevally": dict(h=0.38, w=0.14, peak=0.55, blunt=0.7, stalk=0.12, belly=0.03, tail="crescent", dorsal=(0.3, 0.55, 0.14), anal=(0.25, 0.45, 0.12), pect=0.16, extras=["scutes"]),
}


def read_species():
    """FishData.FISH out of the GDScript: id -> colors, pattern, body."""
    src = open(os.path.join(ROOT, "scripts", "fish_data.gd"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'"(\w+)": \{"name": "([^"]+)".*?"colors": \[(.*?)\], "pattern": "(\w+)", "body": "(\w+)"\}',
                         src, re.S):
        cols = [tuple(float(v) for v in c.split(",")) for c in re.findall(r"Color\(([^)]*)\)", m.group(3))]
        out[m.group(1)] = {"name": m.group(2), "colors": cols, "pattern": m.group(4), "body": m.group(5)}
    return out


def lin(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# --- The model ------------------------------------------------------------------

def profile(b, t):
    """Height, width, centre height at t (0 tail tip .. 1 snout), share of length."""
    peak = b["peak"]
    if t < peak:
        u = t / peak
        # From the tail stalk up to the widest.
        f = b["stalk"] + (1 - b["stalk"]) * math.sin(u * math.pi / 2) ** 1.4
    else:
        u = (t - peak) / (1 - peak)
        # Down to the snout: blunt heads stay full until the end.
        e = 1.0 + 3.0 * b["blunt"]
        f = max(0.0, 1 - u ** e) ** 0.5
    f = max(f, 0.02)
    h = b["h"] * f
    w = b["w"] * f
    c = -b["belly"] * math.sin(t * math.pi) * f
    return h, w, c


def mesh_from(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def body(b):
    verts, faces = [], []
    for i in range(RINGS + 1):
        t = i / RINGS
        h, w, c = profile(b, t)
        x = t - 0.5
        for j in range(SEGMENTS):
            a = j / SEGMENTS * math.tau
            # A little squarer than an ellipse, fish-like.
            ca, sa = math.cos(a), math.sin(a)
            verts.append((x, w / 2 * math.copysign(abs(ca) ** 0.85, ca), c + h / 2 * math.copysign(abs(sa) ** 0.9, sa)))
    for i in range(RINGS):
        for j in range(SEGMENTS):
            a, bb = i * SEGMENTS + j, i * SEGMENTS + (j + 1) % SEGMENTS
            faces.append((a, bb, bb + SEGMENTS, a + SEGMENTS))
    tail_c = len(verts)
    verts.append((-0.5, 0, 0))
    nose_c = len(verts)
    h, w, c = profile(b, 1.0)
    verts.append((0.5 + 0.004, 0, c))
    for j in range(SEGMENTS):
        faces.append((tail_c, (j + 1) % SEGMENTS, j))
        faces.append((nose_c, RINGS * SEGMENTS + j, RINGS * SEGMENTS + (j + 1) % SEGMENTS))
    o = mesh_from("body", verts, faces)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def fin(name, outline, y=0.0, thick=0.004):
    """A flat fin from an outline in the x-z plane, a hair thick."""
    verts = [(x, y + thick / 2, z) for x, z in outline] + [(x, y - thick / 2, z) for x, z in outline]
    n = len(outline)
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    for i in range(n):
        faces.append((i, (i + 1) % n, n + (i + 1) % n, n + i))
    return mesh_from(name, verts, faces)


def top_at(b, t):
    h, w, c = profile(b, t)
    return c + h / 2


def bottom_at(b, t):
    h, w, c = profile(b, t)
    return c - h / 2


def tail(b):
    kind = b["tail"]
    t0 = -0.5
    h = max(b["h"] * 0.9, 0.12)
    if kind == "none" or kind == "point":
        return None
    shapes = {
        "fork": [(0.02, 0.02), (-0.17, h * 0.75), (-0.13, h * 0.12), (-0.09, 0.0), (-0.13, -h * 0.12), (-0.17, -h * 0.75), (0.02, -0.02)],
        "notch": [(0.02, 0.03), (-0.14, h * 0.6), (-0.12, 0.0), (-0.14, -h * 0.6), (0.02, -0.03)],
        "round": [(0.02, 0.03), (-0.1, h * 0.45), (-0.15, h * 0.2), (-0.16, 0.0), (-0.15, -h * 0.2), (-0.1, -h * 0.45), (0.02, -0.03)],
        "crescent": [(0.02, 0.015), (-0.16, h * 0.95), (-0.1, h * 0.25), (-0.07, 0.0), (-0.1, -h * 0.25), (-0.16, -h * 0.95), (0.02, -0.015)],
        "fan": [(0.02, 0.04), (-0.12, h * 0.5), (-0.18, h * 0.35), (-0.2, 0.0), (-0.18, -h * 0.35), (-0.12, -h * 0.5), (0.02, -0.04)],
        "tri": [(0.02, 0.05), (-0.12, h * 0.55), (-0.16, 0.05), (-0.22, 0.0), (-0.16, -0.05), (-0.12, -h * 0.55), (0.02, -0.05)],
        "flowing": [(0.02, 0.05), (-0.2, h * 1.1), (-0.32, h * 0.5), (-0.34, 0.0), (-0.32, -h * 0.5), (-0.2, -h * 1.1), (0.02, -0.05)],
        "shark": [(0.03, 0.02), (-0.16, h * 0.9), (-0.12, h * 0.1), (-0.09, -h * 0.2), (-0.11, -h * 0.45), (0.02, -0.02)],
        "clavus": [(0.02, h * 0.45), (-0.05, h * 0.35), (-0.07, 0.0), (-0.05, -h * 0.35), (0.02, -h * 0.45)],
    }
    return fin("tail", [(t0 + x, z) for x, z in shapes[kind]])


def edge_fin(b, name, span, height, top=True, jag=False):
    t0, t1 = span
    if t1 <= t0 or height <= 0:
        return None
    pts = []
    steps = 10
    for k in range(steps + 1):
        t = t0 + (t1 - t0) * k / steps
        pts.append((t - 0.5, (top_at(b, t) - 0.01) if top else (bottom_at(b, t) + 0.01)))
    out = []
    for k in range(steps, -1, -1):
        t = t0 + (t1 - t0) * k / steps
        u = k / steps
        # Tallest at the front (spiny) or in the middle, sweeping back.
        shape = math.sin(u * math.pi) ** 0.6 if not jag else (0.4 + 0.6 * u) * (0.75 + 0.25 * math.cos(k * 1.9))
        z = height * shape
        base = top_at(b, t) if top else bottom_at(b, t)
        out.append((t - 0.5 - 0.03 * shape, base + (z if top else -z)))
    return fin(name, pts + out)


def pectoral(b, size, side):
    t = min(b["peak"] + 0.12, 0.85)
    h, w, c = profile(b, t)
    x = t - 0.5
    z = c - h * 0.15
    y = side * (w / 2 + 0.003)
    # A rounded fan, swept back.
    pts = [(x, z)]
    for k in range(7):
        a = math.radians(200 + k * 18)
        pts.append((x - size * 0.7 + math.cos(a) * size * 0.55, z - size * 0.35 + math.sin(a) * size * 0.4))
    pts.append((x - 0.005, z - size * 0.12))
    return fin("pect", pts, y=y)


def eye(b, big=False):
    t = 0.93 if b["blunt"] < 0.6 else 0.9
    if "duck_snout" in b["extras"] or "beak" in b["extras"] or "long_snout" in b["extras"] or "bill" in b["extras"]:
        t = 0.84
    h, w, c = profile(b, t)
    r = max(0.012, min(0.03, h * 0.14)) * (1.4 if big else 1.0)
    out = []
    for side in (1, -1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(t - 0.5, side * w / 2 * 0.85, c + h * 0.18))
        e = bpy.context.active_object
        e.name = "eye"
        out.append(e)
    return out


def extras(b):
    parts = []
    ex = b["extras"]

    def rod(name, a, bb, r):
        a, bb = Vector(a), Vector(bb)
        d = bb - a
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + bb) / 2, vertices=8)
        o = bpy.context.active_object
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        o.name = name
        parts.append(o)

    h1, w1, c1 = profile(b, 0.97)
    nose = (0.5, 0.0, c1)
    if "barbels" in ex:
        for s in (1, -1):
            rod("fin_barbel", (0.48, s * 0.03, c1 + 0.01), (0.36, s * 0.14, c1 - 0.06), 0.004)
            rod("fin_barbel", (0.49, s * 0.02, c1 - 0.02), (0.42, s * 0.06, c1 - 0.1), 0.003)
    if "barbels_small" in ex:
        for s in (1, -1):
            rod("fin_barbel", (0.49, s * 0.015, c1 - 0.01), (0.46, s * 0.03, c1 - 0.05), 0.003)
    if "barbels_chin" in ex:
        for s in (1, -1):
            rod("fin_barbel", (0.49, s * 0.01, c1 - 0.02), (0.56, s * 0.02, c1 - 0.02), 0.004)
    if "bill" in ex:
        rod("bill", (0.49, 0, c1 + 0.005), (0.78, 0, c1 + 0.01), 0.012)
    if "beak" in ex:
        rod("bill", (0.48, 0, c1), (0.66, 0, c1), 0.018)
    if "beak_short" in ex:
        rod("bill", (0.48, 0, c1), (0.56, 0, c1), 0.01)
    if "long_snout" in ex:
        rod("bill", (0.47, 0, c1), (0.62, 0, c1 + 0.01), 0.022)
    if "duck_snout" in ex:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(0.53, 0, c1))
        o = bpy.context.active_object
        o.scale = (1.4, 0.7, 0.35)
        o.name = "snout"
        parts.append(o)
    if "hammer" in ex:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(0.5, 0, c1 + 0.01))
        o = bpy.context.active_object
        o.scale = (0.7, 3.6, 0.35)
        o.name = "hammer"
        parts.append(o)
    if "plates" in ex:
        for k in range(9):
            t = 0.2 + k * 0.08
            h, w, c = profile(b, t)
            for zz, yy in ((c + h / 2, 0), (c, w / 2)):
                for s in ((1, -1) if yy else (1,)):
                    bpy.ops.mesh.primitive_cone_add(radius1=0.014, depth=0.02, vertices=4,
                                                    location=(t - 0.5, s * yy, zz))
                    o = bpy.context.active_object
                    o.rotation_euler = (math.pi / 2 * (1 if yy else 0) * s, 0, 0)
                    o.name = "plate"
                    parts.append(o)
    if "spines" in ex:
        rng = np.random.default_rng(2)
        for _ in range(60):
            t = rng.uniform(0.25, 0.85)
            a = rng.uniform(0, math.tau)
            h, w, c = profile(b, t)
            p = Vector((t - 0.5, w / 2 * math.cos(a), c + h / 2 * math.sin(a)))
            nrm = Vector((0, math.cos(a), math.sin(a)))
            rod("spine", p, p + nrm * 0.03, 0.003)
    if "finlets" in ex:
        for k in range(5):
            t = 0.08 + k * 0.045
            for top in (True, False):
                z = top_at(b, t) if top else bottom_at(b, t)
                f = fin("fin_let", [(t - 0.5, z), (t - 0.5 - 0.02, z + (0.02 if top else -0.02)), (t - 0.5 - 0.025, z)])
                parts.append(f)
    if "adipose" in ex:
        z = top_at(b, 0.2)
        parts.append(fin("fin_adipose", [(-0.28, z - 0.005), (-0.31, z + 0.02), (-0.34, z - 0.005)]))
    if "lobes" in ex:
        for t, top in ((0.3, True), (0.28, False), (0.6, False)):
            z = top_at(b, t) if top else bottom_at(b, t)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.03, location=(t - 0.5, 0, z + (0.02 if top else -0.02)))
            o = bpy.context.active_object
            o.scale = (1.4, 0.5, 0.8)
            o.name = "fin_lobe"
            parts.append(o)
    if "streamers" in ex:
        for s in (1, -1):
            rod("fin_streamer", (0.1, s * 0.02, bottom_at(b, 0.6)), (-0.05, s * 0.02, bottom_at(b, 0.6) - 0.3), 0.004)
    return parts


def build(sp):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    b = dict(BODIES[sp["body"]])
    if sp["body"] == "shark" and sp["name"] != "鎚頭鯊":
        b["extras"] = [e for e in b["extras"] if e != "hammer"]
    parts = [body(b)]
    for f in (tail(b),
              edge_fin(b, "fin_dorsal", b["dorsal"][:2], b["dorsal"][2], True, jag="spiny" in b["extras"]),
              edge_fin(b, "fin_anal", b["anal"][:2], b["anal"][2], False),
              pectoral(b, b["pect"], 1), pectoral(b, b["pect"], -1)):
        if f is not None:
            parts.append(f)
    eyes = eye(b, big="big_eyes" in b["extras"])
    parts += extras(b)
    if sp["pattern"] == "blotch" and "雙頭" in sp["name"]:
        # The mutant: a second head growing up out of the first.
        head = body(b)
        head.name = "head2"
        head.location = (0.12, 0.02, b["h"] * 0.45)
        head.rotation_euler = (0.25, 0, 0.45)
        head.scale = (0.55, 0.9, 0.9)
        parts.append(head)
        for side in (1, -1):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.022, location=(0.36, 0.035 * side, b["h"] * 0.78))
            e = bpy.context.active_object
            e.name = "eye"
            eyes.append(e)
    return parts, eyes, b


# --- Paint ------------------------------------------------------------------------

def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def skin(sp, fins=False, gill_x=0.3, gill_h=0.1):
    back, belly, accent = [lin(c) for c in sp["colors"]]
    pat = sp["pattern"]
    mat = bpy.data.materials.new("fins" if fins else "skin")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = 0.45
    coord = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(coord.outputs['Object'], sep.inputs[0])
    L = nt.links.new

    def mix(a, bcol, fac, blend='MIX'):
        m = nt.nodes.new('ShaderNodeMix')
        m.data_type = 'RGBA'
        m.blend_type = blend
        if isinstance(a, tuple):
            m.inputs[6].default_value = (*a, 1)
        else:
            L(a, m.inputs[6])
        if isinstance(bcol, tuple):
            m.inputs[7].default_value = (*bcol, 1)
        else:
            L(bcol, m.inputs[7])
        if isinstance(fac, float):
            m.inputs['Factor'].default_value = fac
        else:
            L(fac, m.inputs['Factor'])
        return m.outputs[2]

    def ramp(src, a, bb):
        r = nt.nodes.new('ShaderNodeMapRange')
        r.inputs['From Min'].default_value = a
        r.inputs['From Max'].default_value = bb
        L(src, r.inputs['Value'])
        return r.outputs['Result']

    if fins:
        col = mix(accent, back, 0.3)
        if pat in ("gradient", "koi"):
            col = mix(accent, belly, 0.2)
        # Fin rays: fine dark lines fanning back, the fin paler at its edge.
        rays = nt.nodes.new('ShaderNodeTexWave')
        rays.inputs['Scale'].default_value = 60.0
        rays.bands_direction = 'X'
        L(coord.outputs['Object'], rays.inputs['Vector'])
        col = mix(col, mix(col, (0.0, 0.0, 0.0), 0.5), ramp(rays.outputs['Fac'], 0.75, 0.95))
        bsdf.inputs['Alpha'].default_value = 0.8
        L(col, bsdf.inputs['Base Color'])
        return mat
    # Back to belly (the z of the body, object space).
    col = mix(back, belly, ramp(sep.outputs['Z'], 0.03, -0.06))
    x, z = sep.outputs['X'], sep.outputs['Z']
    if pat == "spots" or pat == "speckle":
        vor = nt.nodes.new('ShaderNodeTexVoronoi')
        vor.inputs['Scale'].default_value = 26.0 if pat == "spots" else 60.0
        L(coord.outputs['Object'], vor.inputs['Vector'])
        dots = ramp(vor.outputs['Distance'], 0.22 if pat == "spots" else 0.16, 0.12 if pat == "spots" else 0.08)
        # Spots on the back and flanks, fewer on the belly.
        col = mix(col, accent, dots)
    elif pat == "bars":
        wave = nt.nodes.new('ShaderNodeMath')
        wave.operation = 'SINE'
        mul = nt.nodes.new('ShaderNodeMath')
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = 34.0
        L(x, mul.inputs[0])
        L(mul.outputs[0], wave.inputs[0])
        col = mix(col, mix(col, accent, 0.6), ramp(wave.outputs[0], 0.4, 0.85))
    elif pat == "stripe":
        band = nt.nodes.new('ShaderNodeMath')
        band.operation = 'ABSOLUTE'
        L(z, band.inputs[0])
        col = mix(col, accent, ramp(band.outputs[0], 0.018, 0.006))
    elif pat in ("koi", "blotch"):
        noise = nt.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 7.0 if pat == "koi" else 14.0
        noise.inputs['Detail'].default_value = 2.0
        L(coord.outputs['Object'], noise.inputs['Vector'])
        col = mix(col, accent, ramp(noise.outputs['Fac'], 0.5, 0.56))
    elif pat == "gradient":
        # A bright band along the flank, between back and belly.
        band = nt.nodes.new('ShaderNodeMath')
        band.operation = 'ABSOLUTE'
        L(z, band.inputs[0])
        col = mix(col, mix(col, accent, 0.55), ramp(band.outputs[0], 0.025, 0.004))
    elif pat == "plates":
        pass
    elif pat == "bones":
        wave = nt.nodes.new('ShaderNodeMath')
        wave.operation = 'SINE'
        mul = nt.nodes.new('ShaderNodeMath')
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = 90.0
        L(x, mul.inputs[0])
        L(mul.outputs[0], wave.inputs[0])
        col = mix(col, (0.25, 0.3, 0.35), ramp(wave.outputs[0], 0.85, 0.97))
        bsdf.inputs['Alpha'].default_value = 0.7
    if pat == "scales" or pat in ("gradient", "koi", "plain"):
        # Scales: a fine net, darker at the edges.
        vor = nt.nodes.new('ShaderNodeTexVoronoi')
        vor.feature = 'DISTANCE_TO_EDGE'
        vor.inputs['Scale'].default_value = 70.0
        L(coord.outputs['Object'], vor.inputs['Vector'])
        edge = ramp(vor.outputs['Distance'], 0.0, 0.08)
        col = mix(mix(col, (0.0, 0.0, 0.0), 0.35), col, edge)
    # The gill cover: a dark arc behind the head; and the mouth, a dark
    # line at the snout.
    gx = nt.nodes.new('ShaderNodeMath')
    gx.operation = 'SUBTRACT'
    L(x, gx.inputs[0])
    gx.inputs[1].default_value = gill_x
    arc = nt.nodes.new('ShaderNodeCombineXYZ')
    sx = nt.nodes.new('ShaderNodeMath')
    sx.operation = 'MULTIPLY'
    sx.inputs[1].default_value = 1.0 / 0.05
    L(gx.outputs[0], sx.inputs[0])
    sz = nt.nodes.new('ShaderNodeMath')
    sz.operation = 'MULTIPLY'
    sz.inputs[1].default_value = 1.0 / max(gill_h, 0.02)
    L(z, sz.inputs[0])
    L(sx.outputs[0], arc.inputs['X'])
    L(sz.outputs[0], arc.inputs['Y'])
    ln = nt.nodes.new('ShaderNodeVectorMath')
    ln.operation = 'LENGTH'
    L(arc.outputs[0], ln.inputs[0])
    d = nt.nodes.new('ShaderNodeMath')
    d.operation = 'SUBTRACT'
    L(ln.outputs['Value'], d.inputs[0])
    d.inputs[1].default_value = 1.0
    ad = nt.nodes.new('ShaderNodeMath')
    ad.operation = 'ABSOLUTE'
    L(d.outputs[0], ad.inputs[0])
    # Only the back half of the ellipse (the arc bowing toward the tail).
    back_half = ramp(gx.outputs[0], 0.005, -0.005)
    gill = nt.nodes.new('ShaderNodeMath')
    gill.operation = 'MULTIPLY'
    L(ramp(ad.outputs[0], 0.12, 0.03), gill.inputs[0])
    L(back_half, gill.inputs[1])
    col = mix(col, mix(col, (0.0, 0.0, 0.0), 0.6), gill.outputs[0])
    L(col, bsdf.inputs['Base Color'])
    bsdf.inputs['Coat Weight'].default_value = 0.3
    return mat


def eye_mat():
    mat = bpy.data.materials.new("eye")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (0.01, 0.01, 0.01, 1)
    bsdf.inputs['Roughness'].default_value = 0.1
    return mat


def crayfish(sp):
    """Not a fish: a crayfish, of simple shapes."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = []
    mat = skin(sp)
    for k in range(7):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06 - k * 0.004, location=(0.25 - k * 0.075, 0, 0.02 - k * 0.004))
        o = bpy.context.active_object
        o.scale = (1.2 if k else 2.0, 0.9, 0.65)
        parts.append(o)
    bpy.ops.mesh.primitive_cone_add(radius1=0.07, depth=0.08, location=(-0.3, 0, 0))
    o = bpy.context.active_object
    o.rotation_euler = (0, math.pi / 2, 0)
    o.scale = (0.3, 1.0, 1.0)
    parts.append(o)
    for s in (1, -1):
        for seg, (a, bb, r) in enumerate([((0.33, 0.04, 0), (0.45, 0.08, 0.02), 0.012), ((0.45, 0.08, 0.02), (0.58, 0.06, 0.02), 0.02)]):
            a = Vector((a[0], a[1] * s, a[2]))
            bb = Vector((bb[0], bb[1] * s, bb[2]))
            d = bb - a
            bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(a + bb) / 2, vertices=10)
            o = bpy.context.active_object
            o.rotation_mode = 'QUATERNION'
            o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
            if seg == 1:
                o.scale = (1.6, 1.0, 1.0)
            parts.append(o)
        for k in range(4):
            x = 0.2 - k * 0.06
            a = Vector((x, 0.04 * s, -0.02))
            bb = Vector((x - 0.02, 0.12 * s, -0.07))
            d = bb - a
            bpy.ops.mesh.primitive_cylinder_add(radius=0.005, depth=d.length, location=(a + bb) / 2, vertices=6)
            o = bpy.context.active_object
            o.rotation_mode = 'QUATERNION'
            o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
            parts.append(o)
        a = Vector((0.36, 0.02 * s, 0.03))
        bb = Vector((0.62, 0.2 * s, 0.08))
        d = bb - a
        bpy.ops.mesh.primitive_cylinder_add(radius=0.003, depth=d.length, location=(a + bb) / 2, vertices=6)
        o = bpy.context.active_object
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        parts.append(o)
    for o in parts:
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.use_smooth = True
    return parts


# --- Render -----------------------------------------------------------------------

def stage(objs, flat=False):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.62, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(35), math.radians(-25), math.radians(20))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = 'ORTHO'
    scene.collection.objects.link(cam)
    scene.camera = cam
    # Side-on, a little from above and in front; flatfish from above.
    if flat:
        cam.rotation_euler = (math.radians(35), 0, 0)
        cam.location = (0, -0.9, 1.3)
    else:
        cam.rotation_euler = (math.radians(78), 0, 0)
        cam.location = (0, -2.0, 0.42)
    bpy.context.view_layer.update()
    # Fit: every vertex into the frame.
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for o in objs:
        if o.type != 'MESH':
            continue
        for v in o.data.vertices:
            p = inv @ (o.matrix_world @ v.co)
            xs.append(p.x)
            ys.append(p.y)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    span = max(max(xs) - min(xs), (max(ys) - min(ys)) * SIZE[0] / SIZE[1]) * 1.06
    cam.data.ortho_scale = span
    cam.data.shift_x = cx / span
    cam.data.shift_y = cy / span


def render(fid, sp):
    if sp["body"] == "crayfish":
        objs = crayfish(sp)
        flat = False
    else:
        parts, eyes, b = build(sp)
        gt = 0.78 if b["blunt"] < 0.7 else 0.74
        if any(e in b["extras"] for e in ("bill", "beak", "long_snout", "duck_snout")):
            gt = 0.7
        gh, _w, _c = profile(b, gt)
        body_mat = skin(sp, gill_x=gt - 0.5, gill_h=gh * 0.42)
        fin_mat, em = skin(sp, fins=True), eye_mat()
        for o in parts:
            o.data.materials.clear()
            o.data.materials.append(fin_mat if o.name.startswith(("tail", "fin", "pect", "spine")) else body_mat)
        for e in eyes:
            e.data.materials.clear()
            e.data.materials.append(em)
        objs = parts + eyes
        flat = "flat" in b["extras"]
        if flat:
            # Lying on its side: turned to face the camera above.
            for o in objs:
                o.rotation_euler.x += math.pi / 2
    stage(objs, flat)
    bpy.context.scene.render.filepath = os.path.join(OUT, fid + ".png")
    bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    species = read_species()
    want = sys.argv[1:] or list(species)
    for fid in want:
        render(fid, species[fid])
        print("rendered", fid, flush=True)


if __name__ == "__main__":
    main()
