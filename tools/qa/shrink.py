"""Publish a capture as small evidence: a JPEG no wider than WIDTH px (default 1280).

    python -I tools/qa/shrink.py SRC.png DST.jpg [WIDTH] [QUALITY]

The harness keeps the full-size PNG under .userdata/qa/full/ for image statistics and writes only
this JPEG under docs/ (the docs/qa size budget is about 5 MB).
"""
import os
import sys

from PIL import Image


def main():
    src, dst = sys.argv[1], sys.argv[2]
    width = int(sys.argv[3]) if len(sys.argv) > 3 else 1280
    quality = int(sys.argv[4]) if len(sys.argv) > 4 else 80
    im = Image.open(src).convert("RGB")
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    im.save(dst, "JPEG", quality=quality, optimize=True, progressive=True)


if __name__ == "__main__":
    main()
