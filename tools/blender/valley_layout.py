"""Hazewater Vale layout: markers, river, path and the height field, in Godot coordinates.

Pure Python + numpy, shared by tools/blender/make_terrain.py (geometry) and
tools/textures/painted/paint_terrain.py (the painted ground). Godot axes: X east, Y up,
Z south; the player travels from south (+Z) to north (-Z).

The valley as laid out (docs/CONTRACTS.md marker table):
  - west bank lowland: the shrine (M_Spawn), the thorn gate pass (M_GateA, a gap between two
    rocky spurs), the Reed Shallows (M_ZoneA);
  - the Lull enters through a gorge in the north-east wall behind the Camphor Rise, loops
    west round the Rise, runs south between the two zones, is crossed on stepping stones at
    M_Crossing, and leaves through a gorge in the south wall;
  - east bank: the ramp (M_GateB at its middle) up to the Soot Terrace (M_ZoneB, 3 m), and a
    second ramp from the terrace up the Camphor Rise (M_Tree, 6 m);
  - valley walls beyond |x| = 26..30, a far wall north of the river, ridge silhouettes beyond.
"""
import numpy as np

MARKERS = {
    "M_Spawn": (0.0, 0.0, 50.0),
    "M_GateA": (-4.0, 0.0, 36.0),
    "M_ZoneA": (-12.0, 0.0, 20.0),
    "M_Crossing": (0.0, 0.0, 8.0),
    "M_GateB": (6.0, 1.5, 4.0),
    "M_ZoneB": (14.0, 3.0, -10.0),
    "M_Tree": (0.0, 6.0, -42.0),
}
ZONE_RADII = {"M_ZoneA": 16.0, "M_ZoneB": 16.0, "M_Tree": 20.0}

WATER_Y = -0.35
RIVER_HALF = 3.4        # half width of the deep channel
RIVER_BANK = 2.4        # bank slope width beyond the channel
RIVER_BED = -1.8
RIVER = [(52, -66), (38, -70), (22, -73), (6, -72), (-8, -69), (-19, -61), (-25, -48), (-25, -34),
         (-18, -20), (-9, -8), (-3, 2), (0, 8), (5, 18), (9, 30), (12, 42), (14, 54), (15, 66),
         (16, 80), (17, 96), (18, 112)]

PATH = [(1.5, 56), (0, 50), (-2, 43), (-4, 36), (-7, 28), (-12, 20), (-9, 13), (-4, 9.5), (0, 8),
        (3.5, 9.75), (6, 4), (8.5, -1.75), (11, -6), (14, -10), (10, -18), (7, -22), (5, -26.5),
        (3, -31), (1.5, -36), (0, -42)]

TERRACE_C, TERRACE_R = (14.0, -10.0), 17.0
RISE_C, RISE_R = (0.0, -42.0), 17.0
# from, to, y from, y to, half width[, soft side (side, t_end, width), see _soften; side -1 is west
# of the ramp's direction]. RAMP1's bank stops short of the soot bank at M_GateB (t = 0.5), so a
# player on the shore west of the ramp can walk up onto it below the gate but not round the gate.
RAMP1 = ((3.5, 9.75), (8.5, -1.75), 0.0, 3.0, 2.6, (-1, 0.36, 4.0))
RAMP2 = ((7.0, -22.0), (3.0, -31.0), 3.0, 6.0, 3.0)
RAMP3 = ((-9.0, -22.0), (-11.0, -37.0), 0.0, 6.0, 2.6)  # the way back up the Rise's west flank
GATE_SPURS = [((-30.0, 36.0), (-8.5, 36.0)), ((0.5, 36.0), (12.0, 34.5))]  # rocky spurs either side of gate A
STONE_SPACING = 1.45

# Floor heightfield (split into pieces) and the outer wall ring.
FLOOR_X = (-36.0, 36.0)
FLOOR_Z = (-84.0, 79.2)
FLOOR_STEP = 1.2
WALL_STEP = 4.8
OUTER_X = (-74.4, 74.4)
OUTER_Z = (-122.4, 117.6)


