"""Orimi, the folded-paper fox: rigid folded segments, no skin or bones.

    blender --background --factory-startup --python tools/blender/make_fox.py -- <out.glb> <paintmap.json>

About 1.15 m from snout to tail tip, facing Blender +Y (Godot -Z), paws on Z = 0.
Parts: Body (root) > Head > EarL, EarR; Body > LegFL, LegFR, LegBL, LegBR; Body > Tail1 > Tail2
> Tail3; Body > Cord > Bead; Body > Smear (the tail-swipe arc, scale 0 except on smear frames).
Materials: M_fox (paper), M_cord_sacred (cord), M_bead_sacred (bead); all share one atlas.
"""
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import inklib as ik  # noqa: E402

out_glb, out_map = ik.cli_args()[:2]
ik.reset()

# ---------------------------------------------------------------- parts
body = ik.make_object("Body", ik.loft([
    ik.ring_xz(-0.31, ik.roof(0.085, 0.06, 0.0, -0.06, -0.08)),
    ik.ring_xz(-0.21, ik.roof(0.165, 0.125, 0.03, -0.09, -0.13)),
    ik.ring_xz(-0.04, ik.roof(0.12, 0.095, 0.01, -0.07, -0.09)),
    ik.ring_xz(0.12, ik.roof(0.165, 0.13, 0.03, -0.11, -0.17)),
    ik.ring_xz(0.26, ik.roof(0.10, 0.16, 0.07, -0.04, -0.11)),
]), location=(0, 0, 0.42))

head = ik.make_object("Head", ik.loft([
    ik.ring_xz(-0.05, ik.roof(0.085, 0.085, 0.0, -0.05, -0.08)),
    ik.ring_xz(0.04, ik.roof(0.14, 0.105, 0.0, -0.05, -0.085)),
    ik.ring_xz(0.14, ik.roof(0.07, 0.05, -0.02, -0.05, -0.065)),
    [(0.0, 0.27, -0.04)],
]), parent=body, location=(0, 0.28, 0.18), rotation_deg=(-6, 0, 0))

EAR_TIP = (0.0, -0.016, 0.21)


def ear_geo():
    base = [(-0.058, 0.016, 0.0), (0.0, -0.006, 0.0), (0.058, 0.016, 0.0), (0.0, -0.042, 0.0)]
    return ik.loft([base, [EAR_TIP]], cap_start=True)


ear_l = ik.make_object("EarL", ear_geo(), parent=head, location=(-0.068, -0.005, 0.075), rotation_deg=(-10, 0, 24))
ear_r = ik.make_object("EarR", ear_geo(), parent=head, location=(0.068, -0.005, 0.075), rotation_deg=(-10, 0, -24))


def leg_geo(back):
    hock = -0.04 if back else 0.0
    top = 0.075 if back else 0.06
    return ik.loft([
        ik.ring_xy(0.0, [(0.0, top), (-0.05, 0.0), (0.0, -top), (0.05, 0.0)]),
        ik.ring_xy(-0.17, [(0.0, 0.036 + hock), (-0.034, hock), (0.0, -0.036 + hock), (0.034, hock)]),
        ik.ring_xy(-0.29, [(0.0, 0.03), (-0.027, 0.0), (0.0, -0.03), (0.027, 0.0)]),
        ik.ring_xy(-0.325, [(0.0, 0.072), (-0.04, 0.014), (0.0, -0.032), (0.04, 0.014)]),
        ik.ring_xy(-0.35, [(0.0, 0.066), (-0.036, 0.014), (0.0, -0.028), (0.036, 0.014)]),
    ])


legs = [
    ik.make_object("LegFL", leg_geo(False), parent=body, location=(-0.095, 0.14, -0.07), rotation_deg=(0, -4, 0)),
    ik.make_object("LegFR", leg_geo(False), parent=body, location=(0.095, 0.14, -0.07), rotation_deg=(0, 4, 0)),
    ik.make_object("LegBL", leg_geo(True), parent=body, location=(-0.11, -0.2, -0.07), rotation_deg=(0, -5, 0)),
    ik.make_object("LegBR", leg_geo(True), parent=body, location=(0.11, -0.2, -0.07), rotation_deg=(0, 5, 0)),
]

