"""The Hollow Kiln's ground and buildings, one glTF per model, each under 5,000 triangles.

    blender --background --factory-startup --python tools/levels/hollow_kiln/make_architecture.py -- <model> <out.glb>

Models: ground_s, ground_n (near ground, split at kiln_layout.NEAR_SPLIT_Z; ground_s carries every
M_* marker), far (the valley below and the ridge silhouettes), water (the ink stream and the yard
race), yard, hall, flue, kiln (drum, dome, chimney). Everything is built from kiln_layout.py.

Buildings use tileable painted materials with box-projected world UVs (one scale everywhere,
always upright): M_hk_plaster, M_hk_brick, M_hk_stone, M_hk_timber, M_hk_roof, M_hk_flag,
M_hk_board, M_hk_plank, M_hk_paper, M_hk_iron. The ground uses M_hk_ground (a top-down 1K x 2K
painting, tools/levels/hollow_kiln/paint_kiln.py), the far valley M_hk_far.
Colliders are trimesh "-colonly" objects (Godot: StaticBody3D on layer 1, world); the ground
meshes are "-col" (drawn and collided).
"""
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

import kilnlib as L  # noqa: E402
import kiln_layout as K  # noqa: E402

ik = L.ik
bpy = L.bpy

TILE = {"M_hk_plaster": 6.0, "M_hk_brick": 4.0, "M_hk_stone": 5.0, "M_hk_timber": 3.0, "M_hk_roof": 4.0,
        "M_hk_flag": 6.0, "M_hk_board": 4.0, "M_hk_plank": 3.0, "M_hk_paper": 2.0, "M_hk_iron": 2.0}
# vertex colour per material: R outline weight, G sway, B dry-brush tendency
VCOL = {"M_hk_plaster": (0.8, 0.0, 0.45), "M_hk_brick": (0.9, 0.0, 0.5), "M_hk_stone": (0.95, 0.0, 0.45),
        "M_hk_timber": (1.0, 0.0, 0.35), "M_hk_roof": (1.0, 0.0, 0.4), "M_hk_flag": (0.5, 0.0, 0.6),
        "M_hk_board": (0.45, 0.0, 0.6), "M_hk_plank": (0.8, 0.0, 0.4), "M_hk_paper": (0.35, 0.25, 0.6),
        "M_hk_iron": (0.7, 0.0, 0.3)}


def part(name, material, pieces, jitter=0.0, seed=0):
    vf = L.merged(*pieces)
    if jitter > 0:
        vf = L.jitter(vf, jitter, seed)
    obj = L.gmake(name, vf)
    ik.assign_material(obj, material)
    L.world_uv(obj, TILE[material])
    r, g, b = VCOL[material]

    def col(co, n, tag):
        under = 1.0 if n[1] < -0.3 else 0.85
        return (r * under, g, b + 0.25 * (ik.hash01(co[0] * 0.7, co[1] * 1.3, co[2] * 0.9) - 0.5))
    L.paint(obj, col)
    return obj


def finish(model, out_glb, objects):
    ik.report(model, [o for o in objects if o is not None and o.type == "MESH" and not o.name.endswith("colonly")])
    ik.export_glb(out_glb)


def roof_slab(x0, x1, z_eave, y_eave, z_ridge, y_ridge, t):
    """One thick roof slope from the eave line to the ridge line, extruded along X."""
    return L.prism_x(x0, x1, [(z_eave, y_eave), (z_ridge, y_ridge), (z_ridge, y_ridge + t), (z_eave, y_eave + t)])


def coping(axis, fixed, a0, a1, y, w=1.5, h=0.55):
    """A little tiled cap along a wall top, so the wall line reads as a brush stroke."""
    prof = [(-w / 2, y), (w / 2, y), (0.0, y + h)]
    if axis == "x":
        return L.prism_x(a0, a1, [(fixed + p, q) for p, q in prof])
    return L.prism_z(a0, a1, [(fixed + p, q) for p, q in prof])


def steps(x0, x1, z_start, z_end, y_start, y_end, n, extra_under=0.0):
    out = []
    for k in range(n):
        t0, t1 = k / n, (k + 1) / n
        za, zb = z_start + (z_end - z_start) * t0, z_start + (z_end - z_start) * t1
        y = y_start + (y_end - y_start) * t1
        out.append(L.gbox(x0, x1, min(y_start, y_end) - extra_under, y, za, zb))
    return out


# ------------------------------------------------------------------------------------ ground
def heightfield(name, xs, zs, hfn, material, uvfn, target_tris, rfn):
    gx, gz = np.meshgrid(xs, zs)
    H = hfn(gx, gz)
    verts, faces = [], []
    nx = len(xs)
    for j in range(len(zs)):
        for i in range(nx):
            verts.append((float(xs[i]), float(H[j, i]), float(zs[j])))
    for j in range(len(zs) - 1):
        for i in range(nx - 1):
            a, b, c, d = j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i
            if abs(H[j, i] - H[j + 1, i + 1]) <= abs(H[j, i + 1] - H[j + 1, i]):
                faces += [(a, b, c), (a, c, d)]
            else:
                faces += [(a, b, d), (b, c, d)]
    obj = L.gmake(name, (verts, faces))
    mesh = obj.data
    if sum(1 for p in mesh.polygons if p.normal.z > 0) < len(mesh.polygons) / 2:
        for p in mesh.polygons:
            p.flip()
    ik.assign_material(obj, material)
    full = len(mesh.polygons)
    if target_tris and full > target_tris:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.use_collapse_triangulate = True
        dec.ratio = target_tris / full
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=dec.name)
    mesh = obj.data
    for p in mesh.polygons:
        p.use_smooth = True
    ik.planar_uv(obj, lambda co: uvfn(co.x, -co.y))
    eps = 0.8

    def col(co, n, tag):
        x, y, z = co
        sx = (float(hfn(np.array(x + eps), np.array(z))) - float(hfn(np.array(x - eps), np.array(z)))) / (2 * eps)
        sz = (float(hfn(np.array(x), np.array(z + eps))) - float(hfn(np.array(x), np.array(z - eps)))) / (2 * eps)
        return rfn(math.hypot(sx, sz), x, z)
    L.paint(obj, col)
    print("GROUND %s %d -> %d tris" % (name, full, len(mesh.polygons)))
    return obj


