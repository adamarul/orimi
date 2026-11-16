"""Sedge Plain (level id sedge_plain): the one source of truth for the level's shape.

Pure Python + numpy. Read by the Blender terrain and prop generators, the ground painter, the
top-down plan drawer and export_layout.py (which writes the GDScript data gameplay loads), so
the plan, the terrain, the markers and the safe-ground data cannot disagree.

Godot axes, metres: X east, Y up, Z south. The player lands on the south bank (+Z) and leaves
through the pass in the north-west (-X, -Z).

    the Lull   along the south edge, flowing west to east; Pell's landing on its north bank
    the plain        about 120 x 100 m (x -60..60, z -50..50), rising gently to the north
    the Seam         a dry gully, 5 m deep, east to west across the middle, closed at both ends
                     by the hills; two broken rope bridges (Tie)
    three hollows    basins of the Spill. Each holds raised causeways and islands of clean ground.
                     The largest, the Mere, rings the Knoll with the guardian sapling.
    the hills        steep on the west, north and east; a pass in the north-west leads to the wood
"""
import math

import numpy as np

# ----------------------------------------------------------------------------------- extents
PLAIN_X = (-60.0, 60.0)
PLAIN_Z = (-50.0, 50.0)
FLOOR_X = (-72.0, 72.0)          # fine ground tiles (1 m grid) and the 2K ground texture
FLOOR_Z = (-64.0, 80.0)
FLOOR_STEP = 1.0
TILES = (4, 4)                   # ground tiles along X and Z
OUTER_X = (-232.0, 232.0)        # coarse hills ring
OUTER_Z = (-240.0, 248.0)
OUTER_STEP = 8.0

# ----------------------------------------------------------------------------------- the river
WATER_Y = -0.6
RIVER_BED = -2.3
RIVER_HALF = 5.0
RIVER_BANK = 3.2
RIVER = [(-240, 74), (-150, 70), (-96, 66), (-66, 70), (-40, 66.5), (-14, 64.5), (6, 64.5), (28, 67),
         (52, 64.5), (76, 68.5), (110, 74), (160, 78), (240, 82)]

# ----------------------------------------------------------------------------------- the Seam
SEAM = [(-70, 1.0), (-50, 3.0), (-38, 0.0), (-26, -0.5), (-14, 2.0), (0, 1.0), (16, 2.0), (28, -0.5),
        (42, 2.0), (54, 0.0), (70, 1.0)]
SEAM_DEPTH = 5.0
SEAM_FLOOR_HALF = 1.6
SEAM_TOP_HALF = 5.0
SEAM_ENDS = (-68.0, 69.0)        # the gully runs on into the hills, which close it
BRIDGE_X = {"1": 16.0, "2": -26.0}
POST_BACK = 1.6                  # tie posts stand this far back from the gully lip

# ----------------------------------------------------------------------------------- hollows
# centre (x, z), floor radius, rim radius, depth below the plain, CurseField slot, zone radius
HOLLOWS = {
    "mere": {"name": "the Mere", "c": (2.0, -30.0), "floor_r": 15.5, "rim_r": 21.0, "depth": 3.0, "slot": 2, "zone_r": 17.5, "seed": 8},
    "east": {"name": "Kettle Hollow", "c": (44.0, -22.0), "floor_r": 8.0, "rim_r": 12.0, "depth": 2.5, "slot": 1, "zone_r": 9.5, "seed": 12},
    "west": {"name": "Ladle Hollow", "c": (-36.0, 22.0), "floor_r": 8.0, "rim_r": 12.0, "depth": 2.5, "slot": 0, "zone_r": 9.5, "seed": 11},
}
KNOLL_C = HOLLOWS["mere"]["c"]
KNOLL_TOP_R = 5.6                # plateau radius
KNOLL_FOOT_R = 12.5              # where the slope meets the Mere floor
KNOLL_RISE = 3.0                 # plateau height above the surrounding plain
KNOLL_RAMP_R = 9.0
KNOLL_RAMP_ANGLES = (173.0, 95.0)  # degrees in the XZ plane (0 = +X, 90 = +Z): west round to south

