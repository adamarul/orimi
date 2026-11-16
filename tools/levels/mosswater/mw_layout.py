"""Mosswater Wood layout: every marker, pond, path, climb piece, tree and light, in Godot
coordinates, plus the height field. Pure Python + numpy.

The one source of truth for Level 4. Read by:
  tools/levels/mosswater/make_mw.py      terrain, water and markers (Blender)
  tools/levels/mosswater/paint_mw.py     painted ground and cliffs
  tools/levels/mosswater/plan.py         the top-down plan in docs/levels/mosswater/
  tools/levels/mosswater/export_layout.py  scripts/levels/mosswater/mosswater_layout.json (Godot)

Godot axes: X east, Y up, Z south. The wood climbs from the south-east (the river landing) to the
north-west (the spring). Most of the layout is written in slope coordinates:
  s = distance up the slope (north-west), t = distance across it (north-east positive).
  x = (t - s) / sqrt 2, z = -(s + t) / sqrt 2.
"""
import math

import numpy as np

SQ2 = math.sqrt(2.0)


def st_xz(s, t):
    return (t - s) / SQ2, -(s + t) / SQ2


def xz_st(x, z):
    return -(x + z) / SQ2, (x - z) / SQ2


# ------------------------------------------------------------------ tiers, cliffs, ponds
T0_NEAR, T1, T2 = 1.1, 7.0, 13.0          # ground of the three tiers (tier 0 rises from the river)
RIVER_S = -57.0                            # the Lull runs across the foot of the wood
RIVER_WATER_Y, RIVER_BED_Y = -0.35, -1.8
FAR_BANK = 8.0                             # the Lull's far bank rises this high, wooded, so the landing looks across at trees
SQUARE = 45.0                              # the level is the square |x|, |z| <= 45 (90 x 90 m)


def cliff1(t):
    return -6.5 + 0.9 * np.sin(0.31 * t + 1.3) + 0.6 * np.sin(0.83 * t + 0.2)


def cliff2(t):
    return 14.6 + 0.7 * np.sin(0.27 * t + 2.1) + 0.45 * np.sin(0.9 * t + 1.0)


CLIFF_HALF = 0.7          # half the run of a cliff face in s (6 m rise over 1.4 m)

PONDS = {
    # name: centre (s, t), radii (s, t), water y, display name
    "low": {"c": (-19.0, 3.0), "r": (8.0, 10.0), "water": 0.55, "name": "Wheel Pond"},
    "mid": {"c": (4.5, 1.0), "r": (7.0, 14.0), "water": 6.55, "name": "Lily Reach"},
    "high": {"c": (32.0, 3.0), "r": (8.0, 12.0), "water": 12.55, "name": "Willow Pool"},
}
POND_DEPTH = 1.6
ISLAND = {"c": (3.5, 3.0), "r": 2.2}
SPRING = {"c": (45.5, 1.5), "r": 2.0, "water": 13.15}

# Ground walls either side of the wood: |t| beyond these rises into wooded banks.
def strip_half_width(s):
    s = np.asarray(s, dtype=float)
    mid = smoothstep(-8.0, -5.0, s) * smoothstep(16.5, 14.0, s)
    return 20.0 - 3.5 * mid


# Water channels (s, t polylines): the outflow to the river, and the three falls' runnels.
CHANNEL = [(-27.0, 7.0), (-33.0, 7.4), (-40.0, 8.2), (-47.0, 8.6), (-53.0, 8.0), (-58.0, 7.6)]
RUNNELS = {
    "weir": [(-2.2, 5.0), (-5.6, 5.0), (-8.0, 4.8), (-11.2, 4.4)],       # middle pond to lower
    "notch": [(23.6, -2.5), (19.0, -2.5), (15.6, -2.5), (13.8, -2.3), (11.4, -2.0)],  # dam to middle
    "spring": [(45.5, 1.5), (43.6, 2.0), (40.6, 2.8)],                     # spring to upper pond
}
NOTCH_T = (-4.5, -0.5)          # the dam's spillway cut through the crest
DAM_S = 23.6                     # the dam wall along the upper pond's south-east edge
DAM_T = (-4.5, 12.5)
GULLY_BANK = (-4.6, 24.0)       # south-west of the notch the crest is a narrow ledge path

