"""A Meshy character's head on an old-style body (user request: the new
(Meshy) characters move as well as the old ones - their bodies the old
kind, tools/greybox_animals.py's, built to their proportions - and look as
they did: their heads, and the pictures of their fur, their own).

The Meshy character as tools/build_meshy_character.py builds it (rigged on
the game's skeleton, its head rigid with the Head bone, its ears on their
own bones) is brought onto the old-style character's skeleton - each of
its points carried by the bones it's weighted to, from where the Meshy
rig has them to where this one does (conform) - and:

  graft()      its head (what moves with the Head bone and the ears') is
               cut off and joined to the old-style body, keeping its own
               picture, weights and ear bones; the cut's ring drawn in onto
               the body's neck under it, and its last few centimetres
               weighted as the neck is, so neck and head move as one;
  surface()    the whole of it, conformed, with its pictures - for
               tools/paint_pelt.py to paint the body's fur from.
"""
import numpy as np

import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# A point's share with the head (its Head and ear weights) from which it's
# the grafted head's; the head's last stretch (share below FULL) weighted
# as the body under it, and its edge drawn in onto it.
CUT = 0.5
FULL = 0.98
# how far the edge's next rings follow it in (m along the surface, roughly)
SNAP_REACH = 0.03
# the edge sits this far out from the body's neck
SNAP_OUT = 0.0015
# (and only from this near it)
SNAP_FAR = 0.05


def _unit(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-12)


def load(path):
    """The Meshy build (its armature at rest, its mesh) brought into the
    scene; returns (armature, mesh, every object it brought)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    mesh = next(o for o in new if o.type == "MESH" and o.data.materials)
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    return arm, mesh, new


def frames(arm):
    """Each bone's head and tail at rest (world)."""
    mw = arm.matrix_world
    return {b.name: (np.array(mw @ b.head_local), np.array(mw @ b.tail_local)) for b in arm.data.bones}


def rest(mesh):
    """Its points at rest (world) and its weights (points x groups)."""
    me = mesh.data
    M = np.array(mesh.matrix_world)
    co = np.array([v.co for v in me.vertices]) @ M[:3, :3].T + M[:3, 3]
    names = [g.name for g in mesh.vertex_groups]
    W = np.zeros((len(me.vertices), len(names)))
    for v in me.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    return co, W, names


def conform(co, W, names, src, dst):
    """co carried from the src rig to the dst rig: each bone's share of a
    point moved as far as the bone's head is (only moved - a glTF rig's
    bone tails are made up on import, so their ways can't be compared; the
    two rigs are built alike, so the bones' places are what differ)."""
    out = np.zeros_like(co)
    tot = np.zeros(len(co))
    for j, n in enumerate(names):
        w = W[:, j]
        if n not in src or n not in dst or not w.any():
            continue
        out += w[:, None] * (co + (dst[n][0] - src[n][0]))
        tot += w
    lone = tot < 1e-6
    out[~lone] /= tot[~lone, None]
    # (unweighted points: with the pelvis)
    shift = dst["pelvis"][0] - src["pelvis"][0]
    out[lone] = co[lone] + shift
    return out


def head_share(W, names):
    return sum(W[:, j] for j, n in enumerate(names) if n == "Head" or n.startswith("ear_"))


def _pictures(me):
    """Each material's colour picture's pixels (h, w, 3), or a plain colour."""
    pics = []
    for m in me.materials:
        img = None
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links):
                    img = n.image
        if img is not None:
            w, h = img.size
            pics.append(np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, :3])
        else:
            col = (0.1, 0.1, 0.1)
            if m and m.use_nodes:
                b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if b:
                    col = tuple(c ** (1 / 2.2) for c in b.inputs["Base Color"].default_value[:3])
            pics.append(np.array(col, dtype=np.float32).reshape(1, 1, 3))
    return pics


