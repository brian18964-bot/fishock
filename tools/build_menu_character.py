"""The camp's character, assets/models/menu_character.glb: Quaternius'
Universal Animation Library mannequin (CC0 - the libraries kept out of
the repo, like the other source models) with the clips the menus play.
UAL1 and UAL2 share the mannequin's skeleton, so their clips go onto it
as they are: breathing and waving (the equipment page, a tap), and the
camp's life (user request, Camp v2: the character rests at the camp on
its own - walks about, sits by the fire, mends things... - less and less
of it as the spirit runs low; see CampLife). Carrying, chopping and
harvesting are left out (user request: the hands didn't close on what
they held).

The one wearing them is the player's character (owl_character.player, put
on the mannequin's skeleton: the beginner owl person, or PLAYER=<animal>
GREYBOX_DIR=<build> a greybox one); MANNEQUIN=1 keeps the mannequin instead.

  UAL1=<UAL1_Standard.glb> UAL2=<UAL2_Standard.glb> \\
      bpyenv/bin/python tools/build_menu_character.py      (repo root)
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import owl_character  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# (OUT=<path>: elsewhere - a try-out of another character)
OUT = os.environ.get("OUT") or os.path.join(ROOT, "assets", "models", "menu_character.glb")

# The clips kept, by library.
UAL1 = [
    "Idle_Loop", "Idle_Talking_Loop", "Interact", "Walk_Loop",
    "Sitting_Enter", "Sitting_Idle_Loop", "Sitting_Exit", "Sitting_Talking_Loop",
    "Crouch_Idle_Loop", "Idle_Torch_Loop", "Fixing_Kneeling", "PickUp_Table", "Dance_Loop",
]
UAL2 = [
    "Idle_FoldArms_Loop", "Idle_Rail_Loop", "Chest_Open", "Consume", "Yes", "Idle_No_Loop", "LayToIdle",
]


def clip_name(action, armature):
    # The glTF importer names them "<clip>" or "<clip>_<armature>".
    name = action.name.split("|")[-1]
    return name[:-len(armature) - 1] if name.endswith("_" + armature) else name


def load(path):
    """Imports a library; returns its armature, its other objects, and its
    actions by clip name."""
    before_obj = set(bpy.data.objects)
    before_act = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=path)
    new = set(bpy.data.objects) - before_obj
    arm = next(o for o in new if o.type == "ARMATURE")
    acts = {clip_name(a, arm.name): a for a in set(bpy.data.actions) - before_act}
    return arm, [o for o in new if o is not arm], acts


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    arm, body, acts1 = load(os.environ["UAL1"])
    arm2, body2, acts2 = load(os.environ["UAL2"])
    keep = {}
    for names, acts in ((UAL1, acts1), (UAL2, acts2)):
        for n in names:
            if n not in acts:
                raise SystemExit("no clip %r" % n)
            keep[n] = acts[n]
    # The second library's mannequin goes; its clips stay.
    for o in [arm2] + body2:
        bpy.data.objects.remove(o, do_unlink=True)
    if os.environ.get("MANNEQUIN") != "1":
        for o in body:
            bpy.data.objects.remove(o, do_unlink=True)
        body = owl_character.player(arm, "ual", list(keep.values()),
                                    standing=[a for n, a in keep.items() if n.startswith("Idle")])
    for a in list(bpy.data.actions):
        if a not in keep.values():
            bpy.data.actions.remove(a)
    # Each clip on its own NLA track (exported one animation per track).
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    for n, a in keep.items():
        a.use_fake_user = True
        track = ad.nla_tracks.new()
        track.name = n
        strip = track.strips.new(n, int(a.frame_range[0]), a)
        strip.name = n
        track.mute = True
    bpy.ops.object.select_all(action="DESELECT")
    for o in [arm] + body:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
                              export_anim_single_armature=True, export_def_bones=False,
                              export_vertex_color="NONE")
    print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB,", len(keep), "clips")


if __name__ == "__main__":
    main()
