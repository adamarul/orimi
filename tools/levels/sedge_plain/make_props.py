"""Sedge Plain props, headless Blender. One model per call.

    blender --background --factory-startup --python tools/levels/sedge_plain/make_props.py -- <name> <out.glb> <paintmap.json>

Names (Blender +Y = Godot -Z is each prop's front; all stand on Z = 0):
  stone_tall      a weathered standing stone, 3.3 m, with a faded rope and three paper strips
  stone_lean      a standing stone leaning 13 degrees, 2.8 m
  stone_capped    a squat stone carrying a flat cap slab, 2.3 m
  stone_fallen    a stone lying half-buried on its side, 3.2 m long
  tie_post        a stout bridge post bound with gold cord near the head (a Tie anchor)
  bridge_wreck    the two ropes and loose planks of a broken rope bridge, hanging from the post
                  at the origin over the lip (+Y) and down a 5 m gully wall
  tamsin_camp      Tamsin's camp: the empty map frame on its easel (front +Y), a lean-to, a
                  stool, a satchel, rolled maps in a basket and a small cairn
  map_leaf        one lost leaf of Tamsin's map, curled, held down by a pebble
  landing_stage   Pell's landing: a plank jetty reaching 5.5 m into the river (-Y = Godot +Z)
                  with a mooring post
  wood_tree       a tree at the edge of the wood: ink trunk and limbs, three canopy clouds
Static solids carry "-convcol" or "-convcolonly" names so Godot builds StaticBody3D collision on
layer 1. Vertex colours follow docs/CONTRACTS.md (R outline weight with taper, G sway, B dry).
"""
import math
import os
import random
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "blender"))
import inklib as ik  # noqa: E402
import props as P  # noqa: E402
from mathutils import Vector  # noqa: E402

bpy = ik.bpy


def menhir(height, base_w, base_d, seed, lean_deg=0.0, sides=9, sink=0.45):
    """A standing stone: irregular rings lofted upward, tapering, with a ragged off-centre top."""
    rnd = random.Random(seed)
    radii = [rnd.uniform(0.82, 1.12) for _ in range(sides)]
    rings = []
    levels = [(-sink, 1.06), (0.0, 1.0), (height * 0.18, 0.97), (height * 0.4, 0.92), (height * 0.6, 0.84), (height * 0.78, 0.7), (height * 0.9, 0.5)]
    lean = math.tan(math.radians(lean_deg))
    for z, k in levels:
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides + 0.3
            r = radii[s] * k * (1.0 + rnd.uniform(-0.05, 0.05))
            ring.append((math.cos(a) * base_w * r + lean * z, math.sin(a) * base_d * r, z + rnd.uniform(-0.04, 0.04) * (z > 0)))
        rings.append(ring)
    top = (lean * height + rnd.uniform(-0.1, 0.1) * base_w, rnd.uniform(-0.1, 0.1) * base_d, height)
    rings.append([top])
    return ik.loft(rings, cap_start=True, cap_end=False)


def stone_colors(co, local, n, tag):
    if tag == "paper":
        return (0.3, 0.35 + 0.65 * ik.smoothstep(2.1, 1.3, co.z), 0.3)
    if tag == "rope":
        return (0.5, 0.0, 0.4)
    under = 0.85 if n.z < -0.2 else 0.4
    return (under, 0.0, 0.45 + 0.35 * ik.hash01(co.x * 3, co.y * 5, co.z * 7))


def strips(points, length, width=0.09):
    """Paper strips hanging from points, double-sided, three segments each."""
    vf = []
    for k, (x, y, z) in enumerate(points):
        out = Vector((x, y, 0)).normalized() * 0.02
        verts, faces = [], []
        for s in range(4):
            zz = z - length * s / 3
            sw = 0.03 * math.sin(s * 1.7 + k)
            tx, ty = -out.y * 50, out.x * 50
            verts += [(x + out.x * s * 2 + tx * width * 0.5 / 1.0 * 0.02 + sw, y + out.y * s * 2 + ty * width * 0.5 * 0.02, zz),
                      (x + out.x * s * 2 - tx * width * 0.5 * 0.02 + sw, y + out.y * s * 2 - ty * width * 0.5 * 0.02, zz)]
        faces = [(2 * s, 2 * s + 1, 2 * s + 3, 2 * s + 2) for s in range(3)]
        back = len(verts)
        verts += [(vx - out.x * 0.4, vy - out.y * 0.4, vz) for vx, vy, vz in verts]
        faces += [(back + 2 * s, back + 2 * s + 2, back + 2 * s + 3, back + 2 * s + 1) for s in range(3)]
        vf.append((verts, faces))
    return ik.merged(*vf)


