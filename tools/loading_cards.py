"""The loading cards (assets/loading/*.jpg, shown by scripts/main.gd's loading screen): the game's
own night (renders from tools/loading_shots.gd) graded, its gilded title, its gold frame, and a
panel of the game's dark stone with a word on what's shown - in the game's fonts and colours.

    python3 tools/loading_cards.py RENDERS_DIR [PREVIEW_DIR] [card ...]

RENDERS_DIR holds the renders (y_*, z_*, c_*, npc_* PNGs); PREVIEW_DIR, if given, gets each card
at full size with the loading bar drawn where the game draws its own. The characters' words are
read from scripts/abilities.gd and scripts/profile.gd.
"""
import os, re, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDERS = sys.argv[1] if len(sys.argv) > 1 else 'loading_renders'
PRE = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('-') and os.path.isdir(sys.argv[2]) else ''
UI = ROOT + '/assets/ui/'
FONTS = ROOT + '/assets/fonts/'
W, H = 1920, 1080
GOLD = (237, 194, 92); GOLD_B = (255, 217, 107); TEXT = (237, 230, 209); DIM = (168, 161, 145)
FALL = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'

def font(name, size): return ImageFont.truetype(FONTS + name, size)
def fall(size): return ImageFont.truetype(FALL, size)

def has(f, c):
    nd = f.getmask(chr(0x10FFF)); m = f.getmask(c)
    return not (m.size == nd.size and bytes(m) == bytes(nd))

def text(img, xy, s, f, fb, fill, stroke=2, spacing=0, shadow=True, embolden=0):
    # embolden: a fallback glyph in a bold line (the title) drawn that much
    # heavier, so it doesn't read thinner than its neighbours.
    d = ImageDraw.Draw(img)
    x, y = xy
    for c in s:
        ff = f if has(f, c) else fb
        if shadow:
            d.text((x + 2, y + 3), c, font=ff, fill=(0, 0, 0), stroke_width=stroke, stroke_fill=(0, 0, 0))
        d.text((x, y), c, font=ff, fill=fill, stroke_width=stroke, stroke_fill=(10, 8, 6))
        if ff is fb and embolden:
            d.text((x + embolden, y), c, font=ff, fill=fill)
        x += ff.getlength(c) + spacing
    return x

def width(s, f, fb, spacing=0):
    return sum((f if has(f, c) else fb).getlength(c) + spacing for c in s)

def wrap(s, f, fb, w):
    # Break between tokens: a run of digits / latin / % ("10%", "LUCKY!")
    # stays whole, each CJK character is its own token, and closing
    # punctuation never starts a line.
    toks = re.findall(r'[0-9A-Za-z.%!+\-]+|.', s)
    size = lambda t: sum((f if has(f, c) else fb).getlength(c) for c in t)
    for ww in range(w, w - 220, -12):
        lines, cur, cw = [], '', 0
        for t in toks:
            l = size(t)
            if cw + l > ww and cur and t not in '，。、；：？！）」':
                lines.append(cur); cur, cw = '', 0
            cur += t; cw += l
        lines.append(cur)
        if len(lines[-1]) >= 6: return lines
    return lines

def nine(name, size, m, scale=1.0, center=True):
    src = Image.open(UI + name).convert('RGBA')
    l, t, r, b = m
    sw, sh = src.size
    L, T, R, B = [int(v * scale) for v in m]
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    def part(box, dst, dsize):
        if dsize[0] > 0 and dsize[1] > 0:
            out.alpha_composite(src.crop(box).resize(dsize, Image.LANCZOS), dst)
    W2, H2 = size
    part((0, 0, l, t), (0, 0), (L, T)); part((sw - r, 0, sw, t), (W2 - R, 0), (R, T))
    part((0, sh - b, l, sh), (0, H2 - B), (L, B)); part((sw - r, sh - b, sw, sh), (W2 - R, H2 - B), (R, B))
    part((l, 0, sw - r, t), (L, 0), (W2 - L - R, T)); part((l, sh - b, sw - r, sh), (L, H2 - B), (W2 - L - R, B))
    part((0, t, l, sh - b), (0, T), (L, H2 - T - B)); part((sw - r, t, sw, sh - b), (W2 - R, T), (R, H2 - T - B))
    if center:
        part((l, t, sw - r, sh - b), (L, T), (W2 - L - R, H2 - T - B))
    return out

