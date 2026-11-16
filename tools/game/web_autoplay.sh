#!/usr/bin/env bash
# Plays the game in Chrome (autoplay=1) from build/web and screenshots every stage.
#   tools/game/web_autoplay.sh [--no-export] [--out DIR] [--timeout S] [--headed] [key=value ...]
# Exports first (tools/export_web.sh) so the run always tests the working tree. With
# --no-export it plays the existing build, and fails if any project file is newer than it.
source "$(dirname "$0")/../lib/common.sh"
export_first=1
args=()
for a in "$@"; do
  if [ "$a" = "--no-export" ]; then export_first=0; else args+=("$a"); fi
done
cd "$PROJECT_ROOT"
if [ "$export_first" = 1 ]; then
  tools/export_web.sh || { echo "web_autoplay: export failed" >&2; exit 2; }
else
  pck=build/web/index.pck
  [ -f "$pck" ] || { echo "web_autoplay: no build at $pck (run without --no-export)" >&2; exit 2; }
  newer=$(find project.godot scripts scenes shaders materials assets audio ui -newer "$pck" -type f 2>/dev/null | grep -v '\.import$' | head -3 || true)
  if [ -n "$newer" ]; then
    echo "web_autoplay: build/web is older than the working tree (for example: $newer); run without --no-export" >&2
    exit 2
  fi
fi
export ORIMI_TOOLS_DIR="$(native "$TOOLS_DIR")" ORIMI_PROJECT_ROOT="$(native "$PROJECT_ROOT")" ORIMI_PYTHON="$(native "$(python_bin)")"
exec node "$(native "$TOOLS_SCRIPT_DIR/game/web_autoplay.cjs")" "${args[@]}"
