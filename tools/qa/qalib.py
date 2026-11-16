"""Shared helpers for the QA checks in tools/qa/. Python 3.9, standard library only.

Every check script ends by calling result(), which prints one line

    QA_RESULT <STATUS> <evidence path> <detail>

and exits with the status code: PASS 0, FAIL 1, NOT_YET 3, NOT_RUN 4 (missing input such as the
banned-term list). tools/qa/dod.sh collects these lines into its table.
"""
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
EVIDENCE_DIR = os.path.join(ROOT, "docs", "qa", "evidence")
CODES = {"PASS": 0, "FAIL": 1, "NOT_YET": 3, "NOT_RUN": 4}

MODEL_EXT = {".glb", ".gltf", ".obj", ".fbx", ".blend", ".dae", ".3ds", ".stl", ".ply"}
TEXTURE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".tga", ".bmp", ".exr", ".hdr", ".ktx", ".ktx2", ".dds", ".gif"}
AUDIO_EXT = {".wav", ".ogg", ".mp3", ".flac", ".opus", ".aiff"}
FONT_EXT = {".ttf", ".otf", ".woff", ".woff2", ".ttc", ".fnt", ".pfb", ".pfm", ".eot"}


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def project_files(include_untracked=True):
    """Tracked files, plus untracked files that are not git-ignored (what the next commit could hold)."""
    args = ["git", "-C", ROOT, "ls-files", "-z", "--cached"]
    if include_untracked:
        args += ["--others", "--exclude-standard"]
    out = subprocess.run(args, check=True, stdout=subprocess.PIPE).stdout.decode("utf-8", "replace")
    files = sorted({f for f in out.split("\0") if f})
    return [f for f in files if os.path.isfile(os.path.join(ROOT, f))]


def is_binary(data):
    return b"\0" in data[:8192]


def write_evidence(name, lines):
    os.makedirs(EVIDENCE_DIR, exist_ok=True)
    path = os.path.join(EVIDENCE_DIR, name)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")
    return rel(path)


def result(status, evidence, detail):
    detail = " ".join(str(detail).split())
    print("QA_RESULT %s %s %s" % (status, evidence or "-", detail))
    sys.exit(CODES[status])