def grade(path, crop=None, lift=0.72, warm=1.0, glow_k=2.0):
    im = Image.open(path).convert('RGB')
    if crop: im = im.crop(crop)
    im = im.resize((W, H), Image.LANCZOS)
    a = np.asarray(im, float) / 255.0
    a = a ** lift                                   # open up the night
    lum = a.mean(-1, keepdims=True)
    a = a * (1 + np.array([0.06, 0.0, -0.04]) * warm * (lum > 0.35)) + np.array([-0.01, 0.005, 0.03]) * (lum < 0.3)
    yy, xx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((xx - W * 0.42) / (W * 0.62)) ** 2 + ((yy - H * 0.5) / (H * 0.62)) ** 2)
    a *= (1 - 0.55 * np.clip(r - 0.45, 0, 1))[..., None]
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    glow = img.point(lambda v: int(max(0, v - 150) * glow_k)).filter(ImageFilter.GaussianBlur(14))
    img = ImageChops.add(img, glow)
    return ImageEnhance.Contrast(img).enhance(1.08).convert('RGBA')

def logo(img):
    f = ImageFont.truetype(FONTS + 'Philosopher-Latin.ttf', 132)
    s = 'Fishock'
    tw = f.getlength(s)
    x, y = (W - tw) / 2, 52
    # dark band behind, as the frame's crown
    band = Image.new('RGBA', (W, 260), (0, 0, 0, 0)); bd = ImageDraw.Draw(band)
    for i in range(260):
        bd.line((0, i, W, i), fill=(0, 0, 0, int(170 * (1 - i / 260) ** 1.4)))
    img.alpha_composite(band)
    mask = Image.new('L', (W, 260), 0)
    ImageDraw.Draw(mask).text((x, y), s, font=f, fill=255)
    grad = Image.new('RGB', (W, 260))
    gd = ImageDraw.Draw(grad)
    for i in range(260):
        t = (i - y - 20) / 120
        c = [int(a + (b - a) * min(1, max(0, t))) for a, b in zip((255, 236, 170), (176, 118, 36))]
        gd.line((0, i, W, i), fill=tuple(c))
    edge = Image.new('L', (W, 260), 0)
    ImageDraw.Draw(edge).text((x, y), s, font=f, fill=255, stroke_width=7, stroke_fill=255)
    halo = edge.filter(ImageFilter.GaussianBlur(16)).point(lambda v: int(v * 0.6))
    img.paste((255, 200, 90), (0, 0), halo)
    img.paste((26, 16, 8), (0, 0), edge)
    img.paste(grad, (0, 0), mask)
    sub = font('WenKaiTC-Bold-subset.ttf', 30)
    st = '夜　釣　手　記'
    sw = width(st, sub, fall(28))
    text(img, ((W - sw) / 2, 206), st, sub, fall(28), GOLD, stroke=3)
    div = Image.open(UI + 'divider.png').convert('RGBA').resize((520, 30))
    img.alpha_composite(div, (int((W - 520) / 2), 186))

