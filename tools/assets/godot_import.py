"""Godot import settings and materials for every generated model and texture.

    python tools/assets/godot_import.py            write materials, patch .import files
    python tools/assets/godot_import.py --check    exit 1 if anything would change

For each model it writes one StandardMaterial3D .tres per glTF material (resource_name = the
glTF material name, so a "_sacred" suffix survives; albedo = the model's painted texture) and
points the glb's import at those materials ("use_external"), so the glb carries geometry,
vertex colours, material names and animations while the texture stays an ordinary imported
PNG. It also sets looping animations, turns off LOD generation (it would eat silhouettes) and
shadow meshes, and makes textures mipmapped lossy-WebP for a small web download.
A .import file must exist first: run the Godot import once (tools/assets/gen_all.sh does).

Generators outside this file (the folk generator, level workstreams) register their models in a
"godot_import.json" anywhere under assets/:
    {"<glb path>": {"texture": "<png path>", "textures": ["<more png paths>"], "loops": ["idle"]}}
"texture" is the albedo of every material in the glb; "textures" are further PNGs that only need
the texture import settings (a folk person's faded atlas).
"""
import json
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

MODELS = {
    "assets/characters/fox.glb": ("fox", ["idle", "run", "fall", "brush_pose"]),
    "assets/characters/splotchet.glb": ("splotchet", ["idle", "hop"]),
    "assets/characters/reedwraith.glb": ("reedwraith", ["idle", "drift"]),
    "assets/props/sapling.glb": ("sapling", ["withered"]),
    "assets/props/great_tree.glb": ("great_tree", ["withered"]),
    "assets/props/thorn_gate.glb": ("thorn_gate", []),
    "assets/props/shrine.glb": ("shrine", []),
    "assets/props/stepping_stone.glb": ("stepping_stone", []),
    "assets/props/rocks.glb": ("rocks", []),
    "assets/props/reeds.glb": ("reeds", []),
    "assets/props/raft.glb": ("raft", ["bob"]),
    "assets/environment/valley_terrain.glb": ("terrain", []),
    "assets/environment/river_surface.glb": ("terrain", []),
}
# Materials whose texture differs from the model default.
MATERIAL_TEXTURE = {"M_walls": "terrain_walls", "M_ridges": "terrain_walls", "M_river": "terrain_walls"}

GLB_PARAMS = {
    "nodes/root_type": '"Node3D"',
    "meshes/generate_lods": "false",
    "meshes/create_shadow_meshes": "false",
    "meshes/light_baking": "0",
    "animation/fps": "12",
    "animation/remove_immutable_tracks": "false",
    "gltf/embedded_image_handling": "0",
}
PNG_PARAMS = {
    "compress/mode": "1",
    "compress/lossy_quality": "0.85",
    "mipmaps/generate": "true",
    "detect_3d/compress_to": "0",
}


def glb_materials(path):
    data = path.read_bytes()
    clen = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20 + clen])
    return [m.get("name", "") for m in g.get("materials", [])]


def import_uid(path):
    imp = Path(str(path) + ".import")
    if not imp.exists():
        return None
    m = re.search(r'^uid="([^"]+)"', imp.read_text(), re.M)
    return m.group(1) if m else None


def material_tres(name, texture_res, texture_uid):
    uid = ' uid="%s"' % texture_uid if texture_uid else ""
    lines = [
        '[gd_resource type="StandardMaterial3D" load_steps=2 format=3]',
        "",
        '[ext_resource type="Texture2D"%s path="%s" id="1"]' % (uid, texture_res),
        "",
        "[resource]",
        'resource_name = "%s"' % name,
        'albedo_texture = ExtResource("1")',
        "texture_filter = 3",
        "",
    ]
    return "\n".join(lines)


def godot_value(v, indent=0):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = ['"%s": %s' % (k, godot_value(v[k])) for k in sorted(v)]
        return "{\n" + ",\n".join(items) + "\n}"
    raise TypeError(v)


def subresources_satisfied(text, subs):
    """Godot rewrites _subresources in its own expanded form after an import; accept that form
    when it already holds every material mapping and loop flag we want."""
    for mat, opts in subs.get("materials", {}).items():
        if '"use_external/path": "%s"' % opts["use_external/path"] not in text:
            return False
    for name in subs.get("animations", {}):
        if not re.search(r'"%s": \{[^}]*?"settings/loop_mode": 1,' % re.escape(name), text):
            return False
    have_loops = set(re.findall(r'"([^"]+)": \{[^{}]*?"settings/loop_mode": 1,', text))
    return have_loops <= set(subs.get("animations", {}))


