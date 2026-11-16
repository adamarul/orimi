"""The Dregs: what stayed at the bottom of the Ink-maker's vat. The boss of the Hollow Kiln.

    blender --background --factory-startup --python tools/levels/hollow_kiln/make_dregs.py -- dregs <out.glb> <paintmap.json>

A slumped mound of tarry ink that rises out of the vat, two pale thumbprint eyes in a heavy brow,
four long ink arms that end in splayed brush tips, a veil of soot puffs, and a crust of cracked
flakes that only shows as it dries. Rigid parts, no skinning; every clip is keyed at 12 fps with
STEP interpolation. The origin sits on the vat's rim (Godot y = rim); the front faces -Z; the
chamber floor is 4.5 m below the origin.

Clips (seconds at 12 fps):
  veiled    2.0 loop   wrapped in soot, breathing; arms hidden (part 1, Gust)
  veil_off  1.0        the soot blows off outward
  idle      2.0 loop   unveiled, arms raised and curling
  lash_l    3.0        front-left arm: wind-up 0.83 s (the tell), slam 0.17 s, lies on the floor 1.58 s
                       (the window for a Slash), pulls back 0.42 s (part 2, Slash)
  lash_r    3.0        the same with the front-right arm
  hurt      0.5        flinch
  climb     1.33 loop  hauling up the chains, arms reaching in pairs (part 3, Tie); the level moves the node
  bound     1.0 loop   arms pinned, shuddering
  dry       3.0        drying out: shrinks, crust flakes appear, arms droop; seek 1 s per kiln mouth lit (part 4, Kindle)
  unravel   1.5        the dried husk comes apart
Arm segments are named Arm<a>_<k> (a 0 front-left, 1 front-right, 2 back-left, 3 back-right; k 0 root to 5 tip),
so the level can hide a severed arm.
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

SEG_LEN = [2.6, 2.4, 2.2, 2.0, 1.8, 1.6]
SEG_R = [0.62, 0.52, 0.42, 0.33, 0.25, 0.18]
REST_PITCH = [40.0, 20.0, 0.0, -20.0, -35.0, -40.0]      # absolute pitch of each segment in the idle pose
ARM_YAW = [35.0, -35.0, 140.0, -140.0]                   # Blender Z yaw; + turns the front (+Y) toward -X
ARM_ROOT = [(-1.5, 1.0, 3.2), (1.5, 1.0, 3.2), (-1.4, -1.0, 3.0), (1.4, -1.0, 3.0)]   # Blender space


def mk(name, vf, tag, material, parent=None, location=(0, 0, 0), rotation=(0, 0, 0)):
    o = ik.make_object(name, vf, parent=parent, location=location, rotation_deg=rotation)
    ik.set_tags(o, tag)
    ik.assign_material(o, material)
    return o


def body_vf(rnd):
    rings = []
    prof = [(-2.0, 3.4), (-0.5, 3.5), (0.8, 3.2), (2.0, 2.8), (3.2, 2.5), (4.2, 2.1), (5.0, 1.6), (5.6, 0.9)]
    for z, r in prof:
        ring = []
        for k in range(12):
            a = 2 * math.pi * k / 12
            rr = r * (1 + 0.1 * math.sin(a * 3 + z) + rnd.uniform(-0.05, 0.05))
            fwd = 0.5 if math.sin(a) > 0 else 0.0
            ring.append((math.cos(a) * rr, math.sin(a) * rr * 0.9 + (0.4 if z > 3.5 else 0.0), z))
        rings.append(ring)
    rings.append([(0.0, 0.3, 5.9)])
    parts = [ik.loft(rings)]
    # drips and lumps on the shoulders, the brow over the eyes
    for k, (x, y, z, r) in enumerate(((-2.2, 0.6, 3.4, 1.0), (2.1, 0.4, 3.6, 0.95), (-1.0, -1.6, 4.0, 1.1), (1.2, -1.5, 3.8, 1.0),
                                      (0.0, 1.9, 4.9, 1.25), (-2.6, 1.0, 1.0, 0.9), (2.7, 0.8, 1.4, 0.9))):
        v, f = ik.ico(r, 1, (1.0, 1.0, 0.8), 0.22, 300 + k)
        parts.append(([(vx + x, vy + y, vz + z) for vx, vy, vz in v], f))
    for k, (x, y, z0, ln) in enumerate(((-2.9, 1.2, 2.6, 1.8), (2.8, 1.5, 3.0, 2.2), (-0.6, 2.8, 4.2, 1.6), (1.4, 2.6, 4.0, 2.4))):
        parts.append(ik.tube([(x, y, z0), (x * 1.02, y * 1.05, z0 - ln * 0.6), (x * 1.04, y * 1.08, z0 - ln)], [0.3, 0.2, 0.0], 5))
    return ik.merged(*parts)


def seg_vf(k):
    ln, r0 = SEG_LEN[k], SEG_R[k]
    r1 = SEG_R[k + 1] if k + 1 < len(SEG_R) else r0 * 0.6
    parts = [ik.tube([(0, -0.15, 0), (0, ln * 0.5, 0.0), (0, ln + 0.1, 0)], [r0, (r0 + r1) / 2 * 1.08, r1], 6)]
    if k == len(SEG_LEN) - 1:
        # splayed brush tip: a fan of tapering bristle tufts
        for j in range(5):
            a = math.radians(-40 + 20 * j)
            parts.append(ik.tube([(0, ln, 0), (math.sin(a) * 0.35, ln + 0.7, 0.05 * j - 0.1), (math.sin(a) * 0.6, ln + 1.3, -0.1)], [0.14, 0.08, 0.0], 4))
    return ik.merged(*parts)


def build(out_glb, out_map):
    rnd = random.Random(5)
    body = mk("Body", body_vf(rnd), "ink", "M_dregs")
    ik.tag_faces(body, lambda c, n, o: "ink")
    eyes = mk("Eyes", ik.merged(*[ik.transformed(ik.ico(0.42, 1, (1.0, 0.45, 0.8), 0.06, 70 + i), location=(sx * 0.72, 2.95, 4.85))
                                  for i, sx in enumerate((-1, 1))]), "eye", "M_dregs", parent=body)
    small = mk("SmallEyes", ik.merged(*[ik.transformed(ik.ico(0.16, 1, (1.0, 0.5, 1.0), 0.1, 90 + i), location=p)
                                        for i, p in enumerate(((-2.3, 1.5, 3.6), (2.2, 1.6, 2.4), (-1.5, 2.2, 1.0)))]), "eye", "M_dregs", parent=body)
    # crust: flakes of dried ink over the back and shoulders (hidden until it dries)
    flakes = []
    for k in range(10):
        a = math.radians(-160 + k * 36 + rnd.uniform(-10, 10))
        z = rnd.uniform(1.6, 5.0)
        r = 2.9 - 0.25 * (z - 1.6)
        p = Vector((math.cos(a) * r, math.sin(a) * r * 0.9, z))
        n = Vector((math.cos(a), math.sin(a), 0.3)).normalized()
        t1 = n.cross(Vector((0, 0, 1))).normalized()
        t2 = n.cross(t1).normalized()
        pts = []
        for j in range(6):
            b = 2 * math.pi * j / 6
            rr = rnd.uniform(0.5, 0.85)
            pts.append(p + (t1 * math.cos(b) + t2 * math.sin(b)) * rr)
        top = [tuple(q + n * 0.12) for q in pts]
        bot = [tuple(q - n * 0.05) for q in pts]
        f = mk("Flake%d" % k, ik.loft([bot, top]), "flake", "M_dregs", parent=body)
        flakes.append(f)
    veil = []
    for k in range(12):
        if k < 8:
            a = 2 * math.pi * k / 8 + 0.2
            p = (math.cos(a) * 3.2, math.sin(a) * 3.0, rnd.uniform(1.5, 4.5))
            r = rnd.uniform(1.7, 2.2)
        else:
            a = 2 * math.pi * (k - 8) / 4 + 0.6
            p = (math.cos(a) * 1.4, math.sin(a) * 1.4, rnd.uniform(5.8, 7.0))
            r = rnd.uniform(1.6, 2.0)
        v, f = ik.ico(r, 1, (1.0, 1.0, 0.85), 0.25, 400 + k)
        veil.append(mk("Veil%d" % k, (v, f), "veil", "M_dregs_veil", parent=body, location=p))
    arms = []
    for a in range(4):
        segs = []
        parent = body
        for k in range(len(SEG_LEN)):
            if k == 0:
                loc, rot = ARM_ROOT[a], (REST_PITCH[0], 0.0, ARM_YAW[a])
            else:
                loc, rot = (0.0, SEG_LEN[k - 1], 0.0), (REST_PITCH[k] - REST_PITCH[k - 1], 0.0, 0.0)
            s = mk("Arm%d_%d" % (a, k), seg_vf(k), "arm", "M_dregs", parent=parent, location=loc, rotation=rot)
            segs.append(s)
            parent = s
        arms.append(segs)
    bpy.context.view_layer.update()
    strokes = []
    for segs in arms:
        pts = [(s.matrix_world @ Vector((0, 0, 0)), 1.0 - 0.15 * i) for i, s in enumerate(segs)]
        pts.append((segs[-1].matrix_world @ Vector((0, SEG_LEN[-1] + 1.2, 0)), 0.05))
        strokes.append(pts)
    taper = ik.chain_taper(strokes)

    def colors(co, local, n, tag):
        if tag == "veil":
            return (0.4, 0.0, 0.85)
        if tag == "eye":
            return (0.3, 0.0, 0.3)
        if tag == "flake":
            return (0.6, 0.0, 0.5)
        if tag == "arm":
            return (max(0.1, taper(co)), 0.0, 0.3 + 0.5 * (1 - taper(co)))
        return (1.0 if n.z < 0.2 else 0.8, 0.0, 0.3)
    parts = [body, eyes, small] + flakes + veil + [s for segs in arms for s in segs]
    for o in parts:
        ik.paint_vertex_colors(o, colors)
    meshes = [o for o in parts if o.type == "MESH"]
    ik.smart_uv(meshes, angle=50.0, margin=0.01)
    ik.dump_paint_map(meshes, out_map, 1024, crease_deg=70.0)

    # ------------------------------------------------------------------ animation
    ik.store_rest(parts)
    hidden = lambda o, d=4.0: {"scale": 0.01, "loc": tuple(-o.location + Vector((0.0, 0.0, -d)))}  # noqa: E731
    all_arms = [s for segs in arms for s in segs]
    no_flakes = {f.name: hidden(f) for f in flakes}
    no_veil = {v.name: hidden(v) for v in veil}
    no_arms = {segs[0].name: hidden(segs[0]) for segs in arms}

    def arm_pose(a, pitches, yaw=0.0, scale=None):
        out = {}
        for k, p in enumerate(pitches):
            rel = p - (pitches[k - 1] if k else 0.0)
            rest_rel = REST_PITCH[k] - (REST_PITCH[k - 1] if k else 0.0)
            pose = {"rot": (rel - rest_rel, 0.0, yaw if k == 0 else 0.0)}
            if scale is not None and k == 0:
                pose["scale"] = scale
            out[arms[a][k].name] = pose
        return out

    def merge(*ds):
        out = {}
        for d in ds:
            out.update(d)
        return out

    def curl(a, phase):
        s = math.sin(phase)
        return arm_pose(a, [40 + 8 * s, 22 + 10 * s, 4 + 12 * s, -14 + 12 * s, -30 + 10 * s, -38 + 8 * s], yaw=6 * math.cos(phase))

    def breathe(sc):
        return {body.name: {"scale": (sc, sc, 1.0 / sc)}}

    # veiled: soot all round, body hunched, arms hidden
    fr = {}
    for f in range(0, 24, 3):
        s = 1.0 + 0.05 * math.sin(2 * math.pi * f / 24)
        fr[f] = merge(no_flakes, no_arms, {body.name: {"scale": (0.95, 0.95, 0.85)}},
                      {v.name: {"scale": s + 0.04 * math.sin(i + f)} for i, v in enumerate(veil)})
    ik.bake_animation("veiled", parts, fr, 24, True)
    # veil_off: the puffs blow outward and thin away
    fr = {0: merge(no_flakes, no_arms, {body.name: {"scale": (0.95, 0.95, 0.85)}})}
    for f, t in ((2, 0.25), (4, 0.5), (6, 0.75), (8, 0.95)):
        d = {}
        for v in veil:
            out = Vector((v.location.x, v.location.y, 0)).normalized() * 4.0 * t + Vector((0, 0, 1.5 * t))
            d[v.name] = {"loc": tuple(out), "scale": 1.0 - 0.85 * t}
        fr[f] = merge(no_flakes, d, arm_pose(0, [0, -10, -20, -30, -30, -30], scale=t), arm_pose(1, [0, -10, -20, -30, -30, -30], scale=t),
                      arm_pose(2, [0, -10, -20, -30, -30, -30], scale=t), arm_pose(3, [0, -10, -20, -30, -30, -30], scale=t))
    fr[10] = merge(no_flakes, no_veil)
    ik.bake_animation("veil_off", parts, fr, 12, False)
    # idle
    fr = {}
    for f in range(0, 24, 2):
        ph = 2 * math.pi * f / 24
        fr[f] = merge(no_flakes, no_veil, breathe(1.0 + 0.03 * math.sin(ph)), curl(0, ph), curl(1, ph + 1.5), curl(2, ph + 3.0), curl(3, ph + 4.5))
    ik.bake_animation("idle", parts, fr, 24, True)
    # lashes: wind-up (the tell), slam, lie on the floor (the Slash window), pull back
    windup = [80, 70, 55, 40, 30, 20]
    slam = [-20, -60, -72, -55, -15, 0]
    for clip, a, yaw in (("lash_l", 0, -35.0), ("lash_r", 1, 35.0)):
        others = [o for o in range(4) if o != a]
        fr = {}
        for f in (0, 3, 6, 8):
            t = f / 8
            pitches = [REST_PITCH[k] + (windup[k] - REST_PITCH[k]) * t for k in range(6)]
            fr[f] = merge(no_flakes, no_veil, {body.name: {"rot": (-6 * t, 0, 0), "scale": (1, 1, 1.0 + 0.08 * t)}},
                          arm_pose(a, pitches, yaw * t), *[curl(o, f * 0.3 + o) for o in others])
        fr[10] = merge(no_flakes, no_veil, {body.name: {"rot": (10, 0, 0)}}, arm_pose(a, [20, -20, -50, -40, -10, 0], yaw), *[curl(o, 3 + o) for o in others])
        fr[11] = merge(no_flakes, no_veil, {body.name: {"rot": (12, 0, 0), "scale": (1.04, 1.04, 0.95)}}, arm_pose(a, slam, yaw), *[curl(o, 3.3 + o) for o in others])
        for f in range(14, 30, 3):
            q = 2.0 * math.sin(f * 1.7)
            fr[f] = merge(no_flakes, no_veil, {body.name: {"rot": (8, 0, 0)}}, arm_pose(a, [p + (q if k > 2 else 0) for k, p in enumerate(slam)], yaw),
                          *[curl(o, f * 0.3 + o) for o in others])
        fr[31] = merge(no_flakes, no_veil, arm_pose(a, [10, -20, -30, -30, -25, -20], yaw * 0.6), *[curl(o, 10 + o) for o in others])
        fr[34] = merge(no_flakes, no_veil, arm_pose(a, REST_PITCH, yaw * 0.2), *[curl(o, 11 + o) for o in others])
        fr[36] = merge(no_flakes, no_veil)
        ik.bake_animation(clip, parts, fr, 36, False)
    # hurt
    fr = {0: merge(no_flakes, no_veil), 1: merge(no_flakes, no_veil, {body.name: {"rot": (-14, 0, 0), "scale": (1.08, 1.08, 0.88)}}),
          3: merge(no_flakes, no_veil, {body.name: {"rot": (-6, 0, 4), "scale": (0.96, 0.96, 1.05)}}), 6: merge(no_flakes, no_veil)}
    ik.bake_animation("hurt", parts, fr, 6, False)
    # climb: arms reach up the chains in pairs and haul
    up = [80, 85, 80, 70, 60, 50]
    haul = [60, 30, 0, -20, -35, -40]
    fr = {}
    for f in range(0, 16, 2):
        t = 0.5 + 0.5 * math.sin(2 * math.pi * f / 16)
        u = [haul[k] + (up[k] - haul[k]) * t for k in range(6)]
        w = [haul[k] + (up[k] - haul[k]) * (1 - t) for k in range(6)]
        fr[f] = merge(no_flakes, no_veil, {body.name: {"scale": (0.85, 0.85, 1.25 - 0.08 * t)}},
                      arm_pose(0, u, 20), arm_pose(3, u, -20), arm_pose(1, w, -20), arm_pose(2, w, 20))
    ik.bake_animation("climb", parts, fr, 16, True)
    # bound: arms pinned down the sides, shuddering
    pinned = [-60, -20, -10, -5, 0, 0]
    fr = {}
    for f in range(0, 12, 2):
        q = 3.0 * (1 if f % 4 == 0 else -1)
        fr[f] = merge(no_flakes, no_veil, {body.name: {"scale": (1.08, 1.08, 0.9), "rot": (0, q * 0.5, 0)}},
                      *[arm_pose(a, [p + q for p in pinned]) for a in range(4)])
    ik.bake_animation("bound", parts, fr, 12, True)
    # dry: shrinking, crust flakes coming up one by one, arms drooping and shrinking
    fr = {}
    for f in range(0, 37, 3):
        t = f / 36
        d = merge(no_veil, {body.name: {"scale": (1.0 - 0.25 * t, 1.0 - 0.25 * t, 0.95 - 0.35 * t)}},
                  {eyes.name: {"scale": 1.0 - 0.6 * t}, small.name: {"scale": max(0.01, 1.0 - 1.2 * t)}},
                  *[arm_pose(a, [p - 40 * t for p in pinned], scale=max(0.05, 1.0 - 0.8 * t)) for a in range(4)])
        for i, fl in enumerate(flakes):
            if t * len(flakes) < i + 0.5:
                d[fl.name] = hidden(fl)
        fr[f] = d
    ik.bake_animation("dry", parts, fr, 36, False)
    # unravel: the husk comes apart
    end_dry = merge(no_veil, {body.name: {"scale": (0.75, 0.75, 0.6)}}, {eyes.name: {"scale": 0.4}, small.name: hidden(small)},
                    *[arm_pose(a, [p - 40 for p in pinned], scale=0.2) for a in range(4)])
    fr = {0: end_dry}
    for f, t in ((3, 0.25), (6, 0.5), (9, 0.75), (12, 0.95)):
        d = dict(end_dry)
        d[body.name] = {"scale": (0.75 * (1 - t) + 0.01, 0.75 * (1 - t) + 0.01, 0.6 * (1 - t) + 0.01), "loc": (0, 0, -2.5 * t)}
        d[eyes.name] = {"scale": max(0.01, 0.4 * (1 - t))}
        for i, fl in enumerate(flakes):
            outward = Vector((fl.location.x, fl.location.y, 0)).normalized() if fl.location.length > 0 else Vector((1, 0, 0))
            d[fl.name] = {"loc": tuple(outward * 3.0 * t + Vector((0, 0, -3.0 * t * t))), "rot": (90 * t * (1 if i % 2 else -1), 40 * t, 0), "scale": 1.0 - 0.7 * t}
        fr[f] = d
    fr[18] = merge({o.name: hidden(o) for o in [body]})
    ik.bake_animation("unravel", parts, fr, 18, False)
    for o in parts:
        ik.apply_pose(o, {})
    for v in veil:
        pass
    ik.report("dregs", meshes)
    ik.export_glb(out_glb, animated=True)


if __name__ == "__main__":
    _, out_glb, out_map = ik.cli_args()[:3]
    ik.reset()
    build(out_glb, out_map)
