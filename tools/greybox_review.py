"""Review pictures for the greybox animal people (tools/greybox_animals.py):
every picture with the same camera (orthographic, so the side view is a
true side), the same lights and the same ground - the character turns,
nothing else moves.

  views      the T-pose (technical bind pose) from the front, 3/4, side
             and back; black silhouettes of the same; the character at
             about 128 px high.
  original   the character as it is in the game files today
             (art_src/player/ANIMAL_character.glb), from the same angles,
             with its texture and in plain clay.
  poses      the greybox skinned to the game's UAL skeleton
             (owl_character.bind) and put through the tests - arms down,
             arms up, arms forward with the elbows bent, a crouch (UAL's
             Crouch_Idle), the head turned - each counted for skin coming
             out through the clothes and the shorts through the jumper.
  display    a pose for the character (UAL clips, adjusted), apart from the
             bind pose.

    bpyenv/bin/python tools/greybox_review.py -- views ANIMAL GB_DIR OUT_DIR
    bpyenv/bin/python tools/greybox_review.py -- original ANIMAL OUT_DIR
    bpyenv/bin/python tools/greybox_review.py -- poses ANIMAL GB_DIR OUT_DIR UAL1.glb UAL2.glb
    bpyenv/bin/python tools/greybox_review.py -- display ANIMAL GB_DIR OUT_DIR UAL1.glb UAL2.glb
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import owl_character as oc  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# The one camera: orthographic, this many metres across, looking at this
# height; the turns for each view (the character turns, not the camera).
FRAME = 1.5
LOOK_Z = 0.68
VIEWS = {"front": 0.0, "three": -45.0, "side": -90.0, "back": 180.0}
# Zones the greybox's materials stand for (greybox_animals.ZONES' order).
FUR, SKIN, HORN, EYE, KNIT, CLOTH, BUTTON, SCARF, PAD = range(9)


def stage(res=600, samples=24, transparent=False, ground=True, frame=FRAME, look_z=LOOK_Z):
    """Lights, ground and camera - the same for every picture."""
    sc = bpy.context.scene
    for o in [o for o in sc.objects if o.type in ("CAMERA", "LIGHT") or o.name == "ground"]:
        bpy.data.objects.remove(o, do_unlink=True)
    if ground:
        g = bpy.data.meshes.new("ground")
        g.from_pydata([(-6, -6, 0), (6, -6, 0), (6, 6, 0), (-6, 6, 0)], [], [(0, 1, 2, 3)])
        go = bpy.data.objects.new("ground", g)
        sc.collection.objects.link(go)
        gm = bpy.data.materials.new("ground")
        gm.use_nodes = True
        b = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = (0.30, 0.30, 0.31, 1)
        b.inputs["Roughness"].default_value = 0.9
        g.materials.append(gm)
    for rot, e in (((52, 0, -38), 2.3), ((70, 0, 60), 0.6), ((60, 0, 175), 1.2)):
        l = bpy.data.lights.new("sun", "SUN")
        l.energy = e
        l.angle = math.radians(8)
        lo = bpy.data.objects.new("sun", l)
        sc.collection.objects.link(lo)
        lo.rotation_euler = tuple(math.radians(a) for a in rot)
    sc.world = bpy.data.worlds.new("w")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.43, 0.45, 1)
    bg.inputs[1].default_value = 0.45
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = frame
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    cam.location = (0, -6, look_z)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cam
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = transparent
    sc.render.resolution_x = sc.render.resolution_y = res
    return sc


def pivot_all(objs):
    """An empty at the origin the character's top objects hang from (so
    it turns as one)."""
    piv = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(piv)
    for o in objs:
        if o.parent is None:
            o.parent = piv
    return piv


def shoot(path, piv, view):
    piv.rotation_euler = (0, 0, math.radians(VIEWS[view] if isinstance(view, str) else view))
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def silhouette_material():
    m = bpy.data.materials.new("black")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (0, 0, 0, 1)
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def clay_material(v=0.5):
    m = bpy.data.materials.new("clay")
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (v, v, v, 1)
    b.inputs["Roughness"].default_value = 0.62
    return m


def override(objs, mat):
    for o in objs:
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(mat)


# ---------------------------------------------------------------- views

def views(animal, gb_dir, out):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(gb_dir, animal + ".blend"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    piv = pivot_all(meshes)
    stage()
    for v in VIEWS:
        shoot(os.path.join(out, "%s_new_%s.png" % (animal, v)), piv, v)
    # silhouettes: black on nothing
    stage(transparent=True, ground=False)
    override(meshes, silhouette_material())
    for v in VIEWS:
        shoot(os.path.join(out, "%s_sil_%s.png" % (animal, v)), piv, v)


def detail(animal, gb_dir, out, tag):
    """Close views of the T-pose (the same lights; the ground left out):
    the head from the front, 3/4 and side, the left hand from above and
    in front, the left foot from the side and in front, the crotch from
    in front and from below, the tail's root from behind - and for the
    dog, the whole of it without its neckerchief."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(gb_dir, animal + ".blend"))
    with open(os.path.join(gb_dir, animal + "_greybox.json")) as fh:
        j = json.load(fh)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    stage(res=480)
    V = Vector
    # each part found by the body's own points (its box), not guessed
    body = next(o for o in meshes if o.name.startswith("owl_body"))
    co = np.array([(body.matrix_world @ v.co)[:] for v in body.data.vertices])

    def box(sel, pad=1.35):
        pts = co[sel]
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        return V(((lo + hi) / 2).tolist()), float((hi - lo).max()) * pad
    z0 = j["head_rigid"][0]
    head, hs = box(co[:, 2] > z0, 1.15)
    w = V(j["wrist"])
    hand, hsz = box(co[:, 0] > w.x - 0.01, 1.3)
    a = V(j["ankle"])
    foot, fs = box((co[:, 2] < a.z + 0.02) & (co[:, 0] > 0.0), 1.4)
    th = V(j["thigh"])
    crotch = V((0.0, th.y, th.z - 0.05))
    shots = [("head_front", head, (0, -1, 0.05), hs), ("head_three", head, (0.75, -1, 0.1), hs),
             ("head_side", head, (1, 0, 0.05), hs),
             ("hand_top", hand, (0, 0.001, 1), hsz), ("hand_front", hand, (0.15, -1, 0.2), hsz),
             ("foot_side", foot, (1, 0, 0.12), fs), ("foot_front", foot, (0.25, -1, 0.3), fs),
             ("crotch_front", crotch, (0, -1, -0.12), 0.32), ("crotch_low", crotch, (0, -0.45, -1), 0.32)]
    if j.get("tail_box"):
        lo, hi = V(j["tail_box"][0]), V(j["tail_box"][1])
        root = V((0.0, j["tail_root_y"] + 0.02, lo.z + 0.03)) if not j.get("tail") else V(j["tail"][0])
        tc, ts = (lo + hi) / 2, max(hi - lo) * 1.5
        shots += [("tail_back", tc + V((0, 0.0, 0.0)), (0.2, 1, 0.2), max(ts, 0.28)),
                  ("tail_side", tc, (1, 0.1, 0.08), max(ts, 0.28)),
                  ("tail_root", root, (0.35, 1, 0.35), 0.2)]
    for name, c, d, sc in shots:
        close(os.path.join(out, "%s_%s_%s.png" % (animal, tag, name)), c, d, scale=sc)
    if animal == "dog":
        for o in meshes:
            if o.name.startswith("owl_ruff"):
                o.hide_render = True
        piv = pivot_all(meshes)
        stage()
        for v in VIEWS:
            shoot(os.path.join(out, "%s_%s_noscarf_%s.png" % (animal, tag, v)), piv, v)
        piv.rotation_euler = (0, 0, 0)
        close(os.path.join(out, "%s_%s_noscarf_neck_three.png" % (animal, tag)), head + V((0, 0, -0.1)),
              (0.75, -1, 0.1), hs * 1.5)
        close(os.path.join(out, "%s_%s_noscarf_neck_side.png" % (animal, tag)), head + V((0, 0, -0.1)),
              (1, 0, 0.05), hs * 1.5)


