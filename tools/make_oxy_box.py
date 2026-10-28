"""The oxygenated fish box (打氧魚箱; the user's LiveBaitBucket_v5.fbx - a
cooler box with a battery aerator on its side) made the game's own: its
parts kept (body, mounts, carry handle, pump, air line, air stone), the
textures cut to 1024 and written as JPEG, base on the ground at the origin,
the front (the latch) toward +z. Mounts the shop's preview, the bag's
icons and the hip in a run.

  bpyenv/bin/python tools/make_oxy_box.py SRC.fbx    (repo root)

Writes assets/models/items/oxy_box.glb. The user's files stay out of the repo.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "oxy_box.glb")
MAX_TEX = 1024
# The game's own colours (user: not the model's red and cream): the lid's red
# turned to a sea teal, the cream body to a deep harbour navy - the wear,
# scratches and shading of the painted texture kept (hue turned, tones kept).
LID_HUE = 0.08
BODY_HUE = 0.55


def _rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rr = m & (mx == r)
    gg = m & (mx == g) & ~rr
    bb = m & ~rr & ~gg
    h[rr] = ((g - b)[rr] / d[rr]) % 6.0
    h[gg] = (b - r)[gg] / d[gg] + 2.0
    h[bb] = (r - g)[bb] / d[bb] + 4.0
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([h, s, mx], -1)


def _hsv_to_rgb(hsv):
    h, s, v = hsv[..., 0] % 1.0, hsv[..., 1], hsv[..., 2]
    i = np.floor(h * 6.0).astype(int) % 6
    f = h * 6.0 - np.floor(h * 6.0)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    out = np.zeros(h.shape + (3,))
    for k, (a, b, c) in enumerate(((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))):
        m = i == k
        out[m] = np.stack([a[m], b[m], c[m]], -1)
    return out


def recolour(img):
    """The body texture's red parts teal, its cream parts navy."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    hsv = _rgb_to_hsv(px[..., :3])
    hue, sat, val = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    red = ((hue < 0.045) | (hue > 0.93)) & (sat > 0.45)
    cream = (hue >= 0.045) & (hue < 0.2) & ~red
    out = hsv.copy()
    out[red, 0] = LID_HUE
    out[red, 1] = np.clip(sat[red] * 0.95, 0, 1)
    out[cream, 0] = BODY_HUE
    out[cream, 1] = np.clip(sat[cream] * 1.0 + 0.2, 0, 1)
    out[cream, 2] = val[cream] * 0.36
    px[..., :3] = _hsv_to_rgb(out)
    img.pixels[:] = px.reshape(-1)


def main():
    src = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=src)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.parent = None
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    print("bounds", [round(x, 3) for x in lo], [round(x, 3) for x in hi])
    shift = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for o in meshes:
        for v in o.data.vertices:
            v.co -= shift
    for img in bpy.data.images:
        if img.size[0] > MAX_TEX:
            img.scale(MAX_TEX, MAX_TEX)
        if "Color" in img.name and img.size[0] >= 512:
            recolour(img)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=85, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB;", sum(len(o.data.polygons) for o in meshes), "faces")
    os._exit(0)


if __name__ == "__main__":
    main()
