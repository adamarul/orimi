# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=sedge_plain&warp=M_Knoll
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.10s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9173 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":74,"p50_ms":6.9,"p95_ms":7.1,"frames":460} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":74,"p50_ms":6.9,"p95_ms":7.1,"frames":460} godot {"fps":65,"mean_ms":7.58,"p95_ms":8.2,"p99_ms":8.6,"max_ms":144.67,"process_ms":2855.1,"render_cpu_ms":4.1,"render_gpu_ms":0,"draw_calls":586,"primitives":128148,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":115,"p50_ms":7,"p95_ms":13.9,"frames":690} godot {"fps":131,"mean_ms":8.72,"p95_ms":11.11,"p99_ms":11.67,"max_ms":12.9,"process_ms":8.8,"render_cpu_ms":4.2,"render_gpu_ms":0,"draw_calls":567,"primitives":130144,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":76,"p50_ms":6.5,"p95_ms":8.8,"frames":484} godot {"fps":133,"mean_ms":7.17,"p95_ms":8.9,"p99_ms":9.97,"max_ms":137.03,"process_ms":3008.6,"render_cpu_ms":6.3,"render_gpu_ms":0,"draw_calls":585,"primitives":127326,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":117,"p50_ms":8.4,"p95_ms":11.4,"frames":706} godot {"fps":123,"mean_ms":8.51,"p95_ms":10.8,"p99_ms":11.26,"max_ms":13.74,"process_ms":8.8,"render_cpu_ms":4,"render_gpu_ms":0,"draw_calls":581,"primitives":136392,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 214 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_sedge_plain_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 74,
   "p50_ms": 6.9,
   "p95_ms": 7.1,
   "frames": 460
  },
  "godot": {
   "fps": 65,
   "mean_ms": 7.58,
   "p95_ms": 8.2,
   "p99_ms": 8.6,
   "max_ms": 144.67,
   "process_ms": 2855.1,
   "render_cpu_ms": 4.1,
   "render_gpu_ms": 0,
   "draw_calls": 586,
   "primitives": 128148,
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
   "fps": 115,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 690
  },
  "godot": {
   "fps": 131,
   "mean_ms": 8.72,
   "p95_ms": 11.11,
   "p99_ms": 11.67,
   "max_ms": 12.9,
   "process_ms": 8.8,
   "render_cpu_ms": 4.2,
   "render_gpu_ms": 0,
   "draw_calls": 567,
   "primitives": 130144,
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
   "fps": 76,
   "p50_ms": 6.5,
   "p95_ms": 8.8,
   "frames": 484
  },
  "godot": {
   "fps": 133,
   "mean_ms": 7.17,
   "p95_ms": 8.9,
   "p99_ms": 9.97,
   "max_ms": 137.03,
   "process_ms": 3008.6,
   "render_cpu_ms": 6.3,
   "render_gpu_ms": 0,
   "draw_calls": 585,
   "primitives": 127326,
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
   "fps": 117,
   "p50_ms": 8.4,
   "p95_ms": 11.4,
   "frames": 706
  },
  "godot": {
   "fps": 123,
   "mean_ms": 8.51,
   "p95_ms": 10.8,
   "p99_ms": 11.26,
   "max_ms": 13.74,
   "process_ms": 8.8,
   "render_cpu_ms": 4,
   "render_gpu_ms": 0,
   "draw_calls": 581,
   "primitives": 136392,
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
