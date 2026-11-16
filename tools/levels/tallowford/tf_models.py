"""Builders for every Tallowford model; make_model.py calls build(<name>).

    blender --background --factory-startup --python tools/levels/tallowford/make_model.py -- <name> <out.glb> <paintmap.json>

Blender axes (X right, Y forward = Godot -Z, Z up); every model's front is +Y and it stands on
Z = 0, except the jetty and landing (origin at the deck's west end, top at Z = 0, running +X into
the river) and the ford-lamp (origin at the top of its pier). Sizes come from layout.py where the
plan needs them. Uses the shared helpers in tools/blender/inklib.py and props.py unchanged.

Models
  house_trim, house_marrow, house_brindle, house_children, house_ferry   the five quest houses
  cottage, shed                                                          neighbours' cottage, outbuilding
  lamp_post        door lamp; animations unlit, kindle, lit (LanternLit swaps in, gold _sacred)
  ford_lamp        tall lamp on a stone pier; animations hooded, unhood, unlit, kindle, lit
  persimmon        bare black tree; animations withered, bloom (leaves and fruit grow in)
  well, dye_vats, cloth_line, drying_rack, jetty, landing, fence
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "..", "blender"))
import inklib as ik  # noqa: E402
import props as P  # noqa: E402
import layout as L  # noqa: E402
from mathutils import Vector  # noqa: E402

bpy = ik.bpy


# ----------------------------------------------------------------------------- helpers
class Parts:
    """Collects (verts, faces) per (object name, tag), then makes one object per name."""

    def __init__(self):
        self.groups = {}
        self.order = []

    def add(self, name, tag, vf):
        if name not in self.groups:
            self.groups[name] = []
            self.order.append(name)
        self.groups[name].append((tag, vf))

    def build(self, material, parent=None):
        objs = {}
        for name in self.order:
            items = self.groups[name]
            merged = ik.merged(*[vf for _, vf in items])
            obj = ik.make_object(name, merged, parent=parent)
            tags = []
            for tag, (v, f) in items:
                tags += [tag] * len(f)
            obj["paint_tags"] = tags
            ik.assign_material(obj, material)
            objs[name] = obj
        return objs


def cyl(r, h, sides=8, cx=0.0, cy=0.0, cz=0.0, r_top=None, rot=0.0):
    r_top = r if r_top is None else r_top
    rings = []
    for z, rr in ((cz, r), (cz + h, r_top)):
        rings.append([(cx + math.cos(2 * math.pi * k / sides + rot) * rr, cy + math.sin(2 * math.pi * k / sides + rot) * rr, z) for k in range(sides)])
    return ik.loft(rings)


def ring_tube(r_out, r_in, h, sides=10, cz=0.0):
    """An open-topped stone ring (a well kerb or a vat): outer wall, rim, inner wall."""
    def ring(rr, z):
        return [(math.cos(2 * math.pi * k / sides) * rr, math.sin(2 * math.pi * k / sides) * rr, z) for k in range(sides)]
    verts, faces = [], []
    rings = [ring(r_out, cz), ring(r_out, cz + h), ring(r_in, cz + h), ring(r_in, cz + 0.05)]
    for rg in rings:
        verts += rg
    for a in range(3):
        for k in range(sides):
            i0, i1 = a * sides + k, a * sides + (k + 1) % sides
            faces.append((i0, i1, i1 + sides, i0 + sides))
    faces.append(tuple(range(3 * sides, 4 * sides)))
    return verts, faces


def oriented_box(a, b, w, h):
    """A box from point a to point b (beam, oar, rail) with cross-section w x h."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ln = d.length
    yaw = math.degrees(math.atan2(d.y, d.x))
    pitch = math.degrees(math.atan2(d.z, math.hypot(d.x, d.y)))
    vf = P.box(ln, w, h, cx=ln / 2, cz=-h / 2)
    return ik.transformed(vf, location=tuple(a), rotation_deg=(0, -pitch, yaw))


def slab(top_a, top_b, thick):
    """A thick roof slope: top edge row top_a (eave) to row top_b (ridge), offset down by thick."""
    n = len(top_a)
    ta = [Vector(p) for p in top_a]
    tb = [Vector(p) for p in top_b]
    nrm = (tb[0] - ta[0]).cross(ta[-1] - ta[0]).normalized()
    if nrm.z < 0:
        nrm = -nrm
    verts = [tuple(p) for p in ta + tb] + [tuple(p - nrm * thick) for p in ta + tb]
    faces = []
    for k in range(n - 1):
        faces.append((k, k + 1, n + k + 1, n + k))
        faces.append((2 * n + k, 2 * n + n + k, 2 * n + n + k + 1, 2 * n + k + 1))
        faces.append((k, 2 * n + k, 2 * n + k + 1, k + 1))
        faces.append((n + k, n + k + 1, 2 * n + n + k + 1, 2 * n + n + k))
    faces.append((0, n, 3 * n, 2 * n))
    faces.append((n - 1, 2 * n + n - 1, 3 * n + n - 1, n + n - 1))
    return verts, faces


def lantern_body(r, h, sides=8, cz=0.0):
    return cyl(r, h, sides, cz=cz, rot=math.pi / sides)


def augment_map(meshes, path, size):
    """Add per-face UV directions of world up and of the horizontal along the face, and pixels per
    metre, to the paint map ik.dump_paint_map wrote (same face order)."""
    with open(path) as f:
        data = json.load(f)
    out = []
    for obj in meshes:
        if obj.type != "MESH" or not obj.data.uv_layers:
            continue
        mesh = obj.data
        uv = mesh.uv_layers.active.data
        mw = obj.matrix_world
        for poly in mesh.polygons:
            li = list(poly.loop_indices)
            p = [mw @ mesh.vertices[mesh.loops[i].vertex_index].co for i in li]
            u = [Vector((uv[i].uv.x * size, (1.0 - uv[i].uv.y) * size)) for i in li]
            n = (mw.to_3x3() @ poly.normal).normalized()
            horiz = n.cross(Vector((0, 0, 1)))
            if horiz.length < 0.2:
                horiz = Vector((1, 0, 0))
            horiz.normalize()
            info = {"up": [0.0, -1.0], "along": [1.0, 0.0], "ppm": 0.0}
            best = None
            for k in range(1, len(p) - 1):
                e1, e2 = p[k] - p[0], p[k + 1] - p[0]
                d1, d2 = u[k] - u[0], u[k + 1] - u[0]
                det = d1.x * d2.y - d1.y * d2.x
                area = e1.cross(e2).length
                if abs(det) > 1e-6 and area > 1e-8 and (best is None or area > best):
                    best = area
                    inv = ((d2.y / det, -d1.y / det), (-d2.x / det, d1.x / det))

                    def grad(fa, fb):
                        return [inv[0][0] * fa + inv[0][1] * fb, inv[1][0] * fa + inv[1][1] * fb]
                    info["up"] = grad(e1.z, e2.z)
                    info["along"] = grad(e1.dot(horiz), e2.dot(horiz))
                    info["ppm"] = math.sqrt(abs(det) / area)
            out.append(info)
    for face, info in zip(data["faces"], out):
        face.update({k: ([round(x, 5) for x in v] if isinstance(v, list) else round(v, 3)) for k, v in info.items()})
    with open(path, "w") as f:
        json.dump(data, f)


