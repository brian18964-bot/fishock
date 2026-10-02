"""Signed-distance modelling for the greybox characters: shapes built from
primitives (spheres, ellipsoids, capsules, round cones, boxes, tori, half
spaces) joined with smooth unions / cuts, evaluated on a grid in chunks
(each chunk only asks the shapes whose bounds reach it) and meshed with
marching cubes into a Blender mesh.

Distances are in metres. Every node knows a world bounding box; a node
whose box (grown by the blend around it) misses a chunk is left out of
that chunk, which is what keeps a whole character quick to mesh.

    import sdf_mesh as S
    arm = S.smooth([S.round_cone(a, b, 0.04, 0.03), S.sphere(c, 0.05)], 0.02)
    ob = S.mesh("arm", arm, voxel=0.0025)
"""
import math

import numpy as np

FAR = 1.0  # what a left-out node reads as: well outside anything meshed


def _v(p):
    return np.asarray(p, dtype=np.float64)


def _len(a):
    return np.sqrt(np.einsum("ij,ij->i", a, a))


def smin(a, b, k):
    """Polynomial smooth minimum (blend radius k)."""
    if k <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def frame(z, y_hint=(0.0, 0.0, 1.0)):
    """A rotation (columns x, y, z) whose z is along `z`, x across it and
    y_hint (the hint itself swapped for another when parallel)."""
    z = _v(z) / np.linalg.norm(z)
    h = _v(y_hint)
    if abs(np.dot(h, z)) > 0.99:
        h = _v((1.0, 0.0, 0.0)) if abs(z[0]) < 0.9 else _v((0.0, 1.0, 0.0))
    x = np.cross(h, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)


def rot(axis, degrees):
    """Rotation matrix about a world axis ('x', 'y', 'z' or a vector)."""
    if isinstance(axis, str):
        axis = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis]
    a = _v(axis) / np.linalg.norm(axis)
    t = math.radians(degrees)
    c, s = math.cos(t), math.sin(t)
    x, y, z = a
    return np.array([[c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
                     [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
                     [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])


class Node:
    lo = hi = None

    def hits(self, lo, hi, margin):
        return bool(np.all(self.lo - margin <= hi) and np.all(self.hi + margin >= lo))

    def ev(self, P, lo=None, hi=None, margin=0.0):
        """Distances at points P (n, 3); None when the node's box misses
        the chunk lo..hi (grown by margin) - read as FAR."""
        if lo is not None and not self.hits(lo, hi, margin):
            return None
        return self.f(P, lo, hi, margin)

    def __call__(self, P):
        d = self.ev(_v(P).reshape(-1, 3))
        return np.full(len(P), FAR) if d is None else d


class Prim(Node):
    def __init__(self, fn, lo, hi):
        self.fn, self.lo, self.hi = fn, _v(lo), _v(hi)

    def f(self, P, lo, hi, margin):
        return self.fn(P)


def _box_of(points, r):
    pts = np.atleast_2d(_v(points))
    return pts.min(axis=0) - r, pts.max(axis=0) + r


def sphere(c, r):
    c = _v(c)
    return Prim(lambda P: _len(P - c) - r, c - r, c + r)


def capsule(a, b, r):
    return round_cone(a, b, r, r)


def round_cone(a, b, ra, rb):
    """Capsule from a (radius ra) to b (radius rb) - Inigo Quilez's."""
    a, b = _v(a), _v(b)
    ba = b - a
    l2 = float(ba @ ba)
    rr = ra - rb
    a2 = l2 - rr * rr
    il2 = 1.0 / l2

    def fn(P):
        pa = P - a
        y = pa @ ba
        z = y - l2
        q = pa * l2 - y[:, None] * ba
        x2 = np.einsum("ij,ij->i", q, q)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - ra
        top = np.sign(z) * a2 * z2 > k
        bot = np.sign(y) * a2 * y2 < k
        d = np.where(top, np.sqrt(x2 + z2) * il2 - rb, d)
        d = np.where(bot & ~top, np.sqrt(x2 + y2) * il2 - ra, d)
        return d
    lo = np.minimum(a - ra, b - rb)
    hi = np.maximum(a + ra, b + rb)
    return Prim(fn, lo, hi)


def chain(points, radii):
    """Round cones joined end to end (a hard union - they share ends)."""
    return union([round_cone(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)])


def ellipsoid(c, r, R=None):
    """Ellipsoid with radii r = (rx, ry, rz) in the frame R (columns; world
    axes if None) - the near-surface bound IQ uses."""
    c, r = _v(c), _v(r)
    R = np.eye(3) if R is None else _v(R)

    def fn(P):
        q = (P - c) @ R
        k0 = _len(q / r)
        k1 = _len(q / (r * r))
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    corners = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]) * r
    w = corners @ R.T + c
    return Prim(fn, w.min(axis=0), w.max(axis=0))


def box(c, half, R=None, round_r=0.0):
    """Rounded box: centre c, half extents `half` (rounding inside them)."""
    c, half = _v(c), _v(half)
    R = np.eye(3) if R is None else _v(R)
    b = half - round_r

    def fn(P):
        q = np.abs((P - c) @ R) - b
        return _len(np.maximum(q, 0.0)) + np.minimum(q.max(axis=1), 0.0) - round_r
    corners = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]) * half
    w = corners @ R.T + c
    return Prim(fn, w.min(axis=0), w.max(axis=0))


