"""Builds the per-character progression report (HTML) from tools/sim_progress.gd's JSON
(scenarios A and B, each by character).

  python3 tools/sim_report_chars.py [sim.json] [report.html]
"""
import json
import statistics as S
import sys

paths = sys.argv[1].split(",") if len(sys.argv) > 1 else ["/tmp/sim_progress.json"]
d = {"assume": None, "scenarios": {}}
for path in paths:
    part = json.load(open(path))
    d["assume"] = part["assume"]
    for scen, chars in part["scenarios"].items():
        d["scenarios"].setdefault(scen, {}).update(chars)
PER_DAY = 120.0 / d["assume"].get("run_minutes", 9.25)   # runs a day at two hours
A = d["assume"]
NAMES = {"cat": "黑貓", "owl": "雪鴞", "owl2": "角鴞", "dog": "吉娃娃", "dog3": "牧羊犬", "bear": "棕熊", "bear2": "台灣黑熊",
         "deer": "紅鹿", "deer2": "梅花鹿", "sheep": "綿羊", "sheep2": "黑面羊", "croc": "鱷魚"}
START = {"cat": [4, 0, 1, 2, 3], "owl": [3, 0, 2, 4, 1], "owl2": [4, 1, 1, 2, 2], "dog": [4, 0, 3, 1, 2], "dog3": [2, 1, 2, 4, 1],
         "bear": [0, 5, 3, 2, 0], "bear2": [1, 4, 2, 3, 0], "deer": [3, 0, 1, 3, 3], "deer2": [3, 0, 1, 2, 4],
         "sheep": [1, 1, 3, 3, 2], "sheep2": [0, 2, 4, 3, 1], "croc": [0, 4, 4, 2, 0]}
MS = [("giant_land", "首次釣上巨物"), ("epic_land", "首次釣上史詩"), ("steady_epic", "可穩定釣史詩"),
      ("leg_land", "首次釣上傳說"), ("steady_leg", "可穩定釣傳說")]


def pct(vals, p):
    v = sorted(vals)
    return v[min(len(v) - 1, int(len(v) * p))]


def cell(lives, key):
    vals = [l["mile"][key] for l in lives if key in l["mile"]]
    if not vals:
        return "<td class=bad>—</td>"
    share = round(100 * len(vals) / len(lives))
    med = pct(vals, 0.5)
    return "<td>第 %d 趟<small>（第 %d 天・%d%%的角色）</small></td>" % (med, round(med / PER_DAY), share)


def rate(lives, key, lo, hi):
    v = [x.get(key, 0) for l in lives for x in l["log"][lo:hi]]
    return sum(v) / max(1, len(v))


def table(scen):
    rows = ""
    for c, name in NAMES.items():
        lives = d["scenarios"][scen][c]
        rows += "<tr><td>%s</td><td>%s</td>%s</tr>" % (name, "/".join(str(x) for x in START[c]), "".join(cell(lives, k) for k, _ in MS))
    head = "<tr><th>角色</th><th>起始 反/力/韌/耐/幸</th>%s</tr>" % "".join("<th>%s</th>" % l for _, l in MS)
    return head + rows


def rates(scen):
    rows = ""
    for c, name in NAMES.items():
        lives = d["scenarios"][scen][c]
        rows += "<tr><td>%s</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td></tr>" % (
            name, rate(lives, "giant_land", 10, 80), rate(lives, "epic_enc", 10, 80), rate(lives, "epic_land", 10, 80),
            rate(lives, "leg_enc", 10, 80), rate(lives, "leg_land", 10, 80))
    return "<tr><th>角色</th><th>巨物釣上</th><th>史詩遇到</th><th>史詩釣上</th><th>傳說遇到</th><th>傳說釣上</th></tr>" + rows


def fails(scen):
    rows = ""
    for c, name in NAMES.items():
        tot = {}
        for l in d["scenarios"][scen][c]:
            for x in l["log"]:
                for k, v in x["fails"].items():
                    tot[k] = tot.get(k, 0) + v
        n = sum(tot.values()) or 1
        rows += "<tr><td>%s</td>%s</tr>" % (name, "".join("<td>%.0f%%</td>" % (100 * tot.get(k, 0) / n) for k in ("react", "might", "resil", "endure")))
    return "<tr><th>角色</th><th>反應</th><th>力量</th><th>韌性</th><th>耐力</th></tr>" + rows


