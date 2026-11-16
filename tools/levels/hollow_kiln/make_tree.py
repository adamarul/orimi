"""The tree that grows up through the kiln at the end of the Hollow Kiln (Bloom on the cracked vat).

    blender --background --factory-startup --python tools/levels/hollow_kiln/make_tree.py -- vat_tree <out.glb> <paintmap.json>

Origin at the vat's centre on the chamber floor (Godot y = 18). The trunk rises out of the vat
and through the dome's oculus (radius 2.6 m, 32 m up), the limbs spread wide over the dome from 40 m, and
six roots climb over the vat's rim and run out across the floor, where the clear river starts.
The canopy is green with vermilion and pink blossom: the kiln-vermilion bead.

Clips (12 fps, STEP): hidden (1 s loop: nothing shows), grow (3.5 s: roots, trunk, limbs, then
the canopy cluster by cluster), grown (2 s loop: a little sway).
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


def gnarled(start, direction, length, segments, wander, rnd, up_bias=0.0):
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    step = length / segments
    for _ in range(segments):
        d = (d + Vector((rnd.uniform(-wander, wander), rnd.uniform(-wander, wander), rnd.uniform(-wander, wander) + up_bias))).normalized()
        pts.append(pts[-1] + d * step)
    return pts


def mk(name, vf, tag, parent=None, location=(0, 0, 0)):
    o = ik.make_object(name, vf, parent=parent, location=location)
    ik.set_tags(o, tag)
    ik.assign_material(o, "M_vat_tree")
    return o


def build(out_glb, out_map):
    rnd = random.Random(19)
    strokes = []
    # trunk: out of the vat (inner floor 1 m up), through the oculus at 32 m, on to 46 m, where the crown spreads over the dome
    trunk_pts = [Vector((0, 0, 0.6)), Vector((0.3, 0.2, 5.0)), Vector((-0.2, 0.3, 10.0)), Vector((0.25, -0.2, 16.0)), Vector((-0.1, 0.1, 22.0)),
                 Vector((0.1, 0.0, 28.0)), Vector((0.0, 0.1, 34.0)), Vector((0.3, -0.2, 40.0)), Vector((0.1, 0.1, 46.0))]
    trunk = mk("Trunk", ik.tube([tuple(p) for p in trunk_pts], [1.9, 1.7, 1.5, 1.35, 1.2, 1.05, 0.95, 1.15, 0.7], 10), "bark")
    strokes.append(ik.chain([tuple(p) for p in trunk_pts], 1.0, 0.8))
    roots = []
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.25
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = d * 1.2 + Vector((0, 0, 3.6))
        p1 = d * 4.2 + Vector((0, 0, 4.9))
        p2 = d * 5.6 + Vector((0, 0, 4.2))
        p3 = d * 6.2 + Vector((0, 0, 0.6))
        p4 = d * rnd.uniform(9.0, 12.5) + Vector((rnd.uniform(-1.5, 1.5), rnd.uniform(-1.5, 1.5), 0.15))
        pts = [p0, p1, p2, p3, p4]
        o = mk("Root%d" % k, ik.tube([tuple(p) for p in pts], [0.75, 0.6, 0.5, 0.42, 0.0], 6), "root", parent=trunk)
        roots.append(o)
        strokes.append(ik.chain([tuple(p) for p in pts], 0.95, 0.05))
    limbs, tips = [], []
    for k, (yaw, pitch, ln) in enumerate(((10, 18, 15.0), (80, 22, 14.0), (155, 16, 15.5), (230, 20, 14.5), (300, 26, 12.5))):
        base = trunk_pts[-2] + Vector((0, 0, rnd.uniform(-0.5, 3.0)))
        d = (math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch)))
        limb = gnarled(base, d, ln, 5, 0.16, rnd)
        vf = [ik.tube([tuple(p) for p in limb], [0.75, 0.6, 0.48, 0.36, 0.24, 0.0], 6)]
        strokes.append(ik.chain([tuple(p) for p in limb], 0.85, 0.06))
        tips.append(limb[-1])
        sb = limb[2]
        sd = (d[0] + rnd.uniform(-0.7, 0.7), d[1] + rnd.uniform(-0.7, 0.7), d[2] + rnd.uniform(0.0, 0.5))
        br = gnarled(sb, sd, ln * 0.5, 3, 0.25, rnd)
        vf.append(ik.tube([tuple(p) for p in br], [0.32, 0.22, 0.12, 0.0], 5))
        strokes.append(ik.chain([tuple(p) for p in br], 0.5, 0.04))
        if k % 2 == 0:
            tips.append(br[-1])
        merged = ik.merged(*vf)
        o = mk("Limb%d" % k, ([tuple(Vector(v) - base) for v in merged[0]], merged[1]), "bark", parent=trunk, location=tuple(base))
        limbs.append(o)
    canopy = []
    for k, tip in enumerate(tips[:8]):
        r = rnd.uniform(4.6, 5.8)
        base_vf = ik.ico(r, 1, (1.0, 1.0, 0.55), 0.16, 600 + k)
        puffs = []
        for j in range(4):
            a, b = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.2, 1.0)
            at = (math.cos(a) * math.sin(b) * r * 0.9, math.sin(a) * math.sin(b) * r * 0.9, math.cos(b) * r * 0.5 + 0.2)
            puffs.append(ik.transformed(ik.ico(rnd.uniform(0.9, 1.3), 1, (1.0, 1.0, 0.7), 0.2, 700 + k * 10 + j), location=at))
        o = ik.make_object("Canopy%d" % k, ik.merged(base_vf, *puffs), parent=trunk, location=tuple(Vector(tip) + Vector((0, 0, 0.6))))
        ik.assign_material(o, "M_vat_tree")
        nb = len(base_vf[1])
        ik.tag_faces(o, lambda c, n, oo: "canopy" if n.z > -0.3 else "canopy_under")
        tags = list(o["paint_tags"])
        o["paint_tags"] = tags[:nb] + [("blossom_red" if (j // 80) % 2 == 0 else "blossom") for j in range(len(tags) - nb)]
        canopy.append(o)
    parts = [trunk] + roots + limbs + canopy
    taper = ik.chain_taper(strokes)

    def colors(co, local, n, tag):
        if tag.startswith("canopy"):
            return (0.9, 0.35, 0.5)
        if tag.startswith("blossom"):
            return (0.5, 0.45, 0.5)
        r = taper(co)
        return (r * (1.0 if n.z < -0.3 else 0.85), 0.05 * ik.smoothstep(25, 40, co.z), 0.25 + 0.6 * (1 - r))
    for o in parts:
        ik.paint_vertex_colors(o, colors)
    meshes = [o for o in parts if o.type == "MESH"]
    ik.smart_uv(meshes, angle=45.0, margin=0.012)
    ik.dump_paint_map(meshes, out_map, 1024, crease_deg=70.0)
    ik.store_rest(parts)

    def hidden(o, d=6.0):
        return {"scale": 0.01, "loc": tuple(-o.location + Vector((0.0, 0.0, -d)))}

    ik.bake_animation("hidden", parts, {0: {trunk.name: {"scale": 0.01, "loc": (0, 0, -6.0)}}}, 12, True)
    fr = {0: {trunk.name: {"scale": (0.3, 0.3, 0.02)}, **{o.name: hidden(o) for o in limbs + canopy}, **{o.name: {"scale": 0.05} for o in roots}}}
    for f, t in ((2, 0.1), (4, 0.25), (6, 0.45), (8, 0.65), (10, 0.85), (12, 1.0)):
        fr[f] = {trunk.name: {"scale": (0.4 + 0.6 * t, 0.4 + 0.6 * t, t)}, **{o.name: hidden(o) for o in limbs + canopy},
                 **{o.name: {"scale": min(1.0, 0.05 + 1.1 * t)} for o in roots}}
    for f, t in ((14, 0.3), (16, 0.6), (18, 0.85), (20, 1.0)):
        fr[f] = {o.name: {"scale": t} for o in limbs}
        fr[f].update({o.name: hidden(o) for o in canopy})
    order = sorted(range(len(canopy)), key=lambda i: canopy[i].location.z)
    for rank, i in enumerate(order):
        f0 = 21 + rank * 2
        fr.setdefault(f0, {})[canopy[i].name] = {"scale": 0.35}
        fr.setdefault(f0 + 2, {})[canopy[i].name] = {"scale": 0.85}
        fr.setdefault(f0 + 4, {})[canopy[i].name] = {"scale": 1.12}
        fr.setdefault(f0 + 6, {})[canopy[i].name] = {"scale": 1.0}
    for f in range(21, 42):
        fr.setdefault(f, {})
    # a canopy hidden on frame 20 stays hidden until its own key: fill those gaps explicitly
    for i in order:
        first = min(f for f in fr if canopy[i].name in fr[f] and f > 20)
        for f in fr:
            if 20 < f < first:
                fr[f][canopy[i].name] = hidden(canopy[i])
    ik.bake_animation("grow", parts, fr, 42, False)
    sway = {}
    for f in range(0, 24, 3):
        ph = 2 * math.pi * f / 24
        sway[f] = {c.name: {"scale": 1.0 + 0.025 * math.sin(ph + k), "rot": (0, 0, 1.5 * math.sin(ph + k * 0.7))} for k, c in enumerate(canopy)}
    ik.bake_animation("grown", parts, sway, 24, True)
    ik.apply_pose(trunk, {"scale": 0.01, "loc": (0, 0, -6.0)})
    ik.report("vat_tree", meshes)
    ik.export_glb(out_glb, animated=True)


if __name__ == "__main__":
    _, out_glb, out_map = ik.cli_args()[:3]
    ik.reset()
    build(out_glb, out_map)
