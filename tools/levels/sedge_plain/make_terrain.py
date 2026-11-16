"""Sedge Plain terrain, headless Blender: the ground tiles, the hills ring with distant ridges,
the safe-ground skin, and the river surface, all from layout.py.

    blender --background --factory-startup --python tools/levels/sedge_plain/make_terrain.py -- <out_dir>

Writes into <out_dir>:
  ground_<r><c>.glb  16 tiles of the 1 m height field over layout.FLOOR_X/Z, each its own model
                     (under 5,000 triangles). Its collision is a separate Ground_<r><c>_shape-colonly
                     trimesh (StaticBody3D, layer 1) that overlaps the neighbouring tiles by two
                     cells, so a body pushed hard against a seam cannot slip between two tiles.
                     Material M_sp_ground: top-down UV over the 2K ground texture.
  hills.glb          the hills and far bank outside the tiles (8 m grid, sunk under the tiles'
                     edge so the seam never shows) plus three distant ridge silhouettes.
                     Material M_sp_hills (top-down UV over the 1K hills texture) and M_sp_ridges.
  safe.glb           a skin 4 cm above every causeway top, island and the Knoll's plateau and
                     ramp. The wrapper gives it a non-cursable InkLook, so it keeps its colour
                     while the hollow around it is cursed. No collision (the tiles have it).
  river.glb          the Lull's surface ribbon at layout.WATER_Y (vfx's water material).
Height error is zero at grid vertices: the tiles are the height field sampled at 1 m, not decimated.
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

out_dir = ik.cli_args()[0]
bpy = ik.bpy

FW = L.FLOOR_X[1] - L.FLOOR_X[0]
FH = L.FLOOR_Z[1] - L.FLOOR_Z[0]
OW = L.OUTER_X[1] - L.OUTER_X[0]
OH = L.OUTER_Z[1] - L.OUTER_Z[0]


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def build_mesh(name, verts_g, tris, uvs, colors, materials, face_mats=None):
    """verts_g: (n, 3) Godot coordinates; tris: (m, 3) indices; uvs, colors: per vertex."""
    vb = [ik.g2b(*v) for v in verts_g]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vb, [], [tuple(int(i) for i in t) for t in tris])
    mesh.validate(clean_customdata=False)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for m in materials:
        mesh.materials.append(bpy.data.materials.get(m) or bpy.data.materials.new(m))
    if face_mats is not None:
        mesh.polygons.foreach_set("material_index", np.asarray(face_mats, dtype=np.int32))
    loop_vi = np.zeros(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loop_vi)
    uv = mesh.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", np.asarray(uvs, dtype=np.float32)[loop_vi].ravel())
    col = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    c = np.ones((len(loop_vi), 4), dtype=np.float32)
    c[:, :3] = np.clip(np.asarray(colors, dtype=np.float32)[loop_vi], 0, 1)
    col.data.foreach_set("color", c.ravel())
    mesh.color_attributes.active_color = col
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    mesh.polygons.foreach_set("use_smooth", np.ones(len(mesh.polygons), dtype=bool))
    up = sum(1 for p in mesh.polygons if p.normal.z > 0)
    if up < len(mesh.polygons) / 2:
        for p in mesh.polygons:
            p.flip()
    mesh.update()
    return obj


def grid_tris(H, nx, nz):
    """Triangles of an nx x nz vertex grid (row-major, z rows), split along the flatter diagonal."""
    tris = []
    for j in range(nz - 1):
        for i in range(nx - 1):
            a, b = j * nx + i, j * nx + i + 1
            c, d = (j + 1) * nx + i + 1, (j + 1) * nx + i
            if abs(H[j, i] - H[j + 1, i + 1]) <= abs(H[j, i + 1] - H[j + 1, i]):
                tris += [(a, b, c), (a, c, d)]
            else:
                tris += [(a, b, d), (b, c, d)]
    return tris


def slope_of(fn, X, Z, eps=0.5):
    dx = (fn(X + eps, Z) - fn(X - eps, Z)) / (2 * eps)
    dz = (fn(X, Z + eps) - fn(X, Z - eps)) / (2 * eps)
    return np.hypot(dx, dz)


def ground_colors(X, Z, S):
    """R outline weight (heavy on steep faces), G no sway, B dry-brush tendency."""
    noise = L.fbm(X, Z, 5.0, 21)
    r = 0.15 + 0.85 * np.clip((S - 0.45) / 0.95, 0, 1) ** 1.5
    b = np.clip(0.35 + 0.35 * noise + 0.2 * (1 - r), 0, 1)
    return np.stack([r, np.zeros_like(r), b], axis=-1)


os.makedirs(out_dir, exist_ok=True)

# ------------------------------------------------------------------------- ground tiles
COL_OVERLAP = 2
xs = np.arange(L.FLOOR_X[0], L.FLOOR_X[1] + 1e-6, L.FLOOR_STEP)
zs = np.arange(L.FLOOR_Z[0], L.FLOOR_Z[1] + 1e-6, L.FLOOR_STEP)
GX, GZ = np.meshgrid(xs, zs)
GH = L.height(GX, GZ)
GS = slope_of(L.height, GX, GZ)
GC = ground_colors(GX, GZ, GS)
cols = np.linspace(0, len(xs) - 1, L.TILES[0] + 1).astype(int)
rows = np.linspace(0, len(zs) - 1, L.TILES[1] + 1).astype(int)
total = 0
for r in range(L.TILES[1]):
    for c in range(L.TILES[0]):
        clear()
        j0, j1, i0, i1 = rows[r], rows[r + 1], cols[c], cols[c + 1]
        sub = (slice(j0, j1 + 1), slice(i0, i1 + 1))
        X, Z, H = GX[sub], GZ[sub], GH[sub]
        nz, nx = H.shape
        verts = np.stack([X.ravel(), H.ravel(), Z.ravel()], axis=1)
        uvs = np.stack([(X.ravel() - L.FLOOR_X[0]) / FW, 1.0 - (Z.ravel() - L.FLOOR_Z[0]) / FH], axis=1)
        name = "Ground_%d%d" % (r, c)
        obj = build_mesh(name, verts, grid_tris(H, nx, nz), uvs, GC[sub].reshape(-1, 3), ["M_sp_ground"])
        n = ik.tri_count(obj)
        # Collision overlaps the neighbouring tiles by COL_OVERLAP cells, so nothing slips through a seam.
        cj0, cj1 = max(j0 - COL_OVERLAP, 0), min(j1 + COL_OVERLAP, len(zs) - 1)
        ci0, ci1 = max(i0 - COL_OVERLAP, 0), min(i1 + COL_OVERLAP, len(xs) - 1)
        csub = (slice(cj0, cj1 + 1), slice(ci0, ci1 + 1))
        CH = GH[csub]
        cverts = np.stack([GX[csub].ravel(), CH.ravel(), GZ[csub].ravel()], axis=1)
        build_mesh(name + "_shape-colonly", cverts, grid_tris(CH, CH.shape[1], CH.shape[0]), np.zeros((len(cverts), 2)),
                   np.zeros((len(cverts), 3)), ["M_sp_ground"])
        total += n
        print("MODEL ground_%d%d tris=%d" % (r, c, n))
        ik.export_glb(os.path.join(out_dir, "ground_%d%d.glb" % (r, c)))
print("GROUND tiles=%d tris=%d step=%.1f m" % (L.TILES[0] * L.TILES[1], total, L.FLOOR_STEP))

# ------------------------------------------------------------------------- hills ring and ridges
clear()
inset = 6.0


def axis(lo_o, lo, hi, hi_o, step):
    left = list(np.arange(lo_o, lo - 1e-6, step))
    if abs(left[-1] - lo) > 1e-6:
        left.append(lo)
    right = [hi] + list(np.arange(hi + step, hi_o + 1e-6, step))
    return np.array(left + [lo + inset] + [hi - inset] + right)


hx = axis(L.OUTER_X[0], L.FLOOR_X[0], L.FLOOR_X[1], L.OUTER_X[1], L.OUTER_STEP)
hz = axis(L.OUTER_Z[0], L.FLOOR_Z[0], L.FLOOR_Z[1], L.OUTER_Z[1], L.OUTER_STEP)
HX, HZ = np.meshgrid(hx, hz)
HH = L.height(HX, HZ)
inner = (HX > L.FLOOR_X[0] + 1e-3) & (HX < L.FLOOR_X[1] - 1e-3) & (HZ > L.FLOOR_Z[0] + 1e-3) & (HZ < L.FLOOR_Z[1] - 1e-3)
HH = np.where(inner, HH - 1.2, HH)
nz, nx = HH.shape
all_tris = grid_tris(HH, nx, nz)
keep = []
for t in all_tris:
    cx = np.mean([HX.ravel()[i] for i in t])
    cz = np.mean([HZ.ravel()[i] for i in t])
    if (L.FLOOR_X[0] + inset + 1e-3 < cx < L.FLOOR_X[1] - inset - 1e-3) and (L.FLOOR_Z[0] + inset + 1e-3 < cz < L.FLOOR_Z[1] - inset - 1e-3):
        continue
    keep.append(t)
used = sorted({i for t in keep for i in t})
remap = {o: n for n, o in enumerate(used)}
verts = np.stack([HX.ravel()[used], HH.ravel()[used], HZ.ravel()[used]], axis=1)
uvs = np.stack([(verts[:, 0] - L.OUTER_X[0]) / OW, 1.0 - (verts[:, 2] - L.OUTER_Z[0]) / OH], axis=1)
hs = slope_of(L.height, verts[:, 0], verts[:, 2], 2.0)
hc = ground_colors(verts[:, 0], verts[:, 2], hs)
hills = build_mesh("Hills-col", verts, [tuple(remap[i] for i in t) for t in keep], uvs, hc, ["M_sp_hills"])
ridges = []
for layer, (radius, base_h, amp, seed) in enumerate([(250, 30, 34, 31), (300, 40, 52, 37), (345, 46, 70, 41)]):
    n = 64
    rv, rf = [], []
    for k in range(n + 1):
        a = 2 * math.pi * k / n
        cx, cz = math.sin(a) * radius, 6.0 - math.cos(a) * radius
        peak = base_h + amp * (0.5 + 0.5 * float(L.fbm(np.array(k * 9.0), np.array(layer * 50.0), 40.0, seed, 4)))
        peak += amp * 0.35 * abs(math.sin(k * 1.7 + layer)) ** 3
        rv.append(ik.g2b(cx, peak, cz))
        rv.append(ik.g2b(cx * 0.98, -6.0, cz * 0.98))
    for k in range(n):
        rf.append((2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2))
    obj = ik.make_object("Ridge_%d" % layer, (rv, rf))
    for poly in obj.data.polygons:
        if poly.center.to_2d().normalized().dot(poly.normal.to_2d()) > 0:
            poly.flip()
    obj.data.materials.append(bpy.data.materials.get("M_sp_ridges") or bpy.data.materials.new("M_sp_ridges"))
    ik.planar_uv(obj, lambda co: (0.5 + 0.5 * ((math.atan2(co.x, co.y) / (2 * math.pi)) % 1.0), 0.02 + 0.06 * min(1.0, max(0.0, (co.z + 6.0) / 120.0))))
    ik.paint_vertex_colors(obj, lambda co, lc, nn, tag: (0.55 if co.z > 10 else 0.0, 0.0, 0.7))
    ridges.append(obj)
n_h, n_r = ik.tri_count(hills), sum(ik.tri_count(o) for o in ridges)
print("MODEL hills tris=%d (hills %d, ridges %d)" % (n_h + n_r, n_h, n_r))
ik.export_glb(os.path.join(out_dir, "hills.glb"))

# ------------------------------------------------------------------------- safe-ground skin
clear()
safe = L.safe_mask(GX, GZ, margin=0.45)
cell = safe[:-1, :-1] | safe[1:, :-1] | safe[:-1, 1:] | safe[1:, 1:]
nz, nx = GH.shape
tris = []
for j in range(nz - 1):
    for i in range(nx - 1):
        if not cell[j, i]:
            continue
        a, b = j * nx + i, j * nx + i + 1
        c, d = (j + 1) * nx + i + 1, (j + 1) * nx + i
        if abs(GH[j, i] - GH[j + 1, i + 1]) <= abs(GH[j, i + 1] - GH[j + 1, i]):
            tris += [(a, b, c), (a, c, d)]
        else:
            tris += [(a, b, d), (b, c, d)]
used = sorted({i for t in tris for i in t})
remap = {o: n for n, o in enumerate(used)}
verts = np.stack([GX.ravel()[used], GH.ravel()[used] + 0.04, GZ.ravel()[used]], axis=1)
uvs = np.stack([(verts[:, 0] - L.FLOOR_X[0]) / FW, 1.0 - (verts[:, 2] - L.FLOOR_Z[0]) / FH], axis=1)
skin = build_mesh("SafeGround", verts, [tuple(remap[i] for i in t) for t in tris], uvs, np.zeros((len(used), 3)), ["M_sp_safe"])
print("MODEL safe tris=%d" % ik.tri_count(skin))
ik.export_glb(os.path.join(out_dir, "safe.glb"))

# ------------------------------------------------------------------------- river surface
clear()
verts, uvs, tris = [], [], []
for line, half_at in ((L.RIVER, lambda s_: L.RIVER_HALF + L.RIVER_BANK * 0.62), (L.BROOK, L.brook_half)):
    pts = np.array(line, dtype=float)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    samples = np.arange(0, s[-1] + 1e-6, 4.0 if line is L.RIVER else 1.5)
    px, pz = np.interp(samples, s, pts[:, 0]), np.interp(samples, s, pts[:, 1])
    first = len(verts)
    for k in range(len(samples)):
        k0, k1 = max(0, k - 1), min(len(samples) - 1, k + 1)
        tx, tz = px[k1] - px[k0], pz[k1] - pz[k0]
        tl = math.hypot(tx, tz)
        nxv, nzv = -tz / tl, tx / tl
        half = float(half_at(samples[k]))
        for side in (-1, 1):
            verts.append((px[k] + nxv * half * side, L.WATER_Y, pz[k] + nzv * half * side))
            uvs.append((samples[k] / s[-1], 0.5 + 0.5 * side))
    for k in range(len(samples) - 1):
        a_, b_, c_, d_ = first + 2 * k, first + 2 * k + 1, first + 2 * k + 3, first + 2 * k + 2
        tris += [(a_, b_, c_), (a_, c_, d_)]
    if line is L.BROOK:
        centre = len(verts)
        verts.append((px[0], L.WATER_Y, pz[0]))
        uvs.append((0.0, 0.5))
        tx, tz = px[1] - px[0], pz[1] - pz[0]
        base = math.atan2(tz, tx)
        half = float(half_at(0.0))
        ring = [first + 1]
        for j in range(1, 10):
            ang = base + math.pi / 2 + math.pi * j / 10
            ring.append(len(verts))
            verts.append((px[0] + math.cos(ang) * half, L.WATER_Y, pz[0] + math.sin(ang) * half))
            uvs.append((0.0, 0.5))
        ring.append(first)
        tris += [(centre, ring[j + 1], ring[j]) for j in range(len(ring) - 1)]
river = build_mesh("RiverSurface", np.array(verts), tris, uvs, np.zeros((len(verts), 3)), ["M_sp_river"])
print("MODEL river tris=%d" % ik.tri_count(river))
ik.export_glb(os.path.join(out_dir, "river.glb"))
print("TERRAIN OK")
