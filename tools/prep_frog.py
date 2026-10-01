"""The frog merchant (user request, Camp v2 fixes: the frog wanderer from
ASSET2 as the camp's merchant, its clothes painted plain - none of the
original's red). The source is a ZBrush sculpt (frog.obj: 11M vertices,
26 polygroups, no polypaint), far too heavy for Blender's importer, so it
is read and cut down here with numpy, and each part coloured by hand:

  python3 tools/prep_frog.py frog.obj OUT_DIR      (numpy, scipy, fast-simplification)

writes OUT_DIR/frog_low.npz (the game mesh, ~LOW triangles, a colour per
face; frog_high.npz, the finer copy the colours were worked out on).
tools/build_camp_models.py frog_merchant takes it from there. Like the
other source packs, the sculpt stays out of the repo.
"""
import sys

import fast_simplification
import numpy as np
import scipy.sparse as sp
from scipy.sparse.csgraph import connected_components

LOW = 18000
HIGH = 300000

# Plain colours (sRGB): a frog-green wanderer in earth and indigo cloth.
SKIN = (0.40, 0.60, 0.27)
HOOD = (0.21, 0.29, 0.40)
CAPE = (0.25, 0.34, 0.46)
LINING = (0.62, 0.55, 0.40)
SCARF = (0.80, 0.62, 0.26)
COAT = (0.44, 0.33, 0.22)
TRIM = (0.30, 0.33, 0.21)
SHIRT = (0.86, 0.80, 0.63)
PANTS = (0.38, 0.41, 0.45)
SASH = (0.20, 0.45, 0.45)
WRAP = (0.80, 0.75, 0.62)
LEATHER = (0.33, 0.22, 0.14)
BAG = (0.60, 0.49, 0.33)
ROPE = (0.78, 0.66, 0.40)
HILT = (0.22, 0.16, 0.12)
GUARD = (0.70, 0.58, 0.30)
SCABBARD = (0.26, 0.18, 0.12)
EYE = (0.93, 0.80, 0.33)
PUPIL = (0.05, 0.05, 0.06)

# The sculpt's polygroups that are one thing each.
GROUPS = {1: TRIM, 2: TRIM, 3: COAT, 4: TRIM, 5: GUARD, 6: HILT, 7: GUARD, 8: HILT, 9: LEATHER,
          10: SCABBARD, 11: GUARD, 12: WRAP, 13: LEATHER, 14: LEATHER, 15: HOOD, 17: SASH,
          18: SHIRT, 19: SHIRT, 20: SHIRT, 21: LINING, 22: LEATHER, 23: CAPE, 24: ROPE}
# Group 16 runs from the shirt down to the feet: cut by height.
SHIRT_Y, LEG_Y = -2.45, -3.55


def read_obj(path):
    """Vertices, triangles, the polygroup of each triangle."""
    vbuf, fbuf, counts, names = [], [], [], {}
    cur, n = -1, 0
    with open(path, 'rb') as fh:
        for line in fh:
            c = line[:2]
            if c == b'v ':
                vbuf.append(line[2:])
            elif c == b'f ':
                fbuf.append(line[2:])
                n += 1
            elif c == b'g ':
                if cur >= 0:
                    counts.append((cur, n))
                cur = names.setdefault(line[2:].strip().decode(), len(names))
                n = 0
    counts.append((cur, n))
    V = np.fromstring(b''.join(vbuf).replace(b'\n', b' '), sep=' ', dtype=np.float32).reshape(-1, 3)
    del vbuf
    lens = np.fromiter((l.strip().count(b' ') + 1 for l in fbuf), np.int8, len(fbuf))
    flat = np.fromstring(b''.join(fbuf).replace(b'\n', b' '), sep=' ', dtype=np.int64).astype(np.int32) - 1
    del fbuf
    starts = np.concatenate([[0], np.cumsum(lens[:-1], dtype=np.int64)])
    a, b, c = flat[starts], flat[starts + 1], flat[starts + 2]
    quad = lens == 4
    d = np.where(quad, flat[np.minimum(starts + 3, len(flat) - 1)], c)
    F = np.concatenate([np.stack([a, b, c], 1), np.stack([a, c, d], 1)[quad]])
    G0 = np.concatenate([np.full(k, g, np.int16) for g, k in counts])
    return V, F, np.concatenate([G0, G0[quad]])


