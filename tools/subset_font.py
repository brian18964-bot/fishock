"""Build the game's UI fonts, trimmed to the characters the game shows.

Web builds have no system fonts to fall back on, so without a bundled font
every Chinese character renders as a box. The full CJK fonts are 13-20 MB
each; these keep only printable ASCII, common CJK punctuation and every
non-ASCII character found in the project's scripts, scenes and
project.godot (all UI text lives there), a few hundred KB each:

  assets/fonts/WenKaiTC-Regular-subset.ttf   LXGW WenKai TC (OFL): the UI's
  assets/fonts/WenKaiTC-Bold-subset.ttf      Chinese - a brush-written kai
                                             face, like a fantasy MMO's
  assets/fonts/NotoSansTC-subset.otf         Noto Sans CJK TC: the fallback
                                             for anything WenKai lacks

(Latin letters and digits come from Philosopher (OFL), trimmed to Latin - see
assets/fonts/ui_font.tres for how they're chained.)

  python tools/subset_font.py [NotoSansCJK-Regular.ttc]
    (Ubuntu/Debian: fonts-noto-cjk, /usr/share/fonts/opentype/noto/)

WenKai is fetched from the Google Fonts repository into FONT_CACHE (default
/tmp/fishock-fonts) the first time. Without the Noto file only WenKai is
rebuilt. Re-run after adding new text; the web build workflow runs it
before every export, so new characters can't slip through there. Needs
fonttools.
"""
import os
import pathlib
import sys
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTCollection, TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets" / "fonts"
NOTO_OUT = FONTS / "NotoSansTC-subset.otf"
TC_FACE = "Noto Sans CJK TC"
EXTRA = "，。、；：？！「」『』（）《》〈〉…—～・％＋－／"
WENKAI_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/lxgwwenkaitc/LXGWWenKaiTC-%s.ttf"
CACHE = pathlib.Path(os.environ.get("FONT_CACHE", "/tmp/fishock-fonts"))


def used_characters() -> str:
    chars = {chr(c) for c in range(0x20, 0x7F)} | set(EXTRA)
    for pattern in ("scripts/**/*.gd", "scenes/**/*.tscn", "project.godot"):
        for path in ROOT.glob(pattern):
            chars |= {ch for ch in path.read_text(encoding="utf-8") if ord(ch) > 0x7F}
    return "".join(sorted(chars))


def _subset(font: TTFont, text: str, out: pathlib.Path) -> None:
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.drop_tables += ["meta"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    out.parent.mkdir(parents=True, exist_ok=True)
    font.save(str(out))
    print(f"{len(text)} characters -> {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")


def wenkai(weight: str) -> pathlib.Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"LXGWWenKaiTC-{weight}.ttf"
    if not path.exists():
        print("fetching", WENKAI_URL % weight)
        urllib.request.urlretrieve(WENKAI_URL % weight, path)
    return path


def main() -> None:
    text = used_characters()
    for weight in ("Regular", "Bold"):
        _subset(TTFont(str(wenkai(weight))), text, FONTS / f"WenKaiTC-{weight}-subset.ttf")
    if len(sys.argv) > 1:
        collection = TTCollection(sys.argv[1])
        font = next(f for f in collection.fonts if f["name"].getDebugName(4) == TC_FACE)
        _subset(font, text, NOTO_OUT)


if __name__ == "__main__":
    main()
