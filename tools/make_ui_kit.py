"""The UI kit's pictures (user request: the menus and HUD in the style of a
fantasy MMO - dark iron frames with worn gold trim, red lacquered buttons,
square item slots, a navy tooltip, parchment - darker than the reference).

Everything is drawn here from height maps: a shape's height gives its
normal, lit from the top left, so trim reads as embossed metal and the
insides as stone or leather. Pictures are twice the size they're shown at
(the game draws them at half size - UiKit.tex - so they stay sharp on a
phone's screen). Nine-slice pieces keep their borders in the outer
MARGIN pixels and tile seamlessly inside.

  python3 tools/make_ui_kit.py        (needs numpy, scipy and Pillow)

Writes assets/ui/*.png.
"""
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui"
RNG = np.random.default_rng(7)

LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

GOLD_DARK = np.array([0.23, 0.15, 0.05])
GOLD = np.array([0.62, 0.46, 0.17])
GOLD_HI = np.array([1.0, 0.86, 0.5])
IRON = np.array([0.13, 0.125, 0.13])
IRON_HI = np.array([0.42, 0.4, 0.4])


# ---------------------------------------------------------------- helpers

def tile_noise(h, w, sigma, seed=None):
    """Seamless noise in 0..1: random values blurred with wrap-around."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    n = ndimage.gaussian_filter(rng.random((h, w)), sigma, mode="wrap")
    n -= n.min()
    return n / max(n.max(), 1e-6)


def fbm(h, w, seed=0, octaves=((6, 0.5), (2.5, 0.3), (1.0, 0.2))):
    out = np.zeros((h, w))
    for i, (s, amp) in enumerate(octaves):
        out += tile_noise(h, w, s, seed + i) * amp
    return out / sum(a for _, a in octaves)


def grid(h, w):
    y, x = np.mgrid[0:h, 0:w].astype(float)
    return x + 0.5, y + 0.5


def rrect_sdf(x, y, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle (negative inside)."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r
    dx, dy = np.abs(x - cx) - hx, np.abs(y - cy) - hy
    outside = np.hypot(np.maximum(dx, 0), np.maximum(dy, 0))
    inside = np.minimum(np.maximum(dx, dy), 0)
    return outside + inside - r


def smooth(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def normals(height, strength=1.0, wrap=False):
    mode = "wrap" if wrap else "nearest"
    gx = ndimage.sobel(height, axis=1, mode=mode) * strength
    gy = ndimage.sobel(height, axis=0, mode=mode) * strength
    n = np.dstack([-gx, -gy, np.ones_like(height)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def lit(albedo, n, spec=0.35, shine=18.0, ambient=0.38, diffuse=0.85):
    """Lambert + Blinn-Phong under LIGHT, viewer straight on."""
    ndl = np.clip((n * LIGHT).sum(axis=2), 0, 1)
    half = LIGHT + np.array([0, 0, 1.0])
    half /= np.linalg.norm(half)
    ndh = np.clip((n * half).sum(axis=2), 0, 1)
    col = albedo * (ambient + diffuse * ndl)[..., None]
    col += (spec * ndh ** shine)[..., None]
    return col


def metal(height, tone, strength=3.0, spec=0.55, shine=24.0, wrap=False):
    """Gold (or iron) from a height map: colour follows the tone map
    (0 dark .. 1 bright) and the light."""
    n = normals(height, strength, wrap)
    t = np.clip(tone, 0, 1)[..., None]
    alb = np.where(t < 0.5, GOLD_DARK + (GOLD - GOLD_DARK) * (t / 0.5), GOLD + (GOLD_HI - GOLD) * ((t - 0.5) / 0.5))
    return lit(alb, n, spec=spec, shine=shine)


def to_img(rgb, alpha=None):
    rgb = np.clip(rgb, 0, 1)
    if alpha is None:
        alpha = np.ones(rgb.shape[:2])
    a = np.clip(alpha, 0, 1)
    arr = np.dstack([rgb, a[..., None]])
    return Image.fromarray((arr * 255 + 0.5).astype(np.uint8), "RGBA")


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png", optimize=True)
    print("wrote", name, img.size)


def band(d, inner, outer):
    """1 on the band between distances `inner`..`outer` (d negative inside),
    soft at its edges, and its profile (0 at the edges, 1 in the middle)."""
    on = smooth(outer + 0.8, outer - 0.8, d) * smooth(inner - 0.8, inner + 0.8, d)
    mid = (inner + outer) / 2
    half = max((outer - inner) / 2, 1e-3)
    prof = np.clip(1 - np.abs(d - mid) / half, 0, 1)
    return on, prof


# ---------------------------------------------------------------- pieces

def frame(size=128, margin=32, name="frame", inner_col=(0.075, 0.07, 0.075), alpha=0.97):
    """The window frame: black line, embossed gold trim, a dark iron rim,
    a stone-dark inside with an inner shadow; gold studs at the corners."""
    x, y = grid(size, size)
    d = rrect_sdf(x, y, 1, 1, size - 1, size - 1, 7)
    outline = smooth(0.8, -0.8, d)
    # Trim: a raised gold band 3..11 px in, with a groove.
    gold_on, gold_prof = band(d, -12, -3)
    groove = np.exp(-((d + 7.5) ** 2) / 1.2)
    # Iron rim just inside the gold.
    iron_on, iron_prof = band(d, -18, -12)
    # Inside: seamless stone noise.
    stone = fbm(size, size, seed=3)
    height = gold_on * (np.sqrt(gold_prof) * 3.0 - groove * 1.4) + iron_on * iron_prof * 1.2 + stone * 0.25
    # Corners: a raised diamond setting with a small red gem.
    gem_on = np.zeros_like(d)
    gem_h = np.zeros_like(d)
    for cx, cy in ((13, 13), (size - 13, 13), (13, size - 13), (size - 13, size - 13)):
        dia = np.abs(x - cx) + np.abs(y - cy)
        setting = smooth(12.5, 11.0, dia)
        height += setting * (12 - np.minimum(dia, 12)) * 0.35
        gold_on = np.maximum(gold_on, setting)
        gem = smooth(6.0, 4.8, dia)
        gem_on = np.maximum(gem_on, gem)
        gem_h += gem * (6 - np.minimum(dia, 6)) * 0.6
    wear = fbm(size, size, seed=11)
    gold_rgb = metal(height, 0.35 + gold_prof * 0.45 + (wear - 0.5) * 0.35, strength=2.2)
    gem_rgb = lit(np.array([0.55, 0.04, 0.03])[None, None, :] * np.ones((size, size, 1)), normals(gem_h, 3.0), spec=0.9, shine=40)
    iron_rgb = lit(IRON[None, None, :] + (wear[..., None] - 0.5) * 0.04, normals(height, 2.0), spec=0.18, shine=12)
    inside = np.array(inner_col)[None, None, :] * (0.85 + stone[..., None] * 0.3)
    # Inner shadow near the rim.
    shade = smooth(-40, -18, d)
    inside = inside * (1 - 0.55 * shade[..., None])
    rgb = inside
    rgb = rgb * (1 - iron_on[..., None]) + iron_rgb * iron_on[..., None]
    rgb = rgb * (1 - gold_on[..., None]) + gold_rgb * gold_on[..., None]
    rgb = rgb * (1 - gem_on[..., None]) + gem_rgb * gem_on[..., None]
    edge_black = smooth(-3.2, -1.8, d) * outline
    rgb = rgb * (1 - edge_black[..., None])
    a = outline * np.where(d < -18, alpha, 1.0)
    save(to_img(rgb, a), name)


def plate(w=192, h=48, name="plate"):
    """A title plate: a dark bronze bar with a gold edge and bevel."""
    x, y = grid(h, w)
    d = rrect_sdf(x, y, 1, 1, w - 1, h - 1, 6)
    outline = smooth(0.8, -0.8, d)
    gold_on, prof = band(d, -6, -1.5)
    grain = fbm(h, w, seed=21, octaves=((3, 0.6), (1, 0.4)))
    body = np.array([0.2, 0.13, 0.07])[None, None, :] * (0.8 + grain[..., None] * 0.35)
    # A soft vertical gradient: lighter at the top.
    body *= (1.2 - 0.5 * (y / h))[..., None]
    height = gold_on * np.sqrt(prof) * 2.5
    gold_rgb = metal(height, 0.45 + prof * 0.4, strength=2.0)
    rgb = body * (1 - gold_on[..., None]) + gold_rgb * gold_on[..., None]
    rgb *= (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    save(to_img(rgb, outline), name)


def button(kind, state, w=128, h=56, name=None):
    """A button: lacquer (red) or steel (gray) under a gold rim."""
    x, y = grid(h, w)
    d = rrect_sdf(x, y, 1, 1, w - 1, h - 1, 7)
    outline = smooth(0.8, -0.8, d)
    gold_on, prof = band(d, -7.5, -1.8)
    t = y / h
    if kind == "red":
        top, bottom = np.array([0.78, 0.13, 0.08]), np.array([0.28, 0.02, 0.01])
    else:
        top, bottom = np.array([0.36, 0.35, 0.37]), np.array([0.1, 0.1, 0.11])
    if state == "pressed":
        top, bottom = top * 0.7, bottom * 0.8
    elif state == "hover":
        top, bottom = np.minimum(top * 1.2, 1), np.minimum(bottom * 1.25, 1)
    elif state == "disabled":
        g = (top + bottom) / 2
        top = bottom = np.array([g.mean() * 0.8] * 3) * np.array([1.05, 1.0, 0.95])
    body = bottom[None, None, :] + (top - bottom)[None, None, :] * (1 - t)[..., None] ** 1.3
    grain = fbm(h, w, seed=31, octaves=((2.5, 0.6), (1, 0.4)))
    body *= (0.92 + grain[..., None] * 0.16)
    # A glossy band near the top, gone when pressed.
    if state != "pressed":
        gloss = np.exp(-((t - 0.2) ** 2) / 0.006) * smooth(-4, -9, d) * 0.22
        body += gloss[..., None]
    height = gold_on * np.sqrt(prof) * 2.5
    tone = 0.35 + prof * 0.4 if state != "disabled" else 0.1 + prof * 0.25
    gold_rgb = metal(height, tone, strength=2.0)
    if state == "disabled":
        gold_rgb = gold_rgb.mean(axis=2, keepdims=True) * np.array([1.0, 0.95, 0.85])
    rgb = body * (1 - gold_on[..., None]) + gold_rgb * gold_on[..., None]
    # Inner shadow (pressed: from the top, as if sunk).
    inner = smooth(-14, -6.5, d)
    if state == "pressed":
        inner = np.maximum(inner, smooth(0.35, 0.0, t) * smooth(-6.5, -9, d))
    rgb *= (1 - inner * 0.35)[..., None]
    rgb *= (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    save(to_img(rgb, outline), name or f"btn_{kind}_{state}")


def slot(size=96, name="slot"):
    """An item slot: a sunken square with an iron bevel."""
    x, y = grid(size, size)
    d = rrect_sdf(x, y, 1, 1, size - 1, size - 1, 5)
    outline = smooth(0.8, -0.8, d)
    rim_on, prof = band(d, -8, -1.5)
    grain = fbm(size, size, seed=41)
    height = rim_on * np.sqrt(prof) * 1.8 + grain * 0.15
    iron = lit(IRON_HI * 0.55 + (grain[..., None] - 0.5) * 0.05, normals(height, 2.2), spec=0.25, shine=14)
    inside = np.array([0.045, 0.045, 0.055])[None, None, :] * (0.8 + grain[..., None] * 0.4)
    shade = smooth(-26, -8, d)
    inside *= (1 - 0.7 * shade)[..., None]
    rgb = inside * (1 - rim_on[..., None]) + iron * rim_on[..., None]
    rgb *= (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    save(to_img(rgb, outline * np.where(d < -8, 0.92, 1.0)), name)


def slot_ring(size=96, name="slot_ring"):
    """White ring with a glow, tinted by rarity at runtime."""
    x, y = grid(size, size)
    d = rrect_sdf(x, y, 5, 5, size - 5, size - 5, 5)
    ring = np.exp(-((d + 2.0) ** 2) / 2.0)
    glow = np.exp(-np.maximum(d + 2.0, 0) / 2.5) * 0.45 * smooth(-1, 4, d)
    inner_glow = np.exp(-np.maximum(-(d + 2.0), 0) / 6.0) * 0.35 * smooth(0, -3, d)
    a = np.clip(ring + glow + inner_glow, 0, 1)
    save(to_img(np.ones((size, size, 3)), a), name)


def tooltip(size=64, name="tooltip"):
    x, y = grid(size, size)
    d = rrect_sdf(x, y, 1, 1, size - 1, size - 1, 5)
    outline = smooth(0.8, -0.8, d)
    border, prof = band(d, -3.5, -1)
    rgb = np.array([0.02, 0.035, 0.09])[None, None, :] * np.ones((size, size, 1))
    silver = np.array([0.62, 0.64, 0.7]) * (0.75 + 0.35 * prof[..., None])
    rgb = rgb * (1 - border[..., None]) + silver * border[..., None]
    rgb *= (1 - smooth(-1.6, -0.6, d) * 0.9)[..., None]
    a = outline * np.where(d < -3.5, 0.93, 1.0)
    save(to_img(rgb, a), name)


def parchment(size=256, margin=48, name="parchment"):
    x, y = grid(size, size)
    d = rrect_sdf(x, y, 2, 2, size - 2, size - 2, 10)
    outline = smooth(1.0, -1.0, d)
    paper = fbm(size, size, seed=51, octaves=((12, 0.45), (4, 0.3), (1.2, 0.25)))
    stains = tile_noise(size, size, 18, seed=57)
    base = np.array([0.8, 0.69, 0.5])
    rgb = base[None, None, :] * (0.86 + paper[..., None] * 0.2)
    rgb *= (1 - np.clip(stains - 0.55, 0, 1)[..., None] * 0.5)
    # Burnt, darker edges.
    burn = smooth(-margin + 8, -2, d) * (0.75 + paper * 0.5)
    rgb *= (1 - np.clip(burn, 0, 1) * 0.55)[..., None]
    rgb = rgb * np.array([1.0, 0.97, 0.9])
    a = outline * (1 - smooth(-2.5, -0.5, d) * (paper < 0.35) * 0.6)
    save(to_img(rgb, a), name)


def bar_frame(w=128, h=32, name="bar_frame"):
    x, y = grid(h, w)
    d = rrect_sdf(x, y, 1, 1, w - 1, h - 1, 5)
    outline = smooth(0.8, -0.8, d)
    gold_on, prof = band(d, -5.5, -1.5)
    height = gold_on * np.sqrt(prof) * 2.5
    gold_rgb = metal(height, 0.35 + prof * 0.4, strength=2.0)
    trough = np.array([0.02, 0.02, 0.025])[None, None, :] * np.ones((h, w, 1))
    trough *= (0.6 + 0.4 * smooth(-12, -6, d))[..., None]
    rgb = trough * (1 - gold_on[..., None]) + gold_rgb * gold_on[..., None]
    rgb *= (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    a = outline * np.where(d < -5.5, 0.9, 1.0)
    save(to_img(rgb, a), name)


def bar_fill(w=64, h=24, name="bar_fill"):
    """A grey fill, lit like a glass tube; tinted at runtime."""
    x, y = grid(h, w)
    t = y / h
    v = 0.55 + 0.45 * np.exp(-((t - 0.28) ** 2) / 0.02) - 0.35 * t
    grain = fbm(h, w, seed=61, octaves=((2, 0.6), (0.8, 0.4)))
    v = v * (0.94 + grain * 0.12)
    save(to_img(np.dstack([v, v, v])), name)


def medallion(size=160, name="medallion"):
    """A round gold frame for portraits: see-through in the middle."""
    x, y = grid(size, size)
    c = size / 2
    r = np.hypot(x - c, y - c)
    R = c - 2
    d = r - R
    outline = smooth(0.8, -0.8, d)
    gold_on, prof = band(d, -16, -2.5)
    groove = np.exp(-((d + 9) ** 2) / 1.5)
    iron_on, iprof = band(d, -21, -16)
    ang = np.arctan2(y - c, x - c)
    beads = (np.cos(ang * 24) * 0.5 + 0.5) * np.exp(-((d + 5.5) ** 2) / 3.0)
    height = gold_on * (np.sqrt(prof) * 3.0 - groove * 1.4 + beads * 0.9) + iron_on * iprof
    wear = fbm(size, size, seed=71)
    gold_rgb = metal(height, 0.35 + prof * 0.45 + (wear - 0.5) * 0.3, strength=2.2)
    iron_rgb = lit(IRON[None, None, :] * np.ones((size, size, 1)), normals(height, 2.0), spec=0.15)
    rgb = iron_rgb * iron_on[..., None] + gold_rgb * gold_on[..., None]
    rgb *= (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    a = np.clip(gold_on + iron_on, 0, 1) * outline
    # An inner shadow ring over the portrait.
    shadow = np.exp(-np.maximum(-(d + 21), 0) / 5.0) * smooth(-19, -23, d) * 0.7
    a = np.maximum(a, shadow)
    rgb = rgb * (a > shadow)[..., None] + np.zeros_like(rgb) * (a <= shadow)[..., None]
    save(to_img(rgb, a), name)


def close_button(size=64, name="close"):
    x, y = grid(size, size)
    c = size / 2
    r = np.hypot(x - c, y - c)
    d = r - (c - 2)
    outline = smooth(0.8, -0.8, d)
    gold_on, prof = band(d, -6, -1.5)
    t = y / size
    body = np.array([0.3, 0.02, 0.01]) + (np.array([0.75, 0.12, 0.07]) - np.array([0.3, 0.02, 0.01])) * (1 - t)[..., None]
    height = gold_on * np.sqrt(prof) * 2.5
    gold_rgb = metal(height, 0.4 + prof * 0.4, strength=2.0)
    rgb = body * (1 - gold_on[..., None]) + gold_rgb * gold_on[..., None]
    # The cross.
    u, v = (x - c) / c, (y - c) / c
    arm = np.minimum(np.abs(u - v), np.abs(u + v)) / np.sqrt(2)
    cross = smooth(0.1, 0.06, arm) * smooth(0.46, 0.4, np.maximum(np.abs(u), np.abs(v)))
    rgb = rgb * (1 - cross[..., None]) + np.array([1.0, 0.86, 0.55]) * cross[..., None]
    rgb *= (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    save(to_img(rgb, outline), name)


def action_frame(size=144, name="action_frame"):
    """The square frame of an action button: a gold bevel, see-through in
    the middle, where the button's picture shows."""
    x, y = grid(size, size)
    d = rrect_sdf(x, y, 2, 2, size - 2, size - 2, 9)
    outline = smooth(0.8, -0.8, d)
    gold_on, prof = band(d, -11, -2.5)
    groove = np.exp(-((d + 6.5) ** 2) / 1.2)
    height = gold_on * (np.sqrt(prof) * 3.0 - groove * 1.2)
    for cx, cy in ((10, 10), (size - 10, 10), (10, size - 10), (size - 10, size - 10)):
        rr = np.hypot(x - cx, y - cy)
        height += np.sqrt(np.clip(1 - rr / 5.5, 0, 1)) * 2.5
    wear = fbm(size, size, seed=81)
    gold_rgb = metal(height, 0.35 + prof * 0.45 + (wear - 0.5) * 0.3, strength=2.2)
    rgb = gold_rgb * (1 - smooth(-2.2, -1.2, d) * 0.9)[..., None]
    a = gold_on * outline
    # A dark inner rim so the picture sits in a recess.
    rim = smooth(-11, -9.5, d) * smooth(-17, -11, d) * 0.85
    a = np.maximum(a, rim)
    rgb = np.where((rim > gold_on)[..., None], 0.0, rgb)
    save(to_img(rgb, a), name)


