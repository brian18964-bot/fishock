"""The black two-tailed dragon ghost's measures (tools/build_dragon_warden.py): the first dragon the
user had Meshy make ("Crimson Wyrm Warden" - kept out of the repo, its textured export in the ASSET1
release; the user's Meshy auto-rig of it for the trunk's and the legs' joints - its arm chain went
into the wing, so the arms are measured here), rigged as finely as the red one
(tools/build_dragon_sage.py), whose build it runs with these in place of its own.

In Meshy's own frame: facing -y, its left +x, z about the mesh's middle (the ground at -LIFT).
Each joint (head, tail, parent) - the left side's; the right's mirrored. Plain tuples: no Blender
needed to read them (tools that draw the skeleton over pictures of the model use them too).
"""
LIFT = 0.895

TRUNK = {
    # (the auto-rig's hips, spine, neck)
    "pelvis": ((0, -0.235, 0.02), (0, -0.22, 0.126), "root"),
    "spine_01": ((0, -0.22, 0.126), (0, -0.202, 0.249), "pelvis"),
    "spine_02": ((0, -0.202, 0.249), (0, -0.182, 0.39), "spine_01"),
    "spine_03": ((0, -0.182, 0.39), (0, -0.162, 0.533), "spine_02"),
    "neck_01": ((0, -0.162, 0.533), (0, -0.159, 0.676), "spine_03"),
    "Head": ((0, -0.159, 0.676), (0, -0.20, 0.85), "neck_01"),
    # (the jaw: placed, not yet weighted - its mouth comes later)
    "jaw": ((0, -0.27, 0.70), (0, -0.39, 0.67), "Head"),
}
SIDE = {
    "clavicle": ((0.04, -0.17, 0.43), (0.24, -0.2, 0.41), "spine_03"),
    "upperarm": ((0.24, -0.2, 0.41), (0.37, -0.15, 0.14), "clavicle"),
    "lowerarm": ((0.37, -0.15, 0.14), (0.47, -0.27, -0.02), "upperarm"),
    "hand": ((0.47, -0.27, -0.02), (0.515, -0.29, -0.065), "lowerarm"),
    # (the auto-rig's legs)
    "thigh": ((0.052, -0.263, -0.039), (0.215, -0.206, -0.424), "pelvis"),
    "calf": ((0.215, -0.206, -0.424), (0.264, -0.122, -0.769), "thigh"),
    "foot": ((0.264, -0.122, -0.769), (0.29, -0.346, -0.864), "calf"),
    "ball": ((0.29, -0.346, -0.864), (0.31, -0.427, -0.877), "foot"),
    # the wing: the arm to the elbow, to the wrist, the hand
    "wing": ((0.12, -0.04, 0.45), (0.22, -0.06, 0.68), "spine_03"),
    "wing_02": ((0.22, -0.06, 0.68), (0.31, -0.068, 0.86), "wing"),
    "wing_03": ((0.31, -0.068, 0.86), (0.345, -0.064, 0.835), "wing_02"),
}
# (its hand has a thumb and three fingers: the ring finger and the little one share the outer one)
HAND = {
    "thumb": [(0.452, -0.30, -0.05), (0.43, -0.315, -0.075), (0.405, -0.325, -0.10), (0.39, -0.33, -0.135)],
    "index": [(0.489, -0.30, -0.075), (0.485, -0.33, -0.116), (0.478, -0.345, -0.15), (0.472, -0.335, -0.177)],
    "middle": [(0.524, -0.29, -0.07), (0.527, -0.32, -0.12), (0.522, -0.335, -0.16), (0.516, -0.32, -0.197)],
    "ring": [(0.549, -0.275, -0.068), (0.569, -0.30, -0.125), (0.562, -0.30, -0.15), (0.549, -0.29, -0.16)],
    "pinky": [(0.55, -0.262, -0.07), (0.57, -0.28, -0.12), (0.565, -0.28, -0.145), (0.555, -0.272, -0.158)],
}
WING = {
    # (traced on the mesh: where the membrane is thickest - its spars)
    "f1": [(0.345, -0.064, 0.835), (0.46, -0.072, 0.683), (0.64, -0.106, 0.52), (0.83, -0.163, 0.477),
           (0.95, -0.2, 0.30)],
    "f2": [(0.345, -0.064, 0.83), (0.52, -0.082, 0.617), (0.686, -0.116, 0.388), (0.807, -0.143, 0.178),
           (0.866, -0.157, 0.0)],
    "f3": [(0.34, -0.064, 0.825), (0.40, -0.061, 0.65), (0.47, -0.073, 0.46), (0.51, -0.095, 0.286),
           (0.548, -0.112, 0.03)],
}
# The two tails: the one swept out to its right and forward round its leg (as made), the other
# hanging down its back
TAIL_LINE = [(0, -0.02, 0.05), (-0.13, 0.17, 0.0), (-0.3, 0.22, -0.15), (-0.39, 0.17, -0.31),
             (-0.47, 0.09, -0.45), (-0.62, -0.01, -0.565), (-0.78, -0.085, -0.63), (-0.96, -0.165, -0.745)]
