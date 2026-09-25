"""The altar and the fuel station (a cluster of oil drums with the kerosene
lamp that lights it), rendered through the 55deg pipeline (render_sprite.py)
at the sprites' density (scripts/art.gd).

User request: the altar and the barrel group with its oil lamp, from the
user's models:
  art_src/altar/ancient_altar.fbx   ASCII FBX (Blender's importer only reads
      binary), so its one mesh is read here. No texture came with it: it's
      given a weathered stone colour.
  art_src/fuel_station/barrel_low.fbx   its textures didn't come with it:
      each drum is painted (yellow, rust orange, dark red) with grime.
  art_src/fuel_station/oil_lamp.fbx (+ tex/)   the kerosene lamp, sat on the
      middle drum - the station's light source.

  python tools/render_props.py OUT_DIR

writes OUT_DIR/altar_55deg_*.png and fuel_station_55deg_*.png (albedo at
2x density, normal at the original density) and prints each sprite's
offset and, for the station, where the lamp's flame is (world px from the
station's origin, at sprite scale 0.5).
"""
import json
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402

DENSITY = 27.108
PAD = 0.1
HD = 2
ROOT = os.path.join(os.path.dirname(__file__), "..", "art_src")
# World units per metre: the player (1.8 m) stands 2.38 units tall, and
# props are drawn a little larger than life to read on a phone.
UNITS_PER_M = 1.32 * 1.25
ALTAR_WIDTH = 4.2       # units across its widest side
LAMP_SCALE = 1.9        # the lamp is small; enlarged to be seen
FLAME_HEIGHT = 0.5      # of the lamp's height


def fbx_ascii_mesh(path):
    """Vertices and polygons of the (single) mesh in an ASCII FBX."""
    text = open(path, encoding="utf-8", errors="replace").read()

    def array(name):
        m = re.search(name + r": \*\d+ \{\s*a: ([^}]*)\}", text)
        return [float(x) for x in m.group(1).replace("\n", "").split(",") if x.strip()]

    verts = array("Vertices")
    idx = [int(v) for v in array("PolygonVertexIndex")]
    points = [Vector(verts[i:i + 3]) for i in range(0, len(verts), 3)]
    polys, cur = [], []
    for i in idx:
        if i < 0:
            cur.append(-i - 1)
            polys.append(cur)
            cur = []
        else:
            cur.append(i)
    return points, polys