# The tail is a broad folded plume that rises and sweeps to the fox's right, so the camera
# behind sees the haunches, back and head beside it instead of a sliver behind a tail.
tail1 = ik.make_object("Tail1", ik.loft([
    ik.ring_xz(0.0, ik.roof(0.05, 0.045, 0.0, -0.035, -0.045)),
    ik.ring_xz(-0.2, ik.roof(0.11, 0.085, 0.0, -0.06, -0.08)),
]), parent=body, location=(0, -0.29, 0.06), rotation_deg=(-22, 0, 28))
tail2 = ik.make_object("Tail2", ik.loft([
    ik.ring_xz(0.0, ik.roof(0.11, 0.085, 0.0, -0.06, -0.08)),
    ik.ring_xz(-0.11, ik.roof(0.15, 0.10, 0.0, -0.07, -0.095)),
    ik.ring_xz(-0.21, ik.roof(0.13, 0.09, 0.0, -0.06, -0.085)),
]), parent=tail1, location=(0, -0.2, 0), rotation_deg=(-16, 0, 14))
tail3 = ik.make_object("Tail3", ik.loft([
    ik.ring_xz(0.0, ik.roof(0.13, 0.09, 0.0, -0.06, -0.085)),
    ik.ring_xz(-0.09, ik.roof(0.10, 0.075, 0.0, -0.05, -0.07)),
    [(0.0, -0.21, 0.04)],
]), parent=tail2, location=(0, -0.21, 0), rotation_deg=(-24, 0, 12))


def torus(R1, R2, rz, seg=10, sides=4):
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        cx, cz = math.cos(a), math.sin(a)
        for j in range(sides):
            b = 2 * math.pi * j / sides + math.pi / 4
            r = R1 + R2 * math.cos(b)
            verts.append((cx * r, R2 * math.sin(b), cz * (rz + R2 * math.cos(b))))
    for i in range(seg):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            c, d = ((i + 1) % seg) * sides + (j + 1) % sides, ((i + 1) % seg) * sides + j
            faces.append((a, b, c, d))
    return verts, faces


def ico(r):
    t = (1 + 5 ** 0.5) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
         (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
         (8, 6, 7), (9, 8, 1)]
    n = (1 + t * t) ** 0.5
    return [(x / n * r, y / n * r, z / n * r) for x, y, z in v], f


def ribbon(points, w0, w1, lift=0.012):
    """A flat cord end: a thin strip along points, wide w0 at the knot, w1 at the frayed end."""
    verts, faces = [], []
    n = len(points)
    for i, (x, y, z) in enumerate(points):
        w = w0 + (w1 - w0) * i / (n - 1)
        verts += [(x - w, y, z), (x + w, y, z), (x + w * 0.2, y, z + lift)]
    for i in range(n - 1):
        a, b = 3 * i, 3 * (i + 1)
        faces += [(a, b, b + 2, a + 2), (a + 2, b + 2, b + 1, a + 1), (a + 1, b + 1, b, a)]
    return verts, faces


# The cord is a collar round the neck, knotted on the nape with two ends trailing over the
# shoulders, so it reads from the gameplay camera behind and above.
collar = ik.transformed(torus(0.095, 0.017, 0.085, 12, 4), rotation_deg=(30, 0, 0))
knot = ik.transformed(torus(0.03, 0.014, 0.024, 8, 4), location=(0, -0.01, 0.105), rotation_deg=(0, 0, 90))
end_l = ribbon([(-0.02, -0.03, 0.10), (-0.06, -0.10, 0.08), (-0.085, -0.17, 0.05), (-0.11, -0.24, 0.035)], 0.02, 0.012)
end_r = ribbon([(0.02, -0.03, 0.10), (0.05, -0.11, 0.085), (0.075, -0.19, 0.06), (0.09, -0.27, 0.05)], 0.02, 0.012)
cord = ik.make_object("Cord", ik.merged(collar, knot, end_l, end_r), parent=body, location=(0, 0.25, 0.1))
bead = ik.make_object("Bead", ico(0.032), parent=cord, location=(0, -0.035, 0.128))


def smear_geo():
    verts, faces = [], []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        a = math.radians(-70 + 140 * t)
        r = 0.62
        w = 0.13 * math.sin(math.pi * min(1.0, t * 1.15)) + 0.004
        x, y = math.sin(a) * r, -math.cos(a) * r
        verts.append((x, y, 0.02 + w))
        verts.append((x * 0.82, y * 0.82, -0.04))
    for i in range(n - 1):
        a, b, c, d = 2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2
        faces.append((a, b, c, d))
    return verts, faces


smear = ik.make_object("Smear", smear_geo(), parent=body, location=(0, 0, 0.06))

parts = [body, head, ear_l, ear_r] + legs + [tail1, tail2, tail3, cord, bead, smear]

# ---------------------------------------------------------------- tags, materials, colours
ik.bpy.context.view_layer.update()
for o in parts:
    ik.set_tags(o, "paper")