def torus(c, axis, R_major, r_minor, scale_minor=(1.0, 1.0)):
    """Ring around `axis` through c; its tube may be an ellipse
    (scale_minor = its radial and axial stretch)."""
    c = _v(c)
    M = frame(axis)
    er = r_minor * scale_minor[0]
    ea = r_minor * scale_minor[1]

    def fn(P):
        q = (P - c) @ M
        rad = np.sqrt(q[:, 0] ** 2 + q[:, 1] ** 2) - R_major
        ax = q[:, 2]
        k0 = np.sqrt((rad / er) ** 2 + (ax / ea) ** 2)
        k1 = np.sqrt((rad / er ** 2) ** 2 + (ax / ea ** 2) ** 2)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    ext = R_major + er
    corners = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]) * \
        np.array([ext, ext, ea])
    w = corners @ M.T + c
    return Prim(fn, w.min(axis=0), w.max(axis=0))


def half_space(point, normal, extent=2.0):
    """Everything on the far side of the plane from `normal` (inside where
    (p - point) . n < 0); its box is `extent` around the point."""
    p0 = _v(point)
    n = _v(normal) / np.linalg.norm(normal)
    return Prim(lambda P: (P - p0) @ n, p0 - extent, p0 + extent)


def tube(points, radii, close=False):
    """A swept tube through points (round cones between them)."""
    pts = list(points)
    rs = list(radii)
    if close:
        pts.append(pts[0])
        rs.append(rs[0])
    return union([round_cone(pts[i], pts[i + 1], rs[i], rs[i + 1]) for i in range(len(pts) - 1)])


def polygon2d(Q, poly):
    """Signed distance in the plane to a closed polygon (IQ's)."""
    v = np.asarray(poly, dtype=np.float64)
    px, py = Q[:, 0], Q[:, 1]
    d = (px - v[0, 0]) ** 2 + (py - v[0, 1]) ** 2
    sgn = np.ones(len(Q))
    j = len(v) - 1
    for i in range(len(v)):
        ex, ey = v[j, 0] - v[i, 0], v[j, 1] - v[i, 1]
        wx, wy = px - v[i, 0], py - v[i, 1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, bx * bx + by * by)
        c1 = py >= v[i, 1]
        c2 = py < v[j, 1]
        c3 = ex * wy > ey * wx
        flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        sgn = np.where(flip, -sgn, sgn)
        j = i
    return sgn * np.sqrt(d)


