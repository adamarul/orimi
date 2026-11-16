#!/usr/bin/env bash
# Browser proof of the brush with real pointer and key events. Needs a fresh tools/export_web.sh.
#   tools/brush/web_brush.sh [--pointer mouse|pen] [--headed] [--out DIR] [--rate HZ]
source "$(dirname "$0")/../lib/common.sh"
export ORIMI_TOOLS_DIR="$(native "$TOOLS_DIR")" ORIMI_PROJECT_ROOT="$(native "$PROJECT_ROOT")" ORIMI_PYTHON="$(native "$(python_bin)")"
exec node "$(native "$TOOLS_SCRIPT_DIR/brush/web_brush.cjs")" "$@"
