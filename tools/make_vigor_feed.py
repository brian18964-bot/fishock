"""The vitality feed's jar (活力飼料: the user's Tokkuri_Complete bottle mesh),
glazed with a pattern of our own: a plum-wine glaze with rows of gold-edged
fish scales that thin out toward the neck, a gold band at the shoulder, the rope
left a plain hemp. The pattern is made here from noise and cells in the
bottle's own space (not the user's motif textures) and baked into the
bottle's UVs at 1024; only its roughness, metal and (plain) normal detail come from
the user's maps. Upright, base on the ground at the origin, 0.3 m tall.

  bpyenv/bin/python tools/make_vigor_feed.py -- DIR   (DIR holds Tokkuri_Complete.fbx and
                                                      Unpacked/Blank Ceramic/*.png; repo root)

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


def bake_glaze(ob):
    """Our own glaze. The bottle's position at each texel of its UV image is
    baked out (x, y, z packed into a float image), and the pattern is drawn
    from that in numpy: rows of overlapping fish scales, plum-wine with a
    gold edge, a gold band at the shoulder, a hemp-coloured waist and rope."""
    mat = bpy.data.materials.new("glaze_bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    for i, mul, add in ((0, 2.5, 0.5), (1, 2.5, 0.5), (2, 1.0 / HEIGHT, 0.0)):
        m = nt.nodes.new("ShaderNodeMath")
        m.operation = "MULTIPLY_ADD"
        m.inputs[1].default_value = mul
        m.inputs[2].default_value = add
        nt.links.new(sep.outputs[i], m.inputs[0])
        nt.links.new(m.outputs[0], comb.inputs[i])
    nt.links.new(comb.outputs[0], em.inputs[0])
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    img = bpy.data.images.new("pos", SIZE, SIZE, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.cycles.bake_type = "EMIT"
    bpy.ops.object.bake(type="EMIT", margin=6)
    pos = np.array(img.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)
    x = (pos[..., 0] - 0.5) / 2.5
    y = (pos[..., 1] - 0.5) / 2.5
    z = pos[..., 2] * HEIGHT
    ang = np.arctan2(y, x)
    # scales: 26 round, rows 5 mm high; every other row half a scale along
    cols = 26.0
    rowh = 0.0075
    r = np.floor(z / rowh)
    u = ang / (2 * np.pi) * cols + 0.5 * (r % 2)
    fx = (u % 1.0) - 0.5
    fy = (z / rowh) % 1.0
    # each scale is an arch: the distance from its centre (0, 1) up in the row below
    d = np.sqrt(fx * fx + (fy - 1.0) ** 2 * 0.5)
    inside = d
    edge = np.clip((0.62 - inside) / 0.07, 0, 1)
    gold = np.clip(1.0 - np.abs(inside - 0.55) / 0.045, 0, 1)
    shade = np.clip(inside / 0.6, 0, 1)
    plum_dark = np.array([0.20, 0.03, 0.10])
    plum_lite = np.array([0.46, 0.09, 0.22])
    col = plum_dark + (plum_lite - plum_dark) * (1.0 - shade[..., None]) * 0.9
    gold_c = np.array([0.93, 0.70, 0.22])
    col = col * (1 - gold[..., None]) + gold_c * gold[..., None]
    # the shoulder band and the foot ring
    for lo, hi in ((0.2, 0.206), (0.012, 0.018)):
        m = ((z > lo) & (z < hi))[..., None]
        col = np.where(m, gold_c, col)
    # the waist (under the rope) and the rope: hemp
    waist = ((z > 0.156) & (z < 0.186))[..., None]
    hemp = np.array([0.62, 0.48, 0.28]) * (0.85 + 0.15 * np.sin(z * 900.0 + ang * 12.0))[..., None]
    col = np.where(waist, hemp, col)
    # the knob on the lid
    knob = (z > 0.285)[..., None]
    col = np.where(knob, gold_c * 0.9, col)
    res = np.ones((SIZE, SIZE, 4), dtype=np.float32)
    res[..., :3] = col
    return made(res, "vigor_jar_base", False)


def main():
    src = sys.argv[sys.argv.index("--") + 1]
    tex = os.path.join(src, "Unpacked", "Blank Ceramic")
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

    base = bake_glaze(ob)
    rough = px(small(os.path.join(tex, "Tokkuri_Roughness_BlankCeramic_2048.png"), "r", True))
    metal = px(small(os.path.join(tex, "Tokkuri_Metallic_BlankCeramic_2048.png"), "m", True))
    mr = np.ones_like(rough)
    mr[..., 0] = 1.0
    mr[..., 1] = rough[..., 0]
    mr[..., 2] = metal[..., 0]
    mr_img = made(mr, "vigor_jar_mr", True)
    normal = made(px(small(os.path.join(tex, "Tokkuri_Normal_BlankCeramic_2048.png"), "n", True)), "vigor_jar_normal", True)

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
