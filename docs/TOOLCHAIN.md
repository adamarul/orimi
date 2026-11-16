# Toolchain

Everything third-party lives in `.tools/` at the top-level checkout (git-ignored). Nothing is installed
system-wide, and nothing in the scripts writes outside the project folder: Godot's and Blender's
user directories are redirected into each checkout's `.userdata/` (also git-ignored).

## Versions and sources

| Tool | Version | Source | Verified |
| - | - | - | - |
| Godot editor (standard, non-.NET), Windows x86_64 | 4.7.2.stable.official.ed1daf0bf | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip | SHA-512 against the release's SHA512-SUMS.txt |
| Godot export templates (web only kept) | 4.7.2.stable | https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz | SHA-512 against SHA512-SUMS.txt |
| Blender, portable zip, Windows x64 | 5.3.0 (hash 02f0899d78e3) | https://download.blender.org/release/Blender5.3/blender-5.3.0-windows-x64.zip | SHA-256 against blender-5.3.0.sha256 |
| Python venv | Python 3.9.0 (system C:Python39 as base), numpy 2.0.2, Pillow 11.3.0, scipy 1.13.1, soundfile 0.13.1 (writes OGG Vorbis) | PyPI | import check |
| puppeteer-core (drives the installed Chrome; no browser download) | 25.17.0 | npm | require check |
| Chrome (installed, not managed here) | 157.0.8103.51 | system | reported by the smoke check |
| Node (system) | 24.18.0 | system | |

numpy 2.0.2 and Pillow 11.3.0 are the newest releases that support Python 3.9; moving to a newer
Python would allow newer versions. Pillow 11.3.0 prints a deprecation warning for `Image.fromarray(..., mode)`;
do not pass `mode`.

Layout:

```
.tools/
  godot/Godot_v4.7.2-stable_win64.exe            GUI editor
  godot/Godot_v4.7.2-stable_win64_console.exe    console wrapper (used by every script)
  godot/templates/4.7.2.stable/                  web_*.zip + version.txt (from the .tpz)
  blender-5.3.0-windows-x64/blender.exe
  venv/                                          python + numpy + Pillow
  node/node_modules/puppeteer-core
  downloads/                                     checksum files only (archives are deleted)
```

Disk use: 1.4 GB (Blender 972 MB, Godot + web templates 257 MB, venv 95 MB, node 31 MB).

## Recreate .tools/ from scratch

```
tools/setup_tools.sh
```

It downloads the three archives, verifies the published checksums, extracts Godot, the web
templates only (about 90 MB of the 1.2 GB bundle) and Blender, creates the venv, installs
puppeteer-core, prints every version, then deletes the archives. It is idempotent: finished steps
are skipped. Tested from an empty folder (all steps) and against the existing `.tools/` (skip path).
The equivalent manual commands are the ones inside the script.

## Scripts (run from the checkout root, Git Bash)

| Command | What it does |
| - | - |
| `tools/run_desktop.sh [key=value ...]` | Runs the game on desktop (Forward+). Arguments are boot options. |
| `tools/check.sh [key=value ...]` | Headless check: imports, loads every `.gd`, `.tscn` and `.tres` outside hidden/.gdignore folders from inside the running game (so autoloads resolve), then boots the main scene headless with `quit_after=3`. Exit 1 on any parse error, any ERROR line, or a missing first-frame marker. Shaders are not compiled headless. |
| `tools/export_web.sh [--debug]` | Exports the Web preset to `build/web/index.html` (log: `build/export_web.log`, paths sanitised). Exit 1 if a file is missing or the log has an error. |
| `tools/serve_web.sh [port]` | Serves `build/web` on 127.0.0.1; port 0 (default) picks a free one and prints `SERVING <url>`. |
| `tools/screenshot_desktop.sh out.png [key=value ...]` | Runs the real game in a window, saves the viewport image after `shot_after` seconds (default 4) and quits. Writes `out.log` next to it with absolute paths replaced by `<project>`. Exit 1 on errors (including shader errors). |
| `tools/smoke_web.sh [options] [key=value ...]` | Browser smoke check, see below. |
| `tools/gen_phase0_assets.sh` | Regenerates the phase 0 glTF (Blender headless), probe audio and icon. |
| `tools/editor.sh` | Opens the editor with the same redirected directories, so web export from the editor finds the templates. |
| `tools/setup_tools.sh` | Recreates `.tools/`. |

