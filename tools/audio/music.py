"""The four music pieces, composed here as note data and rendered with synthesised plucked
strings, a flute-like voice, a bowed pad, soft bells and soft percussion. Stereo OGG Vorbis.

    python tools/audio/music.py <out_dir> [<report.json>]

All melodies and harmony are original. vale_cursed and vale_restored share one theme: the
cursed version is the same tune drained (slower, darker mode, notes dropping out, muted
strings, a heartbeat drum); the restored version is the tune in full colour. title states the
theme gently; finale builds it up and resolves. The three looping pieces are rendered with
their ringing tails (notes and baked reverb) wrapped back onto the start, so the loop point
is continuous.
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from synth import (RATE, apply_reverb, bell, drum, env_exp, flute, highpass, levels, lowpass, midi_hz, noise,  # noqa: E402
                   normalize, pad, pluck, reverb_ir, sweep_bandpass, wood, write_ogg)

D4, E4, Fs4, A4, B4, D5, E5 = 62, 64, 66, 69, 71, 74, 76

# The theme: (beat, length in beats, MIDI note). 16 bars of 4/4 in D major pentatonic.
THEME = [
    (0, 1.5, A4), (1.5, 0.5, B4), (2, 1, D5), (3, 1, B4), (4, 1.5, A4), (5.5, 0.5, Fs4), (6, 2, E4),
    (8, 1, Fs4), (9, 1, A4), (10, 1.5, B4), (11.5, 0.5, A4), (12, 1, Fs4), (13, 0.5, E4), (13.5, 0.5, D4), (14, 2, E4),
    (16, 1.5, A4), (17.5, 0.5, B4), (18, 1, D5), (19, 1, E5), (20, 1.5, D5), (21.5, 0.5, B4), (22, 2, A4),
    (24, 1, B4), (25, 1, A4), (26, 1, Fs4), (27, 1, E4), (28, 3, D4),
    (32, 2, B4), (34, 1, A4), (35, 1, Fs4), (36, 1.5, A4), (37.5, 0.5, B4), (38, 2, D5),
    (40, 1, E5), (41, 1, D5), (42, 1, B4), (43, 1, A4), (44, 3, B4), (47, 1, Fs4),
    (48, 1.5, A4), (49.5, 0.5, B4), (50, 1, D5), (51, 1, B4), (52, 1, A4), (53, 1, Fs4), (54, 2, E4),
    (56, 1, Fs4), (57, 1, E4), (58, 1, D4), (59, 1, E4), (60, 4, D4),
]
# One chord per bar: (bass root, chord tones as MIDI).
CHORDS_BRIGHT = [
    (50, [62, 66, 69]), (47, [59, 62, 66]), (43, [55, 59, 62]), (45, [57, 61, 64]),
    (50, [62, 66, 69]), (43, [55, 59, 62]), (40, [55, 59, 64]), (50, [62, 66, 69]),
    (47, [59, 62, 66]), (43, [55, 59, 62]), (50, [62, 66, 69]), (45, [57, 61, 64]),
    (47, [59, 62, 66]), (43, [55, 59, 62]), (45, [57, 61, 64]), (50, [62, 66, 69]),
]
# The same theme drained: F# -> F, B -> Bb, E -> Eb, C# -> C (D Phrygian colour).
DRAIN = {66: 65, 71: 70, 64: 63, 76: 75, 61: 60, 59: 58, 47: 46, 54: 53, 40: 39, 52: 51, 73: 72, 78: 77, 83: 82}
CHORDS_DARK = [
    (50, [62, 65, 69]), (46, [58, 62, 65]), (43, [55, 58, 62]), (45, [57, 62, 64]),
    (50, [62, 65, 69]), (43, [55, 58, 62]), (39, [55, 58, 63]), (50, [62, 65, 69]),
    (46, [58, 62, 65]), (43, [55, 58, 62]), (50, [62, 65, 69]), (45, [57, 62, 64]),
    (46, [58, 62, 65]), (43, [55, 58, 62]), (39, [55, 58, 63]), (50, [57, 62, 69]),
]


def drain(m):
    pc_shift = DRAIN.get(m)
    if pc_shift is not None:
        return pc_shift
    for octave in (-24, -12, 12, 24):
        if m + octave in DRAIN:
            return DRAIN[m + octave] - octave
    return m


class Score:
    def __init__(self, tempo, beats, seed):
        self.tempo, self.beats = tempo, beats
        self.spb = 60.0 / tempo
        self.events = []
        self.rng = np.random.default_rng(seed)

    def add(self, beat, length, kind, note=None, gain=1.0, pan=0.0, **kw):
        self.events.append((beat, length, kind, note, gain, pan, kw))

    def render(self, loop, tail=5.0, reverb=(2.6, 0.22)):
        length = int(self.beats * self.spb * RATE)
        out = np.zeros((length + int(tail * RATE) + int(reverb[0] * RATE), 2))
        rng = self.rng
        for beat, dur, kind, note, gain, pan, kw in self.events:
            sec = dur * self.spb
            if kind == "pluck":
                x = pluck(midi_hz(note), sec + kw.get("ring", 1.6), rng, kw.get("bright", 0.5), kw.get("decay", 0.996))
            elif kind == "flute":
                x = flute(midi_hz(note), sec + 0.15, rng, breath=kw.get("breath", 0.18), vibrato=kw.get("vib", 0.006))
            elif kind == "pad":
                x = pad([midi_hz(m) for m in note], sec + 1.2, rng, attack=kw.get("attack", 1.0), release=1.4, bright=kw.get("bright", 0.35))
            elif kind == "bell":
                x = bell(midi_hz(note), kw.get("ring", 2.2))
            elif kind == "drum":
                x = drum(midi_hz(note), 0.9, rng, 0.5)
            elif kind == "wood":
                x = wood(midi_hz(note), 0.15, rng)
            elif kind == "wind":
                n = int((sec + 0.5) * RATE)
                x = sweep_bandpass(noise(n, rng, "pink"), midi_hz(note), midi_hz(kw.get("to", note)), q=kw.get("q", 2.5), steps=24)
                x = x * np.sin(np.pi * np.arange(n) / n) ** 2
                x = x / (np.abs(x).max() + 1e-9)
            elif kind == "shaker":
                n = int(0.12 * RATE)
                x = highpass(noise(n, rng), 5000) * env_exp(n, 0.03, 0.01)
            else:
                raise ValueError(kind)
            x = x * gain * (0.92 + 0.16 * rng.random())
            ramp = min(len(x), int(0.003 * RATE))
            x[:ramp] *= np.linspace(0.0, 1.0, ramp)
            start = int(beat * self.spb * RATE + rng.normal() * 0.004 * RATE * (kind != "drum"))
            start = max(0, start)
            seg = out[start:start + len(x)]
            seg[:, 0] += x[: len(seg)] * np.cos((pan + 1) * np.pi / 4)
            seg[:, 1] += x[: len(seg)] * np.sin((pan + 1) * np.pi / 4)
        wet = apply_reverb(out[: length + int(tail * RATE)], reverb_ir(reverb[0], rng), reverb[1])
        if not loop:
            body = wet[: length + int(tail * RATE)]
            fade_n = int(tail * 0.6 * RATE)
            body[-fade_n:] *= np.linspace(1, 0, fade_n)[:, None] ** 2
            return body
        body = wet[:length].copy()
        rest = wet[length:]
        while len(rest):
            k = min(len(rest), length)
            body[:k] += rest[:k]
            rest = rest[k:]
        return body


def arp(score, chords, pattern, octave_shift=0, gain=0.22, bright=0.5, decay=0.996, pan=-0.3, every=0.5, bars=None):
    bars = range(len(chords)) if bars is None else bars
    for bar in bars:
        root, tones = chords[bar % len(chords)]
        notes = [root + 12] + tones + [tones[0] + 12, tones[1] + 12]
        for i, idx in enumerate(pattern):
            if idx is None:
                continue
            score.add(bar * 4 + i * every, every, "pluck", notes[idx] + octave_shift, gain, pan, bright=bright, decay=decay, ring=1.2)


def pads(score, chords, gain=0.16, bright=0.35, low=True, bars=None):
    bars = range(len(chords)) if bars is None else bars
    for bar in bars:
        root, tones = chords[bar % len(chords)]
        notes = ([root] if low else []) + tones
        score.add(bar * 4, 4.2, "pad", notes, gain, 0.0, attack=0.9, bright=bright)


# ----------------------------------------------------------------------------- pieces
def vale_restored():
    s = Score(72, 64, 3)
    for beat, length, m in THEME:
        s.add(beat, length, "flute", m + 12, 0.42, 0.2, breath=0.14)
    arp(s, CHORDS_BRIGHT, [0, 2, 3, 4, 1, 3, 4, 5], gain=0.2, bright=0.6)
    pads(s, CHORDS_BRIGHT, 0.12, 0.45)
    for bar in range(16):
        s.add(bar * 4, 1, "drum", 38, 0.35, 0.0)
        if bar % 2:
            s.add(bar * 4 + 2.5, 1, "drum", 38, 0.18, 0.0)
        for k in range(8):
            s.add(bar * 4 + k * 0.5, 0.5, "shaker", None, 0.05 if k % 2 else 0.09, 0.45)
        s.add(bar * 4 + 3, 0.5, "wood", 79, 0.07, -0.5)
    for beat, length, m in THEME:
        if length >= 2:
            s.add(beat, length, "bell", m + 24, 0.08, 0.6 * (1 if beat % 8 else -1), ring=2.0)
    return s.render(loop=True)


def vale_cursed():
    s = Score(58, 64, 5)
    for i, (beat, length, m) in enumerate(THEME):
        if i % 4 == 3:
            continue  # notes drop out of the drained tune
        s.add(beat, length * 1.1, "flute", drain(m), 0.38, 0.15, breath=0.32, vib=0.012)
    arp(s, CHORDS_DARK, [0, None, 2, None, 1, None, 3, None], octave_shift=-12, gain=0.2, bright=0.25, decay=0.991)
    pads(s, CHORDS_DARK, 0.15, 0.2)
    for bar in range(16):
        s.add(bar * 4, 4, "pad", [38, 45], 0.1, 0.0)
        if bar % 2 == 0:
            s.add(bar * 4, 1, "drum", 33, 0.42, 0.0)
            s.add(bar * 4 + 0.75, 1, "drum", 33, 0.26, 0.0)
        if bar % 4 == 3:
            s.add(bar * 4 + 2, 1, "bell", 75, 0.06, -0.6, ring=3.0)
    return s.render(loop=True, reverb=(3.4, 0.3))


def title():
    s = Score(66, 64, 7)
    for beat, length, m in THEME[:27]:
        s.add(beat, length, "pluck", m, 0.42, -0.15, bright=0.55, decay=0.997, ring=2.2)
    for beat, length, m in THEME[27:]:
        s.add(beat, length, "flute", m + 12, 0.36, 0.2, breath=0.16)
    pads(s, CHORDS_BRIGHT, 0.13, 0.3)
    arp(s, CHORDS_BRIGHT, [0, None, 3, None, 4, None, 2, None], gain=0.12, bright=0.4, pan=0.4, bars=range(8, 16))
    for bar in range(0, 16, 2):
        s.add(bar * 4, 1, "bell", 86 if bar % 4 else 81, 0.07, -0.5 + bar * 0.06, ring=3.0)
    return s.render(loop=True, reverb=(3.0, 0.28))


def finale():
    s = Score(76, 72, 11)
    # 1. a still opening: pads and bells with the first phrase on plucked strings
    pads(s, CHORDS_BRIGHT, 0.14, 0.3, bars=range(0, 4))
    for beat, length, m in THEME[:7]:
        s.add(beat, length, "pluck", m, 0.4, -0.2, bright=0.55, ring=2.0)
    for k in range(4):
        s.add(k * 4 + 2, 1, "bell", [86, 81, 83, 78][k], 0.08, 0.5, ring=3.0)
    # 2. the whole theme in full colour, an octave of flute over strings, drums driving
    off = 16
    for beat, length, m in THEME:
        if beat >= 52:
            break
        s.add(off + beat, length, "flute", m + 12, 0.42, 0.15, breath=0.12)
        s.add(off + beat, length, "pluck", m, 0.18, -0.35, bright=0.7, ring=1.4)
    arp(s, [CHORDS_BRIGHT[(b - 4) % 16] for b in range(18)], [0, 2, 3, 4, 1, 3, 4, 5], gain=0.18, bright=0.65, bars=range(4, 17))
    pads(s, [CHORDS_BRIGHT[(b - 4) % 16] for b in range(18)], 0.13, 0.5, bars=range(4, 17))
    for bar in range(4, 17):
        s.add(bar * 4, 1, "drum", 38, 0.4, 0.0)
        s.add(bar * 4 + 2, 1, "drum", 43, 0.22, 0.0)
        if bar >= 8:
            s.add(bar * 4 + 1.5, 1, "drum", 38, 0.18, 0.0)
        for k in range(8):
            s.add(bar * 4 + k * 0.5, 0.5, "shaker", None, 0.05 if k % 2 else 0.08, 0.4)
    # 3. resolution: the cadence slows into a held D major with bells
    end = 68
    for i, (b, m) in enumerate([(end - 4, 69), (end - 3, 71), (end - 2, 66), (end - 1, 64)]):
        s.add(b, 1, "flute", m + 12, 0.4, 0.15)
    s.add(end, 4, "flute", 74, 0.45, 0.15)
    s.add(end, 4, "pad", [38, 50, 57, 62, 66, 69, 74], 0.2, 0.0, attack=0.4, bright=0.55)
    s.add(end, 1, "drum", 33, 0.5, 0.0)
    for k, m in enumerate([74, 78, 81, 86, 90]):
        s.add(end + k * 0.25, 1, "bell", m, 0.12, -0.6 + k * 0.3, ring=4.0)
        s.add(end + k * 0.25, 1, "pluck", m - 12, 0.2, -0.3, bright=0.6, ring=4.0)
    return s.render(loop=False, tail=6.0, reverb=(3.2, 0.26))


QUALITY = 0.75  # libsndfile compression level for Vorbis: about 80 kbit/s stereo

PIECES = {"title": (title, True), "vale_cursed": (vale_cursed, True), "vale_restored": (vale_restored, True), "finale": (finale, False)}


def loop_jump(x):
    """How big the end-to-start step is, relative to the 99.9th percentile of ordinary sample steps."""
    steps = np.abs(np.diff(x, axis=0))
    typical = np.percentile(steps, 99.9, axis=0) + 1e-9
    jump = np.abs(x[0] - x[-1])
    return float(np.max(jump / typical))


def write_piece(x, path, loop):
    """Normalise a rendered piece to -1 dBFS, write it as OGG at QUALITY, read it back and return
    its measured entry (levels, size, loop-seam check). Level music scripts use this too."""
    path = Path(path)
    x = normalize(x, -1.0)
    write_ogg(path, x, QUALITY)
    back, _ = sf.read(str(path))
    peak, rms = levels(back)
    entry = {"file": path.as_posix(), "seconds": round(len(back) / RATE, 2), "loop": loop, "peak_db": round(peak, 1),
             "rms_db": round(rms, 1), "bytes": path.stat().st_size, "clipped": bool(np.abs(back).max() >= 0.999),
             "samples_written": len(x), "samples_decoded": len(back)}
    if loop:
        entry["loop_step_ratio_rendered"] = round(loop_jump(x), 2)
        entry["loop_step_ratio_decoded"] = round(loop_jump(back), 2)
    print("MUSIC %-14s %6.2fs loop=%-5s peak %5.1f dBFS rms %5.1f dBFS %7d bytes %s" % (
        path.stem, len(back) / RATE, loop, peak, rms, path.stat().st_size,
        ("loop step x%.2f of a normal step" % entry["loop_step_ratio_decoded"]) if loop else ""))
    return entry, back


def main(out_dir, report_path=None):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    for name, (fn, loop) in PIECES.items():
        entry, back = write_piece(fn(), out / ("%s.ogg" % name), loop)
        entry["file"] = "audio/music/%s.ogg" % name
        report[name] = entry
        if report_path:
            np.save(str(Path(report_path).parent / ("%s.npy" % name)), back.astype(np.float32))
    if report_path:
        Path(report_path).write_text(json.dumps(report, indent=1))
    return report


if __name__ == "__main__":
    main(*sys.argv[1:3])
