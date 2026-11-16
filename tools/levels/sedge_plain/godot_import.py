"""Godot import settings and materials for Sedge Plain's generated models and textures.

    python tools/levels/sedge_plain/godot_import.py            write materials, patch .import files
    python tools/levels/sedge_plain/godot_import.py --check    exit 1 if anything would change

The same scheme as tools/assets/godot_import.py (whose helpers this imports): one
StandardMaterial3D .tres per glTF material in assets/levels/sedge_plain/materials/, albedo = the
model's painted texture, glb imports pointed at those materials, no LODs or shadow meshes,
textures as mipmapped lossy WebP. A .import file must exist first (run the Godot import once;
tools/levels/sedge_plain/gen_all.sh does).
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "assets"))
import godot_import as G  # noqa: E402

BASE = ROOT / "assets/levels/sedge_plain"
MATERIAL_TEXTURE = {"M_sp_hills": "hills", "M_sp_ridges": "hills", "M_sp_tie_gold_sacred": "tie_post",
                    "M_sp_camp_gold_sacred": "tamsin_camp"}


def texture_for(glb):
    if glb.parent.name == "terrain":
        return "hills" if glb.stem == "hills" else "ground"
    return glb.stem


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
            write(imp, G.patch_params(imp.read_text(), G.PNG_PARAMS))
    for glb in sorted(list((BASE / "terrain").glob("*.glb")) + list((BASE / "props").glob("*.glb"))):
        subs = {"materials": {}}
        for mat in G.glb_materials(glb):
            tex = MATERIAL_TEXTURE.get(mat, texture_for(glb))
            tex_res = "res://assets/levels/sedge_plain/textures/%s.png" % tex
            tres = BASE / "materials" / ("%s.tres" % mat.lower())
            write(tres, G.material_tres(mat, tex_res, G.import_uid(ROOT / tex_res[6:])))
            res = "res://" + tres.relative_to(ROOT).as_posix()
            subs["materials"][mat] = {"use_external/enabled": True, "use_external/path": res, "use_external/fallback_path": res}
        imp = Path(str(glb) + ".import")
        if imp.exists():
            text = imp.read_text()
            params = dict(G.GLB_PARAMS)
            if not G.subresources_satisfied(text, subs):
                params["_subresources"] = G.godot_value(subs)
            write(imp, G.patch_params(text, params))
        else:
            print("missing import file (run the Godot import first):", glb.relative_to(ROOT).as_posix())
    for c in changes:
        print(("WOULD CHANGE " if check else "WROTE ") + c)
    print("IMPORT SETTINGS %s (%d files)" % ("STALE" if (check and changes) else "OK", len(changes)))
    return 1 if (check and changes) else 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
