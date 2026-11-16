"""Loudness profile of the game's music tracks, to pick the trailer's music bed.

Decodes each track with ffmpeg and prints its length and an RMS level (dBFS) per second as a small
text plot, so a section that rises can be found without listening. Used once by hand and kept so
the choice in docs/TRAILER.md can be checked again:
    python -I tools/trailer/music_profile.py <ffmpeg.exe> audio/music/*.ogg
"""
import subprocess
import sys

import numpy as np


def decode(ffmpeg, path):
    raw = subprocess.run([ffmpeg, "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", "48000", "-"],
                         check=True, stdout=subprocess.PIPE).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)


def main():
    ffmpeg = sys.argv[1]
    for path in sys.argv[2:]:
        x = decode(ffmpeg, path).mean(axis=1)
        sec = 48000
        n = len(x) // sec
        levels = []
        for i in range(n):
            seg = x[i * sec:(i + 1) * sec]
            levels.append(20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-9))
        peak = 20 * np.log10(np.max(np.abs(x)) + 1e-9)
        print("== %s  %.1f s  peak %.1f dBFS" % (path, len(x) / sec, peak))
        for i, db in enumerate(levels):
            bar = "#" * max(0, int((db + 50) / 1.5))
            print("%3d %6.1f %s" % (i, db, bar))


if __name__ == "__main__":
    main()
