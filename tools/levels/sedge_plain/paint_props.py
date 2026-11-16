"""Paint each Sedge Plain prop's albedo from the paint map its Blender generator wrote.

    python tools/levels/sedge_plain/paint_props.py <model> <paintmap.json> <out_dir>

Uses the shared recipe tools/textures/painted/paint_models.py (paint_prop: a flat wash per tag,
cracks on stone, fans on canopy, fibres on wood and rope, brown creases) with this level's extra
tag colours, and draws a little map in ink on the "map" faces of Tamsin's lost leaves.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "textures" / "painted"))
import paint_models as PM  # noqa: E402
from inkpaint import INK, Canvas, hex_rgb  # noqa: E402

PM.TAG_WASH.update({
    "rope": "a48c5f", "cloth": "b8a57d", "leather": "7d6249", "map": "ece2cb",
    "stone": "b0ab9c", "stone_top": "c2bdae", "canopy": "8fa46a", "canopy_under": "6f8556",
})
SEEDS = {"stone_tall": 301, "stone_lean": 302, "stone_capped": 303, "stone_fallen": 304, "tie_post": 305,
         "bridge_wreck": 306, "tamsin_camp": 307, "map_leaf": 308, "landing_stage": 309, "wood_tree": 310}


def draw_maps(pm, size, out, rng):
    """A river, a dotted road and three small hollow rings, the way Tamsin draws."""
    masks, used = PM.tag_masks(pm, size)
    if "map" not in masks:
        return
    c = Canvas(size, size, (1, 1, 1))
    c.img = np.asarray(Image.open(out).convert("RGB"), dtype=float) / 255.0
    for isl in PM.islands_of(masks["map"]):
        x0, y0, x1, y1, m = isl
        w, h = x1 - x0, y1 - y0
        if w * h < 100:
            continue
        pts = [(x0 + w * 0.05, y0 + h * (0.75 + 0.1 * math.sin(t * 3))) for t in np.linspace(0, 1, 2)]
        river = [(x0 + w * t, y0 + h * (0.8 - 0.15 * math.sin(t * 4.0 + 0.5))) for t in np.linspace(0.02, 0.98, 6)]
        c.stroke(river, max(2.0, w * 0.035), hex_rgb("3d5a68"), 0.85, taper=(0.1, 0.3), dry=0.2)
        for k in range(9):
            t = k / 8
            u, v = x0 + w * (0.15 + 0.7 * t), y0 + h * (0.65 - 0.45 * t + 0.08 * math.sin(t * 7))
            c.stroke([(u, v), (u + w * 0.03, v - h * 0.01)], max(1.4, w * 0.018), INK, 0.8, taper=(0.3, 0.3), dry=0.1)
        for k in range(3):
            cx, cy = x0 + w * (0.25 + 0.25 * k), y0 + h * (0.3 + 0.12 * (k % 2))
            r = w * 0.06
            ring = [(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.8) for a in np.linspace(0.2, 5.9, 9)]
            c.stroke(ring, max(1.4, w * 0.015), INK, 0.8, taper=(0.1, 0.3), dry=0.2)
        del pts
    c.save(out)


def main(model, pm_path, out_dir):
    pm = PM.load(pm_path)
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    out = str(Path(out_dir) / ("%s.png" % model))
    PM.paint_prop(pm, pm["size"], out, SEEDS[model])
    draw_maps(pm, pm["size"], out, np.random.default_rng(SEEDS[model]))
    print("TEXTURE", model, pm["size"])


if __name__ == "__main__":
    main(*sys.argv[1:4])
