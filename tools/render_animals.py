"""Every animal and critter sheet, in one go (the Quaternius animal packs,
CC0, art_src/animal and art_src/critter).

User feedback: the animals walked stiffly. They were drawn in 4 facings,
snapping between them as they turned, and with few frames a clip - a
dinosaur's stride or a cow's grazing at 2-4 pictures a second. Now:

  - 8 facings: down, down_left, left, up_left, up rendered, the right-hand
    three drawn as mirror images (flip_h - Godot mirrors the normal map's X
    along with it, so they're lit right);
  - more frames: FRAMES (ambient) / CRITTER_FRAMES a clip, the clip's rate
    printed per species (frames over the clip's 24fps loop length);
  - normal maps at half size (lighting doesn't need the detail), which pays
    for the extra frames; the albedo is imported lossy (the download).

The camera is fitted per animal to every cell (x-symmetric, origin mid
cell). Cells run clip by clip, facing by facing, frame by frame, `cols` to
a row (as many as fit in MAX_SIDE px).

  python tools/render_animals.py OUT_DIR [name ...]

writes OUT_DIR/<name>_55deg_{albedo,normal}.png and OUT_DIR/animals.json
(per species: cell, cols, frames, offset, and fps per clip).
"""
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import render_sprite as rs  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "art_src")
DENSITY = 27.108
PAD = 0.06
MAX_SIDE = 4096
FRAMES = 16
CRITTER_FRAMES = 12
DIRS = ["down", "down_left", "left", "up_left", "up"]

# name: (file, scale, clips, extra)
ANIMALS = {
    "rat": ("critter/rat.glb", 0.35, ["Rat_Run", "Rat_Idle"], {}),
    "frog": ("critter/frog.glb", 0.34, ["Frog_Jump", "Frog_Idle"], {}),
    "snake": ("critter/snake.glb", 0.44, ["Snake_Walk", "Snake_Idle"], {}),
    "spider": ("critter/spider.glb", 0.28, ["Spider_Walk", "Spider_Idle"], {}),
    "wasp": ("critter/wasp.glb", 0.26, ["Wasp_Flying"], {"facing": -90.0}),
    # User request: the real black spider (tools/prep_black_spider.py), in
    # 8 colourings - a picture sheet each (<name>_<n>_55deg_albedo.png,
    # n = 1..8) over the one normal sheet.
    "black_spider": ("critter/black_spider.glb", 0.28, ["Spider_Walk", "Spider_Idle"],
                     {"skins": "critter/black_spider_skins"}),
    "cow": ("animal/cow.glb", 0.40, ["Walk", "Eating"], {}),
    "bull": ("animal/bull.glb", 0.40, ["Walk", "Eating"], {}),
    "donkey": ("animal/donkey.glb", 0.45, ["Walk", "Eating"], {}),
    "alpaca": ("animal/alpaca.glb", 0.42, ["Walk", "Eating"], {}),
    "deer": ("animal/deer.glb", 0.48, ["Walk", "Eating", "Gallop"], {}),
    "horse": ("animal/horse.glb", 0.54, ["Walk", "Eating"], {}),
    "white_horse": ("animal/white_horse.glb", 0.54, ["Walk", "Eating"], {}),
    "stag": ("animal/stag.glb", 0.52, ["Walk", "Idle", "Gallop"], {}),
    "fox": ("animal/fox.glb", 0.29, ["Walk", "Idle", "Gallop"], {}),
    "husky": ("animal/husky.glb", 0.42, ["Walk", "Idle"], {}),
    "shiba": ("animal/shiba.glb", 0.32, ["Walk", "Idle"], {}),
    "wolf": ("animal/wolf.glb", 0.42, ["Walk", "Idle", "Gallop"], {}),
    "stegosaurus": ("animal/stegosaurus.glb", 0.25, ["Stegosaurus_Walk", "Stegosaurus_Idle"], {}),
    "apatosaurus": ("animal/apatosaurus.glb", 0.195, ["Apatosaurus_Walk", "Apatosaurus_Idle"], {}),
    "parasaurolophus": ("animal/parasaurolophus.glb", 0.32, ["Parasaurolophus_Walk", "Parasaurolophus_Idle"], {}),
    "trex": ("animal/trex.glb", 0.26, ["TRex_Walk", "TRex_Idle"], {}),
    "triceratops": ("animal/triceratops.glb", 0.26, ["Triceratops_Walk", "Triceratops_Idle"], {}),
    "velociraptor": ("animal/velociraptor.glb", 0.24, ["Velociraptor_Walk", "Velociraptor_Idle"], {}),
}


