#!/usr/bin/env bash
# Regenerate every asset from source: models and painted textures, sound effects, music, level
# reports and plots, the Godot import settings and the demo scene. Then run tools/check.sh.
#   tools/assets/gen_all.sh
set -e
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
tools/assets/gen_models.sh
tools/assets/gen_folk.sh tools/assets/folk_cast.json
tools/assets/gen_audio.sh
tools/assets/import_assets.sh
"$VENV_PY" -I -B "$(native tools/assets/make_demo.py)"
"$VENV_PY" -I -B "$(native tools/assets/tri_count.py)"
echo "ALL ASSETS OK"
