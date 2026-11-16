"""Draw the top-down plan and the climb section of the Hollow Kiln from kiln_layout.py, the same
data the terrain and the buildings are generated from.

    python -I tools/levels/hollow_kiln/plan.py <out_dir>

Writes plan.png (top view, 10 px per metre, north up) and section.png (the climb, side view).
"""
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import kiln_layout as K  # noqa: E402

PX = 10.0
X0, X1 = -30.0, 30.0
Z0, Z1 = -102.0, 66.0
W, H = int((X1 - X0) * PX), int((Z1 - Z0) * PX)
MARGIN_L, MARGIN_T = 70, 60
PAPER = (239, 230, 210)
INK = (27, 26, 28)
SEPIA = (107, 74, 43)
VERM = (213, 64, 43)
GOLD = (217, 164, 65)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


F_S, F_M, F_L = font(11), font(14), font(20)


def P(x, z):
    return (MARGIN_L + (x - X0) * PX, MARGIN_T + (z - Z0) * PX)


def rect(d, xr, zr, **kw):
    (a, b), (c, e) = P(xr[0], min(zr)), P(xr[1], max(zr))
    d.rectangle([a, b, c, e], **kw)


def label(d, xy, text, f=F_S, fill=INK, anchor="la", bg=True):
    if bg:
        box = d.textbbox(xy, text, font=f, anchor=anchor)
        d.rectangle([box[0] - 2, box[1] - 1, box[2] + 2, box[3] + 1], fill=PAPER)
    d.text(xy, text, font=f, fill=fill, anchor=anchor)


def ground_image():
    xs = X0 + (np.arange(W) + 0.5) / PX
    zs = Z0 + (np.arange(H) + 0.5) / PX
    gx, gz = np.meshgrid(xs, zs)
    h = K.height(gx, gz)
    dx = np.gradient(h, axis=1) * PX
    dz = np.gradient(h, axis=0) * PX
    shade = np.clip(0.75 + 0.18 * (-dx * 0.6 - dz * 0.8) / np.sqrt(1 + dx * dx + dz * dz), 0.4, 1.0)
    t = np.clip((h + 2.0) / 40.0, 0, 1)[..., None]
    low, high = np.array([200, 205, 178]), np.array([170, 160, 140])
    col = (low * (1 - t) + high * t) * shade[..., None]
    contour = np.abs(((h + 100.0) / 2.0) % 1.0 - 0.5) > 0.47
    col[contour] = col[contour] * 0.78
    sd = K.stream_distance(gx, gz)
    water = (sd < K.STREAM_HALF) & (gz > K.YARD["z"][1])
    col[water] = (60, 62, 70)
    race = K.in_rect(gx, gz, K.RACE["x"], K.RACE["z"])
    col[race] = (60, 62, 70)
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)), h


