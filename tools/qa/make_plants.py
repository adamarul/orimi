"""Writes the planted-defect fixtures for tools/qa/selftest.sh into tests/_plant/ (deleted after).

    python -I tools/qa/make_plants.py <case>

Cases: glb_over, glb_ok, prov_ok, prov_tamper, shader, shader_doc, font, font_licence, readme, badgd
"""
import hashlib
import json
import os
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
PLANT = os.path.join(ROOT, "tests", "_plant")


def write(rel, data):
    p = os.path.join(PLANT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb" if isinstance(data, bytes) else "w", **({} if isinstance(data, bytes) else {"encoding": "utf-8", "newline": "\n"})) as f:
        f.write(data)
    return p


def glb(tris):
    count = tris * 3
    bin_len = count * 12
    doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0, "name": "plant"}],
           "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
           "accessors": [{"bufferView": 0, "componentType": 5126, "count": count, "type": "VEC3", "min": [0, 0, 0], "max": [0, 0, 0]}],
           "bufferViews": [{"buffer": 0, "byteLength": bin_len}], "buffers": [{"byteLength": bin_len}]}
    js = json.dumps(doc).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<I4s", len(js), b"JSON") + js + struct.pack("<I4s", bin_len, b"BIN\0") + b"\0" * bin_len
    return struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body


def png_bytes(seed):
    import zlib
    raw = b"".join(b"\0" + bytes((seed * 7 + x * 3 + y) % 256 for x in range(16 * 3)) for y in range(16))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def main():
    case = sys.argv[1]
    if case == "glb_over":
        write("over_budget.glb", glb(6000))
    elif case == "glb_ok":
        write("in_budget.glb", glb(4999))
    elif case in ("prov_ok", "prov_tamper"):
        write("gen_plant_texture.py", "# plant generator for the provenance self-test\n")
        p = write("tex/plant.png", png_bytes(1))
        digest = hashlib.sha256(open(p, "rb").read()).hexdigest()
        write("tex/plant.provenance.json", json.dumps({"generator": "tests/_plant/gen_plant_texture.py",
                                                       "outputs": [{"path": "tests/_plant/tex/plant.png", "sha256": digest}]}, indent=1))
        if case == "prov_tamper":
            write("tex/plant.png", png_bytes(2))
            write("tex/orphan.wav", b"RIFF\0\0\0\0WAVE")
    elif case == "shader":
        write("plant.gdshader", "shader_type spatial;\nuniform float plant_documented = 1.0;\nuniform vec4 plant_undocumented : source_color;\nvoid fragment() { ALBEDO = vec3(plant_documented) * plant_undocumented.rgb; }\n")
        write("PLANT_SHADERS.md", "# plant.gdshader\n\n| uniform | meaning | range | default |\n| - | - | - | - |\n| plant_documented | test | 0-1 | 1 |\n")
    elif case == "shader_doc":
        write("PLANT_SHADERS.md", "# plant.gdshader\n\n| uniform | meaning | range | default |\n| - | - | - | - |\n| plant_documented | test | 0-1 | 1 |\n| plant_undocumented | test | colour | black |\n")
    elif case == "font":
        write("fonts/PlantSans.ttf", b"\0\1\0\0" + os.urandom(64))
    elif case == "font_licence":
        write("fonts/OFL.txt", "SIL Open Font License 1.1 (plant)\n")
    elif case == "readme":
        for lvl in ("light", "normal", "heavy"):
            for kind in ("web", "desktop"):
                write("shots/valley_%s_%s.png" % (lvl, kind), png_bytes(3))
        write("SHADERS.md", "# shaders\n")
        write("README.md", "\n".join([
            "# Orimi: The Unfaded Vale", "", "## Running", "Desktop: tools/run_desktop.sh. Browser: tools/export_web.sh then tools/serve_web.sh.", "",
            "## Controls", "W A S D move, Space jump, J attack, Shift or Q brush, Esc pause, F2 paper.", "",
            "## Glyphs", "Bloom: a circle. Slash: a horizontal line. Gust: a loop.", "",
            "## Screenshots", "![light](tests/_plant/shots/valley_light_web.png) ![normal](tests/_plant/shots/valley_normal_web.png)", "",
            "## Credits and licences", "Made here."]) + "\n")
    elif case == "badgd":
        write("bad_script.gd", "extends Node\nfunc _ready() -> void\n\tvar x := \n")
    else:
        sys.exit("unknown case " + case)


if __name__ == "__main__":
    main()
