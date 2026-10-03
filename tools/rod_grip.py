"""The rod held in the left hand (user request, round 4: the hand has to
hold the rod - fingers round the handle, the thumb against them - and the
rod must not slide in the hand or jump its angle; a candidate beside the
game's current rod, not over it).

render_player.py's rod was pointed by a per-frame angle (ROD_ANGLES) from
the palm, whatever the hand did - it turned in the hand from frame to
frame, and the fingers stayed open. Here the rod is fixed in the hand:

  - Each character's own grip, from its bound hand: the handle's axis
    across the fingers' roots (from the little finger's side to the
    index's, a little diagonal), under the first finger bones; each
    finger curled round it, joint by joint, until it lies on the handle;
    the thumb turned across to the other side of the handle, against the
    index finger.
  - The rod is then wherever the hand puts it. Where a clip's hand points
    it poorly (the backswing's tip low behind - it reads badly from
    above, and passes through the head), the wrist is turned toward the
    path wanted (path(): ROD_ANGLES' up angles, out to the side as far as
    clears the head), up to WRIST_MAX; what's left the forearm takes (up
    to FOREARM_MAX, about the elbow), then the upper arm (SHOULDER_MAX).
    Whatever is still left over stays: the rod goes where the hand is.

The shared logic is the same for every character; GRIP_TUNE holds each
one's small differences (its handle's place along the fingers, the
diagonal).

    import rod_grip
    g = rod_grip.Grip(arm, mesh, character)     # the bound T-posed rig
    g.hold(arm, target)                          # each frame of a clip
    grip, direction = g.rod(arm)
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

HAND = "mixamorig:LeftHand"
FOREARM = "mixamorig:LeftForeArm"
UPPER = "mixamorig:LeftArm"
FINGERS = ("Index", "Middle", "Ring", "Pinky")
# The handle's radius, character units (a ~1.2 m animal person: a 16 mm
# handle, as a grown man's 25 mm is to his 1.75 m).
HANDLE_R = 0.008
# How far each joint may turn toward the handle (deg), and the thumb's.
CURL_MAX = (95.0, 110.0, 95.0)
# The arm's share of turning the rod toward the path (deg each).
WRIST_MAX = 55.0
FOREARM_MAX = 35.0
SHOULDER_MAX = 30.0
# The handle's axis may lie this far from across the knuckles (deg): past
# it the fingers would run along it rather than round it.
FIT_MAX = 45.0
# Per character: the handle's place along the first finger bones (0 the
# knuckles, 1 the next joint), its diagonal across the palm (deg; the
# little finger's end toward the wrist), and how deep below the fingers
# (x the finger's radius plus the handle's).
GRIP_TUNE = {
    "owl": {"along": 0.45, "diagonal": 18.0, "depth": 1.0},
    "dog": {"along": 0.50, "diagonal": 16.0, "depth": 1.0},
    "cat": {"along": 0.50, "diagonal": 16.0, "depth": 1.0},
    "bear": {"along": 0.55, "diagonal": 12.0, "depth": 1.0},
}


def _v(x):
    return np.array(x[:], dtype=float)


def _rot(axis, deg):
    return np.array(Matrix.Rotation(math.radians(deg), 3, Vector(axis)))


def _to_axis(p, c, g):
    """Distance from p to the line through c along g (unit)."""
    d = p - c
    return float(np.linalg.norm(d - g * (d @ g)))


def turn_bone(arm, name, rot, about):
    """Turns a pose bone by `rot` (world 3x3, numpy) about the world point
    `about`; its children follow."""
    pb = arm.pose.bones[name]
    mw = arm.matrix_world
    R = Matrix(rot.tolist()).to_4x4()
    T = Matrix.Translation(Vector(about))
    pb.matrix = mw.inverted() @ T @ R @ T.inverted() @ mw @ pb.matrix
    bpy.context.view_layer.update()


def head(arm, name):
    return _v(arm.matrix_world @ arm.pose.bones[name].head)


def tail(arm, name):
    return _v(arm.matrix_world @ arm.pose.bones[name].tail)


def hand_matrix(arm):
    """The left hand bone's world matrix (scale taken out)."""
    m = arm.matrix_world @ arm.pose.bones[HAND].matrix
    loc, rot, _ = m.decompose()
    return Matrix.LocRotScale(loc, rot, None)


