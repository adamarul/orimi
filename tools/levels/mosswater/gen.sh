#!/usr/bin/env bash
# Regenerate Mosswater Wood's models (Blender, headless) and painted textures (venv Python),
# then the layout JSON, the plan and the provenance manifest. Run import.sh afterwards.
#   tools/levels/mosswater/gen.sh [model ...]     default: every model
# Writes assets/levels/mosswater/*.glb, assets/levels/mosswater/textures/*.png,
# assets/levels/mosswater/provenance.json, scripts/levels/mosswater/mosswater_layout.json,
# docs/levels/mosswater/plan.jpg and elevation.jpg.
source "$(dirname "$0")/../../lib/common.sh"
cd "$PROJECT_ROOT"
blender_env
HERE=tools/levels/mosswater
OUT=assets/levels/mosswater
WORK=.userdata/mw
mkdir -p "$WORK" "$OUT/textures"
ALL="terrain trunk_a trunk_b trunk_c trunk_snag stair_tree fungus_shelf ledge moss_shelf lantern_fruit wheel lily lily_pad log dam willow fenn_hut brazier raft_post sootflit"
MODELS="${*:-$ALL}"
for m in $MODELS; do
	glb=$OUT/mw_$m.glb
	map=$WORK/$m.json
	echo "== $m"
	"$BLENDER" --background --factory-startup --python "$(native "$HERE/make_mw.py")" -- "$m" "$(native "$glb")" "$(native "$map")" > "$WORK/$m.log" 2>&1 || { tail -30 "$WORK/$m.log"; echo "Blender failed: $m"; exit 1; }
	grep -aE "^(MODEL|WARN|GROUND)" "$WORK/$m.log" || true
	grep -aqE "Traceback|Error:" "$WORK/$m.log" && { grep -aE -A12 "Traceback|Error:" "$WORK/$m.log" | head -40; echo "Blender error: $m"; exit 1; }
	[ -f "$glb" ] || { echo "missing $glb"; exit 1; }
	"$VENV_PY" -I -B "$(native "$HERE/paint_mw.py")" "$m" "$(native "$map")" "$(native "$OUT/textures")" || { echo "painting failed: $m"; exit 1; }
done
"$VENV_PY" -I -B "$(native "$HERE/export_layout.py")" "$(native scripts/levels/mosswater/mosswater_layout.json)"
"$VENV_PY" -I -B "$(native "$HERE/plan.py")" "$(native docs/levels/mosswater)"
"$VENV_PY" -I -B "$(native "$HERE/write_provenance.py")"
echo "MODELS OK"
