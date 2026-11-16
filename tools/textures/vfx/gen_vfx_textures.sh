#!/usr/bin/env bash
# Regenerates every vfx/environment texture into assets/textures/vfx/ (owner: vfx).
#   tools/textures/vfx/gen_vfx_textures.sh
# Uses the project venv (numpy, Pillow, scipy). Deterministic: a fixed seed.
source "$(dirname "$0")/../../lib/common.sh"
cd "$PROJECT_ROOT"
"$(python_bin)" -I "$(native "$TOOLS_SCRIPT_DIR/textures/vfx/gen_vfx_textures.py")" "$(native "$PROJECT_ROOT/assets/textures/vfx")"
