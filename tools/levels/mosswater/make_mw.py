"""Mosswater Wood models, built headless in Blender from mw_layout.py.

    blender --background --factory-startup --python tools/levels/mosswater/make_mw.py -- <model> <out.glb> <paintmap.json>

Models (Blender +Y = Godot -Z is each prop's front; props stand on Z = 0):
  terrain        the wood's ground: three tiers, two banks, three pond basins, the river, as one
                 height field decimated under 5,000 triangles, named Terrain-col (layer 1), with
                 every M_* marker from mw_layout.build_markers(); also writes mw_water.glb (ponds,
                 river, channel, spring, runnels and the three falls) beside it
  (props are added below their own headers)
Uses the shared helpers in tools/blender/inklib.py and tools/blender/props.py (imported, not edited).
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "blender"))
import numpy as np  # noqa: E402

import inklib as ik  # noqa: E402
import mw_layout as L  # noqa: E402
import props as P  # noqa: E402
from mathutils import Vector  # noqa: E402

bpy = ik.bpy
GROUND_TRIS = 4800
GROUND_EXT = 66.0          # the painted ground texture spans x, z in [-66, 66]


def ground_uv(x, z):
    return ((x + GROUND_EXT) / (2 * GROUND_EXT), 1.0 - (z + GROUND_EXT) / (2 * GROUND_EXT))


# ----------------------------------------------------------------------------- terrain
def build_terrain(out_glb, out_map):
    fine, coarse, inner, outer = 0.8, 4.0, 47.2, 67.2
    xs = np.concatenate([np.arange(-outer, -inner, coarse), np.arange(-inner, inner + fine * 0.5, fine), np.arange(inner + coarse, outer + coarse * 0.5, coarse)])
    zs = xs.copy()
    GX, GZ = np.meshgrid(xs, zs)
    H = L.height(GX, GZ)
    eps = 0.4
    dhdx = (L.height(GX + eps, GZ) - L.height(GX - eps, GZ)) / (2 * eps)
    dhdz = (L.height(GX, GZ + eps) - L.height(GX, GZ - eps)) / (2 * eps)
    slope = np.hypot(dhdx, dhdz)
    NOISE = L.fbm(GX, GZ, 5.0, 21)
    nx = len(xs)
    verts, faces = [], []
    for j in range(len(zs)):
        for i in range(nx):
            verts.append(ik.g2b(xs[i], H[j, i], zs[j]))
    for j in range(len(zs) - 1):
        for i in range(nx - 1):
            a, b, c, d = j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i
            if abs(H[j, i] - H[j + 1, i + 1]) <= abs(H[j, i + 1] - H[j + 1, i]):
                faces += [(a, b, c), (a, c, d)]
            else:
                faces += [(a, b, d), (b, c, d)]
    obj = ik.make_object("Terrain-col", (verts, faces))
    mesh = obj.data
    if sum(1 for p in mesh.polygons if p.normal.z > 0) < len(mesh.polygons) / 2:
        for p in mesh.polygons:
            p.flip()
    col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            jj, ii = vi // nx, vi % nx
            sl = slope[jj, ii]
            r = 0.12 + 0.88 * ik.smoothstep(0.5, 1.6, sl)
            col.data[li].color = (r, 0.0, ik.clamp01(0.35 + 0.35 * NOISE[jj, ii] + 0.2 * (1 - r)), 1.0)
    mesh.color_attributes.active_color = col
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    full = len(mesh.polygons)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.use_collapse_triangulate = True
    dec.ratio = GROUND_TRIS / full
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=dec.name)
    mesh = obj.data
    # materials after decimation: steep faces are cliff (side projected), the rest is ground
    mesh.materials.append(bpy.data.materials.new("M_mw_ground"))
    mesh.materials.append(bpy.data.materials.new("M_mw_cliff"))
    uvl = mesh.uv_layers.new(name="UVMap").data
    for poly in mesh.polygons:
        poly.use_smooth = True
        cliff = poly.normal.z < 0.62
        poly.material_index = 1 if cliff else 0
        ns, nt = L.xz_st(poly.normal.x, -poly.normal.y)
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            x, z, y = co.x, -co.y, co.z
            if cliff:
                s, t = L.xz_st(x, z)
                along = t if abs(ns) >= abs(nt) else s
                uvl[li].uv = (along / 9.0, y / 9.0)
            else:
                uvl[li].uv = ground_uv(x, z)

    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
    errs, worst = [], []
    for j in range(0, len(zs), 2):
        for i in range(0, nx, 2):
            if abs(xs[i]) > L.SQUARE or abs(zs[j]) > L.SQUARE:
                continue
            hit = bvh.ray_cast(Vector(ik.g2b(xs[i], 500.0, zs[j])), Vector((0, 0, -1)))
            if hit[0] is not None:
                errs.append(abs(hit[0].z - H[j, i]))
                worst.append((errs[-1], xs[i], zs[j], float(slope[j, i])))
    errs = np.array(errs)
    for e, x, z, sl in sorted(worst, reverse=True)[:4]:
        print("GROUND worst error %.2f m at (%.1f, %.1f), slope %.2f" % (e, x, z, sl))
    flat = np.array([e for e, x, z, sl in worst if sl < 0.5])
    print("GROUND decimated %d -> %d tris; error mean %.3f p95 %.3f max %.3f m; on flat ground p95 %.3f max %.3f" % (
        full, ik.tri_count(obj), errs.mean(), np.percentile(errs, 95), errs.max(), np.percentile(flat, 95), flat.max()))
    markers = L.build_markers()
    for name, (x, y, z) in markers.items():
        hit = bvh.ray_cast(Vector(ik.g2b(x, y + 3.0, z)), Vector((0, 0, -1)))
        mesh_y = hit[0].z if hit[0] is not None else float("nan")
        print("MARKER %s godot=(%.2f, %.2f, %.2f) mesh_ground=%.2f" % (name, x, y, z, mesh_y))
        ik.make_empty(name, ik.g2b(x, y, z))
    ik.dump_paint_map([], out_map, 2048, extra={"kind": "terrain"})
    print("MODEL mw_terrain tris=%d" % ik.tri_count(obj))
    ik.export_glb(out_glb, animated=False)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    build_water(os.path.join(os.path.dirname(out_glb), "mw_water.glb"))


def _ribbon(points, half, y_of, name):
    """Flat water ribbon along an (s, t) polyline; y_of(k, n) gives the surface height."""
    pts = np.array([L.st_xz(s, t) for s, t in points], dtype=float)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    acc = np.concatenate([[0], np.cumsum(seg)])
    samples = np.linspace(0, acc[-1], max(2, int(acc[-1] / 1.5) + 2))
    px, pz = np.interp(samples, acc, pts[:, 0]), np.interp(samples, acc, pts[:, 1])
    verts, faces = [], []
    n = len(samples)
    for k in range(n):
        k0, k1 = max(0, k - 1), min(n - 1, k + 1)
        tx, tz = px[k1] - px[k0], pz[k1] - pz[k0]
        tl = math.hypot(tx, tz)
        nx_, nz_ = -tz / tl, tx / tl
        y = y_of(k, n)
        for side in (-1, 1):
            verts.append(ik.g2b(px[k] + nx_ * half * side, y, pz[k] + nz_ * half * side))
    for k in range(n - 1):
        faces.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
    return ik.make_object(name, (verts, faces))


def _disc(cs, ct, rs, rt, y, name, segs=40):
    verts = [ik.g2b(*L.st_xz(cs, ct)[:1], y, L.st_xz(cs, ct)[1])]
    for k in range(segs):
        a = 2 * math.pi * k / segs
        x, z = L.st_xz(cs + math.cos(a) * rs, ct + math.sin(a) * rt)
        verts.append(ik.g2b(x, y, z))
    faces = [(0, 1 + k, 1 + (k + 1) % segs) for k in range(segs)]
    return ik.make_object(name, (verts, faces))


def _fall(top_st, bottom_st, y_top, y_bottom, width, name):
    (x0, z0), (x1, z1) = L.st_xz(*top_st), L.st_xz(*bottom_st)
    dx, dz = x1 - x0, z1 - z0
    dl = math.hypot(dx, dz)
    nx_, nz_ = -dz / dl, dx / dl
    rows = 6
    verts, faces = [], []
    for r in range(rows + 1):
        f = r / rows
        x, z = x0 + dx * f, z0 + dz * f
        y = y_top + (y_bottom - y_top) * (f ** 1.6)
        for side in (-1, 1):
            verts.append(ik.g2b(x + nx_ * width * 0.5 * side, y, z + nz_ * width * 0.5 * side))
    for r in range(rows):
        faces.append((2 * r, 2 * r + 1, 2 * r + 3, 2 * r + 2))
    return ik.make_object(name, (verts, faces))


def build_water(out_glb):
    objs = []
    for name, p in L.PONDS.items():
        objs.append(_disc(p["c"][0], p["c"][1], p["r"][0] * 1.06, p["r"][1] * 1.06, p["water"], "Pond_%s" % name))
    sp = L.SPRING
    objs.append(_disc(sp["c"][0], sp["c"][1], sp["r"] * 1.1, sp["r"] * 1.1, sp["water"], "Spring", 20))
    objs.append(_ribbon(L.CHANNEL, 2.0, lambda k, n: L.PONDS["low"]["water"] + (L.RIVER_WATER_Y - L.PONDS["low"]["water"]) * k / (n - 1), "Channel"))
    river = [(L.RIVER_S, -40.0), (L.RIVER_S, 40.0)]
    objs.append(_ribbon(river, 4.2, lambda k, n: L.RIVER_WATER_Y, "River"))
    objs.append(_ribbon(L.RUNNELS["weir"][1:], 0.7, lambda k, n: L.T0_NEAR - 0.35, "Runnel_weir"))
    objs.append(_ribbon(L.RUNNELS["notch"][3:], 0.7, lambda k, n: L.T1 - 0.3, "Runnel_notch"))
    objs.append(_ribbon(L.RUNNELS["notch"][:3], 1.2, lambda k, n: L.T2 - 1.05, "Runnel_sluice"))
    objs.append(_ribbon(L.RUNNELS["spring"], 0.7, lambda k, n: L.SPRING["water"] - 0.25 * k / (n - 1), "Runnel_spring"))
    c1 = float(L.cliff1(5.0))
    objs.append(_fall((c1 + 1.0, 5.0), (c1 - 1.2, 5.0), L.PONDS["mid"]["water"] - 0.1, L.T0_NEAR - 0.3, 1.6, "Fall_weir"))
    c2 = float(L.cliff2(-2.5))
    objs.append(_fall((c2 + 1.0, -2.5), (c2 - 1.2, -2.5), L.T2 - 1.05, L.T1 - 0.25, 2.0, "Fall_notch"))
    objs.append(_fall((-27.0, 7.0), (-29.0, 7.1), L.PONDS["low"]["water"], L.PONDS["low"]["water"] - 0.4, 2.4, "Fall_wheel"))
    mat = bpy.data.materials.new("M_mw_water")
    for o in objs:
        if sum(1 for p in o.data.polygons if p.normal.z < 0) > len(o.data.polygons) / 2 and not o.name.startswith("Fall"):
            for p in o.data.polygons:
                p.flip()
        o.data.materials.append(mat)
        ik.paint_vertex_colors(o, lambda co, lc, n, tag: (0.0, 0.0, 0.0))
    print("MODEL mw_water tris=%d parts=%d" % (sum(ik.tri_count(o) for o in objs), len(objs)))
    ik.export_glb(out_glb, animated=False)




# ----------------------------------------------------------------------------- shared shapes
def blade(base, direction, length, width, thick=0.025, bend=(0.0, 0.0, 0.0), up=(0.0, 0.0, 1.0)):
    """One tapered brush-stroke blade (leaf, feather, fan rib): diamond section, pointed both ends."""
    base = Vector(base)
    d = Vector(direction).normalized()
    side = d.cross(Vector(up))
    if side.length < 1e-4:
        side = d.cross(Vector((1.0, 0.0, 0.0)))
    side.normalize()
    nrm = side.cross(d).normalized()
    sections = []
    for f, w in ((0.0, 0.0), (0.3, 1.0), (0.66, 0.72), (1.0, 0.0)):
        c = base + d * length * f + Vector(bend) * (f * f)
        if w == 0.0:
            sections.append([tuple(c)])
        else:
            sections.append([tuple(c + side * width * w), tuple(c + nrm * thick * w), tuple(c - side * width * w), tuple(c - nrm * thick * w)])
    return ik.loft(sections)


def fan(base, direction, rnd, blades=5, length=1.6, width=0.22, spread=1.2, up=(0.0, 0.0, 1.0), droop=0.25):
    """A fan of brush-stroke blades from one point: the canopy card fans of the style guide."""
    d = Vector(direction).normalized()
    side = d.cross(Vector(up))
    if side.length < 1e-4:
        side = Vector((1.0, 0.0, 0.0))
    side.normalize()
    out = []
    for k in range(blades):
        a = (k - (blades - 1) / 2) / max(blades - 1, 1) * spread + rnd.uniform(-0.08, 0.08)
        bd = (d * math.cos(a) + side * math.sin(a)).normalized()
        ln = length * rnd.uniform(0.75, 1.1) * (1.0 - 0.25 * abs(a) / max(spread, 0.01))
        out.append(blade(base, bd, ln, width * rnd.uniform(0.8, 1.15), 0.02, (0.0, 0.0, -droop * ln), up))
    return out


def colors_from(taper, tag_w):
    def fn(co, local, n, tag):
        if tag in tag_w:
            r, g, b = tag_w[tag]
            return (r, g, b)
        r = taper(co)
        return (r * (1.0 if n.z < 0 else 0.85), 0.0, 0.25 + 0.6 * (1 - r))
    return fn


def finish_static(name, parts, size, colors, crease=40.0, angle=45.0, animated=False):
    meshes = P.finish(name, parts, size, colors, angle=angle)
    ik.dump_paint_map(meshes, OUT_MAP, size, crease_deg=crease)
    ik.report(name, meshes)
    return meshes


# ----------------------------------------------------------------------------- tall trunks
def tall_trunk(seed, height, lean, base_r, fork=False, canopy=True, snag=False):
    rnd = random.Random(seed)
    vf, strokes = [], []
    segs = 9
    trunk = P.gnarled((0, 0, -0.4), (lean[0], lean[1], 1.0), height, segs, 0.05, rnd)
    rad = [base_r * (1.0 - 0.82 * (i / segs) ** 0.9) for i in range(segs + 1)]
    if snag:
        rad[-1] = base_r * 0.35
    else:
        rad[-1] = 0.0
    vf.append(ik.tube(trunk, rad, 7))
    strokes.append(ik.chain(trunk, 1.0, 0.1 if not snag else 0.5))
    tips = []
    for k in range(4):
        a = rnd.uniform(0, 2 * math.pi)
        root = P.gnarled((math.cos(a) * base_r * 0.6, math.sin(a) * base_r * 0.6, 0.7), (math.cos(a), math.sin(a), -1.1), base_r * 3.2, 3, 0.15, rnd)
        vf.append(ik.tube(root, [base_r * 0.45, base_r * 0.3, base_r * 0.15, 0.0], 5))
        strokes.append(ik.chain(root, 0.9, 0.1))
    if fork and not snag:
        j = int(segs * 0.45)
        second = P.gnarled(trunk[j], (lean[0] + 0.35, lean[1] - 0.2, 1.0), height * 0.55, 6, 0.06, rnd)
        vf.append(ik.tube(second, [rad[j] * 0.75 * (1 - i / 6) for i in range(6)] + [0.0], 6))
        strokes.append(ik.chain(second, 0.8, 0.08))
        tips.append(second[-1])
    n_branch = 2 if snag else 5
    for k in range(n_branch):
        j = int(segs * (0.5 + 0.45 * (k / max(n_branch - 1, 1)))) if not snag else int(segs * 0.5) + k
        j = min(j, segs - 1)
        a = rnd.uniform(0, 2 * math.pi)
        ln = height * rnd.uniform(0.16, 0.26) * (0.6 if snag else 1.0)
        br = P.gnarled(trunk[j], (math.cos(a), math.sin(a), rnd.uniform(0.2, 0.7)), ln, 4, 0.22, rnd)
        vf.append(ik.tube(br, [rad[j] * 0.42, rad[j] * 0.28, rad[j] * 0.16, rad[j] * 0.07, 0.0], 4))
        strokes.append(ik.chain(br, 0.6, 0.04))
        tips.append(br[-1])
    if not snag:
        tips.append(trunk[-1])
    body = ik.make_object("Trunk", ik.merged(*vf))
    parts = [body]
    if canopy and not snag:
        fans = []
        for k, tip in enumerate(tips):
            for j in range(2):
                out = (Vector(tip) - Vector(trunk[int(segs * 0.6)])).normalized() if (Vector(tip) - Vector(trunk[int(segs * 0.6)])).length > 0.1 else Vector((1, 0, 0))
                a = rnd.uniform(-0.9, 0.9)
                dirv = Vector((out.x * math.cos(a) - out.y * math.sin(a), out.x * math.sin(a) + out.y * math.cos(a), rnd.uniform(-0.1, 0.35)))
                fans += fan(Vector(tip) + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(-0.6, 0.3))), dirv, rnd,
                            blades=5, length=rnd.uniform(2.0, 3.0), width=0.32, spread=1.3, droop=0.3)
        canopy_obj = ik.make_object("Canopy", ik.merged(*fans), parent=body)
        ik.set_tags(canopy_obj, "canopy")
        ik.tag_faces(canopy_obj, lambda c, n, o: "canopy" if n.z > -0.2 else "canopy_under")
        parts.append(canopy_obj)
    ik.tag_faces(body, lambda c, n, o: "bark")
    for o in parts:
        ik.assign_material(o, "M_mw_" + MODEL)
    taper = ik.chain_taper(strokes)
    meshes = finish_static(MODEL, parts, 512, colors_from(taper, {"canopy": (0.45, 0.0, 0.55), "canopy_under": (0.6, 0.0, 0.5)}), crease=70.0)
    collider = ik.make_object("TrunkCollider-convcolonly", ik.tube([(0, 0, -0.4), (lean[0] * 3.0, lean[1] * 3.0, 3.0)], [base_r * 0.9, base_r * 0.75], 6))
    ik.export_glb(OUT_GLB)


def build_trunk_a():
    tall_trunk(101, 20.0, (0.03, 0.02), 0.42)


def build_trunk_b():
    tall_trunk(202, 17.0, (0.16, -0.06), 0.36)


def build_trunk_c():
    tall_trunk(303, 22.0, (-0.05, 0.04), 0.5, fork=True)


def build_trunk_snag():
    tall_trunk(404, 7.5, (0.08, 0.05), 0.45, canopy=False, snag=True)


def build_stair_tree():
    rnd = random.Random(55)
    vf, strokes = [], []
    segs = 10
    trunk = P.gnarled((0, 0, -0.5), (0.0, 0.05, 1.0), 26.0, segs, 0.04, rnd)
    rad = [L.STAIR_RADIUS * (1.08 - 0.75 * (i / segs)) for i in range(segs + 1)]
    rad[-1] = 0.0
    vf.append(ik.tube(trunk, rad, 10))
    strokes.append(ik.chain(trunk, 1.0, 0.15))
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.2, 0.2)
        if math.sin(a) > 0.6:     # the side against the bank (+Y) gets no root
            continue
        root = P.gnarled((math.cos(a) * 1.2, math.sin(a) * 1.2, 1.6), (math.cos(a), math.sin(a), -0.9), 4.2, 4, 0.12, rnd)
        vf.append(ik.tube(root, [0.75, 0.6, 0.42, 0.22, 0.0], 6))
        strokes.append(ik.chain(root, 1.0, 0.12))
    tips = [trunk[-1]]
    for k in range(6):
        j = 5 + k % 5
        a = rnd.uniform(0, 2 * math.pi)
        br = P.gnarled(trunk[j], (math.cos(a), math.sin(a), rnd.uniform(0.25, 0.6)), rnd.uniform(5.0, 7.5), 5, 0.18, rnd)
        vf.append(ik.tube(br, [rad[j] * 0.36, rad[j] * 0.27, rad[j] * 0.18, rad[j] * 0.1, rad[j] * 0.05, 0.0], 5))
        strokes.append(ik.chain(br, 0.7, 0.04))
        tips.append(br[-1])
    body = ik.make_object("Trunk", ik.merged(*vf))
    fans = []
    for tip in tips:
        for j in range(3):
            a = rnd.uniform(0, 2 * math.pi)
            fans += fan(Vector(tip) + Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.4))),
                        (math.cos(a), math.sin(a), rnd.uniform(-0.1, 0.3)), rnd, blades=5, length=rnd.uniform(2.4, 3.4), width=0.36, spread=1.3, droop=0.3)
    canopy = ik.make_object("Canopy", ik.merged(*fans), parent=body)
    ik.tag_faces(body, lambda c, n, o: "bark")
    ik.tag_faces(canopy, lambda c, n, o: "canopy" if n.z > -0.2 else "canopy_under")
    for o in (body, canopy):
        ik.assign_material(o, "M_mw_stair_tree")
    taper = ik.chain_taper(strokes)
    finish_static("stair_tree", [body, canopy], 1024, colors_from(taper, {"canopy": (0.45, 0.0, 0.55), "canopy_under": (0.6, 0.0, 0.5)}), crease=70.0)
    ik.make_object("TrunkCollider-convcolonly", ik.tube([(0, 0, -0.5), (0, 0.3, 8.0)], [L.STAIR_RADIUS, L.STAIR_RADIUS * 0.9], 10))
    ik.export_glb(OUT_GLB)


# ----------------------------------------------------------------------------- climbing pieces
def build_fungus_shelf():
    """Bracket fungus, top at Z = 0, attached edge toward +Y (the trunk), free rim toward -Y."""
    rnd = random.Random(61)
    secs = []
    n = 9
    for zi, (z, sc) in enumerate(((0.0, 1.0), (-0.12, 1.05), (-0.3, 0.8), (-0.42, 0.35))):
        ring = []
        for k in range(n):
            a = math.pi * k / (n - 1)
            r = 0.95 * sc * (1.0 + 0.06 * math.sin(a * 5 + zi))
            ring.append((math.cos(a) * r * 0.95, 0.35 - math.sin(a) * r * 0.85, z))
        ring.append((-0.6 * sc, 0.6, z))
        ring.append((0.6 * sc, 0.6, z))
        secs.append(ring)
    v, f = ik.loft(secs)
    lip = []
    for k in range(5):
        a = math.pi * (0.15 + 0.7 * k / 4)
        lip.append(ik.transformed(ik.ico(0.16, 1, (1.6, 1.0, 0.45), 0.15, 70 + k), location=(math.cos(a) * 0.62, 0.35 - math.sin(a) * 0.55, 0.03)))
    shelf = ik.make_object("Shelf-convcol", (v, f))
    bumps = ik.make_object("Rim", ik.merged(*lip), parent=shelf)
    ik.tag_faces(shelf, lambda c, n, o: "fungus" if n.z > 0.3 else "fungus_under")
    ik.set_tags(bumps, "fungus")
    for o in (shelf, bumps):
        ik.assign_material(o, "M_mw_fungus_shelf")
    finish_static("fungus_shelf", [shelf, bumps], 512, lambda co, lc, n, tag: (1.0 if n.z < 0 else 0.55, 0.0, 0.35), crease=35.0)
    ik.export_glb(OUT_GLB)


def rock_slab(name, w, d, h, seed):
    rnd = random.Random(seed)
    secs = []
    for z, sc in ((0.0, 1.0), (-0.15, 1.03), (-h * 0.6, 0.85), (-h, 0.5)):
        ring = []
        for k in range(10):
            a = 2 * math.pi * k / 10
            ring.append((math.cos(a) * w * 0.5 * sc * rnd.uniform(0.92, 1.06), -0.25 + math.sin(a) * d * 0.5 * sc * rnd.uniform(0.92, 1.06), z + (rnd.uniform(-0.03, 0.03) if z == 0 else 0)))
        secs.append(ring)
    return ik.loft(secs)


def build_ledge():
    """A rock shelf on the bank's face: top at Z = 0, front (+Y) facing out from the cliff."""
    slab = ik.make_object("Ledge-convcol", rock_slab("Ledge", 2.6, 2.4, 1.3, 81))
    roots = []
    rnd = random.Random(82)
    for k in range(3):
        x = rnd.uniform(-0.9, 0.9)
        r = P.gnarled((x, -0.9, 0.05), (rnd.uniform(-0.3, 0.3), 0.9, -0.5), 1.7, 3, 0.2, rnd)
        roots.append(ik.tube(r, [0.12, 0.09, 0.05, 0.0], 4))
    root_obj = ik.make_object("Roots", ik.merged(*roots), parent=slab)
    ik.tag_faces(slab, lambda c, n, o: "moss" if n.z > 0.6 else "rock")
    ik.set_tags(root_obj, "bark")
    for o in (slab, root_obj):
        ik.assign_material(o, "M_mw_ledge")
    finish_static("ledge", [slab, root_obj], 512, lambda co, lc, n, tag: (0.9 if tag == "bark" else (1.0 if n.z < 0.5 else 0.6), 0.0, 0.4), crease=30.0)
    ik.export_glb(OUT_GLB)


