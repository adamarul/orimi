"""Licences: every font and every other third-party file has its licence beside it.

    python -I tools/qa/licences.py [--evidence NAME]

Fonts (.ttf .otf .woff .woff2 ...) need a licence file in the same folder: a file whose name
contains LICENSE / LICENCE / COPYING / OFL / NOTICE, or <font name>.txt / .md mentioning a
licence. Folders named addons/, thirdparty/, third_party/ or vendor/ hold third-party code by
convention and need a licence file in the folder or one of its parents up to that folder.
Text files carrying a foreign copyright or SPDX header are listed for review; they FAIL only
when no licence file sits beside them. The brief allows openly licensed fonts as the one
third-party exception, so the listing is also what the lead reviews.
"""
import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

LICENCE_NAME = re.compile(r"(licen[cs]e|copying|ofl|notice)", re.I)
THIRD_PARTY_DIRS = ("addons", "thirdparty", "third_party", "vendor")
HEADER_RE = re.compile(r"(SPDX-License-Identifier|Copyright \(c\)|Copyright ©|Permission is hereby granted|Licensed under the)", re.I)


def licence_beside(path, files_by_dir):
    d = os.path.dirname(path)
    stem = os.path.splitext(os.path.basename(path))[0].lower()
    for other in files_by_dir.get(d, []):
        name = os.path.basename(other)
        if other == path:
            continue
        if LICENCE_NAME.search(name):
            return other
        if name.lower().startswith(stem) and name.lower().endswith((".txt", ".md")):
            with open(os.path.join(qalib.ROOT, other), encoding="utf-8", errors="replace") as fh:
                if re.search(r"licen[cs]e", fh.read(), re.I):
                    return other
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", default="licences.txt")
    ap.add_argument("--prefix", default="", help="only files under this path (QA self-test)")
    args = ap.parse_args()
    files = [f for f in qalib.project_files() if f.startswith(args.prefix)]
    by_dir = {}
    for f in files:
        by_dir.setdefault(os.path.dirname(f), []).append(f)
    rows, problems = [], []
    for f in files:
        ext = os.path.splitext(f)[1].lower()
        parts = f.split("/")
        tp_dir = next((i for i, p in enumerate(parts[:-1]) if p.lower() in THIRD_PARTY_DIRS), None)
        reason = None
        if ext in qalib.FONT_EXT:
            reason = "font"
        elif tp_dir is not None:
            reason = "in %s/" % parts[tp_dir]
        elif not f.startswith(("docs/", "tools/qa/")) and ext in (".gd", ".gdshader", ".gdshaderinc", ".py", ".js", ".cjs", ".sh", ".txt", ".md", ".cfg"):
            with open(os.path.join(qalib.ROOT, f), encoding="utf-8", errors="replace") as fh:
                head = fh.read(4000)
            if HEADER_RE.search(head):
                reason = "licence/copyright header"
        if not reason:
            continue
        lic = licence_beside(f, by_dir)
        if lic is None and tp_dir is not None:
            for depth in range(len(parts) - 1, tp_dir, -1):
                d = "/".join(parts[:depth])
                lic = next((o for o in by_dir.get(d, []) if LICENCE_NAME.search(os.path.basename(o))), None)
                if lic:
                    break
        if lic:
            rows.append("ok       %-55s %-26s licence: %s" % (f, reason, lic))
        else:
            rows.append("MISSING  %-55s %-26s no licence file beside it" % (f, reason))
            problems.append("%s (%s): no licence beside it" % (f, reason))
    lines = ["# Licences of fonts and third-party files", "files needing a licence: %d, missing: %d" % (len(rows), len(problems)), ""] + rows
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines))
    if problems:
        qalib.result("FAIL", evidence, "%d file(s) without a licence; first: %s" % (len(problems), problems[0]))
    qalib.result("PASS", evidence, "%d font/third-party file(s), each with a licence beside it" % len(rows))


if __name__ == "__main__":
    main()
