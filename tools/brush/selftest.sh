#!/usr/bin/env bash
# Headless brush self test (casting, key orders, refusals, freeze, rays while paused, ink).
# Writes docs/brush/selftest.txt.   tools/brush/selftest.sh
source "$(dirname "$0")/../lib/common.sh"
godot_env
cd "$PROJECT_ROOT"
mkdir -p docs/brush
out="$("$GODOT" --headless --path . -- scene=res://scenes/dev/brush_demo.tscn brush_selftest=1 2>&1)" && rc=0 || rc=$?
echo "$out" | grep -E "BRUSH_SELFTEST|SCRIPT ERROR|^ERROR" > docs/brush/selftest.txt
sanitize_paths docs/brush/selftest.txt
cat docs/brush/selftest.txt
if [ "$rc" -ne 0 ] || ! grep -q "BRUSH_SELFTEST_DONE.*failed=0" docs/brush/selftest.txt || grep -qE "SCRIPT ERROR|^ERROR" docs/brush/selftest.txt; then
	echo "SELFTEST FAILED (exit $rc)"
	exit 1
fi
echo "SELFTEST PASSED"
