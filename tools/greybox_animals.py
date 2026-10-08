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
           dog's neckerchief, the bear's fur collar, the sheep's fleece;
           the cat and the deer none).

User request: two more, after the deer and the ram the user gave as
references - a red deer stag (antlers, big ears, a short tail) and a
sheep with a ram's curled horns, white fleece, a dark face and dark lower
legs (so it reads against the cream jumper); both on cloven hooves, their
hands kept fingered to hold the rod.

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
FUR, SKIN, HORN, EYE, KNIT, CLOTH, BUTTON, SCARF, PAD, MUZZLE = range(10)
# Greybox values: one grey for the animal (its pads and muzzle too - their
# own zones, for the colour pass), lighter for the clothes, dark for eyes
# and nose.
ZONES = [("fur", 0.40), ("skin", 0.22), ("horn", 0.55), ("eye", 0.07),
         ("knit", 0.74), ("cloth", 0.56), ("button", 0.30), ("scarf", 0.24), ("pad", 0.40), ("muzzle", 0.40)]
# The owl's legs below its shorts today (hem 0.352 over the ground at -0.004),
# and the share of that it keeps by default (user request: compare 15-20%
# shorter); the turned-back cuff ends this far below the hem it's measured to.
OWL_EXPOSED = 0.356
OWL_LEGS = 0.85
CUFF_DROP = 0.0103
# A claw is coloured as claw where it stands out of the bare finger or toe:
# its zone max(claw, CLAW_OUT - bare) under a voxel - out by CLAW_OUT less a
# voxel (1 mm at the default 2.4 mm).
CLAW_OUT = 0.0034


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


def clump(root, direction, length, r0, flat=0.6, up=V(0, 0, 1), tip_r=0.34):
    """A fur clump: a round cone from r0 at the root to a point (tip_r of
    r0 round), flattened against the surface it grows from."""
    d = unit(direction)
    tip = root + d * length
    c = S.round_cone(root, tip, r0, r0 * tip_r)
    side = np.cross(up, d)
    if np.linalg.norm(side) < 1e-6:
        side = np.cross(V(1, 0, 0), d)
    side = unit(side)
    n = np.cross(d, side)
    R = np.stack([side, d, n], axis=1)
    return S.squash(c, root + d * length * 0.5, (1.0, 1.0, flat), R)


