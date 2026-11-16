"""Provenance: every model, texture and audio file in the project was produced by a script in the
repository.

    python -I tools/qa/provenance.py [--evidence NAME]

Media files are the project files (tracked or untracked, not ignored) with a model, texture or
audio extension, outside docs/ (screenshots and evidence) and tests/. A file is covered when a
provenance manifest lists it with the sha256 of its current bytes and a generator script that
is a project file. Manifests are JSON files named "provenance.json" or "*.provenance.json"
anywhere in the project, written by the generator scripts themselves:

    {
      "generator": "tools/blender/fox.py",          default generator for every output
      "command": "tools/blender/run.sh fox",        optional: how to re-run it
      "outputs": [
        {"path": "assets/characters/fox.glb", "sha256": "<hex>"},
        {"path": "assets/characters/fox_albedo.png", "sha256": "<hex>", "generator": "tools/textures/painted/fox.py"}
      ]
    }

Paths are repository-relative with forward slashes. A hash that no longer matches means the file
was changed after its generator wrote it (or the manifest is stale): FAIL either way.
"""
import argparse
import glob
import hashlib
import json
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

MEDIA_EXT = qalib.MODEL_EXT | qalib.TEXTURE_EXT | qalib.AUDIO_EXT
EXCLUDED_PREFIXES = ("docs/", "tests/")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", default="provenance.txt")
    ap.add_argument("--prefix", default="", help="only media under this path (QA self-test)")
    args = ap.parse_args()
    files = qalib.project_files()
    file_set = set(files)
    media = [f for f in files if os.path.splitext(f)[1].lower() in MEDIA_EXT
             and (f.startswith(args.prefix) if args.prefix else not f.startswith(EXCLUDED_PREFIXES))]
    manifests = [f for f in files if os.path.basename(f) == "provenance.json" or f.endswith(".provenance.json")]
    problems, covered = [], {}
    for m in manifests:
        try:
            with open(os.path.join(qalib.ROOT, m), encoding="utf-8") as fh:
                doc = json.load(fh)
        except Exception as e:  # noqa: BLE001
            problems.append("%s: unreadable manifest: %s" % (m, e))
            continue
        for out in doc.get("outputs", []):
            path = out.get("path", "")
            gen = out.get("generator", doc.get("generator", ""))
            if not gen or gen not in file_set:
                problems.append("%s: %s names generator '%s', which is not a project file" % (m, path, gen))
                continue
            if path not in file_set:
                problems.append("%s: lists %s, which is not a project file (stale entry)" % (m, path))
                continue
            actual = sha256(os.path.join(qalib.ROOT, path))
            if actual != str(out.get("sha256", "")).lower():
                problems.append("%s: %s sha256 does not match (file changed after generation, or manifest stale)" % (m, path))
                continue
            covered[path] = gen
    rows = []
    for f in media:
        if f in covered:
            rows.append("ok       %-58s <- %s" % (f, covered[f]))
        else:
            rows.append("MISSING  %-58s (no manifest entry with a matching hash)" % f)
            problems.append("%s: no provenance" % f)
    lines = ["# Provenance of models, textures and audio",
             "manifests: %d (%s)" % (len(manifests), ", ".join(manifests) or "none"),
             "media files: %d, covered: %d" % (len(media), sum(1 for f in media if f in covered)), ""] + rows
    lines += ["", "problems: %d" % len(problems)] + sorted(set(problems))
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines))
    if problems:
        qalib.result("FAIL", evidence, "%d problem(s); first: %s" % (len(problems), sorted(problems)[0]))
    if not media:
        qalib.result("NOT_YET", evidence, "no media files yet")
    qalib.result("PASS", evidence, "%d media file(s) all tied to a generator script by hash" % len(media))


if __name__ == "__main__":
    main()
