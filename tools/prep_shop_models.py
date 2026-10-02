"""The shop's new wares, from the user's model packs (user request: the
frog and the low-poly spider as live baits; the knives, the gun and its
rounds, the flashlight and its battery, the food, and a cup for the tea -
all things to buy). Each is
made into one small game model for the menus' 3D previews and the icons
(tools/render_square_icons.py):

  - its parts (modifiers applied, curves made solid) joined into one,
    turned and sized as given (the flashlight the way the old one lay -
    lens to +x, 1.05 long - since the character holds it in the try-on);
  - a copy cut down to `tris` triangles with fresh UVs;
  - the original's look baked onto it: colour, roughness and metalness
    read straight off each material (no lighting) - whatever the pack
    used, image or node set-up - into one small texture, roughness and
    metalness packed into a second (glTF's G and B);
  - saved as assets/models/items/<name>.glb, the textures as JPEG.

  bpyenv/bin/python tools/prep_shop_models.py SRC_DIR [name ...]   (repo root)

SRC_DIR holds the packs as unpacked (see SOURCES). The bread roll came
unpainted, so it wears the bread pack's crust. The packs stay out of the
repo.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items")


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metal=0.0, rough=0.5, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if image:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(image)
        m.node_tree.links.new(t.outputs[0], b.inputs["Base Color"])
    return m


def set_image(m, image, socket="Base Color", data=False):
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(image)
    if data:
        t.image.colorspace_settings.name = "Non-Color"
    nt.links.new(t.outputs[0], b.inputs[socket])
    return b


def solid(objs):
    """One mesh object of `objs` as they show (modifiers applied, curves
    made solid), in world space."""
    dg = bpy.context.evaluated_depsgraph_get()
    made = []
    for o in objs:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        if not me.materials and o.material_slots:
            for s in o.material_slots:
                me.materials.append(s.material)
        n = bpy.data.objects.new(o.name + "_s", me)
        n.matrix_world = o.matrix_world
        bpy.context.scene.collection.objects.link(n)
        made.append(n)
    for o in list(bpy.context.scene.objects):
        if o not in made:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.object.join()
    high = bpy.context.view_layer.objects.active
    high.name = "high"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return high


def bounds(o):
    pts = np.array([v.co[:] for v in o.data.vertices])
    return pts.min(0), pts.max(0)


def place(o, turn=(0, 0, 0), length=1.0, base=False, align=False):
    """Turned (degrees about x, y, z), sized so its longest side is
    `length` and centred on the origin (its bottom on it, `base`). With
    `align`, first laid along x by its own length (for a thing lying
    slantwise in its pack)."""
    if align:
        pts = np.array([v.co[:] for v in o.data.vertices])
        pts -= pts.mean(0)
        axis = np.linalg.svd(pts, full_matrices=False)[2][0]
        rot = Vector(axis).rotation_difference(Vector((1, 0, 0))).to_matrix()
        for v in o.data.vertices:
            v.co = rot @ Vector(v.co)
    o.rotation_euler = tuple(math.radians(a) for a in turn)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = bounds(o)
    k = length / max(hi - lo)
    c = (lo + hi) / 2
    if base:
        c[2] = lo[2]
    for v in o.data.vertices:
        v.co = (Vector(v.co) - Vector(c)) * k


def emission_of(m, what):
    """Re-routes material m's output to an emission of its `what` (the
    Principled input's link or value): colour, Roughness or Metallic."""
    nt = m.node_tree
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
    if out is None:
        return
    for n in [n for n in nt.nodes if n.name.startswith("__bake")]:
        nt.nodes.remove(n)
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.name = "__bake"
    src = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    sock = None
    if src is not None:
        sock = src.inputs["Base Color" if what == "color" else what]
    else:
        # Not a Principled set-up: the first shader with a colour.
        shader = next((n for n in nt.nodes if "Color" in n.inputs and n.type.startswith("BSDF")), None)
        if shader is not None and what == "color":
            sock = shader.inputs["Color"]
    if sock is not None and sock.is_linked:
        nt.links.new(sock.links[0].from_socket, emit.inputs["Color"])
    elif sock is not None:
        v = sock.default_value
        emit.inputs["Color"].default_value = tuple(v) if hasattr(v, "__len__") else (v, v, v, 1.0)
    else:
        emit.inputs["Color"].default_value = {"color": (0.5, 0.5, 0.5, 1), "Roughness": (0.5, 0.5, 0.5, 1),
                                              "Metallic": (0, 0, 0, 1)}[what]
    nt.links.new(emit.outputs[0], out.inputs["Surface"])


