"""The big ghost, the altar's NPC (Willow) and the big ghost's cage, rendered
through the 55deg pipeline (render_sprite.py) at the sprites' density
(scripts/art.gd): albedo at 2x, normal maps at the original density.

User request: a new big ghost that drags the player off to its cage, and a
harmless NPC by the altar, from the user's models (too big for the repo -
kept on the repo's "assets-1" release):
  CG+Soul.fbx  a scene, not one model: the ghoul (a hooded, emaciated
      torso rising out of a smoke cloud, a lantern in one hand and a chain
      in the other) plus two T-posed reference bodies, which are dropped.
      No materials came with it: coloured here.
  WILLOW.fbx   the little horned creature with its staff, merged with a
      display pedestal (cut away here) and a few stray reference parts.
Both are static, so each is rendered in 8 facings (sheet columns: down,
down_left, left, up_left, up, up_right, right, down_right); the game makes
them hover and bob. The cage is built here: an ancient oval iron cage,
rendered as two layers (bars behind the middle, bars in front) so a
prisoner can be drawn between them.

  python tools/render_characters.py RELEASE_DIR OUT_DIR

writes OUT_DIR/{big_ghost,willow}_55deg_{albedo,normal}.png (8 cells in a
row), cage_back_55deg_* / cage_front_55deg_*, and meta.json (cell sizes,
sprite offsets, and per facing where the big ghost's lantern is).
"""
import json
import math
import os
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
M = 1.32  # world units per metre (the player, 1.8 m, stands 2.38 units)
DIRS = ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
GHOST_HEIGHT = 3.6    # units: half as tall again as the player
WILLOW_HEIGHT = 1.9   # units: a little shorter than the player


def solid(name, colour):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Base Color'].default_value = (*colour, 1.0)
    return mat


