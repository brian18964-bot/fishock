"""Mr. Croc's props, made our own from models the user gave (user request: "素材都要經過你再製，
成為我們的資產" - the originals are never committed; only what this makes):

  - the scroll that floats over his head while he has something to talk about (from a rolled
    paper scroll tied with a cord, r1.blend): its paper and cord joined into one mesh, thinned
    out to a game's count, laid along x and a metre long at its middle; its colours ours - an aged
    parchment, darker toward its ends and along its edge (the user: the old sign was too bright),
    and a cord dyed the deep red of his knit;
  - his three hats (user request: any of the three, or none, as he turns up; "帽體目前偏大，先縮小
    15%，帽簷可以做大一些，請依照鱷魚大叔的頭圍去設計修正帽子大小"): a trilby (Hat.obj with its
    picture), a wide sun hat (3d-model.fbx) and a cowboy hat (the leather one, Cowboy hat .fbx with
    its pictures). Each is fitted to his head: his head is measured from our own croc model
    (assets/models/characters/croc.glb) in his Head bone's space, seated where CrocLook puts a hat
    (SEAT, TILT); each crown's foot is drawn in or out to go about his head's outline (EASE to
    spare) - narrower side to side than the old hat, as long front to back as his long head - and
    lowered to its share of its own height (never onto his head), and let out wherever, further up,
    his head would still come through it; each brim drawn out from the new foot (HATS' brim), its
    curl kept (refit).
    Their pictures ours: the trilby re-dyed an aged cream with a dark brown band and a straw weave;
    the sun hat a woven straw of our own with a ribbon; the cowboy's leather warmed and worn, its
    band darkened. All stand on their brims at the origin, the crown's opening there, front toward
    -y (his snout's way once exported).

    bpyenv/bin/python tools/make_croc_props.py -- SCROLL.blend TRILBY.obj TRILBY_BASECOLOR.png \
        SUNHAT.fbx COWBOY.fbx COWBOY_TEXTURES_DIR OUT_DIR

writes OUT_DIR/quest_scroll.glb and OUT_DIR/croc_hat_{trilby,sun,cowboy}.glb (their pictures inside).
ONLY=hats (or ONLY=scroll) makes just those.
"""
import json
import math
import os
import struct
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector
from scipy.spatial import ConvexHull

args = sys.argv[sys.argv.index("--") + 1:]
SCROLL, TRILBY, TRILBY_TEX, SUNHAT, COWBOY, COWBOY_TEX, OUT = args[:7]
ONLY = os.environ.get("ONLY", "")
CROC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models", "characters", "croc.glb")

# (the scroll: how many faces it keeps; its parchment and the cord, linear)
SCROLL_FACES = 2600
PARCHMENT = (0.50, 0.36, 0.20)
PARCHMENT_EDGE = (0.30, 0.19, 0.10)
CORD = (0.30, 0.07, 0.05)
# The hats. Where one sits on his Head bone (its brim's plane: up, forward; tipped back) - the
# same as CrocLook.HAT_AT / HAT_TILT; how much room inside the crown all round (m).
SEAT = (0.195, 0.085)
TILT = -0.16
EASE = 0.016
# (the trilby's re-dye; the sun hat's straw and ribbon - linear)
CREAM = np.array([0.86, 0.76, 0.56])
BAND = np.array([0.20, 0.12, 0.07])
STRAW = np.array([0.78, 0.62, 0.34])
RIBBON = (0.08, 0.20, 0.22)
# Each hat: how its crown's foot is found (points under `foot_z` m up and within `foot_r` of its
# middle - the ring where the crown meets the brim), the height its brim's plane is at; how tall
# its crown ends up (share of its own - but never down onto his head), how far its brim reaches past the crown (m), how far its
# front and back dip (m); how many faces it keeps.
HATS = {
    "trilby": {"foot_z": 0.02, "foot_r": 0.19, "base": 0.008, "height": 0.85, "brim": 0.11, "dip": 0.012, "faces": 3000},
    "sun": {"foot_z": 0.04, "foot_r": 0.135, "base": 0.028, "height": 0.85, "brim": 0.15, "dip": 0.0, "faces": 2400},
    "cowboy": {"foot_z": 0.06, "foot_r": 0.105, "base": 0.012, "height": 0.85, "brim": 0.11, "dip": 0.0, "faces": 3600},
}
# (past this share of the crown's foot, a point's the brim's; the least room over his head and
# inside the crown all the way up (m); how finely his head is measured - ways round, heights (m))
FOOT = 1.03
CLEAR = 0.02
EASE_IN = 0.008
BINS = 90
STEP = 0.005


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def principled(name, colour, rough=0.8, vcol=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*colour, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if vcol:
        attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        mix = m.node_tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = (*colour, 1.0)
        m.node_tree.links.new(attr.outputs[0], mix.inputs[7])
        m.node_tree.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m


def export(objs, path, images="AUTO"):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
                              export_image_format=images, export_jpeg_quality=85)
    print("WROTE", path, os.path.getsize(path))


