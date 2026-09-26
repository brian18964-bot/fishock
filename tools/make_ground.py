"""Procedural, seamlessly tiling ground textures (albedo + normal map).

User request: each map style gets its own ground (grass, gravel, dirt,
sand...) instead of one flat colour. The texture sites are out of reach from
the build machine, so they're generated here: periodic noise (FFT-filtered,
so it wraps), jittered-grid Voronoi stones with wrap-around neighbours, and
strokes/ellipses stamped with wrap-around. Every tile covers TILE / 2 = 256
world px, with shapes squashed vertically by sin 55deg to match the camera.
All sizes and positions below are in "design" texels (TILE per tile, 2 per
world px); the images are rendered DENSITY times finer - N = TILE * DENSITY
texels square (user request: a sharper picture - 2, i.e. 4 texels per
world px like the sprites, see scripts/art.gd). Normal maps are written at
TILE square: lighting doesn't need the extra detail.

Normals use the sprites' encoding: n * 0.5 + 0.5, X right, Y up the screen,
Z toward the viewer; flat ground is (0, 0, 1).

  python tools/make_ground.py [--density D] [--only a,b] OUT_DIR

writes OUT_DIR/<name>_albedo.png and <name>_normal.png for every entry of
MAKERS.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TILE = 512  # design texels per tile
DENSITY = 2  # rendered texels per design texel (--density)
N = TILE * DENSITY
SQUASH = 0.819  # sin 55deg


# --- helpers -----------------------------------------------------------------

def periodic_noise(rng, feature, beta=1.0):
    """Tileable noise in 0..1; `feature` ~ blob size in design texels."""
    k = np.sqrt(np.fft.fftfreq(N)[:, None] ** 2 + (np.fft.fftfreq(N)[None, :] * SQUASH) ** 2)
    k[0, 0] = 1.0
    env = np.exp(-(k * feature * DENSITY / 2.0) ** 2) / k ** beta
    env[0, 0] = 0.0
    spec = (rng.normal(size=(N, N)) + 1j * rng.normal(size=(N, N))) * env
    f = np.real(np.fft.ifft2(spec))
    f -= f.min()
    return f / max(f.max(), 1e-9)


def voronoi(rng, cell, jitter=0.9):
    """Jittered-grid Voronoi on the torus. Returns (F1, F2, id) per texel,
    distances in design texels."""
    n = TILE // cell
    gx0, gy0 = np.meshgrid(np.arange(n), np.arange(n))
    pts = np.stack([gx0 + 0.5 + (rng.random((n, n)) - 0.5) * jitter,
                    gy0 + 0.5 + (rng.random((n, n)) - 0.5) * jitter], -1) * cell
    # Texel centres, in design texels (texel i sits at i when DENSITY is 1).
    ys, xs = (np.mgrid[0:N, 0:N].astype(np.float32) + 0.5) / DENSITY - 0.5
    cx, cy = (xs // cell).astype(int), (ys // cell).astype(int)
    f1 = np.full((N, N), 1e9, np.float32)
    f2 = np.full((N, N), 1e9, np.float32)
    ident = np.zeros((N, N), np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            gx, gy = cx + dx, cy + dy
            wx, wy = gx % n, gy % n
            p = pts[wy, wx]
            px = p[..., 0] + (gx - wx) * cell
            py = p[..., 1] + (gy - wy) * cell
            d = np.sqrt((xs - px) ** 2 + ((ys - py) / SQUASH) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ident = np.where(closer, wy * n + wx, ident)
            f1 = np.where(closer, d, f1)
    return f1, f2, ident


class Canvas:
    """Stamps shapes into a colour layer and a height layer, wrapping at the
    tile edges (every shape is drawn at its 3x3 torus copies). Takes design
    texels, draws DENSITY x finer."""

    def __init__(self):
        self.col = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.h = Image.new("L", (N, N), 0)
        self.dc = ImageDraw.Draw(self.col)
        self.dh = ImageDraw.Draw(self.h)

    def _copies(self, pts):
        for ox in (-TILE, 0, TILE):
            for oy in (-TILE, 0, TILE):
                yield [((x + ox) * DENSITY, (y + oy) * DENSITY) for x, y in pts]

    def line(self, p0, p1, color, width, height):
        for c in self._copies([p0, p1]):
            self.dc.line(c, fill=color, width=width * DENSITY)
            self.dh.line(c, fill=height, width=width * DENSITY)

    def poly(self, pts, color, height):
        for c in self._copies(pts):
            self.dc.polygon(c, fill=color)
            self.dh.polygon(c, fill=height)

    def ellipse(self, cx, cy, rx, ry, angle, color, height, sides=10):
        pts = []
        for i in range(sides):
            a = i / sides * math.tau
            x, y = math.cos(a) * rx, math.sin(a) * ry
            ca, sa = math.cos(angle), math.sin(angle)
            pts.append((cx + x * ca - y * sa, cy + (x * sa + y * ca) * SQUASH))
        self.poly(pts, color, height)

    def layers(self):
        col = np.asarray(self.col, np.float32) / 255.0
        h = np.asarray(self.h, np.float32) / 255.0
        return col[..., :3], col[..., 3], h


def over(base, layer_rgb, alpha):
    return base * (1.0 - alpha[..., None]) + layer_rgb * alpha[..., None]


def lerp(a, b, t):
    return np.asarray(a, np.float32) + (np.asarray(b, np.float32) - np.asarray(a, np.float32)) * t[..., None]


def jitter_color(rng, c, amount=0.12):
    f = 1.0 + (rng.random() - 0.5) * 2 * amount
    return tuple(int(max(0, min(255, v * 255 * f))) for v in c) + (255,)


def normal_from_height(h, strength):
    # Slopes per design texel, so the relief reads the same at any density.
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * DENSITY
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * DENSITY
    n = np.stack([-dx * strength, dy * strength, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def blur(h, r):
    img = Image.fromarray(np.clip(h * 255, 0, 255).astype(np.uint8))
    # Blur a 3x3 tiling so the edges stay seamless.
    big = Image.new("L", (N * 3, N * 3))
    for ox in range(3):
        for oy in range(3):
            big.paste(img, (ox * N, oy * N))
    big = big.filter(ImageFilter.GaussianBlur(r * DENSITY))
    return np.asarray(big.crop((N, N, 2 * N, 2 * N)), np.float32) / 255.0


def blades(rng, cv, count, colors, length=(5, 11), width=2, lean=0.35, height=(150, 255)):
    for _ in range(count):
        x, y = rng.random() * TILE, rng.random() * TILE
        ln = rng.uniform(*length)
        a = -math.pi / 2 + rng.uniform(-lean, lean)
        c = jitter_color(rng, colors[rng.integers(len(colors))])
        cv.line((x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln * SQUASH), c, width,
                int(rng.uniform(*height)))


# --- ground types --------------------------------------------------------------

def grass(rng, light=False):
    base_a, base_b = ((0.2, 0.3, 0.12), (0.3, 0.4, 0.16)) if light else ((0.12, 0.2, 0.08), (0.2, 0.3, 0.11))
    n = periodic_noise(rng, 60)
    col = lerp(base_a, base_b, n)
    soil = periodic_noise(rng, 14) > 0.72
    col = np.where(soil[..., None], col * 0.55 + np.array([0.06, 0.04, 0.02]), col)
    cv = Canvas()
    greens = [(0.24, 0.38, 0.13), (0.3, 0.45, 0.16), (0.18, 0.3, 0.1), (0.36, 0.48, 0.2)]
    if light:
        greens = [(0.34, 0.48, 0.18), (0.42, 0.54, 0.22), (0.28, 0.42, 0.15), (0.5, 0.56, 0.26)]
    blades(rng, cv, 6000, greens, length=(3, 11))
    if light:
        for _ in range(140):
            c = [(0.95, 0.95, 0.9), (0.95, 0.85, 0.35), (0.8, 0.6, 0.9)][rng.integers(3)]
            cv.ellipse(rng.random() * TILE, rng.random() * TILE, 2.2, 2.2, 0, jitter_color(rng, c, 0.05), 220, 6)
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = blur(n, 3) * 0.3 + lh * 0.7
    return col, normal_from_height(h, 5.0)


def leaf_litter(rng):
    n = periodic_noise(rng, 50)
    col = lerp((0.14, 0.1, 0.06), (0.22, 0.15, 0.08), n)
    cv = Canvas()
    leaf = [(0.62, 0.22, 0.08), (0.75, 0.38, 0.1), (0.52, 0.14, 0.08), (0.7, 0.52, 0.16), (0.45, 0.28, 0.12)]
    for _ in range(750):
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(4, 8), rng.uniform(2.2, 3.8),
                   rng.random() * math.pi, jitter_color(rng, leaf[rng.integers(len(leaf))]),
                   int(rng.uniform(120, 255)), 8)
    blades(rng, cv, 1800, [(0.22, 0.32, 0.12), (0.28, 0.36, 0.14), (0.18, 0.28, 0.1)])
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    return col, normal_from_height(blur(lh, 0.8), 4.0)


def forest_floor(rng):
    n = periodic_noise(rng, 70)
    col = lerp((0.13, 0.09, 0.05), (0.2, 0.14, 0.08), n)
    moss = np.clip((periodic_noise(rng, 90) - 0.55) * 6.0, 0, 1)
    col = col * (1 - moss[..., None] * 0.85) + np.array([0.16, 0.24, 0.09]) * moss[..., None] * 0.85
    cv = Canvas()
    needles = [(0.42, 0.26, 0.12), (0.34, 0.2, 0.1), (0.5, 0.34, 0.16), (0.28, 0.18, 0.08)]
    for _ in range(4200):
        x, y = rng.random() * TILE, rng.random() * TILE
        a = rng.random() * math.pi
        ln = rng.uniform(5, 10)
        cv.line((x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln * SQUASH),
                jitter_color(rng, needles[rng.integers(len(needles))]), 1, int(rng.uniform(90, 200)))
    for _ in range(40):
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(3, 5), rng.uniform(4, 6), rng.random() * 3,
                   jitter_color(rng, (0.36, 0.24, 0.12)), 255, 8)  # cones
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = blur(moss, 2) * 0.4 + lh * 0.6
    return col, normal_from_height(h, 4.0)


def dirt(rng):
    n = periodic_noise(rng, 80)
    n2 = periodic_noise(rng, 12)
    col = lerp((0.2, 0.16, 0.11), (0.3, 0.24, 0.16), n * 0.7 + n2 * 0.3)
    f1, f2, _ = voronoi(rng, 64, 1.0)
    crack = np.clip(1.0 - (f2 - f1) / 2.0, 0, 1) * (periodic_noise(rng, 30) > 0.45)
    col = col * (1 - crack[..., None] * 0.55)
    cv = Canvas()
    for _ in range(420):
        g = rng.uniform(0.28, 0.45)
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(1.5, 3.5), rng.uniform(1.5, 3),
                   rng.random() * 3, jitter_color(rng, (g, g * 0.92, g * 0.85)), 230, 7)
    blades(rng, cv, 700, [(0.42, 0.36, 0.2), (0.5, 0.42, 0.24), (0.34, 0.3, 0.18)], length=(6, 13), width=1)
    for _ in range(60):  # twigs
        x, y = rng.random() * TILE, rng.random() * TILE
        a, ln = rng.random() * math.pi, rng.uniform(10, 22)
        cv.line((x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln * SQUASH), jitter_color(rng, (0.26, 0.18, 0.1)), 2, 180)
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = n2 * 0.25 - crack * 0.3 + lh * 0.6
    return col, normal_from_height(h, 5.0)


def gravel(rng):
    f1, f2, ident = voronoi(rng, 16, 0.95)
    tone = np.random.default_rng(int(rng.integers(1 << 30))).random(ident.max() + 1)[ident]
    warm = np.random.default_rng(int(rng.integers(1 << 30))).random(ident.max() + 1)[ident]
    g = 0.24 + tone * 0.22
    col = np.stack([g * (1.0 + warm * 0.08), g * (1.0 + warm * 0.03), g * (0.96 - warm * 0.05)], -1)
    edge = np.clip((f2 - f1) / 3.5, 0, 1)
    dome = np.clip(1.0 - (f1 / 9.0) ** 2, 0, 1)
    h = dome * edge ** 0.5
    col = col * (0.35 + 0.65 * edge[..., None] ** 0.6)
    grit = periodic_noise(rng, 2.5)
    col = col * (0.9 + grit[..., None] * 0.2)
    gap_dirt = np.array([0.1, 0.09, 0.07])
    col = np.where((edge < 0.15)[..., None], gap_dirt, col)
    return col, normal_from_height(blur(h, 0.7) + grit * 0.05, 9.0)


def sand(rng):
    n = periodic_noise(rng, 90)
    grit = periodic_noise(rng, 1.8)
    col = lerp((0.42, 0.35, 0.22), (0.52, 0.44, 0.28), n)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float32) / DENSITY
    warp = periodic_noise(rng, 70) * 5.0
    ripple = np.sin(2 * np.pi * (3 * xs + 7 * ys) / TILE * 1.0 + warp) * 0.5 + 0.5
    col = col * (0.93 + ripple[..., None] * 0.1) * (0.92 + grit[..., None] * 0.16)
    cv = Canvas()
    for _ in range(160):
        c = [(0.85, 0.8, 0.7), (0.6, 0.55, 0.48), (0.9, 0.75, 0.65)][rng.integers(3)]
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(1.5, 3), rng.uniform(1.2, 2.4),
                   rng.random() * 3, jitter_color(rng, c, 0.08), 200, 7)
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = ripple * 0.35 + grit * 0.08 + lh * 0.5
    return col, normal_from_height(h, 3.0)


def moss_soil(rng):
    n = periodic_noise(rng, 60)
    col = lerp((0.08, 0.07, 0.05), (0.13, 0.11, 0.07), n)
    moss = np.clip((periodic_noise(rng, 55) - 0.42) * 4.0, 0, 1)
    moss_col = lerp((0.12, 0.2, 0.07), (0.2, 0.3, 0.1), periodic_noise(rng, 6))
    col = col * (1 - moss[..., None]) + moss_col * moss[..., None]
    cv = Canvas()
    for _ in range(90):  # little fern fronds
        x, y = rng.random() * TILE, rng.random() * TILE
        a = rng.random() * math.tau
        c = jitter_color(rng, (0.2, 0.34, 0.12))
        for k in range(6):
            t = k / 6 * 9
            px, py = x + math.cos(a) * t, y + math.sin(a) * t * SQUASH
            for s in (-1, 1):
                b = a + s * 1.1
                cv.line((px, py), (px + math.cos(b) * 3.5, py + math.sin(b) * 3.5 * SQUASH), c, 1, 200)
    for _ in range(300):
        g = rng.uniform(0.15, 0.3)
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(1.5, 3), rng.uniform(1.5, 2.5),
                   rng.random() * 3, jitter_color(rng, (g, g, g * 0.9)), 220, 7)
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = blur(moss, 1.5) * 0.4 + blur(periodic_noise(rng, 4), 0.5) * 0.15 + lh * 0.5
    return col, normal_from_height(h, 5.0)


def snow(rng):
    """User request (more map styles): a snowfield - soft drifts, wind
    ripples, sparkle, footprint dimples, dry grass tips poking through."""
    n = periodic_noise(rng, 110)
    drift = periodic_noise(rng, 35)
    col = lerp((0.60, 0.64, 0.71), (0.80, 0.83, 0.89), n * 0.6 + drift * 0.4)
    ys, xs = np.mgrid[0:N, 0:N].astype(np.float32) / DENSITY
    warp = periodic_noise(rng, 80) * 6.0
    ripple = np.sin(2 * np.pi * (2 * xs + 5 * ys) / TILE + warp) * 0.5 + 0.5
    col = col * (0.96 + ripple[..., None] * 0.05)
    cv = Canvas()
    for _ in range(90):  # footprint-like dimples, faintly blue
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(2.5, 4), rng.uniform(4, 6),
                   rng.random() * 3, jitter_color(rng, (0.55, 0.6, 0.7), 0.05), 40, 8)
    blades(rng, cv, 260, [(0.45, 0.4, 0.28), (0.36, 0.32, 0.22), (0.3, 0.3, 0.26)], length=(3, 7), width=1)
    for _ in range(500):  # sparkle
        g = rng.uniform(0.9, 1.0)
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, 0.6, 0.6, 0, jitter_color(rng, (g, g, 1.0), 0.02), 170, 4)
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = blur(drift, 4) * 0.5 + ripple * 0.12 + lh * 0.3
    return col, normal_from_height(h, 3.5)


def mud(rng):
    """A swamp's wet mud: dark, with still puddles and rotting reed litter."""
    n = periodic_noise(rng, 70)
    col = lerp((0.07, 0.06, 0.04), (0.14, 0.11, 0.07), n)
    wet = np.clip((periodic_noise(rng, 45) - 0.6) * 5.0, 0, 1)
    col = col * (1 - wet[..., None] * 0.6) + np.array([0.04, 0.06, 0.07]) * wet[..., None] * 0.6
    algae = np.clip((periodic_noise(rng, 20) - 0.62) * 5.0, 0, 1) * (1 - wet)
    col = col * (1 - algae[..., None] * 0.7) + np.array([0.12, 0.16, 0.05]) * algae[..., None] * 0.7
    cv = Canvas()
    for _ in range(420):  # reed litter
        x, y = rng.random() * TILE, rng.random() * TILE
        a, ln = rng.random() * math.pi, rng.uniform(6, 14)
        cv.line((x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln * SQUASH),
                jitter_color(rng, (0.3, 0.26, 0.14), 0.2), 1, 150)
    lc, la, lh = cv.layers()
    col = over(col, lc, la * (1 - wet))
    h = blur(n, 2) * 0.3 - wet * 0.25 + lh * 0.4
    return col, normal_from_height(h, 4.0)


