"""Generates every vfx/environment texture into assets/textures/vfx/.

Owner: vfx. Run through tools/textures/vfx/gen_vfx_textures.sh (uses the project venv).
Everything is painted procedurally as brush marks: strokes are built from bristles that run
dry, so edges are ragged and streaky. Channels carry data, not colour; the shaders colour them
from Palette values. Each file's channel layout is listed in docs/SHADERS_VFX.md.
"""
import hashlib
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SS = 2  # supersampling factor for every painted cell
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/textures/vfx"
REPO_DIR = "assets/textures/vfx"  # where OUT sits in the repository, for the provenance manifest
WRITTEN = []


# ----------------------------------------------------------------------------- noise
def periodic_noise(h, w, scale, rng, aniso=(1.0, 1.0)):
    """Tileable smooth noise in 0..1 from FFT-filtered white noise. scale ~ feature size in px;
    aniso (y, x) stretches features: (1, 8) makes streaks 8 times longer along x."""
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * aniso[0]
    fx = np.fft.fftfreq(w)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    filt = np.exp(-(f * scale) ** 2 * 4.0)
    filt[0, 0] = 0.0
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    n -= n.min()
    n /= max(n.max(), 1e-6)
    return n


def noise1d(n, period, rng):
    """Smooth 1D noise of n samples in 0..1 with features about period samples long."""
    knots = max(3, int(n / max(period, 1.0)) + 3)
    k = rng.random(knots)
    x = np.linspace(0, knots - 3, n)
    i = np.floor(x).astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    return k[i] * (1 - f) + k[i + 1] * f


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------------------- painter
class Painter:
    """Paints into named channels at SS x resolution; finish() returns float arrays 0..1."""

    def __init__(self, w, h, channels=("r", "g", "b")):
        self.w, self.h = w, h
        self.img = {c: Image.new("L", (w * SS, h * SS), 0) for c in channels}
        self.draw = {c: ImageDraw.Draw(self.img[c]) for c in channels}

    def finish(self):
        out = {}
        for c, im in self.img.items():
            out[c] = np.asarray(im.resize((self.w, self.h), Image.BOX), dtype=np.float32) / 255.0
        return out

    def disc(self, ch, x, y, r, value=255):
        r = max(r, 0.45) * SS
        x *= SS
        y *= SS
        self.draw[ch].ellipse((x - r, y - r, x + r, y + r), fill=int(value))

    def poly(self, ch, pts, value=255):
        self.draw[ch].polygon([(float(x) * SS, float(y) * SS) for x, y in pts], fill=int(value))

    def stroke(self, pts, widths, rng, ch="r", param_ch=None, param=(0.0, 1.0), value=255,
               bristles=22, dry=0.5, ragged=0.35, solid_start=0.08, wobble=0.0, value_fn=None,
               streak=0.12):
        """A dry-brush stroke along pts (Nx2, px) with per-point widths (px).

        Bristles each carry their own ink; they break into streaks as the stroke runs dry
        (more towards the end, scaled by dry), and the outer bristles fray first (ragged).
        param_ch receives the arc-length parameter (param[0]..param[1]) as 0..255.
        """
        pts = np.asarray(pts, dtype=np.float64)
        widths = np.asarray(widths, dtype=np.float64)
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        L = np.concatenate([[0.0], np.cumsum(seg)])
        if L[-1] <= 0:
            return
        n = max(4, int(L[-1] / 0.6))
        s = np.linspace(0, L[-1], n)
        px = np.interp(s, L, pts[:, 0])
        py = np.interp(s, L, pts[:, 1])
        wd = np.interp(s, L, widths)
        t = s / L[-1]
        tx = np.gradient(px)
        ty = np.gradient(py)
        tl = np.maximum(np.hypot(tx, ty), 1e-6)
        nx, ny = -ty / tl, tx / tl
        if wobble > 0:
            wob = (noise1d(n, 40, rng) - 0.5) * 2 * wobble
            px = px + nx * wob * wd
            py = py + ny * wob * wd
        B = bristles
        offs = np.linspace(-1.0, 1.0, B) + rng.uniform(-0.5, 0.5, B) / B
        weak = rng.uniform(0.0, 0.35, B) + ragged * np.abs(offs) ** 3
        rad = rng.uniform(0.8, 1.35, B)
        period = max(4.0, n / 30.0)
        dry_profile = dry * smoothstep(solid_start, 1.0, t) ** 1.3
        for i in range(B):
            nz = noise1d(n, period * rng.uniform(0.6, 1.8), rng)
            thresh = dry_profile * 1.25 + weak[i] * (0.25 + dry_profile) - 0.12 + streak * rng.uniform(0.3, 1.6)
            present = nz > thresh
            for k in np.nonzero(present)[0]:
                w = wd[k]
                if w <= 0.05:
                    continue
                cx = px[k] + nx[k] * offs[i] * w * 0.5
                cy = py[k] + ny[k] * offs[i] * w * 0.5
                r = rad[i] * w / B * 1.25 + 0.25
                v = value if value_fn is None else value_fn(t[k], offs[i])
                self.disc(ch, cx, cy, r, v)
                if param_ch is not None:
                    self.disc(param_ch, cx, cy, r, 1 + 254 * (param[0] + (param[1] - param[0]) * t[k]))


