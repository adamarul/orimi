"""Geometry helpers for the Hollow Kiln generators, in Godot coordinates (X east, Y up, Z south).

Built on tools/blender/inklib.py (imported, not edited). Every helper returns (verts, faces) in
Godot space; gmake() converts to Blender space and makes the object. Solids are closed so the
inverted-hull outline works from inside a room as well as outside.
"""
import math
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "blender"))
sys.path.insert(0, HERE)
import inklib as ik  # noqa: E402

bpy = ik.bpy
Vector = ik.Vector


def gmake(name, vf, parent=None, location=(0.0, 0.0, 0.0)):
    """Make a Blender object from Godot-space geometry; location is a Godot position."""
    verts, faces = vf
    obj = ik.make_object(name, ([ik.g2b(*v) for v in verts], faces), parent=parent, location=ik.g2b(*location))
    return obj


def gbox(x0, x1, y0, y1, z0, z1):
    xa, xb = min(x0, x1), max(x0, x1)
    za, zb = min(z0, z1), max(z0, z1)
    bottom = [(xa, y0, za), (xb, y0, za), (xb, y0, zb), (xa, y0, zb)]
    top = [(xa, y1, za), (xb, y1, za), (xb, y1, zb), (xa, y1, zb)]
    return ik.loft([bottom, top])


def gbox_c(cx, cy, cz, sx, sy, sz):
    """Box by centre of its base (cx, cy, cz) and size."""
    return gbox(cx - sx / 2, cx + sx / 2, cy, cy + sy, cz - sz / 2, cz + sz / 2)


def jitter(vf, amount, seed):
    """Nudge every vertex a little, so hand-built masonry is not ruler-straight."""
    import random
    rnd = random.Random(seed)
    verts, faces = vf
    cache = {}
    out = []
    for v in verts:
        key = (round(v[0], 3), round(v[1], 3), round(v[2], 3))
        if key not in cache:
            cache[key] = (rnd.uniform(-amount, amount), rnd.uniform(-amount, amount) * 0.5, rnd.uniform(-amount, amount))
        d = cache[key]
        out.append((v[0] + d[0], v[1] + d[1], v[2] + d[2]))
    return out, faces


def wall_run(axis, fixed, a0, a1, t, y0, y1, openings=()):
    """A straight wall along X (axis "x", at z = fixed) or Z (axis "z", at x = fixed), from a0 to a1,
    thickness t centred on fixed, from y0 to y1. openings: (from, to, top) cut through it, with a
    lintel above each up to y1, and (from, to, top, sill) for a window with wall below the sill.
    Returns a list of (verts, faces) boxes."""
    lo, hi = min(a0, a1), max(a0, a1)
    cuts = sorted((max(lo, o[0]), min(hi, o[1]), o[2], o[3] if len(o) > 3 else y0) for o in openings)
    pieces = []
    cur = lo
    spans = []
    for o0, o1, top, sill in cuts:
        if o0 > cur:
            spans.append((cur, o0, y0, y1))
        if top < y1:
            spans.append((o0, o1, top, y1))
        if sill > y0:
            spans.append((o0, o1, y0, sill))
        cur = o1
    if cur < hi:
        spans.append((cur, hi, y0, y1))
    for s0, s1, b0, b1 in spans:
        if axis == "x":
            pieces.append(gbox(s0, s1, b0, b1, fixed - t / 2, fixed + t / 2))
        else:
            pieces.append(gbox(fixed - t / 2, fixed + t / 2, b0, b1, s0, s1))
    return pieces


def ring_segment(cx, cz, r0, r1, a0, a1, y0, y1):
    """A closed prism between two radii and two angles (degrees, 0 = north / -Z, clockwise seen from above)."""
    def p(r, a, y):
        return (cx + math.sin(math.radians(a)) * r, y, cz - math.cos(math.radians(a)) * r)
    bottom = [p(r0, a0, y0), p(r1, a0, y0), p(r1, a1, y0), p(r0, a1, y0)]
    top = [p(r0, a0, y1), p(r1, a0, y1), p(r1, a1, y1), p(r0, a1, y1)]
    return ik.loft([bottom, top])


def cylinder(cx, cz, r, y0, y1, sides=12, r_top=None, y_cap=True):
    r_top = r if r_top is None else r_top
    ring0 = [(cx + math.sin(2 * math.pi * k / sides) * r, y0, cz - math.cos(2 * math.pi * k / sides) * r) for k in range(sides)]
    ring1 = [(cx + math.sin(2 * math.pi * k / sides) * r_top, y1, cz - math.cos(2 * math.pi * k / sides) * r_top) for k in range(sides)]
    return ik.loft([ring0, ring1], cap_start=y_cap, cap_end=y_cap)