def build_moss_shelf():
    """A cushion of moss that unfurls from the bank toward lantern light (Kindle). Top at Z = 0.
    tucked: shrunk into the bank; unfurl: grows out in 10 frames."""
    rnd = random.Random(91)
    v, f = rock_slab("Moss", 2.2, 1.9, 0.6, 92)
    moss = ik.make_object("Moss-convcol", (v, f), location=(0, 0, 0))
    fronds = []
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6)
        base = (math.cos(a) * 1.0, -0.25 - math.sin(a) * 0.85, -0.05)
        fronds.append(blade(base, (math.cos(a) * 0.4, -math.sin(a), -0.7), 0.7, 0.14, 0.03))
    fr = ik.make_object("Fronds", ik.merged(*fronds), parent=moss)
    ik.tag_faces(moss, lambda c, n, o: "moss" if n.z > 0.2 else "moss_dark")
    ik.set_tags(fr, "moss_dark")
    for o in (moss, fr):
        ik.assign_material(o, "M_mw_moss_shelf")
    meshes = finish_static("moss_shelf", [moss, fr], 512, lambda co, lc, n, tag: (0.8 if n.z < 0.3 else 0.45, 0.0, 0.5), crease=35.0)
    ik.store_rest([moss])
    hidden = {"loc": (0.0, -1.3, -0.2), "scale": 0.01}
    ik.bake_animation("tucked", [moss], {0: {"Moss-convcol": hidden}}, 12, True)
    frames = {0: {"Moss-convcol": hidden}, 2: {"Moss-convcol": {"loc": (0, -0.9, -0.1), "scale": 0.3}},
              4: {"Moss-convcol": {"loc": (0, -0.4, 0.0), "scale": 0.7}}, 6: {"Moss-convcol": {"scale": 1.1}}, 8: {"Moss-convcol": {"scale": 1.0}}}
    ik.bake_animation("unfurl", [moss], frames, 12, False)
    ik.apply_pose(moss, hidden)
    ik.export_glb(OUT_GLB, animated=True)