def fold(base, inner, dirs, r, sink=0.72):
    """A cloth fold on `base`'s surface: a low, soft ridge (it stands
    1 - sink of r proud) curving between the points where rays from
    `inner` along `dirs` leave the surface, thinning out at both ends."""
    a = hit(base, inner[0], dirs[0]) - unit(dirs[0]) * r * sink
    b = hit(base, inner[1], dirs[1]) - unit(dirs[1]) * r * sink
    dm = unit(dirs[0] + dirs[1])
    m = hit(base, (inner[0] + inner[1]) * 0.5, dm) - dm * r * sink
    return S.smooth([S.round_cone(a, m, r * 0.55, r), S.round_cone(m, b, r, r * 0.5)], 0.006)


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
        hand=dict(kind="wing", palm=(0.052, 0.056, 0.031), fingers=(0.020, 0.017, 0.014), finger_r=0.0116,
                  thumb=(0.020, 0.016), thumb_r=0.0110, n=3, curl=(8, 14, 18), spread=10, claw=None),
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
        neck=((0.0, 0.024, 0.262), (0.0, 0.010, 0.372), 0.076, 0.066),
        traps=(0.062, 0.062, 0.042, 0.030),
        head=(0.0, -0.014, 0.438),
        hand=dict(kind="paw", palm=(0.056, 0.068, 0.036), fingers=(0.018, 0.015, 0.012), finger_r=0.0138,
                  thumb=(0.016, 0.013), thumb_r=0.0125, n=3, curl=(8, 14, 18), spread=10,
                  claw=(0.013, 0.0045)),
        foot=dict(kind="paw", length=0.150, width=0.080, toe_r=0.0170, toe_len=0.036, toes=4, heel=0.034,
                  claw=(0.013, 0.0048)),
        tail=dict(points=((0.0, 0.098, 0.040), (0.0, 0.150, 0.050), (0.0, 0.196, 0.076), (0.0, 0.228, 0.116),
                          (0.0, 0.244, 0.160), (0.0, 0.244, 0.194)),
                  radii=(0.024, 0.027, 0.025, 0.020, 0.013, 0.006), tufts=0, bones=4),
        jumper=dict(ease=0.013, hem=0.035, sleeve=0.64, v_depth=0.062, v_slope=2.1),
        trousers=dict(ease=0.007, waist=0.080, hem_above_knee=0.026, leg_r=0.016, crotch=0.024),
    ),
    "cat": dict(
        ankle_z=0.056, shin=0.214, thigh=0.190, pelvis_up=0.040, leg_x=0.064,
        thigh_r=(0.054, 0.039), shin_r=(0.037, 0.022), calf=0.011,
        pelvis=((0.0, 0.010, 0.0), (0.100, 0.080, 0.072)),
        belly=((0.0, 0.000, 0.095), (0.090, 0.077, 0.082)),
        chest=((0.0, -0.002, 0.186), (0.094, 0.080, 0.094)),
        shoulder=(0.116, 0.018, 0.226), shoulder_r=0.034,
        upper=(0.134, 0.028, 0.023), fore=(0.126, 0.025, 0.019),
        neck=((0.0, 0.014, 0.236), (0.0, 0.000, 0.306), 0.052, 0.040),
        head=(0.0, -0.010, 0.356),
        hand=dict(kind="paw", palm=(0.044, 0.052, 0.028), fingers=(0.014, 0.012, 0.010), finger_r=0.0108,
                  thumb=(0.013, 0.011), thumb_r=0.0098, n=3, curl=(8, 14, 18), spread=10, claw=None),
        foot=dict(kind="paw", length=0.120, width=0.064, toe_r=0.0140, toe_len=0.028, toes=4, heel=0.028,
                  claw=None),
        tail=dict(points=((0.0, 0.085, 0.030), (0.006, 0.155, 0.006), (0.026, 0.225, 0.018), (0.054, 0.272, 0.062),
                          (0.076, 0.292, 0.120), (0.088, 0.300, 0.172), (0.092, 0.322, 0.206)),
                  radii=(0.019, 0.017, 0.016, 0.015, 0.0135, 0.0115, 0.0075), tufts=0, bones=5),
        jumper=dict(ease=0.010, hem=0.032, sleeve=0.64, v_depth=0.050, v_slope=2.2, pit=0.06),
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
        neck=((0.0, 0.022, 0.34), (0.0, -0.004, 0.425), 0.106, 0.090),
        traps=(0.090, 0.090, 0.060, 0.042),
        head=(0.0, -0.022, 0.482),
        hand=dict(kind="paw", palm=(0.070, 0.104, 0.048), fingers=(0.018, 0.015, 0.012), finger_r=0.0158,
                  thumb=(0.018, 0.015), thumb_r=0.0158, n=4, curl=(8, 14, 16), spread=6,
                  claw=(0.024, 0.0072)),
        foot=dict(kind="paw", length=0.192, width=0.108, toe_r=0.0170, toe_len=0.032, toes=5, heel=0.046,
                  claw=(0.018, 0.0075), arc=0.25),
        tail=None,
        jumper=dict(ease=0.015, hem=0.040, sleeve=0.70, v_depth=0.095, v_slope=1.25),
        trousers=dict(ease=0.010, waist=0.090, hem_above_knee=0.028, leg_r=0.018, crotch=0.028),
    ),
    # a red deer stag: tall and slim, long-legged, a long neck
    "deer": dict(
        ankle_z=0.072, shin=0.258, thigh=0.236, pelvis_up=0.044, leg_x=0.074,
        thigh_r=(0.060, 0.045), shin_r=(0.040, 0.024), calf=0.010,
        pelvis=((0.0, 0.012, 0.0), (0.110, 0.088, 0.080)),
        belly=((0.0, 0.000, 0.104), (0.104, 0.088, 0.092)),
        chest=((0.0, -0.008, 0.212), (0.128, 0.104, 0.106)),
        shoulder=(0.150, 0.020, 0.250), shoulder_r=0.046,
        upper=(0.150, 0.038, 0.031), fore=(0.142, 0.033, 0.025),
        neck=((0.0, 0.022, 0.256), (0.0, 0.002, 0.392), 0.062, 0.050),
        traps=(0.056, 0.056, 0.038, 0.026),
        head=(0.0, -0.016, 0.454),
        hand=dict(kind="paw", palm=(0.050, 0.060, 0.032), fingers=(0.017, 0.014, 0.011), finger_r=0.0122,
                  thumb=(0.015, 0.012), thumb_r=0.0112, n=3, curl=(8, 14, 18), spread=10, claw=None),
        foot=dict(kind="hoof", length=0.084, width=0.060, height=0.040, pastern_r=(0.025, 0.023)),
        tail=dict(points=((0.0, 0.090, 0.044), (0.0, 0.116, 0.064), (0.0, 0.136, 0.060)),
                  radii=(0.021, 0.019, 0.012), tufts=0, bones=2),
        jumper=dict(ease=0.012, hem=0.034, sleeve=0.64, v_depth=0.060, v_slope=2.1),
        trousers=dict(ease=0.007, waist=0.078, hem_above_knee=0.026, leg_r=0.015, crotch=0.024),
    ),
    # a sheep: stocky and round, shorter in the leg, a short thick neck
    "sheep": dict(
        ankle_z=0.066, shin=0.205, thigh=0.208, pelvis_up=0.046, leg_x=0.084,
        thigh_r=(0.070, 0.054), shin_r=(0.043, 0.026), calf=0.010,
        pelvis=((0.0, 0.014, 0.0), (0.134, 0.104, 0.092)),
        belly=((0.0, -0.010, 0.116), (0.140, 0.120, 0.112)),
        chest=((0.0, -0.004, 0.226), (0.150, 0.122, 0.118)),
        shoulder=(0.168, 0.020, 0.264), shoulder_r=0.054,
        upper=(0.146, 0.044, 0.036), fore=(0.136, 0.038, 0.029),
        neck=((0.0, 0.020, 0.280), (0.0, 0.006, 0.364), 0.080, 0.068),
        traps=(0.066, 0.064, 0.044, 0.032),
        head=(0.0, -0.016, 0.438),
        hand=dict(kind="paw", palm=(0.054, 0.064, 0.034), fingers=(0.017, 0.014, 0.012), finger_r=0.0130,
                  thumb=(0.015, 0.012), thumb_r=0.0120, n=3, curl=(8, 14, 18), spread=10, claw=None),
        foot=dict(kind="hoof", length=0.080, width=0.064, height=0.038, pastern_r=(0.027, 0.025)),
        tail=dict(points=((0.0, 0.100, 0.036), (0.0, 0.124, 0.022), (0.0, 0.134, -0.004)),
                  radii=(0.026, 0.024, 0.017), tufts=0, bones=2),
        jumper=dict(ease=0.013, hem=0.036, sleeve=0.66, v_depth=0.070, v_slope=1.8),
        trousers=dict(ease=0.008, waist=0.084, hem_above_knee=0.026, leg_r=0.016, crotch=0.025),
        # its face, forearms, hands and legs below the knee dark (MUZZLE)
        dark_limbs=True,
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

    def quad(self, s=1):
        """The front of the thigh, fuller in its upper half."""
        P = self.P
        hp = self.hipj * V(s, 1, 1)
        kn = self.knee * V(s, 1, 1)
        return S.ellipsoid(lerp(hp, kn, 0.42) + V(s * 0.004, -P["thigh_r"][0] * 0.28, 0),
                           (P["thigh_r"][0] * 0.82, P["thigh_r"][0] * 0.80, (hp[2] - kn[2]) * 0.34))

    def leg(self, s=1):
        P = self.P
        kn = self.knee * V(s, 1, 1)
        an = self.ankle * V(s, 1, 1)
        th = self.thigh(s)
        sh = S.round_cone(kn, an, P["shin_r"][0], P["shin_r"][1])
        bits = [th, self.quad(s), sh, S.sphere(kn + V(0, -P["shin_r"][0] * 0.45, 0.004), P["shin_r"][0] * 0.82)]
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
                rs = [fr * 1.10, fr * 0.98, fr * 0.84, fr * 0.60]
            shapes.append(S.smooth([S.round_cone(pts[j], pts[j + 1], rs[j], rs[j + 1]) for j in range(3)], 0.004))
            if paw:
                pads.append(S.sphere(pts[3] + d * fr * 0.15 + V(0, 0, -fr * 0.42), fr * 0.72))
                pads.append(S.sphere(pts[0] + V(fr * 0.2, 0, -pt * 0.36), fr * 0.82))
            if H["claw"]:
                L, r = H["claw"]
                down = unit(S.rot(unit(np.cross(V(0, 0, 1), d)), 38) @ d)
                # sat on the fingertip's top and standing out past it, so the
                # claw is seen whole (not a sunk root showing through)
                base = pts[3] - d * fr * 0.20 + V(0, 0, fr * 0.78)
                mid = base + d * L * 0.62 + V(0, 0, r * 0.3)
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
        """The owl's wing-arm: a band of coverts along the back edge of the
        forearm, and under it the flight feathers - shorter secondaries off
        the forearm, longer primaries off the outer edge of the hand, the
        last ones shorter again so the wing closes to a point - each a
        little different in length, overlapping, swept back."""
        P = self.P
        el, wr = self.elbow, self.wrist
        H = P["hand"]
        out = []
        # (where along elbow -> hand end, length, width, lift, sweep)
        spec = [(0.05, 0.046, 0.030, 0.0025, 0.00), (0.22, 0.054, 0.031, -0.002, 0.04),
                (0.38, 0.060, 0.030, 0.003, 0.08), (0.54, 0.068, 0.029, -0.0025, 0.13),
                (0.68, 0.074, 0.028, 0.002, 0.20), (0.79, 0.088, 0.026, -0.002, 0.42),
                (0.87, 0.096, 0.025, 0.0025, 0.62), (0.94, 0.090, 0.023, -0.002, 0.82),
                (1.00, 0.072, 0.021, 0.002, 1.05)]
        end = wr + V(H["palm"][0] * 0.95, 0, 0)
        for t, L, w, lift, sweep in spec:
            along = lerp(el + V(0.022, 0, 0), end, t)
            on_hand = along[0] > wr[0]
            r_arm = lerp(P["fore"][1], P["fore"][2], min(t * 1.2, 1.0))
            back = H["palm"][1] * 0.40 if on_hand else r_arm * 0.55
            root = along + V(0.0, back, -r_arm * 0.18 + lift)
            d = unit(V(sweep, 1.0, -0.28))
            out.append(leaf(root - d * 0.008, d, L + 0.008, w, 0.0085, up=V(0, 0, 1)))
        fringe = S.smooth(out, 0.005)
        coverts = S.ellipsoid(lerp(el, wr, 0.5) + V(0.0, P["fore"][1] * 0.75, -0.004),
                              (np.linalg.norm(wr - el) * 0.55, 0.020, 0.010))
        return S.smooth([fringe, coverts], 0.010)

    # -------------------------------------------------------- feet
    def foot(self, s=1):
        """A plantigrade paw: the heel under and behind the ankle, the
        foot's body arched forward to a row of round toes (a groove
        between each), claws over the toes' fronts, the sole flat on the
        ground with its pads."""
        F = self.P["foot"]
        if F["kind"] == "bird":
            return self.bird_foot(s)
        if F["kind"] == "hoof":
            return self.hoof_foot(s)
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
                # rooted in the toe's tip and curving down close round its
                # front to the ground (user request: they stood off in a row
                # ahead of the toes)
                # (user request, round 4: not a row of round blunt teeth -
                # each claw deep at its root, sunk into the toe's top,
                # narrow from side to side, hooking down over the toe to a
                # sharp point, fanned out with its toe; no longer, no higher)
                sp = u * 0.10
                base = c + V(0, -tl * 0.24, tr * 0.42)
                pts = [base, base + V(sp * cl * 0.3, -cl * 0.40, 0.0005), base + V(sp * cl * 0.6, -cl * 0.70, -tr * 0.30),
                       base + V(sp * cl * 0.8, -cl * 0.86, -tr * 0.80), base + V(sp * cl, -cl * 0.90, -tr * 1.15)]
                side = [V(1, 0, 0)] * 5
                claws.append(S.ribbon(pts, [cr * 2.3, cr * 2.0, cr * 1.5, cr * 0.85, cr * 0.18],
                                      [cr * 1.5, cr * 1.25, cr * 0.95, cr * 0.55, cr * 0.15], side))
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

    def hoof_foot(self, s=1):
        """A cloven hoof (the deer, the sheep): the leg's pastern running
        down and a little forward into two rounded halves side by side, a
        cleft between them at the front, flat on the ground. The hoof is
        its own zone (PAD: dark)."""
        F = self.P["foot"]
        A = self.ankle.copy()
        L, w, h = F["length"], F["width"], F["height"]
        x = A[0]
        y0 = A[1] - L * 0.05
        pastern = S.round_cone(V(x, A[1] + 0.004, A[2]), V(x, y0 - L * 0.10, h * 0.90),
                               F["pastern_r"][0], F["pastern_r"][1])
        halves = [S.ellipsoid(V(x + sd * w * 0.24, y0 - L * 0.22, h * 0.52), (w * 0.27, L * 0.50, h * 0.56),
                              S.rot("z", sd * 4)) for sd in (1, -1)]
        hoof = S.smooth(halves, 0.008)
        cleft = S.box(V(x, y0 - L * 0.62, h * 0.5), V(0.0022, L * 0.30, h * 0.8), round_r=0.0015)
        hoof = S.cut(hoof, cleft, 0.0025)
        # (the coronet: the hair just over the hoof's top edge)
        foot = S.smooth([pastern, hoof], 0.010)
        foot = S.cut(foot, below(0.0), 0.003)
        zone = S.cut(S.offset(hoof, 0.0012), above(h * 0.80), 0.002)
        zone = S.cut(zone, below(-0.01))
        if s == -1:
            foot = _mirror_x(foot)
            zone = _mirror_x(zone)
        return foot, [zone], []

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
        """The owl's feathered legs end in a few rounded feathers round the
        back and sides of the ankle - the front left open so the toes'
        roots show and the leg runs into the foot."""
        A = self.ankle.copy()
        out = []
        for deg, L in ((70, 0.030), (115, 0.036), (160, 0.038), (200, 0.038), (245, 0.036), (290, 0.030)):
            a = math.radians(deg)
            d = V(math.sin(a), -math.cos(a), 0.0)
            root = V(A[0], A[1], A[2] + 0.048) + d * 0.030
            out.append(leaf(root, d * 0.55 + V(0, 0, -1.0), L, 0.030, 0.010, up=d))
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
        """A short tail folded into a small fan: five feathers spread from
        one root under the jumper, the middle one longest, overlapping."""
        root = V(0, 0.094, self.pz + 0.020)
        # gathered at one narrow root (a small rump under it), the middle
        # feather on top and longest, the others tucked under it in turn
        # and of slightly different lengths, so the tips step (user
        # request: not a wavy board hanging from a straight line)
        rump = S.ellipsoid(root + V(0, -0.006, 0.004), (0.020, 0.014, 0.016))
        # (user request, round 4: the main feathers told apart - each its
        # own quill-narrow root, broadest past the middle, a rounded tip,
        # layered with a gap between the layers, not blended into a board)
        feathers = []
        # (thick enough for the mesh to hold their edges, each layer a
        # step lower and lifted a little more, so the fan is domed and the
        # layers' edges and tips show)
        for ang, L, layer in ((0, 0.114, 0), (-19, 0.098, 1), (20, 0.094, 1), (-38, 0.080, 2), (39, 0.076, 2)):
            d = rotate(unit(V(0, 0.80 + 0.10 * layer, -1.0)), "y", -ang)
            off = V(math.sin(math.radians(ang)) * 0.010, -0.007 * layer, 0.006 * layer)
            up = unit(rotate(V(0, 1, 0.8), "y", -ang))
            a = root + off
            pts = [a, a + d * L * 0.25 + up * 0.002, a + d * L * 0.55 + up * 0.004, a + d * L * 0.82 + up * 0.003,
                   a + d * L]
            w = 0.033 - 0.002 * layer
            feathers.append(S.ribbon(pts, [w * 0.35, w * 0.82, w, w * 0.90, w * 0.34],
                                     [0.0090, 0.0085, 0.0078, 0.0068, 0.0055], [up] * 5))
        # the shorts open round the root only (cut round the whole fan,
        # their hole's edge followed every feather and came out ragged)
        self.tail_hole = S.ellipsoid(root + V(0, -0.002, 0.000), (0.024, 0.020, 0.020))
        return S.smooth([rump, S.union(feathers)], 0.005)

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
        extra = []
        tr = self.P.get("traps")
        if tr:
            # the neck's root runs out over the shoulders and down the throat
            n0, n1 = self.neck0, self.neck1
            for s in (1, -1):
                extra.append(S.ellipsoid(V(s * tr[0], n0[1] + 0.014, n0[2] + 0.004), (tr[1], tr[2], tr[3]),
                                         S.rot("y", s * 28)))
            extra.append(S.ellipsoid(lerp(n0, n1, 0.55) + V(0, -self.neck_r[1] * 0.55, -0.01),
                                     (self.neck_r[1] * 0.75, self.neck_r[1] * 0.55, (n1[2] - n0[2]) * 0.55)))
        # (the jumper is cut over them too, or they come through it)
        self.traps_nodes = extra[:2]
        upper = S.smooth([trunk, neck] + extra, 0.045)
        upper = S.smooth([upper, head], 0.035)
        if self.name == "dog":
            # the nape dips under the occiput (no long straight line from
            # the crown down to the collar)
            n1 = self.neck1
            upper = S.cut(upper, S.ellipsoid(n1 + V(0, self.neck_r[1] + 0.010, -0.004), (0.046, 0.014, 0.030)), 0.020)
        self.fur_node = None
        if self.name == "bear":
            self.fur_node = bear_fur(self, upper)
            upper = S.smooth([upper, self.fur_node], 0.018)
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
        bare = body
        if horn is not None:
            body = S.union([body, horn])
        self.tail_node = tail
        labels = []
        if horn is not None:
            # claw only where the claw stands out of the finger or toe (user
            # request: bright flecks on the fingers - the faces of the skin
            # over a sunk claw's root were taken for claw)
            # (as one field - claw, and out of the bare body by a millimetre -
            # so its edge can be cut along: sdf_mesh.split_labels)
            labels.append((HORN, lambda P, h=horn, b=bare: np.maximum(h(P), CLAW_OUT - b(P))))
        if pads:
            labels.append((PAD, S.union(pads)))
        if self.P.get("dark_limbs"):
            # (the sheep: its forearms and hands, its legs below the knee,
            # dark like its face)
            dark = [self.muzzle] if getattr(self, "muzzle", None) is not None else []
            for sd in (1, -1):
                el, wr = self.elbow * V(sd, 1, 1), self.wrist * V(sd, 1, 1)
                dark.append(S.capsule(lerp(el, wr, 0.30), wr + V(sd * 0.09, 0, 0), 0.075))
                kn, an_ = self.knee * V(sd, 1, 1), self.ankle * V(sd, 1, 1)
                dark.append(S.capsule(kn + V(0, 0, -0.030), V(an_[0], an_[1], 0.0), 0.070))
            self.muzzle = S.union(dark)
        if getattr(self, "muzzle", None) is not None:
            labels.append((MUZZLE, self.muzzle))
        # the eyes, the nose or beak: their own pieces (clean edges where
        # the lids and the face meet them; rigid with the head)
        self.face = [(EYE, e) for e in h_eyes] + [(SKIN, n) for n in h_skin] + [(HORN, b) for b in h_horn] + \
            [(FUR, l) for l in getattr(self, "lids", [])]
        return body, labels

    # -------------------------------------------------------- jumper
    def ease_field(self, base, top, shoulder_ease):
        """How far a garment stands off the body, point by point: little
        where it rests on the shoulders, more where it hangs (the back's
        and sides' lower half), so it's not one even shell."""
        sz = self.shoulder[2]
        sx = self.shoulder[0]
        lo = self.pz

        def fn(P):
            z = P[:, 2]
            up = np.clip((z - (sz - 0.07)) / 0.07, 0.0, 1.0)
            # on the shoulders' tops only (not out along the sleeves)
            near = np.clip(1.0 - (np.abs(P[:, 0]) - sx * 0.9) / 0.06, 0.0, 1.0)
            rest = shoulder_ease * up * near + base * (1.0 - up * near)
            hang = np.clip(((sz - 0.07) - z) / (sz - 0.07 - lo), 0.0, 1.0)
            back = np.clip(P[:, 1] / 0.08, 0.0, 1.0)
            return -(rest + (top - base) * hang * (0.5 + 0.5 * back))
        return fn

    def jumper_base(self):
        """The jumper's outer shape before its edges: the trunk with fabric
        falling straight from the chest, bridged under the arms."""
        P = self.P
        J = P["jumper"]
        pel, bel, che = self.trunk_shapes()
        hem = self.pz + J["hem"]
        cc, cr = self.at(P["chest"][0]), P["chest"][1]
        # the cloth hangs from the chest to the hem (not tucked under it)
        drop = S.ellipsoid(V(0, cc[1] + cr[1] * 0.08, (cc[2] + hem) * 0.5),
                           (cr[0] * 0.88, cr[1] * 0.90, (cc[2] - hem) * 0.5 + 0.02))
        core = S.smooth([pel, bel, che, drop] + self.shoulder_caps() + getattr(self, "traps_nodes", []), 0.06)
        arms = [self.upper_arm(s) for s in (1, -1)]
        # under the arm the knit bridges arm and side (a wider blend)
        core = S.smooth([core] + arms, J.get("pit", 0.075))
        self.jumper_core = core
        top = J["ease"] + J.get("hang", 0.006)
        return S.Displace(core, self.ease_field(J["ease"], top, J.get("shoulder_ease", 0.008)), top + 0.002)

    def jumper(self):
        J = self.P["jumper"]
        base = self.jumper_base()
        core = self.jumper_core
        ease = J["ease"]
        hem = self.pz + J["hem"]
        # the hem a touch lower behind than in front; the cloth gathered in
        # gradually over its last few centimetres (no band, no step) and its
        # edge a slim rolled lip
        hem_plane = S.half_space(V(0, 0, hem), unit(V(0, 0.10, -1)))
        gather = S.Displace(base, lambda P: 0.005 * np.clip(1.0 - (P[:, 2] - hem) / 0.06, 0.0, 1.0), 0.006)
        jumper = S.inter(gather, hem_plane, 0.008)
        lip = S.inter(S.offset(core, ease - 0.001), S.inter(hem_plane, S.half_space(V(0, 0, hem + 0.009),
                                                                                 unit(V(0, -0.10, 1)))), 0.003)
        jumper = S.smooth([jumper, lip], 0.006)
        # sleeves end part way down the upper arm, in a turned-back cuff
        sleeve_end = []
        cuffs = []
        hollows = []
        for s in (1, -1):
            sh = self.shoulder * V(s, 1, 1)
            el = self.elbow * V(s, 1, 1)
            ax = unit(el - sh)
            c = lerp(sh, el, J["sleeve"])
            # the opening tilted a little (lower behind) so the edge isn't a ring
            n = unit(ax + V(0, 0.16, -0.10))
            end = S.half_space(c, n)
            sleeve_end.append((c, n))
            arm = self.upper_arm(s)
            r_arm = lerp(self.P["upper"][1], self.P["upper"][2], J["sleeve"])
            cuff_h = max(0.022, r_arm * 0.7)
            # the turn-up: a flat band of cloth folded back over the sleeve,
            # standing off it by its thickness, its top edge a step
            band = S.offset(arm, ease + J.get("cuff_out", 0.0055) + 0.003)
            band = S.inter(band, S.inter(end, S.half_space(c - n * cuff_h, -n), 0.003), 0.004)
            cuffs.append(band)
            # the opening is cloth, not solid: hollowed back toward the arm,
            # only as deep as the turn-up and leaving the cloth its
            # thickness (user request: a dark slit above the cuff - hollowed
            # past the band and nearer the surface than the cells, the sleeve
            # broke through there)
            hollows.append(S.inter(S.offset(arm, ease * 0.35), S.half_space(c - n * (cuff_h + 0.002), -n)))
        for c, n in sleeve_end:
            jumper = S.inter(jumper, S.half_space(c, n), 0.003)
        cutter = self.neck_cutter()
        rib = S.cut(S.inter(S.offset(core, ease + 0.0035), S.offset(cutter, 0.012)), cutter, 0.0)
        jumper = S.cut(jumper, cutter, 0.004)
        # nothing of the knit stands up beside the neck above the collar line
        # (round the neck only: the shoulders' tops can be higher than that)
        n0 = self.neck0
        # (widening upward, so the cut runs down the slope of the shoulders)
        r0 = self.neck_r[0] + 0.024
        ring = S.round_cone(V(0, n0[1], n0[2]), V(0, n0[1], n0[2] + 0.2), r0, r0 + 0.09)
        jumper = S.cut(jumper, S.inter(above(n0[2] + 0.028), ring), 0.018)
        jumper = S.union([jumper, S.inter(rib, S.inter(above(hem + 0.05), below(self.neck0[2] + 0.034)))] + cuffs)
        for h in hollows:
            jumper = S.cut(jumper, h, 0.002)
        # the hem's underside is cloth too: hollow it up a little
        jumper = S.cut(jumper, S.inter(S.offset(core, ease - 0.008), below(hem + 0.012)), 0.003)
        jumper = S.smooth([jumper] + self.jumper_folds(base), 0.012)
        if self.fur_node is not None:
            # the bear's locks lie over the knit
            jumper = S.cut(jumper, S.offset(self.fur_node, 0.003), 0.006)
        self.cutter = cutter
        return jumper

    def jumper_folds(self, base):
        """A few big folds where the cloth is pulled: from under each arm
        down across the chest's side, front and back."""
        J = self.P["jumper"]
        sz = self.shoulder[2]
        out = []
        r = J.get("fold_r", 0.011)
        for s in (1, -1):
            sx = self.shoulder[0] * s
            # under the arm, front and back
            for side in (-1, 1):
                a = V(sx * 0.80, side * 0.01, sz - 0.05)
                b = V(sx * 0.52, side * 0.02, sz - 0.13)
                out.append(fold(base, [a, b], [V(s * 0.25, side, 0.05), V(s * 0.4, side, -0.1)], r))
        return out

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
        """The shorts off the body's hips and thighs: each leg a tube a
        little roomier on its outside than its inside (so the inner edges
        follow the thigh and part below the crotch), the two blended at
        the top into a rounded crotch and the seat, a turned-back cuff
        at each leg's hem, the openings hollow."""
        T = self.P["trousers"]
        pel, bel, che = self.trunk_shapes()
        hem = self.knee_z + T["hem_above_knee"]
        waist = self.pz + T["waist"]
        ease = T["ease"]
        legs, cuffs, hollows, ends = [], [], [], []
        for s in (1, -1):
            h = self.hipj * V(s, 1, 1)
            k = self.knee * V(s, 1, 1)
            t_hem = (h[2] - hem) / (h[2] - k[2])
            r0, r1 = self.P["thigh_r"]
            r_hem = lerp(r0, r1, t_hem)
            loose = T["leg_r"]
            end = lerp(h, k, min(t_hem + 0.03 / (h[2] - k[2]), 1.0))
            # roomier outward: the tube's axis moved out by half the extra
            leg = S.round_cone(h + V(0, 0, 0.02), end + V(s * loose * 0.5, 0, 0), r0 + 0.002, r_hem + loose * 0.5)
            leg = S.smooth([leg, S.offset(self.quad(s), 0.003)], 0.03)
            legs.append(leg)
            ax = unit(k - h)
            c = lerp(h, k, t_hem)
            n = unit(ax + V(0, -0.06, 0))
            ends.append((c, n))
            cuff_h = T.get("cuff_h", 0.026)
            band = S.offset(S.round_cone(c - ax * 0.05 + V(s * loose * 0.5, 0, 0), c + ax * 0.02 + V(s * loose * 0.5, 0, 0),
                                         r_hem + loose * 0.5, r_hem + loose * 0.5), ease + 0.0065)
            band = S.inter(band, S.inter(S.half_space(c, n), S.half_space(c - n * cuff_h, -n), 0.003), 0.004)
            cuffs.append(band)
            hollows.append((c, n, cuff_h, leg))
        seat = S.smooth([pel, S.inter(bel, below(waist + 0.02))], 0.05)
        pair = S.smooth(legs, T.get("crotch_k", 0.035))
        core = S.smooth([seat, pair], 0.045)
        shorts = S.inter(S.offset(core, ease), slab(hem - 0.05, waist))
        for c, n in ends:
            side = S.half_space(V(0, 0, 0), V(-np.sign(c[0]), 0, 0))
            shorts = S.cut(shorts, S.inter(side, S.half_space(c, -n)), 0.003)
        shorts = S.union([shorts] + cuffs)
        for c, n, cuff_h, leg in hollows:
            shorts = S.cut(shorts, S.inter(S.offset(leg, ease - 0.004), S.half_space(c - n * (cuff_h + 0.012), -n)), 0.002)
        shorts = S.smooth([shorts] + self.trouser_folds(S.offset(core, ease), hem), 0.016)
        self.trouser_core = core
        self.hem_z = hem
        self.waist_z = waist
        return shorts

    def trouser_folds(self, base, hem):
        """A fold pulled from the crotch out over the front of each thigh."""
        out = []
        cz = self.hipj_z - self.P["trousers"]["crotch"]
        lx = self.P["leg_x"]
        r = self.P["trousers"].get("fold_r", 0.010)
        for s in (1, -1):
            a = V(s * lx * 0.35, 0.0, cz + 0.010)
            b = V(s * lx * 1.05, 0.0, cz - 0.060)
            out.append(fold(base, [a, b], [V(s * 0.2, -1, 0), V(s * 0.6, -1, -0.1)], r))
        return out

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
        T = self.P.get("tail")
        if T and self.name != "owl":
            # a chain of tail bones along it (owl_character.bind adds them)
            pts = [V(0, 0, self.pz) + V(*p) for p in T["points"]]
            sp, _ = spline(pts, T["radii"], per=8)
            idx = np.linspace(0, len(sp) - 1, T.get("bones", 4) + 1).round().astype(int)
            j["tail"] = [list(map(float, sp[i])) for i in idx]
        # User request: the ears (the owl's tufts) twitch - a short chain of
        # bones up each (owl_character.bind adds them): its points root to
        # tip, how far round them it takes in, and from how far along (a
        # share of its length) it moves free of the head.
        if getattr(self, "ears", None):
            j["ears"] = [{"points": [list(map(float, p)) for p in e["points"]], "reach": float(e["reach"]),
                          "from": float(e["from"])} for e in self.ears]
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

def lid(c, r, cover=0.35, thick=0.0026, tilt=0.0, s=1, gap=0.0006):
    """An upper lid over the eye at c (radius r): a cap of a slightly
    bigger sphere above a plane `cover` of the radius above the centre
    (tilt: the outer corner that much higher per unit out), its edge
    rounded. Made with the eyes (the face's finer mesh - user request:
    thinner than the body's cells it came out jagged, with gaps)."""
    n = unit(V(s * tilt, 0.0, -1.0))
    return S.inter(S.sphere(c, r + gap + thick), S.half_space(c + V(0, 0, r * cover), n), 0.0012)


def plume(root, d, length, width, thick, face=V(0, -1, 0), lean=0.0):
    """A flat feather tuft: a tapering blade from `root` along `d`, its flat
    side toward `face`, the tip set off to one side (lean) so it reads as
    a lock of feathers, not a cone."""
    d = unit(d)
    n = unit(face - d * np.dot(face, d))
    w = unit(np.cross(d, n))
    R = np.stack([w, d, n], axis=1)
    hw = width * 0.5
    poly = [(-hw, 0.0), (hw, 0.0), (hw * 0.80, length * 0.45), (hw * 0.25 + lean, length * 0.88),
            (lean, length), (-hw * 0.35 + lean, length * 0.80), (-hw * 0.85, length * 0.40)]
    return S.plate(root, R, poly, thick * 0.5, thick * 0.5)


def blade(points, widths, thicks, face, k=0.003):
    """A curved, tapering flat piece (a feather tuft, a drop ear): a run of
    flat segments along `points`, `widths[i]` across and `thicks[i]`
    through at points[i], each turned so its flat side faces `face[i]`
    (so it can twist as it goes); joined smoothly."""
    out = []
    for i in range(len(points) - 1):
        a, b = np.asarray(points[i], float), np.asarray(points[i + 1], float)
        d = unit(b - a)
        f = unit(face[i] - d * np.dot(face[i], d))
        w = unit(np.cross(d, f))
        R = np.stack([w, d, f], axis=1)
        L = float(np.linalg.norm(b - a))
        w0, w1 = widths[i] * 0.5, widths[i + 1] * 0.5
        t = (thicks[i] + thicks[i + 1]) * 0.25
        rr = min(t * 0.8, 0.0015)
        poly = [(-w0, -0.002), (w0, -0.002), (w1, L + 0.002), (-w1, L + 0.002)]
        out.append(S.plate(a, R, poly, max(t - rr, 0.0004), rr))
    return S.smooth(out, k)


def arc(p0, d0, d1, length, n=4):
    """n+1 points from p0, `length` long, heading d0 at the start and
    turning steadily to d1 at the end."""
    pts = [np.asarray(p0, float)]
    for i in range(n):
        t = (i + 0.5) / n
        pts.append(pts[-1] + unit(lerp(unit(d0), unit(d1), t)) * length / n)
    return pts


def head_owl(an):
    """A horned owl: a broad head whose face, temples and jaw run back
    into the skull (no mask on a ball); the facial disc two shallow dishes
    with a light rim, the brows a soft V merging into the forehead and out
    into flat ear tufts, a hooked beak between the eyes."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.020, 0.000), (0.130, 0.100, 0.106))
    face = S.ellipsoid(H + V(0, -0.036, -0.010), (0.124, 0.088, 0.100))
    temples = [S.ellipsoid(H + V(s * 0.098, -0.014, 0.000), (0.044, 0.074, 0.078)) for s in (1, -1)]
    jowl = S.ellipsoid(H + V(0, -0.020, -0.066), (0.098, 0.080, 0.054))
    nape = S.ellipsoid(H + V(0, 0.058, -0.052), (0.098, 0.062, 0.062))
    head = S.smooth([skull, face, jowl, nape] + temples, 0.045)
    dishes = S.union([S.sphere(H + V(s * 0.050, -0.238, 0.004), 0.140) for s in (1, -1)])
    head = S.cut(head, dishes, 0.024)
    # the disc's rim: light, strongest at the outer cheek, fading out
    rims = []
    for s in (1, -1):
        c = H + V(s * 0.050, -0.090, 0.000)
        ring = S.torus(c, unit(V(s * 0.25, -1, 0.0)), 0.064, 0.0058, (1.0, 1.5))
        rims.append(S.inter(ring, S.half_space(c + V(s * 0.020, 0, 0.02), unit(V(-s, 0, 0.35))), 0.03))
    head = S.smooth([head] + rims, 0.020)
    fore = S.ellipsoid(H + V(0, -0.070, 0.050), (0.075, 0.048, 0.040))
    # the brows: a low ridge, fullest over the beak and thinning out to
    # nothing as it runs back round onto the side of the head (user
    # request: less of a thick frame across the face)
    brows = []
    for s in (1, -1):
        a = hit(head, H + V(s * 0.012, 0.0, 0.030), V(0, -1, 0.10))
        m = hit(head, H + V(s * 0.050, 0.0, 0.058), V(s * 0.35, -1, 0.25))
        b = hit(head, H + V(s * 0.060, 0.0, 0.050), V(s * 1.0, -0.35, 0.30))
        brows.append(S.round_cone(a - unit(a - H) * 0.0045, m - unit(m - H) * 0.0040, 0.0072, 0.0050))
        brows.append(S.round_cone(m - unit(m - H) * 0.0040, b - unit(b - H) * 0.0050, 0.0050, 0.0022))
    head = S.smooth([head, fore] + brows, 0.026)
    # ear tufts: flat feathers in one continuous surface (user request,
    # round 4: no steps along it) - bending out and back from the root to
    # the tip, thinning and narrowing all the way, a little twisted
    tufts = []
    an.ears = []
    for s in (1, -1):
        root = H + V(s * 0.080, -0.060, 0.062)
        pts = arc(root, V(s * 0.20, 0.02, 1.0), V(s * 0.62, 0.50, 0.62), 0.088, 5)
        an.ears.append({"points": [pts[0], pts[2], pts[5]], "reach": 0.032, "from": 0.12})
        faces = [unit(lerp(V(0, -1, 0.25), V(s * 0.35, -0.85, 0.35), i / 5.0)) for i in range(6)]
        tufts.append(S.ribbon(pts, [0.042, 0.040, 0.034, 0.026, 0.015, 0.003],
                              [0.011, 0.0095, 0.008, 0.0062, 0.0046, 0.0026], faces))
        pts = arc(root + V(s * 0.008, 0.016, -0.012), V(s * 0.50, 0.22, 0.85), V(s * 0.85, 0.65, 0.25), 0.058, 4)
        an.ears.append({"points": [pts[0], pts[2], pts[4]], "reach": 0.026, "from": 0.12})
        faces = [unit(lerp(V(0, -1, 0.2), V(s * 0.45, -0.8, 0.3), i / 4.0)) for i in range(5)]
        tufts.append(S.ribbon(pts, [0.032, 0.030, 0.024, 0.014, 0.003], [0.0085, 0.0074, 0.006, 0.0045, 0.0026],
                              faces))
    head = S.smooth([head] + tufts, 0.014)
    ec = [H + V(s * 0.049, -0.096, 0.008) for s in (1, -1)]
    eyes = [S.sphere(c, 0.031) for c in ec]
    an.lids = [lid(c, 0.031, 0.42, 0.0030, 0.18, sd) for c, sd in zip(ec, (1, -1))]
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
    """A shepherd-type dog: a rounder, narrower skull; a clear stop; a
    flat nasal bridge sloping to an angled nose; the upper muzzle deep at
    its base and narrowing forward, the flews below it, a shorter lower
    jaw; level, open eyes under light brows; drop ears hung from high
    on the skull, standing clear of the cheeks."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.022, 0.028), (0.070, 0.084, 0.074))
    # the occiput standing out behind (user request: the head-to-neck line
    # long and straight; a turn here, and the nape dipping under it)
    occ = S.sphere(H + V(0, 0.070, 0.040), 0.036)
    cheeks = [S.ellipsoid(H + V(s * 0.040, -0.030, -0.024), (0.028, 0.040, 0.034)) for s in (1, -1)]
    head = S.smooth([skull, occ] + cheeks, 0.028)
    # (the bridge stops short of the brows - its end made a knot between
    # them that read as a frown)
    bridge = S.box(H + V(0, -0.112, -0.010), V(0.019, 0.044, 0.011), S.rot("x", -7), round_r=0.010)
    upper = S.ellipsoid(H + V(0, -0.080, -0.030), (0.040, 0.048, 0.032))
    # (the upper lip blended into the muzzle, not a lump under the nose)
    snout = S.ellipsoid(H + V(0, -0.130, -0.026), (0.024, 0.036, 0.020))
    flews = [S.ellipsoid(H + V(s * 0.018, -0.118, -0.042), (0.016, 0.036, 0.013)) for s in (1, -1)]
    muz = S.smooth([bridge, upper, snout] + flews, 0.024)
    jaw = S.ellipsoid(H + V(0, -0.090, -0.058), (0.022, 0.046, 0.012))
    chin = S.sphere(H + V(0, -0.124, -0.056), 0.0095)
    head = S.smooth([head, muz], 0.020)
    head = S.smooth([head, jaw, chin], 0.010)
    mouth = S.tube([H + V(-0.030, -0.064, -0.044), H + V(-0.026, -0.090, -0.050), H + V(-0.014, -0.124, -0.052),
                    H + V(0, -0.140, -0.051), H + V(0.014, -0.124, -0.052), H + V(0.026, -0.090, -0.050),
                    H + V(0.030, -0.064, -0.044)], [0.0022] * 7)
    head = S.cut(head, mouth, 0.004)
    # brows level and set a little higher, clear of the lids: a neutral,
    # open look (user request: it read tired / half-asleep)
    # (apart, each blended on its own: blended together they swelled into
    # a knot between them that read as a frown)
    brows = [S.ellipsoid(H + V(s * 0.037, -0.062, 0.054), (0.014, 0.010, 0.0036)) for s in (1, -1)]
    head = S.smooth([S.smooth([head, b], 0.014) for b in brows[:1]] + [brows[1]], 0.014)
    ec = [set_eye(head, H + V(s * 0.035, 0.0, 0.031), V(s * 0.22, -1, 0), 0.0142, 0.52) for s in (1, -1)]
    # the socket opened upward so the eye isn't hooded by the brow
    head = S.cut(head, S.union([S.sphere(c + V(0, 0, 0.0015), 0.0168) for c in ec]), 0.006)
    eyes = [S.sphere(c, 0.0142) for c in ec]
    # the lids over the top only, the outer corner a touch up
    an.lids = [lid(c, 0.0142, 0.76, 0.0026, 0.12, sd) for c, sd in zip(ec, (1, -1))]
    nose = S.smooth([S.box(H + V(0, -0.160, -0.004), V(0.016, 0.010, 0.011), S.rot("x", 18), round_r=0.008),
                     S.ellipsoid(H + V(0, -0.163, 0.000), (0.014, 0.008, 0.009))], 0.006)
    head = S.smooth([head, S.offset(nose, -0.003)], 0.010)
    # drop ears (user request, round 4: a clear hanging outline, the flap
    # reaching below the cheek; seen from the front they hang, from the
    # side not an oval stuck on): out from the skull and over at the fold,
    # then down beside the cheek, broad above, narrowing to a rounded tip
    # turned a little forward, thin at the edges
    ears = []
    an.ears = []
    for s in (1, -1):
        top = hit(head, H + V(0, 0.014, 0.056), V(s, 0, 0.30))
        c = top + V(s * 0.004, 0.0, 0.002)
        fold = S.capsule(c + V(s * 0.004, -0.016, -0.002), c + V(s * 0.004, 0.014, -0.002), 0.0068)
        # (a leaf, not a strip: broadest a third of the way down, its back
        # edge rounding in to a tip that points a little forward; thick
        # enough that the mesh keeps its edges clean)
        pts = [c + V(s * 0.004, 0.0, 0.000), c + V(s * 0.016, 0.002, -0.014), c + V(s * 0.021, 0.004, -0.046),
               c + V(s * 0.020, -0.004, -0.086), c + V(s * 0.015, -0.016, -0.116), c + V(s * 0.011, -0.022, -0.128)]
        out = [unit(V(s, 0, 0.9)), unit(V(s, 0, 0.3)), unit(V(s, 0.05, 0.05)), unit(V(s, 0.10, -0.05)),
               unit(V(s, 0.12, -0.10)), unit(V(s, 0.12, -0.10))]
        flap = S.ribbon(pts, [0.040, 0.054, 0.056, 0.044, 0.026, 0.008],
                        [0.0120, 0.0088, 0.0078, 0.0070, 0.0064, 0.0058], out)
        ears.append(S.smooth([fold, flap], 0.006))
        an.ears.append({"points": [pts[0], pts[2], pts[5]], "reach": 0.036, "from": 0.06})
    head = S.smooth([head] + ears, 0.008)
    return head, eyes, [nose], [], {"top": float(H[2] + 0.102), "half_width": 0.100}


def head_cat(an):
    """A small cat's head: round skull, wide cheeks, a short muzzle of
    two whisker pads under a small nose, a neat chin, big upright ears
    set wide, almond eyes."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.010, 0.014), (0.062, 0.064, 0.056))
    cheeks = [S.ellipsoid(H + V(s * 0.034, -0.020, -0.016), (0.033, 0.034, 0.028)) for s in (1, -1)]
    nape = S.ellipsoid(H + V(0, 0.040, -0.030), (0.044, 0.034, 0.040))
    head = S.smooth([skull, nape] + cheeks, 0.024)
    pads = [S.ellipsoid(H + V(s * 0.0105, -0.052, -0.018), (0.0105, 0.0080, 0.0075)) for s in (1, -1)]
    chin = S.ellipsoid(H + V(0, -0.040, -0.031), (0.0075, 0.0065, 0.0052))
    bridge = S.capsule(H + V(0, -0.046, 0.024), H + V(0, -0.064, 0.000), 0.0095)
    head = S.smooth([head, bridge] + pads, 0.010)
    head = S.smooth([head, chin], 0.008)
    nose = S.ellipsoid(H + V(0, -0.069, -0.004), (0.0088, 0.0055, 0.0058))
    head = S.smooth([head, S.offset(nose, -0.0025)], 0.004)
    head = S.cut(head, S.capsule(H + V(0, -0.0725, -0.011), H + V(0, -0.0715, -0.024), 0.0021), 0.002)
    ec = [set_eye(head, H + V(s * 0.028, 0.0, 0.013), V(s * 0.30, -1, 0.0), 0.0150, 0.40) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0164) for c in ec]), 0.006)
    eyes = [S.sphere(c, 0.0150) for c in ec]
    an.lids = [lid(c, 0.0150, 0.74, 0.0026, 0.30, sd) for c, sd in zip(ec, (1, -1))]
    # the muzzle's own zone (user request, round 4: a little lighter in the
    # colour pass so nose and mouth read on the black): the whisker pads,
    # the chin and the bridge's lower end
    an.muzzle = S.smooth([S.ellipsoid(H + V(0, -0.056, -0.020), (0.024, 0.016, 0.019)),
                          S.ellipsoid(H + V(0, -0.058, -0.004), (0.010, 0.012, 0.012))], 0.006)
    ears = []
    an.ears = []
    for s in (1, -1):
        base = H + V(s * 0.040, 0.004, 0.044)
        tip = H + V(s * 0.062, 0.000, 0.106)
        an.ears.append({"points": [base, lerp(base, tip, 0.55), tip], "reach": 0.032, "from": 0.3})
        R = S.rot("z", s * -8)
        e = S.squash(S.round_cone(base, tip, 0.025, 0.0035), lerp(base, tip, 0.45), (1.0, 0.42, 1.0), R)
        hollow = S.squash(S.round_cone(base + V(-s * 0.002, -0.010, 0.010), tip + V(-s * 0.002, -0.006, -0.012),
                                       0.016, 0.002), lerp(base, tip, 0.5) + V(0, -0.008, 0), (1.0, 0.35, 1.0), R)
        ears.append(S.cut(e, hollow, 0.003))
    head = S.smooth([head] + ears, 0.012)
    return head, eyes, [nose], [], {"top": float(H[2] + 0.070), "half_width": 0.072}


def head_bear(an):
    """A bear: a broad skull with a heavy brow plane and small round ears;
    a short, deep muzzle in parts - the bridge's flat top, the broad nose
    leather, two upper-lip lobes, a separate smaller chin - the eyes small
    and set wide under the brow; the cheeks' fur in a few locks."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.024, 0.022), (0.102, 0.094, 0.080))
    fore = S.ellipsoid(H + V(0, -0.058, 0.040), (0.072, 0.040, 0.030))
    cheeks = [S.ellipsoid(H + V(s * 0.064, -0.014, -0.030), (0.048, 0.056, 0.048)) for s in (1, -1)]
    nape = S.ellipsoid(H + V(0, 0.058, -0.048), (0.086, 0.060, 0.060))
    head = S.smooth([skull, fore, nape] + cheeks, 0.035)
    locks = []
    for s in (1, -1):
        for k, (dz, dy, L) in enumerate(((-0.012, 0.004, 0.050), (-0.046, 0.022, 0.044))):
            root = H + V(s * 0.096, -0.028 + dy, -0.020 + dz)
            locks.append(clump(root, V(s * 0.45, 0.62, -0.62), L, 0.026, flat=0.5, up=V(s, 0, 0)))
    head = S.smooth([head] + locks, 0.016)
    # the muzzle as one run of forms (user request): the bridge into the
    # nose, the nose sat on the upper lip, the lip's two lobes one curve
    # round the front, the mouth line one even curve corner to corner, the
    # chin carrying on from the jaw beneath
    base = S.ellipsoid(H + V(0, -0.080, -0.024), (0.052, 0.044, 0.044))
    bridge = S.box(H + V(0, -0.104, -0.006), V(0.027, 0.044, 0.013), S.rot("x", -6), round_r=0.013)
    lips = [S.ellipsoid(H + V(s * 0.015, -0.116, -0.039), (0.026, 0.032, 0.021)) for s in (1, -1)]
    muz = S.smooth([base, bridge] + lips, 0.024)
    jaw = S.ellipsoid(H + V(0, -0.090, -0.064), (0.034, 0.038, 0.018))
    head = S.smooth([head, muz], 0.024)
    head = S.smooth([head, jaw], 0.020)
    mouth = S.tube([H + V(-0.040, -0.078, -0.050), H + V(-0.032, -0.100, -0.055), H + V(-0.018, -0.118, -0.058),
                    H + V(0, -0.125, -0.059), H + V(0.018, -0.118, -0.058), H + V(0.032, -0.100, -0.055),
                    H + V(0.040, -0.078, -0.050)], [0.0016, 0.0022, 0.0024, 0.0024, 0.0024, 0.0022, 0.0016])
    head = S.cut(head, mouth, 0.004)
    # the philtrum between the lip lobes, under the nose: shallow
    head = S.cut(head, S.capsule(H + V(0, -0.137, -0.024), H + V(0, -0.134, -0.044), 0.0018), 0.004)
    ec = [set_eye(head, H + V(s * 0.047, 0.0, 0.024), V(s * 0.20, -1, 0.0), 0.0128, 0.42) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0145) for c in ec]), 0.005)
    eyes = [S.sphere(c, 0.0128) for c in ec]
    an.lids = [lid(c, 0.0128, 0.42, 0.0026, 0.0, sd) for c, sd in zip(ec, (1, -1))]
    nose = S.smooth([S.box(H + V(0, -0.145, -0.006), V(0.024, 0.012, 0.015), S.rot("x", 14), round_r=0.011),
                     S.ellipsoid(H + V(0, -0.148, -0.001), (0.020, 0.010, 0.011))], 0.006)
    head = S.smooth([head, S.offset(nose, -0.004)], 0.010)
    ears = []
    an.ears = []
    for s in (1, -1):
        c = H + V(s * 0.080, 0.026, 0.076)
        an.ears.append({"points": [c - V(s * 0.030, 0, 0.026), c, c + V(s * 0.022, 0, 0.026)], "reach": 0.04,
                        "from": 0.42})
        R = S.rot("y", s * -28)
        e = S.ellipsoid(c, (0.034, 0.016, 0.032), R)
        hollow = S.ellipsoid(c + V(0, -0.010, 0.002), (0.022, 0.010, 0.020), R)
        ears.append(S.cut(e, hollow, 0.004))
    head = S.smooth([head] + ears, 0.012)
    return head, eyes, [nose], [], {"top": float(H[2] + 0.104), "half_width": 0.122}


