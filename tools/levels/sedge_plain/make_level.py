"""Write the playable level scene, scenes/levels/sedge_plain/sedge_plain.tscn, from layout.py.

    python tools/levels/sedge_plain/make_level.py

Kit nodes only (docs/LEVEL_KIT.md): the Level root (scripts/levels/sedge_plain/sedge_plain.gd), the
terrain and dressing, Pell and Tamsin (Person), the four sealed fights with their EnemySpawns, the
three CursedZones (the Mere holds the sapling on the Knoll and the finale), CursedGround in each hollow
(safe shapes in level.json), the soot banks (GlyphObstacle, gust), three Tie post pairs (bridge),
two verse-stones, checkpoints, the map leaves (invisible Checkpoint triggers until the kit has a
pickup) and the LevelExit with Pell's raft on the brook pool. Node names are the ones level.json and
its autoplay route use. Owner: l3.
"""
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import layout as L  # noqa: E402
from make_scenes import xform, write  # noqa: E402

ROOT = HERE.parents[2]
OUT = ROOT / "scenes/levels/sedge_plain/sedge_plain.tscn"

INTRO = ("A wide plain of sedge and standing stones. The black has come up in the low places, "
         "and the wind took a mapmaker's map.\n\nFind her leaves, cross the Seam, and wake the sapling on the Knoll.")

# Sealed fights: node, marker, knot drift, waves of (kind, count).
FIGHTS = [
    ("Fight_Stones", "stones", "M_Fight_1", 1.5, [[("splotchet", 4)]]),
    ("Fight_East", "east", "M_Fight_2", 3.0, [[("splotchet", 3), ("reedwraith", 1)]]),
    ("Fight_West", "west", "M_Fight_3", 3.0, [[("splotchet", 3), ("reedwraith", 2)]]),
    ("Fight_Knoll", "knoll", "M_Fight_4", 1.0, [[("splotchet", 4), ("reedwraith", 1)], [("reedwraith", 2), ("splotchet", 2)]]),
]

# Soot banks on the causeways: node, marker, the marker it faces along the causeway.
SOOT = [
    ("Soot_East_1", "M_Soot_East_1", "M_Island_East"),
    ("Soot_East_2", "M_Soot_East_2", "M_Island_East"),
    ("Soot_West_1", "M_Soot_West_1", "M_Island_West"),
    ("Soot_West_2", "M_Soot_West_2", "M_Island_West"),
    ("Soot_Mere", "M_Soot_Mere", "M_Tie_Break_A"),
]

# What Tamsin says on the rim: the last flag set wins (Person.talk_by_flag).
TAMSIN_RIM_TALK = [("leaf_1", "tamsin_rim"), ("leaves_two", "tamsin_two_leaves"), ("leaves_all", "tamsin_map"), ("restored_mere", "tamsin_after")]

# Tie post pairs, in the order layout.props() places the tie_post models (two per pair).
TIES = ["Bridge_1", "Bridge_2", "Mere_Gap"]
BRIDGE_WIDTH = 3.4  # wide enough to walk past the 0.2 m posts that stand on the deck's ends
VERSES = [("Verse_1", "M_Verse_1", "tie"), ("Verse_2", "M_Verse_2", "")]
CHECKPOINTS = [("Checkpoint_Rim", "M_Tamsin_Rim"), ("Checkpoint_Mere", "M_Causeway_Mere")]

# Each soot bank stays until its flag is set: the pack that guards the causeway is beaten (so a
# Gust in that fight does not clear it early), or, in the Mere, Tamsin has read the map.
SOOT_NEEDS = {"Soot_East": "fight_east", "Soot_West": "fight_west", "Soot_Mere": "talked_tamsin_map"}

ZONES = [
    ("Zone_mere", "mere", "The Mere", "M_Hollow_Mere", "sapling", True),
    ("Zone_east", "east", "Kettle Hollow", "M_Hollow_East", "none", False),
    ("Zone_west", "west", "Ladle Hollow", "M_Hollow_West", "none", False),
]


def yaw_to(a, b):
    return math.degrees(math.atan2(-(b[0] - a[0]), -(b[2] - a[2])))


def vec(v):
    return "Vector3(%s)" % ", ".join("%g" % round(c, 3) for c in v)