# Paths the player walks (s, t). Painted as paler ground; trees keep clear of them.
PATHS = {
    "walk": [(-51.0, 2.0), (-48.0, -3.0), (-44.0, -8.6), (-39.0, -12.6), (-34.0, -13.2), (-30.4, -9.6)],
    "wheel": [(-30.4, -9.6), (-29.8, -4.0), (-30.4, 2.4)],
    "shore": [(-30.4, -9.6), (-25.0, -10.8), (-19.0, -11.2), (-13.6, -10.4), (-10.6, -9.6)],
    "lily_shore": [(-5.0, -6.6), (-2.6, -6.4)],
    "nw_shore": [(12.6, 4.4), (12.4, 0.0), (11.6, -4.0), (11.6, -6.6)],
    "gully_foot": [(11.6, -6.6), (12.4, -7.4)],
    "gully_top": [(15.2, -14.4), (15.0, -10.0), (15.5, -5.6)],
    "crest": [(16.8, 0.6), (17.6, 3.4), (19.2, 6.5), (21.0, 11.0), (23.6, 15.2)],
    "upper": [(23.6, 15.2), (28.0, 17.4), (33.5, 17.6), (38.0, 15.6), (40.6, 11.8), (41.6, 8.4)],
}
PATH_HALF = 1.3

CLEARINGS = [  # (s, t, radius): flat, kept free of trees
    (-51.0, 2.0, 6.5),       # landing
    (-30.4, -10.4, 5.5),     # Fenn's clearing
    (-38.6, -12.6, 4.0),     # the dark hollow
    (19.2, 6.5, 6.0),        # the dam crest fight
    (42.5, 4.0, 5.0),        # the willow mound
]


def smoothstep(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash_noise(x, z, scale, seed):
    x = np.asarray(x, dtype=float) / scale + seed * 17.13
    z = np.asarray(z, dtype=float) / scale - seed * 9.71
    xi, zi = np.floor(x), np.floor(z)
    fx, fz = x - xi, z - zi
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)

    def h(a, b):
        v = np.sin(a * 127.1 + b * 311.7 + seed * 74.7) * 43758.5453
        return (v - np.floor(v)) * 2.0 - 1.0

    return (h(xi, zi) * (1 - fx) * (1 - fz) + h(xi + 1, zi) * fx * (1 - fz)
            + h(xi, zi + 1) * (1 - fx) * fz + h(xi + 1, zi + 1) * fx * fz)


def fbm(x, z, scale, seed, octaves=3):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * _hash_noise(x, z, scale / (2 ** o), seed + o)
        norm += amp
        amp *= 0.5
    return total / norm


def polyline_distance(a, b, pts):
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    best = np.full(np.broadcast(a, b).shape, np.inf)
    for (pa, pb), (qa, qb) in zip(pts[:-1], pts[1:]):
        da, db = qa - pa, qb - pb
        l2 = da * da + db * db
        u = np.clip(((a - pa) * da + (b - pb) * db) / l2, 0.0, 1.0)
        best = np.minimum(best, np.hypot(a - (pa + u * da), b - (pb + u * db)))
    return best


def pond_e(s, t, name):
    p = PONDS[name]
    return np.hypot((np.asarray(s) - p["c"][0]) / p["r"][0], (np.asarray(t) - p["c"][1]) / p["r"][1])


def path_distance(s, t):
    return np.min([polyline_distance(s, t, p) for p in PATHS.values()], axis=0)


def tier_ground(s, t):
    """Ground of the tiers and cliffs before ponds, channels and banks."""
    s = np.asarray(s, dtype=float)
    t = np.asarray(t, dtype=float)
    t0 = 0.25 + (T0_NEAR - 0.25) * smoothstep(-54.0, -36.0, s)
    c1, c2 = cliff1(t), cliff2(t)
    step1 = smoothstep(c1 - CLIFF_HALF, c1 + CLIFF_HALF, s)
    step2 = smoothstep(c2 - CLIFF_HALF, c2 + CLIFF_HALF, s)
    return t0 + (T1 - t0) * step1 + (T2 - T1) * step2


