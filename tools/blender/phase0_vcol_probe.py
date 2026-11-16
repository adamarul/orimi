"""Phase 0 probe mesh: a smooth low-poly pebble with painted vertex colours, exported as glTF.

Run headless through tools/gen_phase0_assets.sh:
    blender --background --factory-startup --python tools/blender/phase0_vcol_probe.py -- <out.glb>

Colour attribute "Col" (corner domain, byte colour):
  RGB = a vertical gradient from deep indigo (bottom) to vermilion (top), so the shader read is obvious;
  A   = an outline-width weight that varies around the mesh (0.25 to 1.0), to test whether alpha
        survives Blender -> glTF -> Godot.
Normals stay smooth so an inverted-hull outline does not crack; the flat look is made in the shader.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not argv:
    raise SystemExit("usage: ... -- <out.glb>")
out_path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.9, location=(0.0, 0.0, 0.0))
obj = bpy.context.active_object
obj.name = "VcolProbe"
mesh = obj.data
mesh.name = "VcolProbeMesh"

for v in mesh.vertices:
    v.co.z *= 0.75
    v.co.x *= 1.15

for poly in mesh.polygons:
    poly.use_smooth = True

bottom = (0.12, 0.14, 0.42)
top = (0.86, 0.24, 0.12)
attr = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
for loop in mesh.loops:
    co = mesh.vertices[loop.vertex_index].co
    t = max(0.0, min(1.0, (co.z + 0.7) / 1.4))
    rgb = [bottom[i] + (top[i] - bottom[i]) * t for i in range(3)]
    weight = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(math.atan2(co.y, co.x) * 3.0))
    attr.data[loop.index].color = (rgb[0], rgb[1], rgb[2], weight)
mesh.color_attributes.active_color = attr
mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index

tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
print("PROBE_MESH tris=%d verts=%d" % (tris, len(mesh.vertices)))

bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format="GLB",
    export_vertex_color="ACTIVE",
    export_normals=True,
    export_apply=True,
    export_materials="NONE",
)
print("PROBE_MESH exported", out_path)
