# Sourced by every tools/*.sh script. Do not run directly.
# Resolves this checkout's root and the shared .tools/ directory, which may live in a parent
# folder (git worktrees under .worktrees/<name>/ share the top-level .tools/).
set -euo pipefail

TOOLS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$TOOLS_SCRIPT_DIR/.." && pwd)"

find_tools_dir() {
	local d="$TOOLS_SCRIPT_DIR" parent
	while :; do
		if [ -d "$d/.tools/godot" ]; then
			echo "$d/.tools"
			return 0
		fi
		parent="$(dirname "$d")"
		[ "$parent" = "$d" ] && return 1
		d="$parent"
	done
}

if [ -n "${ORIMI_TOOLS_DIR:-}" ]; then
	TOOLS_DIR="$ORIMI_TOOLS_DIR"
elif ! TOOLS_DIR="$(find_tools_dir)"; then
	echo "error: no .tools/ directory found above $TOOLS_SCRIPT_DIR (run tools/setup_tools.sh)" >&2
	exit 2
fi

GODOT_VERSION_DIR="4.7.2.stable"
GODOT="$TOOLS_DIR/godot/Godot_v4.7.2-stable_win64_console.exe"
GODOT_GUI="$TOOLS_DIR/godot/Godot_v4.7.2-stable_win64.exe"
BLENDER="$TOOLS_DIR/blender-5.3.0-windows-x64/blender.exe"
VENV_PY="$TOOLS_DIR/venv/Scripts/python.exe"
USERDATA="$PROJECT_ROOT/.userdata"

native() {
	if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi
}

# Godot keeps editor settings, caches, export templates and the game's user:// data under
# %APPDATA% (and a doc cache under %LOCALAPPDATA%). Point both at this checkout's .userdata/ so
# concurrent runs from different checkouts never share those files and nothing is written outside
# the project folder. The names are one letter because Godot's shader cache paths are long and
# Windows paths stop at 260 characters for many tools (git included).
godot_env() {
	mkdir -p "$USERDATA/a" "$USERDATA/l"
	export APPDATA="$(native "$USERDATA/a")"
	export LOCALAPPDATA="$(native "$USERDATA/l")"
}

# Copy the single-threaded web templates from .tools/ into this checkout's redirected template
# directory (about 20 MB). Reads .tools/, never writes it.
stage_web_templates() {
	local src="$TOOLS_DIR/godot/templates/$GODOT_VERSION_DIR"
	local dst="$USERDATA/a/Godot/export_templates/$GODOT_VERSION_DIR"
	mkdir -p "$dst"
	local f
	for f in version.txt web_nothreads_release.zip web_nothreads_debug.zip; do
		if [ ! -f "$dst/$f" ] || [ "$src/$f" -nt "$dst/$f" ]; then
			cp "$src/$f" "$dst/$f"
		fi
	done
}

blender_env() {
	mkdir -p "$USERDATA/blender"
	export BLENDER_USER_RESOURCES="$(native "$USERDATA/blender")"
}

# Replace absolute checkout paths in text files with <project> (and the folder holding .tools/
# with <tools-root> when it differs), so logs can be kept under docs/ without leaking local paths.
sanitize_paths() {
	local files=() f
	for f in "$@"; do files+=("$(native "$f")"); done
	"$(python_bin)" -I "$(native "$TOOLS_SCRIPT_DIR/lib/sanitize_paths.py")" "$(native "$PROJECT_ROOT")" "$(native "$(dirname "$TOOLS_DIR")")" "${files[@]}"
}

python_bin() {
	if [ -x "$VENV_PY" ]; then echo "$VENV_PY"; else command -v python3 || command -v python; fi
}
