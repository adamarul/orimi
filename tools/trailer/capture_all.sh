#!/usr/bin/env bash
# Capture every shot in scripts/trailer/shots.json (or the ids given) with tools/trailer/capture.sh,
# one Godot window at a time. Writes .userdata/trailer/clips/<id>.avi and <id>.log.
#   tools/trailer/capture_all.sh [shot id ...]
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
if [ $# -gt 0 ]; then
	ids=("$@")
else
	mapfile -t ids < <("$(python_bin)" -I -c "import json,sys; [print(s['id']) for s in json.load(open(sys.argv[1], encoding='utf-8'))['shots']]" "$(native scripts/trailer/shots.json)" | tr -d '\r')
fi
failed=()
for id in "${ids[@]}"; do
	"$(dirname "$0")/capture.sh" "$id" || failed+=("$id")
done
if [ ${#failed[@]} -gt 0 ]; then
	echo "CAPTURE FAILED: ${failed[*]}"
	exit 1
fi
echo "CAPTURE ALL OK (${#ids[@]} shots)"
