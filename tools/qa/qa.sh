#!/usr/bin/env bash
# Run one QA check. Each prints "QA_RESULT <PASS|FAIL|NOT_YET|NOT_RUN> <evidence> <detail>" as its
# last line and exits 0 PASS, 1 FAIL, 3 NOT_YET, 4 NOT_RUN. tools/qa/dod.sh runs them all.
#
#   tools/qa/qa.sh <check> [args]
#
# Static:   terms [--terms a,b --words c,d]   banned terms (QA_BANNED_TERMS / QA_BANNED_WORDS) and absolute paths
#           tris                              triangles per glTF model (budget 5000)
#           provenance                        every model/texture/audio file tied to its generator by hash
#           shader_docs                       every shader uniform in docs/SHADERS.md or docs/SHADERS_VFX.md
#           licences                          fonts and third-party files have a licence beside them
#           docs                              README, docs/SHADERS.md, paper screenshots
#           contract                          contract API and deliverable scenes (headless Godot)
# Build:    check                             tools/check.sh
#           export                            fresh tools/export_web.sh
#           desktop                           fresh clone of HEAD: import, check.sh, windowed run of the main scene
#           desktop_scenes                    windowed run of the main scene and every scenes/dev/*_demo.tscn
# Browser:  web_smoke_main | web_smoke_demos | web_input | web_brush | web_full | web_level | web_level_<id> | web_resume | web_manual | web_perf | web_perf_tallowford | web_paper
# Static:   packed_exports                    no exported Packed*Array with a literal default (dropped by the web export)
#           web <mode> [options]              any tools/qa/web.cjs mode with your own options
# Visual:   paper_desktop                     Light/Normal/Heavy desktop captures into docs/screenshots/
#           stack                             rendering-stack captures from the full run exist (docs/qa/stack/)
# Audit:    originality                       reads the signed verdict line in docs/qa/ORIGINALITY.md
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
QA_DIR="$TOOLS_SCRIPT_DIR/qa"
EVID="$PROJECT_ROOT/docs/qa/evidence"
WORK="$PROJECT_ROOT/.userdata/qa"
MAIN_SCENE="scenes/game/main.tscn"
mkdir -p "$EVID" "$WORK"
export PYTHONDONTWRITEBYTECODE=1
cd "$PROJECT_ROOT"

