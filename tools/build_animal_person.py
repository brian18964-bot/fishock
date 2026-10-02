"""Beginner animal people beyond the owl (user request: a dog, a cat and
a bear from the user's models - not all the same size, arms and legs:
the cat smaller, the bear stout with short limbs), built the way the owl
is (build_finch_bird_head.py, whose parts this uses): the finch in the
beginner's clothes, its body reshaped for the animal, the animal's own
head on it (cut from its model, turned to face ahead), a collar of the
animal's fur over the jumper's neck, the sleeves rolled, the forearms
and shins in its fur, the hands and feet made paws.

  bpyenv/bin/python tools/build_animal_person.py -- ANIMAL FINCH.blend SRC_DIR OUT.blend [PREVIEW_PREFIX]

ANIMAL: dog, cat or bear. SRC_DIR holds the models as the user sent
them: dog_fur4.blend + dog_tex/dog_tex.png (the sheltie), cat+model.obj
+ cat_tex/cat texures/Untitled.001.png (the black cat; its hair cards
are left out), oso_adulto_realista__0117001935_texture.blend (the bear; its packed
picture saved beside it as bear_tex.png, for its fur).
The models stay out of the repo.
"""
import math
import os
import sys

import bpy
import bmesh  # noqa: E402 (after bpy, which provides it)
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_finch_bird_head as bh  # noqa: E402

# The finch's own frame (its file's units): the shoulder joints this far
# out, the arm's line from there (height) to the wrist, the hips' height,
# the legs' line, the palm's end (where the fingers start).
SHOULDER_X = 0.166
ARM_Z = (0.858, 0.759)
ARM_LEN = 0.318
ARM_Y = 0.035
PALM_END = 0.425
HIP_Z = 0.56
LEG_X = 0.09
LEG_Y = 0.01
ANKLE = (0.101, 0.026)

ANIMALS = {
    "dog": {
        "source": "dog_fur4.blend", "objects": ["dog", "eyes"],
        "images": {"dog_tex": "dog_tex/dog_tex.png"},
        # Its face looks +x in its file: turned to look -y.
        "turn": -90.0,
        # The head (its file's units): kept inside this ellipsoid.
        "keep": ((0.302, 0.005, 0.532), (0.092, 0.08, 0.1)),
        # Its neck (from under the skull, this way) bent to hang straight
        # down from the skull, and this much of it (radius, length) kept.
        "neck": ((0.262, 0.005, 0.47), (-0.45, 0.0, -0.89), 0.07, 0.12),
        # The rounded back of the head behind the cut (as the owl's:
        # half sizes as shares of the head's width / height, how far
        # behind, where its front is in the head's depth, its middle's
        # height).
        "crown": ((0.36, 0.3), 0.02, 0.62, 0.6),
        "width": 0.23,
        # Size against the owl's, then the body: girth, arms' length and
        # thickness, legs' length and thickness, fingers, toes.
        "size": 1.0, "girth": 1.0, "arm": 1.0, "arm_thick": 1.08, "leg": 1.04, "leg_thick": 1.0,
        "fingers": 0.72, "toes": 0.5,
        "fur": ("dog_tex/dog_tex.png", (432, 736, 560, 864)), "fur_scale": 9.0,
        "pads": (0.16, 0.12, 0.1), "shin": (0.03, 0.038),
    },
    "cat": {
        "source": "cat+model.obj", "objects": ["Cube_Cube.001", "Sphere", "Mesh"],
        "images": {"*": "cat_tex/cat texures/Untitled.001.png"},
        "turn": 180.0,
        "keep": ((0.0, 2.37, 1.12), (0.58, 0.62, 0.66)),
        # (plane point, normal toward what goes)
        "cuts": [((0.0, 2.0, 1.1), (0.0, -1.0, 0.0)), ((0.0, 2.3, 0.62), (0.0, 0.0, -1.0))],
        "crown": ((0.43, 0.38), 0.035, 0.55, 0.55),
        "width": 0.27,
        "size": 0.84, "girth": 0.9, "arm": 0.95, "arm_thick": 0.92, "leg": 0.95, "leg_thick": 0.92,
        "fingers": 0.7, "toes": 0.48,
        "fur": ("cat_tex/cat texures/Untitled.001.png", (1712, 512, 1840, 640)), "fur_scale": 12.0, "fur_colour": (0.085, 0.075, 0.07),
         "pads": (0.05, 0.045, 0.045), "shin": (0.026, 0.033),
    },
    "bear": {
        "source": "oso_adulto_realista__0117001935_texture.blend", "objects": ["Mesh_0"],
        "images": {},
        "turn": 0.0,
        "keep": ((0.0, -0.58, 0.68), (0.33, 0.36, 0.3)),
        "cuts": [((0.0, -0.36, 0.7), (0.0, 1.0, 0.0)), ((0.0, -0.6, 0.42), (0.0, 0.0, -1.0))],
        # Its roaring mouth closed: the lower jaw (below the line from
        # (y, z) to (y, z)) turned up about its hinge (y, z) this far.
        "jaw": ((-0.9, 0.545), (-0.55, 0.58), (-0.5, 0.6), -37.0),
        "crown": ((0.42, 0.38), 0.025, 0.66, 0.58),
        "width": 0.29,
        "size": 1.1, "girth": 1.32, "arm": 0.8, "arm_thick": 1.4, "leg": 0.78, "leg_thick": 1.3,
        "fingers": 0.6, "toes": 0.55,
        "fur": ("bear_tex.png", (112, 1760, 272, 1920)), "fur_scale": 8.0, "fur_colour": (0.66, 0.56, 0.44),
         "pads": (0.09, 0.07, 0.06), "shin": (0.046, 0.056),
    },
}


