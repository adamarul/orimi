"""The Hollow Kiln's props, one glTF each, under 5,000 triangles, painted from a paint map.

    blender --background --factory-startup --python tools/levels/hollow_kiln/make_props.py -- <model> <out.glb> <paintmap.json>

Models (Godot space, front toward -Z, standing on y = 0; wall props have their back on the wall at z = 0):
  brazier        stone pedestal and iron bowl; Flame hidden in "unlit", flickering in "lit" (Kindle)
  cord_gate      the yard gate: two timber leaves hinged at x = +-3, bound with ink cord; "bound", "cut", "open" (Slash)
  woodpile       stacked pine logs
  jars           a cluster of big clay jars, some sooted
  bellows        a great box bellows, nozzle toward -Z; "idle", "blow" (Gust)
  tie_post       a timber bollard with an iron tie ring on top (Tie)
  pillar_ring    an iron bracket with a tie ring, bolted to a vat-chamber pillar; the arm reaches +X (Tie, the Dregs part 3)
  counterweight  the hall's north door: a hanging stone weight with a tie ring, a pulley, a slatted door
                 4 m to the east; "closed", "open" (Tie)
  drying_rack    a timber rack hung with grey paper
  wall_lamp      an iron bracket lamp; "unlit", "lit" (Kindle)
  moss_foothold  a stone nub with dry moss; "withered", "bloom" grows a mossy shelf with its own collider (Bloom)
  vat            the cracked vat, its iron bands and the four chains up to the crown ring
  raft_jetty     a short timber jetty at the landing
  kiln_fire      the fire in a kiln mouth: cold ash in "unlit", flames in "lit" (Kindle)
  ink_pool       the ink surface in the flue (the level raises it)
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kilnlib as L  # noqa: E402

ik = L.ik
bpy = L.bpy
Vector = L.Vector


def obj(name, vf, tag, material, parent=None, location=(0.0, 0.0, 0.0)):
    o = L.gmake(name, vf, parent=parent, location=location)
    ik.set_tags(o, tag)
    ik.assign_material(o, material)
    return o


def tagged(o, fn):
    L.tag_by(o, fn)
    return o


def default_col(co, n, tag):
    if tag in ("flame", "flame_core"):
        return (0.15, 0.0, 0.6)
    if tag in ("paper", "paper_grey"):
        return (0.35, 0.35 * max(0.0, 1.0 - co[1] / 2.5), 0.6)
    if tag in ("moss", "moss_dry"):
        return (0.55, 0.2, 0.6)
    under = 1.0 if n[1] < -0.3 else 0.85
    return (under, 0.0, 0.35 + 0.3 * ik.hash01(co[0] * 3.1, co[1] * 2.3, co[2] * 1.7))


def finish(model, out_glb, out_map, parts, size, animated=False, colors=default_col, crease=40.0):
    bpy.context.view_layer.update()
    meshes = [o for o in parts if o.type == "MESH" and not o.name.endswith("colonly")]
    for o in meshes:
        L.paint(o, colors)
    ik.smart_uv(meshes, angle=45.0, margin=0.012)
    ik.dump_paint_map(meshes, out_map, size, crease_deg=crease)
    ik.report(model, meshes)
    ik.export_glb(out_glb, animated=animated)


def tucked(o, depth=1.5):
    return {"scale": 0.01, "loc": tuple(-o.location + Vector((0.0, 0.0, -depth)))}


def flame_vf(base_y, height, radius, seed, tongues=3):
    rnd = random.Random(seed)
    parts = []
    for k in range(tongues):
        a = 2 * math.pi * k / tongues + rnd.uniform(-0.4, 0.4)
        off = radius * 0.45 if tongues > 1 else 0.0
        bx, bz = math.cos(a) * off, math.sin(a) * off
        h = height * rnd.uniform(0.7, 1.0)
        pts = [(bx, base_y, bz), (bx * 0.9 + rnd.uniform(-0.05, 0.05), base_y + h * 0.4, bz * 0.9),
               (bx * 0.5 + rnd.uniform(-0.1, 0.1), base_y + h * 0.75, bz * 0.5), (rnd.uniform(-0.1, 0.1), base_y + h, rnd.uniform(-0.1, 0.1))]
        parts.append(L.gtube(pts, [radius * 0.55, radius * 0.5, radius * 0.3, 0.0], 5))
    return L.merged(*parts)


def flicker_frames(flames, length=12):
    frames = {}
    rnd = random.Random(3)
    for f in range(0, length, 2):
        frames[f] = {fl.name: {"scale": (rnd.uniform(0.85, 1.1), rnd.uniform(0.85, 1.1), rnd.uniform(0.8, 1.25)), "rot": (0, 0, rnd.uniform(-12, 12))} for fl in flames}
    return frames


# ------------------------------------------------------------------------------------ brazier
def build_brazier(out_glb, out_map):
    ped = ik.loft([[(x, 0.0, z) for x, z in ((-0.42, -0.42), (0.42, -0.42), (0.42, 0.42), (-0.42, 0.42))],
                   [(x, 0.15, z) for x, z in ((-0.42, -0.42), (0.42, -0.42), (0.42, 0.42), (-0.42, 0.42))],
                   [(x, 0.25, z) for x, z in ((-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3))],
                   [(x, 0.9, z) for x, z in ((-0.24, -0.24), (0.24, -0.24), (0.24, 0.24), (-0.24, 0.24))],
                   [(x, 0.98, z) for x, z in ((-0.36, -0.36), (0.36, -0.36), (0.36, 0.36), (-0.36, 0.36))]])
    pedestal = obj("Pedestal", ped, "stone", "M_brazier")
    rings = []
    for y, r in ((0.98, 0.18), (1.05, 0.42), (1.25, 0.6), (1.42, 0.66), (1.46, 0.58), (1.3, 0.5), (1.12, 0.3)):
        rings.append([(math.sin(2 * math.pi * k / 12) * r, y, -math.cos(2 * math.pi * k / 12) * r) for k in range(12)])
    bowl = obj("Bowl", ik.loft(rings), "iron", "M_brazier", parent=pedestal)
    coals = obj("Coals", L.moved(L.merged(*[L.moved(ik.ico(0.16, 1, (1, 0.6, 1), 0.3, 40 + k), math.cos(k * 2.1) * 0.28, 0, math.sin(k * 2.1) * 0.28) for k in range(6)]), 0, 1.3, 0),
                "coal", "M_brazier", parent=pedestal)
    flame = obj("Flame", flame_vf(1.28, 1.1, 0.42, 5, 3), "flame", "M_brazier_flame_sacred", parent=pedestal)
    tagged(flame, lambda c, n: "flame_core" if c[1] < 1.6 else "flame")
    col = L.gmake("BrazierCollider-convcolonly", L.gbox(-0.45, 0.45, 0.0, 1.45, -0.45, 0.45))
    parts = [pedestal, bowl, coals, flame]
    ik.store_rest(parts)
    ik.bake_animation("unlit", [flame], {0: {flame.name: tucked(flame)}}, 12, True)
    ik.bake_animation("lit", [flame], flicker_frames([flame]), 12, True)
    ik.apply_pose(flame, tucked(flame))
    finish("brazier", out_glb, out_map, parts + [col], 512, animated=True)


# ------------------------------------------------------------------------------------ gate
def build_cord_gate(out_glb, out_map):
    rnd = random.Random(17)
    leaves = []
    for side in (-1, 1):
        hinge = (side * 3.0, 0.0, 0.0)
        boards = []
        for k in range(6):
            x0 = -side * (0.05 + k * 0.49)
            boards.append(L.gbox(min(x0, x0 - side * 0.47), max(x0, x0 - side * 0.47), 0.05, 4.45 - 0.08 * (k % 2), -0.1, 0.1))
        for y in (0.6, 2.2, 3.8):
            boards.append(L.gbox(min(-side * 0.05, -side * 2.95), max(-side * 0.05, -side * 2.95), y, y + 0.28, -0.22, -0.1))
        boards.append(L.prism_z(-0.24, -0.1, [(-side * 0.2, 0.9), (-side * 0.45, 0.9), (-side * 2.8, 3.6), (-side * 2.55, 3.6)]))
        leaf = obj("Leaf%s" % ("W" if side < 0 else "E"), L.merged(*boards), "wood", "M_cord_gate", location=hinge)
        leaves.append(leaf)
        L.gmake("Leaf%sCollider-convcolonly" % ("W" if side < 0 else "E"), L.gbox(min(0, -side * 3.0), max(0, -side * 3.0), 0.0, 4.5, -0.25, 0.12), parent=leaf)
    # the ink cord: a tangle of black cords wound across both leaves, tied in a knot at the middle
    cords = []
    strokes = []
    for k in range(7):
        y0, y1 = rnd.uniform(0.6, 3.9), rnd.uniform(0.6, 3.9)
        pts = []
        for i in range(13):
            t = i / 12
            x = -3.2 + 6.4 * t
            y = y0 + (y1 - y0) * t + 0.35 * math.sin(math.pi * t * 2 + k) + rnd.uniform(-0.06, 0.06)
            z = 0.2 + 0.12 * math.sin(t * 9 + k) + 0.1
            pts.append((x, y, z))
        r = [0.07 + 0.04 * math.sin(math.pi * i / 12) for i in range(13)]
        r[0] = r[-1] = 0.02
        cords.append(L.gtube(pts, r, 5))
    knot = L.moved(ik.ico(0.42, 1, (1.2, 1.0, 0.8), 0.25, 9), 0.0, 2.3, 0.35)
    knot_v = [(x, y, z) for x, y, z in knot[0]]
    tails = [L.gtube([(0.1, 2.2, 0.45), (0.3, 1.6, 0.5), (0.2, 0.9, 0.42), (0.35, 0.45, 0.4)], [0.08, 0.07, 0.05, 0.0], 5),
             L.gtube([(-0.15, 2.1, 0.45), (-0.4, 1.5, 0.48), (-0.3, 1.0, 0.44)], [0.08, 0.06, 0.0], 5)]
    cordW = obj("CordW", L.merged(*cords[:4]), "ink", "M_cord_gate")
    cordE = obj("CordE", L.merged(*cords[4:]), "ink", "M_cord_gate")
    knot_o = obj("Knot", L.merged((knot_v, knot[1]), *tails), "ink", "M_cord_gate")
    parts = leaves + [cordW, cordE, knot_o]
    ik.store_rest(parts)
    ik.bake_animation("bound", parts, {0: {}}, 12, True)
    cut = {0: {}, 2: {cordW.name: {"loc": (-0.3, -0.4, 0.0), "rot": (0, 8, 0)}, cordE.name: {"loc": (0.3, -0.5, 0.0), "rot": (0, -8, 0)},
                      knot_o.name: {"loc": (0, -0.8, 0)}},
           4: {cordW.name: {"loc": (-0.5, -1.4, 0.1), "rot": (0, 14, 0), "scale": 0.8}, cordE.name: {"loc": (0.5, -1.5, 0.1), "rot": (0, -14, 0), "scale": 0.8},
               knot_o.name: {"loc": (0, -1.8, 0), "scale": 0.7}},
           7: {cordW.name: {"loc": (-0.6, -2.4, 0.1), "scale": 0.5}, cordE.name: {"loc": (0.6, -2.4, 0.1), "scale": 0.5}, knot_o.name: {"loc": (0, -2.2, 0), "scale": 0.4}},
           10: {o.name: tucked(o) for o in (cordW, cordE, knot_o)}}
    ik.bake_animation("cut", parts, cut, 12, False)
    gone = {o.name: tucked(o) for o in (cordW, cordE, knot_o)}
    opn = {0: dict(gone)}
    for f, ang in ((2, 18), (4, 40), (6, 62), (8, 76), (10, 82)):
        opn[f] = dict(gone)
        opn[f][leaves[0].name] = {"rot": (0, 0, -ang)}
        opn[f][leaves[1].name] = {"rot": (0, 0, ang)}
    ik.bake_animation("open", parts, opn, 12, False)

    def colors(co, n, tag):
        if tag == "ink":
            return (0.9, 0.0, 0.5)
        return default_col(co, n, tag)
    finish("cord_gate", out_glb, out_map, parts, 512, animated=True, colors=colors)


# ------------------------------------------------------------------------------------ woodpile, jars
def build_woodpile(out_glb, out_map):
    rnd = random.Random(31)
    logs = []
    for row, (n, y) in enumerate(((5, 0.22), (4, 0.6), (3, 0.98), (2, 1.36))):
        for k in range(n):
            x = (k - (n - 1) / 2) * 0.46 + rnd.uniform(-0.03, 0.03)
            ln = 3.4 + rnd.uniform(-0.3, 0.3)
            cv, cf = L.cylinder(0, 0, 0.22 + rnd.uniform(-0.03, 0.03), -ln / 2, ln / 2, 7)
            logs.append(([(x + px, y + pz, py) for px, py, pz in cv], cf))
    pile = obj("Logs", L.merged(*logs), "log", "M_woodpile")
    tagged(pile, lambda c, n: "log_end" if abs(n[2]) > 0.8 else "log")
    stakes = obj("Stakes", L.merged(L.gbox(-1.35, -1.2, 0, 1.8, -0.1, 0.05), L.gbox(1.2, 1.35, 0, 1.8, -0.1, 0.05)), "wood", "M_woodpile", parent=pile)
    col = L.gmake("WoodCollider-convcolonly", L.gbox(-1.3, 1.3, 0, 1.6, -1.8, 1.8))
    finish("woodpile", out_glb, out_map, [pile, stakes, col], 512)


def jar_vf(h, r, neck, seed):
    rings = []
    prof = [(0.0, r * 0.55), (0.06, r * 0.75), (0.3, r * 1.0), (0.62, r * 0.95), (0.85, neck * 1.15), (0.92, neck), (1.0, neck * 1.2)]
    rnd = random.Random(seed)
    for t, rr in prof:
        rings.append([(math.sin(2 * math.pi * k / 10) * rr * (1 + rnd.uniform(-0.02, 0.02)), t * h, -math.cos(2 * math.pi * k / 10) * rr) for k in range(10)])
    return ik.loft(rings)


def build_jars(out_glb, out_map):
    rnd = random.Random(41)
    jars = []
    for k, (x, z, h, r) in enumerate(((0, 0, 1.6, 0.6), (1.2, 0.3, 1.3, 0.5), (-1.1, 0.5, 1.4, 0.55), (0.5, 1.3, 1.0, 0.42), (-0.5, -1.1, 1.2, 0.48))):
        j = obj("Jar%d" % k, L.moved(jar_vf(h, r, r * 0.45, k), x, 0, z), "clay" if k % 2 == 0 else "clay_dark", "M_jars")
        tagged(j, lambda c, n, h=h, k=k: "glaze" if c[1] > h * 0.7 and k % 2 == 0 else ("clay" if k % 2 == 0 else "clay_dark"))
        jars.append(j)
    lid = obj("Lids", L.merged(L.moved(L.cylinder(0, 0, 0.36, 1.6, 1.68, 10), 0, 0, 0), L.moved(L.cylinder(0, 0, 0.3, 1.3, 1.36, 10), 1.2, 0, 0.3)), "wood", "M_jars", parent=jars[0])
    col = L.gmake("JarsCollider-convcolonly", L.gbox(-1.7, 1.8, 0, 1.5, -1.6, 1.8))
    finish("jars", out_glb, out_map, jars + [lid, col], 512)


# ------------------------------------------------------------------------------------ bellows
def build_bellows(out_glb, out_map):
    frame = obj("Frame", L.merged(L.gbox(-0.9, 0.9, 0.0, 0.35, -1.6, 1.6), L.gbox(-0.9, -0.7, 0.35, 0.8, -1.6, 1.5), L.gbox(0.7, 0.9, 0.35, 0.8, -1.6, 1.5),
                                  L.gbox(-0.25, 0.25, 0.35, 2.3, 1.45, 1.75), L.gbox(-0.85, 0.85, 2.1, 2.35, 1.4, 1.8)), "wood", "M_bellows")
    top = obj("Board", L.merged(L.gbox(-0.85, 0.85, 0.0, 0.18, -2.95, 0.05), L.gbox(-0.12, 0.12, 0.18, 0.5, -2.7, -0.1)), "wood_pale", "M_bellows", parent=frame, location=(0.0, 1.15, 1.45))
    leather = []
    for k in range(3):
        y = 0.45 + k * 0.24
        w = 0.82 + (0.1 if k % 2 else 0.0)
        leather.append(L.gbox(-w, w, y, y + 0.22, -1.45 + 0.1, 1.35))
    leather_o = obj("Leather", L.merged(*leather), "leather", "M_bellows", parent=frame)
    nozzle = obj("Nozzle", L.gtube([(0, 0.62, -1.6), (0, 0.6, -2.3), (0, 0.55, -2.9)], [0.3, 0.17, 0.12], 8), "iron", "M_bellows", parent=frame)
    handle = obj("Handle", L.merged(L.gbox(-0.08, 0.08, 0.18, 1.5, -0.4, -0.25), L.gbox(-0.55, 0.55, 1.42, 1.58, -0.42, -0.24)), "wood", "M_bellows", parent=top)
    col = L.gmake("BellowsCollider-convcolonly", L.gbox(-0.95, 0.95, 0, 1.4, -2.9, 1.8))
    parts = [frame, top, leather_o, nozzle, handle]
    ik.store_rest(parts)
    ik.bake_animation("idle", parts, {0: {}}, 12, True)
    blow = {0: {}, 2: {top.name: {"rot": (-4, 0, 0)}, leather_o.name: {"scale": (1, 1, 0.85)}},
            4: {top.name: {"rot": (-9, 0, 0)}, leather_o.name: {"scale": (1, 1, 0.6), "loc": (0, 0, -0.08)}},
            6: {top.name: {"rot": (-12, 0, 0)}, leather_o.name: {"scale": (1.04, 1, 0.42), "loc": (0, 0, -0.14)}},
            10: {top.name: {"rot": (-6, 0, 0)}, leather_o.name: {"scale": (1, 1, 0.7), "loc": (0, 0, -0.06)}},
            14: {}}
    ik.bake_animation("blow", parts, blow, 18, False)
    finish("bellows", out_glb, out_map, parts + [col], 512, animated=True)


# ------------------------------------------------------------------------------------ tie post, counterweight
def tie_ring(y, r=0.22, seed=0, axis="y"):
    seg, sides = 10, 4
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(sides):
            b = 2 * math.pi * j / sides + math.pi / 4
            rr = r + 0.05 * math.cos(b)
            if axis == "y":
                verts.append((math.cos(a) * rr, y + 0.05 * math.sin(b), math.sin(a) * rr))
            else:
                verts.append((math.cos(a) * rr, y + math.sin(a) * rr, 0.05 * math.sin(b)))
    for i in range(seg):
        for j in range(sides):
            faces.append((i * sides + j, i * sides + (j + 1) % sides, ((i + 1) % seg) * sides + (j + 1) % sides, ((i + 1) % seg) * sides + j))
    return verts, faces


def build_tie_post(out_glb, out_map):
    post = obj("Post", ik.loft([[(math.sin(2 * math.pi * k / 8) * r, y, -math.cos(2 * math.pi * k / 8) * r) for k in range(8)]
                                for y, r in ((0.0, 0.34), (1.2, 0.3), (1.35, 0.36), (1.5, 0.22))]), "wood", "M_tie_post")
    ring = obj("Ring", L.merged(tie_ring(1.62, 0.2, axis="z"), L.gbox(-0.05, 0.05, 1.45, 1.55, -0.05, 0.05)), "gold", "M_tie_post_ring_sacred", parent=post)
    coil = obj("Coil", L.merged(*[tie_ring(0.1 + 0.08 * k, 0.5 - 0.02 * k) for k in range(3)]), "rope", "M_tie_post", parent=post)
    col = L.gmake("PostCollider-convcolonly", L.cylinder(0, 0, 0.36, 0, 1.5, 8))
    finish("tie_post", out_glb, out_map, [post, ring, coil, col], 512)


def build_pillar_ring(out_glb, out_map):
    # origin on the pillar's face at ring height; the ring hangs in the XY plane so it reads as a full circle from the south
    plate = obj("Plate", L.merged(L.gbox(-0.08, 0.0, -0.55, 0.55, -0.32, 0.32), L.gbox(0.0, 0.62, -0.09, 0.09, -0.09, 0.09)), "iron", "M_pillar_ring")
    ring = obj("Ring", L.moved(tie_ring(0.0, 0.42, axis="z"), 0.62, -0.42, 0.0), "gold", "M_pillar_ring_sacred", parent=plate)
    finish("pillar_ring", out_glb, out_map, [plate, ring], 256)


def build_counterweight(out_glb, out_map):
    # local origin under the weight at the hall floor; the door is 4.6 m to the east, in front of the north wall
    beam = obj("Beam", L.merged(L.gbox(-0.8, 6.8, 6.55, 6.9, -0.25, 0.1), L.gbox(-0.15, 0.15, 6.0, 6.6, -0.2, 0.05)), "wood", "M_counterweight")
    pulley = obj("Pulley", L.moved(L.rotated_y(tie_ring(0.0, 0.32, axis="z"), 0), 0.0, 6.2, -0.05), "iron", "M_counterweight", parent=beam)
    weight = obj("Weight", L.merged(L.gbox(-0.6, 0.6, 0.0, 1.2, -0.6, 0.6), L.gbox(-0.15, 0.15, 1.2, 1.45, -0.15, 0.15),
                                    L.moved(tie_ring(0.0, 0.2, axis="z"), 0.0, 0.6, -0.65)), "stone", "M_counterweight", location=(0.0, 4.4, -0.05))
    tagged(weight, lambda c, n: "gold" if c[2] < -0.55 + 0.0 and c[1] > 4.75 and c[1] < 5.25 and abs(c[0]) < 0.3 else "stone")
    rope_w = obj("RopeW", L.gbox(-0.04, 0.04, 1.45, 1.9, -0.04, 0.04), "rope", "M_counterweight", parent=weight)
    rope_top = obj("RopeTop", L.merged(L.gbox(0.0, 4.6, 6.45, 6.53, -0.08, 0.0), L.gbox(4.56, 4.64, 4.6, 6.5, -0.08, 0.0)), "rope", "M_counterweight", parent=beam)
    slats = []
    for k in range(9):
        x = 2.75 + k * 0.45
        slats.append(L.gbox(x, x + 0.22, 0.0, 4.3, 0.15, 0.32))
    for y in (0.5, 2.0, 3.6):
        slats.append(L.gbox(2.6, 6.45, y, y + 0.25, 0.32, 0.45))
    door = obj("Door", L.merged(*slats), "wood", "M_counterweight", location=(0.0, 0.0, 0.0))
    L.gmake("DoorCollider-convcolonly", L.gbox(2.6, 6.45, 0.0, 4.3, 0.12, 0.45), parent=door)
    parts = [beam, pulley, weight, rope_w, rope_top, door]
    ik.store_rest(parts)
    ik.bake_animation("closed", parts, {0: {}}, 12, True)
    opn = {0: {}}
    for f, t in ((2, 0.15), (4, 0.4), (6, 0.65), (8, 0.85), (10, 0.97), (12, 1.0)):
        opn[f] = {weight.name: {"loc": (0, 0, -4.2 * t)}, rope_w.name: {"scale": (1, 1, 1.0 + 9.0 * t)}, door.name: {"loc": (0, 0, 4.0 * t)}}
    ik.bake_animation("open", parts, opn, 14, False)
    finish("counterweight", out_glb, out_map, parts, 512, animated=True)


# ------------------------------------------------------------------------------------ drying rack
def build_drying_rack(out_glb, out_map):
    rnd = random.Random(61)
    frame = []
    for x in (-2.3, 2.3):
        frame.append(L.gbox(x - 0.09, x + 0.09, 0.0, 2.7, -0.09, 0.09))
        frame.append(L.gbox(x - 0.12, x + 0.12, 0.0, 0.14, -0.45, 0.45))
    for y in (1.2, 2.6):
        frame.append(L.gbox(-2.4, 2.4, y, y + 0.08, -0.05, 0.05))
    rack = obj("Rack", L.merged(*frame), "wood", "M_drying_rack")
    sheets = []
    for y_top in (1.2, 2.6):
        x = -2.15
        while x < 2.0:
            w = rnd.uniform(0.6, 0.85)
            h = rnd.uniform(0.75, 1.05)
            sheets.append(L.rotated_y(L.gbox(x, x + w, y_top - h, y_top, -0.015, 0.015), rnd.uniform(-5, 5), x + w / 2, 0.0))
            x += w + rnd.uniform(0.08, 0.2)
    paper = obj("Paper", L.merged(*sheets), "paper_grey", "M_drying_rack", parent=rack)
    col = L.gmake("RackCollider-convcolonly", L.gbox(-2.4, 2.4, 0, 2.7, -0.45, 0.45))
    finish("drying_rack", out_glb, out_map, [rack, paper, col], 512)


# ------------------------------------------------------------------------------------ wall lamp
def build_wall_lamp(out_glb, out_map):
    plate = obj("Plate", L.merged(L.gbox(-0.18, 0.18, -0.5, 0.3, -0.06, 0.0), L.gbox(-0.04, 0.04, -0.1, 0.0, -0.6, -0.06),
                                  L.gtube([(0.0, -0.45, -0.06), (0.0, -0.3, -0.35), (0.0, -0.1, -0.55)], [0.035, 0.03, 0.03], 4)), "iron", "M_wall_lamp")
    rings = []
    for y, r in ((-0.1, 0.06), (-0.02, 0.2), (0.12, 0.26), (0.2, 0.22), (0.12, 0.14)):
        rings.append([(math.sin(2 * math.pi * k / 10) * r, y, -0.62 - math.cos(2 * math.pi * k / 10) * r) for k in range(10)])
    cup = obj("Cup", ik.loft(rings), "brass", "M_wall_lamp", parent=plate)
    flame = obj("Flame", L.moved(flame_vf(0.12, 0.55, 0.16, 7, 1), 0, 0, -0.62), "flame", "M_wall_lamp_flame_sacred", parent=plate)
    tagged(flame, lambda c, n: "flame_core" if c[1] < 0.3 else "flame")
    parts = [plate, cup, flame]
    ik.store_rest(parts)
    ik.bake_animation("unlit", [flame], {0: {flame.name: tucked(flame)}}, 12, True)
    ik.bake_animation("lit", [flame], flicker_frames([flame]), 12, True)
    ik.apply_pose(flame, tucked(flame))
    finish("wall_lamp", out_glb, out_map, parts, 256, animated=True)


# ------------------------------------------------------------------------------------ moss foothold
def build_moss_foothold(out_glb, out_map):
    rnd = random.Random(71)
    nub = obj("Nub", ik.loft([[(-0.45, -0.5, 0.0), (0.45, -0.5, 0.0), (0.45, 0.0, 0.0), (-0.45, 0.0, 0.0)],
                              [(-0.32, -0.3, -0.5), (0.32, -0.3, -0.5), (0.32, 0.0, -0.5), (-0.32, 0.0, -0.5)]]), "stone", "M_moss_foothold")
    strands = []
    for k in range(7):
        x = rnd.uniform(-0.4, 0.4)
        z = rnd.uniform(-0.45, -0.05)
        strands.append(L.gtube([(x, -0.05, z), (x + rnd.uniform(-0.1, 0.1), -0.4, z - 0.05), (x + rnd.uniform(-0.15, 0.15), -0.75 - rnd.random() * 0.3, z - 0.08)], [0.04, 0.03, 0.0], 3))
    dry = obj("DryMoss", L.merged(*strands), "moss_dry", "M_moss_foothold", parent=nub)
    pad_parts = [L.gbox(-0.8, 0.8, -0.35, 0.0, -1.7, 0.0)]
    for k in range(9):
        a = rnd.uniform(0, 2 * math.pi)
        pad_parts.append(L.moved(ik.ico(rnd.uniform(0.22, 0.34), 1, (1.0, 0.45, 1.0), 0.25, 80 + k), math.cos(a) * 0.55, 0.02, -0.85 + math.sin(a) * 0.6))
    pad = obj("Pad", L.merged(*pad_parts), "moss", "M_moss_foothold", location=(0.0, 0.0, 0.0))
    tagged(pad, lambda c, n: "moss" if n[1] > 0.2 or c[1] > -0.05 else "stone")
    L.gmake("PadCollider-convcolonly", L.gbox(-0.8, 0.8, -0.35, 0.0, -1.7, 0.0), parent=pad)
    parts = [nub, dry, pad]
    ik.store_rest(parts)
    ik.bake_animation("withered", [pad, dry], {0: {pad.name: tucked(pad, 3.0)}}, 12, True)
    ik.bake_animation("bloom", [pad, dry], {0: {pad.name: tucked(pad, 3.0)}, 2: {pad.name: {"scale": 0.4}, dry.name: {"scale": 0.6}},
                                            4: {pad.name: {"scale": 1.15}, dry.name: tucked(dry, 3.0)}, 6: {pad.name: {"scale": 1.0}}}, 12, False)
    ik.apply_pose(pad, tucked(pad, 3.0))
    finish("moss_foothold", out_glb, out_map, parts, 256, animated=True)


# ------------------------------------------------------------------------------------ vat and chains
def chain_vf(a, b, link=0.5, r=0.11):
    a, b = Vector(a), Vector(b)
    d = b - a
    n = max(2, int(d.length / link))
    parts = []
    for k in range(n):
        p0 = a + d * (k / n)
        p1 = a + d * ((k + 1) / n)
        mid = (p0 + p1) / 2
        side = d.normalized().cross(Vector((0, 1, 0)) if abs(d.normalized().y) < 0.9 else Vector((1, 0, 0))).normalized()
        if k % 2:
            side = side.cross(d.normalized()).normalized()
        verts = [tuple(p0), tuple(mid + side * r), tuple(p1), tuple(mid - side * r)]
        thick = d.normalized().cross(side).normalized() * 0.04
        vv = [tuple(Vector(v) + thick) for v in verts] + [tuple(Vector(v) - thick) for v in verts]
        parts.append((vv, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]))
    return L.merged(*parts)


def build_vat(out_glb, out_map):
    R = 5.0
    rim = 4.5
    sides = 24
    prof_out = [(0.0, R * 0.86), (0.4, R * 0.96), (1.6, R), (3.4, R * 0.98), (rim, R * 0.94)]
    prof_in = [(rim, R * 0.84), (3.4, R * 0.86), (1.0, R * 0.82), (1.0, 0.0)]
    rings = []
    for y, r in prof_out + prof_in[:-1]:
        rings.append([(math.sin(2 * math.pi * k / sides) * r, y, -math.cos(2 * math.pi * k / sides) * r) for k in range(sides)])
    rings.append([(0.0, 1.0, 0.0)])
    body_v, body_f = ik.loft(rings, cap_start=True, cap_end=False)
    # the crack: pull the south face of the vat apart in a jagged notch
    body_v = [(x + (0.25 * math.copysign(1, x) if (z > R * 0.8 and abs(x) < 0.5 and 0.3 < y < rim) else 0.0), y, z) for x, y, z in body_v]
    body = obj("Body", (body_v, body_f), "stone_dark", "M_vat")
    tagged(body, lambda c, n: "ink" if (c[1] < rim - 0.2 and math.hypot(c[0], c[2]) < R * 0.87 and n[1] > -0.5 and c[1] > 0.9) else ("crack" if (c[2] > R * 0.8 and abs(c[0]) < 0.6) else "stone_dark"))
    bands = []
    for y in (0.8, 2.6, 4.1):
        r = R * (0.98 if y < 3 else 0.955) + 0.06
        bands.append(L.cylinder(0, 0, r, y - 0.18, y + 0.18, sides))
    band_o = obj("Bands", L.merged(*bands), "iron", "M_vat", parent=body)
    ink = obj("InkSurface", L.cylinder(0, 0, R * 0.85, 3.4, 3.5, sides), "ink", "M_vat", parent=body)
    crown_y = 21.0
    chains = []
    lugs = []
    for ang in (45.0, 135.0, 225.0, 315.0):
        a = math.radians(ang)
        p = (math.sin(a) * (R * 0.9), rim + 0.1, -math.cos(a) * (R * 0.9))
        chains.append(chain_vf(p, (math.sin(a) * 1.2, crown_y - 0.4, -math.cos(a) * 1.2), 0.55, 0.13))
        lugs.append(L.moved(L.gbox(-0.25, 0.25, -0.2, 0.35, -0.25, 0.25), p[0], rim - 0.2, p[2]))
    chain_o = obj("Chains", L.merged(*chains), "iron", "M_vat", parent=body)
    crown = obj("Crown", L.merged(tie_ring(crown_y, 1.4), tie_ring(crown_y + 0.3, 1.2), L.gtube([(0, crown_y + 0.3, 0), (0, crown_y + 3.0, 0)], [0.15, 0.15], 5), *lugs), "iron", "M_vat", parent=body)
    col = L.gmake("VatCollider-convcolonly", L.cylinder(0, 0, R, 0, rim, 16))

    def colors(co, n, tag):
        if tag == "iron":
            return (0.55, 0.0, 0.3)
        if tag == "ink":
            return (0.2, 0.0, 0.5)
        return default_col(co, n, tag)
    finish("vat", out_glb, out_map, [body, band_o, ink, chain_o, crown, col], 1024, colors=colors)


# ------------------------------------------------------------------------------------ jetty, fire, ink pool
def build_raft_jetty(out_glb, out_map):
    planks = [L.gbox(-3.8 + k * 0.42, -3.8 + k * 0.42 + 0.38, 0.05, 0.2, -1.2, 1.2) for k in range(9)]
    deck = obj("Deck", L.merged(*planks, L.gbox(-3.8, 0.0, -0.1, 0.05, -1.25, -1.05), L.gbox(-3.8, 0.0, -0.1, 0.05, 1.05, 1.25)), "wood_pale", "M_raft_jetty")
    piles = [L.cylinder(x, z, 0.14, -1.8, 0.7 if x > -1 else 0.3, 6) for x in (-3.6, -1.8, -0.15) for z in (-1.15, 1.15)]
    pile_o = obj("Piles", L.merged(*piles), "wood", "M_raft_jetty", parent=deck)
    rope = obj("Rope", L.merged(tie_ring(0.55, 0.18), tie_ring(0.62, 0.17)), "rope", "M_raft_jetty", parent=deck)
    rope.location = ik.g2b(-0.15, 0.0, 1.15)
    col = L.gmake("JettyCollider-convcolonly", L.gbox(-3.8, 0.0, -0.1, 0.2, -1.25, 1.25))
    finish("raft_jetty", out_glb, out_map, [deck, pile_o, rope, col], 512)


def build_kiln_fire(out_glb, out_map):
    ash = obj("Ash", L.merged(*[L.moved(ik.ico(0.3, 1, (1.2, 0.5, 1.0), 0.3, 60 + k), math.cos(k * 1.7) * 0.6, 0.0, math.sin(k * 1.7) * 0.5) for k in range(7)]), "coal", "M_kiln_fire")
    flames = obj("Flames", L.merged(flame_vf(0.1, 2.4, 0.7, 11, 4), L.moved(flame_vf(0.1, 1.5, 0.45, 12, 2), 0.6, 0, 0.3)), "flame", "M_kiln_fire_flame_sacred", parent=ash)
    tagged(flames, lambda c, n: "flame_core" if c[1] < 0.9 else "flame")
    parts = [ash, flames]
    ik.store_rest(parts)
    ik.bake_animation("unlit", [flames], {0: {flames.name: tucked(flames)}}, 12, True)
    ik.bake_animation("lit", [flames], flicker_frames([flames]), 12, True)
    ik.apply_pose(flames, tucked(flames))
    finish("kiln_fire", out_glb, out_map, parts, 256, animated=True)


def build_ink_pool(out_glb, out_map):
    import kiln_layout as K
    w = (K.FLUE["x"][1] - K.FLUE["x"][0]) / 2 + 0.2
    d = (K.FLUE["z"][1] - K.FLUE["z"][0]) / 2 + 0.2
    pool = obj("InkSurface", L.gbox(-w, w, -0.1, 0.0, -d, d), "ink", "M_ink_pool")

    def colors(co, n, tag):
        return (0.0, 0.0, 0.5)
    finish("ink_pool", out_glb, out_map, [pool], 256, colors=colors)


BUILDERS = {"brazier": build_brazier, "cord_gate": build_cord_gate, "woodpile": build_woodpile, "jars": build_jars,
            "bellows": build_bellows, "tie_post": build_tie_post, "pillar_ring": build_pillar_ring, "counterweight": build_counterweight,
            "drying_rack": build_drying_rack, "wall_lamp": build_wall_lamp, "moss_foothold": build_moss_foothold,
            "vat": build_vat, "raft_jetty": build_raft_jetty, "kiln_fire": build_kiln_fire, "ink_pool": build_ink_pool}

if __name__ == "__main__":
    model, out_glb, out_map = ik.cli_args()[:3]
    ik.reset()
    BUILDERS[model](out_glb, out_map)