py() { "$(python_bin)" -I "$(native "$QA_DIR/$1")" "${@:2}"; }
result() { echo "QA_RESULT $1 $2 $3"; case "$1" in PASS) exit 0 ;; FAIL) exit 1 ;; NOT_YET) exit 3 ;; *) exit 4 ;; esac; }
web() {
	export ORIMI_TOOLS_DIR="$(native "$TOOLS_DIR")" ORIMI_PROJECT_ROOT="$(native "$PROJECT_ROOT")" ORIMI_PYTHON="$(native "$(python_bin)")"
	node "$(native "$QA_DIR/web.cjs")" "$@"
}
ensure_import() { [ -d .godot/imported ] || { godot_env; "$GODOT" --headless --path . --import >/dev/null 2>&1 || true; }; }
demos() { ls scenes/dev/*_demo.tscn 2>/dev/null || true; }
error_re='SCRIPT ERROR|SHADER ERROR|USER ERROR|Parse Error|^ERROR|[^_]ERROR:'

# Windowed desktop run of one scene: screenshot + log under $EVID, fail on any error line.
desktop_run() { # <name> [boot options]
	local name="$1"; shift
	local out="$WORK/full/desktop_$name.png" rc=0
	mkdir -p "$WORK/full"
	tools/screenshot_desktop.sh "$out" shot_after=5 "$@" >"$WORK/desktop_$name.out" 2>&1 || rc=$?
	[ -f "$out" ] && py shrink.py "$(native "$out")" "$(native "$EVID/desktop_$name.jpg")" 960 70
	{ echo "# windowed run of $name: error lines, then the last 25 lines (full log: .userdata/qa/full/desktop_$name.log)"; { grep -E "$error_re" "$WORK/full/desktop_$name.log" 2>/dev/null || true; } | head -10; echo "# ..."; { tail -25 "$WORK/full/desktop_$name.log" 2>/dev/null || true; } | cut -c1-300; } >"$EVID/desktop_$name.log"
	sanitize_paths "$EVID/desktop_$name.log"
	if [ "$rc" -eq 0 ]; then echo "ok   $name"; return 0; fi
	echo "FAIL $name: $(grep -E "$error_re|SCREENSHOT FAILED" "$WORK/full/desktop_$name.log" "$WORK/desktop_$name.out" 2>/dev/null | head -3 | tr '\n' ' ')"
	return 1
}

check="${1:-}"; shift || true
case "$check" in
terms) py scan_terms.py "$@" ;;
tris) py glb_tris.py "$@" ;;
provenance) py provenance.py "$@" ;;
shader_docs) py shader_docs.py "$@" ;;
licences) py licences.py "$@" ;;
docs) py docs_check.py "$@" ;;
contract)
	ensure_import
	godot_env
	rm -f "$WORK/api.json"
	"$GODOT" --headless --path . -- scene=res://tests/contract/api_dump.tscn "out=$(native "$WORK/api.json")" >"$WORK/api_dump.log" 2>&1 || true
	if [ ! -f "$WORK/api.json" ] || grep -qE "$error_re" "$WORK/api_dump.log"; then
		sanitize_paths "$WORK/api_dump.log"; cp "$WORK/api_dump.log" "$EVID/contract_dump.log"
		result FAIL docs/qa/evidence/contract_dump.log "the API dump did not run cleanly (an autoload or contract script fails to load)"
	fi
	py contract.py --dump "$(native "$WORK/api.json")" "$@" ;;
check)
	tools/check.sh >"$WORK/check.out" 2>&1 && rc=0 || rc=$?
	sanitize_paths "$WORK/check.out"; cp "$WORK/check.out" "$EVID/check.txt"
	[ "$rc" -eq 0 ] && result PASS docs/qa/evidence/check.txt "tools/check.sh passed"
	result FAIL docs/qa/evidence/check.txt "tools/check.sh failed: $(grep -E 'FAIL|ERROR' "$WORK/check.out" | head -2 | tr '\n' ' ')" ;;
export)
	rm -rf build/web
	tools/export_web.sh >"$WORK/export.out" 2>&1 && rc=0 || rc=$?
	sanitize_paths "$WORK/export.out"; { echo "# tools/export_web.sh: error and warning lines, then the last 30 lines (full log: .userdata/qa/export.out)"; { grep -E "ERROR|WARNING|missing|FAILED" "$WORK/export.out" || true; } | head -20; echo "# ..."; tail -30 "$WORK/export.out" | cut -c1-300; } >"$EVID/export_web.txt"
	[ "$rc" -eq 0 ] && git rev-parse --short HEAD >build/web/qa_build.txt && result PASS docs/qa/evidence/export_web.txt "fresh web export of $(cat build/web/qa_build.txt) written to build/web ($(du -sh build/web | cut -f1))"
	result FAIL docs/qa/evidence/export_web.txt "export failed: $(grep -E 'ERROR|missing|FAILED' "$WORK/export.out" | head -2 | tr '\n' ' ')" ;;
desktop)
	fresh="$PROJECT_ROOT/.userdata/f"
	rm -rf "$fresh"
	git clone -q --no-hardlinks "$(native "$PROJECT_ROOT")" "$(native "$fresh")"
	sha="$(git -C "$(native "$fresh")" rev-parse --short HEAD)"
	rep="$EVID/desktop_fresh.txt"
	{
		echo "# Fresh clone of HEAD ($sha): first import, tools/check.sh, windowed run of the main scene"
		echo "Uncommitted changes are not part of this test."
		echo
		echo "## tools/check.sh in the fresh clone (imports from nothing)"
	} >"$rep"
	(cd "$fresh" && tools/check.sh) >"$WORK/fresh_check.out" 2>&1 && crc=0 || crc=$?
	{ { grep -E "$error_re|FAIL" "$WORK/fresh_check.out" || true; } | head -10; echo "# ... last 20 lines (full log: .userdata/qa/fresh_check.out)"; tail -20 "$WORK/fresh_check.out" | cut -c1-300; } >>"$rep"
	(cd "$fresh" && tools/screenshot_desktop.sh .userdata/shot.png shot_after=5) >"$WORK/fresh_run.out" 2>&1 && drc=0 || drc=$?
	{ echo; echo "## windowed desktop run (Forward+), main scene (last 25 lines)"; tail -25 "$WORK/fresh_run.out" | cut -c1-300; } >>"$rep"
	[ -f "$fresh/.userdata/shot.png" ] && py shrink.py "$(native "$fresh/.userdata/shot.png")" "$(native "$EVID/desktop_fresh.jpg")" 960 70
	"$(python_bin)" -I "$(native "$TOOLS_SCRIPT_DIR/lib/sanitize_paths.py")" "$(native "$fresh")" "$(native "$(dirname "$TOOLS_DIR")")" "$(native "$rep")"
	sanitize_paths "$rep"
	if [ "$crc" -ne 0 ] || [ "$drc" -ne 0 ]; then result FAIL docs/qa/evidence/desktop_fresh.txt "fresh clone $sha: check.sh exit $crc, windowed run exit $drc"; fi
	if grep -q 'scene=res://scenes/phase0' "$WORK/fresh_run.out"; then result NOT_YET docs/qa/evidence/desktop_fresh.txt "fresh clone $sha imports, checks and runs windowed clean, but boot fell back to the phase 0 probe: $MAIN_SCENE not delivered"; fi
	result PASS docs/qa/evidence/desktop_fresh.txt "fresh clone $sha imports, checks and runs windowed with no script or shader errors" ;;
desktop_scenes)
	rep="$EVID/desktop_scenes.txt"; fails=0; n=0
	echo "# Windowed desktop runs (Forward+): screenshot after 5 s, fail on any script or shader error" >"$rep"
	if [ -f "$MAIN_SCENE" ]; then desktop_run main >>"$rep" || fails=$((fails + 1)); n=$((n + 1)); else echo "NOT YET main: $MAIN_SCENE missing" >>"$rep"; fi
	for d in $(demos); do b="$(basename "$d" .tscn)"; desktop_run "$b" "scene=res://$d" >>"$rep" || fails=$((fails + 1)); n=$((n + 1)); done
	sanitize_paths "$rep"
	[ "$fails" -gt 0 ] && result FAIL docs/qa/evidence/desktop_scenes.txt "$fails of $n windowed run(s) logged errors: $(grep FAIL "$rep" | head -1)"
	{ [ "$n" -eq 0 ] || [ ! -f "$MAIN_SCENE" ]; } && result NOT_YET docs/qa/evidence/desktop_scenes.txt "$n scene(s) clean; main scene or demos not delivered yet"
	result PASS docs/qa/evidence/desktop_scenes.txt "$n scene(s) ran windowed with no errors" ;;
web) web "$@" ;;
web_smoke_main) web smoke --name smoke_main "$@" ;;
web_smoke_demos)
	rep="$EVID/web_smoke_demos.txt"; fails=0; n=0
	echo "# Browser smoke of every scenes/dev/*_demo.tscn" >"$rep"
	for d in $(demos); do
		b="$(basename "$d" .tscn)"; n=$((n + 1))
		line="$(web smoke --name "smoke_$b" "scene=res://$d" 2>&1 | grep '^QA_RESULT' || echo "QA_RESULT FAIL - runner crashed")"
		echo "$b: $line" >>"$rep"
		case "$line" in "QA_RESULT PASS"*) ;; *) fails=$((fails + 1)) ;; esac
	done
	[ "$n" -eq 0 ] && result NOT_YET docs/qa/evidence/web_smoke_demos.txt "no scenes/dev/*_demo.tscn yet"
	[ "$fails" -gt 0 ] && result FAIL docs/qa/evidence/web_smoke_demos.txt "$fails of $n demo(s) fail in the browser: $(grep -v PASS "$rep" | sed -n 2p)"
	result PASS docs/qa/evidence/web_smoke_demos.txt "$n demo(s) load clean in the browser" ;;
web_input | web_brush | web_full | web_manual | web_perf | web_paper) web "${check#web_}" "$@" ;;
web_level) web level --name level_example level=example "$@" ;;
web_level_*) id="${check#web_level_}"; web level --name "level_$id" "level=$id" "$@" ;;
web_perf_tallowford) web perf --name perf_tallowford level=tallowford warp=M_Square kindle=1 "$@" ;;
web_perf_sedge_plain) web perf --name perf_sedge_plain level=sedge_plain warp=M_Knoll "$@" ;;
web_perf_mosswater) web perf --name perf_mosswater level=mosswater warp=M_DarkHollow kindle=1 "$@" ;;
web_perf_kiln) web perf --name perf_kiln level=hollow_kiln warp=M_Arena_Entry walk=2 expect_qa=dregs_part "$@" ;;
web_resume) web resume "$@" ;;
web_resume_*) id="${check#web_resume_}"; web resume --name "resume_$id" "after=$id" "$@" ;;
packed_exports) py packed_exports.py "$@" ;;
paper_desktop)
	[ -f "$MAIN_SCENE" ] || result NOT_YET - "$MAIN_SCENE not delivered; no valley to capture"
	mkdir -p docs/screenshots; fails=0
	idx=0
	notes=""
	for lvl in light normal heavy; do
		# The level comes from the paper= boot option (the QA hook in CONTRACTS.md). A capture counts only if
		# the game was playing before the shot and the probe saw Settings at this level; a slow machine
		# gets one retry with a longer wait.
		ok=0
		for after in 9 20; do
			tools/screenshot_desktop.sh "docs/screenshots/valley_${lvl}_desktop.png" scene=res://tests/qa/qa_host.tscn god=1 warp=M_Spawn "paper=$lvl" shot_after=$after "$@" >"$WORK/paper_$lvl.out" 2>&1 || continue
			pre="$(sed -n '/ORIMI_SCREENSHOT/q;p' "$WORK/paper_$lvl.out")"
			if echo "$pre" | grep -q '"state":"playing"' && echo "$pre" | grep '^QAPROBE:.*"paper":' | tail -1 | grep -q '"paper":'"$idx"'[,}]'; then ok=1; break; fi
			notes+="$lvl: not playing at level $idx after $after s; "
		done
		[ "$ok" -eq 1 ] || fails=$((fails + 1))
		rm -f "docs/screenshots/valley_${lvl}_desktop.log"
		idx=$((idx + 1))
	done
	stats="$(py imgstats.py paper docs/screenshots/valley_light_desktop.png docs/screenshots/valley_normal_desktop.png docs/screenshots/valley_heavy_desktop.png || true)"
	{ echo "# Desktop paper captures (Forward+)"; echo "windowed runs failing: $fails"; echo "retries: ${notes:-none}"; echo '~~~'; echo "$stats"; echo '~~~'; } >"$EVID/paper_desktop.md"
	[ "$fails" -gt 0 ] && result FAIL docs/qa/evidence/paper_desktop.md "$fails capture(s) never showed the game playing at the requested paper level: $notes"
	echo "$stats" | grep -q '"pass": true' && result PASS docs/qa/evidence/paper_desktop.md "Light < Normal < Heavy on desktop"
	result FAIL docs/qa/evidence/paper_desktop.md "desktop captures do not move in the expected direction: $(echo "$stats" | grep -o '"summary": "[^"]*"')" ;;
stack)
	[ -f "$MAIN_SCENE" ] || result NOT_YET - "$MAIN_SCENE not delivered; the full run captures the stack"
	n="$(ls docs/qa/stack/web_*.jpg 2>/dev/null | wc -l)"
	head -1 docs/qa/evidence/web_full.md 2>/dev/null | grep -q '(PASS)' || result FAIL docs/qa/stack "the last full run did not pass, so its captures are not a finished stack (docs/qa/evidence/web_full.md)"
	since=.userdata/qa/logs/web_full_started
	[ -f "$since" ] || since=docs/qa/evidence/web_full_console.txt
	old="$(find docs/qa/stack -name 'web_*.jpg' ! -newer "$since" 2>/dev/null | head -1)"
	[ -z "$old" ] || result FAIL docs/qa/stack "capture older than the last full run: $old"
	[ "$n" -ge 8 ] && result PASS docs/qa/stack "$n web captures from the full run; visual sign-off is in docs/qa/STATUS.md"
	result FAIL docs/qa/stack "only $n stack capture(s); the full run did not reach the events that trigger them" ;;
originality)
	f=docs/qa/ORIGINALITY.md
	v="$(grep -oE '^Verdict: (PASS|FAIL|OPEN)' "$f" 2>/dev/null | head -1 | cut -d' ' -f2 || true)"
	case "$v" in PASS) result PASS "$f" "signed audit verdict PASS" ;; FAIL) result FAIL "$f" "audit found collisions or derivative designs (see file)" ;; *) result NOT_YET "$f" "audit open: art and names still arriving" ;; esac ;;
*) sed -n '2,24p' "$0"; exit 2 ;;
esac