def ground_uv(x, z):
    return ((x - K.NEAR_X[0]) / (K.NEAR_X[1] - K.NEAR_X[0]), 1.0 - (z - K.NEAR_Z[0]) / (K.NEAR_Z[1] - K.NEAR_Z[0]))


def ground_r(slope, x, z):
    r = 0.12 + 0.85 * ik.smoothstep(0.5, 1.4, slope)
    return (r, 0.0, 0.35 + 0.3 * ik.hash01(x * 0.3, z * 0.3) + 0.2 * (1 - r))


def build_ground(model, out_glb):
    xs = np.arange(K.NEAR_X[0], K.NEAR_X[1] + 0.01, K.NEAR_STEP)
    if model == "ground_s":
        zs = np.arange(K.NEAR_SPLIT_Z, K.NEAR_Z[1] + 0.01, K.NEAR_STEP)
    else:
        zs = np.arange(K.NEAR_Z[0], K.NEAR_SPLIT_Z + 0.01, K.NEAR_STEP)
    name = "GroundS-col" if model == "ground_s" else "GroundN-col"
    obj = heightfield(name, xs, zs, K.height, "M_hk_ground", ground_uv, 4700, ground_r)
    objects = [obj]
    if model == "ground_s":
        for mname, (x, y, z) in K.MARKERS.items():
            objects.append(ik.make_empty(mname, ik.g2b(x, y, z)))
            print("MARKER %s (%.2f, %.2f, %.2f) ground %.2f" % (mname, x, y, z, float(K.height(np.array(x), np.array(z)))))
    finish(model, out_glb, objects)


def build_far(model, out_glb):
    xs = np.arange(K.FAR_X[0], K.FAR_X[1] + 0.01, 10.0)
    zs = np.arange(K.FAR_Z[0], K.FAR_Z[1] + 0.01, 10.0)

    def hfn(x, z):
        return K.far_height(x, z)

    def uvfn(x, z):
        return (0.02 + 0.46 * (x - K.FAR_X[0]) / (K.FAR_X[1] - K.FAR_X[0]), 0.98 - 0.46 * (z - K.FAR_Z[0]) / (K.FAR_Z[1] - K.FAR_Z[0]))
    obj = heightfield("FarValley", xs, zs, hfn, "M_hk_far", uvfn, 3200, lambda s, x, z: (0.1 + 0.6 * ik.smoothstep(0.4, 1.2, s), 0.0, 0.7))
    ridges = []
    for layer, (radius, base_h, amp, seed) in enumerate([(260, 18, 40, 51), (360, 28, 70, 57), (480, 40, 110, 61)]):
        n = 48
        verts, faces = [], []
        for k in range(n + 1):
            a = math.radians(-100 + 200 * k / n)
            cx, cz = math.sin(a) * radius, 40.0 + math.cos(a) * radius * 1.1
            peak = base_h + amp * (0.5 + 0.5 * float(K.fbm(np.array(k * 9.0), np.array(layer * 50.0), 40.0, seed, 4)))
            peak += amp * 0.4 * abs(math.sin(k * 1.3 + layer)) ** 3
            verts.append((cx, peak, cz))
            verts.append((cx * 0.98, -60.0, cz))
        for k in range(n):
            faces.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
        o = L.gmake("Ridge_%d" % layer, (verts, faces))
        for p in o.data.polygons:
            c = p.center
            if (c.x * p.normal.x + c.y * p.normal.y) > 0:
                p.flip()
        ik.assign_material(o, "M_hk_far")
        ik.planar_uv(o, lambda co, layer=layer: (0.52 + 0.46 * ((math.atan2(co.x, -co.y) / (2 * math.pi)) % 1.0), 0.6 + 0.12 * layer + 0.1 * min(1.0, max(0.0, (co.z + 60.0) / 220.0))))
        ik.paint_vertex_colors(o, lambda co, lc, n, tag: (0.55 if co.z > 0 else 0.0, 0.0, 0.7))
        ridges.append(o)
    finish(model, out_glb, [obj] + ridges)


def ribbon(pts, half, yfn, step):
    pts = np.array(pts, dtype=float)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    samples = np.arange(0, s[-1], step)
    px, pz = np.interp(samples, s, pts[:, 0]), np.interp(samples, s, pts[:, 1])
    verts, faces = [], []
    for k in range(len(samples)):
        k0, k1 = max(0, k - 1), min(len(samples) - 1, k + 1)
        tx, tz = px[k1] - px[k0], pz[k1] - pz[k0]
        tl = math.hypot(tx, tz)
        nx, nz = -tz / tl, tx / tl
        hw = half(pz[k])
        for side in (-1, 1):
            x, z = px[k] + nx * hw * side, pz[k] + nz * hw * side
            verts.append((x, yfn(x, z), z))
    for k in range(len(samples) - 1):
        faces.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
    return verts, faces