# Raised causeways: polylines across the hollows at plain level. The Mere's is in two parts with
# the break the second Tie spans between them. The two spurs are false roads that end in the ink.
CAUSEWAYS = {
    "east": {"pts": [(32.4, -17.2), (36.5, -18.8), (40.5, -21.6), (43.6, -23.2)], "half": 1.5},
    "west": {"pts": [(-27.4, 13.6), (-30.5, 17.4), (-34.6, 21.6), (-37.0, 23.4)], "half": 1.5},
    "mere": {"pts": [(-13.9, -16.0), (-10.8, -19.6), (-10.9, -24.2)], "half": 1.6},
    "mere_b": {"pts": [(-9.6, -28.9), (-7.9, -30.4)], "half": 1.6},
    "spur_south": {"pts": [(6.0, -9.5), (5.2, -13.4), (5.8, -16.4)], "half": 1.4},
    "spur_east": {"pts": [(22.0, -26.0), (18.2, -27.6), (15.6, -27.2)], "half": 1.4},
}
MERE_BREAK = ((-10.9, -24.2), (-9.6, -28.9))
ISLANDS = {"east": ((46.0, -24.0), 3.4), "west": ((-38.6, 24.6), 3.4)}

# ----------------------------------------------------------------------------------- paths
PATHS = {
    "landing": [(4.5, 57.5), (3.0, 53.0), (0.5, 48.0), (-2.5, 44.5), (0.5, 38.0), (5.5, 30.0), (9.5, 22.5),
                (12.5, 15.0), (16.0, 8.6)],
    "camp": [(-2.5, 44.5), (-6.5, 45.0), (-8.5, 45.5)],
    "shrine": [(3.0, 53.0), (8.0, 51.5), (10.5, 50.0)],
    "north_strip": [(16.0, -4.6), (12.0, -7.0), (6.0, -8.0), (-2.0, -7.6), (-9.0, -9.0), (-15.0, -11.5),
                    (-21.0, -8.0), (-25.6, -6.4)],
    "east": [(16.0, -4.6), (21.0, -7.5), (26.0, -12.5), (30.0, -15.5), (32.4, -17.2)],
    "mere_start": [(-15.0, -11.5), (-13.9, -16.0)],
    "west_south": [(-26.0, 5.8), (-24.0, 9.5), (-25.2, 12.0), (-27.4, 13.6)],
    "west_link": [(-24.0, 9.5), (-16.0, 15.0), (-8.0, 22.0), (-3.0, 32.0), (0.5, 38.0)],
    "exit": [(-15.0, -11.5), (-24.0, -18.0), (-34.0, -27.0), (-44.0, -36.0), (-53.0, -43.0), (-56.5, -45.2)],
}
PATH_HALF = 1.3

# ----------------------------------------------------------------------------------- places
LEANING_STONES = (10.0, 22.0)
LEANING_R = 7.6
WOOD_PASS = [(-56.0, -45.0), (-64.0, -50.0), (-76.0, -56.0), (-92.0, -63.0)]
# The brook: it comes out of the wood down the pass and ends in a pool where Pell's raft waits.
BROOK = [(-61.0, -48.5), (-66.0, -51.5), (-76.0, -56.5), (-92.0, -63.0), (-130.0, -76.0)]
BROOK_HALF = 2.4
POOL_R = 1.6

FIGHTS = {
    "1": {"c": (9.5, 22.0), "r": 5.0, "patrol": 0.0, "pack": "4 Splotchets", "teaches": "finishing stroke"},
    "2": {"c": (25.5, -13.5), "r": 5.0, "patrol": 3.0, "pack": "3 Splotchets, 1 Reedwraith", "teaches": ""},
    "3": {"c": (-11.0, 21.0), "r": 5.0, "patrol": 3.0, "pack": "3 Splotchets, 2 Reedwraiths", "teaches": ""},
    "4": {"c": (2.5, -29.0), "r": 5.0, "patrol": 0.0, "pack": "pulse 1: 4 Splotchets, 1 Reedwraith; pulse 2: 2 Reedwraiths, 2 Splotchets", "teaches": ""},
}


