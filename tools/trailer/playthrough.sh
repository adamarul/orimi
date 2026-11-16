#!/usr/bin/env bash
# Film one level as an unbroken playthrough: the real game from its title screen, the level played
# by its autoplay route through the gameplay camera (HUD, hints and talk as a player sees them, the
# game's own music and sound), to a few seconds after the card that ends the level. One Movie Maker
# take on the Compatibility renderer at 1920x1080 and 60 fps, then trimmed at head and tail and
# encoded by tools/trailer/playthrough.py. See docs/TRAILER.md.
#   tools/trailer/playthrough.sh [level id, default hazewater] [--encode]   (--encode: skip the capture)
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
level="${1:-hazewater}"
name="level1_playthrough"
[ "$level" = "hazewater" ] || name="${level}_playthrough"
"$(dirname "$0")/setup_ffmpeg.sh"
if [ "${2:-}" != "--encode" ]; then
	# MJPEG at 0.8 keeps a take of ten minutes or so well under the AVI writer's 4 GB limit.
	"$(dirname "$0")/capture.sh" "$name" --tries 1 --limit 7200 --quality 0.8 -- "playthrough=$level"
fi
"$(python_bin)" -I "$(native "$(dirname "$0")/playthrough.py")" "$(native "$TOOLS_DIR/ffmpeg/bin")" "$(native "$PROJECT_ROOT")" "$name"
