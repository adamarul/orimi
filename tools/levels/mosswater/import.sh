#!/usr/bin/env bash
# Godot import settings for Mosswater Wood's assets: import, write the external materials and
# patch the .import files (tools/levels/mosswater/godot_import_mw.py), re-import, check.
#   tools/levels/mosswater/import.sh
source "$(dirname "$0")/../../lib/common.sh"
cd "$PROJECT_ROOT"
godot_env
mkdir -p .userdata/mw
"$GODOT" --headless --path . --import > .userdata/mw/import.log 2>&1 || true
"$VENV_PY" -I -B tools/levels/mosswater/godot_import_mw.py
for f in $(git status --porcelain --untracked-files=all -- assets/levels/mosswater | awk '{print $2}' | grep '\.import$' || true); do
	src="${f%.import}"
	rm -f .godot/imported/"$(basename "$src")"-*.md5
done
"$GODOT" --headless --path . --import >> .userdata/mw/import.log 2>&1 || true
"$VENV_PY" -I -B tools/levels/mosswater/godot_import_mw.py --check