def _smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


class Reshape:
    """The finch's body made the animal's: arms (and fingers) shorter or
    longer and thicker or thinner along their own line, the trunk wider,
    the legs shorter (the body coming down to them) and thicker, the toes
    drawn in to a paw."""

    def __init__(self, cfg):
        self.c = cfg

    def __call__(self, p):
        c = self.c
        x, y, z = p
        s = 1.0 if x >= 0 else -1.0
        ax = abs(x)
        # The arm: along its line from the shoulder.
        w = _smooth(SHOULDER_X - 0.02, SHOULDER_X + 0.04, ax)
        u = ax - SHOULDER_X
        if w > 0.0 and u > 0.0:
            uf = u if ax < PALM_END else (PALM_END - SHOULDER_X) + (ax - PALM_END) * c["fingers"]
            slope = (ARM_Z[1] - ARM_Z[0]) / ARM_LEN
            zl = ARM_Z[0] + slope * u
            dy, dz = y - ARM_Y, z - zl
            u2 = uf * c["arm"]
            t = c["arm_thick"]
            ax_arm = SHOULDER_X + u2
            y_arm = ARM_Y + dy * t
            z_arm = ARM_Z[0] + slope * u2 + dz * t
            ax = ax + (ax_arm - ax) * w
            y = y + (y_arm - y) * w
            z = z + (z_arm - z) * w
        # The trunk wider (the arms carried out with the shoulders).
        g = c["girth"]
        if abs(x) <= SHOULDER_X:
            ax = ax * g
        else:
            ax = ax + SHOULDER_X * (g - 1.0)
        y = y * (1.0 + (g - 1.0) * 0.8)
        # The legs: thicker about their own line, shorter (all above them
        # coming down), the toes drawn in.
        wl = _smooth(HIP_Z, HIP_Z - 0.08, z)
        if wl > 0.0:
            cx = LEG_X * g
            t = c["leg_thick"]
            ax = ax + ((cx + (ax - cx) * t) - ax) * wl
            y = y + ((LEG_Y + (y - LEG_Y) * t) - y) * wl
        if z < 0.035:
            ankle_x, ankle_y = ANKLE[0] * g, ANKLE[1]
            dx, dy = ax - ankle_x, y - ankle_y
            reach = math.hypot(dx, dy)
            if reach > 0.012:
                k = (0.012 + (reach - 0.012) * c["toes"]) / reach
                ax, y = ankle_x + dx * k, ankle_y + dy * k
        if z < HIP_Z:
            z = z * c["leg"]
        else:
            z = z - HIP_Z * (1.0 - c["leg"])
        return Vector((s * ax, y, z))


