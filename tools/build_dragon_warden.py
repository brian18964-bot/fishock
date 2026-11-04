"""The black two-tailed dragon ghost's body (user request): the first dragon the user had Meshy make
("Crimson Wyrm Warden" - its textured export in the ASSET1 release, kept out of the repo), rigged as
finely as the red one: tools/build_dragon_sage.py's whole build, run with this one's measures
(tools/dragon_warden_profile.py) in place of its own - each wing on fifteen bones, each hand's
fingers (its thumb and three; the ring finger and the little one share the outer one), the tail in
ten and its second tail in eight (tail_b01..), the robe's skirt on its chains.

  bpyenv/bin/python tools/build_dragon_warden.py -- WARDEN_FBX OLD_GLB OUT.glb

  WARDEN_FBX  Meshy's textured export (its pictures beside it, Meshy's names)
  OLD_GLB     the clips' source, as for the red one (its six clips carried onto this skeleton)

Stage one (user request, in stages - skeleton and weights; the second tail's motion; the black
skin, eyes and teeth; into the game): its mouth, eyes and skin colour are not made yet.
"""
import os
import sys

import bpy  # noqa: F401  (before mathutils)
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dragon_sage as B  # noqa: E402
import dragon_warden_profile as W  # noqa: E402


def _v(t):
    return Vector(t)


B.TRUNK = {n: (_v(h), _v(t), p) for n, (h, t, p) in W.TRUNK.items()}
B.SIDE = {n: (_v(h), _v(t), p) for n, (h, t, p) in W.SIDE.items()}
B.HAND = {f: [_v(p) for p in pts] for f, pts in W.HAND.items()}
B.WING = {f: [_v(p) for p in pts] for f, pts in W.WING.items()}
B.TAIL_LINE = [_v(p) for p in W.TAIL_LINE]
B.TAIL2_LINE = [_v(p) for p in W.TAIL2_LINE]
B.TAIL2_BONES = 8
# (its wings' fingertips end at z ~0.0; the arms held down in front of it, the membrane behind)
B.WING_LOW = -0.05
B.BACK_Y = -0.12
# (its robe: the belt's middle, as for the red one's skirt)
B.SKIRT_CENTRE = W.SKIRT_CENTRE
B.FEATURES = {"mouth": False, "eyes": False, "deepen": False, "skirt": True, "drape": False}


def _dense(co, th):
    # the wings' thin skin (out past its shoulders, above its knees), its hands (fingers to close)
    return (th < 0.016 and abs(co.x) > 0.3 and co.z > -0.05) \
        or (0.36 < abs(co.x) < 0.62 and co.y < -0.2 and -0.24 < co.z < 0.02)


B._dense = _dense

if __name__ == "__main__":
    B.main()
    os._exit(0)
