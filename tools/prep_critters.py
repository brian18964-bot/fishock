"""The user's critter models (user request, round 8: new pictures for the
bee, the rat, the snake and the frog; the grasshopper caught on the map
too) made into rigged, animated models render_animals.py takes as it
takes the Quaternius pack's - art_src/critter/<name>.glb, clips named as
before:

  rat, frog        the user's still model on the pack's rig (the pack's
                   art_src/critter/<pack>.glb): turned and sized onto the
                   pack's mesh, its skin weights carried over from the
                   nearest of the pack's faces, the pack's mesh dropped -
                   so it runs, hops and flies as the pack's did.
  bee              the user's wasp (the 蜜蜂): its own rig, a hovering body
                   and beating wings (Wasp_Flying).
  snake            the user's snake lies in an S on the ground, weighted
                   to a chain of 20 bones it came without: the chain is
                   made through its weight groups' middles, and it
                   slithers - a wave running down the chain - or rests,
                   swaying a little (Snake_Walk, Snake_Idle).
  grasshopper      the user's grasshopper (the 蚱蜢 bait): one bone, a hop
                   (crouch, leap, land) and an idle twitch
                   (Grasshopper_Hop, Grasshopper_Idle).

  bpyenv/bin/python tools/prep_critters.py SRC_DIR [name ...]   (repo root)

SRC_DIR as laid out by hand: rat/Rat.fbx + rat/rat.png, frog.FBX,
Snake.blend, wasp/wasp.obj + wasp/<part> - Kopie/ (its textures),
Grasshopper.blend, and pack/ - the Quaternius rat, frog and wasp as they
were in art_src/critter before (their rigs). The packs stay out of the
repo.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CRITTER = os.path.join(ROOT, "art_src", "critter")


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bounds(objs):
    pts = np.array([(o.matrix_world @ v.co)[:] for o in objs for v in o.data.vertices])
    return pts.min(0), pts.max(0)


def join(objs, name):
    """One mesh of `objs` (their modifiers applied), in world space."""
    dg = bpy.context.evaluated_depsgraph_get()
    made = []
    for o in objs:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        n = bpy.data.objects.new(o.name + "_j", me)
        n.matrix_world = o.matrix_world
        bpy.context.scene.collection.objects.link(n)
        made.append(n)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    if len(made) > 1:
        bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return out


def decimate(o, tris):
    have = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if have <= tris:
        return
    d = o.modifiers.new("dec", "DECIMATE")
    d.ratio = tris / have
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="dec")


def fit(o, target, turn):
    """`o` turned `turn` degrees about z and sized/centred onto `target`'s
    bounds (by length, nose to tail along y; its feet on the target's)."""
    o.rotation_euler = (0, 0, math.radians(turn))
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = bounds([o])
    tlo, thi = bounds([target])
    k = (thi - tlo)[1] / (hi - lo)[1]
    c = (lo + hi) / 2
    tc = (tlo + thi) / 2
    for v in o.data.vertices:
        p = (Vector(v.co) - Vector((c[0], c[1], lo[2]))) * k
        v.co = p + Vector((tc[0], tc[1], tlo[2]))


def transfer_rig(name, pack_glb, mesh, turn, out_name=None):
    """The user's `mesh` onto the pack's rig (see the docstring)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=pack_glb)
    new = set(bpy.data.objects) - before
    arm = next(o for o in new if o.type == "ARMATURE")
    pack_meshes = [o for o in new if o.type == "MESH" and not o.name.startswith("Icosphere")]
    for o in [o for o in new if o.type == "MESH" and o.name.startswith("Icosphere")]:
        bpy.data.objects.remove(o, do_unlink=True)
    # The pack's mesh in its rest pose, as the weights are read from it.
    for t in arm.animation_data.nla_tracks if arm.animation_data else []:
        t.mute = True
    if arm.animation_data:
        arm.animation_data.action = None
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    src = join(pack_meshes, "pack_src") if len(pack_meshes) > 1 else pack_meshes[0]
    # (join() applies the armature modifier in rest: same as the rest shape)
    fit(mesh, src, turn)
    for g in src.vertex_groups:
        mesh.vertex_groups.new(name=g.name)
    dt = mesh.modifiers.new("dt", "DATA_TRANSFER")
    dt.object = src
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.datalayout_transfer(modifier="dt")
    bpy.ops.object.modifier_apply(modifier="dt")
    bpy.data.objects.remove(src, do_unlink=True)
    mesh.parent = arm
    mesh.matrix_parent_inverse = arm.matrix_world.inverted()
    md = mesh.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    arm.data.pose_position = "POSE"
    export(out_name or name, [arm, mesh], nla=True)


def export(name, objs, nla=True):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    os.makedirs(CRITTER, exist_ok=True)
    path = os.path.join(CRITTER, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_animation_mode="NLA_TRACKS" if nla else "ACTIONS",
                              export_image_format="JPEG", export_jpeg_quality=85)
    print(name, os.path.getsize(path) // 1024, "KB", flush=True)


def small_textures(size=512):
    for im in bpy.data.images:
        if im.size[0] > size:
            im.scale(size, size * im.size[1] // max(im.size[0], 1))


def tex_material(name, image, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(image)
    m.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    return m


# ---------------------------------------------------------------- the critters

def rat(src):
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "rat", "Rat.fbx"))
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.name == "Cube":
            bpy.data.objects.remove(o, do_unlink=True)
    o = join(meshes(), "rat")
    o.data.materials.clear()
    o.data.materials.append(tex_material("rat", os.path.join(src, "rat", "rat.png")))
    transfer_rig("rat", os.path.join(src, "pack", "rat.glb"), o, TURNS["rat"])


def frog(src):
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "frog.FBX"))
    o = join(meshes(), "frog")
    decimate(o, 3000)
    small_textures()
    transfer_rig("frog", os.path.join(src, "pack", "frog.glb"), o, TURNS["frog"])


# The bee's parts (the obj's groups) and their pictures.
BEE_PARTS = {
    "butt": "Back - Kopie/DefaultMaterial_Base_Color.png",
    "middle": "middle - Kopie/middle_DefaultMaterial_Diffuse.png",
    "head": "head - Kopie/head_DefaultMaterial_Diffuse.png",
    "eyes_big": "eyes big - Kopie/DefaultMaterial_Base_Color.png",
    "legs_front": "legs - Kopie/legs_DefaultMaterial_Diffuse.png",
    "legs_middle": "legs_middle - Kopie/legs_middle_DefaultMaterial_Diffuse.png",
    "legs_back": "legs_back - Kopie/legs_back_DefaultMaterial_Diffuse.png",
}


def bee(src):
    """The user's wasp (the player's 蜜蜂, the bee) - on a rig of its own (on
    the pack's wasp it came out twisted): a body bone bobbing as it
    hovers, and a bone for each side's wings, beating."""
    fresh()
    bpy.ops.wm.obj_import(filepath=os.path.join(src, "wasp", "wasp.obj"), use_split_groups=True)
    parts = meshes()
    wing = bpy.data.materials.new("wing")
    wing.use_nodes = True
    wb = next(n for n in wing.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    wb.inputs["Base Color"].default_value = (0.78, 0.85, 0.9, 1)
    wb.inputs["Roughness"].default_value = 0.2
    dark = bpy.data.materials.new("dark")
    dark.use_nodes = True
    next(n for n in dark.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.05, 0.04, 0.03, 1)
    mats = {}
    wings = []
    for o in parts:
        key = next((k for k in BEE_PARTS if o.name.startswith(k)), None)
        o.data.materials.clear()
        if key is not None:
            if key not in mats:
                path = os.path.join(src, "wasp", BEE_PARTS[key])
                mats[key] = tex_material("bee_" + key, path) if os.path.exists(path) else dark
            o.data.materials.append(mats[key])
        elif o.name.startswith("wings"):
            o.data.materials.append(wing)
            wings.append(o)
        else:
            o.data.materials.append(dark)
        decimate(o, max(400, int(6000 * len(o.data.polygons) / 442130)))
    wing_names = {o.name for o in wings}
    for o in parts:
        o["is_wing"] = o.name in wing_names
    o = join(parts, "bee")
    small_textures()
    # Which faces were wing (by material).
    wing_slot = [i for i, m in enumerate(o.data.materials) if m == wing]
    wing_verts = set()
    for poly in o.data.polygons:
        if poly.material_index in wing_slot:
            wing_verts.update(poly.vertices)
    # Head to -y (it faced +y), BEE_LENGTH long, feet at 0.
    lo, hi = bounds([o])
    k = BEE_LENGTH / (hi - lo)[1]
    c = (lo + hi) / 2
    for v in o.data.vertices:
        p = (Vector(v.co) - Vector((c[0], c[1], lo[2]))) * k
        v.co = Vector((-p.x, -p.y, p.z))
    lo, hi = bounds([o])
    body_z = (lo[2] + hi[2]) * 0.5
    sides = {"wing_l": [], "wing_r": []}
    for i in wing_verts:
        sides["wing_l" if o.data.vertices[i].co.x > 0 else "wing_r"].append(i)
    # A wing's hinge: its point nearest the body's middle line.
    hinges = {}
    for side, ids in sides.items():
        if ids:
            hinges[side] = min((o.data.vertices[i].co.copy() for i in ids), key=lambda q: abs(q.x))
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    body = arm_data.edit_bones.new("body")
    body.head = Vector((0, 0.6, body_z))
    body.tail = Vector((0, -0.6, body_z))
    for side, h in hinges.items():
        wb_ = arm_data.edit_bones.new(side)
        wb_.head = h
        wb_.tail = h + Vector((0.6 if side == "wing_l" else -0.6, 0, 0))
        wb_.parent = body
    bpy.ops.object.mode_set(mode="OBJECT")
    gb = o.vertex_groups.new(name="body")
    gb.add([v.index for v in o.data.vertices if v.index not in wing_verts], 1.0, "REPLACE")
    for side, ids in sides.items():
        if ids:
            o.vertex_groups.new(name=side).add(ids, 1.0, "REPLACE")
    o.parent = arm
    md = o.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"

    def fly(t, pbs):
        pbs["body"].location = Vector((0, 0, 0.12 * math.sin(t * math.tau)))
        beat = math.sin(t * math.tau * 3.0)
        for side, sign in (("wing_l", 1.0), ("wing_r", -1.0)):
            if side in pbs:
                pbs[side].rotation_quaternion = Matrix.Rotation(0.75 * beat * sign, 4, "X").to_quaternion()

    _clip(arm, "Wasp_Flying", 24, fly)
    export("wasp", [arm, o])


def _chain(points, name="Armature"):
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bones = []
    for i in range(len(points) - 1):
        b = arm_data.edit_bones.new("Bone%02d" % i)
        b.head = points[i]
        b.tail = points[i + 1]
        b.roll = 0.0
        if bones:
            b.parent = bones[-1]
            b.use_connect = True
        bones.append(b)
    names = [b.name for b in bones]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm, names


def _clip(arm, name, frames, fn):
    """An action keyed every frame 1..frames by fn(frame, pose bones)."""
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f in range(1, frames + 2):
        fn((f - 1) / frames, arm.pose.bones)
        for pb in arm.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
    return act


def bake_colour(o, size=512, lift=1.0):
    """`o`'s own look (procedural - glTF can't carry it) baked into a
    picture on fresh UVs (brightened `lift` times), its material swapped
    for one wearing it."""
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name="UV")
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    im = bpy.data.images.new(o.name + "_colour", size, size)
    for m in me.materials:
        nt = m.node_tree
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        emit = nt.nodes.new("ShaderNodeEmission")
        src = b.inputs["Base Color"]
        if src.is_linked:
            nt.links.new(src.links[0].from_socket, emit.inputs["Color"])
        else:
            emit.inputs["Color"].default_value = src.default_value
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = im
        nt.nodes.active = t
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 4
    sc.render.bake.margin = 4
    bpy.ops.object.bake(type="EMIT")
    if lift != 1.0:
        px = np.empty(size * size * 4, np.float32)
        im.pixels.foreach_get(px)
        px = px.reshape(-1, 4)
        px[:, :3] = np.clip(px[:, :3] * lift, 0.0, 1.0)
        im.pixels.foreach_set(px.ravel())
    im.pack()
    m = bpy.data.materials.new(o.name)
    m.use_nodes = True
    bb = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    t = m.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = im
    m.node_tree.links.new(t.outputs[0], bb.inputs["Base Color"])
    bb.inputs["Roughness"].default_value = 0.45
    me.materials.clear()
    me.materials.append(m)


def snake(src):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "Snake.blend"))
    # (its eyes sat away from the body in the file: left off - the head's
    # shape reads at this size)
    for o in list(bpy.data.objects):
        if o.name != "Sphere":
            bpy.data.objects.remove(o, do_unlink=True)
    body = bpy.data.objects["Sphere"]
    for m in list(body.modifiers):
        if m.type == "LATTICE":
            body.modifiers.remove(m)
    # Its weight groups' middles, in order down the body (world).
    mids = []
    for gi, g in enumerate(body.vertex_groups):
        acc = Vector()
        tot = 0.0
        for v in body.data.vertices:
            for e in v.groups:
                if e.group == gi and e.weight > 0.3:
                    acc += body.matrix_world @ v.co * e.weight
                    tot += e.weight
        if tot > 0:
            mids.append((g.name, acc / tot))
    o = join([body], "snake")
    # Its own camouflage came out near black at this size: an olive-brown
    # skin with dark blotches and a paler belly-side instead.
    m = bpy.data.materials.new("snake_skin")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9.0
    noise.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.42, (0.13, 0.11, 0.06, 1)
    els[1].position, els[1].color = 0.5, (0.47, 0.42, 0.2, 1)
    e = els.new(0.75)
    e.color = (0.62, 0.56, 0.3, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(m)
    bake_colour(o)
    # Laid flat at the origin, LENGTH long along its longest ground axis.
    lo, hi = bounds([o])
    c = (lo + hi) / 2
    k = SNAKE_LENGTH / max((hi - lo)[:2])
    base = Vector((c[0], c[1], lo[2]))
    for v in o.data.vertices:
        v.co = (Vector(v.co) - base) * k
    names = [n for n, _ in mids]
    pts = [(p - base) * k for _, p in mids]
    # The chain runs tail to head (the head leads); the head is the end
    # whose middle sits nearer the body's thicker end - here, the group
    # order already runs head (Bone) to tail.
    names, pts = names[::-1], pts[::-1]
    pts = [Vector((p.x, p.y, 0.06)) for p in pts]
    arm, bones = _chain(pts + [pts[-1] + (pts[-1] - pts[-2])])
    for gname, bname in zip(names, bones):
        g = o.vertex_groups.get(gname)
        if g is not None:
            g.name = bname
    o.parent = arm
    md = o.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    n = len(bones)

    def wave(amp, speed, cycles):
        def fn(t, pbs):
            for i, pb in enumerate(pbs):
                s = i / n
                a = amp * math.sin(math.tau * (cycles * s - t * speed)) * (0.4 + 0.6 * s)
                pb.rotation_quaternion = Matrix.Rotation(a, 4, "Z").to_quaternion()
        return fn

    _clip(arm, "Snake_Walk", 24, wave(0.22, 1.0, 1.2))
    _clip(arm, "Snake_Idle", 24, wave(0.05, 1.0, 0.6))
    export("snake", [arm, o])


def grasshopper(src):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "Grasshopper.blend"))
    parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Grasshopper")]
    for o in list(bpy.data.objects):
        if o not in parts:
            bpy.data.objects.remove(o, do_unlink=True)
    m = bpy.data.materials["Grasshopper"]
    tex = m.node_tree.nodes["Image Texture"].image
    plain = bpy.data.materials.new("grasshopper")
    plain.use_nodes = True
    b = next(n for n in plain.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    t = plain.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = tex
    plain.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(plain)
    o = join(parts, "grasshopper")
    decimate(o, 3000)
    tex.scale(512, 512)
    # Its length (y in the file) along y, head to -y, feet at z 0, sized
    # like the pack's spider (3 long).
    lo, hi = bounds([o])
    k = 3.0 / (hi - lo)[1]
    c = (lo + hi) / 2
    for v in o.data.vertices:
        p = (Vector(v.co) - Vector((c[0], c[1], lo[2]))) * k
        # (it faced +y in the file)
        v.co = Vector((-p.x, -p.y, p.z))
    arm, bones = _chain([Vector((0, 0, 0.3)), Vector((0, -0.6, 0.3))])
    o.parent = arm
    o.vertex_groups.new(name=bones[0]).add(range(len(o.data.vertices)), 1.0, "REPLACE")
    md = o.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    pb = arm.pose.bones[0]
    pb.rotation_mode = "QUATERNION"

    def hop(t, pbs):
        # crouch (0-0.2), leap up and along (0.2-0.75), land and settle
        if t < 0.2:
            z, tilt = -0.12 * math.sin(t / 0.2 * math.pi / 2), 0.0
        elif t < 0.75:
            u = (t - 0.2) / 0.55
            z, tilt = 1.4 * math.sin(u * math.pi), -0.35 * math.cos(u * math.pi)
        else:
            u = (t - 0.75) / 0.25
            z, tilt = -0.08 * math.sin(u * math.pi), 0.0
        # (bone space: the bone lies along the body, its z up)
        pbs[0].location = Vector((0, 0, z))
        pbs[0].rotation_quaternion = Matrix.Rotation(tilt, 4, "X").to_quaternion()

    def idle(t, pbs):
        pbs[0].location = Vector((0, 0, 0.03 * math.sin(t * math.tau)))
        pbs[0].rotation_quaternion = Matrix.Rotation(0.03 * math.sin(t * math.tau * 2), 4, "Z").to_quaternion()

    _clip(arm, "Grasshopper_Hop", 16, hop)
    _clip(arm, "Grasshopper_Idle", 24, idle)
    export("grasshopper", [arm, o])


# The turn (deg about z) that faces each user model the way the pack's does.
SNAKE_LENGTH = 3.6
BEE_LENGTH = 3.4
TURNS = {"rat": 0.0, "frog": 0.0}
SOURCES = {"rat": rat, "frog": frog, "bee": bee, "snake": snake, "grasshopper": grasshopper}


def main():
    args = sys.argv[1:]
    src = args[0]
    for name in args[1:] or list(SOURCES):
        SOURCES[name](src)


if __name__ == "__main__":
    main()
