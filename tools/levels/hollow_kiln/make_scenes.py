"""Write the Hollow Kiln's Godot scenes from kiln_layout.py:

  scenes/levels/hollow_kiln/models/<model>.tscn   one wrapper per generated model (the glb plus an InkLook,
                                                 and %AnimationPlayer for animated models), as CONTRACTS.md asks
  scenes/levels/hollow_kiln/kiln_set.tscn        the whole static place: ground, far valley, water, the four
                                                 buildings and every prop at its kiln_layout.PROPS position

    python -I tools/levels/hollow_kiln/make_scenes.py

Only models whose glb exists are written or placed.
"""
import math
import os
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
import kiln_layout as K  # noqa: E402

MODELS = ROOT / "assets/levels/hollow_kiln/models"
SCENES = ROOT / "scenes/levels/hollow_kiln"
INK_LOOK = "res://scripts/render/ink_look.gd"
WATER_MAT = "res://materials/env/water.tres"
# InkLook settings per model: outline_width, accent, cursable, line_style, wind
LOOK = {
    "ground_s": (1.6, "", True, "world", False), "ground_n": (1.6, "", True, "world", False),
    "far": (1.0, "", True, "world", False), "yard": (1.2, "", True, "world", False), "hall": (1.2, "", True, "world", False),
    "flue": (1.2, "", True, "world", False), "kiln": (1.3, "", True, "world", False),
    "brazier": (1.0, "gold", True, "world", False), "wall_lamp": (1.0, "gold", True, "world", False),
    "bellows": (1.0, "gold", True, "world", False), "tie_post": (1.0, "gold", True, "world", False),
    "pillar_ring": (1.0, "gold", False, "world", False),
    "counterweight": (1.0, "gold", True, "world", False), "moss_foothold": (0.9, "gold", True, "world", False),
    "cord_gate": (1.0, "", True, "world", False),
    "drying_rack": (0.8, "", True, "world", True), "kiln_fire": (0.0, "", False, "world", False),
    "dregs": (1.0, "", False, "character", False), "vat_tree": (1.0, "", True, "world", True),
}
FAR_FADE = "res://scripts/levels/hollow_kiln/far_fade.gd"
# models that are seen from far away: (fade_start, fade_end, fade_max) for scripts/levels/hollow_kiln/far_fade.gd
FADE = {"kiln": (90.0, 400.0, 0.5), "far": (140.0, 700.0, 0.45), "ground_s": (60.0, 320.0, 0.6), "ground_n": (60.0, 320.0, 0.6),
        "hall": (70.0, 320.0, 0.6), "vat_tree": (90.0, 400.0, 0.45)}
ANIMATED = {"brazier", "wall_lamp", "bellows", "counterweight", "moss_foothold", "cord_gate", "dregs", "vat_tree", "kiln_fire"}
NO_INK = {"water", "ink_pool"}
# InkLook light_keep: the boss keeps more of its colour than the enemy default (0.7) in the dark chamber
KEEP = {"dregs": 0.9}


def ext(path, kind, i):
    return '[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, i)


def wrapper(model):
    glb = "res://assets/levels/hollow_kiln/models/%s.glb" % model
    name = "".join(p.capitalize() for p in model.split("_"))
    lines = ['[gd_scene format=3]', "", ext(glb, "PackedScene", "1")]
    if model in NO_INK:
        if model == "water":
            lines.append(ext(WATER_MAT, "Material", "2"))
        lines += ["", '[node name="%s" instance=ExtResource("1")]' % name, ""]
        if model == "water":
            for mesh in ("Stream", "Race"):
                lines += ['[node name="%s" parent="." groups=["ink_skip"]]' % mesh, 'material_override = ExtResource("2")', "cast_shadow = 0", ""]
        return "\n".join(lines)
    lines.append(ext(INK_LOOK, "Script", "2"))
    if model in FADE:
        lines.append(ext(FAR_FADE, "Script", "3"))
    lines += ["", '[node name="%s" instance=ExtResource("1")]' % name, ""]
    if model in ANIMATED:
        lines += ['[node name="AnimationPlayer" parent="."]', "unique_name_in_owner = true", ""]
    width, accent, cursable, style, wind = LOOK.get(model, (1.0, "", True, "world", False))
    lines += ['[node name="InkLook" type="Node" parent="."]', 'script = ExtResource("2")']
    if width != 1.0:
        lines.append("outline_width = %s" % width)
    if accent:
        lines.append('accent = &"%s"' % accent)
    if not cursable:
        lines.append("cursable = false")
    if style != "world":
        lines.append('line_style = &"%s"' % style)
    if wind:
        lines.append("wind = true")
    if model in KEEP:
        lines.append("light_keep = %s" % KEEP[model])
    lines.append("")
    if model in FADE:
        s, e, mx = FADE[model]
        lines += ['[node name="FarFade" type="Node" parent="."]', 'script = ExtResource("3")', "fade_start = %s" % s, "fade_end = %s" % e, "fade_max = %s" % mx, ""]
    return "\n".join(lines)


def node_name(model, k):
    return "".join(p.capitalize() for p in model.split("_")) + ("_%d" % k if k else "")


