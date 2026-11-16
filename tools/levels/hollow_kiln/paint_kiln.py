"""Painted textures for the Hollow Kiln: tileable building materials, the top-down ground, the far
valley, and the atlas textures of the level's props and characters.

    python -I tools/levels/hollow_kiln/paint_kiln.py tiles <out_dir>
    python -I tools/levels/hollow_kiln/paint_kiln.py ground <out_dir>
    python -I tools/levels/hollow_kiln/paint_kiln.py far <out_dir>
    python -I tools/levels/hollow_kiln/paint_kiln.py model <name> <paintmap.json> <out_dir>

Uses the shared washes and strokes in tools/textures/painted/inkpaint.py and the paint-map
helpers in tools/textures/painted/paint_models.py (imported, not edited). The style guide's
rules hold: flat washes with large soft value variation (about +-5 %), a few bold tapered ink
strokes, dry-brush breaks, no gradients or photographic noise. Tiles wrap seamlessly: their
value field is periodic and every stroke is also drawn at its wrapped offsets.
"""
import math
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "textures", "painted"))
sys.path.insert(0, HERE)
import numpy as np  # noqa: E402
from scipy import ndimage  # noqa: E402

import inkpaint as ip  # noqa: E402
import kiln_layout as K  # noqa: E402

INK = ip.INK
INK_BROWN = ip.INK_BROWN
H = ip.hex_rgb


def periodic_noise(size, cycles, rng, octaves=3):
    """Smooth noise in about [-1, 1] that wraps on both axes; about cycles features per tile."""
    yy, xx = np.mgrid[0:size, 0:size] / size
    out = np.zeros((size, size))
    amp = 1.0
    for o in range(octaves):
        c = cycles * (2 ** o)
        for _ in range(14):
            fx, fy = 0, 0
            while fx == 0 and fy == 0:
                fx, fy = rng.integers(-c, c + 1), rng.integers(-c, c + 1)
            ph = rng.random() * 2 * math.pi
            out += amp * rng.uniform(0.5, 1.0) * np.sin(2 * math.pi * (fx * xx + fy * yy) + ph)
        amp *= 0.5
    out -= out.mean()
    return out / (np.abs(out).max() + 1e-6)


class Tile(ip.Canvas):
    def __init__(self, size, color, seed):
        super().__init__(size, size, color, seed)
        self.size = size

    def pwash(self, color, variation=0.05, cycles=2, mask=None):
        v = periodic_noise(self.size, cycles, self.rng) * variation + periodic_noise(self.size, cycles * 3, self.rng, 2) * variation * 0.4
        col = np.empty((self.size, self.size, 3))
        col[:] = color
        col *= (1.0 + v)[..., None]
        a = (np.ones((self.size, self.size)) if mask is None else mask)[..., None]
        self.img = self.img * (1 - a) + col * a

    def wstroke(self, pts, width, color=INK, alpha=1.0, **kw):
        seed = int(self.rng.integers(1 << 30))
        s = self.size
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for dx in (-s, 0, s):
            for dy in (-s, 0, s):
                if max(xs) + dx < -width or min(xs) + dx > s + width or max(ys) + dy < -width or min(ys) + dy > s + width:
                    continue
                self.stroke([(x + dx, y + dy) for x, y in pts], width, color, alpha, seed=seed, **kw)

    def pblotches(self, color, count, radius, strength):
        layer = np.zeros((self.size, self.size))
        yy, xx = np.mgrid[0:self.size, 0:self.size]
        for _ in range(count):
            x, y = self.rng.random() * self.size, self.rng.random() * self.size
            r = radius * (0.5 + self.rng.random())
            dx = np.minimum(np.abs(xx - x), self.size - np.abs(xx - x))
            dy = np.minimum(np.abs(yy - y), self.size - np.abs(yy - y))
            d = np.hypot(dx, dy * (0.6 + 0.8 * self.rng.random())) / r
            layer = np.maximum(layer, np.clip(1.0 - d, 0, 1) ** 1.5)
        layer = ndimage.gaussian_filter(layer, radius * 0.15, mode="wrap") * strength
        self.img = self.img * (1 - layer[..., None]) + np.asarray(color) * layer[..., None]

    def wsoften(self, sigma=0.6):
        self.img = ndimage.gaussian_filter(self.img, (sigma, sigma, 0), mode="wrap")