# ----------------------------------------------------------------------------- lantern-fruit
def build_lantern_fruit():
    """A papery lantern-fruit hanging on a vine; origin at the fruit's centre. The husk's five
    petals part and the gold core swells when Kindle lights it.
    Animations: unlit (closed, a dim seed, loop), lit (opens, then a stepped flicker, loop),
    catch (the one-shot opening, 8 frames)."""
    rnd = random.Random(121)
    vine_pts = [(0, 0, 0.32), (0.05, 0.02, 0.9), (-0.08, 0.05, 1.6), (0.1, -0.04, 2.5), (0.25, 0.1, 3.6)]
    vine = ik.make_object("Vine", ik.tube(vine_pts, [0.025, 0.03, 0.035, 0.028, 0.0], 4))
    leaves = [blade((0.05, 0.02, 0.9), (0.6, 0.2, -0.3), 0.45, 0.1), blade((-0.08, 0.05, 1.6), (-0.6, 0.3, -0.4), 0.5, 0.11),
              blade((0.1, -0.04, 2.5), (0.3, -0.7, -0.2), 0.4, 0.09)]
    leaf = ik.make_object("Leaves", ik.merged(*leaves), parent=vine)
    petals = []
    for k in range(5):
        a = 2 * math.pi * k / 5
        secs = []
        for z, r, w in ((0.3, 0.04, 0.03), (0.15, 0.22, 0.16), (-0.08, 0.27, 0.19), (-0.26, 0.14, 0.1), (-0.36, 0.02, 0.02)):
            c = Vector((math.cos(a) * r, math.sin(a) * r, z))
            t = Vector((-math.sin(a), math.cos(a), 0.0))
            o = Vector((math.cos(a), math.sin(a), 0.0))
            secs.append([tuple(c + t * w), tuple(c + o * 0.02), tuple(c - t * w), tuple(c - o * 0.02)])
        p = ik.make_object("Petal%d" % k, ik.loft(secs), parent=vine)
        p.rotation_mode = "XYZ"
        petals.append(p)
    core = ik.make_object("Core", ik.ico(0.17, 2, (1.0, 1.0, 1.2), 0.08, 122), parent=vine)
    ik.set_tags(vine, "stem")
    ik.set_tags(leaf, "moss")
    for p in petals:
        ik.set_tags(p, "lantern_husk")
    ik.set_tags(core, "glow")
    for o in [vine, leaf] + petals:
        ik.assign_material(o, "M_mw_lantern_fruit")
    ik.assign_material(core, "M_mw_lantern_fruit_glow_sacred")
    parts = [vine, leaf] + petals + [core]
    vine_w = ik.chain_taper([ik.chain(vine_pts, 0.5, 0.0)])

    def colors(co, lc, n, tag):
        if tag == "glow":
            return (0.0, 0.0, 0.0)
        if tag == "lantern_husk":
            return (0.55, 0.15, 0.35)
        if tag == "moss":
            return (0.3, 0.3, 0.5)
        return (vine_w(co), 0.2, 0.5)
    finish_static("lantern_fruit", parts, 512, colors, crease=40.0)
    ik.store_rest(parts)
    shut = {p.name: {} for p in petals}
    shut["Core"] = {"scale": 0.55}
    ik.bake_animation("unlit", petals + [core], {0: dict(shut), 6: {"Core": {"scale": 0.5}}}, 12, True)

    def opened(amount):
        pose = {}
        for k, p in enumerate(petals):
            a = 2 * math.pi * k / 5
            pose[p.name] = {"rot": (-math.sin(a) * 28 * amount, math.cos(a) * 28 * amount, 0.0), "loc": (math.cos(a) * 0.05 * amount, math.sin(a) * 0.05 * amount, 0.0)}
        return pose
    lit = {0: dict(opened(1.0), Core={"scale": 1.0}), 3: {"Core": {"scale": 1.08}}, 5: {"Core": {"scale": 0.96}},
           8: {"Core": {"scale": 1.05}}, 10: {"Core": {"scale": 1.0}}}
    ik.bake_animation("lit", petals + [core], lit, 12, True)
    catch = {0: dict(shut), 2: dict(opened(0.4), Core={"scale": 0.8}), 4: dict(opened(1.2), Core={"scale": 1.25}), 6: dict(opened(1.0), Core={"scale": 1.0})}
    ik.bake_animation("catch", petals + [core], catch, 8, False)
    for p in petals:
        ik.apply_pose(p, {})
    ik.apply_pose(core, {"scale": 0.55})
    ik.export_glb(OUT_GLB, animated=True)


