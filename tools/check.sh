#!/usr/bin/env bash
# Headless check. Fails (exit 1) on any script, scene or resource that fails to load, or any runtime ERROR while the
# main scene boots headless for a few seconds. Shaders are not compiled headless: use
# tools/screenshot_desktop.sh and tools/smoke_web.sh to catch shader errors.
#   tools/check.sh [boot options...]      e.g. tools/check.sh scene=res://scenes/other.tscn
source "$(dirname "$0")/lib/common.sh"
godot_env
cd "$PROJECT_ROOT"
mkdir -p "$USERDATA/logs"
log="$USERDATA/logs/check.log"
: > "$log"
status=0
error_re='SCRIPT ERROR|Parse Error|USER ERROR|^ERROR|[^_]ERROR:'

echo "== import"
"$GODOT" --headless --path . --import >>"$log" 2>&1 || { echo "import exited non-zero"; status=1; }

echo "== load every script, scene and resource inside the running game"
# Done in-engine (scenes/dev/check_scripts.tscn) rather than with --check-only, because
# --check-only does not know the autoload singletons (Events, Game, ...).
out="$("$GODOT" --headless --path . -- scene=res://scenes/dev/check_scripts.tscn 2>&1)" && rc=0 || rc=$?
echo "$out" >>"$log"
echo "$out" | grep -E "ORIMI_CHECK FAIL|ORIMI_CHECK_DONE" || true
if [ "$rc" -ne 0 ] || echo "$out" | grep -qE "$error_re|ORIMI_CHECK FAIL"; then
	echo "FAIL load check (exit $rc)"
	echo "$out" | grep -E "$error_re|at:" | head -40
	status=1
elif ! echo "$out" | grep -q ORIMI_CHECK_DONE; then
	echo "FAIL load check never finished"
	status=1
else
	echo "ok   load check"
fi

echo "== boot main scene headless (quit_after=3)"
out="$("$GODOT" --headless --path . -- quit_after=3 "$@" 2>&1)" && rc=0 || rc=$?
echo "$out" >>"$log"
if [ "$rc" -ne 0 ] || echo "$out" | grep -qE "$error_re"; then
	echo "FAIL boot run (exit $rc)"
	echo "$out" | grep -E "$error_re|at:" | head -40
	status=1
elif ! echo "$out" | grep -q ORIMI_FIRST_FRAME; then
	echo "FAIL boot run never printed ORIMI_FIRST_FRAME"
	status=1
else
	echo "ok   boot run"
fi

if [ -x tools/game/check_scenes.sh ]; then
	if tools/game/check_scenes.sh >>"$log" 2>&1; then
		echo "ok   scenes keep instanced-child overrides in a web export"
	else
		echo "FAIL a scene overrides children of an instance without an [editable] line: tools/game/check_scenes.sh --fix"
		status=1
	fi
fi

sanitize_paths "$log"
echo "full log: $log"
[ "$status" -eq 0 ] && echo "CHECK PASSED" || echo "CHECK FAILED"
exit "$status"
