#!/usr/bin/env bash
# Browser capture of the vfx demo from build/web (owner: vfx). See tools/vfx/shots_web.cjs.
#   tools/vfx/shots_web.sh --out .userdata/vfx_web               one screenshot per effect at its peak
#   tools/vfx/shots_web.sh --out DIR --perf 20 foliage=500    frame rate with the demo running
# Run tools/export_web.sh first.
source "$(dirname "$0")/../lib/common.sh"
export ORIMI_TOOLS_DIR="$(native "$TOOLS_DIR")" ORIMI_PROJECT_ROOT="$(native "$PROJECT_ROOT")" ORIMI_PYTHON="$(native "$(python_bin)")"
args=()
while [ $# -gt 0 ]; do
	case "$1" in
		--out) args+=("--out" "$(native "$(mkdir -p "$2" && cd "$2" && pwd)")"); shift 2 ;;
		*) args+=("$1"); shift ;;
	esac
done
exec node "$(native "$TOOLS_SCRIPT_DIR/vfx/shots_web.cjs")" "${args[@]}"
