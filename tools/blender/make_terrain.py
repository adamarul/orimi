"""Hazewater Vale terrain: the valley floor, walls and river gorges as one height field,
decimated so the whole model (with the distant ridge silhouettes) stays under 5,000 triangles,
the M_* marker nodes, and a separate river surface ribbon.

    blender --background --factory-startup --python tools/blender/make_terrain.py -- <valley_terrain.glb> <paintmap.json>

Writes <dir>/river_surface.glb next to the terrain. The layout lives in valley_layout.py.
The ground is named Terrain-col so Godot gives it a trimesh StaticBody3D (layer 1, world).
Faces inside the floor rectangle use M_terrain (top-down UV over the 2K floor texture); the
walls outside it use M_walls; ridges use M_ridges; the river surface uses M_river.
"""
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402

import inklib as ik  # noqa: E402
import valley_layout as V  # noqa: E402

out_glb, out_map = ik.cli_args()[:2]
ik.reset()
bpy = ik.bpy

xs = V.grid_axis(V.OUTER_X[0], V.FLOOR_X[0], V.FLOOR_X[1], V.OUTER_X[1], V.FLOOR_STEP, V.WALL_STEP)
zs = V.grid_axis(V.OUTER_Z[0], V.FLOOR_Z[0], V.FLOOR_Z[1], V.OUTER_Z[1], V.FLOOR_STEP, V.WALL_STEP)
GX, GZ = np.meshgrid(xs, zs)
H = V.height(GX, GZ)
eps = 0.6
dhdx = (V.height(GX + eps, GZ) - V.height(GX - eps, GZ)) / (2 * eps)
dhdz = (V.height(GX, GZ + eps) - V.height(GX, GZ - eps)) / (2 * eps)
slope = np.hypot(dhdx, dhdz)
NOISE = V.fbm(GX, GZ, 5.0, 21)

nz_cells = len(zs) - 1
n_pieces = 1
bounds = [0, nz_cells]
GROUND_TRIS = 4350
FW = V.FLOOR_X[1] - V.FLOOR_X[0]
FH = V.FLOOR_Z[1] - V.FLOOR_Z[0]


def floor_uv(x, z):
    return ((x - V.FLOOR_X[0]) / FW, 1.0 - (z - V.FLOOR_Z[0]) / FH)


def wall_uv(x, z, h):
    along = z if abs(x) > V.FLOOR_X[1] + 0.01 else x
    return (along / 48.0, 0.125 + 0.875 * min(1.0, max(0.0, h / 34.0)))


pieces = []
for p in range(n_pieces):
    z0, z1 = bounds[p], bounds[p + 1]
    verts, faces, face_mat = [], [], []
    index = {}
    for j in range(z0, z1 + 1):
        for i in range(len(xs)):
            index[(i, j)] = len(verts)
            verts.append(ik.g2b(xs[i], H[j, i], zs[j]))
    for j in range(z0, z1):
        for i in range(len(xs) - 1):
            a, b, c, d = index[(i, j)], index[(i + 1, j)], index[(i + 1, j + 1)], index[(i, j + 1)]
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            in_floor = V.FLOOR_X[0] <= cx <= V.FLOOR_X[1] and V.FLOOR_Z[0] <= cz <= V.FLOOR_Z[1]
            if abs(H[j, i] - H[j + 1, i + 1]) <= abs(H[j, i + 1] - H[j + 1, i]):
                tris = [(a, b, c), (a, c, d)]
            else:
                tris = [(a, b, d), (b, c, d)]
            for t in tris:
                faces.append(t)
                face_mat.append(0 if in_floor else 1)
    obj = ik.make_object("Terrain-col", (verts, faces))
    mesh = obj.data
    mesh.materials.append(bpy.data.materials.get("M_terrain") or bpy.data.materials.new("M_terrain"))
    mesh.materials.append(bpy.data.materials.get("M_walls") or bpy.data.materials.new("M_walls"))
    # make_object recalculated normals; a height field must face up, so rebuild faces' winding check
    for poly in mesh.polygons:
        poly.material_index = face_mat[poly.index]
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    loop_normals = []
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            vi = mesh.loops[li].vertex_index
            jj = z0 + vi // len(xs)
            ii = vi % len(xs)
            x, z, h = xs[ii], zs[jj], H[jj, ii]
            uv[li].uv = floor_uv(x, z) if poly.material_index == 0 else wall_uv(x, z, h)
            s = slope[jj, ii]
            r = 0.15 + 0.85 * ik.smoothstep(0.45, 1.4, s)
            col.data[li].color = (r, 0.0, ik.clamp01(0.35 + 0.35 * NOISE[jj, ii] + 0.2 * (1 - r)), 1.0)
    mesh.color_attributes.active_color = col
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    up = sum(1 for poly in mesh.polygons if poly.normal.z > 0)
    if up < len(mesh.polygons) / 2:
        for poly in mesh.polygons:
            poly.flip()
    full_tris = len(mesh.polygons)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.use_collapse_triangulate = True
    dec.ratio = GROUND_TRIS / full_tris
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=dec.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    pieces.append(obj)

# Height error of the decimated ground against the height field, sampled on the full grid.
from mathutils.bvhtree import BVHTree  # noqa: E402
bvh = BVHTree.FromObject(pieces[0], bpy.context.evaluated_depsgraph_get())
errs, worst = [], []
for j in range(0, len(zs), 2):
    for i in range(0, len(xs), 2):
        hit = bvh.ray_cast(ik.Vector(ik.g2b(xs[i], 500.0, zs[j])), ik.Vector((0, 0, -1)))
        if hit[0] is not None and V.FLOOR_X[0] <= xs[i] <= V.FLOOR_X[1] and V.FLOOR_Z[0] <= zs[j] <= V.FLOOR_Z[1]:
            errs.append(abs(hit[0].z - H[j, i]))
            worst.append((errs[-1], xs[i], zs[j], float(slope[j, i])))
