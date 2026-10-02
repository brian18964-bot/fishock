"""Review sheets for the greybox animal people: the pictures
tools/greybox_review.py rendered, laid out with labels (pure Pillow).

    python3 tools/greybox_sheets.py REV_DIR OUT_DIR [FONT]

  greybox_all       the four greyboxes, T-pose, front / 3/4 / true side /
                    back, a 25 cm ruler across each row
  ANIMAL_compare    today's character (textured, and in clay) over the
                    greybox, the same four angles
  silhouettes       black silhouettes of each (T-pose and its display
                    pose) and each at about 128 px high
  ANIMAL_poses      the pose tests, with what came through the clothes
  display           each bind pose beside its display pose
  owl_legs          the owl's legs at today's length, 15% and 20% shorter
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ANIMALS = ["owl", "dog", "cat", "bear"]
NAMES = {"owl": "貓頭鷹", "dog": "犬", "cat": "黑貓", "bear": "熊"}
VIEWS = ["front", "three", "side", "back"]
VIEW_NAMES = {"front": "正面", "three": "四分之三", "side": "真側面", "back": "背面"}
TESTS = ["bind", "arms_down", "arms_up", "arms_forward", "crouch", "squat", "head_turn", "tail_swing"]
TEST_NAMES = {"bind": "綁定姿勢 (T)", "arms_down": "手臂放下", "arms_up": "抬臂",
              "arms_forward": "手前伸＋屈肘", "crouch": "UAL 蹲 (單膝前移低姿)",
              "squat": "雙腳下蹲 (IK 測試)", "head_turn": "轉頭 60°", "tail_swing": "尾巴擺動 (尾骨)"}
BG = (64, 66, 70)
INK = (235, 235, 235)
# The renders' camera: 1.5 m across, centred 0.68 m up.
FRAME, LOOK = 1.5, 0.68


def font(path, size):
    for p in (path, "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
              os.path.join(os.path.dirname(__file__), "..", "assets", "fonts", "NotoSansTC-subset.otf")):
        if p and os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def ruler(im, step=0.25, colour=(255, 255, 255, 40)):
    """Faint lines every `step` metres up from the ground."""
    w, h = im.size
    over = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    z = 0.0
    while z < LOOK + FRAME / 2:
        y = h / 2 - (z - LOOK) * h / FRAME
        d.line([(0, y), (w, y)], fill=colour if z > 0 else (255, 255, 255, 90), width=1)
        z += step
    return Image.alpha_composite(im.convert("RGBA"), over).convert("RGB")


def grid(cells, cols, cell, labels_top=None, labels_left=None, f=None, left=130, top=44, title=None):
    rows = (len(cells) + cols - 1) // cols
    tt = 56 if title else 0
    W = Image.new("RGB", (left + cols * cell, tt + top + rows * cell), BG)
    d = ImageDraw.Draw(W)
    if title:
        d.text((16, 12), title, font=f(30), fill=INK)
    for i, im in enumerate(cells):
        if im is None:
            continue
        im = im.resize((cell, cell), Image.LANCZOS)
        W.paste(im, (left + (i % cols) * cell, tt + top + (i // cols) * cell))
    if labels_top:
        for c, t in enumerate(labels_top):
            d.text((left + c * cell + 10, tt + 8), t, font=f(24), fill=INK)
    if labels_left:
        for r, t in enumerate(labels_left):
            d.text((12, tt + top + r * cell + cell // 2 - 14), t, font=f(24), fill=INK)
    return W


def load(rev, name):
    p = os.path.join(rev, name)
    return Image.open(p) if os.path.exists(p) else None


def on_white(im):
    """A transparent black-silhouette render on white."""
    base = Image.new("RGBA", im.size, (255, 255, 255, 255))
    return Image.alpha_composite(base, im.convert("RGBA")).convert("RGB")


def thumb(clay, sil, h=128, pad=4):
    """The character cut to its outline's box and scaled to h high."""
    a = sil.convert("RGBA").split()[3]
    box = a.getbbox()
    if box is None:
        return None, None
    box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, sil.size[0]), min(box[3] + pad, sil.size[1]))
    c = clay.convert("RGB").crop(box)
    s = on_white(sil).crop(box)
    w = max(1, round(c.size[0] * h / c.size[1]))
    return c.resize((w, h), Image.LANCZOS), s.resize((w, h), Image.LANCZOS)


