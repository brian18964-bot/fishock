"""Greybox animal people (user request: rework the owl, the dog, the cat and
the bear into one game's stylised characters - clear big shapes, a
moderate amount of secondary detail, the same beginner's cream jumper and
khaki shorts refitted to each body - shown untextured before any colour or
detail goes on).

Each animal is built from signed-distance shapes (tools/sdf_mesh.py) in
the T-pose both of the game's skeletons rest in (the technical bind pose;
display poses are put on afterwards through the skeleton):

  body     head, neck, trunk, arms, hands, legs, feet and tail as ONE
           surface, so head-neck, shoulder-arm, waist-hip and leg-foot run
           on without seams;
  jumper   built off that body's trunk and upper arms (its shoulders,
           sleeves, cuffs, V-neck and ribbed hem fit that body);
  trousers built off its hips and thighs (waist, crotch, legs, rolled
           cuffs), the hem of the jumper lapping over their waist so no
           band of anything shows between the two;
  button   on the shorts' fly, just under the jumper;
  collar   what the animal has at its neck (the owl's feather ruff, the
           dog's neckerchief, the bear's fur collar; the cat none).

Writes OUT_DIR/ANIMAL.blend, ANIMAL_greybox.glb (the parts, no rig) and
ANIMAL_greybox.json (its joints, as owl_character.bind reads them, plus
what the greybox's body needs to be weighted: where its head is rigid,
where its tail is, the jumper's neckline).

    bpyenv/bin/python tools/greybox_animals.py -- ANIMAL OUT_DIR [--legs F] [--voxel V]

  --legs F   the owl's legs below the shorts at F times their length on the
             current owl (0.356; user request: compare 0.80-0.85).
"""
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sdf_mesh as S  # noqa: E402

# Material zones (each part's faces take one).
FUR, SKIN, HORN, EYE, KNIT, CLOTH, BUTTON, SCARF, PAD = range(9)
# Greybox values: one grey for the animal (its pads too - their own zone,
# for the colour pass), lighter for the clothes, dark for eyes and nose.
ZONES = [("fur", 0.40), ("skin", 0.22), ("horn", 0.55), ("eye", 0.07),
         ("knit", 0.74), ("cloth", 0.56), ("button", 0.30), ("scarf", 0.24), ("pad", 0.40)]
# The owl's legs below its shorts today (hem 0.352 over the ground at -0.004),
# and the share of that it keeps by default (user request: compare 15-20%
# shorter); the rolled cuff hangs this far below the hem it's measured to.
OWL_EXPOSED = 0.356
OWL_LEGS = 0.85
CUFF_DROP = 0.017


def V(*a):
    return np.array(a, dtype=float)


def unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def lerp(a, b, t):
    return a + (b - a) * t


def above(z):
    """Everything above height z."""
    return S.half_space(V(0, 0, z), V(0, 0, -1))


def below(z):
    return S.half_space(V(0, 0, z), V(0, 0, 1))


def slab(z0, z1):
    return S.inter(above(z0), below(z1))


def rotate(v, axis, deg):
    return S.rot(axis, deg) @ np.asarray(v, dtype=float)


def leaf(root, direction, length, width, thick, up=V(0, 0, 1)):
    """A feather or fur clump: a flattened ellipsoid from `root` along
    `direction`, `width` across and `thick` through (its flat side
    facing `up` as far as it can)."""
    d = unit(direction)
    side = np.cross(up, d)
    if np.linalg.norm(side) < 1e-6:
        side = np.cross(V(1, 0, 0), d)
    side = unit(side)
    n = np.cross(d, side)
    R = np.stack([side, d, n], axis=1)
    return S.ellipsoid(root + d * length * 0.5, (width * 0.5, length * 0.5, thick * 0.5), R)


def clump(root, direction, length, r0, flat=0.6, up=V(0, 0, 1)):
    """A fur clump: a round cone from r0 at the root to a point, flattened
    against the surface it grows from."""
    d = unit(direction)
    tip = root + d * length
    c = S.round_cone(root, tip, r0, r0 * 0.34)
    side = np.cross(up, d)
    if np.linalg.norm(side) < 1e-6:
        side = np.cross(V(1, 0, 0), d)
    side = unit(side)
    n = np.cross(d, side)
    R = np.stack([side, d, n], axis=1)
    return S.squash(c, root + d * length * 0.5, (1.0, 1.0, flat), R)


def flat_cone(a, b, ra, rb, across, flat):
    """A round cone from a to b squashed to `flat` of its thickness
    through the plane of its length and `across` (an ear, a flap)."""
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    d = unit(b - a)
    w = unit(np.asarray(across, dtype=float) - d * np.dot(across, d))
    n = np.cross(d, w)
    R = np.stack([w, d, n], axis=1)
    return S.squash(S.round_cone(a, b, ra, rb), (a + b) * 0.5, (1.0, 1.0, flat), R)


# ---------------------------------------------------------------- animals

# All lengths in metres in the owl's units (its hips 0.603 high today);
# every animal shares them (size 1), so the bear stands bigger than the
# cat the way it would in the game.
ANIMALS = {
    "owl": dict(
        ankle_z=0.040, shin=None, thigh=0.196, pelvis_up=0.045, leg_x=0.078,
        thigh_r=(0.068, 0.054), shin_r=(0.046, 0.034), calf=0.0,
        pelvis=((0.0, 0.012, 0.0), (0.130, 0.106, 0.090)),
        belly=((0.0, -0.006, 0.112), (0.142, 0.122, 0.108)),
        chest=((0.0, 0.002, 0.218), (0.146, 0.122, 0.110)),
        shoulder=(0.148, 0.022, 0.252), shoulder_r=0.050,
        upper=(0.142, 0.038, 0.032), fore=(0.142, 0.036, 0.026),
        neck=((0.0, 0.012, 0.29), (0.0, 0.004, 0.35), 0.080, 0.076),
        head=(0.0, -0.004, 0.418),
        hand=dict(kind="wing", palm=(0.048, 0.052, 0.024), fingers=(0.026, 0.022, 0.018), finger_r=0.0098,
                  thumb=(0.024, 0.019), thumb_r=0.0095, n=3, curl=(6, 12, 16), spread=10, claw=None),
        foot=dict(kind="bird"),
        jumper=dict(ease=0.013, hem=0.035, sleeve=0.62, v_depth=0.070, v_slope=1.9),
        trousers=dict(ease=0.007, waist=0.080, hem_above_knee=0.022, leg_r=0.016, crotch=0.025),
    ),
    "dog": dict(
        ankle_z=0.068, shin=0.240, thigh=0.228, pelvis_up=0.046, leg_x=0.080,
        thigh_r=(0.066, 0.049), shin_r=(0.046, 0.029), calf=0.012,
        pelvis=((0.0, 0.012, 0.0), (0.120, 0.096, 0.085)),
        belly=((0.0, 0.000, 0.108), (0.114, 0.094, 0.095)),
        chest=((0.0, -0.008, 0.215), (0.138, 0.112, 0.110)),
        shoulder=(0.160, 0.020, 0.255), shoulder_r=0.050,
        upper=(0.155, 0.042, 0.035), fore=(0.145, 0.037, 0.029),
        neck=((0.0, 0.022, 0.262), (0.0, 0.004, 0.372), 0.074, 0.060),
        head=(0.0, -0.014, 0.438),
        hand=dict(kind="paw", palm=(0.056, 0.068, 0.036), fingers=(0.018, 0.015, 0.012), finger_r=0.0138,
                  thumb=(0.016, 0.013), thumb_r=0.0125, n=3, curl=(8, 14, 18), spread=10,
                  claw=(0.013, 0.0045)),
        foot=dict(kind="paw", length=0.150, width=0.080, toe_r=0.0170, toe_len=0.036, toes=4, heel=0.034,
                  claw=(0.013, 0.0048)),
        tail=dict(points=((0.0, 0.098, 0.040), (0.0, 0.158, 0.048), (0.0, 0.214, 0.078), (0.0, 0.256, 0.126),
                          (0.0, 0.272, 0.178)),
                  radii=(0.026, 0.031, 0.031, 0.024, 0.008), tufts=0),
        jumper=dict(ease=0.013, hem=0.035, sleeve=0.64, v_depth=0.062, v_slope=2.1),
        trousers=dict(ease=0.007, waist=0.080, hem_above_knee=0.026, leg_r=0.016, crotch=0.024),
    ),
    "cat": dict(
        ankle_z=0.056, shin=0.214, thigh=0.190, pelvis_up=0.040, leg_x=0.064,
        thigh_r=(0.054, 0.039), shin_r=(0.037, 0.022), calf=0.011,
        pelvis=((0.0, 0.010, 0.0), (0.100, 0.080, 0.072)),
        belly=((0.0, 0.000, 0.095), (0.090, 0.077, 0.082)),
        chest=((0.0, -0.004, 0.188), (0.108, 0.088, 0.096)),
        shoulder=(0.128, 0.018, 0.230), shoulder_r=0.040,
        upper=(0.134, 0.031, 0.025), fore=(0.126, 0.026, 0.0195),
        neck=((0.0, 0.014, 0.236), (0.0, 0.000, 0.306), 0.052, 0.040),
        head=(0.0, -0.010, 0.356),
        hand=dict(kind="paw", palm=(0.044, 0.052, 0.028), fingers=(0.014, 0.012, 0.010), finger_r=0.0108,
                  thumb=(0.013, 0.011), thumb_r=0.0098, n=3, curl=(8, 14, 18), spread=10, claw=None),
        foot=dict(kind="paw", length=0.120, width=0.064, toe_r=0.0140, toe_len=0.028, toes=4, heel=0.028,
                  claw=None),
        tail=dict(points=((0.0, 0.085, 0.030), (0.0, 0.150, -0.010), (0.0, 0.225, 0.010), (0.0, 0.272, 0.090),
                          (0.0, 0.272, 0.185), (0.0, 0.236, 0.250), (0.0, 0.196, 0.262)),
                  radii=(0.020, 0.018, 0.017, 0.016, 0.015, 0.014, 0.010), tufts=0),
        jumper=dict(ease=0.011, hem=0.032, sleeve=0.64, v_depth=0.080, v_slope=1.3),
        trousers=dict(ease=0.008, waist=0.072, hem_above_knee=0.024, leg_r=0.014, crotch=0.022),
    ),
    "bear": dict(
        ankle_z=0.074, shin=0.168, thigh=0.180, pelvis_up=0.048, leg_x=0.112,
        thigh_r=(0.092, 0.070), shin_r=(0.068, 0.054), calf=0.010,
        pelvis=((0.0, 0.016, 0.0), (0.178, 0.132, 0.110)),
        belly=((0.0, -0.028, 0.140), (0.200, 0.168, 0.150)),
        chest=((0.0, 0.000, 0.272), (0.198, 0.150, 0.140)),
        shoulder=(0.214, 0.022, 0.318), shoulder_r=0.072,
        upper=(0.140, 0.064, 0.054), fore=(0.124, 0.054, 0.046),
        neck=((0.0, 0.020, 0.34), (0.0, -0.006, 0.44), 0.104, 0.090),
        head=(0.0, -0.026, 0.500),
        hand=dict(kind="paw", palm=(0.070, 0.104, 0.048), fingers=(0.018, 0.015, 0.012), finger_r=0.0158,
                  thumb=(0.018, 0.015), thumb_r=0.0158, n=4, curl=(8, 14, 16), spread=6,
                  claw=(0.026, 0.0062)),
        foot=dict(kind="paw", length=0.192, width=0.108, toe_r=0.0170, toe_len=0.032, toes=5, heel=0.046,
                  claw=(0.024, 0.0060), arc=0.25),
        tail=None,
        jumper=dict(ease=0.015, hem=0.040, sleeve=0.70, v_depth=0.095, v_slope=1.25),
        trousers=dict(ease=0.010, waist=0.090, hem_above_knee=0.028, leg_r=0.018, crotch=0.028),
    ),
}


