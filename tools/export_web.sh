#!/usr/bin/env bash
# Export the Web preset (single-threaded, Compatibility renderer) to build/web/index.html.
#   tools/export_web.sh            release build
#   tools/export_web.sh --debug    debug build
source "$(dirname "$0")/lib/common.sh"
godot_env
stage_web_templates
cd "$PROJECT_ROOT"
mode="--export-release"
[ "${1:-}" = "--debug" ] && mode="--export-debug"
mkdir -p build/web
touch build/.gdignore
rm -f build/web/index.*
# Godot reuses converted scenes from an earlier export even when only a script they use changed.
rm -rf .godot/exported
log="build/export_web.log"
"$GODOT" --headless --path . "$mode" "Web" build/web/index.html >"$log" 2>&1 && rc=0 || rc=$?
sed -i 's/\x1b\[[0-9;]*m//g' "$log"
sanitize_paths "$log"
cat "$log"
missing=0
for f in index.html index.js index.wasm index.pck; do
	[ -f "build/web/$f" ] || { echo "missing build/web/$f"; missing=1; }
done
if [ "$rc" -ne 0 ] || [ "$missing" -ne 0 ] || grep -qE 'SCRIPT ERROR|Parse Error|^ERROR|[^_]ERROR:' "$log"; then
	echo "EXPORT FAILED (exit $rc), log: $log"
	exit 1
fi
ls -l build/web
echo "EXPORT OK: build/web/index.html (log: $log)"
