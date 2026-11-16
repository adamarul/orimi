"""Painted textures for Sedge Plain's ground and hills, from layout.py.

    python tools/levels/sedge_plain/paint_ground.py <out_dir>

ground.png (2048 x 2048) maps top down over layout.FLOOR_X/Z, about 14 px per metre: an olive
sedge wash drifting to ochre, sand paths with ragged ink ticks along both edges, paler causeway
tops edged with stone ticks, wet-meadow hollow floors, rock with tapered crack strokes on every
steep face (the Seam's walls, the hollows' sides, the Knoll's cliffs), a dark ragged contact band
at every cliff foot, a pebbled dry bed in the Seam, sedge-tuft ticks leaning with the wind, and
contact strokes where stones and posts stand.
hills.png (1024 x 1024) maps top down over layout.OUTER_X/Z: the same washes at low detail, rock
on the steep hills, and a pale ridge wash in the bottom strip (the ridge silhouettes' UVs).
Uses the shared painter tools/textures/painted/inkpaint.py.
"""
import math
import sys
from pathlib import Path

import numpy as np
from scipy import ndimage

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1] / "textures" / "painted"))
import layout as L  # noqa: E402
from inkpaint import INK, Canvas, hex_rgb, mix, smoothstep, soft_noise  # noqa: E402

SEDGE = hex_rgb("a2a276")
SEDGE_OCHRE = hex_rgb("b3a774")
SEDGE_DEEP = hex_rgb("8e9a6c")
MEADOW = hex_rgb("7f8f66")
EARTH = hex_rgb("948a72")
PATH_SAND = hex_rgb("d5c7a0")
CAUSEWAY = hex_rgb("cdc09a")
BANK = hex_rgb("c7bc98")
BED = hex_rgb("7b8682")
DRY_BED = hex_rgb("a89f87")
ROCK = hex_rgb("8d8a80")
ROCK_OCHRE = hex_rgb("9b9079")
KNOLL = hex_rgb("9fa474")
INK_GROUND = mix(INK, hex_rgb("3a3a2a"), 0.35)
WIND_ANGLE = 0.0   # tufts lean east, the way the wind blows across the plain


class Field:
    """Pixel grid over a rectangle of the world, top row = north edge."""

    def __init__(self, w, h, x_range, z_range):
        self.w, self.h = w, h
        self.x0, self.x1 = x_range
        self.z0, self.z1 = z_range
        self.sx, self.sz = w / (self.x1 - self.x0), h / (self.z1 - self.z0)
        px = (np.arange(w) + 0.5) / self.sx + self.x0
        pz = (np.arange(h) + 0.5) / self.sz + self.z0
        self.gx, self.gz = np.meshgrid(px, pz)

    def to_px(self, x, z):
        return ((x - self.x0) * self.sx, (z - self.z0) * self.sz)


def offset_polyline(pts, offset, step):
    p = np.asarray(pts, dtype=float)
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    t = np.arange(0, s[-1], step)
    x, z = np.interp(t, s, p[:, 0]), np.interp(t, s, p[:, 1])
    tx, tz = np.gradient(x), np.gradient(z)
    n = np.hypot(tx, tz) + 1e-9
    return x - tz / n * offset, z + tx / n * offset, np.arctan2(tz, tx)


def hollow_masks(gx, gz):
    floor = np.zeros(gx.shape)
    inside = np.zeros(gx.shape, bool)
    for ho in L.HOLLOWS.values():
        cx, cz = ho["c"]
        ang = np.arctan2(gz - cz, gx - cx)
        d = np.hypot(gx - cx, gz - cz)
        floor = np.maximum(floor, smoothstep(L.hollow_radius(ho, ang, ho["floor_r"]) + 0.5, L.hollow_radius(ho, ang, ho["floor_r"]) - 0.5, d))
        inside |= d < L.hollow_radius(ho, ang, ho["rim_r"])
    return floor, inside