def seam_center_z(x):
    return float(np.interp(x, [p[0] for p in SEAM], [p[1] for p in SEAM]))


def seam_post(key, side):
    """Tie post beside the Seam at bridge key: side +1 south bank, -1 north bank."""
    x = BRIDGE_X[key]
    return (x, seam_center_z(x) + side * (SEAM_TOP_HALF + POST_BACK))


def _knoll_ramp():
    a0, a1 = KNOLL_RAMP_ANGLES
    pts = []
    for k in range(9):
        a = math.radians(a0 + (a1 - a0) * k / 8)
        pts.append((round(KNOLL_C[0] + math.cos(a) * KNOLL_RAMP_R, 3), round(KNOLL_C[1] + math.sin(a) * KNOLL_RAMP_R, 3)))
    return pts


KNOLL_RAMP = _knoll_ramp()
KNOLL_RAMP_HALF = 1.7


# ----------------------------------------------------------------------------------- noise
def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
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


def polyline_distance(x, z, pts):
    """Distance from points to a polyline, and the arc length of the nearest point."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    best = np.full(x.shape, np.inf)
    along = np.zeros(x.shape)
    acc = 0.0
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        dx, dz = bx - ax, bz - az
        l2 = dx * dx + dz * dz
        t = np.clip(((x - ax) * dx + (z - az) * dz) / l2, 0.0, 1.0)
        d = np.hypot(x - (ax + t * dx), z - (az + t * dz))
        closer = d < best
        best = np.where(closer, d, best)
        along = np.where(closer, acc + t * np.sqrt(l2), along)
        acc += np.sqrt(l2)
    return best, along


def polyline_length(pts):
    return float(sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:])))


def path_distance(x, z):
    best = None
    for pts in PATHS.values():
        d, _ = polyline_distance(x, z, pts)
        best = d if best is None else np.minimum(best, d)
    return best


def river_distance(x, z):
    """Distance to the water, in river units: the brook is scaled so every river profile fits it."""
    d_river = polyline_distance(x, z, RIVER)[0]
    d, along = polyline_distance(x, z, BROOK)
    pool = POOL_R * np.clip(1.0 - along / 7.0, 0.0, 1.0)
    return np.minimum(d_river, np.maximum(d - pool, 0.0) * RIVER_HALF / BROOK_HALF)


def brook_half(along):
    """Half width of the brook's water surface at arc length along (wider at the pool)."""
    return (RIVER_HALF + RIVER_BANK * 0.62) * BROOK_HALF / RIVER_HALF + POOL_R * np.clip(1.0 - along / 7.0, 0.0, 1.0)


def seam_distance(x, z):
    return polyline_distance(x, z, SEAM)[0]


def hollow_radius(ho, ang, base_r):
    """Ragged rim: the radius wobbles with the angle so no hollow is a clean circle."""
    seed = ho["seed"]
    return base_r * (1.0 + 0.06 * np.sin(3 * ang + seed) + 0.035 * np.sin(7 * ang + 2 * seed))


