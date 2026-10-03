"""The greybox animal people (tools/greybox_animals.py) in the game's own
use, checked frame by frame (user request, round 3: the clips the game
plays first - run, cast, idle and holding the rod - judged by what comes
through the clothes AND how the clothes deform, from the game's own
cameras, with the rod in the hand):

  sheet   the player's sprite sheet as tools/render_player.py makes it:
          Mixamo's clips, the feet drawn in (owl_character.close_stance),
          composed into the game's clips (idle, run, cast, hold, busy,
          reel, fight, hold_run), 8 frames each - every one of those 64
          frames measured; seen from the sheet's camera (orthographic,
          55 degrees up) in its 8 facings; the cast with the shop's rod
          in the hand where the game draws it (the left palm, at
          render_player.ROD_ANGLES).
  camp    the camp's 3D character (UAL skeleton) in the clips the camp
          plays (scripts/camp_life.gd) - idle, walk, sitting and the
          crouch at the fish trough - 16 evenly spaced frames of each
          (the camp plays them live, so there is no final frame list),
          seen from the camp's home camera (scripts/camp_stage.gd).

Measured for each frame, each apart:
  body      body points the clothes covered in the bind pose now outside
            both garments: count, depth and area (estimates), and how many
            of them each game camera sees;
  shorts    the shorts' points under the jumper now outside it;
  cloth     the clothes' own deformation: how far the jumper's hem
            overlaps the shorts' waistband all round (and the least,
            where), how far the hem has risen against the hips, each
            turned-back cuff's cross-section against its rest, the
            share of the shorts' and the jumper's surface stretched or
            squeezed by more than a quarter (area_share_*), and apart
            from it how far the most stretched part goes (stretch_p95,
            stretch_max: a face's area over its rest area);
  crossing  body triangles crossing the clothes' triangles (all of the
            body, openings included): the count, and against the bind
            pose's own which are new (and where) and which have gone -
            new ones never netted against gone ones.
The body points inside the clothes but past the 3.5 cm reach (never
checked - "inside_beyond_reach") are listed by region and marked on the
bind pose (ANIMAL_TAG_blind_front/back.png).

    bpyenv/bin/python tools/greybox_game.py -- sheet ANIMAL GB_DIR OUT_DIR MIXAMO_DIR [TAG]
    bpyenv/bin/python tools/greybox_game.py -- camp ANIMAL GB_DIR OUT_DIR UAL1.glb UAL2.glb [TAG]
(GB_GARMENT_WEIGHTS=0 binds the clothes with the body's weights as
copied, unadjusted - the before of the comparison; GB_GRIP=1 measures the
sheet with the candidate's hand on the rod, render_player.py --grip.)
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
import greybox_review as gr  # noqa: E402
import owl_character as oc  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FUR, SKIN, HORN, EYE, KNIT, CLOTH, BUTTON, SCARF, PAD = range(9)
BODY = (FUR, PAD, HORN)

# The sprite sheet's camera (tools/render_sprite.py): orthographic, 55
# degrees above the horizontal, looking toward +Y; the model turned to
# each facing (degrees about Z).
SPRITE_ELEV = 55.0
FACINGS = {"down": 0.0, "down_right": 45.0, "right": 90.0, "up_right": 135.0,
           "up": 180.0, "up_left": -135.0, "left": -90.0, "down_left": -45.0}
# How the game plays the sheet's clips (scripts/player_visual.gd FPS;
# the cast's first four frames follow the charge, the last four go by in
# WHIP_TIME).
SHEET_FPS = {"idle": 2.5, "run": 10.9, "cast": None, "hold": 3.0, "busy": 6.0, "reel": 14.0, "fight": 16.0,
             "hold_run": 10.9}
WHIP_TIME = 0.3
# The camp (scripts/camp_stage.gd; Godot's x, y, z): the home camera and
# where the character stands for each clip, and its turn.
CAMP_CAMERA = ((0.3, 2.3, 6.9), (-0.15, 0.75, -2.2), 42.0)
CAMP_SPOTS = {"idle": ((-0.35, 0.0, 0.6), 0.35), "walk": ((-0.35, 0.0, 0.6), 0.35),
              "sit": ((-0.35, 0.0, 0.6), 0.35), "crouch": ((2.52, 0.0, 0.4), math.pi / 2)}
CAMP_CLIPS = [("idle", "Idle_Loop"), ("walk", "Walk_Loop"), ("sit", "Sitting_Idle_Loop"),
              ("crouch", "Crouch_Idle_Loop")]
CAMP_STEPS = 16
# The game's rod (assets/models: 6 m along +Y, the grip at the origin).
ROD_MODEL = os.path.join(ROOT, "assets", "models", "fishing_rod_lvl1.glb")


def godot_to_blender(p):
    return Vector((p[0], -p[2], p[1]))


# ---------------------------------------------------------------- rest

class Rest:
    """What a frame is measured against: the bind pose's points, the
    covered set, the rings (the jumper's hem, the shorts' waistband, each
    cuff), the faces' areas, the bones' rest matrices."""

    def __init__(self, mesh, arm, joints, rig, bones):
        self.mesh, self.arm, self.joints, self.rig = mesh, arm, joints, rig
        self.covered, _ = gr.poke(mesh, None)
        co, faces, fz, vz = gr.zones(mesh)
        self.co, self.faces, self.fz, self.vz = co, faces, fz, vz
        self.tri = triangles(faces)
        self.tri_z = np.repeat(fz, [len(f) - 2 for f in faces])
        self.area = tri_area(co, self.tri)
        j = np.where(vz == KNIT)[0]
        t = np.where(vz == CLOTH)[0]
        hem = co[j, 2].min()
        self.hem = j[co[j, 2] < hem + 0.012]
        top = co[t, 2].max()
        self.waist = t[co[t, 2] > top - 0.010]
        sh = Vector(joints["shoulder"])
        el = Vector(joints["elbow"])
        ax = (el - sh).normalized()
        self.cuffs = {}
        for side, sg in (("l", 1.0), ("r", -1.0)):
            q = np.array([[abs(c[0]), c[1], c[2]] for c in co[j]])
            along = (q - np.array(sh)) @ np.array(ax)
            mine = (co[j, 0] * sg > sh.x * 0.8)
            end = along[mine].max()
            self.cuffs[side] = j[mine & (along > end - 0.026)]
        self.bones = bones
        self.mat = {b: (arm.matrix_world @ arm.pose.bones[b].matrix).copy() for b in bones}
        self.ring_rest = {"hem": co[self.hem], "waist": co[self.waist]}
        pel = self.mat[bones[0]].translation
        self.pelvis_xy = np.array([pel.x, pel.y])
        self.cuff_rest = {s: cross_section(co[i], self.mat[self.cuff_bone(s)]) for s, i in self.cuffs.items()}
        self.body_faces = [f for f, z in zip(faces, fz) if z in BODY]
        bt = BVHTree.FromPolygons([Vector(c) for c in co], self.body_faces)
        gt = BVHTree.FromPolygons([Vector(c) for c in co], [f for f, z in zip(faces, fz) if z in (KNIT, CLOTH)])
        # which body triangles cross the clothes at the bind pose (a frame's
        # new crossings are told from these, not netted against them)
        self.cross0 = {a for a, b in bt.overlap(gt)}
        self.crossing0 = len(self.cross0)
        # the 3.5 cm reach of "covered": the body's points inside the clothes
        # but further than that from them (never checked) - and where they are
        body = np.where(np.isin(vz, BODY))[0]
        inj = gr.inside(co, faces, fz, KNIT, co[body])
        intr = gr.inside(co, faces, fz, CLOTH, co[body])
        self.inside_all = int((inj | intr).sum())
        cov = set(np.asarray(self.covered["body"]).tolist())
        self.beyond = np.array(sorted(set(body[inj | intr].tolist()) - cov), dtype=int)
        self.beyond_where = gr.regions(co, self.beyond, joints) if len(self.beyond) else {}
        # the clothes' real openings: their rims (edges of one face only),
        # where a body point may come out without coming through
        import collections
        cnt = collections.Counter()
        for fc, z in zip(faces, fz):
            if z in (KNIT, CLOTH):
                for i in range(len(fc)):
                    cnt[tuple(sorted((fc[i], fc[(i + 1) % len(fc)])))] += 1
        self.rims = np.array(sorted({v for e, n_ in cnt.items() if n_ == 1 for v in e}), dtype=int)
        # tiny faces at rest (their stretch ratio means nothing): under a
        # hundredth of the clothes' median face
        self.tiny_area = float(np.median(self.area[np.isin(self.tri_z, (KNIT, CLOTH))])) * 0.01

    def cuff_bone(self, side):
        return self.bones[1] if side == "l" else self.bones[2]


def triangles(faces):
    out = []
    for f in faces:
        for i in range(1, len(f) - 1):
            out.append((f[0], f[i], f[i + 1]))
    return np.array(out)


def tri_area(co, tri):
    a, b, c = co[tri[:, 0]], co[tri[:, 1]], co[tri[:, 2]]
    return 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)


def cross_section(pts, mat):
    """The ring's cross-section in the bone's frame (perpendicular to the
    bone): its area (convex hull) and how round it is (least / most
    spread)."""
    from scipy.spatial import ConvexHull
    inv = mat.inverted()
    loc = np.array([(inv @ Vector(p))[:] for p in pts])
    # the bone's own Y runs along it
    xz = loc[:, [0, 2]]
    xz = xz - xz.mean(axis=0)
    if len(xz) < 4:
        return 0.0, 0.0
    area = ConvexHull(xz).volume
    sv = np.linalg.svd(xz, compute_uv=False)
    return float(area), float(sv[-1] / max(sv[0], 1e-9))


def to_rest(points, posed, rest):
    """Points carried back by the change in one bone: its rest matrix
    times the inverse of its posed one."""
    m = rest @ posed.inverted()
    return np.array([(m @ Vector(p))[:] for p in points])


# ---------------------------------------------------------------- frame

def measure(rest, looks):
    """One posed frame against the bind pose; `looks` {name: ('dir', v) or
    ('pos', p)} the cameras whose sight of the points through is counted."""
    mesh, arm = rest.mesh, rest.arm
    res, co = gr.poke(mesh, rest.covered)
    sm = gr.summary(res, rest.co, rest.joints)
    out = {"body": sm["body"], "shorts": sm["shorts"],
           "where": {r: {k: v[k] for k in ("points", "depth_max_mm", "area_cm2")} for r, v in sm["where"].items()}}
    # what the game's cameras see of them
    tree = BVHTree.FromPolygons([Vector(c) for c in co], rest.faces, all_triangles=False)
    nm = gr.NORMALS["n"]
    seen = {}
    for name, (kind, v) in looks.items():
        n = 0
        for i in res["body"]:
            p = Vector(co[i])
            d = Vector(v) if kind == "dir" else (Vector(v) - p)
            if d.length < 1e-9:
                continue
            d.normalize()
            if Vector(nm[i]).dot(d) <= 0.0:
                continue
            hit = tree.ray_cast(p + d * 2e-4, d)
            if hit[0] is None or (kind == "pos" and (hit[0] - p).length > (Vector(v) - p).length):
                n += 1
        seen[name] = n
    out["seen"] = seen
    out["seen_max"] = max(seen.values()) if seen else 0
    # the clothes' own shape
    mats = {b: (arm.matrix_world @ arm.pose.bones[b].matrix).copy() for b in rest.bones}
    pel = rest.bones[0]
    hem = to_rest(co[rest.hem], mats[pel], rest.mat[pel])
    waist = to_rest(co[rest.waist], mats[pel], rest.mat[pel])
    out["cloth"] = cloth(rest, hem, waist, co, mats)
    # crossing triangles
    bt = BVHTree.FromPolygons([Vector(c) for c in co], [f for f, z in zip(rest.faces, rest.fz) if z in BODY])
    gt = BVHTree.FromPolygons([Vector(c) for c in co], [f for f, z in zip(rest.faces, rest.fz) if z in (KNIT, CLOTH)])
    out["blind"] = blind_check(rest, co, looks)
    cross = {a for a, b in bt.overlap(gt)}
    new = sorted(cross - rest.cross0)
    out["crossing"] = len(cross)
    out["crossing_new"] = len(new)
    out["crossing_gone"] = len(rest.cross0 - cross)
    out["crossing_new_where"] = gr.regions(rest.co, np.array([rest.body_faces[i][0] for i in new], dtype=int),
                                           rest.joints) if new else {}
    return out, res, co


# A body point out of the clothes this close to an opening's rim (m) came
# out of the opening, not through the cloth.
RIM_NEAR = 0.015


def blind_check(rest, co, looks):
    """The points the 3.5 cm reach leaves out (inside the clothes at rest,
    further than that from them), checked too (user request, round 5): out
    of both garments now - by an opening (within RIM_NEAR of a rim) or
    through the cloth - where, how deep and how many the game's cameras see."""
    if not len(rest.beyond):
        return {"checked": 0, "through": 0, "by_opening": 0}
    faces, fz = rest.faces, rest.fz
    pts = co[rest.beyond]
    ins = gr.inside(co, faces, fz, KNIT, pts) | gr.inside(co, faces, fz, CLOTH, pts)
    out_idx = rest.beyond[~ins]
    res = {"checked": int(len(rest.beyond)), "through": 0, "by_opening": 0}
    if not len(out_idx):
        return res
    from scipy.spatial import cKDTree
    rim = cKDTree(co[rest.rims])
    d, _ = rim.query(co[out_idx])
    thr = out_idx[d > RIM_NEAR]
    res["by_opening"] = int((d <= RIM_NEAR).sum())
    res["through"] = int(len(thr))
    if len(thr):
        sel = [f for f, z in zip(faces, fz) if z in (KNIT, CLOTH)]
        tree = BVHTree.FromPolygons([Vector(c) for c in co], sel, all_triangles=False)
        depth = [tree.find_nearest(Vector(co[i]))[3] for i in thr]
        res["through_where"] = gr.regions(rest.co, thr, rest.joints)
        res["through_depth_max_mm"] = round(float(max(depth)) * 1000, 1)
        allt = BVHTree.FromPolygons([Vector(c) for c in co], rest.faces, all_triangles=False)
        nm = gr.NORMALS["n"]
        seen = 0
        for name, (kind, v) in looks.items():
            n_ = 0
            for i in thr:
                p = Vector(co[i])
                dv = Vector(v) if kind == "dir" else (Vector(v) - p)
                if dv.length < 1e-9:
                    continue
                dv.normalize()
                if Vector(nm[i]).dot(dv) <= 0.0:
                    continue
                if allt.ray_cast(p + dv * 2e-4, dv)[0] is None:
                    n_ += 1
            seen = max(seen, n_)
        res["through_seen_max"] = seen
        res["through_points"] = [int(i) for i in thr[:400]]
    return res