TAIL2_LINE = [(0, -0.04, 0.04), (0, 0.12, 0.0), (0, 0.22, -0.1), (0, 0.28, -0.22), (0, 0.34, -0.33),
              (0, 0.385, -0.45), (0, 0.395, -0.6), (0, 0.38, -0.785)]
# (user request: the main tail swept to one side, one big and one small, looked wrong - both one
# size, both behind it: the main one shortened to the second's length, its width near kept, both
# posed as the second hangs, each swung this far out to its side; past `root` from its root a
# tail's skin all its own)
TAILS_EVEN = {"spread": 28.0, "thick": 0.95, "root": 0.12}
# (the robe's skirt: the belt's middle, x and y)
SKIRT_CENTRE = (0.0, -0.21)
# Its head (stage 3): the lips' line (y, z at the snout's tip and at the mouth's corner - level, the
# snout short and the lower jaw thin), how far back it's cut and how wide; the jaw's fade into the
# throat (y, z); the snout's box and how far back / low its jaw's skin can be; the skull rigid ahead
# of the neck (y, z) and its horns above
JAW_LIP = ((-0.394, 0.677), (-0.31, 0.668))
JAW_CORNER = -0.31
JAW_WIDE = 0.06
JAW_FADE = ((-0.275, -0.35), (0.62, 0.64))
SNOUT_BOX = (0.07, 0.6, 0.71)
JAW_REACH = (-0.285, 0.6)
SKULL = ((-0.24, -0.28), (0.64, 0.66))
SKULL_HORNS = 0.80
# its eyes: in its own sockets, where the first dragon's were (the user's: the dark almond under the
# brow); red, as its lantern
EYE = {"at": (-0.322, 0.732), "r": 0.0075, "tall": 0.42, "out": 0.4, "deep": 0.6, "slant": 15.0,
       "look": (1.0, -0.6, 0.1)}
EYE_SOCKET = {"across": 0.006, "along": 0.011, "deep": 0.0015, "brow": 0.0012}
EYE_RED = ((1.0, 0.6, 0.35), (0.95, 0.14, 0.08), (0.3, 0.03, 0.02))
EYE_GLOW_TINT = (1.0, 0.22, 0.18)
# its teeth along its shorter snout (its lower jaw ~1 cm thick: the upper teeth shorter, so shut
# they stay inside it)
TEETH_Y = (-0.386, -0.318)
TEETH_UPPER = (0.007, 0.012, 0.011, 0.010, 0.009, 0.008, 0.008, 0.007)
TEETH_LOWER = (0.006, 0.010, 0.009, 0.008, 0.008, 0.007, 0.006)
# its skin black (measured: its red 0.49 bright, 0.59 saturated): brightness, saturation (from, to,
# spread kept)
SKIN_TONE = {"v": (0.486, 0.13, 0.5), "s": (0.586, 0.35, 0.6)}
# its robe lighter (user request): its dark grey cloth this much brighter
ROBE_LIGHTEN = 1.8
