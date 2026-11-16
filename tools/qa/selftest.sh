#!/usr/bin/env bash
# Proves the QA harness: every check is run once on input where it must PASS and once on a
# planted defect it must catch. Plants live in tests/_plant/ (untracked) and are deleted at the end,
# even on failure. Results: docs/qa/evidence/selftest.md.
#
#   QA_BANNED_TERMS=... tools/qa/selftest.sh [--no-web] [--no-desktop]
#
# The banned-term plant is written at run time from the first term in QA_BANNED_TERMS, so no term is
# ever stored in the repository. Browser cases run the fixture (tests/fixtures/qa_fixture.tscn) from
# a fresh web export with its defect= modes.
set -uo pipefail
QA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$QA/../.." && pwd)"
cd "$ROOT"
PLANT=tests/_plant
FX=res://tests/fixtures/qa_fixture.tscn
HOSTQ="scene=res://tests/qa/qa_host.tscn target=$FX"
web=1; desktop=1
for a in "$@"; do case "$a" in --no-web) web=0 ;; --no-desktop) desktop=0 ;; esac; done
source tools/lib/common.sh
set +e
PY="$(python_bin)"
cleanup() { rm -rf "$PLANT"; }
trap cleanup EXIT
rows=(); bad=0

plant() { "$PY" -I "$(native tools/qa/make_plants.py)" "$@"; }
# case <name> <plant description> <expected status> <command...>
case_() {
	local name="$1" what="$2" expect="$3"; shift 3
	printf '%-34s ' "$name" >&2
	local res; res="$("$@" 2>&1 | tr -d '\r' | grep '^QA_RESULT' | tail -1)"
	local got; got="$(echo "$res" | cut -d' ' -f2)"
	local ok=ok; [ "$got" = "$expect" ] || { ok=WRONG; bad=$((bad + 1)); }
	echo "$ok ($got)" >&2
	rows+=("| $name | $what | $expect | $got | $ok | $(echo "$res" | cut -d' ' -f4- | sed 's/|/\//g' | cut -c1-220) |")
}

rm -rf "$PLANT"; mkdir -p "$PLANT"

# --- banned terms and absolute paths
first_term="$(echo "${QA_BANNED_TERMS:-}" | tr ',' '\n' | sed '/^\s*$/d' | head -1)"
if [ -n "$first_term" ]; then
	case_ terms_clean "nothing planted" PASS tools/qa/qa.sh terms --evidence selftest_terms.txt
	printf 'scratch %s line\n' "$(echo "$first_term" | tr '[:lower:]' '[:upper:]')" >"$PLANT/term.txt"
	case_ terms_plant "term #1 in upper case in a scratch file" FAIL tools/qa/qa.sh terms --evidence selftest_terms.txt
	rm -f "$PLANT/term.txt"
else
	rows+=("| terms | (QA_BANNED_TERMS not set) | - | - | NOT RUN | |")
fi
echo "log written from $(native "$ROOT")/build" >"$PLANT/abs.txt"
case_ abspath_plant "this checkout's absolute path in a scratch file" FAIL tools/qa/qa.sh terms --evidence selftest_terms.txt
rm -f "$PLANT/abs.txt"
printf 'see %s\n' "$(printf 'C%s/Users/someone/notes.txt' ':')" >"$PLANT/abs2.txt"
case_ abspath_generic "a generic user-folder drive path" FAIL tools/qa/qa.sh terms --evidence selftest_terms.txt
rm -f "$PLANT/abs2.txt"