def original(animal, out):
    """The game's character today (its .glb at the size the game puts it
    on the skeleton)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glb, js = oc.paths(animal)
    with open(js) as fh:
        size = json.load(fh).get("size", 1.0)
    bpy.ops.import_scene.gltf(filepath=glb)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    piv = pivot_all(meshes)
    piv.scale = (size, size, size)
    stage()
    for v in VIEWS:
        shoot(os.path.join(out, "%s_old_%s.png" % (animal, v)), piv, v)
    override(meshes, clay_material(0.55))
    for v in VIEWS:
        shoot(os.path.join(out, "%s_oldclay_%s.png" % (animal, v)), piv, v)


def lineup(items, out, views_=("front", "side"), gap=0.62, res_h=760):
    """Several characters side by side at the same scale: items are
    (label, path) - a greybox .blend, or a game .glb (sized as the game
    sizes it)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pivots = []
    for i, (label, path) in enumerate(items):
        before = set(bpy.data.objects)
        size = 1.0
        if path.endswith(".glb"):
            bpy.ops.import_scene.gltf(filepath=path)
            js = path[:-4] + ".json"
            if os.path.exists(js):
                with open(js) as fh:
                    size = json.load(fh).get("size", 1.0)
        else:
            with bpy.data.libraries.load(path) as (src, dst):
                dst.objects = list(src.objects)
            for o in dst.objects:
                if o is not None and o.type == "MESH":
                    bpy.context.scene.collection.objects.link(o)
        new = [o for o in set(bpy.data.objects) - before if o.type == "MESH" and o.parent is None]
        piv = pivot_all(new)
        piv.location.x = (i - (len(items) - 1) / 2.0) * gap
        piv.scale = (size,) * 3
        pivots.append(piv)
    width = gap * len(items) + 0.2
    sc = stage(frame=width, look_z=0.62)
    sc.render.resolution_x = int(res_h * width / 1.4)
    sc.render.resolution_y = res_h
    sc.camera.data.ortho_scale = width
    paths = []
    for v in views_:
        for p in pivots:
            p.rotation_euler = (0, 0, math.radians(VIEWS[v]))
        path = "%s_%s.png" % (out, v)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    return paths


# ---------------------------------------------------------------- rig