def paint_ground(out):
    rng = np.random.default_rng(31)
    F = Field(2048, 2048, L.FLOOR_X, L.FLOOR_Z)
    gx, gz = F.gx, F.gz
    c = Canvas(F.w, F.h, SEDGE, seed=31)
    h = L.height(gx, gz)
    dz, dx = np.gradient(h, 1.0 / F.sz, 1.0 / F.sx)
    slope = np.hypot(dx, dz)
    path_d = L.path_distance(gx, gz)
    river_d = L.river_distance(gx, gz)
    seam_d = L.seam_distance(gx, gz)
    safe = L.safe_mask(gx, gz).astype(float)
    floor, in_hollow = hollow_masks(gx, gz)
    ones = np.ones((F.h, F.w))

    c.wash(ones, SEDGE, variation=0.05, blotch=130, hue_shift=SEDGE_OCHRE)
    c.wash(np.clip(soft_noise((F.h, F.w), 260, rng) * 1.6, 0, 1), SEDGE_DEEP, variation=0.04, blotch=90)
    c.wash(floor * (1 - safe), MEADOW, variation=0.06, blotch=60, edge_noise=6)
    knoll = smoothstep(L.KNOLL_TOP_R + 0.6, L.KNOLL_TOP_R - 0.4, np.hypot(gx - L.KNOLL_C[0], gz - L.KNOLL_C[1]))
    c.wash(knoll, KNOLL, variation=0.05, blotch=50, edge_noise=4)

    bank = smoothstep(L.RIVER_HALF + L.RIVER_BANK + 1.6, L.RIVER_HALF + L.RIVER_BANK + 0.3, river_d)
    c.wash(bank, BANK, variation=0.05, blotch=50, edge_noise=5)
    bed = smoothstep(L.RIVER_HALF + 1.0, L.RIVER_HALF - 0.4, river_d)
    c.wash(bed, BED, variation=0.06, blotch=40, edge_noise=4)

    earth = smoothstep(0.35, 0.7, slope) * in_hollow
    c.wash(earth, EARTH, variation=0.05, blotch=40, edge_noise=3)
    rock = smoothstep(0.75, 1.2, slope)
    c.wash(rock, ROCK, variation=0.06, blotch=60, edge_noise=4, hue_shift=ROCK_OCHRE)
    dry = smoothstep(L.SEAM_FLOOR_HALF + 0.9, L.SEAM_FLOOR_HALF - 0.2, seam_d) * (h < 0.0)
    c.wash(dry, DRY_BED, variation=0.07, blotch=30, edge_noise=4)

    path = smoothstep(L.PATH_HALF + 0.25, L.PATH_HALF - 0.25, path_d) * (1.0 - bed) * (1 - in_hollow)
    c.wash(path, PATH_SAND, variation=0.04, blotch=40, edge_noise=4)
    cw = np.zeros_like(path)
    for key, cwy in L.CAUSEWAYS.items():
        d, _ = L.polyline_distance(gx, gz, cwy["pts"])
        cw = np.maximum(cw, smoothstep(cwy["half"] + 0.1, cwy["half"] - 0.35, d))
    c.wash(cw, CAUSEWAY, variation=0.04, blotch=30, edge_noise=3)
    for (ix, iz), r in L.ISLANDS.values():
        d = np.hypot(gx - ix, gz - iz)
        c.wash(smoothstep(r + 0.2, r - 0.4, d) * smoothstep(r - 1.6, r - 0.9, d), CAUSEWAY, variation=0.04, blotch=20, edge_noise=3)

    # dark ragged contact band at the foot of every cliff
    steep = slope > 1.0
    near_steep = ndimage.binary_dilation(steep, iterations=7) & ~steep
    low_side = h < ndimage.grey_dilation(h, size=(15, 15)) - 1.2
    foot = ndimage.gaussian_filter((near_steep & low_side).astype(float), 1.6)
    foot = np.clip(foot * 2.2 + soft_noise((F.h, F.w), 10, rng) * 0.35, 0, 1) * (1.0 - bed) * (1 - safe)
    c.wash(foot, INK_GROUND, variation=0.0, blotch=20)

    def ticks_along(pts, offset, step, skip, length, width, alpha, jitter=0.12, test=None):
        for side in (-1, 1):
            ex, ez, ang = offset_polyline(pts, side * offset, step)
            for x, z, a in zip(ex, ez, ang):
                if rng.random() < skip or (test is not None and not test(x, z)):
                    continue
                u, v = F.to_px(x + rng.normal() * jitter, z + rng.normal() * jitter)
                ln = length[0] + rng.random() ** 2 * (length[1] - length[0])
                c.tick(u, v, ln, a + (rng.random() - 0.5) * 0.7 + (math.pi if rng.random() < 0.5 else 0), width[0] + rng.random() * (width[1] - width[0]), INK_GROUND, alpha)

    def on_plain(x, z):
        return L.river_distance(x, z) > L.RIVER_HALF + 1.0 and L.seam_distance(x, z) > L.SEAM_TOP_HALF

    for pts in L.PATHS.values():
        ticks_along(pts, L.PATH_HALF + 0.1, 0.75, 0.55, (6, 30), (2.2, 5.0), 0.9, test=on_plain)
    for cwy in L.CAUSEWAYS.values():
        ticks_along(cwy["pts"], cwy["half"] - 0.05, 0.6, 0.3, (8, 22), (3.0, 6.0), 0.95)
    for (ix, iz), r in L.ISLANDS.values():
        for k in range(26):
            a = 2 * math.pi * k / 26 + rng.random() * 0.2
            u, v = F.to_px(ix + math.cos(a) * (r - 0.1), iz + math.sin(a) * (r - 0.1))
            c.tick(u, v, 10 + rng.random() * 14, a + math.pi / 2 + (rng.random() - 0.5) * 0.5, 3 + rng.random() * 3, INK_GROUND, 0.9)
    ticks_along(L.RIVER, L.RIVER_HALF + L.RIVER_BANK + 0.9, 1.6, 0.4, (12, 26), (2.6, 4.4), 0.8,
                test=lambda x, z: L.FLOOR_X[0] < x < L.FLOOR_X[1])

    # long deliberate cracks down every rock face, following the fall line, some forked
    ys, xs = np.nonzero(slope > 1.3)
    placed = []
    for k in rng.permutation(len(xs)):
        if len(placed) >= 150:
            break
        u, v = int(xs[k]), int(ys[k])
        if any((u - pu) ** 2 + (v - pv) ** 2 < 30 ** 2 for pu, pv in placed):
            continue
        placed.append((u, v))
        pts = [(float(u), float(v))]
        wander = (rng.random() - 0.5) * 0.4
        for _ in range(7):
            cu, cv = int(min(F.w - 1, max(0, pts[-1][0]))), int(min(F.h - 1, max(0, pts[-1][1])))
            if slope[cv, cu] < 0.8:
                break
            a = math.atan2(dz[cv, cu] * F.sz, dx[cv, cu] * F.sx) + math.pi + wander + (rng.random() - 0.5) * 0.35
            seg = 8 + rng.random() * 8
            pts.append((pts[-1][0] + math.cos(a) * seg, pts[-1][1] + math.sin(a) * seg))
        if len(pts) < 3:
            continue
        width = 4.0 + rng.random() * 4.5
        c.stroke(pts, width, INK_GROUND, 0.92, taper=(0.12, 0.7), dry=0.3)
        if rng.random() < 0.4 and len(pts) > 3:
            j = 1 + int(rng.random() * (len(pts) - 2))
            a = math.atan2(pts[j + 1][1] - pts[j][1], pts[j + 1][0] - pts[j][0]) + (0.5 if rng.random() < 0.5 else -0.5)
            fork = [pts[j]] + [(pts[j][0] + math.cos(a) * 10 * i, pts[j][1] + math.sin(a) * 10 * i) for i in (1, 2, 3)]
            c.stroke(fork, width * 0.6, INK_GROUND, 0.88, taper=(0.1, 0.8), dry=0.35)

    # the Seam's dry bed: pebbles and a few streaks along the old flow
    for x in np.arange(L.SEAM_ENDS[0] + 2, L.SEAM_ENDS[1] - 2, 0.9):
        zc = L.seam_center_z(x)
        for _ in range(2):
            px_, pz_ = x + rng.normal() * 0.4, zc + rng.normal() * 0.8
            u, v = F.to_px(px_, pz_)
            r = 2.0 + rng.random() * 3.0
            c.stroke([(u - r, v), (u + r * 0.2, v - r * 0.5), (u + r, v)], 2.2 + rng.random() * 2, mix(INK_GROUND, DRY_BED, 0.3), 0.75, taper=(0.3, 0.4), dry=0.2)
    ex, ez, ang = offset_polyline(L.SEAM, 0.0, 6.0)
    for x, z, a in zip(ex, ez, ang):
        if not (L.SEAM_ENDS[0] + 3 < x < L.SEAM_ENDS[1] - 3) or rng.random() < 0.5:
            continue
        u, v = F.to_px(x, z + rng.normal() * 0.5)
        ln = 30 + rng.random() * 40
        c.stroke([(u, v), (u + math.cos(a) * ln * 0.5, v + math.sin(a) * ln * 0.5 + rng.normal() * 2), (u + math.cos(a) * ln, v + math.sin(a) * ln)],
                 1.8 + rng.random() * 1.6, INK_GROUND, 0.6, taper=(0.1, 0.6), dry=0.6)

    # sedge tufts on open ground, leaning east with the wind
    open_ground = (rock < 0.2) & (path < 0.1) & (bank < 0.1) & (bed < 0.1) & (cw < 0.1) & (h < 6)
    ys, xs = np.nonzero(open_ground)
    # Few, small and light: seen at a low angle the texture squashes each tuft into a smear, and
    # the 3D sedge already stands on this ground.
    for k in rng.choice(len(xs), size=min(len(xs), 220), replace=False):
        colour = mix(INK_GROUND, SEDGE, 0.45) if rng.random() < 0.6 else hex_rgb("4d5a3c")
        for _ in range(1 + int(rng.random() * 3)):
            u, v = xs[k] + rng.normal() * 6, ys[k] + rng.normal() * 4
            c.tuft(u, v, 5 + rng.random() * 5, colour, 0.35 + 0.15 * rng.random(), blades=3 + int(rng.random() * 2),
                   up=-math.pi / 2 + 0.35 + (rng.random() - 0.5) * 0.4, spread=0.8)

    # contact strokes where stones, posts and the camp stand
    for model, x, y, z, yaw, s in L.props():
        if not (L.FLOOR_X[0] < x < L.FLOOR_X[1] and L.FLOOR_Z[0] < z < L.FLOOR_Z[1]):
            continue
        if model.startswith("stone"):
            r0 = (0.75 if model != "stone_fallen" else 1.4) * s
        elif model in ("tie_post", "tamsin_camp"):
            r0 = 0.45 if model == "tie_post" else 1.6
        else:
            continue
        for k in range(4):
            a0 = rng.random() * 2 * math.pi
            r = r0 + rng.random() * 0.3
            pts = [F.to_px(x + math.cos(a0 + t) * r, z + math.sin(a0 + t) * r * 0.9) for t in np.linspace(0, 1.5, 6)]
            c.stroke(pts, 3 + rng.random() * 2, INK, 0.6, taper=(0.15, 0.5), dry=0.35)
    c.soften(0.6)
    c.save(out)


