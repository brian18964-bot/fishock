"""First colour and material trials on the greybox animal people (user
request, round 3: base colours and materials may start, the shapes are
not final - nothing is baked, nothing goes in the game, and the grey
stays beside every colour picture so the colour can't hide a fault).

Each material zone (greybox_animals.ZONES) gets a flat colour and a
plain surface (rough fur, matt knit and cotton, glossy eyes and nose);
no textures. Rendered with the review pictures' camera and lights
(greybox_review.stage), the same four turns, and in the display pose.

    bpyenv/bin/python tools/greybox_colour.py -- views ANIMAL GB_DIR OUT_DIR
    bpyenv/bin/python tools/greybox_colour.py -- display ANIMAL GB_DIR OUT_DIR UAL1.glb UAL2.glb
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import greybox_review as gr  # noqa: E402

# By zone (fur, skin, horn, eye, knit, cloth, button, scarf, pad):
# (colour, roughness, sheen). The clothes the same on all four: the
# beginner's cream jumper, khaki shorts, wooden button.
COMMON = {"knit": ((0.80, 0.75, 0.62), 0.92, 0.35), "cloth": ((0.47, 0.41, 0.27), 0.85, 0.15),
          "button": ((0.33, 0.21, 0.11), 0.55, 0.0), "eye": ((0.025, 0.02, 0.018), 0.08, 0.0)}
PALETTES = {
    # a brown horned owl: warm brown, a buff face would come with texture
    "owl": {"fur": ((0.36, 0.26, 0.17), 0.85, 0.25), "skin": ((0.30, 0.26, 0.20), 0.6, 0.0),
            "horn": ((0.30, 0.27, 0.22), 0.45, 0.0), "pad": ((0.42, 0.36, 0.24), 0.7, 0.0),
            "eye": ((0.62, 0.36, 0.04), 0.08, 0.0), "scarf": ((0.80, 0.75, 0.62), 0.9, 0.3)},
    # a tan shepherd-type dog with a red neckerchief
    "dog": {"fur": ((0.60, 0.40, 0.21), 0.85, 0.25), "skin": ((0.06, 0.05, 0.05), 0.35, 0.0),
            "horn": ((0.20, 0.17, 0.14), 0.45, 0.0), "pad": ((0.10, 0.08, 0.08), 0.6, 0.0),
            "scarf": ((0.55, 0.10, 0.08), 0.8, 0.2)},
    # a black cat: near black, its eyes amber so they read on it
    "cat": {"fur": ((0.022, 0.020, 0.022), 0.75, 0.10), "skin": ((0.22, 0.12, 0.13), 0.4, 0.0),
            "horn": ((0.60, 0.57, 0.52), 0.45, 0.0), "pad": ((0.18, 0.10, 0.11), 0.6, 0.0),
            "eye": ((0.62, 0.52, 0.08), 0.08, 0.0)},
    # a brown bear: dark brown, ivory claws
    "bear": {"fur": ((0.27, 0.17, 0.10), 0.88, 0.25), "skin": ((0.05, 0.04, 0.04), 0.4, 0.0),
             "horn": ((0.70, 0.64, 0.54), 0.45, 0.0), "pad": ((0.08, 0.06, 0.06), 0.6, 0.0)},
}
ZONE_NAMES = ["fur", "skin", "horn", "eye", "knit", "cloth", "button", "scarf", "pad"]


def materials(animal):
    pal = dict(COMMON)
    pal.update(PALETTES[animal])
    out = []
    for z in ZONE_NAMES:
        rgb, rough, sheen = pal.get(z, ((0.5, 0.5, 0.5), 0.6, 0.0))
        m = bpy.data.materials.new("col_" + z)
        m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        # (the colours above are as seen - sRGB; Blender's are linear)
        b.inputs["Base Color"].default_value = (*(c ** 2.2 for c in rgb), 1.0)
        b.inputs["Roughness"].default_value = rough
        for name, v in (("Sheen Weight", sheen), ("Sheen Roughness", 0.6)):
            if name in b.inputs:
                b.inputs[name].default_value = v
        if z == "eye" and "Coat Weight" in b.inputs:
            b.inputs["Coat Weight"].default_value = 1.0
        out.append(m)
    return out


def recolour(objs, animal):
    mats = materials(animal)
    for o in objs:
        if o.type != "MESH":
            continue
        for i, slot in enumerate(o.material_slots):
            name = slot.material.name.split(".")[0] if slot.material else ""
            z = name[3:] if name.startswith("gb_") else None
            if z in ZONE_NAMES:
                o.material_slots[i].material = mats[ZONE_NAMES.index(z)]


def views(animal, gb_dir, out):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(gb_dir, animal + ".blend"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    recolour(meshes, animal)
    piv = gr.pivot_all(meshes)
    gr.stage()
    for v in gr.VIEWS:
        gr.shoot(os.path.join(out, "%s_colour_%s.png" % (animal, v)), piv, v)


def display(animal, gb_dir, out, ual1, ual2):
    arm, acts, mesh, files = gr.bound(animal, gb_dir, ual1, ual2)
    name, f, draw_in, tweaks = gr.DISPLAY[animal]
    act = acts[name]
    if draw_in:
        gr.oc.close_stance(arm, "ual", [act], standing=[act], character=animal, files=files)
    f0, f1 = act.frame_range
    gr.clip(arm, act, int(round(f0 + (f1 - f0) * f)))
    for bone, axis, deg in tweaks:
        gr.turn(arm, bone, axis, deg)
    recolour([mesh], animal)
    piv = gr.pivot_rig(arm)
    gr.stage()
    for v in ("front", "three"):
        gr.shoot(os.path.join(out, "%s_colour_display_%s.png" % (animal, v)), piv, v)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    os.makedirs(args[3], exist_ok=True)
    if args[0] == "views":
        views(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]))
    elif args[0] == "display":
        display(args[1], os.path.abspath(args[2]), os.path.abspath(args[3]), args[4], args[5])
    sys.stdout.flush()
    os._exit(0)
