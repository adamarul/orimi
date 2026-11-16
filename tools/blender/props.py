"""Builders for every prop model; each tools/blender/make_<prop>.py calls build(<prop>).

    blender --background --factory-startup --python tools/blender/make_<prop>.py -- <out.glb> <paintmap.json>

Props (Blender +Y = Godot -Z is each prop's front; all stand on Z = 0):
  sapling          withered sapling tied with a vermilion cord; Bloom1..6 clusters pop on "bloom"
  great_tree       the Thousand-Ring Camphor; Canopy1..10 clusters grow on "bloom"
  thorn_gate       a tangle of ink thorn vines between two stumps, 7.6 m wide, spanning X
  shrine           small riverside shrine on a stone plinth, vermilion posts, gold ridge
  stepping_stone   one flat-topped river stone, top at Z = 0.18, reaching down into the bed
  rocks            a cluster of three boulders
  reeds            a clump of reeds whose vertex green drives wind sway
  raft             Pell's pole raft, origin at the waterline, deck top at Z = 0.17; "bob" loops
Static solids get "-convcol"/"-convcolonly" names so Godot builds StaticBody3D collision (layer 1).
"""
import math
import random

import inklib as ik
from mathutils import Vector

bpy = ik.bpy


def gnarled(start, direction, length, segments, wander, rnd, up_bias=0.0):
    """A wandering polyline, the skeleton of a trunk, branch or vine."""
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    step = length / segments
    for _ in range(segments):
        d = (d + Vector((rnd.uniform(-wander, wander), rnd.uniform(-wander, wander), rnd.uniform(-wander, wander) + up_bias))).normalized()
        pts.append(pts[-1] + d * step)
    return pts


def radii(n, r0, r1, end_point=True):
    out = [r0 + (r1 - r0) * (i / (n - 1)) for i in range(n)]
    if end_point:
        out[-1] = 0.0
    return out


def torus(R, r, seg=12, sides=4, z=0.0):
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(sides):
            b = 2 * math.pi * j / sides + math.pi / 4
            rr = R + r * math.cos(b)
            verts.append((math.cos(a) * rr, math.sin(a) * rr, z + r * math.sin(b) + 0.012 * math.sin(a * 3)))
    for i in range(seg):
        for j in range(sides):
            faces.append((i * sides + j, i * sides + (j + 1) % sides, ((i + 1) % seg) * sides + (j + 1) % sides, ((i + 1) % seg) * sides + j))
    return verts, faces


def box(sx, sy, sz, cx=0.0, cy=0.0, cz=0.0, taper=1.0):
    hx, hy = sx / 2, sy / 2
    bottom = [(cx - hx, cy - hy, cz), (cx + hx, cy - hy, cz), (cx + hx, cy + hy, cz), (cx - hx, cy + hy, cz)]
    top = [(cx - hx * taper, cy - hy * taper, cz + sz), (cx + hx * taper, cy - hy * taper, cz + sz),
           (cx + hx * taper, cy + hy * taper, cz + sz), (cx - hx * taper, cy + hy * taper, cz + sz)]
    return ik.loft([bottom, top])


def finish(name, parts, size, colors, crease=30.0, angle=45.0):
    bpy.context.view_layer.update()
    for o in parts:
        if o.type == "MESH":
            ik.paint_vertex_colors(o, colors)
    meshes = [o for o in parts if o.type == "MESH" and not o.name.endswith("colonly")]
    ik.smart_uv(meshes, angle=angle, margin=0.012)
    return meshes


def tucked(obj, depth=1.5):
    """Hidden pose for a part that grows in later: shrunk and parked below the ground, because the
    outline pass keeps a screen-space width and would draw a shrunk part as a black dot."""
    return {"scale": 0.01, "loc": tuple(-obj.location + Vector((0.0, 0.0, -depth)))}


def default_colors(co, local, n, tag):
    return (1.0, 0.0, 0.35)


