"""Every fish species as a light 3D model, for the menus (user request: out
of the game, show everything in 3D that can be - the fish tank, the fish
log). Each fish is built by render_fish.py (the same body, fins, eyes and
painted skin as its picture), a little lighter; its procedural skin is
baked into a small picture; the parts are joined into one mesh and saved:

  assets/models/fish/<id>.glb   the mesh (head toward +x, back up, 1 long)
  assets/models/fish/<id>.png   its skin (the mesh's UVs)

The game dresses the mesh with the skin itself (FishModel), so the skin is
imported like any picture (lossy) and the .glb carries no material.

  bpyenv/bin/python tools/export_fish_models.py [id ...]     (repo root)
"""
import math
import os
import sys
import tempfile

import bpy
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_fish as rf  # noqa: E402

OUT = os.path.join(rf.ROOT, "assets", "models", "fish")
BAKE = 512
SKIN = 256
# The loft of the body: fewer rings and sides than the pictures', plenty
# for a fish turning in a tank.
rf.RINGS = 30
rf.SEGMENTS = 14
# Small round parts (eyes, the crayfish's shell) are built as fine spheres;
# no part but the body needs more vertices than this.
MAX_PART_VERTS = 90


def lighten(objs):
    """Decimates the fine spheres down to MAX_PART_VERTS."""
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if o.name.startswith("body") or o.name.startswith("head2"):
            continue
        n = len(o.data.vertices)
        if n <= MAX_PART_VERTS:
            continue
        m = o.modifiers.new("lighten", 'DECIMATE')
        m.ratio = MAX_PART_VERTS / n
        deps.update()
        light = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
        o.modifiers.remove(m)
        old = o.data
        o.data = light
        bpy.data.meshes.remove(old)


def select(objs, active):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def unwrap(objs):
    """One UV layout for all the parts together."""
    select(objs, objs[0])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode='OBJECT')


def bake_skin(fid, objs):
    """The parts' own (procedural) colours into one picture, by the UVs."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 6
    scene.render.bake.margin = 8
    img = bpy.data.images.new(fid + "_skin", BAKE, BAKE, alpha=False)
    mats = []
    for o in objs:
        for slot in o.material_slots:
            if slot.material is not None and slot.material not in mats:
                mats.append(slot.material)
    for mat in mats:
        nt = mat.node_tree
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = img
        nt.nodes.active = tex
    select(objs, objs[0])
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True)
    tmp = os.path.join(tempfile.gettempdir(), fid + "_bake.png")
    img.filepath_raw = tmp
    img.file_format = 'PNG'
    img.save()
    Image.open(tmp).convert("RGB").resize((SKIN, SKIN), Image.LANCZOS).save(os.path.join(OUT, fid + ".png"), optimize=True)
    os.remove(tmp)


def export(fid, sp):
    objs, flat = rf.make(fid, sp)
    if flat:
        # make() lays a flatfish down for the picture; the model stays upright
        # (the game lays it down).
        for o in objs:
            o.rotation_euler.x -= math.pi / 2
    objs = [o for o in objs if o.type == 'MESH']
    bpy.context.view_layer.update()
    lighten(objs)
    unwrap(objs)
    bake_skin(fid, objs)
    # One mesh, no material (FishModel dresses it).
    for o in objs:
        o.data.materials.clear()
    body = next((o for o in objs if o.name.startswith("body")), objs[0])
    select(objs, body)
    bpy.ops.object.join()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    body.name = fid
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, fid + ".glb"), export_format='GLB',
                              use_selection=True, export_apply=True, export_materials='NONE',
                              export_texcoords=True, export_normals=True, export_yup=True)
    print("exported", fid, len(body.data.vertices), "verts", flush=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    species = rf.read_species()
    want = sys.argv[1:] or list(species)
    for fid in want:
        export(fid, species[fid])


if __name__ == "__main__":
    main()
