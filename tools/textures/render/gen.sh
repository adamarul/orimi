#!/usr/bin/env bash
# Regenerate the render workstream's textures into assets/textures/render/ (deterministic).
#   tools/textures/render/gen.sh
source "$(dirname "$0")/../../lib/common.sh"
cd "$PROJECT_ROOT"
"$(python_bin)" -I "$(native "$TOOLS_SCRIPT_DIR/textures/render/gen_render_textures.py")" "$(native "$PROJECT_ROOT/assets/textures/render")"
