"""The finch (bird-man) character in a beginner's plain clothes.

User request: the finch from the asset release (finch_character.blend with
finch_textures.zip) is a future playable character; it should start in the
simplest beginner's outfit, the full set to be earned later. This keeps
its body (head, eyes, hands, feet), its shirt and trousers - recoloured to
plain undyed cloth, the weave and wear kept - and takes everything else
off: the cap and its papers, the vest and its patches, the collar, the
satchel, the belt, the jacket buttons, the patches, the plaster.
The pieces taken off are left in the source file as the earnable outfit.

    blender -b --python tools/build_finch_beginner.py -- SRC.blend OUT.blend [PREVIEW.png]

The textures are UDIM sets the .blend expects at
//../character_61_textures/<set>/ (unzip finch_textures.zip there).
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
PREVIEW = args[2] if len(args) > 2 else ""

# What the beginner doesn't have yet (the rest of the set, to be earned).
OFF = [
    "finch_hat", "finch_hat_papers", "finch_patch_hat",
    "finch_vest_base", "finch_patch_vest_1", "finch_patch_vest_2", "finch_collar",
    "finch_button_jackett_1", "finch_button_jackett_2", "finch_button_jackett_3",
    "finch_bag", "finch_belt",
    "finch_patch_jumper_1", "finch_patch_jumper_2", "finch_patch_trousers_1", "finch_patch_trousers_2",
    "finch_plaster_head",
]
# Plain undyed cloth: a linen shirt, brown trousers.
SHIRT = (0.78, 0.70, 0.56, 1.0)
TROUSERS = (0.36, 0.27, 0.19, 1.0)


def plain(obj_name, tint, mat_name):
    """The piece's cloth with its colour taken out and `tint` put in."""
    o = bpy.data.objects[obj_name]
    m = o.data.materials[0].copy()
    m.name = mat_name
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and "BaseColor" in n.image.name)
    grey = nt.nodes.new("ShaderNodeHueSaturation")
    grey.inputs["Saturation"].default_value = 0.0
    nt.links.new(tex.outputs["Color"], grey.inputs["Color"])
    lift = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(grey.outputs[0], lift.inputs[0])
    lift.inputs[1].default_value, lift.inputs[2].default_value = 0.0, 0.6
    lift.inputs[3].default_value, lift.inputs[4].default_value = 0.55, 1.0
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type, mix.blend_type = "RGBA", "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    nt.links.new(lift.outputs[0], mix.inputs[6])
    mix.inputs[7].default_value = tint
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    for name in ("Sheen Tint", "Specular Tint"):
        for link in list(bsdf.inputs[name].links):
            nt.links.remove(link)
        bsdf.inputs[name].default_value = tint
    o.data.materials[0] = m


bpy.ops.wm.open_mainfile(filepath=SRC)
for name in OFF:
    if name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
plain("finch_jumper", SHIRT, "beginner_shirt")
plain("finch_trousers", TROUSERS, "beginner_trousers")
bpy.ops.wm.save_as_mainfile(filepath=OUT, copy=True)

if PREVIEW:
    sc = bpy.context.scene
    for o in sc.objects:
        for md in o.modifiers:
            if md.type == "PARTICLE_SYSTEM":
                md.show_render = False
    sc.camera = bpy.data.objects["Camera_80mm_body_front"]
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.resolution_x, sc.render.resolution_y = 540, 720
    sc.render.filepath = PREVIEW
    # The source's compositor writes renders to its author's own folders.
    sc.use_nodes = False
    bpy.ops.render.render(write_still=True)
