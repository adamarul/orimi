#!/usr/bin/env bash
# Desktop (Forward+) capture of the vfx demo: one PNG per effect at its peak (owner: vfx).
#   tools/vfx/shots_desktop.sh <out_dir> [boot options...]     e.g. foliage=500 only=gust
# Runs scenes/dev/vfx_demo.tscn windowed with peak_pause and vfx_shots, one pass, then quits.
# Writes <out_dir>/desktop.log (paths sanitised). Exit 1 on errors (shader errors included).
source "$(dirname "$0")/../lib/common.sh"
[ $# -ge 1 ] || { echo "usage: $0 <out_dir> [boot options...]" >&2; exit 2; }
out="$1"; shift
mkdir -p "$out"
out_abs="$(native "$(cd "$out" && pwd)")"
godot_env
log="$out/desktop.log"
timeout 300 "$GODOT" --path "$(native "$PROJECT_ROOT")" -- scene=res://scenes/dev/vfx_demo.tscn once=1 "vfx_shots=$out_abs" "$@" >"$log" 2>&1 && rc=0 || rc=$?
sanitize_paths "$log"
grep -E 'VFX_|ERROR|SHADER|FPS' "$log" | head -80
if [ "$rc" -ne 0 ] || grep -qE 'SCRIPT ERROR|SHADER ERROR|Parse Error|^ERROR|[^_]ERROR:' "$log" || ! grep -q VFX_DEMO_DONE "$log"; then
	echo "VFX SHOTS FAILED (exit $rc), log: $log"
	exit 1
fi
echo "VFX SHOTS OK: $out"
