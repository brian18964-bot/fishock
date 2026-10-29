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
<clipPath id="cut"><circle cx="64" cy="64" r="54"/></clipPath>
</defs>
<circle cx="64" cy="64" r="60" fill="url(#rim)"/>
<circle cx="64" cy="64" r="54" fill="url(#bg)"/>
<circle cx="64" cy="64" r="54" fill="none" stroke="#000" stroke-opacity="0.45" stroke-width="2"/>
<g clip-path="url(#cut)">{glyph}</g>
</svg>
'''


GLYPHS = {}

# 神經反射: a brain and one bolt
GLYPHS["reflex"] = ("#5a2a30", "#14070a", '''
<path d="M64 34 C56 22 34 24 32 42 C20 44 18 62 28 68 C22 80 32 94 46 90 C50 100 62 100 64 92 C66 100 78 100 82 90 C96 94 106 80 100 68 C110 62 108 44 96 42 C94 24 72 22 64 34 Z" fill="#e8806e" stroke="#5a1a14" stroke-width="3" stroke-linejoin="round"/>
<path d="M64 36 V92" fill="none" stroke="#b5503e" stroke-width="3" stroke-linecap="round"/>
<path d="M44 52 q10 4 8 14 M84 52 q-10 4 -8 14" fill="none" stroke="#b5503e" stroke-width="3" stroke-linecap="round"/>
<path d="M78 12 L50 64 H68 L56 116 L94 54 H74 Z" fill="#ffd45a" stroke="#7a4a08" stroke-width="3" stroke-linejoin="round"/>
<path d="M75 26 L60 54" stroke="#fff3b0" stroke-width="3" stroke-linecap="round" fill="none"/>''')

# 重量訓練: a dumbbell
GLYPHS["weights"] = ("#2a3c5a", "#070c18", '''
<rect x="38" y="57" width="52" height="14" rx="4" fill="#efe6c8" stroke="#6a6248" stroke-width="2"/>
<g fill="#7f98bd" stroke="#0e1830" stroke-width="3"><rect x="14" y="38" width="20" height="52" rx="5"/><rect x="94" y="38" width="20" height="52" rx="5"/>
<rect x="30" y="30" width="16" height="68" rx="5"/><rect x="82" y="30" width="16" height="68" rx="5"/></g>
<g fill="#c8d8f0" fill-opacity="0.75"><rect x="34" y="34" width="5" height="60" rx="2"/><rect x="86" y="34" width="5" height="60" rx="2"/><rect x="18" y="42" width="5" height="44" rx="2"/><rect x="98" y="42" width="5" height="44" rx="2"/></g>''')

# 技巧卸力: the rod drawn out, the line left slack
GLYPHS["leak"] = ("#1e4a56", "#04141a", '''
<path d="M18 110 C34 80 62 46 100 30" fill="none" stroke="#f0e6c8" stroke-width="5" stroke-linecap="round"/>
<g fill="#c8864a" stroke="#4a2a0c" stroke-width="2"><rect x="10" y="98" width="14" height="20" rx="5" transform="rotate(25 17 108)"/></g>
<circle cx="38" cy="82" r="7" fill="#d9d9e8" stroke="#3a3a50" stroke-width="2.5"/><circle cx="38" cy="82" r="2.5" fill="#3a3a50"/>
<path d="M100 30 C106 56 96 82 82 92 C70 100 56 108 50 100" fill="none" stroke="#9fe6c8" stroke-width="2.5" stroke-linecap="round"/>
<path d="M50 100 q-6 6 0 12" fill="none" stroke="#9fe6c8" stroke-width="2.5" stroke-linecap="round"/>
<circle cx="84" cy="94" r="5" fill="#e04a3a" stroke="#fff" stroke-width="1.5"/>''')

# 咬緊牙關: the rod bowed full, and the clock
GLYPHS["grit"] = ("#5a3a1c", "#150c04", '''
<path d="M108 60 L56 106" fill="none" stroke="#b8d8f0" stroke-width="2"/>
<path d="M24 106 C26 56 58 28 92 34 C104 36 110 48 108 60" fill="none" stroke="#f0e6c8" stroke-width="6" stroke-linecap="round"/>
<g fill="#c8864a" stroke="#4a2a0c" stroke-width="2"><rect x="16" y="98" width="14" height="22" rx="5" transform="rotate(-8 23 109)"/></g>
<circle cx="40" cy="62" r="6" fill="#d9d9e8" stroke="#3a3a50" stroke-width="2.5"/>
<circle cx="88" cy="88" r="22" fill="#2a1a0a" stroke="#e8b84a" stroke-width="5"/>
<circle cx="88" cy="88" r="17" fill="#f6ecd0"/>
<g stroke="#5a3a1c" stroke-width="2" stroke-linecap="round"><path d="M88 74 v3"/><path d="M88 99 v3"/><path d="M74 88 h3"/><path d="M99 88 h3"/></g>
<path d="M88 88 V77 M88 88 L96 93" fill="none" stroke="#3a2008" stroke-width="3" stroke-linecap="round"/><circle cx="88" cy="88" r="2.2" fill="#3a2008"/>''')

# LUCKY!: a four-leaf clover
GLYPHS["lucky"] = ("#1d4a2c", "#04120a", '''
<path d="M64 64 C62 90 70 106 84 116" fill="none" stroke="#5fb870" stroke-width="6" stroke-linecap="round"/>
<g fill="#6fcf7e" stroke="#0e3a1a" stroke-width="2.5" stroke-linejoin="round">
<path d="M64 62 C40 60 28 36 42 22 C54 12 66 28 64 46 Z"/><path d="M64 62 C88 60 100 36 86 22 C74 12 62 28 64 46 Z"/>
<path d="M64 66 C40 68 28 92 42 106 C54 116 66 100 64 82 Z"/><path d="M64 66 C88 68 100 92 86 106 C74 116 62 100 64 82 Z"/></g>
<g fill="none" stroke="#b8f0be" stroke-width="2.5" stroke-linecap="round" stroke-opacity="0.7"><path d="M62 54 C52 46 46 36 46 28"/><path d="M66 54 C76 46 82 36 82 28"/><path d="M62 74 C52 82 46 92 46 100"/><path d="M66 74 C76 82 82 92 82 100"/></g>
<circle cx="64" cy="64" r="4" fill="#ffe08a"/>''')

# 狠角色: the man in black - a black figure, a pale sinister grin and narrowed white eyes
GLYPHS["tough"] = ("#3a2a4a", "#0a0610", '''
<path d="M10 128 C14 100 34 90 64 88 C94 90 114 100 118 128 Z" fill="#06040a"/>
<path d="M48 90 L64 108 L80 90 Z" fill="#14101c"/>
<ellipse cx="64" cy="56" rx="30" ry="36" fill="#06040a"/>
<path d="M34 44 C40 20 88 20 94 44 C80 36 48 36 34 44 Z" fill="#0c0814"/>
<path d="M40 54 L58 60 L56 66 L38 62 Z" fill="#fff" transform="translate(0 -4)"/>
<path d="M88 54 L70 60 L72 66 L90 62 Z" fill="#fff" transform="translate(0 -4)"/>
<g fill="#d8d0ff" fill-opacity="0.35"><ellipse cx="49" cy="58" rx="10" ry="3.5" transform="rotate(14 49 58)"/><ellipse cx="79" cy="58" rx="10" ry="3.5" transform="rotate(-14 79 58)"/></g>
<path d="M38 76 C50 90 78 90 90 76 C84 82 44 82 38 76 Z" fill="#fff"/>
<path d="M38 76 C50 92 78 92 90 76" fill="none" stroke="#fff" stroke-width="2"/>
<g stroke="#06040a" stroke-width="2"><path d="M46 80 v6"/><path d="M54 83 v7"/><path d="M64 84 v8"/><path d="M74 83 v7"/><path d="M82 80 v6"/></g>''')

# 有經驗: a book printed with a fish silhouette
GLYPHS["veteran"] = ("#2a3a50", "#070c14", '''
<path d="M30 20 H92 C98 20 102 24 102 30 V100 C102 106 98 110 92 110 H30 Z" fill="#e6dcc0" stroke="#4a3a1c" stroke-width="2.5"/>
<path d="M24 20 C24 20 24 20 30 20 V110 H26 C22 110 20 106 20 102 V28 C20 23 22 20 26 20 Z" fill="#8a7a52"/>
<path d="M34 20 H92 C98 20 102 24 102 30 V96 C102 102 98 106 92 106 H34 Z" fill="#4f6d96" stroke="#1a2a44" stroke-width="3"/>
<path d="M34 20 V106" stroke="#1a2a44" stroke-width="3"/>
<g fill="#f0e8d0"><path d="M46 62 C56 44 80 42 90 58 C80 74 56 82 46 62 Z"/><path d="M46 62 L36 50 L38 74 Z" transform="translate(6 0)"/><path d="M84 60 L98 50 L98 70 Z" transform="translate(-4 0)"/></g>
<circle cx="76" cy="55" r="2.6" fill="#4f6d96"/>
<g fill="none" stroke="#f0e8d0" stroke-opacity="0.6" stroke-width="2.5" stroke-linecap="round"><path d="M44 30 H92"/><path d="M44 96 H92"/></g>''')

# 好心情: a heart and a note
GLYPHS["mood"] = ("#5a2a30", "#14070a", '''
<path d="M46 108 C14 86 12 52 34 44 C48 40 58 50 60 62 C62 50 72 40 86 44 C108 52 104 86 74 106 Z" transform="translate(-4 2)" fill="#d8453a" stroke="#5a0e0a" stroke-width="3" stroke-linejoin="round"/>
<path d="M26 54 C30 46 40 46 44 54" fill="none" stroke="#f5a090" stroke-width="3.5" stroke-linecap="round"/>
<g fill="#f6ecd0" stroke="#5a4a30" stroke-width="2.5" stroke-linejoin="round"><ellipse cx="88" cy="92" rx="12" ry="9" transform="rotate(-20 88 92)"/>
<path d="M98 90 V28 C108 32 118 40 116 56 C112 48 106 46 102 46 V90 Z"/></g>''')

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for k, (c1, c0, g) in GLYPHS.items():
        with open(os.path.join(out, k + ".svg"), "w") as f:
            f.write(medallion(c1, c0, g))
    print("wrote", len(GLYPHS), "to", out)
