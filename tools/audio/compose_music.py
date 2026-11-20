#!/usr/bin/env python3
"""Dark City soundtrack generator (developer tool, not part of the game).

Every music track and the rain ambience in asset/audio/ is *synthesised* by
this script: no samples, no external music, so there are no licence worries.
It is a tiny "tracker" written with numpy:

  * notes are written as (start_beat, length_beats, "A4") tuples,
  * instruments are additive synthesisers (sums of sine harmonics) with
    filter and volume envelopes,
  * drums are shaped noise and pitch-swept sines,
  * a convolution reverb and a ping-pong delay add space,
  * everything is mixed *circularly*, so looping tracks loop without a seam.

Usage (from the project folder):
    python3 tools/audio/compose_music.py
Needs: python3 + numpy, and ffmpeg on the PATH (for the .ogg encoding).
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MUSIC_DIR = os.path.join(ROOT, "asset", "audio", "music")
SFX_DIR = os.path.join(ROOT, "asset", "audio", "sfx")
rng = np.random.default_rng(1984)  # fixed seed = the same music every run

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
        "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name):
    """'A4' -> 69 (MIDI note number)."""
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


def mtof(m):
    """MIDI note number -> frequency in Hz."""
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


CHORDS = {  # chord name -> MIDI notes of a root-position triad around octave 3
    "Am": ["A3", "C4", "E4"], "F": ["F3", "A3", "C4"], "C": ["C4", "E4", "G4"],
    "G": ["G3", "B3", "D4"], "Dm": ["D4", "F4", "A4"], "E": ["E3", "G#3", "B3"],
    "Em": ["E3", "G3", "B3"], "D": ["D3", "F#3", "A3"], "B": ["B3", "D#4", "F#4"],
    "Bb": ["Bb3", "D4", "F4"], "Gm": ["G3", "Bb3", "D4"], "A": ["A3", "C#4", "E4"],
}


# --------------------------------------------------------------- building blocks

def envelope(total, gate, a, d, s, r):
    """ADSR envelope. total/gate are sample counts, a/d/r are seconds."""
    t = np.arange(total) / SR
    g = gate / SR
    attack = np.clip(t / max(a, 1e-4), 0.0, 1.0)
    decay = s + (1.0 - s) * np.exp(-np.maximum(t - a, 0.0) / max(d, 1e-4))
    env = np.where(t < a, attack, decay)
    level = env[min(gate, total - 1)] if total else 0.0
    release = level * np.exp(-np.maximum(t - g, 0.0) / max(r / 4.0, 1e-4))
    return np.where(t < g, env, release)


def additive(freq, total, cutoff, odd_only=False, vibrato=0.0, kmax=60):
    """Band-limited saw (or square if odd_only) through a 24 dB low-pass.

    cutoff can be a number or an array (a filter envelope) the length of the note.
    vibrato is the depth in semitones of a 5.5 Hz pitch wobble.
    """
    t = np.arange(total) / SR
    f = freq * 2.0 ** (vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1) / 12.0)
    phase = 2 * np.pi * np.cumsum(f) / SR
    cmax = float(np.max(cutoff))
    top = int(min(kmax, SR / 2.2 / freq, cmax * 3.0 / freq + 1))
    out = np.zeros(total)
    for k in range(1, max(top, 1) + 1, 2 if odd_only else 1):
        weight = (1.0 / k) / (1.0 + (k * freq / cutoff) ** 4)
        out += weight * np.sin(k * phase + rng.uniform(0, 2 * np.pi))
    return out


def fft_filter(x, lo=None, hi=None):
    """Zero-phase high-pass (lo) / low-pass (hi) using the FFT. Circular!"""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    gain = np.ones_like(f)
    if lo:
        gain *= 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4)
    if hi:
        gain *= 1.0 / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(spec * gain, len(x))


def samples(seconds):
    return int(seconds * SR)


# --------------------------------------------------------------- instruments
# Each returns a mono numpy array. `dur` is the held length in seconds.

def pad(m, dur, bright=900.0):
    total = samples(dur + 1.6)
    t = np.arange(total) / SR
    cutoff = bright * (1.0 + 0.35 * np.sin(2 * np.pi * 0.15 * t))
    sig = sum(additive(mtof(m + c / 100.0), total, cutoff) for c in (-9, 0, 9))
    sig += 0.5 * np.sin(2 * np.pi * mtof(m - 12) * t)
    return 0.22 * sig * envelope(total, samples(dur), 0.7, 1.0, 0.8, 1.5)


def pluck(m, dur, bright=3200.0):
    total = samples(dur + 0.3)
    t = np.arange(total) / SR
    cutoff = 250.0 + bright * np.exp(-t / 0.09)
    return 0.5 * additive(mtof(m), total, cutoff) * envelope(total, samples(dur), 0.002, 0.25, 0.0, 0.15)


def bass(m, dur, bright=1400.0):
    total = samples(dur + 0.08)
    t = np.arange(total) / SR
    cutoff = 220.0 + bright * np.exp(-t / 0.07)
    sig = 0.7 * additive(mtof(m), total, cutoff) + 0.6 * np.sin(2 * np.pi * mtof(m) * t)
    return 0.55 * sig * envelope(total, samples(dur * 0.92), 0.003, 0.2, 0.7, 0.05)


def lead(m, dur, square=0.5, bright=2600.0):
    total = samples(dur + 0.3)
    f = mtof(m)
    saw = additive(f, total, bright, vibrato=0.18)
    sq = additive(f, total, bright, odd_only=True, vibrato=0.18)
    return 0.35 * ((1 - square) * saw + square * sq) * envelope(total, samples(dur), 0.01, 0.25, 0.7, 0.2)


def bell(m, dur):
    total = samples(dur + 2.5)
    t = np.arange(total) / SR
    f = mtof(m)
    sig = sum(a * np.exp(-t / dec) * np.sin(2 * np.pi * f * ratio * t)
              for ratio, a, dec in ((1.0, 1.0, 1.4), (2.76, 0.4, 0.5), (5.4, 0.25, 0.2)))
    return 0.25 * sig * np.clip(t / 0.003, 0, 1)


def stab(m, dur):
    total = samples(dur + 0.15)
    t = np.arange(total) / SR
    cutoff = 400.0 + 2600.0 * np.exp(-t / 0.05)
    return 0.3 * additive(mtof(m), total, cutoff) * envelope(total, samples(dur), 0.002, 0.1, 0.2, 0.08)


def kick(level=1.0):
    total = samples(0.45)
    t = np.arange(total) / SR
    f = 45.0 + 110.0 * np.exp(-t / 0.035)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)
    click = fft_filter(rng.standard_normal(total), lo=2000) * np.exp(-t / 0.004) * 0.3
    return level * 0.9 * np.tanh(1.5 * (body + click))


def snare(level=1.0):
    total = samples(0.35)
    t = np.arange(total) / SR
    noise = fft_filter(rng.standard_normal(total), lo=900, hi=7000) * np.exp(-t / 0.09)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05)
    return level * 0.45 * (noise * 0.6 + tone * 0.7)


def hat(level=1.0, open_=False):
    total = samples(0.4 if open_ else 0.08)
    t = np.arange(total) / SR
    noise = fft_filter(rng.standard_normal(total), lo=7000)
    return level * 0.18 * noise * np.exp(-t / (0.12 if open_ else 0.018))


def tom(m, level=1.0):
    total = samples(0.4)
    t = np.arange(total) / SR
    f = mtof(m) * (1.0 + 0.6 * np.exp(-t / 0.03))
    return level * 0.6 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.15)


# --------------------------------------------------------------- the "tracker"

class Song:
    """A multi-bus mix. Positions are in beats; looping songs wrap around."""

    def __init__(self, bpm, bars, loop=True, tail=0.0):
        self.spb = 60.0 / bpm
        self.loop = loop
        self.length = samples(bars * 4 * self.spb + (0 if loop else tail))
        self.buses = {}
        self.kicks = []

    def beat_to_sample(self, beat):
        return int(round(beat * self.spb * SR))

    def add(self, bus, beat, sig, pan=0.0):
        buf = self.buses.setdefault(bus, np.zeros((2, self.length)))
        start = self.beat_to_sample(beat)
        sig = sig[: self.length]
        idx = np.arange(len(sig)) + start
        if self.loop:
            idx %= self.length            # the tail of the last note wraps to the start
        else:
            keep = idx < self.length
            idx, sig = idx[keep], sig[keep]
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        buf[0, idx] += sig * left
        buf[1, idx] += sig * right

    def notes(self, bus, instrument, seq, offset=0.0, pan=0.0, transpose=0, **kw):
        for beat, length, name in seq:
            self.add(bus, offset + beat, instrument(midi(name) + transpose, length * self.spb, **kw), pan)

    def drum(self, kind, beat, level=1.0, pan=0.0):
        if kind == "k":
            self.kicks.append(beat)
            self.add("drums", beat, kick(level), pan)
        elif kind == "s":
            self.add("drums", beat, snare(level), pan)
        elif kind == "h":
            self.add("drums", beat, hat(level), pan + 0.3)
        elif kind == "o":
            self.add("drums", beat, hat(level, True), pan + 0.3)

    def pattern(self, bar, text, step=0.25):
        """Drum pattern string, one character per 16th: k s h o or '.'."""
        for lane in text.split("|"):
            for i, ch in enumerate(lane.strip()):
                if ch != ".":
                    self.drum(ch, bar * 4 + i * step, 1.0 if ch != "h" or i % 2 == 0 else 0.6)

    # ---- effects -------------------------------------------------------------
    def sidechain(self, bus, depth=0.6, release=0.18):
        if bus not in self.buses:
            return
        t = np.arange(self.length)
        duck = np.ones(self.length)
        for b in self.kicks:
            d = (t - self.beat_to_sample(b)) % self.length if self.loop else t - self.beat_to_sample(b)
            mask = (d >= 0) & (d < SR)
            duck[mask] = np.minimum(duck[mask], 1 - depth * np.exp(-d[mask] / (release * SR)))
        self.buses[bus] *= duck

    def delay(self, bus, beats=0.75, feedback=0.4, mix=0.35):
        if bus not in self.buses:
            return
        buf = self.buses[bus]
        d = self.beat_to_sample(beats)
        wet = np.zeros_like(buf)
        echo = buf.copy()
        for i in range(1, 6):
            echo = np.roll(echo, d, axis=1) * feedback
            echo = echo[::-1]                       # swap channels = ping-pong
            wet += echo
        if not self.loop:
            pass  # np.roll still wraps; the tail is long enough for jingles
        self.buses[bus] = buf + mix * wet

    def render(self, gains, sends, reverb_seconds=2.2, drive=1.2):
        dry = np.zeros((2, self.length))
        send = np.zeros((2, self.length))
        for name, buf in self.buses.items():
            dry += buf * gains.get(name, 1.0)
            send += buf * sends.get(name, 0.0)
        # Convolution reverb: decaying stereo noise as the impulse response.
        ir_len = min(samples(reverb_seconds), self.length)
        t = np.arange(ir_len) / SR
        wet = np.zeros_like(send)
        for ch in range(2):
            ir = fft_filter(rng.standard_normal(ir_len), lo=200, hi=5000) * np.exp(-t / (reverb_seconds / 5))
            ir /= np.sqrt(np.sum(ir ** 2))
            n = self.length if self.loop else self.length + ir_len
            wet_ch = np.fft.irfft(np.fft.rfft(send[ch], n) * np.fft.rfft(ir, n), n)
            if self.loop:
                wet[ch] = wet_ch            # circular convolution = seamless loop
            else:
                wet[ch] = wet_ch[: self.length]
        mix = dry + wet * 0.8
        mix = np.tanh(drive * mix / max(np.max(np.abs(mix)), 1e-9) * 1.4)
        return mix / np.max(np.abs(mix)) * 0.89  # about -1 dBFS


def save(path_ogg, stereo, quality=5):
    tmp = path_ogg[:-4] + ".tmp.wav"
    data = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis",
                    "-q:a", str(quality), path_ogg], check=True)
    os.remove(tmp)
    print("  wrote", os.path.relpath(path_ogg, ROOT), "%.1fs" % (stereo.shape[1] / SR))


def chord_notes(name, beat, length, octave_shift=0):
    return [(beat, length, n[:-1] + str(int(n[-1]) + octave_shift)) for n in CHORDS[name]]


def arpeggio(chords, bars_per_chord, step, pattern, octave_shift=1, start_bar=0, end_bar=None):
    """Cycle through chord tones. pattern indexes the triad (3 = root an octave up)."""
    seq = []
    steps_per_bar = int(4 / step)
    for ci, ch in enumerate(chords):
        tones = [midi(n) + 12 * octave_shift for n in CHORDS[ch]]
        tones.append(tones[0] + 12)
        for bar in range(bars_per_chord):
            bar_index = ci * bars_per_chord + bar
            if bar_index < start_bar or (end_bar is not None and bar_index >= end_bar):
                continue
            for s in range(steps_per_bar):
                m = tones[pattern[s % len(pattern)]]
                name = [k for k, v in NOTE.items() if v == m % 12][0] + str(m // 12 - 1)
                seq.append((bar_index * 4 + s * step, step * 0.9, name))
    return seq


# --------------------------------------------------------------- the tracks

def title_theme():
    """'Neon Rain' - A minor, 84 BPM, slow and moody. Drums + melody in the 2nd half."""
    s = Song(84, 16)
    prog = ["Am", "F", "C", "G", "Am", "F", "Dm", "E"]
    for i, ch in enumerate(prog):
        s.notes("pad", pad, chord_notes(ch, i * 8, 8))
        root = CHORDS[ch][0]
        s.notes("bass", bass, [(i * 8, 3.5, root[:-1] + "2"), (i * 8 + 4, 3.5, root[:-1] + "2")], bright=500)
    s.notes("arp", pluck, arpeggio(prog, 2, 0.5, [0, 1, 2, 3, 2, 1, 0, 2]), pan=-0.2, bright=2200)
    for bar in range(8, 16):
        s.pattern(bar, "k.......s.......|h.h.h.h.h.h.h.h.")
    melody = [(0, 2, "E5"), (2, 1, "D5"), (3, 1, "C5"), (4, 3, "D5"),
              (8, 2, "C5"), (10, 1, "A4"), (11, 1, "C5"), (12, 2, "D5"), (14, 2, "E5"),
              (16, 2, "F5"), (18, 1, "E5"), (19, 1, "D5"), (20, 3, "A4"),
              (24, 2, "B4"), (26, 1, "C5"), (27, 1, "B4"), (28, 4, "G#4")]
    s.notes("lead", lead, melody, offset=32, pan=0.15, square=0.3, bright=2000)
    s.notes("bells", bell, [(0, 1, "E6"), (14, 1, "C6"), (30, 1, "B5"), (46, 1, "A5")], pan=0.4)
    s.sidechain("pad", 0.35)
    s.delay("arp", 0.75, 0.45, 0.4)
    s.delay("lead", 0.75, 0.35, 0.3)
    return s.render({"pad": 0.8, "bass": 0.9, "arp": 0.45, "drums": 0.8, "lead": 0.6, "bells": 0.5},
                    {"pad": 0.4, "arp": 0.5, "drums": 0.25, "lead": 0.45, "bells": 0.7}, 3.0)


def street_theme():
    """'Concrete Pulse' - E minor, 112 BPM, driving bass and four-on-the-floor drums."""
    s = Song(112, 16)
    prog = ["Em", "C", "D", "B"] * 4
    octave_jumps = [0, 0, 12, 0, 0, 12, 0, 12]
    for bar, ch in enumerate(prog):
        root = midi(CHORDS[ch][0][:-1] + "2")
        for i, jump in enumerate(octave_jumps):
            s.add("bass", bar * 4 + i * 0.5, bass(root + jump, 0.45 * s.spb))
        s.notes("pad", stab, [(bar * 4 + b, 0.4, n) for b in (0.5, 1.5, 2.5, 3.5)
                              for _, _, n in chord_notes(ch, 0, 1)])
        if bar < 15:
            s.pattern(bar, "k...k...k...k...|....s.......s...|h.h.h.h.h.h.h.ho" if bar % 2
                      else "k...k...k...k...|....s.......s...|h.h.h.h.h.h.h.h.")
        else:
            s.pattern(bar, "k...k...k...k...|....s.......ssss|h.h.h.h.h.h.h.h.")
    s.notes("arp", pluck, arpeggio(prog, 1, 0.25, [0, 1, 2, 3, 2, 1, 2, 3], start_bar=4), pan=-0.25)
    melody = [(0, 1.5, "B4"), (1.5, .5, "G4"), (2, 1, "A4"), (3, 1, "B4"),
              (4, 1.5, "C5"), (5.5, .5, "B4"), (6, 2, "G4"),
              (8, 1.5, "A4"), (9.5, .5, "F#4"), (10, 1, "D5"), (11, .5, "C5"), (11.5, .5, "B4"),
              (12, 1, "F#4"), (13, 1, "B4"), (14, 2, "D#5"),
              (16, 1.5, "E5"), (17.5, .5, "D5"), (18, 1, "B4"), (19, 1, "G4"),
              (20, 1, "E5"), (21, 1, "G5"), (22, 1, "E5"), (23, 1, "C5"),
              (24, 1.5, "D5"), (25.5, .5, "F#5"), (26, 1, "A5"), (27, 1, "F#5"),
              (28, 2, "D#5"), (30, 1, "F#5"), (31, 1, "B4")]
    s.notes("lead", lead, melody, offset=32, pan=0.15, square=0.6)
    s.sidechain("pad", 0.6)
    s.sidechain("arp", 0.4)
    s.delay("arp", 0.75, 0.35, 0.3)
    s.delay("lead", 0.75, 0.3, 0.25)
    return s.render({"pad": 0.55, "bass": 1.0, "arp": 0.35, "drums": 0.9, "lead": 0.55},
                    {"pad": 0.35, "arp": 0.35, "drums": 0.12, "lead": 0.35}, 1.8, drive=1.5)


def boss_theme():
    """'Iron Sirens' - D minor, 140 BPM, 16th-note bass ostinato and heavy drums."""
    s = Song(140, 16)
    prog = ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"] * 2
    riff = [0, 0, 12, 0, 0, 0, 10, 0, 0, 0, 12, 0, 0, 7, 10, 12]
    for bar, ch in enumerate(prog):
        root = midi(CHORDS[ch][0][:-1] + "2")
        for i, step in enumerate(riff):
            s.add("bass", bar * 4 + i * 0.25, bass(root + step, 0.22 * s.spb, bright=2200))
        s.notes("stabs", stab, [(bar * 4 + b, 0.3, n) for b in (0.5, 1.5, 2.5, 3.5)
                                for _, _, n in chord_notes(ch, 0, 1, 1)])
        if bar in (7, 15):
            s.pattern(bar, "k.......k.k.k.k.|....s.......s...|hhhhhhhh........")
            for i, m in enumerate(["A3", "F3", "D3", "A2"]):
                s.add("drums", bar * 4 + 2 + i * 0.5, tom(midi(m)), -0.3 + i * 0.2)
        else:
            s.pattern(bar, "k..k..k.k.......|....s.......s...|hhhhhhhhhhhhhhhh")
    s.notes("arp", pluck, arpeggio(prog, 1, 0.25, [3, 2, 1, 0], octave_shift=2, start_bar=4, end_bar=8),
            pan=-0.3, bright=2600)
    melody = [(0, .5, "D5"), (.5, .5, "F5"), (1, 1, "A5"), (2, .5, "G5"), (2.5, .5, "F5"), (3, 1, "E5"),
              (4, .5, "F5"), (4.5, .5, "E5"), (5, 1, "D5"), (6, 2, "A4"),
              (8, .5, "Bb4"), (8.5, .5, "D5"), (9, 1, "F5"), (10, .5, "D5"), (10.5, .5, "F5"), (11, 1, "Bb5"),
              (12, .5, "C5"), (12.5, .5, "E5"), (13, 1, "G5"), (14, 1, "E5"), (15, 1, "C5"),
              (16, 1, "D6"), (17, .5, "C6"), (17.5, .5, "A5"), (18, 1, "F5"), (19, 1, "D5"),
              (20, .5, "E5"), (20.5, .5, "F5"), (21, .5, "G5"), (21.5, .5, "A5"), (22, 1, "Bb5"), (23, 1, "A5"),
              (24, 1, "G5"), (25, 1, "Bb5"), (26, 1, "D6"), (27, 1, "Bb5"),
              (28, 2, "A5"), (30, .5, "C#5"), (30.5, .5, "E5"), (31, 1, "A5")]
    s.notes("lead", lead, melody, offset=32, pan=0.1, square=0.8, bright=3200)
    s.sidechain("stabs", 0.5)
    s.delay("lead", 0.5, 0.3, 0.2)
    s.delay("arp", 0.75, 0.3, 0.3)
    return s.render({"stabs": 0.5, "bass": 1.0, "arp": 0.35, "drums": 1.0, "lead": 0.55},
                    {"stabs": 0.25, "arp": 0.4, "drums": 0.1, "lead": 0.3}, 1.5, drive=1.8)


def intro_theme():
    """'Static' - a dark drone with a heartbeat and distant bells, for the intro."""
    s = Song(64, 8)
    for bar in range(0, 8, 4):
        s.notes("pad", pad, [(bar * 4, 16, "A2"), (bar * 4, 16, "E3"), (bar * 4, 16, "C4")], bright=500)
    for bar in range(8):
        s.drum("k", bar * 4, 0.7)
        s.drum("k", bar * 4 + 0.4, 0.45)
    s.notes("bells", bell, [(2, 1, "E5"), (9, 1, "C6"), (13, 1, "B5"), (18, 1, "A5"), (25, 1, "E6"), (29, 1, "G5")],
            pan=0.3)
    s.delay("bells", 1.5, 0.5, 0.5)
    return s.render({"pad": 0.9, "drums": 0.7, "bells": 0.45}, {"pad": 0.5, "drums": 0.3, "bells": 0.8}, 4.0)


def victory_jingle():
    s = Song(120, 3, loop=False, tail=2.5)
    s.notes("lead", pluck, [(i * 0.25, 0.25, n) for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"])],
            bright=4000)
    s.notes("pad", pad, chord_notes("C", 2, 8) + [(2, 8, "C3")], bright=1400)
    s.notes("lead2", lead, [(2, 1, "G5"), (3, 1, "A5"), (4, 1, "B5"), (5, 4, "C6")], square=0.4)
    for b in (2, 5):
        s.drum("k", b)
        s.drum("o", b)
    s.add("drums", 2, snare(1.2))
    return s.render({"lead": 0.5, "pad": 0.9, "lead2": 0.7, "drums": 0.8},
                    {"lead": 0.5, "pad": 0.4, "lead2": 0.5, "drums": 0.3}, 2.5)


def game_over_sting():
    s = Song(70, 3, loop=False, tail=3.0)
    s.notes("lead", lead, [(0, 1, "A4"), (1, 1, "G4"), (2, 1, "F4"), (3, 4, "E4")], square=0.2, bright=1500)
    s.notes("pad", pad, chord_notes("Am", 0, 3) + chord_notes("E", 3, 6) + [(0, 8, "A2")], bright=600)
    s.drum("k", 0, 1.0)
    s.drum("k", 3, 1.0)
    return s.render({"lead": 0.6, "pad": 0.9, "drums": 0.8}, {"lead": 0.5, "pad": 0.5, "drums": 0.4}, 3.0)


def rain_ambience(seconds=12.0):
    """Seamless rain loop: filtered noise (circular FFT filter) + random droplets."""
    n = samples(seconds)
    out = np.zeros((2, n))
    for ch in range(2):
        hiss = fft_filter(rng.standard_normal(n), lo=500, hi=6000) * 0.35
        rumble = fft_filter(rng.standard_normal(n), lo=60, hi=400) * 0.25
        out[ch] = hiss + rumble
        for _ in range(int(seconds * 35)):
            start = rng.integers(0, n)
            length = samples(0.03)
            t = np.arange(length) / SR
            drop = np.sin(2 * np.pi * rng.uniform(1800, 4200) * t) * np.exp(-t / 0.006) * rng.uniform(0.05, 0.25)
            idx = (np.arange(length) + start) % n
            out[ch, idx] += drop
    return out / np.max(np.abs(out)) * 0.7


def main():
    os.makedirs(MUSIC_DIR, exist_ok=True)
    os.makedirs(SFX_DIR, exist_ok=True)
    save(os.path.join(MUSIC_DIR, "title.ogg"), title_theme())
    save(os.path.join(MUSIC_DIR, "street.ogg"), street_theme())
    save(os.path.join(MUSIC_DIR, "boss.ogg"), boss_theme())
    save(os.path.join(MUSIC_DIR, "intro.ogg"), intro_theme())
    save(os.path.join(MUSIC_DIR, "victory.ogg"), victory_jingle())
    save(os.path.join(MUSIC_DIR, "game_over.ogg"), game_over_sting())
    save(os.path.join(SFX_DIR, "rain_loop.ogg"), rain_ambience(), quality=3)


if __name__ == "__main__":
    main()
