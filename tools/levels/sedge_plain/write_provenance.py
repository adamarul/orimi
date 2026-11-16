"""Write assets/levels/sedge_plain/provenance.json: every model and texture this level's generators
wrote, with its sha256 and the script that made it (checked by tools/qa/qa.sh provenance).

    python tools/levels/sedge_plain/write_provenance.py
"""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "assets/levels/sedge_plain"
CMD = "tools/levels/sedge_plain/gen_all.sh"


def source(f):
    rel = f.relative_to(BASE).as_posix()
    if rel.startswith("terrain/"):
        return "tools/levels/sedge_plain/make_terrain.py"
    if rel.startswith("props/"):
        return "tools/levels/sedge_plain/make_props.py"
    if f.stem in ("ground", "hills"):
        return "tools/levels/sedge_plain/paint_ground.py"
    return "tools/levels/sedge_plain/paint_props.py"


def main():
    outputs = []
    for f in sorted(list(BASE.glob("terrain/*.glb")) + list(BASE.glob("props/*.glb")) + list(BASE.glob("textures/*.png"))):
        gen = source(f)
        assert (ROOT / gen).exists(), gen
        outputs.append({"path": f.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(f.read_bytes()).hexdigest(), "generator": gen})
    manifest = BASE / "provenance.json"
    with open(manifest, "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"generator": "tools/levels/sedge_plain/gen_all.sh", "command": CMD, "outputs": outputs}, fh, indent=1)
        fh.write("\n")
    print("PROVENANCE %s %d files" % (manifest.relative_to(ROOT).as_posix(), len(outputs)))


if __name__ == "__main__":
    main()
