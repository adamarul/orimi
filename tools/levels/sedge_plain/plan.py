"""Draw the Sedge Plain plan, top down and to scale, from layout.py (the same data the terrain uses).

    python tools/levels/sedge_plain/plan.py <out.jpg>

North is up (Godot -Z). One grid square is 10 m. Shading is the real height field; contour lines
every metre. Red dashed circles are the CurseField zones; sand is safe ground; red rings are the
sealed fights; numbered dots are markers (the legend lists them).
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout as L  # noqa: E402

X0, X1 = -72.0, 72.0
Z0, Z1 = -64.0, 76.0
PPM = 7.0
PAD_L, PAD_T, LEGEND_W = 46, 46, 430
W = int((X1 - X0) * PPM) + PAD_L + 20 + LEGEND_W
H = int((Z1 - Z0) * PPM) + PAD_T + 40


def px(x, z):
    return (PAD_L + (x - X0) * PPM, PAD_T + (z - Z0) * PPM)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main(out):
    nx, nz = int((X1 - X0) * PPM), int((Z1 - Z0) * PPM)
    xs = X0 + (np.arange(nx) + 0.5) / PPM
    zs = Z0 + (np.arange(nz) + 0.5) / PPM
    gx, gz = np.meshgrid(xs, zs)
    h = L.height(gx, gz)
    dz, dx = np.gradient(h, 1.0 / PPM)
    slope = np.hypot(dx, dz)
    shade = np.clip(0.78 + 0.22 * (-dx * 0.6 - dz * 0.8) / np.sqrt(1 + slope ** 2), 0.45, 1.1)

    col = np.empty((nz, nx, 3))
    col[:] = (0.70, 0.73, 0.58)
    hill = np.clip((h - 2.0) / 12.0, 0, 1)[..., None]
    col = col * (1 - hill) + np.array((0.74, 0.71, 0.64)) * hill
    rock = (slope > 1.0)[..., None]
    col = np.where(rock, np.array((0.60, 0.58, 0.54)), col)
    hollow = np.zeros((nz, nx), bool)
    for ho in L.HOLLOWS.values():
        cx, cz = ho["c"]
        ang = np.arctan2(gz - cz, gx - cx)
        hollow |= np.hypot(gx - cx, gz - cz) < L.hollow_radius(ho, ang, ho["rim_r"])
    col = np.where(hollow[..., None] & ~rock, np.array((0.33, 0.31, 0.32)), col)
    safe = L.safe_mask(gx, gz)
    col = np.where(safe[..., None], np.array((0.86, 0.80, 0.62)), col)
    path = L.path_distance(gx, gz) < L.PATH_HALF
    col = np.where((path & ~hollow)[..., None], np.array((0.88, 0.83, 0.68)), col)
    river = L.river_distance(gx, gz) < L.RIVER_HALF + 0.8
    col = np.where(river[..., None], np.array((0.55, 0.66, 0.70)), col)
    col = col * shade[..., None]
    # contour lines every metre, darker every 5 m
    for step, dark in ((1.0, 0.82), (5.0, 0.6)):
        q = np.floor(h / step)
        edge = (np.diff(q, axis=0, prepend=q[:1]) != 0) | (np.diff(q, axis=1, prepend=q[:, :1]) != 0)
        col = np.where(edge[..., None], col * dark, col)
    img = Image.new("RGB", (W, H), (244, 239, 226))
    img.paste(Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)), (PAD_L, PAD_T))
    d = ImageDraw.Draw(img)
    f_small, f_mid, f_big = font(11), font(13), font(17)

    # grid every 10 m with coordinates
    for x in range(-70, 71, 10):
        a, b = px(x, Z0), px(x, Z1)
        d.line([a, b], fill=(120, 116, 104), width=1)
        d.text((a[0] - 8, PAD_T - 16), "%d" % x, fill=(60, 56, 50), font=f_small)
    for z in range(-60, 76, 10):
        a, b = px(X0, z), px(X1, z)
        d.line([a, b], fill=(120, 116, 104), width=1)
        d.text((4, a[1] - 6), "%d" % z, fill=(60, 56, 50), font=f_small)
    # the plain's nominal 120 x 100 m
    d.rectangle([px(L.PLAIN_X[0], L.PLAIN_Z[0]), px(L.PLAIN_X[1], L.PLAIN_Z[1])], outline=(90, 110, 70), width=2)

    # paths and walk lines
    for name, pts in L.walk_lines().items():
        d.line([px(*p) for p in pts], fill=(150, 110, 60), width=2)
    # CurseField zones
    for key, ho in L.HOLLOWS.items():
        cx, cz = ho["c"]
        r = ho["zone_r"]
        for k in range(48):
            if k % 2:
                continue
            a0, a1 = 2 * math.pi * k / 48, 2 * math.pi * (k + 1) / 48
            d.line([px(cx + math.cos(a0) * r, cz + math.sin(a0) * r), px(cx + math.cos(a1) * r, cz + math.sin(a1) * r)], fill=(200, 40, 30), width=2)
        tx, ty = px(cx, cz + ho["rim_r"] + 1.0)
        d.text((tx - 30, ty), ho["name"], fill=(150, 20, 20), font=f_mid)
    # the Seam's name and the Knoll
    d.text(px(-55, -6), "the Seam (dry gully, 5 m deep)", fill=(40, 36, 32), font=f_mid)
    d.text(px(-8, -40.5), "the Knoll (+4 m)", fill=(40, 36, 32), font=f_mid)
    d.text(px(-30, 70.5), "the Lull  (flows east)", fill=(30, 60, 80), font=f_mid)
    d.text(px(-70, -61), "to the wood", fill=(40, 36, 32), font=f_mid)
    d.text(px(LEANING_LABEL[0], LEANING_LABEL[1]), "Leaning Stones", fill=(40, 36, 32), font=f_small)

    # sealed fights
    for k, f in L.FIGHTS.items():
        cx, cz = f["c"]
        r = f["r"] + f["patrol"]
        d.ellipse([px(cx - f["r"], cz - f["r"]), px(cx + f["r"], cz + f["r"])], outline=(180, 30, 30), width=3)
        if f["patrol"]:
            d.ellipse([px(cx - r, cz - r), px(cx + r, cz + r)], outline=(180, 80, 80), width=1)
        tx, ty = px(cx, cz)
        d.text((tx - 4, ty - 7), "F" + k, fill=(150, 20, 20), font=f_big)

    # props: stones as dark ticks, trees as rings
    for model, x, y, z, yaw, s in L.props():
        if model.startswith("stone"):
            d.ellipse([px(x - 0.7, z - 0.7), px(x + 0.7, z + 0.7)], fill=(40, 38, 36))
        elif model == "wood_tree":
            d.ellipse([px(x - 3, z - 3), px(x + 3, z + 3)], outline=(60, 80, 50), width=2)
        elif model == "tie_post":
            d.rectangle([px(x - 0.5, z - 0.5), px(x + 0.5, z + 0.5)], fill=(205, 150, 40), outline=(40, 30, 20))
        elif model == "tamsin_camp":
            d.polygon([px(x - 2, z + 1.5), px(x, z - 1.8), px(x + 2, z + 1.5)], outline=(40, 30, 20), fill=(236, 226, 205))
    # tie lines
    for key in L.BRIDGE_X:
        d.line([px(*L.seam_post(key, 1)), px(*L.seam_post(key, -1))], fill=(205, 150, 40), width=2)
    d.line([px(*L.MERE_BREAK[0]), px(*L.MERE_BREAK[1])], fill=(205, 150, 40), width=2)

    # markers, numbered
    marks = L.markers()
    skip = {"M_Fight_1", "M_Fight_2", "M_Fight_3", "M_Fight_4"}
    legend = []
    n = 0
    for name, (x, y, z) in marks.items():
        if name in skip:
            continue
        n += 1
        cx, cy = px(x, z)
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(20, 20, 24))
        d.text((cx + 4, cy - 12), str(n), fill=(20, 20, 24), font=f_small)
        legend.append("%2d %-22s (%6.1f, %5.1f, %6.1f)" % (n, name, x, y, z))

    # legend panel
    lx = PAD_L + int((X1 - X0) * PPM) + 20
    d.text((lx, 14), "Sedge Plain - plan (north up)", fill=(20, 20, 24), font=f_big)
    d.text((lx, 36), "1 square = 10 m; contours every 1 m", fill=(60, 56, 50), font=f_small)
    yy = 56
    for line in legend:
        d.text((lx, yy), line, fill=(30, 28, 26), font=f_small)
        yy += 14
    yy += 8
    for text, colr in [("sand: path / causeway / island (safe)", (150, 110, 60)), ("dark: hollow floor (cursed)", (60, 58, 60)),
                       ("red dashes: CurseField zone", (200, 40, 30)), ("red ring F#: sealed fight (pale: patrol)", (180, 30, 30)),
                       ("gold: tie post and Tie line", (190, 140, 30)), ("green ring: wood tree; black dot: standing stone", (60, 80, 50))]:
        d.text((lx, yy), text, fill=colr, font=f_small)
        yy += 14
    # scale bar and north arrow
    sx, sy = px(30, 74)
    d.line([(sx, sy), (sx + 20 * PPM, sy)], fill=(20, 20, 24), width=3)
    d.text((sx, sy - 16), "20 m", fill=(20, 20, 24), font=f_small)
    ax, ay = px(64, -58)
    d.polygon([(ax, ay - 18), (ax - 7, ay + 4), (ax + 7, ay + 4)], fill=(20, 20, 24))
    d.text((ax - 4, ay + 6), "N", fill=(20, 20, 24), font=f_mid)
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    img.save(out, quality=88)
    print("PLAN %s %dx%d markers=%d" % (Path(out).name, W, H, n))


LEANING_LABEL = (L.LEANING_STONES[0] + 6, L.LEANING_STONES[1] + 7)

if __name__ == "__main__":
    main(sys.argv[1])