def _scarf_faces(me, below):
    """The faces of a neckerchief (red, as seen in the picture, under the
    height `below`): the body's own wears one, moving with the neck, not
    the head."""
    pics = _pictures(me)
    uvl = me.uv_layers.active.data
    out = np.zeros(len(me.polygons), bool)
    for p in me.polygons:
        px = pics[p.material_index]
        h, w = px.shape[:2]
        u = np.mean([uvl[i].uv[0] for i in p.loop_indices]) % 1.0
        v = np.mean([uvl[i].uv[1] for i in p.loop_indices]) % 1.0
        r, g, b = px[min(int(v * h), h - 1), min(int(u * w), w - 1)]
        # (crimson - its blue as strong as its green, not a shiba's orange -
        # and low, round the neck)
        out[p.index] = r > 0.22 and r > 2.2 * g and b > 0.7 * g and p.center.z < below
    return out


def graft(arm, body, path, drop_red=False):
    """The Meshy build at `path`'s head on `body` (bound to `arm`), joined
    to it (drop_red: without its neckerchief - the body has its own)."""
    m_arm, m_mesh, new = load(path)
    co, W, names = rest(m_mesh)
    co = conform(co, W, names, frames(m_arm), frames(arm))
    t = head_share(W, names)
    # the head: a copy of the Meshy mesh, conformed, cut to the faces
    # wholly the head's
    me = m_mesh.data.copy()
    me.vertices.foreach_set("co", co.ravel())
    head = bpy.data.objects.new("graft_head", me)
    bpy.context.scene.collection.objects.link(head)
    for g in m_mesh.vertex_groups:
        head.vertex_groups.new(name=g.name)
    drop = _scarf_faces(me, frames(arm)["Head"][0][2] + 0.02) if drop_red else np.zeros(len(me.polygons), bool)
    bm = bmesh.new()
    bm.from_mesh(me)
    keep = t > CUT
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if drop[f.index] or not all(keep[v.index] for v in f.verts)],
                     context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    # (the vertex groups survived on the mesh's own deform layer)
    hco = np.array([v.co for v in me.vertices])
    hW = np.zeros((len(me.vertices), len(names)))
    for v in me.vertices:
        for g in v.groups:
            hW[v.index, g.group] = g.weight
    ht = head_share(hW, names)
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    # the body's weights at each of its points
    probe = head.copy()
    probe.data = head.data.copy()
    bpy.context.scene.collection.objects.link(probe)
    for g in list(probe.vertex_groups):
        probe.vertex_groups.remove(g)
    for vg in body.vertex_groups:
        probe.vertex_groups.new(name=vg.name)
    md = probe.modifiers.new("w", "DATA_TRANSFER")
    md.object = body
    md.use_vert_data = True
    md.data_types_verts = {"VGROUP_WEIGHTS"}
    md.vert_mapping = "POLYINTERP_NEAREST"
    md.layers_vgroup_select_src = "ALL"
    md.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = probe
    probe.select_set(True)
    bpy.ops.object.modifier_apply(modifier=md.name)
    bw = {}
    pidx = {g.index: g.name for g in probe.vertex_groups}
    for v in probe.data.vertices:
        for g in v.groups:
            bw.setdefault(pidx[g.group], np.zeros(len(hco)))[v.index] = g.weight
    bpy.data.objects.remove(probe, do_unlink=True)
    # the head's own share (Head, ears) as it was, made whole over its
    # last stretch; the rest of each point the body's
    own = np.clip((ht - CUT) / (FULL - CUT), 0.0, 1.0)
    for g in list(head.vertex_groups):
        head.vertex_groups.remove(g)
    groups = {}

    def group(n):
        if n not in groups:
            groups[n] = head.vertex_groups.new(name=n)
        return groups[n]
    for j, n in enumerate(names):
        if n == "Head" or n.startswith("ear_"):
            w = hW[:, j] / np.maximum(ht, 1e-6) * own
            for i in np.nonzero(w > 1e-4)[0]:
                group(n).add([int(i)], float(w[i]), "REPLACE")
    for n, w in bw.items():
        w = w * (1.0 - own)
        for i in np.nonzero(w > 1e-4)[0]:
            group(n).add([int(i)], float(w[i]), "ADD")
    _snap_edge(head, body, ht < FULL)
    # one mesh with the body
    head.parent = body.parent
    bpy.ops.object.select_all(action="DESELECT")
    head.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    print("graft: head of %d points from %s" % (len(hco), path))
    return body


