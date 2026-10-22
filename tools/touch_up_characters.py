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
        grain off it

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
        self.prim = self.j["meshes"][0]["primitives"][0]

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
    g.put(g.prim["attributes"]["POSITION"], P)

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

    def scaled(img):
        return np.array(Image.fromarray(hoof.astype(np.uint8) * 255).resize(img.size, Image.BILINEAR)).astype(float) / 255
    rough = g.image(ri)
    R = np.array(rough).astype(float)
    R[scaled(rough) > 0.5, 1] *= 0.55
    normal = g.image(ni)
    N = np.array(normal).astype(float)
    a = gaussian_filter(scaled(normal), 1.5)[..., None] * 0.85
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
