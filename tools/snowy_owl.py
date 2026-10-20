"""The old owl (the greybox horned owl, assets/models/characters/owl.glb)
made a snowy owl (user request: the two owls were most unlike - the old one
flat brown, no feathers drawn - so it's given feathers painted as the new
one's are, and all white, after a snowy owl): its feathers a picture -
white, lying over each other down its body and out along its arms (each
rounded tip over the next one's root, a soft grey just under it), out from
its eyes over its face, a dark bar across the tips of a few on its back,
crown and wings - its eyes yellow with a black pupil, its beak and claws
black. Its shape, skeleton and clips are as they were.

    bpyenv/bin/python tools/snowy_owl.py -- IN.glb OUT.glb
"""
import os
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[:2]
SIZE = 1024
# A feather's width (m), how much longer than wide it lies, how many have
# a dark bar (one in FLECK of them on its back, crown and wings).
FEATHER = 0.024
LONG = 1.5
FLECK = 7
WHITE = np.array([0.96, 0.96, 0.94])
SHADE = np.array([0.74, 0.77, 0.82])
DARK = np.array([0.20, 0.18, 0.17])
# (as seen - sRGB)
EYE = (0.95, 0.80, 0.14)
BEAK = (0.10, 0.09, 0.09)
PAD = (0.40, 0.38, 0.37)
# (the pupil's size: its angle round the eyeball's middle)
PUPIL = 0.42
# (the lids' dark rim round the eyes: m from the fur)
RIM = 0.0025


def select(objs, active=None):
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = active or objs[0]


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=SRC)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.materials)
    for o in list(bpy.data.objects):
        if o not in (arm, body):
            bpy.data.objects.remove(o, do_unlink=True)
    # (the importer's names back as the game knows them - as
    # build_meshy_character.game_skeleton has them)
    for a in bpy.data.actions:
        if a.name.endswith("_Armature"):
            a.name = a.name[:-len("_Armature")]
    for tr in arm.animation_data.nla_tracks:
        if tr.name.endswith("_Armature"):
            tr.name = tr.name[:-len("_Armature")]
        for st in tr.strips:
            if st.name.endswith("_Armature"):
                st.name = st.name[:-len("_Armature")]
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    return arm, body


def unwrap(body, keep):
    """Its feathers and eyes laid out on one picture (the rest - clothes,
    claws - plain colours, left off it)."""
    import bmesh
    select([body])
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(body.data)
    for f in bm.faces:
        f.select_set(f.material_index in keep)
    bmesh.update_edit_mesh(body.data)
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
    bpy.ops.object.mode_set(mode='OBJECT')


def texels(body, keep):
    """Where on the owl (at rest) each texel of the picture is, and which way
    out - baked off a copy of the faces of the materials in keep."""
    import bmesh
    dup = body.copy()
    dup.data = body.data.copy()
    bpy.context.scene.collection.objects.link(dup)
    dup.parent = None
    dup.matrix_world = body.matrix_world
    for m in list(dup.modifiers):
        dup.modifiers.remove(m)
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in keep], context='FACES')
    bm.to_mesh(dup.data)
    bm.free()
    mat = bpy.data.materials.new("Bake")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emit = nt.nodes.new('ShaderNodeEmission')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    img_node = nt.nodes.new('ShaderNodeTexImage')
    nt.links.new(emit.outputs[0], out.inputs['Surface'])
    dup.data.materials.clear()
    dup.data.materials.append(mat)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    sc.render.bake.use_selected_to_active = False
    sc.render.bake.margin = 6
    maps = {}
    for what in ("Position", "Normal"):
        buf = bpy.data.images.new("Bake" + what, SIZE, SIZE, alpha=True, float_buffer=True)
        buf.generated_color = (0.0, 0.0, 0.0, 0.0)
        img_node.image = buf
        nt.nodes.active = img_node
        nt.links.new(geo.outputs[what], emit.inputs['Color'])
        select([dup])
        bpy.ops.object.bake(type='EMIT')
        maps[what] = np.array(buf.pixels[:]).reshape(SIZE, SIZE, 4)
        bpy.data.images.remove(buf)
    bpy.data.objects.remove(dup, do_unlink=True)
    bpy.data.materials.remove(mat)
    # (texels off the owl: no way out - the bake leaves their alpha set)
    N = maps["Normal"][:, :, :3]
    return maps["Position"][:, :, :3], N, np.linalg.norm(N, axis=2) > 0.5