for ear in (ear_l, ear_r):
    ik.tag_faces(ear, lambda c, n, o: "ash" if (o.matrix_world.inverted() @ c).z > 0.12 else "paper")
for leg in legs:
    ik.tag_faces(leg, lambda c, n, o: "ash" if c.z < 0.075 else "paper")
ik.set_tags(cord, "cord")
ik.set_tags(bead, "bead")
ik.set_tags(smear, "smear")

for o in parts:
    ik.assign_material(o, "M_fox")
ik.assign_material(cord, "M_cord_sacred")
ik.assign_material(bead, "M_bead_sacred")

mw = lambda o, p: tuple(o.matrix_world @ ik.Vector(p))  # noqa: E731
strokes = {
    "Body": [[(mw(body, (0, -0.31, 0)), 0.85), (mw(body, (0, 0.0, 0)), 1.0), (mw(body, (0, 0.26, 0)), 0.95)]],
    "Head": [[(mw(head, (0, -0.05, 0)), 1.0), (mw(head, (0, 0.12, -0.02)), 0.8), (mw(head, (0, 0.27, -0.04)), 0.12)]],
    "Tail1": [[(mw(tail1, (0, 0, 0)), 0.55), (mw(tail1, (0, -0.2, 0)), 0.9)]],
    "Tail2": [[(mw(tail2, (0, 0, 0)), 0.9), (mw(tail2, (0, -0.11, 0)), 1.0), (mw(tail2, (0, -0.21, 0)), 0.85)]],
    "Tail3": [[(mw(tail3, (0, 0, 0)), 0.85), (mw(tail3, (0, -0.21, 0.04)), 0.05)]],
}
for ear in (ear_l, ear_r):
    strokes[ear.name] = [[(mw(ear, (0, 0, 0)), 0.9), (mw(ear, EAR_TIP), 0.05)]]
for leg in legs:
    strokes[leg.name] = [[(mw(leg, (0, 0, 0)), 1.0), (mw(leg, (0, 0, -0.29)), 0.3), (mw(leg, (0, 0.03, -0.35)), 0.45)]]
tapers = {name: ik.chain_taper(chains) for name, chains in strokes.items()}


def fox_colors(co, local, n, tag, taper):
    if tag == "smear":
        return (0.0, 0.0, 1.0)
    if tag in ("cord", "bead"):
        return (0.45, 0.0, 0.2)
    r = taper(co)
    belly = 1.0 if n.z < -0.4 else 0.85
    g = 0.0
    if co.y < -0.45:
        g = ik.smoothstep(-0.45, -0.7, co.y) * 0.45
    if co.z > 0.68:
        g = max(g, 0.12)
    b = 0.15 + 0.7 * (1.0 - r) + 0.15 * ik.hash01(co.x * 7.0, co.y * 9.0, co.z * 5.0)
    return (r * belly, g, b)


for o in parts:
    taper = tapers.get(o.name, lambda co: 1.0)
    ik.paint_vertex_colors(o, lambda co, local, n, tag, taper=taper: fox_colors(co, local, n, tag, taper))

ik.smart_uv(parts, angle=35.0, margin=0.012)
ik.dump_paint_map(parts, out_map, 1024, crease_deg=16.0)

# ---------------------------------------------------------------- animations (12 fps, stepped)
ik.store_rest(parts)
L = {"Body", "Head", "EarL", "EarR", "LegFL", "LegFR", "LegBL", "LegBR", "Tail1", "Tail2", "Tail3", "Smear"}
anim_parts = [o for o in parts if o.name in L]
HIDE = {"scale": 0.01}


def with_smear_hidden(frames):
    for f in frames.values():
        f.setdefault("Smear", HIDE)
    return frames


def legs_pose(fl, fr, bl, br):
    return {"LegFL": {"rot": (fl, 0, 0)}, "LegFR": {"rot": (fr, 0, 0)},
            "LegBL": {"rot": (bl, 0, 0)}, "LegBR": {"rot": (br, 0, 0)}}


