"""The eight talents' icons (神經反射 重量訓練 技巧洩力 咬緊牙關 LUCKY! 狠角色 有經驗
好心情) as SVGs in the same medallion as assets/ui/abilities/*.svg: the gold rim, a
dark ground tinted to the icon's colour, a flat glyph.

  python3 tools/make_talent_icons.py OUT_DIR     (writes OUT_DIR/<id>.svg)
"""
import os
import sys

RIM = ('<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f6dc8a"/>'
       '<stop offset="0.5" stop-color="#b8862e"/><stop offset="1" stop-color="#6e4a14"/></linearGradient>')


def medallion(c1, c0, glyph):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs>
<radialGradient id="bg" cx="50%" cy="40%" r="62%"><stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c0}"/></radialGradient>
{RIM}
</defs>
<circle cx="64" cy="64" r="60" fill="url(#rim)"/>
<circle cx="64" cy="64" r="54" fill="url(#bg)"/>
<circle cx="64" cy="64" r="54" fill="none" stroke="#000" stroke-opacity="0.45" stroke-width="2"/>
{glyph}
</svg>
'''


GLYPHS = {}

# 神經反射: a bolt through the rings of a signal
GLYPHS["reflex"] = ("#6e2a1c", "#1c0905", '''
<g fill="none" stroke="#ffb59a" stroke-opacity="0.55" stroke-width="3"><circle cx="64" cy="64" r="34"/><circle cx="64" cy="64" r="22" stroke-opacity="0.8"/></g>
<path d="M72 18 L40 70 H62 L54 110 L90 54 H67 Z" fill="#ffd45a" stroke="#7a4a08" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M70 28 L52 62" stroke="#fff3b0" stroke-width="3" stroke-linecap="round" fill="none"/>''')

# 重量訓練: a dumbbell
GLYPHS["weights"] = ("#2a3c5a", "#070c18", '''
<rect x="52" y="60" width="24" height="8" rx="3" fill="#e8dfc4"/>
<g fill="#8fa9cf" stroke="#0e1830" stroke-width="2.5"><rect x="26" y="38" width="14" height="52" rx="4"/><rect x="88" y="38" width="14" height="52" rx="4"/>
<rect x="38" y="48" width="12" height="32" rx="3"/><rect x="78" y="48" width="12" height="32" rx="3"/></g>
<g fill="#d6e4fa" fill-opacity="0.7"><rect x="29" y="42" width="4" height="40" rx="2"/><rect x="91" y="42" width="4" height="40" rx="2"/></g>''')

# 技巧洩力: a rod bending, the force let off along the line
GLYPHS["leak"] = ("#1e5a56", "#04161a", '''
<path d="M26 104 C40 70 70 40 100 30" fill="none" stroke="#e8dfc4" stroke-width="5" stroke-linecap="round"/>
<path d="M100 30 C108 52 96 78 82 92" fill="none" stroke="#9fe6c8" stroke-width="2.5" stroke-linecap="round" stroke-dasharray="1 5"/>
<g fill="none" stroke="#9fe6c8" stroke-width="3" stroke-linecap="round"><path d="M82 92 q10 -2 14 6"/><path d="M80 84 q12 -4 18 4" stroke-opacity="0.7"/><path d="M78 76 q14 -6 22 2" stroke-opacity="0.45"/></g>
<circle cx="26" cy="104" r="7" fill="#b9863a" stroke="#4a2f0c" stroke-width="2"/>''')

# 咬緊牙關: clenched teeth
GLYPHS["grit"] = ("#6a1c26", "#16050a", '''
<path d="M24 52 Q64 36 104 52 L100 82 Q64 98 28 82 Z" fill="#2a0a10" stroke="#f0d8c8" stroke-width="3" stroke-linejoin="round"/>
<path d="M30 56 Q64 44 98 56 L96 76 Q64 88 32 76 Z" fill="#f6efe0"/>
<g stroke="#6a1c26" stroke-width="2.5" stroke-linecap="round"><path d="M64 48 V84"/><path d="M48 51 V82"/><path d="M80 51 V82"/><path d="M36 54 V79"/><path d="M92 54 V79"/><path d="M30 66 Q64 76 98 66" fill="none"/></g>
<g stroke="#ffb59a" stroke-width="3" stroke-linecap="round"><path d="M20 38 l8 6"/><path d="M108 38 l-8 6"/><path d="M64 24 v8"/></g>''')