class Animal:
    """An animal's joints (T-pose, facing -y, its left on +x) and the
    shapes they carry."""

    def __init__(self, name, legs=None):
        self.name = name
        P = dict(ANIMALS[name])
        self.P = P
        if name == "owl":
            # The legs below the shorts: OWL_EXPOSED (the owl today) times `legs`;
            # the shorts end hem_above_knee over the knee.
            exposed = OWL_EXPOSED * (legs if legs else OWL_LEGS)
            P["shin"] = exposed + CUFF_DROP - P["trousers"]["hem_above_knee"] - P["ankle_z"]
        self.ankle_z = P["ankle_z"]
        self.knee_z = self.ankle_z + P["shin"]
        self.hipj_z = self.knee_z + P["thigh"]
        self.pz = pz = self.hipj_z + P["pelvis_up"]
        lx = P["leg_x"]
        self.hipj = V(lx, 0.012, self.hipj_z)
        self.knee = V(lx * 0.96, -0.004, self.knee_z)
        self.ankle = V(lx, 0.016, self.ankle_z)
        sx, sy, su = P["shoulder"]
        self.shoulder = V(sx, sy, pz + su)
        self.clavicle = V(sx * 0.32, sy, pz + su - 0.014)
        self.elbow = self.shoulder + V(P["upper"][0], 0.010, 0.0)
        self.wrist = self.elbow + V(P["fore"][0], -0.010, 0.0)
        (n0, n1, nr0, nr1) = P["neck"]
        self.neck0 = V(*n0) + V(0, 0, pz)
        self.neck1 = V(*n1) + V(0, 0, pz)
        self.neck_r = (nr0, nr1)
        self.head_c = V(*P["head"]) + V(0, 0, pz)
        self.parts = {}

    def at(self, off):
        return V(*off) + V(0, 0, self.pz)

    # -------------------------------------------------------- the trunk
    def trunk_shapes(self):
        P = self.P
        pel = S.ellipsoid(self.at(P["pelvis"][0]), P["pelvis"][1])
        bel = S.ellipsoid(self.at(P["belly"][0]), P["belly"][1])
        che = S.ellipsoid(self.at(P["chest"][0]), P["chest"][1])
        return pel, bel, che

    def shoulder_caps(self):
        r = self.P["shoulder_r"]
        return [S.sphere(self.shoulder * V(s, 1, 1) + V(-s * r * 0.35, 0, -r * 0.15), r) for s in (1, -1)]

    def upper_arm(self, s=1):
        P = self.P
        sh = self.shoulder * V(s, 1, 1)
        el = self.elbow * V(s, 1, 1)
        return S.round_cone(sh, el, P["upper"][1], P["upper"][2])

    def trunk(self):
        pel, bel, che = self.trunk_shapes()
        k = 0.05
        t = S.smooth([pel, bel, che], k)
        t = S.smooth([t] + self.shoulder_caps(), 0.04)
        return t

    def neck(self):
        return S.round_cone(self.neck0, self.neck1, self.neck_r[0], self.neck_r[1])

    # -------------------------------------------------------- limbs
    def arm(self, s=1):
        """Upper arm and forearm (the hand on its own)."""
        P = self.P
        el = self.elbow * V(s, 1, 1)
        wr = self.wrist * V(s, 1, 1)
        up = self.upper_arm(s)
        fo = S.round_cone(el, wr, P["fore"][1], P["fore"][2])
        # the forearm's muscle, toward the elbow, on top and behind
        bul = S.ellipsoid(lerp(el, wr, 0.3) + V(0, 0.004, 0.004), (P["fore"][0] * 0.32, P["fore"][1] * 1.02, P["fore"][1] * 1.0))
        return S.smooth([up, fo, bul], 0.02)

    def thigh(self, s=1):
        P = self.P
        return S.round_cone(self.hipj * V(s, 1, 1), self.knee * V(s, 1, 1), P["thigh_r"][0], P["thigh_r"][1])

    def leg(self, s=1):
        P = self.P
        kn = self.knee * V(s, 1, 1)
        an = self.ankle * V(s, 1, 1)
        th = self.thigh(s)
        sh = S.round_cone(kn, an, P["shin_r"][0], P["shin_r"][1])
        bits = [th, sh, S.sphere(kn + V(0, -P["shin_r"][0] * 0.45, 0.004), P["shin_r"][0] * 0.82)]
        if P["calf"]:
            c = lerp(kn, an, 0.30) + V(0, P["calf"], 0)
            bits.append(S.ellipsoid(c, (P["shin_r"][0] * 0.82, P["shin_r"][0] * 0.78, (kn[2] - an[2]) * 0.26)))
        return S.smooth(bits, 0.03)

    # -------------------------------------------------------- hands
    def hand(self, s=1):
        """The hand off the left wrist (mirrored for s = -1): a thick palm,
        its fingers and thumb, and their joints. A paw's fingers are short
        and round-ended, a claw over each tip and a pad under it and under
        the palm; the owl's are longer, for its feathered wing-hand."""
        H = self.P["hand"]
        W = self.wrist.copy()
        pl, pw, pt = H["palm"]
        paw = H["kind"] == "paw"
        shapes, pads, claws = [], [], []
        shapes.append(S.ellipsoid(W + V(pl * 0.50, 0.0, -pt * 0.04), (pl * 0.60, pw * 0.50, pt * 0.50)))
        shapes.append(S.ellipsoid(W + V(pl * 0.14, 0.0, -pt * 0.08), (pl * 0.32, pw * 0.42, pt * 0.46)))
        joints = {}
        n = H["n"]
        fr = H["finger_r"]
        span = pw * 0.5 - fr * 1.02
        names = ["index", "middle", "ring", "pinky"][:n]
        for i, nm in enumerate(names):
            u = (i / (n - 1)) * 2.0 - 1.0 if n > 1 else 0.0
            y = u * span
            d = rotate(V(1, 0, 0), "z", u * H["spread"])
            # the middle ones reach a little further
            reach = 1.0 - abs(u) * 0.18
            p = W + V(pl * 0.86, y, -pt * 0.04)
            pts = [p.copy()]
            for L, c in zip(H["fingers"], H["curl"]):
                axis = unit(np.cross(V(0, 0, 1), d))
                d = S.rot(axis, c) @ d
                p = p + d * L * reach
                pts.append(p.copy())
            joints[nm] = pts
            if paw:
                rs = [fr * 1.05, fr * 1.0, fr * 0.97, fr * 0.95]
            else:
                rs = [fr * 1.05, fr * 0.92, fr * 0.74, fr * 0.42]
            shapes.append(S.smooth([S.round_cone(pts[j], pts[j + 1], rs[j], rs[j + 1]) for j in range(3)], 0.004))
            if paw:
                pads.append(S.sphere(pts[3] + d * fr * 0.15 + V(0, 0, -fr * 0.42), fr * 0.72))
                pads.append(S.sphere(pts[0] + V(fr * 0.2, 0, -pt * 0.36), fr * 0.82))
            if H["claw"]:
                L, r = H["claw"]
                down = unit(S.rot(unit(np.cross(V(0, 0, 1), d)), 38) @ d)
                base = pts[3] - d * fr * 0.35 + V(0, 0, fr * 0.62)
                mid = base + d * L * 0.55 + V(0, 0, r * 0.4)
                claws.append(S.smooth([S.round_cone(base, mid, r, r * 0.72),
                                       S.round_cone(mid, mid + down * L * 0.55, r * 0.72, r * 0.15)], 0.002))
        if n == 3:
            joints["pinky"] = [q + V(-0.006, 0.004, 0) for q in joints["ring"]]
        # the thumb: low on the palm's front, out forward and down
        T = W + V(pl * 0.32, -pw * 0.40, -pt * 0.16)
        d = unit(V(0.55, -0.72, -0.42))
        pts = [T.copy()]
        p = T.copy()
        for L in (H["thumb"][0] * 0.6,) + tuple(H["thumb"]):
            p = p + d * L
            pts.append(p.copy())
            d = unit(d + V(0.20, 0.06, -0.04))
        joints["thumb"] = pts
        tr = H["thumb_r"]
        if paw:
            trs = [tr * 1.12, tr * 1.06, tr * 1.0, tr * 0.95]
        else:
            trs = [tr * 1.1, tr * 0.98, tr * 0.88, tr * 0.72]
        shapes.append(S.smooth([S.round_cone(pts[j], pts[j + 1], trs[j], trs[j + 1]) for j in range(3)], 0.005))
        if paw:
            pads.append(S.sphere(pts[3] + V(0, 0, -tr * 0.45), tr * 0.7))
        if H["claw"]:
            L, r = H["claw"]
            base = pts[3] - d * tr * 0.3 + V(0, 0, tr * 0.55)
            claws.append(S.round_cone(base, base + unit(d + V(0, 0, -0.55)) * L * 0.85, r, r * 0.15))
        if paw:
            pads.append(S.ellipsoid(W + V(pl * 0.52, 0.0, -pt * 0.40), (pl * 0.30, pw * 0.32, pt * 0.18)))
        hand = S.smooth(shapes, 0.010 if paw else 0.008)
        feathers = None
        if H["kind"] == "wing":
            feathers = self.wing_fringe()
        if s == -1:
            hand = _mirror_x(hand)
            pads = [_mirror_x(p) for p in pads]
            claws = [_mirror_x(c) for c in claws]
            feathers = _mirror_x(feathers) if feathers is not None else None
        return hand, pads, claws, feathers, joints

    def wing_fringe(self):
        """The owl's wing-arm: flight feathers in a row off the back edge
        of the forearm and on along the outer edge of the hand, longest
        at the hand (its primaries), so the wing's outline runs off the
        arm without a break."""
        P = self.P
        el, wr = self.elbow, self.wrist
        H = P["hand"]
        reach = H["palm"][0] + sum(H["fingers"]) * 0.55
        out = []
        n = 10
        for i in range(n):
            t = i / (n - 1)
            along = lerp(el + V(0.026, 0, 0), wr + V(reach, 0, 0), t)
            on_hand = along[0] > wr[0]
            r_arm = lerp(P["fore"][1], P["fore"][2], min(t * 1.25, 1.0))
            root = along + V(0.0, (H["palm"][1] * 0.42 if on_hand else r_arm * 0.55), -r_arm * 0.20)
            length = 0.048 + 0.052 * min(t / 0.8, 1.0) ** 1.2
            d = unit(V(0.12 + 0.95 * t ** 1.6, 1.0, -0.30))
            out.append(leaf(root - d * 0.006, d, length + 0.006, 0.030, 0.0095, up=V(0, 0, 1)))
        return S.smooth(out, 0.006)

    # -------------------------------------------------------- feet
    def foot(self, s=1):
        """A plantigrade paw: the heel under and behind the ankle, the
        foot's body arched forward to a row of round toes (a groove
        between each), claws over the toes' fronts, the sole flat on the
        ground with its pads."""
        F = self.P["foot"]
        if F["kind"] == "bird":
            return self.bird_foot(s)
        A = self.ankle.copy()
        L, w, tr, tl = F["length"], F["width"], F["toe_r"], F["toe_len"]
        x = A[0]
        back = A[1] + F["heel"] * 0.85
        front = back - L
        hz = F["heel"]
        heel = S.ellipsoid(V(x, back - hz * 0.95, hz * 0.92), (w * 0.38, hz * 0.98, hz * 0.92))
        body = S.ellipsoid(V(x, lerp(back, front, 0.45), hz * 0.78), (w * 0.47, L * 0.30, hz * 0.80))
        instep = S.round_cone(V(x, A[1] - 0.006, A[2] * 0.85), V(x, lerp(back, front, 0.66), tr * 1.25), hz * 0.62, tr * 1.1)
        toes, pads, claws = [], [], []
        nt = F["toes"]
        gap = tr * 0.12
        width_used = nt * 2 * tr * 0.96 + (nt - 1) * gap
        for i in range(nt):
            u = (i - (nt - 1) / 2.0)
            tx = x + u * (2 * tr * 0.96 + gap) * min(1.0, (w - tr * 0.2) / width_used)
            arc = (abs(u) / max((nt - 1) / 2.0, 1.0)) ** 2 * tl * F.get("arc", 0.45)
            ty = front + tl * 0.55 + arc
            c = V(tx, ty, tr * 0.96)
            toes.append(S.ellipsoid(c, (tr * 0.96, tl * 0.55, tr * 0.98)))
            pads.append(S.ellipsoid(c + V(0, -tl * 0.05, -tr * 0.62), (tr * 0.66, tl * 0.36, tr * 0.38)))
            if F["claw"]:
                cl, cr = F["claw"]
                base = c + V(0, -tl * 0.30, tr * 0.55)
                mid = base + V(u * 0.002, -cl * 0.5, -cr * 0.1)
                claws.append(S.smooth([S.round_cone(base, mid, cr, cr * 0.75),
                                       S.round_cone(mid, mid + V(0, -cl * 0.35, -tr * 0.9), cr * 0.75, cr * 0.15)], 0.002))
        pads.append(S.ellipsoid(V(x, lerp(back, front, 0.62), 0.0), (w * 0.32, L * 0.10, 0.010)))
        pads.append(S.ellipsoid(V(x, back - hz * 0.9, 0.0), (w * 0.24, hz * 0.7, 0.010)))
        foot = S.smooth([heel, body, instep], 0.022)
        foot = S.smooth([foot] + toes, 0.007)
        # standing on the ground: a flat sole
        foot = S.cut(foot, below(0.0), 0.003)
        if s == -1:
            foot = _mirror_x(foot)
            pads = [_mirror_x(p) for p in pads]
            claws = [_mirror_x(c) for c in claws]
        return foot, pads, claws

    def bird_foot(self, s=1):
        """Three toes forward, one back, out of a padded root; each toe
        arched over its knuckles and ending in a hooked talon that reaches
        the ground."""
        A = self.ankle.copy()
        root = V(A[0], A[1] - 0.006, 0.020)
        base = S.ellipsoid(root + V(0, 0, 0.004), (0.026, 0.026, 0.018))
        toes, pads, claws = [base], [], []
        specs = [(-28.0, (0.026, 0.020, 0.016)), (0.0, (0.030, 0.023, 0.018)), (28.0, (0.026, 0.020, 0.016)),
                 (180.0 - 12.0, (0.020, 0.016, 0.0))]
        for ang, lens in specs:
            d = rotate(V(0, -1, 0), "z", ang)
            p = root + d * 0.006
            heights = [0.019, 0.017, 0.013, 0.010]
            rs = [0.0125, 0.0112, 0.0098, 0.0082]
            pts = [V(p[0], p[1], heights[0])]
            for j, L in enumerate(lens):
                if L <= 0:
                    break
                p = p + d * L
                pts.append(V(p[0], p[1], heights[j + 1]))
            segs = [S.round_cone(pts[j], pts[j + 1], rs[j], rs[j + 1]) for j in range(len(pts) - 1)]
            # knuckles a touch proud of the toe
            for q in pts[1:-1]:
                segs.append(S.sphere(q + V(0, 0, 0.002), rs[1] * 1.02))
                pads.append(S.sphere(q + V(0, 0, -0.006), rs[1] * 0.9))
            toes.append(S.smooth(segs, 0.004))
            tip = pts[-1]
            # the talon: hooked, its point at the ground
            c0 = tip + d * 0.003 + V(0, 0, 0.002)
            c1 = c0 + d * 0.012 + V(0, 0, 0.000)
            c2 = c1 + d * 0.006 + V(0, 0, -0.010)
            claws.append(S.smooth([S.round_cone(c0, c1, 0.0062, 0.0042), S.round_cone(c1, c2, 0.0042, 0.0011)], 0.002))
        foot = S.smooth(toes, 0.008)
        foot = S.cut(foot, below(0.0), 0.003)
        if s == -1:
            foot = _mirror_x(foot)
            pads = [_mirror_x(p) for p in pads]
            claws = [_mirror_x(c) for c in claws]
        return foot, pads, claws

    def ankle_fluff(self, s=1):
        """The owl's feathered legs end in a skirt of big pointed feathers
        over the toes' roots."""
        A = self.ankle.copy()
        out = []
        for i in range(7):
            a = (i + 0.5) / 7.0 * 2 * math.pi
            d = V(math.sin(a), -math.cos(a), 0.0)
            root = V(A[0], A[1], A[2] + 0.034) + d * 0.030
            out.append(leaf(root, d * 0.62 + V(0, 0, -1.0), 0.048, 0.034, 0.011, up=d))
        f = S.smooth(out, 0.006)
        return _mirror_x(f) if s == -1 else f

    # -------------------------------------------------------- tails
    def tail(self):
        T = self.P.get("tail")
        if self.name == "owl":
            return self.owl_tail()
        if not T:
            return None
        base = V(0, 0, self.pz)
        pts = [base + V(*p) for p in T["points"]]
        sp, sr = spline(pts, T["radii"])
        t = S.smooth([S.round_cone(sp[i], sp[i + 1], sr[i], sr[i + 1]) for i in range(len(sp) - 1)], 0.004)
        bits = [t]
        # the root: grows out of the rump, not stuck on
        bits.append(S.ellipsoid(pts[0] + V(0, -0.008, 0.004), (T["radii"][0] * 1.3, T["radii"][0] * 1.2, T["radii"][0] * 1.35)))
        for i in range(T.get("tufts", 0)):
            u = 0.35 + 0.5 * i / max(T["tufts"] - 1, 1)
            j = min(int(u * (len(pts) - 1)), len(pts) - 2)
            f = u * (len(pts) - 1) - j
            p = lerp(pts[j], pts[j + 1], f)
            d = unit(pts[j + 1] - pts[j])
            r = lerp(T["radii"][j], T["radii"][j + 1], f)
            under = unit(np.cross(d, V(1, 0, 0)))
            for sd in (-1, 1):
                root = p + under * r * 0.4 + V(sd * r * 0.45, 0, 0)
                bits.append(clump(root, d * 0.8 + under * 0.5 + V(sd * 0.25, 0, 0), r * 1.5, r * 0.55))
        return S.smooth(bits, 0.012)

    def owl_tail(self):
        """A short folded tail: five feathers, in a narrow fan, down and
        out behind from under the jumper."""
        root = V(0, 0.092, self.pz + 0.020)
        out = []
        for i, ang in enumerate((-20, -10, 0, 10, 20)):
            d = rotate(unit(V(0, 0.75, -1.0)), "y", ang * 0.9)
            d = unit(d + V(0, 0.06 * (2 - abs(i - 2)), 0))
            out.append(leaf(root + V(math.sin(math.radians(ang)) * 0.024, -0.004 * abs(i - 2), 0), d,
                            0.135 - 0.012 * abs(i - 2), 0.040, 0.012, up=V(0, 1, 0.75)))
        return S.smooth(out, 0.006)

    # -------------------------------------------------------- body
    def body(self):
        """The whole animal as one surface; with its zones (eyes, pads and
        noses, claws and beaks)."""
        trunk = self.trunk()
        neck = self.neck()
        head, h_eyes, h_skin, h_horn, self.head_info = HEADS[self.name](self)
        arms = [S.smooth([self.arm(s)], 0.0) for s in (1, -1)]
        hands, pads, claws, fringes = [], [], [], []
        for s in (1, -1):
            hd, pd, cl, fe, joints = self.hand(s)
            hands.append(hd)
            pads += pd
            claws += cl
            if fe is not None:
                fringes.append(fe)
            if s == 1:
                self.fingers = joints
        legs, feet = [], []
        for s in (1, -1):
            legs.append(self.leg(s))
            ft, pd, cl = self.foot(s)
            feet.append(ft)
            pads += pd
            claws += cl
            if self.name == "owl":
                legs.append(self.ankle_fluff(s))
        tail = self.tail()
        upper = S.smooth([trunk, neck], 0.045)
        upper = S.smooth([upper, head], 0.035)
        limbs_a = [S.smooth([a, h], 0.012) for a, h in zip(arms, hands)]
        limbs_a = [S.smooth([a] + ([f] if f is not None else []), 0.010) for a, f in
                   zip(limbs_a, fringes if fringes else [None, None])]
        limbs_l = [S.smooth([l, f], 0.020) for l, f in zip(legs[::2] if self.name == "owl" else legs, feet)]
        if self.name == "owl":
            limbs_l = [S.smooth([l, fl], 0.008) for l, fl in zip(limbs_l, legs[1::2])]
        body = S.smooth([upper] + limbs_a, 0.035)
        body = S.smooth([body] + limbs_l, 0.040)
        if tail is not None:
            body = S.smooth([body, tail], 0.018)
        horn = S.union(claws) if claws else None
        if horn is not None:
            body = S.union([body, horn])
        self.tail_node = tail
        labels = []
        if horn is not None:
            labels.append((HORN, horn))
        if pads:
            labels.append((PAD, S.union(pads)))
        # the eyes, the nose or beak: their own pieces (clean edges where
        # the lids and the face meet them; rigid with the head)
        self.face = [(EYE, e) for e in h_eyes] + [(SKIN, n) for n in h_skin] + [(HORN, b) for b in h_horn]
        return body, labels

    # -------------------------------------------------------- jumper
    def jumper(self):
        J = self.P["jumper"]
        pel, bel, che = self.trunk_shapes()
        core = S.smooth([pel, bel, che] + self.shoulder_caps(), 0.06)
        arms = [self.upper_arm(s) for s in (1, -1)]
        core = S.smooth([core] + arms, 0.05)
        ease = J["ease"]
        hem = self.pz + J["hem"]
        band_h = 0.032
        shell = S.offset(core, ease)
        top = S.inter(shell, above(hem + band_h - 0.004))
        band = S.inter(S.offset(core, ease - 0.002), slab(hem, hem + band_h))
        jumper = S.smooth([top, band], 0.010)
        # the bottom edge of the rib: rounded off
        jumper = S.cut(jumper, below(hem), 0.004)
        # sleeves: end part way down the upper arm, a rolled cuff there
        sx = self.shoulder[0] + (self.elbow[0] - self.shoulder[0]) * J["sleeve"]
        jumper = S.inter(jumper, S.box(V(0, 0, self.pz), V(sx, 1.0, 1.5)))
        cuffs = []
        for s in (1, -1):
            c = lerp(self.shoulder, self.elbow, J["sleeve"]) * V(s, 1, 1)
            r_arm = lerp(self.P["upper"][1], self.P["upper"][2], J["sleeve"])
            cuffs.append(S.torus(c + V(-s * 0.006, 0, 0), V(1, 0, 0), r_arm + ease + 0.004, 0.0105, (1.0, 1.45)))
        # the neck: a hole round it and a V down the front
        cutter = self.neck_cutter()
        rib = S.cut(S.inter(S.offset(core, ease + 0.0035), S.offset(cutter, 0.013)), cutter, 0.0)
        jumper = S.cut(jumper, cutter, 0.004)
        jumper = S.union([jumper, S.inter(rib, above(hem + 0.05))] + cuffs)
        self.jumper_core = core
        self.cutter = cutter
        return jumper

    def neck_cutter(self):
        J = self.P["jumper"]
        n0, n1 = self.neck0, self.neck1
        r0, r1 = self.neck_r
        up = unit(n1 - n0)
        hole = S.union([S.round_cone(n0 - up * 0.03, n1, r0, r1), S.round_cone(n1, n1 + V(0, 0, 0.3), r1, r1)])
        vz = n0[2] - J["v_depth"]
        sl = J["v_slope"]
        a = S.half_space(V(0, 0, vz), unit(V(sl, 0, -1)))
        b = S.half_space(V(0, 0, vz), unit(V(-sl, 0, -1)))
        front = S.half_space(V(0, n0[1] - 0.01, 0), V(0, 1, 0))
        wedge = S.inter(S.inter(a, b), front)
        return S.smooth([hole, wedge], 0.012)

    # -------------------------------------------------------- shorts
    def trousers(self):
        T = self.P["trousers"]
        pel, bel, che = self.trunk_shapes()
        hem = self.knee_z + T["hem_above_knee"]
        waist = self.pz + T["waist"]
        legs = []
        for s in (1, -1):
            h = self.hipj * V(s, 1, 1)
            k = self.knee * V(s, 1, 1)
            r0 = self.P["thigh_r"][0]
            r_hem = lerp(self.P["thigh_r"][0], self.P["thigh_r"][1], (h[2] - hem) / (h[2] - k[2]))
            end = lerp(h, k, (h[2] - hem + 0.03) / (h[2] - k[2]))
            legs.append(S.round_cone(h + V(0, 0, 0.02), end, r0 + 0.004, r_hem + T["leg_r"]))
        seat = S.smooth([pel, S.inter(bel, below(self.pz + T["waist"] + 0.02))], 0.05)
        core = S.smooth([seat] + legs, 0.045)
        ease = T["ease"]
        shorts = S.inter(S.offset(core, ease), slab(hem, waist))
        # the crotch: the legs part below it (at the hips' width for this body)
        cz = self.hipj_z - T["crotch"]
        gap_w = max(self.P["leg_x"] - self.P["thigh_r"][1] - ease - 0.016, 0.006)
        crotch = S.smooth([S.box(V(0, 0, (hem + cz) * 0.5 - 0.05), V(gap_w, 0.4, (cz - hem) * 0.5 + 0.05)),
                           S.capsule(V(0, -0.4, cz), V(0, 0.4, cz), gap_w)], 0.01)
        shorts = S.cut(shorts, crotch, 0.012)
        cuffs = []
        for s in (1, -1):
            h = self.hipj * V(s, 1, 1)
            k = self.knee * V(s, 1, 1)
            c = lerp(h, k, (h[2] - hem - 0.006) / (h[2] - k[2]))
            r_hem = lerp(self.P["thigh_r"][0], self.P["thigh_r"][1], (h[2] - hem) / (h[2] - k[2]))
            cuffs.append(S.torus(c, unit(h - k), r_hem + T["leg_r"] + ease - 0.002, 0.0125, (1.0, 1.35)))
        shorts = S.union([shorts] + cuffs)
        # the fly: a seam down from the button
        self.trouser_core = core
        self.hem_z = hem
        self.waist_z = waist
        return shorts

    def button_and_fly(self, shorts):
        J = self.P["jumper"]
        zb = self.pz + J["hem"] - 0.012
        y = surface_y(shorts, 0.0, zb)
        button = S.ellipsoid(V(0, y - 0.002, zb), (0.0095, 0.0045, 0.0095))
        pts = []
        cz = self.hipj_z - self.P["trousers"]["crotch"]
        for z in np.linspace(zb - 0.016, cz + 0.012, 4):
            pts.append(V(0.0, surface_y(shorts, 0.0, z), z))
        fly = S.tube(pts, [0.0022] * len(pts))
        return button, fly

    # -------------------------------------------------------- collar
    def collar(self):
        return COLLARS.get(self.name, lambda a: None)(self)

    # -------------------------------------------------------- joints
    def joints(self):
        tz = [self.pz, self.pz + 0.09, self.at(self.P["chest"][0])[2], self.neck0[2] + 0.03, self.neck1[2]]
        ty = [0.012, 0.010, 0.004, self.neck0[1], self.neck1[1]]
        trunk = [[0.0, y, z] for y, z in zip(ty, tz)]
        j = {
            "trunk": trunk,
            "head_top": [0.0, self.head_c[1], self.head_info["top"]],
            "clavicle": list(self.clavicle), "shoulder": list(self.shoulder), "elbow": list(self.elbow),
            "wrist": list(self.wrist),
            "thigh": list(self.hipj), "knee": list(self.knee), "ankle": list(self.ankle),
        }
        F = self.P["foot"]
        if F["kind"] == "bird":
            j["ball"] = list(V(self.ankle[0], self.ankle[1] - 0.030, 0.014))
            j["toe"] = list(V(self.ankle[0], self.ankle[1] - 0.075, 0.008))
        else:
            j["ball"] = list(V(self.ankle[0], self.ankle[1] - F["length"] * 0.62, 0.016))
            j["toe"] = list(V(self.ankle[0], self.ankle[1] - F["length"] * 0.86, 0.010))
        for nm, pts in self.fingers.items():
            j[nm] = [list(map(float, p)) for p in pts]
        j = {k: ([list(map(float, p)) for p in v] if isinstance(v[0], (list, np.ndarray)) else list(map(float, v)))
             for k, v in j.items()}
        j["size"] = 1.0
        j["ref_hips"] = 0.603
        j["fingers"] = ["thumb", "index", "middle", "ring"] + (["pinky"] if self.P["hand"]["n"] > 3 else [])
        # How the greybox's one body is weighted (owl_character.bind):
        # rigid with the head above the neck's top (blended over the
        # band below), the tail with the hips.
        j["head_rigid"] = [float(self.neck1[2] - 0.035), float(self.neck1[2] + 0.005)]
        j["head_reach"] = float(self.head_info["half_width"] + 0.03)
        if self.tail_node is not None:
            j["tail_box"] = [list(map(float, self.tail_node.lo)), list(map(float, self.tail_node.hi))]
            j["tail_root_y"] = float(self.tail_root_y)
        return j


