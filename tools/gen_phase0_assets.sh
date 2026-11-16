#!/usr/bin/env bash
# Regenerate every phase 0 asset from its script: glTF probe mesh (Blender, headless),
# probe audio and the project icon (Python venv).
source "$(dirname "$0")/lib/common.sh"
cd "$PROJECT_ROOT"
blender_env
"$BLENDER" --background --factory-startup --python "$(native tools/blender/phase0_vcol_probe.py)" -- "$(native assets/phase0/vcol_probe.glb)"
[ -f assets/phase0/vcol_probe.glb ] || { echo "Blender export failed"; exit 1; }
"$VENV_PY" -I tools/gen/phase0_audio.py audio/phase0/probe_chime.wav
"$VENV_PY" -I tools/gen/icon.py ui/icon.png
echo "ASSETS OK"