def skeleton(ual1, ual2):
    """UAL's skeleton (no mannequin) with both libraries' clips."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=ual1)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    keep = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ual2)
    for o in set(bpy.data.objects) - keep:
        bpy.data.objects.remove(o, do_unlink=True)
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        bpy.data.objects.remove(o, do_unlink=True)
    acts = {}
    for a in bpy.data.actions:
        key = a.name.split("|")[-1].split("_Armature")[0]
        acts.setdefault(key, a)
    return arm, acts


def bound(animal, gb_dir, ual1, ual2):
    arm, acts = skeleton(ual1, ual2)
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    files = (os.path.join(gb_dir, animal + "_greybox.glb"), os.path.join(gb_dir, animal + "_greybox.json"))
    with open(files[1]) as fh:
        joints = json.load(fh)
    hips = (arm.matrix_world @ arm.data.bones["pelvis"].head_local).z
    k = oc._scale(hips, joints)
    mesh = oc.bind(arm, "ual", animal, files=files)[0]
    SCALE["k"] = k
    return arm, acts, mesh, files


def pivot_rig(arm):
    """The skinned character back at its own size (the skeleton is UAL's
    size) under a turning pivot."""
    piv = pivot_all([arm])
    piv.scale = (1.0 / SCALE["k"],) * 3
    return piv


def rest(arm):
    ad = arm.animation_data
    ad.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def turn(arm, bone, axis, degrees):
    """Bone `bone` turned about the world axis through its own head."""
    pb = arm.pose.bones[bone]
    mw = arm.matrix_world
    head = mw @ pb.head
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(degrees), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = mw.inverted() @ R @ mw @ pb.matrix
    bpy.context.view_layer.update()


def clip(arm, act, frame):
    ad = arm.animation_data
    ad.action = act
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


SCALE = {"k": 1.0}
TESTS = ["bind", "arms_down", "arms_up", "arms_forward", "crouch", "squat", "head_turn", "tail_swing"]
# How far the hips go down in the squat test: a share of the leg's length.
SQUAT = 0.36


def angle_x(v):
    """A direction's angle in the side (y-z) plane: what a turn about the
    world X axis adds to."""
    return math.degrees(math.atan2(v.z, v.y))


def squat(arm, depth=SQUAT, lean=16.0):
    """Both feet flat where they stood, the hips straight down by `depth`
    of the leg's length and the knees forward over the toes (worked out
    for each leg, two-bone IK in the side plane), the trunk leant forward
    a little and the arms forward for balance - a test pose of our own,
    not a clip: the weight on both feet."""
    mw = arm.matrix_world
    pb = arm.pose.bones

    def at(name, end="head"):
        return mw @ (pb[name].head if end == "head" else pb[name].tail)
    legs = {}
    for s in ("l", "r"):
        legs[s] = (at("thigh_" + s), at("calf_" + s), at("foot_" + s))
    hip, knee, ank = legs["l"]
    drop = depth * ((knee - hip).length + (ank - knee).length)
    pel = pb["pelvis"]
    pel.matrix = mw.inverted() @ Matrix.Translation((0.0, 0.0, -drop)) @ mw @ pel.matrix
    bpy.context.view_layer.update()
    turn(arm, "spine_01", "X", lean * 0.6)
    turn(arm, "spine_02", "X", lean * 0.4)
    for s in ("l", "r"):
        h0, k0, a0 = legs[s]
        l1, l2 = (k0 - h0).length, (a0 - k0).length
        h = at("thigh_" + s)
        k = at("calf_" + s)
        to = a0 - h
        dist = min(to.length, l1 + l2 - 1e-4)
        bend = math.degrees(math.acos(max(-1.0, min(1.0, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)))))
        # the knee forward (-Y): the thigh turned from hip-to-ankle that much more
        r1 = (angle_x(to) - bend) - angle_x(k - h)
        r1 = (r1 + 180.0) % 360.0 - 180.0
        turn(arm, "thigh_" + s, "X", r1)
        k = at("calf_" + s)
        r2 = angle_x(a0 - k) - angle_x(at("foot_" + s) - k)
        r2 = (r2 + 180.0) % 360.0 - 180.0
        turn(arm, "calf_" + s, "X", r2)
        turn(arm, "foot_" + s, "X", -(r1 + r2))
    for s, sg in (("l", 1), ("r", -1)):
        turn(arm, "upperarm_" + s, "Y", 62 * sg)
        turn(arm, "upperarm_" + s, "Z", -34 * sg)
        turn(arm, "lowerarm_" + s, "Z", -30 * sg)


def tail_bones(arm):
    return sorted(b.name for b in arm.pose.bones if b.name.startswith("tail_"))


def tail_swing(arm, side=22.0, lift=-8.0):
    """The tail swung to one side (more at each bone, as a tail swings)
    and a little up - its bones from owl_character.bind."""
    for i, b in enumerate(tail_bones(arm)):
        turn(arm, b, "Z", side * (0.6 + 0.2 * i))
        turn(arm, b, "X", lift)


def pose(arm, acts, name):
    rest(arm)
    if name == "arms_down":
        turn(arm, "upperarm_l", "Y", 68)
        turn(arm, "upperarm_r", "Y", -68)
    elif name == "arms_up":
        turn(arm, "upperarm_l", "Y", -72)
        turn(arm, "upperarm_r", "Y", 72)
        turn(arm, "lowerarm_l", "Y", -12)
        turn(arm, "lowerarm_r", "Y", 12)
    elif name == "arms_forward":
        turn(arm, "upperarm_l", "Z", -78)
        turn(arm, "upperarm_r", "Z", 78)
        turn(arm, "upperarm_l", "Y", 18)
        turn(arm, "upperarm_r", "Y", -18)
        turn(arm, "lowerarm_l", "Z", -62)
        turn(arm, "lowerarm_r", "Z", 62)
    elif name == "crouch":
        clip(arm, acts["Crouch_Idle_Loop"], 10)
    elif name == "squat":
        squat(arm)
    elif name == "tail_swing":
        turn(arm, "upperarm_l", "Y", 68)
        turn(arm, "upperarm_r", "Y", -68)
        tail_swing(arm)
    elif name == "head_turn":
        turn(arm, "upperarm_l", "Y", 68)
        turn(arm, "upperarm_r", "Y", -68)
        turn(arm, "neck_01", "Z", 18)
        turn(arm, "Head", "Z", 42)
        turn(arm, "Head", "X", -12)


def zones(mesh):
    """Posed vertex positions and, per vertex, its zone (from its faces)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.array([v.co[:] for v in me.vertices])
    co = np.array([(ev.matrix_world @ Vector(c))[:] for c in co])
    rot = ev.matrix_world.to_3x3()
    NORMALS["n"] = np.array([(rot @ v.normal).normalized()[:] for v in me.vertices])
    faces = [list(p.vertices) for p in me.polygons]
    mats = np.array([p.material_index for p in me.polygons])
    names = [m.name.split(".")[0] if m else "" for m in mesh.data.materials]
    zone_of = {}
    for i, n in enumerate(names):
        zone_of[i] = {"gb_fur": FUR, "gb_skin": SKIN, "gb_horn": HORN, "gb_eye": EYE, "gb_knit": KNIT,
                      "gb_cloth": CLOTH, "gb_button": BUTTON, "gb_scarf": SCARF, "gb_pad": PAD}.get(n, -1)
    fz = np.array([zone_of.get(m, -1) for m in mats])
    vz = np.full(len(co), -1)
    for f, z in zip(faces, fz):
        vz[f] = z
    ev.to_mesh_clear()
    return co, faces, fz, vz