def world_points(o):
    """Evaluated (modifiers applied) world-space vertices."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    mw = np.array(o.matrix_world)
    return co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]


def decimate(o, ratio):
    mod = o.modifiers.new("decimate", 'DECIMATE')
    mod.ratio = ratio


def normalise(objs, height, center_xy=None):
    """Scales and moves the model so it stands `height` tall with its base
    on the ground, centred on the origin (or on `center_xy`)."""
    pts = np.concatenate([world_points(o) for o in objs])
    lo, hi = pts.min(0), pts.max(0)
    s = height / (hi[2] - lo[2])
    cx, cy = center_xy if center_xy is not None else ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    root.matrix_world = Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -lo[2]))
    bpy.context.view_layer.update()
    return root


def build_ghost(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    for o in list(bpy.data.objects):
        if o.type != 'MESH' or o.name in ("PM3D_Genesis{20}8{2E}1{20}Male", "PM3D_Genesis{20}8{2E}1{20}Male.001"):
            bpy.data.objects.remove(o, do_unlink=True)
    colours = {
        "hood 2": (0.06, 0.06, 0.07),                            # tattered hood
        "PM3D_Genesis{20}8{2E}1{20}Male6": (0.42, 0.45, 0.4),    # grey-green skin
        "Sphere.002": (0.1, 0.1, 0.12),                          # smoke
        "Lamp": (0.28, 0.2, 0.1),
        "Torus.019": (0.16, 0.15, 0.14),                         # chain
        "Sphere": (0.75, 0.95, 0.6),
        "BezierCurve": (0.16, 0.15, 0.14),
    }
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in meshes:
        o.data.materials.clear()
        o.data.materials.append(solid(o.name, colours.get(o.name, (0.3, 0.3, 0.3))))
        if len(o.data.vertices) > 60000:
            decimate(o, 60000 / len(o.data.vertices))
    smoke = bpy.data.objects["Sphere.002"]
    base = world_points(smoke)
    normalise(meshes, GHOST_HEIGHT, ((base[:, 0].min() + base[:, 0].max()) / 2, (base[:, 1].min() + base[:, 1].max()) / 2))
    return meshes, bpy.data.objects["Lamp"]


def build_willow(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    for o in list(bpy.data.objects):
        if o.type != 'MESH' or len(o.data.vertices) == 0 or o.name in ("Plane", "Cylinder.002", "leaf"):
            bpy.data.objects.remove(o, do_unlink=True)
    stick = bpy.data.objects["stick"]
    bpy.ops.object.select_all(action='DESELECT')
    stick.select_set(True)
    bpy.context.view_layer.objects.active = stick
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='LOOSE')
    bpy.ops.object.mode_set(mode='OBJECT')
    # The display pedestal (two wide discs at the bottom) and stray parts
    # far from the creature go.
    body = None
    for o in list(bpy.data.objects):
        if o.type != 'MESH':
            continue
        w = world_points(o)
        if w[:, 2].min() < -2.3 and np.ptp(w[:, 0]) > 4.0:
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    centers = np.array([world_points(o).mean(0) for o in meshes])
    mid = np.median(centers, axis=0)
    for o, c in zip(meshes, centers):
        if np.linalg.norm(c - mid) > 6.0:
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    # Textures the file doesn't carry: a plain green instead of magenta.
    for m in bpy.data.materials:
        if not m.node_tree:
            continue
        for n in list(m.node_tree.nodes):
            if n.type == 'TEX_IMAGE' and (n.image is None or (not n.image.has_data and not n.image.packed_file)):
                for link in list(n.outputs['Color'].links):
                    sock = link.to_socket
                    m.node_tree.links.remove(link)
                    if sock.name == 'Base Color':
                        sock.default_value = (0.3, 0.55, 0.15, 1.0)
    for o in meshes:
        if len(o.data.vertices) > 50000:
            decimate(o, 50000 / len(o.data.vertices))
    normalise(meshes, WILLOW_HEIGHT)
    return meshes


def ellipse_cage():
    """An ancient oval iron cage: bars bowing out from a heavy foot ring to
    a narrow top, three hoops, a ring and chain links on top. Returns
    (back objects, front objects) - split at the middle, toward the camera
    (-Y) is the front."""
    height = 2.55
    radius = 0.62
    bars = 14
    iron = solid("iron", (0.2, 0.15, 0.11))
    halves = {"back": [], "front": []}

    def curve(name, splines, depth, half):
        data = bpy.data.curves.new(name, 'CURVE')
        data.dimensions = '3D'
        data.bevel_depth = depth
        data.bevel_resolution = 2
        for pts in splines:
            sp = data.splines.new('POLY')
            sp.points.add(len(pts) - 1)
            for p, q in zip(sp.points, pts):
                p.co = (q[0], q[1], q[2], 1.0)
        tmp = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(tmp)
        bpy.context.view_layer.update()
        # As a mesh (screen_bounds and the render read meshes).
        mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        bpy.data.objects.remove(tmp, do_unlink=True)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.clear()
        obj.data.materials.append(iron)
        halves[half].append(obj)

    def r_at(t):
        return radius * math.sin(math.pi * (0.1 + 0.8 * t)) ** 0.75

    def z_at(t):
        return 0.12 + (height - 0.12) * t

    for half, sign in (("front", -1), ("back", 1)):
        bar_splines = []
        for i in range(bars):
            a = (i + 0.5) / bars * math.tau
            if math.copysign(1, math.sin(a)) != sign:
                continue
            bar_splines.append([(r_at(t) * math.cos(a), r_at(t) * math.sin(a), z_at(t)) for t in np.linspace(0, 1, 28)])
        curve(f"bars_{half}", bar_splines, 0.024, half)
        hoops = []
        for t in (0.0, 0.33, 0.66, 1.0):
            r = r_at(t)
            arc = np.linspace(0, math.pi, 25) if sign > 0 else np.linspace(math.pi, math.tau, 25)
            hoops.append([(r * math.cos(a), r * math.sin(a), z_at(t)) for a in arc])
        curve(f"hoops_{half}", hoops, 0.04, half)
    # Foot plate (under the prisoner) and the top ring and chain (over them).
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r_at(0.0) + 0.05, depth=0.12, location=(0, 0, 0.06))
    plate = bpy.context.active_object
    plate.data.materials.append(iron)
    halves["back"].append(plate)
    top = z_at(1.0)
    links = []
    for k in range(4):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.018, location=(0, 0, top + 0.08 + k * 0.12),
                                         rotation=(math.pi / 2, 0, (k % 2) * math.pi / 2))
        link = bpy.context.active_object
        link.data.materials.append(iron)
        links.append(link)
    halves["front"].extend(links)
    for objs in halves.values():
        for o in objs:
            o.matrix_world = Matrix.Scale(M, 4) @ o.matrix_world
    bpy.context.view_layer.update()
    return halves["back"], halves["front"]


def downsample_normal(path):
    img = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0
    hh, ww = img.shape[0] // HD, img.shape[1] // HD
    img = img.reshape(hh, HD, ww, HD, 4).mean(axis=(1, 3))
    n = img[..., :3] * 2.0 - 1.0
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    img[..., :3] = n * 0.5 + 0.5
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(path)


def fit(bounds, symmetric=True):
    x0, x1, y0, y1 = bounds["min_x"] - PAD, bounds["max_x"] + PAD, bounds["min_y"] - PAD, bounds["max_y"] + PAD
    if symmetric:
        hx = max(-x0, x1)
        x0, x1 = -hx, hx
    w = math.ceil((x1 - x0) * DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * DENSITY / 8) * 8
    return w, h, (x0 + x1) / 2, (y0 + y1) / 2


def union(bs):
    return {"min_x": min(b["min_x"] for b in bs), "max_x": max(b["max_x"] for b in bs),
            "min_y": min(b["min_y"] for b in bs), "max_y": max(b["max_y"] for b in bs)}


def render_dirs(meshes, out_prefix, marker=None):
    """8 facings in a row; returns meta, with `marker`'s centre per facing
    (world px from the origin at sprite scale 0.5) if given."""
    yaw = rs.Yaw(0.0)
    bs = []
    for d in DIRS:
        yaw.set(rs.DIRS[d])
        bs.append(rs.screen_bounds(meshes))
    w, h, cx, cy = fit(union(bs))
    rs.setup_scene(cy, max(w, h) / DENSITY, w * HD, h * HD, cx)
    marks = []

    def pose(d):
        yaw.set(rs.DIRS[d])
        if marker is not None:
            p = Vector(world_points(marker).mean(0))
            marks.append([round(p.dot(rs.RIGHT) * DENSITY * 0.5, 2), round(-p.dot(rs.UP) * DENSITY * 0.5, 2)])

    rs.pack_sheet(meshes, DIRS, pose, (w * HD, h * HD), len(DIRS), out_prefix)
    downsample_normal(f"{out_prefix}_normal.png")
    meta = {"cell": [w, h], "offset": [round(cx * DENSITY, 2), round(-cy * DENSITY, 2)]}
    if marker is not None:
        meta["marker"] = marks[:len(DIRS)]
    return meta


def render_layers(layers, out_dir):
    """Several layers (name -> objects) with one shared camera."""
    everything = [o for objs in layers.values() for o in objs]
    w, h, cx, cy = fit(rs.screen_bounds(everything))
    rs.setup_scene(cy, max(w, h) / DENSITY, w * HD, h * HD, cx)
    for name, objs in layers.items():
        for o in everything:
            o.hide_render = o not in objs
        for mode in ("albedo", "normal"):
            rs.rewire_materials(objs, mode)
            rs.render_pass(os.path.join(out_dir, f"{name}_55deg_{mode}.png"), mode)
        downsample_normal(os.path.join(out_dir, f"{name}_55deg_normal.png"))
    return {"cell": [w, h], "offset": [round(cx * DENSITY, 2), round(-cy * DENSITY, 2)]}


def main():
    release, out = sys.argv[-2], sys.argv[-1]
    os.makedirs(out, exist_ok=True)
    meta = {}
    only = os.environ.get("ONLY", "")
    if not only or only == "cage":
        bpy.ops.wm.read_factory_settings(use_empty=True)
        back, front = ellipse_cage()
        meta["cage"] = render_layers({"cage_back": back, "cage_front": front}, out)
        print("cage", meta["cage"], flush=True)
    if not only or only == "ghost":
        meshes, lamp = build_ghost(os.path.join(release, "CG+Soul.fbx"))
        meta["big_ghost"] = render_dirs(meshes, os.path.join(out, "big_ghost_55deg"), lamp)
        print("big_ghost", meta["big_ghost"], flush=True)
    if not only or only == "willow":
        meshes = build_willow(os.path.join(release, "WILLOW.fbx"))
        meta["willow"] = render_dirs(meshes, os.path.join(out, "willow_55deg"))
        print("willow", meta["willow"], flush=True)
    path = os.path.join(out, "meta.json")
    old = json.load(open(path)) if os.path.exists(path) else {}
    old.update(meta)
    json.dump(old, open(path, "w"), indent=1)


if __name__ == "__main__":
    main()