def _fill_misses(im):
    """Texels the bake found no surface for stay pure black: given the
    average of the rest instead (a dark seam or hole otherwise)."""
    w, h = im.size
    px = np.empty(w * h * 4, np.float32)
    im.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    miss = px[:, :3].sum(1) <= 0.0
    if miss.all() or not miss.any():
        return
    px[miss, :3] = px[~miss, :3].mean(0)
    im.pixels.foreach_set(px.ravel())


def bake(name, high, tris, size=512, out_dir=OUT, reach=0.04):
    """The cut-down copy with high's look baked on; saved as the item (in
    out_dir). `reach`: how far (a share of its size) the bake looks for
    the original's surface - more for thin, gappy things cut down hard."""
    bpy.ops.object.select_all(action="DESELECT")
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.scene.collection.objects.link(low)
    have = sum(len(p.vertices) - 2 for p in low.data.polygons)
    if have > tris:
        dec = low.modifiers.new("dec", "DECIMATE")
        dec.ratio = tris / have
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.modifier_apply(modifier="dec")
    low.data.materials.clear()
    while low.data.uv_layers:
        low.data.uv_layers.remove(low.data.uv_layers[0])
    low.data.uv_layers.new(name="UV")
    bpy.context.view_layer.objects.active = low
    low.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    low.data.shade_smooth()
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    except (AttributeError, RuntimeError):
        pass

    target = bpy.data.materials.new(name)
    target.use_nodes = True
    low.data.materials.append(target)
    tn = target.node_tree
    slot = tn.nodes.new("ShaderNodeTexImage")
    tn.nodes.active = slot

    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 4
    sc.render.bake.use_selected_to_active = True
    lo, hi = bounds(high)
    span = float(max(hi - lo))
    sc.render.bake.cage_extrusion = span * reach * 0.25
    sc.render.bake.max_ray_distance = span * reach
    sc.render.bake.margin = 6
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    images = {}
    for what in ("color", "Roughness", "Metallic"):
        for m in high.data.materials:
            if m is not None and m.use_nodes:
                emission_of(m, what)
        im = bpy.data.images.new(f"{name}_{what}", size, size)
        if what != "color":
            im.colorspace_settings.name = "Non-Color"
        slot.image = im
        bpy.ops.object.bake(type="EMIT")
        if what != "Metallic":
            _fill_misses(im)
        images[what] = im
    # Roughness in G, metalness in B (glTF's metallic-roughness texture).
    mr = bpy.data.images.new(f"{name}_mr", size, size)
    mr.colorspace_settings.name = "Non-Color"
    px = np.empty(size * size * 4, np.float32)
    images["Roughness"].pixels.foreach_get(px)
    rough = px.reshape(-1, 4)[:, 0].copy()
    images["Metallic"].pixels.foreach_get(px)
    metal = px.reshape(-1, 4)[:, 0].copy()
    out = np.ones((size * size, 4), np.float32)
    out[:, 0] = 1.0
    out[:, 1] = rough
    out[:, 2] = metal
    mr.pixels.foreach_set(out.ravel())
    for im in (images["color"], mr):
        im.pack()

    # The game material.
    tn.nodes.remove(slot)
    b = next(n for n in tn.nodes if n.type == "BSDF_PRINCIPLED")
    col = tn.nodes.new("ShaderNodeTexImage")
    col.image = images["color"]
    tn.links.new(col.outputs[0], b.inputs["Base Color"])
    mrt = tn.nodes.new("ShaderNodeTexImage")
    mrt.image = mr
    sep = tn.nodes.new("ShaderNodeSeparateColor")
    tn.links.new(mrt.outputs[0], sep.inputs[0])
    tn.links.new(sep.outputs["Green"], b.inputs["Roughness"])
    tn.links.new(sep.outputs["Blue"], b.inputs["Metallic"])

    bpy.data.objects.remove(high, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_image_format="JPEG", export_jpeg_quality=85)
    print(name, sum(len(p.vertices) - 2 for p in low.data.polygons), "tris,",
          os.path.getsize(path) // 1024, "KB", flush=True)


# ---------------------------------------------------------------- the wares
# Each builder: the source opened, its parts picked, materials put right
# where the pack's own don't come through, then placed and baked.

def frog(src):
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "frog", "frog.FBX"))
    m = mat("frog", (1, 1, 1), rough=0.4, image=os.path.join(src, "frog", "frog_albedo.png"))
    o = next(o for o in bpy.data.objects if o.type == "MESH")
    o.data.materials.clear()
    o.data.materials.append(m)
    high = solid([o])
    place(high, (0, 0, 0), 0.1, base=True)
    bake("frog", high, 2000)


