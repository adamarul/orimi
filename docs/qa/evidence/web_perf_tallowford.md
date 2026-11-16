# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=tallowford&warp=M_Square&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.29s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9345 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 6 of 6 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":865} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":865} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":9.3,"render_cpu_ms":2.5,"render_gpu_ms":0,"draw_calls":214,"primitives":34862,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":865} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":7.4,"render_cpu_ms":2.6,"render_gpu_ms":0,"draw_calls":214,"primitives":34862,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":181,"p50_ms":5.4,"p95_ms":6.4,"frames":1089} godot {"fps":188,"mean_ms":5.52,"p95_ms":6.06,"p99_ms":6.94,"max_ms":17.2,"process_ms":7.9,"render_cpu_ms":2.9,"render_gpu_ms":0,"draw_calls":228,"primitives":39312,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":167,"p50_ms":5.8,"p95_ms":7.3,"frames":1006} godot {"fps":177,"mean_ms":5.98,"p95_ms":7.41,"p99_ms":8.33,"max_ms":11.6,"process_ms":5.9,"render_cpu_ms":2.6,"render_gpu_ms":0,"draw_calls":214,"primitives":34862,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 213 console lines |

screenshots: docs/qa/evidence/web_perf_tallowford_lit.jpg
console log: docs/qa/evidence/web_perf_tallowford_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 144,
   "p50_ms": 6.9,
   "p95_ms": 7.1,
   "frames": 865
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 9.3,
   "render_cpu_ms": 2.5,
   "render_gpu_ms": 0,
   "draw_calls": 214,
   "primitives": 34862,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1280,
    720
   ]
  }
 },
 {
  "label": "vsync",
  "size": "1920x1080",
  "raf": {
   "fps": 144,
   "p50_ms": 6.9,
   "p95_ms": 7.1,
   "frames": 865
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 7.4,
   "render_cpu_ms": 2.6,
   "render_gpu_ms": 0,
   "draw_calls": 214,
   "primitives": 34862,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1920,
    1080
   ]
  }
 },
 {
  "label": "uncapped",
  "size": "1280x720",
  "raf": {
   "fps": 181,
   "p50_ms": 5.4,
   "p95_ms": 6.4,
   "frames": 1089
  },
  "godot": {
   "fps": 188,
   "mean_ms": 5.52,
   "p95_ms": 6.06,
   "p99_ms": 6.94,
   "max_ms": 17.2,
   "process_ms": 7.9,
   "render_cpu_ms": 2.9,
   "render_gpu_ms": 0,
   "draw_calls": 228,
   "primitives": 39312,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1280,
    720
   ]
  }
 },
 {
  "label": "uncapped",
  "size": "1920x1080",
  "raf": {
   "fps": 167,
   "p50_ms": 5.8,
   "p95_ms": 7.3,
   "frames": 1006
  },
  "godot": {
   "fps": 177,
   "mean_ms": 5.98,
   "p95_ms": 7.41,
   "p99_ms": 8.33,
   "max_ms": 11.6,
   "process_ms": 5.9,
   "render_cpu_ms": 2.6,
   "render_gpu_ms": 0,
   "draw_calls": 214,
   "primitives": 34862,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1920,
    1080
   ]
  }
 }
]
```
