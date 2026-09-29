"""The ruined town's buildings, wrecks and junk, from the user's models,
through the 55deg pipeline (render_sprite.py): albedo at Art.DENSITY x,
normal map at the original density.

User request: a post-apocalyptic town map style - "a town overgrown by
nature, fishing in its flooded streets". The user's models (the repo's
"assets-1" release; too big for the repo):
  ABDN+5+BLEND.rar          ABDN 5.blend - a two-storey abandoned shop
  concrete+building.fbx     a gutted concrete block, graffiti (texture.zip)
  Old+Building+.1.blend     one crumbling plaster facade
  Bus+Stop.fbx              a bus shelter (no texture came with it: painted)
  carwreckScan.rar          a scanned wrecked hatchback
  blender_5.0.1.blend       rusty cars under ivy: a van, a sports car, a
                            motorbike, a car seat, an engine (Blender 5)
Needs Blender 5's Python module (pip install bpy==5.0.1) - the ivy file
is Blender 5; render_sprite.py's helpers work there too.

Buildings and the bus stop are rendered facing each of the four sides
(yaw 0/90/180/270), the wrecks in 12 headings (every 30 deg - the game
lines them up along its roads, or askew), ivy-covered and bare.

  python tools/render_ruins.py RELEASE_DIR [--only NAME_PREFIX]

(RELEASE_DIR holding the release files, the .rar/.zip already unpacked
next to them.) Writes assets/sprites/ruins/*_55deg_{albedo,normal}.png
and scripts/ruins_catalog.gd.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "ruins")
MANIFEST = os.path.join(ROOT, "art_src", "ruins_manifest.json")
CATALOG = os.path.join(ROOT, "scripts", "ruins_catalog.gd")
DENSITY = 27.108
NODE_PX = DENSITY * 0.5
SIN55 = math.sin(math.radians(55.0))
HD = 2
PAD = 0.15
M = 1.32  # world units per metre (the player, 1.8 m, stands 2.38 units)
SIDES = [0, 90, 180, 270]
HEADINGS = list(range(0, 360, 30))

VAN = ["SM_asset_04"]
VAN_IVY = ["SM_ivy_00", "SM_ivy_05", "SM_ivy_06", "SM_ivy_07", "SM_ivy_08", "SM_ivy_09"]
SPORTS = ["SM_asset_03"]
SPORTS_IVY = ["SM_ivy_10", "SM_ivy_11"]
BIKE = ["SM_asset_00"]
BIKE_IVY = ["SM_ivy_02", "SM_ivy_03"]
SEAT = ["SM_asset_01"]
SEAT_IVY = ["SM_ivy_01", "SM_ivy_04"]

# name: (source, objects (None = all meshes), kind, size in metres
#        (("height" | "length"), value), yaws, extra)
MODELS = {
    "shop": ("ABDN 5.blend", None, "building", ("height", 9.2), SIDES, {}),
    "block": ("concrete+building.fbx", None, "building", ("height", 10.5), SIDES,
              {"texture": "texture/texture.png", "roof": True}),
    # One wall standing on its own (the rest fallen): front and back only.
    "facade": ("Old+Building+.1.blend", None, "building", ("height", 7.5), [0, 180], {}),
    "bus_stop": ("Bus+Stop.fbx", None, "prop", ("height", 2.7), SIDES, {"paint": "bus_stop"}),
    # The scan lies across its length axis: turned to face down the screen
    # like the rest at yaw 0.
    # It was scanned standing on a patch of ground: that's cut away.
    "hatchback": ("carwreckScan/carMesh.fbx", None, "wreck", ("length", 4.0), HEADINGS,
                  {"facing": 90.0, "trim_ground": 0.05}),
    "van": ("blender_5.0.1.blend", VAN, "wreck", ("length", 4.6), HEADINGS, {}),
    "van_ivy": ("blender_5.0.1.blend", VAN + VAN_IVY, "wreck", ("length", 4.6), HEADINGS, {"scale_by": VAN}),
    "sports": ("blender_5.0.1.blend", SPORTS, "wreck", ("length", 4.3), HEADINGS, {}),
    "sports_ivy": ("blender_5.0.1.blend", SPORTS + SPORTS_IVY, "wreck", ("length", 4.3), HEADINGS,
                   {"scale_by": SPORTS}),
    "bike": ("blender_5.0.1.blend", BIKE, "junk", ("length", 2.1), SIDES, {}),
    "bike_ivy": ("blender_5.0.1.blend", BIKE + BIKE_IVY, "junk", ("length", 2.1), SIDES, {"scale_by": BIKE}),
    "seat": ("blender_5.0.1.blend", SEAT, "junk", ("height", 1.1), [0, 120, 240], {}),
    "seat_ivy": ("blender_5.0.1.blend", SEAT + SEAT_IVY, "junk", ("height", 1.1), [0, 120, 240], {"scale_by": SEAT}),
    "engine": ("blender_5.0.1.blend", ["SM_asset_02"], "junk", ("length", 0.9), [0, 120, 240], {}),
    # Built here (BUILDERS): the street's furniture and junk, wooden houses.
    "street_lamp": ("@street_lamp", None, "prop", ("height", 6.5), SIDES, {}),
    "street_lamp_bent": ("@street_lamp_bent", None, "prop", ("height", 6.5), SIDES, {}),
    "utility_pole": ("@utility_pole", None, "prop", ("height", 8.0), [0, 90], {}),
    "stop_sign": ("@stop_sign", None, "prop", ("height", 2.8), [0, 90, 270], {}),
    "warn_sign": ("@warn_sign", None, "prop", ("height", 2.7), [0, 90, 270], {}),
    "cones": ("@cones", None, "junk", ("height", 0.75), [0, 120, 240], {}),
    "barrels": ("@barrels", None, "junk", ("height", 0.9), [0, 120, 240], {}),
    "tires": ("@tires", None, "junk", ("height", 1.0), [0, 180], {}),
    "barrier": ("@barrier", None, "prop", ("height", 0.8), [0, 90, 30, 150], {}),
    "dumpster": ("@dumpster", None, "prop", ("height", 1.4), SIDES, {}),
    "hydrant": ("@hydrant", None, "junk", ("height", 0.8), [0], {}),
    "trash": ("@trash", None, "junk", ("height", 0.6), [0, 120, 240], {}),
    "rubble": ("@rubble", None, "junk", ("height", 0.9), [0, 120, 240], {}),
    "fence": ("@fence", None, "prop", ("height", 2.0), [0, 90], {}),
    "fence_broken": ("@fence_broken", None, "prop", ("height", 2.0), [0, 90], {}),
    "house": ("@house", None, "building", ("height", 5.1), SIDES, {}),
    "house_dark": ("@house_dark", None, "building", ("height", 5.1), SIDES, {}),
    "house_ruin": ("@house_ruin", None, "building", ("height", 5.1), SIDES, {}),
}


# --- Built here: street furniture, junk and wooden houses --------------------
# The user asked for the ruined town to look lived-in and left: what a
# street keeps when everyone's gone. Painted (grain and grime) to sit with
# the detailed art. Sizes are real, in metres; normalize() scales them.

def _paint(name, base, grime, scale=6.0, amount=0.6):
    from render_props import paint
    return paint(name, base, grime, scale=scale, amount=amount)


def _cyl(r, depth, loc, mat, verts=12, rot=(0.0, 0.0, 0.0), r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc)
    ob = bpy.context.active_object
    ob.rotation_euler = rot
    ob.data.materials.append(mat)
    return ob


def _box(size, loc, mat, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.scale = size
    # Scale baked in, so textures laid on in object space keep their size.
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.rotation_euler = rot
    ob.data.materials.append(mat)
    return ob


def _tex_mat(name, path, scale=1.0, tint=None):
    """An image laid on by box projection in object space (for tileable
    planks and roof tiles on built shapes)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    coord = nt.nodes.new('ShaderNodeTexCoord')
    mapping = nt.nodes.new('ShaderNodeMapping')
    mapping.inputs['Scale'].default_value = (scale, scale, scale)
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(path, check_existing=True)
    tex.projection = 'BOX'
    tex.projection_blend = 0.2
    nt.links.new(coord.outputs['Object'], mapping.inputs['Vector'])
    nt.links.new(mapping.outputs['Vector'], tex.inputs['Vector'])
    out = tex.outputs['Color']
    if tint is not None:
        mix = nt.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        nt.links.new(out, mix.inputs[6])
        mix.inputs[7].default_value = (*tint, 1.0)
        out = mix.outputs[2]
    nt.links.new(out, bsdf.inputs['Base Color'])
    return mat


