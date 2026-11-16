"""Tallowford layout: every marker, house, prop, path and the height field, in Godot metres.

Pure Python + numpy. It is the single source of truth for the level: the Blender terrain
generator, the ground painter, the plan image in docs/levels/tallowford/ and the placement data
the look-dev scene (and phase B) loads from scripts/levels/tallowford/layout.json all read it,
so the plan and the terrain cannot disagree.

Godot axes: X east, Y up, Z south (north is -Z). The Lull runs north to south along the
east side. Pell's raft lands at the south-east; the road climbs north-west into the square.

    python tools/levels/tallowford/layout.py <out.json>     writes the placement data
"""
import json
import math
import sys

import numpy as np

# ------------------------------------------------------------------ the river
WATER_Y = -0.35
RIVER_BED = -1.6
RIVER_HALF = 4.5       # half width of the channel
RIVER_BANK = 2.5       # bank slope beyond it
RIVER = [(39.0, -110.0), (37.0, -70.0), (34.5, -40.0), (33.5, -22.0), (33.8, -6.0), (33.2, 10.0),
         (34.2, 26.0), (36.0, 44.0), (39.0, 80.0), (42.0, 115.0)]
FLOW = (0.0, 1.0)      # downstream, XZ

# ------------------------------------------------------------------ open spaces
SQUARE_C, SQUARE_R = (0.0, -2.0), 9.5           # paved village square, persimmon at its centre
JETTY_SQ_C, JETTY_SQ_R = (19.5, -5.5), 7.0      # paved jetty square; the sealed fight's 10 m circle fits inside
FIGHT_R = 5.0
DYE_YARD_C, DYE_YARD_R = (-20.0, 2.0), 7.5      # beaten earth stained with dye
WELL_C = (-6.5, 13.5)
WELL_YARD_R = 4.0
LANDING_C = (26.0, 27.0)                        # stone landing steps where the raft ties up
FORD_PIER = (29.8, -24.0)                       # the ford-lamp stands on a stone pier in the shallows
PIER_TOP_Y = 0.25                               # the ford-lamp model's origin: the top of its pier
JETTY_DECK_Y = 0.15                             # jetty and landing models: origin at the deck top
LAMP_HEAD_Y = 2.05                              # house lamp: lantern centre above the post's foot (the Kindle target)
LAMP_ARM = 0.5                                  # the lantern hangs this far to the post's left (toward the door)
FORD_HEAD_Y = 6.35                              # ford-lamp: lantern centre above the pier top
JETTY_LEN, JETTY_W = 10.5, 2.6                  # jetty: from its origin eastward into the river
LANDING_LEN, LANDING_W = 4.5, 3.0               # landing steps: from its origin eastward

# Paths (sandy, inked edges). Each is a polyline of (x, z) and a half width.
PATHS = [
    ("road", [(27.5, 27.5), (24.0, 26.0), (19.5, 23.0), (14.5, 19.0), (10.0, 14.5), (6.0, 9.5), (3.5, 6.5)], 1.9),
    ("lane_west", [(-8.5, -3.0), (-13.0, -2.5), (-16.5, -0.5)], 1.4),
    ("lane_dye_well", [(-18.0, 7.0), (-14.5, 9.5), (-10.5, 12.0)], 1.2),
    ("lane_well_square", [(-5.5, 10.0), (-4.5, 6.5)], 1.2),
    ("lane_east", [(9.2, -3.0), (12.5, -4.5)], 1.6),
    ("lane_north", [(0.0, -11.5), (-1.0, -13.5)], 1.2),
    ("lane_ford", [(23.0, -11.0), (24.0, -16.0), (24.8, -21.5)], 1.3),
    ("lane_ferry", [(18.0, -12.5), (17.5, -14.0)], 1.1),
]

