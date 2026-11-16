"""Write the level's data from kiln_layout.py and scripts/levels/hollow_kiln/kiln_script.json:

  scripts/levels/hollow_kiln/kiln_layout.json   everything phase B places (markers, props, people,
                                                fights, curse zones, planks, soot drifts, flue ledges,
                                                moss, lamps, the Dregs' numbers, the route)
  scenes/levels/hollow_kiln/level.json          the kit's data file (docs/LEVEL_KIT.md, section 3):
                                                objectives, lines, raft, warps, autoplay chain and route

so the game reads the same numbers as the generators and DESIGN.md.

    python tools/levels/hollow_kiln/export_layout.py
"""
import json
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kiln_layout as K  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "scripts", "levels", "hollow_kiln", "kiln_layout.json")
SCRIPT = os.path.join(ROOT, "scripts", "levels", "hollow_kiln", "kiln_script.json")
LEVEL = os.path.join(ROOT, "scenes", "levels", "hollow_kiln", "level.json")

# Flags, in the order the level sets them. Kit defaults: fight_<id>, talked_<talk_id>, restored_<zone>.
OBJECTIVES = [
    {"text": "Open the kiln gate", "flag": "gate_cut"},
    {"text": "Clear the yard", "flag": "restored_yard"},
    {"text": "Cross the drying hall", "flags": ["restored_hall", "counterweight_tied"]},
    {"text": "Climb the flue", "flag": "flue_climbed"},
    {"text": "Still the Dregs", "flag": "dregs_unravelled"},
    {"text": "Bloom the cracked vat", "flag": "vat_bloomed"},
]
YARD_DONE = ["gate_cut", "fight_yard", "restored_yard"]
HALL_DONE = YARD_DONE + ["hall_entered", "bellows_1_blown", "bellows_2_blown", "drift_d1", "drift_d2", "drift_d3", "drift_d4", "drift_d5", "drift_d6", "fight_hall_ambush", "restored_hall"]
WARPS = {
    "M_Yard": {"flags": ["gate_cut"], "face": "M_HallDoor"},
    "M_HallDoor": {"flags": YARD_DONE, "face": "M_Hall"},
    "M_TieAnchor": {"flags": HALL_DONE, "face": "M_CounterDoor"},
    "M_FlueEntry": {"flags": HALL_DONE + ["counterweight_tied"], "face": "M_Flue"},
    "M_FlueTop": {"flags": HALL_DONE + ["counterweight_tied"], "face": "M_Arena_Entry"},
    "M_Arena_Entry": {"flags": HALL_DONE + ["counterweight_tied", "flue_climbed"], "face": "M_Vat"},
}
# The walker's line, south to north; flue points ride the ledges (kiln_layout.FLUE_LEDGES) and the moss footholds.
CHAIN = ([[x, None, z] for x, z in K.PATH[:-1]] +
         [[-8.0, 5.0, -30.5], [-0.5, 5.0, -30.5], [-0.5, 7.2, -36.6], "M_Moss_M1", [-0.5, 8.2, -41.4], [-0.5, 9.3, -46.6],
          [-13.6, 12.0, -46.6], [-15.5, 12.0, -46.6], [-15.5, 12.4, -39.0], "M_Moss_M2", "M_Moss_M3", [-15.5, 15.0, -33.2], [-15.5, 15.15, -29.8],
          [0.0, 16.7, -30.5], [0.0, 16.8, -33.5], "M_FlueTop", [-1.0, 18.0, -49.5], "M_Arena_Entry"])
