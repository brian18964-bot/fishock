"""背景音樂：用 ACE-Step 1.5 生成 prompts.json 的 "music"（每首幾個候選）。

先在另一個視窗開 ACE-Step 的 API 伺服器（見 README.md）：
    uv run acestep-api            （預設 http://localhost:8001）
再執行：
    python gen_music.py [--server http://localhost:8001] [--candidates 3] [--only music_camp]

輸出：out/raw/<name>/<n>.wav（聽一聽，把最好的那個複製成 out/picked/<name>.wav）
只用到 Python 標準函式庫。
"""
import argparse
import json
import os
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


def post(server, path, body):
    req = urllib.request.Request(server + path, data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        out = json.loads(r.read().decode("utf-8"))
    if out.get("code") != 200:
        raise RuntimeError("%s: %s" % (path, out.get("error")))
    return out["data"]


def generate(server, item, candidates):
    task = post(server, "/release_task", {
        "prompt": item["prompt"],
        "lyrics": "[Instrumental]",
        "instrumental": True,
        "audio_duration": item.get("duration", 120),
        "bpm": item.get("bpm"),
        "key_scale": item.get("key", ""),
        "time_signature": item.get("time_signature", ""),
        "thinking": True,
        "batch_size": candidates,
        "audio_format": "wav",
    })
    tid = task["task_id"]
    print("  task", tid, flush=True)
    while True:
        time.sleep(5)
        rows = post(server, "/query_result", {"task_id_list": [tid]})
        row = rows[0] if isinstance(rows, list) else rows
        if row["status"] == 2:
            raise RuntimeError("generation failed: %s" % row)
        if row["status"] == 1:
            results = row["result"]
            return json.loads(results) if isinstance(results, str) else results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--server", default="http://localhost:8001")
    ap.add_argument("--candidates", type=int, default=3)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    prompts = json.load(open(os.path.join(HERE, "prompts.json"), encoding="utf-8"))
    for item in prompts["music"]:
        if args.only and item["name"] != args.only:
            continue
        print("music:", item["name"], flush=True)
        out_dir = os.path.join(HERE, "out", "raw", item["name"])
        os.makedirs(out_dir, exist_ok=True)
        for n, res in enumerate(generate(args.server, item, args.candidates)):
            url = res["file"]
            if url.startswith("/"):
                url = args.server + url
            dst = os.path.join(out_dir, "%d.wav" % (n + 1))
            urllib.request.urlretrieve(url, dst)
            print("  ->", dst, flush=True)


if __name__ == "__main__":
    main()