WEIGHTS = {
    "stone": 0.85, "stone_top": 0.75, "wood": 0.95, "beam": 0.9, "plaster": 0.3, "screen": 0.12, "door": 0.35,
    "roof": 0.9, "thatch": 0.95, "ridge": 0.9, "lantern": 0.5, "lit": 0.45, "cap": 0.6, "noren": 0.35, "stave": 0.7,
    "hoop": 0.5, "dye_indigo": 0.2, "dye_madder": 0.2, "dye_weld": 0.2, "rope": 0.4, "deck": 0.85, "paper": 0.3,
    "cloth_indigo": 0.45, "cloth_madder": 0.45, "cloth_weld": 0.45, "cloth_pale": 0.45, "soot": 0.9, "bark": 1.0,
    "canopy": 0.85, "canopy_under": 0.9, "fruit": 0.35, "dark": 0.2, "herb": 0.4, "iron": 0.6, "log": 0.8, "kerb": 0.8,
}
SWAY = {"noren", "cloth_indigo", "cloth_madder", "cloth_weld", "cloth_pale", "paper", "herb"}


def colors_for(top_of=None, taper=None):
    def fn(co, local, n, tag):
        r = WEIGHTS.get(tag, 0.7)
        if tag in ("roof", "thatch") and n.z < -0.2:
            r = 1.0
        if taper is not None and tag in ("bark",):
            r = taper(co)
        g = 0.0
        if tag in SWAY and top_of is not None:
            g = ik.clamp01((top_of(co) - co.z) / 1.2)
        return (r, g, 0.3 + 0.35 * ik.hash01(co.x * 3.1, co.y * 2.7, co.z * 1.9) + 0.25 * (1 - r))
    return fn


def finish(name, objs, size, colors, out_map, crease=30.0, angle=40.0, animated=False):
    bpy.context.view_layer.update()
    for o in objs:
        if o.type == "MESH" and not o.name.endswith("colonly"):
            ik.paint_vertex_colors(o, colors)
    meshes = [o for o in objs if o.type == "MESH" and not o.name.endswith("colonly")]
    ik.smart_uv(meshes, angle=angle, margin=0.008)
    ik.dump_paint_map(meshes, out_map, size, crease_deg=crease)
    augment_map(meshes, out_map, size)
    ik.report(name, meshes)
    return meshes


# ----------------------------------------------------------------------------- houses
HOUSES = {
    "house_trim": dict(w=6.4, d=4.8, roof="hip", pitch=0.55, features=["lantern_rack", "bench"], seed=1),
    "house_marrow": dict(w=6.0, d=4.6, roof="gable", pitch=0.62, features=["noren", "drip"], seed=2),
    "house_brindle": dict(w=5.4, d=4.2, roof="hip", pitch=0.6, features=["barrel", "rope"], seed=3),
    "house_children": dict(w=7.0, d=5.0, roof="gable", pitch=0.58, features=["veranda", "chimes"], seed=4),
    "house_ferry": dict(w=5.6, d=4.4, roof="hip", pitch=0.52, features=["porch", "oars"], seed=5),
    "cottage": dict(w=L.COTTAGE_W, d=L.COTTAGE_D, roof="gable", pitch=0.7, thatch=True, features=["herbs"], seed=6, wall_h=2.0),
    "shed": dict(w=L.SHED_W, d=L.SHED_D, roof="lean", pitch=0.3, features=["woodpile"], seed=7, wall_h=2.0, open_front=True),
}
for _name, _c, _w, _d, _t, _k in L.HOUSES:
    assert abs(HOUSES[_name]["w"] - _w) < 1e-6 and abs(HOUSES[_name]["d"] - _d) < 1e-6, _name


def posts_along(length, bay=1.6, odd=False):
    n = max(2, int(round(length / bay)))
    if odd and n % 2 == 0:
        n += 1
    return [-length / 2 + length * k / n for k in range(n + 1)]


