#!/usr/bin/env bash
# Headless recognition test: prints the confusion table and writes it to docs/brush/recognition.txt.
#   tools/brush/test_recognition.sh
source "$(dirname "$0")/../lib/common.sh"
godot_env
cd "$PROJECT_ROOT"
mkdir -p docs/brush
out="$("$GODOT" --headless --path . -- scene=res://scenes/dev/brush_recognition_test.tscn 2>&1)" && rc=0 || rc=$?
echo "$out" | sed -n '/BRUSH_TEST confusion/,/BRUSH_TEST_DONE/p' | grep -v BRUSH_TEST_DONE > docs/brush/recognition.txt
cat docs/brush/recognition.txt
if [ "$rc" -ne 0 ] || ! echo "$out" | grep -q BRUSH_TEST_DONE || echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error|^ERROR'; then
	echo "$out" | grep -E 'ERROR|Error|at:' | head -20
	echo "TEST FAILED (exit $rc)"
	exit 1
fi