NORMALS = {"n": None}
RAYS = [Vector(d).normalized() for d in ((0.31, 0.12, 0.94), (-0.71, 0.53, -0.46), (0.22, -0.95, 0.19))]


def inside(co, faces, fz, zone, pts, near=None):
    """Which of pts are inside the closed surface made by the faces of
    `zone`: by the number of times rays from them cross it (odd for most
    of three rays), and - with `near` - no further than that from it."""
    sel = [f for f, z in zip(faces, fz) if z == zone]
    if not sel:
        return np.zeros(len(pts), dtype=bool)
    tree = BVHTree.FromPolygons([Vector(c) for c in co], sel, all_triangles=False)
    out = np.zeros(len(pts), dtype=bool)
    for i, p in enumerate(pts):
        p = Vector(p)
        if near is not None:
            loc, nrm, idx, dist = tree.find_nearest(p, near)
            if loc is None:
                continue
        odd = 0
        for d in RAYS:
            n = 0
            o = p.copy()
            for _ in range(16):
                hit, nrm, idx, dist = tree.ray_cast(o, d)
                if hit is None:
                    break
                n += 1
                o = hit + d * 1e-5
            odd += n % 2
        out[i] = odd >= 2
    return out


def poke(mesh, covered0):
    """Of the body's vertices the clothes covered in the bind pose, the
    ones out through them now; and of the shorts' under the jumper, the
    ones out through it."""
    co, faces, fz, vz = zones(mesh)
    body = np.where(np.isin(vz, [FUR, PAD, HORN]))[0]
    shorts = np.where(vz == CLOTH)[0]
    if covered0 is None:
        near = 0.035
        cj = inside(co, faces, fz, KNIT, co[body], near)
        ct = inside(co, faces, fz, CLOTH, co[body], near)
        sj = inside(co, faces, fz, KNIT, co[shorts], near)
        return {"body": body[cj | ct], "body_j": body[cj], "body_t": body[ct], "shorts": shorts[sj]}, None
    out_body = []
    for key, zone in (("body_j", KNIT), ("body_t", CLOTH)):
        idx = covered0[key]
        if len(idx):
            ins = inside(co, faces, fz, zone, co[idx])
            out_body.append(idx[~ins])
    ob = np.unique(np.concatenate(out_body)) if out_body else np.array([], dtype=int)
    # a body point counts as through only if it is outside both garments
    if len(ob):
        ins_j = inside(co, faces, fz, KNIT, co[ob])
        ins_t = inside(co, faces, fz, CLOTH, co[ob])
        ob = ob[~(ins_j | ins_t)]
    idx = covered0["shorts"]
    os_ = idx[~inside(co, faces, fz, KNIT, co[idx])] if len(idx) else np.array([], dtype=int)
    # how far out: each point's distance to the nearest of the clothes'
    # surfaces (the jumper's, for the shorts)
    sel = [f for f, z in zip(faces, fz) if z in (KNIT, CLOTH)]
    tree = BVHTree.FromPolygons([Vector(c) for c in co], sel, all_triangles=False)
    tk = BVHTree.FromPolygons([Vector(c) for c in co], [f for f, z in zip(faces, fz) if z == KNIT],
                              all_triangles=False)
    depth = np.array([tree.find_nearest(Vector(co[i]))[3] for i in ob]) if len(ob) else np.zeros(0)
    depth_s = np.array([tk.find_nearest(Vector(co[i]))[3] for i in os_]) if len(os_) else np.zeros(0)
    allt = BVHTree.FromPolygons([Vector(c) for c in co], faces, all_triangles=False)
    return {"body": ob, "shorts": os_, "co": co, "depth": depth, "depth_s": depth_s,
            "area": vertex_area(co, faces), "seen": seen(allt, co, ob), "seen_s": seen(allt, co, os_)}, co