# ------------------------------------------------------------------ houses
# name, centre (x, z), width (along the front), depth, the point its front faces, kind
HOUSES = [
    ("house_trim", (14.0, 10.0), 6.4, 4.8, (9.5, 15.0), "lamp-maker's house and workshop"),
    ("house_marrow", (-25.0, -8.0), 6.0, 4.6, (-19.0, -1.5), "the dyer's house"),
    ("house_brindle", (-14.5, 19.5), 5.4, 4.2, (-7.0, 14.0), "the well-keeper's cottage"),
    ("house_children", (-2.0, -17.0), 7.0, 5.0, (0.0, -2.0), "the children's house on the square"),
    ("house_ferry", (16.5, -17.5), 5.6, 4.4, (19.0, -6.0), "the ferry-house above the jetty"),
]
# Neighbours' cottages (one model, placed four times): each has a lamp that lights in the finale.
COTTAGE_W, COTTAGE_D = 5.0, 4.0
COTTAGES = [
    ("cottage", (-19.5, -20.5), COTTAGE_W, COTTAGE_D, (-8.0, -6.0)),
    ("cottage", (2.5, 20.0), COTTAGE_W, COTTAGE_D, (8.0, 13.0)),
    ("cottage", (23.0, 14.0), COTTAGE_W, COTTAGE_D, (14.0, 19.5)),
    ("cottage", (-25.0, 16.0), COTTAGE_W, COTTAGE_D, (-14.0, 9.0)),
]
# Outbuildings (one model, placed three times): no lamp, no person.
SHED_W, SHED_D = 4.0, 3.2
SHEDS = [
    ("shed", (7.5, -18.5), SHED_W, SHED_D, (5.0, -8.0)),
    ("shed", (-12.5, -15.0), SHED_W, SHED_D, (-8.0, -6.0)),
    ("shed", (-30.5, 3.0), SHED_W, SHED_D, (-20.0, 2.0)),
]


def face_yaw(c, target):
    """Godot yaw (degrees) that turns a model facing -Z at c to face target."""
    dx, dz = target[0] - c[0], target[1] - c[1]
    return math.degrees(math.atan2(-dx, -dz))


def local_to_world(c, yaw_deg, lx, lz):
    """A point given in a house's own frame (x right, z forward = toward its front) to world XZ."""
    a = math.radians(yaw_deg)
    fwd = (-math.sin(a), -math.cos(a))
    right = (math.cos(a), -math.sin(a))
    return (c[0] + right[0] * lx + fwd[0] * lz, c[1] + right[1] * lx + fwd[1] * lz)


def house_points(c, w, d, target):
    yaw = face_yaw(c, target)
    door = local_to_world(c, yaw, 0.0, d / 2 + 0.25)
    lamp = local_to_world(c, yaw, 1.55, d / 2 + 1.0)
    person = local_to_world(c, yaw, -0.2, d / 2 + 0.95)
    return yaw, door, lamp, person


def lantern_point(c, w, d, target):
    """Where a house's lantern hangs (the Kindle target), in world XZ."""
    return local_to_world(c, face_yaw(c, target), 1.55 - LAMP_ARM, d / 2 + 1.0)


# ------------------------------------------------------------------ markers
def _markers():
    m = {
        "M_Spawn": (24.5, 26.0),          # Pell's raft lands; Orimi steps off here
        "M_Raft": (29.0, 27.5),           # where the raft ties up
        "M_RaftCross": (34.5, -5.5),      # end of the jetty, where the raft leaves when the ford-lamp burns
        "M_Square": SQUARE_C,
        "M_Persimmon": SQUARE_C,
        "M_DyeVats": (-21.0, 1.0),
        "M_Well": WELL_C,
        "M_JettySquare": JETTY_SQ_C,
        "M_Fight": JETTY_SQ_C,            # sealed fight centre, radius FIGHT_R
        "M_FordLamp": FORD_PIER,
        "M_Verse_1": None,                # set below, beside Old Trim's lamp
        "M_Verse_2": (24.0, -26.0),       # at the head of the ford causeway
        "M_PellWait": (21.5, -1.0),       # Pell waits by the jetty once the village is lit
    }
    for name, c, w, d, target, _ in HOUSES:
        yaw, door, lamp, person = house_points(c, w, d, target)
        key = name.split("_", 1)[1].capitalize()
        m["M_Door_" + key] = door
        m["M_Lamp_" + key] = lamp
    for k, (name, c, w, d, target) in enumerate(COTTAGES):
        m["M_Lamp_Cottage%d" % (k + 1)] = house_points(c, w, d, target)[2]
    yaw, door, lamp, person = house_points(*HOUSES[0][1:5])
    m["M_Verse_1"] = local_to_world(HOUSES[0][1], yaw, -2.3, HOUSES[0][3] / 2 + 1.5)
    return m