# ---------------------------------------------------------------- the scroll

def make_scroll():
    clear()
    with bpy.data.libraries.load(SCROLL, link=False) as (src, dst):
        dst.objects = [n for n in src.objects]
    parts = []
    for o in dst.objects:
        if o is not None and o.type == "MESH":
            bpy.context.scene.collection.objects.link(o)
            parts.append(o)
    paper = next(o for o in parts if o.name.startswith("Roll paper"))
    # (each part in the world as it stood, its own modifiers applied)
    for o in parts:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    for o in parts:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Ours: the paper's own material and the cord's.
    m_paper = principled("ScrollParchment", PARCHMENT, 0.85, vcol=True)
    m_cord = principled("ScrollCord", CORD, 0.6)
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(m_paper if o == paper else m_cord)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = paper
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "QuestScroll"
    # Thinned out.
    faces = len(obj.data.polygons)
    if faces > SCROLL_FACES:
        dec = obj.modifiers.new("thin", "DECIMATE")
        dec.ratio = SCROLL_FACES / faces
        bpy.ops.object.modifier_apply(modifier="thin")
    # Along x, a metre long, its middle at the origin.
    me = obj.data
    pts = np.array([v.co[:] for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    axis = int(np.argmax(hi - lo))
    centre = (lo + hi) / 2
    k = 1.0 / (hi - lo)[axis]
    for v in me.vertices:
        p = (Vector(v.co) - Vector(centre)) * k
        if axis == 1:
            p = Vector((p.y, -p.x, p.z))
        elif axis == 2:
            p = Vector((p.z, p.y, -p.x))
        v.co = p
    # The parchment aged: darker toward its ends and on its outer edge (a vertex colour the
    # material multiplies by).
    if not me.color_attributes.get("Col"):
        me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    col = me.color_attributes["Col"]
    rng = np.random.default_rng(7)
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            end = min(1.0, (abs(v.x) / 0.5) ** 3)
            spot = rng.uniform(0.9, 1.0)
            dark = 1.0 - 0.45 * end
            c = Vector(PARCHMENT).lerp(Vector(PARCHMENT_EDGE), 0.5 * end) * dark * spot / Vector(PARCHMENT).length * 1.7
            col.data[li].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
    bpy.ops.object.shade_smooth()
    export([obj], os.path.join(OUT, "quest_scroll.glb"))




# ---------------------------------------------------------------- his head

def croc_head():
    """His head's points (those mostly on the Head bone) in that bone's own space - x across, y up, z
    his snout's way: what a hat on the bone sits in."""
    data = open(CROC, "rb").read()
    jlen = struct.unpack("<I", data[12:16])[0]
    gl = json.loads(data[20:20 + jlen])
    blob = data[20 + jlen + 8:]
    kinds = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

    def acc(i):
        a = gl["accessors"][i]
        bv = gl["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        dt = np.dtype(kinds[a["componentType"]])
        n = width[a["type"]]
        stride = bv.get("byteStride", dt.itemsize * n)
        raw = np.frombuffer(blob, dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=off)
        rows = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], dt.itemsize * n), strides=(stride, 1)).copy()
        out = rows.view(dt).reshape(a["count"], n)
        return out.astype(np.float64) / np.iinfo(dt).max if a.get("normalized") else out

    skin = gl["skins"][0]
    names = [gl["nodes"][j].get("name", "") for j in skin["joints"]]
    head = names.index("Head")
    ibm = acc(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)[head]
    pts = []
    for mesh in gl["meshes"]:
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            if "JOINTS_0" not in at:
                continue
            pos = acc(at["POSITION"]).astype(np.float64)
            on = (acc(at["WEIGHTS_0"]) * (acc(at["JOINTS_0"]) == head)).sum(1) > 0.5
            pts.append((np.c_[pos[on], np.ones(on.sum())] @ ibm.T)[:, :3])
    return np.vstack(pts)


