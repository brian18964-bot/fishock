"""Touch-ups on the old characters' finished models (after
tools/build_menu_character.py and tools/paint_pelt.py), made straight on the
.glb - its skin and clips as they are, only its points (and the deer's
pictures) changed. Run once on a freshly built model:

  bpyenv/bin/python tools/touch_up_characters.py bear|owl|deer IN.glb OUT.glb

  bear  user report: the brown bear's toes stood on their own ahead of its
        sole - each foot's row of toes (its own piece) slid back into the
        foot's front, following its curve, sunk SINK in
  owl   user request: the snowy owl's eyes smaller - each eye drawn in
        toward its middle to EYE of its size, the face round it closing in
        after it (or the socket shows black round the eye)
  deer  user request: the two deer's hooves alike, the red deer's made as
        fine as the sika's - each half of the cloven hoof narrowed to a
        point in front, its top sloping down to the tip, the hoof taller;
        and its picture's hoof a glossy dark brown (the sika's), the fur's
        grain off it. And its antlers as fine as the sika's too (user
        request): smoothed (their lumps gone, not shrunk - Taubin), each
        tine drawn to a point over its last TINE m, dark brown at the
        burr to cream at the tips, smooth and with a sheen

The glTF's frame: +y up, the front +z, the left +x; the feet on y = 0.
For the deer, the pictures Godot extracts beside the model
(<id>_<id>_Colour.jpg, ...) are written alongside OUT too.
"""
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_dilation, gaussian_filter
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

SINK = 0.03
EYE = 0.80
EYE_REACH = 1.9
HOOF = dict(taper=0.75, drop=0.6, ext=0.035, tall=1.3, height=0.045, pastern=0.07)
HOOF_COLOUR = (66, 44, 36)
ANTLER_SMOOTH = 40
TINE = 0.09
TIP_THIN = 0.2
# (the burr's dark, the beam's tan, the tips' cream - and how far from the
# burr and from a tip each reaches, m)
ANTLER_RAMP = [(0.0, (74, 52, 36)), (0.35, (142, 110, 78)), (1.0, (232, 220, 196))]
ANTLER_BURR = 0.06
ANTLER_TIPS = 0.14

TYPES = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
SIZES = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Glb:
    def __init__(self, path):
        b = open(path, "rb").read()
        assert b[:4] == b"glTF"
        o, self.chunks = 12, []
        while o < len(b):
            n, t = struct.unpack("<II", b[o:o + 8])
            self.chunks.append([t, bytearray(b[o + 8:o + 8 + n])])
            o += 8 + n
        self.j = json.loads(self.chunks[0][1].decode().rstrip(" \0"))
        self.bin = self.chunks[1][1]
        self.prim = self.j["meshes"][0]["primitives"][0] if self.j.get("meshes") else None

    def get(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        n, t = SIZES[a["type"]], TYPES[a["componentType"]]
        assert bv.get("byteStride", 0) in (0, np.dtype(t).itemsize * n)
        return np.frombuffer(self.bin, t, a["count"] * n, off).reshape(a["count"], n).copy(), off

    def put(self, i, arr):
        a = self.j["accessors"][i]
        _, off = self.get(i)
        raw = arr.astype(TYPES[a["componentType"]]).tobytes()
        self.bin[off:off + len(raw)] = raw
        if "min" in a:
            a["min"], a["max"] = [float(x) for x in arr.min(0)], [float(x) for x in arr.max(0)]

    def image(self, k):
        bv = self.j["bufferViews"][self.j["images"][k]["bufferView"]]
        o = bv.get("byteOffset", 0)
        return Image.open(io.BytesIO(bytes(self.bin[o:o + bv["byteLength"]]))).convert("RGB")

    def set_image(self, k, data):
        """An image's bytes replaced, the binary chunk packed again."""
        views, target = self.j["bufferViews"], self.j["images"][k]["bufferView"]
        parts = [data if i == target else bytes(self.bin[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]])
                 for i, v in enumerate(views)]
        out = bytearray()
        for v, p in zip(views, parts):
            out += b"\0" * (-len(out) % 4)
            v["byteOffset"], v["byteLength"] = len(out), len(p)
            out += p
        out += b"\0" * (-len(out) % 4)
        self.bin = self.chunks[1][1] = out
        self.j["buffers"][0]["byteLength"] = len(out)

    def save(self, path):
        js = json.dumps(self.j, separators=(",", ":")).encode()
        self.chunks[0][1] = bytearray(js + b" " * (-len(js) % 4))
        body = b"".join(struct.pack("<II", len(c), t) + bytes(c) for t, c in self.chunks)
        open(path, "wb").write(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)