def height_st(s, t):
    s = np.asarray(s, dtype=float)
    t = np.asarray(t, dtype=float)
    x, z = st_xz(s, t)
    h = tier_ground(s, t)
    # soft hummocks of moss and root, kept off the paths and clearings
    calm = smoothstep(1.2, 4.0, path_distance(s, t))
    for cs, ct, cr in CLEARINGS:
        calm = calm * smoothstep(cr * 0.7, cr + 2.0, np.hypot(s - cs, t - ct))
    flat = 1.0 - smoothstep(0.6, 2.0, np.abs(s - cliff1(t))) - smoothstep(0.6, 2.0, np.abs(s - cliff2(t)))
    h = h + 0.35 * fbm(x, z, 7.0, 3) * calm * np.clip(flat, 0.0, 1.0)

    # the crest south-west of the notch is a narrow ledge under a high bank
    c2 = cliff2(t)
    bank = smoothstep(c2 + 2.6, c2 + 4.2, s) * smoothstep(GULLY_BANK[0] + 0.6, GULLY_BANK[0] - 0.8, t) * smoothstep(GULLY_BANK[1] + 1.0, GULLY_BANK[1] - 0.5, s)
    h = h + 7.0 * bank * (1.0 + 0.15 * fbm(x, z, 4.0, 13))

    # wooded banks either side
    hw = strip_half_width(s) + 1.6 * fbm(s, t, 9.0, 7)
    over = np.maximum(np.abs(t) - hw, 0.0)
    h = h + 13.0 * (1.0 - np.exp(-over / 6.0)) * smoothstep(0.0, 1.2, over) * (1.0 + 0.2 * fbm(x, z, 8.0, 12, 4))
    # beyond the head of the wood the ground keeps climbing
    h = h + 9.0 * (1.0 - np.exp(-np.maximum(s - 47.0, 0.0) / 6.0))

    # ponds: deep, still, black
    for name, p in PONDS.items():
        e = pond_e(s, t, name)
        bottom = p["water"] - POND_DEPTH
        h = np.where(e < 1.12, np.minimum(h, bottom + (h - bottom) * smoothstep(0.82, 1.1, e)), h)
    d = np.hypot(s - ISLAND["c"][0], t - ISLAND["c"][1])
    island = (T1 - 0.28) - (T1 - 0.28 - (PONDS["mid"]["water"] - POND_DEPTH)) * smoothstep(ISLAND["r"] * 0.75, ISLAND["r"] * 1.35, d)
    h = np.where(d < ISLAND["r"] * 1.4, np.maximum(h, island), h)
    d = np.hypot(s - SPRING["c"][0], t - SPRING["c"][1])
    h = np.where(d < SPRING["r"] * 1.6, np.minimum(h, SPRING["water"] - 0.8 + 1.2 * smoothstep(SPRING["r"] * 0.7, SPRING["r"] * 1.5, d)), h)

    # the outflow channel to the river, the spillway notch, the runnels
    cd = polyline_distance(s, t, CHANNEL)
    h = np.where(cd < 3.4, np.minimum(h, (h - 1.5) + 1.5 * smoothstep(1.2, 3.2, cd)), h)
    for name, pts in RUNNELS.items():
        rd = polyline_distance(s, t, pts)
        depth = 0.55 if name != "notch" else 0.45
        h = np.where(rd < 1.6, h - depth * (1.0 - smoothstep(0.5, 1.5, rd)), h)
    inside_notch = smoothstep(NOTCH_T[0] - 0.4, NOTCH_T[0] + 0.4, t) * smoothstep(NOTCH_T[1] + 0.4, NOTCH_T[1] - 0.4, t)
    across = smoothstep(c2 - 1.0, c2 + 0.2, s) * smoothstep(DAM_S + 0.6, DAM_S - 0.2, s)
    notch_bed = (T2 - 1.4) + 0.5 * smoothstep(c2, DAM_S, s)
    h = np.where(inside_notch * across > 0.0, h + (np.minimum(h, notch_bed) - h) * inside_notch * across, h)

    # the river at the foot of the wood, and its wooded far bank
    rs = s - RIVER_S
    far = np.maximum(-rs - 2.5, 0.0)
    h = np.where(rs < 0.0, 0.25 + FAR_BANK * (1.0 - np.exp(-far / 4.0)) * (1.0 + 0.2 * fbm(x, z, 8.0, 31, 4)), h)
    h = np.where(np.abs(rs) < 4.5, np.minimum(h, RIVER_BED_Y + (h - RIVER_BED_Y) * smoothstep(1.2, 4.5, np.abs(rs))), h)
    return h


