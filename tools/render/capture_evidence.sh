#!/usr/bin/env bash
# Capture the render demo evidence set into .userdata/render_demo/ (render workstream). Full-size
# PNGs stay out of git; docs/render/ keeps downsized JPEGs of the real game only.
#   tools/render/capture_evidence.sh [--skip-export]
# Desktop (Forward+) and web (Compatibility) at Light / Normal / Heavy, plus web close-ups of the
# line work, the cursed rim, the restoration front and the character preset. Opens short game
# windows on the desktop.
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
out=.userdata/render_demo
mkdir -p "$out"
scene=scene=res://scenes/dev/render_demo.tscn
status=0
for p in light normal heavy; do
	tools/screenshot_desktop.sh "$out/desktop_$p.png" "$scene" paper=$p curse=cursed shot_after=3 >/dev/null 2>&1 || { echo "desktop $p FAILED"; status=1; }
	echo "desktop $p: $(tail -c 300 "$out/desktop_$p.log" | grep -o 'ORIMI_SCREENSHOT.*' | head -1)"
done
if [ "${1:-}" != "--skip-export" ]; then
	tools/export_web.sh >/dev/null 2>&1 || { echo "export FAILED"; exit 1; }
fi
shot() {
	local name="$1"; shift
	tools/smoke_web.sh --no-input --hold 4 --shot "$out/$name.png" --log "$out/$name.txt" "$scene" "$@" >/dev/null 2>&1 && echo "web $name: ok" || { echo "web $name FAILED"; status=1; }
}
for p in light normal heavy; do shot "web_$p" paper=$p curse=cursed; done
shot web_closeup_line view=line curse=clean gloom=0
shot web_closeup_rim view=rim curse=cursed
shot web_closeup_front view=front curse=0.45
shot web_closeup_char view=char curse=clean gloom=0
exit $status
