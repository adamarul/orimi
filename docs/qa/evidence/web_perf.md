# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.82s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10161 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":140,"p50_ms":6.9,"p95_ms":7,"frames":843} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":140,"p50_ms":6.9,"p95_ms":7,"frames":843} godot {"fps":144,"mean_ms":7.11,"p95_ms":6.94,"p99_ms":6.95,"max_ms":144.43,"process_ms":5.5,"render_cpu_ms":1.9,"render_gpu_ms":0,"draw_calls":232,"primitives":27308,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":143,"p50_ms":6.9,"p95_ms":7,"frames":862} godot {"fps":144,"mean_ms":6.98,"p95_ms":6.94,"p99_ms":8.33,"max_ms":11.77,"process_ms":7.1,"render_cpu_ms":2.1,"render_gpu_ms":0,"draw_calls":253,"primitives":29628,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":196,"p50_ms":4.8,"p95_ms":6.4,"frames":1177} godot {"fps":185,"mean_ms":5.11,"p95_ms":6.06,"p99_ms":8.33,"max_ms":143.62,"process_ms":12,"render_cpu_ms":2,"render_gpu_ms":0,"draw_calls":232,"primitives":27308,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":162,"p50_ms":6.1,"p95_ms":7.1,"frames":975} godot {"fps":165,"mean_ms":6.16,"p95_ms":6.67,"p99_ms":7.07,"max_ms":8.3,"process_ms":6.7,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":257,"primitives":30668,"viewport":[1280,720],"window":[1920,1080]} |
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
   "frames": 843
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.11,
   "p95_ms": 6.94,
   "p99_ms": 6.95,
   "max_ms": 144.43,
   "process_ms": 5.5,
   "render_cpu_ms": 1.9,
   "render_gpu_ms": 0,
   "draw_calls": 232,
   "primitives": 27308,
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
   "p95_ms": 6.94,
   "p99_ms": 8.33,
   "max_ms": 11.77,
   "process_ms": 7.1,
   "render_cpu_ms": 2.1,
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
 },
 {
  "label": "uncapped",
  "size": "1280x720",
  "raf": {
   "fps": 196,
   "p50_ms": 4.8,
   "p95_ms": 6.4,
   "frames": 1177
  },
  "godot": {
   "fps": 185,
   "mean_ms": 5.11,
   "p95_ms": 6.06,
   "p99_ms": 8.33,
   "max_ms": 143.62,
   "process_ms": 12,
   "render_cpu_ms": 2,
   "render_gpu_ms": 0,
   "draw_calls": 232,
   "primitives": 27308,
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
   "fps": 162,
   "p50_ms": 6.1,
   "p95_ms": 7.1,
   "frames": 975
  },
  "godot": {
   "fps": 165,
   "mean_ms": 6.16,
   "p95_ms": 6.67,
   "p99_ms": 7.07,
   "max_ms": 8.3,
   "process_ms": 6.7,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 257,
   "primitives": 30668,
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
