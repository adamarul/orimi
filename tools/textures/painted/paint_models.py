"""Paint each model's albedo texture from the paint map its Blender generator wrote.

    python tools/textures/painted/paint_models.py <model> <paintmap.json> <out_dir>

The paint map holds every face's UV polygon with a tag ("paper", "ash", "bark", ...) and the
UV segments of every fold or edge sharper than the generator's crease angle. Each model has a
recipe below: a flat wash per tag, ink strokes along some creases, and model-specific strokes
(bark lines, cracks, thumbprint eyes). Output: <out_dir>/<model>.png.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from inkpaint import INK, INK_BROWN, Canvas, hex_rgb, mix  # noqa: E402

PAPER = hex_rgb("ece2cb")


def load(path):
    with open(path) as f:
        return json.load(f)


def to_px(uv, size):
    return [(u * size, (1.0 - v) * size) for u, v in uv]


def tag_masks(pm, size):
    tags = sorted({f["tag"] for f in pm["faces"]})
    img = Image.new("I", (size, size), 0)
    draw = ImageDraw.Draw(img)
    for f in pm["faces"]:
        draw.polygon(to_px(f["uv"], size), fill=tags.index(f["tag"]) + 1)
    arr = np.array(img)
    return {t: (arr == i + 1).astype(float) for i, t in enumerate(tags)}, arr > 0


def islands_of(mask):
    from scipy import ndimage
    lab, n = ndimage.label(mask > 0.5)
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        ys, xs = sl
        out.append((xs.start, ys.start, xs.stop, ys.stop, lab == i + 1))
    return out


def paint_creases(c, pm, size, tags, color, width, keep, rng, alpha=0.9):
    for cr in pm["creases"]:
        if cr["tag"] not in tags or rng.random() > keep:
            continue
        (x0, y0), (x1, y1) = to_px(cr["uv"], size)
        (cx, cy), = to_px([cr["center"]], size)
        ex, ey = x1 - x0, y1 - y0
        el = math.hypot(ex, ey) + 1e-6
        nx, ny = -ey / el, ex / el
        if (cx - x0) * nx + (cy - y0) * ny < 0:
            nx, ny = -nx, -ny
        inset = width * 0.6 + 1.0
        x0, y0, x1, y1 = x0 + nx * inset, y0 + ny * inset, x1 + nx * inset, y1 + ny * inset
        a, b = 0.03 + 0.15 * rng.random(), 0.72 + 0.26 * rng.random()
        p0 = (x0 + (x1 - x0) * a, y0 + (y1 - y0) * a)
        p1 = (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)
        if math.hypot(p1[0] - p0[0], p1[1] - p0[1]) < 4:
            continue
        mid = ((p0[0] + p1[0]) / 2 + rng.normal() * 0.8, (p0[1] + p1[1]) / 2 + rng.normal() * 0.8)
        w = width * (0.75 + 0.5 * min(1.0, cr["angle"] / 60.0))
        c.stroke([p0, mid, p1], w, color, alpha, taper=(0.15, 0.5), dry=0.3, pressure=0.35)


def strokes_in_island(c, isl, color, count, width, rng, vertical=True, length=(0.4, 0.9), alpha=0.9, dry=0.35):
    """Long strokes running along one axis of an island's bounding box (bark, reed fibres)."""
    x0, y0, x1, y1, m = isl
    for _ in range(count):
        if vertical:
            x = x0 + rng.random() * (x1 - x0)
            l = (y1 - y0) * (length[0] + rng.random() * (length[1] - length[0]))
            ys = y0 + rng.random() * max(1.0, (y1 - y0) - l)
            pts = [(x, ys), (x + rng.normal() * 2, ys + l * 0.5), (x + rng.normal() * 3, ys + l)]
        else:
            y = y0 + rng.random() * (y1 - y0)
            l = (x1 - x0) * (length[0] + rng.random() * (length[1] - length[0]))
            xs = x0 + rng.random() * max(1.0, (x1 - x0) - l)
            pts = [(xs, y), (xs + l * 0.5, y + rng.normal() * 2), (xs + l, y + rng.normal() * 3)]
        c.stroke(pts, width * (0.6 + 0.8 * rng.random()), color, alpha, dry=dry)


def finish(c, used, out):
    c.soften(0.5)
    c.save(out)


# ----------------------------------------------------------------------------- recipes