def build_house(name, out_glb, out_map):
    s = HOUSES[name]
    rnd = random.Random(s["seed"])
    w, d = s["w"], s["d"]
    wall_h = s.get("wall_h", 2.2)
    base = 0.32
    top = base + wall_h
    pt = Parts()
    body = "Body"
    pt.add(body, "stone", P.box(w + 0.5, d + 0.5, base + 0.25, cz=-0.25, taper=0.98))
    if not s.get("open_front"):
        pt.add(body, "stone_top", P.box(1.5, 0.55, 0.17, cy=d / 2 + 0.52, cz=0.0))
    xs = posts_along(w, odd=True)
    ys = posts_along(d)
    door_bay = len(xs) // 2 - 1
    # posts
    corners = set()
    for x in xs:
        for y in (-d / 2, d / 2):
            corners.add((round(x, 3), round(y, 3)))
    for y in ys:
        for x in (-w / 2, w / 2):
            corners.add((round(x, 3), round(y, 3)))
    for x, y in sorted(corners):
        pt.add(body, "wood", P.box(0.16, 0.16, wall_h + 0.04, cx=x, cy=y, cz=base))
    # sills and head plates
    for z0, hgt in ((base, 0.1), (top - 0.16, 0.16)):
        pt.add(body, "beam", P.box(w + 0.1, 0.13, hgt, cy=d / 2, cz=z0))
        pt.add(body, "beam", P.box(w + 0.1, 0.13, hgt, cy=-d / 2, cz=z0))
        pt.add(body, "beam", P.box(0.13, d + 0.1, hgt, cx=w / 2, cz=z0))
        pt.add(body, "beam", P.box(0.13, d + 0.1, hgt, cx=-w / 2, cz=z0))
    # infill: kneewall plaster below, paper screen above; the back wall is plaster
    rail = base + 0.75

    def bay_panels(a, b, along_x, side, kind):
        ln = abs(b - a) - 0.16
        mid = (a + b) / 2
        t = 0.06
        if kind == "door":
            box = P.box(ln, t, top - 0.16 - base - 0.1, cx=mid, cy=side - 0.06 * (1 if side > 0 else -1), cz=base + 0.1)
            pt.add(body, "door", box)
            pt.add(body, "beam", P.box(ln + 0.1, 0.14, 0.12, cx=mid, cy=side, cz=top - 0.62))
            pt.add(body, "screen", P.box(ln, t, 0.28, cx=mid, cy=side, cz=top - 0.48))
            return
        if kind == "open":
            return
        def put(tag, z0, hgt):
            if along_x:
                pt.add(body, tag, P.box(ln, t, hgt, cx=mid, cy=side, cz=z0))
            else:
                pt.add(body, tag, P.box(t, ln, hgt, cx=side, cy=mid, cz=z0))
        if kind == "plaster":
            put("plaster", base + 0.1, top - 0.16 - base - 0.1)
            return
        put("plaster", base + 0.1, rail - base - 0.1)
        put("screen", rail + 0.07, top - 0.16 - rail - 0.07)
        if along_x:
            pt.add(body, "beam", P.box(ln + 0.02, 0.1, 0.07, cx=mid, cy=side, cz=rail))
        else:
            pt.add(body, "beam", P.box(0.1, ln + 0.02, 0.07, cx=side, cy=mid, cz=rail))

    for k in range(len(xs) - 1):
        front_kind = "door" if k == door_bay else ("open" if s.get("open_front") else "screen")
        bay_panels(xs[k], xs[k + 1], True, d / 2, front_kind)
        bay_panels(xs[k], xs[k + 1], True, -d / 2, "plaster")
    for k in range(len(ys) - 1):
        kind = "plaster" if s.get("open_front") else ("screen" if k % 2 == 0 or len(ys) < 4 else "plaster")
        bay_panels(ys[k], ys[k + 1], False, w / 2, kind)
        bay_panels(ys[k], ys[k + 1], False, -w / 2, kind)
    # roof
    ov = 0.65
    ex, ey = w / 2 + ov, d / 2 + ov
    ze = top + 0.02
    lift = 0.22
    roof_tag = "thatch" if s.get("thatch") else "roof"
    thick = 0.36 if s.get("thatch") else 0.2
    if s["roof"] == "hip":
        zr = ze + ey * s["pitch"]
        rx = max(0.1, ex - ey)
        E = [(-ex, -ey, ze + lift), (ex, -ey, ze + lift), (ex, ey, ze + lift), (-ex, ey, ze + lift)]
        Mb, Mr, Mf, Ml = (0, -ey, ze), (ex, 0, ze), (0, ey, ze), (-ex, 0, ze)
        R0, R1 = (-rx, 0, zr), (rx, 0, zr)
        ring = [E[0], Mb, E[1], Mr, E[2], Mf, E[3], Ml]
        verts = ring + [R0, R1] + [(x, y, z - thick) for x, y, z in ring] + [(0, 0, ze - thick)]
        iR0, iR1, iC = 8, 9, 18
        faces = [(6, 5, 8), (5, 9, 8), (5, 4, 9),        # front
                 (0, 1, 8), (1, 9, 8), (1, 2, 9),        # back
                 (0, 8, 7), (7, 8, 6),                   # left hip
                 (2, 3, 9), (3, 4, 9)]                   # right hip
        for k in range(8):
            a, b = k, (k + 1) % 8
            faces.append((a, b, 10 + b, 10 + a))
            faces.append((10 + a, 10 + b, iC))
        pt.add("Roof", roof_tag, (verts, faces))
        pt.add("Roof", "ridge", ik.tube([R0, R1], [0.1, 0.1], 5))
        for e in (E[0], E[1], E[2], E[3]):
            r = R0 if e[0] < 0 else R1
            pt.add("Roof", "ridge", ik.tube([r, (e[0] * 1.02, e[1] * 1.02, e[2] + 0.03)], [0.08, 0.05], 4))
    elif s["roof"] == "gable":
        zr = ze + ey * s["pitch"]
        for side in (1, -1):
            eave = [(-ex, side * ey, ze + lift), (0, side * ey, ze), (ex, side * ey, ze + lift)]
            ridge = [(-ex, 0, zr + lift * 0.5), (0, 0, zr), (ex, 0, zr + lift * 0.5)]
            pt.add("Roof", roof_tag, slab(eave, ridge, thick))
        pt.add("Roof", "ridge", ik.tube([(-ex - 0.1, 0, zr + lift * 0.5 + 0.05), (0, 0, zr + 0.05), (ex + 0.1, 0, zr + lift * 0.5 + 0.05)], [0.13, 0.12, 0.13], 6))
        for sx in (1, -1):
            gx = sx * w / 2
            tri = ([(gx, -d / 2, top), (gx, d / 2, top), (gx, 0, zr - 0.15)], [(0, 1, 2)])
            v, f = tri
            back = [(x - sx * 0.05, y, z) for x, y, z in v]
            pt.add(body, "plaster", (v + back, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]))
    else:  # lean-to
        zf, zb = top + 0.05, top + 0.05 + (d + 2 * ov) * s["pitch"]
        eave = [(-ex, ey, zf), (0, ey, zf), (ex, ey, zf)]
        back = [(-ex, -ey, zb), (0, -ey, zb), (ex, -ey, zb)]
        pt.add("Roof", roof_tag, slab(eave, back, thick))
        for x in (-w / 2, w / 2):
            pt.add(body, "plaster", ([(x, -d / 2, top), (x, d / 2, top), (x, -d / 2, zb - 0.3), (x - 0.05, -d / 2, top), (x - 0.05, d / 2, top), (x - 0.05, -d / 2, zb - 0.3)],
                                      [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]))
    # features
    feats = s.get("features", [])
    fy = d / 2
    if "lantern_rack" in feats:
        x0, x1 = -w / 2 + 0.4, xs[door_bay] - 0.3
        pt.add("Rack", "beam", oriented_box((x0, fy + 0.45, top - 0.05), (x1, fy + 0.45, top - 0.05), 0.07, 0.07))
        for k in range(4):
            x = x0 + 0.3 + (x1 - x0 - 0.6) * k / 3
            zc = top - 0.62 - 0.08 * (k % 2)
            pt.add("Rack", "rope", ik.tube([(x, fy + 0.45, top - 0.05), (x, fy + 0.45, zc + 0.36)], [0.012, 0.012], 3))
            pt.add("Rack", "lantern", ik.transformed(lantern_body(0.15, 0.32, cz=zc), location=(x, fy + 0.45, 0)))
            pt.add("Rack", "cap", ik.transformed(cyl(0.11, 0.05, 8, cz=zc + 0.32), location=(x, fy + 0.45, 0)))
    if "bench" in feats:
        bx = w / 2 - 1.0
        pt.add("Bench", "wood", P.box(1.5, 0.55, 0.08, cx=bx, cy=fy + 0.75, cz=0.72))
        for sx in (-0.6, 0.6):
            pt.add("Bench", "wood", P.box(0.08, 0.5, 0.72, cx=bx + sx, cy=fy + 0.75, cz=0.0))
        for k in range(3):
            pt.add("Bench", "lantern", ik.transformed(lantern_body(0.12 + 0.02 * k, 0.26, cz=0.8), location=(bx - 0.45 + 0.45 * k, fy + 0.72, 0)))
    if "noren" in feats:
        a, b = xs[door_bay], xs[door_bay + 1]
        n = 3
        for k in range(n):
            cx = a + 0.08 + (b - a - 0.16) * (k + 0.5) / n
            pt.add("Noren", "noren", P.box((b - a - 0.16) / n - 0.03, 0.025, 0.75, cx=cx, cy=fy + 0.08, cz=top - 0.62 - 0.75))
    if "drip" in feats:
        pt.add("Drip", "wood", oriented_box((w / 2 + 0.3, fy - 0.6, 1.9), (w / 2 + 0.3, -fy + 0.6, 1.9), 0.06, 0.06))
        for k in range(3):
            y = fy - 1.0 - k * 0.9
            pt.add("Drip", "cloth_indigo" if k != 1 else "cloth_madder", P.box(0.03, 0.6, 1.1, cx=w / 2 + 0.3, cy=y, cz=0.78))
    if "barrel" in feats:
        bx, by = w / 2 + 0.05, fy - 0.2
        pt.add("Barrel", "stave", cyl(0.36, 0.85, 10, cx=bx, cy=by, r_top=0.33))
        pt.add("Barrel", "hoop", cyl(0.375, 0.07, 10, cx=bx, cy=by, cz=0.18))
        pt.add("Barrel", "hoop", cyl(0.355, 0.07, 10, cx=bx, cy=by, cz=0.66))
    if "rope" in feats:
        pt.add("Rope", "rope", ik.transformed(P.torus(0.24, 0.05, 12, 4, 0.06), location=(-w / 2 + 0.5, fy + 0.9, 0)))
        pt.add("Rope", "rope", ik.transformed(P.torus(0.2, 0.05, 12, 4, 0.14), location=(-w / 2 + 0.5, fy + 0.9, 0)))
    if "veranda" in feats:
        pt.add("Deck", "deck", P.box(w + 0.2, 1.1, 0.12, cy=fy + 0.6, cz=base - 0.1))
        for x in (-w / 2, w / 2):
            pt.add("Deck", "wood", P.box(0.14, 0.14, base, cx=x, cy=fy + 1.08, cz=0.0))
    if "chimes" in feats:
        for k, x in enumerate((-w / 2 + 0.7, w / 2 - 0.7)):
            pt.add("Chimes", "rope", ik.tube([(x, fy + 0.5, top - 0.02), (x, fy + 0.5, top - 0.5)], [0.012, 0.012], 3))
            pt.add("Chimes", "paper", P.box(0.16, 0.02, 0.38, cx=x, cy=fy + 0.5, cz=top - 0.92))
    if "porch" in feats:
        pt.add("Deck", "deck", P.box(w - 1.0, 1.2, 0.12, cy=fy + 0.65, cz=base - 0.1))
    if "oars" in feats:
        for k, x in enumerate((w / 2 - 0.6, w / 2 - 1.0)):
            a = (x, fy + 0.55 + 0.05 * k, 0.05)
            b = (x + 0.25, fy + 0.12, 2.6 - 0.1 * k)
            pt.add("Oars", "wood", oriented_box(a, b, 0.07, 0.05))
            pt.add("Oars", "wood", ik.transformed(P.box(0.2, 0.03, 0.55), location=(a[0] + 0.02, a[1], a[2])))
    if "herbs" in feats:
        for k in range(5):
            x = -w / 2 + 0.6 + k * 0.4
            pt.add("Herbs", "rope", ik.tube([(x, fy + 0.45, top - 0.05), (x, fy + 0.45, top - 0.3)], [0.01, 0.01], 3))
            pt.add("Herbs", "herb", ik.cone((x, fy + 0.45, top - 0.3), (x, fy + 0.45, top - 0.75), 0.11, 5))
    if "woodpile" in feats:
        for row in range(3):
            for k in range(5 - row):
                x = -w / 2 + 0.7 + k * 0.32 + row * 0.16
                z = 0.16 + row * 0.27
                pt.add("Woodpile", "log", ik.tube([(x, -d / 2 + 0.3, z), (x, d / 2 - 0.4, z)], [0.15, 0.15], 6))
        pt.add("Woodpile", "wood", P.box(0.8, 0.8, 0.7, cx=w / 2 - 0.8, cy=0.3, cz=0.0))
        pt.add("Woodpile", "wood", P.box(0.6, 0.6, 0.5, cx=w / 2 - 0.9, cy=0.25, cz=0.7))
    objs = pt.build("M_tf_" + name)
    root = objs[body]
    for o in objs.values():
        if o is not root:
            o.parent = root
    collider = ik.make_object(name.title().replace("_", "") + "Collider-convcolonly", P.box(w + 0.45, d + 0.45, top + 0.4, cz=-0.2))
    size = 1024
    fin = finish(name, list(objs.values()), size, colors_for(top_of=lambda co: top), out_map, crease=35.0)
    ik.export_glb(out_glb)
    return fin