def plate(c, R, poly, half_t, round_r=0.0):
    """A flat piece: the polygon `poly` (in the frame R's x-y about c)
    `half_t` thick either side along R's z, edges rounded by round_r."""
    c = _v(c)
    R = _v(R)
    pts = np.asarray(poly, dtype=np.float64)

    def fn(P):
        q = (P - c) @ R
        dx = polygon2d(q, pts)
        dz = np.abs(q[:, 2]) - half_t
        return np.minimum(np.maximum(dx, dz), 0.0) + np.sqrt(np.maximum(dx, 0.0) ** 2 + np.maximum(dz, 0.0) ** 2) - round_r
    ext = np.array([[x, y, z] for x, y in pts for z in (-half_t - round_r, half_t + round_r)])
    w = ext @ R.T + c
    return Prim(fn, w.min(axis=0) - round_r, w.max(axis=0) + round_r)


class Squash(Node):
    """a stretched by s (three factors, along R's axes) about c - for
    flattening a shape; distances are scaled down to stay a bound."""

    def __init__(self, a, c, s, R=None):
        self.a, self.c, self.s = a, _v(c), _v(s)
        self.R = np.eye(3) if R is None else _v(R)
        corners = np.array([[x, y, z] for x in (a.lo[0], a.hi[0]) for y in (a.lo[1], a.hi[1])
                            for z in (a.lo[2], a.hi[2])])
        w = self.c + (((corners - self.c) @ self.R) * self.s) @ self.R.T
        self.lo, self.hi = w.min(axis=0), w.max(axis=0)

    def f(self, P, lo, hi, margin):
        Q = self.c + (((P - self.c) @ self.R) / self.s) @ self.R.T
        d = self.a.ev(Q)
        return None if d is None else d * float(self.s.min())


def squash(a, c, s, R=None):
    return Squash(a, c, s, R)


class Union(Node):
    def __init__(self, kids, k=0.0):
        self.kids = [c for c in kids if c is not None]
        self.k = k
        self.lo = np.min([c.lo for c in self.kids], axis=0) - k * 0.25
        self.hi = np.max([c.hi for c in self.kids], axis=0) + k * 0.25

    def f(self, P, lo, hi, margin):
        d = None
        for c in self.kids:
            dc = c.ev(P, lo, hi, margin + self.k)
            if dc is None:
                continue
            d = dc if d is None else smin(d, dc, self.k)
        return d


def union(kids, k=0.0):
    kids = [c for c in kids if c is not None]
    return kids[0] if len(kids) == 1 else Union(kids, k)


def smooth(kids, k):
    return union(kids, k)


class Cut(Node):
    """a with b taken out (smoothly over k)."""

    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, k
        self.lo, self.hi = a.lo, a.hi

    def f(self, P, lo, hi, margin):
        da = self.a.ev(P, lo, hi, margin + self.k)
        if da is None:
            return None
        db = self.b.ev(P, lo, hi, margin + self.k)
        return da if db is None else smax(da, -db, self.k)


def cut(a, b, k=0.0):
    return Cut(a, b, k) if b is not None else a


class Inter(Node):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, k
        self.lo = np.maximum(a.lo, b.lo)
        self.hi = np.minimum(a.hi, b.hi)

    def f(self, P, lo, hi, margin):
        da = self.a.ev(P, lo, hi, margin + self.k)
        if da is None:
            return None
        db = self.b.ev(P, lo, hi, margin + self.k)
        return None if db is None else smax(da, db, self.k)


def inter(a, b, k=0.0):
    return Inter(a, b, k)


class Offset(Node):
    """The surface pushed out by r (or in, r < 0)."""

    def __init__(self, a, r):
        self.a, self.r = a, r
        self.lo, self.hi = a.lo - max(r, 0.0), a.hi + max(r, 0.0)

    def f(self, P, lo, hi, margin):
        d = self.a.ev(P, lo, hi, margin + abs(self.r))
        return None if d is None else d - self.r