def reshape_body(fix, arm, parts):
    for o in parts:
        mw = o.matrix_world
        inv = mw.inverted()
        for v in o.data.vertices:
            v.co = inv @ fix(mw @ v.co)
        o.data.update()
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    mw = arm.matrix_world
    inv = mw.inverted()
    for b in arm.data.edit_bones:
        b.use_connect = False
    for b in arm.data.edit_bones:
        h, t = fix(mw @ b.head), fix(mw @ b.tail)
        b.head, b.tail = inv @ h, inv @ t
    bpy.ops.object.mode_set(mode="OBJECT")


def bend_neck(me, pivot, way, _r, _length, over=None):
    """The neck - everything past the skull's base `pivot` along `way` -
    turned about the pivot to hang straight down, gradually over its
    first stretch (so the head stays as it was)."""
    p = Vector(pivot)
    d = Vector(way).normalized()
    down = Vector((0.0, 0.0, -1.0))
    angle = d.angle(down)
    axis = d.cross(down)
    if axis.length < 1e-6:
        return
    axis.normalize()
    over = over or 0.35 * _length
    for v in me.vertices:
        s = (v.co - p).dot(d)
        if s <= 0.0:
            continue
        w = _smooth(0.0, over, s)
        v.co = p + Matrix.Rotation(angle * w, 3, axis) @ (v.co - p)


def close_jaw(me, a, b, hinge, degrees):
    """The lower jaw (below the line a-b in the y-z plane, in front of the
    hinge) turned up about the hinge."""
    hy, hz = hinge
    for v in me.vertices:
        y, z = v.co.y, v.co.z
        if y > hy:
            continue
        t = min(max((y - a[0]) / (b[0] - a[0]), 0.0), 1.0)
        if z > a[1] + (b[1] - a[1]) * t:
            continue
        w = _smooth(hy, hy - 0.08, y)
        ang = math.radians(degrees) * w
        dy, dz = y - hy, z - hz
        v.co.y = hy + dy * math.cos(ang) - dz * math.sin(ang)
        v.co.z = hz + dy * math.sin(ang) + dz * math.cos(ang)


def load_head(cfg, src_dir):
    """The animal's head, one mesh, in the finch's frame's axes: kept
    inside cfg's ellipsoid (its neck, if it has one, bent to hang down and
    a stub of it kept), turned to face -y. The cut is left open: a
    rounded back of the head (crown) and the fur collar close it."""
    path = os.path.join(src_dir, cfg["source"])
    before = set(bpy.data.objects)
    if path.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        with bpy.data.libraries.load(path) as (data_from, data_to):
            data_to.objects = [n for n in data_from.objects if n in cfg["objects"]]
        for o in data_to.objects:
            bpy.context.scene.collection.objects.link(o)
    new = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
    keep = [o for o in new if o.name in cfg["objects"]]
    for o in new:
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for name, rel in cfg["images"].items():
        img = bpy.data.images.load(os.path.join(src_dir, rel), check_existing=True)
        for o in keep:
            for m in o.data.materials:
                if m is None or not m.use_nodes:
                    continue
                b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image is not None and (name == "*" or n.image.name.startswith(name)):
                        n.image = img
                if name == "*" and b is not None and not b.inputs["Base Color"].is_linked:
                    t = m.node_tree.nodes.new("ShaderNodeTexImage")
                    t.image = img
                    m.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
    centre, radii = Vector(cfg["keep"][0]), Vector(cfg["keep"][1])
    neck = cfg.get("neck")
    jaw = cfg.get("jaw")
    meshes = []
    lows = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in keep:
        for md in list(o.modifiers):
            if md.type == "PARTICLE_SYSTEM":
                o.modifiers.remove(md)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        me.transform(o.matrix_world)
        if neck is not None:
            bend_neck(me, *neck)
        if jaw is not None:
            close_jaw(me, *jaw)
        bm = bmesh.new()
        bm.from_mesh(me)
        # A clean cut across the back (the rounded back of the head
        # covers behind it): everything past the plane goes.
        for co, no in cfg.get("cuts", ()):
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no), clear_outer=True)

        def inside(co):
            if sum(((co[i] - centre[i]) / radii[i]) ** 2 for i in range(3)) <= 1.0:
                return True
            if neck is None:
                return False
            p, _d, r, length = neck
            return (Vector((co.x - p[0], co.y - p[1])).length <= r and p[2] - length <= co.z <= p[2])
        gone = [v for v in bm.verts if not inside(v.co)]
        for v in bm.verts:
            if sum(((v.co[i] - centre[i]) / radii[i]) ** 2 for i in range(3)) <= 1.0:
                lows.append(v.co.z)
        bmesh.ops.delete(bm, geom=gone, context="VERTS")
        if len(bm.verts) == 0:
            bm.free()
            continue
        bm.to_mesh(me)
        bm.free()
        part = bpy.data.objects.new("part", me)
        bpy.context.scene.collection.objects.link(part)
        meshes.append(part)
    for o in keep:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    head = meshes[0]
    head.name = "animal_head"
    head.data.transform(Matrix.Rotation(math.radians(cfg["turn"]), 4, "Z"))
    head.data.update()
    # One map name for all (the joined parts' maps differ in name).
    if len(head.data.uv_layers) > 1:
        for name in [l.name for l in head.data.uv_layers][1:]:
            head.data.uv_layers.remove(head.data.uv_layers[name])
    # Where the head itself (not its neck) ends below.
    head["chin"] = min(lows)
    return head


