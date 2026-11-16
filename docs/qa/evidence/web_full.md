# Browser check: full (FAIL)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&autoplay=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.87s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10294 ms)


| result | criterion | detail |
| - | - | - |
| ok | valley_restored reached | after 962 s |
| ok | end card (game state ended) | ended |
| ok | both enemy types killed | enemy_died kinds: splotchet, reedwraith, sootflit, dregs (67 deaths) |
| ok | both zones restored | zone_restored: zone_a, zone_b, tree, mere, east, west, spring, yard, hall, flue, vat |
| ok | finale started | 2 finale_started |
| ok | each glyph cast at least once | glyph_cast: bloom,slash,slash,bloom,gust,slash,bloom,gust,gust,bloom,bloom,kindle,slash,kindle,gust,kindle,bloom,kindle,kindle,slash,gust,gust,kindle,slash,bloom,tie,gust,gust,tie,gust,gust,gust,tie,gust,gust,gust,bloom,bloom,kindle,kindle,slash,kindle,kindle,bloom,gust,kindle,bloom,bloom,tie,slash,kindle,gust,tie,slash,gust,gust,gust,gust,gust,gust,bloom,bloom,bloom,slash,kindle,kindle,slash,gust,gust,bloom,bloom,gust,gust,bloom,tie,kindle,bloom,kindle,kindle,bloom,kindle,bloom,gust,gust,slash,slash,tie,kindle,kindle,kindle,bloom,bloom |
| ok | every book level completes (hazewater, tallowford, sedge_plain, mosswater, hollow_kiln) | level_complete: hazewater, tallowford, sedge_plain, mosswater, hollow_kiln |
| ok | a bead for every book level | bead: hazewater, tallowford, sedge_plain, mosswater, hollow_kiln |
| FAIL | book autoplay passed (no failed step) | failures: ["could not reach [-0.35, 6.68, -4.6]"], 115 stages |
| ok | inside the time limit | 962 s of 2000 |
| ok | gameplay prints QA: lines | 1634 lines, tags: attack_timing, level_built, title_menu, title_ready, stage, state, intro, progress_saved, prompt, play_started, glyph_cast, autoplay_cast, verse_stone, talk_line, prompt_hidden, flag, objective, thorns_cut, enemy_unravel, enemy_died, zone_entered, finishing_stroke, zone_cleared, zone_restore_started, zone_restored, player_died, player_respawned, zone_exited, soot_cleared, enemy_unveiled, wave, finale_started, valley_restored, level_complete, bead, raft_camera, raft_moment, level_arrived, talk, kindled, person_woken, kindle_refused, bark, bark_line, glyph_target, fight_started, camera_fade, fight_won, level_exit, sedge_scenery_ready, sedge_first_sights_warmed, tied, pickup, cursed_ground_hurt, cursed_ground_returned, cursed_probe, checkpoint, cursed_ground_cleared, kindle_look, mw_camera_bushes, level_hint, sootflit_state, deep_water_return, autoplay_fail, exit_refused, water_probe, autoplay_skip_waypoint, glyph_refused, rising_started, glyph_blocked, rising_lifted, rising_probe, dregs_part, dregs_gust, dregs_arm_cut, dregs_dry, dregs_unravelled, autoplay_fight_reach, card_fit, end_card, autoplay_end |
| ok | no console/page errors | 6435 console lines |

screenshots: docs/qa/stack/web_01_glyph_first_cast.jpg, docs/qa/stack/web_02_playing_20s.jpg, docs/qa/stack/web_03_slash_on_thorns.jpg, docs/qa/stack/web_04_slash_trail.jpg, docs/qa/stack/web_05_enemy_ink_death.jpg, docs/qa/stack/web_06_cursed_zone_before.jpg, docs/qa/stack/web_07_zone_restoring.jpg, docs/qa/stack/web_08_zone_restored.jpg, docs/qa/stack/web_09_gust_on_soot.jpg, docs/qa/stack/web_10_finale.jpg, docs/qa/stack/web_11_valley_restored.jpg, docs/qa/stack/web_12_end_card.jpg
console log: docs/qa/evidence/web_full_console.txt
