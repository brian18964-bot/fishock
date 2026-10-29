"""Builds the progression report (HTML) from tools/sim_progress.gd's JSON.

  python3 tools/sim_report.py [sim.json] [report.html]
"""
import json, sys, statistics as S
d=json.load(open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/sim_progress.json"))
A=d["assume"]
N={"react":"反應","might":"力量","resil":"韌性","endure":"耐力"}
def pct(vals,p):
    v=sorted(vals); 
    if not v: return None
    return v[min(len(v)-1,int(len(v)*p))]
MS=[("rod1","買到玻纖竿"),("rod2","買到碳纖竿"),("rod3","買到海釣竿"),("rod4","買到黃金竿"),("giant_land","第一次釣上巨物（門檻魚）"),("rare_land","第一次釣上稀有魚種"),
    ("epic_try","第一次挑戰史詩（2項門檻，海洋稀有魚）"),("epic_land","第一次釣上史詩"),("leg_try","第一次挑戰傳說（3項門檻）"),("leg_land","第一次釣上傳說"),
    ("steady_epic","可穩定釣史詩（門檻達成率≥80%連5趟）"),("steady_leg","可穩定釣傳說（同上）")]
SC={"A":"A 現況（釣竿＋詞綴魚，攜帶4條）","B":"B 假設加入裝備（魚線/浮標/魚鉤/防失繩 各5階）","C":"C = B + 包包可帶8條詞綴魚"}
def mile_table():
    rows=""
    for key,label in MS:
        tds=""
        for sc in "ABC":
            lives=d["scenarios"][sc]; vals=[l["mile"][key] for l in lives if key in l["mile"]]
            n=len(lives)
            if not vals: tds+="<td class=bad>0%% 達成（%d趟內）</td>"%len(lives[0]["log"])
            else:
                tds+="<td>中位 %d 趟（%d～%d）<br><small>%d%% 的角色達成</small></td>"%(pct(vals,.5),pct(vals,.1),pct(vals,.9),round(100*len(vals)/n))
        rows+="<tr><td>%s</td>%s</tr>"%(label,tds)
    return rows
def curve(sc,key,runs):
    lives=d["scenarios"][sc]; out=[]
    for r in runs:
        v=[l["log"][r-1][key] for l in lives if len(l["log"])>=r and key in l["log"][r-1]]
        out.append(S.median(v) if v else None)
    return out
RUNS=[1,3,5,10,20,40,80,150,300]
def curve_table():
    h="<tr><th>第幾趟</th>"+"".join("<th>%d</th>"%r for r in RUNS)+"</tr>"
    rows=""
    for sc in "ABC":
        for key,label,fmt in (("gold","金幣存量（中位）","%d"),("ready_epic","史詩門檻達成率","%.0f%%"),("ready_leg","傳說門檻達成率","%.0f%%")):
            c=curve(sc,key,RUNS)
            cells=""
            for v in c:
                if v is None: cells+="<td>—</td>"
                else: cells+="<td>%s</td>"%(fmt%(v*100 if "%%" in fmt else v))
            rows+="<tr><td>%s・%s</td>%s</tr>"%(sc,label,cells)
    return h+rows
def stat_table():
    h="<tr><th>情境（第N趟中位）</th>"+"".join("<th>%s</th>"%N[s] for s in ("react","might","resil","endure"))+"<th>攜帶詞綴魚數值</th></tr>"
    rows=""
    for sc in "ABC":
        for r in (5,20,80):
            lives=d["scenarios"][sc]
            cells=""
            for s in ("react","might","resil","endure"):
                v=[l["log"][r-1]["tank_stats"][s] for l in lives if len(l["log"])>=r]
                cells+="<td>%d</td>"%S.median(v)
            aff=[sum(l["log"][r-1]["tank_affix_vals"]) for l in lives if len(l["log"])>=r]
            rows+="<tr><td>%s・第%d趟</td>%s<td>%d（合計）</td></tr>"%(sc,r,cells,S.median(aff))
    return h+rows
def rates():
    rows=""
    for sc in "ABC":
        lives=d["scenarios"][sc]
        def avg(key,lo,hi):
            v=[]
            for l in lives:
                for x in l["log"][lo:hi]: v.append(x.get(key,0))
            return sum(v)/max(1,len(v))
        for lo,hi,lab in ((0,10,"第1–10趟"),(10,40,"第11–40趟"),(40,150,"第41–150趟")):
            rows+="<tr><td>%s・%s</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.2f</td><td>%.1f</td></tr>"%(sc,lab,avg("giant_enc",lo,hi),avg("giant_land",lo,hi),avg("epic_enc",lo,hi),avg("epic_land",lo,hi),avg("leg_enc",lo,hi),avg("leg_land",lo,hi),avg("income",lo,hi))
    return rows
def fails():
    rows=""
    for sc in "ABC":
        tot={}
        for l in d["scenarios"][sc]:
            for x in l["log"]:
                for k,v in x["fails"].items(): tot[k]=tot.get(k,0)+v
        s=sum(tot.values()) or 1
        rows+="<tr><td>%s</td>%s</tr>"%(sc,"".join("<td>%s %.0f%%</td>"%(N[k],100*tot.get(k,0)/s) for k in ("react","might","resil","endure")))
    return rows
def spend():
    rows=""
    for sc in "ABC":
        lives=d["scenarios"][sc]
        ins=[sum(x["income"] for x in l["log"][:80]) for l in lives]; sp=[sum(x["spend"] for x in l["log"][:80]) for l in lives]
        gold=[l["log"][min(79,len(l["log"])-1)]["gold"] for l in lives]
        dr=[l["log"][min(79,len(l["log"])-1)]["droppers"] for l in lives]; fd=[l["log"][min(79,len(l["log"])-1)]["feeds"] for l in lives]
        rows+="<tr><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%.1f</td><td>%.1f</td></tr>"%(sc,S.median(ins),S.median(sp),S.median(gold),S.median(dr),S.median(fd))
    return rows
html="""<!doctype html><meta charset=utf-8><title>進程驗證報告</title>
<style>body{background:#14161b;color:#e6e2d6;font:15px/1.6 sans-serif;margin:24px;max-width:1100px}h1,h2{color:#e8c36a}table{border-collapse:collapse;margin:10px 0 24px;width:100%%}
td,th{border:1px solid #3a3f4a;padding:6px 10px;vertical-align:top}th{background:#252a33}small{color:#9aa}.bad{color:#f08a7a}code{background:#252a33;padding:1px 5px}.note{background:#222731;border-left:4px solid #e8c36a;padding:8px 14px;margin:12px 0}</style>
<h1>進程驗證：從新手到史詩</h1>
<p>用遊戲真實規則（出魚機率、魚種池、長度、門檻、詞綴、活性倒數、售價、釣竿價格、關卡獎勵）跑 <b>100 個角色 × 3 種情境</b> 的蒙地卡羅模擬，每個角色最多玩 300 趟。<br>
模擬器：<code>tools/sim_progress.gd</code>（可重跑、可改參數）。</p>
<div class=note><b>情境</b>：%(A)s<br>%(B)s<br>%(C)s<br><small>B、C 的裝備數值是「假設」：每件 0/8/16/25/35，升階價格 400/900/1800/3500。這是為了找出裝備需要多大，不是現有內容。</small></div>
<h2>1. 里程碑（第幾趟達成）</h2><table><tr><th>里程碑</th><th>A 現況</th><th>B 加裝備</th><th>C 加裝備＋帶8條</th></tr>%(mile)s</table>
<h2>2. 金幣與門檻達成率的曲線（中位數）</h2><table>%(curve)s</table>
<h2>3. 攜帶的四項數值（含釣竿、裝備、詞綴魚）</h2><table>%(stat)s</table>
<h2>4. 遇到與釣上的頻率（每趟平均）</h2><table><tr><th>情境・階段</th><th>巨物遇到</th><th>巨物釣上</th><th>史詩遇到</th><th>史詩釣上</th><th>傳說遇到</th><th>傳說釣上</th><th>收入(金)</th></tr>%(rates)s</table>
<h2>5. 被門檻擋下時，缺的是哪一項</h2><table>%(fails)s</table>
<h2>6. 前 80 趟的金錢（中位數）</h2><table><tr><th>情境</th><th>總收入</th><th>總支出</th><th>第80趟存款</th><th>洗點滴瓶用量</th><th>活力飼料用量</th></tr>%(spend)s</table>
<h2>7. 模擬假設（遊戲本身說不準的部分）</h2>
<ul><li>一趟 = 一整天自由釣 %(rs)d 秒；每竿 = 等待時間＋%(ce)d 秒（揚竿、搏魚、收線、走位）。</li>
<li>搏魚勝率（沒有被門檻擋住時）：入門 %(l1).0f%%／普通 %(l2).0f%%／進階 %(l3).0f%%／大師 %(l4).0f%%；挑戰範圍內再扣 差距×3。</li>
<li>一趟成功離開機率 %(sv).0f%%；失敗＝本趟釣獲全失，帶出去的詞綴魚變虛弱，要花 40 金幣的飼料救回。</li>
<li>每趟 25%% 的竿落在稀有水域、約 3 竿在熱點；金幣夠就在熱點用活青蛙（15金，稀有×2、傳說×2）。</li>
<li>前 25 趟依序拿關卡首次通關獎勵（＋每關 1 顆星 15 金）；之後只靠賣魚。</li>
<li>詞綴魚：有屬性詞綴的魚收進魚缸，出發時帶最好的 N 條（A、B：4；C：8）；活性會倒數，帶出去死掉就不算。滿 3 次以前，數值低於區間中點的魚會用洗點滴瓶重抽。</li>
<li>每趟隨機走一種地圖水域（10 種淡水＋海洋）。</li></ul>
"""
html=html%dict(A=SC["A"],B=SC["B"],C=SC["C"],mile=mile_table(),curve=curve_table(),stat=stat_table(),rates=rates(),fails=fails(),spend=spend(),
   rs=A["run_seconds"],ce=A["cycle_extra"],l1=100*A["land"]["novice"],l2=100*A["land"]["normal"],l3=100*A["land"]["advanced"],l4=100*A["land"]["master"],sv=100*A["survive"])
open(sys.argv[2] if len(sys.argv) > 2 else "/tmp/progress_report.html","w").write(html)
print("ok")