# --- triangles
plant glb_ok
case_ tris_ok "4,999-triangle glb" PASS tools/qa/qa.sh tris --evidence selftest_tris.txt "$PLANT/in_budget.glb"
plant glb_over
case_ tris_over "6,000-triangle glb" FAIL tools/qa/qa.sh tris --evidence selftest_tris.txt "$PLANT/in_budget.glb" "$PLANT/over_budget.glb"
rm -f "$PLANT"/*.glb

# --- provenance
plant prov_ok
case_ provenance_ok "texture + generator + manifest with matching hash" PASS tools/qa/qa.sh provenance --prefix "$PLANT/" --evidence selftest_prov.txt
plant prov_tamper
case_ provenance_tamper "texture edited after generation, plus a wav with no manifest" FAIL tools/qa/qa.sh provenance --prefix "$PLANT/" --evidence selftest_prov.txt
rm -rf "$PLANT/tex" "$PLANT/gen_plant_texture.py"

# --- shader docs
plant shader
case_ shader_docs_missing "shader with one undocumented uniform" FAIL tools/qa/qa.sh shader_docs --prefix "$PLANT/" --docs "$PLANT/PLANT_SHADERS.md" --evidence selftest_shd.txt
plant shader_doc
case_ shader_docs_ok "same shader, both uniforms documented" PASS tools/qa/qa.sh shader_docs --prefix "$PLANT/" --docs "$PLANT/PLANT_SHADERS.md" --evidence selftest_shd.txt
rm -f "$PLANT"/plant.gdshader* "$PLANT/PLANT_SHADERS.md"

# --- licences
plant font
case_ licence_missing "font with no licence beside it" FAIL tools/qa/qa.sh licences --prefix "$PLANT/" --evidence selftest_lic.txt
plant font_licence
case_ licence_ok "same font with OFL.txt beside it" PASS tools/qa/qa.sh licences --prefix "$PLANT/" --evidence selftest_lic.txt
rm -rf "$PLANT/fonts"

# --- deliverable docs
plant readme
case_ docs_missing_shot "README embeds only two of three levels" FAIL tools/qa/qa.sh docs --readme "$PLANT/README.md" --shots "$PLANT/shots" --shaders "$PLANT/SHADERS.md" --evidence selftest_docs.txt
sed -i 's#^\(!\[light\].*\)$#\1 ![heavy](tests/_plant/shots/valley_heavy_web.png)#' "$PLANT/README.md"
case_ docs_ok "complete README, screenshots, SHADERS.md" PASS tools/qa/qa.sh docs --readme "$PLANT/README.md" --shots "$PLANT/shots" --shaders "$PLANT/SHADERS.md" --evidence selftest_docs.txt
sed -i 's#Gust: a loop\.#Gust: clears soot.#' "$PLANT/README.md"
case_ docs_glyph_unshaped "README names Gust without the shape to draw" FAIL tools/qa/qa.sh docs --readme "$PLANT/README.md" --shots "$PLANT/shots" --shaders "$PLANT/SHADERS.md" --evidence selftest_docs.txt
rm -rf "$PLANT/shots" "$PLANT/README.md" "$PLANT/SHADERS.md"

# --- contract
"$PY" -I -c "
import json,sys
b=json.load(open('tests/contract/api_baseline.json'))
b['autoloads']['Brush']['methods']['plant_contract_member']={'args':[],'defaults':0,'static':False,'vararg':False,'return':{'type':0,'class':''}}
json.dump(b,open('$PLANT/baseline_extra.json','w'))
c=json.load(open('tests/contract/api_baseline.json'))
c['autoloads']['Vfx']['methods']['ink_splash']['args'][0]={'type':4,'class':''}
json.dump(c,open('$PLANT/baseline_type.json','w'))
"
case_ packed_clean "real scripts" PASS tools/qa/qa.sh packed_exports --evidence selftest_packed.txt
mkdir -p "$PLANT" && printf 'extends Node\n@export var tags: PackedStringArray = ["a"]\n' >"$PLANT/packed_inline.gd"
case_ packed_inline "@export var x: PackedStringArray = [...] on one line" FAIL tools/qa/qa.sh packed_exports --prefix tests/_plant/ --evidence selftest_packed.txt
rm -f "$PLANT/packed_inline.gd"; printf 'extends Node\n@export_group("x")\n@export\nvar ids: PackedInt32Array = []\nvar ok: PackedInt32Array = []\n' >"$PLANT/packed_above.gd"
case_ packed_above "@export on the line above the var" FAIL tools/qa/qa.sh packed_exports --prefix tests/_plant/ --evidence selftest_packed.txt
rm -f "$PLANT/packed_above.gd"; printf 'extends Node\n@export var ids: PackedInt32Array = PackedInt32Array([1])\nvar local: PackedInt32Array = []\n' >"$PLANT/packed_ok.gd"
case_ packed_ok "constructor default; an unexported literal" PASS tools/qa/qa.sh packed_exports --prefix tests/_plant/ --evidence selftest_packed.txt
rm -f "$PLANT/packed_ok.gd"
case_ contract_real "live autoloads and every contract scene vs the stub baseline" PASS tools/qa/qa.sh contract --evidence selftest_contract.txt
case_ contract_missing_member "contract names Brush.plant_contract_member, code lacks it" FAIL tools/qa/qa.sh contract --baseline "$PLANT/baseline_extra.json" --evidence selftest_contract.txt
case_ contract_changed_type "contract says ink_splash(String), code has Vector3" FAIL tools/qa/qa.sh contract --baseline "$PLANT/baseline_type.json" --evidence selftest_contract.txt

# --- image comparators
printf '%-34s ' imgstats_selftest >&2
if "$PY" -I tools/qa/imgstats.py selftest .userdata/qa/imgself >.userdata/qa/imgself.json; then g=PASS; else g=FAIL; bad=$((bad + 1)); fi
echo "$g" >&2
rows+=("| imgstats_selftest | synthetic paper set (good, identical, reversed) and sepia set (good, unchanged, grey, never resumes) | PASS | $g | $([ $g = PASS ] && echo ok || echo WRONG) | $(grep -o '"summary": "[^"]*"' .userdata/qa/imgself.json | head -1 | cut -c1-220) |")

# --- check.sh
plant badgd
case_ check_plant "GDScript parse error in a scratch script" FAIL tools/qa/qa.sh check
rm -f "$PLANT"/bad_script.gd*
case_ check_clean "plant removed" PASS tools/qa/qa.sh check

if [ "$desktop" -eq 1 ]; then
	case_ desktop_fixture "windowed run of the fixture" PASS bash -c "tools/screenshot_desktop.sh .userdata/qa/fx.png $HOSTQ >/dev/null 2>&1 && echo 'QA_RESULT PASS - clean' || echo 'QA_RESULT FAIL - errors'"
	case_ desktop_shader_plant "fixture with a broken shader (defect=shader)" FAIL bash -c "tools/screenshot_desktop.sh .userdata/qa/fx.png $HOSTQ defect=shader >.userdata/qa/fx_shader.out 2>&1 && echo 'QA_RESULT PASS - clean' || echo \"QA_RESULT FAIL - \$(grep -m1 -o 'SHADER ERROR.*' .userdata/qa/fx_shader.out)\""
fi

if [ "$web" -eq 1 ]; then
	tools/qa/qa.sh export >/dev/null 2>&1 || echo "export failed" >&2
	W="tools/qa/qa.sh web"
	case_ web_smoke_fixture "fixture loads in Chrome" PASS $W smoke --name selftest_smoke_ok $HOSTQ
	case_ web_smoke_error "push_error at start (defect=error)" FAIL $W smoke --name selftest_smoke_error $HOSTQ defect=error
	case_ web_smoke_shader "shader that does not compile (defect=shader)" FAIL $W smoke --name selftest_smoke_shader $HOSTQ defect=shader
	case_ web_input_ok "fixture input" PASS $W input --target $FX --name selftest_input_ok
	case_ web_input_defect "movement and attack ignored (defect=input)" FAIL $W input --target $FX --name selftest_input_defect defect=input
	case_ web_brush_ok "fixture brush" PASS $W brush --target $FX --name selftest_brush_ok
	case_ web_brush_defect "brush never opens (defect=brush)" FAIL $W brush --target $FX --name selftest_brush_defect defect=brush
	case_ web_full_ok "fixture autoplay timeline" PASS $W full --target $FX --name selftest_full_ok --timeout 60
	case_ web_full_defect "gust never cast (defect=no_gust)" FAIL $W full --target $FX --name selftest_full_defect --timeout 60 defect=no_gust
	case_ web_level_ok "fixture level autoplay ends passed" PASS $W level --target $FX --name selftest_level_ok --timeout 60 level=example
	case_ web_level_defect "autoplay reports a failed step (defect=level_fail)" FAIL $W level --target $FX --name selftest_level_defect --timeout 60 level=example defect=level_fail
	case_ web_manual_ok "fixture: title, walk, drawn slash" PASS $W manual --target $FX --name selftest_manual_ok
	case_ web_manual_defect "brush never opens (defect=brush)" FAIL $W manual --target $FX --name selftest_manual_defect defect=brush
	case_ web_perf_fixture "fixture frame rate measured" PASS $W perf --target $FX --name selftest_perf
	case_ web_paper_ok "fixture under the real Post: three paper levels differ the right way" PASS $W paper --target $FX --name selftest_paper_ok
	case_ web_paper_stuck "the paper setting never changes (defect=paper_stuck)" FAIL $W paper --target $FX --name selftest_paper_stuck defect=paper_stuck
	case_ web_missing_target "probe modes on a scene that does not exist" NOT_YET $W input --target res://scenes/game/does_not_exist.tscn --name selftest_missing
fi

{
	echo "# QA harness self-test"
	echo
	echo "Each check run once where it must pass and once on a planted defect it must catch. Plants were"
	echo "written to tests/_plant/ (untracked) and deleted afterwards. Run: tools/qa/selftest.sh $*"
	echo
	echo "| case | input | expected | got | | detail |"
	echo "| - | - | - | - | - | - |"
	printf '%s\n' "${rows[@]}"
	echo
	echo "Wrong outcomes: $bad"
} >docs/qa/evidence/selftest.md
cat docs/qa/evidence/selftest.md
[ "$bad" -eq 0 ]