# ----------------------------------------------------------------------------- paths
def arc_path(cx, cy, r, a0, a1, n=64, rx=1.0, ry=1.0):
    a = np.linspace(a0, a1, n)
    return np.stack([cx + np.cos(a) * r * rx, cy + np.sin(a) * r * ry], 1)


def curl_path(x0, y0, length, r0, turns, direction, n=200, droop=0.0):
    """A lead-in that bends into a spiral which tightens: the wind/cloud curl."""
    lead = length - r0 * 1.2
    pts = []
    m = n // 3
    for i in range(m):
        u = i / m
        pts.append((x0 + lead * u, y0 + direction * droop * math.sin(u * math.pi) * r0))
    cx = x0 + lead
    cy = y0 - direction * r0
    total = turns * 2 * math.pi
    for i in range(n - m):
        u = i / (n - m - 1)
        a = math.pi / 2 - u * total
        r = r0 * (1.0 - 0.85 * u) ** 1.1
        pts.append((cx + math.cos(a) * r, cy + direction * math.sin(a) * r))
    return np.array(pts)


def taper(t, head=0.06, tail=1.0, power=1.0):
    return np.minimum(1.0, t / head) * (1.0 - t) ** power if tail else np.minimum(1.0, t / head)


def lens(t, p=0.7):
    return np.sin(np.pi * np.clip(t, 0, 1)) ** p


# ----------------------------------------------------------------------------- atlas utils
def atlas(cells, cols, rows, cw, ch):
    chans = list(cells[0].keys())
    out = {c: np.zeros((rows * ch, cols * cw), np.float32) for c in chans}
    for idx, cell in enumerate(cells):
        cx, cy = idx % cols, idx // cols
        for c in chans:
            out[c][cy * ch:(cy + 1) * ch, cx * cw:(cx + 1) * cw] = cell[c]
    return out


def save(name, ch):
    h, w = ch["r"].shape
    arr = np.zeros((h, w, 3), np.uint8)
    for i, c in enumerate("rgb"):
        if c in ch:
            arr[..., i] = np.clip(ch[c] * 255.0 + 0.5, 0, 255).astype(np.uint8)
    path = os.path.join(OUT, name)
    Image.fromarray(arr).save(path, optimize=True)
    WRITTEN.append(name)
    print("wrote", path, w, "x", h)


