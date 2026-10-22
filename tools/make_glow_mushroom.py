"""The glow mushroom (發光蘑菇; user request: the user's mushroom model made
the game's own - Profile.USABLES "glow_mushroom", GlowMushroom on the map):
a cluster of them, their caps turned from the model's magenta to a night
blue, the caps' dark freckles glowing cyan, and the gills under them (the
picture's blue starburst) glowing; the stems as they were. Base on the
ground at the origin, HEIGHT tall.

  bpyenv/bin/python tools/make_glow_mushroom.py SRC.fbx SRC.jpg    (repo root)

Writes assets/models/items/glow_mushroom.glb (its colour and glow
pictures in it). The user's files stay out of the repo.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "glow_mushroom.glb")
HEIGHT = 0.34
SIZE = 512
# Where the picture's parts are (share of its width/height): the caps' tops
# (a disc), the gills (a disc), the stems (the band below).
CAP = ((0.245, 0.31), 0.255)
GILLS = ((0.75, 0.245), 0.245)
STEMS_FROM = 0.56
CAP_HUE = 0.62
FRECKLE = np.array([0.55, 0.96, 1.0])


def _hsv_to_rgb(h, s, v):
    i = np.floor(h * 6.0).astype(int) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,))
    for k, (r, g, b) in enumerate(((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))):
        m = i == k
        out[m] = np.stack([r[m], g[m], b[m]], 1)
    return out


def pictures(src):
    """The colour and the glow pictures (as arrays 0..1)."""
    im = Image.open(src).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    rgb = np.array(im).astype(float) / 255.0
    hsv = np.array(im.convert("HSV")).astype(float) / 255.0
    yy, xx = np.mgrid[0:SIZE, 0:SIZE] / SIZE

    def disc(spec):
        (cx, cy), r = spec
        return np.hypot(xx - cx, yy - cy) < r

    cap, gills = disc(CAP), disc(GILLS)
    colour = rgb.copy()
    glow = np.zeros_like(rgb)
    # The caps: night blue, as light and as strong as they were.
    blue = _hsv_to_rgb(np.full(hsv.shape[:2], CAP_HUE), np.clip(hsv[..., 1] * 0.9, 0.0, 1.0),
                       np.clip(hsv[..., 2] * 1.25 + 0.05, 0.0, 1.0))
    colour[cap] = blue[cap]
    # (their freckles - the dark spots - lit cyan)
    freckle = cap & (hsv[..., 2] < 0.16)
    colour[freckle] = FRECKLE
    glow[cap] = blue[cap] * 0.12
    glow[freckle] = FRECKLE
    # The gills glow as they're painted.
    glow[gills] = rgb[gills] * 0.9
    return colour, glow


def save(arr, path):
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(path)


def main():
    src_fbx, src_jpg = sys.argv[sys.argv.index("--") + 1:][:2] if "--" in sys.argv else sys.argv[1:3]
    tmp = os.path.join(os.path.dirname(OUT), ".glow_mushroom_tmp")
    os.makedirs(tmp, exist_ok=True)
    colour, glow = pictures(src_jpg)
    cpath, gpath = os.path.join(tmp, "glow_mushroom_color.png"), os.path.join(tmp, "glow_mushroom_glow.png")
    save(colour, cpath)
    save(glow, gpath)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src_fbx)
    parts = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "glow_mushroom"
    # On the ground at the origin, HEIGHT tall.
    pts = [body.matrix_world @ v.co for v in body.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    s = HEIGHT / (hi.z - lo.z)
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        v.co = Vector(((p.x - (lo.x + hi.x) / 2) * s, (p.y - (lo.y + hi.y) / 2) * s, (p.z - lo.z) * s))
    body.matrix_world.identity()
    bpy.ops.object.shade_smooth()

    m = bpy.data.materials.new("glow_mushroom")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = bpy.data.images.load(cpath)
    nt.links.new(tc.outputs[0], b.inputs["Base Color"])
    tg = nt.nodes.new("ShaderNodeTexImage")
    tg.image = bpy.data.images.load(gpath)
    nt.links.new(tg.outputs[0], b.inputs["Emission Color"])
    b.inputs["Emission Strength"].default_value = 1.0
    b.inputs["Roughness"].default_value = 0.55
    body.data.materials.clear()
    body.data.materials.append(m)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=88, export_apply=True)
    for f in (cpath, gpath):
        os.remove(f)
    os.rmdir(tmp)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", len(body.data.vertices), "points")
    os._exit(0)


if __name__ == "__main__":
    main()