def _mirror_x(node):
    """node mirrored to the character's other side (x -> -x)."""
    return _Flip(node)


class _Flip(S.Node):
    def __init__(self, a):
        self.a = a
        self.lo = V(-a.hi[0], a.lo[1], a.lo[2])
        self.hi = V(-a.lo[0], a.hi[1], a.hi[2])

    def f(self, P, lo, hi, margin):
        Q = P * V(-1, 1, 1)
        if lo is None:
            return self.a.ev(Q)
        return self.a.ev(Q, V(-hi[0], lo[1], lo[2]), V(-lo[0], hi[1], hi[2]), margin)


def spline(points, radii, per=6):
    """Points and radii through the control points on a Catmull-Rom curve
    (per samples a span), for tubes that bend smoothly."""
    P = [np.asarray(p, dtype=float) for p in points]
    R = list(radii)
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    R = [R[0]] + R + [R[-1]]
    out_p, out_r = [], []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out_p.append(q)
            out_r.append(R[i] + (R[i + 1] - R[i]) * (3 * t2 - 2 * t3))
    out_p.append(P[-2])
    out_r.append(R[-2])
    return out_p, out_r


def surface_r(node, c, d, r1=0.4):
    """How far out from c along d node's surface is (from inside)."""
    d = unit(d)
    rs = np.linspace(0.0, r1, 801)
    vals = node(c[None, :] + rs[:, None] * d[None, :])
    i = int(np.argmax(vals > 0))
    if vals[i] <= 0:
        return r1
    a, b = rs[max(i - 1, 0)], rs[i]
    for _ in range(30):
        m = (a + b) * 0.5
        if node((c + d * m)[None, :])[0] > 0:
            b = m
        else:
            a = m
    return float((a + b) * 0.5)