# ----------------------------------------------------------------------------------- height
def plain_height(x, z):
    """The plain before anything is cut into it: rising gently north, rolling, flatter on paths."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    rise = 0.014 * (52.0 - z)
    roll = 0.75 * fbm(x, z, 22.0, 3) + 0.25 * fbm(x, z, 7.0, 4)
    flat = 0.45 + 0.55 * _smoothstep(2.0, 6.0, path_distance(x, z))
    h = rise + roll * flat
    shelf = _smoothstep(10.0, 4.0, np.hypot(x - 3.0, (z - 55.0) * 1.6))
    return h * (1 - shelf) + 0.35 * shelf


def _raised(h, x, z, pts, half, top, side_slope=1.8):
    """Raise a causeway: inside half the ground sits at top (array), sloping away steeply.
    Ground already higher stays higher."""
    d, _ = polyline_distance(x, z, pts)
    target = top - side_slope * np.maximum(d - half, 0.0)
    return np.maximum(h, target)


def hills(x, z):
    """Steep hills west, north and east; the river valley and far bank south; the wood pass."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    wob = 3.0 * fbm(z, x, 16.0, 7)
    west = -x - 63.0 + wob
    east = x - 63.5 + wob
    north = -z - 56.0 + 3.0 * fbm(x, z, 15.0, 8)
    edge = np.maximum(np.maximum(west, east), north)
    # Low, lumpy foothills Orimi can stand on, a steep rock band she cannot climb, then grassy
    # shoulders up to a crest that rises and falls along its length, so the edge reads as hills
    # rather than one flat-topped wall.
    foot = (2.2 + 1.2 * fbm(x, z, 14.0, 21)) * _smoothstep(0.0, 4.0, edge) + 0.6 * fbm(x, z, 5.0, 22) * _smoothstep(1.0, 4.0, edge)
    band_at = 3.8 + 1.0 * fbm(x, z, 22.0, 23)
    band = (6.0 + 2.0 * fbm(x, z, 18.0, 26)) * _smoothstep(band_at, band_at + 2.5, edge)
    up = np.maximum(edge - band_at - 2.5, 0.0)
    crest = np.maximum(13.0 + 10.0 * fbm(x, z, 30.0, 24, 4), 5.0)
    shoulder = crest * (1.0 - np.exp(-up / 15.0)) + 2.0 * fbm(x, z, 7.0, 25) * _smoothstep(0.0, 5.0, up)
    wall = foot + band + shoulder + 0.18 * np.maximum(edge - 22.0, 0.0) ** 1.25
    wall = wall * (1.0 + 0.1 * fbm(x, z, 9.0, 12, 4))
    pd, along = polyline_distance(x, z, WOOD_PASS)
    notch = _smoothstep(9.0, 3.5, pd)
    wall = wall * (1.0 - notch) + notch * (0.06 * along)
    far = z - 84.0 + 4.0 * fbm(x, z, 20.0, 9)
    south = 14.0 * (1.0 - np.exp(-np.maximum(far, 0.0) / 14.0))
    return np.maximum(wall, south)