def gold(scen):
    rows = ""
    for c, name in NAMES.items():
        lives = d["scenarios"][scen][c]
        g = [l["log"][min(79, len(l["log"]) - 1)]["gold"] for l in lives]
        r4 = [l["mile"]["rod4"] for l in lives if "rod4" in l["mile"]]
        rows += "<tr><td>%s</td><td>%s</td><td>%d</td></tr>" % (name, "第 %d 趟" % S.median(r4) if r4 else "—", S.median(g))
    return "<tr><th>角色</th><th>買到黃金竿</th><th>第80趟存款</th></tr>" + rows


def talents(scen):
    from collections import Counter
    rows = ""
    tn = {"": "原能力", "reflex": "神經反射", "weights": "重量訓練", "leak": "技巧卸力", "grit": "咬緊牙關", "lucky": "LUCKY!", "tough": "狠角色", "veteran": "有經驗", "mood": "好心情"}
    for c, name in NAMES.items():
        if c not in d["scenarios"][scen]:
            continue
        cnt = Counter()
        for l in d["scenarios"][scen][c]:
            for x in l["log"]:
                cnt[x.get("talent", "")] += 1
        n = sum(cnt.values()) or 1
        top = cnt.most_common(3)
        rows += "<tr><td>%s</td><td>%s</td></tr>" % (name, "　".join("%s %.0f%%" % (tn[k], 100 * v / n) for k, v in top))
    return "<tr><th>角色</th><th>最常選的天賦（佔全部趟數）</th></tr>" + rows


html = """<!doctype html><meta charset=utf-8><title>各角色進程模擬</title>
<style>body{background:#14161b;color:#e6e2d6;font:15px/1.6 sans-serif;margin:24px;max-width:1150px}h1,h2{color:#e8c36a}table{border-collapse:collapse;margin:10px 0 24px;width:100%%}
td,th{border:1px solid #3a3f4a;padding:5px 10px}th{background:#252a33}small{color:#9aa}.bad{color:#f08a7a}.note{background:#222731;border-left:4px solid #e8c36a;padding:8px 14px}</style>
<h1>各角色進程模擬</h1>
<p>12 個角色，每個跑 %(n)d 個虛擬玩家，每人最多 300 趟（用遊戲的真實規則，假設見最後）。表中的「第 N 趟」是各玩家的中位數；括號是達成的比例。</p>
<div class=note>A＝現在的遊戲（釣竿＋詞綴魚＋角色起始素質）。B＝再加上假設的四件裝備（每件 0/8/16/25/35，升階 400/900/1800/3500）。這次有算進：角色的起始素質、幸運（稀有率／升級率）、紅鹿的原能力；天賦（每 3 趟挑最接近門檻的那一個，或維持原能力）有算，其他能力沒有算。</div>
<h2>首次與穩定（含天賦，按每天兩小時換算天數）</h2><table>%(b)s</table>
<h2>每趟遇到與釣上（第 11～80 趟平均）</h2><table>%(br)s</table>
<h2>被門檻擋下時缺哪一項（現在指「差最多」的那一項）</h2><table>%(bf)s</table>
<h2>金錢</h2><table>%(bg)s</table><h2>模擬中玩家選的天賦</h2><table>%(tl)s</table>
<h2>假設</h2><ul><li>一趟 %(rs).0f 秒，每竿等待＋%(ce).0f 秒；搏魚勝率 入門 %(l1).0f%%／普通 %(l2).0f%%／進階 %(l3).0f%%／大師 %(l4).0f%%；成功離開 %(sv).0f%%。</li>
<li>每趟隨機走一種水域；25%% 的竿落在稀有水域；詞綴魚帶 4 條；前 25 趟拿關卡獎勵。</li></ul>"""
n = len(d["scenarios"]["B"]["cat"])
open(sys.argv[2] if len(sys.argv) > 2 else "/tmp/progress_chars.html", "w").write(html % dict(
    n=n, b=table("B"), br=rates("B"), bf=fails("B"), bg=gold("B"), tl=talents("B"),
    rs=A["run_seconds"], ce=A["cycle_extra"], l1=100 * A["land"]["novice"], l2=100 * A["land"]["normal"], l3=100 * A["land"]["advanced"],
    l4=100 * A["land"]["master"], sv=100 * A["survive"]))
print("ok")
