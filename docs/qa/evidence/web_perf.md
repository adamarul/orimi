# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.99s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9677 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":140,"p50_ms":6.9,"p95_ms":7,"frames":839} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":140,"p50_ms":6.9,"p95_ms":7,"frames":839} godot {"fps":144,"mean_ms":7.13,"p95_ms":6.94,"p99_ms":7.14,"max_ms":136.21,"process_ms":5.5,"render_cpu_ms":2.1,"render_gpu_ms":0,"draw_calls":230,"primitives":27508,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":846} godot {"fps":140,"mean_ms":7.08,"p95_ms":8.33,"p99_ms":8.8,"max_ms":13.49,"process_ms":8.6,"render_cpu_ms":2,"render_gpu_ms":0,"draw_calls":230,"primitives":27226,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":188,"p50_ms":5,"p95_ms":6.5,"frames":1132} godot {"fps":193,"mean_ms":5.29,"p95_ms":6.06,"p99_ms":7.58,"max_ms":135.5,"process_ms":6.2,"render_cpu_ms":1.6,"render_gpu_ms":0,"draw_calls":226,"primitives":27132,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":159,"p50_ms":6.2,"p95_ms":7.2,"frames":956} godot {"fps":162,"mean_ms":6.29,"p95_ms":6.69,"p99_ms":8.85,"max_ms":11.52,"process_ms":7,"render_cpu_ms":3.3,"render_gpu_ms":0,"draw_calls":253,"primitives":29628,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 152 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 140,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 839
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.13,
   "p95_ms": 6.94,
   "p99_ms": 7.14,
   "max_ms": 136.21,
   "process_ms": 5.5,
   "render_cpu_ms": 2.1,
   "render_gpu_ms": 0,
   "draw_calls": 230,
   "primitives": 27508,
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
   "fps": 141,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 846
  },
  "godot": {
   "fps": 140,
   "mean_ms": 7.08,
   "p95_ms": 8.33,
   "p99_ms": 8.8,
   "max_ms": 13.49,
   "process_ms": 8.6,
   "render_cpu_ms": 2,
   "render_gpu_ms": 0,
   "draw_calls": 230,
   "primitives": 27226,
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
   "fps": 188,
   "p50_ms": 5,
   "p95_ms": 6.5,
   "frames": 1132
  },
  "godot": {
   "fps": 193,
   "mean_ms": 5.29,
   "p95_ms": 6.06,
   "p99_ms": 7.58,
   "max_ms": 135.5,
   "process_ms": 6.2,
   "render_cpu_ms": 1.6,
   "render_gpu_ms": 0,
   "draw_calls": 226,
   "primitives": 27132,
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
   "fps": 159,
   "p50_ms": 6.2,
   "p95_ms": 7.2,
   "frames": 956
  },
  "godot": {
   "fps": 162,
   "mean_ms": 6.29,
   "p95_ms": 6.69,
   "p99_ms": 8.85,
   "max_ms": 11.52,
   "process_ms": 7,
   "render_cpu_ms": 3.3,
   "render_gpu_ms": 0,
   "draw_calls": 253,
   "primitives": 29628,
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