def height(x, z):
    s, t = xz_st(np.asarray(x, dtype=float), np.asarray(z, dtype=float))
    return height_st(s, t)


def ground(s, t, lift=0.0):
    """(x, y, z) on the ground at slope coordinates (s, t)."""
    x, z = st_xz(s, t)
    return (round(float(x), 3), round(float(height_st(s, t)) + lift, 3), round(float(z), 3))


def at(s, t, y):
    x, z = st_xz(s, t)
    return (round(float(x), 3), round(float(y), 3), round(float(z), 3))


def yaw_toward(a, b):
    """Godot yaw in degrees for a node at a facing b (both (x, y, z)); models face -Z."""
    return round(math.degrees(math.atan2(-(b[0] - a[0]), -(b[2] - a[2]))), 1)


def yaw_st(ds, dt):
    """Godot yaw (degrees) for facing along slope direction (ds, dt)."""
    x0, z0 = st_xz(0.0, 0.0)
    x1, z1 = st_xz(ds, dt)
    return round(math.degrees(math.atan2(-(x1 - x0), -(z1 - z0))), 1)


# ------------------------------------------------------------------ climbs
STAIR_TREE = (-8.6, -7.6)              # giant trunk against the first bank, fungus shelves spiral up it
STAIR_RADIUS = 1.6


def stair_shelves():
    """Six bracket-fungus shelves spiralling up the stair tree, 1 m apart, from tier 0 to tier 1:
    the first on the open side away from the bank, the last against the bank's lip."""
    out = []
    base = float(height_st(*STAIR_TREE))
    for k in range(6):
        ang = math.radians(-30 + 42 * k)   # from the open, downhill side round to the bank's lip
        ds, dt = -math.cos(ang), math.sin(ang)
        s, t = STAIR_TREE[0] + ds * (STAIR_RADIUS + 0.75), STAIR_TREE[1] + dt * (STAIR_RADIUS + 0.75)
        top = base + 1.0 * (k + 1)
        out.append({"pos": at(s, t, top), "yaw": yaw_st(-ds, -dt), "top": round(top, 2)})
    return out


def _cliff_face(t, depth=0.55):
    return float(cliff2(t)) - CLIFF_HALF - depth


def crest_s(t, inset=1.5):
    """s of a point on top of the second bank, inset metres back from its edge."""
    return float(cliff2(t)) + CLIFF_HALF + inset


GULLY = [  # the four-glyph climb up the second bank, south-west along the face
    {"id": "L1", "kind": "ledge", "t": -7.0, "top": 8.0},
    {"id": "M1", "kind": "moss_shelf", "t": -8.5, "top": 9.0},
    {"id": "M2", "kind": "moss_shelf", "t": -10.0, "top": 10.0},
    {"id": "M3", "kind": "moss_shelf", "t": -11.5, "top": 11.0},
    {"id": "L2", "kind": "ledge", "t": -13.0, "top": 12.0},
    {"id": "L3", "kind": "ledge", "t": -14.5, "top": 12.9},
]


def gully_pieces():
    out = []
    for g in GULLY:
        s = _cliff_face(g["t"])
        out.append({"id": g["id"], "kind": g["kind"], "pos": at(s, g["t"], g["top"]), "yaw": yaw_st(-1.0, 0.0), "top": g["top"]})
    return out


