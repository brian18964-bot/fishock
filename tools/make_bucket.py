"""The fish bucket (魚桶 - the user's bucket.fbx with its PBR textures): the
galvanised pail with its bail, all its parts joined into one mesh, the 4K
textures cut to 1024 (all JPEG) and the rust toned down a little so it sits in the
camp's cold night. Base on the ground at the origin, 0.27 m wide.

  bpyenv/bin/python tools/make_bucket.py -- DIR   (DIR holds bucket.fbx and PBR/*.png; repo root)

Writes assets/models/items/fish_bucket.glb. The user's files stay out of the repo.
"""
import os
import sys

import bpy
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "models", "items", "fish_bucket.glb")
SIZE = 1024


def load_small(path, name, non_color):
    img = bpy.data.images.load(path)
    img.scale(SIZE, SIZE)
    return img


def resaved(img, name, non_color, jpeg=False):
    """`img` written out small and loaded back, so the exporter sees the small
    file (not the 4K one it came from)."""
    path = "/tmp/%s.%s" % (name, "jpg" if jpeg else "png")
    img.filepath_raw = path
    img.file_format = "JPEG" if jpeg else "PNG"
    img.save()
    out = bpy.data.images.load(path)
    out.name = name
    out.pack()
    if non_color:
        out.colorspace_settings.name = "Non-Color"
    return out


def main():
    src = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(src, "bucket.fbx"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
        # (the file's own transforms baked in)
    bpy.context.view_layer.objects.active = meshes[0]
    # (out from under the file's scaled empty, its size kept)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    bucket = bpy.context.view_layer.objects.active
    bucket.name = "fish_bucket"

    # The rust, a little cooler and paler (the base colour, in numpy).
    base = load_small(os.path.join(src, "PBR", "M_Bucket_BaseColor.png"), "bucket_base", False)
    px = np.array(base.pixels[:], dtype=np.float32).reshape(SIZE, SIZE, 4)
    grey = px[..., :3].mean(axis=2, keepdims=True)
    px[..., :3] = np.clip(px[..., :3] * 0.55 + grey * 0.45, 0, 1)
    px[..., 2] = np.clip(px[..., 2] * 1.08 + 0.02, 0, 1)
    base.pixels[:] = px.reshape(-1)
    base.update()
    base = resaved(base, "bucket_base", False, True)
    rough = load_small(os.path.join(src, "PBR", "M_Bucket_Roughness.png"), "bucket_rough", True)
    metal = load_small(os.path.join(src, "PBR", "M_Bucket_Metallic.png"), "bucket_metal", True)
    normal = load_small(os.path.join(src, "PBR", "M_Bucket_Normal.png"), "bucket_normal", True)
    rough = resaved(rough, "bucket_rough", True, True)
    metal = resaved(metal, "bucket_metal", True, True)
    normal = resaved(normal, "bucket_normal", True, True)

    mat = bpy.data.materials.new("fish_bucket")
    mat.use_nodes = True
    nt = mat.node_tree
    b = next(x for x in nt.nodes if x.type == "BSDF_PRINCIPLED")

    def tex(img, y):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        n.location = (-500, y)
        return n

    nt.links.new(tex(base, 300).outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex(rough, 0).outputs["Color"], b.inputs["Roughness"])
    nt.links.new(tex(metal, -300).outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(normal, -600).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    bucket.data.materials.clear()
    bucket.data.materials.append(mat)

    # Base on the ground, centred.
    vs = [v.co.copy() for v in bucket.data.vertices]
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    z0 = min(v.z for v in vs)
    # (0.27 wide)
    k = 0.27 / (max(v.x for v in vs) - min(v.x for v in vs))
    for v in bucket.data.vertices:
        v.co.x = (v.co.x - cx) * k
        v.co.y = (v.co.y - cy) * k
        v.co.z = (v.co.z - z0) * k
    print("size", 0.27, (max(v.z for v in vs) - z0) * k, "tris", sum(len(p.vertices) - 2 for p in bucket.data.polygons))
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_apply=True,
                              export_image_format="AUTO", export_jpeg_quality=85)
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
    os._exit(0)


if __name__ == "__main__":
    main()
