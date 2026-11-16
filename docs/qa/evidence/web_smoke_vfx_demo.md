# Browser check: smoke (PASS)

url query: scene=res%3A%2F%2Fscenes%2Fdev%2Fvfx_demo.tscn
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=14.41s scene=res://scenes/dev/vfx_demo.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (19981 ms)


| result | criterion | detail |
| - | - | - |
| ok | first frame | ORIMI_FIRST_FRAME t=14.41s scene=res://scenes/dev/vfx_demo.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web after 19981 ms |
| ok | requestAnimationFrame rate | {"fps":122,"p50_ms":6.9,"p95_ms":7,"frames":244} |
| ok | no console/page errors | 33 console lines |

screenshots: docs/qa/evidence/web_smoke_vfx_demo.jpg
console log: docs/qa/evidence/web_smoke_vfx_demo_console.txt
