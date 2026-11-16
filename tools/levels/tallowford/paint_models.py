"""Paint the albedo texture of every Tallowford model from the paint map its Blender builder wrote.

    python tools/levels/tallowford/paint_models.py <model> <paintmap.json> <out_dir>

The paint map (tools/blender/inklib.dump_paint_map plus tf_models.augment_map) holds each face's
UV polygon and tag, the UV direction of world up and of the horizontal along the face, and its
pixels per metre. Flat washes per tag, then ink: lattices on the paper screens, shingle rows and
straw on the roofs, grain on timber, cracks on stone, hoops on lanterns, folds on cloth, plank
joints on decks, fans of strokes on foliage, and fold creases along sharp edges.
Output: <out_dir>/<model>.png. Shared helpers come from tools/textures/painted/ unchanged.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "textures" / "painted"))
from inkpaint import INK, INK_BROWN, Canvas, hex_rgb, mix  # noqa: E402
import paint_models as PM  # noqa: E402

TAG_WASH = {
    "stone": "8c8a80", "stone_top": "a19e92", "kerb": "9a968a", "wood": "5a4a3c", "beam": "4a3d32", "plaster": "cbbfa4",
    "screen": "ece3cd", "door": "34302d", "roof": "625a52", "thatch": "a08e66", "ridge": "3e3832", "lantern": "e6dcc6",
    "lit": "f2d58a", "cap": "3e342c", "soot": "1e1c20", "bark": "201e1c", "canopy": "7f9a5c", "canopy_under": "5f7748",
    "fruit": "d9823a", "dye_indigo": "4e5f7a", "dye_madder": "a5584a", "dye_weld": "c9a94e", "cloth_indigo": "56698a",
    "cloth_madder": "b0665a", "cloth_weld": "cdb066", "cloth_pale": "aab9c4", "paper": "eee8d8", "deck": "7a6650",
    "rope": "8a7a5c", "dark": "1e1c1e", "hoop": "2e2a28", "stave": "7d6650", "noren": "4e5f7a", "herb": "6f7a4e",
    "log": "6e5a44",
}
LINE = mix(INK_BROWN, hex_rgb("2a2420"), 0.5)


def face_px(face, size):
    return [(u * size, (1.0 - v) * size) for u, v in face["uv"]]


def norm(v):
    l = math.hypot(v[0], v[1])
    return (v[0] / l, v[1] / l) if l > 1e-9 else (0.0, 0.0), l


def clipped(c, poly, draw_fn, pad=2):
    """Run draw_fn() and keep its marks only inside poly (pixel polygon)."""
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    x0, y0 = max(0, int(min(xs)) - pad), max(0, int(min(ys)) - pad)
    x1, y1 = min(c.w, int(math.ceil(max(xs))) + pad), min(c.h, int(math.ceil(max(ys))) + pad)
    if x1 - x0 < 2 or y1 - y0 < 2:
        return
    before = c.img[y0:y1, x0:x1].copy()
    draw_fn()
    m = Image.new("L", (x1 - x0, y1 - y0), 0)
    ImageDraw.Draw(m).polygon([(x - x0, y - y0) for x, y in poly], fill=255)
    mask = (np.asarray(m, float) / 255.0)[..., None]
    c.img[y0:y1, x0:x1] = before * (1 - mask) + c.img[y0:y1, x0:x1] * mask


def family(face, size, spacing, direction, rng, inset=0.5):
    """Parallel lines across a face, one every spacing metres of world 'up' (direction = 'up':
    lines of constant height) or of the horizontal along the face ('along': lines of constant
    position). Returns a list of ((x0, y0), (x1, y1)) segments covering the polygon."""
    poly = face_px(face, size)
    g = face.get(direction)
    other = face.get("along" if direction == "up" else "up")
    if g is None or other is None:
        return []
    gh, gl = norm(g)
    oh, _ = norm(other)
    if gl < 1e-9:
        return []
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    vals = [(p[0] - cx) * g[0] + (p[1] - cy) * g[1] for p in poly]
    lo, hi = min(vals), max(vals)
    if hi - lo < spacing * 0.5:
        return []
    diag = math.hypot(max(p[0] for p in poly) - min(p[0] for p in poly), max(p[1] for p in poly) - min(p[1] for p in poly)) + 4
    out = []
    start = lo + ((hi - lo) % spacing) / 2.0 + (spacing * inset if (hi - lo) > spacing * 2 else 0)
    t = start
    while t < hi - 1e-6:
        px = cx + g[0] / (gl * gl) * t
        py = cy + g[1] / (gl * gl) * t
        d = oh if abs(oh[0]) + abs(oh[1]) > 0 else (gh[1], -gh[0])
        out.append(((px - d[0] * diag, py - d[1] * diag), (px + d[0] * diag, py + d[1] * diag)))
        t += spacing
    return out


def paint(pm, size, out, seed):
    rng = np.random.default_rng(seed)
    masks, used = PM.tag_masks(pm, size)
    first = hex_rgb(TAG_WASH.get(sorted(masks)[0], "8c8a80"))
    c = Canvas(size, size, first, seed=seed)
    for tag, m in masks.items():
        var = 0.12 if tag in ("bark", "soot") else 0.05
        c.wash(m, hex_rgb(TAG_WASH.get(tag, "8c8a80")), variation=var, blotch=size * 0.06, edge_noise=1.2)
    c.dilate_from(used)
    s = size / 512.0

    # directional ink per face
    for face in pm["faces"]:
        tag = face["tag"]
        ppm = face.get("ppm", 0.0)
        if ppm <= 0:
            continue
        poly = face_px(face, size)
        if tag == "screen":
            segs = family(face, size, 0.33, "along", rng) + family(face, size, 0.42, "up", rng)
            if segs:
                clipped(c, poly, lambda segs=segs: [c.stroke([a, b], max(1.6, 0.03 * ppm), LINE, 0.7, taper=(0.02, 0.02), dry=0.35, pressure=0.15, edge=0.1) for a, b in segs])
        elif tag == "roof":
            segs = family(face, size, 0.24, "up", rng)
            if segs:
                clipped(c, poly, lambda segs=segs: [c.stroke([a, b], max(1.8, 0.035 * ppm), mix(INK, hex_rgb("625a52"), 0.35), 0.55, taper=(0.05, 0.05), dry=0.55, pressure=0.4) for a, b in segs])
        elif tag == "thatch":
            def straw(face=face, poly=poly):
                g, gl = norm(face["up"])
                xs, ys = [p[0] for p in poly], [p[1] for p in poly]
                for _ in range(int(max(4, (max(xs) - min(xs)) * (max(ys) - min(ys)) / (ppm * ppm) * 30))):
                    x, y = min(xs) + rng.random() * (max(xs) - min(xs)), min(ys) + rng.random() * (max(ys) - min(ys))
                    l = ppm * rng.uniform(0.25, 0.5)
                    c.stroke([(x, y), (x - g[0] * l, y - g[1] * l)], max(1.4, 0.025 * ppm), mix(INK_BROWN, hex_rgb("a08e66"), 0.35), 0.5, taper=(0.05, 0.6), dry=0.5)
            clipped(c, poly, straw)
        elif tag in ("lantern", "lit"):
            segs = family(face, size, 0.13, "up", rng, inset=0.0)
            col = LINE if tag == "lantern" else hex_rgb("b0803a")
            if segs:
                clipped(c, poly, lambda segs=segs, col=col: [c.stroke([a, b], max(1.4, 0.02 * ppm), col, 0.55, taper=(0.02, 0.02), dry=0.3, pressure=0.1) for a, b in segs])
        elif tag.startswith("cloth") or tag == "noren":
            segs = family(face, size, 0.22, "along", rng)
            base = hex_rgb(TAG_WASH[tag])
            if segs:
                clipped(c, poly, lambda segs=segs, base=base: [c.stroke([a, b], max(2.0, 0.05 * ppm), mix(base, INK, 0.35), 0.35, taper=(0.2, 0.3), dry=0.6, pressure=0.5) for a, b in segs])
        elif tag == "deck":
            segs = family(face, size, 0.22, "along", rng)
            if segs:
                clipped(c, poly, lambda segs=segs: [c.stroke([a, b], max(1.6, 0.025 * ppm), mix(INK, hex_rgb("7a6650"), 0.3), 0.6, taper=(0.05, 0.05), dry=0.45, pressure=0.2) for a, b in segs])
        elif tag == "plaster":
            pass

    # island strokes
    for tag, m in masks.items():
        for isl in PM.islands_of(m):
            w, h = isl[2] - isl[0], isl[3] - isl[1]
            if w * h < 40:
                continue
            area = w * h / (size * size)
            if tag in ("wood", "beam", "stave", "log", "cap"):
                PM.strokes_in_island(c, isl, hex_rgb("2e251d"), max(1, int(area * 160)), 1.8 * s, rng, vertical=h > w, alpha=0.55, dry=0.55)
            elif tag in ("stone", "stone_top", "kerb"):
                PM.cracks(c, isl, rng, max(1, int(area * 50)), 2.6 * s)
            elif tag == "bark":
                PM.strokes_in_island(c, isl, hex_rgb("4a4744"), max(1, int(area * 300)), 2.0 * s, rng, vertical=h > w, alpha=0.5, dry=0.6)
            elif tag in ("canopy", "canopy_under"):
                PM.fans(c, isl, rng, hex_rgb("4f6a3a" if tag == "canopy" else "3d5230"), max(2, int(area * 400)), 12 * s)
            elif tag == "fruit":
                x0, y0, x1, y1, mm = isl
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                c.stroke([(cx - w * 0.2, cy - h * 0.15), (cx + w * 0.1, cy - h * 0.25)], max(1.5, w * 0.18), hex_rgb("f0b070"), 0.8, dry=0.2)
            elif tag == "soot":
                PM.strokes_in_island(c, isl, hex_rgb("3d393a"), max(2, int(area * 200)), 3.0 * s, rng, vertical=h > w, alpha=0.6, dry=0.7)
            elif tag.startswith("dye_"):
                x0, y0, x1, y1, mm = isl
                cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                base = hex_rgb(TAG_WASH[tag])
                for k in range(3):
                    r = min(w, h) * (0.15 + 0.12 * k)
                    a0 = rng.random() * 6.28
                    pts = [(cx + math.cos(a0 + t) * r, cy + math.sin(a0 + t) * r) for t in np.linspace(0, 3.6, 10)]
                    c.stroke(pts, max(1.5, 2.0 * s), mix(base, hex_rgb("f0ece0"), 0.45), 0.6, taper=(0.1, 0.5), dry=0.3)
            elif tag == "rope":
                PM.strokes_in_island(c, isl, hex_rgb("4a3e2c"), max(1, int(area * 200)), 1.4 * s, rng, vertical=w > h, alpha=0.6, dry=0.4)
            elif tag == "herb":
                PM.fans(c, isl, rng, hex_rgb("3d4a2c"), max(1, int(area * 300)), 8 * s)
            elif tag == "plaster":
                c.blotches(hex_rgb("b5a88c"), max(1, int(area * 40)), max(4.0, min(w, h) * 0.3), strength=0.25, mask=mm_of(isl))
            elif tag == "paper":
                x0, y0, x1, y1, mm = isl
                if rng.random() < 0.6 and w > 8 and h > 8:
                    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
                    c.stroke([(cx - w * 0.25, cy), (cx, cy - h * 0.15), (cx + w * 0.2, cy + h * 0.05)], max(1.5, 2.5 * s), hex_rgb("c9bfa8"), 0.6, dry=0.5)
    PM.paint_creases(c, pm, size, {"wood", "beam", "stone", "stone_top", "plaster", "kerb", "stave", "deck", "cap", "door"},
                     mix(INK_BROWN, PM.PAPER, 0.1), 2.0 * s, 0.5, rng, alpha=0.7)
    PM.paint_creases(c, pm, size, {"lantern", "screen", "paper"}, mix(INK_BROWN, PM.PAPER, 0.3), 1.6 * s, 0.6, rng, alpha=0.6)
    c.soften(0.5)
    c.save(out)


def mm_of(isl):
    return isl[4].astype(float)


def main(model, pm_path, out_dir):
    pm = PM.load(pm_path)
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    out = str(Path(out_dir) / ("%s.png" % model))
    paint(pm, pm["size"], out, 300 + sum(map(ord, model)) % 97)
    print("TEXTURE", model, pm["size"])


if __name__ == "__main__":
    main(*sys.argv[1:4])
