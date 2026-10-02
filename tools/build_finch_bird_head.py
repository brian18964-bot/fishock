"""The beginner animal person, from the finch character and a real bird
(user request: every animal person starts in the beginner's clothes -
only its head, forearms and lower legs show - so those are the animal's;
the finch's plush felt head swapped for a realistic one, here the user's
owl, its feathers lying over the jumper's neckline as they would, not
tucked under it).

  blender -b --python tools/build_finch_bird_head.py -- FINCH.blend BIRD.blend OUT.blend [PREVIEW_PREFIX]

FINCH.blend: the finch in its beginner's clothes (build_finch_beginner.py).
BIRD.blend: the owl (cgtrader Owl.blend: one mesh, sm_1_0_0, facing -y
like the finch, its head at the -y end, top up).

  - head: the owl's, cut off at the shoulders, sized to about the felt
    head, set on the neck; the felt head, its eyes and the buttons of the
    shirt under the jumper taken off;
  - back of the head: the owl's head is only a face - in flight its
    back runs into its body - so a rounded crown is set behind it, the
    face's cut edge drawn in onto it;
  - ruff: a mantle of the owl's feathers from under its face and the
    back of its head out over the jumper's neck and down onto the knit,
    lying on it, in two layers of rounded feather tips (the outer
    shorter, over the gaps of the inner), filling the V of the neck - the
    feathers over the clothes, not tucked in; the head's lower part,
    inside it, taken off;
  - sleeves: rolled up to just below the elbow (cut, the edge turned out
    and back into a thick cuff, the knit carried on round it), the
    forearms below them grown out of the hands along the forearm bones;
  - forearms and shins: in tiers of feathers (each tier's tips standing
    out over the next), the fingers and toes left scaly and darker;
  - one picture of the owl's own small body feathers over all of it
    (projected on, tiled without seams), the legs' buff;
  - the head and ruff given to the head bone (DEF_head) - the finch's own
    parts carry no bone weights in its file; they're bound when the
    character goes into the game.

PREVIEW_PREFIX: renders <prefix>_front/three/face/side/arm/legs.png.
"""
import math
import os
import sys

import bpy
import bmesh  # noqa: E402 (after bpy, which provides it)
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
SRC, BIRD, OUT = [os.path.abspath(a) for a in args[:3]]
PREVIEW = args[3] if len(args) > 3 else ""

# The owl's head in its own file.
HEAD_Y = -0.24
HEAD_Z = 0.24
HEAD_X = 0.16
# On the finch: as wide as this, its lowest point this high (the V of the
# jumper's neck reaches down to ~0.82), centred over the head bone, a
# touch forward.
WIDTH = 0.25
BOTTOM = 0.815
FORWARD = -0.03
# The ruff: from RUFF_RISE above the jumper's neckline (under the head)
# out over the neck and onto the knit, in layers - (how far past the
# neckline its tips reach, how far off the knit it lies, where its tips
# fall round the neck as a share of one tip, its own random draw) - the
# inner the longer, the outer over its gaps. RUFF_TIPS round the neck,
# their lengths a little uneven (RUFF_JITTER), notched RUFF_NOTCH deep,
# each RUFF_TIP_SEGS faces wide; RUFF_ROWS rows under the head and on the
# knit; RUFF_PUFF how full the breast under the chin.
RUFF_RISE = 0.045
RUFF_LAYERS = [(0.007, 0.002, 0.0, 5), (0.004, 0.0035, 0.5, 6)]
RUFF_TIPS = 56
RUFF_JITTER = 0.3
RUFF_NOTCH = 0.003
RUFF_TIP_SEGS = 4
RUFF_ROWS = (5, 2)
RUFF_PUFF = 0.0
# ...over a neckline rounded off over this many degrees (the tips still
# past the real one by RUFF_COVER), and no further out from it than
# RUFF_SPREAD (the inner layer's longest tips).
RUFF_ROUND = 50
RUFF_SPREAD = 0.009
RUFF_COVER = 0.004
# Its feathers' picture (and the back of the head's): repeats a metre.
FEATHER_SCALE = 7.5
# The shins: feathered all round - from ANKLE up, this thick at the
# ankle and under the shorts, ruffled by FLUFF.
ANKLE = 0.05
SHIN = (0.021, 0.03)
FLUFF = 0.12
# Tiers of feathers on the forearms (how many) and shins (how tall each),
# each tier's tips standing this much proud of its roots.
ARM_TIERS = 3
LEG_TIER = 0.045
TIER_FLARE = 0.14
# The sleeves: cut here (|x|), the cuff this wide and thick.
SLEEVE_END = 0.37
CUFF = 0.028
CUFF_OUT = 0.009
# The rounded back of the head: its half sizes as shares of the owl
# head's width / height, how far it reaches behind the cut, its middle's
# height as a share of the head's height; its front, as a share of the
# face's depth from the beak (hidden inside the face).
CROWN = (0.42, 0.34)
CROWN_BACK = 0.045
CROWN_FRONT = 0.55
CROWN_MID = 0.6
# The face's cut edge, where it's this near the crown, drawn onto it.
CROWN_SNAP = 0.02
# The feathers: a patch of the owl's small grey-brown body feathers
# (pixels in its 2048 texture) - the back of the head, the ruff, the
# forearms and hands, the legs.
GREY_PATCH = (280, 620, 700, 960)
# The legs: those feathers, buff (an owl's legs are paler, warmer, their
# markings fainter).
LEG_TINT = ((0.86, 0.66, 0.40), 1.0, 0.12, -0.15)
OFF = ["finch_head", "finch_eye", "finch_button_shirt_1", "finch_button_shirt_2", "finch_button_shirt_3"]


