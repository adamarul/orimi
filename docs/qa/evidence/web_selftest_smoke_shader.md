# Browser check: smoke (FAIL)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&defect=shader
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=5.06s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9601 ms)


| result | criterion | detail |
| - | - | - |
| ok | first frame | ORIMI_FIRST_FRAME t=5.06s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web after 9601 ms |
| ok | requestAnimationFrame rate | {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":288} |
| FAIL | no console/page errors | console error: SHADER ERROR: Unknown identifier in expression: 'undefined_symbol'. |
| FAIL | no console/page errors | console error:    at: (null) (:2) |
| FAIL | no console/page errors | console error: ERROR: Shader compilation failed. |
| FAIL | no console/page errors | console error:    at: set_code (drivers/gles3/storage/material_storage.cpp:3119) |

screenshots: .userdata/qa/full/docs/qa/evidence/web_selftest_smoke_shader.png
console log: docs/qa/evidence/web_selftest_smoke_shader_console.txt
