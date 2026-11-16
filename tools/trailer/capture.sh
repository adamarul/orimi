#!/usr/bin/env bash
# Capture one trailer shot with Godot's Movie Maker: a 1920x1080 window, fixed 60 fps, every frame
# and the game's sound written to .userdata/trailer/clips/<shot>.avi (MJPEG + PCM), whatever the
# machine load. The director (scenes/trailer/director.tscn) prints the frame marks the edit uses;
# they are kept in <shot>.log beside the clip. Retries a shot whose casts or route failed.
#   tools/trailer/capture.sh <shot id> [--renderer gl_compatibility|forward_plus] [--tries N]
#       [--limit S] [--quality Q] [-- boot options instead of shot=<shot id>]
#
# Movie Maker records at the window size the project settings give at start-up, which the
# --resolution flag does not change, so while it runs this script writes an override.cfg (Godot's
# per-folder settings override, untracked) that sets a 1920x1080 window and MJPEG quality (0.95 by default),
# and deletes it afterwards. The game's stretch base stays 1280x720, so the interface is scaled
# exactly as a player at 1080p sees it.
source "$(dirname "$0")/../lib/common.sh"
[ $# -ge 1 ] || { echo "usage: $0 <shot id> [--renderer R] [--tries N] [--limit S] [--quality Q] [-- boot options]" >&2; exit 2; }
shot="$1"; shift
renderer="gl_compatibility"
tries=3
limit=900
quality=0.95
boot=()
while [ $# -gt 0 ]; do
	case "$1" in
		--renderer) renderer="$2"; shift 2 ;;
		--tries) tries="$2"; shift 2 ;;
		--limit) limit="$2"; shift 2 ;;
		--quality) quality="$2"; shift 2 ;;
		--) shift; boot=("$@"); break ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done
[ ${#boot[@]} -gt 0 ] || boot=("shot=$shot")
godot_env
clips="$USERDATA/trailer/clips"
mkdir -p "$clips"
avi="$clips/$shot.avi"
log="$clips/$shot.log"
override="$PROJECT_ROOT/override.cfg"

kill_capture() {
	# The console wrapper starts the real Godot as a child; find it by the movie path and stop it.
	powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*clips/$shot.avi*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1 || true
}
cleanup() {
	kill_capture
	rm -f "$override"
}
trap cleanup EXIT

cat >"$override" <<EOF
[display]

window/size/window_width_override=1920
window/size/window_height_override=1080

[editor]

movie_writer/mjpeg_quality=$quality
EOF

# A script added since the last import is not in the class cache yet.
cache="$PROJECT_ROOT/.godot/global_script_class_cache.cfg"
if [ ! -f "$cache" ] || [ -n "$(find "$PROJECT_ROOT/scripts/trailer" -newer "$cache" -name '*.gd' 2>/dev/null)" ]; then
	echo "importing (class cache is older than scripts/trailer)"
	"$GODOT" --headless --path "$(native "$PROJECT_ROOT")" --import >"$clips/import.log" 2>&1 || true
	touch "$cache"
fi

for attempt in $(seq 1 "$tries"); do
	rm -f "$avi"
	set +e
	timeout --kill-after=5 "$limit" "$GODOT" --path "$(native "$PROJECT_ROOT")" --rendering-method "$renderer" \
		--resolution 1920x1080 --fixed-fps 60 --write-movie "$(native "$avi")" -- \
		scene=res://scenes/trailer/director.tscn "${boot[@]}" >"$log" 2>&1
	rc=$?
	set -e
	kill_capture
	sanitize_paths "$log"
	if [ "$rc" -eq 0 ] && grep -q '^TRAILER_OUT' "$log" && [ -s "$avi" ] \
		&& ! grep -qE 'SCRIPT ERROR|SHADER ERROR|Parse Error' "$log"; then
		echo "CAPTURED $shot (attempt $attempt): $(grep -E '^TRAILER_(IN|OUT)' "$log" | tr '\n' ' ')"
		grep -E '^TRAILER_CAST' "$log" || true
		exit 0
	fi
	echo "capture of $shot failed (attempt $attempt, exit $rc):"
	grep -E 'TRAILER_FAIL|TRAILER_CAST|SCRIPT ERROR|Parse Error|ERROR' "$log" | head -20
	grep -qE 'SCRIPT ERROR|Parse Error' "$log" && break
done
exit 1