def _smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash_noise(x, z, scale, seed):
    """Smooth value noise (bilinear on a hashed lattice), about [-1, 1]."""
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
    """Distance from points (arrays) to a polyline; also returns the arc-length position."""
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


def _ramp(x, z, ramp, flare=0.0):
    """Ramp height and blend weight; flare widens the side falloff at the foot by that many metres,
    so a ramp that starts on open ground can be stepped onto from the side as well as the end."""
    (ax, az), (bx, bz), y0, y1, hw = ramp[:5]
    dx, dz = bx - ax, bz - az
    l2 = dx * dx + dz * dz
    t_raw = ((x - ax) * dx + (z - az) * dz) / l2
    t = np.clip(t_raw, 0.0, 1.0)
    perp = np.hypot(x - (ax + t * dx), z - (az + t * dz))
    inside = _smoothstep(hw + 1.2 + flare * _smoothstep(0.3, 0.0, t_raw), hw, perp) * _smoothstep(-0.08, 0.0, t_raw) * _smoothstep(1.15, 1.0, t_raw)
    return y0 + (y1 - y0) * t, inside


def _soften(h, x, z, ramp):
    """A ramp's soft side (side, t_bank, width), applied after the river cut. Ground standing higher
    than the ramp within width of its edge is cut down to the ramp, so no ridge stands beside it.
    A round bank, width in radius, rises from the shore to the ramp's edge at t_bank, so a player
    on the shore can walk up onto the ramp there; elsewhere the drop to the shore stays steep."""
    (ax, az), (bx, bz), y0, y1, hw = ramp[:5]
    side, t_bank, width = ramp[5]
    dx, dz = bx - ax, bz - az
    length = np.hypot(dx, dz)
    t_raw = ((x - ax) * dx + (z - az) * dz) / (length * length)
    t = np.clip(t_raw, 0.0, 1.0)
    perp = np.hypot(x - (ax + t * dx), z - (az + t * dz))
    y = y0 + (y1 - y0) * t
    on_side = (dx * (z - az) - dz * (x - ax)) * side > 0
    near = _smoothstep(hw + width, hw, perp) * on_side * _smoothstep(-0.08, 0.0, t_raw) * _smoothstep(1.15, 1.0, t_raw)
    h = h - np.maximum(0.0, h - y) * near
    nx, nz = -dz / length * side, dx / length * side
    cx, cz = ax + t_bank * dx + nx * hw, az + t_bank * dz + nz * hw
    bank_y = y0 + (y1 - y0) * t_bank - 0.1
    w = _smoothstep(width, 0.0, np.hypot(x - cx, z - cz))
    return h + np.maximum(0.0, bank_y - h) * w


def river_distance(x, z):
    return polyline_distance(x, z, RIVER)[0]


def river_bed(d):
    return RIVER_BED + (0.0 - RIVER_BED) * _smoothstep(RIVER_HALF * 0.35, RIVER_HALF + RIVER_BANK, d)


