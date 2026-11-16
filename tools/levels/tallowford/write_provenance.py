"""Write assets/levels/tallowford/provenance.json: every model and texture under
assets/levels/tallowford/models and textures (the folk/ cast has its own manifest from the folk generator) with its sha256, the script that made it and the command that re-runs it
(format at the top of tools/qa/provenance.py). gen.sh runs this after it writes its outputs.

    python tools/levels/tallowford/write_provenance.py
"""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "assets/levels/tallowford"
T = "tools/levels/tallowford/"


def source(path):
    stem = path.stem
    if path.suffix == ".glb":
        if stem.startswith("tallowford_"):
            return T + "make_terrain.py", T + "gen.sh terrain"
        return T + "make_model.py", T + "gen.sh " + stem
    if stem.startswith("tallowford_"):
        return T + "paint_terrain.py", T + "gen.sh terrain"
    return T + "paint_models.py", T + "gen.sh " + stem


def main():
    outputs = []
    for f in sorted(p for d in ("models", "textures") for p in (ASSETS / d).rglob("*") if p.suffix in (".glb", ".png")):
        generator, command = source(f)
        assert (ROOT / generator).exists(), generator
        outputs.append({"path": f.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                        "generator": generator, "command": command})
    manifest = ASSETS / "provenance.json"
    with open(manifest, "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"outputs": outputs}, fh, indent=1)
        fh.write("\n")
    print("PROVENANCE %s %d files" % (manifest.relative_to(ROOT).as_posix(), len(outputs)))


if __name__ == "__main__":
    main()
