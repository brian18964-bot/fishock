"""A fish from a photo: the user's side-on picture of a species made into a
model and rendered like the rest (tools/render_fish.py's camera and light).

User request: the user finds a photo of each fish (side-on, whole, fins
spread, one fish, a plain background); it's made into a 3D fish in our
style:
  1. cut out: the background colour read off the picture's border, the
     fish is what differs from it (the biggest piece, holes filled, edges
     smoothed);
  2. turned head-right: the tail stalk (the narrowest part near an end)
     says which end is the tail;
  3. painted down: photo detail smoothed away, colours slightly flattened -
     like the rest of the art, not a photograph;
  4. made solid: a pillow of the silhouette, thickest in the middle of the
     body (by the distance to the edge), thin at the fins, both sides
     textured with the photo;
  5. rendered to assets/sprites/fish/<id>.png, replacing the modelled
     placeholder.
The same photo can dress other species of the same body (--as): their
own colours laid over its light and shade.

  python tools/fish_from_photo.py PHOTO ID [--as ID2 ID3 ...]
  python tools/fish_from_photo.py --batch DIR

--batch: every picture in DIR named after a species (its Chinese name,
its id, or the English name from the list the user was given - "Common
carp.jpg", "鯉魚.png"...) becomes that species; then each species with no
photo of its own is dressed from a photo of its body type, in its colours.
"""
import math
import os
import re
import sys

import bpy
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
import render_fish as rf  # noqa: E402

WORK = 512          # the cut-out's working width
GRID = 96           # mesh columns along the fish
THICK = 0.09        # half thickness at the fattest, share of the length


def cut_out(path):
    img = Image.open(path).convert("RGB")
    img.thumbnail((WORK * 2, WORK * 2))
    a = np.asarray(img).astype(np.float32) / 255.0
    h, w = a.shape[:2]
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, axis=0)
    spread = np.percentile(np.linalg.norm(border - bg, axis=1), 90)
    diff = np.linalg.norm(a - bg, axis=2)
    mask = diff > max(0.12, spread * 1.8)
    m = Image.fromarray((mask * 255).astype(np.uint8))
    # Specks off, gaps closed.
    m = m.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
    # The biggest piece: flood from its heaviest point, keep what's reached.
    mm = np.asarray(m) > 127
    ys, xs = np.nonzero(mm)
    if len(xs) == 0:
        raise SystemExit("no fish found in %s" % path)
    seed = (int(np.median(xs)), int(np.median(ys)))
    if not mm[seed[1], seed[0]]:
        k = np.argmin((xs - seed[0]) ** 2 + (ys - seed[1]) ** 2)
        seed = (int(xs[k]), int(ys[k]))
    tagged = m.convert("L")
    ImageDraw.floodfill(tagged, seed, 128)
    body = np.asarray(tagged) == 128
    # Holes filled: whatever the outside can't reach.
    outside = Image.fromarray(np.where(body, 255, 0).astype(np.uint8))
    padded = Image.new("L", (w + 2, h + 2), 0)
    padded.paste(outside, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 64)
    body = np.asarray(padded)[1:-1, 1:-1] != 64
    # Smooth edge.
    soft = Image.fromarray((body * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))
    body = np.asarray(soft) > 127
    ys, xs = np.nonzero(body)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgb = img.crop(box)
    alpha = Image.fromarray((body * 255).astype(np.uint8)).crop(box)
    return rgb, alpha


def head_right(rgb, alpha):
    """The tail stalk - the narrowest column not far from an end - marks
    the tail; turned so the head points right (+x)."""
    a = np.asarray(alpha) > 127
    heights = a.sum(axis=0).astype(np.float32)
    n = len(heights)
    lo, hi = int(n * 0.08), int(n * 0.4)
    left_min = heights[lo:hi].min() if hi > lo else 1e9
    right_min = heights[n - hi:n - lo].min() if hi > lo else 1e9
    if right_min < left_min:
        rgb = rgb.transpose(Image.FLIP_LEFT_RIGHT)
        alpha = alpha.transpose(Image.FLIP_LEFT_RIGHT)
    return rgb, alpha


