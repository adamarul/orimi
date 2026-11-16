"""Painted albedo textures for Mosswater Wood, from the paint maps make_mw.py writes.

    python tools/levels/mosswater/paint_mw.py <model> <paintmap.json> <out_dir>

terrain writes mw_ground.png (2048 x 2048, top-down over x, z in [-66, 66], about 15.5 px per
metre) and mw_cliff.png (1024 x 1024, tiling, side-projected on every steep face). Every other
model writes mw_<model>.png from its paint map: a flat wash per face tag, then the model's ink.
Uses the shared painter (tools/textures/painted/inkpaint.py, paint_models.py), imported only.
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
import mw_layout as L  # noqa: E402
from inkpaint import INK, INK_BROWN, Canvas, hex_rgb, mix, smoothstep, soft_noise  # noqa: E402
import paint_models as PM  # noqa: E402

EXT = 66.0
INK_GROUND = mix(INK, hex_rgb("2c3326"), 0.35)
MOSS = hex_rgb("7d8a5c")
MOSS_DEEP = hex_rgb("687650")
MOSS_HIGH = hex_rgb("8b9867")
LITTER = hex_rgb("958a60")
PEAT = hex_rgb("665c45")
PATH_SAND = hex_rgb("c2b48d")
MUD = hex_rgb("5c5746")
BED = hex_rgb("3f4441")
ROCK = hex_rgb("737569")
CHAR = hex_rgb("4d4b44")


# ----------------------------------------------------------------------------- terrain
def paint_ground(out):
    S = 2048
    sc = S / (2 * EXT)
    rng = np.random.default_rng(31)
    c = Canvas(S, S, MOSS, seed=31)
    px = (np.arange(S) + 0.5) / sc - EXT
    gx, gz = np.meshgrid(px, px)
    h = L.height(gx, gz)
    s, t = L.xz_st(gx, gz)
    dz, dx = np.gradient(h, 1.0 / sc)
    slope = np.hypot(dx, dz)
    ones = np.ones((S, S))

    def to_px(x, z):
        return ((x + EXT) * sc, (z + EXT) * sc)

    c.wash(ones, MOSS, variation=0.06, blotch=150, hue_shift=LITTER)
    tier2 = L.smoothstep(10.5, 12.0, h) * (np.abs(t) < 21)
    c.wash(tier2, MOSS_HIGH, variation=0.05, blotch=90, edge_noise=8)
    banks = L.smoothstep(19.0, 23.0, np.abs(t) - 0.0) + L.smoothstep(46.0, 50.0, s)
    c.wash(np.clip(banks, 0, 1), MOSS_DEEP, variation=0.06, blotch=110, edge_noise=10, hue_shift=PEAT)
    peat = np.clip(soft_noise((S, S), 70, rng) * 1.6 - 0.55, 0, 1) * (1 - tier2 * 0.5)
    c.wash(peat, PEAT, variation=0.05, blotch=60, edge_noise=6)

    # pond basins: mud shore ring, dark bed; channels and runnels stony
    for name, p in L.PONDS.items():
        e = L.pond_e(s, t, name)
        c.wash(L.smoothstep(1.2, 1.05, e), MUD, variation=0.05, blotch=50, edge_noise=6)
        c.wash(L.smoothstep(1.0, 0.92, e), BED, variation=0.05, blotch=40, edge_noise=3)
    chan = L.smoothstep(2.8, 1.6, L.polyline_distance(s, t, L.CHANNEL))
    for pts in L.RUNNELS.values():
        chan = np.maximum(chan, L.smoothstep(1.3, 0.6, L.polyline_distance(s, t, pts)))
    c.wash(chan, hex_rgb("676b63"), variation=0.06, blotch=30, edge_noise=4)
    river = L.smoothstep(L.RIVER_S + 5.0, L.RIVER_S + 3.6, s)
    c.wash(river, hex_rgb("b9ad88"), variation=0.05, blotch=50, edge_noise=6)
    c.wash(L.smoothstep(L.RIVER_S + 3.0, L.RIVER_S + 2.0, s), BED, variation=0.05, blotch=40, edge_noise=3)
    sp = np.hypot(s - L.SPRING["c"][0], t - L.SPRING["c"][1])
    c.wash(L.smoothstep(L.SPRING["r"] * 1.5, L.SPRING["r"] * 1.1, sp), MUD, variation=0.05, blotch=30, edge_noise=3)

    # rock where the ground turns steep (the cliff texture takes the steepest faces)
    rock = L.smoothstep(0.9, 1.5, slope)
    c.wash(rock, ROCK, variation=0.06, blotch=50, edge_noise=4, hue_shift=MOSS_DEEP)

    # Fenn's clearing: charcoal-blackened ground
    fs, ft, fr = L.CLEARINGS[1]
    char = L.smoothstep(fr * 1.1, fr * 0.5, np.hypot(s - fs, t - ft))
    c.wash(char, CHAR, variation=0.07, blotch=30, edge_noise=8)

    # paths: paler, wash stops short, ragged ticks along both edges
    pd = L.path_distance(s, t)
    path = L.smoothstep(L.PATH_HALF + 0.15, L.PATH_HALF - 0.35, pd) * (1 - L.smoothstep(1.0, 1.4, slope))
    c.wash(path, PATH_SAND, variation=0.045, blotch=40, edge_noise=5)

    # dark ragged contact band at every cliff foot; a lip of ticks along every cliff top
    steep = slope > 1.4
    near = ndimage.binary_dilation(steep, iterations=8) & ~steep
    low = h < ndimage.grey_dilation(h, size=(15, 15)) - 1.5
    foot = ndimage.gaussian_filter((near & low).astype(float), 1.8)
    foot = np.clip(foot * 2.4 + soft_noise((S, S), 9, rng) * 0.35, 0, 1)
    c.wash(foot, INK_GROUND, variation=0.0, blotch=20)

    for name, pts in L.PATHS.items():
        for side in (-1, 1):
            for (a0, b0), (a1, b1) in zip(pts[:-1], pts[1:]):
                seg = math.hypot(a1 - a0, b1 - b0)
                n = int(seg / 0.8)
                for k in range(n):
                    if rng.random() < 0.5:
                        continue
                    f = (k + rng.random()) / max(n, 1)
                    sa, ta = a0 + (a1 - a0) * f, b0 + (b1 - b0) * f
                    ns, nt = -(b1 - b0) / seg, (a1 - a0) / seg
                    sa += ns * side * (L.PATH_HALF + 0.1)
                    ta += nt * side * (L.PATH_HALF + 0.1)
                    x, z = L.st_xz(sa, ta)
                    u, v = to_px(x, z)
                    ang = math.atan2(*reversed(L.st_xz(a1 - a0, b1 - b0))) if False else math.atan2(L.st_xz(a1 - a0 + 0.0, b1 - b0)[1] - L.st_xz(0, 0)[1], L.st_xz(a1 - a0, b1 - b0)[0] - L.st_xz(0, 0)[0])
                    c.tick(u, v, 5 + rng.random() ** 2 * 20, ang + (rng.random() - 0.5) * 0.7 + (math.pi if rng.random() < 0.5 else 0), 1.8 + rng.random() * 2.6, INK_GROUND, 0.9)

    # pond shore ticks (reed stubble) and a broken ink lip at the waterline
    for name, p in L.PONDS.items():
        for k in range(150):
            a = rng.uniform(0, 2 * math.pi)
            e = rng.uniform(1.0, 1.1)
            x, z = L.st_xz(p["c"][0] + math.cos(a) * p["r"][0] * e, p["c"][1] + math.sin(a) * p["r"][1] * e)
            u, v = to_px(x, z)
            c.tuft(u, v, 7 + rng.random() * 8, INK_GROUND, 0.75, blades=2 + int(rng.random() * 3))
        pts = []
        for k in range(120):
            a = 2 * math.pi * k / 119
            x, z = L.st_xz(p["c"][0] + math.cos(a) * p["r"][0] * 1.01, p["c"][1] + math.sin(a) * p["r"][1] * 1.01)
            pts.append(to_px(x, z))
        for k in range(0, 119, 10):
            if rng.random() < 0.3:
                continue
            c.stroke(pts[k:k + 8 + int(rng.random() * 4)], 4.0 + rng.random() * 3, INK_GROUND, 0.85, taper=(0.15, 0.5), dry=0.4)

    # roots: every trunk gets a dark contact blot and a few tapered root strokes
    for tr in L.trees() + [{"model": "stair", "pos": L.ground(*L.STAIR_TREE), "scale": 2.6}]:
        x, _, z = tr["pos"]
        if abs(x) > EXT - 2 or abs(z) > EXT - 2:
            continue
        u, v = to_px(x, z)
        r = 0.55 * tr["scale"] * sc
        c.blotches(INK_GROUND, 0, 1)
        n = 4 + int(rng.random() * 3) if tr["model"] != "stair" else 9
        for k in range(n):
            a = rng.uniform(0, 2 * math.pi)
            ln = (1.2 + rng.random() * 1.8) * tr["scale"] * sc
            bend = rng.normal() * 0.35
            pts = [(u + math.cos(a) * r * 0.5, v + math.sin(a) * r * 0.5)]
            for f in (0.35, 0.7, 1.0):
                aa = a + bend * f
                pts.append((u + math.cos(aa) * (r * 0.5 + ln * f), v + math.sin(aa) * (r * 0.5 + ln * f)))
            c.stroke(pts, r * (0.55 + 0.3 * rng.random()), INK_GROUND, 0.92, taper=(0.05, 0.85), dry=0.35)
        ring = [(u + math.cos(a) * r * 0.95, v + math.sin(a) * r * 0.95) for a in np.linspace(0, 2 * math.pi, 14)]
        c.stroke(ring, r * 0.5, INK, 0.95, taper=(0.1, 0.3), dry=0.2)

    # moss cushions and tufts on open ground
    open_ground = (rock < 0.2) & (path < 0.1) & (chan < 0.1) & (river < 0.1)
    for name in L.PONDS:
        open_ground &= L.pond_e(s, t, name) > 1.15
    ys, xs = np.nonzero(open_ground)
    for k in rng.choice(len(xs), size=min(len(xs), 520), replace=False):
        colour = INK_GROUND if rng.random() < 0.55 else hex_rgb("4b5b37")
        for _ in range(2 + int(rng.random() * 4)):
            c.tuft(xs[k] + rng.normal() * 6, ys[k] + rng.normal() * 5, 7 + rng.random() * 7, colour, 0.6 + 0.3 * rng.random(),
                   blades=3 + int(rng.random() * 3), up=-math.pi / 2 + (rng.random() - 0.5) * 0.6)
    for k in rng.choice(len(xs), size=min(len(xs), 90), replace=False):
        PM.fans(c, (int(xs[k]) - 14, int(ys[k]) - 10, int(xs[k]) + 14, int(ys[k]) + 10, None), rng, hex_rgb("55663e"), 2, 12)

    # charcoal clamp scorch and soot scuffs in Fenn's clearing
    fx, fz = L.st_xz(fs, ft)
    u, v = to_px(fx, fz)
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.5, 3.5) * sc
        c.stroke([(u + math.cos(a) * rr, v + math.sin(a) * rr), (u + math.cos(a + 0.5) * rr * 1.2, v + math.sin(a + 0.5) * rr * 1.2)],
                 6 + rng.random() * 6, hex_rgb("2c2a27"), 0.6, taper=(0.2, 0.6), dry=0.6)
    c.soften(0.6)
    c.save(out)


def tileable(img, band=64):
    """Cross-fade the image with itself shifted by half, so the edges tile."""
    h, w, _ = img.shape
    shifted = np.roll(np.roll(img, h // 2, axis=0), w // 2, axis=1)
    yy, xx = np.mgrid[:h, :w]
    dx = np.minimum(xx, w - 1 - xx)
    dy = np.minimum(yy, h - 1 - yy)
    wgt = np.clip(np.minimum(dx, dy) / band, 0, 1)[..., None]
    return img * wgt + shifted * (1 - wgt)


def paint_cliff(out):
    S = 1024
    rng = np.random.default_rng(37)
    c = Canvas(S, S, ROCK, seed=37)
    ones = np.ones((S, S))
    c.wash(ones, ROCK, variation=0.07, blotch=110, hue_shift=hex_rgb("6c7458"))
    # moss drapes hanging from above: ragged green washes and drips
    moss = np.zeros((S, S))
    for k in range(9):
        x0 = rng.random() * S
        w = 60 + rng.random() * 160
        depth = 120 + rng.random() * 380
        y0 = rng.random() * S
        yy, xx = np.mgrid[:S, :S]
        d = np.abs(((xx - x0 + S / 2) % S) - S / 2) / w
        dyv = ((yy - y0) % S) / depth
        moss = np.maximum(moss, np.clip(1 - d, 0, 1) * np.clip(1 - dyv, 0, 1) ** 0.7)
    moss = np.clip(moss * 1.6 + soft_noise((S, S), 30, rng) * 0.3, 0, 1)
    c.wash(moss, hex_rgb("6a7a4c"), variation=0.06, blotch=60, edge_noise=6)
    # strata, faint and dry
    for _ in range(12):
        y = rng.random() * S
        x = rng.random() * S
        l = 140 + rng.random() * 280
        c.stroke([(x, y), (x + l / 2, y + rng.normal() * 6), (x + l, y + rng.normal() * 9)], 1.6 + rng.random() * 2, INK_GROUND, 0.6, taper=(0.1, 0.5), dry=0.6)
    # bold tapered cracks down the face, a few forked
    for k in range(11):
        x, y = (k + 0.2 + rng.random() * 0.6) * S / 11, rng.random() * S * 0.4
        a = math.pi / 2 + (rng.random() - 0.5) * 0.4
        pts = [(x, y)]
        for _ in range(6):
            a += (rng.random() - 0.5) * 0.5
            seg = 50 + rng.random() * 50
            pts.append((pts[-1][0] + math.cos(a) * seg, pts[-1][1] + math.sin(a) * seg))
        width = 10 + rng.random() * 10
        c.stroke(pts, width, INK_GROUND, 0.94, taper=(0.1, 0.75), dry=0.35)
        if rng.random() < 0.6:
            j = 1 + int(rng.random() * (len(pts) - 2))
            b = a + (0.6 if rng.random() < 0.5 else -0.6)
            fork = [pts[j]] + [(pts[j][0] + math.cos(b) * 40 * i, pts[j][1] + math.sin(b) * 40 * i) for i in (1, 2, 3)]
            c.stroke(fork, width * 0.55, INK_GROUND, 0.9, taper=(0.1, 0.8), dry=0.4)
    # moss drips: short hanging strokes
    for _ in range(70):
        x, y = rng.random() * S, rng.random() * S
        c.stroke([(x, y), (x + rng.normal() * 3, y + 20 + rng.random() * 40)], 3 + rng.random() * 4, hex_rgb("4b5a35"), 0.7, taper=(0.05, 0.8), dry=0.4)
    c.soften(0.5)
    c.img = tileable(c.img)
    c.save(out)


# ----------------------------------------------------------------------------- props
TAG_WASH = dict(PM.TAG_WASH)
TAG_WASH.update({
    "bark": "1e1c1b", "bark_pale": "3a3631", "canopy": "6f8752", "canopy_under": "51683f", "fungus": "c9b58a",
    "fungus_under": "8d7a58", "moss": "6d7d4a", "moss_dark": "4f5d38", "rock": "77786c", "rock_top": "8a8b7b",
    "wood": "6a5640", "wood_dark": "3f342a", "plank": "8a7458", "soot": "1a191b", "rope": "b49c6c",
    "lantern": "d9a441", "lantern_husk": "5d4a2c", "glow": "f6dc8a", "stem": "3b3a2a", "lily_bud": "e8dcc6",
    "lily_pad": "6e8a52", "lily_petal": "f0d7da", "thatch": "8e7a52", "clay": "7a6650", "char": "2b2927",
    "stone": "8a887e", "willow_leaf": "8fa968", "willow_whip": "232220", "catkin": "efe6c4", "cloth": "5e6b72",
    "ink": "141315", "eye": "e6e0d0", "wing": "232126", "ember": "e0743a", "paper": "ece3cd", "iron": "45433f",
})


def paint_generic(pm, size, out, seed, recipe):
    rng = np.random.default_rng(seed)
    masks, used = PM.tag_masks(pm, size)
    first = hex_rgb(TAG_WASH.get(sorted(masks)[0], "8c8a80"))
    c = Canvas(size, size, first, seed=seed)
    for tag, m in masks.items():
        col = hex_rgb(TAG_WASH.get(tag, "8c8a80"))
        var = 0.12 if tag in ("bark", "soot", "wing", "willow_whip") else 0.05
        c.wash(m, col, variation=var, blotch=size * 0.08, edge_noise=1.5)
    c.dilate_from(used)
    s = size / 512.0
    for tag, m in masks.items():
        for isl in PM.islands_of(m):
            w, hh = isl[2] - isl[0], isl[3] - isl[1]
            if w * hh < 64:
                continue
            area = w * hh / (size * size)
            vertical = hh > w
            if tag in ("bark", "willow_whip"):
                PM.strokes_in_island(c, isl, hex_rgb("47443f"), max(1, int(area * 260)), 2.4 * s, rng, vertical=vertical, alpha=0.5, dry=0.6)
            elif tag in ("canopy", "canopy_under", "willow_leaf", "moss", "lily_pad"):
                PM.fans(c, isl, rng, hex_rgb("3f5530" if tag != "willow_leaf" else "56723e"), max(2, int(area * 380)), 13 * s)
            elif tag in ("rock", "rock_top", "stone"):
                PM.cracks(c, isl, rng, max(1, int(area * 60)), 3.2 * s)
            elif tag in ("wood", "plank", "wood_dark", "thatch"):
                PM.strokes_in_island(c, isl, hex_rgb("2e251d"), max(2, int(area * 140)), 2.0 * s, rng, vertical=vertical, alpha=0.6, dry=0.5)
            elif tag in ("fungus", "fungus_under"):
                PM.strokes_in_island(c, isl, hex_rgb("6e5a3c"), max(2, int(area * 160)), 1.6 * s, rng, vertical=not vertical, alpha=0.6, dry=0.5)
            elif tag in ("lily_petal", "catkin", "lily_bud"):
                PM.fans(c, isl, rng, hex_rgb("e58aa0" if tag == "lily_petal" else "d8cfae"), max(1, int(area * 200)), 8 * s)
            elif tag == "soot":
                c.blotches(hex_rgb("3a383c"), max(2, int(area * 80)), 14 * s, strength=0.4, mask=m)
    if recipe:
        recipe(c, masks, rng, s)
    PM.paint_creases(c, pm, size, {"wood", "plank", "stone", "rock", "clay", "paper", "lantern_husk"}, mix(INK_BROWN, hex_rgb("ece2cb"), 0.1), 2.2 * s, 0.55, rng, alpha=0.75)
    c.soften(0.5)
    c.save(out)


def eyes(c, masks, rng, s):
    if "eye" in masks:
        for isl in PM.islands_of(masks["eye"]):
            PM.thumbprint(c, isl, rng)


def glow(c, masks, rng, s):
    if "glow" in masks:
        c.blotches(hex_rgb("fff3c8"), 12, 20 * s, strength=0.5, mask=masks["glow"])


RECIPES = {"sootflit": eyes, "lantern_fruit": glow}


def main(model, pm_path, out_dir):
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    if model == "terrain":
        paint_ground(str(Path(out_dir) / "mw_ground.png"))
        print("TEXTURE mw_ground 2048")
        paint_cliff(str(Path(out_dir) / "mw_cliff.png"))
        print("TEXTURE mw_cliff 1024")
        return
    pm = PM.load(pm_path)
    out = str(Path(out_dir) / ("mw_%s.png" % model))
    seed = 500 + sum(ord(ch) for ch in model)
    paint_generic(pm, pm["size"], out, seed, RECIPES.get(model))
    print("TEXTURE mw_%s %d" % (model, pm["size"]))


if __name__ == "__main__":
    main(*sys.argv[1:4])
