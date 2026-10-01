"""把挑好的音檔整理成遊戲用的 .ogg。

  out/picked/<name>.wav（或 .mp3/.flac）  ->  out/game/<name>.ogg

依名稱處理：
  music_* / amb_* / *_loop   無縫循環：尾巴淡入開頭（交叉淡化），音量統一
  voice_*                    去頭尾靜音、單聲道、音量統一
  其他（音效）               去頭尾靜音、單聲道、峰值統一
全部轉成 44.1 kHz，Ogg Vorbis（音樂/環境音品質 0.5，其他 0.4）。

需要：pip install numpy soundfile scipy
    python finish.py [--copy-to ../../assets/audio]
加 --copy-to 會直接放進遊戲的 assets/audio/（同名的 .ogg 會取代原本的合成音）。
"""
import argparse
import glob
import os
import shutil

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

HERE = os.path.dirname(os.path.abspath(__file__))
RATE = 44100


def load(path):
    data, sr = sf.read(path, always_2d=True, dtype="float32")
    if sr != RATE:
        g = np.gcd(sr, RATE)
        data = resample_poly(data, RATE // g, sr // g, axis=0).astype(np.float32)
    return data


def trim(x, floor_db=-45.0, pad=0.02):
    level = np.abs(x).max(axis=1)
    on = np.nonzero(level > 10 ** (floor_db / 20) * max(level.max(), 1e-9))[0]
    if on.size == 0:
        return x
    p = int(pad * RATE)
    return x[max(on[0] - p, 0):min(on[-1] + p, len(x))]


def rms_to(x, db):
    rms = np.sqrt(np.mean(x ** 2)) + 1e-9
    y = x * (10 ** (db / 20) / rms)
    peak = np.abs(y).max()
    return y / peak * 0.95 if peak > 0.95 else y


def peak_to(x, db):
    return x * (10 ** (db / 20) / (np.abs(x).max() + 1e-9))


def loop(x, fade_s):
    """尾巴 fade_s 秒疊進開頭：接回開頭時沒有斷點。"""
    n = min(int(fade_s * RATE), len(x) // 3)
    if n <= 0:
        return x
    t = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None]
    head = x[:n] * np.sqrt(t) + x[-n:] * np.sqrt(1.0 - t)
    return np.concatenate([head, x[n:-n]])


def finish(name, x):
    looping = name.startswith(("music_", "amb_")) or name.endswith("_loop")
    if looping:
        x = loop(x, 2.0 if name.startswith("music_") else 1.0)
        return rms_to(x, -20.0 if name.startswith("music_") else -24.0), 0.5
    x = trim(x.mean(axis=1, keepdims=True))
    if name.startswith("voice_"):
        return rms_to(x, -18.0), 0.4
    return peak_to(x, -1.0), 0.4


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--copy-to", default="")
    args = ap.parse_args()
    out_dir = os.path.join(HERE, "out", "game")
    os.makedirs(out_dir, exist_ok=True)
    picked = sorted(glob.glob(os.path.join(HERE, "out", "picked", "*.*")))
    if not picked:
        print("out/picked/ 裡沒有檔案：先把每個項目最好的候選複製成 out/picked/<name>.wav")
    for path in picked:
        name = os.path.splitext(os.path.basename(path))[0]
        y, q = finish(name, load(path))
        dst = os.path.join(out_dir, name + ".ogg")
        sf.write(dst, y, RATE, format="OGG", subtype="VORBIS", compression_level=1.0 - q)
        print("%-28s %5.1f 秒  %4d KB" % (name, len(y) / RATE, os.path.getsize(dst) // 1024))
        if args.copy_to:
            shutil.copy(dst, os.path.join(args.copy_to, name + ".ogg"))


if __name__ == "__main__":
    main()
