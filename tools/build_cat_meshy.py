"""The cat person, second make (user request: the black cat the user had
generated in Meshy, "Whiskerwood Gentleman" - a sculpted, textured mesh
in the same style as the dragon: kept out of the repo, like the other
source models), rigged here onto the game's cat. Built from

  MESHY_FBX   Meshy's textured export (one mesh, ~120 000 triangles, a
              2048 colour, normal and roughness picture), its feet toward
              -z, facing -y, about 1.9 tall, standing in an A pose
  CAT_GLB     the game's cat (assets/models/characters/cat.glb): its
              skeleton - the mannequin's bones with the fingers, the ears'
              and the tail's - and all its clips

The mesh is brought down to TRIS triangles, the high one's surface baked
into a normal picture for it, sized to the old cat's height and stood on
the ground. Then, in two passes:

  1. a rough skeleton at the joints measured off this mesh (JOINTS), bound
     by bone heat, turns the arms up and the legs straight to the old cat's
     rest (a T pose) and lays the tail in its rest curve (TAIL_ANGLES, a
     question mark off the ground, clear of seats); the mesh is kept so;
  2. the old cat's skeleton is moved onto it - each bone to its joint here,
     keeping its old turn (so every clip plays as it did) - the fingers at
     the knuckles measured on the posed hands (FINGERS), the ears and the
     tail (TAIL_BONES bones; EarTailSway moves them) from pass 1 - and the
     mesh bound to it by bone heat.

  bpyenv/bin/python tools/build_cat_meshy.py MESHY_FBX CAT_GLB OUT.glb [LOW.blend]

LOW.blend (optional) keeps the brought-down, baked mesh between runs.
"""
import math
import os
import sys
import time

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
MESHY, CAT, OUT = args[:3]
LOW = args[3] if len(args) > 3 else ""
TRIS = 36000
NORMAL_SIZE = 2048
SHIP_COLOUR = 1536
SHIP_DETAIL = 1024
# Meshy's feet (its frame) and the size it is brought to: the old cat's
# height (m, ear tips).
FEET = -0.951
SCALE = 1.46 / 1.898


def _p(x, y, z):
    """A point in Meshy's frame (its right side -x), in the game's."""
    return Vector((x, y, z - FEET)) * SCALE


def _sides(name, head, tail, parent):
    out = []
    for s, k in (("l", 1.0), ("r", -1.0)):
        out.append((name.format(s=s), Vector((head.x * k, head.y, head.z)), Vector((tail.x * k, tail.y, tail.z)),
                    parent.format(s=s) if parent else None))
    return out


# The joints, measured off slices of Meshy's mesh (its frame):
# (name, head, tail, parent).
TRUNK = [
    ("pelvis", _p(0, -0.11, -0.12), _p(0, -0.11, 0.0), None),
    ("spine_01", _p(0, -0.11, 0.0), _p(0, -0.11, 0.12), "pelvis"),
    ("spine_02", _p(0, -0.11, 0.12), _p(0, -0.11, 0.26), "spine_01"),
    ("spine_03", _p(0, -0.11, 0.26), _p(0, -0.1, 0.5), "spine_02"),
    ("neck_01", _p(0, -0.1, 0.5), _p(0, -0.08, 0.6), "spine_03"),
    ("Head", _p(0, -0.08, 0.6), _p(0, -0.08, 0.85), "neck_01"),
]
LIMBS = []
for _spec in (
        ("clavicle_{s}", _p(0.03, -0.1, 0.37), _p(0.19, -0.09, 0.38), "spine_03"),
        ("upperarm_{s}", _p(0.19, -0.09, 0.38), _p(0.36, -0.08, 0.215), "clavicle_{s}"),
        ("lowerarm_{s}", _p(0.36, -0.08, 0.215), _p(0.525, -0.095, 0.05), "upperarm_{s}"),
        # (to the fingertips: turned flat with the arm)
        ("hand_{s}", _p(0.525, -0.095, 0.05), _p(0.655, -0.115, -0.17), "lowerarm_{s}"),
        ("thigh_{s}", _p(0.11, -0.11, -0.18), _p(0.195, -0.075, -0.55), "pelvis"),
        ("calf_{s}", _p(0.195, -0.075, -0.55), _p(0.235, -0.07, -0.85), "thigh_{s}"),
        ("foot_{s}", _p(0.235, -0.07, -0.85), _p(0.255, -0.24, -0.935), "calf_{s}"),
        ("ball_{s}", _p(0.255, -0.24, -0.935), _p(0.26, -0.335, -0.945), "foot_{s}"),
        ("ear_{s}1_01", _p(0.095, -0.1, 0.85), _p(0.122, -0.118, 0.9), "Head"),
        ("ear_{s}1_02", _p(0.122, -0.118, 0.9), _p(0.148, -0.135, 0.947), "ear_{s}1_01")):
    LIMBS += _sides(*_spec)
