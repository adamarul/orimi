#!/usr/bin/env bash
# Rebuild the trailer from nothing: fetch ffmpeg if needed, capture every shot with Movie Maker,
# cut, mix, encode and check. Output in build/trailer/ (see docs/TRAILER.md).
#   tools/trailer/build.sh            capture everything, then edit
#   tools/trailer/build.sh --edit     edit only, from the clips already in .userdata/trailer/clips/
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
"$(dirname "$0")/setup_ffmpeg.sh"
if [ "${1:-}" != "--edit" ]; then
	"$(dirname "$0")/capture_all.sh"
fi
"$(python_bin)" -I "$(native "$(dirname "$0")/edit.py")" "$(native "$TOOLS_DIR/ffmpeg/bin")" "$(native "$PROJECT_ROOT")"
