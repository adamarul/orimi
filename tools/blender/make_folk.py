"""Paper folk: one person of a cast spec as a glb, in Orimi's folded-paper language.

    blender --background --factory-startup --python tools/blender/make_folk.py -- <spec.json> <name> <out.glb> <paintmap.json>

Rigid folded segments, no skin or bones: Body (root, pivot at the hips, carries the torso,
garment skirt and sash) > Head (> Hat), ArmL, ArmR (> Prop in the right hand), LegL, LegR.
Faces are a single nose fold. Facing Blender +Y (Godot -Z), feet on Z = 0.
Stepped animations at 12 fps: idle, talk, walk, and faded (a still, bowed, stiff pose).
One material, M_folk_<name>, over one painted atlas; tools/textures/painted/paint_folk.py
paints a woken and a faded version of it. Style data and the spec format: folk_style.py.
"""
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import folk_style as FS  # noqa: E402
import inklib as ik  # noqa: E402

spec_path, name, out_glb, out_map = ik.cli_args()[:4]
P = FS.person(FS.load(spec_path), name)
D, B = P["dims"], P["width"]
ik.reset()

leg, head_h, arm = D["leg"], D["head"], D["arm"]
torso = D["height"] - leg - head_h - 0.04
sh, hip, dep = D["shoulder"] * B, D["hip"] * B, D["depth"] * B


def fold(w, d, front=0.25):
    """Folded-paper cross-section in the XY plane: a ridge down the front, a softer fold behind."""
    return [(0.0, d), (-w * 0.75, d * front + d * 0.45), (-w, 0.0), (-w * 0.8, -d * 0.75), (0.0, -d),
            (w * 0.8, -d * 0.75), (w, 0.0), (w * 0.75, d * front + d * 0.45)]


