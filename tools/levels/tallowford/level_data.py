"""Write scenes/levels/tallowford/level.json, the kit data file (docs/LEVEL_KIT.md, section 3), from
scripts/levels/tallowford/script.json and the layout, so Phase B assembly is placing nodes with the
names below. Kit keys: spawn_facing, complete_on_objectives, objectives, lines, raft, warps,
autoplay. The "tallowford" key is level-local (the kit ignores it): the kit nodes to place, the
proximity lines and the lines that play when a flag is set, for the level script.

    python tools/levels/tallowford/level_data.py [out.json]
"""
import json
import math
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import layout as L  # noqa: E402

SCRIPT = json.loads((ROOT / "scripts/levels/tallowford/script.json").read_text(encoding="utf-8"))
SCENES = {s["id"]: s for s in SCRIPT["scenes"]}
SPEAKERS = SCRIPT["speakers"]

# Person nodes: node name -> (talk_id, folk wrapper or shared model, marker, starts faded, wake flag, script ids)
# script ids: faded lines, first lines once awake, again, after the finale (the level script swaps
# talk_id through Person.talk_by_flag; the kit picks faded / first / again).
PEOPLE = {
    "Pell": ("pell", "folk/pell", "M_Person_Pell", False, "", (None, "arrival", "pell_idle_1", "pell_ready")),
    "Trim": ("trim", "scenes/levels/tallowford/folk/old_trim.tscn", "M_Person_Trim", True, "lit_trim",
             ("trim_grey", "trim_wakes", "trim_after", "trim_end")),
    "Marrow": ("marrow", "scenes/levels/tallowford/folk/marrow.tscn", "M_Person_Marrow", True, "lit_marrow",
               ("marrow_grey", "marrow_wakes", "marrow_after", "marrow_end")),
    "Brindle": ("brindle", "scenes/levels/tallowford/folk/brindle.tscn", "M_Person_Brindle", True, "lit_brindle",
                ("brindle_grey", "brindle_wakes", "brindle_after", "brindle_end")),
    "Flax": ("children", "scenes/levels/tallowford/folk/flax.tscn", "M_Person_Flax", True, "lit_children",
             ("children_grey", "children_wake", "children_after", "children_end")),
    "Pibbet": ("children", "scenes/levels/tallowford/folk/pibbet.tscn", "M_Person_Pibbet", True, "lit_children", None),
    "Wherry": ("wherry", "scenes/levels/tallowford/folk/wherry.tscn", "M_Person_Wherry", True, "fight_jetty",
               ("wherry_grey", "wherry_wakes", "wherry_after", "wherry_end")),
    "Baker": ("baker", "scenes/levels/tallowford/folk/baker.tscn", "M_Person_Neighbour_1", True, "lit_ford",
              (None, "baker_end", "baker_end", None)),
    "NetMender": ("netmender", "scenes/levels/tallowford/folk/netmender.tscn", "M_Person_Neighbour_2", True, "lit_ford",
                  (None, "netmender_end", "netmender_end", None)),
    "Fisher": ("fisher", "scenes/levels/tallowford/folk/fisher.tscn", "M_Person_Neighbour_3", True, "lit_ford",
               (None, "fisher_end", "fisher_end", None)),
}

