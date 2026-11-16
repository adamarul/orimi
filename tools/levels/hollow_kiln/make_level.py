"""Write scenes/levels/hollow_kiln/hollow_kiln.tscn, the playable level, from kiln_layout.py and the
kit (docs/LEVEL_KIT.md): the set without the props the kit drives, the markers, Pell and Wenna,
four verse-stones, the cord gate (GlyphObstacle slash) and its braziers (KindleTarget), the yard's
sealed fight, the soot drifts on the hall's planks (GlyphObstacle gust), the hall's cursed floor
(CursedGround, planks as safe ground in level.json), the hall ambush, the counterweight tie
(TiePost bind), the flue's rising ink (RisingHazard) and lamps, checkpoints, the Dregs (an EnemySpawn of
scenes/levels/hollow_kiln/dregs_enemy.tscn), the pillar rings (TiePost bind), the three kiln
mouths (KindleTarget), the four cursed zones and the vat (the finale). Parts the kit does not have
yet (a Bloom target that grows a foothold, a Gust target that clears other objects) are left out;
their markers and models are in place (DESIGN.md, "Nodes phase B places").

    python tools/levels/hollow_kiln/make_level.py
"""
import math
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kiln_layout as K  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "scenes", "levels", "hollow_kiln", "hollow_kiln.tscn")
INTRO = ("The Ink-maker's works stand at the river's head, under a kiln with a round hat.\n\n"
         "All the black came down from here. Climb to the vat.")

EXT = [
    ("Script", "res://scripts/levels/hollow_kiln/hollow_kiln.gd", "level"),
    ("Script", "res://scripts/game/kit/person.gd", "person"),
    ("Script", "res://scripts/game/glyph_obstacle.gd", "obstacle"),
    ("Script", "res://scripts/game/kit/sealed_fight.gd", "fight"),
    ("Script", "res://scripts/game/kit/enemy_spawn.gd", "spawn"),
    ("Script", "res://scripts/game/cursed_zone.gd", "zone"),
    ("Script", "res://scripts/game/kit/verse_stone.gd", "verse"),
    ("Script", "res://scripts/game/kit/kindle_target.gd", "kindle"),
    ("Script", "res://scripts/game/kit/tie_post.gd", "tie"),
    ("Script", "res://scripts/game/kit/checkpoint.gd", "checkpoint"),
    ("Script", "res://scripts/game/kit/cursed_ground.gd", "ground"),
    ("Script", "res://scripts/levels/hollow_kiln/vat_bloom.gd", "vat_bloom"),
    ("Script", "res://scripts/game/kit/glyph_target.gd", "target"),
    ("Script", "res://scripts/game/kit/camera_zone.gd", "camzone"),
    ("PackedScene", "res://scenes/game/kit/rising_hazard.tscn", "rising"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/models/bellows.tscn", "bellows"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/models/moss_foothold.tscn", "moss"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/kit/brazier_kindle.tscn", "brazier_look"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/kit/lamp_kindle.tscn", "lamp_look"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/kit/mouth_kindle.tscn", "mouth_look"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/kit/counterweight_ring.tscn", "weight_ring"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/models/tie_post.tscn", "tie_post"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/models/pillar_ring.tscn", "pillar_ring"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/dregs_enemy.tscn", "dregs"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/kiln_set_level.tscn", "set"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/kiln_markers.tscn", "markers"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/cord_gate_obstacle.tscn", "gate"),
    ("PackedScene", "res://scenes/levels/hollow_kiln/folk/wenna.tscn", "wenna"),
]


def moss_ramps():
    """Each bloomed moss foothold is a mossy ramp along its wall, as wide as the flue ledges (3 m):
    M1 bridges the gap from ledge A1's top to A2's foot, M2 and M3 climb from C1's top to C2's foot
    (kiln_layout.FLUE_LEDGES). Returns name: ((y, z) start, (y, z) end); the ramps run along z."""
    led = {n: (zr, y0, y1, sg) for n, xr, zr, y0, y1, ax, sg in K.FLUE_LEDGES}

    def end(n):
        zr, y0, y1, sg = led[n]
        return (y1, min(zr) if sg < 0 else max(zr))

    def foot(n):
        zr, y0, y1, sg = led[n]
        return (y0, max(zr) if sg < 0 else min(zr))
    c1, c2 = end("C1"), foot("C2")
    mid = ((c1[0] + c2[0]) / 2, (c1[1] + c2[1]) / 2)
    return {"M1": (end("A1"), foot("A2")), "M2": (c1, mid), "M3": (mid, c2)}


