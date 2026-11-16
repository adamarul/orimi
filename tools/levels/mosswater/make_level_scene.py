"""Write scenes/levels/mosswater/mosswater.tscn, the playable level, from the layout data.

    python tools/levels/mosswater/make_level_scene.py

The scene holds the markers and every kit node (docs/LEVEL_KIT.md) at the places mw_layout.py
gives; the ground, water, trees and props are built in code by scripts/levels/mosswater/
mosswater.gd from the same data. Each pond is the kit's DeepWater, a box over the ellipse's axes
whose corners lie on the dry bank: Orimi who steps off the bank, the island, the log or an open
lily pad is put back where she left. Run it again after any change to mw_layout.py.
"""
import json
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
LAYOUT = ROOT / "scripts/levels/mosswater/mosswater_layout.json"
SCENE = ROOT / "scenes/levels/mosswater/mosswater.tscn"
DATA = ROOT / "scenes/levels/mosswater/level.json"

S_UP = (-math.sqrt(0.5), -math.sqrt(0.5))   # (x, z) of the up-slope axis
T_AC = (math.sqrt(0.5), -math.sqrt(0.5))    # (x, z) of the across axis
POND_NODES = {"low": "PondLow", "mid": "PondMid", "high": "PondHigh"}
INK_NODES = {"low": "InkLow", "mid": "InkMid", "high": "InkHigh"}
FINALE_CAM_AT = [-24.0, 13.0, -32.0]    # centre of the finale CameraZone's box
FINALE_VIEW = [-9.5, 17.5, -19.5]       # where its fixed camera stands: over the dam crest
# Follow-camera overrides where the camera would otherwise be pushed into rock or bark: under the
# moss shelves and the first ledge at the gully foot and against the parapet bank on the dam crest
# (both look north-west at the wall from the open side), and against the stair tree's trunk on its
# top shelves (from the bank top to the north, the trunk beyond Orimi). name: centre, size, pitch, distance, yaw
CAMERA_ZONES = {
    "GullyCam": ([-16.5, 10.0, -1.5], (9, 7, 10), -22.0, 5.0, 45.0),
    "DamCam": ([-8.98, 13.5, -18.17], (10, 5, 10), -30.0, 6.5, 45.0),
    "StairCam": ([-0.3, 7.6, 9.4], (4, 3, 3.5), -25.0, 5.0, 180.0),
}
# The island Sootflits harass Orimi on the lily pads and the island only: within this distance of
# their markers (Lily_1 is 8.5 m from the nearer one; the stair tree's top, 9.8 m, is outside, so a
# dive cannot knock her back off the bank onto the shelves).
ISLAND_TERRITORY = 9.0
WATER_SINK = 0.1        # feet this far under the surface count as in the water; the kit counts feet up to 0.05 m over it as in at sink 0, and the open pads and Lily Reach's north-west shore sit 0.05 m over it
WATER_BANK_HEIGHT = 0.03  # ground inside the box this far over the surface is bank: the island (0.17 m) and an open pad (0.05 m)

EXT = {
    "level": ("Script", "res://scripts/levels/mosswater/mosswater.gd"),
    "person": ("PackedScene", "res://scenes/game/kit/person.tscn"),
    "fenn": ("PackedScene", "res://scenes/levels/mosswater/folk/fenn.tscn"),
    "verse": ("PackedScene", "res://scenes/game/kit/verse_stone.tscn"),
    "lantern": ("PackedScene", "res://scenes/game/kit/lantern_fruit.tscn"),
    "lantern_model": ("PackedScene", "res://scenes/levels/mosswater/models/mw_lantern_fruit.tscn"),
    "brazier": ("PackedScene", "res://scenes/game/kit/brazier.tscn"),
    "brazier_model": ("PackedScene", "res://scenes/levels/mosswater/models/mw_brazier.tscn"),
    "sealed": ("Script", "res://scripts/game/kit/sealed_fight.gd"),
    "spawn": ("Script", "res://scripts/game/kit/enemy_spawn.gd"),
    "sootflit": ("PackedScene", "res://scenes/levels/mosswater/enemies/sootflit.tscn"),
    "soot_bank": ("PackedScene", "res://scenes/game/kit/soot_bank.tscn"),
    "thorn_gate": ("PackedScene", "res://scenes/game/kit/thorn_gate.tscn"),
    "tie": ("Script", "res://scripts/game/kit/tie_post.gd"),
    "deep_water": ("Script", "res://scripts/game/kit/deep_water.gd"),
    "pond_ink": ("Script", "res://scripts/levels/mosswater/mw_pond_ink.gd"),
    "camera_zone": ("Script", "res://scripts/game/kit/camera_zone.gd"),
    "zone": ("Script", "res://scripts/game/cursed_zone.gd"),
    "bloom": ("Script", "res://scripts/game/bloom_target.gd"),
    "checkpoint": ("PackedScene", "res://scenes/game/kit/checkpoint.tscn"),
    "exit": ("PackedScene", "res://scenes/game/kit/level_exit.tscn"),
    "glyph_target": ("Script", "res://scripts/game/kit/glyph_target.gd"),
    "lily_model": ("PackedScene", "res://scenes/levels/mosswater/models/mw_lily.tscn"),
}
IDS = {k: str(i + 1) for i, k in enumerate(EXT)}