# Kit nodes to place (docs/LEVEL_KIT.md): name, script, scene type, where (a marker, or "lamp:<Key>" for
# a house's lamp post, "ford" for the ford-lamp's pier), exports, children. level_scene.py writes them.
KIT = "res://scripts/game/kit/"
OBSTACLE = "res://scripts/game/glyph_obstacle.gd"
SPAWN_R = 3.5
JETTY_END_X = 25.0 + L.JETTY_LEN
FORD_CAM_SHIFT = [-4.0, 0.0, 1.0]
_ford_cam = [L.FORD_PIER[0] + FORD_CAM_SHIFT[0], L.PIER_TOP_Y, L.FORD_PIER[1] + FORD_CAM_SHIFT[2]]
NODES = [
    {"name": "VatThorns", "script": OBSTACLE, "type": "StaticBody3D", "at": "M_DyeVats", "toward": "M_Square", "ahead": 2.6,
     "set": {"glyph": "&slash", "cleared_flag": "&thorns_cut", "width": 4.5, "height": 2.4,
             "hint_id": "&tf_thorns", "hint_text": "Ink thorns bind the vats. Cut straight across them: %s."}},
    {"name": "WellSoot", "script": OBSTACLE, "type": "StaticBody3D", "at": "M_Well",
     "set": {"glyph": "&gust", "cleared_flag": "&well_cleared", "width": 2.2, "height": 1.8,
             "hint_id": "&tf_soot", "hint_text": "Soot chokes the well. Blow it away: %s."}},
    {"name": "JettyFight", "script": KIT + "sealed_fight.gd", "type": "Node3D", "at": "M_Fight",
     "set": {"fight_id": "&jetty", "radius": L.FIGHT_R, "requires_flags": ["lit_ferry"]},
     "children": [{"name": "Spawn%d" % (i + 1), "script": KIT + "enemy_spawn.gd", "type": "Marker3D",
                   "offset": [round(SPAWN_R * math.sin(a), 2), 0, round(SPAWN_R * math.cos(a), 2)],
                   "set": {"kind": "&" + kind, "wave": wave}}
                  for i, (a, kind, wave) in enumerate([(math.radians(d), k, w) for d, k, w in (
                      (60, "splotchet", 0), (100, "splotchet", 0), (140, "splotchet", 0), (20, "splotchet", 0),
                      (-40, "splotchet", 1), (180, "splotchet", 1), (90, "reedwraith", 1))])]},
    {"name": "Persimmon", "script": KIT + "glyph_target.gd", "type": "StaticBody3D", "at": "M_Persimmon",
     "set": {"glyphs": ["bloom"], "requires_flags": ["lit_brindle"], "flag": "&persimmon_bloomed", "size": "Vector3(2.6, 4.0, 2.6)",
             "hint_id": "&tf_tree", "hint_text": "The persimmon is bare. Draw a circle round it: %s."},
     "note": "our persimmon model (PersimmonTree) plays bloom on persimmon_bloomed"},
    {"name": "FordCam", "script": KIT + "camera_zone.gd", "type": "Node3D", "at": "M_FordLamp", "shift": FORD_CAM_SHIFT,
     "set": {"size": "Vector3(10, 8, 10)", "mode": "follow", "lock_pitch": True, "pitch_deg": 24.0, "distance": 4.2},
     "note": "near the ford-lamp the camera looks up at its lantern, 6.6 m above the pier"},
    {"name": "FordHood", "script": OBSTACLE, "type": "StaticBody3D", "at": "M_Kindle_Ford", "drop": 1.0,
     "set": {"glyph": "&gust", "cleared_flag": "&hood_cleared", "width": 1.6, "height": 2.0,
             "model_scene": "res://scenes/levels/tallowford/kit/hood.tscn",
             "hint_id": "&tf_hood", "hint_text": "A hood of soot smothers the ford-lamp. Blow it off: %s."},
     "note": "the soot hood is the ford_lamp model's hooded state; the level script plays unhood"},
    {"name": "Verse_1", "script": KIT + "verse_stone.gd", "type": "StaticBody3D", "at": "M_Verse_1",
     "set": {"talk_id": "&verse_1", "read_flag": "&verse_1_read", "teaches": "&kindle",
             "teach_text": "The stone remembers a short, firm dab that lights: %s."}},
    {"name": "Verse_2", "script": KIT + "verse_stone.gd", "type": "StaticBody3D", "at": "M_Verse_2",
     "set": {"talk_id": "&verse_2", "read_flag": "&verse_2_read"}, "note": "optional"},
] + [{"name": "Lamp_" + k, "script": KIT + "kindle_target.gd", "type": "StaticBody3D",
      "at": "ford" if k == "Ford" else "lamp:" + k,
      "set": {"kind": "lamp", "lit_flag": "&lit_" + k.lower(), "requires_flags": r,
              "model_scene": "res://scenes/levels/tallowford/kit/%s.tscn" % ("ford_lamp_kindle" if k == "Ford" else "lamp_kindle")}}
     for k, r in (("Trim", ["verse_1_read"]), ("Marrow", ["thorns_cut"]), ("Brindle", ["well_cleared"]),
                  ("Children", ["persimmon_bloomed"]), ("Ferry", ["lit_children"]), ("Ford", ["hood_cleared"]))] + [
    {"name": "RaftExit", "script": KIT + "level_exit.gd", "type": "Node3D", "at": "M_RaftCross",
     "set": {"requires_flags": ["said_finale"]},
     "note": "the jetty end; the kit's RaftTrip brings Pell's raft in to raft.depart, just past the pier end on its upriver side"},
    {"name": "FinaleCam", "script": KIT + "camera_zone.gd", "type": "Node3D", "at": "M_FordLamp", "shift": FORD_CAM_SHIFT,
     "set": {"size": "Vector3(18, 12, 18)", "mode": "fixed", "priority": 1, "blend_time": 1.5, "view": 'NodePath("View")'},
     "children": [{"name": "View", "type": "Marker3D", "offset": [round(a - b, 3) for a, b in zip(L.FINALE_VIEW, _ford_cam)]}],
     "note": "the level script keeps it out of the camera_zone group until lit_ford: the finale is seen from over the river"},
    {"name": "Gather", "script": None, "type": "Node3D", "at": "M_JettySquare",
     "children": [{"name": "M_Gather_" + n, "type": "Marker3D",
                   "offset": [round(x - L.JETTY_SQ_C[0], 3), 0.0, round(z - L.JETTY_SQ_C[1], 3)]}
                  for n, (x, z) in L.gather().items()],
     "note": "where each villager stands in the finale (the level script moves them)"},
]