def paint_hills(out):
    rng = np.random.default_rng(37)
    F = Field(1024, 1024, L.OUTER_X, L.OUTER_Z)
    gx, gz = F.gx, F.gz
    c = Canvas(F.w, F.h, SEDGE, seed=37)
    h = L.height(gx, gz)
    dz, dx = np.gradient(h, 1.0 / F.sz, 1.0 / F.sx)
    slope = np.hypot(dx, dz)
    c.wash(np.ones((F.h, F.w)), SEDGE, variation=0.05, blotch=60, hue_shift=SEDGE_OCHRE)
    river_d = L.river_distance(gx, gz)
    c.wash(smoothstep(L.RIVER_HALF + L.RIVER_BANK + 3, L.RIVER_HALF + L.RIVER_BANK, river_d), BANK, variation=0.04, blotch=30)
    rock = smoothstep(0.6, 1.0, slope)
    c.wash(rock, ROCK, variation=0.07, blotch=40, edge_noise=3, hue_shift=ROCK_OCHRE)
    high = smoothstep(18, 30, h) * (1 - rock)
    c.wash(high, hex_rgb("a7a688"), variation=0.05, blotch=40)
    ys, xs = np.nonzero(slope > 1.0)
    for k in rng.choice(len(xs), size=min(len(xs), 120), replace=False):
        u, v = float(xs[k]), float(ys[k])
        a = math.atan2(dz[ys[k], xs[k]] * F.sz, dx[ys[k], xs[k]] * F.sx) + math.pi
        pts = [(u, v), (u + math.cos(a) * 9, v + math.sin(a) * 9), (u + math.cos(a + 0.3) * 18, v + math.sin(a + 0.3) * 18)]
        c.stroke(pts, 3 + rng.random() * 3, INK_GROUND, 0.85, taper=(0.1, 0.7), dry=0.35)
    ys, xs = np.nonzero((slope < 0.4) & (h < 20))
    for k in rng.choice(len(xs), size=min(len(xs), 160), replace=False):
        c.tuft(xs[k], ys[k], 6 + rng.random() * 4, INK_GROUND, 0.6, blades=3, up=-math.pi / 2 + 0.35)
    # pale ridge wash in the bottom strip (the ridge silhouettes map here)
    ridge = np.zeros((F.h, F.w))
    ridge[int(F.h * 0.9):, :] = 1
    c.wash(ridge, hex_rgb("c9cec4"), variation=0.035, blotch=40, hue_shift=hex_rgb("d9d6c6"))
    for _ in range(40):
        x, y = rng.random() * F.w, F.h * 0.9 + 6 + rng.random() * 40
        a = math.pi / 2 + (rng.random() - 0.5) * 1.2
        c.stroke([(x, y), (x + math.cos(a) * 14, y + math.sin(a) * 14), (x + math.cos(a + 0.3) * 26, y + math.sin(a + 0.3) * 26)],
                 1.6 + rng.random() * 1.2, hex_rgb("8f948d"), 0.6, taper=(0.1, 0.6), dry=0.5)
    c.soften(0.5)
    c.save(out)


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    paint_ground(str(out / "ground.png"))
    print("TEXTURE ground 2048x2048")
    paint_hills(str(out / "hills.png"))
    print("TEXTURE hills 1024x1024")


if __name__ == "__main__":
    main(sys.argv[1])