def red_earth(rng):
    """Savanna red earth: dusty, cracked, with dry yellow grass."""
    n = periodic_noise(rng, 90)
    n2 = periodic_noise(rng, 10)
    col = lerp((0.32, 0.15, 0.08), (0.46, 0.24, 0.12), n * 0.7 + n2 * 0.3)
    f1, f2, _ = voronoi(rng, 48, 1.0)
    crack = np.clip(1.0 - (f2 - f1) / 1.6, 0, 1) * (periodic_noise(rng, 40) > 0.5)
    col = col * (1 - crack[..., None] * 0.5)
    cv = Canvas()
    blades(rng, cv, 1600, [(0.62, 0.5, 0.24), (0.55, 0.44, 0.2), (0.7, 0.6, 0.3)], length=(4, 10), width=1)
    for _ in range(200):
        g = rng.uniform(0.35, 0.5)
        cv.ellipse(rng.random() * TILE, rng.random() * TILE, rng.uniform(1.5, 3), rng.uniform(1.2, 2.5),
                   rng.random() * 3, jitter_color(rng, (g, g * 0.75, g * 0.6)), 220, 7)
    lc, la, lh = cv.layers()
    col = over(col, lc, la)
    h = n2 * 0.2 - crack * 0.3 + lh * 0.5
    return col, normal_from_height(h, 5.0)