def paint_down(rgb, alpha):
    """Photo detail smoothed, colours a touch flattened, the shadows lifted."""
    r = rgb.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
    a = np.asarray(r).astype(np.float32) / 255.0
    grey = a @ np.array([0.299, 0.587, 0.114], np.float32)
    a = grey[..., None] + (a - grey[..., None]) * 1.1
    a = 0.06 + a * 0.94
    # Quantized a little: painted, not photographed.
    a = np.round(a * 24.0) / 24.0
    out = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    out.putalpha(alpha)
    return out


def recolor(tex, colors):
    """Another species on the same body: its own colours over the photo's
    light and shade (back to belly by height in the picture)."""
    a = np.asarray(tex).astype(np.float32) / 255.0
    lum = a[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    rel = lum / max(np.median(lum[a[..., 3] > 0.5]), 1e-3)
    h = a.shape[0]
    t = np.linspace(0, 1, h)[:, None, None]
    back, belly = (np.array(rf.lin(c)) ** (1 / 2.2) for c in colors[:2])
    base = back * (1 - t) + belly * t
    a[..., :3] = np.clip(base * rel[..., None] * 0.95, 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8))


def distance(alpha):
    """Distance to the edge (px), by repeated erosion."""
    m = alpha.copy()
    total = np.zeros(np.asarray(alpha).shape, np.float32)
    for _ in range(200):
        arr = np.asarray(m) > 127
        if not arr.any():
            break
        total += arr
        m = m.filter(ImageFilter.MinFilter(3))
    return total


def pillow(tex, tex_path):
    """The silhouette made solid: a grid over it, raised on both sides by
    the square root of the distance to the edge."""
    alpha = tex.getchannel("A")
    w, h = alpha.size
    dist = distance(alpha)
    dmax = max(dist.max(), 1.0)
    cols = GRID
    rows = max(8, int(GRID * h / w))
    aspect = h / w
    verts, uvs, faces = [], [], []
    index = {}
    for side in (1, -1):
        for j in range(rows + 1):
            for i in range(cols + 1):
                u, v = i / cols, j / rows
                px = min(int(u * (w - 1)), w - 1)
                py = min(int(v * (h - 1)), h - 1)
                d = dist[py, px]
                index[(side, i, j)] = len(verts)
                x = u - 0.5
                z = (0.5 - v) * aspect
                y = side * THICK * math.sqrt(d / dmax) + side * 0.002
                verts.append((x, y, z))
                uvs.append((u, 1 - v))
    inside = np.asarray(alpha) > 127
    for side in (1, -1):
        for j in range(rows):
            for i in range(cols):
                cx = min(int((i + 0.5) / cols * (w - 1)), w - 1)
                cy = min(int((j + 0.5) / rows * (h - 1)), h - 1)
                if not inside[cy, cx]:
                    continue
                q = (index[(side, i, j)], index[(side, i + 1, j)], index[(side, i + 1, j + 1)], index[(side, i, j + 1)])
                faces.append(q if side < 0 else tuple(reversed(q)))
    me = bpy.data.meshes.new("fish")
    me.from_pydata(verts, [], faces)
    me.update()
    uv = me.uv_layers.new(name="uv")
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[me.loops[li].vertex_index]
        poly.use_smooth = True
    o = bpy.data.objects.new("fish", me)
    bpy.context.scene.collection.objects.link(o)
    mat = bpy.data.materials.new("photo")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = bpy.data.images.load(tex_path)
    nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(t.outputs['Alpha'], bsdf.inputs['Alpha'])
    bsdf.inputs['Roughness'].default_value = 0.45
    bsdf.inputs['Coat Weight'].default_value = 0.3
    o.data.materials.append(mat)
    return o