def main():
    m = L.markers()
    ext = [
        ("Script", "res://scripts/levels/sedge_plain/sedge_plain.gd", "level"),
        ("Script", "res://scripts/game/kit/person.gd", "person"),
        ("Script", "res://scripts/game/glyph_obstacle.gd", "obstacle"),
        ("Script", "res://scripts/game/kit/sealed_fight.gd", "fight"),
        ("Script", "res://scripts/game/kit/enemy_spawn.gd", "spawn"),
        ("Script", "res://scripts/game/cursed_zone.gd", "zone"),
        ("PackedScene", "res://scenes/levels/sedge_plain/terrain.tscn", "terrain"),
        ("PackedScene", "res://scenes/levels/sedge_plain/dressing.tscn", "dressing"),
        ("PackedScene", "res://scenes/levels/sedge_plain/folk/tamsin.tscn", "tamsin"),
        ("PackedScene", "res://scenes/models/raft.tscn", "raft"),
        ("Script", "res://scripts/game/kit/tie_post.gd", "tie"),
        ("PackedScene", "res://scenes/game/kit/verse_stone.tscn", "verse"),
        ("PackedScene", "res://scenes/game/kit/cursed_ground.tscn", "ground"),
        ("PackedScene", "res://scenes/game/kit/checkpoint.tscn", "checkpoint"),
        ("PackedScene", "res://scenes/game/kit/level_exit.tscn", "exit"),
        ("PackedScene", "res://scenes/levels/sedge_plain/props/tie_post.tscn", "post"),
        ("PackedScene", "res://scenes/game/kit/pickup.tscn", "pickup"),
        ("PackedScene", "res://scenes/levels/sedge_plain/props/map_leaf.tscn", "leaf"),
    ]
    out = ["[gd_scene load_steps=%d format=3]" % (len(ext) + 1), ""]
    out += ['[ext_resource type="%s" path="%s" id="%s"]' % e for e in ext]
    out += ["", '[node name="SedgePlain" type="Node3D"]', 'script = ExtResource("level")', 'level_id = &"sedge_plain"',
            'display_name = "Sedge Plain"', 'chapter = "The Mapmaker\'s Road"', 'intro_text = "%s"' % INTRO,
            'title_marker = "M_Knoll"', ""]
    out += ['[node name="Terrain" parent="." groups=["level_ground"] instance=ExtResource("terrain")]', ""]
    out += ['[node name="Dressing" parent="." instance=ExtResource("dressing")]', ""]

    jetty = (4.5, m["M_Landing"][1], 63.6)
    out += ['[node name="Pell" type="Node3D" parent="."]', "transform = %s" % xform(*jetty, yaw=180.0),
            'script = ExtResource("person")', 'display_name = "Pell"', 'talk_id = "pell_arrival"', 'model_name = "folk/pell"', ""]
    raft_in = (6.7, L.WATER_Y, 63.6)
    out += ['[node name="Raft_Landing" parent="." instance=ExtResource("raft")]', "transform = %s" % xform(*raft_in), ""]
    ex, exr = m["M_Exit"], m["M_Exit_Raft"]
    d = math.hypot(ex[0] - exr[0], ex[2] - exr[2])
    t = 3.4 / d
    at = (exr[0] + (ex[0] - exr[0]) * t, L.WATER_Y, exr[2] + (ex[2] - exr[2]) * t)
    out += ['[node name="LevelExit" parent="." instance=ExtResource("exit")]', "transform = %s" % xform(*at, yaw=yaw_to(at, ex) + 90.0),
            "radius = %g" % round(d - 3.4 + 2.0, 2), 'requires_flags = PackedStringArray("restored_mere")', ""]

    # Tamsin twice: at her camp until the first bridge is tied, then on the Mere's rim, where what she
    # says follows the leaves (leaves_two and leaves_all are set by the level script).
    camp, rim = m["M_Tamsin_Camp"], m["M_Tamsin_Rim"]
    out += ['[node name="Tamsin" type="Node3D" parent="."]', "transform = %s" % xform(*camp, yaw=yaw_to(camp, (-2.5, 0.0, 44.5)) + 180.0),
            'script = ExtResource("person")', 'display_name = "Tamsin"', 'talk_id = "tamsin_meet"', 'model_scene = ExtResource("tamsin")',
            'hide_flag = &"tied_bridge_1"', ""]
    talk_by = ", ".join('"%s": "%s"' % kv for kv in TAMSIN_RIM_TALK)
    out += ['[node name="Tamsin_Rim" type="Node3D" parent="."]', "transform = %s" % xform(*rim, yaw=yaw_to(rim, m["M_Leaf_1"]) + 180.0),
            'script = ExtResource("person")', 'display_name = "Tamsin"', 'talk_id = "tamsin_rim_early"', 'model_scene = ExtResource("tamsin")',
            'show_flag = &"tied_bridge_1"', "talk_by_flag = {%s}" % talk_by, ""]

    for node, fid, mk, drift, waves in FIGHTS:
        c = m[mk]
        out += ['[node name="%s" type="Node3D" parent="."]' % node, "transform = %s" % xform(*c), 'script = ExtResource("fight")',
                'fight_id = &"%s"' % fid, "knot_drift = %g" % drift, ""]
        k = 0
        total = sum(n for wave in waves for _, n in wave)
        for w, wave in enumerate(waves):
            for kind, n in wave:
                for _ in range(n):
                    a = 2 * math.pi * k / total + 0.4
                    out += ['[node name="Spawn%d" type="Marker3D" parent="%s"]' % (k + 1, node),
                            "transform = %s" % xform(round(2.6 * math.cos(a), 2), 0.0, round(2.6 * math.sin(a), 2)),
                            'script = ExtResource("spawn")', 'kind = &"%s"' % kind]
                    if w:
                        out.append("wave = %d" % w)
                    out.append("")
                    k += 1

    for node, zid, name, mk, kind, finale in ZONES:
        h = L.HOLLOWS[zid]
        c = m[mk]
        lines = ['[node name="%s" type="Node3D" parent="."]' % node, "transform = %s" % xform(*c), 'script = ExtResource("zone")',
                 'zone_id = &"%s"' % zid, 'display_name = "%s"' % name, "radius = %g" % h["zone_r"], 'target_kind = "%s"' % kind]
        if kind == "sapling":
            s = m["M_Sapling"]
            lines.append("target_offset = %s" % vec((s[0] - c[0], s[1] - c[1], s[2] - c[2])))
        if finale:
            lines.append("finale = true")
        out += lines + [""]

    posts = [p for p in L.props() if p[0] == "tie_post"]
    for k, node in enumerate(TIES):
        a, b = posts[2 * k], posts[2 * k + 1]
        out += ['[node name="%s" type="Node3D" parent="."]' % node, ""]
        for post, p in (("PostA", a), ("PostB", b)):
            out += ['[node name="%s" type="StaticBody3D" parent="%s"]' % (post, node), "transform = %s" % xform(p[1], p[2], p[3], p[4]),
                    'script = ExtResource("tie")', 'model_scene = ExtResource("post")']
            if post == "PostA":
                out += ['partner = NodePath("../PostB")', 'action = "bridge"', "bridge_width = %g" % BRIDGE_WIDTH]
            out.append("")

    for node, mk, teaches in VERSES:
        v = m[mk]
        out += ['[node name="%s" parent="." instance=ExtResource("verse")]' % node, "transform = %s" % xform(*v, yaw=yaw_to(v, m["M_Bridge1_S"] if teaches else m["M_Sapling"]))]
        if teaches:
            out.append('teaches = &"%s"' % teaches)
        out.append("")

    for key, h in L.HOLLOWS.items():
        c = m["M_Hollow_" + key.capitalize()]
        out += ['[node name="Ground_%s" parent="." instance=ExtResource("ground")]' % key, "transform = %s" % xform(*c),
                "radius = %g" % h["zone_r"], 'clear_flag = &"restored_%s"' % key, "max_height = 2.4", "draw_curse = false", "show_safe = false", ""]

    for node, mk in CHECKPOINTS:
        out += ['[node name="%s" parent="." instance=ExtResource("checkpoint")]' % node, "transform = %s" % xform(*m[mk]), ""]
    for k in (1, 2, 3):
        out += ['[node name="Leaf_%d" parent="." instance=ExtResource("pickup")]' % k, "transform = %s" % xform(*m["M_Leaf_%d" % k]),
                'flag = &"leaf_%d"' % k, 'model_scene = ExtResource("leaf")', "radius = 1.4", ""]

    for node, mk, toward in SOOT:
        a = m[mk]
        out += ['[node name="%s" type="StaticBody3D" parent="."]' % node, "transform = %s" % xform(*a, yaw=yaw_to(a, m[toward])),
                'script = ExtResource("obstacle")', 'glyph = &"gust"', "width = 4.2", "height = 2.4",
                'cleared_flag = &"%s"' % node.lower(), 'hint_id = &"sedge_soot"',
                'hint_text = "Soot buries the road. A %s will clear it."']
        out.append('requires_flags = PackedStringArray("%s")' % SOOT_NEEDS[node.rsplit("_", 1)[0] if node != "Soot_Mere" else node])
        out.append("")

    write(OUT, "\n".join(out))
    print("LEVEL %s" % OUT.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