def wobble_line(x0, y0, x1, y1, rng, n=5, amp=2.0):
    pts = []
    for k in range(n + 1):
        t = k / n
        pts.append((x0 + (x1 - x0) * t + rng.normal() * amp * 0.3, y0 + (y1 - y0) * t + rng.normal() * amp))
    return pts


def crack(c, x, y, length, width, rng, color=INK, alpha=0.85):
    a = rng.random() * 2 * math.pi
    pts = [(x, y)]
    for _ in range(4):
        a += rng.normal() * 0.6
        seg = length * (0.18 + rng.random() * 0.2)
        pts.append((pts[-1][0] + math.cos(a) * seg, pts[-1][1] + math.sin(a) * seg))
    c.wstroke(pts, width, color, alpha, taper=(0.06, 0.6), dry=0.45, pressure=0.4)


# ------------------------------------------------------------------------------------ tiles
def tile_plaster(out, size=1024):
    rng = np.random.default_rng(501)
    c = Tile(size, H("ddd0b1"), 501)
    c.pwash(H("ddd0b1"), 0.05, 2)
    c.pblotches(H("c9b994"), 6, size * 0.12, 0.35)
    c.pblotches(H("e8ddc4"), 5, size * 0.1, 0.4)
    for _ in range(5):
        x, y = rng.random() * size, rng.random() * size
        c.wstroke(wobble_line(x, y, x + rng.normal() * 8, y + size * rng.uniform(0.15, 0.35), rng, 6, 3), size * 0.02,
                  H("b6a684"), 0.25, taper=(0.1, 0.9), dry=0.7, pressure=0.3)
    for _ in range(7):
        crack(c, rng.random() * size, rng.random() * size, size * 0.18, size * 0.006, rng, mix_ink(0.25))
    c.wsoften(0.7)
    c.save(out)


def mix_ink(t):
    return ip.mix(INK_BROWN, H("ddd0b1"), t)


def tile_brick(out, size=1024, base="8d7868", seed=502):
    rng = np.random.default_rng(seed)
    c = Tile(size, H(base), seed)
    c.pwash(H(base), 0.05, 2)
    rows = 16
    rh = size / rows
    for r in range(rows):
        y = r * rh
        off = (r % 2) * rh * 1.0
        x = off
        while x < size + off:
            w = rh * rng.uniform(1.7, 2.3)
            if rng.random() < 0.25:
                tint = H("a08a72") if rng.random() < 0.5 else H("75645a")
                yy, xx = np.mgrid[0:size, 0:size]
                m = ((((xx - x) % size) < w) & (yy >= y) & (yy < y + rh)).astype(float)
                c.img = c.img * (1 - m[..., None] * 0.5) + np.asarray(tint) * m[..., None] * 0.5
            if rng.random() < 0.3:
                c.wstroke([(x % size, y + rh * 0.1), ((x % size) + rng.normal(), y + rh * 0.95)], size * 0.007, INK_BROWN, 0.5, taper=(0.2, 0.4), dry=0.5)
            x += w
        if rng.random() < 0.55:
            x0 = rng.random() * size
            c.wstroke(wobble_line(x0, y, x0 + size * rng.uniform(0.3, 0.7), y, rng, 6, 1.2), size * 0.009, INK_BROWN, 0.6, taper=(0.1, 0.5), dry=0.6, pressure=0.5)
    c.pblotches(H("4d443e"), 4, size * 0.12, 0.3)
    for _ in range(3):
        crack(c, rng.random() * size, rng.random() * size, size * 0.2, size * 0.008, rng, INK, 0.8)
    c.wsoften(0.8)
    c.save(out)


