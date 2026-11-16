"""The Hollow Kiln (Level 5): every number the level is built from, in Godot coordinates.

Pure Python + numpy. Shared by the Blender generators (make_kiln.py, make_kiln_props.py), the
terrain painter (paint_kiln.py), the plan drawing (plan.py) and docs/levels/hollow_kiln/DESIGN.md,
so the plan, the terrain and the design cannot disagree. Godot axes: X east, Y up, Z south.
The player arrives from the south (+Z) and climbs north (-Z).

The four spaces climb a mountain shoulder at the river's head, the way a climbing kiln is
built up a slope:
  landing     y = 0    Pell's raft, the black stream, the first verse-stone
  yard        y = 2    walled yard, gate tied with ink cord, two dead braziers, sealed fight
  drying hall y = 5    long roofed hall, cursed floor, planks, two bellows, counterweight door
  flue        y = 5..18  square shaft, ledges spiralling up, ink rising from below
  vat chamber y = 18   round drum under the dome; the cracked vat; the Dregs
"""
import math

import numpy as np

# ------------------------------------------------------------------ elevations
Y_LANDING = 0.0
Y_YARD = 2.0
Y_HALL = 5.0
Y_PLANK = 5.3
Y_VAT = 18.0
WATER_Y = -0.4

# ------------------------------------------------------------------ the four spaces
YARD = {"x": (-16.0, 16.0), "z": (2.0, 32.0), "y": Y_YARD, "wall_h": 4.5, "wall_t": 1.0}
GATE = {"x": (-3.0, 3.0), "z": 32.0, "h": 4.6}                     # opening in the south yard wall
GATE_STAIR = {"x": (-4.0, 4.0), "z": (40.0, 35.5), "y": (Y_LANDING, Y_YARD)}
GATE_APRON = {"x": (-8.0, 8.0), "z": (32.5, 35.5), "y": Y_YARD}       # stone apron in front of the gate
HALL_STAIR = {"x": (-15.0, -9.0), "z": (9.0, 0.6), "y": (Y_YARD, Y_HALL)}
RACE = {"x": (9.0, 11.2), "z": (-1.0, 32.6), "floor": Y_YARD - 1.2, "ink": Y_YARD - 0.55}   # open ink channel
HALL = {"x": (-18.0, 18.0), "z": (-24.0, -2.0), "y": Y_HALL, "eave": 7.0, "ridge": 11.0, "wall_t": 0.8}
HALL_DOOR_S = {"x": (-14.0, -10.0), "h": 5.0}                       # south wall, from the yard stair
HALL_DOOR_N = {"x": (-10.0, -6.0), "h": 4.2}                         # north wall, the counterweight door
HALL_POSTS = [(x, z) for z in (-8.6, -17.4) for x in (-12.0, -6.0, 0.0, 6.0, 12.0)]
PASSAGE = {"x": (-10.0, -6.0), "z": (-24.8, -27.8), "y": Y_HALL, "h": 4.2}
FLUE = {"x": (-17.0, 1.0), "z": (-47.0, -29.0), "base": 3.0, "ink0": 4.6, "ink_max": 14.0, "ink_rate": 0.06, "roof": 25.0, "wall_t": 1.2}
FLUE_EXIT = {"x": (-3.0, 1.0), "z": -47.0, "y": Y_VAT, "h": 4.0}
VAT_PASSAGE = {"x": (-3.0, 1.0), "z": (-48.2, -50.4), "y": Y_VAT, "h": 4.0}
DRUM_C = (2.0, Y_VAT, -64.0)
DRUM_R = 14.0            # interior radius of the vat chamber
DRUM_T = 2.0             # wall thickness
DRUM_WALL_H = 10.0       # floor to the dome's spring line
DOME_R = 14.0            # interior dome radius at the spring line
DOME_RISE = 22.0         # interior height of the beehive dome above its base ring (taller than a hemisphere)
OCULUS_R = 2.6
CHIMNEY = {"c": (2.0, -94.0), "base": 27.0, "top": 74.0, "w0": 6.4, "w1": 4.2}
VAT = {"c": (2.0, -64.0), "r": 5.0, "rim": Y_VAT + 4.5}
PILLARS = {"W": (-7.0, -64.0), "E": (11.0, -64.0), "r": 0.9, "top": Y_VAT + DRUM_WALL_H, "ring_y": Y_VAT + 5.5}   # tie rings 1 m over the vat rim
KILN_MOUTHS = {name: (DRUM_C[0] + math.sin(math.radians(a)) * (DRUM_R + 0.2), DRUM_C[2] - math.cos(math.radians(a)) * (DRUM_R + 0.2), a)
               for name, a in (("NW", -45.0), ("N", 0.0), ("NE", 45.0))}
