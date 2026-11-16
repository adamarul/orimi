"""Provenance manifest for Mosswater Wood's generated assets (format: tools/qa/provenance.py).

    python tools/levels/mosswater/write_provenance.py

Lists every .glb and .png under assets/levels/mosswater/ with its sha256 and the script that
made it. tools/levels/mosswater/gen.sh runs this after it writes its outputs.
"""
import hashlib
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
FOLDER = ROOT / "assets/levels/mosswater"


def main():
    outputs = []
    for f in sorted(list(FOLDER.glob("*.glb")) + list((FOLDER / "textures").glob("*.png"))):
        gen = "tools/levels/mosswater/make_mw.py" if f.suffix == ".glb" else "tools/levels/mosswater/paint_mw.py"
        name = f.stem[3:] if f.stem.startswith("mw_") else f.stem
        if name in ("water", "ground", "cliff"):
            name = "terrain"
        outputs.append({"path": f.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(f.read_bytes()).hexdigest(),
                        "generator": gen, "command": "tools/levels/mosswater/gen.sh %s" % name})
    manifest = FOLDER / "provenance.json"
    with open(manifest, "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"generator": "tools/levels/mosswater/make_mw.py", "outputs": outputs}, fh, indent=1)
        fh.write("\n")
    print("PROVENANCE %s %d files" % (manifest.relative_to(ROOT).as_posix(), len(outputs)))


if __name__ == "__main__":
    main()