def tile_stone(out, size=512):
    rng = np.random.default_rng(503)
    c = Tile(size, H("8c8a80"), 503)
    c.pwash(H("8c8a80"), 0.06, 2)
    c.pblotches(H("a19e92"), 5, size * 0.15, 0.4)
    y = 0.0
    while y < size:
        h = size * rng.uniform(0.18, 0.3)
        x0 = rng.random() * size
        c.wstroke(wobble_line(x0, y, x0 + size * rng.uniform(0.5, 0.95), y + rng.normal() * 4, rng, 7, 3.0), size * 0.016, INK, 0.8, taper=(0.08, 0.5), dry=0.55, pressure=0.6)
        x = rng.random() * size * 0.3
        while x < size:
            if rng.random() < 0.6:
                c.wstroke([(x, y + h * 0.1), (x + rng.normal() * 6, y + h * 0.5), (x + rng.normal() * 6, y + h * 0.9)], size * 0.014, INK, 0.75, taper=(0.15, 0.5), dry=0.5, pressure=0.5)
            x += size * rng.uniform(0.25, 0.5)
        y += h
    for _ in range(4):
        crack(c, rng.random() * size, rng.random() * size, size * 0.2, size * 0.008, rng)
    c.wsoften(0.7)
    c.save(out)


def tile_timber(out, size=512):
    rng = np.random.default_rng(504)
    c = Tile(size, H("5d4c3d"), 504)
    c.pwash(H("5d4c3d"), 0.06, 2)
    for _ in range(14):
        x = rng.random() * size
        y = rng.random() * size
        c.wstroke(wobble_line(x, y, x + rng.normal() * 6, y + size * rng.uniform(0.3, 0.7), rng, 6, 2), size * rng.uniform(0.006, 0.012),
                  H("3a2f26"), 0.6, taper=(0.1, 0.6), dry=0.65, pressure=0.4)
    for _ in range(3):
        x, y = rng.random() * size, rng.random() * size
        pts = [(x + math.cos(a) * size * 0.025, y + math.sin(a) * size * 0.04) for a in np.linspace(0, 5.6, 10)]
        c.wstroke(pts, size * 0.008, INK, 0.7, taper=(0.1, 0.3), dry=0.4)
    c.wsoften(0.6)
    c.save(out)


def tile_roof(out, size=512):
    rng = np.random.default_rng(505)
    c = Tile(size, H("5f5d57"), 505)
    c.pwash(H("5f5d57"), 0.06, 2)
    rows = 8
    for r in range(rows):
        y = (r + 0.85) * size / rows
        c.wstroke(wobble_line(0, y, size, y, rng, 8, 1.0), size * 0.016, H("2a2927"), 0.85, taper=(0.02, 0.05), dry=0.45, pressure=0.3)
        x = (r % 2) * size / 16
        while x < size:
            c.wstroke([(x, y - size / rows * 0.85), (x + 2, y)], size * 0.008, H("2a2927"), 0.5, taper=(0.2, 0.5), dry=0.5)
            x += size / 8
    c.pblotches(H("777366"), 4, size * 0.15, 0.3)
    c.wsoften(0.7)
    c.save(out)