def build_street_lamp(release, rng, bent=False):
    steel = _paint("lamp_steel", (0.12, 0.13, 0.13), (0.18, 0.08, 0.03))
    glass = _paint("lamp_glass", (0.35, 0.36, 0.3), (0.1, 0.1, 0.08))
    lean = (0.25, 0.1, 0.0) if bent else (0.0, 0.0, 0.0)
    pole = _cyl(0.08, 6.0, (0, 0, 3.0), steel, 10, r2=0.05)
    arm = _cyl(0.04, 1.4, (0, -0.6, 5.9), steel, 8, (math.radians(80), 0, 0))
    head = _box((0.35, 0.6, 0.15), (0, -1.3, 5.95), steel)
    lens = _box((0.28, 0.5, 0.04), (0, -1.3, 5.86), glass)
    base = _cyl(0.2, 0.5, (0, 0, 0.25), steel, 10)
    obs = [pole, arm, head, lens, base]
    if bent:
        pivot = bpy.data.objects.new("pivot", None)
        bpy.context.scene.collection.objects.link(pivot)
        for o in obs[:4]:
            o.parent = pivot
        pivot.rotation_euler = lean
    return obs


def build_utility_pole(release, rng):
    wood = _paint("pole_wood", (0.2, 0.13, 0.08), (0.08, 0.06, 0.04), scale=12.0)
    grey = _paint("insulator", (0.45, 0.45, 0.42), (0.2, 0.2, 0.18))
    wire = _paint("wire", (0.03, 0.03, 0.03), (0.05, 0.05, 0.05))
    obs = [_cyl(0.13, 8.0, (0, 0, 4.0), wood, 10, r2=0.1),
           _box((1.8, 0.12, 0.12), (0, 0, 7.4), wood), _box((1.2, 0.1, 0.1), (0, 0, 6.8), wood)]
    for x in (-0.8, -0.3, 0.3, 0.8):
        obs.append(_cyl(0.05, 0.18, (x, 0, 7.55), grey, 8))
    # Snapped wires hanging down.
    for x, drop in ((-0.8, 2.5), (0.8, 3.6)):
        obs.append(_cyl(0.012, drop, (x, 0.2, 7.5 - drop / 2), wire, 4, (0.12, 0.0, 0.0)))
    obs.append(_box((0.5, 0.4, 0.6), (0, 0.25, 6.2), grey))  # transformer
    return obs