def finish_static(name, parts, size, colors, crease=30.0, angle=45.0):
    meshes = P.finish(name, parts, size, colors, angle=angle)
    return meshes


def stone(name, out_glb, out_map):
    spec = {
        "stone_tall": dict(height=3.6, base_w=0.46, base_d=0.34, seed=3, lean_deg=3.0),
        "stone_lean": dict(height=3.0, base_w=0.42, base_d=0.32, seed=5, lean_deg=13.0),
        "stone_capped": dict(height=1.9, base_w=0.62, base_d=0.5, seed=7, lean_deg=0.0),
        "stone_fallen": dict(height=3.2, base_w=0.55, base_d=0.42, seed=9, lean_deg=0.0),
    }[name]
    vf = menhir(**spec)
    parts = []
    if name == "stone_fallen":
        vf = ik.transformed(vf, location=(-1.4, 0.0, 0.18), rotation_deg=(0, 84, 8))
    body = ik.make_object("Stone-convcol", vf)
    parts.append(body)
    ik.tag_faces(body, lambda c, n, o: "stone_top" if n.z > 0.65 else "stone")
    if name == "stone_capped":
        cap = ik.make_object("Cap-convcol", P.boulder(0.72, (1.25, 0.95, 0.32), 21, sink=0.0, subdiv=1), location=(0.05, 0.0, 1.62))
        ik.tag_faces(cap, lambda c, n, o: "stone_top" if n.z > 0.65 else "stone")
        parts.append(cap)
    if name == "stone_tall":
        rope = ik.make_object("Rope", P.torus(0.5, 0.035, 12, 4, 2.2))
        rope.scale = (1.0, 0.8, 1.0)
        ik.set_tags(rope, "rope")
        hang = [(math.cos(a) * 0.5, math.sin(a) * 0.4, 2.18) for a in (-0.9, 0.0, 0.8)]
        paper = ik.make_object("Strips", strips(hang, 0.55))
        ik.set_tags(paper, "paper")
        parts += [rope, paper]
    for o in parts:
        ik.assign_material(o, "M_sp_" + name)
    meshes = finish_static(name, parts, 512, stone_colors, angle=40.0)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=25.0)
    ik.report(name, meshes)
    ik.export_glb(out_glb)


def tie_post(out_glb, out_map):
    rnd = random.Random(17)
    spine = [(0, 0, -0.45), (0.02, 0.0, 0.5), (0.04, 0.01, 1.2), (0.05, 0.02, 1.72)]
    post = ik.make_object("Post-convcol", ik.merged(ik.tube(spine, [0.17, 0.16, 0.15, 0.13], 7), ik.transformed(ik.ico(0.15, 1, (1, 1, 0.7)), location=(0.05, 0.02, 1.74))))
    ik.tag_faces(post, lambda c, n, o: "wood")
    gold = ik.make_object("Binding", ik.merged(P.torus(0.165, 0.03, 12, 4, 1.42), P.torus(0.16, 0.03, 12, 4, 1.54), P.torus(0.155, 0.028, 12, 4, 1.32)))
    ik.set_tags(gold, "gold")
    stub = P.gnarled((0.08, 0.15, 1.48), (0.2, 1.0, -0.6), 0.6, 4, 0.25, rnd)
    rope = ik.make_object("RopeStub", ik.tube(stub, [0.04, 0.035, 0.03, 0.02, 0.0], 4))
    ik.set_tags(rope, "rope")
    wedges = ik.make_object("Wedges", ik.merged(P.boulder(0.22, (1.3, 0.9, 0.7), 4, sink=0.4), ik.transformed(P.boulder(0.18, (1.0, 1.2, 0.6), 5, sink=0.4), location=(-0.28, -0.12, 0))))
    wedges.location = (0.22, 0.1, 0.0)
    ik.tag_faces(wedges, lambda c, n, o: "stone")
    parts = [post, gold, rope, wedges]
    for o in parts:
        ik.assign_material(o, "M_sp_tie_post")
    ik.assign_material(gold, "M_sp_tie_gold_sacred")
    taper = ik.chain_taper([ik.chain(spine, 1.0, 0.7), ik.chain(stub, 0.5, 0.05)])

    def colors(co, local, n, tag):
        if tag == "gold":
            return (0.45, 0.0, 0.2)
        if tag == "rope":
            return (taper(co), 0.4, 0.5)
        if tag == "stone":
            return stone_colors(co, local, n, "stone")
        return (taper(co) * (1.0 if n.x < 0 else 0.8), 0.0, 0.35)
    meshes = finish_static("tie_post", parts, 512, colors)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=40.0)
    ik.report("tie_post", meshes)
    ik.export_glb(out_glb)