def offset(a, r):
    return Offset(a, r)


class Warp(Node):
    """a evaluated at points moved by fn (a small, smooth displacement:
    keep its stretch low or the distances stop being distances)."""

    def __init__(self, a, fn, reach):
        self.a, self.fn, self.reach = a, fn, reach
        self.lo, self.hi = a.lo - reach, a.hi + reach

    def f(self, P, lo, hi, margin):
        if lo is None:
            return self.a.ev(self.fn(P))
        return self.a.ev(self.fn(P), lo - self.reach, hi + self.reach, margin)


class Displace(Node):
    """a's distance plus fn(P) (|fn| <= amp)."""

    def __init__(self, a, fn, amp):
        self.a, self.fn, self.amp = a, fn, amp
        self.lo, self.hi = a.lo - amp, a.hi + amp

    def f(self, P, lo, hi, margin):
        d = self.a.ev(P, lo, hi, margin + self.amp)
        return None if d is None else d + self.fn(P)


class Mirror(Node):
    """a (modelled on the +x side) and its mirror across x = 0: points
    folded onto +x - with fold > 0 the fold is rounded, so what meets at
    the middle blends instead of creasing."""

    def __init__(self, a, fold=0.0):
        self.a, self.fold = a, fold
        lo, hi = a.lo.copy(), a.hi.copy()
        self.lo = np.minimum(lo, np.array([-hi[0], lo[1], lo[2]]))
        self.hi = np.maximum(hi, np.array([-lo[0], hi[1], hi[2]]))

    def f(self, P, lo, hi, margin):
        Q = P.copy()
        Q[:, 0] = np.sqrt(Q[:, 0] ** 2 + self.fold ** 2) - self.fold if self.fold else np.abs(Q[:, 0])
        if lo is None:
            return self.a.ev(Q)
        if lo[0] >= 0.0:
            x0, x1 = lo[0], hi[0]
        elif hi[0] <= 0.0:
            x0, x1 = -hi[0], -lo[0]
        else:
            x0, x1 = 0.0, max(-lo[0], hi[0])
        return self.a.ev(Q, np.array([x0, lo[1], lo[2]]), np.array([x1, hi[1], hi[2]]), margin)


def mirror(a, fold=0.0):
    return Mirror(a, fold)


# --- meshing -----------------------------------------------------------

