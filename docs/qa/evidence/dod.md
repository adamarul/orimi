# Definition-of-done gate

Checkout: ws branch at 312543b, run 2026-11-16T17:39Z. Command: tools/qa/dod.sh 

Browser build tested: export of 312543b

| DoD | check | what it proves | result | evidence |
| - | - | - | - | - |
| 1 | check | tools/check.sh: every script, scene and resource loads; headless boot clean | **PASS** | docs/qa/evidence/check.txt |
| 1 | desktop | fresh clone of HEAD: first import, check, windowed run of the main scene | **PASS** | docs/qa/evidence/desktop_fresh.txt |
| 1 | desktop_scenes | windowed desktop runs of the main scene and every demo: no script or shader errors | **PASS** | docs/qa/evidence/desktop_scenes.txt |
| 2 | packed_exports | no exported Packed*Array with a literal default (the web export drops it) | **PASS** | docs/qa/evidence/packed_exports.txt |
| 2 | export | fresh web export (tools/export_web.sh) | **PASS** | docs/qa/evidence/export_web.txt |
| 2 | web_smoke_main | browser: main scene loads with no console, shader or page errors | **PASS** | docs/qa/evidence/web_smoke_main.md |
| 2 | web_smoke_demos | browser: every scenes/dev/*_demo.tscn loads clean | **PASS** | docs/qa/evidence/web_smoke_demos.txt |
| 2 | web_input | browser: WASD, click capture, mouse orbit, jump, attack, Escape/lost capture pause | **PASS** | docs/qa/evidence/web_input.md |
| 2 | web_manual | browser, no autoplay: title, start, walk to the thorn gate, cut it with a drawn slash | **PASS** | docs/qa/evidence/web_manual.md |
| 2 | web_perf | browser frame rate in the valley, 1280x720 and 1920x1080, vsync and uncapped | **PASS** | docs/qa/evidence/web_perf.md |
| 2 | web_perf_tallowford | browser frame rate in Tallowford with every lamp lit, 1280x720 and 1920x1080, vsync and uncapped | **PASS** | docs/qa/evidence/web_perf_tallowford.md |
| 2 | web_perf_sedge_plain | browser frame rate on Sedge Plain at the Knoll | **PASS** | docs/qa/evidence/web_perf_sedge_plain.md |
| 2 | web_perf_mosswater | browser frame rate in Mosswater's dark hollow with every lantern-fruit lit | **PASS** | docs/qa/evidence/web_perf_mosswater.md |
| 2 | web_perf_kiln | browser frame rate in the Hollow Kiln during the Dregs fight | **PASS** | docs/qa/evidence/web_perf_kiln.md |
| 2 | web_resume | browser: finish Level 1, reload the page, Continue opens Level 2 with the bead kept | **PASS** | docs/qa/evidence/web_resume.md |
| 2 | web_resume_tallowford | browser: finish Level 2, reload, Continue opens Level 3 with the bead kept | **PASS** | docs/qa/evidence/web_resume_tallowford.md |
| 2 | web_resume_mosswater | browser: finish Level 4, reload, Continue opens Level 5 with the bead kept | **PASS** | docs/qa/evidence/web_resume_mosswater.md |
| 3 | web_paper | browser: Light / Normal / Heavy captures move in the style-guide direction | **PASS** | docs/qa/evidence/web_paper.md |
| 3 | paper_desktop | desktop: Light / Normal / Heavy captures move in the style-guide direction | **PASS** | docs/qa/evidence/paper_desktop.md |
| 4 | web_brush | browser brush: freeze, sepia, circle/line/loop recognised, ink drains, world resumes | **PASS** | docs/qa/evidence/web_brush.md |
| 5 | web_full | browser autoplay of the whole book: Level 1 enemies, zones and finale, every book level completes with its bead, end card | **PASS** | docs/qa/evidence/web_full.md |
| 5 | web_level_tallowford | browser autoplay of level=tallowford: every route step passes, level_complete | **PASS** | docs/qa/evidence/web_level_tallowford.md |
| 5 | web_level_sedge_plain | browser autoplay of level=sedge_plain: every route step passes, level_complete | **PASS** | docs/qa/evidence/web_level_sedge_plain.md |
| 5 | web_level_mosswater | browser autoplay of level=mosswater: every route step passes, level_complete | **PASS** | docs/qa/evidence/web_level_mosswater.md |
| 5 | web_level_hollow_kiln | browser autoplay of level=hollow_kiln: every route step passes, the Dregs, level_complete | **PASS** | docs/qa/evidence/web_level_hollow_kiln.md |
| 5 | web_level | browser autoplay of the kit example level (level=example): every route step passes, level_complete | **PASS** | docs/qa/evidence/web_level_example.md |
| 3 | stack | rendering-stack captures from the full run (visual sign-off in STATUS.md) | **PASS** | docs/qa/stack |
| 6 | tris | every glTF model <= 5000 triangles (counted from the glTF data) | **PASS** | docs/qa/evidence/tris.txt |
| 6 | provenance | every model, texture and audio file tied to a generator script by hash | **PASS** | docs/qa/evidence/provenance.txt |
| 6,7 | licences | fonts and third-party files carry their licence | **PASS** | docs/qa/evidence/licences.txt |
| 7 | terms | banned terms (the lead's list) and absolute paths in every file, build and commit message | **PASS** | docs/qa/evidence/terms.txt |
| 7 | originality | originality audit: invented names searched, designs reviewed | **PASS** | docs/qa/ORIGINALITY.md |
| 8 | docs | README (run, controls, glyphs, credits), docs/SHADERS.md, paper screenshots | **PASS** | docs/qa/evidence/docs_check.txt |
| 8 | shader_docs | every shader uniform documented in docs/SHADERS.md or docs/SHADERS_VFX.md | **PASS** | docs/qa/evidence/shader_docs.txt |
| all | contract | contract API unchanged; contract scenes delivered and well-formed | **PASS** | docs/qa/evidence/contract.txt |

## Details

- **check** (PASS, 32s): tools/check.sh passed
- **desktop** (PASS, 215s): fresh clone 312543b imports, checks and runs windowed with no script or shader errors
- **desktop_scenes** (PASS, 70s): 6 scene(s) ran windowed with no errors
- **packed_exports** (PASS, 0s): 124 script(s), no exported Packed*Array with a literal default
- **export** (PASS, 140s): fresh web export of 312543b written to build/web (61M)
- **web_smoke_main** (PASS, 31s): 3 criteria ok
- **web_smoke_demos** (PASS, 151s): 5 demo(s) load clean in the browser
- **web_input** (PASS, 46s): 16 criteria ok
- **web_manual** (PASS, 37s): 7 criteria ok
- **web_perf** (PASS, 85s): 6 criteria ok
- **web_perf_tallowford** (PASS, 88s): 7 criteria ok
- **web_perf_sedge_plain** (PASS, 98s): 6 criteria ok
- **web_perf_mosswater** (PASS, 94s): 7 criteria ok
- **web_perf_kiln** (PASS, 98s): 7 criteria ok
- **web_resume** (PASS, 121s): 7 criteria ok
- **web_resume_tallowford** (PASS, 180s): 7 criteria ok
- **web_resume_mosswater** (PASS, 194s): 7 criteria ok
- **web_paper** (PASS, 36s): 6 criteria ok
- **paper_desktop** (PASS, 50s): Light < Normal < Heavy on desktop
- **web_brush** (PASS, 43s): 11 criteria ok
- **web_full** (PASS, 977s): 12 criteria ok
- **web_level_tallowford** (PASS, 223s): 4 criteria ok
- **web_level_sedge_plain** (PASS, 280s): 4 criteria ok
- **web_level_mosswater** (PASS, 243s): 4 criteria ok
- **web_level_hollow_kiln** (PASS, 378s): 4 criteria ok
- **web_level** (PASS, 179s): 4 criteria ok
- **stack** (PASS, 1s): 12 web captures from the full run; visual sign-off is in docs/qa/STATUS.md
- **tris** (PASS, 0s): 144 model(s) within 5000 tris; largest: assets/levels/hollow_kiln/models/kiln.glb 4956
- **provenance** (PASS, 1s): 346 media file(s) all tied to a generator script by hash
- **licences** (PASS, 1s): 0 font/third-party file(s), each with a licence beside it
- **terms** (PASS, 19s): 1983 files, 10 build files, 48 commits clean
- **originality** (PASS, 1s): signed audit verdict PASS
- **docs** (PASS, 0s): README, SHADERS.md and screenshots present (18 items)
- **shader_docs** (PASS, 1s): all 279 uniform(s) in 21 shader(s) documented
- **contract** (PASS, 4s): API conforms to the stubs; every contract scene present and well-formed

FAIL: 0, NOT YET / NOT RUN: 0
