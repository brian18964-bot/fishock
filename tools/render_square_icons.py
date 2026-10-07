"""Square icons for the things sold and carried, in the manner of a fantasy
MMO's (user request: the shop's icons in the WoW look): each thing from
its 3D model, close up at a lively angle, lit warm from the upper left
with a cold rim light behind, on a dark painted ground glowing in its
kind's colour, a dark edge round it. 128x128, shown at 64 or less.

  bpyenv/bin/python tools/render_square_icons.py [name ...]    (repo root)

Writes assets/sprites/icons/<name>.png - rod_0..rod_4, flashlight,
battery, lamp, worm, cricket, shrimp, minnow, tea, roll, loaf, cheese,
potion_vigor, potion_ward, eyeball, binoculars, eye_altar, eye_ghost, net,
rat, snake, crab, bee, black_spider,
frog, spider, knife, machete, hatchet, glock, ammo, tent_1..tent_9,
lure_1..lure_6, and throw (the 誘惑 action button) (Items.square_icon()
maps the things' ids onto these).
"""
import math
import os
import sys
import tempfile

import bpy
import bmesh  # noqa: E402 (after bpy, which provides it)
import numpy as np
from mathutils import Vector
from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "icons")
MODELS = os.path.join(ROOT, "assets", "models")
SIZE = 128
RENDER = 320

# The ground's glow, by kind.
GEAR = (0.62, 0.4, 0.16)
LIGHT = (0.7, 0.5, 0.18)
ITEM = (0.36, 0.26, 0.62)
TACKLE = (0.12, 0.46, 0.44)
BAIT = (0.34, 0.46, 0.16)
ABILITY = (0.62, 0.14, 0.1)
WEAPON = (0.5, 0.22, 0.2)

# name: model, turn (degrees about x, y, z), fill (the frame spans the
# thing's size / fill), ground; thick (a rod is a hair at this size: made
# thicker across), aim (where along the thing's length the frame centres,
# 0..1 from its low end - a rod's reel and grip, not the middle of it).
THINGS = {
    "flashlight": dict(model="items/flashlight.glb", turn=(0, -35, -30), fill=0.95, ground=LIGHT),
    "battery": dict(model="items/battery.glb", turn=(8, -18, 25), fill=0.8, ground=ITEM),
    "lamp": dict(model="oil_lamp.glb", turn=(0, 0, 20), fill=0.86, ground=LIGHT),
    "worm": dict(model="items/worm.glb", turn=(-90, 0, 0), fill=0.84, ground=BAIT, smooth=True),
    # User request (round 7): the user's grasshopper (the 蚱蜢 bait, in the
    # old cricket's place), small fish and earthworm, and a live shrimp
    # made here (tools/prep_shop_models.py).
    "cricket": dict(model="items/grasshopper.glb", turn=(20, 0, 30), fill=0.9, ground=BAIT),
    "shrimp": dict(model="items/shrimp.glb", turn=(20, 0, 25), fill=0.9, ground=BAIT),
    "minnow": dict(model="items/minnow.glb", turn=(0, 0, 20), fill=0.9, ground=BAIT),
    # Things to use in a run (round 7): the potions, the eyeball, the
    # binoculars.
    "potion_vigor": dict(model="items/potion_vigor.glb", turn=(12, 0, 20), fill=0.86, ground=ABILITY),
    "potion_ward": dict(model="items/potion_ward.glb", turn=(12, 0, 20), fill=0.86, ground=TACKLE),
    "eyeball": dict(model="items/eyeball.glb", turn=(10, 0, -105), fill=0.8, ground=ITEM),
    "binoculars": dict(model="items/binoculars.glb", turn=(15, 0, 30), fill=0.92, ground=GEAR),
    # Round 8: the eye that shows the altar, the one that sees the ghosts;
    # the net; and the live baits only caught on the map (their own
    # critter models, posed - tools/prep_shop_models.py).
    "eye_altar": dict(model="items/eye_altar.glb", turn=(10, 0, -105), fill=0.8, ground=ABILITY),
    "eye_ghost": dict(model="items/eye_ghost.glb", turn=(10, 0, -105), fill=0.8, ground=TACKLE),
    "net": dict(model="items/net.glb", turn=(0, -40, 0), fill=1.0, ground=GEAR),
    "rat": dict(model="items/rat.glb", turn=(20, 0, 35), fill=0.9, ground=BAIT),
    "snake": dict(model="items/snake.glb", turn=(70, 0, 20), fill=0.95, ground=BAIT),
    "crab": dict(model="items/crab.glb", turn=(30, 0, 20), fill=0.86, ground=BAIT),
    "bee": dict(model="items/bee.glb", turn=(20, 0, 35), fill=0.86, ground=BAIT),
    "black_spider": dict(model="items/black_spider.glb", turn=(35, 0, 25), fill=0.9, ground=BAIT),
    # The merchant's tea (Camp v2): had at once, for spirit.
    # User request: the tea served in the user's cup.
    "tea": dict(model="items/cup.glb", turn=(28, 0, -30), fill=0.8, ground=ITEM),
    # User request: the user's models (tools/prep_shop_models.py) - the
    # food, the live frog and spider, the weapons and the rounds.
    "roll": dict(model="items/roll.glb", turn=(35, 0, 20), fill=0.8, ground=ITEM),
    "loaf": dict(model="items/loaf.glb", turn=(35, 0, 25), fill=0.92, ground=ITEM),
    "cheese": dict(model="items/cheese.glb", turn=(40, 0, -20), fill=0.86, ground=ITEM),
    "frog": dict(model="items/frog.glb", turn=(20, 0, 35), fill=0.86, ground=BAIT),
    "spider": dict(model="items/spider.glb", turn=(35, 0, 25), fill=0.9, ground=BAIT),
    "knife": dict(model="items/knife.glb", turn=(0, -40, 0), fill=1.05, ground=WEAPON),
    "machete": dict(model="items/machete.glb", turn=(0, -40, 0), fill=1.05, ground=WEAPON),
    "hatchet": dict(model="items/hatchet.glb", turn=(70, 0, 20), fill=0.9, ground=WEAPON),
    "glock": dict(model="items/glock.glb", turn=(0, -12, 0), fill=0.92, ground=WEAPON),
    "ammo": dict(model="items/ammo.glb", turn=(15, 0, 20), fill=0.8, ground=ITEM),
    # The in-game 誘惑 action (a bait fish thrown): the fish flung nose-up
    # on a crimson ground.
    "throw": dict(model="fish/minnow.glb", turn=(0, -40, 35), fill=0.95, ground=ABILITY),
}
for _t in range(5):
    THINGS["rod_%d" % _t] = dict(model="fishing_rod_lvl%d.glb" % (_t + 1), turn=(0, 45, 0), fill=2.0, ground=GEAR,
                                 thick=3.2, aim=0.3)
