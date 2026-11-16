"""Painted ground for Tallowford: the 2K village floor and the 1K hills/ridges texture.

    python tools/levels/tallowford/paint_terrain.py <out_dir>

tallowford_ground.png (2048 x 2048) maps top-down over the floor rectangle in layout.py (about
24 px per metre across, 28 down): sage-olive grass with ochre drift, sandy paths with ragged ink
ticks along both edges, the paved square, jetty square and well yard as pale stone flags with
broken ink joints, the dye yard's beaten earth with indigo, madder and weld stains, a dark ragged
contact band under every building, the river bed and banks, rock on steep slopes, ploughed strokes
in the southern fields and scattered grass-tuft ticks.
tallowford_hills.png (1024 x 1024): grass slopes with shrub bands and a few rock strokes (upper
part, wrapped round the bowl four times), and a pale ridge wash along the bottom strip.
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
from inkpaint import INK, INK_BROWN, Canvas, hex_rgb, mix, smoothstep  # noqa: E402

W = H = 2048
X0, X1 = L.FLOOR_X
Z0, Z1 = L.FLOOR_Z
SX, SZ = W / (X1 - X0), H / (Z1 - Z0)

GRASS = hex_rgb("98a078")
GRASS_OCHRE = hex_rgb("aaa074")
FIELD = hex_rgb("a49c72")
PATH_SAND = hex_rgb("d3c49c")
STONE_FLAG = hex_rgb("bdb6a4")
STONE_FLAG_2 = hex_rgb("aaa391")
EARTH = hex_rgb("b5a07c")
BANK = hex_rgb("c4b994")
BED = hex_rgb("7b8682")
ROCK = hex_rgb("8d8a80")
INK_GROUND = mix(INK, hex_rgb("3a3a2a"), 0.35)
JOINT = mix(INK_BROWN, hex_rgb("6b6050"), 0.4)


def to_px(x, z):
    return ((x - X0) * SX, (z - Z0) * SZ)


def house_masks(gx, gz):
    """Footprint masks of every building (houses, cottages, sheds), in metres from the wall."""
    dist = np.full(gx.shape, np.inf)
    blocks = [(c, w, d, t) for _, c, w, d, t, _ in L.HOUSES] + [(c, w, d, t) for _, c, w, d, t in L.COTTAGES + L.SHEDS]
    for c, w, d, target in blocks:
        yaw = math.radians(L.face_yaw(c, target))
        right = (math.cos(yaw), -math.sin(yaw))
        fwd = (-math.sin(yaw), -math.cos(yaw))
        rx = (gx - c[0]) * right[0] + (gz - c[1]) * right[1]
        rz = (gx - c[0]) * fwd[0] + (gz - c[1]) * fwd[1]
        hw, hd = w / 2 + 0.35, d / 2 + 0.35          # plinth edge
        ox, oz = np.abs(rx) - hw, np.abs(rz) - hd
        outside = np.hypot(np.maximum(ox, 0), np.maximum(oz, 0)) + np.minimum(np.maximum(ox, oz), 0)
        dist = np.minimum(dist, outside)
    return dist


def paint_ground(out):
    rng = np.random.default_rng(12)
    c = Canvas(W, H, GRASS, seed=12)
    px = (np.arange(W) + 0.5) / SX + X0
    pz = (np.arange(H) + 0.5) / SZ + Z0
    gx, gz = np.meshgrid(px, pz)
    h = L.height(gx, gz)
    dz, dx = np.gradient(h, 1.0 / SZ, 1.0 / SX)
    slope = np.hypot(dx, dz)
    pathd = L.path_distance(gx, gz)
    river_d = L.river_distance(gx, gz)
    bld = house_masks(gx, gz)
    ones = np.ones((H, W))

    c.wash(ones, GRASS, variation=0.05, blotch=150, hue_shift=GRASS_OCHRE)
    fields = smoothstep(21.0, 24.0, gz) * smoothstep(26.0, 20.0, gx) * smoothstep(-0.5, 2.0, pathd)
    c.wash(fields, FIELD, variation=0.05, blotch=90, edge_noise=8)

    bank = smoothstep(L.RIVER_HALF + L.RIVER_BANK + 1.6, L.RIVER_HALF + L.RIVER_BANK + 0.3, river_d)
    c.wash(bank, BANK, variation=0.05, blotch=60, edge_noise=6)
    bed = smoothstep(L.RIVER_HALF + 1.0, L.RIVER_HALF - 0.4, river_d)
    c.wash(bed, BED, variation=0.06, blotch=50, edge_noise=5)
    rock = smoothstep(1.35, 1.9, slope) * (river_d > L.RIVER_HALF + 1.0)
    c.wash(rock, ROCK, variation=0.06, blotch=60, edge_noise=4)

    # beaten earth under the eaves and in the dye yard
    eaves = smoothstep(1.4, 0.4, bld)
    c.wash(eaves, mix(EARTH, GRASS, 0.35), variation=0.05, blotch=40, edge_noise=6)
    dye = smoothstep(L.DYE_YARD_R + 0.5, L.DYE_YARD_R - 1.0, np.hypot(gx - L.DYE_YARD_C[0], gz - L.DYE_YARD_C[1]))
    c.wash(dye, EARTH, variation=0.06, blotch=60, edge_noise=10)
    vx, vz = L.MARKERS["M_DyeVats"]
    for col, n in ((hex_rgb("5d6a7e"), 3), (hex_rgb("9c6a5c"), 2), (hex_rgb("b8a466"), 2)):
        m = np.zeros((H, W))
        for _ in range(n):
            a, r = rng.random() * 6.28, rng.uniform(0.5, 3.5)
            cx, cz = vx + math.cos(a) * r, vz + math.sin(a) * r
            rad = rng.uniform(1.2, 2.4)
            m = np.maximum(m, smoothstep(rad, rad * 0.2, np.hypot(gx - cx, gz - cz)))
        c.wash(m * dye * 0.28, col, variation=0.12, blotch=30, edge_noise=12)

    # paths
    path = smoothstep(0.15, -0.15, pathd)
    c.wash(path, PATH_SAND, variation=0.05, blotch=50, edge_noise=4)

    # paved places: pale flags
    paved = []
    for (cx, cz), r in ((L.SQUARE_C, L.SQUARE_R), (L.JETTY_SQ_C, L.JETTY_SQ_R), (L.WELL_C, L.WELL_YARD_R)):
        dd = np.hypot(gx - cx, gz - cz)
        m = smoothstep(r + 0.15, r - 0.15, dd)
        c.wash(m, STONE_FLAG, variation=0.05, blotch=40, edge_noise=4, hue_shift=STONE_FLAG_2)
        paved.append((cx, cz, r))
    c.soften(0.4)

    # ------------------------------------------------------------- ink
    # flag joints: broken rings and radial joints, as a few loose strokes
    for cx, cz, r in paved:
        ring = 1.4
        while ring < r - 0.3:
            n = max(6, int(2 * math.pi * ring / 1.6))
            a0 = rng.random() * 6.28
            for k in range(n):
                if rng.random() < 0.3:
                    continue
                a = a0 + 2 * math.pi * k / n
                a1 = a + 2 * math.pi / n * rng.uniform(0.6, 0.95)
                pts = [to_px(cx + math.cos(t) * ring, cz + math.sin(t) * ring) for t in np.linspace(a, a1, 5)]
                c.stroke(pts, 2.4, JOINT, 0.55, taper=(0.2, 0.4), dry=0.45, pressure=0.3)
                r0, r1 = ring, min(ring + 1.4, r - 0.2)
                if r1 > r0 + 0.3 and rng.random() < 0.7:
                    c.stroke([to_px(cx + math.cos(a) * r0, cz + math.sin(a) * r0), to_px(cx + math.cos(a) * r1, cz + math.sin(a) * r1)],
                             2.2, JOINT, 0.5, taper=(0.2, 0.4), dry=0.5, pressure=0.3)
            ring += 1.4
        # a ragged rim stroke round the paving, broken in places
        for k in range(14):
            a = 2 * math.pi * k / 14 + rng.random() * 0.2
            if rng.random() < 0.25:
                continue
            pts = [to_px(cx + math.cos(t) * (r + 0.1), cz + math.sin(t) * (r + 0.1)) for t in np.linspace(a, a + 2 * math.pi / 14 * 0.85, 6)]
            c.stroke(pts, 5.0, INK_GROUND, 0.8, taper=(0.15, 0.5), dry=0.4)

    # path edges: ragged ticks along both sides
    for _, pts, hw in L.PATHS:
        p = np.asarray(pts, dtype=float)
        seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
        s = np.concatenate([[0], np.cumsum(seg)])
        for t in np.arange(0.3, s[-1], 0.55):
            x, z = np.interp(t, s, p[:, 0]), np.interp(t, s, p[:, 1])
            k = min(np.searchsorted(s, t) - 1, len(p) - 2)
            tx, tz = (p[k + 1] - p[k]) / max(seg[k], 1e-6)
            for side in (-1, 1):
                if rng.random() < 0.45:
                    continue
                off = hw + rng.uniform(-0.1, 0.25)
                ex, ez = x - tz * off * side, z + tx * off * side
                X, Z = to_px(ex, ez)
                ang = math.atan2(tz * SZ, tx * SX) + rng.normal() * 0.25
                c.tick(X, Z, rng.uniform(10, 22), ang, rng.uniform(3, 5.5), INK_GROUND, 0.75)

    # contact band under every building: a dark ragged stroke along each wall foot
    blocks = [(c_, w, d, t) for _, c_, w, d, t, _ in L.HOUSES] + [(c_, w, d, t) for _, c_, w, d, t in L.COTTAGES + L.SHEDS]
    for cc, w, d, target in blocks:
        yaw = L.face_yaw(cc, target)
        hw, hd = w / 2 + 0.4, d / 2 + 0.4
        corners = [L.local_to_world(cc, yaw, sx * hw, sz * hd) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for a, b in zip(corners, corners[1:] + corners[:1]):
            pts = [to_px(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t) for t in np.linspace(-0.05, 1.05, 6)]
            c.stroke(pts, 9.0, INK_GROUND, 0.85, taper=(0.06, 0.12), dry=0.35, pressure=0.4, edge=0.25)

    # contact strokes under single props (lamp posts, well, vats, persimmon, ford pier)
    for model, x, z, yaw, s in L.props():
        if model not in ("persimmon", "well", "ford_lamp", "shrine"):
            continue
        r = {"persimmon": 0.9, "well": 1.5, "dye_vats": 3.4, "cloth_line": 2.6, "drying_rack": 1.4, "ford_lamp": 1.6, "shrine": 1.0}.get(model, 0.8)
        X, Z = to_px(x, z)
        a0 = rng.random() * 6.28
        pts = [(X + math.cos(a0 + t) * r * SX * 0.9, Z + math.sin(a0 + t) * r * SZ * 0.5) for t in np.linspace(0, 2.6, 7)]
        c.stroke(pts, 6.0, INK_GROUND, 0.55, taper=(0.1, 0.4), dry=0.45)

    # river bank: a broken ink line along the water's edge
    for side in (-1, 1):
        pts = np.array(L.RIVER, dtype=float)
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        s = np.concatenate([[0], np.cumsum(seg)])
        run = []
        for t in np.arange(0, s[-1], 0.8):
            x, z = np.interp(t, s, pts[:, 0]), np.interp(t, s, pts[:, 1])
            k = min(np.searchsorted(s, t) - 1, len(pts) - 2)
            tx, tz = (pts[k + 1] - pts[k]) / max(seg[k], 1e-6)
            off = L.RIVER_HALF + 0.9 + 0.3 * math.sin(t * 0.7)
            ex, ez = x - tz * off * side, z + tx * off * side
            if not (X0 < ex < X1 and Z0 < ez < Z1):
                if len(run) > 3:
                    c.stroke([to_px(*q) for q in run], 6.0, INK_GROUND, 0.7, taper=(0.1, 0.3), dry=0.45)
                run = []
                continue
            run.append((ex, ez))
            if len(run) > 9 + rng.integers(0, 6):
                c.stroke([to_px(*q) for q in run], 6.0, INK_GROUND, 0.7, taper=(0.1, 0.3), dry=0.45)
                run = [] if rng.random() < 0.4 else run[-1:]

    # cracks on steep rock
    ys, xs = np.nonzero(rock[::24, ::24] > 0.5)
    for y, x in zip(ys, xs):
        if rng.random() < 0.5:
            continue
        X, Z = x * 24 + rng.uniform(0, 24), y * 24 + rng.uniform(0, 24)
        a = rng.random() * 6.28
        pts = [(X, Z)]
        for _ in range(3):
            a += rng.normal() * 0.5
            pts.append((pts[-1][0] + math.cos(a) * 14, pts[-1][1] + math.sin(a) * 14))
        c.stroke(pts, 4.0, INK, 0.8, taper=(0.08, 0.6), dry=0.4)

    # ploughed furrows in the southern fields
    for k in range(26):
        z = 23.0 + k * 0.55
        xa, xb = -30.0 + rng.uniform(-1, 1), 16.0 - (z - 23.0) * 0.8 + rng.uniform(-1, 1)
        pts = []
        for x in np.linspace(xa, xb, 18):
            if L.path_distance(x, z) < 0.6:
                if len(pts) > 2:
                    c.stroke(pts, 3.0, mix(INK_GROUND, FIELD, 0.45), 0.5, taper=(0.1, 0.2), dry=0.55)
                pts = []
                continue
            pts.append(to_px(x, z + 0.08 * math.sin(x * 0.4 + k)))
        if len(pts) > 2:
            c.stroke(pts, 3.0, mix(INK_GROUND, FIELD, 0.45), 0.5, taper=(0.1, 0.2), dry=0.55)

    # grass tufts, kept off paths, paving, yards, water and buildings
    paved_any = np.zeros((H, W), bool)
    for cx, cz, r in paved:
        paved_any |= np.hypot(gx - cx, gz - cz) < r + 0.5
    keep = (pathd > 0.6) & ~paved_any & (bld > 1.0) & (river_d > L.RIVER_HALF + L.RIVER_BANK) & (dye < 0.2) & (slope < 0.8)
    tries = 0
    placed = 0
    while placed < 1500 and tries < 9000:
        tries += 1
        X, Z = rng.random() * W, rng.random() * H
        if not keep[int(Z), int(X)]:
            continue
        placed += 1
        c.tuft(X, Z, rng.uniform(9, 16), mix(INK_GROUND, GRASS, 0.25), alpha=0.7, blades=int(rng.integers(2, 4)))
    c.soften(0.5)
    c.save(out)
    print("TEXTURE tallowford_ground %dx%d tufts=%d" % (W, H, placed))


def paint_hills(out):
    S = 1024
    rng = np.random.default_rng(31)
    c = Canvas(S, S, hex_rgb("93a074"), seed=31)
    yy, xx = np.mgrid[0:S, 0:S]
    upper = (yy < S * 0.86).astype(float)
    c.wash(upper, hex_rgb("93a074"), variation=0.06, blotch=120, hue_shift=hex_rgb("a49d72"))
    # darker shrub bands that follow the slope
    for k in range(9):
        y0 = rng.uniform(0.1, 0.8) * S
        band = smoothstep(26, 4, np.abs(yy - y0 - 18 * np.sin(xx / 70.0 + k))) * upper
        c.wash(band * (rng.random() < 0.7), hex_rgb("6f8158"), variation=0.08, blotch=40, edge_noise=10)
    # ridge strip at the bottom: pale distant hills
    strip = (yy >= S * 0.86).astype(float)
    c.wash(strip, hex_rgb("b8bba8"), variation=0.05, blotch=60, hue_shift=hex_rgb("c9c4ad"))
    c.soften(0.5)
    for _ in range(420):
        X, Y = rng.random() * S, rng.random() * S * 0.84
        c.tuft(X, Y, rng.uniform(7, 12), mix(INK_GROUND, hex_rgb("93a074"), 0.3), alpha=0.65, blades=3)
    for _ in range(40):
        X, Y = rng.random() * S, rng.random() * S * 0.8
        a = rng.random() * 6.28
        pts = [(X, Y)]
        for _ in range(3):
            a += rng.normal() * 0.6
            pts.append((pts[-1][0] + math.cos(a) * 16, pts[-1][1] + math.sin(a) * 9))
        c.stroke(pts, 4.0, INK_GROUND, 0.7, taper=(0.08, 0.6), dry=0.45)
    # fans of brush strokes for the scrub on the crests
    for _ in range(140):
        X, Y = rng.random() * S, rng.random() * S * 0.8
        for k in range(4):
            a = -math.pi / 2 + (k - 1.5) * 0.35 + rng.normal() * 0.2
            l = rng.uniform(10, 18)
            c.stroke([(X, Y), (X + math.cos(a) * l * 0.55, Y + math.sin(a) * l * 0.55), (X + math.cos(a + 0.15) * l, Y + math.sin(a + 0.15) * l)],
                     4.5, hex_rgb("4f6a3a"), 0.6, taper=(0.05, 0.7), dry=0.3)
    # a contour stroke along the top of the ridge strip
    pts = [(x, S * 0.86 + 6 * math.sin(x / 40.0)) for x in np.linspace(0, S, 40)]
    c.stroke(pts, 3.0, hex_rgb("6b6863"), 0.6, taper=(0.02, 0.02), dry=0.5)
    c.soften(0.5)
    c.save(out)
    print("TEXTURE tallowford_hills %dx%d" % (S, S))


def main(out_dir):
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    paint_ground(str(Path(out_dir) / "tallowford_ground.png"))
    paint_hills(str(Path(out_dir) / "tallowford_hills.png"))


if __name__ == "__main__":
    main(sys.argv[1])
