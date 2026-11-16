# Browser check: manual (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.55s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9221 ms)


| result | criterion | detail |
| - | - | - |
| ok | title -> playing with real input | states title > cutscene > playing, player [0,0.036,50] |
| ok | click captures the mouse | pointerLockElement true, Input.mouse_mode 2 |
| ok | walked to the thorn gate with WASD | ended 0.6 m from the stand point south of ThornGate after 1 s |
| ok | thorn gate on screen | gate anchor at css 706,273, 10.8 m away |
| ok | a drawn horizontal line is recognised as slash | glyph_cast: slash; glyph_failed: 0 |
| ok | the slash cuts the thorn gate (Events.thorns_cut) | 1 thorns_cut |
| ok | no console/page errors | 149 console lines |

screenshots: docs/qa/evidence/web_manual_at_gate.jpg, docs/qa/evidence/web_manual_after_cut.jpg
console log: docs/qa/evidence/web_manual_console.txt
