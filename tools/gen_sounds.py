"""Generates all sound effects and the music loop in assets/sounds/ (Ogg Vorbis, via ffmpeg).

Everything is synthesized from sines and filtered noise, so it stays soft and toy-like and needs no
recordings. Run: python3 tools/gen_sounds.py  (then re-import the project). To use real recordings,
replace any .ogg in assets/sounds/ with one of the same name.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
rng = np.random.default_rng(7)


def t_of(dur):
    return np.arange(int(dur * SR)) / SR


def env(dur, attack=0.005, decay=0.2):
    """Quick rise, exponential fall (decay = time to fall to ~1/e)."""
    t = t_of(dur)
    e = np.exp(-np.maximum(0, t - attack) / decay)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * e


def sweep(f0, f1, dur, shape="sin"):
    """A tone gliding from f0 to f1 (exponentially)."""
    t = t_of(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def tone(f, dur):
    return np.sin(2 * np.pi * f * t_of(dur))


def bell(f, dur, decay=0.5, bright=0.35):
    """A music-box / glockenspiel note: a few partials, the high ones fade first."""
    t = t_of(dur)
    s = np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    s += bright * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (decay * 0.45))
    s += bright * 0.4 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / (decay * 0.25))
    return s * np.clip(t / 0.003, 0, 1)


def chime_note(f, dur, decay=1.2):
    """Wind-chime tube: inharmonic partials."""
    t = t_of(dur)
    s = 0
    for ratio, amp, dk in [(1, 1, 1), (2.76, 0.5, 0.5), (5.40, 0.25, 0.3), (8.93, 0.12, 0.2)]:
        s = s + amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (decay * dk))
    return s * np.clip(t / 0.002, 0, 1)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


def band(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def low(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def high(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def mix(dur, *parts):
    """parts: (start_seconds, samples). Returns one buffer `dur` long."""
    out = np.zeros(int(dur * SR))
    for start, s in parts:
        i = int(start * SR)
        n = min(len(s), len(out) - i)
        if n > 0:
            out[i:i + n] += s[:n]
    return out


def grains(dur, count, lo, hi, length=0.012, spread=None, gain_fall=0.0):
    """Little clicks of filtered noise scattered over `dur` (pellets, seeds, crunches)."""
    parts = []
    for k in range(count):
        at = (spread or (lambda i: rng.uniform(0, dur * 0.8)))(k)
        g = band(noise(length), lo, hi) * env(length, 0.001, length / 3)
        parts.append((at, g * rng.uniform(0.6, 1.0) * (1 - gain_fall * k / count)))
    return mix(dur, *parts)


def fade_tail(x, ms=15):
    n = int(SR * ms / 1000)
    if len(x) > n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=float)
    m = np.max(np.abs(x)) or 1.0
    x = fade_tail(x / m * peak)
    data = (x * 32767).astype("<i2").tobytes()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.unlink(tmp)


# ---- notes ----------------------------------------------------------------------

def hz(note):
    """'C5', 'F#4' ... -> Hz."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note[0]]
    rest = note[1:]
    if rest.startswith("#"):
        n += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        n -= 1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + n
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---- sound effects -----------------------------------------------------------------