# ----------------------------------------------------------------------------- sapling
def build_sapling(out_glb, out_map):
    rnd = random.Random(41)
    skeleton = gnarled((0, 0, 0), (0.1, 0.05, 1), 0.95, 6, 0.22, rnd)
    parts_vf = [ik.tube(skeleton, radii(7, 0.075, 0.03), 6)]
    tips = []
    strokes = [ik.chain(skeleton, 1.0, 0.35)]
    for k, (h, yaw, ln) in enumerate([(0.45, 30, 0.55), (0.6, 150, 0.6), (0.72, 260, 0.5), (0.82, 340, 0.45), (0.95, 90, 0.4)]):
        base = skeleton[int(h / 0.95 * 6)]
        d = (math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0.15)
        b = gnarled(base, d, ln, 4, 0.35, rnd, up_bias=-0.08)
        parts_vf.append(ik.tube(b, radii(5, 0.028, 0.012), 4))
        tips.append(b[-1])
        twig = gnarled(b[2], (d[0] + rnd.uniform(-0.5, 0.5), d[1] + rnd.uniform(-0.5, 0.5), 0.3), ln * 0.4, 3, 0.3, rnd)
        parts_vf.append(ik.tube(twig, radii(4, 0.014, 0.008), 3))
        strokes += [ik.chain(b, 0.7, 0.06), ik.chain(twig, 0.4, 0.04)]
    tips.append(skeleton[-1])
    trunk = ik.make_object("Trunk", ik.merged(*parts_vf))
    cord = ik.make_object("Cord", ik.merged(torus(0.085, 0.017, 12, 4, 0.36), ik.transformed(ik.ico(0.028, 1), location=(0.0, 0.1, 0.33))), parent=trunk)
    blooms = []
    for k, tip in enumerate(tips):
        v, f = ik.ico(0.15 if k < 5 else 0.18, 1, (1.0, 1.0, 0.72), 0.18, 50 + k)
        blooms.append(ik.make_object("Bloom%d" % (k + 1), (v, f), parent=trunk, location=tuple(tip)))
    parts = [trunk, cord] + blooms
    ik.set_tags(trunk, "bark")
    ik.set_tags(cord, "cord")
    ik.tag_faces(cord, lambda c, n, o: "gold" if c.y > 0.08 and c.z < 0.36 else "cord")
    for i, b in enumerate(blooms):
        ik.tag_faces(b, lambda c, n, o, i=i: "blossom" if (n.z > -0.2 or i % 2) else "leaf")
    for o in parts:
        ik.assign_material(o, "M_sapling")
    ik.assign_material(cord, "M_sapling_cord_sacred")
    tip_w = ik.chain_taper(strokes)

    def colors(co, local, n, tag):
        if tag in ("cord", "gold"):
            return (0.5, 0.0, 0.2)
        if tag in ("blossom", "leaf"):
            return (0.45, 0.6, 0.5)
        r = tip_w(co)
        return (r, 0.15 * ik.smoothstep(0.4, 1.2, co.z), 0.3 + 0.6 * (1 - r))
    meshes = finish("sapling", parts, 512, colors)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=60.0)
    ik.store_rest(parts)
    hidden = {b.name: tucked(b) for b in blooms}
    ik.bake_animation("withered", blooms, {0: dict(hidden)}, 12, True)
    frames = {0: dict(hidden)}
    for k, b in enumerate(blooms):
        frames.setdefault(2 + 2 * k, {})[b.name] = {"scale": 0.6}
        frames.setdefault(3 + 2 * k, {})[b.name] = {"scale": 1.25}
        frames.setdefault(5 + 2 * k, {})[b.name] = {"scale": 1.0}
    ik.bake_animation("bloom", blooms, frames, 24, False)
    for b in blooms:
        ik.apply_pose(b, tucked(b))
    ik.report("sapling", meshes)
    ik.export_glb(out_glb, animated=True)