# The camp's tents (Camp v2: earned by achievements, picked on the
# equipment page's 營地 tab).
for _n in range(1, 10):
    THINGS["tent_%d" % _n] = dict(model="camp/tent_%d.glb" % _n, turn=(18, 0, -28), fill=0.92, ground=GEAR,
                                   dim=0.75)
for _n in range(1, 7):
    THINGS["lure_%d" % _n] = dict(model="items/lure_%d.glb" % _n, turn=(0, -15, 28), fill=1.0, ground=TACKLE)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(model, dim=1.0):
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, model))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if model.startswith("fish/") or model.startswith("camp/"):
        # The fish's (and the camp's) mesh has no material: its baked skin.
        skin_path = model[:-4] + (".png" if model.startswith("fish/") else "_albedo.png")
        skin = bpy.data.images.load(os.path.join(MODELS, skin_path))
        m = bpy.data.materials.new("skin")
        m.use_nodes = True
        nt = m.node_tree
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = skin
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = 0.4
        if dim < 1.0:
            # A pale skin (canvas) toned down so the key light doesn't burn it.
            hsv = nt.nodes.new("ShaderNodeHueSaturation")
            hsv.inputs["Value"].default_value = dim
            hsv.inputs["Saturation"].default_value = 1.25
            nt.links.new(tex.outputs["Color"], hsv.inputs["Color"])
            nt.links.new(hsv.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 1.0
            bsdf.inputs["Specular IOR Level"].default_value = 0.1
        else:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        for o in meshes:
            o.data.materials.clear()
            o.data.materials.append(m)
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in bpy.data.objects:
        if o.parent is None and o is not root:
            o.parent = root
    return root, meshes


def bounds(meshes):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def area(name, loc, color, energy, size):
    light = bpy.data.lights.new(name, "AREA")
    light.color = color
    light.energy = energy
    light.size = size
    o = bpy.data.objects.new(name, light)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    d = -Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return o


def stage(meshes, fill, aim=None):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = RENDER
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.09, 0.08, 0.08, 1)
    bg.inputs[1].default_value = 1.0
    scene.world = world
    lo, hi = bounds(meshes)
    c = (lo + hi) / 2
    if aim is not None:
        # Along the diagonal the thing lies on, from its low end.
        c = lo + (hi - lo) * aim
    span = max(hi.x - lo.x, hi.z - lo.z)
    r = max((hi - lo).length, 0.01) / (2.0 if aim is not None else 1.0)
    # Warm key from the upper left, cold rim from behind on the right, a
    # little fill from below.
    area("key", (c.x - 1.6 * r, c.y - 1.9 * r, c.z + 1.9 * r), (1.0, 0.86, 0.66), 520 * r * r, r)
    area("rim", (c.x + 1.8 * r, c.y + 1.6 * r, c.z + 1.1 * r), (0.55, 0.72, 1.0), 700 * r * r, r)
    area("fill", (c.x + 0.4 * r, c.y - 2.2 * r, c.z - 1.2 * r), (0.9, 0.9, 1.0), 90 * r * r, r)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = span / fill
    cam.location = (c.x, c.y - 8 * r, c.z)
    cam.data.clip_end = 40 * r
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam


