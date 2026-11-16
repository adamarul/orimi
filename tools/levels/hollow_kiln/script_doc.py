"""Write docs/levels/hollow_kiln/SCRIPT.md from scripts/levels/hollow_kiln/kiln_script.json, so the
readable script and the data phase B loads cannot disagree.

    python tools/levels/hollow_kiln/script_doc.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SRC = os.path.join(ROOT, "scripts", "levels", "hollow_kiln", "kiln_script.json")
OUT = os.path.join(ROOT, "docs", "levels", "hollow_kiln", "SCRIPT.md")


def main():
    with open(SRC, encoding="utf-8") as f:
        data = json.load(f)
    out = ["# The Hollow Kiln: script (\"%s\")" % data["title"], "",
           "Every line of talk, narration and verse in Level 5. Generated from",
           "`scripts/levels/hollow_kiln/kiln_script.json` by `tools/levels/hollow_kiln/script_doc.py`; edit the",
           "JSON, then rerun. Markers are in DESIGN.md. %s" % data["markup"], "", "## Speakers", ""]
    for key, s in data["speakers"].items():
        out.append("- **%s** (`%s`): %s" % (s["name"] or key, key, s["voice"]))
    beat = None
    for sc in data["scenes"]:
        if sc["beat"] != beat:
            beat = sc["beat"]
            out += ["", "## Beat %d" % beat]
        who = data["speakers"][sc["speaker"]]["name"] or sc["speaker"]
        out += ["", "### `%s` (%s, at %s%s)" % (sc["id"], who, sc["where"], ", once" if sc["once"] else ""), "",
                "*%s*" % sc["trigger"], ""]
        if sc["speaker"] == "verse":
            out += ["> " + line + ("  " if k < len(sc["lines"]) - 1 else "") for k, line in enumerate(sc["lines"])]
        else:
            out += ["- " + line for line in sc["lines"]]
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("SCRIPT", os.path.relpath(OUT, ROOT).replace(os.sep, "/"), len(data["scenes"]), "scenes")


if __name__ == "__main__":
    main()