def merge(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


anims = {}

anims["idle"] = (24, True, {
    0: {},
    6: {"Body": {"loc": (0, 0, 0.006)}, "Head": {"rot": (3, 0, 4)}, "Tail2": {"rot": (0, 0, 6)}, "Tail3": {"rot": (0, 0, 8)}},
    12: {"Body": {"loc": (0, 0, 0.008)}, "Head": {"rot": (2, 0, 2)}, "Tail2": {"rot": (0, 0, 2)}, "Tail3": {"rot": (0, 0, -4)}},
    16: {"EarR": {"rot": (-14, 0, -8)}},
    18: {"Body": {"loc": (0, 0, 0.004)}, "Head": {"rot": (0, 0, -3)}, "EarR": {}, "Tail2": {"rot": (0, 0, -5)}, "Tail3": {"rot": (0, 0, -9)}},
})

run_frames = {}
cycle = [(38, 30, -34, -24, 0.03, -5), (14, 4, -12, -2, 0.05, 2), (-30, -38, 24, 34, 0.02, 6), (-10, -18, 40, 30, -0.01, 1)]
for i, (fl, fr, bl, br, dz, pitch) in enumerate(cycle * 2):
    run_frames[i] = merge(legs_pose(fl, fr, bl, br), {
        "Body": {"loc": (0, 0, dz * (0.8 if i >= 4 else 1.0)), "rot": (pitch, 0, 0)},
        "Head": {"rot": (-pitch * 0.8 + 4, 0, 0)},
        "Tail1": {"rot": (-24 + (i % 2) * 6, 0, (4 if i % 4 < 2 else -4))},
        "Tail2": {"rot": (-6, 0, (-6 if i % 4 < 2 else 6))},
        "Tail3": {"rot": (-4, 0, (-8 if i % 4 < 2 else 8))},
        "EarL": {"rot": (-18, 0, 0)}, "EarR": {"rot": (-18, 0, 0)},
    })
anims["run"] = (8, True, run_frames)

anims["jump"] = (6, False, {
    0: merge(legs_pose(20, 20, -30, -30), {"Body": {"loc": (0, 0, -0.06), "rot": (-6, 0, 0)}, "Tail1": {"rot": (-10, 0, 0)}}),
    2: merge(legs_pose(-35, -30, 45, 40), {"Body": {"loc": (0, 0, 0.04), "rot": (16, 0, 0)}, "Head": {"rot": (-8, 0, 0)},
                                           "Tail1": {"rot": (-30, 0, 0)}, "Tail2": {"rot": (-10, 0, 0)},
                                           "EarL": {"rot": (-25, 0, 0)}, "EarR": {"rot": (-25, 0, 0)}}),
    4: merge(legs_pose(-20, -16, 30, 26), {"Body": {"loc": (0, 0, 0.04), "rot": (8, 0, 0)}, "Tail1": {"rot": (-20, 0, 0)},
                                           "EarL": {"rot": (-20, 0, 0)}, "EarR": {"rot": (-20, 0, 0)}}),
})

anims["fall"] = (4, True, {
    0: merge(legs_pose(34, 28, -26, -20), {"Body": {"rot": (-10, 0, 0)}, "Head": {"rot": (8, 0, 0)},
                                           "Tail1": {"rot": (10, 0, 0)}, "Tail2": {"rot": (8, 0, 0)},
                                           "EarL": {"rot": (-30, 0, 6)}, "EarR": {"rot": (-30, 0, -6)}}),
    2: merge(legs_pose(30, 34, -20, -26), {"Body": {"rot": (-9, 0, 0)}, "Head": {"rot": (6, 0, 0)},
                                           "Tail1": {"rot": (14, 0, 0)}, "Tail2": {"rot": (4, 0, 0)},
                                           "EarL": {"rot": (-34, 0, 6)}, "EarR": {"rot": (-34, 0, -6)}}),
})

anims["land"] = (6, False, {
    0: merge(legs_pose(24, 24, -24, -24), {"Body": {"loc": (0, 0, -0.08), "rot": (-4, 0, 0)}, "Head": {"rot": (-10, 0, 0)},
                                           "Tail1": {"rot": (-14, 0, 0)}, "EarL": {"rot": (14, 0, 0)}, "EarR": {"rot": (14, 0, 0)}}),
    2: merge(legs_pose(10, 10, -10, -10), {"Body": {"loc": (0, 0, -0.03)}, "Head": {"rot": (-4, 0, 0)}}),
    4: {},
})

anims["attack_1"] = (8, False, {
    0: merge(legs_pose(10, -6, -8, 6), {"Body": {"rot": (0, 0, 24), "loc": (0, 0, -0.02)}, "Tail1": {"rot": (0, 0, 30)},
                                        "Tail2": {"rot": (0, 0, 18)}, "Head": {"rot": (0, 0, -16)}}),
    1: merge(legs_pose(14, -10, -12, 8), {"Body": {"rot": (0, 0, 34), "loc": (0, 0, -0.03)}, "Tail1": {"rot": (0, 0, 40)},
                                          "Tail2": {"rot": (0, 0, 24)}, "Tail3": {"rot": (0, 0, 16)}, "Head": {"rot": (0, 0, -22)}}),
    2: merge(legs_pose(-12, 12, 14, -10), {"Body": {"rot": (0, 0, -40), "loc": (0, 0, 0.01)}, "Tail1": {"rot": (-10, 0, -60)},
                                           "Tail2": {"rot": (0, 0, -30)}, "Tail3": {"rot": (0, 0, -20)}, "Head": {"rot": (0, 0, 24)},
                                           "Smear": {"rot": (0, 0, 20), "scale": (1.0, 1.0, 1.0)}}),
    3: merge(legs_pose(-8, 8, 10, -8), {"Body": {"rot": (0, 0, -62)}, "Tail1": {"rot": (-6, 0, -40)},
                                        "Tail2": {"rot": (0, 0, -20)}, "Tail3": {"rot": (0, 0, -10)}, "Head": {"rot": (0, 0, 30)},
                                        "Smear": {"rot": (0, 0, -20), "scale": (1.1, 1.1, 0.8)}}),
    4: merge(legs_pose(-4, 4, 6, -4), {"Body": {"rot": (0, 0, -50)}, "Tail1": {"rot": (0, 0, -20)}, "Head": {"rot": (0, 0, 22)}}),
    6: merge(legs_pose(0, 0, 0, 0), {"Body": {"rot": (0, 0, -16)}, "Tail1": {"rot": (0, 0, -6)}, "Head": {"rot": (0, 0, 6)}}),
})

spin = {}
yaws = [0, -20, -90, -170, -250, -320, -360, -360]
for i, yaw in enumerate(yaws):
    pose = {"Body": {"rot": (0, 0, yaw), "loc": (0, 0, 0.05 if 2 <= i <= 5 else 0.0)},
            "Tail1": {"rot": (-20, 0, 26 if 2 <= i <= 5 else 0)}, "Tail2": {"rot": (-6, 0, 12 if 2 <= i <= 5 else 0)}}
    if 2 <= i <= 5:
        pose.update(legs_pose(-22, -22, 22, 22))
        pose["EarL"] = {"rot": (-26, 0, 0)}
        pose["EarR"] = {"rot": (-26, 0, 0)}
    if i in (3, 4):
        pose["Smear"] = {"rot": (0, 0, 40 if i == 3 else 60), "scale": (1.15, 1.15, 0.9)}
    spin[i] = pose
spin[0] = merge(legs_pose(16, 16, -16, -16), {"Body": {"loc": (0, 0, -0.04)}, "Tail1": {"rot": (-8, 0, -20)}})
spin[8] = {"Body": {"rot": (0, 0, -360)}}
anims["attack_2"] = (10, False, spin)

anims["hurt"] = (6, False, {
    0: merge(legs_pose(-16, -16, 18, 18), {"Body": {"loc": (0, -0.08, 0.03), "rot": (16, 0, 8)}, "Head": {"rot": (14, 0, -10)},
                                           "EarL": {"rot": (-50, 0, 10)}, "EarR": {"rot": (-50, 0, -10)},
                                           "Tail1": {"rot": (-20, 0, 0)}}),
    2: merge(legs_pose(-6, -6, 8, 8), {"Body": {"loc": (0, -0.05, 0.01), "rot": (8, 0, 4)}, "Head": {"rot": (6, 0, -4)},
                                       "EarL": {"rot": (-30, 0, 6)}, "EarR": {"rot": (-30, 0, -6)}}),
    4: {"Body": {"loc": (0, -0.02, 0.0)}},
})

sit = merge(legs_pose(-6, -6, 70, 70), {"Body": {"loc": (0, -0.06, -0.02), "rot": (26, 0, 0)}, "Head": {"rot": (-24, 0, 0)},
                                        "Tail1": {"rot": (-40, 0, 55)}, "Tail2": {"rot": (-8, 0, 30)}, "Tail3": {"rot": (0, 0, 24)},
                                        "EarL": {"rot": (8, 0, 0)}, "EarR": {"rot": (8, 0, 0)}})
sit2 = merge(sit, {"Body": {"loc": (0, -0.06, -0.012), "rot": (27, 0, 0)}, "Tail3": {"rot": (0, 0, 30)}})
anims["brush_pose"] = (12, True, {0: sit, 6: sit2})

for name, (length, loop, frames) in anims.items():
    ik.bake_animation(name, anim_parts, with_smear_hidden(frames), length, loop)

smear.scale = (0.01, 0.01, 0.01)
ik.report("fox", parts)
ik.export_glb(out_glb, animated=True)
print("EXPORTED", out_glb)
