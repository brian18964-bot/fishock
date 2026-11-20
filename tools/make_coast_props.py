"""The seaside's rocks, made from the user's "Des" pack's cliff rock (user request: the seaside -
its cliffs and the rocks of the shore; "before use each goes through our own changes and becomes
our asset"). The pack itself stays out of the repo; each one here is changed into ours:

  - coast_cliff_a..c: pieces of cliff - the rock subdivided and drawn out into a wall (about 7 m
    long, 2.5 m through, 3 to 4.5 m tall), cut into the sea cliff's layers (strata standing out
    and sinking back), cracked and roughened, each by noise of its own seed; its picture regraded
    to a dark, weathered grey-brown and mapped evenly over it (box-projected, not stretched);
    its foot dark and wet with a green tinge of weed, its top paler (vertex colour);
  - coast_reef_a..c: the rocks of the water's edge - low, broad, worn round by the sea, darker,
    the weed's green further up them.

Each a .glb (its picture inside, 1024 px, its relief 512) with a .json of the ground it stands on
(circles x, z, r in m, the model's Godot frame - Fossil's), its size and reach.

  bpyenv/bin/python tools/make_coast_props.py -- <the pack's folder> [only=a,b]
    (repo root; the pack's Cliffside_Rock_FBX and Cliff_Rock_One_Texture4K folders)
"""
import json
import math
import os
import random
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector, noise

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
COAST = os.path.join(ROOT, "assets", "models", "coast")
TMP = os.path.join(ROOT, "probe_tmp", "coast_props")
ROCK = "Cliffside_Rock_FBX/Cliffside_Rock_FBX.fbx"
PICS = "Cliff_Rock_One_Texture4K/x/Cliff_Rock_One_Texture4K/Cliff_Rock_One_"

# name: (size m: length, through, height), seed, layer spacing (m), how far they stand out (m),
# rounded by the sea (0 sharp .. 1 worn), wet up to (m), triangles
SHAPES = {
    "coast_cliff_a": ((7.0, 2.6, 3.4), 5, 0.42, 0.2, 0.15, 0.55, 5000),
    "coast_cliff_b": ((6.2, 2.4, 4.4), 17, 0.36, 0.24, 0.1, 0.6, 5000),
    "coast_cliff_c": ((7.6, 2.8, 3.0), 29, 0.5, 0.18, 0.2, 0.5, 5000),
    "coast_reef_a": ((2.6, 1.9, 0.75), 41, 0.3, 0.04, 0.75, 0.5, 1600),
    "coast_reef_b": ((3.4, 1.6, 0.6), 53, 0.28, 0.03, 0.8, 0.45, 1600),
    "coast_reef_c": ((1.7, 1.5, 0.95), 67, 0.32, 0.05, 0.65, 0.6, 1600),
}


