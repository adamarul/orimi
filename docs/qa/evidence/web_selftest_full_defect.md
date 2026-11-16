# Browser check: full (FAIL)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&autoplay=1&defect=no_gust
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.76s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9954 ms)


| result | criterion | detail |
| - | - | - |
| ok | valley_restored reached | after 13 s |
| ok | end card (game state ended) | ended |
| ok | both enemy types killed | enemy_died kinds: splotchet, reedwraith (4 deaths) |
| ok | both zones restored | zone_restored: zone_a, zone_b |
| ok | finale started | 1 finale_started |
| FAIL | each glyph cast at least once | glyph_cast: slash,bloom,slash,bloom,bloom |
| ok | every book level completes (hazewater, tallowford, sedge_plain, mosswater, hollow_kiln) | level_complete: hazewater, tallowford, sedge_plain, mosswater, hollow_kiln |
| ok | a bead for every book level | bead: hazewater, tallowford, sedge_plain, mosswater, hollow_kiln |
| ok | book autoplay passed (no failed step) | failures: [], 0 stages |
| ok | inside the time limit | 13 s of 60 |
| ok | gameplay prints QA: lines | 45 lines, tags: state, glyph_cast, glyph, thorns_cut, thorns, enemy_died, enemy, zone_restore_started, zone_restored, zone, soot_cleared, soot, finale_started, finale, valley_restored, restored, level_complete, bead, autoplay_end |
| ok | no console/page errors | 109 console lines |

screenshots: .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_01_glyph_first_cast.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_02_slash_on_thorns.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_03_slash_trail.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_04_enemy_ink_death.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_05_zone_restoring.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_06_zone_restored.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_07_gust_on_soot.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_08_finale.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_09_valley_restored.png, .userdata/qa/full/docs/qa/evidence/web_selftest_full_defect_10_end_card.png
console log: docs/qa/evidence/web_selftest_full_defect_console.txt