def surface_y(node, x, z, y0=-0.6, y1=0.2):
    """Where a line along y at (x, z) first meets node's surface from the
    front."""
    ys = np.linspace(y0, y1, 801)
    d = node(np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], axis=1))
    i = int(np.argmax(d < 0))
    if d[i] >= 0:
        return 0.0
    a, b = ys[i - 1], ys[i]
    for _ in range(30):
        m = (a + b) * 0.5
        if node(np.array([[x, m, z]]))[0] < 0:
            b = m
        else:
            a = m
    return float((a + b) * 0.5)


# ---------------------------------------------------------------- heads
# Each: (the head's shapes, eyes, skin (nose leather), horn (beak),
# info {top, half_width}). Local offsets from the head's centre H; the
# face looks down -y.

def lid(c, r, cover=0.35, thick=0.0012, tilt=0.0, s=1):
    """An upper lid over the eye at c (radius r): a cap of a slightly
    bigger sphere above a plane `cover` of the radius above the centre
    (tilt: the outer corner that much higher per unit out)."""
    n = unit(V(s * tilt, 0.0, -1.0))
    return S.inter(S.sphere(c, r + thick), S.half_space(c + V(0, 0, r * cover), n))


def head_owl(an):
    """A horned owl: a broad round head, the facial disc a shallow dish
    round each eye with a raised rim, a V of brows running out into the
    ear tufts, a hooked beak between the eyes."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.014, 0.002), (0.134, 0.112, 0.110))
    face = S.ellipsoid(H + V(0, -0.040, -0.012), (0.124, 0.082, 0.100))
    jowl = S.ellipsoid(H + V(0, -0.030, -0.070), (0.092, 0.070, 0.050))
    head = S.smooth([skull, face, jowl], 0.035)
    dishes = S.union([S.sphere(H + V(s * 0.050, -0.232, 0.004), 0.140) for s in (1, -1)])
    head = S.cut(head, dishes, 0.018)
    rims = []
    for s in (1, -1):
        c = H + V(s * 0.050, -0.092, 0.000)
        rims.append(S.inter(S.torus(c, unit(V(s * 0.25, -1, 0.0)), 0.064, 0.010, (1.0, 1.6)),
                            S.half_space(c + V(s * 0.006, 0, 0), V(-s, 0, 0.0))))
    head = S.smooth([head] + rims, 0.012)
    brows = [S.capsule(H + V(s * 0.010, -0.120, 0.030), H + V(s * 0.086, -0.092, 0.066), 0.0120) for s in (1, -1)]
    head = S.smooth([head] + brows, 0.014)
    # ear tufts: two broad feathers fanned up and out off each brow's end
    tufts = []
    for s in (1, -1):
        root = H + V(s * 0.080, -0.064, 0.076)
        for k, (ox, oz, L, r0) in enumerate(((0.36, 1.0, 0.080, 0.025), (0.80, 0.80, 0.060, 0.021))):
            d = unit(V(s * ox, 0.14 + 0.10 * k, oz))
            tufts.append(clump(root + V(s * 0.004 * k, 0.014 * k, -0.010 * k), d, L, r0, flat=0.48, up=V(0, -1, 0.2)))
    head = S.smooth([head] + tufts, 0.014)
    ec = [H + V(s * 0.049, -0.094, 0.008) for s in (1, -1)]
    eyes = [S.sphere(c, 0.031) for c in ec]
    # upper lids over the top of the eye: a level, steady look
    head = S.smooth([head] + [lid(c, 0.031, 0.40, 0.0025, 0.18, sd) for c, sd in zip(ec, (1, -1))], 0.004)
    beak = S.smooth([S.round_cone(H + V(0, -0.110, 0.026), H + V(0, -0.138, 0.000), 0.019, 0.013),
                     S.round_cone(H + V(0, -0.138, 0.000), H + V(0, -0.148, -0.026), 0.013, 0.0068),
                     S.round_cone(H + V(0, -0.148, -0.026), H + V(0, -0.139, -0.044), 0.0068, 0.0016)], 0.004)
    beak = S.squash(beak, H + V(0, -0.13, 0), (0.82, 1.0, 1.0))
    return head, eyes, [], [beak], {"top": float(H[2] + 0.112), "half_width": 0.138}


def hit(node, start, d, reach=0.3):
    """Where a ray from `start` (inside node) along d leaves it."""
    return np.asarray(start, dtype=float) + unit(d) * surface_r(node, np.asarray(start, dtype=float), d, reach)


def set_eye(head, centre_from, look, r, out=0.45):
    """An eye sat in the face: on the surface where a ray from
    `centre_from` along `look` leaves the head, sunk so `out` of its
    radius stands proud."""
    p = hit(head, centre_from, look)
    return p - unit(look) * r * (1.0 - out * 2.0)


def head_dog(an):
    """A shepherd-type dog: a rounded skull, a clear stop, a muzzle a
    little narrower to its end, the jaw under it, soft brows, drop ears."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.020, 0.024), (0.078, 0.086, 0.076))
    occ = S.sphere(H + V(0, 0.068, 0.034), 0.034)
    cheeks = [S.ellipsoid(H + V(s * 0.046, -0.028, -0.018), (0.032, 0.044, 0.038)) for s in (1, -1)]
    head = S.smooth([skull, occ] + cheeks, 0.030)
    # the muzzle: off the stop (a step down from the forehead), its top
    # running level to the nose
    base = S.ellipsoid(H + V(0, -0.066, -0.026), (0.044, 0.040, 0.040))
    snout = S.box(H + V(0, -0.118, -0.030), V(0.028, 0.054, 0.025), round_r=0.020)
    tip = S.ellipsoid(H + V(0, -0.160, -0.028), (0.026, 0.020, 0.025))
    muz = S.smooth([base, snout, tip], 0.020)
    jaw = S.ellipsoid(H + V(0, -0.096, -0.060), (0.025, 0.056, 0.015))
    chin = S.sphere(H + V(0, -0.136, -0.058), 0.0115)
    head = S.smooth([head, muz], 0.022)
    head = S.smooth([head, jaw, chin], 0.010)
    # the lips' line, its corner turned up a little
    mouth = S.tube([H + V(-0.032, -0.064, -0.042), H + V(-0.028, -0.088, -0.050), H + V(-0.016, -0.132, -0.054),
                    H + V(0, -0.154, -0.053), H + V(0.016, -0.132, -0.054), H + V(0.028, -0.088, -0.050),
                    H + V(0.032, -0.064, -0.042)], [0.0024] * 7)
    head = S.cut(head, mouth, 0.004)
    brows = [S.ellipsoid(H + V(s * 0.033, -0.066, 0.052), (0.018, 0.013, 0.007), S.rot("y", s * 10)) for s in (1, -1)]
    head = S.smooth([head] + brows, 0.012)
    ec = [set_eye(head, H + V(s * 0.036, 0.0, 0.028), V(s * 0.22, -1, 0), 0.0135, 0.42) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0158) for c in ec]), 0.005)
    eyes = [S.sphere(c, 0.0135) for c in ec]
    head = S.smooth([head] + [lid(c, 0.0135, 0.40, 0.0012, 0.15, sd) for c, sd in zip(ec, (1, -1))], 0.002)
    nose = S.smooth([S.box(H + V(0, -0.170, -0.006), V(0.017, 0.010, 0.012), round_r=0.008),
                     S.ellipsoid(H + V(0, -0.174, -0.002), (0.015, 0.008, 0.010))], 0.006)
    head = S.smooth([head, S.offset(nose, -0.003)], 0.006)
    # drop ears: from high on the skull's sides, hanging clear of the
    # cheeks, their lower ends standing off a little more
    ears = []
    for s in (1, -1):
        y = 0.004
        top = hit(head, H + V(0, y, 0.062), V(s, 0, 0.30))
        low = hit(head, H + V(0, y, -0.030), V(s, 0, 0.0))
        bottom = low + V(s * 0.010, 0, 0)
        ly = unit(top - bottom)
        lx = V(0, -1, 0)
        lz = unit(np.cross(lx, ly))
        lx = unit(np.cross(ly, lz))
        R = np.stack([lx, ly, lz], axis=1)
        L = np.linalg.norm(top - bottom)
        poly = [(-0.022, L + 0.006), (0.022, L + 0.006), (0.030, L * 0.62), (0.026, L * 0.22), (0.012, -0.010),
                (-0.004, -0.014), (-0.018, 0.0), (-0.026, L * 0.5)]
        ear = S.plate(bottom + lz * (0.0075 * (1 if s > 0 else -1) * np.sign(lz[0] * s)), R, poly, 0.0035, 0.004)
        fold = S.capsule(top + V(s * 0.002, -0.020, 0.0), top + V(s * 0.002, 0.020, 0.0), 0.0105)
        ears.append(S.smooth([ear, fold], 0.010))
    head = S.smooth([head] + ears, 0.010)
    return head, eyes, [nose], [], {"top": float(H[2] + 0.100), "half_width": 0.105}


