"""The web build's character packs (user request: the web build was 148 MB,
too much for a phone's first visit). Only the first character (the black
cat) comes inside the game's own pack; each other one's pictures and camp
model are a pack of their own, fetched the first time it's wanted and kept
in the browser after (scripts/character_packs.gd).

This writes export_presets.cfg's packs from the files on disk: one
"Pack <id>" preset per character (its sprites folder and camp model), and
the "Web" preset's exclude_filter leaving them out of the main pack. Run it
after adding a character or a file to one (CI exports with what's
committed):

  python3 tools/pack_presets.py            (repo root)

and, building the web export (tools/export_web.py does both):

  godot --headless --export-pack "Pack owl" build/web/packs/owl.pck
"""
import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PRESETS = os.path.join(ROOT, "export_presets.cfg")
# (Profile.CHARACTERS: the first one comes with the game.)
BUNDLED = "cat"
SPRITES = "assets/sprites/player/%s"
MODEL = "assets/models/characters/%s.glb"
BASE_EXCLUDE = ["tests/*"]


def characters():
    src = open(os.path.join(ROOT, "scripts/profile.gd"), encoding="utf-8").read()
    line = re.search(r"const CHARACTERS := \[(.*?)\]\n", src, re.S).group(1)
    return re.findall(r'\["(\w+)", "', line)


def packed():
    return [c for c in characters() if c != BUNDLED]


def files_of(cid):
    """A character's files (res:// paths), the json data aside."""
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, SPRITES % cid, "*"))):
        name = os.path.basename(f)
        if name.endswith((".import", ".json")):
            continue
        out.append("res://" + os.path.relpath(f, ROOT).replace(os.sep, "/"))
    out.append("res://" + MODEL % cid)
    return out


def sections(text):
    """[(header, body)] of the cfg, in order."""
    parts = re.split(r"(?m)^(\[[^\]]+\])\n", text)
    head = parts[0]
    return head, [(parts[i], parts[i + 1]) for i in range(1, len(parts), 2)]


def main():
    text = open(PRESETS, encoding="utf-8").read()
    head, secs = sections(text)
    web = next(i for i, (h, b) in enumerate(secs) if h == "[preset.0]")
    web_opts = next(b for h, b in secs if h == "[preset.0.options]")
    excludes = BASE_EXCLUDE + [SPRITES % c + "/*" for c in packed()] + [MODEL % c for c in packed()]
    body = re.sub(r'(?m)^exclude_filter=".*"$', 'exclude_filter="%s"' % ", ".join(excludes), secs[web][1])
    out = [("[preset.0]", body), ("[preset.0.options]", web_opts)]
    for i, cid in enumerate(packed(), start=1):
        files = ", ".join('"%s"' % f for f in files_of(cid))
        out.append(("[preset.%d]" % i, "\n".join([
            "",
            'name="Pack %s"' % cid,
            'platform="Web"',
            "runnable=false",
            "advanced_options=false",
            "dedicated_server=false",
            'custom_features=""',
            'export_filter="resources"',
            "export_files=PackedStringArray(%s)" % files,
            'include_filter="%s/*.json"' % (SPRITES % cid),
            'exclude_filter=""',
            'export_path="build/web/packs/%s.pck"' % cid,
            "patches=PackedStringArray()",
            'encryption_include_filters=""',
            'encryption_exclude_filters=""',
            "seed=0",
            "encrypt_pck=false",
            "encrypt_directory=false",
            "script_export_mode=2",
            "", ""])))
        out.append(("[preset.%d.options]" % i, web_opts))
    with open(PRESETS, "w", encoding="utf-8") as fh:
        fh.write(head)
        for h, b in out:
            fh.write(h + "\n" + b)
    print("packs:", ", ".join(packed()), "- bundled:", BUNDLED)


if __name__ == "__main__":
    sys.exit(main())
