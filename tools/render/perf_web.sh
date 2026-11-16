#!/usr/bin/env bash
# Browser frame-rate measurement of build/web (render workstream). See perf_web.cjs.
#   tools/render/perf_web.sh [--size 1920x1080] [--hold 8] [--uncapped] scene=res://scenes/dev/render_demo.tscn perf=1
source "$(dirname "$0")/../lib/common.sh"
export ORIMI_TOOLS_DIR="$(native "$TOOLS_DIR")" ORIMI_PROJECT_ROOT="$(native "$PROJECT_ROOT")" ORIMI_PYTHON="$(native "$(python_bin)")"
exec node "$(native "$TOOLS_SCRIPT_DIR/render/perf_web.cjs")" "$@"