def world_points(o):
    return np.array([o.matrix_world @ v.co for v in o.data.vertices])


def evaluated_bvh(o):
    dg = bpy.context.evaluated_depsgraph_get()
    me = o.evaluated_get(dg).to_mesh()
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.transform(o.matrix_world)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


# ---------------------------------------------------------------- the head

def cut_head(src):
    with bpy.data.libraries.load(src) as (data_from, data_to):
        data_to.objects = ["sm_1_0_0"]
    owl = data_to.objects[0]
    bpy.context.scene.collection.objects.link(owl)
    owl.name = "bird_head"
    owl.modifiers.clear()
    owl.parent = None
    # Its picture by its full name, wherever the build is saved.
    for m in owl.data.materials:
        for n in m.node_tree.nodes if m and m.use_nodes else []:
            if n.type == "TEX_IMAGE" and n.image is not None:
                n.image.filepath = os.path.join(os.path.dirname(src), os.path.basename(n.image.filepath))
                n.image.reload()
    bm = bmesh.new()
    bm.from_mesh(owl.data)
    gone = [v for v in bm.verts if not (v.co.y < HEAD_Y and v.co.z > HEAD_Z and abs(v.co.x) < HEAD_X)]
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(owl.data)
    bm.free()
    return owl


def place(owl, arm):
    pts = [Vector(v.co) for v in owl.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    k = WIDTH / (hi.x - lo.x)
    at = arm.matrix_world @ arm.data.bones["DEF_head"].head_local
    centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in owl.data.vertices:
        v.co = (Vector(v.co) - centre) * k + Vector((at.x, at.y + FORWARD, BOTTOM))
    owl.matrix_world = Matrix.Identity(4)
    owl.data.update()
    return Vector((at.x, at.y))


def neckline(jumper):
    """The jumper's neck edge: its height round the neck, by angle (a
    function of the angle about the neck's axis)."""
    bm = bmesh.new()
    bm.from_mesh(jumper.data)
    bm.transform(jumper.matrix_world)
    pts = np.array([v.co[:] for e in bm.edges if e.is_boundary for v in e.verts])
    bm.free()
    pts = pts[(np.abs(pts[:, 0]) < 0.2) & (pts[:, 2] > 0.75)]
    cy = (pts[:, 1].min() + pts[:, 1].max()) / 2
    ang = np.arctan2(pts[:, 0], -(pts[:, 1] - cy))
    order = np.argsort(ang)
    ang, z = ang[order], pts[order, 2]

    def height(a):
        return float(np.interp(a, ang, z, period=2 * math.pi))
    return height, cy


def outermost(tree, centre, a, z, far=0.5):
    """How far out from the neck's axis, at height z and angle a, the
    outermost surface of `tree` is (None: nothing there)."""
    d = Vector((math.sin(a), -math.cos(a), 0.0))
    origin = Vector((centre.x, centre.y, z))
    reach = None
    start = origin
    for _ in range(8):
        hit, _n, _i, _d = tree.ray_cast(start, d, far)
        if hit is None:
            break
        reach = (hit - origin).length
        start = hit + d * 1e-4
    return reach


def tip_line(segs, tips, phase, seed):
    """Round the neck, how far each feather tip reaches (1 at a tip's
    point, falling to 0 at the notches between tips) and each tip's own
    length (a little different feather to feather)."""
    rng = np.random.default_rng(seed)
    long = 1.0 + RUFF_JITTER * rng.uniform(-1.0, 1.0, tips)
    # The tips not all the same width: their edges moved about a little.
    edges = (np.arange(tips) + phase + rng.uniform(-0.18, 0.18, tips)) / tips
    reach, length = np.zeros(segs), np.zeros(segs)
    for i in range(segs):
        f = i / segs
        k = int(np.searchsorted(edges, f, side="right")) - 1
        lo = edges[k % tips] - (1.0 if k < 0 else 0.0)
        hi = edges[(k + 1) % tips] + (1.0 if k + 1 >= tips else 0.0)
        u = (f - lo) / (hi - lo)
        # A rounded point: broad at the tip, a sharp notch between.
        reach[i] = math.sin(math.pi * min(max(u, 0.0), 1.0)) ** 0.55
        length[i] = long[k % tips]
    return reach, length


def ruff(owl, jumper, axis, mat):
    """The owl's ruff laid over the jumper: from under its face and the
    back of its head, out over the neck of the jumper and down onto the
    knit, in two layers of feather tips (the outer shorter, its tips over
    the gaps of the inner), lying on the knit as feathers would."""
    jt = evaluated_bvh(jumper)
    ht = evaluated_bvh(owl)
    height, cy = neckline(jumper)
    centre = Vector((axis.x, cy))
    segs = RUFF_TIPS * RUFF_TIP_SEGS
    angles = [-math.pi + 2 * math.pi * i / segs for i in range(segs)]
    # The neckline rounded off (the V's point and its corners smoothed),
    # so the breast is one even fall of feathers - its tips still below
    # the V's point.
    raw = np.array([height(a) for a in angles])
    win = max(int(segs * RUFF_ROUND / 360.0), 1)
    kernel = np.hanning(2 * win + 1)
    kernel /= kernel.sum()
    necks = [float(sum(kernel[k] * raw[(i + k - win) % segs] for k in range(2 * win + 1))) for i in range(segs)]
    # Where it meets the knit: the neck's edge (just inside it), and the
    # head it tucks under, round the neck.
    edge = []
    under = []
    for a, n in zip(angles, necks):
        r = outermost(jt, centre, a, n - 0.004)
        edge.append(r)
        z0 = n + RUFF_RISE
        h = outermost(ht, centre, a, z0)
        under.append((max((h or 0.0) - 0.004, 0.02), z0))
    edge = np.array([e if e is not None else np.nan for e in edge])
    ok = ~np.isnan(edge)
    edge[~ok] = np.interp(np.flatnonzero(~ok), np.flatnonzero(ok), edge[ok], period=segs)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for layer, (drape, lift, phase, seed) in enumerate(RUFF_LAYERS):
        reach, length = tip_line(segs, RUFF_TIPS, phase, seed)
        grid = []
        for i, a in enumerate(angles):
            r0, z0 = under[i]
            # Up to the neck's edge every layer lies under the first (the
            # outer ones come out from under it only on the knit).
            under_lift = RUFF_LAYERS[0][1] - 0.001 * layer
            r1, z1 = edge[i] + under_lift, necks[i] + 0.002
            # Past the rounded neckline, and always past the real one (the
            # V's point) a little.
            tip = min(necks[i] - drape, raw[i] - RUFF_COVER * drape / RUFF_LAYERS[0][0])
            tip = necks[i] - (necks[i] - tip) * length[i]
            # No further out over the shoulders' flat tops than this.
            spread = RUFF_SPREAD * drape / RUFF_LAYERS[0][0] * length[i]
            z = z1
            while z > tip:
                k = outermost(jt, centre, a, z - 0.002)
                if k is not None and k - edge[i] > spread:
                    tip = z
                    break
                z -= 0.002
            tip += RUFF_NOTCH * (1.0 - reach[i])
            # Round the back and sides the head's lower part tucks inside
            # (its own feathers don't show through); under the chin, the
            # face is over the breast.
            back = min(max((abs(a) - math.radians(45)) / math.radians(40), 0.0), 1.0)
            col = []
            # Out from under the head to the neck's edge: a full curve
            # (a puffed breast in front), the layer's lift coming in.
            for j in range(RUFF_ROWS[0]):
                t = j / RUFF_ROWS[0]
                s = math.sin(t * math.pi / 2)
                straight = (r0 + (r1 - r0) * t, z0 + (z1 - z0) * t)
                puffed = (r0 + (r1 - r0) * s, z0 + (z1 - z0) * (1.0 - math.cos(t * math.pi / 2)))
                r = straight[0] + (puffed[0] - straight[0]) * RUFF_PUFF
                z = straight[1] + (puffed[1] - straight[1]) * RUFF_PUFF
                r -= under_lift * (1.0 - t)
                if j > 0 and back > 0.0:
                    h = outermost(ht, centre, a, z)
                    if h is not None:
                        r = max(r, r + (h + 0.0015 - 0.001 * layer - r) * back)
                col.append((r, z))
            # Down over the knit to the tip, lying on it.
            last = edge[i] + lift
            for j in range(RUFF_ROWS[1] + 1):
                t = j / RUFF_ROWS[1]
                z = z1 + (tip - z1) * t
                k = outermost(jt, centre, a, z)
                r = max((k + lift) if k is not None else last, last - 0.002)
                col.append((r, z))
                last = r
            grid.append(col)
        rows = len(grid[0])
        R = np.array([[c[j][0] for c in grid] for j in range(rows)])
        Z = np.array([[c[j][1] for c in grid] for j in range(rows)])
        # Smoothed round the neck (the knit's own bumps, the raycasts'
        # steps), the tips' own heights kept.
        for _ in range(3):
            R = (np.roll(R, 1, 1) + 2 * R + np.roll(R, -1, 1)) / 4
        verts = [[bm.verts.new((centre.x + R[j, i] * math.sin(a), centre.y - R[j, i] * math.cos(a), Z[j, i]))
                  for i, a in enumerate(angles)] for j in range(rows)]
        for j in range(rows - 1):
            for i in range(segs):
                i2 = (i + 1) % segs
                f = bm.faces.new((verts[j][i], verts[j + 1][i], verts[j + 1][i2], verts[j][i2]))
                for loop, (u, w) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                    loop[uv].uv = (u / segs, 1.0 - (w + layer * rows) / (2 * rows))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("ruff")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("bird_ruff", me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    return ob, height, centre


def tuck(owl, height, centre):
    """The owl's head below the ruff's top - inside the ruff, or the
    jumper - taken off."""
    bm = bmesh.new()
    bm.from_mesh(owl.data)
    gone = []
    for v in bm.verts:
        a = math.atan2(v.co.x - centre.x, -(v.co.y - centre.y))
        if v.co.z < height(a) + RUFF_RISE - 0.012:
            gone.append(v)
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(owl.data)
    bm.free()


# ---------------------------------------------------------------- feathers

def patch(owl_png, box, name, saturation=1.0):
    """A crop of the owl's texture as a Blender image, made to tile
    without seams: crossfaded with itself moved half a tile over, so its
    edges are its own middle."""
    from PIL import Image
    from PIL import ImageEnhance
    tile = ImageEnhance.Color(Image.open(owl_png).convert("RGB").crop(box)).enhance(saturation)
    px = np.asarray(tile, dtype=np.float32) / 255.0
    h, w = px.shape[:2]
    moved = np.roll(px, (h // 2, w // 2), axis=(0, 1))
    wy = np.sin(np.pi * (np.arange(h) + 0.5) / h) ** 2
    wx = np.sin(np.pi * (np.arange(w) + 0.5) / w) ** 2
    keep = np.minimum(wy[:, None], wx[None, :])[..., None] ** 0.5
    px = (px * keep + moved * (1.0 - keep)).astype(np.float32)
    img = bpy.data.images.new(name, w, h)
    rgba = np.concatenate([px, np.ones((h, w, 1), np.float32)], axis=2)
    img.pixels.foreach_set(np.flipud(rgba).ravel())
    img.pack()
    return img


def feathers(name, img, scale, rough=0.85, under=None, tint=None):
    """A material: `img` box-projected in world space (`scale` repeats a
    metre). `under`: [image, (axis, from, to), tint] - another look
    blended in along a world axis (the fingers' and toes' scaly skin:
    the source's own texture, darkened to `tint`). `tint`: (colour, how
    much, lighter by) - the feathers' own markings in another colour."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = rough
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    nt.links.new(geo.outputs["Position"], mp.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.projection = "BOX"
    tex.projection_blend = 0.5
    nt.links.new(mp.outputs[0], tex.inputs[0])
    out = tex.outputs[0]
    if tint is not None:
        colour, amount, lighter, contrast = tint
        hue = nt.nodes.new("ShaderNodeMix")
        hue.data_type = "RGBA"
        hue.blend_type = "COLOR"
        hue.inputs["Factor"].default_value = amount
        hue.inputs[7].default_value = (*colour, 1.0)
        nt.links.new(out, hue.inputs[6])
        light = nt.nodes.new("ShaderNodeBrightContrast")
        light.inputs["Bright"].default_value = lighter
        light.inputs["Contrast"].default_value = contrast
        nt.links.new(hue.outputs[2], light.inputs[0])
        out = light.outputs[0]
    if under is not None:
        skin_img, (axis, a, z), tint = under
        uvt = nt.nodes.new("ShaderNodeTexImage")
        uvt.image = skin_img
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        nt.links.new(uvt.outputs[0], bw.inputs[0])
        tinted = nt.nodes.new("ShaderNodeMix")
        tinted.data_type = "RGBA"
        tinted.blend_type = "MULTIPLY"
        tinted.inputs["Factor"].default_value = 1.0
        tinted.inputs[6].default_value = (*tint, 1.0)
        lift = nt.nodes.new("ShaderNodeMath")
        lift.operation = "MULTIPLY_ADD"
        lift.inputs[1].default_value = 1.6
        lift.inputs[2].default_value = 0.15
        nt.links.new(bw.outputs[0], lift.inputs[0])
        nt.links.new(lift.outputs[0], tinted.inputs[7])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(geo.outputs["Position"], sep.inputs[0])
        coord = sep.outputs[axis]
        if axis == "X":
            absx = nt.nodes.new("ShaderNodeMath")
            absx.operation = "ABSOLUTE"
            nt.links.new(coord, absx.inputs[0])
            coord = absx.outputs[0]
        fac = nt.nodes.new("ShaderNodeMapRange")
        fac.interpolation_type = "SMOOTHSTEP"
        fac.inputs["From Min"].default_value = a
        fac.inputs["From Max"].default_value = z
        nt.links.new(coord, fac.inputs[0])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        nt.links.new(fac.outputs[0], mix.inputs["Factor"])
        nt.links.new(out, mix.inputs[6])
        nt.links.new(tinted.outputs[2], mix.inputs[7])
        out = mix.outputs[2]
    nt.links.new(out, b.inputs["Base Color"])
    return m


def source_image(o):
    """The base colour picture the finch part was painted with."""
    for m in o.data.materials:
        if m is None or not m.use_nodes:
            continue
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if b is None or not b.inputs["Base Color"].is_linked:
            continue
        node = b.inputs["Base Color"].links[0].from_node
        seen = [node]
        while seen:
            n = seen.pop()
            if n.type == "TEX_IMAGE" and n.image is not None:
                return n.image
            for i in n.inputs:
                for link in i.links:
                    seen.append(link.from_node)
    return None


def dress(o, mat):
    o.data.materials.clear()
    o.data.materials.append(mat)


def crown(owl, mat):
    """A rounded back of the head behind the owl's face, joined to it:
    from well inside the face (CROWN_FRONT of its depth) to CROWN_BACK
    behind the cut."""
    pts = np.array([v.co[:] for v in owl.data.vertices])
    lo, hi = pts.min(0), pts.max(0)
    w, h, depth = hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]
    back = hi[1] + CROWN_BACK
    front = lo[1] + CROWN_FRONT * depth
    rx, ry, rz = CROWN[0] * w, (back - front) / 2, CROWN[1] * h
    centre = ((lo[0] + hi[0]) / 2, (back + front) / 2, lo[2] + CROWN_MID * h)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1.0, location=centre)
    shell = bpy.context.object
    shell.scale = (rx, ry, rz)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    shell.data.materials.append(mat)
    # The face's open edge drawn in onto the crown, no gap between.
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    bm = bmesh.new()
    bm.from_mesh(owl.data)
    for v in {v for e in bm.edges if e.is_boundary for v in e.verts}:
        hit, normal, _i, dist = tree.find_nearest(v.co)
        if hit is not None and dist < CROWN_SNAP:
            v.co = hit + normal * 0.0005
    bm.to_mesh(owl.data)
    bm.free()
    bpy.ops.object.select_all(action="DESELECT")
    owl.select_set(True)
    shell.select_set(True)
    bpy.context.view_layer.objects.active = owl
    bpy.ops.object.join()


def roll_sleeves(jumper):
    """Sleeves cut off past SLEEVE_END and the edge turned out and back
    over itself into a thick cuff."""
    bm = bmesh.new()
    bm.from_mesh(jumper.data)
    mw = jumper.matrix_world
    inv = mw.inverted()
    gone = [f for f in bm.faces if any(abs((mw @ v.co).x) > SLEEVE_END for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    uv = bm.loops.layers.uv.active
    for side in (1, -1):
        edges = [e for e in bm.edges if e.is_boundary and all(side * (mw @ v.co).x > SLEEVE_END - 0.04 for v in e.verts)]
        if not edges:
            continue
        verts = {v for e in edges for v in e.verts}
        c = sum(((mw @ v.co) for v in verts), Vector()) / len(verts)
        # The knit's picture carried on past the edge, as the sleeve ran
        # into it: each boundary point's picture, and which way on the
        # picture (and how fast) the sleeve went toward it.
        uv_of, way = {}, {}
        for v in verts:
            inward = [e.other_vert(v) for e in v.link_edges if not e.is_boundary]
            face = next((f for f in v.link_faces), None)
            if face is None:
                continue
            here = next(lp for lp in face.loops if lp.vert is v)[uv].uv.copy()
            uv_of[v] = here
            way[v] = Vector((0.0, 0.0))
            if inward:
                q = inward[0]
                there = next((lp[uv].uv for f in q.link_faces if f in v.link_faces for lp in f.loops
                              if lp.vert is q), None)
                gap = ((mw @ v.co) - (mw @ q.co)).length
                if there is not None and gap > 1e-6:
                    way[v] = (here - there) / gap
        steps = [(CUFF_OUT, 0.004), (CUFF_OUT * 0.7, -CUFF), (-CUFF_OUT * 0.8, -0.004)]
        ring = edges
        src = {v: v for v in verts}
        run = {v: 0.0 for v in verts}
        for out, along in steps:
            last = {v for e in ring for v in e.verts}
            made = bmesh.ops.extrude_edge_only(bm, edges=ring)
            new_verts = [g for g in made["geom"] if isinstance(g, bmesh.types.BMVert)]
            for v in new_verts:
                prev = next(e.other_vert(v) for e in v.link_edges if e.other_vert(v) in last)
                src[v] = src[prev]
                p = mw @ v.co
                radial = Vector((0.0, p.y - c.y, p.z - c.z))
                if radial.length > 1e-6:
                    radial.normalize()
                q = p + radial * out + Vector((side * along, 0.0, 0.0))
                run[v] = run[prev] + (q - p).length
                v.co = inv @ q
            ring = [g for g in made["geom"] if isinstance(g, bmesh.types.BMEdge) and all(v in new_verts for v in g.verts)]
            for f in [g for g in made["geom"] if isinstance(g, bmesh.types.BMFace)]:
                for loop in f.loops:
                    b = src[loop.vert]
                    if b in uv_of:
                        loop[uv].uv = uv_of[b] + way[b] * run[loop.vert]
    bm.normal_update()
    bm.to_mesh(jumper.data)
    bm.free()


def forearms(hand, arm):
    """The hands' open wrists grown back along the forearm bones to just
    inside the rolled cuffs, widening a little toward the elbow, in tiers
    of feathers lying toward the hand (each tier's edge a little proud of
    the one below it, the first over the wrist)."""
    bm = bmesh.new()
    bm.from_mesh(hand.data)
    mw = hand.matrix_world
    inv = mw.inverted()
    for side, suffix in ((1, "L"), (-1, "R")):
        elbow = arm.matrix_world @ arm.data.bones["DEF_forearm_" + suffix].head_local
        edges = [e for e in bm.edges if e.is_boundary and all(side * (mw @ v.co).x > 0 for v in e.verts)]
        if not edges:
            continue
        verts = {v for e in edges for v in e.verts}
        c0 = sum(((mw @ v.co) for v in verts), Vector()) / len(verts)
        base = {}
        for v in verts:
            off = (mw @ v.co) - c0
            off.x = 0.0
            base[v] = off
        # To just past the cuff, along the bone.
        goal = c0 + (elbow - c0) * ((abs(c0.x) - (SLEEVE_END - CUFF - 0.01)) / max(abs(c0.x - elbow.x), 1e-6))
        ring = edges
        src = {v: v for v in verts}
        rings = ARM_TIERS * 3
        for i in range(1, rings + 1):
            t = i / rings
            # Within a tier: its feathers' tips (at the hand's end) stand
            # out, their roots (toward the elbow) lie in.
            u = (t * ARM_TIERS) % 1.0 if i < rings else 1.0
            size = (1.0 + 0.22 * t) * (1.0 + TIER_FLARE * (1.0 - u) ** 1.5)
            last = {v for e in ring for v in e.verts}
            made = bmesh.ops.extrude_edge_only(bm, edges=ring)
            new_verts = [g for g in made["geom"] if isinstance(g, bmesh.types.BMVert)]
            centre = c0.lerp(goal, t)
            for v in new_verts:
                prev = next(e.other_vert(v) for e in v.link_edges if e.other_vert(v) in last)
                src[v] = src[prev]
                v.co = inv @ (centre + base[src[v]] * size)
            ring = [g for g in made["geom"] if isinstance(g, bmesh.types.BMEdge) and all(v in new_verts for v in g.verts)]
    bm.normal_update()
    bm.to_mesh(hand.data)
    bm.free()


def feathered_shins(feet):
    """Owls' legs are feathered to the toes: the shins made full, even
    tubes of ruffled feathers (no thin bird's leg with its knobbly
    joint), from the ankle up."""
    mw = feet.matrix_world
    inv = mw.inverted()
    pts = np.array([mw @ v.co for v in feet.data.vertices])
    rng = np.random.default_rng(3)
    ruffle = rng.uniform(-1.0, 1.0, (2, 12))
    for side in (1, -1):
        mine = [i for i, p in enumerate(pts) if side * p[0] > 0 and p[2] > ANKLE]
        if not mine:
            continue
        zs = pts[mine, 2]
        bins = np.linspace(zs.min(), zs.max() + 1e-6, 24)
        for i in mine:
            p = pts[i]
            k = np.searchsorted(bins, p[2])
            ring = [j for j in mine if bins[max(k - 1, 0)] <= pts[j, 2] <= bins[min(k, len(bins) - 1)]]
            c = pts[ring].mean(0)
            d = Vector((p[0] - c[0], p[1] - c[1], 0.0))
            if d.length < 1e-6:
                continue
            ang = math.atan2(d.y, d.x)
            t = min(max((p[2] - ANKLE) / (0.36 - ANKLE), 0.0), 1.0)
            ease = min((p[2] - ANKLE) / 0.03, 1.0)
            fluff = 1.0 + FLUFF * sum(ruffle[(side + 1) // 2, n] * math.sin((n + 2) * ang + n) / (n + 2)
                                      for n in range(12))
            # Tiers of feathers, each one's tips (its lower edge) proud.
            u = ((p[2] - ANKLE) / LEG_TIER) % 1.0
            r = (SHIN[0] + (SHIN[1] - SHIN[0]) * t) * fluff * (1.0 + TIER_FLARE * (1.0 - u) ** 1.5)
            r = d.length + (r - d.length) * ease
            d.normalize()
            q = Vector((c[0], c[1], p[2])) + d * r
            feet.data.vertices[i].co = inv @ q
    feet.data.update()


def rig(o, arm, group_name):
    group = o.vertex_groups.new(name=group_name)
    group.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    md = o.modifiers.new("Armature", "ARMATURE")
    md.object = arm
    o.data.shade_smooth()


# ---------------------------------------------------------------- previews

def previews():
    sc = bpy.context.scene
    for o in sc.objects:
        for md in o.modifiers:
            if md.type == "PARTICLE_SYSTEM":
                md.show_render = False
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    # The source's compositor writes renders to its author's own folders.
    sc.use_nodes = False
    shots = [("Camera_80mm_body_front", "front", (540, 720)), ("Camera_80mm_body_3/4", "three", (540, 720)),
             ("Camera_135mm_face_front", "face", (600, 600)), ("Camera_135mm_face_side", "side", (600, 600))]
    for name, at, frm in (("arm", (0.42, 0.03, 0.77), (0.42, -0.45, 0.85)), ("legs", (0.0, 0.0, 0.2), (0.25, -0.75, 0.35))):
        cd = bpy.data.cameras.new(name)
        cd.lens = 85
        cam = bpy.data.objects.new(name, cd)
        sc.collection.objects.link(cam)
        cam.location = frm
        cam.rotation_euler = (Vector(at) - Vector(frm)).to_track_quat("-Z", "Y").to_euler()
        shots.append((name, name, (600, 600)))
    for cam, name, res in shots:
        sc.camera = bpy.data.objects[cam]
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.filepath = "%s_%s.png" % (PREVIEW, name)
        bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    for name in OFF:
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    jumper = bpy.data.objects["finch_jumper"]
    owl_png = os.path.join(os.path.dirname(BIRD), "Owl.png")
    grey = patch(owl_png, GREY_PATCH, "owl_grey")
    owl = cut_head(BIRD)
    axis = place(owl, arm)
    # The back of the head and the ruff in one: the one picture over both
    # in world space, so no seam where the ruff comes out from under it.
    plumage = feathers("owl_plumage", grey, FEATHER_SCALE)
    crown(owl, plumage)
    roll_sleeves(jumper)
    ruff_ob, height, centre = ruff(owl, jumper, axis, plumage)
    tuck(owl, height, centre)
    rig(owl, arm, "DEF_head")
    rig(ruff_ob, arm, "DEF_head")
    hand = bpy.data.objects["finch_hand"]
    feet = bpy.data.objects["finch_feet"]
    hand_skin = source_image(hand)
    feet_skin = source_image(feet)
    forearms(hand, arm)
    feathered_shins(feet)
    dress(hand, feathers("owl_hand", grey, 8.0, under=[hand_skin, ("X", 0.545, 0.575), (0.32, 0.27, 0.22)]))
    dress(feet, feathers("owl_feet", grey, 10.0, under=[feet_skin, ("Z", 0.05, 0.03), (0.3, 0.27, 0.22)],
                         tint=LEG_TINT))
    bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=True)
    if PREVIEW:
        previews()


main()