def grid_eval(node, lo, hi, voxel, block=16, safety=1.6):
    """node's distances on the grid lo..hi (spacing voxel): first at each
    block's centre (block^3 voxels) - a block clearly inside or outside
    is filled with -FAR / FAR - then voxel by voxel in the blocks the
    surface may cross (each asking only the shapes that reach it)."""
    lo = _v(lo)
    hi = _v(hi)
    n = np.ceil((hi - lo) / voxel).astype(int) + 1
    nb = -(-n // block)
    cx = [lo[a] + (np.arange(nb[a]) * block + (block - 1) / 2.0) * voxel for a in range(3)]
    X, Y, Z = np.meshgrid(cx[0], cx[1], cx[2], indexing="ij")
    dc = node(np.stack([X.ravel(), Y.ravel(), Z.ravel()], axis=1)).reshape(X.shape)
    reach = math.sqrt(3.0) * (block - 1) / 2.0 * voxel * safety + 2.0 * voxel
    vol = np.empty(tuple(n), dtype=np.float32)
    for bi in range(nb[0]):
        for bj in range(nb[1]):
            for bk in range(nb[2]):
                i0, j0, k0 = bi * block, bj * block, bk * block
                i1, j1, k1 = min(i0 + block, n[0]), min(j0 + block, n[1]), min(k0 + block, n[2])
                d0 = dc[bi, bj, bk]
                if d0 > reach:
                    vol[i0:i1, j0:j1, k0:k1] = FAR
                    continue
                if d0 < -reach:
                    vol[i0:i1, j0:j1, k0:k1] = -FAR
                    continue
                xs = lo[0] + np.arange(i0, i1) * voxel
                ys = lo[1] + np.arange(j0, j1) * voxel
                zs = lo[2] + np.arange(k0, k1) * voxel
                clo = np.array([xs[0], ys[0], zs[0]])
                chi = np.array([xs[-1], ys[-1], zs[-1]])
                Xb, Yb, Zb = np.meshgrid(xs, ys, zs, indexing="ij")
                P = np.stack([Xb.ravel(), Yb.ravel(), Zb.ravel()], axis=1)
                d = node.ev(P, clo, chi, 2.0 * voxel)
                vol[i0:i1, j0:j1, k0:k1] = FAR if d is None else d.reshape(Xb.shape)
    return vol


def polygonise(node, voxel, pad=None, bounds=None):
    """Vertices (n, 3) and triangles (m, 3) of node's zero surface."""
    from skimage.measure import marching_cubes
    pad = 3 * voxel if pad is None else pad
    lo, hi = (node.lo, node.hi) if bounds is None else bounds
    lo = _v(lo) - pad
    hi = _v(hi) + pad
    vol = grid_eval(node, lo, hi, voxel)
    if vol.min() > 0.0 or vol.max() < 0.0:
        return np.zeros((0, 3)), np.zeros((0, 3), dtype=int)
    verts, faces, _, _ = marching_cubes(vol, level=0.0, spacing=(voxel, voxel, voxel), allow_degenerate=False)
    verts = verts + lo
    # (skimage's winding, for a field negative inside, already faces out)
    return verts, faces


def drop_crumbs(verts, faces, keep_frac=0.002):
    """Faces in pieces smaller than keep_frac of the biggest piece taken
    away (shapes thinner than the grid break into crumbs)."""
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    if len(faces) == 0:
        return verts, faces
    n = len(verts)
    a = np.concatenate([faces[:, 0], faces[:, 1], faces[:, 2]])
    b = np.concatenate([faces[:, 1], faces[:, 2], faces[:, 0]])
    g = coo_matrix((np.ones(len(a)), (a, b)), shape=(n, n))
    ncomp, lab = connected_components(g, directed=False)
    if ncomp == 1:
        return verts, faces
    fl = lab[faces[:, 0]]
    counts = np.bincount(fl, minlength=ncomp)
    keep = counts[fl] >= max(counts.max() * keep_frac, 40)
    faces = faces[keep]
    used = np.unique(faces)
    remap = -np.ones(n, dtype=np.int64)
    remap[used] = np.arange(len(used))
    return verts[used], remap[faces]


def mesh(name, node, voxel=0.0025, bounds=None, materials=None, labels=None, smooth_iters=0, crumbs=True):
    """A Blender object of node's surface. `labels` [(material index,
    node)]: a face takes the first whose node is at its centre (within a
    voxel); the rest keep 0. `materials` are appended in order."""
    import bpy
    verts, faces = polygonise(node, voxel, bounds=bounds)
    if crumbs:
        verts, faces = drop_crumbs(verts, faces)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], faces.tolist())
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if materials:
        for m in materials:
            me.materials.append(m)
    if labels and len(me.polygons):
        cen = np.zeros(len(me.polygons) * 3)
        me.polygons.foreach_get("center", cen)
        cen = cen.reshape(-1, 3)
        idx = np.zeros(len(cen), dtype=np.int32)
        done = np.zeros(len(cen), dtype=bool)
        for mi, ln in labels:
            d = ln(cen)
            hit = (~done) & (d < voxel * 1.0)
            idx[hit] = mi
            done |= hit
        me.polygons.foreach_set("material_index", idx)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    if smooth_iters:
        md = ob.modifiers.new("smooth", "SMOOTH")
        md.iterations = smooth_iters
        md.factor = 0.5
    return ob
