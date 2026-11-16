"""Project icon: an ink ring on warm paper with a vermilion seal dot (original, generated).

    python tools/gen/icon.py <out.png>
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 128


def main(out):
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    cx = cy = (SIZE - 1) / 2
    r = np.hypot(x - cx, y - cy)
    ang = np.arctan2(y - cy, x - cx)
    rng = np.random.default_rng(3)
    paper = np.array([236, 226, 204], np.float32) + rng.normal(0, 4, (SIZE, SIZE, 1))
    img = np.broadcast_to(paper, (SIZE, SIZE, 3)).copy()
    # Brush ring: thickness swells and thins around the circle, with a dry gap near the top right.
    width = 7 + 5 * np.sin(ang * 1.0 + 0.6) + 2 * np.sin(ang * 5.0)
    ring = np.clip(1.0 - np.abs(r - 44) / np.maximum(width, 1.0), 0, 1)
    gap = (ang > -1.1) & (ang < -0.75)
    ring[gap] *= 0.15
    ink = np.array([28, 24, 30], np.float32)
    img = img * (1 - ring[..., None]) + ink * ring[..., None]
    dot = np.clip(1.0 - (np.hypot(x - cx - 18, y - cy + 18) - 9) / 2.0, 0, 1)
    img = img * (1 - dot[..., None]) + np.array([200, 62, 40], np.float32) * dot[..., None]
    alpha = np.clip((60 - r) / 2.0, 0, 1) * 255
    rgba = np.dstack([np.clip(img, 0, 255), alpha]).astype(np.uint8)
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba).save(out)
    print("ICON", out)


if __name__ == "__main__":
    main(sys.argv[1])