def build_sign(release, rng, kind="stop"):
    steel = _paint("sign_post", (0.3, 0.3, 0.3), (0.2, 0.09, 0.03))
    obs = [_cyl(0.035, 2.4, (0, 0, 1.2), steel, 8)]
    if kind == "stop":
        red = _paint("stop_red", (0.45, 0.04, 0.03), (0.2, 0.08, 0.05), scale=9.0)
        obs.append(_cyl(0.38, 0.03, (0, -0.04, 2.35), red, 8, (math.radians(90), 0, math.radians(22.5))))
    else:
        yellow = _paint("sign_yellow", (0.6, 0.45, 0.05), (0.25, 0.15, 0.05), scale=9.0)
        obs.append(_cyl(0.4, 0.03, (0, -0.04, 2.3), yellow, 3, (math.radians(90), 0, math.radians(90))))
    lean = rng.uniform(-0.25, 0.25)
    for o in obs:
        o.rotation_euler.x += lean
    return obs


def build_cones(release, rng):
    orange = _paint("cone_orange", (0.7, 0.15, 0.02), (0.25, 0.1, 0.04), scale=9.0)
    white = _paint("cone_white", (0.7, 0.7, 0.68), (0.3, 0.3, 0.28), scale=9.0)
    obs = []
    for i, (x, y, fallen) in enumerate(((0, 0, False), (0.6, 0.3, False), (-0.5, 0.5, True))):
        parts = [_box((0.45, 0.45, 0.04), (x, y, 0.02), orange), _cyl(0.17, 0.7, (x, y, 0.37), orange, 12, r2=0.03),
                 _cyl(0.12, 0.1, (x, y, 0.42), white, 12, r2=0.1)]
        if fallen:
            for p in parts:
                p.rotation_euler = (math.radians(85), 0, 0.6)
                p.location.z = 0.18
        obs += parts
    return obs


def build_barrels(release, rng):
    rust = _paint("barrel_rust", (0.25, 0.1, 0.04), (0.08, 0.05, 0.03), scale=8.0, amount=0.7)
    blue = _paint("barrel_blue", (0.05, 0.12, 0.25), (0.2, 0.08, 0.03), scale=8.0, amount=0.7)
    obs = []
    for x, y, mat, fallen in ((0, 0, rust, False), (0.62, 0.1, blue, False), (0.2, 0.75, rust, True)):
        b = _cyl(0.29, 0.88, (x, y, 0.44), mat, 16)
        if fallen:
            b.rotation_euler = (math.radians(90), 0, 0.8)
            b.location.z = 0.29
        obs.append(b)
    return obs