def head_cat(an):
    """A small cat's head: round skull, wide cheeks, a short muzzle of
    two whisker pads under a small nose, a neat chin, big upright ears
    set wide, almond eyes."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.010, 0.014), (0.062, 0.064, 0.056))
    cheeks = [S.ellipsoid(H + V(s * 0.034, -0.026, -0.014), (0.034, 0.036, 0.030)) for s in (1, -1)]
    nape = S.ellipsoid(H + V(0, 0.040, -0.030), (0.044, 0.034, 0.040))
    head = S.smooth([skull, nape] + cheeks, 0.022)
    pads = [S.ellipsoid(H + V(s * 0.0118, -0.058, -0.019), (0.0122, 0.0105, 0.0098)) for s in (1, -1)]
    chin = S.ellipsoid(H + V(0, -0.046, -0.034), (0.0100, 0.0090, 0.0072))
    bridge = S.capsule(H + V(0, -0.046, 0.024), H + V(0, -0.064, 0.000), 0.0095)
    head = S.smooth([head, bridge] + pads, 0.010)
    head = S.smooth([head, chin], 0.008)
    nose = S.ellipsoid(H + V(0, -0.069, -0.004), (0.0088, 0.0055, 0.0058))
    head = S.smooth([head, S.offset(nose, -0.0025)], 0.004)
    head = S.cut(head, S.capsule(H + V(0, -0.0725, -0.011), H + V(0, -0.0715, -0.024), 0.0021), 0.002)
    ec = [set_eye(head, H + V(s * 0.028, 0.0, 0.013), V(s * 0.30, -1, 0.0), 0.0152, 0.44) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0170) for c in ec]), 0.004)
    eyes = [S.sphere(c, 0.0152) for c in ec]
    head = S.smooth([head] + [lid(c, 0.0152, 0.46, 0.0013, 0.32, sd) for c, sd in zip(ec, (1, -1))], 0.002)
    brows = [S.ellipsoid(H + V(s * 0.025, -0.050, 0.030), (0.017, 0.011, 0.0065), S.rot("y", s * 16)) for s in (1, -1)]
    head = S.smooth([head] + brows, 0.010)
    ears = []
    for s in (1, -1):
        base = H + V(s * 0.040, 0.004, 0.044)
        tip = H + V(s * 0.062, 0.000, 0.106)
        R = S.rot("z", s * -8)
        e = S.squash(S.round_cone(base, tip, 0.025, 0.0035), lerp(base, tip, 0.45), (1.0, 0.42, 1.0), R)
        hollow = S.squash(S.round_cone(base + V(-s * 0.002, -0.010, 0.010), tip + V(-s * 0.002, -0.006, -0.012),
                                       0.016, 0.002), lerp(base, tip, 0.5) + V(0, -0.008, 0), (1.0, 0.35, 1.0), R)
        ears.append(S.cut(e, hollow, 0.003))
    head = S.smooth([head] + ears, 0.012)
    return head, eyes, [nose], [], {"top": float(H[2] + 0.070), "half_width": 0.072}


def head_bear(an):
    """A bear: a broad skull with small round ears, a deep short muzzle
    (the biggest form on the face) with a broad nose, the eyes small and
    set wide under a low brow, the mouth one clean line with its corners
    a touch up; the cheeks' fur in a few big locks running back."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.022, 0.020), (0.104, 0.098, 0.086))
    cheeks = [S.ellipsoid(H + V(s * 0.066, -0.016, -0.030), (0.050, 0.058, 0.050)) for s in (1, -1)]
    head = S.smooth([skull] + cheeks, 0.035)
    locks = []
    for s in (1, -1):
        for k, (dz, dy) in enumerate(((-0.008, 0.004), (-0.040, 0.018), (-0.070, 0.036))):
            root = H + V(s * 0.098, -0.028 + dy, -0.020 + dz)
            locks.append(clump(root, V(s * 0.45, 0.62, -0.62), 0.052 - 0.006 * k, 0.022, flat=0.55, up=V(s, 0, 0)))
    head = S.smooth([head] + locks, 0.012)
    muz = S.smooth([S.ellipsoid(H + V(0, -0.098, -0.026), (0.056, 0.056, 0.048)),
                    S.ellipsoid(H + V(0, -0.136, -0.022), (0.044, 0.034, 0.040))], 0.02)
    jaw = S.ellipsoid(H + V(0, -0.112, -0.064), (0.038, 0.044, 0.020))
    head = S.smooth([head, muz], 0.026)
    head = S.smooth([head, jaw], 0.014)
    mouth = S.tube([H + V(-0.044, -0.096, -0.046), H + V(-0.034, -0.132, -0.054), H + V(0, -0.150, -0.054),
                    H + V(0.034, -0.132, -0.054), H + V(0.044, -0.096, -0.046)], [0.0026] * 5)
    head = S.cut(head, mouth, 0.004)
    brows = [S.ellipsoid(H + V(s * 0.044, -0.080, 0.048), (0.026, 0.015, 0.009), S.rot("y", s * 6)) for s in (1, -1)]
    head = S.smooth([head] + brows, 0.014)
    ec = [set_eye(head, H + V(s * 0.047, 0.0, 0.024), V(s * 0.20, -1, 0.0), 0.0128, 0.42) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0145) for c in ec]), 0.005)
    eyes = [S.sphere(c, 0.0128) for c in ec]
    head = S.smooth([head] + [lid(c, 0.0128, 0.40, 0.0012, 0.0, sd) for c, sd in zip(ec, (1, -1))], 0.002)
    nose = S.smooth([S.box(H + V(0, -0.168, -0.004), V(0.026, 0.013, 0.017), round_r=0.012),
                     S.ellipsoid(H + V(0, -0.172, 0.002), (0.022, 0.011, 0.013))], 0.006)
    head = S.smooth([head, S.offset(nose, -0.004)], 0.006)
    ears = []
    for s in (1, -1):
        c = H + V(s * 0.080, 0.024, 0.078)
        R = S.rot("y", s * -28)
        e = S.ellipsoid(c, (0.034, 0.016, 0.032), R)
        hollow = S.ellipsoid(c + V(0, -0.010, 0.002), (0.022, 0.010, 0.020), R)
        ears.append(S.cut(e, hollow, 0.004))
    head = S.smooth([head] + ears, 0.012)
    return head, eyes, [nose], [], {"top": float(H[2] + 0.106), "half_width": 0.125}


