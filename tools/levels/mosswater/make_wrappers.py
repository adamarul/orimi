"""Write the wrapper scenes for Mosswater Wood's models: scenes/levels/mosswater/models/mw_<name>.tscn,
each instancing assets/levels/mosswater/mw_<name>.glb with an InkLook child (render's look) and,
for animated models, the AnimationPlayer exposed as %AnimationPlayer (CONTRACTS.md, Models).

    python tools/levels/mosswater/make_wrappers.py
"""
import json
import struct
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "assets/levels/mosswater"
OUT = ROOT / "scenes/levels/mosswater/models"

# InkLook settings per model (anything not listed: defaults, world line).
LOOK = {
    "terrain": {"outline_width": 1.6},
    "trunk_a": {"outline_width": 1.3}, "trunk_b": {"outline_width": 1.3}, "trunk_c": {"outline_width": 1.3},
    "trunk_snag": {"outline_width": 1.2}, "stair_tree": {"outline_width": 1.4},
    "lantern_fruit": {"accent": "&\"gold\""},
    "willow": {"accent": "&\"vermilion\"", "wind": "true"},
    "sootflit": {"line_style": "&\"character\"", "cursable": "false"},
    "lily": {"outline_width": 0.8}, "lily_pad": {"outline_width": 0.7},
    "moss_shelf": {"outline_width": 0.9}, "fungus_shelf": {"outline_width": 0.9},
}
NO_INKLOOK = {"water"}
# Where a Kindle dab lands (KindleTarget reads the root's "wick" metadata), from the model's origin.
WICK = {"lantern_fruit": "Vector3(0, 0, 0)", "brazier": "Vector3(0, 0.8, 0)"}
WATER_SCRIPT = "res://scripts/levels/mosswater/mw_water.gd"


def has_animations(glb):
    data = glb.read_bytes()
    clen = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20 + clen])
    return bool(g.get("animations"))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for glb in sorted(ASSETS.glob("mw_*.glb")):
        name = glb.stem[3:]
        res = "res://" + glb.relative_to(ROOT).as_posix()
        root_name = "".join(p.capitalize() for p in ("mw_" + name).split("_"))
        lines = []
        if name in NO_INKLOOK:
            lines += ['[gd_scene load_steps=3 format=3]', '', '[ext_resource type="PackedScene" path="%s" id="1"]' % res,
                      '[ext_resource type="Script" path="%s" id="2"]' % WATER_SCRIPT, '',
                      '[node name="%s" instance=ExtResource("1")]' % root_name, 'script = ExtResource("2")', '']
        else:
            lines += ['[gd_scene load_steps=3 format=3]', '', '[ext_resource type="PackedScene" path="%s" id="1"]' % res,
                      '[ext_resource type="Script" path="res://scripts/render/ink_look.gd" id="2"]', '',
                      '[node name="%s" instance=ExtResource("1")]' % root_name]
            if name in WICK:
                lines.append("metadata/wick = %s" % WICK[name])
            lines.append("")
            if has_animations(glb):
                lines += ['[node name="AnimationPlayer" parent="."]', 'unique_name_in_owner = true', '']
            lines += ['[node name="InkLook" type="Node" parent="."]', 'script = ExtResource("2")']
            for k, v in LOOK.get(name, {}).items():
                lines.append("%s = %s" % (k, v))
            lines.append("")
        path = OUT / ("mw_%s.tscn" % name)
        with open(path, "w", newline="\n") as f:
            f.write("\n".join(lines))
        print("WRAPPER", path.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
