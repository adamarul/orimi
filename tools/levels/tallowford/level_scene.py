"""Write scenes/levels/tallowford/tallowford.tscn, the playable level, from
scripts/levels/tallowford/layout.json (terrain, props and the markers baked into the terrain) and
the assembly plan in scenes/levels/tallowford/level.json (people and kit nodes). Run after
level_data.py; gen.sh runs both.

    python tools/levels/tallowford/level_scene.py [out.tscn]
"""
import json
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
LAYOUT = json.loads((ROOT / "scripts/levels/tallowford/layout.json").read_text(encoding="utf-8"))
DATA = json.loads((ROOT / "scenes/levels/tallowford/level.json").read_text(encoding="utf-8"))
PLAN = DATA["tallowford"]
OWN = "res://scenes/levels/tallowford/models/%s.tscn"
SHARED = {"shrine", "thorn_gate", "reeds", "rocks", "stepping_stone"}
LOOSE = {"reeds"}                      # dressing that Orimi walks through: no collision
SKIP = {"thorn_gate", "ford_lamp"}     # the kit's VatThorns and Lamp_Ford stand in for these
QUEST_LAMPS = ["Trim", "Marrow", "Brindle", "Children", "Ferry"]


class Scene:
    def __init__(self):
        self.ext, self.nodes = {}, []

    def res(self, path, kind):
        if path not in self.ext:
            self.ext[path] = (kind, "%d" % (len(self.ext) + 1))
        return 'ExtResource("%s")' % self.ext[path][1]

    def value(self, v):
        if isinstance(v, bool):
            return "true" if v else "false"
        if isinstance(v, (int, float)):
            return repr(round(v, 4)) if isinstance(v, float) else str(v)
        if isinstance(v, dict):
            return json.dumps(v)
        if isinstance(v, str) and v.startswith(("Vector3(", "NodePath(")):
            return v
        if isinstance(v, list):
            return "PackedStringArray(%s)" % ", ".join(json.dumps(x) for x in v)
        if isinstance(v, str) and v.startswith("&"):
            return "&" + json.dumps(v[1:])
        if isinstance(v, str) and v.startswith("res://") and v.endswith(".tscn"):
            return self.res(v, "PackedScene")
        return json.dumps(v)

    def node(self, name, parent, type_=None, instance=None, script=None, pos=None, yaw=0.0, groups=(), props=None):
        head = '[node name="%s"' % name
        if type_:
            head += ' type="%s"' % type_
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += " instance=%s" % self.res(instance, "PackedScene")
        if groups:
            head += " groups=[%s]" % ", ".join(json.dumps(g) for g in groups)
        lines = [head + "]"]
        if pos is not None:
            lines.append("position = Vector3(%s, %s, %s)" % tuple(repr(round(c, 3)) for c in pos))
        if yaw:
            lines.append("rotation = Vector3(0, %s, 0)" % repr(round(math.radians(yaw), 5)))
        if script:
            lines.append("script = %s" % self.res(script, "Script"))
        for k, v in (props or {}).items():
            lines.append("%s = %s" % (k, self.value(v)))
        self.nodes.append("\n".join(lines))

    def text(self):
        head = ['[gd_scene load_steps=%d format=3]' % (len(self.ext) + 1), ""]
        for path, (kind, i) in self.ext.items():
            head.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, i))
        return "\n".join(head) + "\n\n" + "\n\n".join(self.nodes) + "\n"


def camel(model):
    return "".join(p.capitalize() for p in model.split("_"))


def marker(name):
    return LAYOUT["markers"][name]


def lamp_props():
    """The lamp_post prop at each quest house's M_Lamp_ marker, and the ford-lamp prop."""
    out = {}
    for k in QUEST_LAMPS:
        m = marker("M_Lamp_" + k)
        out[k] = min((p for p in LAYOUT["props"] if p["model"] == "lamp_post"),
                     key=lambda p: (p["pos"][0] - m[0]) ** 2 + (p["pos"][2] - m[2]) ** 2)
    out["Ford"] = next(p for p in LAYOUT["props"] if p["model"] == "ford_lamp")
    return out


