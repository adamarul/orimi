# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.30s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9101 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":845} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":845} godot {"fps":144,"mean_ms":7.11,"p95_ms":6.94,"p99_ms":6.94,"max_ms":144.64,"process_ms":5.4,"render_cpu_ms":1.8,"render_gpu_ms":0,"draw_calls":228,"primitives":27268,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":864} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":6.2,"render_cpu_ms":2.4,"render_gpu_ms":0,"draw_calls":247,"primitives":29060,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":206,"p50_ms":4.6,"p95_ms":6,"frames":1238} godot {"fps":208,"mean_ms":4.85,"p95_ms":6.25,"p99_ms":7.2,"max_ms":141.37,"process_ms":7.2,"render_cpu_ms":1.6,"render_gpu_ms":0,"draw_calls":232,"primitives":27348,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":174,"p50_ms":5.7,"p95_ms":6.6,"frames":1048} godot {"fps":179,"mean_ms":5.73,"p95_ms":6.25,"p99_ms":7.85,"max_ms":9.9,"process_ms":5.9,"render_cpu_ms":2.4,"render_gpu_ms":0,"draw_calls":257,"primitives":29764,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 152 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 141,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 845
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.11,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 144.64,
   "process_ms": 5.4,
   "render_cpu_ms": 1.8,
   "render_gpu_ms": 0,
   "draw_calls": 228,
   "primitives": 27268,
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
   "p95_ms": 7,
   "frames": 864
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 6.2,
   "render_cpu_ms": 2.4,
   "render_gpu_ms": 0,
   "draw_calls": 247,
   "primitives": 29060,
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
   "fps": 206,
   "p50_ms": 4.6,
   "p95_ms": 6,
   "frames": 1238
  },
  "godot": {
   "fps": 208,
   "mean_ms": 4.85,
   "p95_ms": 6.25,
   "p99_ms": 7.2,
   "max_ms": 141.37,
   "process_ms": 7.2,
   "render_cpu_ms": 1.6,
   "render_gpu_ms": 0,
   "draw_calls": 232,
   "primitives": 27348,
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
   "fps": 174,
   "p50_ms": 5.7,
   "p95_ms": 6.6,
   "frames": 1048
  },
  "godot": {
   "fps": 179,
   "mean_ms": 5.73,
   "p95_ms": 6.25,
   "p99_ms": 7.85,
   "max_ms": 9.9,
   "process_ms": 5.9,
   "render_cpu_ms": 2.4,
   "render_gpu_ms": 0,
   "draw_calls": 257,
   "primitives": 29764,
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
