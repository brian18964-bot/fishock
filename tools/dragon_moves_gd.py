"""scripts/dragon_moves.gd from the dragons' builds' OUT.moves.json (tools/dragon_moves.py): what
came out of each of their moves - how long it is, how far forward and aside it goes and how far it
turns, sampled - for the game to match its steps to the ground and turn the body with its feet.

  python3 tools/dragon_moves_gd.py dragon=RED.glb.moves.json dragon_black=BLACK.glb.moves.json
"""
import json
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "dragon_moves.gd")

data = {}
for arg in sys.argv[1:]:
    model, path = arg.split("=", 1)
    with open(path) as f:
        data[model] = json.load(f)
with open(OUT, "w") as f:
    f.write("class_name DragonMoves\nextends RefCounted\n\n")
    f.write("## The dragons' moves (tools/dragon_moves.py): per model, per clip - its length (s), whether it\n")
    f.write("## loops, its kind, and what was taken out of it to keep it on the spot, sampled `rate` a second:\n")
    f.write("## how far it goes forward (`fwd`, m, the model's own size) and aside (`side`, to its left) and\n")
    f.write("## how far it turns (`turn`, degrees, to its left); a loop's `trip` - how far one loop goes;\n")
    f.write("## `stride`: the share of that its feet cover (its legs' swing was scaled to it); `feet`: its\n")
    f.write("## left foot's lead over its right at each sample (m) - where a move's step is, to go on from it;\n")
    f.write("## `planted`: how fast (m/s, its size) its planted foot goes back under it - the pace it walks at.\n")
    f.write("## Written by tools/dragon_moves_gd.py from the builds - not by hand.\n\n")
    f.write("const MOVES := ")
    f.write(json.dumps(data, indent="\t", sort_keys=True))
    f.write("\n")
print("wrote", OUT, ", ".join("%s: %d moves" % (m, len(v)) for m, v in data.items()))