def world_verts(body, index):
    me = body.data
    co = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    no = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", no)
    M = np.array(body.matrix_world)
    co = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
    no = no.reshape(-1, 3) @ M[:3, :3].T
    no /= np.linalg.norm(no, axis=1, keepdims=True) + 1e-9
    on = np.zeros(len(me.vertices), bool)
    for p in me.polygons:
        if p.material_index == index:
            on[list(p.vertices)] = True
    return co[on], no[on]


def lay(q, eyes, shoulder):
    """Which way the feathers lie at each point (their tips' way): down the
    body and legs, out along the arms toward the hands, and out from the
    eyes over the face (an owl's face a disc of feathers round them)."""
    d = np.zeros_like(q)
    d[:, 2] = -1.0
    t = np.clip((np.abs(q[:, 0]) - shoulder) / 0.08, 0.0, 1.0)[:, None]
    out = np.stack([np.sign(q[:, 0]), np.zeros(len(q)), np.full(len(q), -0.3)], axis=1)
    d = d * (1 - t) + out * t
    e = eyes[(q[:, 0] > 0).astype(int)]
    face = np.clip((-0.02 - q[:, 1]) / 0.05, 0, 1) * np.clip((q[:, 2] - (e[:, 2] - 0.10)) / 0.04, 0, 1)
    rad = q - e
    rad[:, 1] = 0.0
    rad /= np.linalg.norm(rad, axis=1, keepdims=True) + 1e-9
    d = d * (1 - face[:, None]) + rad * face[:, None]
    return d / (np.linalg.norm(d, axis=1, keepdims=True) + 1e-9), face


def feathers(body, fur_index, eyes, P, on):
    """The feathers' picture: feathers spread FEATHER apart over the owl,
    each a long oval lying the way lay() has them, the one nearer the root
    of the body over the next (as a bird's feathers lie, each tip over the
    next one's root) - so what shows is each feather's rounded tip, white,
    a soft grey just under it on the feather beneath; a dark bar across the
    tip of a few on its back, crown and wings (a snowy owl's markings) and
    none on its face and front."""
    from scipy.spatial import cKDTree
    co, _ = world_verts(body, fur_index)
    rng = np.random.default_rng(11)
    pts = co[rng.permutation(len(co))]
    centres = []
    tree = None
    for p in pts:
        if centres and len(centres) % 200 == 0:
            tree = cKDTree(np.array(centres))
        if tree is not None and tree.query(p)[0] < FEATHER:
            continue
        if centres and np.min(np.linalg.norm(np.array(centres[-200:]) - p, axis=1)) < FEATHER:
            continue
        centres.append(p)
    c = np.array(centres)
    q = P[on]
    shoulder = 0.22
    d, face = lay(q, eyes, shoulder)
    _, near = cKDTree(c).query(q, k=8)
    W, L = FEATHER * 1.0, FEATHER * LONG
    rel = q[:, None, :] - c[near]
    a = np.einsum("nki,ni->nk", rel, d)
    b = np.linalg.norm(rel - a[:, :, None] * d[:, None, :], axis=2)
    E = np.hypot(a / L, b / W)
    # (how far up the body each feather's root is: the higher one on top)
    rank = np.einsum("nki,ni->nk", c[near], d)
    covers = E < 1.0
    rank_on = np.where(covers, rank, np.inf)
    top = np.argmin(rank_on, axis=1)
    top[~covers.any(axis=1)] = 0
    rows = np.arange(len(q))
    mine = rank[rows, top]
    # under the tip of a feather above it: E just over 1, past its middle
    above = (rank < mine[:, None] - 1e-6) & (a > 0.0)
    under = np.where(above, np.clip(1.0 - (E - 1.0) / 0.45, 0.0, 1.0), 0.0).max(axis=1)
    shade = under ** 1.5 * (1.0 - 0.6 * face)
    which = near[rows, top]
    jitter = rng.uniform(-0.02, 0.02, len(c))[which]
    col = WHITE[None, :] * (1.0 + jitter[:, None])
    col = col * (1.0 - shade[:, None]) + SHADE[None, :] * shade[:, None]
    # the bars: across the tip of one feather in FLECK on its back (behind
    # the middle), crown and wings (out past the shoulders)
    top_z = co[:, 2].max()
    marks = (c[:, 1] > 0.03) | (c[:, 2] > top_z - 0.12) | (np.abs(c[:, 0]) > shoulder + 0.06)
    marks &= rng.integers(0, FLECK, len(c)) == 0
    Et, at, bt = E[rows, top], a[rows, top], b[rows, top]
    bar = marks[which] & (Et > 0.52) & (Et < 0.74) & (at > 0.35 * L) & (bt < 0.55 * W) & (face < 0.5)
    col[bar] = DARK
    out = np.ones((SIZE, SIZE, 4))
    out[:, :, :3] = WHITE
    out[on, :3] = np.clip(col, 0.0, 1.0)
    print("feathers: %d over the owl, %d barred" % (len(c), marks.sum()))
    return out


