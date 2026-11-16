#!/usr/bin/env bash
# Regenerate every sound effect and music track (the vale's and the level themes under audio/levels/),
# their level reports and the plots under docs/assets/.
#   tools/assets/gen_audio.sh
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
mkdir -p .userdata/audio docs/assets/audio
"$VENV_PY" -I -B -u "$(native tools/audio/sfx.py)" "$(native audio/sfx)" "$(native .userdata/audio/sfx.json)"
"$VENV_PY" -I -B -u "$(native tools/audio/music.py)" "$(native audio/music)" "$(native .userdata/audio/music.json)"
"$VENV_PY" -I -B -u "$(native tools/audio/level_music.py)" "$(native audio/levels)" "$(native .userdata/audio/level_music.json)"
"$VENV_PY" -I -B -u "$(native tools/audio/plots.py)" "$(native audio)" "$(native docs/assets/audio)" "$(native .userdata/audio)"
cp .userdata/audio/sfx.json docs/assets/audio/sfx_levels.json
cp .userdata/audio/music.json docs/assets/audio/music_levels.json
cp .userdata/audio/level_music.json docs/assets/audio/level_music_levels.json
"$VENV_PY" -I -B "$(native tools/assets/write_provenance.py)"
echo "AUDIO OK"