def write_provenance():
    """provenance.json beside the textures, in the format of tools/qa/provenance.py."""
    outputs = []
    for name in sorted(WRITTEN):
        with open(os.path.join(OUT, name), "rb") as f:
            outputs.append({"path": REPO_DIR + "/" + name, "sha256": hashlib.sha256(f.read()).hexdigest()})
    manifest = {
        "generator": "tools/textures/vfx/gen_vfx_textures.py",
        "command": "tools/textures/vfx/gen_vfx_textures.sh",
        "outputs": outputs,
    }
    with open(os.path.join(OUT, "provenance.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    print("wrote", os.path.join(OUT, "provenance.json"), len(outputs), "outputs")


# ----------------------------------------------------------------------------- ink splats
def splat_cell(rng, size=256, kind="splat"):
    """R = ink mask, G = soak order (low values soak away first), B = 0."""
    P = Painter(size, size)
    c = size / 2
    if kind == "splat":
        R = size * rng.uniform(0.17, 0.22)
        a = np.linspace(0, 2 * np.pi, 220, endpoint=False)
        r = np.ones_like(a)
        for k in range(2, 14):
            r += rng.uniform(0, 0.22 / k ** 0.7) * np.cos(k * a + rng.uniform(0, 6.28))
        for _ in range(rng.integers(4, 8)):
            ac = rng.uniform(0, 6.28)
            d = np.angle(np.exp(1j * (a - ac)))
            r += rng.uniform(0.3, 0.9) * np.exp(-(d / rng.uniform(0.05, 0.12)) ** 2)
        P.poly("r", np.stack([c + np.cos(a) * r * R, c + np.sin(a) * r * R], 1))
        for _ in range(rng.integers(6, 12)):
            ac = rng.uniform(0, 6.28)
            dist = R * rng.uniform(1.25, 1.95)
            dr = size * rng.uniform(0.012, 0.03)
            x, y = c + math.cos(ac) * dist, c + math.sin(ac) * dist
            P.disc("r", x, y, dr)
            tail = np.stack([np.linspace(x, c + math.cos(ac) * dist * 0.75, 12),
                             np.linspace(y, c + math.sin(ac) * dist * 0.75, 12)], 1)
            P.stroke(tail, np.linspace(dr * 1.6, 0.0, 12), rng, bristles=6, dry=0.3)
        for _ in range(rng.integers(2, 5)):
            ac = rng.uniform(0, 6.28)
            p0 = R * 0.9
            p1 = R * rng.uniform(1.6, 2.2)
            line = np.stack([c + np.cos(ac) * np.linspace(p0, p1, 30), c + np.sin(ac) * np.linspace(p0, p1, 30)], 1)
            P.stroke(line, size * 0.035 * (1 - np.linspace(0, 1, 30)) ** 0.8, rng, bristles=10, dry=0.7)
    elif kind == "streak":
        # a thrown streak: heavy blob end, tail that drags dry
        y = c + rng.uniform(-8, 8)
        xs = np.linspace(size * 0.12, size * 0.9, 60)
        ys = y + np.sin(np.linspace(0, rng.uniform(1, 3), 60)) * size * 0.03
        w = size * rng.uniform(0.09, 0.13) * (1 - np.linspace(0, 1, 60)) ** 0.9 * np.minimum(1, np.linspace(0, 1, 60) / 0.04)
        P.stroke(np.stack([xs, ys], 1), w, rng, bristles=18, dry=0.8)
        P.disc("r", xs[2], ys[2], size * 0.06)
    elif kind == "drop":
        R = size * rng.uniform(0.18, 0.24)
        a = np.linspace(0, 2 * np.pi, 120, endpoint=False)
        r = 1 + sum(rng.uniform(0, 0.06) * np.cos(k * a + rng.uniform(0, 6)) for k in range(2, 6))
        P.poly("r", np.stack([c + np.cos(a) * r * R, c + np.sin(a) * r * R], 1))
        tail = np.stack([np.linspace(c, c - size * 0.4, 20), np.full(20, c) + rng.uniform(-3, 3)], 1)
        P.stroke(tail, np.linspace(R * 1.7, 0, 20), rng, bristles=10, dry=0.4)
    elif kind == "shard":
        # thorn fragment: a hooked tapered ink thorn
        xs = np.linspace(size * 0.15, size * 0.85, 40)
        bend = rng.uniform(0.05, 0.15) * size
        ys = c + bend * np.sin(np.linspace(0, np.pi * 0.8, 40))
        w = size * 0.1 * lens(np.linspace(0, 1, 40), 0.5) * (1 - np.linspace(0, 1, 40) * 0.6)
        P.stroke(np.stack([xs, ys], 1), w, rng, bristles=14, dry=0.35)
        for _ in range(2):
            u = rng.uniform(0.3, 0.7)
            bx, by = np.interp(u, np.linspace(0, 1, 40), xs), np.interp(u, np.linspace(0, 1, 40), ys)
            spike = np.stack([np.linspace(bx, bx + rng.uniform(10, 25), 10), np.linspace(by, by - rng.uniform(20, 40), 10)], 1)
            P.stroke(spike, np.linspace(9, 0, 10), rng, bristles=6, dry=0.2)
    out = P.finish()
    m = out["r"]
    # soak order: interior and big masses last, rims, droplets and dry streaks first
    from scipy.ndimage import gaussian_filter
    body = gaussian_filter(m, size * 0.05)
    nz = periodic_noise(size, size, size * 0.06, rng)
    soak = np.clip(body * 1.4, 0, 1) * 0.65 + nz * 0.35
    out["g"] = np.where(m > 0.02, np.clip(soak, 0.02, 1.0), 0.0)
    out["b"] = np.zeros_like(m)
    return out


# ----------------------------------------------------------------------------- petals
def petal_cell(rng, size=128):
    """R = petal mask, G = white edge highlight, B = second-pink choice (0 or 1 per cell)."""
    P = Painter(size, size)
    c = size / 2
    n = 5
    R = size * 0.34
    angs = np.sort(rng.uniform(0, 2 * np.pi, n)) if rng.random() < 0.3 else np.linspace(0, 2 * np.pi, n, endpoint=False) + rng.uniform(-0.25, 0.25, n)
    rads = R * rng.uniform(0.7, 1.05, n)
    rads[0] *= 1.25  # one longer point: a petal tip
    pts = []
    for i in range(n):
        a0, a1 = angs[i], angs[(i + 1) % n] + (2 * np.pi if i == n - 1 else 0)
        p0 = np.array([c + math.cos(a0) * rads[i], c + math.sin(a0) * rads[i]])
        p1 = np.array([c + math.cos(a1) * rads[(i + 1) % n], c + math.sin(a1) * rads[(i + 1) % n]])
        mid = (p0 + p1) / 2
        out = mid - c
        bulge = rng.uniform(0.05, 0.18)
        ctrl = mid + out * bulge
        for u in np.linspace(0, 1, 8, endpoint=False):
            q = (1 - u) ** 2 * p0 + 2 * (1 - u) * u * ctrl + u * u * p1
            pts.append(q)
    P.poly("r", pts)
    o = P.finish()
    from scipy.ndimage import gaussian_filter, shift
    m = o["r"]
    inner = shift(m, (size * 0.07, size * 0.07), order=1)
    edge = np.clip(m - inner, 0, 1)
    edge = gaussian_filter(edge, 0.8)
    o["g"] = np.clip(edge * 1.6, 0, 1) * (m > 0.1)
    o["b"] = np.full_like(m, float(rng.random() < 0.5)) * (m > 0.02)
    return o


# ----------------------------------------------------------------------------- flowers
def flower_cell(rng, kind, size=256):
    """Upright flower card, stem at the bottom centre.
    R = blossom mask, G = stem and leaf mask, B = blossom centre (gold) mask."""
    P = Painter(size, size)
    bx = size / 2 + rng.uniform(-10, 10)
    top = size * rng.uniform(0.22, 0.32)
    stem_x = np.array([size / 2, size / 2 + rng.uniform(-8, 8), bx])
    stem = np.stack([np.interp(np.linspace(0, 2, 30), [0, 1, 2], stem_x), np.linspace(size * 0.98, top + 10, 30)], 1)
    P.stroke(stem, np.linspace(size * 0.035, size * 0.018, 30), rng, ch="g", bristles=8, dry=0.25)
    for side in (-1, 1):
        if rng.random() < 0.8:
            y0 = size * rng.uniform(0.62, 0.85)
            leaf = np.stack([np.linspace(size / 2, size / 2 + side * size * rng.uniform(0.18, 0.28), 20),
                             y0 - np.sin(np.linspace(0, 1.4, 20)) * size * 0.12], 1)
            P.stroke(leaf, size * 0.06 * lens(np.linspace(0, 1, 20), 0.6), rng, ch="g", bristles=12, dry=0.4)
    if kind == "blossom":
        r = size * rng.uniform(0.15, 0.2)
        for i in range(5):
            a = i * 2 * np.pi / 5 + rng.uniform(-0.2, 0.2) - np.pi / 2
            t = np.linspace(0, 1, 20)
            pts = np.stack([bx + np.cos(a) * r * t, top + np.sin(a) * r * t], 1)
            P.stroke(pts, size * 0.12 * lens(t * 0.9 + 0.1, 0.5), rng, ch="r", bristles=16, dry=0.35)
        P.disc("b", bx, top, size * 0.04)
    elif kind == "bell":
        for i in range(3):
            ox = bx + (i - 1) * size * 0.13
            oy = top + abs(i - 1) * size * 0.08
            t = np.linspace(0, 1, 16)
            pts = np.stack([np.full(16, ox) + rng.uniform(-2, 2), oy + t * size * 0.14], 1)
            P.stroke(pts, size * 0.11 * (0.4 + 0.6 * t) * (1 - t * 0.2), rng, ch="r", bristles=14, dry=0.3)
            P.disc("b", ox, oy + size * 0.15, size * 0.015)
    elif kind == "daisy":
        r = size * rng.uniform(0.14, 0.18)
        for i in range(9):
            a = i * 2 * np.pi / 9 + rng.uniform(-0.15, 0.15)
            t = np.linspace(0.2, 1, 12)
            pts = np.stack([bx + np.cos(a) * r * t, top + np.sin(a) * r * t * 0.8], 1)
            P.stroke(pts, size * 0.05 * lens(t, 0.4), rng, ch="r", bristles=8, dry=0.3)
        P.disc("b", bx, top, size * 0.05)
    else:  # buds: a sprig of three dabs
        for i in range(3):
            ox = bx + rng.uniform(-30, 30)
            oy = top + rng.uniform(-10, 30)
            t = np.linspace(0, 1, 10)
            pts = np.stack([ox + t * rng.uniform(-6, 6), oy + t * 18], 1)
            P.stroke(pts, size * 0.08 * lens(t, 0.5), rng, ch="r", bristles=10, dry=0.2)
            sprig = np.stack([np.linspace(bx, ox, 8), np.linspace(top + 40, oy + 12, 8)], 1)
            P.stroke(sprig, np.full(8, 3.0), rng, ch="g", bristles=4, dry=0.1)
    o = P.finish()
    o["g"] = np.clip(o["g"] - o["r"] - o["b"], 0, 1)
    o["r"] = np.clip(o["r"] - o["b"], 0, 1)
    return o


# ----------------------------------------------------------------------------- foliage
def foliage_cell(rng, kind, size=256):
    """Upright card, rooted at the bottom centre.
    R = coverage, G = tone (0 dark .. 1 light, per stroke), B = ink accent strokes."""
    P = Painter(size, size)
    base = np.array([size / 2, size * 0.99])

    def leaf_stroke(p0, p1, w, tone, dry=0.45, bend=0.0, ink=False, profile="lens"):
        t = np.linspace(0, 1, 28)
        d = p1 - p0
        nrm = np.array([-d[1], d[0]]) / (np.linalg.norm(d) + 1e-6)
        pts = p0[None, :] + d[None, :] * t[:, None] + nrm[None, :] * (np.sin(t * np.pi) * bend)[:, None]
        if profile == "lens":
            wid = w * lens(t, 0.6)
        else:  # heavy at the root, tapering to a point
            wid = w * (1 - t) ** 0.8 * np.minimum(1, t / 0.08 + 0.3)
        P.stroke(pts, wid, rng, ch="r", bristles=14, dry=dry)
        P.stroke(pts, wid * 0.98, rng, ch="g", bristles=14, dry=dry, value=int(40 + 215 * tone))
        if ink:
            P.stroke(pts + nrm[None, :] * wid[:, None] * 0.35, wid * 0.35, rng, ch="b", bristles=8, dry=0.65)

    if kind == "reeds":
        for i in range(rng.integers(7, 11)):
            ang = rng.uniform(-0.28, 0.28)
            h = size * rng.uniform(0.6, 0.95)
            p0 = base + [rng.uniform(-14, 14), 0]
            p1 = p0 + [math.sin(ang) * h, -math.cos(ang) * h]
            leaf_stroke(p0, p1, size * rng.uniform(0.035, 0.055), rng.uniform(0.2, 1), dry=0.55,
                        bend=rng.uniform(-15, 15), ink=rng.random() < 0.3, profile="taper")
            if rng.random() < 0.35:
                hd = p0 + (p1 - p0) * 0.8
                tp = p0 + (p1 - p0) * 0.93
                head = np.stack([np.linspace(hd[0], tp[0], 10), np.linspace(hd[1], tp[1], 10)], 1)
                hw = size * 0.022 * lens(np.linspace(0, 1, 10), 0.5) + 0.5
                P.stroke(head, hw, rng, ch="b", bristles=8, dry=0.3)
                P.stroke(head, hw, rng, ch="r", bristles=8, dry=0.3)
    elif kind == "grass":
        for i in range(rng.integers(10, 16)):
            ang = rng.uniform(-1.1, 1.1)
            h = size * rng.uniform(0.3, 0.55) * (1 - abs(ang) * 0.3)
            p0 = base + [rng.uniform(-20, 20), 0]
            p1 = p0 + [math.sin(ang) * h, -math.cos(ang) * h]
            leaf_stroke(p0, p1, size * rng.uniform(0.03, 0.05), rng.uniform(0.15, 1), dry=0.5,
                        bend=rng.uniform(-12, 12) * np.sign(ang), ink=rng.random() < 0.2, profile="taper")
    elif kind in ("bush", "tree"):
        # fans of single leaf strokes, each fan radiating from its own root; the strokes on the
        # underside of each fan get an ink accent (one-sided weight)
        if kind == "bush":
            fans = [(size * rng.uniform(0.3, 0.42), size * 0.9, 0.28), (size * rng.uniform(0.58, 0.7), size * 0.9, 0.28),
                    (size * 0.5, size * 0.78, 0.36)]
        else:
            fans = [(size * 0.5, size * 0.8, 0.44), (size * 0.3, size * 0.7, 0.3), (size * 0.7, size * 0.68, 0.3)]
        for fx, fy, reach in fans:
            root = np.array([fx, fy])
            k = rng.integers(6, 10)
            centre_a = -np.pi / 2 + (fx - size / 2) / size * 1.2
            for j in range(k):
                a = centre_a + (j / (k - 1) - 0.5) * rng.uniform(2.0, 2.6) + rng.uniform(-0.08, 0.08)
                L = size * reach * rng.uniform(0.7, 1.0)
                tip = root + [math.cos(a) * L, math.sin(a) * L]
                start = root + [math.cos(a) * L * 0.12, math.sin(a) * L * 0.12]
                underside = math.sin(a) > -0.45
                tone = np.clip(0.3 + 0.7 * (-math.sin(a)) * rng.uniform(0.7, 1.1), 0.05, 1)
                leaf_stroke(start, tip, size * rng.uniform(0.07, 0.1), tone, dry=0.5,
                            bend=rng.uniform(-10, 10), ink=underside and rng.random() < 0.7)
    o = P.finish()
    o["g"] = np.where(o["r"] > 0.02, np.maximum(o["g"], 0.1), 0.0)
    return o


# ----------------------------------------------------------------------------- strokes
def curl_cell(rng, w=512, h=256, heavy=True):
    """A wind curl: heavy at the start, thinning as it spirals.
    R = mask, G = arc parameter (1/255 start .. 1 end), B = 0."""
    P = Painter(w, h)
    direction = 1 if rng.random() < 0.5 else -1
    r0 = h * rng.uniform(0.2, 0.3)
    turns = rng.uniform(0.9, 1.6)
    length = w * rng.uniform(0.72, 0.84)
    pts = curl_path(w * 0.06, h * 0.5 + direction * r0 * 0.6, length, r0, turns, direction, droop=rng.uniform(-0.5, 0.5))
    t = np.linspace(0, 1, len(pts))
    wmax = h * (0.12 if heavy else 0.07)
    wid = wmax * np.minimum(1, t / 0.05) * (1 - t) ** 1.1 + 1.0
    P.stroke(pts, wid, rng, ch="r", param_ch="g", bristles=18, dry=0.75, wobble=0.08)
    o = P.finish()
    o["b"] = np.zeros_like(o["r"])
    return o


def ripple_cell(rng, w=256, h=128):
    """A calligraphic ripple arc: tapered both ends, heavy in the middle, sometimes hooked.
    R = mask, G = arc parameter."""
    P = Painter(w, h)
    r = w * rng.uniform(0.32, 0.45)
    sweep = rng.uniform(0.5, 0.9)
    ry = rng.uniform(0.25, 0.45)
    pts = arc_path(w / 2, h * 0.5 + r * ry * 0.8, r, -np.pi / 2 - sweep, -np.pi / 2 + sweep, 60, 1.0, ry)
    if rng.random() < 0.5:
        end = pts[-1]
        hook = arc_path(end[0] - 6, end[1] + 6, 8, -np.pi * 0.25, np.pi * 0.6, 12)
        pts = np.concatenate([pts, hook[1:]])
    t = np.linspace(0, 1, len(pts))
    P.stroke(pts, h * rng.uniform(0.07, 0.11) * lens(t, 0.8) + 0.5, rng, ch="r", param_ch="g", bristles=12, dry=0.5)
    o = P.finish()
    o["b"] = np.zeros_like(o["r"])
    return o


def ribbon_texture(rng, w=512, h=128):
    """Dry-brush ribbon, U along the stroke (0 head .. 1 tail), V across.
    R = bristle ink load (threshold it to erode), G = darker streak lines, B = noise."""
    v = np.linspace(0, 1, h)[:, None]
    u = np.linspace(0, 1, w)[None, :]
    rows = np.zeros((h, w), np.float32)
    nb = 48
    centres = np.sort(rng.uniform(0, 1, nb))
    load = rng.uniform(0.55, 1.0, nb)
    for i in range(nb):
        bw = rng.uniform(0.012, 0.03)
        band = np.exp(-((v - centres[i]) / bw) ** 2)
        along = noise1d(w, w / rng.uniform(6, 20), rng)[None, :]
        dryness = u ** 1.4 * rng.uniform(0.6, 1.2)
        rows = np.maximum(rows, band * np.clip(load[i] * (0.55 + 0.45 * along) - dryness * 0.5, 0, 1))
    edge = smoothstep(0.0, 0.12, v) * smoothstep(1.0, 0.88, v)
    r = np.clip(rows * (0.6 + 0.4 * edge), 0, 1)
    streak = np.zeros((h, w), np.float32)
    for i in range(10):
        c = rng.uniform(0.1, 0.9)
        band = np.exp(-((v - c) / rng.uniform(0.006, 0.014)) ** 2)
        along = smoothstep(0.35, 0.7, noise1d(w, w / 8, rng))[None, :]
        streak = np.maximum(streak, band * along)
    return {"r": r, "g": np.clip(streak, 0, 1), "b": periodic_noise(h, w, 18, rng)}


def spark_cell(rng, kind, size=128):
    """R = solid core mask, G = soft halo, B = 0."""
    P = Painter(size, size)
    c = size / 2
    if kind == "star":
        for a in (0, np.pi / 2, np.pi, 3 * np.pi / 2):
            L = size * (0.42 if a in (0, np.pi) else 0.34)
            t = np.linspace(0, 1, 20)
            pts = np.stack([c + np.cos(a) * L * t, c + np.sin(a) * L * t], 1)
            P.stroke(pts, size * 0.1 * (1 - t) ** 1.5 + 0.6, rng, ch="r", bristles=8, dry=0.1)
    elif kind == "ticks":
        for i in range(7):
            a = i * 2 * np.pi / 7 + rng.uniform(-0.25, 0.25)
            t = np.linspace(0, 1, 14)
            r0, r1 = size * rng.uniform(0.14, 0.2), size * rng.uniform(0.36, 0.46)
            d = r0 + (r1 - r0) * t
            pts = np.stack([c + np.cos(a) * d, c + np.sin(a) * d], 1)
            P.stroke(pts, size * 0.06 * (1 - t) ** 0.9 + 0.4, rng, ch="r", bristles=8, dry=0.4)
    else:  # ring flash: a broken brushed circle
        pts = arc_path(c, c, size * 0.32, 0, np.pi * 1.7, 80)
        t = np.linspace(0, 1, 80)
        P.stroke(pts, size * 0.07 * lens(t, 0.5) + 0.5, rng, ch="r", bristles=12, dry=0.6)
    o = P.finish()
    yy, xx = np.mgrid[0:size, 0:size]
    d = np.hypot(xx - c + 0.5, yy - c + 0.5) / (size * 0.5)
    o["g"] = np.clip(1 - d, 0, 1) ** 2.2
    o["b"] = np.zeros_like(o["r"])
    return o


def soot_cell(rng, size=256):
    """A clump of soot: scumbled dry-brush dabs around a soft core.
    R = coverage, G = tone (0 black .. 1 pale grey), B = soak order."""
    P = Painter(size, size)
    c = np.array([size / 2, size / 2])
    for i in range(rng.integers(18, 28)):
        a = rng.uniform(0, 2 * np.pi)
        d = size * rng.uniform(0.0, 0.26)
        p0 = c + [math.cos(a) * d, math.sin(a) * d]
        ang = rng.uniform(0, 2 * np.pi)
        L = size * rng.uniform(0.12, 0.3)
        t = np.linspace(0, 1, 18)
        bend = rng.uniform(-0.6, 0.6)
        pts = np.stack([p0[0] + np.cos(ang + bend * t) * L * t, p0[1] + np.sin(ang + bend * t) * L * t], 1)
        wid = size * rng.uniform(0.05, 0.11) * lens(t, 0.5)
        tone = rng.uniform(0.0, 1.0)
        P.stroke(pts, wid, rng, ch="r", bristles=14, dry=0.7)
        P.stroke(pts, wid, rng, ch="g", bristles=14, dry=0.7, value=int(30 + 225 * tone))
    o = P.finish()
    from scipy.ndimage import gaussian_filter
    body = gaussian_filter(o["r"], size * 0.06)
    nz = periodic_noise(size, size, size * 0.05, rng)
    o["b"] = np.where(o["r"] > 0.02, np.clip(body * 1.3 * 0.6 + nz * 0.4, 0.02, 1), 0)
    o["g"] = np.where(o["r"] > 0.02, np.maximum(o["g"], 0.05), 0.0)
    return o


def torn_edge(n, step, rng):
    """Inward offsets (px) for a torn-paper edge sampled every step px: a slow meander, fibrous
    jags and a few deeper bites."""
    i = np.arange(n)
    off = (noise1d(n, 60 / step, rng) - 0.5) * 5.0
    off += (noise1d(n, 7 / step, rng) - 0.5) * 3.5 + rng.uniform(-1.0, 1.0, n)
    for _ in range(rng.integers(2, 5)):
        c = rng.uniform(0, n)
        off += rng.uniform(3.0, 7.0) * np.exp(-((i - c) * step / rng.uniform(2.0, 5.0)) ** 2)
    return off


def wash_band(P, rng, x0, x1, yc, th, step=1.5):
    """A long flat wash laid left to right: blunt where the brush landed, tapering to a point at
    x1, flatter underneath, with torn-paper edges. Returns (x, bottom y) along the band."""
    n = int((x1 - x0) / step) + 2
    t = np.linspace(0, 1, n)
    x = x0 + (x1 - x0) * t
    prof = smoothstep(0.0, 0.03, t) ** 0.35 * (1.0 - smoothstep(0.4, 1.0, t)) ** 0.8
    top = yc - th * 0.55 * prof * (0.9 + 0.2 * noise1d(n, 120 / step, rng)) + torn_edge(n, step, rng) * prof ** 0.3
    bot = yc + th * 0.45 * prof - torn_edge(n, step, rng) * 0.5 * prof ** 0.3
    top = np.minimum(top, yc)
    bot = np.maximum(bot, yc)
    P.poly("r", list(zip(x, top)) + list(zip(x[::-1], bot[::-1])))
    return x, bot


def cloud_cell(rng, w=512, h=256):
    """A cloud drawn as long horizontal wash bands with torn-paper edges, under one ink stroke
    that runs along the main band and out past its point as a single tapering dry-brush tail.
    No curls. R = fill mask, G = ink line mask, B = 0."""
    P = Painter(w, h)
    th = h * rng.uniform(0.15, 0.18)
    yc = h * rng.uniform(0.56, 0.62)
    x0 = w * rng.uniform(0.04, 0.08)
    L = w * rng.uniform(0.62, 0.7)
    x, bot = wash_band(P, rng, x0, x0 + L, yc, th)
    a = x0 + L * rng.uniform(0.15, 0.3)
    wash_band(P, rng, a, a + L * rng.uniform(0.5, 0.6), yc - th * rng.uniform(0.95, 1.1), th * rng.uniform(0.65, 0.8))
    if rng.random() < 0.6:
        a = x0 + L * rng.uniform(0.4, 0.55)
        wash_band(P, rng, a, a + L * rng.uniform(0.25, 0.35), yc + th * rng.uniform(0.75, 0.95), th * rng.uniform(0.3, 0.4))
    # the ink: along the underside, then out past the point as the tail, which lifts or sags a little
    k = np.searchsorted(x, x0 + L * 0.05)
    tail = w * rng.uniform(0.2, 0.25)
    u = np.linspace(0, 1, 40)[1:]
    tail_pts = np.stack([x[-1] + tail * u, bot[-1] + rng.uniform(-1.0, 1.0) * h * 0.04 * u ** 2], 1)
    pts = np.concatenate([np.stack([x[k:], bot[k:] - th * 0.06], 1)[::3], tail_pts])
    t = np.linspace(0, 1, len(pts))
    wid = h * 0.034 * np.minimum(1, t / 0.04) * (1 - t ** 2.2) + 0.5
    P.stroke(pts, wid, rng, ch="g", bristles=16, dry=0.75, ragged=0.5, solid_start=0.35, wobble=0.05, streak=0.15)
    o = P.finish()
    # the wash runs dry towards the tail: thin horizontal gaps where the paper shows through
    streaks = periodic_noise(h, w, 4, rng, aniso=(1.0, 14.0))
    dryness = smoothstep(x0 + L * 0.35, x0 + L, np.arange(w, dtype=np.float32))[None, :]
    o["r"] *= streaks < 0.72 - 0.2 * dryness
    if rng.random() < 0.5:
        o = {c: v[:, ::-1].copy() for c, v in o.items()}
    o["b"] = np.zeros_like(o["r"])
    return o


# ----------------------------------------------------------------------------- tiling fields
def water_cells(rng, size=512):
    """Tileable. R and G = two networks of thin bright cell lines, B = soft wash noise."""
    out = {}
    from scipy.ndimage import gaussian_filter
    for ch, count in (("r", 26), ("g", 40)):
        pts = rng.uniform(0, size, (count, 2))
        yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
        d1 = np.full((size, size), 1e9, np.float32)
        d2 = np.full((size, size), 1e9, np.float32)
        for p in pts:
            for ox in (-size, 0, size):
                for oy in (-size, 0, size):
                    dx = xx - (p[0] + ox)
                    dy = yy - (p[1] + oy)
                    d = np.sqrt(dx * dx + dy * dy)
                    nd2 = np.where(d < d1, d1, np.minimum(d2, d))
                    d1 = np.minimum(d1, d)
                    d2 = nd2
        edge = d2 - d1
        wn = periodic_noise(size, size, 30, rng)
        width = 1.0 + 2.2 * wn
        line = np.clip(1.0 - edge / width, 0, 1)
        breaks = smoothstep(0.3, 0.55, periodic_noise(size, size, 20, rng))
        out[ch] = gaussian_filter(line * breaks, 0.6)
        out[ch] /= max(out[ch].max(), 1e-6)
    out["b"] = periodic_noise(size, size, 90, rng)
    return out


def noise_texture(rng, size=256):
    """Tileable. R = broad blotches, G = mid detail, B = streaks stretched along U."""
    return {
        "r": periodic_noise(size, size, 50, rng),
        "g": periodic_noise(size, size, 10, rng),
        "b": periodic_noise(size, size, 14, rng, aniso=(1.0, 8.0)),
    }


def mist_band(rng, w=1024, h=256):
    """Tileable in U. R = density with ragged top and bottom, G = streaky detail, B = 0."""
    from scipy.ndimage import gaussian_filter
    v = np.linspace(0, 1, h)[:, None]
    top = 0.25 + 0.15 * periodic_noise(1, w, 60, rng)[0][None, :] + 0.08 * periodic_noise(1, w, 12, rng)[0][None, :]
    bot = 0.78 + 0.1 * periodic_noise(1, w, 80, rng)[0][None, :]
    body = smoothstep(top - 0.12, top + 0.12, v) * smoothstep(1.0, bot - 0.05, v)
    streak = periodic_noise(h, w, 6, rng, aniso=(1.0, 10.0))
    blot = periodic_noise(h, w, 70, rng)
    d = np.clip(body * (0.55 + 0.45 * blot) * (0.75 + 0.35 * streak), 0, 1)
    return {"r": gaussian_filter(d, 1.0), "g": streak, "b": np.zeros_like(d)}


# ----------------------------------------------------------------------------- main
def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(20261114)

    cells = [splat_cell(rng, 256, "splat") for _ in range(4)]
    cells += [splat_cell(rng, 256, "streak") for _ in range(2)]
    cells += [splat_cell(rng, 256, "drop"), splat_cell(rng, 256, "shard")]
    save("ink_splats.png", atlas(cells, 4, 2, 256, 256))

    save("petals.png", atlas([petal_cell(rng) for _ in range(8)], 4, 2, 128, 128))

    kinds = ["blossom", "bell", "daisy", "buds"]
    save("flowers.png", atlas([flower_cell(rng, k) for k in kinds + kinds], 4, 2, 256, 256))

    fk = ["reeds", "grass", "bush", "tree"]
    save("foliage.png", atlas([foliage_cell(rng, k) for k in fk + fk], 4, 2, 256, 256))

    save("curls.png", atlas([curl_cell(rng, heavy=i < 4) for i in range(8)], 2, 4, 512, 256))
    save("ripples.png", atlas([ripple_cell(rng) for _ in range(16)], 4, 4, 256, 128))
    save("ribbon.png", ribbon_texture(rng))
    save("sparks.png", atlas([spark_cell(rng, k) for k in ("star", "ticks", "ring", "star")], 4, 1, 128, 128))
    save("soot.png", atlas([soot_cell(rng) for _ in range(8)], 4, 2, 256, 256))
    cloud_rng = np.random.default_rng(20261116)
    save("clouds.png", atlas([cloud_cell(cloud_rng) for _ in range(4)], 2, 2, 512, 256))
    rng.bit_generator.advance(7955)  # the draws the retired cloud painter took: later files stay byte-identical
    save("water_cells.png", water_cells(rng))
    save("noise.png", noise_texture(rng))
    save("mist.png", mist_band(rng))
    write_provenance()


if __name__ == "__main__":
    main()