# What the level plays today, with the parts the kit has (docs/LEVEL_KIT.md): the landing to the end
# of the book. The flue's ink does not rise yet (the kit's rising hazard). QA starts (hollow_kiln.gd,
# hk_start=<name>) begin a part with everything before it done and play only that part.
ROUTE_HEAD = [
    {"talk": "Pell"}, {"stage": "hk_arrival"},
    {"cast": "bloom", "target": "VerseStone_1", "before": 2.5, "flag": "verse_1_read"}, {"stage": "hk_verse_1"},
    {"cast": "slash", "target": "CordGate", "before": 4, "from": "M_Spawn", "flag": "gate_cut"},
    {"go": [0.0, 1.5, 39.0]}, {"cast": "kindle", "target": "Brazier_W", "flag": "brazier_w_lit"},
    {"cast": "kindle", "target": "Brazier_E", "flag": "brazier_e_lit"}, {"stage": "hk_gate_open"},
    {"go": "M_Yard"}, {"fight": "YardFight", "finish": True}, {"expect_flag": "fight_yard"}, {"stage": "hk_yard_fight_won"},
    {"bloom_zone": "Zone_yard"}, {"stage": "hk_yard_restored"},
    {"talk": "Wenna"}, {"stage": "hk_wenna_awake"},
    {"go": "M_HallDoor"}, {"stage": "hk_hall"}, {"go": [-10.6, 5.3, -5.0]},
    {"cast": "bloom", "target": "VerseStone_2", "before": 2.5, "flag": "verse_2_read"},
    {"probe_cursed": "HallFloor", "toward": [-8.0, 5.0, -9.0]}, {"stage": "hk_hall_floor_hurts"},
    {"go": [-12.0, 5.3, -4.4]},
    {"cast": "gust", "target": "Bellows_1", "flag": "bellows_1_blown"}, {"wait_flag": "drift_d3", "timeout": 3},
    {"stage": "hk_front_aisle_clear"},
    {"go": [14.0, 5.3, -12.0]}, {"go": [14.0, 5.3, -18.6]},
    {"cast": "gust", "target": "Bellows_2", "flag": "bellows_2_blown"},
    {"fight": "HallAmbush"}, {"expect_flag": "fight_hall_ambush"}, {"stage": "hk_hall_ambush_won"},
    {"wait_flag": "drift_d6", "timeout": 3},
    {"go": [-4.0, 5.3, -20.8]}, {"cast": "bloom", "target": "Sapling_hall", "flag": "restored_hall"}, {"stage": "hk_hall_restored"},
    {"death_test": True},
    {"go": [2.0, 5.3, -20.8]}, {"tie": ["TiePost", "CounterweightRing"], "flag": "counterweight_tied"},
    {"wait": 1.5}, {"stage": "hk_counterweight_door_open"},
]
ROUTE_FLUE = [
    {"go": "M_FlueEntry"}, {"stage": "hk_flue"},
    {"cast": "kindle", "target": "WallLamp_K1", "flag": "lamp_k1"},
    {"go": [-0.5, 6.4, -34.0]}, {"cast": "bloom", "target": "MossFoothold_M1", "flag": "moss_m1"}, {"stage": "hk_moss_1"},
    {"go": [-0.5, 9.3, -46.6]}, {"cast": "kindle", "target": "WallLamp_K2", "flag": "lamp_k2"},
    {"probe_rising": "FlueRise", "toward": [-8.0, 9.3, -38.0]}, {"stage": "hk_flue_ink_lifted"},
    {"go": [-0.5, 9.3, -46.6]},
    {"go": [-15.5, 12.0, -46.6]}, {"cast": "kindle", "target": "WallLamp_K3", "flag": "lamp_k3"},
    {"cast": "bloom", "target": "MossFoothold_M2", "flag": "moss_m2"},
    {"cast": "bloom", "target": "MossFoothold_M3", "flag": "moss_m3"}, {"stage": "hk_moss_2_3"},
    {"go": [0.0, 16.7, -30.5]}, {"cast": "kindle", "target": "WallLamp_K4", "flag": "lamp_k4"},
    {"go": [0.0, 16.8, -33.5]}, {"go": "M_FlueTop"}, {"expect_above": 17.5}, {"wait_flag": "flue_climbed", "timeout": 5},
    {"stage": "hk_flue_climbed"},
    {"cast": "bloom", "target": "VerseStone_3", "before": 2.5, "flag": "verse_3_read"}, {"stage": "hk_verse_3"},
]
ROUTE_ARENA = [
    {"go": "M_Arena_Entry"}, {"wait_flag": "dregs_started", "timeout": 5}, {"stage": "hk_arena"},
    {"go": [7.7, 18.0, -55.8]}, {"look": "M_Vat", "pitch": -5.0}, {"wait": 1.0}, {"stage": "hk_dregs_veiled"},
    {"cast": "gust", "target": "Dregs", "flag": "dregs_veil_thin", "attempts": 6},
    {"cast": "gust", "target": "Dregs", "flag": "dregs_veil_off", "attempts": 2},
    {"go": [7.7, 18.0, -55.8]}, {"look": "M_Vat", "pitch": -5.0}, {"wait": 1.0}, {"stage": "hk_dregs_unveiled"},
    {"go": [8.5, 18.0, -54.7]}, {"look": "M_Vat", "pitch": -5.0},
    {"wait_flag": "dregs_arm_down", "timeout": 12}, {"cast": "slash", "target": "Dregs", "flag": "dregs_cut_one", "attempts": 3},
    {"wait_flag": "dregs_arm_down", "timeout": 12}, {"cast": "slash", "target": "Dregs", "flag": "dregs_arms_cut", "attempts": 3},
    {"go": [2.0, 18.0, -55.0]}, {"wait": 1.0}, {"stage": "hk_dregs_arms_cut"},
    {"tie": ["PillarRing_W", "PillarRing_E"], "flag": "dregs_bound"},
    {"go": [8.5, 18.0, -54.7]}, {"look": "M_Vat", "pitch": -5.0}, {"wait": 1.0}, {"stage": "hk_dregs_bound"},
    {"go": "M_Mouth_NW", "before": 1.6, "from": "M_Vat"}, {"cast": "kindle", "target": "KilnMouth_NW", "flag": "mouth_nw_lit"},
    {"go": "M_Mouth_N", "before": 1.6, "from": "M_Vat"}, {"cast": "kindle", "target": "KilnMouth_N", "flag": "mouth_n_lit"},
    {"go": "M_Mouth_NE", "before": 1.6, "from": "M_Vat"}, {"cast": "kindle", "target": "KilnMouth_NE", "flag": "mouth_ne_lit"},
    {"wait_flag": "dregs_unravelled", "timeout": 15}, {"stage": "hk_dregs_unravelled"},
    {"fight": "Zone_vat"},
    {"go": [2.0, 18.0, -55.0]}, {"cast": "bloom", "target": "CrackedVat", "flag": "vat_bloomed", "attempts": 6}, {"stage": "hk_tree"},
    {"cast": "bloom", "target": "VerseStone_4", "before": 2.5, "flag": "verse_4_read"}, {"stage": "hk_ending"},
]
ROUTE = ROUTE_HEAD + ROUTE_FLUE + ROUTE_ARENA
# The end card's heading: the Kiln is the last level of Book One.
END_TEXT = "\n\n".join([
    "[font_size=34]End of Book One[/font_size]",
    "The Ink-maker's last stone gives his answer: colour stays by coming back.",
    "Five beads on Orimi's cord: ivory, lamp gold, sedge green, water indigo, kiln vermilion.",
    "The Lull runs clear from the tree's roots, down through every place it greyed.",
])
ARENA_IN = ROUTE_FLUE[-2:] + ROUTE_ARENA[:3]   # to the arena door, which wakes the Dregs