def antler(root, s):
    """A red deer's antler off the top of the head (side `s`): its beam
    rising up and out and sweeping back, curving in again near the top,
    a brow tine and a bez tine forward low on it, a trez tine halfway up
    and a small crown of two points at the top; thick at the burr and
    thinning to blunt points."""
    beam = [root, root + V(s * 0.022, 0.006, 0.030), root + V(s * 0.050, 0.020, 0.066),
            root + V(s * 0.072, 0.036, 0.104), root + V(s * 0.080, 0.046, 0.140), root + V(s * 0.072, 0.050, 0.168)]
    rs = [0.0125, 0.0115, 0.0102, 0.0090, 0.0078, 0.0060]
    parts = [S.smooth([S.round_cone(beam[i], beam[i + 1], rs[i], rs[i + 1]) for i in range(len(beam) - 1)], 0.004)]
    # the burr round its base
    parts.append(S.torus(root + V(s * 0.004, 0.0, 0.008), unit(beam[1] - beam[0]), 0.0125, 0.0036))

    def tine(at, d, L, r0):
        a = beam[0] + (beam[1] - beam[0]) * 0 if at is None else at
        d = unit(d)
        mid = a + d * L * 0.55 + V(0, 0, L * 0.12)
        return S.smooth([S.round_cone(a, mid, r0, r0 * 0.75), S.round_cone(mid, mid + unit(d + V(0, 0, 0.6)) * L * 0.5,
                                                                        r0 * 0.75, r0 * 0.30)], 0.003)
    parts.append(tine(lerp(beam[0], beam[1], 0.60), V(s * 0.20, -1.0, 0.35), 0.060, 0.0085))
    parts.append(tine(lerp(beam[1], beam[2], 0.50), V(s * 0.30, -1.0, 0.50), 0.050, 0.0075))
    parts.append(tine(beam[3], V(s * 0.25, -0.8, 0.80), 0.040, 0.0066))
    parts.append(tine(beam[4], V(s * 0.10, -0.5, 1.0), 0.030, 0.0056))
    parts.append(tine(beam[4], V(s * 0.60, 0.40, 0.8), 0.028, 0.0052))
    return S.smooth(parts, 0.004)