def main(rev, out, fpath=None):
    os.makedirs(out, exist_ok=True)

    def f(size):
        return font(fpath, size)
    # the four greyboxes
    cells = []
    for a in ANIMALS:
        for v in VIEWS:
            im = load(rev, "%s_new_%s.png" % (a, v))
            cells.append(ruler(im) if im else None)
    grid(cells, 4, 420, [VIEW_NAMES[v] for v in VIEWS], [NAMES[a] for a in ANIMALS], f,
         title="四隻灰模（技術綁定姿勢 T-pose）・同一鏡頭、燈光、地面；橫線每 25 cm").save(
        os.path.join(out, "greybox_all.png"))
    # today's against the greybox
    for a in ANIMALS:
        cells = []
        for kind in ("old", "oldclay", "new"):
            for v in VIEWS:
                im = load(rev, "%s_%s_%s.png" % (a, kind, v))
                cells.append(ruler(im) if im else None)
        grid(cells, 4, 400, [VIEW_NAMES[v] for v in VIEWS], ["現在\n(貼圖)", "現在\n(素模)", "灰模"], f,
             title="%s：原版與灰模・同角度" % NAMES[a]).save(os.path.join(out, "%s_compare.png" % a))
    # silhouettes and thumbnails
    rows = []
    for a in ANIMALS:
        row = [on_white(load(rev, "%s_sil_%s.png" % (a, v))) for v in VIEWS]
        ds = load(rev, "%s_display_sil_three.png" % a)
        row.append(on_white(ds) if ds else None)
        rows += row
    sil = grid(rows, 5, 300, [VIEW_NAMES[v] for v in VIEWS] + ["展示姿勢"], [NAMES[a] for a in ANIMALS], f,
               title="純黑剪影")
    sil.save(os.path.join(out, "silhouettes.png"))
    # ~128 px thumbnails, shown at 1:1
    pieces = []
    for a in ANIMALS:
        for clay_name, sil_name in (("%s_display_three.png", "%s_display_sil_three.png"),
                                    ("%s_new_front.png", "%s_sil_front.png")):
            c, s = load(rev, clay_name % a), load(rev, sil_name % a)
            if c is None or s is None:
                continue
            tc, ts = thumb(c, s)
            pieces.append((a, tc, ts))
    W = Image.new("RGB", (sum(p[1].size[0] + p[2].size[0] + 24 for p in pieces) + 40, 128 + 90), BG)
    d = ImageDraw.Draw(W)
    d.text((16, 10), "約 128 px 高縮圖（1:1，未放大）", font=f(22), fill=INK)
    x = 20
    for a, tc, ts in pieces:
        W.paste(tc, (x, 50))
        W.paste(ts, (x + tc.size[0] + 4, 50))
        d.text((x, 50 + 132), NAMES[a], font=f(16), fill=INK)
        x += tc.size[0] + ts.size[0] + 24
    W.save(os.path.join(out, "thumbnails_128.png"))
    # pose tests
    for a in ANIMALS:
        p = os.path.join(rev, "%s_poses.json" % a)
        if not os.path.exists(p):
            continue
        with open(p) as fh:
            st = json.load(fh)
        cells = []
        for v in ("front", "three"):
            for t in TESTS:
                cells.append(load(rev, "%s_pose_%s_%s.png" % (a, t, v)))
        cell = 300
        G = grid(cells, 6, cell, [TEST_NAMES[t] for t in TESTS], ["正面", "四分之三"], f, top=44,
                 title="%s：姿勢測試（UAL 骨架）・紅點＝衣服下的身體點穿出" % NAMES[a])
        H = Image.new("RGB", (G.size[0], G.size[1] + 120), BG)
        H.paste(G, (0, 0))
        d = ImageDraw.Draw(H)
        d.text((12, G.size[1] + 8), "穿出\n點數", font=f(20), fill=INK)
        for c, t in enumerate(TESTS):
            s = st.get(t, {})
            where = s.get("where", {})
            txt = "身體 %d / %d\n褲頭穿出上衣 %d" % (s.get("body_through", 0), st["covered_body"], s.get("shorts_through", 0))
            if where:
                txt += "\n" + "、".join("%s %d" % (REGION.get(k, k), n) for k, n in where.items())
            d.text((130 + c * cell + 8, G.size[1] + 8), txt, font=f(17), fill=INK)
        H.save(os.path.join(out, "%s_poses.png" % a))
    # display poses
    cells = []
    for a in ANIMALS:
        cells.append(ruler(load(rev, "%s_new_front.png" % a)) if load(rev, "%s_new_front.png" % a) else None)
        for v in VIEWS:
            im = load(rev, "%s_display_%s.png" % (a, v))
            cells.append(ruler(im) if im else None)
    grid(cells, 5, 340, ["綁定姿勢 (技術)", "展示：正面", "展示：四分之三", "展示：真側面", "展示：背面"],
         [NAMES[a] for a in ANIMALS], f, title="技術綁定姿勢與角色展示姿勢（分開交付）").save(
        os.path.join(out, "display.png"))
    # the owl's legs
    fr, sd = load(rev, "owl_legs_front.png"), load(rev, "owl_legs_side.png")
    if fr is not None:
        labels = ["現在（遊戲內）\n外露 0.356 m", "灰模 0%\n外露 0.356 m", "灰模 −15%\n外露 0.302 m", "灰模 −20%\n外露 0.285 m"]
        H = Image.new("RGB", (fr.size[0], fr.size[1] + sd.size[1] + 150), BG)
        H.paste(fr, (0, 70))
        H.paste(sd, (0, 70 + fr.size[1]))
        d = ImageDraw.Draw(H)
        d.text((16, 12), "貓頭鷹腿長比較（外露腿＝短褲褲口到地面）・同比例尺", font=f(28), fill=INK)
        n = len(labels)
        for i, t in enumerate(labels):
            d.text((int((i + 0.18) * fr.size[0] / n), 70 + fr.size[1] + sd.size[1] + 10), t, font=f(24), fill=INK)
        H.save(os.path.join(out, "owl_legs.png"))