def height(x, z):
    """Final ground height at Godot (x, z). Works on scalars and numpy arrays."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    base = plain_height(x, z)
    h = base.copy()

    for key, ho in HOLLOWS.items():
        cx, cz = ho["c"]
        ang = np.arctan2(z - cz, x - cx)
        d = np.hypot(x - cx, z - cz)
        rim = hollow_radius(ho, ang, ho["rim_r"])
        flo = hollow_radius(ho, ang, ho["floor_r"])
        t = np.clip((d - flo) / np.maximum(rim - flo, 0.1), 0.0, 1.0)
        carve = ho["depth"] * (1.0 - t ** 1.6)
        h = h - np.where(d < rim, carve, 0.0) + 0.25 * fbm(x, z, 4.0, 30) * (d < flo)

    kx, kz = KNOLL_C
    kd = np.hypot(x - kx, z - kz)
    kang = np.arctan2(z - kz, x - kx)
    top_r = KNOLL_TOP_R * (1.0 + 0.05 * np.sin(5 * kang + 1.0))
    foot_r = KNOLL_FOOT_R * (1.0 + 0.06 * np.sin(4 * kang + 2.0))
    t = np.clip((kd - top_r) / (foot_r - top_r), 0.0, 1.0)
    knoll_top = base + KNOLL_RISE + 0.35 * np.clip(1 - (kd / top_r) ** 2, 0.0, 1.0)
    knoll = knoll_top - (KNOLL_RISE + HOLLOWS["mere"]["depth"]) * (t * t * (3.0 - 2.0 * t))
    h = np.where(kd < foot_r, np.maximum(h, knoll), h)

    for cw in CAUSEWAYS.values():
        h = _raised(h, x, z, cw["pts"], cw["half"], base + 0.08)
    for (ix, iz), r in ISLANDS.values():
        d = np.hypot(x - ix, z - iz)
        h = np.maximum(h, base + 0.12 - 1.8 * np.maximum(d - r, 0.0))
    rd, along = polyline_distance(x, z, KNOLL_RAMP)
    ramp_y = base + KNOLL_RISE * _smoothstep(0.0, 1.0, along / polyline_length(KNOLL_RAMP)) * 0.98 + 0.05
    inside = _smoothstep(KNOLL_RAMP_HALF + 1.0, KNOLL_RAMP_HALF, rd)
    h = np.where(inside > 0, h * (1 - inside) + ramp_y * inside, h)

    sd, _ = polyline_distance(x, z, SEAM)
    t = np.clip((sd - SEAM_FLOOR_HALF) / (SEAM_TOP_HALF - SEAM_FLOOR_HALF), 0.0, 1.0)
    ends = _smoothstep(SEAM_ENDS[0] - 2.0, SEAM_ENDS[0] + 1.0, x) * _smoothstep(SEAM_ENDS[1] + 2.0, SEAM_ENDS[1] - 1.0, x)
    carve = SEAM_DEPTH * (1.0 - t ** 1.5) * ends
    h = h - np.where(sd < SEAM_TOP_HALF, carve, 0.0) + 0.2 * fbm(x, z, 2.5, 40) * (sd < SEAM_FLOOR_HALF + 0.5) * ends

    h = h + hills(x, z)
    rdist = river_distance(x, z)
    outer = RIVER_HALF + RIVER_BANK
    bank = RIVER_BED + (0.05 - RIVER_BED) * _smoothstep(RIVER_HALF * 0.3, outer, rdist)
    h = np.where(rdist < outer + 3.0, np.minimum(h, bank + np.maximum(0.0, h - 0.05) * _smoothstep(outer, outer + 3.0, rdist)), h)
    return h


def hollow_floor_y(key):
    ho = HOLLOWS[key]
    cx, cz = ho["c"]
    return float(plain_height(cx, cz)) - ho["depth"]


# ----------------------------------------------------------------------------------- safe ground
def safe_mask(x, z, margin=0.0):
    """True where the ground stays clean while its hollow is cursed: causeway tops, islands and
    the Knoll's plateau and ramp. Gameplay gets the same shapes as polylines and circles."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    m = np.zeros(x.shape, dtype=bool)
    for cw in CAUSEWAYS.values():
        d, _ = polyline_distance(x, z, cw["pts"])
        m |= d < cw["half"] + margin
    for (ix, iz), r in ISLANDS.values():
        m |= np.hypot(x - ix, z - iz) < r + margin
    m |= np.hypot(x - KNOLL_C[0], z - KNOLL_C[1]) < KNOLL_TOP_R + margin
    rd, _ = polyline_distance(x, z, KNOLL_RAMP)
    m |= rd < KNOLL_RAMP_HALF + margin
    return m


def ground(x, z):
    return float(height(x, z))


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# ----------------------------------------------------------------------------------- markers
def _on(x, z, dy=0.0):
    return (round(float(x), 2), round(ground(x, z) + dy, 2), round(float(z), 2))


