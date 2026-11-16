"""Top-down plan of Mosswater Wood, drawn to scale from mw_layout.py (the same data the terrain
script uses), plus a side elevation up the slope.

    python tools/levels/mosswater/plan.py <out_dir>

Writes <out_dir>/plan.jpg (10 px per metre, 1 m contours, every marker) and <out_dir>/elevation.jpg.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import mw_layout as L  # noqa: E402

PX = 10                 # pixels per metre
EXT = 50.0              # plan covers x, z in [-50, 50]
MARGIN = 60
SIZE = int(2 * EXT * PX)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def to_px(x, z):
    return (MARGIN + (x + EXT) * PX, MARGIN + (z + EXT) * PX)


def st_px(s, t):
    return to_px(*L.st_xz(s, t))


def main(out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    xs = (np.arange(SIZE) + 0.5) / PX - EXT
    gx, gz = np.meshgrid(xs, xs)
    h = L.height(gx, gz)
    s, t = L.xz_st(gx, gz)

    # tint by height band, hillshade from the upper left, ponds black-indigo
    base = np.zeros((SIZE, SIZE, 3))
    band0, band1, band2 = np.array([0.80, 0.82, 0.70]), np.array([0.72, 0.77, 0.64]), np.array([0.64, 0.71, 0.58])
    w1 = L.smoothstep(3.0, 5.0, h)
    w2 = L.smoothstep(9.0, 11.0, h)
    base[:] = band0
    base = base * (1 - w1[..., None]) + band1 * w1[..., None]
    base = base * (1 - w2[..., None]) + band2 * w2[..., None]
    bank = L.smoothstep(15.0, 22.0, h - np.where(h > 0, 0, 0))
    dy, dx = np.gradient(h, 1.0 / PX)
    shade = np.clip(1.0 + (-dx * -0.7 + -dy * -0.7) * 0.18, 0.55, 1.25)
    img = base * shade[..., None]
    steep = np.hypot(dx, dy)
    img = img * (1 - 0.35 * L.smoothstep(1.2, 3.0, steep)[..., None])
    path = L.smoothstep(L.PATH_HALF + 0.2, L.PATH_HALF - 0.3, L.path_distance(s, t))
    img = img * (1 - path[..., None]) + np.array([0.93, 0.88, 0.74]) * path[..., None]
    water = np.zeros((SIZE, SIZE))
    for name, p in L.PONDS.items():
        water = np.maximum(water, (h < p["water"]) & (np.abs(h - p["water"]) < 3.0) & (L.pond_e(s, t, name) < 1.3))
    water = np.maximum(water, (L.polyline_distance(s, t, L.CHANNEL) < 1.6) & (h < 0.7))
    water = np.maximum(water, (s < L.RIVER_S + 3.0) & (h < L.RIVER_WATER_Y))
    sp = np.hypot(s - L.SPRING["c"][0], t - L.SPRING["c"][1]) < L.SPRING["r"]
    water = np.maximum(water, sp)
    img = img * (1 - water[..., None]) + np.array([0.20, 0.22, 0.30]) * water[..., None]
    outside = (np.abs(gx) > L.SQUARE) | (np.abs(gz) > L.SQUARE)
    img[outside] = img[outside] * 0.55 + np.array([0.93, 0.9, 0.84]) * 0.45
    # contours: thin every metre, heavy every 3 m
    for step, dark in ((1.0, 0.86), (3.0, 0.6)):
        q = np.floor(h / step)
        edge = (np.roll(q, 1, 0) != q) | (np.roll(q, 1, 1) != q)
        img[edge & ~water.astype(bool)] *= dark
    canvas = Image.new("RGB", (SIZE + 2 * MARGIN + 380, SIZE + 2 * MARGIN), (240, 234, 220))
    canvas.paste(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)), (MARGIN, MARGIN))
    d = ImageDraw.Draw(canvas)
    f12, f14, f18, f24 = font(12), font(14), font(18), font(24)

    # grid and coordinates
    for v in range(-50, 51, 10):
        a = to_px(v, -EXT)
        b = to_px(v, EXT)
        d.line([a, b], fill=(120, 110, 95), width=1)
        d.text((a[0] - 10, MARGIN - 20), "%d" % v, fill=(60, 50, 40), font=f12)
        a = to_px(-EXT, v)
        b = to_px(EXT, v)
        d.line([a, b], fill=(120, 110, 95), width=1)
        d.text((MARGIN - 34, a[1] - 7), "%d" % v, fill=(60, 50, 40), font=f12)
    sq = [to_px(-L.SQUARE, -L.SQUARE), to_px(L.SQUARE, L.SQUARE)]
    d.rectangle(sq, outline=(40, 35, 30), width=2)

    # trees
    for tr in L.trees():
        x, _, z = tr["pos"]
        if abs(x) > EXT or abs(z) > EXT:
            continue
        r = (0.55 if tr["model"] != "trunk_snag" else 0.45) * tr["scale"] * PX
        cx, cy = to_px(x, z)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(28, 26, 30))
    # stair tree, shelves, gully pieces
    cx, cy = st_px(*L.STAIR_TREE)
    r = L.STAIR_RADIUS * PX
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(28, 26, 30), outline=(200, 160, 60), width=2)
    for k, sh in enumerate(L.stair_shelves()):
        px_ = to_px(sh["pos"][0], sh["pos"][2])
        d.ellipse([px_[0] - 6, px_[1] - 6, px_[0] + 6, px_[1] + 6], fill=(200, 160, 60), outline=(40, 30, 20))
        d.text((px_[0] + 7, px_[1] - 6), "%.0f" % sh["top"], fill=(40, 30, 20), font=f12)
    for g in L.gully_pieces():
        px_ = to_px(g["pos"][0], g["pos"][2])
        col = (90, 140, 70) if g["kind"] == "moss_shelf" else (150, 140, 120)
        d.rectangle([px_[0] - 7, px_[1] - 7, px_[0] + 7, px_[1] + 7], fill=col, outline=(30, 30, 30))
        d.text((px_[0] + 8, px_[1] - 7), "%s %.0f" % (g["id"], g["top"]), fill=(20, 20, 20), font=f12)

    # route arrows
    for name, pts in L.PATHS.items():
        pp = [st_px(a, b) for a, b in pts]
        d.line(pp, fill=(150, 110, 50), width=2)
    # fights
    for ft in L.fights():
        cx, cy = to_px(ft["center"][0], ft["center"][2])
        r = ft["radius"] * PX
        col = (180, 30, 40) if ft["kind"] == "sealed" else (200, 90, 60)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=3 if ft["kind"] == "sealed" else 2)
        for kind, p in ft.get("enemies", []) + sum(ft.get("waves", []), []):
            ex, ey = to_px(p[0], p[2])
            letter = {"splotchet": "s", "sootflit": "f", "reedwraith": "R"}[kind]
            d.text((ex - 3, ey - 7), letter, fill=col, font=f14)
    # curse zones (ponds)
    for z in L.curse_zones():
        cx, cy = to_px(z["center"][0], z["center"][2])
        r = z["radius"] * PX
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(120, 40, 50), width=1)
    # lanterns
    for lf in L.lanterns():
        cx, cy = to_px(lf["pos"][0], lf["pos"][2])
        fill = (240, 190, 60) if lf["lit"] else (210, 160, 40)
        d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=fill, outline=(60, 40, 10), width=2)
        d.text((cx + 6, cy + 1), lf["id"], fill=(110, 80, 10), font=f12)
    # markers
    m = L.build_markers()
    skip = {"M_PondLow", "M_PondMid", "M_PondHigh"}
    for name, (x, y, z) in m.items():
        if name in skip:
            continue
        cx, cy = to_px(x, z)
        d.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)], fill=(213, 64, 43), outline=(30, 20, 20))
        d.text((cx + 7, cy - 14), name[2:], fill=(20, 15, 15), font=f12)
    for name, p in L.PONDS.items():
        cx, cy = st_px(*p["c"])
        label = "%s  water %.2f" % (p["name"], p["water"])
        w = d.textlength(label, font=f18)
        d.text((cx - w / 2, cy + 18), label, fill=(235, 230, 215), font=f18)
    # beat numbers
    beats = [(1, (-44.0, -4.0)), (2, (-30.0, 6.0)), (3, (-1.0, -9.0)), (4, (14.0, -12.0)), (5, (36.0, 6.0))]
    for n, (bs, bt) in beats:
        cx, cy = st_px(bs, bt)
        d.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=(30, 28, 30), outline=(240, 234, 220), width=2)
        d.text((cx - 5, cy - 12), str(n), fill=(240, 234, 220), font=f24)

    # scale bar, north, legend
    sx, sy = MARGIN + 20, MARGIN + SIZE - 40
    d.rectangle([sx, sy, sx + 10 * PX, sy + 8], fill=(20, 20, 20))
    d.rectangle([sx + 10 * PX, sy, sx + 20 * PX, sy + 8], fill=(240, 234, 220), outline=(20, 20, 20))
    d.text((sx, sy + 10), "0          10         20 m", fill=(20, 20, 20), font=f14)
    nx, ny = MARGIN + SIZE - 40, MARGIN + 40
    d.polygon([(nx, ny - 26), (nx - 10, ny + 4), (nx + 10, ny + 4)], fill=(20, 20, 20))
    d.text((nx - 6, ny + 6), "N", fill=(20, 20, 20), font=f18)
    lx, ly = MARGIN + SIZE + 30, MARGIN
    lines = [
        ("Mosswater Wood: plan", f24),
        ("Godot metres. X east, Z south.", f14),
        ("Grid every 10 m. 1 m contours,", f14),
        ("heavy every 3 m. 10 px = 1 m.", f14),
        ("", f14),
        ("Tier 0  ground ~1.1  (pond 0.55)", f14),
        ("Tier 1  ground  7.0  (pond 6.55)", f14),
        ("Tier 2  ground 13.0  (pond 12.55)", f14),
        ("", f14),
        ("red diamond   marker M_*", f14),
        ("gold dot      lantern-fruit LFnn", f14),
        ("gold ring     fungus shelf (top y)", f14),
        ("square        gully ledge / moss", f14),
        ("               shelf (top y)", f14),
        ("black dot     tall trunk", f14),
        ("brown line    walked path", f14),
        ("red circle    fight (heavy = sealed)", f14),
        ("  s Splotchet  f Sootflit", f14),
        ("  R Reedwraith", f14),
        ("thin circle   pond curse zone", f14),
        ("numbered disc beat 1..5", f14),
        ("pale frame    the 90 x 90 m square", f14),
    ]
    for text, fnt in lines:
        d.text((lx, ly), text, fill=(30, 25, 20), font=fnt)
        ly += 30 if fnt is f24 else 20
    canvas.save(str(out / "plan.jpg"), quality=88)

    # elevation along the slope (t = 0 and t = -10), s from the river to the spring
    W, H = 1400, 420
    el = Image.new("RGB", (W, H), (240, 234, 220))
    de = ImageDraw.Draw(el)
    ss = np.linspace(-60, 50, 1100)
    def sx_(sv):
        return 60 + (sv + 60) / 110 * (W - 100)
    def sy_(yv):
        return H - 60 - (yv + 2) * 16
    for yv in range(0, 25, 3):
        de.line([(60, sy_(yv)), (W - 40, sy_(yv))], fill=(200, 190, 170))
        de.text((20, sy_(yv) - 7), "%d" % yv, fill=(60, 50, 40), font=f12)
    for tv, col in ((2.0, (40, 35, 30)), (-10.0, (150, 120, 70))):
        hh = L.height_st(ss, np.full_like(ss, tv))
        de.line([(sx_(a), sy_(b)) for a, b in zip(ss, hh)], fill=col, width=3)
    for name, p in L.PONDS.items():
        a, b = p["c"][0] - p["r"][0], p["c"][0] + p["r"][0]
        de.line([(sx_(a), sy_(p["water"])), (sx_(b), sy_(p["water"]))], fill=(40, 60, 110), width=4)
        de.text((sx_(p["c"][0]) - 30, sy_(p["water"]) + 8), p["name"], fill=(40, 60, 110), font=f14)
    for sv in range(-60, 51, 10):
        de.text((sx_(sv) - 8, H - 40), "%d" % sv, fill=(60, 50, 40), font=f12)
    de.text((60, 12), "Elevation up the slope: s (m, south-east to north-west) against height (m). Black t = 2 (the ponds' line), brown t = -10 (the walked side).", fill=(30, 25, 20), font=f14)
    el.save(str(out / "elevation.jpg"), quality=88)
    print("PLAN", (out / "plan.jpg").as_posix().split("docs/")[-1], (out / "elevation.jpg").as_posix().split("docs/")[-1])


if __name__ == "__main__":
    main(sys.argv[1])