REGION = {"tail root": "尾根", "arm/sleeve": "手臂/袖", "neck/collar": "頸/領口", "waist/hem": "腰/下襬",
          "thigh/cuff": "大腿/褲管", "lower leg": "小腿", "crotch": "褲襠"}


# ------------------------------------------------------------ round 2
# (user request, round 2: before / after at the same camera, close views
# of the head, hands, feet, crotch and tail root, the pose tests counted,
# measured and placed apart, the clips played through on both skeletons)

DETAILS = [("head_front", "頭・正面"), ("head_three", "頭・四分之三"), ("head_side", "頭・側面"),
           ("hand_top", "手掌・上"), ("hand_front", "手掌・前"), ("foot_side", "腳掌・側"),
           ("foot_front", "腳掌・前"), ("crotch_front", "褲襠・正面"), ("crotch_low", "褲襠・仰視"),
           ("tail_root", "尾根近照"), ("tail_back", "尾巴・背面"), ("tail_side", "尾巴・側面")]
CLIP_NAMES = {"idle": "待機", "walk": "走路", "run": "跑步", "cast": "甩竿", "fish_idle": "持竿待機"}


def measured_text(m):
    b, sh = m["body"], m["shorts"]
    t = "身體穿出 %d 點・最深 %.1f mm・平均 %.1f mm・%.1f cm²" % (
        b["points"], b["depth_max_mm"], b["depth_mean_mm"], b["area_cm2"])
    if sh["points"]:
        t += "\n褲頭穿出上衣 %d 點・最深 %.1f mm" % (sh["points"], sh["depth_max_mm"])
    return t