# ----------------------------------------------------------------------------- lamps
def lamp_frames(lit_objs, unlit_objs, extra_hidden=()):
    for o in list(lit_objs) + list(unlit_objs) + list(extra_hidden):
        o["rest_loc"] = list(o.location)
        o["rest_rot"] = list(o.rotation_euler)
        o["rest_scale"] = list(o.scale)


def build_lamp_post(out_glb, out_map):
    head = L.LAMP_HEAD_Y
    arm = L.LAMP_ARM
    pt = Parts()
    pt.add("Post", "stone", P.box(0.42, 0.42, 0.24, cz=-0.08, taper=0.85))
    pt.add("Post", "wood", P.box(0.14, 0.14, 2.62, cz=0.1, taper=0.85))
    pt.add("Post", "wood", oriented_box((0.05, 0, 2.62), (-arm - 0.08, 0, 2.62), 0.08, 0.09))
    pt.add("Post", "wood", oriented_box((0.0, 0, 2.25), (-0.3, 0, 2.6), 0.05, 0.05))
    pt.add("Post", "rope", ik.tube([(-arm, 0, 2.58), (-arm, 0, head + 0.3)], [0.012, 0.012], 3))
    pt.add("Post", "cap", cyl(0.17, 0.06, 8, cx=-arm, cz=head + 0.24, r_top=0.08))
    pt.add("Post", "cap", cyl(0.15, 0.04, 8, cx=-arm, cz=head - 0.26))
    pt.add("Lantern", "lantern", ik.transformed(lantern_body(0.2, 0.5, cz=-0.25), location=(-arm, 0, head)))
    lit = Parts()
    lit.add("LanternLit", "lit", ik.transformed(lantern_body(0.205, 0.5, cz=-0.25), location=(-arm, 0, head)))
    objs = pt.build("M_tf_lamp_post")
    lobjs = lit.build("M_tf_lamp_post_lit_sacred")
    post, lantern, lanternlit = objs["Post"], objs["Lantern"], lobjs["LanternLit"]
    lantern.parent = post
    lanternlit.parent = post
    collider = ik.make_object("LampPostCollider-convcolonly", P.box(0.3, 0.3, 2.6))
    parts = [post, lantern, lanternlit]
    meshes = finish("lamp_post", parts, 512, colors_for(), out_map, crease=40.0)
    ik.store_rest([lantern, lanternlit])
    hide = P.tucked(lanternlit)
    hide_unlit = P.tucked(lantern)
    ik.bake_animation("unlit", [lantern, lanternlit], {0: {lanternlit.name: hide}}, 12, True)
    ik.bake_animation("kindle", [lantern, lanternlit], {
        0: {lanternlit.name: hide},
        1: {lanternlit.name: {"scale": 0.7}, lantern.name: hide_unlit},
        2: {lanternlit.name: {"scale": 1.12}, lantern.name: hide_unlit},
        4: {lanternlit.name: {"scale": 0.96}, lantern.name: hide_unlit},
        6: {lanternlit.name: {"scale": 1.0}, lantern.name: hide_unlit}}, 8, False)
    ik.bake_animation("lit", [lantern, lanternlit], {
        0: {lanternlit.name: {"scale": 1.0}, lantern.name: hide_unlit},
        5: {lanternlit.name: {"scale": (1.0, 1.0, 1.02)}, lantern.name: hide_unlit},
        8: {lanternlit.name: {"scale": 1.0}, lantern.name: hide_unlit},
        15: {lanternlit.name: {"scale": (1.01, 1.01, 0.99)}, lantern.name: hide_unlit}}, 24, True)
    ik.apply_pose(lanternlit, hide)
    ik.export_glb(out_glb, animated=True)


