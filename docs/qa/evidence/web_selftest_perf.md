# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&god=1&warp=M_ZoneA
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=5.42s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (11059 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":864} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":864} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":2.7,"render_cpu_ms":0.5,"render_gpu_ms":0,"draw_calls":7,"primitives":3488,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":144,"p50_ms":6.9,"p95_ms":7.1,"frames":864} godot {"fps":144,"mean_ms":6.94,"p95_ms":6.94,"p99_ms":6.94,"max_ms":6.94,"process_ms":3,"render_cpu_ms":1.1,"render_gpu_ms":0,"draw_calls":22,"primitives":3668,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":667,"p50_ms":1.5,"p95_ms":1.9,"frames":4008} godot {"fps":706,"mean_ms":1.5,"p95_ms":1.85,"p99_ms":2.08,"max_ms":2.9,"process_ms":2.2,"render_cpu_ms":0.4,"render_gpu_ms":0,"draw_calls":7,"primitives":3488,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":184,"p50_ms":5.2,"p95_ms":7.2,"frames":1105} godot {"fps":203,"mean_ms":5.44,"p95_ms":6.67,"p99_ms":6.67,"max_ms":7.3,"process_ms":6.5,"render_cpu_ms":5,"render_gpu_ms":0,"draw_calls":22,"primitives":3668,"viewport":[1280,720],"window":[1920,1080]} |
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
   "p95_ms": 7.1,
   "frames": 864
  },
  "godot": {
   "fps": 144,
   "mean_ms": 6.94,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 6.94,
   "process_ms": 2.7,
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
   "process_ms": 3,
   "render_cpu_ms": 1.1,
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
   "fps": 667,
   "p50_ms": 1.5,
   "p95_ms": 1.9,
   "frames": 4008
  },
  "godot": {
   "fps": 706,
   "mean_ms": 1.5,
   "p95_ms": 1.85,
   "p99_ms": 2.08,
   "max_ms": 2.9,
   "process_ms": 2.2,
   "render_cpu_ms": 0.4,
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
   "fps": 184,
   "p50_ms": 5.2,
   "p95_ms": 7.2,
   "frames": 1105
  },
  "godot": {
   "fps": 203,
   "mean_ms": 5.44,
   "p95_ms": 6.67,
   "p99_ms": 6.67,
   "max_ms": 7.3,
   "process_ms": 6.5,
   "render_cpu_ms": 5,
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
