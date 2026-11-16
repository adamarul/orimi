#!/usr/bin/env bash
# Open this checkout in the Godot editor with the same redirected user/template directories
# the scripts use, so web export from the editor finds the templates.
source "$(dirname "$0")/lib/common.sh"
godot_env
stage_web_templates
exec "$GODOT_GUI" --editor --path "$(native "$PROJECT_ROOT")" "$@"
