"""Stand-in icons for the new fish items, until the user's own art comes
(user: "這三個道具圖我晚點補給你"). Drawn flat and plain on purpose; replace
the files (same names) and nothing else changes.

  bpyenv/bin/python tools/make_placeholder_icons.py     (repo root)

assets/sprites/items/<id>.png     the long/loose picture (Items.icon)
assets/sprites/icons/<id>.png     the square slot picture (Items.square_icon)
"""
import os
import random

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def bubbles(d, w, h, n, seed):
    rnd = random.Random(seed)
    for _ in range(n):
        r = rnd.randint(3, max(4, h // 12))
        x, y = rnd.randint(r + 4, w - r - 4), rnd.randint(r + 4, h - r - 4)
        d.ellipse([x - r, y - r, x + r, y + r], outline=(210, 240, 255, 230), width=2)


def oxy_box(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = max(3, h // 10)
    d.rounded_rectangle([pad, pad, w - pad, h - pad], radius=max(4, h // 6), fill=(60, 140, 170, 200),
                        outline=(200, 235, 245, 255), width=max(2, h // 20))
    d.rounded_rectangle([pad, pad, w - pad, pad + h // 4], radius=max(3, h // 8), fill=(90, 70, 50, 255))
    cols = 6 if w > h * 3 else 3
    for i in range(1, cols):
        x = pad + (w - 2 * pad) * i // cols
        d.line([x, pad + h // 4, x, h - pad], fill=(200, 235, 245, 140), width=2)
    bubbles(d, w, h, 9 if w > h * 3 else 6, 1)
    return img


def algae(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(w // 5, w, w // 5)):
        top = h // 6 + (i % 2) * h // 8
        pts = [(x, h - h // 8)]
        for k in range(1, 6):
            pts.append((x + (12 if k % 2 else -12) * (w / 128), h - h // 8 - (h - top - h // 8) * k // 5))
        d.line(pts, fill=(70, 200, 120, 255), width=max(4, w // 16), joint="curve")
    bubbles(d, w, h, 4, 2)
    return img


def frozen_soil(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(w * 0.15, h * 0.75), (w * 0.25, h * 0.35), (w * 0.55, h * 0.2), (w * 0.85, h * 0.4), (w * 0.8, h * 0.8),
           (w * 0.45, h * 0.88)]
    d.polygon(pts, fill=(120, 140, 160, 255), outline=(225, 240, 250, 255))
    d.line([(w * 0.3, h * 0.45), (w * 0.5, h * 0.6), (w * 0.72, h * 0.5)], fill=(225, 240, 250, 255), width=3)
    d.line([(w * 0.5, h * 0.25), (w * 0.45, h * 0.6)], fill=(225, 240, 250, 255), width=2)
    return img


if __name__ == "__main__":
    save(oxy_box(384, 64), "assets", "sprites", "items", "oxy_box.png")
    save(oxy_box(256, 256), "assets", "sprites", "icons", "oxy_box.png")
    save(algae(128, 128), "assets", "sprites", "items", "oxy_algae.png")
    save(algae(256, 256), "assets", "sprites", "icons", "oxy_algae.png")
    save(frozen_soil(128, 128), "assets", "sprites", "items", "frozen_soil.png")
    save(frozen_soil(256, 256), "assets", "sprites", "icons", "frozen_soil.png")
    print("placeholders written")