def build_ford_lamp(out_glb, out_map):
    rnd = random.Random(17)
    head = L.FORD_HEAD_Y
    pt = Parts()
    # pier: an octagonal stone drum from the river bed to the top
    sections = []
    for z, r in ((-2.0, 1.55), (-0.6, 1.42), (0.0, 1.38), (0.25, 1.32)):
        sections.append([(math.cos(2 * math.pi * k / 8 + 0.2) * r * (1 + 0.04 * math.sin(k * 2.1 + z)), math.sin(2 * math.pi * k / 8 + 0.2) * r, z) for k in range(8)])
    pt.add("Pier", "stone", ik.loft(sections))
    pt.add("Pier", "stone_top", P.box(1.9, 1.9, 0.12, cz=0.2, taper=0.92))
    # post with braces, pegs and a small roof over the lantern
    post_top = head - 0.62
    pt.add("Post", "wood", P.box(0.34, 0.34, post_top - 0.3, cz=0.3, taper=0.8))
    for a in range(4):
        ang = math.pi / 2 * a + math.pi / 4
        pt.add("Post", "wood", oriented_box((math.cos(ang) * 0.85, math.sin(ang) * 0.85, 0.3), (math.cos(ang) * 0.12, math.sin(ang) * 0.12, 2.0), 0.1, 0.1))
    for k in range(8):
        z = 1.0 + k * 0.55
        ang = (k % 2) * math.pi
        pt.add("Post", "wood", oriented_box((0, 0, z), (math.cos(ang) * 0.38, math.sin(ang) * 0.38, z), 0.06, 0.06))
    pt.add("Post", "cap", cyl(0.62, 0.1, 8, cz=post_top, rot=math.pi / 8))
    pt.add("Post", "cap", cyl(0.55, 0.08, 8, cz=head + 0.6, rot=math.pi / 8))
    for k in range(4):
        ang = math.pi / 2 * k + math.pi / 4
        pt.add("Post", "cap", P.box(0.06, 0.06, 1.12, cx=math.cos(ang) * 0.5, cy=math.sin(ang) * 0.5, cz=post_top + 0.08))
    roof_v = [(math.cos(2 * math.pi * k / 8 + math.pi / 8) * 1.0, math.sin(2 * math.pi * k / 8 + math.pi / 8) * 1.0, head + 0.78 + (0.12 if k % 2 == 0 else 0.0)) for k in range(8)]
    roof_low = [(x * 0.96, y * 0.96, z - 0.14) for x, y, z in roof_v]
    roof = ik.loft([roof_low, roof_v, [(0, 0, head + 1.55)]])
    pt.add("Post", "roof", roof)
    pt.add("Post", "cap", ik.tube([(0, 0, head + 1.5), (0, 0, head + 2.0)], [0.06, 0.0], 5))
    pt.add("Lantern", "lantern", lantern_body(0.48, 1.18, cz=head - 0.59))
    lit = Parts()
    lit.add("LanternLit", "lit", lantern_body(0.49, 1.18, cz=head - 0.59))
    hood = Parts()
    hv, hf = ik.ico(1.0, 2, (1.0, 1.0, 1.25), 0.28, 23)
    hv = [(x, y, head + 0.2 + z * (0.9 if z > 0 else 1.1)) for x, y, z in hv]
    hood.add("Hood", "soot", (hv, hf))
    for k in range(6):
        ang = rnd.uniform(0, 6.28)
        a = (math.cos(ang) * 0.75, math.sin(ang) * 0.75, head - 0.4)
        b = (math.cos(ang) * 0.9, math.sin(ang) * 0.9, head - 1.6 - rnd.uniform(0, 0.8))
        hood.add("Hood", "soot", ik.tube([a, b], [0.22, 0.0], 5))
    objs = pt.build("M_tf_ford_lamp")
    lobjs = lit.build("M_tf_ford_lamp_lit_sacred")
    hobjs = hood.build("M_tf_ford_lamp")
    pier, post, lantern, lanternlit, hoodo = objs["Pier"], objs["Post"], objs["Lantern"], lobjs["LanternLit"], hobjs["Hood"]
    for o in (post, lantern, lanternlit, hoodo):
        o.parent = pier
    ik.make_object("PierCollider-convcolonly", cyl(1.45, 2.3, 8, cz=-2.0))
    ik.make_object("PostCollider-convcolonly", P.box(0.5, 0.5, head + 1.6, cz=0.25))
    parts = [pier, post, lantern, lanternlit, hoodo]
    finish("ford_lamp", parts, 1024, colors_for(), out_map, crease=35.0)
    anim = [lantern, lanternlit, hoodo]
    ik.store_rest(anim)
    hide_lit, hide_lantern, hide_hood = P.tucked(lanternlit, 3.0), P.tucked(lantern, 3.0), P.tucked(hoodo, 3.0)
    ik.bake_animation("hooded", anim, {0: {lanternlit.name: hide_lit}}, 12, True)
    ik.bake_animation("unhood", anim, {
        0: {lanternlit.name: hide_lit},
        2: {lanternlit.name: hide_lit, hoodo.name: {"loc": (0, 0, 0.25), "rot": (6, 0, 0)}},
        4: {lanternlit.name: hide_lit, hoodo.name: {"loc": (0.3, 0, 0.45), "rot": (14, -8, 0), "scale": 0.95}},
        6: {lanternlit.name: hide_lit, hoodo.name: {"loc": (1.0, 0, -0.4), "rot": (30, -20, 10), "scale": 0.8}},
        8: {lanternlit.name: hide_lit, hoodo.name: {"loc": (1.6, 0, -2.4), "rot": (50, -35, 20), "scale": 0.55}},
        10: {lanternlit.name: hide_lit, hoodo.name: {"loc": (1.9, 0, -4.8), "rot": (70, -40, 30), "scale": 0.3}},
        12: {lanternlit.name: hide_lit, hoodo.name: hide_hood}}, 12, False)
    ik.bake_animation("unlit", anim, {0: {lanternlit.name: hide_lit, hoodo.name: hide_hood}}, 12, True)
    ik.bake_animation("kindle", anim, {
        0: {lanternlit.name: hide_lit, hoodo.name: hide_hood},
        1: {lanternlit.name: {"scale": 0.7}, lantern.name: hide_lantern, hoodo.name: hide_hood},
        2: {lanternlit.name: {"scale": 1.12}, lantern.name: hide_lantern, hoodo.name: hide_hood},
        4: {lanternlit.name: {"scale": 0.96}, lantern.name: hide_lantern, hoodo.name: hide_hood},
        6: {lanternlit.name: {"scale": 1.0}, lantern.name: hide_lantern, hoodo.name: hide_hood}}, 8, False)
    ik.bake_animation("lit", anim, {
        0: {lanternlit.name: {"scale": 1.0}, lantern.name: hide_lantern, hoodo.name: hide_hood},
        6: {lanternlit.name: {"scale": (1.0, 1.0, 1.015)}, lantern.name: hide_lantern, hoodo.name: hide_hood},
        14: {lanternlit.name: {"scale": 1.0}, lantern.name: hide_lantern, hoodo.name: hide_hood}}, 24, True)
    ik.apply_pose(lanternlit, hide_lit)
    ik.export_glb(out_glb, animated=True)


