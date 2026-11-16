"""Tallowford terrain: the village floor, the hills round the bowl and the river channel as one
height field (decimated under 5,000 triangles with the distant ridges), every M_* marker from
layout.py, and a separate river surface ribbon.

    blender --background --factory-startup --python tools/levels/tallowford/make_terrain.py -- <terrain.glb> <river.glb>

The ground is named Terrain-col so Godot gives it a trimesh StaticBody3D on layer 1 (world).
Faces inside the floor rectangle use M_tf_ground (top-down UV over the 2K ground texture); the
hills use M_tf_hills; the ridge silhouettes use M_tf_ridges; the river surface uses M_tf_river.
"""
import math
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "blender"))
import numpy as np  # noqa: E402

import inklib as ik  # noqa: E402
import layout as L  # noqa: E402

out_glb, out_river = ik.cli_args()[:2]
ik.reset()
bpy = ik.bpy


def grid_axis(lo_outer, lo, hi, hi_outer, fine, coarse):
    left = np.arange(lo_outer, lo, coarse)
    mid = np.arange(lo, hi + fine * 0.5, fine)
    right = np.arange(hi + coarse, hi_outer + coarse * 0.5, coarse)
    return np.concatenate([left, mid, right])


xs = grid_axis(L.OUTER_X[0], L.FLOOR_X[0], L.FLOOR_X[1], L.OUTER_X[1], L.FLOOR_STEP, L.WALL_STEP)
zs = grid_axis(L.OUTER_Z[0], L.FLOOR_Z[0], L.FLOOR_Z[1], L.OUTER_Z[1], L.FLOOR_STEP, L.WALL_STEP)
GX, GZ = np.meshgrid(xs, zs)
H = L.height(GX, GZ)
eps = 0.5
slope = np.hypot((L.height(GX + eps, GZ) - L.height(GX - eps, GZ)) / (2 * eps),
                 (L.height(GX, GZ + eps) - L.height(GX, GZ - eps)) / (2 * eps))
NOISE = L.fbm(GX, GZ, 5.0, 21)
GROUND_TRIS = 4450
FW = L.FLOOR_X[1] - L.FLOOR_X[0]
FH = L.FLOOR_Z[1] - L.FLOOR_Z[0]
CX, CZ = 3.0, 0.0


def floor_uv(x, z):
    return ((x - L.FLOOR_X[0]) / FW, 1.0 - (z - L.FLOOR_Z[0]) / FH)


def hill_uv(x, z, h):
    a = (math.atan2(x - CX, -(z - CZ)) / (2 * math.pi)) % 1.0
    return (a * 4.0, 0.14 + 0.86 * min(1.0, max(0.0, (h + 2.0) / 22.0)))


verts, faces, face_mat = [], [], []
index = {}
for j in range(len(zs)):
    for i in range(len(xs)):
        index[(i, j)] = len(verts)
        verts.append(ik.g2b(xs[i], H[j, i], zs[j]))
for j in range(len(zs) - 1):
    for i in range(len(xs) - 1):
        a, b, c, d = index[(i, j)], index[(i + 1, j)], index[(i + 1, j + 1)], index[(i, j + 1)]
        cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
        in_floor = L.FLOOR_X[0] <= cx <= L.FLOOR_X[1] and L.FLOOR_Z[0] <= cz <= L.FLOOR_Z[1]
        tris = [(a, b, c), (a, c, d)] if abs(H[j, i] - H[j + 1, i + 1]) <= abs(H[j, i + 1] - H[j + 1, i]) else [(a, b, d), (b, c, d)]
        for t in tris:
            faces.append(t)
            face_mat.append(0 if in_floor else 1)
obj = ik.make_object("Terrain-col", (verts, faces))
mesh = obj.data
for name in ("M_tf_ground", "M_tf_hills"):
    mesh.materials.append(bpy.data.materials.get(name) or bpy.data.materials.new(name))
for poly in mesh.polygons:
    poly.material_index = face_mat[poly.index]
uv = mesh.uv_layers.new(name="UVMap").data
col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
for poly in mesh.polygons:
    for li in poly.loop_indices:
        vi = mesh.loops[li].vertex_index
        jj, ii = vi // len(xs), vi % len(xs)
        x, z, h = xs[ii], zs[jj], H[jj, ii]
        uv[li].uv = floor_uv(x, z) if poly.material_index == 0 else hill_uv(x, z, h)
        r = 0.12 + 0.88 * ik.smoothstep(0.45, 1.4, slope[jj, ii])
        col.data[li].color = (r, 0.0, ik.clamp01(0.35 + 0.35 * NOISE[jj, ii] + 0.2 * (1 - r)), 1.0)
mesh.color_attributes.active_color = col
mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
if sum(1 for p in mesh.polygons if p.normal.z > 0) < len(mesh.polygons) / 2:
    for p in mesh.polygons:
        p.flip()
full_tris = len(mesh.polygons)
dec = obj.modifiers.new("Decimate", "DECIMATE")
dec.decimate_type = "COLLAPSE"
dec.use_collapse_triangulate = True
dec.ratio = GROUND_TRIS / full_tris
bpy.context.view_layer.objects.active = obj
bpy.ops.object.modifier_apply(modifier=dec.name)
for p in obj.data.polygons:
    p.use_smooth = True