def draw_plan(out):
    img = Image.new("RGB", (W + MARGIN_L + 260, H + MARGIN_T + 60), PAPER)
    g, h = ground_image()
    img.paste(g, (MARGIN_L, MARGIN_T))
    d = ImageDraw.Draw(img)
    # grid
    for x in range(int(X0), int(X1) + 1, 10):
        a, b = P(x, Z0), P(x, Z1)
        d.line([a, b], fill=(150, 140, 120), width=1)
        label(d, (a[0], MARGIN_T - 6), "x %d" % x, anchor="ms", bg=False)
    for z in range(int(math.ceil(Z0 / 10)) * 10, int(Z1) + 1, 10):
        a, b = P(X0, z), P(X1, z)
        d.line([a, b], fill=(150, 140, 120), width=1)
        label(d, (MARGIN_L - 6, a[1]), "z %d" % z, anchor="rm", bg=False)
    # buildings
    wall = dict(outline=INK, width=4)
    yx, yz = K.YARD["x"], K.YARD["z"]
    rect(d, yx, yz, **wall)
    rect(d, K.GATE["x"], (yz[1] - 0.6, yz[1] + 0.6), fill=PAPER)
    rect(d, K.HALL["x"], K.HALL["z"], fill=(222, 210, 186), **wall)
    rect(d, K.HALL_DOOR_S["x"], (K.HALL["z"][1] - 0.6, K.HALL["z"][1] + 0.6), fill=(222, 210, 186))
    rect(d, K.HALL_DOOR_N["x"], (K.HALL["z"][0] - 0.6, K.HALL["z"][0] + 0.6), fill=(150, 120, 90))
    rect(d, K.PASSAGE["x"], K.PASSAGE["z"], fill=(205, 192, 168), outline=INK, width=2)
    fx, fz, ft = K.FLUE["x"], K.FLUE["z"], K.FLUE["wall_t"]
    rect(d, (fx[0] - ft, fx[1] + ft), (fz[0] - ft, fz[1] + ft), fill=(40, 40, 44))
    rect(d, fx, fz, fill=(70, 68, 72))
    rect(d, K.VAT_PASSAGE["x"], K.VAT_PASSAGE["z"], fill=(205, 192, 168), outline=INK, width=2)
    cx, _, cz = K.DRUM_C
    for r, fill in ((K.DRUM_R + K.DRUM_T, INK), (K.DRUM_R, (214, 200, 176))):
        a, b = P(cx - r, cz - r), P(cx + r, cz + r)
        d.ellipse([a, b], fill=fill)
    rect(d, K.VAT_PASSAGE["x"], (K.VAT_PASSAGE["z"][1] - 0.5, K.VAT_PASSAGE["z"][1] + 2.4), fill=(205, 192, 168))
    ch = K.CHIMNEY
    rect(d, (ch["c"][0] - ch["w0"] / 2, ch["c"][0] + ch["w0"] / 2), (ch["c"][1] - ch["w0"] / 2, ch["c"][1] + ch["w0"] / 2), fill=(90, 80, 72), outline=INK, width=3)
    label(d, P(ch["c"][0] + 4, ch["c"][1]), "chimney (top y %.0f)" % ch["top"])
    # hall contents: cursed floor, planks, drifts, racks, posts
    hx, hz, t = K.HALL["x"], K.HALL["z"], K.HALL["wall_t"]
    rect(d, (hx[0] + t, hx[1] - t), (hz[0] + t, hz[1] - t), fill=(58, 44, 46))
    for name, (xr, zr) in K.PLANKS.items():
        rect(d, xr, zr, fill=(206, 176, 128), outline=SEPIA, width=1)
        label(d, P((xr[0] + xr[1]) / 2, (zr[0] + zr[1]) / 2), name, anchor="mm", bg=False)
    for name, (x, z, w) in K.SOOT_DRIFTS.items():
        a, b = P(x - w / 2, z - 1.6), P(x + w / 2, z + 1.6)
        d.ellipse([a, b], fill=(30, 30, 34))
        label(d, P(x, z), name, fill=(230, 230, 230), anchor="mm", bg=False)
    for z, (x0, x1) in K.RACK_ROWS:
        for a0, a1 in [(-11.0, -6.2), (-5.2, -0.4), (0.6, 5.4), (6.4, 11.0)]:
            d.line([P(a0, z), P(a1, z)], fill=(225, 225, 220), width=3)
    for x, z in K.HALL_POSTS:
        rect(d, (x - 0.3, x + 0.3), (z - 0.3, z + 0.3), fill=INK)
    # flue ledges
    for name, xr, zr, y0, y1, axis, sgn in K.FLUE_LEDGES:
        rect(d, xr, zr, fill=(150, 140, 125), outline=(30, 30, 30), width=1)
        lx, lz = (xr[0] + xr[1]) / 2, (zr[0] + zr[1]) / 2
        txt = "%s %.1f" % (name, y0) if abs(y1 - y0) < 0.05 else "%s %.1f>%.1f" % (name, y0, y1)
        label(d, P(lx, lz), txt, anchor="mm")
    for name, (x, y, z) in K.MOSS.items():
        a, b = P(x - 0.8, z - 0.8), P(x + 0.8, z + 0.8)
        d.ellipse([a, b], fill=(110, 150, 80), outline=INK)
        label(d, P(x + 1.2, z), "%s y%.1f" % (name, y))
    for name, (x, y, z) in K.FLUE_LAMPS.items():
        a, b = P(x - 0.6, z - 0.6), P(x + 0.6, z + 0.6)
        d.ellipse([a, b], fill=GOLD, outline=INK)
        label(d, P(x + 1.0, z + 1.2), name)
    # vat chamber
    vx, vz = K.VAT["c"]
    a, b = P(vx - K.VAT["r"], vz - K.VAT["r"]), P(vx + K.VAT["r"], vz + K.VAT["r"])
    d.ellipse([a, b], fill=(40, 36, 40), outline=INK, width=3)
    label(d, P(vx, vz), "VAT", fill=(240, 240, 240), anchor="mm", bg=False)
    for nm in ("W", "E"):
        px, pz = K.PILLARS[nm]
        a, b = P(px - 0.9, pz - 0.9), P(px + 0.9, pz + 0.9)
        d.ellipse([a, b], fill=VERM, outline=INK, width=2)
    d.line([P(*K.PILLARS["W"]), P(*K.PILLARS["E"])], fill=VERM, width=1)
    label(d, P(K.PILLARS["E"][0] + 1.4, K.PILLARS["E"][1]), "pillar E (Tie)")
    label(d, P(K.PILLARS["W"][0] - 1.4, K.PILLARS["W"][1]), "pillar W (Tie)", anchor="ra")
    for nm, (mx, mz, ang) in K.KILN_MOUTHS.items():
        a, b = P(mx - 1.4, mz - 1.4), P(mx + 1.4, mz + 1.4)
        d.ellipse([a, b], fill=(160, 70, 40), outline=INK, width=2)
        label(d, P(mx, mz - 2.2), "mouth " + nm, anchor="ms")
    for ang in K.CHAIN_ANGLES:
        r = K.VAT["r"] - 0.5
        ex, ez = vx + math.cos(math.radians(ang)) * r, vz + math.sin(math.radians(ang)) * r
        d.line([P(ex, ez), P(vx, vz)], fill=(200, 200, 200), width=1)
    # yard
    for nm in ("M_Brazier_W", "M_Brazier_E"):
        x, y, z = K.MARKERS[nm]
        a, b = P(x - 0.8, z - 0.8), P(x + 0.8, z + 0.8)
        d.ellipse([a, b], fill=GOLD, outline=INK, width=2)
    d.line([P(K.GATE["x"][0], K.GATE["z"]), P(K.GATE["x"][1], K.GATE["z"])], fill=(20, 20, 20), width=6)
    label(d, P(4, 30.8), "gate: ink cord (Slash)")
    label(d, P(6.8, 35.4), "braziers (Kindle)")
    rect(d, K.GATE_STAIR["x"], K.GATE_STAIR["z"], outline=SEPIA, width=2)
    for k in range(9):
        z = 35.5 + k * 0.5
        d.line([P(-4, z), P(4, z)], fill=SEPIA, width=1)
    rect(d, K.HALL_STAIR["x"], K.HALL_STAIR["z"], outline=SEPIA, width=2)
    for k in range(17):
        z = 0.6 + k * 0.5
        d.line([P(-15, z), P(-9, z)], fill=SEPIA, width=1)
    jx, jz = next((p[1], p[3]) for p in K.PROPS if p[0] == "raft_jetty")
    rect(d, (jx - 2.0, jx + 2.0), (jz - 2.5, jz + 2.5), fill=(150, 120, 85), outline=INK, width=2)
    label(d, P(jx + 2.6, jz - 2.0), "jetty, raft", anchor="la")
    rect(d, (-15.4, -11.8), (21.0, 27.0), fill=(130, 100, 70), outline=INK, width=1)
    label(d, P(-13.6, 24.0), "logs", fill=(240, 230, 220), anchor="mm", bg=False)
    # fights
    for name, f in K.FIGHTS.items():
        cx, cy, cz = f["centre"]
        if f["radius"] > 0:
            a, b = P(cx - f["radius"], cz - f["radius"]), P(cx + f["radius"], cz + f["radius"])
            d.ellipse([a, b], outline=(150, 20, 30), width=3)
        for w, wave in enumerate(f["waves"]):
            for kind, (ox, oy, oz) in wave:
                x, z = cx + ox, cz + oz
                r = 0.5 if kind == "splotchet" else 0.8
                a, b = P(x - r, z - r), P(x + r, z + r)
                d.ellipse([a, b], fill=(20, 20, 20) if w == 0 else (120, 20, 30), outline=(240, 240, 240))
    label(d, P(-6.5, 10.6), "sealed fight r 6 m: wave 1 black, wave 2 red", anchor="la")
    # people
    for name, pinfo in K.PEOPLE.items():
        x, y, z = pinfo["at"]
        a, b = P(x - 0.7, z - 0.7), P(x + 0.7, z + 0.7)
        d.rectangle([a, b], fill=(90, 130, 160), outline=INK, width=2)
        label(d, P(x + 1.2, z - 0.4), name, f=F_M)
    # route
    pts = [P(x, z) for x, z in K.PATH]
    d.line(pts, fill=VERM, width=2)
    # markers
    for name, (x, y, z) in K.MARKERS.items():
        if not (X0 <= x <= X1 and Z0 <= z <= Z1):
            continue
        a, b = P(x - 0.35, z - 0.35), P(x + 0.35, z + 0.35)
        d.ellipse([a, b], fill=VERM)
    for name, (x, y, z) in K.MARKERS.items():
        if name.startswith("M_Verse"):
            a, b = P(x - 0.7, z - 0.7), P(x + 0.7, z + 0.7)
            d.polygon([(a[0] + (b[0] - a[0]) / 2, a[1]), (b[0], b[1]), (a[0], b[1])], fill=(80, 80, 76), outline=INK)
            label(d, P(x - 1.2, z + 1.6), "verse-stone " + name[-1], anchor="ra")
    # titles and legend
    label(d, P(-26.5, 58.5), "landing  y 0", f=F_M)
    label(d, P(-15.5, 31.0), "yard  y 2", f=F_M)
    label(d, P(-17.5, -3.4), "drying hall  y 5", f=F_M, fill=(240, 230, 210), bg=False)
    label(d, P(-16.8, -48.6), "flue  y 3 (ink) to 18", f=F_M, anchor="ls")
    label(d, P(-11.0, -79.5), "vat chamber  y %d, dome to %d" % (K.Y_VAT, K.Y_VAT + K.DRUM_WALL_H + K.DOME_RISE), f=F_M)
    label(d, P(-27.0, -63.0), "terrace\ny 18", f=F_S)
    lx = W + MARGIN_L + 14
    y = MARGIN_T
    d.text((lx, y), "The Hollow Kiln: plan", font=F_L, fill=INK)
    y += 30
    for text in ["10 px = 1 m, grid 10 m, north up", "contours every 2 m", "", "red line: walking route",
                 "red dots: M_* markers", "tan: safe planks (hall)", "dark ellipses: soot drifts D1-D6",
                 "plum floor: cursed (keeps you out)", "white bars: paper drying racks", "grey: flue ledges, y in m",
                 "green dots: moss footholds (Bloom)", "gold dots: lamps (Kindle), braziers", "vermilion: tie pillars",
                 "rust: kiln mouths (Kindle)", "blue squares: people", "grey triangles: verse-stones",
                 "black water: the Spill (ink race, stream)"]:
        d.text((lx, y), text, font=F_S, fill=INK)
        y += 16
    # scale bar
    a = P(-26, 63.5)
    d.line([a, (a[0] + 10 * PX, a[1])], fill=INK, width=4)
    label(d, (a[0] + 5 * PX, a[1] - 6), "10 m", anchor="ms", bg=False)
    img.save(os.path.join(out, "plan.png"), optimize=True)
    return img.size


