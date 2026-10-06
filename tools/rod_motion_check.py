"""Round 5, item 3: the rod's motion on screen from a sheet's rod data
(the game's own input), the way player_visual.gd plays it.

  cast        per facing, each step f1..f8: screen turn (deg), grip jump
              (px), the rod's screen length / its longest (=sin of its
              angle to the line of sight) - a turn over 90 deg with a
              short rod is the rod swinging past the line of sight
              (projection flip), not the hand turning back
  release     charge frame k (0-3, by charge time) straight to the whip's
              first frame (4): a quick tap skips the wind-up
  loops       hold/reel/fight/hold_run last frame -> first, against the
              largest step inside the loop
  switches    the phase is shared: clip A at frame i -> clip B at i or
              i+1 (hold<->reel, hold<->fight, reel<->fight, hold<->hold_run,
              cast f8 (end of whip) -> hold at any frame)

    python3 tools/rod_motion_check.py ROD.json OUT.json
"""
import itertools
import json
import math
import sys

DIRS = ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
LOOPS = ("hold", "reel", "fight", "hold_run")


def vec(c):
    return c[2] - c[0], c[3] - c[1]


def turn(a, b):
    va, vb = vec(a), vec(b)
    if math.hypot(*va) < 1 or math.hypot(*vb) < 1:
        return 0.0
    d = abs(math.degrees(math.atan2(va[1], va[0]) - math.atan2(vb[1], vb[0]))) % 360
    return min(d, 360 - d)


def step(a, b):
    return {"turn": round(turn(a, b), 1), "grip_jump": round(math.hypot(b[0] - a[0], b[1] - a[1]), 2),
            "tip_jump": round(math.hypot(b[2] - a[2], b[3] - a[3]), 2)}


def main():
    src, out = sys.argv[1:3]
    rod = json.load(open(src))["rod"]
    full = max(math.hypot(*vec(c)) for n in rod for row in rod[n] for c in row if c)
    rep = {"rod_full_px": round(full, 1), "cast": {}, "release": {}, "loops": {}, "switches": {}}
    for di, dn in enumerate(DIRS):
        cells = rod["cast"][di]
        rows = []
        for i in range(7):
            s = step(cells[i], cells[i + 1])
            ra, rb = math.hypot(*vec(cells[i])) / full, math.hypot(*vec(cells[i + 1])) / full
            s.update({"from": i + 1, "to": i + 2, "len_ratio": [round(ra, 2), round(rb, 2)],
                      "sight_deg": [round(math.degrees(math.asin(min(1, ra))), 1),
                                    round(math.degrees(math.asin(min(1, rb))), 1)],
                      "behind": [cells[i][4], cells[i + 1][4]]})
            s["projection_flip"] = s["turn"] > 90 and min(ra, rb) < 0.5
            rows.append(s)
        rep["cast"][dn] = rows
        rep["release"][dn] = [dict(step(cells[k], cells[4]), charge_frame=k + 1) for k in range(4)]
        for n in LOOPS:
            c = rod[n][di]
            inside = [step(c[i], c[i + 1]) for i in range(7)]
            seam = step(c[7], c[0])
            rep["loops"].setdefault(n, {})[dn] = {
                "seam": seam, "max_inside_turn": max(s["turn"] for s in inside),
                "max_inside_jump": max(s["grip_jump"] for s in inside)}
        for a, b in itertools.permutations(LOOPS, 2):
            worst = {"turn": 0, "grip_jump": 0}
            for i in range(8):
                for j in (i, (i + 1) % 8):
                    s = step(rod[a][di][i], rod[b][di][j])
                    if s["grip_jump"] > worst["grip_jump"] or s["turn"] > worst["turn"]:
                        worst = {"turn": max(worst["turn"], s["turn"]),
                                 "grip_jump": max(worst["grip_jump"], s["grip_jump"])}
            rep["switches"].setdefault("%s->%s" % (a, b), {})[dn] = worst
        end = rod["cast"][di][7]
        rep["switches"].setdefault("cast_end->hold", {})[dn] = {
            "turn": max(round(turn(end, c), 1) for c in rod["hold"][di]),
            "grip_jump": max(round(math.hypot(c[0] - end[0], c[1] - end[1]), 2) for c in rod["hold"][di])}
    json.dump(rep, open(out, "w"), indent=1)
    # summary
    for dn in DIRS:
        flips = [(r["from"], r["to"], r["turn"], r["sight_deg"]) for r in rep["cast"][dn] if r["projection_flip"]]
        big = max(rep["cast"][dn][:3], key=lambda r: r["turn"])
        print("CAST", dn, "charge max turn %.1f at f%d->f%d" % (big["turn"], big["from"], big["to"]), "flips", flips)
        print("REL ", dn, [(r["charge_frame"], r["turn"], r["grip_jump"]) for r in rep["release"][dn]])
    for n in LOOPS:
        print("LOOP", n, "seam max turn %.1f jump %.2f | inside max turn %.1f jump %.2f" % (
            max(v["seam"]["turn"] for v in rep["loops"][n].values()),
            max(v["seam"]["grip_jump"] for v in rep["loops"][n].values()),
            max(v["max_inside_turn"] for v in rep["loops"][n].values()),
            max(v["max_inside_jump"] for v in rep["loops"][n].values())))
    for k, v in rep["switches"].items():
        print("SW  ", k, "turn %.1f jump %.2f" % (max(x["turn"] for x in v.values()), max(x["grip_jump"] for x in v.values())))


if __name__ == "__main__":
    main()