def head_deer(an):
    """A red deer stag: a long, narrow head - the brow rising to the crown
    between the antlers, a long tapering muzzle sloping down to a broad
    dark nose, a slim lower jaw; big, gentle eyes set on the sides of the
    head; large ears out to the sides; branched antlers (HORN) off the
    crown; the muzzle and chin pale (MUZZLE)."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.022, 0.026), (0.056, 0.070, 0.056))
    cheeks = [S.ellipsoid(H + V(s * 0.030, -0.020, -0.014), (0.026, 0.044, 0.032)) for s in (1, -1)]
    nape = S.ellipsoid(H + V(0, 0.050, -0.022), (0.040, 0.036, 0.040))
    head = S.smooth([skull, nape] + cheeks, 0.024)
    # the long face: down from the brow to the nose
    bridge = S.ellipsoid(H + V(0, -0.078, -0.006), (0.026, 0.062, 0.024), S.rot("x", -12))
    snout = S.ellipsoid(H + V(0, -0.128, -0.024), (0.020, 0.026, 0.019))
    jaw = S.ellipsoid(H + V(0, -0.082, -0.034), (0.017, 0.048, 0.011), S.rot("x", -6))
    head = S.smooth([head, bridge, snout], 0.024)
    head = S.smooth([head, jaw], 0.012)
    mouth = S.tube([H + V(-0.016, -0.100, -0.040), H + V(-0.011, -0.130, -0.040), H + V(0, -0.143, -0.039),
                    H + V(0.011, -0.130, -0.040), H + V(0.016, -0.100, -0.040)], [0.0017] * 5)
    head = S.cut(head, mouth, 0.003)
    ec = [set_eye(head, H + V(s * 0.030, -0.006, 0.020), V(s * 0.75, -1, 0.10), 0.0150, 0.46) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0168) for c in ec]), 0.005)
    eyes = [S.sphere(c, 0.0150) for c in ec]
    an.lids = [lid(c, 0.0150, 0.70, 0.0026, 0.05, sd) for c, sd in zip(ec, (1, -1))]
    nose = S.smooth([S.ellipsoid(H + V(0, -0.149, -0.018), (0.016, 0.008, 0.012)),
                     S.ellipsoid(H + V(0, -0.143, -0.008), (0.012, 0.010, 0.007))], 0.006)
    head = S.smooth([head, S.offset(nose, -0.003)], 0.008)
    an.muzzle = S.smooth([S.ellipsoid(H + V(0, -0.130, -0.030), (0.026, 0.028, 0.020)),
                          S.ellipsoid(H + V(0, -0.086, -0.044), (0.022, 0.048, 0.014))], 0.008)
    ears = []
    an.ears = []
    for s in (1, -1):
        base = H + V(s * 0.038, 0.028, 0.046)
        tip = H + V(s * 0.098, 0.040, 0.100)
        an.ears.append({"points": [base, lerp(base, tip, 0.5), tip], "reach": 0.036, "from": 0.28})
        R = S.rot("x", 12) @ S.rot("y", s * -26)
        e = S.squash(S.round_cone(base, tip, 0.024, 0.006), lerp(base, tip, 0.5), (1.0, 0.40, 1.0), R)
        hollow = S.squash(S.round_cone(base + V(s * 0.006, -0.010, 0.002), tip + V(-s * 0.002, -0.008, -0.004),
                                       0.016, 0.003), lerp(base, tip, 0.55) + V(0, -0.008, 0), (1.0, 0.32, 1.0), R)
        ears.append(S.cut(e, hollow, 0.003))
    head = S.smooth([head] + ears, 0.010)
    antlers = [antler(H + V(s * 0.026, 0.006, 0.066), s) for s in (1, -1)]
    return head, eyes, [nose], antlers, {"top": float(H[2] + 0.082), "half_width": 0.078}


def ram_horn(H, s):
    """A ram's horn (side `s`): out of the top of the head behind the
    brow, back and round down behind the ear and forward under it - a
    curl of about a turn and a quarter, spiralling outward, thick at the
    root and tapering to a blunt tip by the cheek - its front ridged
    with growth rings."""
    c = H + V(s * 0.070, 0.036, 0.004)
    pts, rs = [], []
    n = 14
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-12 + t * 300)
        r = 0.064 - 0.030 * t
        x = 0.040 + 0.068 * t
        pts.append(c + V(s * (x - 0.070), math.sin(a) * r, math.cos(a) * r))
        rs.append(0.026 - 0.018 * t)
    horn = S.smooth([S.round_cone(pts[i], pts[i + 1], rs[i], rs[i + 1]) for i in range(n - 1)], 0.004)
    rings = []
    for i in range(1, n - 2, 2):
        d = unit(pts[i + 1] - pts[i - 1])
        rings.append(S.torus(pts[i], d, rs[i] * 0.92, 0.0024))
    return S.smooth([horn] + rings, 0.003)


def head_sheep(an):
    """A sheep with a ram's horns: a long face with a gently arched
    (Roman) nose and a soft, rounded muzzle; the eyes on the sides of the
    head; ears sticking out level under the horns; a tuft of fleece on the
    crown between them; the face dark (MUZZLE), the fleece light; big
    curled horns (HORN)."""
    H = an.head_c
    skull = S.ellipsoid(H + V(0, 0.018, 0.020), (0.060, 0.066, 0.060))
    cheeks = [S.ellipsoid(H + V(s * 0.032, -0.020, -0.018), (0.030, 0.042, 0.034)) for s in (1, -1)]
    nape = S.ellipsoid(H + V(0, 0.050, -0.026), (0.050, 0.040, 0.046))
    head = S.smooth([skull, nape] + cheeks, 0.026)
    bridge = S.ellipsoid(H + V(0, -0.068, -0.004), (0.028, 0.058, 0.028), S.rot("x", -20))
    snout = S.ellipsoid(H + V(0, -0.114, -0.032), (0.024, 0.026, 0.023))
    jaw = S.ellipsoid(H + V(0, -0.080, -0.042), (0.020, 0.044, 0.013), S.rot("x", -10))
    head = S.smooth([head, bridge, snout], 0.026)
    head = S.smooth([head, jaw], 0.012)
    mouth = S.tube([H + V(-0.018, -0.096, -0.048), H + V(-0.011, -0.122, -0.049), H + V(0, -0.134, -0.048),
                    H + V(0.011, -0.122, -0.049), H + V(0.018, -0.096, -0.048)], [0.0017] * 5)
    head = S.cut(head, mouth, 0.003)
    ec = [set_eye(head, H + V(s * 0.034, -0.006, 0.016), V(s * 0.80, -1, 0.12), 0.0135, 0.46) for s in (1, -1)]
    head = S.cut(head, S.union([S.sphere(c, 0.0152) for c in ec]), 0.005)
    eyes = [S.sphere(c, 0.0135) for c in ec]
    an.lids = [lid(c, 0.0135, 0.62, 0.0026, 0.0, sd) for c, sd in zip(ec, (1, -1))]
    nose = S.smooth([S.ellipsoid(H + V(s * 0.008, -0.137, -0.026), (0.006, 0.005, 0.004)) for s in (1, -1)], 0.004)
    head = S.cut(head, S.offset(nose, 0.001), 0.003)
    ears = []
    an.ears = []
    for s in (1, -1):
        # (under the horn's curl, hanging out and a little down and forward)
        base = H + V(s * 0.044, -0.008, -0.014)
        tip = H + V(s * 0.106, -0.034, -0.046)
        an.ears.append({"points": [base, lerp(base, tip, 0.5), tip], "reach": 0.034, "from": 0.30})
        R = S.rot("x", 18)
        e = S.squash(S.round_cone(base, tip, 0.021, 0.013), lerp(base, tip, 0.5), (1.0, 0.40, 1.0), R)
        hollow = S.squash(S.round_cone(base + V(s * 0.008, -0.006, 0.0), tip + V(-s * 0.002, -0.006, 0.002),
                                       0.011, 0.005), lerp(base, tip, 0.5) + V(0, -0.006, 0), (1.0, 0.30, 1.0), R)
        ears.append(S.cut(e, hollow, 0.003))
    # the fleece on the crown: a few soft lumps
    tuft = S.smooth([S.sphere(H + V(dx, dy, 0.070 + dz), r) for dx, dy, dz, r in
                     ((0.0, -0.010, 0.006, 0.026), (0.020, 0.004, 0.0, 0.022), (-0.020, 0.004, 0.0, 0.022),
                      (0.0, 0.018, 0.002, 0.024), (0.010, -0.030, -0.008, 0.018), (-0.010, -0.030, -0.008, 0.018))],
                    0.010)
    head = S.smooth([head, tuft] + ears, 0.010)
    # the face dark: from the brow down, round the eyes, the ears too
    an.muzzle = S.smooth([S.ellipsoid(H + V(0, -0.074, -0.014), (0.048, 0.080, 0.060), S.rot("x", -14))] +
                         [S.capsule(H + V(s * 0.040, -0.008, -0.012), H + V(s * 0.104, -0.032, -0.048), 0.024)
                          for s in (1, -1)], 0.010)
    horns = [ram_horn(H, s) for s in (1, -1)]
    return head, eyes, [], horns, {"top": float(H[2] + 0.088), "half_width": 0.094}


HEADS = {"owl": head_owl, "dog": head_dog, "cat": head_cat, "bear": head_bear, "deer": head_deer,
         "sheep": head_sheep}


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
    """A neckerchief of thin cloth: a slim rolled band round the neck just
    over the collar, knotted behind, a small triangle lying on the
    jumper's chest in front of the V (the same dark form from the front
    and the back)."""
    n0, n1 = an.neck0, an.neck1
    t = 0.40
    c = lerp(n0, n1, t)
    up = unit(n1 - n0)
    r = max(surface_r(an.body_node, c, d) for d in (V(1, 0, 0), V(0, -1, 0), V(0, 1, 0)))
    band = S.torus(c, up, r + 0.001, 0.0065, (1.0, 1.7))
    knot = S.ellipsoid(c + V(0, r + 0.010, -0.004), (0.013, 0.009, 0.011))
    tails = [S.plate(c + V(s * 0.011, r + 0.016, -0.030), S.rot("x", 102) @ S.rot("z", s * 14),
                     [(-0.009, 0.020), (0.009, 0.020), (0.004, -0.024), (-0.005, -0.020)], 0.0016, 0.0016)
             for s in (1, -1)]
    ztop = c[2] - 0.008
    ztip = c[2] - 0.098
    ytop = min(surface_y(an.jumper_node, 0.040, ztop), surface_y(an.body_node, 0.0, ztop)) - 0.006
    ytip = min(surface_y(an.jumper_node, 0.0, ztip), surface_y(an.jumper_node, 0.03, ztip)) - 0.006
    top, tip = V(0, ytop, ztop), V(0, ytip, ztip)
    ly = unit(top - tip)
    lx = V(1, 0, 0)
    lz = np.cross(lx, ly)
    R = np.stack([lx, ly, lz], axis=1)
    L = np.linalg.norm(top - tip)
    tri = S.plate(tip + lz * -0.002, R, [(-0.050, L), (0.050, L), (0.010, 0.010), (0.0, 0.0), (-0.010, 0.010)],
                  0.0018, 0.0022)
    return S.smooth([band, knot] + tails, 0.004), SCARF, tri


def bear_fur(an, upper):
    """The bear's neck and shoulder fur in a few big locks of different
    widths and lengths - three over the chest, four down the back, one
    over each shoulder - rooted into the neck (blended into it) and only
    parting toward their ends, running down and back."""
    n0, n1 = an.neck0, an.neck1
    out = []
    # (angle from the front, height up the neck, length, root radius, outward)
    spec = [(-38, 0.30, 0.070, 0.040, 0.55), (0, 0.24, 0.088, 0.050, 0.45), (36, 0.32, 0.064, 0.036, 0.55),
            (80, 0.36, 0.070, 0.044, 0.85), (-82, 0.36, 0.074, 0.046, 0.85),
            (140, 0.40, 0.078, 0.048, 0.55), (166, 0.48, 0.112, 0.060, 0.42), (198, 0.40, 0.088, 0.050, 0.45),
            (224, 0.34, 0.064, 0.042, 0.55)]
    for deg, t, L, r0, outw in spec:
        a = math.radians(deg)
        d = V(math.sin(a), -math.cos(a), 0.0)
        c = lerp(n0, n1, t)
        r = surface_r(upper, c, d)
        root = c + d * (r - r0 * 0.5)
        back = max(-math.cos(a), 0.0)
        way = d * (outw + 0.2) + V(0, 0.25 * back, -1.0)
        if back > 0.5:
            continue
        # (tapering to a point: a lock, not a drip)
        out.append(clump(root, way, L * 1.2, r0 * 0.82, flat=0.42, up=d, tip_r=0.16))
    # down the back (user request, round 4: no thick ridge where it starts,
    # no cape or pad, no row of drops): three broad locks growing out of
    # the nape - thin where they leave it, fullest over the collar - lying
    # down over the back and narrowing to points, of different lengths
    # (their roots overlapping - one mass of fur from the nape that parts
    # into three points, not three pieces laid side by side)
    for deg, L, w in ((180, 0.112, 0.088), (158, 0.090, 0.072), (203, 0.096, 0.074)):
        a = math.radians(deg)
        d = V(math.sin(a), -math.cos(a), 0.0)
        pts = []
        # (over the collar and down, they lie on the jumper: its ease out)
        ease = an.P["jumper"]["ease"]
        for t, z_off, lift in ((0.70, None, -0.012), (0.30, None, 0.004), (0.0, None, ease + 0.008),
                               (None, -0.40, ease + 0.008), (None, -0.80, ease + 0.005), (None, -1.0, ease + 0.002)):
            if t is not None:
                cc = lerp(n0, n1, t)
            else:
                cc = V(0, n0[1], n0[2] + z_off * L)
            pts.append(cc + d * (surface_r(upper, cc, d) + lift))
        faces = [d] * len(pts)
        out.append(S.ribbon(pts, [w * 0.55, w * 0.85, w, w * 0.80, w * 0.42, w * 0.06],
                            [0.006, 0.010, 0.013, 0.011, 0.007, 0.002], faces))
    return S.smooth(out, 0.010)


def collar_sheep(an):
    """The sheep's fleece at its neck: soft round lumps of wool all round
    over the jumper's neckline, fuller at the back."""
    n0, n1 = an.neck0, an.neck1
    out = []
    for row, (t, n, r0) in enumerate(((0.10, 13, 0.024), (0.34, 11, 0.021))):
        c = lerp(n0, n1, t)
        for i in range(n):
            a = (i + 0.5 * row) / n * 2 * math.pi
            d = V(math.sin(a), -math.cos(a), 0.0)
            back = max(math.cos(a + math.pi), 0.0)
            r = surface_r(an.body_node, c, d)
            out.append(S.sphere(c + d * (r + 0.004) + V(0, 0, -0.004 * row), r0 * (1.0 + 0.25 * back)))
    return S.smooth(out, 0.010), FUR


