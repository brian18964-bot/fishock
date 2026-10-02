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
TESTS = ["bind", "arms_down", "arms_up", "arms_forward", "crouch", "head_turn"]


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
    return {"body": ob, "shorts": os_, "co": co}, co


def regions(co0, idx, joints):
    """Where on the body (by its bind-pose place) the points that came
    through are: counts per region."""
    out = {}
    if not len(idx):
        return out
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
        elif z > kn[2] - 0.03:
            r = "thigh/cuff"
        else:
            r = "lower leg"
        out[r] = out.get(r, 0) + 1
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


def poses(animal, gb_dir, out, ual1, ual2):
    arm, acts, mesh, files = bound(animal, gb_dir, ual1, ual2)
    piv = pivot_rig(arm)
    stage(res=480, samples=20)
    rest(arm)
    # (under the pivot the world is in the character's own units)
    covered0, _ = poke(mesh, None)
    co0 = zones(mesh)[0]
    with open(files[1]) as fh:
        joints = json.load(fh)
    stats = {"covered_body": int(len(covered0["body"])), "covered_shorts": int(len(covered0["shorts"]))}
    for name in TESTS:
        pose(arm, acts, name)
        res, co = poke(mesh, covered0) if name != "bind" else ({"body": [], "shorts": []}, None)
        stats[name] = {"body_through": int(len(res["body"])), "shorts_through": int(len(res["shorts"])),
                       "where": regions(co0, res["body"], joints)}
        mk = None
        if name != "bind" and (len(res["body"]) or len(res["shorts"])):
            pts = np.concatenate([res["co"][res["body"]], res["co"][res["shorts"]]]) if len(res["shorts"]) else \
                res["co"][res["body"]]
            mk = markers(pts[:: max(1, len(pts) // 400)])
            mk.parent = piv
            # markers are in world space already; keep them so under the turning pivot
            mk.matrix_parent_inverse = piv.matrix_world.inverted()
        for v in ("front", "three"):
            shoot(os.path.join(out, "%s_pose_%s_%s.png" % (animal, name, v)), piv, v)
        if mk is not None:
            bpy.data.objects.remove(mk, do_unlink=True)
    with open(os.path.join(out, "%s_poses.json" % animal), "w") as fh:
        json.dump(stats, fh, indent=1)
    print(animal, json.dumps(stats))


# Display poses: a UAL clip and where in it (a share of its length) for
# each, whether its feet are drawn
# in (owl_character.close_stance) and small adjustments (world-axis turns):
# the owl calm with its arms folded, the dog talking with its head
# cocked, the cat mid-step in the formal walk (light, its weight on the
# planted foot), the bear standing as the clip has it - feet wide, heavy.
DISPLAY = {
    "owl": ("Idle_FoldArms_Loop", 0.5, True, [("Head", "Z", -14), ("Head", "X", 6)]),
    "dog": ("Idle_Talking_Loop", 0.5, True, [("Head", "Z", 10), ("Head", "Y", -8)]),
    "cat": ("Walk_Formal_Loop", 0.35, False, [("Head", "X", -6)]),
    "bear": ("Idle_Loop", 0.5, False, [("Head", "X", -4)]),
}


def display(animal, gb_dir, out, ual1, ual2, clip_name=None, frame=None):
    arm, acts, mesh, files = bound(animal, gb_dir, ual1, ual2)
    name, f, close, tweaks = DISPLAY[animal]
    name = clip_name or name
    f = frame if frame is not None else f
    act = acts[name]
    if close:
        oc.close_stance(arm, "ual", [act], standing=[act], character=animal, files=files)
    f0, f1 = act.frame_range
    clip(arm, act, int(round(f0 + (f1 - f0) * f)) if f < 1.0 else int(f))
    for bone, axis, deg in tweaks:
        turn(arm, bone, axis, deg)
    piv = pivot_rig(arm)
    stage()
    for v in VIEWS:
        shoot(os.path.join(out, "%s_display_%s.png" % (animal, v)), piv, v)
    stage(transparent=True, ground=False)
    override([mesh], silhouette_material())
    for v in ("front", "three"):
        shoot(os.path.join(out, "%s_display_sil_%s.png" % (animal, v)), piv, v)


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
    elif cmd == "display":
        os.makedirs(args[3], exist_ok=True)
        extra = args[6:]
        display(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5],
                extra[0] if extra else None, int(extra[1]) if len(extra) > 1 else None)
    sys.stdout.flush()
    os._exit(0)