def _snap_edge(head, body, cut):
    """The cut's ring drawn in onto the body's neck (it hung open round it)
    and the rings just above it eased after it - only the cut's own edge
    (`cut`: the points on the head's last stretch; its other open edges,
    round the eyes and in the mouth, stay)."""
    me = head.data
    bm = bmesh.new()
    bm.from_mesh(me)
    edge = {v.index for e in bm.edges if e.is_boundary for v in e.verts if cut[v.index]}
    co = np.array([v.co for v in bm.verts])
    bm.free()
    if not edge:
        return
    dg = bpy.context.evaluated_depsgraph_get()
    bme = bmesh.new()
    bme.from_object(body, dg)
    bme.transform(body.matrix_world)
    tree = BVHTree.FromBMesh(bme)
    bme.free()
    moves = {}
    for i in edge:
        hit = tree.find_nearest(Vector(co[i]))
        if hit[0] is not None and hit[3] < SNAP_FAR:
            p, n = np.array(hit[0]), np.array(hit[1])
            moves[i] = p + n * SNAP_OUT - co[i]
    if not moves:
        return
    ei = np.array(sorted(moves))
    em = np.array([moves[i] for i in ei])
    from scipy.spatial import cKDTree
    d, k = cKDTree(co[ei]).query(co)
    fall = np.clip(1.0 - d / SNAP_REACH, 0.0, 1.0) ** 2
    new = co + em[k] * fall[:, None]
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    print("graft: edge of %d points drawn in, %.1f mm on average" %
          (len(ei), float(np.linalg.norm(em, axis=1).mean()) * 1000))


def surface(arm, path):
    """The Meshy build at `path` conformed to `arm`'s rig, for sampling
    its pictures: (BVH tree over its triangles, per triangle: its corners'
    UVs (t, 3, 2) and its picture's pixels (h, w, 3), the head's share of
    each triangle). Removes what it brought into the scene."""
    m_arm, m_mesh, new = load(path)
    co, W, names = rest(m_mesh)
    co = conform(co, W, names, frames(m_arm), frames(arm))
    t = head_share(W, names)
    me = m_mesh.data
    uvl = me.uv_layers.active.data
    tris, tuv, tmat = [], [], []
    me.calc_loop_triangles()
    for lt in me.loop_triangles:
        tris.append(list(lt.vertices))
        tuv.append([uvl[li].uv[:] for li in lt.loops])
        tmat.append(lt.material_index)
    pics = _pictures(me)
    tris = np.array(tris)
    tree = BVHTree.FromPolygons([Vector(p) for p in co], tris.tolist())
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return tree, co, tris, np.array(tuv), np.array(tmat), pics, t[tris].mean(axis=1)


def sample(q, n, surf, reach=0.08):
    """The Meshy picture's colour nearest each point q (n, 3): a ray in
    along -n and out along n first (the surface over or under it), else the
    nearest point; NaN where nothing's within reach."""
    tree, co, tris, tuv, tmat, pics, _ = surf
    out = np.full((len(q), 3), np.nan, dtype=np.float32)
    for i in range(len(q)):
        p = Vector(q[i])
        hit = tree.find_nearest(p, reach)
        if hit[0] is None:
            continue
        loc, f = hit[0], hit[2]
        a, b, c = (co[tris[f][k]] for k in range(3))
        x = np.array(loc)
        v0, v1, v2 = b - a, c - a, x - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-14:
            continue
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        bu = 1.0 - bv - bw
        uv = tuv[f, 0] * bu + tuv[f, 1] * bv + tuv[f, 2] * bw
        px = pics[tmat[f]]
        h, w = px.shape[:2]
        fx = (uv[0] % 1.0) * w - 0.5
        fy = (uv[1] % 1.0) * h - 0.5
        x0, y0 = int(np.floor(fx)) % w, int(np.floor(fy)) % h
        x1, y1 = (x0 + 1) % w, (y0 + 1) % h
        tx, ty = fx - np.floor(fx), fy - np.floor(fy)
        out[i] = (px[y0, x0] * (1 - tx) * (1 - ty) + px[y0, x1] * tx * (1 - ty) +
                  px[y1, x0] * (1 - tx) * ty + px[y1, x1] * tx * ty)
    return out