def cloth(rest, hem, waist, co, mats):
    """The hem over the waistband, round the body in 24 bins (by angle
    about the hips; 0 = the front), the hem's rise, the cuffs' sections,
    the stretch."""
    def bins(pts):
        a = np.degrees(np.arctan2(pts[:, 0] - rest.pelvis_xy[0], -(pts[:, 1] - rest.pelvis_xy[1])))
        return ((a + 180.0) // 15.0).astype(int) % 24
    hb, wb = bins(hem), bins(waist)
    hb0, wb0 = bins(rest.ring_rest["hem"]), bins(rest.ring_rest["waist"])
    over, over0 = [], []
    for b in range(24):
        if (hb == b).any() and (wb == b).any():
            over.append((waist[wb == b, 2].max() - hem[hb == b, 2].min(), b))
        if (hb0 == b).any() and (wb0 == b).any():
            over0.append(rest.ring_rest["waist"][wb0 == b, 2].max() - rest.ring_rest["hem"][hb0 == b, 2].min())
    least, where = min(over) if over else (0.0, 0)
    angle = where * 15.0 - 180.0 + 7.5
    out = {"hem_overlap_min_mm": round(least * 1000, 1), "hem_overlap_rest_min_mm": round(min(over0) * 1000, 1),
           "hem_overlap_where_deg": round(angle, 1),
           "hem_rise_mm": round(float((hem[:, 2] - rest.ring_rest["hem"][:, 2]).mean()) * 1000, 1)}
    for s, idx in rest.cuffs.items():
        a, r = cross_section(co[idx], mats[rest.cuff_bone(s)])
        a0, r0 = rest.cuff_rest[s]
        out["cuff_%s_area" % s] = round(a / max(a0, 1e-9), 3)
        out["cuff_%s_round" % s] = round(r / max(r0, 1e-9), 3)
    area = tri_area(co, rest.tri)
    for zone, name in ((CLOTH, "shorts"), (KNIT, "jumper")):
        m = rest.tri_z == zone
        ratio = area[m] / np.maximum(rest.area[m], 1e-12)
        w = rest.area[m] / rest.area[m].sum()
        # (named apart, user request round 4: the share of the area
        # stretched past 25% is not how far the most stretched part goes)
        out["%s_area_share_stretched_over_25pct" % name] = round(float(w[ratio > 1.25].sum()), 4)
        out["%s_area_share_squeezed_over_25pct" % name] = round(float(w[ratio < 0.75].sum()), 4)
        # (per face, not weighted by area)
        out["%s_stretch_p95" % name] = round(float(np.percentile(ratio, 95)), 3)
        # (weighted by area: the stretch 95% of the cloth's surface is under)
        order = np.argsort(ratio)
        cw = np.cumsum(w[order])
        out["%s_stretch_p95_area" % name] = round(float(ratio[order][np.searchsorted(cw, 0.95)]), 3)
        out["%s_stretch_max" % name] = round(float(ratio.max()), 3)
        # the tiny faces (rest area under rest.tiny_area): kept apart, not
        # dropped - how many, how much cloth, the most stretched of them and
        # the most stretched of the rest, and where each is
        tiny = rest.area[m] < rest.tiny_area
        tri = rest.tri[m]
        out["%s_tiny_faces" % name] = int(tiny.sum())
        out["%s_tiny_area_share" % name] = round(float(w[tiny].sum()), 6)
        for key, sel in (("tiny", tiny), ("rest", ~tiny)):
            if sel.any():
                k = int(np.argmax(np.where(sel, ratio, -1.0)))
                out["%s_stretch_max_%s" % (name, key)] = round(float(ratio[k]), 3)
                out["%s_stretch_max_%s_at" % (name, key)] = [round(float(v), 4) for v in rest.co[tri[k]].mean(axis=0)]
                out["%s_stretch_max_%s_rest_mm2" % (name, key)] = round(float(rest.area[m][k]) * 1e6, 4)
    return out


# ---------------------------------------------------------------- views

def sprite_camera(cz=0.55, scale=1.45, res=(360, 400)):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("sprite")
    cd.type = "ORTHO"
    cd.ortho_scale = scale
    cam = bpy.data.objects.new("sprite", cd)
    sc.collection.objects.link(cam)
    e = math.radians(SPRITE_ELEV)
    cam.location = Vector((0.0, -6.0 * math.cos(e), cz + 6.0 * math.sin(e)))
    cam.rotation_euler = (math.radians(90.0 - SPRITE_ELEV), 0.0, 0.0)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    return cam


def sprite_looks():
    """Each facing's camera direction in the model's own frame (the model
    turns by the facing, so the camera turns the other way)."""
    e = math.radians(SPRITE_ELEV)
    d = Vector((0.0, -math.cos(e), math.sin(e)))
    return {f: ("dir", Matrix.Rotation(math.radians(-deg), 3, "Z") @ d) for f, deg in FACINGS.items()}


def shoot(path, piv, deg):
    piv.rotation_euler = (0, 0, math.radians(deg))
    bpy.context.view_layer.update()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    piv.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()


def marks(piv, res, co):
    pts = np.concatenate([co[res["body"]], co[res["shorts"]]]) if len(res["shorts"]) else co[res["body"]]
    if not len(pts):
        return None
    mk = gr.markers(pts[:: max(1, len(pts) // 300)], r=0.007)
    mk.parent = piv
    mk.matrix_parent_inverse = piv.matrix_world.inverted()
    return mk


def strip(paths, out, cols=8):
    from PIL import Image
    ims = [Image.open(p).convert("RGB") for p in paths]
    w, h = ims[0].size
    W = Image.new("RGB", (w * min(cols, len(ims)), h * ((len(ims) + cols - 1) // cols)))
    for i, im in enumerate(ims):
        W.paste(im, ((i % cols) * w, (i // cols) * h))
    W.save(out)
    for p in paths:
        os.remove(p)


# ---------------------------------------------------------------- rod

def load_rod():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ROD_MODEL)
    objs = [o for o in set(bpy.data.objects) - before]
    holder = bpy.data.objects.new("rod", None)
    bpy.context.scene.collection.objects.link(holder)
    for o in objs:
        if o.parent is None:
            o.parent = holder
    meshes = [o for o in objs if o.type == "MESH"]
    # its grip's girth, the median of the 30 cm above the grip point (the
    # importer turns Godot's +Y, the rod's length, to Blender's +Z)
    vs = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    grip = sorted(math.hypot(v.x, v.y) for v in vs if 0.0 <= v.z < 0.3)
    r = grip[len(grip) // 2] if grip else 0.03
    return holder, meshes, r


def place_rod(holder, grip, tip):
    """The rod's model (its length along +Z as imported) from the grip
    toward the tip, scaled to the grip-to-tip length (its 6 m)."""
    d = (tip - grip)
    L = d.length
    z = d.normalized()
    x = z.cross(Vector((0, 0, 1)))
    if x.length < 1e-6:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = grip
    holder.matrix_world = m @ Matrix.Scale(L / 6.0, 4)
    bpy.context.view_layer.update()


def rod_and_hand(co, vz, hand, grip, tip, r, tips):
    """How the rod sits in the hand: the hand's points inside the grip's
    girth (the rod through the palm), the body's and clothes' points other
    than the hand's inside it (the rod through the arm or body), and how
    far each finger's tip is from the rod's axis."""
    a, b = np.array(grip[:]), np.array(tip[:])
    ab = b - a
    t = np.clip(((co - a) @ ab) / (ab @ ab), 0.0, 1.0)
    d = np.linalg.norm(co - (a + t[:, None] * ab), axis=1)
    near = d < r
    in_hand = int((near & hand).sum())
    others = int((near & ~hand & np.isin(vz, list(BODY) + [KNIT, CLOTH])).sum())
    fingers = {}
    for n, p in tips.items():
        q = np.array(p[:])
        tt = np.clip(((q - a) @ ab) / (ab @ ab), 0.0, 1.0)
        fingers[n] = round(float(np.linalg.norm(q - (a + tt * ab))) * 1000, 1)
    return {"hand_points_inside_grip": in_hand, "other_points_inside_rod": others, "finger_tip_to_axis_mm": fingers}


# ---------------------------------------------------------------- sheet

def sheet(animal, gb_dir, out, mixamo, tag="r3"):
    import render_player as rp
    files = (os.path.join(gb_dir, animal + "_greybox.glb"), os.path.join(gb_dir, animal + "_greybox.json"))
    with open(files[1]) as fh:
        joints = json.load(fh)
    arm, _, src = rp.load(mixamo)
    hips = (arm.matrix_world @ arm.data.bones["mixamorig:Hips"].head_local).z
    k = oc._scale(hips, joints)
    mesh = oc.bind(arm, "mixamo", animal, files=files)[0]
    oc.close_stance(arm, "mixamo", list(src.values()), standing=[src["idle"]], character=animal, files=files)
    clips = rp.build_clips(arm, src)
    # GB_GRIP=1: the candidate's hand on the rod (render_player.py --grip)
    grip = os.environ.get("GB_GRIP") == "1"
    if grip:
        rp.grip_clips(arm, mesh, clips, animal)
    piv = gr.pivot_all([arm])
    piv.scale = (1.0 / k,) * 3
    gr.stage(res=360, samples=12, frame=1.45, look_z=0.55)
    rig = oc.RIGS["mixamo"]
    ad = arm.animation_data
    ad.action = None
    for t in ad.nla_tracks:
        t.mute = True
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    bones = [rig["trunk"][0], rig["limb"]("l", "Arm"), rig["limb"]("r", "Arm")]
    rest = Rest(mesh, arm, joints, rig, bones)
    looks = sprite_looks()
    # the left hand's points (the rod's) and its fingertips' bones
    vg = {g.index: g.name for g in mesh.vertex_groups}
    hand_names = {n for n in vg.values() if n.startswith("mixamorig:LeftHand")}
    hand = np.array([any(vg[g.group] in hand_names and g.weight > 0.5 for g in v.groups) for v in mesh.data.vertices])
    rod, rod_meshes, rod_r = load_rod()
    rod.hide_render = True
    for o in rod_meshes:
        o.hide_render = True
    report = {"animal": animal, "skeleton": "mixamo (render_player.py)", "k": k,
              "covered_body": int(len(rest.covered["body"])), "inside_beyond_reach": int(len(rest.beyond)),
              "inside_beyond_reach_where": rest.beyond_where,
              "sampling": "every frame the game shows (8 per clip) from all 8 facings",
              "grip": "candidate (rod_grip.py)" if grip else "current",
              "crossing_rest": rest.crossing0, "garment_weights": os.environ.get("GB_GARMENT_WEIGHTS", "1") != "0",
              "clips": {}}
    shots = os.environ.get("GB_SHOTS", "1") != "0"
    if shots and len(rest.beyond):
        # where the 3.5 cm reach doesn't look (user request, round 4): the
        # bind pose with those points marked, front and back
        piv.rotation_euler = (0, 0, 0)
        bpy.context.view_layer.update()
        mk = gr.markers(rest.co[rest.beyond][:: max(1, len(rest.beyond) // 400)], r=0.006)
        mk.parent = piv
        mk.matrix_parent_inverse = piv.matrix_world.inverted()
        for v, deg in (("front", 0.0), ("back", 180.0)):
            shoot(os.path.join(out, "%s_%s_blind_%s.png" % (animal, tag, v)), piv, deg)
        bpy.data.objects.remove(mk, do_unlink=True)
    for name in ("run", "cast", "idle", "hold", "reel", "fight", "hold_run", "busy"):
        frames = []
        for f in range(1, rp.FRAMES + 1):
            piv.rotation_euler = (0, 0, 0)
            rp.rs.set_pose(clips[name], f)
            m, res, co = measure(rest, looks)
            m["frame"] = f
            fps = SHEET_FPS[name]
            m["time_s"] = round((f - 1) / fps, 3) if fps else (None if f <= 4 else round((f - 5) * WHIP_TIME / 4, 3))
            if name in rp.HAND_CLIPS:
                grip, tip = rod_ends(arm, rp, name, f, k)
                m["rod"] = rod_and_hand(co, rest.vz, hand, grip, tip, rod_r * (rp.ROD_TIP / 6.0) / k, finger_tips(arm))
            frames.append(m)
        worst = max(frames, key=lambda m: (m["seen_max"], m["body"]["points"]))
        report["clips"][name] = {"frames": frames, "worst_frame": worst["frame"]}
        if not shots:
            continue
        # the worst frame, clean and marked, from the facing seeing most
        f = worst["frame"]
        rp.rs.set_pose(clips[name], f)
        facing = max(worst["seen"], key=worst["seen"].get) if worst["seen_max"] else "down_right"
        cam = sprite_camera()
        res, co = gr.poke(mesh, rest.covered)
        for kind in ("clean", "marked"):
            mk = marks(piv, res, co) if kind == "marked" else None
            shoot(os.path.join(out, "%s_%s_sheet_%s_worst_%s.png" % (animal, tag, name, kind)), piv, FACINGS[facing])
            if mk is not None:
                bpy.data.objects.remove(mk, do_unlink=True)
        report["clips"][name]["worst_facing"] = facing
        # all 8 frames, clean, from the front-right (and the cast with its rod)
        paths = []
        for f in range(1, rp.FRAMES + 1):
            rp.rs.set_pose(clips[name], f)
            if name in rp.HAND_CLIPS:
                grip, tip = rod_ends(arm, rp, name, f, k)
                place_rod(rod, grip, tip)
                for o in rod_meshes:
                    o.hide_render = False
            p = os.path.join(out, "_%s_f%d.png" % (animal, f))
            shoot(p, piv, FACINGS["down_right"])
            paths.append(p)
        strip(paths, os.path.join(out, "%s_%s_sheet_%s_strip.png" % (animal, tag, name)))
        for o in rod_meshes:
            o.hide_render = True
        bpy.data.objects.remove(cam, do_unlink=True)
        if name == "cast":
            # the hand on the rod, close, every frame
            paths = []
            for f in range(1, rp.FRAMES + 1):
                rp.rs.set_pose(clips[name], f)
                grip, tip = rod_ends(arm, rp, name, f, k)
                place_rod(rod, grip, tip)
                for o in rod_meshes:
                    o.hide_render = False
                p = os.path.join(out, "_%s_h%d.png" % (animal, f))
                d = Vector((0.5, -1.0, 0.35))
                gr.close(p, grip, d, scale=0.30, res=300)
                paths.append(p)
            strip(paths, os.path.join(out, "%s_%s_sheet_cast_hand.png" % (animal, tag)))
            for o in rod_meshes:
                o.hide_render = True
    with open(os.path.join(out, "%s_%s_sheet.json" % (animal, tag)), "w") as fh:
        json.dump(report, fh, indent=1)
    summary_print(report)


def rods(animal, gb_dir, out, mixamo, tag="r3"):
    """The rod in the hand only (the sheet's five clips that hold it):
    where it sits against the hand and body each frame, the clips' strips
    with it, and the hand close up through the cast."""
    import render_player as rp
    files = (os.path.join(gb_dir, animal + "_greybox.glb"), os.path.join(gb_dir, animal + "_greybox.json"))
    with open(files[1]) as fh:
        joints = json.load(fh)
    arm, _, src = rp.load(mixamo)
    hips = (arm.matrix_world @ arm.data.bones["mixamorig:Hips"].head_local).z
    k = oc._scale(hips, joints)
    mesh = oc.bind(arm, "mixamo", animal, files=files)[0]
    oc.close_stance(arm, "mixamo", list(src.values()), standing=[src["idle"]], character=animal, files=files)
    clips = rp.build_clips(arm, src)
    piv = gr.pivot_all([arm])
    piv.scale = (1.0 / k,) * 3
    gr.stage(res=360, samples=12, frame=1.45, look_z=0.55)
    vg = {g.index: g.name for g in mesh.vertex_groups}
    hand_names = {n for n in vg.values() if n.startswith("mixamorig:LeftHand")}
    hand = np.array([any(vg[g.group] in hand_names and g.weight > 0.5 for g in v.groups) for v in mesh.data.vertices])
    rod, rod_meshes, rod_r = load_rod()
    r = rod_r * (rp.ROD_TIP / 6.0) / k
    report = {"animal": animal, "grip_radius_mm": round(r * 1000, 1), "clips": {}}
    cam = sprite_camera()
    for name in ("cast", "hold", "reel", "fight", "hold_run"):
        frames, paths = [], []
        for f in range(1, rp.FRAMES + 1):
            piv.rotation_euler = (0, 0, 0)
            rp.rs.set_pose(clips[name], f)
            bpy.context.view_layer.update()
            co, faces, fz, vz = gr.zones(mesh)
            grip, tip = rod_ends(arm, rp, name, f, k)
            m = rod_and_hand(co, vz, hand, grip, tip, r, finger_tips(arm))
            m["frame"] = f
            frames.append(m)
            place_rod(rod, grip, tip)
            p = os.path.join(out, "_%s_f%d.png" % (animal, f))
            shoot(p, piv, FACINGS["down_right"])
            paths.append(p)
        strip(paths, os.path.join(out, "%s_%s_sheet_%s_strip.png" % (animal, tag, name)))
        report["clips"][name] = frames
        if name == "cast":
            paths = []
            for f in range(1, rp.FRAMES + 1):
                rp.rs.set_pose(clips[name], f)
                grip, tip = rod_ends(arm, rp, name, f, k)
                place_rod(rod, grip, tip)
                p = os.path.join(out, "_%s_h%d.png" % (animal, f))
                gr.close(p, grip + (tip - grip) * 0.12, Vector((0.5, -1.0, 0.35)), scale=0.42, res=300)
                paths.append(p)
            strip(paths, os.path.join(out, "%s_%s_sheet_cast_hand.png" % (animal, tag)))
    with open(os.path.join(out, "%s_%s_rod.json" % (animal, tag)), "w") as fh:
        json.dump(report, fh, indent=1)
    for name, fr in report["clips"].items():
        print(animal, name, "palm", [m["hand_points_inside_grip"] for m in fr], "other",
              [m["other_points_inside_rod"] for m in fr])


def rod_ends(arm, rp, name, f, k):
    """Where render_player.py puts the rod in this frame (the model faced
    down): its grip at the left palm, its tip ROD_TIP on at the frame's
    angle."""
    mw = arm.matrix_world
    bones = arm.pose.bones
    hand = bones["mixamorig:LeftHand"]
    grip = (mw @ hand.head + mw @ bones["mixamorig:LeftHandMiddle1"].head) * 0.5
    up = math.radians(rp.ROD_ANGLES[name][f - 1])
    side = math.radians(rp.ROD_SIDE)
    local = Vector((math.sin(side) * math.cos(up), -math.cos(side) * math.cos(up), math.sin(up)))
    return grip, grip + local * (rp.ROD_TIP / k)


def finger_tips(arm):
    mw = arm.matrix_world
    out = {}
    for f in ("Thumb", "Index", "Middle", "Ring"):
        n = "mixamorig:LeftHand%s3" % f
        if n in arm.pose.bones:
            out[f.lower()] = mw @ arm.pose.bones[n].tail
    return out


# ---------------------------------------------------------------- camp

def camp(animal, gb_dir, out, ual1, ual2, tag="r3"):
    arm, acts, mesh, files = gr.bound(animal, gb_dir, ual1, ual2)
    with open(files[1]) as fh:
        joints = json.load(fh)
    k = gr.SCALE["k"]
    piv = gr.pivot_rig(arm)
    gr.stage(res=480, samples=12)
    gr.rest(arm)
    rig = oc.RIGS["ual"]
    bones = [rig["trunk"][0], "upperarm_l", "upperarm_r"]
    rest = Rest(mesh, arm, joints, rig, bones)
    cam_pos, cam_at, fov = CAMP_CAMERA
    report = {"animal": animal, "skeleton": "ual (camp)", "k": k, "covered_body": int(len(rest.covered["body"])),
              "inside_beyond_reach": int(len(rest.beyond)), "inside_beyond_reach_where": rest.beyond_where,
              "sampling": "16 samples per clip (camp)", "crossing_rest": rest.crossing0,
              "garment_weights": os.environ.get("GB_GARMENT_WEIGHTS", "1") != "0", "clips": {}}
    shots = os.environ.get("GB_SHOTS", "1") != "0"
    for key, name in CAMP_CLIPS:
        act = acts.get(name)
        if act is None:
            report["clips"][key] = {"clip": name, "missing": True}
            continue
        spot, yaw = CAMP_SPOTS[key]
        # the camera in the character's own frame (character units)
        rel = godot_to_blender(cam_pos) - godot_to_blender(spot)
        rel = Matrix.Rotation(-yaw, 3, "Z") @ rel / k
        looks = {"camp_home": ("pos", rel)}
        f0, f1 = act.frame_range
        frames = []
        for i in range(CAMP_STEPS):
            f = f0 + (f1 - f0) * i / CAMP_STEPS
            piv.rotation_euler = (0, 0, 0)
            gr.clip(arm, act, int(f))
            m, res, co = measure(rest, looks)
            m["frame"] = int(f)
            m["time_s"] = round((int(f) - f0) / 30.0, 3)
            frames.append(m)
        worst = max(frames, key=lambda m: (m["seen_max"], m["body"]["points"]))
        report["clips"][key] = {"clip": name, "frames": frames, "worst_frame": worst["frame"]}
        if not shots:
            continue
        gr.clip(arm, act, worst["frame"])
        res, co = gr.poke(mesh, rest.covered)
        # from the camp's camera: placed in the character's frame
        sc = bpy.context.scene
        cd = bpy.data.cameras.new("camp")
        cd.sensor_fit = "VERTICAL"
        cd.angle = math.radians(fov)
        camo = bpy.data.objects.new("camp", cd)
        sc.collection.objects.link(camo)
        at = Matrix.Rotation(-yaw, 3, "Z") @ (godot_to_blender(cam_at) - godot_to_blender(spot)) / k
        camo.location = rel
        camo.rotation_euler = (at - rel).to_track_quat("-Z", "Y").to_euler()
        # the character's share of the 960x540 view, cropped round it
        cd.shift_x, cd.shift_y = 0.0, 0.0
        keep = sc.camera
        sc.camera = camo
        sc.render.resolution_x, sc.render.resolution_y = 960, 540
        for kind in ("clean", "marked"):
            mk = marks(piv, res, co) if kind == "marked" else None
            p = os.path.join(out, "%s_%s_camp_%s_%s.png" % (animal, tag, key, kind))
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            if mk is not None:
                bpy.data.objects.remove(mk, do_unlink=True)
        sc.camera = keep
        bpy.data.objects.remove(camo, do_unlink=True)
    with open(os.path.join(out, "%s_%s_camp.json" % (animal, tag)), "w") as fh:
        json.dump(report, fh, indent=1)
    summary_print(report)


# The clips kept in the rigged test file (the camp's, and the run).
RIGGED_CLIPS = ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sitting_Idle_Loop", "Crouch_Idle_Loop"]


def rigged(animal, gb_dir, out, ual1, ual2):
    """A test file with the whole skeleton (user request): the greybox
    bound to UAL's skeleton as the camp binds it - its tail bones
    included - with a few of the clips, as one .glb."""
    arm, acts, mesh, files = gr.bound(animal, gb_dir, ual1, ual2)
    keep = {acts[n] for n in RIGGED_CLIPS if n in acts}
    for a in list(bpy.data.actions):
        if a not in keep:
            bpy.data.actions.remove(a)
    ad = arm.animation_data
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    for a in keep:
        a.use_fake_user = True
        t = ad.nla_tracks.new()
        t.name = a.name.split("|")[-1].split("_Armature")[0]
        t.strips.new(t.name, int(a.frame_range[0]), a)
    ad.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    # (only the character: the skeleton's file brings a helper mesh along)
    for o in [o for o in bpy.data.objects if o.type == "MESH" and o is not mesh]:
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    path = os.path.join(out, "%s_greybox_rigged_ual.glb" % animal)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_skins=True, export_apply=False)
    print(animal, "rigged", path, os.path.getsize(path), sorted(t.name for t in ad.nla_tracks))


def summary_print(report):
    for name, c in report["clips"].items():
        if "frames" not in c:
            print(report["animal"], name, "missing")
            continue
        fr = c["frames"]
        print(report["animal"], name, "body max", max(m["body"]["points"] for m in fr),
              "seen max", max(m["seen_max"] for m in fr), "overlap min mm",
              min(m["cloth"]["hem_overlap_min_mm"] for m in fr), "rise max mm",
              max(m["cloth"]["hem_rise_mm"] for m in fr), "cuff min",
              min(min(m["cloth"]["cuff_l_area"], m["cloth"]["cuff_r_area"]) for m in fr), "shorts>25%",
              max(m["cloth"]["shorts_area_share_stretched_over_25pct"] for m in fr), "crossing", max(m["crossing"] for m in fr))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    cmd = args[0]
    os.makedirs(args[3], exist_ok=True)
    if cmd == "sheet":
        sheet(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], *(args[5:6] or []))
    elif cmd == "rods":
        rods(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], *(args[5:6] or []))
    elif cmd == "rigged":
        rigged(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5])
    elif cmd == "camp":
        camp(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5], *(args[6:7] or []))
    sys.stdout.flush()
    os._exit(0)