# The four standard views' directions to the camera, in the character's
# frame (faced front): front, 3/4, side, back.
LOOKS = [Vector((0.0, -1.0, 0.0)), Vector((0.7071, -0.7071, 0.0)), Vector((1.0, 0.0, 0.0)), Vector((0.0, 1.0, 0.0))]


def seen(tree, co, idx):
    """Which of the points idx a camera in any of the four standard views
    sees: facing it and nothing of the character in between."""
    out = np.zeros(len(idx), dtype=bool)
    nm = NORMALS["n"]
    for k, i in enumerate(idx):
        p = Vector(co[i])
        for d in LOOKS:
            if nm is not None and Vector(nm[i]).dot(d) <= 0.0:
                continue
            hit = tree.ray_cast(p + d * 2e-4, d)[0]
            if hit is None:
                out[k] = True
                break
    return out


def vertex_area(co, faces):
    """Each vertex's share of the surface (a third of its triangles')."""
    va = np.zeros(len(co))
    for f in faces:
        for j in range(1, len(f) - 1):
            a, b, c = co[f[0]], co[f[j]], co[f[j + 1]]
            ar = 0.5 * np.linalg.norm(np.cross(b - a, c - a)) / 3.0
            va[[f[0], f[j], f[j + 1]]] += ar
    return va


def summary(res, co0, joints):
    """What came through, counted, measured and placed: the number of
    points, how far out (mm: the deepest and the mean) and the surface
    they stand for (cm2), all and per region; the shorts through the
    jumper apart (never added to the body's)."""
    def part(idx, depth, vis):
        if not len(idx):
            return {"points": 0, "depth_max_mm": 0.0, "depth_mean_mm": 0.0, "area_cm2": 0.0,
                    "visible_points": 0, "visible_area_cm2": 0.0}
        return {"points": int(len(idx)), "depth_max_mm": round(float(depth.max()) * 1000, 1),
                "depth_mean_mm": round(float(depth.mean()) * 1000, 1),
                "area_cm2": round(float(res["area"][idx].sum()) * 1e4, 2),
                "visible_points": int(vis.sum()), "visible_area_cm2": round(float(res["area"][idx[vis]].sum()) * 1e4, 2)}
    body = res["body"]
    z = np.zeros(0, dtype=bool)
    out = {"body": part(body, res.get("depth", np.zeros(0)), res.get("seen", z)),
           "shorts": part(res["shorts"], res.get("depth_s", np.zeros(0)), res.get("seen_s", z)), "where": {}}
    if len(body):
        lab = np.array(region_of(co0, body, joints))
        for r in sorted(set(lab)):
            m = lab == r
            out["where"][r] = part(body[m], res["depth"][m], res["seen"][m])
            # (the side with more of them: a mean of both arms is no place)
            pick = body[m]
            sx = np.sign(co0[pick, 0])
            if r != "neck/collar" and (sx > 0).any() and (sx < 0).any():
                pick = pick[sx == (1 if (sx > 0).sum() >= (sx < 0).sum() else -1)]
            out["where"][r]["centre"] = [round(float(v), 4) for v in res["co"][pick].mean(axis=0)]
            # the way they face (posed): where to look at them from
            if NORMALS["n"] is not None:
                nm = NORMALS["n"][pick].mean(axis=0)
                out["where"][r]["facing"] = [round(float(v), 3) for v in nm / max(np.linalg.norm(nm), 1e-6)]
    return out


def regions(co0, idx, joints):
    """Where on the body (by its bind-pose place) the points that came
    through are: counts per region."""
    out = {}
    for r in region_of(co0, idx, joints):
        out[r] = out.get(r, 0) + 1
    return out


def region_of(co0, idx, joints):
    """Each point's region of the body, by its bind-pose place."""
    out = []
    sh = joints["shoulder"]
    th = joints["thigh"]
    kn = joints["knee"]
    box = joints.get("tail_box")
    for p in co0[idx]:
        x, y, z = p
        if box and all(box[0][i] - 0.01 <= p[i] <= box[1][i] + 0.01 for i in range(3)) and y > joints["tail_root_y"] - 0.04:
            r = "tail root"
        elif abs(x) > sh[0] - 0.02 and z > sh[2] - 0.08:
            r = "arm/sleeve"
        elif z > sh[2] - 0.02:
            r = "neck/collar"
        elif z > th[2] + 0.03:
            r = "waist/hem"
        elif abs(x) < th[0] * 0.55 and z > kn[2]:
            r = "crotch"
        elif z > kn[2] - 0.03:
            r = "thigh/cuff"
        else:
            r = "lower leg"
        out.append(r)
    return out