def height(x, z):
    """Ground height at Godot (x, z). Works on scalars and numpy arrays."""
    x = np.asarray(x, dtype=float)
    z = np.asarray(z, dtype=float)
    path_d, _ = polyline_distance(x, z, PATH)
    flat = _smoothstep(2.5, 7.0, path_d)
    h = 0.35 * fbm(x, z, 14.0, 3) * flat

    # rocky spurs either side of the thorn gate
    for a, b in GATE_SPURS:
        d, _ = polyline_distance(x, z, [a, b])
        spur = 2.6 * _smoothstep(3.2, 1.2, d) * (1.0 + 0.25 * fbm(x, z, 3.0, 11))
        h = np.maximum(h, spur)

    # Soot Terrace and the Camphor Rise: plateaus with ragged cliff edges
    ang = np.arctan2(z - TERRACE_C[1], x - TERRACE_C[0])
    r = TERRACE_R + 1.4 * np.sin(3 * ang + 1.0) + 0.8 * np.sin(7 * ang + 2.0)
    d = np.hypot(x - TERRACE_C[0], z - TERRACE_C[1])
    terrace = 3.0 * _smoothstep(r + 1.3, r - 0.2, d)
    ang = np.arctan2(z - RISE_C[1], x - RISE_C[0])
    r = RISE_R + 1.2 * np.sin(4 * ang + 0.5) + 0.9 * np.sin(9 * ang + 1.7)
    d = np.hypot(x - RISE_C[0], z - RISE_C[1])
    rise_edge = _smoothstep(r + 1.8, r - 0.2, d)
    rise = 6.0 * rise_edge + 0.25 * fbm(x, z, 6.0, 5) * _smoothstep(r - 2, r - 6, d) * _smoothstep(3.0, 6.0, d)
    h = np.maximum(h, np.maximum(terrace, rise))

    for ramp, flare in ((RAMP1, 0.0), (RAMP2, 0.0), (RAMP3, 3.0)):
        y, w = _ramp(x, z, ramp, flare)
        h = np.where(w > 0, np.maximum(h * (1 - w) + y * w, np.minimum(h, y) * (1 - w) + y * w), h)

    # valley walls east and west, the far wall north of the river, the south end
    ax = np.abs(x) - 26.0 - 2.5 * fbm(z, x, 18.0, 7)
    wall = 28.0 * (1.0 - np.exp(-np.maximum(ax, 0.0) / 9.0)) * _smoothstep(0.0, 1.5, ax)
    north = 30.0 * (1.0 - np.exp(-np.maximum(-z - 76.0 + 3.0 * fbm(x, z, 15.0, 8), 0.0) / 10.0))
    south = 22.0 * (1.0 - np.exp(-np.maximum(z - 70.0 + 3.0 * fbm(x, z, 15.0, 9), 0.0) / 10.0))
    cliffs = np.maximum(np.maximum(wall, north), south)
    cliffs = cliffs * (1.0 + 0.18 * fbm(x, z, 9.0, 12, 4))
    h = h + cliffs

    # the river cuts through everything, including the gorges in the walls
    rd = river_distance(x, z)
    h = np.where(rd < RIVER_HALF + RIVER_BANK, np.minimum(h, river_bed(rd) + np.maximum(0.0, h) * _smoothstep(RIVER_HALF, RIVER_HALF + RIVER_BANK + 4.0, rd)), h)
    return _soften(h, x, z, RAMP1)


def stepping_stones():
    """Stone positions across the river at M_Crossing, perpendicular to the flow, top at y = 0."""
    cx, _, cz = MARKERS["M_Crossing"]
    fx, fz = 5.0 - (-3.0), 18.0 - 2.0
    n = np.hypot(fx, fz)
    px, pz = fz / n, -fx / n
    return [(cx + px * k * STONE_SPACING, 0.0, cz + pz * k * STONE_SPACING) for k in (-2, -1, 0, 1, 2)]


EXTRA_MARKERS = {"M_Shrine": (-3.2, 55.0)}


def grid_axis(lo_outer, lo, hi, hi_outer, fine, coarse):
    """Tensor-grid coordinates: coarse cells outside [lo, hi], fine cells inside, no T-junctions."""
    left = np.arange(lo_outer, lo, coarse)
    mid = np.arange(lo, hi + fine * 0.5, fine)
    right = np.arange(hi + coarse, hi_outer + coarse * 0.5, coarse)
    return np.concatenate([left, mid, right])


def zone_of(x, z):
    out = {}
    for name, r in ZONE_RADII.items():
        mx, _, mz = MARKERS[name]
        out[name] = np.hypot(np.asarray(x) - mx, np.asarray(z) - mz) < r
    return out