def place(spec, lamps):
    at, yaw = spec["at"], 0.0
    if at.startswith("lamp:") or at == "ford":
        p = lamps[at[5:] if at != "ford" else "Ford"]
        return list(p["pos"]), p["yaw"]
    pos = list(marker(at))
    if "toward" in spec:
        t = marker(spec["toward"])
        d = [t[0] - pos[0], t[2] - pos[2]]
        n = math.hypot(*d)
        pos = [pos[0] + d[0] / n * spec["ahead"], pos[1], pos[2] + d[1] / n * spec["ahead"]]
        yaw = math.degrees(math.atan2(-d[0], -d[1]))
    if "shift" in spec:
        pos = [pos[i] + spec["shift"][i] for i in range(3)]
    if "drop" in spec:
        pos[1] -= spec["drop"]
    return pos, yaw


def build():
    s = Scene()
    s.node("Tallowford", None, "Node3D", script="res://scripts/levels/tallowford/tallowford.gd", props={
        "level_id": "&tallowford", "display_name": "Tallowford", "chapter": "The Lamps of Tallowford",
        "intro_text": PLAN["chapter_card"], "start_gloom": 0.0, "title_marker": "M_Square"})
    s.node("Terrain", ".", instance=OWN % "tallowford_terrain", groups=["level_ground"])
    s.node("River", ".", instance=OWN % "tallowford_river")
    s.node("Props", ".", "Node3D")
    s.node("Dressing", ".", "Node3D")
    lamps = lamp_props()
    taken = {id(p) for p in lamps.values()}
    count = {}
    for p in LAYOUT["props"]:
        if p["model"] in SKIP or id(p) in taken:
            continue
        count[p["model"]] = count.get(p["model"], 0) + 1
        name = {"persimmon": "PersimmonTree"}.get(p["model"]) or camel(p["model"]) + ("" if p["model"].startswith("house_") else str(count[p["model"]]))
        loose = p["model"] in LOOSE
        path = ("res://scenes/models/%s.tscn" if p["model"] in SHARED else OWN) % p["model"]
        s.node(name, "Dressing" if loose else "Props", instance=path, pos=p["pos"], yaw=p["yaw"],
               groups=() if loose else ["level_ground"])
        if p["scale"] != 1.0:
            s.nodes[-1] += "\nscale = Vector3(%s, %s, %s)" % ((repr(p["scale"]),) * 3)
    s.node("People", ".", "Node3D")
    for name, spec in PLAN["people"].items():
        spot = LAYOUT["people"][spec["at"]]
        model = spec["model"] if spec["model"].endswith(".tscn") else "scenes/models/%s.tscn" % spec["model"]
        props = {"display_name": spec["display_name"], "talk_id": "&" + spec["talk_id"], "model_scene": "res://" + model}
        if spec["faded"]:
            props["faded"] = True
        if spec["wake_flag"]:
            props["wake_flag"] = "&" + spec["wake_flag"]
        for key in ("talk_by_flag", "bark_on_flag"):
            if spec[key]:
                props[key] = spec[key]
        s.node(name, "People", "Node3D", script="res://scripts/game/kit/person.gd", pos=spot["pos"], yaw=spot["yaw"], props=props)
    s.node("Kit", ".", "Node3D")
    for spec in PLAN["nodes"]:
        pos, yaw = place(spec, lamps)
        s.node(spec["name"], "Kit", spec["type"], script=spec["script"], pos=pos, yaw=yaw, props=spec.get("set", {}))
        for child in spec.get("children", []):
            s.node(child["name"], "Kit/" + spec["name"], child["type"], script=child.get("script"), pos=child["offset"],
                   props=child.get("set", {}))
    return s


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "scenes/levels/tallowford/tallowford.tscn"
    s = build()
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(s.text())
    print("LEVEL_SCENE", out.relative_to(ROOT).as_posix(), len(s.nodes), "nodes", len(s.ext), "resources")