def markers(points, name="poke", r=0.006):
    """Small red balls at points (where something came through)."""
    import bmesh
    bm = bmesh.new()
    for p in points:
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation(Vector(p)))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("red")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (1.0, 0.05, 0.02, 1)
    em.inputs[1].default_value = 3.0
    nt.links.new(em.outputs[0], out.inputs[0])
    me.materials.append(m)
    return ob


def close(path, centre, d, scale=0.34, res=480):
    """A close view: an orthographic camera `scale` across looking at
    `centre` from direction `d` (the ground hidden), then the stage's
    camera back."""
    sc = bpy.context.scene
    keep = sc.camera, sc.render.resolution_x
    cd = bpy.data.cameras.new("close")
    cd.type = "ORTHO"
    cd.ortho_scale = scale
    cam = bpy.data.objects.new("close", cd)
    sc.collection.objects.link(cam)
    d = Vector(d).normalized()
    cam.location = Vector(centre) + d * 3.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x = sc.render.resolution_y = res
    g = sc.objects.get("ground")
    if g is not None:
        g.hide_render = True
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if g is not None:
        g.hide_render = False
    sc.camera = keep[0]
    sc.render.resolution_x = sc.render.resolution_y = keep[1]
    bpy.data.objects.remove(cam, do_unlink=True)
    return path


def look_from(region, c):
    """Which way to look at a region's points (centre c, character
    units, facing -Y): the crotch and hem from in front and a little
    below, the rest from straight out at them, a little above."""
    if region in ("crotch",):
        return (0.0, -1.0, -0.35)
    if region == "tail root":
        return (0.35, 1.0, 0.2)
    h = Vector((c[0], c[1], 0.0))
    if h.length < 0.03:
        h = Vector((0.0, -1.0, 0.0))
    h = h.normalized()
    return (h.x, h.y, 0.35)


# What each test is shot from (the body as a whole).
SHOTS = {"squat": ("front", "three", "side"), "tail_swing": ("back", "three"), "crouch": ("front", "three", "side")}