def spider(src):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "spider_low.blend"))
    o = bpy.data.objects["Lowpoly Spider"]
    for m in o.data.materials:
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if b is not None:
            b.inputs["Metallic"].default_value = 0.0
    high = solid([o])
    place(high, (0, 0, 0), 0.07, base=True)
    bake("spider", high, 1200)


def knife(src):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "knife.blend"))
    parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name != "Plane.001"]
    # The blade's picture samples nearly black here (it's shown in the pack
    # by a bright studio's reflections): plain worn steel instead.
    steel = mat("blade", (0.55, 0.56, 0.58), metal=0.85, rough=0.32)
    blade = bpy.data.objects["Plane"]
    blade.data.materials.clear()
    blade.data.materials.append(steel)
    high = solid(parts)
    # Lies slantwise in the pack: laid along x, the blade (the thin end)
    # to +x, its flat facing -y (where the icons look from).
    place(high, (0, 0, 0), 0.32, align=True)

    def thin(part):
        yz = part[:, 1:] - part[:, 1:].mean(0)
        return np.linalg.svd(yz, full_matrices=False)

    pts = np.array([v.co[:] for v in high.data.vertices])
    if thin(pts[pts[:, 0] < 0])[1][1] < thin(pts[pts[:, 0] > 0])[1][1]:
        place(high, (0, 0, 180), 0.32)
        pts = np.array([v.co[:] for v in high.data.vertices])
    minor = thin(pts[pts[:, 0] > 0.04])[2][1]
    place(high, (-math.degrees(math.atan2(minor[1], minor[0])), 0, 0), 0.32)
    bake("knife", high, 3000)


def machete(src):
    fresh()
    # The pack's FBX with its own textures (the .blend first sent had lost
    # them).
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "machete_fbx", "MACHETE.fbx"))
    high = solid([o for o in bpy.data.objects if o.type == "MESH"])
    # Grip at +x in the pack: blade to +x.
    place(high, (0, 0, 180), 0.55)
    bake("machete", high, 2000)


def battery(src):
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "battery", "battery.fbx"))
    high = solid([o for o in bpy.data.objects if o.type == "MESH"])
    # Stands upright once its object turn is applied.
    place(high, (0, 0, 0), 0.05, base=True)
    bake("battery", high, 900, 256)


def loaf(src):
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "loaf", "loaf.fbx"))
    o = next(o for o in bpy.data.objects if o.type == "MESH")
    m = mat("loaf", (1, 1, 1), rough=0.7, image=os.path.join(src, "loaf", "Color.png"))
    set_image(m, os.path.join(src, "loaf", "Roughness.png"), "Roughness", data=True)
    o.data.materials.clear()
    o.data.materials.append(m)
    high = solid([o])
    place(high, (0, 0, 0), 0.3, base=True)
    bake("loaf", high, 1200)


def hatchet(src):
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, "hatchet", "cc0_-_hatchet_1k.glb"))
    high = solid([o for o in bpy.data.objects if o.type == "MESH"])
    place(high, (0, 0, 0), 0.38)
    bake("hatchet", high, 1500)


def glock(src):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "glock.blend"))
    # The gun with its magazine in; the loose rounds left out.
    parts = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("b_low")]
    high = solid(parts)
    place(high, (0, 0, 180), 0.19)
    bake("glock", high, 3000)


def ammo(src):
    fresh()
    # The user's 9 mm round (230k triangles, plain brass and copper):
    # two of them side by side, cut right down.
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "bullet.fbx"))
    one = next(o for o in bpy.data.objects if o.type == "MESH")
    two = one.copy()
    two.data = one.data.copy()
    bpy.context.scene.collection.objects.link(two)
    two.location.x += one.dimensions.x * 1.1
    two.location.y += one.dimensions.y * 0.3
    high = solid([one, two])
    place(high, (0, 0, 0), 0.03, base=True)
    bake("ammo", high, 1000, 256)


def flashlight(src):
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "flashlight.blend"))
    parts = [o for o in bpy.data.objects if o.type in ("MESH", "CURVE") and o.name != "floor"
             and o.visible_get() and "support" not in [c.name for c in o.users_collection]]
    # The lens glows warm, as the old one's did.
    lens = mat("lens", (1.0, 0.95, 0.75), rough=0.2)
    for o in parts:
        if o.material_slots and o.material_slots[0].material and o.material_slots[0].material.name == "light":
            o.data.materials.clear()
            o.data.materials.append(lens)
    high = solid(parts)
    # Lens at -y in the pack: to +x, as the old flashlight lay (the
    # character's try-on holds it that way).
    place(high, (0, 0, 90), 1.05)
    bake("flashlight", high, 3000)