def tile_flag(out, size=1024):
    rng = np.random.default_rng(506)
    c = Tile(size, H("aaa491"), 506)
    c.pwash(H("aaa491"), 0.05, 2)
    c.pblotches(H("b9b3a0"), 6, size * 0.1, 0.4)
    c.pblotches(H("8f8a78"), 5, size * 0.08, 0.3)
    rows = 5
    for r in range(rows):
        y = r * size / rows + rng.normal() * 4
        c.wstroke(wobble_line(0, y, size, y, rng, 9, 3), size * 0.008, INK, 0.65, taper=(0.03, 0.06), dry=0.6, pressure=0.5)
        x = rng.random() * size / 4
        while x < size:
            c.wstroke([(x, y + 4), (x + rng.normal() * 6, y + size / rows - 4)], size * 0.008, INK, 0.65, taper=(0.15, 0.3), dry=0.55)
            for _ in range(int(rng.integers(0, 3))):
                c.tick(x + rng.normal() * 4, y + rng.uniform(0.2, 0.9) * size / rows, size * 0.02, -math.pi / 2 + rng.normal() * 0.5, size * 0.004, H("3b4a33"), 0.7)
            x += size * rng.uniform(0.16, 0.28)
    for _ in range(5):
        crack(c, rng.random() * size, rng.random() * size, size * 0.12, size * 0.005, rng)
    c.wsoften(0.7)
    c.save(out)


def tile_boards(out, size=512, base="6b5c4b", line="352b22", spacing=0.075, seed=507, nails=False):
    rng = np.random.default_rng(seed)
    c = Tile(size, H(base), seed)
    c.pwash(H(base), 0.05, 2)
    y = 0.0
    n = int(round(1 / spacing))
    for r in range(n):
        y = r * size / n
        c.wstroke(wobble_line(0, y, size, y, rng, 8, 0.8), size * 0.007, H(line), 0.75, taper=(0.02, 0.04), dry=0.5, pressure=0.3)
        x = rng.random() * size
        c.wstroke([(x, y + 2), (x + 1, y + size / n - 2)], size * 0.006, H(line), 0.65, taper=(0.2, 0.3), dry=0.4)
        for _ in range(3):
            gx = rng.random() * size
            c.wstroke([(gx, y + size / n * 0.5), (gx + size * rng.uniform(0.1, 0.3), y + size / n * 0.5 + rng.normal() * 2)],
                      size * 0.004, H(line), 0.3, taper=(0.2, 0.6), dry=0.7)
        if nails:
            for k in range(2):
                nx = (x + size * 0.5 * k + 6) % size
                c.wstroke([(nx, y + size / n * 0.3), (nx + 1, y + size / n * 0.32)], size * 0.01, INK, 0.8, taper=(0.3, 0.3), dry=0.1)
    c.wsoften(0.6)
    c.save(out)


def tile_paper(out, size=256):
    rng = np.random.default_rng(508)
    c = Tile(size, H("e9e1ce"), 508)
    c.pwash(H("e9e1ce"), 0.04, 2)
    for _ in range(10):
        x, y = rng.random() * size, rng.random() * size
        a = rng.random() * math.pi
        c.wstroke([(x, y), (x + math.cos(a) * size * 0.08, y + math.sin(a) * size * 0.08)], 1.2, H("b8ae98"), 0.5, taper=(0.3, 0.5), dry=0.2)
    c.pblotches(H("d4c8ae"), 3, size * 0.2, 0.3)
    c.wsoften(0.5)
    c.save(out)


def tile_iron(out, size=256):
    c = Tile(size, H("3b3936"), 509)
    c.pwash(H("3b3936"), 0.1, 2)
    c.pblotches(H("6a4a36"), 6, size * 0.1, 0.35)
    c.wsoften(0.5)
    c.save(out)


def tile_ink(out, size=128):
    c = Tile(size, H("1c1b1e"), 510)
    c.pwash(H("1c1b1e"), 0.15, 2)
    c.wsoften(0.5)
    c.save(out)


TILES = {"hk_plaster": tile_plaster, "hk_brick": tile_brick, "hk_stone": tile_stone, "hk_timber": tile_timber,
         "hk_roof": tile_roof, "hk_flag": tile_flag,
         "hk_board": lambda out: tile_boards(out, 512, "6b5c4b", "352b22", 0.075, 507),
         "hk_plank": lambda out: tile_boards(out, 512, "c2ab80", "5a4632", 0.11, 511, nails=True),
         "hk_paper": tile_paper, "hk_iron": tile_iron, "hk_ink": tile_ink}


