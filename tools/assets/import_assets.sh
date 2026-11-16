#!/usr/bin/env bash
# Import everything, apply tools/assets/godot_import.py (materials, loops, texture settings), re-import.
source "$(dirname "$0")/../lib/common.sh"
cd "$PROJECT_ROOT"
godot_env
"$GODOT" --headless --path . --import > .userdata/import_assets.log 2>&1 || true
"$VENV_PY" -I -B tools/assets/godot_import.py
# Force a re-import of everything whose settings changed.
for f in $(git status --porcelain --untracked-files=all -- assets | awk '{print $2}' | grep '\.import$' || true); do
	src="${f%.import}"
	rm -f .godot/imported/"$(basename "$src")"-*.md5
done
"$GODOT" --headless --path . --import >> .userdata/import_assets.log 2>&1 || true
"$VENV_PY" -I -B tools/assets/godot_import.py --check
