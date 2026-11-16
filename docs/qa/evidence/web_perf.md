# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.42s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9227 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":138,"p50_ms":6.9,"p95_ms":7,"frames":832} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":138,"p50_ms":6.9,"p95_ms":7,"frames":832} godot {"fps":144,"mean_ms":7.2,"p95_ms":6.94,"p99_ms":8.33,"max_ms":141.77,"process_ms":8.5,"render_cpu_ms":1.9,"render_gpu_ms":0,"draw_calls":230,"primitives":27508,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":863} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":6,"render_cpu_ms":2.2,"render_gpu_ms":0,"draw_calls":241,"primitives":27484,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":191,"p50_ms":5,"p95_ms":6.4,"frames":1148} godot {"fps":193,"mean_ms":5.2,"p95_ms":6.06,"p99_ms":7.3,"max_ms":125.87,"process_ms":5.7,"render_cpu_ms":1.8,"render_gpu_ms":0,"draw_calls":210,"primitives":26252,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":158,"p50_ms":6.2,"p95_ms":7.7,"frames":950} godot {"fps":174,"mean_ms":6.33,"p95_ms":7.14,"p99_ms":7.14,"max_ms":7.73,"process_ms":6.2,"render_cpu_ms":1.8,"render_gpu_ms":0,"draw_calls":241,"primitives":28900,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 152 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 138,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 832
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.2,
   "p95_ms": 6.94,
   "p99_ms": 8.33,
   "max_ms": 141.77,
   "process_ms": 8.5,
   "render_cpu_ms": 1.9,
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
   "fps": 144,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 863
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 6,
   "render_cpu_ms": 2.2,
   "render_gpu_ms": 0,
   "draw_calls": 241,
   "primitives": 27484,
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
   "fps": 191,
   "p50_ms": 5,
   "p95_ms": 6.4,
   "frames": 1148
  },
  "godot": {
   "fps": 193,
   "mean_ms": 5.2,
   "p95_ms": 6.06,
   "p99_ms": 7.3,
   "max_ms": 125.87,
   "process_ms": 5.7,
   "render_cpu_ms": 1.8,
   "render_gpu_ms": 0,
   "draw_calls": 210,
   "primitives": 26252,
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
   "fps": 158,
   "p50_ms": 6.2,
   "p95_ms": 7.7,
   "frames": 950
  },
  "godot": {
   "fps": 174,
   "mean_ms": 6.33,
   "p95_ms": 7.14,
   "p99_ms": 7.14,
   "max_ms": 7.73,
   "process_ms": 6.2,
   "render_cpu_ms": 1.8,
   "render_gpu_ms": 0,
   "draw_calls": 241,
   "primitives": 28900,
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
