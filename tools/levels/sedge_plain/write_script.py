"""Sedge Plain's script: every line of talk, every verse-stone, every pickup card and prompt, in
play order, with who says it and what triggers it. The one source for both outputs:

    python tools/levels/sedge_plain/write_script.py

  scripts/levels/sedge_plain/sedge_script.json   the data phase B loads (no retyping)
  docs/levels/sedge_plain/SCRIPT.md              the same, for reading

Words in [square brackets] take the panel's accent colour; the brackets are markup, not text.
"""
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BT = chr(96)

SPEAKERS = {
    "pell": {"name": "Pell", "who": "the ferry child (recurring, shared across levels)"},
    "tamsin": {"name": "Tamsin", "who": "the mapmaker, camped by the river"},
    "verse": {"name": "Verse-stone", "who": "the Ink-maker's words, spoken when a verse-stone is bloomed"},
    "card": {"name": "", "who": "a pickup card: no speaker, shown on the paper panel"},
}

# Each scene: id, beat, speaker, trigger (what starts it), where (marker), once (plays once), lines.
SCENES = [
    {"id": "pell_arrival", "beat": 0, "speaker": "pell", "trigger": "talk to Pell on the jetty at the landing, beside the raft (first time)",
     "where": "M_Landing", "once": True, "lines": [
         "Sedge Plain. Mind the holes. They bite.",
         "I'll pole round through the trees and wait where the brook comes out of the [wood].",
         "If you hear someone shouting at the wind, that's the mapmaker. She's harmless. Mostly.",
     ]},
    {"id": "pell_arrival_again", "beat": 0, "speaker": "pell", "trigger": "talk to Pell on the jetty again", "where": "M_Landing",
     "once": False, "lines": [
         "Go on. I'll be at the brook by the [wood]. Ears ready.",
     ]},
    {"id": "tamsin_meet", "beat": 1, "speaker": "tamsin", "trigger": "talk to Tamsin at her camp (first time)",
     "where": "M_Tamsin_Camp", "once": True, "lines": [
         "Oh! A fox. A paper fox. Are you lost as well?",
         "Don't answer that. Nobody out here answers.",
         "I'm Tamsin. I map this plain. Mapped it. Was mapping it.",
         "Then the black came up in the low places, and the wind took my map clean off the frame.",
         "Three leaves, and every one blew into a hollow. Of course it did.",
         "The first went north, past the [Leaning Stones], toward the gully. The [Seam], I call it.",
         "Bring it back and I'll draw you. From the good side.",
     ]},
    {"id": "tamsin_rim_early", "beat": 3, "speaker": "tamsin", "trigger": "talk to Tamsin on the rim before the first leaf is found",
     "where": "M_Tamsin_Rim", "once": False, "lines": [
         "The leaf went down by the Mere's rim, just east of here. Bring it and I'll show you where we are.",
     ]},
    {"id": "tamsin_meet_again", "beat": 1, "speaker": "tamsin", "trigger": "talk to Tamsin at her camp again, before leaf 1",
     "where": "M_Tamsin_Camp", "once": False, "lines": [
         "North, past the stones. The leaf is the one thing out there that isn't sedge.",
     ]},
    {"id": "verse_1", "beat": 2, "speaker": "verse", "trigger": "Bloom on the verse-stone by the first bridge; the Tie prompt follows",
     "where": "M_Verse_1", "once": True, "lines": [
         "I carried soot across this plain each spring.",
         "Where the ground split, I strung a rope from post to post.",
         "One straight line and two good posts make a bridge.",
         "I made a thousand. I never made one home.",
     ]},
    {"id": "leaf_1", "beat": 3, "speaker": "card", "trigger": "pick up the first leaf on the Mere's south rim",
     "where": "M_Leaf_1", "once": True, "lines": [
         "A leaf of Tamsin's map: most of the plain, and a hole where the middle should be.",
     ]},
    {"id": "tamsin_rim", "beat": 3, "speaker": "tamsin", "trigger": "talk to Tamsin at the rim (she crosses the first bridge once it is tied and waits at M_Tamsin_Rim)",
     "where": "M_Tamsin_Rim", "once": True, "lines": [
         "You tied the bridge! I walked over it with my eyes shut. Both of them.",
         "That's my first leaf. Look: there's the [Mere], and the Knoll in the middle of it.",
         "There used to be a road out to the Knoll. My map knows where. My map is in three pieces.",
         "The second leaf is east, out on the island in [Kettle Hollow]. The causeway's under soot.",
         "Soot blows away, I'm told. Do you blow?",
     ]},
    {"id": "tamsin_rim_again", "beat": 3, "speaker": "tamsin", "trigger": "talk to Tamsin at the rim again, with one leaf",
     "where": "M_Tamsin_Rim", "once": False, "lines": [
         "East, to Kettle Hollow. Blow the soot off the causeway and walk out to the island.",
     ]},
    {"id": "spur_dead_end", "beat": 3, "speaker": "card", "trigger": "reach the end of a false spur in the Mere (either spur), once",
     "where": "causeway_spur_south / causeway_spur_east (end point)", "once": True, "lines": [
         "The old road stops here, in the black. This isn't the way.",
     ]},
    {"id": "leaf_2", "beat": 4, "speaker": "card", "trigger": "pick up the second leaf on Kettle Hollow's island",
     "where": "M_Leaf_2", "once": True, "lines": [
         "The second leaf: a road leaves the rim for the Knoll, then runs off the edge of the page.",
     ]},
    {"id": "tamsin_two_leaves", "beat": 4, "speaker": "tamsin", "trigger": "talk to Tamsin at the rim with two leaves",
     "where": "M_Tamsin_Rim", "once": False, "lines": [
         "Kettle Hollow! I named it. It whistles when the wind's in the south.",
         "The last leaf went west, back over the gully, into [Ladle Hollow]. Yes, I named that one too.",
     ]},
    {"id": "leaf_3", "beat": 5, "speaker": "card", "trigger": "pick up the third leaf on Ladle Hollow's island",
     "where": "M_Leaf_3", "once": True, "lines": [
         "The third leaf: two bends, a gap, and the Knoll.",
     ]},
    {"id": "tamsin_map", "beat": 6, "speaker": "tamsin", "trigger": "talk to Tamsin at the rim with all three leaves; afterwards the soot at the Mere causeway can be blown away",
     "where": "M_Tamsin_Rim", "once": True, "lines": [
         "All three! Hold still, I need your nose to pin the corner.",
         "There. The old road goes in by the [leaning post], bends twice, and jumps a gap before the Knoll.",
         "The soot at the start is thick. Blow hard. Then [tie] the gap the way you tied the gully.",
         "I'd come along, but someone has to hold the map. Also I'm scared of the black. Mostly the second thing.",
     ]},
    {"id": "tamsin_map_again", "beat": 6, "speaker": "tamsin", "trigger": "talk to Tamsin at the rim again, before the Knoll is restored",
     "where": "M_Tamsin_Rim", "once": False, "lines": [
         "In by the leaning post, two bends, tie the gap. I'll be right here. Holding the map. Bravely.",
     ]},
    {"id": "verse_2", "beat": 7, "speaker": "verse", "trigger": "Bloom on the verse-stone on the Knoll (it stands by the sapling; it can be read before or after the fight)",
     "where": "M_Verse_2", "once": True, "lines": [
         "I boiled this sedge for green when I was young.",
         "The green ran out of every pot I filled.",
         "So I began to grind a black to keep it in.",
         "The plain kept its green without me. I should have asked it how.",
     ]},
    {"id": "tamsin_after", "beat": 8, "speaker": "tamsin", "trigger": "talk to Tamsin at the rim after the plain is restored",
     "where": "M_Tamsin_Rim", "once": True, "lines": [
         "Look at it. Every hollow green right to the bottom.",
         "I finished the map. Here's the river, all the way up past the [wood].",
         "And here's the mountain, and here is... nothing. I have never once drawn nothing.",
         "Somebody up there makes ink. Lots of it. I could smell it on the wind before the black came.",
         "Take the path north-west, down to the brook. Your ferry child is waiting there. Loudly.",
     ]},
    {"id": "tamsin_after_again", "beat": 8, "speaker": "tamsin", "trigger": "talk to Tamsin again after the restoration",
     "where": "M_Tamsin_Rim", "once": False, "lines": [
         "North-west, through the trees. Come back and I'll draw you. I did say the good side. I meant it.",
     ]},
    {"id": "pell_exit", "beat": 9, "speaker": "pell", "trigger": "reach the raft on the brook pool at the edge of the wood (M_Exit); the level ends after it",
     "where": "M_Exit", "once": True, "lines": [
         "There you are. The whole plain went green behind you. I saw it from the water.",
         "In you get. It's dark under those trees, so hold on to your ears.",
     ]},
]

