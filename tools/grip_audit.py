"""The rod in the hand, the game's current way against the candidate
(user request, round 4: check the hand keeps hold of the rod, the rod
doesn't slide or jump its angle, and what it passes in front of or
behind - not only fingertip distances).

In 3D, per hand clip and frame (render_player.py's clips on the bound
character, PLAYER / GREYBOX_DIR as render_player.py takes them):
  turn_in_hand  how far the rod's direction, in the hand's own frame, is
                from its mean over the clip (deg) - 0 when it's held;
                the current way points it by ROD_ANGLES whatever the hand
                does, so it turns in the hand
  fingertips    each fingertip's distance from the rod's surface (mm,
                character units): the current way's open hand, the
                candidate's closed one
  through       the rod's points past the hand inside the character
In 2D, from each sheet's rod data (the game's output: every facing):
  per clip and facing, the largest turn of the rod on screen from one
  frame to the next (deg) and the largest jump of the grip (px) - the
  cast's whip apart (frames 4-7 are meant to be fast).

    PLAYER=cat GREYBOX_DIR=... bpyenv/bin/python tools/grip_audit.py MIXAMO_DIR CURRENT_ROD.json CANDIDATE_ROD.json OUT.json
"""
import json
import math
import os
import sys

import bpy  # noqa: F401 (provides mathutils)
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_player as rp  # noqa: E402
import owl_character  # noqa: E402
import rod_grip  # noqa: E402


def angle(a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    c = float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b)))
    return math.degrees(math.acos(max(-1.0, min(1.0, c))))


def fingertips(arm, mesh, c, d, handle_r):
    k = mesh["char_k"]
    out = {}
    for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        n = "mixamorig:LeftHand%s3" % f
        if n not in arm.pose.bones or mesh.vertex_groups.get(n) is None:
            continue
        p = rod_grip.tail(arm, n)
        out[f.lower()] = round((rod_grip._to_axis(p, np.asarray(c), np.asarray(d)) - handle_r) / k * 1000, 1)
    return out


def three_d(arm, mesh, clips, way, g=None):
    rows = {}
    for name in rp.HAND_CLIPS:
        dirs, frames = [], []
        for f in range(1, rp.FRAMES + 1):
            rp.rs.set_pose(clips[name], f)
            hm = np.array(rod_grip.hand_matrix(arm))
            if way == "current":
                mw = arm.matrix_world
                bones = arm.pose.bones
                c = (mw @ bones["mixamorig:LeftHand"].head + mw @ bones["mixamorig:LeftHandMiddle1"].head) * 0.5
                d = rp.rod_target(name, f)
                c, d = np.array(c[:]), np.array(d[:])
                handle_r = g.handle_r
            else:
                c, d = g.rod()
                handle_r = g.handle_r
            local = hm[:3, :3].T @ d
            dirs.append(local)
            frames.append({"through": rp.rod_through(mesh, Vector(c), Vector(d)),
                           "fingertips_mm": fingertips(arm, mesh, c, d, handle_r)})
        mean = np.mean(dirs, axis=0)
        for fr, v in zip(frames, dirs):
            fr["turn_in_hand"] = round(angle(v, mean), 1)
        rows[name] = frames
    return rows


def two_d(path):
    with open(path) as fh:
        data = json.load(fh)
    out = {}
    for name in rp.HAND_CLIPS:
        per = []
        for di, dn in enumerate(rp.DIRS):
            cells = data["rod"][name][di]
            turns, jumps = [], []
            n = len(cells)
            for i in range(n):
                a, b = cells[i], cells[(i + 1) % n]
                if name == "cast" and i >= 3:
                    continue  # the whip, and back to the start
                va = (a[2] - a[0], a[3] - a[1])
                vb = (b[2] - b[0], b[3] - b[1])
                turns.append(angle(va, vb) if np.linalg.norm(va) > 1 and np.linalg.norm(vb) > 1 else 0.0)
                jumps.append(math.hypot(b[0] - a[0], b[1] - a[1]))
            per.append({"facing": dn, "max_turn_deg": round(max(turns), 1), "max_grip_jump_px": round(max(jumps), 2)})
        out[name] = per
    return out


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    mixamo, cur_json, cand_json, out = args[:4]
    character = os.environ.get("PLAYER", "owl")
    arm, _, src = rp.load(mixamo)
    mesh = owl_character.player(arm, "mixamo", list(src.values()), standing=[src["idle"]])[0]
    clips = rp.build_clips(arm, src)
    # the current way first (the clips as they are), then the candidate's
    samples = [(clips[n], f, rp.rod_target(n, f)) for n in ("hold", "reel", "fight", "hold_run")
               for f in range(1, rp.FRAMES + 1)]
    g = rod_grip.Grip(arm, mesh, character, samples)
    report = {"character": character, "handle_r_mm": round(g.handle_r / mesh["char_k"] * 1000, 1),
              "current": three_d(arm, mesh, clips, "current", g)}
    g2, grip_report = rp.grip_clips(arm, mesh, clips, character)
    report["candidate"] = three_d(arm, mesh, clips, "candidate", g2)
    report["candidate_arm"] = grip_report
    report["screen"] = {"current": two_d(cur_json), "candidate": two_d(cand_json)}
    with open(out, "w") as fh:
        json.dump(report, fh, indent=1)
    for way in ("current", "candidate"):
        for name, rows in report[way].items():
            print("AUDIT", character, way, name, "turn", max(r["turn_in_hand"] for r in rows),
                  "through", sum(r["through"] for r in rows),
                  "tips", min(min(r["fingertips_mm"].values()) for r in rows), max(max(r["fingertips_mm"].values()) for r in rows))
    for way in ("current", "candidate"):
        for name, per in report["screen"][way].items():
            print("AUDIT2D", character, way, name, "turn", max(p["max_turn_deg"] for p in per),
                  "jump", max(p["max_grip_jump_px"] for p in per))
    sys.stdout.flush()
    os._exit(0)


if __name__ == "__main__":
    main()
