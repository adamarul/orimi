"""Finish a folk cast after make_folk.py and paint_folk.py ran: write each person's wrapper scene,
the godot_import.json registry beside the models, and provenance manifests for the outputs.

    python tools/assets/folk_finish.py <spec.json>
"""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "blender"))
import folk_style as FS  # noqa: E402

WRAPPER = """[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" path="res://{glb}" id="1"]
[ext_resource type="Script" path="res://scripts/render/ink_look.gd" id="2"]
[ext_resource type="Script" path="res://scenes/models/folk/folk_person.gd" id="3"]
[ext_resource type="Texture2D" path="res://{texture}" id="4"]
[ext_resource type="Texture2D" path="res://{faded}" id="5"]

[node name="{node}" instance=ExtResource("1")]
script = ExtResource("3")
woken_texture = ExtResource("4")
faded_texture = ExtResource("5")

[node name="AnimationPlayer" parent="." index="1"]
unique_name_in_owner = true

[node name="InkLook" type="Node" parent="."]
script = ExtResource("2")
cursable = false
line_style = &"character"
"""


def write(path, text):
    path = ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def sha(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def main(spec_path):
    spec = FS.load(spec_path)
    spec_rel = Path(spec_path).resolve().relative_to(ROOT).as_posix()
    command = "tools/assets/gen_folk.sh %s" % spec_rel
    registry, outputs = {}, {}
    for name in spec["people"]:
        p = FS.paths(spec, name)
        write(p["scene"], WRAPPER.format(glb=p["glb"], texture=p["texture"], faded=p["faded"], node=FS.scene_name(name)))
        registry[p["glb"]] = {"texture": p["texture"], "textures": [p["faded"]], "loops": list(FS.LOOPING)}
        outputs.setdefault(spec["models"], []).append({"path": p["glb"], "generator": "tools/blender/make_folk.py"})
        for t in (p["texture"], p["faded"]):
            outputs.setdefault(spec["textures"], []).append({"path": t, "generator": "tools/textures/painted/paint_folk.py"})
        print("FOLK %s -> %s" % (name, p["scene"]))
    write("%s/godot_import.json" % spec["models"], json.dumps(registry, indent=1, sort_keys=True) + "\n")
    for folder, items in outputs.items():
        manifest = ROOT / folder / "provenance.json"
        doc = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else {"outputs": []}
        mine = {it["path"] for it in items}
        kept = [o for o in doc["outputs"] if o["path"] not in mine]
        for it in items:
            kept.append(dict(it, sha256=sha(it["path"]), command=command))
        doc["outputs"] = sorted(kept, key=lambda o: o["path"])
        write("%s/provenance.json" % folder, json.dumps(doc, indent=1) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