def poses(animal, gb_dir, out, ual1, ual2):
    arm, acts, mesh, files = bound(animal, gb_dir, ual1, ual2)
    piv = pivot_rig(arm)
    stage(res=480, samples=20)
    rest(arm)
    # (under the pivot the world is in the character's own units; faced
    # front while measuring, so the points' places are the front view's)
    piv.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    covered0, _ = poke(mesh, None)
    co0 = zones(mesh)[0]
    with open(files[1]) as fh:
        joints = json.load(fh)
    stats = {"covered_body": int(len(covered0["body"])), "covered_shorts": int(len(covered0["shorts"])),
             "tail_bones": tail_bones(arm)}
    only = os.environ.get("GB_TESTS")
    for name in TESTS:
        if only and name not in only.split(","):
            continue
        if name == "tail_swing" and not tail_bones(arm):
            continue
        piv.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
        pose(arm, acts, name)
        if name == "bind":
            res = {"body": np.array([], dtype=int), "shorts": np.array([], dtype=int), "area": np.zeros(len(co0))}
        else:
            res, co = poke(mesh, covered0)
        sm = summary(res, co0, joints)
        stats[name] = {"body_through": sm["body"]["points"], "shorts_through": sm["shorts"]["points"],
                       "where": {r: v["points"] for r, v in sm["where"].items()}, "measured": sm}
        mk = None
        if name != "bind" and (len(res["body"]) or len(res["shorts"])):
            pts = np.concatenate([res["co"][res["body"]], res["co"][res["shorts"]]])
            mk = markers(pts[:: max(1, len(pts) // 400)])
            mk.parent = piv
            # markers are in world space already; keep them so under the turning pivot
            mk.matrix_parent_inverse = piv.matrix_world.inverted()
        for v in SHOTS.get(name, ("front", "three")):
            shoot(os.path.join(out, "%s_pose_%s_%s.png" % (animal, name, v)), piv, v)
        # close views of the worst places (most points), markers on
        piv.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
        worst = sorted(sm["where"].items(), key=lambda kv: -kv[1]["points"])[:2]
        stats[name]["close"] = []
        for r, v in worst:
            fn = "%s_close_%s_%s.png" % (animal, name, r.replace("/", "-").replace(" ", "-"))
            d = Vector(v.get("facing") or look_from(r, v["centre"]))
            if d.length < 0.3:
                d = Vector(look_from(r, v["centre"]))
            d = d.normalized() + Vector((0.0, 0.0, 0.25))
            close(os.path.join(out, fn), v["centre"], d)
            stats[name]["close"].append({"region": r, "file": fn})
        if name in ("crouch", "squat"):
            # the crotch, whatever came through: where it bends most
            th = joints["thigh"]
            near = np.where((np.abs(co0[:, 0]) < th[0] * 0.3) & (co0[:, 2] > th[2] - 0.06) & (co0[:, 2] < th[2]))[0]
            if len(near):
                c = res["co"][near].mean(axis=0)
                for tag, d in (("front", (0.0, -1.0, -0.2)), ("low", (0.0, -0.45, -1.0))):
                    fn = "%s_close_%s_crotch-%s.png" % (animal, name, tag)
                    close(os.path.join(out, fn), c, d, scale=0.40)
                    stats[name]["close"].append({"region": "crotch (" + tag + ")", "file": fn})
        if mk is not None:
            bpy.data.objects.remove(mk, do_unlink=True)
    with open(os.path.join(out, "%s_poses.json" % animal), "w") as fh:
        json.dump(stats, fh, indent=1)
    print(animal, json.dumps({k: (v["body_through"], v["shorts_through"]) if isinstance(v, dict) else v
                              for k, v in stats.items()}))


# Display poses: a UAL clip and where in it (a share of its length) for
# each, whether its feet are drawn
# in (owl_character.close_stance) and small adjustments (world-axis turns):
# the owl calm with its arms folded, the dog talking with its head
# cocked, the cat standing at ease (both feet down, arms loose - user
# request: its mid-step walk is an animation frame, not its picture),
# the bear standing as the clip has it - feet wide, heavy. ("anim_still"
# below: a frame of a clip, apart from these.)
DISPLAY = {
    "owl": ("Idle_FoldArms_Loop", 0.5, True, [("Head", "Z", -14), ("Head", "X", 6)]),
    "dog": ("Idle_Talking_Loop", 0.5, True, [("Head", "Z", 10), ("Head", "Y", -8)]),
    "cat": ("Idle_Loop", 0.5, True, [("Head", "X", -4), ("Head", "Z", 8)]),
    "bear": ("Idle_Loop", 0.5, False, [("Head", "X", -4)]),
}


ANIM_STILLS = {"cat": ("Walk_Formal_Loop", 0.35, False, [("Head", "X", -6)])}


def display(animal, gb_dir, out, ual1, ual2, clip_name=None, frame=None, tag="display"):
    arm, acts, mesh, files = bound(animal, gb_dir, ual1, ual2)
    name, f, draw_in, tweaks = (ANIM_STILLS if tag == "anim_still" else DISPLAY)[animal]
    name = clip_name or name
    f = frame if frame is not None else f
    act = acts[name]
    if draw_in:
        oc.close_stance(arm, "ual", [act], standing=[act], character=animal, files=files)
    f0, f1 = act.frame_range
    clip(arm, act, int(round(f0 + (f1 - f0) * f)) if f < 1.0 else int(f))
    for bone, axis, deg in tweaks:
        turn(arm, bone, axis, deg)
    piv = pivot_rig(arm)
    stage()
    for v in VIEWS:
        shoot(os.path.join(out, "%s_%s_%s.png" % (animal, tag, v)), piv, v)
    stage(transparent=True, ground=False)
    override([mesh], silhouette_material())
    for v in ("front", "three"):
        shoot(os.path.join(out, "%s_%s_sil_%s.png" % (animal, tag, v)), piv, v)


# ---------------------------------------------------------------- clips

# The clips played through, on each skeleton (UAL: the library's; Mixamo:
# the ones the game's player sheets are made from - render_player.py -
# plus its walk, which the game doesn't use).
UAL_CLIPS = [("idle", "Idle_Loop"), ("walk", "Walk_Loop"), ("run", "Jog_Fwd_Loop")]
MIXAMO_CLIPS = ["idle", "walk", "run", "cast", "fish_idle"]
STEPS = int(os.environ.get("GB_STEPS", 12))
# The tail's swing in the clips (none of them key a tail): a sway, a
# control of our own, so many degrees each way at the root bone.
SWAY = 14.0


def sway(arm, phase):
    for i, b in enumerate(tail_bones(arm)):
        arm.pose.bones[b].matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for i, b in enumerate(tail_bones(arm)):
        turn(arm, b, "Z", SWAY * math.sin(phase * math.tau - i * 0.6) * (0.6 + 0.15 * i))


def play(arm, mesh, piv, act, covered0, co0, joints, out, tag, f0=None, f1=None, still=None):
    """`act` gone through in STEPS frames: each measured (what came through
    the clothes) and drawn small from 3/4 with its markers; returns the
    frames' numbers and the pictures."""
    a0, a1 = act.frame_range
    f0 = a0 if f0 is None else f0
    f1 = a1 if f1 is None else f1
    rows, pics = [], []
    for i in range(STEPS):
        f = f0 + (f1 - f0) * i / STEPS
        piv.rotation_euler = (0, 0, 0)
        ad = arm.animation_data
        ad.action = act
        bpy.context.scene.frame_set(int(f), subframe=f - int(f))
        if still is not None:
            still(arm)
        if tail_bones(arm):
            sway(arm, i / STEPS)
        bpy.context.view_layer.update()
        res, co = poke(mesh, covered0)
        sm = summary(res, co0, joints)
        rows.append({"frame": round(f, 1), "body": sm["body"], "shorts": sm["shorts"],
                     "where": {r: v["points"] for r, v in sm["where"].items()}})
        mk = None
        pts = np.concatenate([res["co"][res["body"]], res["co"][res["shorts"]]])
        if len(pts):
            mk = markers(pts[:: max(1, len(pts) // 300)], r=0.008)
            mk.parent = piv
            mk.matrix_parent_inverse = piv.matrix_world.inverted()
        pics.append(shoot(os.path.join(out, "%s_%02d.png" % (tag, i)), piv, "three"))
        if mk is not None:
            bpy.data.objects.remove(mk, do_unlink=True)
    return rows, pics


def strip(pics, path, gif=None):
    from PIL import Image
    ims = [Image.open(p).convert("RGB") for p in pics]
    w, h = ims[0].size
    cols = 6
    W = Image.new("RGB", (w * cols, h * ((len(ims) + cols - 1) // cols)))
    for i, im in enumerate(ims):
        W.paste(im, ((i % cols) * w, (i // cols) * h))
    W.save(path)
    if gif:
        ims[0].save(gif, save_all=True, append_images=ims[1:], duration=110, loop=0)
    for p in pics:
        os.remove(p)


def anim(animal, gb_dir, out, ual1, ual2, mixamo):
    """The clips, on both skeletons, frame by frame (UAL's with the greybox
    as bound for the tests; Mixamo's as render_player.py makes the game's
    sheets - its feet drawn in by close_stance)."""
    report = {"ual": {}, "mixamo": {}, "sway_deg": SWAY}
    files = (os.path.join(gb_dir, animal + "_greybox.glb"), os.path.join(gb_dir, animal + "_greybox.json"))
    with open(files[1]) as fh:
        joints = json.load(fh)
    # UAL
    arm, acts, mesh, _ = bound(animal, gb_dir, ual1, ual2)
    piv = pivot_rig(arm)
    stage(res=300, samples=10, frame=1.25, look_z=0.6)
    rest(arm)
    piv.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    covered0, _ = poke(mesh, None)
    co0 = zones(mesh)[0]
    for key, name in UAL_CLIPS:
        if name not in acts:
            report["ual"][key] = {"clip": name, "missing": True}
            continue
        rows, pics = play(arm, mesh, piv, acts[name], covered0, co0, joints, out, "%s_ual_%s" % (animal, key))
        strip(pics, os.path.join(out, "%s_anim_ual_%s.png" % (animal, key)),
              os.path.join(out, "%s_anim_ual_%s.gif" % (animal, key)))
        report["ual"][key] = {"clip": name, "frames": rows}
    report["ual"]["cast"] = {"clip": None, "missing": True, "note": "UAL has no fishing cast"}
    # Mixamo, as the game's sheets
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import render_player as rp
    arm, _, src = rp.load(mixamo)
    objs, a2 = rp.import_fbx(os.path.join(mixamo, "Y_Bot@walking.fbx"))
    src["walk"] = a2[0]
    src["walk"].use_fake_user = True
    rp.in_place(src["walk"])
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    hips = (arm.matrix_world @ arm.data.bones["mixamorig:Hips"].head_local).z
    SCALE["k"] = oc._scale(hips, joints)
    mesh = oc.bind(arm, "mixamo", animal, files=files)[0]
    oc.close_stance(arm, "mixamo", list(src.values()), standing=[src["idle"]], character=animal, files=files)
    piv = pivot_all([arm])
    piv.scale = (1.0 / SCALE["k"],) * 3
    stage(res=300, samples=10, frame=1.25, look_z=0.6)
    ad = arm.animation_data or arm.animation_data_create()
    for t in ad.nla_tracks:
        t.mute = True
    ad.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    piv.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    covered0, _ = poke(mesh, None)
    co0 = zones(mesh)[0]
    for key in MIXAMO_CLIPS:
        act = src[key]
        rows, pics = play(arm, mesh, piv, act, covered0, co0, joints, out, "%s_mx_%s" % (animal, key))
        strip(pics, os.path.join(out, "%s_anim_mixamo_%s.png" % (animal, key)),
              os.path.join(out, "%s_anim_mixamo_%s.gif" % (animal, key)))
        report["mixamo"][key] = {"clip": act.name, "frames": rows, "in_game": key != "walk"}
    with open(os.path.join(out, "%s_anim.json" % animal), "w") as fh:
        json.dump(report, fh, indent=1)
    for rig in ("ual", "mixamo"):
        for key, v in report[rig].items():
            if isinstance(v, dict) and "frames" in v:
                print(animal, rig, key, "max points", max(r["body"]["points"] for r in v["frames"]),
                      "max depth", max(r["body"]["depth_max_mm"] for r in v["frames"]))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    cmd = args[0]
    if cmd == "lineup":
        # lineup OUT label=path label=path ...
        lineup([tuple(a.split("=", 1)) for a in args[2:]], os.path.abspath(args[1]))
    if cmd == "views":
        os.makedirs(args[3], exist_ok=True)
        views(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]))
    elif cmd == "original":
        os.makedirs(args[2], exist_ok=True)
        original(args[1], os.path.abspath(args[2]))
    elif cmd == "poses":
        os.makedirs(args[3], exist_ok=True)
        poses(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5])
    elif cmd == "detail":
        os.makedirs(args[3], exist_ok=True)
        detail(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4] if len(args) > 4 else "new")
    elif cmd == "anim":
        os.makedirs(args[3], exist_ok=True)
        anim(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5], args[6])
    elif cmd == "display":
        os.makedirs(args[3], exist_ok=True)
        extra = args[6:]
        if extra and extra[0] == "--still":
            display(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5], tag="anim_still")
        else:
            display(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5],
                    extra[0] if extra else None, int(extra[1]) if len(extra) > 1 else None)
    sys.stdout.flush()
    os._exit(0)