def round2(before, rev, out, fpath=None):
    os.makedirs(out, exist_ok=True)

    def f(size):
        return font(fpath, size)
    # standing pictures, silhouettes and thumbnails (main's, from these
    # renders; its pose sheets are replaced below)
    main(rev, out, fpath)
    for a in ANIMALS:
        # before / after, the four views
        cells = []
        for src in (before, rev):
            for v in VIEWS:
                im = load(src, "%s_new_%s.png" % (a, v))
                cells.append(ruler(im) if im else None)
        grid(cells, 4, 420, [VIEW_NAMES[v] for v in VIEWS], ["第一輪", "第二輪"], f,
             title="%s：本輪修改前／後・同鏡頭、燈光、比例尺（橫線每 25 cm）" % NAMES[a]).save(
            os.path.join(out, "%s_before_after.png" % a))
        # close views, before / after
        shots = [d for d in DETAILS if load(rev, "%s_new_%s.png" % (a, d[0])) is not None]
        for part, sel in (("a", shots[:5]), ("b", shots[5:9]), ("c", shots[9:])):
            if not sel:
                continue
            cells = [load(src, "%s_%s_%s.png" % (a, tag, k)) for src, tag in ((rev, "old"), (rev, "new"))
                     for k, _ in sel]
            grid(cells, len(sel), 330, [n for _, n in sel], ["第一輪", "第二輪"], f,
                 title="%s：近照（T 姿勢，同燈光；地面不顯示）" % NAMES[a]).save(
                os.path.join(out, "%s_details_%s.png" % (a, part)))
        # the pose tests, measured
        p = os.path.join(rev, "%s_poses.json" % a)
        if os.path.exists(p):
            with open(p) as fh:
                st = json.load(fh)
            tests = [t for t in TESTS if t in st]
            cells = []
            for v in ("front", "three"):
                for t in tests:
                    im = load(rev, "%s_pose_%s_%s.png" % (a, t, v))
                    if im is None and v == "front":
                        im = load(rev, "%s_pose_%s_back.png" % (a, t))
                    cells.append(im)
            cell = 280
            G = grid(cells, len(tests), cell, [TEST_NAMES[t] for t in tests], ["正面*", "四分之三"], f,
                     title="%s：靜態姿勢測試（UAL 骨架）・紅點＝綁定時在衣服內、擺姿後在兩件衣服外的身體點" % NAMES[a])
            H = Image.new("RGB", (G.size[0], G.size[1] + 270), BG)
            H.paste(G, (0, 0))
            d = ImageDraw.Draw(H)
            d.text((12, G.size[1] + 8), "實際\n量測", font=f(20), fill=INK)
            for c, t in enumerate(tests):
                m = st[t]["measured"]
                lines = ["穿出 %d 點" % m["body"]["points"], "最深 %.1f mm" % m["body"]["depth_max_mm"],
                         "平均 %.1f mm" % m["body"]["depth_mean_mm"], "面積 %.1f cm²" % m["body"]["area_cm2"],
                         "可見 %d 點 / %.1f cm²" % (m["body"].get("visible_points", 0), m["body"].get("visible_area_cm2", 0))]
                if m["shorts"]["points"]:
                    lines.append("褲頭穿上衣 %d 點 / %.1f mm" % (m["shorts"]["points"], m["shorts"]["depth_max_mm"]))
                for r, v in sorted(m["where"].items(), key=lambda kv: -kv[1]["points"])[:3]:
                    lines.append("%s %d 點 %.1f mm" % (REGION.get(r, r), v["points"], v["depth_max_mm"]))
                d.text((130 + c * cell + 6, G.size[1] + 8), "\n".join(lines), font=f(15), fill=INK)
            d.text((12, H.size[1] - 26), "* 尾巴擺動一欄為背面。總點數與各部位點數分列；各部位只列前三。",
                   font=f(15), fill=INK)
            H.save(os.path.join(out, "%s_poses.png" % a))
            # where it came through, close
            items = [(t, c) for t in tests for c in st[t].get("close", [])]
            if items:
                cells = [load(rev, c["file"]) for _, c in items]
                cols = 4
                G = grid(cells, cols, 340, None, None, f, left=10, top=10,
                         title="%s：穿模位置近照（紅點＝穿出點；褲襠近照為每次蹲姿固定拍攝）" % NAMES[a])
                d = ImageDraw.Draw(G)
                for i, (t, c) in enumerate(items):
                    x, y = 10 + (i % cols) * 340, 56 + 10 + (i // cols) * 340
                    reg = c["region"]
                    m = st[t]["measured"]["where"].get(reg)
                    txt = "%s・%s" % (TEST_NAMES[t], REGION.get(reg.split(" (")[0], reg))
                    if m:
                        txt += "\n%d 點・最深 %.1f mm・可見 %d 點" % (m["points"], m["depth_max_mm"], m.get("visible_points", 0))
                    d.rectangle([x, y, x + 340, y + (46 if m else 24)], fill=(30, 30, 32))
                    d.text((x + 6, y + 3), txt, font=f(15), fill=INK)
                G.save(os.path.join(out, "%s_poke_close.png" % a))
        # the clips
        p = os.path.join(rev, "%s_anim.json" % a)
        if os.path.exists(p):
            with open(p) as fh:
                an = json.load(fh)
            rows = []
            for rig, label in (("ual", "UAL"), ("mixamo", "Mixamo（遊戲跑圖流程）")):
                for key, v in an[rig].items():
                    im = load(rev, "%s_anim_%s_%s.png" % (a, rig, key))
                    if "frames" in v:
                        fr = v["frames"]
                        worst = max(fr, key=lambda r: r["body"]["points"])
                        txt = "%s・%s（%s）：12 格中穿出點最多 %d 點（第 %.0f 幀），最深 %.1f mm" % (
                            label, CLIP_NAMES.get(key, key), v["clip"], worst["body"]["points"], worst["frame"],
                            max(r["body"]["depth_max_mm"] for r in fr))
                        if rig == "mixamo" and not v.get("in_game", True):
                            txt += "（遊戲未使用此片段）"
                    else:
                        txt = "%s・%s：未驗證（%s）" % (label, CLIP_NAMES.get(key, key), v.get("note", "片段不存在"))
                    rows.append((txt, im))
            W = max(im.size[0] for _, im in rows if im is not None)
            H = sum((im.size[1] if im is not None else 0) + 36 for _, im in rows) + 60
            S_ = Image.new("RGB", (W, H), BG)
            d = ImageDraw.Draw(S_)
            d.text((12, 12), "%s：動畫逐格（四分之三視角，紅點＝穿出點；尾巴擺動為程式控制 ±%.0f°）" % (
                NAMES[a], an.get("sway_deg", 0)), font=f(24), fill=INK)
            y = 60
            for txt, im in rows:
                d.text((12, y + 6), txt, font=f(18), fill=INK)
                y += 36
                if im is not None:
                    S_.paste(im, (0, y))
                    y += im.size[1]
            S_.save(os.path.join(out, "%s_anim.png" % a))
    # the dog without its neckerchief
    cells = [load(rev, "dog_new_noscarf_%s.png" % v) for v in VIEWS] + \
        [load(rev, "dog_new_noscarf_neck_three.png"), load(rev, "dog_new_noscarf_neck_side.png")]
    if cells[0] is not None:
        grid(cells, 6, 330, [VIEW_NAMES[v] for v in VIEWS] + ["頸部・四分之三", "頸部・側面"], None, f, left=10,
             title="犬：不戴領巾的檢查圖（頸部、下顎後方與肩的連接）").save(os.path.join(out, "dog_noscarf.png"))
    # the cat's walk frame (an animation still, not its picture)
    cells = [load(rev, "cat_anim_still_%s.png" % v) for v in VIEWS]
    if cells[0] is not None:
        grid(cells, 4, 360, [VIEW_NAMES[v] for v in VIEWS], None, f, left=10,
             title="黑貓：動畫截圖（UAL Walk_Formal_Loop 35%）・不作角色展示圖").save(
            os.path.join(out, "cat_anim_still.png"))


if __name__ == "__main__":
    if sys.argv[1] == "round2":
        round2(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
    else:
        main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