class Grip:
    def __init__(self, arm, mesh, character, samples=()):
        """On the bound skeleton. `samples`: (action, frame, wanted rod
        direction) - the handle's axis in the hand is the one that, over
        them, points the rod nearest where it's wanted (fit_axis)."""
        self.arm = arm
        tune = GRIP_TUNE.get(character, GRIP_TUNE["cat"])
        ad = arm.animation_data
        keep = ad.action if ad else None
        hands = []
        for act, fr, want in samples:
            ad.action = act
            bpy.context.scene.frame_set(int(fr))
            hands.append((np.array(hand_matrix(arm).to_3x3()), np.array(want, float)))
        if ad:
            ad.action = None
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        self.fingers = [f for f in FINGERS if self._weighted(mesh, "mixamorig:LeftHand%s1" % f)]
        self.k = (arm.matrix_world.to_3x3() @ Vector((1, 0, 0))).length
        self.radius = {f: self._radius(mesh, f) for f in self.fingers + ["Thumb"]}
        # The hand's frame at rest: across (little finger -> index), along
        # the fingers, and toward the palm (the side they curl to).
        roots = {f: head(arm, "mixamorig:LeftHand%s1" % f) for f in self.fingers}
        wrist = head(arm, HAND)
        knuck = np.mean(list(roots.values()), axis=0)
        f = knuck - wrist
        f /= np.linalg.norm(f)
        a = roots[self.fingers[0]] - roots[self.fingers[-1]]
        a -= f * (a @ f)
        a /= np.linalg.norm(a)
        n = np.cross(f, a)
        tips = np.mean([tail(arm, "mixamorig:LeftHand%s3" % x) for x in self.fingers], axis=0)
        # (the palm: where the fingertips hang below the knuckles, else down)
        if n @ (tips - knuck) < 0 or (abs(n @ (tips - knuck)) < 1e-4 and n[2] > 0):
            n = -n
        L1 = np.mean([np.linalg.norm(head(arm, "mixamorig:LeftHand%s2" % x) - roots[x]) for x in self.fingers])
        fr = np.mean([self.radius[x] for x in self.fingers])
        self.handle_r = HANDLE_R * self._char_k(mesh)
        dg = math.radians(tune["diagonal"])
        g = a * math.cos(dg) + f * math.sin(dg)
        g /= np.linalg.norm(g)
        hm0 = np.array(hand_matrix(arm).to_3x3())
        if hands:
            g = self.fit_axis(hands, hm0, a, f, n)
        # The handle's place: across the palm under the fingers, where they
        # wrap furthest round it (the palm and knuckles clear of it).
        palm = [wrist + (knuck - wrist) * t for t in np.linspace(0.0, 1.0, 9)]
        palm_r = max(fr, 0.6 * np.mean([np.linalg.norm(roots[x] - knuck) for x in self.fingers]))
        best = None
        for along in np.linspace(-0.2, 1.1, 14):
            for depth in np.linspace(0.6, 2.2, 17):
                c = knuck + f * L1 * along + n * (fr + self.handle_r) * depth
                if min(_to_axis(p, c, g) for p in palm) < self.handle_r + palm_r * 0.85:
                    continue
                wrap = sum(self._wrap(x, c, g, n)[0] for x in self.fingers)
                if best is None or wrap > best[0]:
                    best = (wrap, c, along, depth)
        _, c, self.along, self.depth = best
        self.rest = {"c": c, "g": g, "n": n, "f": f, "a": a}
        hm = hand_matrix(arm)
        inv = np.array(hm.inverted())
        self.c_local = (inv @ np.append(c, 1.0))[:3]
        self.g_local = inv[:3, :3] @ g
        # The fingers and thumb curled round it, as rotations of their
        # bones relative to their parents (the same in every frame).
        self._curl(c, g, n)
        self._thumb(c, g, n)
        self.pose = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones
                     if pb.name.startswith("mixamorig:LeftHand") and pb.name != HAND}
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        if ad:
            ad.action = keep
        bpy.context.view_layer.update()

    # ------------------------------------------------------------ set up

    @staticmethod
    def fit_axis(hands, hm0, a, f, n):
        """The handle's axis (world, at rest) that over the sampled frames
        (hand rotation, wanted direction) points the rod closest to where
        it's wanted - in the palm's plane (so the fingers can close round
        it), between across the knuckles and FIT_MAX toward the fingers."""
        # in the hand's own frame
        a_l, f_l, n_l = (hm0.T @ v for v in (a, f, n))
        acc = sum(H.T @ w for H, w in hands)
        best = None
        for deg in np.arange(-FIT_MAX, FIT_MAX + 0.1, 1.0):
            t = math.radians(deg)
            g_l = a_l * math.cos(t) + f_l * math.sin(t)
            score = float(g_l @ acc)
            if best is None or score > best[0]:
                best = (score, g_l, deg)
        Grip.fit_deg = best[2]
        return hm0 @ best[1]

    def _weighted(self, mesh, name):
        g = mesh.vertex_groups.get(name)
        if g is None:
            return False
        gi = g.index
        return any(x.group == gi and x.weight > 0.3 for v in mesh.data.vertices for x in v.groups)

    def _char_k(self, mesh):
        """World units a character unit: the hips' height over the greybox's
        (set by owl_character.bind as the mesh's custom property)."""
        return float(mesh.get("char_k", 1.0))

    def _radius(self, mesh, f):
        """A finger's girth: the median distance of its first two bones'
        vertices from their segments."""
        arm = self.arm
        out = []
        for i in (1, 2):
            name = "mixamorig:LeftHand%s%d" % (f, i)
            g = mesh.vertex_groups.get(name)
            if g is None:
                continue
            a, b = head(arm, name), tail(arm, name)
            ab = b - a
            for v in mesh.data.vertices:
                if any(x.group == g.index and x.weight > 0.6 for x in v.groups):
                    p = _v(mesh.matrix_world @ v.co)
                    t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
                    out.append(np.linalg.norm(p - (a + t * ab)))
        return float(np.median(out)) if out else 0.01

    def _chain(self, f):
        names = ["mixamorig:LeftHand%s%d" % (f, i) for i in (1, 2, 3)]
        pts = [head(self.arm, n) for n in names] + [tail(self.arm, names[-1])]
        return names, pts

    def _wrap(self, f, c, g, n):
        """Finger f curled round the handle (c, g) joint by joint, each as far
        as it goes before its later joints would sink into the handle:
        (how far round the handle it reaches (deg), its points, each joint's
        turn)."""
        names, pts = self._chain(f)
        want = self.handle_r + self.radius[f]
        pts = [p.copy() for p in pts]
        if min(_to_axis(p, c, g) for p in pts) < want * 0.97:
            return -1e3, pts, []
        turns = []
        for j in range(3):
            seg = pts[j + 1] - pts[j]
            axis = np.cross(seg, n)
            axis /= np.linalg.norm(axis)
            use = None
            for deg in np.arange(0.0, CURL_MAX[j] + 0.1, 2.0):
                R = _rot(axis, deg)
                q = [pts[j] + R @ (p - pts[j]) for p in pts[j + 1:]]
                chain = [pts[j]] + q
                mids = [(x + y) * 0.5 for x, y in zip(chain[:-1], chain[1:])]
                if min(_to_axis(p, c, g) for p in q) < want * 0.97 or \
                        min(_to_axis(p, c, g) for p in mids) < want * 0.80:
                    break
                use = (deg, R, q)
            if use is None:
                turns.append((names[j], np.eye(3), pts[j].copy()))
                continue
            deg, R, q = use
            pts[j + 1:] = q
            turns.append((names[j], R, pts[j].copy()))
        # how far round: the angle about the axis from knuckle to tip,
        # counting only the joints close to the handle
        def ang(p):
            d = p - c
            d = d - g * (d @ g)
            return math.atan2(float(np.cross(n, d) @ g), float(-n @ d))
        close = [p for p in pts if _to_axis(p, c, g) < want * 1.25]
        if len(close) < 2:
            return 0.0, pts, turns
        a = [ang(p) for p in close]
        span = abs(math.degrees(np.unwrap(a)[-1] - np.unwrap(a)[0]))
        return span, pts, turns

    def _curl(self, c, g, n):
        """Each finger wrapped round the handle (_wrap), on the skeleton."""
        self.wrapped = {}
        self.wrap_deg = {}
        for f in self.fingers:
            span, pts, turns = self._wrap(f, c, g, n)
            for name, R, about in turns:
                turn_bone(self.arm, name, R, about)
            self.wrapped[f] = pts
            self.wrap_deg[f] = round(span, 1)

    def _thumb(self, c, g, n):
        """The thumb round the handle's other side, its tip on the index
        finger's middle bone: its root bone turned (two ways), the others
        curled, the best of a search."""
        arm = self.arm
        names = ["mixamorig:LeftHandThumb%d" % i for i in (1, 2, 3)]
        p0 = [head(arm, x) for x in names] + [tail(arm, names[-1])]
        tr = self.radius["Thumb"]
        want = self.handle_r + tr
        idx = self.wrapped.get(self.fingers[0]) or self._chain(self.fingers[0])[1]
        fr = self.radius[self.fingers[0]]
        # against the handle opposite the fingers' tips (pressing it into
        # them), along it by the index finger
        tip = idx[3]
        opp = (tip - c) - g * ((tip - c) @ g)
        opp = -opp / np.linalg.norm(opp)
        side = (c + g * ((idx[0] - c) @ g))
        target = side + opp * want
        fing = [self.wrapped.get(f) or self._chain(f)[1] for f in self.fingers]

        def chain(x):
            pts = [p.copy() for p in p0]
            Rs = []
            R = _rot(n, x[0]) @ _rot(g, x[1])
            pts[1:] = [pts[0] + R @ (p - pts[0]) for p in pts[1:]]
            Rs.append(R)
            for j, deg in ((1, x[2]), (2, x[3])):
                seg = pts[j + 1] - pts[j]
                axis = np.cross(seg, n)
                axis /= np.linalg.norm(axis) + 1e-12
                R = _rot(axis, deg)
                pts[j + 1:] = [pts[j] + R @ (p - pts[j]) for p in pts[j + 1:]]
                Rs.append(R)
            return pts, Rs

        def seg_d(p, a, b):
            ab = b - a
            t = np.clip(((p - a) @ ab) / (ab @ ab), 0, 1)
            return np.linalg.norm(p - (a + t * ab))

        def cost(x):
            pts, _ = chain(x)
            e = np.linalg.norm(pts[3] - target) ** 2
            for a, b in zip(pts[:-1], pts[1:]):
                for t in (0.25, 0.5, 0.75, 1.0):
                    p = a + (b - a) * t
                    d = _to_axis(p, c, g)
                    if d < want * 0.95:
                        e += (want * 0.95 - d) ** 2 * 40
                    for ch in fing:
                        for u, v in zip(ch[:-1], ch[1:]):
                            dd = seg_d(p, u, v)
                            if dd < (fr + tr) * 0.85:
                                e += ((fr + tr) * 0.85 - dd) ** 2 * 20
            return e + 1e-7 * (x @ x)

        best = None
        for a0 in range(-75, 76, 15):
            for a1 in range(-75, 76, 15):
                for b in (10.0, 40.0):
                    x = np.array([a0, a1, b, b], float)
                    cst = cost(x)
                    if best is None or cst < best[0]:
                        best = (cst, x)
        from scipy.optimize import minimize
        r = minimize(cost, best[1], method="Nelder-Mead", options={"xatol": 0.2, "fatol": 1e-12, "maxiter": 1500})
        x = np.clip(r.x, [-90, -90, 0, 0], [90, 90, 80, 80])
        pts, Rs = chain(x)
        for j, R in enumerate(Rs):
            turn_bone(arm, names[j], R, head(arm, names[j]))
        self.thumb_fit = float(np.linalg.norm(pts[3] - target))
        self.thumb_angles = [round(float(v), 1) for v in x]

    # ------------------------------------------------------------ per frame

    def fingers_on(self):
        """The fingers and thumb round the handle (over the clip's)."""
        for name, mb in self.pose.items():
            self.arm.pose.bones[name].matrix_basis = mb
        bpy.context.view_layer.update()

    def rod(self):
        """The handle's centre and the rod's direction, world."""
        m = np.array(hand_matrix(self.arm))
        return m[:3, :3] @ self.c_local + m[:3, 3], m[:3, :3] @ self.g_local

    def hold(self, target=None):
        """This frame's hand on the rod; turned toward `target` (a world
        direction) by the wrist, then forearm, then upper arm, as far as
        each may. Returns how far each turned and what's left (deg)."""
        self.fingers_on()
        out = {}
        if target is None:
            return out
        t = np.array(target, float)
        t /= np.linalg.norm(t)
        for name, limit in ((HAND, WRIST_MAX), (FOREARM, FOREARM_MAX), (UPPER, SHOULDER_MAX)):
            _, d = self.rod()
            ang = math.degrees(math.acos(max(-1.0, min(1.0, float(d @ t)))))
            if ang < 0.5:
                out[name] = 0.0
                continue
            axis = np.cross(d, t)
            if np.linalg.norm(axis) < 1e-9:
                continue
            axis /= np.linalg.norm(axis)
            use = min(ang, limit)
            turn_bone(self.arm, name, _rot(axis, use), head(self.arm, name))
            out[name] = round(use, 1)
        _, d = self.rod()
        out["left"] = round(math.degrees(math.acos(max(-1.0, min(1.0, float(d @ t))))), 1)
        return out
