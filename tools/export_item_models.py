"""3D models of the things sold and carried, for the menus' 3D previews
(user request: out of the game, show things in 3D - the shop's wares, the
equipment). The flashlight, battery, cricket, shrimp and tea were
built here by render_item_icons.py's own builders (the same shapes as their
pictures) and saved as .glb; the lures and the worm are copied from art_src (the models
their sprites were rendered from).

  bpyenv/bin/python tools/export_item_models.py [builder ...]   (repo root)

Writes assets/models/items/*.glb.
"""
import os
import shutil
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_item_icons as ri  # noqa: E402

OUT = os.path.join(ri.ROOT, "assets", "models", "items")


def export(name, objs, cells):
    """Stands in for render_item_icons.shoot: saves the built thing."""
    os.makedirs(OUT, exist_ok=True)
    for o in list(bpy.data.objects):
        if o.type == "CURVE":
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.convert(target="MESH")
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("MESH", "EMPTY"):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              use_selection=True, export_apply=True)
    print("exported", name)


def main():
    ri.shoot = export
    only = sys.argv[1:]
    if only:
        for name in only:
            getattr(ri, name)()
        return
    # (The flashlight, its battery and the tea's cup are the user's models
    # now - tools/prep_shop_models.py.)
    # (User request, round 7: the cricket, the shrimp and the worm are the
    # user's models and one made by hand now - tools/prep_shop_models.py -
    # and the rations are off the menu.)
    src = os.path.join(ri.ROOT, "art_src", "lure")
    for n in ["lure_%d" % i for i in range(1, 7)]:
        shutil.copy(os.path.join(src, n + ".glb"), os.path.join(OUT, n + ".glb"))
        print("copied", n)


if __name__ == "__main__":
    main()
