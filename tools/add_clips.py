"""More of the user's Mixamo clips put into the finished characters
(assets/models/characters/<id>.glb), without building them again (user
request: gathering, for the glow mushroom; digging, for later). For each
character: its model in, each clip carried onto its own skeleton
(kaykit.bake, as tools/build_menu_character.py carries MIXAMO), its body's
lowest point put on the ground frame by frame (build_menu_character
.ground_on_body - both are down at the ground), written out on the
skeleton alone and its animations added into the model (every character's
skeleton has the same bones; the bones' turns and the root's move - a
clip already there of the name is replaced). The model's own meshes, skin and other clips stay as they
were.

  MOVES_DIR=<dir> bpyenv/bin/python tools/add_clips.py -- id [id ...]   (repo root)

MOVES_DIR holds the clips (Y Bot, 30 fps; kept out of the repo) by the
names in CLIPS.
"""
import os
import sys
import tempfile

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_menu_character as bmc  # noqa: E402
import kaykit  # noqa: E402
from touch_up_characters import Glb  # noqa: E402

ROOT = bmc.ROOT
CHARACTERS = os.path.join(ROOT, "assets", "models", "characters")
# The name it's played by ("_Loop": loops), the file, the source frames
# (None: all).
CLIPS = [
    # (down, gathering, up again - not the standing about after)
    ("Gathering", "Gathering_Objects.fbx", (1, 135)),
    ("Digging_Loop", "Digging.fbx", None),
]


def bake(path, out):
    """The character at `path` with CLIPS on its skeleton; the skeleton and
    the new clips alone written to `out`."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = int(kaykit.FPS)
    arm, body, _acts = bmc.load(path)
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    folder = os.environ["MOVES_DIR"]
    made = {}
    for name, fbx, span in CLIPS:
        lib = kaykit.load_mixamo(os.path.join(folder, fbx), "mx_" + name)
        src = bpy.data.actions["mx_" + name]
        s, e = span or src.frame_range
        step = bmc.MIXAMO_STEP if e - s >= 8 else 1
        act = kaykit.bake(arm, lib, "mx_" + name, name=name, lift=0.0, rig="mixamo", span=(s, e), step=step)
        if step > 1:
            for fc in act.fcurves:
                for kp in fc.keyframe_points:
                    for p in (kp.co, kp.handle_left, kp.handle_right):
                        p.x = 1.0 + (p.x - 1.0) * step
        for o in [lib] + list(lib.children):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.actions.remove(src)
        bmc.ground_on_body(arm, body, act)
        made[name] = act
    for a in list(bpy.data.actions):
        if a not in made.values():
            bpy.data.actions.remove(a)
    ad.action = None
    for n, a in made.items():
        a.use_fake_user = True
        track = ad.nla_tracks.new()
        track.name = n
        strip = track.strips.new(n, int(a.frame_range[0]), a)
        strip.name = n
        track.mute = True
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_animation_mode="NLA_TRACKS", export_optimize_animation_size=True,
                              export_anim_single_armature=True, export_def_bones=False, export_skins=False)
    return list(made)


def _q_mul(a, b):
    x1, y1, z1, w1 = a.T
    x2, y2, z2, w2 = b.T
    return np.stack([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2, w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2, w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2], -1)


def merge(model_path, clips_path, names):
    """The animations `names` of the skeleton at `clips_path` added into
    the model (each channel to the model's node of the same name; its
    turns and moves taken from the skeleton's rest onto the model's, should
    they differ)."""
    g, c = Glb(model_path), Glb(clips_path)
    nodes = {n.get("name"): i for i, n in enumerate(g.j["nodes"])}
    g.j["animations"] = [a for a in g.j.get("animations", []) if a["name"] not in names]
    views, accessors = g.j["bufferViews"], g.j["accessors"]

    def add(arr, like):
        a = dict(c.j["accessors"][like])
        raw = np.ascontiguousarray(arr.astype(np.float32)).tobytes()
        g.bin += b"\0" * (-len(g.bin) % 4)
        views.append({"buffer": 0, "byteOffset": len(g.bin), "byteLength": len(raw)})
        g.bin += raw
        a["bufferView"] = len(views) - 1
        a.pop("byteOffset", None)
        a["count"] = len(arr)
        if a["type"] == "SCALAR":
            a["min"], a["max"] = [float(arr.min())], [float(arr.max())]
        else:
            a.pop("min", None)
            a.pop("max", None)
        accessors.append(a)
        return len(accessors) - 1
    for anim in c.j["animations"]:
        if anim["name"] not in names:
            continue
        out = {"name": anim["name"], "channels": [], "samplers": []}
        for ch in anim["channels"]:
            src = c.j["nodes"][ch["target"]["node"]]
            if src.get("name") not in nodes or ch["target"]["path"] not in ("rotation", "translation"):
                continue
            # (moves only the root's - the ground under it; the bones' own
            # places stay the model's: the skeleton alone comes out with the
            # hips' rest elsewhere, and the clips are baked with the hips'
            # sway off - lift=0)
            if ch["target"]["path"] == "translation" and src.get("name") != "root":
                continue
            tgt = g.j["nodes"][nodes[src["name"]]]
            smp = anim["samplers"][ch["sampler"]]
            times, _ = c.get(smp["input"])
            vals, _ = c.get(smp["output"])
            if ch["target"]["path"] == "rotation":
                rest_c = np.array(src.get("rotation", [0, 0, 0, 1]), float)
                rest_g = np.array(tgt.get("rotation", [0, 0, 0, 1]), float)
                # (the turn from the skeleton's rest, onto the model's)
                inv = rest_c * np.array([-1, -1, -1, 1])
                vals = _q_mul(np.broadcast_to(rest_g, vals.shape), _q_mul(np.broadcast_to(inv, vals.shape), vals))
            else:
                vals = vals - np.array(src.get("translation", [0, 0, 0])) + np.array(tgt.get("translation", [0, 0, 0]))
            out["samplers"].append({"input": add(times, smp["input"]), "output": add(vals, smp["output"]),
                                    "interpolation": smp.get("interpolation", "LINEAR")})
            out["channels"].append({"sampler": len(out["samplers"]) - 1,
                                    "target": {"node": nodes[src["name"]], "path": ch["target"]["path"]}})
        g.j["animations"].append(out)
    g.chunks[1][1] = g.bin
    g.j["buffers"][0]["byteLength"] = len(g.bin)
    g.save(model_path)


def main():
    ids = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    tmp = tempfile.mkdtemp()
    for cid in ids:
        path = os.path.join(CHARACTERS, cid + ".glb")
        clips = os.path.join(tmp, cid + "_clips.glb")
        names = bake(path, clips)
        merge(path, clips, names)
        print("%s: %s added, %d clips now" % (cid, ", ".join(names), len(Glb(path).j["animations"])))
    os._exit(0)


if __name__ == "__main__":
    main()