# ----------------------------------------------------------------------------- the paddle-wheel
def build_wheel():
    """Fenn's paddle-wheel at Wheel Pond's outfall. Origin at the water line under the axle; the
    axle runs along X (across the stream), the stream runs along Y. Animations: clogged (still,
    soot packed in the paddles, loop), unclog (the soot blows out, 10 frames), spin (one paddle
    step every 6 frames; with 8 paddles it reads as a steady turn, loop)."""
    rnd = random.Random(131)
    R, W, AX = 1.8, 1.1, 1.25
    wheel_parts = []
    for side in (-1, 1):
        wheel_parts.append(ik.transformed(P.torus(R, 0.07, 16, 4), location=(side * W * 0.5, 0, 0), rotation_deg=(0, 90, 0)))
        wheel_parts.append(ik.transformed(P.torus(R * 0.55, 0.05, 12, 4), location=(side * W * 0.5, 0, 0), rotation_deg=(0, 90, 0)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        dy, dz = math.cos(a), math.sin(a)
        for side in (-1, 1):
            wheel_parts.append(ik.tube([(side * W * 0.5, 0, 0), (side * W * 0.5, dy * R, dz * R)], [0.05, 0.04], 4, cap=True))
        c = (0.0, dy * R * 0.82, dz * R * 0.82)
        board = P.box(W + 0.12, 0.06, R * 0.42, cz=-R * 0.21)
        wheel_parts.append(ik.transformed(board, location=c, rotation_deg=(math.degrees(a) - 90, 0, 0)))
    wheel_parts.append(ik.tube([(-W * 0.5 - 0.5, 0, 0), (W * 0.5 + 0.5, 0, 0)], [0.1, 0.1], 6))
    wheel = ik.make_object("Wheel", ik.merged(*wheel_parts), location=(0, 0, AX))
    frame = []
    for side in (-1, 1):
        x = side * (W * 0.5 + 0.55)
        frame.append(P.box(0.22, 0.22, AX + 0.9, cx=x, cy=-0.5, cz=-1.2))
        frame.append(P.box(0.22, 0.22, AX + 0.9, cx=x, cy=0.5, cz=-1.2))
        frame.append(P.box(0.24, 1.3, 0.2, cx=x, cz=AX - 0.12))
        frame.append(P.box(0.18, 0.18, 0.9, cx=x, cy=0, cz=AX + 0.05, taper=0.7))
    frame.append(P.box(W + 1.5, 0.25, 0.18, cy=-0.62, cz=AX + 0.82))
    frame_obj = ik.make_object("Frame-convcol", ik.merged(*frame))
    soot = []
    for k in range(12):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(R * 0.55, R * 0.95)
        soot.append(ik.transformed(ik.ico(rnd.uniform(0.3, 0.5), 1, (1.6, 1.0, 1.0), 0.3, 140 + k), location=(rnd.uniform(-0.3, 0.3), math.cos(a) * r, math.sin(a) * r)))
    soot_obj = ik.make_object("Soot", ik.merged(*soot), parent=wheel)
    ik.tag_faces(wheel, lambda c, n, o: "wood")
    ik.set_tags(frame_obj, "wood_dark")
    ik.set_tags(soot_obj, "soot")
    for o in (wheel, frame_obj, soot_obj):
        ik.assign_material(o, "M_mw_wheel")
    parts = [wheel, frame_obj, soot_obj]
    finish_static("wheel", parts, 1024, lambda co, lc, n, tag: (0.45 if tag == "soot" else (1.0 if n.z < 0 else 0.75), 0.0, 0.6 if tag == "soot" else 0.35), crease=40.0)
    ik.store_rest([wheel, soot_obj])
    ik.bake_animation("clogged", [wheel, soot_obj], {0: {}}, 12, True)
    gone = P.tucked(soot_obj, 0.0)
    gone["loc"] = (0.0, 0.0, -AX - 1.6)
    ik.bake_animation("unclog", [wheel, soot_obj], {0: {}, 2: {"Soot": {"scale": 1.15}, "Wheel": {"rot": (-6, 0, 0)}},
                                                    4: {"Soot": {"scale": 0.6, "loc": (0.0, -0.6, 0.3)}, "Wheel": {"rot": (-14, 0, 0)}},
                                                    6: {"Soot": {"scale": 0.25, "loc": (0.0, -1.2, 0.6)}, "Wheel": {"rot": (-26, 0, 0)}},
                                                    8: {"Soot": gone, "Wheel": {"rot": (-38, 0, 0)}}}, 10, False)
    spin = {f: {"Wheel": {"rot": (-7.5 * f, 0, 0)}, "Soot": gone} for f in range(6)}
    ik.bake_animation("spin", [wheel, soot_obj], spin, 6, True)
    ik.apply_pose(wheel, {})
    ik.apply_pose(soot_obj, {})
    ik.export_glb(OUT_GLB, animated=True)


# ----------------------------------------------------------------------------- lilies
def lily_pad_shape(r, seed, notch=0.35):
    rnd = random.Random(seed)
    n = 16
    top, bottom = [], []
    for k in range(n):
        a = notch * 0.5 + (2 * math.pi - notch) * k / (n - 1)
        rr = r * (1.0 + rnd.uniform(-0.04, 0.04))
        top.append((math.cos(a) * rr, math.sin(a) * rr, 0.0))
        bottom.append((math.cos(a) * rr * 0.97, math.sin(a) * rr * 0.97, -0.08))
    top.append((0.0, 0.0, 0.01))
    bottom.append((0.0, 0.0, -0.08))
    return ik.loft([bottom, top])


def build_lily():
    """A lily bud that Bloom opens into a leaf platform (pad 2.4 m across, top at Z = 0.05 above
    the water). Animations: bud (closed bud, pad tucked under, loop), open (the pad spreads and
    the bud opens into a flower at the pad's edge, 16 frames). The pad is Pad-convcol: its
    collision exists in the open pose only (tucked it is a hundredth of its size)."""
    pad = ik.make_object("Pad-convcol", lily_pad_shape(1.2, 151), location=(0, 0, 0.05))
    bud_pts = [(0.55, 0.0, -0.3), (0.58, 0.0, 0.2)]
    stem = ik.make_object("Stem", ik.tube(bud_pts, [0.04, 0.03], 4))
    bud = ik.make_object("Bud", ik.ico(0.2, 1, (0.8, 0.8, 1.4), 0.08, 152), location=(0.58, 0.0, 0.42))
    petals = []
    for k in range(6):
        a = 2 * math.pi * k / 6
        petals.append(blade((0.58, 0.0, 0.25), (math.cos(a) * 0.8, math.sin(a) * 0.8, 0.6), 0.42, 0.13, 0.02))
    flower = ik.make_object("Flower", ik.merged(*petals))
    ik.tag_faces(pad, lambda c, n, o: "lily_pad")
    ik.set_tags(stem, "stem")
    ik.set_tags(bud, "lily_bud")
    ik.set_tags(flower, "lily_petal")
    parts = [pad, stem, bud, flower]
    for o in parts:
        ik.assign_material(o, "M_mw_lily")
    finish_static("lily", parts, 512, lambda co, lc, n, tag: (0.5 if tag in ("lily_pad", "lily_petal") else 0.4, 0.0, 0.4), crease=50.0)
    ik.store_rest(parts)
    under = {"scale": 0.01, "loc": (0.0, 0.0, -1.2)}
    ik.bake_animation("bud", parts, {0: {"Pad-convcol": under, "Flower": under}, 6: {"Bud": {"scale": 1.04}}}, 12, True)
    frames = {0: {"Pad-convcol": under, "Flower": under}, 3: {"Bud": {"scale": 1.25}}, 5: {"Bud": under, "Flower": {"scale": 0.5}, "Pad-convcol": {"scale": 0.3}},
              8: {"Flower": {"scale": 1.15}, "Pad-convcol": {"scale": 0.8}}, 11: {"Pad-convcol": {"scale": 1.08}, "Flower": {"scale": 1.0}}, 14: {"Pad-convcol": {"scale": 1.0}}}
    ik.bake_animation("open", parts, frames, 16, False)
    ik.apply_pose(pad, under)
    ik.apply_pose(flower, under)
    ik.export_glb(OUT_GLB, animated=True)


def build_lily_pad():
    pads = [lily_pad_shape(0.9, 161), ik.transformed(lily_pad_shape(0.55, 162), location=(1.3, 0.6, 0.0), rotation_deg=(0, 0, 70)),
            ik.transformed(lily_pad_shape(0.4, 163), location=(-0.9, 1.1, 0.0), rotation_deg=(0, 0, 200))]
    obj = ik.make_object("Pads", ik.merged(*pads), location=(0, 0, 0.03))
    ik.set_tags(obj, "lily_pad")
    ik.assign_material(obj, "M_mw_lily_pad")
    finish_static("lily_pad", [obj], 256, lambda co, lc, n, tag: (0.45, 0.0, 0.4), crease=50.0)
    ik.export_glb(OUT_GLB)


# ----------------------------------------------------------------------------- the log
def build_log():
    """The old footbridge log: root plate at the origin (its pivot on the island), 7.6 m long
    toward +Y. Jammed across Lily Reach's weir until a Tie hauls it round into a bridge."""
    rnd = random.Random(171)
    pts = [(0, 0.0, 0.25), (0.05, 2.0, 0.28), (-0.06, 4.0, 0.26), (0.04, 6.0, 0.24), (0.0, 7.6, 0.2)]
    body = ik.tube(pts, [0.5, 0.46, 0.43, 0.4, 0.36], 8)
    stubs = []
    for k in range(4):
        y = rnd.uniform(1.0, 6.8)
        a = rnd.uniform(-1.0, 1.0) + (0 if k % 2 else math.pi)
        st = [(math.cos(a) * 0.35, y, 0.25 + math.sin(a) * 0.35), (math.cos(a) * 0.9, y + 0.3, 0.25 + math.sin(a) * 0.9)]
        stubs.append(ik.tube(st, [0.12, 0.0], 4))
    roots = []
    for k in range(7):
        a = 2 * math.pi * k / 7
        rp = P.gnarled((0.0, 0.1, 0.25), (math.cos(a), -0.8, math.sin(a)), 1.4, 3, 0.25, rnd)
        roots.append(ik.tube(rp, [0.22, 0.15, 0.07, 0.0], 4))
    log = ik.make_object("Log-convcol", body)
    extra = ik.make_object("Roots", ik.merged(*(stubs + roots)), parent=log)
    ik.tag_faces(log, lambda c, n, o: "moss" if n.z > 0.75 else "bark")
    ik.set_tags(extra, "bark")
    for o in (log, extra):
        ik.assign_material(o, "M_mw_log")
    taper = ik.chain_taper([ik.chain(pts, 1.0, 0.8)])
    finish_static("log", [log, extra], 512, lambda co, lc, n, tag: (0.9 if n.z < 0 else 0.7, 0.0, 0.35), crease=50.0)
    ik.export_glb(OUT_GLB)


# ----------------------------------------------------------------------------- the dam
def build_dam():
    """The old dam along Willow Pool's south-east edge: 17 m of stacked stone and timber along X,
    the crest walk in front (+Y), the pool behind. Origin at crest ground level (Z = 0); the wall
    stands 0.6 m above it and reaches 2.2 m down into the pool. The sluice gate is 6.5 m to -X
    (the spillway notch): Gate boards lift on "open"."""
    rnd = random.Random(181)
    half = 8.5
    gate_x, gate_w = -6.5, 2.4
    stones = []
    for row, (z0, h) in enumerate(((-2.2, 0.8), (-1.4, 0.75), (-0.65, 0.7))):
        x = -half
        while x < half - 0.1:
            w = rnd.uniform(0.9, 1.6)
            x1 = min(half, x + w)
            if not (x1 < gate_x - gate_w / 2 or x >= gate_x + gate_w / 2 - 1e-6):
                x = gate_x + gate_w / 2
                continue
            stones.append(P.box(x1 - x - 0.06, 1.2 - row * 0.12, h - 0.05, cx=(x + x1) / 2, cy=0.0, cz=z0, taper=0.94))
            x = x1
    wall = ik.make_object("Wall-convcol", ik.merged(*stones))
    beams = [P.box(gate_x + gate_w / 2 + half - 0.0 - 0.1, 0.35, 0.3, cx=(-half + gate_x - gate_w / 2) / 2, cy=0.25, cz=0.05),
             P.box(half - gate_x - gate_w / 2, 0.35, 0.3, cx=(half + gate_x + gate_w / 2) / 2, cy=0.25, cz=0.05)]
    for side in (-1, 1):
        x = gate_x + side * (gate_w / 2 + 0.15)
        beams.append(P.box(0.3, 0.3, 3.4, cx=x, cy=0.1, cz=-2.2))
    beams.append(P.box(gate_w + 0.7, 0.3, 0.28, cx=gate_x, cy=0.1, cz=1.2))
    for k in range(5):
        x = -half + 1.5 + k * 3.6
        if abs(x - gate_x) < 2:
            continue
        beams.append(P.box(0.22, 0.22, 1.0, cx=x, cy=0.55, cz=-0.4, taper=0.8))
    timber = ik.make_object("Timber-convcol", ik.merged(*beams))
    boards = [P.box(gate_w, 0.12, 0.42, cx=gate_x, cy=0.12, cz=-2.0 + k * 0.45) for k in range(5)]
    gate = ik.make_object("Gate", ik.merged(*boards))
    ik.tag_faces(wall, lambda c, n, o: "moss" if n.z > 0.7 else "stone")
    ik.set_tags(timber, "wood_dark")
    ik.set_tags(gate, "plank")
    for o in (wall, timber, gate):
        ik.assign_material(o, "M_mw_dam")
    parts = [wall, timber, gate]
    finish_static("dam", parts, 1024, lambda co, lc, n, tag: (1.0 if n.z < 0.3 else 0.7, 0.0, 0.35), crease=30.0)
    ik.store_rest([gate])
    ik.bake_animation("shut", [gate], {0: {}}, 12, True)
    ik.bake_animation("open", [gate], {0: {}, 3: {"Gate": {"loc": (0, 0, 0.5)}}, 6: {"Gate": {"loc": (0, 0, 1.2)}}, 9: {"Gate": {"loc": (0, 0, 1.9)}}}, 12, False)
    ik.apply_pose(gate, {})
    ik.export_glb(OUT_GLB, animated=True)


# ----------------------------------------------------------------------------- the willow
def build_willow():
    """The old willow whose roots hold the spring: Mosswater Wood's guardian tree, tied with a
    vermilion cord like the Camphor. Withered it is a black trunk hung with bare whips; Bloom
    hangs green leaf-streamers and pale catkins along every whip.
    Animations: withered (loop), bloom (the streamers drop in from the crown down, 36 frames)."""
    rnd = random.Random(191)
    vf, strokes = [], []
    trunk = P.gnarled((0, 0, -0.4), (0.12, -0.05, 1.0), 6.0, 6, 0.1, rnd)
    vf.append(ik.tube(trunk, [1.15, 0.95, 0.85, 0.78, 0.72, 0.66, 0.6], 9))
    strokes.append(ik.chain(trunk, 1.0, 0.7))
    for k in range(7):
        a = 2 * math.pi * k / 7 + rnd.uniform(-0.25, 0.25)
        root = P.gnarled((math.cos(a) * 0.8, math.sin(a) * 0.8, 1.0), (math.cos(a), math.sin(a), -0.8), rnd.uniform(2.4, 3.6), 4, 0.14, rnd)
        vf.append(ik.tube(root, [0.5, 0.38, 0.25, 0.12, 0.0], 5))
        strokes.append(ik.chain(root, 0.95, 0.1))
    whip_tips, whips = [], []
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3)
        limb = P.gnarled(trunk[-2 if k % 2 else -1], (math.cos(a), math.sin(a), 0.85), rnd.uniform(4.0, 5.5), 5, 0.16, rnd, up_bias=-0.05)
        vf.append(ik.tube(limb, [0.45, 0.36, 0.28, 0.2, 0.12, 0.0], 6))
        strokes.append(ik.chain(limb, 0.85, 0.06))
        for j in range(2, 6):
            p = Vector(limb[j])
            for w in range(2):
                out = Vector((math.cos(a), math.sin(a), 0.0))
                start = p + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0.0))
                drop = start.z - rnd.uniform(1.8, 2.8)
                pts = [tuple(start), tuple(start + out * 0.5 + Vector((0, 0, 0.25))), tuple(start + out * 0.9 + Vector((0, 0, -0.6)))]
                pts += [(pts[-1][0] + out.x * 0.15, pts[-1][1] + out.y * 0.15, (pts[-1][2] + drop) / 2), (pts[-1][0] + out.x * 0.2, pts[-1][1] + out.y * 0.2, max(drop, 1.6))]
                whips.append(pts)
    for pts in whips:
        vf.append(ik.tube(pts, [0.06, 0.05, 0.04, 0.025, 0.0], 3))
        strokes.append(ik.chain(pts, 0.5, 0.02))
    body = ik.make_object("Trunk", ik.merged(*vf))
    cord = ik.make_object("Cord", ik.merged(P.torus(0.9, 0.08, 16, 4, 2.0), P.torus(0.87, 0.06, 16, 4, 2.22)), parent=body)
    tails = []
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        c = Vector((math.cos(a) * 0.95, math.sin(a) * 0.95, 1.95))
        tails.append(blade(c, (math.cos(a) * 0.3, math.sin(a) * 0.3, -1.0), 0.8, 0.09, 0.015))
    cord_tails = ik.make_object("CordTails", ik.merged(*tails), parent=body)
    # leaf streamers: groups of hanging blades along the whips, one group per limb
    groups = []
    for g in range(5):
        streamers = []
        for pts in whips[g * 8:(g + 1) * 8]:
            for f in (0.35, 0.6, 0.85):
                i = min(int(f * (len(pts) - 1)), len(pts) - 2)
                a0, b0 = Vector(pts[i]), Vector(pts[i + 1])
                p = a0.lerp(b0, rnd.random())
                streamers.append(blade(p, (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), -1.0), rnd.uniform(0.7, 1.1), 0.12, 0.02))
            tip = Vector(pts[-1])
            streamers.append(ik.transformed(ik.ico(0.13, 1, (0.8, 0.8, 1.5), 0.1, 200 + g), location=tuple(tip + Vector((0, 0, 0.35)))))
        centre = Vector(whips[g * 8][0])
        obj = ik.make_object("Leaves%d" % (g + 1), ik.merged(*streamers), parent=body)
        groups.append(obj)
    ik.tag_faces(body, lambda c, n, o: "bark")
    ik.set_tags(cord, "cord")
    ik.set_tags(cord_tails, "paper")
    for gobj in groups:
        ik.tag_faces(gobj, lambda c, n, o: "willow_leaf" if n.z < 0.6 else "catkin")
    for o in [body, cord_tails] + groups:
        ik.assign_material(o, "M_mw_willow")
    ik.assign_material(cord, "M_mw_willow_cord_sacred")
    parts = [body, cord, cord_tails] + groups
    taper = ik.chain_taper(strokes)

    def colors(co, lc, n, tag):
        if tag == "cord":
            return (0.6, 0.0, 0.2)
        if tag == "paper":
            return (0.3, 0.5, 0.3)
        if tag in ("willow_leaf", "catkin"):
            return (0.35, 0.7, 0.5)
        r = taper(co)
        return (r * (1.0 if n.z < -0.2 else 0.85), 0.25 * ik.smoothstep(3.0, 9.0, co.z) if r < 0.3 else 0.0, 0.25 + 0.6 * (1 - r))
    finish_static("willow", parts, 1024, colors, crease=70.0)
    ik.store_rest(groups)
    hidden = {gobj.name: P.tucked(gobj, 4.0) for gobj in groups}
    ik.bake_animation("withered", groups, {0: dict(hidden)}, 12, True)
    frames = {0: dict(hidden)}
    for k, gobj in enumerate(groups):
        f0 = 3 + k * 4
        frames.setdefault(f0, {})[gobj.name] = {"scale": (1.0, 1.0, 0.3)}
        frames.setdefault(f0 + 2, {})[gobj.name] = {"scale": (1.0, 1.0, 0.75)}
        frames.setdefault(f0 + 4, {})[gobj.name] = {"scale": (1.0, 1.0, 1.1)}
        frames.setdefault(f0 + 6, {})[gobj.name] = {"scale": 1.0}
    ik.bake_animation("bloom", groups, frames, 36, False)
    for gobj in groups:
        ik.apply_pose(gobj, hidden[gobj.name])
    ik.make_object("TrunkCollider-convcolonly", ik.tube([(0, 0, -0.4), (0.6, -0.25, 5.5)], [1.05, 0.7], 8))
    ik.export_glb(OUT_GLB, animated=True)


