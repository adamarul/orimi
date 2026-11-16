# QA harness

Owner: QA (ws/qa). Everything here proves a line of the definition of done in docs/BRIEF.md
against the real builds. The gate is one command:

    QA_BANNED_TERMS=... QA_BANNED_WORDS=... tools/qa/dod.sh            full gate (15-25 min once the game exists)
    tools/qa/dod.sh --quick                                             static checks only, seconds
    tools/qa/dod.sh --only web_brush,web_full   /   --skip web_perf   /   --no-export

It prints a table (DoD line, check, PASS / FAIL / NOT YET, evidence) and writes it to
docs/qa/evidence/dod.md. Exit 0 all PASS, 1 any FAIL, 3 something NOT YET or NOT RUN.
Every row runs alone with `tools/qa/qa.sh <check>` (list: `tools/qa/qa.sh` with no argument).
`tools/qa/selftest.sh` proves each check passes on good input and catches a planted defect
(results in docs/qa/evidence/selftest.md).

The banned-term list is the lead's list. It is never stored in the repository: pass it at run time
in QA_BANNED_TERMS (substring, any case, accents folded) and QA_BANNED_WORDS (whole words, for
short names), comma separated. Findings name the term by its position in the list, never by text.

## Pieces

| Path | What |
| - | - |
| tools/qa/dod.sh | the gate |
| tools/qa/qa.sh | runs one check; prints `QA_RESULT <status> <evidence> <detail>` |
| tools/qa/scan_terms.py | banned terms and absolute paths: every project file (text and binary), build/web, commit messages, branch names |
| tools/qa/glb_tris.py | triangles per .glb/.gltf from the glTF JSON, counted per rendered node instance |
| tools/qa/provenance.py | every model/texture/audio file listed, with a matching sha256, in a provenance manifest that names a generator script in the repo |
| tools/qa/shader_docs.py | every uniform of every .gdshader/.gdshaderinc named in docs/SHADERS.md or docs/SHADERS_VFX.md beside or under its shader's file name |
| tools/qa/licences.py | fonts and files in addons/, vendor/, third_party/ have a licence file beside them |
| tools/qa/docs_check.py | README (title, desktop and browser run, controls, glyph guide, credits/licences, embedded Light/Normal/Heavy screenshots incl. a web one), docs/SHADERS.md, docs/screenshots/ |
| tools/qa/contract.py + tests/contract/ | headless dump of every contract autoload and class compared with tests/contract/api_baseline.json (taken from the lead's stubs); contract scenes (models with InkLook, %AnimationPlayer, animation names, Smear keys, terrain markers) |
| tools/qa/web.cjs | browser runner: smoke, input, brush, full, manual, perf, paper |
| tools/qa/imgstats.py | sepia and paper-direction image statistics |
| tests/qa/qa_host.tscn, qa_probe.gd | QA probe: loads the scene under test and prints `QAPROBE:{json}` (every Events signal, snapshots, targets with screen positions, frame statistics); page JS talks to it through `window.orimiQA(cmd)` |
| tests/fixtures/qa_fixture.tscn | a stand-in game used only by the self-test, with `defect=` modes |

## How the browser checks drive the game

They load `index.html?scene=res://tests/qa/qa_host.tscn&target=res://scenes/game/main.tscn&...`.
The host adds the probe under the root (it survives scene changes) and switches to the target.
Input is real: puppeteer key events (`KeyW`, `ShiftLeft`, ...), mouse clicks that take pointer lock,
mouse moves, and pointer strokes. What the game did is read from the console: the probe's event and
snapshot lines and gameplay's own `QA:` lines. A console error, shader error, page error or failed
request fails every browser check.

Limits: Chrome's own Escape handling cannot be synthesised, so "Escape" is tested as the pause action
and a capture lost to the browser is simulated with `document.exitPointerLock()`. Frame rate is
measured headless on the real GPU (ANGLE D3D11); the uncapped run uses Chrome's
`--disable-frame-rate-limit --disable-gpu-vsync`.

## What the other workstreams need to give QA

**Everyone who generates media** (assets, render, vfx, brush): each generator script writes a
manifest beside its outputs, named `<generator name>.provenance.json` (or `provenance.json`),
repository-relative paths, forward slashes:

```json
{
  "generator": "tools/blender/fox.py",
  "command": "tools/blender/run.sh fox",
  "outputs": [
    {"path": "assets/characters/fox.glb", "sha256": "<hex of the file as written>"},
    {"path": "assets/characters/fox_albedo.png", "sha256": "<hex>", "generator": "tools/textures/painted/fox.py"}
  ]
}
```

Rewrite it on every run. A file edited after generation no longer matches its hash and fails.

**Gameplay:** `Game.debug_snapshot()` with these keys: `state`, `player_pos` ([x, y, z]), `hp`, `max_hp`,
`ink`, `zones_restored` (ids), `enemies_alive`. `qa_log` tags at least: `state`, `zone_restored`,
`enemy_died`, `glyph_cast`, `finale`, `valley_restored`, `end_card`. The title screen starts on Enter
or a click. The thorn gate node's name contains "Thorn" or "Gate" and it is in group `brush_target`.
The end card sets state `ended`. Escape (the pause action) pauses and frees the mouse; a lost capture
pauses. `warp`, `god` and `autoplay` as in CONTRACTS.md.

**Brush:** document in docs/BRUSH.md the stroke shape each template expects (especially what a
"loop" is: the runner draws a line with one curl in the middle) so the scripted strokes match;
emit `glyph_cast` even when nothing was hit.

**Render / vfx:** document each uniform in a table row (or under a heading) that names its shader
file, e.g. `| ink_toon.gdshader | band_soft | ... |`.

## Evidence size

docs/qa/ stays near 5 MB. Captures go under docs/ as JPEGs (stack 1280 px at quality 72, other
evidence 960 px at quality 62, by tools/qa/shrink.py); the full-size PNGs used for image statistics,
whole console logs, export and desktop logs stay under .userdata/qa/ (not committed). Logs under
docs/ are the marker and error lines plus a tail. Self-test captures never go under docs/. The
paper screenshots in docs/screenshots/ stay PNG because README shows them.