def bridge_wreck(out_glb, out_map):
    rnd = random.Random(23)
    ropes, chains, plank_vf = [], [], []
    path = [(0.2, 1.42), (1.7, 0.1), (2.3, -1.2), (2.8, -2.6), (3.15, -3.8), (3.35, -4.6)]
    for side in (-1, 1):
        pts = [(side * (0.3 + 0.03 * i) + rnd.uniform(-0.04, 0.04), y, z) for i, (y, z) in enumerate(path)]
        ropes.append(ik.tube(pts, [0.035] * (len(pts) - 1) + [0.0], 4))
        chains.append(ik.chain(pts, 0.6, 0.1))
    for k in range(6):
        t = 0.3 + k * 0.13
        i = min(int(t * (len(path) - 1)), len(path) - 2)
        f = t * (len(path) - 1) - i
        y = path[i][0] + (path[i + 1][0] - path[i][0]) * f + 0.06
        z = path[i][1] + (path[i + 1][1] - path[i][1]) * f
        if k == 4:
            continue
        plank_vf.append(ik.transformed(P.box(0.95, 0.16, 0.04, cz=-0.02), location=(rnd.uniform(-0.05, 0.05), y, z), rotation_deg=(rnd.uniform(60, 95), rnd.uniform(-12, 12), rnd.uniform(-8, 8))))
    rope = ik.make_object("Ropes", ik.merged(*ropes))
    planks = ik.make_object("Planks", ik.merged(*plank_vf))
    ik.set_tags(rope, "rope")
    ik.set_tags(planks, "wood")
    parts = [rope, planks]
    for o in parts:
        ik.assign_material(o, "M_sp_bridge")
    taper = ik.chain_taper(chains)

    def colors(co, local, n, tag):
        if tag == "rope":
            return (taper(co), 0.35, 0.5)
        return (0.8, 0.25, 0.4)
    meshes = finish_static("bridge_wreck", parts, 512, colors)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=40.0)
    ik.report("bridge_wreck", meshes)
    ik.export_glb(out_glb)


