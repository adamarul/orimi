"""Write Sedge Plain's wrapper scenes from layout.py and the generated models.

    python tools/levels/sedge_plain/make_scenes.py

  scenes/levels/sedge_plain/terrain.tscn         ground tiles + hills (InkLook), safe skin (InkLook,
                                                 not cursable, no outline), river (vfx water), and
                                                 every M_* marker as a Marker3D under Markers
  scenes/levels/sedge_plain/props/<name>.tscn    one wrapper per prop: the glb plus an InkLook
  scenes/levels/sedge_plain/props/guardian_sapling.tscn   Level 1's sapling at 4.5 x scale
  scenes/levels/sedge_plain/dressing.tscn        every prop placement in layout.props()
"""
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout as L  # noqa: E402

SCENES = ROOT / "scenes/levels/sedge_plain"
INK = "res://scripts/render/ink_look.gd"
# wrapper settings per prop: InkLook properties
PROP_LOOK = {
    "stone_tall": {"outline_width": 0.6, "wind": True},
    "stone_lean": {"outline_width": 0.6},
    "stone_capped": {"outline_width": 0.6},
    "stone_fallen": {"outline_width": 0.6},
    "tie_post": {"accent": '&"gold"', "cursable": False},
    "bridge_wreck": {"outline_width": 0.8, "wind": True},
    "tamsin_camp": {"outline_width": 0.9},
    "map_leaf": {"accent": '&"gold"', "cursable": False, "outline_width": 0.6},
    "landing_stage": {},
    "wood_tree": {"outline_width": 1.3},
}
SHARED = {"shrine": "res://scenes/models/shrine.tscn", "rocks": "res://scenes/models/rocks.tscn",
          "reeds": "res://scenes/models/reeds.tscn"}


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return ("%.3f" % v).rstrip("0").rstrip(".")
    return str(v)


def xform(x, y, z, yaw=0.0, s=1.0):
    a = math.radians(yaw)
    c, si = math.cos(a) * s, math.sin(a) * s
    vals = [c, 0.0, si, 0.0, s, 0.0, -si, 0.0, c, x, y, z]
    return "Transform3D(%s)" % ", ".join(fmt(round(v, 4)) for v in vals)


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def prop_wrapper(name):
    look = PROP_LOOK[name]
    lines = ['[gd_scene load_steps=3 format=3]', '',
             '[ext_resource type="PackedScene" path="res://assets/levels/sedge_plain/props/%s.glb" id="1"]' % name,
             '[ext_resource type="Script" path="%s" id="2"]' % INK, '',
             '[node name="%s" instance=ExtResource("1")]' % "".join(p.capitalize() for p in name.split("_")), '',
             '[node name="InkLook" type="Node" parent="."]', 'script = ExtResource("2")']
    lines += ["%s = %s" % (k, fmt(v)) for k, v in look.items()]
    if name == "tie_post":
        lines += ["", '[node name="Ring" type="Marker3D" parent="."]', "transform = %s" % xform(0.0, 1.45, 0.0)]
    write(SCENES / "props" / ("%s.tscn" % name), "\n".join(lines) + "\n")


def sapling_wrapper():
    text = "\n".join([
        '[gd_scene load_steps=2 format=3]', '',
        '[ext_resource type="PackedScene" path="res://scenes/models/sapling.tscn" id="1"]', '',
        '[node name="GuardianSapling" type="Node3D"]', '',
        '[node name="Sapling" parent="." instance=ExtResource("1")]',
        "transform = %s" % xform(0, 0, 0, 0, 4.5), ""])
    write(SCENES / "props" / "guardian_sapling.tscn", text)


def terrain_scene():
    tiles = sorted(p.stem for p in (ROOT / "assets/levels/sedge_plain/terrain").glob("ground_*.glb"))
    ext = ['[ext_resource type="PackedScene" path="res://assets/levels/sedge_plain/terrain/%s.glb" id="%s"]' % (t, t) for t in tiles]
    for name in ("hills", "safe", "river"):
        ext.append('[ext_resource type="PackedScene" path="res://assets/levels/sedge_plain/terrain/%s.glb" id="%s"]' % (name, name))
    ext.append('[ext_resource type="Script" path="%s" id="ink"]' % INK)
    ext.append('[ext_resource type="Script" path="res://scripts/levels/sedge_plain/sedge_river.gd" id="river_gd"]')
    nodes = ['[node name="SedgeTerrain" type="Node3D"]', '', '[node name="Ground" type="Node3D" parent="."]', '']
    for t in tiles:
        nodes += ['[node name="%s" parent="Ground" instance=ExtResource("%s")]' % (t.capitalize(), t), '']
    nodes += ['[node name="InkLook" type="Node" parent="Ground"]', 'script = ExtResource("ink")', 'outline_width = 1.6', '',
              '[node name="Hills" parent="." instance=ExtResource("hills")]', '',
              '[node name="InkLook" type="Node" parent="Hills"]', 'script = ExtResource("ink")', 'outline_width = 1.6', '',
              '[node name="Safe" parent="." instance=ExtResource("safe")]', '',
              '[node name="InkLook" type="Node" parent="Safe"]', 'script = ExtResource("ink")', 'outline_width = 0.0', 'cursable = false', '',
              '[node name="River" parent="." instance=ExtResource("river")]', 'script = ExtResource("river_gd")', '',
              '[node name="Markers" type="Node3D" parent="."]', '']
    for name, (x, y, z) in L.markers().items():
        nodes += ['[node name="%s" type="Marker3D" parent="Markers"]' % name, "transform = %s" % xform(x, y, z), '']
    text = "[gd_scene load_steps=%d format=3]\n\n%s\n\n%s" % (len(ext) + 1, "\n".join(ext), "\n".join(nodes))
    write(SCENES / "terrain.tscn", text)


# Placed by make_level.py as kit nodes (TiePost model_scene), not as dressing.
KIT_PROPS = {"tie_post", "map_leaf"}


def dressing_scene():
    placements = [p for p in L.props() if p[0] not in KIT_PROPS]
    models = sorted({p[0] for p in placements})
    ids = {}
    ext = []
    for k, m in enumerate(models):
        path = SHARED.get(m, "res://scenes/levels/sedge_plain/props/%s.tscn" % m)
        ids[m] = str(k + 1)
        ext.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (path, ids[m]))
    nodes = ['[node name="SedgeDressing" type="Node3D"]', '']
    counts = {}
    for model, x, y, z, yaw, s in placements:
        counts[model] = counts.get(model, 0) + 1
        nodes += ['[node name="%s_%d" parent="." instance=ExtResource("%s")]' % (model, counts[model], ids[model]),
                  "transform = %s" % xform(x, y, z, yaw, s), '']
    text = "[gd_scene load_steps=%d format=3]\n\n%s\n\n%s" % (len(ext) + 1, "\n".join(ext), "\n".join(nodes))
    write(SCENES / "dressing.tscn", text)


def main():
    for name in PROP_LOOK:
        prop_wrapper(name)
    sapling_wrapper()
    terrain_scene()
    dressing_scene()
    print("SCENES terrain, dressing, %d prop wrappers" % (len(PROP_LOOK) + 1))


if __name__ == "__main__":
    main()
