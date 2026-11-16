"""Reedwraith: a tall drifting bundle of ink-black reeds wrapped in a soot veil.

    blender --background --factory-startup --python tools/blender/make_reedwraith.py -- <out.glb> <paintmap.json>

About 2.5 m tall, facing Blender +Y (Godot -Z), hovering with its lowest wisps at Z = 0.
Parts: Lower (root: the lower half of the bundle, its binding and trailing wisps) > Upper (the
reed heads and two long whip reeds, which lash on the attack) > Face (a dark hollow in the reeds
with two pale split-seed eyes, so the player sees where it is looking), and Veil (the soot veil,
keyed only by veil_off, so once shed it stays shed whatever plays next) and Smear (the lash arc,
hidden except on smear frames).
Animations: idle, drift, attack (frames 0 to 10 the windup, matching gameplay's 0.9 s: the reeds
rear back and spread and the eyes flare; then the lash), hurt, veil_off, unravel (1.5 s: the
bundle comes undone, the reeds splaying and drooping as it sinks).
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import inklib as ik  # noqa: E402

out_glb, out_map = ik.cli_args()[:2]
ik.reset()
bpy = ik.bpy
rnd = random.Random(23)

STALKS = [(rnd.uniform(0, 6.28), rnd.uniform(0.03, 0.13), rnd.uniform(0.022, 0.034)) for _ in range(8)]


def stalk(a, r, w, z0, z1, spread0, spread1, lean, sides=4, tip=True):
    """One reed: a thin tapered prism from z0 to z1, fanning from radius spread0 to spread1."""
    sections = []
    n = 4
    for k in range(n + 1):
        t = k / n
        z = z0 + (z1 - z0) * t
        rr = r * (spread0 + (spread1 - spread0) * t * t)
        cx = math.cos(a) * rr + lean[0] * t * t
        cy = math.sin(a) * rr + lean[1] * t * t
        ww = w * (1.0 - 0.75 * t) if tip else w * (0.35 + 0.65 * t)
        sections.append([(cx + math.cos(a + 2 * math.pi * s / sides) * ww, cy + math.sin(a + 2 * math.pi * s / sides) * ww, z) for s in range(sides)])
    if tip:
        sections[-1] = [(sum(p[0] for p in sections[-1]) / sides, sum(p[1] for p in sections[-1]) / sides, z1 + 0.06)]
    else:
        sections[0] = [(sum(p[0] for p in sections[0]) / sides, sum(p[1] for p in sections[0]) / sides, z0 - 0.08)]
    return ik.loft(sections)


lower_parts = []
for a, r, w in STALKS:
    lower_parts.append(stalk(a, r, w, 0.0, 1.25, 2.2, 0.8, (0, 0), tip=False))
# binding: a twisted band around the waist
band = []
for k in range(2):
    sec = []
    for s in range(10):
        ang = 2 * math.pi * s / 10
        rr = 0.17 + 0.015 * math.sin(ang * 3 + k)
        sec.append((math.cos(ang) * rr, math.sin(ang) * rr, 1.02 + 0.16 * k + 0.03 * math.sin(ang * 2)))
    band.append(sec)
lower_parts.append(ik.loft(band))
lower = ik.make_object("Lower", ik.merged(*lower_parts), location=(0, 0, 0.12))

upper_parts = []
for i, (a, r, w) in enumerate(STALKS):
    lean = (math.cos(a) * 0.22, math.sin(a) * 0.22 + 0.06)
    upper_parts.append(stalk(a, r, w, 0.0, 1.05 + 0.25 * ((i * 37) % 7) / 7.0, 0.8, 2.6, lean))
# two long whip reeds curling forward and out: the arms that lash, and a broken silhouette at range
for side in (-1, 1):
    pts = [(side * 0.05, 0.02, 0.0), (side * 0.16, 0.06, 0.5), (side * 0.34, 0.18, 0.95), (side * 0.5, 0.42, 1.25), (side * 0.56, 0.66, 1.3)]
    upper_parts.append(ik.tube(pts, [0.034, 0.03, 0.024, 0.014, 0.0], 4))
upper = ik.make_object("Upper", ik.merged(*upper_parts), parent=lower, location=(0, 0, 1.22))


def face_geo():
    """A shallow dark hood facing +Y and two tall, slanted split-seed eyes standing just proud of it."""
    n = 10
    ring = [(math.cos(2 * math.pi * k / n) * 0.13, 0.0, math.sin(2 * math.pi * k / n) * 0.17) for k in range(n)]
    hood_v, hood_f = ik.loft([[(0.0, 0.004, 0.0)], ring, [(0.0, -0.05, 0.0)]])
    eyes = []
    for side in (-1, 1):
        cx, cz, tilt = side * 0.052, 0.02, side * 0.32
        pts = [(0.0, 0.075), (0.022, 0.0), (0.0, -0.06), (-0.022, 0.0)]
        ring = [(cx + x * math.cos(tilt) - z * math.sin(tilt), 0.012, cz + x * math.sin(tilt) + z * math.cos(tilt)) for x, z in pts]
        eyes.append(ik.loft([[(cx, 0.03, cz)], ring, [(p[0], -0.005, p[2]) for p in ring]], cap_end=True))
    return ik.merged((hood_v, hood_f), *eyes)


face = ik.make_object("Face", face_geo(), parent=upper, location=(0.0, 0.26, 0.98))
face.scale = (1.45, 1.45, 1.45)
seeds = []
for i, (a, r, w) in enumerate(STALKS[::2]):
    top = 0.9 + 0.2 * i / 4.0
    rr = r * (0.8 + 1.8 * 0.72)
    cx, cy = math.cos(a) * rr + math.cos(a) * 0.22 * 0.72, math.sin(a) * rr + math.sin(a) * 0.22 * 0.72
    seeds.append(ik.transformed(ik.loft([[(0, 0, 0)], [(0.03, 0, 0.06), (0, 0.03, 0.06), (-0.03, 0, 0.06), (0, -0.03, 0.06)],
                                         [(0.022, 0, 0.16), (0, 0.022, 0.16), (-0.022, 0, 0.16), (0, -0.022, 0.16)], [(0, 0, 0.21)]]),
                                location=(cx, cy, top)))
seed_obj = ik.make_object("Seeds", ik.merged(*seeds), parent=upper)


def veil_geo():
    """A ragged soot shawl wrapped round the middle of the bundle: open at the top so the reed
    heads fan out above it, torn at the hem, with an inner skin so it reads as a sheet."""
    n = 14
    profile = [(1.9, 0.22), (1.68, 0.33), (1.35, 0.39), (1.05, 0.42), (0.78, 0.44)]
    outer = []
    for k, (z, r) in enumerate(profile):
        ring = []
        for s in range(n):
            ang = 2 * math.pi * s / n
            jag = (rnd.uniform(-0.45, 0.05) if s % 2 else rnd.uniform(-0.12, 0.12)) if k == len(profile) - 1 else (rnd.uniform(-0.04, 0.14) if k == 0 else 0.0)
            rr = r * (1.0 + 0.09 * math.sin(ang * 3 + k) + 0.04 * math.sin(ang * 7))
            ring.append((math.cos(ang) * rr, math.sin(ang) * rr, z + jag))
        outer.append(ring)
    inner = [[(x * 0.9, y * 0.9, z) for x, y, z in ring] for ring in outer]
    verts, faces = [], []
    def add_rings(rings, flip):
        base = len(verts)
        for ring in rings:
            verts.extend(ring)
        for k in range(len(rings) - 1):
            for s in range(n):
                a, b = base + k * n + s, base + k * n + (s + 1) % n
                c, d = base + (k + 1) * n + (s + 1) % n, base + (k + 1) * n + s
                faces.append((a, d, c, b) if flip else (a, b, c, d))
        return base
    ob = add_rings(outer, False)
    ib = add_rings(inner, True)
    last = len(profile) - 1
    for s in range(n):
        t = (s + 1) % n
        faces.append((ob + s, ib + s, ib + t, ob + t))
        faces.append((ob + last * n + t, ib + last * n + t, ib + last * n + s, ob + last * n + s))
    return verts, faces


veil = ik.make_object("Veil", veil_geo(), parent=lower, location=(0, 0, -0.12))
# make_object's normal recalculation can flip a thin open shell; point the outer skin outward
for poly in veil.data.polygons:
    c = poly.center
    radial = ik.Vector((c.x, c.y, 0.0))
    if poly.index < 4 * 14 and radial.length > 1e-4 and poly.normal.dot(radial) < 0:
        poly.flip()
    if 4 * 14 <= poly.index < 8 * 14 and radial.length > 1e-4 and poly.normal.dot(radial) > 0:
        poly.flip()


def smear_geo():
    verts, faces = [], []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-60 + 120 * t)
        w = 0.25 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.01
        verts.append((math.sin(a) * 1.0, 0.3 + math.cos(a) * 0.8, 1.2 + w))
        verts.append((math.sin(a) * 0.8, 0.2 + math.cos(a) * 0.62, 1.05 - w))
    for i in range(n - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    return verts, faces


smear = ik.make_object("Smear", smear_geo(), parent=lower)
parts = [lower, upper, seed_obj, face, veil, smear]
bpy.context.view_layer.update()
ik.set_tags(lower, "reed")
ik.set_tags(upper, "reed")
ik.set_tags(seed_obj, "seed")
ik.set_tags(veil, "veil")
ik.set_tags(smear, "smear")
ik.tag_faces(face, lambda c, n, o: "eye" if (o.matrix_world.inverted() @ c).y > 0.0045 else "hood")
ik.tag_faces(lower, lambda c, n, o: "binding" if 1.08 < c.z < 1.34 and (c.x * c.x + c.y * c.y) > 0.02 else "reed")
for o in parts:
    ik.assign_material(o, "M_reedwraith")
ik.assign_material(veil, "M_reedwraith_veil")


def colors(co, local, n, tag):
    if tag == "smear":
        return (0.0, 0.0, 1.0)
    if tag == "veil":
        return (0.6, 0.15, 0.85)
    if tag == "seed":
        return (0.3, 0.6, 0.6)
    if tag in ("eye", "hood"):
        return (0.3 if tag == "eye" else 0.8, 0.0, 0.3)
    tip = (0.05 + 0.95 * ik.smoothstep(3.05, 1.5, co.z)) * (0.4 + 0.6 * ik.smoothstep(0.0, 0.35, co.z))
    sway = ik.smoothstep(1.4, 3.0, co.z) * 0.6
    return (tip, sway, 0.35 + 0.55 * (1.0 - tip))


for o in parts:
    ik.paint_vertex_colors(o, colors)
ik.smart_uv(parts, angle=45.0, margin=0.01)
ik.dump_paint_map(parts, out_map, 1024, crease_deg=50.0)

ik.store_rest(parts)
HIDE = {"scale": 0.01}
body = [lower, upper, face, smear]
anims = {
    "idle": (24, True, {
        0: {"Lower": {"loc": (0, 0, 0.0)}, "Upper": {"rot": (3, 2, 0)}},
        6: {"Lower": {"loc": (0, 0, 0.04)}, "Upper": {"rot": (5, -2, 4)}},
        12: {"Lower": {"loc": (0, 0, 0.06)}, "Upper": {"rot": (1, -4, 0)}},
        18: {"Lower": {"loc": (0, 0, 0.03)}, "Upper": {"rot": (-2, 0, -4)}},
    }),
    "drift": (12, True, {
        0: {"Lower": {"loc": (0, 0, 0.05), "rot": (10, 0, 0)}, "Upper": {"rot": (-8, 0, 3)}},
        3: {"Lower": {"loc": (0, 0, 0.09), "rot": (12, 0, 2)}, "Upper": {"rot": (-12, 2, 0)}},
        6: {"Lower": {"loc": (0, 0, 0.06), "rot": (10, 0, 0)}, "Upper": {"rot": (-8, 0, -3)}},
        9: {"Lower": {"loc": (0, 0, 0.02), "rot": (8, 0, -2)}, "Upper": {"rot": (-4, -2, 0)}},
    }),
    "attack": (16, False, {
        0: {"Lower": {"rot": (-5, 0, 0)}, "Upper": {"rot": (-18, 0, 0), "scale": (1.1, 1.1, 1.0)}, "Face": {"scale": 1.2}},
        3: {"Lower": {"loc": (0, -0.12, 0.05), "rot": (-10, 0, 0)}, "Upper": {"rot": (-36, 0, 0), "scale": (1.22, 1.22, 1.05)}, "Face": {"scale": 1.35}},
        6: {"Lower": {"loc": (0, -0.18, 0.08), "rot": (-13, 0, 2)}, "Upper": {"rot": (-46, 0, 4), "scale": (1.3, 1.3, 1.08)}, "Face": {"scale": 1.4}},
        8: {"Lower": {"loc": (0, -0.18, 0.08), "rot": (-13, 0, -2)}, "Upper": {"rot": (-48, 0, -4), "scale": (1.32, 1.32, 1.08)}},
        10: {"Lower": {"loc": (0, -0.2, 0.09), "rot": (-14, 0, 0)}, "Upper": {"rot": (-50, 0, 0), "scale": (1.34, 1.34, 1.1)}},
        11: {"Lower": {"loc": (0, 0.25, 0.0), "rot": (16, 0, 0)}, "Upper": {"rot": (58, 0, 0), "scale": (1.0, 1.0, 1.15)}, "Face": {"scale": 1.1},
             "Smear": {"scale": 1.0}},
        12: {"Lower": {"loc": (0, 0.3, -0.02), "rot": (18, 0, 0)}, "Upper": {"rot": (64, 0, 0)}, "Smear": {"scale": (1.1, 1.0, 0.8), "loc": (0, 0.1, -0.15)}},
        13: {"Lower": {"loc": (0, 0.2, 0), "rot": (12, 0, 0)}, "Upper": {"rot": (34, 0, 0), "scale": (1.0, 1.0, 1.0)}, "Face": {}},
        15: {"Lower": {"loc": (0, 0.05, 0), "rot": (4, 0, 0)}, "Upper": {"rot": (8, 0, 0)}},
    }),
    "hurt": (6, False, {
        0: {"Lower": {"loc": (0, -0.2, 0.05), "rot": (-14, 0, 6)}, "Upper": {"rot": (-30, 0, 8)}},
        2: {"Lower": {"loc": (0, -0.25, 0.02), "rot": (-6, 0, 2)}, "Upper": {"rot": (-10, 0, 0)}},
        4: {"Lower": {"loc": (0, -0.15, 0)}, "Upper": {"rot": (4, 0, 0)}},
    }),
    "unravel": (18, False, {
        0: {"Lower": {"loc": (0, -0.1, 0.08), "rot": (-8, 0, 4)}, "Upper": {"rot": (-24, 0, 6), "scale": (1.2, 1.2, 1.1)}, "Face": {"scale": 1.3}},
        3: {"Lower": {"loc": (0, -0.05, 0.0), "rot": (4, 0, -6)}, "Upper": {"rot": (10, 8, -8), "scale": (1.35, 1.35, 1.0)}, "Face": {"loc": (0, 0, -0.06), "scale": 1.0}},
        6: {"Lower": {"loc": (0.05, 0, -0.18), "rot": (10, 0, 8)}, "Upper": {"rot": (24, -10, 10), "scale": (1.55, 1.55, 0.85)}, "Face": {"loc": (0, -0.02, -0.14), "scale": 0.8}},
        9: {"Lower": {"loc": (0.08, 0, -0.38), "rot": (16, 0, 12)}, "Upper": {"rot": (38, -14, 14), "scale": (1.75, 1.75, 0.7)}, "Face": {"loc": (0, -0.04, -0.22), "scale": 0.6}},
        12: {"Lower": {"loc": (0.1, 0, -0.6), "rot": (22, 0, 16)}, "Upper": {"rot": (52, -18, 18), "scale": (1.9, 1.9, 0.55)}, "Face": {"loc": (0, -0.05, -0.3), "scale": 0.4}},
        15: {"Lower": {"loc": (0.12, 0, -0.82), "rot": (28, 0, 20)}, "Upper": {"rot": (64, -20, 22), "scale": (2.0, 2.0, 0.45)}, "Face": {"loc": (0, -0.06, -0.34), "scale": 0.25}},
        17: {"Lower": {"loc": (0.13, 0, -0.95), "rot": (31, 0, 22)}, "Upper": {"rot": (70, -22, 24), "scale": (2.05, 2.05, 0.4)}, "Face": {"scale": 0.15}},
    }),
}
for name, (length, loop, frames) in anims.items():
    for f in frames.values():
        f.setdefault("Smear", HIDE)
    ik.bake_animation(name, body, frames, length, loop)
veil_frames = {
    0: {"Lower": {"rot": (-4, 0, 0)}, "Upper": {"rot": (-12, 0, 0)}, "Veil": {"scale": (1.06, 1.06, 1.0)}},
    2: {"Lower": {"loc": (0, 0, 0.05), "rot": (4, 0, 0)}, "Upper": {"rot": (14, 4, 0)}, "Veil": {"loc": (0, 0, 0.25), "rot": (0, 0, 25), "scale": (1.25, 1.25, 1.05)}},
    4: {"Upper": {"rot": (6, -4, 0)}, "Veil": {"loc": (0.1, -0.1, 0.7), "rot": (10, 0, 70), "scale": (1.5, 1.5, 0.8)}},
    6: {"Lower": {"loc": (0, 0, 0.02)}, "Upper": {"rot": (2, 0, 0)}, "Veil": {"loc": (0.2, -0.2, 1.2), "rot": (20, 6, 130), "scale": (1.6, 1.6, 0.45)}},
    8: {"Veil": {"loc": (0.3, -0.3, 1.6), "rot": (25, 10, 180), "scale": (1.2, 1.2, 0.2)}},
    10: {"Lower": {}, "Upper": {}, "Veil": {"loc": (0, 0, 1.0), "scale": 0.01}},
}
for f in veil_frames.values():
    f.setdefault("Smear", HIDE)
ik.bake_animation("veil_off", [lower, upper, veil, smear], veil_frames, 12, False)
smear.scale = (0.01, 0.01, 0.01)
ik.report("reedwraith", parts)
ik.export_glb(out_glb, animated=True)
