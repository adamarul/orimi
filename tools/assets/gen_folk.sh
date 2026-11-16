#!/usr/bin/env bash
# Generate a cast of paper folk from a spec (format in tools/blender/folk_style.py): for each
# person a glb (Blender), a woken and a faded painted atlas, a wrapper scene, then the import
# registry and provenance. Run tools/assets/import_assets.sh afterwards to import them.
#   tools/assets/gen_folk.sh <spec.json> [name ...]     default: every person in the spec
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
blender_env
spec="$1"; shift
[ -f "$spec" ] || { echo "usage: $0 <spec.json> [name ...]" >&2; exit 2; }
names="${*:-$("$VENV_PY" -I -B "$(native tools/blender/folk_style.py)" "$(native "$spec")" | tr -d '\r')}"
mkdir -p .userdata/paintmaps
for n in $names; do
	glb=$("$VENV_PY" -I -B -c "import sys; sys.path.insert(0, 'tools/blender'); import folk_style as F; print(F.paths(F.load(sys.argv[1]), sys.argv[2])['glb'])" "$spec" "$n" | tr -d '\r')
	map=.userdata/paintmaps/folk_$n.json
	log=.userdata/paintmaps/folk_$n.log
	echo "== $n"
	mkdir -p "$(dirname "$glb")"
	"$BLENDER" --background --factory-startup --python "$(native tools/blender/make_folk.py)" -- "$(native "$spec")" "$n" "$(native "$glb")" "$(native "$map")" > "$log" 2>&1 || { tail -30 "$log"; echo "Blender failed: $n"; exit 1; }
	grep -aE "^(MODEL|WARN)" "$log" || true
	grep -aqE "Traceback|Error:" "$log" && { grep -aE -A12 "Traceback|Error:" "$log" | head -40; echo "Blender error: $n"; exit 1; }
	"$VENV_PY" -I "$(native tools/textures/painted/paint_folk.py)" "$(native "$spec")" "$n" "$(native "$map")" || { echo "painting failed: $n"; exit 1; }
done
"$VENV_PY" -I -B "$(native tools/assets/folk_finish.py)" "$(native "$spec")"
echo "FOLK OK"
