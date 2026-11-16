# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=sedge_plain&warp=M_Knoll
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.73s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10282 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":134,"p50_ms":7,"p95_ms":13.9,"frames":802} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":134,"p50_ms":7,"p95_ms":13.9,"frames":802} godot {"fps":144,"mean_ms":7.48,"p95_ms":9.26,"p99_ms":11.4,"max_ms":48.48,"process_ms":7.1,"render_cpu_ms":5,"render_gpu_ms":0,"draw_calls":665,"primitives":114170,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":127,"p50_ms":7,"p95_ms":13.9,"frames":763} godot {"fps":137,"mean_ms":7.91,"p95_ms":9.52,"p99_ms":11.7,"max_ms":13.9,"process_ms":15,"render_cpu_ms":5.6,"render_gpu_ms":0,"draw_calls":745,"primitives":132808,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":152,"p50_ms":6.4,"p95_ms":8.7,"frames":916} godot {"fps":174,"mean_ms":6.57,"p95_ms":8.33,"p99_ms":9.7,"max_ms":18.73,"process_ms":7.1,"render_cpu_ms":5.3,"render_gpu_ms":0,"draw_calls":663,"primitives":114250,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":132,"p50_ms":7.4,"p95_ms":9.5,"frames":794} godot {"fps":133,"mean_ms":7.57,"p95_ms":9.09,"p99_ms":9.67,"max_ms":11.7,"process_ms":8,"render_cpu_ms":4.9,"render_gpu_ms":0,"draw_calls":741,"primitives":132584,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 248 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_sedge_plain_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 134,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 802
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.48,
   "p95_ms": 9.26,
   "p99_ms": 11.4,
   "max_ms": 48.48,
   "process_ms": 7.1,
   "render_cpu_ms": 5,
   "render_gpu_ms": 0,
   "draw_calls": 665,
   "primitives": 114170,
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
   "fps": 127,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 763
  },
  "godot": {
   "fps": 137,
   "mean_ms": 7.91,
   "p95_ms": 9.52,
   "p99_ms": 11.7,
   "max_ms": 13.9,
   "process_ms": 15,
   "render_cpu_ms": 5.6,
   "render_gpu_ms": 0,
   "draw_calls": 745,
   "primitives": 132808,
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
   "fps": 152,
   "p50_ms": 6.4,
   "p95_ms": 8.7,
   "frames": 916
  },
  "godot": {
   "fps": 174,
   "mean_ms": 6.57,
   "p95_ms": 8.33,
   "p99_ms": 9.7,
   "max_ms": 18.73,
   "process_ms": 7.1,
   "render_cpu_ms": 5.3,
   "render_gpu_ms": 0,
   "draw_calls": 663,
   "primitives": 114250,
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
   "fps": 132,
   "p50_ms": 7.4,
   "p95_ms": 9.5,
   "frames": 794
  },
  "godot": {
   "fps": 133,
   "mean_ms": 7.57,
   "p95_ms": 9.09,
   "p99_ms": 9.67,
   "max_ms": 11.7,
   "process_ms": 8,
   "render_cpu_ms": 4.9,
   "render_gpu_ms": 0,
   "draw_calls": 741,
   "primitives": 132584,
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