COLLARS = {"owl": collar_owl, "dog": collar_dog, "sheep": collar_sheep}


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
    zones = {"owl_body": (labels, voxel)}
    if an.face:
        face = S.union([n for _, n in an.face])
        face_labels = [(z, n) for z, n in an.face]
        S.mesh("owl_face", face, voxel=voxel * 0.5, materials=mats, labels=face_labels)
        zones["owl_face"] = (face_labels, voxel * 0.5)
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
        hole = getattr(an, "tail_hole", None)
        shorts_cut = S.cut(shorts_cut, hole if hole is not None else S.offset(an.tail_node, 0.004),
                           0.006 if hole is not None else 0.004)
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
    export_glb(stem + "_greybox.glb", zones)
    return an, joints


# Triangles each part is cut down to in the .glb (the skinned, posed
# tests run on these; the .blend keeps the full surface).
GLB_TRIS = {"owl_body": 48000, "owl_face": 3000, "owl_jumper": 14000, "owl_trousers": 9000,
            "owl_ruff": 7000, "owl_button": 300}


def cut_down_zoned(o, tris, labels, voxel):
    """o cut down to about `tris` triangles with its colour zones cut again
    on what's left (user request, round 5: the pads' and claws' edges came
    out torn - the cut collapsed the faces along a zone's edge like any
    others, so a smooth edge ended in teeth along whatever edges were left
    and a small zone in a few flecks): the zones' fields read at the cut-down
    surface and the triangles their edges cross split there
    (sdf_mesh.split_labels)."""
    n = len(o.data.polygons)
    md = o.modifiers.new("cut", "DECIMATE")
    md.ratio = tris / n
    md.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    low = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    o.modifiers.remove(md)
    co = np.zeros(len(low.vertices) * 3)
    low.vertices.foreach_get("co", co)
    faces = np.array([p.vertices[:] for p in low.polygons], np.int64)
    verts, faces, idx = S.split_labels(co.reshape(-1, 3), faces, labels, voxel)
    me = bpy.data.meshes.new(o.data.name + "_low")
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.validate()
    for m in o.data.materials:
        me.materials.append(m)
    if len(me.polygons) != len(idx):
        raise RuntimeError("%s: %d faces after validate, %d zones" % (o.name, len(me.polygons), len(idx)))
    me.polygons.foreach_set("material_index", idx)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    o.data = me
    bpy.data.meshes.remove(low)


def export_glb(path, zones=None):
    """The scene's meshes into a .glb, each cut down to GLB_TRIS; `zones`
    {object name: (labels, voxel)} those whose colour zones are cut again
    after (cut_down_zoned) - which replaces their mesh, so the .blend is
    saved first."""
    zones = zones or {}
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        n = len(o.data.polygons)
        t = GLB_TRIS.get(o.name, 20000)
        if n > t:
            if o.name in zones:
                cut_down_zoned(o, t, *zones[o.name])
            else:
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