Boot options (scripts/core/boot.gd) are the same on desktop (after `--`) and web (URL query):
`scene`, `screenshot` (desktop only), `shot_after`, `quit_after`, `paper`, and anything else via
`Boot.opt(key, default)`. The boot scene prints `ORIMI_FIRST_FRAME` once the loaded scene has drawn a
frame. A missing scene prints an error and exits with code 1.

**Browser smoke check.** Starts the server on a free port, launches the installed Chrome through
puppeteer-core with a fresh profile under `.userdata/chrome/` (deleted afterwards), opens
`index.html?<key=value...>`, waits for `ORIMI_FIRST_FRAME`, clicks the canvas (user gesture for audio
and pointer lock), sends a synthetic pen stroke, holds the page `--hold` seconds (default 6), measures
the requestAnimationFrame rate and collects the game's `ORIMI_FPS` lines, then screenshots.
It fails on any console error, page error, failed request or HTTP status >= 400, a missing
marker, missing WebGL 2, or a software rasteriser (SwiftShader etc.; override with
`--allow-software`). Options: `--headed`, `--hold S`, `--shot PATH`, `--log PATH`, `--timeout S`, `--no-input`, `--reload` (also time a warm-cache reload), `--dir PATH`.
It runs **headless** by default, and headless Chrome on this PC uses the real GPU:
`ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 Direct3D11 vs_5_0 ps_5_0, D3D11)`, WebGL 2.0 (OpenGL ES 3.0).

Evidence logs: the scripts replace absolute paths with `<project>` (and the folder holding `.tools/`
with `<tools-root>` inside a worktree) before writing, so logs can be kept under `docs/`.

## Worktrees

Every script locates `.tools/` by walking up from its own folder, so the same scripts work in
`.worktrees/<name>/` (override with `ORIMI_TOOLS_DIR`). Tested: a throwaway worktree with only the phase 0
skeleton ran the headless check, web export, browser smoke check (with `--reload`) and a desktop
screenshot, all passing, while the top-level checkout ran the same scripts at the same time.

Keep worktree names short. Godot's shader cache uses paths about 200 characters long below the
user directory; the scripts shorten the user directory (`.userdata/a`, and project.godot sets
`config/use_custom_user_dir` with the name `orimi`), but git still refused to delete the first test
worktree with "Filename too long" before that change. If it happens: `git -c core.longpaths=true worktree remove --force <path>`,
then delete what is left with PowerShell `Remove-Item -LiteralPath '\\?\<absolute path>' -Recurse -Force`.

This shell has `MSYS_NO_PATHCONV=1`, so Git Bash does not convert `/d/...` paths for Windows
programs. The scripts always pass Windows-style paths (`cygpath -m`) to Godot, Blender, Python and
Node; keep doing that in new scripts, or a Windows program receives `/d/x` and writes to `D:\d\x`.

## Running things at the same time

What is isolated per run or per checkout:

- **Godot user data and editor settings.** The scripts set `APPDATA` and `LOCALAPPDATA` for Godot to
  `<checkout>/.userdata/a` and `.userdata/l`. Editor settings, the editor doc cache, export template
  lookup, the game's `user://` (logs, shader cache) all live there, so different checkouts share
  nothing. Godot's real `%APPDATA%\Godot` was not touched by any run (checked after all runs).
- **Export templates** are copied (about 20 MB) from `.tools/` into the checkout's `.userdata/` on
  export; `.tools/` is only read. A `find .tools -newer` after all runs showed no writes.
- **Server port**: free port per run. **Browser profile**: new directory per run, removed afterwards.
- **Blender** user resources go to `.userdata/blender` (`BLENDER_USER_RESOURCES`).

Observed: two checkouts ran the headless check and web export simultaneously, then two browser
smoke checks and two desktop screenshot runs simultaneously (four Godot/Chrome processes): all
passed, no shared-file errors. Contention only slowed things: web first frame took 25 s instead of
11 s, and a fresh worktree's first desktop launch took 17 s (import plus a cold shader cache).

Not safe to run concurrently **within one checkout**:

- two runs that import or export (`check.sh`, `export_web.sh`, `editor.sh`): they write the same
  `.godot/` import cache and `build/web/`;
- a smoke check while `export_web.sh` is rewriting `build/web/`;
- two desktop runs of the game share `.userdata/a/orimi/` (logs and shader cache). One desktop
  screenshot and one browser smoke check in the same checkout at the same time worked.

## Known gaps

- Shader compile errors only surface in windowed desktop runs and in the browser, not in
  `check.sh` (headless uses a dummy renderer).
- `check.sh` parses every script in the checkout, including other workstreams' work in progress.
