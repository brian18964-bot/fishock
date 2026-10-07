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
from mathutils import Matrix, Vector

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


def bake(name, high, tris, size=512, out_dir=OUT, reach=0.04, remesh=None):
    """The cut-down copy with high's look baked on; saved as the item (in
    out_dir). `reach`: how far (a share of its size) the bake looks for
    the original's surface - more for thin, gappy things cut down hard.
    `remesh`: the copy first remade as one closed skin, voxels this share
    of its size (thin-walled glass, inside and out, falls apart when cut
    down as it is)."""
    bpy.ops.object.select_all(action="DESELECT")
    low = high.copy()
    low.data = high.data.copy()
    low.name = name
    bpy.context.scene.collection.objects.link(low)
    if remesh:
        lo, hi = bounds(low)
        rm = low.modifiers.new("rm", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = float(max(hi - lo)) * remesh
        bpy.context.view_layer.objects.active = low
        bpy.ops.object.modifier_apply(modifier="rm")
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


# ---------------------------------------------------------------- round 7
# User request: the user's earthworm, grasshopper and small fish as live
# baits; two potions, an eyeball and binoculars as things to use in a run;
# and a live shrimp made here (from the user's blockout: a curled body of
# segments under a carapace, a tail fan). SRC_DIR as laid out by hand:
#   worm/worm.fbx  Grasshopper.blend  fish.blend  potion/vials.fbx
#   potion/Potion.fbx  binoculars/Binoculars.fbx (+ textures/)  eye/eye.jpg

def _mix_by(nt, fac, a, b):
    """A colour mix node: a where fac is 0, b where it's 1."""
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(fac, mix.inputs[0])
    for sock, v in ((mix.inputs[6], a), (mix.inputs[7], b)):
        if isinstance(v, tuple):
            sock.default_value = (*v, 1)
        else:
            nt.links.new(v, sock)
    return mix.outputs[2]


def _ramp(nt, fac, stops):
    """A colour ramp on `fac`: [(position, rgb)]."""
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    while len(els) > len(stops):
        els.remove(els[-1])
    while len(els) < len(stops):
        els.new(0.5)
    for e, (pos, rgb) in zip(els, stops):
        e.position = pos
        e.color = (*rgb, 1)
    nt.links.new(fac, r.inputs[0])
    return r.outputs[0]


def worm(src):
    """The user's earthworm (the pack's low-poly one, laid out as it came;
    its materials didn't come through): pink-brown, ringed, the saddle (the
    clitellum) a third of the way back, glistening."""
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "worm", "worm.fbx"))
    o = bpy.data.objects["Worm_LP"]
    m = bpy.data.materials.new("worm")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    # rings along its length (x)
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_profile = "SIN"
    wave.inputs["Scale"].default_value = 70.0
    wave.inputs["Distortion"].default_value = 0.0
    nt.links.new(tc.outputs["Generated"], wave.inputs["Vector"])
    body = _mix_by(nt, wave.outputs["Fac"], (0.36, 0.13, 0.12), (0.55, 0.24, 0.22))
    saddle = _ramp(nt, sep.outputs["X"], [(0.0, (0, 0, 0)), (0.6, (0, 0, 0)), (0.64, (1, 1, 1)), (0.72, (1, 1, 1)), (0.76, (0, 0, 0))])
    col = _mix_by(nt, saddle, body, (0.72, 0.38, 0.3))
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.3
    o.data.materials.clear()
    o.data.materials.append(m)
    high = solid([o])
    place(high, (0, 0, 0), 0.12, base=True)
    bake("worm", high, 2400)


def grasshopper(src):
    """The user's grasshopper (sold as the 蚱蜢 live bait, the old cricket's
    place): its own painted texture."""
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "Grasshopper.blend"))
    objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Grasshopper")]
    # Its shader is a node group the bake can't read: the painted texture
    # straight into a plain one instead.
    m = bpy.data.materials["Grasshopper"]
    tex = m.node_tree.nodes["Image Texture"].image
    plain = mat("grasshopper", (1, 1, 1), rough=0.5)
    t = plain.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = tex
    plain.node_tree.links.new(t.outputs[0], next(n for n in plain.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(plain)
    high = solid(objs)
    # its length along y in the file: laid along x, head to +x
    place(high, (0, 0, 90), 0.1, base=True)
    bake("grasshopper", high, 2600, reach=0.06)


def minnow(src):
    """The user's small fish (the 小活魚 bait): its painted body."""
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "fish.blend"))
    o = bpy.data.objects["Sphere"]
    high = solid([o])
    place(high, (0, 0, 0), 0.12)
    bake("minnow", high, 1600)