def build_tires(release, rng):
    rubber = _paint("tire", (0.03, 0.03, 0.03), (0.08, 0.07, 0.06), scale=10.0)
    obs = []
    for i in range(4):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.33, minor_radius=0.12, location=(0.03 * i, 0.02 * i, 0.12 + 0.23 * i))
        t = bpy.context.active_object
        t.rotation_euler = (rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), 0)
        t.data.materials.append(rubber)
        obs.append(t)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.33, minor_radius=0.12, location=(0.9, 0.2, 0.3))
    t = bpy.context.active_object
    t.rotation_euler = (math.radians(80), 0, 0.5)
    t.data.materials.append(rubber)
    obs.append(t)
    return obs


def build_barrier(release, rng):
    concrete = _paint("barrier", (0.42, 0.41, 0.38), (0.12, 0.12, 0.1), scale=5.0, amount=0.7)
    stripe = _paint("barrier_stripe", (0.6, 0.05, 0.03), (0.3, 0.1, 0.06), scale=8.0)
    import bmesh
    me = bpy.data.meshes.new("barrier")
    bm = bmesh.new()
    prof = [(-0.3, 0.0), (0.3, 0.0), (0.3, 0.1), (0.12, 0.35), (0.1, 0.8), (-0.1, 0.8), (-0.12, 0.35), (-0.3, 0.1)]
    front = [bm.verts.new((-1.5, x, z)) for x, z in prof]
    back = [bm.verts.new((1.5, x, z)) for x, z in prof]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(prof)
    for i in range(n):
        bm.faces.new((front[i], front[(i + 1) % n], back[(i + 1) % n], back[i]))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("barrier", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(concrete)
    band = _box((0.6, 0.23, 0.12), (-0.7, 0.0, 0.62), stripe)
    band2 = _box((0.6, 0.23, 0.12), (0.7, 0.0, 0.62), stripe)
    return [ob, band, band2]


def build_dumpster(release, rng):
    green = _paint("dumpster", (0.06, 0.16, 0.08), (0.2, 0.09, 0.03), scale=7.0, amount=0.7)
    dark = _paint("dumpster_lid", (0.04, 0.05, 0.04), (0.1, 0.06, 0.03))
    obs = [_box((1.9, 1.1, 1.15), (0, 0, 0.7), green), _box((1.95, 0.6, 0.06), (0, -0.25, 1.33), dark, (0.25, 0, 0))]
    for x in (-0.8, 0.8):
        for y in (-0.4, 0.4):
            obs.append(_cyl(0.07, 0.12, (x, y, 0.07), dark, 8, (math.radians(90), 0, 0)))
    trash = _paint("trash", (0.02, 0.02, 0.02), (0.1, 0.1, 0.1))
    for i in range(3):
        b = _rock(0.28, (rng.uniform(-1.3, 1.3), rng.uniform(0.7, 1.0), 0.22), trash, rng)
        obs.append(b)
    return obs


def _rock(r, loc, mat, rng, squash=0.7):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=loc)
    ob = bpy.context.active_object
    for v in ob.data.vertices:
        v.co *= rng.uniform(0.85, 1.12)
    ob.scale = (1.0, rng.uniform(0.8, 1.2), squash)
    ob.data.materials.append(mat)
    return ob


def build_hydrant(release, rng):
    red = _paint("hydrant", (0.45, 0.05, 0.03), (0.15, 0.06, 0.03), scale=9.0)
    return [_cyl(0.13, 0.6, (0, 0, 0.3), red, 12), _cyl(0.15, 0.1, (0, 0, 0.62), red, 12),
            _cyl(0.1, 0.15, (0, 0, 0.72), red, 12, r2=0.04), _cyl(0.05, 0.14, (0.15, 0, 0.42), red, 8, (0, math.radians(90), 0)),
            _cyl(0.05, 0.14, (-0.15, 0, 0.42), red, 8, (0, math.radians(90), 0)), _cyl(0.2, 0.05, (0, 0, 0.03), red, 12)]


def build_trash(release, rng):
    bag = _paint("trash_bag", (0.02, 0.02, 0.025), (0.08, 0.08, 0.08), scale=12.0)
    obs = []
    for i in range(int(rng.integers(4, 7))):
        obs.append(_rock(rng.uniform(0.2, 0.32), (rng.uniform(-0.6, 0.6), rng.uniform(-0.4, 0.4), 0.18), bag, rng, 0.8))
    return obs


