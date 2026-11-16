"""Print every model's triangle count, materials, vertex-colour presence and animations; fail over 5,000.

    python tools/assets/tri_count.py [--markdown] [glb ...]     default: every .glb under assets/
"""
import json
import struct
import sys
from pathlib import Path

LIMIT = 5000
MODES_TRIS = {4: lambda n: n // 3, 5: lambda n: max(0, n - 2), 6: lambda n: max(0, n - 2)}


def read_glb(path):
    data = Path(path).read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67:
        raise ValueError("not a glb: %s" % path)
    clen, ctype = struct.unpack_from("<II", data, 12)
    return json.loads(data[20:20 + clen])


def info(path):
    g = read_glb(path)
    acc = g.get("accessors", [])
    mesh_tris = []
    for mesh in g.get("meshes", []):
        t = 0
        for prim in mesh["primitives"]:
            mode = prim.get("mode", 4)
            n = acc[prim["indices"]]["count"] if "indices" in prim else acc[prim["attributes"]["POSITION"]]["count"]
            t += MODES_TRIS.get(mode, lambda n: 0)(n)
        mesh_tris.append(t)
    # A mesh instanced by several nodes is drawn several times; count per node.
    nodes = g.get("nodes", [])
    per_node = [(n.get("name", "?"), mesh_tris[n["mesh"]]) for n in nodes if "mesh" in n]
    drawn = [g["meshes"][n["mesh"]] for n in nodes if "mesh" in n and "colonly" not in n.get("name", "")]
    colors = all("COLOR_0" in p["attributes"] for m in drawn for p in m["primitives"])
    mats = sorted({m.get("name", "?") for m in g.get("materials", [])})
    anims = []
    for a in g.get("animations", []):
        interp = sorted({s.get("interpolation", "LINEAR") for s in a["samplers"]})
        end = max(acc[s["input"]]["max"][0] for s in a["samplers"])
        anims.append("%s (%.2fs %s)" % (a["name"], end, "/".join(interp)))
    return per_node, colors, mats, anims


def main(argv):
    markdown = "--markdown" in argv
    files = [a for a in argv if not a.startswith("--")] or sorted(str(p) for p in Path("assets").rglob("*.glb") if "phase0" not in p.parts)
    failed = False
    rows = []
    for f in files:
        per_node, colors, mats, anims = info(f)
        total = sum(t for _, t in per_node)
        biggest = max((t for _, t in per_node), default=0)
        over = total > LIMIT
        failed |= over
        rows.append((Path(f).as_posix(), total, biggest, len(per_node), colors, mats, anims, over))
    if markdown:
        print("| Model | Triangles | Largest piece | Mesh nodes | Vertex colours | Materials | Animations |")
        print("| - | - | - | - | - | - | - |")
        for f, total, biggest, n, colors, mats, anims, over in rows:
            print("| %s | %d | %d | %d | %s | %s | %s |" % (f, total, biggest, n, "yes" if colors else "NO", ", ".join(mats), ", ".join(anims) or "none"))
    else:
        for f, total, biggest, n, colors, mats, anims, over in rows:
            print("%-48s tris=%5d largest=%5d nodes=%2d vcol=%s %s" % (f, total, biggest, n, colors, "OVER LIMIT" if over else "ok"))
            print("    materials:", ", ".join(mats))
            if anims:
                print("    animations:", ", ".join(anims))
    print("TRIS FAIL" if failed else "TRIS OK (limit %d per model)" % LIMIT)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