# ------------------------------------------------------------------ markers
def build_markers():
    m = {}

    def g(name, s, t, lift=0.0):
        m[name] = ground(s, t, lift)

    g("M_Spawn", -51.0, 2.0)
    m["M_Raft"] = at(-56.6, 3.0, RIVER_WATER_Y)
    g("M_DarkHollow", -38.6, -12.6)
    g("M_FennHut", -32.6, -15.6)
    g("M_Fenn_1", -29.2, -7.4)
    g("M_Brazier", -30.6, -6.4)
    g("M_Verse_1", -31.6, 1.4)
    m["M_Wheel"] = at(-27.6, 7.0, PONDS["low"]["water"])
    g("M_WheelView", -30.4, 2.4)
    for name, key in (("M_PondLow", "low"), ("M_PondMid", "mid"), ("M_PondHigh", "high")):
        c = PONDS[key]["c"]
        m[name] = at(c[0], c[1], PONDS[key]["water"])
    g("M_StairTree", *STAIR_TREE)
    g("M_StairTop", -5.4, -6.6)
    lilies = [(-0.3, -5.5), (2.2, -3.6), (4.6, -1.4)]
    for i, (s, t) in enumerate(lilies):
        m["M_Lily_%d" % (i + 1)] = at(s, t, PONDS["mid"]["water"])
    g("M_Island", *ISLAND["c"])
    g("M_TiePost_A", 4.8, 4.2)
    g("M_Log", 5.3, 3.6)                       # the log's root, its pivot on the island
    m["M_LogEnd_Jammed"] = at(-2.2, 5.0, PONDS["mid"]["water"])
    g("M_LogEnd_Bridge", 12.8, 4.2)
    g("M_TiePost_B", 13.2, 5.6)
    m["M_Weir"] = at(-2.6, 5.0, PONDS["mid"]["water"])
    m["M_Flyers_Mid"] = at(ISLAND["c"][0], ISLAND["c"][1], PONDS["mid"]["water"] + 4.2)
    g("M_Fenn_2", 12.6, 8.2)
    g("M_Thorns", 11.9, -5.6)
    m["M_MossLantern"] = ground(12.6, -9.6, 2.9)
    g("M_SootBank", crest_s(-8.6), -8.6)
    g("M_TiePost_C", crest_s(-5.3), -5.3)
    g("M_TiePost_D", crest_s(0.3), 0.3)
    m["M_Notch"] = at(18.0, -2.5, T2 - 1.2)
    g("M_DamFight", 19.2, 6.5)
    m["M_Dam"] = at(DAM_S, 4.0, T2)
    m["M_Sluice"] = at(DAM_S, -2.5, T2)
    g("M_Verse_2", 37.0, 16.4)
    g("M_Fenn_3", 39.6, 9.8)
    g("M_Willow", 42.5, 4.0)
    m["M_Spring"] = at(SPRING["c"][0], SPRING["c"][1], SPRING["water"])
    g("M_Exit", 41.4, 8.6)
    for name in list(m):
        m[name] = tuple(float(v) for v in m[name])
    return m


LANTERNS = [  # lantern-fruit, hanging about 2.6 m above the ground; lit_at_start for the guide fruit
    {"id": "LF01", "st": (-47.8, -0.6), "lit": True, "beat": 1},
    {"id": "LF02", "st": (-43.4, -6.6), "lit": False, "beat": 1},
    {"id": "LF03", "st": (-40.2, -10.6), "lit": False, "beat": 1},
    {"id": "LF04", "st": (-35.6, -15.4), "lit": False, "beat": 1},
    {"id": "LF05", "st": (-31.8, -12.0), "lit": False, "beat": 1},
    {"id": "LF06", "st": (-31.0, 4.2), "lit": False, "beat": 2},
    {"id": "LF07", "st": (-11.8, -11.4), "lit": False, "beat": 2},
    {"id": "LF08", "st": (-3.4, -9.0), "lit": False, "beat": 3},
    {"id": "LF09", "st": (2.6, 4.6), "lit": False, "beat": 3},
    {"id": "LF10", "st": (12.6, -9.6), "lit": False, "beat": 4, "opens": "M1 M2 M3"},
    {"id": "LF11", "st": (17.6, -0.4), "lit": False, "beat": 4},
    {"id": "LF12", "st": (21.6, 12.6), "lit": False, "beat": 4},
    {"id": "LF13", "st": (31.0, 18.8), "lit": False, "beat": 5},
    {"id": "LF14", "st": (39.2, 14.4), "lit": False, "beat": 5},
]
LANTERN_HANG = 2.6
FENN_BRAZIER_LIGHT = 4.5