def build_rubble(release, rng):
    concrete = _paint("rubble", (0.33, 0.31, 0.29), (0.1, 0.1, 0.08), scale=5.0, amount=0.7)
    brick = _paint("brick", (0.32, 0.1, 0.06), (0.12, 0.06, 0.04), scale=8.0)
    rebar = _paint("rebar", (0.15, 0.06, 0.02), (0.05, 0.03, 0.02))
    obs = [_rock(0.9, (0, 0, 0.1), concrete, rng, 0.45)]
    for i in range(14):
        a, r = rng.uniform(0, math.tau), rng.uniform(0.3, 1.3)
        mat = brick if rng.random() < 0.4 else concrete
        c = _box((rng.uniform(0.15, 0.45), rng.uniform(0.12, 0.3), rng.uniform(0.1, 0.2)),
                 (math.cos(a) * r, math.sin(a) * r * 0.7, rng.uniform(0.05, 0.35)), mat,
                 (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, math.tau)))
        obs.append(c)
    for i in range(4):
        obs.append(_cyl(0.015, rng.uniform(0.8, 1.4), (rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3), 0.5), rebar, 5,
                        (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0)))
    return obs


def build_fence(release, rng, broken=False):
    """Chain-link: steel posts and rails, the diamond mesh as thin wires."""
    steel = _paint("fence_steel", (0.3, 0.3, 0.29), (0.16, 0.07, 0.03), scale=8.0)
    length, height = 4.0, 1.9
    obs = []
    for x in (-length / 2, 0.0, length / 2):
        obs.append(_cyl(0.035, height + 0.1, (x, 0, (height + 0.1) / 2), steel, 8))
    obs.append(_cyl(0.025, length, (0, 0, height), steel, 6, (0, math.radians(90), 0)))
    step = 0.22
    n = int(length / step)
    for i in range(-n, n + 1):
        for sgn in (1, -1):
            x0 = -length / 2 + i * step
            # A diagonal from the bottom rail to the top, clipped to the panel.
            xa, xb = x0, x0 + sgn * height
            if max(xa, xb) < -length / 2 or min(xa, xb) > length / 2:
                continue
            ta = max(0.0, (-length / 2 - xa) / (xb - xa)) if xb != xa else 0.0
            tb = min(1.0, (length / 2 - xa) / (xb - xa)) if xb != xa else 1.0
            t0, t1 = min(ta, tb), max(ta, tb)
            t0 = max(t0, 0.0)
            t1 = min(t1, 1.0)
            if broken and x0 > 0.3 and rng.random() < 0.6:
                t1 = t0 + (t1 - t0) * rng.uniform(0.2, 0.6)
            p0 = Vector((xa + (xb - xa) * t0, 0, height * t0))
            p1 = Vector((xa + (xb - xa) * t1, 0, height * t1))
            d = p1 - p0
            if d.length < 0.05:
                continue
            w = _cyl(0.008, d.length, (p0 + p1) / 2, steel, 4)
            w.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
            obs.append(w)
    if broken:
        for o in obs:
            if o.location.x > 0.5:
                o.rotation_euler.x += 0.35
    return obs


def _shingles():
    mat = _paint("shingles", (0.16, 0.12, 0.1), (0.08, 0.12, 0.05), scale=3.0, amount=0.75)
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    col = bsdf.inputs['Base Color'].links[0].from_socket
    coord = nt.nodes.new('ShaderNodeTexCoord')
    wave = nt.nodes.new('ShaderNodeTexWave')
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'Y'
    wave.inputs['Scale'].default_value = 3.0
    wave.inputs['Distortion'].default_value = 1.5
    nt.links.new(coord.outputs['Object'], wave.inputs['Vector'])
    rows = nt.nodes.new('ShaderNodeMapRange')
    rows.inputs['To Min'].default_value = 0.7
    nt.links.new(wave.outputs['Fac'], rows.inputs['Value'])
    mul = nt.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    nt.links.new(col, mul.inputs[6])
    nt.links.new(rows.outputs['Result'], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs['Base Color'])
    return mat