def render(tex, fid, tmp):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    tex_path = os.path.join(tmp, fid + "_tex.png")
    tex.save(tex_path)
    o = pillow(tex, tex_path)
    rf.stage([o])
    bpy.context.scene.render.filepath = os.path.join(rf.OUT, fid + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", fid, "from photo", flush=True)


# The English names the user was given to search by.
ENGLISH = {
    "common carp": "carp", "carp": "carp", "rainbow trout": "rainbow_trout", "largemouth bass": "bass",
    "channel catfish": "catfish", "catfish": "catfish", "european eel": "eel", "eel": "eel", "tilapia": "tilapia",
    "atlantic mackerel": "mackerel", "mackerel": "mackerel", "bluefin tuna": "bluefin", "tuna": "bluefin",
    "red sea bream": "sea_bream", "sea bream": "sea_bream", "grouper": "grouper", "flounder": "flounder",
    "cutlassfish": "cutlassfish", "pufferfish": "puffer", "puffer": "puffer", "swordfish": "swordfish",
    "sailfish": "sailfish", "ocean sunfish": "sunfish", "sunfish": "sunfish", "hammerhead shark": "hammerhead",
    "hammerhead": "hammerhead", "sturgeon": "sturgeon", "alligator gar": "alligator_gar", "northern pike": "pike",
    "pike": "pike", "angelfish": "angelfish", "silver arowana": "arowana", "arowana": "arowana",
    "coelacanth": "coelacanth", "arapaima": "arapaima", "koi": "golden_koi", "goldfish": "giant_goldfish",
    "sockeye salmon": "sockeye", "sockeye": "sockeye", "arctic char": "arctic_char", "brown trout": "brown_trout",
    "oscar": "oscar", "piranha": "piranha", "napoleon wrasse": "napoleon", "humphead wrasse": "napoleon",
    "mahi mahi": "mahi", "mahi-mahi": "mahi", "dorado": "mahi", "giant trevally": "trevally", "betta": "betta",
    "pleco": "pleco", "crucian carp": "crucian", "grass carp": "grass_carp", "bluegill": "bluegill",
    "loach": "loach", "sardine": "sardine", "cod": "cod", "herring": "herring", "sea bass": "sea_bass",
}


def species_for_file(fname, species):
    stem = os.path.splitext(os.path.basename(fname))[0]
    low = re.sub(r"[_\-]+", " ", stem.lower()).strip()
    low = re.sub(r"\s*\d+$", "", low)
    if low.replace(" ", "_") in species:
        return low.replace(" ", "_")
    if low in ENGLISH:
        return ENGLISH[low]
    for fid, sp in sorted(species.items(), key=lambda kv: -len(kv[1]["name"])):
        if sp["name"] in stem:
            return fid
    for eng in sorted(ENGLISH, key=len, reverse=True):
        if eng in low:
            return ENGLISH[eng]
    return None


def batch(directory, tmp):
    species = rf.read_species()
    photos = {}
    for f in sorted(os.listdir(directory)):
        if not f.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
            continue
        fid = species_for_file(f, species)
        if fid is None:
            print("no species for", f)
            continue
        photos.setdefault(fid, os.path.join(directory, f))
    textures = {}
    for fid, path in photos.items():
        rgb, alpha = cut_out(path)
        rgb, alpha = head_right(rgb, alpha)
        tex = paint_down(rgb, alpha)
        tex.thumbnail((WORK, WORK))
        textures[fid] = tex
        render(tex, fid, tmp)
    # Body-mates with no photo of their own: dressed from one that has.
    by_body = {}
    for fid in textures:
        by_body.setdefault(species[fid]["body"], fid)
    for fid, sp in species.items():
        if fid in textures or sp["body"] not in by_body:
            continue
        render(recolor(textures[by_body[sp["body"]]], sp["colors"]), fid, tmp)
    print("photos:", len(photos), "dressed from them:",
          sum(1 for f, sp in species.items() if f not in textures and sp["body"] in by_body))


def main():
    args = sys.argv[1:]
    tmp = os.path.join(rf.ROOT, "art_src", "fish_tex")
    os.makedirs(tmp, exist_ok=True)
    if args[0] == "--batch":
        batch(args[1], tmp)
        return
    photo, fid = args[0], args[1]
    also = args[args.index("--as") + 1:] if "--as" in args else []
    rgb, alpha = cut_out(photo)
    rgb, alpha = head_right(rgb, alpha)
    tex = paint_down(rgb, alpha)
    tex.thumbnail((WORK, WORK))
    render(tex, fid, tmp)
    species = rf.read_species()
    for other in also:
        render(recolor(tex, species[other]["colors"]), other, tmp)


if __name__ == "__main__":
    main()