def action_glow(size=176, name="action_glow"):
    """The proc glow round an action button (tinted yellow at runtime)."""
    x, y = grid(size, size)
    m = 16
    d = rrect_sdf(x, y, m, m, size - m, size - m, 12)
    a = np.exp(-np.abs(d) / 5.0) * 0.9
    a *= 0.7 + 0.3 * (np.sin(np.arctan2(y - size / 2, x - size / 2) * 10) * 0.5 + 0.5)
    save(to_img(np.ones((size, size, 3)), np.clip(a, 0, 1)), name)


def coin(size=48, name="coin"):
    x, y = grid(size, size)
    c = size / 2
    r = np.hypot(x - c, y - c)
    d = r - (c - 2)
    outline = smooth(0.8, -0.8, d)
    rim, prof = band(d, -5, 0)
    inner = np.clip(1 - r / (c - 8), 0, 1)
    height = rim * np.sqrt(prof) * 2.0 + np.sqrt(inner) * 1.2
    ang = np.arctan2(y - c, x - c)
    height += smooth(-12, -10, d) * smooth(-7, -9, d) * (np.cos(ang * 16) * 0.3)
    rgb = metal(height, 0.5 + inner * 0.35, strength=2.5, spec=0.8)
    rgb *= (1 - smooth(-1.8, -0.8, d) * 0.9)[..., None]
    save(to_img(rgb, outline), name)


