"""Godot import settings, external materials and wrapper scenes for every Tallowford model.

    python tools/levels/tallowford/godot_import.py            write materials and wrappers, patch .import files
    python tools/levels/tallowford/godot_import.py --check    exit 1 if anything would change

The same scheme as tools/assets/godot_import.py (whose helpers it imports): one StandardMaterial3D
.tres per glTF material with the model's painted texture, the glb's import pointed at those
materials, looping animations, no LODs or shadow meshes, and mipmapped lossy-WebP textures.
Wrapper scenes go to scenes/levels/tallowford/models/<name>.tscn: the glb with an InkLook child
(and %AnimationPlayer on animated models), as docs/CONTRACTS.md asks.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "assets"))
import godot_import as GI  # noqa: E402

ASSETS = ROOT / "assets/levels/tallowford"
MODELS_DIR = ASSETS / "models"
TEX_DIR = ASSETS / "textures"
WRAP_DIR = ROOT / "scenes/levels/tallowford/models"

LOOPS = {"lamp_post": ["unlit", "lit"], "ford_lamp": ["hooded", "unlit", "lit"], "persimmon": ["withered"]}
MATERIAL_TEXTURE = {"M_tf_ground": "tallowford_ground", "M_tf_hills": "tallowford_hills", "M_tf_ridges": "tallowford_hills"}
PLAIN = {"M_tf_river": "7fa0a6"}
# InkLook settings per wrapper (defaults: world line style, cursable, no accent).
INKLOOK = {
    "tallowford_terrain": {"outline_width": 1.6},
    "lamp_post": {"accent": "gold"},
    "ford_lamp": {"accent": "gold", "outline_width": 1.2},
    "cloth_line": {"wind": True},
    "drying_rack": {"wind": True},
    "fence": {"outline_width": 0.8},
}
NO_INKLOOK = {"tallowford_river"}


def texture_for(model, mat):
    return MATERIAL_TEXTURE.get(mat, model)


def plain_tres(name, color):
    return "\n".join(['[gd_resource type="StandardMaterial3D" format=3]', "", "[resource]", 'resource_name = "%s"' % name,
                      "albedo_color = Color(%s, 1)" % ", ".join("%.4f" % (int(color[i:i + 2], 16) / 255) for i in (0, 2, 4)), ""])


def wrapper(model, animated):
    root = "".join(p.capitalize() for p in model.split("_"))
    lines = ['[gd_scene load_steps=%d format=3]' % (2 if model in NO_INKLOOK else 3), "",
             '[ext_resource type="PackedScene" path="res://assets/levels/tallowford/models/%s.glb" id="1"]' % model]
    if model not in NO_INKLOOK:
        lines.append('[ext_resource type="Script" path="res://scripts/render/ink_look.gd" id="2"]')
    lines += ["", '[node name="%s" instance=ExtResource("1")]' % root]
    if animated:
        lines += ["", '[node name="AnimationPlayer" parent="." index="1"]', "unique_name_in_owner = true"]
    if model not in NO_INKLOOK:
        lines += ["", '[node name="InkLook" type="Node" parent="."]', 'script = ExtResource("2")']
        for k, v in INKLOOK.get(model, {}).items():
            if isinstance(v, bool):
                lines.append("%s = %s" % (k, "true" if v else "false"))
            elif isinstance(v, str):
                lines.append('%s = &"%s"' % (k, v))
            else:
                lines.append("%s = %s" % (k, v))
    return "\n".join(lines) + "\n"


def main(check):
    changes = []

    def write(path, text):
        if path.exists() and path.read_text() == text:
            return
        changes.append(path.relative_to(ROOT).as_posix())
        if not check:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "w", newline="\n") as f:
                f.write(text)

    for png in sorted(TEX_DIR.glob("*.png")):
        imp = Path(str(png) + ".import")
        if imp.exists():
            write(imp, GI.patch_params(imp.read_text(), GI.PNG_PARAMS))
    for glb in sorted(MODELS_DIR.glob("*.glb")):
        model = glb.stem
        subs = {"materials": {}, "animations": {}}
        for mat in GI.glb_materials(glb):
            tres = MODELS_DIR / "materials" / ("%s.tres" % mat.lower())
            if mat in PLAIN:
                write(tres, plain_tres(mat, PLAIN[mat]))
            else:
                tex_res = "res://assets/levels/tallowford/textures/%s.png" % texture_for(model, mat)
                write(tres, GI.material_tres(mat, tex_res, GI.import_uid(ROOT / tex_res[6:])))
            res = "res://" + tres.relative_to(ROOT).as_posix()
            subs["materials"][mat] = {"use_external/enabled": True, "use_external/path": res, "use_external/fallback_path": res}
        for name in LOOPS.get(model, []):
            subs["animations"][name] = {"settings/loop_mode": 1}
        subs = {k: v for k, v in subs.items() if v}
        imp = Path(str(glb) + ".import")
        if imp.exists():
            text = imp.read_text()
            params = dict(GI.GLB_PARAMS)
            if not GI.subresources_satisfied(text, subs):
                params["_subresources"] = GI.godot_value(subs)
            write(imp, GI.patch_params(text, params))
        else:
            print("missing import file (run the Godot import first):", glb.relative_to(ROOT).as_posix())
        write(WRAP_DIR / ("%s.tscn" % model), wrapper(model, model in LOOPS))
    for c in changes:
        print(("WOULD CHANGE " if check else "WROTE ") + c)
    print("IMPORT SETTINGS %s (%d files)" % ("STALE" if (check and changes) else "OK", len(changes)))
    return 1 if (check and changes) else 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