def build_house(release, rng, collapsed=False, paint_walls=(0.55, 0.5, 0.45)):
    """A small wooden house: plank walls, a tiled gable roof, a door, the
    windows boarded up. Collapsed: the roof fallen in, a wall half down."""
    tex = os.path.join(release, "textures")
    planks = _tex_mat("house_planks", os.path.join(tex, "Light Wood_Base_Color.png"), 0.4, paint_walls)
    # (The pack's roof texture is laid out for its own model - an atlas -
    # so the shingles are painted: dark, weathered, mossy.)
    roof = _shingles()
    board = _paint("boards", (0.14, 0.1, 0.07), (0.05, 0.04, 0.03), scale=10.0)
    door = _paint("door", (0.12, 0.08, 0.05), (0.05, 0.04, 0.03), scale=10.0)
    base = _paint("foundation", (0.25, 0.24, 0.22), (0.08, 0.08, 0.06))
    w, d, h = 6.0, 5.0, 3.0
    obs = [_box((w + 0.3, d + 0.3, 0.3), (0, 0, 0.15), base)]
    walls = [(w, 0.15, (0, -d / 2, 0.3 + h / 2)), (w, 0.15, (0, d / 2, 0.3 + h / 2)),
             (0.15, d, (-w / 2, 0, 0.3 + h / 2)), (0.15, d, (w / 2, 0, 0.3 + h / 2))]
    for i, (sx, sy, loc) in enumerate(walls):
        hh = h * (0.45 if collapsed and i == 3 else 1.0)
        obs.append(_box((sx, sy, hh), (loc[0], loc[1], 0.3 + hh / 2), planks))
    # Gable ends and the roof.
    import bmesh
    for x in (-w / 2, w / 2):
        if collapsed and x > 0:
            continue
        me = bpy.data.meshes.new("gable")
        bm = bmesh.new()
        vs = [bm.verts.new((x, -d / 2, 0.3 + h)), bm.verts.new((x, d / 2, 0.3 + h)), bm.verts.new((x, 0, 0.3 + h + 1.8))]
        bm.faces.new(vs)
        bm.to_mesh(me)
        bm.free()
        g = bpy.data.objects.new("gable", me)
        bpy.context.scene.collection.objects.link(g)
        g.data.materials.append(planks)
        obs.append(g)
    slope = math.atan2(1.8, d / 2)
    run = math.hypot(1.8, d / 2) + 0.4
    for side in (-1, 1):
        if collapsed and side > 0:
            # Fallen in: a slab lying askew inside the walls.
            obs.append(_box((w * 0.7, run, 0.12), (0.6, 0.6, 1.2), roof, (0.5, 0.25, 0.2)))
            continue
        obs.append(_box((w + 0.6, run, 0.12), (0, side * d / 4, 0.3 + h + 0.9), roof, (-side * slope, 0, 0)))
    obs.append(_box((1.0, 0.05, 2.1), (-1.2, -d / 2 - 0.08, 1.35), door))
    for x in (0.8, 2.0):
        for k in range(3):
            obs.append(_box((0.95, 0.04, 0.14), (x, -d / 2 - 0.09, 1.6 + k * 0.3), board, (0, rng.uniform(-0.2, 0.2), 0)))
    return obs


BUILDERS = {
    "street_lamp": lambda r, g: build_street_lamp(r, g),
    "street_lamp_bent": lambda r, g: build_street_lamp(r, g, bent=True),
    "utility_pole": build_utility_pole,
    "stop_sign": lambda r, g: build_sign(r, g, "stop"),
    "warn_sign": lambda r, g: build_sign(r, g, "warn"),
    "cones": build_cones, "barrels": build_barrels, "tires": build_tires, "barrier": build_barrier,
    "dumpster": build_dumpster, "hydrant": build_hydrant, "trash": build_trash, "rubble": build_rubble,
    "fence": lambda r, g: build_fence(r, g), "fence_broken": lambda r, g: build_fence(r, g, broken=True),
    "house": lambda r, g: build_house(r, g),
    "house_dark": lambda r, g: build_house(r, g, paint_walls=(0.3, 0.26, 0.22)),
    "house_ruin": lambda r, g: build_house(r, g, collapsed=True),
}


def load(release, spec):
    src, objects, _kind, _size, _yaws, extra = spec
    if src.startswith("@"):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        import zlib
        BUILDERS[src[1:]](release, np.random.default_rng(zlib.crc32(src.encode())))
        bpy.context.view_layer.update()
        return [o for o in bpy.data.objects if o.type == 'MESH']
    path = os.path.join(release, src)
    if path.endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=path)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=path)
    for o in list(bpy.data.objects):
        if o.type != 'MESH' or (objects is not None and o.name not in objects):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in meshes:
        w = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = w
    bpy.context.view_layer.update()
    if extra.get("trim_ground"):
        trim_ground(meshes, extra["trim_ground"])
    if extra.get("texture"):
        img = bpy.data.images.load(os.path.join(release, extra["texture"]))
        for m in {s.material for o in meshes for s in o.material_slots if s.material}:
            m.use_nodes = True
            nt = m.node_tree
            bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
            t = nt.nodes.new('ShaderNodeTexImage')
            t.image = img
            nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    if extra.get("paint") == "bus_stop":
        for o in meshes:
            o.data.materials.clear()
            o.data.materials.append(_shelter_material())
    if extra.get("roof"):
        meshes += flat_roof(meshes)
    bpy.context.view_layer.update()
    return meshes


def trim_ground(meshes, fraction):
    """Deletes what lies in the bottom `fraction` of the model's height -
    the ground a scan was made standing on."""
    import bmesh
    p = points(meshes)
    cut = p[:, 2].min() + fraction * np.ptp(p[:, 2])
    for o in meshes:
        mw = o.matrix_world
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if (mw @ v.co).z < cut], context='VERTS')
        bm.to_mesh(o.data)
        bm.free()
    bpy.context.view_layer.update()