MAKERS = {
    "grass": lambda r: grass(r),
    "grass_light": lambda r: grass(r, light=True),
    "leaf_litter": leaf_litter,
    "forest_floor": forest_floor,
    "dirt": dirt,
    "gravel": gravel,
    "sand": sand,
    "moss_soil": moss_soil,
    "snow": snow,
    "mud": mud,
    "red_earth": red_earth,
}


def main():
    global DENSITY, N
    if "--density" in sys.argv:
        DENSITY = int(sys.argv[sys.argv.index("--density") + 1])
        N = TILE * DENSITY
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else None
    out_dir = sys.argv[-1]
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, maker) in enumerate(MAKERS.items()):
        if only and name not in only:
            continue
        rng = np.random.default_rng(1000 + i)
        col, nrm = maker(rng)
        if DENSITY > 1:
            # Lighting doesn't need the extra detail (and it'd double the
            # download): the normal map is box-filtered back to TILE square.
            nrm = nrm.reshape(TILE, DENSITY, TILE, DENSITY, 3).mean(axis=(1, 3)) * 2.0 - 1.0
            nrm = nrm / np.linalg.norm(nrm, axis=-1, keepdims=True) * 0.5 + 0.5
        Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(out_dir, f"{name}_albedo.png"), optimize=True)
        Image.fromarray((np.clip(nrm, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(out_dir, f"{name}_normal.png"), optimize=True)
        print("wrote", name)


if __name__ == "__main__":
    main()
