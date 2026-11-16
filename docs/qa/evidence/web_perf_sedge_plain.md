# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=sedge_plain&warp=M_Knoll
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.44s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9769 ms)


| result | criterion | detail |
| - | - | - |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":137,"p50_ms":6.9,"p95_ms":7.1,"frames":822} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":137,"p50_ms":6.9,"p95_ms":7.1,"frames":822} godot {"fps":144,"mean_ms":7.29,"p95_ms":9.09,"p99_ms":12.03,"max_ms":36.11,"process_ms":6.7,"render_cpu_ms":4.1,"render_gpu_ms":0,"draw_calls":655,"primitives":111706,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":131,"p50_ms":7,"p95_ms":13.9,"frames":786} godot {"fps":138,"mean_ms":7.64,"p95_ms":9.26,"p99_ms":12.96,"max_ms":14.7,"process_ms":9.9,"render_cpu_ms":5,"render_gpu_ms":0,"draw_calls":750,"primitives":135518,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":151,"p50_ms":6.5,"p95_ms":8.8,"frames":908} godot {"fps":166,"mean_ms":6.61,"p95_ms":8.33,"p99_ms":10.07,"max_ms":39.28,"process_ms":6.7,"render_cpu_ms":3.8,"render_gpu_ms":0,"draw_calls":663,"primitives":114010,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":131,"p50_ms":7.4,"p95_ms":9.5,"frames":790} godot {"fps":142,"mean_ms":7.6,"p95_ms":9.09,"p99_ms":9.81,"max_ms":11.7,"process_ms":7.5,"render_cpu_ms":6.6,"render_gpu_ms":0,"draw_calls":751,"primitives":135280,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 248 console lines |

screenshots: none
console log: docs/qa/evidence/web_perf_sedge_plain_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 137,
   "p50_ms": 6.9,
   "p95_ms": 7.1,
   "frames": 822
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.29,
   "p95_ms": 9.09,
   "p99_ms": 12.03,
   "max_ms": 36.11,
   "process_ms": 6.7,
   "render_cpu_ms": 4.1,
   "render_gpu_ms": 0,
   "draw_calls": 655,
   "primitives": 111706,
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
   "frames": 786
  },
  "godot": {
   "fps": 138,
   "mean_ms": 7.64,
   "p95_ms": 9.26,
   "p99_ms": 12.96,
   "max_ms": 14.7,
   "process_ms": 9.9,
   "render_cpu_ms": 5,
   "render_gpu_ms": 0,
   "draw_calls": 750,
   "primitives": 135518,
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
   "fps": 151,
   "p50_ms": 6.5,
   "p95_ms": 8.8,
   "frames": 908
  },
  "godot": {
   "fps": 166,
   "mean_ms": 6.61,
   "p95_ms": 8.33,
   "p99_ms": 10.07,
   "max_ms": 39.28,
   "process_ms": 6.7,
   "render_cpu_ms": 3.8,
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
   "p50_ms": 7.4,
   "p95_ms": 9.5,
   "frames": 790
  },
  "godot": {
   "fps": 142,
   "mean_ms": 7.6,
   "p95_ms": 9.09,
   "p99_ms": 9.81,
   "max_ms": 11.7,
   "process_ms": 7.5,
   "render_cpu_ms": 6.6,
   "render_gpu_ms": 0,
   "draw_calls": 751,
   "primitives": 135280,
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
