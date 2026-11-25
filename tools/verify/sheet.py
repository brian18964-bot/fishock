import sys, os, re
from PIL import Image, ImageDraw, ImageFont
# usage: sheet.py SHOTS_DIR PREFIX OUT.png NAMES_TSV [cols] [ids...]
d, prefix, out, names_tsv = sys.argv[1:5]
cols = int(sys.argv[5]) if len(sys.argv) > 5 else 4
ids = sys.argv[6:]
names = {}
for line in open(names_tsv, encoding="utf-8"):
    p = line.rstrip("\n").split("\t")
    if len(p) >= 2 and re.match(r"\d-\d", p[0]):
        names[p[0]] = p[1]
if not ids:
    ids = sorted(names)
tw, th = 480, 270
font = ImageFont.truetype("/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc", 22)
rows = (len(ids) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw, rows * (th + 34)), (18, 18, 20))
dr = ImageDraw.Draw(sheet)
for i, lid in enumerate(ids):
    x, y = (i % cols) * tw, (i // cols) * (th + 34)
    path = os.path.join(d, f"{prefix}{lid}.png")
    if os.path.exists(path):
        im = Image.open(path).convert("RGB").resize((tw - 6, th - 6), Image.LANCZOS)
        sheet.paste(im, (x + 3, y + 3))
    else:
        dr.text((x + 20, y + 120), "缺少截圖", font=font, fill=(255, 80, 80))
    dr.text((x + 8, y + th + 4), f"{lid} {names.get(lid, '')}", font=font, fill=(235, 210, 140))
sheet.save(out)
print(out, sheet.size)