def half_normal(path):
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = 'Non-Color'
    w, h = im.size
    img = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(img)
    img = img.reshape(h, w, 4)
    bpy.data.images.remove(im)
    img = img.reshape(h // 2, 2, w // 2, 2, 4).mean(axis=(1, 3))
    n = img[..., :3] * 2.0 - 1.0
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    img[..., :3] = n * 0.5 + 0.5
    out = bpy.data.images.new("half", w // 2, h // 2, alpha=True)
    out.colorspace_settings.name = 'Non-Color'
    out.pixels.foreach_set(np.clip(img, 0.0, 1.0).ravel())
    out.filepath_raw = path
    out.file_format = 'PNG'
    out.save()
    bpy.data.images.remove(out)


def render(name, out):
    path, scale, clips, extra = ANIMALS[name]
    frames = CRITTER_FRAMES if path.startswith("critter") else FRAMES
    meshes = rs.load_model(os.path.join(ROOT, path), scale)
    # The packs' stray unit Icosphere at the origin.
    for o in [o for o in meshes if o.name.startswith("Icosphere")]:
        meshes.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    yaw = rs.Yaw(extra.get("facing", 0.0))
    actions = [rs.find_action(c) for c in clips]
    cells = [(a, d, f) for a in actions for d in DIRS for f in rs.loop_frames(a, frames)]

    def pose(cell):
        a, d, f = cell
        yaw.set(rs.DIRS[d])
        rs.set_pose(a, f)

    meta = sheet(name, out, meshes, cells, pose)
    if "skins" in extra:
        meta["skins"] = skins(name, out, meshes, cells, pose, os.path.join(ROOT, extra["skins"]), meta)
    fps = []
    for a in actions:
        start, end = a.frame_range
        fps.append(round(frames / ((end - start) / 24.0), 2))
    meta.update({"frames": frames, "clips": len(clips), "fps": fps})
    return meta


def sheet(name, out, meshes, cells, pose):
    """Renders `cells` (posed by `pose`) into OUT/<name>_55deg_* with one
    camera fitted to them all; returns the cell size, cols and offset."""
    x1 = y1 = -1e9
    y0 = 1e9
    for cell in cells:
        pose(cell)
        b = rs.screen_bounds(meshes)
        x1 = max(x1, -b["min_x"], b["max_x"])
        y0, y1 = min(y0, b["min_y"]), max(y1, b["max_y"])
    x1, y0, y1 = x1 + PAD, y0 - PAD, y1 + PAD
    w = math.ceil(2 * x1 * DENSITY / 8) * 8
    h = math.ceil((y1 - y0) * DENSITY / 8) * 8
    cy = (y0 + y1) / 2
    cols = min(len(cells), MAX_SIDE // w)
    rows = math.ceil(len(cells) / cols)
    assert rows * h <= MAX_SIDE, (name, rows, h)
    rs.setup_scene(cy, max(w, h) / DENSITY, w, h)
    prefix = os.path.join(out, f"{name}_55deg")
    rs.pack_sheet(meshes, cells, pose, (w, h), cols, prefix)
    half_normal(f"{prefix}_normal.png")
    return {"cell": [w, h], "cols": cols, "offset": [0.0, round(-cy * DENSITY, 2)]}


def skins(name, out, meshes, cells, pose, folder, meta):
    """The other colourings: the model's picture swapped for each of
    folder/skin_<n>.jpg in turn and only the picture sheet rendered again
    (same camera, same cells). The first colouring's sheet is renamed
    <name>_1_55deg_albedo.png; returns how many there are."""
    files = sorted(f for f in os.listdir(folder) if f.startswith("skin_"))
    tex = next(n for o in meshes for s in o.material_slots if s.material
               for n in s.material.node_tree.nodes if n.type == "TEX_IMAGE"
               and any(l.to_socket.name == "Base Color" for l in n.outputs[0].links))
    w, h = meta["cell"]
    for f in files:
        n = int(f.split("_")[1].split(".")[0])
        tex.image = bpy.data.images.load(os.path.join(folder, f))
        rs.pack_sheet(meshes, cells, pose, (w, h), meta["cols"], os.path.join(out, f"{name}_{n}_55deg"),
                      modes=("albedo",))
        print(name, "colouring", n, flush=True)
    os.remove(os.path.join(out, f"{name}_55deg_albedo.png"))
    return len(files)


def main():
    args = sys.argv[1:]
    out = args[0]
    names = args[1:] or list(ANIMALS)
    os.makedirs(out, exist_ok=True)
    meta_path = os.path.join(out, "animals.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    for name in names:
        meta[name] = render(name, out)
        print(name, json.dumps(meta[name]), flush=True)
        json.dump(meta, open(meta_path, "w"), indent=1)


if __name__ == "__main__":
    main()