def markers():
    """Every M_* marker: name -> (x, y, z), y on the ground unless noted."""
    m = {}
    m["M_Spawn"] = _on(3.0, 53.0)
    m["M_Landing"] = (4.5, 0.25, 59.0)
    m["M_Raft"] = (5.0, WATER_Y, 63.4)
    m["M_Shrine"] = _on(11.5, 49.8)
    m["M_Tamsin_Camp"] = _on(-8.5, 45.6)
    m["M_MapFrame"] = _on(-10.6, 46.8)
    m["M_LeaningStones"] = _on(*LEANING_STONES)
    for k, f in FIGHTS.items():
        m["M_Fight_%s" % k] = _on(*f["c"])
    for key in BRIDGE_X:
        m["M_Bridge%s_S" % key] = _on(*seam_post(key, +1))
        m["M_Bridge%s_N" % key] = _on(*seam_post(key, -1))
    m["M_Verse_1"] = _on(19.6, 9.4)
    m["M_Leaf_1"] = _on(7.8, -8.6)
    m["M_Tamsin_Rim"] = _on(-17.6, -10.0)
    for key, ho in HOLLOWS.items():
        cx, cz = ho["c"]
        m["M_Hollow_%s" % key.capitalize()] = (cx, round(hollow_floor_y(key), 2), cz)
    for key in ("east", "west"):
        pts = CAUSEWAYS[key]["pts"]
        cap = key.capitalize()
        m["M_Causeway_%s" % cap] = _on(*pts[0])
        (ix, iz), r = ISLANDS[key]
        m["M_Island_%s" % cap] = _on(ix, iz)
        m["M_Soot_%s_1" % cap] = _on(*_lerp(pts[0], pts[1], 0.7))
        m["M_Soot_%s_2" % cap] = _on(*_lerp(pts[1], pts[2], 0.8))
    m["M_Leaf_2"] = _on(46.6, -24.6)
    m["M_Leaf_3"] = _on(-39.2, 25.2)
    m["M_Causeway_Mere"] = _on(*CAUSEWAYS["mere"]["pts"][0])
    m["M_Soot_Mere"] = _on(*_lerp(CAUSEWAYS["mere"]["pts"][0], CAUSEWAYS["mere"]["pts"][1], 0.35))
    m["M_Tie_Break_A"] = _on(*MERE_BREAK[0])
    m["M_Tie_Break_B"] = _on(*MERE_BREAK[1])
    m["M_Knoll_Ramp"] = _on(*KNOLL_RAMP[0])
    m["M_Knoll"] = _on(*KNOLL_C)
    m["M_Sapling"] = _on(KNOLL_C[0] - 0.4, KNOLL_C[1] - 0.6)
    m["M_Verse_2"] = _on(KNOLL_C[0] + 3.2, KNOLL_C[1] - 3.0)
    m["M_Exit"] = _on(-56.0, -45.2)
    m["M_Exit_Raft"] = (BROOK[0][0], WATER_Y, BROOK[0][1])
    return m


# ----------------------------------------------------------------------------------- props
def _ring(cx, cz, r, n, a0=0.0):
    return [(cx + math.cos(a0 + 2 * math.pi * k / n) * r, cz + math.sin(a0 + 2 * math.pi * k / n) * r) for k in range(n)]


