# Browser check: input (NOT_YET)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fdoes_not_exist.tscn&god=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.51s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9839 ms)
NOT YET: target scene res://scenes/game/does_not_exist.tscn does not exist yet

| result | criterion | detail |
| - | - | - |
| ok | no console/page errors | 10 console lines |

screenshots: none
console log: docs/qa/evidence/web_selftest_missing_console.txt
