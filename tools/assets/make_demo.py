"""Write scenes/dev/assets_demo.tscn with tools/assets/assets_demo.gd embedded as a built-in script.

The demo's script lives inside the scene because the workstream owns the scene file but no
script folder for it; edit tools/assets/assets_demo.gd and re-run this.
    python tools/assets/make_demo.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
src = (ROOT / "tools/assets/assets_demo.gd").read_text()
escaped = src.replace("\\", "\\\\").replace('"', '\\"')
scene = """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_demo"]
script/source = "%s"

[node name="AssetsDemo" type="Node3D"]
script = SubResource("GDScript_demo")
""" % escaped
out = ROOT / "scenes/dev/assets_demo.tscn"
with open(out, "w", newline="\n") as f:
    f.write(scene)
print("WROTE", out.relative_to(ROOT).as_posix())