def shells(V, f):
    n = len(V)
    i = np.r_[f[:, 0], f[:, 1], f[:, 2], f[:, 1], f[:, 2], f[:, 0]]
    j = np.r_[f[:, 1], f[:, 2], f[:, 0], f[:, 0], f[:, 1], f[:, 2]]
    _, lab = connected_components(sp.coo_matrix((np.ones(len(i)), (i, j)), shape=(n, n)), directed=False)
    return lab[f[:, 0]]


def paint(V, F, G):
    """A colour per triangle."""
    C = np.zeros((len(F), 3), np.float32)
    P = V[F]
    c = P.mean(1)
    for g, col in GROUPS.items():
        C[G == g] = col
    # Group 1's shells at the arms are the bands on the wrist wraps.
    C[(G == 1) & (np.abs(c[:, 0]) > 1.1) & (c[:, 1] > -2.3)] = LEATHER
    # Group 0 is the head, the arms, the coat, the scarf and the sack.
    idx = np.where(G == 0)[0]
    lab = shells(V, F[idx])
    for s in [idx[lab == k] for k in np.unique(lab)]:
        cc = c[s].mean(0)
        ext = np.ptp(P[s].reshape(-1, 3), 0)
        if len(s) < 0.002 * len(F):
            col = SHIRT
        elif cc[1] > -0.2:
            col = SKIN
        elif cc[2] < -1.2:
            col = BAG
        elif ext[0] > 2.4 and ext[1] < 1.6:
            col = SCARF
        elif abs(cc[0]) > 1.2:
            col = SKIN
        else:
            col = COAT
        C[s] = col
    s = np.where(G == 16)[0]
    y = c[s, 1]
    C[s] = PANTS
    C[s[y > SHIRT_Y]] = SHIRT
    C[s[y < LEG_Y]] = SKIN
    # The eyes: amber, a wide dark pupil looking out.
    s = np.where(G == 25)[0]
    for sign in (1, -1):
        e = s[np.sign(c[s, 0]) == sign]
        d = c[e] - np.array([0.52 * sign, 0.38, 0.6])
        d /= np.linalg.norm(d, axis=1, keepdims=True)
        out = np.array([0.55 * sign, 0.1, 0.83])
        out /= np.linalg.norm(out)
        rt = np.cross([0, 1, 0], out)
        rt /= np.linalg.norm(rt)
        up = np.cross(out, rt)
        C[e] = EYE
        C[e[(d @ out > 0) & (((d @ rt) / 0.42) ** 2 + ((d @ up) / 0.2) ** 2 < 1)]] = PUPIL
    return C


def cut_down(V, F, region, total):
    """Each region (one colour of one polygroup) brought down on its own, so
    the colours keep clean edges."""
    Vs, Fs, Rs = [], [], []
    off = 0
    for r in np.unique(region):
        f = F[region == r]
        used, inv = np.unique(f, return_inverse=True)
        v = V[used]
        f = inv.reshape(-1, 3).astype(np.int32)
        want = max(int(total * len(f) / len(F)), 40)
        if want < len(f):
            v, f = fast_simplification.simplify(v, f, target_reduction=1.0 - want / len(f))
        Vs.append(v)
        Fs.append(f + off)
        Rs.append(np.full(len(f), r, np.int32))
        off += len(v)
    return np.concatenate(Vs).astype(np.float32), np.concatenate(Fs).astype(np.int32), np.concatenate(Rs)


def main():
    src, out = sys.argv[1], sys.argv[2]
    V, F, G = read_obj(src)
    print("read", len(V), "vertices", len(F), "triangles", flush=True)
    # First a high copy, by polygroup; the colours from it.
    Vh, Fh, Gh = cut_down(V, F, G.astype(np.int32), HIGH)
    del V, F, G
    C = paint(Vh, Fh, Gh)
    np.savez_compressed(out + "/frog_high.npz", V=Vh, F=Fh, G=Gh, C=C)
    keys, region = np.unique(np.c_[Gh, (C * 255).astype(np.int32)], axis=0, return_inverse=True)
    Vl, Fl, R = cut_down(Vh, Fh, region.ravel(), LOW)
    np.savez_compressed(out + "/frog_low.npz", V=Vl, F=Fl, C=keys[R, 1:].astype(np.float32) / 255.0)
    print("wrote", len(Fh), "and", len(Fl), "triangles", flush=True)


if __name__ == "__main__":
    main()
