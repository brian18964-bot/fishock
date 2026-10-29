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

# 神經反射: a brain with a bolt through it
GLYPHS["reflex"] = ("#5a2a30", "#14070a", '''
<g fill="#e07a6a" stroke="#5a1a14" stroke-width="2.5" stroke-linejoin="round">
<path d="M64 30 C54 20 36 24 34 38 C22 40 20 56 28 62 C22 72 30 86 42 84 C46 94 62 96 64 88 C66 96 82 94 86 84 C98 86 106 72 100 62 C108 56 106 40 94 38 C92 24 74 20 64 30 Z"/></g>
<g fill="none" stroke="#f5b0a0" stroke-width="2.5" stroke-linecap="round" stroke-opacity="0.85"><path d="M64 32 V86"/><path d="M46 44 q8 4 6 14"/><path d="M82 44 q-8 4 -6 14"/><path d="M40 66 q8 -2 12 6"/><path d="M88 66 q-8 -2 -12 6"/></g>
<path d="M76 10 L50 62 H66 L56 118 L92 52 H74 Z" fill="#ffd45a" stroke="#7a4a08" stroke-width="3" stroke-linejoin="round"/>
<path d="M74 22 L58 54" stroke="#fff3b0" stroke-width="3" stroke-linecap="round" fill="none"/>''')

# 重量訓練: a dumbbell
GLYPHS["weights"] = ("#2a3c5a", "#070c18", '''
<rect x="38" y="57" width="52" height="14" rx="4" fill="#efe6c8" stroke="#6a6248" stroke-width="2"/>
<g fill="#7f98bd" stroke="#0e1830" stroke-width="3"><rect x="14" y="38" width="20" height="52" rx="5"/><rect x="94" y="38" width="20" height="52" rx="5"/>
<rect x="30" y="30" width="16" height="68" rx="5"/><rect x="82" y="30" width="16" height="68" rx="5"/></g>
<g fill="#c8d8f0" fill-opacity="0.75"><rect x="34" y="34" width="5" height="60" rx="2"/><rect x="86" y="34" width="5" height="60" rx="2"/><rect x="18" y="42" width="5" height="44" rx="2"/><rect x="98" y="42" width="5" height="44" rx="2"/></g>''')

# 技巧洩力: a rod, its line loosely looped (the strain let out)
GLYPHS["leak"] = ("#1e4a56", "#04141a", '''
<path d="M20 108 C34 72 62 40 96 24" fill="none" stroke="#f0e6c8" stroke-width="5" stroke-linecap="round"/>
<path d="M20 108 C34 72 62 40 96 24" fill="none" stroke="#b8a070" stroke-width="1.5" stroke-linecap="round" stroke-dasharray="2 9"/>
<path d="M96 24 C112 36 108 60 96 70 C86 78 78 96 86 108" fill="none" stroke="#7fcf8a" stroke-width="3.5" stroke-linecap="round"/>
<g fill="#c8864a" stroke="#4a2a0c" stroke-width="2"><rect x="14" y="96" width="14" height="20" rx="5" transform="rotate(25 21 106)"/></g>
<circle cx="40" cy="76" r="7" fill="#d9d9e8" stroke="#3a3a50" stroke-width="2.5"/><circle cx="40" cy="76" r="2.5" fill="#3a3a50"/>
<g fill="none" stroke="#9fe6c8" stroke-width="2.5" stroke-linecap="round" stroke-opacity="0.8"><path d="M100 84 q10 2 14 -4"/><path d="M96 94 q12 4 18 -4"/></g>''')

# 咬緊牙關: a rod and the clock - holding on a long time
GLYPHS["grit"] = ("#5a3a1c", "#150c04", '''
<path d="M16 108 C30 72 60 38 100 22" fill="none" stroke="#f0e6c8" stroke-width="5" stroke-linecap="round"/>
<path d="M100 22 C114 24 120 36 116 46" fill="none" stroke="#f0e6c8" stroke-width="2" stroke-linecap="round"/>
<g fill="#c8864a" stroke="#4a2a0c" stroke-width="2"><rect x="10" y="96" width="14" height="20" rx="5" transform="rotate(25 17 106)"/></g>
<circle cx="36" cy="78" r="7" fill="#d9d9e8" stroke="#3a3a50" stroke-width="2.5"/><circle cx="36" cy="78" r="2.5" fill="#3a3a50"/>
<circle cx="88" cy="86" r="26" fill="#2a1a0a" stroke="#e8b84a" stroke-width="6"/>
<circle cx="88" cy="86" r="20" fill="#f6ecd0"/>
<g stroke="#5a3a1c" stroke-width="2" stroke-linecap="round"><path d="M88 70 v4"/><path d="M88 98 v4"/><path d="M72 86 h4"/><path d="M100 86 h4"/></g>
<path d="M88 86 V74 M88 86 L97 92" fill="none" stroke="#3a2008" stroke-width="3.5" stroke-linecap="round"/><circle cx="88" cy="86" r="2.5" fill="#3a2008"/>''')

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

# 有經驗: a worn book with a fish on its cover
GLYPHS["veteran"] = ("#2a3a50", "#070c14", '''
<path d="M22 42 L72 30 L106 44 L106 98 L72 88 L22 98 Z" fill="#d8c8a0" stroke="#4a3a1c" stroke-width="2.5" stroke-linejoin="round"/>
<path d="M22 42 L72 30 L72 88 L22 98 Z" fill="#587398" stroke="#1a2a44" stroke-width="3" stroke-linejoin="round"/>
<path d="M72 30 L106 44 L106 98 L72 88 Z" fill="#6a85aa" stroke="#1a2a44" stroke-width="3" stroke-linejoin="round" fill-opacity="0"/>
<path d="M22 98 L72 88 L106 98" fill="none" stroke="#8a7a52" stroke-width="2"/>
<g fill="#f0e6d0" stroke="#2a3a50" stroke-width="1.5"><path d="M34 66 C42 52 58 50 66 60 C58 70 42 78 34 66 Z"/><path d="M66 60 L74 52 L74 70 Z"/></g>
<circle cx="45" cy="62" r="2" fill="#2a3a50"/>
<g fill="none" stroke="#b9a878" stroke-width="2"><path d="M80 52 L98 58"/><path d="M80 62 L98 68"/><path d="M80 72 L98 78"/></g>''')

# 好心情: a heart and a note
GLYPHS["mood"] = ("#5a2a30", "#14070a", '''
<path d="M44 106 C16 86 14 56 34 48 C46 44 56 52 58 62 C60 52 70 44 82 48 C100 56 96 86 70 104 Z" transform="translate(-6 0)" fill="#d8453a" stroke="#5a0e0a" stroke-width="3" stroke-linejoin="round"/>
<path d="M30 56 C34 50 42 50 46 56" fill="none" stroke="#f5a090" stroke-width="3" stroke-linecap="round"/>
<g fill="#f6ecd0" stroke="#5a4a30" stroke-width="2.5" stroke-linejoin="round"><ellipse cx="86" cy="90" rx="11" ry="8" transform="rotate(-20 86 90)"/>
<path d="M95 88 V30 C104 34 114 40 112 54 C108 46 102 44 99 44 V88 Z"/></g>''')

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for k, (c1, c0, g) in GLYPHS.items():
        with open(os.path.join(out, k + ".svg"), "w") as f:
            f.write(medallion(c1, c0, g))
    print("wrote", len(GLYPHS), "to", out)
