#!/usr/bin/env python3
"""Generates every sound effect in assets/sfx (stdlib only, deterministic).

All sounds are synthesised here, so they are original and MIT-licensed with the code.
Run: python3 tools/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
rng = random.Random(1993)


def write(name, samples, peak=0.9):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * k)) * 32767)) for s in samples))
    print("wrote", path, len(samples) / SR, "s")


def n(sec):
    return int(sec * SR)


def noise(count):
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def lowpass(x, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def env_exp(count, tau):
    return [math.exp(-i / SR / tau) for i in range(count)]


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def thump(sec, f0, f1, tau):
    c = n(sec)
    out, ph = [], 0.0
    for i in range(c):
        t = i / c
        f = f0 + (f1 - f0) * t
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-i / SR / tau))
    return out


def click(sec, cutoff, tau, gain=1.0):
    c = n(sec)
    x = highpass(noise(c), cutoff)
    e = env_exp(c, tau)
    return [a * b * gain for a, b in zip(x, e)]


def tone(sec, freqs, tau, vib=0.0, vib_rate=0.0):
    c = n(sec)
    out = []
    for i in range(c):
        t = i / SR
        s = 0.0
        for f, a in freqs:
            fv = f * (1.0 + vib * math.sin(2 * math.pi * vib_rate * t))
            s += a * math.sin(2 * math.pi * fv * t)
        out.append(s * math.exp(-t / tau) if tau > 0 else s)
    return out


def fade(x, fin=0.005, fout=0.02):
    a, b = n(fin), n(fout)
    x = list(x)
    for i in range(min(a, len(x))):
        x[i] *= i / a
    for i in range(min(b, len(x))):
        x[-1 - i] *= i / b
    return x


def whistle(sec):
    c = n(sec)
    out = []
    ph = 0.0
    for i in range(c):
        t = i / SR
        f = 2900 * (1 + 0.025 * math.sin(2 * math.pi * 32 * t))
        ph += 2 * math.pi * f / SR
        trill = 0.6 + 0.4 * (1 if math.sin(2 * math.pi * 32 * t) > 0 else 0)
        out.append(math.sin(ph) * trill)
    breath = lowpass(highpass(noise(c), 2000), 6000)
    return fade(mix(out, [b * 0.25 for b in breath]), 0.01, 0.04)


def crowd(sec, cutoff=900, swell=None):
    c = n(sec)
    x = lowpass(highpass(noise(c), 180), cutoff)
    x = lowpass(x, cutoff * 1.3)
    out = []
    for i, s in enumerate(x):
        t = i / SR
        mod = 0.8 + 0.2 * math.sin(2 * math.pi * 0.7 * t) * math.sin(2 * math.pi * 1.9 * t)
        g = swell(t / sec) if swell else 1.0
        out.append(s * mod * g)
    return out


def square(f, sec, duty=0.5, amp=1.0):
    c = n(sec)
    out = []
    for i in range(c):
        t = i / SR
        ph = (t * f) % 1.0
        out.append((1.0 if ph < duty else -1.0) * amp * math.exp(-t / (sec * 0.9)))
    return out


def jingle():
    notes = [(523.25, 0.14), (659.25, 0.14), (783.99, 0.14), (1046.5, 0.34), (783.99, 0.12), (1046.5, 0.6)]
    out = []
    for f, d in notes:
        a = square(f, d, 0.5, 0.5)
        b = square(f * 0.5, d, 0.25, 0.35)
        out += fade(mix(a, b), 0.003, 0.02)
    return lowpass(out, 5000)


def main():
    os.makedirs(OUT, exist_ok=True)
    write("kick", fade(mix(thump(0.16, 150, 55, 0.05), click(0.05, 1500, 0.008, 0.5))))
    write("kick_hard", fade(mix(thump(0.22, 180, 50, 0.07), click(0.06, 1200, 0.012, 0.8))))
    write("bounce", fade(thump(0.1, 110, 70, 0.03)), 0.6)
    write("wall", fade(mix(thump(0.3, 160, 90, 0.07), lowpass(click(0.25, 300, 0.05, 1.0), 1800), tone(0.3, [(240, 0.3), (410, 0.15)], 0.06))))
    write("post", fade(tone(1.0, [(523, 1.0), (1347, 0.6), (2215, 0.35), (3460, 0.2)], 0.28)))
    write("net", fade([s * e for s, e in zip(lowpass(highpass(noise(n(0.35)), 800), 5000), [math.sin(math.pi * i / n(0.35)) for i in range(n(0.35))])]), 0.5)
    write("whistle", whistle(0.45))
    gap = [0.0] * n(0.12)
    write("whistle_end", whistle(0.25) + gap + whistle(0.25) + gap + whistle(0.9))
    write("tackle", fade(mix(thump(0.25, 90, 45, 0.08), lowpass(click(0.2, 200, 0.06, 1.2), 1200))))
    write("catch", fade(lowpass(click(0.12, 150, 0.03, 1.0), 900)), 0.6)
    write("cheer", fade(crowd(3.2, 1400, lambda u: min(1.0, u * 6.0) * (1.0 - max(0.0, u - 0.55) / 0.45)), 0.05, 0.3))
    write("groan", fade(crowd(1.3, 700, lambda u: math.sin(math.pi * u)), 0.05, 0.2), 0.6)
    write("goal_jingle", jingle(), 0.6)
    # seamless crowd bed: crossfade the tail into the head
    bed = crowd(7.0, 650)
    xf = n(1.0)
    body = bed[:-xf]
    for i in range(xf):
        a = i / xf
        body[i] = body[i] * a + bed[len(bed) - xf + i] * (1 - a)
    write("crowd_loop", body, 0.5)


if __name__ == "__main__":
    main()
