"""Rewrite text files in place, replacing absolute checkout paths with placeholders.

    python sanitize_paths.py <project-root> <tools-root> <file>...

Every spelling a log may contain is covered, case-insensitively: C:/x/y, C:\\x\\y, JSON-escaped
C:\\\\x\\\\y and the MSYS form /c/x/y. The project root becomes <project>; the folder holding .tools/
becomes <tools-root> (only differs inside a worktree).
"""
import re
import sys


def variants(path):
    mixed = path.replace("\\", "/").rstrip("/")
    back = mixed.replace("/", "\\")
    out = [back.replace("\\", "\\\\"), back, mixed]
    if len(mixed) > 2 and mixed[1] == ":":
        out.append("/" + mixed[0].lower() + mixed[2:])
    return out


def main():
    project, tools_root, files = sys.argv[1], sys.argv[2], sys.argv[3:]
    rules = [(v, "<project>") for v in variants(project)] + [(v, "<tools-root>") for v in variants(tools_root)]
    for name in files:
        with open(name, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for needle, tag in rules:
            text = re.sub(re.escape(needle), tag, text, flags=re.IGNORECASE)
        with open(name, "w", encoding="utf-8", newline="") as f:
            f.write(text)


if __name__ == "__main__":
    main()
