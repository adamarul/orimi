# QA harness self-test

Each check run once where it must pass and once on a planted defect it must catch. Plants were
written to tests/_plant/ (untracked) and deleted afterwards. Run: tools/qa/selftest.sh 

| case | input | expected | got | | detail |
| - | - | - | - | - | - |
| terms_clean | nothing planted | PASS | PASS | ok | 1983 files, 10 build files, 39 commits clean |
| terms_plant | term #1 in upper case in a scratch file | FAIL | FAIL | ok | 1 finding(s), first: tests/_plant/term.txt:1: banned term #1 |
| abspath_plant | this checkout's absolute path in a scratch file | FAIL | FAIL | ok | 3 finding(s), first: tests/_plant/abs.txt:1: absolute path (drive path) |
| abspath_generic | a generic user-folder drive path | FAIL | FAIL | ok | 2 finding(s), first: tests/_plant/abs2.txt:1: absolute path (drive path) |
| tris_ok | 4,999-triangle glb | PASS | PASS | ok | 1 model(s) within 5000 tris; largest: tests/_plant/in_budget.glb 4999 |
| tris_over | 6,000-triangle glb | FAIL | FAIL | ok | 1 model(s) fail; tests/_plant/over_budget.glb: 6000 triangles > 5000 |
| provenance_ok | texture + generator + manifest with matching hash | PASS | PASS | ok | 1 media file(s) all tied to a generator script by hash |
| provenance_tamper | texture edited after generation, plus a wav with no manifest | FAIL | FAIL | ok | 3 problem(s); first: tests/_plant/tex/orphan.wav: no provenance |
| shader_docs_missing | shader with one undocumented uniform | FAIL | FAIL | ok | 1 of 2 uniform(s) undocumented; first: tests/_plant/plant.gdshader: plant_undocumented not documented |
| shader_docs_ok | same shader, both uniforms documented | PASS | PASS | ok | all 2 uniform(s) in 1 shader(s) documented |
| licence_missing | font with no licence beside it | FAIL | FAIL | ok | 1 file(s) without a licence; first: tests/_plant/fonts/PlantSans.ttf (font): no licence beside it |
| licence_ok | same font with OFL.txt beside it | PASS | PASS | ok | 1 font/third-party file(s), each with a licence beside it |
| docs_missing_shot | README embeds only two of three levels | FAIL | FAIL | ok | 1 of 18 item(s) missing; first: README embeds an existing tests/_plant/shots/ image for Heavy paper |
| docs_ok | complete README, screenshots, SHADERS.md | PASS | PASS | ok | README, SHADERS.md and screenshots present (18 items) |
| docs_glyph_unshaped | README names Gust without the shape to draw | FAIL | FAIL | ok | 1 of 18 item(s) missing; first: README: glyph guide (Bloom, Slash and Gust each with the shape to draw); no shape given for gust |
| packed_clean | real scripts | PASS | PASS | ok | 124 script(s), no exported Packed*Array with a literal default |
| packed_inline | @export var x: PackedStringArray = [...] on one line | FAIL | FAIL | ok | 1 export(s) with a literal default; first: tests/_plant/packed_inline.gd:2: @export var tags: PackedStringArray = ["a"] |
| packed_above | @export on the line above the var | FAIL | FAIL | ok | 1 export(s) with a literal default; first: tests/_plant/packed_above.gd:4: var ids: PackedInt32Array = [] |
| packed_ok | constructor default; an unexported literal | PASS | PASS | ok | 1 script(s), no exported Packed*Array with a literal default |
| contract_real | live autoloads and every contract scene vs the stub baseline | PASS | PASS | ok | API conforms to the stubs; every contract scene present and well-formed |
| contract_missing_member | contract names Brush.plant_contract_member, code lacks it | FAIL | FAIL | ok | 1 API problem(s), 0 deliverable scene problem(s); first: Brush.plant_contract_member() -> Variant: method removed |
| contract_changed_type | contract says ink_splash(String), code has Vector3 | FAIL | FAIL | ok | 1 API problem(s), 0 deliverable scene problem(s); first: Vfx.ink_splash: argument 1 is Vector3, stub String (now (Vector3, float) -> Variant [1 default], stub (String, float) -> Variant [1 default]) |
| imgstats_selftest | synthetic paper set (good, identical, reversed) and sepia set (good, unchanged, grey, never resumes) | PASS | PASS | ok | "summary": "ok paper good passes; ok paper identical fails; ok paper reversed fails; ok sepia good passes; ok sepia no change fails; ok sepia grey (not warm) fails; ok sepia never resumes fails" |
| check_plant | GDScript parse error in a scratch script | FAIL | FAIL | ok | tools/check.sh failed: ORIMI_CHECK FAIL res://tests/_plant/bad_script.gd FAIL load check (exit 1)  |
| check_clean | plant removed | PASS | PASS | ok | tools/check.sh passed |
| desktop_fixture | windowed run of the fixture | PASS | PASS | ok | clean |
| desktop_shader_plant | fixture with a broken shader (defect=shader) | FAIL | FAIL | ok | SHADER ERROR: Unknown identifier in expression: 'undefined_symbol'. |
| web_smoke_fixture | fixture loads in Chrome | PASS | PASS | ok | 3 criteria ok |
| web_smoke_error | push_error at start (defect=error) | FAIL | FAIL | ok | 2 failing; first: no console/page errors: console error: ERROR: QA fixture: planted error |
| web_smoke_shader | shader that does not compile (defect=shader) | FAIL | FAIL | ok | 4 failing; first: no console/page errors: console error: SHADER ERROR: Unknown identifier in expression: 'undefined_symbol'. |
| web_input_ok | fixture input | PASS | PASS | ok | 16 criteria ok |
| web_input_defect | movement and attack ignored (defect=input) | FAIL | FAIL | ok | 8 failing; first: KeyW moves the player +fwd: moved 0.00 m, 0.00 m along the camera fwd axis |
| web_brush_ok | fixture brush | PASS | PASS | ok | 10 criteria ok |
| web_brush_defect | brush never opens (defect=brush) | FAIL | FAIL | ok | 3 failing; first: a circle is recognised as bloom: no glyph event |
| web_full_ok | fixture autoplay timeline | PASS | PASS | ok | 12 criteria ok |
| web_full_defect | gust never cast (defect=no_gust) | FAIL | FAIL | ok | 1 failing; first: each glyph cast at least once: glyph_cast: slash,bloom,slash,bloom,bloom |
| web_level_ok | fixture level autoplay ends passed | PASS | PASS | ok | 4 criteria ok |
| web_level_defect | autoplay reports a failed step (defect=level_fail) | FAIL | FAIL | ok | 2 failing; first: autoplay passed (no failed step): passed false; failures: ["planted level_fail"] |
| web_manual_ok | fixture: title, walk, drawn slash | PASS | PASS | ok | 7 criteria ok |
| web_manual_defect | brush never opens (defect=brush) | FAIL | FAIL | ok | 2 failing; first: a drawn horizontal line is recognised as slash: glyph_cast: none; glyph_failed: 0 |
| web_perf_fixture | fixture frame rate measured | PASS | PASS | ok | 6 criteria ok |
| web_paper_ok | fixture under the real Post: three paper levels differ the right way | PASS | PASS | ok | 6 criteria ok |
| web_paper_stuck | the paper setting never changes (defect=paper_stuck) | FAIL | FAIL | ok | 3 failing; first: paper light selected in game (O key): Settings.paper_intensity 1 |
| web_missing_target | probe modes on a scene that does not exist | NOT_YET | NOT_YET | ok | target scene res://scenes/game/does_not_exist.tscn does not exist yet |

Wrong outcomes: 0
