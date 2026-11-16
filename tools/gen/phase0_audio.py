"""Phase 0 probe audio: an original two-partial wooden-chime tone, pre-rendered to 16-bit mono WAV.

    python tools/gen/phase0_audio.py <out.wav>
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100


def main(out):
    t = np.arange(int(RATE * 1.6)) / RATE
    rng = np.random.default_rng(7)
    tone = (
        0.55 * np.sin(2 * np.pi * 523.25 * t) * np.exp(-t * 2.8)
        + 0.30 * np.sin(2 * np.pi * 784.0 * t + 0.4) * np.exp(-t * 4.0)
        + 0.12 * np.sin(2 * np.pi * 1318.5 * t) * np.exp(-t * 9.0)
    )
    knock = rng.normal(0.0, 1.0, t.size) * np.exp(-t * 60.0) * 0.25
    signal = tone + knock
    attack = np.minimum(1.0, t / 0.004)
    signal *= attack
    signal /= np.max(np.abs(signal)) / 0.8
    pcm = (signal * 32767).astype("<i2")
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    print("AUDIO", out, "%.2fs" % (t.size / RATE))


if __name__ == "__main__":
    main(sys.argv[1])