def tamsin_camp(out_glb, out_map):
    rnd = random.Random(31)
    wood, paper, cloth, gold, stone_vf, leather = [], [], [], [], [], []
    strokes = []
    # the map frame on its easel, facing +Y
    for x in (-0.55, 0.55):
        leg = [(x * 1.1, 0.12, -0.05), (x * 0.95, 0.0, 0.9), (x * 0.8, -0.08, 1.75)]
        wood.append(ik.tube(leg, [0.04, 0.035, 0.0], 5))
        strokes.append(ik.chain(leg, 0.9, 0.1))
    back = [(0.0, -0.6, -0.05), (0.0, -0.3, 0.9), (0.0, -0.06, 1.6)]
    wood.append(ik.tube(back, [0.035, 0.03, 0.0], 5))
    strokes.append(ik.chain(back, 0.8, 0.1))
    wood.append(P.box(1.3, 0.07, 0.06, cy=0.05, cz=0.62))
    fx, fz0, fz1 = 0.62, 0.68, 1.58
    for (x0, z0, x1, z1) in [(-fx, fz0, fx, fz0), (-fx, fz1, fx, fz1), (-fx, fz0, -fx, fz1), (fx, fz0, fx, fz1)]:
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        sx, sz = abs(x1 - x0) + 0.07, abs(z1 - z0) + 0.07
        wood.append(ik.transformed(P.box(sx, 0.06, sz, cz=-sz / 2), location=(cx, 0.06, cz)))
    paper.append(ik.transformed(P.box(1.18, 0.012, 0.86, cz=-0.43), location=(0.0, 0.04, 1.13)))
    for k, x in enumerate((-0.38, 0.0, 0.38)):
        gold.append(ik.transformed(ik.ico(0.028, 1), location=(x, 0.1, 1.5)))
        gold.append(ik.transformed(ik.ico(0.028, 1), location=(x, 0.1, 0.76)))
    # lean-to: two poles, a ridge pole and a cloth sheet sloping to the ground
    lx, ly = -2.1, -1.0
    for dx in (-0.9, 0.9):
        pole = [(lx + dx, ly + 0.6, -0.05), (lx + dx, ly + 0.62, 1.7)]
        wood.append(ik.tube(pole, [0.045, 0.035], 5))
        strokes.append(ik.chain(pole, 0.9, 0.3))
    wood.append(ik.tube([(lx - 1.05, ly + 0.62, 1.7), (lx + 1.05, ly + 0.62, 1.7)], [0.035, 0.035], 5))
    sheet_v = [(lx - 1.05, ly + 0.64, 1.72), (lx + 1.05, ly + 0.64, 1.72), (lx + 1.1, ly - 1.3, 0.02), (lx - 1.1, ly - 1.3, 0.02),
               (lx - 1.05, ly + 0.6, 1.68), (lx + 1.05, ly + 0.6, 1.68), (lx + 1.1, ly - 1.33, -0.02), (lx - 1.1, ly - 1.33, -0.02)]
    sheet_f = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (2, 6, 7, 3), (1, 5, 6, 2), (0, 3, 7, 4)]
    cloth.append((sheet_v, sheet_f))
    # stool
    sx, sy = 0.9, -0.9
    for a in (0.3, 2.4, 4.4):
        leg = [(sx + math.cos(a) * 0.18, sy + math.sin(a) * 0.18, -0.03), (sx + math.cos(a) * 0.1, sy + math.sin(a) * 0.1, 0.42)]
        wood.append(ik.tube(leg, [0.025, 0.02], 4))
    wood.append(ik.transformed(ik.tube([(0, 0, 0.42), (0, 0, 0.47)], [0.2, 0.2], 7), location=(sx, sy, 0)))
    # satchel and basket of rolled maps
    leather.append(ik.transformed(P.box(0.42, 0.18, 0.3, taper=0.85), location=(1.0, -0.35, 0.0), rotation_deg=(0, 0, 20)))
    bx, by = -0.95, 0.75
    wood.append(ik.transformed(ik.loft([[(math.cos(a) * 0.22, math.sin(a) * 0.22, 0) for a in [i * 0.785 for i in range(8)]],
                                        [(math.cos(a) * 0.26, math.sin(a) * 0.26, 0.32) for a in [i * 0.785 for i in range(8)]]], cap_start=True, cap_end=False), location=(bx, by, 0)))
    for k in range(4):
        a = k * 1.6
        base = (bx + math.cos(a) * 0.09, by + math.sin(a) * 0.09, 0.05)
        tip = (bx + math.cos(a) * 0.3, by + math.sin(a) * 0.25, 0.85 + 0.08 * k)
        paper.append(ik.tube([base, tip], [0.045, 0.045], 6))
    # cairn
    for k, (r, loc) in enumerate([(0.28, (2.2, 0.6, 0)), (0.2, (2.25, 0.62, 0.28)), (0.14, (2.2, 0.58, 0.48)), (0.22, (2.55, 0.4, 0))]):
        stone_vf.append(ik.transformed(P.boulder(r, (1.2, 1.0, 0.7), 40 + k, sink=0.2), location=loc))
    objs = {}
    for name, vf, tag in (("Wood", wood, "wood"), ("Paper", paper, "paper"), ("Cloth", cloth, "cloth"), ("Gold", gold, "gold"),
                          ("Stones", stone_vf, "stone"), ("Leather", leather, "leather")):
        o = ik.make_object(name, ik.merged(*vf))
        ik.set_tags(o, tag)
        ik.assign_material(o, "M_sp_camp")
        objs[name] = o
    ik.tag_faces(objs["Stones"], lambda c, n, o: "stone_top" if n.z > 0.7 else "stone")
    ik.assign_material(objs["Gold"], "M_sp_camp_gold_sacred")
    taper = ik.chain_taper(strokes) if strokes else None

    def colors(co, local, n, tag):
        if tag == "gold":
            return (0.35, 0.0, 0.2)
        if tag == "cloth":
            return (0.85 if n.z < 0 else 0.6, 0.15 * ik.smoothstep(1.7, 0.0, co.z), 0.45)
        if tag == "paper":
            return (0.55, 0.0, 0.35)
        if tag.startswith("stone"):
            return stone_colors(co, local, n, "stone")
        return (0.75, 0.0, 0.35)
    parts = list(objs.values())
    collider = ik.make_object("CampCollider-convcolonly", P.box(1.4, 0.7, 1.7, cy=-0.1))
    collider2 = ik.make_object("LeanToCollider-convcolonly", P.box(2.2, 1.9, 1.6, cx=lx, cy=ly - 0.35))
    meshes = finish_static("tamsin_camp", parts, 1024, colors, angle=40.0)
    ik.dump_paint_map(meshes, out_map, 1024, crease_deg=35.0)
    ik.report("tamsin_camp", meshes)
    ik.export_glb(out_glb)


