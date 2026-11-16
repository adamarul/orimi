# Browser check: smoke (FAIL)

url query: scene=res%3A%2F%2Fscenes%2Fdev%2Frender_demo.tscn
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=9.49s scene=res://scenes/dev/render_demo.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (14484 ms)


| result | criterion | detail |
| - | - | - |
| ok | first frame | ORIMI_FIRST_FRAME t=9.49s scene=res://scenes/dev/render_demo.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web after 14484 ms |
| ok | requestAnimationFrame rate | {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":288} |
| FAIL | no console/page errors | console error: ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D() |
| FAIL | no console/page errors | console error:    at: get_global_transform (scene/3d/node_3d.cpp:649) |

screenshots: docs/qa/evidence/web_smoke_render_demo.jpg
console log: docs/qa/evidence/web_smoke_render_demo_console.txt