# ---------------------------------------------------------------- body: torso, skirt, sash
torso_vf = ik.loft([
    ik.ring_xy(0.0, fold(hip * 0.95, dep)),
    ik.ring_xy(torso * 0.42, fold(hip * 0.9, dep * 0.95)),
    ik.ring_xy(torso * 0.8, fold(sh * 0.92, dep * 1.08)),
    ik.ring_xy(torso * 0.96, fold(sh, dep * 0.9)),
    ik.ring_xy(torso * 1.02, fold(0.055 * (1.0 if P["size"] != "child" else 0.8), 0.05)),
])
skirt_len = {"robe": leg - 0.07, "tunic": leg * 0.42, "apron": leg * 0.42}[P["garment"]]
flare = {"robe": 1.45, "tunic": 1.25, "apron": 1.22}[P["garment"]]
skirt_vf = ik.loft([
    ik.ring_xy(0.06, fold(hip * 1.0, dep * 1.02)),
    ik.ring_xy(-skirt_len * 0.5, fold(hip * (1 + (flare - 1) * 0.55), dep * (1 + (flare - 1) * 0.4))),
    ik.ring_xy(-skirt_len, fold(hip * flare, dep * (1 + (flare - 1) * 0.6))),
])
sash_vf = ik.loft([ik.ring_xy(0.02, fold(hip * 1.04, dep * 1.06)), ik.ring_xy(0.09, fold(hip * 1.0, dep * 1.03))])
parts_vf = [torso_vf, skirt_vf, sash_vf]
if P["garment"] == "apron":
    a_w, a_y = hip * 0.75, dep * 1.12 + 0.012
    apron = ([(-a_w, a_y, 0.05), (a_w, a_y, 0.05), (a_w * 1.15, a_y + 0.05, -leg * 0.62), (-a_w * 1.15, a_y + 0.05, -leg * 0.62),
              (-a_w, a_y - 0.012, 0.05), (a_w, a_y - 0.012, 0.05), (a_w * 1.15, a_y + 0.038, -leg * 0.62), (-a_w * 1.15, a_y + 0.038, -leg * 0.62)],
             [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    parts_vf.append(apron)
body = ik.make_object("Body", ik.merged(*parts_vf), location=(0, 0, leg), rotation_deg=(D["stoop"], 0, 0))
n_torso, n_skirt, n_sash = len(torso_vf[1]), len(skirt_vf[1]), len(sash_vf[1])

# ---------------------------------------------------------------- head with a nose fold
hw, hd = head_h * 0.38, head_h * 0.42
head_vf = ik.loft([
    ik.ring_xy(0.0, fold(0.05, 0.045)),
    ik.ring_xy(head_h * 0.18, fold(hw * 0.78, hd * 0.8)),
    ik.ring_xy(head_h * 0.5, fold(hw, hd)),
    ik.ring_xy(head_h * 0.82, fold(hw * 0.86, hd * 0.9)),
    [(0.0, -hd * 0.12, head_h)],
])
nz = head_h * 0.5
nose_vf = ([(-0.022, hd * 0.92, nz + 0.02), (0.022, hd * 0.92, nz + 0.02), (0.0, hd * 0.9, nz - 0.045), (0.0, hd + 0.035, nz - 0.03)],
           [(0, 1, 3), (1, 2, 3), (2, 0, 3), (0, 2, 1)])
head = ik.make_object("Head", ik.merged(head_vf, nose_vf), parent=body, location=(0, 0, torso * 1.0),
                      rotation_deg=(-D["stoop"] * 0.6, 0, 0))

# ---------------------------------------------------------------- arms and legs


def arm_geo():
    sleeve = ik.loft([
        ik.ring_xy(0.02, fold(0.05 * B ** 0.5, 0.055 * B ** 0.5)),
        ik.ring_xy(-arm * 0.5, fold(0.052 * B ** 0.5, 0.058 * B ** 0.5)),
        ik.ring_xy(-arm * 0.8, fold(0.07 * B ** 0.5, 0.072 * B ** 0.5)),
    ])
    hand = ik.loft([
        ik.ring_xy(-arm * 0.76, fold(0.03, 0.03)),
        ik.ring_xy(-arm * 0.93, fold(0.036, 0.024)),
        [(0.0, 0.01, -arm)],
    ])
    return sleeve, hand


arms, hands_faces = [], []
for side, nm in ((-1, "ArmL"), (1, "ArmR")):
    sleeve, hand = arm_geo()
    a = ik.make_object(nm, ik.merged(sleeve, hand), parent=body, location=(side * (sh + 0.025), 0, torso * 0.94),
                       rotation_deg=(0, side * -6, 0))
    arms.append(a)
    hands_faces.append(len(sleeve[1]))


def leg_geo():
    w = 0.058 * B ** 0.5
    shin = ik.loft([
        ik.ring_xy(0.0, fold(w, w * 1.1)),
        ik.ring_xy(-leg * 0.5, fold(w * 0.85, w * 0.95)),
        ik.ring_xy(-leg + 0.07, fold(w * 0.7, w * 0.8)),
    ])
    foot_len = 0.11 if P["size"] != "child" else 0.08
    foot = ik.loft([
        ik.ring_xy(-leg + 0.075, [(-w * 0.8, -w * 0.8), (w * 0.8, -w * 0.8), (w * 0.8, w * 0.6), (-w * 0.8, w * 0.6)]),
        ik.ring_xy(-leg + 0.0, [(-w * 0.9, -w * 0.9), (w * 0.9, -w * 0.9), (w * 0.75, w + foot_len), (-w * 0.75, w + foot_len)]),
    ])
    return shin, foot


legs, feet_faces = [], []
for side, nm in ((-1, "LegL"), (1, "LegR")):
    shin, foot = leg_geo()
    lg = ik.make_object(nm, ik.merged(shin, foot), parent=body, location=(side * hip * 0.52, 0, 0),
                        rotation_deg=(-D["stoop"], 0, 0))
    legs.append(lg)
    feet_faces.append(len(shin[1]))

# ---------------------------------------------------------------- hat


def hat_geo(kind):
    z0 = head_h * 0.72
    if kind == "paper_boat":
        a, t, h = hw * 1.75, hd * 0.55, head_h * 0.78
        front = [(-a, t, z0), (a, t, z0), (0.0, t * 0.25, z0 + h)]
        back = [(-a, -t, z0), (a, -t, z0), (0.0, -t * 0.25, z0 + h)]
        cuff_f = [(-a * 0.92, t + 0.03, z0 - 0.01), (a * 0.92, t + 0.03, z0 - 0.01), (a * 0.78, t + 0.02, z0 + h * 0.3), (-a * 0.78, t + 0.02, z0 + h * 0.3)]
        cuff_b = [(x, -y, z) for x, y, z in cuff_f]
        verts = front + back + cuff_f + cuff_b
        faces = [(0, 1, 2), (5, 4, 3), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1),
                 (6, 7, 8, 9), (13, 12, 11, 10)]
        return verts, faces
    if kind == "wide_brim":
        n = 10
        r_out, r_in = hw * 2.6, hw * 1.05
        rings = [[(math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r, z) for k in range(n)]
                 for r, z in ((r_out, z0 + 0.0), (r_in, z0 + 0.05), (r_in * 0.55, z0 + head_h * 0.55))]
        return ik.loft(rings + [[(0.0, 0.0, z0 + head_h * 0.62)]])
    if kind == "scarf":
        shell = ik.loft([
            ik.ring_xy(head_h * 0.3, fold(hw * 1.1, hd * 1.08)),
            ik.ring_xy(head_h * 0.62, fold(hw * 1.12, hd * 1.1)),
            ik.ring_xy(head_h * 0.9, fold(hw * 0.95, hd * 0.95)),
            [(0.0, -hd * 0.15, head_h * 1.06)],
        ])
        tail = ik.tube([(0.0, -hd * 1.0, head_h * 0.3), (0.03, -hd * 1.25, head_h * 0.05), (0.06, -hd * 1.3, -head_h * 0.25)], [0.035, 0.03, 0.0], 3)
        return ik.merged(shell, tail)
    if kind == "cap":
        return ik.loft([
            ik.ring_xy(head_h * 0.68, fold(hw * 1.07, hd * 1.07)),
            ik.ring_xy(head_h * 0.92, fold(hw * 0.9, hd * 0.9)),
            [(0.0, 0.0, head_h * 1.04)],
        ])
    return None


hat = None
hat_vf = hat_geo(P["hat"])
if hat_vf:
    hat = ik.make_object("Hat", hat_vf, parent=head)

# ---------------------------------------------------------------- prop, held in the right hand


def prop_geo(kind):
    hz = -arm * 0.9
    if kind == "pole":
        return ik.tube([(0.0, 0.02, hz + 1.25 * D["height"] / 1.66), (0.0, 0.02, hz - 0.95 * D["height"] / 1.66)], [0.024, 0.02], 5), []
    if kind == "lantern":
        cord = ik.tube([(0.0, 0.0, hz), (0.0, 0.0, hz - 0.09)], [0.008, 0.008], 3)
        z1, z2 = hz - 0.09, hz - 0.33
        body_vf = ik.loft([
            ik.ring_xy(z1, [(math.cos(k * math.pi / 3) * 0.05, math.sin(k * math.pi / 3) * 0.05) for k in range(6)]),
            ik.ring_xy((z1 + z2) / 2, [(math.cos(k * math.pi / 3) * 0.09, math.sin(k * math.pi / 3) * 0.09) for k in range(6)]),
            ik.ring_xy(z2, [(math.cos(k * math.pi / 3) * 0.055, math.sin(k * math.pi / 3) * 0.055) for k in range(6)]),
        ])
        return ik.merged(cord, body_vf), [len(cord[1])]
    if kind in ("bucket", "basket"):
        r = 0.12 if kind == "bucket" else 0.17
        depth = 0.2 if kind == "bucket" else 0.12
        z1 = hz - 0.16
        n = 8
        tub = ik.loft([
            [(math.cos(2 * math.pi * k / n) * r, math.sin(2 * math.pi * k / n) * r, z1) for k in range(n)],
            [(math.cos(2 * math.pi * k / n) * r * 0.85, math.sin(2 * math.pi * k / n) * r * 0.85, z1 - depth) for k in range(n)],
        ])
        handle = ik.tube([(-r * 0.9, 0.0, z1), (-r * 0.5, 0.0, hz + 0.01), (r * 0.5, 0.0, hz + 0.01), (r * 0.9, 0.0, z1)], [0.01] * 4, 3, cap=False)
        return ik.merged(tub, handle), []
    if kind == "scroll":
        return ik.tube([(-0.2, 0.05, hz + 0.02), (0.2, 0.05, hz + 0.02)], [0.035, 0.035], 6), []
    return None, []


prop = None
prop_vf, prop_split = prop_geo(P["prop"])
if prop_vf:
    prop = ik.make_object("Prop", prop_vf, parent=arms[1])

parts = [body, head, arms[0], arms[1], legs[0], legs[1]] + [o for o in (hat, prop) if o]
ik.bpy.context.view_layer.update()

# ---------------------------------------------------------------- tags, material, vertex colours


def index_tags(obj, ranges):
    """Tag faces by index ranges: ranges is [(count, tag), ...] in face order, the rest keeps the last."""
    tags = []
    for count, tag in ranges:
        tags += [tag] * count
    tags += [ranges[-1][1]] * (len(obj.data.polygons) - len(tags))
    obj["paint_tags"] = tags[:len(obj.data.polygons)]


skirt_tag = "garment"
body_ranges = [(n_torso, "garment"), (n_skirt, skirt_tag), (n_sash, "trim")]
if P["garment"] == "apron":
    body_ranges.append((6, "trim"))
index_tags(body, body_ranges)
for a, nf in zip(arms, hands_faces):
    index_tags(a, [(nf, "garment"), (999, "skin")])
for lg, nf in zip(legs, feet_faces):
    index_tags(lg, [(nf, "legs"), (999, "shoe")])
hair_back = P["hat"] not in ("scarf", "cap")
ik.tag_faces(head, lambda c, n, o: "hair" if hair_back and (n.y < -0.3 or ((o.matrix_world.inverted() @ c).z > head_h * 0.78 and n.y < 0.2)) else "skin")
if hat:
    ik.set_tags(hat, "hat")
if prop:
    if P["prop"] == "lantern":
        index_tags(prop, [(prop_split[0], "prop"), (999, "lamp")])
    else:
        ik.set_tags(prop, "prop")

for o in parts:
    ik.assign_material(o, P["material"])

mw = lambda o, p: tuple(o.matrix_world @ ik.Vector(p))  # noqa: E731
tapers = {}
for a in arms:
    tapers[a.name] = ik.chain_taper([[(mw(a, (0, 0, 0)), 0.9), (mw(a, (0, 0, -arm * 0.8)), 0.6), (mw(a, (0, 0, -arm)), 0.3)]])
for lg in legs:
    tapers[lg.name] = ik.chain_taper([[(mw(lg, (0, 0, 0)), 1.0), (mw(lg, (0, 0, -leg)), 0.55)]])
if hat and P["hat"] == "paper_boat":
    tapers["Hat"] = lambda co: 1.0
if prop and P["prop"] == "pole":
    top, bottom = mw(prop, prop_vf[0][0]), mw(prop, prop_vf[0][-1])
    tapers["Prop"] = ik.chain_taper([[(top, 0.25), (mw(arms[1], (0, 0, -arm * 0.9)), 0.7), (bottom, 0.35)]])


def colours(taper):
    def fn(co, local, n, tag):
        r = taper(co) * (0.8 if tag in ("skin", "hair") else 1.0)
        return (r, 0.0, 0.2 + 0.5 * (1.0 - r) + 0.15 * ik.hash01(co.x * 9.0, co.y * 7.0, co.z * 5.0))
    return fn


for o in parts:
    ik.paint_vertex_colors(o, colours(tapers.get(o.name, lambda co: 0.95)))

ik.smart_uv(parts, angle=40.0, margin=0.014)
ik.dump_paint_map(parts, out_map, P["texture_size"], crease_deg=22.0)

# ---------------------------------------------------------------- animations (12 fps, stepped)
ik.store_rest(parts)
L = {"Body", "Head", "ArmL", "ArmR", "LegL", "LegR"}
anim_parts = [o for o in parts if o.name in L]
lift = 0.02 if P["size"] == "child" else 0.012
bob = 0.03 if P["size"] == "child" else 0.02
elder = P["size"] == "elder"
stride = 18 if elder else (30 if P["size"] == "child" else 24)
anims = {}
anims["idle"] = (24, True, {
    0: {},
    6: {"Body": {"loc": (0, 0, lift * 0.4)}, "Head": {"rot": (2, 0, 4)}, "ArmL": {"rot": (2, 0, 0)}, "ArmR": {"rot": (2, 0, 0)}},
    12: {"Body": {"loc": (0, 0, lift * 0.6)}, "Head": {"rot": (1, 0, 9)}},
    18: {"Body": {"loc": (0, 0, lift * 0.2)}, "Head": {"rot": (-2, 0, 2)}, "ArmR": {"rot": (4, 0, 0)}},
})
anims["talk"] = (16, True, {
    0: {"Head": {"rot": (-6, 0, 0)}, "ArmR": {"rot": (34, 0, 8)}},
    2: {"Head": {"rot": (4, 0, 3)}, "ArmR": {"rot": (48, 0, 14)}, "Body": {"rot": (0, 0, 3)}},
    4: {"Head": {"rot": (-4, 0, -2)}, "ArmR": {"rot": (40, 0, 4)}, "ArmL": {"rot": (10, 0, 0)}},
    8: {"Head": {"rot": (6, 0, 0)}, "ArmR": {"rot": (22, 0, -4)}, "ArmL": {"rot": (16, 0, -6)}, "Body": {"rot": (0, 0, -2)}},
    12: {"Head": {"rot": (-3, 0, 5)}, "ArmR": {"rot": (30, 0, 10)}, "ArmL": {"rot": (6, 0, 0)}},
})
walk = {}
for i in range(8):
    s = math.sin(2 * math.pi * i / 8)
    walk[i] = {"LegL": {"rot": (stride * s, 0, 0)}, "LegR": {"rot": (-stride * s, 0, 0)},
               "ArmL": {"rot": (-stride * 0.7 * s, 0, 0)}, "ArmR": {"rot": (stride * 0.7 * s, 0, 0)},
               "Body": {"loc": (0, 0, bob * abs(math.cos(2 * math.pi * i / 8))), "rot": (-3, 0, 3 * s)},
               "Head": {"rot": (2, 0, -2 * s)}}
anims["walk"] = (8, True, walk)
still = {"Body": {"rot": (-3, 0, 0)}, "Head": {"rot": (-16, 0, 0)}, "ArmL": {"rot": (-2, 0, 5)}, "ArmR": {"rot": (-2, 0, -5)}}
anims["faded"] = (12, True, {0: still})
for nm, (length, loop, frames) in anims.items():
    ik.bake_animation(nm, anim_parts, frames, length, loop)

ik.report(name, parts)
ik.export_glb(out_glb, animated=True)
print("EXPORTED", out_glb)