def head_fit():
    """His head above a hat's brim, seated at SEAT tipped TILT, in the hat's own (Blender) frame: x
    across, y toward the back of his head (his snout's way is -y), z up from the brim's plane. Its
    outline from above - the round a crown's foot must go about - and how wide it is at each height
    and each way round, for the crown to clear it all the way up."""
    p = croc_head() - np.array([0.0, SEAT[0], SEAT[1]])
    c, s = math.cos(TILT), math.sin(TILT)
    up = c * p[:, 1] + s * p[:, 2]
    fwd = -s * p[:, 1] + c * p[:, 2]
    over = up > -0.005
    pts = np.c_[p[over, 0], -fwd[over], np.maximum(up[over], 0.0)]
    ang = np.arctan2(pts[:, 1], pts[:, 0])
    rad = np.hypot(pts[:, 0], pts[:, 1])
    # The foot's round: his head's outline from above (its hull, so no dent of an eye or a nostril
    # pulls it in), how far out at each of BINS ways round.
    hull = ConvexHull(pts[:, :2])
    ring = pts[hull.vertices, :2]
    dense = np.vstack([ring[i] + (ring[(i + 1) % len(ring)] - ring[i]) * t
                       for i in range(len(ring)) for t in np.linspace(0, 1, 24, endpoint=False)])
    outline = np.zeros(BINS)
    for q in dense:
        k = int((math.atan2(q[1], q[0]) + math.pi) / (2 * math.pi) * BINS) % BINS
        outline[k] = max(outline[k], math.hypot(q[0], q[1]))
    for k in range(BINS):
        if outline[k] == 0.0:
            outline[k] = max(outline[(k - 1) % BINS], outline[(k + 1) % BINS])
    # How far out at each height (STEP m apart) each way round - spread a bin each way.
    rows = int(pts[:, 2].max() / STEP) + 2
    wide = np.zeros((rows, BINS))
    hi = (pts[:, 2] / STEP).astype(int)
    ai = ((ang + math.pi) / (2 * math.pi) * BINS).astype(int) % BINS
    np.maximum.at(wide, (hi, ai), rad)
    spread = wide.copy()
    for dh in (-1, 0, 1):
        for da in (-1, 0, 1):
            spread = np.maximum(spread, np.roll(np.roll(wide, dh, 0), da, 1))
    top = pts[:, 2].max()
    print("HEAD over the brim: %.3f across, %.3f front to back, %.3f high" % (
        np.ptp(pts[:, 0]), np.ptp(pts[:, 1]), top))
    return {"outline": outline, "wide": spread, "top": top}


def bin_of(x, y):
    return int((math.atan2(y, x) + math.pi) / (2 * math.pi) * BINS) % BINS


def smooth_ring(v, n=2):
    return np.mean([np.roll(v, k) for k in range(-n, n + 1)], axis=0)


# ---------------------------------------------------------------- the hats

def load_parts(kind):
    """The hat's own meshes (not the head the cowboy came on), each in the world as it stood."""
    clear()
    if kind == "trilby":
        bpy.ops.wm.obj_import(filepath=TRILBY)
    else:
        bpy.ops.import_scene.fbx(filepath=SUNHAT if kind == "sun" else COWBOY)
    keep = {"Cappello", "Fascia", "Oro"} if kind == "cowboy" else None
    parts = []
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and (keep is None or o.name in keep):
            parts.append(o)
        else:
            bpy.data.objects.remove(o)
    for o in parts:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return parts


def thin(o, faces):
    if len(o.data.polygons) > faces:
        bpy.context.view_layer.objects.active = o
        dec = o.modifiers.new("thin", "DECIMATE")
        dec.ratio = faces / len(o.data.polygons)
        bpy.ops.object.modifier_apply(modifier="thin")


def picture(name, rgb, size):
    """A picture of ours (rgb: h x w x 3, linear 0..1), at `size` across."""
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h)
    img.pixels = np.concatenate([np.clip(rgb, 0, 1), np.ones((h, w, 1))], axis=2).astype(np.float32).ravel().tolist()
    if w != size:
        img.scale(size, size)
    img.pack()
    return img