def binoculars(src):
    """The user's binoculars (望遠鏡: shows where the 渡石 is)."""
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "binoculars", "Binoculars.fbx"))
    o = next(o for o in bpy.data.objects if o.type == "MESH")
    high = solid([o])
    place(high, (90, 0, 0), 0.16, base=True)
    bake("binoculars", high, 3000)


def _glass(name, liquid, fill_z, glow=0.0):
    """Glass that shows its liquid below `fill_z` (object z, after
    placing): the liquid's colour through it, pale glass above."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    edge = _ramp(nt, sep.outputs["Z"], [(fill_z - 0.002, (1, 1, 1)), (fill_z + 0.002, (0, 0, 0))])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 40.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    deep = tuple(c * 0.55 for c in liquid)
    swirl = _mix_by(nt, noise.outputs["Fac"], deep, liquid)
    col = _mix_by(nt, edge, (0.6, 0.68, 0.72), swirl)
    nt.links.new(col, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.08
    return m


def _fill_glass(high, tmp, name, liquid, fill):
    """The placeholder glass on `high` swapped for glass full to `fill`
    of the glass's height (placed: its bottom at z 0)."""
    idx = [i for i, m in enumerate(high.data.materials) if m == tmp][0]
    zs = [v.co.z for v in high.data.vertices]
    top = max(p.center.z for p in high.data.polygons if p.material_index == idx)
    bottom = min(zs)
    high.data.materials[idx] = _glass(name, liquid, bottom + (top - bottom) * fill)


def potion_ward(src):
    """驅鬼藥水: one of the user's three small vials, cork-stoppered, the
    liquid a pale ghostly cyan."""
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "potion", "vials.fbx"))
    glass, cap, liquid = (bpy.data.objects[n] for n in ("Cylinder", "Cylinder.001", "Cylinder.002"))
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o not in (glass, cap, liquid):
            bpy.data.objects.remove(o, do_unlink=True)
    lz = max((liquid.matrix_world @ Vector(c)).z for c in liquid.bound_box)
    gz = [(glass.matrix_world @ Vector(c)).z for c in glass.bound_box]
    fill = (lz - min(gz)) / (max(gz) - min(gz))
    cork = mat("cork", (0.55, 0.4, 0.24), rough=0.85)
    tmp = mat("glass_tmp", (1, 1, 1))
    for o, m in ((glass, tmp), (cap, cork), (liquid, mat("liq", (0.4, 0.95, 0.9)))):
        o.data.materials.clear()
        o.data.materials.append(m)
    high = solid([glass, cap, liquid])
    place(high, (0, 0, 0), 0.1, base=True)
    _fill_glass(high, tmp, "ward_glass", (0.12, 0.78, 0.74), fill)
    bake("potion_ward", high, 1800, remesh=1 / 90)


def potion_vigor(src):
    """增強藥水: the user's corked flask, the liquid a warm blood red."""
    fresh()
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "potion", "Potion.fbx"))
    glass, liquid, cap = (bpy.data.objects[n] for n in ("Kolben 1", "Fluid", "Cylinder"))
    lz = max((liquid.matrix_world @ Vector(c)).z for c in liquid.bound_box)
    gz = [(glass.matrix_world @ Vector(c)).z for c in glass.bound_box]
    fill = (lz - min(gz)) / (max(gz) - min(gz))
    cork = mat("cork", (1, 1, 1), rough=0.85, image=os.path.join(src, "potion", "TexturesCom_BarkCloseup0012_3_S.jpg"))
    tmp = mat("glass_tmp", (1, 1, 1))
    for o, m in ((glass, tmp), (liquid, mat("liq", (0.75, 0.12, 0.08))), (cap, cork)):
        o.data.materials.clear()
        o.data.materials.append(m)
    high = solid([glass, liquid, cap])
    place(high, (0, 0, 0), 0.13, base=True)
    _fill_glass(high, tmp, "vigor_glass", (0.62, 0.05, 0.03), fill)
    bake("potion_vigor", high, 2000, remesh=1 / 110)


