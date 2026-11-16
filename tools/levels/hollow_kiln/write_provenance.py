"""Write assets/levels/hollow_kiln/provenance.json (format: tools/qa/provenance.py): every model and
texture of the level with its sha256, the script that made it and the command that re-runs it.

    python -I tools/levels/hollow_kiln/write_provenance.py
"""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "assets" / "levels" / "hollow_kiln"
T = "tools/levels/hollow_kiln/"
ARCH = {"ground_s", "ground_n", "far", "water", "yard", "hall", "flue", "kiln"}
SCRIPT = {"dregs": T + "make_dregs.py", "vat_tree": T + "make_tree.py"}


def source(path):
    stem = path.stem
    if path.suffix == ".glb":
        gen = T + "make_architecture.py" if stem in ARCH else SCRIPT.get(stem, T + "make_props.py")
        return gen, T + "gen.sh " + stem
    return T + "paint_kiln.py", T + "gen.sh " + (stem if not stem.startswith("hk_") else "textures")


def main():
    outputs = []
    for f in sorted(list((BASE / "models").glob("*.glb")) + list((BASE / "textures").glob("*.png"))):
        gen, cmd = source(f)
        assert (ROOT / gen).exists(), gen
        outputs.append({"path": f.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                        "generator": gen, "command": cmd})
    with open(BASE / "provenance.json", "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"generator": T + "gen.sh", "command": T + "gen.sh", "outputs": outputs}, fh, indent=1)
        fh.write("\n")
    print("PROVENANCE assets/levels/hollow_kiln/provenance.json %d files" % len(outputs))


if __name__ == "__main__":
    main()