# ----------------------------------------------------------------------------- persimmon
def build_persimmon(out_glb, out_map):
    rnd = random.Random(5)
    vf, strokes = [], []
    trunk = P.gnarled((0, 0, -0.2), (0.08, -0.05, 1), 2.4, 4, 0.12, rnd)
    vf.append(ik.tube(trunk, [0.32, 0.27, 0.24, 0.22, 0.2], 7))
    strokes.append(ik.chain(trunk, 1.0, 0.8))
    tips = []
    for k, (yaw, pitch, ln) in enumerate([(15, 30, 2.9), (110, 25, 2.7), (200, 32, 3.0), (290, 28, 2.6), (60, 60, 2.2)]):
        d = (math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch)))
        limb = P.gnarled(trunk[-1 if k == 4 else -2], d, ln, 4, 0.22, rnd, up_bias=0.05)
        vf.append(ik.tube(limb, [0.17, 0.13, 0.09, 0.05, 0.0], 5))
        strokes.append(ik.chain(limb, 0.85, 0.05))
        tips.append(limb[-1])
        for j in range(2):
            sb = limb[1 + j]
            sd = (d[0] + rnd.uniform(-0.9, 0.9), d[1] + rnd.uniform(-0.9, 0.9), d[2] + rnd.uniform(0.0, 0.6))
            br = P.gnarled(sb, sd, ln * 0.5, 3, 0.3, rnd)
            vf.append(ik.tube(br, [0.07, 0.05, 0.025, 0.0], 4))
            strokes.append(ik.chain(br, 0.5, 0.03))
            tips.append(br[-1])
            twig = P.gnarled(br[1], (sd[0] + rnd.uniform(-1, 1), sd[1] + rnd.uniform(-1, 1), sd[2] + 0.4), ln * 0.25, 3, 0.4, rnd)
            vf.append(ik.tube(twig, [0.03, 0.02, 0.01, 0.0], 3))
            strokes.append(ik.chain(twig, 0.35, 0.02))
    tree = ik.make_object("Trunk", ik.merged(*vf))
    ik.set_tags(tree, "bark")
    kerb = ik.make_object("Kerb", ring_tube(1.75, 1.35, 0.42, 10, cz=-0.1), parent=tree)
    ik.set_tags(kerb, "kerb")
    canopy = []
    for k, tip in enumerate(tips):
        r = rnd.uniform(0.75, 1.1)
        base = ik.ico(r, 1, (1.0, 1.0, 0.62), 0.2, 70 + k)
        fruit = []
        for j in range(3):
            a = rnd.uniform(0, 6.28)
            fruit.append(ik.transformed(ik.ico(0.1, 1, (1, 1, 0.85), 0.05, 400 + k * 5 + j),
                                        location=(math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, -r * 0.25 + rnd.uniform(-0.05, 0.1))))
        obj = ik.make_object("Canopy%d" % (k + 1), ik.merged(base, *fruit), parent=tree, location=tuple(Vector(tip) + Vector((0, 0, 0.15))))
        nb = len(base[1])
        tags = ["canopy" if obj.data.polygons[i].normal.z > -0.3 else "canopy_under" for i in range(nb)]
        obj["paint_tags"] = tags + ["fruit"] * (len(obj.data.polygons) - nb)
        canopy.append(obj)
    for o in [tree, kerb] + canopy:
        ik.assign_material(o, "M_tf_persimmon")
    ik.make_object("TrunkCollider-convcolonly", ik.tube([(0, 0, -0.2), (0, 0, 2.4)], [0.35, 0.3], 7))
    ik.make_object("KerbCollider-convcolonly", cyl(1.75, 0.45, 10, cz=-0.1))
    taper = ik.chain_taper(strokes)
    finish("persimmon", [tree, kerb] + canopy, 1024, colors_for(taper=taper), out_map, crease=60.0)
    ik.store_rest(canopy)
    hidden = {c.name: P.tucked(c) for c in canopy}
    ik.bake_animation("withered", canopy, {0: dict(hidden)}, 12, True)
    order = sorted(range(len(canopy)), key=lambda i: canopy[i].location.z)
    frames = {0: dict(hidden)}
    for rank, i in enumerate(order):
        f0 = 1 + rank
        frames.setdefault(f0, {})[canopy[i].name] = {"scale": 0.4}
        frames.setdefault(f0 + 2, {})[canopy[i].name] = {"scale": 1.15}
        frames.setdefault(f0 + 4, {})[canopy[i].name] = {"scale": 1.0}
    ik.bake_animation("bloom", canopy, frames, 30, False)
    for c in canopy:
        ik.apply_pose(c, P.tucked(c))
    ik.export_glb(out_glb, animated=True)


