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
center-y = (min_y + max_y) / 2, and keep every asset at the same pixel
density so sizes stay consistent across sets: ortho-scale = max(W, H) /
27.108 (ortho-scale spans the longer image side). The model origin then sits
at pixel (W / 2, H / 2 + center_y * 27.108). Sprites are shown in Godot at
scale 0.5 (2x density for high-DPI screens).

--scale resizes a model about its origin before rendering, for gameplay
sizing or models authored at a different scale than the rest of a pack.
Pass the same --scale to measure and render.

Sets rendered so far (see art_src/):
  dead_tree/*    scale 1.0   --center-y 5.265 --ortho-scale 13.28  --res 270 360
  bush, bush_flowers  x1.9 --foliage-normals, fern x0.41
                     --center-y 0.555 --ortho-scale 4.1316 --res 112 112
  ground_cover/clover_*  scale 1.5   --center-y 0.651 --ortho-scale 1.7707 --res 48 48
  ground_cover/flower_group_*, flower_single_*, grass_wispy x1.0 (grass_wispy with --foliage-normals),
               flower_petal_* x1.5 (flower_petal_4 x3.0, a much smaller model)
               grass_wispy_2 x1.0 --foliage-normals, grass x1.5 --foliage-normals,
               mushroom x2.0, mushroom_laetiporus x0.75, pebble_* x2.0
  pine/*         scale 1.0   --center-y 2.70 --ortho-scale 7.968 --res 200 216
  leafy_tree/*   scale 1.0 --foliage-normals, same camera as pine/*
  twisted_tree/1,2,3,5  x1.0 --foliage-normals --center-x 0.125 --center-y 6.37 --ortho-scale 15.641 --res 384 424
  twisted_tree/4        x1.0 --foliage-normals --center-x 4.58 --center-y 5.295 --ortho-scale 14.166 --res 384 376
                 (origins already sit at the trunk base; no --recenter)
  bush/plant_big_2  x1.2      --center-y 1.873 --ortho-scale 4.427 --res 120 120
  rock/rock_medium  x1.45     --center-y 0.67 --ortho-scale 5.312 --res 144 120
  rock/rock_medium_2, _3  x1.45 --recenter --center-y 0.75 --ortho-scale 5.312 --res 144 144
  ground_cover/rock_path_1..3, rock_path_square_*  x1.0  --center-y 0.0 --ortho-scale 1.7707 --res 48 48
  ground_cover/rock_path_round_thin, _wide, rock_path_square_thin, _wide
                 x1.0  --center-y 0.0 --ortho-scale 2.361 --res 64 64
  ground_cover/tall_grass  x1.0 --foliage-normals (64x64 flower camera)
  ground_cover/plant_1 x1.3, plant_2 x1.4, plant_big_1 x1.4 (64x64 flower camera)
                     --center-y 0.635 --ortho-scale 2.361 --res 64 64
  Quaternius nature collections (several models per file, picked with --object;
  modelled smaller than the MegaKit), one tight camera per model: bounds padded
  by 0.12 units, W/H rounded up to multiples of 8, center = bounds center:
  birch_tree/*   BirchTree_1..5 x1.5 --foliage-normals --base-slice 0.05
  bare_tree/1..5 DeadTree_1..5 (dead_trees_a.glb), 6..10 DeadTree_6..10
                 (dead_trees_b.glb)  x1.5 --base-slice 0.05
  ground_cover/shrub, shrub_flowers  Bush, Bush_Flowers x1.5
  ground_cover/flower_bush_1  Plant_1 (bushes.glb) x1.0 --recenter
  ground_cover/flower_bush_2, _3  Plant_2, Plant_Flowers x1.0
  ground_cover/flower_petal_6  Petals_1 x1.5
  pine/pine_6..10  PineTree_1..5 x1.5 --base-slice 0.05
  maple_tree/1,3,4,5  MapleTree_* x1.5 --foliage-normals --base-slice 0.05
  maple_tree/2        MapleTree_2 x1.5 --foliage-normals --fold-normals (its back
                      clump's normals point away from the viewer)
  palm_tree/*    PalmTree_1..5 x1.5 --base-slice 0.05
  ground_cover/flower_single_3, _4  Flower_1, Flower_2 x2.5
  ground_cover/flower_clump_1..5  Flower_1_Clump..Flower_5_Clump x2.5
  ground_cover/grass_large, grass_small  Grass_Large_Extruded, Grass_Small x2.0
  oak_tree/*     NormalTree_1..5 x1.5 --foliage-normals --base-slice 0.05
  rock/boulder_*  Rock_1..5 x3.5 --recenter
  dock/dock_long*_vertical    x0.34 --yaw 0   --center-y 0.69  --ortho-scale 6.7877 --res 96 184
  dock/dock_long*_horizontal  x0.34 --yaw 90  --center-y 0.715 --ortho-scale 7.673  --res 208 120

Animated sheets (anim / measure-anim; --drop Icosphere, 8 frames per clip,
rows = clips x dirs down/left/right/up, x-symmetric camera per animal):
  critter/rat     x0.35 Rat_Run Rat_Idle          cell 104x88 --center-y 0.258
  critter/frog    x0.34 Frog_Jump Frog_Idle       cell 64x64  --center-y 0.109
  critter/snake   x0.44 Snake_Walk Snake_Idle     cell 56x56  --center-y 0.43
  critter/spider  x0.28 Spider_Walk Spider_Idle   cell 56x48  --center-y 0.041
  critter/wasp    x0.26 Wasp_Flying --facing -90  cell 48x40  --center-y 0.456
  animal/cow, bull  x0.40 Walk Eating --frames 12  cell 120x112 --center-y 0.679 / 0.682
  animal/donkey     x0.45 Walk Eating --frames 12  cell 88x80   --center-y 0.552
  animal/alpaca     x0.42 Walk Eating --frames 12  cell 104x96  --center-y 0.576
  animal/deer       x0.48 Walk Eating Gallop --frames 12  cell 104x96 --center-y 0.706
  animal/horse      x0.54 Walk Eating --frames 12  cell 120x112 --center-y 0.814
  animal/stag       x0.52 Walk Idle Gallop --frames 12  cell 112x104 --center-y 0.823
  animal/fox        x0.29 Walk Idle Gallop --frames 12  cell 56x56 --center-y 0.289
  animal/husky      x0.42 Walk Idle --frames 12  cell 64x64 --center-y 0.383
  animal/shiba      x0.32 Walk Idle --frames 12  cell 48x56 --center-y 0.304
  animal/wolf       x0.42 Walk Idle Gallop --frames 12  cell 72x72 --center-y 0.396
  animal/white_horse  x0.54 Walk Eating --frames 12  cell 120x112 --center-y 0.814
  animal/stegosaurus  x0.25 Stegosaurus_Walk Stegosaurus_Idle  cell 216x192 --center-y 0.37
  animal/apatosaurus  x0.195 Apatosaurus_Walk Apatosaurus_Idle  cell 288x248 --center-y 0.572
  animal/parasaurolophus  x0.32 Parasaurolophus_Walk Parasaurolophus_Idle  cell 152x136 --center-y 0.574
  animal/trex       x0.26 TRex_Walk TRex_Idle  cell 248x224 --center-y 1.317
  animal/triceratops  x0.26 Triceratops_Walk Triceratops_Idle  cell 176x152 --center-y 0.422
  animal/velociraptor x0.24 Velociraptor_Walk Velociraptor_Idle  cell 120x104 --center-y 0.468
  (ortho-scale = max(cell W, H) / 27.108)
"""
import argparse
import json
import math

import bpy
from mathutils import Matrix, Vector

ELEV = math.radians(55.0)
FORWARD = Vector((0.0, math.cos(ELEV), -math.sin(ELEV)))
RIGHT = Vector((1.0, 0.0, 0.0))
UP = Vector((0.0, math.sin(ELEV), math.cos(ELEV)))
BACK = -FORWARD


def base_footprint(meshes, base_slice=0.25):
    """X/Y bounds of the bottom `base_slice` of the model's height (its ground
    contact). A quarter suits rocks; leaning trees need a thin slice (0.05) or
    low canopy gets counted as part of the trunk base."""
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    zmin = min(p.z for p in pts)
    zmax = max(p.z for p in pts)
    base = [p for p in pts if p.z < zmin + base_slice * (zmax - zmin)]
    return (min(p.x for p in base), max(p.x for p in base),
            min(p.y for p in base), max(p.y for p in base))


def load_model(path, scale=1.0, recenter=False, base_slice=0.25, only=None, drop=()):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    for name in drop:
        # Stray helper meshes some exports carry (e.g. the animal pack's
        # unit Icosphere sitting at the origin).
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    if only:
        # Collection files lay several models out in a row; keep just one and
        # bring its origin to the world origin (keeping its height).
        keep = bpy.data.objects[only]
        world = keep.matrix_world.copy()
        keep.parent = None
        keep.matrix_world = world
        keep.location.x = 0.0
        keep.location.y = 0.0
        for o in list(bpy.context.scene.objects):
            if o is not keep:
                bpy.data.objects.remove(o, do_unlink=True)
        bpy.context.view_layer.update()
    roots = [o for o in bpy.context.scene.objects if o.parent is None]
    # Scale about the world origin so the model's ground point stays the anchor.
    for o in roots:
        o.location *= scale
        o.scale *= scale
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if recenter:
        # For models whose origin isn't at their base: slide them so the
        # ground footprint is centered on the origin (height untouched).
        x0, x1, y0, y1 = base_footprint(meshes, base_slice)
        shift = Vector((-(x0 + x1) / 2, -(y0 + y1) / 2, 0.0))
        for o in roots:
            o.location += shift
        bpy.context.view_layer.update()
    return meshes


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


def rewire_materials(meshes, mode, foliage_normals=False, fold_normals=False):
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
            geo = nt.nodes.new('ShaderNodeNewGeometry')
            geo.name = "__sprite_geo"
            nsrc = bsdf.inputs['Normal'] if bsdf else None
            if nsrc is not None and nsrc.is_linked:
                normal = nsrc.links[0].from_socket  # keeps the model's own bump detail
            else:
                normal = geo.outputs['Normal']
            # Cycles negates the shading normal on back-face hits so it faces
            # the viewer, which is right for ordinary meshes. Foliage clumps
            # built from cards carrying custom "rounded" normals (the bushes)
            # need their authored normals kept regardless of which side of a
            # card is visible, so undo the negation for those.
            if foliage_normals:
                sign = nt.nodes.new('ShaderNodeMath')
                sign.name = "__sprite_sign"
                sign.operation = 'MULTIPLY_ADD'
                sign.inputs[1].default_value = -2.0
                sign.inputs[2].default_value = 1.0
                nt.links.new(geo.outputs['Backfacing'], sign.inputs[0])
                flip = nt.nodes.new('ShaderNodeVectorMath')
                flip.name = "__sprite_flip"
                flip.operation = 'SCALE'
                nt.links.new(normal, flip.inputs[0])
                nt.links.new(sign.outputs['Value'], flip.inputs['Scale'])
                normal = flip.outputs['Vector']
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
                value = dot.outputs['Value']
                if i == 2 and fold_normals:
                    # Mirror normals that point away from the viewer back
                    # across the view plane, keeping their left/right and
                    # up/down lean: for canopies whose authored normals point
                    # out from the whole tree, a clump behind the trunk would
                    # otherwise face away and stay dark whatever the light.
                    fold = nt.nodes.new('ShaderNodeMath')
                    fold.name = "__sprite_fold"
                    fold.operation = 'ABSOLUTE'
                    nt.links.new(value, fold.inputs[0])
                    value = fold.outputs['Value']
                nt.links.new(value, comb.inputs[i])
            enc = nt.nodes.new('ShaderNodeVectorMath')
            enc.name = "__sprite_enc"
            enc.operation = 'MULTIPLY_ADD'
            enc.inputs[1].default_value = (0.5, 0.5, 0.5)
            enc.inputs[2].default_value = (0.5, 0.5, 0.5)
            nt.links.new(comb.outputs['Vector'], enc.inputs[0])
            nt.links.new(enc.outputs['Vector'], emit.inputs['Color'])

        surface = emit.outputs['Emission']
        alpha = bsdf.inputs['Alpha'] if bsdf else None
        if alpha is not None and (alpha.is_linked or alpha.default_value < 1.0):
            # Alpha-cutout foliage cards: keep the cut-out in both passes, or
            # every leaf renders as a solid quad.
            clear = nt.nodes.new('ShaderNodeBsdfTransparent')
            clear.name = "__sprite_clear"
            mix = nt.nodes.new('ShaderNodeMixShader')
            mix.name = "__sprite_mix"
            if alpha.is_linked:
                nt.links.new(alpha.links[0].from_socket, mix.inputs['Fac'])
            else:
                mix.inputs['Fac'].default_value = alpha.default_value
            nt.links.new(clear.outputs['BSDF'], mix.inputs[1])
            nt.links.new(surface, mix.inputs[2])
            surface = mix.outputs['Shader']
        nt.links.new(surface, out.inputs['Surface'])


def setup_scene(center_y, ortho_scale, res_x, res_y, center_x=0.0):
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
    cam.location = RIGHT * center_x + UP * center_y - FORWARD * 200.0
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


# Screen directions for animated sheets: yaw applied to a model that faces
# the camera (-Y). Rotating +90deg about Z turns -Y toward +X (screen right).
DIRS = {"down": 0.0, "right": 90.0, "up": 180.0, "left": -90.0}


def find_action(name):
    # Clips are named "<Armature>|<Clip>_<Armature>" (some exports add a bare
    # "<Clip>_<Armature>" duplicate). Match the clip name exactly, so "Idle"
    # doesn't pick up "Idle_2" or "Idle_Headlow".
    def clip(a):
        short = a.name.split("|")[-1]
        head, _, tail = short.rpartition("_")
        return head if tail.endswith("Armature") else short
    matches = [a for a in bpy.data.actions if clip(a) == name]
    if matches:
        return next((a for a in matches if "|" in a.name), matches[0])
    raise SystemExit(f"no action {name!r}; have {[a.name for a in bpy.data.actions]}")


def set_pose(action, frame):
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True  # the importer stacks every clip as NLA strips
    ad.action = action
    whole = math.floor(frame)
    bpy.context.scene.frame_set(int(whole), subframe=frame - whole)
    bpy.context.view_layer.update()


def loop_frames(action, count):
    # Loops end on their first pose, so sample [start, end) evenly.
    start, end = action.frame_range
    return [start + i * (end - start) / count for i in range(count)]


class Yaw:
    """Turns the whole model about the world Z axis (through the origin)."""

    def __init__(self, facing=0.0):
        self.facing = facing
        bpy.context.view_layer.update()
        self.base = {o: o.matrix_world.copy() for o in bpy.context.scene.objects
                     if o.parent is None and o.type != 'CAMERA'}

    def set(self, deg):
        rot = Matrix.Rotation(math.radians(deg + self.facing), 4, 'Z')
        for o, m in self.base.items():
            o.matrix_world = rot @ m
        bpy.context.view_layer.update()


def anim_cells(args):
    """(action, dir name, frame) for every cell, rows = actions x dirs."""
    for name in args.actions:
        action = find_action(name)
        for d in args.dirs:
            for f in loop_frames(action, args.frames):
                yield action, d, f


def measure_anim(meshes, args):
    yaw = Yaw(args.facing)
    total = None
    for action, d, f in anim_cells(args):
        yaw.set(DIRS[d])
        set_pose(action, f)
        b = screen_bounds(meshes)
        if total is None:
            total = b
        else:
            total = {"min_x": min(total["min_x"], b["min_x"]), "max_x": max(total["max_x"], b["max_x"]),
                     "min_y": min(total["min_y"], b["min_y"]), "max_y": max(total["max_y"], b["max_y"])}
    return total


def render_sheet(meshes, args):
    """Renders every cell and packs them into OUT_PREFIX_{albedo,normal}.png:
    one row per (action, direction), one column per frame. Both passes of a
    cell are rendered back to back from the same pose, so the two sheets
    always line up (posing each pass separately let the deer's walk drift by
    a pixel between them)."""
    import os
    import tempfile
    import numpy as np
    yaw = Yaw(args.facing)
    w, h = args.res
    rows = len(args.actions) * len(args.dirs)
    tmp = tempfile.mkdtemp()
    sheets = {mode: np.zeros((rows * h, args.frames * w, 4), dtype=np.float32) for mode in ("albedo", "normal")}
    for i, (action, d, f) in enumerate(anim_cells(args)):
        yaw.set(DIRS[d])
        set_pose(action, f)
        row, col = divmod(i, args.frames)
        for mode, sheet in sheets.items():
            rewire_materials(meshes, mode)
            path = os.path.join(tmp, f"{mode}_{i}.png")
            render_pass(path, mode)
            img = bpy.data.images.load(path)
            img.colorspace_settings.name = 'Non-Color'  # copy stored bytes untouched
            px = np.empty(w * h * 4, dtype=np.float32)
            img.pixels.foreach_get(px)
            bpy.data.images.remove(img)
            # Blender images are bottom-up; build the sheet top-down.
            sheet[row * h:(row + 1) * h, col * w:(col + 1) * w] = np.flipud(px.reshape(h, w, 4))
    for mode, sheet in sheets.items():
        out = bpy.data.images.new(f"sheet_{mode}", args.frames * w, rows * h, alpha=True)
        out.colorspace_settings.name = 'Non-Color'
        out.pixels.foreach_set(np.flipud(sheet).ravel())
        out.filepath_raw = f"{args.out_prefix}_{mode}.png"
        out.file_format = 'PNG'
        out.save()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("measure")
    m.add_argument("model")
    r = sub.add_parser("render")
    r.add_argument("model")
    r.add_argument("out_prefix", help="writes OUT_PREFIX_albedo.png and OUT_PREFIX_normal.png")
    r.add_argument("--center-y", type=float, required=True)
    r.add_argument("--center-x", type=float, default=0.0,
                   help="shift the canvas sideways, for lopsided models; sprite offset.x = +center_x * 27.108")
    r.add_argument("--ortho-scale", type=float, required=True)
    r.add_argument("--res", type=int, nargs=2, metavar=("W", "H"), required=True)
    r.add_argument("--foliage-normals", action="store_true",
                   help="keep authored normals on back faces (foliage cards with custom rounded normals)")
    r.add_argument("--fold-normals", action="store_true",
                   help="mirror away-facing normals toward the viewer (canopies with tree-wide rounded normals)")
    ma = sub.add_parser("measure-anim", help="union screen bounds over every sheet cell")
    ma.add_argument("model")
    a = sub.add_parser("anim", help="render animation sprite sheets (rows = actions x dirs)")
    a.add_argument("model")
    a.add_argument("out_prefix")
    a.add_argument("--center-y", type=float, required=True)
    a.add_argument("--center-x", type=float, default=0.0)
    a.add_argument("--ortho-scale", type=float, required=True)
    a.add_argument("--res", type=int, nargs=2, metavar=("W", "H"), required=True, help="size of ONE cell")
    for p in (ma, a):
        p.add_argument("--actions", nargs="+", required=True, help="clip names, e.g. Rat_Run Rat_Idle")
        p.add_argument("--frames", type=int, default=8, help="frames sampled per clip loop")
        p.add_argument("--dirs", nargs="+", default=["down", "left", "right", "up"], choices=list(DIRS))
        p.add_argument("--facing", type=float, default=0.0,
                       help="extra yaw (deg) that turns the model to face the camera (-Y)")
    for p in (m, r, ma, a):
        p.add_argument("--scale", type=float, default=1.0,
                       help="uniform model scale about the origin, for models authored at a different scale")
        p.add_argument("--recenter", action="store_true",
                       help="center the model's ground footprint on the origin (for off-center origins)")
        p.add_argument("--object", default=None,
                       help="render only this named object from a multi-model file (moved to the origin)")
        p.add_argument("--yaw", type=float, default=0.0,
                       help="turn the model about Z first (deg; +90 turns a camera-facing model to face right)")
        p.add_argument("--drop", action="append", default=[],
                       help="delete this named object after import (repeatable)")
        p.add_argument("--base-slice", type=float, default=0.25,
                       help="fraction of model height counted as its base for --recenter/footprint (0.05 for leaning trees)")
    args = parser.parse_args()

    meshes = load_model(args.model, args.scale, args.recenter, args.base_slice, args.object, args.drop)
    if args.yaw:
        Yaw().set(args.yaw)
    if args.cmd == "measure-anim":
        print(json.dumps(measure_anim(meshes, args)))
        return
    if args.cmd == "anim":
        setup_scene(args.center_y, args.ortho_scale, *args.res, args.center_x)
        render_sheet(meshes, args)
        return
    if args.cmd == "measure":
        bounds = screen_bounds(meshes)
        bounds["footprint_xy"] = base_footprint(meshes, args.base_slice)
        print(json.dumps(bounds))
        return
    setup_scene(args.center_y, args.ortho_scale, *args.res, args.center_x)
    for mode in ("albedo", "normal"):
        rewire_materials(meshes, mode, args.foliage_normals, args.fold_normals)
        render_pass(f"{args.out_prefix}_{mode}.png", mode)


if __name__ == "__main__":
    main()
