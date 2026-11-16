"""Shader documentation: every uniform in every .gdshader / .gdshaderinc appears in docs/SHADERS.md,
docs/SHADERS_VFX.md or docs/BRUSH.md. The toolchain probe shaders under shaders/phase0/ are test
fixtures, described in docs/RENDERER_NOTES.md, and are not checked (lead's decision, QA F-003).

    python -I tools/qa/shader_docs.py [--evidence NAME] [--docs a.md,b.md]

A uniform is documented when its name appears as a whole word (ideally in backticks) on a line of
either document that also names the shader file (in a table row) or below a heading that names
the shader file. Uniforms inside #if blocks count too: they are part of the web or desktop build.
"""
import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

UNIFORM_RE = re.compile(
    r"\b(?:(global|instance)\s+)?uniform\s+(?:(?:lowp|mediump|highp)\s+)?(\w+)\s+(\w+)\s*(?:\[[^\]]*\])?\s*(?::[^;=]*)?(?:=[^;]*)?;")


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def doc_sections(text):
    """Map each line to the heading text above it, so 'under a heading naming the file' works."""
    heading = ""
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            heading = line
        out.append((heading, line))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", default="shader_docs.txt")
    ap.add_argument("--docs", default="docs/SHADERS.md,docs/SHADERS_VFX.md,docs/BRUSH.md")
    ap.add_argument("--exclude", default="shaders/phase0/", help="skip shaders under this path")
    ap.add_argument("--prefix", default="", help="only shaders under this path (QA self-test)")
    args = ap.parse_args()
    docs = [d for d in args.docs.split(",") if d]
    doc_lines = []
    present = []
    for d in docs:
        p = os.path.join(qalib.ROOT, d)
        if os.path.isfile(p):
            present.append(d)
            with open(p, encoding="utf-8") as fh:
                doc_lines += doc_sections(fh.read())
    shaders = [f for f in qalib.project_files() if f.endswith((".gdshader", ".gdshaderinc")) and f.startswith(args.prefix)
               and not (args.exclude and f.startswith(args.exclude))]
    rows, missing = [], []
    total = 0
    for s in shaders:
        with open(os.path.join(qalib.ROOT, s), encoding="utf-8") as fh:
            text = strip_comments(fh.read())
        base = os.path.basename(s)
        stem = os.path.splitext(base)[0]
        for m in UNIFORM_RE.finditer(text):
            name = m.group(3)
            total += 1
            word = re.compile(r"(?<![\w])%s(?![\w])" % re.escape(name))
            file_word = re.compile(r"(?<![\w])%s(?:\.gdshader(?:inc)?)?(?![\w])" % re.escape(stem))
            ok_scoped = any(word.search(line) and (file_word.search(line) or file_word.search(head) or base in line or base in head)
                            for head, line in doc_lines)
            ok_any = any(word.search(line) for _h, line in doc_lines)
            if ok_scoped:
                rows.append("ok        %s: %s" % (s, name))
            elif ok_any:
                rows.append("UNSCOPED  %s: %s (named in the docs, but not under or beside %s)" % (s, name, base))
                missing.append("%s: %s documented without naming the shader" % (s, name))
            else:
                rows.append("MISSING   %s: %s" % (s, name))
                missing.append("%s: %s not documented" % (s, name))
    lines = ["# Shader uniform documentation",
             "docs present: %s; absent: %s" % (", ".join(present) or "none", ", ".join(d for d in docs if d not in present) or "none"),
             "shaders: %d, uniforms: %d, undocumented: %d" % (len(shaders), total, len(missing)), ""] + rows
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines))
    if missing:
        qalib.result("FAIL", evidence, "%d of %d uniform(s) undocumented; first: %s" % (len(missing), total, missing[0]))
    if not shaders:
        qalib.result("NOT_YET", evidence, "no shaders")
    qalib.result("PASS", evidence, "all %d uniform(s) in %d shader(s) documented" % (total, len(shaders)))


if __name__ == "__main__":
    main()
