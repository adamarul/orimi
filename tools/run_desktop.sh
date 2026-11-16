#!/usr/bin/env bash
# Run the game on desktop (Forward+). Arguments are boot options, e.g.:
#   tools/run_desktop.sh scene=res://scenes/phase0/phase0.tscn paper=heavy
source "$(dirname "$0")/lib/common.sh"
godot_env
exec "$GODOT" --path "$(native "$PROJECT_ROOT")" -- "$@"