def fresh(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in obs:
        o.parent = None
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(obs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    for x in list(bpy.context.scene.objects):
        if x != o:
            bpy.data.objects.remove(x, do_unlink=True)
    return o


def picture(src, name, tint=(1, 1, 1), lift=0.0, sat=1.0, size=1024, normal=False):
    """Our version of a picture: smaller, its colour moved (tint, a lift toward white, saturation)."""
    from PIL import Image, ImageEnhance
    Image.MAX_IMAGE_PIXELS = None
    im = Image.open(src).convert("RGB").resize((size, size), Image.LANCZOS)
    out = os.path.join(TMP, name + ".jpg")
    if normal:
        im.save(out, quality=90)
        return out
    im = ImageEnhance.Color(im).enhance(sat)
    a = np.asarray(im).astype(np.float32) / 255.0
    a = a * np.array(tint, np.float32)
    a = a + (1.0 - a) * lift
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(out, quality=88)
    return out


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def shape(o, size, seed, layer, stand, worn):
    """The rock subdivided, drawn out to `size` (its foot at z 0), layered and roughened."""
    bpy.context.view_layer.objects.active = o
    sub = o.modifiers.new("s", "SUBSURF")
    sub.levels = 2
    sub.subdivision_type = "CATMULL_CLARK"
    bpy.ops.object.modifier_apply(modifier="s")
    me = o.data
    pts = np.array([list(v.co) for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    span = hi - lo
    me.transform(Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    me.transform(Matrix.Diagonal((size[0] / span[0], size[1] / span[1], size[2] / span[2], 1.0)))
    # (a cliff's faces steep and its top flat-ish - squared off from the boulder's round; the sea's
    # rocks left round)
    box = 1.0 - worn
    if box > 0.0:
        a, b, hgt = size[0] / 2, size[1] / 2, size[2]
        for v in me.vertices:
            u, w = v.co.x / a, v.co.y / b
            r = math.hypot(u, w)
            m = max(abs(u), abs(w))
            if r > 1e-4 and m > 1e-4:
                k = (r / m) ** (0.7 * box)
                v.co.x *= k
                v.co.y *= k
            # (the sides upright: the lower part as wide as the middle)
            up = v.co.z / hgt
            if up < 0.6:
                lift = 1.0 + 0.18 * box * (0.6 - up) / 0.6
                v.co.x *= lift
                v.co.y *= lift
            if up > 0.8:
                v.co.z = hgt * (0.8 + (up - 0.8) * (1.0 - 0.55 * box))
    me.update()
    rng = random.Random(seed)
    off = Vector((rng.uniform(0, 80), rng.uniform(0, 80), rng.uniform(0, 80)))
    tilt = rng.uniform(-0.12, 0.12)
    for v in me.vertices:
        p = v.co.copy()
        n = v.normal.copy()
        flat = Vector((n.x, n.y, 0.0))
        side = flat.length
        if side > 1e-4:
            flat /= side
        # (the layers: bands of rock standing out and sinking back, a little tilted, broken along
        # their length; strongest on the faces, none on top)
        z = p.z + tilt * p.x + noise.noise(p * 0.35 + off) * layer * 0.5
        band = (z / layer) % 1.0
        step = smooth(0.0, 0.18, band) - smooth(0.55, 0.75, band)
        out = (step - 0.4) * stand * side * (0.6 + 0.4 * noise.noise(p * 0.6 + off * 1.7))
        # (cracks and knobs, big and small; less of them where the sea has worn it)
        rough = (noise.noise(p * 0.55 + off) * 0.22 + noise.noise(p * 1.9 + off) * 0.07
                 + noise.noise(p * 5.0 + off) * 0.025) * (1.0 - 0.6 * worn) * min(size[2], 2.0)
        top = smooth(size[2] * 0.75, size[2], p.z)
        v.co = p + flat * out * (1.0 - top) + n * rough
        # (the foot sunk a little into the sand, never lifted off it)
        if v.co.z < 0.0:
            v.co.z *= 0.3
    me.update()


def colours(o, wet_to, size, seed):
    """Its foot dark and wet, green with weed low down; its top paler, a little salt-whitened."""
    me = o.data
    attr = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    rng = random.Random(seed + 7)
    off = Vector((rng.uniform(0, 50), rng.uniform(0, 50), rng.uniform(0, 50)))
    for i, v in enumerate(me.vertices):
        z = v.co.z
        n = noise.noise(v.co * 1.3 + off) * 0.18
        wet = 1.0 - smooth(wet_to * 0.4, wet_to * (1.1 + n), z)
        weed = 1.0 - smooth(0.0, wet_to * (0.7 + n), z)
        dry = smooth(size[2] * 0.6, size[2], z)
        r, g, b = 1.0, 1.0, 1.0
        r, g, b = r * (1.0 - 0.42 * wet), g * (1.0 - 0.36 * wet), b * (1.0 - 0.38 * wet)
        r, g, b = r * (1.0 - 0.3 * weed), g * (1.0 - 0.08 * weed), b * (1.0 - 0.32 * weed)
        r, g, b = min(1.0, r * (1.0 + 0.12 * dry)), min(1.0, g * (1.0 + 0.12 * dry)), min(1.0, b * (1.0 + 0.1 * dry))
        attr.data[i].color = (r, g, b, 1.0)


def box_uv(o, cube):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=cube)
    bpy.ops.object.mode_set(mode="OBJECT")


def dress(o, colour, relief):
    m = bpy.data.materials.new("rock")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])
    t = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(colour)
    img.pack()
    t.image = img
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(t.outputs["Color"], mix.inputs["A"])
    nt.links.new(vc.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
    nm = nt.nodes.new("ShaderNodeTexImage")
    nimg = bpy.data.images.load(relief)
    nimg.pack()
    nimg.colorspace_settings.name = "Non-Color"
    nm.image = nimg
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.88
    o.data.materials.clear()
    o.data.materials.append(m)


def decimate(o, tris):
    now = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if now > tris:
        m = o.modifiers.new("d", "DECIMATE")
        m.ratio = tris / now
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier="d")


def footprint(o, cell, above):
    """The ground it covers: cells of `cell` m with some of it more than `above` m up."""
    cells = {}
    for v in o.data.vertices:
        if v.co.z > above:
            k = (int(math.floor(v.co.x / cell)), int(math.floor(-v.co.y / cell)))
            cells[k] = max(cells.get(k, 0.0), v.co.z)
    circles = [[round((k[0] + 0.5) * cell, 3), round((k[1] + 0.5) * cell, 3), round(cell * 0.72, 3)] for k in sorted(cells)]
    pts = np.array([list(v.co) for v in o.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    reach = max([math.hypot(c[0], c[1]) + c[2] for c in circles] or [0.3])
    return {"circles": circles, "size": [round(float(hi[0] - lo[0]), 2), round(float(hi[1] - lo[1]), 2), round(float(hi[2]), 2)],
            "reach": round(float(reach), 2)}


def export(o, path, info):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_image_format="JPEG", export_vertex_color="MATERIAL")
    with open(path.replace(".glb", ".json"), "w") as f:
        json.dump(info, f)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("made %s tris %d reach %.2f circles %d size %s" % (os.path.basename(path), tris, info["reach"], len(info["circles"]), info["size"]), flush=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not args:
        print(__doc__)
        sys.exit(1)
    pack = args[0]
    only = None
    for a in args[1:]:
        if a.startswith("only="):
            only = set(a[5:].split(","))
    os.makedirs(COAST, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    # (the sea cliff's grey-brown, darker and duller than the desert's sandstone; its relief as is)
    cliff_pic = picture(os.path.join(pack, PICS + "BaseColor.png"), "coast_cliff", (0.78, 0.76, 0.72), 0.0, 0.45)
    reef_pic = picture(os.path.join(pack, PICS + "BaseColor.png"), "coast_reef", (0.62, 0.62, 0.6), 0.0, 0.35)
    relief = picture(os.path.join(pack, PICS + "Normal.png"), "coast_rock_normal", size=512, normal=True)
    for name, (size, seed, layer, stand, worn, wet_to, tris) in SHAPES.items():
        if only and name not in only:
            continue
        o = fresh(os.path.join(pack, ROCK))
        shape(o, size, seed, layer, stand, worn)
        decimate(o, tris)
        box_uv(o, 2.4 if "cliff" in name else 1.6)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(55))
        colours(o, wet_to, size, seed)
        dress(o, cliff_pic if "cliff" in name else reef_pic, relief)
        # (Blender's z up is Godot's y: the json's circles in Godot's x, z)
        export(o, os.path.join(COAST, name + ".glb"), footprint(o, 0.7 if "cliff" in name else 0.5, 0.15))


main()
