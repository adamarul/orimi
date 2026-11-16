"""Triangle count of every glTF model in the project, read from the glTF data itself.

    python -I tools/qa/glb_tris.py [--budget 5000] [--evidence NAME] [files...]

For each .glb / .gltf, triangles are counted the way the model renders: every node of the
default scene (or every scene) that references a mesh adds that mesh's triangles once per
instance (EXT_mesh_gpu_instancing multiplies), so a mesh reused by three nodes counts three
times. Primitive modes: TRIANGLES count/3, STRIP and FAN count-2, points and lines 0. The count
is indices.count when the primitive is indexed, else POSITION.count. FAIL above the budget.
Other model formats (.obj, .fbx, .blend, ...) found among project files are listed as FAIL:
the brief says models are glTF from the Blender scripts.
"""
import argparse
import json
import os
import struct
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402


def load_gltf(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] == b"glTF":
        _magic, version, _length = struct.unpack_from("<4sII", data, 0)
        if version != 2:
            raise ValueError("glTF version %d, expected 2" % version)
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, 12)
        if chunk_type != b"JSON":
            raise ValueError("first chunk is not JSON")
        return json.loads(data[20:20 + chunk_len].decode("utf-8"))
    return json.loads(data.decode("utf-8"))


def primitive_tris(gltf, prim):
    mode = prim.get("mode", 4)
    accessors = gltf.get("accessors", [])
    if "indices" in prim:
        count = accessors[prim["indices"]]["count"]
    else:
        count = accessors[prim["attributes"]["POSITION"]]["count"]
    if mode == 4:
        return count // 3
    if mode in (5, 6):
        return max(count - 2, 0)
    return 0


def count_model(gltf):
    meshes = gltf.get("meshes", [])
    mesh_tris = [sum(primitive_tris(gltf, p) for p in m.get("primitives", [])) for m in meshes]
    nodes = gltf.get("nodes", [])
    scenes = gltf.get("scenes", [])
    if "scene" in gltf:
        roots = scenes[gltf["scene"]].get("nodes", [])
    elif scenes:
        roots = [n for s in scenes for n in s.get("nodes", [])]
    else:
        children = {c for n in nodes for c in n.get("children", [])}
        roots = [i for i in range(len(nodes)) if i not in children]
    rendered = 0
    instances = 0
    stack = list(roots)
    seen = set()
    while stack:
        i = stack.pop()
        if i in seen:
            continue
        seen.add(i)
        node = nodes[i]
        if "mesh" in node:
            copies = 1
            inst = node.get("extensions", {}).get("EXT_mesh_gpu_instancing")
            if inst and inst.get("attributes"):
                first = next(iter(inst["attributes"].values()))
                copies = gltf["accessors"][first]["count"]
            rendered += mesh_tris[node["mesh"]] * copies
            instances += copies
        stack.extend(node.get("children", []))
    return {"rendered": rendered, "unique": sum(mesh_tris), "meshes": len(meshes), "instances": instances}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--budget", type=int, default=5000)
    ap.add_argument("--evidence", default="tris.txt")
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()
    files = args.files or [f for f in qalib.project_files() if os.path.splitext(f)[1].lower() in qalib.MODEL_EXT]
    rows, failures = [], []
    for f in files:
        path = os.path.join(qalib.ROOT, f) if not os.path.isabs(f) else f
        name = qalib.rel(path) if os.path.isabs(f) else f
        ext = os.path.splitext(f)[1].lower()
        if ext not in (".glb", ".gltf"):
            failures.append("%s: not glTF (%s); models must be glTF from the Blender scripts" % (name, ext))
            continue
        try:
            c = count_model(load_gltf(path))
        except Exception as e:  # noqa: BLE001
            failures.append("%s: unreadable glTF: %s" % (name, e))
            continue
        verdict = "ok" if c["rendered"] <= args.budget else "OVER"
        rows.append("%-60s %7d %7d %4d %4d  %s" % (name, c["rendered"], c["unique"], c["meshes"], c["instances"], verdict))
        if verdict == "OVER":
            failures.append("%s: %d triangles > %d" % (name, c["rendered"], args.budget))
    lines = ["# Triangle counts (budget %d per model, counted as rendered)" % args.budget,
             "%-60s %7s %7s %4s %4s" % ("file", "tris", "unique", "mesh", "inst")] + rows
    lines += ["", "failures: %d" % len(failures)] + failures
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines))
    if failures:
        qalib.result("FAIL", evidence, "%d model(s) fail; %s" % (len(failures), failures[0]))
    if not rows:
        qalib.result("NOT_YET", evidence, "no glTF models in the project")
    worst = max(rows, key=lambda r: int(r.split()[1]))
    qalib.result("PASS", evidence, "%d model(s) within %d tris; largest: %s" % (len(rows), args.budget, " ".join(worst.split()[:2])))


if __name__ == "__main__":
    main()