def build_water(model, out_glb):
    def ywater(x, z):
        if z <= 56.0:
            return K.WATER_Y
        return float(-0.12 * max(z - 52.0, 0.0) - 2.5 - 0.4)
    stream = L.gmake("Stream", ribbon(K.STREAM, lambda z: K.STREAM_HALF + 0.9 if z < 60 else 5.0, ywater, 2.0))
    race = L.gmake("Race", (lambda x0, x1, z0, z1, y: ([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], [(0, 3, 2, 1)]))(
        K.RACE["x"][0], K.RACE["x"][1], K.RACE["z"][0], K.RACE["z"][1] + 1.0, K.RACE["ink"]))
    for o in (stream, race):
        for p in o.data.polygons:
            if p.normal.z < 0:
                p.flip()
        ik.assign_material(o, "M_hk_water")
        ik.planar_uv(o, lambda co: (co.x * 0.1, -co.y * 0.1))
        ik.paint_vertex_colors(o, lambda co, lc, n, tag: (0.0, 0.0, 0.0))
    finish(model, out_glb, [stream, race])


# ------------------------------------------------------------------------------------ yard
def build_yard(model, out_glb):
    Y, YH = K.Y_YARD, K.YARD["wall_h"]
    x0, x1 = K.YARD["x"]
    z0, z1 = K.YARD["z"]
    t = K.YARD["wall_t"]
    top = Y + YH
    stone, plaster, flag, roof, timber, brick = [], [], [], [], [], []
    col = []
    # south wall with the gate and the race culvert
    gx0, gx1 = K.GATE["x"]
    south = L.wall_run("x", z1 + t / 2, x0 - t, x1 + t, t, Y - 1.2, top,
                       [(gx0 - 0.6, gx1 + 0.6, Y + K.GATE["h"]), (K.RACE["x"][0], K.RACE["x"][1], Y - 0.1, Y - 1.2)])
    plaster += south
    east = L.wall_run("z", x1 + t / 2, z0 - 3.0, z1 + t, t, Y - 1.0, top)
    west = L.wall_run("z", x0 - t / 2, z0 - 3.0, z1 + t, t, Y - 1.0, top)
    plaster += east + west
    col += south + east + west
    # wall feet in rough stone, tops capped with tiles
    for a0, a1, axis, fixed in ((x0 - t, gx0 - 0.6, "x", z1 + t / 2), (gx1 + 0.6, x1 + t, "x", z1 + t / 2),
                                (z0 - 3.0, z1 + t, "z", x1 + t / 2), (z0 - 3.0, z1 + t, "z", x0 - t / 2)):
        roof.append(coping(axis, fixed, a0, a1, top))
        if axis == "x":
            stone.append(L.gbox(a0, a1, Y - 1.2, Y + 0.7, fixed - t / 2 - 0.12, fixed + t / 2 + 0.12))
        else:
            stone.append(L.gbox(fixed - t / 2 - 0.12, fixed + t / 2 + 0.12, Y - 1.2, Y + 0.7, a0, a1))
    # gate towers and the gate roof
    for side in (-1, 1):
        cx = side * (gx1 + 1.4)
        stone.append(L.gbox(cx - 1.0, cx + 1.0, Y - 1.0, Y + 5.6, z1 - 0.4, z1 + 1.6))
        col.append(L.gbox(cx - 1.0, cx + 1.0, Y - 1.0, Y + 5.6, z1 - 0.4, z1 + 1.6))
        roof.append(L.gbox(cx - 1.3, cx + 1.3, Y + 5.6, Y + 5.9, z1 - 0.7, z1 + 1.9))
    timber.append(L.gbox(gx0 - 0.9, gx1 + 0.9, Y + K.GATE["h"], Y + K.GATE["h"] + 0.55, z1 - 0.2, z1 + 1.2))
    roof.append(roof_slab(gx0 - 3.2, gx1 + 3.2, z1 + 2.6, Y + 5.5, z1 + 0.5, Y + 6.9, 0.3))
    roof.append(roof_slab(gx0 - 3.2, gx1 + 3.2, z1 - 1.6, Y + 5.5, z1 + 0.5, Y + 6.9, 0.3))
    # yard floor in flagstones, the race cut through it, the apron outside the gate
    rx0, rx1 = K.RACE["x"]
    flag.append(L.gbox(x0, rx0 - 0.4, Y - 0.4, Y, z0 - 0.4, z1))
    flag.append(L.gbox(rx1 + 0.4, x1, Y - 0.4, Y, z0 - 0.4, z1))
    flag.append(L.gbox(gx0 - 0.6, gx1 + 0.6, Y - 0.4, Y, z1, z1 + t))
    ax, az = K.GATE_APRON["x"], K.GATE_APRON["z"]
    flag.append(L.gbox(ax[0], ax[1], Y - 1.2, Y, az[0] - 0.5, az[1]))
    col += flag[:]
    # race kerbs and floor
    for kx0, kx1 in ((rx0 - 0.4, rx0), (rx1, rx1 + 0.4)):
        stone.append(L.gbox(kx0, kx1, K.RACE["floor"], Y + 0.12, K.RACE["z"][0], z1 + t))
    stone.append(L.gbox(rx0, rx1, K.RACE["floor"] - 0.3, K.RACE["floor"], K.RACE["z"][0], z1 + t + 0.4))
    col += stone[-3:]
    # gate stair with cheek walls
    sx, sz, sy = K.GATE_STAIR["x"], K.GATE_STAIR["z"], K.GATE_STAIR["y"]
    st = steps(sx[0], sx[1], sz[0], sz[1], sy[0], sy[1], 9, extra_under=0.8)
    stone += st
    col += st
    for cx in (sx[0] - 0.5, sx[1] + 0.5):
        stone.append(L.prism_x(cx - 0.5, cx + 0.5, [(sz[0] + 0.6, sy[0] - 0.8), (sz[1], sy[1] - 0.8), (sz[1] - 0.6, sy[1] + 0.7), (sz[0] + 0.6, sy[0] + 0.6)]))
    # retaining wall up to the hall terrace, the hall stair, the terrace
    hx = K.HALL_STAIR["x"]
    rz = K.HALL_STAIR["z"][1] + 0.5
    ret = L.wall_run("x", rz, x0 - t, x1 + t, 1.0, Y - 0.4, K.Y_HALL + 0.5, [(hx[0], hx[1], K.Y_HALL + 0.6),
                                                                          (rx0, rx1, Y - 0.1, Y - 1.2)])
    stone += ret
    col += ret
    hs = steps(hx[0], hx[1], K.HALL_STAIR["z"][0], K.HALL_STAIR["z"][1], Y, K.Y_HALL, 12, extra_under=0.3)
    stone += hs
    col += hs
    stone.append(L.prism_x(hx[1], hx[1] + 0.8, [(K.HALL_STAIR["z"][0] + 0.4, Y - 0.2), (K.HALL_STAIR["z"][1], K.Y_HALL - 0.2),
                                                 (K.HALL_STAIR["z"][1], K.Y_HALL + 0.8), (K.HALL_STAIR["z"][0] + 0.4, Y + 0.6)]))
    terrace = L.gbox(x0 - t, x1 + t, K.Y_HALL - 0.6, K.Y_HALL, K.HALL["z"][1] - 0.4, rz - 0.5)
    flag.append(terrace)
    col.append(terrace)
    # soot tunnel: a long low vaulted brick oven along the east wall, with stacks
    prof = [(12.0, Y - 0.1), (15.4, Y - 0.1)]
    for k in range(9):
        a = math.pi * k / 8
        prof.append((13.7 + math.cos(a) * 1.7, Y + 1.2 + math.sin(a) * 1.4))
    prof = [prof[0], prof[1]] + prof[2:]
    tunnel = L.prism_z(6.0, 26.0, [(15.4, Y - 0.1)] + [(13.7 + math.cos(math.pi * k / 8) * 1.7, Y + 1.2 + math.sin(math.pi * k / 8) * 1.4) for k in range(9)] + [(12.0, Y - 0.1)])
    brick.append(tunnel)
    col.append(L.gbox(12.0, 15.4, Y, Y + 2.6, 6.0, 26.0))
    for zc in (9.0, 16.0, 23.0):
        brick.append(L.cylinder(13.7, zc, 0.55, Y + 2.2, Y + 4.4, 6, r_top=0.42))
        stone.append(L.gbox(12.8, 14.6, Y + 0.2, Y + 1.0, zc - 0.5, zc + 0.5))
    # stoke mouths on the yard side of the tunnel (dark openings painted as soot)
    for zc in (8.0, 12.5, 17.0, 21.5, 25.0):
        timber.append(L.gbox(11.85, 12.05, Y + 0.1, Y + 0.95, zc - 0.5, zc + 0.5))
    objects = [
        part("YardWalls", "M_hk_plaster", plaster, 0.04, 1),
        part("YardStone", "M_hk_stone", stone, 0.05, 2),
        part("YardFloor", "M_hk_flag", flag),
        part("YardRoof", "M_hk_roof", roof, 0.03, 3),
        part("YardTimber", "M_hk_timber", timber, 0.02, 4),
        part("YardBrick", "M_hk_brick", brick, 0.03, 5),
        L.collider("YardCollider", col),
    ]
    finish(model, out_glb, objects)


