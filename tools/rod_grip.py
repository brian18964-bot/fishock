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

User request (round 6: the reeling cranked at the air): the other hand
grips the reel's crank knob the same way (Grip(..., side="Right"), a knob
for a handle), and a hand can be put somewhere - reach(): the handle's
centre to a point, its axis along a direction, the arm reaching there by
two-bone IK (two_bone), the hand turned so the wrist bends least.

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
# Per character (user request, round 5: each its own grip, not one 45
# degree axis for all): the handle's axis in the palm (deg from across the
# knuckles toward the fingers; None = fitted to the clips, up to FIT_MAX),
# where it crosses the palm (x the first finger bone's length from the
# knuckles; negative = into the palm), and the handle's radius (character
# units).
GRIP_TUNE = {
    "owl": {"axis": 25.0, "palm_at": -0.20, "handle_r": 0.008},
    "dog": {"axis": 20.0, "palm_at": -0.25, "handle_r": 0.008},
    "cat": {"axis": 20.0, "palm_at": -0.25, "handle_r": 0.007},
    "bear": {"axis": 15.0, "palm_at": -0.30, "handle_r": 0.009},
    "deer": {"axis": 20.0, "palm_at": -0.25, "handle_r": 0.008},
    "sheep": {"axis": 20.0, "palm_at": -0.25, "handle_r": 0.008},
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
    # Only turned: the rounding each turn leaves in the pose's scale taken
    # out (on UAL's skeleton it built up turn after turn until a hand blew up).
    loc, rot, _ = pb.matrix_basis.decompose()
    pb.matrix_basis = Matrix.LocRotScale(loc, rot, None)
    bpy.context.view_layer.update()


def head(arm, name):
    return _v(arm.matrix_world @ arm.pose.bones[name].head)


def tail(arm, name):
    return _v(arm.matrix_world @ arm.pose.bones[name].tail)


def hand_matrix(arm, hand=HAND):
    """A hand bone's world matrix (scale taken out; the left by default)."""
    m = arm.matrix_world @ arm.pose.bones[hand].matrix
    loc, rot, _ = m.decompose()
    return Matrix.LocRotScale(loc, rot, None)


class Grip:
    def __init__(self, arm, mesh, character, samples=(), side="Left", tune=None):
        """On the bound skeleton. `samples`: (action, frame, wanted rod
        direction) - the handle's axis in the hand is the one that, over
        them, points the rod nearest where it's wanted (fit_axis). `side`:
        the hand ("Left" holds the rod; "Right" the reel's knob, user
        request round 6); `tune`: its GRIP_TUNE entry, if not the
        character's."""
        self.arm = arm
        self.side = side
        self.HAND = "mixamorig:%sHand" % side
        self.FOREARM = "mixamorig:%sForeArm" % side
        self.UPPER = "mixamorig:%sArm" % side
        tune = tune or GRIP_TUNE.get(character, GRIP_TUNE["cat"])
        ad = arm.animation_data
        keep = ad.action if ad else None
        hands = []
        for act, fr, want in samples:
            ad.action = act
            bpy.context.scene.frame_set(int(fr))
            hands.append((np.array(hand_matrix(arm, self.HAND).to_3x3()), np.array(want, float)))
        if ad:
            ad.action = None
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        self.fingers = [f for f in FINGERS if self._weighted(mesh, self.HAND + "%s1" % f)]
        self.k = (arm.matrix_world.to_3x3() @ Vector((1, 0, 0))).length
        self.radius = {f: self._radius(mesh, f) for f in self.fingers + ["Thumb"]}
        # The hand's frame at rest: across (little finger -> index), along
        # the fingers, and toward the palm (the side they curl to).
        roots = {f: head(arm, self.HAND + "%s1" % f) for f in self.fingers}
        wrist = head(arm, self.HAND)
        knuck = np.mean(list(roots.values()), axis=0)
        f = knuck - wrist
        f /= np.linalg.norm(f)
        a = roots[self.fingers[0]] - roots[self.fingers[-1]]
        a -= f * (a @ f)
        a /= np.linalg.norm(a)
        n = np.cross(f, a)
        tips = np.mean([tail(arm, self.HAND + "%s3" % x) for x in self.fingers], axis=0)
        # (the palm: where the fingertips hang below the knuckles, else down)
        if n @ (tips - knuck) < 0 or (abs(n @ (tips - knuck)) < 1e-4 and n[2] > 0):
            n = -n
        L1 = np.mean([np.linalg.norm(head(arm, self.HAND + "%s2" % x) - roots[x]) for x in self.fingers])
        fr = np.mean([self.radius[x] for x in self.fingers])
        self.handle_r = tune.get("handle_r", HANDLE_R) * self._char_k(mesh)
        hm0 = np.array(hand_matrix(arm, self.HAND).to_3x3())
        if tune.get("axis") is None and hands:
            g = self.fit_axis(hands, hm0, a, f, n)
            self.fit_deg = Grip.fit_deg
        else:
            dg = math.radians(tune.get("axis") or 0.0)
            g = a * math.cos(dg) + f * math.sin(dg)
            g /= np.linalg.norm(g)
            self.fit_deg = tune.get("axis") or 0.0
        # The handle across the palm: on the palm's side, where the palm
        # meets it (the palm's own points just clear of it).
        palm = self._palm_points(mesh)
        c = knuck + f * L1 * tune["palm_at"]
        for _ in range(400):
            if min(_to_axis(p, c, g) for p in palm) >= self.handle_r:
                break
            c = c + n * self.handle_r * 0.04
        self.palm_gap = float(min(_to_axis(p, c, g) for p in palm) - self.handle_r)
        self.rest = {"c": c, "g": g, "n": n, "f": f, "a": a}
        hm = hand_matrix(arm, self.HAND)
        inv = np.array(hm.inverted())
        self.c_local = (inv @ np.append(c, 1.0))[:3]
        self.g_local = inv[:3, :3] @ g
        # (and the fingers' way and the palm's, for placing the hand)
        self.f_local = inv[:3, :3] @ f
        self.n_local = inv[:3, :3] @ n
        # how far the fingers spread along the handle, from its centre
        # (index side +, little finger side -), finger girth included
        along = [(roots[x] - c) @ g for x in self.fingers]
        self.span = (min(along) - fr, max(along) + fr)
        # The fingers and thumb curled round it, as rotations of their
        # bones relative to their parents (the same in every frame).
        self._curl(c, g, n)
        self._thumb(c, g, n)
        self.pose = {pb.name: pb.matrix_basis.copy() for pb in arm.pose.bones
                     if pb.name.startswith(self.HAND) and pb.name != self.HAND}
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
            name = self.HAND + "%s%d" % (f, i)
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
        names = [self.HAND + "%s%d" % (f, i) for i in (1, 2, 3)]
        pts = [head(self.arm, n) for n in names] + [tail(self.arm, names[-1])]
        return names, pts

    def _palm_points(self, mesh):
        """The palm's own vertices (mostly the hand bone's, not a finger's)."""
        g = mesh.vertex_groups.get(self.HAND)
        out = []
        if g is None:
            return out
        for v in mesh.data.vertices:
            for x in v.groups:
                if x.group == g.index and x.weight > 0.6:
                    out.append(_v(mesh.matrix_world @ v.co))
                    break
        return out[::3]

    def _hinge(self, pts, n):
        """A finger's bending axis: square to its first bone and the palm's
        normal, turned so that bending moves it toward the palm."""
        d = pts[1] - pts[0]
        d /= np.linalg.norm(d)
        h = np.cross(d, n)
        h /= np.linalg.norm(h)
        if (np.cross(h, d)) @ n < 0:
            h = -h
        return h

    @staticmethod
    def _bend(pts, h, angles):
        """The chain's points with joint j turned angles[j] about h (each
        turn carrying the rest of the finger)."""
        out = [pts[0].copy()]
        tot = 0.0
        for j in range(len(pts) - 1):
            tot += angles[j] if j < len(angles) else 0.0
            out.append(out[-1] + _rot(h, tot) @ (pts[j + 1] - pts[j]))
        return out

    def _curl(self, c, g, n):
        """Each finger bent joint by joint about its own fixed axis so that
        its joints lie along the handle's surface - wrapping round it as far
        as the finger reaches, every joint bending (not stopping at the
        first touch), nowhere sinking into the handle."""
        from scipy.optimize import minimize
        self.wrapped, self.wrap_deg, self.curl_deg, self.hinges = {}, {}, {}, {}
        for f in self.fingers:
            names, pts = self._chain(f)
            want = self.handle_r + self.radius[f]
            h = self._hinge(pts, n)

            base_r = self.radius[f]

            def cost(x):
                q = self._bend(pts, h, x)
                e = 0.0
                for j, w in ((1, 0.5), (2, 1.0), (3, 1.0)):
                    e += w * (_to_axis(q[j], c, g) - want) ** 2
                for a_, b_ in zip(q[:-1], q[1:]):
                    for t in (0.25, 0.5, 0.75, 1.0):
                        p = a_ + (b_ - a_) * t
                        # (the finger's root is in the palm, by the handle
                        # already: only what's past it must keep off)
                        if np.linalg.norm(p - q[0]) < base_r * 1.2:
                            continue
                        dd = _to_axis(p, c, g)
                        if dd < want * 0.97:
                            e += 50.0 * (want * 0.97 - dd) ** 2
                return e / want ** 2

            grid = []
            for t1 in np.arange(0, CURL_MAX[0] + 1, 7.5):
                for t2 in np.arange(0, CURL_MAX[1] + 1, 7.5):
                    for t3 in np.arange(0, CURL_MAX[2] + 1, 7.5):
                        grid.append((cost((t1, t2, t3)), (t1, t2, t3)))
            grid.sort(key=lambda z: z[0])
            best = None
            for _, start in grid[:3]:
                r = minimize(cost, np.array(start, float), method="Nelder-Mead",
                         options={"xatol": 0.3, "fatol": 1e-9, "maxiter": 600})
                xr = np.clip(r.x, 0.0, CURL_MAX)
                fx = cost(xr)
                if best is None or fx < best[0]:
                    best = (fx, xr)
            x = best[1]
            q = self._bend(pts, h, x)
            # on the skeleton, root first
            tot = 0.0
            for j in range(3):
                turn_bone(self.arm, names[j], _rot(h, x[j]), head(self.arm, names[j]))
                tot += x[j]
            self.wrapped[f] = q
            self.curl_deg[f] = [round(float(v), 1) for v in x]
            self.hinges[f] = h
            # how far round the handle its joints in touch reach (deg)
            near = [p for p in q if _to_axis(p, c, g) < want * 1.15]
            if len(near) >= 2:
                ref = np.cross(g, h)

                def ang(p):
                    d = p - c
                    d = d - g * (d @ g)
                    return math.atan2(float(np.cross(ref, d) @ g), float(ref @ d))
                a_ = np.unwrap([ang(p) for p in near])
                self.wrap_deg[f] = round(abs(math.degrees(a_[-1] - a_[0])), 1)
            else:
                self.wrap_deg[f] = 0.0

    def _thumb(self, c, g, n):
        """The thumb on the handle's other side from the fingers, its tip
        pressing on the index finger's middle bone from outside (the grip's
        two sides): its root bone turned two ways, the others bent, the
        best of a search; never into the handle, the fingers or the palm."""
        from scipy.optimize import minimize
        arm = self.arm
        names = [self.HAND + "Thumb%d" % i for i in (1, 2, 3)]
        p0 = [head(arm, x) for x in names] + [tail(arm, names[-1])]
        tr = self.radius["Thumb"]
        want = self.handle_r + tr
        idx = self.wrapped[self.fingers[0]]
        fr = self.radius[self.fingers[0]]
        m = (idx[1] * 0.4 + idx[2] * 0.6)
        out = (m - c) - g * ((m - c) @ g)
        out /= np.linalg.norm(out)
        target = m + out * (fr + tr) * 0.95
        fing = [self.wrapped[f] for f in self.fingers]
        ht = self._hinge(p0, n)

        def chain(x):
            R = _rot(n, x[0]) @ _rot(ht, x[1])
            pts = [p0[0]] + [p0[0] + R @ (p - p0[0]) for p in p0[1:]]
            h2 = R @ ht
            for j, deg in ((1, x[2]), (2, x[3])):
                Rj = _rot(h2, deg)
                pts[j + 1:] = [pts[j] + Rj @ (p - pts[j]) for p in pts[j + 1:]]
            return pts

        def seg_d(p, a_, b_):
            ab = b_ - a_
            t = np.clip(((p - a_) @ ab) / (ab @ ab), 0, 1)
            return np.linalg.norm(p - (a_ + t * ab))

        def cost(x):
            pts = chain(x)
            e = np.linalg.norm(pts[3] - target) ** 2 / want ** 2
            e += 0.3 * (_to_axis(pts[2], c, g) - want) ** 2 / want ** 2
            for a_, b_ in zip(pts[:-1], pts[1:]):
                for t in (0.25, 0.5, 0.75, 1.0):
                    p = a_ + (b_ - a_) * t
                    dd = _to_axis(p, c, g)
                    if dd < want * 0.95:
                        e += 300 * ((want * 0.95 - dd) / want) ** 2
                    for ch in fing:
                        for u, v in zip(ch[:-1], ch[1:]):
                            d2 = seg_d(p, u, v)
                            if d2 < (fr + tr) * 0.85:
                                e += 100 * (((fr + tr) * 0.85 - d2) / want) ** 2
            return e + 1e-6 * float(x @ x)

        best = None
        for a0 in range(-90, 91, 15):
            for a1 in range(-90, 91, 15):
                for b in (10.0, 45.0):
                    x = np.array([a0, a1, b, b], float)
                    cst = cost(x)
                    if best is None or cst < best[0]:
                        best = (cst, x)
        r = minimize(cost, best[1], method="Nelder-Mead", options={"xatol": 0.3, "fatol": 1e-10, "maxiter": 2000})
        x = np.clip(r.x, [-120, -120, 0, 0], [120, 120, 90, 90])
        R = _rot(n, x[0]) @ _rot(ht, x[1])
        turn_bone(arm, names[0], R, p0[0])
        h2 = R @ ht
        turn_bone(arm, names[1], _rot(h2, x[2]), head(arm, names[1]))
        turn_bone(arm, names[2], _rot(h2, x[3]), head(arm, names[2]))
        pts = chain(x)
        self.thumb_fit = float(np.linalg.norm(pts[3] - target))
        self.thumb_angles = [round(float(v), 1) for v in x]
        # which side of the handle the thumb's tip is on, against the
        # fingers' tips (deg round the handle; ~180 = opposite)
        ref = np.cross(g, self.hinges[self.fingers[0]])

        def ang(p):
            d = p - c
            d = d - g * (d @ g)
            return math.degrees(math.atan2(float(np.cross(ref, d) @ g), float(ref @ d)))
        tips = np.mean([ang(ch[2]) for ch in fing])
        self.thumb_opposite_deg = round(abs((ang(pts[3]) - tips + 180) % 360 - 180), 1)

    # ------------------------------------------------------------ per frame

    def fingers_on(self):
        """The fingers and thumb round the handle (over the clip's)."""
        for name, mb in self.pose.items():
            self.arm.pose.bones[name].matrix_basis = mb
        bpy.context.view_layer.update()

    def rod(self):
        """The handle's centre and the rod's direction, world."""
        m = np.array(hand_matrix(self.arm, self.HAND))
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
        # shared out (user request, round 5: not the wrist first to its
        # limit): the wrist takes half of what's wanted, the forearm most of
        # what's left, the upper arm the rest - each within its limit - and
        # the wrist then whatever is still over, if it has room
        HAND, FOREARM, UPPER = self.HAND, self.FOREARM, self.UPPER
        used = {HAND: 0.0, FOREARM: 0.0, UPPER: 0.0}
        limits = {HAND: WRIST_MAX, FOREARM: FOREARM_MAX, UPPER: SHOULDER_MAX}
        for name, share in ((HAND, 0.5), (FOREARM, 0.6), (UPPER, 1.0), (HAND, 1.0), (FOREARM, 1.0)):
            _, d = self.rod()
            ang = math.degrees(math.acos(max(-1.0, min(1.0, float(d @ t)))))
            if ang < 0.3:
                break
            axis = np.cross(d, t)
            if np.linalg.norm(axis) < 1e-9:
                break
            axis /= np.linalg.norm(axis)
            use = min(ang * share, limits[name] - used[name])
            if use <= 0.0:
                continue
            turn_bone(self.arm, name, _rot(axis, use), head(self.arm, name))
            used[name] += use
        out.update({k: round(v, 1) for k, v in used.items()})
        _, d = self.rod()
        out["left"] = round(math.degrees(math.acos(max(-1.0, min(1.0, float(d @ t))))), 1)
        return out

    # ------------------------------------------------------------ reaching (round 6)

    def wrist_bend(self):
        """How far the hand is bent off the forearm's line (deg)."""
        fa = head(self.arm, self.HAND) - head(self.arm, self.FOREARM)
        m = np.array(hand_matrix(self.arm, self.HAND).to_3x3())
        f = m @ self.f_local
        c = float(fa @ f / (np.linalg.norm(fa) * np.linalg.norm(f)))
        return math.degrees(math.acos(max(-1.0, min(1.0, c))))

    def move_to(self, c, pole=None):
        """User request (round 6: both hands on the reel): the handle's
        centre to world point c, the hand turned as it is - the arm reaching
        there (two_bone), the elbow kept toward `pole` (default: where it
        is)."""
        m = hand_matrix(self.arm, self.HAND)
        R = np.array(m.to_3x3())
        w = np.array(c, float) - R @ self.c_local
        two_bone(self.arm, self.UPPER, self.FOREARM, self.HAND, w, pole)
        set_rotation(self.arm, self.HAND, R)

    def place(self, c, g, prefer, palm=None, pole=None):
        """The handle's centre to world point c, its axis along g (either
        way round, whichever turns the palm nearer `palm`; just g without
        one), the fingers as near `prefer` as that leaves them; the arm
        reaching there (the elbow toward `pole`, default where it is)."""
        g = np.array(g, float)
        g /= np.linalg.norm(g)
        best = None
        for sign in ((1.0, -1.0) if palm is not None else (1.0,)):
            gt = g * sign
            ft = np.array(prefer, float) - gt * (gt @ prefer)
            ft /= np.linalg.norm(ft)
            gl = self.g_local / np.linalg.norm(self.g_local)
            fl = self.f_local - gl * (gl @ self.f_local)
            fl /= np.linalg.norm(fl)
            R = np.column_stack([gt, ft, np.cross(gt, ft)]) @ np.column_stack([gl, fl, np.cross(gl, fl)]).T
            score = float((R @ self.n_local) @ np.array(palm, float)) if palm is not None else 0.0
            if best is None or score > best[0]:
                best = (score, R)
        R = best[1]
        w = np.array(c, float) - R @ self.c_local
        two_bone(self.arm, self.UPPER, self.FOREARM, self.HAND, w, pole)
        set_rotation(self.arm, self.HAND, R)

    def reach(self, c, g, palm=None, pole=None, rounds=3, either=False, swings=()):
        """place(), the fingers led along the forearm: first toward the
        shoulder's line to c, then each round along the forearm as it lies
        (so the wrist bends as little as it can). either: the handle may
        lie either way round in the hand (a knob: over- or underhand) -
        whichever bends the wrist less; swings: elbow positions to try (deg
        round the shoulder-to-hand line), the least bent wrist kept."""
        if either or swings:
            # the handle either way round (if it may be), the elbow swung
            # round the shoulder-to-hand line by `swings` deg: the least
            # bent wrist
            g = np.array(g, float)
            keep = {b: self.arm.pose.bones[b].matrix_basis.copy() for b in (self.UPPER, self.FOREARM, self.HAND)}
            s0 = head(self.arm, self.UPPER)
            e0 = head(self.arm, self.FOREARM)
            axis = np.array(c, float) - s0
            axis /= np.linalg.norm(axis)
            best = None
            for sign in ((1.0, -1.0) if either else (1.0,)):
                for sw in (swings or (0.0,)):
                    for b, m in keep.items():
                        self.arm.pose.bones[b].matrix_basis = m
                    bpy.context.view_layer.update()
                    pl = s0 + _rot(axis, sw) @ (e0 - s0) if pole is None else pole
                    self.reach(c, g * sign, palm if not either else None, pl, rounds)
                    bend = self.wrist_bend()
                    if best is None or bend < best[0] - 1e-6:
                        best = (bend, sign, pl)
            for b, m in keep.items():
                self.arm.pose.bones[b].matrix_basis = m
            bpy.context.view_layer.update()
            self.reach(c, g * best[1], palm if not either else None, best[2], rounds)
            return
        prefer = np.array(c, float) - head(self.arm, self.UPPER)
        for _ in range(rounds):
            self.place(c, g, prefer / np.linalg.norm(prefer), palm, pole)
            prefer = head(self.arm, self.HAND) - head(self.arm, self.FOREARM)


def rot_between(a, b):
    """The least rotation (3x3) taking direction a to direction b."""
    a = np.array(a, float) / np.linalg.norm(a)
    b = np.array(b, float) / np.linalg.norm(b)
    axis = np.cross(a, b)
    s = np.linalg.norm(axis)
    if s < 1e-9:
        return np.eye(3)
    return _rot(axis / s, math.degrees(math.atan2(s, float(a @ b))))


def set_rotation(arm, name, R):
    """Turns a bone about its head until its world rotation is R."""
    m = np.array(hand_matrix(arm, name).to_3x3())
    turn_bone(arm, name, R @ m.T, head(arm, name))


def two_bone(arm, upper, fore, hand, w, pole=None):
    """Upper arm and forearm turned so the hand's head (the wrist) reaches
    world point w - as near as the arm's length allows - the elbow toward
    `pole` (default: where it is now)."""
    s, e, h = head(arm, upper), head(arm, fore), head(arm, hand)
    a, b = np.linalg.norm(e - s), np.linalg.norm(h - e)
    d = np.array(w, float) - s
    L = float(np.clip(np.linalg.norm(d), abs(a - b) + 1e-5, a + b - 1e-5))
    dn = d / np.linalg.norm(d)
    p = (e if pole is None else np.array(pole, float)) - s
    p = p - dn * (p @ dn)
    if np.linalg.norm(p) < 1e-6:
        p = np.cross(dn, [0.0, 0.0, 1.0])
    p /= np.linalg.norm(p)
    ca = (a * a + L * L - b * b) / (2 * a * L)
    et = s + a * (ca * dn + math.sqrt(max(0.0, 1 - ca * ca)) * p)
    turn_bone(arm, upper, rot_between(e - s, et - s), s)
    e2, h2 = head(arm, fore), head(arm, hand)
    turn_bone(arm, fore, rot_between(h2 - e2, s + dn * L - e2), e2)