def ground(color, seed):
    """The painted ground: a dark square glowing in the middle, mottled."""
    n = RENDER
    y, x = np.mgrid[0:n, 0:n] / (n - 1)
    d = np.sqrt((x - 0.46) ** 2 + (y - 0.42) ** 2) / 0.75
    glow = np.clip(1.0 - d, 0.0, 1.0) ** 1.6
    rng = np.random.default_rng(seed)
    mottle = Image.fromarray((rng.random((n // 8, n // 8)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
    mottle = np.asarray(mottle.filter(ImageFilter.GaussianBlur(6)), dtype=np.float32) / 255.0
    col = np.array(color, dtype=np.float32)
    base = np.array((0.035, 0.03, 0.03), dtype=np.float32)
    img = base + col[None, None, :] * (glow[..., None] * 0.85) * (0.8 + 0.4 * mottle[..., None])
    # Darker toward the edges, a bevel's shade along them.
    edge = np.minimum(np.minimum(x, 1 - x), np.minimum(y, 1 - y))
    img *= (0.55 + 0.45 * np.clip(edge / 0.12, 0, 1))[..., None]
    return np.clip(img, 0, 1)


def compose(render_path, color, seed):
    thing = np.asarray(Image.open(render_path).convert("RGBA"), dtype=np.float32) / 255.0
    alpha = thing[..., 3]
    img = ground(color, seed)
    a_img = Image.fromarray((alpha * 255).astype(np.uint8))
    # A soft glow of the ground's colour round the thing, then a dark edge.
    halo = np.asarray(a_img.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(14)), dtype=np.float32) / 255.0
    img = img + np.array(color)[None, None, :] * halo[..., None] * 0.55
    edge = np.asarray(a_img.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float32) / 255.0
    img = img * (1 - edge[..., None] * 0.85)
    img = img * (1 - alpha[..., None]) + thing[..., :3] * alpha[..., None]
    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")
    out = out.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    return out


def icon(name):
    spec = THINGS[name]
    fresh()
    root, meshes = load(spec["model"], spec.get("dim", 1.0))
    if spec.get("smooth"):
        # A low-poly body, shaded round (its faces joined up, its own flat
        # normals dropped).
        for o in meshes:
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            bm.to_mesh(o.data)
            bm.free()
            if o.data.has_custom_normals:
                with bpy.context.temp_override(object=o, active_object=o):
                    bpy.ops.mesh.customdata_custom_splitnormals_clear()
            o.data.shade_smooth()
    if "thick" in spec:
        # Made thicker across its length (the model's own up axis).
        k = spec["thick"]
        root.scale = (k, k, 1.0)
    root.rotation_euler = tuple(math.radians(a) for a in spec["turn"])
    bpy.context.view_layer.update()
    stage(meshes, spec["fill"], spec.get("aim"))
    tmp = os.path.join(tempfile.gettempdir(), "icon_%s.png" % name)
    scene = bpy.context.scene
    scene.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    compose(tmp, spec["ground"], sum(map(ord, name))).save(os.path.join(OUT, name + ".png"), optimize=True)
    os.remove(tmp)
    print("icon", name, flush=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or list(THINGS):
        icon(name)


if __name__ == "__main__":
    main()