# Prompts shown when Orimi comes near (until the flag is set), and lines the level script plays
# when a flag is set (then it sets said_<lines id>). Verse-stones speak their own lines.
NEAR = [("verse_1_near", "M_Verse_1", 4.0, "verse_1_read"), ("vats_near", "M_DyeVats", 6.0, "thorns_cut"),
        ("well_near", "M_Well", 5.0, "well_cleared"), ("tree_near", "M_Persimmon", 7.0, "persimmon_bloomed"),
        ("verse_2_near", "M_Verse_2", 4.0, "verse_2_read"), ("hood_near", "M_FordLamp", 8.0, "hood_cleared")]
ON_FLAG = {"lit_ford": "finale"}
# Barks (lines that do not stop play) said by a person when a flag is set, and what they say after
# a flag: Person's bark_on_flag and talk_by_flag (the last listed flag that is set wins).
BARKS = {"Marrow": {"thorns_cut": "vats_cut"}, "Brindle": {"well_cleared": "well_cleared"},
         "Flax": {"persimmon_bloomed": "tree_bloomed"}, "Wherry": {"lit_ferry": "ferry_lamp_lit"},
         "Pell": {"hood_cleared": "hood_off"}}
TALK_BY_FLAG = {"Pell": {"lit_trim": "pell_idle_2", "lit_ford": "pell_ready"}}

OBJECTIVES = [
    ("Wake the verse-stone by Old Trim's house", ["verse_1_read"]),
    ("Light Old Trim's lamp", ["lit_trim"]),
    ("Free the dye vats and light Marrow's lamp", ["thorns_cut", "lit_marrow"]),
    ("Clear the well and light Brindle's lamp", ["well_cleared", "lit_brindle"]),
    ("Wake the persimmon and light the children's lamp", ["persimmon_bloomed", "lit_children"]),
    ("Light the ferry-house lamp and hold the jetty", ["lit_ferry", "fight_jetty"]),
    ("Unhood the ford-lamp and light it", ["hood_cleared", "lit_ford"]),
]


def kit_line(speaker, text):
    text = re.sub(r"\[([^\]]+)\]", r"*\1*", text)
    return {"who": SPEAKERS[speaker]["name"], "text": text}


def lines():
    out = {sid: [kit_line(sp, t) for sp, t in s["lines"]] for sid, s in SCENES.items()}
    for name, (talk, _, _, _, _, ids) in PEOPLE.items():
        if ids is None:
            continue
        faded, first, again, end = ids
        for key, sid in ((talk + "_faded", faded), (talk, first), (talk + "_again", again), (talk + "_end", end)):
            if sid:
                out[key] = out[sid]
    return out


def chain():
    p = {n: pts for n, pts, _ in L.PATHS}
    return (p["road"] + [list(L.SQUARE_C)] + p["lane_west"] + [list(L.DYE_YARD_C)] + p["lane_dye_well"]
            + [list(L.WELL_C)] + p["lane_well_square"] + [list(L.SQUARE_C)] + p["lane_north"] + [list(L.SQUARE_C)]
            + p["lane_east"] + [list(L.JETTY_SQ_C)] + p["lane_ford"])