def edge_colour(head):
    """The head's own average colour along its cut (what the back of the
    head and the collar should carry on): its picture sampled at the
    open edges' corners."""
    me = head.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.active
    edge = {v for e in bm.edges if e.is_boundary for v in e.verts}
    pixels = {}
    got = []
    for f in bm.faces:
        m = me.materials[f.material_index] if f.material_index < len(me.materials) else None
        img = None
        if m is not None and m.use_nodes:
            img = next((n.image for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image is not None), None)
        if img is None or img.size[0] == 0:
            continue
        if img.name not in pixels:
            w, h = img.size
            a = np.empty(w * h * 4, np.float32)
            img.pixels.foreach_get(a)
            pixels[img.name] = a.reshape(h, w, 4)
        a = pixels[img.name]
        h, w = a.shape[:2]
        for loop in f.loops:
            if loop.vert in edge:
                u, v = loop[uv].uv
                got.append(a[int((v % 1.0) * (h - 1)), int((u % 1.0) * (w - 1)), :3])
    bm.free()
    if not got:
        return None
    # (8-bit pictures read back as stored - sRGB, as PIL has them)
    return np.median(np.array(got), axis=0)


def place(head, arm):
    """Like the owl's (build_finch_bird_head.place): as wide as WIDTH, over
    the head bone, a touch forward - its chin (not the neck under it) at
    BOTTOM."""
    pts = [Vector(v.co) for v in head.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    k = bh.WIDTH / (hi.x - lo.x)
    at = arm.matrix_world @ arm.data.bones["DEF_head"].head_local
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, head["chin"]))
    for v in head.data.vertices:
        v.co = (Vector(v.co) - centre) * k + Vector((at.x, at.y + bh.FORWARD, bh.BOTTOM))
    head.matrix_world = Matrix.Identity(4)
    head.data.update()
    return Vector((at.x, at.y))