def divider(w=256, h=24, name="divider"):
    x, y = grid(h, w)
    c = w / 2
    line = np.exp(-((y - h / 2) ** 2) / 1.2) * smooth(w / 2, w / 2 - 40, np.abs(x - c))
    dia = np.abs(x - c) + np.abs(y - h / 2) * 1.4
    gem = smooth(9, 7, dia)
    height = gem * (9 - dia) * 0.4 + line
    rgb = metal(height, 0.45 + gem * 0.4 + line * 0.2, strength=2.5)
    a = np.clip(line * 0.9 + gem, 0, 1)
    save(to_img(rgb, a), name)


def page_bg(size=256, name="page_bg"):
    """A tileable dark stone for page backs."""
    stone = fbm(size, size, seed=91, octaves=((14, 0.4), (5, 0.35), (1.5, 0.25)))
    cracks = tile_noise(size, size, 3, seed=95)
    height = stone + np.clip(0.52 - np.abs(cracks - 0.5), 0, 1) * 0.3
    n = normals(height, 3.0, wrap=True)
    alb = np.array([0.07, 0.068, 0.075])[None, None, :] * (0.8 + stone[..., None] * 0.5)
    rgb = lit(alb, n, spec=0.05, shine=8, ambient=0.6, diffuse=0.6)
    save(to_img(rgb), name)


def main():
    frame()
    frame(name="frame_dark", inner_col=(0.035, 0.035, 0.045), alpha=0.9)
    plate()
    for kind in ("red", "gray"):
        for state in ("normal", "hover", "pressed", "disabled"):
            button(kind, state)
    slot()
    slot_ring()
    tooltip()
    parchment()
    bar_frame()
    bar_fill()
    medallion()
    close_button()
    action_frame()
    action_glow()
    coin()
    divider()
    page_bg()


if __name__ == "__main__":
    main()
