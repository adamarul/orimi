#!/usr/bin/env bash
# Headless autoplay run of the whole slice on desktop (logic only, no rendering).
#   tools/game/autoplay_headless.sh [extra boot options...]
# Prints the QA lines; exit code is the autoplay result. Log: build/game/autoplay_headless.log
source "$(dirname "$0")/../lib/common.sh"
godot_env
cd "$PROJECT_ROOT"
mkdir -p build/game
log=build/game/autoplay_headless.log
"$GODOT" --headless --path . -- scene=res://scenes/game/main.tscn autoplay=1 autoplay_quit=1 "$@" >"$log" 2>&1 && rc=0 || rc=$?
sanitize_paths "$log"
grep -E 'QA:|QA_AUTOPLAY|SCRIPT ERROR|^ERROR|WARNING' "$log" || true
echo "exit $rc"
exit "$rc"