def lanterns():
    out = []
    for lf in LANTERNS:
        p = ground(lf["st"][0], lf["st"][1], LANTERN_HANG)
        out.append({"id": lf["id"], "pos": p, "lit": lf["lit"], "beat": lf["beat"], "opens": lf.get("opens", "")})
    return out


FIGHTS = [
    {"id": "hollow", "kind": "ambush", "at": (-38.6, -12.6), "radius": 4.0, "beat": 1,
     "note": "hidden in the dark until LF03 is lit",
     "enemies": [["splotchet", (-1.6, 1.2)], ["splotchet", (1.4, 1.8)], ["splotchet", (0.4, -2.0)]]},
    {"id": "shore", "kind": "roaming", "at": (-19.0, -12.4), "radius": 5.0, "beat": 2,
     "enemies": [["splotchet", (-1.5, 0.5)], ["splotchet", (1.8, -0.8)]]},
    {"id": "island", "kind": "roaming", "at": ISLAND["c"], "radius": 4.5, "beat": 3,
     "note": "Sootflits circle 4.2 m above the island and dive at Orimi on the lily pads",
     "enemies": [["sootflit", (4.0, 0.0)], ["sootflit", (-4.0, 0.0)]]},
    {"id": "dam", "kind": "sealed", "at": (19.2, 6.5), "radius": 4.0, "beat": 4,
     "waves": [
         [["splotchet", (-2.5, -2.0)], ["splotchet", (2.5, -2.0)], ["splotchet", (-2.0, 2.5)], ["splotchet", (2.0, 2.5)], ["sootflit", (0.0, 0.0)]],
         [["sootflit", (-3.0, 0.0)], ["sootflit", (3.0, 0.0)], ["reedwraith", (0.0, 3.0)]],
     ]},
]


def fights():
    out = []
    for f in FIGHTS:
        c = ground(f["at"][0], f["at"][1])
        e = dict(f)
        e["center"] = c
        del e["at"]

        def place(lst):
            return [[k, ground(f["at"][0] + o[0], f["at"][1] + o[1])] for k, o in lst]
        if "enemies" in f:
            e["enemies"] = place(f["enemies"])
        if "waves" in f:
            e["waves"] = [place(w) for w in f["waves"]]
        out.append(e)
    return out


# CurseField slots: the three ponds and the spring, so each pond reads as black still ink and
# restores with the shared ragged front. Radii reach past the shore so the banks drain too.
CURSE_ZONES = [
    {"slot": 0, "id": "pond_low", "center_st": PONDS["low"]["c"], "y": PONDS["low"]["water"], "radius": 11.5},
    {"slot": 1, "id": "pond_mid", "center_st": PONDS["mid"]["c"], "y": PONDS["mid"]["water"], "radius": 12.0},
    {"slot": 2, "id": "pond_high", "center_st": PONDS["high"]["c"], "y": PONDS["high"]["water"], "radius": 12.0},
    {"slot": 3, "id": "spring", "center_st": (43.5, 3.0), "y": SPRING["water"], "radius": 6.0},
]


def curse_zones():
    out = []
    for z in CURSE_ZONES:
        out.append({"slot": z["slot"], "id": z["id"], "center": at(z["center_st"][0], z["center_st"][1], z["y"]), "radius": z["radius"]})
    return out


