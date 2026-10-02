"""The desert's bones (user request: the animal carcasses as a new map, a
desert of bones). The user's AnimalCarcuss.blend holds five skeletons -
deer, buffalo, crocodile, wild cat and elephant - 30k to 350k triangles
each with 2K textures per bone group. Each is cut down and baked to one
small texture (tools/prep_shop_models.py's bake) and saved as
art_src/packs/bones/<name>.glb, for tools/render_packs.py to render into
rock-like props (family "bones").

  bpyenv/bin/python tools/prep_bones.py AnimalCarcuss.blend   (repo root)

The pack stays out of the repo.
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prep_shop_models as ps  # noqa: E402

OUT = os.path.join(ps.ROOT, "art_src", "packs", "bones")
# name: (material prefix, triangles kept, texture size, turn)
ANIMALS = {
    "deer": ("Deer", 6000, 512, (0, 0, 0)),
    "buffalo": ("Buffelo", 6000, 512, (0, 0, 0)),
    "crocodile": ("Crocodile", 6000, 512, (0, 0, 0)),
    # Lies on its side, upright, in the pack: laid down.
    "wildcat": ("WildCat", 4500, 512, (0, 90, 0)),
    "elephant": ("Elephant", 9000, 512, (0, 0, 0)),
}


def main():
    src = sys.argv[-1]
    for name, (prefix, tris, size, turn) in ANIMALS.items():
        bpy.ops.wm.open_mainfile(filepath=src)
        parts = [o for o in bpy.data.objects if o.type == "MESH" and o.data.materials
                 and o.data.materials[0] is not None
                 and o.data.materials[0].name.lower().startswith(prefix.lower())]
        # (The buffalo's one mesh is under "WildBuffelo"; its other
        # materials share the "Buffelo" names.)
        if prefix == "Buffelo":
            parts = [o for o in bpy.data.objects if o.type == "MESH" and any(
                m is not None and "buffelo" in m.name.lower() for m in o.data.materials)]
        high = ps.solid(parts)
        ps.place(high, turn, 1.0, base=True)
        # Ribs and thin bones cut down leave gaps: look further for them.
        ps.bake(name, high, tris, size, OUT, reach=0.12)


if __name__ == "__main__":
    main()