def paint_fox(pm, size, out):
    rng = np.random.default_rng(11)
    c = Canvas(size, size, PAPER, seed=11)
    masks, used = tag_masks(pm, size)
    c.wash(np.ones((size, size)), hex_rgb("ebdfc4"), variation=0.045, blotch=size * 0.12, hue_shift=hex_rgb("f2e8d6"))
    if "ash" in masks:
        c.wash(masks["ash"], hex_rgb("8f8a82"), variation=0.06, blotch=40, edge_noise=4)
    if "cord" in masks:
        c.wash(masks["cord"], hex_rgb("d5402b"), variation=0.04, blotch=30)
    if "bead" in masks:
        c.wash(masks["bead"], hex_rgb("d9a441"), variation=0.05, blotch=20)
    if "smear" in masks:
        c.wash(masks["smear"], hex_rgb("e9e6df"), variation=0.03, blotch=40)
        for isl in islands_of(masks["smear"]):
            horizontal = (isl[2] - isl[0]) > (isl[3] - isl[1])
            strokes_in_island(c, isl, hex_rgb("b8b4ac"), 14, 3.0, rng, vertical=not horizontal, alpha=0.6, dry=0.6)
    c.dilate_from(used)
    paint_creases(c, pm, size, {"paper", "ash"}, mix(INK_BROWN, PAPER, 0.15), 2.6, 0.62, rng, alpha=0.85)
    finish(c, used, out)


INK_BLOT = hex_rgb("1e1c20")


def thumbprint(c, isl, rng):
    """Pale oval with broken concentric whorl ridges, like a thumb pressed in pale paint."""
    x0, y0, x1, y1, m = isl
    cx, cy = (x0 + x1) / 2 + rng.normal() * 2, (y0 + y1) / 2 + rng.normal() * 2
    rx, ry = (x1 - x0) * 0.42, (y1 - y0) * 0.42
    for k in range(1, 7):
        f = k / 6.5
        a0 = rng.random() * 6.28
        span = 3.6 + rng.random() * 1.8
        pts = [(cx + math.cos(a0 + t) * rx * f, cy + math.sin(a0 + t) * ry * f * (0.9 + 0.1 * k / 6)) for t in np.linspace(0, span, 14)]
        c.stroke(pts, max(1.4, rx * 0.06), hex_rgb("a49e92"), 0.75, taper=(0.1, 0.3), dry=0.35, pressure=0.2)


def paint_splotchet(pm, size, out):
    rng = np.random.default_rng(13)
    c = Canvas(size, size, INK_BLOT, seed=13)
    masks, used = tag_masks(pm, size)
    c.wash(np.ones((size, size)), INK_BLOT, variation=0.18, blotch=size * 0.08, hue_shift=hex_rgb("2a2430"))
    if "eye" in masks:
        c.wash(masks["eye"], hex_rgb("e6e0d0"), variation=0.04, blotch=30)
    if "smear" in masks:
        c.wash(masks["smear"], hex_rgb("2b292d"), variation=0.1, blotch=30)
    c.dilate_from(used)
    if "ink" in masks:
        # Bold wet brush strokes over the blot: broad sheen sweeps and a few dry highlights, so it
        # reads as brushed ink rather than a flat black fill even at gameplay distance.
        for isl in islands_of(masks["ink"]):
            x0, y0, x1, y1, m = isl
            w, h = x1 - x0, y1 - y0
            if w * h < 400:
                continue
            for k in range(max(3, int(w * h / 2500))):
                x, y = x0 + rng.random() * w, y0 + rng.random() * h
                a = rng.normal() * 0.5 + (0.0 if w > h else 1.57)
                l = min(w, h) * (0.35 + 0.4 * rng.random())
                pts = [(x, y), (x + math.cos(a) * l * 0.5, y + math.sin(a) * l * 0.5 + rng.normal() * l * 0.08),
                       (x + math.cos(a + 0.25) * l, y + math.sin(a + 0.25) * l)]
                dry = k % 3 == 0
                c.stroke(pts, (4 if dry else 7) + rng.random() * 6, hex_rgb("8c8898" if dry else "56525f"), 0.45 if dry else 0.6,
                         taper=(0.1, 0.5), dry=0.75 if dry else 0.4)
    if "eye" in masks:
        for isl in islands_of(masks["eye"]):
            thumbprint(c, isl, rng)
            x0, y0, x1, y1, m = isl
            cx, cy, r = (x0 + x1) / 2, (y0 + y1) / 2, min(x1 - x0, y1 - y0) * 0.16
            c.stroke([(cx - r * 0.3, cy), (cx + r * 0.3, cy + r * 0.1)], r * 1.6, INK_BLOT, 0.95, taper=(0.3, 0.3), dry=0.1)
    if "smear" in masks:
        for isl in islands_of(masks["smear"]):
            horizontal = (isl[2] - isl[0]) > (isl[3] - isl[1])
            strokes_in_island(c, isl, hex_rgb("0f0e10"), 10, 3.0, rng, vertical=not horizontal, alpha=0.8, dry=0.6)
    finish(c, used, out)