# The tail's line (its middle, every 0.05 along it from the root; Meshy's
# own swings down round the left leg and curls up at the floor).
TAIL_LINE = [(0.025, 0.115, 0.075), (0.036, 0.133, 0.056), (0.048, 0.15, 0.019), (0.067, 0.164, -0.02),
             (0.09, 0.173, -0.06), (0.111, 0.194, -0.101), (0.127, 0.21, -0.146), (0.146, 0.222, -0.191),
             (0.166, 0.232, -0.235), (0.181, 0.235, -0.282), (0.199, 0.241, -0.328), (0.219, 0.245, -0.375),
             (0.235, 0.246, -0.421), (0.257, 0.252, -0.464), (0.279, 0.253, -0.511), (0.302, 0.258, -0.554),
             (0.33, 0.26, -0.595), (0.363, 0.264, -0.635), (0.4, 0.266, -0.67), (0.442, 0.274, -0.7),
             (0.491, 0.289, -0.718), (0.544, 0.315, -0.711), (0.585, 0.336, -0.671), (0.615, 0.36, -0.62)]
TAIL_BONES = 8
# The tail at rest: each bone's angle down from straight back (deg) - out
# behind, then up, the tip curling over.
TAIL_ANGLES = (30, 15, -5, -25, -45, -60, -75, -95)
# How far from the tail's bones its skin reaches (m, the game's scale).
TAIL_REACH = 0.06
# The bones pass 1 turns to the old cat's rest (the rest stay as Meshy
# stands them).
TURNED = ("upperarm", "lowerarm", "hand", "thigh", "calf", "foot", "ball")
# Pass 2: the old skeleton's bones that keep pass 1's joints.
FROM_PASS1 = ("pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle", "upperarm",
              "lowerarm", "hand", "thigh", "calf", "foot", "ball")
# The fingers on the posed (T) hand, left side, the game's frame: each
# digit's four joints, knuckle first (the fourth the tip - the leaf bone's
# head). Measured off the posed mesh (pass 1).
FINGERS = {
    "thumb": ((0.548, -0.09, 1.01), (0.565, -0.11, 0.995), (0.585, -0.122, 0.97), (0.61, -0.13, 0.94)),
    "index": ((0.62, -0.11, 1.02), (0.65, -0.111, 1.02), (0.68, -0.114, 1.007), (0.712, -0.115, 0.995)),
    "middle": ((0.62, -0.082, 1.021), (0.65, -0.082, 1.02), (0.68, -0.079, 1.0), (0.712, -0.078, 0.98)),
    "ring": ((0.615, -0.04, 1.022), (0.643, -0.043, 1.018), (0.668, -0.041, 0.993), (0.695, -0.041, 0.98)),
    "pinky": ((0.605, -0.013, 1.02), (0.628, -0.013, 1.018), (0.65, -0.01, 1.0), (0.672, -0.008, 0.985)),
}


def select(objs, active=None):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active or objs[0]


# ---------------------------------------------------------------- the mesh

