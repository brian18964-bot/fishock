"""The sea's foam pattern, from the user's ocean-water pack (the "Asset2"
release, OCEAN+WATER.rar: MAPS/Foam003_2K_Opacity.jpg - ambientCG, CC0).

User request: our sea, looking to that pack for how a shore is done but in
our own, less photographic style. Its tiling foam mask, softened a little
and brought down to 512 px (a phone doesn't need more for a lacy band at
the water's edge), feeds shaders/water.gdshader.

  python tools/make_sea_foam.py PATH/TO/Foam003_2K_Opacity.jpg
"""
import os
import sys

from PIL import Image, ImageFilter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "water", "sea_foam.png")


def main():
    img = Image.open(sys.argv[1]).convert("L").resize((512, 512), Image.LANCZOS)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
