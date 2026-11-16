"""Godot import settings and materials for the Hollow Kiln's generated models and textures.

    python -I tools/levels/hollow_kiln/kiln_import.py            write materials, patch .import files
    python -I tools/levels/hollow_kiln/kiln_import.py --check    exit 1 if anything would change

The same treatment tools/assets/godot_import.py gives the shared models (its helpers are imported,
not edited): one StandardMaterial3D per glTF material in assets/levels/hollow_kiln/materials/,
named after the glTF material so a "_sacred" suffix survives, with the painted texture as albedo;
glb imports point at those materials, keep 12 fps stepped animations, loop the idle clips, and
make no LODs or shadow meshes; textures become mipmapped lossy WebP.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "assets"))
import godot_import as gi  # noqa: E402

BASE = ROOT / "assets" / "levels" / "hollow_kiln"
TEX = "res://assets/levels/hollow_kiln/textures/%s.png"
TILE_TEXTURES = {"M_hk_plaster": "hk_plaster", "M_hk_brick": "hk_brick", "M_hk_stone": "hk_stone", "M_hk_timber": "hk_timber",
                 "M_hk_roof": "hk_roof", "M_hk_flag": "hk_flag", "M_hk_board": "hk_board", "M_hk_plank": "hk_plank",
                 "M_hk_paper": "hk_paper", "M_hk_iron": "hk_iron", "M_hk_ground": "hk_ground", "M_hk_far": "hk_far",
                 "M_hk_water": "hk_ink", "M_hk_ink": "hk_ink"}
LOOPS = {"dregs": ["veiled", "idle", "climb", "bound"], "brazier": ["lit"], "wall_lamp": ["lit"], "kiln_fire": ["lit"],
         "vat_tree": ["grown"]}


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

    for png in sorted((BASE / "textures").glob("*.png")):
        imp = Path(str(png) + ".import")
        if imp.exists():
            write(imp, gi.patch_params(imp.read_text(), gi.PNG_PARAMS))
    for glb in sorted((BASE / "models").glob("*.glb")):
        model = glb.stem
        subs = {"materials": {}, "animations": {}}
        for mat in gi.glb_materials(glb):
            tex = TILE_TEXTURES.get(mat, model)
            tex_res = TEX % tex
            tres = BASE / "materials" / ("%s.tres" % mat.lower())
            write(tres, gi.material_tres(mat, tex_res, gi.import_uid(ROOT / tex_res[6:])))
            res = "res://" + tres.relative_to(ROOT).as_posix()
            subs["materials"][mat] = {"use_external/enabled": True, "use_external/path": res, "use_external/fallback_path": res}
        for name in LOOPS.get(model, []):
            subs["animations"][name] = {"settings/loop_mode": 1}
        subs = {k: v for k, v in subs.items() if v}
        imp = Path(str(glb) + ".import")
        if imp.exists():
            text = imp.read_text()
            params = dict(gi.GLB_PARAMS)
            if not gi.subresources_satisfied(text, subs):
                params["_subresources"] = gi.godot_value(subs)
            write(imp, gi.patch_params(text, params))
        else:
            print("missing import file (run the Godot import first):", glb.relative_to(ROOT).as_posix())
    for c in changes:
        print(("WOULD CHANGE " if check else "WROTE ") + c)
    print("KILN IMPORT SETTINGS %s (%d files)" % ("STALE" if (check and changes) else "OK", len(changes)))
    return 1 if (check and changes) else 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