# Short interface prompts the kit shows.
PROMPTS = [
    {"id": "prompt_kept_out", "trigger": "first time the black ground pushes Orimi back", "text": "The black ground won't let you in. Look for the raised road."},
    {"id": "prompt_soot_causeway", "trigger": "standing at a soot bank on a causeway", "text": "Soot buries the road. A [Gust] will clear it."},
    {"id": "prompt_mere_locked", "trigger": "Gust on the Mere's soot before Tamsin has read the map", "text": "The soot here won't shift. Tamsin's map might show the way."},
    {"id": "prompt_leaves", "trigger": "HUD counter while leaves are out", "text": "Map leaves: {n} of 3"},
]

BEAD = {"id": "bead_sedge_green", "trigger": "the restoration ends", "text": "The plain remembers its colour: [sedge green]."}


def code(s):
    return BT + s + BT


def write_md(path):
    lines = ["# Sedge Plain: the script", "",
             "Every line of talk and every verse-stone in play order, with who says it and what triggers it.",
             "Generated by %s, which also writes the same data to" % code("tools/levels/sedge_plain/write_script.py"),
             "%s for phase B. Edit the Python, not this file." % code("scripts/levels/sedge_plain/sedge_script.json"),
             "Words in [square brackets] take the panel's accent colour.", "",
             "## Who speaks", ""]
    for key, s in SPEAKERS.items():
        lines.append("- **%s** (%s): %s." % (s["name"] or "(card)", code(key), s["who"]))
    lines += ["", "## In order", ""]
    beat = None
    for sc in SCENES:
        if sc["beat"] != beat:
            beat = sc["beat"]
            lines += ["### Beat %d" % beat, ""]
        who = SPEAKERS[sc["speaker"]]["name"] or "Card"
        lines.append("**%s**: %s. Trigger: %s. Where: %s. %s" % (code(sc["id"]), who, sc["trigger"], code(sc["where"]), "Plays once." if sc["once"] else "Repeats."))
        lines.append("")
        for ln in sc["lines"]:
            lines.append("> %s%s  " % ((who + ": ") if sc["speaker"] in ("pell", "tamsin") else "", ln))
        lines.append("")
    lines += ["## Prompts", ""]
    for p in PROMPTS:
        lines.append("- %s (%s): \"%s\"" % (code(p["id"]), p["trigger"], p["text"]))
    lines += ["", "## Bead", "", "- %s (%s): \"%s\"" % (code(BEAD["id"]), BEAD["trigger"], BEAD["text"]), ""]
    words = sum(len(l.split()) for sc in SCENES for l in sc["lines"])
    lines += ["## Length", "",
              "%d scenes, %d lines, %d words: about three minutes of reading across the level, clicks included." % (
                  len(SCENES), sum(len(sc["lines"]) for sc in SCENES), words), ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


OBJECTIVES = [
    {"text": "Tie a rope across the Seam", "flag": "tied_bridge_1"},
    {"text": "Find Tamsin's first map leaf on the Mere's rim", "flag": "leaf_1"},
    {"text": "Fetch the leaf from Kettle Hollow", "flag": "leaf_2"},
    {"text": "Fetch the leaf from Ladle Hollow", "flag": "leaf_3"},
    {"text": "Bring Tamsin all three leaves", "flag": "talked_tamsin_map"},
    {"text": "Follow the old road through the Mere", "flag": "tied_mere_gap"},
    {"text": "Wake the sapling on the Knoll", "flag": "restored_mere"},
]

# Flags each warp sets first: everything the route has done before that marker.
_W1 = ["talked_tamsin_meet", "fight_stones", "read_verse_1", "tied_bridge_1", "leaf_1", "talked_tamsin_rim"]
_W2 = _W1 + ["fight_east", "soot_east_1", "soot_east_2", "leaf_2", "leaves_two", "talked_tamsin_two_leaves"]
_W3 = _W2 + ["tied_bridge_2", "fight_west", "soot_west_1", "soot_west_2", "leaf_3", "leaves_all", "talked_tamsin_map"]
WARPS = {
    "M_Verse_1": {"flags": ["talked_tamsin_meet", "fight_stones"], "face": "M_Bridge1_N"},
    "M_Tamsin_Rim": {"flags": _W1, "face": "M_Knoll"},
    "M_Causeway_East": {"flags": _W1, "face": "M_Island_East"},
    "M_Causeway_Mere": {"flags": _W3, "face": "M_Tie_Break_A"},
    "M_Knoll": {"flags": _W3 + ["soot_mere", "tied_mere_gap"], "face": "M_Sapling"},
    "M_Landing": {"flags": [], "face": "M_Knoll"},
    "M_Verse_2": {"flags": _W3 + ["soot_mere", "tied_mere_gap"], "face": "M_Hollow_East"},
    "Fight_Knoll": {"flags": _W3 + ["soot_mere", "tied_mere_gap"], "face": "M_Hollow_West"},
}

# The whole route, by the node names in sedge_plain.tscn (make_level.py). A step tagged "_needs" uses a
# kit part that does not exist yet: level.json leaves it out, and when it is "_gate" (the level cannot
# go on without it) the route stops there with a stage named after the missing part. No step needs
# one today.
def cross(a, b, lane=1.0, back=4.0):
    """Go steps over a Tie bridge from post marker a to post marker b, in a lane beside the posts that
    stand on the deck's ends: back metres behind a (to line up), 1.2 m past a (on the deck), 2 m past b."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import layout as LY
    m = LY.markers()
    (ax, ay, az), (bx, by, bz) = m[a], m[b]
    dx, dz = bx - ax, bz - az
    n = (dx * dx + dz * dz) ** 0.5
    ux, uz = dx / n, dz / n
    sx, sz = -uz * lane, ux * lane
    return [{"go": [round(ax - ux * back + sx, 2), round(ay, 2), round(az - uz * back + sz, 2)]},
            {"go": [round(ax + ux * 1.2 + sx, 2), round(ay, 2), round(az + uz * 1.2 + sz, 2)]},
            {"go": [round(bx + ux * 2.0 + sx, 2), round(by, 2), round(bz + uz * 2.0 + sz, 2)]}]


ROUTE = [
        {"stage": "arrival"},
        {"talk": "Pell"},
        {"go": [-2.5, 0, 44.5], "from": "M_Spawn"},
        {"talk": "Tamsin"},
        {"expect_flag": "talked_tamsin_meet"},
        {"go": [0.5, 0, 38]}, {"go": [5.5, 0, 30]},
        {"stage": "stones"},
        {"fight": "Fight_Stones", "finish": True},
        {"go": "M_Verse_1"},
        {"cast": "bloom", "target": "Verse_1", "before": 2.5, "flag": "read_verse_1"},
        cross("M_Bridge1_S", "M_Bridge1_N")[0],
        {"stage": "bridge_1"},
        {"tie": ["Bridge_1/PostA", "Bridge_1/PostB"], "before": 9.0, "flag": "tied_bridge_1"},
        {"stage": "bridge_1_tied"},
        *cross("M_Bridge1_S", "M_Bridge1_N")[:2],
        {"stage": "bridge_1_deck"},
        cross("M_Bridge1_S", "M_Bridge1_N")[2],
        {"go": "M_Leaf_1"},
        {"wait_flag": "leaf_1", "timeout": 5},
        {"go": [-2, 1, -7.6]}, {"go": [-9, 1, -9]},
        {"talk": "Tamsin_Rim"},
        {"expect_flag": "talked_tamsin_rim"},
        {"go": [-2, 1, -7.6]}, {"go": [12, 1, -7]}, {"go": [21, 1, -7.5]},
        {"stage": "east"},
        {"go": "M_Fight_2"},
        {"fight": "Fight_East"},
        {"go": "M_Causeway_East"},
        {"cast": "gust", "target": "Soot_East_1", "flag": "soot_east_1"},
        {"cast": "gust", "target": "Soot_East_2", "flag": "soot_east_2"},
        {"go": "M_Leaf_2", "from": "M_Causeway_East"},
        {"wait_flag": "leaf_2", "timeout": 5},
        {"stage": "kettle_island"},
        {"go": "M_Island_East"},
        {"probe_cursed": "Ground_east", "toward": [44, 0, -18]},
        {"go": "M_Island_East"}, {"go": "M_Soot_East_2"}, {"go": "M_Soot_East_1"},
        {"go": "M_Causeway_East"}, {"go": [21, 1, -7.5]}, {"go": [12, 1, -7]}, {"go": [-2, 1, -7.6]}, {"go": [-9, 1, -9]},
        {"talk": "Tamsin_Rim"},
        {"expect_flag": "talked_tamsin_two_leaves"},
        {"go": [-21, 1, -8]}, {"go": [-25.5, 1, -16]},
        {"stage": "bridge_2"},
        {"tie": ["Bridge_2/PostB", "Bridge_2/PostA"], "before": 9.0, "flag": "tied_bridge_2"},
        *cross("M_Bridge2_N", "M_Bridge2_S"),
        {"go": [-24, 1, 9.5]},
        {"stage": "west"},
        {"go": "M_Fight_3"},
        {"fight": "Fight_West"},
        {"go": "M_Causeway_West"},
        {"cast": "gust", "target": "Soot_West_1", "flag": "soot_west_1"},
        {"cast": "gust", "target": "Soot_West_2", "flag": "soot_west_2"},
        {"go": "M_Leaf_3", "from": "M_Causeway_West"},
        {"wait_flag": "leaf_3", "timeout": 5},
        {"stage": "ladle_island"},
        {"go": "M_Causeway_West"}, {"go": [-24, 1, 9.5]},
        *cross("M_Bridge2_S", "M_Bridge2_N"), {"go": [-21, 1, -8]},
        {"talk": "Tamsin_Rim"},
        {"expect_flag": "talked_tamsin_map"},
        {"go": "M_Causeway_Mere", "from": "M_Tamsin_Rim"},
        {"stage": "mere"},
        {"cast": "gust", "target": "Soot_Mere", "flag": "soot_mere"},
        {"go": [-10.8, 1, -19.6]}, cross("M_Tie_Break_A", "M_Tie_Break_B", 0.75, 1.5)[0],
        {"tie": ["Mere_Gap/PostA", "Mere_Gap/PostB"], "before": 3.6, "flag": "tied_mere_gap"},
        *cross("M_Tie_Break_A", "M_Tie_Break_B", 0.75, 1.5),
        {"go": "M_Knoll_Ramp"}, {"go": [-4.25, 3, -23.5]}, {"go": [1.2, 4.7, -21]},
        {"stage": "knoll"},
        {"fight": "Fight_Knoll"},
        {"cast": "bloom", "target": "Verse_2", "before": 2.5, "flag": "read_verse_2"},
        {"bloom_zone": "Zone_mere"},
        {"stage": "restored"},
        {"wait_flag": "restored_mere", "timeout": 20},
        {"go": [1.2, 4.7, -21]}, {"go": "M_Knoll_Ramp"}, *cross("M_Tie_Break_B", "M_Tie_Break_A", 0.75, 1.5),
        {"go": [-10.8, 1, -19.6]}, {"go": "M_Causeway_Mere"}, {"go": [-15, 1, -11.5]},
        {"go": [-24, 1, -18]}, {"go": [-34, 1, -27]}, {"go": [-44, 1, -36]}, {"go": [-53, 1, -43]},
        {"stage": "exit"},
        {"go": "M_Exit"},
]


def autoplay_route():
    out = []
    for step in ROUTE:
        if "_needs" in step:
            if step.get("_gate"):
                out.append({"stage": "waits_kit_" + step["_needs"]})
                break
            continue
        out.append(step)
    return out


def kit_text(s):
    return re.sub(r"\[([^\]]+)\]", r"*\1*", s)


def safe_ground():
    """CursedGround safe shapes keyed by node name: the same causeways, ramp, islands and plateau the
    terrain raises (layout.py), in the kit's level.json format."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import layout as LY
    out = {"Ground_" + key: [] for key in LY.HOLLOWS}

    # A little narrower than the raised top, so the last safe spot is never on a causeway's side slope.
    def path(pts, half):
        return {"path": [[round(x, 2), 0, round(z, 2)] for x, z in pts], "width": round(2 * half - 0.6, 2)}

    for name, cw in LY.CAUSEWAYS.items():
        out["Ground_" + (name if name in LY.HOLLOWS else "mere")].append(path(cw["pts"], cw["half"]))
    out["Ground_mere"].append(path(LY.KNOLL_RAMP, LY.KNOLL_RAMP_HALF))
    for key, ((x, z), r) in LY.ISLANDS.items():
        out["Ground_" + key].append({"circle": [x, 0, z], "radius": r})
    out["Ground_mere"].append({"circle": [LY.KNOLL_C[0], 0, LY.KNOLL_C[1]], "radius": LY.KNOLL_TOP_R})
    return out


def level_json():
    lines = {}
    for sc in SCENES:
        who = {"tamsin": None, "verse": None, "pell": "Pell"}.get(sc["speaker"], "")
        lines[sc["id"]] = [{"text": kit_text(ln)} if who is None else {"who": who, "text": kit_text(ln)} for ln in sc["lines"]]
    return {
        "spawn_facing": "M_Knoll",
        "complete_on_objectives": False,
        "objectives": OBJECTIVES,
        "lines": lines,
        "raft": {"talk": "pell_exit", "card": "Pell poles the raft north-west, under the trees of Mosswater Wood."},
        "end_text": "[font_size=34]The plain is on the map again.[/font_size]\n\nTamsin's three leaves are one sheet, the Mere runs green under the Knoll, and the brook carries Pell on towards Mosswater Wood.",
        "safe_ground": safe_ground(),
        "warps": WARPS,
        "autoplay": {"chain": [], "route": autoplay_route()},
    }


def main():
    level = ROOT / "scenes/levels/sedge_plain/level.json"
    level.parent.mkdir(parents=True, exist_ok=True)
    with open(level, "w", encoding="utf-8", newline="\n") as f:
        json.dump(level_json(), f, indent="\t", ensure_ascii=False)
        f.write("\n")
    data = {"level": "sedge_plain", "markup": "[word] = accent colour", "speakers": SPEAKERS, "scenes": SCENES,
            "prompts": PROMPTS, "bead": BEAD}
    out = ROOT / "scripts/levels/sedge_plain/sedge_script.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")
    write_md(ROOT / "docs/levels/sedge_plain/SCRIPT.md")
    print("SCRIPT %d scenes" % len(SCENES))


if __name__ == "__main__":
    main()
