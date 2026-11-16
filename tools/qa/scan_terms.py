"""Banned-term and absolute-path scan of every project file.

    python -I tools/qa/scan_terms.py [--terms a,b] [--words c,d] [--no-build] [--no-history] [--evidence NAME]

The terms are never stored in the repository. Pass them at run time:
  --terms / QA_BANNED_TERMS   matched anywhere, in any letter case, accents folded, spaces in a
                              term also match "_", "-", "." or nothing ("two words" = "two_words")
  --words / QA_BANNED_WORDS   matched as whole words only (for short names that occur inside
                              ordinary words)
Lists are separated by commas or newlines. Findings name the file, line and the term's position
in the list (term #3), never the term itself, so the evidence can be committed.

Scanned: every tracked file and every untracked, non-ignored file (names and contents, text
and binary, UTF-8 and UTF-16), the commit messages reachable from HEAD, branch names, and
build/web/ when it exists. Absolute paths are looked for in text files (Windows drive, MSYS
/x/... and Unix home forms) and, in every file, any spelling of this checkout's and the main
checkout's absolute path and of the user's home folder.
"""
import argparse
import os
import re
import subprocess
import sys
import unicodedata

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

SYSTEM_DIRS = ("program files", "windows", "programdata")


def fold(text):
    text = unicodedata.normalize("NFKD", text)
    return "".join(c for c in text if not unicodedata.combining(c)).casefold()


def split_list(value):
    return [t.strip() for t in re.split(r"[,\n]", value or "") if t.strip()]


def term_regex(term, whole_word):
    parts = [re.escape(fold(p)) for p in term.split()]
    body = r"[\s_\-.]*".join(parts)
    if whole_word:
        body = r"(?<![0-9a-z])" + body + r"(?![0-9a-z])"
    return re.compile(body)


def path_spellings(path):
    mixed = path.replace("\\", "/").rstrip("/")
    out = {mixed, mixed.replace("/", "\\"), mixed.replace("/", "\\\\")}
    if len(mixed) > 2 and mixed[1] == ":":
        out.add("/" + mixed[0].lower() + mixed[2:])
    return sorted({fold(s) for s in out if len(s) > 3}, key=len, reverse=True)