# the fire in each kiln mouth's firebox, behind the drum wall: (x, y, z, yaw)
KILN_FIRES = {name: (DRUM_C[0] + math.sin(math.radians(a)) * (DRUM_R + DRUM_T + 1.4), Y_VAT + 0.6,
                     DRUM_C[2] - math.cos(math.radians(a)) * (DRUM_R + DRUM_T + 1.4), -a)
              for name, (_mx, _mz, a) in KILN_MOUTHS.items()}
CHAIN_CROWN = (2.0, Y_VAT + 21.0, -64.0)   # where the four vat chains meet, under the oculus
CHAIN_ANGLES = (45.0, 135.0, 225.0, 315.0)

# ------------------------------------------------------------------ hall planks (safe route)
# Each plank deck is an axis-aligned rectangle: x range, z range. Decks are 0.3 m above the floor.
PLANKS = {
    "P0": ((-17.0, -9.0), (-6.4, -2.0)),     # entry platform inside the south-west door, bellows B1 on it
    "R1": ((-9.0, 15.2), (-6.4, -3.6)),      # front aisle, buried under three soot drifts until B1 blows
    "R2": ((12.6, 15.2), (-19.2, -6.4)),     # east aisle, clear
    "P2": ((12.6, 17.0), (-22.4, -19.2)),    # back corner, bellows B2 on it
    "R3": ((-12.0, 12.6), (-22.4, -19.2)),   # back aisle, buried under three drifts until B2 blows
    "P3": ((-12.0, -4.0), (-23.6, -22.4)),   # strip in front of the counterweight door
}
SOOT_DRIFTS = {   # name: (centre x, z, width along the deck), the deck each one buries
    "D1": (-5.0, -5.0, 3.4), "D2": (3.0, -5.0, 3.4), "D3": (9.6, -5.0, 3.0),
    "D4": (8.0, -20.8, 3.4), "D5": (1.0, -20.8, 3.4), "D6": (-6.0, -20.8, 3.4),
}
RACK_ROWS = [(-9.8, (-11.0, 11.0)), (-12.8, (-11.0, 11.0)), (-15.8, (-11.0, 11.0))]   # z, x range

# ------------------------------------------------------------------ flue ledges
# (name, x range, z range, y at the start, y at the end, axis it climbs along, sign)
FLUE_LEDGES = [
    ("L0", (-17.0, 1.0), (-32.0, -29.0), 5.0, 5.0, "x", 1),       # level with the passage floor
    ("A1", (-2.0, 1.0), (-37.0, -32.0), 5.0, 7.2, "z", -1),
    ("A2", (-2.0, 1.0), (-47.0, -41.0), 8.2, 9.4, "z", -1),
    ("B", (-14.0, -2.0), (-47.0, -44.0), 9.2, 12.0, "x", -1),     # starts beside A2's top, level with it
    ("C1", (-17.0, -14.0), (-47.0, -38.6), 12.0, 12.4, "z", 1),
    ("C2", (-17.0, -14.0), (-33.2, -29.0), 15.0, 15.2, "z", 1),
    ("D", (-14.0, 1.0), (-32.0, -29.0), 15.2, 16.8, "x", 1),
    ("E", (-2.0, 1.0), (-47.0, -32.0), 16.65, 18.0, "z", -1),    # its foot level with D where the walk turns
]
MOSS = {"M1": (1.0, 7.6, -39.0), "M2": (-17.0, 13.2, -36.8), "M3": (-17.0, 14.0, -34.8)}  # wall face; bloom into footholds
FLUE_LAMPS = {"K1": (-4.0, 11.2, -47.0), "K2": (-11.0, 12.6, -47.0), "K3": (-17.0, 14.4, -40.0), "K4": (1.0, 19.4, -44.0)}  # wall face