def _shelter_material():
    """The bus stop came untextured: weathered steel with rust streaks,
    the roof (faces looking up) dark and grimy."""
    from render_props import paint
    mat = paint("shelter_steel", (0.3, 0.31, 0.3), (0.2, 0.09, 0.03), scale=7.0, amount=0.65)
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    steel = bsdf.inputs['Base Color'].links[0].from_socket
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Normal'], sep.inputs[0])
    up = nt.nodes.new('ShaderNodeMapRange')
    up.inputs['From Min'].default_value = 0.6
    up.inputs['From Max'].default_value = 0.8
    nt.links.new(sep.outputs['Z'], up.inputs['Value'])
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    nt.links.new(steel, mix.inputs[6])
    mix.inputs[7].default_value = (0.05, 0.05, 0.055, 1.0)
    nt.links.new(up.outputs['Result'], mix.inputs['Factor'])
    nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
    return mat


def flat_roof(meshes):
    """The concrete block came as four walls: seen from above it needs a
    roof - a flat concrete one, stained, with moss and a little debris,
    set a touch below the wall tops (a parapet)."""
    from render_props import paint
    p = points(meshes)
    lo, hi = p.min(0), p.max(0)
    mat = paint("roof_concrete", (0.3, 0.29, 0.27), (0.1, 0.13, 0.07), scale=5.0, amount=0.75)
    inset = 0.03 * (hi[0] - lo[0])
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2,
                                                         hi[2] - 0.04 * (hi[2] - lo[2])))
    slab = bpy.context.active_object
    slab.scale = (hi[0] - lo[0] - inset, hi[1] - lo[1] - inset, 1.0)
    slab.data.materials.append(mat)
    out = [slab]
    rng = np.random.default_rng(3)
    chunk = paint("roof_junk", (0.22, 0.2, 0.18), (0.08, 0.08, 0.06), scale=6.0, amount=0.6)
    for _ in range(6):
        size = rng.uniform(0.01, 0.03) * (hi[0] - lo[0])
        bpy.ops.mesh.primitive_cube_add(size=size, location=(lo[0] + rng.uniform(0.15, 0.85) * (hi[0] - lo[0]),
                                                              lo[1] + rng.uniform(0.15, 0.85) * (hi[1] - lo[1]),
                                                              slab.location.z + size / 2))
        c = bpy.context.active_object
        c.rotation_euler = (0.0, 0.0, rng.uniform(0, math.tau))
        c.scale = (rng.uniform(1.0, 2.5), 1.0, 0.6)
        c.data.materials.append(chunk)
        out.append(c)
    return out


def points(meshes):
    out = []
    for o in meshes:
        co = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", co)
        mw = np.array(o.matrix_world)
        out.append(co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3])
    return np.concatenate(out)


def normalize(meshes, spec):
    """Footprint centre to the origin, ground at z = 0, scaled to size."""
    _src, _objects, _kind, (axis, metres), _yaws, extra = spec
    ref = [o for o in meshes if o.name in extra["scale_by"]] if extra.get("scale_by") else meshes
    p = points(ref)
    lo, hi = p.min(0), p.max(0)
    if axis == "height":
        s = metres * M / (hi[2] - lo[2])
    else:
        s = metres * M / max(hi[0] - lo[0], hi[1] - lo[1])
    base = p[p[:, 2] < lo[2] + 0.15 * (hi[2] - lo[2])]
    cx, cy = (base[:, 0].min() + base[:, 0].max()) / 2, (base[:, 1].min() + base[:, 1].max()) / 2
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in meshes:
        o.parent = root
    root.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -lo[2]))
    bpy.context.view_layer.update()
    return root


def screen_bounds(meshes):
    p = points(meshes)
    xs = p @ np.array(rs.RIGHT)
    ys = p @ np.array(rs.UP)
    return {"min_x": xs.min(), "max_x": xs.max(), "min_y": ys.min(), "max_y": ys.max()}


def footprint(meshes):
    """The model's base, as an outline in node-local px (convex hull of
    its bottom quarter, depth foreshortened by sin 55deg)."""
    p = points(meshes)
    top = p[:, 2].max()
    base = p[p[:, 2] < 0.25 * top][:, :2]
    if len(base) > 4000:
        base = base[np.random.default_rng(0).choice(len(base), 4000, replace=False)]
    hull = _hull(base)
    return [[round(x * NODE_PX, 1), round(-y * NODE_PX * SIN55, 1)] for x, y in hull]


