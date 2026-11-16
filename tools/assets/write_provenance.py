"""Write the provenance manifests that tools/qa/provenance.py checks: one provenance.json per
asset folder, listing every model, texture and sound with its sha256 and the script that made it.
gen_models.sh and gen_audio.sh run this after they write their outputs.

    python tools/assets/write_provenance.py
"""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]


def models(path):
    name = "terrain" if path.parent.name == "environment" else path.stem
    return "tools/blender/make_%s.py" % name, "tools/assets/gen_models.sh %s" % name


def textures(path):
    if path.stem.startswith("terrain"):
        return "tools/textures/painted/paint_terrain.py", "tools/assets/gen_models.sh terrain"
    return "tools/textures/painted/paint_models.py", "tools/assets/gen_models.sh %s" % path.stem


FOLDERS = {
    "assets/characters": ("*.glb", models),
    "assets/props": ("*.glb", models),
    "assets/environment": ("*.glb", models),
    "assets/textures/painted": ("*.png", textures),
    "audio/sfx": ("*.ogg", lambda p: ("tools/audio/sfx.py", "tools/assets/gen_audio.sh")),
    "audio/music": ("*.ogg", lambda p: ("tools/audio/music.py", "tools/assets/gen_audio.sh")),
    **{"audio/levels/%s" % level: ("*.ogg", lambda p: ("tools/audio/level_music.py", "tools/assets/gen_audio.sh"))
       for level in ("tallowford", "sedge_plain", "mosswater", "hollow_kiln")},
}


def main():
    for folder, (pattern, source) in FOLDERS.items():
        outputs = []
        for f in sorted((ROOT / folder).glob(pattern)):
            generator, command = source(f)
            assert (ROOT / generator).exists(), generator
            outputs.append({"path": f.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                            "generator": generator, "command": command})
        manifest = ROOT / folder / "provenance.json"
        with open(manifest, "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"outputs": outputs}, fh, indent=1)
            fh.write("\n")
        print("PROVENANCE %s %d files" % (manifest.relative_to(ROOT).as_posix(), len(outputs)))


if __name__ == "__main__":
    main()