# ----------------------------------------------------------------------------- great tree
def build_great_tree(out_glb, out_map):
    rnd = random.Random(7)
    vf = []
    trunk_pts = gnarled((0, 0, -0.3), (0.05, 0.03, 1), 6.3, 7, 0.08, rnd)
    vf.append(ik.tube(trunk_pts, [1.35, 1.15, 1.0, 0.92, 0.86, 0.8, 0.74, 0.7], 9, cap=True))
    strokes = [ik.chain(trunk_pts, 1.0, 0.75)]
    for k in range(6):
        a = 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3)
        root = gnarled((math.cos(a) * 0.7, math.sin(a) * 0.7, 1.4), (math.cos(a), math.sin(a), -0.9), 2.6, 4, 0.15, rnd)
        vf.append(ik.tube(root, [0.55, 0.45, 0.32, 0.18, 0.0], 5))
        strokes.append(ik.chain(root, 0.9, 0.12))
    tips, limbs_end = [], []
    for k, (yaw, pitch, ln) in enumerate([(20, 40, 5.5), (140, 35, 5.0), (260, 45, 5.2), (80, 70, 4.2)]):
        base = trunk_pts[-2 if k < 3 else -1]
        d = (math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch)))
        limb = gnarled(base, d, ln, 5, 0.18, rnd)
        vf.append(ik.tube(limb, [0.62, 0.5, 0.4, 0.3, 0.2, 0.0], 6))
        strokes.append(ik.chain(limb, 0.85, 0.06))
        tips.append(limb[-1])
        for j in range(2):
            sb = limb[2 + j]
            sd = (d[0] + rnd.uniform(-0.8, 0.8), d[1] + rnd.uniform(-0.8, 0.8), d[2] + rnd.uniform(-0.2, 0.4))
            br = gnarled(sb, sd, ln * 0.55, 4, 0.25, rnd)
            vf.append(ik.tube(br, [0.28, 0.2, 0.13, 0.07, 0.0], 5))
            strokes.append(ik.chain(br, 0.5, 0.04))
            tips.append(br[-1])
            # bare crooked twigs, so the withered tree is a spiky black silhouette
            for t in range(3):
                tb = br[1 + t]
                td = (sd[0] + rnd.uniform(-1.2, 1.2), sd[1] + rnd.uniform(-1.2, 1.2), sd[2] + rnd.uniform(-0.3, 0.8))
                twig = gnarled(tb, td, ln * rnd.uniform(0.22, 0.34), 3, 0.35, rnd)
                vf.append(ik.tube(twig, [0.09, 0.05, 0.025, 0.0], 4))
                strokes.append(ik.chain(twig, 0.4, 0.03))
    trunk = ik.make_object("Trunk", ik.merged(*vf))
    cord_v = ik.merged(torus(1.18, 0.1, 16, 4, 2.3), torus(1.15, 0.07, 16, 4, 2.55))
    cord = ik.make_object("Cord", cord_v, parent=trunk)
    streamers = []
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        cx, cy = math.cos(a) * 1.24, math.sin(a) * 1.24
        tx, ty = -math.sin(a), math.cos(a)
        pts = []
        for s in range(4):
            off = 0.09 if s % 2 else -0.09
            z = 2.25 - s * 0.22
            pts.append([(cx + tx * (-0.11 + off * 0.3) + math.cos(a) * 0.02 * s, cy + ty * (-0.11 + off * 0.3) + math.sin(a) * 0.02 * s, z),
                        (cx + tx * (0.11 + off * 0.3) + math.cos(a) * 0.02 * s, cy + ty * (0.11 + off * 0.3) + math.sin(a) * 0.02 * s, z)])
        verts = [p for pair in pts for p in pair]
        faces = [(2 * s, 2 * s + 1, 2 * s + 3, 2 * s + 2) for s in range(3)]
        back = len(verts)
        verts += [(x - math.cos(a) * 0.01, y - math.sin(a) * 0.01, z) for x, y, z in verts]
        faces += [(back + 2 * s, back + 2 * s + 2, back + 2 * s + 3, back + 2 * s + 1) for s in range(3)]
        streamers.append((verts, faces))
    paper = ik.make_object("Streamers", ik.merged(*streamers), parent=trunk)
    # each canopy cloud carries blossom puffs on its crown, so Bloom turns the bare black tree
    # into a full green canopy flecked with pink in one beat
    canopy, canopy_base = [], []
    for k, tip in enumerate(tips):
        r = 2.4 + rnd.uniform(-0.3, 0.6)
        base = ik.ico(r, 2, (1.0, 1.0, 0.5), 0.14, 90 + k)
        puffs = []
        for j in range(6):
            a, b = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.15, 1.1)
            at = (math.cos(a) * math.sin(b) * r * 0.92, math.sin(a) * math.sin(b) * r * 0.92, math.cos(b) * r * 0.46 + 0.1)
            puffs.append(ik.transformed(ik.ico(rnd.uniform(0.5, 0.75), 1, (1.0, 1.0, 0.7), 0.2, 300 + k * 10 + j), location=at))
        obj = ik.make_object("Canopy%d" % (k + 1), ik.merged(base, *puffs), parent=trunk, location=tuple(Vector(tip) + Vector((0, 0, 0.3))))
        canopy.append(obj)
        canopy_base.append(len(base[1]))
    parts = [trunk, cord, paper] + canopy
    ik.tag_faces(trunk, lambda c, n, o: "bark")
    ik.set_tags(cord, "cord")
    ik.set_tags(paper, "paper")
    for c, nb in zip(canopy, canopy_base):
        ik.tag_faces(c, lambda cc, n, o: "canopy" if n.z > -0.3 else "canopy_under")
        c["paint_tags"] = list(c["paint_tags"])[:nb] + ["blossom"] * (len(c.data.polygons) - nb)
    for o in parts:
        ik.assign_material(o, "M_great_tree")
    ik.assign_material(cord, "M_tree_cord_sacred")
    tip_w = ik.chain_taper(strokes)

    def colors(co, local, n, tag):
        if tag == "cord":
            return (0.6, 0.0, 0.2)
        if tag == "paper":
            return (0.3, 0.5, 0.3)
        if tag == "blossom":
            return (0.5, 0.45, 0.5)
        if tag.startswith("canopy"):
            return (0.9, 0.35, 0.5)
        r = tip_w(co)
        under = 1.0 if n.z < -0.3 else 0.85
        return (r * under, 0.08 * ik.smoothstep(6, 12, co.z), 0.25 + 0.6 * (1 - r))
    meshes = finish("great_tree", parts, 1024, colors)
    ik.dump_paint_map(meshes, out_map, 1024, crease_deg=70.0)
    ik.store_rest(parts)
    hidden = {c.name: tucked(c) for c in canopy}
    ik.bake_animation("withered", canopy, {0: dict(hidden)}, 12, True)
    order = sorted(range(len(canopy)), key=lambda i: canopy[i].location.z)
    frames = {0: dict(hidden)}
    for rank, i in enumerate(order):
        f0 = 2 + rank * 2
        frames.setdefault(f0, {})[canopy[i].name] = {"scale": 0.35}
        frames.setdefault(f0 + 2, {})[canopy[i].name] = {"scale": 0.8}
        frames.setdefault(f0 + 4, {})[canopy[i].name] = {"scale": 1.12}
        frames.setdefault(f0 + 6, {})[canopy[i].name] = {"scale": 1.0}
    ik.bake_animation("bloom", canopy, frames, 36, False)
    for c in canopy:
        ik.apply_pose(c, tucked(c))
    collider = ik.make_object("TrunkCollider-convcolonly", ik.tube([(0, 0, -0.3), (0, 0, 6.0)], [1.25, 0.8], 8))
    ik.report("great_tree", meshes)
    ik.export_glb(out_glb, animated=True)


