"""Splotchet: a small hopping blot of ink with a splash crown and two pale, slanted thumbprint
eyes with ink pupils.

    blender --background --factory-startup --python tools/blender/make_splotchet.py -- <out.glb> <paintmap.json>

About 0.8 m across and 0.75 m tall to the crown tips, facing Blender +Y (Godot -Z), resting on
Z = 0. Parts: Body (root, pivot at the ground so squash and stretch stay planted) > EyeL, EyeR,
Crown (the splash flicks that bristle on the windup), Drop1..3 (satellite droplets), Smear (the
lunge arc, hidden except on smear frames).
Animations: idle, hop, attack (frames 0 to 6 the windup, matching gameplay's 0.55 s, then the
lunge), hurt, unravel (1.5 s: the blot loses its shape and spreads into a puddle).
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402

import inklib as ik  # noqa: E402

out_glb, out_map = ik.cli_args()[:2]
ik.reset()
bpy = ik.bpy
rnd = random.Random(17)


def blob(radius, height, subdiv, wobble, seed, flat_bottom=True):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    r = random.Random(seed)
    phases = [r.random() * 6.28 for _ in range(6)]
    verts = []
    for v in bm.verts:
        x, y, z = v.co
        a = math.atan2(y, x)
        k = 1.0 + wobble * (math.sin(3 * a + phases[0]) * 0.5 + math.sin(5 * a + phases[1] + z * 2) * 0.3
                            + math.sin(2 * z * 3 + phases[2]) * 0.2)
        zz = (z + 1.0) / 2.0
        bulge = 1.0 + 0.18 * (1.0 - zz)
        verts.append((x * radius * k * bulge, y * radius * k * bulge, zz ** 0.9 * height if flat_bottom else z * height))
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


body_v, body_f = blob(0.38, 0.52, 3, 0.14, 3)
# pull a few low rim vertices outward into splash points
body = ik.make_object("Body", (body_v, body_f))


def disc(r, n=9, slant=0.0):
    """An oval eye; slant (degrees) tips it so the inner corner sits lower, a frown."""
    c, s = math.cos(math.radians(slant)), math.sin(math.radians(slant))
    ring = [(math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r * 1.3) for k in range(n)]
    verts = [(0.0, 0.0, 0.012)] + [(x * c - y * s, x * s + y * c, 0.0) for x, y in ring]
    back = [(x * 0.92, y * 0.92, -0.01) for x, y, _ in verts[1:]]
    verts += back
    faces = [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)]
    faces += [(1 + k, 1 + n + k, 1 + n + (k + 1) % n, 1 + (k + 1) % n) for k in range(n)]
    faces.append(tuple(1 + n + k for k in reversed(range(n))))
    return verts, faces


bpy.context.view_layer.update()


def on_surface(x, z):
    """Point and normal where a ray from the front hits the body at height z."""
    hit, loc, nrm, _ = body.ray_cast(ik.Vector((x, 2.0, z)), ik.Vector((0.0, -1.0, 0.0)))
    if not hit:
        raise SystemExit("eye ray missed the body")
    return loc + nrm * 0.004, nrm


def eye(name, r, x, z, slant):
    loc, nrm = on_surface(x, z)
    obj = ik.make_object(name, disc(r, slant=slant), parent=body, location=tuple(loc))
    obj.rotation_euler = nrm.to_track_quat("Z", "Y").to_euler()
    return obj


eye_l = eye("EyeL", 0.078, -0.12, 0.34, -22.0)
eye_r = eye("EyeR", 0.072, 0.125, 0.33, 22.0)


def crown_geo():
    """Five splash flicks rising from the top and back of the blot, curling outward at the tips:
    they break the round silhouette so it reads at range, and bristle on the windup."""
    vf = []
    for k, (ang, lean, ln, w) in enumerate([(100, 0.55, 0.26, 0.05), (150, 0.75, 0.22, 0.042), (40, 0.75, 0.21, 0.042),
                                             (200, 0.95, 0.17, 0.035), (-20, 0.95, 0.16, 0.035)]):
        a = math.radians(ang)
        d = ik.Vector((math.cos(a) * lean, math.sin(a) * lean - 0.25, 1.0)).normalized()
        out = ik.Vector((math.cos(a), math.sin(a) - 0.3, 0.0))
        base = ik.Vector((math.cos(a) * 0.12, math.sin(a) * 0.1 - 0.04, -0.06))
        pts = [base, base + d * ln * 0.4, base + d * ln * 0.75 + out * 0.03, base + d * ln + out * 0.09]
        vf.append(ik.tube([tuple(p) for p in pts], [w, w * 0.8, w * 0.45, 0.0], 4))
    return ik.merged(*vf)


top_hit, top_loc, _, _ = body.ray_cast(ik.Vector((0.0, -0.03, 2.0)), ik.Vector((0.0, 0.0, -1.0)))
crown = ik.make_object("Crown", crown_geo(), parent=body, location=(0.0, -0.03, top_loc.z))
drops = []
for k, (x, y, s) in enumerate([(-0.46, -0.12, 0.06), (0.42, -0.24, 0.05), (0.06, -0.48, 0.042)]):
    v, f = blob(s, s * 1.3, 1, 0.1, 30 + k)
    drops.append(ik.make_object("Drop%d" % (k + 1), (v, f), parent=body, location=(x, y, 0.0)))


def smear_geo():
    verts, faces = [], []
    n = 8
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-50 + 100 * t)
        w = 0.16 * math.sin(math.pi * min(1.0, t * 1.1)) + 0.005
        verts.append((math.sin(a) * 0.55, 0.25 + math.cos(a) * 0.3, 0.22 + w))
        verts.append((math.sin(a) * 0.45, 0.2 + math.cos(a) * 0.24, 0.18 - w * 0.5))
    for i in range(n - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    return verts, faces


smear = ik.make_object("Smear", smear_geo(), parent=body)
parts = [body, eye_l, eye_r, crown] + drops + [smear]
bpy.context.view_layer.update()
for o in parts:
    ik.set_tags(o, "ink")
for e in (eye_l, eye_r):
    ik.set_tags(e, "eye")
ik.set_tags(smear, "smear")
for o in parts:
    ik.assign_material(o, "M_splotchet")


def colors(co, local, n, tag):
    if tag == "eye":
        return (0.25, 0.0, 0.2)
    if tag == "smear":
        return (0.0, 0.0, 1.0)
    r = 1.0 if co.z > 0.04 else 0.55
    return (r, 0.0, 0.45 + 0.4 * ik.hash01(co.x * 11, co.y * 13, co.z * 7))


for o in parts:
    ik.paint_vertex_colors(o, colors)
ik.smart_uv(parts, angle=50.0, margin=0.015)
ik.dump_paint_map(parts, out_map, 1024, crease_deg=40.0)

ik.store_rest(parts)
HIDE = {"scale": 0.01}
anims = {
    "idle": (12, True, {
        0: {"Body": {"scale": (1.04, 1.04, 0.93)}},
        3: {"Body": {"scale": (1.0, 1.0, 1.0)}},
        6: {"Body": {"scale": (0.97, 0.97, 1.06)}, "Drop1": {"loc": (0, 0, 0.01)}, "Crown": {"rot": (0, 6, 0)}},
        9: {"Body": {"scale": (1.0, 1.0, 1.0)}, "EyeL": {"scale": (1.0, 0.2, 1.0)}, "EyeR": {"scale": (1.0, 0.2, 1.0)}, "Drop1": {}, "Crown": {}},
        10: {"EyeL": {}, "EyeR": {}},
    }),
    "hop": (8, True, {
        0: {"Body": {"scale": (1.16, 1.16, 0.74)}},
        1: {"Body": {"loc": (0, 0, 0.08), "scale": (0.84, 0.84, 1.32)}, "Drop1": {"loc": (0.05, 0, 0.1)}, "Drop2": {"loc": (-0.04, 0, 0.08)}},
        2: {"Body": {"loc": (0, 0, 0.3), "scale": (0.9, 0.9, 1.14)}, "Drop1": {"loc": (0.1, 0, -0.05)}, "Drop2": {"loc": (-0.08, 0, -0.1)}, "Drop3": {"loc": (0, 0.05, -0.1)}},
        3: {"Body": {"loc": (0, 0, 0.42)}, "EyeL": {"scale": (1.0, 1.25, 1.0)}, "EyeR": {"scale": (1.0, 1.25, 1.0)}},
        4: {"Body": {"loc": (0, 0, 0.28), "scale": (0.94, 0.94, 1.1)}, "EyeL": {}, "EyeR": {}},
        5: {"Body": {"scale": (1.28, 1.28, 0.62)}, "Drop1": {"loc": (0.08, 0, 0)}, "Drop2": {"loc": (-0.06, 0, 0)}, "Drop3": {"loc": (0, -0.06, 0)}},
        6: {"Body": {"scale": (1.08, 1.08, 0.9)}, "Drop1": {}, "Drop2": {}, "Drop3": {}},
        7: {"Body": {}},
    }),
    "attack": (12, False, {
        0: {"Body": {"scale": (1.14, 1.14, 0.84)}, "EyeL": {"scale": (1.0, 0.55, 1.0)}, "EyeR": {"scale": (1.0, 0.55, 1.0)},
            "Crown": {"scale": (1.15, 1.15, 1.45)}},
        2: {"Body": {"loc": (0, -0.12, 0), "scale": (1.12, 1.0, 0.8), "rot": (-16, 0, 0)}, "EyeL": {"scale": (1.15, 0.4, 1.0)},
            "EyeR": {"scale": (1.15, 0.4, 1.0)}, "Crown": {"scale": (1.25, 1.25, 1.75), "rot": (-18, 0, 0)},
            "Drop1": {"loc": (0.04, -0.04, 0.04)}, "Drop2": {"loc": (-0.04, -0.04, 0.04)}},
        4: {"Body": {"loc": (0.025, -0.14, 0), "scale": (1.14, 1.0, 0.78), "rot": (-18, 0, 3)}, "Crown": {"scale": (1.3, 1.3, 1.85), "rot": (-20, 0, 6)}},
        5: {"Body": {"loc": (-0.025, -0.14, 0), "scale": (1.14, 1.0, 0.78), "rot": (-18, 0, -3)}, "Crown": {"scale": (1.3, 1.3, 1.85), "rot": (-20, 0, -6)}},
        6: {"Body": {"loc": (0, -0.15, 0), "scale": (1.16, 1.0, 0.76), "rot": (-19, 0, 0)}, "Crown": {"scale": (1.3, 1.3, 1.9), "rot": (-22, 0, 0)}},
        7: {"Body": {"loc": (0, 0.34, 0.06), "scale": (0.84, 1.45, 0.82), "rot": (14, 0, 0)}, "EyeL": {"scale": (1.0, 1.2, 1.0)},
            "EyeR": {"scale": (1.0, 1.2, 1.0)}, "Crown": {"scale": (1.0, 1.0, 1.2), "rot": (30, 0, 0)}, "Smear": {"scale": 1.0},
            "Drop1": {}, "Drop2": {}},
        8: {"Body": {"loc": (0, 0.42, 0.0), "scale": (1.1, 1.22, 0.8), "rot": (8, 0, 0)}, "Crown": {"rot": (16, 0, 0)},
            "Smear": {"scale": (1.1, 1.2, 0.9), "loc": (0, 0.08, 0)}},
        9: {"Body": {"loc": (0, 0.34, 0), "scale": (1.16, 1.06, 0.82)}, "EyeL": {}, "EyeR": {}, "Crown": {}},
        11: {"Body": {"loc": (0, 0.12, 0), "scale": (1.02, 1.02, 0.97)}},
    }),
    "hurt": (6, False, {
        0: {"Body": {"loc": (0, -0.12, 0.02), "scale": (1.3, 1.3, 0.58), "rot": (-10, 0, 0)}, "EyeL": {"scale": (1.0, 0.15, 1.0)}, "EyeR": {"scale": (1.0, 0.15, 1.0)}},
        2: {"Body": {"loc": (0, -0.16, 0), "scale": (0.9, 0.9, 1.15)}, "EyeL": {"scale": (1.0, 0.5, 1.0)}, "EyeR": {"scale": (1.0, 0.5, 1.0)}},
        4: {"Body": {"loc": (0, -0.14, 0), "scale": (1.04, 1.04, 0.95)}, "EyeL": {}, "EyeR": {}},
    }),
    "unravel": (18, False, {
        0: {"Body": {"loc": (0, -0.05, 0), "scale": (0.86, 0.86, 1.22)}, "EyeL": {"scale": (1.3, 1.3, 1.0)}, "EyeR": {"scale": (1.3, 1.3, 1.0)},
            "Crown": {"scale": (1.3, 1.3, 1.6)}},
        2: {"Body": {"scale": (1.05, 1.05, 0.96), "rot": (0, 0, 6)}, "EyeL": {"loc": (0, 0, -0.02), "scale": (1.0, 0.7, 1.0)},
            "EyeR": {"loc": (0, 0, -0.03), "scale": (1.0, 0.6, 1.0)}, "Crown": {"scale": (1.1, 1.1, 1.1), "rot": (0, 18, 0)}},
        4: {"Body": {"scale": (1.18, 1.18, 0.82), "rot": (0, 0, -5)}, "EyeL": {"loc": (-0.02, 0, -0.06), "scale": (0.9, 0.55, 1.0)},
            "EyeR": {"loc": (0.02, 0, -0.08), "scale": (0.9, 0.5, 1.0)}, "Crown": {"scale": (1.0, 1.0, 0.8), "rot": (-20, 24, 0)},
            "Drop1": {"loc": (-0.12, 0.02, 0)}, "Drop2": {"loc": (0.1, -0.06, 0)}, "Drop3": {"loc": (0, -0.12, 0)}},
        7: {"Body": {"scale": (1.32, 1.32, 0.62), "rot": (0, 0, 4)}, "EyeL": {"loc": (-0.05, 0.02, -0.12), "scale": (0.8, 0.45, 1.0)},
            "EyeR": {"loc": (0.05, 0.0, -0.14), "scale": (0.75, 0.4, 1.0)}, "Crown": {"scale": (0.8, 0.8, 0.5), "rot": (-40, 30, 0)},
            "Drop1": {"loc": (-0.22, 0.05, 0)}, "Drop2": {"loc": (0.2, -0.1, 0)}, "Drop3": {"loc": (0.02, -0.22, 0)}},
        10: {"Body": {"scale": (1.48, 1.48, 0.42), "rot": (0, 0, -3)}, "EyeL": {"loc": (-0.08, 0.04, -0.17), "scale": (0.7, 0.35, 1.0)},
             "EyeR": {"loc": (0.08, 0.02, -0.19), "scale": (0.65, 0.3, 1.0)}, "Crown": {"scale": (0.6, 0.6, 0.3), "rot": (-60, 34, 0)},
             "Drop1": {"loc": (-0.32, 0.08, 0)}, "Drop2": {"loc": (0.3, -0.14, 0)}, "Drop3": {"loc": (0.04, -0.32, 0)}},
        13: {"Body": {"scale": (1.6, 1.6, 0.3)}, "EyeL": {"loc": (-0.1, 0.05, -0.2), "scale": (0.55, 0.3, 1.0)},
             "EyeR": {"loc": (0.1, 0.03, -0.22), "scale": (0.5, 0.25, 1.0)}, "Crown": {"scale": (0.4, 0.4, 0.2), "rot": (-70, 34, 0)}},
        16: {"Body": {"scale": (1.7, 1.7, 0.22)}, "EyeL": {"loc": (-0.12, 0.06, -0.24), "scale": (0.4, 0.2, 1.0)},
             "EyeR": {"loc": (0.12, 0.04, -0.25), "scale": (0.35, 0.18, 1.0)}, "Crown": {"scale": (0.25, 0.25, 0.15), "rot": (-75, 34, 0)},
             "Drop1": {"loc": (-0.4, 0.1, 0)}, "Drop2": {"loc": (0.38, -0.18, 0)}, "Drop3": {"loc": (0.05, -0.4, 0)}},
    }),
}
for name, (length, loop, frames) in anims.items():
    for f in frames.values():
        f.setdefault("Smear", HIDE)
    ik.bake_animation(name, parts, frames, length, loop)
smear.scale = (0.01, 0.01, 0.01)
ik.report("splotchet", parts)
ik.export_glb(out_glb, animated=True)