def arena_from(step):
    """ROUTE_ARENA from the first step equal to step."""
    return ROUTE_ARENA[ROUTE_ARENA.index(step):]


FIGHT_SPOT = {"go": [8.5, 18.0, -54.7]}
QA_STARTS = {
    "flue": {"marker": "M_FlueEntry", "route": ROUTE_FLUE + ROUTE_ARENA},
    "arena": {"marker": "M_FlueTop", "route": ARENA_IN + ROUTE_ARENA[3:]},
    # the Dregs on its own, one part at a time: the flags make it wake in that part (dregs.gd _resume_part)
    "dregs_lash": {"marker": "M_FlueTop", "more_flags": ["dregs_veil_off"],
                   "route": ARENA_IN + [FIGHT_SPOT, {"look": "M_Vat", "pitch": -5.0}, {"wait": 1.0}]
                   + arena_from({"wait_flag": "dregs_arm_down", "timeout": 12})},
    "dregs_climb": {"marker": "M_FlueTop", "more_flags": ["dregs_veil_off", "dregs_arms_cut"],
                    "route": ARENA_IN + arena_from({"go": [2.0, 18.0, -55.0]})},
    "dregs_bound": {"marker": "M_FlueTop", "more_flags": ["dregs_veil_off", "dregs_arms_cut", "dregs_bound"],
                    "route": ARENA_IN + ROUTE_ARENA[ROUTE_ARENA.index({"stage": "hk_dregs_bound"}) - 3:]},
}
# The whole level, once the kit has verse-stones, Kindle and Tie targets and the rising hazard.
ROUTE_PLAN = [
    {"talk": "Pell"}, {"cast": "bloom", "target": "VerseStone_1", "flag": "verse_1_read"},
    {"cast": "slash", "target": "CordGate", "flag": "gate_cut"},
    {"cast": "kindle", "target": "Brazier_W", "flag": "brazier_w_lit"}, {"cast": "kindle", "target": "Brazier_E", "flag": "brazier_e_lit"},
    {"fight": "YardFight", "finish": True}, {"bloom_zone": "Zone_yard"}, {"talk": "Wenna"},
    {"cast": "bloom", "target": "VerseStone_2", "flag": "verse_2_read"},
    {"cast": "gust", "target": "Bellows_1", "flag": "bellows_1_blown"}, {"cast": "gust", "target": "Bellows_2", "flag": "bellows_2_blown"},
    {"fight": "HallAmbush"}, {"bloom_zone": "Zone_hall"},
    {"tie": ["TiePost", "Counterweight"], "flag": "counterweight_tied"},
    {"cast": "bloom", "target": "MossFoothold_M1", "flag": "moss_m1"}, {"cast": "kindle", "target": "WallLamp_K1", "flag": "lamp_k1"},
    {"cast": "kindle", "target": "WallLamp_K2", "flag": "lamp_k2"}, {"cast": "bloom", "target": "MossFoothold_M2", "flag": "moss_m2"},
    {"cast": "bloom", "target": "MossFoothold_M3", "flag": "moss_m3"}, {"cast": "kindle", "target": "WallLamp_K3", "flag": "lamp_k3"},
    {"cast": "kindle", "target": "WallLamp_K4", "flag": "lamp_k4"}, {"go": "M_FlueTop"}, {"wait_flag": "flue_climbed"},
    {"cast": "bloom", "target": "VerseStone_3", "flag": "verse_3_read"}, {"go": "M_Arena_Entry"},
    {"cast": "gust", "target": "Dregs", "flag": "dregs_veil_off"}, {"cast": "slash", "target": "Dregs", "flag": "dregs_arms_cut"},
    {"tie": ["PillarRing_W", "PillarRing_E"], "flag": "dregs_bound"},
    {"cast": "kindle", "target": "KilnMouth_NW", "flag": "mouth_nw_lit"}, {"cast": "kindle", "target": "KilnMouth_N", "flag": "mouth_n_lit"},
    {"cast": "kindle", "target": "KilnMouth_NE", "flag": "mouth_ne_lit"}, {"wait_flag": "dregs_unravelled"},
    {"cast": "bloom", "target": "CrackedVat", "until": "cutscene"}, {"wait_flag": "vat_bloomed"},
    {"cast": "bloom", "target": "VerseStone_4", "flag": "verse_4_read"},
]