# ------------------------------------------------------------------------------------ ground
GW, GH = 1392, 2048


def ground(out):
    rng = np.random.default_rng(601)
    xs = K.NEAR_X[0] + (np.arange(GW) + 0.5) / GW * (K.NEAR_X[1] - K.NEAR_X[0])
    zs = K.NEAR_Z[0] + (np.arange(GH) + 0.5) / GH * (K.NEAR_Z[1] - K.NEAR_Z[0])
    gx, gz = np.meshgrid(xs, zs)
    h = K.height(gx, gz)
    ppm = GW / (K.NEAR_X[1] - K.NEAR_X[0])
    dy, dx = np.gradient(h, zs, xs)
    slope = np.hypot(dx, dy)
    c = ip.Canvas(GW, GH, H("9aa585"), seed=601)
    c.wash(np.ones((GH, GW)), H("97a383"), variation=0.05, blotch=ppm * 6, hue_shift=H("a8a87e"))
    rock = ip.smoothstep(0.7, 1.1, slope)
    c.wash(rock, H("8c8a80"), variation=0.06, blotch=ppm * 4, edge_noise=4)
    high = ip.smoothstep(14.0, 30.0, h) * (1 - rock)
    c.wash(high, H("a6a389"), variation=0.05, blotch=ppm * 8)
    sd = K.stream_distance(gx, gz)
    bank = ((sd < K.STREAM_HALF + 2.0) & (gz > K.YARD["z"][1])).astype(float)
    c.wash(ndimage.gaussian_filter(bank, 3), H("6c6a5e"), variation=0.08, blotch=ppm * 2)
    path_d = K.polyline_distance(gx, gz, K.PATH[:5])
    path = ip.smoothstep(1.7, 1.2, path_d)
    c.wash(path, H("d1c4a2"), variation=0.04, blotch=ppm * 3, edge_noise=3)
    flat = (gz > K.YARD["z"][1] + 2) | (gz < -6)
    # grass tufts on the gentle ground, rock cracks on the steep ground
    n_tufts = 2600
    for _ in range(n_tufts):
        i, j = int(rng.random() * GW), int(rng.random() * GH)
        if slope[j, i] > 0.7 or path_d[j, i] < 2.0 or sd[j, i] < K.STREAM_HALF + 0.5 or not flat[j, i]:
            continue
        c.tuft(i, j, ppm * rng.uniform(0.5, 0.9), color=H("3f4a33"), alpha=0.75, blades=int(rng.integers(2, 4)))
    for _ in range(420):
        i, j = int(rng.random() * GW), int(rng.random() * GH)
        if rock[j, i] < 0.5:
            continue
        a = rng.random() * 2 * math.pi
        pts = [(i, j)]
        for _ in range(3):
            a += rng.normal() * 0.6
            seg = ppm * rng.uniform(0.8, 2.0)
            pts.append((pts[-1][0] + math.cos(a) * seg, pts[-1][1] + math.sin(a) * seg))
        c.stroke(pts, ppm * rng.uniform(0.18, 0.35), INK, 0.85, taper=(0.06, 0.6), dry=0.45, pressure=0.4)
    # ragged ticks along both edges of the path, as if the brush skipped
    for k in range(len(K.PATH[:5]) - 1):
        (ax, az), (bx, bz) = K.PATH[k], K.PATH[k + 1]
        L = math.hypot(bx - ax, bz - az)
        nx, nz = -(bz - az) / L, (bx - ax) / L
        for s in np.arange(0.0, L, 0.9):
            for side in (-1, 1):
                if rng.random() < 0.35:
                    continue
                x = ax + (bx - ax) * s / L + nx * side * 1.55
                z = az + (bz - az) * s / L + nz * side * 1.55
                i, j = (x - K.NEAR_X[0]) * ppm, (z - K.NEAR_Z[0]) * ppm
                c.tick(i, j, ppm * rng.uniform(0.3, 0.6), math.atan2(bz - az, bx - ax) + rng.normal() * 0.3, ppm * 0.12, INK, 0.7)
    # dark ragged contact strokes where walls meet the ground (hides hull seams at the base)
    yx, yz = K.YARD["x"], K.YARD["z"]
    for (x0, z0), (x1, z1) in (((yx[0] - 1.1, yz[1] + 1.1), (yx[1] + 1.1, yz[1] + 1.1)), ((yx[0] - 1.1, yz[0] - 2.0), (yx[0] - 1.1, yz[1] + 1.1)),
                               ((yx[1] + 1.1, yz[0] - 2.0), (yx[1] + 1.1, yz[1] + 1.1))):
        pts = [((x0 + (x1 - x0) * t - K.NEAR_X[0]) * ppm, (z0 + (z1 - z0) * t - K.NEAR_Z[0]) * ppm) for t in np.linspace(0, 1, 12)]
        c.stroke(pts, ppm * 0.6, INK_BROWN, 0.55, taper=(0.02, 0.05), dry=0.65, pressure=0.5)
    c.soften(0.6)
    c.img = c.img[::-1]
    c.save(out)