def fur_near(body, fur_index, eye_pts, reach=0.06, n=8):
    """Points close over the fur's faces round the eyes (its vertices too
    far apart to tell an eye's edge by)."""
    me = body.data
    M = np.array(body.matrix_world)
    co = np.array([v.co for v in me.vertices]) @ M[:3, :3].T + M[:3, 3]
    lo, hi = eye_pts.min(axis=0) - reach, eye_pts.max(axis=0) + reach
    tris = []
    for p in me.polygons:
        if p.material_index != fur_index:
            continue
        vs = co[list(p.vertices)]
        if np.all((vs.mean(axis=0) > lo) & (vs.mean(axis=0) < hi)):
            for i in range(1, len(vs) - 1):
                tris.append((vs[0], vs[i], vs[i + 1]))
    t = np.array(tris)
    u, v = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n))
    keep = (u + v) <= 1.0
    u, v = u[keep], v[keep]
    pts = t[:, None, 0] + u[None, :, None] * (t[:, None, 1] - t[:, None, 0]) + v[None, :, None] * (t[:, None, 2] - t[:, None, 0])
    return np.concatenate([pts.reshape(-1, 3), world_verts(body, fur_index)[0]])


def eye_centres(body, eye_index):
    """Each eye's middle (its ball's) and where it looks: the middle of its
    front (the eyes' faces turned most forward)."""
    co, no = world_verts(body, eye_index)
    out = []
    for side in (-1, 1):
        s = co[:, 0] * side > 0
        ball = co[s].mean(axis=0)
        front = co[s][no[s][:, 1] < -0.6].mean(axis=0)
        out.append((ball, front))
    return out


def irises(picture, eyes, P, on):
    """The eyes: yellow, a round black pupil in the middle of each eye's
    front (the old owl's were plain colour)."""
    q = P[on]
    col = np.tile(np.array(EYE), (len(q), 1))
    for ball, front in eyes:
        look = front - ball
        look /= np.linalg.norm(look)
        v = q - ball
        v /= np.linalg.norm(v, axis=1, keepdims=True) + 1e-9
        ang = np.arccos(np.clip(v @ look, -1, 1))
        side = np.sign(q[:, 0]) == np.sign(ball[0])
        col[side & (ang < PUPIL)] = BEAK
        rim = side & (ang >= PUPIL) & (ang < PUPIL + 0.06)
        col[rim] = col[rim] * 0.7
    picture[on, :3] = col
    return picture


def dress(body, picture):
    img = bpy.data.images.new("owl_Feathers", SIZE, SIZE)
    img.pixels.foreach_set(picture.astype(np.float32).ravel())
    img.pack()
    for m in body.data.materials:
        b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        if m.name.startswith(("col_fur", "col_eye")):
            t = m.node_tree.nodes.new('ShaderNodeTexImage')
            t.image = img
            m.node_tree.links.new(t.outputs['Color'], b.inputs['Base Color'])
            if m.name.startswith("col_fur"):
                b.inputs['Roughness'].default_value = 0.9
        for name, rgb in (("col_horn", BEAK), ("col_pad", PAD)):
            if m.name.startswith(name):
                b.inputs['Base Color'].default_value = (*(v ** 2.2 for v in rgb), 1.0)


def main():
    arm, body = load()
    index = {m.name.split(".")[0]: i for i, m in enumerate(body.data.materials)}
    fur, eye = index["col_fur"], index["col_eye"]
    unwrap(body, (fur, eye))
    eyes = eye_centres(body, eye)
    P, _, on = texels(body, (fur, eye))
    # (which texels are the eyes': nearer an eye's surface than the fur's)
    from scipy.spatial import cKDTree
    on_eye = np.zeros_like(on)
    to_fur = cKDTree(fur_near(body, fur, world_verts(body, eye)[0])).query(P[on])[0]
    on_eye[on] = cKDTree(world_verts(body, eye)[0]).query(P[on])[0] < to_fur
    # (and a dark rim where the lids close over them, as an owl's have)
    rim = np.zeros_like(on)
    rim[on] = to_fur < RIM
    picture = feathers(body, fur, np.array([f for _, f in eyes]), P, on & ~on_eye)
    picture = irises(picture, eyes, P, on_eye)
    picture[on_eye & rim, :3] = BEAK
    dress(body, picture)
    select([arm, body], active=arm)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_optimize_animation_size=True, export_anim_single_armature=True,
                              export_def_bones=False, export_image_format='JPEG', export_jpeg_quality=88)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")


if __name__ == "__main__":
    main()
