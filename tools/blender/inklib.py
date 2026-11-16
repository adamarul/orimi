"""Shared helpers for the headless Blender model generators (tools/blender/make_*.py).

Every generator builds its model from code, paints the CONTRACTS.md vertex colours
(R outline weight, G wind sway, B dry-brush tendency), names materials, unwraps UVs,
writes a "paint map" JSON that tools/textures/painted/paint_models.py turns into the
painted albedo, keys stepped 12 fps animations as NLA tracks, and exports glTF binary.

Coordinates here are Blender's: X right, Y forward, Z up. The glTF exporter converts
to Godot's Y-up, so Blender +Y becomes Godot -Z (the way characters face).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

FPS = 12


def cli_args():
    return sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.fps_base = 1.0
    scene.frame_start = 0
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"


def g2b(x, y, z):
    """Godot position (x, y, z) to Blender (x, -z, y)."""
    return (x, -z, y)


# --------------------------------------------------------------------------- geometry

def loft(sections, cap_start=True, cap_end=True):
    """Join cross-sections into a closed solid.

    sections: list of point lists, all of the same length k, or a single point (an apex).
    Consecutive full sections are joined by quads; an apex section becomes a fan.
    Returns (verts, faces)."""
    verts, faces, rings = [], [], []
    for sec in sections:
        start = len(verts)
        verts.extend(tuple(p) for p in sec)
        rings.append(list(range(start, start + len(sec))))
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            k = len(b)
            for i in range(k):
                faces.append((a[0], b[i], b[(i + 1) % k]))
        elif len(b) == 1:
            k = len(a)
            for i in range(k):
                faces.append((a[(i + 1) % k], a[i], b[0]))
        else:
            k = len(a)
            for i in range(k):
                faces.append((a[i], b[i], b[(i + 1) % k], a[(i + 1) % k]))
    if cap_start and len(rings[0]) > 2:
        faces.append(tuple(reversed(rings[0])))
    if cap_end and len(rings[-1]) > 2:
        faces.append(tuple(rings[-1]))
    return verts, faces


def ring_xz(y, pts):
    """Cross-section in the XZ plane at depth y: pts are (x, z) pairs."""
    return [(x, y, z) for x, z in pts]


def ring_xy(z, pts):
    return [(x, y, z) for x, y in pts]


def roof(w, top, mid, low, bottom):
    """Six-point folded-paper profile: ridge on top, keel below."""
    return [(0.0, top), (-w, mid), (-w * 0.85, low), (0.0, bottom), (w * 0.85, low), (w, mid)]


def diamond(w, h, cx=0.0, cz=0.0):
    return [(cx, cz + h), (cx - w, cz), (cx, cz - h), (cx + w, cz)]


def tube(points, radii, sides=5, twist=0.0, cap=True):
    """Tapered tube along a polyline of (x, y, z) points; a radius of 0 ends in a point."""
    pts = [Vector(p) for p in points]
    sections = []
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        n = prev_n if prev_n is not None else t.cross(ref).normalized()
        n = (n - t * n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        r = radii[i]
        if r <= 1e-6:
            sections.append([tuple(p)])
            continue
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides + twist * i
            ring.append(tuple(p + (n * math.cos(a) + b * math.sin(a)) * r))
        sections.append(ring)
    return loft(sections, cap_start=cap, cap_end=cap)


def cone(base, tip, r, sides=4):
    return tube([base, tip], [r, 0.0], sides)


def ico(r, subdiv=1, squash=(1, 1, 1), wobble=0.0, seed=0):
    import bmesh
    import random as _r
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    rnd = _r.Random(seed)
    verts = []
    for v in bm.verts:
        k = 1.0 + rnd.uniform(-wobble, wobble)
        verts.append((v.co.x * squash[0] * k, v.co.y * squash[1] * k, v.co.z * squash[2] * k))
    faces = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return verts, faces


def make_object(name, vf, parent=None, location=(0, 0, 0), rotation_deg=(0, 0, 0)):
    verts, faces = vf
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    obj.location = location
    obj.rotation_euler = Euler([math.radians(a) for a in rotation_deg], "XYZ")
    fix_winding(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    bpy.context.view_layer.update()
    return obj


def fix_winding(obj):
    """Make face normals consistent and outward for closed parts."""
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def make_empty(name, location, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.5
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    return obj


def merged(*parts):
    """Combine several (verts, faces) pairs into one."""
    verts, faces = [], []
    for v, f in parts:
        off = len(verts)
        verts.extend(v)
        faces.extend(tuple(i + off for i in face) for face in f)
    return verts, faces


def transformed(vf, location=(0, 0, 0), rotation_deg=(0, 0, 0), scale=(1, 1, 1)):
    verts, faces = vf
    mat = Matrix.LocRotScale(Vector(location), Euler([math.radians(a) for a in rotation_deg], "XYZ"), Vector(scale))
    return [tuple(mat @ Vector(v)) for v in verts], faces


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# --------------------------------------------------------------------------- tags and colours

def tag_faces(obj, fn):
    """fn(world_center, world_normal, obj) -> tag string, stored per face for the painter."""
    mw = obj.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    obj["paint_tags"] = [fn(mw @ p.center, (nm @ p.normal).normalized(), obj) for p in obj.data.polygons]


def set_tags(obj, tag):
    obj["paint_tags"] = [tag] * len(obj.data.polygons)


def paint_vertex_colors(obj, fn):
    """fn(world_co, local_co, world_normal, tag) -> (r, g, b). Stored as corner byte colour 'Col'."""
    mesh = obj.data
    mw = obj.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    tags = list(obj.get("paint_tags", [])) or ["base"] * len(mesh.polygons)
    attr = mesh.color_attributes.get("Col") or mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly in mesh.polygons:
        tag = tags[poly.index]
        for li in poly.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index]
            r, g, b = fn(mw @ v.co, v.co.copy(), (nm @ v.normal).normalized(), tag)
            attr.data[li].color = (clamp01(r), clamp01(g), clamp01(b), 1.0)
    mesh.color_attributes.active_color = attr
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index


def clamp01(x):
    return max(0.0, min(1.0, float(x)))


def smoothstep(e0, e1, x):
    t = clamp01((x - e0) / (e1 - e0)) if e1 != e0 else (1.0 if x >= e1 else 0.0)
    return t * t * (3 - 2 * t)


def chain_taper(chains):
    """Outline weight along brush strokes. chains: lists of (world_point, weight); a point takes the
    weight interpolated along its nearest chain segment, so limbs run thick at the root to thin at the tip."""
    segs = []
    for chain in chains:
        for (pa, wa), (pb, wb) in zip(chain, chain[1:]):
            segs.append((Vector(pa), Vector(pb), wa, wb))

    def weight(co):
        best, best_w = None, 1.0
        for a, b, wa, wb in segs:
            ab = b - a
            t = clamp01((co - a).dot(ab) / max(ab.length_squared, 1e-12))
            d = (a + ab * t - co).length
            if best is None or d < best:
                best, best_w = d, wa + (wb - wa) * t
        return best_w
    return weight


def chain(points, w_start, w_end):
    """A chain_taper stroke along a polyline, weight w_start at the first point to w_end at the last."""
    n = max(len(points) - 1, 1)
    return [(tuple(p), w_start + (w_end - w_start) * i / n) for i, p in enumerate(points)]


def hash01(*xs):
    h = 0.0
    for i, x in enumerate(xs):
        h += math.sin(x * (12.9898 + 31.7 * i) + 78.233 * i) * 43758.5453
    return h - math.floor(h)


# --------------------------------------------------------------------------- materials and UVs

def assign_material(obj, name):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return mat


def smart_uv(objects, angle=40.0, margin=0.01):
    """Unwrap all objects together into one atlas (multi-object edit)."""
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [o for o in objects if o.type == "MESH"]
    for o in meshes:
        o.select_set(True)
        if not o.data.uv_layers:
            o.data.uv_layers.new(name="UVMap")
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")


def planar_uv(obj, fn):
    """fn(world_co) -> (u, v) for every corner."""
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    mw = obj.matrix_world
    for loop in mesh.loops:
        uv[loop.index].uv = fn(mw @ mesh.vertices[loop.vertex_index].co)


def dump_paint_map(objects, path, texture_size, crease_deg=18.0, extra=None):
    """Write face UV polygons with tags, and fold-crease UV segments, for the texture painter."""
    faces_out, creases = [], []
    for obj in objects:
        if obj.type != "MESH" or not obj.data.uv_layers:
            continue
        mesh = obj.data
        uv = mesh.uv_layers.active.data
        tags = list(obj.get("paint_tags", [])) or ["base"] * len(mesh.polygons)
        mw = obj.matrix_world
        edge_users = {}
        for poly in mesh.polygons:
            faces_out.append({
                "obj": obj.name,
                "tag": tags[poly.index],
                "uv": [[round(uv[li].uv.x, 5), round(uv[li].uv.y, 5)] for li in poly.loop_indices],
                "z": round((mw @ poly.center).z, 4),
            })
            n = len(poly.loop_indices)
            for k in range(n):
                li = poly.loop_indices[k]
                lj = poly.loop_indices[(k + 1) % n]
                key = tuple(sorted((mesh.loops[li].vertex_index, mesh.loops[lj].vertex_index)))
                edge_users.setdefault(key, []).append((poly.index, li, lj))
        for users in edge_users.values():
            if len(users) != 2:
                continue
            (pa, _, _), (pb, _, _) = users
            angle = math.degrees(mesh.polygons[pa].normal.angle(mesh.polygons[pb].normal, 0.0))
            if angle < crease_deg:
                continue
            for poly_i, l1, l2 in users:
                poly = mesh.polygons[poly_i]
                cu = sum(uv[li].uv.x for li in poly.loop_indices) / len(poly.loop_indices)
                cv = sum(uv[li].uv.y for li in poly.loop_indices) / len(poly.loop_indices)
                creases.append({
                    "center": [round(cu, 5), round(cv, 5)],
                    "obj": obj.name,
                    "tag": tags[poly_i],
                    "angle": round(angle, 1),
                    "uv": [[round(uv[l1].uv.x, 5), round(uv[l1].uv.y, 5)], [round(uv[l2].uv.x, 5), round(uv[l2].uv.y, 5)]],
                })
    data = {"size": texture_size, "faces": faces_out, "creases": creases}
    if extra:
        data.update(extra)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f)


# --------------------------------------------------------------------------- stepped animation

def store_rest(objects):
    for o in objects:
        o["rest_loc"] = list(o.location)
        o["rest_rot"] = list(o.rotation_euler)
        o["rest_scale"] = list(o.scale)


def apply_pose(obj, pose):
    """pose: loc (offset), rot (degrees, added to rest), scale (number or triple, multiplier)."""
    rl, rr, rs = Vector(obj["rest_loc"]), Vector(obj["rest_rot"]), Vector(obj["rest_scale"])
    obj.location = rl + Vector(pose.get("loc", (0, 0, 0)))
    obj.rotation_euler = Euler(rr + Vector([math.radians(a) for a in pose.get("rot", (0, 0, 0))]), "XYZ")
    s = pose.get("scale", 1.0)
    s = Vector((s, s, s)) if isinstance(s, (int, float)) else Vector(s)
    obj.scale = Vector((rs.x * s.x, rs.y * s.y, rs.z * s.z))


def bake_animation(name, objects, frames, length, loop):
    """Key a stepped animation as one NLA track per object, all named `name`.

    frames: {frame: {object_name: pose}}. Every object is keyed on every listed frame; a
    missing pose holds the object's previous pose in this animation (rest on frame 0), so
    no part keeps a pose from another animation. A closing key at `length` repeats frame
    0 for loops and holds the last pose otherwise, so the clip lasts length / 12 s."""
    frames = {int(k): v for k, v in frames.items()}
    frames.setdefault(0, {})
    frames.setdefault(length, {})
    keys = sorted(frames)
    for obj in objects:
        obj.animation_data_create()
        action = bpy.data.actions.new("%s_%s" % (name, obj.name))
        obj.animation_data.action = action
        current = {}
        for f in keys:
            pose = frames[0].get(obj.name, {}) if (loop and f == length) else frames[f].get(obj.name)
            if pose is not None:
                current = pose
            apply_pose(obj, current)
            obj.keyframe_insert("location", frame=f)
            obj.keyframe_insert("rotation_euler", frame=f)
            obj.keyframe_insert("scale", frame=f)
        track = obj.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.name = name
        obj.animation_data.action = None
        apply_pose(obj, {})


# --------------------------------------------------------------------------- export

def export_glb(path, animated=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_normals=True,
        export_texcoords=True,
        export_apply=True,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_yup=True,
        export_animations=animated,
        export_extras=False,
    )
    if animated:
        kwargs.update(
            export_animation_mode="NLA_TRACKS",
            export_force_sampling=False,
            export_sampling_interpolation_fallback="STEP",
            export_frame_step=1,
            export_optimize_animation_keep_anim_object=True,
        )
    bpy.ops.export_scene.gltf(**kwargs)


def report(model, objects):
    meshes = [o for o in objects if o.type == "MESH"]
    print("MODEL %s tris=%d parts=%d" % (model, sum(tri_count(o) for o in meshes), len(meshes)))