def kiln_set(present, root="HollowKilnSet"):
    order = ["ground_s", "ground_n", "far", "water", "yard", "hall", "flue", "kiln"]
    placed = [(m, 0.0, 0.0, 0.0, 0.0) for m in order if m in present]
    placed += [p for p in K.PROPS if p[0] in present]
    if "ink_pool" in present:
        placed.append(("ink_pool", (K.FLUE["x"][0] + K.FLUE["x"][1]) / 2, K.FLUE["ink0"], (K.FLUE["z"][0] + K.FLUE["z"][1]) / 2, 0.0))
    if "kiln_fire" in present:
        for nm, (x, y, z, yaw) in K.KILN_FIRES.items():
            placed.append(("kiln_fire", x, y, z, yaw))
    if "dregs" in present:
        placed.append(("dregs", K.VAT["c"][0], K.VAT["rim"] - 1.0, K.VAT["c"][1], 180.0))
    if "vat_tree" in present:
        placed.append(("vat_tree", K.VAT["c"][0], K.Y_VAT, K.VAT["c"][1], 0.0))
    models = sorted({p[0] for p in placed})
    ids = {m: str(i + 1) for i, m in enumerate(models)}
    lines = ['[gd_scene format=3]', ""]
    for m in models:
        lines.append(ext("res://scenes/levels/hollow_kiln/models/%s.tscn" % m, "PackedScene", ids[m]))
    lines += ["", '[node name="%s" type="Node3D"]' % root, ""]
    groups = {"ground_s": "Ground", "ground_n": "Ground", "far": "Ground", "water": "Ground", "yard": "Buildings", "hall": "Buildings",
              "flue": "Buildings", "kiln": "Buildings", "dregs": "Actors", "vat_tree": "Actors"}
    for g in ("Ground", "Buildings", "Props", "Actors"):
        lines += ['[node name="%s" type="Node3D" parent="."]' % g, ""]
    counts = {}
    for m, x, y, z, yaw in placed:
        k = counts.get(m, 0)
        counts[m] = k + 1
        parent = groups.get(m, "Props")
        lines.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % (node_name(m, k), parent, ids[m]))
        if (x, y, z) != (0.0, 0.0, 0.0):
            lines.append("position = Vector3(%.3f, %.3f, %.3f)" % (x, y, z))
        if yaw:
            lines.append("rotation = Vector3(0, %.6f, 0)" % math.radians(yaw))
        lines.append("")
    return "\n".join(lines)


# Props the playable level puts under kit nodes instead of the set.
KIT_DRIVEN = ["cord_gate", "dregs", "brazier", "wall_lamp", "kiln_fire", "tie_post", "pillar_ring", "bellows", "moss_foothold"]
# Looks for the kit's KindleTarget and TiePost (model_scene): the model plus the node the kit looks
# for, Wick (where the Kindle dab lands) or Ring (where the Tie rope ties on).
KIT_LOOKS = {"brazier_kindle": ("brazier", ("Wick", (0.0, 1.5, 0.0))), "lamp_kindle": ("wall_lamp", ("Wick", (0.0, 0.4, -0.62))),
             "mouth_kindle": ("kiln_fire", ("Wick", (0.0, 1.0, 0.0))), "counterweight_ring": (None, ("Ring", (0.0, 0.0, 0.0)))}


def kit_look(model, wick):
    lines = ['[gd_scene format=3]', ""]
    if model:
        lines += [ext("res://scenes/levels/hollow_kiln/models/%s.tscn" % model, "PackedScene", "1"), ""]
    lines += ['[node name="Look" type="Node3D"]', ""]
    if model:
        lines += ['[node name="Model" parent="." instance=ExtResource("1")]', ""]
    name, (x, y, z) = wick
    lines += ['[node name="%s" type="Node3D" parent="."]' % name, "position = Vector3(%.3f, %.3f, %.3f)" % (x, y, z), ""]
    return "\n".join(lines)


def kiln_markers():
    """Every kiln_layout marker as a Marker3D named M_*, which the kit's Level reads as markers.
    All face north (-Z); level.json's spawn_facing turns Orimi toward the gate."""
    lines = ['[gd_scene format=3]', "", '[node name="KilnMarkers" type="Node3D"]', ""]
    for name, (x, y, z) in K.MARKERS.items():
        lines += ['[node name="%s" type="Marker3D" parent="."]' % name, "position = Vector3(%.3f, %.3f, %.3f)" % (x, y, z), ""]
    return "\n".join(lines)


def main():
    present = {p.stem for p in MODELS.glob("*.glb")}
    (SCENES / "models").mkdir(parents=True, exist_ok=True)
    def write(path, text):
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    for m in sorted(present):
        write(SCENES / "models" / ("%s.tscn" % m), wrapper(m))
    write(SCENES / "kiln_set.tscn", kiln_set(present))
    # the playable level's set: the props the kit drives (gate, braziers, lamps, kiln fires, tie posts,
    # pillar rings) are placed by make_level.py under kit nodes, and the Dregs is an enemy
    write(SCENES / "kiln_set_level.tscn", kiln_set(present - set(KIT_DRIVEN), "HollowKilnSetLevel"))
    (SCENES / "kit").mkdir(exist_ok=True)
    for name, (model, wick) in KIT_LOOKS.items():
        write(SCENES / "kit" / ("%s.tscn" % name), kit_look(model, wick))
    write(SCENES / "kiln_markers.tscn", kiln_markers())
    print("SCENES %d wrappers, kiln_set.tscn, kiln_set_level.tscn, kiln_markers.tscn (%d markers)" % (len(present), len(K.MARKERS)))


if __name__ == "__main__":
    main()