# ----------------------------------------------------------------------------- thorn gate
def build_thorn_gate(out_glb, out_map):
    rnd = random.Random(13)
    half = 3.8
    vf, strokes = [], []
    for side in (-1, 1):
        stump = gnarled((side * half, 0, -0.2), (side * -0.08, 0, 1), 1.8, 4, 0.12, rnd)
        vf.append(ik.tube(stump, [0.36, 0.3, 0.25, 0.2, 0.0], 6))
        strokes.append(ik.chain(stump, 1.0, 0.25))
        for k in range(2):
            fork = gnarled(stump[2], (side * rnd.uniform(-0.6, 0.2), rnd.uniform(-0.4, 0.4), 0.8), 0.8, 3, 0.3, rnd)
            vf.append(ik.tube(fork, [0.12, 0.09, 0.05, 0.0], 4))
            strokes.append(ik.chain(fork, 0.6, 0.05))
    spikes = []
    for k in range(8):
        y0 = rnd.uniform(0.2, 2.3)
        y1 = rnd.uniform(0.2, 2.3)
        sag = rnd.uniform(-0.6, 0.7)
        pts = []
        n = 12
        for i in range(n + 1):
            t = i / n
            x = -half + 2 * half * t
            z = y0 + (y1 - y0) * t + sag * math.sin(math.pi * t) + 0.12 * math.sin(t * 13 + k)
            y = 0.25 * math.sin(t * 7 + k * 1.3) + rnd.uniform(-0.05, 0.05)
            pts.append((x, y, max(0.05, z)))
        rad = [0.035 + 0.06 * math.sin(math.pi * (i / n)) for i in range(n + 1)]
        rad[0] = rad[-1] = 0.0
        vf.append(ik.tube(pts, rad, 5))
        strokes.append([(p, 0.15 + 0.85 * math.sin(math.pi * i / n)) for i, p in enumerate(pts)])
        for i in range(1, n, 1):
            if rnd.random() < 0.2:
                continue
            p = Vector(pts[i])
            dirv = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized()
            tip = p + dirv * rnd.uniform(0.18, 0.34)
            spikes.append(ik.cone(tuple(p), tuple(tip), rad[i] * 0.7, 3))
            strokes.append([(tuple(p + dirv * rad[i]), 0.45), (tuple(tip), 0.03)])
    thorns = ik.make_object("Thorns", ik.merged(*(vf + spikes)))
    ik.set_tags(thorns, "thorn")
    ik.assign_material(thorns, "M_thorn_gate")

    taper = ik.chain_taper(strokes)

    def colors(co, local, n, tag):
        r = taper(co) * (1.0 if n.z < 0 else 0.85)
        return (r, 0.05, 0.3 + 0.6 * (1 - r))
    meshes = finish("thorn_gate", [thorns], 512, colors, angle=60.0)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=80.0)
    ik.report("thorn_gate", meshes)
    ik.export_glb(out_glb)


