"""The web build (user request: smaller for a phone's first visit): each
character but the first as a pack of its own beside the game, named by its
content so a browser that kept an older one fetches the new one
(scripts/character_packs.gd), then the game itself with the list of them
(assets/packs.json, only ever in the build).

  python3 tools/export_web.py GODOT OUT_DIR       (repo root; OUT_DIR/index.html)
"""
import hashlib
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pack_presets  # noqa: E402

ROOT = pack_presets.ROOT
MANIFEST = os.path.join(ROOT, "assets", "packs.json")


def content_hash(godot, cid):
    """The character's own files (and the engine's version): a pack keeps
    its name until its pictures or model change - not with every change to
    the game's code, which the pack also carries but never replaces."""
    h = hashlib.sha1(subprocess.run([godot, "--version"], capture_output=True, text=True).stdout.encode())
    for res in pack_presets.files_of(cid):
        path = os.path.join(ROOT, res[len("res://"):])
        for f in (path, path + ".import"):
            if os.path.exists(f):
                h.update(open(f, "rb").read())
    for f in sorted(os.listdir(os.path.join(ROOT, pack_presets.SPRITES % cid))):
        if f.endswith(".json"):
            h.update(open(os.path.join(ROOT, pack_presets.SPRITES % cid, f), "rb").read())
    return h.hexdigest()[:10]


def main():
    godot, out = sys.argv[1], os.path.abspath(sys.argv[2])
    os.makedirs(os.path.join(out, "packs"), exist_ok=True)
    # (the presets as the files on disk are now)
    pack_presets.main()
    listed = {}
    for cid in pack_presets.packed():
        tmp = os.path.join(out, "packs", cid + ".pck")
        subprocess.run([godot, "--headless", "--path", ROOT, "--export-pack", "Pack " + cid, tmp], check=True)
        digest = content_hash(godot, cid)
        name = "%s-%s.pck" % (cid, digest)
        os.replace(tmp, os.path.join(out, "packs", name))
        listed[cid] = name
        print("pack", name, os.path.getsize(os.path.join(out, "packs", name)) // 1024, "KB")
    with open(MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(listed, fh, indent=1)
    # (and beside them, for a game kept in a browser from an earlier build)
    with open(os.path.join(out, "packs", "packs.json"), "w", encoding="utf-8") as fh:
        json.dump(listed, fh, indent=1)
    try:
        subprocess.run([godot, "--headless", "--path", ROOT, "--export-release", "Web",
                        os.path.join(out, "index.html")], check=True)
    finally:
        os.remove(MANIFEST)
    print("game", os.path.getsize(os.path.join(out, "index.pck")) // 1024, "KB")


if __name__ == "__main__":
    main()
