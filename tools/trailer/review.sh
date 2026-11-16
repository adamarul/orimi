#!/usr/bin/env bash
# Review sheet for one captured shot: a frame every STEP seconds (default 0.5) from its TRAILER_IN
# mark to TRAILER_OUT, left to right then down, written to .userdata/trailer/review/<shot>.jpg.
# Used to choose the in and out points in tools/trailer/cut.json.
#   tools/trailer/review.sh <shot id> [step]
source "$(dirname "$0")/../lib/common.sh"
shot="$1"; step="${2:-0.5}"
FF="$TOOLS_DIR/ffmpeg/bin/ffmpeg.exe"
clips="$USERDATA/trailer/clips"
mkdir -p "$USERDATA/trailer/review"
fin=$(grep -oE '^TRAILER_IN frame=[0-9]+' "$clips/$shot.log" | grep -oE '[0-9]+$')
fout=$(grep -oE '^TRAILER_OUT frame=[0-9]+' "$clips/$shot.log" | grep -oE '[0-9]+$')
every=$("$(python_bin)" -I -c "print(round(float('$step')*60))")
count=$(( (fout - fin) / every + 1 ))
cols=6
rows=$(( (count + cols - 1) / cols ))
"$FF" -v error -y -i "$(native "$clips/$shot.avi")" -vf "select='gte(n\,$fin)*not(mod(n-$fin\,$every))',scale=320:180,tile=${cols}x${rows}:padding=2:color=white" \
	-frames:v 1 -q:v 4 "$(native "$USERDATA/trailer/review/$shot.jpg")"
echo "$shot: $count frames, step $step s, in=$fin out=$fout -> .userdata/trailer/review/$shot.jpg"
