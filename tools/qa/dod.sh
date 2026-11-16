#!/usr/bin/env bash
# Definition-of-done gate: runs every QA check against this checkout and prints one table
# (definition-of-done line, check, PASS / FAIL / NOT YET, evidence). Also written to
# docs/qa/evidence/dod.md.
#
#   tools/qa/dod.sh                      everything (about 15-25 minutes once the game exists)
#   tools/qa/dod.sh --quick              static checks only (seconds, no Godot window, no browser)
#   tools/qa/dod.sh --only terms,tris    named checks only
#   tools/qa/dod.sh --skip web_full      everything except the named checks
#   tools/qa/dod.sh --no-export          reuse build/web instead of exporting afresh
#
# The banned-term check needs the lead's list at run time: QA_BANNED_TERMS (substring) and
# QA_BANNED_WORDS (whole word), comma separated. Without it that row is NOT RUN.
# Exit code: 0 every row PASS, 1 any FAIL, 3 no FAIL but something NOT YET / NOT RUN.
# Each row is also runnable alone: tools/qa/qa.sh <check>.
set -uo pipefail
QA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$QA/../.." && pwd)"
cd "$ROOT"

ROWS=(
	"1|check|tools/check.sh: every script, scene and resource loads; headless boot clean"
	"1|desktop|fresh clone of HEAD: first import, check, windowed run of the main scene"
	"1|desktop_scenes|windowed desktop runs of the main scene and every demo: no script or shader errors"
	"2|packed_exports|no exported Packed*Array with a literal default (the web export drops it)"
	"2|export|fresh web export (tools/export_web.sh)"
	"2|web_smoke_main|browser: main scene loads with no console, shader or page errors"
	"2|web_smoke_demos|browser: every scenes/dev/*_demo.tscn loads clean"
	"2|web_input|browser: WASD, click capture, mouse orbit, jump, attack, Escape/lost capture pause"
	"2|web_manual|browser, no autoplay: title, start, walk to the thorn gate, cut it with a drawn slash"
	"2|web_perf|browser frame rate in the valley, 1280x720 and 1920x1080, vsync and uncapped"
	"2|web_perf_tallowford|browser frame rate in Tallowford with every lamp lit, 1280x720 and 1920x1080, vsync and uncapped"
	"2|web_resume|browser: finish Level 1, reload the page, Continue opens Level 2 with the bead kept"
	"3|web_paper|browser: Light / Normal / Heavy captures move in the style-guide direction"
	"3|paper_desktop|desktop: Light / Normal / Heavy captures move in the style-guide direction"
	"4|web_brush|browser brush: freeze, sepia, circle/line/loop recognised, ink drains, world resumes"
	"5|web_full|browser autoplay of the whole book: Level 1 enemies, zones and finale, every book level completes with its bead, end card"
	"5|web_level_tallowford|browser autoplay of level=tallowford: every route step passes, level_complete"
	"5|web_level|browser autoplay of the kit example level (level=example): every route step passes, level_complete"
	"3|stack|rendering-stack captures from the full run (visual sign-off in STATUS.md)"
	"6|tris|every glTF model <= 5000 triangles (counted from the glTF data)"
	"6|provenance|every model, texture and audio file tied to a generator script by hash"
	"6,7|licences|fonts and third-party files carry their licence"
	"7|terms|banned terms (the lead's list) and absolute paths in every file, build and commit message"
	"7|originality|originality audit: invented names searched, designs reviewed"
	"8|docs|README (run, controls, glyphs, credits), docs/SHADERS.md, paper screenshots"
	"8|shader_docs|every shader uniform documented in docs/SHADERS.md or docs/SHADERS_VFX.md"
	"all|contract|contract API unchanged; contract scenes delivered and well-formed"
)
STATIC="tris provenance licences terms originality docs shader_docs contract"

only=""; skip=""; no_export=0
while [ $# -gt 0 ]; do
	case "$1" in
	--quick) only="$STATIC" ;;
	--only) only="$(echo "$2" | tr ',' ' ')"; shift ;;
	--skip) skip="$(echo "$2" | tr ',' ' ')"; shift ;;
	--no-export) no_export=1 ;;
	*) sed -n '2,18p' "$0"; exit 2 ;;
	esac
	shift
done
want() { local c="$1"; { [ -z "$only" ] || [[ " $only " == *" $c "* ]]; } && [[ " $skip " != *" $c "* ]]; }

mkdir -p docs/qa/evidence .userdata/qa
out=docs/qa/evidence/dod.md
sha="$(git rev-parse --short HEAD)$(git diff --quiet HEAD -- . 2>/dev/null || echo '+uncommitted')"
started="$(date -u +%Y-%m-%dT%H:%MZ)"
table=()
fails=0; open=0
for row in "${ROWS[@]}"; do
	IFS='|' read -r line check desc <<<"$row"
	want "$check" || continue
	if [ "$check" = export ] && [ "$no_export" -eq 1 ] && [ -f build/web/index.html ]; then
		table+=("| $line | export | $desc | SKIPPED (--no-export) | build/web |"); continue
	fi
	printf '%-16s ... ' "$check" >&2
	t0=$(date +%s)
	res="$(tools/qa/qa.sh "$check" 2>&1 | tr -d '\r' | grep '^QA_RESULT' | tail -1)"
	secs=$(( $(date +%s) - t0 ))
	[ -n "$res" ] || res="QA_RESULT ERROR - the check crashed without a result (run tools/qa/qa.sh $check)"
	status="$(echo "$res" | cut -d' ' -f2)"; evidence="$(echo "$res" | cut -d' ' -f3)"; detail="$(echo "$res" | cut -d' ' -f4- | sed 's/|/\//g')"
	# Browser rows must test an export of the commit this gate reports on.
	if [[ "$check" == web_* ]] && [ "$status" != NOT_YET ] && [ "$(cat build/web/qa_build.txt 2>/dev/null)" != "$(git rev-parse --short HEAD)" ]; then
		status=ERROR; detail="build/web is not an export of $(git rev-parse --short HEAD) (stamp: $(cat build/web/qa_build.txt 2>/dev/null || echo none)); run without --no-export: $detail"
	fi
	# Evidence written by the check itself must be fresh, or the row reports a stale file.
	if [[ "$evidence" == docs/qa/evidence/* ]] && [ -f "$evidence" ] && [ "$(stat -c %Y "$evidence")" -lt "$t0" ]; then
		status=ERROR; detail="evidence file was not rewritten by this run (stale): $detail"
	fi
	case "$status" in PASS) ;; NOT_YET | NOT_RUN) open=$((open + 1)) ;; *) fails=$((fails + 1)) ;; esac
	echo "$status (${secs}s)" >&2
	table+=("| $line | $check | $desc | **${status/_/ }** | $evidence |")
	details+=("- **$check** ($status, ${secs}s): $detail")
done
{
	echo "# Definition-of-done gate"
	echo
	echo "Checkout: ws branch at $sha, run $started. Command: tools/qa/dod.sh $*"
	echo
	echo "Browser build tested: export of $(cat build/web/qa_build.txt 2>/dev/null || echo 'unknown (no stamp)')"
	echo
	echo "| DoD | check | what it proves | result | evidence |"
	echo "| - | - | - | - | - |"
	printf '%s\n' "${table[@]}"
	echo
	echo "## Details"
	echo
	printf '%s\n' "${details[@]}"
	echo
	echo "FAIL: $fails, NOT YET / NOT RUN: $open"
} >"$out"
cat "$out"
[ "$fails" -gt 0 ] && exit 1
[ "$open" -gt 0 ] && exit 3
exit 0