# ----------------------------------------------------------------------------- yard props
def build_well(out_glb, out_map):
    pt = Parts()
    pt.add("Well", "stone", ring_tube(0.92, 0.66, 0.78, 10, cz=-0.1))
    pt.add("Well", "dark", cyl(0.67, 0.02, 10, cz=0.12))
    for x in (-0.95, 0.95):
        pt.add("Well", "wood", P.box(0.13, 0.13, 2.05, cx=x, cz=0.0, taper=0.9))
    pt.add("Well", "wood", oriented_box((-1.12, 0, 1.55), (1.12, 0, 1.55), 0.12, 0.12))
    pt.add("Well", "rope", ik.transformed(cyl(0.11, 1.5, 8, cz=-0.75), location=(0, 0, 1.55), rotation_deg=(0, 90, 0)))
    pt.add("Well", "wood", oriented_box((1.0, 0, 1.55), (1.25, 0, 1.25), 0.05, 0.05))
    pt.add("Well", "rope", ik.tube([(0.1, 0, 1.45), (0.1, 0, 0.95)], [0.015, 0.015], 3))
    pt.add("Well", "stave", cyl(0.17, 0.26, 8, cx=0.1, cz=0.68, r_top=0.2))
    pt.add("Well", "hoop", cyl(0.19, 0.04, 8, cx=0.1, cz=0.86))
    for side in (1, -1):
        pt.add("Well", "roof", slab([(-1.3, side * 0.85, 2.0), (0, side * 0.85, 1.94), (1.3, side * 0.85, 2.0)], [(-1.3, 0, 2.45), (0, 0, 2.42), (1.3, 0, 2.45)], 0.08))
    pt.add("Well", "ridge", ik.tube([(-1.35, 0, 2.48), (1.35, 0, 2.48)], [0.07, 0.07], 5))
    pt.add("Bucket", "stave", cyl(0.2, 0.32, 8, cx=-1.25, cy=0.6, r_top=0.23))
    objs = pt.build("M_tf_well")
    objs["Bucket"].parent = objs["Well"]
    ik.make_object("WellCollider-convcolonly", cyl(0.95, 0.85, 10, cz=-0.1))
    ik.make_object("PostLCollider-convcolonly", P.box(0.2, 0.2, 2.0, cx=-0.95))
    ik.make_object("PostRCollider-convcolonly", P.box(0.2, 0.2, 2.0, cx=0.95))
    finish("well", list(objs.values()), 512, colors_for(), out_map)
    ik.export_glb(out_glb)


def build_dye_vats(out_glb, out_map):
    pt = Parts()
    for k, dye in enumerate(("dye_indigo", "dye_madder", "dye_weld")):
        x = (k - 1) * 2.0
        pt.add("Vats", "stave", ik.transformed(ring_tube(0.72, 0.62, 0.9, 12, cz=-0.05), location=(x, 0, 0)))
        for z in (0.15, 0.62):
            pt.add("Vats", "hoop", cyl(0.735, 0.07, 12, cx=x, cz=z))
        pt.add("Vats", dye, cyl(0.63, 0.03, 12, cx=x, cz=0.72))
    pt.add("Vats", "wood", oriented_box((0.2, 0.2, 0.75), (0.9, -0.3, 2.0), 0.06, 0.06))
    pt.add("Vats", "wood", ik.transformed(P.box(0.22, 0.04, 0.4), location=(0.2, 0.2, 0.45)))
    pt.add("Vats", "wood", P.box(5.6, 0.5, 0.1, cy=-1.05, cz=0.3))
    for x in (-2.6, 0.0, 2.6):
        pt.add("Vats", "wood", P.box(0.1, 0.4, 0.3, cx=x, cy=-1.05, cz=0.0))
    objs = pt.build("M_tf_dye_vats")
    for k in range(3):
        ik.make_object("Vat%dCollider-convcolonly" % (k + 1), cyl(0.74, 0.95, 10, cx=(k - 1) * 2.0, cz=-0.05))
    finish("dye_vats", list(objs.values()), 512, colors_for(), out_map)
    ik.export_glb(out_glb)


def hanging_sheet(cx, w, top, h, nx=3, nz=3, cy=0.0, wave=0.05, seed=0):
    """A cloth or paper sheet as a thin closed slab of two grids joined at the rim (so it sways in pieces).
    Closed, so make_object's normal recalculation points both faces outward; two loose faces got
    flipped the same way and one side drew only the outline."""
    rnd = random.Random(seed)
    verts, faces = [], []
    for side, off in ((0, 0.012), (1, -0.012)):
        base = len(verts)
        for j in range(nz + 1):
            for i in range(nx + 1):
                x = cx - w / 2 + w * i / nx
                z = top - h * j / nz
                y = cy + off + wave * math.sin(i * 1.7 + j * 0.9 + seed) * (j / nz)
                verts.append((x + rnd.uniform(-0.01, 0.01), y, z))
        for j in range(nz):
            for i in range(nx):
                a = base + j * (nx + 1) + i
                q = (a, a + 1, a + nx + 2, a + nx + 1)
                faces.append(q if side == 0 else tuple(reversed(q)))
    n = (nx + 1) * (nz + 1)
    rim = ([(i, 0) for i in range(nx)] + [(nx, j) for j in range(nz)]
           + [(i, nz) for i in range(nx, 0, -1)] + [(0, j) for j in range(nz, 0, -1)])
    for k, (i, j) in enumerate(rim):
        i2, j2 = rim[(k + 1) % len(rim)]
        a, b = j * (nx + 1) + i, j2 * (nx + 1) + i2
        faces.append((b, a, a + n, b + n))
    return verts, faces


