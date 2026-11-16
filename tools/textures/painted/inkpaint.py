"""Ink-and-wash painting helpers for the painted albedo textures.

One small library used by every texture generator: flat washes with large soft value
variation, and ink brush strokes that taper, swing in weight and break up where the
brush runs dry. Everything is deterministic for a given seed.

    canvas = Canvas(1024, 1024, hex_rgb("efe6d2"), seed=3)
    canvas.wash(mask, hex_rgb("9daf8c"), variation=0.05, blotch=120)
    canvas.stroke([(10, 10), (200, 60), (380, 40)], width=9, color=INK, dry=0.4)
    canvas.save("out.png")
"""
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

INK = (0.105, 0.10, 0.11)
INK_BROWN = (0.30, 0.22, 0.16)


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def soft_noise(shape, scale, rng):
    """Smooth noise in about [-1, 1] with features roughly \`scale\` pixels across."""
    h, w = shape
    gh, gw = max(2, int(h / scale) + 3), max(2, int(w / scale) + 3)
    grid = rng.standard_normal((gh, gw))
    zoomed = ndimage.zoom(grid, (h / (gh - 2), w / (gw - 2)), order=3)[:h, :w]
    zoomed = ndimage.gaussian_filter(zoomed, scale * 0.25)
    zoomed -= zoomed.mean()
    return zoomed / (np.abs(zoomed).max() + 1e-6)


def value_noise_1d(n, rng):
    return rng.random(n + 2)


def sample_1d(table, x):
    """Linear interpolation into a 1D table at float positions x (wrapping)."""
    n = len(table) - 1
    x = np.mod(x, n)
    i = np.floor(x).astype(int)
    f = x - i
    return table[i] * (1 - f) + table[i + 1] * f


def resample_polyline(points, spacing):
    p = np.asarray(points, dtype=float)
    if len(p) < 2:
        return p
    # Chaikin smoothing twice keeps hand-placed control points soft.
    for _ in range(2):
        if len(p) < 3:
            break
        q = 0.75 * p[:-1] + 0.25 * p[1:]
        r = 0.25 * p[:-1] + 0.75 * p[1:]
        mid = np.empty((2 * len(q), 2))
        mid[0::2], mid[1::2] = q, r
        p = np.vstack([p[:1], mid, p[-1:]])
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    total = s[-1]
    if total < 1e-6:
        return p[:1]
    n = max(2, int(total / spacing) + 1)
    t = np.linspace(0.0, total, n)
    return np.stack([np.interp(t, s, p[:, 0]), np.interp(t, s, p[:, 1])], axis=1)


