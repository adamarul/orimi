# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.75s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9455 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":864} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":864} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":2.1,"render_cpu_ms":0.8,"render_gpu_ms":0,"draw_calls":7,"primitives":3488,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7,"frames":864} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":3.9,"render_cpu_ms":1,"render_gpu_ms":0,"draw_calls":22,"primitives":3668,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":654,"p50_ms":1.5,"p95_ms":1.9,"frames":3924} godot {"fps":639,"mean_ms":1.53,"p95_ms":1.67,"p99_ms":2.08,"max_ms":2.9,"process_ms":2.3,"render_cpu_ms":0.5,"render_gpu_ms":0,"draw_calls":7,"primitives":3488,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":176,"p50_ms":5.7,"p95_ms":6.4,"frames":1060} godot {"fps":184,"mean_ms":5.67,"p95_ms":6.06,"p99_ms":6.67,"max_ms":7.46,"process_ms":5.7,"render_cpu_ms":3.6,"render_gpu_ms":0,"draw_calls":22,"primitives":3668,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 121 console lines |

screenshots: none
console log: docs/qa/evidence/web_selftest_perf_console.txt

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
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 2.1,
   "render_cpu_ms": 0.8,
   "render_gpu_ms": 0,
   "draw_calls": 7,
   "primitives": 3488,
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
   "process_ms": 3.9,
   "render_cpu_ms": 1,
   "render_gpu_ms": 0,
   "draw_calls": 22,
   "primitives": 3668,
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
   "fps": 654,
   "p50_ms": 1.5,
   "p95_ms": 1.9,
   "frames": 3924
  },
  "godot": {
   "fps": 639,
   "mean_ms": 1.53,
   "p95_ms": 1.67,
   "p99_ms": 2.08,
   "max_ms": 2.9,
   "process_ms": 2.3,
   "render_cpu_ms": 0.5,
   "render_gpu_ms": 0,
   "draw_calls": 7,
   "primitives": 3488,
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
   "fps": 176,
   "p50_ms": 5.7,
   "p95_ms": 6.4,
   "frames": 1060
  },
  "godot": {
   "fps": 184,
   "mean_ms": 5.67,
   "p95_ms": 6.06,
   "p99_ms": 6.67,
   "max_ms": 7.46,
   "process_ms": 5.7,
   "render_cpu_ms": 3.6,
   "render_gpu_ms": 0,
   "draw_calls": 22,
   "primitives": 3668,
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