def head_shots(prefix):
    """Close-ups of the head from the front, three-quarter, side and back
    (the finch file's own face cameras are set for its height)."""
    sc = bpy.context.scene
    head = bpy.data.objects["animal_head"]
    pts = [head.matrix_world @ v.co for v in head.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2
    c.z -= 0.03
    for name, deg in (("hface", 0), ("hthree", 40), ("hside", 90), ("hback", 160)):
        a = math.radians(deg)
        cd = bpy.data.cameras.new(name)
        cd.lens = 85
        cam = bpy.data.objects.new(name, cd)
        sc.collection.objects.link(cam)
        cam.location = c + Vector((math.sin(a), -math.cos(a), 0.12)) * 1.0
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.camera = cam
        sc.render.resolution_x = sc.render.resolution_y = 500
        sc.render.filepath = "%s_%s.png" % (prefix, name)
        bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    animal, finch, src_dir, out = args[0], *[os.path.abspath(a) for a in args[1:4]]
    preview = args[4] if len(args) > 4 else ""
    cfg = ANIMALS[animal]
    bpy.ops.wm.open_mainfile(filepath=finch)
    for name in bh.OFF:
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    jumper = bpy.data.objects["finch_jumper"]
    hand = bpy.data.objects["finch_hand"]
    feet = bpy.data.objects["finch_feet"]
    body = [jumper, bpy.data.objects["finch_trousers"], hand, feet, bpy.data.objects["finch_button_trousers_1"]]
    fix = Reshape(cfg)
    reshape_body(fix, arm, body)
    down = HIP_Z * (1.0 - cfg["leg"])
    # The owl's measures, moved with the body.
    bh.WIDTH = cfg["width"]
    bh.BOTTOM = bh.BOTTOM - down
    bh.SLEEVE_END = fix(Vector((0.37, ARM_Y, ARM_Z[0] + (ARM_Z[1] - ARM_Z[0]) * (0.37 - SHOULDER_X) / ARM_LEN))).x
    bh.CUFF = 0.028 * cfg["arm_thick"]
    bh.CUFF_OUT = 0.009 * cfg["arm_thick"]
    bh.ANKLE = 0.05 * cfg["leg"]
    bh.HEM = 0.36 * cfg["leg"]
    bh.LEG_TIER = 0.045 * cfg["leg"]
    bh.SHIN = cfg["shin"]
    bh.TIER_FLARE = 0.05
    bh.FLUFF = 0.08
    bh.ARM_TIERS = 2
    head = load_head(cfg, src_dir)
    # The fur carried on from the head's own colour where it's cut (or as
    # given, where the cut runs through shadow or the mouth).
    match = cfg.get("fur_colour")
    if match is None:
        match = edge_colour(head)
    fur = bh.patch(os.path.join(src_dir, cfg["fur"][0]), cfg["fur"][1], animal + "_fur", match=match)
    coat = bh.feathers(animal + "_coat", fur, cfg["fur_scale"])
    axis = place(head, arm)
    bh.CROWN, bh.CROWN_BACK, bh.CROWN_FRONT, bh.CROWN_MID = cfg["crown"]
    bh.crown(head, coat)
    bh.roll_sleeves(jumper)
    ruff, height, centre = bh.ruff(head, jumper, axis, coat)
    ruff.name = "animal_ruff"
    bh.tuck(head, height, centre)
    bh.rig(head, arm, "DEF_head")
    bh.rig(ruff, arm, "DEF_head")
    hand_skin = bh.source_image(hand)
    feet_skin = bh.source_image(feet)
    bh.forearms(hand, arm)
    bh.feathered_shins(feet)
    wrist_x = (arm.matrix_world @ arm.data.bones["DEF_hand_L"].head_local).x
    palm_x = fix(Vector((PALM_END + 0.02, ARM_Y, ARM_Z[1]))).x
    bh.dress(hand, bh.feathers(animal + "_paws", fur, cfg["fur_scale"],
                               under=[hand_skin, ("X", palm_x - 0.01, palm_x + 0.015), cfg["pads"]]))
    bh.dress(feet, bh.feathers(animal + "_feet", fur, cfg["fur_scale"],
                               under=[feet_skin, ("Z", 0.03 * cfg["leg"] + 0.006, 0.012), cfg["pads"]]))
    del wrist_x
    sc = bpy.context.scene
    sc["animal"] = animal
    sc["animal_size"] = cfg["size"]
    sc["animal_girth"] = cfg["girth"]
    bpy.ops.wm.save_as_mainfile(filepath=out, copy=True)
    if preview:
        bh.previews(preview)
        head_shots(preview)


if __name__ == "__main__":
    main()
