"""Contract conformance: every public member of each contract autoload and global class still
exists with a compatible signature, and the contract deliverable scenes have the shape
CONTRACTS.md gives them.

    python -I tools/qa/contract.py --dump <api.json> [--evidence NAME]
    python -I tools/qa/contract.py --dump <api.json> --write-baseline   (QA only, from the stubs)

The dump comes from tests/contract/api_dump.tscn (run by "tools/qa/qa.sh contract").
The baseline, tests/contract/api_baseline.json, was taken from the lead's contract stubs, which
CONTRACTS.md calls "the full public API". Compatible means every call that worked against the
stub still works:
  methods: same static-ness; no more required arguments than the stub; at least as many
           arguments; each stub argument's type kept (or widened to untyped, or int -> float);
           a non-void return type kept (untyped is accepted).
  properties: present; same type, or untyped.
  signals: present with the same argument types.
  constants: present (a changed value is reported, not failed).
  autoload node class: the same native class (CanvasLayer stays CanvasLayer).
Members added beyond the stub are listed so owners can report them.
Deliverable scenes: missing ones are NOT YET; present ones with problems FAIL.
"""
import argparse
import json
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qalib  # noqa: E402

BASELINE = os.path.join(qalib.ROOT, "tests", "contract", "api_baseline.json")
TYPE_NAMES = {0: "Variant", 1: "bool", 2: "int", 3: "float", 4: "String", 9: "Vector3", 21: "StringName", 18: "Transform3D",
              20: "Color", 24: "Object", 27: "Dictionary", 28: "Array", 35: "PackedVector2Array", 36: "PackedVector3Array",
              5: "Vector2", 12: "Vector4", 22: "NodePath", 34: "PackedStringArray"}


def tname(t):
    if t.get("class"):
        return t["class"]
    n = TYPE_NAMES.get(t.get("type", 0), "type%d" % t.get("type", 0))
    return "%s[%s]" % (n, t["of"]) if t.get("of") else n


def same_type(old, new):
    return old.get("type") == new.get("type") and old.get("class", "") == new.get("class", "") and old.get("of", "") == new.get("of", "")


def arg_ok(old, new):
    return same_type(old, new) or new.get("type", 0) == 0 or (old.get("type") == 2 and new.get("type") == 3 and not new.get("class"))


def sig(m):
    args = ", ".join(tname(a) for a in m["args"])
    return "%s(%s) -> %s%s" % ("static " if m.get("static") else "", args, tname(m["return"]), " [%d default]" % m["defaults"] if m["defaults"] else "")