# People: who stands where at the start (grey, in their doorways) - phase B places them.
def people():
    out = {}
    names = {"house_trim": "M_Person_Trim", "house_marrow": "M_Person_Marrow", "house_brindle": "M_Person_Brindle",
             "house_children": "M_Person_Flax", "house_ferry": "M_Person_Wherry"}
    for name, c, w, d, target, _ in HOUSES:
        yaw, door, lamp, person = house_points(c, w, d, target)
        out[names[name]] = (person, yaw)
    yaw = out["M_Person_Flax"][1]
    out["M_Person_Pibbet"] = (local_to_world(HOUSES[3][1], yaw, 1.0, HOUSES[3][3] / 2 + 3.2), yaw + 25)
    out["M_Person_Pell"] = ((25.5, 25.0), face_yaw((25.5, 25.0), (14.0, 12.0)))
    # three neighbours with a line each after the ford-lamp (gather at the square)
    out["M_Person_Neighbour_1"] = ((-6.5, 3.5), face_yaw((-6.5, 3.5), SQUARE_C))
    out["M_Person_Neighbour_2"] = ((7.0, -1.0), face_yaw((7.0, -1.0), SQUARE_C))
    out["M_Person_Neighbour_3"] = ((5.5, -9.0), face_yaw((5.5, -9.0), SQUARE_C))
    return out


# The finale: everyone gathers by the jetty, facing the ford-lamp, the children in front; Pell waits
# at M_PellWait. A front row of five and a back row of four on the square's north side, by the
# river, leaving the way onto the jetty clear.
GATHER_FRONT = ["Pibbet", "Flax", "Trim", "Marrow", "Wherry"]
GATHER_BACK = ["Brindle", "Baker", "NetMender", "Fisher"]


def gather():
    c = (JETTY_SQ_C[0] + 3.0, JETTY_SQ_C[1] - 4.5)
    ux, uz = FORD_PIER[0] - c[0], FORD_PIER[1] - c[1]
    n = math.hypot(ux, uz)
    ux, uz = ux / n, uz / n
    px, pz = -uz, ux
    out = {}
    for row, names, ahead in ((0, GATHER_FRONT, 1.5), (1, GATHER_BACK, 0.0)):
        for k, name in enumerate(names):
            s = (k - (len(names) - 1) / 2) * 1.4
            out[name] = (c[0] + ux * ahead + px * s, c[1] + uz * ahead + pz * s)
    return out


# The finale camera: high over the river, north-east of the ford-lamp, so Orimi on the causeway is
# small, the lit lantern stands clear of the crowd by the jetty and the village lies behind.
FINALE_VIEW = (38.0, 7.5, -31.0)


MARKERS = _markers()

# ------------------------------------------------------------------ the ford causeway
def causeway_stones():
    a, b = (25.6, -23.4), (FORD_PIER[0] - 1.7, FORD_PIER[1])
    n = 3
    return [(a[0] + (b[0] - a[0]) * (k + 0.5) / n, a[1] + (b[1] - a[1]) * (k + 0.5) / n) for k in range(n)]


