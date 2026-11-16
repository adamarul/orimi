"""Waveform, spectrogram and loop-boundary plots of the rendered audio, for people who cannot
listen: the lead can see the shape of each piece and that each loop point is continuous.

    python tools/audio/plots.py <audio_dir> <out_dir>

Writes <out_dir>/music_<id>.png for every track and <out_dir>/sfx_overview.png.
"""
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw, ImageFont
from scipy import signal

BG = (239, 230, 210)
INK = (27, 26, 28)
GRID = (205, 196, 176)
RED = (179, 32, 42)
BLUE = (78, 111, 122)


def font():
    return ImageFont.load_default()


def draw_wave(d, box, x, color=INK, label=None):
    x0, y0, x1, y1 = box
    d.rectangle(box, outline=GRID)
    mid = (y0 + y1) / 2
    d.line([(x0, mid), (x1, mid)], fill=GRID)
    for db in (-6, -12, -24):
        a = 10 ** (db / 20)
        for s in (1, -1):
            y = mid - s * a * (y1 - y0) / 2
            d.line([(x0, y), (x1, y)], fill=(225, 216, 196))
    w = x1 - x0
    mono = x if x.ndim == 1 else x
    cols = np.array_split(np.arange(len(mono)), w)
    for i, idx in enumerate(cols):
        if len(idx) == 0:
            continue
        seg = mono[idx]
        lo, hi = float(seg.min()), float(seg.max())
        d.line([(x0 + i, mid - hi * (y1 - y0) / 2), (x0 + i, mid - lo * (y1 - y0) / 2)], fill=color)
    if label:
        d.text((x0 + 4, y0 + 2), label, fill=INK, font=font())


def draw_spec(img, box, x, rate):
    x0, y0, x1, y1 = box
    mono = x.mean(axis=1) if x.ndim == 2 else x
    f, t, s = signal.spectrogram(mono, rate, nperseg=2048, noverlap=1024)
    s = 10 * np.log10(s + 1e-12)
    fmax = 8000
    keep = f <= fmax
    f, s = f[keep], s[keep]
    # log frequency axis from 40 Hz
    h, w = y1 - y0, x1 - x0
    rows = np.geomspace(40, fmax, h)[::-1]
    ri = np.clip(np.searchsorted(f, rows), 0, len(f) - 1)
    ci = np.clip((np.arange(w) / w * s.shape[1]).astype(int), 0, s.shape[1] - 1)
    m = s[ri][:, ci]
    top = np.percentile(m, 99.5)
    m = np.clip((m - (top - 70)) / 70, 0, 1)
    rgb = np.stack([BG[c] * (1 - m) + INK[c] * m for c in range(3)], axis=-1).astype(np.uint8)
    img.paste(Image.fromarray(rgb), (x0, y0))
    d = ImageDraw.Draw(img)
    d.rectangle(box, outline=GRID)
    for hz in (100, 500, 1000, 4000):
        y = y0 + int(h * (1 - np.log(hz / 40) / np.log(fmax / 40)))
        d.line([(x0, y), (x0 + 8, y)], fill=RED)
        d.text((x0 + 10, y - 6), "%d Hz" % hz, fill=RED, font=font())


def music_plot(path, out, name, info):
    x, rate = sf.read(str(path))
    W, H = 1600, 760
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    head = "%s  %.1f s  %s  peak %.1f dBFS  rms %.1f dBFS  %d KB" % (
        name, len(x) / rate, "loop" if info.get("loop") else "resolves", info["peak_db"], info["rms_db"], info["bytes"] // 1024)
    d.text((20, 10), head, fill=INK, font=font())
    d.text((20, 26), "waveform (both channels, guide lines at -6, -12, -24 dBFS)", fill=INK, font=font())
    draw_wave(d, (20, 44, W - 20, 244), x[:, 0], INK)
    draw_wave(d, (20, 44, W - 20, 244), x[:, 1], BLUE)
    d.text((20, 252), "spectrogram, 40 Hz to 8 kHz (log), 70 dB range", fill=INK, font=font())
    draw_spec(img, (20, 270, W - 20, 520), x, rate)
    if info.get("loop"):
        n = int(0.04 * rate)
        joined = np.concatenate([x[-n:], x[:n]])
        d.text((20, 532), "loop boundary: last 40 ms then first 40 ms (red line = loop point). end-to-start step = %.2f x the 99.9th-percentile sample step" % info["loop_step_ratio_decoded"], fill=INK, font=font())
        bx = (20, 550, W - 20, 740)
        draw_wave(d, bx, joined[:, 0], INK)
        draw_wave(d, bx, joined[:, 1], BLUE)
        xm = 20 + (W - 40) // 2
        d.line([(xm, 550), (xm, 740)], fill=RED, width=2)
    else:
        n = int(0.5 * rate)
        d.text((20, 532), "ending: last 6 s (the finale resolves and rings out, it does not loop)", fill=INK, font=font())
        draw_wave(d, (20, 550, W - 20, 740), x[-6 * rate:, 0], INK)
    img.save(out)


def sfx_plot(sfx_dir, out, report):
    names = list(report)
    cols, cw, ch = 4, 390, 120
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGB", (cols * cw + 20, rows * ch + 40), BG)
    d = ImageDraw.Draw(img)
    d.text((10, 10), "sound effects: waveform of each file (full length), peak and RMS in dBFS", fill=INK, font=font())
    for i, name in enumerate(names):
        x, rate = sf.read(str(Path(sfx_dir) / ("%s.ogg" % name)))
        r, c = divmod(i, cols)
        box = (10 + c * cw, 34 + r * ch, 10 + c * cw + cw - 12, 34 + r * ch + ch - 8)
        info = report[name]
        draw_wave(d, box, x, INK, "%s  %.2fs  pk %.1f  rms %.1f" % (name, info["seconds"], info["peak_db"], info["rms_db"]))
    img.save(out)


def main(audio_dir, out_dir, report_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    music = json.loads((Path(report_dir) / "music.json").read_text())
    for name, info in music.items():
        music_plot(Path(audio_dir) / "music" / ("%s.ogg" % name), out / ("music_%s.png" % name), name, info)
        print("PLOT", (out / ("music_%s.png" % name)).as_posix())
    sfx = json.loads((Path(report_dir) / "sfx.json").read_text())
    sfx_plot(Path(audio_dir) / "sfx", out / "sfx_overview.png", sfx)
    print("PLOT", (out / "sfx_overview.png").as_posix())


if __name__ == "__main__":
    main(*sys.argv[1:4])