def r(v):
    if isinstance(v, float):
        return round(v, 3)
    if isinstance(v, (list, tuple)):
        return [r(x) for x in v]
    if isinstance(v, dict):
        return {k: r(x) for k, x in v.items()}
    return v


def rect(xr, zr):
    return {"polygon": [[xr[0], 0, zr[0]], [xr[1], 0, zr[0]], [xr[1], 0, zr[1]], [xr[0], 0, zr[1]]]}


def safe_ground():
    """level.json safe_ground for the hall's CursedGround: its planks (and everything outside the
    hall's walls inside its circle). The flue's ink is a RisingHazard (FlueRise)."""
    hx, hz = K.HALL["x"], K.HALL["z"]
    hall = [rect(xr, zr) for xr, zr in K.PLANKS.values()]
    hall.append(rect(K.HALL_DOOR_N["x"], (hz[0] - 1.5, K.PLANKS["P3"][1][0])))
    hall += [rect((-40.0, 40.0), (hz[1], 20.0)), rect((-40.0, 40.0), (-60.0, hz[0])), rect((-40.0, hx[0]), hz), rect((hx[1], 40.0), hz)]
    return {"HallFloor": hall}


def dark_places():
    """Boxes where render's light pools darken the level (hollow_kiln.gd): the hall until it is restored,
    the flue and the vat chamber until the vat blooms. Lit lamps and kiln mouths open pools in them.
    enter_flag is set the first time Orimi is inside (the hall's bellows and ambush wait for it)."""
    hx, hz, fx, fz = K.HALL["x"], K.HALL["z"], K.FLUE["x"], K.FLUE["z"]
    cx, cy, cz = K.DRUM_C
    rr = K.DRUM_R
    return [
        {"box": [[hx[0], K.Y_HALL - 1.0, hz[0] - 4.0], [hx[1], K.Y_HALL + K.HALL["ridge"], hz[1]]], "darkness": 0.55, "until": "restored_hall",
         "enter_flag": "hall_entered"},
        {"box": [[fx[0], K.FLUE["base"] - 1.0, fz[0]], [fx[1], K.FLUE["roof"], fz[1] + 1.5]], "darkness": 1.0, "until": "vat_bloomed"},
        {"box": [[cx - rr, cy - 1.0, cz - rr], [cx + rr, cy + K.DRUM_WALL_H + K.DOME_RISE, cz + rr + 2.0]], "darkness": 0.45, "until": "vat_bloomed"},
    ]