# ------------------------------------------------------------------------------------ hall
def build_hall(model, out_glb):
    Y = K.Y_HALL
    x0, x1 = K.HALL["x"]
    z0, z1 = K.HALL["z"]
    t = K.HALL["wall_t"]
    eave, ridge = Y + K.HALL["eave"], Y + K.HALL["ridge"]
    plaster, stone, timber, roof, board, plank, paper = [], [], [], [], [], [], []
    col = []
    win = [(-6.0, -3.5, 10.8, 8.6), (1.0, 3.5, 10.8, 8.6), (7.0, 9.5, 10.8, 8.6), (13.0, 15.5, 10.8, 8.6)]
    sd = K.HALL_DOOR_S
    south = L.wall_run("x", z1 - t / 2, x0, x1, t, Y - 0.6, eave, [(sd["x"][0], sd["x"][1], Y + sd["h"])] + win)
    nd = K.HALL_DOOR_N
    north = L.wall_run("x", z0 + t / 2, x0, x1, t, Y - 0.6, eave, [(nd["x"][0], nd["x"][1], Y + nd["h"])])
    east = L.wall_run("z", x1 - t / 2, z0, z1, t, Y - 0.6, eave, [(-15.0, -11.0, 10.4, 8.4)])
    west = L.wall_run("z", x0 + t / 2, z0, z1, t, Y - 0.6, eave)
    plaster += south + north + east + west
    col += south + north + east + west
    # gables up to the ridge
    zm = (z0 + z1) / 2
    for gx, sgn in ((x0, 1), (x1, -1)):
        plaster.append(L.prism_x(min(gx, gx + sgn * t), max(gx, gx + sgn * t), [(z1, eave), (zm, ridge), (z0, eave)]))
    # timber frame: corner and door posts on the walls, interior posts, tie beams, purlins, king posts
    for px in (x0 + 0.1, x1 - 0.5):
        for pz in (z1 - 0.5, z0 + 0.1):
            timber.append(L.gbox(px, px + 0.4, Y - 0.2, eave + 0.1, pz, pz + 0.4))
    for x in (sd["x"][0] - 0.35, sd["x"][1] - 0.05):
        timber.append(L.gbox(x, x + 0.4, Y - 0.2, Y + sd["h"] + 0.5, z1 - t - 0.15, z1 + 0.15))
    timber.append(L.gbox(sd["x"][0] - 0.6, sd["x"][1] + 0.6, Y + sd["h"], Y + sd["h"] + 0.5, z1 - t - 0.2, z1 + 0.2))
    for x in (nd["x"][0] - 0.35, nd["x"][1] - 0.05):
        timber.append(L.gbox(x, x + 0.4, Y - 0.2, Y + nd["h"] + 0.5, z0 - 0.15, z0 + t + 0.15))
    timber.append(L.gbox(nd["x"][0] - 0.6, nd["x"][1] + 0.6, Y + nd["h"], Y + nd["h"] + 0.5, z0 - 0.2, z0 + t + 0.2))
    for x, z in K.HALL_POSTS:
        timber.append(L.gbox(x - 0.28, x + 0.28, Y, eave, z - 0.28, z + 0.28))
        timber.append(L.gbox(x - 0.45, x + 0.45, Y - 0.1, Y + 0.35, z - 0.45, z + 0.45))
        col.append(L.gbox(x - 0.3, x + 0.3, Y, eave, z - 0.3, z + 0.3))
    for x in (-12.0, -6.0, 0.0, 6.0, 12.0):
        timber.append(L.gbox(x - 0.3, x + 0.3, eave - 0.1, eave + 0.45, z0 + 0.3, z1 - 0.3))
        timber.append(L.gbox(x - 0.22, x + 0.22, eave + 0.45, ridge - 0.1, zm - 0.22, zm + 0.22))
        for sgn in (-1, 1):
            zz = zm + sgn * 5.2
            timber.append(L.prism_x(x - 0.18, x + 0.18, [(zm + sgn * 0.2, ridge - 0.9), (zm + sgn * 0.2, ridge - 0.4), (zz, eave + 0.95), (zz, eave + 0.45)]))
    for z in (-8.6, -17.4, zm):
        yb = eave + 0.45 if z != zm else ridge - 0.45
        timber.append(L.gbox(x0 + 0.5, x1 - 0.5, yb - 0.1, yb + 0.35, z - 0.2, z + 0.2))
    # roof with eaves overhanging and gable overhangs; a ridge cap
    ov = 1.2
    pitch = (ridge - eave) / (zm - z0)
    roof.append(roof_slab(x0 - ov, x1 + ov, z1 + ov, eave - ov * pitch, zm, ridge + 0.05, 0.35))
    roof.append(roof_slab(x0 - ov, x1 + ov, z0 - ov, eave - ov * pitch, zm, ridge + 0.05, 0.35))
    roof.append(L.gbox(x0 - ov - 0.2, x1 + ov + 0.2, ridge + 0.2, ridge + 0.75, zm - 0.45, zm + 0.45))
    # floor: the cursed boards, raised plank decks, the passage to the flue
    floor = L.gbox(x0, x1, Y - 0.6, Y, z0, z1)
    board.append(floor)
    col.append(floor)
    for name, (xr, zr) in K.PLANKS.items():
        deck = L.gbox(xr[0], xr[1], K.Y_PLANK - 0.12, K.Y_PLANK, zr[0], zr[1])
        plank.append(deck)
        col.append(L.gbox(xr[0], xr[1], Y, K.Y_PLANK, zr[0], zr[1]))
        for k in range(int((xr[1] - xr[0]) / 2.0) + 1):
            bx = min(xr[0] + 0.2 + k * 2.0, xr[1] - 0.4)
            timber.append(L.gbox(bx, bx + 0.25, Y, K.Y_PLANK - 0.12, zr[0] + 0.1, zr[1] - 0.1))
    px, pz = K.PASSAGE["x"], K.PASSAGE["z"]
    pw = [L.gbox(px[0] - 0.8, px[0], Y - 0.6, Y + K.PASSAGE["h"] + 0.4, pz[1] - 0.6, pz[0]),
          L.gbox(px[1], px[1] + 0.8, Y - 0.6, Y + K.PASSAGE["h"] + 0.4, pz[1] - 0.6, pz[0])]
    stone += pw
    col += pw
    stone.append(L.gbox(px[0] - 0.8, px[1] + 0.8, Y + K.PASSAGE["h"], Y + K.PASSAGE["h"] + 0.5, pz[1] - 0.6, pz[0]))
    pf = L.gbox(px[0], px[1], Y - 0.6, Y, pz[1] - 0.6, pz[0])
    board.append(pf)
    col.append(pf)
    # paper hung to dry on lines under the roof: sheets in rows across the hall
    import random
    rnd = random.Random(23)
    for z in (-6.2, -11.0, -15.2, -19.6):
        timber.append(L.gbox(x0 + 0.6, x1 - 0.6, Y + 6.15, Y + 6.25, z - 0.05, z + 0.05))
        x = x0 + 1.4
        while x < x1 - 1.6:
            w = rnd.uniform(0.8, 1.1)
            h = rnd.uniform(1.0, 1.5)
            sheet = L.gbox(x, x + w, Y + 6.2 - h, Y + 6.2, z - 0.02, z + 0.02)
            paper.append(L.rotated_y(sheet, rnd.uniform(-6, 6), x + w / 2, z))
            x += w + rnd.uniform(0.25, 0.7)
    objects = [
        part("HallWalls", "M_hk_plaster", plaster, 0.03, 11),
        part("HallStone", "M_hk_stone", stone, 0.03, 12),
        part("HallTimber", "M_hk_timber", timber, 0.015, 13),
        part("HallRoof", "M_hk_roof", roof),
        part("HallFloor", "M_hk_board", board),
        part("HallPlanks", "M_hk_plank", plank, 0.02, 14),
        part("HallPaper", "M_hk_paper", paper),
        L.collider("HallCollider", col),
    ]
    finish(model, out_glb, objects)