def paint(name, base, grime, scale=6.0, amount=0.55, ao_distance=0.3):
    """A material whose base colour is `base` dirtied by noise towards
    `grime` (Object coordinates, so every drum's grime differs)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    coord = nt.nodes.new('ShaderNodeTexCoord')
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = scale
    noise.inputs['Detail'].default_value = 8.0
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[1].position = 0.75
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.inputs[6].default_value = (*base, 1.0)
    mix.inputs[7].default_value = (*grime, 1.0)
    nt.links.new(coord.outputs['Object'], noise.inputs['Vector'])
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    fac = nt.nodes.new('ShaderNodeMath')
    fac.operation = 'MULTIPLY'
    fac.inputs[1].default_value = amount
    nt.links.new(ramp.outputs['Color'], fac.inputs[0])
    nt.links.new(fac.outputs['Value'], mix.inputs['Factor'])
    # Crevices and rims darkened (ambient occlusion), so the relief reads
    # in the flat albedo too.
    ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = ao_distance
    shade = nt.nodes.new('ShaderNodeMix')
    shade.data_type = 'RGBA'
    shade.blend_type = 'MULTIPLY'
    shade.inputs['Factor'].default_value = 1.0
    nt.links.new(mix.outputs[2], shade.inputs[6])
    lift = nt.nodes.new('ShaderNodeMapRange')
    lift.inputs['To Min'].default_value = 0.45
    nt.links.new(ao.outputs['AO'], lift.inputs['Value'])
    nt.links.new(lift.outputs['Result'], shade.inputs[7])
    nt.links.new(shade.outputs[2], bsdf.inputs['Base Color'])
    return mat


def smooth(obj, angle=40.0):
    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(angle))


def build_altar():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    points, polys = fbx_ascii_mesh(os.path.join(ROOT, "altar", "ancient_altar.fbx"))
    mesh = bpy.data.meshes.new("altar")
    mesh.from_pydata([tuple(p) for p in points], [], polys)
    mesh.validate()
    obj = bpy.data.objects.new("Altar", mesh)
    bpy.context.scene.collection.objects.link(obj)
    # 3ds Max's own Z-up coordinates (the FBX's -90 X pre-rotation and the
    # Y-up axis conversion cancel): stand it on the ground, centred.
    xs = [p.x for p in points]
    ys = [p.y for p in points]
    zs = [p.z for p in points]
    scale = ALTAR_WIDTH / max(max(xs) - min(xs), max(ys) - min(ys))
    obj.scale = (scale, scale, scale)
    obj.location = (-(max(xs) + min(xs)) / 2 * scale, -(max(ys) + min(ys)) / 2 * scale, -min(zs) * scale)
    smooth(obj, 35.0)
    obj.data.materials.append(paint("stone", (0.42, 0.4, 0.36), (0.22, 0.23, 0.2), scale=3.0, amount=0.7, ao_distance=0.8))
    bpy.context.view_layer.update()
    return [obj], None


def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def build_station():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = UNITS_PER_M
    # (x, y, yaw deg, lying on its side, paint): -Y is toward the camera.
    drums = [
        ((0.0, 0.3), 20, False, "yellow"),
        ((-0.66, 0.08), 75, False, "rust"),
        ((0.64, 0.12), -40, False, "red"),
        ((0.35, -0.6), 105, True, "yellow"),
    ]
    paints = {
        "yellow": paint("yellow", (0.62, 0.46, 0.1), (0.2, 0.12, 0.06)),
        "rust": paint("rust", (0.55, 0.26, 0.1), (0.16, 0.09, 0.05)),
        "red": paint("red", (0.45, 0.1, 0.08), (0.14, 0.08, 0.05)),
    }
    meshes = []
    template = import_fbx(os.path.join(ROOT, "fuel_station", "barrel_low.fbx"))[0]
    template.data.materials.clear()
    upright = template.matrix_world.copy()  # the importer's axis conversion
    for k, ((x, y), yaw, lying, colour) in enumerate(drums):
        drum = template if k == 0 else template.copy()
        if k:
            drum.data = template.data.copy()
            bpy.context.scene.collection.objects.link(drum)
        drum.data.materials.clear()
        drum.data.materials.append(paints[colour])
        rot = Matrix.Rotation(math.radians(yaw), 4, 'Z')
        if lying:
            # On its side: radius 0.288 m, so its axis sits that high.
            rot = rot @ Matrix.Translation((0, 0, 0.288)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Translation((0, 0, -0.46))
        drum.matrix_world = Matrix.Translation((x * m, y * m, 0)) @ Matrix.Scale(m, 4) @ rot @ upright
        meshes.append(drum)
    smooth_all = meshes[:]
    for d in smooth_all:
        smooth(d, 50.0)
    lamp_objs = import_fbx(os.path.join(ROOT, "fuel_station", "oil_lamp.fbx"))
    for o in lamp_objs:
        if o.name.endswith("LOD_1"):
            bpy.data.objects.remove(o, do_unlink=True)
    lamp = next(o for o in bpy.data.objects if o.name.startswith("OilLamp_LOD_0"))
    lamp.parent = None
    # Its textures, from art_src (the FBX points at the artist's drive).
    for img in bpy.data.images:
        local = os.path.join(ROOT, "fuel_station", "tex", os.path.basename(img.filepath.replace("\\", "/")))
        if os.path.exists(local):
            img.filepath = local
            img.reload()
    top = 0.923 * m
    s = m * LAMP_SCALE
    lamp.matrix_world = Matrix.Translation((0.0, 0.3 * m, top)) @ Matrix.Scale(s, 4) @ lamp.matrix_world
    meshes.append(lamp)
    bpy.context.view_layer.update()
    flame = Vector((0.0, 0.3 * m, top + 0.306 * s * FLAME_HEIGHT))
    return meshes, flame


def render(meshes, out_prefix):
    b = rs.screen_bounds(meshes)
    x0, x1, y0, y1 = b["min_x"] - PAD, b["max_x"] + PAD, b["min_y"] - PAD, b["max_y"] + PAD
    w = math.ceil((x1 - x0) * DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * DENSITY / 8) * 8
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rs.setup_scene(cy, max(w, h) / DENSITY, w * HD, h * HD, cx)
    for mode in ("albedo", "normal"):
        rs.rewire_materials(meshes, mode)
        rs.render_pass(f"{out_prefix}_{mode}.png", mode)
    # Normal map at the original density (see scripts/art.gd).
    path = f"{out_prefix}_normal.png"
    img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    hh, ww = img.shape[0] // HD, img.shape[1] // HD
    img = img.reshape(hh, HD, ww, HD, 4).mean(axis=(1, 3))
    n = img[..., :3] * 2.0 - 1.0
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    img[..., :3] = n * 0.5 + 0.5
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    return {"cell": [w, h], "offset": [round(cx * DENSITY, 2), round(-cy * DENSITY, 2)]}


def main():
    out = sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    meta = {}
    meshes, _ = build_altar()
    meta["altar"] = render(meshes, os.path.join(out, "altar_55deg"))
    meshes, flame = build_station()
    meta["fuel_station"] = render(meshes, os.path.join(out, "fuel_station_55deg"))
    # Sprite scale 0.5: world px = texture px (original density) / 2.
    meta["fuel_station"]["flame"] = [round(flame.dot(rs.RIGHT) * DENSITY * 0.5, 2),
                                     round(-flame.dot(rs.UP) * DENSITY * 0.5, 2)]
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