# ------------------------------------------------------------------ props
def props():
    """Every placed model: (model, x, z, yaw degrees, scale). Ground height is looked up by the user."""
    out = []
    for name, c, w, d, target, _ in HOUSES:
        yaw, door, lamp, person = house_points(c, w, d, target)
        out.append((name, c[0], c[1], yaw, 1.0))
        out.append(("lamp_post", lamp[0], lamp[1], yaw, 1.0))
    for name, c, w, d, target in COTTAGES:
        yaw, door, lamp, person = house_points(c, w, d, target)
        out.append((name, c[0], c[1], yaw, 1.0))
        out.append(("lamp_post", lamp[0], lamp[1], yaw, 1.0))
    for name, c, w, d, target in SHEDS:
        out.append((name, c[0], c[1], face_yaw(c, target), 1.0))
    out.append(("persimmon", SQUARE_C[0], SQUARE_C[1], 20.0, 1.0))
    out.append(("well", WELL_C[0], WELL_C[1], face_yaw(WELL_C, (-14.5, 19.5)), 1.0))
    out.append(("dye_vats", MARKERS["M_DyeVats"][0], MARKERS["M_DyeVats"][1], face_yaw(MARKERS["M_DyeVats"], (-12.0, -2.0)), 1.0))
    out.append(("cloth_line", -26.0, 4.5, 75.0, 1.0))
    out.append(("cloth_line", -14.8, 6.2, -35.0, 1.0))      # beside lane_dye_well, 2.5 m off it
    out.append(("drying_rack", 18.0, 5.0, 115.0, 1.0))
    out.append(("drying_rack", 19.2, 8.4, 100.0, 1.0))
    out.append(("drying_rack", -9.5, -12.5, 10.0, 1.0))
    out.append(("jetty", 25.0, JETTY_SQ_C[1], 0.0, 1.0))
    out.append(("landing", LANDING_C[0], LANDING_C[1], 0.0, 1.0))
    out.append(("ford_lamp", FORD_PIER[0], FORD_PIER[1], -90.0, 1.0))
    for k, (x, z) in enumerate(causeway_stones()):
        out.append(("stepping_stone", x, z, k * 41.0, 1.0))
    # Level 1 models reused
    out.append(("shrine", 20.5, 30.5, face_yaw((20.5, 30.5), (18.0, 22.0)), 0.85))
    out.append(("thorn_gate", -21.0, 1.0, face_yaw(MARKERS["M_DyeVats"], (-12.0, -2.0)), 0.62))
    fences = [((-33.0, 9.0), (-29.0, 10.0)), ((-9.0, 25.0), (-1.0, 26.5)),
              ((-1.0, 26.5), (7.0, 25.5)), ((-33.0, -2.0), (-33.5, -12.0)), ((22.0, -24.0), (17.0, -26.0)),
              ((10.0, -24.5), (3.0, -25.5))]
    for (ax, az), (bx, bz) in fences:
        n = max(1, int(round(math.hypot(bx - ax, bz - az) / 4.0)))
        for k in range(n):
            t = (k + 0.5) / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            out.append(("fence", x, z, math.degrees(math.atan2(-(bz - az), bx - ax)), math.hypot(bx - ax, bz - az) / n / 4.0))
    rng = np.random.default_rng(4)
    for k in range(18):
        t = rng.random()
        z = -32.0 + 62.0 * t
        x = river_x(z) - RIVER_HALF - rng.uniform(0.8, 2.6)
        if abs(z - JETTY_SQ_C[1]) < 4.0 or abs(z - LANDING_C[1]) < 4.0 or abs(z - FORD_PIER[1]) < 4.0:
            continue
        out.append(("reeds", x, z, rng.uniform(0, 360), rng.uniform(0.8, 1.2)))
    for (x, z, s) in [(-31.0, -20.0, 1.2), (-34.0, 18.0, 1.0), (10.5, -27.0, 0.8), (-20.0, 24.5, 0.9), (28.0, -30.0, 1.1),
                      (24.0, 12.0, 0.7), (-29.5, -15.0, 0.8)]:
        out.append(("rocks", x, z, rng.uniform(0, 360), s))
    return out


def prop_y(model, x, z):
    if model == "ford_lamp":
        return PIER_TOP_Y
    if model in ("jetty", "landing"):
        return JETTY_DECK_Y
    if model == "stepping_stone":
        return -0.12
    return ground(x, z)


def river_x(z):
    pts = np.array(RIVER)
    return float(np.interp(z, pts[:, 1], pts[:, 0]))