def mesh():
    """Meshy's mesh brought down to TRIS, the high one's surface baked into
    a normal picture for it, sized and stood on the ground."""
    if LOW and os.path.exists(LOW):
        with bpy.data.libraries.load(LOW) as (src, dst):
            dst.objects = ["Cat"]
        lo = dst.objects[0]
        bpy.context.scene.collection.objects.link(lo)
        print("mesh from", LOW)
        return lo
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=MESHY)
    hi = next(o for o in set(bpy.data.objects) - before if o.type == 'MESH')
    hi.name = "High"
    lo = hi.copy()
    lo.data = hi.data.copy()
    lo.name = "Cat"
    bpy.context.scene.collection.objects.link(lo)
    tris = sum(len(p.vertices) - 2 for p in hi.data.polygons)
    m = lo.modifiers.new("Less", 'DECIMATE')
    m.ratio = TRIS / tris
    m.use_collapse_triangulate = True
    select([lo])
    bpy.ops.object.modifier_apply(modifier="Less")
    mat = lo.data.materials[0].copy()
    mat.name = "Cat_Skin"
    lo.data.materials[0] = mat
    img = bpy.data.images.new("Cat_Normal", NORMAL_SIZE, NORMAL_SIZE)
    img.colorspace_settings.name = 'Non-Color'
    nt = mat.node_tree
    node = nt.nodes.new('ShaderNodeTexImage')
    node.image = img
    for n in nt.nodes:
        n.select = False
    node.select = True
    nt.nodes.active = node
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.01
    bk.max_ray_distance = 0.03
    bk.margin = 8
    select([hi, lo], active=lo)
    t = time.time()
    bpy.ops.object.bake(type='NORMAL')
    print("baked the normal picture in %.0f s" % (time.time() - t))
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    nm = next((n for n in nt.nodes if n.type == 'NORMAL_MAP'), None)
    if nm is None:
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(nm.outputs[0], bsdf.inputs['Normal'])
    for link in list(nm.inputs['Color'].links):
        nt.links.remove(link)
    nt.links.new(node.outputs['Color'], nm.inputs['Color'])
    for link in list(bsdf.inputs['Metallic'].links):
        nt.links.remove(link)
    bsdf.inputs['Metallic'].default_value = 0.0
    bpy.data.objects.remove(hi, do_unlink=True)
    for n in nt.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None and n.image is not img and n.image.size[0] > 0:
            rough = "roughness" in n.image.name
            ship = SHIP_DETAIL if rough else SHIP_COLOUR
            n.image.scale(ship, ship)
            n.image.name = "Cat_Roughness" if rough else "Cat_Colour"
            n.image.pack()
    img.scale(SHIP_DETAIL, SHIP_DETAIL)
    img.pack()
    for n in list(nt.nodes):
        if n.type == 'TEX_IMAGE' and n.image is not None and "metallic" in n.image.name:
            nt.nodes.remove(n)
    lo.location.z -= FEET
    lo.location *= SCALE
    lo.scale = (SCALE, SCALE, SCALE)
    select([lo])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print("mesh: %d triangles" % sum(len(p.vertices) - 2 for p in lo.data.polygons))
    if LOW:
        bpy.data.libraries.write(LOW, {lo}, fake_user=True, compress=True)
    return lo


# ---------------------------------------------------------------- pass 1

def tail_points():
    """TAIL_BONES + 1 points spaced evenly along TAIL_LINE (the game's
    frame)."""
    pts = [_p(*c) for c in TAIL_LINE]
    run = [0.0]
    for a, b in zip(pts, pts[1:]):
        run.append(run[-1] + (b - a).length)
    out = []
    for i in range(TAIL_BONES + 1):
        s = run[-1] * i / TAIL_BONES
        k = max(j for j in range(len(run)) if run[j] <= s + 1e-9)
        if k >= len(pts) - 1:
            out.append(pts[-1])
            continue
        t = (s - run[k]) / max(run[k + 1] - run[k], 1e-9)
        out.append(pts[k].lerp(pts[k + 1], t))
    return out


def rough_skeleton():
    data = bpy.data.armatures.new("Rough")
    arm = bpy.data.objects.new("Rough", data)
    bpy.context.scene.collection.objects.link(arm)
    select([arm])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = data.edit_bones
    specs = list(TRUNK) + list(LIMBS)
    pts = tail_points()
    for i in range(TAIL_BONES):
        specs.append(("tail_%02d" % (i + 1), pts[i], pts[i + 1], "pelvis" if i == 0 else "tail_%02d" % i))
    for name, h, t, parent in specs:
        b = eb.new(name)
        b.head, b.tail = h, t
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


