#!/usr/bin/env bash
# Regenerate the Hollow Kiln's models, painted textures, provenance, import settings and scenes,
# then the data (scripts/levels/hollow_kiln/kiln_layout.json, scenes/levels/hollow_kiln/level.json),
# docs/levels/hollow_kiln/SCRIPT.md and the plan drawings. Wenna: tools/assets/gen_folk.sh tools/levels/hollow_kiln/folk.json.
#   tools/levels/hollow_kiln/gen.sh                 everything
#   tools/levels/hollow_kiln/gen.sh <model ...>      some models (and their textures), then the rest of the steps
#   tools/levels/hollow_kiln/gen.sh textures         the tileable building textures, ground and far valley
# Blender headless builds the glb files, the venv painter paints the textures, then Godot imports
# them and tools/levels/hollow_kiln/kiln_import.py applies the import settings.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"
cd "$PROJECT_ROOT"
blender_env
HK=tools/levels/hollow_kiln
OUT=assets/levels/hollow_kiln
WORK=.userdata/hollow_kiln
mkdir -p "$OUT/models" "$OUT/textures" "$WORK"
ARCH="ground_s ground_n far water yard hall flue kiln"
PROPS="brazier cord_gate woodpile jars bellows tie_post pillar_ring counterweight drying_rack wall_lamp moss_foothold vat raft_jetty kiln_fire ink_pool"
CHARS="dregs vat_tree"
ALL="textures $ARCH $PROPS $CHARS"
ITEMS="${*:-$ALL}"
py() { "$VENV_PY" -I -B "$@"; }
for m in $ITEMS; do
	if [ "$m" = textures ]; then
		echo "== textures"
		py "$(native $HK/paint_kiln.py)" tiles "$(native $OUT/textures)"
		py "$(native $HK/paint_kiln.py)" ground "$(native $OUT/textures)"
		py "$(native $HK/paint_kiln.py)" far "$(native $OUT/textures)"
		continue
	fi
	case " $ARCH " in *" $m "*) script=$HK/make_architecture.py ;; *)
		case $m in dregs) script=$HK/make_dregs.py ;; vat_tree) script=$HK/make_tree.py ;; *) script=$HK/make_props.py ;; esac ;;
	esac
	echo "== $m"
	log="$WORK/$m.log"
	map="$WORK/$m.json"
	rm -f "$map"
	"$BLENDER" --background --factory-startup --python "$(native "$script")" -- "$m" "$(native "$OUT/models/$m.glb")" "$(native "$map")" > "$log" 2>&1 || { tail -30 "$log"; echo "Blender failed: $m"; exit 1; }
	grep -aE "^(MODEL|WARN|GROUND)" "$log" || true
	grep -aqE "Traceback|Error:" "$log" && { grep -aE -A12 "Traceback|Error:" "$log" | head -40; echo "Blender error: $m"; exit 1; }
	[ -f "$OUT/models/$m.glb" ] || { echo "missing $OUT/models/$m.glb"; exit 1; }
	if [ -f "$map" ]; then
		py "$(native $HK/paint_kiln.py)" model "$m" "$(native "$map")" "$(native $OUT/textures)" || { echo "painting failed: $m"; exit 1; }
	fi
done
py "$(native $HK/write_provenance.py)"
godot_env
"$GODOT" --headless --path . --import > "$WORK/import.log" 2>&1 || true
py "$(native $HK/kiln_import.py)"
for f in $(git status --porcelain --untracked-files=all -- "$OUT" | awk '{print $2}' | grep '\.import$' || true); do
	rm -f .godot/imported/"$(basename "${f%.import}")"-*.md5
done
"$GODOT" --headless --path . --import >> "$WORK/import.log" 2>&1 || true
py "$(native $HK/kiln_import.py)" --check
py "$(native $HK/make_scenes.py)"
py "$(native $HK/make_level.py)"
py "$(native $HK/export_layout.py)"
py "$(native $HK/script_doc.py)"
py "$(native $HK/plan.py)" "$(native docs/levels/hollow_kiln)"
echo "HOLLOW KILN GEN OK"
