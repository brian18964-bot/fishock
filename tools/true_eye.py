"""The 'true eye' a used eye item opens over the character's head (user
request: like the user's reference - a cartoon eye, almond shaped, a thick
dark rim with lashes all round, a big iris with its highlights - but softer,
the colours not so full; each eye item's own iris and pupil). Drawn here at
4x and scaled down; Godot puts it together (scripts/true_eye.gd):

  assets/sprites/fx/true_eye_lids.png    the rim and lashes, FRAMES across:
                                         shut .. wide open
  assets/sprites/fx/true_eye_white.png   the white inside, the same frames
                                         (the iris is clipped to it)
  assets/sprites/fx/true_eye_iris_<id>.png   the iris and pupil, one per
                                         eye item (eyeball, eye_altar,
                                         eye_ghost)

python3 tools/true_eye.py [out_dir]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 192, 128           # a frame
SS = 4                    # supersampling
FRAMES = 6
OPEN = [0.0, 0.2, 0.45, 0.7, 0.9, 1.0]
HALF_W = 0.40             # the eye's half width, of W
UP = 0.30                 # the upper lid's height, of H (wide open)
DOWN = 0.24               # the lower lid's depth
RIM = (34, 30, 34, 255)   # soft black, not ink
WHITE = (236, 233, 226, 255)
SHADE = (196, 192, 188, 255)
# Muted: how far each iris colour is taken toward its grey.
MUTE = 0.3

IRISES = {
    # 渡石之眼: a brown eye, round pupil.
    "eyeball": {"outer": (92, 52, 26), "inner": (150, 96, 46), "ring": (60, 34, 18), "pupil": "round", "rays": None},
    # 祭壇之眼: gold, rayed, a red-rimmed round pupil.
    "eye_altar": {"outer": (196, 120, 34), "inner": (236, 184, 74), "ring": (150, 70, 24), "pupil": "round",
                  "rays": (250, 222, 140), "pupil_rim": (176, 60, 40)},
    # 見鬼之眼: violet and teal, a slit.
    "eye_ghost": {"outer": (70, 54, 112), "inner": (96, 170, 186), "ring": (44, 34, 78), "pupil": "slit", "rays": None},
}


def mute(c, k=MUTE):
    g = sum(c[:3]) / 3.0
    return tuple(int(round(v + (g - v) * k)) for v in c[:3]) + tuple(c[3:])


def lid_points(o, n=48):
    """The upper and lower lid curves at openness `o` (0 shut .. 1), as
    supersampled points, corner to corner."""
    cx, cy = W * SS / 2.0, H * SS / 2.0 + 4 * SS
    hw = HALF_W * W * SS
    up, down = UP * H * SS * o, DOWN * H * SS * o
    # Shut, the lid's a gentle downward curve.
    sag = 0.07 * H * SS * (1.0 - o)
    upper, lower = [], []
    for i in range(n + 1):
        t = -1.0 + 2.0 * i / n
        bulge = (1.0 - t * t) ** 0.85
        upper.append((cx + t * hw, cy - up * bulge + sag * bulge))
        lower.append((cx + t * hw, cy + down * bulge + sag * bulge))
    return upper, lower


def normal_out(pts, i, sign):
    a = pts[max(i - 1, 0)]
    b = pts[min(i + 1, len(pts) - 1)]
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    return (dy / n * sign, -dx / n * sign)


def lash(d, at, direction, length, width, color):
    """A rounded lash: a tapered capsule from `at` along `direction`."""
    x, y = at
    ux, uy = direction
    tip = (x + ux * length, y + uy * length)
    steps = 10
    for k in range(steps + 1):
        f = k / steps
        r = width * (1.0 - 0.35 * f) / 2.0
        px, py = x + (tip[0] - x) * f, y + (tip[1] - y) * f
        d.ellipse((px - r, py - r, px + r, py + r), fill=color)


def lids_frame(o):
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    upper, lower = lid_points(o)
    rim = 0.055 * H * SS
    # Lashes, under the rim: round the top (and over the corners), round
    # the bottom - the reference has them all the way round.
    lash_len, lash_w = 0.25 * H * SS, 0.085 * H * SS
    tops = [0.12, 0.28, 0.5, 0.72, 0.88]
    bottoms = [0.2, 0.38, 0.62, 0.8]
    for f in tops:
        i = int(f * (len(upper) - 1))
        nx, ny = normal_out(upper, i, 1.0)
        # (spread out a little, as lashes fan)
        fan = (f - 0.5) * 0.9
        dx, dy = nx * math.cos(fan) - ny * math.sin(fan), nx * math.sin(fan) + ny * math.cos(fan)
        if o < 0.05:
            dx, dy = -dx * 0.6 + (f - 0.5) * 0.4, -dy  # shut: they hang down
        lash(d, upper[i], (dx, dy), lash_len, lash_w, RIM)
    if o >= 0.05:
        for f in bottoms:
            i = int(f * (len(lower) - 1))
            nx, ny = normal_out(lower, i, -1.0)
            fan = (f - 0.5) * 0.8
            dx, dy = nx * math.cos(-fan) - ny * math.sin(-fan), nx * math.sin(-fan) + ny * math.cos(-fan)
            lash(d, lower[i], (dx, dy), lash_len * 0.85, lash_w * 0.9, RIM)
        for corner, sx in ((upper[0], -1.0), (upper[-1], 1.0)):
            lash(d, corner, (sx * 0.94, -0.34), lash_len * 0.5, lash_w * 0.9, RIM)
    # The rim: thick along the top, thinner along the bottom.
    d.line(upper, fill=RIM, width=int(rim * 1.25), joint="curve")
    d.line(lower, fill=RIM, width=int(rim * (0.8 if o > 0.05 else 1.1)), joint="curve")
    for p in (upper[0], upper[-1]):
        r = rim * 0.55
        d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=RIM)
    return img.resize((W, H), Image.LANCZOS)


def white_frame(o):
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    if o < 0.05:
        return img.resize((W, H), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    upper, lower = lid_points(o)
    d.polygon(upper + lower[::-1], fill=WHITE)
    # The lid's shadow along the top of the white (the reference's grey band).
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    band = [(x, y + 0.11 * H * SS * o) for x, y in upper]
    sd.polygon(upper + band[::-1], fill=SHADE)
    shade = shade.filter(ImageFilter.GaussianBlur(3 * SS))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(upper + lower[::-1], fill=255)
    img.paste(shade, (0, 0), Image.composite(shade.split()[3], Image.new("L", img.size, 0), mask))
    return img.resize((W, H), Image.LANCZOS)


def iris(spec):
    """The iris and pupil, centred in a frame-sized image (moved about in
    Godot to look the way of the place)."""
    img = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W * SS / 2.0, H * SS / 2.0 + 4 * SS
    r = 0.25 * H * SS
    outer, inner, ring = mute(spec["outer"]), mute(spec["inner"]), mute(spec["ring"])
    # A soft radial fill, light at the middle.
    steps = 40
    for k in range(steps):
        f = 1.0 - k / steps
        c = tuple(int(outer[j] + (inner[j] - outer[j]) * (1.0 - f) ** 1.4) for j in range(3))
        rr = r * f
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=c + (255,))
    if spec["rays"] is not None:
        rays = mute(spec["rays"], MUTE + 0.1)
        for k in range(16):
            a = k * math.tau / 16 + 0.1
            p0 = (cx + math.cos(a) * r * 0.42, cy + math.sin(a) * r * 0.42)
            p1 = (cx + math.cos(a) * r * 0.86, cy + math.sin(a) * r * 0.86)
            d.line([p0, p1], fill=rays + (200,), width=int(0.06 * r))
    else:
        # Fibres: faint streaks out from the pupil.
        for k in range(28):
            a = k * math.tau / 28
            p0 = (cx + math.cos(a) * r * 0.4, cy + math.sin(a) * r * 0.4)
            p1 = (cx + math.cos(a) * r * 0.92, cy + math.sin(a) * r * 0.92)
            d.line([p0, p1], fill=ring + (90,), width=int(0.035 * r))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=ring + (255,), width=int(0.09 * r))
    pupil = (20, 18, 22, 255)
    if spec["pupil"] == "slit":
        pw, ph = r * 0.16, r * 0.78
        d.ellipse((cx - pw, cy - ph, cx + pw, cy + ph), fill=pupil)
    else:
        pr = r * 0.4
        if "pupil_rim" in spec:
            rim = mute(spec["pupil_rim"])
            d.ellipse((cx - pr * 1.22, cy - pr * 1.22, cx + pr * 1.22, cy + pr * 1.22), fill=rim + (255,))
        d.ellipse((cx - pr, cy - pr, cx + pr, cy + pr), fill=pupil)
    # The highlights: a big one up and to the right, a small one low left.
    hi = (246, 250, 248, 235)
    hr = r * 0.3
    hx, hy = cx + r * 0.38, cy - r * 0.36
    d.ellipse((hx - hr, hy - hr, hx + hr, hy + hr), fill=hi)
    sr = r * 0.12
    sx, sy = cx - r * 0.3, cy + r * 0.48
    d.ellipse((sx - sr, sy - sr, sx + sr, sy + sr), fill=hi)
    return img.resize((W, H), Image.LANCZOS)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/sprites/fx"
    os.makedirs(out, exist_ok=True)
    lids = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    white = Image.new("RGBA", (W * FRAMES, H), (0, 0, 0, 0))
    for i, o in enumerate(OPEN):
        lids.paste(lids_frame(o), (i * W, 0))
        white.paste(white_frame(o), (i * W, 0))
    lids.save(os.path.join(out, "true_eye_lids.png"))
    white.save(os.path.join(out, "true_eye_white.png"))
    for key, spec in IRISES.items():
        iris(spec).save(os.path.join(out, "true_eye_iris_%s.png" % key))
    print("wrote", out)


if __name__ == "__main__":
    main()
