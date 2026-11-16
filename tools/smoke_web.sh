#!/usr/bin/env bash
# Browser smoke check of build/web in the installed Chrome. See tools/smoke_web.cjs for options:
#   tools/smoke_web.sh [--headed] [--hold S] [--shot out.png] [--log out.txt] [--no-input] [key=value ...]
source "$(dirname "$0")/lib/common.sh"
export ORIMI_TOOLS_DIR="$(native "$TOOLS_DIR")" ORIMI_PROJECT_ROOT="$(native "$PROJECT_ROOT")" ORIMI_PYTHON="$(native "$(python_bin)")"
exec node "$(native "$TOOLS_SCRIPT_DIR/smoke_web.cjs")" "$@"