def main():
    data = {
        "_comment": "Generated by tools/levels/hollow_kiln/export_layout.py from kiln_layout.py. Godot metres; yaw in degrees, 0 faces -Z.",
        "elevations": {"landing": K.Y_LANDING, "yard": K.Y_YARD, "hall": K.Y_HALL, "plank": K.Y_PLANK, "vat": K.Y_VAT, "water": K.WATER_Y},
        "markers": K.MARKERS,
        "props": [{"model": m, "at": [x, y, z], "yaw": yaw} for m, x, y, z, yaw in K.PROPS],
        "people": K.PEOPLE,
        "fights": K.FIGHTS,
        "curse_zones": [{"slot": s, "centre": c, "radius": rad} for s, c, rad in K.CURSE_ZONES],
        "hall": {"planks": K.PLANKS, "plank_y": K.Y_PLANK, "soot_drifts": K.SOOT_DRIFTS, "rack_rows": K.RACK_ROWS},
        "flue": {"box": K.FLUE, "ledges": [{"name": n, "x": xr, "z": zr, "y0": y0, "y1": y1, "axis": ax, "sign": sg}
                                           for n, xr, zr, y0, y1, ax, sg in K.FLUE_LEDGES],
                 "moss": K.MOSS, "lamps": K.FLUE_LAMPS},
        "vat_chamber": {"centre": K.DRUM_C, "radius": K.DRUM_R, "vat": K.VAT, "pillars": K.PILLARS, "mouths": K.KILN_MOUTHS,
                        "chain_crown": K.CHAIN_CROWN, "oculus_y": K.Y_VAT + K.DRUM_WALL_H + K.DOME_RISE},
        "dregs": K.DREGS,
        "route": [{"marker": m, "beat": text} for m, text in K.ROUTE],
        "autoplay_plan": ROUTE_PLAN,
        "walk_path": K.PATH,
    }
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(r(data), f, indent=1)
        f.write("\n")
    print("LAYOUT", os.path.relpath(OUT, ROOT).replace(os.sep, "/"), len(K.MARKERS), "markers", len(K.PROPS), "props")
    with open(SCRIPT, encoding="utf-8") as f:
        script = json.load(f)
    lines = {}
    for sc in script["scenes"]:
        who = None if sc["speaker"] in ("pell", "wenna") else ("" if sc["speaker"] == "narration" else script["speakers"][sc["speaker"]]["name"])
        lines[sc["id"]] = [{"text": t} if who is None else {"who": who, "text": t} for t in sc["lines"]]
    lines["ending"] = [{"who": "Pell", "text": t} for t in next(s for s in script["scenes"] if s["id"] == "ending")["lines"]]
    chain = []
    for pt in CHAIN:
        if isinstance(pt, list) and pt[1] is None:
            pt = [pt[0], float(K.height(pt[0], pt[2])) if pt[2] > 33.0 else (K.Y_YARD if pt[2] > 0.6 else K.Y_PLANK), pt[2]]
        chain.append(r(pt))
    level = {
        "_comment": "Generated by tools/levels/hollow_kiln/export_layout.py (lines from scripts/levels/hollow_kiln/kiln_script.json). Node names in the route are the ones DESIGN.md lists under 'Nodes phase B places'.",
        "spawn_facing": "M_Gate",
        "complete_on_objectives": False,
        "objectives": OBJECTIVES,
        "lines": lines,
        "raft": {"talk": "ending", "card": "End of Book One."},
        "end_text": END_TEXT,
        "warps": WARPS,
        "autoplay": {"chain": chain, "route": ROUTE},
        "qa_starts": {k: {"marker": v["marker"], "route": v["route"], "flags": WARPS[v["marker"]]["flags"] + v.get("more_flags", []),
                          "face": WARPS[v["marker"]]["face"]} for k, v in QA_STARTS.items()},
        "safe_ground": safe_ground(),
        "dark_places": dark_places(),
    }
    with open(LEVEL, "w", encoding="utf-8", newline="\n") as f:
        json.dump(level, f, indent="\t")
        f.write("\n")
    print("LEVEL", os.path.relpath(LEVEL, ROOT).replace(os.sep, "/"), len(lines), "talks", len(ROUTE), "route steps")


if __name__ == "__main__":
    main()