# ----------------------------------------------------------------------------- shrine
def build_shrine(out_glb, out_map):
    stone = ik.merged(box(1.9, 1.5, 0.36, taper=0.96), box(1.0, 0.36, 0.18, cy=0.92), box(1.2, 1.0, 0.08, cz=0.36))
    base = ik.make_object("Plinth", stone)
    posts = []
    for x in (-0.48, 0.48):
        for y in (-0.38, 0.38):
            posts.append(box(0.09, 0.09, 1.2, cx=x, cy=y, cz=0.44))
    posts.append(box(1.08, 0.08, 0.08, cy=0.38, cz=1.5))
    post_obj = ik.make_object("Posts", ik.merged(*posts), parent=base)
    walls = ik.merged(box(0.9, 0.04, 0.86, cy=-0.38, cz=0.56), box(0.04, 0.72, 0.86, cx=-0.48, cz=0.56),
                      box(0.04, 0.72, 0.86, cx=0.48, cz=0.56), box(0.9, 0.7, 0.05, cz=0.5))
    wall_obj = ik.make_object("Walls", walls, parent=base)
    # gabled roof with lifted eave corners
    rv = []
    for y in (-0.75, 0.75):
        lift = 0.1
        rv += [(-0.85, y * 1.0, 1.52 + lift), (0.0, y * 0.95, 2.2), (0.85, y * 1.0, 1.52 + lift)]
    rv += [(-0.78, -0.68, 1.62), (0.0, -0.64, 2.1), (0.78, -0.68, 1.62)]
    rv += [(-0.78, 0.68, 1.62), (0.0, 0.64, 2.1), (0.78, 0.68, 1.62)]
    rf = [(0, 1, 4, 3), (1, 2, 5, 4), (6, 9, 10, 7), (7, 10, 11, 8), (0, 3, 9, 6), (2, 8, 11, 5), (0, 6, 7, 1), (1, 7, 8, 2), (3, 4, 10, 9), (4, 5, 11, 10)]
    roof = ik.make_object("Roof", (rv, rf), parent=base)
    gold = ik.merged(box(0.08, 1.5, 0.07, cz=2.18), ik.transformed(ik.ico(0.07, 1), location=(0, 0.45, 1.4)),
                     ik.transformed(ik.ico(0.05, 1), location=(-0.4, 0.75, 1.6)), ik.transformed(ik.ico(0.05, 1), location=(0.4, 0.75, 1.6)))
    gold_obj = ik.make_object("Gold", gold, parent=base)
    parts = [base, post_obj, wall_obj, roof, gold_obj]
    ik.set_tags(base, "stone")
    ik.set_tags(post_obj, "post")
    ik.set_tags(wall_obj, "paper")
    ik.set_tags(roof, "wood")
    ik.set_tags(gold_obj, "gold")
    for o in (base, wall_obj, roof):
        ik.assign_material(o, "M_shrine")
    ik.assign_material(post_obj, "M_shrine_posts_sacred")
    ik.assign_material(gold_obj, "M_shrine_gold_sacred")

    def colors(co, local, n, tag):
        if tag == "gold":
            return (0.4, 0.0, 0.2)
        if tag == "roof" or tag == "wood":
            return (1.0 if n.z < 0 else 0.8, 0.0, 0.4)
        return (0.9, 0.0, 0.35)
    meshes = finish("shrine", parts, 512, colors, angle=35.0)
    collider = ik.make_object("ShrineCollider-convcolonly", box(1.9, 1.5, 2.2))
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=30.0)
    ik.report("shrine", meshes)
    ik.export_glb(out_glb)