# ------------------------------------------------------------------ trees
TRUNK_VARIANTS = ["trunk_a", "trunk_b", "trunk_c", "trunk_snag"]


def trees(seed=4):
    """Deterministic scatter of the tall trunks: dense in the wood and on its banks, clear of the
    paths, ponds, clearings, climbs and cliff faces."""
    rng = np.random.default_rng(seed)
    placed = []
    pts = []
    tries = 0
    while tries < 20000 and len(placed) < 210:
        tries += 1
        x, z = rng.uniform(-64, 64), rng.uniform(-64, 64)
        s, t = xz_st(x, z)
        if s < RIVER_S + 4.0:
            continue
        inside = abs(x) <= SQUARE + 2 and abs(z) <= SQUARE + 2
        if not inside and rng.random() < 0.55:
            continue
        if float(path_distance(s, t)) < PATH_HALF + 2.0:
            continue
        if any(float(pond_e(s, t, n)) < 1.18 for n in PONDS):
            continue
        if any(math.hypot(s - cs, t - ct) < cr + 1.0 for cs, ct, cr in CLEARINGS):
            continue
        if math.hypot(s - STAIR_TREE[0], t - STAIR_TREE[1]) < 6.0:
            continue
        if float(polyline_distance(s, t, CHANNEL)) < 3.2 or min(float(polyline_distance(s, t, r)) for r in RUNNELS.values()) < 2.0:
            continue
        c1, c2 = float(cliff1(t)), float(cliff2(t))
        if abs(s - c1) < 1.6 or abs(s - c2) < 1.6:
            continue
        if NOTCH_T[0] - 2 < t < NOTCH_T[1] + 2 and c2 - 2 < s < DAM_S + 2:
            continue
        if c2 - 3.5 < s < c2 + 4.2 and -16.0 < t < NOTCH_T[0] + 1:   # the gully climb and its ledge path
            continue
        if DAM_S - 1.5 < s < DAM_S + 1.5 and DAM_T[0] - 1 < t < DAM_T[1] + 1:
            continue
        if math.hypot(s - SPRING["c"][0], t - SPRING["c"][1]) < 4.0:
            continue
        spacing = 4.6 if inside else 3.8
        if any((x - px) ** 2 + (z - pz) ** 2 < spacing ** 2 for px, pz in pts):
            continue
        pts.append((x, z))
        r = rng.random()
        variant = TRUNK_VARIANTS[0 if r < 0.36 else 1 if r < 0.68 else 2 if r < 0.92 else 3]
        y = float(height(x, z))
        placed.append({"model": variant, "pos": (round(float(x), 2), round(y - 0.15, 2), round(float(z), 2)),
                       "yaw": round(float(rng.uniform(0, 360)), 1), "scale": round(float(rng.uniform(0.85, 1.18)), 3)})
    # the far bank of the Lull, from its own generator so the wood's scatter is unchanged
    far = np.random.default_rng(seed + 100)
    for _ in range(12000):
        if len(placed) >= 290:
            break
        x, z = far.uniform(-66, 66), far.uniform(-66, 66)
        s, t = xz_st(x, z)
        if not RIVER_S - 24.0 < s < RIVER_S - 6.0:
            continue
        if any((x - px) ** 2 + (z - pz) ** 2 < 4.2 ** 2 for px, pz in pts):
            continue
        pts.append((x, z))
        r = far.random()
        variant = TRUNK_VARIANTS[0 if r < 0.4 else 1 if r < 0.75 else 2]
        placed.append({"model": variant, "pos": (round(float(x), 2), round(float(height(x, z)) - 0.15, 2), round(float(z), 2)),
                       "yaw": round(float(far.uniform(0, 360)), 1), "scale": round(float(far.uniform(0.95, 1.25)), 3)})
    return placed


