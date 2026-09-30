"""The placeholder fish (render_fish.py) as Blender files, one per species,
to be refined by hand: each fish's parts (body, fins, tail, eyes...) with
their procedural materials, under an empty named "<id> <name>", in a scene
lit and framed as the icons are (render_fish.stage) - render it (F12) to
get the same view as the game's picture.

  bpyenv/bin/python tools/export_fish_blend.py OUT_DIR [id...]
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_fish as rf  # noqa: E402


def main():
    out = os.path.abspath(sys.argv[1])
    os.makedirs(out, exist_ok=True)
    species = rf.read_species()
    want = sys.argv[2:] or list(species)
    for fid in want:
        sp = species[fid]
        objs, flat = rf.make(fid, sp)
        root = bpy.data.objects.new("%s %s" % (fid, sp.get("name", "")), None)
        bpy.context.scene.collection.objects.link(root)
        for o in objs:
            if o.parent is None:
                o.parent = root
        rf.stage(objs, flat)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, fid + ".blend"), compress=True)
        print("saved", fid, flush=True)


if __name__ == "__main__":
    main()
