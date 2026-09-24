"""Build the game's CJK UI font: Noto Sans CJK TC trimmed to the characters
the game actually shows.

Web builds have no system fonts to fall back on, so without a bundled font
every Chinese character renders as a box. The full CJK font is ~20 MB; this
keeps only printable ASCII, common CJK punctuation and every non-ASCII
character found in the project's scripts, scenes and project.godot (all UI
text lives there), which comes out a few hundred KB.

  python tools/subset_font.py NotoSansCJK-Regular.ttc
    (Ubuntu/Debian: fonts-noto-cjk, /usr/share/fonts/opentype/noto/)

Re-run after adding new text; the web build workflow runs it before every
export, so new characters can't slip through there. Needs fonttools.
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTCollection

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "fonts" / "NotoSansTC-subset.otf"
TC_FACE = "Noto Sans CJK TC"
EXTRA = "，。、；：？！「」『』（）《》〈〉…—～・％＋－／"


def used_characters() -> str:
    chars = {chr(c) for c in range(0x20, 0x7F)} | set(EXTRA)
    for pattern in ("scripts/**/*.gd", "scenes/**/*.tscn", "project.godot"):
        for path in ROOT.glob(pattern):
            chars |= {ch for ch in path.read_text(encoding="utf-8") if ord(ch) > 0x7F}
    return "".join(sorted(chars))


def main() -> None:
    collection = TTCollection(sys.argv[1])
    font = next(f for f in collection.fonts if f["name"].getDebugName(4) == TC_FACE)
    text = used_characters()
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(str(OUT))
    print(f"{len(text)} characters -> {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