def pieces(g):
    """The model's points and which piece each is (the points welded first:
    a .glb comes split at its picture's seams)."""
    P, _ = g.get(g.prim["attributes"]["POSITION"])
    tri = g.get(g.prim["indices"])[0].reshape(-1, 3)
    _, w = np.unique(np.round(P / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    w = w.ravel()
    e = np.concatenate([w[tri[:, [0, 1]]], w[tri[:, [1, 2]]]])
    n = w.max() + 1
    _, lab = connected_components(coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)), directed=False)
    return P, lab[w], tri


def ease(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def bear(g):
    P, L, _ = pieces(g)
    for c in np.unique(L):
        t = L == c
        lo, hi = P[t].min(0), P[t].max(0)
        if not (hi[1] < 0.06 and lo[2] > 0.1):
            continue
        side = np.sign(lo[0] + hi[0])
        foot = (L != c) & (P[:, 1] < 0.05) & (P[:, 0] * side > 0.05) & (P[:, 0] * side < 0.4)
        xs = np.linspace(lo[0], hi[0], 15)
        shift = []
        for x in xs:
            f = foot & (abs(P[:, 0] - x) < 0.012)
            if not f.any():
                f = foot & (abs(P[:, 0] - x) < abs(P[foot, 0] - x).min() + 0.012)
            toe = t & (abs(P[:, 0] - x) < 0.012)
            shift.append(P[f, 2].max() - SINK - P[toe, 2].min())
        shift = np.convolve(np.pad(shift, 2, mode="edge"), np.ones(5) / 5, "valid")
        P[t, 2] += np.interp(P[t, 0], xs, shift)
        print("toes (%+.0f): back %.3f..%.3f" % (side, -shift.max(), -shift.min()))
    g.put(g.prim["attributes"]["POSITION"], P)


def owl(g):
    P, L, _ = pieces(g)
    Q = P.copy()
    face = np.bincount(L).argmax()
    for c in np.unique(L):
        eye = L == c
        lo, hi = P[eye].min(0), P[eye].max(0)
        if not (lo[1] > 1.2 and hi[1] < 1.3 and abs(lo[0] + hi[0]) > 0.05):
            continue
        mid = (lo + hi) / 2
        r0 = max(hi[0] - lo[0], hi[1] - lo[1]) / 2
        d = np.linalg.norm(P[:, :2] - mid[:2], axis=1)
        k = EYE + (1.0 - EYE) * ease((d - r0) / (r0 * (EYE_REACH - 1.0)))
        k[eye] = EYE
        m = ((d < r0 * EYE_REACH) & (P[:, 2] > lo[2] - 0.02) & (np.sign(P[:, 0]) == np.sign(mid[0])) & (L == face)) | eye
        Q[m, :2] = mid[:2] + (P[m, :2] - mid[:2]) * k[m, None]
        print("eye at x %+.3f: %d points" % (mid[0], m.sum()))
    g.put(g.prim["attributes"]["POSITION"], Q)


def _welded(P, tri):
    """The points welded (the .glb's split at its picture's seams): each
    point's welded index, and each welded point's neighbours."""
    _, w = np.unique(np.round(P / 1e-5).astype(np.int64), axis=0, return_inverse=True)
    w = w.ravel()
    n = w.max() + 1
    nb = [set() for _ in range(n)]
    for t in w[tri]:
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            nb[a].add(b)
            nb[b].add(a)
    return w, [np.array(sorted(x), int) for x in nb]


def antlers(P, L, tri, N):
    """The antlers smoothed and their tines pointed (P and N changed); each
    antler point's place on ANTLER_RAMP (0 the burr, 0.35 the beam, 1 a tip;
    -1 off the antlers)."""
    import heapq
    share = np.full(len(P), -1.0)
    w, nb = _welded(P, tri)
    for c in np.unique(L):
        m = L == c
        lo, hi = P[m].min(0), P[m].max(0)
        if not (lo[1] > 1.85 and hi[1] > 2.0):
            continue
        ids = np.unique(w[m])
        at = np.zeros((w.max() + 1, 3))
        at[w[m]] = P[m]
        q = at[ids].copy()
        index = {v: i for i, v in enumerate(ids)}
        near = [np.array([index[x] for x in nb[v] if x in index], int) for v in ids]
        burr = q[:, 1] < lo[1] + 0.025
        # (Taubin: a step in, a step back out - the lumps go, the size stays)
        for k in range(ANTLER_SMOOTH * 2):
            f = 0.5 if k % 2 == 0 else -0.53
            mean = np.array([q[nn].mean(0) if len(nn) else q[i] for i, nn in enumerate(near)])
            step = (mean - q) * f
            step[burr] = 0.0
            q += step
        # how far over the antler from the burr, and from the nearest tip
        def spread(src):
            d = np.full(len(q), np.inf)
            heap = [(0.0, int(i)) for i in src]
            for _, i in heap:
                d[i] = 0.0
            heapq.heapify(heap)
            while heap:
                dd, i = heapq.heappop(heap)
                if dd > d[i]:
                    continue
                for j in near[i]:
                    nd = dd + float(np.linalg.norm(q[i] - q[j]))
                    if nd < d[j]:
                        d[j] = nd
                        heapq.heappush(heap, (nd, int(j)))
            return d
        from_burr = spread(np.nonzero(burr)[0])
        tips = [i for i in range(len(q)) if len(near[i]) and from_burr[i] >= from_burr[near[i]].max() - 1e-9
                and from_burr[i] > 0.05]
        to_tip = spread(tips)
        # each tine thinned toward its tip, to its own middle there (its
        # points' mean over the nearby ring)
        thin = TIP_THIN + (1.0 - TIP_THIN) * np.clip(to_tip / TINE, 0.0, 1.0)
        mid = q.copy()
        for _ in range(30):
            mid = np.array([mid[nn].mean(0) if len(nn) else mid[i] for i, nn in enumerate(near)])
        q = mid + (q - mid) * thin[:, None]
        at[ids] = q
        P[m] = at[w[m]]
        sh = np.zeros(w.max() + 1)
        tipness = np.clip(1.0 - to_tip / ANTLER_TIPS, 0.0, 1.0)
        burr_off = np.clip(from_burr / ANTLER_BURR, 0.0, 1.0)
        sh[ids] = 0.35 * burr_off + 0.65 * tipness
        share[m] = sh[w[m]]
        print("antler (%+.0f): %d points, %d tips" % (np.sign(lo[0] + hi[0]), len(ids), len(tips)))
    # their normals again, off their faces
    on = share >= 0.0
    acc = np.zeros((w.max() + 1, 3))
    for t in tri[on[tri].all(1)]:
        a, b, c = P[t]
        acc[w[t]] += np.cross(b - a, c - a)
    nn = acc[w[on]]
    nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-9)
    # (facing the way they did)
    flip = (nn * N[on]).sum(1).mean() < 0.0
    N[on] = -nn if flip else nn
    return share


