#!/usr/bin/env bash
# Regenerate Tallowford's art and data: layout data, plan image and docs tables, the terrain, every
# model (Blender headless) with its painted texture (venv painter), the provenance manifest, then
# the Godot import settings, materials and wrapper scenes.
#   tools/levels/tallowford/gen.sh [terrain] [model ...]     default: everything
#   tools/levels/tallowford/gen.sh --import-only             only the Godot import step
# Run from the checkout root. Never run it while another import or export runs in this checkout.
source "$(dirname "$0")/../../lib/common.sh"
cd "$PROJECT_ROOT"
T=tools/levels/tallowford
A=assets/levels/tallowford
W=.userdata/tf
mkdir -p "$W/maps" "$A/models" "$A/textures"
ALL_MODELS="house_trim house_marrow house_brindle house_children house_ferry cottage shed lamp_post ford_lamp persimmon well dye_vats cloth_line drying_rack jetty landing fence"
py() { "$VENV_PY" -I -B "$@"; }

if [ "${1:-}" != "--import-only" ]; then
	TARGETS="${*:-terrain $ALL_MODELS}"
	py $T/layout.py scripts/levels/tallowford/layout.json
	py $T/plan.py docs/levels/tallowford/plan.png
	py $T/docs.py
	py $T/level_data.py
	py $T/level_scene.py
	blender_env
	for m in $TARGETS; do
		echo "== $m"
		if [ "$m" = terrain ]; then
			"$BLENDER" --background --factory-startup --python "$(native $T/make_terrain.py)" -- "$(native $A/models/tallowford_terrain.glb)" "$(native $A/models/tallowford_river.glb)" > "$W/terrain.log" 2>&1 || { tail -30 "$W/terrain.log"; exit 1; }
			grep -aE "^(MODEL|GROUND|MARKERS)" "$W/terrain.log"
			grep -aqE "Traceback|Error:" "$W/terrain.log" && { grep -aE -A12 "Traceback|Error:" "$W/terrain.log" | head -30; exit 1; }
			py $T/paint_terrain.py $A/textures || exit 1
			continue
		fi
		"$BLENDER" --background --factory-startup --python "$(native $T/make_model.py)" -- "$m" "$(native $A/models/$m.glb)" "$(native $W/maps/$m.json)" > "$W/maps/$m.log" 2>&1 || { tail -30 "$W/maps/$m.log"; exit 1; }
		grep -aE "^MODEL" "$W/maps/$m.log"
		grep -aqE "Traceback|Error:" "$W/maps/$m.log" && { grep -aE -A12 "Traceback|Error:" "$W/maps/$m.log" | head -30; exit 1; }
		py $T/paint_models.py "$m" "$W/maps/$m.json" $A/textures || exit 1
	done
	py $T/write_provenance.py
fi

godot_env
"$GODOT" --headless --path . --import > "$W/import.log" 2>&1 || true
py $T/godot_import.py
for f in $(git status --porcelain --untracked-files=all -- $A | awk '{print $2}' | grep '\.import$' || true); do
	rm -f .godot/imported/"$(basename "${f%.import}")"-*.md5
done
"$GODOT" --headless --path . --import >> "$W/import.log" 2>&1 || true
py $T/godot_import.py --check
echo "TALLOWFORD GEN OK"
