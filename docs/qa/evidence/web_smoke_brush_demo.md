# Browser check: smoke (PASS)

url query: scene=res%3A%2F%2Fscenes%2Fdev%2Fbrush_demo.tscn
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=13.46s scene=res://scenes/dev/brush_demo.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (18080 ms)


| result | criterion | detail |
| - | - | - |
| ok | first frame | ORIMI_FIRST_FRAME t=13.46s scene=res://scenes/dev/brush_demo.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web after 18080 ms |
| ok | requestAnimationFrame rate | {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":289} |
| ok | no console/page errors | 10 console lines |

screenshots: docs/qa/evidence/web_smoke_brush_demo.jpg
console log: docs/qa/evidence/web_smoke_brush_demo_console.txt