def _paint(img, uv, tri, value, colour_of):
    """Each triangle's texels (by its UVs) painted colour_of(texels' value,
    their old colour) - `value` per point, spread over the triangle."""
    W, H = img.shape[1], img.shape[0]
    for t in tri:
        x, y = uv[t, 0] * W, uv[t, 1] * H
        x0, x1 = int(np.floor(x.min())) - 1, int(np.ceil(x.max())) + 1
        y0, y1 = int(np.floor(y.min())) - 1, int(np.ceil(y.max())) + 1
        gx, gy = np.meshgrid(np.arange(max(x0, 0), min(x1, W)) + 0.5, np.arange(max(y0, 0), min(y1, H)) + 0.5)
        den = (y[1] - y[2]) * (x[0] - x[2]) + (x[2] - x[1]) * (y[0] - y[2])
        if abs(den) < 1e-9 or gx.size == 0:
            continue
        a = ((y[1] - y[2]) * (gx - x[2]) + (x[2] - x[1]) * (gy - y[2])) / den
        b = ((y[2] - y[0]) * (gx - x[2]) + (x[0] - x[2]) * (gy - y[2])) / den
        c = 1.0 - a - b
        # (a texel past each edge too: no seam showing the old colour)
        inside = (a > -0.08) & (b > -0.08) & (c > -0.08)
        if not inside.any():
            continue
        v = a * value[t[0]] + b * value[t[1]] + c * value[t[2]]
        px, py = gx[inside].astype(int), gy[inside].astype(int)
        img[py, px] = colour_of(np.clip(v[inside], 0.0, 1.0), img[py, px])