# ------------------------------------------------------------------ height field
FLOOR_X = (-40.0, 46.0)
FLOOR_Z = (-36.0, 36.0)
FLOOR_STEP = 1.0
WALL_STEP = 5.0
OUTER_X = (-100.0, 105.0)
OUTER_Z = (-96.0, 96.0)


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
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    best = np.full(x.shape, np.inf)
    for (ax, az), (bx, bz) in zip(pts[:-1], pts[1:]):
        dx, dz = bx - ax, bz - az
        l2 = dx * dx + dz * dz
        t = np.clip(((x - ax) * dx + (z - az) * dz) / l2, 0.0, 1.0)
        best = np.minimum(best, np.hypot(x - (ax + t * dx), z - (az + t * dz)))
    return best


def river_distance(x, z):
    return polyline_distance(x, z, RIVER)


def path_distance(x, z):
    """Distance to the nearest path edge (negative inside a path)."""
    best = np.full(np.shape(np.asarray(x, dtype=float)), np.inf)
    for _, pts, hw in PATHS:
        best = np.minimum(best, polyline_distance(x, z, pts) - hw)
    return best


def pads():
    """Flat places: (x, z, radius, height). Houses sit on level pads; the squares are paved."""
    out = [(SQUARE_C[0], SQUARE_C[1], SQUARE_R + 0.8, 0.0), (JETTY_SQ_C[0], JETTY_SQ_C[1], JETTY_SQ_R + 0.8, 0.1),
           (DYE_YARD_C[0], DYE_YARD_C[1], DYE_YARD_R, 0.35), (WELL_C[0], WELL_C[1], WELL_YARD_R + 0.6, 0.12),
           (LANDING_C[0] - 2.5, LANDING_C[1] - 0.5, 3.5, 0.05)]
    for name, c, w, d, target, _ in HOUSES:
        out.append((c[0], c[1], max(w, d) * 0.5 + 1.6, None))
    for name, c, w, d, target in COTTAGES + SHEDS:
        out.append((c[0], c[1], max(w, d) * 0.5 + 1.2, None))
    return out


def _tilt(x, z):
    """The ground rises gently away from the river and toward the southern fields."""
    return 0.022 * np.maximum(0.0, -x - 4.0) + 0.012 * np.maximum(0.0, z - 14.0)


def _base(x, z):
    return _tilt(x, z) + 0.14 * fbm(x, z, 8.0, 3) + 0.06 * fbm(x, z, 2.5, 9)


