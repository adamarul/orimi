"""Painted ground for Hazewater Vale: the 2K floor texture and the walls/ridges/water texture.

    python tools/textures/painted/paint_terrain.py <out_dir>

terrain.png (1024 x 2048) maps top-down over the floor rectangle in valley_layout.py
(about 14 px per metre): sage-olive grass wash with ochre drift, a paler sandy path with ragged
ink ticks along both edges, sandy banks and a stony river bed, grey rock on every steep slope
with tapered crack strokes and a dark ragged contact band at cliff feet, grass-tuft ticks, and
a contact stroke where the great tree stands.
terrain_walls.png (1024 x 1024): rock strata and cracks for the valley walls (upper 7/8), a
water wash with white ripple arcs (bottom-left) and a pale ridge wash (bottom-right).
"""
import math
import sys
from pathlib import Path

import numpy as np
from scipy import ndimage

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1] / "blender"))
import valley_layout as V  # noqa: E402
from inkpaint import INK, INK_BROWN, Canvas, hex_rgb, mix, smoothstep, soft_noise  # noqa: E402

W, H = 1024, 2048
X0, X1 = V.FLOOR_X
Z0, Z1 = V.FLOOR_Z
SX, SZ = W / (X1 - X0), H / (Z1 - Z0)

GRASS = hex_rgb("98a078")
GRASS_OCHRE = hex_rgb("ada276")
GRASS_RISE = hex_rgb("8d9c70")
PATH_SAND = hex_rgb("d5c7a0")
BANK = hex_rgb("c7bc98")
BED = hex_rgb("7b8682")
ROCK = hex_rgb("8d8a80")
ROCK_OCHRE = hex_rgb("9b9079")
INK_GROUND = mix(INK, hex_rgb("3a3a2a"), 0.35)


def to_px(x, z):
    return ((x - X0) * SX, (z - Z0) * SZ)


def polyline_px(pts):
    return [to_px(x, z) for x, z in pts]


def offset_polyline(pts, offset, step=0.5):
    """Sample a polyline every \`step\` metres and offset it sideways; returns (x, z, tangent angle)."""
    p = np.asarray(pts, dtype=float)
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s[-1], step)
    x, z = np.interp(t, s, p[:, 0]), np.interp(t, s, p[:, 1])
    tx, tz = np.gradient(x), np.gradient(z)
    n = np.hypot(tx, tz) + 1e-9
    return x - tz / n * offset, z + tx / n * offset, np.arctan2(tz * SZ, tx * SX)