def deer(g, out):
    P, L, tri = pieces(g)
    rest = P.copy()
    body = np.bincount(L).argmax()
    H, B = HOOF["height"], HOOF["pastern"]
    for side in (1, -1):
        sole = (L == body) & (P[:, 0] * side > 0.02) & (P[:, 0] * side < 0.3) & (P[:, 1] < 0.012)
        xc = (P[sole, 0].min() + P[sole, 0].max()) / 2
        w = P[sole, 0].max() - P[sole, 0].min()
        back, front = P[sole, 2].min(), P[sole, 2].max()
        m = (L == body) & (abs(P[:, 0] - xc) < w) & (P[:, 1] < B + 0.005)
        p = P[m]
        u = ease((p[:, 2] - (back + front) / 2) / ((front - back) / 2))
        k = 1.0 - ease((p[:, 1] - H) / 0.03)
        half = xc + np.sign(p[:, 0] - xc) * w / 4
        q = p.copy()
        q[:, 0] = half + (p[:, 0] - half) * (1.0 - HOOF["taper"] * u * k)
        q[:, 1] = p[:, 1] * (1.0 - HOOF["drop"] * u * k)
        q[:, 2] = p[:, 2] + HOOF["ext"] * u * u * k * (0.4 + 0.6 * ease(1.0 - p[:, 1] / H))
        # (taller: the hoof stretched up, the pastern over it squeezed to
        # meet the leg where it was)
        y, tall = q[:, 1], HOOF["tall"]
        q[:, 1] = np.where(y < H, y * tall, np.where(y > B, y, H * tall + (y - H) * (B - H * tall) / (B - H)))
        P[m] = q
    nrm, _ = g.get(g.prim["attributes"]["NORMAL"])
    share = antlers(P, L, tri, nrm)
    g.put(g.prim["attributes"]["POSITION"], P)
    g.put(g.prim["attributes"]["NORMAL"], nrm)

    # The picture: the hoof's black (on the triangles under the hoof's top,
    # as made) a glossy dark brown, its fur's grain off.
    uv, _ = g.get(g.prim["attributes"]["TEXCOORD_0"])
    tex = [t["source"] for t in g.j["textures"]]
    mat = g.j["materials"][0]
    ci = tex[mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    ri = tex[mat["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"]]
    ni = tex[mat["normalTexture"]["index"]]
    colour = g.image(ci)
    W, Hh = colour.size
    mask = Image.new("L", (W, Hh), 0)
    draw = ImageDraw.Draw(mask)
    for t in tri[rest[tri, 1].max(1) < 0.06]:
        draw.polygon([(uv[i, 0] * W, uv[i, 1] * Hh) for i in t], fill=255)
    C = np.array(colour).astype(float)
    lum = C.mean(2)
    hoof = binary_dilation(np.array(mask) > 0, iterations=4) & (lum < 60)
    f = np.clip(lum[hoof] / max(lum[hoof].mean(), 1.0), 0.3, 2.5) ** 0.25
    C[hoof] = np.clip(np.array(HOOF_COLOUR, float) * f[:, None], 0, 255)

    # The antlers: burr to tips, dark brown to cream (the sika's), their
    # grain kept faintly.
    on = tri[(share[tri] >= 0.0).all(1)]
    stops = np.array([x for x, _ in ANTLER_RAMP])
    ramp = np.array([c for _, c in ANTLER_RAMP], float)

    def antler_colour(v, old):
        k = np.clip(old.mean(1) / max(float(old.mean()), 1.0), 0.8, 1.2)[:, None] ** 0.35
        rgb = np.stack([np.interp(v, stops, ramp[:, i]) for i in range(3)], 1)
        return np.clip(rgb * k, 0, 255)
    _paint(C, uv, on, np.clip(share, 0.0, 1.0), antler_colour)
    horn = np.zeros(lum.shape + (1,))
    _paint(horn, uv, on, np.clip(share, 0.0, 1.0), lambda v, old: np.ones((len(v), 1)))
    horn = horn[..., 0] > 0.5

    def scaled(mask):
        return np.array(Image.fromarray(mask.astype(np.uint8) * 255).resize(normal.size, Image.BILINEAR)).astype(float) / 255
    rough = g.image(ri)
    R = np.array(rough).astype(float)
    rs = lambda mask: np.array(Image.fromarray(mask.astype(np.uint8) * 255).resize(rough.size, Image.BILINEAR)) > 127
    R[rs(hoof), 1] *= 0.55
    R[rs(horn), 1] *= 0.7
    normal = g.image(ni)
    N = np.array(normal).astype(float)
    a = gaussian_filter(scaled(hoof), 1.5)[..., None] * 0.85 + gaussian_filter(scaled(horn), 1.5)[..., None] * 0.8
    a = np.clip(a, 0.0, 0.9)
    N = N * (1.0 - a) + np.array([128.0, 128.0, 255.0]) * a
    name = os.path.splitext(os.path.basename(out))[0]
    for k, arr in ((ci, C), (ri, R), (ni, N)):
        buf = io.BytesIO()
        Image.fromarray(arr.astype(np.uint8)).save(buf, "JPEG", quality=92)
        g.set_image(k, buf.getvalue())
        side = os.path.join(os.path.dirname(out), "%s_%s.jpg" % (name, g.j["images"][k]["name"]))
        open(side, "wb").write(buf.getvalue())
        print("wrote", side)
    print("hoof: %d texels repainted" % hoof.sum())


def main():
    kind, src, out = sys.argv[1:4]
    g = Glb(src)
    if kind == "deer":
        deer(g, out)
    else:
        {"bear": bear, "owl": owl}[kind](g)
    g.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