class Canvas:
    def __init__(self, width, height, color, seed=0):
        self.w, self.h = width, height
        self.img = np.empty((height, width, 3))
        self.img[:] = color
        self.rng = np.random.default_rng(seed)

    # ------------------------------------------------------------------ washes
    def wash(self, mask, color, variation=0.05, blotch=100.0, edge_noise=0.0, hue_shift=None):
        """Flat colour over \`mask\` (h x w floats 0..1) with large soft value blotches (+-variation).

        edge_noise > 0 makes the mask edge ragged by that many pixels, as wash spills or stops short.
        hue_shift: optional second colour mixed in by a second, larger blotch field (up to 35%)."""
        mask = np.asarray(mask, dtype=float)
        if edge_noise > 0:
            n = soft_noise(mask.shape, edge_noise * 2.5, self.rng)
            dist_in = ndimage.distance_transform_edt(mask > 0.5)
            dist_out = ndimage.distance_transform_edt(mask <= 0.5)
            signed = dist_in - dist_out
            mask = np.clip((signed + n * edge_noise) / 1.5 + 0.5, 0.0, 1.0)
        col = np.empty((self.h, self.w, 3))
        col[:] = color
        if hue_shift is not None:
            t = np.clip(soft_noise(mask.shape, blotch * 2.2, self.rng) * 0.5 + 0.5, 0, 1)[..., None] * 0.35
            col = col * (1 - t) + np.asarray(hue_shift) * t
        if variation > 0:
            v = soft_noise(mask.shape, blotch, self.rng) * variation
            v += soft_noise(mask.shape, blotch * 0.45, self.rng) * variation * 0.4
            col *= (1.0 + v)[..., None]
        a = mask[..., None]
        self.img = self.img * (1 - a) + col * a

    def blotches(self, color, count, radius, strength=0.15, mask=None):
        """Soft round pools of pigment (darker or lighter), used sparingly."""
        layer = np.zeros((self.h, self.w))
        for _ in range(count):
            x, y = self.rng.random() * self.w, self.rng.random() * self.h
            r = radius * (0.5 + self.rng.random())
            yy, xx = np.ogrid[:self.h, :self.w]
            d = np.hypot(xx - x, (yy - y) * (0.6 + 0.8 * self.rng.random())) / r
            layer = np.maximum(layer, np.clip(1.0 - d, 0, 1) ** 1.5)
        layer = ndimage.gaussian_filter(layer, radius * 0.15) * strength
        if mask is not None:
            layer *= mask
        a = layer[..., None]
        self.img = self.img * (1 - a) + np.asarray(color) * a

    # ------------------------------------------------------------------ strokes
    def stroke(self, points, width, color=INK, alpha=1.0, taper=(0.12, 0.45), dry=0.25,
               pressure=0.25, edge=0.12, seed=None, wrap=False):
        """One brush stroke along a polyline (pixel coordinates).

        width: full width in pixels at the heaviest point. taper: fractions of the length over
        which the stroke swells in and thins out to a point. dry: 0 solid .. 1 very broken; the
        bristle streaks open up toward the end of the stroke and where it is thin. pressure:
        how much the weight swings along the stroke. edge: raggedness of the edge."""
        rng = np.random.default_rng(seed) if seed is not None else self.rng
        pts = resample_polyline(points, 0.6)
        if len(pts) < 2:
            return
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        length = float(seg.sum())
        s = np.concatenate([[0.0], np.cumsum(seg)]) / max(length, 1e-6)
        tang = np.gradient(pts, axis=0)
        tang /= np.linalg.norm(tang, axis=1, keepdims=True) + 1e-9

        tin, tout = taper
        prof = np.sqrt(smoothstep(0.0, max(tin, 1e-3), s)) * (smoothstep(1.0, 1.0 - max(tout, 1e-3), s) ** 0.8)
        swing = sample_1d(value_noise_1d(8, rng), s * 6.0)
        prof = prof * (1.0 - pressure + pressure * (0.4 + 1.2 * swing))
        half_w = np.maximum(prof * width * 0.5, 0.0)

        pad = width + 3
        x0, y0 = int(max(0, np.floor(pts[:, 0].min() - pad))), int(max(0, np.floor(pts[:, 1].min() - pad)))
        x1, y1 = int(min(self.w, np.ceil(pts[:, 0].max() + pad))), int(min(self.h, np.ceil(pts[:, 1].max() + pad)))
        if x1 <= x0 or y1 <= y0:
            return
        yy, xx = np.mgrid[y0:y1, x0:x1]
        pix = np.stack([xx.ravel() + 0.5, yy.ravel() + 0.5], axis=1)
        dist, idx = cKDTree(pts).query(pix, distance_upper_bound=pad)
        ok = np.isfinite(dist)
        if not ok.any():
            return
        pix, dist, idx = pix[ok], dist[ok], idx[ok]
        rel = pix - pts[idx]
        side = np.sign(tang[idx, 0] * rel[:, 1] - tang[idx, 1] * rel[:, 0])
        hw = half_w[idx]
        si = s[idx]
        along = si * length
        rough = 1.0 + edge * (2.0 * sample_1d(value_noise_1d(64, rng), along / 5.0) - 1.0)
        hw_eff = hw * rough
        cov = np.clip(hw_eff - dist + 0.5, 0.0, 1.0)
        # Past the ends of the polyline the nearest point is an end point: keep the round tip small.
        u = np.clip(side * dist / np.maximum(hw_eff, 0.3), -1.0, 1.0)
        bristles = max(5, int(width * 1.3))
        streak_a = sample_1d(value_noise_1d(bristles + 2, rng), (u * 0.5 + 0.5) * bristles)
        streak_b = sample_1d(value_noise_1d(97, rng), (u * 0.5 + 0.5) * bristles * 0.7 + along / max(width * 9.0, 1.0))
        streak = 0.65 * streak_a + 0.35 * streak_b
        thin = 1.0 - np.clip(hw / (width * 0.5 + 1e-6), 0, 1)
        dryness = dry * (0.25 + 0.95 * smoothstep(0.35, 1.0, si) + 0.5 * thin)
        bristle = smoothstep(dryness - 0.12, dryness + 0.12, streak)
        a = cov * bristle * alpha
        layer = np.zeros((y1 - y0, x1 - x0))
        layer.ravel()[np.flatnonzero(ok)] = a
        region = self.img[y0:y1, x0:x1]
        np.maximum(layer, 0, out=layer)
        region[:] = region * (1 - layer[..., None]) + np.asarray(color) * layer[..., None]

    def tick(self, x, y, length, angle, width, color=INK, alpha=1.0, curve=0.25, dry=0.3, seed=None):
        """A short tapered tick (grass tuft blade, edge skip), angle in radians, 0 = pointing right."""
        rng = np.random.default_rng(seed) if seed is not None else self.rng
        dx, dy = np.cos(angle), np.sin(angle)
        nx, ny = -dy, dx
        bend = (rng.random() - 0.5) * 2 * curve * length
        pts = [(x, y), (x + dx * length * 0.5 + nx * bend * 0.5, y + dy * length * 0.5 + ny * bend * 0.5),
               (x + dx * length + nx * bend, y + dy * length + ny * bend)]
        self.stroke(pts, width, color, alpha, taper=(0.08, 0.75), dry=dry, pressure=0.1, edge=0.08, seed=rng.integers(1 << 30))

    def tuft(self, x, y, size, color=INK, alpha=0.85, blades=3, up=-np.pi / 2, spread=0.9, width=None):
        """A fan of 2-4 blades from one base point, the grass tuft of the style guide."""
        width = width or max(1.6, size * 0.22)
        for i in range(blades):
            a = up + (i - (blades - 1) / 2) * spread / max(blades - 1, 1) + (self.rng.random() - 0.5) * 0.3
            self.tick(x + (self.rng.random() - 0.5) * size * 0.2, y, size * (0.7 + 0.5 * self.rng.random()), a, width, color, alpha)

    # ------------------------------------------------------------------ finishing
    def soften(self, sigma=0.6):
        self.img = ndimage.gaussian_filter(self.img, (sigma, sigma, 0))

    def dilate_from(self, mask):
        """Fill pixels outside \`mask\` with the nearest inside colour (UV padding against bleeding)."""
        inside = mask > 0.5
        if inside.all() or not inside.any():
            return
        _, (iy, ix) = ndimage.distance_transform_edt(~inside, return_indices=True)
        self.img = self.img[iy, ix]

    def save(self, path):
        out = (np.clip(self.img, 0, 1) * 255 + 0.5).astype(np.uint8)
        Image.fromarray(out).save(path, optimize=True)
