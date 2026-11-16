# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=sedge_plain&warp=M_Knoll
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.50s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (8853 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":139,"p50_ms":6.9,"p95_ms":7.1,"frames":836} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":139,"p50_ms":6.9,"p95_ms":7.1,"frames":836} godot {"fps":144,"mean_ms":7.17,"p95_ms":8.33,"p99_ms":11.3,"max_ms":31.94,"process_ms":6.7,"render_cpu_ms":4.3,"render_gpu_ms":0,"draw_calls":661,"primitives":114090,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":131,"p50_ms":7,"p95_ms":13.9,"frames":790} godot {"fps":144,"mean_ms":7.62,"p95_ms":9.09,"p99_ms":11.67,"max_ms":14.4,"process_ms":6.7,"render_cpu_ms":5,"render_gpu_ms":0,"draw_calls":749,"primitives":135240,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":153,"p50_ms":6.5,"p95_ms":8.3,"frames":917} godot {"fps":166,"mean_ms":6.55,"p95_ms":8.33,"p99_ms":8.4,"max_ms":19.93,"process_ms":9.5,"render_cpu_ms":4,"render_gpu_ms":0,"draw_calls":663,"primitives":114010,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":131,"p50_ms":7.5,"p95_ms":9.7,"frames":785} godot {"fps":144,"mean_ms":7.65,"p95_ms":9.09,"p99_ms":9.75,"max_ms":11.01,"process_ms":7.5,"render_cpu_ms":4.8,"render_gpu_ms":0,"draw_calls":753,"primitives":135856,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 248 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_sedge_plain_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 139,
   "p50_ms": 6.9,
   "p95_ms": 7.1,
   "frames": 836
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.17,
   "p95_ms": 8.33,
   "p99_ms": 11.3,
   "max_ms": 31.94,
   "process_ms": 6.7,
   "render_cpu_ms": 4.3,
   "render_gpu_ms": 0,
   "draw_calls": 661,
   "primitives": 114090,
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
   "fps": 131,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 790
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.62,
   "p95_ms": 9.09,
   "p99_ms": 11.67,
   "max_ms": 14.4,
   "process_ms": 6.7,
   "render_cpu_ms": 5,
   "render_gpu_ms": 0,
   "draw_calls": 749,
   "primitives": 135240,
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
   "fps": 153,
   "p50_ms": 6.5,
   "p95_ms": 8.3,
   "frames": 917
  },
  "godot": {
   "fps": 166,
   "mean_ms": 6.55,
   "p95_ms": 8.33,
   "p99_ms": 8.4,
   "max_ms": 19.93,
   "process_ms": 9.5,
   "render_cpu_ms": 4,
   "render_gpu_ms": 0,
   "draw_calls": 663,
   "primitives": 114010,
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
   "fps": 131,
   "p50_ms": 7.5,
   "p95_ms": 9.7,
   "frames": 785
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.65,
   "p95_ms": 9.09,
   "p99_ms": 9.75,
   "max_ms": 11.01,
   "process_ms": 7.5,
   "render_cpu_ms": 4.8,
   "render_gpu_ms": 0,
   "draw_calls": 753,
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
 }
]
```