def paint_reedwraith(pm, size, out):
    rng = np.random.default_rng(19)
    reed = hex_rgb("1f211d")
    c = Canvas(size, size, reed, seed=19)
    masks, used = tag_masks(pm, size)
    c.wash(np.ones((size, size)), reed, variation=0.12, blotch=size * 0.06, hue_shift=hex_rgb("23271f"))
    for tag, col in (("binding", hex_rgb("2c2622")), ("seed", hex_rgb("cdc6b0")), ("veil", hex_rgb("4a4746")), ("smear", hex_rgb("2a2a28")),
                     ("hood", hex_rgb("0c0b0d")), ("eye", hex_rgb("ece4cc"))):
        if tag in masks:
            c.wash(masks[tag], col, variation=0.08, blotch=40, edge_noise=2)
    c.dilate_from(used)
    if "reed" in masks:
        for isl in islands_of(masks["reed"]):
            w, h = isl[2] - isl[0], isl[3] - isl[1]
            if w * h < 200:
                continue
            strokes_in_island(c, isl, hex_rgb("4d5146"), max(3, int(max(w, h) / 22)), 4.0, rng, vertical=h > w, alpha=0.75, dry=0.5)
            strokes_in_island(c, isl, hex_rgb("7c8070"), max(1, int(max(w, h) / 60)), 2.5, rng, vertical=h > w, alpha=0.5, dry=0.8)
    if "binding" in masks:
        for isl in islands_of(masks["binding"]):
            strokes_in_island(c, isl, hex_rgb("0e0d0c"), 6, 2.5, rng, vertical=False, alpha=0.8, dry=0.4)
    if "veil" in masks:
        veil = masks["veil"]
        c.blotches(hex_rgb("6b6764"), 40, 40, strength=0.35, mask=veil)
        c.blotches(hex_rgb("27252a"), 30, 30, strength=0.4, mask=veil)
        for isl in islands_of(veil):
            w, h = isl[2] - isl[0], isl[3] - isl[1]
            if w * h < 200:
                continue
            strokes_in_island(c, isl, hex_rgb("1c1b1d"), max(2, int(max(w, h) / 30)), 3.0, rng, vertical=h > w, alpha=0.6, dry=0.7)
    if "seed" in masks:
        for isl in islands_of(masks["seed"]):
            strokes_in_island(c, isl, hex_rgb("8a8370"), 2, 1.5, rng, vertical=True, alpha=0.6, dry=0.3)
    finish(c, used, out)


TAG_WASH = {
    "bark": "201e1c", "thorn": "18171a", "cord": "d5402b", "post": "cf3f2a", "gold": "d9a441",
    "blossom": "f0b4be", "leaf": "8fa76b", "canopy": "7f9a5c", "canopy_under": "5f7748", "paper": "ece3cd",
    "stone": "8c8a80", "stone_top": "a19e92", "stone_wet": "626660", "wood": "5a4a3c", "reed": "98a06a",
    "reed_head": "8a6f4a", "driftwood": "8d7c60", "rope": "b8955c",
}


def cracks(c, isl, rng, count, width, color=INK, alpha=0.9):
    x0, y0, x1, y1, m = isl
    for _ in range(count):
        x, y = x0 + rng.random() * (x1 - x0), y0 + rng.random() * (y1 - y0)
        a = rng.random() * 6.28
        pts = [(x, y)]
        for _ in range(3):
            a += rng.normal() * 0.5
            seg = min(x1 - x0, y1 - y0) * (0.12 + rng.random() * 0.18)
            pts.append((pts[-1][0] + math.cos(a) * seg, pts[-1][1] + math.sin(a) * seg))
        c.stroke(pts, width * (0.6 + 0.8 * rng.random()), color, alpha, taper=(0.08, 0.6), dry=0.4)


