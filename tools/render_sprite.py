"""Render a 3D model into a 2D albedo + normal-map sprite pair for the game.

Matches the oil barrel art pipeline exactly (reverse-engineered from
oil_barrel_55deg_normal.png, verified to within 1/255 per channel):
  - orthographic camera, 55 deg above the horizontal, looking toward +Y
  - albedo: unlit base color (texture x vertex color), transparent background
  - normal: camera-space normal (X right, Y up, Z toward viewer), encoded as
    n * 0.5 + 0.5, OpenGL convention (green = up) - what Godot's 2D lights
    expect in a CanvasTexture's normal_texture

Needs Blender's Python module (pip install "bpy==4.2.*", Python 3.11).

  # 1) measure each model's projected bounds (world units):
  python tools/render_sprite.py measure art_src/dead_tree/dead_tree_1.glb
  # 2) render every model in a set with ONE shared camera, so relative sizes
  #    stay true and the model origin lands on the same pixel in every sprite:
  python tools/render_sprite.py render MODEL.glb OUT_PREFIX \
      --center-y 5.265 --ortho-scale 13.28 --res 270 360

Pick --center-y / --ortho-scale from the union of the measured bounds:
center-y = (min_y + max_y) / 2, ortho-scale = (max_y - min_y) * ~1.06 for a
portrait canvas (ortho-scale spans the longer image side). The model origin
then sits at pixel (res_x / 2, res_y / 2 + center_y * res_y / ortho_scale).
"""
import argparse
import json
import math

import bpy
from mathutils import Vector

ELEV = math.radians(55.0)
FORWARD = Vector((0.0, math.cos(ELEV), -math.sin(ELEV)))
RIGHT = Vector((1.0, 0.0, 0.0))
UP = Vector((0.0, math.sin(ELEV), math.cos(ELEV)))
BACK = -FORWARD


def load_model(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o.type == 'MESH']


def screen_bounds(meshes):
    xs, ys = [], []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        ev = o.evaluated_get(depsgraph)
        for v in ev.data.vertices:
            p = ev.matrix_world @ v.co
            xs.append(p.dot(RIGHT))
            ys.append(p.dot(UP))
    return {"min_x": min(xs), "max_x": max(xs), "min_y": min(ys), "max_y": max(ys)}


def rewire_materials(meshes, mode):
    """Route every material's surface to an emission of albedo or encoded normal."""
    for mat in {s.material for o in meshes for s in o.material_slots if s.material}:
        nt = mat.node_tree
        out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output), None) \
            or nt.nodes.new('ShaderNodeOutputMaterial')
        for n in [n for n in nt.nodes if n.name.startswith("__sprite_")]:
            nt.nodes.remove(n)
        bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        emit = nt.nodes.new('ShaderNodeEmission')
        emit.name = "__sprite_emit"

        if mode == "albedo":
            src = bsdf.inputs['Base Color'] if bsdf else None
            if src is not None and src.is_linked:
                nt.links.new(src.links[0].from_socket, emit.inputs['Color'])
            elif src is not None:
                emit.inputs['Color'].default_value = src.default_value
        else:
            nsrc = bsdf.inputs['Normal'] if bsdf else None
            if nsrc is not None and nsrc.is_linked:
                normal = nsrc.links[0].from_socket  # keeps the model's own bump detail
            else:
                geo = nt.nodes.new('ShaderNodeNewGeometry')
                geo.name = "__sprite_geo"
                normal = geo.outputs['Normal']
            # World -> camera space by explicit dot products with the camera's
            # axes, sidestepping Cycles' own camera-space axis conventions.
            comb = nt.nodes.new('ShaderNodeCombineXYZ')
            comb.name = "__sprite_comb"
            for i, axis in enumerate((RIGHT, UP, BACK)):
                dot = nt.nodes.new('ShaderNodeVectorMath')
                dot.name = f"__sprite_dot{i}"
                dot.operation = 'DOT_PRODUCT'
                dot.inputs[1].default_value = axis
                nt.links.new(normal, dot.inputs[0])
                nt.links.new(dot.outputs['Value'], comb.inputs[i])
            enc = nt.nodes.new('ShaderNodeVectorMath')
            enc.name = "__sprite_enc"
            enc.operation = 'MULTIPLY_ADD'
            enc.inputs[1].default_value = (0.5, 0.5, 0.5)
            enc.inputs[2].default_value = (0.5, 0.5, 0.5)
            nt.links.new(comb.outputs['Vector'], enc.inputs[0])
            nt.links.new(enc.outputs['Vector'], emit.inputs['Color'])
        nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])


def setup_scene(center_y, ortho_scale, res_x, res_y):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 32  # emission-only, so samples only buy anti-aliasing
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    cam_data = bpy.data.cameras.new("SpriteCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho_scale
    cam_data.clip_end = 1000.0
    cam = bpy.data.objects.new("SpriteCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = UP * center_y - FORWARD * 200.0
    cam.rotation_euler = (math.radians(90.0) - ELEV, 0.0, 0.0)
    scene.camera = cam


def render_pass(path_out, mode):
    view = bpy.context.scene.view_settings
    # Albedo keeps the sRGB texture colors as-is; normals must stay raw data.
    view.view_transform = 'Standard' if mode == "albedo" else 'Raw'
    view.look = 'None'
    view.exposure = 0.0
    view.gamma = 1.0
    bpy.context.scene.render.filepath = path_out
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("measure")
    m.add_argument("model")
    r = sub.add_parser("render")
    r.add_argument("model")
    r.add_argument("out_prefix", help="writes OUT_PREFIX_albedo.png and OUT_PREFIX_normal.png")
    r.add_argument("--center-y", type=float, required=True)
    r.add_argument("--ortho-scale", type=float, required=True)
    r.add_argument("--res", type=int, nargs=2, metavar=("W", "H"), required=True)
    args = parser.parse_args()

    meshes = load_model(args.model)
    if args.cmd == "measure":
        print(json.dumps(screen_bounds(meshes)))
        return
    setup_scene(args.center_y, args.ortho_scale, *args.res)
    for mode in ("albedo", "normal"):
        rewire_materials(meshes, mode)
        render_pass(f"{args.out_prefix}_{mode}.png", mode)


if __name__ == "__main__":
    main()