# ----------------------------------------------------------------------------- stones and rocks
def boulder(r, squash, seed, sink=0.25, subdiv=1):
    v, f = ik.ico(r, subdiv, squash, 0.22, seed)
    v = [(x, y, max(z + r * squash[2] * (1 - sink), -0.05) if z < 0 else z + r * squash[2] * (1 - sink)) for x, y, z in v]
    return v, f


def rock_colors(co, local, n, tag):
    under = 1.0 if n.z < 0.2 else 0.7
    return (under, 0.0, 0.4 + 0.3 * ik.hash01(co.x * 3, co.y * 5, co.z * 7))


def build_stepping_stone(out_glb, out_map):
    rnd = random.Random(3)
    sections = []
    for z, r in ((-1.9, 0.78), (-0.6, 0.7), (0.05, 0.62), (0.18, 0.5)):
        ring = []
        for s in range(8):
            a = 2 * math.pi * s / 8 + 0.2
            rr = r * (1.0 + 0.1 * math.sin(a * 3 + 1.0)) * (1.12 if s in (1, 5) else 1.0)
            ring.append((math.cos(a) * rr, math.sin(a) * rr * 0.85, z + (rnd.uniform(-0.02, 0.02) if z > 0 else 0)))
        sections.append(ring)
    sections.append([(0.03, 0.0, 0.22)])
    stone = ik.make_object("Stone-convcol", ik.loft(sections))
    ik.tag_faces(stone, lambda c, n, o: "stone_top" if c.z > 0.1 else ("stone_wet" if c.z < -0.25 else "stone"))
    ik.assign_material(stone, "M_stepping_stone")
    meshes = finish("stepping_stone", [stone], 512, rock_colors)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=25.0)
    ik.report("stepping_stone", meshes)
    ik.export_glb(out_glb)