HEADS = {"owl": head_owl, "dog": head_dog, "cat": head_cat, "bear": head_bear}


# ---------------------------------------------------------------- collars

def collar_owl(an):
    """A small feather ruff round the neck: two rows of pointed feathers
    lying down over the jumper's neckline by a centimetre or so."""
    n0 = an.neck0
    out = []
    r = an.neck_r[0] + 0.006
    for row, (dz, n, L) in enumerate(((0.016, 18, 0.042), (0.036, 15, 0.036))):
        for i in range(n):
            a = (i + 0.5 * row) / n * 2 * math.pi
            d = V(math.sin(a), -math.cos(a), 0.0)
            root = n0 + V(0, 0, dz) + d * (r - 0.008 * row)
            out.append(clump(root, d * 0.70 + V(0, 0, -1.0), L, 0.016, flat=0.45, up=d))
    return S.smooth(out, 0.006), FUR


def collar_dog(an):
    """A neckerchief: a rolled band round the neck just over the collar,
    knotted behind, its triangle lying on the jumper's chest over the V
    (the same dark form from the front and the back)."""
    n0, n1 = an.neck0, an.neck1
    t = 0.42
    c = lerp(n0, n1, t)
    up = unit(n1 - n0)
    r = max(surface_r(an.body_node, c, d) for d in (V(1, 0, 0), V(0, -1, 0), V(0, 1, 0)))
    band = S.torus(c, up, r + 0.001, 0.0095, (1.0, 1.7))
    knot = S.ellipsoid(c + V(0, r + 0.012, -0.004), (0.017, 0.012, 0.014))
    tails = [S.plate(c + V(s * 0.013, r + 0.020, -0.034), S.rot("x", 102) @ S.rot("z", s * 14),
                     [(-0.010, 0.022), (0.010, 0.022), (0.004, -0.026), (-0.006, -0.022)], 0.0025, 0.002)
             for s in (1, -1)]
    # the triangle: from the band's front down over the chest, on the jumper
    ztop = c[2] - 0.010
    ztip = c[2] - 0.112
    ytop = min(surface_y(an.jumper_node, 0.045, ztop), surface_y(an.body_node, 0.0, ztop)) - 0.005
    ytip = min(surface_y(an.jumper_node, 0.0, ztip), surface_y(an.jumper_node, 0.03, ztip)) - 0.005
    top, tip = V(0, ytop, ztop), V(0, ytip, ztip)
    ly = unit(top - tip)
    lx = V(1, 0, 0)
    lz = np.cross(lx, ly)
    R = np.stack([lx, ly, lz], axis=1)
    L = np.linalg.norm(top - tip)
    tri = S.plate(tip + lz * -0.002, R, [(-0.064, L), (0.064, L), (0.012, 0.012), (0.0, 0.0), (-0.012, 0.012)], 0.003, 0.004)
    return S.smooth([band, knot] + tails, 0.006), SCARF, tri


