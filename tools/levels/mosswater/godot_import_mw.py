"""Godot import settings and external materials for Mosswater Wood's generated assets.

    python tools/levels/mosswater/godot_import_mw.py            write materials, patch .import files
    python tools/levels/mosswater/godot_import_mw.py --check    exit 1 if anything would change

The same scheme as tools/assets/godot_import.py (whose helpers it imports): one
StandardMaterial3D .tres per glTF material, albedo = the model's painted texture, the glb's
import pointing at it; looping animations; no LODs or shadow meshes; textures as mipmapped
lossy WebP. A .import file must exist first (tools/levels/mosswater/import.sh runs Godot's import).
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "assets"))
import godot_import as GI  # noqa: E402

FOLDER = ROOT / "assets/levels/mosswater"
TEXDIR = "res://assets/levels/mosswater/textures"
LOOPS = {
    "lantern_fruit": ["unlit", "lit"], "wheel": ["clogged", "spin"], "lily": ["bud"], "moss_shelf": ["tucked"],
    "willow": ["withered"], "sootflit": ["idle", "fly", "downed"],
}
MATERIAL_TEXTURE = {"M_mw_ground": "mw_ground", "M_mw_cliff": "mw_cliff"}
NO_TEXTURE = {"M_mw_water"}


def texture_for(model, mat):
    if mat in MATERIAL_TEXTURE:
        return MATERIAL_TEXTURE[mat]
    return "mw_%s" % model


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

    for png in sorted((FOLDER / "textures").glob("*.png")):
        imp = Path(str(png) + ".import")
        if imp.exists():
            write(imp, GI.patch_params(imp.read_text(), GI.PNG_PARAMS))
    for glb in sorted(FOLDER.glob("*.glb")):
        model = glb.stem[3:]
        subs = {"materials": {}, "animations": {}}
        for mat in GI.glb_materials(glb):
            if mat in NO_TEXTURE:
                continue
            tex = texture_for(model, mat)
            tex_res = "%s/%s.png" % (TEXDIR, tex)
            if not (ROOT / tex_res[6:]).exists():
                continue
            tres = FOLDER / "materials" / ("%s.tres" % mat.lower())
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
    for c in changes:
        print(("WOULD CHANGE " if check else "WROTE ") + c)
    print("IMPORT SETTINGS %s (%d files)" % ("STALE" if (check and changes) else "OK", len(changes)))
    return 1 if (check and changes) else 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
