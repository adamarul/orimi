#!/usr/bin/env bash
# Regenerate every model (Blender, headless) and its painted texture (Python venv).
#   tools/assets/gen_models.sh [model ...]     default: all models
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
blender_env
mkdir -p .userdata/paintmaps
ALL="fox splotchet reedwraith sapling great_tree thorn_gate shrine stepping_stone rocks reeds raft terrain"
MODELS="${*:-$ALL}"
for m in $MODELS; do
	case $m in
		fox|splotchet|reedwraith) dir=assets/characters ;;
		terrain) dir=assets/environment ;;
		*) dir=assets/props ;;
	esac
	script=tools/blender/make_$m.py
	glb=$dir/$m.glb
	[ $m = terrain ] && glb=$dir/valley_terrain.glb
	map=.userdata/paintmaps/$m.json
	echo "== $m"
	"$BLENDER" --background --factory-startup --python "$(native "$script")" -- "$(native "$glb")" "$(native "$map")" > ".userdata/paintmaps/$m.log" 2>&1 || { tail -30 ".userdata/paintmaps/$m.log"; echo "Blender failed: $m"; exit 1; }
	grep -aE "^(MODEL|WARN)" ".userdata/paintmaps/$m.log" || true
	grep -aqE "Traceback|Error:" ".userdata/paintmaps/$m.log" && { grep -aE -A12 "Traceback|Error:" ".userdata/paintmaps/$m.log" | head -40; echo "Blender error: $m"; exit 1; }
	[ -f "$glb" ] || { echo "missing $glb"; exit 1; }
	"$VENV_PY" -I "$(native tools/textures/painted/paint_models.py)" "$m" "$(native "$map")" "$(native assets/textures/painted)" || { echo "painting failed: $m"; exit 1; }
done
"$VENV_PY" -I -B "$(native tools/assets/write_provenance.py)"
echo "MODELS OK"