def eyeball(src):
    """眼球 (round 8: shows the way to the 渡石): a ball wearing the user's
    eye picture - drawn front on, so laid round the ball from its front
    (the iris) back (the angle from the front as the distance from the
    picture's middle) - glossy."""
    fresh()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=48, ring_count=32)
    o = bpy.context.object
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uv = me.uv_layers.new(name="UV")
    for loop in me.loops:
        v = Vector(me.vertices[loop.vertex_index].co).normalized()
        # front: +x
        a = math.acos(max(-1.0, min(1.0, v.x)))
        # (the iris a little smaller round the ball than an even spread
        # would make it)
        r = 0.5 * (a / math.pi) ** 0.6
        phi = math.atan2(v.z, v.y)
        uv.data[loop.index].uv = (0.5 + r * math.cos(phi), 0.5 + r * math.sin(phi))
    m = mat("eye", (1, 1, 1), rough=0.12, image=os.path.join(src, "eye", "eye.jpg"))
    # the pupil's pure black lifted a hair (the bake takes pure black for
    # "no surface found" and fills it in)
    nt = m.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    lift = _mix_by(nt, nt.nodes.new("ShaderNodeValue").outputs[0], tex.outputs[0], (0.03, 0.02, 0.02))
    lift.node.inputs[0].links[0].from_node.outputs[0].default_value = 0.05
    nt.links.new(lift, next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
    me.materials.append(m)
    bpy.ops.object.shade_smooth()
    # (user request, round 8: no flesh-coloured stub behind the pupil - the
    # nerve's gone)
    high = solid([o])
    place(high, (0, 0, 20), 0.06, base=True)
    bake("eyeball", high, 1600)


def _eye_picture(src_png, out_png, kind):
    """The pack's eye picture repainted in the same places (its UVs): the
    pupil kept where it is, the rest our own. kind "altar": an amber-gold
    ball darkening to rust at the back, the round pupil ringed in
    fire-orange with thin spokes of light out from it; "ghost": a
    violet-black ball, the slit's glow turned to a pale spectral cyan
    mist with a milky film over it."""
    from PIL import Image, ImageFilter
    im = np.asarray(Image.open(src_png).convert("RGB")).astype(np.float32) / 255.0
    h, w, _ = im.shape
    lum = im.mean(2)
    yy, xx = np.mgrid[0:h, 0:w]
    if kind == "altar":
        pupil = lum < 0.12
        cy, cx = yy[pupil].mean(), xx[pupil].mean()
        r_p = math.sqrt(pupil.sum() / math.pi)
        d = np.hypot(yy - cy, xx - cx)
        ang = np.arctan2(yy - cy, xx - cx)
        t = np.clip(d / (w * 0.7), 0, 1)[..., None]
        out = (1 - t) * np.array([0.98, 0.72, 0.22]) + t * np.array([0.42, 0.13, 0.05])
        ring = np.exp(-((d - r_p * 1.25) / (r_p * 0.22)) ** 2)[..., None]
        out = out * (1 - ring) + ring * np.array([1.0, 0.42, 0.06])
        spokes = (np.cos(ang * 14) * 0.5 + 0.5) ** 18 * np.exp(-((d - r_p * 2.3) / (r_p * 0.9)) ** 2)
        out = out + spokes[..., None] * np.array([1.0, 0.9, 0.55]) * 0.6
        out[pupil] = (0.02, 0.01, 0.01)
    else:
        glow = (im[..., 0] > 0.25) & (lum > 0.12)
        pupil = (lum < 0.08) & glow.astype(bool)
        g = np.asarray(Image.fromarray((glow * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(w / 80))) / 255.0
        white = np.clip((lum - 0.5) * 2.5, 0, 1)
        base = np.array([0.1, 0.04, 0.16])
        mist = np.array([0.55, 0.95, 1.0])
        out = base * (1 - g[..., None]) + mist * g[..., None] * (0.55 + 0.45 * white[..., None])
        # the slit itself (dark inside the glow) kept dark
        slit = (lum < 0.1) & (g > 0.5)
        out[slit] = (0.01, 0.02, 0.04)
        # a milky film: lifts everything a little toward pale lilac
        out = out * 0.85 + np.array([0.6, 0.55, 0.75]) * 0.15
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(out_png)


def _reptile_eye(src, variant, kind):
    """The pack's low-poly eye with our own picture (_eye_picture)."""
    fresh()
    base = os.path.join(src, "reptile_eyes")
    bpy.ops.wm.obj_import(filepath=os.path.join(base, "Files", "Reptiles_Eye_OBJ.obj"))
    o = next(o for o in bpy.data.objects if o.type == "MESH")
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    tex_dir = os.path.join(base, "Textures", variant, "1k")
    diffuse = next(f for f in os.listdir(tex_dir) if "Diffuse" in f)
    painted = os.path.join(src, "reptile_eyes", "eye_%s.png" % kind)
    _eye_picture(os.path.join(tex_dir, diffuse), painted, kind)
    o.data.materials.clear()
    o.data.materials.append(mat("eye_" + kind, (1, 1, 1), rough=0.12, image=painted))
    bpy.ops.object.shade_smooth()
    return o


def _ring(name, radius, minor, rot, m, loc=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=minor, major_segments=48,
                                     minor_segments=10, location=loc, rotation=rot)
    r = bpy.context.object
    r.name = name
    r.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return r


def eye_altar(src):
    """祭壇之眼 (round 8: shows the way to the altar): the pack's simplest
    eye (round pupil) repainted amber-gold with a fire ring and spokes of
    light, set like an amulet - a bronze band round its middle and three
    little prongs gripping it from behind."""
    o = _reptile_eye(src, "Red_Eye_03", "altar")
    lo, hi = bounds(o)
    r = float(max(hi - lo)) / 2
    c = Vector(((lo + hi) / 2).tolist())
    bronze = mat("bronze", (0.55, 0.36, 0.16), metal=0.9, rough=0.35)
    # the pupil faces the eye's own front: find it (darkest texel's
    # direction is the mesh's +? - the band goes square to it)
    front = _eye_front(o)
    band = _ring("band", r * 1.02, r * 0.08, (0, 0, 0), bronze, c)
    band.rotation_euler = front.to_track_quat("Z", "Y").to_euler()
    parts = [o, band]
    side = front.orthogonal().normalized()
    for k in range(3):
        a = k * math.tau / 3
        d = (Matrix.Rotation(a, 3, front) @ side)
        tip = c - front * r * 0.55 + d * r * 0.85
        bpy.ops.mesh.primitive_cone_add(radius1=r * 0.12, radius2=r * 0.03, depth=r * 0.6, location=tip, vertices=10)
        p = bpy.context.object
        p.rotation_euler = (-front * 0.5 + d).normalized().to_track_quat("Z", "Y").to_euler()
        p.data.materials.append(bronze)
        parts.append(p)
    high = solid(parts)
    _face_front(high, front)
    place(high, (0, 0, 0), 0.06, base=True)
    bake("eye_altar", high, 2400)


def eye_ghost(src):
    """見鬼之眼 (round 8: shows which way the ghosts are): the pack's slit
    eye repainted violet-black with a pale spectral mist round the slit
    and a milky film, hung in two crossed silver rings."""
    o = _reptile_eye(src, "Black_Red_Eye_06", "ghost")
    lo, hi = bounds(o)
    r = float(max(hi - lo)) / 2
    c = Vector(((lo + hi) / 2).tolist())
    silver = mat("silver", (0.75, 0.77, 0.8), metal=1.0, rough=0.25)
    front = _eye_front(o)
    up = front.orthogonal().normalized()
    # a halo round the eye's rim, and a second ring tipped back from it
    # (neither across the slit)
    a = _ring("ring_a", r * 1.08, r * 0.05, (0, 0, 0), silver, c)
    a.rotation_euler = front.to_track_quat("Z", "Y").to_euler()
    b = _ring("ring_b", r * 1.2, r * 0.04, (0, 0, 0), silver, c)
    b.rotation_euler = (front * math.cos(1.1) + up * math.sin(1.1)).to_track_quat("Z", "Y").to_euler()
    high = solid([o, a, b])
    _face_front(high, front)
    place(high, (0, 0, 0), 0.06, base=True)
    bake("eye_ghost", high, 3200, size=1024)


def _eye_front(o):
    """The way the eye looks (world): from its middle toward where its
    picture stands out from the rest of the ball (the iris and pupil) -
    each vertex weighted by how far its texel's colour is from the ball's
    usual one."""
    img = next(n.image for m in o.data.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.empty(w * h * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[..., :3]
    uv = o.data.uv_layers.active.data
    cols, pts = [], []
    for poly in o.data.polygons:
        for li in poly.loop_indices:
            u, v = uv[li].uv
            cols.append(px[min(h - 1, max(0, int(v * h))), min(w - 1, max(0, int(u * w)))])
            pts.append(o.matrix_world @ o.data.vertices[o.data.loops[li].vertex_index].co)
    cols = np.array(cols)
    weight = np.linalg.norm(cols - np.median(cols, 0), axis=1) ** 2
    lo, hi = bounds(o)
    c = Vector(((lo + hi) / 2).tolist())
    d = Vector((0, 0, 0))
    for p, k in zip(pts, weight):
        d += (p - c).normalized() * float(k)
    return d.normalized()


def _face_front(o, front):
    """Turns `o` (placed later) so the eye looks along +x, as the cartoon
    eyeball does."""
    rot = front.rotation_difference(Vector((1, 0, 0))).to_matrix()
    for v in o.data.vertices:
        v.co = rot @ Vector(v.co)


def net(src):
    """撈網 (round 8: carried to catch live bait): the user's net - its rim
    and handle, and its netting (a cloth sack worn as a wireframe in the
    file) as a sack whose mesh is a picture: alpha-cut squares, so it's
    light and still see-through."""
    fresh()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(src, "net.blend"))
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    rim = bpy.data.objects["Circle"]
    sack = bpy.data.objects["Sphere"]
    for m in list(sack.modifiers):
        if m.type == "WIREFRAME":
            sack.modifiers.remove(m)
    dg = bpy.context.evaluated_depsgraph_get()
    made = []
    for o in (rim, sack):
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
        n = bpy.data.objects.new(o.name + "_s", me)
        n.matrix_world = o.matrix_world
        bpy.context.scene.collection.objects.link(n)
        made.append(n)
    for o in (rim, sack):
        bpy.data.objects.remove(o, do_unlink=True)
    rim, sack = made
    # The netting picture: cord-coloured lines, clear between.
    size = 256
    cells = 12
    img = bpy.data.images.new("net_mesh", size, size, alpha=True)
    yy, xx = np.mgrid[0:size, 0:size]
    line = ((xx % (size // cells)) < 3) | ((yy % (size // cells)) < 3)
    px = np.zeros((size, size, 4), np.float32)
    px[line] = (0.78, 0.6, 0.18, 1.0)
    img.pixels.foreach_set(px.ravel())
    img.pack()
    nm = bpy.data.materials.new("netting")
    nm.use_nodes = True
    nt = nm.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    nt.links.new(t.outputs[0], b.inputs["Base Color"])
    nt.links.new(t.outputs[1], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = 0.8
    nm.blend_method = "CLIP"
    sack.data.materials.clear()
    sack.data.materials.append(nm)
    if not sack.data.uv_layers:
        sack.data.uv_layers.new(name="UV")
        bpy.ops.object.select_all(action="DESELECT")
        sack.select_set(True)
        bpy.context.view_layer.objects.active = sack
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.sphere_project()
        bpy.ops.object.mode_set(mode="OBJECT")
    # The rim and handle: the mirror-bright metal (it vanished
    # into whatever's behind it at this size) made a duller steel, the
    # grip kept dark.
    for m in rim.data.materials:
        bb = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
        if bb is not None and bb.inputs["Metallic"].default_value > 0.5:
            bb.inputs["Base Color"].default_value = (0.42, 0.44, 0.47, 1)
            bb.inputs["Metallic"].default_value = 0.6
            bb.inputs["Roughness"].default_value = 0.4
    # (the rim and handle kept whole: cut down, the thin shaft fell apart)
    # The file's net has a grip out past the rim but nothing joining them:
    # a steel shaft put in, from the rim's far edge to the grip.
    co = np.array([(rim.matrix_world @ v.co)[:] for v in rim.data.vertices])
    # (the grip is past the widest empty stretch along the handle's way)
    ys = np.sort(co[:, 1])
    gap = int(np.argmax(np.diff(ys)))
    cut = (ys[gap] + ys[gap + 1]) / 2
    grip = co[co[:, 1] > cut]
    ring = co[co[:, 1] <= cut]
    if len(grip) and ys[gap + 1] - ys[gap] > 0.2:
        g0 = Vector((grip[:, 0].mean(), grip[:, 1].min(), grip[:, 2].mean()))
        r0 = Vector((g0.x, ring[:, 1].max(), g0.z))
        rad = max(float(grip[:, 0].max() - grip[:, 0].min()) * 0.32, 0.012)
        bpy.ops.mesh.primitive_cylinder_add(radius=rad, depth=(g0 - r0).length + rad * 2, vertices=12,
                                            location=(g0 + r0) / 2)
        shaft = bpy.context.object
        shaft.rotation_euler = (g0 - r0).to_track_quat("Z", "Y").to_euler()
        steel = mat("steel", (0.42, 0.44, 0.47), metal=0.6, rough=0.4)
        shaft.data.materials.append(steel)
        bpy.ops.object.select_all(action="DESELECT")
        shaft.select_set(True)
        rim.select_set(True)
        bpy.context.view_layer.objects.active = rim
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.ops.object.join()
        rim = bpy.context.view_layer.objects.active
    have = sum(len(p.vertices) - 2 for p in sack.data.polygons)
    if have > 2000:
        d = sack.modifiers.new("dec", "DECIMATE")
        d.ratio = 2000 / have
        bpy.context.view_layer.objects.active = sack
        bpy.ops.object.modifier_apply(modifier="dec")
    # Laid along +x (handle to -x), NET_LENGTH long, at the origin.
    bpy.ops.object.select_all(action="DESELECT")
    rim.select_set(True)
    sack.select_set(True)
    bpy.context.view_layer.objects.active = rim
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = "net"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    place(o, (0, 0, 90), 0.5)
    for p in o.data.polygons:
        p.use_smooth = True
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "net.glb")
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_image_format="AUTO")
    print("net", sum(len(p.vertices) - 2 for p in o.data.polygons), "tris,", os.path.getsize(path) // 1024, "KB", flush=True)


def _loft(name, spine, widths, heights, ring=20, cap=True):
    """A shell lofted along `spine` (points) - an ellipse of widths[i] x
    heights[i] square to it at each point, its up kept toward +z."""
    import bmesh
    bm = bmesh.new()
    rings = []
    n = len(spine)
    up = Vector((0, 0, 1))
    for i in range(n):
        p = Vector(spine[i])
        t = (Vector(spine[min(i + 1, n - 1)]) - Vector(spine[max(i - 1, 0)])).normalized()
        side = t.cross(up).normalized()
        u = side.cross(t).normalized()
        rings.append([bm.verts.new(p + side * widths[i] * math.cos(a) + u * heights[i] * math.sin(a))
                      for a in np.linspace(0, math.tau, ring, endpoint=False)])
    for i in range(n - 1):
        for j in range(ring):
            k = (j + 1) % ring
            bm.faces.new((rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def _tube(name, pts, r0, r1, m, ring=8):
    o = _loft(name, pts, list(np.linspace(r0, r1, len(pts))), list(np.linspace(r0, r1, len(pts))), ring=ring)
    o.data.materials.append(m)
    return o


def shrimp(src=None):
    """活蝦, made here (user request, from the user's blockout: a carapace,
    six abdominal segments curling down, a tail fan): one lofted shell -
    the carapace, then the segments each a little swollen (their joints
    pinched), the telson - under a pointed rostrum; stalked black eyes;
    long antennae swept back over it and two short ones; five pairs of
    thin walking legs and the swimmerets under the abdomen; the tail fan's
    five blades. Greyish and see-through looking, freckled brown, the legs
    and feelers tinged orange, the fan's edges blue."""
    fresh()
    body = bpy.data.materials.new("shrimp_body")
    body.use_nodes = True
    nt = body.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 26.0
    noise.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    speck = _ramp(nt, noise.outputs["Fac"], [(0.0, (0.36, 0.4, 0.34)), (0.5, (0.3, 0.34, 0.29)), (0.6, (0.17, 0.13, 0.09)), (1.0, (0.13, 0.1, 0.07))])
    nt.links.new(speck, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.25
    leg = mat("shrimp_leg", (0.62, 0.34, 0.2), rough=0.35)
    fan = mat("shrimp_fan", (0.2, 0.34, 0.52), rough=0.3)
    black = mat("shrimp_eye", (0.02, 0.02, 0.02), rough=0.1)

    # The spine, head (+x) to tail: straight under the carapace, then
    # curling down through the abdomen.
    step = 0.01
    pts, ws, hs = [], [], []
    p = Vector((0.0, 0.0, 0.0))
    ang = 0.0
    d = 0.0
    segs = [0.44 + i * 0.08 for i in range(7)]
    while d <= 1.0:
        if d < 0.04:
            w = 0.03 + (d / 0.04) * 0.05
        elif d < 0.42:
            w = 0.08 + 0.04 * math.sin(min(1.0, (d - 0.04) / 0.2) * math.pi / 2)
        elif d < 0.92:
            w = 0.115 - (d - 0.42) / 0.5 * 0.07
            # each segment swells a little between its joints
            k = min(abs(d - s) for s in segs)
            w *= 0.93 + 0.07 * min(1.0, k / 0.035)
        else:
            w = 0.045 * (1.0 - (d - 0.92) / 0.08) + 0.006
        h = w * (1.18 if d < 0.92 else 0.5)
        pts.append(p.copy())
        ws.append(w)
        hs.append(h)
        if d > 0.42:
            ang += 1.35 * step / 0.5
        p += Vector((-math.cos(ang), 0.0, -math.sin(ang))) * step
        d += step
    shell = _loft("shell", pts, ws, hs, ring=28)
    shell.data.materials.append(body)
    objs = [shell]
    ix = lambda dd: min(len(pts) - 1, int(round(dd / step)))

    def at(dd, side=0.0, upw=0.0):
        i = ix(dd)
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = Vector((0, 1, 0)).cross(t).normalized() * -1.0
        if u.z < 0:
            u = -u
        return pts[i] + Vector((0, 1, 0)) * side * ws[i] + u * upw * hs[i], t, u

    # rostrum: a flattened spike forward and a little up from the head top
    base, _, _ = at(0.06, 0.0, 0.7)
    objs.append(_tube("rostrum", [base, base + Vector((0.12, 0, 0.02)), base + Vector((0.2, 0, 0.045))], 0.018, 0.002, body))
    # eyes on short stalks
    for s in (-1, 1):
        e0, _, _ = at(0.05, 0.75 * s, 0.25)
        e1 = e0 + Vector((0.03, 0.035 * s, 0.015))
        objs.append(_tube("stalk", [e0, e1], 0.012, 0.012, body))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.021, location=e1 + Vector((0.008, 0.006 * s, 0)), segments=16, ring_count=10)
        eye = bpy.context.object
        eye.data.materials.append(black)
        objs.append(eye)
    # long antennae swept back over the body, and two short antennules
    for s in (-1, 1):
        a0, _, _ = at(0.03, 0.5 * s, -0.2)
        ant = [a0] + [Vector((a0.x + 0.06 - 0.95 * t * t + 0.1 * t, a0.y + s * (0.05 + 0.28 * t), a0.z + 0.05 * math.sin(t * 2.4)))
                      for t in np.linspace(0.05, 1.0, 22)]
        objs.append(_tube("antenna", ant, 0.006, 0.0015, leg, ring=6))
        short = [a0 + Vector((0.12 * t, s * 0.05 * t, 0.04 * t * t)) for t in np.linspace(0, 1, 6)]
        objs.append(_tube("antennule", short, 0.006, 0.002, leg, ring=6))
    # walking legs under the carapace, and the swimmerets under the abdomen
    for k, dd in enumerate(np.linspace(0.14, 0.36, 5)):
        for s in (-1, 1):
            l0, t, u = at(dd, 0.55 * s, -0.75)
            knee = l0 + Vector((0.02, s * 0.06, -0.06))
            foot = knee + Vector((0.03 - 0.012 * k, s * 0.03, -0.09))
            objs.append(_tube("leg", [l0, knee, foot], 0.007, 0.003, leg, ring=6))
    for dd in segs[:5]:
        for s in (-1, 1):
            l0, t, u = at(dd + 0.03, 0.45 * s, -0.8)
            tip = l0 - u * 0.07 + Vector((0, s * 0.012, 0)) - t * 0.02
            objs.append(_tube("swimmeret", [l0, tip], 0.008, 0.004, leg, ring=6))
    # the tail fan: the telson and two uropods each side, splayed
    end, t, u = at(0.98)
    side = Vector((0, 1, 0))
    for spread, ln, wd in ((0.0, 0.19, 0.035), (0.4, 0.18, 0.04), (-0.4, 0.18, 0.04), (0.75, 0.15, 0.036), (-0.75, 0.15, 0.036)):
        dirv = (t * math.cos(spread) + side * math.sin(spread)).normalized()
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=16, ring_count=8, location=end + dirv * ln * 0.5)
        blade = bpy.context.object
        blade.scale = (ln * 0.5, wd, 0.006)
        blade.rotation_euler = dirv.to_track_quat("X", "Z").to_euler()
        blade.data.materials.append(fan)
        objs.append(blade)
    high = solid(objs)
    place(high, (0, 0, 0), 0.1, base=True)
    bake("shrimp", high, 3200, reach=0.08)


CRITTERS = os.path.join(ROOT, "art_src", "critter")


def _critter(name, glb, clip, frame, turn, length, tris, reach=0.05):
    """Round 8 (user request: what's caught on the map goes in the bag as a
    live bait): the critter's own model (art_src/critter, rigged) posed at
    `frame` of its `clip` and set down as a still - the bait's model in the
    menus and its icon."""
    fresh()
    bpy.ops.import_scene.gltf(filepath=os.path.join(CRITTERS, glb))
    arm = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    act = next((a for a in bpy.data.actions if clip and clip in a.name), None)
    if arm is not None and act is not None:
        arm.animation_data_create()
        for t in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(t)
        arm.animation_data.action = act
        bpy.context.scene.frame_set(frame)
    # (the packs' "Icosphere" is a hidden ground marker)
    objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("Icosphere")]
    # Fur, scales and chitin: matt (the packs' glossy setting washed the
    # dark ones out grey under the icons' lights).
    for o in objs:
        for m in o.data.materials:
            b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
            if b is not None and not b.inputs["Roughness"].is_linked:
                b.inputs["Roughness"].default_value = max(b.inputs["Roughness"].default_value, 0.85)
    high = solid(objs)
    # glTF keeps every face's corners apart (split along its seams): welded
    # back up, or cutting it down shreds it.
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=float(max(high.dimensions)) * 1e-4)
    bpy.ops.object.mode_set(mode="OBJECT")
    place(high, turn, length, base=True)
    bake(name, high, tris, reach=reach)


def rat(src):
    """老鼠 (big bait, only caught on the map)."""
    _critter("rat", "rat.glb", "Rat_Idle", 4, (0, 0, -90), 0.14, 2400)


def snake(src):
    """蛇 (big bait, only caught on the map): curled mid-slither."""
    _critter("snake", "snake.glb", "Snake_Walk", 3, (0, 0, -90), 0.16, 2400)


def crab(src):
    """螃蟹 (big bait, the beach's)."""
    _critter("crab", "crab.glb", "Crab_Idle", 1, (0, 0, 0), 0.1, 2400)


def bee(src):
    """蜜蜂 (round 8: the bug-bait one that may sting)."""
    _critter("bee", "wasp.glb", "Wasp_Flying", 2, (0, 0, -90), 0.08, 2000)


def black_spider(src):
    """黑蜘蛛 (the bait that may bite): its first colouring."""
    _critter("black_spider", "black_spider.glb", "", 0, (0, 0, -90), 0.1, 2400)


SOURCES = {"frog": frog, "spider": spider, "knife": knife, "machete": machete, "hatchet": hatchet,
           "glock": glock, "ammo": ammo, "battery": battery, "loaf": loaf, "flashlight": flashlight, "cup": cup, "cheese": cheese, "roll": roll,
           "worm": worm, "grasshopper": grasshopper, "minnow": minnow, "binoculars": binoculars, "potion_ward": potion_ward,
           "potion_vigor": potion_vigor, "eyeball": eyeball, "shrimp": shrimp,
           "eye_altar": eye_altar, "eye_ghost": eye_ghost, "net": net,
           "rat": rat, "snake": snake, "crab": crab, "bee": bee, "black_spider": black_spider}


def main():
    args = sys.argv[1:]
    src = args[0]
    for name in args[1:] or list(SOURCES):
        SOURCES[name](src)


if __name__ == "__main__":
    main()