def heat(body, arm):
    """Bone heat; what it leaves out (loose bits: the whiskers, the eyes)
    on its nearest bone."""
    for m in list(body.modifiers):
        if m.type == 'ARMATURE':
            body.modifiers.remove(m)
    body.vertex_groups.clear()
    select([body, arm], active=arm)
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    segs = [(b.name, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local)
            for b in arm.data.bones if b.use_deform]
    groups = {g.name: g for g in body.vertex_groups}
    loose = 0
    for v in body.data.vertices:
        if v.groups:
            continue
        p = body.matrix_world @ v.co
        best, name = 9.0, None
        for n, a, b in segs:
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
            d = (a + ab * t - p).length
            if d < best:
                best, name = d, n
        if name not in groups:
            groups[name] = body.vertex_groups.new(name=name)
        groups[name].add([v.index], 1.0, 'REPLACE')
        loose += 1
    print("bound: %d loose vertices on their nearest bone" % loose)


def tail_only(body, arm):
    """The tail's skin on the tail's bones alone: what lies nearer the
    tail's line than any other bone, within TAIL_REACH of it (Meshy's tail
    lies along the left leg)."""
    segs = [(b.name, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones
            if b.use_deform]

    def seg_dist(p, a, b):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        return (a + ab * t - p).length

    groups = {g.name: g for g in body.vertex_groups}
    index = {g.index: g.name for g in body.vertex_groups}
    moved = 0
    for v in body.data.vertices:
        p = body.matrix_world @ v.co
        best_tail, tail_bone, other = 9.0, None, 9.0
        for name, a, b in segs:
            d = seg_dist(p, a, b)
            if name.startswith("tail"):
                if d < best_tail:
                    best_tail, tail_bone = d, name
            else:
                other = min(other, d)
        if tail_bone is None or best_tail > TAIL_REACH or best_tail >= other:
            continue
        keep = {}
        for g in v.groups:
            name = index[g.group]
            if name.startswith("tail") or (name == "pelvis" and tail_bone == "tail_01"):
                keep[name] = g.weight
        if not keep:
            keep = {tail_bone: 1.0}
        for g in list(v.groups):
            if index[g.group] not in keep:
                groups[index[g.group]].remove([v.index])
        for name, w in keep.items():
            if name not in groups:
                groups[name] = body.vertex_groups.new(name=name)
            groups[name].add([v.index], w, 'REPLACE')
        moved += 1
    print("tail skin kept to the tail: %d vertices" % moved)


def turn_to(arm, pb, want):
    """Pose bone `pb` turned (about its head) so it points `want` (world)."""
    bpy.context.view_layer.update()
    now = (arm.matrix_world @ pb.matrix).to_3x3() @ Vector((0.0, 1.0, 0.0))
    turn = now.normalized().rotation_difference(want.normalized())
    world = arm.matrix_world.to_3x3()
    m = pb.matrix.copy()
    r = (world.inverted() @ turn.to_matrix() @ world).to_4x4()
    head = m.translation.copy()
    m.translation = Vector()
    m = r @ m
    m.translation = head
    pb.matrix = m


def pose_rest(body, rough, old):
    """The arms and legs turned to the old cat's rest, the tail laid in its
    curve; the mesh kept so, and the rough skeleton's rest with it."""
    select([rough])
    bpy.ops.object.mode_set(mode='POSE')
    order = [b.name for b in rough.data.bones]
    order.sort(key=lambda n: len(rough.data.bones[n].parent_recursive))
    for name in order:
        part = name.rsplit("_", 1)[0]
        pb = rough.pose.bones[name]
        if part in TURNED:
            ob = old.data.bones[name]
            want = (old.matrix_world.to_3x3() @ (ob.tail_local - ob.head_local))
            if part == "hand":
                # (the old hand bone ends at the knuckles: to the middle
                # finger's tip instead, the way the hand lies)
                tip = old.data.bones["middle_04_leaf_" + name[-1]].head_local
                want = old.matrix_world.to_3x3() @ (tip - ob.head_local)
            turn_to(rough, pb, want)
        elif name.startswith("tail_"):
            a = math.radians(TAIL_ANGLES[int(name[5:]) - 1])
            turn_to(rough, pb, Vector((0.0, math.cos(a), -math.sin(a))))
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode='OBJECT')
    mod = next(m for m in body.modifiers if m.type == 'ARMATURE')
    select([body])
    bpy.ops.object.modifier_apply(modifier=mod.name)
    select([rough])
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    tip = rough.matrix_world @ rough.data.bones["tail_%02d" % TAIL_BONES].tail_local
    low = min((rough.matrix_world @ b.tail_local).z for b in rough.data.bones if b.name.startswith("tail"))
    print("posed: tail tip at y %.2f z %.2f, its lowest %.2f above the ground" % (tip.y, tip.z, low))