def point(xz):
    return [round(xz[0], 2), round(L.ground(*xz), 2), round(xz[1], 2)]


def route():
    kindle = lambda k, f: {"cast": "kindle", "target": "Lamp_" + k, "before": 2.2, "flag": f}
    said = lambda i: {"wait_flag": "said_" + i, "timeout": 40}
    return [
        {"talk": "Pell"}, {"stage": "arrival"},
        {"talk": "Trim"},
        {"cast": "bloom", "target": "Verse_1", "before": 2.5, "flag": "verse_1_read"}, {"stage": "verse_1_read"},
        kindle("Trim", "lit_trim"), {"talk": "Trim"}, {"stage": "trim_lit"},
        {"cast": "slash", "target": "VatThorns", "before": 4, "from": "M_Square", "flag": "thorns_cut"},
        kindle("Marrow", "lit_marrow"), {"talk": "Marrow"}, {"stage": "marrow_lit"},
        {"cast": "gust", "target": "WellSoot", "before": 4, "flag": "well_cleared"},
        kindle("Brindle", "lit_brindle"), {"talk": "Brindle"}, {"stage": "brindle_lit"},
        {"cast": "bloom", "target": "Persimmon", "before": 5, "flag": "persimmon_bloomed"},
        kindle("Children", "lit_children"), {"talk": "Flax"}, {"stage": "children_lit"},
        kindle("Ferry", "lit_ferry"),
        {"fight": "JettyFight", "finish": True}, {"expect_flag": "fight_jetty"}, {"wait": 2.5}, {"stage": "jetty_held"},
        {"talk": "Wherry"},
        {"go": "M_Verse_2", "before": 1.0},
        {"cast": "gust", "target": "FordHood", "flag": "hood_cleared"},
        {"cast": "kindle", "target": "Lamp_Ford", "flag": "lit_ford"}, said("finale"), {"stage": "finale"},
        {"go": "RaftExit", "before": 0.5},
    ]


def tour(c, w, d, target, m=1.6):
    """Round a building at m metres from its walls, starting and ending in front of it."""
    yaw = L.face_yaw(c, target)
    lx, lz = w / 2 + m, d / 2 + m
    return [L.local_to_world(c, yaw, x, z) for x, z in
            ((0.0, d / 2 + 2.5), (lx, lz), (lx, -lz), (-lx, -lz), (-lx, lz), (0.0, d / 2 + 2.5))]


def ring(c, r, n=8):
    return [(c[0] + r * math.cos(2 * math.pi * k / n), c[1] + r * math.sin(2 * math.pi * k / n)) for k in range(n + 1)]


def bank(zs, inset=1.4):
    return [(L.river_x(z) - L.RIVER_HALF - inset, z) for z in zs]