from mathutils.bvhtree import BVHTree  # noqa: E402
bvh = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
errs = []
for j in range(0, len(zs), 2):
    for i in range(0, len(xs), 2):
        if not (L.FLOOR_X[0] <= xs[i] <= L.FLOOR_X[1] and L.FLOOR_Z[0] <= zs[j] <= L.FLOOR_Z[1]):
            continue
        hit = bvh.ray_cast(ik.Vector(ik.g2b(xs[i], 500.0, zs[j])), ik.Vector((0, 0, -1)))
        if hit[0] is not None:
            errs.append(abs(hit[0].z - H[j, i]))
errs = np.array(errs)
print("GROUND decimated %d -> %d tris; floor height error mean %.3f p95 %.3f max %.3f m" % (
    full_tris, ik.tri_count(obj), errs.mean(), np.percentile(errs, 95), errs.max()))
markers = L.all_markers()
worst = 0.0
for name, (x, y, z) in markers.items():
    hit = bvh.ray_cast(ik.Vector(ik.g2b(x, 500.0, z)), ik.Vector((0, 0, -1)))
    if hit[0] is not None and abs(y - L.ground(x, z)) < 1e-6:
        worst = max(worst, abs(hit[0].z - y))
print("GROUND worst marker-to-mesh height error %.3f m" % worst)

# ---------------------------------------------------------------- ridge silhouettes
ridge_mat = bpy.data.materials.new("M_tf_ridges")
ridges = []
for layer, (radius, base_h, amp, seed) in enumerate([(150, 16, 18, 31), (200, 24, 30, 37), (260, 30, 44, 41)]):
    n = 64
    rv, rf = [], []
    for k in range(n + 1):
        a = 2 * math.pi * k / n
        cx, cz = CX + math.sin(a) * radius, CZ - math.cos(a) * radius
        peak = base_h + amp * (0.5 + 0.5 * float(L.fbm(np.array(k * 9.0), np.array(layer * 50.0), 30.0, seed, 4)))
        peak += amp * 0.3 * abs(math.sin(k * 1.3 + layer)) ** 3
        rv.append(ik.g2b(cx, peak, cz))
        rv.append(ik.g2b(CX + (cx - CX) * 0.98, -6.0, CZ + (cz - CZ) * 0.98))
    for k in range(n):
        rf.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
    r_obj = ik.make_object("Ridge_%d" % layer, (rv, rf))
    for poly in r_obj.data.polygons:
        c2 = poly.center.to_2d() - ik.Vector(ik.g2b(CX, 0, CZ)).to_2d()
        if c2.normalized().dot(poly.normal.to_2d()) > 0:
            poly.flip()
    r_obj.data.materials.append(ridge_mat)
    ik.planar_uv(r_obj, lambda co, layer=layer: (0.03 + 0.94 * ((math.atan2(co.x, co.y) / (2 * math.pi)) % 1.0),
                                                 0.01 + 0.11 * min(1.0, max(0.0, (co.z + 6.0) / 80.0))))
    ik.paint_vertex_colors(r_obj, lambda co, lc, nn, tag: (0.5 if co.z > 8 else 0.0, 0.0, 0.7))
    ridges.append(r_obj)

for name, (x, y, z) in sorted(markers.items()):
    ik.make_empty(name, ik.g2b(x, y, z))
print("MARKERS %d" % len(markers))
total = ik.tri_count(obj) + sum(ik.tri_count(o) for o in ridges)
print("MODEL tallowford_terrain tris=%d ground=%d ridges=%d" % (total, ik.tri_count(obj), sum(ik.tri_count(o) for o in ridges)))
ik.export_glb(out_glb, animated=False)

# ---------------------------------------------------------------- river surface (separate file)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
pts = np.array(L.RIVER, dtype=float)
seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
s = np.concatenate([[0], np.cumsum(seg)])
samples = np.arange(0, s[-1], 2.5)
px, pz = np.interp(samples, s, pts[:, 0]), np.interp(samples, s, pts[:, 1])
rv, rf = [], []
half = L.RIVER_HALF + L.RIVER_BANK * 0.6
for k in range(len(samples)):
    k0, k1 = max(0, k - 1), min(len(samples) - 1, k + 1)
    tx, tz = px[k1] - px[k0], pz[k1] - pz[k0]
    tl = math.hypot(tx, tz)
    nx, nz = -tz / tl, tx / tl
    for side in (-1, 1):
        rv.append(ik.g2b(px[k] + nx * half * side, L.WATER_Y, pz[k] + nz * half * side))
for k in range(len(samples) - 1):
    rf.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
river = ik.make_object("RiverSurface", (rv, rf))
for poly in river.data.polygons:
    if poly.normal.z < 0:
        poly.flip()
river.data.materials.append(bpy.data.materials.new("M_tf_river"))
uvl = river.data.uv_layers.new(name="UVMap").data
for poly in river.data.polygons:
    for li in poly.loop_indices:
        vi = river.data.loops[li].vertex_index
        uvl[li].uv = (samples[vi // 2] / s[-1], float(vi % 2))
ik.paint_vertex_colors(river, lambda co, lc, nn, tag: (0.0, 0.0, 0.0))
print("MODEL tallowford_river tris=%d" % ik.tri_count(river))
ik.export_glb(out_river, animated=False)