# ----------------------------------------------------------------------------- Fenn's hut
def build_fenn_hut():
    """The charcoal-burner's hut: a cone of poles under bark slabs with its door toward +Y, a
    turf-capped charcoal clamp beside it (-X), a woodpile and two sacks."""
    rnd = random.Random(211)
    poles, slabs = [], []
    n = 11
    apex = Vector((0.0, -0.2, 3.7))
    for k in range(n):
        a = 2 * math.pi * k / n
        if abs(math.atan2(math.sin(a - math.pi / 2), math.cos(a - math.pi / 2))) < 0.42:
            continue
        foot = Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, -0.1))
        tip = apex + (apex - foot).normalized() * 0.6
        poles.append(ik.tube([tuple(foot), tuple(tip)], [0.07, 0.04], 4))
        a2 = a + math.pi / n
        f2 = Vector((math.cos(a2) * 1.75, math.sin(a2) * 1.75, -0.05))
        side = Vector((-math.sin(a2), math.cos(a2), 0.0))
        if abs(math.atan2(math.sin(a2 - math.pi / 2), math.cos(a2 - math.pi / 2))) < 0.5:
            continue
        top = apex.lerp(f2, 0.12)
        outward = Vector((math.cos(a2), math.sin(a2), 0.25)).normalized() * 0.05
        slab = [tuple(f2 - side * 0.55), tuple(f2 + side * 0.55), tuple(top + side * 0.08), tuple(top - side * 0.08)]
        slab_in = [tuple(Vector(p) - outward) for p in slab]
        slabs.append(ik.loft([slab_in, slab]))
    hut = ik.make_object("Hut-convcol", ik.merged(*slabs))
    pole_obj = ik.make_object("Poles", ik.merged(*poles), parent=hut)
    clamp = ik.make_object("Clamp-convcol", ik.ico(1.6, 2, (1.0, 1.0, 0.55), 0.1, 212), location=(-3.6, -0.6, -0.15))
    vent = ik.make_object("Vent", ik.tube([(-3.6, -0.6, 0.6), (-3.55, -0.58, 1.05)], [0.18, 0.12], 6), parent=None)
    logs = []
    for k in range(9):
        row, col = divmod(k, 3)
        logs.append(ik.tube([(2.2 + col * 0.0, -0.9 + col * 0.34, 0.18 + row * 0.3), (3.6, -0.9 + col * 0.34, 0.18 + row * 0.3)], [0.15, 0.14], 6))
    pile = ik.make_object("Woodpile-convcol", ik.merged(*logs))
    sacks = ik.make_object("Sacks", ik.merged(ik.transformed(ik.ico(0.38, 1, (0.9, 0.8, 1.2), 0.15, 213), location=(1.6, 1.2, 0.4)),
                                              ik.transformed(ik.ico(0.34, 1, (0.9, 0.8, 1.1), 0.15, 214), location=(2.2, 1.35, 0.35))))
    ik.tag_faces(hut, lambda c, n, o: "wood")
    ik.set_tags(pole_obj, "wood_dark")
    ik.tag_faces(clamp, lambda c, n, o: "moss" if n.z > 0.5 else "clay")
    ik.set_tags(vent, "char")
    ik.tag_faces(pile, lambda c, n, o: "wood" if abs(n.x) < 0.7 else "char")
    ik.set_tags(sacks, "cloth")
    parts = [hut, pole_obj, clamp, vent, pile, sacks]
    for o in parts:
        ik.assign_material(o, "M_mw_fenn_hut")
    finish_static("fenn_hut", parts, 1024, lambda co, lc, n, tag: (1.0 if n.z < 0.2 else 0.75, 0.0, 0.35), crease=30.0)
    ik.export_glb(OUT_GLB)


