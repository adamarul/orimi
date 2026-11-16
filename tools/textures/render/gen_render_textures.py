"""Generate the render workstream's tileable greyscale textures into assets/textures/render/.

Every texture is periodic (built by filtering white noise in the frequency domain, or by
drawing with wrap-around), so it tiles without seams. Deterministic: fixed seeds.

  paper_tooth.png  512  pebbled height field for the paper emboss (cell ~8 texels)
  paper_stain.png  512  large soft blotches with faint tide lines (paper staining, pigment blotches)
  paper_fibres.png 1024 sparse short hairs: R = dark fibres, G = pale fibres
  ink_noise.png    256  RGBA: R mid value noise, G low value noise, B cellular blots, A white noise
  dry_streak.png   256  noise stretched along X (dry-brush streaks run along U)
"""
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/render"


def band_noise(size, lo, hi, rng, aniso=(1.0, 1.0)):
    """Periodic noise whose energy sits between wavelengths size/hi and size/lo texels."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * size * aniso[1]
    fx = np.fft.fftfreq(size)[None, :] * size * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    mask = np.exp(-((np.log2(np.maximum(f, 1e-6)) - np.log2((lo * hi) ** 0.5)) ** 2) / (2 * (np.log2(hi / lo) / 2.5) ** 2))
    mask[0, 0] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * mask))
    return normalise(out)


def normalise(a):
    a = a - a.min()
    return a / max(a.max(), 1e-9)


def cellular(size, cells, rng):
    """Periodic Worley F1 distance, 0 at cell centres, about 1 at borders."""
    pts = rng.random((cells, cells, 2))
    yy, xx = np.mgrid[0:size, 0:size] / size * cells
    best = np.full((size, size), 9.0)
    cy, cx = np.floor(yy).astype(int), np.floor(xx).astype(int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ny, nx = cy + dy, cx + dx
            p = pts[ny % cells, nx % cells]
            py, px = ny + p[..., 0], nx + p[..., 1]
            d = np.sqrt((yy - py) ** 2 + (xx - px) ** 2)
            best = np.minimum(best, d)
    return np.clip(best / 0.75, 0.0, 1.0)


def save_l(a, name):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name))


def save_rgba(chans, name):
    arr = np.stack([(np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8) for c in chans], axis=-1)
    Image.fromarray(arr).save(os.path.join(OUT, name))


def paper_tooth(rng):
    size = 512
    cells = cellular(size, 64, rng)
    pebble = 1.0 - cells ** 1.5
    fine = band_noise(size, 40, 120, rng)
    broad = band_noise(size, 6, 20, rng)
    h = pebble * 0.6 + fine * 0.25 + broad * 0.15
    save_l(normalise(h), "paper_tooth.png")


def paper_stain(rng):
    size = 512
    low = band_noise(size, 1.5, 4, rng)
    mid = band_noise(size, 4, 10, rng)
    s = normalise(low * 0.75 + mid * 0.25)
    blot = np.clip((s - 0.45) / 0.4, 0, 1) ** 1.3
    tide = np.exp(-((s - 0.55) / 0.018) ** 2) * 0.35
    save_l(normalise(blot + tide), "paper_stain.png")


def paper_fibres(rng):
    size = 1024
    layers = []
    for count in (150, 110):
        img = Image.new("L", (size * 3, size * 3), 0)
        d = ImageDraw.Draw(img)
        for _ in range(count):
            x, y = rng.random(2) * size + size
            ang = rng.random() * np.pi
            length = 12 + rng.random() * 34
            bend = (rng.random() - 0.5) * 0.08
            pts = []
            for i in range(9):
                t = i / 8 * length
                a = ang + bend * i
                x2, y2 = x + np.cos(a) * t, y + np.sin(a) * t
                pts.append((x2, y2))
            val = int(150 + rng.random() * 105)
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    d.line([(px + ox, py + oy) for px, py in pts], fill=val, width=2)
        full = np.asarray(img, dtype=np.float32) / 255.0
        acc = np.zeros((size, size), np.float32)
        for by in range(3):
            for bx in range(3):
                acc = np.maximum(acc, full[by * size:(by + 1) * size, bx * size:(bx + 1) * size])
        layers.append(acc)
    zero = np.zeros((size, size))
    save_rgba([layers[0], layers[1], zero, np.ones((size, size))], "paper_fibres.png")


def ink_noise(rng):
    size = 256
    r = band_noise(size, 6, 24, rng)
    g = band_noise(size, 2, 6, rng)
    b = 1.0 - cellular(size, 10, rng)
    b = normalise(b * 0.7 + band_noise(size, 8, 32, rng) * 0.3)
    a = rng.random((size, size))
    save_rgba([r, g, b, a], "ink_noise.png")


def dry_streak(rng):
    size = 256
    s = band_noise(size, 4, 64, rng, aniso=(6.0, 0.6))
    fine = band_noise(size, 16, 96, rng, aniso=(8.0, 0.5))
    save_l(normalise(s * 0.7 + fine * 0.3), "dry_streak.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    paper_tooth(np.random.default_rng(11))
    paper_stain(np.random.default_rng(23))
    paper_fibres(np.random.default_rng(37))
    ink_noise(np.random.default_rng(41))
    dry_streak(np.random.default_rng(53))
    write_provenance()
    print("RENDER_TEXTURES written to", OUT)


def write_provenance():
    """provenance.json beside the textures, in the format of tools/qa/provenance.py."""
    outputs = []
    for name in sorted(os.listdir(OUT)):
        if not name.endswith(".png"):
            continue
        with open(os.path.join(OUT, name), "rb") as fh:
            digest = hashlib.sha256(fh.read()).hexdigest()
        outputs.append({"path": "assets/textures/render/" + name, "sha256": digest})
    manifest = {
        "generator": "tools/textures/render/gen_render_textures.py",
        "command": "tools/textures/render/gen.sh",
        "outputs": outputs,
    }
    with open(os.path.join(OUT, "provenance.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")


if __name__ == "__main__":
    main()
