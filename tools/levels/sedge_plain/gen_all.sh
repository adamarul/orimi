#!/usr/bin/env bash
# Regenerate everything Sedge Plain's art is made of, in order:
#   layout data (GDScript), plan image, terrain (Blender), props (Blender), painted textures,
#   wrapper scenes, Godot import settings, provenance manifest.
#   tools/levels/sedge_plain/gen_all.sh [terrain] [props] [paint] [scenes]   (default: all)
source "$(dirname "$0")/../../lib/common.sh"
cd "$PROJECT_ROOT"
blender_env
godot_env
HERE=tools/levels/sedge_plain
OUT=assets/levels/sedge_plain
WORK=.userdata/l3
PROPS="stone_tall stone_lean stone_capped stone_fallen tie_post bridge_wreck tamsin_camp map_leaf landing_stage wood_tree"
STEPS="${*:-terrain props paint scenes}"
mkdir -p "$WORK/maps" "$OUT/terrain" "$OUT/props" "$OUT/textures"
py() { "$VENV_PY" -I -B "$(native "$1")" "${@:2}"; }

py $HERE/export_layout.py scripts/levels/sedge_plain/sedge_layout.gd
py $HERE/plan.py docs/levels/sedge_plain/plan.jpg
case " $STEPS " in *" terrain "*)
	"$BLENDER" --background --factory-startup --python "$(native $HERE/make_terrain.py)" -- "$(native $OUT/terrain)" > "$WORK/terrain.log" 2>&1 || { tail -30 "$WORK/terrain.log"; exit 1; }
	grep -aE "^(MODEL|GROUND)" "$WORK/terrain.log"
	grep -aqE "Traceback|Error:" "$WORK/terrain.log" && { grep -aE -A12 "Traceback|Error:" "$WORK/terrain.log" | head -30; exit 1; }
;; esac
case " $STEPS " in *" props "*)
	for m in $PROPS; do
		"$BLENDER" --background --factory-startup --python "$(native $HERE/make_props.py)" -- $m "$(native $OUT/props/$m.glb)" "$(native $WORK/maps/$m.json)" > "$WORK/$m.log" 2>&1 || { tail -30 "$WORK/$m.log"; exit 1; }
		grep -aE "^MODEL" "$WORK/$m.log"
		grep -aqE "Traceback|Error:" "$WORK/$m.log" && { grep -aE -A12 "Traceback|Error:" "$WORK/$m.log" | head -30; exit 1; }
	done
;; esac
case " $STEPS " in *" paint "*)
	py $HERE/paint_ground.py "$OUT/textures"
	for m in $PROPS; do py $HERE/paint_props.py $m "$(native $WORK/maps/$m.json)" "$OUT/textures"; done
;; esac
case " $STEPS " in *" scenes "*)
	py $HERE/make_scenes.py
	py $HERE/write_script.py
	py $HERE/make_level.py
;; esac
"$GODOT" --headless --path . --import > "$WORK/import.log" 2>&1 || true
py $HERE/godot_import.py
for f in $(git status --porcelain --untracked-files=all -- $OUT | awk '{print $2}' | grep '\.import$' || true); do
	rm -f .godot/imported/"$(basename "${f%.import}")"-*.md5
done
"$GODOT" --headless --path . --import >> "$WORK/import.log" 2>&1 || true
py $HERE/godot_import.py --check
py $HERE/write_provenance.py
echo "SEDGE PLAIN OK"