# LUCKY!: a four-leaf clover
GLYPHS["lucky"] = ("#1d5a2c", "#04160a", '''
<path d="M64 70 C62 90 70 102 82 110" fill="none" stroke="#7fd08a" stroke-width="5" stroke-linecap="round"/>
<g fill="#6fcf7e" stroke="#0e3a1a" stroke-width="2.5" stroke-linejoin="round">
<path d="M64 62 C44 56 38 34 52 26 C62 22 66 34 64 44 Z"/><path d="M64 62 C84 56 90 34 76 26 C66 22 62 34 64 44 Z"/>
<path d="M64 66 C44 72 38 94 52 102 C62 106 66 94 64 84 Z"/><path d="M64 66 C84 72 90 94 76 102 C66 106 62 94 64 84 Z"/></g>
<g fill="#b8f0be" fill-opacity="0.55"><path d="M56 40 C50 36 50 30 55 30 C58 32 59 36 56 40 Z"/><path d="M72 40 C78 36 78 30 73 30 C70 32 69 36 72 40 Z"/></g>
<circle cx="64" cy="64" r="4" fill="#ffe08a"/>
<g fill="#ffe08a"><path d="M100 28 l2 6 6 2 -6 2 -2 6 -2 -6 -6 -2 6 -2z"/><path d="M26 92 l1.5 4 4 1.5 -4 1.5 -1.5 4 -1.5 -4 -4 -1.5 4 -1.5z"/></g>''')

# 狠角色: an iron fist, scarred
GLYPHS["tough"] = ("#6a3412", "#180a03", '''
<g fill="#e4b27a" stroke="#4a210a" stroke-width="3" stroke-linejoin="round">
<rect x="34" y="46" width="62" height="50" rx="12"/>
<rect x="34" y="34" width="15" height="26" rx="7"/><rect x="50" y="30" width="15" height="28" rx="7"/><rect x="66" y="30" width="15" height="28" rx="7"/><rect x="82" y="34" width="14" height="26" rx="7"/>
<path d="M34 70 C22 66 20 82 32 86 C40 88 44 84 44 78 Z"/></g>
<g fill="none" stroke="#4a210a" stroke-width="2.5" stroke-linecap="round"><path d="M49 50 V62"/><path d="M65 50 V60"/><path d="M81 50 V62"/></g>
<path d="M58 64 L82 92" stroke="#7a1d14" stroke-width="4" stroke-linecap="round"/><path d="M62 66 l5 -3 M68 74 l5 -3 M74 82 l5 -3" stroke="#7a1d14" stroke-width="2" stroke-linecap="round"/>
<g fill="#ffd45a"><rect x="30" y="96" width="70" height="8" rx="3"/></g>''')

# 有經驗: rank chevrons under a star
GLYPHS["veteran"] = ("#4a4a1c", "#10100a", '''
<path d="M64 14 l8 18 20 2 -15 13 5 20 -18 -10 -18 10 5 -20 -15 -13 20 -2z" fill="#ffd45a" stroke="#6a4a08" stroke-width="2.5" stroke-linejoin="round" transform="translate(0 -2) scale(1)"/>
<g fill="none" stroke="#e8dfc4" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"><path d="M34 74 L64 90 L94 74"/><path d="M34 92 L64 108 L94 92" stroke="#b9863a"/></g>''')

# 好心情: a smile, five little lights round it - one for each of the stats
GLYPHS["mood"] = ("#7a5a1c", "#1c1204", '''
<circle cx="64" cy="66" r="30" fill="#ffd45a" stroke="#7a4a08" stroke-width="3"/>
<circle cx="64" cy="66" r="30" fill="url(#bg)" fill-opacity="0"/>
<g fill="#5a3208"><ellipse cx="53" cy="60" rx="3.6" ry="5.2"/><ellipse cx="75" cy="60" rx="3.6" ry="5.2"/></g>
<path d="M48 74 Q64 92 80 74" fill="none" stroke="#5a3208" stroke-width="4" stroke-linecap="round"/>
<g fill="#ff9a8a" fill-opacity="0.7"><ellipse cx="44" cy="72" rx="5" ry="3"/><ellipse cx="84" cy="72" rx="5" ry="3"/></g>
<g stroke="#fff3b0" stroke-width="2" stroke-opacity="0.8"><circle cx="64" cy="66" r="30" fill="none"/></g>
<circle cx="64" cy="20" r="6" fill="#e88a7a" stroke="#fff" stroke-opacity="0.6"/>
<circle cx="102" cy="48" r="6" fill="#8fa9cf" stroke="#fff" stroke-opacity="0.6"/>
<circle cx="90" cy="100" r="6" fill="#7fd08a" stroke="#fff" stroke-opacity="0.6"/>
<circle cx="38" cy="100" r="6" fill="#e8c24a" stroke="#fff" stroke-opacity="0.6"/>
<circle cx="26" cy="48" r="6" fill="#9fe6a8" stroke="#fff" stroke-opacity="0.6"/>''')

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for k, (c1, c0, g) in GLYPHS.items():
        with open(os.path.join(out, k + ".svg"), "w") as f:
            f.write(medallion(c1, c0, g))
    print("wrote", len(GLYPHS), "to", out)