def panel(img, where, title, body):
    bf = font('WenKaiTC-Regular-subset.ttf', 32)
    big = font('WenKaiTC-Bold-subset.ttf', 58)
    bottom = where.startswith('bottom')
    if bottom:
        w = 820; x = 90 if where == 'bottom-left' else W - 90 - w
    else:
        w = 660 if '【天賦】' in body else 560
        x = W - 90 - w if where == 'right' else 90
    story, _, gift = body.partition('【天賦】')
    lines = [(l, TEXT) for l in wrap(story, bf, fall(30), w - 110)]
    if gift:
        lines.append(('', TEXT))
        lines += [(l, GOLD) for l in wrap('天賦：' + gift, bf, fall(30), w - 110)]
    h = 150 + len(lines) * 50 + 30 - (26 if gift else 0)
    y = 926 - h if bottom else min(max(270, (H - h) // 2 + 40), 930 - h)
    page = Image.open(UI + 'page_bg.png').convert('RGBA')
    bg = Image.new('RGBA', (w, h))
    for ty in range(0, h, page.height):
        for tx in range(0, w, page.width):
            bg.alpha_composite(page, (tx, ty))
    bg.putalpha(205)
    img.alpha_composite(bg, (x, y))
    img.alpha_composite(nine('frame_dark.png', (w + 10, h + 10), (18, 16, 18, 16), 0.9, center=False), (x - 5, y - 5))
    text(img, (x + 44, y + 30), title, big, fall(54), GOLD_B, stroke=4, embolden=1)
    div = Image.open(UI + 'divider.png').convert('RGBA').resize((w - 80, 24))
    img.alpha_composite(div, (x + 40, y + 108))
    yy = y + 146
    for line, col in lines:
        if line == '':
            yy += 24
            continue
        text(img, (x + 46, yy), line, bf, fall(30), col, stroke=2, spacing=1)
        yy += 50

def loading_bar(img, frac):
    bw, bh = 980, 44
    x, y = (W - bw) // 2, 966
    fw = int((bw - 30) * frac)
    fill = Image.new('RGBA', (fw, bh - 18))
    fd = ImageDraw.Draw(fill)
    for i in range(bh - 18):
        t = i / (bh - 19)
        c = tuple(int(a + (b - a) * t) for a, b in zip((255, 214, 120), (176, 112, 30)))
        fd.line((0, i, fw, i), fill=c + (255,))
    back = Image.new('RGBA', (bw - 24, bh - 14), (6, 5, 4, 220))
    img.alpha_composite(back, (x + 12, y + 7))
    img.alpha_composite(fill, (x + 15, y + 9))
    img.alpha_composite(nine('bar_frame.png', (bw, bh), (14, 10, 14, 10), 1.4, center=False), (x, y))
    lf = font('WenKaiTC-Regular-subset.ttf', 26)
    s = '載入中…'
    text(img, ((W - width(s, lf, fall(24))) / 2, y - 40), s, lf, fall(24), DIM, stroke=2)

def card(out, shot, crop, where, title, body, frac=None, lift=0.72, preview=None, glow_k=2.0):
    img = grade(f'{RENDERS}/{shot}.png', crop, lift, glow_k=glow_k)
    logo(img)
    if where:
        panel(img, where, title, body)
    img.alpha_composite(nine('frame.png', (W, H), (18, 16, 18, 16), 1.0, center=False))
    # (the game's own bar goes where loading_bar draws it - the card keeps that room clear)
    small = img.convert('RGB').resize((1280, 720), Image.LANCZOS)
    if out.endswith('.png'):
        small.save(out, optimize=True)
    else:
        small.save(out, quality=86)
    if preview:
        loading_bar(img, 0.62)
        img.convert('RGB').save(preview)
    print('wrote', out)

OUT = ROOT + '/assets/loading'
os.makedirs(OUT, exist_ok=True)
CARDS = [
 ('cast', 'y_cast_2', (80, 60, 1680, 960), 'right', '拋竿',
  '按住右搖桿瞄準，拉得越開，浮標落得越遠。遠處的水域藏著更大的魚，也更難拉上岸。浮標一沉，立刻揚竿，慢一步，魚就帶著餌跑了。'),
 ('dragon', 'y_dragon_02', (400, 30, 1840, 840), 'right', '子夜之龍',
  '夜色過半，龍會從天而降，吼聲傳遍整座湖。牠循著燈光而來。被牠抓住時，強光、心臟，或丟一條魚給牠，都能換來脫身的機會。'),
 ('catch', 'y_catch_2', (0, 120, 1500, 964), 'right', '漁獲',
  '每條魚都有自己的大小、活性與新鮮度。離開水面，活性一點一滴流失；魚死了，新鮮度跟著倒數。背上打氧魚箱，放進去的魚就不會掉活性。'),
 ('altar', 'z_altar_1', None, 'bottom-left', '祭壇',
  '把釣到的魚獻上祭壇，湊滿這一晚的供品額度，渡石便會亮起，帶你離開。活魚分量最足，死去的魚價值隨新鮮度流失；只有這一晚釣到的魚才算數。'),
 ('ghost', 'z_ghost_2', None, 'right', '小鬼',
  '小鬼大多只在湖邊飄蕩，偶爾會過來搗亂：讓你頭暈、搶走身上的魚、剪斷釣線，或溜進水裡偷走浮標上的餌。用燈光一照，牠就會愣在原地。'),
 ('lamp', 'z_lamp_2', None, 'left', '煤燈',
  '煤燈照亮你面前的一片路，也一路燒著燈油。燈油只能在營火旁的油桶補充；油桶用完，營火的光和它守護的安全範圍會一起熄滅。燈隨時能吹熄，重新點亮要花一點時間。'),
 ('frost', 'z_frost_0', None, 'right', '冷凍花',
  '冷凍花只長在石頭旁，根部蔓延出一片冰冷的土地。帶著鏟子在那裡挖掘，就能挖出冷凍土；用在背包裡的魚身上，300 秒內新鮮度下降只剩四分之一。'),
 ('oxy', 'z_oxy_0', None, 'right', '魚氧樹',
  '只長在水邊淺灘、冒著細小氣泡的小樹。採下來揉碎，塗在魚鰓上，魚離開水面也能撐久一點：180 秒內，活性下降只剩四分之一。'),
 ('snow', 'z_snow_0', None, 'right', '雪地森林',
  '大雪覆蓋的森林，走過的地方都會留下腳印。這裡出沒的是雙尾黑龍：被牠的紅燈照到會感到壓力，腳步變慢，撐不過幾秒就會陷入混亂。'),
 ('autumn', 'z_autumn_0', None, 'bottom-right', '秋林',
  '枯樹與落葉鋪滿的秋天森林，動物少得出奇。風一吹，落葉就在腳邊翻飛；角色和動物走過，也會把葉子踢起來。'),
 ('merchant', 'npc_0', None, 'right', '青蛙商人',
  '營地的青蛙商人總在攤子和小船之間來回走動。釣竿、鏟子、打氧魚箱、餌料都向他買；用不到的東西和魚，也能賣給他換錢。'),
]
# Each character: its story and its kind's gift, from the game's own data; which side its words go
# (its render puts it on the other: c_<id>_0 on the right, c_<id>_1 on the left).
CHAR_IDS = ['cat', 'owl', 'owl2', 'dog', 'dog3', 'bear', 'bear2', 'deer', 'deer2', 'sheep', 'sheep2', 'croc']
_ab = open(ROOT + '/scripts/abilities.gd', encoding='utf-8').read()
_stories = dict(re.findall(r'^\t"(\w+)": "(.*?)",$', _ab[_ab.index('const STORIES'):_ab.index('## (tests: every chance')], re.M))
_gifts = {k: (n, d) for k, n, d in re.findall(r'"(\w+)": \{"name": "([^"]+)", "desc": "([^"]+)"', _ab)}
_pf = open(ROOT + '/scripts/profile.gd', encoding='utf-8').read()
_names = dict(re.findall(r'\["(\w+)", "([^"]+)"\]', _pf[_pf.index('const CHARACTERS'):_pf.index('var character:')]))
for i, cid in enumerate(CHAR_IDS):
    gift = _gifts[re.sub(r'\d+$', '', cid)]
    where = 'left' if i % 2 == 0 else 'right'
    CARDS.append(('char_' + cid, 'c_%s_%d' % (cid, 0 if where == 'left' else 1), (96, 54, 1824, 1026), where,
        '%s・%s' % (_names[cid], gift[0]), _stories[cid].replace('\\n', '') + '【天賦】' + gift[1]))
only = [a for a in sys.argv[2:] if a != PRE]
for name, shot, crop, where, title, body in CARDS:
    if only and name not in only:
        continue
    if name.startswith('char_'):
        # (lit from the front by its own lamp: graded gently, no bloom)
        card(f'{OUT}/{name}.jpg', shot, crop, where, title, body, lift=0.86, preview=f'{PRE}/{name}.png' if PRE else None, glow_k=0.0)
    else:
        dark = name in ('dragon', 'autumn', 'snow')
        card(f'{OUT}/{name}.jpg', shot, crop, where, title, body, lift=0.62 if dark else 0.72, preview=f'{PRE}/{name}.png' if PRE else None)
# The game's opening card (project.godot's boot splash, and the web page's while it downloads - its
# own bar and tips go over the dark ground): the camp at night, no words.
if not only or 'boot' in only:
    card(ROOT + '/assets/boot_splash.png', 'camp_3', None, None, '', '', lift=0.66, preview=f'{PRE}/boot.png' if PRE else None)