def sfx():
    # UI
    save("tap", sweep(620, 380, 0.06) * env(0.06, 0.002, 0.018), 0.5)
    save("notify", mix(0.35, (0, bell(hz("G5"), 0.3, 0.12, 0.2)), (0.08, bell(hz("C6"), 0.27, 0.14, 0.2))), 0.45)
    save("coin", mix(0.5, (0, bell(hz("B5"), 0.2, 0.06)), (0.07, bell(hz("E6"), 0.43, 0.16))), 0.6)
    save("buy", mix(0.6, (0, high(noise(0.03), 2500) * env(0.03, 0.001, 0.008) * 0.5),
                    (0.03, bell(hz("E6"), 0.2, 0.06)), (0.1, bell(hz("G6"), 0.2, 0.07)),
                    (0.17, bell(hz("C7"), 0.43, 0.16))), 0.6)
    fan = [(i * 0.11, bell(hz(n), 1.4 - i * 0.11, 0.5)) for i, n in enumerate(["C5", "E5", "G5", "C6"])]
    fan += [(0.45, bell(hz(n), 1.2, 0.8, 0.2) * 0.5) for n in ["E5", "G5", "C6", "E6"]]
    save("fanfare", mix(1.7, *fan), 0.7)
    save("star", bell(hz("A6"), 0.5, 0.15) + 0.5 * bell(hz("E7"), 0.5, 0.1), 0.45)
    save("sparkle", mix(0.7, *[(i * 0.07, bell(hz(n), 0.4, 0.09, 0.2))
                                for i, n in enumerate(["E6", "G6", "A6", "C7", "E7"])]), 0.4)

    # camera
    click = lambda: band(noise(0.012), 1500, 7000) * env(0.012, 0.0005, 0.003)
    save("shutter", mix(0.2, (0, click()), (0.004, low(noise(0.05), 900) * env(0.05, 0.001, 0.015) * 0.6),
                        (0.075, click() * 0.8)), 0.6)

    # care
    save("pellets", grains(0.5, 16, 2000, 5000, 0.01, gain_fall=0.6), 0.6)
    save("seeds", grains(0.55, 26, 3500, 8000, 0.006, gain_fall=0.5), 0.45)
    rustle = band(noise(0.6), 1500, 6000) * (0.5 + 0.5 * np.abs(low(noise(0.6), 18))) * env(0.6, 0.05, 0.25)
    save("hay", rustle, 0.4)
    pour = band(noise(0.8), 500, 1600) * env(0.8, 0.06, 0.35) * 0.5
    bubbles = [(rng.uniform(0.05, 0.6), sweep(rng.uniform(350, 600), rng.uniform(800, 1300), 0.04)
                * env(0.04, 0.002, 0.015) * 0.6) for _ in range(9)]
    save("water", mix(0.8, (0, pour), *bubbles), 0.45)
    scrape = lambda d: band(noise(d), 800, 3500) * np.sin(np.linspace(0, np.pi, int(d * SR)))
    save("scrape", mix(0.9, (0, scrape(0.18)), (0.22, scrape(0.2)),
                       *[(0.45 + i * 0.07, bell(hz(n), 0.35, 0.08, 0.2) * 0.35) for i, n in enumerate(["E6", "A6", "C7"])]), 0.45)
    save("pluck", mix(0.5, (0, band(noise(0.05), 600, 3000) * env(0.05, 0.001, 0.012)),
                      (0.03, sweep(500, 260, 0.12) * env(0.12, 0.002, 0.04) * 0.6),
                      (0.12, bell(hz("G6"), 0.35, 0.1, 0.2) * 0.3)), 0.5)
    save("drip", mix(0.6, *[(i * 0.14, sweep(600 + 80 * i, 1100 + 80 * i, 0.05) * env(0.05, 0.002, 0.018))
                            for i in range(3)]), 0.4)
    save("door", mix(0.7, (0, low(noise(0.04), 1200) * env(0.04, 0.001, 0.012)),
                     (0.02, sweep(140, 90, 0.08) * env(0.08, 0.002, 0.03) * 0.8),
                     (0.08, band(noise(0.5), 300, 1500) * np.sin(np.linspace(0, np.pi, int(0.5 * SR))) * 0.25)), 0.5)
    chimes = [(i * 0.16 + rng.uniform(0, 0.05), chime_note(hz(n), 2.2 - i * 0.16, 0.9) * rng.uniform(0.6, 1))
              for i, n in enumerate(["E6", "G6", "C7", "A6", "D7"])]
    save("chime", mix(2.3, *chimes), 0.5)
    chirp = lambda f: sweep(f, f * 1.45, 0.05) * env(0.05, 0.002, 0.02)
    save("chirp", mix(0.45, (0, chirp(3200)), (0.08, chirp(3500)), (0.2, chirp(2900) * 0.8)), 0.35)
    save("ball", mix(0.9, *[(at, sweep(260, 170, 0.07) * env(0.07, 0.001, 0.02) * g)
                            for at, g in [(0, 1), (0.28, 0.6), (0.48, 0.38), (0.62, 0.22), (0.72, 0.12)]]), 0.5)

    # Bubák
    save("thump", sweep(110, 42, 0.22) * env(0.22, 0.002, 0.07) + 0.4 * low(noise(0.22), 300) * env(0.22, 0.001, 0.03), 0.9)
    vib = sweep(320, 950, 0.32) * (1 + 0.0 * t_of(0.32))
    save("boing", vib * env(0.32, 0.005, 0.12), 0.45)
    save("munch", grains(0.6, 6, 1200, 3200, 0.03, spread=lambda i: i * 0.1 + rng.uniform(0, 0.02)), 0.45)
    save("lap", mix(0.55, *[(i * 0.15, sweep(420, 700, 0.045) * env(0.045, 0.002, 0.015)) for i in range(3)]), 0.4)
    save("purr", grains(0.9, 22, 2500, 6000, 0.005, spread=lambda i: i * 0.038), 0.3)
    save("love", bell(hz("E6"), 0.35, 0.09, 0.15) + 0.4 * bell(hz("B6"), 0.35, 0.06, 0.1), 0.3)
    save("surprise", sweep(700, 1500, 0.08) * env(0.08, 0.003, 0.04), 0.35)
    save("huh", mix(0.3, (0, sweep(520, 480, 0.08) * env(0.08, 0.004, 0.04)),
                    (0.1, sweep(500, 760, 0.12) * env(0.12, 0.004, 0.05))), 0.3)
    save("hop", sweep(150, 90, 0.05) * env(0.05, 0.001, 0.015), 0.35)
    save("dig", grains(0.5, 10, 500, 2000, 0.03, spread=lambda i: i * 0.045), 0.4)

    # work mini-games
    save("good", sweep(880, 1320, 0.07) * env(0.07, 0.002, 0.04) + 0.3 * bell(hz("E6"), 0.07, 0.04), 0.4)
    save("bad", sweep(240, 160, 0.18, "tri") * env(0.18, 0.004, 0.08), 0.4)
    save("streak", mix(0.5, *[(i * 0.06, bell(hz(n), 0.3, 0.1)) for i, n in enumerate(["C6", "E6", "G6", "C7"])]), 0.5)


