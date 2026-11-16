# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.21s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (8976 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":141,"p50_ms":6.9,"p95_ms":7.1,"frames":845} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7.1,"frames":845} godot {"fps":144,"mean_ms":7.09,"p95_ms":6.94,"p99_ms":6.94,"max_ms":130.86,"process_ms":5.7,"render_cpu_ms":1.8,"render_gpu_ms":0,"draw_calls":211,"primitives":26320,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":864} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":5.8,"render_cpu_ms":2.1,"render_gpu_ms":0,"draw_calls":216,"primitives":26416,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":202,"p50_ms":4.7,"p95_ms":6.2,"frames":1217} godot {"fps":197,"mean_ms":4.94,"p95_ms":6.06,"p99_ms":6.06,"max_ms":137.13,"process_ms":6.1,"render_cpu_ms":1.6,"render_gpu_ms":0,"draw_calls":210,"primitives":26308,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":183,"p50_ms":5.4,"p95_ms":6.7,"frames":1100} godot {"fps":178,"mean_ms":5.46,"p95_ms":6.25,"p99_ms":6.25,"max_ms":9.06,"process_ms":6.5,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":240,"primitives":29760,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 142 console lines |

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
   "p95_ms": 7.1,
   "frames": 845
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.09,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 130.86,
   "process_ms": 5.7,
   "render_cpu_ms": 1.8,
   "render_gpu_ms": 0,
   "draw_calls": 211,
   "primitives": 26320,
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
   "frames": 864
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 5.8,
   "render_cpu_ms": 2.1,
   "render_gpu_ms": 0,
   "draw_calls": 216,
   "primitives": 26416,
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
   "fps": 202,
   "p50_ms": 4.7,
   "p95_ms": 6.2,
   "frames": 1217
  },
  "godot": {
   "fps": 197,
   "mean_ms": 4.94,
   "p95_ms": 6.06,
   "p99_ms": 6.06,
   "max_ms": 137.13,
   "process_ms": 6.1,
   "render_cpu_ms": 1.6,
   "render_gpu_ms": 0,
   "draw_calls": 210,
   "primitives": 26308,
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
   "fps": 183,
   "p50_ms": 5.4,
   "p95_ms": 6.7,
   "frames": 1100
  },
  "godot": {
   "fps": 178,
   "mean_ms": 5.46,
   "p95_ms": 6.25,
   "p99_ms": 6.25,
   "max_ms": 9.06,
   "process_ms": 6.5,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 240,
   "primitives": 29760,
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