def collar_bear(an):
    """The bear's neck and shoulder fur gathered into big locks: two rows
    rooted on the neck just above the jumper, all running down and back
    over its neckline and onto the shoulders."""
    n0, n1 = an.neck0, an.neck1
    out = []
    for row, (t, n, L, r0) in enumerate(((0.22, 12, 0.074, 0.030), (0.42, 10, 0.064, 0.028))):
        c = lerp(n0, n1, t)
        for i in range(n):
            a = (i + 0.5 * row) / n * 2 * math.pi
            d = V(math.sin(a), -math.cos(a), 0.0)
            r = surface_r(an.body_node, c, d)
            back = max(math.cos(a - math.pi), 0.0)
            side = abs(math.sin(a))
            root = c + d * (r - 0.010)
            way = d * (0.75 + 0.25 * side) + V(0, 0.30 * back, -0.85)
            out.append(clump(root, way, L * (1.0 + 0.30 * back), r0, flat=0.55, up=d))
    return S.smooth(out, 0.010), FUR


COLLARS = {"owl": collar_owl, "dog": collar_dog, "bear": collar_bear}


# ---------------------------------------------------------------- build

def materials():
    mats = []
    for name, v in ZONES:
        m = bpy.data.materials.new("gb_" + name)
        m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = (v, v, v, 1.0)
        b.inputs["Roughness"].default_value = 0.62
        m.diffuse_color = (v, v, v, 1.0)
        mats.append(m)
    return mats


