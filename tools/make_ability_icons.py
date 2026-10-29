"""The seven character abilities' icons, drawn after the user's sheet (an eye, a
dog's nose with scent, a paw print, antlers with a leaf, a wool curl with berries
and a leaf, a crocodile's head) in the medallion of tools/make_talent_icons.py. The
cat's (夜貓子) is kept as it was.

  python3 tools/make_ability_icons.py OUT_DIR     (writes OUT_DIR/<kind>.svg)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_talent_icons import medallion  # noqa: E402

G = {}

# 夜視: a wide amber eye
G["owl"] = ("#1d3352", "#060b16", '''
<path d="M10 64 C30 30 98 30 118 64 C98 98 30 98 10 64 Z" fill="#f0e6cc" stroke="#2a2418" stroke-width="3"/>
<path d="M4 54 C20 40 30 36 40 38 C28 44 20 52 14 62 Z M124 54 C108 40 98 36 88 38 C100 44 108 52 114 62 Z" fill="#f6efe0"/>
<circle cx="64" cy="64" r="26" fill="#e8a030" stroke="#7a4a08" stroke-width="3"/>
<circle cx="64" cy="64" r="15" fill="#120a04"/>
<circle cx="56" cy="55" r="6" fill="#fff"/><circle cx="72" cy="72" r="3" fill="#fff" fill-opacity="0.7"/>''')

# 敏感嗅覺: a dog's muzzle, the scent coming to its nose
G["dog"] = ("#4a3a1e", "#140f06", '''
<path d="M14 100 C10 70 20 56 44 54 C66 52 84 60 92 78 C96 90 90 104 76 106 L26 108 Z" fill="#e0a238" stroke="#5a380a" stroke-width="3" stroke-linejoin="round"/>
<path d="M14 100 C12 86 18 78 28 76 C40 74 60 84 66 98 L60 108 L22 108 Z" fill="#b87a1c" fill-opacity="0.55"/>
<ellipse cx="88" cy="76" rx="14" ry="11" fill="#0a0806" stroke="#3a2a0a" stroke-width="2"/><ellipse cx="85" cy="72" rx="4" ry="2.5" fill="#fff" fill-opacity="0.5"/>
<g fill="none" stroke="#7fcf8a" stroke-width="4" stroke-linecap="round"><path d="M100 22 C108 30 96 36 104 44 C108 48 106 52 104 56"/><path d="M76 20 C84 28 72 34 80 42 C84 46 84 52 82 56"/><path d="M52 24 C60 32 50 38 58 46"/></g>
<g fill="#e0a238"><circle cx="30" cy="40" r="3"/><circle cx="20" cy="50" r="2"/></g>''')

# 展現力量: a paw print
G["bear"] = ("#6a2a1a", "#1c0806", '''
<g fill="#e8a64a" stroke="#6a380a" stroke-width="3" stroke-linejoin="round">
<path d="M64 62 C44 62 28 84 34 100 C38 110 52 108 64 104 C76 108 90 110 94 100 C100 84 84 62 64 62 Z"/>
<ellipse cx="30" cy="54" rx="10" ry="14" transform="rotate(-25 30 54)"/><ellipse cx="50" cy="36" rx="10" ry="15" transform="rotate(-8 50 36)"/>
<ellipse cx="78" cy="36" rx="10" ry="15" transform="rotate(8 78 36)"/><ellipse cx="98" cy="54" rx="10" ry="14" transform="rotate(25 98 54)"/></g>
<path d="M44 80 C48 72 60 70 66 74" fill="none" stroke="#fff3c0" stroke-opacity="0.6" stroke-width="3.5" stroke-linecap="round"/>''')

# 森林友好: antlers round a leaf
G["deer"] = ("#1e4a26", "#061408", '''
<g fill="none" stroke="#f0e6c8" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
<path d="M52 100 C46 80 40 64 30 50 M40 66 C30 66 22 60 18 50 M44 74 C36 78 28 78 22 74 M34 54 C34 42 30 32 24 24"/>
<path d="M76 100 C82 80 88 64 98 50 M88 66 C98 66 106 60 110 50 M84 74 C92 78 100 78 106 74 M94 54 C94 42 98 32 104 24"/></g>
<path d="M64 112 C46 100 46 70 64 50 C82 70 82 100 64 112 Z" fill="#6fcf7e" stroke="#0e3a1a" stroke-width="3" stroke-linejoin="round"/>
<path d="M64 108 V62" stroke="#0e3a1a" stroke-width="2.5" stroke-linecap="round"/><path d="M64 92 L54 84 M64 80 L74 72 M64 70 L56 64" fill="none" stroke="#0e3a1a" stroke-width="2" stroke-linecap="round"/>''')

# 採集高手: a wool curl, berries and a leaf
G["sheep"] = ("#5a5232", "#18160a", '''
<path d="M64 30 C36 26 22 54 34 72 C42 84 62 86 70 74 C78 62 68 48 56 52 C48 54 46 64 54 66" fill="none" stroke="#f6efdc" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M64 30 C90 28 104 50 96 68" fill="none" stroke="#f6efdc" stroke-width="12" stroke-linecap="round"/>
<path d="M64 30 C36 26 22 54 34 72 C42 84 62 86 70 74 C78 62 68 48 56 52 C48 54 46 64 54 66" fill="none" stroke="#c8bda0" stroke-width="2" stroke-linecap="round" stroke-opacity="0.7" transform="translate(0 0)"/>
<path d="M82 92 C80 74 96 66 108 72 C108 86 96 96 82 92 Z" fill="#6fcf7e" stroke="#0e3a1a" stroke-width="3" stroke-linejoin="round"/>
<g fill="#d8453a" stroke="#5a0e0a" stroke-width="2.5"><circle cx="34" cy="98" r="11"/><circle cx="60" cy="102" r="11"/></g>
<g fill="#fff" fill-opacity="0.6"><circle cx="30" cy="94" r="3"/><circle cx="56" cy="98" r="3"/></g>''')

# 水中霸王: a crocodile's head, jaws open
G["croc"] = ("#14455a", "#04121a", '''
<path d="M8 84 L8 70 C24 58 56 40 92 36 C108 34 120 42 122 56 C112 54 104 56 98 60 C84 62 40 76 8 84 Z" fill="#6fa83a" stroke="#1a3a0c" stroke-width="3" stroke-linejoin="round"/>
<path d="M8 84 C40 96 84 100 112 92 C118 88 122 82 122 76 C108 72 98 70 90 70 C60 76 30 80 8 84 Z" fill="#4f8a2c" stroke="#1a3a0c" stroke-width="3" stroke-linejoin="round"/>
<g fill="#fff"><path d="M16 74 l5 -12 5 11z"/><path d="M32 70 l5 -12 5 10z"/><path d="M50 64 l5 -11 5 9z"/><path d="M68 60 l4 -10 5 8z"/><path d="M20 86 l5 11 5 -12z"/><path d="M38 90 l5 11 5 -12z"/><path d="M58 92 l5 10 5 -12z"/><path d="M78 92 l4 9 5 -11z"/></g>
<ellipse cx="96" cy="50" rx="8" ry="6" fill="#f0d04a" stroke="#1a3a0c" stroke-width="2.5"/><ellipse cx="96" cy="50" rx="2" ry="5" fill="#120a04"/>
<path d="M14 50 C24 44 34 46 40 52" fill="none" stroke="#a8d870" stroke-width="3" stroke-linecap="round" stroke-opacity="0.7"/>
<path d="M0 108 C20 100 30 112 52 106 C74 100 84 112 104 104 C112 100 120 104 128 106 V128 H0 Z" fill="#2e8aa8" fill-opacity="0.85"/>''')

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for k, (c1, c0, g) in G.items():
        with open(os.path.join(out, k + ".svg"), "w") as f:
            f.write(medallion(c1, c0, g))
    print("wrote", len(G), "to", out)
