#!/usr/bin/env bash
# Finds overrides on instanced scenes' children that the web export drops (no [editable] line).
#   tools/game/check_scenes.sh [--fix] [res://path/to/scene.tscn ...]
# With no scenes it checks every .tscn in the project. --fix appends the missing lines.
source "$(dirname "$0")/../lib/common.sh"
godot_env
cd "$PROJECT_ROOT"
out="$("$GODOT" --headless --path . -s "$(native "$PWD/tools/game/check_scenes.gd")" -- "$@" 2>&1)" && rc=0 || rc=$?
echo "$out" | grep 'CHECK_SCENES' || echo "$out" | tail -20
exit "$rc"