def build(name, out_dir, legs=None, voxel=0.0024, tag=None):
    """The greybox animal into a fresh scene; written out. Returns the
    joints."""
    import time
    bpy.ops.wm.read_factory_settings(use_empty=True)
    an = Animal(name, legs)
    mats = materials()
    t0 = time.time()
    body, labels = an.body()
    an.body_node = body
    T = an.P.get("tail")
    an.tail_root_y = float(an.P["pelvis"][1][1]) if an.name == "owl" else \
        (float(T["points"][0][1]) - 0.010 if T else 0.0)
    ob = S.mesh("owl_body", body, voxel=voxel, materials=mats, labels=labels)
    print("body", len(ob.data.polygons), "%.1fs" % (time.time() - t0))
    if an.face:
        face = S.union([n for _, n in an.face])
        S.mesh("owl_face", face, voxel=voxel * 0.5, materials=mats, labels=[(z, n) for z, n in an.face])
    t0 = time.time()
    jumper = an.jumper()
    an.jumper_node = jumper
    oj = S.mesh("owl_jumper", jumper, voxel=voxel * 1.1, materials=mats)
    oj.data.polygons.foreach_set("material_index", [KNIT] * len(oj.data.polygons))
    shorts = an.trousers()
    button, fly = an.button_and_fly(shorts)
    shorts_cut = S.cut(shorts, fly, 0.0015)
    if an.tail_node is not None:
        # the tail out through the seat: a hemmed hole round it
        shorts_cut = S.cut(shorts_cut, S.offset(an.tail_node, 0.004), 0.004)
    ot = S.mesh("owl_trousers", shorts_cut, voxel=voxel * 1.1, materials=mats)
    ot.data.polygons.foreach_set("material_index", [CLOTH] * len(ot.data.polygons))
    obt = S.mesh("owl_button", button, voxel=0.0012, materials=mats)
    obt.data.polygons.foreach_set("material_index", [BUTTON] * len(obt.data.polygons))
    print("clothes %.1fs" % (time.time() - t0))
    col = an.collar()
    if col is not None:
        node, zone = col[0], col[1]
        if len(col) > 2:
            node = S.union([node] + list(col[2:]))
        oc = S.mesh("owl_ruff", node, voxel=voxel, materials=mats)
        oc.data.polygons.foreach_set("material_index", [zone] * len(oc.data.polygons))
    joints = an.joints()
    joints["neckline"] = neckline(an, jumper)
    os.makedirs(out_dir, exist_ok=True)
    stem = os.path.join(out_dir, tag or name)
    tr = [o for o in bpy.context.scene.objects if o.name == "owl_trousers"][0]
    co = np.array([v.co[:] for v in tr.data.vertices])
    legs_at = (np.abs(co[:, 0]) > an.P["leg_x"] * 0.5) & (np.abs(co[:, 0]) < an.P["leg_x"] * 1.6)
    joints["exposed_leg"] = float(co[legs_at, 2].min())
    with open(stem + "_greybox.json", "w") as fh:
        json.dump(joints, fh, indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=stem + ".blend")
    export_glb(stem + "_greybox.glb")
    return an, joints


# Triangles each part is cut down to in the .glb (the skinned, posed
# tests run on these; the .blend keeps the full surface).
GLB_TRIS = {"owl_body": 48000, "owl_face": 3000, "owl_jumper": 14000, "owl_trousers": 9000,
            "owl_ruff": 7000, "owl_button": 300}


def export_glb(path):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        n = len(o.data.polygons)
        t = GLB_TRIS.get(o.name, 20000)
        if n > t:
            md = o.modifiers.new("cut", "DECIMATE")
            md.ratio = t / n
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True)
    for o in objs:
        for md in [m for m in o.modifiers if m.name == "cut"]:
            o.modifiers.remove(md)


def neckline(an, jumper):
    """The jumper's neckline: [angle about the neck (0 in front, +90 on
    the left), height] - the highest the jumper reaches just outside the
    neck - for weighting the collar by how far above it each point is."""
    J = an.P["jumper"]
    out = []
    n0 = an.neck0
    zs = np.linspace(n0[2] - J["v_depth"] - 0.06, n0[2] + 0.10, 240)
    for i in range(72):
        a = i / 72.0 * 2 * math.pi
        d = V(math.sin(a), -math.cos(a), 0.0)
        p = n0 + d * (an.neck_r[0] + 0.022)
        dj = jumper(np.stack([np.full_like(zs, p[0]), np.full_like(zs, p[1]), zs], axis=1))
        inside = np.where(dj < 0)[0]
        out.append([a, float(zs[inside.max()]) if len(inside) else float(n0[2])])
    return {"centre": [0.0, float(n0[1])], "points": out}


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    legs = None
    voxel = 0.0024
    tag = None
    if "--legs" in args:
        legs = float(args[args.index("--legs") + 1])
    if "--voxel" in args:
        voxel = float(args[args.index("--voxel") + 1])
    if "--tag" in args:
        tag = args[args.index("--tag") + 1]
    build(args[0], os.path.abspath(args[1]), legs, voxel, tag)
    # (Blender as a module can crash tearing down after a glTF export;
    # everything is written by now)
    sys.stdout.flush()
    os._exit(0)
