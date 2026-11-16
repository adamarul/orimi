"""Top-down plan of Tallowford, drawn to scale from layout.py (the same data the terrain uses).

    python tools/levels/tallowford/plan.py <out.png>

Ground tint and 0.5 m contours come from layout.height(); paths, squares, houses, props, people,
markers, the sealed-fight circle and the route are drawn from the layout tables.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout as L  # noqa: E402

PX = 12.0                       # pixels per metre
X0, X1 = -42.0, 48.0
Z0, Z1 = -38.0, 38.0
MARGIN = 60
W = int((X1 - X0) * PX) + 2 * MARGIN
H = int((Z1 - Z0) * PX) + 2 * MARGIN + 40


def P(x, z):
    return (MARGIN + (x - X0) * PX, MARGIN + 40 + (z - Z0) * PX)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def rot_rect(c, w, d, yaw):
    pts = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        pts.append(P(*L.local_to_world(c, yaw, lx, lz)))
    return pts


def main(out):
    xs = np.linspace(X0, X1, int((X1 - X0) * PX))
    zs = np.linspace(Z0, Z1, int((Z1 - Z0) * PX))
    gx, gz = np.meshgrid(xs, zs)
    h = L.height(gx, gz)
    grass = np.array([152, 160, 120], float)
    hill = np.array([128, 140, 104], float)
    t = np.clip(h / 8.0, 0, 1)[..., None]
    img = grass * (1 - t) + hill * t
    shade = np.gradient(h, axis=1) * -0.9 + np.gradient(h, axis=0) * -0.9
    img = img * (1 + np.clip(shade, -0.25, 0.25))[..., None]
    pd = L.path_distance(gx, gz)
    img = np.where((pd < 0)[..., None], np.array([214, 199, 160], float), img)
    paved = np.zeros(h.shape, bool)
    for (cx, cz), r in ((L.SQUARE_C, L.SQUARE_R), (L.JETTY_SQ_C, L.JETTY_SQ_R), (L.WELL_C, L.WELL_YARD_R)):
        paved |= np.hypot(gx - cx, gz - cz) < r
    img = np.where(paved[..., None], np.array([196, 192, 178], float), img)
    dye = np.hypot(gx - L.DYE_YARD_C[0], gz - L.DYE_YARD_C[1]) < L.DYE_YARD_R
    img = np.where(dye[..., None], np.array([186, 164, 128], float), img)
    water = h < L.WATER_Y
    img = np.where(water[..., None], np.array([127, 160, 166], float), img)
    # contours every 0.5 m (every 2 m bold)
    for step, col, thick in ((0.5, 0.82, 1), (2.0, 0.55, 2)):
        band = np.floor(h / step)
        edge = (np.abs(np.diff(band, axis=0, prepend=band[:1])) + np.abs(np.diff(band, axis=1, prepend=band[:, :1]))) > 0
        if thick > 1:
            edge = edge | np.roll(edge, 1, axis=0) | np.roll(edge, 1, axis=1)
        img = np.where((edge & ~water)[..., None], img * col, img)
    canvas = Image.new("RGB", (W, H), (239, 230, 210))
    canvas.paste(Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), (MARGIN, MARGIN + 40))
    d = ImageDraw.Draw(canvas)
    f_small, f_mid, f_big = font(11), font(14), font(20)

    # grid
    for x in range(-40, 50, 10):
        d.line([P(x, Z0), P(x, Z1)], fill=(120, 110, 95), width=1)
        d.text((P(x, Z0)[0] - 8, P(x, Z0)[1] - 16), "%d" % x, fill=(60, 50, 40), font=f_small)
    for z in range(-30, 40, 10):
        d.line([P(X0, z), P(X1, z)], fill=(120, 110, 95), width=1)
        d.text((MARGIN - 34, P(X0, z)[1] - 7), "%d" % z, fill=(60, 50, 40), font=f_small)

    # fight circle
    cx, cz = P(*L.JETTY_SQ_C)
    r = L.FIGHT_R * PX
    for a in range(0, 360, 12):
        a0, a1 = math.radians(a), math.radians(a + 7)
        d.line([(cx + r * math.cos(a0), cz + r * math.sin(a0)), (cx + r * math.cos(a1), cz + r * math.sin(a1))], fill=(179, 32, 42), width=3)

    # props
    props = L.props()
    for m, x, z, yaw, s in props:
        if m.startswith("house_") or m in ("shed", "cottage"):
            continue
        X, Z = P(x, z)
        if m == "lamp_post":
            d.ellipse([X - 5, Z - 5, X + 5, Z + 5], fill=(217, 164, 65), outline=(27, 26, 28), width=2)
        elif m == "persimmon":
            d.ellipse([X - 30, Z - 30, X + 30, Z + 30], outline=(40, 34, 30), width=2)
            d.ellipse([X - 6, Z - 6, X + 6, Z + 6], fill=(40, 34, 30))
        elif m == "well":
            d.ellipse([X - 12, Z - 12, X + 12, Z + 12], fill=(140, 138, 128), outline=(27, 26, 28), width=2)
            d.ellipse([X - 6, Z - 6, X + 6, Z + 6], fill=(40, 40, 44))
        elif m == "dye_vats":
            for k in (-1, 0, 1):
                vx, vz = L.local_to_world((x, z), yaw, k * 2.0, 0.0)
                VX, VZ = P(vx, vz)
                d.ellipse([VX - 9, VZ - 9, VX + 9, VZ + 9], fill=[(78, 95, 122), (165, 88, 74), (201, 169, 78)][k + 1], outline=(27, 26, 28), width=2)
        elif m == "thorn_gate":
            a = math.radians(-yaw)
            hw = 3.8 * s * PX
            d.line([(X - math.cos(a) * hw, Z - math.sin(a) * hw), (X + math.cos(a) * hw, Z + math.sin(a) * hw)], fill=(20, 20, 22), width=3)
        elif m in ("jetty", "landing"):
            ln, wd = (L.JETTY_LEN, L.JETTY_W) if m == "jetty" else (L.LANDING_LEN, L.LANDING_W)
            d.rectangle([P(x, z - wd / 2), P(x + ln, z + wd / 2)], fill=(110, 90, 70), outline=(27, 26, 28), width=2)
        elif m == "ford_lamp":
            d.rectangle([X - 14, Z - 14, X + 14, Z + 14], fill=(140, 138, 128), outline=(27, 26, 28), width=2)
            d.ellipse([X - 8, Z - 8, X + 8, Z + 8], fill=(217, 164, 65), outline=(27, 26, 28), width=2)
        elif m == "stepping_stone":
            d.ellipse([X - 7, Z - 6, X + 7, Z + 6], fill=(150, 148, 140), outline=(27, 26, 28))
        elif m == "fence":
            a = math.radians(-yaw)
            hw = 2.0 * s * PX
            d.line([(X - math.cos(a) * hw, Z - math.sin(a) * hw), (X + math.cos(a) * hw, Z + math.sin(a) * hw)], fill=(90, 70, 50), width=2)
        elif m in ("cloth_line", "drying_rack"):
            a = math.radians(-yaw)
            hw = (2.4 if m == "cloth_line" else 1.2) * PX
            d.line([(X - math.cos(a) * hw, Z - math.sin(a) * hw), (X + math.cos(a) * hw, Z + math.sin(a) * hw)],
                   fill=(78, 95, 122) if m == "cloth_line" else (236, 227, 205), width=5)
        elif m == "reeds":
            d.ellipse([X - 3, Z - 3, X + 3, Z + 3], fill=(120, 130, 80))
        elif m == "rocks":
            d.ellipse([X - 8 * s, Z - 6 * s, X + 8 * s, Z + 6 * s], fill=(140, 138, 128), outline=(27, 26, 28))
        elif m == "shrine":
            d.rectangle([X - 8, Z - 7, X + 8, Z + 7], fill=(207, 63, 42), outline=(27, 26, 28), width=2)

    # houses
    labels = {"house_trim": "1 Old Trim", "house_marrow": "2 Marrow", "house_brindle": "3 Brindle",
              "house_children": "4 Children's house", "house_ferry": "5 Ferry-house"}
    for name, c, w, dd, target, _ in L.HOUSES:
        yaw = L.face_yaw(c, target)
        d.polygon(rot_rect(c, w + 1.2, dd + 1.2, yaw), fill=(92, 82, 74), outline=(27, 26, 28))
        d.polygon(rot_rect(c, w, dd, yaw), outline=(236, 227, 205))
        door = L.house_points(c, w, dd, target)[1]
        DX, DZ = P(*door)
        d.ellipse([DX - 3, DZ - 3, DX + 3, DZ + 3], fill=(236, 227, 205))
        X, Z = P(*c)
        d.text((X - 34, Z - 8), labels[name], fill=(245, 240, 228), font=f_mid)
    for name, c, w, dd, target in L.SHEDS:
        yaw = L.face_yaw(c, target)
        d.polygon(rot_rect(c, w + 0.8, dd + 0.8, yaw), fill=(150, 138, 120), outline=(27, 26, 28))
    for name, c, w, dd, target in L.COTTAGES:
        yaw = L.face_yaw(c, target)
        d.polygon(rot_rect(c, w + 1.0, dd + 1.0, yaw), fill=(122, 110, 100), outline=(27, 26, 28))
        d.polygon(rot_rect(c, w, dd, yaw), outline=(220, 210, 190))

    # route
    M = L.all_markers()
    route = [M["M_Spawn"], (19.5, 23.0), M["M_Person_Trim"], (6.0, 9.5), (0.0, 3.5), (-8.5, -3.0), (-16.5, -0.5), M["M_DyeVats"],
             (-18.0, 7.0), (-10.5, 12.0), M["M_Well"], (-4.5, 6.5), (-3.0, -6.0), M["M_Door_Children"], (0.0, -9.0), (9.2, -3.0),
             M["M_Door_Ferry"], M["M_Fight"], (23.0, -11.0), (24.8, -21.5), M["M_FordLamp"]]
    pts = [P(p[0], p[2]) if len(p) == 3 else P(*p) for p in route]
    for a, b in zip(pts, pts[1:]):
        d.line([a, b], fill=(213, 64, 43), width=2)
    beats = [("A", M["M_Spawn"]), ("1", M["M_Kindle_Trim"]), ("2", M["M_DyeVats"]), ("3", M["M_Well"]), ("4", M["M_Persimmon"]),
             ("5", M["M_Fight"]), ("6", M["M_FordLamp"])]
    for label, p in beats:
        X, Z = P(p[0], p[2])
        d.ellipse([X - 11, Z - 11 - 22, X + 11, Z + 11 - 22], fill=(213, 64, 43), outline=(255, 255, 255), width=2)
        d.text((X - 4, Z - 30), label, fill=(255, 255, 255), font=f_mid)

    # people and verse-stones
    for k, (p, yaw) in L.people().items():
        X, Z = P(*p)
        d.polygon([(X, Z - 7), (X - 5, Z + 5), (X + 5, Z + 5)], fill=(236, 227, 205), outline=(27, 26, 28))
        d.text((X + 6, Z - 2), k.replace("M_Person_", "").replace("Neighbour_", "N"), fill=(27, 26, 28), font=f_small)
    for k in ("M_Verse_1", "M_Verse_2"):
        x, y, z = M[k]
        X, Z = P(x, z)
        d.rectangle([X - 5, Z - 7, X + 5, Z + 7], fill=(90, 90, 96), outline=(217, 164, 65), width=2)
        d.text((X + 7, Z - 6), "verse " + k[-1], fill=(27, 26, 28), font=f_small)
    X, Z = P(M["M_Spawn"][0], M["M_Spawn"][2])
    d.text((X - 70, Z + 8), "M_Spawn (raft lands)", fill=(27, 26, 28), font=f_small)
    X, Z = P(*L.JETTY_SQ_C)
    d.text((X - 48, Z + 34), "sealed fight, 10 m", fill=(140, 20, 30), font=f_small)

    # title, scale bar, north
    d.text((MARGIN, 14), "Tallowford: plan, 1 square = 10 m (drawn from tools/levels/tallowford/layout.py)", fill=(27, 26, 28), font=f_big)
    sx, sz = P(X0 + 2, Z1 - 3)
    d.rectangle([sx, sz, sx + 10 * PX, sz + 6], fill=(27, 26, 28))
    d.text((sx, sz + 8), "10 m", fill=(27, 26, 28), font=f_mid)
    nx, nz = P(X1 - 3, Z0 + 5)
    d.polygon([(nx, nz - 22), (nx - 8, nz), (nx + 8, nz)], fill=(27, 26, 28))
    d.text((nx - 5, nz + 2), "N", fill=(27, 26, 28), font=f_mid)
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, optimize=True)
    print("PLAN", out, canvas.size)


if __name__ == "__main__":
    main(sys.argv[1])