def build_cloth_line(out_glb, out_map):
    pt = Parts()
    for x in (-2.5, 2.5):
        pt.add("Poles", "wood", P.box(0.12, 0.12, 2.75, cx=x, cz=-0.1, taper=0.85))
        pt.add("Poles", "wood", oriented_box((x, 0, 2.5), (x * 1.08, 0.0, 2.7), 0.06, 0.06))
    pt.add("Poles", "rope", ik.tube([(-2.5, 0, 2.5), (-1.2, 0, 2.38), (0, 0, 2.34), (1.2, 0, 2.38), (2.5, 0, 2.5)], [0.015] * 5, 3))
    for k, (tag, x, h) in enumerate((("cloth_indigo", -1.75, 1.45), ("cloth_madder", -0.6, 1.3), ("cloth_weld", 0.6, 1.5), ("cloth_pale", 1.75, 1.2))):
        top = 2.38 - 0.04 * abs(x)
        pt.add("Cloth", tag, hanging_sheet(x, 1.0, top, h, 3, 4, seed=k))
    objs = pt.build("M_tf_cloth_line")
    objs["Cloth"].parent = objs["Poles"]
    ik.make_object("PolesCollider-convcolonly", P.box(5.2, 0.2, 2.6))
    finish("cloth_line", list(objs.values()), 512, colors_for(top_of=lambda co: 2.4), out_map, crease=60.0)
    ik.export_glb(out_glb)


def build_drying_rack(out_glb, out_map):
    pt = Parts()
    for x in (-1.2, 1.2):
        pt.add("Frame", "wood", oriented_box((x, -0.5, 0.0), (x, 0.0, 1.85), 0.07, 0.07))
        pt.add("Frame", "wood", oriented_box((x, 0.5, 0.0), (x, 0.0, 1.85), 0.07, 0.07))
    for z, y in ((1.8, 0.0), (1.2, -0.17), (1.2, 0.17)):
        pt.add("Frame", "wood", oriented_box((-1.35, y, z), (1.35, y, z), 0.05, 0.05))
    for k in range(5):
        x = -1.0 + k * 0.5
        top = 1.78 if k % 2 == 0 else 1.18
        y = 0.0 if k % 2 == 0 else (0.17 if k % 4 == 1 else -0.17)
        pt.add("Paper", "paper", hanging_sheet(x, 0.42, top, 0.55 if top > 1.5 else 0.5, 2, 2, cy=y, wave=0.03, seed=k))
    objs = pt.build("M_tf_drying_rack")
    objs["Paper"].parent = objs["Frame"]
    ik.make_object("RackCollider-convcolonly", P.box(2.6, 1.0, 1.8))
    finish("drying_rack", list(objs.values()), 512, colors_for(top_of=lambda co: 1.8 if co.z > 1.25 else 1.2), out_map, crease=60.0)
    ik.export_glb(out_glb)


def build_jetty(out_glb, out_map):
    ln, wd = L.JETTY_LEN, L.JETTY_W
    pt = Parts()
    pt.add("Deck", "deck", P.box(ln, wd, 0.14, cx=ln / 2, cz=-0.14))
    for k in range(6):
        x = 0.4 + (ln - 0.8) * k / 5
        for y in (-wd / 2 + 0.1, wd / 2 - 0.1):
            pt.add("Deck", "wood", P.box(0.2, 0.2, 2.2, cx=x, cy=y, cz=-2.3))
    for y in (-wd / 2 + 0.1, wd / 2 - 0.1):
        pt.add("Deck", "beam", P.box(ln, 0.14, 0.16, cx=ln / 2, cy=y, cz=-0.3))
        pt.add("Deck", "wood", ik.tube([(ln - 0.2, y, -0.2), (ln - 0.2, y, 0.85)], [0.12, 0.1], 6))
    pt.add("Deck", "rope", ik.transformed(P.torus(0.26, 0.05, 12, 4, 0.05), location=(ln - 1.0, wd / 2 - 0.45, 0)))
    for k in range(4):
        pt.add("Deck", "wood", P.box(0.6, 0.06, 0.06, cx=ln + 0.05, cy=-0.25 + 0.0, cz=-0.4 - k * 0.38))
    objs = pt.build("M_tf_jetty")
    ik.make_object("DeckCollider-convcolonly", P.box(ln, wd, 0.5, cx=ln / 2, cz=-0.5))
    finish("jetty", list(objs.values()), 512, colors_for(), out_map)
    ik.export_glb(out_glb)


def build_landing(out_glb, out_map):
    ln, wd = L.LANDING_LEN, L.LANDING_W
    pt = Parts()
    for k in range(3):
        x0 = k * ln / 3
        pt.add("Steps", "stone_top" if k == 0 else "stone", P.box(ln / 3 + 0.05, wd, 1.6 - 0.0, cx=x0 + ln / 6, cz=-1.6 - k * 0.2, taper=0.99))
    for y in (-wd / 2 + 0.2, wd / 2 - 0.2):
        pt.add("Steps", "wood", ik.tube([(ln - 0.3, y, -0.6), (ln - 0.3, y, 0.7)], [0.12, 0.1], 6))
    objs = pt.build("M_tf_landing")
    for k in range(3):
        ik.make_object("Step%dCollider-convcolonly" % (k + 1), P.box(ln / 3 + 0.05, wd, 1.6, cx=k * ln / 3 + ln / 6, cz=-1.6 - k * 0.2))
    finish("landing", list(objs.values()), 512, colors_for(), out_map)
    ik.export_glb(out_glb)


def build_fence(out_glb, out_map):
    pt = Parts()
    for x in (-2.0, 0.0, 2.0):
        pt.add("Fence", "wood", ik.tube([(x, 0, -0.15), (x + 0.02, 0, 1.05)], [0.07, 0.06], 5))
    for z in (0.35, 0.62, 0.88):
        pt.add("Fence", "log", ik.tube([(-2.05, 0.03, z), (0.0, -0.03, z + 0.03), (2.05, 0.03, z)], [0.04, 0.045, 0.04], 4))
    objs = pt.build("M_tf_fence")
    ik.make_object("FenceCollider-convcolonly", P.box(4.0, 0.2, 1.0))
    finish("fence", list(objs.values()), 512, colors_for(), out_map, crease=60.0)
    ik.export_glb(out_glb)


BUILDERS = {
    "lamp_post": build_lamp_post, "ford_lamp": build_ford_lamp, "persimmon": build_persimmon, "well": build_well,
    "dye_vats": build_dye_vats, "cloth_line": build_cloth_line, "drying_rack": build_drying_rack, "jetty": build_jetty,
    "landing": build_landing, "fence": build_fence,
}
for _n in HOUSES:
    BUILDERS[_n] = (lambda n: (lambda g, m: build_house(n, g, m)))(_n)
ANIMATED = {"lamp_post": ["unlit", "lit"], "ford_lamp": ["hooded", "unlit", "lit"], "persimmon": ["withered"]}
TEXTURE_SIZE = {n: 1024 for n in HOUSES}
TEXTURE_SIZE.update({"ford_lamp": 1024, "persimmon": 1024})


def build(name, out_glb, out_map):
    ik.reset()
    BUILDERS[name](out_glb, out_map)