def build_rocks(out_glb, out_map):
    rocks = []
    for name, r, sq, loc, seed in (("RockA-convcol", 1.0, (1.1, 0.9, 0.75), (0, 0, 0), 5),
                                   ("RockB-convcol", 0.62, (1.0, 1.2, 0.8), (1.25, 0.55, 0), 6),
                                   ("RockC-convcol", 0.38, (1.2, 1.0, 0.7), (-0.95, 0.85, 0), 7)):
        rocks.append(ik.make_object(name, boulder(r, sq, seed, subdiv=2), location=loc))
    for o in rocks:
        ik.tag_faces(o, lambda c, n, o: "stone_top" if n.z > 0.75 else "stone")
        ik.assign_material(o, "M_rocks")
    meshes = finish("rocks", rocks, 512, rock_colors)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=25.0)
    ik.report("rocks", meshes)
    ik.export_glb(out_glb)


def build_reeds(out_glb, out_map):
    rnd = random.Random(29)
    vf, heads = [], []
    for k in range(16):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.0, 0.35)
        base = (math.cos(a) * r, math.sin(a) * r, -0.05)
        h = rnd.uniform(0.75, 1.55)
        lean = (math.cos(a) * rnd.uniform(0.05, 0.3), math.sin(a) * rnd.uniform(0.05, 0.3))
        pts = [(base[0] + lean[0] * t * t, base[1] + lean[1] * t * t, base[2] + h * t) for t in (0, 0.35, 0.7, 1.0)]
        vf.append(ik.tube(pts, [0.022, 0.018, 0.011, 0.0], 3))
        if k % 5 == 0:
            top = Vector(pts[2])
            heads.append(ik.tube([tuple(top), tuple(top + Vector((lean[0] * 0.1, lean[1] * 0.1, 0.16)))], [0.028, 0.0], 4))
    reeds = ik.make_object("Reeds", ik.merged(*vf))
    head_obj = ik.make_object("Heads", ik.merged(*heads), parent=reeds)
    ik.set_tags(reeds, "reed")
    ik.set_tags(head_obj, "reed_head")
    for o in (reeds, head_obj):
        ik.assign_material(o, "M_reeds")

    def colors(co, local, n, tag):
        tip = 0.06 + 0.94 * ik.smoothstep(1.55, 0.35, co.z) if tag == "reed" else 0.6
        return (tip, ik.smoothstep(0.1, 1.4, co.z), 0.3 + 0.5 * (1 - tip))
    meshes = finish("reeds", [reeds, head_obj], 512, colors, angle=60.0)
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=80.0)
    ik.report("reeds", meshes)
    ik.export_glb(out_glb)