def cup(src):
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "cup", "CupClear_exp.fbx"))
    m = mat("cup", (1, 1, 1), rough=0.35, image=os.path.join(src, "cup", "Cup_diffuse.png"))
    set_image(m, os.path.join(src, "cup", "Cup_roughness.png"), "Roughness", data=True)
    parts = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in parts:
        o.data.materials.clear()
        o.data.materials.append(m)
    high = solid(parts)
    # Stands upright in the pack (z up), the handle to +y.
    place(high, (0, 0, 0), 0.12, base=True)
    # User request: the cup is for the tea - tea in it, near the brim.
    lo, hi = bounds(high)
    pts = np.array([v.co[:] for v in high.data.vertices])
    rim = pts[pts[:, 2] > hi[2] - (hi[2] - lo[2]) * 0.04]
    centre = np.array([(lo[0] + hi[0]) / 2, np.median(rim[:, 1]), 0.0])
    radius = float(np.percentile(np.hypot(rim[:, 0] - centre[0], rim[:, 1] - centre[1]), 15)) * 0.97
    bpy.ops.mesh.primitive_circle_add(vertices=32, radius=radius, fill_type="NGON",
                                      location=(centre[0], centre[1], lo[2] + (hi[2] - lo[2]) * 0.82))
    tea = bpy.context.object
    tea.data.materials.append(mat("tea", (0.32, 0.14, 0.04), rough=0.08))
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    tea.select_set(True)
    bpy.context.view_layer.objects.active = high
    bpy.ops.object.join()
    bake("cup", high, 1500)


def cheese(src):
    fresh()
    bpy.ops.wm.obj_import(filepath=os.path.join(src, "cheese", "cheese.obj"))
    o = next(o for o in bpy.data.objects if o.type == "MESH")
    for s in o.material_slots:
        k = s.material.name[:8]  # cheese01..03
        m = mat(s.material.name, (1, 1, 1), rough=0.55, image=os.path.join(src, "cheese", k + "DiffuseMap.png"))
        s.material = m
    high = solid([o])
    lo, hi = bounds(high)
    # Lying flat (the OBJ's thin side is its z already).
    place(high, (0, 0, 0), 0.16, base=True)
    bake("cheese", high, 600)


def roll(src):
    fresh()
    bpy.ops.wm.obj_import(filepath=os.path.join(src, "roll", "roll_low.obj"))
    o = next(o for o in bpy.data.objects if o.type == "MESH")
    # Unpainted in the pack: a golden-brown crust, darker on top and paler
    # underneath, with the bread pack's crust picture for its grain (its
    # light and dark only - its own colour is too red).
    m = bpy.data.materials.new("crust")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Roughness"].default_value = 0.7
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (0.3, 0.3, 0.3)
    nt.links.new(coord.outputs["Object"], mapping.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(src, "roll", "bread_crust.jpg"))
    tex.projection = "BOX"
    tex.projection_blend = 0.35
    nt.links.new(mapping.outputs[0], tex.inputs[0])
    grain = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(tex.outputs[0], grain.inputs[0])
    gmap = nt.nodes.new("ShaderNodeMapRange")
    gmap.inputs["From Min"].default_value = 0.1
    gmap.inputs["From Max"].default_value = 0.7
    gmap.inputs["To Min"].default_value = 0.72
    gmap.inputs["To Max"].default_value = 1.18
    nt.links.new(grain.outputs[0], gmap.inputs[0])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = (0.82, 0.62, 0.36, 1)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (0.5, 0.26, 0.09, 1)
    half = nt.nodes.new("ShaderNodeMapRange")
    half.inputs["From Min"].default_value = -1.0
    nt.links.new(sep.outputs["Z"], half.inputs[0])
    nt.links.new(half.outputs[0], ramp.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    comb = nt.nodes.new("ShaderNodeCombineColor")
    for ch in ("Red", "Green", "Blue"):
        nt.links.new(gmap.outputs[0], comb.inputs[ch])
    nt.links.new(ramp.outputs[0], mul.inputs[6])
    nt.links.new(comb.outputs[0], mul.inputs[7])
    nt.links.new(mul.outputs[2], b.inputs["Base Color"])
    o.data.materials.clear()
    o.data.materials.append(m)
    high = solid([o])
    # Imported lying flat, its flat underside down (-z).
    place(high, (0, 0, 0), 0.1, base=True)
    bake("roll", high, 1600)


SOURCES = {"frog": frog, "spider": spider, "knife": knife, "machete": machete, "hatchet": hatchet,
           "glock": glock, "ammo": ammo, "battery": battery, "loaf": loaf, "flashlight": flashlight, "cup": cup, "cheese": cheese, "roll": roll}


def main():
    args = sys.argv[1:]
    src = args[0]
    for name in args[1:] or list(SOURCES):
        SOURCES[name](src)


if __name__ == "__main__":
    main()