def known_roots():
    roots = {qalib.ROOT}
    try:
        common = subprocess.run(["git", "-C", qalib.ROOT, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                check=True, stdout=subprocess.PIPE).stdout.decode().strip()
        roots.add(os.path.dirname(common))
    except Exception:
        pass
    for var in ("USERPROFILE", "HOME"):
        if os.environ.get(var) and len(os.environ[var]) > 3:
            roots.add(os.environ[var])
    spellings = []
    for r in roots:
        spellings += path_spellings(os.path.abspath(r))
    return sorted(set(spellings), key=len, reverse=True)


DRIVE_RE = re.compile(r"(?<![A-Za-z0-9_])[A-Za-z]:(?:\\\\|\\|/)([^\s\"'\x60<>|*?]*)")
MSYS_RE = re.compile(r"(?<![\w.:/\-])/[A-Za-z]/[^\s/\"'\x60]{2,}/[^\s/\"'\x60]{2,}")
# /root/ is left out on purpose: Godot node paths start with it.
HOME_RE = re.compile(r"(?<![\w.])/(?:home|Users)/[^\s/\"'\x60]+")


def generic_abs_paths(line):
    kinds = []
    for m in DRIVE_RE.finditer(line):
        comps = [c for c in re.split(r"[\\/]+", m.group(1)) if c]
        if len(comps) >= 2 and len(comps[0]) >= 2 and len(comps[1]) >= 2:
            if not comps[0].casefold().startswith(SYSTEM_DIRS):
                kinds.append("drive path")
    if MSYS_RE.search(line):
        kinds.append("MSYS path")
    if HOME_RE.search(line):
        kinds.append("home path")
    return kinds


ASCII_RUN_RE = re.compile(rb"[\x20-\x7e\t]{8,}")
UTF16_RUN_RE = re.compile(rb"(?:[\x20-\x7e\t]\x00){8,}")


NAMEISH_RE = re.compile(r"[A-Za-z0-9 _.,:;'\"()/\-]")


QUOTED_RE = re.compile(r'"([^"]{1,120})"')


def textlike(run):
    return len(NAMEISH_RE.findall(run)) >= 0.9 * len(run)


def name_strings(runs):
    """Printable runs inside compressed data (PNG, OGG) are mostly random, and a short whole word such
    as a three-letter name turns up in them by chance. Only text that reads like a name counts: whole
    runs that are name-like, and quoted strings inside any run (glTF/JSON node and material names)."""
    out = []
    for r in runs:
        if textlike(r):
            out.append(r)
        out += [q for q in QUOTED_RE.findall(r) if textlike(q)]
    return "\n".join(out).lower()


def decode_variants(data):
    """(kind, text, whole_words_too). Binary data is searched without accent folding, which would
    turn random bytes into letters: substring terms over the raw bytes (ASCII case-insensitive),
    and every term over printable runs of 8+ characters (ASCII and UTF-16), where real embedded
    names live (glTF node names, PNG text chunks, metadata)."""
    if not qalib.is_binary(data):
        return [("text", data.decode("utf-8", "replace"), True)]
    out = [("bytes", data.lower().decode("latin-1"), False)]
    out.append(("strings", name_strings(m.group(0).decode("ascii") for m in ASCII_RUN_RE.finditer(data)), True))
    for off in (0, 1):
        runs = [m.group(0).decode("utf-16-le") for m in UTF16_RUN_RE.finditer(data[off:])]
        out.append(("utf-16", name_strings(runs), True))
    return out


def scan_text(label, text, regexes, roots, findings, abs_check, whole_words=True, do_fold=True):
    folded = fold(text) if do_fold else text
    for idx, rx in regexes:
        if not whole_words and rx.pattern.startswith("(?<!"):
            continue
        for m in rx.finditer(folded):
            line = folded.count("\n", 0, m.start()) + 1
            findings.append("%s:%d: banned term #%d" % (label, line, idx))
            break
    for spelling in roots:
        pos = folded.find(spelling)
        if pos >= 0:
            findings.append("%s:%d: absolute path of this machine (project or home folder)" % (label, folded.count("\n", 0, pos) + 1))
            break
    if abs_check:
        for n, line in enumerate(text.splitlines(), 1):
            for kind in generic_abs_paths(line):
                findings.append("%s:%d: absolute path (%s)" % (label, n, kind))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--terms", default=os.environ.get("QA_BANNED_TERMS", ""))
    ap.add_argument("--words", default=os.environ.get("QA_BANNED_WORDS", ""))
    ap.add_argument("--no-build", action="store_true")
    ap.add_argument("--no-history", action="store_true")
    ap.add_argument("--evidence", default="terms.txt")
    args = ap.parse_args()
    terms = split_list(args.terms)
    words = split_list(args.words)
    regexes = [(i + 1, term_regex(t, False)) for i, t in enumerate(terms)]
    regexes += [(len(terms) + i + 1, term_regex(t, True)) for i, t in enumerate(words)]
    roots = known_roots()
    findings = []
    files = qalib.project_files()
    for f in files:
        scan_text("(file name) " + f, f, regexes, [], findings, False)
        with open(os.path.join(qalib.ROOT, f), "rb") as fh:
            data = fh.read()
        for kind, text, words_ok in decode_variants(data):
            scan_text(f if kind == "text" else "%s [%s]" % (f, kind), text, regexes, roots, findings, kind == "text",
                      words_ok, kind == "text")
    build_files = []
    build_dir = os.path.join(qalib.ROOT, "build", "web")
    if not args.no_build and os.path.isdir(build_dir):
        for name in sorted(os.listdir(build_dir)):
            p = os.path.join(build_dir, name)
            if os.path.isfile(p):
                build_files.append(name)
                scan_text("(file name) build/web/" + name, name, regexes, [], findings, False)
                with open(p, "rb") as fh:
                    data = fh.read()
                for kind, text, words_ok in decode_variants(data):
                    scan_text("build/web/%s [%s]" % (name, kind), text, regexes, roots, findings, False,
                              words_ok, kind == "text")
    commits = 0
    if not args.no_history:
        log = subprocess.run(["git", "-C", qalib.ROOT, "log", "--format=%H%x01%B%x02", "HEAD"],
                             check=True, stdout=subprocess.PIPE).stdout.decode("utf-8", "replace")
        for entry in log.split("\x02"):
            if "\x01" not in entry:
                continue
            sha, body = entry.strip().split("\x01", 1)
            commits += 1
            scan_text("commit %s message" % sha[:10], body, regexes, roots, findings, True)
        branches = subprocess.run(["git", "-C", qalib.ROOT, "branch", "--format=%(refname:short)"],
                                  check=True, stdout=subprocess.PIPE).stdout.decode("utf-8", "replace")
        scan_text("(branch names)", branches, regexes, [], findings, False)
    findings = sorted(set(findings))
    lines = [
        "# Banned-term and absolute-path scan",
        "terms supplied: %d substring, %d whole-word (the lead's list, passed at run time)" % (len(terms), len(words)),
        "files scanned: %d project files, %d build/web files, %d commit messages" % (len(files), len(build_files), commits),
        "findings: %d" % len(findings),
        "",
    ] + findings
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines[:4] + findings[:60]))
    if findings:
        qalib.result("FAIL", evidence, "%d finding(s), first: %s" % (len(findings), findings[0]))
    if not regexes:
        qalib.result("NOT_RUN", evidence, "no banned terms supplied (set QA_BANNED_TERMS or pass --terms); no absolute paths found")
    qalib.result("PASS", evidence, "%d files, %d build files, %d commits clean" % (len(files), len(build_files), commits))


if __name__ == "__main__":
    main()
