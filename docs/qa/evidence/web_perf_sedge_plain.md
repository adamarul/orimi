# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=sedge_plain&warp=M_Knoll
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.26s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (8703 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":847} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":847} godot {"fps":144,"mean_ms":7.08,"p95_ms":8.33,"p99_ms":9.72,"max_ms":18.92,"process_ms":5.9,"render_cpu_ms":3.8,"render_gpu_ms":0,"draw_calls":663,"primitives":111906,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":134,"p50_ms":7,"p95_ms":13.9,"frames":805} godot {"fps":144,"mean_ms":7.48,"p95_ms":9.09,"p99_ms":9.38,"max_ms":12.49,"process_ms":7.3,"render_cpu_ms":4.5,"render_gpu_ms":0,"draw_calls":751,"primitives":135856,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":155,"p50_ms":6.4,"p95_ms":8.2,"frames":934} godot {"fps":170,"mean_ms":6.44,"p95_ms":8.33,"p99_ms":8.39,"max_ms":18.88,"process_ms":6.5,"render_cpu_ms":4.2,"render_gpu_ms":0,"draw_calls":650,"primitives":113444,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":136,"p50_ms":7.2,"p95_ms":9.2,"frames":819} godot {"fps":146,"mean_ms":7.34,"p95_ms":8.66,"p99_ms":9.27,"max_ms":10.87,"process_ms":6.8,"render_cpu_ms":4.7,"render_gpu_ms":0,"draw_calls":745,"primitives":132848,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 248 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_sedge_plain_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 141,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 847
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.08,
   "p95_ms": 8.33,
   "p99_ms": 9.72,
   "max_ms": 18.92,
   "process_ms": 5.9,
   "render_cpu_ms": 3.8,
   "render_gpu_ms": 0,
   "draw_calls": 663,
   "primitives": 111906,
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
   "fps": 134,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 805
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.48,
   "p95_ms": 9.09,
   "p99_ms": 9.38,
   "max_ms": 12.49,
   "process_ms": 7.3,
   "render_cpu_ms": 4.5,
   "render_gpu_ms": 0,
   "draw_calls": 751,
   "primitives": 135856,
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
   "fps": 155,
   "p50_ms": 6.4,
   "p95_ms": 8.2,
   "frames": 934
  },
  "godot": {
   "fps": 170,
   "mean_ms": 6.44,
   "p95_ms": 8.33,
   "p99_ms": 8.39,
   "max_ms": 18.88,
   "process_ms": 6.5,
   "render_cpu_ms": 4.2,
   "render_gpu_ms": 0,
   "draw_calls": 650,
   "primitives": 113444,
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
   "fps": 136,
   "p50_ms": 7.2,
   "p95_ms": 9.2,
   "frames": 819
  },
  "godot": {
   "fps": 146,
   "mean_ms": 7.34,
   "p95_ms": 8.66,
   "p99_ms": 9.27,
   "max_ms": 10.87,
   "process_ms": 6.8,
   "render_cpu_ms": 4.7,
   "render_gpu_ms": 0,
   "draw_calls": 745,
   "primitives": 132848,
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