def far(out, size=1024):
    rng = np.random.default_rng(701)
    c = ip.Canvas(size, size, H("e6dcc4"), seed=701)
    # left half: the valley below, top-down (u 0.02..0.48 over x, v 0.52..0.98 over z)
    u = np.linspace(0, 1, size)
    uu, vv = np.meshgrid(u, 1.0 - u)
    x = K.FAR_X[0] + (uu - 0.02) / 0.46 * (K.FAR_X[1] - K.FAR_X[0])
    z = K.FAR_Z[0] + (0.98 - vv) / 0.46 * (K.FAR_Z[1] - K.FAR_Z[0])
    region = ((uu < 0.5) & (vv > 0.5)).astype(float)
    c.wash(region, H("9aa384"), variation=0.06, blotch=40, hue_shift=H("aaa47c"))
    sd = K.stream_distance(x, z)
    fields = (K.fbm(x, z, 60.0, 31) > 0.25) & (sd > 10)
    c.wash(region * fields, H("b4b08a"), variation=0.05, blotch=20, edge_noise=2)
    c.wash(region * (sd < 7).astype(float), H("8fa3a3"), variation=0.04, blotch=20, edge_noise=2)
    for _ in range(900):
        i, j = int(rng.random() * size * 0.5), int(size * 0.5 + rng.random() * size * 0.5)
        if sd[j, i] < 10:
            continue
        c.tuft(i, j, rng.uniform(4, 8), color=H("44533a"), alpha=0.6, blades=3)
    # right half: the ridge bands, pale wash darkening a little toward the top of each band
    for layer, col in enumerate(("a3a68e", "b3b29c", "c4c0ab")):
        v0, v1 = 0.6 + 0.12 * layer, 0.6 + 0.12 * layer + 0.1
        m = ((uu > 0.5) & (vv > v0 - 0.01) & (vv < v1 + 0.01)).astype(float)
        c.wash(m, H(col), variation=0.05, blotch=40)
        for _ in range(60):
            i = int(size * (0.52 + rng.random() * 0.46))
            j = int(size * (1.0 - (v1 - rng.random() * 0.03)))
            c.tick(i, j, rng.uniform(5, 12), math.pi / 2 + rng.normal() * 0.4, 1.4, H("5a5d4c"), 0.5)
    c.soften(0.6)
    c.save(out)


# ------------------------------------------------------------------------------------ props
def model(name, pm_path, out_dir):
    import paint_models as pmod
    pm = pmod.load(pm_path)
    size = pm["size"]
    out = os.path.join(out_dir, "%s.png" % name)
    recipe = RECIPES.get(name)
    if recipe:
        recipe(pmod, pm, size, out)
    else:
        prop(pmod, pm, size, out, 800 + sum(map(ord, name)))
    print("TEXTURE", name, size)


