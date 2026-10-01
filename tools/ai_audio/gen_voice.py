"""角色語音：用 Qwen3-TTS 為 prompts.json 的 "voices" 配音。

做法（官方建議的「先設計聲音，再複製」）：
  1. VoiceDesign 模型依 design 的文字描述，念 ref_text，做出這個角色的聲音樣本
     （每個角色做幾個樣本：out/voice_ref/<角色>_<n>.wav，挑最像的）
  2. Base 模型拿樣本當參考，用同一個聲音念完所有台詞 -> out/raw/<name>/<n>.wav

在 Qwen3-TTS 的環境裡執行（見 README.md）：
    python gen_voice.py design            # 步驟 1：只做聲音樣本
    python gen_voice.py speak [--ref merchant=out/voice_ref/merchant_2.wav]
                                          # 步驟 2：用選好的樣本念台詞（不指定就用 _1）
"""
import argparse
import json
import os

import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel

HERE = os.path.dirname(os.path.abspath(__file__))
DESIGN = "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign"
BASE = "Qwen/Qwen3-TTS-12Hz-1.7B-Base"


def load(name):
    kw = {"device_map": "cuda:0", "dtype": torch.bfloat16}
    try:
        return Qwen3TTSModel.from_pretrained(name, attn_implementation="flash_attention_2", **kw)
    except Exception:  # 沒裝 flash-attn 也能跑，只是比較吃記憶體
        return Qwen3TTSModel.from_pretrained(name, **kw)


def design(voices, samples):
    model = load(DESIGN)
    os.makedirs(os.path.join(HERE, "out", "voice_ref"), exist_ok=True)
    for who, v in voices.items():
        for n in range(samples):
            torch.manual_seed(2000 + n)
            wavs, sr = model.generate_voice_design(text=v["ref_text"], language="Chinese", instruct=v["design"])
            dst = os.path.join(HERE, "out", "voice_ref", "%s_%d.wav" % (who, n + 1))
            sf.write(dst, wavs[0], sr)
            print("  ->", dst, flush=True)


def speak(voices, refs, candidates):
    model = load(BASE)
    for who, v in voices.items():
        ref = refs.get(who, os.path.join(HERE, "out", "voice_ref", "%s_1.wav" % who))
        prompt = model.create_voice_clone_prompt(ref_audio=ref, ref_text=v["ref_text"])
        for line in v["lines"]:
            print("voice:", line["name"], flush=True)
            out_dir = os.path.join(HERE, "out", "raw", line["name"])
            os.makedirs(out_dir, exist_ok=True)
            for n in range(candidates):
                torch.manual_seed(3000 + n)
                wavs, sr = model.generate_voice_clone(text=line["text"], language="Chinese",
                                                      voice_clone_prompt=prompt)
                dst = os.path.join(out_dir, "%d.wav" % (n + 1))
                sf.write(dst, wavs[0], sr)
                print("  ->", dst, flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("step", choices=["design", "speak"])
    ap.add_argument("--samples", type=int, default=4, help="design：每個角色做幾個聲音樣本")
    ap.add_argument("--candidates", type=int, default=2, help="speak：每句台詞念幾次")
    ap.add_argument("--ref", action="append", default=[], help="角色=樣本路徑，例如 merchant=out/voice_ref/merchant_2.wav")
    ap.add_argument("--only", default="", help="只做某個角色（merchant / willow）")
    args = ap.parse_args()
    voices = json.load(open(os.path.join(HERE, "prompts.json"), encoding="utf-8"))["voices"]
    if args.only:
        voices = {args.only: voices[args.only]}
    if args.step == "design":
        design(voices, args.samples)
    else:
        refs = dict(r.split("=", 1) for r in args.ref)
        refs = {k: (p if os.path.isabs(p) else os.path.join(HERE, p)) for k, p in refs.items()}
        speak(voices, refs, args.candidates)


if __name__ == "__main__":
    main()
