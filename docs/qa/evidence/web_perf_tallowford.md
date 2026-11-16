# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=tallowford&warp=M_Square&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.70s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10213 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 6 of 6 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":864} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":864} godot {"fps":144,"mean_ms":6.93,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":9.6,"render_cpu_ms":2.9,"render_gpu_ms":0,"draw_calls":235,"primitives":35850,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":143,"p50_ms":6.9,"p95_ms":7,"frames":862} godot {"fps":144,"mean_ms":6.98,"p95_ms":7.14,"p99_ms":7.58,"max_ms":11.37,"process_ms":7.5,"render_cpu_ms":2.5,"render_gpu_ms":0,"draw_calls":235,"primitives":35850,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":177,"p50_ms":5.5,"p95_ms":6.7,"frames":1062} godot {"fps":174,"mean_ms":5.66,"p95_ms":6.25,"p99_ms":7.3,"max_ms":8.12,"process_ms":8.2,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":249,"primitives":40300,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":149,"p50_ms":6.6,"p95_ms":7.8,"frames":893} godot {"fps":149,"mean_ms":6.73,"p95_ms":7.41,"p99_ms":7.8,"max_ms":11.43,"process_ms":7.8,"render_cpu_ms":2.6,"render_gpu_ms":0,"draw_calls":235,"primitives":35850,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 217 console lines |

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
   "p95_ms": 7,
   "frames": 864
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.93,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 9.6,
   "render_cpu_ms": 2.9,
   "render_gpu_ms": 0,
   "draw_calls": 235,
   "primitives": 35850,
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
   "fps": 143,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 862
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.98,
   "p95_ms": 7.14,
   "p99_ms": 7.58,
   "max_ms": 11.37,
   "process_ms": 7.5,
   "render_cpu_ms": 2.5,
   "render_gpu_ms": 0,
   "draw_calls": 235,
   "primitives": 35850,
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
   "fps": 177,
   "p50_ms": 5.5,
   "p95_ms": 6.7,
   "frames": 1062
  },
  "godot": {
   "fps": 174,
   "mean_ms": 5.66,
   "p95_ms": 6.25,
   "p99_ms": 7.3,
   "max_ms": 8.12,
   "process_ms": 8.2,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 249,
   "primitives": 40300,
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
   "fps": 149,
   "p50_ms": 6.6,
   "p95_ms": 7.8,
   "frames": 893
  },
  "godot": {
   "fps": 149,
   "mean_ms": 6.73,
   "p95_ms": 7.41,
   "p99_ms": 7.8,
   "max_ms": 11.43,
   "process_ms": 7.8,
   "render_cpu_ms": 2.6,
   "render_gpu_ms": 0,
   "draw_calls": 235,
   "primitives": 35850,
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