# ------------------------------------------------------------------ markers
MARKERS = {
    "M_Spawn": (0.0, Y_LANDING, 58.0),
    "M_Raft": (8.2, WATER_Y, 60.0),
    "M_Verse_1": (-4.5, Y_LANDING, 47.0),
    "M_Gate": (0.0, Y_YARD, 32.0),
    "M_Brazier_W": (-5.6, Y_YARD, 34.2),
    "M_Brazier_E": (5.6, Y_YARD, 34.2),
    "M_Yard": (0.0, Y_YARD, 17.0),
    "M_FightYard": (0.0, Y_YARD, 17.0),
    "M_Keeper": (-10.8, Y_YARD, 27.2),
    "M_HallDoor": (-12.0, Y_HALL, -2.0),
    "M_Hall": (0.0, Y_HALL, -13.0),
    "M_Verse_2": (-10.4, Y_PLANK, -3.4),
    "M_Bellows_1": (-15.6, Y_PLANK, -4.2),
    "M_Bellows_2": (15.0, Y_PLANK, -20.8),
    "M_HallAmbush": (1.0, Y_PLANK, -20.8),
    "M_TieAnchor": (-4.6, Y_PLANK, -22.8),
    "M_TieWeight": (-12.6, 10.6, -23.2),
    "M_CounterDoor": (-8.0, Y_HALL, -24.0),
    "M_Flue": (-8.0, FLUE["ink0"], -38.0),
    "M_FlueEntry": (-8.0, 5.0, -30.5),
    "M_FlueTop": (-1.0, Y_VAT, -46.0),
    "M_Verse_3": (-4.8, Y_VAT, -54.0),
    "M_VatChamber": DRUM_C,
    "M_Arena_Entry": (-0.6, Y_VAT, -52.5),
    "M_Vat": (VAT["c"][0], Y_VAT, VAT["c"][1]),
    "M_Pillar_W": (PILLARS["W"][0], Y_VAT, PILLARS["W"][1]),
    "M_Pillar_E": (PILLARS["E"][0], Y_VAT, PILLARS["E"][1]),
    "M_Mouth_NW": (KILN_MOUTHS["NW"][0], Y_VAT, KILN_MOUTHS["NW"][1]),
    "M_Mouth_N": (KILN_MOUTHS["N"][0], Y_VAT, KILN_MOUTHS["N"][1]),
    "M_Mouth_NE": (KILN_MOUTHS["NE"][0], Y_VAT, KILN_MOUTHS["NE"][1]),
    "M_Verse_4": (9.5, Y_VAT, -55.5),
    "M_Pell_End": (-1.6, Y_VAT, -51.2),
    "M_EndView": (2.0, 58.0, -40.0),
}
CURSE_ZONES = [   # CurseField slot, centre, radius: what the drained look covers
    (0, (0.0, Y_YARD, 17.0), 19.0),
    (1, (0.0, Y_HALL, -13.0), 19.5),
    (2, (-8.0, 11.0, -38.0), 13.5),
    (3, (2.0, Y_VAT + 4.0, -64.0), 17.0),
]

# ------------------------------------------------------------------ props placed by the level
# (model, x, y, z, yaw degrees). yaw follows Godot: 0 faces -Z (north).
PROPS = [
    ("brazier", -5.6, Y_YARD, 34.2, 0.0), ("brazier", 5.6, Y_YARD, 34.2, 0.0),
    ("cord_gate", 0.0, Y_YARD, 32.0, 0.0),
    ("woodpile", -13.6, Y_YARD, 24.0, 90.0), ("jars", -13.0, Y_YARD, 14.0, 20.0), ("jars", 6.5, Y_YARD, 28.5, 200.0),
    ("jars", -6.0, Y_YARD, 5.0, 75.0),
    ("bellows", -15.6, Y_PLANK, -4.6, -90.0), ("bellows", 15.0, Y_PLANK, -20.8, 90.0),
    ("tie_post", -4.6, Y_PLANK, -22.8, 0.0),
    ("counterweight", -12.6, Y_HALL, -23.2, 0.0),
    ("vat", VAT["c"][0], Y_VAT, VAT["c"][1], 0.0),
    ("pillar_ring", PILLARS["W"][0] + PILLARS["r"], PILLARS["ring_y"], PILLARS["W"][1], 0.0),
    ("pillar_ring", PILLARS["E"][0] - PILLARS["r"], PILLARS["ring_y"], PILLARS["E"][1], 180.0),
    ("raft_jetty", 7.6, Y_LANDING, 58.0, 0.0),
]
for _x0, _x1 in [(-11.0, -6.2), (-5.2, -0.4), (0.6, 5.4), (6.4, 11.0)]:
    for _z, _ in RACK_ROWS:
        PROPS.append(("drying_rack", (_x0 + _x1) / 2, Y_HALL, _z, 0.0))