def v3(p):
    return "Vector3(%.3f, %.3f, %.3f)" % tuple(p)


def node(lines, name, kind, parent, ext=None, pos=None, yaw=0.0, props=(), groups=None, instance=None):
    head = '[node name="%s"' % name
    if instance:
        head += ' parent="%s" instance=ExtResource("%s")' % (parent, instance)
    else:
        head += ' type="%s"' % kind
        if parent is not None:
            head += ' parent="%s"' % parent
    if groups:
        head += " groups=[%s]" % ", ".join('"%s"' % g for g in groups)
    lines.append(head + "]")
    if pos is not None:
        lines.append("position = " + v3(pos))
    if yaw:
        lines.append("rotation = Vector3(0, %.6f, 0)" % math.radians(yaw))
    if ext:
        lines.append('script = ExtResource("%s")' % ext)
    lines += list(props)
    lines.append("")


def s(text):
    return '"%s"' % text.replace('"', '\\"')


def main():
    L = ['[gd_scene format=3]', ""]
    for kind, path, i in EXT:
        L.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, i))
    L.append("")
    for name, (lo, hi) in moss_ramps().items():
        L += ['[sub_resource type="BoxShape3D" id="ledge_%s"]' % name, "size = Vector3(3.0, 0.4, %.3f)" % (math.dist(lo, hi) + 0.6), ""]
    node(L, "HollowKiln", "Node3D", None, ext="level", props=[
        'level_id = &"hollow_kiln"', 'display_name = "The Hollow Kiln"', 'chapter = "What the Vat Kept"',
        "intro_text = " + s(INTRO), "start_gloom = 1.0"])
    node(L, "Set", None, ".", instance="set", groups=["level_ground"])
    node(L, "Markers", None, ".", instance="markers")

    # people
    pell = K.PEOPLE["Pell"]
    node(L, "Pell", "Node3D", ".", ext="person", pos=pell["at"], yaw=pell["yaw"],
         props=['display_name = "Pell"', 'talk_id = "pell"', 'model_name = "folk/pell"', 'hide_flag = &"vat_bloomed"'])
    node(L, "PellEnd", "Node3D", ".", ext="person", pos=K.MARKERS["M_Pell_End"], yaw=180.0,
         props=['display_name = "Pell"', 'talk_id = "ending"', 'model_name = "folk/pell"', 'show_flag = &"vat_bloomed"'])
    wenna = K.PEOPLE["Wenna"]
    node(L, "Wenna", "Node3D", ".", ext="person", pos=wenna["at"], yaw=wenna["yaw"],
         props=['display_name = "Wenna"', 'talk_id = "wenna"', 'model_scene = ExtResource("wenna")', "faded = true",
                'wake_flag = &"restored_yard"'])

    # the gate (Slash); the braziers wait for the kit's Kindle targets
    node(L, "CordGate", "StaticBody3D", ".", ext="obstacle", pos=(0.0, K.Y_YARD, K.GATE["z"]),
         props=['glyph = &"slash"', "width = 6.0", "height = 4.6", 'model_scene = ExtResource("gate")', 'cleared_flag = &"gate_cut"',
                'hint_id = &"kiln_gate"', 'hint_text = "The gate is tied with ink. Cut straight across the cord: %s."'])

    # sealed fights
    for fid, name, extra in (("yard", "YardFight", ['requires_flags = PackedStringArray("gate_cut")']),
                             ("hall_ambush", "HallAmbush", ['start_flag = &"bellows_2_blown"', 'requires_flags = PackedStringArray("hall_entered")'])):
        f = K.FIGHTS[fid]
        radius = f["radius"] if f["radius"] > 0 else 4.0
        node(L, name, "Node3D", ".", ext="fight", pos=f["centre"], props=['fight_id = &"%s"' % fid, "radius = %.1f" % radius] + extra)
        k = 0
        for w, wave in enumerate(f["waves"]):
            for kind, off in wave:
                node(L, "Spawn%d" % k, "Marker3D", name, ext="spawn", pos=off, props=['kind = &"%s"' % kind, "wave = %d" % w])
                k += 1

    # the hall: soot drifts across the plank aisles, too deep for a Gust; each bellows (GlyphTarget, Gust) blows three off.
    # The brush reaches 60 m through walls, so the bellows and the ambush wait until Orimi has been in the hall.
    bellows = [p for p in K.PROPS if p[0] == "bellows"]
    for n, (m, x, y, z, yaw) in enumerate(bellows, 1):
        drifts = ["D1", "D2", "D3"] if n == 1 else ["D4", "D5", "D6"]
        node(L, "Bellows_%d" % n, "StaticBody3D", ".", ext="target", pos=(x, y, z), yaw=yaw,
             props=['glyphs = PackedStringArray("gust")', 'flag = &"bellows_%d_blown"' % n, 'model_scene = ExtResource("bellows")',
                    "clears = Array[NodePath]([%s])" % ", ".join('NodePath("../SootDrift_%s")' % d for d in drifts),
                    "size = Vector3(1.6, 1.2, 1.6)", "solid = true", 'hint_text = "The bellows are cold and heavy. %s into them."',
                    'requires_flags = PackedStringArray("hall_entered")', 'refuse_hint = &""'])
    for dname, (x, z, w) in K.SOOT_DRIFTS.items():
        n = 1 if dname in ("D1", "D2", "D3") else 2
        node(L, "SootDrift_" + dname, "StaticBody3D", ".", ext="obstacle", pos=(x, K.Y_PLANK, z), yaw=90.0,
             props=['glyph = &"gust"', "width = 3.2", "height = 1.8", 'cleared_flag = &"drift_%s"' % dname.lower(),
                    'requires_flags = PackedStringArray("bellows_%d_blown")' % n, 'refuse_hint = &""',
                    'hint_text = "Packed soot, too deep for a breath of %s. Something here was built to blow."'])

    # the flue: moss on the walls (GlyphTarget, Bloom) grows into a foothold; hollow_kiln.gd turns its Ledge solid
    for name, (x, y, z) in K.MOSS.items():
        mpath = "MossFoothold_" + name
        node(L, mpath, "StaticBody3D", ".", ext="target", pos=(x, y, z), yaw=K.wall_yaw(x, z),
             props=['glyphs = PackedStringArray("bloom")', 'flag = &"moss_%s"' % name.lower(), 'model_scene = ExtResource("moss")',
                    "size = Vector3(2.0, 1.0, 1.0)"])
        (y0, z0), (y1, z1) = moss_ramps()[name]
        tilt = math.atan((y1 - y0) / (z0 - z1))
        cx = -0.5 if x > K.FLUE["x"][1] - 0.01 else K.FLUE["x"][0] + 1.5
        cy, cz = (y0 + y1) / 2 - 0.2 * math.cos(tilt), (z0 + z1) / 2 - 0.2 * math.sin(tilt)
        node(L, "MossLedge_" + name, "StaticBody3D", ".", pos=(cx, cy, cz), props=["rotation = Vector3(%.6f, 0, 0)" % tilt, "collision_layer = 0", "collision_mask = 0"])
        node(L, "Shape", "CollisionShape3D", "MossLedge_" + name, props=['shape = SubResource("ledge_%s")' % name])

    # the indoor camera: looking up the flue; in the vat chamber behind Orimi, wide and tilted up so the Dregs' head
    # (5.9 m over the vat rim) stays in the picture; ArenaDoorCam at the door turns her to the vat from low in the passage
    # for the first sight of it whole; TieCam looks north and higher across the vat at both pillar rings while the
    # Dregs climbs (hollow_kiln.gd turns VatCam and TieCam on and off)
    fx, fz = K.FLUE["x"], K.FLUE["z"]
    node(L, "FlueCam", "Node3D", ".", ext="camzone", pos=((fx[0] + fx[1]) / 2, (K.FLUE["base"] + K.FLUE["roof"]) / 2, (fz[0] + fz[1]) / 2),
         props=["size = Vector3(%.1f, %.1f, %.1f)" % (fx[1] - fx[0], K.FLUE["roof"] - K.FLUE["base"], fz[1] - fz[0]),
                'mode = "follow"', "priority = 1", "distance = 3.6", "lock_pitch = true", "pitch_deg = 15.0"])
    cx, cy, cz = K.DRUM_C
    node(L, "VatCam", "Node3D", ".", ext="camzone", pos=(cx, cy + 6.0, cz),
         props=["size = Vector3(%.1f, 14.0, %.1f)" % (2 * K.DRUM_R + 2, 2 * K.DRUM_R + 2), 'mode = "follow"', "priority = 1",
                "distance = 4.5", "pivot_raise = 1.0", "fov = 80.0", "lock_pitch = true", "pitch_deg = 4.0"])
    node(L, "TieCam", "Node3D", ".", ext="camzone", pos=(cx, cy + 6.0, cz),
         props=["size = Vector3(%.1f, 14.0, %.1f)" % (2 * K.DRUM_R + 2, 2 * K.DRUM_R + 2), 'mode = "follow"', "priority = 2",
                "distance = 4.5", "pivot_raise = 1.0", "fov = 90.0", "lock_yaw = true", "yaw_deg = 0.0", "lock_pitch = true", "pitch_deg = 22.0"])
    ex, _ey, ez = K.MARKERS["M_Arena_Entry"]
    vx, vz = K.VAT["c"]
    node(L, "ArenaDoorCam", "Node3D", ".", ext="camzone", pos=(ex, K.Y_VAT + 2.0, ez + 1.25),
         props=["size = Vector3(3.6, 6.0, 4.5)", 'mode = "follow"', "priority = 3", "distance = 3.0", "pivot_raise = 0.8", "fov = 80.0",
                "lock_yaw = true", "yaw_deg = %.1f" % math.degrees(math.atan2(-(vx - ex), -(vz - ez))), "lock_pitch = true", "pitch_deg = 8.0"])

    # verse-stones; the fourth comes up with the tree's roots (hollow_kiln.gd shows it)
    for n in range(1, 5):
        node(L, "VerseStone_%d" % n, "StaticBody3D", ".", ext="verse", pos=K.MARKERS["M_Verse_%d" % n], yaw=180.0 if n == 4 else 0.0,
             props=['talk_id = "verse_%d"' % n, 'read_flag = &"verse_%d_read"' % n])

    # Kindle: the gate's braziers, the flue's lamps, the kiln mouths
    for side in ("W", "E"):
        node(L, "Brazier_" + side, "StaticBody3D", ".", ext="kindle", pos=K.MARKERS["M_Brazier_" + side],
             props=['kind = "brazier"', 'lit_flag = &"brazier_%s_lit"' % side.lower(), 'model_scene = ExtResource("brazier_look")'])
    for name, (x, y, z) in K.FLUE_LAMPS.items():
        node(L, "WallLamp_" + name, "StaticBody3D", ".", ext="kindle", pos=(x, y, z), yaw=K.wall_yaw(x, z),
             props=['lit_flag = &"lamp_%s"' % name.lower(), 'model_scene = ExtResource("lamp_look")', "light_range = 9.0"])
    for name, (x, y, z, yaw) in K.KILN_FIRES.items():
        node(L, "KilnMouth_" + name, "StaticBody3D", ".", ext="kindle", pos=(x, y, z), yaw=yaw,
             props=['lit_flag = &"mouth_%s_lit"' % name.lower(), 'model_scene = ExtResource("mouth_look")', 'requires_flags = PackedStringArray("dregs_bound")',
                    "light_range = 10.0", "light_energy = 2.2"])

    # Tie: the counterweight (the level script lifts the door), the pillar rings (the Dregs listens)
    tx, ty, tz = K.MARKERS["M_TieAnchor"]
    node(L, "TiePost", "StaticBody3D", ".", ext="tie", pos=(tx, ty, tz),
         props=['partner = NodePath("../CounterweightRing")', 'action = "bind"', 'tied_flag = &"counterweight_tied"',
                'requires_flags = PackedStringArray("restored_hall")', 'model_scene = ExtResource("tie_post")'])
    node(L, "CounterweightRing", "StaticBody3D", ".", ext="tie", pos=K.MARKERS["M_TieWeight"], props=['model_scene = ExtResource("weight_ring")'])
    rings = [p for p in K.PROPS if p[0] == "pillar_ring"]
    for (m, x, y, z, yaw), side in zip(rings, ("W", "E")):
        props = ['model_scene = ExtResource("pillar_ring")']
        if side == "W":
            props = ['partner = NodePath("../PillarRing_E")', 'action = "bind"', 'tied_flag = &"dregs_bound"', "sag = 0.15",
                     'requires_flags = PackedStringArray("dregs_arms_cut")'] + props
        node(L, "PillarRing_" + side, "StaticBody3D", ".", ext="tie", pos=(x, y, z), yaw=yaw, props=props)

    # ground that keeps you out: the hall floor between the planks, the ink at the bottom of the flue
    node(L, "HallFloor", "Node3D", ".", ext="ground", pos=(0.0, K.Y_HALL, -13.0),
         props=["radius = 21.0", 'clear_flag = &"restored_hall"', "max_height = 2.0", "draw_curse = false", "show_safe = false"])
    fx, fz = K.FLUE["x"], K.FLUE["z"]
    # the flue's ink rises once the first lamp is lit, until the top checkpoint; the set's InkPool follows it (hollow_kiln.gd)
    node(L, "FlueRise", None, ".", instance="rising", pos=((fx[0] + fx[1]) / 2, K.FLUE["ink0"], (fz[0] + fz[1]) / 2),
         props=["size = Vector2(%.1f, %.1f)" % (fx[1] - fx[0], fz[1] - fz[0]), "top_height = %.2f" % (K.FLUE["ink_max"] - K.FLUE["ink0"]),
                "rise_speed = %.2f" % K.FLUE["ink_rate"], 'start_flag = &"lamp_k1"', "start_on_enter = false", 'stop_flag = &"flue_climbed"',
                'flag = &"flue_lifted"', "show_surface = false"])

    # checkpoints: the top of the flue, the arena door (it also wakes the Dregs)
    node(L, "FlueTop", "Node3D", ".", ext="checkpoint", pos=K.MARKERS["M_FlueTop"], props=['flag = &"flue_climbed"', "show_model = false"])
    node(L, "ArenaEntry", "Node3D", ".", ext="checkpoint", pos=K.MARKERS["M_Arena_Entry"], props=['flag = &"dregs_started"', "show_model = false", "radius = 2.5"])

    # cursed zones (kiln_layout.CURSE_ZONES): the yard and hall restore with a sapling, the flue and the vat at the finale
    zones = {0: ("yard", "The Kiln Yard", "sapling", (4.0, 0.0, -5.0), ["fight_yard"]),
             1: ("hall", "The Drying Hall", "sapling", (-11.0, 0.3, -7.6), ["fight_hall_ambush"]),
             2: ("flue", "The Flue", "none", (0, 0, 0), []),
             3: ("vat", "The Vat Chamber", "none", (0, 0, 0), ["dregs_unravelled"])}
    for slot, centre, radius in K.CURSE_ZONES:
        zid, title, target, off, req = zones[slot]
        props = ['zone_id = &"%s"' % zid, 'display_name = "%s"' % title, "radius = %.1f" % radius, 'target_kind = "%s"' % target]
        if target != "none":
            props.append("target_offset = " + v3(off))
        if req:
            props.append("requires_flags = PackedStringArray(%s)" % ", ".join('"%s"' % r for r in req))
        if zid == "vat":
            props.append("finale = true")
        node(L, "Zone_" + zid, "Node3D", ".", ext="zone", pos=centre, props=props)
    # the vat: the finale's Bloom target, and the Dregs on its rim
    vx, vz = K.VAT["c"]
    zc = K.CURSE_ZONES[3][1]
    node(L, "CrackedVat", "StaticBody3D", "Zone_vat", ext="vat_bloom", pos=(vx - zc[0], K.Y_VAT - zc[1], vz - zc[2]))
    dx, dy, dz = K.DREGS["at"]
    node(L, "DregsSpawn", "Marker3D", "Zone_vat", ext="spawn", pos=(dx - zc[0], dy + 0.5 - zc[1], dz - zc[2]), yaw=180.0,
         props=['enemy_scene = ExtResource("dregs")'])

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))
    print("LEVEL SCENE", os.path.relpath(OUT, ROOT).replace(os.sep, "/"))


if __name__ == "__main__":
    main()
