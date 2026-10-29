"""the vitality feed (活力飼料) (活力飼料: the user's Tokkuri_Complete bottle with its
Spiral Motif textures), glazed our own way: the teal turned to a deep moss
green, the brown swirls to gold. Textures cut to 1024 JPEG (the base colour
recoloured here, the roughness and metal packed into one map), the bottle
upright with its base on the ground at the origin, 0.3 m tall.

  bpyenv/bin/python tools/make_vigor_feed.py -- DIR   (DIR holds Tokkuri_Complete.fbx and
                                                      Unpacked/Spiral Motif/*.png; repo root)

Writes assets/models/items/vigor_feed.glb. The user's files stay out of the repo.
"""
import colorsys
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "vigor_feed.glb")
SIZE = 1024
HEIGHT = 0.3


def small(path, name, non_color):
    img = bpy.data.images.load(path)
    img.scale(SIZE, SIZE)
    return img


def px(img):
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)


def made(arr, name, non_color):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h)
    img.pixels = arr.reshape(-1).tolist()
    path = "/tmp/%s.jpg" % name
    img.filepath_raw = path
    img.file_format = "JPEG"
    img.save()
    out = bpy.data.images.load(path)
    out.name = name
    out.pack()
    if non_color:
        out.colorspace_settings.name = "Non-Color"
    return out


def recolour(rgba):
    """Teal glaze -> moss green; brown swirls -> gold; the dark bits stay."""
    rgb = rgba[..., :3]
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn + 1e-6
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    s = d / (mx + 1e-6)
    v = mx
    teal = (h > 0.35) & (h < 0.6) & (s > 0.12)
    brown = (h < 0.14) & (s > 0.12)
    h2 = h.copy()
    s2 = s.copy()
    v2 = v.copy()
    h2[teal] = 0.28 + (h[teal] - 0.46) * 0.5
    s2[teal] = np.clip(s[teal] * 1.05 + 0.08, 0, 1)
    v2[teal] = v[teal] * 0.72
    h2[brown] = 0.115
    s2[brown] = np.clip(s[brown] * 1.2 + 0.12, 0, 0.8)
    v2[brown] = np.clip(v[brown] * 1.25 + 0.08, 0, 1)
    out = np.empty_like(rgb)
    # hsv -> rgb
    i = np.floor(h2 * 6).astype(int) % 6
    f = h2 * 6 - np.floor(h2 * 6)
    p = v2 * (1 - s2)
    q = v2 * (1 - f * s2)
    t = v2 * (1 - (1 - f) * s2)
    choices = [(v2, t, p), (q, v2, p), (p, v2, t), (p, q, v2), (t, p, v2), (v2, p, q)]
    for k, (cr, cg, cb) in enumerate(choices):
        m = i == k
        out[m, 0], out[m, 1], out[m, 2] = cr[m], cg[m], cb[m]
    res = rgba.copy()
    res[..., :3] = out
    return res


def main():
    src = sys.argv[sys.argv.index("--") + 1]
    tex = os.path.join(src, "Unpacked", "Spiral Motif")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "Tokkuri_Complete.fbx"))
    ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    co = np.array([v.co[:] for v in ob.data.vertices])
    ax = int(np.argmax(np.ptp(co, axis=0)))
    if ax != 2:
        for v in ob.data.vertices:
            c = list(v.co)
            c[2], c[ax] = c[ax], c[2]
            v.co = Vector(c)
        co = np.array([v.co[:] for v in ob.data.vertices])
    k = HEIGHT / np.ptp(co[:, 2])
    mid = Vector(((co[:, 0].max() + co[:, 0].min()) / 2, (co[:, 1].max() + co[:, 1].min()) / 2, co[:, 2].min()))
    for v in ob.data.vertices:
        v.co = (v.co - mid) * k
    bpy.ops.object.shade_smooth()

    base = made(recolour(px(small(os.path.join(tex, "Tokkuri_Diffuse_SpiralMotif_2048.png"), "d", False))), "vigor_jar_base", False)
    rough = px(small(os.path.join(tex, "Tokkuri_Roughness_SpiralMotif_2048.png"), "r", True))
    metal = px(small(os.path.join(tex, "Tokkuri_Metallic_SpiralMotif_2048.png"), "m", True))
    mr = np.ones_like(rough)
    mr[..., 0] = 1.0
    mr[..., 1] = rough[..., 0]
    mr[..., 2] = metal[..., 0]
    mr_img = made(mr, "vigor_jar_mr", True)
    normal = made(px(small(os.path.join(tex, "Tokkuri_Normal_SpiralMotif_2048.png"), "n", True)), "vigor_jar_normal", True)

    mat = bpy.data.materials.new("vigor_jar")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = base
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    tm = nt.nodes.new("ShaderNodeTexImage")
    tm.image = mr_img
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tm.outputs[0], sep.inputs[0])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = normal
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_image_format="JPEG",
                              export_jpeg_quality=85, export_apply=True)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
    os._exit(0)


if __name__ == "__main__":
    main()