def map_leaf(out_glb, out_map):
    nu, nv = 6, 4
    w, d = 0.5, 0.38
    top, bottom = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            u, v = i / nu, j / nv
            x, y = (u - 0.5) * w, (v - 0.5) * d
            z = 0.03 + 0.12 * (u ** 2.4) + 0.05 * (v ** 3) + 0.02 * math.sin(u * 3 + v * 2)
            top.append((x, y, z))
            bottom.append((x, y, z - 0.008))
    faces = []
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    off = len(top)
    faces += [(off + a, off + d_, off + c, off + b) for (a, b, c, d_) in faces[:]]
    sheet = ik.make_object("Leaf", (top + bottom, faces))
    ik.tag_faces(sheet, lambda c, n, o: "map" if n.z > 0 else "paper")
    pebble = ik.make_object("Pebble", P.boulder(0.07, (1.3, 1.0, 0.7), 51, sink=0.1), location=(-0.17, 0.12, 0.02))
    ik.tag_faces(pebble, lambda c, n, o: "stone")
    for o in (sheet, pebble):
        ik.assign_material(o, "M_sp_leaf")

    def colors(co, local, n, tag):
        if tag == "stone":
            return (0.8, 0.0, 0.4)
        return (0.45, 0.3, 0.3)
    meshes = finish_static("map_leaf", [sheet, pebble], 256, colors)
    ik.dump_paint_map(meshes, out_map, 256, crease_deg=60.0)
    ik.report("map_leaf", meshes)
    ik.export_glb(out_glb)


def landing_stage(out_glb, out_map):
    rnd = random.Random(43)
    wood, rope = [], []
    deck_z = 0.28
    for k in range(13):
        y = 0.3 - k * 0.44
        wood.append(ik.transformed(P.box(2.2 + rnd.uniform(-0.12, 0.12), 0.4, 0.07), location=(rnd.uniform(-0.05, 0.05), y, deck_z - 0.07), rotation_deg=(0, 0, rnd.uniform(-2, 2))))
    for x in (-0.95, 0.95):
        wood.append(P.box(0.12, 5.6, 0.12, cy=-2.4, cz=deck_z - 0.2))
        for y in (0.2, -2.4, -5.0):
            wood.append(ik.tube([(x, y, -2.4), (x, y, deck_z + (0.35 if y < -4 else 0.05))], [0.09, 0.08], 6))
    wood.append(ik.tube([(0.8, -5.2, -2.0), (0.82, -5.25, deck_z + 0.75)], [0.12, 0.1], 7))
    rope.append(P.torus(0.13, 0.03, 10, 4, deck_z + 0.5))
    rope[-1] = ik.transformed(rope[-1], location=(0.82, -5.25, 0))
    rope.append(ik.tube([(0.7, -5.2, deck_z + 0.5), (0.2, -5.6, deck_z + 0.2), (-0.2, -6.0, -0.55)], [0.025, 0.025, 0.0], 4))
    w = ik.make_object("Planks", ik.merged(*wood))
    r = ik.make_object("Rope", ik.merged(*rope))
    ik.set_tags(w, "wood")
    ik.set_tags(r, "rope")
    for o in (w, r):
        ik.assign_material(o, "M_sp_landing")
    collider = ik.make_object("Deck-convcolonly", P.box(2.2, 5.8, 0.4, cy=-2.4, cz=deck_z - 0.4))

    def colors(co, local, n, tag):
        if tag == "rope":
            return (0.45, 0.3, 0.5)
        return (1.0 if n.z < -0.3 else 0.75, 0.0, 0.4)
    meshes = finish_static("landing_stage", [w, r], 512, colors)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=40.0)
    ik.report("landing_stage", meshes)
    ik.export_glb(out_glb)