def paint_floor(out):
    rng = np.random.default_rng(5)
    c = Canvas(W, H, GRASS, seed=5)
    px = (np.arange(W) + 0.5) / SX + X0
    pz = (np.arange(H) + 0.5) / SZ + Z0
    gx, gz = np.meshgrid(px, pz)
    h = V.height(gx, gz)
    dz, dx = np.gradient(h, 1.0 / SZ, 1.0 / SX)
    slope = np.hypot(dx, dz)
    path_d, _ = V.polyline_distance(gx, gz, V.PATH)
    river_d = V.river_distance(gx, gz)
    ones = np.ones((H, W))

    # grass, drifting toward ochre in big blotches; the Rise a little deeper
    c.wash(ones, GRASS, variation=0.05, blotch=110, hue_shift=GRASS_OCHRE)
    rise = smoothstep(4.5, 5.8, h) * (np.hypot(gx - V.RISE_C[0], gz - V.RISE_C[1]) < 24)
    c.wash(rise, GRASS_RISE, variation=0.05, blotch=80, edge_noise=6)

    # river bed and banks
    bank = smoothstep(V.RIVER_HALF + V.RIVER_BANK + 1.6, V.RIVER_HALF + V.RIVER_BANK + 0.4, river_d)
    c.wash(bank, BANK, variation=0.05, blotch=50, edge_noise=5)
    bed = smoothstep(V.RIVER_HALF + 1.0, V.RIVER_HALF - 0.4, river_d)
    c.wash(bed, BED, variation=0.06, blotch=40, edge_noise=4)

    # rock on every steep slope
    rock = smoothstep(0.75, 1.25, slope)
    rock = np.maximum(rock, ndimage.grey_dilation(rock, size=(5, 5)) * 0.0)
    c.wash(rock, ROCK, variation=0.06, blotch=60, edge_noise=4, hue_shift=ROCK_OCHRE)

    # the path: paler sand, wash stops short or spills a little
    path = smoothstep(1.55, 1.05, path_d) * (1.0 - bed)
    c.wash(path, PATH_SAND, variation=0.04, blotch=40, edge_noise=4)

    # dark ragged contact band at the foot of every cliff
    steep = slope > 1.0
    near_steep = ndimage.binary_dilation(steep, iterations=6) & ~steep
    low_side = h < ndimage.grey_dilation(h, size=(13, 13)) - 1.2
    foot = (near_steep & low_side).astype(float)
    foot = ndimage.gaussian_filter(foot, 1.6)
    foot = np.clip(foot * 2.2 + soft_noise((H, W), 10, rng) * 0.35, 0, 1) * (1.0 - bed)
    c.wash(foot, INK_GROUND, variation=0.0, blotch=20)

    # ragged ticks along both path edges, as if the brush skipped
    for side in (-1, 1):
        ex, ez, ang = offset_polyline(V.PATH, side * 1.4, step=0.7)
        for x, z, a in zip(ex, ez, ang):
            if rng.random() < 0.55 or V.river_distance(x, z) < V.RIVER_HALF + 1.0:
                continue
            u, v = to_px(x + rng.normal() * 0.15, z + rng.normal() * 0.15)
            length = 6 + rng.random() ** 2 * 26
            c.tick(u, v, length, a + (rng.random() - 0.5) * 0.7 + (math.pi if rng.random() < 0.5 else 0), 2.2 + rng.random() * 3.0, INK_GROUND, 0.9)

    # bank edge ticks
    for side in (-1, 1):
        ex, ez, ang = offset_polyline(V.RIVER, side * (V.RIVER_HALF + V.RIVER_BANK + 0.9), step=1.6)
        for x, z, a in zip(ex, ez, ang):
            if not (X0 < x < X1 and Z0 < z < Z1) or rng.random() < 0.4:
                continue
            u, v = to_px(x, z)
            c.tick(u, v, 12 + rng.random() * 14, a + (rng.random() - 0.5) * 0.3, 2.6 + rng.random() * 1.8, INK_GROUND, 0.8)

    # a few long deliberate cracks down the rock faces, each following the fall line, some forked
    ys, xs = np.nonzero(slope > 1.3)
    placed = []
    for k in rng.permutation(len(xs)):
        if len(placed) >= 70:
            break
        u, v = int(xs[k]), int(ys[k])
        if any((u - pu) ** 2 + (v - pv) ** 2 < 34 ** 2 for pu, pv in placed):
            continue
        placed.append((u, v))
        pts = [(float(u), float(v))]
        wander = (rng.random() - 0.5) * 0.4
        for _ in range(7):
            cu, cv = int(min(W - 1, max(0, pts[-1][0]))), int(min(H - 1, max(0, pts[-1][1])))
            if slope[cv, cu] < 0.8:
                break
            a = math.atan2(dz[cv, cu] * SZ, dx[cv, cu] * SX) + math.pi + wander + (rng.random() - 0.5) * 0.35
            seg = 9 + rng.random() * 9
            pts.append((pts[-1][0] + math.cos(a) * seg, pts[-1][1] + math.sin(a) * seg))
        if len(pts) < 4:
            continue
        width = 4.5 + rng.random() * 4.5
        c.stroke(pts, width, INK_GROUND, 0.92, taper=(0.12, 0.7), dry=0.3)
        if rng.random() < 0.45:
            j = 1 + int(rng.random() * (len(pts) - 2))
            a = math.atan2(pts[j + 1][1] - pts[j][1], pts[j + 1][0] - pts[j][0]) + (0.5 if rng.random() < 0.5 else -0.5)
            fork = [pts[j]] + [(pts[j][0] + math.cos(a) * 12 * i, pts[j][1] + math.sin(a) * 12 * i) for i in (1, 2, 3)]
            c.stroke(fork, width * 0.6, INK_GROUND, 0.88, taper=(0.1, 0.8), dry=0.35)

    # grass tufts on open ground
    open_ground = (rock < 0.2) & (path < 0.1) & (bank < 0.1) & (bed < 0.1) & (h < 20)
    ys, xs = np.nonzero(open_ground)
    for k in rng.choice(len(xs), size=min(len(xs), 240), replace=False):
        colour = INK_GROUND if rng.random() < 0.75 else hex_rgb("4d5a3c")
        for _ in range(3 + int(rng.random() * 4)):
            u, v = xs[k] + rng.normal() * 6, ys[k] + rng.normal() * 4
            c.tuft(u, v, 8 + rng.random() * 7, colour, 0.65 + 0.25 * rng.random(),
                   blades=3 + int(rng.random() * 3), up=-math.pi / 2 + (rng.random() - 0.5) * 0.5)

    # contact stroke where the Thousand-Ring Camphor stands
    tx, _, tz = V.MARKERS["M_Tree"]
    for k in range(9):
        a0 = rng.random() * 2 * math.pi
        r = 1.7 + rng.random() * 0.7
        pts = [to_px(tx + math.cos(a0 + t) * r, tz + math.sin(a0 + t) * r * 0.95) for t in np.linspace(0, 1.4, 6)]
        c.stroke(pts, 5 + rng.random() * 5, INK, 0.9, taper=(0.15, 0.5), dry=0.35)

    c.soften(0.6)
    c.save(out)


