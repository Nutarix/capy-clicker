#!/usr/bin/env python3
"""Generate ORIGINAL soft cozy mono WAV assets (16 kHz) for Grow! Capy!.

No copyrighted material — procedural pads / plucks / splash only.
Re-run: python3 tool/gen_audio.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import wave

SR = 16000
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def write_wav(path: Path, samples: np.ndarray, sr: int = SR) -> None:
    samples = np.clip(samples, -1.0, 1.0)
    pcm = (samples * 32767.0).astype(np.int16)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    print(f"  wrote {path.name} ({path.stat().st_size} bytes, {len(samples)/sr:.2f}s)")


def envelope(n: int, attack: float, release: float, sr: int = SR) -> np.ndarray:
    a = max(1, int(attack * sr))
    r = max(1, int(release * sr))
    env = np.ones(n, dtype=np.float64)
    env[:a] = np.linspace(0, 1, a, endpoint=False)
    if r < n:
        env[-r:] = np.linspace(1, 0, r)
    return env


def soft_tone(freqs, dur, vol=0.25, attack=0.04, release=0.12, sr=SR):
    n = int(dur * sr)
    t = np.arange(n) / sr
    sig = np.zeros(n, dtype=np.float64)
    for f, amp in freqs:
        sig += amp * np.sin(2 * math.pi * f * t)
        sig += amp * 0.18 * np.sin(2 * math.pi * f * 2 * t)
    sig = 0.7 * sig + 0.3 * np.roll(sig, 2)
    return sig * envelope(n, attack, release, sr) * vol


def noise_burst(
    dur, vol=0.15, band_low=400, band_high=2400, attack=0.005, release=0.08, sr=SR, seed=42
):
    n = int(dur * sr)
    rng = np.random.default_rng(seed)
    raw = rng.standard_normal(n)
    k1 = max(1, int(sr / band_high))
    k2 = max(1, int(sr / band_low))
    soft = np.convolve(raw, np.ones(k1) / k1, mode="same")
    warm = np.convolve(raw, np.ones(k2) / k2, mode="same")
    sig = soft - 0.35 * warm
    sig = sig / (np.max(np.abs(sig)) + 1e-9)
    return sig * envelope(n, attack, release, sr) * vol


def gen_bgm() -> None:
    dur = 12.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    root, fifth, octave = 110.0, 165.0, 220.0
    lfo = 0.5 + 0.5 * np.sin(2 * math.pi * (1.0 / dur) * t)
    lfo2 = 0.5 + 0.5 * np.sin(2 * math.pi * (2.0 / dur) * t + 1.2)
    sig = (
        0.22 * np.sin(2 * math.pi * root * t) * (0.55 + 0.45 * lfo)
        + 0.16 * np.sin(2 * math.pi * fifth * t) * (0.5 + 0.5 * lfo2)
        + 0.10 * np.sin(2 * math.pi * octave * t) * (0.4 + 0.6 * (1 - lfo))
        + 0.06 * np.sin(2 * math.pi * (root * 3) * t) * 0.35
    )
    sparkle = np.zeros(n)
    for beat in (0.0, 3.0, 6.0, 9.0):
        i0 = int(beat * SR)
        length = int(0.5 * SR)
        i1 = min(n, i0 + length)
        tt = np.arange(i1 - i0) / SR
        note = 440.0 if int(beat) % 6 == 0 else 550.0
        sparkle[i0:i1] += 0.04 * np.sin(2 * math.pi * note * tt) * np.exp(-tt * 3.5)
    sig = sig + sparkle
    fade = int(0.08 * SR)
    ramp = np.linspace(0, 1, fade)
    sig[:fade] = sig[:fade] * ramp + sig[-fade:] * (1 - ramp)
    sig[-fade:] = sig[:fade]
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * 0.55
    write_wav(OUT / "bgm_cozy.wav", sig)


def gen_sfx() -> None:
    a = soft_tone([(523.25, 1.0)], 0.12, vol=0.28, attack=0.004, release=0.09)
    b = soft_tone([(659.25, 0.85)], 0.14, vol=0.22, attack=0.004, release=0.10)
    sig = np.concatenate([a, np.zeros(int(0.04 * SR)), b[: int(0.10 * SR)]])
    nb = noise_burst(0.06, vol=0.04, band_low=800, band_high=4000)
    sig = sig + np.pad(nb, (0, max(0, len(sig) - len(nb))))[: len(sig)]
    write_wav(OUT / "sfx_flower.wav", sig)

    a = soft_tone([(392.0, 1.0)], 0.10, vol=0.30, attack=0.005, release=0.08)
    b = soft_tone([(587.33, 0.9), (784.0, 0.35)], 0.18, vol=0.26, attack=0.006, release=0.12)
    write_wav(OUT / "sfx_berry.wav", np.concatenate([a, np.zeros(int(0.03 * SR)), b]))

    parts = []
    for i, f in enumerate([349.23, 440.0, 523.25]):
        parts.append(soft_tone([(f, 1.0)], 0.14, vol=0.22 - i * 0.02, attack=0.008, release=0.10))
        parts.append(np.zeros(int(0.025 * SR)))
    write_wav(OUT / "sfx_merge.wav", np.concatenate(parts))

    splash = noise_burst(0.28, vol=0.22, band_low=200, band_high=1800, attack=0.01, release=0.18)
    thud = soft_tone([(90.0, 1.0), (140.0, 0.5)], 0.22, vol=0.20, attack=0.01, release=0.16)
    n = max(len(splash), len(thud))
    sig = np.zeros(n)
    sig[: len(thud)] += thud
    sig[: len(splash)] += splash
    write_wav(OUT / "sfx_wallow.wav", sig)

    a = soft_tone([(261.63, 1.0), (392.0, 0.7)], 0.35, vol=0.24, attack=0.02, release=0.22)
    b = soft_tone([(523.25, 0.6), (784.0, 0.35)], 0.40, vol=0.16, attack=0.03, release=0.28)
    out = np.zeros(len(a) + len(b) // 2 + int(0.08 * SR))
    out[: len(a)] += a
    start = int(0.12 * SR)
    out[start : start + len(b)] += b
    write_wav(OUT / "sfx_glade.wav", out)


def main() -> None:
    print(f"Generating into {OUT}")
    gen_bgm()
    gen_sfx()
    print("done")


if __name__ == "__main__":
    main()