# ------------------------------------------------------------------ props
def props():
    m = build_markers()
    out = []

    def add(model, pos, yaw=0.0, scale=1.0, **kw):
        d = {"model": model, "pos": tuple(round(float(v), 3) for v in pos), "yaw": float(yaw), "scale": float(scale)}
        d.update(kw)
        out.append(d)

    add("raft_post", m["M_Raft"], yaw_st(1, 0))
    add("wheel", m["M_Wheel"], yaw_st(1.0, 0.0), state="clogged")
    add("fenn_hut", m["M_FennHut"], yaw_toward(m["M_FennHut"], m["M_Fenn_1"]))
    add("brazier", m["M_Brazier"], 0.0)
    add("stair_tree", m["M_StairTree"], yaw_st(-1.0, 0.0))
    for i, sh in enumerate(stair_shelves()):
        add("fungus_shelf", sh["pos"], sh["yaw"], 1.35, id="F%d" % (i + 1))
    for i in range(3):
        add("lily", m["M_Lily_%d" % (i + 1)], 37.0 * i, state="bud", id="Lily_%d" % (i + 1))
    for i, ps in enumerate(((-6.0, -8.0), (8.0, -6.0), (9.5, 12.0))):
        p = PONDS["mid"]
        add("lily_pad", at(p["c"][0] + ps[0] * 0.8, p["c"][1] + ps[1], p["water"]), 61.0 * i, 0.8)
    log_root = m["M_Log"]
    add("log", log_root, yaw_toward(log_root, m["M_LogEnd_Jammed"]), state="jammed")
    for piece in gully_pieces():
        add(piece["kind"], piece["pos"], piece["yaw"], id=piece["id"], state="tucked" if piece["kind"] == "moss_shelf" else "")
    add("thorn_gate", m["M_Thorns"], yaw_st(0.0, 1.0), 0.95, shared="res://scenes/models/thorn_gate.tscn")
    add("dam", m["M_Dam"], yaw_st(-1.0, 0.0))
    add("willow", m["M_Willow"], yaw_st(-1.0, 0.0), state="withered")
    # reused Level 1 pieces: reeds at the pond margins, rocks on the banks
    rng = np.random.default_rng(12)
    for name, p in PONDS.items():
        for k in range(9 if name != "high" else 7):
            a = rng.uniform(0, 2 * math.pi)
            e = rng.uniform(1.02, 1.12)
            s = p["c"][0] + math.cos(a) * p["r"][0] * e
            t = p["c"][1] + math.sin(a) * p["r"][1] * e
            if float(path_distance(s, t)) < PATH_HALF + 0.6:
                continue
            add("reeds", ground(s, t, -0.05), rng.uniform(0, 360), rng.uniform(0.8, 1.2), shared="res://scenes/models/reeds.tscn")
    for k in range(26):
        s, t = rng.uniform(-50, 44), rng.uniform(-22, 22)
        if float(path_distance(s, t)) < PATH_HALF + 1.5 or any(float(pond_e(s, t, n)) < 1.25 for n in PONDS):
            continue
        if abs(s - float(cliff1(t))) < 1.0 or abs(s - float(cliff2(t))) < 1.0:
            continue
        if any(math.hypot(s - cs, t - ct) < cr for cs, ct, cr in CLEARINGS):
            continue
        add("rocks", ground(s, t, -0.1), rng.uniform(0, 360), rng.uniform(0.5, 1.1), shared="res://scenes/models/rocks.tscn")
    return out


def path_points():
    return {k: [st_xz(s, t) for s, t in v] for k, v in PATHS.items()}


PEOPLE = [
    {"id": "pell", "marker": "M_Raft", "note": "on the raft at the landing; arrives with Orimi"},
    {"id": "fenn", "marker": "M_Fenn_1", "note": "beside his brazier in the clearing (beat 1-2)"},
    {"id": "fenn", "marker": "M_Fenn_2", "note": "on the far shore of Lily Reach (beat 3)"},
    {"id": "fenn", "marker": "M_Fenn_3", "note": "at the willow (beat 4-5)"},
]
VERSE_STONES = [
    {"id": "verse_1", "marker": "M_Verse_1", "note": "by the paddle-wheel"},
    {"id": "verse_2", "marker": "M_Verse_2", "note": "on the path above Willow Pool"},
]
