"""環境音與音效：用 MOSS-SoundEffect v2 生成 prompts.json 的 "ambience" 和 "sfx"。

在 MOSS-SoundEffect v2 的環境裡執行（見 README.md）：
    python gen_sfx.py [--candidates 3] [--only amb_camp] [--kind ambience|sfx]

輸出：out/raw/<name>/<n>.wav（聽一聽，把最好的那個複製成 out/picked/<name>.wav）
"""
import argparse
import json
import os

os.environ.setdefault("TORCHDYNAMO_DISABLE", "1")  # 官方建議：避免第一次編譯出錯

import torch  # noqa: E402
from moss_soundeffect_v2 import MossSoundEffectPipeline  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidates", type=int, default=3)
    ap.add_argument("--only", default="")
    ap.add_argument("--kind", default="", help="ambience 或 sfx（不填就兩種都做）")
    ap.add_argument("--model", default="OpenMOSS-Team/MOSS-SoundEffect-v2.0")
    args = ap.parse_args()
    prompts = json.load(open(os.path.join(HERE, "prompts.json"), encoding="utf-8"))
    pipe = MossSoundEffectPipeline.from_pretrained(args.model, torch_dtype=torch.bfloat16, device="cuda")
    kinds = [args.kind] if args.kind else ["ambience", "sfx"]
    for kind in kinds:
        for item in prompts[kind]:
            if args.only and item["name"] != args.only:
                continue
            print(kind + ":", item["name"], flush=True)
            out_dir = os.path.join(HERE, "out", "raw", item["name"])
            os.makedirs(out_dir, exist_ok=True)
            for n in range(args.candidates):
                torch.manual_seed(1000 + n)
                audio = pipe(prompt=item["prompt"], seconds=item["seconds"],
                             num_inference_steps=100, cfg_scale=4.0)
                dst = os.path.join(out_dir, "%d.wav" % (n + 1))
                pipe.save_audio(audio, dst)
                print("  ->", dst, flush=True)


if __name__ == "__main__":
    main()