# ------------------------------------------------------------------------------------ flue
def ledge(xr, zr, y0, y1, axis, sgn, thick=0.7):
    """A ledge deck whose top climbs from y0 to y1 along axis, toward +axis if sgn > 0."""
    (xa, xb), (za, zb) = (min(xr), max(xr)), (min(zr), max(zr))

    def ytop(x, z):
        if abs(y1 - y0) < 1e-6:
            return y0
        if axis == "x":
            t = (x - xa) / (xb - xa) if sgn > 0 else (xb - x) / (xb - xa)
        else:
            t = (z - za) / (zb - za) if sgn > 0 else (zb - z) / (zb - za)
        return y0 + (y1 - y0) * t
    corners = [(xa, za), (xb, za), (xb, zb), (xa, zb)]
    bottom = [(x, ytop(x, z) - thick, z) for x, z in corners]
    top = [(x, ytop(x, z), z) for x, z in corners]
    return ik.loft([bottom, top])


def build_flue(model, out_glb):
    fx, fz, t = K.FLUE["x"], K.FLUE["z"], K.FLUE["wall_t"]
    base, roof_y = K.FLUE["base"], K.FLUE["roof"]
    brick, stone, timber = [], [], []
    col = []
    px = K.PASSAGE["x"]
    ex = K.FLUE_EXIT["x"]
    south = L.wall_run("x", fx[0] - 0 if False else fz[1] + t / 2, fx[0] - t, fx[1] + t, t, base - 0.5, roof_y,
                       [(px[0], px[1], K.Y_HALL + K.PASSAGE["h"], K.Y_HALL)])
    north = L.wall_run("x", fz[0] - t / 2, fx[0] - t, fx[1] + t, t, base - 0.5, roof_y,
                       [(ex[0], ex[1], K.Y_VAT + K.FLUE_EXIT["h"], K.Y_VAT)])
    east = L.wall_run("z", fx[1] + t / 2, fz[0], fz[1], t, base - 0.5, roof_y)
    west = L.wall_run("z", fx[0] - t / 2, fz[0], fz[1], t, base - 0.5, roof_y)
    brick += south + north + east + west
    col += south + north + east + west
    # roof with a smoke hole, base floor
    hx0, hx1, hz0, hz1 = -10.0, -6.0, -40.0, -36.0
    for b in (L.gbox(fx[0] - t, fx[1] + t, roof_y, roof_y + 0.8, fz[0] - t, hz0),
              L.gbox(fx[0] - t, fx[1] + t, roof_y, roof_y + 0.8, hz1, fz[1] + t),
              L.gbox(fx[0] - t, hx0, roof_y, roof_y + 0.8, hz0, hz1),
              L.gbox(hx1, fx[1] + t, roof_y, roof_y + 0.8, hz0, hz1)):
        stone.append(b)
    stone.append(L.cylinder(-8.0, -38.0, 2.6, roof_y + 0.8, roof_y + 2.4, 8, r_top=2.4, y_cap=False) if False else L.gbox(hx0 - 0.4, hx1 + 0.4, roof_y + 0.8, roof_y + 2.0, hz0 - 0.4, hz0))
    stone.append(L.gbox(hx0 - 0.4, hx1 + 0.4, roof_y + 0.8, roof_y + 2.0, hz1, hz1 + 0.4))
    floor = L.gbox(fx[0], fx[1], base - 0.5, base, fz[0], fz[1])
    stone.append(floor)
    col.append(floor)
    # ledges and the corbels under them
    for name, xr, zr, y0, y1, axis, sgn in K.FLUE_LEDGES:
        lg = ledge(xr, zr, y0, y1, axis, sgn)
        stone.append(lg)
        col.append(lg)
        along = xr if axis == "x" else zr
        n = max(1, int((along[1] - along[0]) / 3.0))
        for k in range(n + 1):
            a = along[0] + (along[1] - along[0]) * (k + 0.5) / (n + 1)
            if axis == "x":
                inner_z = zr[0] if zr[0] > -40 else zr[1]
                wall_z = fz[1] if zr[0] > -40 else fz[0]
                yb = min(y0, y1) - 0.7
                timber.append(L.gbox(a - 0.25, a + 0.25, yb - 0.9, yb, min(inner_z, wall_z), max(inner_z, wall_z)))
            else:
                inner_x = xr[0] if xr[0] > -8 else xr[1]
                wall_x = fx[1] if xr[0] > -8 else fx[0]
                yb = min(y0, y1) - 0.7
                timber.append(L.gbox(min(inner_x, wall_x), max(inner_x, wall_x), yb - 0.9, yb, a - 0.25, a + 0.25))
    # the passage floor and exit lintel stones
    objects = [
        part("FlueWalls", "M_hk_brick", brick, 0.03, 21),
        part("FlueStone", "M_hk_stone", stone, 0.03, 22),
        part("FlueTimber", "M_hk_timber", timber, 0.02, 23),
        L.collider("FlueCollider", col),
    ]
    finish(model, out_glb, objects)