def xz(v):
    return (v[0], v[2])


def to_st(c, p):
    dx, dz = p[0] - c[0], p[1] - c[1]
    return (dx * S_UP[0] + dz * S_UP[1], dx * T_AC[0] + dz * T_AC[1])


def from_st(c, s, t):
    return (c[0] + s * S_UP[0] + t * T_AC[0], c[1] + s * S_UP[1] + t * T_AC[1])


def num(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else str(int(v))


def xform(pos, yaw_deg=0.0):
    c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    # A .tscn Transform3D lists the basis by rows.
    vals = (c, 0, s, 0, 1, 0, -s, 0, c, pos[0], pos[1], pos[2])
    return "Transform3D(%s)" % ", ".join(num(round(v, 4)) for v in vals)


def xform_yaw_pitch(pos, yaw_deg, pitch_deg):
    cy, sy = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
    cp, sp = math.cos(math.radians(pitch_deg)), math.sin(math.radians(pitch_deg))
    # Basis = Ry(yaw) * Rx(pitch), written by rows as a .tscn Transform3D lists it.
    vals = (cy, sy * sp, sy * cp, 0, cp, -sp, -sy, cy * sp, cy * cp) + tuple(pos)
    return "Transform3D(%s)" % ", ".join(num(round(v, 4)) for v in vals)


def yaw_toward(a, b):
    return math.degrees(math.atan2(-(b[0] - a[0]), -(b[2] - a[2])))


def gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(v)
    if isinstance(v, list):
        return "PackedStringArray(%s)" % ", ".join(json.dumps(x) for x in v)
    if isinstance(v, tuple) and v[0] == "ext":
        return 'ExtResource("%s")' % IDS[v[1]]
    if isinstance(v, tuple) and v[0] == "path":
        return 'NodePath("%s")' % v[1]
    if isinstance(v, tuple) and v[0] == "v3":
        return "Vector3(%s)" % ", ".join(num(round(x, 4)) for x in v[1:])
    if isinstance(v, tuple) and v[0] == "sn":
        return '&"%s"' % v[1]
    return json.dumps(v)


class Scene:
    def __init__(self):
        self.nodes = []

    def node(self, name, parent=".", type_=None, instance=None, transform=None, **props):
        head = '[node name="%s"' % name
        if type_:
            head += ' type="%s"' % type_
        if parent is not None:
            head += ' parent="%s"' % parent
        if instance:
            head += ' instance=ExtResource("%s")' % IDS[instance]
        lines = [head + "]"]
        if transform:
            lines.append("transform = " + transform)
        for k, v in props.items():
            lines.append("%s = %s" % (k, gd(v)))
        self.nodes.append("\n".join(lines))

    def text(self, used):
        out = ['[gd_scene load_steps=%d format=3]' % (len(used) + 1), ""]
        for k in EXT:
            if k in used:
                out.append('[ext_resource type="%s" path="%s" id="%s"]' % (EXT[k][0], EXT[k][1], IDS[k]))
        out.append("")
        return "\n".join(out) + "\n" + "\n\n".join(self.nodes) + "\n"


def main():
    d = json.loads(LAYOUT.read_text())
    m = d["markers"]
    sc = Scene()
    used = set(["level"])
    sc.node("Mosswater", parent=None, type_="Node3D", script=("ext", "level"), level_id=("sn", "mosswater"),
            display_name="Mosswater Wood", chapter="The Three Still Ponds",
            intro_text="Old forest on a slope, and a stream that falls through three ponds. The ponds have gone black and still, and under the canopy it is nearly dark.",
            title_marker="M_PondMid")

    sc.node("Markers", type_="Node3D")
    for k, v in m.items():
        sc.node(k, parent="Markers", type_="Marker3D", transform=xform(v))

    # --- people and verse-stones -------------------------------------------------------------
    used |= {"person", "fenn", "verse"}
    sc.node("People", type_="Node3D")
    landing = [(m["M_Spawn"][i] * 0.55 + m["M_Raft"][i] * 0.45) for i in range(3)]
    sc.node("Pell", parent="People", instance="person", transform=xform(landing, yaw_toward(landing, m["M_Spawn"])),
            display_name="Pell", talk_id="pell", model_name="folk/pell")
    sc.node("Fenn", parent="People", instance="person", transform=xform(m["M_Fenn_1"], yaw_toward(m["M_Fenn_1"], m["M_DarkHollow"])),
            display_name="Fenn", talk_id="fenn", model_scene=("ext", "fenn"),
            hide_flag=("sn", "reached_cp_stair_top"), bark_on_flag={"wheel_freed": "fenn_wheel"})
    sc.node("FennLedge", parent="People", instance="person", transform=xform(m["M_Fenn_2"], yaw_toward(m["M_Fenn_2"], m["M_Island"])),
            display_name="Fenn", talk_id="fenn_ledge", model_scene=("ext", "fenn"),
            show_flag=("sn", "reached_cp_stair_top"), hide_flag=("sn", "fight_dam"),
            bark_on_flag={"reached_cp_stair_top": "fenn_call", "lily_3_open": "fenn_log", "tied_log": "fenn_tied"})
    sc.node("FennWillow", parent="People", instance="person", transform=xform(m["M_Fenn_3"], yaw_toward(m["M_Fenn_3"], m["M_Willow"])),
            display_name="Fenn", talk_id="fenn_willow", model_scene=("ext", "fenn"), show_flag=("sn", "fight_dam"),
            talk_by_flag={"restored_spring": "fenn_farewell"}, bark_on_flag={"water_runs": "fenn_end"})
    for i in (1, 2):
        at = m["M_Verse_%d" % i]
        sc.node("Verse_%d" % i, parent="People", instance="verse", transform=xform(at), talk_id="verse_%d" % i)

    # --- lights -------------------------------------------------------------------------------
    used |= {"lantern", "lantern_model", "brazier", "brazier_model"}
    sc.node("Lanterns", type_="Node3D")
    for lf in d["lanterns"]:
        props = {"model_scene": ("ext", "lantern_model"), "lit_flag": ("sn", "lit_" + lf["id"].lower())}
        if lf["lit"]:
            props["start_lit"] = True
        sc.node(lf["id"], parent="Lanterns", instance="lantern", transform=xform(lf["pos"]), **props)
    sc.node("Brazier", parent="Lanterns", instance="brazier", transform=xform(m["M_Brazier"]),
            model_scene=("ext", "brazier_model"), start_lit=True)

    # --- obstacles ----------------------------------------------------------------------------
    used |= {"soot_bank", "thorn_gate"}
    sc.node("Obstacles", type_="Node3D")
    sc.node("WheelSoot", parent="Obstacles", instance="soot_bank", transform=xform(m["M_Wheel"], yaw_toward(m["M_Wheel"], m["M_WheelView"])),
            width=3.2, height=2.6, cleared_flag=("sn", "wheel_freed"), hint_id=("sn", "mw_wheel"),
            hint_text="Soot packs the paddles. A %s could clear them.", hint_distance=7.0)
    thorn = next(p for p in d["props"] if p["model"] == "thorn_gate")
    sc.node("Thorns", parent="Obstacles", instance="thorn_gate", transform=xform(m["M_Thorns"], thorn["yaw"]),
            width=4.4, cleared_flag=("sn", "thorns_cut"))
    sc.node("SootBank", parent="Obstacles", instance="soot_bank", transform=xform(m["M_SootBank"], yaw_toward(m["M_SootBank"], m["M_TiePost_C"])),
            width=3.6, height=2.8, cleared_flag=("sn", "soot_cleared"))

    # --- lily buds: Bloom opens each into a leaf platform (mosswater.gd plays the opening) ------
    used |= {"glyph_target", "lily_model"}
    sc.node("Lilies", type_="Node3D")
    for p in (p for p in d["props"] if p["model"] == "lily"):
        hint = {"hint_id": ("sn", "mw_lily"), "hint_text": "The bud is waiting for a sun. %s it.", "hint_distance": 5.0} if p["id"] == "Lily_1" else {}
        sc.node(p["id"], parent="Lilies", type_="StaticBody3D", transform=xform(p["pos"], p["yaw"]), script=("ext", "glyph_target"),
                glyphs=["bloom"], flag=("sn", p["id"].lower() + "_open"), model_scene=("ext", "lily_model"), **hint)

    # --- ties: the log swings free of the weir about its root; the gap gets a rope bridge -------
    used.add("tie")
    sc.node("Ties", type_="Node3D")
    for name, a, b in (("Log", "M_TiePost_A", "M_TiePost_B"), ("Gap", "M_TiePost_C", "M_TiePost_D")):
        # Bare posts with the kit script, as in the example level: overrides on the children of an
        # instanced tie_posts.tscn were lost in the web export.
        sc.node(name, parent="Ties", type_="Node3D")
        pull = {}
        if name == "Log":
            # Free, the log lies half sunk with its top 0.13 m over the island at the root and level
            # with the north shore at the far end (its top is 0.75 m over its origin at the root,
            # 0.56 m at the tip, 7.6 m along), so Orimi walks on and off it without a jump.
            root = [m["M_Log"][0], m["M_Island"][1] + 0.13 - 0.75, m["M_Log"][2]]
            tip_y = m["M_LogEnd_Bridge"][1] + 0.05 - 0.56
            pitch = math.degrees(math.asin((tip_y - root[1]) / 7.6))
            sc.node("LogFree", parent="Ties/Log", type_="Marker3D",
                    transform=xform_yaw_pitch(root, yaw_toward(m["M_Log"], m["M_LogEnd_Bridge"]), pitch))
            pull = {"action": "pull", "pull_target": ("path", "../../../Props/log_1"), "pull_to": ("path", "../LogFree"), "pull_to_ground": False}
        pull["tied_flag"] = ("sn", "tied_" + name.lower())
        pull.setdefault("action", "bridge")
        sc.node("PostA", parent="Ties/" + name, type_="StaticBody3D", transform=xform(m[a], yaw_toward(m[a], m[b])), script=("ext", "tie"),
                partner=("path", "../PostB"), **pull)
        sc.node("PostB", parent="Ties/" + name, type_="StaticBody3D", transform=xform(m[b], yaw_toward(m[b], m[a])), script=("ext", "tie"))

    # --- fights -------------------------------------------------------------------------------
    used |= {"sealed", "spawn", "sootflit"}
    sc.node("Fights", type_="Node3D")
    fights = {f["id"]: f for f in d["fights"]}
    f = fights["hollow"]
    sc.node("Fight_Hollow", parent="Fights", type_="Node3D", transform=xform(f["center"]), script=("ext", "sealed"),
            fight_id=("sn", "hollow"), radius=f["radius"] + 1.0, start_flag=("sn", "lit_lf03"))
    for i, (kind, at) in enumerate(f["enemies"]):
        sc.node("Spawn_%d" % i, parent="Fights/Fight_Hollow", type_="Marker3D",
                transform=xform([at[j] - f["center"][j] for j in range(3)]), script=("ext", "spawn"), kind=("sn", kind))
    f = fights["dam"]
    sc.node("Fight_Dam", parent="Fights", type_="Node3D", transform=xform(f["center"]), script=("ext", "sealed"),
            fight_id=("sn", "dam"), radius=f["radius"], requires_flags=["tied_gap"])
    n = 0
    for w, wave in enumerate(f["waves"]):
        for kind, at in wave:
            props = {"wave": w}
            if kind == "sootflit":
                props["enemy_scene"] = ("ext", "sootflit")
            else:
                props["kind"] = ("sn", kind)
            sc.node("Spawn_%d" % n, parent="Fights/Fight_Dam", type_="Marker3D",
                    transform=xform([at[j] - f["center"][j] for j in range(3)]), script=("ext", "spawn"), **props)
            n += 1
    for fid in ("shore", "island"):
        for i, (kind, at) in enumerate(fights[fid]["enemies"]):
            props = {"enemy_scene": ("ext", "sootflit")} if kind == "sootflit" else {"kind": ("sn", kind)}
            if fid == "island":
                props["territory_radius"] = ISLAND_TERRITORY
            sc.node("Roam_%s_%d" % (fid.capitalize(), i), parent="Fights", type_="Marker3D", transform=xform(at),
                    script=("ext", "spawn"), **props)

    # --- the ponds and the spring -------------------------------------------------------------
    used |= {"deep_water", "zone", "bloom"}
    sc.node("Water", type_="Node3D")
    for key, pond in d["ponds"].items():
        # Yaw 135 turns local x onto the up-slope axis and local z onto the across axis.
        sc.node(POND_NODES[key], parent="Water", type_="Node3D", script=("ext", "deep_water"),
                transform=xform([pond["center"][0], pond["water_y"], pond["center"][2]], 135.0),
                size=("v3", pond["radius_s"] * 2, pond["depth"] + 1.0, pond["radius_t"] * 2), show_surface=False, sink=WATER_SINK, bank_height=WATER_BANK_HEIGHT,
                flag=("sn", "fell_in_pond"))
    used |= {"pond_ink", "camera_zone"}
    sc.node("Curse", type_="Node3D")
    for z in (z for z in d["curse_zones"] if z["id"].startswith("pond_")):
        sc.node(INK_NODES[z["id"][5:]], parent="Curse", type_="Node3D", script=("ext", "pond_ink"), transform=xform(z["center"]),
                radius=z["radius"])
    sc.node("Zone_spring", parent="Curse", type_="Node3D", transform=xform(m["M_Willow"]), script=("ext", "zone"),
            zone_id=("sn", "spring"), display_name="the spring", radius=6.0, target_kind="none",
            requires_flags=["fight_dam"], finale=True)
    sc.node("Willow", parent="Curse/Zone_spring", type_="StaticBody3D", script=("ext", "bloom"), model_name="")
    # The finale's fixed camera (mosswater.gd turns it on when the willow blooms): from above the
    # dam crest, over the open sluice and Willow Pool to Orimi and the willow on the far shore.
    sc.node("FinaleCam", parent="Curse", type_="Node3D", transform=xform(FINALE_CAM_AT), script=("ext", "camera_zone"),
            size=("v3", 28, 14, 28), mode="fixed", priority=1, blend_time=1.5, view=("path", "View"))
    sc.node("View", parent="Curse/FinaleCam", type_="Marker3D", transform=xform([FINALE_VIEW[i] - FINALE_CAM_AT[i] for i in range(3)]))
    sc.node("Cameras", type_="Node3D")
    for name, (at, size, pitch, dist, yaw) in CAMERA_ZONES.items():
        sc.node(name, parent="Cameras", type_="Node3D", transform=xform(at), script=("ext", "camera_zone"), size=("v3",) + size,
                distance=dist, lock_pitch=True, pitch_deg=pitch, lock_yaw=True, yaw_deg=yaw)

    # --- checkpoints and the exit -------------------------------------------------------------
    used |= {"checkpoint", "exit"}
    sc.node("Checkpoints", type_="Node3D")
    for name, mk in (("CP_Brazier", "M_Fenn_1"), ("CP_StairTop", "M_StairTop"), ("CP_NorthShore", "M_Fenn_2"),
                     ("CP_GullyTop", "M_TiePost_C"), ("CP_Willow", "M_Verse_2")):
        at = m[mk]
        sc.node(name, parent="Checkpoints", instance="checkpoint", transform=xform([at[0] + 1.2, at[1], at[2] + 1.2]))
    high = d["ponds"]["high"]
    c = xz(high["center"])
    s, t = to_st(c, xz(m["M_Exit"]))
    k = 1.0 / math.hypot(s / high["radius_s"], t / high["radius_t"])
    ex = from_st(c, s * k * 0.85, t * k * 0.85)
    sc.node("Exit", parent="Checkpoints", instance="exit", transform=xform([ex[0], high["water_y"], ex[1]], yaw_toward([ex[0], 0, ex[1]], m["M_Exit"])),
            requires_flags=["water_runs"], radius=2.5)

    SCENE.write_bytes(sc.text(used).encode())
    data = json.loads(DATA.read_text())
    data.pop("safe_ground", None)
    DATA.write_bytes((json.dumps(data, indent="\t", ensure_ascii=False) + "\n").encode())
    print("SCENE %s nodes=%d" % (SCENE.relative_to(ROOT).as_posix(), len(sc.nodes)))


if __name__ == "__main__":
    main()