def fans(c, isl, rng, color, count, size):
    """Fan-shaped clusters of single brush strokes (foliage and blossom)."""
    x0, y0, x1, y1, m = isl
    for _ in range(count):
        x, y = x0 + rng.random() * (x1 - x0), y0 + rng.random() * (y1 - y0)
        up = -math.pi / 2 + rng.normal() * 0.5
        for k in range(4):
            a = up + (k - 1.5) * 0.35
            l = size * (0.7 + 0.5 * rng.random())
            c.stroke([(x, y), (x + math.cos(a) * l * 0.55, y + math.sin(a) * l * 0.55), (x + math.cos(a + 0.15) * l, y + math.sin(a + 0.15) * l)],
                     size * 0.28, color, 0.75, taper=(0.05, 0.7), dry=0.3)


def paint_prop(pm, size, out, seed):
    rng = np.random.default_rng(seed)
    masks, used = tag_masks(pm, size)
    first = hex_rgb(TAG_WASH.get(sorted(masks)[0], "8c8a80"))
    c = Canvas(size, size, first, seed=seed)
    for tag, m in masks.items():
        col = hex_rgb(TAG_WASH.get(tag, "8c8a80"))
        var = 0.12 if tag in ("bark", "thorn") else 0.05
        c.wash(m, col, variation=var, blotch=size * 0.08, edge_noise=1.5)
    c.dilate_from(used)
    s = size / 512.0
    for tag, m in masks.items():
        for isl in islands_of(m):
            w, h = isl[2] - isl[0], isl[3] - isl[1]
            if w * h < 64:
                continue
            area = w * h / (size * size)
            if tag == "bark":
                strokes_in_island(c, isl, hex_rgb("4a4744"), max(1, int(area * 300)), 2.2 * s, rng, vertical=h > w, alpha=0.55, dry=0.6)
            elif tag == "thorn":
                strokes_in_island(c, isl, hex_rgb("3a383c"), max(1, int(area * 200)), 1.8 * s, rng, vertical=h > w, alpha=0.5, dry=0.6)
            elif tag.startswith("stone"):
                cracks(c, isl, rng, max(1, int(area * 60)), 3.0 * s, INK if tag != "stone_wet" else hex_rgb("2c302c"))
            elif tag in ("canopy", "canopy_under", "leaf"):
                fans(c, isl, rng, hex_rgb("4f6a3a" if tag != "canopy_under" else "3d5230"), max(2, int(area * 400)), 14 * s)
            elif tag == "blossom":
                fans(c, isl, rng, hex_rgb("e58aa0"), max(2, int(area * 300)), 10 * s)
                fans(c, isl, rng, hex_rgb("fbf2ee"), max(1, int(area * 120)), 7 * s)
            elif tag in ("wood", "driftwood"):
                strokes_in_island(c, isl, hex_rgb("2e251d"), max(2, int(area * 120)), 2.0 * s, rng, vertical=h > w, alpha=0.6, dry=0.5)
            elif tag == "reed":
                strokes_in_island(c, isl, hex_rgb("4f5a37"), max(1, int(area * 200)), 1.6 * s, rng, vertical=h > w, alpha=0.7, dry=0.5)
    paint_creases(c, pm, size, {"paper", "stone", "stone_top", "wood"}, mix(INK_BROWN, PAPER, 0.1), 2.2 * s, 0.55, rng, alpha=0.75)
    finish(c, used, out)


RECIPES = {"fox": paint_fox, "splotchet": paint_splotchet, "reedwraith": paint_reedwraith}
for _i, _name in enumerate(["sapling", "great_tree", "thorn_gate", "shrine", "stepping_stone", "rocks", "reeds", "raft"]):
    RECIPES[_name] = (lambda seed: (lambda pm, size, out: paint_prop(pm, size, out, seed)))(100 + _i)


def main(model, pm_path, out_dir):
    if model == "terrain":
        import paint_terrain
        paint_terrain.main(out_dir)
        return
    pm = load(pm_path)
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    out = str(Path(out_dir) / ("%s.png" % model))
    RECIPES[model](pm, pm["size"], out)
    print("TEXTURE", model, pm["size"], Path(out).as_posix().split("assets/", 1)[-1])


if __name__ == "__main__":
    main(*sys.argv[1:4])