# ------------------------------------------------------------------------------------ kiln
def build_kiln(model, out_glb):
    cx, Y, cz = K.DRUM_C
    R, T = K.DRUM_R, K.DRUM_T
    spring = Y + K.DRUM_WALL_H
    brick, stone, plaster, timber, roof, iron = [], [], [], [], [], []
    col = []
    # openings in the drum wall: (centre angle, width at the inner face, top)
    ent_a = math.degrees(math.atan2(-1.0 - cx, -(K.VAT_PASSAGE["z"][1] - cz)))
    openings = [(ent_a % 360.0, 4.0, Y + K.VAT_PASSAGE["h"])]
    for name, (mx, mz, a) in K.KILN_MOUTHS.items():
        openings.append((a % 360.0, 3.2, Y + 3.4))
    breaks = set(float(a) for a in range(0, 360, 10))
    spans = []
    for a, w, top in openings:
        half = math.degrees(w / 2 / R)
        spans.append(((a - half) % 360.0, (a + half) % 360.0, top))
        breaks.add((a - half) % 360.0)
        breaks.add((a + half) % 360.0)
    breaks = sorted(breaks)
    for i, a0 in enumerate(breaks):
        a1 = breaks[(i + 1) % len(breaks)] + (360.0 if i == len(breaks) - 1 else 0.0)
        mid = ((a0 + a1) / 2) % 360.0
        opening = None
        for s0, s1, top in spans:
            inside = (s0 <= mid <= s1) if s0 <= s1 else (mid >= s0 or mid <= s1)
            if inside:
                opening = top
        if opening is None:
            seg = L.ring_segment(cx, cz, R, R + T, a0, a1, Y - 0.6, spring)
            brick.append(seg)
            col.append(seg)
        else:
            seg = L.ring_segment(cx, cz, R, R + T, a0, a1, opening, spring)
            brick.append(seg)
            col.append(seg)
        stone.append(L.ring_segment(cx, cz, R - 0.25, R + T + 0.3, a0, a1, spring - 0.1, spring + 0.6))
    # dome and its crown ring
    plaster.append(L.dome_shell(cx, spring + 0.6, cz, R, R + T, K.OCULUS_R, sides=36, rings=10, rise=K.DOME_RISE))
    col.append(L.dome_shell(cx, spring + 0.6, cz, R, R + T, K.OCULUS_R, sides=18, rings=6, rise=K.DOME_RISE))
    top = spring + 0.6 + K.DOME_RISE + T
    stone.append(L.cylinder(cx, cz, K.OCULUS_R + 1.2, top - 1.6, top + 0.6, 12, r_top=K.OCULUS_R + 0.9, y_cap=False))
    stone.append(L.cylinder(cx, cz, K.OCULUS_R + 0.15, top - 1.6, top + 0.6, 12, y_cap=False))
    # ribs of darker brick up the dome, so it reads as a kiln from the yard
    for k in range(8):
        a = math.radians(22.5 + 45.0 * k)
        pts = []
        for i in range(9):
            e = math.radians(85.0 * i / 8)
            rr = (R + T + 0.15) * math.cos(e)
            pts.append((cx + math.sin(a) * rr, spring + 0.6 + (K.DOME_RISE + T + 0.15) * math.sin(e), cz - math.cos(a) * rr))
        brick.append(L.gtube(pts, [0.55] * 8 + [0.3], 4))
    # floor and the ring of firing floor round the vat
    floor = L.cylinder(cx, cz, R + 0.2, Y - 0.6, Y, 36)
    stone.append(floor)
    col.append(floor)
    # fireboxes behind the three mouths
    for name, (mx, mz, a) in K.KILN_MOUTHS.items():
        local = [L.gbox(-2.1, 2.1, Y - 0.6, Y + 0.05, -(R + T + 3.2), -(R - 0.1)),
                 L.gbox(-2.1, -1.6, Y, Y + 4.4, -(R + T + 3.2), -(R + T - 0.2)),
                 L.gbox(1.6, 2.1, Y, Y + 4.4, -(R + T + 3.2), -(R + T - 0.2)),
                 L.gbox(-2.1, 2.1, Y, Y + 4.4, -(R + T + 3.7), -(R + T + 3.2)),
                 L.gbox(-2.1, 2.1, Y + 4.0, Y + 4.6, -(R + T + 3.7), -(R + T - 0.2))]
        for b in local:
            g = L.moved(L.rotated_y(b, a), cx, 0.0, cz)
            brick.append(g)
            col.append(g)
        frame = [L.gbox(-1.9, -1.5, Y, Y + 3.6, -(R + 0.1), -(R - 0.3)), L.gbox(1.5, 1.9, Y, Y + 3.6, -(R + 0.1), -(R - 0.3)),
                 L.gbox(-2.1, 2.1, Y + 3.4, Y + 4.0, -(R + 0.1), -(R - 0.35))]
        for b in frame:
            stone.append(L.moved(L.rotated_y(b, a), cx, 0.0, cz))
        grate = L.gbox(-1.4, 1.4, Y + 0.3, Y + 0.6, -(R + T + 2.8), -(R + 0.4))
        iron.append(L.moved(L.rotated_y(grate, a), cx, 0.0, cz))
    # the two tie pillars
    for nm in ("W", "E"):
        px, pz = K.PILLARS[nm]
        p = L.cylinder(px, pz, K.PILLARS["r"], Y, spring, 10, r_top=K.PILLARS["r"] * 0.85)
        stone.append(p)
        col.append(L.cylinder(px, pz, K.PILLARS["r"], Y, spring, 10))
        stone.append(L.gbox(px - 1.3, px + 1.3, Y - 0.1, Y + 0.8, pz - 1.3, pz + 1.3))
        stone.append(L.gbox(px - 1.2, px + 1.2, spring - 0.8, spring, pz - 1.2, pz + 1.2))
        # a timber strut from each pillar head to the drum wall
        for da in (-1, 1):
            tx = px + (1.0 if px > cx else -1.0) * (R - abs(px - cx))
            timber.append(L.gbox(min(px, tx), max(px, tx), spring - 1.4, spring - 0.9, pz - 0.3, pz + 0.3) if da > 0 else
                          L.gbox(px - 0.3, px + 0.3, spring - 1.4, spring - 0.9, pz - 0.3, pz + 0.3))
    # vat passage from the flue
    vx, vz = K.VAT_PASSAGE["x"], K.VAT_PASSAGE["z"]
    for wx0, wx1 in ((vx[0] - 0.8, vx[0]), (vx[1], vx[1] + 0.8)):
        b = L.gbox(wx0, wx1, Y - 0.6, Y + K.VAT_PASSAGE["h"] + 0.5, vz[1] - 1.8, vz[0] + 0.4)
        brick.append(b)
        col.append(b)
    brick.append(L.gbox(vx[0] - 0.8, vx[1] + 0.8, Y + K.VAT_PASSAGE["h"], Y + K.VAT_PASSAGE["h"] + 0.6, vz[1] - 1.8, vz[0] + 0.4))
    pfl = L.gbox(vx[0], vx[1], Y - 0.6, Y, vz[1] - 1.8, vz[0] + 0.4)
    stone.append(pfl)
    col.append(pfl)
    # terrace east of the flue, south of the drum, where the ending is seen from
    terr = L.gbox(2.2, 20.0, Y - 0.8, Y, -48.6, -43.0)
    stone.append(terr)
    col.append(terr)
    stone.append(L.gbox(19.4, 20.0, Y, Y + 1.0, -48.6, -43.0))
    stone.append(L.gbox(2.2, 20.0, Y, Y + 1.0, -43.6, -43.0))
    # chimney and the duct from the drum to it
    ch = K.CHIMNEY
    ccx, ccz = ch["c"]
    w0, w1 = ch["w0"] / 2, ch["w1"] / 2
    brick.append(ik.loft([[(ccx - w0, ch["base"], ccz - w0), (ccx + w0, ch["base"], ccz - w0), (ccx + w0, ch["base"], ccz + w0), (ccx - w0, ch["base"], ccz + w0)],
                          [(ccx - w1, ch["top"], ccz - w1), (ccx + w1, ch["top"], ccz - w1), (ccx + w1, ch["top"], ccz + w1), (ccx - w1, ch["top"], ccz + w1)]]))
    stone.append(L.gbox(ccx - w1 - 0.5, ccx + w1 + 0.5, ch["top"] - 1.2, ch["top"], ccz - w1 - 0.5, ccz + w1 + 0.5))
    stone.append(L.gbox(ccx - w0 - 0.3, ccx + w0 + 0.3, ch["base"] + 12.0, ch["base"] + 12.8, ccz - w0 - 0.3, ccz + w0 + 0.3))
    brick.append(L.prism_z(cz - R - T + 0.5, ccz + w0, [(cx - 2.2, Y + 4.0), (cx + 2.2, Y + 4.0), (cx + 2.2, Y + 9.0), (cx - 2.2, Y + 9.0)]))
    objects = [
        part("KilnBrick", "M_hk_brick", brick, 0.03, 31),
        part("KilnStone", "M_hk_stone", stone, 0.03, 32),
        part("KilnDome", "M_hk_plaster", plaster, 0.05, 33),
        part("KilnTimber", "M_hk_timber", timber),
        part("KilnIron", "M_hk_iron", iron),
        L.collider("KilnCollider", col),
    ]
    finish(model, out_glb, objects)


BUILDERS = {"ground_s": build_ground, "ground_n": build_ground, "far": build_far, "water": build_water,
            "yard": build_yard, "hall": build_hall, "flue": build_flue, "kiln": build_kiln}

if __name__ == "__main__":
    model, out = ik.cli_args()[:2]
    ik.reset()
    BUILDERS[model](model, out)