# ----------------------------------------------------------------------------- raft
def build_raft(out_glb, out_map):
    """Pell's pole raft: seven lashed logs, two battens, a stern post with a paper lantern.
    Origin at the waterline, bow toward +Y (Godot -Z), deck top (battens) at Z = 0.17."""
    rnd = random.Random(61)
    logs = []
    for k in range(7):
        x = (k - 3) * 0.205
        r = 0.1 * rnd.uniform(0.92, 1.08)
        bow = 1.42 - 0.05 * abs(k - 3) ** 1.6 + rnd.uniform(-0.04, 0.04)
        stern = -1.3 + rnd.uniform(-0.05, 0.05)
        pts = [(x, stern, 0.0), (x, 0.0, rnd.uniform(-0.01, 0.01)), (x, bow - 0.12, 0.02), (x, bow, 0.06)]
        logs.append(ik.tube(pts, [r, r, r * 0.95, r * 0.7], 6))
    deck = ik.make_object("Deck", ik.merged(*logs))
    battens = ik.make_object("Battens", ik.merged(*[box(1.62, 0.14, 0.07, cy=y, cz=0.1) for y in (0.95, -0.9)]), parent=deck)
    bands = []
    for y in (1.06, 0.84, -0.79, -1.01):
        ring = [(-0.76, y, 0.12), (0.76, y, 0.12), (0.8, y, -0.02), (0.76, y, -0.1), (-0.76, y, -0.1), (-0.8, y, -0.02), (-0.76, y, 0.12)]
        bands.append(ik.tube(ring, [0.022] * len(ring), 3, cap=False))
    rope = ik.make_object("Lashings", ik.merged(*bands), parent=deck)
    post = ik.make_object("Post", ik.merged(box(0.07, 0.07, 1.05, cx=0.52, cy=-1.08, cz=0.1),
                                            box(0.05, 0.36, 0.05, cx=0.52, cy=-0.94, cz=1.08, taper=0.9)), parent=deck)
    lantern = []
    for z, r in ((0.72, 0.0), (0.74, 0.075), (0.82, 0.105), (0.92, 0.1), (0.98, 0.07), (1.0, 0.0)):
        lantern.append([(0.52 + math.cos(2 * math.pi * s / 6) * r, -0.8 + math.sin(2 * math.pi * s / 6) * r, z) for s in range(6)] if r else [(0.52, -0.8, z)])
    lamp = ik.make_object("Lantern", ik.merged(ik.loft(lantern), box(0.012, 0.012, 0.08, cx=0.52, cy=-0.8, cz=1.0)), parent=deck)
    parts = [deck, battens, rope, post, lamp]
    ik.set_tags(deck, "driftwood")
    ik.set_tags(battens, "wood")
    ik.set_tags(rope, "rope")
    ik.set_tags(post, "wood")
    ik.tag_faces(lamp, lambda c, n, o: "paper" if 0.75 < c.z < 0.97 else "gold")
    for o in parts:
        ik.assign_material(o, "M_raft")

    def colors(co, local, n, tag):
        if tag in ("rope", "gold"):
            return (0.5, 0.0, 0.2)
        if tag == "paper":
            return (0.9, 0.0, 0.35)
        return (1.0 if n.z < 0 else 0.85, 0.0, 0.4)
    meshes = finish("raft", parts, 512, colors, angle=40.0)
    ik.make_object("RaftCollider-convcolonly", box(1.5, 2.7, 0.3, cy=0.05, cz=-0.13))
    ik.dump_paint_map(meshes, out_map, 512, crease_deg=30.0)
    ik.store_rest([deck])
    frames = {0: {}, 6: {"Deck": {"loc": (0, 0, 0.025), "rot": (1.2, -0.8, 0)}}, 12: {"Deck": {"loc": (0, 0, 0.01), "rot": (0, 0.9, 0)}},
              18: {"Deck": {"loc": (0, 0, -0.02), "rot": (-1.1, 0.2, 0)}}}
    ik.bake_animation("bob", [deck], frames, 24, True)
    ik.report("raft", meshes)
    ik.export_glb(out_glb, animated=True)


BUILDERS = {
    "sapling": build_sapling, "great_tree": build_great_tree, "thorn_gate": build_thorn_gate, "shrine": build_shrine,
    "stepping_stone": build_stepping_stone, "rocks": build_rocks, "reeds": build_reeds, "raft": build_raft,
}


def build(name):
    out_glb, out_map = ik.cli_args()[:2]
    ik.reset()
    BUILDERS[name](out_glb, out_map)