def _hull(pts):
    pts = sorted(set(map(tuple, np.round(pts, 4))))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    hull = lower[:-1] + upper[:-1]
    # A handful of points is plenty for collision.
    if len(hull) > 12:
        idx = np.linspace(0, len(hull), 12, endpoint=False).astype(int)
        hull = [hull[i] for i in idx]
    return hull


def render(release, name):
    spec = MODELS[name]
    meshes = load(release, spec)
    root = normalize(meshes, spec)
    base = root.matrix_world.copy()
    records = []
    for yaw in spec[4]:
        turn = yaw + spec[5].get("facing", 0.0)
        root.matrix_world = Matrix.Rotation(math.radians(turn), 4, 'Z') @ base
        bpy.context.view_layer.update()
        b = screen_bounds(meshes)
        w = math.ceil((b["max_x"] - b["min_x"] + 2 * PAD) * DENSITY / 8) * 8
        h = math.ceil((b["max_y"] - b["min_y"] + 2 * PAD) * DENSITY / 8) * 8
        cx, cy = (b["min_x"] + b["max_x"]) / 2, (b["min_y"] + b["max_y"]) / 2
        for o in [o for o in bpy.data.objects if o.type == 'CAMERA']:
            bpy.data.objects.remove(o, do_unlink=True)
        rs.setup_scene(cy, max(w, h) / DENSITY, w, h, cx)
        prefix = os.path.join(OUT, "%s_%d_55deg" % (name, yaw))
        rs.rewire_materials(meshes, "normal", foliage_normals=True)
        rs.render_pass(prefix + "_normal.png", "normal")
        scene = bpy.context.scene
        scene.render.resolution_x, scene.render.resolution_y = w * HD, h * HD
        rs.rewire_materials(meshes, "albedo")
        rs.render_pass(prefix + "_albedo.png", "albedo")
        fp = footprint(meshes)
        front = max(p[1] for p in fp)
        records.append({
            "name": "%s_%d" % (name, yaw), "family": name, "kind": spec[2], "yaw": yaw,
            "offset": [round(cx * DENSITY, 2), round(-cy * DENSITY, 2)],
            "footprint": fp,
            # Where the player counts as "behind" it: the sprite's area down
            # to the footprint's front edge.
            "fade": [round(b["min_x"] * NODE_PX, 1), round(-b["max_y"] * NODE_PX, 1),
                     round((b["max_x"] - b["min_x"]) * NODE_PX, 1), round(b["max_y"] * NODE_PX + front, 1)],
        })
        print("rendered", records[-1]["name"], flush=True)
    return records


def write_catalog(records):
    lines = [
        "class_name RuinsCatalog",
        "",
        "## Generated by tools/render_ruins.py from the user's ruined-town models -",
        "## re-run the tool rather than editing this. One entry per model and",
        "## facing: yaw 0 faces the camera (down the screen), 90 turned to the right.",
        "## footprint: its base outline, fade: where the player counts as behind",
        "## it - node-local px at sprite scale 0.5; offset in original-density px.",
        "",
        "const ENTRIES := [",
    ]
    for r in records:
        base = "res://assets/sprites/ruins/%s_55deg" % r["name"]
        fp = ", ".join("Vector2(%.1f, %.1f)" % tuple(p) for p in r["footprint"])
        lines.append('\t{"name": "%s", "family": "%s", "kind": "%s", "yaw": %d,' % (r["name"], r["family"], r["kind"], r["yaw"]))
        lines.append('\t "albedo": "%s_albedo.png", "normal": "%s_normal.png",' % (base, base))
        lines.append('\t "offset": Vector2(%.2f, %.2f), "fade": Rect2(%.1f, %.1f, %.1f, %.1f),'
                     % (tuple(r["offset"]) + tuple(r["fade"])))
        lines.append('\t "footprint": [%s]},' % fp)
    lines += ["]", "", "",
              "## The entries of these families (and kind, if given).",
              "static func of(families: Array, kind := \"\") -> Array:",
              "\treturn ENTRIES.filter(func(e): return (families.is_empty() or e.family in families)"
              " and (kind == \"\" or e.kind == kind))"]
    with open(CATALOG, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    args = sys.argv[1:]
    only = args[args.index("--only") + 1] if "--only" in args else ""
    release = [a for a in args if not a.startswith("--") and a != only][0]
    os.makedirs(OUT, exist_ok=True)
    manifest = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    for name in MODELS:
        if only and not name.startswith(only):
            continue
        manifest[name] = render(release, name)
        json.dump(manifest, open(MANIFEST, "w"), indent=1)
    write_catalog([r for n in MODELS if n in manifest for r in manifest[n]])


if __name__ == "__main__":
    main()