def patch_params(text, params):
    head, sep, body = text.partition("[params]\n")
    if not sep:
        raise ValueError("no [params] section")
    lines = body.split("\n")
    out, seen, i = [], set(), 0
    while i < len(lines):
        line = lines[i]
        key = line.split("=", 1)[0] if "=" in line else None
        if key in params:
            seen.add(key)
            out.append("%s=%s" % (key, params[key]))
            if line.split("=", 1)[1].startswith("{") and not line.rstrip().endswith("}"):
                depth = line.count("{") - line.count("}")
                while depth > 0 and i + 1 < len(lines):
                    i += 1
                    depth += lines[i].count("{") - lines[i].count("}")
        else:
            out.append(line)
        i += 1
    while out and out[-1] == "":
        out.pop()
    for key in params:
        if key not in seen:
            out.append("%s=%s" % (key, params[key]))
    return head + sep + "\n".join(out) + "\n"


LOOPING_MUSIC = ("title", "vale_cursed", "vale_restored")
LOOPING_SFX = ("lamp_hum",)


def registries():
    """Models and textures registered by other generators in godot_import.json files."""
    models, textures = {}, []
    for reg in sorted(ROOT.glob("assets/**/godot_import.json")):
        for glb, entry in json.loads(reg.read_text(encoding="utf-8")).items():
            models[glb] = (entry["texture"], entry.get("loops", []))
            textures += [entry["texture"]] + entry.get("textures", [])
    return models, textures


def texture_path(texture):
    return texture if "/" in texture else "assets/textures/painted/%s.png" % texture


def main(check):
    changes = []
    extra_models, extra_textures = registries()

    def write(path, text):
        if path.exists() and path.read_text() == text:
            return
        changes.append(path.relative_to(ROOT).as_posix())
        if not check:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, "w", newline="\n") as f:
                f.write(text)

    pngs = sorted((ROOT / "assets/textures/painted").glob("*.png")) + [ROOT / t for t in extra_textures]
    for png in pngs:
        imp = Path(str(png) + ".import")
        if imp.exists():
            write(imp, patch_params(imp.read_text(), PNG_PARAMS))

    for ogg in sorted((ROOT / "audio").rglob("*.ogg")):
        imp = Path(str(ogg) + ".import")
        if imp.exists():
            loop = ogg.stem in {"music": LOOPING_MUSIC, "sfx": LOOPING_SFX}.get(ogg.parent.name, ())
            write(imp, patch_params(imp.read_text(), {"loop": "true" if loop else "false", "loop_offset": "0.0"}))

    for rel, (texture, loops) in list(MODELS.items()) + list(extra_models.items()):
        glb = ROOT / rel
        if not glb.exists():
            continue
        subs = {"materials": {}, "animations": {}}
        for mat in glb_materials(glb):
            tex_res = "res://" + texture_path(MATERIAL_TEXTURE.get(mat, texture))
            tres = glb.parent / "materials" / ("%s.tres" % mat.lower())
            write(tres, material_tres(mat, tex_res, import_uid(ROOT / tex_res[6:])))
            res = "res://" + tres.relative_to(ROOT).as_posix()
            subs["materials"][mat] = {"use_external/enabled": True, "use_external/path": res, "use_external/fallback_path": res}
        for name in loops:
            subs["animations"][name] = {"settings/loop_mode": 1}
        subs = {k: v for k, v in subs.items() if v}
        imp = Path(str(glb) + ".import")
        if imp.exists():
            text = imp.read_text()
            params = dict(GLB_PARAMS)
            if not subresources_satisfied(text, subs):
                params["_subresources"] = godot_value(subs)
            write(imp, patch_params(text, params))
        else:
            print("missing import file (run the Godot import first):", rel)

    for c in changes:
        print(("WOULD CHANGE " if check else "WROTE ") + c)
    print("IMPORT SETTINGS %s (%d files)" % ("STALE" if (check and changes) else "OK", len(changes)))
    return 1 if (check and changes) else 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
