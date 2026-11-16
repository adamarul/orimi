#!/usr/bin/env bash
# Capture the real game at the four warps on desktop and web into a folder (render workstream).
#   tools/render/capture_valley.sh <out-dir> [--skip-export] [extra boot options...]
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
out="$1"; shift
mkdir -p "$out"
if [ "${1:-}" = "--skip-export" ]; then shift; else tools/export_web.sh >/dev/null 2>&1 || { echo "export FAILED"; exit 1; }; fi
for w in M_Spawn M_ZoneA M_ZoneB M_Tree; do
	tools/screenshot_desktop.sh "$out/desktop_$w.png" warp=$w god=1 shot_after=7 "$@" >/dev/null 2>&1 && echo "desktop $w ok" || echo "desktop $w FAILED"
	tools/smoke_web.sh --no-input --hold 22 --shot "$out/web_$w.png" --log "$out/web_$w.txt" warp=$w god=1 "$@" >/dev/null 2>&1 && echo "web $w ok" || echo "web $w FAILED"
done
