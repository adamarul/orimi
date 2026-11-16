"""Deliverable documents (definition of done line 8): README.md, docs/SHADERS.md and the three
paper-intensity screenshots exist, and the README covers what the brief asks for.

    python -I tools/qa/docs_check.py [--evidence NAME]

README.md must: name the game's title (from project.godot); explain running on desktop and in
the browser; list the controls (every input action's keys); give a glyph guide naming Bloom,
Slash and Gust with their shapes; have credits/licences; and embed images from
docs/screenshots/ for Light, Normal and Heavy that exist on disk, at least one set from the web
build (file name containing "web"). docs/SHADERS.md must exist (its completeness is the
shader_docs check). Whether the screenshots match the build is judged by eye and by the visual
checks, not here.
"""
import argparse
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

KEYS = ["W", "A", "S", "D", "Space", "Shift", "Q", "Esc", "F2", "J"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", default="docs_check.txt")
    ap.add_argument("--readme", default="README.md", help="other paths for the QA self-test")
    ap.add_argument("--shots", default="docs/screenshots")
    ap.add_argument("--shaders", default="docs/SHADERS.md")
    args = ap.parse_args()
    rows, problems = [], []

    def need(ok, what):
        rows.append(("ok       " if ok else "MISSING  ") + what)
        if not ok:
            problems.append(what)

    with open(os.path.join(qalib.ROOT, "project.godot"), encoding="utf-8") as fh:
        m = re.search(r'config/name="([^"]+)"', fh.read())
    title = m.group(1) if m else ""
    readme_path = os.path.join(qalib.ROOT, args.readme)
    readme = open(readme_path, encoding="utf-8").read() if os.path.isfile(readme_path) else ""
    need(bool(readme), "README.md exists")
    if readme:
        low = readme.lower()
        need(bool(title) and title.lower() in low, "README names the title from project.godot (%s)" % title)
        need("run_desktop" in low or "desktop" in low, "README: how to run on desktop")
        need("serve_web" in low or "browser" in low, "README: how to run in the browser")
        need("control" in low and all(re.search(r"(?<!\w)%s(?!\w)" % re.escape(k.lower()), low) for k in KEYS),
             "README: controls section naming %s" % ", ".join(KEYS))
        shape_words = r"(circle|loop|ring|line|stroke|curl|spiral|swirl|dab|draw)"
        glyph_re = re.compile(r"(?<!\w)(bloom|slash|gust|kindle|tie)(?!\w)")
        shaped = set()
        for ln in low.splitlines():
            hits = list(glyph_re.finditer(ln))
            for i, m in enumerate(hits):
                seg = ln[m.end():hits[i + 1].start() if i + 1 < len(hits) else len(ln)]
                if re.search(shape_words, seg):
                    shaped.add(m.group(1))
        unshaped = [g for g in ("bloom", "slash", "gust") if g not in shaped]
        need(not unshaped, "README: glyph guide (Bloom, Slash and Gust each with the shape to draw)"
             + ("; no shape given for " + ", ".join(unshaped) if unshaped else ""))
        need(("credit" in low) and ("licen" in low), "README: credits and licences")
        imgs = re.findall(r"!\[[^\]]*\]\(([^)\s]+)", readme) + re.findall(r'<img[^>]+src="([^"]+)"', readme)
        shots = [i for i in imgs if args.shots.rstrip("/") + "/" in i]
        for level in ("light", "normal", "heavy"):
            hits = [i for i in shots if level in i.lower()]
            exists = [i for i in hits if os.path.isfile(os.path.join(qalib.ROOT, i.lstrip("./")))]
            need(bool(exists), "README embeds an existing %s/ image for %s paper" % (args.shots, level.capitalize()))
        need(any("web" in i.lower() for i in shots), "README embeds at least one web-build screenshot")
    shots_dir = os.path.join(qalib.ROOT, args.shots)
    files = sorted(os.listdir(shots_dir)) if os.path.isdir(shots_dir) else []
    for level in ("light", "normal", "heavy"):
        need(any(level in f.lower() and "web" in f.lower() for f in files), "%s has a web capture at %s paper" % (args.shots, level.capitalize()))
        need(any(level in f.lower() and "desktop" in f.lower() for f in files), "%s has a desktop capture at %s paper" % (args.shots, level.capitalize()))
    need(os.path.isfile(os.path.join(qalib.ROOT, args.shaders)), "%s exists" % args.shaders)
    lines = ["# Deliverable documents", ""] + rows
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines))
    if problems:
        status = "NOT_YET" if not readme and not files else "FAIL"
        qalib.result(status, evidence, "%d of %d item(s) missing; first: %s" % (len(problems), len(rows), problems[0]))
    qalib.result("PASS", evidence, "README, SHADERS.md and screenshots present (%d items)" % len(rows))


if __name__ == "__main__":
    main()