# ---------------------------------------------------------------- pass 2

def old_cat():
    """The old cat: its armature (its clips on NLA tracks), its meshes gone."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=CAT)
    new = set(bpy.data.objects) - before
    arm = next(o for o in new if o.type == 'ARMATURE')
    for o in new:
        if o is not arm:
            bpy.data.objects.remove(o, do_unlink=True)
    for a in bpy.data.actions:
        if a.name.endswith("_Armature"):
            a.name = a.name[:-len("_Armature")]
    for tr in arm.animation_data.nla_tracks:
        if tr.name.endswith("_Armature"):
            tr.name = tr.name[:-len("_Armature")]
        for st in tr.strips:
            if st.name.endswith("_Armature"):
                st.name = st.name[:-len("_Armature")]
    arm.name = "Armature"
    arm.data.name = "Armature"
    return arm


def refit(old, rough):
    """The old skeleton moved onto the posed mesh: each bone at its joint,
    keeping its turn (the clips play as they did); the ears and the tail
    from pass 1."""
    inv = old.matrix_world.inverted()
    joints = {}
    for b in rough.data.bones:
        joints[b.name] = (inv @ (rough.matrix_world @ b.head_local), inv @ (rough.matrix_world @ b.tail_local))
    fingers = {}
    for digit, pts in (FINGERS or {}).items():
        for s, k in (("l", 1.0), ("r", -1.0)):
            ps = [inv @ Vector((p[0] * k, p[1], p[2])) for p in pts]
            for i in range(3):
                fingers["%s_%02d_%s" % (digit, i + 1, s)] = (ps[i], ps[i + 1])
            fingers["%s_04_leaf_%s" % (digit, s)] = (ps[3], ps[3] + (ps[3] - ps[2]) * 0.5)
    select([old])
    bpy.ops.object.mode_set(mode='EDIT')
    eb = old.data.edit_bones
    for b in list(eb):
        if b.name.startswith(("ear_", "tail_")):
            eb.remove(b)
    for b in eb:
        part = b.name.rsplit("_", 1)[0] if b.name[-2:] in ("_l", "_r") else b.name
        if part in FROM_PASS1 and b.name in joints:
            h, t = joints[b.name]
            if part == "hand" and FINGERS:
                # (to the knuckles: the fingers have their own bones)
                t = fingers["middle_01" + b.name[-2:]][0]
        elif b.name in fingers:
            h, t = fingers[b.name]
        elif b.name.startswith("ball_leaf"):
            h = joints["ball" + b.name[-2:]][1]
            t = h + (b.tail - b.head)
        else:
            continue
        roll = b.roll
        way = (b.tail - b.head).normalized()
        b.head = h
        b.tail = h + way * max((t - h).length, 0.01)
        b.roll = roll
    for name, (h, t) in joints.items():
        if name.startswith(("ear_", "tail_")):
            b = eb.new(name)
            b.head, b.tail = h, t
            parent = rough.data.bones[name].parent.name
            b.parent = eb[parent]
    for b in eb:
        b.use_deform = not (b.name == "root" or "leaf" in b.name)
    bpy.ops.object.mode_set(mode='OBJECT')
    print("skeleton: %d bones" % len(old.data.bones))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    old = old_cat()
    body = mesh()
    rough = rough_skeleton()
    heat(body, rough)
    tail_only(body, rough)
    pose_rest(body, rough, old)
    if FINGERS is None:
        # (measuring: the posed mesh, for the fingers)
        me = body.data
        co = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        np.save(OUT + ".posed.npy", co.reshape(-1, 3))
        bpy.ops.wm.save_as_mainfile(filepath=OUT + ".posed.blend")
        print("posed mesh written; FINGERS still to measure")
        return
    refit(old, rough)
    bpy.data.objects.remove(rough, do_unlink=True)
    for m in list(body.modifiers):
        body.modifiers.remove(m)
    body.parent = None
    heat(body, old)
    tail_only(body, old)
    select([body])
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    ad = old.animation_data
    ad.action = None
    for pb in old.pose.bones:
        pb.matrix_basis.identity()
    select([old, body], active=old)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_optimize_animation_size=True, export_anim_single_armature=True,
                              export_def_bones=False, export_image_format='JPEG', export_jpeg_quality=85)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