def props():
    """Prop placements: list of (model, x, y, z, yaw_degrees, scale)."""
    out = []

    def put(model, x, z, yaw=0.0, scale=1.0, dy=0.0):
        out.append((model, round(float(x), 2), round(ground(x, z) + dy, 2), round(float(z), 2), round(float(yaw), 1), round(float(scale), 2)))

    for k, (x, z) in enumerate(_ring(LEANING_STONES[0], LEANING_STONES[1], LEANING_R, 7, 0.4)):
        variant = ["stone_tall", "stone_lean", "stone_tall", "stone_capped", "stone_lean", "stone_fallen", "stone_tall"][k]
        yaw = math.degrees(math.atan2(x - LEANING_STONES[0], z - LEANING_STONES[1])) + 10 * math.sin(k * 2.1)
        put(variant, x, z, yaw, 0.9 + 0.12 * math.sin(k * 1.7), -0.15)
    for (x, z, v, yaw, s) in [(-4.0, 33.0, "stone_tall", 20, 0.85), (22.0, 30.0, "stone_lean", -40, 1.0),
                               (27.0, 6.5, "stone_capped", 70, 0.9), (-14.0, 26.0, "stone_lean", 130, 0.8),
                               (-40.0, -12.0, "stone_tall", 15, 1.1), (-47.0, -30.0, "stone_capped", -60, 1.0),
                               (33.0, -33.0, "stone_tall", 200, 1.05), (52.0, -6.0, "stone_lean", 95, 0.95),
                               (-50.0, 38.0, "stone_tall", 45, 0.9), (40.0, 30.0, "stone_fallen", 10, 1.0),
                               (-30.0, -36.0, "stone_lean", 160, 0.9), (16.0, -48.0, "stone_tall", 0, 1.15)]:
        put(v, x, z, yaw, s, -0.15)
    for k, (x, z) in enumerate(_ring(KNOLL_C[0], KNOLL_C[1], 4.6, 5, 1.2)):
        put(["stone_capped", "stone_tall", "stone_lean", "stone_tall", "stone_tall"][k], x, z, k * 72 + 15, 0.8, -0.1)
    for key in BRIDGE_X:
        sx, sz = seam_post(key, +1)
        nx, nz = seam_post(key, -1)
        put("tie_post", sx, sz, 0.0)
        put("tie_post", nx, nz, 180.0)
        hang = (sx, sz) if key == "1" else (nx, nz)
        put("bridge_wreck", hang[0], hang[1], 0.0 if key == "1" else 180.0)
    a, b = MERE_BREAK
    yaw = math.degrees(math.atan2(-(b[0] - a[0]), -(b[1] - a[1])))
    put("tie_post", a[0], a[1], yaw)
    put("tie_post", b[0], b[1], yaw + 180)
    put("tamsin_camp", -10.6, 46.8, 25.0)
    put("landing_stage", 4.5, 59.0, 0.0)
    put("shrine", 11.5, 49.8, -30.0)
    put("map_leaf", 7.8, -8.6, 30.0)
    put("map_leaf", 46.6, -24.6, 200.0)
    put("map_leaf", -39.2, 25.2, 110.0)
    cx, cz = CAUSEWAYS["mere"]["pts"][0]
    put("stone_lean", cx - 2.2, cz + 0.6, -50.0, 1.15)
    rng = np.random.default_rng(11)
    for x, z in [(-44, 8), (-8, -4.5), (30, 6.5), (48, -5.5), (-52, -5), (6, 7.5), (36, -6.0), (-34, 6.8)]:
        put("rocks", x, z, float(rng.uniform(0, 360)), float(rng.uniform(0.7, 1.2)), -0.2)
    for x in (-48, -32, -18, -6, 8, 24, 38, 50):
        zc = seam_center_z(x)
        put("rocks", x + float(rng.uniform(-2, 2)), zc + float(rng.uniform(-0.6, 0.6)), float(rng.uniform(0, 360)), float(rng.uniform(0.5, 0.8)), -0.25)
    for x, z in [(-58, 30), (-58, -20), (58, 24), (58, -38), (-20, -52), (30, -53), (-60, 10)]:
        put("rocks", x, z, float(rng.uniform(0, 360)), float(rng.uniform(1.2, 1.8)), -0.3)
    for x in np.arange(-60, 64, 7.5):
        z = float(np.interp(x, [p[0] for p in RIVER], [p[1] for p in RIVER])) - RIVER_HALF - 0.8 + float(rng.uniform(-0.8, 0.8))
        if abs(x - 4.5) < 5:
            continue
        put("reeds", float(x + rng.uniform(-2, 2)), z, float(rng.uniform(0, 360)), float(rng.uniform(0.9, 1.3)), -0.1)
    for x, z, s in [(-52, -52, 1.1), (-60, -40, 1.0), (-66, -46, 1.2), (-46, -56, 1.0), (-70, -60, 1.25),
                    (-58, -60, 1.15), (-78, -52, 1.2), (-82, -66, 1.3), (-68, -70, 1.2), (-40, -60, 0.95),
                    (-56, -66, 1.1), (-86, -56, 1.25), (-74, -42, 1.1)]:
        put("wood_tree", x, z, float(rng.uniform(0, 360)), s, -0.2)
    return out


def walk_lines():
    """Every walkable route (paths, causeways, ramp) for the plan and gameplay."""
    out = dict(PATHS)
    for key, cw in CAUSEWAYS.items():
        out["causeway_" + key] = cw["pts"]
    out["knoll_ramp"] = KNOLL_RAMP
    return out