def textured(name, img, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    return m


def read_rgb(path):
    src = bpy.data.images.load(path)
    w, h = src.size
    return np.array(src.pixels[:], dtype=np.float32).reshape(h, w, src.channels)[:, :, :3]


def refit(obj, spec, fit):
    """The hat made to fit him: its crown's foot drawn in or out, each way round, to go about his
    head's outline with EASE to spare (the source's own foot measured each way round too, so its
    walls stay walls); its crown lowered to its share of its height, never onto his head; then, at any
    height and any way round where his head would still come through it (a crown narrowing toward
    its top), let out there to clear it by EASE_IN. Its brim drawn out from the new foot, as wide all
    round in metres (its curl and its wider and narrower places kept in proportion)."""
    me = obj.data
    pts = np.array([v.co[:] for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    pts -= np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    r = np.hypot(pts[:, 0], pts[:, 1])
    bins = np.array([bin_of(x, y) for x, y, _ in pts])
    # The source's foot, each way round.
    foot = (pts[:, 2] < spec["foot_z"]) & (r < spec["foot_r"])
    was = np.zeros(BINS)
    np.maximum.at(was, bins[foot], r[foot])
    for _ in range(BINS):
        gap = was == 0.0
        if not gap.any():
            break
        was[gap] = np.maximum(np.roll(was, 1), np.roll(was, -1))[gap]
    was = smooth_ring(was)
    want = smooth_ring(fit["outline"]) + EASE
    rho = r / was[bins]
    brim_was = np.percentile(rho, 99.5) - FOOT
    height = pts[:, 2].max() - spec["base"]
    lower = max(spec["height"], (fit["top"] + EASE + CLEAR) / height)
    out = np.zeros_like(pts)
    crown = rho <= FOOT
    for i, (x, y, z) in enumerate(pts):
        if r[i] < 1e-6:
            continue
        dx, dy = x / r[i], y / r[i]
        if crown[i]:
            k = rho[i] * want[bins[i]]
        else:
            k = FOOT * want[bins[i]] + (rho[i] - FOOT) / brim_was * spec["brim"]
        out[i] = (dx * k, dy * k, z)
        if crown[i] and z > spec["base"]:
            out[i, 2] = spec["base"] + (z - spec["base"]) * lower
        if not crown[i] and spec["dip"]:
            out[i, 2] -= spec["dip"] * abs(dy) * min((rho[i] - FOOT) / brim_was, 1.0)
    out[:, 2] -= spec["base"]
    # Let out wherever his head would come through: the crown's inside at each height and each way
    # round against his head there.
    rows = fit["wide"].shape[0]
    hrow = np.clip((out[:, 2] / STEP).astype(int), 0, rows - 1)
    rin = np.full((rows, BINS), np.inf)
    rr = np.hypot(out[:, 0], out[:, 1])
    up = crown & (out[:, 2] >= -0.01) & (out[:, 2] < fit["top"] + STEP)
    np.minimum.at(rin, (hrow[up], bins[up]), rr[up])
    need = np.where((fit["wide"] > 0) & np.isfinite(rin), (fit["wide"] + EASE_IN) / np.maximum(rin, 1e-4), 1.0)
    need = np.maximum(need, 1.0)
    for h in range(rows):
        need[h] = np.maximum(need[h], smooth_ring(need[h], 2))
    # (eased up and down the crown too, so its walls stay smooth)
    padded = np.vstack([need[:1], need, need[-1:]])
    need = np.maximum(need, (padded[:-2] + padded[1:-1] + padded[2:]) / 3.0)
    let = np.ones(len(out))
    let[up] = need[hrow[up], bins[up]]
    above = crown & (out[:, 2] >= fit["top"] + STEP)
    let[above] = need[rows - 1, bins[above]]
    out[:, 0] *= let
    out[:, 1] *= let
    print("HAT %s: crown %.3f x %.3f at its foot, %.3f tall, let out up to %.0f%%; brim out %.3f" % (
        obj.name, np.ptp(out[crown & (out[:, 2] < 0.02), 0]), np.ptp(out[crown & (out[:, 2] < 0.02), 1]),
        out[crown, 2].max(), (need.max() - 1) * 100, spec["brim"]))
    for i, v in enumerate(me.vertices):
        v.co = Vector(out[i])


def finish(parts, kind, images="JPEG"):
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "CrocHat_" + kind
    refit(obj, HATS[kind], FIT)
    bpy.ops.object.shade_smooth()
    export([obj], os.path.join(OUT, "croc_hat_%s.glb" % kind), images)


def trilby():
    parts = load_parts("trilby")
    # Its picture re-dyed: the cream warmer and aged, the dark band brown; a straw weave over it.
    rgb = read_rgb(TRILBY_TEX)
    h, w = rgb.shape[:2]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    band = (lum < 0.25).astype(np.float32)[..., None]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    weave = 0.92 + 0.08 * (np.sin(xx * 0.9) * np.sin(yy * 0.9) > 0).astype(np.float32)
    grain = 0.94 + 0.06 * np.random.default_rng(3).random((h, w)).astype(np.float32)
    straw = (lum / max(lum.max(), 1e-3))[..., None] * CREAM * (weave * grain)[..., None]
    dyed = straw * (1.0 - band) + (lum[..., None] * 2.2 * BAND) * band
    # (half its size: a small thing on his head, for the web build to fetch)
    m = textured("CrocHatTrilby", picture("croc_hat_trilby", dyed, w // 2), 0.9)
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(m)
        thin(o, HATS["trilby"]["faces"])
    finish(parts, "trilby")


def straw_picture(size=512):
    """A woven straw of our own: over-and-under strands both ways, each strand's fibres and its own
    shade, a little sun-bleaching."""
    rng = np.random.default_rng(11)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    n = 32
    cell = size / n
    cx, cy = (xx // cell).astype(int), (yy // cell).astype(int)
    fx, fy = (xx % cell) / cell, (yy % cell) / cell
    over = (cx + cy) % 2 == 0
    # (each strand rounded across, with fibres along it)
    along_x = 0.75 + 0.25 * np.sin(np.pi * fy) + 0.05 * np.sin(xx * 1.7 + cy * 3.1)
    along_y = 0.75 + 0.25 * np.sin(np.pi * fx) + 0.05 * np.sin(yy * 1.7 + cx * 3.1)
    shade = np.where(over, along_x, along_y)
    strand = rng.uniform(0.86, 1.06, (n, n)).astype(np.float32)
    shade *= np.where(over, strand[cy % n, 0], strand[0, cx % n])
    gaps = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    shade *= 0.72 + 0.28 * np.clip(gaps * 12.0, 0, 1)
    bleach = 0.94 + 0.06 * np.random.default_rng(5).random((size, size)).astype(np.float32)
    return shade[..., None] * STRAW * bleach[..., None]


def sun_hat():
    parts = load_parts("sun")
    obj = parts[0]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    if len(parts) > 1:
        for o in parts:
            o.select_set(True)
        bpy.ops.object.join()
        obj = bpy.context.view_layer.objects.active
    me = obj.data
    me.materials.clear()
    m_straw = textured("CrocHatSunStraw", picture("croc_hat_sun_straw", straw_picture(), 512), 0.95)
    m_ribbon = principled("CrocHatSunRibbon", RIBBON, 0.6)
    me.materials.append(m_straw)
    me.materials.append(m_ribbon)
    for uv in list(me.uv_layers):
        me.uv_layers.remove(uv)
    thin(obj, HATS["sun"]["faces"])
    # Our own wrap: the straw laid on from above (it's a low, wide thing), a ribbon round the
    # crown's foot.
    uvl = me.uv_layers.new(name="UVMap")
    pts = np.array([v.co[:] for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    mid = (lo + hi) / 2
    span = (hi - lo).max()
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = ((co.x - mid[0]) / span * 3.0 + 0.5, (co.y - mid[1]) / span * 3.0 + 0.5)
        c = poly.center
        r = math.hypot(c.x - mid[0], c.y - mid[1])
        z = c.z - lo[2]
        poly.material_index = 1 if r < 0.135 and 0.026 < z < 0.052 else 0
    finish([obj], "sun")


def cowboy():
    parts = load_parts("cowboy")
    for o in parts:
        rgb = read_rgb(os.path.join(COWBOY_TEX, "%s_2D_View_1001.jpg" % o.name))
        h, w = rgb.shape[:2]
        wear = np.random.default_rng(len(o.name)).random((h // 8, w // 8)).astype(np.float32)
        wear = np.kron(wear, np.ones((8, 8), np.float32))[:h, :w]
        if o.name == "Cappello":
            # (the leather warmed toward a saddle brown, worn lighter here and there)
            out = rgb * np.array([1.12, 0.94, 0.78]) * (0.92 + 0.14 * wear)[..., None]
            size, rough = 512, 0.7
        elif o.name == "Fascia":
            out = rgb * np.array([0.62, 0.52, 0.46])
            size, rough = 256, 0.6
        else:
            out = rgb * np.array([1.05, 0.95, 0.75])
            size, rough = 128, 0.35
        m = textured("CrocHatCowboy" + o.name, picture("croc_hat_cowboy_" + o.name.lower(), out, size), rough)
        if o.name == "Oro":
            m.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.8
        o.data.materials.clear()
        o.data.materials.append(m)
        thin(o, {"Cappello": 2600, "Fascia": 500, "Oro": 500}[o.name])
    finish(parts, "cowboy")


os.makedirs(OUT, exist_ok=True)
if ONLY in ("", "scroll"):
    make_scroll()
if ONLY in ("", "hats"):
    FIT = head_fit()
    trilby()
    sun_hat()
    cowboy()