def wall_yaw(x, z):
    """Yaw that turns a wall-mounted prop's front (-Z) away from the flue wall it hangs on."""
    if z <= FLUE["z"][0] + 0.01:
        return 180.0
    if x <= FLUE["x"][0] + 0.01:
        return -90.0
    if x >= FLUE["x"][1] - 0.01:
        return 90.0
    return 0.0


for _name, (_x, _y, _z) in FLUE_LAMPS.items():
    PROPS.append(("wall_lamp", _x, _y, _z, wall_yaw(_x, _z)))
for _name, (_x, _y, _z) in MOSS.items():
    PROPS.append(("moss_foothold", _x, _y, _z, wall_yaw(_x, _z)))

# ------------------------------------------------------------------ people and fights
PEOPLE = {
    "Pell": {"at": (3.0, Y_LANDING, 56.2), "yaw": 100.0},
    "Wenna": {"at": MARKERS["M_Keeper"], "yaw": -60.0},
}
FIGHTS = {
    "yard": {"centre": MARKERS["M_FightYard"], "radius": 6.0, "waves": [
        [("splotchet", (-3.0, 0.0, -3.0)), ("splotchet", (3.0, 0.0, -3.0)), ("splotchet", (0.0, 0.0, -5.0)),
         ("splotchet", (-4.0, 0.0, 2.0))],
        [("reedwraith", (-3.5, 0.0, -2.0)), ("reedwraith", (3.5, 0.0, -2.0)), ("splotchet", (0.0, 0.0, 3.0))],
    ]},
    "hall_ambush": {"centre": MARKERS["M_HallAmbush"], "radius": 0.0, "waves": [
        [("splotchet", (-2.0, 0.0, 0.0)), ("splotchet", (2.5, 0.0, 0.3))],
    ]},
}

# ------------------------------------------------------------------ the Dregs (DESIGN.md, "The Dregs")
DREGS = {
    "at": (VAT["c"][0], VAT["rim"], VAT["c"][1]),        # node origin on the vat rim; climb moves it up the chains
    "damage": 1,                                         # petals per hit, every attack
    "checkpoint": "M_Arena_Entry",                      # death restarts the current part, never an earlier one
    "parts": [
        {"name": "veil", "glyph": "gust", "clip": "veiled", "end_clip": "veil_off", "gusts": 2, "regrow_s": 10.0,
         "spit_every_s": 3.0, "spit_tell_s": 0.8, "spit_radius": 1.6, "adds": "splotchet", "adds_max": 2, "adds_every_s": 10.0},
        {"name": "lash", "glyph": "slash", "clips": ["lash_l", "lash_r"], "cuts": 2, "tell_s": 0.83, "slam_s": 0.17,
         "window_s": 1.58, "recover_s": 0.42, "rest_s": 1.2, "lane_w": 1.6, "lane_len": 9.5},
        {"name": "climb", "glyph": "tie", "clip": "climb", "end_clip": "bound", "posts": ["M_Ring_W", "M_Ring_E"],
         "climb_speed": 1.0, "climb_top": CHAIN_CROWN[1] - 3.0, "drip_every_s": 1.5, "drip_tell_s": 0.7, "drip_radius": 1.2,
         "fall_wave_speed": 6.0, "fall_wave_h": 0.5},
        {"name": "dry", "glyph": "kindle", "clip": "bound", "dry_clip": "dry", "mouths": ["M_Mouth_NW", "M_Mouth_N", "M_Mouth_NE"],
         "bound_s": 14.0, "dry_seek_per_mouth": 1.0, "slap_every_s": 4.0, "slap_tell_s": 0.8, "slap_radius": 2.2},
    ],
    "finish": {"clip": "unravel", "seconds": 1.5, "then": "Bloom the cracked vat (M_Vat): vat_tree plays grow"},
}
for _n, (_x, _y, _z) in MOSS.items():   # where Orimi stands on a bloomed foothold
    MARKERS["M_Moss_" + _n] = (_x + (-0.9 if _x > FLUE["x"][1] - 0.01 else 0.9), _y + 0.3, _z)
MARKERS["M_Ring_W"] = (PILLARS["W"][0] + PILLARS["r"] + 0.62, PILLARS["ring_y"] - 0.42, PILLARS["W"][1])
MARKERS["M_Ring_E"] = (PILLARS["E"][0] - PILLARS["r"] - 0.62, PILLARS["ring_y"] - 0.42, PILLARS["E"][1])