def wood_tree(out_glb, out_map):
    rnd = random.Random(61)
    vf, strokes, tips = [], [], []
    trunk = P.gnarled((0, 0, -0.3), (0.04, 0.02, 1), 5.2, 5, 0.1, rnd)
    vf.append(ik.tube(trunk, [0.42, 0.36, 0.3, 0.26, 0.22, 0.18], 7))
    strokes.append(ik.chain(trunk, 1.0, 0.6))
    for k, (yaw, pitch, ln) in enumerate([(30, 35, 3.0), (150, 40, 2.8), (260, 45, 2.6), (90, 70, 2.2)]):
        base = trunk[3 if k < 3 else 4]
        d = (math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch)))
        limb = P.gnarled(base, d, ln, 4, 0.2, rnd)
        vf.append(ik.tube(limb, [0.16, 0.12, 0.08, 0.05, 0.0], 5))
        strokes.append(ik.chain(limb, 0.8, 0.05))
        tips.append(limb[-1])
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        root = P.gnarled((math.cos(a) * 0.25, math.sin(a) * 0.25, 0.5), (math.cos(a), math.sin(a), -0.9), 1.1, 3, 0.15, rnd)
        vf.append(ik.tube(root, [0.18, 0.12, 0.06, 0.0], 5))
        strokes.append(ik.chain(root, 0.9, 0.1))
    bark = ik.make_object("Trunk", ik.merged(*vf))
    ik.set_tags(bark, "bark")
    canopy = []
    for k, tip in enumerate(tips[:4]):
        r = 1.6 + rnd.uniform(-0.2, 0.4)
        c = ik.make_object("Canopy%d" % (k + 1), ik.ico(r * 1.15, 2, (1.0, 1.0, 0.42), 0.08, 70 + k), location=tuple(Vector(tip) + Vector((0, 0, 0.2))))
        ik.tag_faces(c, lambda cc, n, o: "canopy" if n.z > -0.3 else "canopy_under")
        canopy.append(c)
    parts = [bark] + canopy
    for o in parts:
        ik.assign_material(o, "M_sp_wood_tree")
    taper = ik.chain_taper(strokes)

    def colors(co, local, n, tag):
        if tag.startswith("canopy"):
            return (0.45 if n.z < 0 else 0.2, 0.35, 0.6)
        r = taper(co)
        return (r * (1.0 if n.z < -0.3 else 0.85), 0.05 * ik.smoothstep(3, 7, co.z), 0.25 + 0.6 * (1 - r))
    collider = ik.make_object("TrunkCollider-convcolonly", ik.tube([(0, 0, -0.3), (0, 0, 3.0)], [0.4, 0.3], 6))
    meshes = finish_static("wood_tree", parts, 512, colors, angle=60.0)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=70.0)
    ik.report("wood_tree", meshes)
    ik.export_glb(out_glb)


BUILDERS = {"tie_post": tie_post, "bridge_wreck": bridge_wreck, "tamsin_camp": tamsin_camp, "map_leaf": map_leaf,
            "landing_stage": landing_stage, "wood_tree": wood_tree}

if __name__ == "__main__":
    name, out_glb, out_map = ik.cli_args()[:3]
    ik.reset()
    if name.startswith("stone_"):
        stone(name, out_glb, out_map)
    else:
        BUILDERS[name](out_glb, out_map)
