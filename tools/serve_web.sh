#!/usr/bin/env bash
# Serve build/web on localhost. Picks a free port unless one is given:
#   tools/serve_web.sh            -> prints SERVING http://127.0.0.1:<port>/
#   tools/serve_web.sh 8123
source "$(dirname "$0")/lib/common.sh"
exec "$(python_bin)" -I "$(native "$TOOLS_SCRIPT_DIR/serve_web.py")" --dir "$(native "$PROJECT_ROOT/build/web")" --port "${1:-0}"