# ------------------------------------------------------------------ the route, in order
ROUTE = [
    ("M_Spawn", "Pell's raft lands at the jetty. Pell talks."),
    ("M_Verse_1", "Verse-stone 1 (Bloom)."),
    ("M_Gate", "Slash the ink cord, Kindle both braziers; the gate opens."),
    ("M_FightYard", "Sealed fight: two waves."),
    ("M_Keeper", "Wenna wakes when the yard is clean."),
    ("M_HallDoor", "Up the yard stair into the drying hall."),
    ("M_Verse_2", "Verse-stone 2 (Bloom)."),
    ("M_Bellows_1", "Gust bellows 1: the front aisle clears."),
    ("M_Bellows_2", "Gust bellows 2: the back aisle clears; two Splotchets tumble out."),
    ("M_TieAnchor", "Tie the counterweight to the bollard: the door lifts."),
    ("M_FlueEntry", "The ink starts rising. Bloom moss, Kindle lamps, climb."),
    ("M_FlueTop", "Out of the flue at y = 18."),
    ("M_Verse_3", "Verse-stone 3 (Bloom)."),
    ("M_Arena_Entry", "The Dregs."),
    ("M_Vat", "Bloom on the cracked vat: the tree, the clear river."),
    ("M_Verse_4", "Verse-stone 4, in the roots."),
    ("M_EndView", "The valley in full colour. Pell. End of Book One."),
]
# Walking line through the level (x, z) for the plan, the painted paths and foliage clearance.
PATH = [(0.0, 64.0), (0.0, 58.0), (-1.5, 51.0), (-2.0, 44.5), (0.0, 38.5), (0.0, 33.0), (0.0, 26.0), (0.0, 17.0), (-6.0, 11.0),
        (-12.0, 8.0), (-12.0, 0.0), (-12.0, -4.5), (-4.0, -5.0), (14.0, -5.0), (14.0, -20.8), (-4.6, -20.8),
        (-8.0, -23.0), (-8.0, -26.0), (-8.0, -30.5)]
STREAM = [(10.1, 32.6), (10.1, 36.5), (8.6, 42.0), (9.2, 50.0), (10.4, 58.0), (12.0, 68.0), (15.0, 84.0), (12.0, 110.0),
          (2.0, 140.0), (-14.0, 175.0), (-18.0, 215.0), (-6.0, 260.0), (12.0, 320.0), (20.0, 420.0)]
STREAM_HALF = 2.4

# ------------------------------------------------------------------ height field
NEAR_X = (-64.0, 64.0)
NEAR_Z = (-124.0, 64.0)
NEAR_STEP = 2.0
NEAR_SPLIT_Z = -10.0     # the near ground is two models, north and south of this line
CUT_PAD = 3.0            # ground stays under a floor this far outside each building's walls
FAR_Z = (60.0, 460.0)
FAR_X = (-200.0, 200.0)


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


def rect_distance(x, z, xr, zr):
    """Distance outside an axis-aligned rectangle (0 inside)."""
    dx = np.maximum(np.maximum(xr[0] - x, x - xr[1]), 0.0)
    dz = np.maximum(np.maximum(min(zr) - z, z - max(zr)), 0.0)
    return np.hypot(dx, dz)


def in_rect(x, z, xr, zr, pad=0.0):
    return (x >= xr[0] - pad) & (x <= xr[1] + pad) & (z >= min(zr) - pad) & (z <= max(zr) + pad)


def stream_distance(x, z):
    return polyline_distance(x, z, STREAM)


