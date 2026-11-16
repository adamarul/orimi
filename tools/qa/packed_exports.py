"""Packed array exports: no script declares an exported Packed*Array with an array-literal default.

    python -I tools/qa/packed_exports.py [--evidence NAME] [--prefix PATH]

Godot 4.7.2's web export drops a saved Packed*Array export whose script default is an array literal
(`@export var x: PackedStringArray = [...]`), so the browser silently reads the default while the
editor and desktop read the saved value (docs/LEVEL_KIT.md, "Packed arrays in scripts"). Declare
them with a constructor instead: `= PackedStringArray([...])`. The export annotation may sit on the
line above the var.
"""
import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

VAR_RE = re.compile(r"^\s*(@export\w*(\([^)]*\))?\s+)?var\s+\w+\s*:\s*Packed\w+Array\s*=\s*\[")
EXPORT_RE = re.compile(r"^\s*@export\w*(\([^)]*\))?\s*$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", default="packed_exports.txt")
    ap.add_argument("--prefix", default="", help="only files under this path (QA self-test)")
    args = ap.parse_args()
    files = [f for f in qalib.project_files() if f.endswith(".gd") and f.startswith(args.prefix)]
    problems = []
    for f in files:
        with open(os.path.join(qalib.ROOT, f), encoding="utf-8", errors="replace") as fh:
            lines = fh.read().splitlines()
        prev = ""
        for n, line in enumerate(lines, 1):
            m = VAR_RE.match(line)
            if m and (m.group(1) or EXPORT_RE.match(prev)):
                problems.append("%s:%d: %s" % (f, n, line.strip()[:120]))
            if line.strip():
                prev = line
    lines = ["# Exported Packed*Array with an array-literal default (dropped by the web export)",
             "scripts scanned: %d" % len(files), ""] + (problems or ["none"])
    ev = qalib.write_evidence(args.evidence, lines)
    if problems:
        qalib.result("FAIL", ev, "%d export(s) with a literal default; first: %s" % (len(problems), problems[0]))
    qalib.result("PASS", ev, "%d script(s), no exported Packed*Array with a literal default" % len(files))


if __name__ == "__main__":
    main()