def height(x, z):
    """Ground height at Godot (x, z). Works on scalars and numpy arrays."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    h = _base(x, z)
    # paths keep the slope but lose the bumps
    pd = path_distance(x, z)
    h = h + (_tilt(x, z) + 0.14 * fbm(x, z, 8.0, 3) - h) * _smoothstep(1.2, -0.2, pd)
    for px, pz, r, ph in pads():
        target = float(_base(px, pz)) if ph is None else ph
        w = _smoothstep(r + 1.6, r, np.hypot(x - px, z - pz))
        h = h * (1 - w) + target * w
    # the bowl: hills west, north and south; the far bank rises beyond the river
    west = np.maximum(-x - 33.0 + 2.5 * fbm(z, x, 14.0, 7), 0.0)
    north = np.maximum(-z - 29.0 + 2.5 * fbm(x, z, 13.0, 8), 0.0)
    south = np.maximum(z - 30.0 + 2.5 * fbm(x, z, 12.0, 4), 0.0) * _smoothstep(30.0, 20.0, x)
    east = np.maximum(x - 44.0 + 3.0 * fbm(x, z, 15.0, 6), 0.0)
    rim = np.maximum(np.maximum(14.0 * (1 - np.exp(-west / 9.0)), 16.0 * (1 - np.exp(-north / 10.0))),
                     np.maximum(9.0 * (1 - np.exp(-south / 9.0)), 12.0 * (1 - np.exp(-east / 10.0))))
    rim = rim * (1.0 + 0.2 * fbm(x, z, 10.0, 12, 4))
    h = h + rim
    # the river cuts through
    rd = river_distance(x, z)
    bed = RIVER_BED + (0.0 - RIVER_BED) * _smoothstep(RIVER_HALF * 0.35, RIVER_HALF + RIVER_BANK, rd)
    h = np.where(rd < RIVER_HALF + RIVER_BANK, np.minimum(h, bed + np.maximum(0.0, h) * _smoothstep(RIVER_HALF, RIVER_HALF + RIVER_BANK + 4.0, rd)), h)
    # the ford pier and the landing stand above the water on stone footings (props); keep the bank under them
    return h


def ground(x, z):
    return float(height(x, z))


# Markers whose height is not the ground under them.
MARKER_Y = {"M_Raft": WATER_Y, "M_RaftCross": WATER_Y, "M_FordLamp": PIER_TOP_Y}


def marker_y(name):
    if name in MARKER_Y:
        return MARKER_Y[name]
    return ground(*MARKERS[name])


def wick_markers():
    """Kindle targets: the lantern centre of every lamp."""
    out = {}
    for name, c, w, d, target, _ in HOUSES:
        x, z = lantern_point(c, w, d, target)
        lx, lz = MARKERS["M_Lamp_" + name.split("_", 1)[1].capitalize()]
        out["M_Kindle_" + name.split("_", 1)[1].capitalize()] = (x, ground(lx, lz) + LAMP_HEAD_Y, z)
    for k, (name, c, w, d, target) in enumerate(COTTAGES):
        x, z = lantern_point(c, w, d, target)
        lx, lz = MARKERS["M_Lamp_Cottage%d" % (k + 1)]
        out["M_Kindle_Cottage%d" % (k + 1)] = (x, ground(lx, lz) + LAMP_HEAD_Y, z)
    out["M_Kindle_Ford"] = (FORD_PIER[0], PIER_TOP_Y + FORD_HEAD_Y, FORD_PIER[1])
    return out


def all_markers():
    """Every marker as (x, y, z): the M_* nodes on the terrain model."""
    out = {k: (v[0], marker_y(k), v[1]) for k, v in MARKERS.items()}
    out.update(wick_markers())
    for k, (p, yaw) in people().items():
        out[k] = (p[0], ground(*p), p[1])
    return out


def to_json():
    data = {
        "units": "metres, Godot axes (X east, Y up, Z south)",
        "markers": {k: [round(v[0], 3), round(v[1], 3), round(v[2], 3)] for k, v in all_markers().items()},
        "people": {k: {"pos": [round(p[0], 3), round(ground(*p), 3), round(p[1], 3)], "yaw": round(y, 1)} for k, (p, y) in people().items()},
        "props": [{"model": m, "pos": [round(x, 3), round(prop_y(m, x, z), 3), round(z, 3)], "yaw": round(y, 1), "scale": round(s, 3)}
                  for m, x, z, y, s in props()],
        "fight": {"center": [JETTY_SQ_C[0], ground(*JETTY_SQ_C), JETTY_SQ_C[1]], "radius": FIGHT_R},
        "water_y": WATER_Y,
        "river": [list(p) for p in RIVER],
        "flow": list(FLOW),
        "paths": {n: {"points": [list(p) for p in pts], "half_width": hw} for n, pts, hw in PATHS},
        "clear": [[SQUARE_C[0], SQUARE_C[1], SQUARE_R + 0.5], [JETTY_SQ_C[0], JETTY_SQ_C[1], JETTY_SQ_R + 0.5],
                  [DYE_YARD_C[0], DYE_YARD_C[1], DYE_YARD_R], [WELL_C[0], WELL_C[1], WELL_YARD_R + 1.0]]
                 + [[c[0], c[1], max(w, d) * 0.5 + 2.2] for _, c, w, d, _, _ in HOUSES]
                 + [[c[0], c[1], max(w, d) * 0.5 + 1.8] for _, c, w, d, _ in COTTAGES + SHEDS]
                 + [[25.0 + k * 1.5, JETTY_SQ_C[1], JETTY_W * 0.5 + 0.7] for k in range(int(JETTY_LEN / 1.5) + 1)]
                 + [[LANDING_C[0] + k * 1.5, LANDING_C[1], LANDING_W * 0.5 + 0.7] for k in range(int(LANDING_LEN / 1.5) + 1)],
    }
    return data


if __name__ == "__main__":
    out = sys.argv[1]
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(to_json(), f, indent=1)
        f.write("\n")
    print("LAYOUT", out, len(MARKERS), "markers", len(props()), "props")
