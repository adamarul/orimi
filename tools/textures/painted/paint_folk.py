"""Paint one paper person's atlas from the paint map make_folk.py wrote: a woken version in its
palette and a faded version (grey, drained paper with the same ink creases).

    python tools/textures/painted/paint_folk.py <spec.json> <name> <paintmap.json>

Writes the two textures named by folk_style.paths(): <name>.png and <name>_faded.png.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parents[1] / "blender"))
import folk_style as FS  # noqa: E402
from inkpaint import INK_BROWN, Canvas, hex_rgb, mix  # noqa: E402
from paint_models import islands_of, load, paint_creases, strokes_in_island, tag_masks  # noqa: E402

ROOT = HERE.parents[2]
FADED_PAPER = hex_rgb("cfcac0")


def shade(rgb, k):
    return tuple(max(0.0, min(1.0, c * k)) for c in rgb)


def paint(person, pm, out):
    size = pm["size"]
    s = size / 512.0
    col = {k: hex_rgb(v) for k, v in person["colours"].items()}
    rng = np.random.default_rng(person["seed"])
    c = Canvas(size, size, col["skin"], seed=person["seed"])
    masks, used = tag_masks(pm, size)
    for tag, m in masks.items():
        base = col.get(tag, col["garment"])
        c.wash(m, base, variation=0.05, blotch=30 * s, edge_noise=2, hue_shift=mix(base, hex_rgb("efe4cc"), 0.12))
    for tag in ("garment", "legs"):
        if tag in masks:
            for isl in islands_of(masks[tag]):
                x0, y0, x1, y1, _ = isl
                area = (x1 - x0) * (y1 - y0) / float(size * size)
                strokes_in_island(c, isl, shade(col[tag], 0.72), max(1, int(area * 90)), 2.4 * s, rng,
                                  vertical=(y1 - y0) > (x1 - x0), alpha=0.55, dry=0.55)
    if "hair" in masks:
        for isl in islands_of(masks["hair"]):
            strokes_in_island(c, isl, shade(col["hair"], 1.6), 3, 1.6 * s, rng, vertical=True, alpha=0.35, dry=0.6)
    if "lamp" in masks:
        c.wash(masks["lamp"], mix(col["lamp"], hex_rgb("fff3d6"), 0.35), variation=0.04, blotch=10 * s)
    c.dilate_from(used)
    paint_creases(c, pm, size, {"skin", "garment", "trim", "legs", "hat", "prop", "lamp", "shoe"},
                  mix(INK_BROWN, hex_rgb("efe4cc"), 0.12), 2.2 * s, 0.7, rng, alpha=0.8)
    c.soften(0.5)
    c.save(out)


def fade(src, out):
    """Drained paper: colour gone, values lifted and flattened toward a cool paper grey, ink kept."""
    a = np.asarray(Image.open(src).convert("RGB")).astype(float) / 255.0
    lum = a @ np.array([0.299, 0.587, 0.114])
    flat = 0.62 + 0.38 * lum
    ink = np.clip((0.35 - lum) / 0.35, 0.0, 1.0)
    v = flat * (1.0 - ink) + lum * ink
    paper = np.array(FADED_PAPER)
    rgb = v[..., None] * (paper / paper.max())
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8)).save(out)


def main(spec_path, name, pm_path):
    spec = FS.load(spec_path)
    person = FS.person(spec, name)
    paths = FS.paths(spec, name)
    out, faded = ROOT / paths["texture"], ROOT / paths["faded"]
    out.parent.mkdir(parents=True, exist_ok=True)
    paint(person, load(pm_path), str(out))
    fade(out, faded)
    print("TEXTURE folk %s %d %s" % (name, load(pm_path)["size"], paths["texture"]))


if __name__ == "__main__":
    main(*sys.argv[1:4])