def build_brazier():
    """Fenn's brazier: an iron bowl on three legs with a heap of embers (the one light the wood
    kept). The embers are sacred: they keep their colour in the drained wood."""
    legs = []
    for k in range(3):
        a = 2 * math.pi * k / 3
        legs.append(ik.tube([(math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.62)], [0.035, 0.03], 4))
    secs = [[(math.cos(2 * math.pi * k / 10) * r, math.sin(2 * math.pi * k / 10) * r, z) for k in range(10)] for z, r in ((0.55, 0.12), (0.62, 0.36), (0.82, 0.46))]
    bowl = ik.make_object("Bowl-convcol", ik.merged(ik.loft(secs, cap_start=True, cap_end=True), *legs))
    embers = ik.make_object("Embers", ik.merged(*[ik.transformed(ik.ico(0.11, 1, (1.2, 1.0, 0.7), 0.25, 220 + k), location=(math.cos(k * 2.1) * 0.22, math.sin(k * 2.1) * 0.22, 0.82)) for k in range(6)]))
    ik.set_tags(bowl, "iron")
    ik.set_tags(embers, "ember")
    ik.assign_material(bowl, "M_mw_brazier")
    ik.assign_material(embers, "M_mw_brazier_embers_sacred")
    finish_static("brazier", [bowl, embers], 256, lambda co, lc, n, tag: (0.3 if tag == "ember" else 0.8, 0.0, 0.3), crease=40.0)
    ik.export_glb(OUT_GLB)