def draw_section(out):
    """The climb, seen from the east: z left to right (south to north), y up, 8 px per metre."""
    s = 8.0
    zs = np.arange(62.0, -102.0, -0.25)
    w, hgt = int(len(zs) * 0.25 * s) + 140, int(80 * s) + 80
    img = Image.new("RGB", (w, hgt), PAPER)
    d = ImageDraw.Draw(img)

    def Q(z, y):
        return (70 + (62.0 - z) * s, hgt - 40 - (y + 6.0) * s)
    ground_mid = K.height(np.zeros_like(zs) - 8.0, zs)
    d.polygon([Q(zs[0], -6)] + [Q(z, y) for z, y in zip(zs, ground_mid)] + [Q(zs[-1], -6)], fill=(200, 196, 170))
    for y in range(-5, 71, 5):
        d.line([Q(62, y), Q(-102, y)], fill=(215, 205, 185))
        d.text((8, Q(0, y)[1] - 6), "y %d" % y, font=F_S, fill=INK)
    for z in range(60, -101, -10):
        d.text((Q(z, 0)[0] - 10, hgt - 30), "z %d" % z, font=F_S, fill=INK)

    def box(z0, z1, y0, y1, **kw):
        d.rectangle([Q(max(z0, z1), y1), Q(min(z0, z1), y0)], **kw)
    box(K.YARD["z"][0], K.YARD["z"][1], K.Y_YARD, K.Y_YARD + K.YARD["wall_h"], outline=INK, width=2)
    hz = K.HALL["z"]
    box(hz[0], hz[1], K.Y_HALL, K.Y_HALL + K.HALL["eave"], fill=(222, 210, 186), outline=INK, width=2)
    d.polygon([Q(hz[1], K.Y_HALL + K.HALL["eave"]), Q((hz[0] + hz[1]) / 2, K.Y_HALL + K.HALL["ridge"]), Q(hz[0], K.Y_HALL + K.HALL["eave"])], outline=INK, fill=(150, 120, 100))
    fz = K.FLUE["z"]
    box(fz[0], fz[1], K.FLUE["base"], K.FLUE["roof"], fill=(90, 88, 92), outline=INK, width=2)
    box(fz[0], fz[1], K.FLUE["base"], K.FLUE["ink0"], fill=(20, 20, 24))
    for name, xr, zr, y0, y1, axis, sgn in K.FLUE_LEDGES:
        if axis == "z":
            za, zb = (zr[1], zr[0]) if sgn < 0 else (zr[0], zr[1])
            d.line([Q(za, y0), Q(zb, y1)], fill=(230, 220, 200), width=3)
        else:
            zc = (zr[0] + zr[1]) / 2
            d.line([Q(zc - 0.8, y0), Q(zc + 0.8, y1)], fill=(230, 220, 200), width=3)
        d.text(Q((zr[0] + zr[1]) / 2, max(y0, y1) + 0.4), name, font=F_S, fill=(240, 240, 240))
    d.line([Q(fz[0], K.FLUE["ink_max"]), Q(fz[1], K.FLUE["ink_max"])], fill=(160, 30, 40), width=1)
    d.text(Q(fz[1] - 0.5, K.FLUE["ink_max"] + 1.6), "ink stops rising at y %.0f" % K.FLUE["ink_max"], font=F_S, fill=(240, 200, 200))
    cz, r = K.DRUM_C[2], K.DRUM_R
    box(cz - r - K.DRUM_T, cz + r + K.DRUM_T, K.Y_VAT, K.Y_VAT + K.DRUM_WALL_H, fill=(214, 200, 176), outline=INK, width=2)
    spring = K.Y_VAT + K.DRUM_WALL_H
    rise = K.DOME_RISE + K.DRUM_T
    d.chord([Q(cz + r + K.DRUM_T, spring + rise), Q(cz - r - K.DRUM_T, spring - rise)], 180, 360, fill=(190, 176, 150), outline=INK, width=2)
    a, b = Q(cz + K.OCULUS_R, spring + rise), Q(cz - K.OCULUS_R, spring + rise)
    d.line([a, b], fill=PAPER, width=4)
    d.text((b[0] + 6, b[1] - 14), "oculus, y %.0f" % (spring + K.DOME_RISE), font=F_S, fill=INK)
    vz = K.VAT["c"][1]
    box(vz - K.VAT["r"], vz + K.VAT["r"], K.Y_VAT, K.VAT["rim"], fill=(40, 36, 40))
    ch = K.CHIMNEY
    box(ch["c"][1] - ch["w0"] / 2, ch["c"][1] + ch["w0"] / 2, ch["base"], ch["top"], fill=(110, 96, 86), outline=INK, width=2)
    route = [(58, 0), (40, 0), (35.5, 2), (17, 2), (9, 2), (0.6, 5), (-5, 5.3), (-21, 5.3), (-26, 5), (-31, 5.6)]
    d.line([Q(z, y + 0.4) for z, y in route], fill=VERM, width=2)
    for name in ("M_Spawn", "M_Gate", "M_FightYard", "M_HallDoor", "M_FlueEntry", "M_FlueTop", "M_Vat", "M_EndView"):
        x, y, z = K.MARKERS[name]
        a = Q(z, y)
        d.ellipse([a[0] - 3, a[1] - 3, a[0] + 3, a[1] + 3], fill=VERM)
        d.text((a[0] + 4, a[1] - 14), name, font=F_S, fill=INK)
    # sight line from the middle of the yard to the dome top and the chimney
    eye = (17.0, K.Y_YARD + 1.5)
    for tgt in ((cz, spring + rise), (ch["c"][1], ch["top"])):
        d.line([Q(*eye), Q(*tgt)], fill=(90, 120, 160), width=1)
    d.text(Q(16, 4.5), "eye in the yard", font=F_S, fill=(60, 90, 130))
    d.text((70, 10), "The climb, seen from the east (section at x = -8, buildings drawn on their own lines). 8 px = 1 m.", font=F_M, fill=INK)
    img.save(os.path.join(out, "section.png"), optimize=True)
    return img.size


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    print("PLAN", draw_plan(out))
    print("SECTION", draw_section(out))