for e, x, z, sl in sorted(worst, reverse=True)[:5]:
    print("GROUND worst error %.2f m at (%.1f, %.1f), slope %.2f" % (e, x, z, sl))
for name, (x, y, z) in V.MARKERS.items():
    hit = bvh.ray_cast(ik.Vector(ik.g2b(x, 500.0, z)), ik.Vector((0, 0, -1)))
    print("GROUND at %s mesh %.2f field %.2f" % (name, hit[0].z, float(V.height(x, z))))
errs = np.array(errs)
print("GROUND decimated %d -> %d tris; floor height error mean %.3f p95 %.3f max %.3f m" % (
    full_tris, ik.tri_count(pieces[0]), errs.mean(), np.percentile(errs, 95), errs.max()))

# ---------------------------------------------------------------- ridge silhouettes
ridge_mat = bpy.data.materials.new("M_ridges")
ridges = []
for layer, (radius, base_h, amp, seed) in enumerate([(170, 26, 34, 31), (230, 34, 52, 37), (300, 40, 70, 41)]):
    n = 72
    verts, faces = [], []
    for k in range(n + 1):
        a = 2 * math.pi * k / n
        cx, cz = math.sin(a) * radius, -20.0 - math.cos(a) * radius * 1.15
        peak = base_h + amp * (0.5 + 0.5 * float(V.fbm(np.array(k * 9.0), np.array(layer * 50.0), 40.0, seed, 4)))
        peak += amp * 0.35 * abs(math.sin(k * 1.7 + layer)) ** 3
        verts.append(ik.g2b(cx, peak, cz))
        verts.append(ik.g2b(cx * 0.98, -6.0, cz * 0.98))
    for k in range(n):
        a, b, c, d = 2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2
        faces.append((a, b, c, d))
    obj = ik.make_object("Ridge_%d" % layer, (verts, faces))
    mesh = obj.data
    for poly in mesh.polygons:
        if (poly.center.to_2d().normalized().dot(poly.normal.to_2d())) > 0:
            poly.flip()
    mesh.materials.append(ridge_mat)
    ik.planar_uv(obj, lambda co, layer=layer: (0.52 + 0.46 * ((math.atan2(co.x, co.y) / (2 * math.pi)) % 1.0), 0.015 + 0.09 * min(1.0, max(0.0, (co.z + 6.0) / 110.0))))
    ik.paint_vertex_colors(obj, lambda co, lc, n, tag: (0.55 if co.z > 10 else 0.0, 0.0, 0.7))
    ridges.append(obj)

# ---------------------------------------------------------------- markers
markers = []
for name, (x, y, z) in V.MARKERS.items():
    markers.append(ik.make_empty(name, ik.g2b(x, y, z)))
for k, (x, y, z) in enumerate(V.stepping_stones()):
    markers.append(ik.make_empty("M_Stone_%d" % (k + 1), ik.g2b(x, y, z)))
for name, (x, z) in V.EXTRA_MARKERS.items():
    markers.append(ik.make_empty(name, ik.g2b(x, float(V.height(x, z)), z)))
for m in markers:
    print("MARKER %s godot=(%.2f, %.2f, %.2f) ground=%.2f" % (m.name, m.location.x, m.location.z, -m.location.y,
                                                             float(V.height(m.location.x, -m.location.y))))

ik.dump_paint_map([], out_map, 2048, extra={"kind": "terrain"})
total = sum(ik.tri_count(o) for o in pieces)
print("MODEL terrain tris=%d pieces=%d largest=%d ridges=%d" % (total, len(pieces), max(ik.tri_count(o) for o in pieces),
                                                                sum(ik.tri_count(o) for o in ridges)))
ik.export_glb(out_glb, animated=False)

# ---------------------------------------------------------------- river surface (separate file)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
pts = np.array(V.RIVER, dtype=float)
seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
s = np.concatenate([[0], np.cumsum(seg)])
samples = np.arange(0, s[-1], 2.0)
px, pz = np.interp(samples, s, pts[:, 0]), np.interp(samples, s, pts[:, 1])
verts, faces = [], []
half = V.RIVER_HALF + V.RIVER_BANK * 0.62
for k in range(len(samples)):
    k0, k1 = max(0, k - 1), min(len(samples) - 1, k + 1)
    tx, tz = px[k1] - px[k0], pz[k1] - pz[k0]
    tl = math.hypot(tx, tz)
    nx, nz = -tz / tl, tx / tl
    for side in (-1, 1):
        verts.append(ik.g2b(px[k] + nx * half * side, V.WATER_Y, pz[k] + nz * half * side))
for k in range(len(samples) - 1):
    a, b, c, d = 2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2
    faces.append((a, b, c, d))
river = ik.make_object("RiverSurface", (verts, faces))
for poly in river.data.polygons:
    if poly.normal.z < 0:
        poly.flip()
river.data.materials.append(bpy.data.materials.new("M_river"))
uvl = river.data.uv_layers.new(name="UVMap").data
for poly in river.data.polygons:
    for li in poly.loop_indices:
        vi = river.data.loops[li].vertex_index
        uvl[li].uv = (0.02 + 0.44 * (samples[vi // 2] / s[-1]), 0.02 + 0.08 * (vi % 2))
ik.paint_vertex_colors(river, lambda co, lc, n, tag: (0.0, 0.0, 0.0))
print("MODEL river_surface tris=%d" % ik.tri_count(river))
ik.export_glb(os.path.join(os.path.dirname(out_glb), "river_surface.glb"), animated=False)