def dome_shell(cx, cy, cz, r_in, r_out, oculus, sides=28, rings=7, rise=None):
    """Thick dome shell standing on y = cy, open at the top in an oculus of the given radius
    (measured on the inner surface). rise: interior height (default r_in, a hemisphere; taller
    makes a beehive). Closed solid: inner, outer, base ring and oculus rim."""
    rise = r_in if rise is None else rise
    t = r_out - r_in
    elev_top = math.acos(min(1.0, oculus / r_in))
    elev_out_top = math.acos(min(1.0, (oculus + t * 0.3) / r_out))
    verts, faces = [], []

    def ring(r, h, e):
        return [(cx + math.sin(2 * math.pi * k / sides) * r * math.cos(e), cy + h * math.sin(e),
                 cz - math.cos(2 * math.pi * k / sides) * r * math.cos(e)) for k in range(sides)]
    inner = [ring(r_in, rise, elev_top * i / rings) for i in range(rings + 1)]
    outer = [ring(r_out, rise + t, elev_out_top * i / rings) for i in range(rings + 1)]
    idx_in, idx_out = [], []
    for rg in inner:
        idx_in.append(list(range(len(verts), len(verts) + sides)))
        verts.extend(rg)
    for rg in outer:
        idx_out.append(list(range(len(verts), len(verts) + sides)))
        verts.extend(rg)
    for a, b in zip(idx_out, idx_out[1:]):
        for k in range(sides):
            faces.append((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    for a, b in zip(idx_in, idx_in[1:]):
        for k in range(sides):
            faces.append((b[k], b[(k + 1) % sides], a[(k + 1) % sides], a[k]))
    for a, b in ((idx_in[0], idx_out[0]), (idx_in[-1], idx_out[-1])):
        for k in range(sides):
            faces.append((a[k], b[k], b[(k + 1) % sides], a[(k + 1) % sides]))
    return verts, faces


def prism_x(x0, x1, profile):
    """Extrude a 2D profile [(z, y), ...] (a closed polygon in the ZY plane) along X."""
    a = [(x0, y, z) for z, y in profile]
    b = [(x1, y, z) for z, y in profile]
    return ik.loft([a, b])


def prism_z(z0, z1, profile):
    """Extrude a 2D profile [(x, y), ...] along Z."""
    a = [(x, y, z0) for x, y in profile]
    b = [(x, y, z1) for x, y in profile]
    return ik.loft([a, b])


def gtube(points, radii, sides=5):
    """inklib.tube for a Godot-space polyline; returns Godot-space geometry."""
    bpts = [ik.g2b(*p) for p in points]
    v, f = ik.tube(bpts, radii, sides)
    return [(x, z, -y) for x, y, z in v], f


def rotated_y(vf, deg, cx=0.0, cz=0.0):
    """Rotate Godot-space geometry about the vertical axis through (cx, cz); positive turns -Z toward +X."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    verts, faces = vf
    out = []
    for x, y, z in verts:
        dx, dz = x - cx, z - cz
        out.append((cx + dx * c - dz * s, y, cz + dx * s + dz * c))
    return out, faces


def moved(vf, dx=0.0, dy=0.0, dz=0.0):
    verts, faces = vf
    return [(x + dx, y + dy, z + dz) for x, y, z in verts], faces


def world_uv(obj, tile):
    """Box-projected UVs in metres / tile: floors and roofs from above, walls from the side, so a
    tileable painted texture keeps one scale and stays upright everywhere."""
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    mw = obj.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    for poly in mesh.polygons:
        n = (nm @ poly.normal).normalized()
        gx, gy, gz = n.x, n.z, -n.y
        for li in poly.loop_indices:
            co = mw @ mesh.vertices[mesh.loops[li].vertex_index].co
            x, y, z = co.x, co.z, -co.y
            if abs(gy) > 0.72:
                u, v = x, -z
            elif abs(gx) > abs(gz):
                u, v = (-z if gx > 0 else z), y
            else:
                u, v = (x if gz > 0 else -x), y
            uv[li].uv = (u / tile, v / tile)


def merged(*parts):
    return ik.merged(*parts)


def collider(name, boxes, parent=None):
    """One trimesh collider (no mesh drawn) on the world layer: the glTF -colonly suffix."""
    if not boxes:
        return None
    return gmake(name + "-colonly", merged(*boxes), parent=parent)


def tag_by(obj, fn):
    """fn(godot_center, godot_normal) -> tag."""
    def f(c, n, o):
        return fn((c.x, c.z, -c.y), (n.x, n.z, -n.y))
    ik.tag_faces(obj, f)


def paint(obj, fn):
    """fn(godot_co, godot_normal, tag) -> (r, g, b) vertex colour."""
    ik.paint_vertex_colors(obj, lambda co, lc, n, tag: fn((co.x, co.z, -co.y), (n.x, n.z, -n.y), tag))
