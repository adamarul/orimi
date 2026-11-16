#!/usr/bin/env bash
# Capture a screenshot from the real running game on desktop (Forward+), then quit.
#   tools/screenshot_desktop.sh out.png [shot_after=4] [scene=res://...] [paper=heavy] ...
# Opens a game window for a few seconds. Exit 1 if no PNG was written or the run logged errors.
source "$(dirname "$0")/lib/common.sh"
[ $# -ge 1 ] || { echo "usage: $0 <out.png> [boot options...]" >&2; exit 2; }
out="$1"; shift
mkdir -p "$(dirname "$out")"
out_abs="$(native "$(cd "$(dirname "$out")" && pwd)/$(basename "$out")")"
rm -f "$out"
godot_env
has_shot_after=0
for a in "$@"; do case "$a" in shot_after=*) has_shot_after=1 ;; esac; done
extra=()
[ "$has_shot_after" -eq 1 ] || extra+=("shot_after=4")
log="${out%.png}.log"
"$GODOT" --path "$(native "$PROJECT_ROOT")" -- "screenshot=$out_abs" "${extra[@]}" "$@" >"$log" 2>&1 && rc=0 || rc=$?
sanitize_paths "$log"
cat "$log"
if [ "$rc" -ne 0 ] || [ ! -f "$out" ] || grep -qE 'SCRIPT ERROR|SHADER ERROR|Parse Error|^ERROR|[^_]ERROR:' "$log"; then
	echo "SCREENSHOT FAILED (exit $rc), log: $log"
	exit 1
fi
echo "SCREENSHOT OK: $out (log: $log)"