WASH = {
    "bark": "201e1c", "cord": "d5402b", "gold": "d9a441", "blossom": "f0b4be", "leaf": "8fa76b", "canopy": "7f9a5c",
    "canopy_under": "5f7748", "blossom_red": "d5402b", "paper": "ece3cd", "paper_grey": "c9c4b6",
    "paper_indigo": "5f7299", "paper_madder": "c4644c", "paper_ochre": "d4a54e", "stone": "8c8a80", "stone_top": "a19e92",
    "stone_dark": "5e5c55", "wood": "5a4a3c", "wood_pale": "a08868", "iron": "3b3936", "brass": "b08a42",
    "leather": "6e4b36", "clay": "a67c5b", "clay_dark": "6f5446", "glaze": "4f5b58", "rope": "b19a6f", "ink": "1e1c20",
    "soot": "2a2829", "moss": "6f8a4f", "moss_dry": "3c3a33", "flame": "e8a23a", "flame_core": "f6dc8a",
    "coal": "4a2a22", "eye": "e6e0d0", "root": "3a2e26", "water": "8fa3a3", "log": "6a5240", "log_end": "c9ab7d",
}


def prop(pmod, pm, size, out, seed):
    rng = np.random.default_rng(seed)
    masks, used = pmod.tag_masks(pm, size)
    first = H(WASH.get(sorted(masks)[0], "8c8a80"))
    c = ip.Canvas(size, size, first, seed=seed)
    for tag, m in masks.items():
        var = 0.12 if tag in ("bark", "root", "ink", "soot") else 0.05
        c.wash(m, H(WASH.get(tag, "8c8a80")), variation=var, blotch=size * 0.08, edge_noise=1.5)
    c.dilate_from(used)
    s = size / 512.0
    for tag, m in masks.items():
        for isl in pmod.islands_of(m):
            w, h = isl[2] - isl[0], isl[3] - isl[1]
            if w * h < 64:
                continue
            area = w * h / (size * size)
            if tag in ("bark", "root"):
                pmod.strokes_in_island(c, isl, H("4a4744"), max(1, int(area * 300)), 2.2 * s, rng, vertical=h > w, alpha=0.55, dry=0.6)
            elif tag.startswith("stone"):
                pmod.cracks(c, isl, rng, max(1, int(area * 60)), 3.0 * s, INK)
            elif tag in ("wood", "wood_pale", "log"):
                pmod.strokes_in_island(c, isl, H("2e251d"), max(2, int(area * 120)), 2.0 * s, rng, vertical=h > w, alpha=0.6, dry=0.5)
            elif tag in ("canopy", "canopy_under", "leaf", "moss"):
                pmod.fans(c, isl, rng, H("4f6a3a" if tag != "canopy_under" else "3d5230"), max(2, int(area * 400)), 14 * s)
            elif tag == "blossom":
                pmod.fans(c, isl, rng, H("e58aa0"), max(2, int(area * 300)), 10 * s)
                pmod.fans(c, isl, rng, H("fbf2ee"), max(1, int(area * 120)), 7 * s)
            elif tag == "blossom_red":
                pmod.fans(c, isl, rng, H("b8321f"), max(2, int(area * 300)), 10 * s)
                pmod.fans(c, isl, rng, H("f3b7a6"), max(1, int(area * 120)), 7 * s)
            elif tag in ("clay", "clay_dark", "glaze"):
                pmod.strokes_in_island(c, isl, H("3a2c24"), max(1, int(area * 40)), 2.4 * s, rng, vertical=False, alpha=0.5, dry=0.6)
            elif tag in ("iron", "soot", "ink"):
                c.blotches(H("6a4a36" if tag == "iron" else "45403f"), max(1, int(area * 30)), 12 * s, 0.25, mask=m)
            elif tag in ("flame", "flame_core"):
                pmod.strokes_in_island(c, isl, H("d5402b"), max(2, int(area * 60)), 3.0 * s, rng, vertical=True, alpha=0.6, dry=0.3)
            elif tag == "rope":
                pmod.strokes_in_island(c, isl, H("6b5a40"), max(2, int(area * 120)), 1.6 * s, rng, vertical=h > w, alpha=0.6, dry=0.4)
            elif tag == "log_end":
                x0, y0, x1, y1, mm = isl
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                for k in range(1, 4):
                    rr = min(w, h) * 0.12 * k
                    c.stroke([(cx + math.cos(a) * rr, cy + math.sin(a) * rr) for a in np.linspace(0, 5.8, 12)], 1.2 * s, H("6a5240"), 0.6, taper=(0.1, 0.3), dry=0.3)
    pmod.paint_creases(c, pm, size, {"paper", "paper_grey", "paper_indigo", "paper_madder", "paper_ochre", "stone", "stone_top", "wood", "wood_pale", "clay", "leather"}, ip.mix(INK_BROWN, H("ece2cb"), 0.1), 2.2 * s, 0.55, rng, alpha=0.75)
    pmod.finish(c, used, out)


