#!/usr/bin/env bash
# Light pools and curse evidence (render workstream, scratch): web captures of render_lights and
# two valley warps, once with the shaders of a given commit and once with HEAD.
#   tools/render/capture_lights.sh <out-dir> <before-commit>
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
out="$1"; before="$2"
mkdir -p "$out"
scene=scene=res://scenes/dev/render_lights.tscn
web() { tools/smoke_web.sh --no-input --hold "$1" --shot "$out/$2.png" --log "$out/$2.txt" "${@:3}" >/dev/null 2>&1; [ -f "$out/$2.png" ] && echo "web $2 ok" || echo "web $2 MISSING"; }
set_shaders() {
	git checkout "$1" -- shaders/render scripts/render/curse_field.gd
}
set_shaders "$before"
tools/export_web.sh >/dev/null 2>&1 || { set_shaders HEAD; echo "export FAILED"; exit 1; }
web 8 before_curse $scene mode=none curse=1 view=curse lit=0
web 22 before_M_ZoneA warp=M_ZoneA god=1
web 22 before_M_ZoneB warp=M_ZoneB god=1
set_shaders HEAD
git status --short shaders/render scripts/render
tools/export_web.sh >/dev/null 2>&1 || { echo "export FAILED"; exit 1; }
web 8 after_curse $scene mode=none curse=1 view=curse lit=0
web 22 after_M_ZoneA warp=M_ZoneA god=1
web 22 after_M_ZoneB warp=M_ZoneB god=1
for m in drained dark; do for n in 0 1 2 3; do web 8 ${m}_$n $scene mode=$m lit=$n; done; done
web 8 drained_close $scene mode=drained lit=1 view=close
web 8 dark_close $scene mode=dark lit=1 view=close
