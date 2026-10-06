"""The reel on the rod, and where the cranking hand holds its knob.

User request (round 6): reeling in and the fight cranked at the air - the
right hand turned a small circle 24-42 cm (in a 1.2 m animal person) off
the rod, with nothing there to turn; the reel was only a flat bump on the
rod's sprite. Here the reel is a part of the character's own pictures
(render_player.py --grip draws it with the body, so the hand on its knob
and the rod over or under it are seen as they are): a casting reel on top
of the rod, just ahead of the rod hand, its crank on the right (the hand
that isn't holding the rod), turning about an axis square to the rod.

Sizes are in character units (a ~1.2 m animal person, see rod_grip.py),
times the character's char_k for the world; a little larger than a real
reel's so the crank's turn reads on screen.

    r = reel.Reel(char_k, handle_r)       # builds the reel's two objects
    r.place(c, d, theta)                  # on the rod: grip c, direction d
    centre, axis = r.knob(c, d, theta)    # where the crank hand's grip goes
"""
import math

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

# Ahead of the rod hand's index finger (along the rod), from the reel's foot.
GAP = 0.006
FOOT = 0.008        # the foot's height, rod surface to the reel's body
BODY_R = 0.026      # the reel's round body
BODY_W = 0.05       # its width across the rod
PLATE = 0.009       # each side plate's width (the spool between them)
HUB = 0.006         # the crank's hub, out of the right side plate
CRANK_R = 0.04      # the crank's arm, hub to knob
ARM_T = 0.006       # the arm's thickness and width
ARM_W = 0.012
# The knob (its radius and length come from the hand that holds it).
KNOB_R = 0.0075

BODY_RGB = (0.11, 0.115, 0.13)
SPOOL_RGB = (0.78, 0.76, 0.70)
ARM_RGB = (0.42, 0.43, 0.46)
KNOB_RGB = (0.86, 0.79, 0.62)


def frame(c, d, out=None):
    """The reel's frame on the rod at the grip c, pointing d: (u along the
    rod, up square to it - toward the sky, or `out` if given (the rod on
    the back: away from it) - and s to the character's right)."""
    u = np.array(d, float)
    u /= np.linalg.norm(u)
    w = np.array([0.0, 0.0, 1.0]) if out is None else np.array(out, float)
    up = w - u * (u @ w)
    if np.linalg.norm(up) < 1e-6:
        up = np.array([0.0, 1.0, 0.0])
    up /= np.linalg.norm(up)
    s = np.cross(u, up)
    return np.array(c, float), u, up, s / np.linalg.norm(s)


def _material(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.6
    return m


def _cylinder(bm, x0, x1, r, centre, segs=20, mat=0):
    """A cylinder along X from x0 to x1, radius r, its axis through centre
    (y, z)."""
    cy, cz = centre
    rings = []
    for x in (x0, x1):
        rings.append([bm.verts.new((x, cy + r * math.cos(a), cz + r * math.sin(a)))
                      for a in np.linspace(0, math.tau, segs, endpoint=False)])
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i])).material_index = mat
    bm.faces.new(list(reversed(rings[0]))).material_index = mat
    bm.faces.new(rings[1]).material_index = mat


def _box(bm, lo, hi, mat=0):
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                   (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([v[i] for i in f]).material_index = mat


class Reel:
    def __init__(self, char_k, handle_r, seat, knob_len, knob_r=None):
        """char_k: world units a character unit; handle_r: the rod's handle
        radius in the hand (world); seat: how far ahead of the grip's centre
        the reel's foot goes (world, past the rod hand); knob_len: the
        knob's length (world, the crank hand's width and some)."""
        k = char_k
        self.k = k
        self.seat = seat
        self.lift = handle_r + FOOT * k + BODY_R * k       # rod axis to the body's centre
        self.knob_x = (BODY_W / 2 + HUB + ARM_T) * k + knob_len / 2
        self.crank_r = CRANK_R * k
        mats = [_material("reel_body", BODY_RGB), _material("reel_spool", SPOOL_RGB),
                _material("reel_arm", ARM_RGB), _material("reel_knob", KNOB_RGB)]
        # the body (origin: the seat on the rod's axis; X across, Y along, Z up)
        bm = bmesh.new()
        hw = BODY_W / 2 * k
        cz = self.lift
        _box(bm, (-0.006 * k, -0.014 * k, handle_r * 0.6), (0.006 * k, 0.014 * k, cz), 0)
        _cylinder(bm, -hw, -hw + PLATE * k, BODY_R * k, (0.0, cz), mat=0)
        _cylinder(bm, -hw + PLATE * k, hw - PLATE * k, BODY_R * k * 0.86, (0.0, cz), mat=1)
        _cylinder(bm, hw - PLATE * k, hw, BODY_R * k, (0.0, cz), mat=0)
        _cylinder(bm, hw, hw + HUB * k, BODY_R * k * 0.3, (0.0, cz), segs=12, mat=2)
        self.body = self._object("reel", bm, mats)
        # the crank (origin: the body's centre; turned about X)
        bm = bmesh.new()
        x0 = hw + HUB * k
        _box(bm, (x0, -ARM_W / 2 * k, -ARM_W / 2 * k), (x0 + ARM_T * k, self.crank_r + ARM_W / 2 * k, ARM_W / 2 * k), 2)
        _cylinder(bm, x0 + ARM_T * k, x0 + ARM_T * k + knob_len, (knob_r or KNOB_R * k), (self.crank_r, 0.0), segs=14, mat=3)
        self.crank = self._object("reel_crank", bm, mats)

    @staticmethod
    def _object(name, bm, mats):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in mats:
            me.materials.append(m)
        for p in me.polygons:
            p.use_smooth = True
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        return o

    def matrix(self, c, d, out=None):
        """The reel's world matrix on the rod (its seat on the axis)."""
        o, u, up, s = frame(c, d, out)
        m = Matrix.Identity(4)
        for i, v in enumerate((s, u, up)):
            m[0][i], m[1][i], m[2][i] = v
        m.translation = Vector(o + u * self.seat)
        return m

    def place(self, c, d, theta, out=None):
        """On the rod at grip c pointing d, the crank turned to theta
        (deg; 0 = the knob toward the tip, 90 = up)."""
        m = self.matrix(c, d, out)
        self.body.matrix_world = m
        self.crank.matrix_world = m @ Matrix.Translation((0.0, 0.0, self.lift)) @ Matrix.Rotation(math.radians(theta), 4, "X")

    def knob(self, c, d, theta, out=None):
        """The knob's middle (where the crank hand's grip centre goes) and
        its axis (the character's right), world."""
        o, u, up, s = frame(c, d, out)
        t = math.radians(theta)
        hub = o + u * self.seat + up * self.lift
        return hub + s * self.knob_x + self.crank_r * (u * math.cos(t) + up * math.sin(t)), s

    def hide(self, hidden):
        self.body.hide_render = self.crank.hide_render = hidden

    def objects(self):
        return [self.body, self.crank]
