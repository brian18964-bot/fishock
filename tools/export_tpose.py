"""A Meshy character's finished body out of the game's model, at rest (its T
pose), with its pictures and without its skeleton - for an auto-rig of it
(Mixamo; user request) to come back as its config's `mixamo_final`
(tools/meshy_characters.py).

  bpyenv/bin/python tools/export_tpose.py -- assets/models/characters/ID.glb OUT_DIR ID
"""
import os
import sys

import bpy

a=sys.argv[sys.argv.index("--")+1:]
src, out_dir, cid = a[0], a[1], a[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
if arm.animation_data:
    arm.animation_data.action=None
    for t in arm.animation_data.nla_tracks: t.mute=True
for pb in arm.pose.bones: pb.matrix_basis.identity()
bpy.context.view_layer.update()
meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials]
keep=meshes[0]
for o in list(bpy.data.objects):
    if o.type=='MESH' and o is not keep:
        bpy.data.objects.remove(o, do_unlink=True)
mw=keep.matrix_world.copy()
for m in list(keep.modifiers):
    keep.modifiers.remove(m)
keep.parent=None; keep.matrix_world=mw
keep.vertex_groups.clear()
bpy.data.objects.remove(arm, do_unlink=True)
for o in list(bpy.data.objects):
    if o is not keep: bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active=keep; keep.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
keep.name=cid
# pictures out to files beside the fbx, then embedded
tex=os.path.join(out_dir, cid+"_textures"); os.makedirs(tex, exist_ok=True)
for img in bpy.data.images:
    if img.size[0]==0: continue
    ext = "png" if img.file_format=="PNG" else "jpg"
    p=os.path.join(tex, "%s_%s.%s"%(cid, img.name.replace(".","_"), ext))
    img.filepath_raw=p; img.file_format="PNG" if ext=="png" else "JPEG"; img.save()
dims=keep.dimensions
print("EXPORT", cid, "verts", len(keep.data.vertices), "tris", sum(len(p.vertices)-2 for p in keep.data.polygons), "dims", tuple(round(x,2) for x in dims))
bpy.ops.export_scene.fbx(filepath=os.path.join(out_dir, cid+"_tpose.fbx"), use_selection=True, object_types={'MESH'},
                         path_mode='COPY', embed_textures=True, add_leaf_bones=False, bake_anim=False)
os._exit(0)