# ---- music --------------------------------------------------------------------------

def music():
    """A slow music-box lullaby over a soft pad, ~46 s, looping seamlessly."""
    bpm = 84
    beat = 60 / bpm
    bars = 16
    total = bars * 4 * beat
    n = int(total * SR)
    out = np.zeros(n)

    def put(at, s):
        i = int(at * SR) % n
        k = min(len(s), n - i)
        out[i:i + k] += s[:k]
        if k < len(s):       # wraps round to the start: seamless loop
            out[:len(s) - k] += s[k:]

    chords = [["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]]
    bass = ["C3", "A2", "F2", "G2"]
    # melody: beats within each bar (beat, note, length in beats); A A' B A''
    a = [[(0, "E5", 1), (1, "G5", 1), (2, "A5", 1.5), (3.5, "G5", .5)],
         [(0, "E5", 1.5), (1.5, "D5", .5), (2, "C5", 2)],
         [(0, "A4", 1), (1, "C5", 1), (2, "F5", 1.5), (3.5, "E5", .5)],
         [(0, "D5", 2), (2, "G4", 1), (3, "B4", 1)]]
    a2 = [a[0], [(0, "E5", 1), (1, "G5", 1), (2, "C6", 2)], a[2], [(0, "D5", 1.5), (1.5, "E5", .5), (2, "C5", 2)]]
    b = [[(0, "G5", 1), (1, "E5", .5), (1.5, "G5", .5), (2, "C6", 2)],
         [(0, "A5", 1), (1, "G5", 1), (2, "E5", 2)],
         [(0, "F5", 1), (1, "A5", 1), (2, "G5", 1), (3, "F5", 1)],
         [(0, "E5", 1), (1, "D5", 1), (2, "B4", 1), (3, "D5", 1)]]
    a3 = [a[0], a[1], a[2], [(0, "D5", 1), (1, "E5", 1), (2, "C5", 2)]]
    melody = a + a2 + b + a3
    for bar in range(bars):
        t0 = bar * 4 * beat
        ch = chords[bar % 4]
        # pad: slow swell per bar
        d = 4 * beat
        tt = t_of(d)
        sw = np.sin(np.pi * tt / d) ** 1.5
        pad = sum(np.sin(2 * np.pi * hz(x) * tt) + 0.3 * np.sin(2 * np.pi * hz(x) * 2.003 * tt) for x in ch)
        put(t0, low(pad, 1200) * sw * 0.05)
        put(t0, bell(hz(bass[bar % 4]), 3 * beat, 1.2, 0.15) * 0.16)
        put(t0 + 2 * beat, bell(hz(bass[bar % 4]) * 1.5, 2 * beat, 0.9, 0.1) * 0.08)
        # gentle arpeggio on the off-beats
        for i, x in enumerate(ch + [ch[1]]):
            put(t0 + (i + 0.5) * beat, bell(hz(x) * 2, 1.0, 0.35, 0.2) * 0.05)
        for at, note, ln in melody[bar]:
            put(t0 + at * beat, bell(hz(note), ln * beat + 1.2, 0.55 + 0.15 * ln) * 0.22)
    # a touch of echo for a cozy room feel
    d = int(beat * 0.75 * SR)
    echo = np.roll(out, d) * 0.22 + np.roll(out, 2 * d) * 0.08
    out = low(out + echo, 5000)
    m = np.max(np.abs(out))
    x = out / m * 0.7
    data = (x * 32767).astype("<i2").tobytes()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3",
                    os.path.join(OUT, "music.ogg")], check=True)
    os.unlink(tmp)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx()
    music()
    print("sounds:", len([f for f in os.listdir(OUT) if f.endswith(".ogg")]))
