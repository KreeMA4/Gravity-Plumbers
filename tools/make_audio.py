#!/usr/bin/env python3
"""Generate every sound and music loop for Gravity Plumbers.

Python standard library only (numpy is NOT needed). Writes mono 16-bit
22,050 Hz WAV files into assets/audio/. Run from the project root:

    python3 tools/make_audio.py

Everything is synthesised from scratch (oscillators, noise, envelopes,
simple filters), so there is no copyrighted material. Music loops are
rendered "circularly" (tails wrap round to the start) so they loop seamlessly.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
random.seed(20261122)


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------
def silence(sec):
    return [0.0] * int(sec * RATE)


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "saw":
        return 2.0 * p - 1.0
    if kind == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    return 0.0


def tone(freq_fn, sec, kind="sine", vol=0.5, attack=0.005, release=0.05, vib=0.0, vib_rate=6.0):
    """freq_fn: a number or a function t -> Hz."""
    n = int(sec * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq_fn(t) if callable(freq_fn) else freq_fn
        if vib:
            f *= 1.0 + vib * math.sin(2 * math.pi * vib_rate * t)
        phase += f / RATE
        env = 1.0
        if t < attack:
            env = t / attack
        elif t > sec - release:
            env = max(0.0, (sec - t) / release)
        out.append(osc(kind, phase) * env * vol)
    return out


def noise(sec, vol=0.5, attack=0.002, release=0.05):
    n = int(sec * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = 1.0
        if t < attack:
            env = t / attack
        elif t > sec - release:
            env = max(0.0, (sec - t) / release)
        out.append((random.random() * 2 - 1) * env * vol)
    return out


def decay(samples, rate):
    return [s * math.exp(-rate * i / RATE) for i, s in enumerate(samples)]


def lowpass(samples, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    a = (1.0 / RATE) / (rc + 1.0 / RATE)
    y = 0.0
    out = []
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    lp = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, lp)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def place(dst, src, at_sec, wrap=False):
    start = int(at_sec * RATE)
    n = len(dst)
    for i, s in enumerate(src):
        j = start + i
        if wrap:
            dst[j % n] += s
        elif j < n:
            dst[j] += s


def concat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def normalize(samples, peak=0.85):
    m = max(1e-9, max(abs(s) for s in samples))
    return [s * peak / m for s in samples]


def write(name, samples, peak=0.85):
    samples = normalize(samples, peak)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))
    print("  %-16s %5.2fs" % (name, len(samples) / RATE))


def note(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12.0)


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------
def sfx():
    print("Sound effects:")
    write("footstep", decay(lowpass(mix(noise(0.09, 0.6), tone(lambda t: 180 - 600 * t, 0.09, "sine", 0.6)), 900), 30))
    write("jump", decay(tone(lambda t: 220 + 900 * t, 0.22, "sine", 0.7, vib=0.05, vib_rate=30), 6))
    write("land", decay(lowpass(mix(noise(0.18, 0.7), tone(lambda t: 120 - 200 * t, 0.18, "sine", 0.9)), 500), 18))
    write("grab", decay(tone(lambda t: 900 + 1400 * t, 0.1, "square", 0.25), 25))
    write("release", decay(tone(lambda t: 700 - 300 * t, 0.07, "sine", 0.6), 40))
    for i, (vol, f0, length) in enumerate([(0.5, 220, 0.15), (0.75, 150, 0.22), (1.0, 95, 0.32)], start=1):
        write("impact_%d" % i, decay(lowpass(mix(noise(length, vol), tone(lambda t, f0=f0: f0 * (1 - t), length, "sine", vol)), 1200), 10 / length))
    write("whoosh", lowpass(highpass(noise(0.4, 0.6, attack=0.15, release=0.2), 300), 2500))
    write("plunger_thwock", decay(mix(tone(lambda t: 160 - 100 * t, 0.2, "sine", 0.9), lowpass(noise(0.05, 0.5), 2000)), 14))
    write("plunger_suck", tone(lambda t: 300 + 1200 * t * t, 0.35, "sine", 0.6, vib=0.08, vib_rate=40))
    write("wrench_clank", decay(mix(tone(1240, 0.4, "square", 0.25), tone(1870, 0.4, "sine", 0.35), tone(620, 0.4, "tri", 0.3)), 12))
    write("tape_rip", lowpass(highpass(noise(0.35, 0.7, attack=0.01, release=0.08), 1500), 6000))
    write("leak_hiss", lowpass(highpass(noise(0.9, 0.4, attack=0.1, release=0.3), 2500), 7000))
    write("leak_spray", mix(lowpass(noise(0.6, 0.6, release=0.3), 3000), decay(tone(lambda t: 500 - 300 * t, 0.6, "sine", 0.3), 4)))
    write("valve_creak", lowpass(tone(lambda t: 140 + 40 * math.sin(t * 25), 0.45, "saw", 0.5, vib=0.1, vib_rate=17), 1400))
    write("pipe_snap", decay(mix(tone(lambda t: 300 - 200 * t, 0.25, "square", 0.4), lowpass(noise(0.06, 0.8), 1500)), 12))
    write("sludge_splat", decay(lowpass(mix(noise(0.3, 0.8), tone(lambda t: 200 - 300 * t, 0.3, "sine", 0.6)), 800), 9))
    glug = concat(*[decay(tone(lambda t, k=k: 180 + 60 * k + 200 * t, 0.09, "sine", 0.8), 25) for k in range(3)])
    write("sludge_glug", lowpass(glug, 1500))
    siren = tone(lambda t: 600 + 300 * math.sin(2 * math.pi * 2.5 * t), 1.2, "square", 0.35, release=0.2)
    write("gravity_siren", lowpass(siren, 2500))
    whoomp = mix(tone(lambda t: 60 + 500 * (t / 0.9) ** 2, 0.9, "saw", 0.4, attack=0.1, release=0.3),
                 lowpass(noise(0.9, 0.4, attack=0.3, release=0.4), 600))
    write("gravity_whoomp", lowpass(whoomp, 1800))
    write("boots_clamp", decay(mix(tone(220, 0.2, "square", 0.4), tone(330, 0.2, "square", 0.25), lowpass(noise(0.03, 0.6), 3000)), 18))
    write("flush", mix(tone(lambda t: 800 - 700 * t / 1.2, 1.2, "sine", 0.5, vib=0.15, vib_rate=9, release=0.3),
                       lowpass(noise(1.2, 0.4, attack=0.1, release=0.5), 1200)))
    write("ui_click", decay(tone(1500, 0.05, "square", 0.3), 60))
    write("ui_hover", decay(tone(2200, 0.03, "sine", 0.3), 80))
    write("ui_confirm", concat(decay(tone(880, 0.07, "square", 0.3), 30), decay(tone(1320, 0.12, "square", 0.3), 20)))
    write("ui_back", concat(decay(tone(660, 0.06, "square", 0.3), 35), decay(tone(440, 0.1, "square", 0.3), 25)))
    rattle = silence(0.5)
    for k in range(9):
        place(rattle, decay(mix(noise(0.03, 0.6), tone(2000 + random.random() * 1500, 0.03, "sine", 0.4)), 80), k * 0.05 + random.random() * 0.02)
    write("dice_rattle", highpass(rattle, 800))
    jingle = silence(0.9)
    for k, n in enumerate([72, 76, 79, 84]):
        place(jingle, decay(mix(tone(note(n), 0.35, "square", 0.25), tone(note(n) * 2, 0.35, "sine", 0.15)), 7), k * 0.12)
    write("work_done", lowpass(jingle, 5000))
    fanfare = silence(2.4)
    for k, (n, d) in enumerate([(67, 0.15), (67, 0.15), (67, 0.15), (72, 0.7), (76, 0.25), (79, 0.9)]):
        at = [0, 0.18, 0.36, 0.54, 1.25, 1.5][k]
        place(fanfare, decay(mix(tone(note(n), d + 0.2, "saw", 0.2), tone(note(n - 12), d + 0.2, "square", 0.15)), 2.5), at)
    write("level_clear", lowpass(fanfare, 4000))
    wah = silence(2.2)
    for k, n in enumerate([67, 66, 65]):
        place(wah, tone(note(n), 0.5, "saw", 0.4, vib=0.02, vib_rate=5, release=0.2), k * 0.55)
    place(wah, tone(lambda t: note(64) * (1 - 0.06 * t), 0.9, "saw", 0.4, vib=0.04, vib_rate=6, release=0.4), 1.65)
    write("fail", lowpass(wah, 1500))
    # Gibberish voice blip (pitch-shifted at runtime by AudioManager).
    write("blip", decay(mix(tone(520, 0.07, "square", 0.3), tone(1040, 0.07, "sine", 0.2)), 22), 0.6)


# ---------------------------------------------------------------------------
# Music (seamless loops)
# ---------------------------------------------------------------------------
def kick():
    return decay(tone(lambda t: 120 * math.exp(-t * 25) + 45, 0.3, "sine", 1.0), 9)


def snare():
    return decay(mix(highpass(noise(0.2, 0.6), 1200), tone(190, 0.2, "tri", 0.3)), 18)


def hat(vol=0.25):
    return decay(highpass(noise(0.05, vol), 6000), 60)


def pluck_bass(n, length):
    return lowpass(decay(tone(note(n), length, "saw", 0.6, release=0.03), 4), 700)


def epiano(notes, length, vol=0.12):
    parts = [decay(mix(tone(note(n), length, "sine", vol, vib=0.004, vib_rate=5), tone(note(n) * 2, length, "sine", vol * 0.3)), 2.2) for n in notes]
    return mix(*parts)


def music_game(bpm=112, bars=8):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    out = silence(total)
    chords = [[57, 60, 64, 67], [62, 65, 69, 72], [55, 59, 62, 65], [60, 64, 67, 71]]   # Am7 Dm7 G7 Cmaj7
    roots = [45, 50, 43, 48]
    bass_pattern = [0, None, 0, 12, None, 7, 10, None]
    for bar in range(bars):
        t0 = bar * 4 * beat
        c = bar % 4
        for b in range(4):
            place(out, kick(), t0 + b * beat, wrap=True) if b in (0, 2) else None
            if b in (1, 3):
                place(out, snare(), t0 + b * beat, wrap=True)
        for e in range(8):
            place(out, hat(0.18 if e % 2 else 0.28), t0 + e * beat / 2, wrap=True)
            iv = bass_pattern[e]
            if iv is not None:
                place(out, pluck_bass(roots[c] + iv, beat * 0.45), t0 + e * beat / 2, wrap=True)
        place(out, epiano(chords[c], beat * 1.6), t0 + 0.5 * beat, wrap=True)
        place(out, epiano(chords[c], beat * 1.2, 0.08), t0 + 2.75 * beat, wrap=True)
    return out


def music_storm(bpm=112, bars=8):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    out = silence(total)
    for bar in range(bars):
        t0 = bar * 4 * beat
        for s in range(16):
            place(out, hat(0.2), t0 + s * beat / 4, wrap=True)
            place(out, lowpass(decay(tone(note(33 + (7 if bar % 2 else 0)), beat / 4, "saw", 0.5), 10), 400), t0 + s * beat / 4, wrap=True)
        siren = tone(lambda t: note(81) * (1 + 0.03 * math.sin(2 * math.pi * 0.5 * t)), 4 * beat, "tri", 0.07, attack=0.5, release=0.5)
        place(out, siren, t0, wrap=True)
        place(out, kick(), t0, wrap=True)
        place(out, kick(), t0 + 2.5 * beat, wrap=True)
    return out


def music_menu(bpm=78, bars=8):
    beat = 60.0 / bpm
    total = bars * 4 * beat
    out = silence(total)
    chords = [[60, 64, 67, 71], [57, 60, 64, 69], [65, 69, 72, 76], [62, 65, 69, 72]]
    for bar in range(bars):
        t0 = bar * 4 * beat
        c = chords[bar % 4]
        pad = mix(*[tone(note(n), 4 * beat, "tri", 0.05, attack=0.8, release=1.2, vib=0.003, vib_rate=3) for n in c])
        place(out, lowpass(pad, 1500), t0, wrap=True)
        for k in range(8):
            n = c[[0, 1, 2, 3, 2, 1, 2, 3][k]] + 12
            place(out, decay(tone(note(n), beat * 0.8, "sine", 0.12), 4), t0 + k * beat / 2, wrap=True)
        place(out, lowpass(decay(tone(note(c[0] - 24), 3 * beat, "sine", 0.35), 1.2), 300), t0, wrap=True)
    return out


def music():
    print("Music loops:")
    write("music_game", music_game(), 0.7)
    write("music_storm", music_storm(), 0.7)
    write("music_menu", music_menu(), 0.6)


if __name__ == "__main__":
    sfx()
    music()
    print("Done -> %s" % os.path.abspath(OUT))
