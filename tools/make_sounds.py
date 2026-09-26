"""Synthesize the game's sound effects, ambience loops and music.

User request: sound, from scratch - there were no audio assets at all.
Everything here is generated (numpy only): filtered noise, pitched sweeps,
additive bells, granular crunches, a few hand-built drones. Mono, 22.05
kHz, 16-bit WAV; Godot imports them compressed (QOA). Loops are made
seamless by crossfading their tail into their head.

  python tools/make_sounds.py [--only a,b] [OUT_DIR=assets/audio]
"""
import math
import os
import sys
import wave
import zlib

import numpy as np

SR = 22050
RNG = np.random.default_rng(7)


# --- building blocks -----------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def white(dur):
    return RNG.uniform(-1.0, 1.0, int(dur * SR))


def spectral(x, response):
    """Filter by a frequency response: response(freqs_hz) -> gain."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x) * response(f), n)


def lowpass(x, cutoff, order=2):
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (f / cutoff) ** (2 * order)))


def highpass(x, cutoff, order=2):
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(x, center, width):
    return spectral(x, lambda f: np.exp(-0.5 * ((f - center) / width) ** 2))


def pink(dur):
    return spectral(white(dur), lambda f: 1.0 / np.sqrt(np.maximum(f, 20.0))) * 8.0


def sweep_filter(x, centers, width_ratio=0.35, block=1024):
    """Time-varying band-pass: centers(t in 0..1) -> Hz, overlap-added blocks."""
    n = len(x)
    hop = block // 2
    win = np.hanning(block)
    out = np.zeros(n + block)
    pad = np.concatenate([x, np.zeros(block)])
    f = np.fft.rfftfreq(block, 1.0 / SR)
    for start in range(0, n, hop):
        c = centers(min(start / max(n - 1, 1), 1.0))
        resp = np.exp(-0.5 * ((f - c) / (c * width_ratio)) ** 2)
        seg = pad[start:start + block] * win
        out[start:start + block] += np.fft.irfft(np.fft.rfft(seg) * resp, block)
    return out[:n]


def env_ad(n, attack, decay_tau, sustain_end=None):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / decay_tau)
    return a * d


def tone(freq, dur, phase=0.0):
    """Sine with a frequency that may be an array (glide)."""
    n = int(dur * SR)
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def glide(f0, f1, dur, curve=1.0):
    t = np.linspace(0, 1, int(dur * SR)) ** curve
    return f0 * (f1 / f0) ** t


def bell(freq, dur, partials=((1, 1.0), (2.76, 0.45), (5.4, 0.25), (8.9, 0.12)), tau=0.6):
    n = int(dur * SR)
    out = np.zeros(n)
    for ratio, amp in partials:
        out += amp * tone(freq * ratio, dur) * env_ad(n, 0.002, tau / math.sqrt(ratio))
    return out


def place(dst, src, at):
    i = int(at * SR)
    j = min(len(dst), i + len(src))
    if i < len(dst):
        dst[i:j] += src[:j - i]
    return dst


def reverb(x, room=0.35, tail=1.2, wet=0.25):
    """Cheap diffuse tail: the signal convolved with decaying noise."""
    n = int(tail * SR)
    ir = white(tail) * np.exp(-np.arange(n) / (SR * tail * room))
    ir = lowpass(ir, 5000)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = np.convolve(x, ir)
    y = np.concatenate([y, np.zeros(len(x) + n - len(y))])
    dry = np.concatenate([x, np.zeros(n)])
    return dry * (1 - wet) + y * wet


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def loopify(x, xfade=0.5):
    """Seamless loop: the tail is crossfaded into the head and dropped."""
    k = int(xfade * SR)
    head, body, tail = x[:k], x[k:-k], x[-k:]
    ramp = np.linspace(0, 1, k)
    mixed = tail * (1 - ramp) + head * ramp
    return np.concatenate([mixed, body])


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def crunch(n_grains, dur, band=(1500, 5000), grain=0.012, level=1.0):
    out = np.zeros(int(dur * SR))
    for _ in range(n_grains):
        g = white(grain) * np.exp(-np.linspace(0, 5, int(grain * SR)))
        g = bandpass(g, RNG.uniform(*band), 900)
        place(out, g * RNG.uniform(0.3, 1.0) * level, RNG.uniform(0, dur - grain))
    return out


# --- effects -------------------------------------------------------------------

def cast():
    d = 0.42
    x = sweep_filter(white(d), lambda u: 500 + 2600 * math.sin(math.pi * u) ** 1.5, 0.5)
    x *= np.sin(np.linspace(0, math.pi, len(x))) ** 1.2
    return norm(x, 0.7)


def plop():
    d = 0.35
    n = int(d * SR)
    body = tone(glide(700, 180, d, 0.4), d) * env_ad(n, 0.001, 0.05)
    splash = lowpass(white(d), 2500) * env_ad(n, 0.001, 0.035) * 0.6
    bub = np.zeros(n)
    for k in range(4):
        b = 0.08
        place(bub, tone(glide(RNG.uniform(900, 1400), RNG.uniform(1500, 2200), b), b) * env_ad(int(b * SR), 0.001, 0.02) * 0.25,
              0.06 + k * 0.045)
    return norm(fade(body + splash + bub), 0.75)


def nibble():
    d = 0.18
    n = int(d * SR)
    x = tone(glide(900, 500, d), d) * env_ad(n, 0.001, 0.03) * 0.6 + lowpass(white(d), 1800) * env_ad(n, 0.001, 0.02) * 0.4
    return norm(fade(x), 0.45)


def splash(size=1.0):
    d = 0.5 + 0.4 * size
    n = int(d * SR)
    x = sweep_filter(white(d), lambda u: 3200 * (1 - 0.7 * u) + 300, 0.9) * env_ad(n, 0.004, 0.12 + 0.15 * size)
    drops = np.zeros(n)
    for _ in range(int(10 * size) + 6):
        b = 0.05
        place(drops, tone(glide(RNG.uniform(800, 2000), RNG.uniform(1800, 3200), b), b) * env_ad(int(b * SR), 0.001, 0.012)
              * RNG.uniform(0.1, 0.35), RNG.uniform(0.05, d - 0.06))
    low = lowpass(white(d), 300) * env_ad(n, 0.002, 0.08) * size
    return norm(fade(x + drops + low * 0.8), 0.85)


def reel_loop():
    d = 1.0
    x = np.zeros(int(d * SR))
    rate = 28
    for k in range(int(d * rate)):
        c = bandpass(white(0.006), RNG.uniform(3000, 4200), 800) * np.exp(-np.linspace(0, 6, int(0.006 * SR)))
        place(x, c * RNG.uniform(0.7, 1.0), k / rate)
    hum = bandpass(white(d), 600, 150) * 0.12
    return norm(loopify(np.concatenate([x + hum, (x + hum)[:int(0.05 * SR)]]), 0.05), 0.5)


def creak_loop():
    d = 1.6
    t = t_axis(d)
    x = bandpass(white(d), 900, 60) * (0.5 + 0.5 * np.sin(2 * np.pi * 3.1 * t) ** 2)
    x += bandpass(white(d), 1500, 40) * 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * 2.3 * t + 1))
    grit = crunch(40, d, (800, 2000), 0.02, 0.4)
    return norm(loopify(x + grit, 0.3), 0.45)


def snap():
    d = 0.5
    n = int(d * SR)
    twang = sum(tone(1700 * r, d) * env_ad(n, 0.0005, 0.08 / r) / r for r in (1, 2.01, 3.03))
    crack = highpass(white(d), 2000) * env_ad(n, 0.0005, 0.01)
    return norm(fade(reverb(twang * 0.6 + crack, 0.2, 0.6, 0.2)), 0.8)


def chime(notes=(660, 880, 990), gap=0.09, tau=0.5):
    d = gap * len(notes) + 1.0
    x = np.zeros(int(d * SR))
    for i, f in enumerate(notes):
        place(x, bell(f, 1.0, tau=tau), i * gap)
    return norm(fade(reverb(x, 0.3, 0.8, 0.2)), 0.6)


def perfect():
    return chime((880, 1175, 1568), 0.06, 0.4)


def catch_ok():
    return chime((523, 659, 784, 1046), 0.08, 0.6)


def fail():
    d = 0.6
    n = int(d * SR)
    x = tone(glide(330, 220, d), d) * env_ad(n, 0.01, 0.25) + tone(glide(262, 175, d), d) * env_ad(n, 0.01, 0.25) * 0.6
    return norm(fade(lowpass(x, 1200)), 0.4)


def ignite():
    d = 0.8
    n = int(d * SR)
    whoosh = sweep_filter(white(d), lambda u: 400 + 1800 * u, 0.6) * env_ad(n, 0.12, 0.25)
    crackle = crunch(30, d, (2000, 6000), 0.006, 0.6) * np.linspace(1, 0.3, n)
    return norm(fade(whoosh + crackle), 0.55)


def extinguish():
    d = 0.4
    n = int(d * SR)
    x = sweep_filter(white(d), lambda u: 1500 - 1100 * u, 0.6) * env_ad(n, 0.01, 0.12)
    return norm(fade(x), 0.4)


def flash():
    d = 0.9
    n = int(d * SR)
    zap = tone(glide(400, 2400, 0.25), 0.25)
    zap = np.concatenate([zap, np.zeros(n - len(zap))]) * env_ad(n, 0.005, 0.12)
    shimmer = sum(tone(f, d) * 0.2 for f in (2093, 2637, 3136)) * env_ad(n, 0.02, 0.3)
    burst = highpass(white(d), 1500) * env_ad(n, 0.001, 0.06)
    return norm(fade(reverb(zap * 0.6 + shimmer + burst * 0.7, 0.3, 1.0, 0.3)), 0.75)


def step(kind):
    if kind == "wood":
        d = 0.14
        n = int(d * SR)
        x = tone(glide(210, 150, d), d) * env_ad(n, 0.001, 0.03) + bandpass(white(d), 900, 300) * env_ad(n, 0.001, 0.01)
        return norm(fade(x), 0.35)
    if kind == "snow":
        return norm(fade(lowpass(crunch(35, 0.16, (900, 3500), 0.01), 5000)), 0.35)
    d = 0.1
    n = int(d * SR)
    x = lowpass(white(d), 900 if kind == "soft" else 1600) * env_ad(n, 0.004, 0.025)
    return norm(fade(x), 0.3)


def chain_loop():
    d = 2.4
    x = np.zeros(int(d * SR))
    t = 0.05
    while t < d - 0.2:
        f = RNG.uniform(1800, 3400)
        c = bell(f, 0.25, ((1, 1.0), (2.2, 0.6), (3.7, 0.4), (5.9, 0.3)), 0.06)
        place(x, c * RNG.uniform(0.3, 0.9), t)
        t += RNG.uniform(0.05, 0.22) if RNG.random() < 0.7 else RNG.uniform(0.3, 0.5)
    drag = bandpass(white(d), 1200, 500) * 0.15 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.8 * t_axis(d)))
    return norm(loopify(x + drag, 0.25), 0.5)


def whisper():
    d = 1.8
    t = t_axis(d)
    breath = sum(bandpass(white(d), f, bw) * a for f, bw, a in ((700, 120, 1.0), (1200, 150, 0.7), (2600, 300, 0.5)))
    am = np.clip(np.sin(2 * np.pi * 2.2 * t) * 0.5 + np.sin(2 * np.pi * 5.3 * t) * 0.3 + 0.35, 0, 1) ** 2
    x = breath * am * np.sin(np.linspace(0, math.pi, len(t)))
    return norm(fade(reverb(x, 0.5, 1.5, 0.45)), 0.5)


def moan():
    d = 2.6
    n = int(d * SR)
    f = glide(160, 110, d, 0.7) * (1 + 0.02 * np.sin(2 * np.pi * 5 * t_axis(d)))
    x = sum(tone(f * k, d) / k for k in (1, 2, 3)) * env_ad(n, 0.4, 1.2)
    x += bandpass(white(d), 500, 150) * env_ad(n, 0.3, 1.0) * 0.4
    return norm(fade(reverb(lowpass(x, 1400), 0.6, 2.0, 0.5)), 0.55)


def emerge():
    d = 1.6
    n = int(d * SR)
    gurgle = np.zeros(n)
    for _ in range(30):
        b = RNG.uniform(0.04, 0.12)
        f0 = RNG.uniform(150, 400)
        place(gurgle, tone(glide(f0, f0 * 2.2, b), b) * env_ad(int(b * SR), 0.005, b / 3) * RNG.uniform(0.2, 0.6),
              RNG.uniform(0, 0.9))
    big = splash(1.4)
    out = place(gurgle, big * 0.9, 0.7)
    return norm(fade(out + np.concatenate([moan()[:n] * 0.25, np.zeros(max(0, n - len(moan())))])[:n]), 0.8)


def cage():
    d = 0.8
    x = np.zeros(int(d * SR))
    for k in range(4):
        place(x, bell(RNG.uniform(300, 520), 0.5, ((1, 1.0), (2.4, 0.7), (4.1, 0.5), (6.6, 0.3)), 0.12) * RNG.uniform(0.6, 1.0),
              k * RNG.uniform(0.08, 0.14))
    return norm(fade(reverb(x, 0.3, 0.8, 0.25)), 0.65)


def heartbeat_loop():
    d = 0.85
    n = int(d * SR)
    x = np.zeros(n)
    for at, amp in ((0.0, 1.0), (0.22, 0.7)):
        b = 0.18
        th = tone(glide(70, 45, b), b) * env_ad(int(b * SR), 0.004, 0.05) * amp
        place(x, th, at)
    return norm(lowpass(x, 300), 0.8)


def offering():
    d = 2.2
    x = bell(196, d, ((1, 1.0), (2.0, 0.5), (2.76, 0.4), (5.4, 0.2)), 1.2) + bell(294, d, tau=1.0) * 0.4
    return norm(fade(reverb(x, 0.6, 1.8, 0.4)), 0.6)


def rock_flip():
    d = 0.5
    n = int(d * SR)
    scrape = bandpass(white(d), 1200, 500) * env_ad(n, 0.05, 0.12)
    thud = tone(glide(120, 60, 0.2), 0.2) * env_ad(int(0.2 * SR), 0.002, 0.05)
    x = place(scrape * 0.6, thud, 0.2)
    return norm(fade(x), 0.55)


def tap():
    d = 0.05
    n = int(d * SR)
    return norm(fade(bandpass(white(d), 2500, 900) * env_ad(n, 0.0005, 0.008)), 0.3)


def whoosh_hit():
    d = 0.45
    n = int(d * SR)
    w = sweep_filter(white(d), lambda u: 800 + 3000 * u, 0.5) * np.linspace(0.2, 1, n) ** 2
    hit = lowpass(white(0.12), 900) * env_ad(int(0.12 * SR), 0.001, 0.03)
    return norm(fade(place(w * 0.7, hit + bell(1320, 0.12, tau=0.08)[:len(hit)] * 0.3, 0.3)), 0.7)


def flop():
    d = 0.7
    x = np.zeros(int(d * SR))
    for k in range(3):
        s = lowpass(white(0.07), 1500) * env_ad(int(0.07 * SR), 0.001, 0.015)
        place(x, s * (1 - k * 0.25), k * 0.18 + RNG.uniform(0, 0.04))
    return norm(fade(x), 0.5)


def thunder():
    d = 4.0
    n = int(d * SR)
    crack = highpass(white(d), 800) * env_ad(n, 0.003, 0.08)
    rumble = lowpass(pink(d), 180) * env_ad(n, 0.15, 1.2) * (1 + 0.5 * np.sin(2 * np.pi * 1.3 * t_axis(d)))
    return norm(fade(crack * 0.4 + rumble, 0.01, 0.5), 0.9)


def escape_sparkle():
    d = 1.6
    x = np.zeros(int(d * SR))
    for k in range(10):
        place(x, bell(RNG.choice([1046, 1318, 1568, 2093, 2637]), 0.8, tau=0.3) * 0.5, k * 0.07)
    return norm(fade(reverb(x, 0.4, 1.2, 0.35)), 0.55)


# --- ambience (loops) ----------------------------------------------------------

def crickets(d, density=1.0, pitch=4300):
    x = np.zeros(int(d * SR))
    voices = int(5 * density)
    for v in range(voices):
        f = pitch * RNG.uniform(0.85, 1.15)
        period = RNG.uniform(0.6, 1.4)
        t = RNG.uniform(0, period)
        while t < d - 0.3:
            chirp_d = 0.12
            n = int(chirp_d * SR)
            pulses = (np.sin(2 * np.pi * 42 * np.arange(n) / SR) > 0.2).astype(float)
            c = tone(f, chirp_d) * pulses * np.hanning(n) * RNG.uniform(0.2, 0.5)
            place(x, c, t)
            t += period * RNG.uniform(0.8, 1.2)
    return x


def amb_night():
    d = 16.0
    wind = lowpass(pink(d), 400) * 0.35
    x = wind + crickets(d, 1.4) * 0.8
    return norm(loopify(x, 1.0), 0.45)


def amb_day():
    d = 18.0
    wind = lowpass(pink(d), 600) * 0.4 * (0.7 + 0.3 * np.sin(2 * np.pi * t_axis(d) / 9))
    birds = np.zeros(int(d * SR))
    for _ in range(7):
        at = RNG.uniform(0.5, d - 2)
        for k in range(RNG.integers(2, 5)):
            b = RNG.uniform(0.06, 0.14)
            f0 = RNG.uniform(2200, 3600)
            place(birds, tone(glide(f0, f0 * RNG.uniform(0.7, 1.4), b), b) * np.hanning(int(b * SR)) * 0.25, at + k * 0.13)
    x = wind + reverb(birds, 0.5, 1.0, 0.4)[:len(wind)] * 0.5 + crickets(d, 0.4) * 0.25
    return norm(loopify(x, 1.0), 0.4)


def amb_water():
    d = 12.0
    t = t_axis(d)
    lap = lowpass(white(d), 700) * (0.4 + 0.6 * np.clip(np.sin(2 * np.pi * t / 2.6) + np.sin(2 * np.pi * t / 4.1 + 1), 0, None))
    trickle = np.zeros(len(t))
    for _ in range(40):
        b = RNG.uniform(0.03, 0.07)
        f0 = RNG.uniform(600, 1300)
        place(trickle, tone(glide(f0, f0 * 1.6, b), b) * np.hanning(int(b * SR)) * RNG.uniform(0.05, 0.18), RNG.uniform(0, d - 0.1))
    return norm(loopify(lap + trickle, 0.8), 0.45)


def amb_rain():
    d = 10.0
    hiss = highpass(pink(d), 800) * 0.5
    drops = crunch(900, d, (1500, 6000), 0.008, 0.5)
    return norm(loopify(lowpass(hiss + drops, 7000), 0.8), 0.55)


def amb_wind():
    d = 16.0
    x = sweep_filter(pink(d), lambda u: 350 + 250 * math.sin(2 * math.pi * u * 2) + 150 * math.sin(2 * math.pi * u * 5), 0.4, 2048)
    howl = bandpass(white(d), 520, 25) * (0.5 + 0.5 * np.sin(2 * np.pi * t_axis(d) / 5.3)) * 0.6
    return norm(loopify(x + howl, 1.2), 0.5)


def amb_swamp():
    d = 16.0
    x = lowpass(pink(d), 300) * 0.3 + crickets(d, 0.8, 3600) * 0.5
    for _ in range(9):  # frogs
        at = RNG.uniform(0.3, d - 1.2)
        f = RNG.uniform(110, 190)
        for k in range(RNG.integers(2, 4)):
            b = 0.16
            n = int(b * SR)
            croak = sum(tone(f * h, b) / h for h in (1, 2, 3, 4)) * np.hanning(n) * (np.sin(2 * np.pi * 30 * np.arange(n) / SR) > 0)
            place(x, lowpass(croak, 1200) * 0.35, at + k * 0.22)
    return norm(loopify(x, 1.0), 0.45)


def amb_jungle():
    d = 16.0
    x = lowpass(pink(d), 800) * 0.25 + crickets(d, 2.0, 5200) * 0.5
    birds = np.zeros(int(d * SR))
    for _ in range(10):
        at = RNG.uniform(0.3, d - 1.5)
        f0 = RNG.uniform(900, 1800)
        for k in range(RNG.integers(2, 6)):
            b = 0.1
            place(birds, tone(glide(f0, f0 * 1.5, b), b) * np.hanning(int(b * SR)) * 0.3, at + k * 0.16)
    return norm(loopify(x + reverb(birds, 0.6, 1.2, 0.5)[:len(x)] * 0.6, 1.0), 0.45)


# --- music ---------------------------------------------------------------------

def pad(freqs, d, vib=0.004, bright=1400):
    t = t_axis(d)
    x = np.zeros(len(t))
    for f in freqs:
        for det in (-0.004, 0.0, 0.005):
            ff = f * (1 + det) * (1 + vib * np.sin(2 * np.pi * RNG.uniform(0.1, 0.3) * t + RNG.uniform(0, 6)))
            saw = sum(tone(ff * k, d) / k for k in range(1, 7))
            x += saw
    return lowpass(x, bright)


def music_day():
    """Eerie calm: slow minor pads (A minor -> F -> D minor -> E), soft bell."""
    bar = 6.0
    chords = [(110, 131, 165, 220), (87.3, 131, 175, 220), (73.4, 147, 175, 220), (82.4, 123, 165, 208)]
    d = bar * len(chords)
    x = np.zeros(int(d * SR))
    for i, ch in enumerate(chords):
        p = pad(ch, bar + 2.0, bright=900)
        n = len(p)
        env = np.clip(np.minimum(np.arange(n) / (1.5 * SR), (n - np.arange(n)) / (2.0 * SR)), 0, 1)
        place(x, p * env * 0.25, i * bar)
    tail = int(2.0 * SR)
    x[:tail] += x[-tail:] if len(x) > tail else 0
    for i in range(10):
        place(x, bell(RNG.choice([440, 523, 659, 880]), 2.0, tau=0.8) * 0.12, RNG.uniform(0, d - 2))
    return norm(loopify(reverb(x, 0.7, 2.5, 0.35)[:len(x)], 2.0), 0.4)


def music_night():
    """The hunt: low pulsing drone, a heartbeat, dissonant string swells."""
    d = 24.0
    t = t_axis(d)
    drone = pad((55, 58.3, 82.4), d, 0.006, 500) * 0.3
    pulse = np.zeros(len(t))
    beat = heartbeat_loop()
    k = 0.0
    while k < d - 1:
        place(pulse, beat * 0.6, k)
        k += 0.85
    swell = pad((233, 247, 311), d, 0.01, 2200) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 12 - 1.5)) ** 3 * 0.15
    ticks = np.zeros(len(t))
    for i in range(int(d / 0.425)):
        place(ticks, bandpass(white(0.02), 3000, 800) * np.hanning(int(0.02 * SR)) * 0.15, i * 0.425)
    return norm(loopify(drone + pulse + swell + ticks, 1.5), 0.5)


SOUNDS = {
    "cast": cast, "plop": plop, "nibble": nibble, "splash": lambda: splash(1.0), "splash_small": lambda: splash(0.4),
    "reel_loop": reel_loop, "creak_loop": creak_loop, "snap": snap, "perfect": perfect, "catch": catch_ok,
    "fail": fail, "ignite": ignite, "extinguish": extinguish, "flash": flash,
    "step_soft": lambda: step("soft"), "step_hard": lambda: step("hard"), "step_wood": lambda: step("wood"),
    "step_snow": lambda: step("snow"), "chain_loop": chain_loop, "whisper": whisper, "moan": moan,
    "emerge": emerge, "cage": cage, "heartbeat_loop": heartbeat_loop, "offering": offering,
    "rock_flip": rock_flip, "tap": tap, "swipe_hit": whoosh_hit, "flop": flop, "thunder": thunder,
    "escape": escape_sparkle,
    "amb_night": amb_night, "amb_day": amb_day, "amb_water": amb_water, "amb_rain": amb_rain,
    "amb_wind": amb_wind, "amb_swamp": amb_swamp, "amb_jungle": amb_jungle,
    "music_day": music_day, "music_night": music_night,
}


def write_wav(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    args = [a for a in sys.argv[1:]]
    only = None
    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")
        del args[args.index("--only"):args.index("--only") + 2]
    out = args[0] if args else os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        global RNG
        RNG = np.random.default_rng(zlib.crc32(name.encode()))
        x = fn()
        write_wav(os.path.join(out, name + ".wav"), x)
        print("wrote", name, "%.2fs" % (len(x) / SR), flush=True)


if __name__ == "__main__":
    main()
