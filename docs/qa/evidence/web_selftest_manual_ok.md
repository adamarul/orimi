# Browser check: manual (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&god=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.94s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9853 ms)


| result | criterion | detail |
| - | - | - |
| ok | title -> playing with real input | states title > playing, player [0,0,50] |
| ok | click captures the mouse | pointerLockElement true, Input.mouse_mode 2 |
| ok | walked to the thorn gate with WASD | ended 0.7 m from the stand point south of ThornGateFixture after 2 s |
| ok | thorn gate on screen | gate anchor at css 621,294, 12.6 m away |
| ok | a drawn horizontal line is recognised as slash | glyph_cast: slash; glyph_failed: 0 |
| ok | the slash cuts the thorn gate (Events.thorns_cut) | 1 thorns_cut |
| ok | no console/page errors | 65 console lines |

screenshots: .userdata/qa/full/docs/qa/evidence/web_manual_at_gate.png, .userdata/qa/full/docs/qa/evidence/web_manual_after_cut.png
console log: docs/qa/evidence/web_selftest_manual_ok_console.txt