def paint_dregs(pmod, pm, size, out):
    rng = np.random.default_rng(901)
    blot = H("1e1c20")
    c = ip.Canvas(size, size, blot, seed=901)
    masks, used = pmod.tag_masks(pm, size)
    c.wash(np.ones((size, size)), blot, variation=0.18, blotch=size * 0.06, hue_shift=H("2a2430"))
    for tag, col in (("veil", "4f4b4a"), ("eye", "e6e0d0"), ("flake", "6b625a"), ("crack", "8a3a2a"), ("arm", "232126")):
        if tag in masks:
            c.wash(masks[tag], H(col), variation=0.1, blotch=40, edge_noise=2)
    c.dilate_from(used)
    if "veil" in masks:
        c.blotches(H("757170"), 50, 36, strength=0.35, mask=masks["veil"])
        c.blotches(H("27252a"), 40, 30, strength=0.45, mask=masks["veil"])
        for isl in pmod.islands_of(masks["veil"]):
            if (isl[2] - isl[0]) * (isl[3] - isl[1]) > 300:
                pmod.strokes_in_island(c, isl, H("1c1b1d"), 3, 3.0, rng, vertical=(isl[3] - isl[1]) > (isl[2] - isl[0]), alpha=0.6, dry=0.7)
    for tag in ("ink", "arm"):
        if tag in masks:
            for isl in pmod.islands_of(masks[tag]):
                if (isl[2] - isl[0]) * (isl[3] - isl[1]) < 300:
                    continue
                pmod.strokes_in_island(c, isl, H("47434d"), 2, 3.0, rng, vertical=(isl[3] - isl[1]) > (isl[2] - isl[0]), alpha=0.35, dry=0.5)
    if "eye" in masks:
        for isl in pmod.islands_of(masks["eye"]):
            pmod.thumbprint(c, isl, rng)
    if "flake" in masks:
        for isl in pmod.islands_of(masks["flake"]):
            pmod.cracks(c, isl, rng, 2, 2.4, INK)
    pmod.finish(c, used, out)


RECIPES = {"dregs": paint_dregs}


if __name__ == "__main__":
    kind = sys.argv[1]
    if kind == "tiles":
        os.makedirs(sys.argv[2], exist_ok=True)
        only = sys.argv[3:]
        for name, fn in TILES.items():
            if only and name not in only:
                continue
            fn(os.path.join(sys.argv[2], name + ".png"))
            print("TEXTURE", name)
    elif kind == "ground":
        ground(os.path.join(sys.argv[2], "hk_ground.png"))
        print("TEXTURE hk_ground", GW, GH)
    elif kind == "far":
        far(os.path.join(sys.argv[2], "hk_far.png"))
        print("TEXTURE hk_far")
    elif kind == "model":
        model(sys.argv[2], sys.argv[3], sys.argv[4])