def paint_walls(out):
    S = 1024
    rng = np.random.default_rng(9)
    c = Canvas(S, S, ROCK, seed=9)
    rock_rows = int(S * 0.875)
    rock_mask = np.zeros((S, S))
    rock_mask[:rock_rows] = 1
    c.wash(rock_mask, ROCK, variation=0.06, blotch=90, hue_shift=ROCK_OCHRE)
    moss = np.zeros((S, S))
    moss[:150] = 1
    c.wash(moss, GRASS, variation=0.05, blotch=60, edge_noise=18, hue_shift=GRASS_OCHRE)
    # strata: a few long thin dry horizontal strokes
    for _ in range(14):
        y = 120 + rng.random() * (rock_rows - 140)
        x = rng.random() * S
        l = 120 + rng.random() * 260
        pts = [(x, y), (x + l / 2, y + rng.normal() * 6), (x + l, y + rng.normal() * 10)]
        c.stroke(pts, 1.6 + rng.random() * 2.2, INK_GROUND, 0.75, taper=(0.1, 0.5), dry=0.6)
    # cracks: a handful of bold, long, tapered strokes running down the face, a few forked
    for k in range(13):
        x, y = (k + 0.2 + rng.random() * 0.6) * S / 13, 130 + rng.random() * 160
        a = math.pi / 2 + (rng.random() - 0.5) * 0.5
        pts = [(x, y)]
        for _ in range(6):
            a += (rng.random() - 0.5) * 0.5
            seg = 45 + rng.random() * 45
            pts.append((pts[-1][0] + math.cos(a) * seg, min(rock_rows - 10, pts[-1][1] + math.sin(a) * seg)))
        width = 9 + rng.random() * 9
        c.stroke(pts, width, INK_GROUND, 0.93, taper=(0.1, 0.75), dry=0.35)
        for _ in range(int(rng.random() * 3)):
            j = 1 + int(rng.random() * (len(pts) - 2))
            b = a + (0.6 if rng.random() < 0.5 else -0.6)
            fork = [pts[j]] + [(pts[j][0] + math.cos(b) * 40 * i, pts[j][1] + math.sin(b) * 40 * i) for i in (1, 2, 3)]
            c.stroke(fork, width * 0.55, INK_GROUND, 0.9, taper=(0.1, 0.8), dry=0.4)
    for _ in range(36):
        cx, cy = rng.random() * S, 30 + rng.random() * 110
        for _ in range(3 + int(rng.random() * 4)):
            c.tuft(cx + rng.normal() * 9, cy + rng.normal() * 5, 12 + rng.random() * 8, INK_GROUND, 0.75)

    # water (bottom-left): blue-grey wash with white calligraphic ripple arcs
    water = np.zeros((S, S))
    water[rock_rows:, : S // 2] = 1
    c.wash(water, hex_rgb("7f9ea3"), variation=0.05, blotch=40, hue_shift=hex_rgb("6f8f98"))
    for _ in range(46):
        x, y = 20 + rng.random() * (S // 2 - 60), rock_rows + 18 + rng.random() * (S - rock_rows - 36)
        r = 10 + rng.random() * 18
        a0 = rng.random() * math.pi
        pts = [(x + math.cos(a0 + t) * r, y + math.sin(a0 + t) * r * 0.35) for t in np.linspace(0, 2.0, 7)]
        c.stroke(pts, 2.0 + rng.random() * 1.6, hex_rgb("f1efe6"), 0.85, taper=(0.15, 0.6), dry=0.35)
    # ridges (bottom-right): pale wash that fades toward paper, a few grey crease strokes
    ridge = np.zeros((S, S))
    ridge[rock_rows:, S // 2:] = 1
    c.wash(ridge, hex_rgb("c9cec4"), variation=0.035, blotch=60, hue_shift=hex_rgb("d9d6c6"))
    for _ in range(26):
        x, y = S // 2 + 20 + rng.random() * (S // 2 - 40), rock_rows + 22 + rng.random() * 30
        a = math.pi / 2 + (rng.random() - 0.5) * 1.2
        pts = [(x, y), (x + math.cos(a) * 18, y + math.sin(a) * 18), (x + math.cos(a + 0.3) * 34, y + math.sin(a + 0.3) * 34)]
        c.stroke(pts, 1.8 + rng.random() * 1.4, hex_rgb("8f948d"), 0.6, taper=(0.1, 0.6), dry=0.5)
    c.soften(0.5)
    c.save(out)


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paint_floor(str(out / "terrain.png"))
    print("TEXTURE terrain 1024x2048 textures/painted/terrain.png")
    paint_walls(str(out / "terrain_walls.png"))
    print("TEXTURE terrain_walls 1024 textures/painted/terrain_walls.png")


if __name__ == "__main__":
    main(sys.argv[1])