def compare(owner, old, new, problems, notes, additions):
    if new.get("missing"):
        problems.append("%s: missing entirely (autoload not registered or script does not load)" % owner)
        return
    if "node_class" in old and old["node_class"] != new.get("node_class"):
        problems.append("%s: node class %s, contract stub was %s" % (owner, new.get("node_class"), old["node_class"]))
    for name, om in old["methods"].items():
        nm = new["methods"].get(name)
        if nm is None:
            problems.append("%s.%s%s: method removed" % (owner, name, sig(om)[sig(om).index("("):]))
            continue
        why = []
        if om["static"] != nm["static"]:
            why.append("static changed")
        o_total, n_total = len(om["args"]), len(nm["args"])
        o_req, n_req = o_total - om["defaults"], n_total - nm["defaults"]
        if not nm.get("vararg"):
            if n_total < o_total:
                why.append("takes %d argument(s), stub took %d" % (n_total, o_total))
            if n_req > o_req:
                why.append("requires %d argument(s), stub required %d" % (n_req, o_req))
        for i, oa in enumerate(om["args"]):
            if i < n_total and not arg_ok(oa, nm["args"][i]):
                why.append("argument %d is %s, stub %s" % (i + 1, tname(nm["args"][i]), tname(oa)))
        if om["return"].get("type", 0) != 0 and not (same_type(om["return"], nm["return"]) or nm["return"].get("type", 0) == 0 and not nm["return"].get("class")):
            why.append("returns %s, stub %s" % (tname(nm["return"]), tname(om["return"])))
        if why:
            problems.append("%s.%s: %s (now %s, stub %s)" % (owner, name, "; ".join(why), sig(nm), sig(om)))
    for name, op in old["properties"].items():
        np = new["properties"].get(name)
        if np is None:
            problems.append("%s.%s: property removed" % (owner, name))
        elif op.get("type", 0) != 0 and not same_type(op, np) and np.get("type", 0) != 0:
            problems.append("%s.%s: property type %s, stub %s" % (owner, name, tname(np), tname(op)))
        elif op.get("export") and not np.get("export"):
            problems.append("%s.%s: no longer an @export" % (owner, name))
    for name, oargs in old["signals"].items():
        nargs = new["signals"].get(name)
        if nargs is None:
            problems.append("%s.%s: signal removed" % (owner, name))
        elif len(nargs) != len(oargs) or any(not same_type(a, b) for a, b in zip(oargs, nargs)):
            problems.append("%s.%s: signal arguments (%s), stub (%s)" % (owner, name, ", ".join(map(tname, nargs)), ", ".join(map(tname, oargs))))
    for name, value in old["constants"].items():
        if name not in new["constants"]:
            problems.append("%s.%s: constant removed" % (owner, name))
        elif new["constants"][name] != value:
            notes.append("%s.%s: value changed from %s to %s" % (owner, name, value, new["constants"][name]))
    for kind in ("methods", "properties", "signals", "constants"):
        for name in sorted(set(new[kind]) - set(old[kind])):
            additions.append("%s.%s (%s)" % (owner, name, kind[:-1] if kind != "properties" else "property"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--evidence", default="contract.txt")
    ap.add_argument("--write-baseline", action="store_true")
    ap.add_argument("--baseline", default=BASELINE, help="another baseline (QA self-test)")
    args = ap.parse_args()
    with open(args.dump, encoding="utf-8") as fh:
        dump = json.load(fh)
    if args.write_baseline:
        base = {"autoloads": dump["autoloads"], "classes": dump["classes"]}
        with open(BASELINE, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(base, fh, indent=1, sort_keys=True)
            fh.write("\n")
        print("wrote", qalib.rel(BASELINE))
        return
    with open(args.baseline, encoding="utf-8") as fh:
        base = json.load(fh)
    problems, notes, additions = [], [], []
    for group in ("autoloads", "classes"):
        for owner, old in base[group].items():
            compare(owner, old, dump[group].get(owner, {"missing": True}), problems, notes, additions)
    deliv_rows, deliv_fail, deliv_missing = [], [], []
    for d in dump.get("deliverables", []):
        path = d["path"].replace("res://", "")
        if not d["exists"]:
            deliv_rows.append("NOT YET  %s" % path)
            deliv_missing.append(path)
        elif d["problems"]:
            deliv_rows.append("FAIL     %s: %s" % (path, "; ".join(d["problems"])))
            deliv_fail.append("%s: %s" % (path, d["problems"][0]))
        else:
            deliv_rows.append("ok       %s%s" % (path, " (animations: %s)" % ", ".join(d["animations"]) if d.get("animations") else ""))
    lines = ["# Contract conformance", "baseline: tests/contract/api_baseline.json (the lead's contract stubs)", "",
             "## API problems: %d" % len(problems)] + problems
    lines += ["", "## Constant values changed (not a failure): %d" % len(notes)] + notes
    lines += ["", "## Members added beyond the contract stubs: %d" % len(additions)] + additions
    lines += ["", "## Contract deliverable scenes: %d present ok, %d failing, %d not yet" % (
        len(deliv_rows) - len(deliv_fail) - len(deliv_missing), len(deliv_fail), len(deliv_missing))] + deliv_rows
    evidence = qalib.write_evidence(args.evidence, lines)
    print("\n".join(lines))
    if problems or deliv_fail:
        first = (problems + deliv_fail)[0]
        qalib.result("FAIL", evidence, "%d API problem(s), %d deliverable scene problem(s); first: %s" % (len(problems), len(deliv_fail), first))
    if deliv_missing:
        qalib.result("NOT_YET", evidence, "API conforms; %d contract scene(s) not delivered yet (e.g. %s)" % (len(deliv_missing), deliv_missing[0]))
    qalib.result("PASS", evidence, "API conforms to the stubs; every contract scene present and well-formed")


if __name__ == "__main__":
    main()
