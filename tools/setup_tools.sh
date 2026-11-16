#!/usr/bin/env bash
# Recreate .tools/ from scratch (Windows x64, Git Bash). Idempotent: finished steps are skipped.
#   tools/setup_tools.sh            installs into <checkout root>/.tools
# Needs: curl, unzip, sha256sum/sha512sum, Python 3.9+ (py launcher or python on PATH), Node 18+.
# Writes nothing outside .tools/ (Godot templates live in .tools/godot/templates and are staged
# per checkout by the other scripts).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Windows programs (python, node) get Windows paths: Git Bash path conversion may be disabled.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }
T="$ROOT/.tools"
DL="$T/downloads"
mkdir -p "$DL"

GODOT_REL="https://github.com/godotengine/godot/releases/download/4.7.2-stable"
GODOT_ZIP="Godot_v4.7.2-stable_win64.exe.zip"
TPZ="Godot_v4.7.2-stable_export_templates.tpz"
BLENDER_URL="https://download.blender.org/release/Blender5.3"
BLENDER_ZIP="blender-5.3.0-windows-x64.zip"

fetch() {
	[ -f "$DL/$2" ] && return 0
	(cd "$DL" && curl -fL --retry 3 -o "$2.part" "$1/$2" && mv "$2.part" "$2") || { echo "download failed: $1/$2" >&2; exit 1; }
}

if [ ! -x "$T/godot/Godot_v4.7.2-stable_win64_console.exe" ] || [ ! -f "$T/godot/templates/4.7.2.stable/web_nothreads_release.zip" ]; then
	fetch "$GODOT_REL" SHA512-SUMS.txt
	fetch "$GODOT_REL" "$GODOT_ZIP"
	fetch "$GODOT_REL" "$TPZ"
	(cd "$DL" && grep -E " ($GODOT_ZIP|$TPZ)\$" SHA512-SUMS.txt | sha512sum -c -)
	mkdir -p "$T/godot/templates/4.7.2.stable"
	unzip -o -q "$DL/$GODOT_ZIP" -d "$T/godot"
	# Only the web templates are kept (about 90 MB of the 1.2 GB bundle).
	unzip -o -q -j "$DL/$TPZ" 'templates/web_*' 'templates/version.txt' -d "$T/godot/templates/4.7.2.stable"
fi
"$T/godot/Godot_v4.7.2-stable_win64_console.exe" --version

if [ ! -x "$T/blender-5.3.0-windows-x64/blender.exe" ]; then
	fetch "$BLENDER_URL" blender-5.3.0.sha256
	fetch "$BLENDER_URL" "$BLENDER_ZIP"
	(cd "$DL" && grep " $BLENDER_ZIP\$" blender-5.3.0.sha256 | sha256sum -c -)
	unzip -o -q "$DL/$BLENDER_ZIP" -d "$T"
fi
"$T/blender-5.3.0-windows-x64/blender.exe" --version | head -1

if [ ! -x "$T/venv/Scripts/python.exe" ]; then
	if command -v python >/dev/null 2>&1; then python -m venv "$(native "$T/venv")"; else py -3 -m venv "$(native "$T/venv")"; fi
	"$T/venv/Scripts/python.exe" -m pip install -q --upgrade pip
	"$T/venv/Scripts/python.exe" -m pip install -q "numpy==2.0.2" "Pillow==11.3.0" "scipy==1.13.1" "soundfile==0.13.1"
fi
"$T/venv/Scripts/python.exe" -c "import sys, numpy, PIL; print('python', sys.version.split()[0], 'numpy', numpy.__version__, 'Pillow', PIL.__version__)"

if [ ! -d "$T/node/node_modules/puppeteer-core" ]; then
	mkdir -p "$T/node"
	(cd "$T/node" && { [ -f package.json ] || npm init -y >/dev/null; } && npm install --no-audit --no-fund "puppeteer-core@25.17.0")
fi
node -e "console.log('puppeteer-core', require(process.argv[1] + '/package.json').version)" "$(native "$T/node/node_modules/puppeteer-core")"

# The archives are only needed to recreate the above; drop them to save about 1.7 GB.
rm -f "$DL/$GODOT_ZIP" "$DL/$TPZ" "$DL/$BLENDER_ZIP"
du -sh "$T" | sed 's#\t.*##; s#^#.tools/ uses #'
echo "TOOLS OK"
