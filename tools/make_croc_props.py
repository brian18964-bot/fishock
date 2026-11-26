"""Mr. Croc's two props, made our own from models the user gave (user request: "素材都要經過你再製，
成為我們的資產" - the originals are never committed; only what this makes):

  - the scroll that floats over his head while he has something to talk about (from a rolled
    paper scroll tied with a cord, r1.blend): its paper and cord joined into one mesh, thinned
    out to a game's count, laid along x and a metre long at its middle; its colours ours - an aged
    parchment, darker toward its ends and along its edge (the user: the old sign was too bright),
    and a cord dyed the deep red of his knit;
  - his hat (from a trilby, Hat.obj with its pictures): its brim drawn out wider and dipped a
    little at the front and back, as an old fisherman's; its picture re-dyed - the cream warmer and
    aged, the band a dark brown - and a fine straw weave laid into it.

    bpyenv/bin/python tools/make_croc_props.py -- SCROLL.blend HAT.obj HAT_BASECOLOR.png OUT_DIR

writes OUT_DIR/quest_scroll.glb, OUT_DIR/croc_hat.glb (and the hat's picture inside it).
"""
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SCROLL, HAT, HAT_TEX, OUT = args[:4]

# (the scroll: how many faces it keeps; its parchment and the cord, linear)
SCROLL_FACES = 2600
PARCHMENT = (0.50, 0.36, 0.20)
PARCHMENT_EDGE = (0.30, 0.19, 0.10)
CORD = (0.30, 0.07, 0.05)
# (the hat: how much wider its brim, how far its front and back dip; its re-dye)
BRIM_OUT = 1.18
BRIM_DIP = 0.012
CREAM = np.array([0.86, 0.76, 0.56])
BAND = np.array([0.20, 0.12, 0.07])


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


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT")
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


# ---------------------------------------------------------------- the hat

def make_hat():
    clear()
    bpy.ops.wm.obj_import(filepath=HAT)
    obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    obj.name = "CrocHat"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = obj.data
    pts = np.array([v.co[:] for v in me.vertices])
    lo, hi = pts.min(0), pts.max(0)
    # (it stands on z; its crown's middle over the origin, its brim at z = 0)
    cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
    crown_r = 0.13
    for v in me.vertices:
        x, y, z = v.co.x - cx, v.co.y - cy, v.co.z - lo[2]
        r = math.hypot(x, y)
        # The brim drawn out (only past the crown), dipping at the front and back.
        if r > crown_r and z < 0.05:
            out = crown_r + (r - crown_r) * BRIM_OUT
            k = out / r
            x, y = x * k, y * k
            ang = math.atan2(y, x)
            z -= BRIM_DIP * abs(math.sin(ang)) * ((r - crown_r) / max(hi[0] - cx - crown_r, 0.01))
        v.co = Vector((x, y, z))
    # Its picture re-dyed: the cream warmer and aged, the dark band brown; a straw weave over it.
    src = bpy.data.images.load(HAT_TEX)
    w, h = src.size
    px = np.array(src.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[:, :, :3]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    band = (lum < 0.25).astype(np.float32)[..., None]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    weave = 0.92 + 0.08 * (np.sin(xx * 0.9) * np.sin(yy * 0.9) > 0).astype(np.float32)
    grain = 0.94 + 0.06 * np.random.default_rng(3).random((h, w)).astype(np.float32)
    straw = (lum / max(lum.max(), 1e-3))[..., None] * CREAM * (weave * grain)[..., None]
    dyed = straw * (1.0 - band) + (lum[..., None] * 2.2 * BAND) * band
    out = np.concatenate([np.clip(dyed, 0, 1), px[:, :, 3:]], axis=2)
    img = bpy.data.images.new("croc_hat", w, h)
    img.pixels = out.ravel().tolist()
    # (half its size: the web build's to fetch - it's a small thing on his head)
    img.scale(w // 2, h // 2)
    img.filepath_raw = os.path.join(OUT, "croc_hat_colour.png")
    img.file_format = "PNG"
    img.save()
    m = bpy.data.materials.new("CrocHat")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    m.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    me.materials.clear()
    me.materials.append(m)
    bpy.ops.object.shade_smooth()
    export([obj], os.path.join(OUT, "croc_hat.glb"))
    os.remove(os.path.join(OUT, "croc_hat_colour.png"))


os.makedirs(OUT, exist_ok=True)
make_scroll()
make_hat()