def height(x, z):
    """Ground height at Godot (x, z), scalars or arrays. Buildings stand on it; inside each
    building footprint the ground sits at or below that building's floor."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    # The mountain shoulder: low by the landing, rising behind the works.
    rise = np.clip(-z, 0.0, None)
    hill = 4.6 + 0.22 * rise + 4.0 * _smoothstep(10.0, 70.0, rise) + 2.2 * fbm(x, z, 22.0, 3)
    # the valley falls away south of the landing
    south = -0.12 * np.clip(z - 52.0, 0.0, None) - 2.5 * _smoothstep(52.0, 90.0, z)
    low = 0.3 * fbm(x, z, 9.0, 5) + south
    h = np.where(z < 4.0, np.maximum(hill * _smoothstep(4.0, -6.0, z) + low * _smoothstep(-6.0, 4.0, z), low), low)
    # side walls of the gorge the works sit in
    side = np.abs(x) - 22.0 - 4.0 * fbm(z, x, 20.0, 7)
    gorge = 26.0 * (1.0 - np.exp(-np.maximum(side, 0.0) / 10.0)) * _smoothstep(0.0, 2.0, side)
    gorge *= 1.0 + 0.2 * fbm(x, z, 8.0, 12, 4)
    gorge *= _smoothstep(120.0, 60.0, z)
    h = h + gorge
    # yard terrace (the flagstone floor is a model; the ground waits just under it)
    yard_d = rect_distance(x, z, (YARD["x"][0] - 1.0, YARD["x"][1] + 1.0), (YARD["z"][0] - 1.0, YARD["z"][1] + 1.0))
    edge = _smoothstep(5.0, 0.0, yard_d)
    h = np.where(yard_d > 0.0, h * (1 - edge) + np.maximum(h, Y_YARD) * edge, Y_YARD - 0.25)
    # landing: a flat bank round the spawn
    land = _smoothstep(11.0, 7.0, np.hypot(x - 0.0, (z - 52.0) * 0.55))
    h = h * (1 - land) + Y_LANDING * land
    # stream bed, from the culvert under the yard's south wall
    sd = stream_distance(x, z)
    bed = WATER_Y - 1.0 + 1.0 * _smoothstep(STREAM_HALF * 0.4, STREAM_HALF + 2.5, sd)
    on = (sd < STREAM_HALF + 6.0) & (z > YARD["z"][1] + 0.4)
    h = np.where(on, np.minimum(h, bed + np.maximum(h - WATER_Y, 0.0) * _smoothstep(STREAM_HALF, STREAM_HALF + 6.0, sd)), h)
    # the gate apron and the ground under the gate stair (the steps are a model)
    apron = in_rect(x, z, (GATE_APRON["x"][0] + 0.3, GATE_APRON["x"][1] - 0.3), GATE_APRON["z"])
    h = np.where(apron, Y_YARD - 0.25, h)
    sx = in_rect(x, z, GATE_STAIR["x"], GATE_STAIR["z"], 0.6)
    t = np.clip((40.0 - z) / 4.5, 0.0, 1.0)
    h = np.where(sx, Y_LANDING + (Y_YARD - Y_LANDING) * t - 0.3, h)
    # under the hall, the flue and the passages the ground stays under the floors
    for xr, zr, top in ((HALL["x"], HALL["z"], Y_HALL - 0.05), (FLUE["x"], FLUE["z"], FLUE["base"]),
                        (PASSAGE["x"], PASSAGE["z"], Y_HALL - 0.05), (VAT_PASSAGE["x"], VAT_PASSAGE["z"], Y_VAT - 0.05)):
        inside = in_rect(x, z, xr, zr, CUT_PAD)
        h = np.where(inside, np.minimum(h, top), h)
    drum_d = np.hypot(x - DRUM_C[0], z - DRUM_C[2])
    h = np.where(drum_d < DRUM_R + DRUM_T + CUT_PAD, np.minimum(h, Y_VAT - 0.05), h)
    # the terrace round the drum's south side, where the ending is seen from
    terr = rect_distance(x, z, (-12.0, 20.0), (-52.0, -44.0))
    h = np.where(terr <= 0.0, np.minimum(h, Y_VAT - 0.05), h)
    # the race through the yard is cut into the yard floor
    race = in_rect(x, z, RACE["x"], RACE["z"])
    h = np.where(race, RACE["floor"], h)
    return h


def far_height(x, z):
    """The valley below the works, seen at the end: falls south, river winding through it."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    base = -0.12 * np.clip(z - 52.0, 0.0, None) - 2.5
    sd = stream_distance(x, z)
    valley = 0.05 * (sd ** 1.35) + 4.0 * fbm(x, z, 40.0, 21, 4) * _smoothstep(8.0, 40.0, sd)
    h = base + valley
    bed = base - 1.2 + 1.2 * _smoothstep(3.0, 8.0, sd)
    return np.where(sd < 8.0, np.minimum(h, bed), h)


def zone_rects():
    """Footprints for the plan drawing."""
    return {
        "yard": (YARD["x"], YARD["z"]), "hall": (HALL["x"], HALL["z"]), "flue": (FLUE["x"], FLUE["z"]),
        "passage": (PASSAGE["x"], PASSAGE["z"]), "vat passage": (VAT_PASSAGE["x"], VAT_PASSAGE["z"]),
    }