def walk_route():
    """The collision walk (boot option tf_route=walk): from the lit village (the M_PellWait warp)
    along every lane, round every building, the square, the well and the dye yard, the river bank,
    the ford causeway and the jetty, ending at the raft. Straight legs, no chain."""
    p = {n: pts for n, pts, _ in L.PATHS}
    h = {n: (c, w, d, t) for n, c, w, d, t, _ in L.HOUSES}
    cot = [(c, w, d, t) for _, c, w, d, t in L.COTTAGES]
    shed = [(c, w, d, t) for _, c, w, d, t in L.SHEDS]
    legs = [
        ("bank_south", bank([-1.0, 4.0, 10.0, 16.0, 21.0]) + [L.LANDING_C, (27.5, 27.5)]),
        ("road", p["road"][1:3]),
        ("cottage_3", tour(*cot[2])),
        ("road", p["road"][3:4]),
        ("house_trim", tour(*h["house_trim"])),
        ("road", p["road"][4:5]),
        ("cottage_2", tour(*cot[1])),
        ("road", p["road"][5:]),
        ("square", ring(L.SQUARE_C, 4.5)),
        ("lane_well_square", p["lane_well_square"][::-1]),
        ("well", ring(L.WELL_C, 3.0, 6)),
        ("house_brindle", tour(*h["house_brindle"])),
        ("lane_dye_well", p["lane_dye_well"][::-1]),
        ("cottage_4", tour(*cot[3])),
        ("lane_dye_well", p["lane_dye_well"][:1]),
        ("dye_yard", [(-16.0, 2.0), (-17.5, -2.5), (-21.0, -4.0), (-24.5, -2.0), (-24.0, 2.5), (-24.5, 0.5), (-27.0, 0.5)]),
        ("shed_3", tour(*shed[2])),
        ("house_marrow", tour(*h["house_marrow"])),
        ("lane_west", p["lane_west"][::-1]),
        ("shed_2", tour(*shed[1])),
        ("cottage_1", tour(*cot[0])),
        ("house_children", tour(*h["house_children"])),
        ("lane_north", p["lane_north"][::-1]),
        ("shed_1", tour(*shed[0])),
        ("lane_east", p["lane_east"]),
        ("lane_ferry", p["lane_ferry"]),
        ("house_ferry", tour(*h["house_ferry"])),
        ("lane_ford", p["lane_ford"]),
        ("causeway", L.causeway_stones() + [(L.FORD_PIER[0] - 1.2, L.FORD_PIER[1])] + L.causeway_stones()[::-1]),
        ("bank_north", bank([-20.0, -14.0, -9.0])),
        ("jetty", [L.JETTY_SQ_C, (26.0, L.JETTY_SQ_C[1]), (30.0, L.JETTY_SQ_C[1])]),
    ]
    out = []
    for name, pts in legs:
        out.append({"stage": "walk_" + name})
        out += [{"go": point(xz)} for xz in pts]
    return out + [{"go": "RaftExit", "before": 0.5}]


def to_json():
    flags_so_far, warps = [], {}
    for (text, flags), at in zip(OBJECTIVES, ["M_Verse_1", "M_Lamp_Trim", "M_DyeVats", "M_Well", "M_Persimmon",
                                               "M_JettySquare", "M_FordLamp"]):
        warps[at] = {"flags": list(flags_so_far), "face": at}
        flags_so_far += flags
    warps["M_PellWait"] = {"flags": list(flags_so_far), "face": "M_RaftCross"}
    return {
        "_comment": "Generated by tools/levels/tallowford/level_data.py from script.json and layout.py; do not edit by hand.",
        "spawn_facing": "Trim",
        "complete_on_objectives": False,
        "objectives": [{"text": t, "flags": f} for t, f in OBJECTIVES],
        "lines": lines(),
        "raft": {"talk": "pell_ready", "card": "Pell poles the raft upriver, past the lit ford-lamp.",
                 "depart": [JETTY_END_X + 1.1, L.WATER_Y, L.JETTY_SQ_C[1] - L.JETTY_W / 2 - 2.0], "depart_yaw": 0.0, "water": L.WATER_Y},
        "end_text": "[font_size=34]Every window in Tallowford is lit.[/font_size]\n\nThe ford-lamp burns over the Lull "
                    "again, and from the bend you can see the whole village glowing.",
        "warps": warps,
        "autoplay": {"chain": [point(p) for p in chain()], "route": route()},
        "tallowford": {
            "people": {n: {"display_name": SPEAKERS[n.lower()]["name"], "talk_id": t, "model": m, "at": at, "faded": f,
                           "wake_flag": w, "bark_on_flag": BARKS.get(n, {}),
                           "talk_by_flag": TALK_BY_FLAG.get(n, {"lit_ford": t + "_end"} if t + "_end" in lines() else {})}
                       for n, (t, m, at, f, w, _) in PEOPLE.items()},
            "nodes": NODES,
            "chapter_card": "Tallowford lights its lamps at dusk. Tonight, not one window is lit.",
            "near": [{"lines": i, "at": m, "radius": r, "unless": u} for i, m, r, u in NEAR],
            "walk": {"warp": "M_PellWait", "route": walk_route()},
            "on_flag": ON_FLAG,
            "intro": {"talk": "arrival", "who": "Pell"},
            "pools": {"Trim": 6.5, "Marrow": 6.5, "Brindle": 6.5, "Children": 6.5, "Ferry": 6.5, "Ford": 7.0, "cottages": 4.5},
        },
    }


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "scenes/levels/tallowford/level.json"
    data = to_json()
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("LEVEL_DATA", out.relative_to(ROOT).as_posix(), len(data["lines"]), "line sets", len(data["autoplay"]["route"]), "steps")