def build_raft_post():
    """The mooring post at the landing where Pell ties the raft, with a coil of rope."""
    post = ik.make_object("Post-convcol", ik.tube([(0, 0, -1.6), (0.02, 0.0, 0.6), (0.0, 0.03, 1.3)], [0.16, 0.15, 0.12], 6))
    rope = ik.make_object("Rope", ik.merged(P.torus(0.2, 0.04, 12, 4, 0.9), P.torus(0.21, 0.04, 12, 4, 0.98), ik.tube([(0.2, 0.0, 0.92), (0.6, 0.3, 0.35), (1.1, 0.5, -0.3)], [0.035, 0.03, 0.0], 4)))
    ik.set_tags(post, "wood_dark")
    ik.set_tags(rope, "rope")
    for o in (post, rope):
        ik.assign_material(o, "M_mw_raft_post")
    finish_static("raft_post", [post, rope], 256, lambda co, lc, n, tag: (0.9 if tag != "rope" else 0.4, 0.0, 0.35), crease=40.0)
    ik.export_glb(OUT_GLB)


# ----------------------------------------------------------------------------- the Sootflit
def build_sootflit():
    """The Sootflit: a drop of ink that grew soot wings. About 0.9 m across the wings, faces -Z in
    Godot (+Y here); origin at the body's centre (on the ground, stand it 0.18 m up).
    It circles out of reach until a Gust knocks it down; grounded, it flaps and can be struck.
    Animations (12 fps, stepped): idle (slow hover, 8 frames), fly (fast beats, 4 frames), dive
    (wings swept back, a stoop at the target, smear on frames 2 and 3), hurt, fall (tumbling out
    of the air after a Gust, 8 frames), downed (on the ground, wings splayed, twitching, loop)."""
    rnd = random.Random(231)
    secs = []
    for y, r, z in ((0.26, 0.0, 0.0), (0.18, 0.11, 0.0), (0.02, 0.16, 0.0), (-0.14, 0.13, 0.02), (-0.28, 0.06, 0.05), (-0.4, 0.0, 0.1)):
        if r == 0.0:
            secs.append([(0.0, y, z)])
        else:
            secs.append([(math.cos(2 * math.pi * k / 7) * r, y, z + math.sin(2 * math.pi * k / 7) * r * 0.85) for k in range(7)])
    body = ik.make_object("Body", ik.loft(secs))
    eyes = ik.make_object("Eyes", ik.merged(ik.transformed(ik.ico(0.045, 1, (1.0, 0.5, 1.2), 0.05, 232), location=(-0.065, 0.2, 0.05)),
                                            ik.transformed(ik.ico(0.045, 1, (1.0, 0.5, 1.2), 0.05, 233), location=(0.065, 0.2, 0.05))), parent=body)
    tail = ik.make_object("Tail", ik.merged(blade((0.0, -0.36, 0.08), (0.15, -1.0, -0.1), 0.32, 0.05, 0.015), blade((0.0, -0.36, 0.08), (-0.2, -1.0, 0.05), 0.26, 0.04, 0.015)), parent=body)
    wings = []
    for side in (-1, 1):
        feathers = []
        for k in range(4):
            a = math.radians(-12 + k * 20)
            d = (side * math.cos(a), -math.sin(a) * 0.9 - 0.15, 0.05)
            feathers.append(blade((side * 0.08, 0.02, 0.03), d, 0.48 - k * 0.06, 0.07, 0.012, (0.0, 0.0, -0.05)))
        w = ik.make_object("Wing" + ("L" if side < 0 else "R"), ik.merged(*feathers), parent=body, location=(side * 0.09, 0.02, 0.04))
        wings.append(w)
    smear = ik.make_object("Smear", ik.merged(blade((0.0, -0.1, 0.0), (0.0, -1.0, 0.25), 0.9, 0.16, 0.02), blade((0.12, -0.1, 0.0), (0.2, -1.0, 0.3), 0.6, 0.08, 0.015)), parent=body)
    ik.set_tags(body, "ink")
    ik.set_tags(eyes, "eye")
    ik.set_tags(tail, "wing")
    for w in wings:
        ik.set_tags(w, "wing")
    ik.set_tags(smear, "soot")
    parts = [body, eyes, tail] + wings + [smear]
    for o in parts:
        ik.assign_material(o, "M_mw_sootflit")
    strokes = [ik.chain([(0, 0.26, 0), (0, -0.4, 0.1)], 1.0, 0.4)]
    for w in wings:
        sx = 1 if w.name.endswith("R") else -1
        strokes.append(ik.chain([(sx * 0.1, 0.02, 0.05), (sx * 0.55, -0.05, 0.05)], 0.8, 0.05))
    taper = ik.chain_taper(strokes)

    def colors(co, lc, n, tag):
        if tag == "eye":
            return (0.2, 0.0, 0.2)
        if tag == "soot":
            return (0.2, 0.0, 0.9)
        return (taper(co), 0.0, 0.5 + 0.4 * (1 - taper(co)))
    finish_static("sootflit", parts, 512, colors, crease=60.0)
    ik.store_rest(parts)
    off = {"Smear": {"scale": 0.01, "loc": (0.0, 0.0, -1.5)}}

    def flap(up, sweep=0.0):
        return {"WingL": {"rot": (0, -up, sweep)}, "WingR": {"rot": (0, up, -sweep)}}

    def pose(*ds):
        out = {}
        for d in ds:
            out.update(d)
        return out
    ik.bake_animation("idle", parts, {0: pose(off, flap(35)), 2: pose(flap(10), {"Body": {"loc": (0, 0, 0.03)}}), 4: pose(flap(-30), {"Body": {"loc": (0, 0, 0.05)}}),
                                      6: pose(flap(0), {"Body": {"loc": (0, 0, 0.02)}})}, 8, True)
    ik.bake_animation("fly", parts, {0: pose(off, flap(45), {"Body": {"rot": (-8, 0, 0)}}), 1: pose(flap(0), {"Body": {"rot": (-8, 0, 0), "loc": (0, 0, 0.04)}}),
                                     2: pose(flap(-40), {"Body": {"rot": (-8, 0, 0), "loc": (0, 0, 0.06)}}), 3: pose(flap(-5), {"Body": {"rot": (-8, 0, 0), "loc": (0, 0, 0.02)}})}, 4, True)
    ik.bake_animation("dive", parts, {0: pose(off, flap(30, 0)), 1: pose(off, flap(55, 25), {"Body": {"rot": (-25, 0, 0)}}),
                                      2: pose(flap(70, 50), {"Body": {"rot": (-40, 0, 0)}, "Smear": {}}), 3: pose(flap(70, 50), {"Body": {"rot": (-40, 0, 0)}, "Smear": {"scale": 0.7}}),
                                      4: pose(off, flap(20, 30), {"Body": {"rot": (-15, 0, 0)}}), 6: pose(off, flap(0))}, 8, False)
    ik.bake_animation("hurt", parts, {0: pose(off, flap(-20)), 1: pose(flap(60, -10), {"Body": {"rot": (15, 0, 10), "loc": (0, -0.06, 0)}}),
                                      3: pose(flap(30), {"Body": {"rot": (6, 0, 4)}}), 5: pose(flap(0))}, 6, False)
    ik.bake_animation("fall", parts, {0: pose(off, flap(-50, -20), {"Body": {"rot": (30, 0, 20)}}), 2: pose(flap(70, 10), {"Body": {"rot": (90, 0, 60), }}),
                                      4: pose(flap(-60, -10), {"Body": {"rot": (160, 0, 110)}}), 6: pose(flap(40, 20), {"Body": {"rot": (230, 0, 150)}}),
                                      8: pose(flap(80, 0), {"Body": {"rot": (0, 0, 15)}})}, 8, False)
    ik.bake_animation("downed", parts, {0: pose(off, flap(80, 0), {"Body": {"rot": (8, 0, 15)}}), 3: pose(flap(60, 10), {"Body": {"rot": (8, 0, 12)}}),
                                        5: pose(flap(85, -5), {"Body": {"rot": (10, 0, 16), "loc": (0, 0, 0.03)}}), 9: pose(flap(75, 0), {"Body": {"rot": (8, 0, 15)}})}, 12, True)
    for o in parts:
        ik.apply_pose(o, {})
    ik.apply_pose(smear, off["Smear"])
    ik.export_glb(OUT_GLB, animated=True)


MODEL, OUT_GLB, OUT_MAP = (ik.cli_args() + ["", "", ""])[:3]


def main():
    ik.reset()
    if MODEL == "terrain":
        build_terrain(OUT_GLB, OUT_MAP)
        return
    globals()["build_" + MODEL]()


main()
